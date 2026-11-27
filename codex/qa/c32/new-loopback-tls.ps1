[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $PrivateRoot,
    [string] $OpenSslExe
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-NoReparsePoint([string] $Path) {
    $cursor = Get-Item -LiteralPath $Path -Force
    while ($null -ne $cursor) {
        if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse point denied: $($cursor.FullName)" }
        $cursor = $cursor.Parent
    }
}

function Assert-PrivateAcl([string] $Path, [string[]] $AllowedSids) {
    $acl = Get-Acl -LiteralPath $Path
    if (-not $acl.AreAccessRulesProtected) { throw "ACL inheritance is enabled: $Path" }
    $rules = $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])
    foreach ($rule in $rules) {
        if ($rule.IdentityReference.Value -notin $AllowedSids -or $rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow) {
            throw "Unexpected ACL principal or deny rule on private path: $Path"
        }
    }
    foreach ($sid in $AllowedSids) {
        if (-not ($rules | Where-Object { $_.IdentityReference.Value -eq $sid -and ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) -eq [Security.AccessControl.FileSystemRights]::FullControl })) {
            throw "ACL lacks required private-root access for an approved principal: $Path"
        }
    }
}

function Write-NewAscii([string] $Path, [string] $Text) {
    $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [Text.Encoding]::ASCII.GetBytes($normalized)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

function Invoke-OpenSsl([string[]] $OpenSslArgs) {
    $output = @(& $script:OpenSslExe @OpenSslArgs 2>&1)
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "OpenSSL command failed ($($OpenSslArgs[0])) with exit $code" }
    return $output
}

$privateRootFull = [IO.Path]::GetFullPath($PrivateRoot)
if (-not (Test-Path -LiteralPath $privateRootFull -PathType Container)) { throw 'PrivateRoot must already exist.' }
Assert-NoReparsePoint $privateRootFull
$currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$allowedSids = @($currentSid, 'S-1-5-18', 'S-1-5-32-544')
Assert-PrivateAcl $privateRootFull $allowedSids

if ([string]::IsNullOrWhiteSpace($OpenSslExe)) {
    $command = Get-Command openssl.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) { $OpenSslExe = $command.Source }
    else {
        $gitOpenSsl = 'C:\Program Files\Git\usr\bin\openssl.exe'
        if (Test-Path -LiteralPath $gitOpenSsl -PathType Leaf) { $OpenSslExe = $gitOpenSsl }
    }
}
if ([string]::IsNullOrWhiteSpace($OpenSslExe) -or -not (Test-Path -LiteralPath $OpenSslExe -PathType Leaf)) { throw 'OpenSSL unavailable.' }
$script:OpenSslExe = (Resolve-Path -LiteralPath $OpenSslExe).Path

