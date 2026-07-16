import pygetwindow as gw

def minimize_all():
    for w in gw.getAllWindows():
        if w.visible and w.title:
            try:
                w.minimize()
            except Exception:
                pass
    return "Minimizando todas las ventanas"

def maximize_window(title=None):
    wins = gw.getWindowsWithTitle(title) if title else gw.getAllWindows()
    for w in wins:
        if w.visible and w.title:
            try:
                w.maximize()
            except Exception:
                pass
    return f"Maximizando ventana"

def restore_window(title=None):
    wins = gw.getWindowsWithTitle(title) if title else gw.getAllWindows()
    for w in wins:
        if w.visible and w.title:
            try:
                w.restore()
            except Exception:
                pass
    return "Restaurando ventana"

def close_window(title=None):
    if title:
        wins = gw.getWindowsWithTitle(title)
        for w in wins:
            try:
                w.close()
            except Exception:
                pass
        return f"Cerrando ventana: {title}"
    return "¿Qué ventana querés cerrar?"
