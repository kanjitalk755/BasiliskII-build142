/*
 *  cdrom.cpp - CD-ROM driver
 *
 *  Basilisk II (C) 1997-1999 Christian Bauer
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

/*
 *  SEE ALSO
 *    Inside Macintosh: Devices, chapter 1 "Device Manager"
 *    Technote DV 05: "Drive Queue Elements"
 *    Technote DV 22: "CD-ROM Driver Calls"
 *    Technote DV 23: "Driver Education"
 *    Technote FL 24: "Don't Look at ioPosOffset for Devices"
 *    Technote FL 36: "Apple Extensions to ISO 9660"
 */

#include <string.h>

#include "sysdeps.h"
#include "cpu_emulation.h"
#include "main.h"
#include "macos_util.h"
#include "sys.h"
#include "prefs.h"
#include "cdrom.h"

#define DEBUG 0
#include "debug.h"


// CDROM disk/drive icon
const uint8 CDROMIcon[258] = {
	0x3f, 0xff, 0xff, 0xf0, 0x40, 0x00, 0x00, 0x08, 0x80, 0x1f, 0xc0, 0x04, 0x80, 0x75, 0x70, 0x04,
	0x81, 0xaa, 0xac, 0x04, 0x83, 0x55, 0x56, 0x04, 0x86, 0xaa, 0xab, 0x04, 0x8d, 0x55, 0x55, 0x84,
	0x8a, 0xaa, 0xaa, 0xc4, 0x95, 0x5f, 0xd5, 0x44, 0x9a, 0xb0, 0x6a, 0xe4, 0xb5, 0x67, 0x35, 0x64,
	0xaa, 0xcf, 0x9a, 0xb4, 0xb5, 0x5c, 0x55, 0x74, 0xaa, 0xd8, 0x5a, 0xb4, 0xb5, 0x58, 0x55, 0x74,
	0xaa, 0xc8, 0x9a, 0xb4, 0xb5, 0x67, 0x35, 0x74, 0x9a, 0xb0, 0x6a, 0xf4, 0x95, 0x5f, 0xd5, 0x64,
	0x8a, 0xaa, 0xaa, 0xe4, 0x8d, 0x55, 0x55, 0xc4, 0x86, 0xaa, 0xab, 0xc4, 0x83, 0x55, 0x57, 0x84,
	0x81, 0xaa, 0xaf, 0x04, 0x80, 0xf5, 0x7e, 0x04, 0x80, 0x3f, 0xf8, 0x04, 0x80, 0x0f, 0xe0, 0x04,
	0xff, 0xff, 0xff, 0xfc, 0x80, 0x00, 0x00, 0x04, 0x80, 0x1f, 0xf0, 0x04, 0x7f, 0xff, 0xff, 0xf8,

	0x3f, 0xff, 0xff, 0xf0, 0x7f, 0xff, 0xff, 0xf8, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc,
	0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc,
	0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc,
	0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc,
	0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc,
	0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc,
	0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc,
	0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xfc, 0x7f, 0xff, 0xff, 0xf8,

	0, 0
};


// Tables for converting bin<->BCD
static const uint8 bin2bcd[256] = {
	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
	0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19,
	0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29,
	0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
	0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
	0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
	0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
	0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79,
	0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
	0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff
};

static const uint8 bcd2bin[256] = {
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
};


// Struct for each drive
struct DriveInfo {
	DriveInfo()
	{
		next = NULL;
		num = 0;
		fh = NULL;
		start_byte = 0;
		status = 0;
	}

	DriveInfo *next;	// Pointer to next DriveInfo (must be first in struct!)
	int num;			// Drive number
	void *fh;			// File handle
	int block_size;		// CD-ROM block size
	int twok_offset;	// Offset of beginning of 2K block to last Prime position
	uint32 start_byte;	// Start of HFS partition on disk
	bool to_be_mounted;	// Flag: drive must be mounted in accRun
	bool mount_non_hfs;	// Flag: Issue disk-inserted events for non-HFS disks

