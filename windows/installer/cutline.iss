; Inno Setup script for the Windows installer. Built by
; tool/package_windows.ps1, which passes the version and paths.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\dist"
#endif

[Setup]
; Keep this id: Windows uses it to recognise upgrades.
AppId={{6C5CE7E8-4393-4C1E-9A5D-C07C0711E000}
AppName=Cutline
AppVersion={#AppVersion}
AppPublisher=Cutline
AppPublisherURL=https://github.com/Umair0092/cutline
DefaultDirName={autopf}\Cutline
DefaultGroupName=Cutline
DisableProgramGroupPage=yes
; Per-user install by default, so no admin prompt; users can choose all users.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=Cutline-{#AppVersion}-windows-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\cutline.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Cutline"; Filename: "{app}\cutline.exe"
Name: "{autodesktop}\Cutline"; Filename: "{app}\cutline.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\cutline.exe"; Description: "{cm:LaunchProgram,Cutline}"; Flags: nowait postinstall skipifsilent
