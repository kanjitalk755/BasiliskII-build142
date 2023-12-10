# Microsoft Developer Studio Project File - Name="BasiliskII" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
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
!MESSAGE "BasiliskII - Win32 Win9x" (based on "Win32 (x86) Application")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
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
# ADD CPP /nologo /G5 /Gz /Zp4 /MT /W3 /GX /Zi /O1 /Ob2 /I ".\include" /I ".\uae_cpu" /I "..\include" /I "..\uae_cpu" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /FR /Yu"sysdeps.h" /FD /c
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /machine:I386
# ADD LINK32 kernel32.lib user32.lib gdi32.lib comdlg32.lib advapi32.lib shell32.lib ddraw.lib winmm.lib dxguid.lib /nologo /subsystem:windows /debug /debugtype:both /machine:I386

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
# ADD BASE CPP /nologo /W3 /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /YX /FD /GZ /c
# ADD CPP /nologo /Gz /Zp4 /MTd /w /W0 /Gm /GX /ZI /Od /I ".\include" /I ".\uae_cpu" /I "..\include" /I "..\uae_cpu" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /FR /FD /c
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
# ADD LINK32 kernel32.lib user32.lib gdi32.lib comdlg32.lib advapi32.lib shell32.lib ddraw.lib winmm.lib dxguid.lib /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept

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
# ADD CPP /nologo /Gz /Zp4 /MT /W3 /GX /Zi /O2 /Ob2 /I ".\include" /I ".\uae_cpu" /I "..\include" /I "..\uae_cpu" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /D "B2PROFILE" /FR /Yu"sysdeps.h" /FD /c
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
# ADD LINK32 kernel32.lib user32.lib gdi32.lib comdlg32.lib advapi32.lib shell32.lib ddraw.lib winmm.lib dxguid.lib /nologo /subsystem:windows /profile /map /debug /machine:I386

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "BasiliskII___Win32_Win9x"
# PROP BASE Intermediate_Dir "BasiliskII___Win32_Win9x"
# PROP BASE Ignore_Export_Lib 0
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "BasiliskII___Win32_Win9x"
# PROP Intermediate_Dir "BasiliskII___Win32_Win9x"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /G5 /Gz /Zp4 /MT /W3 /GX /Zi /O2 /Ob2 /I ".\include" /I ".\uae_cpu" /I "..\include" /I "..\uae_cpu" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /FR /Yu"sysdeps.h" /FD /c
# ADD CPP /nologo /G5 /Gz /Zp4 /MT /W3 /GX /Zi /O1 /Ob2 /I ".\include" /I ".\uae_cpu" /I "..\include" /I "..\uae_cpu" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /D "WIN9X" /FR /Yu"sysdeps.h" /FD /c
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib comdlg32.lib advapi32.lib shell32.lib ddraw.lib winmm.lib dxguid.lib /nologo /subsystem:windows /debug /debugtype:both /machine:I386
# ADD LINK32 kernel32.lib user32.lib gdi32.lib comdlg32.lib advapi32.lib shell32.lib ddraw.lib winmm.lib dxguid.lib /nologo /subsystem:windows /debug /debugtype:both /machine:I386

!ENDIF 

# Begin Target

# Name "BasiliskII - Win32 Release"
# Name "BasiliskII - Win32 Debug"
# Name "BasiliskII - Win32 Profile"
# Name "BasiliskII - Win32 Win9x"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat"
# Begin Source File

SOURCE=..\adb.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O1 /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\audio.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

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

# ADD CPP /Zi /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /Zi
# ADD CPP /Zi /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\ether.cpp
# End Source File
# Begin Source File

SOURCE=..\extfs.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O1 /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /O2 /Yu
# ADD CPP /O1 /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\macos_util.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\prefs.cpp
# End Source File
# Begin Source File

SOURCE=..\rom_patches.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O1 /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /O2 /Yu
# ADD CPP /O1 /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\rsrc_patches.cpp
# End Source File
# Begin Source File

