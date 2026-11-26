[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Backup','Restore')][string]$Action,
    [Parameter(Mandatory)][string]$InstanceRoot,
    [Parameter(Mandatory)][string]$Archive,
    [string]$RestoreRoot,
    [string]$PhpExe = 'C:\xampphp\php\php.exe'
)

$ErrorActionPreference = 'Stop'
$maxTotalBytes = 1GB
$maxFileCount = 10000
$maxManifestBytes = 4MB
$copyBufferSize = 65536
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sha256Regex = '^[A-Fa-f0-9]{64}$'
$headRegex = '^(?:[A-Fa-f0-9]{40}|[A-Fa-f0-9]{64})$'

function Stop-Operation([string]$Code, [string]$Detail) {
    throw [InvalidOperationException]::new("$Code :: $Detail")
}

function Get-CanonicalPath([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.StartsWith('\\') -or $Value -notmatch '^[A-Za-z]:[\\/]') {
        Stop-Operation 'PATH_INVALID' 'An absolute local drive path is required.'
    }
    $normalized = $Value.Replace('/', '\')
    if ($normalized -match '^[A-Za-z]:[^\\]' -or $normalized.Substring(2).Contains(':')) {
        Stop-Operation 'PATH_INVALID' 'Drive-relative paths and alternate data streams are not accepted.'
    }
    $segments = $normalized.Substring(3).Split([char[]]@('\'), [StringSplitOptions]::RemoveEmptyEntries)
    foreach ($segment in $segments) {
        if ($segment -in @('.', '..') -or $segment.EndsWith('.') -or $segment.EndsWith(' ') -or $segment -match '[\x00-\x1f<>"|?*]') {
            Stop-Operation 'PATH_INVALID' 'The path contains a dot segment or an ambiguous Windows name.'
        }
        if ($segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$') {
            Stop-Operation 'PATH_INVALID' 'Reserved Windows device names are not accepted.'
        }
    }
    try { [IO.Path]::GetFullPath($normalized) }
    catch { Stop-Operation 'PATH_INVALID' 'The path could not be canonicalized.' }
}

function Test-SamePath([string]$Left, [string]$Right) {
    $a = (Get-CanonicalPath $Left).TrimEnd('\')
    $b = (Get-CanonicalPath $Right).TrimEnd('\')
    [string]::Equals($a, $b, [StringComparison]::OrdinalIgnoreCase)
}

function Test-PathWithin([string]$Candidate, [string]$Root) {
    $candidatePath = (Get-CanonicalPath $Candidate).TrimEnd('\')
    $rootPath = (Get-CanonicalPath $Root).TrimEnd('\') + '\'
    $candidatePath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoReparse([string]$Path, [switch]$MustExist) {
    $full = Get-CanonicalPath $Path
    $root = [IO.Path]::GetPathRoot($full)
    $cursor = $root
    $parts = $full.Substring($root.Length).Split([char[]]@('\'), [StringSplitOptions]::RemoveEmptyEntries)
    foreach ($part in $parts) {
        $cursor = Join-Path $cursor $part
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                Stop-Operation 'REPARSE_REJECT' 'A path component is a reparse point.'
            }
        } elseif ($MustExist) {
            Stop-Operation 'PATH_MISSING' 'A required path component does not exist.'
        } else {
            break
        }
    }
    if ($MustExist -and -not (Test-Path -LiteralPath $full)) {
        Stop-Operation 'PATH_MISSING' 'The required path does not exist.'
    }
}

function Get-Layout([string]$SourceRoot) {
    $instance = Get-CanonicalPath $SourceRoot
    $runtime = [IO.Directory]::GetParent($instance)
    if (-not $runtime -or $runtime.Name -cne 'runtime') { Stop-Operation 'INSTANCE_LAYOUT_REJECT' 'InstanceRoot must be a direct child of runtime.' }
    $base = $runtime.Parent
    if (-not $base -or [IO.Directory]::GetParent($instance).Name -cne 'runtime') { Stop-Operation 'INSTANCE_LAYOUT_REJECT' 'The C30 runtime root is malformed.' }
    if ([IO.Path]::GetFileName($instance) -cne 'instance-a') { Stop-Operation 'INSTANCE_LAYOUT_REJECT' 'This lane accepts only the frozen instance-a source.' }
    $runtimeRoot = $runtime.FullName
    $privateRoot = Join-Path $base.FullName 'private'
    Assert-NoReparse $base.FullName -MustExist
    Assert-NoReparse $runtimeRoot -MustExist
    Assert-NoReparse $instance -MustExist
    Assert-NoReparse $privateRoot -MustExist
    [pscustomobject]@{
        InstanceRoot = $instance
        RuntimeRoot = $runtimeRoot
        BaseRoot = $base.FullName
        PrivateRoot = $privateRoot
        LockPath = Join-Path $instance 'runtime\operation.lock'
        ProcessPath = Join-Path $instance 'runtime\process.json'
    }
}

function Assert-PrivateRoot([string]$Path) {
    Assert-NoReparse $Path -MustExist
    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer) { Stop-Operation 'PRIVATE_ROOT_REJECT' 'The private root is not a directory.' }
    $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($Path))
    if ($drive.DriveFormat -cne 'NTFS') { Stop-Operation 'PRIVATE_ROOT_REJECT' 'The private root must be on NTFS for its access policy.' }
    try { $acl = Get-Acl -LiteralPath $Path }
    catch { Stop-Operation 'PRIVATE_ROOT_REJECT' 'The private root ACL could not be verified.' }
    $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $ownerSid = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($ownerSid -cne $currentSid -or -not $acl.AreAccessRulesProtected) {
        Stop-Operation 'PRIVATE_ROOT_REJECT' 'The private root must be owned by the current user with inheritance disabled.'
    }
    $allowed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    [void]$allowed.Add($currentSid)
    [void]$allowed.Add('S-1-5-18')
    [void]$allowed.Add('S-1-5-32-544')
    $currentHasFullControl = $false
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
        $sid = $rule.IdentityReference.Value
        if (-not $allowed.Contains($sid) -or $rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow) {
            Stop-Operation 'PRIVATE_ROOT_REJECT' 'The private root ACL grants access outside the current user, SYSTEM, or Administrators.'
        }
        if ($sid -ceq $currentSid -and -not $rule.IsInherited -and ([int64]$rule.FileSystemRights -band [int64][Security.AccessControl.FileSystemRights]::FullControl) -eq [int64][Security.AccessControl.FileSystemRights]::FullControl) {
            $currentHasFullControl = $true
        }
    }
    if (-not $currentHasFullControl) { Stop-Operation 'PRIVATE_ROOT_REJECT' 'The current user lacks an explicit FullControl rule on the private root.' }
}

function Assert-PhpExe([string]$Path) {
    $full = Get-CanonicalPath $Path
    if (-not (Test-SamePath $full 'C:\xampphp\php\php.exe')) { Stop-Operation 'PHP_PATH_REJECT' 'Only the verified C30 PHP CLI path is accepted.' }
    Assert-NoReparse $full -MustExist
    if ((Get-Item -LiteralPath $full).PSIsContainer) { Stop-Operation 'PHP_PATH_REJECT' 'PhpExe is not a regular file.' }
    $full
}

function Get-Field($Object, [string[]]$Names) {
    if ($null -eq $Object) { return $null }
    foreach ($name in $Names) {
        if ($Object -is [Collections.IDictionary]) {
            foreach ($key in $Object.Keys) { if ([string]::Equals([string]$key, $name, [StringComparison]::OrdinalIgnoreCase)) { return $Object[$key] } }
        } else {
            $property = $Object.PSObject.Properties | Where-Object { [string]::Equals($_.Name, $name, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
            if ($property) { return $property.Value }
        }
    }
    $null
}

function Assert-NoSecretProperties($Value, [string]$Context = 'marker') {
    if ($Value -is [Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if ([string]$key -match '(?i)(password|app[_-]?key|secret|token|credential|private[_-]?key|certificate)') {
                Stop-Operation 'INSTANCE_MARKER_REJECT' "A secret-like property name is present in $Context."
            }
            Assert-NoSecretProperties $Value[$key] $Context
        }
    } elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($item in $Value) { Assert-NoSecretProperties $item $Context }
    }
}

function Read-JsonFile([string]$Path, [int]$LimitBytes, [string]$ErrorCode) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -gt $LimitBytes) { Stop-Operation $ErrorCode 'A JSON file exceeded the size limit.' }
    try {
        $encoding = [Text.UTF8Encoding]::new($false, $true)
        $text = $encoding.GetString($bytes)
        $document = [System.Text.Json.JsonDocument]::Parse($text)
        try { Assert-NoDuplicateJsonKeys $document.RootElement } finally { $document.Dispose() }
        $text | ConvertFrom-Json -AsHashtable -Depth 40
    } catch { Stop-Operation $ErrorCode 'A JSON file is malformed, duplicated, or not strict UTF-8.' }
}

function Assert-NoDuplicateJsonKeys([System.Text.Json.JsonElement]$Element) {
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($property in $Element.EnumerateObject()) {
            if (-not $seen.Add($property.Name)) { Stop-Operation 'JSON_DUPLICATE_PROPERTY' 'Duplicate JSON properties are not accepted.' }
            Assert-NoDuplicateJsonKeys $property.Value
        }
    } elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        foreach ($item in $Element.EnumerateArray()) { Assert-NoDuplicateJsonKeys $item }
    }
}

function Get-StringLeaves($Value, [Collections.Generic.List[string]]$Target) {
    if ($Value -is [Collections.IDictionary]) {
        foreach ($key in $Value.Keys) { Get-StringLeaves $Value[$key] $Target }
    } elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($item in $Value) { Get-StringLeaves $item $Target }
    } elseif ($Value -is [string]) { $Target.Add($Value) }
}

function Read-InstanceMarker([string]$Instance) {
    $path = Join-Path $Instance 'instance.json'
    Assert-NoReparse $path -MustExist
    if ((Get-Item -LiteralPath $path).PSIsContainer) { Stop-Operation 'INSTANCE_MARKER_REJECT' 'instance.json is not a regular file.' }
    $marker = Read-JsonFile $path 64KB 'INSTANCE_MARKER_REJECT'
    Assert-NoSecretProperties $marker
    $format = [string](Get-Field $marker @('format','schema'))
    $id = [string](Get-Field $marker @('id','instanceId'))
    $backend = [string](Get-Field $marker @('backend'))
    $scope = [string](Get-Field $marker @('scope'))
    $head = [string](Get-Field $marker @('codeHead','code_head','head'))
    $state = [string](Get-Field $marker @('state','status'))
    $paths = Get-Field $marker @('paths')
    $guid = [guid]::Empty
    if ($format -cne 'picoradar-local-qa/1' -or -not [guid]::TryParse($id, [ref]$guid) -or $backend -cne 'sqlite' -or $scope -cne 'NON_PRODUCTION_SYNTHETIC' -or $head -notmatch $headRegex -or $state -notin @('initialized','INITIALIZED','initialised','INITIALISED') -or $null -eq $paths) {
        Stop-Operation 'INSTANCE_MARKER_REJECT' 'instance.json does not match the C30 synthetic SQLite contract.'
    }
    $pathLeaves = [Collections.Generic.List[string]]::new()
    Get-StringLeaves $paths $pathLeaves
    $allowedPaths = @('data/picoradar.sqlite','storage','storage/app/private','storage/app/public','storage/framework/cache/data','storage/framework/sessions','storage/framework/views','storage/framework/testing','storage/logs','bootstrap/cache','runtime')
    foreach ($relative in $pathLeaves) {
        if ($relative -notin $allowedPaths) { Stop-Operation 'INSTANCE_MARKER_REJECT' 'instance.json contains a path outside the fixed layout.' }
    }
    foreach ($required in @('data/picoradar.sqlite','storage/app/private','storage/app/public','runtime')) {
        if ($required -notin $pathLeaves) { Stop-Operation 'INSTANCE_MARKER_REJECT' 'instance.json omits a fixed C30 path.' }
    }
    [pscustomobject]@{ Data = $marker; Id = $guid.ToString(); CodeHead = $head.ToLowerInvariant() }
}

function Get-CurrentHead {
    $head = & git -C $repoRoot rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($head -join ''))) { Stop-Operation 'CODE_HEAD_UNVERIFIABLE' 'The candidate Git HEAD could not be read.' }
    $value = ($head -join '').Trim()
    if ($value -notmatch $headRegex) { Stop-Operation 'CODE_HEAD_UNVERIFIABLE' 'The candidate Git HEAD has an invalid form.' }
    $value.ToLowerInvariant()
}

