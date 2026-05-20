#!/usr/bin/env bash
set -euo pipefail

tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT
container_cli="${CONTAINER_CLI:-}"

if [ -z "$container_cli" ]; then
    if command -v podman >/dev/null 2>&1; then
        container_cli="podman"
    else
        container_cli="docker"
    fi
fi
container_args=()
mount_relabel=""

if [ "$(basename "$container_cli")" = "podman" ]; then
    container_args+=(--userns=keep-id --user "$(id -u):$(id -g)")
    mount_relabel=",relabel=shared"
fi

mkdir -p \
    "${tmp_home}/.codex" \
    "${tmp_home}/.claude"
printf '{}' > "${tmp_home}/.claude.json"

"$container_cli" run --rm \
    "${container_args[@]}" \
    --mount "type=bind,source=${tmp_home}/.codex,target=/home/tester/.codex${mount_relabel}" \
    --mount "type=bind,source=${tmp_home}/.claude,target=/home/tester/.claude${mount_relabel}" \
    --mount "type=bind,source=${tmp_home}/.claude.json,target=/home/tester/.claude.json${mount_relabel}" \
    debian:bookworm-slim \
    bash -lc '
        test -d /home/tester/.codex
        test -d /home/tester/.claude
        test -f /home/tester/.claude.json
        printf codex > /home/tester/.codex/state
        printf claude > /home/tester/.claude/state
        printf "{\"ok\":true}" > /home/tester/.claude.json
    '

test "$(cat "${tmp_home}/.codex/state")" = "codex"
test "$(cat "${tmp_home}/.claude/state")" = "claude"
test "$(cat "${tmp_home}/.claude.json")" = '{"ok":true}'