	uint8 toc[804];		// TOC of currently inserted disk
	uint8 lead_out[3];	// MSF address of lead-out track
	uint8 stop_at[3];	// MSF address of audio play stopping point

	uint8 play_mode;	// Audio play mode
	uint8 power_mode;	// Power mode
	uint32 status;		// Mac address of drive status record
};

// Linked list of DriveInfos
static DriveInfo *first_drive_info;

// Icon address (Mac address space, set by PatchROM())
uint32 CDROMIconAddr;

// Number of ticks between checks for disk insertion
// const int driver_delay = 120;

// Flag: Control(accRun) has been called, interrupt routine is now active
static bool acc_run_called = false;


/*
 *  Get pointer to drive info, NULL = invalid drive number
 */

static DriveInfo *get_drive_info(int num)
{
	DriveInfo *info = first_drive_info;
	while (info != NULL) {
		if (info->num == num)
			return info;
		info = info->next;
	}
	return NULL;
}


/*
 *  Find HFS partition, set info->start_byte (0 = no HFS partition)
 */

static void find_hfs_partition(DriveInfo *info)
{
	info->start_byte = 0;
	uint8 *map = new uint8[512];

	// Search first 64 blocks for HFS partition
	for (int i=0; i<64; i++) {
		if (Sys_read(info->fh, map, i * 512, 512) != 512)
			break;

		// Skip driver descriptor
		uint16 sig = ntohs(((uint16 *)map)[0]);
		if (sig == 'ER')
			continue;

		// No partition map? Then look at next block
		if (sig != 'PM')
			continue;

		// Partition map found, Apple HFS partition?
		if (strcmp((char *)(map + 48), "Apple_HFS") == 0) {
			info->start_byte = ntohl(((uint32 *)map)[2]) << 9;
			D(bug(" HFS partition found at %ld, %ld blocks\n", info->start_byte, ntohl(((uint32 *)map)[3])));
			break;
		}
	}
	delete[] map;
}


/*
 *  Read TOC of disk and set lead_out
 */

static void read_toc(DriveInfo *info)
{
	// Read TOC
	memset(&info->toc, 0, sizeof(info->toc));
	SysCDReadTOC(info->fh, info->toc);
	D(bug(" TOC: %08lx %08lx\n", ntohl(((uint32 *)info->toc)[0]), ntohl(((uint32 *)info->toc)[1])));

	// Find lead-out track
	info->lead_out[0] = 0;
	info->lead_out[1] = 0;
	info->lead_out[2] = 0;
	for (int i=4; i<804; i+=8) {
		if (info->toc[i+2] == 0xaa) {
			info->stop_at[0] = info->lead_out[0] = info->toc[i+5];
			info->stop_at[1] = info->lead_out[1] = info->toc[i+6];
			info->stop_at[2] = info->lead_out[2] = info->toc[i+7];
			break;
		}
	}
	D(bug(" Lead-Out M %d S %d F %d\n", info->lead_out[0], info->lead_out[1], info->lead_out[2]));
}


/*
 *  Convert audio positioning type/position to MSF address
 *  Return: false = error
 */

static bool position2msf(DriveInfo *info, uint16 postype, uint32 pos, bool stopping, uint8 &m, uint8 &s, uint8 &f)
{
	switch (postype) {
		case 0:
			m = pos / (60 * 75);
			s = (pos / 75) % 60;
			f = pos % 75;
			return true;
		case 1:
			m = bcd2bin[(pos >> 16) & 0xff];
			s = bcd2bin[(pos >> 8) & 0xff];
			f = bcd2bin[pos & 0xff];
			return true;
		case 2: {
			uint8 track = bcd2bin[pos & 0xff];
			if (stopping)
				track++;
			for (int i=4; i<804; i+=8) {
				if (info->toc[i+2] == track || info->toc[i+2] == 0xaa) {
					m = info->toc[i+5];
					s = info->toc[i+6];
					f = info->toc[i+7];
					return true;
				}
			}
			return false;
		}
		default:
			return false;
	}
}


