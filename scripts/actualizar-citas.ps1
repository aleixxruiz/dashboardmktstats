# ============================================================
#  ACTUALIZAR CITAS IA (Grounding queries + Cited pages)
# ============================================================
#  Lee el CSV que descargas de Clarity (AI Visibility -> Citation)
#  y genera datos/citas-ia.js para la pagina de Visibilidad en IA.
#
#  Como usarlo: descarga el CSV de Clarity, guardalo en la carpeta
#  del proyecto (se llamara "Clarity_ingesco.csv" o similar) y
#  ejecuta "Actualizar datos.bat". El script coge el CSV mas reciente.
#
#  No hay API para estos datos: por eso se hace desde el CSV.
# ============================================================
param([switch]$Silencioso)

$Raiz = Split-Path -Parent $PSScriptRoot
$CarpetaDatos = Join-Path $Raiz "datos"
if (-not (Test-Path $CarpetaDatos)) { New-Item -ItemType Directory -Path $CarpetaDatos | Out-Null }

# Buscar el CSV de Clarity mas reciente
$csv = Get-ChildItem -Path $Raiz -Filter "Clarity_ingesco*.csv" -ErrorAction SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $csv) {
    Write-Host "(No hay CSV de Clarity para citas; se omite este bloque.)" -ForegroundColor DarkGray
    return
}

Write-Host "=== Procesando citas de IA desde: $($csv.Name) ===" -ForegroundColor Cyan
$lineas = Get-Content $csv.FullName -Encoding UTF8

$periodo = ""; $soa = 0; $referral = 0; $totalCitas = 0
$queries = @(); $paginas = @(); $topics = @()
$modo = ""
foreach ($l in $lineas) {
    $t = $l.Trim()
    if ($t -eq "") { $modo = ""; continue }
    if ($t -match '^"Intervalo de fechas","(.+)"$') { $periodo = $matches[1]; continue }
    if ($t -match 'Share of authority[^"]*","([0-9.]+)"') {
        try { $soa = [math]::Round([double]::Parse($matches[1], [Globalization.CultureInfo]::InvariantCulture), 1) } catch { $soa = 0 }
        continue
    }
    if ($t -match '"AI referral traffic","([0-9]+)"') { $referral   = [int]$matches[1]; continue }
    if ($t -match '"Page citations","([0-9]+)"')      { $totalCitas = [int]$matches[1]; continue }
    # Cabeceras de seccion (el formato de Clarity cambio: antes "Query", ahora "Topic")
    if ($t -match '^"Query","SoA","Citations"$')  { $modo = "q"; continue }
    if ($t -match '^"Topic","Citations","SoA"$')  { $modo = "t"; continue }
    if ($t -match '^"Page URL","Citations"$')     { $modo = "p"; continue }

    if ($modo -eq "q" -and $t -match '^"(.*)","([0-9.,]+%)","([0-9]+)"$') {
        $queries += [pscustomobject]@{ query = $matches[1]; soa = $matches[2]; citations = [int]$matches[3] }
    }
    elseif ($modo -eq "t" -and $t -match '^"(.*)","([0-9]+)","([0-9.,]+%?)"$') {
        $topics += [pscustomobject]@{ query = $matches[1]; citations = [int]$matches[2]; soa = $matches[3] }
    }
    elseif ($modo -eq "p" -and $t -match '^"(.*)","([0-9]+)"$') {
        $paginas += [pscustomobject]@{ url = $matches[1]; citations = [int]$matches[2] }
    }
}
# Formato nuevo: si no hay "Query" pero si "Topic", usamos los temas como tabla principal
if ($queries.Count -eq 0 -and $topics.Count -gt 0) { $queries = $topics }

# Reformatear el periodo MM/DD/YYYY -> DD/MM/YYYY
$periodoTexto = $periodo
if ($periodo -match '(\d{2})/(\d{2})/(\d{4})[^-]*-\s*(\d{2})/(\d{2})/(\d{4})') {
    $periodoTexto = "{0}/{1}/{2} - {3}/{4}/{5}" -f $matches[2], $matches[1], $matches[3], $matches[5], $matches[4], $matches[6]
}

$obj = @{
    fechaActualizacion = (Get-Date).ToString("dd/MM/yyyy HH:mm")
    periodo    = $periodoTexto
    soa        = $soa
    queries    = $queries
    paginas    = $paginas
    referral   = $referral      # visitas que llegan desde asistentes de IA (AI referral traffic)
    totalCitas = $totalCitas    # total de citas de paginas en el periodo
}
$json = $obj | ConvertTo-Json -Depth 6 -Compress
"window.CITAS = $json;" | Out-File (Join-Path $CarpetaDatos "citas-ia.js") -Encoding utf8

Write-Host ("OK  SoA: {0}%  |  Temas/Queries: {1}  |  Paginas citadas: {2}  |  Trafico IA: {3}" -f $soa, $queries.Count, $paginas.Count, $referral) -ForegroundColor Green
Write-Host "Guardado en datos/citas-ia.js"