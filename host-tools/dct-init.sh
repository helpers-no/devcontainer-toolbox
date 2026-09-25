#!/bin/bash
# File: host-tools/dct-init.sh
# Installed to: ~/.local/bin/dct-init (by install.sh)
#
# Purpose:
#   Set up a project folder for DevContainer Toolbox: write .devcontainer/devcontainer.json,
#   recommend and install the VS Code Dev Containers extension, and download the image.
#   After the first install, a user sets up any new project folder by typing `dct-init` in it.
#
# Usage:
#   dct-init                      set up the current folder
#   dct-init --target-dir <path>  set up another folder
#
# Contract (agreed with client-provisioning, urb-agents #1505): no prompts, never needs sudo,
# safe to run twice. Exit codes:
#   0  done
#   1  a prerequisite is missing (Rancher Desktop not installed or not running, no VS Code,
#      unsupported Mac)
#   2  download or network failure
#   3  target folder problem (missing, a system folder, or a backup already exists)
# Every error line carries an ERRnnn code. Nothing is written while a prerequisite is missing.

set -u

REPO="helpers-no/devcontainer-toolbox"
IMAGE="ghcr.io/$REPO:latest"
TEMPLATE_URL="https://raw.githubusercontent.com/$REPO/main/devcontainer-user-template.json"
EXT_ID="ms-vscode-remote.remote-containers"

fail() {
    # fail <exit-code> <ERRnnn> <message> [more lines...]
    local code="$1" err="$2"
    shift 2
    echo ""
    echo "$err: $1"
    shift
    for line in "$@"; do echo "$line"; done
    exit "$code"
}

# ─── Arguments ───────────────────────────────────────────────────────────────

TARGET_DIR="$(pwd)"
while [ $# -gt 0 ]; do
    case "$1" in
        --target-dir)
            [ $# -ge 2 ] || fail 3 ERR010 "--target-dir needs a folder."
            TARGET_DIR="$2"
            shift 2
            ;;
        -h|--help)
            sed -n '5,20p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            fail 3 ERR010 "Unknown option: $1" "Usage: dct-init [--target-dir <path>]"
            ;;
    esac
done

echo "Setting up DevContainer Toolbox in: $TARGET_DIR"

# ─── 1. Target folder (checked first: it is about the command just typed) ────

if [ ! -d "$TARGET_DIR" ]; then
    fail 3 ERR010 "The folder does not exist: $TARGET_DIR"
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd -P)"
HOME_REAL="$(cd "$HOME" 2>/dev/null && pwd -P || echo "$HOME")"

