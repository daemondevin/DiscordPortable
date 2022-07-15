
;= LAUNCHER
;= ################
; This PAF was compiled using a modified version of PAL:
; https://github.com/demondevin/portableapps.comlauncher

;= VARIABLES 
;= ################

;= DEFINES
;= ################
!define SETBUILD  `Kernel32::SetEnvironmentVariable(t "BUILD", t "$1")`
!define oNET      `SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full`
!define J         `$PLUGINSDIR\junction.exe`
!define INT       HKCU\Software\Sysinternals
!define JNC       ${INT}\Junction

;= LANGUAGE
;= ################
LangString OS ${LANG_ENGLISH}      `You must have Windows 7 or better to use ${PORTABLEAPPNAME}.$\r$\n$\r$\nAborting!`
LangString OS ${LANG_SIMPCHINESE}  `?????Windows 7?????????${PORTABLEAPPNAME}?$\r$\n$\r$\n??!`
LangString OS ${LANG_FRENCH}       `Vous devez avoir Windows 7 ou mieux pour utiliser ${PORTABLEAPPNAME}.$\r$\n$\r$\nAbandonner!`
LangString OS ${LANG_GERMAN}       `Sie müssen Windows 7 oder besser verwenden, um ${PORTABLEAPPNAME} zu verwenden.$\r$\n$\r$\nAbbrechen!`
LangString OS ${LANG_ITALIAN}      `Devi avere Windows 7 o meglio utilizzare ${PORTABLEAPPNAME}.$\r$\n$\r$\nInterruzione!`
LangString OS ${LANG_JAPANESE}     `${PORTABLEAPPNAME}????????Windows 7????????$\r$\n$\r$\n??!`
LangString OS ${LANG_PORTUGUESEBR} `Você deve ter o Windows 7 ou superior para usar o ${PORTABLEAPPNAME}.$\r$\n$\r$\nAbortando!`
LangString OS ${LANG_SPANISH}      `Debes tener Windows 7 o mejor para utilizar ${PORTABLEAPPNAME}.$\r$\n$\r$\nAbortar!`
LangString NET ${LANG_ENGLISH}      `.NET Error:$\r$\n$\r$\nv4.5 or greater of the .NET Framework must be installed.$\r$\n$\r$\nAborting!`
LangString NET ${LANG_SIMPCHINESE}  `.NET??:$\r$\n$\r$\n????v4.5??????.NET Framework?$\r$\n$\r$\n??!`
LangString NET ${LANG_FRENCH}       `Erreur .NET:$\r$\n$\r$\nv4.5 ou plus du .NET Framework doit être installé.$\r$\n$\r$\nAbandonner!`
LangString NET ${LANG_GERMAN}       `.NET Fehler:$\r$\n$\r$\nv4.5 oder höher von .NET Framework muss installiert sein.$\r$\n$\r$\nAbbrechen!`
LangString NET ${LANG_ITALIAN}      `.NET Errore:$\r$\n$\r$\nv4.5 o superiore del .NET Framework deve essere installato.$\r$\n$\r$\nInterruzione!`
LangString NET ${LANG_JAPANESE}     `.NET???:$\r$\n$\r$\n.NET Framework?v4.5??????????????????????$\r$\n$\r$\n??!`
LangString NET ${LANG_PORTUGUESEBR} `Erro .NET:$\r$\n$\r$\nv4.5 ou superior do .NET Framework deve ser instalado.$\r$\n$\r$\nAbortando!`
LangString NET ${LANG_SPANISH}      `.NET Error:$\r$\n$\r$\ndebe instalarse v4.5 o superior del .NET Framework.$\r$\n$\r$\nAbortar!`

;= FUNCTIONS
;= ################

;= MACROS
;= ################
!define Junction::BackupLocal "!insertmacro _Junction::BackupLocal"
!macro _Junction::BackupLocal _LOCALDIR _SUBDIR _PORTABLEDIR _KEY _VAR1 _VAR2
	${Directory::BackupLocal} `${_LOCALDIR}` `${_SUBDIR}`
	CreateDirectory `${_PORTABLEDIR}`
	CreateDirectory `${_LOCALDIR}`
	ExecDos::Exec /TOSTACK `"${J}" -accepteula -q "${_LOCALDIR}\${_SUBDIR}" "${_PORTABLEDIR}"`
	Pop ${_VAR1}
	${If} ${_VAR1} = 0
		${WriteRuntimeData} ${PAL} ${_KEY} 1
	${Else}
		${GetFileAttributes} `${_LOCALDIR}\${_SUBDIR}` REPARSE_POINT ${_VAR1}
		${If} ${_VAR1} = 1
			${WriteRuntimeData} ${PAL} ${_KEY} 1
		${Else}
			${Directory::RestorePortable} `${_LOCALDIR}` `${_SUBDIR}` `${_PORTABLEDIR}` ${_VAR1} ${_VAR2}
		${EndIf}
	${EndIf}
