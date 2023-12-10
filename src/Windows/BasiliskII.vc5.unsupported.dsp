# Microsoft Developer Studio Project File - Name="BasiliskII" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 5.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Application" 0x0101

CFG=BasiliskII - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "BasiliskII.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "BasiliskII.mak" CFG="BasiliskII - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "BasiliskII - Win32 Release" (based on "Win32 (x86) Application")
!MESSAGE "BasiliskII - Win32 Debug" (based on "Win32 (x86) Application")
!MESSAGE "BasiliskII - Win32 Profile" (based on "Win32 (x86) Application")
!MESSAGE 

# Begin Project
# PROP Scc_ProjName "BasiliskII"
# PROP Scc_LocalPath ""
CPP=cl.exe
MTL=midl.exe
RSC=rc.exe

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Release"
# PROP Intermediate_Dir "Release"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /YX /FD /c
# ADD CPP /nologo /G4 /Gz /Zp4 /MT /W3 /GX /Zi /O2 /Op /Ob2 /I ".\include" /I ".\uae_cpu" /I "..\include" /I "..\uae_cpu" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /FR /Yu"sysdeps.h" /FD /c
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /machine:I386
# ADD LINK32 kernel32.lib user32.lib gdi32.lib comdlg32.lib advapi32.lib shell32.lib ddraw.lib winmm.lib /nologo /subsystem:windows /debug /machine:I386

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "Debug"
# PROP Intermediate_Dir "Debug"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /YX /FD /ZI /GZ /c
# ADD CPP /nologo /Gz /Zp4 /MT /W3 /Gm /GX /Zi /Od /I ".\include" /I ".\uae_cpu" /I "..\include" /I "..\uae_cpu" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /FR /FD /c
# SUBTRACT CPP /YX
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept
# ADD LINK32 kernel32.lib user32.lib gdi32.lib comdlg32.lib advapi32.lib shell32.lib ddraw.lib winmm.lib /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Basilisk"
# PROP BASE Intermediate_Dir "Basilisk"
# PROP BASE Ignore_Export_Lib 0
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Basilisk"
# PROP Intermediate_Dir "Basilisk"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /Gz /Zp4 /MT /W3 /GX /O2 /Ob2 /I ".\include" /I ".\uae_cpu" /I "..\include" /I "..\uae_cpu" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /FR /YX /FD /c
# ADD CPP /nologo /Gz /Zp4 /MT /W3 /GX /Zi /O2 /Ob2 /I ".\include" /I ".\uae_cpu" /I "..\include" /I "..\uae_cpu" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /FR /YX /FD /c
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib comdlg32.lib advapi32.lib shell32.lib ddraw.lib winmm.lib /nologo /subsystem:windows /machine:I386
# SUBTRACT BASE LINK32 /debug
# ADD LINK32 kernel32.lib user32.lib gdi32.lib comdlg32.lib advapi32.lib shell32.lib ddraw.lib winmm.lib /nologo /subsystem:windows /profile /map /debug /machine:I386

!ENDIF 

# Begin Target

# Name "BasiliskII - Win32 Release"
# Name "BasiliskII - Win32 Debug"
# Name "BasiliskII - Win32 Profile"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat"
# Begin Source File

SOURCE=..\adb.cpp
# End Source File
# Begin Source File

SOURCE=..\audio.cpp
# End Source File
# Begin Source File

SOURCE=..\cdrom.cpp
# End Source File
# Begin Source File

SOURCE=..\disk.cpp
# End Source File
# Begin Source File

SOURCE=..\emul_op.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Zi

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\ether.cpp
# End Source File
# Begin Source File

SOURCE=..\macos_util.cpp
# End Source File
# Begin Source File

SOURCE=..\prefs.cpp
# End Source File
# Begin Source File

SOURCE=..\rom_patches.cpp
# End Source File
# Begin Source File

SOURCE=..\rsrc_patches.cpp
# End Source File
# Begin Source File

SOURCE=..\scsi.cpp
# End Source File
# Begin Source File

SOURCE=..\serial.cpp
# End Source File
# Begin Source File

SOURCE=..\slot_rom.cpp
# End Source File
# Begin Source File

SOURCE=..\sony.cpp
# End Source File
# Begin Source File

SOURCE=..\timer.cpp
# End Source File
# Begin Source File

SOURCE=..\user_strings.cpp
# End Source File
# Begin Source File

SOURCE=..\video.cpp
# End Source File
# Begin Source File

