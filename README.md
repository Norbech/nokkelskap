# Nøkkelskap Kontrollsystem

Et moderne kontrollsystem for elektronisk nøkkelskap med RFID-autentisering, RS485-kommunikasjon og web-basert grensesnitt.

## 🎯 Oversikt

Dette systemet tilbyr:
- **Dobbelt RFID-autentisering**: Primær innloggingsmetode ved bruk av RFID-kort
- **Passord som reserve**: Brukernavn/passord-autentisering når RFID ikke er tilgjengelig
- **Nøkkelkontroll**: Åpne individuelle nøkkelplasser via RS485 seriell kommunikasjon
- **Tilgangssystem**: Brukerbasert tilgangskontroll for spesifikke nøkler
- **Omfattende logging**: Alle handlinger logges til SQLite-database med full revisjonsspor
- **To brukergrensesnitt**:
  - **Web-app (Blazor)**: Moderne, responsiv web-app tilgjengelig fra nettleser
  - **WPF Desktop**: Tradisjonell Windows-applikasjon for nettbrett
- **Hardware Agent**: Separat tjeneste for RS485-kommunikasjon med sanntids-oppdateringer
- **SignalR**: Sanntidskommunikasjon mellom web-app og hardware agent

## 📋 Maskinvarekrav

- **Server/PC**: Windows 10/11 eller Windows Server for å kjøre web-applikasjonen
- **Klient**: Enhver moderne nettleser (Chrome, Edge, Firefox, Safari)
- **USB-til-RS485 Adapter**: Vises som en COM-port i Windows
- **Elektronisk Kontroller**: 
  - Terminalblokk: GND, 485 B, 485 A, +12V
  - RS485-linjer koblet til adapter
  - 12V strømforsyning
  - Flatbåndkabler til nøkkellåser/reléer/sensorer
- **RFID-leser**: USB keyboard wedge eller HID-enhet (valgfritt, kun for WPF-app)

## 🏗️ Arkitektur

```
KeyCabinetApp/
├── src/
│   ├── KeyCabinetApp.Core/          # Domenemodeller & grensesnitt
│   ├── KeyCabinetApp.Application/   # Forretningslogikk & tjenester
│   ├── KeyCabinetApp.Infrastructure/# Database, Serial, SignalR implementasjoner
│   ├── KeyCabinetApp.Web/           # Blazor Server web-applikasjon (ANBEFALT)
│   ├── KeyCabinetApp.HardwareAgent/ # Background service for RS485-kommunikasjon
│   └── KeyCabinetApp.UI/            # WPF desktop-app (legacy)
├── appsettings.json                 # Global konfigurasjon
├── build.ps1                        # Byggescript
├── publish.ps1                      # Publiseringscript
└── README.md
```

**Teknologistakk:**
- .NET 8.0 (LTS)
- Blazor Server for moderne web UI
- SignalR for sanntidskommunikasjon
- Entity Framework Core + SQLite
- BCrypt.Net for passord-hashing
- System.IO.Ports for RS485-kommunikasjon
- Background Services for hardware-integrasjon

## 🚀 Kom i gang

### Forutsetninger

