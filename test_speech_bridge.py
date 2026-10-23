import io
import threading
import time
import unittest

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


def test_silence_discards_pending_speech_even_when_queue_is_full():
    speaker = BlockingSpeaker()
    dispatcher = speech_bridge.SpeechDispatcher(speaker, lambda message: None, max_queue=1)
    try:
        dispatcher.submit("speak", "block")
        assert_true(speaker.started.wait(1), "first call should block the worker")
        dispatcher.submit("speak", "obsolete")
        dispatcher.submit("silence")
        speaker.release.set()
        dispatcher.close()
        assert_true(speaker.calls == [("block", False), ("silence", False)],
                    "silence must replace pending speech, including a full queue")
    finally:
        speaker.release.set()
        dispatcher.close()


def test_close_stops_worker_after_a_full_queue_drains():
    speaker = BlockingSpeaker()
    dispatcher = speech_bridge.SpeechDispatcher(speaker, lambda message: None, max_queue=1)
    try:
        dispatcher.submit("speak", "block")
        assert_true(speaker.started.wait(1), "first call should block the worker")
        dispatcher.submit("speak", "last")
        dispatcher.close(wait=False)
        speaker.release.set()
        dispatcher.close()
        assert_true(not dispatcher._thread.is_alive(), "close must work with a full queue")
        assert_true(speaker.calls == [("block", False), ("last", False)],
                    "graceful close should drain accepted speech")
    finally:
        speaker.release.set()
        dispatcher.close()


def test_submit_after_close_does_not_restart_or_enqueue_work():
    speaker = BlockingSpeaker()
    dispatcher = speech_bridge.SpeechDispatcher(speaker, lambda message: None)
    dispatcher.close()
    dispatcher.submit("interrupt", "too late")
    assert_true(dispatcher._queue.empty(), "closed dispatcher must reject new commands")
    assert_true(speaker.calls == [], "closed dispatcher must not call the backend")


def test_silence_supports_backends_with_only_speak():
    class SpeakOnly:
        def __init__(self):
            self.calls = []

        def speak(self, text, interrupt=False):
            self.calls.append((text, interrupt))

    speaker = SpeakOnly()
    logs = []
    dispatcher = speech_bridge.SpeechDispatcher(speaker, logs.append)
    dispatcher.submit("silence")
    dispatcher.close()
    assert_true(speaker.calls == [("", True)], "JAWS needs an empty interrupt")
    assert_true(logs == [], "silence should not log a backend attribute failure")


def load_tests(loader, tests, pattern):
    # unittest discovery otherwise silently skips these standalone functions.
    tests.addTests(unittest.FunctionTestCase(test) for name, test in sorted(globals().items())
                   if name.startswith("test_") and callable(test))
    return tests


if __name__ == "__main__":
    unittest.main()
