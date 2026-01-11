$ErrorActionPreference = 'SilentlyContinue'

$webTaskName = 'KeyCabinet Web'
$agentTaskName = 'KeyCabinet Hardware Agent'

Write-Host "== Scheduled Tasks ==" -ForegroundColor Cyan
Get-ScheduledTask -TaskName $webTaskName, $agentTaskName | Select-Object TaskName, State | Format-Table -AutoSize

Write-Host "\n== Processes ==" -ForegroundColor Cyan
Get-Process -Name 'KeyCabinetApp.Web','KeyCabinetApp.HardwareAgent' | Select-Object ProcessName, Id, StartTime | Format-Table -AutoSize

Write-Host "\n== Port 5000 ==" -ForegroundColor Cyan
Get-NetTCPConnection -LocalPort 5000 -State Listen | Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table -AutoSize
