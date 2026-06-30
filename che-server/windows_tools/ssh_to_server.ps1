# ssh_to_server.ps1
# Pide la IP del servidor y se conecta por SSH

$ip = Read-Host "IP del servidor (ej: 192.168.1.100 o 100.x.x.x)"
if ($ip) {
    ssh "che@$ip"
} else {
    Write-Host "No ingresaste ninguna IP." -ForegroundColor Red
}
