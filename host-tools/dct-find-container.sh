#!/bin/bash
# File: host-tools/dct-find-container.sh
# Installed to: ~/.local/bin/dct-find-container
#
# Purpose:
#   Resolve the name of the running devcontainer for the current repo, using
#   the `devcontainer.local_folder` label that the Dev Containers CLI sets on
#   every container it creates. Lets host-side scripts stop hardcoding a
#   fixed container name — broken by devcontainer-toolbox's image-mode change
#   (v1.7.38), which intentionally dropped `--name=devcontainer-toolbox` from
#   runArgs so multiple devcontainers/worktrees can run at once.
#
# Usage:
#   dct-find-container            Print the resolved container name, exit 0
#   dct-find-container --help     Show this help
#
# Scope: macOS and Linux hosts. Not supported on native Windows (no bash).
#
# See: https://github.com/helpers-no/devcontainer-toolbox/issues/96

set -e

case "${1:-}" in
    --help|-h)
        cat <<'EOF'
dct-find-container — resolve the running devcontainer for the current repo

Usage: dct-find-container

Resolves the git repo root (falls back to the current directory if not in a
git repo) and looks up the running Docker container whose
`devcontainer.local_folder` label matches it. Prints the container name on
stdout and exits 0.

Exits 1 with an error on stderr if:
  - no container matches (nothing printed on stdout)
  - a matching container exists but isn't running
  - more than one running container matches (ambiguous — not auto-resolved)
EOF
        exit 0
        ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

MATCHES="$(docker ps --filter "label=devcontainer.local_folder=$ROOT" --format '{{.Names}}')"

if [ -z "$MATCHES" ]; then
    STOPPED="$(docker ps -a --filter "label=devcontainer.local_folder=$ROOT" --format '{{.Names}}' | head -1)"
    if [ -n "$STOPPED" ]; then
        echo "Error: found a devcontainer for this repo, but it isn't running: $STOPPED" >&2
        echo "  Start it (e.g. open $ROOT in VS Code and 'Reopen in Container'), then retry." >&2
    else
        echo "Error: no devcontainer found for $ROOT" >&2
        echo "  Is this repo open in VS Code with 'Reopen in Container'?" >&2
    fi
    exit 1
fi

MATCH_COUNT="$(echo "$MATCHES" | wc -l | tr -d ' ')"
if [ "$MATCH_COUNT" -gt 1 ]; then
    echo "Error: multiple running devcontainers matched $ROOT:" >&2
    echo "$MATCHES" | sed 's/^/  /' >&2
    exit 1
fi

echo "$MATCHES"
