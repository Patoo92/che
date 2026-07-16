import pyautogui
import subprocess

def click(x=None, y=None):
    if x is not None and y is not None:
        pyautogui.click(x, y)
        return f"Haciendo click en {x}, {y}"
    pyautogui.click()
    return "Click"

def move_mouse(x, y):
    pyautogui.moveTo(x, y)
    return f"Moviendo mouse a {x}, {y}"

def type_text(text):
    pyautogui.typewrite(text, interval=0.05)
    return f"Escribiendo: {text}"

def press_key(key):
    pyautogui.press(key)
    return f"Presionando: {key}"

def hotkey(*keys):
    pyautogui.hotkey(*keys)
    return f"Combinación: {'+'.join(keys)}"

def screenshot(path="screenshot.png"):
    pyautogui.screenshot(path)
    return f"Screenshot guardado en {path}"
