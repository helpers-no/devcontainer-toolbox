# Fix: Windows Quick Start Does Not Work

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: A Windows user who follows the Quick Start on [dct.sovereignsky.no/docs](https://dct.sovereignsky.no/docs/) gets a running devcontainer.

**Who this is for**: ordinary Windows office users with no knowledge of git, containers or Docker (Terje, 2026-09-25). Every message this plan touches must be plain language with the next action spelled out. This plan fixes the defects in today's script; installing the prerequisites for the user (WSL, Rancher Desktop, VS Code) belongs to [helpers-no/client-provisioning](https://github.com/helpers-no/client-provisioning) (decision 2026-09-25, see [PLAN-host-installer-handover](../backlog/PLAN-host-installer-handover.md)).

**Priority**: High — every new Windows install on a PC without Unix tools on PATH (the normal office PC) is affected. Reported by Terje, 2026-09-24.

**Last Updated**: 2026-09-25

**Related**: [PLAN-host-installer-handover](../backlog/PLAN-host-installer-handover.md) (DCT's side of the host-installer split), [helpers-no/client-provisioning](https://github.com/helpers-no/client-provisioning) (the host installer), [PLAN-windows-testing](../backlog/PLAN-windows-testing.md) (broader Windows validation)

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

## Phase 1: Cross-shell `initializeCommand` — IN PROGRESS

### Tasks

- [x] 1.1 Replace the template's `initializeCommand` with one string that is valid in both shells:

  ```
  ver || sh -c "mkdir -p .devcontainer.secrets/env-vars && { hostname -s 2>/dev/null || hostname; } > .devcontainer.secrets/env-vars/.host-hostname; true"
  ```

  - `cmd.exe`: `ver` succeeds (exit 0), so `||` skips the rest. The quoted part is one argument, so `cmd.exe` does not interpret the `&&`, `>` or `{ }` inside it.
  - `/bin/sh`: `ver` does not exist, so `||` runs the capture, which ends in `true` (exit 0).
  - Windows does not need the file: `config-host-info.sh` checks `DEV_HOST_COMPUTERNAME` (from `${localEnv:COMPUTERNAME}`) before it reads the file (lines 76–87).
  - Measured on macOS 2026-09-25: exit 0 and the same `.host-hostname` content as today's command. The side effect is one `ver: command not found` line in the startup log.
- [ ] 1.2 CI: add a `windows-latest` job that reads `initializeCommand` from `devcontainer-user-template.json` and runs it with `cmd.exe /c` in a temp folder. It must exit 0. Also run the Linux side with `/bin/sh -c` and check that `.host-hostname` is non-empty. This guards against the regression coming back; nothing tested the Windows side before.
  - **As built (2026-09-25):** a separate workflow, `.github/workflows/host-commands.yml`, not `ci-tests.yml`. `ci-tests.yml` only triggers on `.devcontainer/**` and builds the whole image first, and the template lives at the repo root. The Windows job runs the command through the **real devcontainers CLI** (`@devcontainers/cli@0.89.0`, `devcontainer up`), so it takes the same `cmd.exe /c` path, quoting included, as VS Code does. A **control step** runs the old bash-only command (`.github/fixtures/host-commands/bash-only-initialize-command.json`) and must see it fail, which proves the check can detect the bug. Script: `.github/scripts/test-initialize-command.ps1`.
  - **First run on GitHub (PR #102, 2026-09-25):** the new command passed through the real CLI on `windows-latest`. **The control did not fail**: `cmd.exe` printed "The syntax of the command is incorrect." and "The system cannot find the path specified.", but the old command still exited 0, because the runner has Git for Windows' `usr\bin` (with `true.exe`) on PATH. A normal office PC does not. The script now strips Git/MSYS/Cygwin Unix tool folders from PATH and refuses to run if a Unix `true` is still found. That also sharpens the bug: it hits PCs **without** Unix tools on PATH, which is the normal case.
- [x] 1.3 Add a comment next to the command (in the contributor docs, since JSON has no comments) saying it runs under `cmd.exe` on Windows and must stay valid in both shells.
  - Done in `contributors/architecture/devcontainer-json.md` and `startup-lifecycle.md`. Both still showed the old command and claimed `.host-hostname` is written on Windows; corrected.

### Validation

The CI job is green on `windows-latest` and `ubuntu-latest`. The command still works on macOS: `.host-hostname` is written.

---

## Phase 2: `install.ps1` is safe to run with `irm | iex`

### Tasks

- [x] 2.1 Wrap the script body in a scriptblock (`& { … }`), so `$ErrorActionPreference` stays local to it, and replace every `exit 1` with an error message plus `return`. The user's window stays open and shows what went wrong.
  - Done 2026-09-25: the body runs in `& { ... }`, every `exit 1` is now `return`. Tested in PowerShell with `Get-Content install.ps1 -Raw | Invoke-Expression`: the session survives every failure and the caller's `$ErrorActionPreference` is untouched. **Exit codes for callers (PLAN-host-installer-handover 2.2) are not done yet**: inside `irm | iex` there is no exit code without closing the window, so that needs a separate, non-`iex` entry point.
- [x] 2.2 **Confirmed on Terje's PC (urb-agents #1536, 2026-09-25):** with Rancher Desktop not running, `docker pull` failed (`failed to connect to the docker API at npipe:////./pipe/docker_engine`) and the script still printed "devcontainer-toolbox installed!". Check `$LASTEXITCODE` after `docker pull`. On failure, stop without printing "installed!" and say what to do in plain words, for example: "Rancher Desktop is not running. Start Rancher Desktop from the Start menu, wait until it says it is ready, then run this again."
  - Done 2026-09-25: step 1 now checks, before anything is written, whether Rancher Desktop is installed (user and system install paths), visible to this window (`docker` on PATH), and **running** (`docker info`), each with a plain message saying what to do (Terje: "the user must be notified that rancher must be running"). A failed `docker pull` stops without "installed!". `install.sh` got the same messages and now names Rancher Desktop instead of Docker Desktop. Tested with stub `docker` commands in PowerShell and bash; **not yet on Windows**.
- [ ] 2.3 Rewrite every message the script prints for a non-developer: no "PATH", "Docker CLI" or "image" without explanation; each error says what happened and the one thing to do next. The missing-Docker case uses the handover sentence from [PLAN-host-installer-handover](../backlog/PLAN-host-installer-handover.md) Phase 2.
- [ ] 2.4 Stop deleting the user's previous backup: `install.ps1` removes an existing `.devcontainer.backup/` without asking (lines 30–31), so a second run loses the original setup. Refuse instead, with a plain message, the way `install.sh` already does. Found by client-provisioning (urb-agents #1505).
- [x] 2.5 Install the VS Code Dev Containers extension as the user (`code --install-extension ms-vscode-remote.remote-containers`), finding `code` even when it is not on PATH yet (user and system install paths). If VS Code is missing, stop with a plain message. VS Code itself comes from Intune (Terje, 2026-09-25). The shared spec is [PLAN-host-installer-handover](../backlog/PLAN-host-installer-handover.md) task 2.8.
  - **Done 2026-09-25, pulled forward for Terje's PC test**, in `install.ps1` and `install.sh` (step 4b). Finds `code` on PATH, else in the user and system install folders (Windows) or the app bundle (macOS); skips when `code --list-extensions` already lists it. **Limit until 2.1:** if VS Code is missing it prints a plain warning and continues, rather than exiting `1`, because `exit` inside `irm | iex` would close the user's window.
  - Checked: `install.sh` shellcheck clean; its step 4b run against a stub `code` (installs when missing, skips when present) and, with no `code` on PATH, it found this Mac's real VS Code in the app bundle. `install.ps1` parses with 0 errors and has 0 PSScriptAnalyzer findings apart from `PSAvoidUsingWriteHost` (the script has always used `Write-Host`). **Not run on Windows yet.**
- [ ] 2.7 **Refuse to install into a system or unsuitable folder.** Found on Terje's PC (urb-agents #1536): he ran it in an administrator PowerShell, which opens in `C:\Windows\System32`, and the script created `.devcontainer\` and `.vscode\` there. A non-developer does not know to change folders first. Refuse `$env:SystemRoot` and anything under it, `Program Files`, and the drive root. For the user's home folder itself, offer a work folder instead (for example `$HOME\DevContainer-Toolbox\<name>`) rather than writing into it. Also warn when running elevated: nothing in `install.ps1` needs admin.
- [ ] 2.6 CI: in the `windows-latest` job, run `install.ps1` in a temp folder with `docker` missing from `PATH`. It must print the Docker error and leave the PowerShell process running (the job's next step still executes).

### Validation

The CI job is green. The script still works end to end on a Windows machine (Phase 3).

---

## Phase 3: Docs, and a real Windows run

### Tasks

- [ ] 3.1 Split the Quick Start in `website/docs/index.md` and `README.md` into two blocks: a `bash` block for Mac/Linux and a `powershell` block for Windows, so each copy button copies one command.
- [ ] 3.1b Correct the Windows prerequisites in `website/docs/getting-started.md`: Rancher Desktop needs **Windows 11** x64 (not Windows 10), and `wsl --install` also installs Ubuntu, which asks for a Linux username the user does not need. Point to the "What your computer needs" page from [PLAN-host-installer-handover](../backlog/PLAN-host-installer-handover.md) when it exists.
- [ ] 3.2 **Needs a Windows machine (Terje, or someone he names):** in an empty folder, run the Quick Start from the site, open it in VS Code, and choose "Reopen in Container". The container must start, and `dev-help` must run.
- [ ] 3.3 Have one non-developer office user do 3.2 from the site alone, with Rancher Desktop and VS Code already installed, and note every point where they got stuck. Pass those notes to the owner of [helpers-no/client-provisioning](https://github.com/helpers-no/client-provisioning) through the bus.
- [ ] 3.4 Release: bump `version.txt` (PATCH).

### Validation

Terje confirms 3.2 on Windows. `npm run build` passes for the docs change.

---

## Acceptance Criteria

- [ ] A fresh Windows install from the published Quick Start reaches a running container
- [ ] `initializeCommand` is tested on Windows in CI
- [ ] `install.ps1` never closes the user's window, never reports success after a failed pull, and every message tells a non-developer what to do next
- [ ] Each Quick Start copy button copies one platform's command

## Files to Modify

- `devcontainer-user-template.json`
- `install.ps1`
- `.github/workflows/ci-tests.yml` (new `windows-latest` job)
- `website/docs/index.md`, `README.md`, `website/docs/getting-started.md`
- `website/docs/contributors/architecture/devcontainer-json.md` (note on `initializeCommand`)
- `version.txt`

## Not in this plan

- PowerShell 5.1 on old Windows 10 builds may default to TLS 1.0 *before* the script's own TLS 1.2 line runs, so `irm` itself could fail. Current Windows 10/11 is not affected; handle it in [PLAN-windows-testing](../backlog/PLAN-windows-testing.md) if it shows up.
