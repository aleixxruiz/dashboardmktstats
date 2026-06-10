# ============================================================
#  ACTUALIZAR SAGE CRM (Oportunidades)
# ------------------------------------------------------------
#  Lee las oportunidades de Sage CRM via API SData REST (Basic Auth)
#  y las AGREGA por mes (fecha de apertura) y por origen.
#  Guarda solo numeros en datos/sage.js (ningun dato personal).
#
#  config.json -> "sage": { "url": "...", "usuario": "...", "password": "..." }
# ============================================================
param([switch]$Silencioso)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Raiz = Split-Path -Parent $PSScriptRoot
$CarpetaDatos = Join-Path $Raiz "datos"
if (-not (Test-Path $CarpetaDatos)) { New-Item -ItemType Directory -Path $CarpetaDatos | Out-Null }

$cfg = Get-Content (Join-Path $Raiz "config.json") -Raw | ConvertFrom-Json
$s = $cfg.sage
if (-not $s -or [string]::IsNullOrWhiteSpace($s.usuario) -or [string]::IsNullOrWhiteSpace($s.password)) {
    Write-Host "(No hay configuracion 'sage' en config.json; se omite.)" -ForegroundColor DarkGray
    return
}

$auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s.usuario + ":" + $s.password))
$H = @{ Accept = "application/json"; Authorization = "Basic $auth" }
# SData REST (instalacion crm2j). Base independiente de config.sage.url para no liarla.
$root = "https://dena-fss.ardicloud.com/sdata/crm2j/sagecrm2/-"
$sel  = [uri]::EscapeDataString("Oppo_Opened,Oppo_Source,Oppo_Status")

Write-Host "=== Actualizando Sage CRM (oportunidades) ===" -ForegroundColor Cyan

# Limpia la etiqueta de sector: "500 - ALMACEN MAT. ELECTR." -> "ALMACEN MAT. ELECTR."
function LimpiaSector($txt) {
    if ([string]::IsNullOrWhiteSpace($txt)) { return $null }
    $t = ([string]$txt).Trim()
    $t2 = ($t -replace '^\s*\S+\s*-\s*', '').Trim()
    if ($t2 -eq '') { return $t }   # si al quitar el codigo queda vacio, dejar original
    return $t2
}

# Carga una familia de traducciones (codigo -> etiqueta ES) de Custom_Captions
function CargarFamilia($fam) {
    $m = @{}
    try {
        $w = [uri]::EscapeDataString("Capt_Family eq '$fam'")
        $r = Invoke-RestMethod -Uri "$root/Custom_Captions?where=$w&count=1000&startIndex=1" -Headers $H -Method Get -TimeoutSec 120
        foreach ($c in @($r.'$resources')) {
            $cod = [string]$c.Capt_Code; $lab = ([string]$c.Capt_ES).Trim()
            if (-not [string]::IsNullOrWhiteSpace($cod) -and -not [string]::IsNullOrWhiteSpace($lab) -and $lab -ne '--') { $m[$cod] = $lab }
        }
    } catch {}
    return $m
}

# Etiqueta de origen tal como aparece HOY en el desplegable del CRM (familia Comp_Source).
# Lo que no este en esa lista (codigos antiguos retirados) se agrupa en "Otros (antiguos)".
function EtiquetaOrigen($code) {
    if ([string]::IsNullOrWhiteSpace($code) -or $code -eq '(sin origen)') { return 'Sin origen' }
    if ($script:srcMap -and $script:srcMap.ContainsKey($code)) { return $script:srcMap[$code] }
    return 'Otros (antiguos)'
}

$porMes = @{}; $porOrigen = @{}
$total = 0; $ganadas = 0; $perdidas = 0; $abiertas = 0
$start = 1; $totalResults = 0

do {
    $u = "$root/Opportunity?select=$sel&count=1000&startIndex=$start"
    try {
        $r = Invoke-RestMethod -Uri $u -Headers $H -Method Get -TimeoutSec 120 -ErrorAction Stop
    } catch {
        $code = $null; if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        Write-Host ("Error (start=$start, codigo $code): " + $_.Exception.Message) -ForegroundColor Red
        break
    }
    if ($totalResults -eq 0) { $totalResults = [int]$r.'$totalResults' }
    foreach ($o in @($r.'$resources')) {
        $total++

        $st = [string]$o.Oppo_Status
        if ($st -eq 'Won') { $ganadas++ } elseif ($st -eq 'Lost') { $perdidas++ } else { $abiertas++ }

        $op = [string]$o.Oppo_Opened
        if ($op.Length -ge 7) {
            $mes = $op.Substring(0, 7)
            if ($porMes.ContainsKey($mes)) { $porMes[$mes]++ } else { $porMes[$mes] = 1 }
        }

        $org = [string]$o.Oppo_Source
        if ([string]::IsNullOrWhiteSpace($org)) { $org = "(sin origen)" }
        if ($porOrigen.ContainsKey($org)) { $porOrigen[$org]++ } else { $porOrigen[$org] = 1 }
    }
    Write-Host ("  ...$total / $totalResults oportunidades") -ForegroundColor DarkGray
    $start += 1000
    Start-Sleep -Milliseconds 150
} while ($start -le $totalResults)

$listaMes = @()
foreach ($k in ($porMes.Keys | Sort-Object)) {
    $listaMes += [pscustomobject]@{ nombre = $k; valor = $porMes[$k] }
}
# Traducciones de origen: SOLO la lista actual del CRM (desplegable Comp_Source)
$srcMap = CargarFamilia 'Comp_Source'
Write-Host ("Traducciones de origen (Comp_Source): {0}" -f $srcMap.Count) -ForegroundColor DarkGray