function Test-CompatibleCodeHead([string]$RecordedHead, [string]$CandidateHead) {
    if ($RecordedHead -notmatch $headRegex -or $CandidateHead -notmatch $headRegex) { return $false }
    $ancestor = & git -C $repoRoot merge-base --is-ancestor $RecordedHead $CandidateHead 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    $recordedTree = & git -C $repoRoot rev-parse "${RecordedHead}:server" 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    $candidateTree = & git -C $repoRoot rev-parse "${CandidateHead}:server" 2>$null
    if ($LASTEXITCODE -ne 0 -or ($recordedTree -join '').Trim() -cne ($candidateTree -join '').Trim()) { return $false }
    $workingTree = & git -C $repoRoot diff --quiet HEAD -- server 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    $untracked = & git -C $repoRoot ls-files --others --exclude-standard -- server 2>$null
    if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace(($untracked -join ''))) { return $false }
    return $true
}

function Open-OperationLock([string]$Instance) {
    $runtimePath = Join-Path $Instance 'runtime'
    Assert-NoReparse $runtimePath -MustExist
    if (-not (Get-Item -LiteralPath $runtimePath).PSIsContainer) { Stop-Operation 'LOCK_UNAVAILABLE' 'The instance runtime path is not a directory.' }
    $path = Join-Path $runtimePath 'operation.lock'
    if (Test-Path -LiteralPath $path) { Assert-NoReparse $path -MustExist }
    try { [IO.File]::Open($path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch [IO.IOException] { Stop-Operation 'LOCK_BUSY' 'Another lifecycle or backup operation holds the instance lock.' }
    catch { Stop-Operation 'LOCK_UNAVAILABLE' 'The shared instance lock could not be acquired.' }
}

function Parse-UtcTime($Value, [string]$Code) {
    $date = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$date)) {
        Stop-Operation $Code 'The process creation time is absent or invalid.'
    }
    $date.ToUniversalTime()
}

