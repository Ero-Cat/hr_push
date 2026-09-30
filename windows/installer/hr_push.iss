; HR PUSH Windows installer script (Inno Setup 6).
;
; Compile from the repo root:
;   ISCC /DMyAppVersion=1.8.2 windows\installer\hr_push.iss
;
; ChineseSimplified.isl is not bundled with Inno Setup; drop it next to this
; script (https://github.com/jrsoftware/issrc/tree/main/Files/Languages/Unofficial)
; to enable the Chinese installer UI. CI downloads it automatically and the
; #if guards keep local English/Japanese-only builds working without it.

#ifndef MyAppVersion
#define MyAppVersion "0.0.0"
#endif

#define MyAppName "HR PUSH"
#define MyAppExeName "hr_push.exe"
#define MyAppPublisher "EroCat"
#define MyAppURL "https://github.com/Ero-Cat/hr_push"

[Setup]
AppId={{9F3A5B7C-2D4E-4F6B-8A1C-3E5D7C9B0F21}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Program Files keeps the install path pure ASCII, which sidesteps the
; known "Chinese paths break the Windows build" issue for installed copies.
OutputBaseFilename=hr-push-windows-v{#MyAppVersion}-setup
OutputDir=..\..\build\windows\installer
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
#if FileExists(AddBackslash(CompilerPath) + "Languages\Japanese.isl")
Name: "ja"; MessagesFile: "compiler:Languages\Japanese.isl"
#endif
#if FileExists(AddBackslash(SourcePath) + "ChineseSimplified.isl")
Name: "chs"; MessagesFile: "ChineseSimplified.isl"
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
