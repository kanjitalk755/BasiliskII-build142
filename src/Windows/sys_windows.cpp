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

// TODO: SysCDReadTOC() for Win9x
// TODO: get_physical_disk_type_and_letter() for NT5

#include "sysdeps.h"
#include "main.h"
#include "prefs.h"
#include "user_strings.h"
#include "cpu_emulation.h"
#include "macos_util.h"
#include "sony.h"
#include "cdrom.h"
#include "disk.h"
#include "sys.h"
#include "errno.h"
#include "cdenable\ntcd.h"
#include "cdenable\cache.h"
#include "cdenable\eject_nt.h"
#include "cdenable\eject_w9x.h"
#include "cdenable\vxdiface.h"
#include "winioctl.h"
#include "main_windows.h"
#include "sys_windows.h"
#include "kernel_windows.h"
#include "desktop_windows.h"
#include "video_windows.h"
#include <mmsystem.h>
#include "cd_defs.h"
#include "w9xfloppy.h"
#include "undo_windows.h"
#include "resource.h"
#include "emul_op.h"

// This must be always on.
#define DEBUG 1
#undef OutputDebugString
#define OutputDebugString filesys_log_write
static void filesys_log_write( char *s );
#define FILESYS_LOG_FILE_NAME "filesys.log"
#include "debug.h"
#undef D
#define D(x) if(debug_filesys != DB_FILESYS_NONE) (x);

#define DUMMY_HANDLE (HANDLE)-2


static bool is_nt = false;
static bool nocdrom = false;
static bool nofloppyboot = false;
static bool poll_media = true;
static bool realmodecd = false;


enum {
	DB_FILESYS_NONE=0,
	DB_FILESYS_NORMAL,
	DB_FILESYS_LOUD
};

static int16 debug_filesys = DB_FILESYS_NONE;

static HANDLE filesys_log_file = INVALID_HANDLE_VALUE;

#define FLOPPY_ALIGN_MEMORY_SIZE 512
#define HD_ALIGN_MEMORY_SIZE 512
#define CD_READ_AHEAD_SECTORS 16
#define FLOPPY_READ_AHEAD_SECTORS 36

static char *sector_buffer = 0;

static bool some_media_removed = false;
// static bool some_media_arrived = false;


typedef struct _open_list_struct {
	file_handle *fh;
	struct _open_list_struct *next;
} open_list_struct;

static open_list_struct *open_devices = 0;

static bool is_floppy_readable( file_handle *fh );
static bool is_cdrom_readable( file_handle *fh );

static void filesys_log_open( char *path )
{
	if(debug_filesys == DB_FILESYS_NONE) return;

	DeleteFile( path );
	filesys_log_file = CreateFile(
			path,
			GENERIC_READ|GENERIC_WRITE,
			FILE_SHARE_READ,
			NULL,
			CREATE_ALWAYS,
			FILE_FLAG_WRITE_THROUGH,
			NULL
	);
	if( filesys_log_file == INVALID_HANDLE_VALUE ) {
		ErrorAlert( "Could not create the filesys log file." );
	}
}

static void filesys_log_close( void )
{
	if(debug_filesys == DB_FILESYS_NONE) return;

	if( filesys_log_file != INVALID_HANDLE_VALUE ) {
		CloseHandle( filesys_log_file );
		filesys_log_file = INVALID_HANDLE_VALUE;
	}
}

static void filesys_log_write( char *s )
{
	DWORD bytes_written;

	// should have been checked already.
	if(debug_filesys == DB_FILESYS_NONE) return;

	if( filesys_log_file != INVALID_HANDLE_VALUE ) {

		DWORD count = strlen(s);
		if (0 == WriteFile(filesys_log_file, s, count, &bytes_written, NULL) ||
				(int)bytes_written != count)
		{
			filesys_log_close();
			ErrorAlert( "filesys log file write error (out of disk space?). Log closed." );
		} else {
			FlushFileBuffers( filesys_log_file );
		}
	}
}

static void sys_add_open_list(file_handle *fh)
{
	open_list_struct *p;

	p = new open_list_struct;
	if(p) {
		p->fh = fh;
		p->next = open_devices;
		open_devices = p;
	}
}

static void sys_remove_open_list(file_handle *fh)
{
	open_list_struct *p = open_devices;
	open_list_struct *prev = 0;

	while(p) {
		if(p->fh == fh) {
			if(prev) {
				prev->next = p->next;
			} else {
				open_devices = p->next;
			}
			delete p;
			break;
		}
		prev = p;
		p = p->next;
	}
}

void mount_removable_media( media_t media )
{
	open_list_struct *p = open_devices;

	D(bug("mount_removable_media(%d)\r\n",media));

	while(p) {
		// if(!p->fh->is_media_present) {
			// some_media_arrived = true;
			if(p->fh->is_floppy && (media & MEDIA_FLOPPY)) {
				D(bug("mounting floppy %s\r\n",p->fh->name));

				cache_clear( &p->fh->cache );
				p->fh->start_byte = 0;
				if(is_nt) {
					if(p->fh->h && p->fh->h != INVALID_HANDLE_VALUE) {
						D(bug("mount closing file %X\r\n",p->fh->h));
						CloseHandle(p->fh->h);
					}
					UINT prevmode = SetErrorMode(SEM_NOOPENFILEERRORBOX|SEM_FAILCRITICALERRORS);
					p->fh->h = CreateFile (p->fh->name,
											   p->fh->read_only ? GENERIC_READ : GENERIC_READ|GENERIC_WRITE,
												 FILE_SHARE_READ,
												 NULL, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS,
												 NULL);
					D(bug("mount reopened file: %X\r\n",p->fh->h));
					SetErrorMode(prevmode);
				}
				if( p->fh->h != INVALID_HANDLE_VALUE ) {
					p->fh->is_media_present = is_floppy_readable(p->fh);
					D(bug("is_media_present = %d\r\n",(int)p->fh->is_media_present));
					if(p->fh->is_media_present) {
						D(bug("calling MountVolume()\r\n"));
						MountVolume(p->fh);
					}
				} else {
					p->fh->is_media_present = false;
				}
			} else if(p->fh->is_cdrom && (media & MEDIA_CD)) {
				D(bug("mounting cd %s\r\n",p->fh->name));
				cache_clear( &p->fh->cache );
				p->fh->start_byte = 0;

				if(is_nt) {
					if(p->fh->h && p->fh->h != INVALID_HANDLE_VALUE) {
						CloseHandle(p->fh->h);
					}
					char dname[64];
					sprintf(dname,"\\\\.\\%c:",(char)*p->fh->name);
					p->fh->h = CreateFile (dname, GENERIC_READ,
												 FILE_SHARE_READ|FILE_SHARE_WRITE,
												 NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
												 NULL);
				}
				if( p->fh->h != INVALID_HANDLE_VALUE ) {
					p->fh->is_media_present = is_cdrom_readable(p->fh);
					if(p->fh->is_media_present) {
						MountVolume(p->fh);
					}
				} else {
					p->fh->is_media_present = false;
				}
			} else if(p->fh->is_hd && (media & MEDIA_HD)) {
				MountVolume(p->fh);
			}
		// }
		p = p->next;
	}
}

static void check_os(void)
{
	OSVERSIONINFO osv;

	is_nt = false;

	osv.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
	if(GetVersionEx( &osv )) {
		switch(osv.dwPlatformId) {
			case VER_PLATFORM_WIN32s:
				ErrorAlert("Cannot run on Win32s");
				QuitEmulator();
				// not reached
				break;
			case VER_PLATFORM_WIN32_NT:
				is_nt = true;
				break;
			default:
				is_nt = false;
		}
	}
}

// Must give cd some time to settle
// Cant give too much however, would be annoying, this is difficult..

static int cd_read_with_retry( file_handle *fh, ULONG LBA, int count, char *buf )
{
	int got_bytes = 0;

	if(!fh || !fh->h) return(0);

	if(is_nt) {
		got_bytes = CdenableSysReadCdBytes( fh->h, LBA, count, buf );
	} else {
		if(realmodecd && pfnGETCDSECTORS) {
			BOOL result = pfnGETCDSECTORS(
							fh->drive + 'A',
              LBA / 2048,
              (WORD)(count / 2048),
              (LPBYTE)buf );
			got_bytes = result ? count : 0;
		} else {
			got_bytes = VxdReadCdSectors( fh->drive, LBA, count, buf );
		}
	}
	return(got_bytes);
}