/*
 *  Initialization
 */

void CDROMInit(void)
{
	first_drive_info = NULL;

	// No drives specified in prefs? Then add defaults
	if (PrefsFindString("cdrom", 0) == NULL)
		SysAddCDROMPrefs();

	// Add drives specified in preferences
	int32 index = 0;
	const char *str;
	while ((str = PrefsFindString("cdrom", index++)) != NULL) {
		void *fh = Sys_open(str, true);
		if (fh) {
			DriveInfo *info = new DriveInfo;
			info->fh = fh;
			DriveInfo *p = (DriveInfo *)&first_drive_info;
			while (p->next != NULL)
				p = p->next;
			p->next = info;
		}
	}
}


/*
 *  Deinitialization
 */

void CDROMExit(void)
{
	DriveInfo *info = first_drive_info, *next;
	while (info != NULL) {
		SysAllowRemoval(info->fh);
		Sys_close(info->fh);
		next = info->next;
		delete info;
		info = next;
	}
}


/*
 *  Disk was inserted, flag for mounting
 */

bool CDROMMountVolume(void *fh)
{
	DriveInfo *info;
	for (info = first_drive_info; info != NULL && info->fh != fh; info = info->next) ;
	if (info) {
		if (SysIsDiskInserted(info->fh)) {
			SysPreventRemoval(info->fh);
			WriteMacInt8(info->status + dsDiskInPlace, 1);
			read_toc(info);
			find_hfs_partition(info);
			if (info->start_byte != 0 || info->mount_non_hfs)
				info->to_be_mounted = true;
		}
		return true;
	} else
		return false;
}


/*
 *  Mount volumes for which the to_be_mounted flag is set
 *  (called during interrupt time)
 */

static void mount_mountable_volumes(void)
{
	DriveInfo *info = first_drive_info;
	while (info != NULL) {

		// Disk in drive?
		if (ReadMacInt8(info->status + dsDiskInPlace) == 0) {

			// No, check if disk was inserted
			if (SysIsDiskInserted(info->fh))
				CDROMMountVolume(info->fh);
		}

		// Mount disk if flagged
		if (info->to_be_mounted) {
			D(bug(" mounting drive %d\n", info->num));
			M68kRegisters r;
			r.d[0] = info->num;
			r.a[0] = 7;	// diskEvent
			Execute68kTrap(0xa02f, &r);		// PostEvent()
			info->to_be_mounted = false;
		}

		info = info->next;
	}
}


/*
 *  Driver Open() routine
 */

int16 CDROMOpen(uint32 pb, uint32 dce)
{
	D(bug("CDROMOpen\n"));

	// Set up DCE
	WriteMacInt32(dce + dCtlPosition, 0);
	acc_run_called = false;

	// Install drives
	for (DriveInfo *info = first_drive_info; info; info = info->next) {

		info->num = FindFreeDriveNumber(1);
		info->to_be_mounted = false;

		if (info->fh) {
			info->mount_non_hfs = true;
			info->block_size = 512;
			info->twok_offset = -1;
			info->play_mode = 0x09;
			info->power_mode = 0;

			// Allocate drive status record
			M68kRegisters r;
			r.d[0] = SIZEOF_DrvSts;
			Execute68kTrap(0xa71e, &r);		// NewPtrSysClear()
			if (r.a[0] == 0)
				continue;
			info->status = r.a[0];
			D(bug(" DrvSts at %08lx\n", info->status));

			// Set up drive status
			WriteMacInt8(info->status + dsWriteProt, 0x80);
			WriteMacInt8(info->status + dsInstalled, 1);
			WriteMacInt8(info->status + dsSides, 1);

			// Disk in drive?
			if (SysIsDiskInserted(info->fh)) {
				SysPreventRemoval(info->fh);
				WriteMacInt8(info->status + dsDiskInPlace, 1);
				read_toc(info);
				find_hfs_partition(info);
				info->to_be_mounted = true;
			}

			// Add drive to drive queue
			D(bug(" adding drive %d\n", info->num));
			r.d[0] = (info->num << 16) | (CDROMRefNum & 0xffff);
			r.a[0] = info->status + dsQLink;
			Execute68kTrap(0xa04e, &r);		// AddDrive()
		}
	}
	return noErr;
}


