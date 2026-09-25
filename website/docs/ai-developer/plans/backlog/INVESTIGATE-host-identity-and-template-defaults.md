# Investigate: Host Identity Capture and Template Defaults

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Make a freshly-cloned project Just Work — `clone → install.sh → open in VS Code → dev-template <id> → dev-template-configure` should produce a working app with database, K8s namespace, and secret all named after the repo, **with zero file editing required**.

**Priority**: High — this is the "first impression" path for every new DCT user. The current state has two compounding bugs that together make the default experience broken.

**Last Updated**: 2026-04-10

**Related**:
- [INVESTIGATE-improve-template-docs-with-services.md](https://github.com/helpers-no/dev-templates) (cross-repo, in TMP)
- `PLAN-p1-dct-shim.md` — completed `--namespace` / `--secret-name-prefix` wiring (v1.7.35)

---

## Problem

A new user runs:

```bash
git clone https://github.com/MyOrg/my-cool-app.git
cd my-cool-app
curl -fsSL .../install.sh | bash
code .
# "Reopen in Container" → DCT v1.7.35 starts
dev-template python-basic-webserver-database
dev-template-configure
```

Expected outcome: a working Flask app with `my_cool_app_db` database, `my-cool-app` namespace, and `my-cool-app-db` Kubernetes secret. All names derived from the repo. Zero edits.

Actual outcome: **broken in two independent places.**

### Bug A — Host git identity is never captured

`detect_git_user_email()` in `.devcontainer/additions/lib/git-identity.sh:109` has a 5-priority fallback chain:

| Priority | Source | Status on fresh clone |
|---|---|---|
| 1 | `$GIT_USER_EMAIL` env var already set | empty |
| 2 | `.devcontainer.secrets/env-vars/.git-identity` (saved from previous run) | does not exist |
| 3 | `.devcontainer.secrets/env-vars/.git-host-email` (host-captured) | **does not exist** |
| 4 | `git config --global user.email` (inside the container) | empty |
| 5 | Fallback: `<host_user>@localhost` | matches → returns `vscode@localhost` |

Priority 3 expects `.git-host-email` to be written by `initializeCommand` on the host. But the actual `initializeCommand` in `devcontainer-user-template.json:54` only captures the hostname:

```json
"initializeCommand": "mkdir -p .devcontainer.secrets/env-vars && hostname -s > .devcontainer.secrets/env-vars/.host-hostname 2>/dev/null || hostname > .devcontainer.secrets/env-vars/.host-hostname 2>/dev/null || true"
```

It never runs `git config --global user.email` or `user.name`. So priority 3 always fails on fresh clones, and the container ends up reporting `vscode@localhost` even though the user has a perfectly good git identity on their host machine.

**Symptom:** the "🔐 Configuring git identity..." block in entrypoint output (printed by `config-git.sh:184-189`) shows:

```
✅ Git identity detected:
   Email:    vscode@localhost
   Provider: local
   Repo:     workspace
   Branch:   unknown
   Hostname: dev-vscode-localhost-...
```

…instead of the user's real email and the actual `MyOrg/my-cool-app` repo info. (`Repo: workspace` happens because `git remote get-url origin` may also fail before VS Code marks `/workspace` as a safe directory — see Bug A2 below.)

### Bug A2 — `git remote get-url origin` may fail at entrypoint time

The entrypoint runs `git config --global --add safe.directory "$DCT_WORKSPACE"` early (line 38), then calls `config-git.sh --verify` which calls `git remote get-url origin`. This *should* work, but the order of UID mapping vs. safe-directory marking is fragile.

**Update 2026-04-10:** Real-world test on a freshly-cloned `terchris/delete-test` opened in VS Code shows `git remote get-url origin` works correctly at entrypoint time — `Repo: terchris/delete-test` and `Branch: main` were both detected on the first start. So Bug A2 **does not reproduce** in this environment. It may still surface in other environments (different UID mapping, slow filesystem, etc.) but it's not load-bearing for the main fix. **Demote from "open question" to "monitor".**

### Bug B — Template defaults don't use the repo name

`templates/python-basic-webserver-database/template-info.yaml` ships with hardcoded placeholder defaults:

```yaml
params:
  app_name: "my-app"
  database_name: "my_app_db"
```

When the user runs `dev-template-configure` without editing this file, v1.7.35's `dev-template-configure.sh` resolves:

```bash
local namespace="${PARAMS[subdomain]:-${PARAMS[app_name]:-$GIT_REPO}}"
```

With `app_name="my-app"`, this falls through to `app_name` and never reaches the `GIT_REPO` fallback. The configure call lands as:

```
uis configure postgresql --namespace my-app --secret-name-prefix my-cool-app
```

And UIS creates:
- Namespace: `my-app`  ← from app_name default
- Secret: `my-cool-app-db` in `my-app` namespace  ← prefix from GIT_REPO, namespace from app_name
- Database: `my_app_db`  ← from database_name default

But the template's `deployment.yaml` was placeholder-substituted at `dev-template` time using `GIT_REPO` (not `app_name`):

```yaml
metadata:
  name: "my-cool-app-deployment"
  labels:
    app: "my-cool-app"
spec:
  containers:
    - name: "my-cool-app"
      env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: "my-cool-app-db"   # ← expects this secret in the deployment's namespace
```

So when the user later does `kubectl apply -f manifests/ -n my-cool-app`, the pod looks for `my-cool-app-db` in `my-cool-app` namespace, but the secret was created in `my-app`. **Crash-loop.**

**Two naming schemes in the same template, defaulting to different values:**

| Layer | Source | Default value | Used for |
|---|---|---|---|
| `dev-template` placeholder substitution | `GIT_REPO` | `my-cool-app` | deployment.yaml, kustomization.yaml, container/secret names |
| `template-info.yaml` runtime params | manual edit | `my-app` | `dev-template-configure` namespace + db name |

These two values are independent by accident. Nothing forces them to match.

### How A and B compound

Bug A means we can't even *trust* `GIT_REPO` to be detected correctly on fresh clones (if the entrypoint's `git remote get-url` fails for any reason, GIT_REPO falls back to `basename "/workspace"` = `workspace`).

