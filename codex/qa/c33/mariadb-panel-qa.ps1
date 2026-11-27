[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Prepare','Start','Status','Smoke','Stop')][string]$Action,
    [Parameter(Mandatory)][string]$PrivateRoot,
    [Parameter(Mandatory)][string]$MariaDbRoot,
    [string]$SourcePrivateRoot='D:\codex\_build\PicoRadar-C32-V2\db-candidate\private',
    [string]$PhpPath='C:\xampphp\php\php.exe',
    [int]$Port=8893
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$privatePath=[IO.Path]::GetFullPath($PrivateRoot)
$sourcePath=[IO.Path]::GetFullPath($SourcePrivateRoot)
$mariaPath=[IO.Path]::GetFullPath($MariaDbRoot)
$phpExe=[IO.Path]::GetFullPath($PhpPath)
$expectedPrivate='D:\codex\_build\PicoRadar-C33-V2\private\B'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$serverRoot=Join-Path $repoRoot 'server'
$routerPath=Join-Path $repoRoot 'codex\qa\c33\local-panel-router.php'
$bootstrapPath=Join-Path $repoRoot 'codex\qa\c33\panel-bootstrap.php'
$phpDir=Split-Path -Parent $phpExe
$clientExe=Join-Path $mariaPath 'bin\mariadb.exe'
$dbHelper=Join-Path $repoRoot 'codex\qa\c32\mariadb-qa.ps1'
$panelRoot=Join-Path $privatePath 'panel'
$runtimeRoot=Join-Path $privatePath 'laravel'
$markerPath=Join-Path $panelRoot 'panel-instance.json'
$ledgerPath=Join-Path $panelRoot 'panel-ledger.jsonl'
$credentialPath=Join-Path $panelRoot 'synthetic-admin.json'
$appKeyPath=Join-Path $panelRoot 'app-key.txt'

function Write-Ledger([string]$Name,[string]$State,[double]$ElapsedMs=0) {
    $entry=[ordered]@{step=$Name;state=$State;utc=[DateTime]::UtcNow.ToString('o');elapsedMs=[Math]::Round($ElapsedMs,1)}
    [IO.File]::AppendAllText($ledgerPath,(($entry|ConvertTo-Json -Compress)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
}
function Assert-PrivateRoot {
    if($privatePath -ine $expectedPrivate){throw 'BLOCKED_PRIVATE_ROOT_IDENTITY'}
    if(-not(Test-Path -LiteralPath $privatePath -PathType Container)){throw 'BLOCKED_PRIVATE_ROOT_MISSING'}
    $root=Get-Item -LiteralPath $privatePath -Force
    if(($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'BLOCKED_PRIVATE_ROOT_REPARSE'}
    $acl=Get-Acl -LiteralPath $privatePath
    if(-not $acl.AreAccessRulesProtected){throw 'BLOCKED_PRIVATE_ROOT_INHERITS_ACL'}
    $allowed=@([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18','S-1-5-32-544')
    $actual=@($acl.Access|ForEach-Object{$_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value}|Sort-Object -Unique)
    if(@($actual|Where-Object{$_ -notin $allowed}).Count -gt 0 -or @($allowed|Where-Object{$_ -notin $actual}).Count -gt 0){throw 'BLOCKED_PRIVATE_ROOT_ACL'}
}
function Assert-NoReparse([string]$Path) {
    if(-not(Test-Path -LiteralPath $Path)){throw 'BLOCKED_REQUIRED_PATH_MISSING'}
    $item=Get-Item -LiteralPath $Path -Force
    if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'BLOCKED_REPARSE_PATH'}
}
function Get-Meta([string]$Root) {
    $p=Join-Path $Root 'mariadb\qa-instance.json'
    if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw 'BLOCKED_DB_MARKER_MISSING'}
    $m=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json
    if($m.schemaVersion -ne 1 -or [IO.Path]::GetFullPath([string]$m.privateRoot) -ine [IO.Path]::GetFullPath($Root)){throw 'BLOCKED_DB_MARKER_IDENTITY'}
    if([string]$m.serverExe -ine (Join-Path $mariaPath 'bin\mariadbd.exe') -or [string]$m.version -notlike '11.8.8*'){throw 'BLOCKED_DB_BINARY_VERSION'}
    return $m
}
function Invoke-DbQuery($Meta,[string]$Sql) {
    $queryArgs=@("--defaults-file=$($Meta.appOptions)",'--protocol=TCP','--connect-timeout=5','--batch','--raw','--skip-column-names',"--execute=$Sql")
    $rows=@(& $clientExe @queryArgs 2>&1)
    $exit=$LASTEXITCODE
    if($exit -ne 0){throw 'BLOCKED_DB_READ_QUERY'}
    return (($rows -join [Environment]::NewLine).Trim())
}
function Assert-DbRunning($Meta,[string]$Root) {
    $status=@(& $dbHelper -Action Status -PrivateRoot $Root -MariaDbRoot $mariaPath 2>&1)
    if(($status -join [Environment]::NewLine) -notmatch 'DB_STATUS=RUNNING\|VERSION=11\.8\.8-MariaDB'){throw 'BLOCKED_DB_HELPER_STATUS'}
    $row=Invoke-DbQuery $Meta 'SELECT DATABASE(),@@port,@@datadir,CURRENT_USER();'
    $f=$row -split ([string][char]9)
    if($f.Count -ne 4 -or $f[0] -ne [string]$Meta.database -or [int]$f[1] -ne [int]$Meta.port){throw 'BLOCKED_DB_IDENTITY_QUERY'}
    $actual=([string]$f[2]).Replace('/','\').Replace('\\','\').TrimEnd('\')
    $expected=([string]$Meta.datadir).Replace('/','\').Replace('\\','\').TrimEnd('\')
    if(-not $actual.Equals($expected,[StringComparison]::OrdinalIgnoreCase)){throw 'BLOCKED_DB_DATADIR_QUERY'}
    if($f[3] -ne "$($Meta.dbUser)@127.0.0.1"){throw 'BLOCKED_DB_ACCOUNT_QUERY'}
    return $f
}
function Get-ClientPassword($Meta) {
    $line=Get-Content -LiteralPath ([string]$Meta.appOptions)|Where-Object{$_ -match '^password='}|Select-Object -First 1
    if(-not $line){throw 'BLOCKED_DB_CREDENTIAL_FILE'}
    return $line.Substring(9)
}
function Get-AssetHashes {
    $manifestPath=Join-Path $privatePath 'public\build\manifest.json'
    foreach($dir in @((Join-Path $privatePath 'public'),(Join-Path $privatePath 'public\build'),(Join-Path $privatePath 'public\build\assets'))){Assert-NoReparse $dir}
    Assert-NoReparse $manifestPath
    $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
    $entries=@{
        '/build/assets/app-DZ9YpV5z.css'='2D1359FE85DA969DFD8AED6570B9198B883D6699D27FB09E931031D989413E86'
        '/build/assets/app-DMsN-rLE.js'='F0D3557302F9EBA56ACF6EE08EB53F2D49C2A8CF994A70708A2BCD8AB22676CF'
    }
    if($manifest.'resources/css/app.css'.file -ne 'assets/app-DZ9YpV5z.css' -or $manifest.'resources/js/app.js'.file -ne 'assets/app-DMsN-rLE.js'){throw 'BLOCKED_VITE_MANIFEST_IDENTITY'}
    foreach($url in $entries.Keys){
        $disk=Join-Path $privatePath ('public'+$url.Replace('/','\'))
        Assert-NoReparse $disk
        if((Get-FileHash -LiteralPath $disk -Algorithm SHA256).Hash -ne $entries[$url]){throw 'BLOCKED_VITE_ASSET_HASH'}
    }
    return $entries
}
function Get-EnvironmentNames {
    $names=@(Get-ChildItem Env:|Where-Object{$_.Name -match '^(APP_|DB_|MAIL_|REDIS_|SESSION_|CACHE_|QUEUE_|FILESYSTEM_|DATASET_|CAMPAIGN_|PICORADAR_|AWS_|S3_|STRIPE_|GOOGLE_|SENDGRID_|POSTMARK_|RESEND_|TWILIO_|MAILGUN_|CLOUD_)|^(DATABASE_URL|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY|MYSQL_HOME|MARIADB_HOME)$'}|Select-Object -ExpandProperty Name)
    $names+=@('APP_ENV','APP_DEBUG','APP_KEY','APP_NAME','APP_URL','APP_CONFIG_CACHE','APP_ROUTES_CACHE','APP_EVENTS_CACHE','APP_PACKAGES_CACHE','APP_SERVICES_CACHE','VIEW_COMPILED_PATH','LARAVEL_STORAGE_PATH','PICORADAR_PUBLIC_PATH','PICORADAR_QA_SERVER_ROOT','PICORADAR_QA_PRIVATE_ROOT','PICORADAR_QA_EXPECT_DB','PICORADAR_QA_EXPECT_PORT','PICORADAR_QA_EXPECT_DATADIR','PICORADAR_QA_EXPECT_USER','PICORADAR_QA_CREDENTIAL_FILE','DB_CONNECTION','DB_URL','DATABASE_URL','DB_HOST','DB_PORT','DB_DATABASE','DB_USERNAME','DB_PASSWORD','DB_SOCKET','SESSION_DRIVER','CACHE_STORE','QUEUE_CONNECTION','MAIL_MAILER','LOG_CHANNEL','LOG_LEVEL','FILESYSTEM_DISK','DATASET_DRAFT_DISK','DATASET_PUBLISHED_DISK','DATASET_PUBLIC_BASE_URL','CAMPAIGN_PUBLIC_CATALOG_ENABLED','CAMPAIGN_PUBLIC_BASE_URL','PICORADAR_ACCOUNTS_ENABLED','PICORADAR_ACCOUNT_EMAIL_ENABLED','PICORADAR_MARKETING_SEND_ENABLED','PICORADAR_SPONSORED_CAMPAIGNS_ENABLED','MYSQL_HOME','MARIADB_HOME')
    return @($names|Sort-Object -Unique)
}
function Enter-AppEnvironment($Meta,[string]$Key,[string]$DbPassword) {
    $names=Get-EnvironmentNames
    $old=@{}
    foreach($name in $names){$old[$name]=[Environment]::GetEnvironmentVariable($name,'Process');[Environment]::SetEnvironmentVariable($name,$null,'Process')}
    $oldPath=[Environment]::GetEnvironmentVariable('PATH','Process')
    $storage=Join-Path $runtimeRoot 'storage'
    $views=Join-Path $storage 'framework\views'
    $relativeCache=[IO.Path]::GetRelativePath($serverRoot,(Join-Path $runtimeRoot 'bootstrap\cache')).Replace('\','/')
    $values=@{
        APP_ENV='local';APP_DEBUG='false';APP_KEY=$Key;APP_NAME='PicoRadar C33 Local QA';APP_URL="http://127.0.0.1:$Port"
        APP_CONFIG_CACHE="$relativeCache/config.php";APP_ROUTES_CACHE="$relativeCache/routes-v7.php";APP_EVENTS_CACHE="$relativeCache/events.php";APP_PACKAGES_CACHE="$relativeCache/packages.php";APP_SERVICES_CACHE="$relativeCache/services.php"
        VIEW_COMPILED_PATH=$views;LARAVEL_STORAGE_PATH=$storage;PICORADAR_PUBLIC_PATH=(Join-Path $privatePath 'public');PICORADAR_QA_SERVER_ROOT=$serverRoot;PICORADAR_QA_PRIVATE_ROOT=$privatePath
        PICORADAR_QA_EXPECT_DB=[string]$Meta.database;PICORADAR_QA_EXPECT_PORT=[string]$Meta.port;PICORADAR_QA_EXPECT_DATADIR=[string]$Meta.datadir;PICORADAR_QA_EXPECT_USER="$($Meta.dbUser)@127.0.0.1";PICORADAR_QA_CREDENTIAL_FILE=$credentialPath
        DB_CONNECTION='mariadb';DB_URL='';DATABASE_URL='';DB_HOST='127.0.0.1';DB_PORT=[string]$Meta.port;DB_DATABASE=[string]$Meta.database;DB_USERNAME=[string]$Meta.dbUser;DB_PASSWORD=$DbPassword;DB_SOCKET='';HTTP_PROXY='';HTTPS_PROXY='';ALL_PROXY='';NO_PROXY='127.0.0.1,localhost,::1'
        SESSION_DRIVER='file';CACHE_STORE='file';QUEUE_CONNECTION='sync';MAIL_MAILER='array';LOG_CHANNEL='single';LOG_LEVEL='warning'
        FILESYSTEM_DISK='local';DATASET_DRAFT_DISK='local';DATASET_PUBLISHED_DISK='public';DATASET_PUBLIC_BASE_URL=''
        CAMPAIGN_PUBLIC_CATALOG_ENABLED='false';CAMPAIGN_PUBLIC_BASE_URL='';PICORADAR_ACCOUNTS_ENABLED='false';PICORADAR_ACCOUNT_EMAIL_ENABLED='false';PICORADAR_MARKETING_SEND_ENABLED='false';PICORADAR_SPONSORED_CAMPAIGNS_ENABLED='false'
    }
    foreach($name in $values.Keys){[Environment]::SetEnvironmentVariable($name,[string]$values[$name],'Process')}
    [Environment]::SetEnvironmentVariable('PATH',"$phpDir;$phpDir\ext;$oldPath",'Process')
    return [pscustomobject]@{names=$names;old=$old;oldPath=$oldPath}
}
function Exit-AppEnvironment($Snapshot) {
    foreach($name in $Snapshot.names){[Environment]::SetEnvironmentVariable($name,$Snapshot.old[$name],'Process')}
    [Environment]::SetEnvironmentVariable('PATH',$Snapshot.oldPath,'Process')
}
function Ensure-RuntimeDirectories {
    $paths=@((Join-Path $runtimeRoot 'bootstrap\cache'),(Join-Path $runtimeRoot 'storage\framework\views'),(Join-Path $runtimeRoot 'storage\framework\cache\data'),(Join-Path $runtimeRoot 'storage\framework\sessions'),(Join-Path $runtimeRoot 'storage\logs'),(Join-Path $runtimeRoot 'storage\app\private'),(Join-Path $runtimeRoot 'storage\app\public'))
    foreach($p in $paths){New-Item -ItemType Directory -Path $p -Force|Out-Null;Assert-NoReparse $p}
    $rootFull=[IO.Path]::GetFullPath($privatePath).TrimEnd('\')+'\'
    foreach($p in $paths){$full=[IO.Path]::GetFullPath($p);if(-not $full.StartsWith($rootFull,[StringComparison]::OrdinalIgnoreCase)){throw 'BLOCKED_RUNTIME_PATH_ESCAPE'}}
}
function Invoke-PhpBootstrap([string]$Mode) {
    $runId=[Guid]::NewGuid().ToString('N')
    $stdout=Join-Path $panelRoot "bootstrap-$runId.stdout.log"
    $stderr=Join-Path $panelRoot "bootstrap-$runId.stderr.log"
    $args=@('-d',"extension_dir=$phpDir\ext",'-f',$bootstrapPath,'--',$Mode)
    $proc=Start-Process -FilePath $phpExe -ArgumentList $args -WorkingDirectory $serverRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Wait-Process -Id $proc.Id -Timeout 45 -ErrorAction SilentlyContinue | Out-Null
    $info=Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction SilentlyContinue
    if($info){
        if([string]$info.ExecutablePath -ieq $phpExe -and $info.CommandLine -like "*$bootstrapPath*"){Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue}
        $stopWatch=[Diagnostics.Stopwatch]::StartNew()
        do {Start-Sleep -Milliseconds 100;$info=Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction SilentlyContinue} while($info -and $stopWatch.Elapsed.TotalSeconds -lt 5)
        if($info){throw 'BLOCKED_LARAVEL_PREFLIGHT_PROCESS_REMAINS'}
        throw 'BLOCKED_LARAVEL_PREFLIGHT_TIMEOUT'
    }
    $proc.Refresh()
    if(-not $proc.WaitForExit(0)){throw 'BLOCKED_LARAVEL_PREFLIGHT_PROCESS_REMAINS'}
    $nativeExit=$proc.ExitCode
    if($nativeExit -ne 0){throw "BLOCKED_LARAVEL_PREFLIGHT_EXIT_$nativeExit"}
    $line=Get-Content -LiteralPath $stdout -Raw
    if(-not $line.Trim().StartsWith('{')){throw 'BLOCKED_LARAVEL_PREFLIGHT_OUTPUT'}
    return ($line|ConvertFrom-Json)
}
function Get-PanelMeta {
    if(-not(Test-Path -LiteralPath $markerPath -PathType Leaf)){throw 'BLOCKED_PANEL_MARKER_MISSING'}
    $m=Get-Content -LiteralPath $markerPath -Raw|ConvertFrom-Json
    if($m.schemaVersion -ne 1 -or [IO.Path]::GetFullPath([string]$m.privateRoot) -ine $privatePath -or [IO.Path]::GetFullPath([string]$m.serverRoot) -ine $serverRoot -or [IO.Path]::GetFullPath([string]$m.router) -ine $routerPath){throw 'BLOCKED_PANEL_MARKER_IDENTITY'}
    return $m
}
function Get-VerifiedPanelProcess($Meta) {
    if($Meta.state -ne 'RUNNING'){return $null}
    $p=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$Meta.pid)" -ErrorAction SilentlyContinue
    if(-not $p){return $null}
    if([string]$p.ExecutablePath -ine $phpExe -or $p.CommandLine -notlike "*-S 127.0.0.1:$($Meta.port)*" -or $p.CommandLine -notlike "*$routerPath*" -or $p.CommandLine -notlike "*$($Meta.publicRoot)*"){throw 'BLOCKED_PANEL_PROCESS_IDENTITY'}
    $proc=Get-Process -Id ([int]$Meta.pid) -ErrorAction Stop
    $actualStartUtc=$proc.StartTime.ToUniversalTime()
    $expectedStartUtc=([DateTime]$Meta.processStartUtc).ToUniversalTime()
    if($actualStartUtc -ne $expectedStartUtc){throw 'BLOCKED_PANEL_PROCESS_START_TIME'}
    $listeners=@(Get-NetTCPConnection -State Listen -LocalPort ([int]$Meta.port) -ErrorAction SilentlyContinue)
    if($listeners.Count -eq 0 -or @($listeners|Where-Object{$_.LocalAddress -ne '127.0.0.1' -or $_.OwningProcess -ne [int]$Meta.pid}).Count -gt 0){throw 'BLOCKED_PANEL_LISTENER_IDENTITY'}
    return $p
}
function Get-HttpStatus([string]$Url) {
    $handler=[Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect=$false
    $handler.UseProxy=$false
    $client=[Net.Http.HttpClient]::new($handler)
    $client.Timeout=[TimeSpan]::FromSeconds(5)
    try {$response=$client.GetAsync($Url).GetAwaiter().GetResult();return [int]$response.StatusCode}
    finally {$client.Dispose();$handler.Dispose()}
}
function Get-RawHttpStatus([int]$ListenPort,[string]$Path) {
    $tcp=[Net.Sockets.TcpClient]::new()
    try {
        $connect=$tcp.ConnectAsync([Net.IPAddress]::Loopback,$ListenPort)
        if(-not $connect.Wait(3000)){throw 'BLOCKED_RAW_HTTP_CONNECT_TIMEOUT'}
        $stream=$tcp.GetStream();$stream.ReadTimeout=3000;$stream.WriteTimeout=3000
        $crlf=[string][char]13+[char]10
        $request="GET $Path HTTP/1.1"+$crlf+"Host: 127.0.0.1:$ListenPort"+$crlf+"Connection: close"+$crlf+$crlf
        $bytes=[Text.Encoding]::ASCII.GetBytes($request)
        $stream.Write($bytes,0,$bytes.Length);$stream.Flush()
        $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::ASCII,$false,1024,$true)
        $line=$reader.ReadLine()
        if($line -notmatch '^HTTP/1\.[01] (?<status>[0-9]{3})'){throw 'BLOCKED_RAW_HTTP_STATUS_LINE'}
        return [int]$Matches.status
    } finally {$tcp.Dispose()}
}

function Start-Panel {
    if(Test-Path -LiteralPath $markerPath){
        $previous=Get-PanelMeta
        if($previous.state -ne 'STOPPED'){throw 'BLOCKED_PANEL_INSTANCE_ALREADY_EXISTS'}
        $previousProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$previous.pid)" -ErrorAction SilentlyContinue
        $previousListeners=@(Get-NetTCPConnection -State Listen -LocalPort ([int]$previous.port) -ErrorAction SilentlyContinue)
        if($previousProcess -or $previousListeners.Count -gt 0){throw 'BLOCKED_STOPPED_PANEL_HAS_LIVE_PROCESS_OR_LISTENER'}
        $historyMarker=Join-Path $panelRoot ("panel-instance-"+[string]$previous.runId+".stopped.json")
        if(Test-Path -LiteralPath $historyMarker){throw 'BLOCKED_PANEL_HISTORY_MARKER_EXISTS'}
        Move-Item -LiteralPath $markerPath -Destination $historyMarker
    }
    if($Port -lt 1024 -or $Port -eq 3306 -or @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue).Count -gt 0){throw 'BLOCKED_PANEL_PORT_UNAVAILABLE'}
    Assert-NoReparse $routerPath
    if(-not(Test-Path -LiteralPath $phpExe -PathType Leaf) -or -not(Test-Path -LiteralPath $dbHelper -PathType Leaf)){throw 'BLOCKED_PANEL_TOOLING_MISSING'}
    $db=Get-Meta $privatePath
    [void](Assert-DbRunning $db $privatePath)
    if((Invoke-DbQuery $db 'SELECT COUNT(*) FROM users;') -ne '1'){throw 'BLOCKED_TARGET_ADMIN_COUNT'}
    [void](Get-AssetHashes)
    Ensure-RuntimeDirectories
    if(-not(Test-Path -LiteralPath (Join-Path $panelRoot 'synthetic-admin-created.json')) -or -not(Test-Path -LiteralPath $appKeyPath) -or -not(Test-Path -LiteralPath $credentialPath)){throw 'BLOCKED_PANEL_PREPARE_REQUIRED'}
    $key=Get-Content -LiteralPath $appKeyPath -Raw
    $environment=Enter-AppEnvironment $db $key (Get-ClientPassword $db)
    try {
        $phpCheck=Invoke-PhpBootstrap 'preflight'
        if(-not $phpCheck.ok -or $phpCheck.db -ne $db.database -or [int]$phpCheck.port -ne [int]$db.port -or $phpCheck.users -ne 1 -or $phpCheck.flags -ne 'OFF'){throw 'BLOCKED_LARAVEL_PREFLIGHT'}
        $runId=[Guid]::NewGuid().ToString('N')
        $stdout=Join-Path $panelRoot "php-$runId.stdout.log"
        $stderr=Join-Path $panelRoot "php-$runId.stderr.log"
        $publicRoot=Join-Path $privatePath 'public'
        $serverArgs=@('-d',"extension_dir=$phpDir\ext",'-S',"127.0.0.1:$Port",'-t',$publicRoot,$routerPath)
        $proc=Start-Process -FilePath $phpExe -ArgumentList $serverArgs -WorkingDirectory $serverRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $startTime=(Get-Process -Id $proc.Id -ErrorAction Stop).StartTime.ToUniversalTime().ToString('o')
        $meta=[ordered]@{schemaVersion=1;state='RUNNING';privateRoot=$privatePath;serverRoot=$serverRoot;router=$routerPath;publicRoot=$publicRoot;phpExe=$phpExe;pid=$proc.Id;processStartUtc=$startTime;port=$Port;bind='127.0.0.1';startedUtc=[DateTime]::UtcNow.ToString('o');stdout=$stdout;stderr=$stderr;runId=$runId}
        [IO.File]::WriteAllText($markerPath,($meta|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
    } finally {Exit-AppEnvironment $environment}
    $clock=[Diagnostics.Stopwatch]::StartNew();$ready=$false
    while($clock.Elapsed.TotalSeconds -lt 30){
        try {$m=Get-PanelMeta;[void](Get-VerifiedPanelProcess $m);if((Get-HttpStatus "http://127.0.0.1:$Port/up") -eq 200){$ready=$true;break}}
        catch {}
        Start-Sleep -Milliseconds 250
    }
    if(-not $ready){throw 'BLOCKED_PANEL_HEALTH_TIMEOUT'}
    Write-Ledger 'panel-start' 'PASS_SCOPED' $clock.Elapsed.TotalMilliseconds
    Write-Output "PANEL_START=PASS_SCOPED|BIND=127.0.0.1|PORT=$Port|PID=$($proc.Id)|ADMIN=synthetic-target-only"
}
function Test-PanelHttp {
    $meta=Get-PanelMeta
    [void](Get-VerifiedPanelProcess $meta)
    $db=Get-Meta $privatePath
    [void](Assert-DbRunning $db $privatePath)
    [void](Get-AssetHashes)
    $secret=Get-Content -LiteralPath $credentialPath -Raw|ConvertFrom-Json
    $handler=[Net.Http.HttpClientHandler]::new()
    $handler.CookieContainer=[Net.CookieContainer]::new()
    $handler.AllowAutoRedirect=$true
    $handler.UseProxy=$false
    $client=[Net.Http.HttpClient]::new($handler)
    $client.Timeout=[TimeSpan]::FromSeconds(12)
    $base="http://127.0.0.1:$($meta.port)"
    $checks=[Collections.Generic.List[string]]::new()
    $loginHtml=''
    try {
        $health=$client.GetAsync("$base/up").GetAwaiter().GetResult()
        if([int]$health.StatusCode -ne 200){throw 'BLOCKED_HTTP_UP'}
        $login=$client.GetAsync("$base/login").GetAwaiter().GetResult()
        if([int]$login.StatusCode -ne 200){throw 'BLOCKED_HTTP_LOGIN_GET'}
        $loginHtml=$login.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $tokenMatch=[regex]::Match($loginHtml,'(?i)<input\b(?=[^>]*\bname=["'']_token["''])(?=[^>]*\bvalue=["'']([^"'']+)["''])[^>]*>')
        if(-not $tokenMatch.Success){throw 'BLOCKED_HTTP_CSRF_TOKEN'}
        $csrf=[Net.WebUtility]::HtmlDecode($tokenMatch.Groups[1].Value)
        $form=[Collections.Generic.Dictionary[string,string]]::new()
        $form.Add('_token',$csrf);$form.Add('email',[string]$secret.email);$form.Add('password',[string]$secret.password);$form.Add('remember','0')
        $loginPost=$client.PostAsync("$base/login",[Net.Http.FormUrlEncodedContent]::new($form)).GetAwaiter().GetResult()
        if([int]$loginPost.StatusCode -lt 200 -or [int]$loginPost.StatusCode -ge 400){throw 'BLOCKED_HTTP_LOGIN_POST'}
        $admin=$client.GetAsync("$base/admin").GetAwaiter().GetResult()
        if([int]$admin.StatusCode -ne 200){throw 'BLOCKED_HTTP_ADMIN_AUTH'}
        $adminHtml=$admin.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $checks.Add('login+csrf=PASS');$checks.Add('admin=200')
        $national=$client.GetAsync("$base/admin/operations/national").GetAwaiter().GetResult()
        if([int]$national.StatusCode -ne 200){throw 'BLOCKED_HTTP_NATIONAL'}
        $nationalHtml=$national.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if($nationalHtml -notmatch '(?i)(?:1104|1[., ]104)' -or $nationalHtml -notmatch '(?i)SIN RELEASE ACTUAL'){throw 'BLOCKED_HTTP_NATIONAL_CONTENT'}
        $checks.Add('national=200|municipalities=1104|release=none')
        $filter=$client.GetAsync("$base/admin/operations/national?q=05001").GetAwaiter().GetResult()
        if([int]$filter.StatusCode -ne 200){throw 'BLOCKED_HTTP_NATIONAL_FILTER'}
        $filterHtml=$filter.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if($filterHtml -notmatch '(?i)Medell[ií]n'){throw 'BLOCKED_HTTP_NATIONAL_FILTER_CONTENT'}
        $checks.Add('national-filter=05001:Medellin')
        foreach($route in @('/admin/restrictions/municipalities','/admin/app-users','/admin/campaigns/planning')){
            $response=$client.GetAsync("$base$route").GetAwaiter().GetResult()
            if([int]$response.StatusCode -ne 200){throw "BLOCKED_HTTP_READ_ROUTE_$($route.Replace('/','_'))"}
            $checks.Add("$route=200")
        }
        $campaign=$client.GetAsync("$base/api/v1/campaign-catalog").GetAwaiter().GetResult()
        if([int]$campaign.StatusCode -ne 404){throw 'BLOCKED_CAMPAIGN_CATALOG_NOT_OFF'}
        $checks.Add('campaign-catalog=404_OFF')
        $assetMatches=[regex]::Matches($loginHtml,'(?i)(?:href|src)=["''](?<url>[^"'']*/build/assets/[^"'']+)["'']')
        $seen=@{};$expected=Get-AssetHashes
        foreach($match in $assetMatches){
            $assetUri=[Uri]::new([Uri]$base,[Net.WebUtility]::HtmlDecode($match.Groups['url'].Value))
            $assetPath=$assetUri.AbsolutePath
            if(-not $expected.ContainsKey($assetPath) -or $seen.ContainsKey($assetPath)){continue}
            if($assetUri.Host -ne '127.0.0.1' -or $assetUri.Port -ne [int]$meta.port){throw 'BLOCKED_ASSET_EXTERNAL_ORIGIN'}
            $response=$client.GetAsync($assetUri).GetAwaiter().GetResult()
            if([int]$response.StatusCode -ne 200){throw 'BLOCKED_ASSET_HTTP'}
            $bytes=$response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
            $hasher=[Security.Cryptography.SHA256]::Create()
            try{$sha=[Convert]::ToHexString($hasher.ComputeHash($bytes))}finally{$hasher.Dispose()}
            if($sha -ne $expected[$assetPath]){throw 'BLOCKED_ASSET_HTTP_HASH'}
            $seen[$assetPath]=$sha
        }
        if($seen.Count -ne 2){throw 'BLOCKED_ASSET_REFERENCES'}
        $checks.Add("assets=2|css=$($seen['/build/assets/app-DZ9YpV5z.css'])|js=$($seen['/build/assets/app-DMsN-rLE.js'])")
        $postDenied=$client.PostAsync("$base/admin/restrictions",[Net.Http.StringContent]::new('')).GetAwaiter().GetResult()
        if([int]$postDenied.StatusCode -ne 404){throw 'BLOCKED_ROUTER_POST_NOT_DENIED'}
        $checks.Add('unauthorized-post=404')
        $overrideRequest=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get,"$base/admin")
        $overrideRequest.Headers.Add('X-HTTP-Method-Override','POST')
        $overrideResponse=$client.SendAsync($overrideRequest).GetAwaiter().GetResult()
        if([int]$overrideResponse.StatusCode -ne 404){throw 'BLOCKED_METHOD_OVERRIDE'}
        $checks.Add('method-override=404')
        foreach($path in @('/.env','/%2e%2e/.env')){
            $privateStatus=Get-RawHttpStatus ([int]$meta.port) $path
            if($privateStatus -ne 404){throw 'BLOCKED_PRIVATE_PATH_EXPOSED'}
        }
        $checks.Add('private-traversal=404')
        $tokenAdmin=[regex]::Match($adminHtml,'(?i)<input\b(?=[^>]*\bname=["'']_token["''])(?=[^>]*\bvalue=["'']([^"'']+)["''])[^>]*>')
        if($tokenAdmin.Success){
            $logoutForm=[Collections.Generic.Dictionary[string,string]]::new()
            $logoutForm.Add('_token',[Net.WebUtility]::HtmlDecode($tokenAdmin.Groups[1].Value))
            $logout=$client.PostAsync("$base/logout",[Net.Http.FormUrlEncodedContent]::new($logoutForm)).GetAwaiter().GetResult()
            if([int]$logout.StatusCode -lt 200 -or [int]$logout.StatusCode -ge 400){throw 'BLOCKED_HTTP_LOGOUT'}
            $checks.Add('logout=PASS')
        }
        Write-Ledger 'panel-http-smoke' 'PASS_SCOPED' 0
        Write-Output ('PANEL_HTTP=PASS_SCOPED|'+($checks -join '|'))
    } finally {$client.Dispose();$handler.Dispose()}
}

Assert-PrivateRoot
if(-not(Test-Path -LiteralPath $panelRoot)){New-Item -ItemType Directory -Path $panelRoot|Out-Null}
$lockPath=Join-Path $panelRoot 'panel-operation.lock'
$lock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$clock=[Diagnostics.Stopwatch]::StartNew()
try {
    switch($Action){
        'Prepare' {
            if(Test-Path -LiteralPath $markerPath){throw 'BLOCKED_PANEL_INSTANCE_ALREADY_EXISTS'}
            if(-not(Test-Path -LiteralPath $serverRoot -PathType Container) -or -not(Test-Path -LiteralPath (Join-Path $serverRoot 'vendor\autoload.php') -PathType Leaf)){throw 'BLOCKED_LARAVEL_SOURCE_OR_VENDOR'}
            if(-not(Test-Path -LiteralPath $clientExe -PathType Leaf) -or -not(Test-Path -LiteralPath $phpExe -PathType Leaf) -or -not(Test-Path -LiteralPath $bootstrapPath -PathType Leaf)){throw 'BLOCKED_PHP_OR_DB_CLIENT'}
            $target=Get-Meta $privatePath;$source=Get-Meta $sourcePath
            [void](Assert-DbRunning $source $sourcePath);[void](Assert-DbRunning $target $privatePath)
            $sourceUsers=Invoke-DbQuery $source 'SELECT COUNT(*) FROM users;'
            $targetUsers=Invoke-DbQuery $target 'SELECT COUNT(*) FROM users;'
            if($sourceUsers -ne '0' -or $targetUsers -ne '0'){throw 'BLOCKED_UNEXPECTED_OPERATOR_DATA'}
            [void](Get-AssetHashes);Ensure-RuntimeDirectories
            $keyExists=Test-Path -LiteralPath $appKeyPath;$credentialExists=Test-Path -LiteralPath $credentialPath
            if($keyExists -xor $credentialExists){throw 'BLOCKED_PARTIAL_PRIVATE_CREDENTIALS'}
            if(-not $keyExists){
                $key='base64:'+[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
                $password='C33QA'+[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
                [IO.File]::WriteAllText($appKeyPath,$key,[Text.UTF8Encoding]::new($false))
                $credentials=[ordered]@{name='C33 Local QA';email='qa-c33-admin@localhost.test';password=$password}
                [IO.File]::WriteAllText($credentialPath,($credentials|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
                $acl=Get-Acl -LiteralPath $privatePath
                Set-Acl -LiteralPath $appKeyPath -AclObject $acl;Set-Acl -LiteralPath $credentialPath -AclObject $acl
            } else {$key=Get-Content -LiteralPath $appKeyPath -Raw}
            $allowed=@([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18','S-1-5-32-544')
            foreach($file in @($appKeyPath,$credentialPath)){
                $a=Get-Acl -LiteralPath $file
                if(-not $a.AreAccessRulesProtected){throw 'BLOCKED_SECRET_ACL_INHERIT'}
                $actual=@($a.Access|ForEach-Object{$_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value}|Sort-Object -Unique)
                if(@($actual|Where-Object{$_ -notin $allowed}).Count -gt 0){throw 'BLOCKED_SECRET_ACL_FOREIGN'}
            }
            Write-Ledger 'panel-private-preflight' 'STARTED' $clock.Elapsed.TotalMilliseconds
            $environment=Enter-AppEnvironment $target $key (Get-ClientPassword $target)
            try {
                $preflight=Invoke-PhpBootstrap 'preflight'
                if(-not $preflight.ok -or $preflight.users -ne 0 -or $preflight.flags -ne 'OFF' -or $preflight.db -ne $target.database -or [int]$preflight.port -ne [int]$target.port){throw 'BLOCKED_LARAVEL_TARGET_PREFLIGHT'}
                $created=Invoke-PhpBootstrap 'create'
                if(-not $created.ok -or -not $created.admin_created -or $created.users -ne 1 -or $created.role -ne 'super_admin' -or -not $created.active){throw 'BLOCKED_SYNTHETIC_ADMIN_VERIFY'}
            } finally {Exit-AppEnvironment $environment}
            $adminMarker=[ordered]@{schemaVersion=1;createdUtc=[DateTime]::UtcNow.ToString('o');database=$target.database;users=1;role='super_admin';synthetic=$true}
            [IO.File]::WriteAllText((Join-Path $panelRoot 'synthetic-admin-created.json'),($adminMarker|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
            Write-Ledger 'panel-prepare-admin' 'PASS_SCOPED' $clock.Elapsed.TotalMilliseconds
            Write-Output "PANEL_PREPARE=PASS_SCOPED|SOURCE_USERS=0|TARGET_USERS=1|ROLE=super_admin|EXTERNAL_FLAGS=OFF|APP_KEY=PRIVATE"
        }
        'Start' {Start-Panel}
        'Status' {
            $m=Get-PanelMeta
            if($m.state -eq 'STOPPED'){Write-Output 'PANEL_STATUS=STOPPED';break}
            [void](Get-VerifiedPanelProcess $m)
            $status=Get-HttpStatus "http://127.0.0.1:$($m.port)/up"
            if($status -ne 200){throw 'BLOCKED_PANEL_STATUS_HEALTH'}
            Write-Output "PANEL_STATUS=RUNNING|HTTP_UP=$status|BIND=127.0.0.1|PORT=$($m.port)|PID=$($m.pid)"
        }
        'Smoke' {Test-PanelHttp}
        'Stop' {
            $m=Get-PanelMeta
            if($m.state -eq 'STOPPED'){Write-Output 'PANEL_STOP=PASS_SCOPED|ALREADY_STOPPED';break}
            $proc=Get-VerifiedPanelProcess $m
            if($null -eq $proc){
                $listeners=@(Get-NetTCPConnection -State Listen -LocalPort ([int]$m.port) -ErrorAction SilentlyContinue)
                if($listeners.Count -gt 0){throw 'BLOCKED_UNOWNED_PANEL_LISTENER'}
            } else {
                Stop-Process -Id ([int]$m.pid) -ErrorAction Stop
                $wait=[Diagnostics.Stopwatch]::StartNew()
                do {
                    Start-Sleep -Milliseconds 200
                    $alive=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$m.pid)" -ErrorAction SilentlyContinue
                    $listeners=@(Get-NetTCPConnection -State Listen -LocalPort ([int]$m.port) -ErrorAction SilentlyContinue)
                } while(($alive -or $listeners.Count -gt 0) -and $wait.Elapsed.TotalSeconds -lt 20)
                if($alive -or $listeners.Count -gt 0){throw 'BLOCKED_PANEL_STOP_TIMEOUT'}
            }
            $m.state='STOPPED';$m|Add-Member -NotePropertyName stoppedUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
            [IO.File]::WriteAllText($markerPath,($m|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
            Write-Ledger 'panel-stop' 'PASS_SCOPED' $clock.Elapsed.TotalMilliseconds
            Write-Output "PANEL_STOP=PASS_SCOPED|PID=$($m.pid)|LISTENER=CLOSED|DATA=RETAINED"
        }
    }
} finally {$lock.Dispose()}