# Bootstrap script - Laster ned og installerer nodvendige avhengigheter
# Denne kjores automatisk nar man starter bundelen forste gang

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

function Resolve-DotNetExe {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'dotnet\dotnet.exe')
    )

    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }

    try {
        $cmd = Get-Command dotnet -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { return $cmd.Source }
    } catch {
        # Ignore
    }

    return $null
}

function Test-DotNetInstalled {
    $dotnetExe = Resolve-DotNetExe
    if (-not $dotnetExe) { return $false }

    # Sikrer at dotnet-dir ligger i PATH i denne prosessen
    $dotnetDir = Split-Path -Parent $dotnetExe
    if ($dotnetDir -and ($env:PATH -notlike "*${dotnetDir}*")) {
        $env:PATH = "$dotnetDir;$env:PATH"
    }

    try {
        $dotnetVersion = & $dotnetExe --version 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }

        $runtimes = & $dotnetExe --list-runtimes 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $runtimes) { return $false }

        $hasNetCore = ($runtimes | Select-String -SimpleMatch 'Microsoft.NETCore.App 8.').Count -gt 0
        $hasAspNet = ($runtimes | Select-String -SimpleMatch 'Microsoft.AspNetCore.App 8.').Count -gt 0

        if ($hasNetCore -and $hasAspNet) {
            Write-Host "[OK] .NET er installert (versjon: $dotnetVersion)" -ForegroundColor Green
            return $true
        }

        return $false
    } catch {
        return $false
    }
}

function Get-DotNetDownloadUrl {
    # Bruk offisiell release-metadata for å finne siste .NET 8 Hosting Bundle.
    # Dette er mye mer stabilt enn hardkodet VS-download URL som kan bli fjernet.
    $metadataUrl = "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/8.0/releases.json"

    try {
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $raw = (Invoke-WebRequest -UseBasicParsing -Uri $metadataUrl -TimeoutSec 30).Content
        if (-not $raw) { throw "Empty metadata" }

        $json = $raw | ConvertFrom-Json
        if (-not $json -or -not $json.releases -or $json.releases.Count -lt 1) { throw "Invalid metadata schema" }

        $latest = $json.releases[0]
        $files = $latest.'aspnetcore-runtime'.files
        if (-not $files) { throw "Missing aspnetcore-runtime files" }

        $hosting = $files | Where-Object { $_.name -eq 'dotnet-hosting-win.exe' } | Select-Object -First 1
        if (-not $hosting -or -not $hosting.url) { throw "Missing hosting bundle URL" }

        return [string]$hosting.url
    } catch {
        # Fallback: bruk dotnet-siden hvis metadata ikke kan hentes (offline/proxy/blocked).
        return "https://dotnet.microsoft.com/download/dotnet/8.0"
    } finally {
        $ProgressPreference = 'Continue'
    }
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
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Prov forst med WebClient (mer palitelig for store filer)
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        
        if (Test-Path $OutputPath) {
            $fileSize = (Get-Item $OutputPath).Length / 1MB
            Write-Host "[OK] Nedlasting fullfort ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
            return $true
        }
    } catch {
        if (Test-Path $OutputPath) {
            Remove-Item -Force -Path $OutputPath -ErrorAction SilentlyContinue
        }

        Write-Host "WebClient feilet, prover Invoke-WebRequest..." -ForegroundColor Yellow
        
        try {
            # Fallback til Invoke-WebRequest
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -TimeoutSec 600
            $ProgressPreference = 'Continue'
            
            if (Test-Path $OutputPath) {
                $fileSize = (Get-Item $OutputPath).Length / 1MB
                Write-Host "[OK] Nedlasting fullfort ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
                return $true
            }
        } catch {
            if (Test-Path $OutputPath) {
                Remove-Item -Force -Path $OutputPath -ErrorAction SilentlyContinue
            }
            Write-Host "[FEIL] Nedlasting feilet: $_" -ForegroundColor Red
            Write-Host "Feiltype: $($_.Exception.GetType().Name)" -ForegroundColor Red
            return $false
        }
    }
    
    return $false
}

function Install-DotNetRuntime {
    Write-Host ""
    Write-Host "=== Installer .NET Runtime ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ".NET Runtime er ikke installert." -ForegroundColor Yellow
    Write-Host "Denne applikasjonen krever .NET 8.0 Runtime (inkl. ASP.NET Core Runtime) for a kjore." -ForegroundColor White
    Write-Host ""
    
    $install = Read-Host "Vil du laste ned og installere .NET 8.0 Hosting Bundle na? (J/N)"
    
    if ($install -ne 'J' -and $install -ne 'j') {
        Write-Host ""
        Write-Host "Installasjon avbrutt." -ForegroundColor Yellow
        Write-Host "Last ned manuelt fra: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor White
        return $false
    }
    
    $installerPath = Join-Path $downloadDir "dotnet-hosting-8.0-installer.exe"
    $downloadUrl = Get-DotNetDownloadUrl

    # Hvis fallback til dotnet-siden, forklar at brukeren må laste ned manuelt.
    if ($downloadUrl -like "https://dotnet.microsoft.com/*") {
        Write-Host "";
        Write-Host "Kunne ikke finne direkte nedlastningslenke automatisk." -ForegroundColor Yellow
        Write-Host "Last ned og installer .NET 8 Hosting Bundle manuelt fra:" -ForegroundColor White
        Write-Host "$downloadUrl" -ForegroundColor Cyan
        return $false
    }
    
    Write-Host ""
    Write-Host "Laster ned .NET 8.0 Hosting Bundle..." -ForegroundColor Cyan
    Write-Host "Storrelse: ~170 MB" -ForegroundColor Gray
    
    if (-not (Download-File -Url $downloadUrl -OutputPath $installerPath)) {
        Write-Host ""
        Write-Host "Nedlasting feilet. Last ned manuelt:" -ForegroundColor Red
        Write-Host "https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor White
        return $false
    }
    
    Write-Host ""
    Write-Host "Starter installer..." -ForegroundColor Cyan
    Write-Host "Folg instruksjonene i installasjonsveiviseren." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        $isAdmin = $false
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch {
            $isAdmin = $false
        }

        # Start installeren og vent til den er ferdig
        if (-not $isAdmin) {
            Write-Host "Krever administrator-rettigheter (UAC) for a installere .NET." -ForegroundColor Yellow
            $process = Start-Process -FilePath $installerPath -Wait -PassThru -Verb RunAs
        } else {
            $process = Start-Process -FilePath $installerPath -Wait -PassThru
        }
        
        if ($process.ExitCode -eq 0) {
            Write-Host ""
            Write-Host "[OK] .NET Hosting Bundle installert" -ForegroundColor Green
            Write-Host ""
            Write-Host "Hvis serveren fortsatt sier at .NET mangler: lukk terminalen og prov igjen." -ForegroundColor Yellow
            Write-Host ""
            return $true
        } else {
            Write-Host "[FEIL] Installasjon feilet med kode: $($process.ExitCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "[FEIL] Kunne ikke starte installer: $_" -ForegroundColor Red
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
    Write-Host "Start PowerShell pa nytt og kjor:" -ForegroundColor White
    Write-Host "  .\bootstrap.ps1" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "[OK] Alle avhengigheter er installert!" -ForegroundColor Green
Write-Host ""
Write-Host "Du kan na kjore applikasjonen med:" -ForegroundColor White
Write-Host "  .\run.ps1" -ForegroundColor Cyan
Write-Host ""
