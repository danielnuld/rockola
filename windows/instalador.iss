; El instalador de Rockola para Windows: un solo .exe para la release.
; Flutter de escritorio deja una carpeta (rockola.exe, DLLs y data\); esto la empaqueta.
; Lo compila .github/workflows/windows.yml:  iscc /DVersion=0.2.0 windows\instalador.iss

#ifndef Version
  #define Version "0.0.0"
#endif

[Setup]
; No cambiar: Windows reconoce las actualizaciones por este id.
AppId={{28024015-FE16-4064-B294-B869306CC314}
AppName=Rockola
AppVersion={#Version}
AppVerName=Rockola {#Version}
AppPublisher=Daniel Noé Núñez López
AppPublisherURL=https://danielnuld.github.io/rockola/
AppSupportURL=https://github.com/danielnuld/rockola/issues
; En la carpeta del usuario: sin permisos de administrador.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\Rockola
DisableProgramGroupPage=yes
DisableDirPage=yes
OutputDir=..\build\instalador
OutputBaseFilename=RockolaSetup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\rockola.exe
UninstallDisplayName=Rockola
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "escritorio"; Description: "Crear un acceso en el escritorio"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{userprograms}\Rockola"; Filename: "{app}\rockola.exe"
Name: "{userdesktop}\Rockola"; Filename: "{app}\rockola.exe"; Tasks: escritorio

[Run]
Filename: "{app}\rockola.exe"; Description: "Abrir Rockola"; Flags: nowait postinstall skipifsilent
