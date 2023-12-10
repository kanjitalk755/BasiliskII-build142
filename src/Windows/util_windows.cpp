/*
 *  util_windows.cpp - Miscellaneous utilities for Win32
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
#include "main_windows.h"
#include "util_windows.h"

BOOL exists( const char *path )
{
	HFILE h;
	bool ret = false;

	h = _lopen( path, OF_READ );
	if(h != HFILE_ERROR) {
		ret = true;
		_lclose(h);
	}
	return(ret);
}

BOOL create_file( const char *path, DWORD size )
{
	HANDLE h;
	bool ok = false;

	h = CreateFile( path,
		GENERIC_READ | GENERIC_WRITE,
		0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL
	);
	if(h != INVALID_HANDLE_VALUE) {
		if(size == 0) {
			ok = true;
		} else if(SetFilePointer( h, size, NULL, FILE_BEGIN) != 0xFFFFFFFF) {
			if(SetEndOfFile(h)) {
				ok = true;
				if(SetFilePointer( h, 0, NULL, FILE_BEGIN) != 0xFFFFFFFF) {
					DWORD written, zeroed_size = min(1024*1024,size);
					char *b = (char *)malloc(zeroed_size);
					if(b) {
						memset( b, 0, zeroed_size );
						WriteFile( h, b, zeroed_size, &written, NULL );
						free(b);
					}
				}
			}
		}
		CloseHandle(h);
	}
	if(!ok) DeleteFile(path);
	return(ok);
}

int32 get_file_size( const char *path )
{
	HANDLE h;
	DWORD size = 0;

	h = CreateFile( path,
		GENERIC_READ,
		0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
	);
	if(h != INVALID_HANDLE_VALUE) {
		size = GetFileSize( h, NULL );
		CloseHandle(h);
	}
	return(size);
}

void center_window( HWND hwnd )
{
  int16 x, y;
  RECT r;
  GetWindowRect( hwnd, &r );
  x = (GetSystemMetrics(SM_CXSCREEN) - (r.right - r.left)) / 2;
  y = (GetSystemMetrics(SM_CYSCREEN) - (r.bottom - r.top)) / 2;
  SetWindowPos( hwnd, 0, x, y, 0, 0, SWP_NOZORDER|SWP_NOSIZE|SWP_SHOWWINDOW );
}

uint32 b2_ntohl( uint32 s )
{
	return(
		 ((s&0x000000FF) << 24) |
     ((s&0x0000FF00) << 8 ) |
     ((s&0x00FF0000) >> 8 ) |
     ((s&0xFF000000) >> 24)
	);
}

uint32 b2_htonl( uint32 s )
{
	return(
		 ((s&0x000000FF) << 24) |
     ((s&0x0000FF00) << 8 ) |
     ((s&0x00FF0000) >> 8 ) |
     ((s&0xFF000000) >> 24)
	);
}

uint16 b2_ntohs( uint16 s )
{
	return( ((s&0x00FF) << 8) | ((s&0xFF00) >> 8) );
}

uint16 b2_htons( uint16 s )
{
	return( ((s&0x00FF) << 8) | ((s&0xFF00) >> 8) );
}
