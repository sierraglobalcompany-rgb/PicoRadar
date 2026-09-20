$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script = Join-Path $root 'scripts/server_preflight.ps1'
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("picoradar-preflight-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null

try {
    $readyFixture = Join-Path $scratch 'ready.json'
    @{
        php = @{ available = $true; version = '8.3.12'; extensions = @('ctype', 'dom', 'fileinfo', 'filter', 'hash', 'iconv', 'json', 'libxml', 'mbstring', 'openssl', 'pcre', 'phar', 'session', 'tokenizer', 'xml', 'xmlwriter') }
        composer = @{ available = $true; version = '2.8.0' }
        database = @{ mysqlDriverAvailable = $true; connectivity = $true }
        hosting = @{ https = $true; cron = $true; persistentProcesses = $true; writableStorage = $true }
        osrm = @{ dockerAvailable = $true; graphPresent = $true }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $readyFixture -Encoding UTF8

    $before = @(Get-ChildItem -LiteralPath $scratch -File).Count
    $report = (& $script -Profile laravel -FixturePath $readyFixture -AsJson) | ConvertFrom-Json
    $after = @(Get-ChildItem -LiteralPath $scratch -File).Count
    if ($report.profile -ne 'laravel') { throw 'Laravel profile was not reported.' }
    if ($report.source.kind -ne 'fixture') { throw 'Fixture provenance was not reported.' }
    if ($report.source.provesTargetHost) { throw 'A fixture cannot prove a target host.' }
    if ($report.readiness -ne 'PASS') { throw 'Ready Laravel fixture was rejected.' }
    $persistent = @($report.checks | Where-Object id -eq 'hosting-persistent-processes')
    if ($persistent.Count -ne 1 -or $persistent[0].status -ne 'NOT_APPLICABLE') {
        throw 'Laravel bounded-cron strategy must not require a persistent process.'
    }
    if ($before -ne $after) { throw 'Default preflight wrote unexpected files.' }

    $missingFixture = Join-Path $scratch 'missing.json'
    @{
        php = @{ available = $false; version = $null; extensions = @() }
        composer = @{ available = $false; version = $null }
        database = @{ mysqlDriverAvailable = $false; connectivity = $false }
        hosting = @{ https = $false; cron = $false; persistentProcesses = $false; writableStorage = $false }
        osrm = @{ dockerAvailable = $false; graphPresent = $false }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $missingFixture -Encoding UTF8

    $missing = (& $script -Profile laravel -FixturePath $missingFixture -AsJson) | ConvertFrom-Json
    if ($missing.readiness -ne 'FAIL') { throw 'Missing dependencies were accepted.' }
    if ($missing.blockers.Count -lt 1) { throw 'Missing dependencies did not report blockers.' }

    $unknownFixture = Join-Path $scratch 'unknown-host.json'
    @{
        php = @{ available = $true; version = '8.3.12'; extensions = @('ctype', 'dom', 'fileinfo', 'filter', 'hash', 'iconv', 'json', 'libxml', 'mbstring', 'openssl', 'pcre', 'phar', 'session', 'tokenizer', 'xml', 'xmlwriter') }
        composer = @{ available = $true; version = '2.8.0' }
        database = @{ mysqlDriverAvailable = $true; connectivity = $null }
        hosting = @{ https = $null; cron = $null; persistentProcesses = $null; writableStorage = $null }
        osrm = @{ dockerAvailable = $null; graphPresent = $null; memoryGb = $null; diskGb = $null; persistentProcess = $null }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $unknownFixture -Encoding UTF8

    $unknown = (& $script -Profile laravel -FixturePath $unknownFixture -AsJson) | ConvertFrom-Json
    if ($unknown.readiness -ne 'UNKNOWN') { throw 'Unknown host facts must remain UNKNOWN.' }
    if (@($unknown.checks | Where-Object status -eq 'UNKNOWN').Count -eq 0) {
        throw 'Unknown host facts were coerced to pass/fail.'
    }
    $database = @($unknown.checks | Where-Object id -eq 'database-connectivity')[0]
    if ($database.status -ne 'UNKNOWN') {
        throw 'A PDO driver must not prove operational database connectivity.'
    }

    $osrm = (& $script -Profile osrm -FixturePath $unknownFixture -AsJson) | ConvertFrom-Json
    if ($osrm.readiness -ne 'UNKNOWN') { throw 'Unknown OSRM resources must not be ready.' }
    if (@($osrm.checks | Where-Object id -eq 'hosting-persistent-processes')[0].status -ne 'UNKNOWN') {
        throw 'OSRM must require a confirmed persistent process.'
    }

    $missingOsrmFixture = Join-Path $scratch 'missing-osrm.json'
    @{
        php = @{ available = $null; version = $null; extensions = $null }
        composer = @{ available = $null; version = $null }
        database = @{ mysqlDriverAvailable = $null; connectivity = $null }
        hosting = @{ https = $null; cron = $null; persistentProcesses = $false; writableStorage = $null }
        osrm = @{ dockerAvailable = $false; graphPresent = $false; memoryGb = 4; diskGb = 10; persistentProcess = $false }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $missingOsrmFixture -Encoding UTF8
    $missingOsrm = (& $script -Profile osrm -FixturePath $missingOsrmFixture -AsJson) | ConvertFrom-Json
    if ($missingOsrm.readiness -ne 'FAIL') { throw 'Missing OSRM resources were accepted.' }

    $failedAsRequired = $false
    try {
        & $script -Profile laravel -FixturePath $missingFixture -RequireReady | Out-Null
    } catch {
        $failedAsRequired = $true
    }
    if (-not $failedAsRequired) { throw 'RequireReady did not fail closed.' }

    Write-Output 'PASS: separated preflight profiles preserve provenance, unknowns, and read-only behavior.'
} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
