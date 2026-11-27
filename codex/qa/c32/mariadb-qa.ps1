[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Start','Resume','Status','Migrate','Stop')][string]$Action,
    [Parameter(Mandatory)][string]$PrivateRoot,
    [Parameter(Mandatory)][string]$MariaDbRoot,
    [int]$Port = 0,
    [string]$PhpPath = ''
)

$ErrorActionPreference = 'Stop'
$privatePath = [IO.Path]::GetFullPath($PrivateRoot)
$mariaPath = [IO.Path]::GetFullPath($MariaDbRoot)
$serverExe = Join-Path $mariaPath 'bin\mariadbd.exe'
$installerExe = Join-Path $mariaPath 'bin\mariadb-install-db.exe'
$clientExe = Join-Path $mariaPath 'bin\mariadb.exe'
$instanceDir = Join-Path $privatePath 'mariadb'
$markerPath = Join-Path $instanceDir 'qa-instance.json'

function Assert-PrivateRoot {
    if (-not (Test-Path -LiteralPath $privatePath -PathType Container)) { throw 'BLOCKED_PRIVATE_ROOT_MISSING' }
    $item = Get-Item -LiteralPath $privatePath -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'BLOCKED_PRIVATE_ROOT_REPARSE' }
    $acl = Get-Acl -LiteralPath $privatePath
    if (-not $acl.AreAccessRulesProtected) { throw 'BLOCKED_PRIVATE_ROOT_INHERITS_ACL' }
    $expected = @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value, 'S-1-5-18', 'S-1-5-32-544')
    $actual = @($acl.Access | ForEach-Object { $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value } | Sort-Object -Unique)
    if (@($actual | Where-Object { $_ -notin $expected }).Count -gt 0 -or @($expected | Where-Object { $_ -notin $actual }).Count -gt 0) { throw 'BLOCKED_PRIVATE_ROOT_ACL' }
}

function Get-Instance {
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { throw 'BLOCKED_INSTANCE_MARKER_MISSING' }
    $meta = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
    if ($meta.schemaVersion -ne 1 -or $meta.privateRoot -ne $privatePath) { throw 'BLOCKED_INSTANCE_MARKER_MISMATCH' }
    return $meta
}

function Get-VerifiedProcess($meta) {
    $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$meta.pid)" -ErrorAction SilentlyContinue
    if (-not $processInfo) { return $null }
    if ($processInfo.ExecutablePath -ne $serverExe -or -not $processInfo.CommandLine.Contains('--no-defaults') -or -not $processInfo.CommandLine.Contains("--datadir=$($meta.datadir)") -or -not $processInfo.CommandLine.Contains("--port=$($meta.port)") -or -not $processInfo.CommandLine.Contains('--bind-address=127.0.0.1')) { throw 'BLOCKED_PROCESS_IDENTITY_MISMATCH' }
    return $processInfo
}

function Invoke-MariaClient([string[]]$ClientArgs, [string]$Sql = '') {
    if ($Sql -ne '') { $result = @($Sql | & $clientExe @ClientArgs 2>&1) }
    else { $result = @(& $clientExe @ClientArgs 2>&1) }
    $clientExit = $LASTEXITCODE
    if ($clientExit -ne 0) { throw "MARIADB_CLIENT_EXIT_$clientExit" }
    return $result
}

