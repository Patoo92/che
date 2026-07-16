import pyttsx3
import threading

_engine = None
_lock = threading.Lock()

def _get_engine():
    global _engine
    if _engine is None:
        _engine = pyttsx3.init()
        _engine.setProperty("rate", 180)
        _engine.setProperty("volume", 0.9)
        voices = _engine.getProperty("voices")
        for v in voices:
            if "es" in v.id.lower() or "spanish" in v.name.lower():
                _engine.setProperty("voice", v.id)
                break
    return _engine

def speak(text):
    def _speak():
        with _lock:
            engine = _get_engine()
            engine.say(text)
            engine.runAndWait()
    threading.Thread(target=_speak, daemon=True).start()
