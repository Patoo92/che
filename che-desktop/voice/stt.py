import queue
import tempfile
import os
import sounddevice as sd
import numpy as np
from faster_whisper import WhisperModel
import config

_model = None

def _get_model():
    global _model
    if _model is None:
        _model = WhisperModel(
            config.WHISPER_MODEL,
            device=config.WHISPER_DEVICE,
            compute_type=config.WHISPER_COMPUTE,
        )
    return _model

def record_audio():
    audio_queue = queue.Queue()
    frames = []

    def audio_callback(indata, frames_count, time, status):
        audio_queue.put(bytes(indata))

    with sd.RawInputStream(
        samplerate=config.SAMPLE_RATE,
        blocksize=config.BLOCK_SIZE,
        dtype="int16",
        channels=config.CHANNELS,
        callback=audio_callback,
    ):
        silence_start = None
        while True:
            data = audio_queue.get()
            frames.append(data)
            audio_np = np.frombuffer(data, dtype=np.int16).astype(np.float32)
            rms = np.sqrt(np.mean(audio_np ** 2))

            if rms < config.SILENCE_THRESHOLD:
                if silence_start is None:
                    silence_start = len(frames)
                elif (len(frames) - silence_start) * (config.BLOCK_SIZE / config.SAMPLE_RATE) > config.SILENCE_TIMEOUT:
                    break
            else:
                silence_start = None

            total_seconds = len(frames) * (config.BLOCK_SIZE / config.SAMPLE_RATE)
            if total_seconds > config.MAX_RECORD_SECONDS:
                break

    return b"".join(frames)

def transcribe(audio_data):
    model = _get_model()

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        import wave
        wf = wave.open(f.name, "wb")
        wf.setnchannels(config.CHANNELS)
        wf.setsampwidth(2)
        wf.setframerate(config.SAMPLE_RATE)
        wf.writeframes(audio_data)
        wf.close()

        segments, info = model.transcribe(f.name, language="es", beam_size=5)
        text = " ".join(seg.text.strip() for seg in segments)

        os.unlink(f.name)
        return text
