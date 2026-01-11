@echo off
REM ====================================================
REM KeyCabinet Server - Installer autostart
REM ====================================================
REM Lager Scheduled Tasks som starter web + agent ved innlogging.
REM Krever admin (scriptet hever seg selv).
REM ====================================================

echo.
echo ========================================
echo KeyCabinet Server - Installerer autostart...
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-autostart.ps1" -RunNow

echo.
echo Ferdig.
echo.
pause
