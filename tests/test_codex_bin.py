import os
import subprocess
import unittest
from unittest.mock import patch

from scripts import codex_quota_status as quota


class ResolveCodexBinTests(unittest.TestCase):
    def setUp(self):
        self.files = set()
        self.executables = set()
        self.patchers = [
            patch.dict(os.environ, {"CODEX_QUOTA_CODEX_BIN": "", "CODEX_BIN": ""}),
            patch.object(quota.shutil, "which", return_value=None),
            patch.object(quota.os.path, "isfile", side_effect=lambda path: path in self.files),
            patch.object(quota.os, "access", side_effect=lambda path, mode: path in self.executables),
            patch.object(quota, "_registered_codex_apps", return_value=[]),
        ]
        self.mocks = [patcher.start() for patcher in self.patchers]
        for patcher in self.patchers:
            self.addCleanup(patcher.stop)

    def add_executable(self, path):
        self.files.add(path)
        self.executables.add(path)

    def test_current_bundle_layouts_with_desktop_path(self):
        for app_path in (
            "/Applications/ChatGPT.app",
            "/Applications/Codex.app",
            "~/Applications/ChatGPT.app",
            "~/Applications/Codex.app",
        ):
            for relative_path in (
                "Contents/Resources/codex-cli/bin/codex",
                "Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            ):
                with self.subTest(app=app_path, layout=relative_path):
                    self.files.clear()
                    self.executables.clear()
                    expected = os.path.expanduser(os.path.join(app_path, relative_path))
                    self.add_executable(expected)
                    actual, searched = quota._resolve_codex_bin()
                    self.assertEqual(actual, expected)
                    self.assertIn(expected, searched)
        self.mocks[-1].assert_not_called()

    def test_legacy_bundle_layouts(self):
        for app_path in ("/Applications/ChatGPT.app", "/Applications/Codex.app", "~/Applications/Codex.app"):
            with self.subTest(app=app_path):
                self.files.clear()
                self.executables.clear()
                expected = os.path.expanduser(app_path + "/Contents/Resources/codex")
                self.add_executable(expected)
                self.assertEqual(quota._resolve_codex_bin()[0], expected)

    def test_overrides_and_path_keep_precedence(self):
        bundled = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
        for path in ("/custom/quota-codex", "/custom/codex", "/terminal/codex", bundled):
            self.add_executable(path)
        self.mocks[1].return_value = "/terminal/codex"
        with patch.dict(os.environ, {"CODEX_QUOTA_CODEX_BIN": "/custom/quota-codex", "CODEX_BIN": "/custom/codex"}):
            self.assertEqual(quota._resolve_codex_bin()[0], "/custom/quota-codex")
        with patch.dict(os.environ, {"CODEX_BIN": "/custom/codex"}):
            self.assertEqual(quota._resolve_codex_bin()[0], "/custom/codex")
        self.assertEqual(quota._resolve_codex_bin()[0], "/terminal/codex")

    def test_missing_or_non_executable_override_falls_back(self):
        bundled = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
        self.add_executable(bundled)
        self.files.add("/custom/not-executable")
        with patch.dict(os.environ, {"CODEX_QUOTA_CODEX_BIN": "/custom/not-executable", "CODEX_BIN": "/removed/codex"}):
            self.assertEqual(quota._resolve_codex_bin()[0], bundled)

    def test_registered_app_can_be_renamed_and_moved(self):
        app_path = "/Volumes/External/Apps/My Codex.app"
        expected = app_path + "/Contents/Resources/codex-cli/bin/codex"
        self.mocks[-1].return_value = [app_path]
        self.add_executable(expected)
        self.assertEqual(quota._resolve_codex_bin()[0], expected)
        self.mocks[-1].assert_called_once_with()

    def test_homebrew_still_works(self):
        self.add_executable("/opt/homebrew/bin/codex")
        self.assertEqual(quota._resolve_codex_bin()[0], "/opt/homebrew/bin/codex")
        self.mocks[-1].assert_not_called()

    def test_not_found_reports_searched_paths_without_duplicates(self):
        self.mocks[-1].return_value = ["/Applications/ChatGPT.app", "/other/Codex.app"]
        actual, searched = quota._resolve_codex_bin()
        self.assertIsNone(actual)
        self.assertEqual(len(searched), len(set(searched)))
        self.assertIn("/other/Codex.app/Contents/Resources/codex-cli/bin/codex", searched)


class RegisteredCodexAppsTests(unittest.TestCase):
    @patch.object(quota.sys, "platform", "darwin")
    @patch.object(quota.subprocess, "run")
    def test_returns_only_absolute_app_paths(self, run):
        run.return_value.stdout = '["/Volumes/Apps/Codex.app", null, 1, "relative.app"]'
        self.assertEqual(quota._registered_codex_apps(), ["/Volumes/Apps/Codex.app"])
        self.assertEqual(run.call_args.kwargs["timeout"], 2)
        self.assertTrue(run.call_args.kwargs["check"])

    @patch.object(quota.sys, "platform", "darwin")
    @patch.object(quota.subprocess, "run")
    def test_invalid_responses_are_ignored(self, run):
        for output in ("not JSON", '{}', '"/Applications/Codex.app"'):
            with self.subTest(output=output):
                run.return_value.stdout = output
                self.assertEqual(quota._registered_codex_apps(), [])

    @patch.object(quota.sys, "platform", "darwin")
    @patch.object(quota.subprocess, "run")
    def test_failed_or_timed_out_lookup_is_ignored(self, run):
        for error in (
            FileNotFoundError(),
            subprocess.CalledProcessError(1, "osascript"),
            subprocess.TimeoutExpired("osascript", 2),
        ):
            with self.subTest(error=type(error).__name__):
                run.side_effect = error
                self.assertEqual(quota._registered_codex_apps(), [])

    @patch.object(quota.sys, "platform", "linux")
    @patch.object(quota.subprocess, "run")
    def test_other_platforms_skip_macos_lookup(self, run):
        self.assertEqual(quota._registered_codex_apps(), [])
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
