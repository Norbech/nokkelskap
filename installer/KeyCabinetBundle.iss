; Inno Setup script for KeyCabinet local-server bundle
; Requires Inno Setup 6+ (ISCC.exe)

#define AppName "KeyCabinet"
#define AppPublisher "KeyCabinet"
#define AppVersion "1.0.0"
#define BundleDir "..\\bundle\\local-server"

[Setup]
AppId={{A7A0C5E0-77D9-4D7A-9E58-08B3C0B8A2C1}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
OutputDir=..\\dist
OutputBaseFilename=KeyCabinet-Setup
PrivilegesRequired=admin

[Languages]
Name: "norwegian"; MessagesFile: "compiler:Languages\\Norwegian.isl"

[Tasks]
Name: "desktopicon"; Description: "Lag skrivebordssnarvei"; GroupDescription: "Snarveier:"; Flags: unchecked
Name: "autostart"; Description: "Start automatisk ved innlogging"; GroupDescription: "Oppstart:"; Flags: unchecked

[Files]
; Install the entire bundle folder contents
Source: "{#BundleDir}\\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\\Start KeyCabinet"; Filename: "{app}\\START.cmd"; WorkingDir: "{app}"
Name: "{group}\\Stopp KeyCabinet"; Filename: "{app}\\STOPP.cmd"; WorkingDir: "{app}"
Name: "{group}\\Status"; Filename: "{sys}\\WindowsPowerShell\\v1.0\\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File \"{app}\\status-autostart.ps1\""; WorkingDir: "{app}"
Name: "{commondesktop}\\Start KeyCabinet"; Filename: "{app}\\START.cmd"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; Always configure agent COM port based on wizard selection
Filename: "{sys}\\WindowsPowerShell\\v1.0\\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command \"$p='{code:GetSelectedComPort}'; $path=Join-Path '{app}' 'agent\\appsettings.json'; if (Test-Path $path) { $json=Get-Content $path -Raw | ConvertFrom-Json; if ($null -ne $json.SerialCommunication) { $json.SerialCommunication.PortName=$p }; $json | ConvertTo-Json -Depth 64 | Set-Content -Encoding UTF8 $path }\""; WorkingDir: "{app}"; Flags: runhidden

; Optional: install autostart tasks (runs elevated because installer is admin)
Filename: "{sys}\\WindowsPowerShell\\v1.0\\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File \"{app}\\install-autostart.ps1\""; WorkingDir: "{app}"; Tasks: autostart; Flags: runhidden

; Optional: start once at the end (kept OFF by default)
; Filename: "{app}\\START.cmd"; WorkingDir: "{app}"; Flags: postinstall nowait

[Code]
var
	ComPortPage: TWizardPage;
	ComPortCombo: TNewComboBox;
	ComPortHint: TNewStaticText;
	ComPortTestButton: TNewButton;

function IsValidComPort(const Value: string): Boolean;
var
	s: string;
	i: Integer;
begin
	Result := False;
	s := Trim(Value);
	if Length(s) < 4 then Exit;
	if (Uppercase(Copy(s, 1, 3)) <> 'COM') then Exit;
	for i := 4 to Length(s) do begin
		if (s[i] < '0') or (s[i] > '9') then Exit;
	end;
	Result := True;
end;

procedure AddComPortIfValid(const Port: string);
var
	p: string;
begin
	p := Trim(Port);
	if (p <> '') and IsValidComPort(p) then begin
		ComPortCombo.Items.Add(p);
	end;
end;

procedure PopulateComPorts;
var
	PortsFile: string;
	Cmd: string;
	ResultCode: Integer;
	Contents: string;
	Line: string;
	i: Integer;
begin
	PortsFile := ExpandConstant('{tmp}\\keycabinet-ports.txt');

	{ Use .NET API from PowerShell to list available serial ports }
	Cmd := '[System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object | Out-File -Encoding ascii -FilePath ' + QuotedStr(PortsFile);
	Exec(ExpandConstant('{sys}\\WindowsPowerShell\\v1.0\\powershell.exe'),
			 '-NoProfile -ExecutionPolicy Bypass -Command ' + AddQuotes(Cmd),
			 '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

	if LoadStringFromFile(PortsFile, Contents) then begin
		{ Normalize line endings }
		StringChangeEx(Contents, #13#10, #10, True);
		StringChangeEx(Contents, #13, #10, True);

		Line := '';
		for i := 1 to Length(Contents) do begin
			if Contents[i] = #10 then begin
				AddComPortIfValid(Line);
				Line := '';
			end else begin
				Line := Line + Contents[i];
			end;
		end;
		AddComPortIfValid(Line);
	end;

	{ Fallback if nothing detected }
	if ComPortCombo.Items.Count = 0 then begin
		ComPortCombo.Items.Add('COM1');
		ComPortCombo.Items.Add('COM2');
		ComPortCombo.Items.Add('COM3');
		ComPortCombo.Items.Add('COM4');
		ComPortCombo.Items.Add('COM5');
		ComPortCombo.Items.Add('COM6');
	end;

	{ Default selection: if COM6 exists, choose it; else choose first }
	if ComPortCombo.Items.IndexOf('COM6') >= 0 then
		ComPortCombo.ItemIndex := ComPortCombo.Items.IndexOf('COM6')
	else
		ComPortCombo.ItemIndex := 0;
end;

procedure TestComPortClick(Sender: TObject);
var
	Port: string;
	Cmd: string;
	ResultCode: Integer;
begin
	Port := Trim(ComPortCombo.Text);
	if not IsValidComPort(Port) then begin
		MsgBox('Ugyldig COM-port. Velg en port som ser slik ut: COM6', mbError, MB_OK);
		Exit;
	end;

	{ Try to open the serial port (9600 8N1) and close it immediately }
	Cmd :=
		'try { ' +
		'$p = New-Object System.IO.Ports.SerialPort ' + QuotedStr(Port) + ',9600,''None'',8,''One''; ' +
		'$p.ReadTimeout = 500; $p.WriteTimeout = 500; $p.Open(); Start-Sleep -Milliseconds 150; $p.Close(); ' +
		'Write-Host ''OK''; exit 0 ' +
		'} catch { Write-Host $_.Exception.Message; exit 1 }';

	Exec(ExpandConstant('{sys}\\WindowsPowerShell\\v1.0\\powershell.exe'),
			 '-NoProfile -ExecutionPolicy Bypass -Command ' + AddQuotes(Cmd),
			 '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

	if ResultCode = 0 then begin
		MsgBox('OK! Klarte å åpne ' + Port + '.', mbInformation, MB_OK);
	end else begin
		MsgBox('Kunne ikke åpne ' + Port + '.\r\n\r\nSjekk at adapteren er plugget inn og at riktig port er valgt.', mbError, MB_OK);
	end;
end;

procedure InitializeWizard;
begin
	ComPortPage := CreateCustomPage(wpSelectTasks, 'Maskinvare', 'Velg COM-port for RS485-adapteren');

	ComPortHint := TNewStaticText.Create(ComPortPage);
	ComPortHint.Parent := ComPortPage.Surface;
	ComPortHint.Left := 0;
	ComPortHint.Top := 0;
	ComPortHint.Width := ComPortPage.SurfaceWidth;
	ComPortHint.Caption :=
		'Velg COM-port som USB→RS485-adapteren bruker (f.eks. COM6). ' +
		'Denne settes automatisk i agent\\appsettings.json.';

	ComPortCombo := TNewComboBox.Create(ComPortPage);
	ComPortCombo.Parent := ComPortPage.Surface;
	ComPortCombo.Left := 0;
	ComPortCombo.Top := ComPortHint.Top + ComPortHint.Height + ScaleY(12);
	ComPortCombo.Width := ScaleX(240);
	ComPortCombo.Style := csDropDown;

	ComPortTestButton := TNewButton.Create(ComPortPage);
	ComPortTestButton.Parent := ComPortPage.Surface;
	ComPortTestButton.Left := ComPortCombo.Left + ComPortCombo.Width + ScaleX(12);
	ComPortTestButton.Top := ComPortCombo.Top;
	ComPortTestButton.Width := ScaleX(140);
	ComPortTestButton.Caption := 'Test port';
	ComPortTestButton.OnClick := @TestComPortClick;

	PopulateComPorts;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
	Result := True;
	if CurPageID = ComPortPage.ID then begin
		if not IsValidComPort(ComPortCombo.Text) then begin
			MsgBox('Ugyldig COM-port. Velg en port som ser slik ut: COM6', mbError, MB_OK);
			Result := False;
		end;
	end;
end;

function GetSelectedComPort(Param: string): string;
begin
	Result := Trim(ComPortCombo.Text);
	if Result = '' then Result := 'COM6';
end;