function Assert-InstanceStopped([pscustomobject]$Layout, [pscustomobject]$InstanceInfo, [string]$PhpPath) {
    if (Test-Path -LiteralPath $Layout.ProcessPath) {
        Assert-NoReparse $Layout.ProcessPath -MustExist
        if ((Get-Item -LiteralPath $Layout.ProcessPath).PSIsContainer) { Stop-Operation 'PROCESS_UNVERIFIABLE' 'runtime/process.json is not a regular marker.' }
        try { $marker = Read-JsonFile $Layout.ProcessPath 32KB 'PROCESS_UNVERIFIABLE' }
        catch { Stop-Operation 'PROCESS_UNVERIFIABLE' 'runtime/process.json cannot be verified.' }
        Assert-NoSecretProperties $marker 'process marker'
        $pidValue = 0
        $portValue = 0
        $instanceId = [string](Get-Field $marker @('instanceId','id'))
        $pidRaw = Get-Field $marker @('pid','processId')
        $portRaw = Get-Field $marker @('port','listenPort')
        if (-not [int]::TryParse([string]$pidRaw, [ref]$pidValue) -or $pidValue -le 0 -or -not [int]::TryParse([string]$portRaw, [ref]$portValue) -or $portValue -lt 1 -or $portValue -gt 65535 -or $instanceId -cne $InstanceInfo.Id) {
            Stop-Operation 'PROCESS_UNVERIFIABLE' 'The process marker identity, PID, or port is invalid.'
        }
        $exeRaw = [string](Get-Field $marker @('executable','phpExe','executablePath'))
        $timeRaw = Get-Field $marker @('createdAtUtc','startedAtUtc','startTimeUtc','createdAt','startTime')
        if ([string]::IsNullOrWhiteSpace($exeRaw) -or $null -eq $timeRaw) { Stop-Operation 'PROCESS_UNVERIFIABLE' 'The process marker omits executable or creation time.' }
        try {
            $cim = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $pidValue" -ErrorAction Stop
            $process = Get-Process -Id $pidValue -ErrorAction Stop
        } catch { Stop-Operation 'PROCESS_UNVERIFIABLE' 'The marked process identity cannot be queried.' }
        if (-not $cim -or -not $process) { Stop-Operation 'PROCESS_UNVERIFIABLE' 'The process marker is stale; it is not safe to assume STOPPED.' }
        $actualExe = [string]$cim.ExecutablePath
        if ([string]::IsNullOrWhiteSpace($actualExe)) { $actualExe = [string]$process.Path }
        try { $actualExe = Get-CanonicalPath $actualExe; $markedExe = Get-CanonicalPath $exeRaw }
        catch { Stop-Operation 'PROCESS_UNVERIFIABLE' 'The PHP executable in the process marker is invalid.' }
        if (-not (Test-SamePath $actualExe $PhpPath) -or -not (Test-SamePath $markedExe $PhpPath)) { Stop-Operation 'PROCESS_UNVERIFIABLE' 'The marked PID is not the expected PHP executable.' }
        $markedTime = Parse-UtcTime $timeRaw 'PROCESS_UNVERIFIABLE'
        $actualTime = [DateTimeOffset]$process.StartTime.ToUniversalTime()
        if ([Math]::Abs(($actualTime - $markedTime).TotalSeconds) -gt 2) { Stop-Operation 'PROCESS_UNVERIFIABLE' 'The PID creation time does not match the process marker.' }
        $commandLine = [string]$cim.CommandLine
        $publicPath = Join-Path $repoRoot 'server\public'
        if ($commandLine.IndexOf($publicPath, [StringComparison]::OrdinalIgnoreCase) -lt 0 -or $commandLine -notmatch ('(?i)(?:^|\s)-S\s+["'']?127\.0\.0\.1:' + $portValue + '(?:\s|["'']|$)')) {
            Stop-Operation 'PROCESS_UNVERIFIABLE' 'The marked process command line is not the candidate loopback server.'
        }
        try {
            $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $portValue -ErrorAction Stop | Where-Object { $_.LocalAddress -in @('127.0.0.1','::1') })
        } catch { Stop-Operation 'PROCESS_UNVERIFIABLE' 'The local listener owner could not be verified.' }
        if ($listeners.Count -ne 1 -or [int]$listeners[0].OwningProcess -ne $pidValue) { Stop-Operation 'PROCESS_UNVERIFIABLE' 'The loopback listener is absent or belongs to another process.' }
        Stop-Operation 'INSTANCE_ACTIVE' 'The instance PHP server is running; a backup requires STOPPED.'
    }

    try { $phpProcesses = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'php.exe'" -ErrorAction Stop) }
    catch { Stop-Operation 'PROCESS_UNVERIFIABLE' 'PHP processes could not be enumerated to check for an unmarked worker.' }
    $publicPath = Join-Path $repoRoot 'server\public'
    $artisanPath = Join-Path $repoRoot 'server\artisan'
    foreach ($process in $phpProcesses) {
        $commandLine = [string]$process.CommandLine
        if ($commandLine.IndexOf($Layout.InstanceRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or $commandLine.IndexOf($publicPath, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or $commandLine.IndexOf($artisanPath, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            Stop-Operation 'PROCESS_UNVERIFIABLE' 'A PHP server or worker references this candidate without a verifiable process marker.'
        }
    }
}

function Get-SqliteProgram {
@'
$inputData = json_decode(stream_get_contents(STDIN), true, 32, JSON_THROW_ON_ERROR);
function inspectDatabase(string $path): array {
    $db = new SQLite3($path, SQLITE3_OPEN_READONLY);
    $db->enableExceptions(true);
    try {
        $integrity = $db->query('PRAGMA integrity_check');
        $integrityRows = [];
        while ($row = $integrity->fetchArray(SQLITE3_NUM)) { $integrityRows[] = (string)$row[0]; }
        if (count($integrityRows) !== 1 || $integrityRows[0] !== 'ok') { throw new RuntimeException('integrity_check failed'); }
        $foreign = $db->query('PRAGMA foreign_key_check');
        $foreignCount = 0;
        while ($foreign->fetchArray(SQLITE3_NUM)) { $foreignCount++; }
        if ($foreignCount !== 0) { throw new RuntimeException('foreign_key_check failed'); }
        $hasMigrations = (int)$db->querySingle("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='migrations'");
        if ($hasMigrations !== 1) { throw new RuntimeException('migrations table is absent'); }
        $rows = $db->query('SELECT migration,batch FROM migrations ORDER BY migration,batch');
        $migrations = [];
        $seen = [];
        while ($row = $rows->fetchArray(SQLITE3_ASSOC)) {
            $name = (string)$row['migration'];
            $batch = (int)$row['batch'];
            if ($name === '' || isset($seen[$name])) { throw new RuntimeException('invalid or duplicate migration metadata'); }
            $seen[$name] = true;
            $migrations[] = ['migration'=>$name,'batch'=>$batch];
        }
        return ['schema'=>['userVersion'=>(int)$db->querySingle('PRAGMA user_version'),'migrations'=>$migrations], 'sqliteVersion'=>SQLite3::version()['versionString']];
    } finally { $db->close(); }
}
try {
    $source = inspectDatabase($inputData['source']);
    if ($inputData['action'] === 'backup') {
        if (file_exists($inputData['target'])) { throw new RuntimeException('snapshot target already exists'); }
        $from = new SQLite3($inputData['source'], SQLITE3_OPEN_READONLY);
        $from->enableExceptions(true);
        $to = new SQLite3($inputData['target'], SQLITE3_OPEN_READWRITE | SQLITE3_OPEN_CREATE);
        $to->enableExceptions(true);
        try {
            if (!$from->backup($to)) { throw new RuntimeException('SQLite3::backup failed'); }
        } finally { $to->close(); $from->close(); }
        $snapshot = inspectDatabase($inputData['target']);
        if (json_encode($snapshot['schema'], JSON_THROW_ON_ERROR) !== json_encode($source['schema'], JSON_THROW_ON_ERROR)) { throw new RuntimeException('snapshot schema metadata differs'); }
        $sourceAfter = inspectDatabase($inputData['source']);
        if (json_encode($sourceAfter['schema'], JSON_THROW_ON_ERROR) !== json_encode($source['schema'], JSON_THROW_ON_ERROR)) { throw new RuntimeException('source schema metadata changed during snapshot'); }
        echo json_encode(['source'=>$source,'snapshot'=>$snapshot], JSON_THROW_ON_ERROR);
    } elseif ($inputData['action'] === 'inspect') {
        echo json_encode($source, JSON_THROW_ON_ERROR);
    } else { throw new RuntimeException('unknown SQLite operation'); }
} catch (Throwable $error) {
    fwrite(STDERR, 'SQLITE_PREFLIGHT_FAILED: ' . $error->getMessage());
    exit(2);
}
'@
}

function Invoke-Sqlite([string]$PhpPath, [string]$Operation, [string]$Source, [string]$Target = '') {
    $program = Get-SqliteProgram
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $PhpPath
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.CreateNoWindow = $true
    foreach ($argument in @('-d','extension_dir=C:\xampphp\php\ext','-d','extension=php_sqlite3.dll','-d','extension=php_pdo_sqlite.dll','-r',$program)) { $start.ArgumentList.Add($argument) }
    $start.Environment['PATH'] = "C:\xampphp\php;C:\xampphp\php\ext;$env:PATH"
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) { Stop-Operation 'SQLITE_TOOL_FAILED' 'The verified PHP CLI did not start.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $input = [ordered]@{ action = $Operation; source = $Source; target = $Target } | ConvertTo-Json -Compress
    $process.StandardInput.Write($input)
    $process.StandardInput.Close()
    $process.WaitForExit()
    $outText = $stdout.GetAwaiter().GetResult()
    $errText = $stderr.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { Stop-Operation 'SQLITE_TOOL_FAILED' ($errText.Trim()) }
    try { $outText | ConvertFrom-Json -AsHashtable -Depth 32 }
    catch { Stop-Operation 'SQLITE_TOOL_FAILED' 'The PHP SQLite result was not valid JSON.' }
    finally { $process.Dispose() }
}

function Get-HashAndCount([string]$Source, [string]$Destination = '') {
    $inputStream = $null
    $outputStream = $null
    $hash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        $inputStream = [IO.File]::Open($Source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        if ($Destination) { $outputStream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None) }
        $buffer = [byte[]]::new($copyBufferSize)
        [long]$total = 0
        while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $total += $read
            if ($total -gt $maxTotalBytes) { Stop-Operation 'SIZE_LIMIT' 'A file exceeded the one GiB QA limit.' }
            $hash.AppendData($buffer, 0, $read)
            if ($outputStream) { $outputStream.Write($buffer, 0, $read) }
        }
        [pscustomobject]@{ Bytes = $total; Sha256 = [Convert]::ToHexString($hash.GetHashAndReset()) }
    } finally {
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        $hash.Dispose()
    }
}

function Get-StorageFiles([string]$Instance) {
    $files = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($relativeRoot in @('storage\app\private','storage\app\public')) {
        $root = Join-Path $Instance $relativeRoot
        Assert-NoReparse $root -MustExist
        if (-not (Get-Item -LiteralPath $root).PSIsContainer) { Stop-Operation 'STORAGE_REJECT' 'A storage allowlist root is not a directory.' }
        $pending = [Collections.Generic.Stack[string]]::new()
        $pending.Push($root)
        while ($pending.Count -gt 0) {
            $directory = $pending.Pop()
            foreach ($item in Get-ChildItem -LiteralPath $directory -Force) {
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { Stop-Operation 'STORAGE_REJECT' 'Storage contains a reparse point.' }
                if ($item.PSIsContainer) { $pending.Push($item.FullName); continue }
                if (($item.Attributes -band [IO.FileAttributes]::Directory) -ne 0) { Stop-Operation 'STORAGE_REJECT' 'Storage contains a non-regular entry.' }
                if ($item.Name -match '(?i)(^\.env(?:\.|$)|app[_-]?key|password|credential|secret|token|\.pem$|\.pfx$|\.p12$|\.crt$|\.cer$|\.jks$|\.keystore$|id_rsa)') {
                    Stop-Operation 'STORAGE_REJECT' 'A secret or certificate-like file is present under storage.'
                }
                $relative = [IO.Path]::GetRelativePath($Instance, $item.FullName).Replace('\','/')
                Assert-ArchivePath $relative
                if (-not $seen.Add($relative)) { Stop-Operation 'STORAGE_REJECT' 'Storage paths collide case-insensitively.' }
                $files.Add([pscustomobject]@{ RelativePath = $relative; SourcePath = $item.FullName })
                if ($files.Count -ge $maxFileCount) { Stop-Operation 'SIZE_LIMIT' 'Storage exceeds the 10,000 file QA limit.' }
            }
        }
    }
    $files
}

function Assert-ArchivePath([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or $RelativePath.Length -gt 240 -or $RelativePath.Contains('\') -or $RelativePath.StartsWith('/') -or $RelativePath.Contains(':') -or $RelativePath -match '[\x00-\x1f%]') {
        Stop-Operation 'TRAVERSAL_REJECT' 'An archive path is absolute, ambiguous, or too long.'
    }
    if ($RelativePath.Normalize([Text.NormalizationForm]::FormC) -cne $RelativePath) { Stop-Operation 'TRAVERSAL_REJECT' 'Archive paths must be Unicode NFC.' }
    $segments = $RelativePath.Split('/')
    foreach ($segment in $segments) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -in @('.','..') -or $segment.EndsWith('.') -or $segment.EndsWith(' ') -or $segment.Length -gt 255 -or $segment -match '[<>"|?*]') {
            Stop-Operation 'TRAVERSAL_REJECT' 'An archive path contains a traversal or ambiguous Windows segment.'
        }
        if ($segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$') { Stop-Operation 'TRAVERSAL_REJECT' 'An archive path uses a reserved Windows device name.' }
    }
    if ($RelativePath -cne 'data/picoradar.sqlite' -and -not $RelativePath.StartsWith('storage/app/private/', [StringComparison]::Ordinal) -and -not $RelativePath.StartsWith('storage/app/public/', [StringComparison]::Ordinal)) {
        Stop-Operation 'ALLOWLIST_REJECT' 'Only the SQLite database and storage/app/private or storage/app/public files are allowed.'
    }
    if ($RelativePath -match '(?i)(^|/)(\.env(?:\.|$)|[^/]*app[_-]?key[^/]*|[^/]*password[^/]*|[^/]*credential[^/]*|[^/]*secret[^/]*|[^/]*token[^/]*|[^/]*\.(pem|pfx|p12|crt|cer|jks|keystore))($|/)') {
        Stop-Operation 'ALLOWLIST_REJECT' 'Secret and certificate files are not valid archive members.'
    }
}

function Get-ExpectedArchiveFiles([string]$RelativePath, [long]$Bytes, [string]$Hash) {
    Assert-ArchivePath $RelativePath
    if ($Bytes -lt 0 -or $Bytes -gt $maxTotalBytes -or $Hash -notmatch $sha256Regex) { Stop-Operation 'MANIFEST_REJECT' 'A file descriptor has an invalid size or SHA-256.' }
    [pscustomobject]@{ path = $RelativePath; bytes = $Bytes; sha256 = $Hash.ToUpperInvariant() }
}

function Get-PhpMeta([string]$PhpPath, [string]$Operation, [string]$Database, [string]$Snapshot = '') {
    Invoke-Sqlite $PhpPath $Operation $Database $Snapshot
}

function Assert-MigrationCompatibility($Schema) {
    $available = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $migrationRoot = Join-Path $repoRoot 'server\database\migrations'
    if (-not (Test-Path -LiteralPath $migrationRoot -PathType Container)) { Stop-Operation 'MIGRATION_COMPATIBILITY_REJECT' 'Candidate migration metadata is absent.' }
    foreach ($file in Get-ChildItem -LiteralPath $migrationRoot -Filter '*.php' -File) { [void]$available.Add($file.BaseName) }
    foreach ($migration in @($Schema.migrations)) {
        if (-not $available.Contains([string]$migration.migration)) { Stop-Operation 'MIGRATION_COMPATIBILITY_REJECT' 'The backup contains an applied migration missing from candidate code.' }
    }
}

function Assert-SchemaMatches($Actual, $Expected) {
    if ([int]$Actual.schema.userVersion -ne [int]$Expected.userVersion) { Stop-Operation 'SCHEMA_MISMATCH' 'SQLite user_version differs from the manifest.' }
    $actualMigrations = @($Actual.schema.migrations | ForEach-Object { "{0}`t{1}" -f $_.migration,$_.batch } | Sort-Object)
    $expectedMigrations = @($Expected.migrations | ForEach-Object { "{0}`t{1}" -f $_.migration,$_.batch } | Sort-Object)
    if ($actualMigrations.Count -ne $expectedMigrations.Count) { Stop-Operation 'SCHEMA_MISMATCH' 'The applied migration count differs from the manifest.' }
    for ($i = 0; $i -lt $actualMigrations.Count; $i++) { if ($actualMigrations[$i] -cne $expectedMigrations[$i]) { Stop-Operation 'SCHEMA_MISMATCH' 'Applied migration metadata differs from the manifest.' } }
}

function Assert-ManifestShape($Manifest) {
    Assert-NoSecretProperties $Manifest 'manifest'
    $allowedRootKeys = @('format','backend','layout','instanceId','codeHead','createdAtUtc','schema','files')
    if ($Manifest.Keys.Count -ne $allowedRootKeys.Count -or @($Manifest.Keys | Where-Object { $_ -cnotin $allowedRootKeys }).Count -gt 0) { Stop-Operation 'MANIFEST_REJECT' 'The manifest contains unknown or missing root fields.' }
    if ([string]$Manifest.format -cne 'picoradar-backup/1' -or [string]$Manifest.backend -cne 'sqlite' -or [string]$Manifest.layout -cne 'picoradar-local-qa/1' -or [string]$Manifest.codeHead -notmatch $headRegex) {
        Stop-Operation 'MANIFEST_REJECT' 'The archive manifest version or backend is unsupported.'
    }
    $id = [guid]::Empty
    if (-not [guid]::TryParse([string]$Manifest.instanceId, [ref]$id)) { Stop-Operation 'MANIFEST_REJECT' 'The archive instance identity is invalid.' }
    $created = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string]$Manifest.createdAtUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$created) -or $created.Offset -ne [TimeSpan]::Zero) {
        Stop-Operation 'MANIFEST_REJECT' 'The manifest timestamp must be UTC.'
    }
    if ($Manifest.schema -isnot [Collections.IDictionary] -or $Manifest.schema.Keys.Count -ne 2 -or @($Manifest.schema.Keys | Where-Object { $_ -cnotin @('userVersion','migrations') }).Count -gt 0) {
        Stop-Operation 'MANIFEST_REJECT' 'The schema section is malformed.'
    }
    if ($Manifest.schema.userVersion -isnot [ValueType] -or @($Manifest.schema.migrations).Count -gt $maxFileCount) { Stop-Operation 'MANIFEST_REJECT' 'The schema metadata has an invalid shape.' }
    $fileItems = @($Manifest.files)
    if ($fileItems.Count -lt 1 -or $fileItems.Count -gt $maxFileCount) { Stop-Operation 'SIZE_LIMIT' 'The manifest file count is outside the QA limit.' }
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    [long]$declaredTotal = 0
    foreach ($file in $fileItems) {
        if ($file -isnot [Collections.IDictionary] -or $file.Keys.Count -ne 3 -or @($file.Keys | Where-Object { $_ -cnotin @('path','bytes','sha256') }).Count -gt 0) { Stop-Operation 'MANIFEST_REJECT' 'A file descriptor contains unknown or missing fields.' }
        $relative = [string]$file.path
        Assert-ArchivePath $relative
        if (-not $names.Add($relative)) { Stop-Operation 'DUPLICATE_MEMBER_REJECT' 'Manifest paths collide case-insensitively.' }
        if ($file.bytes -isnot [ValueType] -or $file.sha256 -isnot [string]) { Stop-Operation 'MANIFEST_REJECT' 'File sizes and hashes must have their declared types.' }
        [long]$count = $file.bytes
        if ($count -lt 0 -or $count -gt $maxTotalBytes -or [string]$file.sha256 -notmatch $sha256Regex) { Stop-Operation 'MANIFEST_REJECT' 'A file descriptor has an invalid size or hash.' }
        $declaredTotal += $count
        if ($declaredTotal -gt $maxTotalBytes) { Stop-Operation 'SIZE_LIMIT' 'The total expanded size exceeds one GiB.' }
    }
    if (-not $names.Contains('data/picoradar.sqlite')) { Stop-Operation 'MANIFEST_REJECT' 'The archive must contain exactly one SQLite database.' }
    $migrationNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($migration in @($Manifest.schema.migrations)) {
        if ($migration -isnot [Collections.IDictionary] -or $migration.Keys.Count -ne 2 -or @($migration.Keys | Where-Object { $_ -cnotin @('migration','batch') }).Count -gt 0 -or [string]$migration.migration -notmatch '^[A-Za-z0-9_]{1,255}$' -or $migration.batch -isnot [ValueType] -or [int]$migration.batch -lt 0 -or -not $migrationNames.Add([string]$migration.migration)) {
            Stop-Operation 'MANIFEST_REJECT' 'A migration entry is invalid or duplicated.'
        }
    }
    Assert-MigrationCompatibility $Manifest.schema
}

