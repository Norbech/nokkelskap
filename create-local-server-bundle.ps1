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
    [switch]$NoBrowser,
    [switch]$SkipBootstrap
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# Sjekk om .NET er tilgjengelig ved første oppstart
if (-not $SkipBootstrap) {
    $dotnetAvailable = $false
    try {
        $null = & dotnet --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $dotnetAvailable = $true
        }
    } catch {
        # Ignore
    }

    if (-not $dotnetAvailable) {
        Write-Host "⚠️  .NET Runtime ble ikke funnet" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Starter bootstrap for å laste ned nødvendige avhengigheter..." -ForegroundColor Cyan
        Write-Host ""
        
        $bootstrapScript = Join-Path $root "bootstrap.ps1"
        if (Test-Path $bootstrapScript) {
            & $bootstrapScript
            
            # Sjekk om bootstrap var vellykket
            try {
                $null = & dotnet --version 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host ""
                    Write-Host "Bootstrap fullført, men .NET er ikke tilgjengelig ennå." -ForegroundColor Yellow
                    Write-Host "Start PowerShell på nytt og prøv igjen." -ForegroundColor Yellow
                    exit 1
                }
            } catch {
                Write-Host ""
                Write-Host "Bootstrap fullført, men .NET er ikke tilgjengelig ennå." -ForegroundColor Yellow
                Write-Host "Start PowerShell på nytt og prøv igjen." -ForegroundColor Yellow
                exit 1
            }
        } else {
            Write-Host "✗ bootstrap.ps1 ikke funnet!" -ForegroundColor Red
            Write-Host "Installer .NET 8.0 Runtime manuelt:" -ForegroundColor White
            Write-Host "https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Cyan
            exit 1
        }
    }
}

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

# Bootstrap script for dependency installation
$bootstrapScript = @'
# Bootstrap script - Laster ned og installerer nødvendige avhengigheter
# Denne kjøres automatisk når man starter bundelen første gang

[CmdletBinding()]
param(
    [switch]$SkipDotNetCheck
)

$ErrorActionPreference = "Stop"

Write-Host "=== KeyCabinet Bundle - Bootstrap ===" -ForegroundColor Cyan
Write-Host ""

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$downloadDir = Join-Path $root "downloads"

# Opprett download-katalog
if (-not (Test-Path $downloadDir)) {
    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
}

function Test-DotNetInstalled {
    try {
        $dotnetVersion = & dotnet --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ .NET er installert (versjon: $dotnetVersion)" -ForegroundColor Green
            return $true
        }
    } catch {
        # Ignore
    }
    return $false
}

function Get-DotNetDownloadUrl {
    # .NET 8.0 Runtime (ASP.NET Core) for Windows x64
    # Oppdatert link - sjekk https://dotnet.microsoft.com/download/dotnet/8.0 for nyeste versjon
    return "https://download.visualstudio.microsoft.com/download/pr/6224f00f-08da-4e7f-85b1-00d42c2bb3d3/b775de636b91e023574a0bbc291f705a/dotnet-sdk-8.0.101-win-x64.exe"
}

function Download-File {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$OutputPath
    )

    Write-Host "Laster ned fra: $Url" -ForegroundColor Yellow
    Write-Host "Til: $OutputPath" -ForegroundColor White
    
    try {
        # Bruk Invoke-WebRequest for bedre kompatibilitet
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        
        if (Test-Path $OutputPath) {
            Write-Host "✓ Nedlasting fullført" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "✗ Nedlasting feilet: $_" -ForegroundColor Red
        return $false
    }
    
    return $false
}

