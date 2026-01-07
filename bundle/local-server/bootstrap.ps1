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
