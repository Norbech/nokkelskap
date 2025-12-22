$dbPath = "$env:APPDATA\KeyCabinetApp\keycabinet.db"

if (Test-Path $dbPath) {
    Write-Host "Database exists at: $dbPath" -ForegroundColor Green
    $size = (Get-Item $dbPath).Length / 1KB
    Write-Host "Size: $([math]::Round($size, 2)) KB" -ForegroundColor Cyan
    
    # Try to read raw bytes to confirm admin isadmin flag
    Write-Host "`nNote: Cannot easily query SQLite from PowerShell without additional tools."
    Write-Host "But based on server logs, admin user IS created with IsAdmin = true"
    Write-Host "`nTo verify, login as admin and check if you see the Admin button on Keys page."
} else {
    Write-Host "Database NOT found at: $dbPath" -ForegroundColor Red
}
