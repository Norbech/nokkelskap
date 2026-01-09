# Build and Run Script for Key Cabinet Application
# Run this script from the project root directory

Write-Host "=== Key Cabinet Application Build Script ===" -ForegroundColor Cyan
Write-Host ""

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

# Check .NET SDK
Write-Host "Checking .NET SDK..." -ForegroundColor Yellow
try {
    $dotnetExe = Resolve-DotNetExe
    if (-not $dotnetExe) { throw "dotnet not found" }

    $dotnetDir = Split-Path -Parent $dotnetExe
    if ($dotnetDir -and ($env:PATH -notlike "*${dotnetDir}*")) {
        $env:PATH = "$dotnetDir;$env:PATH"
    }

    $dotnetVersion = & $dotnetExe --version
    Write-Host "[OK] .NET SDK version: $dotnetVersion" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] .NET SDK not found. Please install .NET 8.0 SDK" -ForegroundColor Red
    Write-Host "  Download from: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Yellow
    exit 1
}

# Restore packages
Write-Host ""
Write-Host "Restoring NuGet packages..." -ForegroundColor Yellow
& $dotnetExe restore
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Package restore failed" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Packages restored" -ForegroundColor Green

# Build solution
Write-Host ""
Write-Host "Building solution..." -ForegroundColor Yellow
& $dotnetExe build --configuration Release
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Build failed" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Build successful" -ForegroundColor Green

# Ask if user wants to run
Write-Host ""
$runApp = Read-Host "Do you want to run the application? (Y/N)"
if ($runApp -eq 'Y' -or $runApp -eq 'y') {
    Write-Host ""
    Write-Host "Starting Key Cabinet Application..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
    Write-Host ""
    
    Set-Location "src\KeyCabinetApp.UI"
    & $dotnetExe run --configuration Release
} else {
    Write-Host ""
    Write-Host "Build complete!" -ForegroundColor Green
    Write-Host "To run the application:" -ForegroundColor Yellow
    Write-Host "  cd src\KeyCabinetApp.UI" -ForegroundColor White
    Write-Host "  dotnet run" -ForegroundColor White
}
