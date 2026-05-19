# Dev Container Tools

Reusable Dev Container Features for personal workflow tooling that should sit
above project-specific devcontainers without becoming part of them.

## `tools`

`tools` installs reusable tools only:

- Codex
- Claude Code by default
- GitHub CLI
- `fd`
- `bat`
- `jq`
- `yq`
- `ripgrep`
- `ugrep`
- `fzf`
- small shell conveniences such as `less`, `procps`, and `bash-completion`

It intentionally does not install project runtimes, compilers, package managers,
or libraries. Rust, Python, C++, and project dependencies remain owned by each
project image.

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
- `~/.config/gh`

The examples default to `/home/vscode` through `TOOLS_CONTAINER_HOME`. Set that
local environment variable to another absolute home path when the base image
uses a different user, for example `/root` or `/home/dev`.

Each wrapper runs `validate-host-paths.sh` before startup. Missing required host
paths fail fast with a clear error instead of being silently auto-created by the
container runtime.

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
