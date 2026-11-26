$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$tool = Join-Path $repoRoot 'scripts\local\picoradar-backup-qa.ps1'
$php = 'C:\xampphp\php\php.exe'
$powershell = (Get-Process -Id $PID).Path
$runId = [guid]::NewGuid().ToString('N')
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "picoradar-c30-b-$runId"
$base = $fixtureRoot
$instance = Join-Path $base 'runtime\instance-a'
$private = Join-Path $base 'private'
$archive = Join-Path $private 'fixture-backup.zip'
$restore = Join-Path $base 'runtime\instance-restored'
$results = [Collections.Generic.List[object]]::new()
$log = [Collections.Generic.List[string]]::new()
$server = $null

function Write-Case([string]$Name, [string]$Status, [string]$Detail = '') {
    $entry = [pscustomobject]@{ name = $Name; status = $Status; detail = $Detail }
    $script:results.Add($entry)
    $line = "$Status $Name" + $(if ($Detail) { " :: $Detail" } else { '' })
    $line = $line.Replace($script:fixtureRoot, '<fixture-root>')
    $script:log.Add($line)
    Write-Host $line
}

function Invoke-Child([string[]]$Arguments, [string]$InputText = '') {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $script:powershell
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.CreateNoWindow = $true
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'Unable to start child PowerShell.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.Write($InputText)
    $process.StandardInput.Close()
    $process.WaitForExit()
    [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdoutTask.GetAwaiter().GetResult()
        StdErr = $stderrTask.GetAwaiter().GetResult()
    }
}

