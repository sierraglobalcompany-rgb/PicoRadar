$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script = Join-Path $root 'scripts/server_preflight.ps1'
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("picoradar-preflight-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null

try {
    $readyFixture = Join-Path $scratch 'ready.json'
    @{
        php = @{ available = $true; version = '8.3.12'; extensions = @('ctype', 'fileinfo', 'json', 'mbstring', 'openssl', 'pdo', 'pdo_mysql', 'tokenizer', 'xml') }
        composer = @{ available = $true; version = '2.8.0' }
        database = @{ mysqlAvailable = $true }
        hosting = @{ https = $true; cron = $true; persistentProcesses = $true; writableStorage = $true }
        osrm = @{ dockerAvailable = $true; graphPresent = $true }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $readyFixture -Encoding UTF8

    $before = @(Get-ChildItem -LiteralPath $scratch -File).Count
    $report = (& $script -FixturePath $readyFixture -AsJson) | ConvertFrom-Json
    $after = @(Get-ChildItem -LiteralPath $scratch -File).Count
    if (-not $report.applicationPrerequisitesReady) { throw 'Ready fixture was rejected.' }
    if (-not $report.stagingCapabilitiesReady) { throw 'Ready staging fixture was rejected.' }
    if ($before -ne $after) { throw 'Default preflight wrote unexpected files.' }

    $missingFixture = Join-Path $scratch 'missing.json'
    @{
        php = @{ available = $false; version = $null; extensions = @() }
        composer = @{ available = $false; version = $null }
        database = @{ mysqlAvailable = $false }
        hosting = @{ https = $false; cron = $false; persistentProcesses = $false; writableStorage = $false }
        osrm = @{ dockerAvailable = $false; graphPresent = $false }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $missingFixture -Encoding UTF8

    $missing = (& $script -FixturePath $missingFixture -AsJson) | ConvertFrom-Json
    if ($missing.applicationPrerequisitesReady) { throw 'Missing dependencies were accepted.' }
    if ($missing.blockers.Count -lt 1) { throw 'Missing dependencies did not report blockers.' }

    $failedAsRequired = $false
    try {
        & $script -FixturePath $missingFixture -RequireReady | Out-Null
    } catch {
        $failedAsRequired = $true
    }
    if (-not $failedAsRequired) { throw 'RequireReady did not fail closed.' }

    Write-Output 'PASS: server preflight is read-only by default and fails closed on demand.'
} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