Bug B means even when `GIT_REPO` *is* detected correctly, the template ignores it for namespace/database naming.

Together: a fresh-clone user gets either `workspace`-prefixed names or `my-app`-prefixed names — never the actual repo name they expect.

### Bug C — `dev-check` (and the welcome message) don't know about host capture

There are **two surfaces** that show the "git not configured" warning, both rooted in the same check.

**Surface 1 — `dev-check`** (`.devcontainer/manage/dev-check.sh`): a generic configuration checker that scans `additions/config-*.sh` scripts and runs each one's `SCRIPT_CHECK_COMMAND`. For git identity (`config-git.sh:15`):

```bash
SCRIPT_CHECK_COMMAND="git config --global user.name >/dev/null 2>&1 && git config --global user.email >/dev/null 2>&1"
```

**Surface 2 — the welcome message** at every container start (streamed via `dev-welcome.sh` from `/tmp/.dct-startup.log`). This *also* runs an identity check independently and prints:

```
⚠️  Git identity not configured - run 'dev-setup' to set your name and email
```

Both surfaces check the **container's** `git config`. Neither checks whether `.git-host-email` / `.git-host-name` exist on disk. So on a fresh clone where Bug A bites:

1. The welcome message warns "Git identity not configured" on every container start
2. `dev-check` (if run) would report `❌ Git Identity — NOT_CONFIGURED`
3. Both offer the interactive `configure_git_identity()` flow (`config-git.sh:198`)
4. The interactive flow prompts the user from scratch with no awareness that the host has a perfectly good `git config user.email` available
5. User retypes information they already have on their host

This is a third symptom of Bug A: the manual recovery path is awkward because nothing surfaces "your host has X, do you want to use that?".

**Once Bug A is fixed**, this resolves automatically — the entrypoint applies the host-captured email to the container's `git config`, the check command passes, and `dev-check` reports CONFIGURED. But there's still a UX gap worth addressing:

- **dev-check could show a third state** (besides CONFIGURED / NOT_CONFIGURED) — `READY_FROM_HOST` — when host capture exists but hasn't been applied yet (e.g., between `initializeCommand` running and the entrypoint applying). This would tell the user "your host identity will be used automatically on next start" instead of scaring them with NOT_CONFIGURED.
- **`configure_git_identity()` interactive flow** could pre-populate prompts from `.git-host-email` / `.git-host-name` if they exist, so the user just hits Enter to accept the host's values rather than retyping.

These are UX polish, not blockers — but they're cheap wins once we're already touching this code path.

---

## Code reference

### Files involved