static int cd_read(
	file_handle *fh,
	cachetype *cptr,
	ULONG LBA,
	int count,
	char *buf
)
{
	ULONG l1, l2, cc;
	int i, c_count, got_bytes = 0, nblocks, s_inx, ss, first_block;
	int ok_bytes = 0;
	char *ptr, *ttptr = 0, *tmpbuf;

	if(count <= 0) return(0);
	if(!fh || !fh->h) return(0);

	ss = 2048;
	l1 = (LBA / ss) * ss;
	l2 = ((LBA+count-1+ss)/ss) * ss;
	cc = l2-l1;
	nblocks = cc / ss;
	first_block = LBA / ss;

	ptr = buf;
	s_inx = LBA-l1;
	c_count = ss - s_inx;
	if(c_count > count) c_count = count;

	for(i=0; i<nblocks; i++) {
		if(cache_get( cptr, first_block+i, sector_buffer )) {
			memcpy( ptr, sector_buffer+s_inx, c_count );
			ok_bytes += c_count;
			ptr += c_count;
			s_inx = 0;
			c_count = ss;
			if(c_count > count-ok_bytes) c_count = count-ok_bytes;
		} else {
			break;
		}
	}

	if(i != nblocks && count != ok_bytes) {
		int bytes_left, blocks_left, alignedleft;

		bytes_left = count - ok_bytes;
		blocks_left = nblocks - i;

		// NEW read ahead code:
		int ahead = CD_READ_AHEAD_SECTORS;
		if(blocks_left < ahead) {
			nblocks += (ahead - blocks_left);
			blocks_left = ahead;
		}

		alignedleft = blocks_left*ss;

		tmpbuf = (char *)VirtualAlloc(
				NULL, alignedleft,
				MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE );
		if(tmpbuf) {
			got_bytes = cd_read_with_retry( fh, (first_block+i)*ss, alignedleft, tmpbuf );
			if(got_bytes != alignedleft) {
				// should never happen
				// Yes it does ...
				if(got_bytes < 0) got_bytes = 0;
				if(c_count > got_bytes) c_count = got_bytes;
				if(c_count > 0) {
					ttptr = tmpbuf;
					memcpy( ptr, ttptr+s_inx, c_count );
					ok_bytes += c_count;
				}
				VirtualFree( tmpbuf, 0, MEM_RELEASE  );
				return(ok_bytes);
			}
			ttptr = tmpbuf;
			for( ; i<nblocks; i++ ) {
				if(c_count > 0) {
					memcpy( ptr, ttptr+s_inx, c_count );
					ok_bytes += c_count;
					ptr += c_count;
				}
				s_inx = 0;
				c_count = ss;
				if(c_count > count-ok_bytes) c_count = count-ok_bytes;
				cache_put( cptr, first_block+i, ttptr, ss );
				ttptr += ss;
			}
			VirtualFree( tmpbuf, 0, MEM_RELEASE  );
		}
	}

	return(ok_bytes);
}

size_t nt_floppy_read( file_handle *fh, off_t LBA, size_t count, char *buf )
{
	DWORD bytes_read;
	OVERLAPPED overl;
	char *aux_buffer = 0;
	char *rd_buffer;

	if(count == 0) return(0);
	if(!fh->h) return(0);

	// If not aligned to sector boundary -> must use another buffer
	if( (unsigned long)buf & (FLOPPY_ALIGN_MEMORY_SIZE-1) ) {
		aux_buffer = (char *)VirtualAlloc(
				NULL, count, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE );
		if(!aux_buffer) return(0);
		rd_buffer = aux_buffer;
	} else {
		rd_buffer = buf;
	}

	memset( &overl, 0, sizeof(overl) );
	overl.Offset = LBA;

  if (!ReadFile (fh->h, rd_buffer, count, &bytes_read, &overl)) {
		D(bug("nt_floppy_read(%d,%d) failed.\r\n",(int)LBA,(int)count));
		bytes_read = count = 0;
	}
	if(aux_buffer) {
		if(count) memcpy( buf, rd_buffer, count );
		VirtualFree( aux_buffer, 0, MEM_RELEASE  );
	}
	return(bytes_read);
}

size_t w9x_floppy_read( file_handle *fh, loff_t LBA, size_t count, char *buf )
{
	if(!fh->h) return(0);
	if(count == 0) return(0);

	if( LBA & (FLOPPY_ALIGN_MEMORY_SIZE-1) ) {
		D(bug("Illegal LBA %ld in w9x_floppy_read()\r\n",(long)LBA));
		return(0);
	}
	if( count & (FLOPPY_ALIGN_MEMORY_SIZE-1) ) {
		D(bug("Illegal count %ld in w9x_floppy_read()\r\n",(long)count));
		return(0);
	}

	if(win_os_old) {
		if(ReadLogicalSectors(
				fh->h,
				toupper(*fh->name) - 'A' + 1,
				(DWORD)(LBA/512),
				count/512,
				(unsigned char*)buf ))
		{
			return( count );
		} else {
			return( 0 );
		}
	} else {
		if(NewReadSectors(
				fh->h,
				toupper(*fh->name) - 'A' + 1,
				(DWORD)(LBA/512),
				count/512,
				(unsigned char*)buf ))
		{
			return( count );
		} else {
			return( 0 );
		}
	}
}

size_t w9x_floppy_write( file_handle *fh, loff_t LBA, int count, char *buf )
{
	if(!fh->h) return(0);
	if(count == 0) return(0);

	if( LBA & (FLOPPY_ALIGN_MEMORY_SIZE-1) ) {
		D(bug("Illegal LBA %ld in w9x_floppy_write()\r\n",(long)LBA));
		return(0);
	}
	if( count & (FLOPPY_ALIGN_MEMORY_SIZE-1) ) {
		D(bug("Illegal count %ld in w9x_floppy_write()\r\n",(long)count));
		return(0);
	}

	if(win_os_old) {
		if(WriteLogicalSectors(
				fh->h,
				toupper(*fh->name) - 'A' + 1,
				(DWORD)(LBA/512),
				count/512,
				(unsigned char*)buf ))
		{
			return( count );
		} else {
			return( 0 );
		}
	} else {
		if(NewWriteSectors(
				fh->h,
				toupper(*fh->name) - 'A' + 1,
				(DWORD)(LBA/512),
				count/512,
				(unsigned char*)buf ))
		{
			return( count );
		} else {
			return( 0 );
		}
	}
}

size_t floppy_read( file_handle *fh, cachetype *cptr, off_t LBA, int count, char *buf )
{
	ULONG l1, l2, cc;
	int i, c_count, got_bytes = 0, nblocks, s_inx, ss, first_block;
	int ok_bytes = 0;
	char *ptr, *ttptr = 0, *tmpbuf;

	if(fh->h == 0 || count <= 0) return(0);

	ss = 512;
	l1 = (LBA / ss) * ss;
	l2 = ((LBA+count-1+ss)/ss) * ss;
	cc = l2-l1;
	nblocks = cc / ss;
	first_block = LBA / ss;

	ptr = buf;
	s_inx = LBA-l1;
	c_count = ss - s_inx;
	if(c_count > count) c_count = count;

	for(i=0; i<nblocks; i++) {
		if(cache_get( cptr, first_block+i, sector_buffer )) {
			memcpy( ptr, sector_buffer+s_inx, c_count );
			ok_bytes += c_count;
			ptr += c_count;
			s_inx = 0;
			c_count = ss;
			if(c_count > count-ok_bytes) c_count = count-ok_bytes;
		} else {
			break;
		}
	}

	if(i != nblocks && count != ok_bytes) {
		int bytes_left, blocks_left, alignedleft;

		bytes_left = count - ok_bytes;
		blocks_left = nblocks - i;

		// NEW read ahead code:
		int ahead = FLOPPY_READ_AHEAD_SECTORS;
		if(blocks_left < ahead) {
			nblocks += (ahead - blocks_left);
			blocks_left = ahead;
		}

		alignedleft = blocks_left*ss;

		tmpbuf = (char *)VirtualAlloc(
				NULL, alignedleft,
				MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE );
		if(tmpbuf) {
			if(is_nt) {
				got_bytes = nt_floppy_read( fh, (first_block+i)*ss, alignedleft, tmpbuf );
			} else {
				got_bytes = w9x_floppy_read( fh, (first_block+i)*ss, alignedleft, tmpbuf );
			}
			if(got_bytes != alignedleft) {
				// should never happen
				// Yes it does ...
				if(got_bytes < 0) got_bytes = 0;
				if(c_count > got_bytes) c_count = got_bytes;
				if(c_count > 0) {
					ttptr = tmpbuf;
					memcpy( ptr, ttptr+s_inx, c_count );
					ok_bytes += c_count;
				}
				VirtualFree( tmpbuf, 0, MEM_RELEASE  );
				return(ok_bytes);
			}
			ttptr = tmpbuf;
			for( ; i<nblocks; i++ ) {
				if(c_count > 0) {
					memcpy( ptr, ttptr+s_inx, c_count );
					ok_bytes += c_count;
					ptr += c_count;
				}
				s_inx = 0;
				c_count = ss;
				if(c_count > count-ok_bytes) c_count = count-ok_bytes;
				cache_put( cptr, first_block+i, ttptr, ss );
				ttptr += ss;
			}
			VirtualFree( tmpbuf, 0, MEM_RELEASE  );
		}
	}

	return(ok_bytes);
}

size_t nt_floppy_write( file_handle *fh, ULONG LBA, int count, char *buf )
{
	DWORD bytes_written;
	OVERLAPPED overl;
	char *aux_buffer = 0;

	if(!fh->h) return(0);
	if(count == 0) return(0);

	memset( &overl, 0, sizeof(overl) );
	overl.Offset = LBA;

	// If not aligned to sector boundary -> must use another buffer
	if( (unsigned long)buf & (FLOPPY_ALIGN_MEMORY_SIZE-1) ) {
		aux_buffer = (char *)VirtualAlloc(
				NULL, count, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE );
		if(!aux_buffer) return(0);
		memcpy( aux_buffer, buf, count );
		buf = aux_buffer;
	}

  if (WriteFile (fh->h, buf, count, &bytes_written, &overl) &&
			(int)bytes_written == count)
	{
		;
	} else {
		D(bug("nt_floppy_write(%d,%d) failed.\r\n",(int)LBA,(int)count));
		bytes_written = 0;
	}
	if(aux_buffer) VirtualFree( aux_buffer, 0, MEM_RELEASE  );
	return(bytes_written);
}

