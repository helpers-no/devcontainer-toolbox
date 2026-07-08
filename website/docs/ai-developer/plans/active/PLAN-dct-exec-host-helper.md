# Plan: Host-Side `dct-exec` Helper (mirror of `uis-exec`, opposite direction)

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Give host-side scripts a reliable, documented way to find and exec into "the devcontainer for this repo," replacing the fixed `--name=devcontainer-toolbox` convention that image-mode (v1.7.38) correctly removed but didn't replace.

**GitHub Issue**: [#96](https://github.com/helpers-no/devcontainer-toolbox/issues/96)

**Last Updated**: 2026-07-08

**Scope**: macOS and Linux hosts only for v1. See "Out of Scope" below.

---

## Problem Summary

Image-mode dropped the fixed container name pin from `runArgs` in `devcontainer-user-template.json` — the right call, since a fixed name means only one devcontainer can run at a time, blocking multi-project use and the worktree-per-devcontainer pattern.

But nothing replaced it. Host-side scripts that used to `docker exec devcontainer-toolbox ...` by hardcoded name now silently fail, because the container gets a random Docker-assigned name. Confirmed regression: `helpers-no/sovdev-logger`'s three `specification/tools/*.sh` scripts all hardcode `CONTAINER_NAME="devcontainer-toolbox"` and now report "devcontainer not running" even when it is.

The fix is already proven out in the issue: every container created by the Dev Containers CLI carries a `devcontainer.local_folder` label with the host repo path, so it can be resolved deterministically:

```bash
docker ps --filter "label=devcontainer.local_folder=$(git rev-parse --show-toplevel 2>/dev/null || pwd)" --format '{{.Names}}'
```

This repo already has the mirror-image problem solved the other direction — `.devcontainer/manage/uis-exec.sh` resolves and execs into `uis-provision-host` *from inside* DCT. This plan builds the host → DCT equivalent, and (unlike `uis-exec`) also has to solve host-side *distribution*, since nothing today puts any devcontainer-toolbox binary on the host's `PATH`.

## Out of Scope (this plan)

**Windows is explicitly out of scope for v1.** `dct-exec`/`dct-find-container` are bash scripts. `install.ps1` installs DCT via native PowerShell (`irm | iex`) with no WSL requirement stated, so a `.sh` file won't run for a native-Windows user out of the box — there's no bash on `PATH` by default, and cmd.exe/PowerShell can't execute it directly. Separately, `plans/backlog/PLAN-windows-testing.md` already documents that "DCT was developed and tested exclusively on macOS... no Windows validation exists" for the project as a whole, so Windows support for this feature would inherit that unvalidated risk anyway.

`install.ps1` is **not** modified by this plan. Windows support (a `.ps1` port of both scripts, plus verifying whether the `devcontainer.local_folder` label format differs between a WSL2-filesystem project and a native-Windows-filesystem project) should be scoped as a separate follow-up plan once this v1 ships and macOS/Linux behavior is proven.

---

## Phase 1: Design the host installation mechanism — ✅ DONE

`install.sh` today only drops `.devcontainer/devcontainer.json` into the target project — it doesn't install anything onto the host `PATH`. This is new territory and needs a decision before writing code.

**Proposed default** (confirm with user before implementing): ship `dct-exec` and `dct-find-container` as standalone scripts in a new top-level `host-tools/` folder in this repo, and have `install.sh` copy them into `$HOME/.local/bin/` (creating it if needed, warning if it's not on `PATH`).

### Tasks

- [x] 1.1 Confirmed install target: `~/.local/bin` (Linux/macOS) — matches XDG convention, no sudo required
- [x] 1.2 Confirmed update behavior: re-running `install.sh` overwrites the existing `dct-exec`/`dct-find-container` (like it does for `.devcontainer.json`)

### Validation

User confirms the installation approach before Phase 2 starts.

---

## Phase 2: `dct-find-container` — resolve the container name — ✅ DONE (2.5 unverified)

### Tasks

- [x] 2.1 Created `host-tools/dct-find-container.sh`:
  - Resolves root via `git rev-parse --show-toplevel 2>/dev/null || pwd`
  - Filters running containers: `docker ps --filter "label=devcontainer.local_folder=$ROOT" --format '{{.Names}}'`
  - No match → checks `docker ps -a` too, so a *stopped* match gets a distinct "found but not running" message instead of a generic "not found"; exits 1
  - Multiple matches → prints all names, exits 1, does not silently pick one
  - Single match → prints the container name to stdout, exits 0
- [x] 2.2 Added `--help` output
- [x] 2.3 Manual test: ran against the real running `sovdev-logger` devcontainer (container `relaxed_nightingale`) from that repo's root — resolved correctly
- [x] 2.4 Manual test: ran from this repo (devcontainer-toolbox), which has no devcontainer currently running — got the clear "no devcontainer found" error, exit 1
- [ ] 2.5 Manual test: two worktrees of the same repo, each with its own devcontainer running — **not tested**, no second worktree available in this session. Logic should hold since labels differ by filesystem path, but unverified.

### Validation

`dct-find-container` prints exactly one container name (or a clear error) in the cases tested above. Multi-worktree case (2.5) still needs verification.

---

## Phase 3: `dct-exec` — exec into the resolved container — ✅ DONE (3.2 unverified)

Mirrors the TTY/stdin/non-TTY routing already solved in `.devcontainer/manage/uis.sh` (same problem, opposite direction) rather than re-deriving it.

### Tasks

- [x] 3.1 Created `host-tools/dct-exec.sh`:
  - Resolves container by shelling out to `dct-find-container` (prefers installed sibling without `.sh`, falls back to `.sh` for running straight from the repo, then `PATH`) — shelling out chosen over sourcing so `dct-find-container` stays independently usable/documented as its own tool (per the issue's "and/or a lighter dct-find-container" suggestion)
  - Interactive TTY (`-t 0` and `-t 1`): `docker exec -it <container> "$@"`
  - Piped stdin (`! -t 0`): `docker exec -i <container> "$@"`
  - Neither: `docker exec <container> "$@"`
  - No-args / `--help`: usage message, doesn't require a running container
- [ ] 3.2 Manual test: `dct-exec bash` gives an interactive shell — **not verified**: the tool environment used for this implementation session has no real TTY (`[ -t 0 ]`/`[ -t 1 ]` both false), so the `-it` branch can't be exercised here. The condition and `docker exec` flags are identical to `uis.sh`'s already-proven `-it` branch; needs a real terminal to confirm end-to-end.
- [x] 3.3 Manual test: `echo hi | dct-exec cat` — ran against the real `sovdev-logger` devcontainer, printed `hello from host` cleanly, exit 0
- [x] 3.4 Manual test: `dct-exec ls /workspace > out.txt` — ran against the real container, redirected cleanly (listed repo contents), exit 0

### Validation

Non-TTY and stdin-pipe modes verified against a real running devcontainer. Interactive TTY mode (3.2) still needs a real terminal to confirm.

---

## Phase 4: Wire into `install.sh` (macOS/Linux only) — ✅ DONE (4.3 partially verified)

### Tasks

- [x] 4.1 Updated `install.sh`: new step 6 downloads `host-tools/dct-exec.sh` and `host-tools/dct-find-container.sh` from `raw.githubusercontent.com/$REPO/main/...` into `~/.local/bin/{dct-exec,dct-find-container}` (no `.sh` suffix), `chmod +x`, prints install location. Gated on `uname -s` being `Linux` or `Darwin` (skipped on Windows). A failed download is a **warning, not a hard error** — it removes the partial file and continues, since the core devcontainer install already succeeded by this point and shouldn't be blocked by an optional host helper failing to fetch.
- [x] 4.2 If `$HOME/.local/bin` isn't on `PATH`, prints a one-line `export PATH=...` instruction
- [x] 4.3 Re-run behavior: overwrites existing files unconditionally (`curl -o`/`wget -O` always overwrite) — logic verified in isolation (see below), but not run via a real second `curl | bash` invocation of the full installer
- [x] 4.4 `install.ps1` is untouched by this plan — Windows users simply won't get `dct-exec` until the follow-up plan ships

**Testing note:** did not run `install.sh` end-to-end in this session — it backs up/replaces `.devcontainer/` and pulls the Docker image, too invasive to exercise just to test one step. Instead, extracted the new download/chmod loop into an isolated test script using `file://` URLs pointing at the local `host-tools/` files (standing in for `raw.githubusercontent.com`, which won't resolve for this branch until merged to `main`). Confirmed: both files download, get `chmod +x`, and the installed `dct-exec` (no `.sh` suffix) correctly finds its sibling `dct-find-container` and runs a real command in the `sovdev-logger` devcontainer successfully.

### Validation

Download/install/chmod logic verified in isolation against real files. The literal `curl -fsSL .../install.sh | bash` end-to-end flow (fresh machine, real GitHub URLs, full script including Docker pull) has **not** been run — needs verification after merge, since the `raw.githubusercontent.com/.../main/...` URLs only resolve once `host-tools/*.sh` exist on `main`.

---

## Phase 5: Documentation

### Tasks

- [ ] 5.1 Document `dct-exec` / `dct-find-container` in `website/docs/getting-started/` or wherever host-side tooling is currently documented (find the right home — check if one exists first)
- [ ] 5.2 Document the underlying `devcontainer.local_folder` label pattern directly, for maintainers who want to write their own host-side scripts instead of using `dct-exec`
- [ ] 5.3 Note the fix for `helpers-no/sovdev-logger` (or file a follow-up issue there) — that repo's three scripts should switch from hardcoded `CONTAINER_NAME` to `dct-find-container`/`dct-exec` once this ships
- [ ] 5.4 Run `cd website && npm run build` locally to catch broken links before pushing (per WORKFLOW.md's mandatory docs build check)

### Validation

A maintainer unfamiliar with this issue can find and use `dct-exec` from the docs alone.

---

## Acceptance Criteria

- [ ] `dct-find-container` resolves the correct running container for the current repo (and correctly for distinct worktrees)
- [ ] `dct-find-container` fails with a clear, actionable message when no container is running
- [ ] `dct-exec <command>` runs `<command>` inside the resolved container, with correct TTY/stdin/non-TTY routing
- [ ] `install.sh` installs both scripts onto the host `PATH` (or clearly instructs the user how to add the install dir to `PATH`)
- [ ] Re-running `install.sh` updates existing installs without duplication or leftover stale copies
- [ ] Scripts pass `shellcheck`
- [ ] Documented somewhere a project maintainer would find it, including that v1 is macOS/Linux only
- [ ] `install.ps1` is unmodified; no Windows artifacts shipped as part of this plan

---

## Implementation Notes

- **Reuse, don't re-derive.** `.devcontainer/manage/uis.sh` already solves TTY/stdin/non-TTY routing for the same class of problem (docker exec proxy) — copy that logic rather than reinventing it.
- **`docker ps` vs `docker ps -a`.** Only match *running* containers — `dct-exec` can't do anything useful with a stopped one. If nothing running matches but a stopped container does, the error message should say so explicitly ("found a stopped devcontainer for this repo — start it first") rather than "not found."
- **Label value format.** Confirm during Phase 2 whether `devcontainer.local_folder` is always an absolute path matching `git rev-parse --show-toplevel` exactly, or whether path normalization (symlinks, trailing slashes, case-sensitivity on macOS) needs handling.
- **Scope vs `uis-exec`.** `uis-exec` is a multi-call binary with per-command symlinks (`kubectl`, `helm`, `k9s`) because it's shimming *missing* tools inside DCT. `dct-exec` doesn't need that — the host already has its own `docker`, `git`, etc. Keep it a single generic `dct-exec <command> [args]`, no symlink shims.

---

## Files to Create/Modify

**New:**
- `host-tools/dct-find-container.sh`
- `host-tools/dct-exec.sh`

**Modify:**
- `install.sh` — copy new scripts to host `PATH`, report install location
- `website/docs/getting-started/` (or equivalent) — new documentation page/section

**Not modified (out of scope):**
- `install.ps1`

---

## Related

- `.devcontainer/manage/uis-exec.sh` — the mirror-image problem, solved the other direction
- `.devcontainer/manage/uis.sh` — TTY/stdin routing pattern to reuse (see `plans/active/PLAN-p1-dct-shim.md` for how it was built)
- `helpers-no/sovdev-logger` — the concrete repo currently broken by this gap
- `plans/backlog/PLAN-windows-testing.md` — tracks the project-wide lack of Windows validation; the Windows follow-up to this plan should build on whatever that work establishes
- **Follow-up (not this plan)**: `PLAN-dct-exec-windows-support.md` — port `dct-exec`/`dct-find-container` to PowerShell, verify `devcontainer.local_folder` label format on Windows (WSL2-filesystem vs. native-Windows-filesystem projects), wire into `install.ps1`
