; <COMPILER: v1.1.23.06>
#NoEnv
#NoTrayIcon
#SingleInstance Off
PreprocessScript(ByRef ScriptText, AhkScript, ExtraFiles, FileList="", FirstScriptDir="", Options="", iOption=0)
{
SplitPath, AhkScript, ScriptName, ScriptDir
if !IsObject(FileList)
{
FileList := [AhkScript]
ScriptText := "`n"
FirstScriptDir := ScriptDir
IsFirstScript := true
Options := { comm: ";", esc: "``" }
OldWorkingDir := A_WorkingDir
SetWorkingDir, %ScriptDir%
}
IfNotExist, %AhkScript%
if !iOption
Util_Error((IsFirstScript ? "Script" : "#include") " file """ AhkScript """ cannot be opened.")
else return
cmtBlock := false, contSection := false
Loop, Read, %AhkScript%
{
tline := Trim(A_LoopReadLine)
if !cmtBlock
{
if !contSection
{
if StrStartsWith(tline, Options.comm)
continue
else if tline =
continue
else if StrStartsWith(tline, "/*")
{
cmtBlock := true
continue
}
}
if StrStartsWith(tline, "(") && !IsFakeCSOpening(tline)
contSection := true
else if StrStartsWith(tline, ")")
contSection := false
tline := RegExReplace(tline, "\s+" RegExEscape(Options.comm) ".*$", "")
if !contSection && RegExMatch(tline, "i)^#Include(Again)?[ \t]*[, \t]?\s+(.*)$", o)
{
IsIncludeAgain := (o1 = "Again")
IgnoreErrors := false
IncludeFile := o2
if RegExMatch(IncludeFile, "\*[iI]\s+?(.*)", o)
IgnoreErrors := true, IncludeFile := Trim(o1)
if RegExMatch(IncludeFile, "^<(.+)>$", o)
{
if IncFile2 := FindLibraryFile(o1, FirstScriptDir)
{
IncludeFile := IncFile2
goto _skip_findfile
}
}
StringReplace, IncludeFile, IncludeFile, `%A_ScriptDir`%, %FirstScriptDir%, All
StringReplace, IncludeFile, IncludeFile, `%A_AppData`%, %A_AppData%, All
StringReplace, IncludeFile, IncludeFile, `%A_AppDataCommon`%, %A_AppDataCommon%, All
StringReplace, IncludeFile, IncludeFile, `%A_LineFile`%, %AhkScript%, All
if InStr(FileExist(IncludeFile), "D")
{
SetWorkingDir, %IncludeFile%
continue
}
_skip_findfile:
IncludeFile := Util_GetFullPath(IncludeFile)
AlreadyIncluded := false
for k,v in FileList
if (v = IncludeFile)
{
AlreadyIncluded := true
break
}
if(IsIncludeAgain || !AlreadyIncluded)
{
if !AlreadyIncluded
FileList.Insert(IncludeFile)
PreprocessScript(ScriptText, IncludeFile, ExtraFiles, FileList, FirstScriptDir, Options, IgnoreErrors)
}
}else if !contSection && tline ~= "i)^FileInstall[, \t]"
{
if tline ~= "^\w+\s+(:=|\+=|-=|\*=|/=|//=|\.=|\|=|&=|\^=|>>=|<<=)"
continue
EscapeChar := Options.esc
EscapeCharChar := EscapeChar EscapeChar
EscapeComma := EscapeChar ","
EscapeTmp := chr(2)
EscapeTmpD := chr(3)
StringReplace, tline, tline, %EscapeCharChar%, %EscapeTmpD%, All
StringReplace, tline, tline, %EscapeComma%, %EscapeTmp%, All
if !RegExMatch(tline, "i)^FileInstall[ \t]*[, \t][ \t]*([^,]+?)[ \t]*(,|$)", o) || o1 ~= "[^``]%"
Util_Error("Error: Invalid ""FileInstall"" syntax found. Note that the first parameter must not be specified using a continuation section.")
_ := Options.esc
StringReplace, o1, o1, %_%`%, `%, All
StringReplace, o1, o1, %_%`,, `,, All
StringReplace, o1, o1, %_%%_%,, %_%,, All
StringReplace, o1, o1, %EscapeTmp%, `,, All
StringReplace, o1, o1, %EscapeTmpD%, %EscapeChar%, All
StringReplace, tline, tline, %EscapeTmp%, %EscapeComma%, All
StringReplace, tline, tline, %EscapeTmpD%, %EscapeCharChar%, All
ExtraFiles.Insert(o1)
ScriptText .= tline "`n"
}else if !contSection && RegExMatch(tline, "i)^#CommentFlag\s+(.+)$", o)
Options.comm := o1, ScriptText .= tline "`n"
else if !contSection && RegExMatch(tline, "i)^#EscapeChar\s+(.+)$", o)
Options.esc := o1, ScriptText .= tline "`n"
else if !contSection && RegExMatch(tline, "i)^#DerefChar\s+(.+)$", o)
Util_Error("Error: #DerefChar is not supported.")
else if !contSection && RegExMatch(tline, "i)^#Delimiter\s+(.+)$", o)
Util_Error("Error: #Delimiter is not supported.")
else
ScriptText .= (contSection ? A_LoopReadLine : tline) "`n"
}else if StrStartsWith(tline, "*/")
cmtBlock := false
}
Loop, % !!IsFirstScript
{
static AhkPath := A_IsCompiled ? A_ScriptDir "\..\AutoHotkey.exe" : A_AhkPath
IfNotExist, %AhkPath%
break
Util_Status("Auto-including any functions called from a library...")
ilibfile = %A_Temp%\_ilib.ahk
IfExist, %ilibfile%, FileDelete, %ilibfile%
AhkType := AHKType(AhkPath)
if AhkType = FAIL
Util_Error("Error: The AutoHotkey build used for auto-inclusion of library functions is not recognized.", 1, AhkPath)
if AhkType = Legacy
Util_Error("Error: Legacy AutoHotkey versions (prior to v1.1) are not allowed as the build used for auto-inclusion of library functions.", 1, AhkPath)
tmpErrorLog := Util_TempFile()
RunWait, "%AhkPath%" /iLib "%ilibfile%" /ErrorStdOut "%AhkScript%" 2>"%tmpErrorLog%", %FirstScriptDir%, UseErrorLevel
FileRead,tmpErrorData,%tmpErrorLog%
FileDelete,%tmpErrorLog%
if (ErrorLevel = 2)
Util_Error("Error: The script contains syntax errors.",1,tmpErrorData)
IfExist, %ilibfile%
{
PreprocessScript(ScriptText, ilibfile, ExtraFiles, FileList, FirstScriptDir, Options)
FileDelete, %ilibfile%
}
StringTrimRight, ScriptText, ScriptText, 1
}
if OldWorkingDir
SetWorkingDir, %OldWorkingDir%
}
IsFakeCSOpening(tline)
{
Loop, Parse, tline, %A_Space%%A_Tab%
if !StrStartsWith(A_LoopField, "Join") && InStr(A_LoopField, ")")
return true
return false
}
FindLibraryFile(name, ScriptDir)
{
libs := [ScriptDir "\Lib", A_MyDocuments "\AutoHotkey\Lib", A_ScriptDir "\..\Lib"]
p := InStr(name, "_")
if p
name_lib := SubStr(name, 1, p-1)
for each,lib in libs
{
file := lib "\" name ".ahk"
IfExist, %file%
return file
if !p
continue
file := lib "\" name_lib ".ahk"
IfExist, %file%
return file
}
}
StrStartsWith(ByRef v, ByRef w)
{
return SubStr(v, 1, StrLen(w)) = w
}
RegExEscape(t)
{
static _ := "\.*?+[{|()^$"
Loop, Parse, _
StringReplace, t, t, %A_LoopField%, \%A_LoopField%, All
return t
}
Util_TempFile(d:="")
{
if ( !StrLen(d) || !FileExist(d) )
d:=A_Temp
Loop
tempName := d "\~temp" A_TickCount ".tmp"
until !FileExist(tempName)
return tempName
}
ReplaceAhkIcon(re, IcoFile, ExeFile)
{
global _EI_HighestIconID
static iconID := 159
ids := EnumIcons(ExeFile, iconID)
if !IsObject(ids)
return false
f := FileOpen(IcoFile, "r")
if !IsObject(f)
return false
VarSetCapacity(igh, 8), f.RawRead(igh, 6)
if NumGet(igh, 0, "UShort") != 0 || NumGet(igh, 2, "UShort") != 1
return false
wCount := NumGet(igh, 4, "UShort")
VarSetCapacity(rsrcIconGroup, rsrcIconGroupSize := 6 + wCount*14)
NumPut(NumGet(igh, "Int64"), rsrcIconGroup, "Int64")
ige := &rsrcIconGroup + 6
Loop, % ids.MaxIndex()
DllCall("UpdateResource", "ptr", re, "ptr", 3, "ptr", ids[A_Index], "ushort", 0x409, "ptr", 0, "uint", 0, "uint")
Loop, %wCount%
{
thisID := ids[A_Index]
if !thisID
thisID := ++ _EI_HighestIconID
f.RawRead(ige+0, 12)
NumPut(thisID, ige+12, "UShort")
imgOffset := f.ReadUInt()
oldPos := f.Pos
f.Pos := imgOffset
VarSetCapacity(iconData, iconDataSize := NumGet(ige+8, "UInt"))
f.RawRead(iconData, iconDataSize)
f.Pos := oldPos
DllCall("UpdateResource", "ptr", re, "ptr", 3, "ptr", thisID, "ushort", 0x409, "ptr", &iconData, "uint", iconDataSize, "uint")
ige += 14
}
DllCall("UpdateResource", "ptr", re, "ptr", 14, "ptr", iconID, "ushort", 0x409, "ptr", &rsrcIconGroup, "uint", rsrcIconGroupSize, "uint")
return true
}
EnumIcons(ExeFile, iconID)
{
global _EI_HighestIconID
static pEnumFunc := RegisterCallback("EnumIcons_Enum")
hModule := DllCall("LoadLibraryEx", "str", ExeFile, "ptr", 0, "ptr", 2, "ptr")
if !hModule
return
_EI_HighestIconID := 0
if DllCall("EnumResourceNames", "ptr", hModule, "ptr", 3, "ptr", pEnumFunc, "uint", 0) = 0
{
DllCall("FreeLibrary", "ptr", hModule)
return
}
hRsrc := DllCall("FindResource", "ptr", hModule, "ptr", iconID, "ptr", 14, "ptr")
hMem := DllCall("LoadResource", "ptr", hModule, "ptr", hRsrc, "ptr")
pDirHeader := DllCall("LockResource", "ptr", hMem, "ptr")
pResDir := pDirHeader + 6
wCount := NumGet(pDirHeader+4, "UShort")
iconIDs := []
Loop, %wCount%
{
pResDirEntry := pResDir + (A_Index-1)*14
iconIDs[A_Index] := NumGet(pResDirEntry+12, "UShort")
}
DllCall("FreeLibrary", "ptr", hModule)
return iconIDs
}
EnumIcons_Enum(hModule, type, name, lParam)
{
global _EI_HighestIconID
if (name < 0x10000) && name > _EI_HighestIconID
_EI_HighestIconID := name
return 1
}
AhkCompile(ByRef AhkFile, ExeFile="", ByRef CustomIcon="", BinFile="", UseMPRESS="", fileCP="")
{
global ExeFileTmp
AhkFile := Util_GetFullPath(AhkFile)
if AhkFile =
Util_Error("Error: Source file not specified.")
SplitPath, AhkFile,, AhkFile_Dir,, AhkFile_NameNoExt
if ExeFile =
ExeFile = %AhkFile_Dir%\%AhkFile_NameNoExt%.exe
else
ExeFile := Util_GetFullPath(ExeFile)
ExeFileTmp := Util_TempFile()
if BinFile =
BinFile = %A_ScriptDir%\AutoHotkeySC.bin
Util_DisplayHourglass()
IfNotExist, %BinFile%
Util_Error("Error: The selected AutoHotkeySC binary does not exist.", 1, BinFile)
try FileCopy, %BinFile%, %ExeFileTmp%, 1
catch
Util_Error("Error: Unable to copy AutoHotkeySC binary file to destination.")
BundleAhkScript(ExeFileTmp, AhkFile, CustomIcon, fileCP)
if FileExist(A_ScriptDir "\mpress.exe") && UseMPRESS
{
Util_Status("Compressing final executable...")
RunWait, "%A_ScriptDir%\mpress.exe" -q -x "%ExeFileTmp%",, Hide
}
try FileCopy, %ExeFileTmp%, %ExeFile%, 1
catch
Util_Error("Error: Could not copy final compiled binary file to destination.")
Util_HideHourglass()
Util_Status("")
}
BundleAhkScript(ExeFile, AhkFile, IcoFile="", fileCP="")
{
if fileCP is space
fileCP := A_FileEncoding
try FileEncoding, %fileCP%
catch e
Util_Error("Error: Invalid codepage parameter """ fileCP """ was given.")
SplitPath, AhkFile,, ScriptDir
ExtraFiles := []
PreprocessScript(ScriptBody, AhkFile, ExtraFiles)
VarSetCapacity(BinScriptBody, BinScriptBody_Len := StrPut(ScriptBody, "UTF-8") - 1)
StrPut(ScriptBody, &BinScriptBody, "UTF-8")
module := DllCall("BeginUpdateResource", "str", ExeFile, "uint", 0, "ptr")
if !module
Util_Error("Error: Error opening the destination file.")
if IcoFile
{
Util_Status("Changing the main icon...")
if !ReplaceAhkIcon(module, IcoFile, ExeFile)
{
gosub _EndUpdateResource
Util_Error("Error changing icon: Unable to read icon or icon was of the wrong format.")
}
}
Util_Status("Compressing and adding: Master Script")
;VarSetCapacity(data, 10000000)
data := DllCall("decoding_encodingDll.dll\AES_ECB_Encry","ptr",&BinScriptBody,"int",BinScriptBody_Len,"Astr")
Len := BinScriptBody_Len * 4
VarSetCapacity(RESdata, 10000000)
StrPut(data, &RESdata, "UTF-8")
if !DllCall("UpdateResource", "ptr", module, "ptr", 10, "str", IcoFile ? "AWI" : "AS"
, "ushort", 0x409, "ptr",&RESdata, "uint",Len, "uint")
if !a
goto _FailEnd
oldWD := A_WorkingDir
SetWorkingDir, %ScriptDir%
for each,file in ExtraFiles
{
Util_Status("Compressing and adding: " file)
StringUpper, resname, file
IfNotExist, %file%
goto _FailEnd2
FileGetSize, filesize, %file%
VarSetCapacity(filedata, filesize)
FileRead, filedata, *c %file%
if !DllCall("UpdateResource", "ptr", module, "ptr", 10, "str", resname
, "ushort", 0x409, "ptr", &filedata, "uint", filesize, "uint")
goto _FailEnd2
VarSetCapacity(filedata, 0)
}
SetWorkingDir, %oldWD%
gosub _EndUpdateResource
return
_FailEnd:
gosub _EndUpdateResource
Util_Error("Error adding script file:`n`n" AhkFile)
_FailEnd2:
gosub _EndUpdateResource
Util_Error("Error adding FileInstall file:`n`n" file)
_EndUpdateResource:
if !DllCall("EndUpdateResource", "ptr", module, "uint", 0)
Util_Error("Error: Error opening the destination file.")
return
}
Util_GetFullPath(path)
{
VarSetCapacity(fullpath, 260 * (!!A_IsUnicode + 1))
if DllCall("GetFullPathName", "str", path, "uint", 260, "str", fullpath, "ptr", 0, "uint")
return fullpath
else
return ""
}
SendMode Input
DEBUG := !A_IsCompiled
gosub BuildBinFileList
gosub LoadSettings
gosub ParseCmdLine
if !UsesCustomBin
gosub CheckAutoHotkeySC
if CLIMode
{
gosub ConvertCLI
ExitApp, 0
}
IcoFile = %LastIcon%
BinFileId := FindBinFile(LastBinFile)
ScriptFileCP := A_FileEncoding
Menu, FileMenu, Add, &Convert, Convert
Menu, FileMenu, Add
Menu, FileMenu, Add, E&xit`tAlt+F4, GuiClose
Menu, HelpMenu, Add, &Help, Help
Menu, HelpMenu, Add
Menu, HelpMenu, Add, &About, About
Menu, MenuBar, Add, &File, :FileMenu
Menu, MenuBar, Add, &Help, :HelpMenu
Gui, Menu, MenuBar
Gui, +LastFound
GuiHwnd := WinExist("")
Gui, Add, Link, x287 y25,
(
使2004-2009 Chris Mallet
使2008-2011 Steve Gray (Lexikos)
使2011-%A_Year% fincs
<a href="http://ahkscript.org</a">http://ahkscript.org">http://ahkscript.org</a>
Note: Compiling does not guarantee source code protection.
)
Gui, Add, Text, x11 y117 w570 h2 +0x1007
Gui, Add, GroupBox, x11 y124 w570 h86, Required Parameters
Gui, Add, Text, x17 y151, &Source (script file)
Gui, Add, Edit, x137 y146 w315 h23 +Disabled vAhkFile, %AhkFile%
Gui, Add, Button, x459 y146 w53 h23 gBrowseAhk, &Browse
Gui, Add, Text, x17 y180, &Destination (.exe file)
Gui, Add, Edit, x137 y176 w315 h23 +Disabled vExeFile, %Exefile%
Gui, Add, Button, x459 y176 w53 h23 gBrowseExe, B&rowse
Gui, Add, GroupBox, x11 y219 w570 h106, Optional Parameters
Gui, Add, Text, x18 y245, Custom Icon (.ico file)
Gui, Add, Edit, x138 y241 w315 h23 +Disabled vIcoFile, %IcoFile%
Gui, Add, Button, x461 y241 w53 h23 gBrowseIco, Br&owse
Gui, Add, Button, x519 y241 w53 h23 gDefaultIco, D&efault
Gui, Add, Text, x18 y274, Base File (.bin)
Gui, Add, DDL, x138 y270 w315 h23 R10 AltSubmit vBinFileId Choose%BinFileId%, %BinNames%
Gui, Add, CheckBox, x138 y298 w315 h20 vUseMpress Checked%LastUseMPRESS%, Use MPRESS (if present) to compress resulting exe
Gui, Add, Button, x258 y329 w75 h28 Default gConvert, > &Convert <
Gui, Add, Statusbar,, Ready
if !A_IsCompiled
Gui, Add, Pic, x29 y16 w240 h78, %A_ScriptDir%\logo.png
else
gosub AddPicture
GuiControl, Focus, Button1
Gui, Show, w594 h383, Ahk2Exe for AutoHotkey v%A_AhkVersion% -- Script to EXE Converter
return
GuiClose:
Gui, Submit
gosub SaveSettings
ExitApp
GuiDropFiles:
if A_EventInfo > 2
Util_Error("You cannot drop more than one file into this window!")
SplitPath, A_GuiEvent,,, dropExt
if dropExt = ahk
GuiControl,, AhkFile, %A_GuiEvent%
else if dropExt = ico
GuiControl,, IcoFile, %A_GuiEvent%
return
AddPicture:
Gui, Add, Text, x29 y16 w240 h78 +0xE hwndhPicCtrl
hRSrc := DllCall("FindResource", "ptr", 0, "str", "LOGO.PNG", "ptr", 10, "ptr")
sData := DllCall("SizeofResource", "ptr", 0, "ptr", hRSrc, "uint")
hRes  := DllCall("LoadResource", "ptr", 0, "ptr", hRSrc, "ptr")
pData := DllCall("LockResource", "ptr", hRes, "ptr")
hGlob := DllCall("GlobalAlloc", "uint", 2, "uint", sData, "ptr")
pGlob := DllCall("GlobalLock", "ptr", hGlob, "ptr")
DllCall("msvcrt\memcpy", "ptr", pGlob, "ptr", pData, "uint", sData, "CDecl")
DllCall("GlobalUnlock", "ptr", hGlob)
DllCall("ole32\CreateStreamOnHGlobal", "ptr", hGlob, "int", 1, "ptr*", pStream)
hGdip := DllCall("LoadLibrary", "str", "gdiplus")
VarSetCapacity(si, 16, 0), NumPut(1, si, "UChar")
DllCall("gdiplus\GdiplusStartup", "ptr*", gdipToken, "ptr", &si, "ptr", 0)
DllCall("gdiplus\GdipCreateBitmapFromStream", "ptr", pStream, "ptr*", pBitmap)
DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", pBitmap, "ptr*", hBitmap, "uint", 0)
SendMessage, 0x172, 0, hBitmap,, ahk_id %hPicCtrl%
GuiControl, Move, %hPicCtrl%, w240 h78
DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
DllCall("gdiplus\GdiplusShutdown", "ptr", gdipToken)
DllCall("FreeLibrary", "ptr", hGdip)
ObjRelease(pStream)
return
Never:
FileInstall, logo.png, NEVER
return
BuildBinFileList:
BinFiles := ["AutoHotkeySC.bin"]
BinNames = (Default)
Loop, %A_ScriptDir%\*.bin
{
SplitPath, A_LoopFileFullPath,,,, n
if n = AutoHotkeySC
continue
FileGetVersion, v, %A_LoopFileFullPath%
BinFiles.Insert(n ".bin")
BinNames .= "|v" v " " n
}
return
CheckAutoHotkeySC:
IfNotExist, %A_ScriptDir%\AutoHotkeySC.bin
{
try FileAppend, test, %A_ScriptDir%\___.tmp
catch
{
MsgBox, 52, Ahk2Exe Error,
  (LTrim
  Unable to copy the appropriate binary file as AutoHotkeySC.bin because the current user does not have write/create privileges in the %A_ScriptDir% folder (perhaps you should run this program as administrator?)
  
  Do you still want to continue?
)
IfMsgBox, Yes
return
ExitApp, 0x2
}
FileDelete, %A_ScriptDir%\___.tmp
IfNotExist, %A_ScriptDir%\..\AutoHotkey.exe
binFile = %A_ScriptDir%\Unicode 32-bit.bin
else
{
try FileDelete, %A_Temp%\___temp.ahk
FileAppend, ExitApp `% (A_IsUnicode=1) << 8 | (A_PtrSize=8) << 9, %A_Temp%\___temp.ahk
RunWait, "%A_ScriptDir%\..\AutoHotkey.exe" "%A_Temp%\___temp.ahk"
rc := ErrorLevel
FileDelete,  %A_Temp%\___temp.ahk
if rc = 0
binFile = %A_ScriptDir%\ANSI 32-bit.bin
else if rc = 0x100
binFile = %A_ScriptDir%\Unicode 32-bit.bin
else if rc = 0x300
binFile = %A_ScriptDir%\Unicode 64-bit.bin
}
IfNotExist, %binFile%
{
MsgBox, 52, Ahk2Exe Error,
  (LTrim
  Unable to copy the appropriate binary file as AutoHotkeySC.bin because said file does not exist:
  %binFile%
  
  Do you still want to continue?
)
IfMsgBox, Yes
return
ExitApp, 0x2
}
FileCopy, %binFile%, %A_ScriptDir%\AutoHotkeySC.bin
}
return
FindBinFile(name)
{
global BinFiles
for k,v in BinFiles
if (v = name)
return k
return 1
}
ParseCmdLine:
if 0 = 0
return
Error_ForceExit := true
p := []
Loop, %0%
{
if %A_Index% = /NoDecompile
Util_Error("Error: /NoDecompile is not supported.")
else p.Insert(%A_Index%)
}
if Mod(p.MaxIndex(), 2)
goto BadParams
Loop, % p.MaxIndex() // 2
{
p1 := p[2*(A_Index-1)+1]
p2 := p[2*(A_Index-1)+2]
if p1 not in /in,/out,/icon,/pass,/bin,/mpress,/cp
goto BadParams
if p1 = /bin
UsesCustomBin := true
if p1 = /pass
Util_Error("Error: Password protection is not supported.")
if p2 =
goto BadParams
StringTrimLeft, p1, p1, 1
gosub _Process%p1%
}
if !AhkFile
goto BadParams
if !IcoFile
IcoFile := LastIcon
if !BinFile
BinFile := A_ScriptDir "\" LastBinFile
if UseMPRESS =
UseMPRESS := LastUseMPRESS
CLIMode := true
return
BadParams:
Util_Info("Command Line Parameters:`n`n" A_ScriptName " /in infile.ahk [/out outfile.exe] [/icon iconfile.ico] [/bin AutoHotkeySC.bin] [/mpress 1 (true) or 0 (false)] [/cp codepage]")
ExitApp, 0x3
_ProcessIn:
AhkFile := p2
return
_ProcessOut:
ExeFile := p2
return
_ProcessIcon:
IcoFile := p2
return
_ProcessBin:
CustomBinFile := true
BinFile := p2
return
_ProcessMPRESS:
UseMPRESS := p2
return
_ProcessCP:
if p2 is number
ScriptFileCP := "CP" p2
else
ScriptFileCP := p2
return
BrowseAhk:
Gui, +OwnDialogs
FileSelectFile, ov, 1, %LastScriptDir%, Open, AutoHotkey files (*.ahk)
if ErrorLevel
return
GuiControl,, AhkFile, %ov%
return
BrowseExe:
Gui, +OwnDialogs
FileSelectFile, ov, S16, %LastExeDir%, Save As, Executable files (*.exe)
if ErrorLevel
return
SplitPath, ov,,, ovExt
if !StrLen(ovExt)
ov .= ".exe"
GuiControl,, ExeFile, %ov%
return
BrowseIco:
Gui, +OwnDialogs
FileSelectFile, ov, 1, %LastIconDir%, Open, Icon files (*.ico)
if ErrorLevel
return
GuiControl,, IcoFile, %ov%
return
DefaultIco:
GuiControl,, IcoFile
return
Convert:
Gui, +OwnDialogs
Gui, Submit, NoHide
BinFile := A_ScriptDir "\" BinFiles[BinFileId]
ConvertCLI:
AhkCompile(AhkFile, ExeFile, IcoFile, BinFile, UseMpress, ScriptFileCP)
if !CLIMode
Util_Info("Conversion complete.")
else
FileAppend, Successfully compiled: %ExeFile%`n, *
return
LoadSettings:
RegRead, LastScriptDir, HKCU, Software\AutoHotkey\Ahk2Exe, LastScriptDir
RegRead, LastExeDir, HKCU, Software\AutoHotkey\Ahk2Exe, LastExeDir
RegRead, LastIconDir, HKCU, Software\AutoHotkey\Ahk2Exe, LastIconDir
RegRead, LastIcon, HKCU, Software\AutoHotkey\Ahk2Exe, LastIcon
RegRead, LastBinFile, HKCU, Software\AutoHotkey\Ahk2Exe, LastBinFile
RegRead, LastUseMPRESS, HKCU, Software\AutoHotkey\Ahk2Exe, LastUseMPRESS
if LastBinFile =
LastBinFile = AutoHotkeySC.bin
if LastUseMPRESS
LastUseMPRESS := true
return
SaveSettings:
SplitPath, AhkFile,, AhkFileDir
if ExeFile
SplitPath, ExeFile,, ExeFileDir
else
ExeFileDir := LastExeDir
if IcoFile
SplitPath, IcoFile,, IcoFileDir
else
IcoFileDir := ""
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastScriptDir, %AhkFileDir%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastExeDir, %ExeFileDir%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastIconDir, %IcoFileDir%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastIcon, %IcoFile%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastUseMPRESS, %UseMPRESS%
if !CustomBinFile
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastBinFile, % BinFiles[BinFileId]
return
Help:
helpfile = %A_ScriptDir%\..\AutoHotkey.chm
IfNotExist, %helpfile%
Util_Error("Error: cannot find AutoHotkey help file!")
VarSetCapacity(ak, ak_size := 8+5*A_PtrSize+4, 0)
NumPut(ak_size, ak, 0, "UInt")
name = Ahk2Exe
NumPut(&name, ak, 8)
DllCall("hhctrl.ocx\HtmlHelp", "ptr", GuiHwnd, "str", helpfile, "uint", 0x000D, "ptr", &ak)
return
About:
MsgBox, 64, About Ahk2Exe,
(
Ahk2Exe - Script to EXE Converter
Original version:
  Copyright 使1999-2003 Jonathan Bennett & AutoIt Team
  Copyright 使2004-2009 Chris Mallet
  Copyright 使2008-2011 Steve Gray (Lexikos)
Script rewrite:
  Copyright 使2011-%A_Year% fincs
)
return
Util_Status(s)
{
SB_SetText(s)
}
Util_Error(txt, doexit=1, extra="")
{
global CLIMode, Error_ForceExit, ExeFileTmp
if ExeFileTmp && FileExist(ExeFileTmp)
{
FileDelete, %ExeFileTmp%
ExeFileTmp =
}
if extra
txt .= "`n`nSpecifically: " extra
Util_HideHourglass()
MsgBox, 16, Ahk2Exe Error, % txt
if CLIMode
FileAppend, Failed to compile: %ExeFile%`n, *
Util_Status("Ready")
if doexit
if !Error_ForceExit
Exit, % Util_ErrorCode(txt)
else
ExitApp, % Util_ErrorCode(txt)
}
Util_ErrorCode(x)
{
if InStr(x,"Syntax")
if InStr(x,"FileInstall")
return 0x12
else
return 0x11
if InStr(x,"AutoHotkeySC")
if InStr(x,"copy")
return 0x41
else
return 0x34
if InStr(x,"file")
if InStr(x,"open")
if InStr(x,"cannot")
return 0x32
else
return 0x31
else if InStr(x,"adding")
if InStr(x,"FileInstall")
return 0x44
else
return 0x43
else if InStr(x,"cannot")
if InStr(x,"drop")
return 0x51
else
return 0x52
else if InStr(x,"final")
return 0x45
else
return 0x33
if InStr(x,"Supported")
if InStr(x,"De")
if InStr(x,"#")
if InStr(x,"ref")
return 0x21
else
return 0x22
else
return 0x23
else
return 0x24
if InStr(x,"build used")
if InStr(x,"Legacy")
return 0x26
else
return 0x25
if InStr(x,"icon")
return 0x42
if InStr(x,"codepage")
return 0x53
return 0x1
}
Util_Info(txt)
{
MsgBox, 64, Ahk2Exe, % txt
}
Util_DisplayHourglass()
{
DllCall("SetCursor", "ptr", DllCall("LoadCursor", "ptr", 0, "ptr", 32514, "ptr"))
}
Util_HideHourglass()
{
DllCall("SetCursor", "ptr", DllCall("LoadCursor", "ptr", 0, "ptr", 32512, "ptr"))
}
AHKType(exeName)
{
FileGetVersion, vert, %exeName%
if !vert
return "FAIL"
StringSplit, vert, vert, .
vert := vert4 | (vert3 << 8) | (vert2 << 16) | (vert1 << 24)
exeMachine := GetExeMachine(exeName)
if !exeMachine
return "FAIL"
if (exeMachine != 0x014C) && (exeMachine != 0x8664)
return "FAIL"
if !(VersionInfoSize := DllCall("version\GetFileVersionInfoSize", "str", exeName, "uint*", null, "uint"))
return "FAIL"
VarSetCapacity(VersionInfo, VersionInfoSize)
if !DllCall("version\GetFileVersionInfo", "str", exeName, "uint", 0, "uint", VersionInfoSize, "ptr", &VersionInfo)
return "FAIL"
if !DllCall("version\VerQueryValue", "ptr", &VersionInfo, "str", "\VarFileInfo\Translation", "ptr*", lpTranslate, "uint*", cbTranslate)
return "FAIL"
oldFmt := A_FormatInteger
SetFormat, IntegerFast, H
wLanguage := NumGet(lpTranslate+0, "UShort")
wCodePage := NumGet(lpTranslate+2, "UShort")
id := SubStr("0000" SubStr(wLanguage, 3), -3, 4) SubStr("0000" SubStr(wCodePage, 3), -3, 4)
SetFormat, IntegerFast, %oldFmt%
if !DllCall("version\VerQueryValue", "ptr", &VersionInfo, "str", "\StringFileInfo\" id "\ProductName", "ptr*", pField, "uint*", cbField)
return "FAIL"
if !InStr(StrGet(pField, cbField), "AutoHotkey")
return "FAIL"
return vert >= 0x01010000 ? "Modern" : "Legacy"
}
GetExeMachine(exepath)
{
exe := FileOpen(exepath, "r")
if !exe
return
exe.Seek(60), exe.Seek(exe.ReadUInt()+4)
return exe.ReadUShort()
}