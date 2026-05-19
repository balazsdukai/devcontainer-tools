#!/usr/bin/env bash
set -euo pipefail

INSTALL_CLAUDE="${INSTALLCLAUDE:-true}"

if [[ ! -r /etc/os-release ]]; then
    echo "tools: /etc/os-release is required" >&2
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

case " ${ID:-} ${ID_LIKE:-} " in
    *" debian "*|*" ubuntu "*)
        ;;
    *)
        echo "tools: only Debian and Ubuntu based images are supported in v1" >&2
        exit 1
        ;;
esac

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    bash-completion \
    ca-certificates \
    curl \
    fzf \
    gh \
    git \
    jq \
    less \
    nodejs \
    npm \
    procps \
    ripgrep \
    unzip
rm -rf /var/lib/apt/lists/*

npm install --global @openai/codex

if [[ "$INSTALL_CLAUDE" == "true" ]]; then
    npm install --global @anthropic-ai/claude-code
fi
