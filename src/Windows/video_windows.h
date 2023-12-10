/*
 *  video_windows.h - Startup code for Win32
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

#ifndef _VIDEO_WINDOWS_H_
#define _VIDEO_WINDOWS_H_

void Screen_Draw_All( HWND hWnd );
int update_palette();
void video_activate( bool activate );
void video_update_focus( bool has_focus );
bool is_screen_inited(void);
char *get_wnd_class_name(void);
void save_window_position( int width, int height, int x, int y );
void save_ontop( void );
void toggle_full_screen_mode( void );
void get_video_mode(
	int &width, 
	int &height, 
	int &depth_mac, 
	int &depth_win
);
int calc_bytes_per_row( int width, int depth );

enum {
	FB_NONE = 0, FB_QUIT,
	FB_SETPALETTE, FB_UPDATEPALETTE,
	FB_LOCK, FB_UNLOCK
};
void fb_command( uint8 cmd, LPBYTE param, uint32 sz );

extern bool classic_mode;

// Current palette in "MacOS values".
extern uint8 current_mac_palette[256*3];

// Need to export this for 8bit address space mapping
extern uint8 *the_buffer;

// Display types
enum {
  DISPLAY_WINDOW, // GDI
  DISPLAY_DX,			// DirectX full screen
  DISPLAY_FB      // Linear frame buffer
};
extern int display_type;

extern int is_windowed;
extern int is_ontop;

#endif // _VIDEO_WINDOWS_H_
