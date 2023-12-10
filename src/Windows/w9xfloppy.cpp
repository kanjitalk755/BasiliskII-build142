/*
 *  w9xfloppy.cpp
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
#include <windows.h>
#include "w9xfloppy.h"

#define VWIN32_DIOC_DOS_IOCTL     1
#define VWIN32_DIOC_DOS_INT25     2
#define VWIN32_DIOC_DOS_INT26     3
#define VWIN32_DIOC_DOS_DRIVEINFO 6

typedef struct _DIOC_REGISTERS {
    DWORD reg_EBX;
    DWORD reg_EDX;
    DWORD reg_ECX;
    DWORD reg_EAX;
    DWORD reg_EDI;
    DWORD reg_ESI;
    DWORD reg_Flags;
} DIOC_REGISTERS, *PDIOC_REGISTERS;

#define CARRY_FLAG 1

#pragma pack(1)
typedef struct _DISKIO {
   DWORD  dwStartSector;   // starting logical sector number
   WORD   wSectors;        // number of sectors
   DWORD  dwBuffer;        // address of read/write buffer
} DISKIO, * PDISKIO;
#pragma pack()

BOOL ReadLogicalSectors (HANDLE hDev,
                         BYTE   bDrive,
                         DWORD  dwStartSector,
                         WORD   wSectors,
                         LPBYTE lpSectBuff)
{
   BOOL           fResult;
   DWORD          cb;
   DIOC_REGISTERS reg = {0};
   DISKIO         dio = {0};

   dio.dwStartSector = dwStartSector;
   dio.wSectors      = wSectors;
   dio.dwBuffer      = (DWORD)lpSectBuff;

   reg.reg_EAX = bDrive - 1;    // Int 25h drive numbers are 0-based.
   reg.reg_EBX = (DWORD)&dio;
   reg.reg_ECX = 0xFFFF;        // use DISKIO struct

   fResult = DeviceIoControl(hDev, VWIN32_DIOC_DOS_INT25,
                             &reg, sizeof(reg),
                             &reg, sizeof(reg), &cb, 0);

   // Determine if the DeviceIoControl call and the read succeeded.
   fResult = fResult && !(reg.reg_Flags & CARRY_FLAG);

   return fResult;
}


BOOL WriteLogicalSectors (HANDLE hDev,
                          BYTE   bDrive,
                          DWORD  dwStartSector,
                          WORD   wSectors,
                          LPBYTE lpSectBuff)
{
   BOOL           fResult;
   DWORD          cb;
   DIOC_REGISTERS reg = {0};
   DISKIO         dio = {0};

   dio.dwStartSector = dwStartSector;
   dio.wSectors      = wSectors;
   dio.dwBuffer      = (DWORD)lpSectBuff;

   reg.reg_EAX = bDrive - 1;    // Int 26h drive numbers are 0-based.
   reg.reg_EBX = (DWORD)&dio;
   reg.reg_ECX = 0xFFFF;        // use DISKIO struct

   fResult = DeviceIoControl(hDev, VWIN32_DIOC_DOS_INT26,
                             &reg, sizeof(reg),
                             &reg, sizeof(reg), &cb, 0);

   // Determine if the DeviceIoControl call and the write succeeded.
   fResult = fResult && !(reg.reg_Flags & CARRY_FLAG);

   return fResult;
}

BOOL NewReadSectors (HANDLE hDev,
                     BYTE   bDrive,
                     DWORD  dwStartSector,
                     WORD   wSectors,
                     LPBYTE lpSectBuff)
{
  BOOL           fResult;
  DWORD          cb;
  DIOC_REGISTERS reg = {0};
  DISKIO         dio;

  dio.dwStartSector = dwStartSector;
  dio.wSectors      = wSectors;
  dio.dwBuffer      = (DWORD)lpSectBuff;

  reg.reg_EAX = 0x7305;   // Ext_ABSDiskReadWrite
  reg.reg_EBX = (DWORD)&dio;
  reg.reg_ECX = -1;
  reg.reg_EDX = bDrive;   // Int 21h, fn 7305h drive numbers are 1-based

  fResult = DeviceIoControl(hDev, VWIN32_DIOC_DOS_DRIVEINFO,
                            &reg, sizeof(reg),
                            &reg, sizeof(reg), &cb, 0);

  // Determine if the DeviceIoControl call and the read succeeded.
  fResult = fResult && !(reg.reg_Flags & CARRY_FLAG);

  return fResult;
}

BOOL NewWriteSectors (HANDLE hDev,
                     BYTE   bDrive,
                     DWORD  dwStartSector,
                     WORD   wSectors,
                     LPBYTE lpSectBuff)
{
  BOOL           fResult;
  DWORD          cb;
  DIOC_REGISTERS reg = {0};
  DISKIO         dio;

  dio.dwStartSector = dwStartSector;
  dio.wSectors      = wSectors;
  dio.dwBuffer      = (DWORD)lpSectBuff;

  reg.reg_EAX = 0x7305;   // Ext_ABSDiskReadWrite
  reg.reg_EBX = (DWORD)&dio;
  reg.reg_ECX = -1;
  reg.reg_EDX = bDrive;   // Int 21h, fn 7305h drive numbers are 1-based

  reg.reg_ESI = 0x6001;   // Normal file data (See function
                          // documentation for other values)


  fResult = DeviceIoControl(hDev, VWIN32_DIOC_DOS_DRIVEINFO,
                            &reg, sizeof(reg),
                            &reg, sizeof(reg), &cb, 0);

  // Determine if the DeviceIoControl call and the write succeeded.
  fResult = fResult && !(reg.reg_Flags & CARRY_FLAG);

  return fResult;
}

BOOL WINAPI LockLogicalVolumeW95(HANDLE hVWin32,
                                 BYTE   bDriveNum,
                                 BYTE   bLockLevel,
                                 WORD   wPermissions)
{
   BOOL           fResult;
   DIOC_REGISTERS regs = {0};
   BYTE           bDeviceCat;  // can be either 0x48 or 0x08
   DWORD          cb;

   /*
      Try first with device category 0x48 for FAT32 volumes. If it
      doesn't work, try again with device category 0x08. If that
      doesn't work, then the lock failed.
   */

   bDeviceCat = 0x48;

