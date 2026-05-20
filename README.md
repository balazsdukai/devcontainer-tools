# Dev Container Tools

Reusable Dev Container Features for personal workflow tooling that should sit
above project-specific devcontainers without becoming part of them.

## `tools`

`tools` installs reusable tools only:

- Codex
- Claude Code by default
- GitUI
- Yazi
- Helix
- GitHub CLI
- `just`
- `fd`
- `bat`
- `jq`
- `yq`
- `ripgrep`
- `ugrep`
- `fzf`
- small shell conveniences such as `less`, `procps`, and `bash-completion`

It installs Node.js 22 only as the runtime for npm-distributed CLI tools such as
Codex and Claude Code. It intentionally does not install project runtimes,
compilers, package managers, or libraries beyond that tool dependency. Rust,
Python, C++, and project dependencies remain owned by each project image.

Personal auth and mutable state also stay outside the image. Mount them at
runtime from private wrappers or project-local devcontainer overrides so rebuilt
images never contain personal credentials.

## Use The Feature

Reference the published Feature from a devcontainer:

```jsonc
{
  "features": {
    "ghcr.io/balazsdukai/devcontainer-tools/tools:1": {}
  }
}
```

`installClaude` is the only v1 option:

```jsonc
{
  "features": {
    "ghcr.io/balazsdukai/devcontainer-tools/tools:1": {
      "installClaude": false
    }
  }
}
```

The Feature supports Debian and Ubuntu family images only in v1. The same
Feature is intended to work above Rust, Python, and C++ base images because it
does not own language setup.

## Wrapper Contract

Wrappers mount these host paths read-write from `${localEnv:HOME}`:

- `~/.codex`
- `~/.claude`
- `~/.claude.json`

Wrappers also bind-mount the host SSH agent socket from
`${localEnv:SSH_AUTH_SOCK}` to `/ssh-agent` and set
`SSH_AUTH_SOCK=/ssh-agent` inside the container. This lets Git-over-SSH use the
host agent, including the Bitwarden SSH agent, without mounting the full host
home or copying private keys into the container.

GitHub CLI authentication is provided through `GH_TOKEN` in `remoteEnv`, not by
mounting `~/.config/gh`. Export `GH_TOKEN` in the host environment before
starting JetBrains or the devcontainer launcher:

```sh
export GH_TOKEN=github_pat_...
```

`gh` reads `GH_TOKEN` directly inside the container and prefers it over stored
credentials. This avoids storing a GitHub token as plaintext in
`~/.config/gh/hosts.yml`.

The examples mount into `/home/vscode` explicitly because container environment
variables are not reliably expanded in mount targets. `TOOLS_CONTAINER_HOME`
is still set inside the container for scripts and tools that need the effective
home path at runtime.

Each wrapper runs `validate-host-paths.sh` before startup. Missing required host
paths fail fast with a clear error instead of being silently auto-created by the
container runtime.

The devcontainer launcher must inherit `SSH_AUTH_SOCK` and `GH_TOKEN`;
otherwise `${localEnv:SSH_AUTH_SOCK}` and `${localEnv:GH_TOKEN}` expand to empty
values. If JetBrains or another launcher is started from the desktop without
that environment, start it from a shell that has the agent and token environment
or configure the variables at the desktop/session level.

Before launching a wrapper, verify the host sees the expected Bitwarden socket
and keys:

```sh
echo "$SSH_AUTH_SOCK"
ssh-add -l
```

Verify GitHub CLI authentication inside the container:

```sh
gh auth status
```

Fresh containers may also need to trust GitHub's SSH host key before
noninteractive Git commands can connect. To accept it during a verification
command, run:

```sh
GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" git ls-remote git@github.com:balazsdukai/devcontainer-tools.git HEAD
```

## Layout

```text
src/tools/                            # reusable Feature
test/tools/                           # Feature checks
examples/wrappers/{rust,python,cpp}/  # private wrapper examples
examples/wrappers/scripts/            # wrapper validation helpers
```

## Verification

```sh
./test/tools/run-local-tests.sh
./test/tools/test-wrapper-mounts.sh
```

When the Dev Container CLI is available, the tests under `test/tools/` are also
shaped for Feature test runners and exercise the same Feature against generic
Debian/Ubuntu bases plus the Rust scenario used for option coverage.
