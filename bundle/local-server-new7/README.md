# Local server bundle

## HURTIGSTART (anbefalt):

**Dobbeltklikk: KeyCabinetServer.exe**

(Alternativt: START-UI.cmd)

Dette gir en liten UI med Start/Stopp-knapp og status-lampe, uten ekstra terminalvinduer.

Serveren starter automatisk naar du aapner UI-en.

Naar UI-en starter web, aapnes nettleseren i fullskjerm (Edge/Chrome hvis tilgjengelig).

Autostart ved innlogging (PC-start):
- Dobbeltklikk: INSTALL-AUTOSTART.cmd
- For aa fjerne igjen: FJERN-AUTOSTART.cmd

Tips: Ved autostart legges det ogsaa et tray-ikon (ved klokka) som lar deg starte/stoppe og aapne web.

---

## HURTIGSTART (gammel metode):

**Dobbeltklikk pÃ¥: START.cmd**

Det er alt! Se HVORDAN-STARTE.txt for mer info.

---

## ðŸ“ Innhold:

- `START.cmd` â† **Start serveren (dobbeltklikk)**
- `START-UI.cmd` â† Starter UI-launcher (uten ekstra vinduer)
- `KeyCabinetServer.exe` â† UI-launcher (Start/Stopp + status)
- `INSTALL-AUTOSTART.cmd` â† Installer autostart ved innlogging
- `FJERN-AUTOSTART.cmd` â† Fjern autostart
- `STOPP.cmd` â† **Stopp serveren (dobbeltklikk)**
- `HVORDAN-STARTE.txt` â† Detaljert brukerveiledning
- `web/` Published KeyCabinetApp.Web
- `agent/` Published KeyCabinetApp.HardwareAgent
- `bootstrap.ps1` Installerer nÃ¸dvendige avhengigheter (.NET Runtime)
- `run.ps1` PowerShell script (brukes av START.cmd)
- `stop.ps1` PowerShell script (brukes av STOPP.cmd)
- `config/` Reference appsettings files
- `cloudflare/` Cloudflared templates

## FÃ¸rste gangs oppstart:

1. **Dobbeltklikk pÃ¥ START.cmd**
   
2. **Automatisk installasjon:**
   - Scriptet sjekker om .NET Runtime er installert
   - Hvis ikke, laster det ned og installerer .NET 8.0 SDK automatisk
   - Du vil bli bedt om Ã¥ bekrefte installasjonen
   
3. **Etter installasjon:**
   - Start PowerShell pÃ¥ nytt
   - Dobbeltklikk pÃ¥ START.cmd igjen

## Vanlig bruk:

- **Start:** Dobbeltklikk START.cmd
- **Stopp:** Dobbeltklikk STOPP.cmd
- **Web:** http://localhost:5000

## For avanserte brukere (PowerShell):

```powershell
.\run.ps1              # Start med standardinnstillinger
.\run.ps1 -NoBrowser   # Start uten Ã¥ Ã¥pne nettleser
.\stop.ps1             # Stopp begge tjenester
.\bootstrap.ps1        # Manuell installasjon av avhengigheter
```

## Notater:

- Database: `%APPDATA%\KeyCabinetApp\keycabinet.db`
- Hardware: Rediger `agent/appsettings.json` for COM-port
- Loggfiler: `logs/`
- Downloads: `downloads/` (installasjonsfiler)
