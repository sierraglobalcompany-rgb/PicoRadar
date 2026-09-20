param(
    [string] $OutputDirectory = 'artifacts/current/admin-content',
    [string] $PhpPath = 'php',
    [string] $AppUrl = 'https://picoradar.bodegadigitalmedellin.com'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$output = [System.IO.Path]::GetFullPath((Join-Path $root $OutputDirectory))

& (Join-Path $PSScriptRoot 'build_hostinger_staging_package.ps1') `
    -OutputDirectory $output `
    -PhpPath $PhpPath `
    -AppUrl $AppUrl `
    -PackagePrefix 'PicoRadar-admin-contenidos'
if ($LASTEXITCODE -ne 0) {
    throw "Admin content package build failed with exit code $LASTEXITCODE."
}
