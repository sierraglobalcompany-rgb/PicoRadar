[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Backup','Restore')][string]$Action,
    [Parameter(Mandatory)][string]$PrivateRoot,
    [Parameter(Mandatory)][string]$SourcePrivateRoot,
    [Parameter(Mandatory)][string]$TargetPrivateRoot,
    [Parameter(Mandatory)][string]$MariaDbRoot,
    [string]$BackupManifest = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$privatePath = [IO.Path]::GetFullPath($PrivateRoot)
$sourcePath = [IO.Path]::GetFullPath($SourcePrivateRoot)
$targetPath = [IO.Path]::GetFullPath($TargetPrivateRoot)
$mariaPath = [IO.Path]::GetFullPath($MariaDbRoot)
$mariaClient = Join-Path $mariaPath 'bin\mariadb.exe'
$mariaDump = Join-Path $mariaPath 'bin\mariadb-dump.exe'
$helper = Join-Path $PSScriptRoot '..\c32\mariadb-qa.ps1'
$guardModule = Join-Path $PSScriptRoot 'mariadb-catalog-guards.psm1'
Import-Module $guardModule -Force
$allowedTables = @('audit_logs','datasets','geographic_units','jurisdictions','jurisdiction_geographic_unit','migrations')
$logRoot = Join-Path $privatePath 'logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

function Assert-PrivateRoot([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw 'BLOCKED_PRIVATE_ROOT_MISSING' }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'BLOCKED_PRIVATE_ROOT_REPARSE' }
    $acl = Get-Acl -LiteralPath $Path
    if (-not $acl.AreAccessRulesProtected) { throw 'BLOCKED_PRIVATE_ROOT_INHERITS_ACL' }
    $expected = @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18','S-1-5-32-544')
    $actual = @($acl.Access | ForEach-Object { $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value } | Sort-Object -Unique)
    if (@($actual | Where-Object { $_ -notin $expected }).Count -gt 0 -or @($expected | Where-Object { $_ -notin $actual }).Count -gt 0) { throw 'BLOCKED_PRIVATE_ROOT_ACL' }
}

function Get-InstanceMeta([string]$Root) {
    $marker = Join-Path (Join-Path $Root 'mariadb') 'qa-instance.json'
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { throw 'BLOCKED_INSTANCE_MARKER_MISSING' }
    $meta = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
    if ($meta.schemaVersion -ne 1 -or -not ([IO.Path]::GetFullPath([string]$meta.privateRoot)).Equals([IO.Path]::GetFullPath($Root),[StringComparison]::OrdinalIgnoreCase)) { throw 'BLOCKED_INSTANCE_MARKER_MISMATCH' }
    if (-not (Test-Path -LiteralPath $meta.appOptions -PathType Leaf) -or -not (Test-Path -LiteralPath $meta.rootOptions -PathType Leaf)) { throw 'BLOCKED_INSTANCE_OPTIONS_MISSING' }
    return $meta
}

function Invoke-HelperStatus([string]$Root) {
    $output = @(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $helper -Action Status -PrivateRoot $Root -MariaDbRoot $mariaPath 2>&1)
    $code = $LASTEXITCODE
    if ($code -ne 0 -or ($output -join "`n") -notmatch 'DB_STATUS=RUNNING') { throw 'BLOCKED_INSTANCE_STATUS' }
}

