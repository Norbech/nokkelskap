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
    # Prov standard dotnet-kommando
    try {
        $dotnetVersion = & dotnet --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] .NET er installert (versjon: $dotnetVersion)" -ForegroundColor Green
            return $true
        }
    } catch {
        # Ignore
    }
    
    # Sjekk vanlige installasjonssteder
    $commonPaths = @(
        "$env:ProgramFiles\dotnet\dotnet.exe",
        "${env:ProgramFiles(x86)}\dotnet\dotnet.exe",
        "$env:LOCALAPPDATA\Microsoft\dotnet\dotnet.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            try {
                $dotnetVersion = & $path --version 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] .NET funnet i: $path" -ForegroundColor Green
                    Write-Host "    Versjon: $dotnetVersion" -ForegroundColor Gray
                    
                    # Legg til i PATH for denne sesjonen
                    $dotnetDir = Split-Path -Parent $path
                    if ($env:PATH -notlike "*$dotnetDir*") {
                        $env:PATH = "$dotnetDir;$env:PATH"
                        Write-Host "[OK] Lagt til i PATH for denne sesjonen" -ForegroundColor Green
                    }
                    return $true
                }
            } catch {
                # Ignore
            }
        }
    }
    
    return $false
}

function Get-DotNetDownloadUrl {
    # .NET 8.0 Runtime for Windows x64
    # Direct link til hosting bundle (inkluderer alt som trengs)
    return "https://download.visualstudio.microsoft.com/download/pr/907765b0-2bf8-494e-93aa-5ef9553c5d68/a9308dc010617e6716c0e6abd53b05ce/dotnet-hosting-8.0.0-win.exe"
}

function Download-File {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$OutputPath
    )

    Write-Host "Laster ned fra: $Url" -ForegroundColor Yellow
    Write-Host "Til: $OutputPath" -ForegroundColor White
    Write-Host "Dette kan ta flere minutter avhengig av internettforbindelsen..." -ForegroundColor Gray
    
    try {
        # Prøv først med WebClient (mer pålitelig for store filer)
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        
        if (Test-Path $OutputPath) {
            $fileSize = (Get-Item $OutputPath).Length / 1MB
            Write-Host "[OK] Nedlasting fullfort ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "WebClient feilet, prøver Invoke-WebRequest..." -ForegroundColor Yellow
        
        try {
            # Fallback til Invoke-WebRequest
            $ProgressPreference = 'SilentlyContinue'
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -TimeoutSec 600
            $ProgressPreference = 'Continue'
            
            if (Test-Path $OutputPath) {
                $fileSize = (Get-Item $OutputPath).Length / 1MB
                Write-Host "[OK] Nedlasting fullfort ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
                return $true
            }
        } catch {
            Write-Host "[FEIL] Nedlasting feilet: $_" -ForegroundColor Red
            Write-Host "Feiltype: $($_.Exception.GetType().Name)" -ForegroundColor Red
            return $false
        }
    }
    
    return $false
}

function Test-WingetAvailable {
    try {
        $null = & winget --version 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Install-DotNetRuntime {
    Write-Host ""
    Write-Host "=== Installer .NET Runtime ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ".NET Runtime er ikke installert." -ForegroundColor Yellow
    Write-Host "Denne applikasjonen krever .NET 8.0 Runtime for a kjore." -ForegroundColor White
    Write-Host ""
    
    # Sjekk om winget er tilgjengelig
    $hasWinget = Test-WingetAvailable
    
    if ($hasWinget) {
        Write-Host "[OK] Windows Package Manager (winget) er tilgjengelig" -ForegroundColor Green
        Write-Host ""
        $install = Read-Host "Vil du installere .NET 8.0 med winget? (J/N)"
        
        if ($install -ne 'J' -and $install -ne 'j') {
            Write-Host ""
            Write-Host "Installasjon avbrutt." -ForegroundColor Yellow
            return $false
        }
        
        Write-Host ""
        Write-Host "Installerer .NET 8.0 SDK via winget..." -ForegroundColor Cyan
        Write-Host "Dette kan ta noen minutter..." -ForegroundColor Gray
        Write-Host ""
        
        try {
            & winget install Microsoft.DotNet.SDK.8 --silent --accept-source-agreements --accept-package-agreements
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host "[OK] .NET 8.0 SDK installert via winget" -ForegroundColor Green
                Write-Host ""
                Write-Host "VIKTIG: Du ma starte PowerShell pa nytt for at endringene skal tre i kraft." -ForegroundColor Yellow
                Write-Host "Lukk dette vinduet og kjor START.cmd pa nytt." -ForegroundColor Yellow
                Write-Host ""
                return $true
            } else {
                Write-Host ""
                Write-Host "[FEIL] Winget-installasjon feilet med kode: $LASTEXITCODE" -ForegroundColor Red
                Write-Host "Prover manuell nedlasting..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host ""
            Write-Host "[FEIL] Winget-installasjon feilet: $_" -ForegroundColor Red
            Write-Host "Prover manuell nedlasting..." -ForegroundColor Yellow
        }
    }
    
    # Fallback til manuell nedlasting
    Write-Host ""
    $install = Read-Host "Vil du laste ned .NET 8.0 manuelt? (J/N)"
    
    if ($install -ne 'J' -and $install -ne 'j') {
        Write-Host ""
        Write-Host "Installasjon avbrutt." -ForegroundColor Yellow
        Write-Host "Last ned manuelt fra: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor White
        return $false
    }
    
    $installerPath = Join-Path $downloadDir "dotnet-hosting-8.0-installer.exe"
    $downloadUrl = Get-DotNetDownloadUrl
    
    Write-Host ""
    Write-Host "Apner nettleseren for manuell nedlasting..." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Instruksjoner:" -ForegroundColor Yellow
    Write-Host "1. Last ned .NET 8.0 SDK eller Runtime fra nettleseren" -ForegroundColor White
    Write-Host "2. Kjor installasjonsfilen som lastes ned" -ForegroundColor White
    Write-Host "3. Nar installasjonen er ferdig, lukk dette vinduet" -ForegroundColor White
    Write-Host "4. Dobbeltklikk pa START.cmd igjen" -ForegroundColor White
    Write-Host ""
    
    try {
        Start-Process "https://dotnet.microsoft.com/download/dotnet/8.0"
        Write-Host "[OK] Nettleser apnet" -ForegroundColor Green
    } catch {
        Write-Host "[!] Kunne ikke apne nettleser automatisk" -ForegroundColor Yellow
        Write-Host "Ga til: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Read-Host "Trykk Enter nar du har installert .NET 8.0"
    
    # Sjekk om .NET na er installert
    if (Test-DotNetInstalled) {
        Write-Host ""
        Write-Host "[OK] .NET er na installert!" -ForegroundColor Green
        Write-Host "Du kan na kjore START.cmd" -ForegroundColor White
        return $true
    } else {
        Write-Host ""
        Write-Host "[!] .NET er fortsatt ikke installert" -ForegroundColor Yellow
        Write-Host "Start PowerShell pa nytt etter installasjon og kjor START.cmd igjen" -ForegroundColor White
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
    Write-Host "[SKIP] Hopper over .NET-sjekk (--SkipDotNetCheck)" -ForegroundColor Yellow
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
Write-Host "[OK] Alle avhengigheter er installert!" -ForegroundColor Green
Write-Host ""
Write-Host "Du kan nå kjøre applikasjonen med:" -ForegroundColor White
Write-Host "  .\run.ps1" -ForegroundColor Cyan
Write-Host ""
