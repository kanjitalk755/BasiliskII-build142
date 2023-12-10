/*
 *  screen_saver.cpp
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
#include "prefs.h"
#include "main_windows.h"
#include "screen_saver.h"

static char *ss_section = "Screen Saver";
static char *ss_disabled = "Disabled by Basilisk II";


void screen_saver_enable()
{
	if(!PrefsFindBool("disablescreensaver")) return;

	if(GetPrivateProfileInt( ss_section, ss_disabled, 0, ini_file_name )) {
		SystemParametersInfo( SPI_SETSCREENSAVEACTIVE, TRUE, NULL, SPIF_SENDCHANGE );
		WritePrivateProfileInt( ss_section, ss_disabled, 0, ini_file_name );
	}
}

void screen_saver_disable()
{
	if(!PrefsFindBool("disablescreensaver")) return;

	BOOL is_screen_saver_active = FALSE;
	SystemParametersInfo( SPI_GETSCREENSAVEACTIVE, FALSE, (PVOID)&is_screen_saver_active, 0 );

	if( is_screen_saver_active ) {
		SystemParametersInfo( SPI_SETSCREENSAVEACTIVE, FALSE, NULL, SPIF_SENDCHANGE );
		WritePrivateProfileInt( ss_section, ss_disabled, 1, ini_file_name );
	} else {
		// Do not clear the entry; Basilisk II may have crashed.
	}
}
