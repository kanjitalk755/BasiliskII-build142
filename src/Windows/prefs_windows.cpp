/*
 *  prefs_windows.cpp - Preferences handling for Win32
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
#include <stdlib.h>

#include "sysdeps.h"
#include "prefs.h"
#include "prefs_windows.h"


// Platform-specific preferences items
prefs_desc platform_prefs_items[] = {
	{"replacescsi", TYPE_STRING, true},		// replacescsi "HP" "CD-Writer+ 7100" "PHILIPS" "CDD3600"
	{"nofloppyboot", TYPE_BOOLEAN, false},
	{"noscsi", TYPE_BOOLEAN, false},
	{"ntdx5hack", TYPE_BOOLEAN, false},
	{"rightmouse", TYPE_INT16, false},
	{"keyboardfile", TYPE_STRING, false},
	{"pollmedia", TYPE_BOOLEAN, false},
	{"priority_ether_run", TYPE_STRING, false},
	{"priority_ether_idle", TYPE_STRING, false},
	{"priority_serial_in_run", TYPE_STRING, false},
	{"priority_serial_in_idle", TYPE_STRING, false},
	{"priority_serial_out_run", TYPE_STRING, false},
	{"priority_serial_out_idle", TYPE_STRING, false},
	{"priority_cpu_run", TYPE_STRING, false},
	{"priority_cpu_idle", TYPE_STRING, false},
	{"priority_60hz_run", TYPE_STRING, false},
	{"priority_60hz_idle", TYPE_STRING, false},
	{"priority_1hz_run", TYPE_STRING, false},
	{"priority_1hz_idle", TYPE_STRING, false},
	{"priority_pram_run", TYPE_STRING, false},
	{"priority_pram_idle", TYPE_STRING, false},
	{"priority_gui_run", TYPE_STRING, false},
	{"priority_gui_idle", TYPE_STRING, false},
	{"priority_gdi_run", TYPE_STRING, false},
	{"priority_gdi_idle", TYPE_STRING, false},
	{"priority_dx_run", TYPE_STRING, false},
	{"priority_dx_idle", TYPE_STRING, false},
	{"priority_fb_run", TYPE_STRING, false},
	{"priority_fb_idle", TYPE_STRING, false},
	{"priority_sound_run", TYPE_STRING, false},
	{"priority_sound_idle", TYPE_STRING, false},
	{"noaudio", TYPE_BOOLEAN, false},
	{"debugscsi", TYPE_INT16, false},
	{"debugfilesys", TYPE_INT16, false},
	{"debugserial", TYPE_INT16, false},
	{"framesleepticks", TYPE_INT32, false},
	{"showfps", TYPE_BOOLEAN, false},
	{"stickymenu", TYPE_BOOLEAN, false},
	{"etherpermanentaddress", TYPE_BOOLEAN, false},
	{"ethermulticastmode", TYPE_INT16, false},
	{"disable98optimizations", TYPE_BOOLEAN, false},
	{"etherfakeaddress", TYPE_STRING, false},
	{"realmodecd", TYPE_BOOLEAN, false},
	{"ether9x", TYPE_STRING, false},
	{"ethernt", TYPE_STRING, false},
	{"ethernt5", TYPE_STRING, false},
	{"soundbuffers", TYPE_INT16, false},
	{"soundbuffersize8000", TYPE_INT32, false},
	{"soundbuffersize11025", TYPE_INT32, false},
	{"soundbuffersize22050", TYPE_INT32, false},
	{"soundbuffersize44100", TYPE_INT32, false},
	// {"cpu", TYPE_INT32, false},
	{"nosoundwheninactive", TYPE_BOOLEAN, false},
	{"mousewheelmode", TYPE_INT16, false},
	{"mousewheellines", TYPE_INT16, false},
	{"mousewheelreversex", TYPE_BOOLEAN, false},
	{"mousewheelreversey", TYPE_BOOLEAN, false},
	{"mousewheelclickmode", TYPE_INT16, false},
	{"mousewheelcust00", TYPE_STRING, false},
	{"mousewheelcust01", TYPE_STRING, false},
	{"mousewheelcust10", TYPE_STRING, false},
	{"mousewheelcust11", TYPE_STRING, false},
	{"usealtescape", TYPE_BOOLEAN, false},
	{"usealttab", TYPE_BOOLEAN, false},
	{"usecontrolescape", TYPE_BOOLEAN, false},
	{"usealtspace", TYPE_BOOLEAN, false},
	{"usealtenter", TYPE_BOOLEAN, false},
	{"disableaccuratetimer", TYPE_BOOLEAN, false},
	{"guiautorestart", TYPE_INT16, false},
	{"gethardwarevolume", TYPE_BOOLEAN, false},
	{"enableextfs", TYPE_BOOLEAN, false},
	{"usentfsafp", TYPE_BOOLEAN, false},
	{"extdrives", TYPE_STRING, false},
	{"typemapfile", TYPE_STRING, false},
	{"debugextfs", TYPE_INT16, false},
	{"portfile0", TYPE_STRING, false},
	{"portfile1", TYPE_STRING, false},
	{"DX_fullscreen_refreshrate", TYPE_STRING, false},
	{"mousemovementmode", TYPE_INT16, false},
	{"usestartupsound", TYPE_BOOLEAN, false},
	{"smp_ethernet", TYPE_INT32, false},
	{"smp_serialin", TYPE_INT32, false},
	{"smp_serialout", TYPE_INT32, false},
	{"smp_cpu", TYPE_INT32, false},
	{"smp_60hz", TYPE_INT32, false},
	{"smp_1hz", TYPE_INT32, false},
	{"smp_pram", TYPE_INT32, false},
	{"smp_gui", TYPE_INT32, false},
	{"smp_gdi", TYPE_INT32, false},
	{"smp_dx", TYPE_INT32, false},
	{"smp_fb", TYPE_INT32, false},
	{"smp_audio", TYPE_INT32, false},
	{"idlesleep", TYPE_INT32, false},
	{"idlesleepenabled", TYPE_BOOLEAN, false},
	{"idletimeout", TYPE_INT32, false},
	{"routerenabled", TYPE_BOOLEAN, false},
	{"tcp_port", TYPE_STRING, true},
	{"udp_port", TYPE_STRING, true},
	{"ftp_port_list", TYPE_STRING, false},
	{"disablescreensaver", TYPE_BOOLEAN, false},
	{"keyboardtype", TYPE_INT16, false},
	{NULL, TYPE_END, false}	// End of list
};

// Prefs file name and path
static char prefs_path[_MAX_PATH];


static void prefs_get_ini_path( char *path, int sz )
{
	memset( path, 0, sz );
	strncpy( path, prefs_path, sz-1 );
}

void SetPrefsFile( const char *path )
{
	memset( prefs_path, 0, sizeof(prefs_path) );

	if(!strchr(path,'\\')) {
		GetCurrentDirectory(sizeof(prefs_path)-1,prefs_path);
		if(strlen(prefs_path) > 0 && prefs_path[strlen(prefs_path)-1] != '\\') strcat(prefs_path,"\\");
	}
	strcat( prefs_path, path );
}

/*
 *  Load preferences from settings file
 */