SOURCE=..\xpram.cpp
# End Source File
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "h;hpp;hxx;hm;inl"
# Begin Source File

SOURCE=..\include\adb.h
# End Source File
# Begin Source File

SOURCE=..\include\cdrom.h
# End Source File
# Begin Source File

SOURCE=..\include\clip.h
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\compiler.h
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\cpu_emulation.h
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\cputbl.h
# End Source File
# Begin Source File

SOURCE=..\include\debug.h
# End Source File
# Begin Source File

SOURCE=..\include\disk.h
# End Source File
# Begin Source File

SOURCE=..\include\emul_op.h
# End Source File
# Begin Source File

SOURCE=..\include\ether.h
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\m68k.h
# End Source File
# Begin Source File

SOURCE=..\include\macos_util.h
# End Source File
# Begin Source File

SOURCE=..\include\main.h
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\newcpu.h
# End Source File
# Begin Source File

SOURCE=..\include\prefs.h
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\readcpu.h
# End Source File
# Begin Source File

SOURCE=..\include\rom_patches.h
# End Source File
# Begin Source File

SOURCE=..\include\rsrc_patches.h
# End Source File
# Begin Source File

SOURCE=..\include\scsi.h
# End Source File
# Begin Source File

SOURCE=..\include\serial.h
# End Source File
# Begin Source File

SOURCE=..\include\serial_defs.h
# End Source File
# Begin Source File

SOURCE=..\include\slot_rom.h
# End Source File
# Begin Source File

SOURCE=..\include\sony.h
# End Source File
# Begin Source File

SOURCE=..\include\sys.h
# End Source File
# Begin Source File

SOURCE=..\include\timer.h
# End Source File
# Begin Source File

SOURCE=..\include\uae_compiler.h
# End Source File
# Begin Source File

SOURCE=..\include\uae_cputbl.h
# End Source File
# Begin Source File

SOURCE=..\include\uae_m68k.h
# End Source File
# Begin Source File

SOURCE=..\include\uae_memory.h
# End Source File
# Begin Source File

SOURCE=..\include\uae_newcpu.h
# End Source File
# Begin Source File

SOURCE=..\include\uae_readcpu.h
# End Source File
# Begin Source File

SOURCE=..\include\user_strings.h
# End Source File
# Begin Source File

SOURCE=..\include\version.h
# End Source File
# Begin Source File

SOURCE=..\include\video.h
# End Source File
# Begin Source File

SOURCE=..\include\video_defs.h
# End Source File
# Begin Source File

SOURCE=..\include\xpram.h
# End Source File
# End Group
# Begin Group "Windows"

# PROP Default_Filter ""
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
# End Group
# Begin Group "Headers"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\b2ether\inc\b2ether_hl.h
# End Source File
# Begin Source File

SOURCE=.\cd_defs.h
# End Source File
# Begin Source File

SOURCE=.\desktop_windows.h
# End Source File
# Begin Source File

SOURCE=.\dialog_windows.h
# End Source File
# Begin Source File

SOURCE=..\Include\ether_defs.h
# End Source File
# Begin Source File

SOURCE=.\main_windows.h
# End Source File
# Begin Source File

SOURCE=.\B2ether\Inc\Ntddpack.h
# End Source File
# Begin Source File

SOURCE=.\prefs_windows.h
# End Source File
# Begin Source File

SOURCE=.\sys_windows.h
# End Source File
# Begin Source File

SOURCE=.\sysdeps.h
# End Source File
# Begin Source File

SOURCE=.\timer_windows.h
# End Source File
# Begin Source File

SOURCE=.\util_windows.h
# End Source File
# Begin Source File

SOURCE=.\video_windows.h
# End Source File
# Begin Source File

SOURCE=.\xpram_windows.h
# End Source File
# End Group
# Begin Group "cdenable"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\cdenable\Cache.cpp
# End Source File
# Begin Source File

SOURCE=.\cdenable\Cache.h
# End Source File
# Begin Source File

SOURCE=.\cdenable\cdenable.h
# End Source File
# Begin Source File

SOURCE=.\cdenable\Eject_nt.cpp
# End Source File
# Begin Source File

SOURCE=.\cdenable\eject_nt.h
# End Source File
# Begin Source File

SOURCE=.\Cdenable\Eject_w9x.cpp
# End Source File
# Begin Source File

SOURCE=.\Cdenable\eject_w9x.h
# End Source File
# Begin Source File

