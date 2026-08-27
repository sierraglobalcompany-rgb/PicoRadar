param(
    [switch]$Graphify,
    [switch]$UiUxProMax,
    [switch]$PlaywrightCli
)

$ErrorActionPreference = 'Stop'

function Require-Command([string]$Name, [string]$Help) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required. $Help"
    }
}

if (-not $Graphify -and -not $UiUxProMax -and -not $PlaywrightCli) {
    Write-Host 'Nothing selected.'
    Write-Host 'Examples:'
    Write-Host '  .\scripts\setup_agent_tooling.ps1 -Graphify'
    Write-Host '  .\scripts\setup_agent_tooling.ps1 -Graphify -UiUxProMax'
    Write-Host '  .\scripts\setup_agent_tooling.ps1 -PlaywrightCli'
    exit 0
}

if ($Graphify) {
    Require-Command 'uv' 'Install uv from its official distribution before continuing.'
    Write-Host 'Installing/updating Graphify locally via PyPI package graphifyy...'
    uv tool install graphifyy
    Write-Host 'Registering Graphify skill with the coding assistant...'
    graphify install
    Write-Host 'Graphify ready. Run /graphify . inside the coding assistant.'
}

if ($UiUxProMax) {
    Require-Command 'npm' 'Install a supported Node.js/npm runtime before continuing.'
    Write-Host 'Installing UI/UX Pro Max CLI...'
    npm install -g uipro-cli
    Write-Host 'Registering UI/UX Pro Max for Codex...'
    uipro init --ai codex
    Write-Host 'UI/UX Pro Max ready. PicoRadar baseline remains the source of truth.'
}

if ($PlaywrightCli) {
    Require-Command 'npm' 'Install a supported Node.js/npm runtime before continuing.'
    Write-Host 'Installing Microsoft Playwright CLI...'
    npm install -g @playwright/cli@latest
    playwright-cli install --skills
    Write-Host 'Playwright CLI ready for web/admin visual QA. It is not the Android native UI gate.'
}

Write-Host 'Done.'
