/*
 *  undo_buffer.h
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

#ifndef _UNDO_BUFFER_H_
#define _UNDO_BUFFER_H_

#define MULTI_BLOCK_IO 1

#define UB_MAX_BUCKETS 4096
#define UB_BLOCK_SIZE  512

enum {
	UB_STATUS_HEALTHY=0,
	UB_STATUS_OUT_OF_SPACE,
	UB_STATUS_UNKNOWN_CORRUPTION
};

typedef struct _ub_entry {
	loff_t offset_mac;
	loff_t offset_host;
	struct _ub_entry *next;
} ub_entry;

typedef struct {
	uint32 offset_mac;
	uint32 offset_host;
} rw_entry;

typedef struct {
	__int64 total_bytes_committed;
} ub_stats;

class undo_buffer {
	public:
		undo_buffer();
		~undo_buffer();

		bool is_dirty() { return m_dirty; }
		int get_status() { return m_status; }

		void set_status( int status ) { m_status = status; }

		bool open( const char *path );
		bool close();

#if MULTI_BLOCK_IO
		bool put_n( void *buffer, loff_t offset, int blocks, int &blocks_written );
		bool get_n( void *buffer, loff_t offset, int blocks, int &blocks_read, int &skip_blocks );
#else
		bool put( void *buffer, loff_t offset );
		bool get( void *buffer, loff_t offset );
#endif

		bool commit( HANDLE target_file, ub_stats &stats );

	protected:
		ub_entry *find_entry( int hash_inx, loff_t offset );
		ub_entry *new_entry( int hash_inx, loff_t offset_mac, loff_t offset_host );

		int count_entries();
		void delete_entries();
		rw_entry *get_sorted_entry_list( int & count );

		void dump();

	protected:
		bool m_dirty;
		ub_entry *m_table[UB_MAX_BUCKETS];
		char m_path[_MAX_PATH];
		HANDLE m_file;
		loff_t m_next_offset;
		int m_status;
};

#endif // _UNDO_BUFFER_H_
