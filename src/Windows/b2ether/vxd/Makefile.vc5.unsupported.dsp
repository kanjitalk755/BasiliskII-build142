# Microsoft Developer Studio Project File - Name="Makefile" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 5.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) External Target" 0x0106

CFG=Makefile - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "Makefile.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "Makefile.mak" CFG="Makefile - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "Makefile - Win32 Release" (based on "Win32 (x86) External Target")
!MESSAGE "Makefile - Win32 Debug" (based on "Win32 (x86) External Target")
!MESSAGE 

# Begin Project
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""

!IF  "$(CFG)" == "Makefile - Win32 Release"

# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Cmd_Line "NMAKE /f Makefile"
# PROP BASE Rebuild_Opt "/a"
# PROP BASE Target_File "Makefile.exe"
# PROP BASE Bsc_Name "Makefile.bsc"
# PROP BASE Target_Dir ""
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Release"
# PROP Intermediate_Dir "Release"
# PROP Cmd_Line "NMAKE /f Makefile"
# PROP Rebuild_Opt "/a"
# PROP Target_File "Makefile.exe"
# PROP Bsc_Name "Makefile.bsc"
# PROP Target_Dir ""

!ELSEIF  "$(CFG)" == "Makefile - Win32 Debug"

# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Cmd_Line "NMAKE /f Makefile"
# PROP BASE Rebuild_Opt "/a"
# PROP BASE Target_File "Makefile.exe"
# PROP BASE Bsc_Name "Makefile.bsc"
# PROP BASE Target_Dir ""
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "Debug"
# PROP Intermediate_Dir "Debug"
# PROP Cmd_Line "NMAKE /f Makefile"
# PROP Rebuild_Opt "/a"
# PROP Target_File "Makefile.exe"
# PROP Bsc_Name "Makefile.bsc"
# PROP Target_Dir ""

!ENDIF 

# Begin Target

# Name "Makefile - Win32 Release"
# Name "Makefile - Win32 Debug"

!IF  "$(CFG)" == "Makefile - Win32 Release"

!ELSEIF  "$(CFG)" == "Makefile - Win32 Debug"

!ENDIF 

# Begin Source File

SOURCE=.\debug.h
# End Source File
# Begin Source File

SOURCE=.\lock.c
# End Source File
# Begin Source File

SOURCE=.\B2ETHER.def
# End Source File
# Begin Source File

SOURCE=.\ndisdev.asm
# End Source File
# Begin Source File

SOURCE=.\ndispkt.c
# End Source File
# Begin Source File

SOURCE=.\MACRO.INC
# End Source File
# Begin Source File

SOURCE=.\Makefile
# End Source File
# Begin Source File

SOURCE=.\NDIS.MK
# End Source File
# Begin Source File

SOURCE=.\openclose.c
# End Source File
# Begin Source File

SOURCE=.\packet.c
# End Source File
# Begin Source File

SOURCE=.\packet.h
# End Source File
# Begin Source File

SOURCE=.\b2ether.rc
# End Source File
# Begin Source File

SOURCE=.\read.c
# End Source File
# Begin Source File

SOURCE=.\request.c
# End Source File
# Begin Source File

SOURCE=.\write.c
# End Source File
# End Target
# End Project
