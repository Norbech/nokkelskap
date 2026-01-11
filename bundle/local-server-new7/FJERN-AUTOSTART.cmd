@echo off
REM ====================================================
REM KeyCabinet Server - Fjern autostart
REM ====================================================
REM Fjerner Scheduled Tasks.
REM Krever admin (scriptet hever seg selv).
REM ====================================================

echo.
echo ========================================
echo KeyCabinet Server - Fjerner autostart...
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0remove-autostart.ps1"

echo.
echo Ferdig.
echo.
pause
