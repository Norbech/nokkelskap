# 🔧 RFID Innlogging - Løsning

## Problemet
RFID-innlogging fungerte ikke fordi HardwareAgent-vinduet må være aktivt og ha fokus når du skanner RFID-kortet.

## ✅ Løsningen

### 1. **Sørg for at HardwareAgent-vinduet har fokus**
   - Et PowerShell-vindu med teksten "Hardware Agent - Skann RFID-kort her!" skal være åpent
   - **Klikk i dette vinduet før du skanner kortet**
   - RFID-leseren sender data som tastaturinput, så vinduet må være aktivt

### 2. **Skann RFID-kortet**
   - Hold kortet mot RFID-leseren
   - Pass på at HardwareAgent-vinduet har fokus
   - Du vil se RFID-nummeret dukke opp i konsollen
   - Data sendes automatisk til web-serveren
   - Innlogging skjer automatisk i nettleseren

### 3. **Hvis det fortsatt ikke fungerer:**

**Test RFID-leseren:**
```powershell
# Åpne Notepad
notepad

# Skann RFID-kort - du skal se tallene dukke opp i Notepad
# Noter ID-nummeret som vises
```

**Sjekk at riktig RFID er registrert i databasen:**
1. Logg inn i web-appen med brukernavn/passord
2. Gå til brukeradministrasjon (admin)
3. Sjekk at RFID-nummeret matcher det du så i Notepad-testen
4. Hvis ikke, oppdater brukerens RFID-nummer

## 📝 Registrerte brukere

### Admin
- **RFID**: `0014571466`
- **Brukernavn**: `admin`
- **Passord**: `admin123`

### Test bruker
- **RFID**: Ikke satt (kan legges til)
- **Brukernavn**: `testuser`
- **Passord**: `test123`

## 🎯 Steg-for-steg RFID innlogging

1. **Start systemet** (hvis ikke allerede kjørende):
   ```powershell
   cd "C:\Users\andre\Desktop\nøkkelskap\nokkelskap"
   .\start-local.ps1
   ```

2. **Åpne web-appen** i nettleser:
   - Gå til: http://localhost:5000
   - Du vil se RFID-innloggingsskjermen

3. **Klikk i HardwareAgent-vinduet** (PowerShell med grønn tekst)

4. **Skann RFID-kort**:
   - Hold kortet mot leseren
   - RFID-nummer vises i HardwareAgent-vinduet
   - Logger automatisk inn i web-appen

5. **Ferdig!** Du er nå logget inn

## 🔍 Feilsøking

### Problem: Ingen respons når jeg skanner
**Sjekk:**
- [ ] Har HardwareAgent-vinduet fokus? (klikk i vinduet)
- [ ] Kjører HardwareAgent? (se PowerShell-vindu)
- [ ] Er RFID-leseren tilkoblet USB?
- [ ] Fungerer RFID-leseren i Notepad?

### Problem: "Ingen bruker funnet" feilmelding
**Løsning:**
1. Test RFID i Notepad og noter nummeret
2. Logg inn med brukernavn/passord
3. Gå til brukeradministrasjon
4. Oppdater/legg til RFID-nummer på brukeren
5. Logg ut og test RFID på nytt

### Problem: HardwareAgent crasher eller viser feil
**Løsning:**
```powershell
# Stopp alt
cd "C:\Users\andre\Desktop\nøkkelskap\nokkelskap"
.\stop-local.ps1

# Start på nytt
.\start-local.ps1
```

## 💡 Tips

### Hvordan legge til nytt RFID-kort på en bruker:

1. **Test kortet først:**
   - Åpne Notepad
   - Skann kortet
   - Kopier RFID-nummeret

2. **Oppdater bruker:**
   - Logg inn som admin i web-appen
   - Gå til brukeradministrasjon
   - Rediger bruker
   - Lim inn RFID-nummer
   - Lagre

3. **Test:**
   - Logg ut
   - Klikk i HardwareAgent-vinduet
   - Skann kortet
   - Skal automatisk logge inn

## 🎨 Visuell guide

```
┌─────────────────────────────────────┐
│ HardwareAgent-vindu (PowerShell)    │
│ Hardware Agent - Skann RFID her!    │ ← KLIKK HER FØRST!
│                                     │
│ Waiting for RFID scans...           │
│ [Her vises RFID når du skanner]     │
└─────────────────────────────────────┘
         ↑
         │ RFID-leser sender data hit
         │
    [Hold kortet her]


┌─────────────────────────────────────┐
│ Nettleser (localhost:5000)          │
│                                     │
│  [RFID-ikon]                        │
│  Skann RFID-kort eller logg inn     │
│  med brukernavn                     │
│                                     │
│  [LOGG INN MED BRUKERNAVN]          │ ← Alternativ metode
└─────────────────────────────────────┘
         ↑
         │ Logger automatisk inn
         │ når RFID skannes
```

## 📊 Teknisk forklaring

**Dataflyt:**
1. RFID-leser (USB keyboard wedge) → sender tastaturinput
2. HardwareAgent-vindu (må ha fokus) → mottar input
3. ConsoleRfidReader → validerer og prosesserer RFID-nummer
4. SignalR → sender til web-server
5. Web-server → autentiserer bruker
6. Nettleser → logger automatisk inn

**Viktig:** RFID-leseren fungerer som et tastatur. Den sender data til vinduet som har fokus. Derfor MÅ HardwareAgent-vinduet være aktivt når du skanner.

---

**Sist oppdatert:** 8. januar 2026
