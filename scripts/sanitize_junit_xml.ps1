param(
    [Parameter(Mandatory = $true)]
    [string] $InputPath,
    [Parameter(Mandatory = $true)]
    [string] $OutputPath,
    [string] $WorkspacePath
)

$ErrorActionPreference = 'Stop'
$inputFile = (Resolve-Path -LiteralPath $InputPath).Path
$workspace = if ($WorkspacePath) {
    [System.IO.Path]::GetFullPath($WorkspacePath).TrimEnd('\', '/')
} else {
    (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.TrimEnd('\', '/')
}

$xmlText = [System.IO.File]::ReadAllText($inputFile)
foreach ($candidate in @($workspace, $workspace.Replace('\', '/'))) {
    $xmlText = $xmlText.Replace($candidate, '[B06_WORKTREE]')
}

$outputFile = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $outputFile
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
[System.IO.File]::WriteAllText($outputFile, $xmlText, [System.Text.UTF8Encoding]::new($false))

$settings = [System.Xml.XmlReaderSettings]::new()
$settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
$reader = [System.Xml.XmlReader]::Create($outputFile, $settings)
try {
    while ($reader.Read()) {}
} finally {
    $reader.Dispose()
}

Write-Output "PASS: sanitized JUnit XML is well-formed: $outputFile"