function Invoke-Tool([string[]]$Arguments) {
    Invoke-Child (@('-NoLogo', '-NoProfile', '-File', $script:tool) + $Arguments)
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Set-PrivateAcl([string]$Path) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $sid = $identity.User
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner($sid)
    $inheritance = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $propagation = [Security.AccessControl.PropagationFlags]::None
    $allow = [Security.AccessControl.AccessControlType]::Allow
    foreach ($allowedSid in @($sid, [Security.Principal.SecurityIdentifier]::new('S-1-5-18'), [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new($allowedSid, [Security.AccessControl.FileSystemRights]::FullControl, $inheritance, $propagation, $allow)
        [void]$acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Invoke-Php([string]$Code, [hashtable]$InputObject) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $script:php
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.CreateNoWindow = $true
    foreach ($argument in @('-d', 'extension_dir=C:\xampphp\php\ext', '-d', 'extension=php_sqlite3.dll', '-r', $Code)) {
        $start.ArgumentList.Add($argument)
    }
    $start.Environment['PATH'] = "C:\xampphp\php;C:\xampphp\php\ext;$env:PATH"
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'Unable to start PHP fixture helper.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.Write(($InputObject | ConvertTo-Json -Compress -Depth 8))
    $process.StandardInput.Close()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "PHP fixture helper failed with exit $($process.ExitCode): $($stderrTask.GetAwaiter().GetResult())"
    }
    $stdoutTask.GetAwaiter().GetResult() | ConvertFrom-Json -AsHashtable
}

function New-Database([string]$Path, [string]$Migration) {
    $code = @'
$inputData = json_decode(stream_get_contents(STDIN), true, 16, JSON_THROW_ON_ERROR);
$db = new SQLite3($inputData['path'], SQLITE3_OPEN_READWRITE | SQLITE3_OPEN_CREATE);
$db->enableExceptions(true);
$db->exec('PRAGMA foreign_keys=ON');
$db->exec('CREATE TABLE migrations (id INTEGER PRIMARY KEY, migration TEXT NOT NULL, batch INTEGER NOT NULL)');
$db->exec('CREATE TABLE fixture_parent (id INTEGER PRIMARY KEY, label TEXT NOT NULL)');
$db->exec('CREATE TABLE fixture_child (id INTEGER PRIMARY KEY, parent_id INTEGER NOT NULL REFERENCES fixture_parent(id), label TEXT NOT NULL)');
$db->exec("INSERT INTO migrations (migration,batch) VALUES ('" . SQLite3::escapeString($inputData['migration']) . "',1)");
$db->exec("INSERT INTO fixture_parent VALUES (1,'synthetic-parent')");
$db->exec("INSERT INTO fixture_child VALUES (1,1,'synthetic-child')");
$db->exec('PRAGMA user_version=7');
$db->close();
echo json_encode(['created'=>true], JSON_THROW_ON_ERROR);
'@
    $out = Invoke-Php $code @{ path = $Path; migration = $Migration }
    Assert-True ($out.created -eq $true) 'Fixture database was not created.'
}

function Get-DatabaseState([string]$Path) {
    $code = @'
$inputData = json_decode(stream_get_contents(STDIN), true, 16, JSON_THROW_ON_ERROR);
$db = new SQLite3($inputData['path'], SQLITE3_OPEN_READONLY);
$db->enableExceptions(true);
$migrations = [];
$result = $db->query('SELECT migration,batch FROM migrations ORDER BY migration,batch');
while ($row = $result->fetchArray(SQLITE3_ASSOC)) { $migrations[] = ['migration'=>$row['migration'],'batch'=>(int)$row['batch']]; }
$state = ['userVersion'=>(int)$db->querySingle('PRAGMA user_version'),'migrations'=>$migrations,'parent'=>$db->querySingle('SELECT label FROM fixture_parent WHERE id=1'),'child'=>$db->querySingle('SELECT label FROM fixture_child WHERE id=1')];
$db->close();
echo json_encode($state, JSON_THROW_ON_ERROR);
'@
    Invoke-Php $code @{ path = $Path }
}

function Get-MigrationName {
    $migration = Get-ChildItem -LiteralPath (Join-Path $script:repoRoot 'server\database\migrations') -Filter '*.php' -File | Sort-Object Name | Select-Object -First 1
    if (-not $migration) { throw 'No current Laravel migration is available for the synthetic schema fixture.' }
    $migration.BaseName
}

function New-Fixture {
    New-Item -ItemType Directory -Path (Join-Path $script:base 'runtime') -Force | Out-Null
    Set-PrivateAcl (Join-Path $script:base 'runtime')
    New-Item -ItemType Directory -Path $script:instance -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:instance 'runtime') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:instance 'data') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:instance 'storage\app\private') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:instance 'storage\app\public') -Force | Out-Null
    New-Item -ItemType Directory -Path $script:private -Force | Out-Null
    Set-PrivateAcl $script:private
    $instanceId = [guid]::NewGuid().ToString()
    $head = (& git -C $script:repoRoot rev-parse HEAD).Trim()
    $parent = (& git -C $script:repoRoot rev-parse 'HEAD^' 2>$null)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($parent -join ''))) {
        $parentHead = ($parent -join '').Trim()
        $headTree = (& git -C $script:repoRoot rev-parse "${head}:server" 2>$null)
        $parentTree = (& git -C $script:repoRoot rev-parse "${parentHead}:server" 2>$null)
        if ($LASTEXITCODE -eq 0 -and ($headTree -join '').Trim() -ceq ($parentTree -join '').Trim()) { $head = $parentHead }
    }
    $marker = [ordered]@{
        format = 'picoradar-local-qa/1'
        id = $instanceId
        backend = 'sqlite'
        scope = 'NON_PRODUCTION_SYNTHETIC'
        codeHead = $head
        state = 'initialized'
        paths = [ordered]@{
            database = 'data/picoradar.sqlite'
            storage = 'storage'
            private = 'storage/app/private'
            public = 'storage/app/public'
            runtime = 'runtime'
        }
    }
    $marker | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $script:instance 'instance.json') -Encoding utf8NoBOM
    $keyPath = Join-Path $script:private 'instance-a.app-key'
    [IO.File]::WriteAllText($keyPath, 'fixture-only-not-a-real-key')
    [IO.File]::WriteAllText((Join-Path $script:private 'operator.qa.password'), 'fixture-only-not-a-password')
    [IO.File]::WriteAllBytes((Join-Path $script:instance 'storage\app\private\sentinel.bin'), [byte[]](0, 1, 2, 255))
    [IO.File]::WriteAllText((Join-Path $script:instance 'storage\app\public\sentinel.json'), '{"fixture":"synthetic"}', [Text.UTF8Encoding]::new($false))
    New-Database (Join-Path $script:instance 'data\picoradar.sqlite') (Get-MigrationName)
}

function Add-ZipBytes([IO.Compression.ZipArchive]$Zip, [string]$Name, [byte[]]$Bytes) {
    $entry = $Zip.CreateEntry($Name, [IO.Compression.CompressionLevel]::NoCompression)
    $stream = $entry.Open()
    try { $stream.Write($Bytes, 0, $Bytes.Length) } finally { $stream.Dispose() }
}