size_t floppy_write( file_handle *fh, off_t LBA, size_t count, char *buf )
{
	if(is_nt) {
		return(nt_floppy_write( fh, LBA, count, buf ));
	} else {
		return(w9x_floppy_write( fh, LBA, count, buf ));
	}
}

/*
 *  Initialization
 */

void SysInit(void)
{
	check_os();

	nocdrom = PrefsFindBool("nocdrom");
	nofloppyboot = PrefsFindBool("nofloppyboot");
	poll_media = PrefsFindBool("pollmedia");
	debug_filesys = PrefsFindInt16("debugfilesys");
	realmodecd = PrefsFindBool("realmodecd");

	filesys_log_open( FILESYS_LOG_FILE_NAME );

	D(bug("SysInit\r\n"));

	sector_buffer = (char *)VirtualAlloc( NULL, 8192, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE );

 	if(is_nt) {
		CdenableSysInstallStart();
	} else {
		if(!VxdInit()) nocdrom = true;
		VxdPatch(1);
	}
}

/*
 *  Deinitialization
 */

void SysExit(void)
{
	D(bug("SysExit\r\n"));

	if(sector_buffer) {
		VirtualFree( sector_buffer, 0, MEM_RELEASE  );
		sector_buffer = 0;
	}
 	if(!is_nt) {
		VxdFinal();
	}
	filesys_log_close();
}

/*
static void scan_floppies( char *type )
{
	char rootdir[20], letter;
	int i;

	for( letter = 'A'; letter <= 'B'; letter++ ) {
		i = (int)( letter - 'A' );
		wsprintf( rootdir, "%c:\\", letter );
		if(GetDriveType( rootdir ) == DRIVE_REMOVABLE) {
			PrefsAddString(type, rootdir);
		}
	}
}
*/

/*
 *  This gets called when no "floppy" prefs items are found
 *  It scans for available floppy drives and adds appropriate prefs items
 */

void SysAddFloppyPrefs(void)
{
	// scan_floppies("floppy");
}

/*
 *  This gets called when no "disk" prefs items are found
 *  It scans for available HFS volumes and adds appropriate prefs items
 */

// TODO: we shouldn't boot just from any arbitrary volume which happens to
// be the first one. Set up a dialog here, and prompt for a boot volume file,
// and put it first in the list.

/*
void enum_hard_files( char *dir, char *extension )
{
	char mask[_MAX_PATH], path[_MAX_PATH];
	HANDLE fh;
	WIN32_FIND_DATA FindFileData;
	int ok;

	wsprintf( mask, "%s*.%s", dir, extension );
	fh = FindFirstFile( mask, &FindFileData );
	ok = fh != INVALID_HANDLE_VALUE;
	while(ok) {
		sprintf( path, "%s%s", dir, FindFileData.cFileName );
		PrefsAddString("disk", path);
		ok = FindNextFile( fh, &FindFileData );
	}
	if(fh != INVALID_HANDLE_VALUE) FindClose( fh );
}

void enum_hd_partitions(void)
{
	char rootdir[20], letter;
	int i;
	UINT type;

	for( letter = 'C'; letter <= 'Z'; letter++ ) {
		i = (int)( letter - 'A' );
		wsprintf( rootdir, "%c:\\", letter );
		type = GetDriveType( rootdir );
		if(type == DRIVE_FIXED) {
			PrefsAddString("disk", rootdir);
		}
	}
}
*/

void SysAddDiskPrefs(void)
{
	/*
	char dir[_MAX_PATH];

	GetCurrentDirectory(sizeof(dir),dir);
	if(strlen(dir) > 0 && dir[strlen(dir)-1] != '\\') strcat(dir,"\\");

	enum_hard_files( dir, "hf*" );
	enum_hard_files( dir, "dsk" );
	enum_hd_partitions();
	*/
}


/*
 *  This gets called when no "cdrom" prefs items are found
 *  It scans for available CD-ROM drives and adds appropriate prefs items
 */

void SysAddCDROMPrefs(void)
{
	// Don't scan for drives if nocdrom option given
	/*
	if (!nocdrom) {
		char rootdir[20], letter;
		int i;

		for( letter = 'C'; letter <= 'Z'; letter++ ) {
			i = (int)( letter - 'A' );
			wsprintf( rootdir, "%c:\\", letter );
			if(GetDriveType( rootdir ) == DRIVE_CDROM) {
				PrefsAddString("cdrom", rootdir);
			}
		}
	}
	*/
}


/*
 *  Add default serial prefs (must be added, even if no ports present)
 */

void SysAddSerialPrefs(void)
{
	PrefsAddString("seriala", "COM1");
	PrefsAddString("serialb", "COM2");
}

static void find_hfs_partition(file_handle *fh)
{
	fh->start_byte = 0;
	uint8 *map = new uint8[512];

	D(bug("Finding HFS partition\r\n"));

	if(is_nt) {
		if(nt_floppy_read( fh, 1024, 512, (char *)map ) != 512) {
			delete[] map;
			return;
		}
	} else {
		if(w9x_floppy_read( fh, 1024, 512, (char *)map ) != 512) {
			delete[] map;
			return;
		}
	}
	uint16 sig = ntohs(((uint16 *)map)[0]);
	if (sig == 'BD') {
		delete[] map;
		D(bug("HFS partition found at 0\r\n"));
		return;
	}

	// Search first 64 blocks for HFS partition
	for (int i=0; i<64; i++) {

		D(bug("Checking block %ld\r\n", i));

		if(is_nt) {
			if(nt_floppy_read( fh, i * 512, 512, (char *)map ) != 512) break;
		} else {
			if(w9x_floppy_read( fh, i * 512, 512, (char *)map ) != 512) break;
		}

		// No partition map? Then look at next block
		if (sig != 'PM')
			continue;

		// Partition map found, Apple HFS partition?
		if (strcmp((char *)(map + 48), "Apple_HFS") == 0) {
			fh->start_byte = ntohl(((uint32 *)map)[2]) << 9;
			D(bug(" HFS partition found at %ld, %ld blocks\r\n", fh->start_byte, ntohl(((uint32 *)map)[3])));
			break;
		}
	}
	delete[] map;
}

static bool is_floppy_readable( file_handle *fh )
{
	UINT prevmode = SetErrorMode(SEM_NOOPENFILEERRORBOX|SEM_FAILCRITICALERRORS);
	char dummy[0x200];
	bool result = false;

	cache_clear( &fh->cache );
	fh->start_byte = 0;

	D(bug("Checking presence of media in drive %s\r\n",fh->name));

	if( fh && fh->h != INVALID_HANDLE_VALUE ) {
		if(is_nt) {
			if(nt_floppy_read( fh, 0, sizeof(dummy), dummy ) == sizeof(dummy)) result = true;
		} else {
			if(w9x_floppy_read( fh, 0, sizeof(dummy), dummy ) == sizeof(dummy)) result = true;
		}
		if(result) {
			find_hfs_partition(fh);
		}
  }
	SetErrorMode(prevmode);
	return( result );
}

static bool is_cdrom_readable( file_handle *fh )
{
	bool result = false;
	size_t bytes;
	char *buffer;

	if(!fh || !fh->h) return(0);

	cache_clear( &fh->cache );

	if(is_nt) {
		DWORD dwBytesReturned;
		result = ( 0 != DeviceIoControl(
			fh->h,
			IOCTL_STORAGE_CHECK_VERIFY,
			NULL, 0,
			NULL, 0,
			&dwBytesReturned,
			NULL
		) );
		if(!result) {
			bytes = 2048;
			buffer = (char *)VirtualAlloc( NULL, bytes, MEM_RESERVE|MEM_COMMIT, PAGE_READWRITE );
			if(buffer) {
				result = (cd_read_with_retry( fh, 0, 2048, buffer ) == 2048);
				VirtualFree( buffer, 0, MEM_RELEASE  );
			}
		}
	} else {
		// This does not work for CDDA
		bytes = 2048;
		buffer = (char *)VirtualAlloc( NULL, bytes, MEM_RESERVE|MEM_COMMIT, PAGE_READWRITE );
		if(buffer) {
			result = (cd_read_with_retry( fh, 0, 2048, buffer ) == 2048);
			VirtualFree( buffer, 0, MEM_RELEASE  );
		}
	}

	D(bug("is_cdrom_readable = %d\r\n", (int)result));

	return(result);
}

void media_removed(void)
{
	some_media_removed = true;
}

void media_arrived(void)
{
	// some_media_arrived = true;
	mount_removable_media( MEDIA_REMOVABLE );
}


BOOL is_read_only_path( LPCSTR path )
{
  DWORD attrib;
	BOOL result = FALSE;

  attrib = GetFileAttributes( (char *)path );
  if( attrib != 0xFFFFFFFF && (attrib & FILE_ATTRIBUTE_READONLY) != 0 ) {
		result = TRUE;
  }
	return result;
}

static void no_exclusive_access_warning( LPCSTR name )
{
	char msg[100+_MAX_PATH];
	wsprintf(
		msg,
		"Could not obtain exclusive read/write access to the drive \"%s\", mounting read-only.",
		name
	);
	WarningAlert( msg );
}

