# ============================================================
#  ACTUALIZAR DATOS - Dashboard Clarity
# ============================================================
#  Llama a la API de Microsoft Clarity y guarda los datos para
#  que el dashboard.html los pueda mostrar.
#
#  Como usarlo:
#   - Clic derecho -> "Ejecutar con PowerShell"
#   - O doble clic en "Actualizar datos.bat" (en la carpeta raiz)
#
#  Genera:
#   datos\datos.js        -> ultimos datos (los que pinta el dashboard)
#   datos\respuesta.json  -> respuesta cruda de la API (por si acaso)
#   datos\historico.js    -> acumula un punto por cada dia (tendencias)
# ============================================================
#
#  Parametro -Silencioso : no muestra pausas "Pulsa ENTER" (para la tarea programada)
# ============================================================
param([switch]$Silencioso)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$RaizProyecto = Split-Path -Parent $PSScriptRoot
$RutaConfig   = Join-Path $RaizProyecto "config.json"
$CarpetaDatos = Join-Path $RaizProyecto "datos"

if (-not (Test-Path $CarpetaDatos)) { New-Item -ItemType Directory -Path $CarpetaDatos | Out-Null }
$RutaLog = Join-Path $CarpetaDatos "log-actualizaciones.txt"
function Escribir-Log($texto) {
    $sello = (Get-Date).ToString("dd/MM/yyyy HH:mm:ss")
    Add-Content -Path $RutaLog -Value "$sello  $texto" -Encoding utf8
}
$modo = if ($Silencioso) { "AUTO" } else { "MANUAL" }
Escribir-Log "INICIO ($modo)"

Write-Host ""
Write-Host "=== Actualizando datos de Microsoft Clarity ===" -ForegroundColor Cyan

# --- Leer token ---
if (-not (Test-Path $RutaConfig)) {
    Write-Host "ERROR: No encuentro config.json" -ForegroundColor Red
    if (-not $Silencioso) { Read-Host "Pulsa ENTER para cerrar" }
    return
}
$config = Get-Content $RutaConfig -Raw | ConvertFrom-Json
$token  = $config.token
if ([string]::IsNullOrWhiteSpace($token) -or $token -eq "PEGA_AQUI_TU_TOKEN") {
    Write-Host "ERROR: Falta el token en config.json" -ForegroundColor Red
    if (-not $Silencioso) { Read-Host "Pulsa ENTER para cerrar" }
    return
}

# --- Llamada a la API (ultimos 3 dias, desglose por Dispositivo) ---
$url = "https://www.clarity.ms/export-data/api/v1/project-live-insights?numOfDays=3&dimension1=Device"
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

Write-Host "Consultando la API..." -ForegroundColor Gray
try {
    $respuesta = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
}
catch {
    $code = $null; if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    switch ($code) {
        401 { Write-Host "ERROR 401: Token invalido o caducado." -ForegroundColor Red }
        403 { Write-Host "ERROR 403: El token no tiene permisos (debes ser admin)." -ForegroundColor Red }
        429 { Write-Host "ERROR 429: Limite diario superado (max 10/dia). Prueba manana." -ForegroundColor Red }
        default { Write-Host "ERROR ($code): $($_.Exception.Message)" -ForegroundColor Red }
    }
    Escribir-Log "ERROR llamada general (codigo $code): $($_.Exception.Message)"
    if (-not $Silencioso) { Read-Host "Pulsa ENTER para cerrar" }
    return
}

$ahora      = Get-Date
$fechaTexto = $ahora.ToString("dd/MM/yyyy HH:mm")
$fechaDia   = $ahora.ToString("yyyy-MM-dd")

# --- Guardar respuesta cruda ---
$respuesta | ConvertTo-Json -Depth 10 | Out-File (Join-Path $CarpetaDatos "respuesta.json") -Encoding utf8

