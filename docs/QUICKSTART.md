# 🚀 Hurtigstart - Nøkkelskap Web

## Quick Start (Lokal testing)

## Enkelt oppsett (anbefalt)

Dobbelklikk `start-local.cmd` i prosjektroten.

- Starter Web + HardwareAgent
- Åpner nettleser automatisk
- Logger til `C:\temp\keycabinet-*.log`

Stopper alt igjen med `stop-local.cmd`.

### Terminal 1: Start Web Server
```powershell
cd "c:\Users\andre\Desktop\App til nøkkelskap\nokkelskap"
dotnet run --project src/KeyCabinetApp.Web
```

Web-app tilgjengelig på: **https://localhost:5001**

### Terminal 2: Start Hardware Agent
```powershell
cd "c:\Users\andre\Desktop\App til nøkkelskap\nokkelskap"
dotnet run --project src/KeyCabinetApp.HardwareAgent
```

### Terminal 3: Åpne nettleser
```powershell
start https://localhost:5001
```

## Innlogging

**Admin-bruker:**
- Brukernavn: `admin`
- Passord: `admin123`

**RFID:**
- Skann kort: `0014571466`

## Test uten hardware

Hvis du ikke har hardware tilkoblet:
1. Start bare Web Server (Terminal 1)
2. Logg inn med brukernavn/passord
3. Hardware-kommandoer vil feile, men UI fungerer

## Bygg for produksjon

```powershell
# Web Server
dotnet publish src/KeyCabinetApp.Web -c Release -o publish/web

# Hardware Agent
dotnet publish src/KeyCabinetApp.HardwareAgent -c Release -o publish/agent
```

## Kjør published versjon

```powershell
# Web
publish/web/KeyCabinetApp.Web.exe

# Agent
publish/agent/KeyCabinetApp.HardwareAgent.exe
```

---

Se [WEB_README.md](WEB_README.md) for full dokumentasjon!
