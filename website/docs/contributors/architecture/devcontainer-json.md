---
sidebar_label: devcontainer.json
---

# devcontainer.json Reference

The `devcontainer-user-template.json` in the repo root is the **single source of truth** for user project configuration. Install scripts (`install.sh`, `install.ps1`) download this file and place it at `.devcontainer/devcontainer.json` in the user's project.

The DCT development devcontainer (`.devcontainer/devcontainer.json`) has additional build-time fields but follows the same field conventions documented here.

---

## This file is managed by DCT

**Developers should not edit `.devcontainer/devcontainer.json`.** It is owned and maintained by `dev-update`. If a developer needs something that requires editing this file, that's a missing feature in DCT — open an issue instead.

### How it stays up to date

1. **Initial install:** `install.sh` downloads `devcontainer-user-template.json` from GitHub and places it as `.devcontainer/devcontainer.json`
2. **On every update:** `dev-update` downloads the latest template from GitHub, backs up the current file to `.devcontainer/backup/devcontainer.json.<version>`, and replaces it with the new template. This ensures all users get new fields (env vars, features, extensions) automatically.
3. **CI keeps the template current:** The `build-image.yml` workflow auto-updates `DCT_IMAGE_VERSION` in `devcontainer-user-template.json` after each image build.

### What happens to customizations

Any changes a developer made to devcontainer.json will be overwritten on the next `dev-update`. The old file is preserved in `.devcontainer/backup/` so customizations can be found and re-applied if needed.

The `.devcontainer/backup/` directory is gitignored — it's a local safety net, not a shared resource.

### Where project-specific config belongs

| Need | Where to put it |
|------|----------------|
| VS Code extensions | Install via VS Code UI (stored in user settings, not devcontainer.json) |
| Tools and runtimes | `.devcontainer.extend/enabled-tools.conf` |
| Services | `.devcontainer.extend/enabled-services.conf` |
| Custom setup scripts | `.devcontainer.extend/project-installs.sh` |
| Secrets and credentials | `.devcontainer.secrets/` (gitignored) |

---

## Field Reference

### image

```json
"image": "ghcr.io/helpers-no/devcontainer-toolbox:latest"
```

The pre-built container image from GitHub Container Registry. Always `:latest` for users — CI publishes a new image on every version bump. Versioned tags (e.g., `:1.7.17`) exist for pinning but are not recommended.

**Do not change** unless testing a specific version.

---

### overrideCommand

```json
"overrideCommand": false
```

**Must be `false`.** When `true` (the default in VS Code), VS Code overrides the container's ENTRYPOINT/CMD with a sleep command. DCT's entrypoint (`/opt/devcontainer-toolbox/entrypoint.sh`) handles all startup — git identity, services, tool installation, welcome message. Without it, nothing initializes.

**Never change this.**

---

### runArgs

```json
"runArgs": [
    "--cap-add=NET_ADMIN",
    "--cap-add=NET_RAW",
    "--cap-add=SYS_ADMIN",
    "--cap-add=AUDIT_WRITE",
    "--device=/dev/net/tun:/dev/net/tun",
    "--privileged"
]
```

Linux capabilities needed for VPN connectivity inside the container. Without these, VPN tools (GlobalProtect, OpenConnect, etc.) cannot create TUN devices or manipulate network routes.

| Capability | Purpose |
|-----------|---------|
| `NET_ADMIN` | Configure network interfaces, routes, firewall rules |
| `NET_RAW` | Raw socket access (needed by VPN protocols) |
| `SYS_ADMIN` | Mount filesystems, configure namespaces (VPN TUN device) |
| `AUDIT_WRITE` | Write audit log entries (required by some VPN clients) |
| `--device=/dev/net/tun` | Pass TUN device into container |
| `--privileged` | Full capability set (some VPN clients need this beyond individual caps) |

**Impact of removing:** VPN will not work. Other DCT functionality is unaffected.

---

### customizations.vscode.extensions

