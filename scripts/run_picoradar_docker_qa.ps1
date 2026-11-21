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
# Process-scoped environment takes precedence over --env-file in Docker
# Compose; this also avoids storing synthetic secrets on disk.
$qaEnvNames = @('PICORADAR_QA_PROJECT', 'PICORADAR_QA_DB_PASSWORD', 'PICORADAR_QA_APP_KEY')
$qaEnvBefore = @{}
foreach ($qaName in $qaEnvNames) {
    $qaEnvBefore[$qaName] = [Environment]::GetEnvironmentVariable($qaName, 'Process')
}
$env:PICORADAR_QA_PROJECT = $project
$env:PICORADAR_QA_DB_PASSWORD = New-HexSecret
$env:PICORADAR_QA_APP_KEY = New-AppKey
$composeArgs = @('compose', '--project-name', $project, '--file', $composeFile)

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
        # PHPUnit XML's <env> does NOT replace already-set Compose variables.
        # Force synthetic SQLite in the *test container*; never use MariaDB from
        # the schema mode or any host/other-project database.
        # No MariaDB service is started in the focused test mode.
        Invoke-Compose -ArgsList @('run', '--rm', '--no-deps',
            '-e', 'DB_CONNECTION=sqlite',
            '-e', 'DB_DATABASE=:memory:',
            '-e', 'DB_URL=',
            'app', 'php', 'artisan', 'test', '--filter', $Filter)
    }
    Write-Host 'PASS_SCOPED_DOCKER_ISOLATION; does not imply HTTPS or production release.'
} finally {
    try {
        # Only our unique project: NEVER docker system prune / compose down -v.
        & docker @composeArgs down 2>$null | Out-Null
    } finally {
        # Restore process-only values even if Docker cleanup fails.
        foreach ($qaName in $qaEnvNames) {
            [Environment]::SetEnvironmentVariable($qaName, $qaEnvBefore[$qaName], 'Process')
        }
    }
}
