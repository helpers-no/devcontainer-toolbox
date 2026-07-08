# Plan: Phase 1 DCT Work — uis Shim + Namespace/Secret Flags

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Ship DCT's two Phase 1 items from `INVESTIGATE-improve-template-docs-with-services.md`: (1.8) the `uis` shim that lets users type bare `uis ...` commands inside DCT, and (1.9) updates to `dev-template-configure` to pass `--namespace` and `--secret-name-prefix` to UIS.

**Priority**: High — 1.8 unblocks TMP's README rewrites; 1.9 fixes the deploy-time crash-loop bug.

**Last Updated**: 2026-07-08

**Note**: Phases 1 and 2 code shipped in commits `41fa00a` (feat: uis shim + dev-template-configure passes namespace + secret-name-prefix) and `b33988a` (feat: dev-template configure verbose output + v1.7.36), released in v1.7.36+. This doc was stale — it hadn't been updated since 2026-04-09 despite the work landing. Task 1.5 (four-input-mode test) and Phase 3 (end-to-end verification with TMP's rewritten templates) have no recorded confirmation, so their checkboxes remain unchecked below.

**Investigation**: `helpers-no/dev-templates` → `INVESTIGATE-improve-template-docs-with-services.md` (active)

**Cross-team dependencies**:
- 1.8: zero dependencies, can start immediately
- 1.9: depends on UIS 1.10 (`uis configure --namespace`/`--secret-name-prefix` flags + new JSON fields)

---

## Overview

The Phase B integration work (completed 2026-04-06) confirmed the architecture works end-to-end, but real-user testing of `python-basic-webserver-database` surfaced UX problems:

1. **C2: "uis: command not found" from inside DCT.** Users see `uis configure` in docs and try to run it. The CLI lives inside the `uis-provision-host` container — not in DCT. The workaround is `docker exec uis-provision-host uis ...` everywhere, which makes READMEs unreadable.

2. **Deploy-time crash-loop.** The template's `deployment.yaml` references a Kubernetes Secret (`{{REPO_NAME}}-db`) that doesn't exist in the cluster. ArgoCD deploys the app, the pod tries to read the secret, fails, crash-loops.

This plan ships the DCT half of the fix.

---

## Phase 1: The `uis` shim (1.8) — ✅ CODE DONE (1.5 unverified)

### Tasks

- [x] 1.1 Add `uis_bridge_run_tty()` function to `.devcontainer/manage/lib/uis-bridge.sh`:
  ```bash
  uis_bridge_run_tty() {
      docker exec -it "$UIS_CONTAINER" uis "$@"
  }
  ```
- [x] 1.2 Created `.devcontainer/manage/uis.sh` with TTY/stdin/no-TTY routing + help fast path
  ```bash
  #!/bin/bash
  # /usr/local/bin/uis — DCT shim for the UIS CLI
  set -e
  source /opt/devcontainer-toolbox/manage/lib/uis-bridge.sh

  # Fast path: help/no-args output is local-only — don't require UIS container
  case "${1:-}" in
      ""|help|--help|-h)
          # Print DCT-flavoured usage that mentions the shim
          # Falls back to running 'uis help' if container is up; otherwise shows local message
          if uis_bridge_check 2>/dev/null; then
              uis_bridge_run_tty "$@"
          else
              cat <<'EOF'
  uis — UIS CLI (proxied from DCT via docker-outside-of-docker)

  Usage: uis <command> [args]

  This is a DCT shim that forwards commands to the uis-provision-host
  container. UIS provides commands for managing data services, deployments,
  templates, and more.

  Common commands (require uis-provision-host running):
    uis status               Show status of all UIS components
    uis deploy <service>     Deploy a service (postgresql, redis, ...)
    uis configure <service>  Configure a service for an app
    uis connect <service>    Connect to a service (psql, redis-cli, ...)
    uis template install <id>  Install a UIS stack template
    uis expose <service>     Expose a service via port-forward

  ⚠️  uis-provision-host container is not running.
      Start it from the urbalurba-infrastructure repo.
  EOF
              exit 0
          fi
          ;;
      *)
          uis_bridge_check || exit 1
          if [ -t 0 ] && [ -t 1 ]; then
              uis_bridge_run_tty "$@"
          elif [ ! -t 0 ]; then
              uis_bridge_run_stdin "$@"
          else
              uis_bridge_run "$@"
          fi
          ;;
  esac
  ```
- [x] 1.3 Added `uis` symlink in `image/Dockerfile` (alongside config-host-info)
- [x] 1.4 `chmod +x` already covered by existing `chmod +x /opt/devcontainer-toolbox/manage/*.sh` block
- [ ] 1.5 Test all four input modes (needs new image build):
  - Interactive TTY: `uis status` (should show formatted output, no garbled escape codes)
  - Piped stdin: `echo "SELECT 1;" | uis configure postgresql --init-file -` (should work, no TTY allocated)
  - Non-TTY no stdin: `uis status > out.txt` (should redirect cleanly)
  - Container down: `docker stop uis-provision-host && uis status` (should print clear error)
  - Help fast path: `docker stop uis-provision-host && uis help` (should print local help, exit 0)

### Validation

`uis help` works regardless of UIS state. `uis status`, `uis connect`, `uis configure` work when UIS is running. README rewrites can drop the `docker exec uis-provision-host` noise.

---

## Phase 2: `dev-template-configure` passes namespace + secret name prefix (1.9) — ✅ DONE