// TODO: this does not work on NT5
static int get_physical_disk_type_and_letter( LPCSTR path, char &letter )
{
	int index1, index2;
	char dnamebuf[64];
	char dname[64];

	if(strncmp(path,"\\\\.\\PHYSICALDRIVE",17) == 0) {
		index1 = atoi( &path[17] );
		for( letter='A'; letter<='Z'; letter++ ) {
			sprintf( dname, "%c:", letter );
			if(QueryDosDevice(dname, dnamebuf, sizeof(dnamebuf)) != 0) {
				char *hd = strstr( dnamebuf, "\\Harddisk" );
				if(hd && strstr( dnamebuf, "\\Partition1" )) {
					index2 = atoi(hd+9);
					if(index1 == index2) {
						strcat( dname, "\\" );
						return GetDriveType(dname);
					}
				}
			}
		}
	}
	return DRIVE_UNKNOWN;
}

/*
 *  Open file/device, create new file handle (returns NULL on error)
 */

// TODO: clean up this function. (too long to be readable)

void *Sys_open(const char *_name, bool read_only)
{
	HANDLE h;
	off_t size;
	file_handle *fh = 0;

	char dnamebuf[256];
	char dname[256];
	char dnamel[256];
	char *name, local_name[_MAX_PATH], phys_letter;

	bool physical = false; // open physical/logical volume

	bool user_wants_rw = false;
	bool user_wants_ro = false;
	int	 user_wants_mmode = MMODE_PERSISTENT;

	UINT type = DRIVE_UNKNOWN;


	strcpy( local_name, _name );
	strupr( local_name );
	name = local_name;

	int32 len = strlen(name);
	while( len > 0 && name[len-1] <= ' ' ) len--;
	name[len] = 0;

	if(strncmp(name,"/RW ",4) == 0) {
		user_wants_rw = true;
		name += 3;
		while(*name == ' ') name++;
	}

	if(strncmp(name,"/RU ",4) == 0) {
		user_wants_rw = true;
		user_wants_mmode = MMODE_UNDOABLE;
		name += 3;
		while(*name == ' ') name++;
	}

	if(strncmp(name,"/RA ",4) == 0) {
		user_wants_rw = true;
		user_wants_mmode = MMODE_UNDOABLE_AUTO;
		name += 3;
		while(*name == ' ') name++;
	}

	if(strncmp(name,"/RV ",4) == 0) {
		user_wants_rw = true;
		user_wants_mmode = MMODE_NONPERSISTENT;
		name += 3;
		while(*name == ' ') name++;
	}

	if(strncmp(name,"/RO ",4) == 0) {
		user_wants_ro = true;
		name += 3;
		while(*name == ' ') name++;
	}

	if(strncmp(name,"PHYSICAL ",9) == 0) {
		physical = true;
		name += 9;
		while(*name == ' ') name++;
	}

	if(is_nt && strncmp(name,"\\\\.\\PHYSICALDRIVE",17) == 0) {
		// type = DRIVE_FIXED;
		type = get_physical_disk_type_and_letter(name,phys_letter);
		physical = true;
	}

	// Normalize floppy / cd path.
	// User may give "disk A:" or "disk A:\" or "disk A" or "disk physical A:"

	int name_len = strlen(name);

	if(name_len == 1 && isalpha(*name)) {
		strcat( name, ":\\" );
	}

	if(name_len > 0 && name[name_len-1] == ':') {
		strcat( name, "\\" );
	}

	name_len = strlen(name);

	D(bug("Sys_open(%s, %s)\r\n", name, read_only ? "read-only" : "read/write"));

	if(type != DRIVE_UNKNOWN || (name_len > 0 && name[name_len-1] == '\\')) {

		if(type == DRIVE_UNKNOWN) type = GetDriveType(name);

		if(type == DRIVE_FIXED) {

			if(user_wants_rw) {
				read_only = false;
			} else {
				read_only = true;
			}

			if(is_nt) {
				*dname = 0;
				if(physical) {
					// "\\.\PHYSICALDRIVEx"
					strcpy( dnamebuf, name );
					read_only = true;
				} else {
					sprintf( dnamebuf, "\\\\.\\%c:", (char)toupper(*name) );
				}

				h = CreateFile(
					dnamebuf,
					read_only ? GENERIC_READ : GENERIC_READ|GENERIC_WRITE,
					read_only ? FILE_SHARE_READ|FILE_SHARE_WRITE : 0,
					0,
					OPEN_EXISTING,
					FILE_FLAG_NO_BUFFERING,
					0
				);
				if( read_only == 0 && h == INVALID_HANDLE_VALUE ) {
					read_only = true;
					h = CreateFile(
						dnamebuf,
						GENERIC_READ,
						FILE_SHARE_READ | FILE_SHARE_WRITE,
						0,
						OPEN_EXISTING,
						FILE_FLAG_NO_BUFFERING,
						0
					);
					if( h != INVALID_HANDLE_VALUE ) {
						no_exclusive_access_warning(name);
					}
				}

				if( h != INVALID_HANDLE_VALUE ) {
					fh = new file_handle;
					memset( fh, 0, sizeof(file_handle) );
					fh->h = h;
					fh->is_hd = true;
					fh->is_physical = physical;
					fh->is_media_present = true;
					if( read_only == 0 ) {
						DWORD dwBytesReturned = 0;
						if(DeviceIoControl(h,
							FSCTL_LOCK_VOLUME,
							NULL, 0,
							NULL, 0,
							&dwBytesReturned,
							NULL))
						{
							fh->locked = true;
						} else {
							read_only = true;
							CloseHandle(fh->h);
							no_exclusive_access_warning(name);
							h = fh->h = CreateFile(
								dnamebuf,
								GENERIC_READ,
								FILE_SHARE_READ | FILE_SHARE_WRITE,
								0,
								OPEN_EXISTING,
								FILE_FLAG_NO_BUFFERING,
								0
							);
						}
					}
					fh->read_only = read_only;
					strcpy( fh->name, name );
				}
			} else { // Win9x hd access.
				if(physical) {
					fh = new file_handle;
					memset( fh, 0, sizeof(file_handle) );
					fh->h = DUMMY_HANDLE;
					fh->is_hd = true;
					fh->is_physical = true;
					fh->is_media_present = true;

					// Not implemented. Do not enable this code.
					fh->read_only = true; // read_only;

					strcpy( fh->name, name );
					fh->drive = toupper(*name) - 'A';
				} else {
					h = OpenVWin32();
					if( h != INVALID_HANDLE_VALUE ) {
						fh = new file_handle;
						memset( fh, 0, sizeof(file_handle) );
						fh->h = h;
						fh->is_hd = true;
						fh->is_media_present = true;

						if(!read_only) {
							// Must grab level 0 lock first.
							if(LockLogicalVolumeW95(h, toupper(*name) - 'A' + 1, 0, 0)) {
								fh->locked = true;
							} else {
								read_only = true;
								no_exclusive_access_warning(name);
							}
						}
						fh->read_only = read_only;

						strcpy( fh->name, name );
						fh->drive = toupper(*name) - 'A';
					}
				}
			}
		} else if(type == DRIVE_REMOVABLE) {

			char letter;
			bool is_real_floppy;

			if(physical) {
				letter = phys_letter;
				is_real_floppy = FALSE;
			} else {
				letter = toupper(*name);
				is_real_floppy = letter == 'A' || letter == 'B';
			}

			if(user_wants_ro) read_only = true;

			if(is_nt) {
				if(!physical) {
					sprintf(dname,"B2_floppy_%c",letter);
					if(QueryDosDevice(dname, dnamebuf, sizeof(dnamebuf)) == 0) {
						is_real_floppy = strstr( dnamebuf, "Floppy" ) != 0;
						int rc = GetLastError();
						if(rc == ERROR_FILE_NOT_FOUND) {
							sprintf( name,"%c:", letter );
							if(QueryDosDevice(name, dnamel, sizeof(dnamel)) == 0) {
								return 0;
							}
							// if(win_os_major == 4) {
								// Work around one subtle NT4 bug.
								DefineDosDevice( DDD_REMOVE_DEFINITION, dname, NULL );
							// }
							if (DefineDosDevice(DDD_RAW_TARGET_PATH, dname, dnamel) == 0) {
								return 0;
							}
						} else {
							return 0;
						}
					}
					sprintf(name,"\\\\.\\%s", dname);
				}

				UINT prevmode = SetErrorMode(SEM_NOOPENFILEERRORBOX|SEM_FAILCRITICALERRORS);

				h = CreateFile ( name,
											 read_only ? GENERIC_READ : GENERIC_READ|GENERIC_WRITE,
											 FILE_SHARE_READ,
											 NULL, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS,
											 0);
				if( h == INVALID_HANDLE_VALUE ) h = 0;

				fh = new file_handle;
				memset( fh, 0, sizeof(file_handle) );
				fh->h = h;
				fh->is_physical = physical;
				fh->is_floppy = true;
				fh->is_real_floppy = is_real_floppy;
				fh->read_only = read_only;
				fh->drive = letter - 'A';
				strcpy( fh->name, name );
				memset( &fh->cache, 0, sizeof(cachetype) );
				cache_init( &fh->cache );
				if (fh->h) {
					if (!is_real_floppy || !nofloppyboot) {
						fh->is_media_present = is_floppy_readable(fh);
					}
				}
				SetErrorMode(prevmode);
			} else {
				h = OpenVWin32();
				if( h != INVALID_HANDLE_VALUE ) {
					fh = new file_handle;
					memset( fh, 0, sizeof(file_handle) );
					fh->h = h;
					fh->is_floppy = true;
					fh->is_real_floppy = is_real_floppy;
					if(LockLogicalVolumeW95(h, toupper(*name) - 'A' + 1, 0, 0)) {
						fh->locked = true;
					} else {
						read_only = true;
					}
					fh->read_only = read_only;
					strcpy( fh->name, name );
					memset( &fh->cache, 0, sizeof(cachetype) );
					cache_init( &fh->cache );
					fh->drive = letter - 'A';
					if (!is_real_floppy || !nofloppyboot) {
						fh->is_media_present = is_floppy_readable(fh);
					}
				}
			}
		} else if(type == DRIVE_CDROM) {
			read_only = true;
			if(is_nt) {
				sprintf(dname,"\\\\.\\%c:",(char)*name);
				h = CreateFile (dname, GENERIC_READ,
											 FILE_SHARE_READ|FILE_SHARE_WRITE,
											 NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
											 NULL);
				if( h != INVALID_HANDLE_VALUE ) {
					fh = new file_handle;
					memset( fh, 0, sizeof(file_handle) );
					fh->h = h;
					fh->is_cdrom = true;
					fh->read_only = read_only;
					fh->drive = toupper(*name) - 'A';
					strcpy( fh->name, name );
					memset( &fh->cache, 0, sizeof(cachetype) );
					cache_init( &fh->cache );
					cache_clear( &fh->cache );
					fh->start_byte = 0;
					if (!nocdrom) {
						fh->is_media_present = is_cdrom_readable(fh);
					}
				}
			} else {
				fh = new file_handle;
				memset( fh, 0, sizeof(file_handle) );
				fh->h = DUMMY_HANDLE;
				fh->is_cdrom = true;
				fh->read_only = read_only;
				fh->drive = toupper(*name) - 'A';
				strcpy( fh->name, name );
				memset( &fh->cache, 0, sizeof(cachetype) );
				cache_init( &fh->cache );
				if (!nocdrom) {
					fh->is_media_present = is_cdrom_readable(fh);
				}
			}
		}
	} else {
		// hard file.
		// Check if write access is allowed, set read-only flag if not
		// Open file/device (for exclusive access, to protect data integrity)

		if(user_wants_ro || is_read_only_path(name)) {
			h = INVALID_HANDLE_VALUE;
		} else {
			h = CreateFile(
				name,
				GENERIC_READ | GENERIC_WRITE,
				0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
			);
		}

		if(h == INVALID_HANDLE_VALUE) {
			read_only = true;
			h = CreateFile(
				name,
				GENERIC_READ,
				FILE_SHARE_READ,
				NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
			);
		}

		if(h != INVALID_HANDLE_VALUE) {
			fh = new file_handle;
			memset( fh, 0, sizeof(file_handle) );
			fh->h = h;
			fh->is_file = true;
			fh->read_only = read_only;
			fh->is_media_present = true;
			strcpy( fh->name, name );
			// Detect header length: if the file size is not a multiple of 512,
			// the remainder at the beginning is considered the header and skipped
			size = (long)GetFileSize(h,NULL);
			if (size == 838484)	// 800K DiskCopy image
				fh->start_byte = 84;
			else
				fh->start_byte = size % 512;
			fh->mount_mode = user_wants_mmode;
			if(fh->mount_mode != MMODE_PERSISTENT) {
				if(undo_init( fh )) {
					if(fh->mount_mode == MMODE_NONPERSISTENT && fh->read_only) {
						if(fh->read_only) {
							// Fake read/write mode. Changes will not be committed to disk.
							fh->read_only = false;
						}
					} else { // MMODE_UNDOABLE, MMODE_UNDOABLE_AUTO
						if(is_read_only_path(name)) {
							// Read-only file. Cannot commit changes anyway.
							fh->mount_mode = MMODE_NONPERSISTENT;
						}
					}
				} else {
					CloseHandle(h);
					delete fh;
					fh = 0;
				}
			}
		}
	}

	if(fh) sys_add_open_list(fh);

	return fh;
}


