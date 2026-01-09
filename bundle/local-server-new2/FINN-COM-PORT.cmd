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
