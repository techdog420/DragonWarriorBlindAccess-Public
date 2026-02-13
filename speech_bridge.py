"""
speech_bridge.py
Bridge between FCEUX Lua scripts and screen reader speech output.

FCEUX uses standard Lua 5.1 which can't load DLLs directly (no FFI).
This Python script acts as a middleman:
  - FCEUX Lua opens a pipe to this process via io.popen
  - Lua sends simple text commands through the pipe (one per line)
  - This script calls the screen reader via accessible_output2

accessible_output2 auto-detects the active screen reader (JAWS, NVDA,
Narrator) and handles 32/64-bit DLL selection automatically.

Commands (sent as lines of text):
  speak:Some text here     -> Speak text without interrupting
  interrupt:Some text here -> Speak text, cutting off current speech
  silence                  -> Stop all current speech

Requirements:
  - Python 3.x
  - accessible_output2 package (pip install accessible_output2)
  - A screen reader running (NVDA, JAWS, or Narrator)
"""

import sys

def main():
    # Import the auto-detecting screen reader output
    from accessible_output2.outputs.auto import Auto
    speaker = Auto()

    # Read commands from stdin, one per line.
    # We use readline() instead of iterating stdin directly because
    # Python 3's "for line in sys.stdin" buffers aggressively, which
    # would delay speech output until the buffer fills up.
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                # Empty string means EOF — the pipe was closed
                # (FCEUX shut down or the script was unloaded)
                break

            line = line.strip()
            if not line:
                continue

            if line.startswith("speak:"):
                # Speak without interrupting current speech
                text = line[6:]
                speaker.speak(text, interrupt=False)

            elif line.startswith("interrupt:"):
                # Speak and cut off any current speech
                text = line[10:]
                speaker.speak(text, interrupt=True)

            elif line == "silence":
                # Stop all current speech
                speaker.silence()

        except KeyboardInterrupt:
            break
        except Exception as e:
            # Log errors but keep running — one bad command
            # shouldn't kill the whole speech bridge
            print(f"Bridge error: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