# --- Guardar datos.js (lo que lee el dashboard) ---
$jsonDatos = $respuesta | ConvertTo-Json -Depth 10 -Compress
$contenidoDatos = "window.CLARITY = { fechaActualizacion: `"$fechaTexto`", dias: 3, datos: $jsonDatos };"
$contenidoDatos | Out-File (Join-Path $CarpetaDatos "datos.js") -Encoding utf8

# --- Acumular historico (un punto por dia) ---
# Sumamos las sesiones reales (sin bots) y usuarios del bloque Traffic
$traffic = ($respuesta | Where-Object { $_.metricName -eq "Traffic" }).information
$sesiones = 0; $usuarios = 0; $bots = 0
foreach ($t in $traffic) {
    $sesiones += [int]$t.totalSessionCount
    $usuarios += [int]$t.distinctUserCount
    $bots     += [int]$t.totalBotSessionCount
}

$rutaHistJson = Join-Path $CarpetaDatos "historico.json"
$historico = @()
if (Test-Path $rutaHistJson) {
    $historico = @(Get-Content $rutaHistJson -Raw | ConvertFrom-Json)
}
# Si ya hay un punto de hoy, lo reemplazamos; si no, lo anadimos
$historico = @($historico | Where-Object { $_.fecha -ne $fechaDia })
$historico += [pscustomobject]@{ fecha = $fechaDia; sesiones = $sesiones; usuarios = $usuarios; bots = $bots }
$historico = @($historico | Sort-Object fecha)

$historico | ConvertTo-Json -Depth 5 | Out-File $rutaHistJson -Encoding utf8
$jsonHist = $historico | ConvertTo-Json -Depth 5 -Compress
# ConvertTo-Json de un solo elemento no genera array; forzamos corchetes
if ($historico.Count -eq 1) { $jsonHist = "[$jsonHist]" }
"window.CLARITY_HISTORICO = $jsonHist;" | Out-File (Join-Path $CarpetaDatos "historico.js") -Encoding utf8

# ============================================================
#  SEGUNDA LLAMADA: tráfico por Canal + Fuente (para la pagina de IA)
# ============================================================
$urlIA = "https://www.clarity.ms/export-data/api/v1/project-live-insights?numOfDays=3&dimension1=Channel&dimension2=Source"
Write-Host "Consultando trafico de IA (canal/fuente)..." -ForegroundColor Gray
try {
    $respIA = Invoke-RestMethod -Uri $urlIA -Headers $headers -Method Get -ErrorAction Stop
}
catch {
    $code = $null; if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    Write-Host "AVISO: no se pudo traer el trafico de IA (codigo $code). El resto de datos si se guardo." -ForegroundColor Yellow
    Escribir-Log "ERROR llamada IA (codigo $code): $($_.Exception.Message)"
    if (-not $Silencioso) { Read-Host "Pulsa ENTER para cerrar" }
    return
}

$trafficIA = ($respIA | Where-Object { $_.metricName -eq "Traffic" }).information

# Guardar datos-ia.js (lo que lee la pagina de IA)
$jsonIA = $trafficIA | ConvertTo-Json -Depth 8 -Compress
if ($trafficIA.Count -eq 1) { $jsonIA = "[$jsonIA]" }
"window.CLARITY_IA = { fechaActualizacion: `"$fechaTexto`", dias: 3, datos: $jsonIA };" |
    Out-File (Join-Path $CarpetaDatos "datos-ia.js") -Encoding utf8

# Clasificar y sumar las sesiones que vienen de IA (para el historico de IA)
$dominiosIA = @('chatgpt.com','openai','perplexity.ai','copilot.microsoft.com','gemini.google.com','claude.ai','bard.google.com','poe.com','you.com')
$sesionesIA = 0; $usuariosIA = 0; $sesionesTotal = 0
foreach ($row in $trafficIA) {
    $s = [int]$row.totalSessionCount
    $sesionesTotal += $s
    $esIA = $false
    if ($row.Channel -like 'Ai*' -or $row.Channel -like 'PaidAi*') { $esIA = $true }
    elseif ($dominiosIA -contains ([string]$row.Source).ToLower()) { $esIA = $true }
    if ($esIA) { $sesionesIA += $s; $usuariosIA += [int]$row.distinctUserCount }
}

