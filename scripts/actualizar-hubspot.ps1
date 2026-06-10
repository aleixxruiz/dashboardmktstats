# ============================================================
#  ACTUALIZAR HUBSPOT (Captacion de Leads)
# ============================================================
#  Recorre TODOS los contactos de HubSpot y los AGREGA (cuenta)
#  por origen, por mes y por etapa. Guarda solo numeros en
#  datos/leads.js (ningun dato personal: ni nombres ni emails).
# ============================================================
param([switch]$Silencioso)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Raiz = Split-Path -Parent $PSScriptRoot
$CarpetaDatos = Join-Path $Raiz "datos"
if (-not (Test-Path $CarpetaDatos)) { New-Item -ItemType Directory -Path $CarpetaDatos | Out-Null }

$cfg = Get-Content (Join-Path $Raiz "config.json") -Raw | ConvertFrom-Json
$hs = $cfg.hubspot
if (-not $hs -or [string]::IsNullOrWhiteSpace($hs.token)) {
    Write-Host "Falta el token de HubSpot en config.json." -ForegroundColor Red
    if (-not $Silencioso) { Read-Host "ENTER para cerrar" }; return
}
$h = @{ Authorization = "Bearer $($hs.token)"; "Content-Type" = "application/json" }

Write-Host "=== Actualizando HubSpot (leads) ===" -ForegroundColor Cyan

# Mapa de etapas del ciclo (traduce IDs personalizados a su nombre real)
$etiquetasEtapa = @{}
try {
    $pl = Invoke-RestMethod -Uri "https://api.hubapi.com/crm/v3/properties/contacts/lifecyclestage" -Headers $h -Method Get -ErrorAction Stop
    foreach ($op in $pl.options) { $etiquetasEtapa[[string]$op.value] = $op.label }
} catch { Write-Host "(aviso: no pude traer las etiquetas de etapa)" -ForegroundColor DarkYellow }

$props = "createdate,hs_analytics_source,lifecyclestage,first_conversion_event_name,ip_country_code"
$base  = "https://api.hubapi.com/crm/v3/objects/contacts?limit=100&properties=$props&archived=false"

# Clasifica el formulario por el que llego el contacto (primera conversion)
# El valor real es lo que va despues de los ultimos ": " en el nombre del evento.
function ClasificarFormulario($raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $name = $raw
    $idx = $raw.LastIndexOf(": ")
    if ($idx -ge 0) { $name = $raw.Substring($idx + 2).Trim() }
    $l = $name.ToLower()
    if ($l -like "*registro calculus*") { return "Registro Calculus" }
    if ($l -like "*prefooter es*") { return "Web prefooter ES" }
    if ($l -like "*prefooter en*") { return "Web prefooter EN" }
    if ($l -like "*prefooter pt*") { return "Web prefooter PT" }
    if ($l -like "*prefooter fr*") { return "Web prefooter FR" }
    if ($l -like "*prefooter br*") { return "Web prefooter BR" }
    if ($l -like "*webinar*")      { return "Formulario Webinar" }
    return $name
}

# Detecta el idioma de un formulario por marcadores explicitos de su nombre.
# Devuelve un CODIGO (ES/EN/FR/PT/OTROS); la pagina lo traduce (asi evitamos acentos en el .ps1).
function DetectarIdioma($name) {
    $l = ([string]$name).ToLower()
    if ($l -like "*prefooter es*" -or $l -like "*espa*") { return "ES" }
    if ($l -like "*prefooter en*" -or $l -like "*ingl*" -or $l -like "*_en") { return "EN" }
    if ($l -like "*prefooter fr*" -or $l -like "*franc*") { return "FR" }
    if ($l -like "*prefooter pt*" -or $l -like "*prefooter br*" -or $l -like "*microsite pt*") { return "PT" }
    return "OTROS"
}

# Agrupa un formulario en su categoria (igual que el bloque "Como llegaron los contactos")
function GrupoFormulario($form) {
    if ([string]::IsNullOrWhiteSpace($form)) { return "Sin formulario" }
    $l = $form.ToLower()
    if ($l -like "*alculus*")           { return "Calculus" }
    if ($l -like "*prefooter*")         { return "Prefooter" }
    if ($form -eq "Formulario Webinar") { return "Formulario Webinar" }
    return "Otros"
}

# Acumuladores
$porFuente = @{}; $porMes = @{}; $porEtapa = @{}; $porFormulario = @{}; $sinFormFuente = @{}; $porMesForm = @{}; $porPais = @{}
$total = 0; $nuevos30 = 0; $nuevosPrev30 = 0; $conFormulario = 0
$hoy = [datetime]::UtcNow
$h30 = $hoy.AddDays(-30); $h60 = $hoy.AddDays(-60)

