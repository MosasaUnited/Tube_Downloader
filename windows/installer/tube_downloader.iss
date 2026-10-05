; Inno Setup 6 script: per-user installer for Tube DL (no admin prompt).
; Build the app first:  flutter build windows --release -t lib/main_prod.dart
; Then:                 iscc windows\installer\tube_downloader.iss
; Not yet verified on Windows: see docs/release.md.

#define AppName "Tube DL"
#define AppVersion "1.0.0"          ; keep in step with pubspec.yaml
#define AppExe "tube_downloader.exe"

[Setup]
; Never change AppId: Windows uses it to find the installed app on upgrade.
AppId={{CF7C347F-9AF0-47A2-A972-ABDE1DA4900E}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Tube Downloader
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\build\windows\installer
OutputBaseFilename=TubeDL-{#AppVersion}-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Files]
; The whole Release folder: the exe, Flutter, the plugins and FFmpeg DLLs, data\.
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
