#!/bin/bash
# install.sh - First-time install of devcontainer-toolbox (image mode)
# Run with: curl -fsSL https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.sh | bash
#
# Installs the DCT host commands for this user (no sudo) and then sets up the current folder:
#   dct-init            set up a project folder (writes .devcontainer/, installs the VS Code
#                       Dev Containers extension, downloads the image)
#   dct-find-container  find the running devcontainer for the current folder
#   dct-exec            run a command inside that devcontainer
# All three go to ~/.local/bin. Every dct-* command is installed by this script.
#
# Afterwards, set up any new project folder by typing `dct-init` in it.
# Exit code: dct-init's (0 done, 1 prerequisite missing, 2 download failed, 3 folder problem).
#
# Testing: DCT_INSTALL_SOURCE=<repo checkout> installs host-tools/ from that folder instead of
# downloading them from GitHub; DCT_INSTALL_REF=<branch> downloads them from that branch instead
# of main (to test a branch before it is merged).

REPO="helpers-no/devcontainer-toolbox"
REF="${DCT_INSTALL_REF:-main}"
BIN_DIR="$HOME/.local/bin"
TOOLS="dct-init dct-find-container dct-exec"

echo "Installing DevContainer Toolbox from $REPO ($REF)..."
echo ""

case "$(uname -s 2>/dev/null)" in
    Linux|Darwin) ;;
    *)
        echo "ERR001: This installer is for macOS and Linux. On Windows, use the PowerShell command:"
        echo "    irm https://raw.githubusercontent.com/$REPO/main/install.ps1 | iex"
        exit 1
        ;;
esac

# ─── 1. Install the dct-* commands ───────────────────────────────────────────

mkdir -p "$BIN_DIR"
echo "Installing the DevContainer Toolbox commands to $BIN_DIR..."

for name in $TOOLS; do
    dest="$BIN_DIR/$name"
    ok=0
    if [ -n "${DCT_INSTALL_SOURCE:-}" ]; then
        cp "$DCT_INSTALL_SOURCE/host-tools/$name.sh" "$dest" 2>/dev/null && ok=1
    else
        url="https://raw.githubusercontent.com/$REPO/$REF/host-tools/$name.sh"
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$url" -o "$dest" && ok=1
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$dest" "$url" && ok=1
        fi
    fi
    if [ "$ok" = "1" ] && [ -s "$dest" ]; then
        chmod +x "$dest"
        echo "  Installed $name"
    else
        rm -f "$dest"
        if [ "$name" = "dct-init" ]; then
            echo ""
            echo "ERR020: Could not download dct-init."
            echo ""
            echo "Check that this computer is connected to the internet, then run this command again."
            exit 2
        fi
        echo "  Warning: could not install $name (the devcontainer itself is not affected)"
    fi
done

# ─── 2. Set up the current folder ────────────────────────────────────────────

echo ""
"$BIN_DIR/dct-init"
rc=$?

# ─── 3. How to use it next time ──────────────────────────────────────────────

echo ""
case ":$PATH:" in
    *":$BIN_DIR:"*)
        if [ "$rc" = "0" ]; then
            echo "Next time, set up a new project folder by typing 'dct-init' in it."
        else
            echo "When the problem above is fixed, run 'dct-init' in this folder."
        fi
        ;;
    *)
        echo "Note: $BIN_DIR is not on your PATH, so 'dct-init' is not found by name yet."
        echo "Add this line to your shell profile (~/.zshrc or ~/.bashrc), then open a new terminal:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

exit "$rc"
