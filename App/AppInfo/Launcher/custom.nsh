; Discord Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; What lives here and why:
;   Architecture  Discord comes in x64 and ARM64 builds, each kept the way
;                 Discord's installer lays it out (an app-<version> folder per
;                 version) in App\Discord and App\DiscordARM64. The package
;                 ships the x64 build; the ARM64 one is downloaded on the
;                 first launch on ARM64 Windows. The user can force a build
;                 with Architecture= in DiscordPortable.ini.
;   Host          The newest app-<version> folder is the one that starts, so
;                 updates Discord installs for itself are picked up too.
;   Update        Optional self update from Discord's official installers.
;                 The app is unpacked straight out of the installer (it is
;                 never run, so nothing gets installed), set up next to the
;                 current build and then swapped in under the journal, so a
;                 failure or a crash keeps the version you had. A damaged or
;                 missing Discord is downloaded the same way.
;   BetterDiscord Optional (BetterDiscord= in DiscordPortable.ini). Its folder
;                 lives in Data\BetterDiscord, betterdiscord.asar is
;                 downloaded when it's missing, and Discord's core module is
;                 told to load it only when the launcher asks for it.
;   Discord       Journaled session changes: the discord:// protocol, the
;                 Run at startup entry, the uninstall entry and the shortcuts
;                 Discord makes for itself, all put back the way they were
;                 when it closes.
;
; The AppData and BetterDiscord links are not done here: they are declared in
; DiscordPortable.ini and handled by the journaled Symlinks segment.

; Variables
Var DscWant
Var DscIdx
Var DscDir
Var DscLabel
Var DscArchKey
Var DscVer
Var DscUrl
Var DscKB
Var DscDo
Var DscLocal
Var DscVer1
Var DscUrl1
Var DscKB1
Var DscDo1
Var DscVer2
Var DscUrl2
Var DscKB2
Var DscDo2
Var DscText
Var DscFailed
Var DscSwapped
Var DscTool
Var DscForce
Var DlWindow
Var DlLabel
Var DlBar
Var DlMsg
Var DlShown
Var DlText

; Defines
!define APPARM64    `DiscordARM64`
!define EXENAME     `Discord.exe`
!define CURL        `$SYSDIR\curl.exe`
!define DEPLOY      `https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=`
!define UPD         `$PLUGINSDIR\dscupdate`
!define BDDIR       `${DATA}\BetterDiscord`
!define BDASAR      `${BDDIR}\data\betterdiscord.asar`
!define BDURL       `https://github.com/BetterDiscord/BetterDiscord/releases/latest/download/betterdiscord.asar`
!define BDENV       `DISCORDPORTABLE_BETTERDISCORD`
!define RUNKEY      `Software\Microsoft\Windows\CurrentVersion\Run`
!define APPROVED    `Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run`
!define UNINSTKEY   `Software\Microsoft\Windows\CurrentVersion\Uninstall\Discord`

; Functions

; Architecture and host

; Applies the user's Architecture= setting (auto, x64 or arm64) to $Arch and
; notes the build this PC should run in $DscWant. Discord has had no 32-bit
; build since December 2023.
Function DSC_SelectArch
	Push $0
	!ifdef DSC_TEST
		; The Wine test bed is 32-bit: let it pretend to be anything.
		ReadEnvStr $0 DSCTEST_ARCH
		${IfThen} $0 != "" ${|} StrCpy $Arch $0 ${|}
	!else
		${If} $Arch == x86
			MessageBox MB_ICONSTOP|MB_TOPMOST "Discord needs 64-bit Windows (x64 or ARM64).$\r$\n$\r$\n${PORTABLEAPPNAME} can't run on this computer."
			Quit
		${EndIf}
	!endif
	${ReadUserConfig} $0 Architecture
	${If} $0 == x64
		StrCpy $Arch x64
	${EndIf}
	; arm64 can only be forced on ARM64 Windows, where it is already the
	; default; anything else keeps what the framework found.
	${If} $Arch == arm64
		StrCpy $DscWant ${APPARM64}
	${Else}
		StrCpy $DscWant ${APP}
	${EndIf}
	Pop $0
FunctionEnd

; Sets $1 to the newest version installed under build folder $0 ("1.0.9221")
; and $2 to its folder name ("app-1.0.9221"), or both to "" when there is
; none. Only folders with Discord.exe in them count.
Function DSC_NewestHost
	Push $3
	Push $4
	Push $5
	Push $6
	StrCpy $1 ""
	StrCpy $2 ""
	FindFirst $3 $4 `$0\app-*`
	${DoWhile} $4 != ""
		${If} ${FileExists} `$0\$4\${EXENAME}`
			StrCpy $5 $4 "" 4
			Push $0
			Push $1
			StrCpy $0 $5
			Call DSC_IsVersion
			StrCpy $6 $1
			Pop $1
			Pop $0
			${If} $6 == true
				${If} $1 == ""
					StrCpy $1 $5
					StrCpy $2 $4
				${Else}
					${VersionCompare} $5 $1 $6
					${If} $6 = 1
						StrCpy $1 $5
						StrCpy $2 $4
					${EndIf}
				${EndIf}
			${EndIf}
		${EndIf}
		FindNext $3 $4
	${Loop}
	FindClose $3
	Pop $6
	Pop $5
	Pop $4
	Pop $3
FunctionEnd

; Sets $3 to true when host folder $0 is usable: Discord's own code
; (resources\app.asar) is there and isn't empty. Copies made by sync tools
; or source control sometimes keep the file names but drop the contents.
Function DSC_HostOK
	Push $4
	Push $5
	StrCpy $3 false
	ClearErrors
	FileOpen $4 `$0\resources\app.asar` r
	${IfNot} ${Errors}
		FileSeek $4 0 END $5
		FileClose $4
		${If} $5 > 1024
			StrCpy $3 true
		${EndIf}
	${EndIf}
	Pop $5
	Pop $4
FunctionEnd