$runRoot = Join-Path $privateRootFull ('tls-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($runRoot) | Out-Null
Assert-NoReparsePoint $runRoot
$icacls = Join-Path $env:SystemRoot 'System32\icacls.exe'
$grantUser = "*${currentSid}:(OI)(CI)F"
$grantSystem = '*S-1-5-18:(OI)(CI)F'
$grantAdmins = '*S-1-5-32-544:(OI)(CI)F'
$null = & $icacls $runRoot '/inheritance:r' '/grant:r' $grantUser $grantSystem $grantAdmins '/Q' 2>&1
if ($LASTEXITCODE -ne 0) { throw 'Could not apply the private child ACL; stopping.' }
Assert-NoReparsePoint $runRoot
Assert-PrivateAcl $runRoot $allowedSids

$oldOpenSslConf = $env:OPENSSL_CONF
Remove-Item Env:OPENSSL_CONF -ErrorAction SilentlyContinue
try {
    $caConfig = @('[req]','prompt = no','distinguished_name = dn','[dn]','CN = PicoRadar C32 QA CA','[ca_ext]','basicConstraints = critical,CA:TRUE,pathlen:0','keyUsage = critical,keyCertSign,cRLSign','subjectKeyIdentifier = hash') -join "`n"
    $leafConfig = @('[req]','prompt = no','distinguished_name = dn','[dn]','CN = 127.0.0.1','[leaf_ext]','basicConstraints = critical,CA:FALSE','keyUsage = critical,digitalSignature,keyEncipherment','extendedKeyUsage = serverAuth','subjectAltName = IP:127.0.0.1','subjectKeyIdentifier = hash','authorityKeyIdentifier = keyid,issuer') -join "`n"
    Write-NewAscii (Join-Path $runRoot 'ca.cnf') ($caConfig + "`n")
    Write-NewAscii (Join-Path $runRoot 'leaf.cnf') ($leafConfig + "`n")

    Push-Location $runRoot
    try {
        $null = Invoke-OpenSsl @('req','-new','-x509','-newkey','rsa:2048','-nodes','-sha256','-days','7','-config','ca.cnf','-extensions','ca_ext','-keyout','ca.key.pem','-out','ca.pem')
        $null = Invoke-OpenSsl @('req','-new','-newkey','rsa:2048','-nodes','-sha256','-config','leaf.cnf','-keyout','leaf.key.pem','-out','leaf.csr.pem')
        $null = Invoke-OpenSsl @('x509','-req','-in','leaf.csr.pem','-CA','ca.pem','-CAkey','ca.key.pem','-CAcreateserial','-days','2','-sha256','-extfile','leaf.cnf','-extensions','leaf_ext','-out','leaf.pem')
        $verify = (Invoke-OpenSsl @('verify','-purpose','sslserver','-verify_ip','127.0.0.1','-CAfile','ca.pem','-no-CApath','-no-CAstore','leaf.pem')) -join "`n"
        if ($verify -notmatch 'leaf\.pem\s*:\s*OK') { throw 'OpenSSL chain/purpose/IP verification did not return OK.' }
        $extText = (Invoke-OpenSsl @('x509','-in','leaf.pem','-noout','-ext','extendedKeyUsage,subjectAltName,basicConstraints,keyUsage')) -join "`n"
        if ($extText -notmatch 'TLS Web Server Authentication' -or $extText -notmatch 'IP Address:127\.0\.0\.1' -or $extText -notmatch 'CA:FALSE') { throw 'OpenSSL leaf extensions did not match serverAuth, IP SAN and CA:false.' }
        $null = Invoke-OpenSsl @('x509','-in','leaf.pem','-noout','-checkend','3600')
        $null = Invoke-OpenSsl @('x509','-in','leaf.pem','-outform','DER','-out','leaf.der')
        $null = Invoke-OpenSsl @('pkey','-in','leaf.key.pem','-pubout','-out','leaf-key-public.pem')
        $null = Invoke-OpenSsl @('x509','-in','leaf.pem','-pubkey','-noout','-out','leaf-cert-public.pem')
        $keyPublicHash = (Get-FileHash -LiteralPath (Join-Path $runRoot 'leaf-key-public.pem') -Algorithm SHA256).Hash
        $certPublicHash = (Get-FileHash -LiteralPath (Join-Path $runRoot 'leaf-cert-public.pem') -Algorithm SHA256).Hash
        if ($keyPublicHash -ne $certPublicHash) { throw 'Leaf public key does not match the private key.' }

        $leafText = [IO.File]::ReadAllText((Join-Path $runRoot 'leaf.pem')).TrimEnd()
        $caText = [IO.File]::ReadAllText((Join-Path $runRoot 'ca.pem')).TrimEnd()
        Write-NewAscii (Join-Path $runRoot 'chain.pem') ($leafText + "`n" + $caText + "`n")

        $cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $runRoot 'leaf.der'))
        $ekuExt = $cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' } | Select-Object -First 1
        if ($null -eq $ekuExt) { throw 'Leaf EKU extension missing.' }
        $eku = [Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($ekuExt, $ekuExt.Critical)
        $ekuOids = @($eku.EnhancedKeyUsages | ForEach-Object { $_.Value })
        if ('1.3.6.1.5.5.7.3.1' -notin $ekuOids) { throw 'Leaf does not contain the serverAuth OID.' }
        $bcExt = $cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.19' } | Select-Object -First 1
        if ($null -eq $bcExt) { throw 'Leaf basicConstraints missing.' }
        $bc = [Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($bcExt, $bcExt.Critical)
        if ($bc.CertificateAuthority) { throw 'Leaf basicConstraints must be CA:false.' }
        $kuExt = $cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.15' } | Select-Object -First 1
        if ($null -eq $kuExt) { throw 'Leaf keyUsage missing.' }
        $ku = [Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new($kuExt, $kuExt.Critical)
        if ((($ku.KeyUsages -band [Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature) -eq 0) -or (($ku.KeyUsages -band [Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment) -eq 0)) { throw 'Leaf keyUsage is incomplete.' }
        if ($cert.NotBefore.ToUniversalTime() -gt [DateTime]::UtcNow -or $cert.NotAfter.ToUniversalTime() -lt [DateTime]::UtcNow.AddHours(1)) { throw 'Leaf certificate validity window is not current/sufficient.' }

        [pscustomobject]@{
            result = 'PASS'
            opensslVersion = ((Invoke-OpenSsl @('version')) -join ' ')
            tlsRoot = $runRoot
            caPem = Join-Path $runRoot 'ca.pem'
            chainPem = Join-Path $runRoot 'chain.pem'
            leafKeyPem = Join-Path $runRoot 'leaf.key.pem'
            leafSha256 = (Get-FileHash -LiteralPath (Join-Path $runRoot 'leaf.pem') -Algorithm SHA256).Hash
            serverAuthOid = '1.3.6.1.5.5.7.3.1'
            san = 'IP:127.0.0.1'
            caFalse = $true
            publicKeyMatchesPrivateKey = $true
            verify = 'PASS: sslserver + IP 127.0.0.1 + explicit CA; no system CA path/store'
            checkend3600 = 'PASS'
        } | ConvertTo-Json -Depth 4
    }
    finally { Pop-Location }
}
finally {
    if ($null -eq $oldOpenSslConf) { Remove-Item Env:OPENSSL_CONF -ErrorAction SilentlyContinue }
    else { $env:OPENSSL_CONF = $oldOpenSslConf }
}