static int CALLBACK ask_commit_proc( HWND hDlg, unsigned message, WPARAM wParam, LPARAM lParam )
{
	int result = 0;

	switch (message) {
		case WM_INITDIALOG:
			center_window( hDlg );
			SetWindowText( GetDlgItem( hDlg, IDC_COMMIT_FILE ), (LPSTR)lParam );
			SetWindowPos( hDlg, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOSIZE|SWP_NOMOVE );
			SetForegroundWindow( hDlg );
			result = 1;
			break;
		case WM_DESTROY:
			break;
		case WM_COMMAND:
			switch (LOWORD(wParam)) {
				case IDC_YES_ALL:
				case IDC_NO_ALL:
				case IDYES:
				case IDNO:
					EndDialog( hDlg, LOWORD(wParam) );
					result = 1;
					break;
			}
	  	break;
	}
  return(result);
}

static bool yes_all = false;
static bool no_all = false;

static bool is_commit_needed( file_handle *fh )
{
	return
		fh != 0 &&
		fh->is_file &&
		fh->ub.is_dirty() && 
			(!no_all && (fh->mount_mode == MMODE_UNDOABLE || fh->mount_mode == MMODE_UNDOABLE_AUTO) ||
			is_shutting_down && fh->mount_mode == MMODE_UNDOABLE_AUTO);
}

void Sys_commit_if_needed(file_handle *fh)
{
	if(fh && fh->is_file) {

		D(bug("Sys_commit_if_needed(%s)\r\n",fh->name));

		if(fh->mount_mode != MMODE_PERSISTENT) {
			if( is_commit_needed(fh) ) {
				if(fh->ub.get_status() == UB_STATUS_HEALTHY) {
					int answer;
					if(yes_all)
						answer = IDC_YES_ALL;
					else if(is_shutting_down && fh->mount_mode == MMODE_UNDOABLE_AUTO)
						answer = IDYES;
					else
						answer = DialogBoxParam( hInst, "DLG_ASK_COMMIT", GetForegroundWindow(), ask_commit_proc, (LPARAM)fh->name );
					if(answer == IDYES || answer == IDC_YES_ALL) {
						undo_commit( fh );
					}
					if(answer == IDC_NO_ALL) no_all = true;
					if(answer == IDC_YES_ALL) yes_all = true;
				} else {
					MessageBox(
						GetForegroundWindow(),
						"The undo buffer of this volume file is not in a consistent state; maybe you ran out of disk space. To protect the integrity of your data, the changes will not be committed to the volume file.",
						fh->name,
						MB_OK|MB_ICONSTOP
					);
				}
			}
			undo_cleanup( fh );
		}
	}
}

void panic( DWORD address )
{
	bool any_dirty = false;
	open_list_struct *p = open_devices;
	while(p) {
		any_dirty |= is_commit_needed(p->fh);
		p = p->next;
	}

	if(has_own_desktop() && is_screen_inited()) {
		swap_desktop();
	}
	ShowWindow( hMainWnd, SW_MINIMIZE );
	SetForegroundWindow(hMainWnd);
	SetWindowPos( hMainWnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOSIZE|SWP_NOMOVE );
	ShowCursor(TRUE);

	char caption[100];
	wsprintf( caption, "Abnormal termination at 0x%08X", address );
	MessageBox(
		hMainWnd,
		any_dirty
			? "Unhandled exception occurred. Basilisk II is shutting down. You now have a chance to save changes to any undoable volumes if you wish."
			: "Unhandled exception occurred. Basilisk II is shutting down.",
		caption,
		MB_OK|MB_ICONSTOP
	);

	QuitEmulator();
}

/*
 *  Close file/device, delete file handle
 */

void Sys_close(void *arg)
{
	file_handle *fh = (file_handle *)arg;

	D(bug("Sys_close %s\r\n",fh->name));

	if(fh) {
		Sys_commit_if_needed(fh);

		D(bug("Sys_close %s calling sys_remove_open_list\r\n",fh->name));
		sys_remove_open_list(fh);
		if( fh->is_cdrom || fh->is_floppy ) {
			D(bug("Sys_close %s calling cache_final\r\n",fh->name));
			cache_final( &fh->cache );
			SysAllowRemoval( (void *)fh );
		}
		if( !fh->read_only && fh->is_hd && fh->h ) {
			if(is_nt && fh->locked) {
				D(bug("Sys_close %s calling FSCTL_UNLOCK_VOLUME\r\n",fh->name));
				DWORD dwBytesReturned = 0;
				DeviceIoControl(
					fh->h,
					FSCTL_UNLOCK_VOLUME,
					NULL, 0,
					NULL, 0,
					&dwBytesReturned,
					NULL
				);
			}
		}
		if( fh->h != 0 && fh->h != DUMMY_HANDLE) {
			if(fh->is_floppy && !is_nt && fh->locked) {
				D(bug("Sys_close %s calling UnlockLogicalVolumeW95\r\n",fh->name));
				UnlockLogicalVolumeW95( fh->h, fh->drive + 1 );
			}
			D(bug("Sys_close %s calling CloseHandle\r\n",fh->name));
			CloseHandle( fh->h );
			fh->h = 0;
		}

		D(bug("Sys_close %s exit\r\n",fh->name));

		delete fh;
	}
}

