; ============================================================================
; Next N — Modern Windows Installer Script (NSIS 3 + MUI2)
; Repository: https://github.com/EbramJames/Next-N
; Publisher:  EbramJames
; License:    GNU GPL v3.0
; ============================================================================

Unicode True
SetCompressor /SOLID lzma
SetCompressorDictSize 32

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "x64.nsh"

; Build-time parameters (can be overridden via makensis /D...)
!ifndef APP_VERSION
  !define APP_VERSION "1.0.0"
!endif
!ifndef APP_ARCH
  !define APP_ARCH "x64"
!endif
!ifndef STAGE_DIR
  !define STAGE_DIR "..\..\dist\stage-win-x64"
!endif
!ifndef OUTPUT_EXE
  !define OUTPUT_EXE "..\..\dist\NextN-Setup-x64.exe"
!endif

!define APP_NAME "Next N"
!define APP_SLUG "NextN"
!define APP_EXE "NextN.exe"
!define APP_PUBLISHER "EbramJames"
!define APP_URL "https://github.com/EbramJames/Next-N"
!define APP_REG_UNINSTALL "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_SLUG}"
!define APP_REG_RUN "Software\Microsoft\Windows\CurrentVersion\Run"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "${OUTPUT_EXE}"
InstallDir "$PROGRAMFILES64\${APP_NAME}"
InstallDirRegKey HKLM "${APP_REG_UNINSTALL}" "InstallLocation"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show
BrandingText "${APP_NAME} ${APP_VERSION}  •  github.com/EbramJames/Next-N"

; Version info embedded into Setup EXE properties
VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "CompanyName" "${APP_PUBLISHER}"
VIAddVersionKey "LegalCopyright" "Copyright © 2026 ${APP_PUBLISHER} (GPL-3.0)"
VIAddVersionKey "FileDescription" "${APP_NAME} Installer (${APP_ARCH})"
VIAddVersionKey "FileVersion" "${APP_VERSION}.0"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"

; ----------------------------------------------------------------------------
; Modern UI 2 Theme & Custom Next N Branding
; ----------------------------------------------------------------------------
!define MUI_ABORTWARNING
!define MUI_ICON "NextN.ico"
!define MUI_UNICON "NextN.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "sidebar.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "sidebar.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP "header.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "header.bmp"

!define MUI_WELCOMEPAGE_TITLE "Welcome to ${APP_NAME} Setup"
!define MUI_WELCOMEPAGE_TEXT "This wizard will install ${APP_NAME} ${APP_VERSION} (${APP_ARCH}) on your computer.$\r$\n$\r$\n${APP_NAME} is a modern, cross-platform network proxy client powered by Xray-core and sing-box with native TUN mode, smart routing, and a clean unified interface.$\r$\n$\r$\nClick Next to continue."

!define MUI_FINISHPAGE_TITLE "${APP_NAME} Installed Successfully"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${APP_NAME} now"
!define MUI_FINISHPAGE_LINK "Visit ${APP_NAME} on GitHub"
!define MUI_FINISHPAGE_LINK_LOCATION "${APP_URL}"

; Installer pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\..\LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; Languages
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Farsi"
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "Russian"
!insertmacro MUI_LANGUAGE "French"

; ----------------------------------------------------------------------------
; Helper Functions
; ----------------------------------------------------------------------------
Function .onInit
  ${If} "${APP_ARCH}" == "x64"
    ${IfNot} ${RunningX64}
      MessageBox MB_OK|MB_ICONSTOP "This 64-bit installer requires 64-bit Windows."
      Abort
    ${EndIf}
    SetRegView 64
  ${EndIf}
FunctionEnd

Function un.onInit
  ${If} "${APP_ARCH}" == "x64"
    SetRegView 64
  ${EndIf}
FunctionEnd

!macro StopRunningProcesses
  DetailPrint "Stopping running ${APP_NAME} and proxy core processes..."
  nsExec::ExecToLog 'taskkill /F /IM "${APP_EXE}" /T'
  nsExec::ExecToLog 'taskkill /F /IM "xray.exe" /T'
  nsExec::ExecToLog 'taskkill /F /IM "sing-box.exe" /T'
  nsExec::ExecToLog 'taskkill /F /IM "mihomo.exe" /T'
  Sleep 600
!macroend

; ----------------------------------------------------------------------------
; Installer Sections
; ----------------------------------------------------------------------------
Section "${APP_NAME} Application (Required)" SecCore
  SectionIn RO

  !insertmacro StopRunningProcesses

  SetOutPath "$INSTDIR"
  File /r "${STAGE_DIR}\*.*"

  ; Ensure installed mode always stores user profiles/config safely in %LOCALAPPDATA%\NextN
  ; (consistent across normal user and Administrator/TUN launches, preserved across upgrades)
  FileOpen $0 "$INSTDIR\NotStoreConfigHere.txt" w
  FileWrite $0 "Installed by Next N Setup. User data is stored in %LOCALAPPDATA%\NextN."
  FileClose $0

  ; Create Uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Compute Installed Size for Windows Installed Apps
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0

  ; Register in Add/Remove Programs
  WriteRegStr   HKLM "${APP_REG_UNINSTALL}" "DisplayName"     "${APP_NAME}"
  WriteRegStr   HKLM "${APP_REG_UNINSTALL}" "DisplayVersion"  "${APP_VERSION}"
  WriteRegStr   HKLM "${APP_REG_UNINSTALL}" "Publisher"       "${APP_PUBLISHER}"
  WriteRegStr   HKLM "${APP_REG_UNINSTALL}" "URLInfoAbout"    "${APP_URL}"
  WriteRegStr   HKLM "${APP_REG_UNINSTALL}" "DisplayIcon"     "$INSTDIR\${APP_EXE},0"
  WriteRegStr   HKLM "${APP_REG_UNINSTALL}" "InstallLocation" "$INSTDIR"
  WriteRegStr   HKLM "${APP_REG_UNINSTALL}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr   HKLM "${APP_REG_UNINSTALL}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKLM "${APP_REG_UNINSTALL}" "NoModify"        1
  WriteRegDWORD HKLM "${APP_REG_UNINSTALL}" "NoRepair"        1
  WriteRegDWORD HKLM "${APP_REG_UNINSTALL}" "EstimatedSize"   "$0"
