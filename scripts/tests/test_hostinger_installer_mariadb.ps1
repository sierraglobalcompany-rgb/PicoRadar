param(
    [string] $ArtifactDirectory = 'artifacts/current/hostinger-staging',
    [string] $MariaDbRoot = 'C:\codex\_tool-cache\mariadb-11.8.8-winx64',
    [string] $PhpPath = 'C:\xampphp\php\php.exe'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$artifacts = (Resolve-Path -LiteralPath (Join-Path $root $ArtifactDirectory)).Path
$zip = @(Get-ChildItem -LiteralPath $artifacts -Filter 'PicoRadar-staging-hostinger-*.zip' -File)
if ($zip.Count -ne 1) { throw 'Exactly one Hostinger staging ZIP is required.' }

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('picoradar-hostinger-db-' + [guid]::NewGuid().ToString('N'))
$domainRoot = Join-Path $scratch 'domain'
$dataRoot = Join-Path $scratch 'mariadb-data'
$logs = Join-Path $scratch 'logs'
$rootPassword = 'Root-Test-Only-2026'
$database = 'picoradar_clean_room'
$restoreDatabase = 'picoradar_restore_probe'
$dbUser = 'picoradar_test'
$dbPassword = 'Db_${APP_NAME}_#" Unicode-á-2026'
$operatorPassword = 'Operator-Test-Only-2026'
$serverProcess = $null
$webProcess = $null
$succeeded = $false

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
$listener.Stop()

try {
    New-Item -ItemType Directory -Path $domainRoot, $dataRoot, $logs -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip[0].FullName, $domainRoot)

    $installer = Join-Path $MariaDbRoot 'bin/mariadb-install-db.exe'
    & $installer "--datadir=$dataRoot" "--password=$rootPassword" "--port=$port" --silent
    if ($LASTEXITCODE -ne 0) { throw 'MariaDB initialization failed.' }

    $ini = Join-Path $scratch 'my.ini'
    $basedirIni = $MariaDbRoot.Replace('\', '/')
    $datadirIni = $dataRoot.Replace('\', '/')
    [System.IO.File]::WriteAllText($ini, @"
[mysqld]
basedir=$basedirIni
datadir=$datadirIni
port=$port
bind-address=127.0.0.1
skip-name-resolve
skip-log-bin
max_connections=20
"@, [System.Text.UTF8Encoding]::new($false))

    $serverProcess = Start-Process -FilePath (Join-Path $MariaDbRoot 'bin/mysqld.exe') `
        -ArgumentList "--defaults-file=$ini", '--console' `
        -RedirectStandardOutput (Join-Path $logs 'mariadb.out.log') `
        -RedirectStandardError (Join-Path $logs 'mariadb.err.log') `
        -WindowStyle Hidden -PassThru

    $client = Join-Path $MariaDbRoot 'bin/mariadb.exe'
    $ready = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Milliseconds 250
        & $client --protocol=tcp --host=127.0.0.1 "--port=$port" --user=root "--password=$rootPassword" --silent --skip-column-names --execute='SELECT 1' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        if ($serverProcess.HasExited) { break }
    }
    if (-not $ready) { throw "MariaDB did not start. See $logs" }

    $sql = @"
CREATE DATABASE ``$database`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE ``$restoreDatabase`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$dbUser'@'127.0.0.1' IDENTIFIED BY '$dbPassword';
GRANT ALL PRIVILEGES ON ``$database``.* TO '$dbUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ``$restoreDatabase``.* TO '$dbUser'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
    & $client --protocol=tcp --host=127.0.0.1 "--port=$port" --user=root "--password=$rootPassword" --execute=$sql
    if ($LASTEXITCODE -ne 0) { throw 'Disposable database provisioning failed.' }

    $env:PICORADAR_TEST_DB_USER = $dbUser
    $env:PICORADAR_TEST_DB_PASSWORD = $dbPassword
    $env:PICORADAR_TEST_DB_NAME = $database
    $env:PICORADAR_TEST_OPERATOR_PASSWORD = $operatorPassword
    try {
        & $PhpPath (Join-Path $root 'scripts/tests/hostinger_installer_clean_room.php') $domainRoot '127.0.0.1' $port
        $harnessExit = $LASTEXITCODE
        if ($harnessExit -ne 0) { throw "The clean-room installer harness failed with exit code $harnessExit." }

        $privateRoot = Join-Path $domainRoot 'picoradar_app/current'
        $publicRoot = Join-Path $domainRoot 'public_html/picoradar'
        $webListener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $webListener.Start()
        $webPort = ([System.Net.IPEndPoint]$webListener.LocalEndpoint).Port
        $webListener.Stop()
        $webProcess = Start-Process -FilePath $PhpPath `
            -ArgumentList '-S', "127.0.0.1:$webPort", '-t', $publicRoot, (Join-Path $publicRoot 'index.php') `
            -WorkingDirectory $publicRoot -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $logs 'php-web.out.log') `
            -RedirectStandardError (Join-Path $logs 'php-web.err.log')
        $health = $null
        for ($attempt = 0; $attempt -lt 40; $attempt++) {
            Start-Sleep -Milliseconds 250
            try {
                $health = Invoke-WebRequest -Uri "http://127.0.0.1:$webPort/api/v1/health" -UseBasicParsing -TimeoutSec 2
                break
            } catch {
                if ($webProcess.HasExited) { break }
            }
        }
        if ($null -eq $health -or $health.StatusCode -ne 200) { throw 'Real HTTP health verification failed.' }
        $healthPayload = $health.Content | ConvertFrom-Json
        if ($healthPayload.status -ne 'ok' -or $healthPayload.apiVersion -ne 'v1') { throw 'Health response contract failed.' }
        $login = Invoke-WebRequest -Uri "http://127.0.0.1:$webPort/login" -UseBasicParsing -TimeoutSec 5
        if ($login.StatusCode -ne 200 -or $login.Content -notmatch 'PicoRadar') { throw 'Real HTTP login verification failed.' }

        $cronProbe = Join-Path $root 'scripts/tests/hostinger_cron_probe.php'
        $cronMarker = Join-Path $scratch 'cron-probe.marker'
        $dispatchOutput = (& $PhpPath $cronProbe $privateRoot dispatch $cronMarker).Trim()
        if ($LASTEXITCODE -ne 0 -or $dispatchOutput -ne 'QUEUED') { throw 'Synthetic cron job could not be queued.' }
        $cronOutput = (& $PhpPath (Join-Path $privateRoot 'bin/cron.php')).Trim()
        if ($LASTEXITCODE -ne 0 -or $cronOutput -ne 'OK') { throw "Cron verification failed: $cronOutput" }
        $cronStatus = (& $PhpPath $cronProbe $privateRoot status $cronMarker | ConvertFrom-Json)
        if ($cronStatus.queued -ne 0 -or $cronStatus.marker -ne 'processed') {
            throw "Cron did not process the synthetic queued job (queued=$($cronStatus.queued), failed=$($cronStatus.failed), marker=$($cronStatus.marker))."
        }

        Remove-Item -LiteralPath $cronMarker -Force
        $failureDispatchOutput = (& $PhpPath $cronProbe $privateRoot dispatch-failure $cronMarker).Trim()
        if ($LASTEXITCODE -ne 0 -or $failureDispatchOutput -ne 'QUEUED_FAILURE') { throw 'Synthetic failing cron job could not be queued.' }
        $failedCronOutput = (& $PhpPath (Join-Path $privateRoot 'bin/cron.php')).Trim()
        if ($LASTEXITCODE -ne 0 -or $failedCronOutput -ne 'OK') { throw "Cron failure-path runner failed: $failedCronOutput" }
        $failedStatus = (& $PhpPath $cronProbe $privateRoot status $cronMarker | ConvertFrom-Json)
        if ($failedStatus.failed -lt 1 -or $failedStatus.queued -ne 0) { throw 'Failed cron job was not recorded honestly.' }
        $recoveryDispatchOutput = (& $PhpPath $cronProbe $privateRoot dispatch $cronMarker).Trim()
        if ($LASTEXITCODE -ne 0 -or $recoveryDispatchOutput -ne 'QUEUED') { throw 'Synthetic recovery cron job could not be queued.' }
        $recoveryCronOutput = (& $PhpPath (Join-Path $privateRoot 'bin/cron.php')).Trim()
        if ($LASTEXITCODE -ne 0 -or $recoveryCronOutput -ne 'OK') { throw 'Cron did not recover after a failed job.' }

        $cronLock = Join-Path $privateRoot 'storage/framework/picoradar-cron.lock'
        $lockReady = Join-Path $scratch 'cron-lock.ready'
        $lockHolder = Start-Process -FilePath $PhpPath `
            -ArgumentList (Join-Path $root 'scripts/tests/hold_file_lock.php'), $cronLock, $lockReady, '3' `
            -WindowStyle Hidden -PassThru
        for ($attempt = 0; $attempt -lt 40 -and -not (Test-Path -LiteralPath $lockReady); $attempt++) {
            Start-Sleep -Milliseconds 100
        }
        if (-not (Test-Path -LiteralPath $lockReady)) { throw 'Cron overlap probe did not acquire its lock.' }
        $overlapOutput = (& $PhpPath (Join-Path $privateRoot 'bin/cron.php')).Trim()
        if ($LASTEXITCODE -ne 0 -or $overlapOutput -ne 'SKIPPED_LOCKED') { throw "Cron overlap contract failed: $overlapOutput" }
        $lockHolder.WaitForExit(5000) | Out-Null

        $storageProbe = Join-Path $privateRoot 'storage/app/public/backup-probe.txt'
        [System.IO.File]::WriteAllText($storageProbe, 'synthetic-backup-probe', [System.Text.UTF8Encoding]::new($false))
        $backupRoot = Join-Path $scratch 'synthetic-backup'
        $restoredStorage = Join-Path $scratch 'synthetic-restored-storage'
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $privateRoot 'storage/app/public') -Destination (Join-Path $backupRoot 'public') -Recurse -Force
        $dumpPath = Join-Path $backupRoot 'database.sql'
        $dump = Join-Path $MariaDbRoot 'bin/mariadb-dump.exe'
        & $dump --protocol=tcp --host=127.0.0.1 "--port=$port" --user=root "--password=$rootPassword" --single-transaction --skip-comments "--result-file=$dumpPath" $database
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $dumpPath)) { throw 'Synthetic database backup failed.' }
        $dumpUnix = $dumpPath.Replace('\', '/')
        & $client --protocol=tcp --host=127.0.0.1 "--port=$port" --user=root "--password=$rootPassword" "--database=$restoreDatabase" "--execute=source $dumpUnix"
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic database restore failed.' }
        $restoredOperator = (& $client --protocol=tcp --host=127.0.0.1 "--port=$port" --user=root "--password=$rootPassword" "--database=$restoreDatabase" --silent --skip-column-names --execute="SELECT CONCAT(email, '|', role, '|', is_active) FROM users LIMIT 1").Trim()
        if ($restoredOperator -ne 'owner@example.test|super_admin|1') { throw 'Restored operator contract failed.' }
        Copy-Item -LiteralPath (Join-Path $backupRoot 'public') -Destination $restoredStorage -Recurse -Force
        $sourceProbeHash = (Get-FileHash -LiteralPath $storageProbe -Algorithm SHA256).Hash
        $restoredProbeHash = (Get-FileHash -LiteralPath (Join-Path $restoredStorage 'backup-probe.txt') -Algorithm SHA256).Hash
        if ($sourceProbeHash -ne $restoredProbeHash) { throw 'Synthetic storage restore failed.' }

        Push-Location $privateRoot
        try {
            & $PhpPath artisan migrate:rollback --force --no-interaction
            if ($LASTEXITCODE -ne 0) { throw 'Migration rollback verification failed.' }
        } finally {
            Pop-Location
        }
    } finally {
        Remove-Item Env:PICORADAR_TEST_DB_USER -ErrorAction SilentlyContinue
        Remove-Item Env:PICORADAR_TEST_DB_PASSWORD -ErrorAction SilentlyContinue
        Remove-Item Env:PICORADAR_TEST_DB_NAME -ErrorAction SilentlyContinue
        Remove-Item Env:PICORADAR_TEST_OPERATOR_PASSWORD -ErrorAction SilentlyContinue
    }

    Write-Output "PASS: extracted package installed on disposable MariaDB 11.8.8; operator, login, health, protected routing, real queue cron, overlap, failure recovery, backup/restore, links, and rollback verified."
    $succeeded = $true
} finally {
    if ($webProcess -and -not $webProcess.HasExited) {
        Stop-Process -Id $webProcess.Id -Force -ErrorAction SilentlyContinue
        $webProcess.WaitForExit(5000) | Out-Null
    }
    if ($serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
        $serverProcess.WaitForExit(5000) | Out-Null
    }
    if ($succeeded -and (Test-Path -LiteralPath $scratch)) {
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    } elseif (Test-Path -LiteralPath $scratch) {
        Write-Warning "Clean-room files preserved for diagnosis: $scratch"
    }
}
