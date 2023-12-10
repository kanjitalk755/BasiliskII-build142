# Microsoft Developer Studio Project File - Name="BasiliskIIGUI" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 5.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Application" 0x0101

CFG=BasiliskIIGUI - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "BasiliskIIGUI.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "BasiliskIIGUI.mak" CFG="BasiliskIIGUI - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "BasiliskIIGUI - Win32 Release" (based on "Win32 (x86) Application")
!MESSAGE "BasiliskIIGUI - Win32 Debug" (based on "Win32 (x86) Application")
!MESSAGE 

# Begin Project
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""
CPP=cl.exe
MTL=midl.exe
RSC=rc.exe

!IF  "$(CFG)" == "BasiliskIIGUI - Win32 Release"

# PROP BASE Use_MFC 5
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 5
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Release"
# PROP Intermediate_Dir "Release"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /MT /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /Yu"stdafx.h" /FD /c
# ADD CPP /nologo /MT /W3 /GX /O2 /I "\BasiliskII\src\include" /I "\BasiliskII\src\Windows" /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /FR /Yu"stdafx.h" /FD /c
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /o NUL /win32
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /o NUL /win32
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 /nologo /subsystem:windows /machine:I386
# ADD LINK32 /nologo /subsystem:windows /machine:I386

!ELSEIF  "$(CFG)" == "BasiliskIIGUI - Win32 Debug"

# PROP BASE Use_MFC 5
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 5
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "Debug"
# PROP Intermediate_Dir "Debug"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /MTd /W3 /Gm /GX /Zi /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /Yu"stdafx.h" /FD /c
# ADD CPP /nologo /MTd /W3 /Gm /GX /Zi /Od /I "\BasiliskII\src\include" /I "\BasiliskII\src\Windows" /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /FR /Yu"stdafx.h" /FD /c
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /o NUL /win32
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /o NUL /win32
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept
# ADD LINK32 /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept

!ENDIF 

# Begin Target

# Name "BasiliskIIGUI - Win32 Release"
# Name "BasiliskIIGUI - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat"
# Begin Source File

SOURCE=.\AskSCSIReplacement.cpp
# End Source File
# Begin Source File

SOURCE=.\BasiliskIIGUI.cpp

!IF  "$(CFG)" == "BasiliskIIGUI - Win32 Release"

# ADD CPP /I "include" /I "Windows"

!ELSEIF  "$(CFG)" == "BasiliskIIGUI - Win32 Debug"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\BasiliskIIGUI.rc

!IF  "$(CFG)" == "BasiliskIIGUI - Win32 Release"

!ELSEIF  "$(CFG)" == "BasiliskIIGUI - Win32 Debug"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\BasiliskIIGUIDlg.cpp
# End Source File
# Begin Source File

SOURCE=.\dummies.cpp
# End Source File
# Begin Source File

SOURCE=.\KeyCodes.cpp
# End Source File
# Begin Source File

SOURCE=.\MakeNewHFV.cpp
# End Source File
# Begin Source File

SOURCE=.\PageAbout.cpp
# End Source File
# Begin Source File

SOURCE=.\PageAudio.cpp
# End Source File
# Begin Source File

SOURCE=.\PageCDROM.cpp
# End Source File
# Begin Source File

SOURCE=.\PageDebug.cpp
# End Source File
# Begin Source File

SOURCE=.\PageDisk.cpp
# End Source File
# Begin Source File

SOURCE=.\PageEthernet.cpp
# End Source File
# Begin Source File

SOURCE=.\PageFloppy.cpp
# End Source File
# Begin Source File

SOURCE=.\PageGeneral.cpp
# End Source File
# Begin Source File

SOURCE=.\PageKeyboard.cpp
# End Source File
# Begin Source File

SOURCE=.\PageMemory.cpp
# End Source File
# Begin Source File

SOURCE=.\PagePorts.cpp
# End Source File
# Begin Source File

SOURCE=.\PagePriorities.cpp
# End Source File
# Begin Source File

SOURCE=.\PageScreen.cpp
# End Source File
# Begin Source File

SOURCE=.\PageSCSI.cpp
# End Source File
# Begin Source File

SOURCE=.\PageTools.cpp
# End Source File
# Begin Source File

SOURCE=.\StdAfx.cpp
# ADD CPP /Yc"stdafx.h"
# End Source File
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "h;hpp;hxx;hm;inl"
# Begin Source File

