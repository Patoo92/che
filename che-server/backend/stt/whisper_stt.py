from faster_whisper import WhisperModel
import io
import wave
import tempfile
import os

_model = None

def get_model():
    global _model
    if _model is None:
        print("[STT] Loading Whisper base model (CPU)...")
        _model = WhisperModel("base", device="cpu", compute_type="int8")
        print("[STT] Whisper model loaded")
    return _model

def transcribe_audio(audio_bytes: bytes, sample_rate: int = 16000) -> str:
    model = get_model()

    tmp_path = None
    try:
        if audio_bytes[:4] == b'RIFF':
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
                f.write(audio_bytes)
                tmp_path = f.name
        else:
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
                with wave.open(f, "wb") as wf:
                    wf.setnchannels(1)
                    wf.setsampwidth(2)
                    wf.setframerate(sample_rate)
                    wf.writeframes(audio_bytes)
                tmp_path = f.name

        segments, info = model.transcribe(
            tmp_path,
            language="es",
            beam_size=3,
            vad_filter=True,
        )

        text = " ".join(seg.text.strip() for seg in segments)
        print(f"[STT] Whisper: '{text}' (lang={info.language}, prob={info.language_probability:.2f})")
        return text
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)
