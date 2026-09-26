[Setup]
AppId={{6D9EAEB4-0B71-4FD0-9A1E-2B22DB0E5A71}
AppName=Elder Souls Content Studio
AppVersion=1.0.0
AppPublisher=Elder Souls
DefaultDirName={localappdata}\Programs\Elder Souls Content Studio
DefaultGroupName=Elder Souls
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=installer
OutputBaseFilename=Elder-Souls-Content-Studio-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=Elder Souls Content Studio

[Files]
Source: "dist\Elder Souls Content Studio\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Elder Souls Content Studio"; Filename: "{app}\Elder Souls Content Studio.exe"
Name: "{autodesktop}\Elder Souls Content Studio"; Filename: "{app}\Elder Souls Content Studio.exe"

[Run]
Filename: "{app}\Elder Souls Content Studio.exe"; Description: "Launch Elder Souls Content Studio"; Flags: nowait postinstall skipifsilent
