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
#include <string.h>
#include <ctype.h>

#define FLOPPY_SECTOR_SIZE     512
#define CD_SECTOR_SIZE     		 2048
#define MAX_BUFFER_LENGTH      65536
#define MAX_SECTORS_TO_READ 		(MAX_BUFFER_LENGTH / FLOPPY_SECTOR_SIZE)
#define MAX_CD_SECTORS_TO_READ 	(MAX_BUFFER_LENGTH / CD_SECTOR_SIZE)

#define CARRY_FLAG 1
typedef struct tagRMCS {
   DWORD edi, esi, ebp, RESERVED, ebx, edx, ecx, eax;
   WORD  wFlags, es, ds, fs, gs, ip, cs, sp, ss;
} RMCS, FAR* LPRMCS;

void db( char *s )
{
#ifdef _DEBUG
	OutputDebugString( s );
	OutputDebugString( "\r\n" );
#endif
}

BOOL FAR PASCAL __export ReadCDSectors(BYTE   bDrive,
                                       DWORD  dwStartSector,
                                       WORD   wSectors,
                                       LPBYTE lpBuffer);

BOOL FAR PASCAL __export ReadFloppySectors(BYTE   bDrive,
                                           DWORD  dwStartSector,
                                           WORD   wSectors,
                                           LPBYTE lpBuffer);

BOOL FAR PASCAL __export WriteFloppySectors(BYTE   bDrive,
                                            DWORD  dwStartSector,
                                            WORD   wSectors,
                                            LPBYTE lpBuffer);

BOOL FAR PASCAL CD_ReadSectors(BYTE   bDrive,
                               DWORD  dwStartSector,
                               DWORD  dwCount,
                               LPBYTE RMlpBuffer);

BOOL FAR PASCAL Floppy_ReadSectors(BYTE   bDrive,
                                   DWORD  dwStartSector,
                                   DWORD  dwCount,
                                   LPBYTE RMlpBuffer);

BOOL FAR PASCAL Floppy_WriteSectors(BYTE   bDrive,
                                   DWORD  dwStartSector,
                                   DWORD  dwCount,
                                   LPBYTE RMlpBuffer);

BOOL FAR PASCAL SimulateRM_Int (BYTE bIntNum, LPRMCS lpCallStruct);

void FAR PASCAL BuildRMCS (LPRMCS lpCallStruct);


BOOL FAR PASCAL __export ReadCDSectors(
	BYTE   bDrive,
	DWORD  dwStartSector,
	WORD   wSectors,
	LPBYTE lpBuffer
)
{
  char buf[100];
	BOOL   fResult;
	DWORD  cbOffset;
	DWORD  i;
	DWORD  gdaBuffer = 0;
	LPBYTE RMlpBuffer;
	LPBYTE PMlpBuffer;
	WORD  sc_count, sectors_left;

  wsprintf( buf, "ReadCDSectors: %c, %ld, %d", (char)bDrive, (long)dwStartSector, (int)wSectors );
  db( buf );

  bDrive = toupper(bDrive) - 'A';

	if (bDrive > 25 || !lpBuffer) return FALSE;

	if (!wSectors || (wSectors > MAX_CD_SECTORS_TO_READ)) return FALSE;

	sc_count = wSectors;
	while(!gdaBuffer) {
		gdaBuffer = GlobalDosAlloc( CD_SECTOR_SIZE*sc_count );
		if(!gdaBuffer) {
			sc_count >>= 1;
			if(!sc_count) return FALSE;
		}
	}

	RMlpBuffer = (LPBYTE)MAKELONG(0, HIWORD(gdaBuffer));
	PMlpBuffer = (LPBYTE)MAKELONG(0, LOWORD(gdaBuffer));

	sectors_left = wSectors;
	for ( i = cbOffset = 0;
			 i < wSectors;
			 i += sc_count, cbOffset += CD_SECTOR_SIZE*sc_count, sectors_left -= sc_count )
	{
		if(sc_count > sectors_left) sc_count = sectors_left;

	  fResult = CD_ReadSectors(bDrive,
                             dwStartSector + i,
                             sc_count,
                             RMlpBuffer);
		if(!fResult) break;
		_fmemcpy (lpBuffer + cbOffset, PMlpBuffer, CD_SECTOR_SIZE*sc_count);
	}

  GlobalDosFree (LOWORD(gdaBuffer));

  return (fResult);
}

