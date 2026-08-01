import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent
REQUIREMENTS = REPO_ROOT / "release" / "speech-requirements.txt"
BUILD_SCRIPT = REPO_ROOT / "release" / "build_speech_runtime.ps1"


class SpeechRuntimePackageTests(unittest.TestCase):
    def test_runtime_dependencies_are_pinned_to_working_versions(self):
        self.assertEqual(
            REQUIREMENTS.read_text(encoding="utf-8").splitlines(),
            [
                "accessible-output2==0.17",
                "libloader==1.4.3",
                "platform-utils==1.6.2",
                "platformdirs==4.9.4",
                "pywin32==311",
            ],
        )

    def test_builder_uses_verified_official_embedded_python(self):
        text = BUILD_SCRIPT.read_text(encoding="utf-8")
        self.assertIn(
            "https://www.python.org/ftp/python/3.14.6/python-3.14.6-embed-amd64.zip",
            text,
        )
        self.assertIn(
            "DF901E84A896FF1EE720AD03377E0C8D8C2244FDA79808AEEAFF6316DF1CB75C",
            text,
        )
        self.assertIn("--no-index", text)
        self.assertIn("--only-binary=:all:", text)
        self.assertNotIn("Copy-Item -LiteralPath '.venv", text)

    def test_builder_replaces_wheel_vendor_dlls_with_official_nvda_client(self):
        text = BUILD_SCRIPT.read_text(encoding="utf-8")
        self.assertIn(
            "https://download.nvaccess.org/releases/2026.1.1/"
            "nvda_2026.1.1_controllerClient.zip",
            text,
        )
        self.assertIn(
            "2A3A70F729BE0C48120C5F24A81653202827C40A7986E289FFE2275A2B45011F",
            text,
        )
        self.assertIn(
            "5d92106f17e461dac62aa48257bbbf4183e033d0",
            text,
        )
        for unused_dll in (
            "dolapi.dll",
            "nvdaControllerClient32.dll",
            "PCTKUSR.dll",
            "PCTKUSR64.dll",
            "SAAPI32.dll",
            "ZDSRAPI.dll",
            "ZDSRAPI_x64.dll",
        ):
            self.assertIn(unused_dll, text)
        self.assertNotIn("from accessible_output2.outputs.auto import Auto", text)


if __name__ == "__main__":
    unittest.main()
