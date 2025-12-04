# Quick Setup Guide

## 1. First Time Setup

### Install Prerequisites
```powershell
# Verify .NET 8.0 is installed
dotnet --version
```

If not installed, download from: https://dotnet.microsoft.com/download/dotnet/8.0

### Build the Application
```powershell
# From project root directory
.\build.ps1
```

Or manually:
```powershell
dotnet restore
dotnet build
```

## 2. Configure Hardware

### Find Your COM Port
```powershell
Get-WmiObject Win32_SerialPort | Select-Object DeviceID,Description
```

Or use Device Manager → Ports (COM & LPT)

### Edit Configuration
Open: `src\KeyCabinetApp.UI\appsettings.json`

Update:
```json
{
  "SerialCommunication": {
    "PortName": "COM3",  // ← Change this to your COM port
    "BaudRate": 9600,    // ← Match your controller
    "SlotCommands": {
      "1": "01 05 00 01 FF 00 DD FA"  // ← Your command bytes
    }
  }
}
```

## 3. Run the Application

### Development Mode
```powershell
cd src\KeyCabinetApp.UI
dotnet run
```

### Production Build
```powershell
.\publish.ps1
```

Then copy `publish\KeyCabinetApp\` folder to your tablet.

## 4. Initial Login

**Default Admin Account:**
- Username: `admin`
- Password: `admin123`

**⚠️ CHANGE THIS PASSWORD IMMEDIATELY!**

**Test User:**
- Username: `testuser`
- Password: `test123`
- RFID: `1234567890`

## 5. Test RFID Reader

1. Open Notepad
2. Scan an RFID card
3. Card ID should appear as text
4. Note the card ID for user setup

## 6. Configure Your Keys

### Example: Add a New Key

Open database: `%APPDATA%\KeyCabinetApp\keycabinet.db`

```sql
-- Add key
INSERT INTO Keys (SlotId, Name, Description, IsActive, CreatedAt)
VALUES (6, 'My New Key', 'Description', 1, datetime('now'));

-- Give user access
INSERT INTO UserKeyAccess (UserId, KeyId, GrantedAt)
VALUES (1, 6, datetime('now'));
```

**Important:** SlotId must match your `appsettings.json` SlotCommands!

## 7. Kiosk Mode Setup

### Auto-Start on Boot
1. Build application: `.\publish.ps1`
2. Copy `publish\KeyCabinetApp\` to tablet
3. Create shortcut to `KeyCabinetApp.UI.exe`
4. Place shortcut in:
   ```
   %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
   ```

### Disable Sleep
```powershell
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
```

## 8. Troubleshooting

### Serial Port Not Found
```powershell
# List all COM ports
[System.IO.Ports.SerialPort]::GetPortNames()
```

Update `PortName` in `appsettings.json`

### RFID Not Working
- Test in Notepad first
- Verify USB connection
- Check reader mode (should be keyboard wedge)

### Database Issues
```powershell
# Location
explorer "$env:APPDATA\KeyCabinetApp"

# Backup
Copy-Item "$env:APPDATA\KeyCabinetApp\keycabinet.db" `
    "$env:APPDATA\KeyCabinetApp\keycabinet.db.backup"
```

## 9. Quick Commands

### Build
```powershell
.\build.ps1
```

### Publish for Deployment
```powershell
.\publish.ps1
```

### Run Development Mode
```powershell
cd src\KeyCabinetApp.UI
dotnet run
```

### Clean Build
```powershell
dotnet clean
dotnet build --configuration Release
```

## 10. Keyboard Shortcuts

When running:
- **ESC** - Exit fullscreen (for testing)
- **F11** - Toggle fullscreen
- **Ctrl+C** - Stop application (when run from terminal)

## Need More Help?

See full documentation in `README.md`
