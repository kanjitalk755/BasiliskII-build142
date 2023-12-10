/*
 *  desktop_windows.cpp - WinNT lfb desktop
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
#include "main.h"
#include "adb.h"
#include "prefs.h"
#include "user_strings.h"
#include "cpu_emulation.h"
#include "main_windows.h"
#include "video_windows.h"
#include "desktop_windows.h"
#include "keyboard_windows.h"
#include "threads_windows.h"
#include "util_windows.h"
#include "video.h"
#include <winnt.h>
#include <ddraw.h>
#include <d3d.h>
#include <process.h>

#define DEBUG 0
#include "debug.h"

#ifndef WH_KEYBOARD_LL
#define WH_KEYBOARD_LL	13
#define LLKHF_UP				0x00000080
#define LLKHF_ALTDOWN		0x00000020
typedef struct tagKBDLLHOOKSTRUCT {
    DWORD   vkCode;
    DWORD   scanCode;
    DWORD   flags;
    DWORD   time;
    DWORD   dwExtraInfo;
} KBDLLHOOKSTRUCT, FAR *LPKBDLLHOOKSTRUCT, *PKBDLLHOOKSTRUCT;
#endif //WH_KEYBOARD_LL


static HDESK hDesk = 0;
static HDESK hDeskOld = 0;
static bool is_own_desktop = FALSE;
static char *desktopname = "BasiliskII";
static HHOOK m_keyhook = 0;

// Ctrl-Shift-<this> is the switch between Windows and Mac
static UINT registered_hotkey = VK_F12;

// Note that Ctrl-Alt-Del is not disabled.
// There is always a way to log out or shut down gracefully.

// Disable ctrl-escape and shift-ctrl-escape on this desktop.
// Cannot allow Explorer in another desktop bring up a start menu.
// User defined hotkeys can still lock the system.
// If that happens, use ctrl-alt-del and log out to resume.
LRESULT CALLBACK key_func(
  int nCode,
  WPARAM wParam,
  LPARAM lParam
)
{
	if(nCode < 0) return(CallNextHookEx(m_keyhook,nCode,wParam,lParam));

	if(!b2_is_front_window()) return(CallNextHookEx(m_keyhook,nCode,wParam,lParam));

	LPKBDLLHOOKSTRUCT p = (LPKBDLLHOOKSTRUCT)lParam;

	if( m_use_alt_enter && (p->vkCode == VK_RETURN) && (p->flags & LLKHF_ALTDOWN) ) {
		if( (p->flags & LLKHF_UP) == 0 ) {
			toggle_full_screen_mode();
		}
		return(1);
	} else if( m_use_control_escape && (p->vkCode == VK_ESCAPE) && (GetAsyncKeyState(VK_CONTROL) & 0x8000) )
	{
		PostMessage(
			hMainWnd,
			p->flags & LLKHF_UP ? WM_KEYUP : WM_KEYDOWN,
			VK_ESCAPE,
			keyname_2_scan_extended( "ESC" )
		);
		return(1);
	} else if( m_use_alt_escape && (p->vkCode == VK_ESCAPE) && (p->flags & LLKHF_ALTDOWN) )
	{
		PostMessage(
			hMainWnd,
			p->flags & LLKHF_UP ? WM_KEYUP : WM_KEYDOWN,
			VK_ESCAPE,
			keyname_2_scan_extended( "ESC" )
		);
		return(1);
	} else if( m_use_alt_space && (p->vkCode == VK_SPACE) && (p->flags & LLKHF_ALTDOWN) )
	{
		PostMessage(
			hMainWnd,
			p->flags & LLKHF_UP ? WM_KEYUP : WM_KEYDOWN,
			VK_SPACE,
			keyname_2_scan_extended( "SPACE" )
		);
		return(1);
	} else if( p->vkCode == VK_LWIN )
	{
		PostMessage(
			hMainWnd,
			p->flags & LLKHF_UP ? WM_KEYUP : WM_KEYDOWN,
			VK_LWIN,
			keyname_2_scan_extended( "LWIN" )
		);
		return(1);
	} else if( p->vkCode == VK_RWIN )
	{
		PostMessage(
			hMainWnd,
			p->flags & LLKHF_UP ? WM_KEYUP : WM_KEYDOWN,
			VK_RWIN,
			keyname_2_scan_extended( "RWIN" )
		);
		return(1);
	} else if( (p->vkCode == VK_F4) &&
						 (p->flags & LLKHF_ALTDOWN) &&
						 ((p->flags & LLKHF_UP) == 0) )
	{
		PostMessage( hMainWnd, WM_CLOSE, 0, 0 );
		return(1);
#ifndef WANT_HAVE_FAST_TASK_SWITCH
	} else if( m_use_alt_tab && (p->vkCode == VK_TAB) && (p->flags & LLKHF_ALTDOWN)) {
		PostMessage(
			hMainWnd,
			p->flags & LLKHF_UP ? WM_KEYUP : WM_KEYDOWN,
			VK_TAB,
			keyname_2_scan_extended( "TAB" )
		);
		return(1);
#endif
	} else {
		return(0);
	}
}

LRESULT CALLBACK key_func_w9x(
  int nCode,
  WPARAM wParam,
  LPARAM lParam
)
{
	if(nCode < 0) return(CallNextHookEx(m_keyhook,nCode,wParam,lParam));

	if(!b2_is_front_window()) return(CallNextHookEx(m_keyhook,nCode,wParam,lParam));

	BOOL alt = (HIWORD(lParam) & KF_ALTDOWN) != 0;
	BOOL up  = (HIWORD(lParam) & KF_UP) != 0;
	BOOL ext = (HIWORD(lParam) & KF_EXTENDED) != 0;

	if( m_use_alt_enter && (wParam == VK_RETURN) && alt ) {
		if(!up) {
			toggle_full_screen_mode();
		}
		return(1);
	} else if( (wParam == VK_F4) && alt && up ) {
		PostMessage( hMainWnd, WM_CLOSE, 0, 0 );
		return(1);
	} else if( wParam == VK_LWIN ) {
		PostMessage(
			hMainWnd,
			up ? WM_KEYUP : WM_KEYDOWN,
			VK_LWIN,
			keyname_2_scan_extended( "LWIN" )
		);
		return(1);
	} else if( wParam == VK_RWIN ) {
		PostMessage(
			hMainWnd,
			up ? WM_KEYUP : WM_KEYDOWN,
			VK_RWIN,
			keyname_2_scan_extended( "RWIN" )
		);
		return(1);
	} else if( (wParam == VK_CONTROL) && ext )
	{
		PostMessage(
			hMainWnd,
			up ? WM_KEYUP : WM_KEYDOWN,
			VK_RCONTROL,
			keyname_2_scan_extended( "RCONTROL" )
		);
		return(1);
	} else {
		return(0);
	}
}

void register_desktop_hotkey( void )
{
	if(!RegisterHotKey(
		hMainWnd,
		registered_hotkey,
		MOD_CONTROL|MOD_SHIFT,
		registered_hotkey
	))
	{
		WarningAlert("Could not register desktop switch hotkey Control-Shift-F12.");
	}
}

void unregister_desktop_hotkey( void )
{
	if(registered_hotkey) {
		// BoundsChecker says: not registered...?
    UnregisterHotKey( hMainWnd, registered_hotkey );
		registered_hotkey = 0;
	}
}

UINT get_registered_desktop_hotkey( void )
{
	return( registered_hotkey );
}

void init_keyboard_hook(void)
{
	if(win_os == VER_PLATFORM_WIN32_WINDOWS) {
		m_keyhook = SetWindowsHookEx( WH_KEYBOARD, (HOOKPROC)key_func_w9x, hInst, 0 );
	} else {
		m_keyhook = SetWindowsHookEx( WH_KEYBOARD_LL, (HOOKPROC)key_func, hInst, 0 );
	}
}

void final_keyboard_hook(void)
{
	if(m_keyhook) {
		UnhookWindowsHookEx(m_keyhook);
		m_keyhook = 0;
	}
}

// Must be called from the main thread only.
void swap_desktop(void)
{
#if DEBUG
	if(GetCurrentThread() != GUIThread_handle) {
		D(bug("Internal error, improper call of swap_desktop()"));
	}
#endif
	if(hDesk) {
		if(threads[THREAD_CPU].h) SuspendThread(threads[THREAD_CPU].h);
		if(threads[THREAD_60_HZ].h) SuspendThread(threads[THREAD_60_HZ].h);
		if(is_own_desktop) {
			fb_command( FB_UNLOCK, 0, 0 );
			suspend_emulation();
			SwitchDesktop(hDeskOld);
			final_keyboard_hook();
			is_own_desktop = FALSE;
		} else {
			SwitchDesktop(hDesk);
			resume_emulation();
			ShowWindow(hMainWnd, SW_MAXIMIZE);
			fb_command( FB_SETPALETTE, current_mac_palette, sizeof(current_mac_palette) );
			ShowWindow(hMainWnd, SW_MAXIMIZE);
			fb_command( FB_LOCK, 0, 0 );
			init_keyboard_hook();
			is_own_desktop = TRUE;
		}
		if(threads[THREAD_60_HZ].h) ResumeThread(threads[THREAD_60_HZ].h);
		if(threads[THREAD_CPU].h) ResumeThread(threads[THREAD_CPU].h);
	} else {
		if(GetFocus() == hMainWnd) {
			video_activate( false );
			suspend_emulation();
			ShowWindow(hMainWnd, SW_HIDE);
			final_keyboard_hook();
		} else {
			resume_emulation();
			video_activate( true );
			ShowWindow(hMainWnd, SW_MAXIMIZE);
			SetFocus(hMainWnd);
			SetActiveWindow(hMainWnd);
			init_keyboard_hook();
		}
	}
}

void final_desktop(void)
{
	is_own_desktop = FALSE;

	if(hDesk) {
		if(hDeskOld) {
			SwitchDesktop(hDeskOld);
			// SetThreadDesktop(hDeskOld);
			hDeskOld = 0;
			is_own_desktop = FALSE;
		}
		CloseDesktop(hDesk);
		hDesk = 0;
	}
}

BOOL init_desktop(void)
{
	BOOL ok;

  hDesk = OpenDesktop( desktopname, 0, FALSE, GENERIC_ALL );
	if(!hDesk) {
		hDesk = CreateDesktop( desktopname, NULL, NULL, 0, MAXIMUM_ALLOWED, NULL );
	}
	if(!hDesk) {
		final_desktop();
		return(FALSE);
	}

	hDeskOld = GetThreadDesktop(GetCurrentThreadId());
	if(!hDeskOld) {
		final_desktop();
		return(FALSE);
	}

	set_desktop();

	ok = SwitchDesktop(hDesk);
	if(!ok) {
		final_desktop();
		return(FALSE);
	}
	is_own_desktop = TRUE;

	return(TRUE);
}

void set_desktop(void)
{
	USEROBJECTFLAGS uof;

	if(hDesk) {
    uof.fInherit = FALSE;
    uof.fReserved = FALSE;
    uof.dwFlags = DF_ALLOWOTHERACCOUNTHOOK;
    SetUserObjectInformation( hDesk, UOI_FLAGS, (LPVOID)&uof, sizeof(uof) );
		if(!SetThreadDesktop(hDesk)) {
			D(bug("SetThreadDesktop() failed in set_desktop()\n"));
		}
	}
}

bool has_own_desktop(void)
{
	return(is_own_desktop);
}

char *get_desktopname(void)
{
	return(desktopname);
}
