[CmdletBinding()]
param(
    [string]$IsccPath = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    [switch]$SelfContained = $true,
    [string]$Runtime = 'win-x64'
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$iss = Join-Path $root 'installer\KeyCabinetBundle.iss'

if (-not (Test-Path $iss)) {
    throw "Missing Inno Setup script: $iss"
}

if (-not (Test-Path $IsccPath)) {
    Write-Host "ISCC.exe not found at: $IsccPath" -ForegroundColor Yellow
    Write-Host "Install Inno Setup 6, or pass -IsccPath to this script." -ForegroundColor Yellow
    Write-Host "Download: https://jrsoftware.org/isdl.php" -ForegroundColor Cyan
    exit 2
}

# Ensure bundle is up-to-date
Write-Host "Creating/updating bundle/local-server..." -ForegroundColor Cyan
if ($SelfContained) {
    & (Join-Path $root 'create-local-server-bundle.ps1') -OutputDir (Join-Path $root 'bundle\local-server') -Configuration Release -SelfContained -Runtime $Runtime
} else {
    & (Join-Path $root 'create-local-server-bundle.ps1') -OutputDir (Join-Path $root 'bundle\local-server') -Configuration Release
}

Write-Host "Building installer..." -ForegroundColor Cyan
& $IsccPath $iss

Write-Host "Done. Output is in: $(Join-Path $root 'dist')" -ForegroundColor Green
