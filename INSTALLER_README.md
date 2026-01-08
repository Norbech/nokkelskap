# Installer (Wizard) for KeyCabinet

Dette repoet kan bygge en vanlig Windows-"install wizard" (EXE) som:
- kopierer `bundle/local-server` til `C:\Program Files\KeyCabinet`
- lager snarveier i Start-meny (og ev. skrivebord)
- kan (valgfritt) sette opp autostart via Task Scheduler
- lar deg velge COM-port i wizard og skriver det inn i `agent/appsettings.json`

## Krav
- Windows
- Inno Setup 6 (for å kompilere installer)
  - `ISCC.exe` ligger vanligvis i: `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`

## Bygg installer
Kjør i repo-roten:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-installer.ps1
```

Standard er `-SelfContained` (større installer, men krever ikke .NET installert på målmaskinen). For å skru av:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-installer.ps1 -SelfContained:$false
```

Hvis Inno Setup er installert et annet sted:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-installer.ps1 -IsccPath "C:\Path\To\ISCC.exe"
```

Installer-output havner i `dist\KeyCabinet-Setup.exe`.

## Installere på en PC
1. Kjør `KeyCabinet-Setup.exe`
2. Velg om du vil:
   - lage skrivebordssnarvei
   - aktivere autostart (Task Scheduler)

Etterpå kan du starte via Start-meny: **Start KeyCabinet**.

## Notat om autostart
RFID global keyboard hook krever interaktiv bruker-sesjon. Derfor brukes Task Scheduler "At logon" (ikke Windows Service).
