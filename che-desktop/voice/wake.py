import json
import queue
import sounddevice as sd
from vosk import Model, KaldiRecognizer
import config

_model = None

def _get_model():
    global _model
    if _model is None:
        _model = Model(lang="es")
    return _model

def listen_for_wake_word(callback):
    model = _get_model()
    rec = KaldiRecognizer(model, config.SAMPLE_RATE)
    rec.SetWords(True)

    audio_queue = queue.Queue()

    def audio_callback(indata, frames, time, status):
        audio_queue.put(bytes(indata))

    with sd.RawInputStream(
        samplerate=config.SAMPLE_RATE,
        blocksize=config.BLOCK_SIZE,
        dtype="int16",
        channels=config.CHANNELS,
        callback=audio_callback,
    ):
        while True:
            data = audio_queue.get()
            if rec.AcceptWaveform(data):
                result = json.loads(rec.Result())
                text = result.get("text", "").lower().strip()
                if "che" in text:
                    callback()
