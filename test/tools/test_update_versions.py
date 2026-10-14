#!/usr/bin/env python3
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.request import Request


repo_root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(repo_root / "src/tools"))

import importlib.util

spec = importlib.util.spec_from_file_location("update_versions", repo_root / "src/tools/update-versions.py")
update_versions = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(update_versions)


class UpdateVersionsTests(unittest.TestCase):
    def setUp(self):
        self.manifest = {
            "github": {"example/tool": "v1.0.0"},
            "npm": {"@example/tool": "1.0.0"},
        }
        self.feature = {"id": "tools", "version": "1.3.1"}

    def test_updates_pins_and_bumps_feature_patch_once(self):
        manifest, feature, changed = update_versions.update_versions(
            self.manifest,
            self.feature,
            github_lookup=lambda _: "v1.1.0",
            npm_lookup=lambda _: "1.2.0",
        )

        self.assertEqual(manifest["github"]["example/tool"], "v1.1.0")
        self.assertEqual(manifest["npm"]["@example/tool"], "1.2.0")
        self.assertEqual(feature["version"], "1.3.2")
        self.assertEqual(changed, ["example/tool", "@example/tool"])

    def test_no_updates_leave_feature_version_unchanged(self):
        manifest, feature, changed = update_versions.update_versions(
            self.manifest,
            self.feature,
            github_lookup=lambda _: "v1.0.0",
            npm_lookup=lambda _: "1.0.0",
        )

        self.assertEqual(manifest, self.manifest)
        self.assertEqual(feature, self.feature)
        self.assertEqual(changed, [])

    def test_queries_stable_release_and_npm_latest_endpoints(self):
        requested_urls = []

        class Response:
            def __init__(self, data):
                self.data = data

            def __enter__(self):
                return self

            def __exit__(self, *_):
                return False

            def read(self):
                return json.dumps(self.data).encode()

        def fake_urlopen(request, timeout):
            self.assertIsInstance(request, Request)
            requested_urls.append(request.full_url)
            if "api.github.com" in request.full_url:
                return Response({"tag_name": "v2.0.0"})
            return Response({"version": "2.0.0"})

        with patch.object(update_versions, "urlopen", side_effect=fake_urlopen):
            self.assertEqual(update_versions.latest_github_version("example/tool"), "v2.0.0")
            self.assertEqual(update_versions.latest_npm_version("@example/tool"), "2.0.0")

        self.assertEqual(
            requested_urls,
            [
                "https://api.github.com/repos/example/tool/releases/latest",
                "https://registry.npmjs.org/%40example%2Ftool/latest",
            ],
        )

    def test_rejects_prerelease_versions(self):
        class Response:
            def __init__(self, data):
                self.data = data

            def __enter__(self):
                return self

            def __exit__(self, *_):
                return False

            def read(self):
                return json.dumps(self.data).encode()

        def prerelease_response(request, timeout):
            if "api.github.com" in request.full_url:
                return Response({"tag_name": "v2.0.0-rc.1", "prerelease": True})
            return Response({"version": "2.0.0-beta.1"})

        with patch.object(update_versions, "urlopen", side_effect=prerelease_response):
            with self.assertRaises(ValueError):
                update_versions.latest_github_version("example/tool")
            with self.assertRaises(ValueError):
                update_versions.latest_npm_version("@example/tool")


if __name__ == "__main__":
    unittest.main()
