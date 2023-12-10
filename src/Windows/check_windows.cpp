/*
 *  check_windows.cpp
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
#include "check_windows.h"

// It's ok if the driver is missing (warning only)
// It's not ok to use an old driver (quit)
BOOL check_drivers(void)
{
	char path[_MAX_PATH], path2[_MAX_PATH];
	char text[_MAX_PATH*2];

	BOOL exists_in_drivers = FALSE;
	BOOL exists_in_working = FALSE;
	BOOL size_ok = TRUE;
	int32 size, ok_size;
	BOOL result = TRUE;

	GetSystemDirectory( path, sizeof(path) );
	if(win_os == VER_PLATFORM_WIN32_NT) {
		strcat( path, "\\drivers\\cdenable.sys" );
		ok_size = 6112;
	} else {
		strcat( path, "\\cdenable.vxd" );
		ok_size = 11924;
	}

	exists_in_drivers = (BOOL)exists( path );
	if(exists_in_drivers) {
		size = get_file_size( path );
		if(size && size != ok_size) {
			sprintf( text, "The CD-ROM driver file \"%s\" is too old or corrupted.", path );
			ErrorAlert(text);
			result = FALSE;
		}
	} else {
		sprintf( text, "The CD-ROM driver file \"%s\" is missing.", path );
		WarningAlert(text);
	}

	strcpy( path2, path );

	GetCurrentDirectory( sizeof(path), path );
	if(win_os == VER_PLATFORM_WIN32_NT) {
		strcat( path, "\\cdenable.sys" );
		ok_size = 6112;
	} else {
		strcat( path, "\\cdenable.vxd" );
		ok_size = 11924;
	}

	// May be running from the drivers folder.
	if(stricmp(path,path2)) {
		exists_in_working = (BOOL)exists( path );
		if(exists_in_working) {
			sprintf( text, "The CD-ROM driver file \"%s\" should not be here, but only in \"%s\".", path, path2 );
			WarningAlert(text);
		}
	}

	return(result);
}
