#!/bin/bash
# ============================================================
# setup_server.sh — Script automático de instalación del servidor
# Ejecutar: bash setup_server.sh
# ============================================================

set -e

echo "========================================"
echo "  CHE — Instalación del Servidor"
echo "========================================"
echo ""

# ─── Verificar que no se ejecuta como root ───
if [ "$EUID" -eq 0 ]; then
    echo "❌ No ejecutes este script como root. Usá el usuario 'che'."
    exit 1
fi

echo "✅ Usuario: $(whoami)"
echo ""

# ─── 1. Actualizar sistema ───
echo "[1/7] Actualizando sistema..."
sudo apt update && sudo apt upgrade -y
echo "✅ Sistema actualizado"
echo ""

# ─── 2. Instalar herramientas básicas ───
echo "[2/7] Instalando herramientas..."
sudo apt install -y curl wget git htop net-tools ufw tree openssl
echo "✅ Herramientas instaladas"
echo ""

# ─── 3. Configurar disco externo ───
echo "[3/7] Configurando disco externo..."
echo ""
echo "IDENTIFICACIÓN DE DISCOS:"
lsblk -d -o NAME,SIZE,MODEL | grep -v loop
echo ""
echo "Buscá el disco de 1TB (ej: sdb), luego ejecutá MANUALMENTE:"
echo "  sudo mkfs.ext4 /dev/sdX   (X = tu disco, ej: sdb)"
echo "  sudo mkdir -p /mnt/che"
echo "  sudo mount /dev/sdX /mnt/che"
echo "  sudo blkid /dev/sdX   (copiar UUID)"
echo "  sudo nano /etc/fstab   (agregar UUID)"
echo "  sudo chown -R che:che /mnt/che"
echo "  mkdir -p /mnt/che/{models,brain/{diario,notas,imagenes,hechos},pgdata,backups/{pg,brain},logs}"
echo ""

read -p "¿Ya configuraste el disco externo? (s/N): " disco_ok
if [ "$disco_ok" != "s" ] && [ "$disco_ok" != "S" ]; then
    echo "⏸️  Pausando. Configurá el disco y ejecutá el script de nuevo."
    exit 0
fi

if [ ! -d "/mnt/che" ]; then
    echo "❌ /mnt/che no existe. Configurá el disco primero."
    exit 1
fi
echo "✅ Disco configurado"
echo ""

# ─── 4. Configurar firewall ───
echo "[4/7] Configurando firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 41641/udp
sudo ufw --force enable
sudo ufw status
echo "✅ Firewall configurado"
echo ""

# ─── 5. Instalar Docker ───
echo "[5/7] Instalando Docker..."
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sudo sh /tmp/get-docker.sh
sudo usermod -aG docker $USER
echo "✅ Docker instalado (necesitás cerrar sesión y volver a entrar)"
echo ""

# ─── 6. Instalar Tailscale ───
echo "[6/7] Instalando Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
echo ""
echo "========================================"
echo "  IMPORTANTE: Iniciar Tailscale"
echo "========================================"
echo ""
echo "Ejecutá:  sudo tailscale up"
echo "Después:  tailscale ip -4"
echo "Anotá esa IP (100.x.x.x)"
echo ""
read -p "¿Ya iniciaste Tailscale y tenés la IP? (s/N): " ts_ok
if [ "$ts_ok" != "s" ] && [ "$ts_ok" != "S" ]; then
    echo "⏸️  Ejecutá 'sudo tailscale up', autenticate, y volvé a correr el script."
    exit 0
fi
echo "✅ Tailscale configurado"
echo ""

# ─── 7. Preparar proyecto ───
echo "[7/7] Preparando proyecto..."
cd /home/che/che-server

# Generar .env si no existe
if [ ! -f ".env" ]; then
    CONTRASENA=$(openssl rand -base64 32)
    echo "POSTGRES_PASSWORD=$CONTRASENA" > .env
    chmod 600 .env
    echo "✅ .env creado con contraseña generada"
else
    echo "✅ .env ya existe"
fi

echo ""
echo "========================================"
echo "  INSTALACIÓN COMPLETADA"
echo "========================================"
echo ""
echo "Ahora ejecutá estos pasos MANUALMENTE:"
echo ""
echo "  1. Cerrar sesión: exit"
echo "  2. Volver a conectarte por SSH"
echo "  3. cd /home/che/che-server"
echo "  4. docker compose up -d"
echo "  5. docker exec che-ollama ollama pull qwen2.5:1.5b"
echo "  6. docker exec che-ollama ollama pull nomic-embed-text"
echo "  7. docker exec -i che-postgres psql -U che -d che_brain < init_db.sql"
echo "  8. curl http://localhost:8000   (verificar)"
echo ""
echo "¡Listo! 🎉"
