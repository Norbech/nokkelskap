# 🎉 Nøkkelskap System - Klar til bruk!

## ✅ Status: Operativt

### Kjørende tjenester:
- ✅ **Web Server**: http://localhost:5000
- ✅ **Hardware Agent**: Kjører (2 instanser)
- ✅ **Database**: Initialisert med testdata
- ✅ **COM-port**: COM6 (konfigurert og åpnet)

---

## 🔑 Innloggingsinformasjon

### Admin-bruker:
- **URL**: http://localhost:5000
- **Brukernavn**: `admin`
- **Passord**: `admin123`
- **RFID**: `0014571466`

### Test-bruker:
- **Brukernavn**: `testuser`
- **Passord**: `test123`
- **RFID**: Ikke satt (kan legges til)

---

## 📝 Neste steg

### 1. Test RFID-leseren
**⚠️ VIKTIG: HardwareAgent-vinduet må ha fokus når du skanner!**

Det åpne PowerShell-vinduet med grønn tekst "Hardware Agent - Skann RFID-kort her!" 
må være det aktive vinduet når du holder kortet mot leseren.

**Slik tester du:**
1. **Klikk i HardwareAgent-vinduet** (PowerShell med grønn tekst)
2. **Skann et RFID-kort** - nummeret vises i vinduet
3. **Automatisk innlogging** skjer i web-appen

**Enkel test i Notepad:**
1. Åpne Notepad
2. Skann et RFID-kort
3. Noter ID-nummeret som vises

**Legg til RFID til en bruker:**
1. Logg inn som admin i web-appen
2. Gå til brukeradministrasjon
3. Rediger bruker og legg til RFID-nummer
4. **VIKTIG:** Klikk i HardwareAgent-vinduet før du tester
5. Skann kortet - du logger inn automatisk

📖 **Se [RFID_GUIDE.md](RFID_GUIDE.md) for detaljert guide**

### 2. Konfigurer nøkler
**I web-appen (som admin):**
- Se eksisterende nøkler (8 stk er allerede opprettet)
- Rediger navn og beskrivelser
- Aktiver/deaktiver nøkler

**Standard nøkler (slot 1-8):**
1. Ambulanse nøkkel
2. Bil 3 nøkkel  
3. Hovedinngang
4. Lager
5. Kontor
6. Verksted
7. Garasje
8. Reservenøkkel

### 3. Gi brukertilganger
**I web-appen:**
- Admin har allerede tilgang til alle nøkler
- Test-bruker har tilgang til nøkkel 1, 2, 3
- Legg til nye brukere og gi dem tilgang til spesifikke nøkler

### 4. Test hardwarekommunikasjon
**Åpne en nøkkel:**
1. Logg inn (RFID eller brukernavn/passord)
2. Velg en nøkkel du har tilgang til
3. Klikk "Åpne"
4. Systemet sender kommando via RS485 til slot

**Overvåk logging:**
- Web-logger: Se i web-appen
- Serial trace: `C:\temp\serial-trace.log`

---

## 🛠️ Teknisk informasjon

### Database
- **Type**: SQLite
- **Plassering**: `%LOCALAPPDATA%\KeyCabinetApp\keycabinet.db`
- **Viewer**: DB Browser for SQLite (valgfritt)

### Hardware-kommandoer (RS485)
Konfigurasjon i: `src\KeyCabinetApp.HardwareAgent\appsettings.json`

**Format**: AA 01 01 00 00 XX XX 55
- Slot 1: `AA 01 01 00 00 01 01 55`
- Slot 2: `AA 01 01 00 00 02 02 55`
- ...osv.

**Justere kommandoer:**
Hvis nøkkelskapets kontroller bruker et annet format, rediger `SlotCommands` i appsettings.json.

### COM-port
- **Port**: COM6
- **Baud rate**: 9600
- **Data bits**: 8
- **Parity**: None
- **Stop bits**: One

---

## 🔧 Vedlikehold

### Stoppe systemet:
```powershell
cd "C:\Users\andre\Desktop\nøkkelskap\nokkelskap"
.\stop-local.ps1
```

### Starte systemet på nytt:
```powershell
cd "C:\Users\andre\Desktop\nøkkelskap\nokkelskap"
.\start-local.ps1
```

### Sjekke logger:
- Web terminal: Se PowerShell-vinduet med Web Server
- Agent terminal: Se PowerShell-vinduet med Hardware Agent
- Serial trace: `C:\temp\serial-trace.log`

### Backup database:
```powershell
Copy-Item "$env:LOCALAPPDATA\KeyCabinetApp\keycabinet.db" -Destination "C:\backup\keycabinet-backup-$(Get-Date -Format 'yyyy-MM-dd').db"
```

---

## ⚠️ Viktig sikkerhet

1. **Endre admin-passord umiddelbart!**
   - Logg inn som admin
   - Gå til innstillinger/brukeradministrasjon
   - Endre passord fra `admin123` til noe sikkert

2. **Fjern/deaktiver testbruker** hvis ikke nødvendig

3. **Backup databasen regelmessig** - den inneholder all tilgangshistorikk

---

## 📞 Feilsøking

### Problem: Ingen COM-port funnet
**Løsning:**
```powershell
# Sjekk tilgjengelige porter
mode
# eller
Get-WmiObject Win32_SerialPort
```
Oppdater `PortName` i appsettings.json hvis porten endres.

### Problem: Nøkkel åpner ikke
**Sjekk:**
1. Er Hardware Agent kjørende?
2. Er COM-porten åpen? (se agent-loggen)
3. Er kommandoen riktig for ditt nøkkelskap?
4. Sjekk `C:\temp\serial-trace.log` for hva som ble sendt

### Problem: RFID fungerer ikke
**Sjekk:**
1. Test i Notepad først - vises tall?
2. Er RFID-leseren i "keyboard wedge" modus?
3. Er riktig RFID-nummer registrert i databasen?

### Problem: Web-appen laster ikke
**Løsning:**
```powershell
# Sjekk om port 5000 er i bruk
Get-NetTCPConnection -LocalPort 5000

# Restart web server
cd "C:\Users\andre\Desktop\nøkkelskap\nokkelskap\src\KeyCabinetApp.Web"
dotnet run
```

---

## 🎯 Neste utviklingssteg

Når basissystemet fungerer, kan du:

1. **Konfigurere firewall** for ekstern tilgang:
   ```powershell
   .\setup-firewall.ps1
   ```

2. **Bygge produksjonsversjon**:
   ```powershell
   .\publish.ps1
   ```

3. **Sette opp som Windows Service** for automatisk oppstart

4. **Legge til flere slots** (opptil din kontroller støtter)

5. **Integrere med eksterne systemer** via API

---

**Systemet er klart! 🚀**

*Opprettet: 8. januar 2026*
