[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Init', 'PrepareEditorial', 'Start', 'Stop', 'Status', 'RecoverStopped')][string]$Action,
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$RuntimeHome = 'D:\codex\_build\PicoRadar-C30-V2\runtime',
    [string]$InstanceRoot = 'D:\codex\_build\PicoRadar-C30-V2\runtime\instance-a',
    [string]$PrivateRoot = 'D:\codex\_build\PicoRadar-C30-V2\private',
    [string]$KeyFile = 'D:\codex\_build\PicoRadar-C30-V2\private\instance-a.app-key',
    [string]$PasswordFile = 'D:\codex\_build\PicoRadar-C30-V2\private\operator.qa.password',
    [string]$EditorialPrivateRoot,
    [string]$HistoricalRouterPath,
    [string]$ExpectedInstanceId,
    [string]$PhpExe = 'C:\xampphp\php\php.exe',
    [string]$ReportRoot = 'D:\codex\_REPORTES\PicoRadar\C30-V2-20261126',
    [ValidateRange(1024, 65535)][int]$Port = 8878,
    [switch]$EditorialQa
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:InvocationBoundParameters = $PSBoundParameters
Import-Module (Join-Path $PSScriptRoot 'picoradar-local-qa-recovery.psm1') -Force -ErrorAction Stop

function Get-FullPath([string]$Path) { [IO.Path]::GetFullPath($Path).TrimEnd('\') }

function Assert-EditorialParametersExplicit {
    foreach ($name in @('RepoRoot','RuntimeHome','InstanceRoot','PrivateRoot','KeyFile','PasswordFile','PhpExe','ReportRoot','Port','EditorialPrivateRoot','ExpectedInstanceId')) {
        if (-not $script:InvocationBoundParameters.ContainsKey($name)) { throw "BLOCKED_EDITORIAL_PARAMETER_REQUIRED_$name" }
    }
}

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

function Assert-PrivateFileAcl([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'BLOCKED_PRIVATE_FILE_MISSING' }
    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'BLOCKED_PRIVATE_FILE_REPARSE_POINT' }
    $acl = Get-Acl -LiteralPath $Path
    $expected = @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value, 'S-1-5-18', 'S-1-5-32-544')
    $rules = $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])
    foreach ($rule in $rules) {
        if ($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or $rule.IdentityReference.Value -notin $expected) {
            throw 'BLOCKED_PRIVATE_FILE_ACL_PRINCIPAL'
        }
    }
    foreach ($sid in $expected) {
        if (-not ($rules | Where-Object { $_.IdentityReference.Value -eq $sid -and ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) -eq [Security.AccessControl.FileSystemRights]::FullControl })) {
            throw 'BLOCKED_PRIVATE_FILE_ACL_INCOMPLETE'
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

function Get-EditorialEntryMode {
    $name = [IO.Path]::GetFileName($InstanceRoot)
    if ($name -cmatch '^instance-restored-c31-[A-Za-z0-9][A-Za-z0-9_-]{0,63}$') { return 'RESTORED' }
    $runtimeParentName = [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($RuntimeHome))
    if ($name -ceq 'instance-a' -and $runtimeParentName -cmatch '^PicoRadar-C31-V2(?:-[A-Za-z0-9_-]+)?$') { return 'FRESH_ISOLATED' }
    throw 'BLOCKED_EDITORIAL_INSTANCE_ROOT_NOT_C31_SLOT'
}

function Assert-EditorialPrivateRoot {
    if ([string]::IsNullOrWhiteSpace($EditorialPrivateRoot)) { throw 'BLOCKED_EDITORIAL_PRIVATE_ROOT_REQUIRED' }
    $script:EditorialPrivateRoot = Get-FullPath $EditorialPrivateRoot
    Assert-NoReparseAncestors $script:EditorialPrivateRoot
    Assert-PrivateAcl $script:EditorialPrivateRoot
    foreach ($root in @($PrivateRoot, $RuntimeHome, $InstanceRoot, $RepoRoot)) {
        if ((Test-UnderRoot $script:EditorialPrivateRoot $root) -or (Test-UnderRoot $root $script:EditorialPrivateRoot)) {
            throw 'BLOCKED_EDITORIAL_PRIVATE_ROOT_NOT_SEPARATE'
        }
    }
}

function Get-EditorialCredentialPaths {
    if (-not $script:EditorialPrivateRoot) { throw 'BLOCKED_EDITORIAL_PRIVATE_ROOT_REQUIRED' }
    return Join-Path $script:EditorialPrivateRoot 'editor-c31.qa.credential.json'
}

function Assert-EditorialCredential {
    param([Parameter(Mandatory)][string]$ForInstanceId, [switch]$Create)
    $path = Get-EditorialCredentialPaths
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path -Force
        if ($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'BLOCKED_EDITORIAL_CREDENTIAL_FILE_TYPE' }
    }
    if (-not (Test-Path -LiteralPath $path) -and $Create) {
        $password = Get-RandomText 36 $true
        $credential = [ordered]@{
            format='picoradar-editorial-credential/1'; scope='NON_PRODUCTION_SYNTHETIC'
            instance_id=$ForInstanceId; password=$password
        }
        New-ExclusiveText $path (($credential | ConvertTo-Json -Compress) + "`n")
        Assert-PrivateFileAcl $path
        return $password
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'BLOCKED_EDITORIAL_CREDENTIAL_MISSING' }
    Assert-PrivateFileAcl $path
    $credential = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($credential.format -ne 'picoradar-editorial-credential/1' -or
        $credential.scope -ne 'NON_PRODUCTION_SYNTHETIC' -or
        [string]$credential.instance_id -cne $ForInstanceId -or
        [string]$credential.password -notmatch '^[A-Za-z0-9_-]{48}$') {
        throw 'BLOCKED_EDITORIAL_CREDENTIAL_INSTANCE_MISMATCH'
    }
    return [string]$credential.password
}

