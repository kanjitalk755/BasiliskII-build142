/*
 *  clip_windows.cpp - Clipboard handling for Win32
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
#include "clip.h"
#include "main_windows.h"
#include "main.h"
#include "cpu_emulation.h"
#include "prefs.h"
#include "clip_windows.h"

#define DEBUG 0
#include "debug.h"

// Conversion tables
static const uint8 mac2iso[0x80] = {
  0xc4, 0xc5, 0xc7, 0xc9, 0xd1, 0xd6, 0xdc, 0xe1,
  0xe0, 0xe2, 0xe4, 0xe3, 0xe5, 0xe7, 0xe9, 0xe8,
  0xea, 0xeb, 0xed, 0xec, 0xee, 0xef, 0xf1, 0xf3,
  0xf2, 0xf4, 0xf6, 0xf5, 0xfa, 0xf9, 0xfb, 0xfc,
  0x2b, 0xb0, 0xa2, 0xa3, 0xa7, 0xb7, 0xb6, 0xdf,
  0xae, 0xa9, 0x20, 0xb4, 0xa8, 0x23, 0xc6, 0xd8,
  0x20, 0xb1, 0x3c, 0x3e, 0xa5, 0xb5, 0xf0, 0x53,
  0x50, 0x70, 0x2f, 0xaa, 0xba, 0x4f, 0xe6, 0xf8,
  0xbf, 0xa1, 0xac, 0x2f, 0x66, 0x7e, 0x44, 0xab,
  0xbb, 0x2e, 0x20, 0xc0, 0xc3, 0xd5, 0x4f, 0x6f,
  0x2d, 0x2d, 0x22, 0x22, 0x60, 0x27, 0xf7, 0x20,
  0xff, 0x59, 0x2f, 0xa4, 0x3c, 0x3e, 0x66, 0x66,
  0x23, 0xb7, 0x2c, 0x22, 0x25, 0xc2, 0xca, 0xc1,
  0xcb, 0xc8, 0xcd, 0xce, 0xcf, 0xcc, 0xd3, 0xd4,
  0x20, 0xd2, 0xda, 0xdb, 0xd9, 0x69, 0x5e, 0x7e,
  0xaf, 0x20, 0xb7, 0xb0, 0xb8, 0x22, 0xb8, 0x20
};

static const uint8 iso2mac[0x80] = {
	0xAD, 0xB0, 0xE2, 0xC4, 0xE3, 0xC9, 0xA0, 0xE0,
	0xF6, 0xE4, 0xDE, 0xDC, 0xCE, 0xB2, 0xB3, 0xB6, 
	0xB7, 0xD4, 0xD5, 0xD2, 0xD3, 0xA5, 0xD0, 0xD1,
	0xF7, 0xAA, 0xDF, 0xDD, 0xCF, 0xBA, 0xFD, 0xD9, 
	0xCA, 0xC1, 0xA2, 0xA3, 0xDB, 0xB4, 0xBD, 0xA4,
	0xAC, 0xA9, 0xBB, 0xC7, 0xC2, 0xF0, 0xA8, 0xF8, 
	0xA1, 0xB1, 0xC3, 0xC5, 0xAB, 0xB5, 0xA6, 0xE1,
	0xFC, 0xC6, 0xBC, 0xC8, 0xF9, 0xDA, 0xD7, 0xC0, 
	0xCB, 0xE7, 0xE5, 0xCC, 0x80, 0x81, 0xAE, 0x82,
	0xE9, 0x83, 0xE6, 0xE8, 0xED, 0xEA, 0xEB, 0xEC, 
	0xF5, 0x84, 0xF1, 0xEE, 0xEF, 0xCD, 0x85, 0xFB,
	0xAF, 0xF4, 0xF2, 0xF3, 0x86, 0xFA, 0xB8, 0xA7, 
	0x88, 0x87, 0x89, 0x8B, 0x8A, 0x8C, 0xBE, 0x8D,
	0x8F, 0x8E, 0x90, 0x91, 0x93, 0x92, 0x94, 0x95, 
	0xFE, 0x96, 0x98, 0x97, 0x99, 0x9B, 0x9A, 0xD6,
	0xBF, 0x9D, 0x9C, 0x9E, 0x9F, 0xFF, 0xB9, 0xD8
};

static bool noclipconvert = false;

/*
 *  Initialization
 */

