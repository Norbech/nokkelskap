[CmdletBinding()]
param(
    [string]$Urls = "http://127.0.0.1:5000",
    [switch]$NoBrowser,
    [switch]$SkipBootstrap
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

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

function Test-RequiredDotNetRuntimes {
    param([Parameter(Mandatory = $true)][string]$DotNetExe)

    try {
        $runtimes = & $DotNetExe --list-runtimes 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $runtimes) { return $false }

        $hasNetCore = ($runtimes | Select-String -SimpleMatch 'Microsoft.NETCore.App 8.').Count -gt 0
        $hasAspNet = ($runtimes | Select-String -SimpleMatch 'Microsoft.AspNetCore.App 8.').Count -gt 0
        return ($hasNetCore -and $hasAspNet)
    } catch {
        return $false
    }
}

# Sjekk om dette er en self-contained bundle (exe-filer finnes)
$webExe = Join-Path $root "web\KeyCabinetApp.Web.exe"
$isSelfContained = Test-Path $webExe

# Bare sjekk etter .NET hvis ikke self-contained
if (-not $isSelfContained -and -not $SkipBootstrap) {
    $dotnetExe = Resolve-DotNetExe
    $dotnetReady = $false

    if ($dotnetExe) {
        # Sikrer at dotnet-dir ligger i PATH i denne prosessen (nyttig for underprosesser)
        $dotnetDir = Split-Path -Parent $dotnetExe
        if ($dotnetDir -and ($env:PATH -notlike "*${dotnetDir}*")) {
            $env:PATH = "$dotnetDir;$env:PATH"
        }

        $dotnetReady = Test-RequiredDotNetRuntimes -DotNetExe $dotnetExe
    }

    if (-not $dotnetReady) {
        Write-Host "[!] .NET Runtime ble ikke funnet" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Starter bootstrap for a laste ned nodvendige avhengigheter..." -ForegroundColor Cyan
        Write-Host ""
        
        $bootstrapScript = Join-Path $root "bootstrap.ps1"
        if (Test-Path $bootstrapScript) {
            & $bootstrapScript
            
            # Sjekk om bootstrap var vellykket
            $dotnetExe2 = Resolve-DotNetExe
            if (-not $dotnetExe2 -or -not (Test-RequiredDotNetRuntimes -DotNetExe $dotnetExe2)) {
                Write-Host "";
                Write-Host "Bootstrap fullfort, men .NET er ikke tilgjengelig enna." -ForegroundColor Yellow
                Write-Host "Lukk terminalen, apne PowerShell pa nytt, og prov igjen." -ForegroundColor Yellow
                exit 1
            }
        } else {
            Write-Host "[FEIL] bootstrap.ps1 ikke funnet!" -ForegroundColor Red
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
        [string]$DotNetExe,
        [string[]]$Arguments,
        [Parameter(Mandatory=$true)][string]$StdOut,
        [Parameter(Mandatory=$true)][string]$StdErr
    )

    $exePath = Join-Path $AppDir ($DllName -replace '\.dll$','.exe')
    $dllPath = Join-Path $AppDir $DllName

    if (Test-Path $exePath) {
        if ($Arguments -and $Arguments.Count -gt 0) {
            return Start-Process -FilePath $exePath -WorkingDirectory $AppDir -PassThru -ArgumentList $Arguments -RedirectStandardOutput $StdOut -RedirectStandardError $StdErr
        } else {
            return Start-Process -FilePath $exePath -WorkingDirectory $AppDir -PassThru -RedirectStandardOutput $StdOut -RedirectStandardError $StdErr
        }
    }

    if (Test-Path $dllPath) {
        if (-not $DotNetExe) {
            $DotNetExe = Resolve-DotNetExe
        }
        if (-not $DotNetExe) {
            throw "dotnet.exe not found. Install .NET 8 (Hosting Bundle) or rebuild bundle as self-contained."
        }

        if ($Arguments -and $Arguments.Count -gt 0) {
            $allArgs = @($dllPath) + $Arguments
            return Start-Process -FilePath $DotNetExe -WorkingDirectory $AppDir -PassThru -ArgumentList $allArgs -RedirectStandardOutput $StdOut -RedirectStandardError $StdErr
        } else {
            return Start-Process -FilePath $DotNetExe -WorkingDirectory $AppDir -PassThru -ArgumentList @($dllPath) -RedirectStandardOutput $StdOut -RedirectStandardError $StdErr
        }
    }

    throw "Could not find $exePath or $dllPath"
}

$webDir = Join-Path $root "web"
$agentDir = Join-Path $root "agent"

Write-Host "Starting Web..." -ForegroundColor Cyan
$dotnetExeForRun = if ($isSelfContained) { $null } else { Resolve-DotNetExe }
$pWeb = Start-DotNetApp -AppDir $webDir -DllName "KeyCabinetApp.Web.dll" -DotNetExe $dotnetExeForRun -Arguments @("--urls", $Urls) -StdOut $webOut -StdErr $webErr
Set-Content -Path $webPidFile -Value $pWeb.Id -Encoding ascii

Write-Host "Starting HardwareAgent..." -ForegroundColor Cyan
$pAgent = Start-DotNetApp -AppDir $agentDir -DllName "KeyCabinetApp.HardwareAgent.dll" -DotNetExe $dotnetExeForRun -StdOut $agentOut -StdErr $agentErr
Set-Content -Path $agentPidFile -Value $pAgent.Id -Encoding ascii

Write-Host "Started." -ForegroundColor Green
Write-Host "PIDs: Web=$($pWeb.Id) Agent=$($pAgent.Id)" -ForegroundColor White
Write-Host "Logs: $logsDir" -ForegroundColor White

if (-not $NoBrowser) {
    Start-Process "http://localhost:5000" | Out-Null
}
