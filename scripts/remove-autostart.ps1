$ErrorActionPreference = 'Stop'

$webTaskName = 'KeyCabinet Web'
$agentTaskName = 'KeyCabinet Hardware Agent'

Unregister-ScheduledTask -TaskName $webTaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Unregister-ScheduledTask -TaskName $agentTaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

Write-Host "Removed autostart tasks (if they existed)." -ForegroundColor Green
