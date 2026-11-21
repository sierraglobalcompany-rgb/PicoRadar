#Requires -Version 5.1
<#
.SYNOPSIS
  Single-run isolated PicoRadar PHP/MariaDB QA; never touches host services.
.EXAMPLE
  pwsh -NoProfile -File scripts/run_picoradar_docker_qa.ps1 -Mode schema
.EXAMPLE
  pwsh -NoProfile -File scripts/run_picoradar_docker_qa.ps1 -Mode test -Filter RestrictionMunicipalityMatrixTest
#>
[CmdletBinding()]
param(
    [ValidateSet('schema', 'test')]
    [string]$Mode = 'schema',
    [string]$Filter = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$composeFile = Join-Path $repo 'infra/docker/compose.qa.yml'
if (-not (Test-Path -LiteralPath $composeFile -PathType Leaf)) {
    throw 'The isolated Compose definition is missing.'
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker is unavailable. Nothing was modified.'
}
& docker compose version | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose is unavailable.' }

# Require a dedicated clean checkout. Never package 43 protected WIP paths or
# accidentally bake secrets/uncommitted files from another Codex agent.
& git -C $repo rev-parse --is-inside-work-tree | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'A Git worktree is required.' }
$dirty = (& git -C $repo status --porcelain --untracked-files=all | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $dirty.Length -gt 0) {
    throw 'Use a CLEAN isolated PicoRadar clone/worktree; protected or dirty checkout refused.'
}
if ($Mode -eq 'test' -and ([string]::IsNullOrWhiteSpace($Filter) -or $Filter -eq '.*')) {
    throw 'Provide a specific -Filter. Broad/repeated test suites are forbidden in this launcher.'
}

function New-HexSecret {
    $data = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($data) } finally { $rng.Dispose() }
    return ([BitConverter]::ToString($data)).Replace('-', '').ToLowerInvariant()
}
function New-AppKey {
    $data = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($data) } finally { $rng.Dispose() }
    return 'base64:' + [Convert]::ToBase64String($data)
}

$project = 'picoradar-qa-' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
$scratch = Join-Path ([IO.Path]::GetTempPath()) $project
[void][IO.Directory]::CreateDirectory($scratch)
$envFile = Join-Path $scratch 'compose.env'
$settings = @(
    "PICORADAR_QA_PROJECT=$project",
    'PICORADAR_QA_DB_PASSWORD=' + (New-HexSecret),
    'PICORADAR_QA_APP_KEY=' + (New-AppKey)
) -join "`n"
[IO.File]::WriteAllText($envFile, $settings + "`n", (New-Object Text.UTF8Encoding($false)))
$composeArgs = @('compose', '--project-name', $project, '--env-file', $envFile, '--file', $composeFile)
function Invoke-Compose {
    param([Parameter(Mandatory=$true)][string[]]$ArgsList)
    & docker @composeArgs @ArgsList
    if ($LASTEXITCODE -ne 0) { throw "Isolated Compose command failed (exit $LASTEXITCODE)." }
}

try {
    Write-Host "PicoRadar isolated QA; unique Docker project: $project"
    Invoke-Compose -ArgsList @('build', 'app')
    if ($Mode -eq 'schema') {
        Invoke-Compose -ArgsList @('up', '-d', '--wait', 'db')
        Invoke-Compose -ArgsList @('run', '--rm', '--no-deps', 'app', 'php', 'artisan', 'migrate', '--force', '--no-interaction')
        Invoke-Compose -ArgsList @('run', '--rm', '--no-deps', 'app', 'php', 'artisan', 'migrate:status')
    } else {
        # phpunit.xml intentionally selects in-memory SQLite for existing tests.
        # No MariaDB service is started in the focused test mode.
        Invoke-Compose -ArgsList @('run', '--rm', '--no-deps', 'app', 'php', 'artisan', 'test', '--filter', $Filter)
    }
    Write-Host 'PASS_SCOPED_DOCKER_ISOLATION; does not imply HTTPS or production release.'
} finally {
    # Only our unique project: NEVER docker system prune / compose down -v.
    & docker @composeArgs down 2>$null | Out-Null
    if (Test-Path -LiteralPath $envFile) { Remove-Item -LiteralPath $envFile -Force }
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Force }
}