void LoadPrefs(void)
{
	char path[_MAX_PATH];

	prefs_get_ini_path(path,sizeof(path));

	// Read preferences from settings file
	FILE *f = fopen(path, "r");
	if (f != NULL) {
		// Prefs file found, load settings
		LoadPrefsFromStream(f);
		fclose(f);
	} else {
		// No prefs file, save defaults
		SavePrefs();
	}
}


/*
 *  Save preferences to settings file
 */

void SavePrefs(void)
{
	char path[_MAX_PATH];
	FILE *f;

	prefs_get_ini_path(path,sizeof(path));

	if ((f = fopen(path, "w")) != NULL) {
		SavePrefsToStream(f);
		fclose(f);
	}
}


/*
 *  Add defaults of platform-specific prefs items
 *  You may also override the defaults set in PrefsInit()
 */

void AddPlatformPrefsDefaults(void)
{
	PrefsReplaceInt16( "rightmouse", 0 );
	PrefsReplaceString( "keyboardfile", "BasiliskII_keyboard" );
	PrefsReplaceBool( "pollmedia", true );
	PrefsReplaceBool( "noaudio", true );
	PrefsReplaceInt32( "framesleepticks", 12 );
	PrefsReplaceBool( "showfps", false );
	PrefsReplaceBool( "stickymenu", true );
	PrefsReplaceBool( "etherpermanentaddress", true );
	PrefsReplaceInt16( "ethermulticastmode", 0 );
	PrefsReplaceBool( "disable98optimizations", false );
	PrefsReplaceBool( "realmodecd", false );
	PrefsReplaceString( "screen", "dx/800/600/8" );
	PrefsReplaceInt32( "ramsize", 16 * 1024 * 1024 );
	PrefsReplaceInt32( "modelid", 14 );
	PrefsReplaceInt16( "rightmouse", 1 );
	PrefsReplaceBool( "noscsi", true );
	PrefsReplaceBool( "ntdx5hack", false );
	PrefsReplaceBool( "fpu", true );
	PrefsReplaceInt16( "rightmouse", 1 );
	PrefsReplaceBool( "nosound", false );
	PrefsReplaceInt16("soundbuffers", 3 );
	PrefsReplaceInt32( "soundbuffersize8000", 1024 );
	PrefsReplaceInt32( "soundbuffersize11025", 2048 );
	PrefsReplaceInt32( "soundbuffersize22050", 2048 );
	PrefsReplaceInt32( "soundbuffersize44100", 4096 );
	PrefsReplaceInt32( "cpu", 68040 );
	PrefsReplaceBool( "nosoundwheninactive", true );
	PrefsReplaceInt16( "mousewheelmode", 1 );
	PrefsReplaceInt16( "mousewheellines", 3 );
	PrefsReplaceBool( "mousewheelreversex", false );
	PrefsReplaceBool( "mousewheelreversey", false );
	PrefsReplaceInt16( "mousewheelclickmode", 1 );
	PrefsReplaceString( "mousewheelcust00", "+37+3B-3B-37" );
	PrefsReplaceString( "mousewheelcust01", "+37+3C-3C-37" );
	PrefsReplaceString( "mousewheelcust10", "" );
	PrefsReplaceString( "mousewheelcust11", "" );
	PrefsReplaceBool( "usealtescape", true );
	PrefsReplaceBool( "usealttab", true );
	PrefsReplaceBool( "usecontrolescape", true );
	PrefsReplaceBool( "usealtspace", true );
	PrefsReplaceBool( "usealtenter", true );
	PrefsReplaceBool( "disableaccuratetimer", false );
	PrefsReplaceInt16( "guiautorestart", 0 );
	PrefsReplaceString( "extfs", "" );
	PrefsReplaceBool( "gethardwarevolume", true );
	PrefsReplaceBool( "enableextfs", false );
	PrefsReplaceBool( "usentfsafp", false );
	PrefsReplaceString( "extdrives", "CDEFGHIJKLMNOPQRSTUVWXYZ" );
	PrefsReplaceString( "portfile0", "C:\\B2TEMP0.OUT" );
	PrefsReplaceString( "portfile1", "C:\\B2TEMP1.OUT" );
	PrefsReplaceString( "DX_fullscreen_refreshrate", "Monitor default" );
	PrefsReplaceInt16( "mousemovementmode", 0 );
	PrefsReplaceBool( "usestartupsound", true );
	PrefsReplaceInt32( "smp_ethernet", 0 );
	PrefsReplaceInt32( "smp_serialin", 0 );
	PrefsReplaceInt32( "smp_serialout", 0 );
	PrefsReplaceInt32( "smp_cpu", 0 );
	PrefsReplaceInt32( "smp_60hz", 0 );
	PrefsReplaceInt32( "smp_1hz", 0 );
	PrefsReplaceInt32( "smp_pram", 0 );
	PrefsReplaceInt32( "smp_gui", 0 );
	PrefsReplaceInt32( "smp_gdi", 0 );
	PrefsReplaceInt32( "smp_dx", 0 );
	PrefsReplaceInt32( "smp_fb", 0 );
	PrefsReplaceInt32( "smp_audio", 0 );
	PrefsReplaceInt32( "idlesleep", 1 );
	PrefsReplaceBool( "idlesleepenabled", false );
	PrefsReplaceInt32( "idletimeout", 0 );
	PrefsReplaceBool( "routerenabled", false );
	PrefsReplaceString( "ftp_port_list", "21" );
	PrefsReplaceBool( "disablescreensaver", false );
	PrefsReplaceInt16( "keyboardtype", 5 );
	// No default for "typemapfile"
}