function Install-DotNetRuntime {
    Write-Host ""
    Write-Host "=== Installer .NET Runtime ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ".NET Runtime er ikke installert." -ForegroundColor Yellow
    Write-Host "Denne applikasjonen krever .NET 8.0 Runtime for å kjøre." -ForegroundColor White
    Write-Host ""
    
    $install = Read-Host "Vil du laste ned og installere .NET 8.0 SDK nå? (J/N)"
    
    if ($install -ne 'J' -and $install -ne 'j') {
        Write-Host ""
        Write-Host "Installasjon avbrutt." -ForegroundColor Yellow
        Write-Host "Last ned manuelt fra: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor White
        return $false
    }
    
    $installerPath = Join-Path $downloadDir "dotnet-sdk-8.0-installer.exe"
    $downloadUrl = Get-DotNetDownloadUrl
    
    Write-Host ""
    Write-Host "Laster ned .NET 8.0 SDK..." -ForegroundColor Cyan
    
    if (-not (Download-File -Url $downloadUrl -OutputPath $installerPath)) {
        Write-Host ""
        Write-Host "Nedlasting feilet. Last ned manuelt:" -ForegroundColor Red
        Write-Host "https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor White
        return $false
    }
    
    Write-Host ""
    Write-Host "Starter installer..." -ForegroundColor Cyan
    Write-Host "Følg instruksjonene i installasjonsveiviseren." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        # Start installeren og vent til den er ferdig
        $process = Start-Process -FilePath $installerPath -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host ""
            Write-Host "✓ .NET SDK installert" -ForegroundColor Green
            Write-Host ""
            Write-Host "VIKTIG: Du må starte PowerShell på nytt for at endringene skal tre i kraft." -ForegroundColor Yellow
            Write-Host "Lukk dette vinduet og kjør bootstrap.ps1 på nytt." -ForegroundColor Yellow
            Write-Host ""
            return $true
        } else {
            Write-Host "✗ Installasjon feilet med kode: $($process.ExitCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "✗ Kunne ikke starte installer: $_" -ForegroundColor Red
        return $false
    }
}

# Hovedlogikk
Write-Host "Sjekker avhengigheter..." -ForegroundColor Yellow
Write-Host ""

$needsRestart = $false

