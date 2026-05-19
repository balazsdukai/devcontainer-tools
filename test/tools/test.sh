#!/usr/bin/env bash
set -euo pipefail

for command in codex claude gh jq rg fzf; do
    command -v "$command" >/dev/null
done
