import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent
README = REPO_ROOT / "README.md"


class ReleaseReadmeTests(unittest.TestCase):
    def setUp(self):
        self.text = README.read_text(encoding="utf-8")

    def test_documents_supported_rom_and_unsupported_opt_in(self):
        self.assertIn("81,936 bytes", self.text)
        self.assertIn(
            "676B89D76CF9E83EED76C0A67F81DA906916F0BCE321CF3A9A39AC78BC9C0845",
            self.text,
        )
        self.assertIn("type `I ACCEPT`", self.text)
        self.assertIn("never modifies\nthe selected source ROM", self.text)

    def test_names_release_supported_speech_backends(self):
        self.assertIn("NVDA or JAWS", self.text)
        self.assertIn("Windows SAPI5 voice", self.text)
        self.assertNotIn("Narrator", self.text)

    def test_points_to_separate_keyboard_reference(self):
        self.assertIn("Keyboard Commands.txt", self.text)
        self.assertIn("quick screen-reader lookup", self.text)

    def test_warns_about_teleport_state_and_save_risk(self):
        self.assertIn("Teleport changes live game state", self.text)
        self.assertIn("produce\nunusable save data", self.text)
        self.assertIn("does not modify the original ROM file", self.text)
        self.assertIn("`Start` is pressed once", self.text)
        self.assertIn("does not restore\ncontrol", self.text)
        self.assertIn("reloading the accessibility script may help", self.text)
        self.assertIn("run `Play Dragon Warrior.cmd` again", self.text)

    def test_does_not_claim_joytokey_is_in_player_zip(self):
        self.assertIn("It is not bundled in the lean player\nrelease ZIP", self.text)
        self.assertNotIn("included\n  JoyToKey profile", self.text)
        self.assertNotIn("included profile", self.text)

    def test_qualifies_stock_fceux_startup_limit(self):
        self.assertIn("Manual installations using an ordinary\n  stock FCEUX build", self.text)
        self.assertIn("automatic player package includes the project's patched", self.text)


if __name__ == "__main__":
    unittest.main()
