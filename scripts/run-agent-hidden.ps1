param(
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$agentProject = Join-Path $root 'src\KeyCabinetApp.HardwareAgent'
$agentPublishDir = Join-Path $root 'publish\agent'
$agentExe = Join-Path $agentPublishDir 'KeyCabinetApp.HardwareAgent.exe'

if ($Publish -or -not (Test-Path $agentExe)) {
    Write-Host "Publishing HardwareAgent..." -ForegroundColor Cyan
    dotnet publish $agentProject -c Release -o $agentPublishDir | Out-Host
}

# Avoid duplicates
$existing = Get-Process -Name 'KeyCabinetApp.HardwareAgent' -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "HardwareAgent already running (PID(s): $($existing.Id -join ', '))" -ForegroundColor Yellow
    exit 0
}

Write-Host "Starting HardwareAgent (hidden): $agentExe" -ForegroundColor Green
Start-Process -FilePath $agentExe -WorkingDirectory $agentPublishDir -WindowStyle Hidden