UIS 1.10 shipped 2026-04-09 (PR #121, all 6 tester verification steps PASS). Confirmed present in code (`dev-template-configure.sh` lines ~361-382) as of 2026-07-08.

### Tasks

- [x] 2.1 Resolved `namespace` from `${PARAMS[subdomain]:-${PARAMS[app_name]:-$GIT_REPO}}` — done in `_configure_service`
- [x] 2.2 Resolved `secret_name_prefix` from `$GIT_REPO` (matches deployment.yaml `{{REPO_NAME}}-db`)
- [x] 2.3 Pass both as new args via `extra_args` array — `uis_bridge_configure` already forwards them transparently
- [x] 2.4 `uis_bridge_configure` already forwards arbitrary args via `"$@"` — no change needed
- [x] 2.5 Updated JSON parsing in `uis-bridge.sh`: added `UIS_SECRET_NAME`, `UIS_SECRET_NAMESPACE`, `UIS_SECRET_ENV_VAR` globals, parsed in both `ok` and `already_configured` branches, reset on each call
- [x] 2.6 Updated completion message: shows `→ .env: DATABASE_URL=... (local)` and `→ K8s Secret: my-app-db in namespace my-app (cluster)` when UIS returned secret fields. Falls back to writing `.env.cluster` for legacy callers (no GIT_REPO, older UIS).
- [x] 2.7 Sourced `git-identity.sh` in `dev-template-configure.sh` and call `detect_git_identity` early to populate `GIT_REPO`

### Validation

After running `dev-template-configure` on `python-basic-webserver-database`:
- `.env` contains a working local URL
- `kubectl get secret <repo-name>-db -n <namespace>` shows the secret exists
- `kubectl get namespace <namespace>` shows the namespace exists
- Re-running is idempotent (UIS returns `already_configured`)
- The secret's `DATABASE_URL` key matches the manifest's `secretKeyRef`
- A pod deployed via `kubectl apply -f manifests/deployment.yaml` would NOT crash-loop on missing secret

---

## Phase 3: Test end-to-end with TMP's rewritten templates

### Tasks (after TMP finishes 1.5/1.6 README rewrites)

- [ ] 3.1 In a fresh DCT devcontainer with UIS running, follow the new `python-basic-webserver-database` README literally:
  - `dev-template python-basic-webserver-database`
  - Edit `template-info.yaml` params
  - `dev-template-configure`
  - Run the Flask app, confirm `/tasks` returns seeded rows
- [ ] 3.2 Verify `uis connect postgresql <db>` from the new "Verify" section works
- [ ] 3.3 Verify `uis status postgresql` from the "Before you start" section works
- [ ] 3.4 Verify `uis help` works even when the UIS container is stopped
- [ ] 3.5 Test `kubectl get secret <repo>-db -n <namespace>` shows the secret with correct key

### Validation

End-to-end happy path works with zero `docker exec` mentions in the README.

---

## Acceptance Criteria

Items below marked `(code confirmed 2026-07-08)` were verified by reading the shipped source; they are not runtime-tested. Items with no annotation still need a live check.

- [x] `/usr/local/bin/uis` symlink exists in `image/Dockerfile`, pointing at `.devcontainer/manage/uis.sh` (code confirmed 2026-07-08)
- [x] `uis_bridge_run_tty()` function added to `lib/uis-bridge.sh` (code confirmed 2026-07-08)
- [ ] `uis help` / `uis --help` / `uis -h` / `uis` (no args) work without UIS container running
- [ ] All other `uis ...` commands fail clearly when container is down, work when up
- [ ] Stdin pipe (`uis configure ... --init-file -`) routes via `docker exec -i` without TTY
- [ ] Interactive TTY (`uis connect postgresql mydb`) routes via `docker exec -it`
- [x] `dev-template-configure` passes `--namespace` and `--secret-name-prefix` to UIS (code confirmed 2026-07-08, `dev-template-configure.sh` ~L361-382)
- [x] `uis-bridge.sh` reads new JSON fields (`secret_name`, `secret_namespace`, `env_var`) (code confirmed 2026-07-08)
- [x] `dev-template-configure` completion message mentions both local and cluster secret (code confirmed 2026-07-08)
- [ ] Re-run of `dev-template-configure` is idempotent (UIS returns `already_configured`)
- [ ] CI passes (static + unit + image build)
- [ ] Tested in fresh devcontainer with TMP's rewritten templates

---

## Files to Create/Modify

**New:**
- `.devcontainer/manage/uis.sh` — the shim

**Modify:**
- `.devcontainer/manage/lib/uis-bridge.sh` — add `uis_bridge_run_tty()`, update `uis_bridge_configure()` to forward new flags, update JSON parsing
- `.devcontainer/manage/dev-template-configure.sh` — resolve namespace + secret_name_prefix, pass to bridge, update completion message
- `image/Dockerfile` — add `uis` symlink

**No template changes needed** — Option A (use existing `{{REPO_NAME}}` placeholder) means the deployment.yaml stays as-is.

---

## Cross-team coordination

| Item | DCT depends on | DCT blocks |
|---|---|---|
| 1.8 (shim) | Nothing | TMP 1.5, 1.6, 1.7, 1.12 (README rewrites) |
| 1.9 (--namespace) | UIS 1.10 (--namespace flag in `uis configure`) | Nothing — TMP READMEs reference the result, not the flag |

**Recommended sequence (from TMP 7MSG):**
- Day 1: DCT starts 1.8 (this plan Phase 1) in parallel with TMP and UIS
- Day 2-3: DCT 1.8 lands → TMP can rewrite postgresql-demo README
- Day 2-3: UIS 1.10 lands → DCT starts 1.9 (this plan Phase 2)
- Day 3-5: DCT Phase 3 verification once TMP READMEs are ready
