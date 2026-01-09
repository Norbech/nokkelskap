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

$dotnetExe = Resolve-DotNetExe
if (-not $dotnetExe) {
    throw "dotnet.exe not found. Install .NET 8 SDK."
}

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
& $dotnetExe @webPublishArgs
if ($LASTEXITCODE -ne 0) { throw "dotnet publish (Web) failed." }

Write-Host "Publishing HardwareAgent..." -ForegroundColor Yellow
& $dotnetExe @agentPublishArgs
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

# If present, prefer editable configs from .\config\ over published defaults.
$configDir = Join-Path $root "config"
$webConfigSrc = Join-Path $configDir "appsettings.web.json"
$agentConfigSrc = Join-Path $configDir "appsettings.agent.json"
if (Test-Path $webConfigSrc) {
    Copy-Item -Force $webConfigSrc (Join-Path $webDir "appsettings.json")
}
if (Test-Path $agentConfigSrc) {
    Copy-Item -Force $agentConfigSrc (Join-Path $agentDir "appsettings.json")
}

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

# Autostart (Task Scheduler) scripts for running without visible terminal windows
$bundleRunWebHidden = @'
param(
    [string]$Urls = "http://127.0.0.1:5000"
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDir = Join-Path $root '.run'
$logsDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $runDir,$logsDir | Out-Null

$pidFile = Join-Path $runDir 'web.pid'

$existing = Get-Process -Name 'KeyCabinetApp.Web' -ErrorAction SilentlyContinue
if ($existing) {
    Set-Content -Path $pidFile -Value $existing[0].Id -Encoding ascii
    exit 0
}

$webDir = Join-Path $root 'web'
$webExe = Join-Path $webDir 'KeyCabinetApp.Web.exe'
$webDll = Join-Path $webDir 'KeyCabinetApp.Web.dll'

$webOut = Join-Path $logsDir 'web.out.log'
$webErr = Join-Path $logsDir 'web.err.log'

if (Test-Path $webExe) {
    $p = Start-Process -FilePath $webExe -WorkingDirectory $webDir -WindowStyle Hidden -PassThru -ArgumentList @('--urls', $Urls) -RedirectStandardOutput $webOut -RedirectStandardError $webErr
} elseif (Test-Path $webDll) {
    $p = Start-Process -FilePath 'dotnet' -WorkingDirectory $webDir -WindowStyle Hidden -PassThru -ArgumentList @($webDll, '--urls', $Urls) -RedirectStandardOutput $webOut -RedirectStandardError $webErr
} else {
    throw "Could not find $webExe or $webDll"
}

Set-Content -Path $pidFile -Value $p.Id -Encoding ascii
'@

$bundleRunAgentHidden = @'
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDir = Join-Path $root '.run'
$logsDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $runDir,$logsDir | Out-Null

$pidFile = Join-Path $runDir 'agent.pid'

$existing = Get-Process -Name 'KeyCabinetApp.HardwareAgent' -ErrorAction SilentlyContinue
if ($existing) {
    Set-Content -Path $pidFile -Value $existing[0].Id -Encoding ascii
    exit 0
}

$agentDir = Join-Path $root 'agent'
$agentExe = Join-Path $agentDir 'KeyCabinetApp.HardwareAgent.exe'
$agentDll = Join-Path $agentDir 'KeyCabinetApp.HardwareAgent.dll'

$agentOut = Join-Path $logsDir 'agent.out.log'
$agentErr = Join-Path $logsDir 'agent.err.log'

if (Test-Path $agentExe) {
    $p = Start-Process -FilePath $agentExe -WorkingDirectory $agentDir -WindowStyle Hidden -PassThru -RedirectStandardOutput $agentOut -RedirectStandardError $agentErr
} elseif (Test-Path $agentDll) {
    $p = Start-Process -FilePath 'dotnet' -WorkingDirectory $agentDir -WindowStyle Hidden -PassThru -ArgumentList @($agentDll) -RedirectStandardOutput $agentOut -RedirectStandardError $agentErr
} else {
    throw "Could not find $agentExe or $agentDll"
}

Set-Content -Path $pidFile -Value $p.Id -Encoding ascii
'@

$bundleInstallAutostart = @'
param(
    [switch]$RunNow
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Re-launching as Administrator..." -ForegroundColor Yellow
    $argList = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $PSCommandPath)
    )
    if ($RunNow) { $argList += '-RunNow' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ($argList -join ' ')
    exit 0
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$webTaskName = 'KeyCabinet Web'
$agentTaskName = 'KeyCabinet Hardware Agent'

$ps = (Get-Command powershell).Source

$webScript = Join-Path $root 'run-web-hidden.ps1'
$agentScript = Join-Path $root 'run-agent-hidden.ps1'

$webAction = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $webScript" -WorkingDirectory $root
$agentAction = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $agentScript" -WorkingDirectory $root

$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -Hidden

Unregister-ScheduledTask -TaskName $webTaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Unregister-ScheduledTask -TaskName $agentTaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

Register-ScheduledTask -TaskName $webTaskName -Action $webAction -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
Register-ScheduledTask -TaskName $agentTaskName -Action $agentAction -Trigger $trigger -Principal $principal -Settings $settings | Out-Null

Write-Host "Installed autostart tasks:" -ForegroundColor Green
Write-Host "- $webTaskName" -ForegroundColor Green
Write-Host "- $agentTaskName" -ForegroundColor Green

if ($RunNow) {
    schtasks /Run /TN "$webTaskName" | Out-Null
    schtasks /Run /TN "$agentTaskName" | Out-Null
    Write-Host "Started tasks." -ForegroundColor Green
}
'@

$bundleRemoveAutostart = @'
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Re-launching as Administrator..." -ForegroundColor Yellow
    $argList = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $PSCommandPath)
    )
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ($argList -join ' ')
    exit 0
}

