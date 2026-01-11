# Nøkkelskap Kontrollsystem - AI Kodeinstruksjoner

## Prosjektoversikt

Elektronisk nøkkelskap-kontrollsystem med RFID-autentisering, RS485 seriell kommunikasjon og web-basert grensesnitt. Bygget med .NET 8 ved bruk av Clean Architecture-mønstre. Målrettet mot Windows-deployment med dobbel-prosess arkitektur.

## Mappestruktur

```
nokkelskap/
├── src/                              # Kildekode
│   ├── KeyCabinetApp.Core/          # Domenemodeller og grensesnitt
│   ├── KeyCabinetApp.Application/   # Forretningslogikk
│   ├── KeyCabinetApp.Infrastructure/ # Database, Serial, RFID
│   ├── KeyCabinetApp.Web/           # Blazor Server web-app (PRIMÆR)
│   ├── KeyCabinetApp.HardwareAgent/ # Hardware I/O-tjeneste
│   ├── KeyCabinetApp.LocalServerLauncher/ # Tray UI-launcher
│   └── KeyCabinetApp.UI/            # Legacy WPF (ikke i bruk)
│
├── bundle/                           # Deployment-bunter
│   └── local-server-new7/           # Nyeste bundle (bruk denne)
│       ├── KeyCabinetServer.exe     # UI-launcher med tray-ikon
│       ├── web/                     # Publiserte web-binærfiler
│       ├── agent/                   # Publiserte agent-binærfiler
│       └── config/                  # Redigerbare appsettings
│
├── publish/                          # Publiserte binærfiler (generert)
│   ├── web/                         # Web Server binærfiler
│   └── agent/                       # Hardware Agent binærfiler
│
├── docs/                             # Dokumentasjon
│   ├── README.md                    # Hovedoversikt
│   ├── QUICKSTART.md                # Hurtigstart-guide
│   ├── WEB_README.md                # Web-arkitektur
│   ├── RFID_GUIDE.md                # RFID feilsøking
│   └── DEPLOYMENT_CHECKLIST.md      # Produksjons-sjekkliste
│
├── scripts/                          # Utvikler-scripts
│   ├── start-local.ps1/.cmd         # Start lokal utvikling
│   ├── stop-local.ps1/.cmd          # Stopp alle prosesser
│   ├── build.ps1                    # Bygg alle prosjekter
│   └── simple-publish.ps1           # Publiser Web + Agent
│
├── appsettings.EXAMPLE.json          # Konfigurasjon-mal
└── KeyCabinetApp.sln                 # Visual Studio solution
```

## Arkitekturmønster

**Clean Architecture** med streng lagdeling:
- `KeyCabinetApp.Core/` - Domenemodeller (User, Key, Event), kun grensesnitt - INGEN avhengigheter
- `KeyCabinetApp.Application/` - Forretningslogikk-tjenester (AuthenticationService, KeyControlService)
- `KeyCabinetApp.Infrastructure/` - Konkrete implementasjoner (ApplicationDbContext, Rs485Communication, RFID-lesere)
- `KeyCabinetApp.Web/` - Blazor Server UI med Razor-komponenter i `Pages/`
- `KeyCabinetApp.HardwareAgent/` - BackgroundService for hardware I/O
- `KeyCabinetApp.LocalServerLauncher/` - WPF/WinForms hybrid UI-launcher med tray-ikon

**Kritisk**: Core har INGEN avhengigheter. Application refererer kun til Core. Infrastructure implementerer Core-grensesnitt. Web refererer Application + Infrastructure.

## Dobbel-Prosess Kommunikasjon

**Web Server ↔ Hardware Agent via SignalR**:
- Web-server hoster [HardwareHub.cs](../src/KeyCabinetApp.Web/Hubs/HardwareHub.cs) SignalR hub
- Agent kobler til som klient via [SignalRClientService.cs](../src/KeyCabinetApp.HardwareAgent/Services/SignalRClientService.cs)
- Proxy-mønster i Web: [HardwareProxyService.cs](../src/KeyCabinetApp.Web/Services/HardwareProxyService.cs) implementerer `ISerialCommunication`, videresender til agent
- RFID-hendelser flyter: Hardware Agent → SignalR → Web → RfidProxyService → AuthenticationService
- Serielle kommandoer flyter: Web UI → HardwareProxyService → SignalR → Agent → Rs485Communication

