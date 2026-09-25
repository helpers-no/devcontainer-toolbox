# Plan: DCT's Side of the Host Installer Split

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: A non-developer gets from DCT's website to a running devcontainer with **one command**, while DCT itself never installs host software.

**Priority**: High — this is who DCT is for on Windows.

**Last Updated**: 2026-09-25

**Related**: [PLAN-fix-windows-quickstart](../active/PLAN-fix-windows-quickstart.md) (defects in today's `install.ps1`), [helpers-no/client-provisioning](https://github.com/helpers-no/client-provisioning) (the host installer)

---

## Decision (Terje, 2026-09-25)

| Repo | Owns | Needs admin? |
|---|---|---|
| **helpers-no/client-provisioning** — "the machine is ready" | WSL, Rancher Desktop, VS Code + Dev Containers extension, elevation, restart and resume, Intune/Jamf packages, and the one-script installer for non-developers | Yes |
| **devcontainer-toolbox** (this repo) — "the project is ready" | `devcontainer.json`, the image, everything inside the container, **and the VS Code Dev Containers extension** (per user). `install.ps1` / `install.sh` stay small and never need admin | No |

**Amended 2026-09-25 (Terje):** VS Code itself comes from **Intune**, which already deploys it on managed PCs (on unmanaged PCs, from client-provisioning's installer if it chooses). The **Dev Containers extension is installed by DCT's script**: it is per user and needs no admin. Recorded with client-provisioning in urb-agents #1533.

The user still sees **one command** on DCT's website. client-provisioning's installer prepares the machine and, as its **last step, runs DCT's own `install.ps1` / `install.sh`**. DCT stays the only place that writes `devcontainer.json`.

**Why the split** (the advice Terje accepted):

- Host provisioning is a different job: Windows internals, admin rights, restarts, Intune/Jamf policy.
- It needs different testing (real Windows 11 / Mac machines, managed and unmanaged).
- It has a different release pace (a Rancher Desktop pin bump must not force a DCT image release).
- It carries a different risk: an admin-elevated script from a public repo belongs where changes are rare and strictly reviewed, fetched from a release tag.
- client-provisioning already holds tested Rancher Desktop, WSL-features and Mac packages.

The full investigation of the one-script installer (the user, vendor findings, managed machines, prior art, options) moved to client-provisioning with its new owner agent. It was handed over through the fleet bus.

**Owner of client-provisioning:** the fleet agent `client-provisioning` (onboarded 2026-09-25, urb-agents #1492).

**Contract agreed with it on 2026-09-25 (urb-agents #1505).** Phases 1–3 below are written to that agreement. Nothing in it has run on a managed Windows 11 PC or a Jamf Mac yet.

---

## Phase 1: Document what DCT needs from the host

### Tasks

- [ ] 1.1 Add one page, **"What your computer needs"**, as the single list both repos work from. Plain language first, exact values in a table:
  - **Windows 11, build ≥ 22000, x64.** Rancher Desktop no longer supports Windows 10.
  - **WSL 2, installed without a Linux distribution.** It's the step with the restart.
  - **macOS 13 (Ventura) or later, Apple Silicon (M1 or later).** Intel Macs are out of scope (Terje, urb-agents #1511, passed on in #1514). The macOS minimum comes from the Rancher Desktop 1.24 docs ("macOS 13 (Ventura) or higher"); client-provisioning's Mac check uses the same number.
  - **Memory and CPU:** Rancher Desktop 1.24 recommends 8 GB of memory and 4 CPUs on both Windows and macOS. Many office laptops sit exactly at 8 GB, so state it as recommended, not required.
  - **Rancher Desktop ≥ 1.24.0**, engine `moby`, Kubernetes off.
  - **VS Code** (from Intune on managed PCs). The `ms-vscode-remote.remote-containers` extension is **not** a prerequisite: DCT's script installs it.
  - **Virtualization** on.
  - **Free disk: DCT owns this number.** Measure the image size on disk and state it × 2, in GB.
- [ ] 1.2 Publish the same values as a machine-readable **`host-requirements.json`**, so client-provisioning's checks read DCT's numbers instead of copying them.
- [ ] 1.3 Link the page from Getting Started and the Quick Start.

### Validation

client-provisioning confirms its installer checks against the page / `host-requirements.json`. `npm run build` passes.

---

## Phase 2: `install.ps1` / `install.sh` as a callable, pinned last step

### Tasks

- [ ] 2.1 **Interface:** `-TargetDir <path>` / `--target-dir <path>`, no interactive prompts, **never elevates**, safe to run twice on the same folder. client-provisioning runs it un-elevated, as the user, after its admin steps and the restart.
- [ ] 2.2 **Exit codes:** `0` done, `1` a prerequisite is missing (runtime not installed or not running, no VS Code), `2` download or network failure, `3` target folder problem. Never use `3010` / `1641` (they mean "restart required" to client-provisioning and Intune). Each error line carries an **`ERRnnn`** code, which client-provisioning passes through verbatim for support calls.
- [ ] 2.3 **Absorb what client-provisioning's `devcontainer-init` does**, so it can retire it:
  - Back up an existing `.devcontainer/` to `.devcontainer.backup/`, and **refuse when a backup already exists**. `install.sh` already refuses; **`install.ps1` silently deletes the old backup** (lines 30–31), so a second run loses the user's original setup. That fix is shared with [PLAN-fix-windows-quickstart](../active/PLAN-fix-windows-quickstart.md) Phase 2.
  - Create or merge the host-side `.vscode/extensions.json` recommending the Dev Containers extension, both scripts. It's needed on the host before "Reopen in Container".
  - A connectivity pre-check before downloading (exit `2`, with its own message).
- [ ] 2.4 **Pin to the release:** the script defaults to the image tag of its own release (`ghcr.io/helpers-no/devcontainer-toolbox:<version>`), not `latest`, and downloads the template from the same tag.
- [ ] 2.5 When a prerequisite is missing, print one plain sentence and the next action. Until client-provisioning's installer exists, point to the "What your computer needs" page.
- [ ] 2.7 `install.sh` checks the Mac architecture (`uname -m` = `arm64`) and stops on an Intel Mac with the same plain sentence client-provisioning's installer uses, so a user who runs DCT's script directly gets the same answer (suggested in urb-agents #1514).
- [ ] 2.8 **Install the Dev Containers extension** (`code --install-extension ms-vscode-remote.remote-containers`), as the user, in both scripts. Skip it if `code --list-extensions` already lists it.
  - **Find `code` even when it is not on PATH yet** (for example right after Intune installed VS Code). Windows: `%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd` (user install), then `%ProgramFiles%\Microsoft VS Code\bin\code.cmd` (system install). macOS: `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`.
  - If VS Code is not found, exit `1` with an `ERRnnn` line and the plain handover sentence.
- [ ] 2.6 Both scripts stay admin-free. Add a test that fails if either one elevates or calls an installer.

### Validation

Tests pass. Called with Rancher Desktop missing, each script exits `1`, prints an `ERRnnn` line and the handover sentence. Run twice on the same folder, it refuses to overwrite the backup and loses nothing.

---

## Phase 3: Releases client-provisioning can pin

### Tasks

- [x] 3.1 Agree the handover with client-provisioning (urb-agents #1505, 2026-09-25).
- [ ] 3.2 **Tag each release as `v<version>`** (DCT has no version tags today; only a moving `latest`) and **protect `v*` tags** against moving.
- [ ] 3.3 **Publish a GitHub release per version** with `install.ps1`, `install.sh`, `SHA256SUMS` and `host-requirements.json` as assets. client-provisioning pins the version and the hash, and refuses on a mismatch. Add this to the release workflow and to `contributors/releasing.md`.
- [ ] 3.4 Send client-provisioning the first release URL as a bus task. It then replaces `devcontainer-init` (which today downloads DCT's template from `main`, unpinned) with a call to the pinned script. That change is theirs, with Terje's go.

### Validation

A client-provisioning test run fetches a tagged DCT release, verifies `SHA256SUMS`, runs the script un-elevated, and gets the same `devcontainer.json` as DCT's own installer.

---

## Phase 4: One command on the website

### Tasks

- [ ] 4.1 When client-provisioning's installer is released, change the Windows Quick Start (and later the Mac one) to that single command, and keep today's `install.ps1` line as the "your PC is already set up" path.
- [ ] 4.2 Release: bump `version.txt`.

### Validation

A non-developer on a clean Windows 11 PC follows the Quick Start alone and gets a running devcontainer.

---

## Acceptance Criteria

- [ ] "What your computer needs" and `host-requirements.json` exist, and client-provisioning checks against them
- [ ] Every DCT release is a protected `v<version>` tag with `SHA256SUMS`, and its scripts pull that release's image
- [ ] DCT's install scripts never need admin, and can be called by another script with documented exit codes
- [ ] A missing prerequisite produces a plain-language handover, not a technical error
- [ ] `devcontainer.json` is written by DCT's script only
- [ ] The website shows one command for a non-developer

## Files to Modify

- `install.ps1`, `install.sh`
- `website/docs/getting-started.md`, `website/docs/index.md`, `README.md`
- a new "What your computer needs" page under `website/docs/`
- `.devcontainer/additions/tests/` (admin-free test)
- `.github/workflows/` (release assets, tag protection), `website/docs/contributors/releasing.md`
- `version.txt`
