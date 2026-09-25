# Fix: Windows Quick Start Does Not Work

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: A Windows user who follows the Quick Start on [dct.sovereignsky.no/docs](https://dct.sovereignsky.no/docs/) gets a running devcontainer.

**Priority**: High — every new Windows install is affected. Reported by Terje, 2026-09-24.

**Last Updated**: 2026-09-25

**Related**: [PLAN-windows-testing](PLAN-windows-testing.md) (broader Windows validation; this plan fixes the known defects first)

---

## Problem

### 1. `initializeCommand` is bash-only, and Windows runs it with `cmd.exe` (main defect)

`devcontainer-user-template.json` has:

```
mkdir -p .devcontainer.secrets/env-vars && hostname -s > .devcontainer.secrets/env-vars/.host-hostname 2>/dev/null || hostname > .devcontainer.secrets/env-vars/.host-hostname 2>/dev/null || true
```

**Mechanism (verified in upstream source):** `devcontainers/cli` `src/spec-node/utils.ts`, `runInitializeCommand` (lines 559–560): on Windows a string command runs as `[ComSpec || 'cmd.exe', '/c', <string>]`, elsewhere as `['/bin/sh', '-c', <string>]`. A non-zero exit aborts container startup.

In `cmd.exe`, `mkdir -p` with forward slashes fails, the `||` chain ends at `true`, which does not exist in `cmd.exe`, and the command exits non-zero. So VS Code cannot start the container.

**History (verified in git):**

| Date | Commit | What happened |
|---|---|---|
| 2026-02-03 | `c4d7f6c`, `2078f13` | `install.ps1` wrote a cmd.exe-specific `initializeCommand`, ending in `& ver >nul` to force exit code 0 |
| 2026-02-17 | `d07e842` | One shared `devcontainer-user-template.json` for all platforms; the Windows command was dropped |
| 2026-04-07 | `733dd73` | A bash-only `initializeCommand` was added to the shared template (host hostname capture) |

**Not yet reproduced on Windows** — no Windows machine was available. The failure follows from the mechanism above; Phase 1's CI job and Phase 3 confirm it.

### 2. `install.ps1` closes the user's PowerShell window on error

The Quick Start runs it as `irm … | iex`, so the script runs inside the user's own session. `exit 1` (used in three places: lines 22, 54, 61) therefore closes the user's terminal before they can read the error. `$ErrorActionPreference = "Stop"` also stays set in their session afterwards.

### 3. `install.ps1` says "installed!" after a failed `docker pull`

`docker pull` is a native command; its exit code is never checked. If Rancher Desktop is not running, the pull fails and the script still prints success.

### 4. The Quick Start block mixes Mac/Linux and Windows

`website/docs/index.md` (and `README.md`) put the `curl … | bash` line and the `irm … | iex` line in one `bash` code block. The copy button copies both. In PowerShell 5.1 `curl` is an alias for `Invoke-WebRequest`, so the first line fails with a parameter error.

---

## Phase 1: Cross-shell `initializeCommand`

### Tasks

- [ ] 1.1 Replace the template's `initializeCommand` with one string that is valid in both shells:

  ```
  ver || sh -c "mkdir -p .devcontainer.secrets/env-vars && { hostname -s 2>/dev/null || hostname; } > .devcontainer.secrets/env-vars/.host-hostname; true"
  ```

  - `cmd.exe`: `ver` succeeds (exit 0), so `||` skips the rest. The quoted part is one argument, so `cmd.exe` does not interpret the `&&`, `>` or `{ }` inside it.
  - `/bin/sh`: `ver` does not exist, so `||` runs the capture, which ends in `true` (exit 0).
  - Windows does not need the file: `config-host-info.sh` checks `DEV_HOST_COMPUTERNAME` (from `${localEnv:COMPUTERNAME}`) before it reads the file (lines 76–87).
  - Measured on macOS 2026-09-25: exit 0 and the same `.host-hostname` content as today's command. The side effect is one `ver: command not found` line in the startup log.
- [ ] 1.2 CI: add a `windows-latest` job that reads `initializeCommand` from `devcontainer-user-template.json` and runs it with `cmd.exe /c` in a temp folder. It must exit 0. Also run the Linux side with `/bin/sh -c` and check that `.host-hostname` is non-empty. This guards against the regression coming back; nothing tested the Windows side before.
- [ ] 1.3 Add a comment next to the command (in the contributor docs, since JSON has no comments) saying it runs under `cmd.exe` on Windows and must stay valid in both shells.

### Validation

The CI job is green on `windows-latest` and `ubuntu-latest`. The command still works on macOS: `.host-hostname` is written.

---

## Phase 2: `install.ps1` is safe to run with `irm | iex`

### Tasks

- [ ] 2.1 Wrap the script body in a scriptblock (`& { … }`), so `$ErrorActionPreference` stays local to it, and replace every `exit 1` with an error message plus `return`. The user's window stays open and shows what went wrong.
- [ ] 2.2 Check `$LASTEXITCODE` after `docker pull`. On failure, say "Is Rancher Desktop running?" and stop without printing "installed!".
- [ ] 2.3 CI: in the `windows-latest` job, run `install.ps1` in a temp folder with `docker` missing from `PATH`. It must print the Docker error and leave the PowerShell process running (the job's next step still executes).

### Validation

The CI job is green. The script still works end to end on a Windows machine (Phase 3).

---

## Phase 3: Docs, and a real Windows run

### Tasks

- [ ] 3.1 Split the Quick Start in `website/docs/index.md` and `README.md` into two blocks: a `bash` block for Mac/Linux and a `powershell` block for Windows, so each copy button copies one command.
- [ ] 3.2 **Needs a Windows machine (Terje, or someone he names):** in an empty folder, run the Quick Start from the site, open it in VS Code, and choose "Reopen in Container". The container must start, and `dev-help` must run.
- [ ] 3.3 Release: bump `version.txt` (PATCH).

### Validation

Terje confirms 3.2 on Windows. `npm run build` passes for the docs change.

---

## Acceptance Criteria

- [ ] A fresh Windows install from the published Quick Start reaches a running container
- [ ] `initializeCommand` is tested on Windows in CI
- [ ] `install.ps1` never closes the user's window, and never reports success after a failed pull
- [ ] Each Quick Start copy button copies one platform's command

## Files to Modify

- `devcontainer-user-template.json`
- `install.ps1`
- `.github/workflows/ci-tests.yml` (new `windows-latest` job)
- `website/docs/index.md`, `README.md`
- `website/docs/contributors/architecture/devcontainer-json.md` (note on `initializeCommand`)
- `version.txt`

## Not in this plan

- PowerShell 5.1 on old Windows 10 builds may default to TLS 1.0 *before* the script's own TLS 1.2 line runs, so `irm` itself could fail. Current Windows 10/11 is not affected; handle it in [PLAN-windows-testing](PLAN-windows-testing.md) if it shows up.
