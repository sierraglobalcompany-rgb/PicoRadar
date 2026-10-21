# PicoRadar B04 CSV — strict local smoke + Laravel QA.
# Execute ONLY inside a disposable clean clone of feat/B04-csv-safe-parser.
# Does not reset/clean/checkout, deploy, push, migrate a persistent DB, or touch other worktrees.
# MariaDB/concurrent operator QA is a separate guarded manual gate, never auto-PASS.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$originalLocation = (Get-Location).Path
$checks = @()

function Require-ExitZero {
    param([string]$Name, [scriptblock]$Action)
    Write-Host "B04 QA: $Name"
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
    $script:checks += $Name
}

try {
    Set-Location -LiteralPath $root
    if (-not (Test-Path -LiteralPath (Join-Path $root 'server/artisan'))) {
        throw 'This is not the PicoRadar repository root.'
    }

    Require-ExitZero 'git HEAD' { git rev-parse HEAD }
    $actualBranch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $actualBranch -ne 'feat/B04-csv-safe-parser') {
        throw "Wrong local branch ($actualBranch). Do not test a different checkout."
    }
    $dirty = @(& git status --porcelain=v1 -uall)
    if ($LASTEXITCODE -ne 0 -or @($dirty | Where-Object { $_.Length -gt 0 }).Count -gt 0) {
        throw 'The QA checkout has local/untracked changes. Preserve them and use another clean clone.'
    }
    $worktree = @(& git worktree list --porcelain)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect Git worktrees.' }
    Write-Host 'B04 QA: worktree inventory (read-only)'
    $worktree | ForEach-Object { Write-Host $_ }
    Write-Host "B04 QA: branch=$actualBranch"
    $checks += 'clean git preflight'

    if (-not (Get-Command php -ErrorAction SilentlyContinue)) {
        throw 'PHP CLI is unavailable. Do not claim runtime QA.'
    }
    Require-ExitZero 'PHP version' { php --version }

    $extensions = @(& php -m)
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect PHP extensions.' }
    foreach ($needed in @('mbstring', 'pdo_sqlite', 'sqlite3', 'fileinfo')) {
        if (@($extensions | Where-Object { $_ -ieq $needed }).Count -ne 1) {
            throw "Missing required PHP extension: $needed"
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'server/vendor/autoload.php'))) {
        throw 'Composer dependencies missing in this clean clone. Run composer install using committed lockfile, then restart QA.'
    }

    Set-Location -LiteralPath (Join-Path $root 'server')
    $sources = @(
        'app/Services/CameraCsvParser.php',
        'app/Services/CameraRegistryService.php',
        'app/Services/AnsvRichCameraImporter.php',
        'app/Services/CameraCsvPreviewService.php',
        'app/Services/CameraCsvImportService.php',
        'app/Models/CameraCsvImport.php',
        'app/Http/Controllers/Admin/CameraCsvImportController.php',
        'database/migrations/2026_10_21_154600_create_camera_csv_imports_table.php',
        'tests/Unit/CameraCsvParserTest.php',
        'tests/Feature/CameraCsvPreviewTest.php',
        'tests/Feature/CameraCsvImportTest.php',
        'tests/Feature/CameraRegistryTest.php',
        'tests/Feature/AnsvRichCameraImportTest.php',
        'routes/web.php'
    )
    foreach ($source in $sources) {
        if (-not (Test-Path -LiteralPath $source)) { throw "Missing source: $source" }
        Require-ExitZero "php -l $source" { php -l $source }
    }

    # Tests use the repository phpunit.xml in-memory SQLite database.
    # Never run artisan migrate here against a configured persistent database.
    # In this child process only: prevent an inherited production key,
    # connection, or cache from affecting QA. No .env writes or persisted key.
    $env:APP_ENV = 'testing'
    $env:APP_KEY = 'base64:' + [Convert]::ToBase64String(
        [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
    )
    $env:CACHE_STORE = 'array'
    $env:SESSION_DRIVER = 'array'
    $env:QUEUE_CONNECTION = 'sync'
    $env:DB_CONNECTION = 'sqlite'
    $env:DB_DATABASE = ':memory:'
    $env:DB_URL = ''
    Require-ExitZero 'Laravel B04 routes' { php artisan route:list --path=admin/cameras/imports }
    # Laravel route:list exits 0 for an empty result. Verify the exact contract,
    # not only the command exit status; no assumptions about display columns.
    $routeJson = & php artisan route:list --json --path=admin/cameras/imports
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect B04 routes as JSON.' }
    $routes = @($routeJson | ConvertFrom-Json)
    $expectedRoutes = @{
        'admin.camera-csv-imports.index' = 'GET'
        'admin.camera-csv-imports.create' = 'GET'
        'admin.camera-csv-imports.template' = 'GET'
        'admin.camera-csv-imports.store' = 'POST'
        'admin.camera-csv-imports.show' = 'GET'
        'admin.camera-csv-imports.report' = 'GET'
        'admin.camera-csv-imports.apply' = 'POST'
    }
    $actual = @{}
    foreach ($route in $routes) {
        if ($route.name -like 'admin.camera-csv-imports.*') {
            if ($actual.ContainsKey($route.name)) { throw "Duplicate route name: $($route.name)" }
            $actual[$route.name] = $route.method
        }
    }
    if ($actual.Count -ne $expectedRoutes.Count) {
        throw "B04 route count mismatch: expected $($expectedRoutes.Count), found $($actual.Count)."
    }
    foreach ($routeName in $expectedRoutes.Keys) {
        if (-not $actual.ContainsKey($routeName) -or
            @($actual[$routeName] -split '\\|') -notcontains $expectedRoutes[$routeName]) {
            throw "B04 missing or wrong HTTP method: $routeName"
        }
    }
    Write-Host 'B04 QA: all seven named routes and HTTP methods verified.'
    $checks += 'seven B04 route contracts'

    Require-ExitZero 'PHP Pint (test only)' { php vendor/bin/pint --test }
    Require-ExitZero 'B04 focal Laravel tests' { php artisan test --filter=CameraCsv }
    Require-ExitZero 'Laravel full suite (once)' { php artisan test }

    Write-Host ''
    Write-Host 'B04_LOCAL_SQLITE_QA_PASS (only tested scope)'
    Write-Host "Checked gates: $($checks.Count)"
    Write-Host 'B04_OVERALL_STATUS=PARTIAL: separate MariaDB concurrency/unique-index tests and Windows browser QA still required.'
    exit 0
} catch {
    # Write-Error is terminating under ErrorActionPreference=Stop;
    # use the error stream directly so exit 1 is deterministic.
    [Console]::Error.WriteLine("B04_LOCAL_QA_BLOCKED_OR_FAIL: $($_.Exception.Message)")
    Write-Host "Checks completed before failure: $($checks.Count)"
    exit 1
} finally {
    Set-Location -LiteralPath $originalLocation
}