size_t nt_hd_read( file_handle *fh, loff_t offset, int count, char *buf )
{
	DWORD bytes_read;
	OVERLAPPED overl;
	char *aux_buffer = 0;
	char *rd_buffer;

	if(!fh->h) return(0);

	if(count == 0) return(0);

	// If not aligned to sector boundary -> must use another buffer
	if( (unsigned long)buf & (HD_ALIGN_MEMORY_SIZE-1) ) {
		aux_buffer = (char *)VirtualAlloc(
				NULL, count, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE );
		if(!aux_buffer) return(0);
		rd_buffer = aux_buffer;
	} else {
		rd_buffer = buf;
	}

	memset( &overl, 0, sizeof(overl) );
	overl.Offset = (DWORD)offset;
	overl.OffsetHigh = (DWORD)(offset >> 32);

  if (!ReadFile (fh->h, rd_buffer, count, &bytes_read, &overl)) {
		bytes_read = count = 0;
	}
	if(aux_buffer) {
		if(bytes_read) memcpy( buf, rd_buffer, bytes_read );
		VirtualFree( aux_buffer, 0, MEM_RELEASE  );
	}
	return(bytes_read);
}

size_t w9x_hd_read( file_handle *fh, loff_t offset, int count, char *buf )
{
	if(fh->is_physical) {
		return( VxdReadHdSectors( fh->drive, (DWORD)offset, count, buf ) );
	} else {
		return( w9x_floppy_read( fh, offset, count, buf ));
	}
}

size_t hd_read( file_handle *fh, loff_t offset, int count, char *buf )
{
	if(is_nt) {
		return( nt_hd_read( fh, offset, count, buf ) );
	} else {
		return( w9x_hd_read( fh, offset, count, buf ) );
	}
}

int nt_hd_write( file_handle *fh, loff_t offset, int count, char *buf )
{
	DWORD bytes_written;
	OVERLAPPED overl;
	char *aux_buffer = 0;
	char *rd_buffer;

	if(!fh->h) return(0);

	if(count == 0) return(0);

	// If not aligned to sector boundary -> must use another buffer
	if( (unsigned long)buf & (HD_ALIGN_MEMORY_SIZE-1) ) {
		aux_buffer = (char *)VirtualAlloc(
				NULL, count, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE );
		if(!aux_buffer) return(0);
		rd_buffer = aux_buffer;
		memcpy( rd_buffer, buf, count );
	} else {
		rd_buffer = buf;
	}

	memset( &overl, 0, sizeof(overl) );
	overl.Offset = (DWORD)offset;
	overl.OffsetHigh = (DWORD)(offset >> 32);

  if (!WriteFile (fh->h, rd_buffer, count, &bytes_written, &overl)) {
		if(GetLastError() == ERROR_WRITE_PROTECT) {
			// AfxMessageBox( "The media is write protected." );
		}
		bytes_written = count = 0;
	}

	if(aux_buffer) {
		VirtualFree( aux_buffer, 0, MEM_RELEASE  );
	}
	return(bytes_written);
}

int w9x_hd_write( file_handle *fh, loff_t offset, int count, char *buf )
{
	if(fh->is_physical) {
		// return( VxdWriteHdSectors( fh->drive, LBA, count, buf ) );
		return( 0 );
	} else {
		return( w9x_floppy_write( fh, offset, count, buf ));
	}
}

int hd_write( file_handle *fh, loff_t offset, int count, char *buf )
{
	if(is_nt) {
		return(nt_hd_write( fh, offset, count, buf ));
	} else {
		return(w9x_hd_write( fh, offset, count, buf ));
	}
}

/*
 *  Read "length" bytes from file/device, starting at "offset", to "buffer",
 *  returns number of bytes read (or 0)
 */

size_t Sys_read(void *arg, void *buffer, loff_t offset, size_t length)
{
	file_handle *fh = (file_handle *)arg;
	DWORD bytes_read = 0;
	LONG low, high;

	if (!fh) return 0;

	D(bug("Sys_read %s offset=%d, length=%d\r\n",fh->name, (int)offset,(int)length));

	offset += fh->start_byte;

	if(fh->is_file) {
		switch( fh->mount_mode ) {
			case MMODE_PERSISTENT:
				low = (LONG)offset;
				high = (LONG)(offset >> 32);
				if( SetFilePointer( fh->h, low, &high, FILE_BEGIN ) != 0xFFFFFFFF ) {
					if(!ReadFile( fh->h, buffer, length, &bytes_read, NULL)) {
						bytes_read = 0;
					}
				}
				break;
			case MMODE_NONPERSISTENT:
			case MMODE_UNDOABLE:
			case MMODE_UNDOABLE_AUTO:
				undoable_read( fh, buffer, offset, length, bytes_read );
				break;
			default:
				D(bug("Unknown mount mode %d.\r\n",fh->mount_mode));
				bytes_read = 0;
				break;
		}
	} else if(fh->is_floppy || fh->is_cdrom || fh->is_hd) {

		// D(bug("Sys_read %s offset=%d, length=%d\r\n",fh->name, (int)offset,(int)length));
		// D(bug("h=%d, start_byte=%d, is_media_present=%d\r\n",(int)fh->h, (int)fh->start_byte,(int)fh->is_media_present));

		size_t bytes_left, try_bytes, got_bytes;
		char *b = (char *)buffer;
		bytes_left = length;
		while(bytes_left) {
			try_bytes = min( bytes_left, 32768 );
			if(fh->is_cdrom) {
				D(bug("Calling cd_read %s offset=%d, length=%d\r\n",fh->name, (int)offset,(int)try_bytes));
				got_bytes = cd_read( fh, &fh->cache, (DWORD)offset, try_bytes, b );
				D(bug("cd_read returned =%d\r\n",(int)got_bytes));
				if(got_bytes != try_bytes) {
					if (!nocdrom) {
						fh->is_media_present = is_cdrom_readable(fh);
					}
				}
			} else if(fh->is_floppy) {
				got_bytes = floppy_read( fh, &fh->cache, (DWORD)offset, try_bytes, (char*)b );
				if(got_bytes != try_bytes) {
					fh->is_media_present = is_floppy_readable(fh);
				}
			} else if(fh->is_hd) {
				got_bytes = hd_read( fh, offset, try_bytes, (char*)b );
			}
			b += got_bytes;
			offset += got_bytes;
			bytes_read += got_bytes;
			bytes_left -= got_bytes;
			if(got_bytes != try_bytes) {
				bytes_left = 0;
			}
		}
		// D(bug("Sys_read returns %d\r\n",(int)bytes_read));
	}

	D(bug("Sys_read returns %d\r\n",(int)bytes_read));

	return(bytes_read);
}


static int CALLBACK ask_commit_now_proc( HWND hDlg, unsigned message, WPARAM wParam, LPARAM lParam )
{
	int result = 0;

	switch (message) {
		case WM_INITDIALOG:
			center_window( hDlg );
			SetWindowText( GetDlgItem( hDlg, IDC_COMMIT_FILE ), (LPSTR)lParam );
			SetWindowPos( hDlg, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOSIZE|SWP_NOMOVE );
			SetForegroundWindow( hDlg );
			result = 1;
			break;
		case WM_DESTROY:
			break;
		case WM_COMMAND:
			switch (LOWORD(wParam)) {
				case IDYES:
				case IDNO:
					EndDialog( hDlg, LOWORD(wParam) == IDYES );
					result = 1;
					break;
			}
	  	break;
	}
  return(result);
}

/*
 *  Write "length" bytes from "buffer" to file/device, starting at "offset",
 *  returns number of bytes written (or 0)
 */

size_t Sys_write(void *arg, void *buffer, loff_t offset, size_t length)
{
	file_handle *fh = (file_handle *)arg;
	DWORD bytes_written = 0;
	LONG low, high;

	D(bug("Sys_write %s, offset=%d, length=%d\r\n",fh->name,(int)offset,(int)length));

	if(!fh) return 0;

	if(fh->read_only) {
		D(bug("Attempt to write to read-only media.\r\n"));
		return 0;
	}

	offset += fh->start_byte;

do_it_again:

	if(fh->is_file) {
		switch( fh->mount_mode ) {
			case MMODE_PERSISTENT:
				low = (LONG)offset;
				high = (LONG)(offset >> 32);
				if( SetFilePointer( fh->h, low, &high, FILE_BEGIN ) != 0xFFFFFFFF ) {
					if(!WriteFile( fh->h, buffer, length, &bytes_written, NULL)) {
						bytes_written = 0;
					}
				}
				break;
			case MMODE_NONPERSISTENT:
			case MMODE_UNDOABLE:
			case MMODE_UNDOABLE_AUTO:
				if(fh->ub.get_status() == UB_STATUS_HEALTHY) {
					undoable_write( fh, buffer, offset, length, bytes_written );
					switch(fh->ub.get_status()) {
						case UB_STATUS_HEALTHY:
							break;
						case UB_STATUS_OUT_OF_SPACE:
							if(fh->mount_mode != MMODE_NONPERSISTENT) {
								if(DialogBoxParam( hInst, "DLG_ASK_COMMIT_NOW", GetForegroundWindow(), ask_commit_now_proc, (LPARAM)fh->name )) {
									fh->ub.set_status(UB_STATUS_HEALTHY);
									undo_commit( fh );
									fh->mount_mode = MMODE_PERSISTENT;
									goto do_it_again;
								}
							} else { // MMODE_NONPERSISTENT
								char msg[512];
								wsprintf( 
									msg, 
									"Out of disk space in writing to undo file of volume \"%s\". Please make sure that you have enough free disk space and restart Basilisk II.",
									fh->name
								);
								MessageBox(
									GetForegroundWindow(),
									msg,
									"Error",
									MB_OK|MB_ICONSTOP
								);
							}
							break;
						default:
							char msg[512];
							wsprintf( msg, "Unknown error in writing to undo file of volume \"%s\". You will not be able to commit the changes for this volume file. Please make sure that you have enough free disk space and restart Basilisk II.", fh->name );
							MessageBox(
								GetForegroundWindow(),
								msg,
								"Error",
								MB_OK|MB_ICONSTOP
							);
					}
				}
				break;
			default:
				D(bug("Unknown mount mode %d.\r\n",fh->mount_mode));
				bytes_written = 0;
				break;
		}
	} else if(fh->is_floppy || fh->is_hd) {
		size_t bytes_left, try_bytes, got_bytes;
		char *b = (char *)buffer;
		bytes_left = length;
		while(bytes_left) {
			try_bytes = min( bytes_left, 32768 );
			if(fh->is_floppy) {
				// could use write-back some day
				cache_clear( &fh->cache );
				got_bytes = floppy_write( fh, (DWORD)offset, try_bytes, (char *)b );
				if(got_bytes != try_bytes) {
					fh->is_media_present = is_floppy_readable(fh);
				}
			} else if(fh->is_hd) {
				got_bytes = hd_write( fh, offset, try_bytes, (char *)b );
			}
			b += got_bytes;
			offset += got_bytes;
			bytes_written += got_bytes;
			bytes_left -= got_bytes;
			if(got_bytes != try_bytes) {
				bytes_left = 0;
			}
		}
	}

	if(bytes_written != length) {
		D(bug("Sys_write(%ld,%ld) failed.\r\n",(long)offset,(long)length));
	}

	return(bytes_written);
}

