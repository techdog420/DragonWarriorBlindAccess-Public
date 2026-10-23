import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent
PLAYER = REPO_ROOT / "release" / "play_player.ps1"
CMD_ENTRY_POINT = REPO_ROOT / "release" / "Play Dragon Warrior.cmd"
POWERSHELL = shutil.which("powershell.exe") or shutil.which("powershell")
CMD = shutil.which("cmd.exe")


@unittest.skipUnless(POWERSHELL, "Windows PowerShell is required")
class PlayerLaunchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.temp_root = Path(self.tmp.name)
        self.root = self.temp_root / "test package"
        for relative_path in (
            "app/main.lua",
            "app/launch_dw.ps1",
            "app/launch_dw.cmd",
            "app/keyboard_bridge.ps1",
            "app/speech_bridge.py",
            "app/dw_access.ini",
            "runtime/fceux/qfceux.exe",
            "runtime/python/python.exe",
            "user/fceux/fceux.cfg",
        ):
            path = self.root / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"test package file\n")

        self.rom_bytes = b"player-launch-unit-test-rom"
        self.rom_path = self.root / "user" / "Dragon Warrior.nes"
        self.rom_path.write_bytes(self.rom_bytes)
        self.manifest_path = self.root / "app" / "roms.json"
        self.manifest_path.write_text(
            json.dumps(
                {
                    "roms": [
                        {
                            "name": "Unit Test Revision",
                            "size": len(self.rom_bytes),
                            "sha256": hashlib.sha256(self.rom_bytes).hexdigest().upper(),
                        }
                    ]
                }
            ),
            encoding="utf-8",
        )

    def tearDown(self):
        self.tmp.cleanup()

    def run_player(self, *args, root=None):
        package_root = root or self.root
        return subprocess.run(
            [
                POWERSHELL,
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(PLAYER),
                "-PackageRoot",
                str(package_root),
                "-RomManifestPath",
                str(package_root / "app" / "roms.json"),
                *map(str, args),
            ],
            text=True,
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def test_cmd_entry_point_passes_valid_package_root_from_explorer_style_path(self):
        if not CMD:
            self.skipTest("cmd.exe is required")

        package_root = self.temp_root / "Explorer package"
        app_directory = package_root / "app"
        app_directory.mkdir(parents=True)
        entry_point = package_root / CMD_ENTRY_POINT.name
        shutil.copy2(CMD_ENTRY_POINT, entry_point)
        (app_directory / "play_player.ps1").write_text(
            """param([string] $PackageRoot)
try {
    $fullPath = [System.IO.Path]::GetFullPath($PackageRoot)
    Write-Output ("PACKAGE_ROOT=" + $fullPath)
    exit 0
} catch {
    Write-Error $_
    exit 9
}
""",
            encoding="utf-8",
        )

        result = subprocess.run(
            [CMD, "/d", "/c", "call", str(entry_point)],
            input="\n",
            text=True,
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=15,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn(f"PACKAGE_ROOT={package_root.resolve()}", result.stdout)
        self.assertNotIn("Illegal characters in path", result.stderr + result.stdout)

    def test_validate_only_uses_package_relative_private_paths(self):
        result = self.run_player("-ValidateOnly")

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("Player package validation passed.", result.stdout)
        self.assertIn(str(self.root / "runtime" / "fceux" / "qfceux.exe"), result.stdout)
        self.assertIn(str(self.root / "user" / "fceux"), result.stdout)
        self.assertIn(str(self.root / "user" / "Dragon Warrior.nes"), result.stdout)
        self.assertIn(str(self.root / "app" / "main.lua"), result.stdout)
        self.assertIn("Private FCEUX Lua autoload path refreshed.", result.stdout)
        self.assertIn("Validation only: no emulator was started.", result.stdout)
        config_text = (self.root / "user" / "fceux" / "fceux.cfg").read_text(encoding="utf-8")
        normalized_lua_path = str(self.root / "app" / "main.lua").replace("\\", "/")
        self.assertIn(f"SDL.LastLoadLua = {normalized_lua_path}", config_text)
        self.assertIn(f"SDL.LuaScript = {normalized_lua_path}", config_text)

    def test_validate_only_uses_ascii_fceux_aliases_for_unicode_package_path(self):
        unicode_root = self.temp_root / "DWA – été тест 日本語"
        shutil.copytree(self.root, unicode_root)

        result = self.run_player("-ValidateOnly", root=unicode_root)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn(
            "Non-ASCII installation path detected; using Windows compatibility aliases for FCEUX.",
            result.stdout,
        )
        config_text = (unicode_root / "user" / "fceux" / "fceux.cfg").read_text(
            encoding="utf-8"
        )
        lua_lines = [
            line
            for line in config_text.splitlines()
            if line.startswith(("SDL.LastLoadLua = ", "SDL.LuaScript = "))
        ]
        self.assertEqual(len(lua_lines), 2)
        self.assertTrue(all(line.isascii() for line in lua_lines), lua_lines)
        self.assertTrue(all(line.endswith("/app/main.lua") for line in lua_lines), lua_lines)

    def test_repeated_validation_preserves_literal_dollar_in_package_path(self):
        special_root = self.temp_root / "DWA $& package"
        shutil.copytree(self.root, special_root)
        for _ in range(2):
            result = self.run_player("-ValidateOnly", root=special_root)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            config_text = (special_root / "user/fceux/fceux.cfg").read_text(encoding="utf-8")
            lua_path = str(special_root / "app/main.lua").replace("\\", "/")
            for key in ("SDL.LastLoadLua", "SDL.LuaScript"):
                lines = [line for line in config_text.splitlines() if line.startswith(key + " =")]
                self.assertEqual(lines, [f"{key} = {lua_path}"])

    def test_all_fceux_config_writers_preserve_literal_replacement_characters(self):
        probe = self.temp_root / "config-writer-probe.ps1"
        probe.write_text(r'''
param([string] $RepoPath, [string] $ConfigFile)
$ErrorActionPreference = "Stop"
foreach ($relativePath in @("release\install_player.ps1", "release\play_player.ps1", "launch_dw.ps1")) {
    $name = if ($relativePath -eq "launch_dw.ps1") { "Set-ConfigValue" } else { "Set-PrivateFceuxConfigValue" }
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $RepoPath $relativePath), [ref] $tokens, [ref] $parseErrors)
    if ($parseErrors.Count -gt 0) { throw "Could not parse $relativePath" }
    $writer = $ast.Find({param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true)
    . ([scriptblock]::Create($writer.Extent.Text))
    [IO.File]::WriteAllText($ConfigFile, "SDL.LuaScript = old`r`nSDL.Sound.Volume = 128`r`n")
    $value = 'D:/Games/$&/$1/$$/${name}/app/main.lua'
    & $name -ConfigPath $ConfigFile -Key "SDL.LuaScript" -Value $value
    $lines = [IO.File]::ReadAllLines($ConfigFile)
    if ($lines[0] -cne "SDL.LuaScript = $value") { throw "Path corrupted by $relativePath : $($lines[0])" }
    if ($lines[1] -cne "SDL.Sound.Volume = 128") { throw "Unrelated setting changed" }
}
Write-Output "literal-config-writers=OK"
''', encoding="utf-8")
        result = subprocess.run(
            [POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(probe),
             "-RepoPath", str(REPO_ROOT), "-ConfigFile", str(self.temp_root / "fceux.cfg")],
            text=True, errors="replace", capture_output=True, timeout=15, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("literal-config-writers=OK", result.stdout)

    def test_missing_installed_rom_directs_player_to_setup(self):
        self.rom_path.unlink()

        result = self.run_player("-ValidateOnly")

        self.assertEqual(result.returncode, 2, result.stderr + result.stdout)
        self.assertIn("Dragon Warrior is not installed yet.", result.stdout)
        self.assertIn("Install Dragon Warrior.cmd", result.stdout)

    def test_unknown_installed_rom_is_rejected_before_launch(self):
        self.rom_path.write_bytes(b"changed revision")

        result = self.run_player("-ValidateOnly")

        self.assertEqual(result.returncode, 3, result.stderr + result.stdout)
        self.assertIn("The installed ROM is not the supported revision.", result.stdout)
        self.assertIn("No emulator was started.", result.stdout)

    def test_exact_previously_accepted_unsupported_rom_can_launch(self):
        unsupported_bytes = b"accepted hacked revision"
        self.rom_path.write_bytes(unsupported_bytes)
        acknowledgement = {
            "schemaVersion": 1,
            "acknowledged": True,
            "size": len(unsupported_bytes),
            "sha256": hashlib.sha256(unsupported_bytes).hexdigest().upper(),
            "sourceFile": "hacked.nes",
        }
        (self.root / "user" / "unsupported-rom-acknowledgement.json").write_text(
            json.dumps(acknowledgement),
            encoding="utf-8",
        )

        result = self.run_player("-ValidateOnly")

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("WARNING: Running an unsupported ROM", result.stdout)
        self.assertIn("Unsupported ROM override active for this exact file.", result.stdout)
        self.assertIn("Validation only: no emulator was started.", result.stdout)

    def test_changed_unsupported_rom_invalidates_prior_acknowledgement(self):
        acknowledgement = {
            "schemaVersion": 1,
            "acknowledged": True,
            "size": len(self.rom_bytes),
            "sha256": hashlib.sha256(self.rom_bytes).hexdigest().upper(),
        }
        (self.root / "user" / "unsupported-rom-acknowledgement.json").write_text(
            json.dumps(acknowledgement),
            encoding="utf-8",
        )
        self.rom_path.write_bytes(b"different hacked revision")

        result = self.run_player("-ValidateOnly")

        self.assertEqual(result.returncode, 3, result.stderr + result.stdout)
        self.assertIn("The installed ROM is not the supported revision.", result.stdout)
        self.assertIn("No emulator was started.", result.stdout)

    def test_cmd_entry_point_is_keyboard_friendly(self):
        text = CMD_ENTRY_POINT.read_text(encoding="utf-8")
        self.assertIn("-NoProfile -ExecutionPolicy Bypass", text)
        self.assertIn("app\\play_player.ps1", text)
        self.assertIn("user\\launch.log", text)
        self.assertIn("pause", text.lower())

    def test_developer_launcher_exposes_isolated_process_scope(self):
        text = (REPO_ROOT / "launch_dw.ps1").read_text(encoding="utf-8")
        self.assertIn("[switch] $IsolatedProcessScope", text)
        self.assertIn("Get-TargetEmulatorProcesses", text)

    def test_developer_launcher_prefers_repo_verified_fceux_runtime(self):
        developer_root = self.temp_root / "developer checkout"
        patched_runtime = (
            developer_root
            / ".tools"
            / "fceux-release-runtime-verified"
            / "qfceux.exe"
        )
        patched_runtime.parent.mkdir(parents=True)
        patched_runtime.write_bytes(b"patched qfceux fixture\n")
        (patched_runtime.parent / "FCEUX-ACCESSIBILITY-BUILD.txt").write_text(
            "FCEUX 2.6.6 Dragon Warrior Accessibility runtime\n",
            encoding="utf-8",
        )

        launcher = developer_root / "launch_dw.ps1"
        shutil.copy2(REPO_ROOT / "launch_dw.ps1", launcher)
        for filename in ("launch_dw.cmd", "keyboard_bridge.ps1"):
            (developer_root / filename).write_text("test fixture\n", encoding="utf-8")
        lua_path = developer_root / "main.lua"
        lua_path.write_text("-- test fixture\n", encoding="utf-8")
        rom_path = developer_root / "Dragon Warrior.nes"
        rom_path.write_bytes(b"test fixture rom\n")

        env = os.environ.copy()
        for name in ("DW_FCEUX_PATH", "FCEUX_CONFIG_DIR", "FCEUX_HOME"):
            env.pop(name, None)
        result = subprocess.run(
            [
                POWERSHELL,
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(launcher),
                "-RomPath",
                str(rom_path),
                "-LuaPath",
                str(lua_path),
                "-DryRun",
            ],
            text=True,
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            timeout=15,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn(f"Emulator: {patched_runtime}", result.stdout)

    def test_wsl_launcher_checks_for_repo_verified_fceux_runtime(self):
        text = (REPO_ROOT / "launch_dw.sh").read_text(encoding="utf-8")
        self.assertIn(
            'verified_fceux_path="$script_dir/.tools/fceux-release-runtime-verified/qfceux.exe"',
            text,
        )
        self.assertIn(
            'verified_fceux_marker="$script_dir/.tools/fceux-release-runtime-verified/FCEUX-ACCESSIBILITY-BUILD.txt"',
            text,
        )

    def test_player_launcher_uses_speech_readiness_instead_of_debug_log(self):
        player_text = PLAYER.read_text(encoding="utf-8")
        developer_text = (REPO_ROOT / "launch_dw.ps1").read_text(encoding="utf-8")
        self.assertIn("-PlayerReadiness", player_text)
        self.assertIn("[switch] $PlayerReadiness", developer_text)
        self.assertIn("Wait-ForPlayerSpeechReady", developer_text)
        self.assertIn('status -eq "READY"', developer_text)

    def test_player_launcher_uses_private_config_autoload_without_duplicate_cli_lua(self):
        player_text = PLAYER.read_text(encoding="utf-8")
        developer_text = (REPO_ROOT / "launch_dw.ps1").read_text(encoding="utf-8")
        shim_text = (REPO_ROOT / "launch_dw.cmd").read_text(encoding="utf-8")
        self.assertIn('$env:DW_LAUNCH_CONFIG_LUA_ONLY = "1"', player_text)
        self.assertIn(":config_lua_only_without_slot", shim_text)
        config_branch = shim_text.split(":config_lua_only", 1)[1].split(":split_loadlua", 1)[0]
        self.assertIn('"%FCEUX_EXE%" "%ROM_PATH%"', config_branch)
        self.assertNotIn("--loadlua", config_branch)
        self.assertIn(
            'Invoke-StartupInputRecovery -Process $process -Phase "post-start"',
            developer_text,
        )

    def test_qt_launcher_omits_unsupported_windows_bginput_option(self):
        for relative_path in ("launch_dw.cmd", "launch_dw.ps1", "launch_dw.sh"):
            text = (REPO_ROOT / relative_path).read_text(encoding="utf-8")
            self.assertNotIn("bginput", text.lower(), relative_path)

    def test_keyboard_bridge_start_quotes_package_paths_with_spaces(self):
        developer_text = (REPO_ROOT / "launch_dw.ps1").read_text(encoding="utf-8")
        self.assertIn('"-File", (Quote-Argument $keyboardBridgeScript)', developer_text)
        self.assertIn('"-OutputPath", (Quote-Argument $keyboardBridgeFile)', developer_text)

    def test_keyboard_state_writer_recovers_after_temporary_read_lock(self):
        # Load just the writer: do not poll real keys or start an emulator.
        probe = self.temp_root / "writer-probe.ps1"
        probe.write_text(r'''
param([string] $BridgeScript, [string] $StateFile)
$ErrorActionPreference = "Stop"
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $BridgeScript, [ref] $tokens, [ref] $parseErrors)
if ($parseErrors.Count -gt 0) { throw "Could not parse keyboard bridge" }
$writer = $ast.Find({param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq "Write-State"
}, $true)
. ([scriptblock]::Create($writer.Extent.Text))
$OutputPath = $StateFile
[IO.File]::WriteAllText($OutputPath, "old")
$reader = [IO.File]::Open($OutputPath, [IO.FileMode]::Open,
    [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    if (Write-State -Line "blocked") { throw "Locked publication should be deferred" }
} finally { $reader.Dispose() }
if (-not (Write-State -Line "fresh")) { throw "Publication should recover after unlock" }
if ([IO.File]::ReadAllText($OutputPath).Trim() -ne "fresh") { throw "State did not recover" }
$OutputPath = Join-Path (Join-Path (Split-Path -Parent $StateFile) "missing") "state.txt"
$propagated = $false
try { [void] (Write-State -Line "bad path") } catch { $propagated = $true }
if (-not $propagated) { throw "Unrelated file errors must propagate" }
Write-Output "keyboard-writer-recovery=OK"
''', encoding="utf-8")
        result = subprocess.run(
            [POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(probe),
             "-BridgeScript", str(REPO_ROOT / "keyboard_bridge.ps1"),
             "-StateFile", str(self.temp_root / "keyboard.txt")],
            text=True, errors="replace", capture_output=True, timeout=15, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("keyboard-writer-recovery=OK", result.stdout)

    def test_config_lua_autoload_is_refreshed_after_old_emulator_shutdown(self):
        developer_text = (REPO_ROOT / "launch_dw.ps1").read_text(encoding="utf-8")
        refresh_message = "Refreshed FCEUX config Lua autoload after emulator shutdown"
        self.assertIn('$configLuaAutoloadOnly', developer_text)
        self.assertIn('Set-ConfigValue -ConfigPath $configPath -Key "SDL.LuaScript"', developer_text)
        self.assertIn('Set-ConfigValue -ConfigPath $configPath -Key "SDL.LastLoadLua"', developer_text)
        self.assertIn(refresh_message, developer_text)
        self.assertLess(
            developer_text.index(refresh_message),
            developer_text.index(
                "Disable-FceuxNativeKeyboardGamepad -ConfigPath $configPath",
                developer_text.index(refresh_message),
            ),
        )

    def test_config_lua_refresh_preserves_rooted_short_path_alias(self):
        developer_text = (REPO_ROOT / "launch_dw.ps1").read_text(encoding="utf-8")
        self.assertIn("Convert-ToFceuxConfigPath", developer_text)
        self.assertIn(
            "Convert-ToFceuxConfigPath -PathValue $LuaPath",
            developer_text,
        )


if __name__ == "__main__":
    unittest.main()