**Hvorfor**: Hardware-tilgang (COM-porter, globale tastaturhooks) krever Windows-spesifikke privilegier. Separasjon tillater at web-serveren kan kjøre hvor som helst mens agenten forblir lokal.

## Service Registrering & DI

**Web Server** ([Program.cs](../src/KeyCabinetApp.Web/Program.cs)):
- **Scoped** (per Blazor circuit): Repositories, Application services, Session state
- **Singleton**: HardwareAgentManager, KeyImageService
- Proxy-tjenester (`HardwareProxyService`, `RfidProxyService`) implementerer Core-grensesnitt men delegerer til SignalR
- Database-sti: `%APPDATA%\KeyCabinetApp\keycabinet.db` settes opp i Program.cs
- Standard URL: `http://0.0.0.0:5000` (kan overskrives via `--urls`)

**Hardware Agent** ([Program.cs](../src/KeyCabinetApp.HardwareAgent/Program.cs)):
- **Singleton**: All hardware-kommunikasjon (Rs485Communication, GlobalKeyboardRfidReader, SignalRClientService)
- **HostedService**: HardwareAgentWorker koordinerer hardware-hendelser
- Konfigurasjon lastet fra `appsettings.json` i `AppContext.BaseDirectory`
- Støtter Windows Service-deployment via `AddWindowsService()`

## Database & Konfigurasjon

**SQLite-plassering**: `%APPDATA%\KeyCabinetApp\keycabinet.db` (auto-opprettet ved første kjøring)
- Seedes via [DatabaseSeeder.cs](../src/KeyCabinetApp.Infrastructure/Data/DatabaseSeeder.cs) med standard admin (brukernavn: `admin`, passord: `admin123`)
- Skjema definert i [ApplicationDbContext.cs](../src/KeyCabinetApp.Infrastructure/Data/ApplicationDbContext.cs)

**Kritisk konfigurasjon**: [appsettings.json](../appsettings.EXAMPLE.json) inneholder RS485-protokollkommandoer:
- `SlotCommands` mapper slot-numre til hex byte-strenger (f.eks. `"1": "01 05 00 01 FF 00 DD FA"`)
- Kommandoer er hardware-spesifikke (Modbus RTU vanlig, men ikke garantert)
- COM-port, baud rate, paritet må matche fysisk kontroller-board

## Utviklingsarbeidsflyt

**Rask lokal oppstart**:
```powershell
.\scripts\start-local.cmd  # Starter både Web + Agent, åpner nettleser
.\scripts\stop-local.cmd   # Stopper alt
```

**Manuell utvikling**:
```powershell
# Terminal 1
dotnet run --project src/KeyCabinetApp.Web
# Terminal 2
dotnet run --project src/KeyCabinetApp.HardwareAgent
```

**Bygg & publiser**:
```powershell
.\scripts\build.ps1           # Restore + bygg alle prosjekter
.\scripts\simple-publish.ps1  # Publiser til publish/web og publish/agent
```

**Testing uten hardware**: Start kun Web-prosjektet. RFID/seriell-operasjoner vil logge feil, men UI forblir funksjonelt for utvikling.

## Prosjekt-Spesifikke Mønstre

**RFID-Autentisering**:
- Primær inngangsmetode via keyboard wedge (USB HID-enhet som emulerer tastatur)
- [GlobalKeyboardRfidReader.cs](../src/KeyCabinetApp.Infrastructure/Rfid/GlobalKeyboardRfidReader.cs) bruker lavnivå Windows hooks for å fange skanning selv uten vindusfokus
- RFID-IDer lagres som strenger i User.RfidTag (unik indeksert)
- Fallback til brukernavn/passord via BCrypt-hashing