!macroend
!define Junction::RestoreLocal "!insertmacro _Junction::RestoreLocal"
!macro _Junction::RestoreLocal _LOCALDIR _SUBDIR _PORTABLEDIR _KEY _VAR1 _VAR2
	ClearErrors
	${ReadRuntimeData} ${_VAR1} ${PAL} ${_KEY}
	${If} ${Errors}
		${GetFileAttributes} `${_LOCALDIR}\${_SUBDIR}` REPARSE_POINT ${_VAR1}
		${If} ${_VAR1} = 1
			ExecDos::Exec /TOSTACK `"${J}" -accepteula -d -q "${_LOCALDIR}\${_SUBDIR}"`
			Pop ${_VAR1}
			IntCmp ${_VAR1} 0 +2
			RMDir `${_LOCALDIR}\${_SUBDIR}`
		${Else}
			${Directory::BackupPortable} `${_LOCALDIR}` `${_SUBDIR}` `${_PORTABLEDIR}` ${_VAR1} ${_VAR2}
		${EndIf}
	${Else}
		ExecDos::Exec /TOSTACK `"${J}" -accepteula -d -q "${_LOCALDIR}\${_SUBDIR}"`
		Pop ${_VAR1}
		IntCmp ${_VAR1} 0 +2
		RMDir `${_LOCALDIR}\${_SUBDIR}`
	${EndIf}
	${Directory::RestoreLocal} `${_LOCALDIR}` `${_SUBDIR}`
	RMDir `${_PORTABLEDIR}`
	RMDir `${_LOCALDIR}`
!macroend

;= CUSTOM 
;= ################
${SegmentFile}
${Segment.OnInit}
	ClearErrors
	ReadRegDWORD $0 HKLM `${oNET}` `Release`
	IfErrors +2
	IntCmp $0 378389 +4 0 +4
	MessageBox MB_ICONSTOP|MB_TOPMOST `$(NET)`
	Call Unload
	Quit
	${ReadAppInfoConfig} $1 "Version" "ProgramVersion"
	System::Call `${SETBUILD}`
	${IfNot} ${Errors}
		${ReadLauncherConfig} $2 "Launch" "ProgramExecutable"
		${IfNot} "$2" == "${APP}\app-$1\${APP}.exe"
			${WriteLauncherConfig} "Launch" "ProgramExecutable" "${APP}\app-$1\${APP}.exe"
		${EndIf}
	${EndIf}
!macroend
!macro OS
	${If} ${IsNT}
		${IfNot} ${AtLeastWin7}
			MessageBox MB_ICONSTOP|MB_TOPMOST `$(OS)`
			Call Unload
			Quit
		${EndIf}
	${Else}
		MessageBox MB_ICONSTOP|MB_TOPMOST `$(OS)`
		Call Unload
		Quit
	${EndIf}
!macroend
!macro RunAsAdmin
	${ConfigReads} `${CONFIG}` Junctions= $0
	StrCmpS $0 true 0 +2
	StrCpy $RunAsAdmin force
	${If} $RunAsAdmin == force
		${If} ${ProcessExists} ${APP}.exe
			Return
		${Else}
			Elevate:
			!insertmacro UAC_RunElevated
			${Switch} $0
				${Case} 0
					${IfThen} $1 = 1 ${|} Quit ${|}
					${If} $3 <> 0
						${Break}
					${EndIf}
					${If} $1 = 3
						MessageBox MB_RETRYCANCEL|MB_ICONINFORMATION|MB_TOPMOST|MB_SETFOREGROUND \ 
						"$(LauncherRequiresAdmin)$\r$\n$\r$\n$(LauncherNotAdminTryAgain)" IDRETRY Elevate
						Quit
					${EndIf}
				${CaseUACCodeAlert} 1223 \
					"$(LauncherRequiresAdmin)" \
					"$(LauncherNotAdminLimitedFunctionality)"
				${CaseUACCodeAlert} 1062 \
					"$(LauncherAdminLogonServiceNotRunning)" \
					"$(LauncherNotAdminLimitedFunctionality)"
				${CaseUACCodeAlert} "" \
					"$(LauncherAdminError)$\r$\n$(LauncherRequiresAdmin)" \
					"$(LauncherAdminError)$\r$\n$(LauncherNotAdminLimitedFunctionality)"
			${EndSwitch}
		${EndIf}
	${EndIf}
