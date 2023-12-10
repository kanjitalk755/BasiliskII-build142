# Microsoft Developer Studio Generated NMAKE File, Based on BasiliskII.dsp
!IF "$(CFG)" == ""
CFG=BasiliskII - Win32 Debug
!MESSAGE No configuration specified. Defaulting to BasiliskII - Win32 Debug.
!ENDIF 

!IF "$(CFG)" != "BasiliskII - Win32 Release" && "$(CFG)" !=\
 "BasiliskII - Win32 Debug"
!MESSAGE Invalid configuration "$(CFG)" specified.
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "BasiliskII.mak" CFG="BasiliskII - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "BasiliskII - Win32 Release" (based on "Win32 (x86) Application")
!MESSAGE "BasiliskII - Win32 Debug" (based on "Win32 (x86) Application")
!MESSAGE 
!ERROR An invalid configuration is specified.
!ENDIF 

!IF "$(OS)" == "Windows_NT"
NULL=
!ELSE 
NULL=nul
!ENDIF 

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

OUTDIR=.\Release
INTDIR=.\Release
# Begin Custom Macros
OutDir=.\Release
# End Custom Macros

!IF "$(RECURSE)" == "0" 

ALL : "$(OUTDIR)\BasiliskII.exe" "$(OUTDIR)\BasiliskII.bsc"

!ELSE 

ALL : "$(OUTDIR)\BasiliskII.exe" "$(OUTDIR)\BasiliskII.bsc"

!ENDIF 

CLEAN :
	-@erase "$(INTDIR)\adb.obj"
	-@erase "$(INTDIR)\adb.sbr"
	-@erase "$(INTDIR)\Cache.obj"
	-@erase "$(INTDIR)\Cache.sbr"
	-@erase "$(INTDIR)\cdrom.obj"
	-@erase "$(INTDIR)\cdrom.sbr"
	-@erase "$(INTDIR)\clip_windows.obj"
	-@erase "$(INTDIR)\clip_windows.sbr"
	-@erase "$(INTDIR)\disk.obj"
	-@erase "$(INTDIR)\disk.sbr"
	-@erase "$(INTDIR)\Eject_nt.obj"
	-@erase "$(INTDIR)\Eject_nt.sbr"
	-@erase "$(INTDIR)\emul_op.obj"
	-@erase "$(INTDIR)\emul_op.sbr"
	-@erase "$(INTDIR)\ether.obj"
	-@erase "$(INTDIR)\ether.sbr"
	-@erase "$(INTDIR)\macos_util.obj"
	-@erase "$(INTDIR)\macos_util.sbr"
	-@erase "$(INTDIR)\main_windows.obj"
	-@erase "$(INTDIR)\main_windows.sbr"
	-@erase "$(INTDIR)\Ntcd.obj"
	-@erase "$(INTDIR)\Ntcd.sbr"
	-@erase "$(INTDIR)\prefs.obj"
	-@erase "$(INTDIR)\prefs.sbr"
	-@erase "$(INTDIR)\prefs_windows.obj"
	-@erase "$(INTDIR)\prefs_windows.sbr"
	-@erase "$(INTDIR)\rom_patches.obj"
	-@erase "$(INTDIR)\rom_patches.sbr"
	-@erase "$(INTDIR)\rsrc_patches.obj"
	-@erase "$(INTDIR)\rsrc_patches.sbr"
	-@erase "$(INTDIR)\scsi.obj"
	-@erase "$(INTDIR)\scsi.sbr"
	-@erase "$(INTDIR)\scsi_windows.obj"
	-@erase "$(INTDIR)\scsi_windows.sbr"
	-@erase "$(INTDIR)\serial.obj"
	-@erase "$(INTDIR)\serial.sbr"
	-@erase "$(INTDIR)\serial_windows.obj"
	-@erase "$(INTDIR)\serial_windows.sbr"
	-@erase "$(INTDIR)\slot_rom.obj"
	-@erase "$(INTDIR)\slot_rom.sbr"
	-@erase "$(INTDIR)\sony.obj"
	-@erase "$(INTDIR)\sony.sbr"
	-@erase "$(INTDIR)\sys_windows.obj"
	-@erase "$(INTDIR)\sys_windows.sbr"
	-@erase "$(INTDIR)\timer.obj"
	-@erase "$(INTDIR)\timer.sbr"
	-@erase "$(INTDIR)\timer_windows.obj"
	-@erase "$(INTDIR)\timer_windows.sbr"
	-@erase "$(INTDIR)\uae_cpudefs.obj"
	-@erase "$(INTDIR)\uae_cpudefs.sbr"
	-@erase "$(INTDIR)\uae_cpuemu.obj"
	-@erase "$(INTDIR)\uae_cpuemu.sbr"
	-@erase "$(INTDIR)\uae_cpustbl.obj"
	-@erase "$(INTDIR)\uae_cpustbl.sbr"
	-@erase "$(INTDIR)\uae_fpp.obj"
	-@erase "$(INTDIR)\uae_fpp.sbr"
	-@erase "$(INTDIR)\uae_memory.obj"
	-@erase "$(INTDIR)\uae_memory.sbr"
	-@erase "$(INTDIR)\uae_newcpu.obj"
	-@erase "$(INTDIR)\uae_newcpu.sbr"
	-@erase "$(INTDIR)\uae_readcpu.obj"
	-@erase "$(INTDIR)\uae_readcpu.sbr"
	-@erase "$(INTDIR)\user_strings.obj"
	-@erase "$(INTDIR)\user_strings.sbr"
	-@erase "$(INTDIR)\vc50.idb"
	-@erase "$(INTDIR)\video.obj"
	-@erase "$(INTDIR)\video.sbr"
	-@erase "$(INTDIR)\video_windows.obj"
	-@erase "$(INTDIR)\video_windows.sbr"
	-@erase "$(INTDIR)\xpram.obj"
	-@erase "$(INTDIR)\xpram.sbr"
	-@erase "$(INTDIR)\xpram_windows.obj"
	-@erase "$(INTDIR)\xpram_windows.sbr"
	-@erase "$(OUTDIR)\BasiliskII.bsc"
	-@erase "$(OUTDIR)\BasiliskII.exe"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP=cl.exe
