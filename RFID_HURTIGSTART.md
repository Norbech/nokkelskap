# ⚡ HURTIGSTART - RFID Innlogging

## 🎯 Enkle steg

### 1️⃣ Systemet kjører allerede
✅ Web Server: http://localhost:5000
✅ Hardware Agent: Se PowerShell-vindu med grønn tekst

### 2️⃣ For å logge inn med RFID:

```
1. KLIKK i HardwareAgent-vinduet
   (det med teksten "Hardware Agent - Skann RFID-kort her!")

2. HOLD RFID-kortet mot leseren

3. Du logger automatisk inn i nettleseren!
```

### 3️⃣ Første gang med nytt kort?

**Test kortet:**
- Åpne Notepad
- Skann kortet
- Kopier nummeret (f.eks. `0014571466`)

**Legg til på bruker:**
- Logg inn med brukernavn: `admin` / passord: `admin123`
- Gå til brukeradministrasjon  
- Legg til RFID-nummer på brukeren
- Lagre

**Test innlogging:**
- Logg ut
- **Klikk i HardwareAgent-vinduet** ⚠️
- Skann kortet
- ✅ Logget inn!

---

## ⚠️ Huskeregel

**RFID-leseren fungerer som et tastatur!**

Den sender data til vinduet som har fokus.
→ **HardwareAgent-vinduet MÅ være aktivt når du skanner**

---

## 📱 Alternativ innlogging

Hvis RFID ikke er tilgjengelig:
- Gå til http://localhost:5000
- Klikk "LOGG INN MED BRUKERNAVN"
- Brukernavn: `admin`
- Passord: `admin123`

---

## 🆘 Hjelp!

**Problem:** Ingenting skjer når jeg skanner
- ❌ Har du glemt å klikke i HardwareAgent-vinduet?
- ❌ Er RFID-leseren tilkoblet USB?
- ❌ Kjører HardwareAgent? (se PowerShell-vindu)

**Problem:** "Ingen bruker funnet"
- Riktig RFID-nummer registrert på brukeren?
- Test i Notepad og sammenlign med databasen

---

**Full dokumentasjon:** Se [RFID_GUIDE.md](RFID_GUIDE.md)