ATTEMPT_AGAIN:
   // Set up the parameters for the call.
   regs.reg_EAX = 0x440D;
   regs.reg_EBX = MAKEWORD(bDriveNum, bLockLevel);
   regs.reg_ECX = MAKEWORD(0x4A, bDeviceCat);
   regs.reg_EDX = wPermissions;

   fResult = DeviceIoControl (hVWin32, VWIN32_DIOC_DOS_IOCTL,
                              &regs, sizeof(regs), &regs, sizeof(regs),
                              &cb, 0);

   // See if DeviceIoControl and the lock succeeded
   fResult = fResult && !(regs.reg_Flags & CARRY_FLAG);

   // If DeviceIoControl or the lock failed, and device category 0x08
   // hasn't been tried, retry the operation with device category 0x08.
   if (!fResult && (bDeviceCat != 0x08))
   {
      bDeviceCat = 0x08;
      goto ATTEMPT_AGAIN;
   }

   return fResult;
}

BOOL WINAPI UnlockLogicalVolumeW95(HANDLE hVWin32, BYTE bDriveNum)
{
   BOOL           fResult;
   DIOC_REGISTERS regs = {0};
   BYTE           bDeviceCat;  // can be either 0x48 or 0x08
   DWORD          cb;

   /* Try first with device category 0x48 for FAT32 volumes. If it
      doesn't work, try again with device category 0x08. If that
      doesn't work, then the unlock failed.
   */

   bDeviceCat = 0x48;

ATTEMPT_AGAIN:
   // Set up the parameters for the call.
   regs.reg_EAX = 0x440D;
   regs.reg_EBX = bDriveNum;
   regs.reg_ECX = MAKEWORD(0x6A, bDeviceCat);

   fResult = DeviceIoControl (hVWin32, VWIN32_DIOC_DOS_IOCTL,
                              &regs, sizeof(regs), &regs, sizeof(regs),
                              &cb, 0);

   // See if DeviceIoControl and the unlock succeeded
   fResult = fResult && !(regs.reg_Flags & CARRY_FLAG);

   // If DeviceIoControl or the unlock failed, and device category 0x08
   // hasn't been tried, retry the operation with device category 0x08.
   if (!fResult && (bDeviceCat != 0x08))
   {
      bDeviceCat = 0x08;
      goto ATTEMPT_AGAIN;
   }
   return fResult;
}
