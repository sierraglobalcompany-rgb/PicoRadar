param(
    [Parameter(Mandatory = $true)]
    [string] $ArtifactDirectory
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$artifacts = (Resolve-Path -LiteralPath $ArtifactDirectory).Path
$zip = @(Get-ChildItem -LiteralPath $artifacts -Filter 'PicoRadar-staging-hostinger-*.zip' -File)
if ($zip.Count -ne 1) { throw 'Exactly one Hostinger staging ZIP is required.' }

$tokenFile = Join-Path $artifacts 'PicoRadar-INSTALL_TOKEN.txt'
$hashFile = Join-Path $artifacts 'SHA256SUMS.txt'
$manifestFile = Join-Path $artifacts 'package-manifest.json'
$guideFile = Join-Path $artifacts 'PicoRadar-INSTALACION_HOSTINGER_GUIADA.html'
foreach ($required in @($tokenFile, $hashFile, $manifestFile, $guideFile)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing artifact: $required" }
}

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('picoradar-hostinger-verify-' + [guid]::NewGuid().ToString('N'))
try {
    $archive = $null
    $zipStream = [System.IO.File]::OpenRead($zip[0].FullName)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Read, $false)
        $entryNames = @($archive.Entries | ForEach-Object FullName)
        if ($entryNames.Count -eq 0) { throw 'ZIP has no entries.' }
        foreach ($entryName in $entryNames) {
            if ($entryName.Contains('\')) { throw "ZIP contains a Windows-only entry: $entryName" }
            if ($entryName -match '(^/|^[A-Za-z]:|(^|/)\.\.(/|$))') { throw "ZIP contains an unsafe entry: $entryName" }
        }
        $duplicates = @($entryNames | Group-Object | Where-Object Count -gt 1)
        if ($duplicates.Count -gt 0) { throw "ZIP contains duplicate entries: $($duplicates[0].Name)" }
    } finally {
        if ($archive) { $archive.Dispose() }
        $zipStream.Dispose()
    }

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip[0].FullName, $scratch)
    foreach ($requiredPath in @(
        'picoradar_app/current/artisan',
        'picoradar_app/current/vendor/autoload.php',
        'picoradar_app/current/bin/cron.php',
        'picoradar_app/current/deploy/hostinger/setup.php',
        'picoradar_app/current/deploy/hostinger/routing.htaccess',
        'public_html/picoradar/index.php',
        'public_html/picoradar/_setup/index.php',
        'package-manifest.json'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $scratch $requiredPath))) { throw "ZIP is missing $requiredPath" }
    }
    foreach ($forbidden in @(
        'picoradar_app/current/.env',
        'picoradar_app/current/tests',
        'picoradar_app/current/node_modules',
        'picoradar_app/current/vendor/phpunit'
    )) {
        if (Test-Path -LiteralPath (Join-Path $scratch $forbidden)) { throw "ZIP contains forbidden path $forbidden" }
    }

    $token = (Get-Content -LiteralPath $tokenFile | Where-Object { $_ -match '^[A-Za-z0-9_-]{40,}$' } | Select-Object -First 1)
    if (-not $token) { throw 'The separate token file is malformed.' }
    $zipTextHits = Get-ChildItem -LiteralPath $scratch -File -Recurse -Force | Select-String -SimpleMatch $token -ErrorAction SilentlyContinue
    if ($zipTextHits) { throw 'The plaintext installation token is present in the ZIP.' }

    $manifest = Get-Content -LiteralPath (Join-Path $scratch 'package-manifest.json') -Raw | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1 -or -not $manifest.releaseId -or @($manifest.files).Count -eq 0) {
        throw 'Manifest contract is missing or empty.'
    }
    $manifestDuplicates = @($manifest.files | Group-Object path | Where-Object Count -gt 1)
    if ($manifestDuplicates.Count -gt 0) { throw "Manifest contains duplicate entries: $($manifestDuplicates[0].Name)" }
    foreach ($entry in $manifest.files) {
        if ([string]$entry.path -match '(^/|^[A-Za-z]:|(^|/)\.\.(/|$))') { throw "Unsafe manifest path: $($entry.path)" }
        $path = Join-Path $scratch ([string]$entry.path)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Manifest file missing: $($entry.path)" }
        if ((Get-Item -LiteralPath $path).Length -ne [long]$entry.size) { throw "Manifest size mismatch: $($entry.path)" }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne [string]$entry.sha256) { throw "Manifest hash mismatch: $($entry.path)" }
    }

    $checksums = Get-Content -LiteralPath $hashFile | Where-Object { $_.Trim() }
    foreach ($line in $checksums) {
        if ($line -notmatch '^([a-f0-9]{64})  (.+)$') { throw "Invalid SHA256SUMS line: $line" }
        $path = Join-Path $artifacts $Matches[2]
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Checksum file missing: $($Matches[2])" }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $Matches[1]) { throw "Checksum mismatch: $($Matches[2])" }
    }

    Write-Output 'PASS: Hostinger staging package structure, manifest, token separation, exclusions, and hashes are valid.'
} finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
