# ============================================================
#  SUBIR A GITHUB (sin git instalado, via API web de GitHub)
# ============================================================
#  Sube los archivos del dashboard a tu repositorio de GitHub
#  usando la API. Asi GitHub Pages muestra la version actualizada.
#
#  Parametros:
#   -SoloDatos : sube solo los archivos de datos (para la actualizacion diaria)
#   -Silencioso: sin pausas (para la tarea programada)
#
#  Lee la configuracion de GitHub desde config.json:
#   "github": { "usuario": "...", "repo": "...", "token": "PAT...", "rama": "main" }
# ============================================================
param([switch]$SoloDatos, [switch]$Silencioso)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$RaizProyecto = Split-Path -Parent $PSScriptRoot
$RutaConfig   = Join-Path $RaizProyecto "config.json"
$RutaLog      = Join-Path $RaizProyecto "datos\log-actualizaciones.txt"
function Log($t){ Add-Content -Path $RutaLog -Value ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "  " + $t) -Encoding utf8 }

if (-not (Test-Path $RutaConfig)) { Write-Host "No encuentro config.json" -ForegroundColor Red; return }
$cfg = Get-Content $RutaConfig -Raw | ConvertFrom-Json
$gh  = $cfg.github
if (-not $gh -or [string]::IsNullOrWhiteSpace($gh.token) -or $gh.token -like "PEGA_*") {
    Write-Host "Falta la configuracion de GitHub en config.json (usuario, repo, token)." -ForegroundColor Red
    if (-not $Silencioso) { Read-Host "Pulsa ENTER para cerrar" }
    return
}
$owner = $gh.usuario; $repo = $gh.repo
$rama  = if ($gh.rama) { $gh.rama } else { "main" }
$headers = @{
    "Authorization" = "Bearer $($gh.token)"
    "Accept"        = "application/vnd.github+json"
    "User-Agent"    = "ingesco-dashboard-uploader"
}

# Lista de archivos: (ruta local relativa  ->  ruta en el repositorio)
$todos = @(
    @{ local = "index.html";                 remoto = "index.html" },
    @{ local = "visibilidad-ia.html";        remoto = "visibilidad-ia.html" },
    @{ local = "analytics.html";             remoto = "analytics.html" },
    @{ local = "google-search.html";         remoto = "google-search.html" },
    @{ local = "leads.html";                 remoto = "leads.html" },
    @{ local = "faq.html";                   remoto = "faq.html" },
    @{ local = "peticiones.html";            remoto = "peticiones.html" },
    @{ local = "clientes-cualificados.html"; remoto = "clientes-cualificados.html" },
    @{ local = "directindustry.html";        remoto = "directindustry.html" },
    @{ local = "certificados.html";          remoto = "certificados.html" },
    @{ local = "assets\cert-plantilla.png";  remoto = "assets/cert-plantilla.png" },
    @{ local = "assets\logo-ingesco.png";    remoto = "assets/logo-ingesco.png" },
    @{ local = "assets\logo-clarity.png";    remoto = "assets/logo-clarity.png" },
    @{ local = "assets\logo-analytics.png";  remoto = "assets/logo-analytics.png" },
    @{ local = "assets\logo-search-console.svg"; remoto = "assets/logo-search-console.svg" },
    @{ local = "assets\logo-hubspot.png";    remoto = "assets/logo-hubspot.png" },
    @{ local = "assets\logo-sage.png";       remoto = "assets/logo-sage.png" },
    @{ local = "assets\direct-industry.png"; remoto = "assets/direct-industry.png" },
    @{ local = "assets\PDC 6.4.png";         remoto = "assets/PDC 6.4.png" },
    @{ local = "assets\previstorm.png";       remoto = "assets/previstorm.png" },
    @{ local = "assets\PararrayosE.png";      remoto = "assets/PararrayosE.png" },
    @{ local = "assets\favicon.ico.png";     remoto = "assets/favicon.ico.png" },
    @{ local = "assets\widget.js";           remoto = "assets/widget.js" },
    @{ local = "assets\gate.js";              remoto = "assets/gate.js" },
    @{ local = "datos\datos.js";             remoto = "datos/datos.js" },
    @{ local = "datos\datos-ia.js";          remoto = "datos/datos-ia.js" },
    @{ local = "datos\historico.js";         remoto = "datos/historico.js" },
    @{ local = "datos\historico-ia.js";      remoto = "datos/historico-ia.js" },
    @{ local = "datos\gsc.js";               remoto = "datos/gsc.js" },
    @{ local = "datos\ga.js";                remoto = "datos/ga.js" },
    @{ local = "datos\leads.js";             remoto = "datos/leads.js" },
    @{ local = "datos\citas-ia.js";          remoto = "datos/citas-ia.js" },
    @{ local = "datos\indexacion.js";        remoto = "datos/indexacion.js" },
    @{ local = "datos\sage.js";              remoto = "datos/sage.js" },
    @{ local = "datos\directindustry.js";    remoto = "datos/directindustry.js" },
    @{ local = "scripts\actualizar.ps1";         remoto = "scripts/actualizar.ps1" },
    @{ local = "scripts\subir-github.ps1";       remoto = "scripts/subir-github.ps1" },
    @{ local = "scripts\lib-google.ps1";         remoto = "scripts/lib-google.ps1" },
    @{ local = "scripts\actualizar-gsc.ps1";     remoto = "scripts/actualizar-gsc.ps1" },
    @{ local = "scripts\actualizar-ga.ps1";      remoto = "scripts/actualizar-ga.ps1" },
    @{ local = "scripts\actualizar-hubspot.ps1"; remoto = "scripts/actualizar-hubspot.ps1" },
    @{ local = "scripts\actualizar-sage.ps1";    remoto = "scripts/actualizar-sage.ps1" },
    @{ local = "scripts\actualizar-citas.ps1";   remoto = "scripts/actualizar-citas.ps1" },
    @{ local = "scripts\actualizar-indexacion.ps1"; remoto = "scripts/actualizar-indexacion.ps1" },
    @{ local = "scripts\cloudflare-worker.js";       remoto = "scripts/cloudflare-worker.js" }
)
$soloDatosLista = $todos | Where-Object { $_.remoto -like "datos/*" }
# La indexacion la gestiona SOLO la nube (1/semana). En local no la subimos para no pisar el dato bueno.
if ($env:GITHUB_ACTIONS -ne 'true') {
    $soloDatosLista = $soloDatosLista | Where-Object { $_.remoto -ne 'datos/indexacion.js' }
}
$lista = if ($SoloDatos) { $soloDatosLista } else { $todos }