function Read-EntryBytes([IO.Compression.ZipArchiveEntry]$Entry, [long]$Limit) {
    if ($Entry.Length -gt $Limit) { Stop-Operation 'SIZE_LIMIT' 'An archive control member exceeded its size limit.' }
    $inputStream = $Entry.Open()
    $memory = [IO.MemoryStream]::new()
    try {
        $buffer = [byte[]]::new($copyBufferSize)
        [long]$total = 0
        while (($read = $inputStream.Read($buffer,0,$buffer.Length)) -gt 0) {
            $total += $read
            if ($total -gt $Limit) { Stop-Operation 'SIZE_LIMIT' 'An archive control member exceeded its streamed size limit.' }
            $memory.Write($buffer,0,$read)
        }
        if ($total -ne $Entry.Length) { Stop-Operation 'ARCHIVE_CORRUPT' 'A ZIP member length differs from its stream.' }
        $memory.ToArray()
    } finally { $inputStream.Dispose(); $memory.Dispose() }
}

function Get-EntryDigest([IO.Compression.ZipArchiveEntry]$Entry, [long]$ExpectedBytes) {
    if ($Entry.Length -ne $ExpectedBytes) { Stop-Operation 'SIZE_MISMATCH' 'A ZIP member length differs from its manifest.' }
    $inputStream = $Entry.Open()
    $hash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        $buffer = [byte[]]::new($copyBufferSize)
        [long]$total = 0
        while (($read = $inputStream.Read($buffer,0,$buffer.Length)) -gt 0) {
            $total += $read
            if ($total -gt $ExpectedBytes -or $total -gt $maxTotalBytes) { Stop-Operation 'SIZE_MISMATCH' 'A streamed ZIP member exceeds its declared bound.' }
            $hash.AppendData($buffer,0,$read)
        }
        if ($total -ne $ExpectedBytes) { Stop-Operation 'SIZE_MISMATCH' 'A streamed ZIP member is shorter than declared.' }
        [pscustomobject]@{ Bytes = $total; Sha256 = [Convert]::ToHexString($hash.GetHashAndReset()) }
    } finally { $inputStream.Dispose(); $hash.Dispose() }
}