| File | What it does | What's wrong |
|---|---|---|
| `devcontainer-user-template.json:54` | `initializeCommand` runs on host before container start | Only captures hostname, not git identity |
| `image/entrypoint.sh:62-77` | Reads `.git-host-name` / `.git-host-email` from host-captured files | The files don't exist (Bug A) |
| `image/entrypoint.sh:79-84` | Calls `config-git.sh --verify` to detect identity | Works as designed but starves with no input |
| `.devcontainer/additions/config-git.sh:137` | `verify_git_identity()` — orchestrates detection + display | Comment claims "called via postStartCommand" but actually called from ENTRYPOINT |
| `.devcontainer/additions/lib/git-identity.sh:109` | `detect_git_user_email()` priority chain | Priority 3 source never populated |
| `.devcontainer/additions/lib/git-identity.sh:211` | `detect_git_identity()` calls remote URL parser | Falls back to `basename /workspace` = "workspace" if `git remote get-url` fails |
| `.devcontainer/additions/lib/git-identity.sh:276` | `save_git_identity_to_file()` writes to `.git-identity` | Persists garbage on first run, but priority 2 will read it on second run — sticky |
| `.devcontainer/manage/dev-template.sh` | Placeholder-substitutes `{{REPO_NAME}}` in deployment.yaml | Doesn't substitute in template-info.yaml |
| `.devcontainer/manage/dev-check.sh` | Generic config checker — scans `config-*.sh`, runs each `SCRIPT_CHECK_COMMAND` | No notion of "host-captured but not yet applied" — reports git as NOT_CONFIGURED on fresh clones (Bug C) |
| `.devcontainer/additions/lib/component-scanner.sh` | `scan_config_scripts()` — discovers config scripts that `dev-check` iterates | n/a — works as designed |
| `helpers-no/dev-templates/templates/python-basic-webserver-database/template-info.yaml` | Template params | Hardcoded defaults `my-app` / `my_app_db`, no `{{REPO_NAME}}` |

### Where things are stored

Note: **`.devcontainer.secrets/.gh-config/`** is for `gh` CLI OAuth tokens (managed by `gh-credential-sync.sh`). It is **NOT** where git identity is stored.

Git identity lives in **`.devcontainer.secrets/env-vars/.git-identity`** — written by `save_git_identity_to_file()`. It contains exports for `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GIT_PROVIDER`, `GIT_ORG`, `GIT_REPO`, `GIT_REPO_FULL`, `GIT_BRANCH`, `TS_HOSTNAME`, plus legacy aliases.

Host-captured fragments live in **`.devcontainer.secrets/env-vars/`** as separate files:
- `.host-hostname` — hostname (currently the only thing captured)
- `.git-host-name` — host's git user.name (**referenced but never written**)
- `.git-host-email` — host's git user.email (**referenced but never written**)

---

## What needs to be true for the happy path to work

A user who clones a repo, runs install.sh, opens VS Code, and runs `dev-template <id>` followed by `dev-template-configure` should:

1. See their **real email** in the entrypoint's "Git identity detected" block
2. See their **real repo name** (e.g. `MyOrg/my-cool-app`) in the same block
3. Have `dev-template`'s "next steps" message say "defaults are ready — your database, namespace, and secret will be named **my-cool-app**"
4. Have `dev-template-configure` create namespace `my-cool-app`, database `my_cool_app_db`, secret `my-cool-app-db` — all consistent with what `deployment.yaml` references
5. Be able to `kubectl apply -f manifests/ -n my-cool-app` and have the pod find its secret without crash-looping
6. Never have to edit any file unless they explicitly want different names

---

## Design questions

### Q1 — How should the host's git identity reach the container?

Options:
1. **Extend `initializeCommand` inline** with the additional `git config` calls (gets unwieldy)
2. **Move `initializeCommand` to a script** in `image/host-init.sh` that the JSON references — cleaner, but `initializeCommand` runs on the *host* and the script needs to be cloned alongside the project (chicken-and-egg)
3. **Shell out via `bash -c "..."`** in initializeCommand — readable but still inline
4. **Copy host's `~/.gitconfig` into a captured location** instead of running `git config --global` — more general but copies more than we need

Constraint: the user template gets re-downloaded by `dev-update`, so the JSON itself must be self-contained or reference something that's available at install time. Option 2 only works if the script ships in the cloned-from-template `.devcontainer/` and is referenced relatively.

### Q2 — Should templates default `app_name` to the repo name?

Two ways to achieve "defaults work without editing":

**(a) TMP-side fix:** Templates use `{{REPO_NAME}}` placeholder in `template-info.yaml` params, and `dev-template.sh` substitutes them just like it already does for `deployment.yaml`. After substitution, the file looks like:

```yaml
params:
  app_name: "my-cool-app"
  database_name: "my_cool_app_db"
```

