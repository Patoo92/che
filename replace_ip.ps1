# ============================================================
# replace_ip.ps1 — Reemplaza 100.x.x.x por tu IP de Tailscale
# 
# Cómo usar:
#   1. Ejecutá:  tailscale ip -4
#   2. Anotá la IP (ej: 100.64.0.1)
#   3. Ejecutá este script:  .\replace_ip.ps1
#   4. Cuando pregunte, pegá la IP
# ============================================================

$ip = Read-Host "Pegá la IP de Tailscale del servidor (ej: 100.64.0.1)"
if (-not $ip) {
    Write-Host "❌ No ingresaste ninguna IP." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Reemplazando 100.x.x.x por $ip en todos los archivos..."
Write-Host ""

$archivos = @(
    "che-server\docker-compose.yml",
    "che-server\app\lib\services\websocket_service.dart",
    "che-server\app\lib\services\tts_service.dart"
)

foreach ($archivo in $archivos) {
    $ruta = Join-Path $PSScriptRoot $archivo
    if (Test-Path $ruta) {
        $contenido = Get-Content $ruta -Raw
        if ($contenido -match "100\.x\.x\.x") {
            $contenido = $contenido -replace "100\.x\.x\.x", $ip
            Set-Content $ruta $contenido -NoNewline
            Write-Host "✅ $archivo" -ForegroundColor Green
        } else {
            Write-Host "⚠️  $archivo (sin 100.x.x.x, puede que ya esté actualizado)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ $archivo (archivo no encontrado)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Listo. Revisá los archivos para confirmar." -ForegroundColor Green
