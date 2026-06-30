# open_project.ps1
# Abre la carpeta del proyecto y la documentación

$ruta = Join-Path $PSScriptRoot ".." ".." | Resolve-Path

# Abrir carpeta en Explorer
Invoke-Item $ruta

# Abrir documentación
$doc = Join-Path $ruta "CHE_DOCUMENTACION.md"
if (Test-Path $doc) {
    Invoke-Item $doc
}