; Points $ProgramExecutable at the newest Discord of the build that should
; run: ARM64 on ARM64 Windows when the package has it, x64 otherwise. When
; there is none it points at a folder that doesn't exist, so the launcher
; offers to download Discord before it gives up.
Function DSC_Select
	Push $0
	Push $1
	Push $2
	StrCpy $ProgramExecutable ""
	${If} $DscWant == ${APPARM64}
		StrCpy $0 `$EXEDIR\App\${APPARM64}`
		Call DSC_NewestHost
		${If} $1 != ""
			StrCpy $ProgramExecutable `${APPARM64}\$2\${EXENAME}`
		${EndIf}
	${EndIf}
	${If} $ProgramExecutable == ""
		StrCpy $0 `$EXEDIR\App\${APP}`
		Call DSC_NewestHost
		${If} $1 != ""
			StrCpy $ProgramExecutable `${APP}\$2\${EXENAME}`
		${Else}
			StrCpy $ProgramExecutable `${APP}\app-0\${EXENAME}`
		${EndIf}
	${EndIf}
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Writes the version of the Discord that runs to AppInfo.ini when it
; changed, whether the launcher or Discord itself updated it.
Function DSC_WriteVersion
	Push $0
	Push $1
	Push $2
	${GetParent} `$EXEDIR\App\$ProgramExecutable` $0
	${GetParent} $0 $0
	Call DSC_NewestHost
	${If} $1 != ""
		${ReadAppInfoConfig} $2 Version DisplayVersion
		${If} $2 != $1
			${WriteAppInfoConfig} Version PackageVersion `$1.0`
			${WriteAppInfoConfig} Version DisplayVersion $1
		${EndIf}
	${EndIf}
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Update helpers

; The per build values live in $DscVer1, $DscUrl1, ... (x64) and $DscVer2,
; ... (ARM64). DSC_Load copies the ones of build $DscIdx into $DscDir,
; $DscLabel, $DscArchKey, $DscVer, $DscUrl, $DscKB and $DscDo, and
; DSC_Store copies the ones that change back.
Function DSC_Load
	${If} $DscIdx = 1
		StrCpy $DscDir ${APP}
		StrCpy $DscLabel x64
		StrCpy $DscArchKey x64
		StrCpy $DscVer $DscVer1
		StrCpy $DscUrl $DscUrl1
		StrCpy $DscKB $DscKB1
		StrCpy $DscDo $DscDo1
	${Else}
		StrCpy $DscDir ${APPARM64}
		StrCpy $DscLabel ARM64
		StrCpy $DscArchKey arm64
		StrCpy $DscVer $DscVer2
		StrCpy $DscUrl $DscUrl2
		StrCpy $DscKB $DscKB2
		StrCpy $DscDo $DscDo2
	${EndIf}
FunctionEnd

Function DSC_Store
	${If} $DscIdx = 1
		StrCpy $DscVer1 $DscVer
		StrCpy $DscUrl1 $DscUrl
		StrCpy $DscKB1 $DscKB
		StrCpy $DscDo1 $DscDo
	${Else}
		StrCpy $DscVer2 $DscVer
		StrCpy $DscUrl2 $DscUrl
		StrCpy $DscKB2 $DscKB
		StrCpy $DscDo2 $DscDo
	${EndIf}
FunctionEnd

; Runs the function _FUNC once per build.
!define DSC::EachBuild "!insertmacro _DSC::EachBuild"
!macro _DSC::EachBuild _FUNC
	StrCpy $DscIdx 1
	Call DSC_Load
	Call ${_FUNC}
	Call DSC_Store
	StrCpy $DscIdx 2
	Call DSC_Load
	Call ${_FUNC}
	Call DSC_Store
!macroend

; Sets $1 to the version ("1.0.9221") of the executable $0, or
; "" when it isn't there.
Function DSC_ExeVersion
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	StrCpy $1 ""
	${If} ${FileExists} $0
		ClearErrors
		GetDllVersion $0 $R0 $R1
		${IfNot} ${Errors}
			IntOp $R2 $R0 >> 16
			IntOp $R2 $R2 & 0xFFFF
			IntOp $R3 $R0 & 0xFFFF
			IntOp $R1 $R1 >> 16
			IntOp $R1 $R1 & 0xFFFF
			StrCpy $1 `$R2.$R3.$R1`
		${EndIf}
	${EndIf}
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Sets $1 to true when $0 looks like a version (digits and dots, starting
; and ending with a digit), else false.
Function DSC_IsVersion
	Push $2
	Push $3
	StrCpy $1 false
	StrCpy $2 $0 1
	StrCpy $3 $0 1 -1
	${If} $2 S>= 0
	${AndIf} $2 S<= 9
	${AndIf} $3 S>= 0
	${AndIf} $3 S<= 9
		StrCpy $1 true
		StrCpy $3 0
		${Do}
			StrCpy $2 $0 1 $3
			${IfThen} $2 == "" ${|} ${ExitDo} ${|}
			${If} $2 S< 0
			${OrIf} $2 S> 9
				${If} $2 != .
					StrCpy $1 false
					${ExitDo}
				${EndIf}
			${EndIf}
			IntOp $3 $3 + 1
		${Loop}
	${EndIf}
	Pop $3
	Pop $2
FunctionEnd

