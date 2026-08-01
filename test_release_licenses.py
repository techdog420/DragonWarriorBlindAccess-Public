import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent
LICENSE = REPO_ROOT / "LICENSE"
LICENSE_DIR = REPO_ROOT / "licenses"
THIRD_PARTY_DIR = LICENSE_DIR / "third-party"
SOURCE_BUILDER = REPO_ROOT / "release" / "build_corresponding_source.ps1"
LAYOUT = REPO_ROOT / "release" / "package-layout.json"


class ReleaseLicenseTests(unittest.TestCase):
    def test_project_license_names_copyright_holder(self):
        text = LICENSE.read_text(encoding="utf-8")
        self.assertIn("MIT License", text)
        self.assertIn("Copyright (c) 2026 Bill Freeman", text)

    def test_release_notices_cover_every_bundled_component(self):
        notice = (LICENSE_DIR / "THIRD-PARTY-NOTICES.txt").read_text(encoding="utf-8")
        for component in (
            "FCEUX 2.6.6",
            "Qt 5.15.2",
            "Mesa llvmpipe software OpenGL renderer",
            "SDL2 2.24.1",
            "libarchive 3.6.2",
            "Lua 5.1",
            "NVDA Controller Client 2026.1.1",
            "Python 3.14.6",
            "Microsoft Direct3D shader compiler redistributable",
        ):
            self.assertIn(component, notice)
        self.assertIn("{{RELEASE_VERSION}}", notice)

    def test_vendored_license_materials_are_real(self):
        expected = (
            "FCEUX COPYING.txt",
            "Qt LGPL v3.txt",
            "Qt GPL v3.txt",
            "Qt 5.15.2 Third-Party License Materials.zip",
            "Mesa llvmpipe LICENSE.txt",
            "SDL2 LICENSE.txt",
            "libarchive COPYING.txt",
            "Lua 5.1 LICENSE.txt",
            "NVDA Controller Client LGPL 2.1.txt",
        )
        for name in expected:
            path = THIRD_PARTY_DIR / name
            self.assertTrue(path.is_file(), name)
            self.assertGreater(path.stat().st_size, 500, name)

    def test_source_builder_pins_all_copyleft_source_inputs(self):
        text = SOURCE_BUILDER.read_text(encoding="utf-8")
        for value in (
            "34eb7601c415b81901fd02afbd5cfdc84b5047ac",
            "5d92106f17e461dac62aa48257bbbf4183e033d0",
            "6BC369D0A9D24F185ABCD718EE0F003B8DA09DDEEF4F90B35088BD46152B7507",
            "0466848C82F09BFB867E018CEFFE5C717B4AE0FA02B5F8531D0008659FD482AA",
            "3C44AC5BB35188E0B2CB9339E8AC78D5D9F74EAA10E14565572E7FD41D8CFB64",
        ):
            self.assertIn(value, text)
        self.assertIn("git -C $FceuxSourceDirectory ls-files", text)

    def test_player_layout_excludes_ffmpeg(self):
        layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
        names = set(layout["fceuxRootFiles"])
        for name in (
            "avcodec-59.dll",
            "avdevice-59.dll",
            "avfilter-8.dll",
            "avformat-59.dll",
            "avutil-57.dll",
            "postproc-56.dll",
            "swresample-4.dll",
            "swscale-6.dll",
        ):
            self.assertNotIn(name, names)


if __name__ == "__main__":
    unittest.main()