/*
 *  Return size of file/device (minus header)
 */

loff_t SysGetFileSize(void *arg)
{
	off_t length = 0;
	LONGLONG real_len = 0;
	file_handle *fh = (file_handle *)arg;

	D(bug("SysGetFileSize %s\r\n",fh->name));

	if (!fh)
		return true;

	if(fh->h) {
		if (fh->is_file) {
			real_len = (LONGLONG)GetFileSize(fh->h,NULL);
		} else if (fh->is_floppy && fh->is_real_floppy) {
			real_len = (LONGLONG)80 * 2 * 18 * 512;
		} else if (fh->is_cdrom) {
			// test
			real_len = (LONGLONG)0x28A00000;
		} else if (fh->is_hd || fh->is_floppy) {
			// Note: if pure mac disk, cluster info is not available
			if(win_os_old) {
				DWORD SectorsPerCluster;
				DWORD BytesPerSector;
				DWORD NumberOfFreeClusters;
				DWORD TotalNumberOfClusters;
				if(GetDiskFreeSpace( fh->name,
					&SectorsPerCluster,
					&BytesPerSector,
					&NumberOfFreeClusters,
					&TotalNumberOfClusters ))
				{
					real_len = (LONGLONG)TotalNumberOfClusters*SectorsPerCluster*BytesPerSector;
				}
			} else if(fh->is_physical) {
				DISK_GEOMETRY g;
				DWORD dwBytesReturned;
				if(DeviceIoControl(
					fh->h,
					IOCTL_DISK_GET_DRIVE_GEOMETRY,
					NULL, 0,
					&g, sizeof(g),
					&dwBytesReturned,
					NULL
				) && dwBytesReturned == sizeof(g) )
				{
					real_len = ( (LONGLONG)g.Cylinders.QuadPart *
											 (LONGLONG)g.TracksPerCylinder *
											 (LONGLONG)g.SectorsPerTrack *
											 (LONGLONG)g.BytesPerSector );
				}
			} else {
				if(pfnGetDiskFreeSpaceEx) {
					ULARGE_INTEGER FreeBytesAvailableToCaller; // Note: quotas.
					ULARGE_INTEGER TotalNumberOfBytes;
					ULARGE_INTEGER TotalNumberOfFreeBytes;

					if(pfnGetDiskFreeSpaceEx( fh->name,
						&FreeBytesAvailableToCaller,
						&TotalNumberOfBytes,
						&TotalNumberOfFreeBytes))
					{
						real_len = (LONGLONG)TotalNumberOfBytes.QuadPart;
					}
				} else {
					DWORD SectorsPerCluster;
					DWORD BytesPerSector;
					DWORD NumberOfFreeClusters;
					DWORD TotalNumberOfClusters;
					if(GetDiskFreeSpace( fh->name,
						&SectorsPerCluster,
						&BytesPerSector,
						&NumberOfFreeClusters,
						&TotalNumberOfClusters ))
					{
						real_len = (LONGLONG)TotalNumberOfClusters*SectorsPerCluster*BytesPerSector;
					}
				}
			}
		}
	}

#if DEBUG
if(sizeof(off_t) != 4) D(bug("off_t size changed, update code\r\n"));
#endif

	return real_len;
}

/*
 *  Eject volume (if applicable)
 */

void SysEject(void *arg)
{
	DWORD dwBytesReturned;
	file_handle *fh = (file_handle *)arg;

	D(bug("SysEject %s\r\n",fh->name));

	if (!fh) return;

	if (fh->is_floppy) {
		if(fh->is_media_present) {
			fh->is_media_present = false;
			if(is_nt) {
				DeviceIoControl(
					fh->h,
					IOCTL_STORAGE_EJECT_MEDIA,
					NULL, 0,
					NULL, 0,
					&dwBytesReturned,
					NULL
				);
				/*
				if(fh->h && fh->h != INVALID_HANDLE_VALUE) {
					CloseHandle(fh->h);
					fh->h = 0;
				}
				*/
			} else {
				EjectMedia_w9x( fh->drive + 1 );
			}
			/*
			char msg[300];
			wsprintf(
				msg,
				"The floppy was ejected from drive \"%c:\".\r\n"
				"Press Control-Shift-F11 to reload the floppy disk.",
				(char)toupper(*fh->name)
			);
			WarningAlert( msg );
			*/
		}
		cache_clear( &fh->cache );
		fh->start_byte = 0;
	} else if (fh->is_cdrom) {
		if(!fh->h) return;
		fh->is_media_present = false;
		if(is_nt) {

			// Commented out because there was some problems, but can't remember
			// exactly ... need to find out

			// EjectVolume(toupper(*fh->name),false);

			// Preventing is cumulative, try to make sure it's indeed released now
			for(int i=0; i<10; i++) PreventRemovalOfVolume(fh->h,false);

			if (!nocdrom) {
				DeviceIoControl(
					fh->h,
					IOCTL_STORAGE_EJECT_MEDIA,
					NULL, 0,
					NULL, 0,
					&dwBytesReturned,
					NULL
				);
			}
		} else {
			EjectMedia_w9x( fh->drive + 1 );
		}
		cache_clear( &fh->cache );
		fh->start_byte = 0;
	}
}

/*
 *  Format volume (if applicable)
 */

bool SysFormat(void *arg)
{
	file_handle *fh = (file_handle *)arg;

	D(bug("SysFormat %s\r\n",fh->name));

	if (!fh) return false;

	if(fh->read_only) return false;

	return true;
}


/*
 *  Check if file/device is read-only (this includes the read-only flag on Sys_open())
 */

bool SysIsReadOnly(void *arg)
{
	file_handle *fh = (file_handle *)arg;

	bool result = true;

	D(bug("SysIsReadOnly %s\r\n",fh->name));

	if (fh) result = fh->read_only;

	return result;
}


/*
 *  Check if the given file handle refers to a fixed or a removable disk
 */

bool SysIsFixedDisk(void *arg)
{
	file_handle *fh = (file_handle *)arg;

	D(bug("SysIsFixedDisk %s\r\n",fh->name));

	if (!fh)
		return true;

	if (fh->is_file || fh->is_hd)
		return true;
	else if (fh->is_floppy || fh->is_cdrom)
		return false;
	else
		return true;
}


/*
 *  Check if a disk is inserted in the drive (always true for files)
 */

bool SysIsDiskInserted(void *arg)
{
	file_handle *fh = (file_handle *)arg;
	bool result = false;

	D(bug("SysIsDiskInserted %s\r\n",fh->name));

	if (!fh) return false;

	if (fh->is_file || fh->is_hd) {
		result = true;
	} else if (fh->is_floppy) {
		if(poll_media || /*some_media_arrived ||*/ some_media_removed) {
			if (!nofloppyboot || HasMacStarted()) {
				fh->is_media_present = is_floppy_readable(fh);
			}
			if(fh->is_media_present && !is_nt){
				UnlockLogicalVolumeW95( fh->h, fh->drive + 1 );
				if(LockLogicalVolumeW95( fh->h, fh->drive + 1, 0, 0) ) {
					fh->locked = true;
				} else {
					if(fh->drive < 2) { // A:, B:
						// This just means that our previous lock is valid.
					} else {
						fh->read_only = true;
					}
				}
			}
			// some_media_arrived = false;
			some_media_removed = false;
		}
		result = fh->is_media_present;
	} else if (fh->is_cdrom && !nocdrom) {
		if(poll_media || /*some_media_arrived ||*/ some_media_removed) {
			if(is_nt) {
				fh->is_media_present = is_cdrom_readable(fh);
			} else {
				if(/*some_media_arrived ||*/ some_media_removed) {
					fh->is_media_present = is_cdrom_readable(fh);
					// some_media_arrived = false;
					some_media_removed = false;
				}
			}
		}
		result = fh->is_media_present;
	}
	D(bug("SysIsDiskInserted = %d\r\n",(int)result));
	return(result);
}


