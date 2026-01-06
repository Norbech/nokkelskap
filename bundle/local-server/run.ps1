[CmdletBinding()]
param(
    [string]$Urls = "http://127.0.0.1:5000",
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDir = Join-Path $root ".run"
$logsDir = Join-Path $root "logs"

New-Item -ItemType Directory -Force -Path $runDir,$logsDir | Out-Null

$webPidFile = Join-Path $runDir "web.pid"
$agentPidFile = Join-Path $runDir "agent.pid"

$webOut = Join-Path $logsDir "web.out.log"
$webErr = Join-Path $logsDir "web.err.log"
$agentOut = Join-Path $logsDir "agent.out.log"
$agentErr = Join-Path $logsDir "agent.err.log"

function Stop-PidFileProcess {
    param([Parameter(Mandatory=$true)][string]$PidFile)

    if (-not (Test-Path $PidFile)) { return }

    $pidRaw = (Get-Content -Path $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    if (-not $pidRaw) { Remove-Item -Force -Path $PidFile -ErrorAction SilentlyContinue; return }

    $pidValue = 0
    if (-not [int]::TryParse($pidRaw, [ref]$pidValue)) { Remove-Item -Force -Path $PidFile -ErrorAction SilentlyContinue; return }

    $p = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
    if ($null -ne $p) {
        Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 300
    }

    Remove-Item -Force -Path $PidFile -ErrorAction SilentlyContinue
}

Write-Host "Stopping any previously started instances (bundle)..." -ForegroundColor Yellow
Stop-PidFileProcess -PidFile $webPidFile
Stop-PidFileProcess -PidFile $agentPidFile

function Start-DotNetApp {
    param(
        [Parameter(Mandatory=$true)][string]$AppDir,
        [Parameter(Mandatory=$true)][string]$DllName,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory=$true)][string]$StdOut,
        [Parameter(Mandatory=$true)][string]$StdErr
    )

    $exePath = Join-Path $AppDir ($DllName -replace '\.dll$','.exe')
    $dllPath = Join-Path $AppDir $DllName

    if (Test-Path $exePath) {
        return Start-Process -FilePath $exePath -WorkingDirectory $AppDir -PassThru -ArgumentList $Arguments -RedirectStandardOutput $StdOut -RedirectStandardError $StdErr
    }

    if (Test-Path $dllPath) {
        return Start-Process -FilePath "dotnet" -WorkingDirectory $AppDir -PassThru -ArgumentList @($dllPath) + $Arguments -RedirectStandardOutput $StdOut -RedirectStandardError $StdErr
    }

    throw "Could not find $exePath or $dllPath"
}

$webDir = Join-Path $root "web"
$agentDir = Join-Path $root "agent"

Write-Host "Starting Web..." -ForegroundColor Cyan
$pWeb = Start-DotNetApp -AppDir $webDir -DllName "KeyCabinetApp.Web.dll" -Arguments @("--urls", $Urls) -StdOut $webOut -StdErr $webErr
Set-Content -Path $webPidFile -Value $pWeb.Id -Encoding ascii

Write-Host "Starting HardwareAgent..." -ForegroundColor Cyan
$pAgent = Start-DotNetApp -AppDir $agentDir -DllName "KeyCabinetApp.HardwareAgent.dll" -StdOut $agentOut -StdErr $agentErr
Set-Content -Path $agentPidFile -Value $pAgent.Id -Encoding ascii

Write-Host "Started." -ForegroundColor Green
Write-Host "PIDs: Web=$($pWeb.Id) Agent=$($pAgent.Id)" -ForegroundColor White
Write-Host "Logs: $logsDir" -ForegroundColor White

if (-not $NoBrowser) {
    Start-Process "http://localhost:5000" | Out-Null
}
