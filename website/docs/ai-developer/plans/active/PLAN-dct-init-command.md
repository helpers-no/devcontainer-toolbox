# Plan: `dct-init` — One Command to Set Up Any Project Folder

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: After the first install, a user sets up any new project folder by typing **`dct-init`** in it, on every machine: Windows or Mac, managed or unmanaged.

**Priority**: High — today the experience depends on how the PC was set up.

**Last Updated**: 2026-09-25

**Related**: [PLAN-fix-windows-quickstart](PLAN-fix-windows-quickstart.md), [PLAN-host-installer-handover](../backlog/PLAN-host-installer-handover.md), [helpers-no/client-provisioning](https://github.com/helpers-no/client-provisioning)

---

## Problem

| Installed by | Puts on the PC | Set up a new folder with |
|---|---|---|
| client-provisioning (Intune/Jamf, managed PCs) | `devcontainer-init` (Windows: Program Files, on PATH; Mac too) | `devcontainer-init` |
| DCT `irm … \| iex` (Windows, any PC) | nothing, only files in the current folder | the whole `irm` line again |
| DCT `curl … \| bash` (Mac/Linux) | `dct-exec`, `dct-find-container` (run commands *in* a container) | the whole `curl` line again |

client-provisioning's `devcontainer-init` also does less than DCT's installer: it downloads DCT's template from `main` unpinned, does not check that Rancher Desktop is running, and does not install the Dev Containers extension.

## Decision (Terje, 2026-09-25)

- **DCT installs the command itself**, per user and without admin, as part of its installer. **Nobody uses `devcontainer-init` today**, so the name is free to choose.
- **Name: `dct-init`**, alongside `dct-exec` and `dct-find-container` (confirmed by Terje, 2026-09-25).
- **Rule (Terje, 2026-09-25): every `dct-*` command is installed by DCT's own install script**, the one that downloads `devcontainer.json` (`install.ps1` / `install.sh`), on every platform. Not by client-provisioning, and not by anything else. Today `install.sh` installs `dct-exec` and `dct-find-container` on Mac/Linux, and **`install.ps1` installs none**, so Windows needs PowerShell versions of both (Phase 2b).
- DCT owns `devcontainer.json` (contract with client-provisioning, urb-agents #1505), so client-provisioning's `devcontainer-init` is retired, or becomes a call to `dct-init`. That change is theirs to make.

## Design

- **`dct-init` holds the install logic.** Everything `install.ps1` / `install.sh` does today for a folder moves into it:
  - check Rancher Desktop is installed, visible and running
  - refuse system folders ([PLAN-fix-windows-quickstart](PLAN-fix-windows-quickstart.md) task 2.7)
  - back up an existing `.devcontainer/`, refusing when a backup already exists
  - write `devcontainer.json`
  - write `.vscode/extensions.json`
  - install the extension
  - pull the image
  - print plain messages
- **`install.ps1` / `install.sh` become a small bootstrap.** They install `dct-init` for the user, then run it once in the current folder. The Quick Start command stays the same.
- **Where it lives (no admin):**
  - Windows: `%LOCALAPPDATA%\devcontainer-toolbox\bin\` with `dct-init.ps1` and a `dct-init.cmd` shim, added to the **user** PATH.
  - Mac/Linux: `~/.local/bin/dct-init`, next to `dct-exec`.
- **Exit codes become possible.** A script file (unlike `irm | iex`) can exit without closing the user's window, so `dct-init` implements the contract's codes: `0` done, `1` prerequisite missing, `2` download/network, `3` target folder, with `ERRnnn` on the error line. client-provisioning calls `dct-init -TargetDir <path>` instead of fetching `install.ps1`.
- **Updating:** running the Quick Start line again replaces `dct-init`. Whether `dct-init` should update itself is out of scope for the first version.

## Risk to verify first: PowerShell execution policy

`irm | iex` is not subject to the execution policy, but a `.ps1` **file** is. The Windows client default (`Restricted`) blocks it. The `.cmd` shim can run `powershell -NoProfile -ExecutionPolicy Bypass -File dct-init.ps1`, but **a policy enforced through Intune/Group Policy (for example `AllSigned`) overrides `Bypass`**, and then an unsigned `dct-init.ps1` does not run. That would break `dct-init` exactly on managed PCs.

**Phase 1 checks this on Terje's managed PC before anything is built.** If the policy blocks it, the options are code-signing the script (needs a certificate the PC trusts: an organisation decision) or keeping `dct-init` inside a signed or allowed wrapper.

---

## Phase 1: Check execution policy on a managed PC — ✅ DONE

### Tasks

- [x] 1.1 On Terje's managed PC, record `Get-ExecutionPolicy -List`.
- [x] 1.2 Create a one-line test `.ps1` plus `.cmd` shim in the user's profile, the same way `dct-init` would be installed, and check it runs from a new PowerShell window by typing its name.
- [x] 1.3 Decide with Terje: go ahead unsigned, sign it, or change the design.

**Result (Terje's managed PC, urb-agents #1541, 2026-09-25):** the real `dct-init` install from the branch ran **without `ERR006`**, so neither `MachinePolicy` nor `UserPolicy` enforces `AllSigned` or `Restricted`. `dct-init.cmd` then ran `dct-init.ps1` from `%LOCALAPPDATA%` **by name in a new window**. Decision: go ahead unsigned. (#1539's dummy-script test was superseded by this real one; the `Get-ExecutionPolicy -List` table itself was not pasted.)

### Validation

A written result in this plan: the policy values and whether the shim ran.

---

## Phase 2: `dct-init` for Windows and Mac/Linux — IN PROGRESS

### Tasks

- [x] 2.1 Move the per-folder logic from `install.ps1` / `install.sh` into `dct-init`, keeping every message and check that works today.
- [x] 2.2 Parameters: `-TargetDir` / `--target-dir` (default: current folder); no prompts; never elevates; safe to run twice.
- [x] 2.3 Exit codes and `ERRnnn` lines as in the contract.
- [x] 2.4 `install.ps1` / `install.sh`: install `dct-init` per user (plus PATH), then run it in the current folder. Tell the user in one sentence that next time they can just type `dct-init` in a new folder (in a new window).

**As built (2026-09-25):**

- **Files:**
  - `host-tools/dct-init.sh` (installed as `~/.local/bin/dct-init`)
  - `host-tools/dct-init.ps1` + `host-tools/dct-init.cmd` (installed to `%LOCALAPPDATA%\devcontainer-toolbox\bin`, which is added to the user PATH)
- **The bootstraps:** `install.sh` / `install.ps1` are now bootstraps that install the commands and run `dct-init` once. `install.sh` installs all three `dct-*` commands; `install.ps1` only `dct-init` until Phase 2b.
- **Checks `dct-init` does:**
  - Rancher Desktop installed, visible and running
  - VS Code (checked up front)
  - Intel Mac (`ERR005`)
  - system folders, the drive root and the home folder (`ERR011`; fix-plan task 2.7)
  - an existing backup is never overwritten (`ERR012`; fix-plan task 2.4)
  - a note when run as administrator
- **Exit codes** 0/1/2/3 with `ERRnnn`, per the contract.
- **Execution policy:** `install.ps1` stops with `ERR006` when Group Policy/Intune enforces `AllSigned` or `Restricted`; `-ExecutionPolicy Bypass` in the `.cmd` shim does not override an enforced policy, and the installer does not try to work around one.
- **For tests:** `DCT_INSTALL_SOURCE` installs from a checkout instead of GitHub.
- **Verified locally:**
  - bash, via `install.sh` with a throwaway HOME and stub `docker`/`code`: every case returns the contract's exit code (not running 1, pull fails 2, system folder / missing folder / home / backup exists 3, success 0), and `install.sh` passes it on; `dct-init` works by name in a new folder.
  - PowerShell 7 on Linux, `install.ps1` run via `Invoke-Expression` like the Quick Start: not running / success / rerun-with-backup / backup-exists (3), with the session kept alive and `$ErrorActionPreference` untouched.
  - Lint: shellcheck, PSScriptAnalyzer (0 findings apart from `PSAvoidUsingWriteHost`), actionlint; `.ps1` files are plain ASCII (Windows PowerShell 5.1 reads BOM-less files as ANSI).
- **Verified on Windows:** the `Host Commands` jobs on PR #105 (9/9 checks on `windows-latest`, Linux green), then **Terje's managed PC** (urb-agents #1541): the first install, `dct-init` by name in a new window (exit 0), and Rancher stopped (`ERR003`, exit 1, nothing written).
- **Fixed after the PC test:** `dct-init -TargetDir C:\Windows\System32` with Rancher stopped reported `ERR003` (1) instead of `ERR011` (3), because prerequisites were checked before the folder, which cost the user two round trips. The **folder is now checked first** (both scripts), with a regression check in both CI jobs.

### Validation

Stub-`docker` tests like 1.8.3's, for `dct-init` itself: each failure case returns its exit code and writes nothing. Plus a CI job on `windows-latest` that installs `dct-init` and runs it by name from a fresh shell.

---

## Phase 2b: `dct-exec` and `dct-find-container` for Windows

The rule above requires them on Windows too; today they are bash-only (their plan, PLAN-dct-exec-host-helper, left Windows out of v1).

### Tasks

- [ ] 2b.1 Port both to PowerShell (`dct-exec.ps1`, `dct-find-container.ps1`, each with a `.cmd` shim), installed by `install.ps1` in the same user folder as `dct-init`.
- [ ] 2b.2 Check how the `devcontainer.local_folder` label looks for a Windows project path (drive letter, backslashes), which the bash version never had to handle. Verify on Terje's PC against a running container.
- [ ] 2b.3 Interactive (`dct-exec bash`) and piped (`echo hi | dct-exec cat`) cases, as in the bash version.

### Validation

On Terje's PC, in a project folder with a running devcontainer: `dct-find-container` prints its name and `dct-exec bash` opens a shell in it.

---

## Phase 3: Docs, client-provisioning, release

### Tasks

- [ ] 3.1 Quick Start and Getting Started: "next time, type `dct-init` in a new project folder".
- [ ] 3.2 Tell client-provisioning (bus): `dct-init -TargetDir` is the call, and their `devcontainer-init` can go.
- [ ] 3.3 Test on Terje's PC: first install via the Quick Start, then `dct-init` in a second, new folder.
- [ ] 3.4 Release: bump `version.txt`.

### Validation

On Terje's PC a second folder is set up with `dct-init` alone and opens in its container.

---

## Acceptance Criteria

- [ ] After the Quick Start, `dct-init` works by name in a new window on Windows and Mac
- [ ] Every `dct-*` command is installed by `install.ps1` / `install.sh`, on Windows as well as Mac/Linux
- [ ] It never needs admin, and it returns the contract's exit codes
- [ ] client-provisioning calls `dct-init` and ships no copy of its own
- [ ] Execution policy on managed PCs is checked, and handled

## Files to Modify

- `install.ps1`, `install.sh` (become bootstraps)
- new `dct-init.ps1`, `dct-init.cmd`, `dct-init` (bash)
- new `dct-exec.ps1`, `dct-find-container.ps1` and their `.cmd` shims (in `host-tools/`)
- `.github/workflows/host-commands.yml` (dct-init job), tests
- `website/docs/getting-started.md`, `website/docs/index.md`, `README.md`
- `version.txt`
