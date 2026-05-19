#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
feature_root="${repo_root}/src/tools"
wrapper_root="${repo_root}/examples/wrappers"
feature_ref="ghcr.io/balazsdukai/devcontainer-tools/tools:1"

tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT

mkdir -p \
    "${tmp_home}/.codex" \
    "${tmp_home}/.claude" \
    "${tmp_home}/.config/gh"
printf '{}' > "${tmp_home}/.claude.json"

HOME="$tmp_home" "${wrapper_root}/scripts/validate-host-paths.sh"

printf 'token' > "${tmp_home}/.codex/state"
printf 'token' > "${tmp_home}/.claude/state"
printf 'token' > "${tmp_home}/.config/gh/hosts.yml"
printf '{"ok":true}' > "${tmp_home}/.claude.json"

test -w "${tmp_home}/.codex/state"
test -w "${tmp_home}/.claude/state"
test -w "${tmp_home}/.config/gh/hosts.yml"
test -w "${tmp_home}/.claude.json"

rm -rf "${tmp_home}/.claude"
if HOME="$tmp_home" "${wrapper_root}/scripts/validate-host-paths.sh" 2>"${tmp_home}/missing.log"; then
    echo "wrapper validation should fail when a required path is missing" >&2
    exit 1
fi
grep -F "${tmp_home}/.claude" "${tmp_home}/missing.log" >/dev/null

for wrapper in rust python cpp; do
    grep -F "\"${feature_ref}\"" "${wrapper_root}/${wrapper}/devcontainer.json" >/dev/null
    grep -F '${localEnv:HOME}/.codex' "${wrapper_root}/${wrapper}/devcontainer.json" >/dev/null
    grep -F '${localEnv:HOME}/.claude' "${wrapper_root}/${wrapper}/devcontainer.json" >/dev/null
    grep -F '${localEnv:HOME}/.claude.json' "${wrapper_root}/${wrapper}/devcontainer.json" >/dev/null
    grep -F '${localEnv:HOME}/.config/gh' "${wrapper_root}/${wrapper}/devcontainer.json" >/dev/null
done

if grep -R -F '.codex' "${feature_root}" >/dev/null; then
    echo "feature must not contain personal auth paths" >&2
    exit 1
fi

if grep -R -F '.claude' "${feature_root}" >/dev/null; then
    echo "feature must not contain personal auth paths" >&2
    exit 1
fi

echo "local tools checks passed"
