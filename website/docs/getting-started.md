---
sidebar_position: 2
---

# Getting Started

A ready-to-use development environment that works the same on Windows, Mac, and Linux.

## Prerequisites

You need two programs. **On a work computer, get them from Company Portal** (Windows) or **Self Service** (Mac), or ask your IT department.

1. **[Rancher Desktop](https://rancherdesktop.io/)** 1.24 or later (free and open source). It runs the container.
   - **Start it before you install**, and wait until it says it is ready. The first start can take a few minutes. If it isn't running, the installer tells you and changes nothing.
   - *Why not Docker Desktop?* It works too, but Docker Desktop requires a [paid subscription](https://www.docker.com/pricing/) for companies. Rancher Desktop is free.

2. **[VS Code](https://code.visualstudio.com/)**. You don't need to install any extension yourself: the installer adds the Dev Containers extension.

### Windows

- **Windows 11** (64-bit). Rancher Desktop no longer supports Windows 10.
- Rancher Desktop needs **WSL** (Windows Subsystem for Linux).
  - **On a work PC**, your IT department sets up WSL together with Rancher Desktop.
  - **On your own PC**, install it once in PowerShell **as Administrator**, then restart:

    ```powershell
    wsl --install --no-distribution
    ```

    `--no-distribution` matters: plain `wsl --install` also installs Ubuntu and asks you to create a Linux user, which DevContainer Toolbox does not need.

### Mac

- **macOS 13 (Ventura) or later**, on **Apple Silicon** (M1 or later).
- No extra setup: just install Rancher Desktop.

### Linux

Install Rancher Desktop. No extra setup needed.

## Installation (3 Steps)

### Step 1: Install in Your Project

Run the installer **in the folder for your project**. If you don't have one yet, create it first.

**Windows** — open **PowerShell** from the Start menu. Use a normal PowerShell, **not "Run as administrator"**: an administrator window opens in `C:\Windows\System32`, and the installer would put its files there. Then run:

```powershell
mkdir $HOME\my-project; cd $HOME\my-project
```

```powershell
irm https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.ps1 | iex
```

**Mac / Linux** — open **Terminal**, then:

```bash
mkdir -p ~/my-project && cd ~/my-project
```

```bash
curl -fsSL https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.sh | bash
```

Replace `my-project` with a name of your choice. Skip the `mkdir` line if you already have a project folder, and run the install command in it.

If you see "running scripts is disabled on this system":
```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.ps1 | iex"
```

This creates a `.devcontainer/devcontainer.json` in your project, installs the Dev Containers extension in VS Code, and downloads the pre-built container image. If Rancher Desktop isn't installed or isn't running, it tells you what to do and changes nothing.

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