BOOL FAR PASCAL __export FloppySectorsIO(
	BYTE   bDrive,
	DWORD  dwStartSector,
	WORD   wSectors,
	LPBYTE lpBuffer,
	BOOL   reading
)
{
	BOOL   fResult;
	DWORD  cbOffset;
	DWORD  i;
	DWORD  gdaBuffer = 0;
	LPBYTE RMlpBuffer;
	LPBYTE PMlpBuffer;
	WORD  sc_count, sectors_left;

  bDrive = toupper(bDrive) - 'A';

	if (bDrive > 25 || !lpBuffer) return FALSE;

	if (!wSectors || (wSectors > MAX_SECTORS_TO_READ)) return FALSE;

	sc_count = wSectors;
	while(!gdaBuffer) {
		gdaBuffer = GlobalDosAlloc( FLOPPY_SECTOR_SIZE*sc_count );
		if(!gdaBuffer) {
			sc_count >>= 1;
			if(!sc_count) return FALSE;
		}
	}

	RMlpBuffer = (LPBYTE)MAKELONG(0, HIWORD(gdaBuffer));
	PMlpBuffer = (LPBYTE)MAKELONG(0, LOWORD(gdaBuffer));

	sectors_left = wSectors;
	for ( i = cbOffset = 0;
			 i < wSectors;
			 i += sc_count, cbOffset += FLOPPY_SECTOR_SIZE*sc_count, sectors_left -= sc_count )
	{
		if(sc_count > sectors_left) sc_count = sectors_left;

		if(reading) {
		  fResult = Floppy_ReadSectors(bDrive,
                                   dwStartSector + i,
                                   sc_count,
                                   RMlpBuffer);
			if(!fResult) break;
			_fmemcpy (lpBuffer + cbOffset, PMlpBuffer, FLOPPY_SECTOR_SIZE*sc_count);
		} else {
			_fmemcpy (PMlpBuffer, lpBuffer + cbOffset, FLOPPY_SECTOR_SIZE*sc_count);
		  fResult = Floppy_WriteSectors(bDrive,
                                   dwStartSector + i,
                                   sc_count,
                                   RMlpBuffer);
			if(!fResult) break;
		}
	}

  GlobalDosFree (LOWORD(gdaBuffer));

  return (fResult);
}

BOOL FAR PASCAL __export ReadFloppySectors(
	BYTE   bDrive,
	DWORD  dwStartSector,
	WORD   wSectors,
	LPBYTE lpBuffer
)
{
  char buf[100];

  wsprintf( buf, "ReadFloppySectors: %c, %ld, %d", (char)bDrive, (long)dwStartSector, (int)wSectors );
  db( buf );

	return( FloppySectorsIO( bDrive, dwStartSector, wSectors, lpBuffer, TRUE ) );
}

BOOL FAR PASCAL __export WriteFloppySectors(
	BYTE   bDrive,
	DWORD  dwStartSector,
	WORD   wSectors,
	LPBYTE lpBuffer
)
{
  char buf[100];

  wsprintf( buf, "WriteFloppySectors: %c, %ld, %d", (char)bDrive, (long)dwStartSector, (int)wSectors );
  db( buf );

	return( FloppySectorsIO( bDrive, dwStartSector, wSectors, lpBuffer, FALSE ) );
}

BOOL FAR PASCAL CD_ReadSectors(
	BYTE   bDrive,
	DWORD  dwStartSector,
	DWORD  dwCount,
	LPBYTE RMlpBuffer
)
{
	RMCS   callStruct;
	BOOL   fResult;

	db( "Floppy_ReadSector" );
	BuildRMCS (&callStruct);

	callStruct.eax = 0x1508;                 // MSCDEX Absolute read
	callStruct.ebx = LOWORD(RMlpBuffer);     // Offset of sect buffer
	callStruct.es  = HIWORD(RMlpBuffer);     // Segment of sect buffer
	callStruct.ecx = bDrive;                 // 0=A, 1=B, 2=C, etc.
	callStruct.edx = dwCount;                // How many sectors
	callStruct.esi = HIWORD(dwStartSector);
	callStruct.edi = LOWORD(dwStartSector);
	callStruct.wFlags = CARRY_FLAG;

	if (fResult = SimulateRM_Int (0x2F, &callStruct))
	  fResult = !(callStruct.wFlags & CARRY_FLAG);
	return fResult;
}

