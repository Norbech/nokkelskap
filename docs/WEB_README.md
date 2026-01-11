# Nøkkelskap Web-applikasjon 🔑

## Oversikt

Nøkkelskappsystemet er nå konvertert til en **Blazor Server web-applikasjon** som kan brukes direkte i nettleseren! Dette betyr at du slipper å installere noe på klientmaskinene - bare åpne nettleseren og gå til adressen.

## Arkitektur

Systemet består nå av to hoveddeler:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Nettleser     │◄───►│  Web Server     │◄───►│  Database       │
│   (Blazor)      │     │  (ASP.NET Core) │     │  (SQLite)       │
└─────────────────┘     └────────┬────────┘     └─────────────────┘
                                 │
                                 │ SignalR WebSocket
                                 ▼
                        ┌─────────────────┐
                        │  Hardware Agent │
                        │  (Lokal PC)     │
                        │  - RFID-leser   │
                        │  - RS485 seriell│
                        └─────────────────┘
```

### 1. Web Server (`KeyCabinetApp.Web`)
- Blazor Server-applikasjon
- Håndterer all business-logikk
- Serverer web-grensesnittet
- Kommuniserer med database
- Mottar hardware-hendelser via SignalR

### 2. Hardware Agent (`KeyCabinetApp.HardwareAgent`)
- Liten tjeneste som kjører på PC-en med hardware tilkoblet
- Kommuniserer med RFID-leser og RS485 nøkkelskap
- Sender hendelser til web-server via SignalR
- Kan kjøres som Windows-tjeneste

## Komme i gang

### Steg 1: Start Web Server

```powershell
cd src/KeyCabinetApp.Web
dotnet run
```

Web-applikasjonen vil starte på:
- HTTPS: `https://localhost:5001`
- HTTP: `http://localhost:5000`

### Steg 2: Start Hardware Agent (på PC med hardware)

```powershell
cd src/KeyCabinetApp.HardwareAgent
dotnet run
```

Hardware Agent vil automatisk koble seg til web-serveren.

### Steg 3: Åpne i nettleser

Gå til `https://localhost:5001` i nettleseren din. 

**Standard innlogging:**
- Brukernavn: `admin`
- Passord: `admin123`

Eller skann RFID-kort: `0014571466`

## Konfigurasjon

### Web Server (`KeyCabinetApp.Web/appsettings.json`)

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "HardwareAgent": {
    "RequireAuthentication": false,
    "AllowedAgentIds": []
  }
}
```

### Hardware Agent (`KeyCabinetApp.HardwareAgent/appsettings.json`)

```json
{
  "ServerUrl": "https://localhost:5001",
  "AgentId": "hardware-agent-01",
  "ReconnectDelaySeconds": 5,
  "SerialCommunication": {
    "PortName": "COM4",
    "BaudRate": 9600,
    ...
  }
}
```

**Viktige innstillinger:**
- `ServerUrl`: Adressen til web-serveren
- `AgentId`: Unik ID for denne hardware-agenten
- `PortName`: COM-port for RS485-kommunikasjon

## Kjøre på nettverk

### Installer web-server på server

1. **Publiser applikasjonen:**
```powershell
dotnet publish src/KeyCabinetApp.Web -c Release -o publish/web
```

2. **Konfigurer IIS eller Kestrel** til å hoste applikasjonen

3. **Oppdater appsettings.json** med riktig URL og database-sti

### Installer Hardware Agent som Windows-tjeneste

```powershell
# Publiser
dotnet publish src/KeyCabinetApp.HardwareAgent -c Release -o publish/agent

# Installer som Windows-tjeneste
sc create "KeyCabinet Hardware Agent" binPath="C:\path\to\KeyCabinetApp.HardwareAgent.exe"
sc start "KeyCabinet Hardware Agent"
```

### Tilgang fra andre maskiner

1. **Oppdater ServerUrl** i Hardware Agent til å peke på server-IP
2. **Åpne brannmurporter** (typisk 5000/5001)
3. **Konfigurer SSL-sertifikat** for produksjon

Brukere kan nå åpne nettleseren og gå til:
```
https://server-ip:5001
```

## Funksjoner

### ✅ Innlogging
- RFID-kort (automatisk via Hardware Agent)
- Brukernavn og passord

### ✅ Nøkkelvelger
- Visuelt rutenett med alle tilgjengelige nøkler
- Real-time status
- Klikk for å åpne nøkkel

### ✅ Administrasjon
- Brukerhåndtering
- Nøkkelhåndtering
- Hendelseslogg med filtrering
- Hardware-status

### ✅ Real-time kommunikasjon
- SignalR WebSocket for øyeblikkelig respons
- Automatisk gjenkobling ved forbindelsestap

## Fordeler vs Desktop-app

| Funksjon | Desktop WPF | Web Blazor |
|----------|-------------|------------|
| **Installasjon** | Må installeres på hver PC | Ingen installasjon - åpne nettleser |
| **Oppdateringer** | Må oppdateres manuelt | Automatisk ved refresh |
| **Plattform** | Kun Windows | Alle platformer (Windows/Mac/Linux/mobile) |
| **Flerbruker** | En om gangen | Flere samtidige brukere |
| **Hardware** | Direkte tilkobling | Via Hardware Agent |
| **Administrasjon** | Lokalt | Sentralisert |

## Troubleshooting

### Hardware Agent kobler ikke til

1. Sjekk at `ServerUrl` er riktig i appsettings.json
2. Sjekk brannmur-innstillinger
3. Verifiser at web-serveren kjører
4. Se logger i konsollen

### RFID fungerer ikke

1. Sjekk at Hardware Agent kjører
2. Verifiser at RFID-leseren er tilkoblet
3. Test RFID-leser i Notisblokk (keyboard wedge)
4. Sjekk logger for feilmeldinger

### Nøkkelskap åpner ikke

1. Verifiser COM-port i appsettings.json
2. Sjekk RS485-tilkobling
3. Test seriell kommunikasjon manuelt
4. Se Hardware Agent-logger

## Database

Databasen lagres automatisk i:
```
%APPDATA%\KeyCabinetApp\keycabinet.db
```

**Backup:** Kopier denne filen regelmessig!

## Sikkerhet

### Produksjon
- ✅ Bruk HTTPS med gyldig sertifikat
- ✅ Endre standard admin-passord
- ✅ Begrens tilgang via brannmur
- ✅ Aktiver autentisering for Hardware Agent
- ✅ Backup database regelmessig

### Utviklingsserver
- Selv-signert sertifikat er OK
- Standard-passord kan brukes
- Lokal tilgang anbefales

## Support

For spørsmål eller problemer, sjekk:
1. Konsollogger (både web og agent)
2. Event Viewer (Windows-logger)
3. Database-integritet
4. Nettverksforbindelse

## Kjente begrensninger

- Hardware Agent må kjøre på Windows (pga. seriell/RFID)
- Krever stabil nettverksforbindelse mellom agent og server
- Kun én Hardware Agent per server støttes pt. (kan utvides)

## Fremtidige forbedringer

- [ ] Multi-agent støtte (flere nøkkelskap)
- [ ] Mobile app (React Native/MAUI)
- [ ] QR-kode innlogging
- [ ] Push-varsler
- [ ] Rapportering og statistikk
- [ ] Azure/cloud hosting