function Invoke-Native([string]$Exe,[string[]]$NativeArgs,[int]$TimeoutMs=120000,[byte[]]$InputBytes=$null) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Exe
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.RedirectStandardInput = $null -ne $InputBytes
    foreach ($argument in $NativeArgs) { [void]$start.ArgumentList.Add([string]$argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'BLOCKED_NATIVE_PROCESS_START' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if ($null -ne $InputBytes) {
        try { $process.StandardInput.BaseStream.Write($InputBytes,0,$InputBytes.Length); $process.StandardInput.BaseStream.Flush() }
        finally { $process.StandardInput.Close() }
    }
    if (-not $process.WaitForExit($TimeoutMs)) {
        $ownedPid = $process.Id
        try { $process.Kill() } catch { }
        [void]$process.WaitForExit()
        throw "BLOCKED_NATIVE_TIMEOUT_PID_$ownedPid"
    }
    return [pscustomobject]@{exitCode=$process.ExitCode;stdout=$stdoutTask.GetAwaiter().GetResult();stderr=$stderrTask.GetAwaiter().GetResult()}
}

function Invoke-Query($Meta,[string]$Sql) {
    $nativeArgs = @("--defaults-file=$($Meta.appOptions)",'--protocol=TCP','--connect-timeout=5','--batch','--raw','--skip-column-names',"--execute=$Sql")
    $result = Invoke-Native $mariaClient $nativeArgs 30000
    if ($result.exitCode -ne 0) {
        $safeError = [string]$result.stderr -replace '(?i)using password:\s*(YES|NO)','using password: <redacted>' -replace '(?i)password\s*[=:]\s*\S+','password=<redacted>'
        $failure = [ordered]@{sql=$Sql;exitCode=$result.exitCode;stderr=$safeError;observedUtc=[DateTime]::UtcNow.ToString('o')}
        [IO.File]::WriteAllText((Join-Path $logRoot 'catalog-query-failure.json'),($failure|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
        throw 'BLOCKED_MARIADB_READ_QUERY'
    }
    return @($result.stdout -split "`r?`n" | Where-Object { $_ -ne '' })
}

function Assert-Identity($Meta) {
    $line = @(Invoke-Query $Meta 'SELECT DATABASE(),@@port,@@datadir,VERSION(),CURRENT_USER();')
    if ($line.Count -ne 1) { throw 'BLOCKED_DATABASE_IDENTITY_QUERY' }
    $fields = $line[0] -split "`t",5
    $actualData = ([string]$fields[2]).Replace('/','\').Replace('\\','\').TrimEnd('\')
    $expectedData = ([string]$Meta.datadir).Replace('/','\').Replace('\\','\').TrimEnd('\')
    if ($fields.Count -ne 5 -or $fields[0] -ne $Meta.database -or [int]$fields[1] -ne [int]$Meta.port -or -not $actualData.Equals($expectedData,[StringComparison]::OrdinalIgnoreCase) -or $fields[4] -ne "$($Meta.dbUser)@127.0.0.1") { throw 'BLOCKED_DATABASE_IDENTITY_MISMATCH' }
    return [pscustomobject]@{privateRoot=[string]$Meta.privateRoot;datadir=[string]$Meta.datadir;database=[string]$Meta.database;dbUser=[string]$Meta.dbUser;pipeName=[string]$Meta.pipeName;port=[int]$Meta.port;version=[string]$fields[3]}
}

function Get-TableSnapshot($Meta) {
    $tableLines = Invoke-Query $Meta "SELECT TABLE_NAME,ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME;"
    $rows = foreach ($tableLine in $tableLines) {
        $parts = $tableLine -split "`t",2
        if ($parts.Count -ne 2 -or $parts[0] -notmatch '^[A-Za-z0-9_]+$') { throw 'BLOCKED_UNSAFE_TABLE_NAME' }
        $countLine = @(Invoke-Query $Meta "SELECT COUNT(*) FROM ``$($parts[0])``;")
        if ($countLine.Count -ne 1 -or $countLine[0] -notmatch '^\d+$') { throw 'BLOCKED_TABLE_COUNT' }
        [pscustomobject]@{table=$parts[0];engine=$parts[1];rows=[long]$countLine[0]}
    }
    return @($rows)
}

function Assert-CatalogContent($Meta,$Snapshot) {
    Assert-CatalogOnlyRows $Snapshot
    $nonCatalog = @($Snapshot | Where-Object { $_.rows -gt 0 -and $_.table -notin $allowedTables })
    if ($nonCatalog.Count -gt 0) { throw 'BLOCKED_NON_CATALOG_ROWS_PRESENT' }
    $required = @{migrations=26;geographic_units=1138;jurisdictions=73;jurisdiction_geographic_unit=82;datasets=1}
    foreach ($name in $required.Keys) {
        $row = $Snapshot | Where-Object table -eq $name | Select-Object -First 1
        if (-not $row -or [long]$row.rows -ne [long]$required[$name]) { throw "BLOCKED_EXPECTED_CATALOG_COUNT_$name" }
    }
    $zeroTables = @('users','app_users','app_login_challenges','app_access_tokens','datasets_releases','dataset_releases','restriction_rule_versions','restriction_imports','restriction_import_rows','restriction_publications','restriction_publication_items','campaigns','campaign_catalog_releases','sponsors','partner_inquiries','service_providers','service_provider_imports','service_provider_import_rows','cameras','camera_sources','camera_verifications','ansv_camera_imports','ansv_camera_import_rows')
    foreach ($name in $zeroTables) { $row=$Snapshot|Where-Object table -eq $name|Select-Object -First 1; if ($row -and [long]$row.rows -ne 0) { throw "BLOCKED_PRODUCT_ROWS_$name" } }
    $audit = @(Invoke-Query $Meta "SELECT COUNT(*) FROM audit_logs WHERE actor_id IS NOT NULL OR subject_type NOT IN ('App\\Models\\GeographicUnit','App\\Models\\Jurisdiction') OR action NOT IN ('geography.bootstrapped','jurisdiction.created','jurisdiction.coverage_attached');")
    if ($audit.Count -ne 1 -or [int]$audit[0] -ne 0) { throw 'BLOCKED_NON_CATALOG_AUDIT_ROWS' }
$off = @(Invoke-Query $Meta 'SELECT COUNT(*) FROM datasets WHERE `key`=''restrictions'' AND schema_version=2 AND enabled=0 AND publication_revision=0 AND current_version IS NULL;')
    if ($off.Count -ne 1 -or [int]$off[0] -ne 1) { throw 'BLOCKED_RESTRICTION_DATASET_NOT_OFF' }
    $levels = @(Invoke-Query $Meta "SELECT SUM(level='country'),SUM(level='department'),SUM(level='municipality') FROM geographic_units;")
    $levelCounts = $levels[0] -split "`t",3
    if ($levelCounts.Count -ne 3 -or [int]$levelCounts[0] -ne 1 -or [int]$levelCounts[1] -ne 33 -or [int]$levelCounts[2] -ne 1104) { throw 'BLOCKED_GEOGRAPHIC_LEVEL_COUNTS' }
    $enabledJurisdictions = @(Invoke-Query $Meta 'SELECT SUM(enabled=1),SUM(enabled=0) FROM jurisdictions;')
    $jurisdictionCounts = $enabledJurisdictions[0] -split "`t",2
    if ($jurisdictionCounts.Count -ne 2 -or [int]$jurisdictionCounts[0] -ne 5 -or [int]$jurisdictionCounts[1] -ne 68) { throw 'BLOCKED_JURISDICTION_ENABLEMENT_COUNTS' }
    $associatedMunicipalities = @(Invoke-Query $Meta "SELECT COUNT(DISTINCT gu.id) FROM geographic_units gu JOIN jurisdiction_geographic_unit jgu ON jgu.geographic_unit_id=gu.id WHERE gu.level='municipality';")
    $unassociatedMunicipalities = @(Invoke-Query $Meta "SELECT COUNT(*) FROM geographic_units gu WHERE gu.level='municipality' AND NOT EXISTS (SELECT 1 FROM jurisdiction_geographic_unit jgu WHERE jgu.geographic_unit_id=gu.id);")
    if ([int]$associatedMunicipalities[0] -ne 73 -or [int]$unassociatedMunicipalities[0] -ne 1031) { throw 'BLOCKED_MUNICIPALITY_ASSOCIATION_COUNTS' }
    $releaseRows = @(Invoke-Query $Meta 'SELECT COUNT(*) FROM dataset_releases;')
    if ([int]$releaseRows[0] -ne 0) { throw 'BLOCKED_RELEASE_ROWS_PRESENT' }
    $rules = @(Invoke-Query $Meta 'SELECT COUNT(*) FROM restriction_rule_versions;')
    $publications = @(Invoke-Query $Meta 'SELECT COUNT(*) FROM restriction_publications;')
    if ([int]$rules[0] -ne 0 -or [int]$publications[0] -ne 0) { throw 'BLOCKED_RESTRICTION_PRODUCT_ROWS_PRESENT' }
    $other = @(Invoke-Query $Meta "SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE ID <> CONNECTION_ID() AND USER NOT IN ('system user','event_scheduler');")
    if ($other.Count -ne 1 -or [int]$other[0] -ne 0) { throw 'BLOCKED_UNEXPECTED_DATABASE_CLIENTS' }
}

function Assert-NoPrivateStorageFiles([string]$SourceRoot) {
    $appStorage = Join-Path $SourceRoot 'laravel\storage\app'
    if (Test-Path -LiteralPath $appStorage -PathType Container) {
        $files = @(Get-ChildItem -LiteralPath $appStorage -Recurse -File -ErrorAction Stop)
        if ($files.Count -gt 0) { throw 'BLOCKED_SOURCE_STORAGE_FILES_REQUIRE_SEPARATE_BACKUP' }
    }
}
function New-DumpOptions($Meta,[string]$Path) {
    $passwordLine = Get-Content -LiteralPath $Meta.appOptions | Where-Object { $_ -match '^password=' } | Select-Object -First 1
    if (-not $passwordLine) { throw 'BLOCKED_DATABASE_OPTION_PASSWORD_MISSING' }
    $password = $passwordLine.Substring('password='.Length)
    $text = "[client]`nuser=$($Meta.dbUser)`npassword=$password`nhost=127.0.0.1`nport=$($Meta.port)`nprotocol=tcp`n"
    [IO.File]::WriteAllText($Path,$text,[Text.UTF8Encoding]::new($false))
}

function Assert-DumpSafe([string]$Path) {
    $reader = [IO.StreamReader]::new($Path,[Text.Encoding]::UTF8,$true)
    try {
        while (($line = $reader.ReadLine()) -ne $null) {
            if ($line -match '^\s*(USE\s+|CREATE\s+(DATABASE|USER)\b|DROP\s+(DATABASE|TABLE)\b|GRANT\b|REVOKE\b|CREATE\s+TRIGGER\b|DEFINER\s*=|LOCK\s+TABLES\b)') { throw 'BLOCKED_DUMP_CONTAINS_OUT_OF_SCOPE_SQL' }
        }
    } finally { $reader.Dispose() }
}

function Read-BackupManifest([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'BLOCKED_BACKUP_MANIFEST_MISSING' }
    $manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1 -or $manifest.scope -ne 'CATALOG_DB_ONLY' -or -not (Test-Path -LiteralPath $manifest.dumpPath -PathType Leaf)) { throw 'BLOCKED_BACKUP_MANIFEST_SCOPE' }
    $actual = Get-Item -LiteralPath $manifest.dumpPath
    $actualHash = (Get-FileHash -LiteralPath $manifest.dumpPath -Algorithm SHA256).Hash
    Assert-BackupBytes $actualHash ([string]$manifest.sha256) ([long]$actual.Length) ([long]$manifest.bytes)
    Assert-DumpSafe ([string]$manifest.dumpPath)
    return $manifest
}

Assert-PrivateRoot $privatePath
Assert-PrivateRoot $sourcePath
if ($targetPath -ne $sourcePath) { Assert-PrivateRoot $targetPath }
if (-not (Test-Path -LiteralPath $mariaClient -PathType Leaf) -or -not (Test-Path -LiteralPath $mariaDump -PathType Leaf)) { throw 'BLOCKED_MARIADB_TOOLS_MISSING' }
$lockPath = Join-Path $privatePath 'catalog-operation.lock'
$lock = $null
try { $lock = [IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) } catch { throw 'BLOCKED_CATALOG_OPERATION_LOCK' }
try {
    if ($Action -eq 'Backup') {
        $sourceMeta = Get-InstanceMeta $sourcePath
        Invoke-HelperStatus $sourcePath
        $sourceIdentity = Assert-Identity $sourceMeta
        Assert-NoPrivateStorageFiles $sourcePath
        $sourceSnapshot = Get-TableSnapshot $sourceMeta
        Assert-CatalogContent $sourceMeta $sourceSnapshot
        $backupDir = Join-Path $privatePath ('catalog-backup-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
        [void](New-Item -ItemType Directory -Path $backupDir)
        $dumpPath = Join-Path $backupDir 'catalog.sql'
        $optionsPath = Join-Path $backupDir 'client-dump.cnf'
        New-DumpOptions $sourceMeta $optionsPath
        $dumpArgs = @("--defaults-file=$optionsPath",'--single-transaction','--skip-lock-tables','--skip-add-drop-table','--skip-add-locks','--skip-comments','--default-character-set=utf8mb4','--hex-blob',"--result-file=$dumpPath",[string]$sourceMeta.database)
        $dump = Invoke-Native $mariaDump $dumpArgs 180000
        if ($dump.stderr.Length -gt 0) { [IO.File]::WriteAllText((Join-Path $logRoot 'catalog-dump.stderr.txt'),$dump.stderr,[Text.UTF8Encoding]::new($false)) }
        if ($dump.exitCode -ne 0) { throw "BLOCKED_MARIADB_DUMP_EXIT_$($dump.exitCode)" }
        if (-not (Test-Path -LiteralPath $dumpPath -PathType Leaf)) { throw 'BLOCKED_DUMP_FILE_MISSING' }
        Assert-DumpSafe $dumpPath
        $dumpItem = Get-Item -LiteralPath $dumpPath
        if ($dumpItem.Length -le 0) { throw 'BLOCKED_DUMP_EMPTY' }
        $dumpHash = (Get-FileHash -LiteralPath $dumpPath -Algorithm SHA256).Hash
        $manifest = [ordered]@{schemaVersion=1;scope='CATALOG_DB_ONLY';sourceHead='956e001cdbd87d5db27fc774b7a636f26a1c9159';sourceDatabase=$sourceIdentity.database;sourcePort=$sourceIdentity.port;sourceVersion=$sourceIdentity.version;sourceDatadir=$sourceIdentity.datadir;createdUtc=[DateTime]::UtcNow.ToString('o');bytes=$dumpItem.Length;sha256=$dumpHash;dumpPath=$dumpPath;tableCounts=$sourceSnapshot}
        $manifestPath = Join-Path $backupDir 'backup-manifest.json'
        [IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        [pscustomobject]@{result='PASS_SCOPED';scope='CATALOG_DB_ONLY';bytes=$dumpItem.Length;sha256=$dumpHash;tableCount=$manifest.tableCounts.Count;manifest=$manifestPath}|ConvertTo-Json -Compress
    } else {
        if ([string]::IsNullOrWhiteSpace($BackupManifest)) { throw 'BLOCKED_BACKUP_MANIFEST_REQUIRED' }
        $manifestPath = [IO.Path]::GetFullPath($BackupManifest)
        $manifest = Read-BackupManifest $manifestPath
        $sourceMeta = Get-InstanceMeta $sourcePath
        $targetMeta = Get-InstanceMeta $targetPath
        Invoke-HelperStatus $sourcePath
        Invoke-HelperStatus $targetPath
        $sourceIdentity = Assert-Identity $sourceMeta
        $targetIdentity = Assert-Identity $targetMeta
        Assert-DistinctMariaDbInstance $sourceIdentity $targetIdentity
        if ($sourceIdentity.database -ne [string]$manifest.sourceDatabase) { throw 'BLOCKED_BACKUP_SOURCE_IDENTITY' }
        $currentSourceSnapshot = Get-TableSnapshot $sourceMeta
        Assert-CatalogContent $sourceMeta $currentSourceSnapshot
        $empty = @(Invoke-Query $targetMeta 'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE=''BASE TABLE'';')
        if ($empty.Count -ne 1 -or [int]$empty[0] -ne 0) { throw 'BLOCKED_RESTORE_TARGET_NOT_EMPTY' }
        $grants = Invoke-Query $targetMeta 'SHOW GRANTS FOR CURRENT_USER();'
        if (@($grants | Where-Object { $_ -match 'ON \*\.\*' -and $_ -notmatch 'GRANT USAGE ON \*\.\*' }).Count -gt 0 -or @($grants | Where-Object { $_ -match 'WITH GRANT OPTION' }).Count -gt 0) { throw 'BLOCKED_TARGET_USER_PRIVILEGE_SCOPE' }
        $dumpBytes = [IO.File]::ReadAllBytes([string]$manifest.dumpPath)
        $attemptPath = Join-Path $privatePath 'restore-attempted.json'
        $attempt = [IO.File]::Open($attemptPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $bytes = [Text.Encoding]::UTF8.GetBytes(([ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');source=$sourceIdentity.database;target=$targetIdentity.database;dumpSha256=$manifest.sha256}|ConvertTo-Json -Compress));$attempt.Write($bytes,0,$bytes.Length) } finally { $attempt.Dispose() }
        $restoreArgs = @("--defaults-file=$($targetMeta.appOptions)",'--protocol=TCP','--connect-timeout=5','--default-character-set=utf8mb4',"--database=$($targetMeta.database)",'--binary-mode')
        $restore = Invoke-Native $mariaClient $restoreArgs 300000 $dumpBytes
        if ($restore.stderr.Length -gt 0) { [IO.File]::WriteAllText((Join-Path $logRoot 'catalog-restore.stderr.txt'),$restore.stderr,[Text.UTF8Encoding]::new($false)) }
        if ($restore.exitCode -ne 0) { throw "BLOCKED_MARIADB_RESTORE_EXIT_$($restore.exitCode)_TARGET_PRESERVED_NO_RETRY" }
        $targetSnapshot = Get-TableSnapshot $targetMeta
        $expected = @($manifest.tableCounts | ForEach-Object { "$($_.table)|$($_.engine)|$($_.rows)" } | Sort-Object)
        $actual = @($targetSnapshot | ForEach-Object { "$($_.table)|$($_.engine)|$($_.rows)" } | Sort-Object)
        $sourceRows = @($currentSourceSnapshot | ForEach-Object { "$($_.table)|$($_.engine)|$($_.rows)" } | Sort-Object)
        if ([string]::Join([char]10,$expected) -ne [string]::Join([char]10,$sourceRows)) { throw 'BLOCKED_SOURCE_CATALOG_CHANGED' }
        if (($expected -join "`n") -ne ($actual -join "`n")) { throw 'BLOCKED_RESTORE_TABLE_RECONCILIATION' }
        Assert-CatalogOnlyRows $targetSnapshot
        Assert-CatalogContent $targetMeta $targetSnapshot
        $comparison = [ordered]@{scope='CATALOG_DB_ONLY';sourceIdentity=$sourceIdentity;targetIdentity=$targetIdentity;tables=$targetSnapshot;sourceUnchanged=$true;targetMatchesSource=$true;dumpBytes=$manifest.bytes;dumpSha256=$manifest.sha256;restoredUtc=[DateTime]::UtcNow.ToString('o')}
        $resultPath = Join-Path $privatePath 'restore-result.json'
        [IO.File]::WriteAllText($resultPath,($comparison|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        [pscustomobject]@{result='PASS_SCOPED';scope='CATALOG_DB_ONLY';dumpBytes=$manifest.bytes;dumpSha256=$manifest.sha256;tableCount=$targetSnapshot.Count;geoUnits=1138;jurisdictions=73;coverageLinks=82;rules=0;releases=0;publications=0;sourceAlias='C32_QA';targetAlias='C33_QA'}|ConvertTo-Json -Compress
    }
} finally {
    if ($null -ne $lock) { $lock.Dispose() }
    if (Test-Path -LiteralPath $lockPath) { Remove-Item -LiteralPath $lockPath -Force }
}