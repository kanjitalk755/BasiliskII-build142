/*
 *  undo_windows.cpp
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
#include "main.h"
#include "prefs.h"
#include "user_strings.h"
#include "cpu_emulation.h"
#include "macos_util.h"
#include "sys.h"
#include "errno.h"
#include "winioctl.h"
#include "main_windows.h"
#include "sys_windows.h"
#include "undo_windows.h"
#include "undo_buffer.h"

#define DEBUG 0
#include "debug.h"

void undoable_write(
	file_handle *fh,
	void *buffer,
	loff_t offset,
	size_t length,
	DWORD &bytes_written
)
{
	D(bug("undoable_write(%s,buffer,0x%X,0x%X)\r\n", fh->name, (int)offset, (int)length));

	if(fh->ub.get_status() != UB_STATUS_HEALTHY) return;

	bytes_written = 0;

	int nblocks_left = (int)(length / UB_BLOCK_SIZE);

#if MULTI_BLOCK_IO
	int nblocks_written = 0;
	while( nblocks_left > 0 ) {
		if(fh->ub.put_n( buffer, offset, nblocks_left, nblocks_written ) && nblocks_written) {
			int bcount = nblocks_written*UB_BLOCK_SIZE;
			nblocks_left -= nblocks_written;
			bytes_written += bcount;
			offset += bcount;
			buffer = (void *)( (uint32)buffer + bcount );
		} else {
			break;
		}
	}
#else //MULTI_BLOCK_IO
	for( int i=0; i<nblocks_left; i++ ) {
		if(fh->ub.put( buffer, offset )) {
			bytes_written += UB_BLOCK_SIZE;
			offset += UB_BLOCK_SIZE;
			buffer = (void *)( (uint32)buffer + UB_BLOCK_SIZE );
		} else {
			break;
		}
	}
#endif //MULTI_BLOCK_IO
	D(bug("undoable_write(%s) returns 0x%X\r\n", fh->name, (int)bytes_written));
}

void undoable_read(
	file_handle *fh,
	void *buffer,
	loff_t offset,
	size_t length,
	DWORD &bytes_read
)
{
	D(bug("undoable_read(%s,buffer,0x%X,0x%X)\r\n", fh->name, (int)offset, (int)length));

	bytes_read = 0;

	int nblocks_left = (int)(length / UB_BLOCK_SIZE);

#if MULTI_BLOCK_IO
	while(nblocks_left > 0) {
		int blocks_read = 0, skip_blocks = 0;
		if(fh->ub.get_n( buffer, offset, nblocks_left, blocks_read, skip_blocks ) && blocks_read) {
			D(bug("undoable_read(%s) got %d blocks from the undo file\r\n", blocks_read, fh->name));
		} else {
			LONG low = (LONG)offset;
			LONG high = (LONG)(offset >> 32);
			if( SetFilePointer( fh->h, low, &high, FILE_BEGIN ) != 0xFFFFFFFF ) {
				DWORD try_bytes = (DWORD)skip_blocks * UB_BLOCK_SIZE;
				DWORD got_bytes = 0;
				if(ReadFile( fh->h, buffer, try_bytes, &got_bytes, NULL) && got_bytes == try_bytes) {
					blocks_read = skip_blocks;
				} else {
					break;
				}
			}
		}
		nblocks_left -= blocks_read;
		int bcount = blocks_read*UB_BLOCK_SIZE;
		bytes_read += bcount;
		offset += bcount;
		buffer = (void *)( (uint32)buffer + bcount );
	}
#else //MULTI_BLOCK_IO
	for( int i=0; i<nblocks_left; i++ ) {
		if(fh->ub.get( buffer, offset )) {
			D(bug("undoable_read(%s) got a block from the undo file\r\n", fh->name));
			bytes_read += UB_BLOCK_SIZE;
		} else {
			LONG low = (LONG)offset;
			LONG high = (LONG)(offset >> 32);
			if( SetFilePointer( fh->h, low, &high, FILE_BEGIN ) != 0xFFFFFFFF ) {
				DWORD got_bytes;
				if(ReadFile( fh->h, buffer, UB_BLOCK_SIZE, &got_bytes, NULL)) {
					bytes_read += got_bytes;
				} else {
					break;
				}
			}
		}
		offset += UB_BLOCK_SIZE;
		buffer = (void *)( (uint32)buffer + UB_BLOCK_SIZE );
	}
#endif //MULTI_BLOCK_IO
	D(bug("undoable_read(%s) returns 0x%X\r\n", fh->name, (int)bytes_read));
}

static void undo_make_path( const char *base_name, char *path )
{
	strcpy( path, base_name );
	strcat( path, ".undo" );
}

static void undo_make_alternate_path( const char *base_name, char *path )
{
	*path = 0;
	char *p = strrchr( base_name, '\\' );
	if(p) {
		GetTempPath( _MAX_PATH, path );
		if(*path && path[strlen(path)-1] != '\\') strcat( path, "\\" );
		strcat( path, p+1 );
		strcat( path, ".undo" );
	}
}

bool undo_init( file_handle *fh )
{
	bool result = false;
	char path[_MAX_PATH ];
	char path2[_MAX_PATH ];

	if(!fh) return false;

	undo_make_path( fh->name, path );

	D(bug("undo_init %s, %s\r\n", fh->name, path));

	bool open_ok = fh->ub.open( path );
	if(!open_ok) {
		strcpy( path2, path ); // save it for possible error message
		D(bug("ub.open %s failed, modifying file name\r\n", path));
		undo_make_alternate_path( fh->name, path );
		open_ok = fh->ub.open( path );
	}

	if(open_ok) {
		D(bug("ub.open %s ok\r\n", path));
		result = true;
	} else {
		char msg[1024];
		D(bug("ub.open %s failed\r\n", path));
		wsprintf( 
			msg,
			"Failed to create undo file (tried two paths \"%s\" and \"%s\"); volume not mounted.",
			path2,
			path
		);
		MessageBox(
			GetForegroundWindow(),
			msg,
			fh->name,
			MB_OK|MB_ICONSTOP
		);
	}
	return result;
}

void undo_commit( file_handle *fh )
{
	D(bug("undo_commit %s\r\n", fh->name));

	if(fh && fh->ub.is_dirty()) {
		if(fh->ub.get_status() == UB_STATUS_HEALTHY) {
			ub_stats stats;
			if(!fh->ub.commit( fh->h, stats )) {
				MessageBox(
					GetForegroundWindow(),
					"Failed to commit the changes. The volume file may be corrupted.",
					fh->name,
					MB_OK|MB_ICONSTOP
				);
			} else {
				D(bug("undo_commit %s ok, %d bytes\r\n", fh->name, (int)stats.total_bytes_committed));
			}
		}
	}
}

void undo_cleanup( file_handle *fh )
{
	D(bug("undo_cleanup %s\r\n", fh->name));

	if(fh) fh->ub.close();
}