```json
"customizations": {
    "vscode": {
        "extensions": [
            "yzhang.markdown-all-in-one",
            "MermaidChart.vscode-mermaid-chart",
            "redhat.vscode-yaml",
            "mhutchie.git-graph",
            "timonwong.shellcheck"
        ]
    }
}
```

VS Code extensions installed automatically when the container starts. These are the baseline extensions every DCT user gets.

| Extension | Purpose |
|-----------|---------|
| `markdown-all-in-one` | Markdown editing, preview, TOC generation |
| `vscode-mermaid-chart` | Mermaid diagram rendering in markdown |
| `vscode-yaml` | YAML validation and autocompletion |
| `git-graph` | Visual git history and branch management |
| `shellcheck` | Shell script linting |

**Do not add project-specific extensions here.** The goal is one identical `devcontainer.json` across all projects so that `dev-update` can upgrade everyone seamlessly. Developers who want additional extensions should install them via VS Code's own UI — those are stored in VS Code's user settings, not in the devcontainer config.
---

### remoteEnv

```json
"remoteEnv": {
    "DCT_HOME": "/opt/devcontainer-toolbox",
    "DCT_WORKSPACE": "/workspace",
    "DCT_IMAGE_VERSION": "1.7.31",
    "DEV_HOST_USER": "${localEnv:USER}",
    "DEV_HOST_USERNAME": "${localEnv:USERNAME}",
    "DEV_HOST_OS": "${localEnv:OS}",
    "DEV_HOST_HOME": "${localEnv:HOME}",
    "DEV_HOST_LOGNAME": "${localEnv:LOGNAME}",
    "DEV_HOST_LANG": "${localEnv:LANG}",
    "DEV_HOST_SHELL": "${localEnv:SHELL}",
    "DEV_HOST_TERM_PROGRAM": "${localEnv:TERM_PROGRAM}",
    "DEV_HOST_HOSTNAME": "${localEnv:HOSTNAME}",
    "DEV_HOST_COMPUTERNAME": "${localEnv:COMPUTERNAME}",
    "DEV_HOST_PROCESSOR_ARCHITECTURE": "${localEnv:PROCESSOR_ARCHITECTURE}",
    "DEV_HOST_ONEDRIVE": "${localEnv:OneDrive}"
}
```

Environment variables available inside the container. Set by VS Code at container start, available to all processes. `${localEnv:...}` reads the value from the **host machine** — empty if the variable doesn't exist on the host.

#### DCT system variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `DCT_HOME` | `/opt/devcontainer-toolbox` | Root of the toolbox installation. All scripts reference this. |
| `DCT_WORKSPACE` | `/workspace` | The mounted project directory. Scripts use this instead of hardcoding `/workspace`. |
| `DCT_IMAGE_VERSION` | e.g. `1.7.31` | The image version this devcontainer.json was last updated for. `dev-update` downloads the latest template which has this set by CI. VS Code detects the change and prompts rebuild. |

#### Host detection variables

These variables pass information from the developer's host machine into the container. Used by `config-host-info.sh` for telemetry and by scripts that need to adapt to the host platform.

**To see all host variables inside the container, run:** `config-host-info --env`

| Variable | Host source | Set on | Purpose |
|----------|------------|--------|---------|
| `DEV_HOST_USER` | `USER` | Mac, Linux | Username |
| `DEV_HOST_USERNAME` | `USERNAME` | Windows, Mac | Username (Windows primary, also set on Mac) |
| `DEV_HOST_OS` | `OS` | Windows only | `Windows_NT` if Windows, empty otherwise |
| `DEV_HOST_HOME` | `HOME` | Mac, Linux | Home directory (starts with `/Users/` on Mac) |
| `DEV_HOST_LOGNAME` | `LOGNAME` | Mac, Linux | Login name |
| `DEV_HOST_LANG` | `LANG` | All | Locale setting (e.g., `en_US.UTF-8`) |
| `DEV_HOST_SHELL` | `SHELL` | Mac, Linux | Default shell (e.g., `/bin/zsh`) |
| `DEV_HOST_TERM_PROGRAM` | `TERM_PROGRAM` | Mac | Terminal app (e.g., `vscode`, `Apple_Terminal`) |
| `DEV_HOST_HOSTNAME` | `HOSTNAME` | Linux | Machine hostname (set by bash; empty on Mac/Windows) |
| `DEV_HOST_COMPUTERNAME` | `COMPUTERNAME` | Windows only | Machine name |
| `DEV_HOST_PROCESSOR_ARCHITECTURE` | `PROCESSOR_ARCHITECTURE` | Windows only | CPU architecture (`AMD64`, `ARM64`) |
| `DEV_HOST_ONEDRIVE` | `OneDrive` | Windows only | OneDrive path (used for organization detection) |

