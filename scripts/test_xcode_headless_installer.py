from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE = (
    REPO_ROOT
    / "tools"
    / "xcode-headless-installer"
    / "Sources"
    / "XcodeHeadlessInstaller"
    / "main.swift"
)
PACKAGE_SCRIPT = (
    REPO_ROOT / "tools" / "xcode-headless-installer" / "scripts" / "package_dmg.sh"
)
PLUGIN_NAME = "apple-appdev-workflow"
PLUGIN_VERSION = "0.2.0"
PLUGIN_SOURCE = "apple-developer-tools"
REQUIRED_PROFILE_FILES = (
    "hooks/hooks.json",
    "hooks/apple_router.mjs",
    "routing/router-policy.json",
    "routing/top-level-owner-kernel.md",
)


class XcodeHeadlessInstallerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._build_temp = tempfile.TemporaryDirectory()
        cls.binary = Path(cls._build_temp.name) / "xcode-headless-installer"
        subprocess.run(
            ["xcrun", "swiftc", "-O", "-o", str(cls.binary), str(SOURCE)],
            check=True,
            text=True,
            capture_output=True,
        )

    @classmethod
    def tearDownClass(cls) -> None:
        cls._build_temp.cleanup()

    def make_payload(
        self,
        root: Path,
        *,
        marker: str,
        manifest_additions: dict[str, object] | None = None,
    ) -> tuple[Path, Path]:
        payload_root = root / "payload"
        profile = payload_root / PLUGIN_NAME / PLUGIN_VERSION
        manifest_dir = profile / ".codex-plugin"
        manifest_dir.mkdir(parents=True)
        manifest: dict[str, object] = {
            "name": PLUGIN_NAME,
            "version": PLUGIN_VERSION,
        }
        if manifest_additions:
            manifest.update(manifest_additions)
        (manifest_dir / "plugin.json").write_text(json.dumps(manifest) + "\n")
        for relative_path in REQUIRED_PROFILE_FILES:
            path = profile / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"fixture:{relative_path}\n")
        (profile / "marker.txt").write_text(marker + "\n")
        return payload_root, profile

    def run_installer(
        self,
        *arguments: str,
        expected_returncode: int = 0,
    ) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [str(self.binary), *arguments],
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(
            result.returncode,
            expected_returncode,
            msg=f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}",
        )
        return result

    def install_arguments(self, payload_root: Path, xcode_home: Path) -> list[str]:
        return [
            "--install-plugin-profile",
            "--plugin-payload-root",
            str(payload_root),
            "--plugin-version",
            PLUGIN_VERSION,
            "--xcode-codex-home",
            str(xcode_home),
        ]

    def target(self, xcode_home: Path) -> Path:
        return (
            xcode_home
            / "plugins"
            / "cache"
            / PLUGIN_SOURCE
            / PLUGIN_NAME
            / PLUGIN_VERSION
        )

    def test_help_names_public_plugin_source_as_default(self) -> None:
        result = self.run_installer("--help")

        self.assertIn(
            "Cache namespace. Defaults to apple-developer-tools.",
            result.stdout,
        )

    def test_plugin_profile_dry_run_never_mutates_xcode_home(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, _ = self.make_payload(root, marker="new")
            xcode_home = root / "xcode-home"

            result = self.run_installer(
                *self.install_arguments(payload_root, xcode_home),
                "--dry-run",
            )

            self.assertIn("Xcode active Codex agent remains unchanged", result.stdout)
            self.assertFalse(xcode_home.exists())

    def test_plugin_profile_install_backs_up_and_restores_same_version(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, _ = self.make_payload(root / "new", marker="new")
            _, old_profile = self.make_payload(root / "old", marker="old")
            xcode_home = root / "xcode-home"
            target = self.target(xcode_home)
            target.parent.mkdir(parents=True)
            subprocess.run(["/bin/cp", "-R", str(old_profile), str(target)], check=True)

            self.run_installer(*self.install_arguments(payload_root, xcode_home))

            self.assertEqual((target / "marker.txt").read_text().strip(), "new")
            quarantine = xcode_home / ".tmp/plugins/quarantine" / PLUGIN_NAME
            backups = sorted(quarantine.glob(f"{PLUGIN_VERSION}-full-plugin-cache-*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual((backups[0] / "marker.txt").read_text().strip(), "old")

            self.run_installer(
                "--restore-plugin-profile",
                str(backups[0]),
                "--xcode-codex-home",
                str(xcode_home),
            )

            self.assertEqual((target / "marker.txt").read_text().strip(), "old")
            replaced = sorted(quarantine.glob(f"{PLUGIN_VERSION}-before-restore-*"))
            self.assertEqual(len(replaced), 1)
            self.assertEqual((replaced[0] / "marker.txt").read_text().strip(), "new")
            self.assertFalse((root / "Agents").exists())

    def test_plugin_profile_rejects_plugin_managed_mcp_servers(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, _ = self.make_payload(
                root,
                marker="invalid",
                manifest_additions={"mcpServers": "./.mcp.json"},
            )
            xcode_home = root / "xcode-home"

            result = self.run_installer(
                *self.install_arguments(payload_root, xcode_home),
                expected_returncode=1,
            )

            self.assertIn("must omit mcpServers", result.stderr)
            self.assertFalse(self.target(xcode_home).exists())

    def test_plugin_profile_rejects_path_traversal_version(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, _ = self.make_payload(root, marker="new")
            xcode_home = root / "xcode-home"
            arguments = self.install_arguments(payload_root, xcode_home)
            version_index = arguments.index(PLUGIN_VERSION)
            arguments[version_index] = "../escape"

            result = self.run_installer(*arguments, expected_returncode=1)

            self.assertIn("safe path component", result.stderr)
            self.assertFalse(xcode_home.exists())

    def test_plugin_profile_rejects_symbolic_link_payload(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, profile = self.make_payload(root, marker="new")
            external = root / "external-router.mjs"
            external.write_text("external\n")
            router = profile / "hooks" / "apple_router.mjs"
            router.unlink()
            router.symlink_to(external)
            xcode_home = root / "xcode-home"

            result = self.run_installer(
                *self.install_arguments(payload_root, xcode_home),
                expected_returncode=1,
            )

            self.assertIn("must not contain symbolic links", result.stderr)
            self.assertFalse(xcode_home.exists())

    def test_plugin_profile_rejects_required_payload_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, profile = self.make_payload(root, marker="new")
            router = profile / "hooks" / "apple_router.mjs"
            router.unlink()
            router.mkdir()
            xcode_home = root / "xcode-home"

            result = self.run_installer(
                *self.install_arguments(payload_root, xcode_home),
                expected_returncode=1,
            )

            self.assertIn("required regular file", result.stderr)
            self.assertFalse(xcode_home.exists())

    def test_plugin_profile_rejects_malformed_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, profile = self.make_payload(root, marker="new")
            (profile / ".codex-plugin/plugin.json").write_text("{not-json\n")
            xcode_home = root / "xcode-home"

            self.run_installer(
                *self.install_arguments(payload_root, xcode_home),
                expected_returncode=1,
            )

            self.assertFalse(xcode_home.exists())

    def test_plugin_profile_rejects_control_characters_in_version(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, _ = self.make_payload(root, marker="new")
            xcode_home = root / "xcode-home"
            arguments = self.install_arguments(payload_root, xcode_home)
            version_index = arguments.index(PLUGIN_VERSION)
            arguments[version_index] = "0.2.0\nforged-log-line"

            result = self.run_installer(*arguments, expected_returncode=1)

            self.assertIn("safe path component", result.stderr)
            self.assertFalse(xcode_home.exists())

    def test_plugin_restore_rejects_path_outside_quarantine(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _, profile = self.make_payload(root, marker="outside")
            xcode_home = root / "xcode-home"

            result = self.run_installer(
                "--restore-plugin-profile",
                str(profile),
                "--xcode-codex-home",
                str(xcode_home),
                expected_returncode=1,
            )

            self.assertIn("restore path must be inside", result.stderr)
            self.assertFalse(xcode_home.exists())

    def test_profile_only_package_dry_run_never_requires_agent_runtime(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _, profile = self.make_payload(root, marker="package")
            output_dir = root / "output"

            result = subprocess.run(
                [
                    str(PACKAGE_SCRIPT),
                    "--plugin-profile",
                    str(profile),
                    "--plugin-version",
                    PLUGIN_VERSION,
                    "--output-dir",
                    str(output_dir),
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn("validate --install-plugin-profile", result.stdout)
            self.assertNotIn("copy runtime payload", result.stdout)
            self.assertFalse(output_dir.exists())

    def test_package_notarization_requires_release_signing_mode(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _, profile = self.make_payload(root, marker="package")

            result = subprocess.run(
                [
                    str(PACKAGE_SCRIPT),
                    "--plugin-profile",
                    str(profile),
                    "--notarize",
                    "--keychain-profile",
                    "fixture-profile",
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 2)
            self.assertIn("--notarize requires --release", result.stderr)

    def test_package_rejects_path_traversal_plugin_version(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _, profile = self.make_payload(root, marker="package")

            result = subprocess.run(
                [
                    str(PACKAGE_SCRIPT),
                    "--plugin-profile",
                    str(profile),
                    "--plugin-version",
                    "../escape",
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 2)
            self.assertIn("safe path component", result.stderr)


if __name__ == "__main__":
    unittest.main()
