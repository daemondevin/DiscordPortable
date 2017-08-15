
;= VARIABLES
;= ################
Var Developer

;= PRE INSTALL
;= ################
!macro CustomCodePreInstall
	SetDetailsPrint textonly
	DetailPrint "Checking for a different developer.."
	SetDetailsPrint lastused
	ReadINIStr $0 "$INSTDIR\App\AppInfo\appinfo.ini" Team Developer
	${IfNot} ${Errors}
	${AndIfNot} "$0" == "demon.devin"
		StrCpy $Developer "$0"
		SetDetailsPrint textonly
		DetailPrint "Different develop detected!"
		SetDetailsPrint lastused
		MESSAGEBOX MB_OKCANCEL|MB_ICONINFORMATION|MB_TOPMOST "Your current version was created by another developer ($Developer).$\r$\n$\r$\nClick OK to overwrite everything and continue.$\r$\nClick Cancel to abort current installation.$\r$\n$\r$\nNOTE: Everything will be overwritten (including any settings in ..\Data)." IDOK +3 IDCANCEL 0
		Call .onInstFailed
		Quit
		SetDetailsPrint textonly
		DetailPrint "Erasing old installation to prepare for new installation.."
		SetDetailsPrint lastused
		IfFileExists "$INSTDIR\DiscordPortable.ini" 0 +2
		Delete `$INSTDIR\DiscordPortable.ini`
		RMDir /r `$INSTDIR\Data`
	${EndIf}
!macroend

;= POST INSTALL 
;= ################
!macro CustomCodePostInstall
	IfFileExists "$INSTDIR\DiscordPortable.ini" +2
	CopyFiles /SILENT "$INSTDIR\Other\Source\DiscordPortable.ini" "$INSTDIR"
!macroend