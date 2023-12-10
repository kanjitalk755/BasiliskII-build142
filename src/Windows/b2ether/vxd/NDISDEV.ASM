.LALL
;
;  b2ether driver -- derived from DDK packet driver sample
;
;  Basilisk II (C) 1997-1999 Christian Bauer
;
;  Ported to Windows by Lauri Pesonen
;
;  This program is free software; you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation; either version 2 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program; if not, write to the Free Software
;  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;

    TITLE $B2ETHER
    .386P


INCLUDE VMM.INC
INCLUDE NDIS.INC
INCLUDE NETVXD.INC          ; Net VxD initialization oredr


; the following equate makes the VXD dynamically loadable.
%DEVICE_DYNAMIC EQU 1


DECLARE_VIRTUAL_DEVICE %DEVICE, 3, 10, <%DEVICE>_Control, Undefined_Device_Id, PROTOCOL_Init_Order

VxD_LOCKED_DATA_SEG

Public bInitAlready	
	bInitAlready	 DB 0
	
VxD_LOCKED_DATA_ENDS

VxD_LOCKED_CODE_SEG


BeginProc C_Device_Init


IFDEF NDIS_STDCALL
	extern _DriverEntry@8:NEAR
ELSE
	extern _DriverEntry:NEAR
ENDIF

	mov  		al, bInitAlready
	cmp  		al, 0					; Make sure we' haven't been called already.
	jnz  		Succeed_Init_Phase
	inc  		bInitAlready			; Set the "Called Already" Flag

; Make sure the wrapper (Ndis.386) is loaded
   VxDcall	NdisGetVersion
   jc   		Fail_Init_Phase

   push 		0
   push 		0

IFDEF NDIS_STDCALL
   call 		_DriverEntry@8
ELSE
   call 		_DriverEntry
   add  		esp,8
ENDIF

   cmp  		eax, NDIS_STATUS_SUCCESS
   jne  		Fail_Init_Phase

Succeed_Init_Phase:
   clc
   ret

Fail_Init_Phase:
   stc
   ret

EndProc C_Device_Init


Begin_Control_Dispatch %DEVICE

    Control_Dispatch Sys_Dynamic_Device_Init,	C_Device_Init
    Control_Dispatch W32_DEVICEIOCONTROL,    	PacketIOControl, sCall, <ecx, ebx, edx, esi>

IFDEF DEBUG
    Control_Dispatch DEBUG_QUERY,					PacketDebugQuery, sCall
ENDIF

End_Control_Dispatch %DEVICE


VxD_LOCKED_CODE_ENDS


	END
