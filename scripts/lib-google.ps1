# ============================================================
#  lib-google.ps1  ·  Autenticacion con Google (cuenta de servicio)
# ============================================================
#  Funciones para obtener un token de acceso de Google a partir
#  de la llave de la cuenta de servicio (google-credenciales.json),
#  firmando un JWT con RS256. Sin librerias externas.
#
#  Uso:  . .\lib-google.ps1   (dot-source)
#        $token = Get-GoogleAccessToken -CredPath ... -Scopes @(...)
# ============================================================

# --- Lee un bloque TLV (tag-length-value) en DER y devuelve valor + nuevo offset ---
function Read-DerTlv($bytes, $offset) {
    $tag = $bytes[$offset]; $offset++
    $len = $bytes[$offset]; $offset++
    if ($len -ge 0x80) {
        $n = $len - 0x80
        $len = 0
        for ($i = 0; $i -lt $n; $i++) { $len = ($len -shl 8) -bor $bytes[$offset]; $offset++ }
    }
    $val = New-Object byte[] $len
    [Array]::Copy($bytes, $offset, $val, 0, $len)
    return @{ Tag = $tag; Value = $val; Next = ($offset + $len) }
}

function Remove-LeadingZero($b) {
    $i = 0
    while ($i -lt $b.Length - 1 -and $b[$i] -eq 0) { $i++ }
    $out = New-Object byte[] ($b.Length - $i)
    [Array]::Copy($b, $i, $out, 0, $out.Length)
    return $out
}

function Set-PadLeft($b, $len) {
    $b = Remove-LeadingZero $b
    if ($b.Length -eq $len) { return $b }
    $out = New-Object byte[] $len
    [Array]::Copy($b, 0, $out, $len - $b.Length, $b.Length)
    return $out
}

# --- Convierte una clave privada PEM (PKCS#8) en un objeto RSA listo para firmar ---
function Get-RsaFromPem($pem) {
    $b64 = ($pem -replace "-----BEGIN PRIVATE KEY-----","" -replace "-----END PRIVATE KEY-----","" -replace "\s","")
    $der = [Convert]::FromBase64String($b64)

    # PKCS#8: SEQUENCE { version, algorithm, privateKey OCTET STRING }
    $seq = Read-DerTlv $der 0
    $p = 0; $content = $seq.Value
    $v = Read-DerTlv $content $p; $p = $v.Next           # version
    $alg = Read-DerTlv $content $p; $p = $alg.Next        # algorithm
    $oct = Read-DerTlv $content $p                        # privateKey (OCTET STRING)
    $inner = $oct.Value

    # PKCS#1 RSAPrivateKey: SEQUENCE { version, n, e, d, p, q, dp, dq, qinv }
    $rsaSeq = Read-DerTlv $inner 0
    $c = $rsaSeq.Value; $q = 0
    $null = (Read-DerTlv $c $q); $q = (Read-DerTlv $c $q).Next   # version
    $n  = Read-DerTlv $c $q; $q = $n.Next
    $e  = Read-DerTlv $c $q; $q = $e.Next
    $d  = Read-DerTlv $c $q; $q = $d.Next
    $p1 = Read-DerTlv $c $q; $q = $p1.Next
    $p2 = Read-DerTlv $c $q; $q = $p2.Next
    $dp = Read-DerTlv $c $q; $q = $dp.Next
    $dq = Read-DerTlv $c $q; $q = $dq.Next
    $iq = Read-DerTlv $c $q

    $mod = Remove-LeadingZero $n.Value
    $half = [int]($mod.Length / 2)

    $params = New-Object System.Security.Cryptography.RSAParameters
    $params.Modulus  = $mod
    $params.Exponent = Remove-LeadingZero $e.Value
    $params.D        = Set-PadLeft $d.Value  $mod.Length
    $params.P        = Set-PadLeft $p1.Value $half
    $params.Q        = Set-PadLeft $p2.Value $half
    $params.DP       = Set-PadLeft $dp.Value $half
    $params.DQ       = Set-PadLeft $dq.Value $half
    $params.InverseQ = Set-PadLeft $iq.Value $half

    $rsa = New-Object System.Security.Cryptography.RSACng
    $rsa.ImportParameters($params)
    return $rsa
}

function ConvertTo-Base64Url($bytes) {
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
}

# --- Token de acceso usando el flujo OAuth de usuario (refresh_token) ---
function Get-GoogleAccessTokenOAuth {
    param([string]$ClientId, [string]$ClientSecret, [string]$RefreshToken)
    $body = "client_id=" + [Uri]::EscapeDataString($ClientId) +
            "&client_secret=" + [Uri]::EscapeDataString($ClientSecret) +
            "&refresh_token=" + [Uri]::EscapeDataString($RefreshToken) +
            "&grant_type=refresh_token"
    $resp = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
    return $resp.access_token
}

# --- Token de acceso usando cuenta de servicio (JWT firmado) ---
function Get-GoogleAccessToken {
    param([string]$CredPath, [string[]]$Scopes)

    $cred = Get-Content $CredPath -Raw | ConvertFrom-Json
    $now  = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

    $header = '{"alg":"RS256","typ":"JWT"}'
    $claim  = @{
        iss   = $cred.client_email
        scope = ($Scopes -join " ")
        aud   = "https://oauth2.googleapis.com/token"
        exp   = $now + 3600
        iat   = $now
    } | ConvertTo-Json -Compress

    $enc = [Text.Encoding]::UTF8
    $signingInput = (ConvertTo-Base64Url $enc.GetBytes($header)) + "." + (ConvertTo-Base64Url $enc.GetBytes($claim))

    $rsa = Get-RsaFromPem $cred.private_key
    $sig = $rsa.SignData($enc.GetBytes($signingInput), [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $jwt = $signingInput + "." + (ConvertTo-Base64Url $sig)

    $body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$jwt"
    $resp = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
    return $resp.access_token
}
