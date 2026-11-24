import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent
README = REPO_ROOT / "README.md"


class ReleaseReadmeTests(unittest.TestCase):
    def setUp(self):
        self.text = README.read_text(encoding="utf-8")
        # Match safety information across prose edits and line wrapping.
        self.prose = " ".join(
            self.text.replace(chr(96), "").replace("*", "").split()
        ).lower()

    def test_documents_supported_rom_and_unsupported_opt_in(self):
        self.assertIn("81,936 bytes", self.prose)
        self.assertIn(
            "676B89D76CF9E83EED76C0A67F81DA906916F0BCE321CF3A9A39AC78BC9C0845",
            self.text,
        )
        self.assertRegex(self.prose, r"typ(?:e|ing) i accept")
        self.assertRegex(
            self.prose,
            r"installer never modifies (?:your original rom file|the selected source rom)",
        )

    def test_names_release_supported_speech_backends(self):
        for backend in ("nvda", "jaws", "windows sapi5 voice"):
            self.assertIn(backend, self.prose)
        self.assertNotIn("Narrator", self.text)

    def test_points_to_separate_keyboard_reference(self):
        self.assertIn("keyboard commands.txt", self.prose)
        self.assertRegex(self.prose, r"quick screen-reader(?:-friendly)? (?:lookup|shortcut reference)")

    def test_warns_about_teleport_state_and_save_risk(self):
        self.assertRegex(self.prose, r"teleport changes (?:the )?live game state")
        self.assertIn("unusable save data", self.prose)
        self.assertRegex(self.prose, r"teleport(?:ing)? does not modify (?:your|the) original rom file")
        self.assertRegex(self.prose, r"(?:start is pressed once|pressing start once)")
        self.assertRegex(self.prose, r"reloading the accessibility script may (?:help|restore control)")
        self.assertIn("close the emulator without saving", self.prose)
        self.assertIn("run play dragon warrior.cmd again", self.prose)

    def test_does_not_claim_joytokey_is_in_player_zip(self):
        self.assertRegex(
            self.prose,
            r"(?:joytokey isn't bundled with the player release zip|it is not bundled in the lean player release zip)",
        )
        self.assertNotIn("included joytokey profile", self.prose)
        self.assertNotIn("included profile", self.prose)

    def test_qualifies_stock_fceux_startup_limit(self):
        self.assertRegex(self.prose, r"(?:stock fceux build|ordinary fceux build)")
        self.assertRegex(self.prose, r"automatic player package includes (?:the project's patched|the patched and tested runtime)")


if __name__ == "__main__":
    unittest.main()