/*
 *  Prevent medium removal (if applicable)
 */

void SysPreventRemoval(void *arg)
{
	file_handle *fh = (file_handle *)arg;

	D(bug("SysPreventRemoval %s\r\n",fh->name));

	if (!fh) return;

	if (fh->is_cdrom) {
		if(!fh->h) return;
		if(is_nt) {
			PreventRemovalOfVolume(fh->h,true);
		}
	}
}


/*
 *  Allow medium removal (if applicable)
 */

void SysAllowRemoval(void *arg)
{
	file_handle *fh = (file_handle *)arg;

	D(bug("SysAllowRemoval %s\r\n",fh->name));

	if (!fh) return;

	if (fh->is_cdrom) {
		if(!fh->h) return;
		if(is_nt) {
			for( int i=0; i<10; i++) PreventRemovalOfVolume(fh->h,false);
		}
	}
}


// TOC and CDDA for NT only


/*
 *  Read CD-ROM TOC (binary MSF format, 804 bytes max.)
 */

bool SysCDReadTOC(void *arg, uint8 *toc)
{
	file_handle *fh = (file_handle *)arg;
	DWORD dwBytesReturned = 0;

	D(bug("SysCDReadTOC %s\r\n",fh->name));

	if (!fh) return false;
	if(!is_nt) return false;

	// to ease viewing in db
	PCDROM_TOC ptoc = (PCDROM_TOC)toc;

	if(!fh->h) return false;

	if(DeviceIoControl(fh->h,
		IOCTL_CDROM_READ_TOC,
		NULL, 0,
		toc, min(sizeof(CDROM_TOC),804),
		&dwBytesReturned,
		NULL))
	{
		D(bug("SysCDReadTOC success\r\n"));
		return true;
	}
	D(bug("SysCDReadTOC failed\r\n"));
	return false;
}


/*
 *  Read CD-ROM position data (Sub-Q Channel, 16 bytes, see SCSI standard)
 */

bool SysCDGetPosition(void *arg, uint8 *pos)
{
	file_handle *fh = (file_handle *)arg;
	if (!fh) return false;
	if(!is_nt) return false;
	if(!fh->h) return false;

	DWORD dwBytesReturned = 0;
	SUB_Q_CHANNEL_DATA q_data;
	CDROM_SUB_Q_DATA_FORMAT q_format;

	q_format.Format = IOCTL_CDROM_CURRENT_POSITION;
	q_format.Track = 0; // used only by ISRC reads

	if(DeviceIoControl(fh->h,
		IOCTL_CDROM_READ_Q_CHANNEL,
		&q_format, sizeof(CDROM_SUB_Q_DATA_FORMAT),
		&q_data, sizeof(SUB_Q_CHANNEL_DATA),
		&dwBytesReturned,
		NULL))
	{
		memcpy( pos, &q_data.CurrentPosition, sizeof(SUB_Q_CURRENT_POSITION) );
		D(bug("SysCDGetPosition success\r\n"));
		return true;
	} else {
		D(bug("SysCDGetPosition failed, error code=%d\r\n",GetLastError()));
		return false;
	}
}


/*
 *  Play CD audio
 */

bool SysCDPlay(void *arg, uint8 start_m, uint8 start_s, uint8 start_f, uint8 end_m, uint8 end_s, uint8 end_f)
{
	file_handle *fh = (file_handle *)arg;
	if (!fh) return false;
	if(!is_nt) return false;
	if(!fh->h) return false;

	DWORD dwBytesReturned = 0;
	CDROM_PLAY_AUDIO_MSF msf;

	D(bug("SysCDPlay %d,%d,%d, %d,%d,%d\r\n",(int)start_m,(int)start_s,(int)start_f,(int)end_m,(int)end_s,(int)end_f));

  msf.StartingM = start_m;
  msf.StartingS = start_s;
  msf.StartingF = start_f;
  msf.EndingM = end_m;
  msf.EndingS = end_s;
  msf.EndingF = end_f;

	if(DeviceIoControl(fh->h,
		IOCTL_CDROM_PLAY_AUDIO_MSF,
		&msf, sizeof(CDROM_PLAY_AUDIO_MSF),
		NULL, 0,
		&dwBytesReturned,
		NULL))
	{
		D(bug("SysCDPlay success\r\n"));
		return true;
	} else {
		D(bug("SysCDPlay failed\r\n"));
		return false;
	}
}


/*
 *  Pause CD audio
 */

bool SysCDPause(void *arg)
{
	file_handle *fh = (file_handle *)arg;
	if (!fh) return false;
	if(!is_nt) return false;
	if(!fh->h) return false;

	DWORD dwBytesReturned = 0;
	if(DeviceIoControl(fh->h,IOCTL_CDROM_PAUSE_AUDIO, 0, 0, 0, 0, &dwBytesReturned, 0)) {
		D(bug("SysCDPause success\r\n"));
		return true;
	} else {
		D(bug("SysCDPause failed\r\n"));
		return false;
	}
}


/*
 *  Resume paused CD audio
 */

bool SysCDResume(void *arg)
{
	file_handle *fh = (file_handle *)arg;
	if (!fh) return false;
	if(!is_nt) return false;
	if(!fh->h) return false;

	DWORD dwBytesReturned = 0;
	if(DeviceIoControl(fh->h,IOCTL_CDROM_RESUME_AUDIO, 0, 0, 0, 0, &dwBytesReturned, 0)) {
		D(bug("SysCDResume success\r\n"));
		return true;
	} else {
		D(bug("SysCDResume failed\r\n"));
		return false;
	}
}


/*
 *  Stop CD audio
 */

extern bool SysCDStop(void *arg, uint8 lead_out_m, uint8 lead_out_s, uint8 lead_out_f)
{
	file_handle *fh = (file_handle *)arg;
	if (!fh) return false;
	if(!is_nt) return false;
	if(!fh->h) return false;

	DWORD dwBytesReturned = 0;
	if(DeviceIoControl(fh->h,IOCTL_CDROM_STOP_AUDIO, 0, 0, 0, 0, &dwBytesReturned, 0)) {
		D(bug("SysCDStop success\r\n"));
		return true;
	} else {
		D(bug("SysCDStop failed\r\n"));
		return false;
	}
}


/*
 *  Perform CD audio fast-forward/fast-reverse operation starting from specified address
 */

bool SysCDScan(void *arg, uint8 start_m, uint8 start_s, uint8 start_f, bool reverse)
{
	file_handle *fh = (file_handle *)arg;
	if (!fh) return false;
	if(!is_nt) return false;
	if(!fh->h) return false;

	DWORD dwBytesReturned = 0;
	CDROM_SEEK_AUDIO_MSF msf;

	// reverse?

	D(bug("SysCDScan %d,%d,%d,%d\r\n",(int)start_m, (int)start_s, (int)start_f, (int)reverse));

  msf.M = start_m;
  msf.S = start_s;
  msf.F = start_f;

	if(DeviceIoControl(fh->h,
		IOCTL_CDROM_SEEK_AUDIO_MSF,
		&msf, sizeof(CDROM_SEEK_AUDIO_MSF),
		NULL, 0,
		&dwBytesReturned,
		NULL))
	{
		D(bug("SysCDScan success\r\n"));
		return true;
	} else {
		D(bug("SysCDScan failed\r\n"));
		return false;
	}
}


/*
 *  Set CD audio volume (0..255 each channel)
 */

void SysCDSetVolume(void *arg, uint8 left, uint8 right)
{
	file_handle *fh = (file_handle *)arg;
	if (!fh) return;
	if(!is_nt) return;
	if(!fh->h) return;

	DWORD dwBytesReturned = 0;
	VOLUME_CONTROL vc;

	vc.PortVolume[0] = left;
	vc.PortVolume[1] = right;
	vc.PortVolume[2] = left;
	vc.PortVolume[3] = right;

	D(bug("SysCDSetVolume %d,%d\r\n",(int)left,(int)right));

	DeviceIoControl(fh->h,
		IOCTL_CDROM_SET_VOLUME,
		&vc, sizeof(VOLUME_CONTROL),
		NULL, 0,
		&dwBytesReturned,
		NULL);
}


/*
 *  Get CD audio volume (0..255 each channel)
 */

void SysCDGetVolume(void *arg, uint8 &left, uint8 &right)
{
	file_handle *fh = (file_handle *)arg;
	if (!fh) return;

	left = 0;
	right = 0;

	if(!is_nt) return;
	if(!fh->h) return;

	DWORD dwBytesReturned = 0;
	VOLUME_CONTROL vc;

	memset( &vc, 0, sizeof(vc) );

	if(DeviceIoControl(fh->h,
		IOCTL_CDROM_GET_VOLUME,
		NULL, 0,
		&vc, sizeof(VOLUME_CONTROL),
		&dwBytesReturned,
		NULL))
	{
		left = vc.PortVolume[0];
		right = vc.PortVolume[1];
		D(bug("SysCDGetVolume success %d,%d,%d,%d\r\n",(int)vc.PortVolume[0],(int)vc.PortVolume[1],(int)vc.PortVolume[2],(int)vc.PortVolume[3]));
	} else {
		D(bug("SysCDGetVolume failed\r\n"));
	}
}
