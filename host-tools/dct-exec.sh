#!/bin/bash
# File: host-tools/dct-exec.sh
# Installed to: ~/.local/bin/dct-exec
#
# Purpose:
#   Run a command inside the current repo's own devcontainer, from the host.
#   Mirror of .devcontainer/manage/uis-exec.sh, which runs the opposite
#   direction (from inside DCT into the uis-provision-host container).
#
# Why this exists:
#   Image-mode devcontainer-toolbox (v1.7.38+) dropped the fixed
#   --name=devcontainer-toolbox container name so multiple devcontainers /
#   worktrees can run at once. That broke host-side scripts that hardcoded
#   the old name to `docker exec` into it. This resolves the container via
#   dct-find-container (the devcontainer.local_folder label) instead.
#
# Modes (mirrors .devcontainer/manage/uis.sh's TTY/stdin routing):
#   Interactive TTY:  docker exec -it
#   Piped stdin:      docker exec -i
#   Non-TTY no stdin: docker exec
#
# Scope: macOS and Linux hosts. Not supported on native Windows (no bash).
#
# See: https://github.com/helpers-no/devcontainer-toolbox/issues/96

set -e

case "${1:-}" in
    ""|--help|-h)
        cat <<'EOF'
dct-exec — run a command inside this repo's own devcontainer

Usage: dct-exec <command> [args]

Examples:
  dct-exec bash                  Interactive shell inside the devcontainer
  dct-exec npm test               Run a command, output printed to your terminal
  echo hi | dct-exec cat          Pipe stdin into the container (no TTY)
  dct-exec ls /workspace > out.txt   Redirect output cleanly (no TTY)

Resolves the container via dct-find-container — see:
  dct-find-container --help
EOF
        exit 0
        ;;
esac

SCRIPT_REAL_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_REAL_PATH")"

# Prefer the installed sibling (no .sh, once install.sh has run); fall back
# to the .sh version so this also works uninstalled, straight from the repo.
if [ -x "$SCRIPT_DIR/dct-find-container" ]; then
    FIND_CONTAINER="$SCRIPT_DIR/dct-find-container"
elif [ -x "$SCRIPT_DIR/dct-find-container.sh" ]; then
    FIND_CONTAINER="$SCRIPT_DIR/dct-find-container.sh"
else
    FIND_CONTAINER="dct-find-container"
fi

CONTAINER="$("$FIND_CONTAINER")"

if [ -t 0 ] && [ -t 1 ]; then
    # Interactive: terminal in and out — allocate a TTY
    exec docker exec -it "$CONTAINER" "$@"
elif [ ! -t 0 ]; then
    # Stdin is piped (e.g., echo hi | dct-exec cat)
    exec docker exec -i "$CONTAINER" "$@"
else
    # Non-TTY, no stdin (e.g., dct-exec ls /workspace > out.txt)
    exec docker exec "$CONTAINER" "$@"
fi
