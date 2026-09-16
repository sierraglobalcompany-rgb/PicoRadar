param(
    [string]$JarRoot = "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1",
    [string]$AndroidJar = "$env:LOCALAPPDATA/Android/sdk/platforms/android-37.0/android.jar"
)
$ErrorActionPreference = 'Stop'
$androidRoot = Split-Path $PSScriptRoot -Parent
$compilerPaths = @('org.jetbrains.kotlin/kotlin-compiler-embeddable/2.4.0',
    'org.jetbrains.kotlin/kotlin-stdlib/2.4.0', 'org.jetbrains.kotlin/kotlin-script-runtime/2.4.0',
    'org.jetbrains.kotlin/kotlin-reflect/1.6.10', 'org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0',
    'org.jetbrains/annotations/23.0.0')
$compilerJars = $compilerPaths | ForEach-Object {
    Get-ChildItem -LiteralPath (Join-Path $JarRoot $_) -Recurse -Filter '*.jar' | Select-Object -ExpandProperty FullName
}
$testJars = @('junit/junit/4.13.2', 'org.hamcrest/hamcrest-core/1.3') | ForEach-Object {
    Get-ChildItem -LiteralPath (Join-Path $JarRoot $_) -Recurse -Filter '*.jar' | Select-Object -ExpandProperty FullName
}
if (-not (Test-Path -LiteralPath $AndroidJar)) { throw 'Android SDK jar missing.' }
$testClasspath = (@($compilerJars) + @($testJars) + @($AndroidJar)) -join ';'
$testOutput = Join-Path $env:TEMP 'PicoRadar-C15-native-unit'
New-Item -ItemType Directory -Path $testOutput -Force | Out-Null
$sources = @('app/src/main/kotlin/co/picoradar/app/wallet/WalletLimits.kt',
    'app/src/main/kotlin/co/picoradar/app/wallet/DocumentPdfService.kt',
    'app/src/main/kotlin/co/picoradar/app/wallet/DocumentPdfClient.kt',
    'app/src/test/kotlin/co/picoradar/app/wallet/WalletLimitsTest.kt') |
    ForEach-Object { Join-Path $androidRoot $_ }
& java -cp ($compilerJars -join ';') org.jetbrains.kotlin.cli.jvm.K2JVMCompiler -no-stdlib -no-reflect -classpath $testClasspath -d $testOutput @sources
if ($LASTEXITCODE -ne 0) { throw 'Native compilation failed.' }
& java -cp ($testOutput + ';' + $testClasspath) org.junit.runner.JUnitCore co.picoradar.app.wallet.WalletLimitsTest
if ($LASTEXITCODE -ne 0) { throw 'Native unit tests failed.' }