SectionEnd

Section "Start Menu Shortcuts" SecStartMenu
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk" "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Desktop Shortcut" SecDesktop
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0
SectionEnd

Section /o "Launch ${APP_NAME} at Windows Startup" SecAutoStart
  WriteRegStr HKCU "${APP_REG_RUN}" "NextNAutoRun" '"$INSTDIR\${APP_EXE}"'
SectionEnd

; Component descriptions (all 5 installer languages — zero warnings)
LangString DESC_SecCore      ${LANG_ENGLISH}     "Core Next N desktop application, bundled Xray-core and sing-box engines, and routing rule databases."
LangString DESC_SecStartMenu ${LANG_ENGLISH}     "Adds Next N and Uninstall shortcuts to the Windows Start Menu."
LangString DESC_SecDesktop   ${LANG_ENGLISH}     "Creates a Next N shortcut on your Desktop."
LangString DESC_SecAutoStart ${LANG_ENGLISH}     "Automatically starts Next N when you sign in to Windows."

LangString DESC_SecCore      ${LANG_FARSI}       "برنامه اصلی Next N همراه با هسته‌های Xray و sing-box و پایگاه‌های مسیریابی."
LangString DESC_SecStartMenu ${LANG_FARSI}       "ایجاد میانبر Next N در منوی استارت ویندوز."
LangString DESC_SecDesktop   ${LANG_FARSI}       "ایجاد میانبر Next N روی دسکتاپ."
LangString DESC_SecAutoStart ${LANG_FARSI}       "اجرای خودکار Next N هنگام ورود به ویندوز."

LangString DESC_SecCore      ${LANG_SIMPCHINESE} "Next N 核心桌面客户端，内置 Xray-core、sing-box 及路由规则库。"
LangString DESC_SecStartMenu ${LANG_SIMPCHINESE} "在 Windows 开始菜单中创建 Next N 快捷方式。"
LangString DESC_SecDesktop   ${LANG_SIMPCHINESE} "在桌面创建 Next N 快捷方式。"
LangString DESC_SecAutoStart ${LANG_SIMPCHINESE} "登录 Windows 时自动启动 Next N。"

LangString DESC_SecCore      ${LANG_RUSSIAN}     "Основное приложение Next N со встроенными ядрами Xray-core, sing-box и базами маршрутизации."
LangString DESC_SecStartMenu ${LANG_RUSSIAN}     "Добавляет ярлыки Next N в меню Пуск Windows."
LangString DESC_SecDesktop   ${LANG_RUSSIAN}     "Создаёт ярлык Next N на рабочем столе."
LangString DESC_SecAutoStart ${LANG_RUSSIAN}     "Автоматически запускать Next N при входе в Windows."

LangString DESC_SecCore      ${LANG_FRENCH}      "Application principale Next N avec Xray-core, sing-box et bases de routage intégrées."
LangString DESC_SecStartMenu ${LANG_FRENCH}      "Ajoute les raccourcis Next N dans le menu Démarrer."
LangString DESC_SecDesktop   ${LANG_FRENCH}      "Crée un raccourci Next N sur le Bureau."
LangString DESC_SecAutoStart ${LANG_FRENCH}      "Démarre Next N automatiquement à l'ouverture de session Windows."

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecCore}      $(DESC_SecCore)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStartMenu} $(DESC_SecStartMenu)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop}   $(DESC_SecDesktop)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecAutoStart} $(DESC_SecAutoStart)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ----------------------------------------------------------------------------
; Uninstaller Section
; ----------------------------------------------------------------------------
Section "Uninstall"
  !insertmacro StopRunningProcesses

  ; Remove Shortcuts
  Delete "$DESKTOP\${APP_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${APP_NAME}"

  ; Remove Auto-Start & Registry Entries
  DeleteRegValue HKCU "${APP_REG_RUN}" "NextNAutoRun"
  DeleteRegKey   HKLM "${APP_REG_UNINSTALL}"

  ; Remove Installation Directory
  RMDir /r "$INSTDIR"

  ; Optionally remove user profile data in %LOCALAPPDATA%\NextN (interactive uninstall only)
  IfSilent skip_userdata
  IfFileExists "$LOCALAPPDATA\${APP_SLUG}\*.*" 0 skip_userdata
    MessageBox MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2 \
      "Do you also want to delete your saved ${APP_NAME} servers, subscriptions, and settings in $LOCALAPPDATA\${APP_SLUG}?" \
      IDNO skip_userdata
    RMDir /r "$LOCALAPPDATA\${APP_SLUG}"
  skip_userdata:
SectionEnd