Write-Host ""
Write-Host "=== Subiendo a GitHub: $owner/$repo (rama $rama) ===" -ForegroundColor Cyan

$ok = 0; $fallos = 0
foreach ($item in $lista) {
    $rutaLocal = Join-Path $RaizProyecto $item.local
    if (-not (Test-Path $rutaLocal)) { Write-Host "  (omito, no existe) $($item.local)" -ForegroundColor DarkGray; continue }

    $bytes   = [System.IO.File]::ReadAllBytes($rutaLocal)
    $base64  = [Convert]::ToBase64String($bytes)
    $apiUrl  = "https://api.github.com/repos/$owner/$repo/contents/$($item.remoto)"

    # Obtener el SHA actual si el archivo ya existe (necesario para actualizar)
    $sha = $null
    try {
        $existente = Invoke-RestMethod -Uri "$apiUrl`?ref=$rama" -Headers $headers -Method Get -ErrorAction Stop
        $sha = $existente.sha
    } catch { $sha = $null }

    $cuerpo = @{
        message = "Actualizacion dashboard ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
        content = $base64
        branch  = $rama
    }
    if ($sha) { $cuerpo.sha = $sha }
    $json = $cuerpo | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Put -Body $json -ContentType "application/json" -ErrorAction Stop | Out-Null
        Write-Host ("  OK  {0}" -f $item.remoto) -ForegroundColor Green
        $ok++
    } catch {
        $code = $null; if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        Write-Host ("  FALLO ({0})  {1}  -> {2}" -f $code, $item.remoto, $_.Exception.Message) -ForegroundColor Red
        $fallos++
    }
}

Write-Host ""
Write-Host ("Subida terminada: {0} correctos, {1} fallos." -f $ok, $fallos) -ForegroundColor Cyan
Log ("GITHUB subida: $ok ok, $fallos fallos" + $(if($SoloDatos){" (solo datos)"}else{" (completa)"}))
if ($fallos -gt 0 -and -not $Silencioso -and [Environment]::UserInteractive) { Read-Host "Pulsa ENTER para cerrar" }