function Get-EditorialMarker {
    $path = Join-Path $InstanceRoot 'runtime\editorial-qa.json'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $item = Get-Item -LiteralPath $path -Force
    if ($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'BLOCKED_EDITORIAL_MARKER_FILE_TYPE' }
    $marker = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($marker.format -ne 'picoradar-editorial-qa/1' -or $marker.scope -ne 'NON_PRODUCTION_SYNTHETIC' -or
        $marker.prepared -ne $true -or [string]$marker.instance_id -cne $script:InstanceId -or
        [string]$marker.entry_mode -cne (Get-EditorialEntryMode)) {
        throw 'BLOCKED_EDITORIAL_MARKER_MISMATCH'
    }
    return $marker
}

function Assert-EditorialTarget {
    if ([string]::IsNullOrWhiteSpace($ExpectedInstanceId) -or $ExpectedInstanceId -cne $script:InstanceId) {
        throw 'BLOCKED_EDITORIAL_EXPECTED_INSTANCE_ID_MISMATCH'
    }
    $entryMode = Get-EditorialEntryMode
    if (-not $instanceMarker -or $instanceMarker.scope -ne 'NON_PRODUCTION_SYNTHETIC') { throw 'BLOCKED_EDITORIAL_INSTANCE_SCOPE' }
    Assert-EditorialPrivateRoot
    $credential = Assert-EditorialCredential -ForInstanceId $script:InstanceId
    $marker = Get-EditorialMarker
    if ($marker -and [string]$marker.entry_mode -cne $entryMode) { throw 'BLOCKED_EDITORIAL_ENTRY_MODE_MISMATCH' }
    return @{ EntryMode = $entryMode; Password = $credential; Marker = $marker }
}

function Assert-EditorialStopped([string]$ProcessPath) {
    if (Test-Path -LiteralPath $ProcessPath) { throw 'BLOCKED_EDITORIAL_INSTANCE_NOT_STOPPED' }
    $lastPortPath = Join-Path $InstanceRoot 'runtime\last-port.json'
    if (Test-Path -LiteralPath $lastPortPath -PathType Leaf) {
        $lastPort = Get-Content -LiteralPath $lastPortPath -Raw | ConvertFrom-Json
        if ([string]$lastPort.instance_id -cne $script:InstanceId) { throw 'BLOCKED_EDITORIAL_LAST_PORT_INSTANCE_MISMATCH' }
        Assert-NoOrphanC30Listener ([int]$lastPort.port)
    }
}

function Get-ProcessMarkerPath { Join-Path $InstanceRoot 'runtime\process.json' }
function Get-ListenerConnections([Nullable[int]]$Port) {
    if ($null -eq $Port) {
        return ,@(Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetTCPConnection -Filter 'State = 2' -ErrorAction Stop -OperationTimeoutSec 8)
    }
    return ,@(Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetTCPConnection -Filter "LocalPort = $([int]$Port) AND State = 2" -ErrorAction Stop -OperationTimeoutSec 8)
}

function Get-RecoveryRouterPaths {
    $paths=@((Get-FullPath (Join-Path $PSScriptRoot 'picoradar-local-qa.php')))
    if (-not [string]::IsNullOrWhiteSpace($HistoricalRouterPath)) {
        $historical=[IO.Path]::GetFullPath($HistoricalRouterPath)
        if (Test-Path -LiteralPath $historical) {
            Assert-NoReparseAncestors $historical
            if (-not (Test-Path -LiteralPath $historical -PathType Leaf)) { throw 'BLOCKED_HISTORICAL_ROUTER_NOT_FILE' }
            $paths+=@($historical)
        }
    }
    return @($paths|Select-Object -Unique)
}

function Read-RecoveryMarker([string]$Path,[int]$MaxBytes,[string]$Name) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "BLOCKED_$Name_NOT_REGULAR_FILE" }
    Assert-NoReparseAncestors $Path
    $item=Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $item.Length -lt 2 -or $item.Length -gt $MaxBytes) { throw "BLOCKED_$Name_FILE_SHAPE" }
    $bytes=[IO.File]::ReadAllBytes($Path)
    $text=[Text.UTF8Encoding]::new($false,$true).GetString($bytes)
    try {$value=ConvertFrom-Json -InputObject $text -ErrorAction Stop}catch{throw "BLOCKED_$Name_JSON_INVALID"}
    return [pscustomobject]@{Value=$value;Bytes=$bytes;Sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))}
}