# Acumular historico de IA (un punto por dia)
$rutaHistIA = Join-Path $CarpetaDatos "historico-ia.json"
$histIA = @()
if (Test-Path $rutaHistIA) { $histIA = @(Get-Content $rutaHistIA -Raw | ConvertFrom-Json) }
$histIA = @($histIA | Where-Object { $_.fecha -ne $fechaDia })
$histIA += [pscustomobject]@{ fecha = $fechaDia; sesionesIA = $sesionesIA; usuariosIA = $usuariosIA; sesionesTotal = $sesionesTotal }
$histIA = @($histIA | Sort-Object fecha)
$histIA | ConvertTo-Json -Depth 5 | Out-File $rutaHistIA -Encoding utf8
$jsonHistIA = $histIA | ConvertTo-Json -Depth 5 -Compress
if ($histIA.Count -eq 1) { $jsonHistIA = "[$jsonHistIA]" }
"window.CLARITY_IA_HISTORICO = $jsonHistIA;" | Out-File (Join-Path $CarpetaDatos "historico-ia.js") -Encoding utf8

# --- Registro de la ejecucion (util para la tarea automatica) ---
Escribir-Log ("OK  sesiones={0}  usuarios={1}  IA={2}/{3}" -f $sesiones, $usuarios, $sesionesIA, $sesionesTotal)

# --- Actualizar Search Console (Google), si esta conectado ---
$scriptGsc = Join-Path $PSScriptRoot "actualizar-gsc.ps1"
if ((Test-Path $scriptGsc) -and $config.google_oauth -and $config.google_oauth.refresh_token) {
    Write-Host "Actualizando Search Console..." -ForegroundColor Gray
    & $scriptGsc -Silencioso
}

# --- Actualizar Google Analytics, si esta conectado ---
$scriptGa = Join-Path $PSScriptRoot "actualizar-ga.ps1"
if ((Test-Path $scriptGa) -and $config.google_oauth -and $config.google_oauth.refresh_token -and $config.google_oauth.ga4_property_id) {
    Write-Host "Actualizando Google Analytics..." -ForegroundColor Gray
    & $scriptGa -Silencioso
}

# --- Actualizar HubSpot (leads), si esta configurado ---
$scriptHs = Join-Path $PSScriptRoot "actualizar-hubspot.ps1"
if ((Test-Path $scriptHs) -and $config.hubspot -and $config.hubspot.token) {
    Write-Host "Actualizando HubSpot (leads)..." -ForegroundColor Gray
    & $scriptHs -Silencioso
}

# --- Subir los datos nuevos a la web (GitHub Pages), si esta configurado ---
$scriptSubir = Join-Path $PSScriptRoot "subir-github.ps1"
$ghCfg = $config.github
if ((Test-Path $scriptSubir) -and $ghCfg -and $ghCfg.token -and $ghCfg.token -ne "PEGA_AQUI_TU_PAT") {
    Write-Host "Subiendo datos a la web..." -ForegroundColor Gray
    & $scriptSubir -SoloDatos -Silencioso
}

Write-Host ""
Write-Host "DATOS ACTUALIZADOS CORRECTAMENTE" -ForegroundColor Green
Write-Host ("Sesiones reales (3 dias): {0}  |  Usuarios: {1}  |  Bots filtrados: {2}" -f $sesiones, $usuarios, $bots)
Write-Host ("Sesiones desde IA: {0}  (de {1} totales)" -f $sesionesIA, $sesionesTotal)
Write-Host ("Fecha: {0}" -f $fechaTexto)
Write-Host ""
Write-Host "Abre 'dashboard.html' (general) o 'visibilidad-ia.html' (IA)." -ForegroundColor Yellow
Write-Host ""