$after = $null; $pagina = 0
do {
    $url = $base
    if ($after) { $url += "&after=$after" }
    try {
        $r = Invoke-RestMethod -Uri $url -Headers $h -Method Get -ErrorAction Stop
    } catch {
        $code = $null; if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        if ($code -eq 429) { Start-Sleep -Seconds 10; continue }   # rate limit: esperar y reintentar
        Write-Host ("Error en la pagina $pagina (codigo $code): " + $_.Exception.Message) -ForegroundColor Red
        break
    }

    foreach ($c in $r.results) {
        $p = $c.properties
        $total++

        $src = $p.hs_analytics_source; if ([string]::IsNullOrWhiteSpace($src)) { $src = "DESCONOCIDO" }
        if ($porFuente.ContainsKey($src)) { $porFuente[$src]++ } else { $porFuente[$src] = 1 }

        $cc = $p.ip_country_code
        if (-not [string]::IsNullOrWhiteSpace($cc)) {
            $cc = $cc.ToUpper()
            if ($porPais.ContainsKey($cc)) { $porPais[$cc]++ } else { $porPais[$cc] = 1 }
        }

        $et = $p.lifecyclestage
        if ([string]::IsNullOrWhiteSpace($et)) { $etLabel = "Sin etapa" }
        elseif ($etiquetasEtapa.ContainsKey([string]$et)) { $etLabel = $etiquetasEtapa[[string]$et] }
        else { $etLabel = $et }
        if ($porEtapa.ContainsKey($etLabel)) { $porEtapa[$etLabel]++ } else { $porEtapa[$etLabel] = 1 }

        $form = ClasificarFormulario $p.first_conversion_event_name
        $grupo = if ($form) { GrupoFormulario $form } else { "Sin formulario" }

        if (-not [string]::IsNullOrWhiteSpace($p.createdate)) {
            try {
                $cd = [datetimeoffset]::Parse($p.createdate).UtcDateTime
                $mes = $cd.ToString("yyyy-MM")
                if ($porMes.ContainsKey($mes)) { $porMes[$mes]++ } else { $porMes[$mes] = 1 }
                if (-not $porMesForm.ContainsKey($mes)) { $porMesForm[$mes] = @{} }
                if ($porMesForm[$mes].ContainsKey($grupo)) { $porMesForm[$mes][$grupo]++ } else { $porMesForm[$mes][$grupo] = 1 }
                if ($cd -ge $h30) { $nuevos30++ } elseif ($cd -ge $h60) { $nuevosPrev30++ }
            } catch {}
        }

        if ($form) {
            $conFormulario++
            if ($porFormulario.ContainsKey($form)) { $porFormulario[$form]++ } else { $porFormulario[$form] = 1 }
        } else {
            if ($sinFormFuente.ContainsKey($src)) { $sinFormFuente[$src]++ } else { $sinFormFuente[$src] = 1 }
        }
    }

    $after = $r.paging.next.after
    $pagina++
    if ($pagina % 10 -eq 0) { Write-Host ("  ...$total contactos procesados") -ForegroundColor DarkGray }
    Start-Sleep -Milliseconds 110
} while ($after)

# Convertir acumuladores a listas ordenadas
function Lista($tabla, $ordenarPorValor) {
    $arr = @()
    foreach ($k in $tabla.Keys) { $arr += [pscustomobject]@{ nombre = $k; valor = $tabla[$k] } }
    if ($ordenarPorValor) { return @($arr | Sort-Object valor -Descending) }
    else { return @($arr | Sort-Object nombre) }
}

# Lista de formularios agrupada en 3 desplegables + Webinar suelto:
#  - "Calculus"  -> todos los formularios de Calculus (detalle)
#  - "Prefooter" -> todos los Web prefooter por idioma (detalle)
#  - "Formulario Webinar" -> barra propia (captacion directa)
#  - "Otros"     -> el resto (BIM, evaluacion proveedores, etc.) (detalle)
$calcDet = @(); $preDet = @(); $otrosDet = @()
$calcTot = 0; $preTot = 0; $otrosTot = 0; $webinarTot = 0
foreach ($k in $porFormulario.Keys) {
    $v = $porFormulario[$k]
    if ($k -like "*alculus*")        { $calcDet  += [pscustomobject]@{ nombre=$k; valor=$v }; $calcTot += $v }
    elseif ($k -like "*prefooter*")  { $preDet   += [pscustomobject]@{ nombre=$k; valor=$v }; $preTot  += $v }
    elseif ($k -eq "Formulario Webinar") { $webinarTot += $v }
    else                             { $otrosDet += [pscustomobject]@{ nombre=$k; valor=$v }; $otrosTot += $v }
}

