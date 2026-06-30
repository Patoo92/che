#!/bin/bash
# setup_cron.sh — Agrega la consolidación nocturna al crontab
# Ejecutar: bash scripts/setup_cron.sh

CRON_LINE='0 3 * * * cd /home/che/che-server && docker compose exec -T backend python /app/scripts/consolidacion.py >> /mnt/che/logs/consolidacion.log 2>&1'

# Verificar si ya existe
if crontab -l 2>/dev/null | grep -q "consolidacion.py"; then
    echo "✅ La tarea cron ya está configurada. No se hicieron cambios."
    crontab -l
    exit 0
fi

# Agregar al crontab
(crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -

echo "✅ Consolidación nocturna programada: todos los días a las 3 AM"
echo ""
echo "Tareas activas:"
crontab -l
