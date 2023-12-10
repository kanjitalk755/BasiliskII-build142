/*
 *  user_strings_windows.cpp - Localizable strings for Windows
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
#include "user_strings.h"


// Platform-specific string definitions
user_string_def platform_strings[] = {
	{STR_EXTFS_VOLUME_NAME, "My Computer"},
	{-1, NULL}	// End marker
};

const char *check_customized_strings( int num )
{
	static char buf[256];
	char *b = 0;
	HKEY hHelpKey;
	DWORD key_type, cbData;

	if(num == STR_EXTFS_VOLUME_NAME) {
		memset( buf, 0, sizeof(buf) );
		b = buf;

		// Try 2k key first.
		if( ERROR_SUCCESS == RegOpenKey(
			HKEY_CURRENT_USER,
			"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\CLSID\\{20D04FE0-3AEA-1069-A2D8-08002B30309D}",
			&hHelpKey ) )
		{
			cbData = sizeof(buf);
			RegQueryValueEx( hHelpKey, 0, NULL, &key_type, (unsigned char *)buf, &cbData );
			RegCloseKey(hHelpKey);
		}
		if(!*buf) {
			if( ERROR_SUCCESS == RegOpenKey(
				HKEY_CURRENT_USER,
				"Software\\Classes\\CLSID\\{20D04FE0-3AEA-1069-A2D8-08002B30309D}",
				&hHelpKey ) )
			{
				cbData = sizeof(buf);
				RegQueryValueEx( hHelpKey, 0, NULL, &key_type, (unsigned char *)buf, &cbData );
				RegCloseKey(hHelpKey);
			}
		}
		if(!*buf) {
			if( ERROR_SUCCESS == RegOpenKey(
				HKEY_CLASSES_ROOT,
				"CLSID\\{20D04FE0-3AEA-1069-A2D8-08002B30309D}",
				&hHelpKey ) )
			{
				cbData = sizeof(buf);
				RegQueryValueEx( hHelpKey, 0, NULL, &key_type, (unsigned char *)buf, &cbData );
				RegCloseKey(hHelpKey);
			}
		}

		// Fix the error that some "tweak" apps do.
		if(stricmp(buf,"%USERNAME% on %COMPUTER%") == 0) *buf = 0;

		if(!*buf) {
			strcpy( buf, "My Computer" );
		}
	}
	return b;
}

/*
 *  Fetch pointer to string, given the string number
 */

const char *GetString(int num)
{
	// First search for platform-specific variable string
	const char *b = check_customized_strings(num);
	if(b) return b;

	// Next search for platform-specific constant string
	int i = 0;
	while (platform_strings[i].num >= 0) {
		if (platform_strings[i].num == num)
			return platform_strings[i].str;
		i++;
	}

	// Not found, search for common string
	i = 0;
	while (common_strings[i].num >= 0) {
		if (common_strings[i].num == num)
			return common_strings[i].str;
		i++;
	}
	return NULL;
}
