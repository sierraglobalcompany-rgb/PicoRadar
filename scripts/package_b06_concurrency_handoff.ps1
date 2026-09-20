param(
    [string] $ArtifactDirectory = 'artifacts/current/hostinger-staging',
    [string] $OutputDirectory = 'C:\Users\felip\Documents\ChatGPT\PicoRadar_ Pico y Placa\output\B06_HOSTINGER_FINAL_20260920',
    [string] $PackageHead = '2095695d16fc414d7c32213d803ac42cc71b4a4b',
    [Parameter(Mandatory = $true)]
    [string] $FinalDocHead
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifacts = (Resolve-Path -LiteralPath (Join-Path $root $ArtifactDirectory)).Path
$installable = @(Get-ChildItem -LiteralPath $artifacts -Filter 'PicoRadar-staging-hostinger-*.zip' -File)
if ($installable.Count -ne 1) { throw 'Exactly one final installable is required.' }
$installable = $installable[0]
$installableHash = (Get-FileHash -LiteralPath $installable.FullName -Algorithm SHA256).Hash
$packageManifest = Get-Content -LiteralPath (Join-Path $artifacts 'package-manifest.json') -Raw | ConvertFrom-Json
if ($packageManifest.gitHead -ne $PackageHead) { throw 'The package manifest does not match PackageHead.' }

$output = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item -LiteralPath $installable.FullName -Destination (Join-Path $output $installable.Name) -Force
Copy-Item -LiteralPath (Join-Path $artifacts 'PicoRadar-INSTALACION_HOSTINGER_GUIADA.html') `
    -Destination (Join-Path $output 'PicoRadar-INSTALACION_HOSTINGER_GUIADA.html') -Force
[System.IO.File]::WriteAllText(
    (Join-Path $output ($installable.BaseName + '.sha256.txt')),
    $installableHash + '  ' + $installable.Name + "`n",
    [System.Text.UTF8Encoding]::new($false)
)

$stage = Join-Path ([System.IO.Path]::GetTempPath()) ('picoradar-b06-handoff-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $stage 'evidence') -Force | Out-Null
try {
    foreach ($name in @('00_LEEME.md', 'B06_HOSTINGER_STAGING_INSTALLER_HANDOFF.md')) {
        Copy-Item -LiteralPath (Join-Path $root 'codex/B06_HOSTINGER_STAGING_INSTALLER_HANDOFF.md') `
            -Destination (Join-Path $stage $name)
    }
    Copy-Item -LiteralPath (Join-Path $artifacts 'package-manifest.json') -Destination (Join-Path $stage 'package-manifest.json')
    foreach ($name in @('phpunit-php83-installer.xml', 'phpunit-php85-full.xml')) {
        Copy-Item -LiteralPath (Join-Path $artifacts "evidence/$name") -Destination (Join-Path $stage "evidence/$name")
    }
    foreach ($name in @('installer-completed.png', 'admin-panel.png')) {
        Copy-Item -LiteralPath (Join-Path $artifacts "evidence-browser/$name") -Destination (Join-Path $stage "evidence/$name")
    }

    $identity = [ordered]@{
        schemaVersion = 1
        packageHead = $PackageHead
        packageTree = '2a7564e1d4a394b9a7a5dc76baa31a643ff7a86e'
        finalDocHead = $FinalDocHead
        branch = 'feat/B06-hostinger-staging-installer'
        releaseId = [string] $packageManifest.releaseId
        installable = $installable.Name
        installableSha256 = $installableHash
        hostinger = 'HOSTINGER_NOT_TOUCHED / PENDING_TARGET_SMOKE'
        mobileDelta = 'EMPTY'
        tokenDisposition = 'LOCAL_SEPARATE_FILE_ONLY'
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $stage 'PACKAGE_IDENTITY.json'),
        ($identity | ConvertTo-Json -Depth 5) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    $delta = git -C $root diff --binary 16514c7f8e761fa273462cf99c321573d2efbd00 $PackageHead -- server scripts
    if ($LASTEXITCODE -ne 0) { throw 'The source delta could not be exported.' }
    [System.IO.File]::WriteAllText(
        (Join-Path $stage 'SOURCE_DELTA.patch'),
        ($delta -join "`n") + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    $files = @(Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
            size = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
    $manifest = [ordered]@{
        schemaVersion = 1
        packageHead = $PackageHead
        finalDocHead = $FinalDocHead
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        files = $files
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $stage 'MANIFEST.json'),
        ($manifest | ConvertTo-Json -Depth 8) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    $hashLines = @(Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName | ForEach-Object {
        (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() +
            '  ' + $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
    })
    [System.IO.File]::WriteAllText(
        (Join-Path $stage 'SHA256SUMS.txt'),
        ($hashLines -join "`n") + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    $token = Get-Content -LiteralPath (Join-Path $artifacts 'PicoRadar-INSTALL_TOKEN.txt') |
        Where-Object { $_ -match '^[A-Za-z0-9_-]{40,}$' } |
        Select-Object -First 1
    if (-not $token) { throw 'The separate private token file is malformed.' }
    if (Get-ChildItem -LiteralPath $stage -Recurse -File | Select-String -SimpleMatch $token -ErrorAction SilentlyContinue) {
        throw 'The plaintext installation token is present in handoff evidence.'
    }

    $handoff = Join-Path $output 'PicoRadar_B06_CONCURRENCIA_CIERRE_HANDOFF.zip'
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $handoff -CompressionLevel Optimal -Force
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($handoff)
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -match '(^/|^[A-Za-z]:|(^|/)\.\.(/|$))') {
                throw "Unsafe handoff path: $($entry.FullName)"
            }
        }
    } finally {
        $archive.Dispose()
    }

    [PSCustomObject]@{
        Installable = Join-Path $output $installable.Name
        InstallableSha256 = $installableHash
        Handoff = $handoff
        HandoffSha256 = (Get-FileHash -LiteralPath $handoff -Algorithm SHA256).Hash
        Guide = Join-Path $output 'PicoRadar-INSTALACION_HOSTINGER_GUIADA.html'
    }
} finally {
    $resolvedStage = [System.IO.Path]::GetFullPath($stage)
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (
        $resolvedStage.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path $resolvedStage -Leaf) -like 'picoradar-b06-handoff-*' -and
        (Test-Path -LiteralPath $resolvedStage)
    ) {
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}