/*
 *  Driver Prime() routine
 */

int16 CDROMPrime(uint32 pb, uint32 dce)
{
	WriteMacInt32(pb + ioActCount, 0);

	// Drive valid and disk inserted?
	DriveInfo *info;
	if ((info = get_drive_info(ReadMacInt16(pb + ioVRefNum))) == NULL)
		return nsDrvErr;
	if (ReadMacInt8(info->status + dsDiskInPlace) == 0)
		return offLinErr;

	// Get parameters
	void *buffer = Mac2HostAddr(ReadMacInt32(pb + ioBuffer));
	size_t length = ReadMacInt32(pb + ioReqCount);
	loff_t position = ReadMacInt32(dce + dCtlPosition);
	if ((length & (info->block_size - 1)) || (position & (info->block_size - 1)))
		return paramErr;
	info->twok_offset = (position + info->start_byte) & 0x7ff;

	size_t actual = 0;
	if ((ReadMacInt16(pb + ioTrap) & 0xff) == aRdCmd) {

		// Read
		actual = Sys_read(info->fh, buffer, position + info->start_byte, length);
		if (actual != length) {

			// Read error, tried to read HFS root block?
			if (length == 0x200 && position == 0x400) {

				// Yes, fake (otherwise audio CDs won't get mounted)
				memset(buffer, 0, 0x200);
				actual = 0x200;
			} else
				return readErr;
		}
	} else
		return wPrErr;

	// Update ParamBlock and DCE
	WriteMacInt32(pb + ioActCount, actual);
	WriteMacInt32(dce + dCtlPosition, ReadMacInt32(dce + dCtlPosition) + actual);
	return noErr;
}


/*
 *  Driver Control() routine
 */

