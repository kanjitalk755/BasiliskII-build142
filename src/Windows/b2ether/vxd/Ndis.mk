##################################################################
#
#  ndis.mk -- derived from the ddk packet sample
#
#  Basilisk II (C) 1997-1999 Christian Bauer
#
#  Ported to Windows by Lauri Pesonen
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
##################################################################
#
#       INPUT:
#               BIN: Where to put the stuff
#               DEB: Flags to control debug level
#
##################################################################


DDKROOT         =       D:\DDK\95
SDKROOT         =				D:\MSSDK\win16
PLATSDKROOT     =				D:\mssdk
MASMDIR					=				$(DDKROOT)\MASM611C

DEBLEVEL = 0
!UNDEF BIN

INCLUDE = $(PLATSDKROOT)\include;$(DDKROOT)\INC32;$(DDKROOT)\NET\INC;$(DDKROOT)\INC16

NDIS_STDCALL=1

!IFNDEF DEBLEVEL
DEBLEVEL=1
!ENDIF

DDEB            =       -DDEBUG -DDBG=1 -DDEBLEVEL=$(DEBLEVEL) -DCHICAGO -Zi
RDEB            =       -DDEBLEVEL=0 -DCHICAGO

!IFNDEF BIN
BIN             =       retail
DEB             =       $(RDEB)
LDEB            =       NONE
!ELSE
DEB             =       $(DDEB)
LDEB            =       FULL
!ENDIF


WIN32           =       $(DDKROOT)
NETROOT         =       $(DDKROOT)\net
NDISROOT        =       $(NETROOT)\ndis3
LIBDIR          =       $(NDISROOT)\lib
INCLUDE         =       $(INCLUDE);.;..\inc

DDKTOOLS        =       $(WIN32)\bin

i386                             =                      TRUE
VXD                              =                      TRUE
ASM             =       $(MASMDIR)\ml.exe
CL              =       cl.exe -bzalign
CHGNAM          =       chgnam.exe
CHGNAMSRC       =       $(DDKTOOLS)\chgnam.vxd
INCLUDES        =       $(NETROOT)\bin\includes.exe
MAPSYM          =       mapsym

LIBNDIS         =       $(LIBDIR)\$(BIN)\libndis.clb
LINK            =       link.exe
LIBWRAPS        =       $(DDKROOT)\lib\vxdwraps.clb


LFLAGS  =   /m /NOD /MA /LI /NOLOGO /NOI 

CFLAGS  = -Zp -Gs -c -DIS_32 -Zl
AFLAGS  = -DIS_32 -W2 -Cx -DMASM6 -DVMMSYS -Zm -DSEGNUM=3

#AFLAGS  = $(AFLAGS) -DNDIS_WIN -c -coff -DBLD_COFF
AFLAGS  = $(AFLAGS) -c -coff -DBLD_COFF -DDEVICE=$(DEVICE)

!ifdef NDIS_STDCALL
CFLAGS = $(CFLAGS) -Gz -DNDIS_STDCALL
AFLAGS = $(AFLAGS) -DNDIS_STDCALL
!endif

.asm{$(BIN)}.obj:
		set INCLUDE=$(INCLUDE)
		set ML= $(AFLAGS) $(DEB)
		$(ASM) -Fo$*.obj $<

.asm{$(BIN)}.lst:
		set INCLUDE=$(INCLUDE)
		set ML= $(AFLAGS) $(DEB)
		$(ASM) -Fl$*.obj $<

.c{$(BIN)}.obj:
		set INCLUDE=$(INCLUDE)
		set CL= $(CFLAGS) $(DEB)
		$(CL) -Fo$*.obj $<

target: $(BIN) $(BIN)\$(DEVICE).VXD $(BIN)\$(DEVICE).RES

$(BIN):
	if not exist $(BIN)\nul md $(BIN)

dbg:    depend
		$(MAKE) BIN=debug DEB="$(DDEB)"

rtl:    depend
		$(MAKE) BIN=retail DEB="$(RDEB)"

all: rtl dbg

!if EXIST (depend.mk)
!include depend.mk
!endif

VERSION =   4.0

!ifdef OMB

$(BIN)\$(DEVICE).VXD: $(OBJS) $(DEVICE).def $(LIBNDIS)
				$(LINK) @<<
$(OBJS: =+^
)
$(BIN)\$(DEVICE).VXD $(LFLAGS)
$(BIN)\$(DEVICE).map
$(LIBNDIS)
$(DEVICE).def
<<

!else

$(BIN)\$(DEVICE).VXD: $(OBJS) $(DEVICE).def $(LIBNDIS) $(LIBWRAPS)
		$(LINK) @<<
-MACHINE:i386
-DEBUG:$(LDEB)
-DEBUGTYPE:MAP,COFF
-PDB:NONE
-DEF:$(DEVICE).def
-OUT:$(BIN)\$(DEVICE).VXD
-MAP:$(BIN)\$(DEVICE).map
-VXD
$(LIBNDIS)
$(LIBWRAPS)
$(OBJS: =^
)


<<
!endif
		cd      $(BIN)
		$(MAPSYM) $(DEVICE)

		cd      ..


$(BIN)\$(DEVICE).RES:
      $(SDKROOT)\binw16\rc -r -i$(DDKROOT)\inc16 $(DEVICE).RC

		move     $(DEVICE).RES $(BIN)
		cd      $(BIN)
      
      $(DDKROOT)\bin\adrc2vxd $(DEVICE).vxd $(DEVICE).res

		cd      ..
		
		bscmake @sbrList.txt


depend:
#        -mkdir debug
#        -mkdir retail
		set INCLUDE=$(INCLUDE)
		$(INCLUDES) -i -L$$(BIN) -S$$(BIN) *.asm *.c > depend.mk
		$(INCLUDES) -i -L$$(BIN) -S$$(BIN) $(NDISSRC)\ndisdev.asm >> depend.mk


clean :
		- del debug\*.obj
		- del debug\*.sym
      - del debug\*.VXD
		- del debug\*.map
		- del debug\*.lst
		- del retail\*.obj
		- del retail\*.sym
      - del retail\*.VXD
		- del retail\*.map
		- del retail\*.lst
		- del depend.mk


