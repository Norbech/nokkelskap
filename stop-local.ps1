[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDir = Join-Path $repoRoot ".run"

$webPidFile = Join-Path $runDir "web.pid"
$agentPidFile = Join-Path $runDir "agent.pid"

function Stop-PidFileProcess {
    param([Parameter(Mandatory=$true)][string]$PidFile)

    if (-not (Test-Path $PidFile)) {
        return $false
    }

    $pidRaw = (Get-Content -Path $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    if (-not $pidRaw) {
        Remove-Item -Force -Path $PidFile -ErrorAction SilentlyContinue
        return $false
    }

    $pidValue = 0
    if (-not [int]::TryParse($pidRaw, [ref]$pidValue)) {
        Remove-Item -Force -Path $PidFile -ErrorAction SilentlyContinue
        return $false
    }

    $p = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
    if ($null -ne $p) {
        Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 300
    }

    Remove-Item -Force -Path $PidFile -ErrorAction SilentlyContinue
    return $true
}

Write-Host "Stopping instances started via start-local..." -ForegroundColor Yellow
$stoppedWeb = Stop-PidFileProcess -PidFile $webPidFile
$stoppedAgent = Stop-PidFileProcess -PidFile $agentPidFile

if (-not $stoppedWeb -and -not $stoppedAgent) {
    Write-Host "No pid files found (nothing to stop)." -ForegroundColor Gray
} else {
    Write-Host "Stopped." -ForegroundColor Green
}
