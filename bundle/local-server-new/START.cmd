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
