# Investigate: Auto-Detect Git Identity from Host

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Automatically detect the developer's git name and email from the host machine so the devcontainer never shows `vscode@localhost`.

**Priority**: High — every new user sees a broken git identity on first start

**Last Updated**: 2026-04-07

**Related**: [INVESTIGATE-simplify-initial-dct-experience.md](INVESTIGATE-simplify-initial-dct-experience.md)

---

## Problem

On first container start, git identity shows:
```
✅ Git identity detected:
   Email:    vscode@localhost
```

This is the container default — not the developer's real identity. Commits made with this identity are attributed to `vscode@localhost`, which causes problems with GitHub/Azure DevOps.

The startup warns about it but tells the user to "run dev-setup" which requires navigating a menu. Most users ignore it and commit with the wrong identity.

---

## What Already Exists

### Entrypoint reads host git identity files

`image/entrypoint.sh` (lines 62-76) already looks for:
- `.devcontainer.secrets/env-vars/.git-host-name`
- `.devcontainer.secrets/env-vars/.git-host-email`

If these files exist, it applies them with `git config --global`. The files are expected to be written by an `initializeCommand` — but the current `initializeCommand` only captures hostname, not git identity.

### Host has the git config

On the developer's host machine, `git config user.name` and `git config user.email` are almost always configured (required for any git work). The data exists — we just need to capture it.

---

## Proposed Solution

Extend the existing `initializeCommand` to also capture git identity:

```json
"initializeCommand": "mkdir -p .devcontainer.secrets/env-vars && hostname -s > .devcontainer.secrets/env-vars/.host-hostname 2>/dev/null || hostname > .devcontainer.secrets/env-vars/.host-hostname 2>/dev/null || true && git config user.name > .devcontainer.secrets/env-vars/.git-host-name 2>/dev/null || true && git config user.email > .devcontainer.secrets/env-vars/.git-host-email 2>/dev/null || true"
```

This runs on the **host** before the container starts. The entrypoint already reads these files and applies them.

### What changes

| Before | After |
|--------|-------|
| Container starts with `vscode@localhost` | Container starts with host's git identity |
| User must manually configure via `dev-setup` | Automatic — zero configuration |
| `.git-host-name` / `.git-host-email` files never created | Created by `initializeCommand` on every start |

### Cross-platform

| Platform | `git config user.name` works? |
|----------|------------------------------|
| macOS | Yes — git is pre-installed or via Xcode CLI tools |
| Linux | Yes — git is standard |
| Windows (Git Bash) | Yes |
| Windows (PowerShell) | Yes — if Git for Windows is installed |
| Windows (WSL2) | Yes — if git is installed in WSL |

The `|| true` ensures it doesn't break if git isn't configured on the host.

---

## Questions to Answer

1. **initializeCommand length** — it's getting long (hostname + git name + git email). Should we move it to a script file? But the script needs to exist before the container starts — it's in the workspace, so it should work.

2. **What if the host has no git config?** — Files are empty or don't exist. Entrypoint falls back to current behavior (`vscode@localhost`). No worse than today.

3. **What about users with different git identities per repo?** — `git config user.name` without `--global` reads the repo-level config first, then global. If the user has a repo-specific identity, that's what gets captured. This is correct behavior.

4. **Privacy** — The git identity is stored in `.devcontainer.secrets/` which is gitignored. It's also the same identity that would be in git commits — not a new exposure.

5. **Should we also capture the git signing key?** — Future enhancement, not needed for the identity problem.

---

## Alternative: Use remoteEnv to pass git config

We could add to `remoteEnv`:
```json
"DEV_HOST_GIT_NAME": "${localEnv:GIT_AUTHOR_NAME}",
"DEV_HOST_GIT_EMAIL": "${localEnv:GIT_AUTHOR_EMAIL}"
```

But `GIT_AUTHOR_NAME` and `GIT_AUTHOR_EMAIL` are rarely set as env vars. They're usually in `~/.gitconfig`, not the environment. So `${localEnv:...}` would be empty for most users. The `git config` command in `initializeCommand` is the reliable source.

---

## Implementation Estimate

This is a small change:
1. Extend `initializeCommand` in `devcontainer-user-template.json` (one line)
2. The entrypoint already handles the files — no code changes needed
3. Test on Mac (verify git identity is captured and applied)

The entrypoint code at lines 62-76 is already written and tested. We just need to create the files it reads.

---

## Next Steps

- [ ] Extend `initializeCommand` to capture `git config user.name` and `git config user.email`
- [ ] Test: fresh install → container starts → git identity shows real name/email
- [ ] Test: host has no git config → graceful fallback to `vscode@localhost`
- [ ] Consider moving `initializeCommand` to a script file (getting long)
- [ ] Update startup message — remove "Git identity not configured" warning when identity is auto-detected

## Finding from a real Windows PC (2026-09-25)

DCT 1.8.3 on a managed Windows PC (urb-agents #1536): git identity came out as `vscode@localhost`, provider `local`. Nothing captures the host's git identity on Windows today. The February Windows-specific `initializeCommand` did (`git config --global user.name/email > .devcontainer.secrets\env-vars\.git-host-*`), but it was dropped with the shared template on 2026-02-17 (`d07e842`); the current command only captures the hostname, and only on Mac/Linux.
