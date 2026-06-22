import io
import threading
import time

import speech_bridge


class BlockingSpeaker:
    def __init__(self):
        self.started = threading.Event()
        self.release = threading.Event()
        self.calls = []

    def speak(self, text, interrupt=False):
        self.calls.append((text, interrupt))
        if text == "block":
            self.started.set()
            self.release.wait(5)

    def silence(self):
        self.calls.append(("silence", False))


def assert_true(value, message):
    if not value:
        raise AssertionError(message)


def test_command_loop_keeps_reading_when_speaker_blocks():
    speaker = BlockingSpeaker()
    logs = []
    stdin = io.StringIO("speak:block\nspeak:second\n")
    start = time.monotonic()

    dispatcher = speech_bridge.SpeechDispatcher(speaker, logs.append)
    try:
        speech_bridge.run_command_loop(stdin, dispatcher, logs.append)
        assert_true(speaker.started.wait(0.5), "blocking speech should have started")
    finally:
        speaker.release.set()
        dispatcher.close(wait=False)

    elapsed = time.monotonic() - start
    joined = "\n".join(logs)

    assert_true(elapsed < 0.5, "command loop should not wait for speaker.speak")
    assert_true("command='speak:block'" in joined, "first command should be logged")
    assert_true("command='speak:second'" in joined, "second command should be logged")


if __name__ == "__main__":
    test_command_loop_keeps_reading_when_speaker_blocks()
    print("test_speech_bridge.py: 1 test passed")