SOURCE=.\screen_saver.cpp
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

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\timer.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\user_strings.cpp
# End Source File
# Begin Source File

SOURCE=..\video.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\xpram.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "h;hpp;hxx;hm;inl"
# Begin Source File

SOURCE=..\include\adb.h
# End Source File
# Begin Source File

SOURCE=..\include\audio.h
# End Source File
# Begin Source File

SOURCE=..\include\audio_defs.h
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

SOURCE=..\include\extfs.h
# End Source File
# Begin Source File

SOURCE=..\include\extfs_defs.h
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
# Begin Source File

SOURCE=.\b2_icon1.ico
# End Source File
# Begin Source File

SOURCE=.\BasiliskII.ico
# End Source File
# Begin Source File

SOURCE=.\BasiliskII.rc
# End Source File
# End Group
# Begin Group "Headers"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\audio_windows.h
# End Source File
# Begin Source File

SOURCE=.\b2ether\inc\b2ether_hl.h
# End Source File
# Begin Source File

SOURCE="P:\Program Files\Microsoft Visual Studio\VC98\Include\BASETSD.H"
# End Source File
# Begin Source File

SOURCE=.\cd_defs.h
# End Source File
# Begin Source File

SOURCE=.\check_windows.h
# End Source File
# Begin Source File

SOURCE=.\clip_windows.h
# End Source File
# Begin Source File

SOURCE=.\counter.h
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

SOURCE=.\ether_windows.h
# End Source File
# Begin Source File

SOURCE=.\experiment_windows.h
# End Source File
# Begin Source File

SOURCE=.\fpu.h
# End Source File
# Begin Source File

SOURCE=.\headers_windows.h
# End Source File
# Begin Source File

SOURCE=.\kernel_windows.h
# End Source File
# Begin Source File

SOURCE=.\keyboard_windows.h
# End Source File
# Begin Source File

SOURCE=.\main_windows.h
# End Source File
# Begin Source File

SOURCE=.\mem_limits.h
# End Source File
# Begin Source File

SOURCE=.\b2ether\multiopt.h
# End Source File
# Begin Source File

SOURCE=L:\MSSDK\include\ntddndis.h
# End Source File
# Begin Source File

SOURCE=.\B2ether\Inc\Ntddpack.h
# End Source File
# Begin Source File

SOURCE=.\posix_emu.h
# End Source File
# Begin Source File

SOURCE=.\prefs_windows.h
# End Source File
# Begin Source File

SOURCE=.\progress.h
# End Source File
# Begin Source File

SOURCE=.\scsi_windows.h
# End Source File
# Begin Source File

SOURCE=.\startupsound.h
# End Source File
# Begin Source File

SOURCE=.\sys_windows.h
# End Source File
# Begin Source File

SOURCE=.\sysdeps.h
# End Source File
# Begin Source File

SOURCE=.\threads_windows.h
# End Source File
# Begin Source File

SOURCE=.\timer_windows.h
# End Source File
# Begin Source File

SOURCE=.\typemap.h
# End Source File
# Begin Source File

SOURCE=.\undo_buffer.h
# End Source File
# Begin Source File

SOURCE=.\undo_windows.h
# End Source File
# Begin Source File

SOURCE=.\util_windows.h
# End Source File
# Begin Source File

SOURCE=.\video_windows.h
# End Source File
# Begin Source File

SOURCE=.\w9xfloppy.h
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

SOURCE=..\uae_cpu\compiler.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# PROP Exclude_From_Build 1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# PROP BASE Exclude_From_Build 1
# PROP Exclude_From_Build 1

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\asm\cpuemu.inc
# End Source File
# Begin Source File

SOURCE=.\asm\cpuemuop.asm

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

USERDEP__CPUEM=".\asm\cpuemu.inc"	".\asm\opdefs.inc"	".\MASM\listing.inc"	
# Begin Custom Build - Assembling $(InputPath)
IntDir=.\Release
InputPath=.\asm\cpuemuop.asm
InputName=cpuemuop

