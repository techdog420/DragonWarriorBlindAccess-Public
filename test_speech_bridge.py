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


class FakeSAPI5:
    pass


class FakeNVDA:
    def __init__(self, active=True):
        self.active = active

    def is_active(self):
        return self.active


class FakeJaws:
    pass


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


def test_create_speaker_prefers_jaws_when_jfw_is_running():
    logs = []
    speaker = speech_bridge.create_speaker(
        logs.append,
        process_names={"jfw.exe"},
        nvda_factory=lambda: FakeNVDA(active=False),
        jaws_factory=FakeJaws,
        sapi_factory=FakeSAPI5,
    )

    assert_true(isinstance(speaker, FakeJaws), "running JAWS should select JAWS")
    assert_true(
        "selected_backend=Jaws reason=jfw-process" in logs,
        "JAWS selection reason should be logged",
    )


def test_create_speaker_prefers_active_nvda():
    logs = []
    speaker = speech_bridge.create_speaker(
        logs.append,
        process_names={"nvda.exe"},
        nvda_factory=FakeNVDA,
        jaws_factory=FakeJaws,
        sapi_factory=FakeSAPI5,
    )

    assert_true(isinstance(speaker, FakeNVDA), "active NVDA should be selected")
    assert_true(
        "selected_backend=NVDA reason=active" in logs,
        "NVDA selection reason should be logged",
    )


def test_create_speaker_preserves_nvda_when_jaws_also_runs():
    logs = []
    speaker = speech_bridge.create_speaker(
        logs.append,
        process_names={"nvda.exe", "jfw.exe"},
        nvda_factory=FakeNVDA,
        jaws_factory=FakeJaws,
        sapi_factory=FakeSAPI5,
    )

    assert_true(isinstance(speaker, FakeNVDA), "active NVDA should retain priority")
    assert_true(
        "selected_backend=NVDA reason=active" in logs,
        "NVDA selection should be logged",
    )


def test_create_speaker_falls_back_when_jaws_backend_fails():
    logs = []

    def failing_jaws():
        raise RuntimeError("unavailable")

    speaker = speech_bridge.create_speaker(
        logs.append,
        process_names={"jfw.exe"},
        nvda_factory=lambda: FakeNVDA(active=False),
        jaws_factory=failing_jaws,
        sapi_factory=FakeSAPI5,
    )

    assert_true(isinstance(speaker, FakeSAPI5), "failed JAWS backend should fall back")
    joined = "\n".join(logs)
    assert_true("JAWS direct backend failed" in joined, "fallback reason should be logged")
    assert_true("selected_backend=SAPI5 reason=fallback" in joined, "fallback should be logged")


def test_create_speaker_uses_sapi_without_screen_reader():
    logs = []
    speaker = speech_bridge.create_speaker(
        logs.append,
        process_names=set(),
        nvda_factory=lambda: FakeNVDA(active=False),
        jaws_factory=FakeJaws,
        sapi_factory=FakeSAPI5,
    )

    assert_true(isinstance(speaker, FakeSAPI5), "SAPI should be the final fallback")
    assert_true(
        "selected_backend=SAPI5 reason=fallback" in logs,
        "SAPI fallback should be logged",
    )


if __name__ == "__main__":
    test_command_loop_keeps_reading_when_speaker_blocks()
    test_create_speaker_prefers_jaws_when_jfw_is_running()
    test_create_speaker_prefers_active_nvda()
    test_create_speaker_preserves_nvda_when_jaws_also_runs()
    test_create_speaker_falls_back_when_jaws_backend_fails()
    test_create_speaker_uses_sapi_without_screen_reader()
    print("test_speech_bridge.py: 6 tests passed")
