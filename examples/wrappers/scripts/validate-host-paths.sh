#!/usr/bin/env bash
set -euo pipefail

required_paths=(
    "${HOME}/.codex"
    "${HOME}/.claude"
    "${HOME}/.claude.json"
)

missing=()
for path in "${required_paths[@]}"; do
    if [[ ! -e "$path" ]]; then
        missing+=("$path")
    fi
done

if (( ${#missing[@]} > 0 )); then
    {
        echo "tools wrapper: required host paths are missing:"
        printf '  - %s\n' "${missing[@]}"
        echo "Create them or remove the corresponding mount before launching this wrapper."
    } >&2
    exit 1
fi
