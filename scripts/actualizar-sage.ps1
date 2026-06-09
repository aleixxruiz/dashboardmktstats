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
$sel  = [uri]::EscapeDataString("Oppo_Opened,Oppo_Source,Oppo_Total,Oppo_Status")

Write-Host "=== Actualizando Sage CRM (oportunidades) ===" -ForegroundColor Cyan

# Importe a numero, aguantando formato espanol (1.234,56) e ingles (1,234.56)
function ImporteNum($t) {
    if ([string]::IsNullOrWhiteSpace($t)) { return 0.0 }
    $x = ([string]$t).Trim()
    $lc = $x.LastIndexOf(','); $ld = $x.LastIndexOf('.')
    if ($lc -gt $ld) { $x = $x.Replace('.', '').Replace(',', '.') }   # decimal = coma (es)
    else            { $x = $x.Replace(',', '') }                       # decimal = punto (en) o sin separador
    try { return [double]::Parse($x, [Globalization.CultureInfo]::InvariantCulture) } catch { return 0.0 }
}

$porMes = @{}; $porMesImp = @{}; $porOrigen = @{}; $porOrigenImp = @{}
$total = 0; $valorTotal = 0.0; $ganadas = 0; $perdidas = 0; $abiertas = 0
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
        $imp = ImporteNum $o.Oppo_Total
        $valorTotal += $imp

        $st = [string]$o.Oppo_Status
        if ($st -eq 'Won') { $ganadas++ } elseif ($st -eq 'Lost') { $perdidas++ } else { $abiertas++ }

        $op = [string]$o.Oppo_Opened
        if ($op.Length -ge 7) {
            $mes = $op.Substring(0, 7)
            if ($porMes.ContainsKey($mes)) { $porMes[$mes]++ } else { $porMes[$mes] = 1 }
            if ($porMesImp.ContainsKey($mes)) { $porMesImp[$mes] += $imp } else { $porMesImp[$mes] = $imp }
        }

        $org = [string]$o.Oppo_Source
        if ([string]::IsNullOrWhiteSpace($org)) { $org = "(sin origen)" }
        if ($porOrigen.ContainsKey($org)) { $porOrigen[$org]++ } else { $porOrigen[$org] = 1 }
        if ($porOrigenImp.ContainsKey($org)) { $porOrigenImp[$org] += $imp } else { $porOrigenImp[$org] = $imp }
    }
    Write-Host ("  ...$total / $totalResults oportunidades") -ForegroundColor DarkGray
    $start += 1000
    Start-Sleep -Milliseconds 150
} while ($start -le $totalResults)

$listaMes = @()
foreach ($k in ($porMes.Keys | Sort-Object)) {
    $listaMes += [pscustomobject]@{ nombre = $k; valor = $porMes[$k]; importe = [long][math]::Round($porMesImp[$k], 0) }
}
$listaOrigen = @()
foreach ($k in $porOrigen.Keys) {
    $listaOrigen += [pscustomobject]@{ nombre = $k; valor = $porOrigen[$k]; importe = [long][math]::Round($porOrigenImp[$k], 0) }
}
$listaOrigen = @($listaOrigen | Sort-Object valor -Descending)

$obj = @{
    fechaActualizacion = (Get-Date).ToString("dd/MM/yyyy HH:mm")
    total      = $total
    valorTotal = [long][math]::Round($valorTotal, 0)
    ganadas    = $ganadas
    perdidas   = $perdidas
    abiertas   = $abiertas
    porMes     = @($listaMes)
    porOrigen  = @($listaOrigen)
}
# Solo escribimos si hemos traido datos (si Sage no responde, conservamos el ultimo sage.js bueno)
if ($total -gt 0) {
    $json = $obj | ConvertTo-Json -Depth 6 -Compress
    "window.SAGE = $json;" | Out-File (Join-Path $CarpetaDatos "sage.js") -Encoding utf8
    Write-Host ""
    Write-Host ("OK  Oportunidades: {0} | valor total: {1} EUR | ganadas: {2} | perdidas: {3}" -f $total, $obj.valorTotal, $ganadas, $perdidas) -ForegroundColor Green
    Write-Host "Guardado en datos/sage.js"
} else {
    Write-Host "AVISO: 0 oportunidades (Sage no accesible?). NO se sobrescribe sage.js." -ForegroundColor Yellow
}