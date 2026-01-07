# Local server bundle

## 🚀 HURTIGSTART:

**Dobbeltklikk på: START.cmd**

Det er alt! Se HVORDAN-STARTE.txt for mer info.

---

## 📁 Innhold:

- `START.cmd` ← **Start serveren (dobbeltklikk)**
- `STOPP.cmd` ← **Stopp serveren (dobbeltklikk)**
- `HVORDAN-STARTE.txt` ← Detaljert brukerveiledning
- `web/` Published KeyCabinetApp.Web
- `agent/` Published KeyCabinetApp.HardwareAgent
- `bootstrap.ps1` Installerer nødvendige avhengigheter (.NET Runtime)
- `run.ps1` PowerShell script (brukes av START.cmd)
- `stop.ps1` PowerShell script (brukes av STOPP.cmd)
- `config/` Reference appsettings files
- `cloudflare/` Cloudflared templates

## Første gangs oppstart:

1. **Dobbeltklikk på START.cmd**
   
2. **Automatisk installasjon:**
   - Scriptet sjekker om .NET Runtime er installert
   - Hvis ikke, laster det ned og installerer .NET 8.0 SDK automatisk
   - Du vil bli bedt om å bekrefte installasjonen
   
3. **Etter installasjon:**
   - Start PowerShell på nytt
   - Dobbeltklikk på START.cmd igjen

## Vanlig bruk:

- **Start:** Dobbeltklikk START.cmd
- **Stopp:** Dobbeltklikk STOPP.cmd
- **Web:** http://localhost:5000

## For avanserte brukere (PowerShell):

```powershell
.\run.ps1              # Start med standardinnstillinger
.\run.ps1 -NoBrowser   # Start uten å åpne nettleser
.\stop.ps1             # Stopp begge tjenester
.\bootstrap.ps1        # Manuell installasjon av avhengigheter
```

## Notater:

- Database: `%APPDATA%\KeyCabinetApp\keycabinet.db`
- Hardware: Rediger `agent/appsettings.json` for COM-port
- Loggfiler: `logs/`
- Downloads: `downloads/` (installasjonsfiler)
