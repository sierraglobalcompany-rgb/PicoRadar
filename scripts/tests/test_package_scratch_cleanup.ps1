$ErrorActionPreference = 'Stop'
$helper = Join-Path $PSScriptRoot '../package_scratch_cleanup.ps1'
if (-not (Test-Path -LiteralPath $helper)) { throw 'FAIL: bounded owned-scratch cleanup is missing.' }
. $helper

Add-Type -TypeDefinition @'
using System.IO;
using System.Threading.Tasks;
public static class PackageCleanupFixture {
    public static async Task ReleaseAfter(FileStream stream) {
        await Task.Delay(300);
        stream.Dispose();
    }
}
'@

$scratchRoot = Join-Path ([IO.Path]::GetTempPath()) ('picoradar-hostinger-package-' + [guid]::NewGuid().ToString('N'))
$outsideRoot = Join-Path ([IO.Path]::GetTempPath()) ('picoradar-hostinger-package-' + [guid]::NewGuid().ToString('N'))
$verifyRoot = Join-Path ([IO.Path]::GetTempPath()) ('picoradar-hostinger-verify-' + [guid]::NewGuid().ToString('N'))
$held = $null
$junctions = @()
try {
    New-Item -ItemType Directory -Path $scratchRoot, $outsideRoot | Out-Null
    New-Item -ItemType Directory -Path $verifyRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $verifyRoot 'fixture.txt'), 'synthetic verifier fixture')
    Remove-PackageScratchDirectory -Path $verifyRoot -ScratchRoot $verifyRoot
    if (Test-Path -LiteralPath $verifyRoot) { throw 'FAIL: generated verification scratch remains.' }
    $sentinel = Join-Path $outsideRoot 'sentinel.txt'
    [IO.File]::WriteAllText($sentinel, 'synthetic boundary fixture')
    $rejected = $false
    try { Remove-PackageScratchDirectory -Path $outsideRoot -ScratchRoot $scratchRoot }
    catch [ArgumentException] { $rejected = $true }
    if (-not $rejected -or -not (Test-Path -LiteralPath $sentinel)) { throw 'FAIL: outside scratch boundary was not preserved.' }

    $rejected = $false
    try { Remove-PackageScratchDirectory -Path $scratchRoot -ScratchRoot ([IO.Path]::GetTempPath()) }
    catch [ArgumentException] { $rejected = $true }
    if (-not $rejected) { throw 'FAIL: temporary-directory root must not be accepted as owned scratch.' }

    $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($scratchRoot))
    if ($drive.DriveFormat -eq 'NTFS') {
        $outsideChild = Join-Path $outsideRoot 'child'
        New-Item -ItemType Directory -Path $outsideChild | Out-Null
        $bridge = Join-Path $scratchRoot 'bridge'
        $linkedRoot = Join-Path ([IO.Path]::GetTempPath()) ('picoradar-hostinger-package-' + [guid]::NewGuid().ToString('N'))
        foreach ($link in @($bridge, $linkedRoot)) {
            New-Item -ItemType Junction -Path $link -Target $outsideRoot | Out-Null
            $junctions += $link
            $owner = if ($link -eq $bridge) { $scratchRoot } else { $linkedRoot }
            $rejected = $false
            try { Remove-PackageScratchDirectory -Path (Join-Path $link 'child') -ScratchRoot $owner }
            catch [ArgumentException] { $rejected = $true }
            if (-not $rejected -or -not (Test-Path -LiteralPath $outsideChild)) { throw 'FAIL: junction ancestor escaped scratch.' }
        }
    } else {
        Write-Output "SKIP: junction fixture requires NTFS; TEMP filesystem is $($drive.DriveFormat)."
    }

    $transient = Join-Path $scratchRoot 'transient'
    New-Item -ItemType Directory -Path $transient | Out-Null
    $file = Join-Path $transient 'held.txt'
    [IO.File]::WriteAllText($file, 'synthetic transient fixture')
    $held = [IO.File]::Open($file, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    $release = [PackageCleanupFixture]::ReleaseAfter($held)
    Remove-PackageScratchDirectory -Path $transient -ScratchRoot $scratchRoot
    [void]$release.GetAwaiter().GetResult()
    $held = $null
    if (Test-Path -LiteralPath $transient) { throw 'FAIL: transient lock prevented cleanup.' }

    $persistent = Join-Path $scratchRoot 'persistent'
    New-Item -ItemType Directory -Path $persistent | Out-Null
    $file = Join-Path $persistent 'held.txt'
    [IO.File]::WriteAllText($file, 'synthetic persistent fixture')
    $held = [IO.File]::Open($file, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    $failed = $false
    try { Remove-PackageScratchDirectory -Path $persistent -ScratchRoot $scratchRoot }
    catch [IO.IOException] { $failed = $true }
    if (-not $failed -or -not (Test-Path -LiteralPath $file)) { throw 'FAIL: persistent failure was hidden.' }
    $held.Dispose()
    $held = $null
    Remove-PackageScratchDirectory -Path $persistent -ScratchRoot $scratchRoot
    Remove-PackageScratchDirectory -Path $persistent -ScratchRoot $scratchRoot
    Write-Output 'PASS: outside paths preserved, transient lock retried, persistent failure propagated, absent path accepted.'
} finally {
    if ($null -ne $held) { $held.Dispose() }
    foreach ($link in $junctions) {
        if (Test-Path -LiteralPath $link) { [IO.Directory]::Delete($link, $false) }
    }
    Remove-PackageScratchDirectory -Path $scratchRoot -ScratchRoot $scratchRoot
    Remove-PackageScratchDirectory -Path $outsideRoot -ScratchRoot $outsideRoot
    if (Test-Path -LiteralPath $verifyRoot) { [IO.Directory]::Delete($verifyRoot, $true) }
}
