param(
    [Parameter(Mandatory = $true)]
    [string] $OutputDirectory,
    [Parameter(Mandatory = $true)]
    [string] $TokenFile,
    [Parameter(Mandatory = $true)]
    [string] $ExpectedPackageHead,
    [Parameter(Mandatory = $true)]
    [string] $ExpectedFinalDocHead,
    [Parameter(Mandatory = $true)]
    [string] $ExpectedInstallableSha256
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$output = (Resolve-Path -LiteralPath $OutputDirectory).Path
$installable = @(Get-ChildItem -LiteralPath $output -Filter 'PicoRadar-staging-hostinger-*.zip' -File)
if ($installable.Count -ne 1) { throw 'Exactly one final installable is required.' }
$installable = $installable[0]
$handoff = Get-Item -LiteralPath (Join-Path $output 'PicoRadar_B06_CONCURRENCIA_CIERRE_HANDOFF.zip')

$expectedInstallableHash = $ExpectedInstallableSha256.ToUpperInvariant()
$actualInstallableHash = (Get-FileHash -LiteralPath $installable.FullName -Algorithm SHA256).Hash
if ($actualInstallableHash -ne $expectedInstallableHash) { throw 'Installable hash mismatch.' }

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('picoradar-b06-independent-' + [guid]::NewGuid().ToString('N'))
$handoffExtract = Join-Path $temp 'handoff'
$installableExtract = Join-Path $temp 'installable'
New-Item -ItemType Directory -Path $handoffExtract, $installableExtract -Force | Out-Null

function Assert-SafeReadableZip([string] $Path) {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -match '(^/|^[A-Za-z]:|(^|/)\.\.(/|$))') {
                throw "Unsafe ZIP path in $Path"
            }
            if (-not $entry.FullName.EndsWith('/')) {
                $stream = $entry.Open()
                try {
                    $buffer = [byte[]]::new(65536)
                    while ($stream.Read($buffer, 0, $buffer.Length) -gt 0) {}
                } finally {
                    $stream.Dispose()
                }
            }
        }
    } finally {
        $archive.Dispose()
    }
}

function Test-ContainsBytes([byte[]] $Haystack, [byte[]] $Needle) {
    if ($Needle.Length -eq 0 -or $Haystack.Length -lt $Needle.Length) { return $false }
    for ($i = 0; $i -le $Haystack.Length - $Needle.Length; $i++) {
        $matches = $true
        for ($j = 0; $j -lt $Needle.Length; $j++) {
            if ($Haystack[$i + $j] -ne $Needle[$j]) {
                $matches = $false
                break
            }
        }
        if ($matches) { return $true }
    }
    return $false
}

try {
    Assert-SafeReadableZip $installable.FullName
    Assert-SafeReadableZip $handoff.FullName
    [System.IO.Compression.ZipFile]::ExtractToDirectory($handoff.FullName, $handoffExtract)
    [System.IO.Compression.ZipFile]::ExtractToDirectory($installable.FullName, $installableExtract)

    $identity = Get-Content -LiteralPath (Join-Path $handoffExtract 'PACKAGE_IDENTITY.json') -Raw | ConvertFrom-Json
    if ($identity.packageHead -ne $ExpectedPackageHead) { throw 'Handoff packageHead mismatch.' }
    if ($identity.finalDocHead -ne $ExpectedFinalDocHead) { throw 'Handoff finalDocHead mismatch.' }
    if ($identity.installableSha256.ToUpperInvariant() -ne $expectedInstallableHash) {
        throw 'Handoff installable hash mismatch.'
    }
    if ($identity.mobileDelta -ne 'EMPTY') { throw 'Handoff says mobile changed.' }

    $manifest = Get-Content -LiteralPath (Join-Path $handoffExtract 'MANIFEST.json') -Raw | ConvertFrom-Json
    foreach ($item in $manifest.files) {
        $path = Join-Path $handoffExtract ($item.path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing manifest file: $($item.path)" }
        $file = Get-Item -LiteralPath $path
        if ($file.Length -ne [long] $item.size) { throw "Size mismatch: $($item.path)" }
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.sha256) {
            throw "Hash mismatch: $($item.path)"
        }
    }

    foreach ($line in (Get-Content -LiteralPath (Join-Path $handoffExtract 'SHA256SUMS.txt'))) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { throw 'Malformed SHA line.' }
        $path = Join-Path $handoffExtract ($Matches[2].Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing SHA file: $($Matches[2])" }
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Matches[1]) {
            throw "SHA mismatch: $($Matches[2])"
        }
    }

    foreach ($xmlName in @('phpunit-php83-installer.xml', 'phpunit-php85-full.xml')) {
        $xmlPath = Join-Path $handoffExtract "evidence\$xmlName"
        $settings = [System.Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
        $reader = [System.Xml.XmlReader]::Create($xmlPath, $settings)
        try {
            while ($reader.Read()) {}
        } finally {
            $reader.Dispose()
        }
        $raw = Get-Content -LiteralPath $xmlPath -Raw
        if ($raw -match [regex]::Escape('C:\Users\felip\.codex\worktrees\b06-hostinger-installer')) {
            throw "Unsanitized worktree path in $xmlName"
        }
    }

    $handoffFiles = @(Get-ChildItem -LiteralPath $handoffExtract -Recurse -File)
    if ($handoffFiles.Name -match 'INSTALL_TOKEN') { throw 'Token file present in handoff.' }
    if ($handoffFiles.Extension -contains '.zip') { throw 'Nested ZIP present in handoff.' }

    $token = Get-Content -LiteralPath $TokenFile |
        Where-Object { $_ -match '^[A-Za-z0-9_-]{40,}$' } |
        Select-Object -First 1
    if (-not $token) { throw 'Private token source is malformed.' }
    $tokenBytes = [System.Text.Encoding]::UTF8.GetBytes($token)
    foreach ($file in @(Get-ChildItem -LiteralPath $handoffExtract, $installableExtract -Recurse -File)) {
        if (Test-ContainsBytes ([System.IO.File]::ReadAllBytes($file.FullName)) $tokenBytes) {
            throw 'Plaintext installation token leaked into deliverables.'
        }
    }

    $required = @(
        '00_LEEME.md',
        'B06_HOSTINGER_STAGING_INSTALLER_HANDOFF.md',
        'PACKAGE_IDENTITY.json',
        'SOURCE_DELTA.patch',
        'MANIFEST.json',
        'SHA256SUMS.txt',
        'evidence\phpunit-php83-installer.xml',
        'evidence\phpunit-php85-full.xml',
        'evidence\installer-completed.png',
        'evidence\admin-panel.png'
    )
    foreach ($relative in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $handoffExtract $relative) -PathType Leaf)) {
            throw "Required handoff item missing: $relative"
        }
    }

    [PSCustomObject]@{
        InstallableSha256 = $actualInstallableHash
        HandoffSha256 = (Get-FileHash -LiteralPath $handoff.FullName -Algorithm SHA256).Hash
        HandoffFileCount = $handoffFiles.Count
        InstallableFileCount = (Get-ChildItem -LiteralPath $installableExtract -Recurse -File).Count
        XmlParsed = 2
        ManifestFilesVerified = $manifest.files.Count
        TokenLeak = $false
        PackageHead = $identity.packageHead
        FinalDocHead = $identity.finalDocHead
    }
} finally {
    $resolvedTemp = [System.IO.Path]::GetFullPath($temp)
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (
        $resolvedTemp.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path $resolvedTemp -Leaf) -like 'picoradar-b06-independent-*' -and
        (Test-Path -LiteralPath $resolvedTemp)
    ) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
