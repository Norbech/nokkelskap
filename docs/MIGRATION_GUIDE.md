# Migreringsguide: WPF Desktop → Blazor Web

## Hva har endret seg?

### Arkitektur

**Før (WPF Desktop):**
```
┌─────────────────────────┐
│   WPF Desktop App       │
│   - UI (XAML)           │
│   - ViewModels          │
│   - Services            │
│   - Direct hardware     │
└─────────────────────────┘
         │
         ├─► RFID-leser (USB)
         ├─► RS485 (COM-port)
         └─► SQLite database
```

**Nå (Blazor Web):**
```
┌─────────────┐    ┌──────────────┐    ┌───────────────┐
│  Nettleser  │◄──►│  Web Server  │◄──►│   Database    │
│  (Blazor)   │    │  (ASP.NET)   │    │   (SQLite)    │
└─────────────┘    └──────┬───────┘    └───────────────┘
                          │
                          │ SignalR
                          ▼
                   ┌──────────────┐
                   │ HW Agent (PC)│
                   │ - RFID       │
                   │ - RS485      │
                   └──────────────┘
```

### Kode-endringer

#### 1. ViewModels → Blazor Components

**Før (LoginViewModel.cs):**
```csharp
public class LoginViewModel : ViewModelBase
{
    private string _username;
    public string Username 
    { 
        get => _username; 
        set => SetProperty(ref _username, value); 
    }
    
    public ICommand LoginCommand { get; }
}
```

**Nå (Login.razor):**
```razor
@code {
    private string Username { get; set; } = "";
    
    private async Task LoginAsync()
    {
        // Login logic
    }
}
```

#### 2. XAML → Razor/HTML

**Før (LoginView.xaml):**
```xml
<TextBox Text="{Binding Username}" 
         materialDesign:HintAssist.Hint="Brukernavn"/>
<Button Content="LOGG INN" 
        Command="{Binding LoginCommand}"/>
```

**Nå (Login.razor):**
```html
<input type="text" @bind="Username" placeholder="Brukernavn" />
<button @onclick="LoginAsync">LOGG INN</button>
```

#### 3. Hardware Communication

**Før (Direkte tilgang):**
```csharp
// I WPF-app
var _rfidReader = new KeyboardWedgeRfidReader();
var _serialComm = new Rs485Communication(config);
```

**Nå (Via proxy):**
```csharp
// I Web (proxy)
services.AddScoped<IRfidReader, RfidProxyService>();
services.AddScoped<ISerialCommunication, HardwareProxyService>();

// I Hardware Agent (faktisk hardware)
var _rfidReader = new KeyboardWedgeRfidReader();
var _serialComm = new Rs485Communication(config);
```

### Services - Gjenbrukt!

Disse er **ikke endret** og fungerer i begge versjoner:
- ✅ `AuthenticationService`
- ✅ `KeyControlService`
- ✅ `LoggingService`
- ✅ `ApplicationDbContext`
- ✅ Alle repositories
- ✅ Alle entities

## Deployment-forskjeller

### Desktop (WPF)
```powershell
# Bygge
dotnet publish -c Release

# Installere
- Kopier exe + DLL-er til hver PC
- Kjør setup.exe
```

### Web (Blazor)
```powershell
# Bygge
dotnet publish src/KeyCabinetApp.Web -c Release

# Installere
- Deploy til IIS/server én gang
- Hardware Agent på PC med hardware
- Brukere åpner URL i nettleser
```

## Fordeler med web-versjon

### For sluttbrukere
- ✅ Ingen installasjon
- ✅ Fungerer på Mac/Linux/mobil
- ✅ Alltid nyeste versjon
- ✅ Raskere oppstart

### For administratorer
- ✅ Én sentralisert installasjon
- ✅ Enklere oppdateringer
- ✅ Bedre logging/monitoring
- ✅ Flere brukere samtidig

### For utviklere
- ✅ Moderne web-stack
- ✅ Bedre debugging
- ✅ Hot reload
- ✅ Cross-platform

## Beholdte funksjoner

Alle funksjoner fra desktop-versjonen er bevart:
- ✅ RFID-innlogging
- ✅ Passord-innlogging
- ✅ Nøkkel-åpning via RS485
- ✅ Brukerhåndtering
- ✅ Hendelseslogg
- ✅ Admin-panel
- ✅ Database (samme struktur)

## Nye funksjoner

- 🆕 Real-time oppdateringer (SignalR)
- 🆕 Multi-bruker støtte
- 🆕 Mobilvenlig design
- 🆕 Remote admin fra andre PC-er
- 🆕 Bedre feilhåndtering

## Kjente begrensninger

### Desktop hadde:
- Direkte hardware-tilgang
- Offline-støtte

### Web krever:
- Nettverkstilgang til server
- Hardware Agent for RFID/RS485
- Aktiv internett-tilkobling (for remote)

## Performance

| Metrikk | Desktop | Web |
|---------|---------|-----|
| **Oppstartstid** | ~2 sek | < 1 sek (etter første last) |
| **Minnebruk** | ~100 MB | ~50 MB (browser) + 30 MB (server/bruker) |
| **RFID-respons** | ~200 ms | ~300 ms (via SignalR) |
| **UI-ytelse** | Utmerket | Utmerket (Blazor Server) |

## Migrering av eksisterende installasjon

### Trinn 1: Backup
```powershell
# Backup database
Copy-Item "$env:APPDATA\KeyCabinetApp\keycabinet.db" -Destination "backup.db"
```

### Trinn 2: Installer web-versjon
```powershell
# Start web server
dotnet run --project src/KeyCabinetApp.Web
```

### Trinn 3: Test
- Logg inn via browser
- Verifiser at data er der
- Test nøkkel-åpning

### Trinn 4: Deploy
- Installer web server på server
- Installer Hardware Agent på hardware-PC
- Distribuer URL til brukere

### Trinn 5: Avinstaller desktop
```powershell
# Fjern gamle desktop-installasjoner
# Behold database-backup!
```

## Support for begge versjoner

Du kan kjøre **både desktop og web** samtidig:
- Desktop-app: For direkte hardware-tilgang
- Web-app: For remote bruk

Begge deler samme database-struktur!

## Fremover

Web-versjonen er nå primær-plattformen:
- Nye funksjoner legges til i web
- Desktop-versjon er frozen (kun bugfixes)
- Migration path: Desktop → Web

---

**Spørsmål?** Se [WEB_README.md](WEB_README.md) for mer info!
