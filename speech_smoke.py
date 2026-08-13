"""
Standalone screen-reader speech smoke test.

Run this manually from the command line, outside FCEUX:

    python speech_smoke.py

This intentionally speaks and is therefore not named ``test_*.py`` or run by
the automated unittest discovery gate.
"""

import sys


print("Step 1: Importing accessible_output2...")
try:
    from accessible_output2.outputs.auto import Auto

    print("  Import OK")
except ImportError as exc:
    print(f"  FAILED: {exc}")
    print("  Use a project-local venv instead of the system Python.")
    print("  Example (Windows): py -m venv .venv")
    print(r"  Then: .venv\Scripts\python.exe -m pip install accessible_output2")
    sys.exit(1)

print("Step 2: Creating auto-detect output...")
speaker = Auto()
print(f"  Created: {speaker}")

print("Step 3: Attempting to speak...")
try:
    speaker.speak("Screen reader test successful. Hello from Python.")
    print("  speak() called without error")
except Exception as exc:
    print(f"  FAILED: {exc}")
    sys.exit(1)

print("\nIf you heard speech, everything is working!")
print("Test complete.")
