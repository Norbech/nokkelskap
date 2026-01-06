[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$Configuration = "Debug",

    [ValidateNotNullOrEmpty()]
    [string]$Urls = "http://0.0.0.0:5000",

    [switch]$NoBuild,

    [switch]$NoBrowser,

    [int]$StartupTimeoutSeconds = 20
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$webProject = Join-Path $repoRoot "src\KeyCabinetApp.Web\KeyCabinetApp.Web.csproj"
$agentProject = Join-Path $repoRoot "src\KeyCabinetApp.HardwareAgent\KeyCabinetApp.HardwareAgent.csproj"

$runDir = Join-Path $repoRoot ".run"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$logDir = "C:\temp"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$webPidFile = Join-Path $runDir "web.pid"
$agentPidFile = Join-Path $runDir "agent.pid"

$webOut = Join-Path $logDir "keycabinet-web.out.log"
$webErr = Join-Path $logDir "keycabinet-web.err.log"
$agentOut = Join-Path $logDir "keycabinet-agent.out.log"
$agentErr = Join-Path $logDir "keycabinet-agent.err.log"

function Stop-PidFileProcess {
    param([Parameter(Mandatory=$true)][string]$PidFile)

    if (-not (Test-Path $PidFile)) { return }

    $pidRaw = (Get-Content -Path $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    if (-not $pidRaw) { return }

    $pidValue = 0
    if (-not [int]::TryParse($pidRaw, [ref]$pidValue)) { return }

    $p = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
    if ($null -ne $p) {
        Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 300
    }

    Remove-Item -Force -Path $PidFile -ErrorAction SilentlyContinue
}

Write-Host "Stopping any previously started instances..." -ForegroundColor Yellow
Stop-PidFileProcess -PidFile $webPidFile
Stop-PidFileProcess -PidFile $agentPidFile

# Also stop any running processes by name (covers manual runs outside this script)
Get-Process KeyCabinetApp.Web,KeyCabinetApp.HardwareAgent -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 300

if (-not $NoBuild) {
    Write-Host "Building (Configuration=$Configuration)..." -ForegroundColor Cyan
    dotnet build $repoRoot\KeyCabinetApp.sln -c $Configuration
    if ($LASTEXITCODE -ne 0) { throw "Build failed." }
}

Write-Host "Starting Web (Urls=$Urls)..." -ForegroundColor Cyan
$pWeb = Start-Process -FilePath "dotnet" -WorkingDirectory $repoRoot -PassThru -ArgumentList @(
    "run",
    "--project", $webProject,
    "-c", $Configuration,
    "--no-build",
    "--urls", $Urls
) -RedirectStandardOutput $webOut -RedirectStandardError $webErr

Set-Content -Path $webPidFile -Value $pWeb.Id -Encoding ascii

Write-Host "Starting HardwareAgent..." -ForegroundColor Cyan
$pAgent = Start-Process -FilePath "dotnet" -WorkingDirectory $repoRoot -PassThru -ArgumentList @(
    "run",
    "--project", $agentProject,
    "-c", $Configuration,
    "--no-build"
) -RedirectStandardOutput $agentOut -RedirectStandardError $agentErr

Set-Content -Path $agentPidFile -Value $pAgent.Id -Encoding ascii

function Get-LocalPortFromUrls {
    param([Parameter(Mandatory=$true)][string]$UrlsValue)

    # Grab first URL and try to parse a port
    $first = ($UrlsValue -split ';' | Select-Object -First 1).Trim()
    if (-not $first) { return 5000 }

    try {
        $uri = [Uri]$first
        if ($uri.Port -gt 0) { return $uri.Port }
    } catch {
        # ignore
    }

    # Fallback: parse trailing :PORT
    $m = [regex]::Match($first, ':(\d+)$')
    if ($m.Success) { return [int]$m.Groups[1].Value }

    return 5000
}

$port = Get-LocalPortFromUrls -UrlsValue $Urls

Write-Host "Waiting for Web to listen on localhost:$port (timeout ${StartupTimeoutSeconds}s)..." -ForegroundColor Yellow
$deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
$ready = $false
while ((Get-Date) -lt $deadline) {
    $tnc = Test-NetConnection -ComputerName "localhost" -Port $port -WarningAction SilentlyContinue
    if ($tnc.TcpTestSucceeded) { $ready = $true; break }
    Start-Sleep -Milliseconds 300
}

if (-not $ready) {
    Write-Host "Web did not become reachable in time." -ForegroundColor Red
    Write-Host "Check logs:" -ForegroundColor Yellow
    Write-Host "  $webErr" -ForegroundColor White
    Write-Host "  $agentErr" -ForegroundColor White
    exit 2
}

if (-not $NoBrowser) {
    $browserUrl = "http://localhost:$port"
    Write-Host "Opening browser: $browserUrl" -ForegroundColor Green
    Start-Process $browserUrl | Out-Null
}

Write-Host "Started." -ForegroundColor Green
Write-Host "PIDs: Web=$($pWeb.Id) Agent=$($pAgent.Id)" -ForegroundColor White
Write-Host "Logs:" -ForegroundColor White
Write-Host "  Web:   $webOut" -ForegroundColor White
Write-Host "  Agent: $agentOut" -ForegroundColor White
Write-Host "Stop with: .\stop-local.cmd" -ForegroundColor Yellow
