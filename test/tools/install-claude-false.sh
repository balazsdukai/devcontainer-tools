#!/usr/bin/env bash
set -euo pipefail

for command in bat codex fd gh gitui hx jq just rg fzf ug ugrep ya yazi yq; do
    command -v "$command" >/dev/null
done

if command -v claude >/dev/null; then
    echo "claude should not be installed when installClaude=false" >&2
    exit 1
fi