// Old style read (partitions < 32M)
BOOL FAR PASCAL Floppy_ReadSectors(
	BYTE   bDrive,
	DWORD  dwStartSector,
	DWORD  dwCount,
	LPBYTE RMlpBuffer
)
{
	RMCS   callStruct;
	BOOL   fResult;

	db( "Floppy_ReadSector" );
	// Ralp Brown: original flags are left on stack, and must be popped by caller
	BuildRMCS (&callStruct);
	callStruct.eax = bDrive;                 // 0=A, 1=B, 2=C, etc.
	callStruct.ecx = dwCount;                // Number of sectors
	callStruct.edx = dwStartSector;          // Sector count
	callStruct.ebx = LOWORD(RMlpBuffer);     // Offset of sect buffer
	callStruct.ds  = HIWORD(RMlpBuffer);     // Segment of sect buffer
	callStruct.wFlags = CARRY_FLAG;
	if (fResult = SimulateRM_Int (0x25, &callStruct))
	  fResult = !(callStruct.wFlags & CARRY_FLAG);
	return fResult;
}

// Old style write (partitions < 32M)
BOOL FAR PASCAL Floppy_WriteSectors(
	BYTE   bDrive,
	DWORD  dwStartSector,
	DWORD  dwCount,
	LPBYTE RMlpBuffer
)
{
	RMCS   callStruct;
	BOOL   fResult;

	db( "Floppy_ReadSector" );
	// Ralp Brown: original flags are left on stack, and must be popped by caller
	BuildRMCS (&callStruct);
	callStruct.eax = bDrive;                 // 0=A, 1=B, 2=C, etc.
	callStruct.ecx = dwCount;                // Number of sectors
	callStruct.edx = dwStartSector;          // Sector count
	callStruct.ebx = LOWORD(RMlpBuffer);     // Offset of sect buffer
	callStruct.ds  = HIWORD(RMlpBuffer);     // Segment of sect buffer
	callStruct.wFlags = CARRY_FLAG;
	if (fResult = SimulateRM_Int (0x26, &callStruct))
	  fResult = !(callStruct.wFlags & CARRY_FLAG);
	return fResult;
}



/*-------------------------------------------------------------------
  SimulateRM_Int()

  Allows protected-mode software to execute real-mode interrupts
  such as calls to MS-DOS, MS-DOS TSRs, MS-DOS device drivers.

  This function implements the "Simulate Real Mode Interrupt"
  function of the DPMI specification v0.9 and later.

  Parameters:

     bIntNum
        Number of the interrupt to simulate.

     lpCallStruct
        Call structure that contains params (register values)
        for bIntNum.

  Return Value
     SimulateRM_Int returns TRUE if it succeeded or FALSE if
     it failed.

  Comments
     lpCallStruct is a protected-mode selector:offset address, not


     a real-mode segment:offset address.
*/

BOOL FAR PASCAL SimulateRM_Int (BYTE bIntNum, LPRMCS lpCallStruct)
{
  BOOL fRetVal = FALSE;        // Assume failure

	db( "SimulateRM_Int" );
  _asm {

#ifdef _DEBUG
				 int 3
#endif
         push di
         mov  ax, 0300h         ; DPMI Simulate Real Mode Interrupt
         mov  bl, bIntNum       ; Number of the interrupt to simulate
         mov  bh, 01h           ; Bit 0 = 1; all other bits must be 0
         xor  cx, cx            ; No words to copy from PM to RM stack
         les  di, lpCallStruct  ; Real mode call structure
         int  31h               ; Call DPMI
         jc   END1              ; CF set if error occurred

         mov  fRetVal, TRUE
     END1:
         pop di
        }
   return (fRetVal);
}


/*-------------------------------------------------------------------
   BuildRMCS()

   Initializes a real-mode call structure by
	 zeroing all its members.

   Parameters:

      lpCallStruct
         Points to a real-mode call structure

   Return Value
         None.

   Comments
         lpCallStruct is a protected-mode
				 selector:offset address,
         not a real-mode segment:offset address.
*/


void FAR PASCAL BuildRMCS (LPRMCS lpCallStruct)
{
	db( "BuildRMCS" );
	_fmemset (lpCallStruct, 0, sizeof(RMCS));
}


// prototype for function in .obj file from the thunk script
BOOL WINAPI __export thk_ThunkConnect16(LPSTR lpDll16,
                                        LPSTR lpDll32,
                                        WORD  hInst,
                                        DWORD dwReason);

BOOL WINAPI __export DllEntryPoint(DWORD dwReason,
                                   WORD  hInst,
                                   WORD  wDS,
                                   WORD  wHeapSize,
                                   DWORD dwReserved1,
                                   WORD  wReserved2)
{
 if (!thk_ThunkConnect16("B2WIN16.DLL",
                         "B2WIN32.DLL",
                         hInst,
                         dwReason))
	{
		db( "thk_ThunkConnect16 failed" );
		return FALSE;
	}
	db( "thk_ThunkConnect16 succeeded" );
	return TRUE;
}
