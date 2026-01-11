# Simple publish script
$ErrorActionPreference = "Stop"
$dotnet = "C:\Program Files\dotnet\dotnet.exe"

Write-Host "Publishing Web Application..." -ForegroundColor Yellow
& $dotnet publish "src\KeyCabinetApp.Web\KeyCabinetApp.Web.csproj" -c Release -o "publish\web"

Write-Host ""
Write-Host "Publishing Hardware Agent..." -ForegroundColor Yellow  
& $dotnet publish "src\KeyCabinetApp.HardwareAgent\KeyCabinetApp.HardwareAgent.csproj" -c Release -o "publish\agent"

Write-Host ""
Write-Host "Done! Files are in publish\ directory" -ForegroundColor Green