function Assert-ZipEntryType([IO.Compression.ZipArchiveEntry]$Entry) {
    if ($Entry.FullName.EndsWith('/') -or $Entry.FullName.EndsWith('\')) { Stop-Operation 'ARCHIVE_TYPE_REJECT' 'Directory entries are not allowed; restore creates the fixed directories.' }
    $unixType = ($Entry.ExternalAttributes -shr 16) -band 0xF000
    if ($unixType -ne 0 -and $unixType -ne 0x8000) { Stop-Operation 'ARCHIVE_TYPE_REJECT' 'Only regular ZIP files are allowed.' }
    if (($Entry.ExternalAttributes -band 0x400) -ne 0) { Stop-Operation 'ARCHIVE_TYPE_REJECT' 'Reparse-point ZIP attributes are not allowed.' }
}

function Open-ValidatedArchive([string]$Path) {
    Assert-NoReparse $Path -MustExist
    if ((Get-Item -LiteralPath $Path).PSIsContainer) { Stop-Operation 'ARCHIVE_REJECT' 'Archive is not a regular file.' }
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $zip = $null
    try {
        $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read, $true)
        if ($zip.Entries.Count -lt 2 -or $zip.Entries.Count -gt ($maxFileCount + 1)) { Stop-Operation 'SIZE_LIMIT' 'The ZIP entry count is outside the QA limit.' }
        $entryMap = [Collections.Generic.Dictionary[string,IO.Compression.ZipArchiveEntry]]::new([StringComparer]::OrdinalIgnoreCase)
        $manifestEntry = $null
        foreach ($entry in $zip.Entries) {
            Assert-ZipEntryType $entry
            if ($entry.FullName -ceq 'manifest.json') {
                if ($manifestEntry) { Stop-Operation 'DUPLICATE_MEMBER_REJECT' 'The ZIP contains duplicate manifests.' }
                $manifestEntry = $entry
                continue
            }
            Assert-ArchivePath $entry.FullName
            if (-not $entryMap.TryAdd($entry.FullName, $entry)) { Stop-Operation 'DUPLICATE_MEMBER_REJECT' 'ZIP member paths collide case-insensitively.' }
        }
        if (-not $manifestEntry) { Stop-Operation 'MANIFEST_REJECT' 'The ZIP manifest is missing.' }
        $manifestBytes = Read-EntryBytes $manifestEntry $maxManifestBytes
        try {
            $text = [Text.UTF8Encoding]::new($false,$true).GetString($manifestBytes)
            $json = [System.Text.Json.JsonDocument]::Parse($text)
            try { Assert-NoDuplicateJsonKeys $json.RootElement } finally { $json.Dispose() }
            $manifest = $text | ConvertFrom-Json -AsHashtable -Depth 40
        } catch { Stop-Operation 'MANIFEST_REJECT' 'The manifest is malformed, duplicated, or not strict UTF-8.' }
        Assert-ManifestShape $manifest
        $declared = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($file in @($manifest.files)) { [void]$declared.Add([string]$file.path, $file) }
        if ($entryMap.Count -ne $declared.Count) { Stop-Operation 'ARCHIVE_MEMBERS_REJECT' 'ZIP members and manifest contents do not match exactly.' }
        foreach ($pathName in $declared.Keys) {
            if (-not $entryMap.ContainsKey($pathName)) { Stop-Operation 'ARCHIVE_MEMBERS_REJECT' 'A manifest member is missing from the ZIP.' }
            if ($entryMap[$pathName].FullName -cne $pathName) { Stop-Operation 'ARCHIVE_MEMBERS_REJECT' 'ZIP member casing differs from the manifest.' }
            $digest = Get-EntryDigest $entryMap[$pathName] ([long]$declared[$pathName].bytes)
            if ($digest.Sha256 -cne ([string]$declared[$pathName].sha256).ToUpperInvariant()) { Stop-Operation 'HASH_MISMATCH' 'A ZIP member SHA-256 does not match the manifest.' }
        }
        [pscustomobject]@{ Stream = $stream; Zip = $zip; Manifest = $manifest; Entries = $entryMap }
    } catch {
        if ($zip) { $zip.Dispose() }
        $stream.Dispose()
        throw
    }
}

function Copy-VerifiedZipEntry([IO.Compression.ZipArchiveEntry]$Entry, [string]$Destination, $Descriptor) {
    $inputStream = $Entry.Open()
    $outputStream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $hash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        $buffer = [byte[]]::new($copyBufferSize)
        [long]$total = 0
        while (($read = $inputStream.Read($buffer,0,$buffer.Length)) -gt 0) {
            $total += $read
            if ($total -gt [long]$Descriptor.bytes -or $total -gt $maxTotalBytes) { Stop-Operation 'SIZE_MISMATCH' 'A ZIP stream exceeded its declared length during extraction.' }
            $hash.AppendData($buffer,0,$read)
            $outputStream.Write($buffer,0,$read)
        }
        $actualHash = [Convert]::ToHexString($hash.GetHashAndReset())
        if ($total -ne [long]$Descriptor.bytes -or $actualHash -cne ([string]$Descriptor.sha256).ToUpperInvariant()) { Stop-Operation 'HASH_MISMATCH' 'A ZIP stream changed between preflight and extraction.' }
    } finally { $inputStream.Dispose(); $outputStream.Dispose(); $hash.Dispose() }
}

