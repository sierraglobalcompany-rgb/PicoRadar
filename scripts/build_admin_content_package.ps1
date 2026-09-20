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

$guideSource = Join-Path $root 'docs/operations/PicoRadar_GUIA_PANEL_ADMIN_CONTENIDOS.md'
$guideDestination = Join-Path $output 'PicoRadar_GUIA_PANEL_ADMIN_CONTENIDOS.md'
Copy-Item -LiteralPath $guideSource -Destination $guideDestination -Force

$hashLines = @(
    Get-ChildItem -LiteralPath $output -File |
        Where-Object Name -ne 'SHA256SUMS.txt' |
        Sort-Object Name |
        ForEach-Object { "$(($_ | Get-FileHash -Algorithm SHA256).Hash)  $($_.Name)" }
)
[System.IO.File]::WriteAllText(
    (Join-Path $output 'SHA256SUMS.txt'),
    (($hashLines -join "`n") + "`n"),
    [System.Text.UTF8Encoding]::new($false)
)
