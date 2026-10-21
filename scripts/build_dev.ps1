param(
    [string]$FlutterPath = 'flutter',
    [string]$ApkAnalyzerPath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$gate = [Threading.Mutex]::new($false, 'Local\PicoRadarFlutterGate')
$held = $false
Push-Location (Join-Path $root 'mobile')
try {
    try { $held = $gate.WaitOne() }
    catch [Threading.AbandonedMutexException] { $held = $true }
    & $FlutterPath build apk --flavor dev --release --dart-define=APP_ENV=dev --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'The dev APK build failed.' }
    $apk = Join-Path $root 'mobile/build/app/outputs/flutter-apk/app-dev-release.apk'
    & (Join-Path $PSScriptRoot 'verify_wallet_release.ps1') -ApkPath $apk -ApkAnalyzerPath $ApkAnalyzerPath
    Get-FileHash -LiteralPath $apk -Algorithm SHA256
} finally {
    if ($held) { $gate.ReleaseMutex() }
    $gate.Dispose()
    Pop-Location
}