function Get-RecoverySnapshot([Nullable[int]]$ProcessId,[Nullable[int]]$Port,[string[]]$RouterPaths) {
    $processes=@(Get-Process -ErrorAction Stop)
    $cim=@(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop -OperationTimeoutSec 8)
    $listeners=Get-ListenerConnections $Port
    $pidProcessPresent=$false
    $pidCimPresent=$false
    if ($null -ne $ProcessId) {
        $pidProcessPresent=@($processes|Where-Object Id -eq ([int]$ProcessId)).Count -gt 0
        $pidCimPresent=@($cim|Where-Object {[int]$_.ProcessId -eq ([int]$ProcessId)}).Count -gt 0
    }
    $slotWriter=$false;$ambiguousPhp=$false;$unverifiableListener=$false
    foreach($process in $cim) {
        if ([int]$process.ProcessId -eq $PID) { continue }
        $name=[string]$process.Name;$cmd=[string]$process.CommandLine;$isPhp=$name -in @('php.exe','php-cgi.exe')
        $matchesRouter=$false
        foreach($router in $RouterPaths) { if (-not [string]::IsNullOrWhiteSpace($cmd) -and $cmd.IndexOf($router,[StringComparison]::OrdinalIgnoreCase) -ge 0) {$matchesRouter=$true} }
        $matchesInstance=(-not [string]::IsNullOrWhiteSpace($cmd) -and $cmd.IndexOf($InstanceRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0)
        if ($isPhp -and ($matchesRouter -or $matchesInstance)) {$slotWriter=$true}
        if ($isPhp -and [string]::IsNullOrWhiteSpace($cmd)) {$ambiguousPhp=$true}
        if ($isPhp -and $cmd -match '(?i)(?:^|\s)-S(?:\s|$)' -and -not $matchesRouter -and -not $matchesInstance -and $cmd -notmatch '(?i)(?:[A-Z]:\\[^"]+\.php\b|\bartisan\b)') {$ambiguousPhp=$true}
    }
    foreach($listener in $listeners) {
        $owner=@($cim|Where-Object {[int]$_.ProcessId -eq [int]$listener.OwningProcess})
        if ($owner.Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$owner[0].CommandLine)) {$unverifiableListener=$true;continue}
        $ownerName=[string]$owner[0].Name;$ownerCommand=[string]$owner[0].CommandLine
        foreach($router in $RouterPaths) {if ($ownerCommand.IndexOf($router,[StringComparison]::OrdinalIgnoreCase) -ge 0) {$slotWriter=$true}}
        if ($ownerCommand.IndexOf($InstanceRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0) {$slotWriter=$true}
        if ($ownerName -in @('php.exe','php-cgi.exe') -and $ownerCommand -match '(?i)(?:^|\s)-S(?:\s|$)' -and $ownerCommand -notmatch '(?i)(?:[A-Z]:\\[^"]+\.php\b|\bartisan\b)' -and -not $slotWriter) {$unverifiableListener=$true}
    }
    return [pscustomobject]@{GetProcessQuery='PASS';CimQuery='PASS';ListenerQuery='PASS';ProcessInventoryQuery='PASS';PidPresent=($pidProcessPresent -or $pidCimPresent);ListenerCount=@($listeners).Count;SlotWriterPresent=$slotWriter;PhpServerAmbiguous=$ambiguousPhp;UnverifiableListener=$unverifiableListener;Listeners=@($listeners)}
}

function Assert-NoActiveInstanceServer([Nullable[int]]$Port) {
    $routers=Get-RecoveryRouterPaths;$probe=Get-RecoverySnapshot -ProcessId $null -Port $Port -RouterPaths $routers
    if ($probe.SlotWriterPresent) { throw 'BLOCKED_SLOT_PROCESS_WITHOUT_MARKER' }
    if ($probe.PhpServerAmbiguous) { throw 'BLOCKED_PHP_SERVER_AMBIGUOUS' }
    if ($probe.UnverifiableListener) { throw 'BLOCKED_LISTENER_OWNER_UNVERIFIABLE' }
}

function Assert-RecoveryParametersExplicit {
    foreach($name in @('RepoRoot','RuntimeHome','InstanceRoot','PrivateRoot','KeyFile','PasswordFile','PhpExe','ReportRoot','Port','ExpectedInstanceId','EditorialPrivateRoot','HistoricalRouterPath')) {
        if (-not $script:InvocationBoundParameters.ContainsKey($name)) { throw "BLOCKED_RECOVERY_PARAMETER_REQUIRED_$name" }
    }
    if ([string]::IsNullOrWhiteSpace($ExpectedInstanceId)) { throw 'BLOCKED_RECOVERY_EXPECTED_INSTANCE_ID_REQUIRED' }
}

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
    $modeProperty = $Marker.PSObject.Properties['mode']
    $mode = if ($modeProperty) { [string]$modeProperty.Value } else { 'C30_DEFAULT' }
    if ($mode -notin @('C30_DEFAULT','EDITORIAL_QA')) { throw 'BLOCKED_PROCESS_MODE_INVALID' }
    if ($mode -eq 'EDITORIAL_QA') {
        $editorialMarker = Get-EditorialMarker
        if (-not $editorialMarker -or [string]$Marker.entry_mode -cne [string]$editorialMarker.entry_mode) { throw 'BLOCKED_PROCESS_EDITORIAL_MODE_MISMATCH' }
    }
    $listenerFilter = "LocalAddress = '127.0.0.1' AND LocalPort = $([int]$Marker.port) AND State = 2"
    $listeners = @(Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetTCPConnection -Filter $listenerFilter -ErrorAction Stop -OperationTimeoutSec 8)
    if ($listeners.Count -ne 1 -or [int]$listeners[0].OwningProcess -ne [int]$Marker.pid) { throw 'BLOCKED_PROCESS_LISTENER_MISMATCH' }
    if ([string]$Marker.instanceId -ne [string]$script:InstanceId) { throw 'BLOCKED_PROCESS_INSTANCE_MISMATCH' }
    return $process
}

