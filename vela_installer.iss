; Inno Setup Skript fuer den Vela-Windows-Installer (Vela-Setup.exe).
; Installiert pro Benutzer (kein Admin noetig), mit Startmenue- + Desktop-Icon.
#define MyAppName "Vela"
#define MyAppVersion "1.0.67"
#define MyAppPublisher "Vela"
#define MyAppExeName "velaplayer.exe"
#define RelDir "C:\Users\race1000.DESKTOP-5OG4MER\velaplayer\build\windows\x64\runner\Release"
#define IcoFile "C:\Users\race1000.DESKTOP-5OG4MER\velaplayer\windows\runner\resources\app_icon.ico"

[Setup]
AppId={{7F3C1A20-5E44-4B2A-9F3E-56454C41504C}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Vela
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=D:\
OutputBaseFilename=Vela-Setup
SetupIconFile={#IcoFile}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#RelDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "C:\Users\race1000.DESKTOP-5OG4MER\velaplayer\Vela-Clean.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Vela"; Filename: "{app}\{#MyAppExeName}"
Name: "{autoprograms}\Vela zuruecksetzen"; Filename: "{app}\Vela-Clean.bat"
Name: "{autodesktop}\Vela"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,Vela}"; Flags: nowait postinstall skipifsilent

; Programmordner beim Deinstallieren komplett entfernen.
[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
// Bei der Installation: alte Vela-Daten erkennen und fragen, ob sie geloescht werden sollen
// (sauberer Neustart). Daten liegen ausserhalb des Programmordners und bleiben sonst erhalten.
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    if DirExists(ExpandConstant('{userappdata}\com.vela')) or DirExists(ExpandConstant('{localappdata}\com.vela')) then
    begin
      if MsgBox('Es wurden bereits Vela-Daten einer frÃ¼heren Installation gefunden (Playlists, Einstellungen, Cache).'#13#10#13#10'Alles lÃ¶schen und sauber neu starten?'#13#10#13#10'Existing Vela data found. Delete everything for a clean start?', mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      begin
        DelTree(ExpandConstant('{userappdata}\com.vela'), True, True, True);
        DelTree(ExpandConstant('{localappdata}\com.vela'), True, True, True);
        DelTree(ExpandConstant('{localappdata}\Temp\vela_m3u_*.cache'), False, True, False);
        DelTree('D:\VelaDownloads', True, True, True);
      end;
    end;
  end;
end;

// Beim Deinstallieren fragen, ob auch die App-Daten (Playlists, Einstellungen, Cache,
// Downloads) geloescht werden sollen. Die liegen ausserhalb des Programmordners und
// bleiben sonst erhalten (damit man bei Updates seine Playlists nicht verliert).
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    if MsgBox('Auch deine Playlists, Einstellungen, den Cache und die Downloads lÃ¶schen?'#13#10#13#10'Also delete your playlists, settings, cache and downloads?', mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
    begin
      DelTree(ExpandConstant('{userappdata}\com.vela'), True, True, True);
      DelTree(ExpandConstant('{localappdata}\com.vela'), True, True, True);
      DelTree(ExpandConstant('{localappdata}\Temp\vela_m3u_*.cache'), False, True, False);
      DelTree('D:\VelaDownloads', True, True, True);
    end;
  end;
end;
