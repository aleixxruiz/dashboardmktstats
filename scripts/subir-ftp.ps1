# ============================================================
#  SUBIR AL SERVIDOR FTP  ·  estudios.ingesco.com
# ------------------------------------------------------------
#  Sube los archivos del portal a un servidor por FTP / FTPS.
#  Pensado para engancharse a la actualizacion diaria: tras
#  regenerar los datos, los copia tambien al dominio propio.
#
#  Parametros:
#   -SoloDatos  : sube solo datos\*.js (uso diario, por defecto)
#   -Todo       : sube TODO el portal (html + assets + datos) [publicacion completa]
#   -Silencioso : sin pausas (para la tarea programada)
#
#  Lee la configuracion de config.json -> bloque "ftp":
#   "ftp": {
#     "protocolo": "ftps",              // "ftp" | "ftps"  (sftp: ver nota al final)
#     "host": "ftp.tuservidor.com",
#     "puerto": 21,
#     "usuario": "usuario_ftp",
#     "password": "clave_ftp",
#     "rutaBase": "/"                    // carpeta web raiz del dominio (donde esta index.html)
#   }
#  Las credenciales viven SOLO aqui, en tu PC; nunca se publican.
# ============================================================
param([switch]$SoloDatos, [switch]$Todo, [switch]$Silencioso)

$RaizProyecto = Split-Path -Parent $PSScriptRoot
$RutaConfig   = Join-Path $RaizProyecto "config.json"
$RutaLog      = Join-Path $RaizProyecto "datos\log-actualizaciones.txt"
function Log($t){ Add-Content -Path $RutaLog -Value ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "  " + $t) -Encoding utf8 }

if (-not (Test-Path $RutaConfig)) { Write-Host "No encuentro config.json" -ForegroundColor Red; return }
$cfg = Get-Content $RutaConfig -Raw | ConvertFrom-Json
$ftp = $cfg.ftp
if (-not $ftp -or [string]::IsNullOrWhiteSpace($ftp.host) -or $ftp.host -like "PEGA_*" -or [string]::IsNullOrWhiteSpace($ftp.password) -or $ftp.password -like "PEGA_*") {
    Write-Host "FTP no configurado del todo (falta host o contrasena en config.json). Omito la subida FTP." -ForegroundColor DarkYellow
    return
}

$proto  = ("$($ftp.protocolo)").ToLower(); if ([string]::IsNullOrWhiteSpace($proto)) { $proto = "ftps" }
$host_  = $ftp.host
$puerto = if ($ftp.puerto) { [int]$ftp.puerto } else { 21 }
$user   = $ftp.usuario
$pass   = $ftp.password
$base   = if ([string]::IsNullOrWhiteSpace($ftp.rutaBase)) { "" } else { ($ftp.rutaBase).TrimEnd('/') }

if ($proto -eq "sftp") {
    Write-Host "El bloque ftp indica SFTP. Este script hace FTP/FTPS nativo; para SFTP hay que usar WinSCP." -ForegroundColor Yellow
    Write-Host "Avisa para adaptar el script a SFTP (requiere WinSCP instalado)." -ForegroundColor Yellow
    Log "FTP: protocolo sftp no soportado por script nativo; pendiente WinSCP"
    return
}
$usarSsl = ($proto -eq "ftps")

# FTPS suele usar certificado propio del hosting: aceptamos el certificado del servidor.
if ($usarSsl) { [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } }
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# ---- Lista de archivos a subir (local -> ruta remota relativa a rutaBase) ----
$items = @()
function AddFile($local, $remoto){ $script:items += [pscustomobject]@{ local=$local; remoto=$remoto } }

if ($Todo) {
    # Portal completo
    Get-ChildItem $RaizProyecto -Filter *.html | ForEach-Object { AddFile $_.FullName $_.Name }
    foreach ($sub in @("assets","datos")) {
        $carpeta = Join-Path $RaizProyecto $sub
        if (Test-Path $carpeta) {
            Get-ChildItem $carpeta -File -Recurse | ForEach-Object {
                $rel = $_.FullName.Substring($RaizProyecto.Length+1) -replace '\\','/'
                AddFile $_.FullName $rel
            }
        }
    }
} else {
    # Solo datos (uso diario): datos\*.js
    $carpetaDatos = Join-Path $RaizProyecto "datos"
    Get-ChildItem $carpetaDatos -Filter *.js -File | ForEach-Object { AddFile $_.FullName ("datos/" + $_.Name) }
}

if (-not $items.Count) { Write-Host "No hay archivos que subir." -ForegroundColor Yellow; return }

$cred = New-Object System.Net.NetworkCredential($user, $pass)

# Crea una carpeta remota (ignora el error si ya existe)
$dirsCreados = @{}
function AsegurarCarpeta($rutaRemotaCarpeta){
    if ([string]::IsNullOrWhiteSpace($rutaRemotaCarpeta)) { return }
    if ($dirsCreados.ContainsKey($rutaRemotaCarpeta)) { return }
    $dirsCreados[$rutaRemotaCarpeta] = $true
    try {
        $uri = "ftp://${host_}:${puerto}${base}/${rutaRemotaCarpeta}"
        $req = [System.Net.FtpWebRequest]::Create($uri)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
        $req.Credentials = $cred; $req.EnableSsl = $usarSsl; $req.UsePassive = $true; $req.KeepAlive = $false
        $resp = $req.GetResponse(); $resp.Close()
    } catch { }   # normalmente falla porque ya existe: es correcto
}

function SubirArchivo($local, $remotoRel){
    $uri = "ftp://${host_}:${puerto}${base}/${remotoRel}"
    $req = [System.Net.FtpWebRequest]::Create($uri)
    $req.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
    $req.Credentials = $cred; $req.EnableSsl = $usarSsl; $req.UseBinary = $true; $req.UsePassive = $true; $req.KeepAlive = $false
    $bytes = [System.IO.File]::ReadAllBytes($local)
    $req.ContentLength = $bytes.Length
    $s = $req.GetRequestStream(); $s.Write($bytes,0,$bytes.Length); $s.Close()
    $resp = $req.GetResponse(); $resp.Close()
}

Write-Host ""
Write-Host "=== Subiendo a FTP: $host_ (rutaBase '$base', $proto) ===" -ForegroundColor Cyan
$ok = 0; $fallos = 0
foreach ($it in $items) {
    # Asegura la carpeta contenedora (assets/, datos/, subcarpetas)
    $carpeta = ($it.remoto -replace '/[^/]+$','')
    if ($carpeta -ne $it.remoto) { AsegurarCarpeta $carpeta }
    try {
        SubirArchivo $it.local $it.remoto
        Write-Host ("  OK  {0}" -f $it.remoto) -ForegroundColor Green
        $ok++
    } catch {
        Write-Host ("  FALLO  {0}  -> {1}" -f $it.remoto, $_.Exception.Message) -ForegroundColor Red
        $fallos++
    }
}

Write-Host ""
Write-Host ("Subida FTP terminada: {0} correctos, {1} fallos." -f $ok, $fallos) -ForegroundColor Cyan
Log ("FTP subida: $ok ok, $fallos fallos" + $(if($Todo){" (completa)"}else{" (solo datos)"}))
if ($fallos -gt 0 -and -not $Silencioso -and [Environment]::UserInteractive) { Read-Host "Pulsa ENTER para cerrar" }
