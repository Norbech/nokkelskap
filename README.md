# Nøkkelskap Kontrollsystem

En komplett Windows-applikasjon for å styre et nøkkelskap ved bruk av RS485-kommunikasjon, RFID-autentisering og ekstern tilgang.

## 🎯 Oversikt

Denne applikasjonen tilbyr:
- **RFID-autentisering**: Primær innloggingsmetode ved bruk av RFID-kort
- **Passord som reserve**: Brukernavn/passord-autentisering når RFID ikke er tilgjengelig
- **Nøkkelkontroll**: Åpne individuelle nøkkelplasser via RS485 seriell kommunikasjon
- **Tilgangssystem**: Brukerbasert tilgangskontroll for spesifikke nøkler
- **Omfattende logging**: Alle handlinger logges til SQLite-database
- **Ekstern API**: Valgfri HTTP API for ekstern nøkkelåpning
- **Berøringsvennlig UI**: WPF-grensesnitt optimalisert for nettbrett

## 📋 Maskinvarekrav

- **Windows Nettbrett/PC**: Windows 10/11 (Surface eller lignende)
- **USB Hub**: Koblet til nettbrettet
- **USB-til-RS485 Adapter**: Vises som en COM-port i Windows
- **Elektronisk Kontroller**: 
  - Terminalblokk: GND, 485 B, 485 A, +12V
  - RS485-linjer koblet til adapter
  - 12V strømforsyning
  - Flatbåndkabler til nøkkellåser/reléer/sensorer
- **RFID-leser**: USB keyboard wedge eller HID-enhet

## 🏗️ Arkitektur

```
KeyCabinetApp/
├── src/
│   ├── KeyCabinetApp.Core/          # Domenemodeller & grensesnitt
│   ├── KeyCabinetApp.Application/   # Forretningslogikk
│   ├── KeyCabinetApp.Infrastructure/# Database, Serial, API implementasjoner
│   └── KeyCabinetApp.UI/            # WPF brukergrensesnitt
├── appsettings.json                 # Konfigurasjon
└── README.md
```

**Teknologistakk:**
- .NET 8.0 (LTS)
- WPF med Material Design
- Entity Framework Core + SQLite
- BCrypt.Net for passord-hashing
- System.IO.Ports for RS485-kommunikasjon
- ASP.NET Core for ekstern API

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

```powershell
cd src\KeyCabinetApp.UI
dotnet run
```

Eller bygg for produksjon:
```powershell
dotnet publish -c Release -r win-x64 --self-contained
```

