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
