# Script for å åpne Windows Firewall for port 5000
# Må kjøres som Administrator

$ruleName = "KeyCabinet Web Server"
$port = 5000

Write-Host "Sjekker om firewall-regel allerede eksisterer..." -ForegroundColor Cyan

$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "Regel '$ruleName' eksisterer allerede." -ForegroundColor Yellow
    Write-Host "Sletter gammel regel..." -ForegroundColor Yellow
    Remove-NetFirewallRule -DisplayName $ruleName
}

Write-Host "Oppretter ny firewall-regel..." -ForegroundColor Cyan

New-NetFirewallRule -DisplayName $ruleName `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort $port `
    -Action Allow `
    -Profile Any `
    -Description "Tillater innkommende tilkoblinger til KeyCabinet web server på port 5000"

Write-Host ""
Write-Host "✅ Firewall-regel opprettet!" -ForegroundColor Green
Write-Host ""
Write-Host "Port $port er nå åpen for innkommende tilkoblinger." -ForegroundColor Green
Write-Host "Serveren vil være tilgjengelig på:" -ForegroundColor Cyan
Write-Host "  - Lokalt: http://localhost:$port" -ForegroundColor White
Write-Host "  - LAN: http://<din-ip-adresse>:$port" -ForegroundColor White
Write-Host "  - Eksternt: http://<ekstern-ip>:$port (krever port forwarding i ruter)" -ForegroundColor White
Write-Host ""
Write-Host "For å finne din lokale IP-adresse, kjør:" -ForegroundColor Cyan
Write-Host "  ipconfig" -ForegroundColor White
Write-Host ""
