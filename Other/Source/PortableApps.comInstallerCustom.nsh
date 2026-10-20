
;= VARIABLES
;= ################
Var Developer

;= DEFINES
;= ################
!define APP 		`Discord`
!define PORTABLE 	`${APP}Portable`
!define DEVELOPER_ID	`daemon.devin`

;= PRE INSTALL
;= ################
!macro CustomCodePreInstall
	SetDetailsPrint textonly
	DetailPrint "Checking if Discord Portable is already installed.."
	SetDetailsPrint lastused
	${If} ${FileExists} "$INSTDIR\App\AppInfo\appinfo.ini"
		SetDetailsPrint listonly
		DetailPrint "Discord Portable is already installed.."
		DetailPrint "Checking if Discord Portable was created by a different developer.."
		; The developer is kept in its own variable for the whole check, so
		; nothing below can overwrite it the way $0 used to be.
		ClearErrors
		ReadINIStr $Developer "$INSTDIR\App\AppInfo\appinfo.ini" Team Developer
		${If} ${Errors}
		${OrIf} $Developer == ""
			; Packages from other publishers usually have no [Team] section.
			; Their Publisher is the next best name to show, and an older
			; package of ours is recognized by it too.
			ClearErrors
			ReadINIStr $Developer "$INSTDIR\App\AppInfo\appinfo.ini" Details Publisher
			StrCpy $1 $Developer 12
			${If} $1 == "${DEVELOPER_ID}"
				StrCpy $Developer "${DEVELOPER_ID}"
			${ElseIf} $Developer == ""
				StrCpy $Developer "Unknown Developer"
			${EndIf}
		${EndIf}

		; Older packages spelled the name demon.devin; they are ours too.
		${If} $Developer == "demon.devin"
			StrCpy $Developer "${DEVELOPER_ID}"
		${EndIf}

		${If} $Developer == "${DEVELOPER_ID}"
			DetailPrint "Discord Portable was created by ${DEVELOPER_ID}.."
		${Else}
			SetDetailsPrint textonly
			DetailPrint "Different developer detected!"
			SetDetailsPrint lastused
			MessageBox MB_OKCANCEL|MB_ICONINFORMATION|MB_TOPMOST "Your current version of Discord Portable was created by another developer ($Developer).$\r$\n$\r$\nClick OK to overwrite everything and continue.$\r$\nClick Cancel to abort current installation.$\r$\n$\r$\nNOTE: If you select OK, everything will be overwritten (including any settings in ..\Data)." IDOK _CustomCodePreInstall_Overwrite
			Call .onInstFailed
			Quit
			_CustomCodePreInstall_Overwrite:
			SetDetailsPrint textonly
			DetailPrint "Preparing current Discord Portable for new installation.."
			SetDetailsPrint listonly
			DetailPrint "Erasing previous settings and data.."
			Delete `$INSTDIR\${PORTABLE}.ini`
			RMDir /r `$INSTDIR\Data`
			SetDetailsPrint lastused
		${EndIf}
		; Older packages kept BetterDiscord (plugins, themes, settings) in
		; App\BetterDiscord, which the new App folder replaces. It moves to
		; Data\BetterDiscord, where the launcher keeps it now.
		${If} ${FileExists} "$INSTDIR\App\BetterDiscord\*.*"
		${AndIfNot} ${FileExists} "$INSTDIR\Data\BetterDiscord\*.*"
			SetDetailsPrint listonly
			DetailPrint "Moving BetterDiscord to the Data folder.."
			CreateDirectory "$INSTDIR\Data"
			Rename "$INSTDIR\App\BetterDiscord" "$INSTDIR\Data\BetterDiscord"
			SetDetailsPrint lastused
		${EndIf}
	${Else}
		SetDetailsPrint listonly
		DetailPrint "Discord Portable is not installed.."
		DetailPrint "Continuing with current installation.."
		SetDetailsPrint lastused
	${EndIf}
!macroend

;= POST INSTALL 
;= ################
!macro CustomCodePostInstall
	IfFileExists "$INSTDIR\${PORTABLE}.ini" +2
	CopyFiles /SILENT "$INSTDIR\Other\Source\${PORTABLE}.ini" "$INSTDIR"
!macroend
