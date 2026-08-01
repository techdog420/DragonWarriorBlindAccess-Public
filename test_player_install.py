import hashlib
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent
INSTALLER = REPO_ROOT / "release" / "install_player.ps1"
ROM_MANIFEST = REPO_ROOT / "release" / "roms.json"
CMD_ENTRY_POINT = REPO_ROOT / "release" / "Install Dragon Warrior.cmd"
POWERSHELL = shutil.which("powershell.exe") or shutil.which("powershell")
CMD = shutil.which("cmd.exe")


@unittest.skipUnless(POWERSHELL, "Windows PowerShell is required")
class PlayerInstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        for relative_path in (
            "app/main.lua",
            "app/launch_dw.ps1",
            "app/keyboard_bridge.ps1",
            "app/speech_bridge.py",
            "runtime/fceux/qfceux.exe",
            "runtime/python/python.exe",
        ):
            path = self.root / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"test runtime file\n")

    def tearDown(self):
        self.tmp.cleanup()

    def make_test_rom_and_manifest(self, name="source.nes"):
        rom_bytes = b"unit-test-rom-data\x00\x01\x02"
        rom_path = self.root / name
        rom_path.write_bytes(rom_bytes)
        manifest_path = self.root / "test-roms.json"
        manifest_path.write_text(
            json.dumps(
                {
                    "roms": [
                        {
                            "name": "Unit Test Revision",
                            "size": len(rom_bytes),
                            "sha256": hashlib.sha256(rom_bytes).hexdigest().upper(),
                        }
                    ]
                }
            ),
            encoding="utf-8",
        )
        return rom_path, manifest_path, rom_bytes

    def run_installer(self, *args):
        return subprocess.run(
            [
                POWERSHELL,
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(INSTALLER),
                "-PackageRoot",
                str(self.root),
                "-NonInteractive",
                *map(str, args),
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def read_fceux_config(self):
        config_path = self.root / "user" / "fceux" / "fceux.cfg"
        return config_path.read_text(encoding="utf-8")

    def test_release_manifest_pins_supported_rev1_rom(self):
        payload = json.loads(ROM_MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(
            payload,
            {
                "roms": [
                    {
                        "name": "Dragon Warrior (USA) (Rev 1)",
                        "size": 81936,
                        "sha256": "676B89D76CF9E83EED76C0A67F81DA906916F0BCE321CF3A9A39AC78BC9C0845",
                    }
                ]
            },
        )

    def test_cmd_entry_point_is_keyboard_friendly_and_forwards_rom_path(self):
        text = CMD_ENTRY_POINT.read_text(encoding="utf-8")
        self.assertIn("-NoProfile -ExecutionPolicy Bypass", text)
        self.assertIn('-PackageRoot "%~dp0."', text)
        self.assertIn('-RomPath "%~1"', text)
        self.assertIn("user\\install.log", text)
        self.assertIn("pause", text.lower())

    def test_cmd_entry_point_passes_valid_package_root_from_explorer_style_path(self):
        if not CMD:
            self.skipTest("cmd.exe is required")

        package_root = self.root / "Explorer package"
        app_directory = package_root / "app"
        app_directory.mkdir(parents=True)
        entry_point = package_root / CMD_ENTRY_POINT.name
        shutil.copy2(CMD_ENTRY_POINT, entry_point)
        (app_directory / "install_player.ps1").write_text(
            """param([string] $PackageRoot, [string] $RomPath)
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
        rom_path = package_root / "source rom.nes"
        rom_path.write_bytes(b"test")

        result = subprocess.run(
            [CMD, "/d", "/c", "call", str(entry_point), str(rom_path)],
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

    def test_supported_rom_is_copied_without_modifying_source(self):
        rom_path, manifest_path, rom_bytes = self.make_test_rom_and_manifest()

        result = self.run_installer(
            "-RomPath",
            rom_path,
            "-RomManifestPath",
            manifest_path,
        )

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("Supported ROM: Unit Test Revision", result.stdout)
        self.assertIn("ROM installation complete.", result.stdout)
        self.assertEqual(rom_path.read_bytes(), rom_bytes)
        self.assertEqual((self.root / "user" / "Dragon Warrior.nes").read_bytes(), rom_bytes)
        self.assertIn("ROM installation complete.", (self.root / "user" / "install.log").read_text(encoding="utf-8"))
        config_text = self.read_fceux_config()
        self.assertIn("SDL.AutoResume = 0", config_text)
        self.assertIn("SDL.ToggleMenu = 1", config_text)
        self.assertIn("SDL.PauseOnMainMenuAccess = 1", config_text)
        self.assertIn("SDL.Input.GamePad.0.DeviceType = None", config_text)
        self.assertIn(
            "SDL.Input.GamePad.0.Profile = dragonwarrior-bridge-only",
            config_text,
        )
        normalized_lua_path = str(self.root / "app" / "main.lua").replace("\\", "/")
        self.assertIn(f"SDL.LastLoadLua = {normalized_lua_path}", config_text)
        self.assertIn(f"SDL.LuaScript = {normalized_lua_path}", config_text)
        self.assertTrue((self.root / "user" / "fceux" / "sav").is_dir())
        profile = (
            self.root
            / "user"
            / "fceux"
            / "input"
            / "keyboard"
            / "dragonwarrior-bridge-only.txt"
        ).read_text(encoding="utf-8")
        self.assertEqual(
            profile,
            "keyboard,dragonwarrior-bridge-only,config:0,a:,b:,back:,start:,dpup:,dpdown:,dpleft:,dpright:,turboA:,turboB:,",
        )

    def test_private_fceux_config_preserves_unrelated_settings_and_repairs_safety_keys(self):
        rom_path, manifest_path, _ = self.make_test_rom_and_manifest()
        config_path = self.root / "user" / "fceux" / "fceux.cfg"
        config_path.parent.mkdir(parents=True)
        config_path.write_text(
            "SDL.Sound.Volume = 128\n"
            "SDL.ToggleMenu = 0\n"
            "SDL.PauseOnMainMenuAccess = 0\n"
            "SDL.Hotkeys.MainMenuHide = Alt+M\n"
            "SDL.Input.GamePad.0.DeviceType = Keyboard\n",
            encoding="utf-8",
        )

        result = self.run_installer(
            "-RomPath",
            rom_path,
            "-RomManifestPath",
            manifest_path,
        )

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        config_text = self.read_fceux_config()
        self.assertIn("SDL.Sound.Volume = 128", config_text)
        expected = {
            "SDL.AutoResume": "0",
            "SDL.ToggleMenu": "1",
            "SDL.PauseOnMainMenuAccess": "1",
            "SDL.Hotkeys.MainMenuHide": "",
            "SDL.Hotkeys.FullScreen": "",
            "SDL.Input.0": "GamePad.0",
            "SDL.Input.GamePad.0.DeviceGUID": "",
            "SDL.Input.GamePad.0.DeviceType": "None",
            "SDL.Input.GamePad.0.Profile": "dragonwarrior-bridge-only",
            "SDL.LastLoadLua": str(self.root / "app" / "main.lua").replace("\\", "/"),
            "SDL.LuaScript": str(self.root / "app" / "main.lua").replace("\\", "/"),
        }
        for key, value in expected.items():
            matching_lines = [
                line
                for line in config_text.splitlines()
                if line.split("=", 1)[0].strip() == key
            ]
            self.assertEqual(matching_lines, [f"{key} = {value}"], key)

    def test_unknown_rom_is_rejected_with_actual_fingerprint(self):
        rom_path = self.root / "wrong-revision.nes"
        rom_path.write_bytes(b"wrong revision")

        result = self.run_installer("-RomPath", rom_path)

        self.assertEqual(result.returncode, 3, result.stderr + result.stdout)
        self.assertIn("Unsupported Dragon Warrior ROM revision.", result.stdout)
        self.assertIn("Actual size: 14 bytes", result.stdout)
        self.assertIn(hashlib.sha256(b"wrong revision").hexdigest().upper(), result.stdout)
        self.assertIn("Expected: Dragon Warrior (USA) (Rev 1), 81936 bytes", result.stdout)
        self.assertIn("type I ACCEPT, or use -AllowUnsupportedRom", result.stdout)
        self.assertFalse((self.root / "user" / "Dragon Warrior.nes").exists())

    def test_power_user_can_accept_an_unsupported_rom_by_exact_fingerprint(self):
        rom_bytes = b"hacked revision"
        rom_path = self.root / "hacked.nes"
        rom_path.write_bytes(rom_bytes)

        result = self.run_installer(
            "-RomPath",
            rom_path,
            "-AllowUnsupportedRom",
        )

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("WARNING: This mod was built and tested only", result.stdout)
        self.assertIn("Unsupported ROM override recorded", result.stdout)
        self.assertEqual((self.root / "user" / "Dragon Warrior.nes").read_bytes(), rom_bytes)
        acknowledgement = json.loads(
            (self.root / "user" / "unsupported-rom-acknowledgement.json").read_text(encoding="utf-8")
        )
        self.assertTrue(acknowledgement["acknowledged"])
        self.assertEqual(acknowledgement["size"], len(rom_bytes))
        self.assertEqual(
            acknowledgement["sha256"],
            hashlib.sha256(rom_bytes).hexdigest().upper(),
        )
        self.assertEqual(acknowledgement["sourceFile"], "Dragon Warrior.nes")

    def test_previously_accepted_unsupported_rom_makes_repeat_setup_a_noop(self):
        rom_path = self.root / "hacked.nes"
        rom_path.write_bytes(b"hacked revision")
        first = self.run_installer("-RomPath", rom_path, "-AllowUnsupportedRom")
        self.assertEqual(first.returncode, 0, first.stderr + first.stdout)

        second = self.run_installer()

        self.assertEqual(second.returncode, 0, second.stderr + second.stdout)
        self.assertIn("previously accepted unsupported ROM is already installed", second.stdout)

    def test_valid_installed_rom_makes_repeat_setup_a_noop(self):
        rom_path, manifest_path, rom_bytes = self.make_test_rom_and_manifest()
        installed_path = self.root / "user" / "Dragon Warrior.nes"
        installed_path.parent.mkdir(parents=True)
        installed_path.write_bytes(rom_bytes)

        result = self.run_installer("-RomManifestPath", manifest_path)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("The supported ROM is already installed.", result.stdout)
        self.assertEqual(installed_path.read_bytes(), rom_bytes)

    def test_supported_rom_beside_installer_is_detected_automatically(self):
        rom_path, manifest_path, rom_bytes = self.make_test_rom_and_manifest("game.nes")

        result = self.run_installer("-RomManifestPath", manifest_path)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("Found a supported ROM beside the installer", result.stdout)
        self.assertEqual((self.root / "user" / "Dragon Warrior.nes").read_bytes(), rom_bytes)

    def test_missing_runtime_file_stops_before_rom_copy(self):
        rom_path, manifest_path, _ = self.make_test_rom_and_manifest()
        (self.root / "runtime" / "python" / "python.exe").unlink()

        result = self.run_installer(
            "-RomPath",
            rom_path,
            "-RomManifestPath",
            manifest_path,
        )

        self.assertEqual(result.returncode, 4, result.stderr + result.stdout)
        self.assertIn("The release package is incomplete.", result.stdout)
        self.assertIn("runtime\\python\\python.exe", result.stdout)
        self.assertFalse((self.root / "user" / "Dragon Warrior.nes").exists())


if __name__ == "__main__":
    unittest.main()
