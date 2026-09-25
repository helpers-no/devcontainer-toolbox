---
slug: /
sidebar_class_name: hidden
---

# DevContainer Toolbox

**One command. Full dev environment. Any project.**

Stop wasting time setting up development environments. DevContainer Toolbox gives you a complete, consistent setup that works on Windows, Mac, and Linux.

## Quick Start

**Before you start:** [Rancher Desktop](https://rancherdesktop.io/) (started and ready) and [VS Code](https://code.visualstudio.com/). On a work PC, get both from Company Portal (Self Service on a Mac). Windows 11, or macOS 13 or later on Apple Silicon. [Details](getting-started)

**1. Install** — open the folder for your project and run the command for your computer:

**Windows** — in PowerShell (*not* "Run as administrator"):

```powershell
irm https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.ps1 | iex
```

**Mac / Linux** — in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.sh | bash
```

This creates `.devcontainer/devcontainer.json`, installs the Dev Containers extension in VS Code, and downloads the container image. If Rancher Desktop isn't running, it tells you and changes nothing.

**2. Open in VS Code** and click **"Reopen in Container"** when prompted.

Done! The container starts in seconds. Run `dev-setup` to install tools.

## What's Next?

- [What Are DevContainers?](what-are-devcontainers) - New to containers? Start here
- [Getting Started](getting-started) - Full installation guide
- [Available Tools](tools) - See all 20+ tools
- [Commands Reference](commands) - All `dev-*` commands
- [Configuration](configuration) - Customize your setup
- [Troubleshooting](troubleshooting) - Common issues and solutions
