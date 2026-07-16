import psutil
import subprocess
import platform

def get_cpu_usage():
    return f"Uso de CPU: {psutil.cpu_percent(interval=1)}%"

def get_memory_usage():
    mem = psutil.virtual_memory()
    return f"RAM: {mem.percent}% ({mem.used // (1024**3)}GB de {mem.total // (1024**3)}GB)"

def get_disk_usage():
    disk = psutil.disk_usage("C:\\")
    return f"Disco C: {disk.percent}% ({disk.free // (1024**3)}GB libres)"

def get_battery():
    bat = psutil.sensors_battery()
    if bat:
        return f"Batería: {bat.percent}% {'(cargando)' if bat.power_plugged else ''}"
    return "No hay batería detectada"

def get_uptime():
    boot = psutil.boot_time()
    import time
    uptime = time.time() - boot
    hours = int(uptime // 3600)
    minutes = int((uptime % 3600) // 60)
    return f"Uptime: {hours}h {minutes}m"

def get_system_info():
    info = [
        get_cpu_usage(),
        get_memory_usage(),
        get_disk_usage(),
        get_battery(),
        get_uptime(),
    ]
    return "\n".join(info)

def set_volume(level):
    from ctypes import cast, POINTER
    from comtypes import CLSCTX_ALL
    from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
    devices = AudioUtilities.GetSpeakers()
    iface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
    volume = cast(iface, POINTER(IAudioEndpointVolume))
    volume.SetMasterVolumeLevelScalar(level / 100.0, None)
    return f"Volumen: {level}%"

def get_volume():
    from ctypes import cast, POINTER
    from comtypes import CLSCTX_ALL
    from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
    devices = AudioUtilities.GetSpeakers()
    iface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
    volume = cast(iface, POINTER(IAudioEndpointVolume))
    level = round(volume.GetMasterVolumeLevelScalar() * 100)
    return f"Volumen actual: {level}%"
