@echo off
REM ====================================================
REM KeyCabinet Server - Stopp
REM ====================================================
REM Dobbeltklikk p?? denne filen for ?? stoppe serveren
REM ====================================================

echo.
echo ========================================
echo KeyCabinet Server - Stopper...
echo ========================================
echo.

REM Kj??r PowerShell-script med Bypass execution policy
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop.ps1"

pause
