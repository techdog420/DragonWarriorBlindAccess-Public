import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

import run_tests


REPO_ROOT = Path(__file__).resolve().parent


class RunTestsCommandQueueTests(unittest.TestCase):
    def test_check_command_queue_fails_clearly_when_bash_is_missing(self):
        with mock.patch.object(run_tests, "get_bash_runtime", return_value=None):
            with mock.patch.object(run_tests.subprocess, "run") as run:
                ok, detail = run_tests.check_command_queue()

        self.assertFalse(ok)
        self.assertEqual(detail, "bash not found on PATH")
        run.assert_not_called()

    def test_check_command_queue_uses_resolved_bash_and_helper_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            git_root = Path(tmp) / "Git"
            bash_dir = git_root / "bin"
            helper_dir = git_root / "usr" / "bin"
            bash_dir.mkdir(parents=True)
            helper_dir.mkdir(parents=True)
            resolved_bash = bash_dir / "bash.exe"
            resolved_bash.write_bytes(b"")
            caller_path = str(Path(tmp) / "caller-only")

            def run_queue_command(command, **kwargs):
                child_path = kwargs["env"]["PATH"].split(os.pathsep)
                self.assertEqual(child_path[:2], [str(helper_dir), str(bash_dir)])
                self.assertEqual(child_path[2:], [caller_path])
                cmd_file = Path(kwargs["cwd"]) / "dw_commands.txt"
                commands = cmd_file.read_text(encoding="utf-8").splitlines()
                commands.extend(command[2:])
                cmd_file.write_text("\n".join(commands) + "\n", encoding="utf-8")
                return subprocess.CompletedProcess(command, 0, "", "")

            with mock.patch.dict(os.environ, {"PATH": caller_path}):
                with mock.patch.object(
                    run_tests, "get_bash_runtime", return_value=str(resolved_bash)
                ):
                    with mock.patch.object(
                        run_tests.subprocess, "run", side_effect=run_queue_command
                    ) as run:
                        ok, detail = run_tests.check_command_queue()

        self.assertTrue(ok)
        self.assertEqual(detail, "dw_commands.sh append queue OK")
        self.assertEqual(run.call_count, 2)
        for call in run.call_args_list:
            self.assertEqual(call.args[0][0], str(resolved_bash))


class DwCommandsShTests(unittest.TestCase):
    def setUp(self):
        self.bash = run_tests.get_bash_runtime()
        if not self.bash:
            self.skipTest("bash is required for dw_commands.sh tests")
        self.bash_env = run_tests.get_bash_environment(self.bash)
        self.tmp = tempfile.TemporaryDirectory()
        self.tmp_path = Path(self.tmp.name)
        self.script = self.tmp_path / "dw_commands.sh"
        shutil.copy2(REPO_ROOT / "dw_commands.sh", self.script)
        self.script.chmod(0o755)

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, *args):
        return subprocess.run(
            [self.bash, self.script.as_posix(), *args],
            cwd=self.tmp_path,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            env=self.bash_env,
        )

    def read_commands(self):
        path = self.tmp_path / "dw_commands.txt"
        if not path.exists():
            return []
        return path.read_text(encoding="ascii").splitlines()

    def test_json_replace_writes_commands(self):
        result = self.run_script("--json", "--replace", "report_position")
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "sent")
        self.assertEqual(payload["commands"], ["report_position"])
        self.assertTrue(payload["sent"])
        self.assertEqual(self.read_commands(), ["report_position"])

    def test_require_live_fails_before_queueing_when_log_missing(self):
        result = self.run_script("--json", "--replace", "--require-live", "5", "report_position")
        self.assertEqual(result.returncode, 3)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "not_live")
        self.assertFalse(payload["sent"])
        self.assertEqual(self.read_commands(), [])

    def test_require_live_fails_before_queueing_when_log_stale(self):
        log_path = self.tmp_path / "dw_debug.log"
        log_path.write_text("old\n", encoding="utf-8")
        old_time = time.time() - 120
        os.utime(log_path, (old_time, old_time))

        result = self.run_script("--json", "--replace", "--require-live", "5", "report_position")
        self.assertEqual(result.returncode, 3)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "not_live")
        self.assertFalse(payload["sent"])
        self.assertEqual(self.read_commands(), [])

    def test_wait_ready_queues_probe_and_reports_timeout(self):
        (self.tmp_path / "dw_debug.log").write_text("header\n", encoding="utf-8")
        result = self.run_script(
            "--json",
            "--replace",
            "--timeout",
            "1",
            "--wait-ready",
            "unit_probe",
            "report_position",
        )
        self.assertEqual(result.returncode, 2)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "timeout")
        self.assertEqual(payload["wait_pattern"], "LAUNCHER_PROBE: unit_probe")
        self.assertTrue(payload["sent"])
        self.assertTrue(payload["timed_out"])
        self.assertEqual(self.read_commands(), ["launcher_probe:unit_probe", "report_position"])

    def test_wait_and_wait_ready_are_mutually_exclusive(self):
        result = self.run_script(
            "--json",
            "--replace",
            "--wait",
            "POSITION:",
            "--wait-ready",
            "unit_probe",
            "report_position",
        )
        self.assertEqual(result.returncode, 1)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "error")
        self.assertFalse(payload["sent"])
        self.assertEqual(self.read_commands(), [])


