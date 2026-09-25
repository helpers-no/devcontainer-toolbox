# Plan: Finish the Move from terchris to helpers-no

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: `helpers-no/devcontainer-toolbox` is the only home of DCT: the repo, the image, and the fork network.

**Priority**: Medium — nothing is broken for current users; this removes leftovers that mislead.

**Last Updated**: 2026-09-24

---

## Problem

The repository was created as `terchris/devcontainer-toolbox` and transferred to `helpers-no` (code references changed in `2b9b83a`, 2026-03-18). State measured 2026-09-24:

| What | State |
|---|---|
| Repo | Transferred. `terchris/devcontainer-toolbox` URLs (git and raw) redirect to `helpers-no`. ✅ |
| Code | No live code path references `terchris`. ✅ |
| Container image | Was: `ghcr.io/terchris/devcontainer-toolbox` left behind at 1.7.6 (packages do not follow a repo transfer). Now deleted (Phase 2). ✅ |
| Fork network | Was: `helpers-no` registered as a fork of `norwegianredcross/devcontainer-toolbox`. Now reversed (Phase 1). ✅ |

**Decision (Terje, 2026-09-24): no migration path for users installed before the move.** Projects that still name `ghcr.io/terchris/...` keep the image they already have, but fail on their next rebuild until someone re-runs the installer in them.

### Why the fork link matters

- GitHub's web UI defaults new pull requests to the **parent** repo (`norwegianredcross`). One wrong click sends a PR to the wrong org.
- Forks are excluded from GitHub code search unless they have more stars than the parent, so DCT is hard to find.
- The "forked from norwegianredcross/devcontainer-toolbox" banner says the Red Cross repo is upstream, which is no longer true.

---

## Phase 1: Reverse the fork network — ✅ DONE (2026-09-24)

Goal (Terje): the repo lives on `helpers-no`, and `norwegianredcross` has a fork of it. Terje manages both orgs and chose Route B: delete the old repo and re-fork, rather than ask GitHub Support to detach.

### Tasks

- [x] 1.1 Checked what the old `norwegianredcross/devcontainer-toolbox` held: 19 issues/PRs (only #15 open, "Add health-check for wget", already solved by `install.sh`/`install.ps1`), 2 releases, 5 stars, empty wiki. Its one unique commit (`2afcd8a`, ARM PowerShell fix, #16) changed files that no longer exist; `install-tool-powershell.sh` already handles arm64.
- [x] 1.2 Backed it up first: git mirror (52 commits, tags, all PR refs), issues/PRs with comments, both release assets, repo metadata.
- [x] 1.3 Deleted `norwegianredcross/devcontainer-toolbox`. GitHub made `helpers-no/devcontainer-toolbox` the root of the network (`fork=false`); its three existing forks now point at it.
- [x] 1.4 Forked `helpers-no/devcontainer-toolbox` into `norwegianredcross` under the same name.

### Validation

Measured 2026-09-24: `helpers-no/devcontainer-toolbox` has `fork=false`; `norwegianredcross/devcontainer-toolbox` has `fork=true`, `parent=helpers-no/devcontainer-toolbox`, and the same `main` head (`ab76ba0`).

---

## Phase 2: Delete the old image — ✅ DONE (2026-09-25)

### Tasks

- [x] 2.1 Terje chose to delete it ("so that we don't have any more confusion"). Checked first: `ghcr.io/terchris/devcontainer-toolbox` held 1.7.0–1.7.6 (2026-02-16 to 2026-03-04, `latest` = 1.7.6), linked to no repo. Deleted with `DELETE /user/packages/container/devcontainer-toolbox`. GitHub allows restoring a deleted package for 30 days.
- [x] 2.2 The repo redirect `github.com/terchris/devcontainer-toolbox` → `helpers-no` stays. It cannot be switched off without creating a new repo of that name, which would break old links and create the confusion this plan removes.

### Validation

Measured 2026-09-25: the package API returns 404 for `terchris/devcontainer-toolbox`; the registry refuses `ghcr.io/terchris/devcontainer-toolbox:latest`; `ghcr.io/helpers-no/devcontainer-toolbox:latest` still returns 200.

---

## Phase 3: Sweep what is left

### Tasks

- [ ] 3.1 Local clones: `git remote set-url origin https://github.com/helpers-no/devcontainer-toolbox.git`. Redirects work today, but they break silently if anyone ever creates a new `terchris/devcontainer-toolbox`.
- [ ] 3.2 Leave historical mentions alone: blog author `terchris` (correct, it is the person), old recordings, completed plans in this repo and in `urbalurba-infrastructure`.

### Validation

`grep -rn 'terchris/devcontainer-toolbox'` only finds history (plans, recordings, blog).

---

## Acceptance Criteria

- [x] `helpers-no/devcontainer-toolbox` is not a fork
- [x] The `terchris` image is deleted or marked as moved
- [ ] No live code path references `terchris`

## Not in this plan

The Windows `initializeCommand` failure (a bash-only command run by `cmd.exe`, regressed in `733dd73`) is a separate bug. It hits new Windows installs whatever the image name is, and gets its own plan.