**RS485 Seriell Protokoll**:
- Hex-kommandoer konfigurert i JSON, parsert til byte-arrays ved runtime
- Ingen automatisk CRC-beregning - kommandoer må inkludere korrekte checksums
- WriteAndDiscardResponse-mønster: send bytes, ignorer respons (fire-and-forget)
- Valgfrie statusforespørsler via `StatusCommands`-seksjonen

**Norsk UI**: Alle Blazor-komponenter og etiketter bruker norsk tekst. Oppretthold denne konvensjonen.

**Sesjonshåndtering**: [SessionStateService.cs](../src/KeyCabinetApp.Web/Services/SessionStateService.cs) sporer gjeldende bruker i Blazor Server scoped service (per-circuit).

**Blazor Server Mønstre**:
- Alle `.razor` filer i [src/KeyCabinetApp.Web/Pages/](../src/KeyCabinetApp.Web/Pages/)
- Ruter via `@page` direktiv (f.eks. `@page "/keys"`)
- Komponenter injiserer tjenester via `@inject` (f.eks. `@inject AuthenticationService AuthService`)
- Real-time oppdateringer via `StateHasChanged()` når SignalR-hendelser mottas
- Norsk språk brukes konsekvent i all UI-tekst
- CSS-filer co-located med Razor-komponenter (f.eks. `Login.razor.css`)

## Deployment-Bunter

`bundle/local-server-new7/` mapper inneholder distribusjonspakker med:
- `KeyCabinetServer.exe` - UI-launcher med tray-ikon (dobbeltklikk for å starte)
- Publiserte Web + Agent-binærfiler
- Bootstrap-script for runtime-sjekker (.NET 8 auto-install)
- Brukervendte .cmd-filer:
  - `START.cmd` / `START-UI.cmd` - Start serveren
  - `STOPP.cmd` - Stopp serveren
  - `INSTALL-AUTOSTART.cmd` - Installer autostart ved Windows-innlogging
  - `FINN-COM-PORT.cmd` - Diagnostikk for COM-port
- Norsk dokumentasjon (`HVORDAN-STARTE.txt`)

**Deployment-mønster**: 
- Self-contained publish (exe) ELLER framework-avhengig med runtime-sjekk via [run.ps1](../bundle/local-server-new7/run.ps1)
- `run.ps1` detekterer tilgjengelig deployment-type automatisk
- Bootstrap installerer .NET Runtime hvis mangler

## Vanlige Fallgruver

1. **COM-port konflikter**: Kun én prosess kan åpne en seriell port. Sikre at det ikke finnes dupliserte agent-instanser.
2. **RFID fokus-krav**: Opprinnelige keyboard wedge-implementasjoner krevde vindusfokus - migrert til globale hooks for å løse dette.
3. **SignalR-gjenkobling**: Agent må håndtere frakoblinger grasiøst (se `ReconnectDelaySeconds` config).
4. **Database-låsing**: SQLite støtter ikke samtidige skrivinger godt. Bruk scoped DbContext-levetid for å unngå utdaterte kontekster.
5. **Hex-string parsing**: Slot-kommandoer aksepterer mellomrom eller bindestrek som skilletegn. Valider format før sending til seriell port.

## Viktige Filer å Kjenne

- [docs/DEPLOYMENT_CHECKLIST.md](../docs/DEPLOYMENT_CHECKLIST.md) - Produksjonsoppsett-validering
- [appsettings.EXAMPLE.json](../appsettings.EXAMPLE.json) - Annotert konfigurasjonsreferanse  
- [docs/RFID_GUIDE.md](../docs/RFID_GUIDE.md) - Feilsøking av RFID-autentisering
- [docs/WEB_README.md](../docs/WEB_README.md) - Arkitekturforklaring for web-migrasjon

## Test-Innlogginger

Standard seedede brukere:
- Admin: brukernavn `admin` / passord `admin123` / RFID `0014571466`
- Testbruker: brukernavn `testuser` / passord `test123`

**Sikkerhetsnotat**: Endre standard passord før produksjonsdeployment.
