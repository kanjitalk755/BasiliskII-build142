/*
 *  sys_windows.cpp - System dependent routines for Win32
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

#include <windows.h>

__declspec(dllexport)
BOOL WINAPI GETCDSECTORS (BYTE   bDrive,
                        	DWORD  dwStartSector,
                        	WORD   wSectors,
                        	LPBYTE lpBuff);

__declspec(dllexport)
BOOL WINAPI GETFLOPPYSECTORS (BYTE   bDrive,
                        			DWORD  dwStartSector,
                        			WORD   wSectors,
                        			LPBYTE lpBuff);

__declspec(dllexport)
BOOL WINAPI PUTFLOPPYSECTORS (BYTE   bDrive,
                        			DWORD  dwStartSector,
                        			WORD   wSectors,
                        			LPBYTE lpBuff);

BOOL FAR PASCAL ReadCDSectors(BYTE   bDrive,
                              DWORD  dwStartSector,
                              WORD   wSectors,
                              LPBYTE lpBuffer);

BOOL FAR PASCAL ReadFloppySectors(BYTE   bDrive,
                                  DWORD  dwStartSector,
                                  WORD   wSectors,
                                  LPBYTE lpBuffer);

BOOL FAR PASCAL WriteFloppySectors(BYTE   bDrive,
                                   DWORD  dwStartSector,
                                   WORD   wSectors,
                                   LPBYTE lpBuffer);

BOOL WINAPI thk_ThunkConnect32(LPSTR     lpDll16,
                               LPSTR     lpDll32,
                               HINSTANCE hDllInst,
                               DWORD     dwReason);

BOOL WINAPI DllMain(HINSTANCE hDLLInst,
                    DWORD     dwReason,
                    LPVOID    lpvReserved)
{
	if (!thk_ThunkConnect32("B2WIN16.DLL", "B2WIN32.DLL",
                           hDLLInst, dwReason))
   {
      return FALSE;
   }
   switch (dwReason)
   {
      case DLL_PROCESS_ATTACH:
         break;

      case DLL_PROCESS_DETACH:
         break;

      case DLL_THREAD_ATTACH:
         break;

      case DLL_THREAD_DETACH:
         break;
   }
   return TRUE;
}

__declspec(dllexport)
BOOL WINAPI GETCDSECTORS (BYTE   bDrive,
                        	DWORD  dwStartSector,
                        	WORD   wSectors,
                        	LPBYTE lpBuff)
{
   return ReadCDSectors (bDrive, dwStartSector, wSectors, lpBuff);
}

__declspec(dllexport)
BOOL WINAPI GETFLOPPYSECTORS (BYTE   bDrive,
                        			DWORD  dwStartSector,
                        			WORD   wSectors,
                        			LPBYTE lpBuff)
{
   return ReadFloppySectors (bDrive, dwStartSector, wSectors, lpBuff);
}

__declspec(dllexport)
BOOL WINAPI PUTFLOPPYSECTORS (BYTE   bDrive,
                        			DWORD  dwStartSector,
                        			WORD   wSectors,
                        			LPBYTE lpBuff)
{
   return WriteFloppySectors (bDrive, dwStartSector, wSectors, lpBuff);
}
