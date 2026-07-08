---
sidebar_position: 8
---

# Troubleshooting

Common issues and solutions when using devcontainer-toolbox.

## Container Won't Start

### "Reopen in Container" not appearing

**Solution:** Make sure you have the Dev Containers extension installed in VS Code.

```
Extension ID: ms-vscode-remote.remote-containers
```

### Container build fails

**Solution:** Try rebuilding from scratch:

1. In VS Code: `Ctrl+Shift+P` → "Dev Containers: Rebuild Container"

### Docker not running

**Solution:** Start Docker/Rancher Desktop and try again.

---

## Git Issues

### Git identity not configured

**Symptom:** Commits fail with "Please tell me who you are"

**Solution:**
```bash
dev-check
```

Follow the prompts to set your name and email.

### Git credentials not working

**Solution:** Re-run configuration:
```bash
dev-check
```

Credentials are stored in `.devcontainer.secrets/` and restored on rebuild.

---

## Tool Installation Issues

### Tool not found after install

**Symptom:** Installed a tool but `command not found`

**Solution:** Open a new terminal. The PATH updates in new sessions.

Or source the profile:
```bash
source ~/.bashrc
```

### Install script fails

**Solution:** Check the logs:
```bash
ls /tmp/devcontainer-install/
cat /tmp/devcontainer-install/<script>-*.log
```

### Tool not auto-installing on rebuild

**Solution:** Make sure it's in `enabled-tools.conf`:
```bash
cat .devcontainer.extend/enabled-tools.conf
```

Add the tool ID if missing.

### Host-side script says "devcontainer not running" but it is

**Symptom:** A host-side script that does `docker exec devcontainer-toolbox ...` (or similar hardcoded name) fails, even though the devcontainer is clearly running.

**Cause:** Devcontainers now get a random Docker-assigned name instead of a fixed one, so multiple projects (or worktrees) can each run their own devcontainer at once. Any script still hardcoding the old fixed name will break.

**Solution:** Use `dct-exec` instead of hardcoding a container name — see [Running Commands From the Host](getting-started#running-commands-from-the-host-dct-exec):
```bash
dct-exec <command>
```

---

## Service Issues

### Service won't start

**Solution:** Check status and logs:
```bash
dev-services status
dev-services logs <service-name>
```

### Service not auto-starting

**Solution:** Check if enabled:
```bash
cat .devcontainer.extend/enabled-services.conf
```

Enable it:
```bash
dev-services enable <service-name>
```

---

## VS Code Issues

### Extensions not loading

**Solution:** Rebuild the container:
- `Ctrl+Shift+P` → "Dev Containers: Rebuild Container"

### Terminal not working

**Solution:** Try opening a new terminal:
- `Ctrl+Shift+`` (backtick)

---

## Update Issues

### Update not applying

**Solution:** After `dev-update`, VS Code should prompt to rebuild. If not:
1. Check if version changed: `dev-help`
2. Manually rebuild: `Ctrl+Shift+P` → "Dev Containers: Rebuild Container"

---

## Reset Everything

If nothing else works, rebuild from scratch:

1. In VS Code: `Ctrl+Shift+P` → "Dev Containers: Rebuild Container Without Cache"
2. If that doesn't help, close VS Code, delete the container manually, and reopen

Your settings are preserved in:
- `.devcontainer.extend/` settings
- `.devcontainer.secrets/` credentials

---

## Getting Help

```bash
dev-help              # Show all commands
dev-setup             # Interactive menu
```

Still stuck? Check the [GitHub issues](https://github.com/helpers-no/devcontainer-toolbox/issues).
