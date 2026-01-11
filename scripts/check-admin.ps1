$dbPath = "$env:APPDATA\KeyCabinetApp\keycabinet.db"

Add-Type -Path "C:\Program Files\dotnet\shared\Microsoft.NETCore.App\8.0.*\System.Data.Common.dll"

$connectionString = "Data Source=$dbPath"
$connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)

try {
    # Try to load SQLite provider
    [System.Reflection.Assembly]::LoadWithPartialName("System.Data.SQLite") | Out-Null
    
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = "SELECT Id, Name, Username, IsAdmin, IsActive FROM Users WHERE Username = 'admin'"
    
    $reader = $command.ExecuteReader()
    
    while ($reader.Read()) {
        Write-Host "ID: $($reader['Id'])"
        Write-Host "Name: $($reader['Name'])"
        Write-Host "Username: $($reader['Username'])"  
        Write-Host "IsAdmin: $($reader['IsAdmin'])"
        Write-Host "IsActive: $($reader['IsActive'])"
    }
    
    $reader.Close()
}
catch {
    Write-Host "Error: $_"
    Write-Host "Trying alternate method..."
    
    # Alternative: Just read the file size to confirm it exists
    if (Test-Path $dbPath) {
        $size = (Get-Item $dbPath).Length
        Write-Host "Database exists at $dbPath"
        Write-Host "Size: $size bytes"
    }
}
finally {
    if ($connection.State -eq 'Open') {
        $connection.Close()
    }
}