void ClipInit(void)
{
	noclipconvert = PrefsFindBool("noclipconvert");
}


/*
 *  Deinitialization
 */

void ClipExit(void)
{
	ZeroScrap();
}


char *cvrttype(uint32 type)
{
	static char type_str[5];
	char *p = (char *)&type;
	int i;

	for(i=3; i>=0; i--) {
		type_str[i] = *p++;
	}
	type_str[4] = 0;
	return(type_str);
}

static uint8 *get_scrap_data = 0;
static uint32 get_scrap_data_sz = 0;

void ZeroScrap(void)
{
	if(get_scrap_data) {
		delete [] get_scrap_data;
		get_scrap_data = 0;
		get_scrap_data_sz = 0;
	}
}

void GetTextScrap( uint8 * & data, uint32 &data_sz )
{
	data = get_scrap_data;
	data_sz = get_scrap_data_sz;
}

void NewTextScrap( void )
{
	ZeroScrap();

	if(OpenClipboard(hMainWnd)) {
		HANDLE hClipData;
		if ((hClipData = GetClipboardData(CF_TEXT)) != 0) {
			PTSTR pszClipboard;
			if ((pszClipboard = (PTSTR)GlobalLock(hClipData)) != 0) {
				uint32 length = strlen(pszClipboard);
				if(length) {
					get_scrap_data = new uint8 [length+1];
					if(get_scrap_data) {
						// Convert text from ISO-Latin1 charset to Mac
						uint8 *p = (uint8 *)pszClipboard;
						uint8 *q = get_scrap_data;
						int32 out_length = 0;
						for (uint32 i=0; i<length; i++) {
							uint8 c = *p++;
							if (c < 0x80) {
								if (c == 13 && i < length-1 && *p == 10) {
									p++;
									i++;
								}
							} else {
								// Toshimitsu Tanaka
								if (!noclipconvert) c = iso2mac[c & 0x7f];
							}
							*q++ = c;
							out_length++;
						}
						get_scrap_data_sz = out_length;
					}
				}
				GlobalUnlock(hClipData);
			}
		}
		CloseClipboard();
	}
}

/*
 *  Mac application wrote to clipboard
 */

void PutScrap(uint32 type, void *scrap, int32 length)
{
  D(bug("PutScrap type %08lx (%s), data %08lx, length %ld\n", type, cvrttype(type), scrap, length));

  if (length <= 0)
    return;

  switch (type) {
    case 'TEXT':
			ZeroScrap();

      // Convert text from Mac charset to ISO-Latin1
      uint8 *buf = new uint8[length*2];
      uint8 *p = (uint8 *)scrap;
      uint8 *q = buf;
      int32 out_length = 0;
      for (int i=0; i<length; i++) {
        uint8 c = *p++;
        if (c < 0x80) {
          if (c == 13) {
            *q++ = 13;
            out_length++;
            c = 10;
          }
        } else {
					// Toshimitsu Tanaka
          if (!noclipconvert) c = mac2iso[c & 0x7f];
				}
        *q++ = c;
        out_length++;
      }

      if(OpenClipboard(hMainWnd)) {
        EmptyClipboard();
        HANDLE h = GlobalAlloc( GMEM_MOVEABLE | GMEM_DDESHARE | GMEM_ZEROINIT, out_length+1 );
        if(h) {
          LPSTR lpstr = (LPSTR)GlobalLock(h);
          memcpy( lpstr, buf, out_length );
          lpstr[out_length] = 0;
          GlobalUnlock(h);
          if(!SetClipboardData(CF_TEXT,h)) {
            GlobalFree(h);
          }
        }
        CloseClipboard();
      }

      delete[] buf;
      break;
  }
}
