; The Windows installer of EstudiCards (T6.7), made with Inno Setup
; (https://jrsoftware.org/isinfo.php). `release.yml` builds it after
; `flutter build windows`:
;
;   iscc /DAppVersion=1.0.0 /DSourceDir=<Release folder> /DOutputDir=<folder>
;        /DOutputName=<file name without .exe> windows\installer\estudicards.iss
;
; It installs for the current user only (in %LOCALAPPDATA%\Programs), so it
; does not ask for administrator rights, adds EstudiCards to the Start menu
; and to "Aplicaciones" to uninstall it. Uninstalling never touches the
; data folder the user chose (Documents\EstudiCards by default).

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\installer"
#endif
#ifndef OutputName
  #define OutputName "EstudiCards-setup"
#endif

[Setup]
; Tells Windows this is the same app on every update; it never changes
; (the app identifier, SPEC §13.2 assumption 70).
AppId=dev.ivalon.estudicards
AppName=EstudiCards
AppVersion={#AppVersion}
AppPublisher=ivalon
AppPublisherURL=https://github.com/ivanalonsoe/EstudiCards
DefaultDirName={autopf}\EstudiCards
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\estudicards.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Everything `flutter build windows` made, plus the Visual C++ libraries
; release.yml copies next to the app.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\EstudiCards"; Filename: "{app}\estudicards.exe"
Name: "{autodesktop}\EstudiCards"; Filename: "{app}\estudicards.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\estudicards.exe"; Description: "{cm:LaunchProgram,EstudiCards}"; Flags: nowait postinstall skipifsilent
