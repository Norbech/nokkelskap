param(
    [switch]$Publish
)

# Ensure we are running elevated (Task registration typically requires admin when using highest run level)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Re-launching as Administrator..." -ForegroundColor Yellow
    $argList = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $PSCommandPath)
    )
    if ($Publish) { $argList += '-Publish' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ($argList -join ' ')
    exit 0
}

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot

# Publish (optional but recommended)
if ($Publish) {
    & (Join-Path $root 'run-web-hidden.ps1') -Publish
    & (Join-Path $root 'run-agent-hidden.ps1') -Publish
}

$webTaskName = 'KeyCabinet Web'
$agentTaskName = 'KeyCabinet Hardware Agent'

$ps = (Get-Command powershell).Source

$webScript = Join-Path $root 'run-web-hidden.ps1'
$agentScript = Join-Path $root 'run-agent-hidden.ps1'

$webAction = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $webScript" -WorkingDirectory $root
$agentAction = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $agentScript" -WorkingDirectory $root

# RFID global keyboard hook requires interactive user session -> AtLogOn
$trigger = New-ScheduledTaskTrigger -AtLogOn

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -Hidden

# Remove existing tasks if present
Unregister-ScheduledTask -TaskName $webTaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Unregister-ScheduledTask -TaskName $agentTaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

Register-ScheduledTask -TaskName $webTaskName -Action $webAction -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
Register-ScheduledTask -TaskName $agentTaskName -Action $agentAction -Trigger $trigger -Principal $principal -Settings $settings | Out-Null

Write-Host "Installed autostart tasks:" -ForegroundColor Green
Write-Host "- $webTaskName" -ForegroundColor Green
Write-Host "- $agentTaskName" -ForegroundColor Green
Write-Host "" 
Write-Host "Run once now (optional):" -ForegroundColor Yellow
Write-Host "  schtasks /Run /TN \"$webTaskName\"" -ForegroundColor Yellow
Write-Host "  schtasks /Run /TN \"$agentTaskName\"" -ForegroundColor Yellow
