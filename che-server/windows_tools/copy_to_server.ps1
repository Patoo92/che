# copy_to_server.ps1
# Copia todos los archivos del proyecto al servidor

$ip = Read-Host "IP del servidor (ej: 192.168.1.100 o 100.x.x.x)"
if (-not $ip) {
    Write-Host "No ingresaste ninguna IP." -ForegroundColor Red
    exit 1
}

$origen = Join-Path $PSScriptRoot ".." | Resolve-Path

Write-Host "Copiando archivos a che@${ip}:/home/che/che-server/ ..."
scp -r "$origen\*" "che@${ip}:/home/che/che-server/"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Archivos copiados correctamente." -ForegroundColor Green
} else {
    Write-Host "❌ Error al copiar archivos." -ForegroundColor Red
}