"$(IntDir)\..\Release\$(InputName).obj" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	$(IntDir)\..\masm\ml  /c /coff /Fo $(IntDir)\..\Release\$(InputName).obj $(InputPath)

# End Custom Build

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\fpu.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /G5 /Zp4 /GX /O2 /Op /Oy /Ob2 /FAs
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /Ob1 /FAcs
# SUBTRACT BASE CPP /YX /Yc /Yu
# ADD CPP /O2 /Ob1 /FAcs
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\uae_cpu\get_disp_ea_020.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2 /FAs
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /FAs
# ADD CPP /O2 /FAs
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\MASM\LISTING.INC
# End Source File
# Begin Source File

SOURCE=.\uae_cpu_windows\Memory.cpp
# End Source File
# Begin Source File

SOURCE=.\uae_cpu_windows\Newcpu.cpp
# End Source File
# Begin Source File

SOURCE=.\asm\opdefs.inc
# End Source File
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

# ADD CPP /Zi /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /Zi
# ADD CPP /Zi

!ENDIF 

# End Source File
# End Group
# Begin Group "Source"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\audio_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\check_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\clip_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\counter.cpp
# End Source File
# Begin Source File

SOURCE=.\desktop_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\ether_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Zi /Od
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /Zi
# ADD CPP /Zi /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\experiment_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\extfs_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /O2 /Yu
# ADD CPP /O1 /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\headers_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Yc"headers_windows.h"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# ADD CPP /Yc"headers_windows.h"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /Yc"headers_windows.h"
# ADD CPP /Yc"headers_windows.h"

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

# ADD CPP /Zi /O2 /Ob2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /Zi /O2 /Yu
# ADD CPP /Zi /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\mem_limits.cpp
# End Source File
# Begin Source File

SOURCE=.\posix_emu.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /O2 /Yu
# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\prefs_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O1

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\progress.cpp
# End Source File
# Begin Source File

SOURCE=.\scsi_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\serial_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\startupsound.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O1 /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\sys_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Zi /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /Zi /O2 /Yu
# ADD CPP /Zi /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\threads_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\timer_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# ADD BASE CPP /FAs
# ADD CPP /FAs

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\typemap.cpp
# End Source File
# Begin Source File

SOURCE=.\undo_buffer.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\undo_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\user_strings_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\util_windows.cpp
# End Source File
# Begin Source File

SOURCE=.\video_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /Zi /O2 /FAs
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /Zi /O2 /FAs /Yu
# ADD CPP /Zi /O2 /FAs
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\w9xfloppy.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\xpram_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# End Group
# Begin Group "Router"

# PROP Default_Filter ""
# Begin Group "Router headers"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\router\arp.h
# End Source File
# Begin Source File

SOURCE=.\router\dump.h
# End Source File
# Begin Source File

SOURCE=.\router\dynsockets.h
# End Source File
# Begin Source File

SOURCE=.\router\ftp.h
# End Source File
# Begin Source File

SOURCE=.\router\icmp.h
# End Source File
# Begin Source File

SOURCE=.\router\mib\interfaces.h
# End Source File
# Begin Source File

SOURCE=.\router\iphelp.h
# End Source File
# Begin Source File

SOURCE=.\router\ipsocket.h
# End Source File
# Begin Source File

SOURCE=.\router\mib\MibAccess.h
# End Source File
# Begin Source File

SOURCE=.\router\router.h
# End Source File
# Begin Source File

SOURCE=.\router\router_types.h
# End Source File
# Begin Source File

SOURCE=.\router\tcp.h
# End Source File
# Begin Source File

SOURCE=.\router\udp.h
# End Source File
# End Group
# Begin Source File

SOURCE=.\router\arp.cpp
# End Source File
# Begin Source File

SOURCE=.\router\dump.cpp
# End Source File
# Begin Source File

SOURCE=.\router\dynsockets.cpp
# End Source File
# Begin Source File

SOURCE=.\router\ftp.cpp
# End Source File
# Begin Source File

