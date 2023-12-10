/*
 *  main_windows.h - Startup code for Win32
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

#ifndef _MAIN_WINDOWS_H_
#define _MAIN_WINDOWS_H_

void WarningAlert(const char *text);
void ErrorAlert(const char *text);

void show_cursor( int onoff );

extern HWND hMainWnd;
extern HINSTANCE hInst;
extern int win_os;
extern int win_os_major;
extern BOOL win_os_old;
extern BOOL mem_8_only;
extern int m_right_mouse;
extern int32 m_sleep;
extern bool m_sleep_enabled;

#ifdef __cplusplus
extern bool m_use_alt_escape;
extern bool m_use_alt_tab;
extern bool m_use_control_escape;
extern bool m_use_alt_space;
extern bool m_use_alt_enter;
#endif

extern HANDLE ether_th1;
extern HANDLE ether_th2;

extern char *ini_file_name;

void suspend_emulation(void);
void resume_emulation(void);
void WritePrivateProfileInt(
	LPSTR lpAppName,
	LPSTR lpKeyName,
	int value,
	LPSTR lpFileName
);

LRESULT CALLBACK MainWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

void update_system_menu( HWND hWnd );

#endif // _MAIN_WINDOWS_H_
