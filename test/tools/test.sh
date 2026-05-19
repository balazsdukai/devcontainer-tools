#!/usr/bin/env bash
set -euo pipefail

for command in bat codex claude fd gh jq rg fzf ug ugrep yq; do
    command -v "$command" >/dev/null
done
