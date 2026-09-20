param(
    [string] $FixturePath,
    [switch] $AsJson,
    [switch] $RequireReady
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverRoot = Join-Path $root 'server'
$requiredExtensions = @(
    'ctype', 'fileinfo', 'json', 'mbstring', 'openssl', 'pdo',
    'pdo_mysql', 'tokenizer', 'xml'
)

function Test-CommandAvailable([string] $Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-ReadOnlyProbe([scriptblock] $Command) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'SilentlyContinue'
        $output = @(& $Command 2>&1 | ForEach-Object { [string] $_ })
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        return [pscustomobject]@{
            succeeded = $code -eq 0
            output = ($output -join ' ').Trim()
        }
    } catch {
        return [pscustomobject]@{
            succeeded = $false
            output = $_.Exception.Message
        }
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Get-LiveCapabilities {
    $phpAvailable = Test-CommandAvailable 'php'
    $composerAvailable = Test-CommandAvailable 'composer'
    $extensions = @()
    $phpVersion = $null
    if ($phpAvailable) {
        $versionProbe = Invoke-ReadOnlyProbe { php -r 'echo PHP_VERSION;' }
        $phpAvailable = $versionProbe.succeeded
        $phpVersion = $versionProbe.output
        if ($phpAvailable) {
            $extensionProbe = Invoke-ReadOnlyProbe { php -m }
            if ($extensionProbe.succeeded) {
                $extensions = @($extensionProbe.output -split '\s+' | ForEach-Object { $_.Trim().ToLowerInvariant() })
            }
        }
    }
    $composerVersion = $null
    if ($composerAvailable) {
        $composerProbe = Invoke-ReadOnlyProbe { composer --version --no-ansi }
        $composerAvailable = $composerProbe.succeeded
        $composerVersion = $composerProbe.output
    }
    return [pscustomobject]@{
        php = [pscustomobject]@{
            available = $phpAvailable
            version = $phpVersion
            extensions = $extensions
        }
        composer = [pscustomobject]@{
            available = $composerAvailable
            version = $composerVersion
        }
        database = [pscustomobject]@{
            mysqlAvailable = $extensions -contains 'pdo_mysql'
        }
        hosting = [pscustomobject]@{
            https = $null
            cron = $null
            persistentProcesses = $null
            writableStorage = $null
        }
        osrm = [pscustomobject]@{
            dockerAvailable = Test-CommandAvailable 'docker'
            graphPresent = Test-Path (Join-Path $root 'data/local/osrm/colombia-latest.osrm.cell_metrics')
        }
    }
}

if ($FixturePath) {
    $resolvedFixture = (Resolve-Path -LiteralPath $FixturePath).Path
    $capabilities = Get-Content -LiteralPath $resolvedFixture -Raw | ConvertFrom-Json
    $source = 'fixture'
} else {
    $capabilities = Get-LiveCapabilities
    $source = 'local-read-only-probe'
}

$checks = New-Object System.Collections.Generic.List[object]
function Add-Check([string] $Id, [bool] $Passed, [string] $Detail, [bool] $Required = $true) {
    $checks.Add([pscustomobject]@{
        id = $Id
        passed = $Passed
        required = $Required
        detail = $Detail
    })
}

$phpVersion = [string] $capabilities.php.version
$phpVersionOk = $false
if ($capabilities.php.available -and $phpVersion) {
    try { $phpVersionOk = ([version] $phpVersion) -ge ([version] '8.3.0') } catch { $phpVersionOk = $false }
}
Add-Check 'php-8.3' $phpVersionOk "PHP $phpVersion"
Add-Check 'composer' ([bool] $capabilities.composer.available) ([string] $capabilities.composer.version)

$availableExtensions = @($capabilities.php.extensions | ForEach-Object { ([string] $_).ToLowerInvariant() })
foreach ($extension in $requiredExtensions) {
    Add-Check "php-ext-$extension" ($availableExtensions -contains $extension) "PHP extension $extension"
}
Add-Check 'laravel-artisan' (Test-Path (Join-Path $serverRoot 'artisan')) 'server/artisan exists'
Add-Check 'composer-lock' (Test-Path (Join-Path $serverRoot 'composer.lock')) 'server/composer.lock exists'
Add-Check 'mysql-driver' ([bool] $capabilities.database.mysqlAvailable) 'PDO MySQL is available'

$hostingChecks = [ordered]@{
    'hosting-https' = [bool] $capabilities.hosting.https
    'hosting-cron' = [bool] $capabilities.hosting.cron
    'hosting-persistent-processes' = [bool] $capabilities.hosting.persistentProcesses
    'hosting-writable-storage' = [bool] $capabilities.hosting.writableStorage
}
foreach ($entry in $hostingChecks.GetEnumerator()) {
    Add-Check $entry.Key $entry.Value 'Must be confirmed on the private staging host'
}

Add-Check 'osrm-docker' ([bool] $capabilities.osrm.dockerAvailable) 'Docker available for private OSRM' $false
Add-Check 'osrm-graph' ([bool] $capabilities.osrm.graphPresent) 'Existing OSRM graph is reusable' $false

$requiredFailures = @($checks | Where-Object { $_.required -and -not $_.passed })
$applicationFailures = @($checks | Where-Object {
    $_.required -and -not $_.passed -and $_.id -notlike 'hosting-*'
})
$hostingFailures = @($checks | Where-Object {
    $_.required -and -not $_.passed -and $_.id -like 'hosting-*'
})
$checksArray = @($checks | ForEach-Object { $_ })
$blockers = @($requiredFailures | ForEach-Object { $_.id })
$report = [pscustomobject]@{
    schemaVersion = 1
    mode = 'read-only'
    source = $source
    checkedAt = (Get-Date).ToUniversalTime().ToString('o')
    projectRoot = $root
    envFilePresent = (Test-Path (Join-Path $serverRoot '.env'))
    envFileRead = $false
    applicationPrerequisitesReady = $applicationFailures.Count -eq 0
    stagingCapabilitiesReady = $hostingFailures.Count -eq 0
    ready = $requiredFailures.Count -eq 0
    checks = $checksArray
    blockers = $blockers
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
} else {
    $report | Format-List schemaVersion, mode, source, checkedAt, envFilePresent, envFileRead, applicationPrerequisitesReady, stagingCapabilitiesReady, ready
    $checks | Format-Table id, passed, required, detail -AutoSize
}

if ($RequireReady -and -not $report.ready) {
    throw "Server preflight is not ready: $($report.blockers -join ', ')"
}
