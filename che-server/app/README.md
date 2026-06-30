# App CHE — Flutter

## Cómo compilar la app

1. Instalar Flutter SDK:
   https://docs.flutter.dev/get-started/install/windows

2. Abrir PowerShell y ejecutar:
```
cd che-server/app
flutter pub get
flutter build apk --debug
```

3. El APK se genera en:
   `build/app/outputs/flutter-apk/app-debug.apk`

4. Copiarlo al celu e instalar, o conectar celu por USB y:
```
flutter install
```

## Antes de compilar

Reemplazar `100.x.x.x` por la IP real de Tailscale del servidor en:
- `lib/services/websocket_service.dart`
- `lib/services/tts_service.dart`

Usar el script `replace_ip.ps1` desde la carpeta raíz del proyecto.