CPP_PROJ=/nologo /G6 /Gz /Zp4 /MT /W3 /GX /O2 /Ob2 /I ".\include" /I\
 "..\include" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "NDEBUG" /D\
 "_WINDOWS" /D "_MBCS" /FR"$(INTDIR)\\" /Fp"$(INTDIR)\BasiliskII.pch" /YX\
 /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /c 
CPP_OBJS=.\Release/
CPP_SBRS=.\Release/

.c{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.c{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

MTL=midl.exe
MTL_PROJ=/nologo /D "NDEBUG" /mktyplib203 /win32 
RSC=rc.exe
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\BasiliskII.bsc" 
BSC32_SBRS= \
	"$(INTDIR)\adb.sbr" \
	"$(INTDIR)\Cache.sbr" \
	"$(INTDIR)\cdrom.sbr" \
	"$(INTDIR)\clip_windows.sbr" \
	"$(INTDIR)\disk.sbr" \
	"$(INTDIR)\Eject_nt.sbr" \
	"$(INTDIR)\emul_op.sbr" \
	"$(INTDIR)\ether.sbr" \
	"$(INTDIR)\macos_util.sbr" \
	"$(INTDIR)\main_windows.sbr" \
	"$(INTDIR)\Ntcd.sbr" \
	"$(INTDIR)\prefs.sbr" \
	"$(INTDIR)\prefs_windows.sbr" \
	"$(INTDIR)\rom_patches.sbr" \
	"$(INTDIR)\rsrc_patches.sbr" \
	"$(INTDIR)\scsi.sbr" \
	"$(INTDIR)\scsi_windows.sbr" \
	"$(INTDIR)\serial.sbr" \
	"$(INTDIR)\serial_windows.sbr" \
	"$(INTDIR)\slot_rom.sbr" \
	"$(INTDIR)\sony.sbr" \
	"$(INTDIR)\sys_windows.sbr" \
	"$(INTDIR)\timer.sbr" \
	"$(INTDIR)\timer_windows.sbr" \
	"$(INTDIR)\uae_cpudefs.sbr" \
	"$(INTDIR)\uae_cpuemu.sbr" \
	"$(INTDIR)\uae_cpustbl.sbr" \
	"$(INTDIR)\uae_fpp.sbr" \
	"$(INTDIR)\uae_memory.sbr" \
	"$(INTDIR)\uae_newcpu.sbr" \
	"$(INTDIR)\uae_readcpu.sbr" \
	"$(INTDIR)\user_strings.sbr" \
	"$(INTDIR)\video.sbr" \
	"$(INTDIR)\video_windows.sbr" \
	"$(INTDIR)\xpram.sbr" \
	"$(INTDIR)\xpram_windows.sbr"

"$(OUTDIR)\BasiliskII.bsc" : "$(OUTDIR)" $(BSC32_SBRS)
    $(BSC32) @<<
  $(BSC32_FLAGS) $(BSC32_SBRS)
<<

LINK32=link.exe
LINK32_FLAGS=kernel32.lib user32.lib gdi32.lib comdlg32.lib advapi32.lib\
 shell32.lib ws2_32.lib /nologo /subsystem:windows /incremental:no\
 /pdb:"$(OUTDIR)\BasiliskII.pdb" /machine:I386 /out:"$(OUTDIR)\BasiliskII.exe" 
LINK32_OBJS= \
	"$(INTDIR)\adb.obj" \
	"$(INTDIR)\Cache.obj" \
	"$(INTDIR)\cdrom.obj" \
	"$(INTDIR)\clip_windows.obj" \
	"$(INTDIR)\disk.obj" \
	"$(INTDIR)\Eject_nt.obj" \
	"$(INTDIR)\emul_op.obj" \
	"$(INTDIR)\ether.obj" \
	"$(INTDIR)\macos_util.obj" \
	"$(INTDIR)\main_windows.obj" \
	"$(INTDIR)\Ntcd.obj" \
	"$(INTDIR)\prefs.obj" \
	"$(INTDIR)\prefs_windows.obj" \
	"$(INTDIR)\rom_patches.obj" \
	"$(INTDIR)\rsrc_patches.obj" \
	"$(INTDIR)\scsi.obj" \
	"$(INTDIR)\scsi_windows.obj" \
	"$(INTDIR)\serial.obj" \
	"$(INTDIR)\serial_windows.obj" \
	"$(INTDIR)\slot_rom.obj" \
	"$(INTDIR)\sony.obj" \
	"$(INTDIR)\sys_windows.obj" \
	"$(INTDIR)\timer.obj" \
	"$(INTDIR)\timer_windows.obj" \
	"$(INTDIR)\uae_cpudefs.obj" \
	"$(INTDIR)\uae_cpuemu.obj" \
	"$(INTDIR)\uae_cpustbl.obj" \
	"$(INTDIR)\uae_fpp.obj" \
	"$(INTDIR)\uae_memory.obj" \
	"$(INTDIR)\uae_newcpu.obj" \
	"$(INTDIR)\uae_readcpu.obj" \
	"$(INTDIR)\user_strings.obj" \
	"$(INTDIR)\video.obj" \
	"$(INTDIR)\video_windows.obj" \
	"$(INTDIR)\xpram.obj" \
	"$(INTDIR)\xpram_windows.obj"

"$(OUTDIR)\BasiliskII.exe" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
    $(LINK32) @<<
  $(LINK32_FLAGS) $(LINK32_OBJS)
<<

!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

OUTDIR=.\Debug
INTDIR=.\Debug
# Begin Custom Macros
OutDir=.\Debug
# End Custom Macros

!IF "$(RECURSE)" == "0" 

ALL : "$(OUTDIR)\BasiliskII.exe" "$(OUTDIR)\BasiliskII.bsc"

!ELSE 

ALL : "$(OUTDIR)\BasiliskII.exe" "$(OUTDIR)\BasiliskII.bsc"

!ENDIF 

CLEAN :
	-@erase "$(INTDIR)\adb.obj"
	-@erase "$(INTDIR)\adb.sbr"
	-@erase "$(INTDIR)\Cache.obj"
	-@erase "$(INTDIR)\Cache.sbr"
	-@erase "$(INTDIR)\cdrom.obj"
	-@erase "$(INTDIR)\cdrom.sbr"
	-@erase "$(INTDIR)\clip_windows.obj"
	-@erase "$(INTDIR)\clip_windows.sbr"
	-@erase "$(INTDIR)\disk.obj"
	-@erase "$(INTDIR)\disk.sbr"
	-@erase "$(INTDIR)\Eject_nt.obj"
	-@erase "$(INTDIR)\Eject_nt.sbr"
	-@erase "$(INTDIR)\emul_op.obj"
	-@erase "$(INTDIR)\emul_op.sbr"
	-@erase "$(INTDIR)\ether.obj"
	-@erase "$(INTDIR)\ether.sbr"
	-@erase "$(INTDIR)\macos_util.obj"
	-@erase "$(INTDIR)\macos_util.sbr"
	-@erase "$(INTDIR)\main_windows.obj"
	-@erase "$(INTDIR)\main_windows.sbr"
	-@erase "$(INTDIR)\Ntcd.obj"
	-@erase "$(INTDIR)\Ntcd.sbr"
	-@erase "$(INTDIR)\prefs.obj"
	-@erase "$(INTDIR)\prefs.sbr"
	-@erase "$(INTDIR)\prefs_windows.obj"
	-@erase "$(INTDIR)\prefs_windows.sbr"
	-@erase "$(INTDIR)\rom_patches.obj"
	-@erase "$(INTDIR)\rom_patches.sbr"
	-@erase "$(INTDIR)\rsrc_patches.obj"
	-@erase "$(INTDIR)\rsrc_patches.sbr"
	-@erase "$(INTDIR)\scsi.obj"
	-@erase "$(INTDIR)\scsi.sbr"
	-@erase "$(INTDIR)\scsi_windows.obj"
	-@erase "$(INTDIR)\scsi_windows.sbr"
	-@erase "$(INTDIR)\serial.obj"
	-@erase "$(INTDIR)\serial.sbr"
	-@erase "$(INTDIR)\serial_windows.obj"
	-@erase "$(INTDIR)\serial_windows.sbr"
	-@erase "$(INTDIR)\slot_rom.obj"
	-@erase "$(INTDIR)\slot_rom.sbr"
	-@erase "$(INTDIR)\sony.obj"
	-@erase "$(INTDIR)\sony.sbr"
	-@erase "$(INTDIR)\sys_windows.obj"
	-@erase "$(INTDIR)\sys_windows.sbr"
	-@erase "$(INTDIR)\timer.obj"
	-@erase "$(INTDIR)\timer.sbr"
	-@erase "$(INTDIR)\timer_windows.obj"
	-@erase "$(INTDIR)\timer_windows.sbr"
	-@erase "$(INTDIR)\uae_cpudefs.obj"
	-@erase "$(INTDIR)\uae_cpudefs.sbr"
	-@erase "$(INTDIR)\uae_cpuemu.obj"
	-@erase "$(INTDIR)\uae_cpuemu.sbr"
	-@erase "$(INTDIR)\uae_cpustbl.obj"
	-@erase "$(INTDIR)\uae_cpustbl.sbr"
	-@erase "$(INTDIR)\uae_fpp.obj"
	-@erase "$(INTDIR)\uae_fpp.sbr"
	-@erase "$(INTDIR)\uae_memory.obj"
	-@erase "$(INTDIR)\uae_memory.sbr"
	-@erase "$(INTDIR)\uae_newcpu.obj"
	-@erase "$(INTDIR)\uae_newcpu.sbr"
	-@erase "$(INTDIR)\uae_readcpu.obj"
	-@erase "$(INTDIR)\uae_readcpu.sbr"
	-@erase "$(INTDIR)\user_strings.obj"
	-@erase "$(INTDIR)\user_strings.sbr"
	-@erase "$(INTDIR)\vc50.idb"
	-@erase "$(INTDIR)\vc50.pdb"
	-@erase "$(INTDIR)\video.obj"
	-@erase "$(INTDIR)\video.sbr"
	-@erase "$(INTDIR)\video_windows.obj"
	-@erase "$(INTDIR)\video_windows.sbr"
	-@erase "$(INTDIR)\xpram.obj"
	-@erase "$(INTDIR)\xpram.sbr"
	-@erase "$(INTDIR)\xpram_windows.obj"
	-@erase "$(INTDIR)\xpram_windows.sbr"
	-@erase "$(OUTDIR)\BasiliskII.bsc"
	-@erase "$(OUTDIR)\BasiliskII.exe"
	-@erase "$(OUTDIR)\BasiliskII.ilk"
	-@erase "$(OUTDIR)\BasiliskII.pdb"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP=cl.exe
CPP_PROJ=/nologo /G6 /Gz /Zp4 /MT /W3 /Gm /GX /Zi /Od /I ".\include" /I\
 "..\include" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "_DEBUG" /D\
 "_WINDOWS" /D "_MBCS" /FR"$(INTDIR)\\" /Fp"$(INTDIR)\BasiliskII.pch" /YX\
 /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /c 
CPP_OBJS=.\Debug/
CPP_SBRS=.\Debug/

.c{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.c{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

MTL=midl.exe
MTL_PROJ=/nologo /D "_DEBUG" /mktyplib203 /win32 
RSC=rc.exe
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\BasiliskII.bsc" 
BSC32_SBRS= \
	"$(INTDIR)\adb.sbr" \
	"$(INTDIR)\Cache.sbr" \
	"$(INTDIR)\cdrom.sbr" \
	"$(INTDIR)\clip_windows.sbr" \
	"$(INTDIR)\disk.sbr" \
	"$(INTDIR)\Eject_nt.sbr" \
	"$(INTDIR)\emul_op.sbr" \
	"$(INTDIR)\ether.sbr" \
	"$(INTDIR)\macos_util.sbr" \
	"$(INTDIR)\main_windows.sbr" \
	"$(INTDIR)\Ntcd.sbr" \
	"$(INTDIR)\prefs.sbr" \
	"$(INTDIR)\prefs_windows.sbr" \
	"$(INTDIR)\rom_patches.sbr" \
	"$(INTDIR)\rsrc_patches.sbr" \
	"$(INTDIR)\scsi.sbr" \
	"$(INTDIR)\scsi_windows.sbr" \
	"$(INTDIR)\serial.sbr" \
	"$(INTDIR)\serial_windows.sbr" \
	"$(INTDIR)\slot_rom.sbr" \
	"$(INTDIR)\sony.sbr" \
	"$(INTDIR)\sys_windows.sbr" \
	"$(INTDIR)\timer.sbr" \
	"$(INTDIR)\timer_windows.sbr" \
	"$(INTDIR)\uae_cpudefs.sbr" \
	"$(INTDIR)\uae_cpuemu.sbr" \
	"$(INTDIR)\uae_cpustbl.sbr" \
	"$(INTDIR)\uae_fpp.sbr" \
	"$(INTDIR)\uae_memory.sbr" \
	"$(INTDIR)\uae_newcpu.sbr" \
	"$(INTDIR)\uae_readcpu.sbr" \
	"$(INTDIR)\user_strings.sbr" \
	"$(INTDIR)\video.sbr" \
	"$(INTDIR)\video_windows.sbr" \
	"$(INTDIR)\xpram.sbr" \
	"$(INTDIR)\xpram_windows.sbr"

"$(OUTDIR)\BasiliskII.bsc" : "$(OUTDIR)" $(BSC32_SBRS)
    $(BSC32) @<<
  $(BSC32_FLAGS) $(BSC32_SBRS)
<<

LINK32=link.exe
LINK32_FLAGS=ws2_32.lib kernel32.lib user32.lib gdi32.lib comdlg32.lib\
 advapi32.lib shell32.lib /nologo /subsystem:windows /incremental:yes\
 /pdb:"$(OUTDIR)\BasiliskII.pdb" /debug /machine:I386\
 /out:"$(OUTDIR)\BasiliskII.exe" /pdbtype:sept 
LINK32_OBJS= \
	"$(INTDIR)\adb.obj" \
	"$(INTDIR)\Cache.obj" \
	"$(INTDIR)\cdrom.obj" \
	"$(INTDIR)\clip_windows.obj" \
	"$(INTDIR)\disk.obj" \
	"$(INTDIR)\Eject_nt.obj" \
	"$(INTDIR)\emul_op.obj" \
	"$(INTDIR)\ether.obj" \
	"$(INTDIR)\macos_util.obj" \
	"$(INTDIR)\main_windows.obj" \
	"$(INTDIR)\Ntcd.obj" \
	"$(INTDIR)\prefs.obj" \
	"$(INTDIR)\prefs_windows.obj" \
	"$(INTDIR)\rom_patches.obj" \
	"$(INTDIR)\rsrc_patches.obj" \
	"$(INTDIR)\scsi.obj" \
	"$(INTDIR)\scsi_windows.obj" \
	"$(INTDIR)\serial.obj" \
	"$(INTDIR)\serial_windows.obj" \
	"$(INTDIR)\slot_rom.obj" \
	"$(INTDIR)\sony.obj" \
	"$(INTDIR)\sys_windows.obj" \
	"$(INTDIR)\timer.obj" \
	"$(INTDIR)\timer_windows.obj" \
	"$(INTDIR)\uae_cpudefs.obj" \
	"$(INTDIR)\uae_cpuemu.obj" \
	"$(INTDIR)\uae_cpustbl.obj" \
	"$(INTDIR)\uae_fpp.obj" \
	"$(INTDIR)\uae_memory.obj" \
	"$(INTDIR)\uae_newcpu.obj" \
	"$(INTDIR)\uae_readcpu.obj" \
	"$(INTDIR)\user_strings.obj" \
	"$(INTDIR)\video.obj" \
	"$(INTDIR)\video_windows.obj" \
	"$(INTDIR)\xpram.obj" \
	"$(INTDIR)\xpram_windows.obj"

"$(OUTDIR)\BasiliskII.exe" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
    $(LINK32) @<<
  $(LINK32_FLAGS) $(LINK32_OBJS)
<<

!ENDIF 


!IF "$(CFG)" == "BasiliskII - Win32 Release" || "$(CFG)" ==\
 "BasiliskII - Win32 Debug"
SOURCE=..\adb.cpp
DEP_CPP_ADB_C=\
	"..\include\adb.h"\
	"..\include\debug.h"\
	"..\include\main.h"\
	"..\include\uae_memory.h"\
	"..\include\video.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\adb.obj"	"$(INTDIR)\adb.sbr" : $(SOURCE) $(DEP_CPP_ADB_C)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\cdrom.cpp
DEP_CPP_CDROM=\
	"..\include\cdrom.h"\
	"..\include\debug.h"\
	"..\include\macos_util.h"\
	"..\include\main.h"\
	"..\include\prefs.h"\
	"..\include\sys.h"\
	"..\include\uae_memory.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\cdrom.obj"	"$(INTDIR)\cdrom.sbr" : $(SOURCE) $(DEP_CPP_CDROM)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\disk.cpp
DEP_CPP_DISK_=\
	"..\include\debug.h"\
	"..\include\disk.h"\
	"..\include\macos_util.h"\
	"..\include\main.h"\
	"..\include\prefs.h"\
	"..\include\sys.h"\
	"..\include\uae_memory.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\disk.obj"	"$(INTDIR)\disk.sbr" : $(SOURCE) $(DEP_CPP_DISK_)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\emul_op.cpp
DEP_CPP_EMUL_=\
	"..\include\adb.h"\
	"..\include\cdrom.h"\
	"..\include\clip.h"\
	"..\include\debug.h"\
	"..\include\disk.h"\
	"..\include\emul_op.h"\
	"..\include\ether.h"\
	"..\include\main.h"\
	"..\include\rom_patches.h"\
	"..\include\rsrc_patches.h"\
	"..\include\scsi.h"\
	"..\include\serial.h"\
	"..\include\sony.h"\
	"..\include\timer.h"\
	"..\include\uae_memory.h"\
	"..\include\video.h"\
	"..\include\xpram.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\emul_op.obj"	"$(INTDIR)\emul_op.sbr" : $(SOURCE) $(DEP_CPP_EMUL_)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\ether.cpp
DEP_CPP_ETHER=\
	"..\include\debug.h"\
	"..\include\ether.h"\
	"..\include\macos_util.h"\
	"..\include\main.h"\
	"..\include\uae_memory.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\ether.obj"	"$(INTDIR)\ether.sbr" : $(SOURCE) $(DEP_CPP_ETHER)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\macos_util.cpp
DEP_CPP_MACOS=\
	"..\include\debug.h"\
	"..\include\macos_util.h"\
	"..\include\main.h"\
	"..\include\uae_memory.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\macos_util.obj"	"$(INTDIR)\macos_util.sbr" : $(SOURCE)\
 $(DEP_CPP_MACOS) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\prefs.cpp
DEP_CPP_PREFS=\
	"..\include\prefs.h"\
	"..\include\sys.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\prefs.obj"	"$(INTDIR)\prefs.sbr" : $(SOURCE) $(DEP_CPP_PREFS)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\rom_patches.cpp
DEP_CPP_ROM_P=\
	"..\include\cdrom.h"\
	"..\include\debug.h"\
	"..\include\disk.h"\
	"..\include\emul_op.h"\
	"..\include\macos_util.h"\
	"..\include\main.h"\
	"..\include\prefs.h"\
	"..\include\rom_patches.h"\
	"..\include\slot_rom.h"\
	"..\include\sony.h"\
	"..\include\uae_memory.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\rom_patches.obj"	"$(INTDIR)\rom_patches.sbr" : $(SOURCE)\
 $(DEP_CPP_ROM_P) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\rsrc_patches.cpp
DEP_CPP_RSRC_=\
	"..\include\debug.h"\
	"..\include\emul_op.h"\
	"..\include\main.h"\
	"..\include\rsrc_patches.h"\
	"..\include\uae_memory.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\rsrc_patches.obj"	"$(INTDIR)\rsrc_patches.sbr" : $(SOURCE)\
 $(DEP_CPP_RSRC_) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\scsi.cpp
DEP_CPP_SCSI_=\
	"..\include\debug.h"\
	"..\include\main.h"\
	"..\include\scsi.h"\
	"..\include\uae_memory.h"\
	"..\include\user_strings.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\scsi.obj"	"$(INTDIR)\scsi.sbr" : $(SOURCE) $(DEP_CPP_SCSI_)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\serial.cpp
DEP_CPP_SERIA=\
	"..\include\debug.h"\
	"..\include\macos_util.h"\
	"..\include\main.h"\
	"..\include\serial.h"\
	"..\include\serial_defs.h"\
	"..\include\uae_memory.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\serial.obj"	"$(INTDIR)\serial.sbr" : $(SOURCE) $(DEP_CPP_SERIA)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\slot_rom.cpp
DEP_CPP_SLOT_=\
	"..\include\emul_op.h"\
	"..\include\main.h"\
	"..\include\slot_rom.h"\
	"..\include\uae_memory.h"\
	"..\include\version.h"\
	"..\include\video.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\slot_rom.obj"	"$(INTDIR)\slot_rom.sbr" : $(SOURCE) $(DEP_CPP_SLOT_)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\sony.cpp
DEP_CPP_SONY_=\
	"..\include\debug.h"\
	"..\include\macos_util.h"\
	"..\include\main.h"\
	"..\include\prefs.h"\
	"..\include\rom_patches.h"\
	"..\include\sony.h"\
	"..\include\sys.h"\
	"..\include\uae_memory.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\sony.obj"	"$(INTDIR)\sony.sbr" : $(SOURCE) $(DEP_CPP_SONY_)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\timer.cpp
DEP_CPP_TIMER=\
	"..\include\debug.h"\
	"..\include\macos_util.h"\
	"..\include\main.h"\
	"..\include\timer.h"\
	"..\include\uae_memory.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\timer.obj"	"$(INTDIR)\timer.sbr" : $(SOURCE) $(DEP_CPP_TIMER)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\video.cpp
DEP_CPP_VIDEO=\
	"..\include\debug.h"\
	"..\include\macos_util.h"\
	"..\include\main.h"\
	"..\include\uae_memory.h"\
	"..\include\video.h"\
	"..\include\video_defs.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\video.obj"	"$(INTDIR)\video.sbr" : $(SOURCE) $(DEP_CPP_VIDEO)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\xpram.cpp
DEP_CPP_XPRAM=\
	"..\include\xpram.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\xpram.obj"	"$(INTDIR)\xpram.sbr" : $(SOURCE) $(DEP_CPP_XPRAM)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=.\cdenable\Cache.cpp
DEP_CPP_CACHE=\
	".\cdenable\Cache.h"\
	

"$(INTDIR)\Cache.obj"	"$(INTDIR)\Cache.sbr" : $(SOURCE) $(DEP_CPP_CACHE)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=.\cdenable\Eject_nt.cpp
DEP_CPP_EJECT=\
	".\cdenable\eject_nt.h"\
	

"$(INTDIR)\Eject_nt.obj"	"$(INTDIR)\Eject_nt.sbr" : $(SOURCE) $(DEP_CPP_EJECT)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=.\cdenable\Ntcd.cpp
DEP_CPP_NTCD_=\
	".\cdenable\cdenable.h"\
	".\cdenable\ntcd.h"\
	

"$(INTDIR)\Ntcd.obj"	"$(INTDIR)\Ntcd.sbr" : $(SOURCE) $(DEP_CPP_NTCD_)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=.\clip_windows.cpp

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

DEP_CPP_CLIP_=\
	"..\include\clip.h"\
	"..\include\debug.h"\
	".\main_windows.h"\
	".\sysdeps.h"\
	

"$(INTDIR)\clip_windows.obj"	"$(INTDIR)\clip_windows.sbr" : $(SOURCE)\
 $(DEP_CPP_CLIP_) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

DEP_CPP_CLIP_=\
	"..\include\clip.h"\
	"..\include\debug.h"\
	".\main_windows.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\clip_windows.obj"	"$(INTDIR)\clip_windows.sbr" : $(SOURCE)\
 $(DEP_CPP_CLIP_) "$(INTDIR)"


!ENDIF 

SOURCE=.\main_windows.cpp
DEP_CPP_MAIN_=\
	"..\include\adb.h"\
	"..\include\cdrom.h"\
	"..\include\clip.h"\
	"..\include\debug.h"\
	"..\include\disk.h"\
	"..\include\ether.h"\
	"..\include\main.h"\
	"..\include\prefs.h"\
	"..\include\rom_patches.h"\
	"..\include\scsi.h"\
	"..\include\serial.h"\
	"..\include\sony.h"\
	"..\include\sys.h"\
	"..\include\timer.h"\
	"..\include\uae_memory.h"\
	"..\include\uae_newcpu.h"\
	"..\include\uae_readcpu.h"\
	"..\include\user_strings.h"\
	"..\include\version.h"\
	"..\include\video.h"\
	"..\include\xpram.h"\
	".\main_windows.h"\
	".\sysdeps.h"\
	".\timer_windows.h"\
	".\video_windows.h"\
	".\xpram_windows.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\main_windows.obj"	"$(INTDIR)\main_windows.sbr" : $(SOURCE)\
 $(DEP_CPP_MAIN_) "$(INTDIR)"


SOURCE=.\prefs_windows.cpp
DEP_CPP_PREFS_=\
	"..\include\prefs.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\prefs_windows.obj"	"$(INTDIR)\prefs_windows.sbr" : $(SOURCE)\
 $(DEP_CPP_PREFS_) "$(INTDIR)"


SOURCE=.\scsi_windows.cpp
DEP_CPP_SCSI_W=\
	"..\include\debug.h"\
	"..\include\main.h"\
	"..\include\prefs.h"\
	"..\include\scsi.h"\
	"..\include\uae_memory.h"\
	"..\include\user_strings.h"\
	".\main_windows.h"\
	".\scsidefs.h"\
	".\sysdeps.h"\
	".\wnaspi32.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\scsi_windows.obj"	"$(INTDIR)\scsi_windows.sbr" : $(SOURCE)\
 $(DEP_CPP_SCSI_W) "$(INTDIR)"


SOURCE=.\serial_windows.cpp
DEP_CPP_SERIAL=\
	"..\include\debug.h"\
	"..\include\macos_util.h"\
	"..\include\main.h"\
	"..\include\prefs.h"\
	"..\include\serial.h"\
	"..\include\serial_defs.h"\
	"..\include\uae_memory.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\serial_windows.obj"	"$(INTDIR)\serial_windows.sbr" : $(SOURCE)\
 $(DEP_CPP_SERIAL) "$(INTDIR)"


SOURCE=.\sys_windows.cpp
DEP_CPP_SYS_W=\
	"..\include\debug.h"\
	"..\include\main.h"\
	"..\include\prefs.h"\
	"..\include\sys.h"\
	"..\include\uae_memory.h"\
	"..\include\user_strings.h"\
	".\cdenable\Cache.h"\
	".\cdenable\eject_nt.h"\
	".\cdenable\ntcd.h"\
	".\main_windows.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\sys_windows.obj"	"$(INTDIR)\sys_windows.sbr" : $(SOURCE)\
 $(DEP_CPP_SYS_W) "$(INTDIR)"


SOURCE=.\timer_windows.cpp
DEP_CPP_TIMER_=\
	"..\include\debug.h"\
	"..\include\timer.h"\
	".\sysdeps.h"\
	".\timer_windows.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

CPP_SWITCHES=/nologo /G6 /Gz /Zp4 /MT /W3 /GX /O2 /Ob2 /I ".\include" /I\
 "..\include" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "NDEBUG" /D\
 "_WINDOWS" /D "_MBCS" /FAs /Fa"$(INTDIR)\\" /FR"$(INTDIR)\\"\
 /Fp"$(INTDIR)\BasiliskII.pch" /YX /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /c 

"$(INTDIR)\timer_windows.obj"	"$(INTDIR)\timer_windows.sbr" : $(SOURCE)\
 $(DEP_CPP_TIMER_) "$(INTDIR)"
	$(CPP) @<<
  $(CPP_SWITCHES) $(SOURCE)
<<


!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

CPP_SWITCHES=/nologo /G6 /Gz /Zp4 /MT /W3 /Gm /GX /Zi /Od /I ".\include" /I\
 "..\include" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "_DEBUG" /D\
 "_WINDOWS" /D "_MBCS" /FR"$(INTDIR)\\" /Fp"$(INTDIR)\BasiliskII.pch" /YX\
 /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /c 

"$(INTDIR)\timer_windows.obj"	"$(INTDIR)\timer_windows.sbr" : $(SOURCE)\
 $(DEP_CPP_TIMER_) "$(INTDIR)"
	$(CPP) @<<
  $(CPP_SWITCHES) $(SOURCE)
<<


!ENDIF 

SOURCE=.\video_windows.cpp
DEP_CPP_VIDEO_=\
	"..\include\adb.h"\
	"..\include\debug.h"\
	"..\include\main.h"\
	"..\include\prefs.h"\
	"..\include\uae_memory.h"\
	"..\include\user_strings.h"\
	"..\include\video.h"\
	".\main_windows.h"\
	".\sysdeps.h"\
	".\video_windows.h"\
	{$(INCLUDE)}"sys\timeb.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\video_windows.obj"	"$(INTDIR)\video_windows.sbr" : $(SOURCE)\
 $(DEP_CPP_VIDEO_) "$(INTDIR)"


SOURCE=.\xpram_windows.cpp
DEP_CPP_XPRAM_=\
	"..\include\xpram.h"\
	".\sysdeps.h"\
	".\xpram_windows.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\xpram_windows.obj"	"$(INTDIR)\xpram_windows.sbr" : $(SOURCE)\
 $(DEP_CPP_XPRAM_) "$(INTDIR)"


SOURCE=..\uae_cpudefs.cpp
DEP_CPP_UAE_C=\
	"..\include\uae_readcpu.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\uae_cpudefs.obj"	"$(INTDIR)\uae_cpudefs.sbr" : $(SOURCE)\
 $(DEP_CPP_UAE_C) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\uae_cpuemu.cpp
DEP_CPP_UAE_CP=\
	"..\include\uae_compiler.h"\
	"..\include\uae_cputbl.h"\
	"..\include\uae_m68k.h"\
	"..\include\uae_memory.h"\
	"..\include\uae_newcpu.h"\
	"..\include\uae_readcpu.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\uae_cpuemu.obj"	"$(INTDIR)\uae_cpuemu.sbr" : $(SOURCE)\
 $(DEP_CPP_UAE_CP) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\uae_cpustbl.cpp
DEP_CPP_UAE_CPU=\
	"..\include\uae_compiler.h"\
	"..\include\uae_cputbl.h"\
	"..\include\uae_m68k.h"\
	"..\include\uae_memory.h"\
	"..\include\uae_newcpu.h"\
	"..\include\uae_readcpu.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\uae_cpustbl.obj"	"$(INTDIR)\uae_cpustbl.sbr" : $(SOURCE)\
 $(DEP_CPP_UAE_CPU) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\uae_fpp.cpp
DEP_CPP_UAE_F=\
	"..\include\uae_memory.h"\
	"..\include\uae_newcpu.h"\
	"..\include\uae_readcpu.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\uae_fpp.obj"	"$(INTDIR)\uae_fpp.sbr" : $(SOURCE) $(DEP_CPP_UAE_F)\
 "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\uae_memory.cpp
DEP_CPP_UAE_M=\
	"..\include\main.h"\
	"..\include\uae_m68k.h"\
	"..\include\uae_memory.h"\
	"..\include\uae_newcpu.h"\
	"..\include\uae_readcpu.h"\
	"..\include\video.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

CPP_SWITCHES=/nologo /G6 /Gz /Zp4 /MT /W3 /GX /O2 /Ob2 /I ".\include" /I\
 "..\include" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "NDEBUG" /D\
 "_WINDOWS" /D "_MBCS" /FAs /Fa"$(INTDIR)\\" /FR"$(INTDIR)\\"\
 /Fp"$(INTDIR)\BasiliskII.pch" /YX /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /c 

"$(INTDIR)\uae_memory.obj"	"$(INTDIR)\uae_memory.sbr" : $(SOURCE)\
 $(DEP_CPP_UAE_M) "$(INTDIR)"
	$(CPP) @<<
  $(CPP_SWITCHES) $(SOURCE)
<<


!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

CPP_SWITCHES=/nologo /G6 /Gz /Zp4 /MT /W3 /Gm /GX /Zi /Od /I ".\include" /I\
 "..\include" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "_DEBUG" /D\
 "_WINDOWS" /D "_MBCS" /FR"$(INTDIR)\\" /Fp"$(INTDIR)\BasiliskII.pch" /YX\
 /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /c 

"$(INTDIR)\uae_memory.obj"	"$(INTDIR)\uae_memory.sbr" : $(SOURCE)\
 $(DEP_CPP_UAE_M) "$(INTDIR)"
	$(CPP) @<<
  $(CPP_SWITCHES) $(SOURCE)
<<


!ENDIF 

SOURCE=..\uae_newcpu.cpp
DEP_CPP_UAE_N=\
	"..\include\emul_op.h"\
	"..\include\main.h"\
	"..\include\uae_compiler.h"\
	"..\include\uae_m68k.h"\
	"..\include\uae_memory.h"\
	"..\include\uae_newcpu.h"\
	"..\include\uae_readcpu.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

!IF  "$(CFG)" == "BasiliskII - Win32 Release"

CPP_SWITCHES=/nologo /G6 /Gz /Zp4 /MT /W3 /GX /O2 /Ob2 /I ".\include" /I\
 "..\include" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "NDEBUG" /D\
 "_WINDOWS" /D "_MBCS" /FAs /Fa"$(INTDIR)\\" /FR"$(INTDIR)\\"\
 /Fp"$(INTDIR)\BasiliskII.pch" /YX /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /c 

"$(INTDIR)\uae_newcpu.obj"	"$(INTDIR)\uae_newcpu.sbr" : $(SOURCE)\
 $(DEP_CPP_UAE_N) "$(INTDIR)"
	$(CPP) @<<
  $(CPP_SWITCHES) $(SOURCE)
<<


!ELSEIF  "$(CFG)" == "BasiliskII - Win32 Debug"

CPP_SWITCHES=/nologo /G6 /Gz /Zp4 /MT /W3 /Gm /GX /Zi /Od /I ".\include" /I\
 "..\include" /I ".\Windows" /I "..\Windows" /D "WIN32" /D "_DEBUG" /D\
 "_WINDOWS" /D "_MBCS" /FR"$(INTDIR)\\" /Fp"$(INTDIR)\BasiliskII.pch" /YX\
 /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /c 

"$(INTDIR)\uae_newcpu.obj"	"$(INTDIR)\uae_newcpu.sbr" : $(SOURCE)\
 $(DEP_CPP_UAE_N) "$(INTDIR)"
	$(CPP) @<<
  $(CPP_SWITCHES) $(SOURCE)
<<


!ENDIF 

SOURCE=..\uae_readcpu.cpp
DEP_CPP_UAE_R=\
	"..\include\uae_readcpu.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\uae_readcpu.obj"	"$(INTDIR)\uae_readcpu.sbr" : $(SOURCE)\
 $(DEP_CPP_UAE_R) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\user_strings.cpp
DEP_CPP_USER_=\
	"..\include\user_strings.h"\
	".\sysdeps.h"\
	{$(INCLUDE)}"sys\types.h"\
	

"$(INTDIR)\user_strings.obj"	"$(INTDIR)\user_strings.sbr" : $(SOURCE)\
 $(DEP_CPP_USER_) "$(INTDIR)"
	$(CPP) $(CPP_PROJ) $(SOURCE)


SOURCE=..\AmigaOS\clip_amiga.cpp
SOURCE=..\AmigaOS\main_amiga.cpp
SOURCE=..\AmigaOS\prefs_amiga.cpp
SOURCE=..\AmigaOS\scsi_amiga.cpp
SOURCE=..\AmigaOS\serial_amiga.cpp
SOURCE=..\AmigaOS\sys_amiga.cpp
SOURCE=..\AmigaOS\timer_amiga.cpp
SOURCE=..\AmigaOS\video_amiga.cpp
SOURCE=..\AmigaOS\xpram_amiga.cpp
SOURCE=..\BeOS\clip_beos.cpp
SOURCE=..\BeOS\main_beos.cpp
SOURCE=..\BeOS\prefs_beos.cpp
SOURCE=..\BeOS\scsi_beos.cpp
SOURCE=..\BeOS\serial_beos.cpp
SOURCE=..\BeOS\sys_beos.cpp
SOURCE=..\BeOS\timer_beos.cpp
SOURCE=..\BeOS\video_beos.cpp
SOURCE=..\BeOS\xpram_beos.cpp
SOURCE=..\Unix\clip_unix.cpp
SOURCE=..\Unix\main_unix.cpp
SOURCE=..\Unix\prefs_unix.cpp
SOURCE=..\Unix\scsi_unix.cpp
SOURCE=..\Unix\serial_unix.cpp
SOURCE=..\Unix\sys_unix.cpp
SOURCE=..\Unix\timer_unix.cpp
SOURCE=..\Unix\video_x.cpp
SOURCE=..\Unix\xpram_unix.cpp

!ENDIF 

