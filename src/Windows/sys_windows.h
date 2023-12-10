/*
 *  sys_windows.h - System dependent routines for Win32
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

#ifndef _SYS_WINDOWS_H_
#define _SYS_WINDOWS_H_

#include "cdenable\cache.h"
#include "undo_buffer.h"

// Bitmapped
typedef enum {
	MEDIA_FLOPPY		= 1,
	MEDIA_CD				= 2,
	MEDIA_HD				= 4,
	//MEDIA_ANY				= MEDIA_FLOPPY|MEDIA_CD|MEDIA_HD,
	MEDIA_REMOVABLE = MEDIA_FLOPPY|MEDIA_CD
} media_t;

#define MAX_DEVICE_NAME _MAX_PATH

// File handles are pointers to these structures
struct file_handle {
	HANDLE h;
	bool is_file;			// Flag: plain file or /dev/something?
	bool is_floppy;		// Flag: floppy device
	bool is_real_floppy;
	bool is_cdrom;		// Flag: CD-ROM device
	bool is_hd;				// Flag: Hard disk.
	bool is_physical;	// Flag: drive instead of partition.
	bool read_only;		// Copy of Sys_open() flag
	off_t start_byte;	// Size of file header (if any)
	cachetype cache;
	char name[MAX_DEVICE_NAME];
	bool is_media_present;
	int drive;
	bool locked;
	int mount_mode;
	undo_buffer ub;
};

enum {
	MMODE_PERSISTENT=0,
	MMODE_NONPERSISTENT,
	MMODE_UNDOABLE,
	MMODE_UNDOABLE_AUTO
};

void media_removed(void);
void media_arrived(void);
void mount_removable_media( media_t media );

#endif // _SYS_WINDOWS_H_