# Sjekk .NET
if (-not $SkipDotNetCheck) {
    if (-not (Test-DotNetInstalled)) {
        if (Install-DotNetRuntime) {
            $needsRestart = $true
        } else {
            Write-Host ""
            Write-Host "Kan ikke fortsette uten .NET Runtime." -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host "⊘ Hopper over .NET-sjekk (--SkipDotNetCheck)" -ForegroundColor Yellow
}

if ($needsRestart) {
    Write-Host ""
    Write-Host "=== Restart Required ===" -ForegroundColor Yellow
    Write-Host "Start PowerShell på nytt og kjør:" -ForegroundColor White
    Write-Host "  .\bootstrap.ps1" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "✓ Alle avhengigheter er installert!" -ForegroundColor Green
Write-Host ""
Write-Host "Du kan nå kjøre applikasjonen med:" -ForegroundColor White
Write-Host "  .\run.ps1" -ForegroundColor Cyan
Write-Host ""
'@

Set-Content -Path (Join-Path $OutputDir "bootstrap.ps1") -Value $bootstrapScript -Encoding utf8

# START.cmd - Enkel dobbeltklikk-starter
$startCmd = @'
@echo off
REM ====================================================
REM KeyCabinet Server - Start
REM ====================================================
REM Dobbeltklikk på denne filen for å starte serveren
REM ====================================================

echo.
echo ========================================
echo KeyCabinet Server - Starter...
echo ========================================
echo.

REM Kjør PowerShell-script med Bypass execution policy
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"

pause
'@

$stoppCmd = @'
@echo off
REM ====================================================
REM KeyCabinet Server - Stopp
REM ====================================================
REM Dobbeltklikk på denne filen for å stoppe serveren
REM ====================================================

echo.
echo ========================================
echo KeyCabinet Server - Stopper...
echo ========================================
echo.

REM Kjør PowerShell-script med Bypass execution policy
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop.ps1"

pause
'@

$howToStart = @'
╔═══════════════════════════════════════════════════════════════╗
║                 HVORDAN STARTE KEYCABINET SERVER              ║
╚═══════════════════════════════════════════════════════════════╝

📋 FØRSTE GANGS OPPSETT:
═══════════════════════════════════════════════════════════════

1. Kopier hele "local-server"-mappen til din PC
   (Kan plasseres hvor som helst, f.eks. C:\KeyCabinet\)

2. Dobbeltklikk på: START.cmd

3. Første gang:
   - Hvis .NET ikke er installert, vil du få spørsmål
   - Trykk 'J' for å installere automatisk
   - Installer, lukk vinduet, og kjør START.cmd på nytt


🚀 NORMAL BRUK:
═══════════════════════════════════════════════════════════════

▶ Start server:
  → Dobbeltklikk på START.cmd

■ Stopp server:
  → Dobbeltklikk på STOPP.cmd

🌐 Åpne webgrensesnittet:
  → Gå til http://localhost:5000 i nettleseren
  → Eller http://127.0.0.1:5000


⚙️ KONFIGURERING:
═══════════════════════════════════════════════════════════════

📁 Hardware-innstillinger (COM-port):
   agent\appsettings.json
   
   Endre "PortName": "COM3" til din COM-port

📁 Web-innstillinger:
   web\appsettings.json


📊 LOGGFILER:
═══════════════════════════════════════════════════════════════

Finner du i: logs\
  - web.out.log    (Web-server output)
  - web.err.log    (Web-server feil)
  - agent.out.log  (Hardware agent output)
  - agent.err.log  (Hardware agent feil)


🔧 FEILSØKING:
═══════════════════════════════════════════════════════════════

❌ "Ingenting skjer når jeg dobbeltklikker"
   → Bruk START.cmd, ikke run.ps1 direkte

❌ ".NET er ikke installert"
   → Dobbeltklikk START.cmd og følg instruksjonene
   → Eller installer manuelt fra:
     https://dotnet.microsoft.com/download/dotnet/8.0

❌ "Port 5000 er opptatt"
   → Kjør STOPP.cmd først
   → Eller endre port i run.ps1

❌ "Kan ikke finne COM-port"
   → Åpne Enhetsbehandling (Device Manager)
   → Finn COM-porten under "Porter (COM & LPT)"
   → Oppdater agent\appsettings.json


💾 DATABASE:
═══════════════════════════════════════════════════════════════

Lagres automatisk i:
  %APPDATA%\KeyCabinetApp\keycabinet.db

Backup:
  Kopier filen over for sikkerhet


👤 STANDARD INNLOGGING:
═══════════════════════════════════════════════════════════════

Admin-bruker:
  Brukernavn: admin
  Passord: admin123

⚠️ BYTT PASSORD ETTER FØRSTE INNLOGGING!


📞 HJELP:
═══════════════════════════════════════════════════════════════

Se README.md for mer informasjon
'@

Set-Content -Path (Join-Path $OutputDir "START.cmd") -Value $startCmd -Encoding ascii
Set-Content -Path (Join-Path $OutputDir "STOPP.cmd") -Value $stoppCmd -Encoding ascii
Set-Content -Path (Join-Path $OutputDir "HVORDAN-STARTE.txt") -Value $howToStart -Encoding utf8

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

## 🚀 HURTIGSTART:

**Dobbeltklikk på: START.cmd**

Det er alt! Se HVORDAN-STARTE.txt for mer info.

---

## 📁 Innhold:

- `START.cmd` ← **Start serveren (dobbeltklikk)**
- `STOPP.cmd` ← **Stopp serveren (dobbeltklikk)**
- `HVORDAN-STARTE.txt` ← Detaljert brukerveiledning
- `web/` Published KeyCabinetApp.Web
- `agent/` Published KeyCabinetApp.HardwareAgent
- `bootstrap.ps1` Installerer nødvendige avhengigheter (.NET Runtime)
- `run.ps1` PowerShell script (brukes av START.cmd)
- `stop.ps1` PowerShell script (brukes av STOPP.cmd)
- `config/` Reference appsettings files
- `cloudflare/` Cloudflared templates

## Første gangs oppstart:

1. **Dobbeltklikk på START.cmd**
   
2. **Automatisk installasjon:**
   - Scriptet sjekker om .NET Runtime er installert
   - Hvis ikke, laster det ned og installerer .NET 8.0 SDK automatisk
   - Du vil bli bedt om å bekrefte installasjonen
   
3. **Etter installasjon:**
   - Start PowerShell på nytt
   - Dobbeltklikk på START.cmd igjen

## Vanlig bruk:

- **Start:** Dobbeltklikk START.cmd
- **Stopp:** Dobbeltklikk STOPP.cmd
- **Web:** http://localhost:5000

## For avanserte brukere (PowerShell):

```powershell
.\run.ps1              # Start med standardinnstillinger
.\run.ps1 -NoBrowser   # Start uten å åpne nettleser
.\stop.ps1             # Stopp begge tjenester
.\bootstrap.ps1        # Manuell installasjon av avhengigheter
```

## Notater:

- Database: `%APPDATA%\KeyCabinetApp\keycabinet.db`
- Hardware: Rediger `agent/appsettings.json` for COM-port
- Loggfiler: `logs/`
- Downloads: `downloads/` (installasjonsfiler)
'@

Set-Content -Path (Join-Path $OutputDir "README.md") -Value $bundleReadme -Encoding utf8

Write-Host "Bundle created: $OutputDir" -ForegroundColor Green
Write-Host "Next: Copy this folder to the server machine." -ForegroundColor White
