#!/usr/bin/env bash
set -euo pipefail

tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT

mkdir -p \
    "${tmp_home}/.codex" \
    "${tmp_home}/.claude" \
    "${tmp_home}/.config/gh"
printf '{}' > "${tmp_home}/.claude.json"

docker run --rm \
    --mount "type=bind,source=${tmp_home}/.codex,target=/home/tester/.codex" \
    --mount "type=bind,source=${tmp_home}/.claude,target=/home/tester/.claude" \
    --mount "type=bind,source=${tmp_home}/.claude.json,target=/home/tester/.claude.json" \
    --mount "type=bind,source=${tmp_home}/.config/gh,target=/home/tester/.config/gh" \
    debian:bookworm-slim \
    bash -lc '
        test -d /home/tester/.codex
        test -d /home/tester/.claude
        test -f /home/tester/.claude.json
        test -d /home/tester/.config/gh
        printf codex > /home/tester/.codex/state
        printf claude > /home/tester/.claude/state
        printf "{\"ok\":true}" > /home/tester/.claude.json
        printf github > /home/tester/.config/gh/hosts.yml
    '

test "$(cat "${tmp_home}/.codex/state")" = "codex"
test "$(cat "${tmp_home}/.claude/state")" = "claude"
test "$(cat "${tmp_home}/.claude.json")" = '{"ok":true}'
test "$(cat "${tmp_home}/.config/gh/hosts.yml")" = "github"