int16 CDROMControl(uint32 pb, uint32 dce)
{
	uint16 code = ReadMacInt16(pb + csCode);
	D(bug("CDROMControl %d\n", code));

	// General codes
	switch (code) {
		case 1:		// KillIO
			return noErr;

		case 65: {	// Periodic action (accRun, "insert" disks on startup)
			mount_mountable_volumes();
			WriteMacInt16(dce + dCtlFlags, ReadMacInt16(dce + dCtlFlags) & ~0x2000);	// Disable periodic action
			acc_run_called = true;
			return noErr;
		}

		case 81:		// Set poll freq
			WriteMacInt16(dce + dCtlDelay, ReadMacInt16(pb + csParam));
			return noErr;
	}

	// Drive valid?
	DriveInfo *info;
	if ((info = get_drive_info(ReadMacInt16(pb + ioVRefNum))) == NULL)
		if (first_drive_info == NULL)
			return nsDrvErr;
		else
			info = first_drive_info;	// This is needed for Apple's Audio CD program

	// Drive-specific codes
	switch (code) {
		case 5:			// VerifyTheDisc
			if (ReadMacInt8(info->status + dsDiskInPlace) > 0)
				return noErr;
			else
				return offLinErr;

		case 6:			// FormatTheDisc
			return writErr;

		case 7:			// EjectTheDisc
			if (ReadMacInt8(info->status + dsDiskInPlace) > 0) {
				SysAllowRemoval(info->fh);
				SysEject(info->fh);
				WriteMacInt8(info->status + dsDiskInPlace, 0);
				info->twok_offset = -1;
			}
			return noErr;

		case 21:		// GetDriveIcon
		case 22:		// GetMediaIcon
			WriteMacInt32(pb + csParam, CDROMIconAddr);
			return noErr;

		case 23:		// DriveInfo
			WriteMacInt32(pb + csParam, 0x00000b01);	// Unspecified external removable SCSI disk
			return noErr;

		case 70: {		// SetPowerMode
			uint8 mode = ReadMacInt8(pb + csParam);
			if (mode > 3)
				return paramErr;
			else {
				info->power_mode = mode;
				return noErr;
			}
		}

		case 76:		// ModifyPostEvent
			info->mount_non_hfs = ReadMacInt16(pb + csParam);
			return noErr;

		case 79: {		// Change block size
			uint16 size = ReadMacInt16(pb + csParam);
			D(bug(" change block size to %d bytes\n", size));
			if (size != 512 && size != 2048)
				return paramErr;
			else {
				info->block_size = size;
				return noErr;
			}
		}

		case 80:		// SetUserEject
			if (ReadMacInt8(info->status + dsDiskInPlace) > 0) {
				if (ReadMacInt16(pb + csParam) == 1)
					SysAllowRemoval(info->fh);
				else
					SysPreventRemoval(info->fh);
				return noErr;
			} else
				return offLinErr;

		case 100: {		// ReadTOC
			if (ReadMacInt8(info->status + dsDiskInPlace) == 0)
				return offLinErr;

			int action = ReadMacInt16(pb + csParam);
			D(bug(" read TOC %d\n", action));
			switch (action) {
				case 1:		// Get first/last track number
					WriteMacInt8(pb + csParam, bin2bcd[info->toc[2]]);
					WriteMacInt8(pb + csParam + 1, bin2bcd[info->toc[3]]);
					WriteMacInt16(pb + csParam + 2, 0);
					break;

				case 2:		// Get lead out MSF starting address
					WriteMacInt8(pb + csParam, bin2bcd[info->lead_out[0]]);
					WriteMacInt8(pb + csParam + 1, bin2bcd[info->lead_out[1]]);
					WriteMacInt8(pb + csParam + 2, bin2bcd[info->lead_out[2]]);
					WriteMacInt8(pb + csParam + 3, 0);
					break;

				case 3: {		// Get track starting address
					uint8 *buf = Mac2HostAddr(ReadMacInt32(pb + csParam + 2));
					uint16 buf_size = ReadMacInt16(pb + csParam + 6);
					int track = bcd2bin[ReadMacInt8(pb + csParam + 8)];

					// Search start track in TOC
					int i;
					for (i=4; i<804; i+=8) {
						if (info->toc[i+2] == track)
							break;
					}

					// Fill buffer
					if (i != 804)
						while (buf_size > 0) {
							*buf++ = info->toc[i+1] & 0x0f;		// Control
							*buf++ = bin2bcd[info->toc[i+5]];	// M
							*buf++ = bin2bcd[info->toc[i+6]];	// S
							*buf++ = bin2bcd[info->toc[i+7]];	// F

							// Lead-Out? Then stop
							if (info->toc[i+2] == 0xaa)
								break;

							buf_size -= 4;
							i += 8;
						}
					break;
				}

				case 5:		// Get session information
					WriteMacInt16(pb + csParam, 1);							// First session number
					WriteMacInt16(pb + csParam + 2, 1);						// Last session number
					WriteMacInt16(pb + csParam + 4, bin2bcd[info->toc[2]]);	// First track number of last session
					WriteMacInt8(pb + csParam + 6, info->toc[5] & 0x0f);	// Control
					WriteMacInt8(pb + csParam + 7, bin2bcd[info->toc[9]]);	// M
					WriteMacInt8(pb + csParam + 8, bin2bcd[info->toc[10]]);	// S
					WriteMacInt8(pb + csParam + 9, bin2bcd[info->toc[11]]);	// F
					break;

				default:
					printf("FATAL: .AppleCD/Control(100): unimplemented TOC type\n");
					return paramErr;
			}
			return noErr;
		}

		case 101: {		// ReadTheQSubcode
			if (ReadMacInt8(info->status + dsDiskInPlace) == 0) {
				memset(Mac2HostAddr(pb + csParam), 0, 10);
				return offLinErr;
			}

			uint8 pos[16];
			if (SysCDGetPosition(info->fh, pos)) {
				uint8 *p = Mac2HostAddr(pb + csParam);
				*p++ = pos[5] & 0x0f;		// Control
				*p++ = bin2bcd[pos[6]];		// Track number
				*p++ = bin2bcd[pos[7]];		// Index number
				*p++ = bin2bcd[pos[13]];	// M (rel)
				*p++ = bin2bcd[pos[14]];	// S (rel)
				*p++ = bin2bcd[pos[15]];	// F (rel)
				*p++ = bin2bcd[pos[9]];		// M (abs)
				*p++ = bin2bcd[pos[10]];	// S (abs)
				*p++ = bin2bcd[pos[11]];	// F (abs)
				*p++ = 0;
				return noErr;
			} else
				return ioErr;
		}

		case 102:		// ReadHeader
			printf("FATAL: .AppleCD/Control(102): unimplemented call\n");
			return controlErr;

		case 103: {		// AudioTrackSearch
			D(bug(" AudioTrackSearch postype %d, pos %08lx, hold %d\n", ReadMacInt16(pb + csParam), ReadMacInt32(pb + csParam + 2), ReadMacInt16(pb + csParam + 6)));
			if (ReadMacInt8(info->status + dsDiskInPlace) == 0)
				return offLinErr;

			uint8 start_m, start_s, start_f;
			if (!position2msf(info, ReadMacInt16(pb + csParam), ReadMacInt32(pb + csParam + 2), false, start_m, start_s, start_f))
				return paramErr;
			info->play_mode = ReadMacInt8(pb + csParam + 9) & 0x0f;
			if (!SysCDPlay(info->fh, start_m, start_s, start_f, info->stop_at[0], info->stop_at[1], info->stop_at[2]))
				return paramErr;
			if (ReadMacInt16(pb + csParam + 6) == 0)	// Hold
				SysCDPause(info->fh);
			return noErr;
		}

		case 104:		// AudioPlay
			D(bug(" AudioPlay postype %d, pos %08lx, hold %d\n", ReadMacInt16(pb + csParam), ReadMacInt32(pb + csParam + 2), ReadMacInt16(pb + csParam + 6)));
			if (ReadMacInt8(info->status + dsDiskInPlace) == 0)
				return offLinErr;

			if (ReadMacInt16(pb + csParam + 6)) {
				// Given stopping address
				if (!position2msf(info, ReadMacInt16(pb + csParam), ReadMacInt32(pb + csParam + 2), true, info->stop_at[0], info->stop_at[1], info->stop_at[2]))
					return paramErr;
			} else {
				// Given starting address
				uint8 start_m, start_s, start_f;
				if (!position2msf(info, ReadMacInt16(pb + csParam), ReadMacInt32(pb + csParam + 2), false, start_m, start_s, start_f))
					return paramErr;
				info->play_mode = ReadMacInt8(pb + csParam + 9) & 0x0f;
				if (!SysCDPlay(info->fh, start_m, start_s, start_f, info->stop_at[0], info->stop_at[1], info->stop_at[2]))
					return paramErr;
			}
			return noErr;

		case 105:		// AudioPause
			if (ReadMacInt8(info->status + dsDiskInPlace) == 0)
				return offLinErr;

			switch (ReadMacInt32(pb + csParam)) {
				case 0:
					if (!SysCDResume(info->fh))
						return paramErr;
					break;
				case 1:
					if (!SysCDPause(info->fh))
						return paramErr;
					break;
				default:
					return paramErr;
			}
			return noErr;

		case 106:		// AudioStop
			D(bug(" AudioStop postype %d, pos %08lx\n", ReadMacInt16(pb + csParam), ReadMacInt32(pb + csParam + 2)));
			if (ReadMacInt8(info->status + dsDiskInPlace) == 0)
				return offLinErr;

			if (ReadMacInt16(pb + csParam) == 0 && ReadMacInt32(pb + csParam + 2) == 0) {
				// Stop immediately
				if (!SysCDStop(info->fh, info->lead_out[0], info->lead_out[1], info->lead_out[2]))
					return paramErr;
			} else {
				// Given stopping address
				if (!position2msf(info, ReadMacInt16(pb + csParam), ReadMacInt32(pb + csParam + 2), true, info->stop_at[0], info->stop_at[1], info->stop_at[2]))
					return paramErr;
			}
			return noErr;

		case 107: {		// AudioStatus
			if (ReadMacInt8(info->status + dsDiskInPlace) == 0)
				return offLinErr;

			uint8 pos[16];
			if (!SysCDGetPosition(info->fh, pos))
				return paramErr;

			uint8 *p = Mac2HostAddr(pb + csParam);
			switch (pos[1]) {
				case 0x11:
					*p++ = 0;	// Audio play in progress
					break;
				case 0x12:
					*p++ = 1;	// Audio play paused
					break;
				case 0x13:
					*p++ = 3;	// Audio play completed
					break;
				case 0x14:
					*p++ = 4;	// Error occurred
					break;
				default:
					*p++ = 5;	// No audio play operation requested
					break;
			}
			*p++ = info->play_mode;
			*p++ = pos[5] & 0x0f;		// Control
			*p++ = bin2bcd[pos[9]];		// M (abs)
			*p++ = bin2bcd[pos[10]];	// S (abs)
			*p++ = bin2bcd[pos[11]];	// F (abs)
			return noErr;
		}

		case 108: {		// AudioScan
			if (ReadMacInt8(info->status + dsDiskInPlace) == 0)
				return offLinErr;

			uint8 start_m, start_s, start_f;
			if (!position2msf(info, ReadMacInt16(pb + csParam), ReadMacInt32(pb + csParam + 2), false, start_m, start_s, start_f))
				return paramErr;

			if (!SysCDScan(info->fh, start_m, start_s, start_f, ReadMacInt16(pb + csParam + 6)))
				return paramErr;
			else
				return noErr;
		}

		case 109:		// AudioControl
			SysCDSetVolume(info->fh, ReadMacInt8(pb + csParam), ReadMacInt8(pb + csParam + 1));
			return noErr;

		case 110:		// ReadMCN
			printf("FATAL: .AppleCD/Control(110): unimplemented call\n");
			return controlErr;

		case 111:		// ReadISRC
			printf("FATAL: .AppleCD/Control(111): unimplemented call\n");
			return controlErr;

		case 112: {		// ReadAudioVolume
			uint8 left, right;
			SysCDGetVolume(info->fh, left, right);
			WriteMacInt8(pb + csParam, left);
			WriteMacInt8(pb + csParam + 1, right);
			return noErr;
		}

		case 113:		// GetSpindleSpeed
			WriteMacInt16(pb + csParam, 0xff);
			return noErr;

		case 114:		// SetSpindleSpeed
			return noErr;

		case 115:		// ReadAudio
			printf("FATAL: .AppleCD/Control(115): unimplemented call\n");
			return controlErr;

		case 116:		// ReadAllSubcodes
			printf("FATAL: .AppleCD/Control(116): unimplemented call\n");
			return controlErr;

		case 122:		// SetTrackList
			printf("FATAL: .AppleCD/Control(122): unimplemented call\n");
			return controlErr;

		case 123:		// GetTrackList
			printf("FATAL: .AppleCD/Control(123): unimplemented call\n");
			return controlErr;

		case 124:		// GetTrackIndex
			printf("FATAL: .AppleCD/Control(124): unimplemented call\n");
			return controlErr;

		case 125:		// SetPlayMode
			D(bug(" SetPlayMode %04x\n", ReadMacInt16(pb + csParam)));
			printf("FATAL: .AppleCD/Control(125): unimplemented call\n");
			return controlErr;

		case 126:		// GetPlayMode (Apple's Audio CD program needs this)
			WriteMacInt16(pb + csParam, 0);
			return noErr;

		default:
			printf("WARNING: Unknown CDROMControl(%d)\n", code);
			return controlErr;
	}
}