#### Platform detection logic

Scripts can determine the host OS from these variables:

```bash
if [ "${DEV_HOST_OS}" = "Windows_NT" ]; then
    # Windows host
elif [[ "${DEV_HOST_HOME}" == /Users/* ]]; then
    # macOS host
else
    # Linux host
fi
```

**Why `remoteEnv` instead of Dockerfile `ENV`:** These values are set by VS Code at container start, not baked into the image. This allows the same image to work across all platforms. Host-specific values (username, OS, paths) are injected at runtime via `${localEnv:...}`.

---

### workspaceFolder and workspaceMount

```json
"workspaceFolder": "/workspace",
"workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=cached"
```

Maps the user's project directory into the container at `/workspace`.

| Field | Purpose |
|-------|---------|
| `workspaceFolder` | The path VS Code opens inside the container |
| `workspaceMount` | How the host directory is mounted. `consistency=cached` improves macOS performance. |

**Do not change `workspaceFolder`** — scripts, entrypoint, and `DCT_WORKSPACE` all assume `/workspace`. Changing this breaks DCT.

**`${localWorkspaceFolder}`** is a VS Code variable that resolves to the host path the user opened. This is handled by VS Code, not Docker.

---

### features

```json
"features": {
    "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {}
}
```

Dev container features from the official registry. These are applied by VS Code at container start as an additional layer on top of the base image.

| Feature | Purpose | Added in |
|---------|---------|----------|
| `docker-outside-of-docker:1` | Docker CLI + host socket access. Enables `docker` commands inside the container without running a Docker daemon. Cross-platform (Docker Desktop, OrbStack, Rancher Desktop, Colima, Linux). | v1.7.14 |

**Why a feature instead of an install script:** The Docker socket path varies by platform and runtime. The feature handles socket detection and mounting automatically — something an install script can't do because it runs inside the container after the socket is (or isn't) mounted. See `completed/INVESTIGATE-docker-socket-cross-platform.md` for the full investigation.

**Impact:** Adds ~240MB to the container (Docker CLI + Compose + socat + layer overhead). This is applied locally by VS Code, not baked into the ghcr.io image.

---

### remoteUser and containerUser

```json
"remoteUser": "vscode",
"containerUser": "vscode"
```

Both set to `vscode` — the non-root user created by the base image (`mcr.microsoft.com/devcontainers/python`).

| Field | Purpose |
|-------|---------|
| `remoteUser` | The user VS Code runs as when connected |
| `containerUser` | The user the container process runs as |

**Why non-root:** Security best practice. Scripts that need root use `sudo` explicitly. Files created in `/workspace` are owned by `vscode`, matching typical developer expectations.

---

### shutdownAction

```json
"shutdownAction": "stopContainer"
```

What happens when VS Code disconnects. `stopContainer` stops the container (preserving state). Alternatives: `none` (leave running) or `stopCompose` (for Docker Compose setups).

**`stopContainer` is correct** — DCT containers don't need to keep running when the developer disconnects. Startup is fast because everything is pre-built.

---

### updateRemoteUserUID

```json
"updateRemoteUserUID": true
```

VS Code updates the `vscode` user's UID inside the container to match the host user's UID. This prevents file permission issues on bind mounts — files created inside the container have the correct ownership on the host.

**Must be `true`** on macOS and Linux where UID mismatch causes permission errors. On Windows (WSL2), UIDs are less relevant but this setting doesn't hurt.

---

### init

```json
"init": true
```

