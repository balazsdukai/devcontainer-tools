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

curl_with_retry() {
    local attempt=1

    while ((attempt <= 5)); do
        if curl -fsSL "$@"; then
            return 0
        fi
        if ((attempt == 5)); then
            return 1
        fi
        sleep "$((attempt * 2))"
        attempt=$((attempt + 1))
    done
}

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
    gnupg \
    jq \
    less \
    procps \
    ripgrep \
    tar \
    unzip \
    ugrep \
    xz-utils
rm -rf /var/lib/apt/lists/*

install_nodejs() {
    local node_major="22"
    local keyring="/usr/share/keyrings/nodesource.gpg"
    local sources_list="/etc/apt/sources.list.d/nodesource.list"

    rm -f "$keyring"
    curl_with_retry "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" |
        gpg --dearmor -o "$keyring"
    chmod 0644 "$keyring"

    echo "deb [signed-by=${keyring}] https://deb.nodesource.com/node_${node_major}.x nodistro main" >"$sources_list"

    apt-get update
    apt-get install -y --no-install-recommends nodejs
    rm -rf /var/lib/apt/lists/*
}

install_nodejs

if ! command -v bat >/dev/null && command -v batcat >/dev/null; then
    ln -s "$(command -v batcat)" /usr/local/bin/bat
fi

if ! command -v fd >/dev/null && command -v fdfind >/dev/null; then
    ln -s "$(command -v fdfind)" /usr/local/bin/fd
fi

architecture="$(dpkg --print-architecture)"
tool_versions="$(dirname "${BASH_SOURCE[0]}")/tool-versions.json"

case "$architecture" in
    amd64)
        yq_arch="amd64"
        gitui_asset_regex='^gitui-linux-x86_64\.tar\.gz$'
        yazi_asset_regex='^yazi-x86_64-unknown-linux-gnu\.zip$'
        helix_asset_regex='^helix-[^-]+-x86_64-linux\.tar\.xz$'
        just_asset_regex='^just-[^-]+-x86_64-unknown-linux-musl\.tar\.gz$'
        ;;
    arm64)
        yq_arch="arm64"
        gitui_asset_regex='^gitui-linux-aarch64\.tar\.gz$'
        yazi_asset_regex='^yazi-aarch64-unknown-linux-gnu\.zip$'
        helix_asset_regex='^helix-[^-]+-aarch64-linux\.tar\.xz$'
        just_asset_regex='^just-[^-]+-aarch64-unknown-linux-musl\.tar\.gz$'
        ;;
    armhf)
        yq_arch="arm"
        echo "tools: unsupported architecture for gitui, yazi, and helix: $architecture" >&2
        exit 1
        ;;
    *)
        echo "tools: unsupported architecture: $architecture" >&2
        exit 1
        ;;
esac

tmp_dir="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

download_github_release_asset() {
    local repo="$1"
    local version="$2"
    local asset_regex="$3"
    local destination="$4"
    local api_url asset_url

    if [[ -n "$version" ]]; then
        api_url="https://api.github.com/repos/${repo}/releases/tags/${version}"
    else
        api_url="https://api.github.com/repos/${repo}/releases/latest"
    fi
    asset_url="$(
        curl_with_retry "$api_url" |
            jq -r --arg asset_regex "$asset_regex" \
                '[.assets[] | select(.name | test($asset_regex)) | .browser_download_url][0] // empty'
    )"

    if [[ -z "$asset_url" ]]; then
        echo "tools: could not find latest ${repo} release asset matching ${asset_regex}" >&2
        exit 1
    fi

    curl_with_retry -o "$destination" "$asset_url"
}

github_version() {
    jq -r --arg repository "$1" '.github[$repository] // empty' "$tool_versions"
}

npm_version() {
    jq -r --arg package "$1" '.npm[$package] // empty' "$tool_versions"
}

install_executable_from_tree() {
    local tree="$1"
    local executable="$2"
    local source

    source="$(find "$tree" -type f -name "$executable" -perm /111 -print -quit)"
    if [[ -z "$source" ]]; then
        echo "tools: could not find executable ${executable} under ${tree}" >&2
        exit 1
    fi

    install -m 0755 "$source" "/usr/local/bin/${executable}"
}

yq_version="$(github_version mikefarah/yq)"
if [[ -n "$yq_version" ]]; then
    yq_url="https://github.com/mikefarah/yq/releases/download/${yq_version}/yq_linux_${yq_arch}"
else
    yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${yq_arch}"
fi
curl_with_retry -o /usr/local/bin/yq "$yq_url"
chmod 0755 /usr/local/bin/yq

download_github_release_asset "gitui-org/gitui" "$(github_version gitui-org/gitui)" "$gitui_asset_regex" "$tmp_dir/gitui.tar.gz"
mkdir -p "$tmp_dir/gitui"
tar -xzf "$tmp_dir/gitui.tar.gz" -C "$tmp_dir/gitui"
install_executable_from_tree "$tmp_dir/gitui" gitui

download_github_release_asset "sxyazi/yazi" "$(github_version sxyazi/yazi)" "$yazi_asset_regex" "$tmp_dir/yazi.zip"
mkdir -p "$tmp_dir/yazi"
unzip -q "$tmp_dir/yazi.zip" -d "$tmp_dir/yazi"
install_executable_from_tree "$tmp_dir/yazi" yazi
install_executable_from_tree "$tmp_dir/yazi" ya

download_github_release_asset "helix-editor/helix" "$(github_version helix-editor/helix)" "$helix_asset_regex" "$tmp_dir/helix.tar.xz"
mkdir -p "$tmp_dir/helix" /usr/local/lib/helix
tar -xJf "$tmp_dir/helix.tar.xz" -C "$tmp_dir/helix"
install_executable_from_tree "$tmp_dir/helix" hx
mv /usr/local/bin/hx /usr/local/lib/helix/hx
helix_runtime="$(find "$tmp_dir/helix" -type d -name runtime -print -quit)"
if [[ -z "$helix_runtime" ]]; then
    echo "tools: could not find helix runtime directory" >&2
    exit 1
fi
rm -rf /usr/local/lib/helix/runtime
cp -a "$helix_runtime" /usr/local/lib/helix/runtime
cat >/usr/local/bin/hx <<'EOF'
#!/usr/bin/env bash
export HELIX_RUNTIME="${HELIX_RUNTIME:-/usr/local/lib/helix/runtime}"
exec /usr/local/lib/helix/hx "$@"
EOF
chmod 0755 /usr/local/bin/hx

download_github_release_asset "casey/just" "$(github_version casey/just)" "$just_asset_regex" "$tmp_dir/just.tar.gz"
mkdir -p "$tmp_dir/just"
tar -xzf "$tmp_dir/just.tar.gz" -C "$tmp_dir/just"
install_executable_from_tree "$tmp_dir/just" just

codex_version="$(npm_version @openai/codex)"
claude_version="$(npm_version @anthropic-ai/claude-code)"
if [[ -n "$codex_version" ]]; then
    npm install --global "@openai/codex@${codex_version}"
else
    npm install --global @openai/codex
fi

if [[ "$INSTALL_CLAUDE" == "true" ]]; then
    if [[ -n "$claude_version" ]]; then
        npm install --global "@anthropic-ai/claude-code@${claude_version}"
    else
        npm install --global @anthropic-ai/claude-code
    fi
fi
