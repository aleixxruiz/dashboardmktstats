# ============================================================
#  ACTUALIZAR INDEXACION (Google Search Console - URL Inspection)
# ============================================================
#  Recorre las URLs de los sitemaps e inspecciona cada una para
#  saber si esta INDEXADA o NO en Google. Guarda datos/indexacion.js
#
#  Limite: 2000 inspecciones/dia por propiedad. El sitio tiene ~1000.
#  Por eso se ejecuta SOLO en la nube (no en la tarea local) para no
#  duplicar; con -Forzar se puede lanzar a mano para probar.
# ============================================================
param([switch]$Silencioso, [switch]$Forzar)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Raiz = Split-Path -Parent $PSScriptRoot
$CarpetaDatos = Join-Path $Raiz "datos"
if (-not (Test-Path $CarpetaDatos)) { New-Item -ItemType Directory -Path $CarpetaDatos | Out-Null }
$RutaSalida = Join-Path $CarpetaDatos "indexacion.js"
. (Join-Path $PSScriptRoot "lib-google.ps1")

$cfg = Get-Content (Join-Path $Raiz "config.json") -Raw | ConvertFrom-Json
$o = $cfg.google_oauth
if (-not $o -or [string]::IsNullOrWhiteSpace($o.refresh_token)) { Write-Host "Falta conexion con Google." -ForegroundColor Red; return }

# Guarda de antiguedad: si ya se hizo hace menos de 6 dias, no repetir (salvo -Forzar).
# (La indexacion cambia despacio y la inspeccion es lenta: con semanal sobra.)
if (-not $Forzar -and (Test-Path $RutaSalida)) {
    $edad = (Get-Date) - (Get-Item $RutaSalida).LastWriteTime
    if ($edad.TotalDays -lt 6) { Write-Host "Indexacion reciente ($([int]$edad.TotalDays)d); se omite." -ForegroundColor DarkGray; return }
}

$site = $o.gsc_site
$tok = Get-GoogleAccessTokenOAuth -ClientId $o.client_id -ClientSecret $o.client_secret -RefreshToken $o.refresh_token
$h = @{ "Authorization"="Bearer $tok"; "Content-Type"="application/json" }
$enc = [Uri]::EscapeDataString($site)

Write-Host "=== Inspeccionando indexacion en Google ($site) ===" -ForegroundColor Cyan

# 1) Recoger URLs de todos los sitemaps
$urls = @()
try {
    $sm = Invoke-RestMethod -Uri "https://www.googleapis.com/webmasters/v3/sites/$enc/sitemaps" -Headers $h -Method Get
    foreach ($s in $sm.sitemap) {
        try {
            $xml = [xml]((Invoke-WebRequest -Uri $s.path -UseBasicParsing -TimeoutSec 25).Content)
            foreach ($u in $xml.urlset.url) { if ($u.loc) { $urls += [string]$u.loc } }
        } catch { Write-Host ("  No pude leer sitemap " + $s.path) -ForegroundColor DarkYellow }
    }
} catch { Write-Host ("Error al listar sitemaps: " + $_.Exception.Message) -ForegroundColor Red; return }
$urls = $urls | Select-Object -Unique
Write-Host ("URLs a inspeccionar: " + $urls.Count)
if ($urls.Count -eq 0) { return }

# 2) Inspeccionar cada URL
$indexadas = @(); $noIndex = @{}   # motivo -> lista de urls
$hecho = 0; $abortado = $false
foreach ($u in $urls) {
    $body = @{ inspectionUrl = $u; siteUrl = $site } | ConvertTo-Json
    try {
        $r = (Invoke-RestMethod -Uri "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect" -Headers $h -Method Post -Body $body -ErrorAction Stop).inspectionResult.indexStatusResult
        $cov = [string]$r.coverageState
        $esIndexada = ($cov -match 'indexed' -and $cov -notmatch 'not indexed')
        if ($esIndexada) { $indexadas += $u }
        else {
            $motivo = if ([string]::IsNullOrWhiteSpace($cov)) { "Sin determinar" } else { $cov }
            if (-not $noIndex.ContainsKey($motivo)) { $noIndex[$motivo] = @() }
            $noIndex[$motivo] += $u
        }
        $hecho++
    } catch {
        $code = $null; if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        if ($code -eq 429) { Write-Host "Limite diario de inspecciones alcanzado; se detiene." -ForegroundColor Yellow; $abortado = $true; break }
        # otros errores: omitir esa URL
    }
    if ($hecho % 100 -eq 0) { Write-Host ("  ...$hecho inspeccionadas") -ForegroundColor DarkGray }
    Start-Sleep -Milliseconds 110
}

# Si se aborto por limite y ya habia un archivo previo, lo conservamos
if ($abortado -and (Test-Path $RutaSalida) -and $hecho -lt ($urls.Count * 0.5)) {
    Write-Host "Inspeccion incompleta; se conserva el archivo anterior." -ForegroundColor Yellow
    return
}

# 3) Construir salida
$motivos = @()
foreach ($k in $noIndex.Keys) { $motivos += [pscustomobject]@{ motivo=$k; total=$noIndex[$k].Count; urls=@($noIndex[$k]) } }
$motivos = @($motivos | Sort-Object total -Descending)
$totalNo = ($motivos | Measure-Object total -Sum).Sum

$obj = @{
    fechaActualizacion = (Get-Date).ToString("dd/MM/yyyy HH:mm")
    total       = $hecho
    indexadas   = $indexadas.Count
    noIndexadas = [int]$totalNo
    listaIndexadas = @($indexadas)
    motivos     = $motivos
}
$json = $obj | ConvertTo-Json -Depth 6 -Compress
"window.INDEX = $json;" | Out-File $RutaSalida -Encoding utf8

Write-Host ("OK  Inspeccionadas: {0}  |  Indexadas: {1}  |  No indexadas: {2}" -f $hecho, $indexadas.Count, $totalNo) -ForegroundColor Green