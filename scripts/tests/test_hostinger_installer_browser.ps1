param(
    [string] $ArtifactDirectory = 'artifacts/current/hostinger-staging',
    [string] $EvidenceDirectory,
    [ValidateSet('happy', 'migration-failure', 'admin-content')]
    [string] $Scenario = 'happy',
    [string] $ZipPattern = 'PicoRadar-staging-hostinger-*.zip',
    [string] $MariaDbRoot = 'C:\codex\_tool-cache\mariadb-11.8.8-winx64',
    [string] $PhpPath = 'C:\xampphp\php\php.exe',
    [string] $OpenSslPath = 'C:\xampphp\apache\bin\openssl.exe',
    [string] $OpenSslConfig = 'C:\xampphp\apache\conf\openssl.cnf'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$artifacts = (Resolve-Path -LiteralPath (Join-Path $root $ArtifactDirectory)).Path
$zip = @(Get-ChildItem -LiteralPath $artifacts -Filter $ZipPattern -File)
if ($zip.Count -ne 1) { throw 'Exactly one Hostinger staging ZIP is required.' }
$tokenFile = Join-Path $artifacts 'PicoRadar-INSTALL_TOKEN.txt'
if (-not (Test-Path -LiteralPath $tokenFile -PathType Leaf)) { throw 'The private local token file is unavailable.' }

function Get-FreePort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try { return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port } finally { $listener.Stop() }
}

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('picoradar-hostinger-browser-' + [guid]::NewGuid().ToString('N'))
$domainRoot = Join-Path $scratch 'domain'
$publicRoot = Join-Path $domainRoot 'public_html/picoradar'
$dataRoot = Join-Path $scratch 'mariadb-data'
$logs = Join-Path $scratch 'logs'

