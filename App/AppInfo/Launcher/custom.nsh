
;= LAUNCHER
;= ################
; This PAF was compiled using a modified version of PAL:
; https://github.com/demondevin/portableapps.comlauncher

;= VARIABLES 
;= ################

;= DEFINES
;= ################
!define SETBUILD	`Kernel32::SetEnvironmentVariable(t "BUILD", t "$1")`
!define oNET		`SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full`
!define J			`$PLUGINSDIR\junction.exe`
!define INT			HKCU\Software\Sysinternals
!define JNC			${INT}\Junction

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
Function Compare
	!define Compare `!insertmacro _Compare`
	!macro _Compare _VER1 _VER2 _RESULT
		Push `${_VER1}`
		Push `${_VER2}`
		Call Compare
		Pop ${_RESULT}
	!macroend
	Exch $1
	Exch
	Exch $0
	Exch
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	Push $7
	StrCpy $2 -1
	IntOp $2 $2 + 1
	StrCpy $3 $0 1 $2
	StrCmp $3 '' +2
	StrCmp $3 '.' 0 -3
	StrCpy $4 $0 $2
	IntOp $2 $2 + 1
	StrCpy $0 $0 '' $2
	StrCpy $2 -1
	IntOp $2 $2 + 1
	StrCpy $3 $1 1 $2
	StrCmp $3 '' +2
	StrCmp $3 '.' 0 -3
	StrCpy $5 $1 $2
	IntOp $2 $2 + 1
	StrCpy $1 $1 '' $2
	StrCmp $4$5 '' +20
	StrCpy $6 -1
	IntOp $6 $6 + 1
	StrCpy $3 $4 1 $6
	StrCmp $3 '0' -2
	StrCmp $3 '' 0 +2
	StrCpy $4 0
	StrCpy $7 -1
	IntOp $7 $7 + 1
	StrCpy $3 $5 1 $7
	StrCmp $3 '0' -2
	StrCmp $3 '' 0 +2
	StrCpy $5 0
	StrCmp $4 0 0 +2
	StrCmp $5 0 -30 +10
	StrCmp $5 0 +7
	IntCmp $6 $7 0 +6 +8
	StrCpy $4 '1$4'
	StrCpy $5 '1$5'
	IntCmp $4 $5 -35 +5 +3
	StrCpy $0 0
	Goto END
	StrCpy $0 1
	Goto END
	StrCpy $0 2
	END:
	Pop $7
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Exch $0
FunctionEnd
Function ReadS
	!macro _ReadS _FILE _ENTRY _RESULT
		Push `${_FILE}`
		Push `${_ENTRY}`
		Call ReadS
		Pop ${_RESULT}
	!macroend
	!define ReadS `!insertmacro _ReadS`
	!insertmacro TextFunc_BOM
	Exch $1
	Exch
	Exch $0
	Exch
	Push $2
	Push $3
	Push $4
	Push $5
	ClearErrors
	FileOpen $2 $0 r
	IfErrors +22
	FileReadWord $2 $5
	IntCmp $5 0xFEFF +4
	FileSeek $2 0 SET
	StrCpy $TextFunc_BOM 0
	Goto +2
	StrCpy $TextFunc_BOM FFFE
	StrLen $0 $1
	StrCmpS $0 0 +14
	IntCmp $5 0xFEFF +3
	FileRead $2 $3
	Goto +2
	FileReadUTF16LE $2 $3
	IfErrors +9
	StrCpy $4 $3 $0
	StrCmpS $4 $1 0 -6
	StrCpy $0 $3 '' $0
	StrCpy $4 $0 1 -1
	StrCmpS $4 '$\r' +2
	StrCmpS $4 '$\n' 0 +5
	StrCpy $0 $0 -1
	Goto -4
	SetErrors
	StrCpy $0 ''
	FileClose $2
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Exch $0
FunctionEnd
!define FILE_SUPPORTS_REPARSE_POINTS 0x00000080
!macro YESNO _FLAGS _BIT _VAR
	IntOp ${_VAR} ${_FLAGS} & ${_BIT}
	${IfThen} ${_VAR} <> 0 ${|} StrCpy ${_VAR} 1 ${|}
	${IfThen} ${_VAR} == 0 ${|} StrCpy ${_VAR} 0 ${|}
!macroend
Function ValidateFS
	!macro _ValidateFS _PATH _RETURN
		Push `${_PATH}`
		Call ValidateFS
		Pop ${_RETURN}
	!macroend
	!define ValidateFS `!insertmacro _ValidateFS`
	Exch $0
	Push $1
	Push $2
	StrCpy $0 $0 3
	System::Call `Kernel32::GetVolumeInformation(t "$0",t,i ${NSIS_MAX_STRLEN},*i,*i,*i.r1,t,i ${NSIS_MAX_STRLEN})i.r0`
	${If} $0 <> 0
		!insertmacro YESNO $1 ${FILE_SUPPORTS_REPARSE_POINTS} $2
	${EndIf}
	Pop $0
	Pop $1
	Exch $2
FunctionEnd

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
	${ReadAppInfoConfig} $1 "Version" "DisplayVersion"
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
${SegmentPreExec}
	AccessControl::GrantOnFile '$APPDATA\discord' (S-1-5-32-545) FULLACCESS
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
				${WriteAppInfoConfig} "Version" "DisplayVersion" "$1"
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
!macro UnPostFilesMove
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
			${Directory::RestoreLocal} `$APPDATA` discord
		${EndIf}
	${EndIf}
	${Directory::RestoreLocal} `$APPDATA` discord
!macroend