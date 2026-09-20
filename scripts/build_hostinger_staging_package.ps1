param(
    [string] $OutputDirectory,
    [string] $PhpPath = 'php',
    [string] $AppUrl = 'https://picoradar.bodegadigitalmedellin.com',
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{2,80}$')]
    [string] $PackagePrefix = 'PicoRadar-staging-hostinger'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverRoot = Join-Path $root 'server'
$outputRoot = if ($OutputDirectory) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    Join-Path $root 'artifacts/current/hostinger-staging'
}
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('picoradar-hostinger-package-' + [guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $scratch 'package'
$privateRoot = Join-Path $packageRoot 'picoradar_app/current'
$publicRoot = Join-Path $packageRoot 'public_html/picoradar'

function Invoke-Checked([string] $Command, [string[]] $Arguments, [string] $WorkingDirectory) {
    Push-Location $WorkingDirectory
    try {
        & $Command @Arguments
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($exitCode -ne 0) {
        throw "$Command failed with exit code $exitCode."
    }
}

function Get-RelativeUnixPath([string] $Base, [string] $Path) {
    $basePath = [System.IO.Path]::GetFullPath($Base).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($basePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the package root: $fullPath"
    }
    return $fullPath.Substring($basePath.Length).Replace('\', '/')
}

function Get-FileHashHex([string] $Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-Utf8NoBom([string] $Path, [string] $Content) {
    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

try {
    $head = (git -C $root rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $head) { throw 'Cannot resolve the Git HEAD.' }
    $shortHead = (git -C $root rev-parse --short=10 HEAD).Trim()
    $releaseId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') + '-' + $shortHead

    $mobileDiff = @(git -C $root status --porcelain -- mobile)
    if ($mobileDiff.Count -gt 0) {
        throw 'Packaging stopped because mobile/ contains changes.'
    }

    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
    New-Item -ItemType Directory -Path $privateRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $publicRoot -Force | Out-Null

    $trackedServerFiles = @(git -C $root ls-files server)
    foreach ($tracked in $trackedServerFiles) {
        $relative = $tracked.Substring('server/'.Length)
        if ($relative -match '^(tests/|phpunit\.xml$|README\.md$|\.env|\.editorconfig$|deploy/hostinger/public/)') { continue }
        if ($relative -match '^(node_modules/|vendor/|public/build/)') { continue }

        $source = Join-Path $root $tracked
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
        $destination = Join-Path $privateRoot $relative
        $destinationDirectory = Split-Path -Parent $destination
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }

    foreach ($catalog in @(
        'pico_jurisdiction_catalog_v1.json',
        'colombia_registration_cities_v1.json'
    )) {
        $source = Join-Path $root "mobile/assets/catalogs/$catalog"
        $destination = Join-Path $privateRoot "database/data/$catalog"
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Required clean-install catalog is missing: $catalog"
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }

    Copy-Item -LiteralPath (Join-Path $serverRoot 'deploy/hostinger/public/index.php') -Destination (Join-Path $publicRoot 'index.php') -Force
    New-Item -ItemType Directory -Path (Join-Path $publicRoot '_setup') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $serverRoot 'deploy/hostinger/public/_setup/index.php') -Destination (Join-Path $publicRoot '_setup/index.php') -Force
    foreach ($publicFile in @('favicon.ico', 'robots.txt')) {
        $source = Join-Path $serverRoot "public/$publicFile"
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $publicRoot $publicFile) -Force }
    }

    Invoke-Checked 'composer' @('install', '--no-dev', '--classmap-authoritative', '--no-interaction', '--prefer-dist', '--no-ansi') $privateRoot
    Invoke-Checked 'npm' @('ci', '--no-audit', '--no-fund') $privateRoot
    Invoke-Checked 'npm' @('run', 'build') $privateRoot
    Copy-Item -LiteralPath (Join-Path $privateRoot 'public/build') -Destination (Join-Path $publicRoot 'build') -Recurse -Force
    Remove-Item -LiteralPath (Join-Path $privateRoot 'node_modules') -Recurse -Force
    Remove-Item -LiteralPath (Join-Path $privateRoot 'public') -Recurse -Force

    $installerDirectory = Join-Path $privateRoot 'storage/app/installer'
    New-Item -ItemType Directory -Path $installerDirectory -Force | Out-Null
    $tokenBytes = New-Object byte[] 32
    $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $random.GetBytes($tokenBytes)
    } finally {
        $random.Dispose()
    }
    $token = [Convert]::ToBase64String($tokenBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $env:PICORADAR_INSTALL_TOKEN = $token
    try {
        $hashScript = Join-Path $scratch 'hash-install-token.php'
        Write-Utf8NoBom $hashScript '<?php echo password_hash(getenv(''PICORADAR_INSTALL_TOKEN''), PASSWORD_ARGON2ID);'
        $tokenHash = (& $PhpPath $hashScript).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'PHP failed while hashing the installation token.' }
    } finally {
        Remove-Item Env:PICORADAR_INSTALL_TOKEN -ErrorAction SilentlyContinue
    }
    if (-not $tokenHash.StartsWith('$argon2id$')) { throw 'The installation token could not be hashed with Argon2id.' }

    $packageConfig = [ordered]@{
        schemaVersion = 1
        releaseId = $releaseId
        tokenHash = $tokenHash
        tokenExpiresAt = (Get-Date).ToUniversalTime().AddDays(30).ToString('o')
        appUrl = $AppUrl.TrimEnd('/')
        manifestPath = 'package-manifest.json'
        trustedProxyIps = @()
    }
    Write-Utf8NoBom (Join-Path $installerDirectory 'package.json') (($packageConfig | ConvertTo-Json -Depth 5) + "`n")

    $manifestPath = Join-Path $packageRoot 'package-manifest.json'
    $manifestFiles = @(
        Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Force |
            Where-Object { $_.FullName -ne $manifestPath } |
            Sort-Object FullName |
            ForEach-Object {
                [ordered]@{
                    path = Get-RelativeUnixPath $packageRoot $_.FullName
                    size = $_.Length
                    sha256 = Get-FileHashHex $_.FullName
                }
            }
    )
    $manifest = [ordered]@{
        schemaVersion = 1
        releaseId = $releaseId
        gitHead = $head
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        files = $manifestFiles
    }
    Write-Utf8NoBom $manifestPath (($manifest | ConvertTo-Json -Depth 8) + "`n")

    if (Test-Path -LiteralPath $outputRoot) { Remove-Item -LiteralPath $outputRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
    $zipName = "$PackagePrefix-$releaseId.zip"
    $zipPath = Join-Path $outputRoot $zipName
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipStream = [System.IO.File]::Open($zipPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            $packageFiles = @(Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Force | Sort-Object FullName)
            foreach ($file in $packageFiles) {
                $entryName = Get-RelativeUnixPath $packageRoot $file.FullName
                if ($entryName.Contains('\')) { throw "ZIP entry is not portable: $entryName" }
                $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
                $entryStream = $entry.Open()
                $sourceStream = [System.IO.File]::OpenRead($file.FullName)
                try {
                    $sourceStream.CopyTo($entryStream)
                } finally {
                    $sourceStream.Dispose()
                    $entryStream.Dispose()
                }
            }
        } finally {
            $archive.Dispose()
        }
    } finally {
        $zipStream.Dispose()
    }

    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $outputRoot 'package-manifest.json') -Force
    Write-Utf8NoBom (Join-Path $outputRoot 'PicoRadar-INSTALL_TOKEN.txt') @"
PicoRadar staging installation token
Release: $releaseId
Expires: $($packageConfig.tokenExpiresAt)

$token

Keep this file only on the owner's computer. It is not included in the ZIP.
"@

    $guide = @"
<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>PicoRadar - Instalación Hostinger</title><style>body{font:16px/1.55 system-ui;margin:32px auto;max-width:820px;padding:0 20px;color:#0b3159}h1,h2{line-height:1.2}code{display:block;background:#eef3f6;padding:10px;overflow-wrap:anywhere}li{margin:8px 0}.warn{border-left:4px solid #c99000;padding:8px 12px;background:#fff8df}</style></head><body>
<h1>PicoRadar: instalación guiada en Hostinger</h1><p>Release <strong>$releaseId</strong></p>
<h2>Antes de subir</h2><ol><li>Activa PHP 8.5 y HTTPS.</li><li>Crea una base MySQL/MariaDB exclusiva y vacía.</li><li>Protege con contraseña la carpeta <code>public_html/picoradar</code> desde hPanel.</li><li>Conserva el token separado en tu computador.</li></ol>
<h2>Extraer el ZIP</h2><p>Sube <strong>$zipName</strong> a:</p><code>/home/u390570745/domains/bodegadigitalmedellin.com/</code><p>Extrae allí. Deben quedar exactamente:</p><code>picoradar_app/current<br>public_html/picoradar<br>package-manifest.json</code>
<p class="warn">No muevas Laravel dentro de public_html y no uses permisos 777. El ZIP no incluye un .htaccess raíz: así conserva la protección por contraseña que configuraste. Al finalizar, el asistente añade únicamente las reglas de PicoRadar.</p>
<h2>Asistente</h2><p>Abre <code>https://picoradar.bodegadigitalmedellin.com/_setup/</code>, introduce el token y sigue las etapas. No cierres la protección por contraseña de Hostinger.</p>
<h2>Cron</h2><p>Al finalizar, crea en hPanel un cron de tipo PHP cada cinco minutos. El asistente mostrará esta ruta:</p><code>/home/u390570745/domains/bodegadigitalmedellin.com/picoradar_app/current/bin/cron.php</code><p>Hostinger interpreta la programación en UTC.</p>
<h2>Cierre</h2><ol><li>Comprueba Login y Health.</li><li>Elimina manualmente <code>public_html/picoradar/_setup</code>.</li><li>Mantén staging protegido por contraseña.</li><li>No cargues datos reales en esta prueba.</li></ol>
</body></html>
"@
    Write-Utf8NoBom (Join-Path $outputRoot 'PicoRadar-INSTALACION_HOSTINGER_GUIADA.html') $guide

    $provenance = [ordered]@{
        releaseId = $releaseId
        gitHead = $head
        branch = (git -C $root branch --show-current).Trim()
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        php = (& $PhpPath -r 'echo PHP_VERSION;').Trim()
        composer = (composer --version --no-ansi | Select-Object -First 1)
        node = (node --version)
        databaseTest = 'pending-local-clean-room'
        targetDeployment = 'not-performed'
    }
    Write-Utf8NoBom (Join-Path $outputRoot 'PicoRadar-PRUEBAS_Y_PROCEDENCIA.json') (($provenance | ConvertTo-Json -Depth 5) + "`n")

    $hashFiles = @(
        Get-ChildItem -LiteralPath $outputRoot -File |
            Where-Object Name -ne 'SHA256SUMS.txt' |
            Sort-Object Name |
            ForEach-Object { "$(Get-FileHashHex $_.FullName)  $($_.Name)" }
    )
    Write-Utf8NoBom (Join-Path $outputRoot 'SHA256SUMS.txt') (($hashFiles -join "`n") + "`n")

    Write-Output ([pscustomobject]@{
        releaseId = $releaseId
        outputDirectory = $outputRoot
        zip = $zipPath
        zipSha256 = Get-FileHashHex $zipPath
    } | ConvertTo-Json -Depth 4)
} finally {
    Remove-Item Env:PICORADAR_INSTALL_TOKEN -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
