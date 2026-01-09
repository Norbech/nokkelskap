@echo off
REM ====================================================
REM Fjern Windows-blokkering fra alle filer
REM ====================================================

echo.
echo Fjerner Windows-blokkering fra alle filer...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Path '%~dp0' -Recurse | Unblock-File"

echo.
echo Ferdig! Prov a kjore START.cmd na.
echo.
pause
