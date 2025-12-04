# Publish Script for Key Cabinet Application
# Creates a standalone executable for deployment

Write-Host "=== Key Cabinet Application Publish Script ===" -ForegroundColor Cyan
Write-Host ""

$publishPath = "publish\KeyCabinetApp"

Write-Host "Publishing application for Windows x64..." -ForegroundColor Yellow
Write-Host "Output directory: $publishPath" -ForegroundColor White
Write-Host ""

# Clean previous publish
if (Test-Path $publishPath) {
    Write-Host "Cleaning previous publish..." -ForegroundColor Yellow
    Remove-Item -Path $publishPath -Recurse -Force
}

# Publish
dotnet publish src\KeyCabinetApp.UI\KeyCabinetApp.UI.csproj `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    --output $publishPath `
    /p:PublishSingleFile=false `
    /p:IncludeNativeLibrariesForSelfExtract=true

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Publish successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Deployment files are in: $publishPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Copy the entire '$publishPath' folder to your tablet" -ForegroundColor White
    Write-Host "2. Edit appsettings.json to configure COM port and commands" -ForegroundColor White
    Write-Host "3. Run KeyCabinetApp.UI.exe" -ForegroundColor White
    Write-Host ""
    
    $openFolder = Read-Host "Open publish folder? (Y/N)"
    if ($openFolder -eq 'Y' -or $openFolder -eq 'y') {
        explorer.exe $publishPath
    }
} else {
    Write-Host "✗ Publish failed" -ForegroundColor Red
    exit 1
}