# En "Otros", mostrar top 12 y agrupar el resto en "(otros menores)"
$otrosDet = @($otrosDet | Sort-Object valor -Descending)
if ($otrosDet.Count -gt 12) {
    $top = @($otrosDet[0..11])
    $restoSum = ($otrosDet[12..($otrosDet.Count-1)] | Measure-Object valor -Sum).Sum
    if ($restoSum -gt 0) { $top += [pscustomobject]@{ nombre="(otros menores)"; valor=$restoSum } }
    $otrosDet = $top
}

$listaForm = @()
if ($calcTot -gt 0)    { $listaForm += [pscustomobject]@{ nombre="Calculus";  valor=$calcTot; detalle=@($calcDet | Sort-Object valor -Descending) } }
if ($preTot -gt 0)     { $listaForm += [pscustomobject]@{ nombre="Prefooter"; valor=$preTot; detalle=@($preDet | Sort-Object valor -Descending) } }
if ($webinarTot -gt 0) { $listaForm += [pscustomobject]@{ nombre="Formulario Webinar"; valor=$webinarTot } }
if ($otrosTot -gt 0)   { $listaForm += [pscustomobject]@{ nombre="Otros"; valor=$otrosTot; detalle=$otrosDet } }

# Grupo "Sin formulario": contactos que entraron por otra via (import, offline, chat...), desglosado por origen.
# Guardamos el codigo en bruto (DIRECT_TRAFFIC, etc.); la pagina lo traduce al español (evita problemas de acentos).
$sinTot = 0; foreach ($v in $sinFormFuente.Values) { $sinTot += $v }
if ($sinTot -gt 0) {
    $sinDet = @()
    foreach ($k in $sinFormFuente.Keys) {
        $sinDet += [pscustomobject]@{ nombre = $k; valor = $sinFormFuente[$k] }
    }
    $listaForm += [pscustomobject]@{ nombre = "Sin formulario"; valor = $sinTot; detalle = @($sinDet | Sort-Object valor -Descending) }
}

$listaForm = @($listaForm | Sort-Object valor -Descending)

# Agrupar los formularios por idioma (cada formulario cuenta una sola vez)
$idiTot = @{}; $idiDet = @{}
foreach ($k in $porFormulario.Keys) {
    $idi = DetectarIdioma $k
    if (-not $idiTot.ContainsKey($idi)) { $idiTot[$idi] = 0; $idiDet[$idi] = @() }
    $idiTot[$idi] += $porFormulario[$k]
    $idiDet[$idi] += [pscustomobject]@{ nombre = $k; valor = $porFormulario[$k] }
}
$listaIdioma = @()
foreach ($idi in $idiTot.Keys) {
    $listaIdioma += [pscustomobject]@{ nombre = $idi; valor = $idiTot[$idi]; detalle = @($idiDet[$idi] | Sort-Object valor -Descending) }
}
$listaIdioma = @($listaIdioma | Sort-Object valor -Descending)

# Evolucion mensual con desglose por grupo de formulario (para el desplegable de cada mes)
$listaMes = @()
foreach ($k in ($porMes.Keys | Sort-Object)) {
    $det = @()
    if ($porMesForm.ContainsKey($k)) {
        foreach ($g in $porMesForm[$k].Keys) { $det += [pscustomobject]@{ nombre = $g; valor = $porMesForm[$k][$g] } }
        $det = @($det | Sort-Object valor -Descending)
    }
    $listaMes += [pscustomobject]@{ nombre = $k; valor = $porMes[$k]; detalle = $det }
}

# Contactos por pais (codigo ISO2 de ip_country_code) para el mapa coropletico
$listaPais = @()
foreach ($k in $porPais.Keys) { $listaPais += [pscustomobject]@{ code = $k; valor = $porPais[$k] } }
$listaPais = @($listaPais | Sort-Object valor -Descending)

$obj = @{
    fechaActualizacion = (Get-Date).ToString("dd/MM/yyyy HH:mm")
    total        = $total
    nuevos30     = $nuevos30
    nuevosPrev30 = $nuevosPrev30
    conFormulario = $conFormulario
    porFuente    = Lista $porFuente $true
    porEtapa     = Lista $porEtapa $true
    porMes       = $listaMes
    porFormulario = $listaForm
    porIdioma    = $listaIdioma
    porPais      = $listaPais
}
$json = $obj | ConvertTo-Json -Depth 6 -Compress
"window.LEADS = $json;" | Out-File (Join-Path $CarpetaDatos "leads.js") -Encoding utf8

Write-Host ""
Write-Host ("OK  Total leads: {0}  |  Nuevos 30d: {1}  (prev: {2})" -f $total, $nuevos30, $nuevosPrev30) -ForegroundColor Green
Write-Host "Guardado en datos/leads.js"