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
