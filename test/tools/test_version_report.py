#!/usr/bin/env python3
import importlib.util
import sys
import unittest
from pathlib import Path


repo_root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(repo_root / "src/tools"))

spec = importlib.util.spec_from_file_location("version_report", repo_root / "src/tools/version-report.py")
version_report = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(version_report)


class VersionReportTests(unittest.TestCase):
    def test_reports_initial_pins_as_unpinned_to_new_version(self):
        previous = {
            "github": {"mikefarah/yq": None},
            "npm": {"@openai/codex": None},
        }
        current = {
            "github": {"mikefarah/yq": "v4.54.1"},
            "npm": {"@openai/codex": "0.162.1"},
        }

        rows = version_report.changes(previous, current)

        self.assertEqual(
            rows,
            [
                ("yq", "not pinned", "v4.54.1"),
                ("Codex CLI", "not pinned", "0.162.1"),
            ],
        )
        self.assertIn("| yq | `not pinned` | `v4.54.1` |", version_report.render_table(rows))

    def test_reports_only_changed_tool_versions(self):
        previous = {"github": {"mikefarah/yq": "v4.53.0"}, "npm": {}}
        current = {"github": {"mikefarah/yq": "v4.54.1"}, "npm": {}}

        self.assertEqual(
            version_report.changes(previous, current),
            [("yq", "v4.53.0", "v4.54.1")],
        )


if __name__ == "__main__":
    unittest.main()
