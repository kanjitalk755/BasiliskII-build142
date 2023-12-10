/*
 *  undo_windows.h
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

#ifndef _UNDO_WINDOWS_H_
#define _UNDO_WINDOWS_H_

bool undo_init( file_handle *fh );
void undoable_write( file_handle *fh, void *buffer, loff_t offset, size_t length, DWORD &bytes_written );
void undoable_read( file_handle *fh, void *buffer, loff_t offset, size_t length, DWORD &bytes_read );
void undo_commit( file_handle *fh );
void undo_cleanup( file_handle *fh );

#endif // _UNDO_WINDOWS_H_
