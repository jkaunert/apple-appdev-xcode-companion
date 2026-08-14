from __future__ import annotations

import json
import os
import platform
import pty
import select
import subprocess
import tempfile
import time
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
FETCH_HOOK_RUNTIME_SCRIPT = (
    REPO_ROOT
    / "tools"
    / "xcode-headless-installer"
    / "scripts"
    / "fetch_hook_runtime.sh"
)
PLUGIN_NAME = "apple-appdev-workflow"
PLUGIN_VERSION = "0.2.1"
PLUGIN_SOURCE = "apple-developer-tools"
LOCAL_PLUGIN_SOURCE = "LocalAppleWorkflow"
APP_VERSION = "0.2.1"
APP_BUILD = "2"
REQUIRED_PROFILE_FILES = (
    "hooks/apple_router.mjs",
    "hooks/apple_contract_guard.mjs",
    "routing/router-policy.json",
    "routing/top-level-owner-kernel.md",
)
USER_PROMPT_SUBMIT_COMMAND = (
    '"$PLUGIN_ROOT/hooks/runtime/node" '
    '"$PLUGIN_ROOT/hooks/apple_router.mjs"'
)
STOP_COMMAND = (
    '"$PLUGIN_ROOT/hooks/runtime/node" '
    '"$PLUGIN_ROOT/hooks/apple_contract_guard.mjs"'
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
        hooks = {
            "hooks": {
                "UserPromptSubmit": [
                    {
                        "hooks": [
                            {
                                "type": "command",
                                "command": USER_PROMPT_SUBMIT_COMMAND,
                                "timeout": 5,
                            }
                        ]
                    }
                ],
                "Stop": [
                    {
                        "hooks": [
                            {
                                "type": "command",
                                "command": STOP_COMMAND,
                                "timeout": 5,
                            }
                        ]
                    }
                ],
            }
        }
        hooks_path = profile / "hooks" / "hooks.json"
        hooks_path.write_text(json.dumps(hooks, indent=2) + "\n")
        runtime = profile / "hooks" / "runtime" / "node"
        runtime.parent.mkdir(parents=True)
        runtime.write_text(
            "#!/bin/sh\n"
            "if [ \"${1:-}\" = \"--version\" ]; then\n"
            "  printf '%s\\n' 'v24.19.0'\n"
            "  exit 0\n"
            "fi\n"
            "INPUT=$(/bin/cat)\n"
            "case \"${1:-}\" in\n"
            "  *apple_router.mjs)\n"
            "    printf '%s\\n' '{\"continue\":true,\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":\"Routing: orchestrator-led\\nSelected owner: apple-appdev-workflow:apple-app-orchestrator\\nTop-level owner injection: applied\\nReason: prompt-signal:ios\"}}'\n"
            "    ;;\n"
            "  *apple_contract_guard.mjs)\n"
            "    case \"$INPUT\" in\n"
            "      *'\"stop_hook_active\":true'*) exit 0 ;;\n"
            "    esac\n"
            "    printf '%s\\n' '{\"decision\":\"block\",\"reason\":\"Apple workflow final-output contract failed: fixture\"}'\n"
            "    ;;\n"
            "  *) exit 1 ;;\n"
            "esac\n"
        )
        runtime.chmod(0o755)
        (runtime.parent / "LICENSE").write_text("Fixture runtime license.\n")
        (profile / "marker.txt").write_text(marker + "\n")
        return payload_root, profile

    def make_package_hook_runtime(self, root: Path) -> tuple[Path, Path]:
        root.mkdir(parents=True, exist_ok=True)
        runtime = root / "node"
        runtime.write_text(
            "#!/bin/sh\n"
            "if [ \"${1:-}\" = \"--version\" ]; then\n"
            "  printf '%s\\n' 'v24.19.0'\n"
            "  exit 0\n"
            "fi\n"
            "exit 0\n"
        )
        runtime.chmod(0o755)
        license_path = root / "LICENSE"
        license_path.write_text("Fixture runtime license.\n")
        return runtime, license_path

    def package_hook_arguments(self, root: Path) -> list[str]:
        runtime, license_path = self.make_package_hook_runtime(root)
        return [
            "--hook-runtime",
            str(runtime),
            "--hook-runtime-license",
            str(license_path),
        ]

    def run_installer(
        self,
        *arguments: str,
        expected_returncode: int = 0,
        environment: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [str(self.binary), *arguments],
            text=True,
            capture_output=True,
            check=False,
            env=environment,
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

    def config_path(self, xcode_home: Path) -> Path:
        return xcode_home / "config.toml"

    def test_help_names_public_plugin_source_as_default(self) -> None:
        result = self.run_installer("--help")

        self.assertIn(
            "Cache namespace. Defaults to apple-developer-tools.",
            result.stdout,
        )

    def test_hook_review_mode_runs_xcode_agent_with_xcode_codex_home(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            xcode_build = "27A5237l"
            agents_root = root / "Agents"
            agent = (
                agents_root
                / "XcodeVersions"
                / xcode_build
                / "codex"
                / "codex"
            )
            agent.parent.mkdir(parents=True)
            capture = root / "hook-review-capture.txt"
            agent.write_text(
                "#!/bin/sh\n"
                "printf '%s\\n' \"$CODEX_HOME\" > \"$HOOK_REVIEW_CAPTURE\"\n"
                "printf '%s\\n' \"$#\" >> \"$HOOK_REVIEW_CAPTURE\"\n"
                "/bin/pwd >> \"$HOOK_REVIEW_CAPTURE\"\n"
            )
            agent.chmod(0o755)
            xcode_home = root / "xcode-home"
            environment = os.environ.copy()
            environment["HOOK_REVIEW_CAPTURE"] = str(capture)

            result = self.run_installer(
                "--review-plugin-hooks",
                "--agents-root",
                str(agents_root),
                "--xcode-build",
                xcode_build,
                "--xcode-codex-home",
                str(xcode_home),
                environment=environment,
            )

            self.assertEqual(
                capture.read_text().splitlines(),
                [
                    str(xcode_home),
                    "0",
                    str(
                        (xcode_home / ".tmp/hook-trust-onboarding/workspace").resolve()
                    ),
                ],
            )

    def test_hook_review_mode_keeps_agent_in_terminal_foreground_process_group(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            xcode_build = "27A5237l"
            agents_root = root / "Agents"
            agent = (
                agents_root
                / "XcodeVersions"
                / xcode_build
                / "codex"
                / "codex"
            )
            agent.parent.mkdir(parents=True)
            agent.write_text(
                "#!/bin/sh\n"
                "agent_pgid=$(/bin/ps -o pgid= -p $$ | /usr/bin/tr -d ' ')\n"
                "terminal_pgid=$(/bin/ps -o tpgid= -p $$ | /usr/bin/tr -d ' ')\n"
                "printf 'agent_pgid=%s terminal_pgid=%s\\n' \"$agent_pgid\" \"$terminal_pgid\"\n"
                "test \"$agent_pgid\" = \"$terminal_pgid\"\n"
            )
            agent.chmod(0o755)
            xcode_home = root / "xcode-home"
            arguments = [
                str(self.binary),
                "--review-plugin-hooks",
                "--agents-root",
                str(agents_root),
                "--xcode-build",
                xcode_build,
                "--xcode-codex-home",
                str(xcode_home),
            ]

            child_pid, master_fd = pty.fork()
            if child_pid == 0:
                os.execve(str(self.binary), arguments, os.environ.copy())

            output = bytearray()
            status: int | None = None
            deadline = time.monotonic() + 3
            try:
                while time.monotonic() < deadline:
                    ready, _, _ = select.select([master_fd], [], [], 0.1)
                    if ready:
                        try:
                            output.extend(os.read(master_fd, 4096))
                        except OSError:
                            pass
                    waited_pid, waited_status = os.waitpid(child_pid, os.WNOHANG)
                    if waited_pid == child_pid:
                        status = waited_status
                        break
            finally:
                if status is None:
                    subprocess.run(
                        ["/usr/bin/pkill", "-TERM", "-s", str(child_pid)],
                        check=False,
                        capture_output=True,
                    )
                    time.sleep(0.1)
                    subprocess.run(
                        ["/usr/bin/pkill", "-KILL", "-s", str(child_pid)],
                        check=False,
                        capture_output=True,
                    )
                    _, status = os.waitpid(child_pid, 0)
                os.close(master_fd)

            rendered = output.decode(errors="replace")
            self.assertFalse(
                os.WIFSIGNALED(status),
                msg=f"hook review was terminated before completion:\n{rendered}",
            )
            self.assertEqual(
                os.waitstatus_to_exitcode(status),
                0,
                msg=f"hook review did not retain the terminal foreground:\n{rendered}",
            )
            self.assertRegex(
                rendered,
                r"agent_pgid=(\d+) terminal_pgid=\1",
            )

    def test_hook_review_mode_rejects_symlinked_onboarding_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            xcode_build = "27A5237l"
            agents_root = root / "Agents"
            agent = (
                agents_root
                / "XcodeVersions"
                / xcode_build
                / "codex"
                / "codex"
            )
            agent.parent.mkdir(parents=True)
            agent.write_text("#!/bin/sh\nexit 0\n")
            agent.chmod(0o755)
            xcode_home = root / "xcode-home"
            xcode_home.mkdir()
            external = root / "external"
            external.mkdir()
            (xcode_home / ".tmp").symlink_to(external, target_is_directory=True)

            result = self.run_installer(
                "--review-plugin-hooks",
                "--agents-root",
                str(agents_root),
                "--xcode-build",
                xcode_build,
                "--xcode-codex-home",
                str(xcode_home),
                expected_returncode=1,
            )

            self.assertIn(
                "Xcode Codex temporary directory must be a real directory",
                result.stderr,
            )
            self.assertEqual(list(external.iterdir()), [])

    def test_packaged_app_has_a_native_double_click_install_flow(self) -> None:
        source = SOURCE.read_text()

        self.assertIn("import AppKit", source)
        self.assertIn("if arguments.isEmpty", source)
        self.assertIn("return runInteractiveInstaller()", source)
        self.assertIn(
            'message: "Install Apple AppDev Workflow for Xcode?"',
            source,
        )
        self.assertIn("try installPackagedPluginProfile(options: options)", source)

    def test_interactive_install_offers_stock_codex_hook_review_without_pretrust(
        self,
    ) -> None:
        source = SOURCE.read_text()

        self.assertIn(
            "pre-trust either lifecycle hook: UserPromptSubmit or Stop.",
            source,
        )
        self.assertIn(
            "review and trust each lifecycle hook: UserPromptSubmit and Stop.",
            source,
        )
        self.assertIn('primaryButton: "Review Hooks"', source)
        self.assertIn("try launchHookReviewInTerminal()", source)
        self.assertIn('launcherPath="$0"', source)
        self.assertIn('/bin/rm -f -- "$launcherPath"', source)
        self.assertNotIn('key_path: "hooks.state"', source)
        self.assertNotIn("pre-trust the UserPromptSubmit hook.", source)
        self.assertNotIn(
            "review and trust the UserPromptSubmit hook with stock Codex.",
            source,
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
            self.assertIn(
                "would postflight UserPromptSubmit and Stop under sanitized PATH",
                result.stdout,
            )
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
            config = self.config_path(xcode_home)
            original_config = (
                'model = "gpt-5.5"\n\n'
                f'[plugins."{PLUGIN_NAME}@{LOCAL_PLUGIN_SOURCE}"]\n'
                "enabled = true\n\n"
                '[plugins."unrelated@example"]\n'
                "enabled = true\n"
            )
            config.write_text(original_config)

            install_result = self.run_installer(
                *self.install_arguments(payload_root, xcode_home)
            )

            self.assertEqual((target / "marker.txt").read_text().strip(), "new")
            self.assertIn(
                "hook postflight passed under sanitized PATH: UserPromptSubmit",
                install_result.stdout,
            )
            self.assertIn(
                "hook postflight passed under sanitized PATH: Stop",
                install_result.stdout,
            )
            self.assertIn(
                "hook postflight passed under sanitized PATH: Stop one-retry guard",
                install_result.stdout,
            )
            installed_config = config.read_text()
            self.assertIn(
                f'[plugins."{PLUGIN_NAME}@{PLUGIN_SOURCE}"]\nenabled = true',
                installed_config,
            )
            self.assertIn(
                f'[plugins."{PLUGIN_NAME}@{LOCAL_PLUGIN_SOURCE}"]\nenabled = false',
                installed_config,
            )
            self.assertIn(
                '[plugins."unrelated@example"]\nenabled = true',
                installed_config,
            )
            quarantine = xcode_home / ".tmp/plugins/quarantine" / PLUGIN_NAME
            backups = sorted(quarantine.glob(f"{PLUGIN_VERSION}-plugin-install-*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(
                (backups[0] / "previous-profile/marker.txt").read_text().strip(),
                "old",
            )

            self.run_installer(
                "--restore-plugin-profile",
                str(backups[0]),
                "--xcode-codex-home",
                str(xcode_home),
            )

            self.assertEqual((target / "marker.txt").read_text().strip(), "old")
            self.assertEqual(config.read_text(), original_config)
            replaced = sorted(quarantine.glob(f"{PLUGIN_VERSION}-before-restore-*"))
            self.assertEqual(len(replaced), 1)
            self.assertEqual(
                (replaced[0] / "previous-profile/marker.txt").read_text().strip(),
                "new",
            )
            self.assertFalse((root / "Agents").exists())

    def test_plugin_profile_fresh_install_rollback_removes_profile_and_restores_config(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, _ = self.make_payload(root, marker="new")
            xcode_home = root / "xcode-home"
            xcode_home.mkdir()
            config = self.config_path(xcode_home)
            original_config = (
                f'[plugins."{PLUGIN_NAME}@{LOCAL_PLUGIN_SOURCE}"]\n'
                "enabled = true\n"
            )
            config.write_text(original_config)

            self.run_installer(*self.install_arguments(payload_root, xcode_home))

            target = self.target(xcode_home)
            self.assertTrue(target.is_dir())
            quarantine = xcode_home / ".tmp/plugins/quarantine" / PLUGIN_NAME
            backups = sorted(quarantine.glob(f"{PLUGIN_VERSION}-plugin-install-*"))
            self.assertEqual(len(backups), 1)
            self.assertFalse((backups[0] / "previous-profile").exists())

            self.run_installer(
                "--restore-plugin-profile",
                str(backups[0]),
                "--xcode-codex-home",
                str(xcode_home),
            )

            self.assertFalse(target.exists())
            self.assertEqual(config.read_text(), original_config)

    def test_plugin_profile_fresh_install_rollback_removes_new_config(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, _ = self.make_payload(root, marker="new")
            xcode_home = root / "xcode-home"

            self.run_installer(*self.install_arguments(payload_root, xcode_home))

            target = self.target(xcode_home)
            config = self.config_path(xcode_home)
            self.assertTrue(target.is_dir())
            self.assertTrue(config.is_file())
            quarantine = xcode_home / ".tmp/plugins/quarantine" / PLUGIN_NAME
            backups = sorted(quarantine.glob(f"{PLUGIN_VERSION}-plugin-install-*"))
            self.assertEqual(len(backups), 1)

            self.run_installer(
                "--restore-plugin-profile",
                str(backups[0]),
                "--xcode-codex-home",
                str(xcode_home),
            )

            self.assertFalse(target.exists())
            self.assertFalse(config.exists())

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

    def test_plugin_profile_rejects_external_node_hook_commands(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, profile = self.make_payload(root, marker="invalid")
            hooks_path = profile / "hooks" / "hooks.json"
            hooks = json.loads(hooks_path.read_text())
            hooks["hooks"]["UserPromptSubmit"][0]["hooks"][0]["command"] = (
                'node "$PLUGIN_ROOT/hooks/apple_router.mjs"'
            )
            hooks_path.write_text(json.dumps(hooks, indent=2) + "\n")
            xcode_home = root / "xcode-home"

            result = self.run_installer(
                *self.install_arguments(payload_root, xcode_home),
                expected_returncode=1,
            )

            self.assertIn("must use the packaged hook runtime", result.stderr)
            self.assertFalse(self.target(xcode_home).exists())

    def test_hook_postflight_failure_restores_previous_profile_and_config(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload_root, profile = self.make_payload(root / "new", marker="new")
            runtime = profile / "hooks" / "runtime" / "node"
            runtime.write_text(
                "#!/bin/sh\n"
                "if [ \"${1:-}\" = \"--version\" ]; then\n"
                "  printf '%s\\n' 'v24.19.0'\n"
                "  exit 0\n"
                "fi\n"
                "exit 7\n"
            )
            runtime.chmod(0o755)
            _, old_profile = self.make_payload(root / "old", marker="old")
            xcode_home = root / "xcode-home"
            target = self.target(xcode_home)
            target.parent.mkdir(parents=True)
            subprocess.run(["/bin/cp", "-R", str(old_profile), str(target)], check=True)
            config = self.config_path(xcode_home)
            original_config = 'model = "gpt-5.5"\n'
            config.write_text(original_config)

            result = self.run_installer(
                *self.install_arguments(payload_root, xcode_home),
                expected_returncode=1,
            )

            self.assertIn("UserPromptSubmit hook postflight failed", result.stderr)
            self.assertEqual((target / "marker.txt").read_text().strip(), "old")
            self.assertEqual(config.read_text(), original_config)

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
            arguments[version_index] = f"{PLUGIN_VERSION}\nforged-log-line"

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
            hook_arguments = self.package_hook_arguments(root / "hook-runtime")

            result = subprocess.run(
                [
                    str(PACKAGE_SCRIPT),
                    "--plugin-profile",
                    str(profile),
                    "--plugin-version",
                    PLUGIN_VERSION,
                    "--version",
                    APP_VERSION,
                    "--output-dir",
                    str(output_dir),
                    *hook_arguments,
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn("validate --install-plugin-profile", result.stdout)
            self.assertIn("validate --review-plugin-hooks", result.stdout)
            self.assertIn("source_commit:", result.stdout)
            self.assertIn("source_dirty:", result.stdout)
            self.assertIn(f"app_version: {APP_VERSION}", result.stdout)
            self.assertIn(f"app_build: {APP_BUILD}", result.stdout)
            self.assertIn(
                f'-target "{platform.machine()}-apple-macosx15.0"',
                result.stdout,
            )
            self.assertNotIn("copy runtime payload", result.stdout)
            self.assertIn("embed self-contained hook runtime", result.stdout)
            self.assertIn(
                "AppleAppDevXcodeHeadlessInstaller-0.2.1.dmg",
                result.stdout,
            )
            self.assertNotIn(
                "AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg",
                result.stdout,
            )
            self.assertFalse(output_dir.exists())

    def test_hook_runtime_fetch_dry_run_is_pinned_and_non_mutating(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir) / "hook-runtime"

            result = subprocess.run(
                [
                    str(FETCH_HOOK_RUNTIME_SCRIPT),
                    "--output-dir",
                    str(output_dir),
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn("node_version: v24.19.0", result.stdout)
            self.assertIn("nodejs.org/dist/v24.19.0", result.stdout)
            self.assertFalse(output_dir.exists())

    def test_package_notarization_requires_release_signing_mode(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _, profile = self.make_payload(root, marker="package")
            hook_arguments = self.package_hook_arguments(root / "hook-runtime")

            result = subprocess.run(
                [
                    str(PACKAGE_SCRIPT),
                    "--plugin-profile",
                    str(profile),
                    "--notarize",
                    "--keychain-profile",
                    "fixture-profile",
                    *hook_arguments,
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
            hook_arguments = self.package_hook_arguments(root / "hook-runtime")

            result = subprocess.run(
                [
                    str(PACKAGE_SCRIPT),
                    "--plugin-profile",
                    str(profile),
                    "--plugin-version",
                    "../escape",
                    *hook_arguments,
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 2)
            self.assertIn("safe path component", result.stderr)

    def test_package_rejects_path_traversal_app_version(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _, profile = self.make_payload(root, marker="package")
            hook_arguments = self.package_hook_arguments(root / "hook-runtime")

            result = subprocess.run(
                [
                    str(PACKAGE_SCRIPT),
                    "--plugin-profile",
                    str(profile),
                    "--version",
                    "../escape",
                    *hook_arguments,
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 2)
            self.assertIn("app version must be one safe path component", result.stderr)


if __name__ == "__main__":
    unittest.main()