/*
 *  Driver Status() routine
 */

int16 CDROMStatus(uint32 pb, uint32 dce)
{
	DriveInfo *info = get_drive_info(ReadMacInt16(pb + ioVRefNum));
	uint16 code = ReadMacInt16(pb + csCode);
	D(bug("CDROMStatus %d\n", code));

	// General codes
	switch (code) {
		case 43: {	// DriverGestalt
			uint32 sel = ReadMacInt32(pb + csParam);
			D(bug(" driver gestalt %c%c%c%c\n", sel >> 24, sel >> 16,  sel >> 8, sel));
			switch (sel) {
				case 'vers':	// Version
					WriteMacInt32(pb + csParam + 4, 0x05208000);
					break;
				case 'devt':	// Device type
					WriteMacInt32(pb + csParam + 4, 'cdrm');
					break;
				case 'intf':	// Interface type
					WriteMacInt32(pb + csParam + 4, 'basi');
					break;
				case 'sync':	// Only synchronous operation?
					WriteMacInt32(pb + csParam + 4, 0x01000000);
					break;
				case 'boot':	// Boot ID
					if (info != NULL)
						WriteMacInt16(pb + csParam + 4, info->num);
					else
						WriteMacInt16(pb + csParam + 4, 0);
					WriteMacInt16(pb + csParam + 6, (uint16)CDROMRefNum);
					break;
				case 'wide':	// 64-bit access supported?
					WriteMacInt16(pb + csParam + 4, 0);
					break;
				case 'purg':	// Purge flags
					WriteMacInt32(pb + csParam + 4, 0);
					break;
				case 'ejec':	// Eject flags
					WriteMacInt32(pb + csParam + 4, 0x00030003);	// Don't eject on shutdown/restart
					break;
				case 'flus':	// Flush flags
					WriteMacInt16(pb + csParam + 4, 0);
					break;
				case 'vmop':	// Virtual memory attributes
					WriteMacInt32(pb + csParam + 4, 0);	// Drive not available for VM
					break;
				default:
					return statusErr;
			}
			return noErr;
		}
	}

	// Drive valid?
	if (info == NULL)
		if (first_drive_info == NULL)
			return nsDrvErr;
		else
			info = first_drive_info;	// This is needed for Apple's Audio CD program

	// Drive-specific codes
	switch (code) {
		case 8:			// DriveStatus
			memcpy(Mac2HostAddr(pb + csParam), Mac2HostAddr(info->status), 22);
			return noErr;

		case 70:		// GetPowerMode
			WriteMacInt16(pb + csParam, info->power_mode << 8);
			return noErr;

		case 95:		// Get2KOffset
			if (info->twok_offset > 0) {
				WriteMacInt16(pb + csParam, info->twok_offset);
				return noErr;
			} else
				return statusErr;

		case 96:		// Get drive type
			WriteMacInt16(pb + csParam, 3);			// Apple CD 300 or newer
			return noErr;

		case 98:		// Get block size
			WriteMacInt16(pb + csParam, info->block_size);
			return noErr;

		case 120:		// Return device ident
			WriteMacInt32(pb + csParam, 0);
			return noErr;

		case 121:		// Get CD features
			WriteMacInt16(pb + csParam, 0x0200);	// 300 KB/s
			WriteMacInt16(pb + csParam, 0x0300);	// SCSI-2, stereo
			return noErr;

		default:
			printf("WARNING: Unknown CDROMStatus(%d)\n", code);
			return statusErr;
	}
}


/*
 *  Driver interrupt routine - check for volumes to be mounted
 */

void CDROMInterrupt(void)
{
	if (!acc_run_called)
		return;

	mount_mountable_volumes();
}
