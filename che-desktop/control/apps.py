import subprocess
import os

def open_app(app_name):
    apps = {
        "chrome": r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        "firefox": r"C:\Program Files\Mozilla Firefox\firefox.exe",
        "spotify": r"C:\Users\alegr\AppData\Local\Microsoft\WindowsApps\Spotify.exe",
        "vscode": r"C:\Users\alegr\AppData\Local\Programs\Microsoft VS Code\Code.exe",
        "notepad": "notepad.exe",
        "calculator": "calc.exe",
    }
    path = apps.get(app_name.lower())
    if path:
        subprocess.Popen([path])
        return f"Abriendo {app_name}"
    subprocess.Popen(["cmd", "/c", "start", "", app_name])
    return f"Abriendo {app_name}"

def close_app(app_name):
    subprocess.run(["taskkill", "/IM", f"{app_name}.exe", "/F"], capture_output=True)
    return f"Cerrando {app_name}"
