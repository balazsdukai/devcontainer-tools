#!/usr/bin/env python3
"""Render a Markdown table of tool versions changed between two manifests."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
MANIFEST_PATH = "src/tools/tool-versions.json"
TOOL_NAMES = {
    "github": {
        "mikefarah/yq": "yq",
        "gitui-org/gitui": "GitUI",
        "sxyazi/yazi": "Yazi",
        "helix-editor/helix": "Helix",
        "casey/just": "just",
    },
    "npm": {
        "@openai/codex": "Codex CLI",
        "@anthropic-ai/claude-code": "Claude Code",
    },
}


def load_manifest_at_ref(ref: str) -> dict:
    contents = subprocess.run(
        ["git", "show", f"{ref}:{MANIFEST_PATH}"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return json.loads(contents)


def load_current_manifest() -> dict:
    with (ROOT / "tool-versions.json").open(encoding="utf-8") as file:
        return json.load(file)


def changes(previous: dict, current: dict) -> list[tuple[str, str, str]]:
    result = []
    for source in ("github", "npm"):
        for key, new_version in current[source].items():
            old_version = previous[source].get(key)
            if new_version == old_version:
                continue
            label = TOOL_NAMES[source].get(key, key)
            result.append(
                (
                    label,
                    str(old_version) if old_version else "not pinned",
                    str(new_version) if new_version else "not pinned",
                )
            )
    return result


def render_table(version_changes: list[tuple[str, str, str]]) -> str:
    lines = [
        "| Tool | Previous version | New version |",
        "| --- | --- | --- |",
    ]
    lines.extend(f"| {name} | `{old}` | `{new}` |" for name, old, new in version_changes)
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-ref", required=True, help="Git ref containing the previous version manifest")
    args = parser.parse_args()

    version_changes = changes(load_manifest_at_ref(args.base_ref), load_current_manifest())
    if not version_changes:
        print("No pinned tool versions changed.")
    else:
        print(render_table(version_changes))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
