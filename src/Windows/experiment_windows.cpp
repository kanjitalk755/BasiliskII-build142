/*
 *  experiment_windows.cpp
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

#include <stdio.h>
#include <process.h>

#include "sysdeps.h"
#include "experiment_windows.h"

bool experiment_get_bool( const char *name )
{
	char exp_str[100];

	::GetPrivateProfileString( "Experiments", "DisableLowMemCache", "false", exp_str, sizeof(exp_str), "BasiliskII.ini" );
	return stricmp(exp_str,"true") == 0;
}