$webTaskName = 'KeyCabinet Web'
$agentTaskName = 'KeyCabinet Hardware Agent'

Unregister-ScheduledTask -TaskName $webTaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Unregister-ScheduledTask -TaskName $agentTaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

Write-Host "Removed autostart tasks (if present)." -ForegroundColor Green
'@

$bundleStatusAutostart = @'
$ErrorActionPreference = 'SilentlyContinue'

$webTaskName = 'KeyCabinet Web'
$agentTaskName = 'KeyCabinet Hardware Agent'

Write-Host "== Scheduled Tasks ==" -ForegroundColor Cyan
Get-ScheduledTask -TaskName $webTaskName, $agentTaskName | Select-Object TaskName, State | Format-Table -AutoSize

Write-Host "`n== Processes ==" -ForegroundColor Cyan
Get-Process -Name 'KeyCabinetApp.Web','KeyCabinetApp.HardwareAgent' | Select-Object ProcessName, Id, StartTime | Format-Table -AutoSize

Write-Host "`n== Port 5000 ==" -ForegroundColor Cyan
Get-NetTCPConnection -LocalPort 5000 -State Listen | Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table -AutoSize
'@

Set-Content -Path (Join-Path $OutputDir 'run-web-hidden.ps1') -Value $bundleRunWebHidden -Encoding utf8
Set-Content -Path (Join-Path $OutputDir 'run-agent-hidden.ps1') -Value $bundleRunAgentHidden -Encoding utf8
Set-Content -Path (Join-Path $OutputDir 'install-autostart.ps1') -Value $bundleInstallAutostart -Encoding utf8
Set-Content -Path (Join-Path $OutputDir 'remove-autostart.ps1') -Value $bundleRemoveAutostart -Encoding utf8
Set-Content -Path (Join-Path $OutputDir 'status-autostart.ps1') -Value $bundleStatusAutostart -Encoding utf8

# Bootstrap script for dependency installation
$bootstrapScript = @'
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

