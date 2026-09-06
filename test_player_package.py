import hashlib
import json
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent
BUILDER = REPO_ROOT / "release" / "build_player_package.ps1"
LAYOUT_PATH = REPO_ROOT / "release" / "package-layout.json"
POWERSHELL = shutil.which("powershell.exe") or shutil.which("powershell")


@unittest.skipUnless(POWERSHELL, "Windows PowerShell is required")
class PlayerPackageTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.fceux = self.root / "fceux"
        self.python = self.root / "python"
        self.docs = self.root / "docs"
        self.docs.mkdir(parents=True)

        layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
        for relative_path in layout["fceuxRootFiles"]:
            path = self.fceux / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(("fixture " + relative_path).encode("utf-8"))
        for relative_directory in layout["fceuxDirectories"]:
            path = self.fceux / relative_directory / "fixture-plugin.dll"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(("fixture " + relative_directory).encode("utf-8"))
        (self.fceux / "FCEUX-ACCESSIBILITY-BUILD.txt").write_text(
            "FCEUX 2.6.6 Dragon Warrior Accessibility runtime\n"
            "Upstream commit: 34eb7601c415b81901fd02afbd5cfdc84b5047ac\n"
            "Patch: release/fceux-v2.6.6-deferred-startup-lua.patch\n",
            encoding="utf-8",
        )

        (self.python / "Lib" / "site-packages" / "win32").mkdir(parents=True)
        accessible_output_lib = (
            self.python / "Lib" / "site-packages" / "accessible_output2" / "lib"
        )
        accessible_output_lib.mkdir(parents=True)
        (accessible_output_lib / "nvdaControllerClient64.dll").write_bytes(
            b"fixture official nvda controller client"
        )
        (accessible_output_lib / "NVDA Controller Client LICENSE.txt").write_text(
            "GNU LESSER GENERAL PUBLIC LICENSE Version 2.1\n",
            encoding="utf-8",
        )
        (self.python / "python.exe").write_bytes(b"fixture embedded python")
        (self.python / "LICENSE.txt").write_text("Python fixture license\n", encoding="utf-8")
        (self.python / "SPEECH-DEPENDENCIES.txt").write_text(
            "accessible-output2==0.17\n"
            "NVDA-Controller-Client==2026.1.1\n"
            "NVDA corresponding source commit: "
            "5d92106f17e461dac62aa48257bbbf4183e033d0\n",
            encoding="utf-8",
        )
        (self.python / "Lib" / "site-packages" / "win32" / "license.txt").write_text(
            "pywin32 fixture license\n",
            encoding="utf-8",
        )
        for relative_path in (
            "Lib/site-packages/isapi/samples/test.py",
            "Lib/site-packages/win32/Demos/example.py",
            "Lib/site-packages/win32com/test/test_runtime.py",
            "Lib/site-packages/win32comext/ifilter/demo/sample.py",
        ):
            path = self.python / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("non-runtime fixture\n", encoding="utf-8")
        for distribution in (
            "accessible_output2-0.17.dist-info",
            "libloader-1.4.3.dist-info",
            "platform_utils-1.6.2.dist-info",
            "platformdirs-4.9.4.dist-info",
        ):
            license_path = (
                self.python
                / "Lib"
                / "site-packages"
                / distribution
                / "licenses"
                / "LICENSE.txt"
            )
            license_path.parent.mkdir(parents=True)
            license_path.write_text(distribution + " fixture license\n", encoding="utf-8")

        self.readme = self.docs / "README.txt"
        self.keyboard = self.docs / "Keyboard Commands.txt"
        self.project_license = self.docs / "PROJECT-LICENSE.txt"
        self.fceux_license = self.docs / "FCEUX-COPYING.txt"
        self.fceux_source = self.docs / "FCEUX-SOURCE.txt"
        self.readme.write_text("Fixture player installation guide.\n", encoding="utf-8")
        self.keyboard.write_text("Fixture keyboard commands.\n", encoding="utf-8")
        self.project_license.write_text(
            "MIT License\nCopyright (c) 2026 Bill Freeman\nPermission is hereby granted.\n",
            encoding="utf-8",
        )
        self.fceux_license.write_text(
            "GNU GENERAL PUBLIC LICENSE\nVersion 2, June 1991\n",
            encoding="utf-8",
        )
        self.fceux_source.write_text(
            "Complete corresponding source is supplied as the sibling release asset "
            "Dragon-Warrior-Accessibility-test-1.0-Corresponding-Source.zip.\n",
            encoding="utf-8",
        )

    def tearDown(self):
        self.tmp.cleanup()

    def run_builder(self, output_name, *, project_license=None):
        output_directory = self.root / output_name
        output_zip = self.root / (output_name + ".zip")
        result = subprocess.run(
            [
                POWERSHELL,
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(BUILDER),
                "-ReleaseVersion",
                "test-1.0",
                "-OutputDirectory",
                str(output_directory),
                "-OutputZip",
                str(output_zip),
                "-FceuxDirectory",
                str(self.fceux),
                "-PythonDirectory",
                str(self.python),
                "-ReadmePath",
                str(self.readme),
                "-KeyboardCommandsPath",
                str(self.keyboard),
                "-ProjectLicensePath",
                str(project_license or self.project_license),
                "-FceuxLicensePath",
                str(self.fceux_license),
                "-FceuxSourceNoticePath",
                str(self.fceux_source),
                "-SkipRuntimeExecution",
            ],
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        return result, output_directory, output_zip

    def test_layout_is_explicit_and_excludes_project_tests(self):
        layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
        self.assertEqual(layout["schemaVersion"], 1)
        self.assertIn("main.lua", layout["appFiles"])
        self.assertIn("settings_menu.lua", layout["appFiles"])
        self.assertIn("speech_bridge.py", layout["appFiles"])
        self.assertIn("qfceux.exe", layout["fceuxRootFiles"])
        self.assertIn("FCEUX-ACCESSIBILITY-BUILD.txt", layout["fceuxRootFiles"])
        self.assertFalse(any(Path(path).name.startswith("av") for path in layout["fceuxRootFiles"]))
        self.assertFalse(any(Path(path).name.startswith("sw") for path in layout["fceuxRootFiles"]))
        self.assertNotIn("postproc-56.dll", layout["fceuxRootFiles"])
        self.assertFalse(any(Path(path).name.startswith("test_") for path in layout["appFiles"]))

    def test_fixture_build_is_clean_manifested_and_reproducible(self):
        first, first_directory, first_zip = self.run_builder("build-one")
        second, second_directory, second_zip = self.run_builder("build-two")

        self.assertEqual(first.returncode, 0, first.stderr + first.stdout)
        self.assertEqual(second.returncode, 0, second.stderr + second.stdout)
        self.assertIn("Deterministic player package build complete.", first.stdout)
        self.assertEqual(first_zip.read_bytes(), second_zip.read_bytes())

        manifest_path = first_directory / "PACKAGE-MANIFEST.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertTrue(manifest["manifestSelfExcluded"])
        manifest_paths = [entry["path"] for entry in manifest["files"]]
        self.assertEqual(manifest_paths, sorted(manifest_paths, key=str.casefold))

        payload_paths = sorted(
            (
                path.relative_to(first_directory).as_posix()
                for path in first_directory.rglob("*")
                if path.is_file() and path.name != "PACKAGE-MANIFEST.json"
            ),
            key=str.casefold,
        )
        self.assertEqual(manifest_paths, payload_paths)
        for entry in manifest["files"]:
            path = first_directory / Path(entry["path"])
            self.assertEqual(entry["size"], path.stat().st_size)
            self.assertEqual(
                entry["sha256"],
                hashlib.sha256(path.read_bytes()).hexdigest().upper(),
            )

        config_text = (first_directory / "app" / "dw_access.ini").read_text(encoding="utf-8")
        self.assertIn("speech_python_cmd=..\\runtime\\python\\python.exe", config_text)
        self.assertIn("debug_mode=false", config_text)
        self.assertIn("debug_log_level=ERROR", config_text)
        self.assertIn("enable_bizhawk_diagnostic_hotkeys=false", config_text)

        lower_paths = [path.lower() for path in payload_paths]
        self.assertFalse(any(path.endswith((".nes", ".sav", ".fcs", ".saveram")) for path in lower_paths))
        self.assertFalse(any("/__pycache__/" in "/" + path + "/" for path in lower_paths))
        non_runtime_segments = {"test", "tests", "demo", "demos", "sample", "samples"}
        self.assertFalse(
            any(non_runtime_segments.intersection(Path(path).parts) for path in lower_paths)
        )
        self.assertFalse(any(Path(path).name.startswith("test_") for path in payload_paths))
        self.assertIn("licenses/FCEUX COPYING.txt", payload_paths)
        self.assertIn("licenses/FCEUX SOURCE.txt", payload_paths)
        self.assertIn("licenses/Dragon Warrior Accessibility LICENSE.txt", payload_paths)
        self.assertIn("licenses/Qt LGPL v3.txt", payload_paths)
        self.assertIn("licenses/NVDA Controller Client LGPL 2.1.txt", payload_paths)
        self.assertIn("licenses/SDL2 LICENSE.txt", payload_paths)
        self.assertIn("licenses/libarchive COPYING.txt", payload_paths)
        self.assertIn("licenses/Lua 5.1 LICENSE.txt", payload_paths)

        with zipfile.ZipFile(first_zip) as archive:
            names = archive.namelist()
            self.assertTrue(all(name.startswith("Dragon Warrior Accessibility test-1.0/") for name in names))
            self.assertTrue(all(info.date_time == (1980, 1, 1, 0, 0, 0) for info in archive.infolist()))

        self.assertEqual(
            hashlib.sha256(first_zip.read_bytes()).hexdigest(),
            hashlib.sha256(second_zip.read_bytes()).hexdigest(),
        )

    def test_missing_required_license_fails_without_output(self):
        missing_license = self.docs / "missing-license.txt"
        result, output_directory, output_zip = self.run_builder(
            "missing-license-build",
            project_license=missing_license,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Project license not found", result.stderr + result.stdout)
        self.assertFalse(output_directory.exists())
        self.assertFalse(output_zip.exists())

    def test_placeholder_license_is_rejected(self):
        placeholder = self.docs / "placeholder-license.txt"
        placeholder.write_text("INTERNAL PACKAGE TEST ONLY - NOT A LICENSE.\n", encoding="utf-8")
        result, output_directory, output_zip = self.run_builder(
            "placeholder-license-build",
            project_license=placeholder,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Project license contains placeholder text", result.stderr + result.stdout)
        self.assertFalse(output_directory.exists())
        self.assertFalse(output_zip.exists())

    def test_unmarked_stock_fceux_runtime_is_rejected(self):
        (self.fceux / "FCEUX-ACCESSIBILITY-BUILD.txt").unlink()
        result, output_directory, output_zip = self.run_builder("stock-fceux-build")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Patched FCEUX build marker not found", result.stderr + result.stdout)
        self.assertFalse(output_directory.exists())
        self.assertFalse(output_zip.exists())


if __name__ == "__main__":
    unittest.main()
