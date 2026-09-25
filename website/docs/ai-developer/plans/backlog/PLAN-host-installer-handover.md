# Plan: DCT's Side of the Host Installer Split

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: A non-developer gets from DCT's website to a running devcontainer with **one command**, while DCT itself never installs host software.

**Priority**: High — this is who DCT is for on Windows.

**Last Updated**: 2026-09-25

**Related**: [PLAN-fix-windows-quickstart](PLAN-fix-windows-quickstart.md) (defects in today's `install.ps1`), [helpers-no/client-provisioning](https://github.com/helpers-no/client-provisioning) (the host installer)

---

## Decision (Terje, 2026-09-25)

| Repo | Owns | Needs admin? |
|---|---|---|
| **helpers-no/client-provisioning** — "the machine is ready" | WSL, Rancher Desktop, VS Code + Dev Containers extension, elevation, restart and resume, Intune/Jamf packages, and the one-script installer for non-developers | Yes |
| **devcontainer-toolbox** (this repo) — "the project is ready" | `devcontainer.json`, the image, everything inside the container. `install.ps1` / `install.sh` stay small and never need admin | No |

The user still sees **one command** on DCT's website. client-provisioning's installer prepares the machine and, as its **last step, runs DCT's own `install.ps1` / `install.sh`**. DCT stays the only place that writes `devcontainer.json`.

**Why the split** (the advice Terje accepted):

- Host provisioning is a different job: Windows internals, admin rights, restarts, Intune/Jamf policy.
- It needs different testing (real Windows 11 / Mac machines, managed and unmanaged).
- It has a different release pace (a Rancher Desktop pin bump must not force a DCT image release).
- It carries a different risk: an admin-elevated script from a public repo belongs where changes are rare and strictly reviewed, fetched from a release tag.
- client-provisioning already holds tested Rancher Desktop, WSL-features and Mac packages.

The full investigation of the one-script installer (the user, vendor findings, managed machines, prior art, options) moved to client-provisioning with its new owner agent. It was handed over through the fleet bus.

**Owner of client-provisioning:** none yet. ops-dev was asked on 2026-09-25 to onboard an agent for it.

---

## Phase 1: Document what DCT needs from the host

### Tasks

- [ ] 1.1 Add one page, **"What your computer needs"**, as the single list both repos work from: Windows 11 x64 (Rancher Desktop no longer supports Windows 10), or macOS; Rancher Desktop ≥ 1.24 with the `moby` engine; VS Code with the Dev Containers extension; virtualization on; free disk space for the image. Plain language first, exact versions in a table below.
- [ ] 1.2 Link it from Getting Started and the Quick Start.

### Validation

client-provisioning's owner agent confirms the page is what their installer checks against. `npm run build` passes.

---

## Phase 2: `install.ps1` / `install.sh` as a callable last step

### Tasks

- [ ] 2.1 Make both scripts safe to call from another script: a parameter for the target folder, no interactive prompts, documented exit codes (for example 0 = done, 1 = a prerequisite is missing, 2 = download failed).
- [ ] 2.2 When a prerequisite is missing (no Docker/Rancher, Rancher not running, no VS Code), print one plain sentence and the next action instead of a technical error, for example: *"Your PC isn't ready for DevContainer Toolbox yet. Run this first: [the installer command]"*. Until client-provisioning's installer exists, point to the "What your computer needs" page.
- [ ] 2.3 Both scripts stay admin-free. Add a test that fails if either one elevates or calls an installer.

### Validation

Tests pass. Called with a missing Rancher Desktop, each script exits with the documented code and prints the handover sentence.

---

## Phase 3: Agree the handover with client-provisioning

### Tasks

- [ ] 3.1 Through the bus: agree with client-provisioning's owner agent how their installer calls DCT's script: the URL (a release tag, not `main`), the parameters, and the exit codes from Phase 2.
- [ ] 3.2 Ask them to replace their `devcontainer-init` (which writes `devcontainer.json` its own way) with a call to DCT's script, so the file has one owner. That change is theirs to make.

### Validation

A client-provisioning test run ends by calling DCT's script and produces the same `devcontainer.json` as DCT's own installer.

---

## Phase 4: One command on the website

### Tasks

- [ ] 4.1 When client-provisioning's installer is released, change the Windows Quick Start (and later the Mac one) to that single command, and keep today's `install.ps1` line as the "your PC is already set up" path.
- [ ] 4.2 Release: bump `version.txt`.

### Validation

A non-developer on a clean Windows 11 PC follows the Quick Start alone and gets a running devcontainer.

---

## Acceptance Criteria

- [ ] "What your computer needs" exists and client-provisioning checks against it
- [ ] DCT's install scripts never need admin, and can be called by another script with documented exit codes
- [ ] A missing prerequisite produces a plain-language handover, not a technical error
- [ ] `devcontainer.json` is written by DCT's script only
- [ ] The website shows one command for a non-developer

## Files to Modify

- `install.ps1`, `install.sh`
- `website/docs/getting-started.md`, `website/docs/index.md`, `README.md`
- a new "What your computer needs" page under `website/docs/`
- `.devcontainer/additions/tests/` (admin-free test)
- `version.txt`