function Test-DotNetInstalled {
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

    $dotnetExe = Resolve-DotNetExe
    if (-not $dotnetExe) { return $false }

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
        # Prov forst med WebClient (mer palitelig for store filer)
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        
        if (Test-Path $OutputPath) {
            $fileSize = (Get-Item $OutputPath).Length / 1MB
            Write-Host "[OK] Nedlasting fullfort ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "WebClient feilet, prover Invoke-WebRequest..." -ForegroundColor Yellow
        
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
        # Start installeren og vent til den er ferdig
        $process = Start-Process -FilePath $installerPath -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host ""
            Write-Host "[OK] .NET Hosting Bundle installert" -ForegroundColor Green
            Write-Host ""
            Write-Host "VIKTIG: Du ma starte PowerShell pa nytt for at endringene skal tre i kraft." -ForegroundColor Yellow
            Write-Host "Lukk dette vinduet og kjor bootstrap.ps1 pa nytt." -ForegroundColor Yellow
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
'@

Set-Content -Path (Join-Path $OutputDir "bootstrap.ps1") -Value $bootstrapScript -Encoding ascii

# START.cmd - Enkel dobbeltklikk-starter
$startCmd = @'
@echo off
REM ====================================================
REM KeyCabinet Server - Start
REM ====================================================
REM Dobbeltklikk pa denne filen for a starte serveren
REM ====================================================

echo.
echo ========================================
echo KeyCabinet Server - Starter...
echo ========================================
echo.

REM Kjor PowerShell-script med Bypass execution policy
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"

echo.
echo ========================================
echo SERVEREN KJORER NA I BAKGRUNNEN!
echo ========================================
echo.
echo Web-grensesnitt: http://localhost:5000
echo.
echo For a stoppe serveren: Dobbeltklikk pa STOPP.cmd
echo.
echo Du kan lukke dette vinduet - serveren fortsetter a kjore.
echo.
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

# Hjelpescripts
$fjernBlokkeringCmd = @'
@echo off
REM ====================================================
REM Fjern Windows-blokkering fra alle filer
REM ====================================================

echo.
echo Fjerner Windows-blokkering fra alle filer...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Path '%~dp0' -Recurse | Unblock-File"

echo.
echo Ferdig! Prov a kjore START.cmd na.
echo.
pause
'@

$finnComPortCmd = @'
@echo off
REM ====================================================
REM Finn tilgjengelige COM-porter
REM ====================================================

echo.
echo ========================================
echo Tilgjengelige COM-porter
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"Write-Host 'Serielle porter funnet pa denne PC-en:' -ForegroundColor Cyan; ^
Write-Host ''; ^
Get-WmiObject Win32_SerialPort | Select-Object DeviceID, Description, Status | ^
Format-Table -AutoSize; ^
Write-Host ''; ^
Write-Host 'For a oppdatere agent/appsettings.json:' -ForegroundColor Yellow; ^
Write-Host '1. Apne: agent\appsettings.json' -ForegroundColor White; ^
Write-Host '2. Finn linjen med PortName' -ForegroundColor White; ^
Write-Host '3. Endre til riktig COM-port (f.eks. COM3, COM4, etc.)' -ForegroundColor White; ^
Write-Host ''; ^
Write-Host 'Hvis listen er tom:' -ForegroundColor Yellow; ^
Write-Host '- Koble til USB-til-RS485 adapter' -ForegroundColor White; ^
Write-Host '- Sjekk i Enhetsbehandling (Device Manager) under Porter (COM og LPT)' -ForegroundColor White"

echo.
pause
'@

$sjakkStatusCmd = @'
@echo off
REM ====================================================
REM KeyCabinet Server - Sjekk Status
REM ====================================================

echo.
echo ========================================
echo KeyCabinet Server - Status
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$webPid = Get-Content '.run\web.pid' -ErrorAction SilentlyContinue; ^
$agentPid = Get-Content '.run\agent.pid' -ErrorAction SilentlyContinue; ^
Write-Host 'Web Server:' -ForegroundColor Cyan; ^
if ($webPid) { ^
    $proc = Get-Process -Id $webPid -ErrorAction SilentlyContinue; ^
    if ($proc) { Write-Host '  [KJORER] PID: $webPid' -ForegroundColor Green } ^
    else { Write-Host '  [STOPPET] (PID $webPid finnes ikke)' -ForegroundColor Red } ^
} else { Write-Host '  [IKKE STARTET]' -ForegroundColor Yellow }; ^
Write-Host ''; ^
Write-Host 'Hardware Agent:' -ForegroundColor Cyan; ^
if ($agentPid) { ^
    $proc = Get-Process -Id $agentPid -ErrorAction SilentlyContinue; ^
    if ($proc) { Write-Host '  [KJORER] PID: $agentPid' -ForegroundColor Green } ^
    else { Write-Host '  [STOPPET] (PID $agentPid finnes ikke)' -ForegroundColor Red } ^
} else { Write-Host '  [IKKE STARTET]' -ForegroundColor Yellow }; ^
Write-Host ''; ^
Write-Host 'Siste feil fra web.err.log:' -ForegroundColor Cyan; ^
if (Test-Path 'logs\web.err.log') { ^
    Get-Content 'logs\web.err.log' -Tail 10 | ForEach-Object { Write-Host '  $_' } ^
} else { Write-Host '  Ingen loggfil funnet' -ForegroundColor Gray }; ^
Write-Host ''; ^
Write-Host 'Siste feil fra agent.err.log:' -ForegroundColor Cyan; ^
if (Test-Path 'logs\agent.err.log') { ^
    Get-Content 'logs\agent.err.log' -Tail 10 | ForEach-Object { Write-Host '  $_' } ^
} else { Write-Host '  Ingen loggfil funnet' -ForegroundColor Gray }"

echo.
pause
'@

Set-Content -Path (Join-Path $OutputDir "FJERN-BLOKKERING.cmd") -Value $fjernBlokkeringCmd -Encoding ascii
Set-Content -Path (Join-Path $OutputDir "FINN-COM-PORT.cmd") -Value $finnComPortCmd -Encoding ascii
Set-Content -Path (Join-Path $OutputDir "SJEKK-STATUS.cmd") -Value $sjakkStatusCmd -Encoding ascii

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