Den kjørbare filen vil være i: `src\KeyCabinetApp.UI\bin\Release\net8.0-windows\win-x64\publish\`

## ⚙️ Konfigurasjon

### Seriell kommunikasjon (RS485)

Rediger `src\KeyCabinetApp.UI\appsettings.json`:

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

### Ekstern API konfigurasjon

```json
{
  "RemoteApi": {
    "Enabled": false,           // Sett til true for å aktivere
    "Port": 5000,               // HTTP-port
    "AllowedIpAddresses": [     // Hviteliste bestemte IP-er
      "192.168.1.100",
      "192.168.1.101"
    ]
  }
}
```

**Sikkerhetsmerknad:**
- Ekstern API bør kun brukes på sikre interne nettverk
- Vurder å bruke VPN for ekstern tilgang
- Hold sterke passord for API-brukere
- Overvåk logger for uautoriserte tilgangsforsøk

### RFID-leser oppsett

Applikasjonen støtter **keyboard wedge** RFID-lesere (mest vanlig).

**Konfigurasjon:**
- Ingen ekstra programvarekonfigurasjon nødvendig
- Leseren skal sende kort-ID etterfulgt av Enter-tasten
- Typisk kortformat: numerisk eller alfanumerisk streng

**Testing:**
1. Åpne Notisblokk
2. Skann et RFID-kort
3. Du skal se kort-ID-en dukke opp som tekst
4. Notér kort-ID-en for brukerregistrering

**Alternative lesertyper:**
Hvis leseren din bruker seriell/HID-modus, kan du trenge å endre `KeyboardWedgeRfidReader.cs` for å håndtere den spesifikke protokollen.

## 👥 Brukeradministrasjon

### Initial admin-konto

Applikasjonen oppretter en standard admin-konto ved første kjøring:

- **Brukernavn:** `admin`
- **Passord:** `admin123`
- **⚠️ ENDRE DETTE PASSORDET UMIDDELBART!**

### Testbruker

En testbruker opprettes også:
- **Brukernavn:** `testuser`
- **Passord:** `test123`
- **RFID:** `1234567890` (erstatt med faktisk kort-ID)

### Legge til nye brukere

**Via database (SQLite):**

1. Installer en SQLite-leser (f.eks. [DB Browser for SQLite](https://sqlitebrowser.org/))
2. Åpne databasefilen:
   ```
   %APPDATA%\KeyCabinetApp\keycabinet.db
   ```
3. Legg til i `Users`-tabellen (passord må være BCrypt-hashet)

**Programmatisk (Fremtidig admin-panel):**

`AdminView` er en plassholder for fremtidig brukeradministrasjon. For nå kan du legge til brukere ved:

1. Bruke `AuthenticationService.CreateUserAsync()`-metoden
2. Opprette et enkelt admin-verktøy
3. Eller manuelt via databasen

**Eksempel: Opprett bruker via kode**

```csharp
// I et fremtidig admin-panel eller oppsettskript
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

Brukere trenger tillatelser for å få tilgang til spesifikke nøkler:

1. Åpne databasen i SQLite-leser
2. Legg til poster i `UserKeyAccess`-tabellen:
   ```sql
   INSERT INTO UserKeyAccess (UserId, KeyId, GrantedAt)
   VALUES (2, 1, datetime('now'));
   ```

## 🔑 Nøkkeladministrasjon

### Legge til nøkler

Nøkler defineres i databasen:

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

Oppdater disse i databasen for å matche dine faktiske nøkler.

## 🌐 Ekstern åpnings-API

### Aktiver ekstern API

1. Rediger `appsettings.json`:
   ```json
   "RemoteApi": {
     "Enabled": true,
     "Port": 5000
   }
   ```

2. Start applikasjonen på nytt

### API-endepunkter

**Helsekontroll:**
```bash
GET http://localhost:5000/api/health
```

Respons:
```json
{
  "status": "healthy",
  "timestamp": "2025-12-02T10:30:00Z"
}
```

**Åpne nøkkelslot:**
```bash
POST http://localhost:5000/api/open
Content-Type: application/json

{
  "username": "dispatcher",
  "password": "SikkertPassord123",
  "slotId": 1
}
```

Respons (Suksess):
```json
{
  "success": true,
  "message": "Ambulanse nøkkel åpnet"
}
```

Respons (Feil):
```json
{
  "success": false,
  "message": "Ugyldig brukernavn eller passord"
}
```

### Eksempel: PowerShell-skript

```powershell
$body = @{
    username = "dispatcher"
    password = "SikkertPassord123"
    slotId = 1
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://192.168.1.50:5000/api/open" `
    -Method Post `
    -Body $body `
    -ContentType "application/json"

Write-Host "Suksess: $($response.success)"
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

Eller implementer automatisk opprydding i koden.

## 🖥️ Kioskmodus-oppsett

### Autostart ved oppstart

1. Opprett en snarvei til `KeyCabinetApp.UI.exe`
2. Kopier til oppstartsmappen:
   ```
   %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
   ```

### Windows-konfigurasjon

**Deaktiver hvilemodus:**
```powershell
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
```