SOURCE=.\router\icmp.cpp
# End Source File
# Begin Source File

SOURCE=.\router\mib\interfaces.cpp
# End Source File
# Begin Source File

SOURCE=.\router\iphelp.cpp
# End Source File
# Begin Source File

SOURCE=.\router\ipsocket.cpp
# End Source File
# Begin Source File

SOURCE=.\router\mib\MibAccess.cpp
# End Source File
# Begin Source File

SOURCE=.\router\router.cpp
# End Source File
# Begin Source File

SOURCE=.\router\tcp.cpp
# End Source File
# Begin Source File

SOURCE=.\router\udp.cpp
# End Source File
# End Group
# End Group
# Begin Group "uae"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\uae_cpu\basilisk_glue.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD CPP /O2
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\uae_cpu\cpuemu.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

# PROP Exclude_From_Build 1
# ADD CPP /Zi /O2 /Ob1 /FA
# SUBTRACT CPP /YX /Yc /Yu

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Profile"

# ADD BASE CPP /Zi /FAs
# ADD CPP /Zi /FAs

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Win9x"

# ADD BASE CPP /Zi /FAs
# ADD CPP /Zi /O2 /FAs
# SUBTRACT CPP /YX /Yc /Yu

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\uae_cpu\cpuemu.h
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\cpustbl.cpp
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\fpp.cpp
# PROP Exclude_From_Build 1
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\memory.h
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\readcpu.cpp
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\table68k
# End Source File
# Begin Source File

SOURCE=..\uae_cpu\table68k.cpp
# End Source File
# End Group
# Begin Group "Documents"

# PROP Default_Filter "*.txt,*.win32,*.doc"
# Begin Group "Christian"

# PROP Default_Filter ""
# Begin Source File

SOURCE="..\..\Setup\General documents\ChangeLog"
# End Source File
# Begin Source File

SOURCE="..\..\Setup\General documents\COPYING"
# End Source File
# Begin Source File

SOURCE="..\..\Setup\General documents\INSTALL"
# End Source File
# Begin Source File

SOURCE="..\..\Setup\General documents\README"
# End Source File
# Begin Source File

SOURCE="..\..\Setup\General documents\TECH"
# End Source File
# Begin Source File

SOURCE="..\..\Setup\General documents\TODO"
# End Source File
# End Group
# Begin Group "Windows port"

# PROP Default_Filter ""
# Begin Source File

SOURCE="..\..\Setup\Windows-specific documents\Changes.win32.txt"
# End Source File
# Begin Source File

SOURCE="..\..\Setup\Windows-specific documents\Ethernet.win32.txt"
# End Source File
# Begin Source File

SOURCE="..\..\Setup\Windows-specific documents\NAT-Router FAQ.html"
# End Source File
# Begin Source File

SOURCE="..\..\Setup\Windows-specific documents\Readme.win32.txt"
# End Source File
# Begin Source File

SOURCE="..\..\Setup\Windows-specific documents\Speed tips.txt"
# End Source File
# Begin Source File

SOURCE="..\..\Setup\Windows-specific documents\Tech.win32.txt"
# End Source File
# End Group
# Begin Group "Internal"

# PROP Default_Filter ""
# Begin Source File

SOURCE="..\..\Util\Apple Personal Diagnostics.txt"
# End Source File
# Begin Source File

SOURCE=..\..\Util\Optimize.txt
# End Source File
# Begin Source File

SOURCE="c:\doc\todo before release.txt"
# End Source File
# End Group
# End Group
# Begin Group "Test"

# PROP Default_Filter ""
# Begin Source File

SOURCE=C:\WINNT\BasiliskII.ini
# End Source File
# Begin Source File

SOURCE=..\..\test\BasiliskII_prefs
# End Source File
# Begin Source File

SOURCE=..\..\test\stderr.txt
# End Source File
# Begin Source File

SOURCE=..\..\test\stdout.txt
# End Source File
# End Group
# End Target
# End Project