User can still edit, but the default is sensible. **Cleanest because the substitution mechanism already exists.**

**(b) DCT-side fix:** `dev-template-configure.sh` resolves `app_name` from `GIT_REPO` first, only falling back to `params.app_name` if explicitly overridden by the user. Templates ship with `app_name: ""` or omit it entirely.

(a) is better because:
- The substitution is visible in the file (user can see what the default is)
- It's consistent with how `deployment.yaml` is already substituted
- It works for any param name, not just `app_name`
- It doesn't require special-casing in `dev-template-configure`

(b) would require every template to either omit `app_name` or use a sentinel value, and `dev-template-configure` would need to know which params are "name-like" and should fall back to `GIT_REPO`.

**Recommendation: (a).**

### Q3 — How do we handle `database_name` (which is a slug, not a domain name)?

The repo name is `my-cool-app`. The PostgreSQL database name needs to be a valid SQL identifier — typically `my_cool_app_db` (underscores, not dashes). Two sub-options:

- **(a-i)** Add a `{{REPO_NAME_SLUG}}` placeholder that's `${GIT_REPO//-/_}` — automatic conversion
- **(a-ii)** Document that the template author writes `{{REPO_NAME}}_db` and accepts the dashes (PostgreSQL allows quoted identifiers but it's ugly)
- **(a-iii)** Provide a hand-crafted `{{REPO_NAME_UNDERSCORE}}` that converts dashes to underscores

a-i is the cleanest. We'd just need to add the substitution to `dev-template.sh` and document it.

### Q4 — What about users with no host git config?

If the user's host has no `git config --global user.email`, should we:
- Refuse to start the container?
- Show a clear warning and use a deterministic default?
- Prompt at first `dev-template-configure` run?

Current behavior: silently uses `vscode@localhost`. That's bad — the user has no idea their commits will look weird. We should at least surface this clearly.

### Q5 — What does `dev-template`'s "next steps" message look like?

After Bug B is fixed, the message should reflect that defaults work. See the proposal already in the chat:

```
   3. Configure services (database, auth, etc.):

      ✅ Defaults are ready to use — your database, K8s namespace,
         and Kubernetes secret will all be named after your repo
         (my-cool-app). Just run:

            dev-template configure

      📝 To use different names, edit params in template-info.yaml
         before running configure. See the README for details.
```

The `(my-cool-app)` part requires `dev-template.sh` to have access to `GIT_REPO` at the time it prints next-steps. Currently it does (the placeholder substitution already uses it for deployment.yaml).

### Q6 — Cross-team coordination

This investigation touches **three repos**:

| Repo | What changes |
|---|---|
| `helpers-no/devcontainer-toolbox` (DCT) | `initializeCommand`, `git-identity.sh`, `dev-template.sh` (placeholder substitution + next-steps message), `dev-template-configure.sh` (maybe), `devcontainer-user-template.json` |
| `helpers-no/dev-templates` (TMP) | `template-info.yaml` files for all templates that have configurable params, READMEs that document the new defaults flow |
| `helpers-no/urbalurba-infrastructure` (UIS) | None — UIS already accepts the resolved namespace/prefix; this is purely about how DCT *computes* them |

DCT and TMP need coordinated changes. We should sequence them so each release is independently shippable:
1. DCT ships host identity capture + `{{REPO_NAME_SLUG}}` placeholder support → no behavior change for existing templates
2. TMP migrates one template (python-basic-webserver-database) to use the new placeholders → tests the flow end-to-end
3. TMP migrates remaining templates → general rollout
4. DCT updates `dev-template`'s next-steps message → better UX

---

## Out of scope for this investigation

- The `dev-update` cleanup function's dangling-image bug (already known, separate fix)
- Replacing `template-info.yaml` with a different format
- Changing how `dev-template-configure` calls UIS (the `--namespace` / `--secret-name-prefix` flow stays as v1.7.35 designed)
- Auto-prompting for git identity when the host has none (Q4 — defer until we have data on how often this happens)

---

## What this investigation needs to produce before we plan

Before writing a `PLAN-*.md`, we need answers to:

1. **Q1 (host capture mechanism):** Pick option 1, 2, 3, or 4
2. **Q2 (template defaults source):** Confirm (a) over (b)
3. **Q3 (slug placeholder):** Confirm `{{REPO_NAME_SLUG}}` with `s/-/_/g`
4. **Q5 (next-steps message):** Confirm the proposed text or revise
5. **Q6 (sequencing):** Confirm DCT-first → TMP-second
6. **Verify Bug A2:** does `git remote get-url origin` actually fail on first start, or is the "Repo: workspace" symptom always caused by Bug A's downstream effects?

---

## Acceptance criteria for the eventual plan

A user running the following on a fresh repo with a sensible host git config should see all five things work without editing:

```bash
git clone https://github.com/MyOrg/my-cool-app.git
cd my-cool-app
curl -fsSL .../install.sh | bash
code .
# Click "Reopen in Container"
# In container terminal:
dev-template python-basic-webserver-database
dev-template-configure
```

Then:

- [ ] Entrypoint's "Git identity detected" block shows the user's real email + `MyOrg/my-cool-app`
- [ ] `dev-check` reports `✅ Git Identity — CONFIGURED` (no manual interactive setup needed)
- [ ] `dev-template`'s next-steps says "named after your repo (my-cool-app)"
- [ ] `dev-template-configure` creates namespace `my-cool-app`, database `my_cool_app_db`, secret `my-cool-app-db`
- [ ] `cat .env` shows a working `DATABASE_URL` for local dev
- [ ] `kubectl get secret my-cool-app-db -n my-cool-app -o jsonpath='{.data.DATABASE_URL}' | base64 -d` returns a working cluster URL
- [ ] User did not edit a single file
- [ ] **Negative path:** if the user has no git identity on their host, `dev-check` shows a clear actionable message (not silent fallback to `vscode@localhost`)

---

## Real-world reproduction (2026-04-10, DCT v1.7.36)

Captured during the v1.7.36 E2E test setup. After:

1. `rm -rf ~/learn/helpers/testing/delete-test`
2. `git clone https://github.com/terchris/delete-test.git`
3. `code delete-test` → "Reopen in Container"
4. VS Code pulled `:latest` (v1.7.36) and built the derived container
5. Opened first terminal — entrypoint output streamed via the welcome script:

```
DevContainer Toolbox v1.7.36 - Type 'dev-help' for commands

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 DevContainer Toolbox — Starting up
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔐 Configuring git identity...

✅ Git identity detected:
   Email:    vscode@localhost                              ← Bug A: priority-5 fallback
   Provider: github                                         ← parsed correctly
   Repo:     terchris/delete-test                           ← parsed correctly (Bug A2 NOT manifesting)
   Branch:   main                                           ← parsed correctly
   Hostname: dev-vscode-localhost-mbp-j4g0g066w2            ← derived from the bad email

...

⚠️  Git identity not configured - run 'dev-setup' to set     ← Bug C, surface 2:
    your name and email                                       welcome message warning
```

The host (Mac) has a real `git config --global user.email` set, but **none of it reached the container** because the `initializeCommand` only writes `.host-hostname`, never `.git-host-email`.

### What this confirms

| Bug | Predicted | Observed | Status |
|---|---|---|---|
| **A** (host email not captured) | `vscode@localhost` shown | `vscode@localhost` shown | ✅ Confirmed |
| **A2** (git remote may fail) | `Repo: workspace` fallback | `Repo: terchris/delete-test` correct | ❌ Does not manifest in this environment |
| **B** (template defaults wrong) | Will manifest at `dev-template configure` | (not yet tested in this run) | Pending |
| **C** (dev-check unaware of host capture) | Warning surfaces on fresh clones | Welcome message warning surfaced; `dev-check` not run but same root cause | ✅ Confirmed (and revealed surface 2) |

### What the user has to do today (workaround)

After this output, the user has to either:
1. **Ignore the warning and proceed** — works for `dev-template configure` because that flow uses `git remote get-url origin` (which works) for `GIT_REPO`, not the email. The bad email doesn't break the E2E.
2. **Run `dev-setup` and manually re-enter** the email and name they already have on their host.

Neither is acceptable as a long-term experience for new users.

## Finding from a real Windows PC (2026-09-25)

DCT 1.8.3 on a managed Windows PC (urb-agents #1536): the startup's host-info refresh showed `OS: unknown`, `User: unknown`, `Hostname: devcontainer` (the fallback). `remoteEnv` passes `${localEnv:COMPUTERNAME}` as `DEV_HOST_COMPUTERNAME`, but it was evidently not visible at that stage (possibly the ENTRYPOINT stage, which runs before `remoteEnv` applies; not verified). The same output's Docker Engine block showed the PC's real name (`docker info` Name), which could serve as a Windows fallback. Since 1.8.2, `initializeCommand` deliberately writes no `.host-hostname` on Windows.
