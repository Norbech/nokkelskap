# Publish Script for Key Cabinet Application
# Creates a standalone executable for deployment

[CmdletBinding()]
param(
    [switch]$OpenFolder
)

function Resolve-DotNetExe {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'dotnet\dotnet.exe')
    )

    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }

    try {
        $cmd = Get-Command dotnet -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { return $cmd.Source }
    } catch {
        # Ignore
    }

    return $null
}

$dotnetExe = Resolve-DotNetExe
if (-not $dotnetExe) {
    Write-Host "[FAIL] dotnet.exe not found. Install .NET 8 SDK." -ForegroundColor Red
    exit 1
}

$publishPath = "publish\KeyCabinetApp"

Write-Host "=== Key Cabinet Application Publish Script ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Publishing application for Windows x64..." -ForegroundColor Yellow
Write-Host "Output directory: $publishPath" -ForegroundColor White
Write-Host ""

# Clean previous publish
if (Test-Path $publishPath) {
    Write-Host "Cleaning previous publish..." -ForegroundColor Yellow
    Remove-Item -Path $publishPath -Recurse -Force
}

# Publish
& $dotnetExe publish src\KeyCabinetApp.UI\KeyCabinetApp.UI.csproj `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    --output $publishPath `
    /p:PublishSingleFile=false `
    /p:IncludeNativeLibrariesForSelfExtract=true

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[OK] Publish successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Deployment files are in: $publishPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Copy the entire '$publishPath' folder to your tablet" -ForegroundColor White
    Write-Host "2. Edit appsettings.json to configure COM port and commands" -ForegroundColor White
    Write-Host "3. Run KeyCabinetApp.UI.exe" -ForegroundColor White
    Write-Host ""

    if ($OpenFolder) {
        explorer.exe $publishPath
    }
} else {
    Write-Host "[FAIL] Publish failed" -ForegroundColor Red
    exit 1
}
