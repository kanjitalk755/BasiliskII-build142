/*
 *  keyboard_windows.h
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

#ifndef _KEYBOARD_WINDOWS_H_
#define _KEYBOARD_WINDOWS_H_

typedef struct {
	int dlg_id;
	int scan_code;
	int extended;
	int mac;
	int show_name;
	char name[100];
} keymap_type;

extern keymap_type keymap[];

void load_key_codes( LPCSTR path, keymap_type *map );
void save_key_codes( LPCSTR path, keymap_type *map );
int scancode_2_mac( uint32 lparam );
int keyname_2_scan_extended( char *name );

#endif // _KEYBOARD_WINDOWS_H_
