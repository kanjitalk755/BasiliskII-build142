/*
 *  undo_buffer.cpp
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
#include "progress.h"
#include "winerror.h"

#define DEBUG 0
#include "debug.h"

#define INVALID_OFFSET (loff_t)0xFFFFFFFFFFFFFFFF

undo_buffer::undo_buffer()
{
	for( int i=0; i<UB_MAX_BUCKETS; i++ ) { m_table[i] = 0; }
	m_dirty = false;
	*m_path = 0;
	m_file = INVALID_HANDLE_VALUE;
	m_next_offset = 0;
	m_status = UB_STATUS_HEALTHY;
}

undo_buffer::~undo_buffer()
{
	delete_entries();
	close();
	m_dirty = false;
}

void undo_buffer::delete_entries()
{
	for( int i=0; i<UB_MAX_BUCKETS; i++ ) {
		ub_entry *e = m_table[i];
		while(e) {
			ub_entry *next = e->next;
			delete e;
			e = next;
		}
		m_table[i] = 0;
	}
	m_next_offset = 0;
}

bool undo_buffer::open( const char *path )
{
	if(m_file != INVALID_HANDLE_VALUE) close();

	strcpy( m_path, path );

	if(exists( m_path )) DeleteFile( m_path );

	m_file = CreateFile(
		m_path,
		GENERIC_READ | GENERIC_WRITE,
		0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL
	);

	m_next_offset = 0;

	return m_file != INVALID_HANDLE_VALUE;
}

bool undo_buffer::close()
{
	if(m_file != INVALID_HANDLE_VALUE) {
		CloseHandle(m_file);
		m_file = INVALID_HANDLE_VALUE;
		DeleteFile( m_path );
	}
	return true;
}

ub_entry *undo_buffer::find_entry( int hash_inx, loff_t offset )
{
	ub_entry *e = m_table[hash_inx];
	while( e && e->offset_mac != offset ) e = e->next;
	return e;
}

ub_entry *undo_buffer::new_entry( int hash_inx, loff_t offset_mac, loff_t offset_host )
{
	ub_entry *e = new ub_entry;
	if(e) {
		e->offset_mac = offset_mac;
		e->offset_host = offset_host;
#if ADD_TO_HEAD
		e->next = m_table[hash_inx];
		m_table[hash_inx] = e;
#else
		// This makes faster commit possible.
		e->next = 0;
		ub_entry *f = m_table[hash_inx];
		if(f) {
			while(f->next) f = f->next;
			f->next = e;
		} else {
			m_table[hash_inx] = e;
		}
#endif
	}
	return e;
}

// Try to keep some consecutive entries in the same bucket.
// This increases (minimally) access times, but helps
// in reducing the commmit time. Trying for 16kB blocks.
#define JOIN_BLOCK_COUNT 32

// The constants are power of two, the compiler can optimize this.
static inline int hash_func( loff_t offset )
{
	return (int)( (offset / UB_BLOCK_SIZE / JOIN_BLOCK_COUNT) % UB_MAX_BUCKETS );
}

#if MULTI_BLOCK_IO
bool undo_buffer::put_n( void *buffer, loff_t offset, int blocks, int &blocks_written )
{
	bool result = false;

	blocks_written = 0;

	if(m_file != INVALID_HANDLE_VALUE) {
		int hash_inx = hash_func(offset);

		ub_entry *e = find_entry( hash_inx, offset );

		if(e) {
			LONG low = (LONG)e->offset_host;
			LONG high = (LONG)(e->offset_host >> 32);
			if( SetFilePointer( m_file, low, &high, FILE_BEGIN ) != 0xFFFFFFFF ) {
				blocks_written = 1;
				while( e && e->next && 
							 blocks_written < blocks &&
							 e->offset_host+UB_BLOCK_SIZE == e->next->offset_host &&
							 e->offset_mac+UB_BLOCK_SIZE == e->next->offset_mac )
				{
					blocks_written++;
					e = e->next;
				}

				D(bug("undo_buffer::put_n() replacing %d of %d blocks\r\n", blocks_written, blocks));
				
				DWORD got_bytes;
				if(WriteFile( m_file, buffer, blocks_written*UB_BLOCK_SIZE, &got_bytes, NULL)) {
					result = got_bytes == (DWORD)blocks_written*UB_BLOCK_SIZE;
				} else {
					blocks_written = 0;
				}
			}
		} else {
			e = new_entry( hash_inx, offset, m_next_offset );
			if(e) {
				LONG low = (LONG)e->offset_host;
				LONG high = (LONG)(e->offset_host >> 32);
				if( SetFilePointer( m_file, low, &high, FILE_BEGIN ) != 0xFFFFFFFF ) {
					blocks_written = 1;
					while( blocks_written < blocks && 
								 hash_inx == hash_func( offset+blocks_written*UB_BLOCK_SIZE ) &&
								 !find_entry( hash_inx, offset+blocks_written*UB_BLOCK_SIZE )
							 )
					{
						blocks_written++;
					}

					D(bug("undo_buffer::put_n() writing %d of %d blocks\r\n", blocks_written, blocks));

					DWORD got_bytes = 0;
					if(WriteFile( m_file, buffer, blocks_written*UB_BLOCK_SIZE, &got_bytes, NULL)) {
						result = got_bytes == (DWORD)blocks_written*UB_BLOCK_SIZE;
						if(result) {
							for( int i=1; i<blocks_written; i++ ) {
								(void)new_entry( hash_inx, offset + i*UB_BLOCK_SIZE, m_next_offset+i*UB_BLOCK_SIZE );
							}
						}
						m_next_offset += got_bytes;
					}
				}
				if(!result) {
					e->offset_host = INVALID_OFFSET;
					e->offset_mac = INVALID_OFFSET;
					DWORD err = GetLastError();
					char expl[100];
					if(err == ERROR_DISK_FULL) {
						m_status = UB_STATUS_OUT_OF_SPACE;
						strcpy( expl, "Out of disk space error" );
					} else {
						m_status = UB_STATUS_UNKNOWN_CORRUPTION;
						wsprintf( expl, "Error code %d", err );
					}
					D(bug("undo_buffer::put(): %s in writing to undo file \"%s\".", expl, m_path));
				}
			}
		}
	}
	if(result) m_dirty = true;

	return result;
}

bool undo_buffer::get_n( void *buffer, loff_t offset, int blocks, int &blocks_read, int &skip_blocks )
{
	bool result = false;

	blocks_read = skip_blocks = 0;

	if(m_file != INVALID_HANDLE_VALUE) {
		int hash_inx = hash_func(offset);

		ub_entry *e = find_entry( hash_inx, offset );

		if(e) {
			LONG low = (LONG)e->offset_host;
			LONG high = (LONG)(e->offset_host >> 32);
			if( SetFilePointer( m_file, low, &high, FILE_BEGIN ) != 0xFFFFFFFF ) {

				blocks_read = 1;
				while( e && e->next && 
							 blocks_read < blocks &&
							 e->offset_host+UB_BLOCK_SIZE == e->next->offset_host &&
							 e->offset_mac+UB_BLOCK_SIZE == e->next->offset_mac )
				{
					blocks_read++;
					e = e->next;
				}

				D(bug("undo_buffer::get_n() reading %d of %d blocks\r\n", blocks_read, blocks));
				
				DWORD try_bytes = (DWORD)blocks_read*UB_BLOCK_SIZE;
				DWORD got_bytes;
				if(ReadFile( m_file, buffer, try_bytes, &got_bytes, NULL)) {
					result = got_bytes == try_bytes;
				} else {
					blocks_read = 0;
				}
			}
		}
	}

	if(!result) {
		skip_blocks = 1;
		for( int i=1; i<blocks; i++ ) {
			offset += UB_BLOCK_SIZE;
			if(find_entry( hash_func(offset), offset )) {
				break;
			} else {
				skip_blocks++;
			}
		}
	}

	return result;
}
#else //!MULTI_BLOCK_IO
bool undo_buffer::put( void *buffer, loff_t offset )
{
	bool result = false;

	if(m_file != INVALID_HANDLE_VALUE) {
		int hash_inx = hash_func(offset);

		ub_entry *e = find_entry( hash_inx, offset );

		if(e) {
			LONG low = (LONG)e->offset_host;
			LONG high = (LONG)(e->offset_host >> 32);
			if( SetFilePointer( m_file, low, &high, FILE_BEGIN ) != 0xFFFFFFFF ) {
				DWORD got_bytes;
				if(WriteFile( m_file, buffer, UB_BLOCK_SIZE, &got_bytes, NULL)) {
					result = got_bytes == UB_BLOCK_SIZE;
				}
			}
		} else {
			e = new_entry( hash_inx, offset, m_next_offset );
			if(e) {
				LONG low = (LONG)e->offset_host;
				LONG high = (LONG)(e->offset_host >> 32);
				if( SetFilePointer( m_file, low, &high, FILE_BEGIN ) != 0xFFFFFFFF ) {
					DWORD got_bytes;
					if(WriteFile( m_file, buffer, UB_BLOCK_SIZE, &got_bytes, NULL)) {
						result = got_bytes == UB_BLOCK_SIZE;
						m_next_offset += UB_BLOCK_SIZE;
					}
				}
				if(!result) {
					e->offset_host = INVALID_OFFSET;
					e->offset_mac = INVALID_OFFSET;
					DWORD err = GetLastError();
					char expl[100];
					if(err == ERROR_DISK_FULL) {
						m_status = UB_STATUS_OUT_OF_SPACE;
						strcpy( expl, "Out of disk space error" );
					} else {
						m_status = UB_STATUS_UNKNOWN_CORRUPTION;
						wsprintf( expl, "Error code %d", err );
					}
					D(bug("undo_buffer::put(): %s in writing to undo file \"%s\".", expl, m_path));
				}
			}
		}
	}
	if(result) m_dirty = true;

	return result;
}

bool undo_buffer::get( void *buffer, loff_t offset )
{
	bool result = false;

	if(m_file != INVALID_HANDLE_VALUE) {
		int hash_inx = hash_func(offset);

		ub_entry *e = find_entry( hash_inx, offset );

		if(e) {
			LONG low = (LONG)e->offset_host;
			LONG high = (LONG)(e->offset_host >> 32);
			if( SetFilePointer( m_file, low, &high, FILE_BEGIN ) != 0xFFFFFFFF ) {
				DWORD got_bytes;
				if(ReadFile( m_file, buffer, UB_BLOCK_SIZE, &got_bytes, NULL)) {
					result = got_bytes == UB_BLOCK_SIZE;
				}
			}
		}
	}

	return result;
}
#endif //MULTI_BLOCK_IO

int undo_buffer::count_entries()
{
	int count = 0;

	for( int i=0; i<UB_MAX_BUCKETS; i++ ) {
		ub_entry *e = m_table[i];
		while(e) {
			if(e->offset_host != INVALID_OFFSET && e->offset_mac != INVALID_OFFSET) {
				count++;
			}
			e = e->next;
		}
	}

	return count;
}

#if DEBUG
void undo_buffer::dump()
{
	D(bug("Dumping %d undo nodes\r\n", UB_MAX_BUCKETS));

	for( int i=0; i<UB_MAX_BUCKETS; i++ ) {
		ub_entry *e = m_table[i];
		int count = 0;
		while(e) {
			if(e->offset_host != INVALID_OFFSET && e->offset_mac != INVALID_OFFSET) {
				count++;
			} else {
				D(bug("Invalid block at %d,%d\r\n", i, count));
			}
			e = e->next;
		}
		D(bug("Block %d: %d entries\r\n", i, count));
	}
}
#endif //DEBUG

bool undo_buffer::commit( HANDLE target_file, ub_stats &stats )
{
	stats.total_bytes_committed = 0;

	if( m_status != UB_STATUS_HEALTHY ||
			m_file == INVALID_HANDLE_VALUE ||
			target_file == INVALID_HANDLE_VALUE )
	{
		return false;
	}

	bool result = true;

	int buffer_blocks = JOIN_BLOCK_COUNT;
	char *buffer = new char [buffer_blocks * UB_BLOCK_SIZE];

	if(!buffer) {
		MessageBox( GetForegroundWindow(), "undo_buffer::commit() failed to allocate scratch buffer", "Panic", MB_OK|MB_ICONSTOP );
		return false;
	}

#if DEBUG
	dump();
#endif

	SetCursor( LoadCursor( 0, IDC_WAIT ) );
	char xplain[1024];
	wsprintf( 
		xplain,
		"Updating %d bytes to the volume file. Please wait.",
		count_entries() * UB_BLOCK_SIZE
	);
	progress_c progress( 
		UB_MAX_BUCKETS, 
		m_path,
		xplain
	);
	for( int i=0; i<UB_MAX_BUCKETS; i++ ) {
		if( (i & 7) == 0 ) progress.set( i );
		ub_entry *e = m_table[i];

		while(result && e) {
			if(e->offset_host != INVALID_OFFSET && e->offset_mac != INVALID_OFFSET) {
				LONG source_low = (LONG)e->offset_host;
				LONG source_high = (LONG)(e->offset_host >> 32);
				LONG target_low = (LONG)e->offset_mac;
				LONG target_high = (LONG)(e->offset_mac >> 32);
				if( SetFilePointer( m_file, source_low, &source_high, FILE_BEGIN ) != 0xFFFFFFFF &&
						SetFilePointer( target_file, target_low, &target_high, FILE_BEGIN ) != 0xFFFFFFFF )
				{
					int blocks = 1;
					while( e && e->next && 
								 blocks < buffer_blocks &&
								 e->offset_host+UB_BLOCK_SIZE == e->next->offset_host &&
								 e->offset_mac+UB_BLOCK_SIZE == e->next->offset_mac )
					{
						blocks++;
						e = e->next;
					}

					D(bug("undo_buffer::commit() committing %d blocks\r\n", blocks));
					
					DWORD try_bytes = blocks*UB_BLOCK_SIZE;
					DWORD got_bytes;
					if(ReadFile( m_file, buffer, try_bytes, &got_bytes, NULL) && got_bytes == try_bytes ) {
						DWORD bytes_written;
						if(WriteFile( target_file, buffer, got_bytes, &bytes_written, NULL) && bytes_written == got_bytes ) {
							stats.total_bytes_committed += got_bytes;
						} else {
							result = false;
						}
					} else {
						result = false;
					}
				} else {
					result = false;
				}
			}
			e = e->next;
		}
	}
	SetCursor( LoadCursor( 0, IDC_ARROW ) );

	delete [] buffer;

	delete_entries();
	close();

	m_dirty = false;

	return result;
}
