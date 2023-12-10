/*
 *  typemap.cpp
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
#include "prefs.h"
#include "typemap.h"

ext2type default_e2t_translation[] = {
	{".Z", 'ZIVM', 'LZIV'},
	{".gz", 'Gzip', 'Gzip'},
	{".hqx", 'TEXT', 'SITx'},
	{".pdf", 'PDF ', 'CARO'},
	{".ps", 'TEXT', 'ttxt'},
	{".sit", 'SIT!', 'SITx'},
	{".tar", 'TARF', 'TAR '},
	{".uu", 'TEXT', 'SITx'},
	{".uue", 'TEXT', 'SITx'},
	{".zip", 'ZIP ', 'ZIP '},
	{".8svx", '8SVX', 'SNDM'},
	{".aifc", 'AIFC', 'TVOD'},
	{".aiff", 'AIFF', 'TVOD'},
	{".au", 'ULAW', 'TVOD'},
	{".mid", 'MIDI', 'TVOD'},
	{".midi", 'MIDI', 'TVOD'},
	{".mp2", 'MPG ', 'TVOD'},
	{".mp3", 'MPG ', 'TVOD'},
	{".wav", 'WAVE', 'TVOD'},
	{".bmp", 'BMPf', 'ogle'},
	{".gif", 'GIFf', 'ogle'},
	{".lbm", 'ILBM', 'GKON'},
	{".ilbm", 'ILBM', 'GKON'},
	{".jpg", 'JPEG', 'ogle'},
	{".jpeg", 'JPEG', 'ogle'},
	{".pict", 'PICT', 'ogle'},
	{".png", 'PNGf', 'ogle'},
	{".sgi", '.SGI', 'ogle'},
	{".tga", 'TPIC', 'ogle'},
	{".tif", 'TIFF', 'ogle'},
	{".tiff", 'TIFF', 'ogle'},
	{".htm", 'TEXT', 'MOSS'},
	{".html", 'TEXT', 'MOSS'},
	{".txt", 'TEXT', 'ttxt'},
	{".rtf", 'TEXT', 'MSWD'},
	{".c", 'TEXT', 'CWIE'},
	{".cc", 'TEXT', 'CWIE'},
	{".cp", 'TEXT', 'CWIE'},
	{".cpp", 'TEXT', 'CWIE'},
	{".cxx", 'TEXT', 'CWIE'},
	{".h", 'TEXT', 'CWIE'},
	{".hh", 'TEXT', 'CWIE'},
	{".hpp", 'TEXT', 'CWIE'},
	{".hxx", 'TEXT', 'CWIE'},
	{".s", 'TEXT', 'CWIE'},
	{".i", 'TEXT', 'CWIE'},
	{".mpg", 'MPEG', 'TVOD'},
	{".mpeg", 'MPEG', 'TVOD'},
	{".mov", 'MooV', 'TVOD'},
	{".fli", 'FLI ', 'TVOD'},
	{".avi", 'VfW ', 'TVOD'},
	{".qxd", 'XDOC', 'XPR3'},
	{".hfv", 'DDim', 'ddsk'},
	{".dsk", 'DDim', 'ddsk'},
	{".img", 'rohd', 'ddsk'},
	{"", 0, 0}	// End marker
};

ext2type *e2t_translation = 0;
static bool e2t_allocated = false;

void get_typemap_file_name( HINSTANCE h, char *path )
{
	const char *user_path = PrefsFindString("typemapfile");
	if(user_path) {
		strcpy( path, user_path );
	} else {
		GetModuleFileName( (HMODULE)h, path, _MAX_PATH );
		char *p = strrchr( path, '\\' );
		if(p) {
			*(++p) = 0;
		} else {
			*path = 0;
		}
		strcat( path, "BasiliskII.ftm" );
	}
}

void final_type_map( void )
{
	if(e2t_allocated) {
		free(e2t_translation);
		e2t_translation = 0;
	}
}

void myquote( unsigned char *buf, BOOL encode )
{
	int i, len = strlen((char *)buf), tmplen;
	unsigned char tmp[100];

	if(encode) {
		for( i=len-1; i>=0; i-- ) {
			if(buf[i] < 32 || buf[i] > 127 || buf[i] == '\\') {
				wsprintf( (char *)tmp, "\\%03d", (int)buf[i] );
				tmplen = strlen((char *)tmp); // always 4...
				memmove( &buf[i+tmplen], &buf[i+1], strlen((char *)&buf[i+1])+1 );
				memmove( (char *)&buf[i], (char *)tmp, tmplen );
			}
		}
	} else {
		for( i=len-1; i>=0; i-- ) {
			// "\006..."
			if(buf[i] == '\\' && strlen((char *)&buf[i]) >= 4) {
				buf[i] = (unsigned char)atoi((char *)&buf[i+1]);
				memmove( &buf[i+1], &buf[i+4], strlen((char *)&buf[i+4])+1 );
			}
		}
	}
}

// hqx,,TEXT,SITx,,x,"Default translation"
static bool parse_line( unsigned char *s, int i )
{
	int c = 1;

	e2t_translation[i].ext[0] = '.';
	while( *s >= ' ' && *s != ',' && c < 14 ) {
		e2t_translation[i].ext[c++] = *s++;
	}
	e2t_translation[i].ext[c] = 0;

	if(*s != ',') return false;
	s++;

	if(*s == 'x') s++;

	if(*s != ',') return false;
	s++;

	if(s[4] != ',') return false;
	e2t_translation[i].type =
			((unsigned long)s[0] << 24) |
			((unsigned long)s[1] << 16) |
			((unsigned long)s[2] <<  8) |
			((unsigned long)s[3] <<  0);
	s += 5;

	if(s[4] != ',') return false;
	e2t_translation[i].creator =
			((unsigned long)s[0] << 24) |
			((unsigned long)s[1] << 16) |
			((unsigned long)s[2] <<  8) |
			((unsigned long)s[3] <<  0);

	return true;
}

void init_type_map( HINSTANCE h )
{
	char path[_MAX_PATH];
	get_typemap_file_name( h, path );

	int count = 0;
	FILE *f = fopen(path,"r");

  if(f) {
		e2t_allocated = true;
		int alloc_items = 100;
		int alloc_sz = alloc_items * sizeof(struct ext2type);
		e2t_translation = (struct ext2type *)malloc(alloc_sz);

		if(e2t_translation) {
			char line[256];
			char *linebuf = (char *)malloc( 1000 );
			while(fgets(line, 255, f)) {
				strcpy( linebuf, line );
				myquote((unsigned char *)linebuf,FALSE);
				if(count >= alloc_items) {
					alloc_items += 10;
					alloc_sz = alloc_items * sizeof(struct ext2type);
					e2t_translation = (struct ext2type *)realloc(e2t_translation,alloc_sz);
					if(!e2t_translation) {
						count = 0;
						break;
					}
				}
				if(parse_line( (unsigned char *)linebuf, count )) count++;
			}
			free(linebuf);
		}
		fclose(f);
	}
	if(count == 0) {
		e2t_allocated = false;
		if(e2t_translation) free(e2t_translation);
		e2t_translation = default_e2t_translation;
	}
}
