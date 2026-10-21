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
    if ($LASTEXITCODE -ne 0 -or ($dirty | Where-Object { $_.Length -gt 0 }).Count -gt 0) {
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
        'app/Services/CameraCsvPreviewService.php',
        'app/Services/CameraCsvImportService.php',
        'app/Models/CameraCsvImport.php',
        'app/Http/Controllers/Admin/CameraCsvImportController.php',
        'database/migrations/2026_10_21_154600_create_camera_csv_imports_table.php',
        'tests/Unit/CameraCsvParserTest.php',
        'tests/Feature/CameraCsvPreviewTest.php',
        'tests/Feature/CameraCsvImportTest.php',
        'routes/web.php'
    )
    foreach ($source in $sources) {
        if (-not (Test-Path -LiteralPath $source)) { throw "Missing source: $source" }
        Require-ExitZero "php -l $source" { php -l $source }
    }

    # Tests use the repository phpunit.xml in-memory SQLite database.
    # Never run artisan migrate here against a configured persistent database.
    $env:APP_ENV = 'testing'
    $env:DB_CONNECTION = 'sqlite'
    $env:DB_DATABASE = ':memory:'
    $env:DB_URL = ''
    Require-ExitZero 'Laravel B04 routes' { php artisan route:list --path=admin/cameras/imports }
    Require-ExitZero 'PHP Pint (test only)' { php vendor/bin/pint --test }
    Require-ExitZero 'B04 focal Laravel tests' { php artisan test --filter=CameraCsv }
    Require-ExitZero 'Laravel full suite (once)' { php artisan test }

    Write-Host ''
    Write-Host 'B04_LOCAL_SQLITE_QA_PASS (only tested scope)'
    Write-Host "Checked gates: $($checks.Count)"
    Write-Host 'B04_OVERALL_STATUS=PARTIAL: separate MariaDB concurrency/unique-index tests and Windows browser QA still required.'
    exit 0
} catch {
    Write-Error "B04_LOCAL_QA_BLOCKED_OR_FAIL: $($_.Exception.Message)"
    Write-Host "Checks completed before failure: $($checks.Count)"
    exit 1
} finally {
    Set-Location -LiteralPath $originalLocation
}