function Get-Status($meta) {
    $processInfo = Get-VerifiedProcess $meta
    if (-not $processInfo) {
        $open = @(Get-NetTCPConnection -State Listen -LocalPort ([int]$meta.port) -ErrorAction SilentlyContinue)
        if ($open.Count -eq 0) { return [pscustomobject]@{ stopped = $true; meta = $meta } }
        throw 'BLOCKED_UNOWNED_LISTENER'
    }
    $listeners = @(Get-NetTCPConnection -State Listen -LocalPort ([int]$meta.port) -ErrorAction SilentlyContinue)
    if ($listeners.Count -eq 0 -or @($listeners | Where-Object { $_.LocalAddress -ne '127.0.0.1' -or $_.OwningProcess -ne [int]$meta.pid }).Count -gt 0) { throw 'BLOCKED_LISTENER_IDENTITY_OR_BIND' }
    $query = Invoke-MariaClient @("--defaults-file=$($meta.appOptions)",'--protocol=TCP','--batch','--skip-column-names',"--execute=SELECT DATABASE(),@@port,@@datadir,VERSION(),CURRENT_USER();")
    $fields = (($query -join "`n").Trim() -split "`t")
    $actualData = ([string]$fields[2]).Replace('/','\').Replace('\\','\').TrimEnd('\')
    $expectedData = ([string]$meta.datadir).Replace('/','\').Replace('\\','\').TrimEnd('\')
    if ($fields.Count -lt 5 -or $fields[0] -ne $meta.database -or [int]$fields[1] -ne [int]$meta.port -or -not $actualData.Equals($expectedData,[StringComparison]::OrdinalIgnoreCase) -or $fields[4] -ne "$($meta.dbUser)@127.0.0.1") { throw 'BLOCKED_DATABASE_IDENTITY_MISMATCH' }
    return [pscustomobject]@{ stopped = $false; meta = $meta; version = $fields[3] }
}

Assert-PrivateRoot

switch ($Action) {
    'Start' {
        if (Test-Path -LiteralPath $markerPath) { throw 'BLOCKED_INSTANCE_ALREADY_EXISTS' }
        if (Test-Path -LiteralPath $instanceDir) { throw 'BLOCKED_MARIADB_ROOT_NOT_EMPTY' }
        foreach ($binary in @($serverExe,$installerExe,$clientExe)) { if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { throw 'BLOCKED_MARIADB_BINARY_MISSING' } }
        $fileVersion = (Get-Item -LiteralPath $serverExe).VersionInfo.FileVersion
        if ($fileVersion -notlike '11.8.8*') { throw 'BLOCKED_MARIADB_VERSION_MISMATCH' }
        $services = @(Get-CimInstance Win32_Service | Where-Object { $_.Name -match 'MariaDB|MySQL' -and $_.State -eq 'Running' })
        if ($services.Count -gt 0) { throw 'BLOCKED_EXISTING_DATABASE_SERVICE_RUNNING' }
        if ($Port -eq 0) {
            $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
            $listener.Start(); $Port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port; $listener.Stop()
        }
        if ($Port -lt 1024 -or $Port -eq 3306 -or (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)) { throw 'BLOCKED_PORT_UNAVAILABLE' }
        New-Item -ItemType Directory -Path $instanceDir | Out-Null
        $dataDir = Join-Path $instanceDir 'data'
        $logDir = Join-Path $instanceDir 'logs'
        New-Item -ItemType Directory -Path $dataDir,$logDir | Out-Null
        $suffix = [Guid]::NewGuid().ToString('N').Substring(0,10)
        $database = 'picoradar_c32_qa_' + $suffix
        $dbUser = 'picoradar_c32_' + $suffix
        $pipeName = 'PicoRadarC32' + $suffix
        $initOut = @(& $installerExe "--datadir=$dataDir" "--port=$Port" --skip-networking --silent 2>&1)
        if ($LASTEXITCODE -ne 0) { throw 'BLOCKED_MARIADB_INIT_FAILED' }
        if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) { throw 'BLOCKED_TCP_DURING_INIT' }
        $bootstrapArgs = @('--no-defaults',"--basedir=$mariaPath","--datadir=$dataDir","--port=$Port",'--skip-networking','--named-pipe',"--socket=$pipeName",'--skip-name-resolve','--console',"--log-error=$(Join-Path $logDir 'bootstrap.error.log')")
        $bootstrap = Start-Process -FilePath $serverExe -ArgumentList $bootstrapArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logDir 'bootstrap.out.log') -RedirectStandardError (Join-Path $logDir 'bootstrap.err.log')
        $pipeClientArgs = @('--no-defaults','--protocol=PIPE','--pipe',"--socket=$pipeName",'--user=root','--batch','--skip-column-names','--connect-timeout=2')
        $rootHosts = @()
        $probeSql = "SELECT Host FROM mysql.user WHERE User='root' ORDER BY Host;"
        $bootstrapClock = [Diagnostics.Stopwatch]::StartNew()
        while ($bootstrapClock.Elapsed.TotalSeconds -lt 20) {
            $b = Get-CimInstance Win32_Process -Filter "ProcessId=$($bootstrap.Id)" -ErrorAction Stop
            if (-not $b) { throw 'BLOCKED_BOOTSTRAP_PROCESS_EXITED' }
            try {
                $probeRows = @(Invoke-MariaClient $pipeClientArgs $probeSql)
                $rootHosts = @($probeRows | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -ne '' })
                if ($rootHosts.Count -gt 0) { break }
            } catch {
                $rootHosts = @()
            }
            Start-Sleep -Milliseconds 250
        }
        if ($rootHosts.Count -eq 0) { throw 'BLOCKED_LOCAL_BOOTSTRAP_PIPE' }
        if ($rootHosts.Count -eq 0) { throw 'BLOCKED_LOCAL_BOOTSTRAP_PIPE' }
        $computerHost = [string]$env:COMPUTERNAME
        $allowedHosts = @('localhost','127.0.0.1','::1',$computerHost)
        if (@($rootHosts | Where-Object { $_ -notin $allowedHosts }).Count -gt 0) { throw 'BLOCKED_UNEXPECTED_ROOT_HOST' }
        $rootPassword = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
        $dbPassword = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
        $rootOptions = Join-Path $instanceDir 'client-root.cnf'
        $appOptions = Join-Path $instanceDir 'client-app.cnf'
        [IO.File]::WriteAllText($rootOptions,"[client]`nuser=root`npassword=$rootPassword`nhost=127.0.0.1`nport=$Port`nprotocol=tcp`n",[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($appOptions,"[client]`nuser=$dbUser`npassword=$dbPassword`nhost=127.0.0.1`nport=$Port`nprotocol=tcp`ndatabase=$database`n",[Text.UTF8Encoding]::new($false))
        $sqlParts = @()
        foreach ($rootHost in $rootHosts) {
            if ($rootHost -ieq $computerHost) { $sqlParts += "DROP USER 'root'@'$rootHost';" }
            else { $sqlParts += "ALTER USER 'root'@'$rootHost' IDENTIFIED BY '$rootPassword';" }
        }
        $sqlParts += "CREATE DATABASE ``$database`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        $sqlParts += "CREATE USER '$dbUser'@'127.0.0.1' IDENTIFIED BY '$dbPassword';"
        $sqlParts += "GRANT ALL PRIVILEGES ON ``$database``.* TO '$dbUser'@'127.0.0.1';"
        $sqlParts += 'FLUSH PRIVILEGES;'
        $ddl = $sqlParts -join "`n"
        [void](Invoke-MariaClient $pipeClientArgs $ddl)
        $rootPipeArgs = @("--defaults-file=$rootOptions",'--protocol=PIPE',"--socket=$pipeName",'--batch','--skip-column-names',"--execute=SHUTDOWN;")
        [void](Invoke-MariaClient $rootPipeArgs)
        $shutdownDeadline = (Get-Date).AddSeconds(15)
        do { $alive = Get-CimInstance Win32_Process -Filter "ProcessId=$($bootstrap.Id)" -ErrorAction SilentlyContinue; if (-not $alive) { break }; Start-Sleep -Milliseconds 250 } while ((Get-Date) -lt $shutdownDeadline)
        if (Get-CimInstance Win32_Process -Filter "ProcessId=$($bootstrap.Id)" -ErrorAction SilentlyContinue) { throw 'BLOCKED_BOOTSTRAP_STOP' }
        $serverArgs = @('--no-defaults',"--basedir=$mariaPath","--datadir=$dataDir","--port=$Port",'--bind-address=127.0.0.1','--named-pipe',"--socket=$pipeName",'--skip-name-resolve','--skip-log-bin','--max-connections=20','--console',"--log-error=$(Join-Path $logDir 'mariadb.error.log')")
        $server = Start-Process -FilePath $serverExe -ArgumentList $serverArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logDir 'mariadb.out.log') -RedirectStandardError (Join-Path $logDir 'mariadb.err.log')
        $meta = [ordered]@{ schemaVersion=1; privateRoot=$privatePath; pid=$server.Id; serverExe=$serverExe; datadir=$dataDir; port=$Port; pipeName=$pipeName; database=$database; dbUser=$dbUser; rootOptions=$rootOptions; appOptions=$appOptions; version=$fileVersion; startedUtc=[DateTime]::UtcNow.ToString('o') }
        [IO.File]::WriteAllText($markerPath,($meta | ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
        $ready = $false
        for ($attempt = 0; $attempt -lt 120; $attempt++) { Start-Sleep -Milliseconds 250; try { $status = Get-Status ([pscustomobject]$meta); if (-not $status.stopped) { $ready = $true; break } } catch {} }
        if (-not $ready) { throw 'BLOCKED_LOOPBACK_SERVER_NOT_READY; use -Action Stop only after identity validation' }
        Write-Output "DB_START=PASS_SCOPED|VERSION=$($status.version)|DATABASE=$database|PORT=$Port|PID=$($server.Id)|BIND=127.0.0.1"
    }
    'Status' {
        $meta = Get-Instance
        $status = Get-Status $meta
        if ($status.stopped) { Write-Output 'DB_STATUS=STOPPED'; break }
        Write-Output "DB_STATUS=RUNNING|VERSION=$($status.version)|DATABASE=$($meta.database)|PORT=$($meta.port)|PID=$($meta.pid)|BIND=127.0.0.1"
    }
    'Resume' {
        $meta = Get-Instance
        $status = Get-Status $meta
        if (-not $status.stopped) { throw 'BLOCKED_INSTANCE_ALREADY_RUNNING' }
        foreach ($binary in @($serverExe,$clientExe)) { if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { throw 'BLOCKED_MARIADB_BINARY_MISSING' } }
        if ($meta.serverExe -ne $serverExe -or $meta.version -notlike '11.8.8*' -or (Get-Item -LiteralPath $serverExe).VersionInfo.FileVersion -notlike '11.8.8*') { throw 'BLOCKED_MARIADB_IDENTITY_MISMATCH' }
        $expectedData = [IO.Path]::GetFullPath((Join-Path $instanceDir 'data')).TrimEnd('\')
        $actualData = [IO.Path]::GetFullPath([string]$meta.datadir).TrimEnd('\')
        if (-not $actualData.Equals($expectedData,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $actualData -PathType Container)) { throw 'BLOCKED_DATADIR_IDENTITY_MISMATCH' }
        foreach ($path in @($instanceDir,$actualData)) {
            if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'BLOCKED_DATADIR_REPARSE' }
        }
        if ([int]$meta.port -lt 1024 -or [int]$meta.port -eq 3306 -or (Get-NetTCPConnection -State Listen -LocalPort ([int]$meta.port) -ErrorAction SilentlyContinue)) { throw 'BLOCKED_PORT_UNAVAILABLE' }
        $logDir = Join-Path $instanceDir 'logs'
        $serverArgs = @('--no-defaults',"--basedir=$mariaPath","--datadir=$actualData","--port=$($meta.port)",'--bind-address=127.0.0.1','--named-pipe',"--socket=$($meta.pipeName)",'--skip-name-resolve','--skip-log-bin','--max-connections=20','--console',"--log-error=$(Join-Path $logDir 'mariadb.error.log')")
        $server = Start-Process -FilePath $serverExe -ArgumentList $serverArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logDir 'mariadb.out.log') -RedirectStandardError (Join-Path $logDir 'mariadb.err.log')
        $meta.pid = $server.Id
        $meta.startedUtc = [DateTime]::UtcNow.ToString('o')
        [IO.File]::WriteAllText($markerPath,($meta | ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
        $ready = $false
        for ($attempt = 0; $attempt -lt 120; $attempt++) { Start-Sleep -Milliseconds 250; try { $status = Get-Status $meta; if (-not $status.stopped) { $ready = $true; break } } catch {} }
        if (-not $ready) { throw 'BLOCKED_RESUME_SERVER_NOT_READY; inspect the private MariaDB error log, then use identity-checked Stop' }
        Write-Output "DB_RESUME=PASS_SCOPED|VERSION=$($status.version)|DATABASE=$($meta.database)|PORT=$($meta.port)|PID=$($server.Id)|BIND=127.0.0.1|MIGRATE=NOT_RUN"
    }
    'Migrate' {
        $meta = Get-Instance
        $status = Get-Status $meta
        if ($status.stopped) { throw 'BLOCKED_INSTANCE_STOPPED' }
        if (-not $PhpPath -or -not (Test-Path -LiteralPath $PhpPath -PathType Leaf)) { throw 'BLOCKED_PHP_PATH' }
        $attemptPath = Join-Path $instanceDir 'migration-attempted.json'
        $resultPath = Join-Path $instanceDir 'migration-result.json'
        if (Test-Path -LiteralPath $attemptPath) { throw 'BLOCKED_MIGRATION_ALREADY_ATTEMPTED' }
        $cnf = Get-Content -LiteralPath $meta.appOptions
        $dbPassword = ($cnf | Where-Object { $_ -like 'password=*' } | Select-Object -First 1).Substring(9)
        $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $serverRoot = Join-Path $repoRoot 'server'
        $laravelRoot = Join-Path $privatePath 'laravel'
        $storageRoot = Join-Path $laravelRoot 'storage'
        $cacheRoot = Join-Path $laravelRoot 'bootstrap\cache'
        $compiledRoot = Join-Path $storageRoot 'framework\views'
        $logRoot = Join-Path $laravelRoot 'logs'
        New-Item -ItemType Directory -Path $cacheRoot,$compiledRoot,$logRoot,(Join-Path $storageRoot 'framework\cache\data'),(Join-Path $storageRoot 'framework\sessions') -Force | Out-Null
        $relativeCache = [IO.Path]::GetRelativePath($serverRoot,$cacheRoot).Replace('\','/')
        $envNames = @((Get-ChildItem Env: | Where-Object { $_.Name -match '^(APP_|DB_|MAIL_|REDIS_|SESSION_|CACHE_|QUEUE_|FILESYSTEM_|DATASET_|CAMPAIGN_|PICORADAR_)|^(DATABASE_URL)$' } | Select-Object -ExpandProperty Name))
        $envNames += @('APP_ENV','APP_DEBUG','APP_KEY','APP_NAME','APP_URL','APP_CONFIG_CACHE','APP_ROUTES_CACHE','APP_EVENTS_CACHE','APP_PACKAGES_CACHE','APP_SERVICES_CACHE','VIEW_COMPILED_PATH','LARAVEL_STORAGE_PATH','PICORADAR_PUBLIC_PATH','DB_CONNECTION','DB_URL','DATABASE_URL','DB_HOST','DB_PORT','DB_DATABASE','DB_USERNAME','DB_PASSWORD','DB_SOCKET','SESSION_DRIVER','CACHE_STORE','QUEUE_CONNECTION','MAIL_MAILER','LOG_CHANNEL','LOG_LEVEL','FILESYSTEM_DISK','DATASET_DRAFT_DISK','DATASET_PUBLISHED_DISK','DATASET_PUBLIC_BASE_URL','CAMPAIGN_PUBLIC_CATALOG_ENABLED','CAMPAIGN_PUBLIC_BASE_URL','PICORADAR_ACCOUNTS_ENABLED','PICORADAR_ACCOUNT_EMAIL_ENABLED','PICORADAR_MARKETING_SEND_ENABLED','PICORADAR_SPONSORED_CAMPAIGNS_ENABLED')
        $envNames = @($envNames | Sort-Object -Unique)
        $oldEnv = @{}
        foreach ($name in $envNames) { $oldEnv[$name] = [Environment]::GetEnvironmentVariable($name,'Process'); [Environment]::SetEnvironmentVariable($name,$null,'Process') }
        $oldPath = [Environment]::GetEnvironmentVariable('PATH','Process')
        $envValues = @{
            APP_ENV='local'; APP_DEBUG='false'; APP_KEY=('base64:' + [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))); APP_NAME='PicoRadar C32 DB QA'; APP_URL='http://127.0.0.1'
            APP_CONFIG_CACHE="$relativeCache/config.php"; APP_ROUTES_CACHE="$relativeCache/routes-v7.php"; APP_EVENTS_CACHE="$relativeCache/events.php"; APP_PACKAGES_CACHE="$relativeCache/packages.php"; APP_SERVICES_CACHE="$relativeCache/services.php"
            VIEW_COMPILED_PATH=$compiledRoot; LARAVEL_STORAGE_PATH=$storageRoot; PICORADAR_PUBLIC_PATH=(Join-Path $serverRoot 'public')
            DB_CONNECTION='mariadb'; DB_URL=''; DATABASE_URL=''; DB_HOST='127.0.0.1'; DB_PORT=[string]$meta.port; DB_DATABASE=[string]$meta.database; DB_USERNAME=[string]$meta.dbUser; DB_PASSWORD=$dbPassword; DB_SOCKET=''
            SESSION_DRIVER='file'; CACHE_STORE='file'; QUEUE_CONNECTION='sync'; MAIL_MAILER='array'; LOG_CHANNEL='single'; LOG_LEVEL='warning'
            FILESYSTEM_DISK='local'; DATASET_DRAFT_DISK='local'; DATASET_PUBLISHED_DISK='public'; DATASET_PUBLIC_BASE_URL='/storage'
            CAMPAIGN_PUBLIC_CATALOG_ENABLED='false'; CAMPAIGN_PUBLIC_BASE_URL=''; PICORADAR_ACCOUNTS_ENABLED='false'; PICORADAR_ACCOUNT_EMAIL_ENABLED='false'; PICORADAR_MARKETING_SEND_ENABLED='false'; PICORADAR_SPONSORED_CAMPAIGNS_ENABLED='false'
        }
        try {
            foreach ($name in $envValues.Keys) { [Environment]::SetEnvironmentVariable($name,[string]$envValues[$name],'Process') }
            $phpDir = Split-Path -Parent $PhpPath
            [Environment]::SetEnvironmentVariable('PATH',"$phpDir;$phpDir\ext;$oldPath",'Process')
            $extensionDir = Join-Path $phpDir 'ext'
            $extensionArgs = @('-d',"extension_dir=$extensionDir")
            $extProbe = & $PhpPath '-r' 'echo extension_loaded("pdo_mysql") ? "yes" : "no";' 2>&1
            if ($LASTEXITCODE -ne 0) { throw 'BLOCKED_PHP_EXTENSION_PROBE' }
            if (($extProbe -join '').Trim() -ne 'yes') {
                if (-not (Test-Path -LiteralPath (Join-Path $extensionDir 'php_pdo_mysql.dll'))) { throw 'BLOCKED_PDO_MYSQL_DLL_MISSING' }
                $extensionArgs += @('-d','extension=php_pdo_mysql.dll')
            }
            $phpLines = @(
                'require "vendor/autoload.php";',
                '$app = require "bootstrap/app.php";',
                '$app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();',
                '$pdo = \Illuminate\Support\Facades\DB::connection()->getPdo();',
                '$row = $pdo->query("SELECT DATABASE() AS db, @@port AS port, @@datadir AS datadir, VERSION() AS version, CURRENT_USER() AS current_account")->fetch(\PDO::FETCH_ASSOC);',
                '$tables = $pdo->query("SHOW TABLES")->fetchAll(\PDO::FETCH_COLUMN);',
                '$out = ["default"=>config("database.default"),"driver"=>$pdo->getAttribute(\PDO::ATTR_DRIVER_NAME),"host"=>config("database.connections.mariadb.host"),"port"=>(int)config("database.connections.mariadb.port"),"database"=>config("database.connections.mariadb.database"),"username"=>config("database.connections.mariadb.username"),"socket"=>config("database.connections.mariadb.unix_socket"),"actual_db"=>$row["db"],"actual_port"=>(int)$row["port"],"datadir"=>$row["datadir"],"current_user"=>$row["current_account"],"table_count"=>count($tables),"storage"=>$app->storagePath(),"config_cache"=>$app->getCachedConfigPath(),"routes_cache"=>$app->getCachedRoutesPath(),"events_cache"=>$app->getCachedEventsPath(),"packages_cache"=>$app->getCachedPackagesPath(),"services_cache"=>$app->getCachedServicesPath(),"ads"=>config("datasets.features.ads"),"cloud"=>config("datasets.features.cloud"),"paid_documents"=>config("datasets.features.paidDocuments"),"campaign_public"=>config("campaigns.public_catalog_enabled"),"account_email"=>config("app_accounts.transactional_email_enabled"),"marketing_send"=>config("app_accounts.marketing_send_enabled")];',
                'echo json_encode($out, JSON_THROW_ON_ERROR);'
            )
            $phpSource = $phpLines -join ' '
            Push-Location $serverRoot
            try {
                $preflightOutput = @(& $PhpPath @extensionArgs '-r' $phpSource 2>&1)
                $preflightExit = $LASTEXITCODE
            } finally { Pop-Location }
            if ($preflightExit -ne 0) { throw "BLOCKED_LARAVEL_PREFLIGHT_EXIT_$preflightExit" }
            $jsonLine = @($preflightOutput | ForEach-Object { $_.ToString() } | Where-Object { $_.Trim().StartsWith('{') } | Select-Object -Last 1)
            if ($jsonLine.Count -ne 1) { throw 'BLOCKED_LARAVEL_PREFLIGHT_OUTPUT' }
            $check = $jsonLine[0] | ConvertFrom-Json
            $expectedData = ([string]$meta.datadir).Replace('/','\').Replace('\\','\').TrimEnd('\')
            $actualData = ([string]$check.datadir).Replace('/','\').Replace('\\','\').TrimEnd('\')
            $expectedStorage = Join-Path $laravelRoot 'storage'
            $expectedCache = @((Join-Path $cacheRoot 'config.php'),(Join-Path $cacheRoot 'routes-v7.php'),(Join-Path $cacheRoot 'events.php'),(Join-Path $cacheRoot 'packages.php'),(Join-Path $cacheRoot 'services.php'))
            $actualCache = @($check.config_cache,$check.routes_cache,$check.events_cache,$check.packages_cache,$check.services_cache)
            $cacheMatch = $true
            for ($i=0;$i -lt $expectedCache.Count;$i++) { $actualPath=[IO.Path]::GetFullPath(([string]$actualCache[$i]).Replace('/','\')); $expectedPath=[IO.Path]::GetFullPath(([string]$expectedCache[$i]).Replace('/','\')); if (-not $actualPath.Equals($expectedPath,[StringComparison]::OrdinalIgnoreCase)) { $cacheMatch=$false } }
            if ($check.default -ne 'mariadb' -or $check.driver -ne 'mysql' -or $check.host -ne '127.0.0.1' -or [int]$check.port -ne [int]$meta.port -or $check.database -ne $meta.database -or $check.username -ne $meta.dbUser -or $check.socket -ne '' -or $check.actual_db -ne $meta.database -or [int]$check.actual_port -ne [int]$meta.port -or -not $actualData.Equals($expectedData,[StringComparison]::OrdinalIgnoreCase) -or $check.current_user -ne "$($meta.dbUser)@127.0.0.1" -or [int]$check.table_count -ne 0 -or -not ([string]$check.storage).Replace('/','\').Replace('\\','\').TrimEnd('\').Equals(([string]$expectedStorage).Replace('/','\').Replace('\\','\').TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase) -or -not $cacheMatch -or $check.ads -ne $false -or $check.cloud -ne $false -or $check.paid_documents -ne $false -or $check.campaign_public -ne $false -or $check.account_email -ne $false -or $check.marketing_send -ne $false) { throw 'BLOCKED_LARAVEL_TARGET_PREFLIGHT_MISMATCH' }
            [IO.File]::WriteAllText($attemptPath,([ordered]@{ startedUtc=[DateTime]::UtcNow.ToString('o'); database=$meta.database; port=$meta.port; datadir=$meta.datadir } | ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
            Push-Location $serverRoot
            try {
                $migrateOutput = @(& $PhpPath @extensionArgs artisan migrate --no-interaction --force 2>&1)
                $migrateExit = $LASTEXITCODE
            } finally { Pop-Location }
            [IO.File]::WriteAllText((Join-Path $instanceDir 'artisan-migrate.log'),(($migrateOutput | ForEach-Object { $_.ToString() }) -join "`n"),[Text.UTF8Encoding]::new($false))
            $migrationCount = 0
            if ($migrateExit -eq 0) {
                $countOutput = Invoke-MariaClient @("--defaults-file=$($meta.appOptions)",'--protocol=TCP','--batch','--skip-column-names','--execute=SELECT COUNT(*) FROM migrations;')
                $migrationCount = [int](($countOutput -join '').Trim())
            }
            [IO.File]::WriteAllText($resultPath,([ordered]@{ completedUtc=[DateTime]::UtcNow.ToString('o'); exitCode=$migrateExit; migrationCount=$migrationCount; database=$meta.database; port=$meta.port } | ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
            if ($migrateExit -ne 0) { throw "MARIADB_MIGRATE_EXIT_$migrateExit; no retry is permitted by this helper" }
            Write-Output "MARIADB_MIGRATE=PASS_SCOPED|EXIT=0|MIGRATIONS=$migrationCount|DATABASE=$($meta.database)|PORT=$($meta.port)"
        } finally {
            [Environment]::SetEnvironmentVariable('PATH',$oldPath,'Process')
            foreach ($name in $envNames) { [Environment]::SetEnvironmentVariable($name,$oldEnv[$name],'Process') }
        }
    }
    'Stop' {
        $meta = Get-Instance
        $status = Get-Status $meta
        if ($status.stopped) { Write-Output 'DB_STOP=ALREADY_STOPPED'; break }
        $stopArgs = @("--defaults-file=$($meta.rootOptions)",'--protocol=PIPE',"--socket=$($meta.pipeName)",'--batch','--skip-column-names','--execute=SHUTDOWN;')
        [void](Invoke-MariaClient $stopArgs)
        $deadline = (Get-Date).AddSeconds(20)
        do { $alive = Get-CimInstance Win32_Process -Filter "ProcessId=$($meta.pid)" -ErrorAction SilentlyContinue; if (-not $alive) { break }; Start-Sleep -Milliseconds 250 } while ((Get-Date) -lt $deadline)
        if (Get-CimInstance Win32_Process -Filter "ProcessId=$($meta.pid)" -ErrorAction SilentlyContinue) { throw 'BLOCKED_STOP_TIMEOUT' }
        if (Get-NetTCPConnection -State Listen -LocalPort ([int]$meta.port) -ErrorAction SilentlyContinue) { throw 'BLOCKED_PORT_STILL_OPEN' }
        Write-Output "DB_STOP=PASS_SCOPED|PID=$($meta.pid)|PORT_CLOSED=$($meta.port)"
    }
}
