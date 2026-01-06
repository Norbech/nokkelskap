[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$OutputDir = (Join-Path $PSScriptRoot "bundle\\local-server"),

    [ValidateNotNullOrEmpty()]
    [string]$Configuration = "Release",

    [switch]$SelfContained,

    [ValidateNotNullOrEmpty()]
    [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$webProject = Join-Path $repoRoot "src\\KeyCabinetApp.Web\\KeyCabinetApp.Web.csproj"
$agentProject = Join-Path $repoRoot "src\\KeyCabinetApp.HardwareAgent\\KeyCabinetApp.HardwareAgent.csproj"

function Clean-Directory {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

$webOutDir = Join-Path $OutputDir "web"
$agentOutDir = Join-Path $OutputDir "agent"
$cloudflareDir = Join-Path $OutputDir "cloudflare"
$logsDir = Join-Path $OutputDir "logs"
$runDir = Join-Path $OutputDir ".run"
$configDir = Join-Path $OutputDir "config"

Write-Host "=== Create Local Server Bundle ===" -ForegroundColor Cyan
Write-Host "OutputDir: $OutputDir" -ForegroundColor White
Write-Host "Configuration: $Configuration" -ForegroundColor White
Write-Host "SelfContained: $SelfContained" -ForegroundColor White
if ($SelfContained) { Write-Host "Runtime: $Runtime" -ForegroundColor White }

Clean-Directory -Path $OutputDir
New-Item -ItemType Directory -Force -Path $webOutDir,$agentOutDir,$cloudflareDir,$logsDir,$runDir,$configDir | Out-Null

$webPublishArgs = @(
    "publish", $webProject,
    "-c", $Configuration,
    "--output", $webOutDir
)

$agentPublishArgs = @(
    "publish", $agentProject,
    "-c", $Configuration,
    "--output", $agentOutDir
)

if ($SelfContained) {
    $webPublishArgs += @("--runtime", $Runtime, "--self-contained", "true")
    $agentPublishArgs += @("--runtime", $Runtime, "--self-contained", "true")
} else {
    $webPublishArgs += @("--self-contained", "false")
    $agentPublishArgs += @("--self-contained", "false")
}

Write-Host "Publishing Web..." -ForegroundColor Yellow
& dotnet @webPublishArgs
if ($LASTEXITCODE -ne 0) { throw "dotnet publish (Web) failed." }

Write-Host "Publishing HardwareAgent..." -ForegroundColor Yellow
& dotnet @agentPublishArgs
if ($LASTEXITCODE -ne 0) { throw "dotnet publish (HardwareAgent) failed." }

# Copy default configs as reference (publish output already contains appsettings.json)
Copy-Item -Force (Join-Path $repoRoot "src\\KeyCabinetApp.Web\\appsettings.json") (Join-Path $configDir "appsettings.web.json")
Copy-Item -Force (Join-Path $repoRoot "src\\KeyCabinetApp.HardwareAgent\\appsettings.json") (Join-Path $configDir "appsettings.agent.json")
Copy-Item -Force (Join-Path $repoRoot "appsettings.EXAMPLE.json") (Join-Path $configDir "appsettings.EXAMPLE.json")

# Helper scripts
$runScript = @'
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
'@

$stopScript = @'
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDir = Join-Path $root ".run"

$webPidFile = Join-Path $runDir "web.pid"
$agentPidFile = Join-Path $runDir "agent.pid"

function Stop-PidFileProcess {
    param([Parameter(Mandatory=$true)][string]$PidFile)

    if (-not (Test-Path $PidFile)) { return $false }

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

Write-Host "Stopping bundle instances..." -ForegroundColor Yellow
$stoppedWeb = Stop-PidFileProcess -PidFile $webPidFile
$stoppedAgent = Stop-PidFileProcess -PidFile $agentPidFile

if (-not $stoppedWeb -and -not $stoppedAgent) {
    Write-Host "No pid files found (nothing to stop)." -ForegroundColor Gray
} else {
    Write-Host "Stopped." -ForegroundColor Green
}
'@

Set-Content -Path (Join-Path $OutputDir "run.ps1") -Value $runScript -Encoding utf8
Set-Content -Path (Join-Path $OutputDir "stop.ps1") -Value $stopScript -Encoding utf8

# Cloudflare templates
$cloudflareConfig = @'
# Example config for cloudflared (Cloudflare Tunnel)
# Place this file at: %USERPROFILE%\.cloudflared\config.yml
# Replace placeholders:
#   - <TUNNEL_NAME>
#   - <TUNNEL_ID>
#   - <USERNAME>
#   - <HOSTNAME>

tunnel: <TUNNEL_NAME>
credentials-file: C:\Users\<USERNAME>\.cloudflared\<TUNNEL_ID>.json

ingress:
  - hostname: <HOSTNAME>
    service: http://127.0.0.1:5000
  - service: http_status:404
'@

$cloudflareReadme = @'
# Cloudflare Tunnel (quick notes)

This bundle runs the app locally on `http://127.0.0.1:5000`.
Use Cloudflare Tunnel to expose it externally without port forwarding.

Typical commands on the server machine:

1) Install cloudflared (one-time)
   - winget install Cloudflare.cloudflared

2) Login
   - cloudflared tunnel login

3) Create tunnel
   - cloudflared tunnel create keycabinet

4) Route DNS (requires your domain in Cloudflare)
   - cloudflared tunnel route dns keycabinet keys.yourdomain.no

5) Configure
   - Copy `config.yml.example` to `%USERPROFILE%\.cloudflared\config.yml` and fill placeholders.

6) Run
   - cloudflared tunnel run keycabinet

Lock down access in Cloudflare Zero Trust (Access policy) before using in production.
'@

Set-Content -Path (Join-Path $cloudflareDir "config.yml.example") -Value $cloudflareConfig -Encoding utf8
Set-Content -Path (Join-Path $cloudflareDir "README.md") -Value $cloudflareReadme -Encoding utf8

# Bundle README
$bundleReadme = @'
# Local server bundle

Contents:
- `web/` Published KeyCabinetApp.Web
- `agent/` Published KeyCabinetApp.HardwareAgent
- `run.ps1` Starts both (logs in `logs/`)
- `stop.ps1` Stops both
- `config/` Reference appsettings files
- `cloudflare/` Cloudflared templates

Run:
- `./run.ps1` (default binds URLs to `http://127.0.0.1:5000`)
- `./stop.ps1`

Notes:
- The database is created/used at `%APPDATA%\KeyCabinetApp\keycabinet.db`.
- Edit `agent/appsettings.json` on the server to match COM port and hardware settings.
'@

Set-Content -Path (Join-Path $OutputDir "README.md") -Value $bundleReadme -Encoding utf8

Write-Host "Bundle created: $OutputDir" -ForegroundColor Green
Write-Host "Next: Copy this folder to the server machine." -ForegroundColor White