function Assert-ArchiveLocation([string]$Path, [pscustomobject]$Layout, [switch]$MustExist) {
    $full = Get-CanonicalPath $Path
    if (-not (Test-SamePath ([IO.Path]::GetDirectoryName($full)) $Layout.PrivateRoot) -or [IO.Path]::GetExtension($full) -cne '.zip') {
        Stop-Operation 'ARCHIVE_PATH_REJECT' 'The archive must be a direct .zip child of the private root.'
    }
    Assert-NoReparse $full -MustExist:$MustExist
    $full
}

function New-InstanceLayout([string]$Root) {
    foreach ($relative in @('bootstrap\cache','data','storage\app\private','storage\app\public','storage\framework\cache\data','storage\framework\sessions','storage\framework\views','storage\framework\testing','storage\logs','runtime')) {
        New-Item -ItemType Directory -Path (Join-Path $Root $relative) -Force | Out-Null
    }
}

function New-RestoredMarker([string]$InstanceId, [string]$CodeHead) {
    [ordered]@{
        format = 'picoradar-local-qa/1'
        id = $InstanceId
        backend = 'sqlite'
        scope = 'NON_PRODUCTION_SYNTHETIC'
        codeHead = $CodeHead
        state = 'initialized'
        paths = [ordered]@{
            database = 'data/picoradar.sqlite'
            private_storage = 'storage/app/private'
            public_storage = 'storage/app/public'
            runtime = 'runtime'
            bootstrap_cache = 'bootstrap/cache'
        }
    }
}

