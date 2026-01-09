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
