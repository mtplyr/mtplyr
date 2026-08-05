; Inno Setup Skript fuer den Vela-Windows-Installer (Vela-Setup.exe).
; Installiert pro Benutzer (kein Admin noetig), mit Startmenue- + Desktop-Icon.
#define MyAppName "Vela"
#define MyAppVersion "1.0.34"
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

[Icons]
Name: "{autoprograms}\Vela"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Vela"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,Vela}"; Flags: nowait postinstall skipifsilent
