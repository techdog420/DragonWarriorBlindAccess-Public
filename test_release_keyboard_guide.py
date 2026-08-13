import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent
CONFIG = REPO_ROOT / "dw_access.ini"
GUIDE = REPO_ROOT / "release" / "Keyboard Commands.txt"


class ReleaseKeyboardGuideTests(unittest.TestCase):
    def test_guide_matches_player_facing_default_bindings(self):
        config = CONFIG.read_text(encoding="utf-8")
        guide = GUIDE.read_text(encoding="utf-8")
        expected = {
            "key_position": ("C|F17", "C or F17"),
            "key_hp": ("H|F19", "H or F19"),
            "key_level": ("I", "I:"),
            "key_gold": ("G|F20", "G or F20"),
            "key_experience": ("E", "E:"),
            "key_stats": ("Shift+R", "Shift+R:"),
            "key_screen_text": ("Shift+T", "Shift+T:"),
            "key_object_prev": ("J|F13", "J or F13"),
            "key_object_current": ("K|F14", "K or F14"),
            "key_object_next": ("L|F15", "L or F15"),
            "key_pathfind": ("O|F16", "O or F16"),
            "key_route_guidance": ("R", "R:"),
            "key_auto_walk": ("U|F18", "U or F18"),
            "key_stop_auto_walk": ("Shift+U", "Shift+U:"),
            "key_freeze_npcs": ("Shift+F", "Shift+F:"),
            "key_filter": ("Q", "Q:"),
            "key_filter_prev": ("Shift+J", "Shift+J:"),
            "key_filter_all": ("Shift+K", "Shift+K:"),
            "key_filter_next": ("Shift+L", "Shift+L:"),
            "key_pathability_filter": ("Shift+O", "Shift+O:"),
            "key_mark_visited": ("Shift+V", "Shift+V:"),
            "key_teleport_exact": ("Shift+Enter", "Shift+Enter:"),
            "key_teleport_north": ("Shift+Up", "Shift+Up:"),
            "key_teleport_south": ("Shift+Down", "Shift+Down:"),
            "key_teleport_west": ("Shift+Left", "Shift+Left:"),
            "key_teleport_east": ("Shift+Right", "Shift+Right:"),
            "key_diag_tiles": ("Ctrl+N", "Ctrl+N:"),
        }
        for key, (configured, documented) in expected.items():
            self.assertIn(f"{key}={configured}", config, key)
            self.assertIn(documented, guide, key)

    def test_guide_documents_basic_keyboard_bridge_controls(self):
        guide = GUIDE.read_text(encoding="utf-8")
        for binding in (
            "Arrow keys:",
            "F: NES A button",
            "D: NES B button",
            "Enter: NES Start button",
            "S: NES Select button",
        ):
            self.assertIn(binding, guide)

    def test_guide_omits_developer_dump_bindings(self):
        guide = GUIDE.read_text(encoding="utf-8")
        for binding in ("Ctrl+M", "Ctrl+D", "Ctrl+Y"):
            self.assertNotIn(binding, guide)

    def test_guide_warns_about_teleport_state_and_save_risk(self):
        guide = GUIDE.read_text(encoding="utf-8")
        self.assertIn("WARNING: Teleport changes the live game state", guide)
        self.assertIn("produce unusable save data", guide)
        self.assertIn("does not modify your original ROM file", guide)
        self.assertIn("Press Start once to restore them", guide)
        self.assertIn("If Start does not work", guide)
        self.assertIn("run Play Dragon Warrior.cmd again", guide)
        self.assertIn("Reloading the\naccessibility script may also restore control", guide)


if __name__ == "__main__":
    unittest.main()
