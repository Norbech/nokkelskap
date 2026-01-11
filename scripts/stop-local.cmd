@echo off
setlocal

REM Stops processes started by start-local.cmd

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop-local.ps1"

endlocal
