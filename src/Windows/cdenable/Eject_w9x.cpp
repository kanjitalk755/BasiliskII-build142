/*
 *  eject_w9x.cpp - cd eject routines for Win9x
 *
 *  Basilisk II (C) 1997-1999 Christian Bauer
 *
 *  Windows platform specific code copyright (C) Lauri Pesonen
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "sysdeps.h"

#include "windows.h"
#include <winioctl.h>

// Prototypes

extern "C" {

#include "eject_w9x.h"

#if !defined (VWIN32_DIOC_DOS_IOCTL)
#define VWIN32_DIOC_DOS_IOCTL      1

typedef struct _DIOC_REGISTERS {
    DWORD reg_EBX;
    DWORD reg_EDX;
    DWORD reg_ECX;
    DWORD reg_EAX;
    DWORD reg_EDI;
    DWORD reg_ESI;
    DWORD reg_Flags;
} DIOC_REGISTERS, *PDIOC_REGISTERS;
#endif

#define CARRY_FLAG             0x0001

HANDLE OpenVWin32(void)
{
	return(CreateFile(
		"\\\\.\\vwin32",
		GENERIC_READ|GENERIC_WRITE,
		0,
		NULL,
		CREATE_NEW,
		FILE_FLAG_DELETE_ON_CLOSE,
		NULL )
	);
}

BOOL EjectMedia_w9x( int bDrive )
{
	DIOC_REGISTERS regs = {0};
	BOOL  fResult;
	DWORD cb;
	HANDLE h;

	h = OpenVWin32();

	if(h != 0 && h != INVALID_HANDLE_VALUE) {
		regs.reg_EAX = 0x440D;
		regs.reg_EBX = bDrive;
		regs.reg_ECX = MAKEWORD(0x49, 0x08);
		fResult = DeviceIoControl (h, VWIN32_DIOC_DOS_IOCTL,
															&regs, sizeof(regs), &regs, sizeof(regs),
															&cb, 0);
		fResult = fResult && !(regs.reg_Flags & CARRY_FLAG);
		CloseHandle(h);
	}
	return(fResult);
}

} // extern "C"
