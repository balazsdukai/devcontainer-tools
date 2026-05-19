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
    tar \
    unzip \
    ugrep \
    xz-utils
rm -rf /var/lib/apt/lists/*

if ! command -v bat >/dev/null && command -v batcat >/dev/null; then
    ln -s "$(command -v batcat)" /usr/local/bin/bat
fi

if ! command -v fd >/dev/null && command -v fdfind >/dev/null; then
    ln -s "$(command -v fdfind)" /usr/local/bin/fd
fi

architecture="$(dpkg --print-architecture)"

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
    local asset_regex="$2"
    local destination="$3"
    local api_url asset_url

    api_url="https://api.github.com/repos/${repo}/releases/latest"
    asset_url="$(
        curl -fsSL "$api_url" |
            jq -r --arg asset_regex "$asset_regex" \
                '[.assets[] | select(.name | test($asset_regex)) | .browser_download_url][0] // empty'
    )"

    if [[ -z "$asset_url" ]]; then
        echo "tools: could not find latest ${repo} release asset matching ${asset_regex}" >&2
        exit 1
    fi

    curl -fsSL "$asset_url" -o "$destination"
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

curl -fsSL \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${yq_arch}" \
    -o /usr/local/bin/yq
chmod 0755 /usr/local/bin/yq

download_github_release_asset "gitui-org/gitui" "$gitui_asset_regex" "$tmp_dir/gitui.tar.gz"
mkdir -p "$tmp_dir/gitui"
tar -xzf "$tmp_dir/gitui.tar.gz" -C "$tmp_dir/gitui"
install_executable_from_tree "$tmp_dir/gitui" gitui

download_github_release_asset "sxyazi/yazi" "$yazi_asset_regex" "$tmp_dir/yazi.zip"
mkdir -p "$tmp_dir/yazi"
unzip -q "$tmp_dir/yazi.zip" -d "$tmp_dir/yazi"
install_executable_from_tree "$tmp_dir/yazi" yazi
install_executable_from_tree "$tmp_dir/yazi" ya

download_github_release_asset "helix-editor/helix" "$helix_asset_regex" "$tmp_dir/helix.tar.xz"
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

download_github_release_asset "casey/just" "$just_asset_regex" "$tmp_dir/just.tar.gz"
mkdir -p "$tmp_dir/just"
tar -xzf "$tmp_dir/just.tar.gz" -C "$tmp_dir/just"
install_executable_from_tree "$tmp_dir/just" just

npm install --global @openai/codex

if [[ "$INSTALL_CLAUDE" == "true" ]]; then
    npm install --global @anthropic-ai/claude-code
fi
