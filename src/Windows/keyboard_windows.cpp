/*
 *  keyboard_windows.cpp
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

#include <windows.h>
#include <stdio.h>
#include "sysdeps.h"
#include "keyboard_windows.h"
#include "\BasiliskII_win32\src\Windows\Gui\BasiliskIIGUI\Resource.h"

#define DEBUG 0
#include "debug.h"

keymap_type keymap[] = {
{ IDC_K_SECTION,				0x29,		0,		0x0A,			1,		"SECTION" },
{ IDC_K_1,							2,			0,		0x12,			1,		"1" },
{ IDC_K_2,							3,			0,		0x13,			1,		"2" },
{ IDC_K_3,							4,			0,		0x14,			1,		"3" },
{ IDC_K_4,							5,			0,		0x15,			1,		"4" },
{ IDC_K_5,							6,			0,		0x17,			1,		"5" },
{ IDC_K_6,							7,			0,		0x16,			1,		"6" },
{ IDC_K_7,							8,			0,		0x1A,			1,		"7" },
{ IDC_K_8,							9,			0,		0x1C,			1,		"8" },
{ IDC_K_9,							10,			0,		0x19,			1,		"9" },
{ IDC_K_0,							11,			0,		0x1D,			1,		"0" },
{ IDC_K_PLUS,						12,			0,		0x1B,			1,		"PLUS" },
{ IDC_K_ACUTE,					13,			0,		0x18,			1,		"ACUTE" },
{ IDC_K_BACKSPACE,			14,			0,		0x33,			0,		"BACK_SPACE" },
{ IDC_K_Q,							16,			0,		0x0C,			1,		"Q" },
{ IDC_K_W,							17,			0,		0x0D,			1,		"W" },
{ IDC_K_E,							18,			0,		0x0E,			1,		"E" },
{ IDC_K_R,							19,			0,		0x0F,			1,		"R" },
{ IDC_K_T,							20,			0,		0x11,			1,		"T" },
{ IDC_K_Y,							21,			0,		0x10,			1,		"Y" },
{ IDC_K_U,							22,			0,		0x20,			1,		"U" },
{ IDC_K_I,							23,			0,		0x22,			1,		"I" },
{ IDC_K_O,							24,			0,		0x1F,			1,		"O" },
{ IDC_K_P,							25,			0,		0x23,			1,		"P" },
{ IDC_K_RUOTS_O,				26,			0,		0x21,			1,		"ARING" },
{ IDC_K_DOTDOT,					27,			0,		0x1E,			1,		"DIAERESIS" },
{ IDC_K_TAB,						15,			0,		0x30,			0,		"TAB" },
{ IDC_K_A,							30,			0,		0x00,			1,		"A" },
{ IDC_K_S,							31,			0,		0x01,			1,		"S" },
{ IDC_K_D,							32,			0,		0x02,			1,		"D" },
{ IDC_K_F,							33,			0,		0x03,			1,		"F" },
{ IDC_K_G,							34,			0,		0x05,			1,		"G" },
{ IDC_K_H,							35,			0,		0x04,			1,		"H" },
{ IDC_K_J,							36,			0,		0x26,			1,		"J" },
{ IDC_K_K,							37,			0,		0x28,			1,		"K" },
{ IDC_K_L,							38,			0,		0x25,			1,		"L" },
{ IDC_K_OO,							39,			0,		0x29,			1,		"ODIERESIS" },
{ IDC_K_AA,							40,			0,		0x27,			1,		"ADIERESIS" },
{ IDC_K_QUOTE,					0x2B,		0,		0x2A,			1,		"SINGLE_QUOTE" },
{ IDC_K_RET,						28,			0,		0x24,			0,		"ENTER" },
{ IDC_K_CAPSLOCK,				58,			0,		0x39,			0,		"CAPS_LOCK" },
{ IDC_K_LESSTHAN,				0x56,		0,		0x32,			1,		"LESS_THAN" },
{ IDC_K_Z,							44,			0,		0x06,			1,		"Z" },
{ IDC_K_X,							45,			0,		0x07,			1,		"X" },
{ IDC_K_C,							46,			0,		0x08,			1,		"C" },
{ IDC_K_V,							47,			0,		0x09,			1,		"V" },
{ IDC_K_B,							48,			0,		0x0B,			1,		"B" },
{ IDC_K_N,							49,			0,		0x2D,			1,		"N" },
{ IDC_K_M,							50,			0,		0x2E,			1,		"M" },
{ IDC_K_COMMA,					51,			0,		0x2B,			1,		"COMMA" },
{ IDC_K_PERIOD,					52,			0,		0x2F,			1,		"PERIOD" },
{ IDC_K_HYPHEN,					53,			0,		0x2C,			1,		"HYPHEN" },
{ IDC_K_RSHIFT,					54,			0,		0x38,			0,		"RSHIFT" },
{ IDC_K_LSHIFT,					42,			0,		0x38,			0,		"LSHIFT" },
{ IDC_K_LCONTROL,				29,			0,		0x36,			0,		"LCONTROL" },
{ IDC_K_LWIN,						0x5B,		1,		0x3A,			0,		"LWIN" },
{ IDC_K_LALT,						56,			0,		0x37,			0,		"LALT" },
{ IDC_K_ALTGR,					0,			0,		-1,				0,		"ALTGR" },
{ IDC_K_RWIN,						0x5C,		1,		0x3A,			0,		"RWIN" },
{ IDC_K_RCONTROL,				0x1D,		1,		0x3A,			0,		"RCONTROL" },
{ IDC_K_SPACE,					57,			0,		0x31,			1,		"SPACE" },
{ IDC_K_ESC,						1,			0,		0x35,			0,		"ESC" },
{ IDC_K_F1,							59,			0,		0x7A,			0,		"F1" },
{ IDC_K_F2,							60,			0,		0x78,			0,		"F2" },
{ IDC_K_F3,							61,			0,		0x63,			0,		"F3" },
{ IDC_K_F4,							62,			0,		0x76,			0,		"F4" },
{ IDC_K_F5,							63,			0,		0x60,			0,		"F5" },
{ IDC_K_F6,							64,			0,		0x61,			0,		"F6" },
{ IDC_K_F7,							65,			0,		0x62,			0,		"F7" },
{ IDC_K_F8,							66,			0,		0x64,			0,		"F8" },
{ IDC_K_F9,							67,			0,		0x65,			0,		"F9" },
{ IDC_K_F10,						68,			0,		0x6D,			0,		"F10" },
{ IDC_K_F11,						87,			0,		0x67,			0,		"F11" },
{ IDC_K_F12,						88,			0,		0x6F,			0,		"F12" },
{ IDC_K_PRINTSCREEN,		0,			0,		0x69,			0,		"PRINT_SCREEN" },
{ IDC_K_SCROLL_LOCK,		70,			0,		0x6B,			0,		"SCROLL_LOCK" },
{ IDC_K_PAUSE,					0x45,		0,		0x7F,			0,		"PAUSE" },
{ IDC_K_INSERT,					0x52,		1,		0x72,			0,		"INSERT" },
{ IDC_K_HOME,						0x47,		1,		0x73,			0,		"HOME" },
{ IDC_K_PAGE_UP,				0x49,		1,		0x74,			0,		"PAGE_UP" },
{ IDC_K_DELETE,					0x53,		1,		0x75,			0,		"DELETE" },
{ IDC_K_END,						0x4F,		1,		0x77,			0,		"END" },
{ IDC_K_PAGE_DOWN,			0x51,		1,		0x79,			0,		"PAGE_DOWN" },
{ IDC_K_LEFT,						0x4B,		1,		0x3B,			0,		"LEFT" },
{ IDC_K_DOWN,						0x50,		1,		0x3D,			0,		"DOWN" },
{ IDC_K_RIGHT,					0x4D,		1,		0x3C,			0,		"RIGHT" },
{ IDC_K_UP,							0x48,		1,		0x3E,			0,		"UP" },
{ IDC_K_NUMLOCK,				0x45,		1,		0x47,			0,		"NUM_LOCK" },
{ IDC_K_NUMPAD_DIVIDE,	0x35,		1,		0x4B,			0,		"NUMPAD_DIVIDE" },
{ IDC_K_NUMPAD_MULTIPLE,0x37,		0,		0x43,			0,		"NUMPAD_MULTIPLY" },
{ IDC_K_NUMPAD_MINUS,		0x4A,		0,		0x4E,			0,		"NUMPAD_SUBTRACT" },
{ IDC_K_NUMPAD_7,				0x47,		0,		0x59,			0,		"NUMPAD_7" },
{ IDC_K_NUMPAD_8,				0x48,		0,		0x5B,			0,		"NUMPAD_8" },
{ IDC_K_NUMPAD_9,				0x49,		0,		0x5C,			0,		"NUMPAD_9" },
{ IDC_K_NUMPAD_PLUS,		0x4E,		0,		0x45,			0,		"NUMPAD_ADD" },
{ IDC_K_NUMPAD_4,				0x4B,		0,		0x56,			0,		"NUMPAD_4" },
{ IDC_K_NUMPAD_5,				0x4C,		0,		0x57,			0,		"NUMPAD_5" },
{ IDC_K_NUMPAD_6,				0x4D,		0,		0x58,			0,		"NUMPAD_6" },
{ IDC_K_NUMPAD_1,				0x4F,		0,		0x53,			0,		"NUMPAD_1" },
{ IDC_K_NUMPAD_2,				0x50,		0,		0x54,			0,		"NUMPAD_2" },
{ IDC_K_NUMPAD_3,				0x51,		0,		0x55,			0,		"NUMPAD_3" },
{ IDC_K_NUMPAD_COMMA,		0x53,		0,		0x41,			0,		"NUMPAD_DEL" },
{ IDC_K_NUMPAD_0,				0x52,		0,		0x52,			0,		"NUMPAD_0" },
{ IDC_K_NUMPAD_ENTER,		0x1C,		1,		0x4C,			0,		"NUMPAD_ENTER" },
{ 0,										0,			0,		-1,				1,		"" }
};

void load_key_codes( LPCSTR path, keymap_type *map )
{
	int i = 0, scan_code, extended, mac;
	char buf[100];

	// D(bug("Mac code for scancode 0x%X is 0x%X\r\n", 0x150001, scancode_2_mac(0x150001) ));

	while(keymap[i].dlg_id) {
		::GetPrivateProfileString( "Codes", keymap[i].name, "", buf, sizeof(buf), path );
		if(*buf) {
			if( 3 == sscanf( buf, "0x%02X,%d,0x%02X", &scan_code, &extended, &mac )) {
				keymap[i].scan_code = scan_code;
				keymap[i].extended = extended;
				keymap[i].mac = mac;
			}
		}
		i++;
	}

	// D(bug("Mac code for scancode 0x%X is 0x%X\r\n", 0x150001, scancode_2_mac(0x150001) ));
}

void save_key_codes( LPCSTR path, keymap_type *map )
{
	int i = 0;
	char buf[100];

	::WritePrivateProfileString( "Codes", NULL, buf, path );
	while(keymap[i].dlg_id) {
		wsprintf(
			buf,
			"0x%02X,%d,0x%02X",
			keymap[i].scan_code,
			keymap[i].extended,
			keymap[i].mac
		);
		::WritePrivateProfileString( "Codes", keymap[i].name, buf, path );
		i++;
	}
}


int scancode_2_mac( uint32 lparam )
{
	int i = 0, scan_code, extended, mac = -1;

	scan_code = (lparam >> 16) & 0xFF;
	extended = (lparam >> 24) & 1;

	while(keymap[i].dlg_id) {
		if(keymap[i].scan_code == scan_code && keymap[i].extended == extended) {
			mac = keymap[i].mac;
			if(strcmp(keymap[i].name,"CAPS_LOCK") == 0) {
				int down = (lparam & 0x80000000) == 0;
				if(GetKeyState(VK_CAPITAL) & 1) { // toggled?
					if(!down) mac = -1;
				} else {
					if(down) mac = -1;
				}
			}
			break;
		}
		i++;
	}

	D(bug("Mac code for scancode 0x%X is 0x%X\r\n", lparam, mac ));

	return(mac);
}

int keyname_2_scan_extended( char *name )
{
	int i = 0;
	int ret = 0;

	while(keymap[i].dlg_id) {
		if(strcmp(keymap[i].name,name) == 0) {
			ret = (keymap[i].scan_code << 16) | (keymap[i].extended << 24);
			break;
		}
		i++;
	}

	D(bug("Key code for name %s is 0x%X\r\n", name, ret ));

	return ret;
}