**Auto-innlogging (Valgfritt):**
1. Trykk `Win + R`, skriv `netplwiz`
2. Fjern haken ved "Brukere må oppgi brukernavn og passord"
3. Skriv inn legitimasjon for auto-innlogging

**Kioskmodus (Avansert):**

Bruk Windows 10/11 Kioskmodus:
1. Innstillinger → Kontoer → Familie og andre brukere
2. Konfigurer tilordnet tilgang
3. Velg nettbrettbrukeren
4. Velg KeyCabinetApp.UI.exe

### Fullskjermkontroller

- **ESC**: Avslutt fullskjerm (for testing)
- **F11**: Veksle fullskjerm
- Applikasjonen starter i fullskjerm som standard

## 🔧 Feilsøking

### Seriellport-problemer

**Problem:** "Could not connect to serial port"

**Løsninger:**
1. Verifiser COM-port i Enhetsbehandling
2. Sjekk at `appsettings.json` PortName stemmer
3. Forsikre at ingen annen programvare bruker porten
4. Sjekk USB-kabeltilkoblinger
5. Prøv å restarte USB-til-RS485-adapteren

**Test seriellportforbindelse:**
```powershell
# List tilgjengelige COM-porter
[System.IO.Ports.SerialPort]::GetPortNames()
```

### RFID-leseren fungerer ikke

**Problem:** RFID-skanninger oppdages ikke

**Løsninger:**
1. Test i Notisblokk - vises kort-ID?
2. Sjekk USB-tilkobling
3. Verifiser at leseren er i keyboard wedge-modus
4. Noen lesere trenger konfigurasjonsprogramvare
5. Sjekk `IsValidRfidFormat()` i `KeyboardWedgeRfidReader.cs`

### Database-feil

**Problem:** "Database locked" eller korrupsjon

**Løsninger:**
```powershell
# Sikkerhetskopier database
Copy-Item "$env:APPDATA\KeyCabinetApp\keycabinet.db" `
    "$env:APPDATA\KeyCabinetApp\keycabinet.db.backup"

