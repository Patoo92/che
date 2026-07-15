from faster_whisper import WhisperModel
import io
import wave

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

    if audio_bytes[:4] == b'RIFF':
        wav_bytes = audio_bytes
    else:
        wav_buffer = io.BytesIO()
        with wave.open(wav_buffer, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(audio_bytes)
        wav_bytes = wav_buffer.getvalue()

    segments, info = model.transcribe(
        wav_bytes,
        language="es",
        beam_size=3,
        vad_filter=True,
    )

    text = " ".join(seg.text.strip() for seg in segments)
    print(f"[STT] Whisper: '{text}' (lang={info.language}, prob={info.language_probability:.2f})")
    return text
