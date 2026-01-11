param(
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$webProject = Join-Path $root 'src\KeyCabinetApp.Web'
$webPublishDir = Join-Path $root 'publish\web'
$webExe = Join-Path $webPublishDir 'KeyCabinetApp.Web.exe'

if ($Publish -or -not (Test-Path $webExe)) {
    Write-Host "Publishing Web..." -ForegroundColor Cyan
    dotnet publish $webProject -c Release -o $webPublishDir | Out-Host
}

# Avoid duplicates
$existing = Get-Process -Name 'KeyCabinetApp.Web' -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Web already running (PID(s): $($existing.Id -join ', '))" -ForegroundColor Yellow
    exit 0
}

Write-Host "Starting Web (hidden): $webExe" -ForegroundColor Green
Start-Process -FilePath $webExe -WorkingDirectory $webPublishDir -WindowStyle Hidden