function New-CorruptArchive([string]$Source, [string]$Destination) {
    $sourceStream = [IO.File]::Open($Source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $inputZip = [IO.Compression.ZipArchive]::new($sourceStream, [IO.Compression.ZipArchiveMode]::Read, $false)
    $outputStream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $outputZip = [IO.Compression.ZipArchive]::new($outputStream, [IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        foreach ($entry in $inputZip.Entries) {
            $output = $outputZip.CreateEntry($entry.FullName, [IO.Compression.CompressionLevel]::NoCompression)
            $inStream = $entry.Open(); $outStream = $output.Open()
            try {
                if ($entry.FullName -ceq 'data/picoradar.sqlite') {
                    $memory = [IO.MemoryStream]::new()
                    $inStream.CopyTo($memory)
                    $bytes = $memory.ToArray()
                    $memory.Dispose()
                    $bytes[0] = [byte]($bytes[0] -bxor 1)
                    $outStream.Write($bytes, 0, $bytes.Length)
                } else { $inStream.CopyTo($outStream) }
            } finally { $inStream.Dispose(); $outStream.Dispose() }
        }
    } finally { $outputZip.Dispose(); $outputStream.Dispose(); $inputZip.Dispose(); $sourceStream.Dispose() }
}

function New-TraversalArchive([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
    try { Add-ZipBytes $zip '../escaped-c30.txt' ([Text.Encoding]::UTF8.GetBytes('must-not-be-written')) }
    finally { $zip.Dispose(); $stream.Dispose() }
}

function Test-Case([string]$Name, [scriptblock]$Body) {
    try { & $Body; Write-Case $Name 'PASS' }
    catch { Write-Case $Name 'FAIL' $_.Exception.Message }
}

try {
    New-Fixture
    if (-not (Test-Path -LiteralPath $script:tool)) {
        Write-Case 'tool_available' 'FAIL' 'expected implementation is not present yet'
        throw 'TOOL_MISSING_RED'
    }

    Test-Case 'backup_snapshot_created' {
        $backup = Invoke-Tool @('-Action','Backup','-InstanceRoot',$script:instance,'-Archive',$script:archive,'-PhpExe',$script:php)
        Assert-True ($backup.ExitCode -eq 0) ("backup rejected: " + $backup.StdErr + $backup.StdOut)
        Assert-True (Test-Path -LiteralPath $script:archive -PathType Leaf) 'Backup archive was not created.'
    }

    Test-Case 'modified_member_rejected_without_restore' {
        $corrupt = Join-Path $script:private 'fixture-corrupt.zip'
        New-CorruptArchive $script:archive $corrupt
        $result = Invoke-Tool @('-Action','Restore','-InstanceRoot',$script:instance,'-Archive',$corrupt,'-RestoreRoot',$script:restore,'-PhpExe',$script:php)
        Assert-True ($result.ExitCode -ne 0) 'Corrupted archive was accepted.'
        Assert-True (-not (Test-Path -LiteralPath $script:restore)) 'Corrupt restore left a destination behind.'
    }

    Test-Case 'occupied_restore_destination_rejected_without_overwrite' {
        $occupied = $script:restore
        New-Item -ItemType Directory -Path $occupied | Out-Null
        $sentinel = Join-Path $occupied 'keep.txt'
        [IO.File]::WriteAllText($sentinel, 'preserve')
        $result = Invoke-Tool @('-Action','Restore','-InstanceRoot',$script:instance,'-Archive',$script:archive,'-RestoreRoot',$occupied,'-PhpExe',$script:php)
        Assert-True ($result.ExitCode -ne 0) 'Restore accepted an occupied destination.'
        Assert-True ([IO.File]::ReadAllText($sentinel) -ceq 'preserve') 'Restore overwrote the occupied destination.'
        Remove-Item -LiteralPath $sentinel -Force
        Remove-Item -LiteralPath $occupied -Force
    }

    Test-Case 'traversal_member_rejected_before_write' {
        $traversal = Join-Path $script:private 'fixture-traversal.zip'
        $escaped = Join-Path $script:base 'escaped-c30.txt'
        New-TraversalArchive $traversal
        $result = Invoke-Tool @('-Action','Restore','-InstanceRoot',$script:instance,'-Archive',$traversal,'-RestoreRoot',$script:restore,'-PhpExe',$script:php)
        Assert-True ($result.ExitCode -ne 0) 'Traversal member was accepted.'
        Assert-True (-not (Test-Path -LiteralPath $escaped)) 'Traversal wrote outside staging.'
        Assert-True (-not (Test-Path -LiteralPath $script:restore)) 'Traversal created a restore destination.'
    }

    Test-Case 'valid_backup_restore_roundtrip' {
        $restoreResult = Invoke-Tool @('-Action','Restore','-InstanceRoot',$script:instance,'-Archive',$script:archive,'-RestoreRoot',$script:restore,'-PhpExe',$script:php)
        Assert-True ($restoreResult.ExitCode -eq 0) ("restore rejected: " + $restoreResult.StdErr + $restoreResult.StdOut)
        Assert-True (Test-Path (Join-Path $script:restore 'data\picoradar.sqlite') -PathType Leaf) 'Restored database is missing.'
        $sourceDbState = Get-DatabaseState (Join-Path $script:instance 'data\picoradar.sqlite')
        $restoredDbState = Get-DatabaseState (Join-Path $script:restore 'data\picoradar.sqlite')
        Assert-True (($sourceDbState | ConvertTo-Json -Compress -Depth 8) -ceq ($restoredDbState | ConvertTo-Json -Compress -Depth 8)) 'Restored SQLite schema or canonical fixture rows differ.'
        $sourcePrivateBytes = [IO.File]::ReadAllBytes((Join-Path $script:instance 'storage\app\private\sentinel.bin'))
        $restoredPrivateBytes = [IO.File]::ReadAllBytes((Join-Path $script:restore 'storage\app\private\sentinel.bin'))
        Assert-True ($sourcePrivateBytes.Length -eq $restoredPrivateBytes.Length) 'Private storage sentinel length differs.'
        for ($i=0; $i -lt $sourcePrivateBytes.Length; $i++) { Assert-True ($sourcePrivateBytes[$i] -eq $restoredPrivateBytes[$i]) 'Private storage sentinel bytes differ.' }
        Assert-True ([IO.File]::ReadAllText((Join-Path $script:restore 'storage\app\public\sentinel.json')) -ceq '{"fixture":"synthetic"}') 'Public storage sentinel differs.'
        $sourceMarker = Get-Content -LiteralPath (Join-Path $script:instance 'instance.json') -Raw | ConvertFrom-Json
        $restoredMarker = Get-Content -LiteralPath (Join-Path $script:restore 'instance.json') -Raw | ConvertFrom-Json
        Assert-True ($sourceMarker.id -ne $restoredMarker.id) 'Restore reused the source instance id.'
        Assert-True (-not (Test-Path (Join-Path $script:restore 'runtime\process.json'))) 'Restore copied a process marker.'
        $zip = [IO.Compression.ZipFile]::OpenRead($script:archive)
        try {
            $names = @($zip.Entries | ForEach-Object FullName)
            Assert-True ($names -contains 'data/picoradar.sqlite') 'Archive omitted the database.'
            Assert-True ($names -contains 'storage/app/private/sentinel.bin') 'Archive omitted private synthetic storage.'
            Assert-True ($names -contains 'storage/app/public/sentinel.json') 'Archive omitted public synthetic storage.'
            Assert-True (-not ($names | Where-Object { $_ -match 'app-key|operator\.qa\.password|\.env|\.pem|\.pfx' })) 'Archive included a credential or secret-like file.'
        } finally { $zip.Dispose() }
    }

    Test-Case 'fresh_restore_slot_startable_without_overwrite' {
        $alternate = Join-Path (Join-Path $script:base 'runtime') 'instance-restored-second'
        $restoreResult = Invoke-Tool @('-Action','Restore','-InstanceRoot',$script:instance,'-Archive',$script:archive,'-RestoreRoot',$alternate,'-PhpExe',$script:php)
        Assert-True ($restoreResult.ExitCode -eq 0) ("fresh restore slot was rejected: " + $restoreResult.StdErr + $restoreResult.StdOut)
        Assert-True (Test-Path -LiteralPath (Join-Path $alternate 'data\picoradar.sqlite') -PathType Leaf) 'Fresh restore slot omitted its database.'
        $statusArgs = @('-NoLogo','-NoProfile','-File',(Join-Path $script:repoRoot 'scripts\local\picoradar-local-qa.ps1'),'Status','-RepoRoot',$script:repoRoot,'-RuntimeHome',(Join-Path $script:base 'runtime'),'-InstanceRoot',$alternate,'-PrivateRoot',$script:private,'-KeyFile',(Join-Path $script:private 'instance-a.app-key'),'-PasswordFile',(Join-Path $script:private 'operator.qa.password'),'-PhpExe',$script:php,'-ReportRoot',$script:fixtureRoot)
        $status = Invoke-Child $statusArgs
        Assert-True ($status.ExitCode -eq 0 -and $status.StdOut -match '"status":"STOPPED"') ("A tool rejected a fresh restore slot: " + $status.StdErr + $status.StdOut)
    }

    Test-Case 'active_server_rejected' {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start(); $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port; $listener.Stop()
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $script:php
        $start.UseShellExecute = $false
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $start.CreateNoWindow = $true
        foreach ($arg in @('-S',"127.0.0.1:$port",'-t',(Join-Path $script:repoRoot 'server\public'))) { $start.ArgumentList.Add($arg) }
        $start.Environment['PATH'] = "C:\xampphp\php;C:\xampphp\php\ext;$env:PATH"
        $script:server = [Diagnostics.Process]::new(); $script:server.StartInfo = $start
        Assert-True ($script:server.Start()) 'Synthetic PHP server did not start.'
        $ready = $false
        for ($try = 0; $try -lt 50; $try++) {
            try { $client=[Net.Sockets.TcpClient]::new(); $client.Connect('127.0.0.1',$port); $client.Dispose(); $ready=$true; break } catch { Start-Sleep -Milliseconds 100 }
        }
        Assert-True $ready 'Synthetic PHP server did not bind.'
        $proc = Get-Process -Id $script:server.Id
        $processMarker = [ordered]@{ instanceId = (Get-Content (Join-Path $script:instance 'instance.json') -Raw | ConvertFrom-Json).id; pid = $script:server.Id; createdAtUtc = $proc.StartTime.ToUniversalTime().ToString('o'); executable = $script:php; port = $port }
        $processMarker | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:instance 'runtime\process.json') -Encoding utf8NoBOM
        $result = Invoke-Tool @('-Action','Backup','-InstanceRoot',$script:instance,'-Archive',(Join-Path $script:private 'active.zip'),'-PhpExe',$script:php)
        Assert-True ($result.ExitCode -ne 0) 'Backup accepted a live server.'
        Assert-True (($result.StdErr + $result.StdOut) -match 'INSTANCE_ACTIVE') 'Live server was not classified as active.'
        Remove-Item -LiteralPath (Join-Path $script:instance 'runtime\process.json') -Force
        $script:server.Kill(); $script:server.WaitForExit(5000) | Out-Null; $script:server.Dispose(); $script:server=$null
    }

    Test-Case 'unverifiable_process_marker_rejected' {
        $proc = Get-Process -Id $PID
        $processMarker = [ordered]@{ instanceId = (Get-Content (Join-Path $script:instance 'instance.json') -Raw | ConvertFrom-Json).id; pid = $PID; createdAtUtc = $proc.StartTime.ToUniversalTime().ToString('o'); executable = $proc.Path; port = 65534 }
        $processMarker | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:instance 'runtime\process.json') -Encoding utf8NoBOM
        $result = Invoke-Tool @('-Action','Backup','-InstanceRoot',$script:instance,'-Archive',(Join-Path $script:private 'unverifiable.zip'),'-PhpExe',$script:php)
        Assert-True ($result.ExitCode -ne 0) 'Backup accepted an unverifiable process marker.'
        Assert-True (($result.StdErr + $result.StdOut) -match 'PROCESS_UNVERIFIABLE') 'Unverifiable process was not classified fail-closed.'
        Remove-Item -LiteralPath (Join-Path $script:instance 'runtime\process.json') -Force
    }

    $failed = @($script:results | Where-Object status -ne 'PASS')
    if ($failed.Count) { throw "FOCUSED_SUITE_FAILED=$($failed.Count)" }
    $summary = [ordered]@{ task='C30_V2_B'; suite='PASS'; cases=$script:results.Count; names=@($script:results | ForEach-Object name); timestampUtc=[DateTime]::UtcNow.ToString('o') }
    $script:log.Add(($summary | ConvertTo-Json -Compress -Depth 8))
    Write-Host "FOCUSED_SUITE=PASS cases=$($script:results.Count)"
}
catch {
    $script:log.Add("SUITE=FAIL reason=$($_.Exception.Message)")
    Write-Error $_
    exit 1
}
finally {
    if ($script:server) {
        try { if (-not $script:server.HasExited) { $script:server.Kill(); $script:server.WaitForExit(5000) | Out-Null } } catch { $script:log.Add('CLEANUP=BLOCKED_OWN_TEST_SERVER') }
        try { $script:server.Dispose() } catch { }
    }
    if (Test-Path -LiteralPath $script:fixtureRoot) {
        try { Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force; Write-Host 'FIXTURE_CLEANUP=PASS_OWN_TEMP_ROOT' }
        catch { Write-Host 'FIXTURE_CLEANUP=BLOCKED_OWN_TEMP_ROOT' }
    }
}