Adds a tiny init process (`tini`) as PID 1 inside the container. This properly handles zombie processes and signal forwarding.

**Must be `true`** — without it, orphaned child processes (from background tools, services, or crashed scripts) accumulate and never get reaped. The init process also ensures `SIGTERM` is forwarded correctly when the container stops, allowing graceful shutdown of services managed by supervisord.

---

### initializeCommand

```json
"initializeCommand": "ver || sh -c \"mkdir -p .devcontainer.secrets/env-vars && { hostname -s 2>/dev/null || hostname; } > .devcontainer.secrets/env-vars/.host-hostname; true\""
```

Runs on the **host machine** before the container starts. This is the only devcontainer lifecycle command that executes outside the container.

**It must be valid in two shells.** The devcontainers CLI (which VS Code uses) runs a string `initializeCommand` with `cmd.exe /c` on Windows and with `/bin/sh -c` everywhere else (`devcontainers/cli`, `src/spec-node/utils.ts`, `runInitializeCommand`). A non-zero exit stops the container from starting. A bash-only command therefore broke every new Windows install from 2026-04-07 (`733dd73`) until 1.8.2.

How the command works in each shell:

- **`cmd.exe` (Windows):** `ver` succeeds, so `||` skips the rest. The quoted part is a single argument, so `cmd.exe` never interprets the `&&`, `>` or `{ }` inside it. Windows does not need the file: the hostname comes from `COMPUTERNAME` via `remoteEnv`.
- **`/bin/sh` (Mac, Linux):** `ver` does not exist (one `ver: command not found` line in the log), so `||` runs the capture, which ends in `true` (exit 0).

The `Host Commands` workflow (`.github/workflows/host-commands.yml`) checks both, on a `windows-latest` runner through the real devcontainers CLI and with `/bin/sh` on Linux. It also runs a control that confirms the old bash-only command still fails on Windows. **Change this command only with that workflow green.**

Used to capture the host's real hostname, which is not available via `remoteEnv` on macOS (zsh doesn't export `HOSTNAME`). The file `.devcontainer.secrets/env-vars/.host-hostname` is read by `config-host-info.sh` as a fallback when `DEV_HOST_HOSTNAME` is empty.

| Platform | Result |
|----------|--------|
| macOS | `.host-hostname` = machine name (e.g., `MBP-J4G0G066W2`) |
| Linux | `.host-hostname` = machine hostname (e.g., `terje-desktop`) |
| Windows | No file written; `config-host-info.sh` uses `DEV_HOST_COMPUTERNAME` instead |

The `mkdir -p` ensures the secrets directory exists on fresh installs. The file is in `.devcontainer.secrets/` which is gitignored.

---

### postStartCommand

```json
"postStartCommand": "bash /opt/devcontainer-toolbox/additions/config-host-info.sh --verify 2>/dev/null || true"
```

Runs after VS Code connects to the container, on every start. At this point `remoteEnv` variables (`DEV_HOST_*`) are available.

This refreshes `.devcontainer.secrets/env-vars/.host-info` with correct host detection data (OS, username, hostname, Docker engine info). The data is used by OTel telemetry, `dev-env`, and Grafana dashboards.

**Why not in the entrypoint:** The ENTRYPOINT is a Docker-level construct that runs before VS Code connects. `remoteEnv` variables are injected by VS Code after the container starts. Any host detection in the entrypoint sees empty `DEV_HOST_*` variables and writes `unknown`. `postStartCommand` runs after VS Code has set up the environment.

**Execution order on container start:**
1. `initializeCommand` — on host, captures hostname
2. ENTRYPOINT — in container, no remoteEnv (git identity, services, tool install)
3. `postStartCommand` — in container, remoteEnv available (host info detection)

For the full startup sequence with detailed steps, see [Startup Lifecycle](startup-lifecycle).

**Must be `true`** — without it, orphaned child processes (from background tools, services, or crashed scripts) accumulate and never get reaped. The init process also ensures `SIGTERM` is forwarded correctly when the container stops, allowing graceful shutdown of services managed by supervisord.
