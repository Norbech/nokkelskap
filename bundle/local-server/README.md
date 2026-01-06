# Local server bundle

Contents:
- `web/` Published KeyCabinetApp.Web
- `agent/` Published KeyCabinetApp.HardwareAgent
- `run.ps1` Starts both (logs in `logs/`)
- `stop.ps1` Stops both
- `config/` Reference appsettings files
- `cloudflare/` Cloudflared templates

Run:
- `./run.ps1` (default binds URLs to `http://127.0.0.1:5000`)
- `./stop.ps1`

Notes:
- The database is created/used at `%APPDATA%\KeyCabinetApp\keycabinet.db`.
- Edit `agent/appsettings.json` on the server to match COM port and hardware settings.