SOURCE=.\cdenable\Ntcd.cpp
# End Source File
# Begin Source File

SOURCE=.\cdenable\ntcd.h
# End Source File
# Begin Source File

SOURCE=.\Cdenable\Vxdiface.cpp
# End Source File
# Begin Source File

SOURCE=.\Cdenable\Vxdiface.h
# End Source File
# End Group
# Begin Group "aspi headers"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\scsidefs.h
# End Source File
# Begin Source File

SOURCE=.\wnaspi32.h
# End Source File
# End Group
# Begin Group "uae windows"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\uae_cpu_windows\Memory.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\uae_cpu_windows\Newcpu.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ENDIF 

# End Source File
# End Group
# Begin Group "asm"

# PROP Default_Filter ""
# End Group
# Begin Group "Batch files"

# PROP Default_Filter "bat"
# Begin Source File

SOURCE=.\opti.bat
# End Source File
# End Group
# Begin Group "ethernet"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\b2ether\packet32.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Zi

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ENDIF 

# End Source File
# End Group
# Begin Source File

SOURCE=.\BasiliskII.rc
# End Source File
# Begin Source File

SOURCE=.\check_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\clip_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\desktop_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\ether_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Zi

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\headers_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Yc"headers_windows.h"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\kernel_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\keyboard_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\main_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Zi

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\prefs_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\scsi_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\serial_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\sys_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Zi

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\threads_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\timer_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /FAs

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# ADD BASE CPP /FAs
# ADD CPP /FAs

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\util_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\video_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Zi /FAs

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\w9xfloppy.cpp
# End Source File
# Begin Source File

SOURCE=.\xpram_windows.cpp
# End Source File
# End Group
# Begin Group "uae"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\uae_cpu\basilisk_glue.cpp
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\cpuemu.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Zi /FAs

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# ADD BASE CPP /Zi /FAs
# ADD CPP /Zi /FAs

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\uae_cpu\cpustbl.cpp
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\fpp.cpp
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\memory.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\uae_cpu\newcpu.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\uae_cpu\readcpu.cpp
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\table68k.cpp
# End Source File
# End Group
# Begin Group "AmigaOS"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\AmigaOS\asm_support.asm

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\AmigaOS\clip_amiga.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\AmigaOS\ether_amiga.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\AmigaOS\main_amiga.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\AmigaOS\prefs_amiga.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\AmigaOS\scsi_amiga.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\AmigaOS\serial_amiga.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\AmigaOS\sys_amiga.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\AmigaOS\sysdeps.h

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\AmigaOS\timer_amiga.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\AmigaOS\video_amiga.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\AmigaOS\xpram_amiga.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# End Group
# Begin Group "BeOS"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\BeOS\clip_beos.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\BeOS\ether_beos.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\BeOS\main_beos.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\BeOS\meme.h

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\BeOS\prefs_beos.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\BeOS\scsi_beos.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\BeOS\serial_beos.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\BeOS\sys_beos.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\BeOS\sysdeps.h
# End Source File
# Begin Source File

SOURCE=..\BeOS\timer_beos.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\BeOS\video_beos.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\BeOS\xpram_beos.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# End Group
# Begin Group "Unix"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\Unix\clip_unix.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\Unix\ether_linux.cpp
# PROP Exclude_From_Build 1
# End Source File
# Begin Source File

SOURCE=..\Unix\main_unix.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\Unix\prefs_unix.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\Unix\serial_unix.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\Unix\sys_unix.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\Unix\sysdeps.h

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\Unix\timer_unix.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\Unix\video_x.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\Unix\xpram_unix.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# End Group
# Begin Group "Documents"

# PROP Default_Filter "*.txt,*.win32,*.doc"
# Begin Source File

SOURCE=..\..\CHANGES
# End Source File
# Begin Source File

SOURCE=..\..\Changes.win32.txt
# End Source File
# Begin Source File

SOURCE=..\..\Ethernet.win32.txt
# End Source File
# Begin Source File

SOURCE=..\..\Util\Optimize.txt
# End Source File
# Begin Source File

SOURCE=..\..\README
# End Source File
# Begin Source File

SOURCE=..\..\Readme.win32.txt
# End Source File
# Begin Source File

SOURCE=..\..\TECH
# End Source File
# Begin Source File

SOURCE=..\..\Tech.win32.txt
# End Source File
# End Group
# Begin Source File

SOURCE=..\..\test\BasiliskII_prefs
# End Source File
# End Target
# End Project