; Opens the download window: the banner, made wider, with a progress bar
; under its text. The bar belongs to this thread, so DSC_Pump has to run
; while the download is waiting, or it would never be drawn.
Function DSC_ProgressOpen
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	Push $7
	Push $8
	Push $9
	Banner::show "$DlText"
	Banner::getWindow
	Pop $DlWindow
	GetDlgItem $DlLabel $DlWindow 1030
	StrCpy $DlShown ""
	System::Call 'comctl32::InitCommonControls()'
	System::Call '*(i,i,i,i) p .r0'
	System::Call 'user32::GetWindowRect(p $DlWindow, p r0)'
	System::Call '*$0(i .r1, i .r2, i .r3, i .r4)'
	System::Call 'user32::GetWindowRect(p $DlLabel, p r0)'
	System::Call 'user32::MapWindowPoints(p 0, p $DlWindow, p r0, i 2)'
	System::Call '*$0(i .r5, i .r6, i .r7, i .r8)'
	System::Free $0
	; Sizes come from the label, so they follow the DPI the banner uses:
	; the bar is as tall as the label, with half that as the gap above it,
	; and both are made half as wide again.
	Push $R8
	Push $R9
	IntOp $9 $7 - $5
	IntOp $0 $8 - $6
	IntOp $R9 $0 / 2
	IntOp $R8 $9 / 2
	IntOp $9 $9 + $R8
	; The window grows by the same amounts and stays centred where it was.
	IntOp $3 $3 - $1
	IntOp $3 $3 + $R8
	IntOp $4 $4 - $2
	IntOp $4 $4 + $0
	IntOp $4 $4 + $R9
	IntOp $7 $R8 / 2
	IntOp $1 $1 - $7
	IntOp $7 $0 + $R9
	IntOp $7 $7 / 2
	IntOp $2 $2 - $7
	; SWP_NOZORDER|SWP_NOACTIVATE
	System::Call 'user32::SetWindowPos(p $DlWindow, p 0, i r1, i r2, i r3, i r4, i 0x14)'
	; SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE
	System::Call 'user32::SetWindowPos(p $DlLabel, p 0, i 0, i 0, i r9, i r0, i 0x16)'
	IntOp $8 $8 + $R9
	Pop $R9
	Pop $R8
	; WS_CHILD|WS_VISIBLE, PBS_SMOOTH
	System::Call 'user32::CreateWindowExW(i 0, w "msctls_progress32", w "", i 0x50000001, i r5, i r8, i r9, i r0, p $DlWindow, p 0, p 0, p 0) p .s'
	Pop $DlBar
	${If} $DscKB > 0
		; PBM_SETRANGE32 0 to 100
		SendMessage $DlBar 0x406 0 100
	${Else}
		; Size unknown: a marquee (PBS_MARQUEE, PBM_SETMARQUEE).
		System::Call 'user32::GetWindowLongW(p $DlBar, i -16) i .r1'
		IntOp $1 $1 | 0x08
		System::Call 'user32::SetWindowLongW(p $DlBar, i -16, i r1)'
		SendMessage $DlBar 0x40A 1 30
	${EndIf}
	System::Call '*(&i32) p .s'
	Pop $DlMsg
	Call DSC_Pump
	Pop $9
	Pop $8
	Pop $7
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

Function DSC_ProgressClose
	${If} $DlBar != ""
		System::Call 'user32::DestroyWindow(p $DlBar)'
		StrCpy $DlBar ""
	${EndIf}
	${If} $DlMsg != ""
		System::Free $DlMsg
		StrCpy $DlMsg ""
	${EndIf}
	${If} $DlWindow != ""
		Banner::destroy
		StrCpy $DlWindow ""
	${EndIf}
FunctionEnd

; Shows plain text $0 in the banner, opening it when it isn't up yet.
Function DSC_Banner
	${If} $DlWindow == ""
		Banner::show ""
		Banner::getWindow
		Pop $DlWindow
		GetDlgItem $DlLabel $DlWindow 1030
	${EndIf}
	SendMessage $DlLabel ${WM_SETTEXT} 0 "STR:$0"
FunctionEnd