case "$TARGET_DIR" in
    /|/System|/System/*|/usr|/usr/*|/bin|/bin/*|/sbin|/sbin/*|/etc|/etc/*|/private/etc|/private/etc/*|/Library|/Library/*|/Applications|/Applications/*)
        fail 3 ERR011 "This is a system folder, not a project folder: $TARGET_DIR" \
            "" \
            "Create a folder for your project and run this command in it, for example:" \
            "    mkdir -p ~/my-project && cd ~/my-project && dct-init"
        ;;
esac
if [ "$TARGET_DIR" = "$HOME_REAL" ]; then
    fail 3 ERR011 "This is your home folder, not a project folder." \
        "" \
        "Create a folder for your project and run this command in it, for example:" \
        "    mkdir -p ~/my-project && cd ~/my-project && dct-init"
fi

cd "$TARGET_DIR" || fail 3 ERR010 "Cannot open the folder: $TARGET_DIR"

if [ -d ".devcontainer.backup" ]; then
    fail 3 ERR012 "A previous backup (.devcontainer.backup/) already exists in this folder." \
        "" \
        "Remove or rename it first, so it is not overwritten, e.g.:" \
        "    mv .devcontainer.backup .devcontainer.backup.old"
fi

# ─── 2. Prerequisites (nothing is written before these pass) ─────────────────

if [ "$(uname -s 2>/dev/null)" = "Darwin" ] && [ "$(uname -m 2>/dev/null)" != "arm64" ]; then
    fail 1 ERR005 "This Mac has an Intel processor. DevContainer Toolbox supports Macs with Apple Silicon (M1 or later)."
fi

# `docker` comes with Rancher Desktop. A caller that installed Rancher in the same process has a
# stale PATH, so also look where Rancher puts it (~/.rd/bin) and in the app bundle (urb-agents #1543).
DOCKER=""
if command -v docker >/dev/null 2>&1; then
    DOCKER="$(command -v docker)"
else
    for candidate in \
        "$HOME/.rd/bin/docker" \
        "/Applications/Rancher Desktop.app/Contents/Resources/resources/darwin/bin/docker" \
        "$HOME/Applications/Rancher Desktop.app/Contents/Resources/resources/darwin/bin/docker" \
        "/opt/rancher-desktop/resources/resources/linux/bin/docker"; do
        if [ -x "$candidate" ]; then
            DOCKER="$candidate"
            PATH="$(dirname "$candidate"):$PATH"
            break
        fi
    done
fi

if [ -z "$DOCKER" ]; then
    if [ -d "/Applications/Rancher Desktop.app" ] || [ -d "$HOME/Applications/Rancher Desktop.app" ]; then
        fail 1 ERR002 "Rancher Desktop is installed, but this terminal cannot see it yet." \
            "" \
            "Start Rancher Desktop, wait until it says it is ready, then open a new terminal" \
            "window and run this command again."
    fi
    fail 1 ERR001 "Rancher Desktop is not installed. DevContainer Toolbox needs it." \
        "" \
        "On a work Mac: install Rancher Desktop from Self Service, or ask your IT department." \
        "On your own computer: download it from https://rancherdesktop.io/" \
        "Then run this command again."
fi

if ! "$DOCKER" info >/dev/null 2>&1; then
    fail 1 ERR003 "Rancher Desktop is not running." \
        "" \
        "1. Start Rancher Desktop." \
        "2. Wait until it says it is ready. The first start can take a few minutes." \
        "3. Then run this command again."
fi

# `code` is often not on PATH on macOS (the shell command is opt-in), so also look inside the app.
CODE_CMD=""
if command -v code >/dev/null 2>&1; then
    CODE_CMD="$(command -v code)"
else
    for candidate in \
        "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
        "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; do
        if [ -x "$candidate" ]; then
            CODE_CMD="$candidate"
            break
        fi
    done
fi
if [ -z "$CODE_CMD" ]; then
    fail 1 ERR004 "VS Code was not found." \
        "" \
        "Install VS Code (on a work Mac: from Self Service), then run this command again."
fi

# ─── 3. devcontainer.json ────────────────────────────────────────────────────

if [ -d ".devcontainer" ]; then
    echo "Found existing .devcontainer/ directory. Backing it up to .devcontainer.backup/..."
    mv .devcontainer .devcontainer.backup
fi

mkdir -p .devcontainer
echo "Downloading devcontainer.json..."
ok=0
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$TEMPLATE_URL" -o .devcontainer/devcontainer.json && ok=1
elif command -v wget >/dev/null 2>&1; then
    wget -qO .devcontainer/devcontainer.json "$TEMPLATE_URL" && ok=1
fi
if [ "$ok" != "1" ] || [ ! -s .devcontainer/devcontainer.json ]; then
    rm -f .devcontainer/devcontainer.json
    fail 2 ERR020 "Could not download devcontainer.json." \
        "" \
        "Check that this computer is connected to the internet, then run this command again."
fi
echo "Created .devcontainer/devcontainer.json"

# ─── 4. VS Code: recommend and install the Dev Containers extension ─────────

EXT_FILE=".vscode/extensions.json"
mkdir -p .vscode
if [ -f "$EXT_FILE" ]; then
    if grep -q "$EXT_ID" "$EXT_FILE" 2>/dev/null; then
        :
    elif command -v python3 >/dev/null 2>&1; then
        python3 - "$EXT_FILE" "$EXT_ID" <<'PYEOF'
import json, sys
path, ext_id = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
recs = data.setdefault("recommendations", [])
if ext_id not in recs:
    recs.append(ext_id)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
        echo "Added the Dev Containers extension to $EXT_FILE"
    else
        echo "Warning: could not update the existing $EXT_FILE (python3 not available)"
    fi
else
    printf '{\n  "recommendations": [\n    "%s"\n  ]\n}\n' "$EXT_ID" > "$EXT_FILE"
    echo "Created $EXT_FILE"
fi

if "$CODE_CMD" --list-extensions 2>/dev/null | grep -qx "$EXT_ID"; then
    echo "Dev Containers extension is already installed in VS Code"
else
    echo "Installing the Dev Containers extension in VS Code..."
    if "$CODE_CMD" --install-extension "$EXT_ID"; then
        echo "Dev Containers extension installed"
    else
        echo "WARN030: Could not install the Dev Containers extension."
        echo "Open VS Code and accept its offer to install the recommended extensions."
    fi
fi

# ─── 5. Download the image ───────────────────────────────────────────────────

echo ""
echo "Downloading the DevContainer Toolbox image: $IMAGE"
echo "(This may take a few minutes the first time...)"
if ! "$DOCKER" pull "$IMAGE"; then
    fail 2 ERR022 "The DevContainer Toolbox image could not be downloaded." \
        "" \
        "Check that this computer is connected to the internet and that Rancher Desktop is" \
        "still running, then run this command again." \
        "If you saw \"denied\", clear stale ghcr.io credentials with: docker logout ghcr.io"
fi

# ─── 6. Done ─────────────────────────────────────────────────────────────────

echo ""
echo "✅ This folder is ready for DevContainer Toolbox."
echo ""
echo "Next steps:"
echo "  1. Open this folder in VS Code:  code ."
echo "  2. When VS Code asks, click 'Reopen in Container'"
echo "     (or: Cmd/Ctrl+Shift+P > 'Dev Containers: Reopen in Container')"
echo "  3. Inside the container, run: dev-help"
if [ -d ".devcontainer.backup" ]; then
    echo ""
    echo "Note: your previous .devcontainer/ was backed up to .devcontainer.backup/"
fi
exit 0
