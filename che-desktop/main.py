import sys
import os
import threading
import json
import asyncio
import pystray
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import config
from voice.wake import listen_for_wake_word
from voice.stt import record_audio, transcribe
from voice.tts import speak
from brain.client import send_message
from control import apps, window, input as ctrl_input, system, browser

def classify_command(text):
    text_lower = text.lower()

    local_commands = [
        "abrí", "abri", "abrir", "cerrá", "cerro", "cerrar",
        "minimizá", "minimizar", "maximizá", "maximizar",
        "subí", "bajá", "volumen", "brillo",
        "screenshot", "captura", "tomá",
        "escribí", "escribir", "click", "mouse",
        "hora", "fecha", "batería", "bateria", "cpu", "ram", "disco", "pc",
        "googleá", "buscá", "buscar", "youtube",
    ]

    for cmd in local_commands:
        if cmd in text_lower:
            return "local"

    return "server"

def handle_local_command(text):
    text_lower = text.lower()

    if any(w in text_lower for w in ["abrí", "abri", "abrir"]):
        for app in ["chrome", "firefox", "spotify", "vscode", "notepad", "calculator"]:
            if app in text_lower:
                return apps.open_app(app)
        return apps.open_app(text_lower.split("abrí")[-1].strip().split("abri")[-1].strip().split("abrir")[-1].strip())

    if any(w in text_lower for w in ["cerrá", "cerro", "cerrar"]):
        for app in ["chrome", "firefox", "spotify", "vscode"]:
            if app in text_lower:
                return apps.close_app(app)
        return "¿Qué aplicación querés cerrar?"

    if "minimizá todo" in text_lower or "minimizar todo" in text_lower:
        return window.minimize_all()

    if "maximizá" in text_lower or "maximizar" in text_lower:
        return window.maximize_window()

    if "subí el volumen" in text_lower or "subir el volumen" in text_lower:
        vol = system.get_volume()
        current = int(vol.split(": ")[1].split("%")[0])
        return system.set_volume(min(100, current + 10))

    if "bajá el volumen" in text_lower or "bajar el volumen" in text_lower:
        vol = system.get_volume()
        current = int(vol.split(": ")[1].split("%")[0])
        return system.set_volume(max(0, current - 10))

    if "volumen" in text_lower:
        return system.get_volume()

    if any(w in text_lower for w in ["hora", "fecha"]):
        import datetime
        now = datetime.datetime.now()
        return now.strftime("Son las %H:%M del %d de %m de %Y")

    if any(w in text_lower for w in ["batería", "bateria"]):
        return system.get_battery()

    if any(w in text_lower for w in ["cpu", "ram", "disco", "cómo está la pc", "como esta la pc"]):
        return system.get_system_info()

    if any(w in text_lower for w in ["screenshot", "captura"]):
        return ctrl_input.screenshot()

    if any(w in text_lower for w in ["googleá", "buscá", "buscar"]):
        query = text_lower.replace("googleá", "").replace("buscá", "").replace("buscar", "").strip()
        return browser.search_google(query)

    if "youtube" in text_lower:
        query = text_lower.replace("youtube", "").strip()
        return browser.open_youtube(query)

    return "No entendí el comando"

def process_voice():
    print("[CHE] Grabando...")
    audio = record_audio()
    print("[CHE] Transcribiendo...")
    text = transcribe(audio)
    print(f"[CHE] Dijiste: {text}")

    if not text.strip():
        speak("No te escuché bien, repetí")
        return

    speak(f"Dijiste: {text}")

    command_type = classify_command(text)

    if command_type == "local":
        result = handle_local_command(text)
    else:
        result = asyncio.run(send_message(text))

    print(f"[CHE] {result}")
    speak(result)

def on_wake():
    print("[CHE] ¡Wake word detectada!")
    threading.Thread(target=process_voice, daemon=True).start()

def create_icon():
    if os.path.exists(config.TRAY_ICON_PATH):
        return Image.open(config.TRAY_ICON_PATH)
    img = Image.new("RGB", (64, 64), color=(30, 30, 30))
    return img

def on_exit(icon, item):
    icon.stop()
    sys.exit(0)

def main():
    print("[CHE] Iniciando CHE Desktop...")
    print(f"[CHE] Servidor: {config.SERVER_URL}")
    print(f"[CHE] Whisper: {config.WHISPER_MODEL}")

    icon = pystray.Icon(
        "che",
        create_icon(),
        config.TRAY_TOOLTIP,
        menu=pystray.Menu(
            pystray.MenuItem("Estado", lambda: None),
            pystray.MenuItem("Salir", on_exit),
        ),
    )

    print("[CHE] Escuchando wake word 'che'...")
    threading.Thread(target=listen_for_wake_word, args=(on_wake,), daemon=True).start()

    icon.run()

if __name__ == "__main__":
    main()
