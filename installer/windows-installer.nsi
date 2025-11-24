!include "MUI2.nsh"

Name "Dvx3 Backup Manager"
OutFile "Dvx3-Backup-Manager-Installer.exe"
InstallDir "$PROGRAMFILES\\Dvx3 Backup Manager"

; Pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

Section "Install"
    SetOutPath "$INSTDIR"
    ; Extract the Release ZIP into the install dir
    ; This assumes the ZIP is bundled in the installer, we will add it during building
    SetOverwrite on
    File "Releases\\Dvx3-Backup-Manager-Windows.zip"

    ; Try to extract the zip using built-in NSIS capabilities (requires unzip plugin) or instruct user
    ; If the system doesn't have a built-in unzip, we leave the zip for users to extract manually
SectionEnd