function Invoke-Backup([pscustomobject]$Layout, [string]$PhpPath, [string]$ArchivePath, [pscustomobject]$InstanceInfo, [string]$CurrentHead) {
    $lock = $null
    $temporaryRoot = $null
    $temporaryZip = $null
    try {
        $lock = Open-OperationLock $Layout.InstanceRoot
        $again = Read-InstanceMarker $Layout.InstanceRoot
        if ($again.Id -cne $InstanceInfo.Id -or -not (Test-CompatibleCodeHead $again.CodeHead $CurrentHead)) { Stop-Operation 'INSTANCE_CHANGED' 'The instance marker changed or its server code is incompatible with the candidate.' }
        Assert-InstanceStopped $Layout $again $PhpPath
        $database = Join-Path $Layout.InstanceRoot 'data\picoradar.sqlite'
        Assert-NoReparse $database -MustExist
        if ((Get-Item -LiteralPath $database).PSIsContainer) { Stop-Operation 'DATABASE_REJECT' 'The SQLite database is not a regular file.' }
        foreach ($relative in @('storage\app\private','storage\app\public')) { Assert-NoReparse (Join-Path $Layout.InstanceRoot $relative) -MustExist }
        if (Test-Path -LiteralPath $ArchivePath) { Stop-Operation 'ARCHIVE_EXISTS' 'Backup refuses to overwrite an existing archive.' }
        $temporaryRoot = Join-Path $Layout.PrivateRoot ".picoradar-backup-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
        $payloadRoot = Join-Path $temporaryRoot 'payload'
        $dbSnapshot = Join-Path $payloadRoot 'data\picoradar.sqlite'
        New-Item -ItemType Directory -Path (Split-Path -Parent $dbSnapshot) -Force | Out-Null
        $snapshot = Get-PhpMeta $PhpPath 'backup' $database $dbSnapshot
        $snapshotMeta = Get-PhpMeta $PhpPath 'inspect' $dbSnapshot
        Assert-SchemaMatches $snapshotMeta $snapshot.source.schema
        $descriptors = [Collections.Generic.List[object]]::new()
        $dbInfo = Get-HashAndCount $dbSnapshot
        $descriptors.Add((Get-ExpectedArchiveFiles 'data/picoradar.sqlite' $dbInfo.Bytes $dbInfo.Sha256))
        [long]$totalBytes = $dbInfo.Bytes
        $storageFiles = @(Get-StorageFiles $Layout.InstanceRoot)
        foreach ($file in $storageFiles) {
            $destination = Join-Path $payloadRoot ($file.RelativePath.Replace('/','\'))
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            $info = Get-HashAndCount $file.SourcePath $destination
            $totalBytes += $info.Bytes
            if ($totalBytes -gt $maxTotalBytes) { Stop-Operation 'SIZE_LIMIT' 'The total backup exceeds one GiB.' }
            $descriptors.Add((Get-ExpectedArchiveFiles $file.RelativePath $info.Bytes $info.Sha256))
        }
        if ($descriptors.Count -gt $maxFileCount) { Stop-Operation 'SIZE_LIMIT' 'Backup exceeds the 10,000 file QA limit.' }
        $manifest = [ordered]@{
            format = 'picoradar-backup/1'
            backend = 'sqlite'
            layout = 'picoradar-local-qa/1'
            instanceId = $again.Id
            codeHead = $again.CodeHead
            createdAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
            schema = [ordered]@{ userVersion = [int]$snapshot.source.schema.userVersion; migrations = @($snapshot.source.schema.migrations) }
            files = @($descriptors)
        }
        $manifestText = $manifest | ConvertTo-Json -Depth 20 -Compress
        $manifestBytes = [Text.UTF8Encoding]::new($false).GetBytes($manifestText)
        if ($manifestBytes.Length -gt $maxManifestBytes) { Stop-Operation 'SIZE_LIMIT' 'The generated manifest exceeded the size limit.' }
        $temporaryZip = Join-Path $Layout.PrivateRoot ".picoradar-backup-$([guid]::NewGuid().ToString('N')).tmp"
        $zipStream = [IO.File]::Open($temporaryZip, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $zip = [IO.Compression.ZipArchive]::new($zipStream, [IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            foreach ($descriptor in $descriptors) {
                $source = Join-Path $payloadRoot ($descriptor.path.Replace('/','\'))
                $entry = $zip.CreateEntry([string]$descriptor.path, [IO.Compression.CompressionLevel]::Optimal)
                $inputStream = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
                $outputStream = $entry.Open()
                try { $inputStream.CopyTo($outputStream, $copyBufferSize) } finally { $outputStream.Dispose(); $inputStream.Dispose() }
            }
            $manifestEntry = $zip.CreateEntry('manifest.json', [IO.Compression.CompressionLevel]::Optimal)
            $manifestStream = $manifestEntry.Open()
            try { $manifestStream.Write($manifestBytes,0,$manifestBytes.Length) } finally { $manifestStream.Dispose() }
        } finally { $zip.Dispose(); $zipStream.Dispose() }
        $verified = Open-ValidatedArchive $temporaryZip
        try {
            if ($verified.Entries.Count -ne $descriptors.Count -or $verified.Manifest.instanceId -cne $again.Id -or $verified.Manifest.codeHead -cne $again.CodeHead) {
                Stop-Operation 'ARCHIVE_VERIFY_FAILED' 'The newly written backup did not match its manifest.'
            }
            Assert-SchemaMatches $snapshotMeta $verified.Manifest.schema
        } finally { $verified.Zip.Dispose(); $verified.Stream.Dispose() }
        if (Test-Path -LiteralPath $ArchivePath) { Stop-Operation 'ARCHIVE_EXISTS' 'The destination appeared during backup; no overwrite was attempted.' }
        [IO.File]::Move($temporaryZip, $ArchivePath)
        $temporaryZip = $null
        $archiveHash = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash
        $length = (Get-Item -LiteralPath $ArchivePath).Length
        [ordered]@{ status='PASS'; action='Backup'; archive=$ArchivePath; files=$descriptors.Count; bytes=$length; archiveSha256=$archiveHash } | ConvertTo-Json -Compress
    } finally {
        if ($lock) { $lock.Dispose() }
        if ($temporaryZip -and (Test-Path -LiteralPath $temporaryZip)) { [IO.File]::Delete($temporaryZip) }
        if ($temporaryRoot -and (Test-Path -LiteralPath $temporaryRoot)) { [IO.Directory]::Delete($temporaryRoot,$true) }
    }
}

function Invoke-Restore([pscustomobject]$Layout, [string]$PhpPath, [string]$ArchivePath, [string]$Destination, [pscustomobject]$InstanceInfo, [string]$CurrentHead) {
    $sourceLock = $null
    $stageLock = $null
    $stage = $null
    $promoted = $false
    $validated = $null
    try {
        $sourceLock = Open-OperationLock $Layout.InstanceRoot
        $again = Read-InstanceMarker $Layout.InstanceRoot
        if ($again.Id -cne $InstanceInfo.Id -or -not (Test-CompatibleCodeHead $again.CodeHead $CurrentHead)) { Stop-Operation 'INSTANCE_CHANGED' 'The source marker changed or its server code is incompatible with the candidate.' }
        Assert-InstanceStopped $Layout $again $PhpPath
        if (Test-Path -LiteralPath $Destination) { Stop-Operation 'DESTINATION_EXISTS' 'Restore requires a destination that does not exist.' }
        $validated = Open-ValidatedArchive $ArchivePath
        $manifest = $validated.Manifest
        if ([string]$manifest.instanceId -cne $again.Id) { Stop-Operation 'ARCHIVE_INSTANCE_MISMATCH' 'The archive belongs to another instance.' }
        if ([string]$manifest.codeHead -cne $again.CodeHead -or -not (Test-CompatibleCodeHead ([string]$manifest.codeHead) $CurrentHead)) { Stop-Operation 'CODE_HEAD_MISMATCH' 'The backup code HEAD is not an ancestor with an identical server tree.' }
        if (-not (Test-SamePath ([IO.Path]::GetPathRoot($Destination)) ([IO.Path]::GetPathRoot($Layout.RuntimeRoot))) -or -not (Test-SamePath ([IO.Path]::GetPathRoot($ArchivePath)) ([IO.Path]::GetPathRoot($Destination)))) {
            Stop-Operation 'VOLUME_MISMATCH' 'Archive, restore staging, and destination must share a volume.'
        }
        $stage = Join-Path $Layout.RuntimeRoot ".instance-restored-stage-$([guid]::NewGuid().ToString('N'))"
        if (Test-Path -LiteralPath $stage) { Stop-Operation 'STAGING_COLLISION' 'A unique staging path unexpectedly exists.' }
        New-Item -ItemType Directory -Path $stage | Out-Null
        New-InstanceLayout $stage
        $stageLock = Open-OperationLock $stage
        foreach ($descriptor in @($manifest.files)) {
            $target = Join-Path $stage ($descriptor.path.Replace('/','\'))
            $canonicalTarget = Get-CanonicalPath $target
            if (-not (Test-PathWithin $canonicalTarget $stage)) { Stop-Operation 'TRAVERSAL_REJECT' 'A restored path escaped the private staging directory.' }
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-VerifiedZipEntry $validated.Entries[[string]$descriptor.path] $target $descriptor
        }
        $restoredDb = Join-Path $stage 'data\picoradar.sqlite'
        $dbMeta = Get-PhpMeta $PhpPath 'inspect' $restoredDb
        Assert-SchemaMatches $dbMeta $manifest.schema
        if ($manifest.instanceId -cne $again.Id) { Stop-Operation 'ARCHIVE_INSTANCE_MISMATCH' 'Restore source identity changed during validation.' }
        $newId = [guid]::NewGuid().ToString()
        $marker = New-RestoredMarker $newId ([string]$manifest.codeHead)
        $markerBytes = [Text.UTF8Encoding]::new($false).GetBytes(($marker | ConvertTo-Json -Depth 16 -Compress))
        $markerPath = Join-Path $stage 'instance.json'
        $markerStream = [IO.File]::Open($markerPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $markerStream.Write($markerBytes,0,$markerBytes.Length) } finally { $markerStream.Dispose() }
        if (Test-Path -LiteralPath (Join-Path $stage 'runtime\process.json')) { Stop-Operation 'RESTORE_LAYOUT_REJECT' 'A process marker unexpectedly appeared in staging.' }
        if (Test-Path -LiteralPath $Destination) { Stop-Operation 'DESTINATION_EXISTS' 'The restore destination appeared during staging; it was not overwritten.' }
        $stageLock.Dispose()
        $stageLock = $null
        [IO.Directory]::Move($stage,$Destination)
        $promoted = $true
        $stage = $null
        [ordered]@{ status='PASS'; action='Restore'; restoreRoot=$Destination; newInstanceId=$newId; files=@($manifest.files).Count; codeHead=$manifest.codeHead } | ConvertTo-Json -Compress
    } finally {
        if ($validated) { $validated.Zip.Dispose(); $validated.Stream.Dispose() }
        if ($stageLock) { $stageLock.Dispose() }
        if ($sourceLock) { $sourceLock.Dispose() }
        if (-not $promoted -and $stage -and (Test-Path -LiteralPath $stage)) {
            $expectedParent = (Get-CanonicalPath $Layout.RuntimeRoot).TrimEnd('\') + '\'
            if ((Get-CanonicalPath $stage).StartsWith($expectedParent,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($stage) -like '.instance-restored-stage-*') {
                [IO.Directory]::Delete($stage,$true)
            }
        }
    }
}

try {
    $phpPath = Assert-PhpExe $PhpExe
    $layout = Get-Layout $InstanceRoot
    Assert-PrivateRoot $layout.PrivateRoot
    $archivePath = Assert-ArchiveLocation $Archive $layout -MustExist:($Action -eq 'Restore')
    if ($Action -eq 'Backup' -and (Test-Path -LiteralPath $archivePath)) { Stop-Operation 'ARCHIVE_EXISTS' 'Backup refuses to overwrite an existing archive.' }
    if ($Action -eq 'Restore') {
        if ([string]::IsNullOrWhiteSpace($RestoreRoot)) { Stop-Operation 'RESTORE_ROOT_REQUIRED' 'RestoreRoot is required for restore.' }
        $destination = Get-CanonicalPath $RestoreRoot
        $restoreName = [IO.Path]::GetFileName($destination)
        if (-not (Test-SamePath ([IO.Path]::GetDirectoryName($destination)) $layout.RuntimeRoot) -or $restoreName -cnotmatch '^instance-restored(?:-[A-Za-z0-9][A-Za-z0-9_-]{0,63})?$') {
            Stop-Operation 'RESTORE_PATH_REJECT' 'RestoreRoot must be a new direct instance-restored child of the frozen runtime root.'
        }
        if (Test-Path -LiteralPath $destination) { Stop-Operation 'DESTINATION_EXISTS' 'Restore requires a destination that does not exist.' }
        Assert-NoReparse $layout.RuntimeRoot -MustExist
        Assert-NoReparse $destination
    } else { $destination = '' }
    $instanceInfo = Read-InstanceMarker $layout.InstanceRoot
    $head = Get-CurrentHead
    if (-not (Test-CompatibleCodeHead $instanceInfo.CodeHead $head)) { Stop-Operation 'CODE_HEAD_MISMATCH' 'The instance code HEAD is not an ancestor with an identical server tree.' }
    if ($Action -eq 'Backup') { Invoke-Backup $layout $phpPath $archivePath $instanceInfo $head; exit 0 }
    Invoke-Restore $layout $phpPath $archivePath $destination $instanceInfo $head
    exit 0
} catch {
    [Console]::Error.WriteLine(('ERROR ' + $_.Exception.Message))
    exit 2
}