# Slett og gjenskape (mister data)
Remove-Item "$env:APPDATA\KeyCabinetApp\keycabinet.db"
# Start applikasjonen på nytt for å gjenskape
```

### Ekstern API svarer ikke

**Problem:** Kan ikke koble til API

**Løsninger:**
1. Sjekk `Enabled: true` i konfigurasjon
2. Verifiser at brannmur tillater port 5000
3. Test lokalt: `http://localhost:5000/api/health`
4. Sjekk Windows Brannmur:
   ```powershell
   New-NetFirewallRule -DisplayName "KeyCabinet API" `
       -Direction Inbound -LocalPort 5000 -Protocol TCP -Action Allow
   ```

### Applikasjonskrasj

**Sjekk logger:**
1. Kjør fra PowerShell for å se konsollutskrift
2. Sjekk Windows Hendelseslogg
3. Aktiver detaljert logging i `appsettings.json`:
   ```json
   "Logging": {
     "LogLevel": {
       "Default": "Debug"
     }
   }
   ```

## 🔐 Beste praksis for sikkerhet

1. **Endre standardpassord** umiddelbart
2. **Bruk sterke passord** for alle brukere (min 12 tegn)
3. **Begrens admin-tilgang** til kun betrodd personell
4. **Deaktiver ekstern API** med mindre nødvendig
5. **Bruk VPN** for ekstern tilgang, ikke direkte internetteksponering
6. **Regelmessige sikkerhetskopier** av databasen
7. **Overvåk logger** for mistenkelig aktivitet
8. **Hold Windows oppdatert**
9. **Bruk BitLocker** for nettbrettdiskkryptering
10. **Fysisk sikkerhet** - monter nettbrett sikkert i skapet

## 📁 Filplasseringer

- **Applikasjon:** `src\KeyCabinetApp.UI\bin\Release\net8.0-windows\`
- **Database:** `%APPDATA%\KeyCabinetApp\keycabinet.db`
- **Konfigurasjon:** `appsettings.json` (i app-katalog)
- **Logger (fremtidig):** `%APPDATA%\KeyCabinetApp\logs\`

## 🛠️ Utvikling

### Prosjektstruktur

```
KeyCabinetApp/
├── src/
│   ├── KeyCabinetApp.Core/
│   │   ├── Entities/          # Domenemodeller
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
│   │   ├── Data/              # Database & repositories
│   │   ├── Serial/            # RS485-kommunikasjon
│   │   ├── Rfid/              # RFID-leser
│   │   └── Api/               # Ekstern API-server
│   │
│   └── KeyCabinetApp.UI/
│       ├── Views/             # XAML brukerkontroller
│       ├── ViewModels/        # MVVM view models
│       └── Converters/        # XAML verdiekonverterere
```

### Utvide applikasjonen

**Legge til en ny nøkkelslot:**
1. Oppdater maskinvaretilkobling
2. Legg til kommando i `appsettings.json` → `SlotCommands`
3. Legg til nøkkel i databasen

**Legge til en ny bruker:**
1. Bruk `AuthenticationService.CreateUserAsync()`
2. Legg til tillatelser via `UserKeyAccess`-tabellen

**Tilpasse UI:**
1. Rediger XAML-filer i `Views/`
2. Material Design-tema i `App.xaml`
3. Farger, skrifter, layout kan alle tilpasses

**Legge til admin-funksjoner:**
1. Utvid `AdminViewModel.cs`
2. Oppdater `AdminView.xaml`
3. Legg til repository-metoder etter behov

## 📞 Support og kontakt

For problemer med:
- **Maskinvare:** Konsulter produsenten av styringskort
- **RS485-protokoll:** Sjekk styringskortdokumentasjon
- **Programvarefeil:** Gjennomgå logger og feilmeldinger
- **Egendefinerte funksjoner:** Modifiser kildekode etter behov

## 📄 Lisens

Dette er skreddersydd programvare utviklet for ditt spesifikke maskinvareoppsett. Modifiser og bruk etter behov.

## ✅ Sjekkliste før utrulling

Før utrulling til produksjon:

- [ ] Endre admin-passord fra `admin123`
- [ ] Konfigurer riktig COM-port i `appsettings.json`
- [ ] Test RS485-kommandoer med faktisk maskinvare
- [ ] Registrer alle RFID-kort for brukere
- [ ] Sett opp alle nøkler i databasen
- [ ] Konfigurer brukertillatelser
- [ ] Test fullskjerm/kioskmodus
- [ ] Sett opp autostart ved oppstart
- [ ] Deaktiver hvilemodus på nettbrett
- [ ] Konfigurer brannmur hvis ekstern API brukes
- [ ] Sikkerhetskopier databasefil
- [ ] Test nødtilgangsprosedyrer
- [ ] Dokumenter maskinvareoppsett
- [ ] Tren brukere på systemet

## 🎓 Hurtigstartguide for brukere

### Normal bruk (RFID)

1. Skann ditt RFID-kort
2. Velg nøkkelen du trenger
3. Klikk på nøkkelkortet
4. Nøkkelslotet låses opp
5. Ta ut nøkkel
6. Ferdig!

### Alternativ (Passord)

1. Klikk "LOGG INN MED BRUKERNAVN"
2. Skriv inn brukernavn og passord
3. Klikk "LOGG INN"
4. Velg og åpne nøkkel som over

### Ekstern åpning

Fra dispatsentral/kontrollrom:
1. Bruk oppgitt API-endepunkt
2. Autentiser med brukernavn/passord
3. Spesifiser slot-ID som skal åpnes
4. Verifiser handling i logger

---

**Bygget med .NET 8.0, WPF, og Material Design**

For tekniske spørsmål om kodebasen, gjennomgå inline kode-dokumentasjon og kommentarer i kildefilene.

