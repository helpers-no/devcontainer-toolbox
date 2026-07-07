# Plan: install.sh Hardening + Stale /workspace/.devcontainer Path Cleanup

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Fix four rough edges in `install.sh` and the image scripts it sets up, found while migrating `sovdev-logger` to the image-based model — silent backup loss, unhelpful `docker pull`/daemon errors, and five scripts that still hardcode the old vendored-toolbox path instead of `$DCT_HOME`.

**GitHub Issue**: #94

**Priority**: Medium — not a regression blocking anyone today, but issue #4 (hardcoded paths) actively pollutes a consuming project's git working tree when `service-otel` is enabled.

**Last Updated**: 2026-07-07

---

## Problem Summary

`install.sh` is the curl-to-bash entry point for first-time installs (and re-installs when migrating from the old vendored `.devcontainer/` layout). Four issues surfaced in one migration pass (full detail in #94):

1. `docker pull "$IMAGE"` (line 105) has no error handling. A stale/empty `"ghcr.io": {}` entry in `~/.docker/config.json` causes a cryptic `denied` on a genuinely public image, sending users down an auth-debugging rabbit hole.
2. The backup step (lines 24-31) does `rm -rf .devcontainer.backup` before `mv .devcontainer .devcontainer.backup`. If a user re-runs the script after a failed step (e.g. the `docker pull` failure above), their first backup is silently destroyed.
3. The Docker check (line 15) only verifies the `docker` CLI exists (`command -v docker`), not that the daemon is running. Users with Docker Desktop installed but stopped get a raw `Cannot connect to the Docker daemon` error deep in step 5 instead of a clear message up front.
4. Five image scripts still hardcode `/workspace/.devcontainer/...` — the old path where the toolbox was vendored directly into a project's repo. In the new model, the toolbox lives at `$DCT_HOME` (`/opt/devcontainer-toolbox`, set via `remoteEnv` in `devcontainer-user-template.json`), and `.devcontainer/` in a consuming project contains only `devcontainer.json`. Worst case: `install-srv-otel-monitoring.sh` writes config into the *consuming project's git working tree* at `.devcontainer/additions/otel/` when `service-otel` is enabled, instead of staying inside the image.

---

## Phase 1: Fix docker pull error handling — ✅ DONE

### Tasks

- [x] 1.1 In `install.sh`, wrap `docker pull "$IMAGE"` (line 105) in an `if ! ... ; then` check
- [x] 1.2 On failure, print an error that names the likely cause and fix:
  ```
  Error: Failed to pull ghcr.io/helpers-no/devcontainer-toolbox:latest

  This image is public and does not require a Docker login. If you saw "denied",
  try clearing any stale ghcr.io credentials:
      docker logout ghcr.io
  then re-run this script.
  ```
- [x] 1.3 `exit 1` on failure

### Validation

```bash
IMAGE="ghcr.io/helpers-no/nonexistent-image:latest" bash install.sh
# Should print the friendly error and exit 1, not a raw docker error
```

User confirms message is clear.

---

## Phase 2: Stop the installer from destroying prior backups — ✅ DONE

### Tasks

- [x] 2.1 In `install.sh`, replace the unconditional `rm -rf .devcontainer.backup` (line 27) with a check: if `.devcontainer.backup` already exists, abort with a clear message instead of overwriting it
  ```
  Error: .devcontainer.backup/ already exists.

  Remove or rename it before re-running this script, e.g.:
      mv .devcontainer.backup .devcontainer.backup.old
  ```
- [x] 2.2 `exit 1` in that case, before touching `.devcontainer`

### Validation

```bash
mkdir -p .devcontainer .devcontainer.backup
echo "keep-me" > .devcontainer.backup/marker
bash install.sh
# Should abort with the message above; .devcontainer.backup/marker must still exist
cat .devcontainer.backup/marker  # prints "keep-me"
```

User confirms re-running after a failure never loses a prior backup.

---

## Phase 3: Check Docker daemon is running, not just installed — ✅ DONE

### Tasks

- [x] 3.1 After the existing `command -v docker` check in `install.sh` (line 15), add a `docker info >/dev/null 2>&1` check
- [x] 3.2 On failure, print:
  ```
  Error: Docker is installed but not running.

  Please start Docker Desktop (or Rancher Desktop / Colima) and try again.
  ```
- [x] 3.3 `exit 1` on failure

### Validation

```bash
# With Docker Desktop stopped:
bash install.sh
# Should print the "installed but not running" message before attempting any pull
```

User confirms message appears before step 5 (image pull), not after.

---

## Phase 4: Repoint hardcoded /workspace/.devcontainer paths to $DCT_HOME — ✅ DONE

**Scope expanded during implementation**: a repo-wide grep after fixing the original 5 issue-#94 spots turned up more functional (not just cosmetic) hardcodes with the identical root cause — most notably `service-otel-monitoring.sh`, the script that actually *runs* otel monitoring, which would have failed to find its config at all in image mode even after fixing the installer. User approved folding these into this phase rather than a follow-up.

### Tasks

- [x] 4.1 `.devcontainer/additions/install-srv-otel-monitoring.sh:42` — change `OTEL_CONFIG_DIR="/workspace/.devcontainer/additions/otel"` to `OTEL_CONFIG_DIR="${DCT_HOME:-/opt/devcontainer-toolbox}/additions/otel"`; also fix the stale `# file: .devcontainer/additions/install-srv-otel-monitoring.sh` header comment
- [x] 4.2 `.devcontainer/additions/config-supervisor.sh:44` — change `ADDITIONS_DIR="/workspace/.devcontainer/additions"` to `ADDITIONS_DIR="${DCT_HOME:-/opt/devcontainer-toolbox}/additions"`
- [x] 4.3 `.devcontainer/additions/lib/tool-auto-enable.sh:16` — change `EVENT_NOTIFICATION_SCRIPT="/workspace/.devcontainer/additions/otel/scripts/send-event-notification.sh"` to use `${DCT_HOME:-/opt/devcontainer-toolbox}`
- [x] 4.4 `.devcontainer/additions/lib/service-auto-enable.sh:16` — change `AUTO_ENABLE_GENERATOR="/workspace/.devcontainer/additions/config-supervisor.sh"` to use `${DCT_HOME:-/opt/devcontainer-toolbox}`
- [x] 4.5 `.devcontainer/additions/lib/environment-utils.sh` — removed `setup_devcontainer_path()` and `setup_command_symlinks()` entirely (also removed the now-unused `add_to_bashrc` dependency-check block they were the sole caller of); both were dead-weight no-ops in the new model since `image/Dockerfile` already symlinks every `dev-*` command into `/usr/local/bin` (confirmed: `dev-setup`, `dev-help`, `dev-check`, `dev-docs`, `dev-env`, `dev-services`, `dev-test`, `dev-template`, `dev-update`, `dev-logos`, `dev-cubes`, `dev-log`, `dev-tools`, `uis`, `uis-exec` + aliases)
- [x] 4.6 `.devcontainer/manage/postCreateCommand.sh` — removed the `setup_devcontainer_path` and `setup_command_symlinks` calls in `main()`, and the stale doc comment referencing them
- [x] 4.7 Left `.devcontainer/additions/lib/environment-utils.sh`'s `/workspace/.devcontainer/devcontainer.json` checks, `dev-welcome.sh`'s intentional `$DCT_HOME`-first/workspace-fallback dual-mode logic, and the `.devcontainer.extend/enabled-*.conf` paths unchanged — those correctly refer to the project's own `.devcontainer/`, not the vendored toolbox
- [x] 4.8 (added) `.devcontainer/additions/service-otel-monitoring.sh:78-80` — `CONFIG_FILE_LIFECYCLE`, `CONFIG_FILE_METRICS`, `SCRIPT_EXPORTER_CONFIG` repointed to `${DCT_HOME:-/opt/devcontainer-toolbox}/additions/otel/...`. This is the runtime service script (distinct from the installer fixed in 4.1) — without this fix otel monitoring would fail to start in image mode even after 4.1
- [x] 4.9 (added) `.devcontainer/additions/otel/scripts/devcontainer-info.sh:8,18` and `send-tools-inventory.sh:17` — `LIB_DIR`/`ADDITIONS_DIR` repointed to `${DCT_HOME:-/opt/devcontainer-toolbox}/additions`
- [x] 4.10 (added) `.devcontainer/additions/otel/script-exporter-config.yaml` and `otelcol-metrics-config.yaml` — these are YAML read literally by `script_exporter`/documented for `otelcol-contrib`, not shell-expanded, so the 6 occurrences of `/workspace/.devcontainer/additions/otel` were replaced with the literal `/opt/devcontainer-toolbox/additions/otel` (matches the fixed `DCT_HOME` set in `image/Dockerfile`). The `command:` fields in `script-exporter-config.yaml` are live config, not comments — this was a real functional bug (script_exporter would fail to find `devcontainer-info.sh`/`rancher-vm-k8s-status.sh`)
- [x] 4.11 (added) `.devcontainer/additions/tailscale/start-tailscale.sh:23` — `SERVICE_COMMAND` repointed to `${DCT_HOME:-/opt/devcontainer-toolbox}/additions/tailscale/start-tailscale.sh`; also fixed a pre-existing separate bug where the path was missing the `tailscale/` subdirectory segment entirely, plus the stale file/usage header comments

### Validation

```bash
grep -rn "/workspace/.devcontainer/additions\|/workspace/.devcontainer/manage" .devcontainer/
# Should return nothing

grep -n "setup_devcontainer_path\|setup_command_symlinks" .devcontainer/manage/postCreateCommand.sh .devcontainer/additions/lib/environment-utils.sh
# Should return nothing
```

Rebuild the image and confirm:
- `dev-services` (enables `service-otel`) writes config under `/opt/devcontainer-toolbox/additions/otel/`, not into the mounted project repo
- No stray `.devcontainer/additions/otel/` folder appears in a test project after enabling otel monitoring
- `postCreateCommand.sh` runs clean with no missing-function errors

User confirms end-to-end in a fresh devcontainer.

---

## Acceptance Criteria

- [ ] `docker pull` failure in `install.sh` prints a clear, actionable error and exits non-zero
- [ ] Re-running `install.sh` after a failure never silently deletes an existing `.devcontainer.backup/`
- [ ] `install.sh` detects a stopped Docker daemon before attempting any pull, with a clear message
- [ ] No script under `.devcontainer/` hardcodes `/workspace/.devcontainer/additions` or `/workspace/.devcontainer/manage` — all use `${DCT_HOME:-/opt/devcontainer-toolbox}`
- [ ] `setup_devcontainer_path()` / `setup_command_symlinks()` removed from `environment-utils.sh` and `postCreateCommand.sh`
- [ ] Enabling `service-otel` no longer writes into the consuming project's git working tree
- [ ] `install.sh` passes shellcheck
- [ ] CI passes (static + unit + image build)
- [ ] Tested end-to-end: fresh install, re-install-after-failure, daemon-stopped, otel-enabled scenarios

---

## Files to Modify

- `install.sh`
- `.devcontainer/additions/install-srv-otel-monitoring.sh`
- `.devcontainer/additions/config-supervisor.sh`
- `.devcontainer/additions/lib/tool-auto-enable.sh`
- `.devcontainer/additions/lib/service-auto-enable.sh`
- `.devcontainer/additions/lib/environment-utils.sh`
- `.devcontainer/manage/postCreateCommand.sh`
- `.devcontainer/additions/service-otel-monitoring.sh` (added — Phase 4 scope expansion)
- `.devcontainer/additions/otel/scripts/devcontainer-info.sh` (added)
- `.devcontainer/additions/otel/scripts/send-tools-inventory.sh` (added)
- `.devcontainer/additions/otel/script-exporter-config.yaml` (added)
- `.devcontainer/additions/otel/otelcol-metrics-config.yaml` (added, comments only)
- `.devcontainer/additions/tailscale/start-tailscale.sh` (added)

---

## Implementation Notes

- Phases 1-3 only touch `install.sh` and are independent of Phase 4 — could ship as a quick patch release on their own if preferred.
- Phase 4 is the one with real-world impact today (otel config leaking into project repos) but touches more files; keep it as its own phase so a failure there doesn't block the `install.sh` fixes.
- There's already one active plan (`PLAN-p1-dct-shim.md`). Per the "one active plan at a time" guideline, this plan should stay in `backlog/` until that one completes, unless the user wants to run them concurrently.
