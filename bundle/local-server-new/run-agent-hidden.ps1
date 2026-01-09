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
