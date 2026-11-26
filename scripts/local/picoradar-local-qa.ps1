[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Init', 'Start', 'Stop', 'Status')][string]$Action,
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$RuntimeHome = 'D:\codex\_build\PicoRadar-C30-V2\runtime',
    [string]$InstanceRoot = 'D:\codex\_build\PicoRadar-C30-V2\runtime\instance-a',
    [string]$PrivateRoot = 'D:\codex\_build\PicoRadar-C30-V2\private',
    [string]$KeyFile = 'D:\codex\_build\PicoRadar-C30-V2\private\instance-a.app-key',
    [string]$PasswordFile = 'D:\codex\_build\PicoRadar-C30-V2\private\operator.qa.password',
    [string]$PhpExe = 'C:\xampphp\php\php.exe',
    [string]$ReportRoot = 'D:\codex\_REPORTES\PicoRadar\C30-V2-20261126',
    [ValidateRange(1024, 65535)][int]$Port = 8878
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FullPath([string]$Path) { [IO.Path]::GetFullPath($Path).TrimEnd('\') }

function Test-UnderRoot([string]$Path, [string]$Root) {
    $p = (Get-FullPath $Path).TrimEnd('\')
    $r = (Get-FullPath $Root).TrimEnd('\')
    return $p.Equals($r, [StringComparison]::OrdinalIgnoreCase) -or $p.StartsWith($r + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoReparseAncestors([string]$Path) {
    $full = Get-FullPath $Path
    $cursor = $full
    while ($cursor -and (Test-Path -LiteralPath $cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'BLOCKED_REPARSE_POINT' }
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or $parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Assert-PrivateAcl([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw 'BLOCKED_PRIVATE_ROOT_MISSING' }
    $acl = Get-Acl -LiteralPath $Path
    if (-not $acl.AreAccessRulesProtected) { throw 'BLOCKED_PRIVATE_ACL_INHERITED' }
    $expected = @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value, 'S-1-5-18', 'S-1-5-32-544')
    $rules = $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])
    foreach ($rule in $rules) {
        if ($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or $rule.IdentityReference.Value -notin $expected) {
            throw 'BLOCKED_PRIVATE_ACL_PRINCIPAL'
        }
    }
    foreach ($sid in $expected) {
        if (-not ($rules | Where-Object { $_.IdentityReference.Value -eq $sid -and ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) -eq [Security.AccessControl.FileSystemRights]::FullControl })) {
            throw 'BLOCKED_PRIVATE_ACL_INCOMPLETE'
        }
    }
}

function New-ExclusiveText([string]$Path, [string]$Text) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
}

function Write-OwnedText([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Get-RandomText([int]$ByteCount, [bool]$Base64Url = $false) {
    $bytes = [byte[]]::new($ByteCount)
    [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $value = [Convert]::ToBase64String($bytes)
    if ($Base64Url) { return $value.TrimEnd('=').Replace('+', '-').Replace('/', '_') }
    return $value
}

function New-OperationLock([string]$Path) {
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    try { return [IO.File]::Open($Path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch { throw 'BLOCKED_OPERATION_LOCK_BUSY' }
}

function Get-InstanceMarker {
    $markerPath = Join-Path $InstanceRoot 'instance.json'
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { return $null }
    $marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
    if ($marker.format -ne 'picoradar-local-qa/1' -or $marker.backend -ne 'sqlite' -or $marker.scope -ne 'NON_PRODUCTION_SYNTHETIC' -or $marker.state -ne 'initialized') {
        throw 'BLOCKED_INSTANCE_MARKER_INVALID'
    }
    $instanceFull = Get-FullPath $InstanceRoot
    $instanceName = [IO.Path]::GetFileName($instanceFull)
    $instanceParent = [IO.Path]::GetDirectoryName($instanceFull)
    $allowedParent = Get-FullPath $RuntimeHome
    $allowedName = $instanceName -ceq 'instance-a' -or $instanceName -cmatch '^instance-restored(?:-[A-Za-z0-9][A-Za-z0-9_-]{0,63})?$'
    if (-not $allowedName -or -not $instanceParent.Equals($allowedParent, [StringComparison]::OrdinalIgnoreCase)) { throw 'BLOCKED_INSTANCE_ROOT_NAME' }
    $expectedPaths = @{ database='data/picoradar.sqlite'; private_storage='storage/app/private'; public_storage='storage/app/public'; runtime='runtime'; bootstrap_cache='bootstrap/cache' }
    foreach ($name in $expectedPaths.Keys) { if ([string]$marker.paths.$name -ne $expectedPaths[$name]) { throw 'BLOCKED_INSTANCE_LAYOUT_MARKER' } }
    $parsedId = [guid]::Empty
    if (-not [guid]::TryParse([string]$marker.id, [ref]$parsedId) -or -not (Test-UnderRoot $InstanceRoot $RuntimeHome) -or -not (Test-Path -LiteralPath (Join-Path $InstanceRoot 'data\picoradar.sqlite') -PathType Leaf)) {
        throw 'BLOCKED_INSTANCE_LAYOUT_INVALID'
    }
    return $marker
}

function Get-ProcessMarkerPath { Join-Path $InstanceRoot 'runtime\process.json' }

function Get-VerifiedProcess($Marker) {
    if (-not $Marker) { return $null }
    $process = Get-Process -Id ([int]$Marker.pid) -ErrorAction SilentlyContinue
    $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$Marker.pid)" -ErrorAction SilentlyContinue
    if (-not $process -or -not $cim) { throw 'BLOCKED_PROCESS_NOT_RUNNING' }
    if (-not $process.Path -or -not $process.Path.Equals((Get-FullPath $PhpExe), [StringComparison]::OrdinalIgnoreCase)) { throw 'BLOCKED_PROCESS_EXE_MISMATCH' }
    $markerStart = $Marker.startTimeUtc
    if ($markerStart -is [datetime]) { $markerStartUtc = $markerStart.ToUniversalTime() }
    else { $markerStartUtc = [datetime]::Parse([string]$markerStart, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime() }
    if ($process.StartTime.ToUniversalTime().Ticks -ne $markerStartUtc.Ticks) { throw 'BLOCKED_PROCESS_START_TIME_MISMATCH' }
    $command = [string]$cim.CommandLine
    $router = Get-FullPath (Join-Path $PSScriptRoot 'picoradar-local-qa.php')
    if (-not $command.Contains('-S 127.0.0.1:' + [string]$Marker.port) -or -not $command.Contains($router)) { throw 'BLOCKED_PROCESS_COMMAND_MISMATCH' }
    $commandHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes($command)))
    if ($commandHash -ne [string]$Marker.commandline_sha256) { throw 'BLOCKED_PROCESS_COMMAND_HASH_MISMATCH' }
    $listeners = @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort ([int]$Marker.port) -ErrorAction SilentlyContinue)
    if ($listeners.Count -ne 1 -or [int]$listeners[0].OwningProcess -ne [int]$Marker.pid) { throw 'BLOCKED_PROCESS_LISTENER_MISMATCH' }
    if ([string]$Marker.instanceId -ne [string]$script:InstanceId) { throw 'BLOCKED_PROCESS_INSTANCE_MISMATCH' }
    return $process
}

function Assert-NoOrphanC30Listener([int]$ListenerPort) {
    $listeners = @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $ListenerPort -ErrorAction SilentlyContinue)
    $router = Get-FullPath (Join-Path $PSScriptRoot 'picoradar-local-qa.php')
    foreach ($listener in $listeners) {
        $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$listener.OwningProcess)" -ErrorAction SilentlyContinue
        if ($cim -and [string]$cim.CommandLine -and [string]$cim.CommandLine.Contains($router)) { throw 'BLOCKED_UNVERIFIABLE_C30_LISTENER' }
    }
}

function Get-C30Environment([string]$Key, [int]$UsePort, [bool]$IncludePassword = $false) {
    $serverRoot = Get-FullPath (Join-Path $RepoRoot 'server')
    $database = Join-Path $InstanceRoot 'data\picoradar.sqlite'
    $cache = Join-Path $InstanceRoot 'bootstrap\cache'
    $relativeCache = [IO.Path]::GetRelativePath($serverRoot, $cache).Replace('\', '/')
    $values = @{
        APP_ENV='local'; APP_DEBUG='false'; APP_KEY=$Key; APP_NAME='PicoRadar C30 QA'; APP_URL="http://127.0.0.1:$UsePort"
        APP_CONFIG_CACHE="$relativeCache/config.php"; APP_ROUTES_CACHE="$relativeCache/routes-v7.php"
        APP_EVENTS_CACHE="$relativeCache/events.php"; APP_PACKAGES_CACHE="$relativeCache/packages.php"
        APP_SERVICES_CACHE="$relativeCache/services.php"; VIEW_COMPILED_PATH=(Join-Path $InstanceRoot 'storage\framework\views')
        LARAVEL_STORAGE_PATH=(Join-Path $InstanceRoot 'storage'); PICORADAR_PUBLIC_PATH=(Join-Path $serverRoot 'public')
        PICORADAR_INSTANCE_ROOT=$InstanceRoot; PICORADAR_INSTANCE_ID=$script:InstanceId
        DB_CONNECTION='sqlite'; DB_URL=''; DATABASE_URL=''; DB_DATABASE=$database; DB_FOREIGN_KEYS='true'
        SESSION_DRIVER='file'; CACHE_STORE='file'; QUEUE_CONNECTION='sync'; MAIL_MAILER='array'; LOG_CHANNEL='single'; LOG_LEVEL='info'
        FILESYSTEM_DISK='local'; DATASET_DRAFT_DISK='local'; DATASET_PUBLISHED_DISK='public'; DATASET_PUBLIC_BASE_URL='/storage'
        CAMPAIGN_PUBLIC_CATALOG_ENABLED='false'; PICORADAR_ACCOUNT_EMAIL_ENABLED='false'; PICORADAR_MARKETING_SEND_ENABLED='false'
        PICORADAR_PUBLIC_CATALOG_ENABLED='false'; PICORADAR_QA_LOCAL='1'
    }
    if ($IncludePassword) { $values.PICORADAR_OPERATOR_PASSWORD = [IO.File]::ReadAllText($PasswordFile).Trim() }
    return $values
}

function Invoke-C30Php([string[]]$PhpArguments, [hashtable]$Values) {
    $names = @((Get-ChildItem Env: | Where-Object Name -Match '^(APP_|DB_|MAIL_|REDIS_|SESSION_|CACHE_|QUEUE_|FILESYSTEM_|DATASET_|CAMPAIGN_|PICORADAR_)|^(DATABASE_URL)$' | Select-Object -ExpandProperty Name))
    $names += @('APP_ENV','APP_DEBUG','APP_KEY','APP_NAME','APP_URL','APP_CONFIG_CACHE','APP_ROUTES_CACHE','APP_EVENTS_CACHE','APP_PACKAGES_CACHE','APP_SERVICES_CACHE','VIEW_COMPILED_PATH','LARAVEL_STORAGE_PATH','PICORADAR_PUBLIC_PATH','PICORADAR_INSTANCE_ROOT','PICORADAR_INSTANCE_ID','PICORADAR_OPERATOR_PASSWORD','DB_CONNECTION','DB_URL','DATABASE_URL','DB_DATABASE','DB_FOREIGN_KEYS','SESSION_DRIVER','CACHE_STORE','QUEUE_CONNECTION','MAIL_MAILER','LOG_CHANNEL','LOG_LEVEL','FILESYSTEM_DISK','DATASET_DRAFT_DISK','DATASET_PUBLISHED_DISK','DATASET_PUBLIC_BASE_URL','CAMPAIGN_PUBLIC_CATALOG_ENABLED','PICORADAR_ACCOUNT_EMAIL_ENABLED','PICORADAR_MARKETING_SEND_ENABLED','PICORADAR_PUBLIC_CATALOG_ENABLED','PICORADAR_QA_LOCAL')
    $names = @($names | Sort-Object -Unique)
    $old = @{}
    foreach ($name in $names) { $old[$name] = [Environment]::GetEnvironmentVariable($name, 'Process'); [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
    $oldPath = [Environment]::GetEnvironmentVariable('PATH', 'Process')
    try {
        foreach ($name in $Values.Keys) { [Environment]::SetEnvironmentVariable($name, [string]$Values[$name], 'Process') }
        $phpDir = Split-Path -Parent $PhpExe
        [Environment]::SetEnvironmentVariable('PATH', "$phpDir;$phpDir\ext;$oldPath", 'Process')
        Push-Location (Join-Path $RepoRoot 'server')
        try {
            $extensionArgs = @('-d', 'extension_dir=C:\xampphp\php\ext', '-d', 'extension=php_sqlite3.dll', '-d', 'extension=php_pdo_sqlite.dll')
            $output = @(& $PhpExe @extensionArgs @PhpArguments 2>&1)
            $exitCode = $LASTEXITCODE
        } finally { Pop-Location }
        $text = ($output | ForEach-Object { $_.ToString() }) -join "`n"
        if ($exitCode -ne 0) { throw "PHP_EXIT_$exitCode`n$text" }
        return $text.Trim()
    } finally {
        [Environment]::SetEnvironmentVariable('PATH', $oldPath, 'Process')
        foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $old[$name], 'Process') }
    }
}

function Write-RunLog([string]$Name, [string]$Content) {
    $logs = Join-Path $ReportRoot 'logs\A'
    [IO.Directory]::CreateDirectory($logs) | Out-Null
    $path = Join-Path $logs $Name
    New-ExclusiveText $path ($Content.TrimEnd() + "`r`n")
    return $path
}

function Assert-PartialInitSafe {
    $expectedFiles = @('bootstrap/cache/packages.php','bootstrap/cache/services.php','data/picoradar.sqlite','runtime/operation.lock') | Sort-Object
    $actualFiles = @(Get-ChildItem -LiteralPath $InstanceRoot -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($InstanceRoot.Length + 1).Replace('\','/') } | Sort-Object)
    if (($actualFiles -join "`n") -ne ($expectedFiles -join "`n")) { throw 'BLOCKED_PARTIAL_INIT_FILE_INVENTORY' }
    $expectedDirs = @('bootstrap','bootstrap/cache','data','runtime','storage','storage/app','storage/app/private','storage/app/public','storage/framework','storage/framework/cache','storage/framework/cache/data','storage/framework/sessions','storage/framework/testing','storage/framework/views','storage/logs') | Sort-Object
    $actualDirs = @(Get-ChildItem -LiteralPath $InstanceRoot -Recurse -Directory -Force | ForEach-Object { $_.FullName.Substring($InstanceRoot.Length + 1).Replace('\','/') } | Sort-Object)
    if (($actualDirs -join "`n") -ne ($expectedDirs -join "`n")) { throw 'BLOCKED_PARTIAL_INIT_DIRECTORY_INVENTORY' }
    if (-not (Test-Path -LiteralPath $KeyFile -PathType Leaf) -or -not (Test-Path -LiteralPath $PasswordFile -PathType Leaf)) { throw 'BLOCKED_PARTIAL_INIT_PRIVATE_MATERIAL_MISSING' }
    $key = [IO.File]::ReadAllText($KeyFile).Trim()
    $password = [IO.File]::ReadAllText($PasswordFile).Trim()
    if ($key -notmatch '^base64:[A-Za-z0-9+/]{43}=$' -or [Convert]::FromBase64String($key.Substring(7)).Length -ne 32 -or $password.Length -lt 32) { throw 'BLOCKED_PARTIAL_INIT_PRIVATE_MATERIAL_INVALID' }
    Assert-NoReparseAncestors $InstanceRoot
}

function Assert-Roots {
    $script:RepoRoot = Get-FullPath $RepoRoot
    $script:RuntimeHome = Get-FullPath $RuntimeHome
    $script:InstanceRoot = Get-FullPath $InstanceRoot
    $script:PrivateRoot = Get-FullPath $PrivateRoot
    $script:KeyFile = Get-FullPath $KeyFile
    $script:PasswordFile = Get-FullPath $PasswordFile
    $script:PhpExe = Get-FullPath $PhpExe
    if (-not (Test-UnderRoot $InstanceRoot $RuntimeHome) -or $InstanceRoot.Equals($RuntimeHome, [StringComparison]::OrdinalIgnoreCase)) { throw 'BLOCKED_INSTANCE_ROOT_OUTSIDE_PRIVATE_RUNTIME' }
    if (-not (Test-UnderRoot $KeyFile $PrivateRoot) -or -not (Test-UnderRoot $PasswordFile $PrivateRoot)) { throw 'BLOCKED_KEY_OR_PASSWORD_OUTSIDE_PRIVATE_ROOT' }
    if (Test-UnderRoot $InstanceRoot $RepoRoot) { throw 'BLOCKED_INSTANCE_INSIDE_REPOSITORY' }
    foreach ($path in @($RuntimeHome, $PrivateRoot, $InstanceRoot, (Split-Path -Parent $KeyFile), (Split-Path -Parent $PasswordFile))) { Assert-NoReparseAncestors $path }
    Assert-PrivateAcl $RuntimeHome
    Assert-PrivateAcl $PrivateRoot
    if (-not (Test-Path -LiteralPath $PhpExe -PathType Leaf) -or -not (Test-Path -LiteralPath (Join-Path $RepoRoot 'server\vendor\autoload.php') -PathType Leaf)) { throw 'BLOCKED_PHP_OR_VENDOR_MISSING' }
}

Assert-Roots
$script:InstanceId = $null
$instanceMarker = Get-InstanceMarker
if ($instanceMarker) { $script:InstanceId = [string]$instanceMarker.id }

if ($Action -eq 'Init') {
    if ($instanceMarker) { throw 'BLOCKED_INIT_ALREADY_COMPLETE' }
    $resumeInit = Test-Path -LiteralPath $InstanceRoot -PathType Container
    $initLock = New-OperationLock (Join-Path $RuntimeHome 'instance-a.init.lock')
    try {
        if ($resumeInit) {
            Assert-PartialInitSafe
        } else {
            if (Test-Path -LiteralPath $InstanceRoot) { throw 'BLOCKED_INIT_ROOT_RACE' }
            [IO.Directory]::CreateDirectory($InstanceRoot) | Out-Null
            $folders = @('bootstrap\cache','data','runtime','storage\app\private','storage\app\public','storage\framework\cache\data','storage\framework\sessions','storage\framework\views','storage\framework\testing','storage\logs')
            foreach ($folder in $folders) { [IO.Directory]::CreateDirectory((Join-Path $InstanceRoot $folder)) | Out-Null }
        }
        $lock = New-OperationLock (Join-Path $InstanceRoot 'runtime\operation.lock')
        try {
            if (-not $resumeInit) {
                if (Test-Path -LiteralPath $KeyFile) { throw 'BLOCKED_KEYFILE_ALREADY_EXISTS' }
                if (Test-Path -LiteralPath $PasswordFile) { throw 'BLOCKED_PASSWORDFILE_ALREADY_EXISTS' }
                New-ExclusiveText $KeyFile ('base64:' + (Get-RandomText 32) + "`n")
                New-ExclusiveText $PasswordFile ((Get-RandomText 36 $true) + "`n")
            }
            $script:InstanceId = [guid]::NewGuid().ToString('D')
            $key = [IO.File]::ReadAllText($KeyFile).Trim()
            $password = [IO.File]::ReadAllText($PasswordFile).Trim()
            if ($key -notmatch '^base64:[A-Za-z0-9+/]{43}=$' -or [Convert]::FromBase64String($key.Substring(7)).Length -ne 32) { throw 'BLOCKED_KEYFILE_FORMAT' }
            $values = Get-C30Environment $key $Port
            $runId = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
            $scopeAction = if ($resumeInit) { 'scope' } else { 'paths' }
            $scope = Invoke-C30Php @('..\scripts\local\picoradar-local-qa.php',$scopeAction) $values
            Write-RunLog "C30_A_PATHS_PREFLIGHT_$runId.json" $scope | Out-Null
            $scopeEvidence = $scope | ConvertFrom-Json
            if ($scopeEvidence.status -ne 'PASS') { throw 'BLOCKED_PATHS_PREFLIGHT_NOT_PASS' }
            if (-not $resumeInit) {
                $created = Invoke-C30Php @('..\scripts\local\picoradar-local-qa.php','create-db') $values
                Write-RunLog "C30_A_EMPTY_DATABASE_CREATE_$runId.json" $created | Out-Null
            }
            $dbcheck = Invoke-C30Php @('..\scripts\local\picoradar-local-qa.php','preflight') $values
            Write-RunLog "C30_A_READONLY_PDO_PREFLIGHT_$runId.json" $dbcheck | Out-Null
            $dbEvidence = $dbcheck | ConvertFrom-Json
            if ($dbEvidence.status -ne 'PASS' -or [int]$dbEvidence.evidence.sqlite_table_count -ne 0) { throw 'BLOCKED_DATABASE_PREFLIGHT_NOT_PASS_OR_NOT_EMPTY' }
            $migration = Invoke-C30Php @('artisan','migrate','--no-interaction') $values
            Write-RunLog "C30_A_MIGRATE_$runId.log" $migration | Out-Null
            $values.PICORADAR_OPERATOR_PASSWORD = $password
            $fixture = Invoke-C30Php @('..\scripts\local\picoradar-local-qa.php','seed') $values
            Write-RunLog "C30_A_FIXTURE_$runId.json" $fixture | Out-Null
            $fixtureJson = $fixture | ConvertFrom-Json
            if ($fixtureJson.status -ne 'PASS') { throw 'BLOCKED_FIXTURE_NOT_PASS' }
            $sentinelPrivate = Join-Path $InstanceRoot 'storage\app\private\c30-synthetic-private.txt'
            $sentinelPublic = Join-Path $InstanceRoot 'storage\app\public\c30-synthetic-public.txt'
            New-ExclusiveText $sentinelPrivate "C30_PRIVATE_SYNTHETIC_SENTINEL_v1`n"
            New-ExclusiveText $sentinelPublic "C30_PUBLIC_SYNTHETIC_SENTINEL_v1`n"
            $head = (& git -C $RepoRoot rev-parse HEAD).Trim()
            if ($LASTEXITCODE -ne 0) { throw 'BLOCKED_GIT_HEAD_UNAVAILABLE' }
            $metadata = [ordered]@{
                format='picoradar-local-qa/1'; id=$script:InstanceId; backend='sqlite'; scope='NON_PRODUCTION_SYNTHETIC'
                code_head=$head; state='initialized'; paths=[ordered]@{
                    database='data/picoradar.sqlite'; private_storage='storage/app/private'; public_storage='storage/app/public'
                    runtime='runtime'; bootstrap_cache='bootstrap/cache'
                }
            }
            New-ExclusiveText (Join-Path $InstanceRoot 'instance.json') (($metadata | ConvertTo-Json -Depth 6) + "`n")
            $summary = [ordered]@{
                status='PASS'; instance_id=$script:InstanceId; code_head=$head; backend='sqlite'; scope='NON_PRODUCTION_SYNTHETIC'
                database='runtime/instance-a/data/picoradar.sqlite'; fixture=$fixtureJson.fixture
                sentinel_private_sha256=(Get-FileHash -LiteralPath $sentinelPrivate -Algorithm SHA256).Hash
                sentinel_public_sha256=(Get-FileHash -LiteralPath $sentinelPublic -Algorithm SHA256).Hash
                path_preflight=$scopeEvidence.evidence; readonly_pdo_preflight=$dbEvidence.evidence
            }
            Write-RunLog "C30_A_INIT_SUMMARY_$runId.json" (($summary | ConvertTo-Json -Depth 12)) | Out-Null
            $summary | ConvertTo-Json -Depth 12
        } finally { $lock.Dispose() }
    } finally { $initLock.Dispose() }
    exit 0
}

if (-not $instanceMarker) { throw 'BLOCKED_INSTANCE_NOT_INITIALIZED' }
$processPath = Get-ProcessMarkerPath
$operationLock = New-OperationLock (Join-Path $InstanceRoot 'runtime\operation.lock')
try {
    if ($Action -eq 'Status') {
        if (-not (Test-Path -LiteralPath $processPath -PathType Leaf)) {
            $lastPortPath = Join-Path $InstanceRoot 'runtime\last-port.json'
            if (Test-Path -LiteralPath $lastPortPath -PathType Leaf) {
                $lastPort = Get-Content -LiteralPath $lastPortPath -Raw | ConvertFrom-Json
                Assert-NoOrphanC30Listener ([int]$lastPort.port)
            }
            @{ status='STOPPED'; instance_id=$script:InstanceId; backend='sqlite'; scope='NON_PRODUCTION_SYNTHETIC' } | ConvertTo-Json -Compress
            exit 0
        }
        $processMarker = Get-Content -LiteralPath $processPath -Raw | ConvertFrom-Json
        $process = Get-VerifiedProcess $processMarker
        @{ status='RUNNING'; instance_id=$script:InstanceId; pid=$process.Id; port=[int]$processMarker.port; start_time_utc=$process.StartTime.ToUniversalTime().ToString('o') } | ConvertTo-Json -Compress
        exit 0
    }
    if ($Action -eq 'Start') {
        if (Test-Path -LiteralPath $processPath) { throw 'BLOCKED_PROCESS_MARKER_ALREADY_EXISTS' }
        $lastPortPath = Join-Path $InstanceRoot 'runtime\last-port.json'
        if (Test-Path -LiteralPath $lastPortPath -PathType Leaf) {
            $lastPort = Get-Content -LiteralPath $lastPortPath -Raw | ConvertFrom-Json
            Assert-NoOrphanC30Listener ([int]$lastPort.port)
        }
        $key = [IO.File]::ReadAllText($KeyFile).Trim()
        if ($key -notmatch '^base64:[A-Za-z0-9+/]{43}=$') { throw 'BLOCKED_KEYFILE_INVALID' }
        $check = Invoke-C30Php @('..\scripts\local\picoradar-local-qa.php','preflight') (Get-C30Environment $key $Port)
        Write-RunLog ('C30_A_START_PREFLIGHT_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.json') $check | Out-Null
        $preflight = $check | ConvertFrom-Json
        if ($preflight.status -ne 'PASS') { throw 'BLOCKED_START_PREFLIGHT_NOT_PASS' }
        $selectedPort = $Port
        while ($selectedPort -lt 65535 -and @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $selectedPort -ErrorAction SilentlyContinue).Count -gt 0) { $selectedPort++ }
        if ($selectedPort -ge 65535) { throw 'BLOCKED_NO_LOOPBACK_PORT' }
        $reportLogs = Join-Path $ReportRoot 'logs\A'
        [IO.Directory]::CreateDirectory($reportLogs) | Out-Null
        $logId = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
        $stdout = Join-Path $reportLogs ('C30_A_PHP_SERVER_' + $selectedPort + '_' + $logId + '.out.log')
        $stderr = Join-Path $reportLogs ('C30_A_PHP_SERVER_' + $selectedPort + '_' + $logId + '.err.log')
        if ((Test-Path $stdout) -or (Test-Path $stderr)) { throw 'BLOCKED_SERVER_LOG_EXISTS' }
        $values = Get-C30Environment $key $selectedPort
        $old = @{}
        $envNames = @((Get-ChildItem Env: | Where-Object Name -Match '^(APP_|DB_|MAIL_|REDIS_|SESSION_|CACHE_|QUEUE_|FILESYSTEM_|DATASET_|CAMPAIGN_|PICORADAR_)|^(DATABASE_URL)$' | Select-Object -ExpandProperty Name))
        $envNames += @($values.Keys)
        $envNames = @($envNames | Sort-Object -Unique)
        foreach ($name in $envNames) { $old[$name] = [Environment]::GetEnvironmentVariable($name,'Process'); [Environment]::SetEnvironmentVariable($name,$null,'Process') }
        $oldPath = [Environment]::GetEnvironmentVariable('PATH','Process')
        try {
            foreach ($name in $values.Keys) { [Environment]::SetEnvironmentVariable($name,[string]$values[$name],'Process') }
            $phpDir = Split-Path -Parent $PhpExe
            [Environment]::SetEnvironmentVariable('PATH',"$phpDir;$phpDir\ext;$oldPath",'Process')
            $router = Get-FullPath (Join-Path $PSScriptRoot 'picoradar-local-qa.php')
            $phpArgs = @('-d', 'extension_dir=C:\xampphp\php\ext', '-d', 'extension=php_sqlite3.dll', '-d', 'extension=php_pdo_sqlite.dll', '-S', "127.0.0.1:$selectedPort", '-t', (Join-Path $RepoRoot 'server\public'), $router)
            $serverProcess = Start-Process -FilePath $PhpExe -ArgumentList $phpArgs -WorkingDirectory (Join-Path $RepoRoot 'server') -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        } finally {
            [Environment]::SetEnvironmentVariable('PATH',$oldPath,'Process')
            foreach ($name in $envNames) { [Environment]::SetEnvironmentVariable($name,$old[$name],'Process') }
        }
        $ready = $false
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Milliseconds 300
            $listener = @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $selectedPort -ErrorAction SilentlyContinue)
            if ($serverProcess.HasExited) { break }
            if ($listener.Count -eq 1 -and [int]$listener[0].OwningProcess -eq $serverProcess.Id) {
                try { $r = Invoke-WebRequest -Uri "http://127.0.0.1:$selectedPort/up" -TimeoutSec 3; if ([int]$r.StatusCode -eq 200) { $ready = $true; break } } catch { }
            }
        }
        if (-not $ready) {
            if (-not $serverProcess.HasExited) { Stop-Process -Id $serverProcess.Id -ErrorAction SilentlyContinue; $serverProcess.WaitForExit(5000) | Out-Null }
            throw 'BLOCKED_SERVER_BIND_OR_HEALTHCHECK'
        }
        $actual = Get-Process -Id $serverProcess.Id
        $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$($serverProcess.Id)"
        $processMarker = [ordered]@{
            format='picoradar-local-process/1'; instanceId=$script:InstanceId; pid=$serverProcess.Id
            startTimeUtc=$actual.StartTime.ToUniversalTime().ToString('o'); executable=(Get-FullPath $actual.Path)
            port=$selectedPort; commandline_sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes([string]$cim.CommandLine)))
        }
        try {
            if (Test-Path -LiteralPath $lastPortPath -PathType Leaf) {
                $oldPortMarker = Get-Content -LiteralPath $lastPortPath -Raw | ConvertFrom-Json
                if ([string]$oldPortMarker.instance_id -ne $script:InstanceId) { throw 'BLOCKED_LAST_PORT_MARKER_INSTANCE_MISMATCH' }
                Write-OwnedText $lastPortPath (([ordered]@{ instance_id=$script:InstanceId; port=$selectedPort } | ConvertTo-Json -Compress) + "`n")
            } else {
                New-ExclusiveText $lastPortPath (([ordered]@{ instance_id=$script:InstanceId; port=$selectedPort } | ConvertTo-Json -Compress) + "`n")
            }
            New-ExclusiveText $processPath (($processMarker | ConvertTo-Json -Depth 4) + "`n")
        } catch {
            if (-not $serverProcess.HasExited) { Stop-Process -Id $serverProcess.Id -ErrorAction SilentlyContinue; $serverProcess.WaitForExit(5000) | Out-Null }
            throw
        }
        @{ status='RUNNING'; instance_id=$script:InstanceId; pid=$serverProcess.Id; port=$selectedPort; start_time_utc=$processMarker.startTimeUtc; health='/up:200' } | ConvertTo-Json -Compress
        exit 0
    }
    if ($Action -eq 'Stop') {
        if (-not (Test-Path -LiteralPath $processPath -PathType Leaf)) {
            @{ status='STOPPED'; instance_id=$script:InstanceId; evidence='NO_PROCESS_MARKER' } | ConvertTo-Json -Compress
            exit 0
        }
        $processMarker = Get-Content -LiteralPath $processPath -Raw | ConvertFrom-Json
        $process = Get-VerifiedProcess $processMarker
        Stop-Process -Id $process.Id
        $process.WaitForExit(10000) | Out-Null
        if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) { throw 'BLOCKED_PROCESS_DID_NOT_EXIT' }
        $listenerAfter = @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort ([int]$processMarker.port) -ErrorAction SilentlyContinue)
        if ($listenerAfter.Count -gt 0) { throw 'BLOCKED_LISTENER_REMAINS' }
        Remove-Item -LiteralPath $processPath
        @{ status='STOPPED'; instance_id=$script:InstanceId; pid=$process.Id; listener_closed=$true } | ConvertTo-Json -Compress
        exit 0
    }
} finally { $operationLock.Dispose() }
