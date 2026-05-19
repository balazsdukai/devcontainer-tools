#!/usr/bin/env bash
set -euo pipefail

for command in bat codex claude fd gh gitui hx jq just rg fzf ug ugrep ya yazi yq; do
    command -v "$command" >/dev/null
done
