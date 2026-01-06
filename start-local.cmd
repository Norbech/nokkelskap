@echo off
setlocal

REM One-click starter for KeyCabinetApp (Web + HardwareAgent)
REM Uses PowerShell with ExecutionPolicy Bypass for convenience.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-local.ps1"

endlocal