1. Installer [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
2. Installer [Visual Studio Code](https://code.visualstudio.com/) med C#-utvidelse
3. Verifiser installasjonen:
   ```powershell
   dotnet --version
   ```

### Bygg applikasjonen

1. Åpne terminal i prosjektets rotkatalog
2. Gjenopprett avhengigheter og bygg:
   ```powershell
   dotnet restore
   dotnet build
   ```

### Kjør applikasjonen

**Web-applikasjon (Anbefalt):**

1. Start web-serveren:
   ```powershell
   cd src\KeyCabinetApp.Web
   dotnet run
   ```

2. Åpne nettleser og gå til: **http://localhost:5000**

3. (Valgfritt) Start hardware agent for RS485-kommunikasjon:
   ```powershell
   cd src\KeyCabinetApp.HardwareAgent
   dotnet run
   ```

**WPF Desktop-app (Legacy):**

```powershell
cd src\KeyCabinetApp.UI
dotnet run
```

**Produksjonsbygg:**

Bruk det inkluderte PowerShell-scriptet:
```powershell
.\build.ps1
```

Dette bygger begge applikasjoner og plasserer output i `publish/` mappen.

## ⚙️ Konfigurasjon

### Web-applikasjon konfigurasjon

Rediger `src\KeyCabinetApp.Web\appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=keycabinet.db"
  },
  "Urls": "http://0.0.0.0:5000",
  "SignalR": {
    "HardwareAgentUrl": "http://localhost:5001/hardwarehub"
  }
}
```

### Hardware Agent konfigurasjon

Rediger `src\KeyCabinetApp.HardwareAgent\appsettings.json`:

```json
{
  "SerialCommunication": {
    "PortName": "COM3",          // Endre til din COM-port
    "BaudRate": 9600,            // Tilpass til styringskortets innstillinger
    "DataBits": 8,
    "Parity": "None",            // Alternativer: None, Odd, Even, Mark, Space
    "StopBits": "One",           // Alternativer: None, One, Two, OnePointFive
    "ReadTimeout": 1000,
    "WriteTimeout": 1000,
    "SlotCommands": {
      "1": "01 05 00 01 FF 00 DD FA",  // Hex-kommando for slot 1
      "2": "01 05 00 02 FF 00 2D FA",  // Hex-kommando for slot 2
      "3": "01 05 00 03 FF 00 7C 3A",  // osv...
      "4": "01 05 00 04 FF 00 CD FB",
      "5": "01 05 00 05 FF 00 9C 3B"
    },
    "StatusCommands": {
      // Valgfritt: Legg til statusforespørsler hvis maskinvaren støtter det
      // "1": "01 03 00 01 00 01 D5 CA"
    }
  }
}
```

**Finne din COM-port:**
```powershell
Get-WmiObject Win32_SerialPort | Select-Object DeviceID,Description
```

Eller bruk Enhetsbehandling → Porter (COM og LPT)

**Bestemme kommandoer:**

Eksempelkommandoene ovenfor bruker Modbus RTU-format. Du må:

1. **Sjekk styringskortets dokumentasjon** for nøyaktig protokoll
2. Vanlige protokoller:
   - Modbus RTU
   - Egendefinert binær protokoll
   - ASCII-baserte kommandoer

3. **Eksempel Modbus RTU kommandofordeling:**
   - `01` = Enhetadresse
   - `05` = Funksjonskode (Write Single Coil)
   - `00 01` = Registeradresse
   - `FF 00` = Verdi (PÅ)
   - `DD FA` = CRC sjekksum

4. **Teste kommandoer:**
   - Bruk et seriellport-terminalprogram (f.eks. Termite, RealTerm)
   - Koble til COM-porten
   - Send testkommandoer og observer styringskortets oppførsel
   - Notér vellykkede kommandosekvenser

5. **Oppdater `SlotCommands`** med dine fungerende hex-strenger

### SignalR og Hardware Agent

Web-applikasjonen kommuniserer med Hardware Agent via SignalR for sanntids-oppdateringer:

**Web App → Hardware Agent:**
- Nøkkelåpning-kommandoer sendes via SignalR
- Hardware Agent utfører RS485-kommunikasjon
- Statusoppdateringer sendes tilbake til web-app

**Konfigurasjon:**

I `KeyCabinetApp.Web\appsettings.json`:
```json
"SignalR": {
  "HardwareAgentUrl": "http://localhost:5001/hardwarehub"
}
```

I `KeyCabinetApp.HardwareAgent\appsettings.json`:
```json
"Urls": "http://localhost:5001"
```

**Sikkerhet:**
For produksjon, bruk HTTPS og tilgangskontroll:
```json
"Urls": "https://localhost:5001"
```

### RFID-autentisering (Web-app)

Web-applikasjonen støtter **RFID-autentisering direkte i nettleseren**:

**Oppsett:**
1. Bruk RFID-leser i keyboard wedge-modus
2. På login-siden, fokuser RFID-feltet
3. Skann RFID-kortet - applikasjonen logger automatisk inn

**Alternativ metode:**
- Klikk "LOGG INN MED BRUKERNAVN" for passordautentisering

**WPF Desktop-app:**

For WPF-appen gjelder samme oppsett med keyboard wedge RFID-lesere:

**Konfigurasjon:**
- Ingen ekstra programvarekonfigurasjon nødvendig
- Leseren skal sende kort-ID etterfulgt av Enter-tasten
- Typisk kortformat: numerisk eller alfanumerisk streng

**Testing:**
1. Åpne Notisblokk
2. Skann et RFID-kort
3. Du skal se kort-ID-en dukke opp som tekst
4. Notér kort-ID-en for brukerregistrering

## 👥 Brukeradministrasjon

### Initial admin-konto

Applikasjonen oppretter en standard admin-konto ved første kjøring:

- **Brukernavn:** `admin`
- **Passord:** `admin123`
- **⚠️ ENDRE DETTE PASSORDET UMIDDELBART VIA ADMIN-PANELET!**

### Web-app Admin-panel

Web-applikasjonen har et komplett admin-panel tilgjengelig på `/admin`:

**Funksjoner:**
- **Brukeradministrasjon**: Opprett, rediger og slett brukere
- **Nøkkeladministrasjon**: Administrer nøkler og nøkkelplasser
- **Tilgangskontroll**: Tildel og fjern nøkkeltilgang for brukere
- **Logg**: Se alle hendelser og aktivitet

**Tilgang:**
Kun brukere med `IsAdmin = true` kan få tilgang til admin-panelet.

### Testbruker

En testbruker opprettes også:
- **Brukernavn:** `testuser`
- **Passord:** `test123`
- **RFID:** `1234567890` (erstatt med faktisk kort-ID)

### Legge til nye brukere

**Via Web Admin-panel (Anbefalt):**

1. Logg inn som admin på web-appen
2. Klikk "⚙️ Admin" i toppmeny
3. Gå til "Brukere"-fanen
4. Klikk "Legg til bruker"
5. Fyll inn brukerdetaljer (navn, brukernavn, passord, RFID)
6. Marker som admin hvis nødvendig
7. Klikk "Opprett"

**Via database (Avansert):**

1. Installer [DB Browser for SQLite](https://sqlitebrowser.org/)
2. Åpne databasefilen: `keycabinet.db` (i web-app mappen)
3. Legg til i `Users`-tabellen (passord må være BCrypt-hashet)

**Programmatisk:**

```csharp
var authService = serviceProvider.GetRequiredService<AuthenticationService>();
var newUser = await authService.CreateUserAsync(
    name: "Ola Nordmann",
    username: "ola.nordmann",
    password: "SikkertPassord123",
    rfidTag: "9876543210",  // Valgfritt
    isAdmin: false
);
```

### Tildele nøkkeltilgang

**Via Web Admin-panel (Anbefalt):**

1. Logg inn som admin
2. Gå til "Admin" → "Tilgangskontroll"
3. Velg bruker
4. Marker nøklene brukeren skal ha tilgang til
5. Klikk "Lagre"

**Via database:**

```sql
INSERT INTO UserKeyAccess (UserId, KeyId, GrantedAt)
VALUES (2, 1, datetime('now'));
```

## 🔑 Nøkkeladministrasjon

### Legge til nøkler

**Via Web Admin-panel (Anbefalt):**

1. Logg inn som admin
2. Gå til "Admin" → "Nøkler"
3. Klikk "Legg til nøkkel"
4. Fyll inn nøkkeldetaljer:
   - **Slot-ID**: Fysisk slot-nummer (må matche SlotCommands-konfigurasjon!)
   - **Navn**: Beskrivende navn
   - **Beskrivelse**: Valgfri ekstra info
5. Klikk "Opprett"

**Via database:**

```sql
INSERT INTO Keys (SlotId, Name, Description, IsActive, CreatedAt)
VALUES (6, 'Garasje nøkkel', 'Nøkkel til garasjen', 1, datetime('now'));
```

**Viktig:** `SlotId` må matche slot-numrene i din `SlotCommands`-konfigurasjon!

### Eksempel nøkler (opprettet av Seeder)

Applikasjonen oppretter 5 eksempel nøkler:
1. **Slot 1**: Ambulanse nøkkel
2. **Slot 2**: Bil 3 nøkkel
3. **Slot 3**: Hovedinngang
4. **Slot 4**: Lager
5. **Slot 5**: Kontor

Oppdater disse i admin-panelet eller databasen for å matche dine faktiske nøkler.

## 📊 Logging og revisjon

### Hendelseslogging

Alle handlinger blir automatisk logget til databasen med full revisjonsspor:

- Innloggingsforsøk (vellykkede og mislykkede)
- Nøkkelåpninger med bruker- og tidsstempel
- Admin-handlinger (opprettelse/sletting av brukere, nøkler)
- Tilgangsendringer
- Systemhendelser og feil

### Vise logger

**Via Web Admin-panel:**

1. Logg inn som admin
2. Gå til "Admin" → "Logger"
3. Se alle hendelser med filtrering:
   - Filtrer etter dato
   - Filtrer etter bruker
   - Filtrer etter hendelsestype
   - Søk i detaljer

**Via database:**

```sql
SELECT * FROM Events 
WHERE Timestamp > datetime('now', '-7 days')
ORDER BY Timestamp DESC;
```

### Loggplassering

- **Database:** `keycabinet.db` (i web-app mappen)
- **Konsollutskrift:** Synlig når applikasjonen kjøres fra terminal

### Loggoppbevaring

Logger beholdes permanent. For å rydde gamle logger (via admin-panel eller database):
Write-Host "Melding: $($response.message)"
```

### Eksempel: C# klient

```csharp
using System.Net.Http.Json;

var client = new HttpClient();
var request = new
{
    username = "dispatcher",
    password = "SikkertPassord123",
    slotId = 1
};

var response = await client.PostAsJsonAsync(
    "http://192.168.1.50:5000/api/open", 
    request);

var result = await response.Content.ReadFromJsonAsync<RemoteOpenResponse>();
Console.WriteLine($"Suksess: {result.Success}, Melding: {result.Message}");
```

## 📊 Logging og revisjon

### Hendelseslogging

Alle handlinger blir automatisk logget til databasen:

- Innloggingsforsøk (vellykkede og mislykkede)
- Nøkkelåpninger (lokale og eksterne)
- Konfigurasjonsendringer
- Feil og unntak

### Vise logger

1. Klikk "**Logg**" i topplinjen (krever innlogging)
2. Filtrer etter datoområde
3. Eksporter til CSV for ekstern analyse

### Loggplassering

- **Database:** `%APPDATA%\KeyCabinetApp\keycabinet.db`
- **Applikasjonslogger:** Synlige i Debug-vinduet under utvikling

### Loggoppbevaring

Logger beholdes på ubestemt tid. For å rydde gamle logger:

```sql
DELETE FROM Events WHERE Timestamp < date('now', '-90 days');
```

## 🖥️ Produksjonsoppsett

### Web-applikasjon som Windows Service

For å kjøre web-appen som en Windows Service:

1. Bygg applikasjonen:
   ```powershell
   .\publish.ps1
   ```

2. Installer som Windows Service:
   ```powershell
   sc.exe create "KeyCabinetWebApp" binPath="C:\Path\To\KeyCabinetApp.Web.exe"
   sc.exe start "KeyCabinetWebApp"
   ```

3. Konfigurer oppstart:
   ```powershell
   sc.exe config "KeyCabinetWebApp" start=auto
   ```

### Hardware Agent som Windows Service

Samme fremgangsmåte for Hardware Agent:

```powershell
sc.exe create "KeyCabinetHardwareAgent" binPath="C:\Path\To\KeyCabinetApp.HardwareAgent.exe"
sc.exe config "KeyCabinetHardwareAgent" start=auto
sc.exe start "KeyCabinetHardwareAgent"
```

### Reverse Proxy (Valgfritt)

For produksjon med HTTPS, bruk IIS eller nginx som reverse proxy:

**IIS ARR (Application Request Routing):**
1. Installer IIS og ARR
2. Konfigurer URL Rewrite for å videresende til http://localhost:5000
3. Legg til SSL-sertifikat

### Nettverkstilgang

Åpne brannmur for ekstern tilgang:
```powershell
New-NetFirewallRule -DisplayName "KeyCabinet Web" `
    -Direction Inbound -LocalPort 5000 -Protocol TCP -Action Allow

New-NetFirewallRule -DisplayName "KeyCabinet Hardware Agent" `
    -Direction Inbound -LocalPort 5001 -Protocol TCP -Action Allow
```

### Kioskmodus (Nettbrett/Touch-skjerm)

**For WPF Desktop-app:**

1. Opprett snarvei til `KeyCabinetApp.UI.exe`
2. Kopier til oppstartsmappen:
   ```
   %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
   ```

**For Web-app (Fullskjerm-nettleser):**

1. Opprett `.bat`-fil:
   ```batch
   @echo off
   start msedge --kiosk "http://localhost:5000" --edge-kiosk-type=fullscreen
   ```

2. Kopier til oppstartsmappen

**Windows-konfigurasjon:**

```powershell
# Deaktiver hvilemodus
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0

# Auto-innlogging (valgfritt)
# Win + R → netplwiz
# Fjern "Brukere må oppgi brukernavn og passord"
```

## 🔧 Feilsøking

### Web-applikasjon starter ikke

**Problem:** Kan ikke koble til http://localhost:5000

**Løsninger:**
1. Sjekk at port 5000 ikke er i bruk:
   ```powershell
   netstat -ano | findstr :5000
   ```
2. Verifiser `appsettings.json` konfigurasjon
3. Sjekk brannmurregler
4. Se etter feil i terminalen når du starter appen

### Hardware Agent kobler ikke til

**Problem:** "Panel frakoblet" vises i web-appen

**Løsninger:**
1. Sjekk at Hardware Agent kjører
2. Verifiser SignalR URL-konfigurasjon i begge apper
3. Sjekk nettverkstilkobling mellom web-app og agent
4. Se etter feil i Hardware Agent terminal-output

### Seriellport-problemer

**Problem:** "Could not connect to serial port"

**Løsninger:**
1. Verifiser COM-port i Enhetsbehandling
2. Sjekk at `appsettings.json` PortName stemmer
3. Forsikre at ingen annen programvare bruker porten
4. Sjekk USB-kabeltilkoblinger
5. Restart Hardware Agent-tjenesten

**Test seriellportforbindelse:**
```powershell
# List tilgjengelige COM-porter
[System.IO.Ports.SerialPort]::GetPortNames()
```

### RFID-leseren fungerer ikke

**Problem:** RFID-skanninger oppdages ikke i web-app

**Løsninger:**
1. Test i Notisblokk - vises kort-ID?
2. Sjekk USB-tilkobling
3. Verifiser at leseren er i keyboard wedge-modus
4. Fokuser RFID-input-feltet på login-siden
5. Sjekk at kort-ID-en er registrert for bruker i databasen

### Database-feil

**Problem:** "Database locked" eller korrupsjon

**Løsninger:**
```powershell
# Sikkerhetskopier database
Copy-Item "keycabinet.db" "keycabinet.db.backup"

# Slett og gjenskape (mister data) - kjør web-appen for å gjenskape
Remove-Item "keycabinet.db"
```

### JSON Serialization Cycle Error

**Problem:** "A possible object cycle was detected"

Dette er allerede fikset i koden med `[JsonIgnore]` attributter. Hvis det oppstår:

**Løsninger:**
1. Sjekk at alle navigasjonsegenskaper har `[JsonIgnore]`
2. Unngå å laste inn unødvendige relasjoner i repositories
3. Se [Entity.cs](src/KeyCabinetApp.Core/Entities/) filer for korrekt konfigurasjon

## 🔐 Beste praksis for sikkerhet

1. **Endre standardpassord** umiddelbart via admin-panelet
2. **Bruk sterke passord** for alle brukere (min 12 tegn, kombinasjon av tegn)
3. **Begrens admin-tilgang** til kun betrodd personell
4. **Brannmurregler**: Begrens tilgang til port 5000/5001 til betrodde nettverk
5. **HTTPS**: Bruk reverse proxy med SSL-sertifikat for produksjon
6. **Regelmessige sikkerhetskopier** av databasen
7. **Overvåk logger** for mistenkelig aktivitet via admin-panelet
8. **Hold Windows og .NET oppdatert**
9. **Fysisk sikkerhet** - monter server/nettbrett sikkert
10. **SignalR autentisering**: Implementer token-basert auth for produksjon
10. **Fysisk sikkerhet** - monter nettbrett sikkert i skapet

## 📁 Filplasseringer

**Web-applikasjon:**
- **Applikasjon:** `src\KeyCabinetApp.Web\`
- **Database:** `src\KeyCabinetApp.Web\keycabinet.db`
- **Konfigurasjon:** `src\KeyCabinetApp.Web\appsettings.json`
- **wwwroot:** `src\KeyCabinetApp.Web\wwwroot\` (statiske filer)

**Hardware Agent:**
- **Applikasjon:** `src\KeyCabinetApp.HardwareAgent\`
- **Konfigurasjon:** `src\KeyCabinetApp.HardwareAgent\appsettings.json`

**WPF Desktop (Legacy):**
- **Applikasjon:** `src\KeyCabinetApp.UI\`
- **Database:** `%APPDATA%\KeyCabinetApp\keycabinet.db`

## 🛠️ Utvikling

### Prosjektstruktur

```
KeyCabinetApp/
├── src/
│   ├── KeyCabinetApp.Core/
│   │   ├── Entities/          # Domenemodeller (User, Key, Event, osv.)
│   │   ├── Enums/             # Konstanter
│   │   └── Interfaces/        # Tjenestekontrakter
│   │
│   ├── KeyCabinetApp.Application/
│   │   └── Services/          # Forretningslogikk
│   │       ├── AuthenticationService.cs
│   │       ├── KeyControlService.cs
│   │       └── LoggingService.cs
│   │
│   ├── KeyCabinetApp.Infrastructure/
│   │   ├── Data/              # Database context & repositories
│   │   ├── Serial/            # RS485-kommunikasjon
│   │   └── Api/               # SignalR hubs
│   │
│   ├── KeyCabinetApp.Web/
│   │   ├── Pages/             # Blazor-sider (Login, Keys, Admin)
│   │   ├── Shared/            # Delte komponenter
│   │   ├── Services/          # Web-spesifikke tjenester
│   │   ├── Hubs/              # SignalR hubs
│   │   └── wwwroot/           # CSS, JavaScript, bilder
│   │
│   ├── KeyCabinetApp.HardwareAgent/
│   │   └── Services/          # SignalR klient, RS485-kommunikasjon
│   │
│   └── KeyCabinetApp.UI/      # WPF (legacy)
│       ├── Views/             # XAML brukerkontroller
│       ├── ViewModels/        # MVVM view models
│       └── Converters/        # XAML verdiekonverterere
```

### Utvide applikasjonen

**Legge til ny Blazor-side:**
1. Opprett `.razor`-fil i `Pages/` mappen
2. Legg til `@page "/route"` directive
3. Inject nødvendige tjenester med `@inject`
4. Legg til lenke i navigasjon hvis nødvendig

**Legge til en ny nøkkelslot:**
1. Oppdater maskinvaretilkobling
2. Legg til kommando i Hardware Agent `appsettings.json` → `SlotCommands`
3. Legg til nøkkel via admin-panelet eller database

**Legge til en ny bruker:**
1. Bruk web-appens admin-panel (anbefalt)
2. Eller bruk `AuthenticationService.CreateUserAsync()` programmatisk

**Tilpasse UI:**
1. Rediger CSS i `wwwroot/css/` for web-app
2. Rediger Razor-komponenter i `Pages/` og `Shared/`
3. For WPF: Rediger XAML-filer i `Views/`

**Legge til ny SignalR-funksjonalitet:**
1. Utvid `HardwareHub.cs` eller opprett ny hub
2. Legg til klientmetoder i `HardwareAgentManager.cs` eller `SignalRClientService.cs`
3. Implementer UI-oppdateringer i relevante Blazor-sider

## 📞 Support og dokumentasjon

**Ytterligere dokumentasjon:**
- [QUICKSTART.md](QUICKSTART.md) - Hurtigstartveiledning
- [SETUP.md](SETUP.md) - Detaljert oppsettguide
- [WEB_README.md](WEB_README.md) - Web-app spesifikk dokumentasjon
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Sjekkliste for produksjonsutrulling

**For problemer med:**
- **Maskinvare:** Konsulter produsenten av styringskort
- **RS485-protokoll:** Sjekk styringskortdokumentasjon
- **Programvarefeil:** Sjekk logger i admin-panelet
- **Egendefinerte funksjoner:** Kildekode er åpen for modifikasjon

## 📄 Lisens

Dette er skreddersydd programvare. Kildekoden er tilgjengelig for modifikasjon og tilpasning til dine behov.

## ✅ Sjekkliste før utrulling

Før utrulling til produksjon:

**Web-applikasjon:**
- [ ] Endre admin-passord fra `admin123` via admin-panelet
- [ ] Konfigurer riktig COM-port i Hardware Agent `appsettings.json`
- [ ] Test RS485-kommandoer med faktisk maskinvare
- [ ] Verifiser SignalR-kommunikasjon mellom Web og Hardware Agent
- [ ] Registrer alle RFID-kort for brukere via admin-panelet
- [ ] Sett opp alle nøkler via admin-panelet
- [ ] Konfigurer brukertillatelser for nøkkeltilgang
- [ ] Test i flere nettlesere (Chrome, Edge, Firefox)
- [ ] Konfigurer HTTPS med reverse proxy for produksjon
- [ ] Konfigurer brannmur (port 5000 og 5001)
- [ ] Installer web-app og hardware agent som Windows Services
- [ ] Sikkerhetskopier database regelmessig
- [ ] Test nødtilgangsprosedyrer
- [ ] Dokumenter maskinvareoppsett og nettverk
- [ ] Tren brukere på web-grensesnittet
- [ ] Sett opp kioskmodus hvis berøringsskjerm brukes

**Legacy WPF-app (hvis brukt):**
- [ ] Test fullskjerm/kioskmodus på nettbrett
- [ ] Sett opp autostart ved oppstart
- [ ] Deaktiver hvilemodus på nettbrett

## 🎓 Hurtigstartguide for brukere

### Web-applikasjon

**Normal bruk (RFID):**

**Normal bruk (RFID):**

1. Åpne web-appen i nettleseren (http://localhost:5000)
2. Fokuser RFID-input-feltet på login-siden
3. Skann ditt RFID-kort
4. Applikasjonen logger automatisk inn og viser tilgjengelige nøkler
5. Klikk på nøkkelkortet du trenger
6. Nøkkelslotet låses opp automatisk
7. Ta ut nøkkel
8. Ferdig!

**Alternativ (Passord):**

1. Åpne web-appen i nettleseren
2. Klikk "LOGG INN MED BRUKERNAVN"
3. Skriv inn brukernavn og passord
4. Klikk "LOGG INN"
5. Velg og klikk på nøkkel for å åpne

**Admin-funksjoner:**

1. Logg inn som admin-bruker
2. Klikk "⚙️ Admin" i toppmeny
3. Administrer:
   - **Brukere**: Opprett, rediger, slett brukere
   - **Nøkler**: Legg til og administrer nøkler
   - **Tilgangskontroll**: Tildel nøkkeltilgang
   - **Logger**: Se all aktivitet

---

**Bygget med .NET 8.0, Blazor Server, SignalR og moderne web-teknologi**

💡 **Tips:** For beste opplevelse, bruk Chrome eller Edge i fullskjerm-modus på berøringsskjermer.

For tekniske spørsmål om kodebasen, gjennomgå kildekode og inline dokumentasjon.

