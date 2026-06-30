# CHEATSHEET — Referencia Rápida de Comandos

## Conexión al servidor
```bash
ssh che@<IP_DEL_SERVIDOR>
```

## Copiar archivos al servidor (desde PC2)
```bash
cd C:\Users\Usuario\Desktop\"RE JARVIS - CHE"\che-server
scp -r * che@<IP_DEL_SERVIDOR>:/home/che/che-server/
```

## Tailscale
```bash
sudo tailscale up               # Iniciar sesión
tailscale ip -4                 # Ver IP
tailscale status                # Ver dispositivos conectados
```

## Docker
```bash
cd /home/che/che-server
docker compose up -d            # Iniciar todos los servicios
docker compose down             # Detener todos los servicios
docker compose ps               # Ver estado
docker compose logs -f --tail=50 # Ver logs en vivo
docker compose logs backend     # Ver logs de un servicio
```

## Descargar modelos Ollama
```bash
docker exec che-ollama ollama pull qwen2.5:1.5b
docker exec che-ollama ollama pull nomic-embed-text
docker exec che-ollama ollama list
```

## Inicializar base de datos
```bash
docker exec -i che-postgres psql -U che -d che_brain < init_db.sql
```

## Probar backend
```bash
curl http://localhost:8000               # Desde el servidor
curl http://<IP_TAILSCALE>:8000          # Desde PC2 o celu
curl "http://<IP_TAILSCALE>:8000/tts?texto=Hola%20che"  # Probar TTS
```

## Consolidación nocturna (cron)
```bash
crontab -e
# Agregar:
0 3 * * * cd /home/che/che-server && docker compose exec -T backend python /app/scripts/consolidacion.py >> /mnt/che/logs/consolidacion.log 2>&1
```

## App Flutter (desde PC2)
```bash
cd C:\Users\Usuario\Desktop\"RE JARVIS - CHE"\che-server\app
flutter pub get
flutter build apk --debug
flutter install
```

## Reemplazar IP de Tailscale (desde PC2, PowerShell)
```powershell
.\replace_ip.ps1
```

## Mantenimiento
```bash
# Ver uso de RAM
docker stats

# Ver espacio en disco
df -h

# Ver logs del servidor
htop
```
