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

#ifndef _DESKTOP_WINDOWS_H_
#define _DESKTOP_WINDOWS_H_

void final_desktop(void);
BOOL init_desktop(void);
BOOL init_desktop_keys(void);
void set_desktop(void);
void swap_desktop(void);
bool has_own_desktop(void);
void register_desktop_hotkey(void);
UINT get_registered_desktop_hotkey(void);
char *get_desktopname(void);

// Alt tab works in linear frame buffer mode?
// #define WANT_HAVE_FAST_TASK_SWITCH

void init_keyboard_hook(void);
void final_keyboard_hook(void);

void register_desktop_hotkey(void);
void unregister_desktop_hotkey(void);

#endif // _DESKTOP_WINDOWS_H_
