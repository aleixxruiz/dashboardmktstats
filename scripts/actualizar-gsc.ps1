# ============================================================
#  ACTUALIZAR SEARCH CONSOLE  (Visibilidad en Google)
# ============================================================
#  Trae datos reales de Google Search Console y los guarda en
#  datos/gsc.js para la pagina google-search.html.
# ============================================================
param([switch]$Silencioso)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Raiz = Split-Path -Parent $PSScriptRoot
$CarpetaDatos = Join-Path $Raiz "datos"
if (-not (Test-Path $CarpetaDatos)) { New-Item -ItemType Directory -Path $CarpetaDatos | Out-Null }
. (Join-Path $PSScriptRoot "lib-google.ps1")

$cfg = Get-Content (Join-Path $Raiz "config.json") -Raw | ConvertFrom-Json
$o = $cfg.google_oauth
if (-not $o -or [string]::IsNullOrWhiteSpace($o.refresh_token)) {
    Write-Host "Falta la conexion con Google (ejecuta autorizar-google.ps1)." -ForegroundColor Red
    if (-not $Silencioso) { Read-Host "ENTER para cerrar" }; return
}
$site = if ($o.gsc_site) { $o.gsc_site } else { "https://www.ingesco.com/" }

Write-Host "=== Actualizando Search Console ($site) ===" -ForegroundColor Cyan
try {
    $tok = Get-GoogleAccessTokenOAuth -ClientId $o.client_id -ClientSecret $o.client_secret -RefreshToken $o.refresh_token
} catch {
    Write-Host ("Error al renovar el acceso: " + $_.Exception.Message) -ForegroundColor Red
    if (-not $Silencioso) { Read-Host "ENTER para cerrar" }; return
}
$h = @{ "Authorization" = "Bearer $tok"; "Content-Type" = "application/json" }
$enc = [Uri]::EscapeDataString($site)
$urlQ = "https://www.googleapis.com/webmasters/v3/sites/$enc/searchAnalytics/query"

# Search Console publica con ~3 dias de retraso
$fin     = (Get-Date).AddDays(-3)
$ini     = $fin.AddDays(-27)            # 28 dias
$finPrev = $ini.AddDays(-1)
$iniPrev = $finPrev.AddDays(-27)        # 28 dias anteriores (comparativa)

function Consultar($desde, $hasta, $dims, $limite) {
    $b = @{ startDate = $desde.ToString("yyyy-MM-dd"); endDate = $hasta.ToString("yyyy-MM-dd") }
    if ($dims) { $b.dimensions = $dims }
    if ($limite) { $b.rowLimit = $limite }
    $json = $b | ConvertTo-Json
    return (Invoke-RestMethod -Uri $urlQ -Headers $h -Method Post -Body $json).rows
}

# Totales periodo actual y anterior (forzamos lista con @() para indexar bien)
$tot  = @(Consultar $ini $fin $null 1)
$totP = @(Consultar $iniPrev $finPrev $null 1)
$rTot  = if ($tot.Count -ge 1)  { $tot[0] }  else { $null }
$rTotP = if ($totP.Count -ge 1) { $totP[0] } else { $null }

$totales = @{
    clicks      = if ($rTot)  { [int]$rTot.clicks }       else { 0 }
    impressions = if ($rTot)  { [int]$rTot.impressions }  else { 0 }
    ctr         = if ($rTot)  { [math]::Round($rTot.ctr * 100, 2) }   else { 0 }
    position    = if ($rTot)  { [math]::Round($rTot.position, 1) }    else { 0 }
    clicksPrev      = if ($rTotP) { [int]$rTotP.clicks }      else { 0 }
    impressionsPrev = if ($rTotP) { [int]$rTotP.impressions } else { 0 }
}

# Por dia (evolucion real)
$porDia = @()
foreach ($row in (Consultar $ini $fin @("date") 1000)) {
    $porDia += [pscustomobject]@{ fecha = $row.keys[0]; clicks = [int]$row.clicks; impressions = [int]$row.impressions }
}
$porDia = @($porDia | Sort-Object fecha)

# Top consultas y top paginas
function MapFilas($rows) {
    $out = @()
    foreach ($r in $rows) {
        $out += [pscustomobject]@{
            clave = $r.keys[0]; clicks = [int]$r.clicks; impressions = [int]$r.impressions
            ctr = [math]::Round($r.ctr * 100, 1); position = [math]::Round($r.position, 1)
        }
    }
    return $out
}
$queries = MapFilas (Consultar $ini $fin @("query") 15)
$paginas = MapFilas (Consultar $ini $fin @("page") 10)

$obj = @{
    fechaActualizacion = (Get-Date).ToString("dd/MM/yyyy HH:mm")
    sitio    = $site
    periodo  = @{ ini = $ini.ToString("dd/MM/yyyy"); fin = $fin.ToString("dd/MM/yyyy") }
    totales  = $totales
    porDia   = $porDia
    queries  = $queries
    paginas  = $paginas
}
$json = $obj | ConvertTo-Json -Depth 8 -Compress
"window.GSC = $json;" | Out-File (Join-Path $CarpetaDatos "gsc.js") -Encoding utf8

Write-Host ("OK  clics={0}  impresiones={1}  CTR={2}%  pos={3}" -f $totales.clicks, $totales.impressions, $totales.ctr, $totales.position) -ForegroundColor Green
Write-Host "Guardado en datos/gsc.js"