SOURCE=.\AskSCSIReplacement.h
# End Source File
# Begin Source File

SOURCE=.\BasiliskIIGUI.h
# End Source File
# Begin Source File

SOURCE=.\BasiliskIIGUIDlg.h
# End Source File
# Begin Source File

SOURCE=.\KeyCodes.h
# End Source File
# Begin Source File

SOURCE=.\MakeNewHFV.h
# End Source File
# Begin Source File

SOURCE=.\PageAbout.h
# End Source File
# Begin Source File

SOURCE=.\PageCDROM.h
# End Source File
# Begin Source File

SOURCE=.\PageDisk.h
# End Source File
# Begin Source File

SOURCE=.\PageEthernet.h
# End Source File
# Begin Source File

SOURCE=.\PageFloppy.h
# End Source File
# Begin Source File

SOURCE=.\PageGeneral.h
# End Source File
# Begin Source File

SOURCE=.\PageKeyboard.h
# End Source File
# Begin Source File

SOURCE=.\PageMemory.h
# End Source File
# Begin Source File

SOURCE=.\PagePorts.h
# End Source File
# Begin Source File

SOURCE=.\PagePriorities.h
# End Source File
# Begin Source File

SOURCE=.\PageScreen.h
# End Source File
# Begin Source File

SOURCE=.\PageSCSI.h
# End Source File
# Begin Source File

SOURCE=.\PageTools.h
# End Source File
# Begin Source File

SOURCE=.\Resource.h
# End Source File
# Begin Source File

SOURCE=.\StdAfx.h
# End Source File
# End Group
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;cnt;rtf;gif;jpg;jpeg;jpe"
# Begin Source File

SOURCE=.\res\BasiliskIIGUI.ico
# End Source File
# Begin Source File

SOURCE=.\res\BasiliskIIGUI.rc2
# End Source File
# End Group
# Begin Group "BasiliskII"

# PROP Default_Filter ""
# Begin Group "B Source"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\..\keyboard_windows.cpp
# PROP Exclude_From_Build 1
# End Source File
# Begin Source File

SOURCE=..\..\..\prefs.cpp
# PROP Exclude_From_Build 1
# End Source File
# Begin Source File

SOURCE=..\..\prefs_windows.cpp
# PROP Exclude_From_Build 1
# End Source File
# Begin Source File

SOURCE=..\..\scsi_windows.cpp
# PROP Exclude_From_Build 1
# End Source File
# Begin Source File

SOURCE=..\..\util_windows.cpp
# PROP Exclude_From_Build 1
# End Source File
# End Group
# Begin Group "B Header"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\..\..\include\debug.h
# End Source File
# Begin Source File

SOURCE=..\..\keyboard_windows.h
# End Source File
# Begin Source File

SOURCE=..\..\..\include\main.h
# End Source File
# Begin Source File

SOURCE=..\..\main_windows.h
# End Source File
# Begin Source File

SOURCE=..\..\..\include\prefs.h
# End Source File
# Begin Source File

SOURCE=..\..\prefs_windows.h
# End Source File
# Begin Source File

SOURCE=..\..\..\include\scsi.h
# End Source File
# Begin Source File

SOURCE=..\..\scsi_windows.h
# End Source File
# Begin Source File

SOURCE=..\..\scsidefs.h
# End Source File
# Begin Source File

SOURCE=..\..\..\include\sys.h
# End Source File
# Begin Source File

SOURCE=..\..\sysdeps.h
# End Source File
# Begin Source File

SOURCE=..\..\..\include\user_strings.h
# End Source File
# Begin Source File

SOURCE=..\..\util_windows.h
# End Source File
# Begin Source File

SOURCE=..\..\wnaspi32.h
# End Source File
# End Group
# Begin Group "Wrappers"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\keyboard_windows_wrapper.cpp
# End Source File
# Begin Source File

SOURCE=.\packet32_wrapper.cpp
# End Source File
# Begin Source File

SOURCE=.\prefs_windows_wrapper.cpp
# End Source File
# Begin Source File

SOURCE=.\prefs_wrapper.cpp
# End Source File
# Begin Source File

SOURCE=.\scsi_windows_wrapper.cpp
# End Source File
# Begin Source File

SOURCE=.\thread_windows_wrapper.cpp
# End Source File
# Begin Source File

SOURCE=.\util_windows_wrapper.cpp
# End Source File
# End Group
# End Group
# End Target
# End Project
