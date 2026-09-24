---
mdx:
  format: md
---

# Azure DevOps Operations (`az` CLI)

How to operate Azure DevOps — pull requests, pipelines, work items — from the command line with the **Azure CLI (`az`)** and its **`azure-devops` extension**.

**Related:**

- [GIT.md](GIT.md) — git safety rules and branch/commit conventions (these still apply; this doc adds the Azure-DevOps-specific tooling)
- The repo's `project-*.md` — says whether this repo uses Azure DevOps or GitHub, and names the org/project/repo

---

## When this doc applies

This doc applies to repos whose `origin` is an Azure DevOps URL. Check:

```bash
git remote -v
# Applies if you see: https://dev.azure.com/<org>/<project>/_git/<repo>
```

If `origin` is a GitHub URL instead, ignore this doc and use the **GitHub Operations** (`gh`) section of [GIT.md](GIT.md). A repo uses one platform or the other, never both — the `project-*.md` states which.

---

## Prefer project wrappers when they exist

This doc describes the raw Azure DevOps `az` commands. If `project-*.md` names wrapper scripts for PR → merge → deploy, use those first. The raw `az` commands below are the reference for what those wrappers do and for anything they don't cover.

---

## Prerequisites: `az` + the `azure-devops` extension

**Do not assume `az` is installed or authenticated.** Check first:

```bash
az account show                                   # fails if az missing or not logged in
az extension list --query "[?name=='azure-devops'].version" -o tsv   # empty = extension not installed
```

### Installing `az` (cross-platform)

- **macOS** — `brew install azure-cli`
- **Windows** — `winget install -e --id Microsoft.AzureCLI` (or the MSI from [aka.ms/installazurecliwindows](https://aka.ms/installazurecliwindows))
- **Linux (Debian/Ubuntu)** — `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`
- **Linux (RHEL/Fedora)** — `sudo dnf install azure-cli` (after importing the Microsoft key — see docs)

Other distros and details: [learn.microsoft.com/cli/azure/install-azure-cli](https://learn.microsoft.com/cli/azure/install-azure-cli).

Then add the DevOps extension and set defaults so you don't repeat `--organization`/`--project` on every command:

```bash
az extension add --name azure-devops
az devops configure --defaults \
  organization=https://dev.azure.com/<org> project=<project>
```

### Authentication — the AI cannot do this step

`az login` is **interactive** (it opens a browser). The AI **cannot** run it on the user's behalf. When auth is missing, ask the user to run it themselves:

> Please run `az login` (in Claude Code, type `! az login` so the output shows here), then tell me when `! az account show` succeeds.

Verify before proceeding:

```bash
az account show --query "{name:name, user:user.name}" -o json
```

**On the subscription/tenant picker:** `az login` lists your Azure *subscriptions* and asks you to pick one. For Azure DevOps work (`az repos`, `az pipelines`, `az boards`), **which subscription you pick does not matter** — those commands authenticate to the DevOps *organization* using your login token, not an Azure subscription. What matters is logging into the **correct tenant** — the one that backs the DevOps org (for this repo, `Norges Røde Kors`, org `ExampleOrg`). If that tenant has no subscriptions you can access, `az login --allow-no-subscriptions` still gives you the token DevOps needs.

(CI/pipelines authenticate non-interactively with a service principal or PAT instead — see this repo's `add-service.yaml` for that pattern. Local development uses `az login`.)

---

## Safety rules

The [GIT.md](GIT.md) safety rules apply in full. In addition:

- **Completing/merging a PR is outward-facing and often triggers a deploy.** In this repo, merging to `main` auto-deploys to the test environment. Treat "complete the PR" like a push to a shared branch: **confirm with the user first.**
- **Never bypass branch policies.** If a PR can't be completed because of required reviewers or build validation, report that it needs approval — do not try to force it.
- **Don't set auto-complete without asking** — it merges the moment policies pass, which may be after the user has stepped away.

---

## Common operations

### Pull requests (`az repos pr`)

```bash
# Create a PR from the current feature branch to main
az repos pr create \
  --repository <repo> \
  --source-branch <feature-branch> --target-branch main \
  --title "docs: short summary" \
  --description "What changed and why."

# List active PRs
az repos pr list --status active -o table

# Show one PR (get its id, status, policy state)
az repos pr show --id <pr-id>

# Complete (merge) a PR — outward-facing, confirm first.
# This repo's branch policy FORBIDS the default merge-commit type — you must squash:
az repos pr update --id <pr-id> --status completed --squash true --delete-source-branch true

# Set auto-complete instead of merging now (merges when policies pass) — ask first
az repos pr update --id <pr-id> --auto-complete true

# Add a reviewer / link a work item
az repos pr reviewer add --id <pr-id> --reviewers <email-or-id>
az repos pr work-item add --id <pr-id> --work-items <work-item-id>
```

`az repos pr create` prints the new PR's `pullRequestId` — capture it for the follow-up `show`/`update` calls. Add `--open` to open the PR in a browser.

### Pipelines (`az pipelines`)

```bash
az pipelines list -o table                         # all pipelines in the project
az pipelines run --name "<pipeline-name>"           # queue a run
az pipelines run --id <pipeline-id> --branch <ref>  # run a specific pipeline/branch
az pipelines show --name "<pipeline-name>"          # pipeline definition + default branch
az pipelines runs list --pipeline-ids <id> -o table # recent runs (status, result)
az pipelines runs show --id <run-id>                # one run's detail
```

### Work items (`az boards work-item`)

```bash
az boards work-item show --id <id>
az boards work-item create --title "..." --type "User Story"
az boards work-item update --id <id> --state "Closed"
```

### Repos (`az repos`)

```bash
az repos list -o table
az repos show --repository <repo>
```

---

## Tips and gotchas

- **Set `az devops configure --defaults`** for org + project once; otherwise pass `--organization https://dev.azure.com/<org> --project <project>` on every call.
- **Output format**: append `-o table` for humans, `-o tsv --query <jmespath>` to capture a single value in scripts.
- **PR can't complete** → it's almost always a branch policy (required reviewers, build validation, linked work items, comment resolution). `az repos pr show --id <id>` reveals the policy state. Surface it to the user; don't work around it.
- **`The chosen merge type is forbidden by policy`** → this repo requires a **squash** merge; the default merge-commit type is blocked. Re-run the complete with `--squash true` (see the complete command above). After a squash merge the feature branch is not an ancestor of `main`, so delete the local branch with `git branch -D` (not `-d`), and align local `main` with `git pull` (or `git reset --hard origin/main` if it diverged).
- **Stale git auth on shared agents** (`TF401019` / "could not read Password") — clear `http.extraheader` git config. This repo's `add-service.yaml` does exactly this in its pre-cleanup step.