# Agrupamos por la etiqueta del CRM (varios codigos pueden compartir nombre)
$origAgg = @{}
foreach ($k in $porOrigen.Keys) {
    $lab = EtiquetaOrigen $k
    if ($origAgg.ContainsKey($lab)) { $origAgg[$lab] += $porOrigen[$k] } else { $origAgg[$lab] = $porOrigen[$k] }
}
$listaOrigen = @()
foreach ($k in $origAgg.Keys) {
    $listaOrigen += [pscustomobject]@{ nombre = $k; valor = $origAgg[$k] }
}
$listaOrigen = @($listaOrigen | Sort-Object valor -Descending)

# ============================================================
#  EMPRESAS POR SECTOR (entidad Company, campo comp_CodigoSector)
# ============================================================
Write-Host "=== Empresas por sector ===" -ForegroundColor Cyan
# 1) Mapa de traduccion codigo -> nombre (Custom_Captions, familia comp_CodigoSector)
$capMap = @{}
try {
    $wf = [uri]::EscapeDataString("Capt_Family eq 'comp_CodigoSector'")
    $rc = Invoke-RestMethod -Uri "$root/Custom_Captions?where=$wf&count=1000&startIndex=1" -Headers $H -Method Get -TimeoutSec 120
    foreach ($c in @($rc.'$resources')) {
        $cod = [string]$c.Capt_Code
        if (-not [string]::IsNullOrWhiteSpace($cod)) { $capMap[$cod] = (LimpiaSector $c.Capt_ES) }
    }
    Write-Host ("  Traducciones de sector cargadas: {0}" -f $capMap.Count) -ForegroundColor DarkGray
} catch {
    Write-Host "  (No pude leer las traducciones de sector; se usaran los codigos.)" -ForegroundColor Yellow
}

# 2) Escaneo de empresas con sector (solo se lee el codigo de sector)
$porSector = @{}; $empresasSec = 0; $startC = 1; $totC = 0
$selC = [uri]::EscapeDataString("comp_CodigoSector")
$whC  = [uri]::EscapeDataString("comp_CodigoSector ne '0' and comp_CodigoSector ne ''")
do {
    $uc = "$root/Company?where=$whC&select=$selC&count=1000&startIndex=$startC"
    try {
        $rcomp = Invoke-RestMethod -Uri $uc -Headers $H -Method Get -TimeoutSec 120 -ErrorAction Stop
    } catch {
        Write-Host ("  Error leyendo empresas (start=$startC): " + $_.Exception.Message) -ForegroundColor Red
        break
    }
    if ($totC -eq 0) { $totC = [int]$rcomp.'$totalResults' }
    foreach ($c in @($rcomp.'$resources')) {
        $cod = [string]$c.comp_CodigoSector
        if ([string]::IsNullOrWhiteSpace($cod) -or $cod -eq '0') { continue }
        $lab = if ($capMap.ContainsKey($cod)) { $capMap[$cod] } else { "Otros" }
        if ([string]::IsNullOrWhiteSpace($lab)) { $lab = "Otros" }
        if ($porSector.ContainsKey($lab)) { $porSector[$lab]++ } else { $porSector[$lab] = 1 }
        $empresasSec++
    }
    if ($startC % 20000 -eq 1) { Write-Host ("  ...$empresasSec / $totC empresas") -ForegroundColor DarkGray }
    $startC += 1000
    Start-Sleep -Milliseconds 120
} while ($startC -le $totC)
Write-Host ("  Empresas con sector procesadas: $empresasSec / $totC") -ForegroundColor Green

# 3) Top sectores; el resto se agrupa en "Otros"
$ordSec = @($porSector.GetEnumerator() | Sort-Object Value -Descending)
$listaSector = @(); $topN = 12; $i = 0; $restoVal = 0
foreach ($e in $ordSec) {
    if ($i -lt $topN -and $e.Key -ne 'Otros') { $listaSector += [pscustomobject]@{ nombre = $e.Key; valor = $e.Value }; $i++ }
    else { $restoVal += $e.Value }
}
if ($restoVal -gt 0) { $listaSector += [pscustomobject]@{ nombre = 'Otros'; valor = $restoVal } }

$obj = @{
    fechaActualizacion = (Get-Date).ToString("dd/MM/yyyy HH:mm")
    total      = $total
    ganadas    = $ganadas
    perdidas   = $perdidas
    abiertas   = $abiertas
    porMes     = @($listaMes)
    porOrigen  = @($listaOrigen)
    porSector  = @($listaSector)
    empresasConSector = $empresasSec
}
# Solo escribimos si hemos traido datos (si Sage no responde, conservamos el ultimo sage.js bueno)
if ($total -gt 0) {
    $json = $obj | ConvertTo-Json -Depth 6 -Compress
    "window.SAGE = $json;" | Out-File (Join-Path $CarpetaDatos "sage.js") -Encoding utf8
    Write-Host ""
    Write-Host ("OK  Oportunidades: {0} | ganadas: {1} | perdidas: {2} | en curso: {3}" -f $total, $ganadas, $perdidas, $abiertas) -ForegroundColor Green
    Write-Host "Guardado en datos/sage.js"
} else {
    Write-Host "AVISO: 0 oportunidades (Sage no accesible?). NO se sobrescribe sage.js." -ForegroundColor Yellow
}