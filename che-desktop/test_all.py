import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
import config

print("=== CHE Desktop Test ===")
print("Server:", config.SERVER_URL)
print("Whisper:", config.WHISPER_MODEL)
print()

# Test 1: Microphone
print("1. Testing microphone...")
try:
    import sounddevice as sd
    devices = sd.query_devices()
    print("   Available audio input devices:")
    for i, d in enumerate(devices):
        if d["max_input_channels"] > 0:
            print("   [%d] %s (inputs: %d)" % (i, d["name"], d["max_input_channels"]))
except Exception as e:
    print("   ERROR:", e)

# Test 2: TTS
print()
print("2. Testing TTS...")
try:
    import pyttsx3
    engine = pyttsx3.init()
    engine.setProperty("rate", 180)
    print("   pyttsx3 init OK")
    engine.say("Hola, soy CHE")
    engine.runAndWait()
    print("   TTS test spoken")
    engine.stop()
except Exception as e:
    print("   ERROR:", e)

# Test 3: Vosk
print()
print("3. Testing Vosk...")
try:
    from vosk import Model, KaldiRecognizer
    print("   Vosk import OK")
    model = Model(lang="es")
    print("   Vosk model loaded")
except Exception as e:
    print("   ERROR:", e)

# Test 4: Whisper
print()
print("4. Testing faster-whisper...")
try:
    from faster_whisper import WhisperModel
    print("   faster-whisper import OK")
    print("   Loading model (may take a moment)...")
    model = WhisperModel(config.WHISPER_MODEL, device=config.WHISPER_DEVICE, compute_type=config.WHISPER_COMPUTE)
    print("   Whisper model loaded:", config.WHISPER_MODEL)
except Exception as e:
    print("   ERROR:", e)

# Test 5: WebSocket
print()
print("5. Testing server connection...")
try:
    import asyncio
    import websockets

    async def test_ws():
        try:
            async with websockets.connect(config.SERVER_URL, open_timeout=5) as ws:
                print("   Connected to", config.SERVER_URL)
                return True
        except Exception as e:
            print("   Connection failed:", e)
            return False

    asyncio.run(test_ws())
except Exception as e:
    print("   ERROR:", e)

# Test 6: Record 3 seconds of audio
print()
print("6. Recording 3 seconds of audio...")
try:
    import sounddevice as sd
    import numpy as np
    recording = sd.rec(int(3 * config.SAMPLE_RATE), samplerate=config.SAMPLE_RATE, channels=1, dtype="int16")
    sd.wait()
    rms = np.sqrt(np.mean(recording.astype(np.float32) ** 2))
    print("   Recording OK, RMS:", round(float(rms), 2))
except Exception as e:
    print("   ERROR:", e)

print()
print("=== All Tests Complete ===")
