/*
 *  xpram_windows.cpp - XPRAM handling for Win32
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
#include <string.h>
#include <process.h>

#include "sysdeps.h"
#include "cpu_emulation.h"
#include "xpram.h"
#include "main_windows.h"
#include "xpram_windows.h"
#include "desktop_windows.h"
#include "threads_windows.h"
#include "user_strings.h"

#define DEBUG 0
#include "debug.h"


// XPRAM file name and path
static char param_path[_MAX_PATH];

static HANDLE prefs_file_mutex = 0;

#define XPRAM_SIZE (sizeof(XPRAM))

static uint8 last_xpram[XPRAM_SIZE];

void xpar_init(void)
{
	prefs_file_mutex = CreateMutex( 0, FALSE, "Basilisk II prefs file mutex" );

	char folder[_MAX_PATH];
	GetCurrentDirectory(sizeof(folder),folder);
	if(strlen(folder) > 0 && folder[strlen(folder)-1] != '\\') strcat(folder,"\\");

	wsprintf( param_path, "%spram_%08x.dat", folder, ntohl(*(uint32 *)ROMBaseHost) );

	char param_path_oldie[_MAX_PATH];
	wsprintf( param_path_oldie, "%spram.dat", folder );

	if(!exists(param_path) && exists(param_path_oldie)) {
		if(rename(param_path_oldie, param_path) >= 0) {
			char *text = new char [512];
			if(text) {
				wsprintf(
					text,
					"Your parameter RAM file was renamed from \"%s\" to \"%s\".",
					param_path_oldie,
					param_path
				);
				MessageBox(hMainWnd,text,GetString(STR_WINDOW_TITLE),MB_OK|MB_ICONINFORMATION);
				delete [] text;
			}
		}
	}
}

void xpar_final(void)
{
  D(bug("xpar_final\r\n"));

	if(prefs_file_mutex) {
		CloseHandle(prefs_file_mutex);
		prefs_file_mutex = 0;
	}
}

static bool xpar_grab_mutex()
{
	if(prefs_file_mutex) {
		WaitForSingleObject(prefs_file_mutex,INFINITE);
		return(true);
	} else {
		return(false);
	}
}

static void xpar_release_mutex()
{
	if(prefs_file_mutex) {
		ReleaseMutex(prefs_file_mutex);
	}
}

// Should call CloseHandle(prefs_file_mutex) but Windows does this anyway at exit


void xpar_save_if_needed(void)
{
  D(bug("xpar_save_if_needed\r\n"));

	if (memcmp(last_xpram, XPRAM, XPRAM_SIZE)) {
	  D(bug("xpar_save_if_needed: some changes detected\r\n"));
		memcpy(last_xpram, XPRAM, XPRAM_SIZE);
		SaveXPRAM();
	} else {
	  D(bug("xpar_save_if_needed: no changes\r\n"));
	}
}

/*
 *  XPRAM watchdog thread (saves XPRAM every 10 seconds)
 */

unsigned int WINAPI xpram_func(LPVOID param)
{
	set_desktop();

	for (;;) {
		Sleep(10000);
		xpar_save_if_needed();
	}

  threads[THREAD_PARAMETER_RAM].h = NULL;
  threads[THREAD_PARAMETER_RAM].tid = 0;
	_endthreadex( 0 );

	return(0);
}

static void xpar_get_ini_path( char *path, int sz )
{
	memset( path, 0, sz );
	strncpy( path, param_path, sz );
}

/*
 *  Load XPRAM from settings file
 */

void LoadXPRAM(void)
{
	HFILE hf;
	char path[_MAX_PATH];

  D(bug("LoadXPRAM\r\n"));

	if(xpar_grab_mutex()) {
		memset( XPRAM, 0, XPRAM_SIZE );
		xpar_get_ini_path(path,sizeof(path));
		hf = _lopen( path, OF_READ );
		if(hf != HFILE_ERROR) {
		  D(bug("LoadXPRAM loading\r\n"));
			_lread(hf, XPRAM, XPRAM_SIZE);
			_lclose(hf);
		}
		memcpy(last_xpram, XPRAM, XPRAM_SIZE);
		xpar_release_mutex();
	}
}


/*
 *  Save XPRAM to settings file
 */

void SaveXPRAM(void)
{
	HFILE hf;
	char path[_MAX_PATH];

  D(bug("SaveXPRAM\r\n"));

	if(xpar_grab_mutex()) {
	  D(bug("SaveXPRAM got mutex\r\n"));
		xpar_get_ini_path(path,sizeof(path));
		unlink( path );
		hf = _lcreat( path, 0 );
		if(hf != HFILE_ERROR) {
		  D(bug("SaveXPRAM saving\r\n"));
			_lwrite(hf, (char *)XPRAM, XPRAM_SIZE);
			_lclose(hf);
		}
		xpar_release_mutex();
	}
}
