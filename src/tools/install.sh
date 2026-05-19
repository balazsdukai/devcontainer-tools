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
    bat \
    ca-certificates \
    curl \
    fd-find \
    fzf \
    gh \
    git \
    jq \
    less \
    nodejs \
    npm \
    procps \
    ripgrep \
    unzip \
    ugrep
rm -rf /var/lib/apt/lists/*

if ! command -v bat >/dev/null && command -v batcat >/dev/null; then
    ln -s "$(command -v batcat)" /usr/local/bin/bat
fi

if ! command -v fd >/dev/null && command -v fdfind >/dev/null; then
    ln -s "$(command -v fdfind)" /usr/local/bin/fd
fi

case "$(dpkg --print-architecture)" in
    amd64)
        yq_arch="amd64"
        ;;
    arm64)
        yq_arch="arm64"
        ;;
    armhf)
        yq_arch="arm"
        ;;
    *)
        echo "tools: unsupported architecture for yq: $(dpkg --print-architecture)" >&2
        exit 1
        ;;
esac

curl -fsSL \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${yq_arch}" \
    -o /usr/local/bin/yq
chmod 0755 /usr/local/bin/yq

npm install --global @openai/codex

if [[ "$INSTALL_CLAUDE" == "true" ]]; then
    npm install --global @anthropic-ai/claude-code
fi