function Remove-VerifiedTestScratch {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $leaf = [System.IO.Path]::GetFileName($resolved)
    if (-not $resolved.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $leaf.StartsWith('picoradar-hostinger-browser-', [System.StringComparison]::Ordinal)) {
        throw "Refusing to remove an unverified browser fixture path: $resolved"
    }

    $extendedPath = if ($resolved.StartsWith('\\?\')) { $resolved } else { '\\?\' + $resolved }
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        try {
            if (-not [System.IO.Directory]::Exists($extendedPath)) { return }
            [System.IO.Directory]::Delete($extendedPath, $true)
            return
        } catch {
            if ($attempt -eq 4) { throw }
            Start-Sleep -Milliseconds 250
        }
    }
}
$rootPassword = 'Root-Browser-Test-2026'
$database = 'picoradar_browser_qa'
$restoreDatabase = 'picoradar_browser_restore'
$dbUser = 'picoradar_browser'
$dbPassword = 'Browser_${APP_NAME}_#" Unicode-á-2026'
$operatorPassword = 'Browser-Operator-Test-2026'
$basicUser = 'local-staging'
$basicPassword = 'Local-Basic-Test-2026'
$dbPort = Get-FreePort
$backendPort = Get-FreePort
$httpsPort = Get-FreePort
$mariaProcess = $null
$phpProcess = $null
$proxyProcess = $null
$succeeded = $false

try {
    New-Item -ItemType Directory -Path $publicRoot, $dataRoot, $logs -Force | Out-Null
    [System.IO.File]::WriteAllText(
        (Join-Path $publicRoot '.htaccess'),
        "AuthType Basic`nAuthName `"Private staging`"`nRequire valid-user`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip[0].FullName, $domainRoot)

    $installer = Join-Path $MariaDbRoot 'bin/mariadb-install-db.exe'
    & $installer "--datadir=$dataRoot" "--password=$rootPassword" "--port=$dbPort" --silent
    if ($LASTEXITCODE -ne 0) { throw 'MariaDB initialization failed.' }
    $ini = Join-Path $scratch 'my.ini'
    $basedirIni = $MariaDbRoot.Replace('\', '/')
    $datadirIni = $dataRoot.Replace('\', '/')
    [System.IO.File]::WriteAllText($ini, "[mysqld]`nbasedir=$basedirIni`ndatadir=$datadirIni`nport=$dbPort`nbind-address=127.0.0.1`nskip-name-resolve`nskip-log-bin`nmax_connections=20`n", [System.Text.UTF8Encoding]::new($false))
    $mariaProcess = Start-Process -FilePath (Join-Path $MariaDbRoot 'bin/mysqld.exe') `
        -ArgumentList "--defaults-file=$ini", '--console' -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $logs 'mariadb.out.log') -RedirectStandardError (Join-Path $logs 'mariadb.err.log')
    $client = Join-Path $MariaDbRoot 'bin/mariadb.exe'
    $ready = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Milliseconds 250
        & $client --protocol=tcp --host=127.0.0.1 "--port=$dbPort" --user=root "--password=$rootPassword" --silent --skip-column-names --execute='SELECT 1' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        if ($mariaProcess.HasExited) { break }
    }
    if (-not $ready) { throw 'MariaDB did not start.' }
    $sql = "CREATE DATABASE ``$database`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE ``$restoreDatabase`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER '$dbUser'@'127.0.0.1' IDENTIFIED BY '$dbPassword'; GRANT ALL PRIVILEGES ON ``$database``.* TO '$dbUser'@'127.0.0.1'; GRANT ALL PRIVILEGES ON ``$restoreDatabase``.* TO '$dbUser'@'127.0.0.1'; FLUSH PRIVILEGES;"
    $provisionSqlPath = Join-Path $scratch 'provision.sql'
    [System.IO.File]::WriteAllText($provisionSqlPath, $sql, [System.Text.UTF8Encoding]::new($false))
    $provisionSqlUnix = $provisionSqlPath.Replace('\', '/')
    & $client --protocol=tcp --host=127.0.0.1 "--port=$dbPort" --user=root "--password=$rootPassword" "--execute=source $provisionSqlUnix"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable browser database provisioning failed.' }

    $cert = Join-Path $scratch 'localhost.crt'
    $key = Join-Path $scratch 'localhost.key'
    $opensslProcess = Start-Process -FilePath $OpenSslPath `
        -ArgumentList 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', $key, '-out', $cert, '-subj', '/CN=127.0.0.1', '-days', '1', '-config', $OpenSslConfig `
        -WindowStyle Hidden -PassThru -Wait `
        -RedirectStandardOutput (Join-Path $logs 'openssl.out.log') `
        -RedirectStandardError (Join-Path $logs 'openssl.err.log')
    if ($opensslProcess.ExitCode -ne 0) { throw 'Local HTTPS certificate generation failed.' }

    $env:PICORADAR_TEST_PUBLIC_ROOT = $publicRoot
    $env:PICORADAR_TEST_PRIVATE_PUBLIC_ROOT = Join-Path $domainRoot 'picoradar_app/current/storage/app/public'
    $phpInfo = [System.Diagnostics.ProcessStartInfo]::new($PhpPath)
    $phpInfo.WorkingDirectory = $publicRoot
    $phpInfo.UseShellExecute = $false
    $phpInfo.CreateNoWindow = $true
    $phpInfo.RedirectStandardOutput = $true
    $phpInfo.RedirectStandardError = $true
    $phpInfo.Environment['APP_URL'] = "https://127.0.0.1:$httpsPort"
    $phpInfo.Environment['DATASET_PUBLIC_BASE_URL'] = "https://127.0.0.1:$httpsPort/storage"
    $phpInfo.Environment['CAMPAIGN_PUBLIC_BASE_URL'] = "https://127.0.0.1:$httpsPort/storage"
    $phpInfo.Arguments = (@('-S', "127.0.0.1:$backendPort", '-t', $publicRoot, (Join-Path $root 'scripts/tests/php_https_router.php')) |
        ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
    $phpProcess = [System.Diagnostics.Process]::Start($phpInfo)
    $phpProcess.BeginOutputReadLine()
    $phpProcess.BeginErrorReadLine()

    $env:PICORADAR_TEST_BASIC_USER = $basicUser
    $env:PICORADAR_TEST_BASIC_PASSWORD = $basicPassword
    $proxyInfo = [System.Diagnostics.ProcessStartInfo]::new('node')
    $proxyInfo.WorkingDirectory = $root
    $proxyInfo.UseShellExecute = $false
    $proxyInfo.CreateNoWindow = $true
    $proxyInfo.RedirectStandardOutput = $true
    $proxyInfo.RedirectStandardError = $true
    $proxyInfo.Arguments = (@((Join-Path $root 'scripts/tests/https_basic_proxy.js'), "$httpsPort", "$backendPort", $cert, $key) |
        ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
    $proxyProcess = [System.Diagnostics.Process]::Start($proxyInfo)
    $proxyProcess.BeginOutputReadLine()
    $proxyProcess.BeginErrorReadLine()
    $proxyReady = $false
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        Start-Sleep -Milliseconds 200
        try {
            $statusCode = (& curl.exe -k -s -o NUL -w '%{http_code}' "https://127.0.0.1:$httpsPort/").Trim()
            if ($statusCode -eq '401') { $proxyReady = $true; break }
        } catch {}
        if ($proxyProcess.HasExited -or $phpProcess.HasExited) { break }
    }
    if (-not $proxyReady) { throw 'Local HTTPS/private barrier did not start.' }

    $playwrightRoot = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'npm-cache/_npx') -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $package = Join-Path $_.FullName 'node_modules/playwright/package.json'
            (Test-Path -LiteralPath $package -PathType Leaf) -and (Get-Item -LiteralPath $package).Length -gt 20
        } |
        Select-Object -First 1
    if ($null -eq $playwrightRoot) { throw 'A local Playwright runtime is unavailable.' }
    $env:NODE_PATH = Join-Path $playwrightRoot.FullName 'node_modules'
    $chromium = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'ms-playwright/chromium-*') -Filter chrome.exe -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($null -eq $chromium) { throw 'A local Chromium executable is unavailable.' }
    $env:PICORADAR_TEST_CHROMIUM = $chromium.FullName
    $env:PICORADAR_TEST_DB_PORT = "$dbPort"
    $env:PICORADAR_TEST_DB_NAME = $database
    $env:PICORADAR_TEST_DB_USER = $dbUser
    $env:PICORADAR_TEST_DB_PASSWORD = $dbPassword
    $env:PICORADAR_TEST_OPERATOR_PASSWORD = $operatorPassword
    $env:PICORADAR_TEST_SCENARIO = $Scenario
    $env:PICORADAR_TEST_PRIVATE_ROOT = (Join-Path $domainRoot 'picoradar_app/current')
    $env:PICORADAR_TEST_STATE_PATH = (Join-Path $domainRoot 'picoradar_app/current/storage/app/installer/installation-state.json')
    $env:PICORADAR_TEST_MUTATION_LOCK_PATH = (Join-Path $domainRoot 'picoradar_app/current/storage/app/installer/mutation.lock')
    $env:PICORADAR_TEST_HOLD_LOCK_SCRIPT = (Join-Path $root 'scripts/tests/hold_file_lock.php')
    $env:PICORADAR_TEST_PHP = $PhpPath
    if ($Scenario -eq 'admin-content') {
        $fixtureRoot = Join-Path $scratch 'admin-content-fixtures'
        & $PhpPath (Join-Path $root 'scripts/tests/create_admin_content_browser_fixtures.php') $fixtureRoot | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Admin-content browser fixtures could not be generated.' }
        $env:PICORADAR_TEST_RULES_JSON = Join-Path $fixtureRoot 'b07-rules.json'
        $env:PICORADAR_TEST_RULES_CSV = Join-Path $fixtureRoot 'b07-rules.csv'
        $env:PICORADAR_TEST_RULES_XLSX = Join-Path $fixtureRoot 'b07-rules.xlsx'
        $env:PICORADAR_TEST_CAMPAIGN_IMAGE = Join-Path $root 'mobile/assets/home/partners/campaign_automotor.png'
    }
    if ($EvidenceDirectory) {
        $env:PICORADAR_BROWSER_EVIDENCE_DIR = [System.IO.Path]::GetFullPath($EvidenceDirectory)
    }
    & node (Join-Path $root 'scripts/tests/hostinger_installer_browser_test.js') "https://127.0.0.1:$httpsPort" $tokenFile
    if ($LASTEXITCODE -ne 0) { throw 'Browser-driven installer verification failed.' }
    if ($Scenario -eq 'admin-content') {
        $env:PICORADAR_B07_BASE_URL = "https://127.0.0.1:$httpsPort"
        Push-Location (Join-Path $root 'mobile')
        try {
            & 'C:\Users\felip\.codex\tooling\flutter_3.47.1\flutter\bin\flutter.bat' test test/integration/admin_content_publication_bridge_test.dart
            if ($LASTEXITCODE -ne 0) { throw 'The real Flutter publication bridge failed.' }
        } finally {
            Pop-Location
        }

        $expectedCounts = '1|1|1|1|1'
        $contentCountsSql = "SELECT CONCAT((SELECT COUNT(*) FROM restriction_rule_versions),'|',(SELECT COUNT(*) FROM restriction_publications),'|',(SELECT COUNT(*) FROM sponsors),'|',(SELECT COUNT(*) FROM campaigns),'|',(SELECT COUNT(*) FROM campaign_catalog_releases));"
        $contentCounts = (& $client --protocol=tcp --host=127.0.0.1 "--port=$dbPort" --user=root "--password=$rootPassword" "--database=$database" --silent --skip-column-names --execute=$contentCountsSql).Trim()
        if ($contentCounts -ne $expectedCounts) {
            throw "The browser flow did not persist the expected administrative content: $contentCounts"
        }

        $backupRoot = Join-Path $scratch 'admin-content-backup'
        $restoredPublic = Join-Path $scratch 'admin-content-restored-public'
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        $privatePublic = Join-Path $domainRoot 'picoradar_app/current/storage/app/public'
        Copy-Item -LiteralPath $privatePublic -Destination (Join-Path $backupRoot 'public') -Recurse -Force
        $dumpPath = Join-Path $backupRoot 'database.sql'
        $dump = Join-Path $MariaDbRoot 'bin/mariadb-dump.exe'
        & $dump --protocol=tcp --host=127.0.0.1 "--port=$dbPort" --user=root "--password=$rootPassword" --single-transaction --skip-comments "--result-file=$dumpPath" $database
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $dumpPath)) {
            throw 'Administrative content database backup failed.'
        }
        $dumpUnix = $dumpPath.Replace('\', '/')
        & $client --protocol=tcp --host=127.0.0.1 "--port=$dbPort" --user=root "--password=$rootPassword" "--database=$restoreDatabase" "--execute=source $dumpUnix"
        if ($LASTEXITCODE -ne 0) { throw 'Administrative content database restore failed.' }
        $restoredCounts = (& $client --protocol=tcp --host=127.0.0.1 "--port=$dbPort" --user=root "--password=$rootPassword" "--database=$restoreDatabase" --silent --skip-column-names --execute=$contentCountsSql).Trim()
        if ($restoredCounts -ne $contentCounts) {
            throw "Administrative content changed during database restore: $restoredCounts"
        }
        Copy-Item -LiteralPath (Join-Path $backupRoot 'public') -Destination $restoredPublic -Recurse -Force
        foreach ($relativePath in @('manifest/v1/manifest.json', 'campaigns/v1/catalog.json')) {
            $sourceFile = Join-Path $privatePublic $relativePath
            $restoredFile = Join-Path $restoredPublic $relativePath
            if (-not (Test-Path -LiteralPath $sourceFile) -or -not (Test-Path -LiteralPath $restoredFile)) {
                throw "Published pointer missing from content backup: $relativePath"
            }
            if ((Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $restoredFile -Algorithm SHA256).Hash) {
                throw "Published pointer changed during storage restore: $relativePath"
            }
        }
        $campaignAsset = Get-ChildItem -LiteralPath (Join-Path $privatePublic 'campaigns/assets') -File | Select-Object -First 1
        if ($null -eq $campaignAsset) { throw 'The published campaign asset is missing from private storage.' }
        $restoredAsset = Join-Path (Join-Path $restoredPublic 'campaigns/assets') $campaignAsset.Name
        if ((Get-FileHash -LiteralPath $campaignAsset.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $restoredAsset -Algorithm SHA256).Hash) {
            throw 'The campaign image changed during storage restore.'
        }
    }

    $htaccess = Get-Content -LiteralPath (Join-Path $publicRoot '.htaccess') -Raw
    if ($htaccess -notmatch 'AuthType Basic') { throw 'The synthetic private barrier was not preserved.' }
    if ($Scenario -eq 'happy' -and $htaccess -notmatch '# BEGIN PICORADAR ROUTING') {
        throw 'Final routing was not installed after the successful scenario.'
    }
    Write-Output "PASS: final ZIP completed browser scenario '$Scenario' behind HTTPS and Basic Auth."
    $succeeded = $true
} finally {
    foreach ($process in @($proxyProcess, $phpProcess, $mariaProcess)) {
        if ($process -and -not $process.HasExited) {
            $process.Kill()
            $process.WaitForExit(5000) | Out-Null
        }
    }
    foreach ($name in @(
        'PICORADAR_TEST_PUBLIC_ROOT', 'PICORADAR_TEST_PRIVATE_PUBLIC_ROOT', 'PICORADAR_TEST_BASIC_USER', 'PICORADAR_TEST_BASIC_PASSWORD',
        'PICORADAR_TEST_DB_PORT', 'PICORADAR_TEST_DB_NAME', 'PICORADAR_TEST_DB_USER',
        'PICORADAR_TEST_DB_PASSWORD', 'PICORADAR_TEST_OPERATOR_PASSWORD', 'PICORADAR_TEST_CHROMIUM', 'NODE_PATH'
        , 'PICORADAR_BROWSER_EVIDENCE_DIR', 'PICORADAR_TEST_SCENARIO', 'PICORADAR_TEST_PRIVATE_ROOT'
        , 'PICORADAR_TEST_STATE_PATH', 'PICORADAR_TEST_MUTATION_LOCK_PATH', 'PICORADAR_TEST_HOLD_LOCK_SCRIPT'
        , 'PICORADAR_TEST_PHP'
        , 'PICORADAR_TEST_RULES_JSON', 'PICORADAR_TEST_RULES_CSV', 'PICORADAR_TEST_RULES_XLSX'
        , 'PICORADAR_TEST_CAMPAIGN_IMAGE', 'PICORADAR_B07_BASE_URL'
    )) { Remove-Item "Env:$name" -ErrorAction SilentlyContinue }
    if ($succeeded -and (Test-Path -LiteralPath $scratch)) {
        Remove-VerifiedTestScratch -Path $scratch
    } elseif (Test-Path -LiteralPath $scratch) {
        Write-Warning "Browser fixture preserved for diagnosis: $scratch"
    }
}
