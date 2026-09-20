param(
    [ValidateSet('laravel', 'osrm')]
    [string] $Profile = 'laravel',
    [ValidateSet('sync', 'bounded-cron', 'persistent-worker')]
    [string] $QueueStrategy = 'bounded-cron',
    [string] $FixturePath,
    [string] $TargetHostEvidencePath,
    [switch] $AsJson,
    [switch] $RequireReady
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverRoot = Join-Path $root 'server'

if ($FixturePath -and $TargetHostEvidencePath) {
    throw 'Use FixturePath or TargetHostEvidencePath, not both.'
}

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

function Get-ComposerRequirements {
    $composer = Get-Content -LiteralPath (Join-Path $serverRoot 'composer.json') -Raw | ConvertFrom-Json
    $lock = Get-Content -LiteralPath (Join-Path $serverRoot 'composer.lock') -Raw | ConvertFrom-Json
    $phpConstraint = [string] $lock.platform.php
    if (-not $phpConstraint) { $phpConstraint = [string] $composer.require.php }
    $versionMatch = [regex]::Match($phpConstraint, '(\d+\.\d+(?:\.\d+)?)')
    if (-not $versionMatch.Success) {
        throw "Cannot derive the PHP version from composer metadata: $phpConstraint"
    }
    $extensions = New-Object System.Collections.Generic.HashSet[string]
    foreach ($package in @($lock.packages)) {
        if ($null -eq $package.require) { continue }
        foreach ($property in $package.require.PSObject.Properties) {
            if ($property.Name -like 'ext-*') {
                [void] $extensions.Add($property.Name.Substring(4).ToLowerInvariant())
            }
        }
    }
    return [pscustomobject]@{
        phpConstraint = $phpConstraint
        minimumPhp = [version] $versionMatch.Groups[1].Value
        extensions = @($extensions | Sort-Object)
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
        php = [pscustomobject]@{ available = $phpAvailable; version = $phpVersion; extensions = $extensions }
        composer = [pscustomobject]@{ available = $composerAvailable; version = $composerVersion }
        database = [pscustomobject]@{ mysqlDriverAvailable = $extensions -contains 'pdo_mysql'; connectivity = $null }
        hosting = [pscustomobject]@{ https = $null; cron = $null; persistentProcesses = $null; writableStorage = $null }
        osrm = [pscustomobject]@{
            dockerAvailable = Test-CommandAvailable 'docker'
            graphPresent = Test-Path (Join-Path $root 'data/local/osrm/colombia-latest.osrm.cell_metrics')
            memoryGb = $null
            diskGb = $null
            persistentProcess = $null
        }
    }
}

function Read-CapabilityFile([string] $Path) {
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    return Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
}

if ($FixturePath) {
    $capabilities = Read-CapabilityFile $FixturePath
    $source = [pscustomobject]@{ kind = 'fixture'; path = (Resolve-Path -LiteralPath $FixturePath).Path; provesTargetHost = $false }
} elseif ($TargetHostEvidencePath) {
    $capabilities = Read-CapabilityFile $TargetHostEvidencePath
    $source = [pscustomobject]@{ kind = 'target-host-evidence'; path = (Resolve-Path -LiteralPath $TargetHostEvidencePath).Path; provesTargetHost = $true }
} else {
    $capabilities = Get-LiveCapabilities
    $source = [pscustomobject]@{ kind = 'local-read-only-probe'; path = $null; provesTargetHost = $false }
}

$checks = New-Object System.Collections.Generic.List[object]
function Add-Check(
    [string] $Id,
    [ValidateSet('PASS', 'FAIL', 'UNKNOWN', 'NOT_APPLICABLE')]
    [string] $Status,
    [string] $Detail,
    [bool] $Required = $true
) {
    $checks.Add([pscustomobject]@{ id = $Id; status = $Status; required = $Required; detail = $Detail })
}

function Get-BooleanStatus($Value) {
    if ($null -eq $Value) { return 'UNKNOWN' }
    if ([bool] $Value) { return 'PASS' }
    return 'FAIL'
}

function Get-MinimumStatus($Value, [double] $Minimum) {
    if ($null -eq $Value) { return 'UNKNOWN' }
    if ([double] $Value -ge $Minimum) { return 'PASS' }
    return 'FAIL'
}

if ($Profile -eq 'laravel') {
    $requirements = Get-ComposerRequirements
    $phpAvailable = $capabilities.php.available
    $phpVersion = [string] $capabilities.php.version
    if ($null -eq $phpAvailable) {
        $phpStatus = 'UNKNOWN'
    } elseif (-not [bool] $phpAvailable) {
        $phpStatus = 'FAIL'
    } elseif (-not $phpVersion) {
        $phpStatus = 'UNKNOWN'
    } else {
        try {
            $phpStatus = if ([version] $phpVersion -ge $requirements.minimumPhp) { 'PASS' } else { 'FAIL' }
        } catch {
            $phpStatus = 'FAIL'
        }
    }
    Add-Check 'php-version' $phpStatus "Composer requires $($requirements.phpConstraint); observed $phpVersion"
    Add-Check 'composer' (Get-BooleanStatus $capabilities.composer.available) ([string] $capabilities.composer.version)

    $availableExtensions = @($capabilities.php.extensions | ForEach-Object { ([string] $_).ToLowerInvariant() })
    foreach ($extension in $requirements.extensions) {
        $status = if ($null -eq $capabilities.php.extensions) {
            'UNKNOWN'
        } elseif ($availableExtensions -contains $extension) {
            'PASS'
        } else {
            'FAIL'
        }
        Add-Check "php-ext-$extension" $status 'Derived from server/composer.lock'
    }
    Add-Check 'laravel-artisan' (Get-BooleanStatus (Test-Path (Join-Path $serverRoot 'artisan'))) 'server/artisan exists'
    Add-Check 'composer-lock' (Get-BooleanStatus (Test-Path (Join-Path $serverRoot 'composer.lock'))) 'server/composer.lock exists'

    $driver = $capabilities.database.mysqlDriverAvailable
    if ($null -eq $driver -and $null -ne $capabilities.database.mysqlAvailable) {
        $driver = $capabilities.database.mysqlAvailable
    }
    Add-Check 'mysql-driver' (Get-BooleanStatus $driver) 'PDO MySQL transport capability'
    Add-Check 'database-connectivity' (Get-BooleanStatus $capabilities.database.connectivity) 'Independent staging DB connectivity evidence; driver presence is insufficient'
    Add-Check 'hosting-https' (Get-BooleanStatus $capabilities.hosting.https) 'HTTPS on the target Laravel host'
    Add-Check 'hosting-writable-storage' (Get-BooleanStatus $capabilities.hosting.writableStorage) 'Writable Laravel storage on the target host'

    if ($QueueStrategy -eq 'bounded-cron') {
        Add-Check 'hosting-cron' (Get-BooleanStatus $capabilities.hosting.cron) 'Bounded scheduled queue execution with overlap prevention'
        Add-Check 'hosting-persistent-processes' 'NOT_APPLICABLE' 'Not required by bounded-cron strategy' $false
    } elseif ($QueueStrategy -eq 'persistent-worker') {
        Add-Check 'hosting-cron' 'NOT_APPLICABLE' 'Not required by persistent-worker strategy' $false
        Add-Check 'hosting-persistent-processes' (Get-BooleanStatus $capabilities.hosting.persistentProcesses) 'Persistent queue worker required by selected strategy'
    } else {
        Add-Check 'hosting-cron' 'NOT_APPLICABLE' 'Not required by synchronous queue strategy' $false
        Add-Check 'hosting-persistent-processes' 'NOT_APPLICABLE' 'Not required by synchronous queue strategy' $false
    }
} else {
    Add-Check 'osrm-docker' (Get-BooleanStatus $capabilities.osrm.dockerAvailable) 'Container runtime for the isolated OSRM profile'
    Add-Check 'osrm-graph' (Get-BooleanStatus $capabilities.osrm.graphPresent) 'Versioned Colombia OSRM graph is present'
    Add-Check 'osrm-memory' (Get-MinimumStatus $capabilities.osrm.memoryGb 8) 'At least 8 GB RAM for the proposed first OSRM profile'
    Add-Check 'osrm-disk' (Get-MinimumStatus $capabilities.osrm.diskGb 20) 'At least 20 GB free storage for graph and rollback assets'
    $persistent = $capabilities.osrm.persistentProcess
    if ($null -eq $persistent) { $persistent = $capabilities.hosting.persistentProcesses }
    Add-Check 'hosting-persistent-processes' (Get-BooleanStatus $persistent) 'OSRM requires a supervised persistent process'
}

$checksArray = @($checks | ForEach-Object { $_ })
$failures = @($checksArray | Where-Object { $_.required -and $_.status -eq 'FAIL' })
$unknowns = @($checksArray | Where-Object { $_.required -and $_.status -eq 'UNKNOWN' })
$readiness = if ($failures.Count -gt 0) { 'FAIL' } elseif ($unknowns.Count -gt 0) { 'UNKNOWN' } else { 'PASS' }

$report = [pscustomobject]@{
    schemaVersion = 2
    mode = 'read-only'
    profile = $Profile
    queueStrategy = if ($Profile -eq 'laravel') { $QueueStrategy } else { $null }
    source = $source
    checkedAt = (Get-Date).ToUniversalTime().ToString('o')
    projectRoot = $root
    envFilePresent = (Test-Path (Join-Path $serverRoot '.env'))
    envFileRead = $false
    readiness = $readiness
    targetHostReady = $readiness -eq 'PASS' -and $source.provesTargetHost
    checks = $checksArray
    blockers = @($failures | ForEach-Object { $_.id })
    unknowns = @($unknowns | ForEach-Object { $_.id })
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 8
} else {
    $report | Format-List schemaVersion, mode, profile, queueStrategy, checkedAt, readiness, targetHostReady, envFilePresent, envFileRead
    $checks | Format-Table id, status, required, detail -AutoSize
}

if ($RequireReady -and $report.readiness -ne 'PASS') {
    $reasons = @($report.blockers) + @($report.unknowns)
    throw "$Profile preflight is not ready: $($reasons -join ', ')"
}
