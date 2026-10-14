#!/usr/bin/env python3
"""Update pinned upstream tool versions and the Feature patch version."""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / "tool-versions.json"
FEATURE = ROOT / "devcontainer-feature.json"
SEMVER = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
STABLE_VERSION = re.compile(r"^v?\d+\.\d+\.\d+(?:\+[0-9A-Za-z.-]+)?$")


def fetch_json(url: str) -> dict:
    headers = {"User-Agent": "devcontainer-tools-version-check"}
    token = os.environ.get("GITHUB_TOKEN")
    if token and url.startswith("https://api.github.com/"):
        headers["Authorization"] = f"Bearer {token}"
    request = Request(url, headers=headers)
    with urlopen(request, timeout=30) as response:
        return json.load(response)


def latest_github_version(repository: str) -> str:
    release = fetch_json(f"https://api.github.com/repos/{repository}/releases/latest")
    version = release.get("tag_name")
    if not isinstance(version, str) or not version:
        raise ValueError(f"GitHub returned no stable release tag for {repository}")
    if release.get("prerelease") or not STABLE_VERSION.fullmatch(version):
        raise ValueError(f"GitHub returned a prerelease version for {repository}: {version}")
    return version


def latest_npm_version(package: str) -> str:
    package_path = quote(package, safe="")
    package_data = fetch_json(f"https://registry.npmjs.org/{package_path}/latest")
    version = package_data.get("version")
    if not isinstance(version, str) or not version:
        raise ValueError(f"npm returned no latest version for {package}")
    if not STABLE_VERSION.fullmatch(version):
        raise ValueError(f"npm latest points to a prerelease version for {package}: {version}")
    return version


def read_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def update_versions(
    manifest: dict,
    feature: dict,
    github_lookup=latest_github_version,
    npm_lookup=latest_npm_version,
) -> tuple[dict, dict, list[str]]:
    updated_manifest = json.loads(json.dumps(manifest))
    changed: list[str] = []

    for repository, current in manifest["github"].items():
        latest = github_lookup(repository)
        if latest != current:
            updated_manifest["github"][repository] = latest
            changed.append(repository)

    for package, current in manifest["npm"].items():
        latest = npm_lookup(package)
        if latest != current:
            updated_manifest["npm"][package] = latest
            changed.append(package)

    updated_feature = json.loads(json.dumps(feature))
    if changed:
        match = SEMVER.fullmatch(feature.get("version", ""))
        if not match:
            raise ValueError("Feature version must use three-part semantic versioning")
        major, minor, patch = (int(part) for part in match.groups())
        updated_feature["version"] = f"{major}.{minor}.{patch + 1}"

    return updated_manifest, updated_feature, changed


def main() -> int:
    manifest = read_json(MANIFEST)
    feature = read_json(FEATURE)
    updated_manifest, updated_feature, changed = update_versions(manifest, feature)

    if not changed:
        print("All pinned tools are already at their latest stable versions.")
        return 0

    write_json(MANIFEST, updated_manifest)
    write_json(FEATURE, updated_feature)
    print("Updated stable versions:")
    for name in changed:
        print(f"- {name}")
    print(f"Feature version: {feature['version']} -> {updated_feature['version']}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (HTTPError, OSError, ValueError, KeyError) as error:
        print(f"Version update failed: {error}", file=sys.stderr)
        sys.exit(1)
