---
sidebar_position: 2
---

# Getting Started

A ready-to-use development environment that works the same on Windows, Mac, and Linux.

## Prerequisites

### All Platforms

1. **Docker** - Install [Rancher Desktop](https://rancherdesktop.io/) (free and open source)
   - *Why not Docker Desktop?* Docker Desktop requires a [paid subscription](https://www.docker.com/pricing/) for companies. Rancher Desktop is 100% free.

2. **VS Code** with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Windows Users

Before installing Rancher Desktop, you need WSL (Windows Subsystem for Linux):

```powershell
# Run in PowerShell as Administrator
wsl --install
```

Restart your computer after the command completes, then install Rancher Desktop.

**Note:** This works on Windows 10 (build 19041+) and Windows 11.

### Mac/Linux Users

Just install Rancher Desktop - no additional setup needed.

## Installation (3 Steps)

### Step 1: Install in Your Project

Open a terminal in your project directory and run:

**Mac/Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.ps1 | iex
```

If you see "running scripts is disabled on this system":
```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.ps1 | iex"
```

This creates a `.devcontainer/devcontainer.json` in your project and pulls the pre-built container image.

### Step 2: Open in VS Code and Reopen in Container

Open the project in VS Code. When prompted "Reopen in Container", click it.

The container starts in seconds since the image was already pulled during install. Run `dev-setup` inside the container to install development tools.

That's it! You're ready to start developing.

## Migrating from an Older Version

If your project has an older `.devcontainer/` folder with many files (Dockerfile, manage/, additions/), you can switch to the new image-based approach:

1. Back up your current config:
   ```bash
   mv .devcontainer .devcontainer.old
   ```

2. Run the installer again from your project directory:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.sh | bash
   ```

3. Your `.devcontainer.extend/` and `.devcontainer.secrets/` are preserved — all tool selections and credentials carry over.

4. Delete the old backup when everything works:
   ```bash
   rm -rf .devcontainer.old
   ```

The new approach uses a pre-built image so your `.devcontainer/` folder contains only `devcontainer.json` instead of 100+ files.

---

## Running Commands From the Host: `dct-exec`

Each project's devcontainer gets a random Docker container name, not a fixed one — this is what lets you run multiple projects' devcontainers (or multiple worktrees of the same project) at the same time. That means host-side scripts can't hardcode a container name to `docker exec` into.

Step 1's installer also installs two small helpers to `~/.local/bin` (macOS/Linux only):

- `dct-find-container` — prints the name of the running devcontainer for the current repo
- `dct-exec <command> [args]` — runs `<command>` inside it

```bash
dct-exec bash                          # open a shell inside this project's devcontainer
dct-exec npm test                      # run a command, output prints to your terminal
echo "SELECT 1;" | dct-exec psql mydb  # pipe stdin in
```

Both resolve the container via the `devcontainer.local_folder` label that VS Code's Dev Containers extension sets automatically on every devcontainer it creates:

```bash
docker ps --filter "label=devcontainer.local_folder=$(git rev-parse --show-toplevel)" --format '{{.Names}}'
```

If you're writing your own host-side script (for this project or another one), use that label lookup directly instead of hardcoding a container name.

:::note
`dct-exec` needs `~/.local/bin` on your `PATH`. If the installer warned you it wasn't, add this to your shell profile: `export PATH="$HOME/.local/bin:$PATH"`
:::

:::note Windows
`dct-exec` is macOS/Linux only for now — it's a bash script and there's no `.ps1` equivalent yet.
:::

---

## What's Next?

- **[Install Tools](commands)** - Add development tools (Python, TypeScript, Go, etc.)
- **[Customization](configuration)** - Configure your project settings
- **[Troubleshooting](troubleshooting)** - Common issues and solutions

Run `dev-help` in the terminal to see all available commands.