class RunTestsInventoryTests(unittest.TestCase):
    def test_all_lua_test_files_are_run_or_explicitly_classified(self):
        discovered = {path.name for path in REPO_ROOT.glob("test_*.lua")}
        classified = (
            set(run_tests.LUA_TEST_FILES)
            | run_tests.LUA_TEST_HELPERS
            | run_tests.LUA_EMULATOR_DIAGNOSTICS
        )

        self.assertEqual(discovered, classified)
        self.assertIn("test_debug_tools.lua", run_tests.LUA_TEST_FILES)
        self.assertIn("test_text.lua", run_tests.LUA_TEST_FILES)
        self.assertNotIn("test_env.lua", run_tests.LUA_TEST_FILES)

    def test_python_discovery_contains_only_automated_test_modules(self):
        self.assertIn("test_tooling.py", run_tests.PYTHON_TEST_FILES)
        self.assertNotIn("speech_smoke.py", run_tests.PYTHON_TEST_FILES)


class PreToolGuardTests(unittest.TestCase):
    hook_path = REPO_ROOT / ".codex" / "hooks" / "pretool_dw_command_guard.py"

    def run_hook(self, command):
        payload = {"tool_input": {"command": command}}
        return subprocess.run(
            [sys.executable, "-B", str(self.hook_path)],
            input=json.dumps(payload),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def assert_denied(self, command):
        result = self.run_hook(command)
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["hookSpecificOutput"]["permissionDecision"], "deny")

    def assert_allowed(self, command):
        result = self.run_hook(command)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_blocks_teleport_with_probe_in_same_invocation(self):
        self.assert_denied("./dw_commands.sh --replace teleport_to:1,2 probe_edge:UP")

    def test_blocks_state_sensitive_command_without_replace(self):
        self.assert_denied("./dw_commands.sh teleport_to:1,2")

    def test_allows_independent_read_only_append(self):
        self.assert_allowed("./dw_commands.sh report_position speech_status")

    def test_allows_documentation_string_that_mentions_bad_command(self):
        self.assert_allowed(
            "printf '%s\\n' './dw_commands.sh --replace teleport_to:1,2 probe_edge:UP'"
        )

    def test_blocks_direct_command_file_write(self):
        self.assert_denied(": > dw_commands.txt")

    def test_blocks_touch_main_without_probe_or_wait(self):
        self.assert_denied("touch main.lua")

    def test_allows_touch_main_with_wait_ready_probe(self):
        self.assert_allowed("touch main.lua && ./dw_commands.sh --replace --wait-ready reload_probe")

    def test_blocks_nested_bash_command(self):
        self.assert_denied("bash -lc './dw_commands.sh teleport_to:1,2'")


if __name__ == "__main__":
    unittest.main()
