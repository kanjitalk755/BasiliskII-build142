/*
 *  util_windows.h - Miscellaneous utilities for Win32
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

#ifndef _UTIL_WINDOWS_H
#define _UTIL_WINDOWS_H

#include "main_windows.h"

/*
static inline uint32 b2_ntohl( uint32 s )
{
	return(
		 ((s&0x000000FF) << 24) |
     ((s&0x0000FF00) << 8 ) |
     ((s&0x00FF0000) >> 8 ) |
     ((s&0xFF000000) >> 24)
	);
}

static inline uint32 b2_htonl( uint32 s )
{
	return(
		 ((s&0x000000FF) << 24) |
     ((s&0x0000FF00) << 8 ) |
     ((s&0x00FF0000) >> 8 ) |
     ((s&0xFF000000) >> 24)
	);
}

static inline uint16 b2_ntohs( uint16 s )
{
	return( ((s&0x00FF) << 8) | ((s&0xFF00) >> 8) );
}

static inline uint16 b2_htons( uint16 s )
{
	return( ((s&0x00FF) << 8) | ((s&0xFF00) >> 8) );
}
*/

uint32 b2_ntohl( uint32 s );
uint32 b2_htonl( uint32 s );
uint16 b2_ntohs( uint16 s );
uint16 b2_htons( uint16 s );

#define ntohl b2_ntohl
#define htonl b2_htonl
#define ntohs b2_ntohs
#define htons b2_htons

#ifdef __cplusplus
static uae_u32 inline b2_is_front_window(void)
{
	if(GetForegroundWindow() == hMainWnd) {
		return 1;
	} else {
		return 0;
	}
}
#endif

BOOL exists( const char *path );
int32 get_file_size( const char *path );
BOOL create_file( const char *path, DWORD size );

void center_window( HWND hwnd );

#endif // _UTIL_WINDOWS_H