; Handles the messages waiting for this thread (the progress bar's).
Function DSC_Pump
	Push $0
	${Do}
		; PM_REMOVE
		System::Call 'user32::PeekMessageW(p $DlMsg, p 0, i 0, i 0, i 1) i .r0'
		${IfThen} $0 = 0 ${|} ${ExitDo} ${|}
		System::Call 'user32::TranslateMessage(p $DlMsg)'
		System::Call 'user32::DispatchMessageW(p $DlMsg)'
	${Loop}
	Pop $0
FunctionEnd

; Shows $0 bytes downloaded: "45%  (60.2 / 133.4 MB)", or "60.2 MB" when
; the size is unknown. The text only changes when the numbers do.
Function DSC_ProgressSet
	Push $1
	Push $2
	Push $3
	Push $4
	IntOp $1 $0 / 1024
	; Tenths of a MB.
	IntOp $2 $1 * 10
	IntOp $2 $2 / 1024
	IntOp $3 $2 % 10
	IntOp $2 $2 / 10
	StrCpy $2 `$2.$3`
	${If} $DscKB > 0
		IntOp $4 $1 * 100
		IntOp $4 $4 / $DscKB
		${IfThen} $4 > 100 ${|} StrCpy $4 100 ${|}
		IntOp $3 $DscKB * 10
		IntOp $3 $3 / 1024
		IntOp $1 $3 % 10
		IntOp $3 $3 / 10
		StrCpy $3 `$4%  ($2 / $3.$1 MB)`
		SendMessage $DlBar 0x402 $4 0
	${Else}
		StrCpy $3 `$2 MB`
	${EndIf}
	${If} $3 != $DlShown
		StrCpy $DlShown $3
		SendMessage $DlLabel ${WM_SETTEXT} 0 `STR:$DlText  $3`
	${EndIf}
	Pop $4
	Pop $3
	Pop $2
	Pop $1
FunctionEnd

; Sets $1 to file or folder name $0 with its %XX escapes decoded. NuGet
; packages store names that way (a space is %20), and Squirrel decodes them
; when it installs. Only ASCII escapes are decoded.
Function DSC_Unescape
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	StrCpy $1 ""
	StrCpy $2 0
	${Do}
		StrCpy $3 $0 1 $2
		${IfThen} $3 == "" ${|} ${ExitDo} ${|}
		${If} $3 == "%"
			IntOp $5 $2 + 1
			StrCpy $4 $0 2 $5
			; Two hex digits: they survive a round trip through a number
			; (== ignores case, so "2b" matches "2B").
			IntOp $5 0x$4 + 0
			IntFmt $6 "%02X" $5
			StrLen $5 $4
			${If} $5 = 2
			${AndIf} $6 == $4
				IntOp $5 0x$4 + 0
				${If} $5 >= 32
				${AndIf} $5 < 128
					IntFmt $3 "%c" $5
					IntOp $2 $2 + 2
				${EndIf}
			${EndIf}
		${EndIf}
		StrCpy $1 `$1$3`
		IntOp $2 $2 + 1
	${Loop}
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
FunctionEnd

; Locate callback: notes the first escaped name in $R0 and stops.
Function DSC_FindEscaped
	StrCpy $R0 $R9
	Push StopLocate
FunctionEnd

; Decodes every escaped name under folder $0. One name is renamed per pass
; and the search starts over, so a renamed folder never leaves a stale path
; behind; most packages have no escaped names and need a single pass.
Function DSC_UnescapeTree
	Push $0
	Push $1
	Push $2
	Push $R0
	StrCpy $2 $0
	${Do}
		StrCpy $R0 ""
		${Locate} $2 "/L=FD /M=*%*" DSC_FindEscaped
		${IfThen} $R0 == "" ${|} ${ExitDo} ${|}
		${GetFileName} $R0 $0
		Call DSC_Unescape
		${If} $1 == $0
			; Nothing to decode: a real percent sign. Stop rather than loop.
			${ExitDo}
		${EndIf}
		${GetParent} $R0 $0
		ClearErrors
		Rename $R0 `$0\$1`
		${IfThen} ${Errors} ${|} ${ExitDo} ${|}
	${Loop}
	Pop $R0
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Looks up the latest installer for the build: Discord's download link for
; it redirects to a URL with the version in it
; (https://stable.dl2.discordapp.net/distro/app/stable/win/x64/1.0.9221/
; DiscordSetup.exe), so one HEAD request gives the version, the file to
; download and its size. Sets $DscVer, $DscUrl and $DscKB; $DscVer is ""
; when the lookup failed.
Function DSC_LatestInstaller
	Push $0
	Push $1
	Push $2
	StrCpy $DscVer ""
	StrCpy $DscUrl ""
	StrCpy $DscKB 0
	Delete `${UPD}\headers.txt`
	nsExec::Exec `"${CURL}" -sSIL --max-redirs 5 -o "${UPD}\headers.txt" "${DEPLOY}$DscArchKey"`
	Pop $0
	ClearErrors
	FileOpen $0 `${UPD}\headers.txt` r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileRead $0 $1
			${IfThen} ${Errors} ${|} ${ExitDo} ${|}
			; == ignores case, and HTTP/2 headers are lower case.
			StrCpy $2 $1 9
			${If} $2 == "location:"
				StrCpy $1 $1 "" 9
				${Trim} $1 $1
				${WordFind} $1 "/win/$DscArchKey/" "E+1}" $2
				${IfNot} ${Errors}
					StrCpy $DscUrl $1
					; $2 is "1.0.9221/DiscordSetup.exe".
					${WordFind} $2 "/" "+1" $DscVer
				${EndIf}
			${EndIf}
			; The last Content-Length is the installer's; the ones before it
			; belong to the redirects.
			StrCpy $2 $1 15
			${If} $2 == "content-length:"
				StrCpy $1 $1 "" 15
				${Trim} $1 $1
				StrCpy $2 $1 1
				${If} $2 S>= 0
				${AndIf} $2 S<= 9
					IntOp $DscKB $1 / 1024
				${EndIf}
			${EndIf}
		${Loop}
		FileClose $0
	${EndIf}
	StrCpy $0 $DscVer
	Call DSC_IsVersion
	${If} $1 != true
		StrCpy $DscVer ""
	${EndIf}
	${IfThen} $DscKB < 0 ${|} StrCpy $DscKB 0 ${|}
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Decides whether the build gets updated ($DscDo 1): when it is older than
; the latest release, damaged, or missing while it's the build this PC
; should run. Builds the package doesn't have and doesn't need are left
; alone.
Function DSC_Check
	Push $0
	Push $1
	Push $2
	Push $3
	StrCpy $DscDo 0
	StrCpy $0 `$EXEDIR\App\$DscDir`
	Call DSC_NewestHost
	StrCpy $DscLocal $1
	StrCpy $3 true
	${If} $1 != ""
		StrCpy $0 `$EXEDIR\App\$DscDir\$2`
		Call DSC_HostOK
	${ElseIf} $DscDir != $DscWant
		Goto check_done
	${EndIf}
	Call DSC_LatestInstaller
	${If} $DscVer == ""
		; A build the package doesn't have yet may simply not be offered;
		; the x64 build keeps running then.
		${If} $DscLocal != ""
		${OrIf} $DscForce == true
			StrCpy $DscFailed "Couldn't find out the latest version of the $DscLabel build."
		${EndIf}
		Goto check_done
	${EndIf}
	${If} $DscLocal == ""
		StrCpy $DscDo 1
		StrCpy $DscText "$DscText$\r$\n- The $DscLabel build, Discord $DscVer, which this copy doesn't have yet."
		${If} $DscDir == ${APPARM64}
			StrCpy $DscText "$DscText Until it does, the x64 build runs under emulation."
		${EndIf}
	${ElseIf} $3 != true
		StrCpy $DscDo 1
		StrCpy $DscText "$DscText$\r$\n- Discord $DscVer for the $DscLabel build, replacing a copy that is damaged (its app files are empty)."
	${Else}
		${VersionCompare} $DscVer $DscLocal $0
		${If} $0 = 1
			StrCpy $DscDo 1
			StrCpy $DscText "$DscText$\r$\n- Discord $DscVer for the $DscLabel build (this copy has $DscLocal)."
		${EndIf}
	${EndIf}
	check_done:
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Downloads the build's installer to ${UPD}\<label>.exe with curl, showing
; its progress.
Function DSC_Download
	${IfThen} $DscDo != 1 ${|} Return ${|}
	${IfThen} $DscFailed != "" ${|} Return ${|}
	StrCpy $1 `${UPD}\$DscLabel.exe`
	StrCpy $DlText "Downloading Discord $DscVer ($DscLabel).."
	Call DSC_Fetch
	${If} $0 <> 0
		StrCpy $DscFailed "The $DscLabel download failed (curl exit code $0)."
	${EndIf}
FunctionEnd

; Downloads $DscUrl to file $1 with curl, showing $DlText and the progress
; ($DscKB is the expected size, 0 when unknown). $0 is curl's exit code, or
; -1 when curl could not be started or nothing arrived.
Function DSC_Fetch
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	Push $7
	Call DSC_ProgressClose
	StrCpy $7 $1
	Delete $7
	Call DSC_ProgressOpen
	StrCpy $0 -1
	StrCpy $1 `"${CURL}" -fsSL -o "$7" "$DscUrl"`
	System::Call '*(i 68, &i64) p .r2'
	System::Call '*(&i16) p .r3'
	; CREATE_NO_WINDOW
	System::Call 'kernel32::CreateProcessW(p 0, w r1, p 0, p 0, i 0, i 0x08000000, p 0, p 0, p r2, p r3) i .r4'
	${If} $4 <> 0
		System::Call '*$3(p .r4, p .r5)'
		System::Call 'kernel32::CloseHandle(p r5)'
		System::Call '*(&i36) p .r6'
		${Do}
			System::Call 'kernel32::WaitForSingleObject(p r4, i 100) i .r5'
			Call DSC_Pump
			; nFileSizeLow of WIN32_FILE_ATTRIBUTE_DATA, at offset 32.
			StrCpy $0 0
			Push $4
			System::Call 'kernel32::GetFileAttributesExW(w r7, i 0, p r6) i .r4'
			${If} $4 <> 0
				System::Call '*$6(&i32, i .r0)'
			${EndIf}
			Pop $4
			Call DSC_ProgressSet
		${LoopWhile} $5 <> 0
		System::Call 'kernel32::GetExitCodeProcess(p r4, *i .r0)'
		System::Call 'kernel32::CloseHandle(p r4)'
		System::Free $6
	${EndIf}
	System::Free $2
	System::Free $3
	Call DSC_ProgressClose
	${If} $0 = 0
	${AndIfNot} ${FileExists} $7
		StrCpy $0 -1
	${EndIf}
	StrCpy $1 $7
	Pop $7
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
FunctionEnd

; Takes the files named $1 (a 7-Zip wildcard list) out of the Squirrel
; installer ${UPD}\<label>.exe into folder $0. 7-Zip opens the installer
; straight through to the zip inside it; older 7-Zip versions need that zip
; taken out of the installer's resources first.
Function DSC_FromSetup
	Push $2
	nsExec::Exec `"$DscTool" e "${UPD}\$DscLabel.exe" $1 -o"$0" -y -bso0 -bsp0`
	Pop $2
	FindFirst $2 $R0 `$0\*.nupkg`
	FindClose $2
	${If} $R0 == ""
		nsExec::Exec `"$DscTool" e -tpe "${UPD}\$DscLabel.exe" ".rsrc\DATA\131" -o"$0" -y -bso0 -bsp0`
		Pop $2
		nsExec::Exec `"$DscTool" e "$0\131" $1 -o"$0" -y -bso0 -bsp0`
		Pop $2
		Delete `$0\131`
	${EndIf}
	Pop $2
FunctionEnd

; Sets up the new build in <build>-new the way Discord's installer would
; leave it: Update.exe, packages\RELEASES and the app in app-<version> (the
; NuGet package's lib\net45 folder). Nothing in use is touched yet.
Function DSC_Extract
	${IfThen} $DscDo != 1 ${|} Return ${|}
	${IfThen} $DscFailed != "" ${|} Return ${|}
	Push $0
	Push $1
	Push $2
	Push $3
	Push $R0
	StrCpy $0 `${UPD}\$DscLabel`
	StrCpy $2 `$EXEDIR\App\$DscDir-tmp`
	StrCpy $3 `$EXEDIR\App\$DscDir-new`
	RMDir /r $0
	RMDir /r $2
	RMDir /r $3
	StrCpy $1 `"*.nupkg" "Update.exe" "RELEASES"`
	Call DSC_FromSetup
	FindFirst $1 $R0 `$0\*.nupkg`
	FindClose $1
	${If} $R0 == ""
		StrCpy $DscFailed "The $DscLabel download is not a Discord installer."
		Goto extract_done
	${EndIf}
	nsExec::Exec `"$DscTool" x "$0\$R0" "lib\net45\*" -o"$2" -y -bso0 -bsp0`
	Pop $1
	CreateDirectory `$3\packages`
	ClearErrors
	Rename `$2\lib\net45` `$3\app-$DscVer`
	${If} ${Errors}
	${OrIf} $1 <> 0
		StrCpy $DscFailed "The $DscLabel build could not be extracted (7-Zip exit code $1)."
		Goto extract_done
	${EndIf}
	CopyFiles /SILENT `$0\Update.exe` $3
	CopyFiles /SILENT `$0\RELEASES` `$3\packages`
	; Discord's installer also gives the build folder the updater database
	; that ships with the app, which records this version as installed.
	; Without it Discord's updater tries to install the version that is
	; already running and stops with an InconsistentInstallerState error.
	CopyFiles /SILENT `$3\app-$DscVer\installer.db` $3
	StrCpy $0 `$3\app-$DscVer`
	Call DSC_UnescapeTree
	; The new build has to be complete and the version the download promised.
	StrCpy $0 `$3\app-$DscVer`
	Push $3
	Call DSC_HostOK
	StrCpy $1 $3
	Pop $3
	${If} $1 != true
	${OrIfNot} ${FileExists} `$3\app-$DscVer\${EXENAME}`
		StrCpy $DscFailed "The $DscLabel download is missing parts of Discord."
		Goto extract_done
	${EndIf}
	StrCpy $0 `$3\app-$DscVer\${EXENAME}`
	Call DSC_ExeVersion
	${If} $1 != ""
		${VersionCompare} $1 $DscVer $0
		${If} $0 != 0
			StrCpy $DscFailed "The $DscLabel download holds Discord $1, not $DscVer."
		${EndIf}
	${EndIf}
	extract_done:
	RMDir /r $2
	RMDir /r `${UPD}\$DscLabel`
	Delete `${UPD}\$DscLabel.exe`
	Pop $R0
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

Function DSC_DropNew
	RMDir /r `$EXEDIR\App\$DscDir-new`
	RMDir /r `$EXEDIR\App\$DscDir-tmp`
FunctionEnd

Function DSC_DropBackup
	RMDir /r `$EXEDIR\App\$DscDir-backup`
FunctionEnd

; Swaps <build>-new in. Moving the current build aside is the backup, and it
; is journaled straight away, so from here on a failure or a crash puts it
; back: the undo deletes the new build and moves the backup into place. A
; build that wasn't there before is journaled with no backup, so the undo
; simply removes it. The whole build folder is replaced, the way a fresh
; install of Discord starts out: Discord downloads its modules again the
; first time the new version starts.
Function DSC_Swap
	${IfThen} $DscDo != 1 ${|} Return ${|}
	${IfThen} $DscFailed != "" ${|} Return ${|}
	Push $0
	StrCpy $0 `$EXEDIR\App\$DscDir`
	${If} ${FileExists} `$0\*.*`
		ClearErrors
		Rename $0 `$0-backup`
		${If} ${Errors}
			StrCpy $DscFailed "The $DscLabel build is in use and can't be replaced right now. Quit Discord (also from the notification area), then try again."
			Pop $0
			Return
		${EndIf}
		${Journal::Record} DiscordUpdate DIR $0 `$0-backup` recursive ""
	${Else}
		${Journal::Record} DiscordUpdate DIR $0 "" recursive ""
	${EndIf}
	IntOp $DscSwapped $DscSwapped + 1
	ClearErrors
	Rename `$0-new` $0
	${If} ${Errors}
		StrCpy $DscFailed "The new $DscLabel build could not be moved into place."
	${EndIf}
	Pop $0
FunctionEnd

; Puts the builds back after an update that was interrupted. Called from the
; InstanceManagement segment before the launcher checks that the executable
; exists, and only for a primary launch, so it never touches an update
; another launcher is still doing.
Function DSC_RepairBuild
	Push $0
	Push $1
	Push $2
	StrCpy $0 `$EXEDIR\App\$DscDir`
	${If} ${FileExists} `$0-backup\*.*`
		Call DSC_NewestHost
		${If} $1 != ""
			; The update was committed; the old copy is left over.
			RMDir /r `$0-backup`
		${Else}
			; The new build never got in place; put the old one back.
			RMDir /r $0
			Rename `$0-backup` $0
		${EndIf}
	${EndIf}
	RMDir /r `$0-new`
	RMDir /r `$0-tmp`
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

Function DSC_Repair
	Push $0
	${Journal::HasEntries} DiscordUpdate $0
	${If} $0 > 0
		${Journal::Rollback} DiscordUpdate
	${EndIf}
	${DSC::EachBuild} DSC_RepairBuild
	Pop $0
FunctionEnd

; Checks for a newer Discord and, if the user agrees, updates the builds the
; package has. Also offers the build this PC should run when the package
; doesn't have it (ARM64, the first time on Windows on ARM), and replaces a
; damaged one.
Function DSC_Update
	Push $0
	Push $1
	${ReadUserConfig} $0 UpdateCheck
	${If} $0 != true
	${AndIf} $DscForce != true
		Goto update_done
	${EndIf}
	; An earlier update that could not be undone yet is retried by the
	; journal; don't start another one.
	${Journal::HasEntries} DiscordUpdate $0
	${If} $0 > 0
		Goto update_done
	${EndIf}

	InitPluginsDir
	RMDir /r `${UPD}`
	CreateDirectory `${UPD}`
	StrCpy $DscFailed ""
	StrCpy $DscText ""
	${DSC::EachBuild} DSC_Check
	${If} $DscFailed != ""
		MessageBox MB_ICONSTOP|MB_TOPMOST "Update check failed! $DscFailed$\r$\n$\r$\nYou need to update ${PORTABLEAPPNAME} manually."
		Goto update_done
	${EndIf}
	${If} $DscDo1 != 1
	${AndIf} $DscDo2 != 1
		Goto update_done
	${EndIf}
	${If} $DscForce == true
		StrCpy $0 "Discord has to be downloaded before ${PORTABLEAPPNAME} can start:"
	${Else}
		StrCpy $0 "An update for Discord is available:"
	${EndIf}
	MessageBox MB_USERICON|MB_YESNO|MB_TOPMOST "$0$\r$\n$DscText$\r$\n$\r$\nDo you want to download it now?" IDYES +2
	Goto update_done

	; Download everything first: nothing changes if a download fails.
	${DSC::EachBuild} DSC_Download
	${If} $DscFailed != ""
		Goto update_failed
	${EndIf}

	StrCpy $0 "Updating Discord. Almost done.."
	Call DSC_Banner
	StrCpy $DscTool `${UPD}\7z.exe`
	File `/oname=${UPD}\7z.exe` `${PACKAGE}\Other\Source\7-Zip\7z.exe`
	File `/oname=${UPD}\7z.dll` `${PACKAGE}\Other\Source\7-Zip\7z.dll`
	${DSC::EachBuild} DSC_Extract
	${If} $DscFailed != ""
		${DSC::EachBuild} DSC_DropNew
		Goto update_failed
	${EndIf}

	StrCpy $DscSwapped 0
	${DSC::EachBuild} DSC_Swap
	${If} $DscFailed != ""
		${Journal::Rollback} DiscordUpdate
		${DSC::EachBuild} DSC_DropNew
		Goto update_failed
	${EndIf}

	; Commit. The entries go first: if the launcher stops before the old
	; copies are deleted, DSC_Repair deletes them on the next launch.
	${DoWhile} $DscSwapped > 0
		${Journal::Discard} DiscordUpdate
		IntOp $DscSwapped $DscSwapped - 1
	${Loop}
	${DSC::EachBuild} DSC_DropBackup
	Call DSC_Select
	Call DSC_WriteVersion
	${ReadAppInfoConfig} $1 Version DisplayVersion
	Call DSC_ProgressClose
	MessageBox MB_ICONINFORMATION|MB_TOPMOST "Discord has been updated to $1.$\r$\n$\r$\nDiscord downloads its voice and other modules again the first time it starts, so the first start takes a little longer.$\r$\n$\r$\nNow launching ${PORTABLEAPPNAME}."
	Goto update_done

	update_failed:
	Call DSC_ProgressClose
	MessageBox MB_ICONSTOP|MB_TOPMOST "The update failed. $DscFailed$\r$\n$\r$\nThe current version of Discord was kept."

	update_done:
	Call DSC_ProgressClose
	RMDir /r `${UPD}`
	Pop $1
	Pop $0
FunctionEnd

; Gives the build folder of the Discord that runs the updater database that
; ships with it (app-<version>\installer.db) when it has none, or only the
; empty one Discord's updater makes when it starts without it (12 KB, just
; an install id). That is what Discord's installer does; without it the
; updater tries to install the running version again and stops with an
; InconsistentInstallerState error. A database in use is always bigger: it
; records the installed version and its files.
Function DSC_SeedDB
	Push $0
	Push $1
	Push $2
	Push $3
	${GetParent} `$EXEDIR\App\$ProgramExecutable` $1
	${GetParent} $1 $0
	${If} ${FileExists} `$1\installer.db`
		ClearErrors
		FileOpen $2 `$0\installer.db` r
		${IfNot} ${Errors}
			FileSeek $2 0 END $3
			FileClose $2
			${If} $3 > 12288
				Goto seed_done
			${EndIf}
		${EndIf}
		Delete `$0\installer.db`
		CopyFiles /SILENT `$1\installer.db` $0
	${EndIf}
	seed_done:
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Gets the package a Discord it can run when it has none: a package shipped
; without Discord, an ARM64 only copy on an x64 PC, or one whose app files
; are damaged. This runs before the launcher checks for the executable,
; which is before the journal session is opened, so the update's own
; entries are closed out here when it's done.
Function DSC_Bootstrap
	Push $0
	Push $3
	StrCpy $0 false
	${If} ${FileExists} `$EXEDIR\App\$ProgramExecutable`
		${GetParent} `$EXEDIR\App\$ProgramExecutable` $0
		Call DSC_HostOK
		StrCpy $0 true
		${If} $3 == true
			StrCpy $0 false
		${EndIf}
	${Else}
		StrCpy $0 true
	${EndIf}
	${If} $0 == true
		StrCpy $DscForce true
		Call DSC_Update
		StrCpy $DscForce false
		ReadRegStr $0 HKCU `${JOURNAL_KEY}\DiscordUpdate` Count
		${If} $0 == 0
			DeleteRegKey HKCU `${JOURNAL_KEY}\DiscordUpdate`
		${EndIf}
		${Journal::End}
		Call DSC_Select
		${If} ${FileExists} `$EXEDIR\App\$ProgramExecutable`
			${GetParent} `$EXEDIR\App\$ProgramExecutable` $0
			Call DSC_HostOK
			${If} $3 != true
				MessageBox MB_ICONSTOP|MB_TOPMOST "The Discord in this copy of ${PORTABLEAPPNAME} is damaged: its app files are empty, so it can't start.$\r$\n$\r$\nStart ${PORTABLEAPPNAME} again with an internet connection to download Discord again."
				Quit
			${EndIf}
		${EndIf}
	${EndIf}
	Pop $3
	Pop $0
FunctionEnd

; BetterDiscord

; Writes text $1 to file $0, replacing it.
Function DSC_WriteText
	Push $2
	ClearErrors
	FileOpen $2 $0 w
	${IfNot} ${Errors}
		FileWrite $2 $1
		FileClose $2
	${EndIf}
	Pop $2
FunctionEnd

; Sets $1 to true when file $0 contains text $2 (case insensitive), else
; false. Only for small files: Discord's core loader is one or two lines.
Function DSC_FileHas
	Push $3
	Push $4
	StrCpy $1 false
	ClearErrors
	FileOpen $3 $0 r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileRead $3 $4
			${IfThen} ${Errors} ${|} ${ExitDo} ${|}
			${WordFind} $4 $2 "E+1" $4
			${IfNot} ${Errors}
				StrCpy $1 true
				${ExitDo}
			${EndIf}
		${Loop}
		FileClose $3
	${EndIf}
	Pop $4
	Pop $3
FunctionEnd

; Rewrites the loader (index.js) of every discord_desktop_core module of the
; Discord that runs. With $R1 true it loads BetterDiscord first, but only
; when the launcher set ${BDENV}: Discord started any other way runs
; unmodded instead of failing. With $R1 false the plain loader goes back.
Function DSC_PatchCore
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	${GetParent} `$EXEDIR\App\$ProgramExecutable` $3
	FindFirst $4 $2 `$3\modules\discord_desktop_core-*`
	${DoWhile} $2 != ""
		StrCpy $0 `$3\modules\$2\discord_desktop_core\index.js`
		${If} ${FileExists} $0
			Push $2
			${If} $R1 == true
				StrCpy $2 ${BDENV}
				Call DSC_FileHas
				${If} $1 != true
					StrCpy $1 `// Discord Portable: loads BetterDiscord when its launcher asks for it.$\r$\nif (process.env.${BDENV}) {$\r$\n$\ttry {$\r$\n$\t$\trequire(process.env.${BDENV});$\r$\n$\t} catch (e) {$\r$\n$\t$\tconsole.error("BetterDiscord could not be loaded", e);$\r$\n$\t}$\r$\n}$\r$\nmodule.exports = require("./core.asar");$\r$\n`
					Call DSC_WriteText
				${EndIf}
			${Else}
				StrCpy $2 betterdiscord
				Call DSC_FileHas
				${If} $1 == true
					StrCpy $1 `module.exports = require('./core.asar');`
					Call DSC_WriteText
				${EndIf}
			${EndIf}
			Pop $2
		${EndIf}
		FindNext $4 $2
	${Loop}
	FindClose $4
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Sets $3 to true when betterdiscord.asar is there and isn't a placeholder.
Function DSC_BDOK
	Push $4
	Push $5
	StrCpy $3 false
	ClearErrors
	FileOpen $4 `${BDASAR}` r
	${IfNot} ${Errors}
		FileSeek $4 0 END $5
		FileClose $4
		${If} $5 > 102400
			StrCpy $3 true
		${EndIf}
	${EndIf}
	Pop $5
	Pop $4
FunctionEnd

; BetterDiscord's folder (plugins, themes, settings and betterdiscord.asar)
; is kept in Data\BetterDiscord and linked to %APPDATA%\BetterDiscord, where
; BetterDiscord looks for it. Older packages kept it in App\BetterDiscord;
; it is moved over once. With BetterDiscord=true, betterdiscord.asar is
; downloaded when it's missing (BetterDiscord updates it itself after that)
; and Discord's core module is told to load it.
Function DSC_BetterDiscord
	Push $0
	Push $1
	Push $3
	Push $R1
	${If} ${FileExists} `$EXEDIR\App\BetterDiscord\*.*`
	${AndIfNot} ${FileExists} `${BDDIR}\*.*`
		CreateDirectory `${DATA}`
		Rename `$EXEDIR\App\BetterDiscord` `${BDDIR}`
	${EndIf}
	${ReadUserConfig} $R1 BetterDiscord
	${If} $R1 == true
		CreateDirectory `${BDDIR}\data\stable`
		CreateDirectory `${BDDIR}\plugins`
		CreateDirectory `${BDDIR}\themes`
		Call DSC_BDOK
		${If} $3 != true
			InitPluginsDir
			StrCpy $DscUrl `${BDURL}`
			StrCpy $DscKB 0
			StrCpy $DlText "Downloading BetterDiscord.."
			StrCpy $1 `${BDASAR}.download`
			Call DSC_Fetch
			${If} $0 = 0
				Delete `${BDASAR}`
				Rename `${BDASAR}.download` `${BDASAR}`
			${EndIf}
			Delete `${BDASAR}.download`
			Call DSC_BDOK
			${If} $3 != true
				MessageBox MB_ICONEXCLAMATION|MB_TOPMOST "BetterDiscord couldn't be downloaded (curl exit code $0).$\r$\n$\r$\nDiscord starts without it this time; ${PORTABLEAPPNAME} tries again on the next launch."
				StrCpy $R1 false
			${EndIf}
		${EndIf}
	${EndIf}
	${If} $R1 == true
		System::Call `kernel32::SetEnvironmentVariable(t "${BDENV}", t "${BDASAR}")`
	${Else}
		StrCpy $R1 false
	${EndIf}
	Call DSC_PatchCore
	Pop $R1
	Pop $3
	Pop $1
	Pop $0
FunctionEnd

; Session changes

; Journals what Discord writes for itself while it runs: the discord://
; protocol, the Run at startup entry ("Open Discord" in its settings is on
; by default), the uninstall entry its updater keeps, and its Start menu and
; desktop shortcuts. An installed Discord's entries are backed up first and
; come back exactly as they were.
Function DSC_Apply
	Push $0
	Push $1
	Push $2
	${Journal::RegKey} Discord HKCU `Software\Classes\Discord` $0
	${Journal::RegKey} Discord HKCU `${UNINSTKEY}` $0
	ClearErrors
	ReadRegStr $1 HKCU `${RUNKEY}` Discord
	${If} ${Errors}
		${Journal::Record} Discord REGVALUE HKCU `${RUNKEY}` Discord ""
	${Else}
		${Journal::Record} Discord REGVALUE HKCU `${RUNKEY}` Discord `STR:$1`
	${EndIf}
	; Task Manager's startup switch for an installed Discord is a binary
	; value; reg.exe puts it back.
	nsExec::ExecToStack `"$SYSDIR\reg.exe" query "HKCU\${APPROVED}" /v Discord`
	Pop $0
	Pop $1
	${If} $0 = 0
		${WordFind} $1 "REG_BINARY" "E+1}" $2
		${IfNot} ${Errors}
			${Trim} $2 $2
			${WordFind} $2 "$\r" "+1" $2
			${WordFind} $2 "$\n" "+1" $2
			${Trim} $2 $2
			${If} $2 != ""
				${Journal::Record} Discord CMD `"$SYSDIR\reg.exe" add "HKCU\${APPROVED}" /v Discord /t REG_BINARY /d $2 /f` 0 "" ""
			${EndIf}
		${EndIf}
	${EndIf}
	SetShellVarContext current
	${IfNot} ${FileExists} `$SMPROGRAMS\Discord Inc\*.*`
		${Journal::Record} Discord DIR `$SMPROGRAMS\Discord Inc` "" "" ""
	${EndIf}
	${Journal::BackupFile} Discord `$SMPROGRAMS\Discord Inc\Discord.lnk` $0
	${Journal::Record} Discord FILE `$SMPROGRAMS\Discord Inc\Discord.lnk` $0 "" ""
	${Journal::BackupFile} Discord `$DESKTOP\Discord.lnk` $0
	${Journal::Record} Discord FILE `$DESKTOP\Discord.lnk` $0 "" ""
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Hooks

; Core segment, Init: the executable is the newest Discord of the build to
; run, not a fixed path.
!macro ProExecInit
	Call DSC_Select
!macroend

; InstanceManagement segment, Init, right before the executable is looked for.
!macro EXE
	${If} $SecondaryLaunch != true
		Call DSC_Repair
		Call DSC_Select
		Call DSC_Bootstrap
		Call DSC_SeedDB
	${EndIf}
!macroend

${SegmentFile}

${Segment.OnInit}
	Call DSC_SelectArch
!macroend

${SegmentPre}
	; Runs after crash recovery and after the journal session is open, and
	; before the launcher builds the command line, so a build added by the
	; update is the one that starts.
	${If} ${PrimaryInstance}
		Call DSC_Update
		Call DSC_Select
		Call DSC_SeedDB
	${EndIf}
!macroend

${SegmentPrePrimary}
	Call DSC_BetterDiscord
	Call DSC_Apply
!macroend

${SegmentPostPrimary}
	${Journal::HasEntries} Discord $R0
	${If} $R0 > 0
		${Journal::Rollback} Discord
	${EndIf}
	; Discord may have updated itself while it ran.
	Call DSC_WriteVersion
!macroend
