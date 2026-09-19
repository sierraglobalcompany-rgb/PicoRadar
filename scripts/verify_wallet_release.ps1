param(
    [string]$ApkPath,
    [string]$ApkAnalyzerPath
)

$ErrorActionPreference = 'Stop'

function Assert-WalletRegistrarDex {
    param([AllowEmptyString()][string]$DexCode)

    $className = 'Lcom/google/mlkit/common/internal/CommonComponentRegistrar;'
    $classes = [regex]::Matches($DexCode, '(?m)^\.class[^\r\n]*')
    if ($classes.Count -ne 1 -or
        $classes[0].Value.Trim() -ne ".class public $className") {
        throw 'Wallet release gate: expected the public ML Kit registrar class in DEX.'
    }
    if ($DexCode -notmatch '(?m)^\.implements Lcom/google/firebase/components/ComponentRegistrar;\s*$') {
        throw 'Wallet release gate: ML Kit registrar interface missing in DEX.'
    }

    # Only a complete method declaration counts, never an invoke-direct reference.
    $methods = [regex]::Matches($DexCode,
        '(?ms)^\.method[^\r\n]*\r?\n(?:(?!^\.method\b).)*?^\.end method[ \t]*\r?$')
    foreach ($method in $methods) {
        if ($method.Value -match '^\.method public constructor <init>\(\)V[ \t]*\r?\n') {
            return
        }
    }
    throw 'Wallet release gate: public no-arg ML Kit registrar constructor missing in DEX (R8 reflection regression).'
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $ApkPath -or -not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
        throw 'Wallet release gate: APK file required.'
    }
    if (-not $ApkAnalyzerPath) {
        $sdk = $env:ANDROID_HOME
        if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
        if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android/Sdk' }
        $ApkAnalyzerPath = Join-Path $sdk 'cmdline-tools/latest/bin/apkanalyzer.bat'
    }
    if (-not (Test-Path -LiteralPath $ApkAnalyzerPath -PathType Leaf)) {
        throw 'Wallet release gate: apkanalyzer not found; pass -ApkAnalyzerPath explicitly.'
    }
    $dex = & $ApkAnalyzerPath dex code --class com.google.mlkit.common.internal.CommonComponentRegistrar $ApkPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Wallet release gate: apkanalyzer failed; APK is not verified.'
    }
    Assert-WalletRegistrarDex -DexCode ($dex -join "`n")
    Write-Output 'Wallet release gate PASS: actual APK DEX retains the public ML Kit no-arg constructor.'
}
