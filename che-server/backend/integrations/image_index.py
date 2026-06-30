from pathlib import Path
from config import BRAIN_PATH
import os

def indexar_imagenes():
    ruta_imagenes = Path(BRAIN_PATH) / "imagenes"
    if not ruta_imagenes.exists():
        return []
    imagenes = []
    for ext in ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp"]:
        imagenes.extend(ruta_imagenes.rglob(ext))
    return [str(i) for i in imagenes]
