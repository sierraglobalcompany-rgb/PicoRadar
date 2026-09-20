$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

$build = Get-Content -LiteralPath (Join-Path $root 'scripts/build_hostinger_staging_package.ps1') -Raw
$wrapper = Get-Content -LiteralPath (Join-Path $root 'scripts/build_admin_content_package.ps1') -Raw

if ($build -notmatch "PackagePrefix = 'PicoRadar-staging-hostinger'") {
    throw 'The accepted B06 package name is no longer the default.'
}
if ($build -notmatch '\$zipName = "\$PackagePrefix-\$releaseId\.zip"') {
    throw 'The package builder does not use its validated prefix.'
}
if ($wrapper -notmatch "PackagePrefix 'PicoRadar-admin-contenidos'") {
    throw 'The B07 wrapper does not select the required installable name.'
}
if ($wrapper -notmatch 'PicoRadar_GUIA_PANEL_ADMIN_CONTENIDOS\.md') {
    throw 'The B07 package output does not include the Spanish owner guide.'
}
if ($build -notmatch "pico_jurisdiction_catalog_v1\.json") {
    throw 'The package builder does not bundle the Pico jurisdiction fixture required by a clean install.'
}
if ($build -notmatch "colombia_registration_cities_v1\.json") {
    throw 'The package builder does not bundle the registration-city fixture required by a clean install.'
}

Write-Output 'PASS: B06 keeps its default name and B07 selects a complete, separate installable.'
