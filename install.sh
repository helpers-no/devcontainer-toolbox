#!/bin/bash
# install.sh - First-time install of devcontainer-toolbox (image mode)
# Run with: curl -fsSL https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.sh | bash
set -e

REPO="helpers-no/devcontainer-toolbox"
IMAGE="ghcr.io/$REPO:latest"
TEMPLATE_URL="https://raw.githubusercontent.com/$REPO/main/devcontainer-user-template.json"

echo "Installing devcontainer-toolbox from $REPO..."
echo ""

# ─── 1. Check Docker is available ────────────────────────────────────────────

if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH."
    echo ""
    echo "Install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    echo "Then run this script again."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is installed but not running."
    echo ""
    echo "Please start Docker Desktop (or Rancher Desktop / Colima) and try again."
    exit 1
fi

# ─── 2. Backup existing .devcontainer/ ───────────────────────────────────────

if [ -d ".devcontainer.backup" ]; then
    echo "Error: .devcontainer.backup/ already exists."
    echo ""
    echo "Remove or rename it before re-running this script, e.g.:"
    echo "    mv .devcontainer.backup .devcontainer.backup.old"
    exit 1
fi

if [ -d ".devcontainer" ]; then
    echo "Found existing .devcontainer/ directory."
    echo "Creating backup at .devcontainer.backup/..."
    mv .devcontainer .devcontainer.backup
    echo "Backup created."
    echo ""
fi

# ─── 3. Download devcontainer-user-template.json ─────────────────────────────

mkdir -p .devcontainer

echo "Downloading devcontainer.json from $TEMPLATE_URL..."
if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL "$TEMPLATE_URL" -o .devcontainer/devcontainer.json; then
        echo "Error: Failed to download devcontainer-user-template.json"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if ! wget -qO .devcontainer/devcontainer.json "$TEMPLATE_URL"; then
        echo "Error: Failed to download devcontainer-user-template.json"
        exit 1
    fi
else
    echo "Error: Neither 'curl' nor 'wget' is available"
    exit 1
fi

if [ ! -s .devcontainer/devcontainer.json ]; then
    echo "Error: Downloaded file is empty"
    exit 1
fi

echo "Created .devcontainer/devcontainer.json"

# ─── 4. Ensure .vscode/extensions.json recommends Dev Containers ─────────────

EXT_ID="ms-vscode-remote.remote-containers"
EXT_FILE=".vscode/extensions.json"

mkdir -p .vscode

if [ -f "$EXT_FILE" ]; then
    if grep -q "$EXT_ID" "$EXT_FILE" 2>/dev/null; then
        echo "Dev Containers extension already in $EXT_FILE"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys
path = '$EXT_FILE'
ext_id = '$EXT_ID'
with open(path) as f:
    data = json.load(f)
recs = data.setdefault('recommendations', [])
if ext_id not in recs:
    recs.append(ext_id)
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        echo "Added Dev Containers extension to $EXT_FILE"
    else
        echo "Warning: Could not update existing $EXT_FILE (python3 not available)"
    fi
else
    cat > "$EXT_FILE" << 'EXTENSIONS_EOF'
{
  "recommendations": [
    "ms-vscode-remote.remote-containers"
  ]
}
EXTENSIONS_EOF
    echo "Created $EXT_FILE with Dev Containers extension recommendation"
fi

# ─── 5. Pull the Docker image ────────────────────────────────────────────────

echo ""
echo "Pulling container image: $IMAGE"
echo "(This may take a few minutes on first install...)"
if ! docker pull "$IMAGE"; then
    echo ""
    echo "Error: Failed to pull $IMAGE"
    echo ""
    echo "This image is public and does not require a Docker login. If you saw \"denied\","
    echo "try clearing any stale ghcr.io credentials:"
    echo "    docker logout ghcr.io"
    echo "then re-run this script."
    exit 1
fi

# ─── 6. Print next steps ─────────────────────────────────────────────────────

echo ""
echo "✅ devcontainer-toolbox installed!"
echo ""
echo "Next steps:"
echo "  1. Open this folder in VS Code"
echo "  2. When prompted, click 'Reopen in Container'"
echo "     (or run: Cmd/Ctrl+Shift+P > 'Dev Containers: Reopen in Container')"
echo "  3. Inside the container, run: dev-help"
echo ""

if [ -d ".devcontainer.backup" ]; then
    echo "Note: Your previous .devcontainer/ was backed up to .devcontainer.backup/"
    echo ""
fi
