param(
    [string]$Cache = "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1",
    [switch]$CompileAndroid,
    [string]$AndroidJar = "$env:LOCALAPPDATA/Android/sdk/platforms/android-37.0/android.jar"
)
$ErrorActionPreference = 'Stop'
function Jar([string]$group, [string]$name, [string]$version) {
    $found = @(Get-ChildItem -LiteralPath "$Cache/$group/$name/$version" -Recurse -Filter '*.jar')
    if ($found.Count -ne 1) { throw "Expected one cached jar: $name $version" }
    return $found[0].FullName
}
$stdlib = Jar 'org.jetbrains.kotlin' 'kotlin-stdlib' '2.4.0'
$junit = Jar 'junit' 'junit' '4.13.2'
$hamcrest = Jar 'org.hamcrest' 'hamcrest-core' '1.3'
$compiler = @(
    (Jar 'org.jetbrains.kotlin' 'kotlin-compiler-embeddable' '2.4.0'),
    (Jar 'org.jetbrains.kotlin' 'kotlin-build-tools-api' '2.4.0'),
    (Jar 'org.jetbrains.kotlin' 'kotlin-script-runtime' '2.4.0'),
    (Jar 'org.jetbrains.kotlin' 'kotlin-reflect' '1.6.10'),
    (Jar 'org.jetbrains.kotlinx' 'kotlinx-coroutines-core-jvm' '1.8.0'),
    (Jar 'org.jetbrains' 'annotations' '13.0'), $stdlib
) -join [IO.Path]::PathSeparator
$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../../main/kotlin/co/picoradar/app/alerts'))
$files = @(@('AlertRules.kt', 'AlertEngine.kt', 'AlertCodec.kt', 'AlertSession.kt') | ForEach-Object {
    $path = Join-Path $source $_
    if (Test-Path -LiteralPath $path) { $path }
})
$tests = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*Test.kt')
$output = Join-Path ([IO.Path]::GetTempPath()) ('picoradar-alert-tests-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $output | Out-Null
$classpath = @($stdlib, $junit, $hamcrest) -join [IO.Path]::PathSeparator
if ($CompileAndroid) {
    $transforms = [IO.Path]::GetFullPath((Join-Path $Cache '../../9.3.1/transforms'))
    $names = @('fragment-1.8.9-runtime.jar', 'activity-1.9.0-runtime.jar', 'core-1.18.0-runtime.jar',
        'lifecycle-runtime-runtime.jar', 'lifecycle-viewmodel-runtime.jar',
        'lifecycle-viewmodel-savedstate-runtime.jar', 'savedstate-runtime.jar')
    $androidx = @(Get-ChildItem -LiteralPath $transforms -Recurse -Filter '*.jar' |
        Where-Object { $_.Name -in $names } | Group-Object Name | ForEach-Object { $_.Group[0].FullName })
    if ($androidx.Count -ne $names.Count) { throw 'Required AndroidX cached classes missing' }
    $flutter = @(Get-ChildItem -LiteralPath "$Cache/io.flutter/flutter_embedding_debug" -Recurse -Filter '*.jar')[0].FullName
    $classpath = (@($classpath, $AndroidJar, $flutter,
        (Jar 'androidx.lifecycle' 'lifecycle-common-jvm' '2.10.0')) + $androidx) -join [IO.Path]::PathSeparator
    $files = @(Get-ChildItem -LiteralPath $source -Filter '*.kt' | ForEach-Object { $_.FullName })
}
$compilerArgs = @('-cp', $compiler, 'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler', '-no-stdlib', '-no-reflect',
    '-jvm-target', '17', '-classpath', $classpath, '-d', $output) + @($files) + @($tests.FullName)
& java @compilerArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$classes = $tests | ForEach-Object { 'co.picoradar.app.alerts.' + $_.BaseName }
& java -cp "$output$([IO.Path]::PathSeparator)$classpath" org.junit.runner.JUnitCore @classes
exit $LASTEXITCODE
