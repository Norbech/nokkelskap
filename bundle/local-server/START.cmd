@echo off
REM ====================================================
REM KeyCabinet Server - Start
REM ====================================================
REM Dobbeltklikk på denne filen for å starte serveren
REM ====================================================

echo.
echo ========================================
echo KeyCabinet Server - Starter...
echo ========================================
echo.

REM Kjør PowerShell-script med Bypass execution policy
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"

pause
