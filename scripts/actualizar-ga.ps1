# ============================================================
#  ACTUALIZAR GOOGLE ANALYTICS (Visibilidad en Web)
# ============================================================
#  Trae datos reales de GA4 y los guarda en datos/ga.js
#  para la pagina analytics.html.
# ============================================================
param([switch]$Silencioso)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Raiz = Split-Path -Parent $PSScriptRoot
$CarpetaDatos = Join-Path $Raiz "datos"
if (-not (Test-Path $CarpetaDatos)) { New-Item -ItemType Directory -Path $CarpetaDatos | Out-Null }
. (Join-Path $PSScriptRoot "lib-google.ps1")

$cfg = Get-Content (Join-Path $Raiz "config.json") -Raw | ConvertFrom-Json
$o = $cfg.google_oauth
if (-not $o -or [string]::IsNullOrWhiteSpace($o.refresh_token) -or [string]::IsNullOrWhiteSpace($o.ga4_property_id)) {
    Write-Host "Falta conexion con Google o el ID de propiedad GA4." -ForegroundColor Red
    if (-not $Silencioso) { Read-Host "ENTER para cerrar" }; return
}

Write-Host "=== Actualizando Google Analytics (propiedad $($o.ga4_property_id)) ===" -ForegroundColor Cyan
try {
    $tok = Get-GoogleAccessTokenOAuth -ClientId $o.client_id -ClientSecret $o.client_secret -RefreshToken $o.refresh_token
} catch {
    Write-Host ("Error al renovar el acceso: " + $_.Exception.Message) -ForegroundColor Red
    if (-not $Silencioso) { Read-Host "ENTER para cerrar" }; return
}
$h = @{ "Authorization" = "Bearer $tok"; "Content-Type" = "application/json" }
$prop = $o.ga4_property_id
$url = "https://analyticsdata.googleapis.com/v1beta/properties/$prop`:runReport"

function Reporte($obj) {
    $json = $obj | ConvertTo-Json -Depth 8
    return (Invoke-RestMethod -Uri $url -Headers $h -Method Post -Body $json).rows
}
function V($row, $i) { [double]$row.metricValues[$i].value }

# --- Totales periodo actual y anterior ---
$mTot = @(@{name="activeUsers"},@{name="sessions"},@{name="screenPageViews"},@{name="averageSessionDuration"})
$cur  = @(Reporte @{ dateRanges=@(@{startDate="28daysAgo"; endDate="yesterday"}); metrics=$mTot })
$prev = @(Reporte @{ dateRanges=@(@{startDate="56daysAgo"; endDate="29daysAgo"}); metrics=@(@{name="activeUsers"},@{name="sessions"}) })

$rc = if ($cur.Count -ge 1)  { $cur[0] }  else { $null }
$rp = if ($prev.Count -ge 1) { $prev[0] } else { $null }
$totales = @{
    usuarios     = if($rc){[int](V $rc 0)}else{0}
    sesiones     = if($rc){[int](V $rc 1)}else{0}
    vistas       = if($rc){[int](V $rc 2)}else{0}
    duracion     = if($rc){[int](V $rc 3)}else{0}
    usuariosPrev = if($rp){[int](V $rp 0)}else{0}
    sesionesPrev = if($rp){[int](V $rp 1)}else{0}
}

# --- Por dia (evolucion) ---
$porDia = @()
foreach ($row in @(Reporte @{ dateRanges=@(@{startDate="28daysAgo"; endDate="yesterday"}); dimensions=@(@{name="date"}); metrics=@(@{name="sessions"},@{name="activeUsers"}); orderBys=@(@{dimension=@{dimensionName="date"}}) })) {
    $d = $row.dimensionValues[0].value   # formato YYYYMMDD
    $fecha = $d.Substring(0,4)+"-"+$d.Substring(4,2)+"-"+$d.Substring(6,2)
    $porDia += [pscustomobject]@{ fecha=$fecha; sesiones=[int](V $row 0); usuarios=[int](V $row 1) }
}

# --- Helper para listas de 1 dimension ---
function Lista($dim, $metrica, $limite) {
    $out = @()
    foreach ($row in @(Reporte @{ dateRanges=@(@{startDate="28daysAgo"; endDate="yesterday"}); dimensions=@(@{name=$dim}); metrics=@(@{name=$metrica}); orderBys=@(@{metric=@{metricName=$metrica}; desc=$true}); limit=$limite })) {
        $out += [pscustomobject]@{ nombre=$row.dimensionValues[0].value; valor=[int](V $row 0) }
    }
    return $out
}
# --- Helper para listas de 2 dimensiones ---
function Lista2($dim1, $dim2, $metrica, $limite) {
    $out = @()
    foreach ($row in @(Reporte @{ dateRanges=@(@{startDate="28daysAgo"; endDate="yesterday"}); dimensions=@(@{name=$dim1},@{name=$dim2}); metrics=@(@{name=$metrica}); orderBys=@(@{metric=@{metricName=$metrica}; desc=$true}); limit=$limite })) {
        $out += [pscustomobject]@{ d1=$row.dimensionValues[0].value; d2=$row.dimensionValues[1].value; valor=[int](V $row 0) }
    }
    return $out
}

$canales      = Lista "sessionDefaultChannelGroup" "sessions" 8
$dispositivos = Lista "deviceCategory" "sessions" 5

# Paginas con su ruta (para enlaces) + titulo
$paginas = @()
foreach ($r in (Lista2 "pagePath" "pageTitle" "screenPageViews" 12)) {
    $paginas += [pscustomobject]@{ path=$r.d1; titulo=$r.d2; valor=$r.valor }
}
# Paises con codigo ISO (para el mapa) + nombre
$paises = @()
foreach ($r in (Lista2 "countryId" "country" "activeUsers" 250)) {
    if (-not [string]::IsNullOrWhiteSpace($r.d1)) {
        $paises += [pscustomobject]@{ code=$r.d1; nombre=$r.d2; valor=$r.valor }
    }
}

$obj = @{
    fechaActualizacion = (Get-Date).ToString("dd/MM/yyyy HH:mm")
    periodo = @{ ini = (Get-Date).AddDays(-28).ToString("dd/MM/yyyy"); fin = (Get-Date).AddDays(-1).ToString("dd/MM/yyyy") }
    totales = $totales
    porDia = $porDia
    canales = $canales
    paginas = $paginas
    paises = $paises
    dispositivos = $dispositivos
}
$json = $obj | ConvertTo-Json -Depth 8 -Compress
"window.GA = $json;" | Out-File (Join-Path $CarpetaDatos "ga.js") -Encoding utf8

Write-Host ("OK  usuarios={0}  sesiones={1}  vistas={2}" -f $totales.usuarios, $totales.sesiones, $totales.vistas) -ForegroundColor Green
Write-Host "Guardado en datos/ga.js"
