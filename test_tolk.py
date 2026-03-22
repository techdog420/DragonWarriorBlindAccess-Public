"""
test_tolk.py
Standalone test to verify screen reader speech works from Python.
Run this from the command line (not from FCEUX):

    python test_tolk.py

This uses the accessible_output2 library which auto-detects your
active screen reader (JAWS, NVDA, Narrator) and handles the
32/64-bit DLL matching automatically.
"""

import sys

print("Step 1: Importing accessible_output2...")
try:
    from accessible_output2.outputs.auto import Auto
    print("  Import OK")
except ImportError as e:
    print(f"  FAILED: {e}")
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
except Exception as e:
    print(f"  FAILED: {e}")
    sys.exit(1)

print("\nIf you heard speech, everything is working!")
print("Test complete.")
