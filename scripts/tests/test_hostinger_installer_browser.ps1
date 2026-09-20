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

function Start-StructuredProcess([string] $FilePath, [string[]] $Arguments, [string] $WorkingDirectory, [string] $Stdout, [string] $Stderr) {
    $info = [System.Diagnostics.ProcessStartInfo]::new($FilePath)
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::Start($info)
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    return $process
}

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('picoradar-hostinger-browser-' + [guid]::NewGuid().ToString('N'))
$domainRoot = Join-Path $scratch 'domain'
$publicRoot = Join-Path $domainRoot 'public_html/picoradar'
$dataRoot = Join-Path $scratch 'mariadb-data'
$logs = Join-Path $scratch 'logs'
$rootPassword = 'Root-Browser-Test-2026'
$database = 'picoradar_browser_qa'
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
    $sql = "CREATE DATABASE ``$database`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER '$dbUser'@'127.0.0.1' IDENTIFIED BY '$dbPassword'; GRANT ALL PRIVILEGES ON ``$database``.* TO '$dbUser'@'127.0.0.1'; FLUSH PRIVILEGES;"
    & $client --protocol=tcp --host=127.0.0.1 "--port=$dbPort" --user=root "--password=$rootPassword" --execute=$sql
    if ($LASTEXITCODE -ne 0) { throw 'Disposable browser database provisioning failed.' }

    $cert = Join-Path $scratch 'localhost.crt'
    $key = Join-Path $scratch 'localhost.key'
    & $OpenSslPath req -x509 -newkey rsa:2048 -nodes -keyout $key -out $cert -subj '/CN=127.0.0.1' -days 1 -config $OpenSslConfig 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Local HTTPS certificate generation failed.' }

    $env:PICORADAR_TEST_PUBLIC_ROOT = $publicRoot
    $phpInfo = [System.Diagnostics.ProcessStartInfo]::new($PhpPath)
    $phpInfo.WorkingDirectory = $publicRoot
    $phpInfo.UseShellExecute = $false
    $phpInfo.CreateNoWindow = $true
    $phpInfo.RedirectStandardOutput = $true
    $phpInfo.RedirectStandardError = $true
    $phpInfo.Environment['APP_URL'] = "https://127.0.0.1:$httpsPort"
    $phpInfo.Environment['DATASET_PUBLIC_BASE_URL'] = "https://127.0.0.1:$httpsPort/storage"
    $phpInfo.Environment['CAMPAIGN_PUBLIC_BASE_URL'] = "https://127.0.0.1:$httpsPort/storage"
    foreach ($argument in @('-S', "127.0.0.1:$backendPort", '-t', $publicRoot, (Join-Path $root 'scripts/tests/php_https_router.php'))) { $phpInfo.ArgumentList.Add($argument) }
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
    foreach ($argument in @((Join-Path $root 'scripts/tests/https_basic_proxy.js'), "$httpsPort", "$backendPort", $cert, $key)) { $proxyInfo.ArgumentList.Add($argument) }
    $proxyProcess = [System.Diagnostics.Process]::Start($proxyInfo)
    $proxyProcess.BeginOutputReadLine()
    $proxyProcess.BeginErrorReadLine()
    $proxyReady = $false
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        Start-Sleep -Milliseconds 200
        try {
            $response = Invoke-WebRequest -Uri "https://127.0.0.1:$httpsPort/" -SkipCertificateCheck -UseBasicParsing -TimeoutSec 2 -SkipHttpErrorCheck
            if ($response.StatusCode -eq 401) { $proxyReady = $true; break }
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
            $process.Kill($true)
            $process.WaitForExit(5000) | Out-Null
        }
    }
    foreach ($name in @(
        'PICORADAR_TEST_PUBLIC_ROOT', 'PICORADAR_TEST_BASIC_USER', 'PICORADAR_TEST_BASIC_PASSWORD',
        'PICORADAR_TEST_DB_PORT', 'PICORADAR_TEST_DB_NAME', 'PICORADAR_TEST_DB_USER',
        'PICORADAR_TEST_DB_PASSWORD', 'PICORADAR_TEST_OPERATOR_PASSWORD', 'PICORADAR_TEST_CHROMIUM', 'NODE_PATH'
        , 'PICORADAR_BROWSER_EVIDENCE_DIR', 'PICORADAR_TEST_SCENARIO', 'PICORADAR_TEST_PRIVATE_ROOT'
        , 'PICORADAR_TEST_STATE_PATH', 'PICORADAR_TEST_MUTATION_LOCK_PATH', 'PICORADAR_TEST_HOLD_LOCK_SCRIPT'
        , 'PICORADAR_TEST_PHP'
        , 'PICORADAR_TEST_RULES_JSON', 'PICORADAR_TEST_RULES_CSV', 'PICORADAR_TEST_RULES_XLSX'
        , 'PICORADAR_TEST_CAMPAIGN_IMAGE', 'PICORADAR_B07_BASE_URL'
    )) { Remove-Item "Env:$name" -ErrorAction SilentlyContinue }
    if ($succeeded -and (Test-Path -LiteralPath $scratch)) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    } elseif (Test-Path -LiteralPath $scratch) {
        Write-Warning "Browser fixture preserved for diagnosis: $scratch"
    }
}