function Assert-NoOrphanC30Listener([int]$ListenerPort) {
    $routers=Get-RecoveryRouterPaths
    $probe=Get-RecoverySnapshot -ProcessId $null -Port $ListenerPort -RouterPaths $routers
    if ($probe.SlotWriterPresent) { throw 'BLOCKED_UNVERIFIABLE_C30_LISTENER' }
    if ($probe.PhpServerAmbiguous -or $probe.UnverifiableListener) { throw 'BLOCKED_UNVERIFIABLE_C30_LISTENER' }
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
        PICORADAR_EDITORIAL_QA='0'; PICORADAR_EDITORIAL_EXPECTED_INSTANCE_ID=''; PICORADAR_EDITORIAL_ENTRY_MODE=''
    }
    if ($IncludePassword) { $values.PICORADAR_OPERATOR_PASSWORD = [IO.File]::ReadAllText($PasswordFile).Trim() }
    return $values
}

function Invoke-C30Php([string[]]$PhpArguments, [hashtable]$Values) {
    $names = @((Get-ChildItem Env: | Where-Object Name -Match '^(APP_|DB_|MAIL_|REDIS_|SESSION_|CACHE_|QUEUE_|FILESYSTEM_|DATASET_|CAMPAIGN_|PICORADAR_)|^(DATABASE_URL)$' | Select-Object -ExpandProperty Name))
    $names += @('APP_ENV','APP_DEBUG','APP_KEY','APP_NAME','APP_URL','APP_CONFIG_CACHE','APP_ROUTES_CACHE','APP_EVENTS_CACHE','APP_PACKAGES_CACHE','APP_SERVICES_CACHE','VIEW_COMPILED_PATH','LARAVEL_STORAGE_PATH','PICORADAR_PUBLIC_PATH','PICORADAR_INSTANCE_ROOT','PICORADAR_INSTANCE_ID','PICORADAR_OPERATOR_PASSWORD','PICORADAR_EDITOR_PASSWORD','PICORADAR_EDITORIAL_QA','PICORADAR_EDITORIAL_EXPECTED_INSTANCE_ID','PICORADAR_EDITORIAL_ENTRY_MODE','DB_CONNECTION','DB_URL','DATABASE_URL','DB_DATABASE','DB_FOREIGN_KEYS','SESSION_DRIVER','CACHE_STORE','QUEUE_CONNECTION','MAIL_MAILER','LOG_CHANNEL','LOG_LEVEL','FILESYSTEM_DISK','DATASET_DRAFT_DISK','DATASET_PUBLISHED_DISK','DATASET_PUBLIC_BASE_URL','CAMPAIGN_PUBLIC_CATALOG_ENABLED','PICORADAR_ACCOUNT_EMAIL_ENABLED','PICORADAR_MARKETING_SEND_ENABLED','PICORADAR_PUBLIC_CATALOG_ENABLED','PICORADAR_QA_LOCAL')
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
$instanceMarker = $null
if ($Action -ne 'RecoverStopped') {
    $instanceMarker = Get-InstanceMarker
    if ($instanceMarker) { $script:InstanceId = [string]$instanceMarker.id }
}
if ($EditorialQa -and $Action -ne 'Start') { throw 'BLOCKED_EDITORIAL_SWITCH_ONLY_VALID_FOR_START' }

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

if ($Action -eq 'RecoverStopped') {
    Assert-RecoveryParametersExplicit
    if ($ExpectedInstanceId -cnotmatch '^[0-9a-fA-F-]{36}$') { throw 'BLOCKED_RECOVERY_EXPECTED_INSTANCE_ID_INVALID' }
    $recoveryLock=New-OperationLock (Join-Path $InstanceRoot 'runtime\operation.lock')
    try {
        $instanceMarker=Get-InstanceMarker
        if (-not $instanceMarker) { throw 'BLOCKED_INSTANCE_NOT_INITIALIZED' }
        $script:InstanceId=[string]$instanceMarker.id
        if ($script:InstanceId -cne $ExpectedInstanceId) { throw 'BLOCKED_RECOVERY_INSTANCE_ID_MISMATCH' }
        $routers=Get-RecoveryRouterPaths;$processPath=Get-ProcessMarkerPath;$lastPath=Join-Path $InstanceRoot 'runtime\last-port.json'
        $processData=Read-RecoveryMarker $processPath 4096 'PROCESS_MARKER';$lastData=Read-RecoveryMarker $lastPath 1024 'LAST_PORT_MARKER'
        $targetPort=$null;$pidValue=$null;$markerValid=$true;$lastPortMatches=$true
        if ($processData) {
            $editorialEntry=$null;$rawMode=[string]$processData.Value.mode
            if ($rawMode -ceq 'EDITORIAL_QA') {Assert-EditorialPrivateRoot;$editorialMarker=Get-EditorialMarker;if (-not $editorialMarker) {throw 'BLOCKED_EDITORIAL_MARKER_MISSING'};$editorialEntry=[string]$editorialMarker.entry_mode}
            $processValidation=Test-PicoRadarRecoveryMarker -Marker $processData.Value -ExpectedInstanceId $script:InstanceId -PhpExe $PhpExe -EditorialEntryMode $editorialEntry
            $markerValid=[bool]$processValidation.Valid
            if (-not $markerValid) { throw ('BLOCKED_PROCESS_MARKER_' + [string]$processValidation.Reason) }
            $pidValue=[int]$processValidation.Pid;$targetPort=[int]$processValidation.Port
            if (-not $lastData) { throw 'BLOCKED_LAST_PORT_MARKER_MISSING' }
            $lastId=[string]$lastData.Value.instance_id;$lastPort=0
            $lastPortParsed=[int]::TryParse([string]$lastData.Value.port,[ref]$lastPort)
            $lastPortMatches=$lastPortParsed -and $lastId -ceq $script:InstanceId -and $lastPort -eq $targetPort
            if (-not $lastPortMatches) { throw 'BLOCKED_LAST_PORT_MARKER_MISMATCH' }
        } elseif ($lastData) {
            $lastId=[string]$lastData.Value.instance_id;$lastPort=0
            if (-not [int]::TryParse([string]$lastData.Value.port,[ref]$lastPort) -or $lastPort -lt 1024 -or $lastPort -gt 65535 -or $lastId -cne $script:InstanceId) { throw 'BLOCKED_LAST_PORT_MARKER_INVALID' }
            $targetPort=$lastPort
        }
        $first=Get-RecoverySnapshot -ProcessId $pidValue -Port $targetPort -RouterPaths $routers
        Start-Sleep -Milliseconds 300
        $second=Get-RecoverySnapshot -ProcessId $pidValue -Port $targetPort -RouterPaths $routers
        if ($processData) {
            $processAgain=Read-RecoveryMarker $processPath 4096 'PROCESS_MARKER';$lastAgain=Read-RecoveryMarker $lastPath 1024 'LAST_PORT_MARKER'
            if (-not $processAgain -or $processAgain.Sha256 -cne $processData.Sha256) { throw 'BLOCKED_PROCESS_MARKER_CHANGED_DURING_PROBE' }
            if (-not $lastAgain -or $lastAgain.Sha256 -cne $lastData.Sha256) { throw 'BLOCKED_LAST_PORT_MARKER_CHANGED_DURING_PROBE' }
            $destination=Join-Path (Split-Path -Parent $processPath) ('process.stale-'+[guid]::NewGuid().ToString('N')+'.json')
            $facts=@{MarkerValid=$markerValid;InstanceMatches=($script:InstanceId -ceq $ExpectedInstanceId);LastPortMatches=$lastPortMatches;GetProcessQuery='PASS';CimQuery='PASS';ListenerQuery='PASS';ProcessInventoryQuery='PASS';PidPresent=([bool]$first.PidPresent -or [bool]$second.PidPresent);ListenerPresent=([int]$first.ListenerCount -gt 0 -or [int]$second.ListenerCount -gt 0);SlotWriterPresent=([bool]$first.SlotWriterPresent -or [bool]$second.SlotWriterPresent);PhpServerAmbiguous=([bool]$first.PhpServerAmbiguous -or [bool]$second.PhpServerAmbiguous -or [bool]$first.UnverifiableListener -or [bool]$second.UnverifiableListener);DestinationExists=(Test-Path -LiteralPath $destination)}
            $decision=Get-PicoRadarRecoveryDecision -Facts $facts
            if ($decision.Action -ne 'ARCHIVE') { throw ('BLOCKED_RECOVERY_' + [string]$decision.Reason) }
            $archive=Move-PicoRadarRecoveryMarker -SourcePath $processPath -DestinationPath $destination -ExpectedSha256 $processData.Sha256
            [ordered]@{status='RECOVERED_STOPPED';instance_id=$script:InstanceId;pid=$pidValue;port=$targetPort;marker_archive=(Split-Path -Leaf $archive.DestinationPath);marker_sha256=$archive.Sha256;process_absent_twice=$true;listener_absent_twice=$true;historical_router_checked=($routers.Count -gt 1)}|ConvertTo-Json -Compress
        } else {
            if ($first.PidPresent -or $second.PidPresent -or $first.ListenerCount -gt 0 -or $second.ListenerCount -gt 0 -or $first.SlotWriterPresent -or $second.SlotWriterPresent -or $first.PhpServerAmbiguous -or $second.PhpServerAmbiguous -or $first.UnverifiableListener -or $second.UnverifiableListener) { throw 'BLOCKED_RECOVERY_NO_MARKER_BUT_PROCESS_OR_LISTENER_PRESENT' }
            [ordered]@{status='RECOVERY_NOT_REQUIRED';instance_id=$script:InstanceId;process_marker_absent=$true;process_inventory_checked_twice=$true;historical_router_checked=($routers.Count -gt 1)}|ConvertTo-Json -Compress
        }
    } finally { $recoveryLock.Dispose() }
    exit 0
}
if (-not $instanceMarker) { throw 'BLOCKED_INSTANCE_NOT_INITIALIZED' }
$processPath = Get-ProcessMarkerPath

if ($Action -eq 'PrepareEditorial') {
    Assert-EditorialParametersExplicit
    if (-not $ExpectedInstanceId -or $ExpectedInstanceId -cne $script:InstanceId) { throw 'BLOCKED_EDITORIAL_EXPECTED_INSTANCE_ID_MISMATCH' }
    $entryMode = Get-EditorialEntryMode
    Assert-EditorialPrivateRoot
    $lock = New-OperationLock (Join-Path $InstanceRoot 'runtime\operation.lock')
    try {
        Assert-EditorialStopped $processPath
        $key = [IO.File]::ReadAllText($KeyFile).Trim()
        if ($key -notmatch '^base64:[A-Za-z0-9+/]{43}=$') { throw 'BLOCKED_KEYFILE_INVALID' }
        $values = Get-C30Environment $key $Port
        $preflight = Invoke-C30Php @('..\scripts\local\picoradar-local-qa.php','preflight') $values | ConvertFrom-Json
        if ($preflight.status -ne 'PASS') { throw 'BLOCKED_EDITORIAL_PREFLIGHT_NOT_PASS' }
        if ([int]$preflight.evidence.config.campaign_catalog -ne 0 -or
            $preflight.evidence.config.environment -ne 'local' -or
            $preflight.evidence.config.debug -ne $false -or
            $preflight.evidence.config.database -ne 'sqlite') { throw 'BLOCKED_EDITORIAL_PREFLIGHT_CONFIG' }

        $editorPassword = Assert-EditorialCredential -ForInstanceId $script:InstanceId -Create
        $values.PICORADAR_EDITORIAL_EXPECTED_INSTANCE_ID = $script:InstanceId
        $values.PICORADAR_EDITORIAL_ENTRY_MODE = $entryMode
        $values.PICORADAR_EDITOR_PASSWORD = $editorPassword
        $resultText = Invoke-C30Php @('..\scripts\local\picoradar-local-qa.php','prepare-editorial') $values
        $result = $resultText | ConvertFrom-Json
        if ($result.status -ne 'PASS' -or $result.prepared -ne $true -or
            [string]$result.instance_id -cne $script:InstanceId -or
            [string]$result.entry_mode -cne $entryMode) { throw 'BLOCKED_EDITORIAL_PREPARATION_RESULT_INVALID' }
        $marker = Get-EditorialMarker
        if (-not $marker) { throw 'BLOCKED_EDITORIAL_MARKER_NOT_WRITTEN' }
        $runId = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
        Write-RunLog "C31_A_EDITORIAL_PREP_$runId.json" ($result | ConvertTo-Json -Depth 6) | Out-Null
        [ordered]@{
            status='PASS'; prepared=$true; idempotent=[bool]$result.idempotent
            instance_id=$script:InstanceId; entry_mode=$entryMode; dataset_id=$result.dataset_id
            country_code=$result.country_code; department_code=$result.department_code; municipality_code=$result.municipality_code
            municipality_id=$result.municipality_id; jurisdiction_id=$result.jurisdiction_id; jurisdiction_enabled=$result.jurisdiction_enabled
            editor_id=$result.editor_id; source_id=$result.source_id; release_count=$result.release_count
            publication_count=$result.publication_count; rule_count=$result.rule_count
        } | ConvertTo-Json -Depth 6
    } finally { $lock.Dispose() }
    exit 0
}

$operationLock = New-OperationLock (Join-Path $InstanceRoot 'runtime\operation.lock')
try {
    if ($Action -eq 'Status') {
        $editorialMarker = Get-EditorialMarker
        $mode = if ($editorialMarker) { 'EDITORIAL_QA' } else { 'C30_DEFAULT' }
        if (-not (Test-Path -LiteralPath $processPath -PathType Leaf)) {
            $lastPortPath = Join-Path $InstanceRoot 'runtime\last-port.json'
            $knownPort = $null
            if (Test-Path -LiteralPath $lastPortPath) {
                $lastPortData = Read-RecoveryMarker $lastPortPath 1024 'LAST_PORT_MARKER'
                $lastPortValue = 0
                if (-not [int]::TryParse([string]$lastPortData.Value.port,[ref]$lastPortValue) -or [string]$lastPortData.Value.instance_id -cne $script:InstanceId) { throw 'BLOCKED_LAST_PORT_MARKER_INVALID' }
                $knownPort = $lastPortValue
            }
            Assert-NoActiveInstanceServer $knownPort
            @{ status='STOPPED'; instance_id=$script:InstanceId; backend='sqlite'; scope='NON_PRODUCTION_SYNTHETIC'; mode=$mode; editorial_prepared=[bool]$editorialMarker; process_inventory_verified=$true } | ConvertTo-Json -Compress
            exit 0
        }
        $processMarker = Get-Content -LiteralPath $processPath -Raw | ConvertFrom-Json
        $process = Get-VerifiedProcess $processMarker
        $processMode = if ($processMarker.PSObject.Properties['mode']) { [string]$processMarker.mode } else { 'C30_DEFAULT' }
        @{ status='RUNNING'; instance_id=$script:InstanceId; pid=$process.Id; port=[int]$processMarker.port; start_time_utc=$process.StartTime.ToUniversalTime().ToString('o'); mode=$processMode; editorial_prepared=[bool]$editorialMarker } | ConvertTo-Json -Compress
        exit 0
    }
    if ($Action -eq 'Start') {
        if ($EditorialQa) { Assert-EditorialParametersExplicit }
        if (Test-Path -LiteralPath $processPath) { throw 'BLOCKED_PROCESS_MARKER_ALREADY_EXISTS' }
        $lastPortPath = Join-Path $InstanceRoot 'runtime\last-port.json'
        if (Test-Path -LiteralPath $lastPortPath -PathType Leaf) {
            $lastPort = Get-Content -LiteralPath $lastPortPath -Raw | ConvertFrom-Json
            Assert-NoOrphanC30Listener ([int]$lastPort.port)
        }
        $editorialContext = $null
        if ($EditorialQa) {
            $editorialContext = Assert-EditorialTarget
            if (-not $editorialContext.Marker) { throw 'BLOCKED_EDITORIAL_PREPARATION_REQUIRED' }
        }
        $key = [IO.File]::ReadAllText($KeyFile).Trim()
        if ($key -notmatch '^base64:[A-Za-z0-9+/]{43}=$') { throw 'BLOCKED_KEYFILE_INVALID' }
        $check = Invoke-C30Php @('..\scripts\local\picoradar-local-qa.php','preflight') (Get-C30Environment $key $Port)
        Write-RunLog ('C30_A_START_PREFLIGHT_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.json') $check | Out-Null
        $preflight = $check | ConvertFrom-Json
        if ($preflight.status -ne 'PASS') { throw 'BLOCKED_START_PREFLIGHT_NOT_PASS' }
        $selectedPort = $Port
        while ($selectedPort -lt 65535 -and (Get-ListenerConnections $selectedPort).Count -gt 0) { $selectedPort++ }
        if ($selectedPort -ge 65535) { throw 'BLOCKED_NO_LOOPBACK_PORT' }
        $reportLogs = Join-Path $ReportRoot 'logs\A'
        [IO.Directory]::CreateDirectory($reportLogs) | Out-Null
        $logId = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
        $stdout = Join-Path $reportLogs ('C30_A_PHP_SERVER_' + $selectedPort + '_' + $logId + '.out.log')
        $stderr = Join-Path $reportLogs ('C30_A_PHP_SERVER_' + $selectedPort + '_' + $logId + '.err.log')
        if ((Test-Path $stdout) -or (Test-Path $stderr)) { throw 'BLOCKED_SERVER_LOG_EXISTS' }
        $values = Get-C30Environment $key $selectedPort
        if ($EditorialQa) {
            $values.PICORADAR_EDITORIAL_QA = '1'
            $values.PICORADAR_EDITORIAL_EXPECTED_INSTANCE_ID = $script:InstanceId
            $values.PICORADAR_EDITORIAL_ENTRY_MODE = $editorialContext.EntryMode
        }
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
        $readyFailure = 'NOT_ATTEMPTED'
        $readyWatch = [Diagnostics.Stopwatch]::StartNew()
        $readyBudget = [TimeSpan]::FromSeconds(45)
        $httpHandler = [System.Net.Http.HttpClientHandler]::new()
        $httpHandler.UseProxy = $false
        $httpClient = [System.Net.Http.HttpClient]::new($httpHandler)
        $httpClient.Timeout = [Threading.Timeout]::InfiniteTimeSpan
        try {
            while ($readyWatch.Elapsed -lt $readyBudget) {
                if ($serverProcess.HasExited) { $readyFailure = 'SERVER_PROCESS_EXITED'; break }
                try { $listener = Get-ListenerConnections $selectedPort }
                catch { $readyFailure = 'LISTENER_QUERY_' + $_.Exception.GetType().Name; break }
                if (@($listener | Where-Object { $_.LocalAddress -eq '127.0.0.1' -and [int]$_.OwningProcess -eq $serverProcess.Id }).Count -eq 1) {
                    $remaining = $readyBudget - $readyWatch.Elapsed
                    if ($remaining -le [TimeSpan]::Zero) { $readyFailure = 'TOTAL_DEADLINE'; break }
                    $cancel = [Threading.CancellationTokenSource]::new($remaining)
                    $response = $null
                    try {
                        $response = $httpClient.GetAsync("http://127.0.0.1:$selectedPort/up", $cancel.Token).GetAwaiter().GetResult()
                        if ([int]$response.StatusCode -eq 200) { $ready = $true; break }
                        $readyFailure = 'HTTP_STATUS_' + [int]$response.StatusCode
                    } catch [System.OperationCanceledException] {
                        $readyFailure = 'HTTP_DEADLINE'
                    } catch [System.Net.Http.HttpRequestException] {
                        $readyFailure = 'HTTP_' + $_.Exception.GetType().Name
                    } finally {
                        if ($response) { $response.Dispose() }
                        $cancel.Dispose()
                    }
                } else {
                    $readyFailure = 'LOOPBACK_LISTENER_NOT_OWNED'
                }
                $remainingMs = [int][Math]::Max(1, ($readyBudget - $readyWatch.Elapsed).TotalMilliseconds)
                Start-Sleep -Milliseconds ([Math]::Min(250, $remainingMs))
            }
        } finally {
            $httpClient.Dispose()
            $httpHandler.Dispose()
        }
        if (-not $ready) {
            if (-not $serverProcess.HasExited) {
                $currentProcess = Get-Process -Id $serverProcess.Id -ErrorAction Stop
                $currentCim = Get-CimInstance Win32_Process -Filter "ProcessId=$($serverProcess.Id)" -ErrorAction Stop -OperationTimeoutSec 8
                $expectedRouter = Get-FullPath (Join-Path $PSScriptRoot 'picoradar-local-qa.php')
                if (-not $currentProcess.Path -or -not $currentProcess.Path.Equals((Get-FullPath $PhpExe), [StringComparison]::OrdinalIgnoreCase) -or
                    $currentProcess.StartTime.ToUniversalTime().Ticks -ne $serverProcess.StartTime.ToUniversalTime().Ticks -or
                    -not [string]$currentCim.CommandLine.Contains('-S 127.0.0.1:' + [string]$selectedPort) -or
                    -not [string]$currentCim.CommandLine.Contains($expectedRouter)) { throw 'BLOCKED_SERVER_CLEANUP_IDENTITY' }
                Stop-Process -Id $serverProcess.Id -ErrorAction Stop
                $serverProcess.WaitForExit(5000) | Out-Null
            }
            $failureLog = [ordered]@{status='BLOCKED';reason='SERVER_BIND_OR_HEALTHCHECK';last_failure=$readyFailure;elapsed_ms=[int]$readyWatch.Elapsed.TotalMilliseconds;port=$selectedPort}
            Write-RunLog ('C33_A_START_FAILURE_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.json') ($failureLog|ConvertTo-Json -Compress) | Out-Null
            throw ('BLOCKED_SERVER_BIND_OR_HEALTHCHECK_' + $readyFailure)
        }
        $actual = Get-Process -Id $serverProcess.Id
        $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$($serverProcess.Id)"
        $processMarker = [ordered]@{
            format='picoradar-local-process/1'; instanceId=$script:InstanceId; pid=$serverProcess.Id
            startTimeUtc=$actual.StartTime.ToUniversalTime().ToString('o'); executable=(Get-FullPath $actual.Path)
            port=$selectedPort; commandline_sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes([string]$cim.CommandLine)))
            mode=$(if ($EditorialQa) { 'EDITORIAL_QA' } else { 'C30_DEFAULT' })
        }
        if ($EditorialQa) { $processMarker.entry_mode = $editorialContext.EntryMode }
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
        @{ status='RUNNING'; instance_id=$script:InstanceId; pid=$serverProcess.Id; port=$selectedPort; start_time_utc=$processMarker.startTimeUtc; health='/up:200'; mode=$processMarker.mode; editorial_prepared=[bool]$EditorialQa } | ConvertTo-Json -Compress
        exit 0
    }
    if ($Action -eq 'Stop') {
        if (-not (Test-Path -LiteralPath $processPath -PathType Leaf)) {
            $lastPortPath = Join-Path $InstanceRoot 'runtime\last-port.json'
            $knownPort = $null
            if (Test-Path -LiteralPath $lastPortPath) {
                $lastPortData = Read-RecoveryMarker $lastPortPath 1024 'LAST_PORT_MARKER'
                $lastPortValue = 0
                if (-not [int]::TryParse([string]$lastPortData.Value.port,[ref]$lastPortValue) -or [string]$lastPortData.Value.instance_id -cne $script:InstanceId) { throw 'BLOCKED_LAST_PORT_MARKER_INVALID' }
                $knownPort = $lastPortValue
            }
            Assert-NoActiveInstanceServer $knownPort
            @{ status='STOPPED'; instance_id=$script:InstanceId; evidence='NO_PROCESS_MARKER_PROCESS_AND_LISTENER_CHECKED' } | ConvertTo-Json -Compress
            exit 0
        }
        $processMarker = Get-Content -LiteralPath $processPath -Raw | ConvertFrom-Json
        $process = Get-VerifiedProcess $processMarker
        Stop-Process -Id $process.Id
        $process.WaitForExit(10000) | Out-Null
        if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) { throw 'BLOCKED_PROCESS_DID_NOT_EXIT' }
        $listenerAfter = @(Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetTCPConnection -Filter "LocalPort = $([int]$processMarker.port) AND State = 2" -ErrorAction Stop -OperationTimeoutSec 8)
        if ($listenerAfter.Count -gt 0) { throw 'BLOCKED_LISTENER_REMAINS' }
        Remove-Item -LiteralPath $processPath
        @{ status='STOPPED'; instance_id=$script:InstanceId; pid=$process.Id; listener_closed=$true; mode=$(if ($processMarker.PSObject.Properties['mode']) { [string]$processMarker.mode } else { 'C30_DEFAULT' }) } | ConvertTo-Json -Compress
        exit 0
    }
} finally { $operationLock.Dispose() }