!macroend
${SegmentPreExec}
	${If} $RunAsAdmin == force
		AccessControl::GrantOnFile '$APPDATA\discord' (S-1-5-32-545) FULLACCESS
	${EndIf}
!macroend
${SegmentUnload}
	FindFirst $0 $1 `${APPDIR}\app-*`
	ReadEnvStr $2 BUILD
	UPLOOP:
		StrCmp $1 "" UPDONE
		StrCpy $3 $1 4
		StrCmp $3 "app-" 0 UPNEXT
		StrCpy $1 $1 "" 4
		Push `$2.0`
		Push `$1.0`
		Call Compare
		Pop $3
		${If} $3 > 1
			${If} ${FileExists} "${APPDIR}\app-$1\${APP}.exe"
				${WriteAppInfoConfig} "Version" "ProgramVersion" "$1"
				${WriteAppInfoConfig} "Version" "PackageVersion" "$1.0"
			${EndIf}
		${EndIf}
		UPNEXT:
			FindNext $0 $1
		Goto UPLOOP
	UPDONE:
	FindClose $0
	FindFirst $0 $1 `$LOCALAPPDATA\Microsoft\*`
	StrCmpS $0 "" +12
	StrCmpS $1 "" +11
	StrCmpS $1 "." +8
	StrCmpS $1 ".." +7 
	StrCpy $2 $1 3
	StrCmpS $2 CLR 0 +5
	IfFileExists `$LOCALAPPDATA\Microsoft\$1\UsageLogs\${APP}.exe.log` 0 +2
	Delete `$LOCALAPPDATA\Microsoft\$1\UsageLogs\*.log`
	RMDir `$LOCALAPPDATA\Microsoft\$1\UsageLogs`
	RMDir `$LOCALAPPDATA\Microsoft\$1`
	FindNext $0 $1
	Goto -10
	FindClose $0
!macroend
!macro PreFilesMove
	${Directory::BackupLocal} `$APPDATA` discord
	${ConfigReads} `${CONFIG}` Junction= $0
	${If} $0 == true
		${If} $Admin == true
			${ValidateFS} $EXEDIR $0
			${If} $0 = 1
				File /oname=${J} junction.exe
				${WriteRuntimeData} ${PAL} NTFS 1
				${Registry::BackupValue} `${JNC}` EulaAccepted $0
				${Junction::BackupLocal} `$APPDATA` discord `${DATA}\AppData\discord` discord $0 $1
			${Else}
				${Directory::BackupLocal} `$APPDATA` discord
				${Directory::RestorePortable} `$APPDATA` discord `${DATA}\AppData\discord` $0 $1
			${EndIf}
		${Else}
			${Directory::BackupLocal} `$APPDATA` discord
			${Directory::RestorePortable} `$APPDATA` discord `${DATA}\AppData\discord` $0 $1
		${EndIf}
	${Else}
		${Directory::BackupLocal} `$APPDATA` discord
		${Directory::RestorePortable} `$APPDATA` discord `${DATA}\AppData\discord` $0 $1
	${EndIf}
!macroend
!macro PostFilesMove
	ClearErrors
	${ReadRuntimeData} $0 ${PAL} NTFS
	${If} ${Errors}
		${Directory::RestoreLocal} `$APPDATA` discord
	${Else}
		${If} $Admin == true
			IfFileExists `${J}` +2
			File /oname=${J} junction.exe
			${Junction::RestoreLocal} `$APPDATA` discord `${DATA}\AppData\discord` discord $0 $1
			${Registry::RestoreBackupValue} `${JNC}` EulaAccepted $0
			${Registry::DeleteKeyEmpty} `${JNC}` $0
			${Registry::DeleteKeyEmpty} `${INT}` $0
		${Else}
			${Directory::BackupPortable} `$APPDATA` discord `${DATA}\AppData\discord` $0 $1
			${Directory::RestoreLocal} `$APPDATA` discord
		${EndIf}
	${EndIf}
	${Directory::BackupPortable} `$APPDATA` discord `${DATA}\AppData\discord` $0 $1
	${Directory::RestoreLocal} `$APPDATA` discord
!macroend
