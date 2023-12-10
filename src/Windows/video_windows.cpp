/*
 *  video_windows.cpp - Video/graphics emulation for Win32
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
#include "m68k.h"
#include "memory.h"
#include "readcpu.h"
#include "newcpu.h"
#include "main.h"
#include "adb.h"
#include "prefs.h"
#include "user_strings.h"
#include "macos_util.h"
#include "cpu_emulation.h"
#include "main_windows.h"
#include "video_windows.h"
#include "desktop_windows.h"
#include "threads_windows.h"
#include "kernel_windows.h"
#include "video.h"
#include <winnt.h>
// #define INITGUID
#include <ddraw.h>
#include <d3d.h>
#include <process.h>

#include "resource.h"


#define DEBUG 0
#include "debug.h"

#ifndef _DEBUG

// #define BITMAPPED_PAGE_FLAGS

#ifdef BITMAPPED_PAGE_FLAGS
#define PFLAG_SET(page)				mainBuffer.bits[(page)>>5] |= ( (DWORD32)1 << ((page) & 31))
#define PFLAG_CLEAR(page)			mainBuffer.bits[(page)>>5] &= ~((DWORD32)1 << ((page) & 31))
#define PFLAG_ISSET(page)			(mainBuffer.bits[(page)>>5] & ((DWORD32)1 << ((page) & 31)))
#define PFLAG_ISCLEAR(page)		((mainBuffer.bits[(page)>>5] & ((DWORD32)1 << ((page) & 31))) == 0)
#else
#define PFLAG_SET(page)				mainBuffer.bits[page] = 1
#define PFLAG_CLEAR(page)			mainBuffer.bits[page] = 0
#define PFLAG_ISSET(page)			mainBuffer.bits[page]
#define PFLAG_ISCLEAR(page)		(mainBuffer.bits[page] == 0)
#define PFLAG_ISCLEAR_4(page)	( *((DWORD *)&mainBuffer.bits[page]) == 0)

#endif
#define PFLAG_CLEAR_ALL			memset( mainBuffer.bits, 0, sizeof(mainBuffer.bits) )


#endif


// Some people may have outdated Platform SDK.
#ifndef MEM_WRITE_WATCH
#define MEM_WRITE_WATCH    0x200000
#endif

#ifndef WRITE_WATCH_FLAG_RESET
#define WRITE_WATCH_FLAG_RESET 1
#endif



int sz_the_buffer;

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
static uint8 *host_screen = 0;
#endif

static char *window_class = "Basilisk II MainWndClass";

static int screen_bit_depth_win;
static int screen_bit_depth_mac;

static BOOL log_faults = false;

int is_windowed = false;

// Flag: Classic Mac video mode
bool classic_mode = false;

int m_has_caption;

int is_ontop = 0;

// Usually (but not always) it's best to use palette index
// and not explicit rgb values on 8bit devices
static DWORD bPalette = DIB_PAL_COLORS;

// Used to determine do we need to release frame buffer lock.
static bool dx_blits_allowed = true;

// Platform specific: size of the virtual memory page.
#define VM_PAGE_BYTES       4096
#define VM_PAGE_BITS        12
#define VM_PAGE_ALIGN_MASK  0xFFFFF000
#define VM_PAGE_MODULO_BITS 0xFFF


// Mac specific: screen size
#define SCREEN_BYTES    scanlines[VideoMonitor.y]
#define SCREEN_MAX_X    VideoMonitor.x
#define SCREEN_MAX_Y    VideoMonitor.y
#define SCANLINE_BYTES  VideoMonitor.bytes_per_row

// How many virtual memory pages per Mac screen?.
// This just needs to be large enough. Should really be calculated
// using display attributes, fix it if you want
#define MAX_PAGES_PER_SCREEN 5000

// Current palette in "MacOS values".
uint8 current_mac_palette[256*3];

int display_type = DISPLAY_WINDOW;

#define MAX_SCAN_LINES 2500

typedef struct {
  int top, bottom;  // Mapping between this virtual page and Mac scan lines
} ScreenPageInfo;

typedef struct {
  DWORD memBase,			// Real start address of this Mac screen page
        memStart,			// Start address aligned to nearest page boundary
											// (Note that nowadays base and start are always the same)
        memEnd,				// Address of the first byte not belonging to the screen pages
        memLength,		// Length of the memory addressed by the screen pages
				memLastPage,	// Index of last virtual page.
				memInvalExtraPages; // When a page faults, invalidate memInvalExtraPages+1 pages.
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
	DWORD memStartAlt;
#endif

	// Seems to be faster when not bitmapped
#ifdef BITMAPPED_PAGE_FLAGS
  DWORD32 bits[MAX_PAGES_PER_SCREEN/sizeof(DWORD32)];
#else
	BYTE bits[MAX_PAGES_PER_SCREEN];
#endif
  DWORD32 last_pages[MAX_PAGES_PER_SCREEN];

	int dirty;
	int very_dirty;
  ScreenPageInfo pages[MAX_PAGES_PER_SCREEN];
} ScreenInfo;

static ScreenInfo mainBuffer;

// Global variables
static bool screen_inited = 0;

// How many msecs to sleep between screen refreshes
static int32 sleep_ticks = 30;

static bool m_show_real_fps = false;

uint8 *the_buffer = 0;

static HPALETTE hPalMain = 0;
static HPALETTE hPalMain2bits = 0;

static LPBITMAPINFO pbmi = 0;
static LPLOGPALETTE lppal = 0;
static LPLOGPALETTE lppal2bits = 0;


static CRITICAL_SECTION draw_csection;
static CRITICAL_SECTION fb_csection;

LPTOP_LEVEL_EXCEPTION_FILTER old_exception_filter = 0;

int scanlines[MAX_SCAN_LINES];

int dx_scanlines[MAX_SCAN_LINES];
int dx_pitch = 1024;
BOOL equal_scanline_lengths = FALSE;

int dx_refresh_rate	= 0;

#pragma pack(1)
typedef struct {
	BYTE red, green, blue;
} macpal_type;
#pragma pack()

typedef struct {
	int32 diff;
	uint32 inx;
} macpal_inx;


// Prototypes
unsigned int WINAPI redraw_thread(LPVOID param);
unsigned int WINAPI redraw_thread_d3d(LPVOID param);
unsigned int WINAPI redraw_thread_d3d_fullscreen(LPVOID param);
unsigned int WINAPI redraw_thread_fb(LPVOID param);
void video_set_palette2(uint8 *pal);
LONG WINAPI Screen_fault_proc( struct _EXCEPTION_POINTERS *ExceptionInfo );
LONG WINAPI Screen_fault_proc_opt( struct _EXCEPTION_POINTERS *ExceptionInfo );


static uint8 fb_current_command = FB_NONE;
HANDLE fb_signal = 0;
HANDLE fb_reply = 0;

static inline void grab_draw_mutex(void)
{
	EnterCriticalSection( &draw_csection );
}

static inline void release_draw_mutex(void)
{
	LeaveCriticalSection( &draw_csection );
}

// Need to be inside critical section already
static void __inline__ set_very_dirty( void )
{
	if(!classic_mode) {
		// No need to optimize this
		for( DWORD page=0; page<=mainBuffer.memLastPage; page++ ) {
			PFLAG_SET(page);
		}
	}

	mainBuffer.dirty = 1;
	mainBuffer.very_dirty = 1;

  if (pfnGetWriteWatch) {
		// Compiler should not optimize this away
		*the_buffer ^= (uint8)255;
		*the_buffer ^= (uint8)255;
	}
}

#define MAX_WRITE_WATCH_PAGES 4096
static DWORD rglAddr[MAX_WRITE_WATCH_PAGES];

static void Screen_Setup_fault_handler(void)
{
  DWORD a, i, y1, y2;

  mainBuffer.memBase  = (DWORD)the_buffer;
  mainBuffer.memStart = mainBuffer.memBase & VM_PAGE_ALIGN_MASK;
  mainBuffer.memEnd   = mainBuffer.memBase + SCREEN_BYTES;
  if(mainBuffer.memEnd & VM_PAGE_MODULO_BITS) mainBuffer.memEnd = (mainBuffer.memEnd | VM_PAGE_MODULO_BITS) + 1;
  mainBuffer.memLength = mainBuffer.memEnd - mainBuffer.memStart;
	mainBuffer.memLastPage = mainBuffer.memLength / VM_PAGE_BYTES - 1;
	mainBuffer.memInvalExtraPages = (SCANLINE_BYTES * 16) / VM_PAGE_BYTES;

	PFLAG_CLEAR_ALL;
	mainBuffer.dirty = 0;
	mainBuffer.very_dirty = 0;

  a = 0;
  for(i=0; i<(unsigned int)MAX_PAGES_PER_SCREEN; i++) {

		mainBuffer.last_pages[i] = i + mainBuffer.memInvalExtraPages;
		if(mainBuffer.last_pages[i] > mainBuffer.memLastPage) {
			mainBuffer.last_pages[i] = mainBuffer.memLastPage;
		}

		y1 = a / (int)SCANLINE_BYTES;
		y2 = (a+VM_PAGE_BYTES) / (int)SCANLINE_BYTES;
		if(y1 >= (int)VideoMonitor.y) y1 = (int)VideoMonitor.y - 1;
		if(y2 >= (int)VideoMonitor.y) y2 = (int)VideoMonitor.y - 1;
    mainBuffer.pages[i].top = y1;
    mainBuffer.pages[i].bottom = y2;
    a += VM_PAGE_BYTES;
  }

	if(pfnGetWriteWatch) {
		old_exception_filter = SetUnhandledExceptionFilter( (LPTOP_LEVEL_EXCEPTION_FILTER)Screen_fault_proc_opt );
	} else {
		old_exception_filter = SetUnhandledExceptionFilter( (LPTOP_LEVEL_EXCEPTION_FILTER)Screen_fault_proc );
	}
}

/*
 *  Initialization
 */

// Set VideoMonitor according to video mode
static void set_video_monitor(int width, int height, int depth_win, int depth_mac, int bytes_per_row)
{
	/*
	char b[256];
	sprintf( b, "set_video_monitor( %d, %d, %d, %d, %d )\r\n", width, height, depth_win, depth_mac, bytes_per_row );
	OutputDebugString(b);
	*/

	screen_bit_depth_win = depth_win;
	screen_bit_depth_mac = depth_mac;

  switch (depth_mac) {
    case 1:
      MacFrameLayout = FLAYOUT_DIRECT;
      VideoMonitor.mode = VMODE_1BIT;
      break;
    case 2:
      MacFrameLayout = FLAYOUT_DIRECT;
      VideoMonitor.mode = VMODE_2BIT;
      break;
    case 4:
      MacFrameLayout = FLAYOUT_DIRECT;
      VideoMonitor.mode = VMODE_4BIT;
      break;
    case 8:
      MacFrameLayout = FLAYOUT_DIRECT;
      VideoMonitor.mode = VMODE_8BIT;
      break;
    case 15:
      MacFrameLayout = FLAYOUT_HOST_555;
      VideoMonitor.mode = VMODE_16BIT;
      break;
    case 16:
			MacFrameLayout = FLAYOUT_HOST_565;
      VideoMonitor.mode = VMODE_16BIT;
      break;
    case 24:
      MacFrameLayout = FLAYOUT_HOST_888;
      VideoMonitor.mode = VMODE_32BIT;
      break;
    case 32:
      MacFrameLayout = FLAYOUT_HOST_888;
      VideoMonitor.mode = VMODE_32BIT;
      break;
  }
  VideoMonitor.x = width;
  VideoMonitor.y = height;
  VideoMonitor.bytes_per_row = bytes_per_row;

	for( int i=0; i<MAX_SCAN_LINES; i++ ) {
		scanlines[i] = bytes_per_row * i;
	}
}

int calc_bytes_per_row( int width, int depth )
{
	if(depth == 15) depth = 16;
  return width * depth / 8;
}

// Init window mode
static bool init_window(int width, int height, int depth_mac, int depth_win)
{
  bool retval = (the_buffer && lppal);

	bPalette = (depth_win <= 8) ? DIB_PAL_COLORS : DIB_RGB_COLORS;

  if(!retval) {
		if(lppal) {
			free(lppal);
			lppal = 0;
		}
  }

	MacFrameBaseHost = the_buffer;

  return ( retval );
}

static LPDIRECTDRAW lpDD = 0;
static DDSURFACEDESC ddsd;
static LPDIRECTDRAWSURFACE lpDDSPrimary = 0;
static LPDIRECTDRAWPALETTE	lpDDPal = 0;

#define DDPALETTE (DDPCAPS_ALLOW256|DDPCAPS_INITIALIZE|DDPCAPS_8BIT)

static DDPIXELFORMAT dx_15_pixel_format =
  {sizeof(DDPIXELFORMAT), DDPF_RGB, 0, 16,  0x7C00, 0x03e0, 0x001F, 0};

static DDPIXELFORMAT dx_16_pixel_format =
  {sizeof(DDPIXELFORMAT), DDPF_RGB, 0, 16,  0xF800, 0x07e0, 0x001F, 0};


static HRESULT restoreAll( void )
{
  HRESULT	ddrval;

	if(display_type == DISPLAY_DX) {
		if(!dx_blits_allowed || !b2_is_front_window()) return DDERR_CANTLOCKSURFACE;
	}

	ddrval = lpDDSPrimary->Restore();
	if( ddrval == DD_OK ) {
		if(lpDDPal) {
			lpDDSPrimary->SetPalette(0);
			lpDDPal->Release();
			lpDD->CreatePalette( DDPALETTE, lppal->palPalEntry, &lpDDPal, NULL );
			lpDDSPrimary->SetPalette(lpDDPal);
		}
	}

  return ddrval;
}

static void finiObjects( void )
{
	if( lpDD ) {
		if(fb_signal) {
			fb_command( FB_QUIT, 0, 0 );
			CloseHandle(fb_signal);
			CloseHandle(fb_reply);
			fb_signal = 0;
			fb_reply = 0;
		}
		if( lpDDPal ) {
			if(lpDDSPrimary) lpDDSPrimary->SetPalette(0);
			lpDDPal->Release();
			lpDDPal = NULL;
		}
		if( lpDDSPrimary ) {
			lpDDSPrimary->Release();
			lpDDSPrimary = NULL;
		}
		lpDD->Release();
		lpDD = NULL;
	}
}

static DWORD count_bits( DWORD x )
{
	DWORD count = 0, i;

	for( i=0; i<32; i++ ) {
		if( x & (1 << i) ) count++;
	}
	return count;
}

static HRESULT mySetDisplayMode2( LPDIRECTDRAW lpDD, int width, int height, int &depth_win )
{
	LPDIRECTDRAW2 lpDD4 = 0;

  HRESULT ddrval = lpDD->QueryInterface( IID_IDirectDraw4, (void **)&lpDD4 );

	if(ddrval == DD_OK) {
		ddrval = lpDD4->SetDisplayMode( width, height, depth_win, dx_refresh_rate, 0 );
		if(ddrval != DD_OK && (depth_win == 15 || depth_win == 16)) {
			int depth = depth_win == 16 ? 15 : 16;
			ddrval = lpDD4->SetDisplayMode( width, height, depth, dx_refresh_rate, 0 );
			if(ddrval == DD_OK) {
				depth_win = depth;
			}
		}
    lpDD4->Release();
	}

	return ddrval;
}

static HRESULT mySetDisplayMode( LPDIRECTDRAW lpDD, int width, int height, int &depth_win )
{
	HRESULT ddrval = -1;

	if(!b2_is_front_window()) return DDERR_CANTLOCKSURFACE;

	if(dx_refresh_rate == 0)
		ddrval = -1;
	else
		ddrval = mySetDisplayMode2( lpDD, width, height, depth_win );

	if(ddrval != DD_OK) {
		ddrval = lpDD->SetDisplayMode( width, height, depth_win );
		if(ddrval != DD_OK && (depth_win == 15 || depth_win == 16)) {
			int depth = depth_win == 16 ? 15 : 16;
			ddrval = lpDD->SetDisplayMode( width, height, depth );
			if(ddrval == DD_OK) {
				depth_win = depth;
			}
		}
	}
	return ddrval;
}

// Init DX display
static bool init_dx(
	int width,
	int height,
	int &depth_mac,
	int &depth_win,
	char *error_str
)
{
	HRESULT ddrval;
	int i;

	const char *refresh_rate_str = PrefsFindString("DX_fullscreen_refreshrate");
  if(refresh_rate_str) {
		dx_refresh_rate = atoi(refresh_rate_str);
	} else {
		dx_refresh_rate = 0;
	}

	/*
	printf(
		"init_dx(width=%d, height=%d, depth_mac=%d, depth_win=%d)\r\n",
		width, height, depth_mac, depth_win
	);
	*/

	if(classic_mode) {
		width = 640;
		height = 480;
		depth_win = 8;
	}

	*error_str = 0;

	finiObjects();

  ddrval = DirectDrawCreate( NULL, &lpDD, NULL );
  if( ddrval != DD_OK ) {
		sprintf( error_str, "DirectDrawCreate failed (error code 0x%08X)", ddrval );
    finiObjects();
		return(false);
  }

	if(is_windowed) {
		ddrval = lpDD->SetCooperativeLevel( hMainWnd, DDSCL_NORMAL );
	} else {
		ddrval = lpDD->SetCooperativeLevel( hMainWnd, DDSCL_EXCLUSIVE|DDSCL_FULLSCREEN|DDSCL_ALLOWREBOOT );
		if( ddrval != DD_OK ) {
	    finiObjects();
			ddrval = DirectDrawCreate( NULL, &lpDD, NULL );
			if( ddrval == DD_OK ) {
				ddrval = lpDD->SetCooperativeLevel( hMainWnd, DDSCL_EXCLUSIVE|DDSCL_FULLSCREEN|DDSCL_ALLOWREBOOT );
			}
		}
	}
  if( ddrval != DD_OK ) {
		if(is_windowed)
			sprintf( error_str, "SetCooperativeLevel (windowed mode) failed (error code 0x%08X)", ddrval );
		else
			sprintf( error_str, "SetCooperativeLevel (full screen mode) failed (error code 0x%08X)", ddrval );
    finiObjects();
		return(false);
  }

	if(!is_windowed) {
		ddrval = mySetDisplayMode( lpDD, width, height, depth_win );
		if(ddrval != DD_OK) {
			sprintf( error_str, "SetDisplayMode(%d,%d,%d) failed (error code 0x%08X)", width, height, depth_win, ddrval );
			finiObjects();
			return(false);
		}
  }

	memset( &ddsd, 0, sizeof(ddsd) );
  ddsd.dwSize = sizeof( ddsd );
	ddsd.dwFlags = DDSD_CAPS;
	ddsd.ddsCaps.dwCaps = DDSCAPS_PRIMARYSURFACE|DDSCAPS_VIDEOMEMORY;
	if(depth_mac == 15) {
		ddsd.ddsCaps.dwCaps |= DDSD_PIXELFORMAT;
    ddsd.ddpfPixelFormat = dx_15_pixel_format;
	} else if(depth_mac == 16) {
		ddsd.ddsCaps.dwCaps |= DDSD_PIXELFORMAT;
    ddsd.ddpfPixelFormat = dx_16_pixel_format;
	}

  ddrval = lpDD->CreateSurface( &ddsd, &lpDDSPrimary, NULL );
  if( ddrval != DD_OK ) {
		ddsd.ddsCaps.dwCaps = DDSCAPS_PRIMARYSURFACE;
		ddrval = lpDD->CreateSurface( &ddsd, &lpDDSPrimary, NULL );
		if( ddrval != DD_OK ) {
			sprintf( error_str, "CreateSurface (%d,%d,%d) failed (error code 0x%08X)", width, height, depth_win, ddrval );
			finiObjects();
			return(false);
		}
	}

	if(depth_mac <= 8) {
		for ( i = 0; i < 256; i++ ) {
			lppal->palPalEntry[i].peRed = 0;
			lppal->palPalEntry[i].peGreen = 0;
			lppal->palPalEntry[i].peBlue = 0;
			lppal->palPalEntry[i].peFlags = D3DPAL_FREE;
		}
#define CLASSIC_BK_GRAY 0
		if(classic_mode) {
			lppal->palPalEntry[0].peRed = 255;
			lppal->palPalEntry[0].peGreen = 255;
			lppal->palPalEntry[0].peBlue = 255;
			lppal->palPalEntry[1].peRed = 0;
			lppal->palPalEntry[1].peGreen = 0;
			lppal->palPalEntry[1].peBlue = 0;
			lppal->palPalEntry[2].peRed = CLASSIC_BK_GRAY;
			lppal->palPalEntry[2].peGreen = CLASSIC_BK_GRAY;
			lppal->palPalEntry[2].peBlue = CLASSIC_BK_GRAY;
			macpal_type *pp  = (macpal_type *)current_mac_palette;
			pp[0].red = 255;
			pp[0].green = 255;
			pp[0].blue = 255;
			pp[1].red = 0;
			pp[1].green = 0;
			pp[1].blue = 0;
			pp[2].red = CLASSIC_BK_GRAY;
			pp[2].green = CLASSIC_BK_GRAY;
			pp[2].blue = CLASSIC_BK_GRAY;
		}
		lpDD->CreatePalette( DDPALETTE, lppal->palPalEntry, &lpDDPal, NULL );
		if(lpDDPal) {
			ddrval = lpDDSPrimary->SetPalette(lpDDPal);
		}
	}

	ddrval = lpDDSPrimary->GetSurfaceDesc( &ddsd );
  if( ddrval != DD_OK ) {
		sprintf( error_str, "GetSurfaceDesc (%d,%d,%d) failed (error code 0x%08X)", width, height, depth_win, ddrval );
    finiObjects();
		return(false);
  }

	if(depth_mac == 15 || depth_mac == 16) {
		DWORD depth, red, green, blue;

    red = ddsd.ddpfPixelFormat.dwRBitMask;
    green = ddsd.ddpfPixelFormat.dwGBitMask;
    blue = ddsd.ddpfPixelFormat.dwBBitMask;

		depth = count_bits(red) + count_bits(green) + count_bits(blue);

		/*
		printf(
			"red=%X, green=%X, blue=%X, redbits=%d, greenbits=%d, bluebits=%d, depth=%d\r\n",
			red, green, blue,
			count_bits(red), count_bits(green), count_bits(blue),
			depth
		);
		*/

		if(depth == 15) {
			depth_mac = depth_win = 15;
		} else if(depth == 16) {
			depth_mac = depth_win = 16;
		}

		*(DWORD *)&pbmi->bmiColors[0] = red;
		*(DWORD *)&pbmi->bmiColors[1] = green;
		*(DWORD *)&pbmi->bmiColors[2] = blue;
	}

	dx_pitch = ddsd.lPitch;
	for( i=0; i<MAX_SCAN_LINES; i++ ) {
		dx_scanlines[i] = dx_pitch * i;
	}

  MacFrameBaseHost = the_buffer;

	bPalette = DIB_RGB_COLORS;

	dx_blits_allowed = true;

  return true;
}

static bool init_fb(
	int width,
	int height,
	int depth_mac,
	int depth_win,
	char *error_str
)
{
	HRESULT ddrval;
	int i;

	*error_str = 0;

  ddrval = DirectDrawCreate( NULL, &lpDD, NULL );
  if( ddrval != DD_OK ) {
		sprintf( error_str, "DirectDrawCreate failed (error code 0x%08X)", ddrval );
    finiObjects();
		return(false);
  }
	for( int attempt=0; attempt<10; attempt++ ) {
	  ddrval = lpDD->SetCooperativeLevel( hMainWnd, DDSCL_EXCLUSIVE|DDSCL_FULLSCREEN|DDSCL_ALLOWREBOOT|DDSCL_NOWINDOWCHANGES );
		if( ddrval == DD_OK ) break;
		Sleep(100);
	}
  if( ddrval != DD_OK ) {
		sprintf( error_str, "SetCooperativeLevel (LFB) failed (error code 0x%08X)", ddrval );
    finiObjects();
		return(false);
  }
  ddrval = mySetDisplayMode( lpDD, width, height, depth_win );
  if(ddrval != DD_OK) {
		sprintf( error_str, "SetDisplayMode(%d,%d,%d) failed (error code 0x%08X)", width, height, depth_win, ddrval );
    finiObjects();
		return(false);
  }

	memset( &ddsd, 0, sizeof(ddsd) );
  ddsd.dwSize = sizeof( ddsd );
	ddsd.dwFlags = DDSD_CAPS;
	ddsd.ddsCaps.dwCaps = DDSCAPS_PRIMARYSURFACE|DDSCAPS_VIDEOMEMORY;

  ddrval = lpDD->CreateSurface( &ddsd, &lpDDSPrimary, NULL );
  if( ddrval != DD_OK ) {
		ddsd.ddsCaps.dwCaps = DDSCAPS_PRIMARYSURFACE;
		ddrval = lpDD->CreateSurface( &ddsd, &lpDDSPrimary, NULL );
		if( ddrval != DD_OK ) {
			sprintf( error_str, "CreateSurface (%d,%d,%d) failed (error code 0x%08X)", width, height, depth_win, ddrval );
			finiObjects();
			return(false);
		}
	}

	if(depth_mac <= 8) {
		for ( i = 0; i < 256; i++) {
			lppal->palPalEntry[i].peRed = 0;
			lppal->palPalEntry[i].peGreen = 0;
			lppal->palPalEntry[i].peBlue = 0;
			lppal->palPalEntry[i].peFlags = D3DPAL_FREE;
		}
		lpDD->CreatePalette( DDPALETTE, lppal->palPalEntry, &lpDDPal, NULL );
		if(lpDDPal) {
			lpDDSPrimary->SetPalette(lpDDPal);
		}
	}

	ddrval = lpDDSPrimary->GetSurfaceDesc( &ddsd );
  if( ddrval != DD_OK ) {
		sprintf( error_str, "GetSurfaceDesc (%d,%d,%d) failed (error code 0x%08X)", width, height, depth_win, ddrval );
    finiObjects();
		return(false);
  }

	if(depth_mac == 15 || depth_mac == 16) {
		DWORD depth, red, green, blue;

    red = ddsd.ddpfPixelFormat.dwRBitMask;
    green = ddsd.ddpfPixelFormat.dwGBitMask;
    blue = ddsd.ddpfPixelFormat.dwBBitMask;

		depth = count_bits(red) + count_bits(green) + count_bits(blue);

		/*
		printf(
			"red=%X, green=%X, blue=%X, redbits=%d, greenbits=%d, bluebits=%d, depth=%d\r\n",
			red, green, blue,
			count_bits(red), count_bits(green), count_bits(blue),
			depth
		);
		*/

		if(depth == 15) {
			depth_mac = depth_win = 15;
		} else if(depth == 16) {
			depth_mac = depth_win = 16;
		}

		*(DWORD *)&pbmi->bmiColors[0] = red;
		*(DWORD *)&pbmi->bmiColors[1] = green;
		*(DWORD *)&pbmi->bmiColors[2] = blue;
	}

  MacFrameBaseHost = the_buffer;

	bPalette = DIB_RGB_COLORS;

	dx_pitch = ddsd.lPitch;

  return true;
}

char *get_wnd_class_name(void)
{
	return(window_class);
}

void save_window_position( int width, int height, int x, int y )
{
	char entry[100], position[100];

	if(x < 0) x = 0;
	if(y < 0) y = 0;
	if(x > GetSystemMetrics(SM_CXSCREEN) - 20) x = GetSystemMetrics(SM_CXSCREEN) - 20;
	if(y > GetSystemMetrics(SM_CYSCREEN) - 20) y = GetSystemMetrics(SM_CYSCREEN) - 20;

	sprintf( entry, "%dx%d", width, height );
	sprintf( position, "%d,%d", x, y );
	WritePrivateProfileString( "Window Positions", entry, position, ini_file_name );
}

void save_ontop( void )
{
	WritePrivateProfileString( "Window Positions", "AlwaysOnTop", is_ontop ? "true" : "false", ini_file_name );
}

void get_ontop( void )
{
	char tmp[100];

	GetPrivateProfileString( "Window Positions", "AlwaysOnTop", "false", tmp, sizeof(tmp), ini_file_name );
	is_ontop = stricmp(tmp,"true") == 0;
}

void get_window_position( int width, int height, int *x, int *y )
{
	char entry[100], position[100];
	int left, top;

	sprintf( entry, "%dx%d", width, height );
	GetPrivateProfileString( "Window Positions", entry, "", position, sizeof(position), ini_file_name );
	if(2 == sscanf(position, "%d,%d", &left, &top )) {
		*x = left;
		*y = top;
		if(*x < 0) *x = 0;
		if(*y < 0) *y = 0;
		if(*x > GetSystemMetrics(SM_CXSCREEN) - 20) *x = GetSystemMetrics(SM_CXSCREEN) - 20;
		if(*y > GetSystemMetrics(SM_CYSCREEN) - 20) *y = GetSystemMetrics(SM_CYSCREEN) - 20;
	} else {
		*x = 0;
		*y = 0;
	}
}

static void update_window_size( DWORD style, int width, int height )
{
	if(is_windowed) {
		RECT cr, wr;
		int dx, dy;
		GetWindowRect( hMainWnd, &wr );
		GetClientRect( hMainWnd, &cr );
		dx = wr.right - wr.left;
		dy = wr.bottom - wr.top;
		dx += width - (cr.right - cr.left);
		dy += height - (cr.bottom - cr.top);
		SetWindowPos( hMainWnd, 0, 0, 0, dx, dy, SWP_NOZORDER|SWP_NOMOVE );
	}
}

static void update_zorder(void)
{
	if(is_windowed) {
		HWND after;
		get_ontop();
		if(is_ontop) {
			after = HWND_TOPMOST;
		} else {
			after = HWND_NOTOPMOST;
		}
		SetWindowPos( hMainWnd, after, 0, 0, 0, 0, SWP_NOSIZE|SWP_NOMOVE );
	}
}

static bool create_window( int width, int height )
{
	WNDCLASSEX wc;
	int x, y, w, h;
	DWORD style;

	memset( &wc, 0, sizeof(wc) );
	wc.cbSize = sizeof(wc);
	wc.hbrBackground = (HBRUSH)GetStockObject(GRAY_BRUSH);
	wc.hInstance = hInst;
	wc.lpfnWndProc = MainWndProc;
	wc.lpszClassName = window_class;
	wc.style = CS_HREDRAW|CS_VREDRAW|CS_BYTEALIGNCLIENT|CS_BYTEALIGNWINDOW|CS_DBLCLKS;
  wc.hIcon = LoadIcon(hInst, MAKEINTRESOURCE(IDI_B2_ICON));

	if(is_windowed && (m_right_mouse == 1)) {
		m_has_caption = true;
		style = WS_POPUP|WS_SYSMENU|WS_CAPTION|WS_MINIMIZEBOX|WS_MAXIMIZEBOX;
	} else {
		m_has_caption = false;
		style = WS_POPUP;
	}

  if(is_windowed) {
		w = width;
		h = height;
		get_window_position( width, height, &x, &y );
	} else {
		w = CW_USEDEFAULT;
		h = CW_USEDEFAULT;
		x = y = 0;
	}

	RegisterClassEx(&wc);

	hMainWnd = CreateWindowEx(
		WS_EX_APPWINDOW,
		window_class,
		GetString(STR_WINDOW_TITLE),
		style,
		x,
		y,
		w,
		h,
		HWND_DESKTOP,
		NULL,
		hInst,
		NULL
	);

	if(!hMainWnd) {
		ErrorAlert("Failed to create main window.");
		return(false);
	} else {
		update_system_menu( hMainWnd );
		update_window_size(style,w,h);
		update_zorder();
		return(true);
	}
}

static void set_mouse_initial_position(void)
{
	int x = 15, y = 15;

	if(is_windowed) {
		RECT r;
		GetClientRect( hMainWnd, &r );
		ClientToScreen( hMainWnd, (LPPOINT)&r );
		x += r.left;
		y += r.top;
	}

	SetCursorPos(x,y);
}

static void start_video_thread(void)
{
  screen_inited = 1;

  if(display_type == DISPLAY_WINDOW) {
		threads[THREAD_SCREEN_GDI].h = (HANDLE)_beginthreadex( 0, 0, redraw_thread, 0, 0, &threads[THREAD_SCREEN_GDI].tid );
		SetThreadPriority( threads[THREAD_SCREEN_GDI].h, threads[THREAD_SCREEN_GDI].priority_running );
		SetThreadAffinityMask( threads[THREAD_SCREEN_GDI].h, threads[THREAD_SCREEN_GDI].affinity_mask );
  } else if(display_type == DISPLAY_FB) {
		fb_signal = CreateSemaphore( 0, 0, 1, NULL);
		fb_reply = CreateSemaphore( 0, 0, 1, NULL);
		threads[THREAD_SCREEN_LFB].h = (HANDLE)_beginthreadex( 0, 0, redraw_thread_fb, 0, 0, &threads[THREAD_SCREEN_LFB].tid );
		SetThreadPriority( threads[THREAD_SCREEN_LFB].h, threads[THREAD_SCREEN_LFB].priority_running );
		SetThreadAffinityMask( threads[THREAD_SCREEN_LFB].h, threads[THREAD_SCREEN_LFB].affinity_mask );
  } else if(display_type == DISPLAY_DX) {
		// Why not check everything possible already here.
    if(pfnGetWriteWatch && equal_scanline_lengths) {
			threads[THREAD_SCREEN_DX].h = (HANDLE)_beginthreadex( 0, 0, redraw_thread_d3d_fullscreen, 0, 0, &threads[THREAD_SCREEN_DX].tid );
			SetThreadPriority( threads[THREAD_SCREEN_DX].h, threads[THREAD_SCREEN_DX].priority_running );
			SetThreadAffinityMask( threads[THREAD_SCREEN_DX].h, threads[THREAD_SCREEN_DX].affinity_mask );
		} else {
			threads[THREAD_SCREEN_DX].h = (HANDLE)_beginthreadex( 0, 0, redraw_thread_d3d, 0, 0, &threads[THREAD_SCREEN_DX].tid );
			SetThreadPriority( threads[THREAD_SCREEN_DX].h, threads[THREAD_SCREEN_DX].priority_running );
			SetThreadAffinityMask( threads[THREAD_SCREEN_DX].h, threads[THREAD_SCREEN_DX].affinity_mask );
		}
	}
}

static void stop_video_thread(void)
{
  int was_inited = screen_inited;

	if(fb_signal) {
		fb_command( FB_QUIT, 0, 0 );
		CloseHandle(fb_signal);
		CloseHandle(fb_reply);
		fb_signal = 0;
		fb_reply = 0;
	}

  screen_inited = 0;
	dx_blits_allowed = 0;

	D(bug("VideoExit waiting the thread\n"));
	for( int i=0; i<20; i++ ) {
		if(threads[THREAD_SCREEN_GDI].h == 0 &&
			 threads[THREAD_SCREEN_LFB].h == 0 &&
			 threads[THREAD_SCREEN_DX].h == 0)
		{
			break;
		}
		Sleep(100);
	}

	D(bug("VideoExit acquiring mutex\n"));
	if(was_inited) grab_draw_mutex();
	// Normally they die gracefully.

	if(threads[THREAD_SCREEN_GDI].h) {
		D(bug("VideoExit killing GDI\n"));
		TerminateThread(threads[THREAD_SCREEN_GDI].h,0);
		threads[THREAD_SCREEN_GDI].h = 0;
	}
	if(threads[THREAD_SCREEN_LFB].h) {
		D(bug("VideoExit killing LFB\n"));
		TerminateThread(threads[THREAD_SCREEN_LFB].h,0);
		threads[THREAD_SCREEN_LFB].h = 0;
	}
	if(threads[THREAD_SCREEN_DX].h) {
		D(bug("VideoExit killing DX\n"));
		TerminateThread(threads[THREAD_SCREEN_DX].h,0);
		threads[THREAD_SCREEN_DX].h = 0;
	}
	D(bug("VideoExit releasing mutex\n"));
	if(was_inited) release_draw_mutex();

	D(bug("VideoExit calling finiObjects\n"));
	finiObjects();
}

static int count_palette_colors( int depth )
{
	switch(depth) {
		case 1:  return 2;
		case 2:  return 2;
		case 4:  return 16;
		case 8:  return 256;
		default: return 0;
	}
}

int get_current_screen_depth()
{
	typedef struct BITMAPINFO256 {
		BITMAPINFOHEADER bmiHeader;
		RGBQUAD bmiColors[256];
	} b;

	int depth = 16;

  HDC hScreenDC = GetDC(GetDesktopWindow());
	if(hScreenDC) {
	  depth = GetDeviceCaps(hScreenDC,BITSPIXEL);
		if(depth == 15 || depth == 16) {
			HBITMAP hbmp = CreateCompatibleBitmap( hScreenDC, 16, 16 );
			if(hbmp) {
				BITMAPINFO256 b;
				memset( &b, 0, sizeof(b) );
				b.bmiHeader.biSize = sizeof(b);
				GetDIBits( hScreenDC, hbmp, 0, 1, NULL, (LPBITMAPINFO)&b, 0 );
				GetDIBits( hScreenDC, hbmp, 0, 1, NULL, (LPBITMAPINFO)&b, 0 );
				if(b.bmiHeader.biCompression == BI_BITFIELDS) {
					DWORD red		= *(DWORD *)&b.bmiColors[0];
					DWORD green = *(DWORD *)&b.bmiColors[1];
					DWORD blue	= *(DWORD *)&b.bmiColors[2];
					int depth_new = count_bits(red) + count_bits(green) + count_bits(blue);
					if(depth_new == 15 || depth_new == 16) {
						depth = depth_new;
					}
				} else if(b.bmiHeader.biCompression == BI_RGB) {
					// Default to the faster mode.
					depth = 15;
				}
				DeleteObject(hbmp);
			}
		}
		ReleaseDC(GetDesktopWindow(),hScreenDC);
	}
	return depth;
}

void get_video_mode(
	int &width, 
	int &height, 
	int &depth_mac, 
	int &depth_win
)
{
  const char *_mode_str = PrefsFindString("screen");
  char mode_str[200];

	int w_user=0, h_user=0, bits_user=0, got_args=0;

	width  = GetSystemMetrics(SM_CXSCREEN);
	height = GetSystemMetrics(SM_CYSCREEN);
  depth_mac = depth_win = get_current_screen_depth();
  display_type = DISPLAY_DX;

  if(_mode_str == 0 || *_mode_str == 0) {
		// Newbies cannot use the screen page and compare apples and oranges.
		strcpy( mode_str, "dx/800/600/8" );
	} else {
		strcpy( mode_str, _mode_str );
	}

	// Mac screen depth is always 1 bit in Classic mode
	if (classic_mode) {
		depth_mac = 1;
	  if (mode_str && (strncmp(mode_str,"win",3) == 0)) {
			strcpy( mode_str, "win/512/342" );
		} else {
			strcpy( mode_str, "dx/512/342" );
		}
	}

  if (mode_str && *mode_str) {
    if (strncmp(mode_str, "win",3) == 0) {
      display_type = DISPLAY_WINDOW;
			got_args = sscanf(mode_str, "win/%d/%d/%d", &w_user, &h_user, &bits_user);
    } else if (strncmp(mode_str, "dxwin",5) == 0) {
			display_type = DISPLAY_DX;
			got_args = sscanf(mode_str, "dxwin/%d/%d/%d", &w_user, &h_user, &bits_user);
			is_windowed = true;
    } else if (strncmp(mode_str, "dx",2) == 0) {
      display_type = DISPLAY_DX;
			got_args = sscanf(mode_str, "dx/%d/%d/%d", &w_user, &h_user, &bits_user);
    } else if (strncmp(mode_str, "fb",2) == 0) {
			// Note that this mode cannot be used under Win9x. I'm not
			// disabling it without a good reason. It grabs the Win16Lock
			// for an extended period of time. Try it if you want under Win9x,
			// it will hang your system.
			if(win_os == VER_PLATFORM_WIN32_NT) {
				display_type = DISPLAY_FB;
			}
			got_args = sscanf(mode_str, "fb/%d/%d/%d", &w_user, &h_user, &bits_user);
    }
	}

	if(got_args >= 2) {
		// if either one is zero, the user is trying to define depth only.
		if(w_user || h_user) {
			if(w_user == 0) w_user = width;
			if(h_user == 0) h_user = height;
			if(w_user > 8192) w_user = 8192;
			if(h_user > 8192) h_user = 8192;
			if(display_type == DISPLAY_WINDOW || is_windowed) {
				if(w_user < 80) w_user = 80;
				if(h_user < 80) h_user = 80;
				if(w_user != width || h_user != height) {
					is_windowed = true;
				}
			} else {
				if(w_user < 320) w_user = 320;
				if(h_user < 200) h_user = 200;
			}
			width  = w_user;
			height = h_user;
		}
	}
	if(got_args >= 3 && bits_user != 0) {
		if(is_windowed && display_type == DISPLAY_DX) {
			if(bits_user == 15 || bits_user == 16) {
				if(depth_win != 16) bits_user = depth_win;
			} else {
				bits_user = depth_win;
			}
		}
		if(is_windowed && (bits_user > depth_mac)) {
			bits_user = depth_mac;
		}
		if(bits_user > 32) bits_user = 32;
		depth_mac = depth_win = bits_user;
		if(bits_user == 15) {
			depth_mac = 15;
			depth_win = 16;
		}
	}

	if(depth_win < 8 && display_type != DISPLAY_FB) depth_win = 8;
  if(depth_mac == 24) depth_mac = 32;

	if(mem_8_only) {
		if(display_type == DISPLAY_FB) {
			// Linear frame buffer address is not predictable for my purposes.
			// Use normal d3d as a fallback
			display_type = DISPLAY_DX;
		}
	}
}

bool VideoInit(bool /*classic*/)
{
	char error_str[512], msg[256];

  if(screen_inited) return 0;

	log_faults = GetPrivateProfileInt( "Debug", "log_faults", 0, ini_file_name );

	is_windowed = false;

  lppal = (LPLOGPALETTE)malloc( sizeof(LOGPALETTE) + sizeof(PALETTEENTRY) * 256 );
  lppal->palVersion = 0x300;

	if(pfnInitializeCriticalSectionAndSpinCount) {
		pfnInitializeCriticalSectionAndSpinCount( &draw_csection, 7000 );
		pfnInitializeCriticalSectionAndSpinCount( &fb_csection, 3000 );
	} else {
		InitializeCriticalSection( &draw_csection );
		InitializeCriticalSection( &fb_csection );
	}

  int width, height, depth_mac, depth_win;
	get_video_mode( width, height, depth_mac, depth_win );

  if(classic_mode || PrefsFindBool("disable98optimizations")) pfnGetWriteWatch = 0;

	m_show_real_fps = PrefsFindBool("showfps");
	sleep_ticks = PrefsFindInt32("framesleepticks");
	if(sleep_ticks < 1) sleep_ticks = 1;
	if(sleep_ticks > 1000) sleep_ticks = 1000;

  set_video_monitor( width, height, depth_win, depth_mac, calc_bytes_per_row(width,depth_mac) );

	int pal_colors = count_palette_colors(depth_mac);

  pbmi = (LPBITMAPINFO)malloc( sizeof(BITMAPINFO) + 256 * sizeof(RGBQUAD) );
  if(!pbmi) QuitEmulator();
  memset( pbmi, 0, sizeof(BITMAPINFO) + 256 * sizeof(RGBQUAD) );

  pbmi->bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  pbmi->bmiHeader.biWidth = width;
	pbmi->bmiHeader.biHeight = -height;
	pbmi->bmiHeader.biSizeImage = scanlines[height];
  pbmi->bmiHeader.biPlanes = 1;
  pbmi->bmiHeader.biCompression = BI_RGB;
  pbmi->bmiHeader.biXPelsPerMeter = 0;
  pbmi->bmiHeader.biYPelsPerMeter = 0;
  pbmi->bmiHeader.biClrUsed = pal_colors;
  pbmi->bmiHeader.biClrImportant = pal_colors;
	switch(depth_mac) {
		case 15:
		  pbmi->bmiHeader.biBitCount = 16;
			pbmi->bmiHeader.biCompression = BI_BITFIELDS;
			*(DWORD *)&pbmi->bmiColors[0] = 0x7c00;
			*(DWORD *)&pbmi->bmiColors[1] = 0x03e0;
			*(DWORD *)&pbmi->bmiColors[2] = 0x001f;
			// Target may be palette based, reserve some optimization space.
			pbmi->bmiHeader.biClrUsed = 256;
			pbmi->bmiHeader.biClrImportant = 256;
			break;
		case 16:
		  pbmi->bmiHeader.biBitCount = 16;
			pbmi->bmiHeader.biCompression = BI_BITFIELDS;
			*(DWORD *)&pbmi->bmiColors[0] = 0xf800;
			*(DWORD *)&pbmi->bmiColors[1] = 0x07e0;
			*(DWORD *)&pbmi->bmiColors[2] = 0x001f;
			// Target may be palette based, reserve some optimization space.
			pbmi->bmiHeader.biClrUsed = 256;
			pbmi->bmiHeader.biClrImportant = 256;
			break;
		case 2:
		  pbmi->bmiHeader.biBitCount = 1;
		  pbmi->bmiHeader.biWidth = width*2;
			break;
		default:
		  pbmi->bmiHeader.biBitCount = depth_mac;
			break;
	}

	switch(depth_mac) {
		case 1:
			lppal->palPalEntry[0].peRed = 255;
			lppal->palPalEntry[0].peGreen = 255;
			lppal->palPalEntry[0].peBlue = 255;
			lppal->palPalEntry[1].peRed = 0;
			lppal->palPalEntry[1].peGreen = 0;
			lppal->palPalEntry[1].peBlue = 0;
			break;
		case 2:
			// Fake 2 bit palette.
			lppal2bits = (LPLOGPALETTE)malloc( sizeof(LOGPALETTE) + sizeof(PALETTEENTRY) * 256 );
			lppal2bits->palVersion = 0x300;
			lppal2bits->palPalEntry[0].peRed = 255;
			lppal2bits->palPalEntry[0].peGreen = 255;
			lppal2bits->palPalEntry[0].peBlue = 255;
			lppal2bits->palPalEntry[1].peRed = 0;
			lppal2bits->palPalEntry[1].peGreen = 0;
			lppal2bits->palPalEntry[1].peBlue = 0;
			lppal2bits->palNumEntries = (WORD)2;
			hPalMain2bits = CreatePalette(lppal2bits);
			break;
	}

	for( int i=0; i<pal_colors; i++ ) {
		lppal->palPalEntry[0].peFlags = PC_NOCOLLAPSE; // PC_RESERVED|PC_NOCOLLAPSE
		pbmi->bmiColors[0].rgbRed = lppal->palPalEntry[0].peRed;
		pbmi->bmiColors[0].rgbGreen = lppal->palPalEntry[0].peGreen;
		pbmi->bmiColors[0].rgbBlue = lppal->palPalEntry[0].peBlue;
		pbmi->bmiColors[i].rgbReserved = 0;
	}

  lppal->palNumEntries = (WORD)pal_colors;
	if(pal_colors) hPalMain = CreatePalette(lppal);

  // ADBSetRelMouseMode(false);

	sz_the_buffer = width * calc_bytes_per_row(height,depth_mac);

	if(mem_8_only) {
		if(!the_buffer) {
			ErrorAlert("Internal error: the_buffer is not mapped to process address space.");
			QuitEmulator();
		}
	} else {
    LONG memAlloc = MEM_RESERVE|MEM_COMMIT;
		if(display_type != DISPLAY_FB) {
			if(pfnGetWriteWatch) {
				if(win_os == VER_PLATFORM_WIN32_WINDOWS) {
					memAlloc |= MEM_WRITE_WATCH;
				}
			}
		}
		if (classic_mode) {
			the_buffer = (uint8 *)Mac2HostAddr(0x3fa700);
		} else {
			the_buffer = (uint8 *)VirtualAlloc( 0, sz_the_buffer+VM_PAGE_BYTES*16, memAlloc, PAGE_READWRITE );
		}
	}
	if(!the_buffer) return false;

	if (!classic_mode) {
		// Cannot touch this memory yet in classic mode.
		// memset( the_buffer, 0, sz_the_buffer );
	}

  VideoMonitor.mac_frame_base = MacFrameBaseMac;

	if(!create_window(width,height)) QuitEmulator();

	if(is_windowed) {
		ShowWindow(hMainWnd, SW_SHOWNORMAL);
	} else {
		ShowWindow(hMainWnd, SW_MAXIMIZE);
	}

  // Initialize according to display type
	// If DirectX init fails use WINAPI as a fallback.
  switch (display_type) {
    case DISPLAY_WINDOW:
      if (!init_window(width, height, depth_mac, depth_win))
        return false;
      break;
    case DISPLAY_FB:
      if (!init_fb(width, height, depth_mac, depth_win, error_str)) {
				display_type = DISPLAY_WINDOW;
				DestroyWindow(hMainWnd);
				final_desktop();
				if(!create_window(width,height)) QuitEmulator();
				ShowWindow(hMainWnd, SW_MAXIMIZE);
	      if (!init_window(width, height, depth_mac, depth_win))
					return false;
				sprintf( msg, "Frame buffer initialization failed: \"%s.\" Using Windows GDI API.", error_str );
		    WarningAlert(msg);
			} else if(dx_pitch != calc_bytes_per_row(width,depth_mac)) {
				finiObjects();
		    ErrorAlert("Linear Frame Buffer mode cannot be used with this screen width.");
				QuitEmulator();
			}
		  set_video_monitor( width, height, depth_win, depth_mac, calc_bytes_per_row(width,depth_mac) );
      break;
    case DISPLAY_DX:
      if (!init_dx(width, height, depth_mac, depth_win, error_str)) {
				display_type = DISPLAY_WINDOW;
	      if (!init_window(width, height, depth_mac, depth_win))
					return false;
				sprintf( msg, "Direct X problem: \"%s.\" Using Windows GDI API.", error_str );
		    WarningAlert(msg);
			}
			// Depth may change...
		  set_video_monitor( width, height, depth_win, depth_mac, calc_bytes_per_row(width,depth_mac) );
      break;
  }

	equal_scanline_lengths = (int)VideoMonitor.bytes_per_row == dx_pitch;

	// No special frame buffer in Classic mode (frame buffer is in Mac RAM)
	if (classic_mode) {
		MacFrameLayout = FLAYOUT_NONE;
	}

	show_cursor( 0 );

	// set_mouse_initial_position();

	if(is_windowed) {
		ShowWindow(hMainWnd, SW_SHOWNORMAL);
	} else {
		ShowWindow(hMainWnd, SW_MAXIMIZE);
	}

  if(display_type != DISPLAY_WINDOW) {
		SetFocus(hMainWnd);
		SetActiveWindow(hMainWnd);
	}

	// Direct frame buffer access does not need the fault handler
  if(display_type != DISPLAY_FB) {
		if(pfnGetWriteWatch) {
			mainBuffer.dirty = 1;
		}
		// if(classic_mode) set_very_dirty();
		Screen_Setup_fault_handler();
	}

  // Set variables for UAE memory mapping
  MacFrameSize = VideoMonitor.bytes_per_row * VideoMonitor.y;

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
	switch(screen_bit_depth_mac) {
		case 15:
		case 16:
		case 32:
			host_screen = (uint8 *)VirtualAlloc( 0, sz_the_buffer+VM_PAGE_BYTES*16, MEM_RESERVE|MEM_COMMIT, PAGE_READWRITE );
			mainBuffer.memStartAlt = (DWORD)host_screen;
			break;
		default:
			mainBuffer.memStartAlt = (DWORD)mainBuffer.memStart;
	}
#endif

	start_video_thread();

  return true;
}

void toggle_full_screen_mode(void)
{
	BOOL going_fullscreen;
	int x, y;
	static int remember_windowed_mode = DISPLAY_WINDOW;

  if(display_type == DISPLAY_DX && !is_windowed) {
		going_fullscreen = FALSE;
		get_window_position( VideoMonitor.x, VideoMonitor.y, &x, &y );
  } else if(is_windowed) {
		going_fullscreen = TRUE;
	} else {
		return;
	}

	stop_video_thread();

	grab_draw_mutex();

	if(going_fullscreen) {
		remember_windowed_mode = display_type;
	  is_windowed = false;
		display_type = DISPLAY_DX;
	} else {
	  is_windowed = true;
		display_type = remember_windowed_mode;
	}

	DWORD style =	GetWindowLong( hMainWnd, GWL_STYLE );

	if(is_windowed && (m_right_mouse == 1)) {
		m_has_caption = true;
		style |= WS_SYSMENU|WS_CAPTION|WS_MINIMIZEBOX|WS_MAXIMIZEBOX;
	} else {
		m_has_caption = false;
		style &= ~(WS_SYSMENU|WS_CAPTION|WS_MINIMIZEBOX|WS_MAXIMIZEBOX);
	}
	SetWindowLong( hMainWnd, GWL_STYLE, style );

	if(is_windowed) {
		ShowWindow(hMainWnd, SW_SHOWNORMAL);
		SetWindowPos( hMainWnd, 0, x, y, 0, 0, SWP_NOZORDER|SWP_NOSIZE );
	} else {
		ShowWindow(hMainWnd, SW_MAXIMIZE);
	}
	update_system_menu( hMainWnd );
	update_window_size(style,VideoMonitor.x, VideoMonitor.y);
	update_zorder();

	if(display_type == DISPLAY_DX) {
		char error_str[512];
		int depth_win = screen_bit_depth_win;
		int depth_mac = screen_bit_depth_mac;
		int width = VideoMonitor.x;
		int height = VideoMonitor.y;
		if(classic_mode) {
			depth_win = 8;
			depth_mac = 1;
			width = 640;
			height = 480;
		}
		if (!init_dx(width, height, depth_mac, depth_win, error_str)) {
			char msg[512];
			sprintf( msg, "Direct X problem: \"%s\".", error_str );
		  WarningAlert(msg);
		}
		equal_scanline_lengths = (int)VideoMonitor.bytes_per_row == dx_pitch;
	  set_video_monitor( width, height, depth_win, depth_mac, calc_bytes_per_row(width,depth_mac) );
		memory_init();
	} else {
		if(!init_window(VideoMonitor.x, VideoMonitor.y, screen_bit_depth_mac, screen_bit_depth_win)) {
		}
	}

	if(is_windowed) {
		ShowWindow(hMainWnd, SW_SHOWNORMAL);
	} else {
		ShowWindow(hMainWnd, SW_MAXIMIZE);
	}

	SetFocus(hMainWnd);
	SetActiveWindow(hMainWnd);

	start_video_thread();

	set_very_dirty();
	release_draw_mutex();

	video_set_palette2(current_mac_palette);

  if(display_type == DISPLAY_DX && is_windowed) {
		video_activate( TRUE );
	}
}

bool is_screen_inited(void)
{
	return(screen_inited);
}


/*
 *  Deinitialization
 */

void VideoExit(void)
{
  int was_inited = screen_inited;

	if(display_type == DISPLAY_DX) {
		ShowWindow(hMainWnd, SW_MINIMIZE);
	} else if(display_type == DISPLAY_WINDOW) {
		ShowWindow(hMainWnd, SW_SHOWMINIMIZED);
	}
	ShowCursor(1);

	if(old_exception_filter) {
		SetUnhandledExceptionFilter( (LPTOP_LEVEL_EXCEPTION_FILTER)old_exception_filter );
		old_exception_filter = 0;
	}

	stop_video_thread();

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
  if(host_screen) {
		D(bug("VideoExit freeing host_screen\n"));
    VirtualFree( host_screen, 0, MEM_RELEASE  );
		host_screen = 0;
  }
#endif
  if(the_buffer && !mem_8_only && !classic_mode) {
		D(bug("VideoExit freeing the_buffer\n"));
    VirtualFree( the_buffer, 0, MEM_RELEASE  );
		the_buffer = 0;
  }
  if(lppal) {
		D(bug("VideoExit deleting lppal\n"));
		free(lppal);
		lppal = 0;
	}
  if(lppal2bits) {
		D(bug("VideoExit deleting lppal2bits\n"));
		free(lppal2bits);
		lppal2bits = 0;
	}
  if(hPalMain) {
		D(bug("VideoExit deleting hPalMain\n"));
    DeleteObject(hPalMain);
    hPalMain = 0;
  }
  if(hPalMain2bits) {
		D(bug("VideoExit deleting hPalMain2bits\n"));
    DeleteObject(hPalMain2bits);
    hPalMain2bits = 0;
  }
  if(pbmi) {
		D(bug("VideoExit deleting pbmi\n"));
    free(pbmi);
    pbmi = 0;
  }
	// D(bug("VideoExit releasing mutex\n"));
	// release_draw_mutex();

	if(was_inited) {
		D(bug("VideoExit deleting critical sections\n"));
		DeleteCriticalSection( &draw_csection );
		DeleteCriticalSection( &fb_csection );
	}

	D(bug("VideoExit finalizing desktop\n"));
	final_desktop();

	D(bug("VideoExit done\n"));
}

void setup_palette_entries(uint8 *pal)
{
	uint16 i, j;
	uint16 *iptr = (uint16 *)&pbmi->bmiColors[0];

  for (i=0,j=0; i<256; i++,j+=3) {
    lppal->palPalEntry[i].peRed = pal[j];
    lppal->palPalEntry[i].peGreen = pal[j+1];
    lppal->palPalEntry[i].peBlue = pal[j+2];
    lppal->palPalEntry[i].peFlags = PC_NOCOLLAPSE; // PC_RESERVED|PC_NOCOLLAPSE
		if(bPalette == DIB_PAL_COLORS) {
			*iptr++ = i;
		} else {
			pbmi->bmiColors[i].rgbRed = pal[j];
			pbmi->bmiColors[i].rgbGreen = pal[j+1];
			pbmi->bmiColors[i].rgbBlue = pal[j+2];
			pbmi->bmiColors[i].rgbReserved = 0;
		}
  }
}

void setup_palette_entries_dd3(uint8 *pal)
{
	uint16 i, j;

  for (i=0,j=0; i<256; i++,j+=3) {
    lppal->palPalEntry[i].peRed = pal[j];
    lppal->palPalEntry[i].peGreen = pal[j+1];
    lppal->palPalEntry[i].peBlue = pal[j+2];
  }
}

// Tester only. Does not blank but inverts, to study how protection
// attributes work

/*
void blank_screen( void )
{
	HDC hScreenDC = GetDC(hMainWnd);
	if(hScreenDC) {
		RECT r;
		GetClientRect( hMainWnd, &r );
		InvertRect( hScreenDC, &r );
		ReleaseDC(hMainWnd,hScreenDC);
	}
}
*/

void video_set_palette2(uint8 *pal)
{
	HDC hScreenDC;
	HRESULT ddrval;
	int dt = display_type;

	if(!screen_inited) return;

	grab_draw_mutex();

  if(screen_bit_depth_win <= 8) {
		switch(dt) {
			case DISPLAY_DX:
				if(lpDDPal) {
					setup_palette_entries_dd3(pal);
					for(;;) {
						ddrval = lpDDPal->SetEntries( 0, 0, 256, lppal->palPalEntry );
						if( ddrval == DD_OK ) break;
						if( ddrval == DDERR_SURFACELOST ) {
							ddrval = restoreAll();
						}
						if( ddrval != DD_OK && ddrval != DDERR_WASSTILLDRAWING ) break;
					}
				}
				set_very_dirty();
				break;
			case DISPLAY_FB:
				if(lpDDPal) {
					fb_command( FB_SETPALETTE, pal, 768 );
				}
				break;
			default:
				hScreenDC = GetDC(hMainWnd);
				if(hScreenDC) {
					HPALETTE hold;
					if(hPalMain) DeleteObject(hPalMain);
					setup_palette_entries( pal );
					hPalMain = CreatePalette(lppal);
					hold = SelectPalette( hScreenDC, hPalMain, FALSE );
					RealizePalette(hScreenDC);
					SelectPalette( hScreenDC, hold, FALSE );
					ReleaseDC(hMainWnd,hScreenDC);
					set_very_dirty();
				}
				break;
		}
  }

	release_draw_mutex();
}

/*
 *  Set palette
 */

void video_set_palette(uint8 *pal)
{
	memcpy( current_mac_palette, pal, sizeof(current_mac_palette) );
	video_set_palette2(pal);
}

int update_palette()
{
	int i = 0;
	HRESULT ddrval;
	int dt = display_type;

	if(!screen_inited) return(0);

	grab_draw_mutex();

  switch(dt) {
		case DISPLAY_DX:
			if(lpDDPal) {
				setup_palette_entries_dd3(current_mac_palette);
				for(;;) {
					ddrval = lpDDPal->SetEntries( 0, 0, 256, lppal->palPalEntry );
					// ddrval = lpDDSPrimary->SetPalette(lpDDPal);
					if( ddrval == DD_OK ) break;
					if( ddrval == DDERR_SURFACELOST ) {
						ddrval = restoreAll();
					}
					if( ddrval != DD_OK && ddrval != DDERR_WASSTILLDRAWING ) break;
				}
			}
			i = 1;
			set_very_dirty();
			break;
		case DISPLAY_FB:
			if(lpDDPal) {
				fb_command( FB_UPDATEPALETTE, 0, 0 );
			}
			i = 1;
			break;
		default:
			if(hPalMain) {
				HDC hScreenDC = GetDC(hMainWnd);
				if(hScreenDC) {
					// UnrealizeObject(hPalMain);
					HPALETTE hold;
					hold = SelectPalette( hScreenDC, hPalMain, FALSE );
					i = RealizePalette(hScreenDC);
					SelectPalette( hScreenDC, hold, FALSE );
					if(i) {
						set_very_dirty();
					}
					ReleaseDC(hMainWnd,hScreenDC);
				}
			}
			break;
	}
	release_draw_mutex();
	return( i );
}

static void set_fps_caption( char *caption )
{
	if(m_has_caption) {
		SetWindowText( hMainWnd, caption );
	} else {
		grab_draw_mutex();
    HDC hScreenDC = GetDC(hMainWnd);
    if(hScreenDC) {
			TextOut( hScreenDC, 0, VideoMonitor.y - 20, caption, strlen(caption) );
      ReleaseDC(hMainWnd,hScreenDC);
    }
		release_draw_mutex();
	}
}

/*
	MacOS tries to write to ROM which is write-protected.
	Sometimes it also tries to read from illegal addresses.
	The technique used here has a disadvantage of hiding some bugs.

	Now DIVL exceptions are handled here too.
*/

static void dump_first_bytes( char *opname, BYTE *buf, int32 actual )
{
	char b[256], bb[10];
	int32 i, bytes = min(actual,sizeof(b)/3-1-3);

	sprintf( b, "Function \"%s\": ", opname );

	for (i=0; i<bytes; i++) {
		sprintf( bb, "%02x ", (uint32)buf[i] );
		strcat( b, bb );
	}
	strcat((char*)b,"\r\n");
	OutputDebugString(b);
}

static void get_op_code( BYTE *buf, char *opname, int max_sz )
{
	LPBYTE start = 0, end = 0;

	for (int i=0; i<1024; i++) {
		buf--;
		if(IsBadCodePtr((FARPROC)buf)) break;
		if(memcmp(buf,"{[(",3)==0) start = buf+3;
		if(memcmp(buf,")]}",3)==0) end = buf;
		if(start && end) break;
	}
	if(start && end) {
		int len = (int)( (DWORD)end - (DWORD)start );
		if(len > max_sz) len = max_sz-1;
		memcpy( opname, start, len );
		opname[len] = 0;
	} else {
		strcpy( opname, "Unknown" );
	}
}

static DWORD step_over_modrm( LPBYTE p )
{
  uint8 mod = (p[0] >> 6) & 3;
  uint8 rm = p[0] & 7;
	DWORD offset = 0;

  switch(mod) {
		case 0:
			if(rm == 5) return 4;
			break;
		case 1:
			offset = 1;
			break;
		case 2:
			offset = 4;
			break;
		case 3:
			return 0;
  }
  if(rm == 4) {
		if(mod == 0 && (p[1] & 7) == 5)
			offset = 5;
		else
			offset++;
  }
  return offset;
}

/*
	You may need to add some more things here if you
	upgrade the compiler
*/
// #include "mem_limits.h"

static DWORD inline advance( struct _EXCEPTION_POINTERS *ExceptionInfo )
{
	DWORD inc = 0;
	LPBYTE eip = (LPBYTE)ExceptionInfo->ContextRecord->Eip;

	if(eip == 0 || IsBadCodePtr((FARPROC)eip)) return 0;

	if(log_faults) {
		char opname[100];
		get_op_code( eip, opname, sizeof(opname) );
		dump_first_bytes( opname, eip, 16 );
	}

	// Operand size prefix
	if(*eip == 0x66) {
		eip++;
		inc++;
	}

/*
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
	if(ExceptionInfo->ExceptionRecord->ExceptionCode == EXCEPTION_ARRAY_BOUNDS_EXCEEDED ) {
		if(log_faults) OutputDebugString("Bounds check\r\n");
		while(*eip == 0x62) {
			ExceptionInfo->ContextRecord->Eip += inc + 2 + step_over_modrm(eip+1);
			eip = (LPBYTE)ExceptionInfo->ContextRecord->Eip;
			inc = 0;
			if(*eip == 0x66) {
				eip++;
				inc++;
			}
		}
	}
#endif
*/

	switch( *eip ) {
#ifdef OVERFLOW_EXCEPTIONS
		case 0xf7:
			// div dword ptr [ebp+disp]
			// idiv dword ptr [ebp+disp]
			if(eip[1] == 0x75 || eip[1] == 0x7d) {
				if(log_faults) OutputDebugString("divide error...\r\n");
				if(ExceptionInfo->ExceptionRecord->ExceptionCode == EXCEPTION_INT_OVERFLOW) {
					if(log_faults) OutputDebugString("... overflow error was handled.\r\n");
					ExceptionInfo->ContextRecord->Eip += inc + 3;
					overflow_confition = OVERFLOW_OVRL;
					return 1;
				} else if(ExceptionInfo->ExceptionRecord->ExceptionCode == EXCEPTION_INT_DIVIDE_BY_ZERO) {
					if(log_faults) OutputDebugString("... divide by zero was handled.\r\n");
					ExceptionInfo->ContextRecord->Eip += inc + 3;
					overflow_confition = OVERFLOW_DIVZERO;
					return 1;
				}
			}
			break;
#endif
		case 0x0f:
			if( eip[1] == 0xb7 || // movzx   ebx,word ptr [edx+edi] (0fb71c17)
					eip[1] == 0xb6 )  // movzx   ecx,byte ptr [ebp]			(0fb64d00)
			{ 
				ExceptionInfo->ContextRecord->Eip += inc + 3 + step_over_modrm(eip+2);
				return 1;
			}
			break;

		case 0x00: // ADD r/m8,r8
		case 0x02: // ADD r8,r/m8
		case 0x88: // MOV r/m8,r8
		case 0x8a: // MOV r8,r/m8
		case 0x89: // MOV r/m32,r32
		case 0x8b: // MOV r32,r/m32
			ExceptionInfo->ContextRecord->Eip += inc + 2 + step_over_modrm(eip+1);
			return 1;
		case 0xc6: // MOV r/m8,imm8
			if( (eip[1] & 0x38) == 0 ) {
				ExceptionInfo->ContextRecord->Eip += inc + 3 + step_over_modrm(eip+1);
				return 1;
			} /* else illegal op code */
	}

	// Let it crash.
	return(0);
}

// todo: move this to h
void panic( DWORD address );
extern "C" void fake_cpufunctbl_all_funcs(void);

// This function is called when any exception would remain
// unhandled. It is a write to the Mac page if:
//    - it is a access violation
//    - it is within the range of the Mac screen buffers.
//    - if both of these are true, we know that it's a write
//      (since we didn't deny read).
// Update the dirty area (top,bottom) of the buffer,
// make the virtual page r/w again to stop faulting,
// and continue execution. The write will be attempted again
// and it will succeed now.

LONG WINAPI Screen_fault_proc( struct _EXCEPTION_POINTERS *ExceptionInfo )
{
  DWORD OldProtect, page, last_page;

  DWORD a = (DWORD)ExceptionInfo->ExceptionRecord->ExceptionInformation[1];
#ifdef SPECFLAG_EXCEPIONS
  if(a >= (DWORD)cpufunctbl+4*1024 && a < (DWORD)cpufunctbl + 4*1024 + 64*4*1024) {
		ExceptionInfo->ContextRecord->Eip = (DWORD)fake_cpufunctbl_all_funcs;
		return( EXCEPTION_CONTINUE_EXECUTION );
  }
#endif
  if(	/*ExceptionInfo->ExceptionRecord->ExceptionCode == EXCEPTION_ACCESS_VIOLATION &&*/
			a >= mainBuffer.memStart && a < mainBuffer.memEnd )
	{
		page = (a - mainBuffer.memStart) >> VM_PAGE_BITS;
		last_page = mainBuffer.last_pages[page];

		// This is time critical. Move everything possible out of here.
		grab_draw_mutex();

		VirtualProtect(
			(LPVOID)(a & VM_PAGE_ALIGN_MASK),
			(last_page - page + 1) << VM_PAGE_BITS,
			PAGE_READWRITE,
			&OldProtect // doc says this can be NULL, but it cannot.
		);
		mainBuffer.dirty = 1;

		// Check out the code generated by VC6. I was impressed.
		for( ; page <= last_page; page++ ) PFLAG_SET(page);

		release_draw_mutex();

    return( EXCEPTION_CONTINUE_EXECUTION );
  } else {
		if(advance(ExceptionInfo)) {
			return( EXCEPTION_CONTINUE_EXECUTION );
		} else {
			if( ExceptionInfo->ExceptionRecord->ExceptionCode != EXCEPTION_BREAKPOINT &&
					ExceptionInfo->ExceptionRecord->ExceptionCode != EXCEPTION_SINGLE_STEP )
			{
				panic(a);
			}
			return( EXCEPTION_CONTINUE_SEARCH );
		}
  }
}

LONG WINAPI Screen_fault_proc_opt( struct _EXCEPTION_POINTERS *ExceptionInfo )
{
#ifdef SPECFLAG_EXCEPIONS
  DWORD a = (DWORD)ExceptionInfo->ExceptionRecord->ExceptionInformation[1];
  if(a >= (DWORD)cpufunctbl+4*1024 && a < (DWORD)cpufunctbl + 4*1024 + 64*4*1024) {
		ExceptionInfo->ContextRecord->Eip = (DWORD)fake_cpufunctbl_all_funcs;
		return( EXCEPTION_CONTINUE_EXECUTION );
  }
#endif
	if(advance( ExceptionInfo )) return( EXCEPTION_CONTINUE_EXECUTION );

#ifndef SPECFLAG_EXCEPIONS
  DWORD a = (DWORD)ExceptionInfo->ExceptionRecord->ExceptionInformation[1];
#endif
	if( ExceptionInfo->ExceptionRecord->ExceptionCode != EXCEPTION_BREAKPOINT &&
			ExceptionInfo->ExceptionRecord->ExceptionCode != EXCEPTION_SINGLE_STEP )
	{
		panic(a);
	}

  return( EXCEPTION_CONTINUE_SEARCH );
}

void Screen_Draw_All(HWND hWnd)
{
  HDC hdc;
  PAINTSTRUCT ps;

	if(!screen_inited) {
		hdc = BeginPaint(hWnd, &ps);
		EndPaint(hWnd, &ps);
		return;
	}

	grab_draw_mutex();
	hdc = BeginPaint(hWnd, &ps);
  switch(display_type) {
		case DISPLAY_WINDOW:
			set_very_dirty();
			break;
		case DISPLAY_DX:
			if(dx_blits_allowed) {
				set_very_dirty();
			}
			break;
		case DISPLAY_FB:
			break;
	}
	EndPaint(hWnd, &ps);
	release_draw_mutex();
}

static void inline Screen_Draw_classic(HDC hScreenDC)
{
  DWORD OldProtect;
	HPALETTE hold1 = 0;

	if(mainBuffer.dirty == 0 && mainBuffer.very_dirty == 0) return;

	if(hPalMain) hold1 = SelectPalette( hScreenDC, hPalMain, FALSE );

	VirtualProtect( (LPVOID)the_buffer, 21888, PAGE_READONLY, &OldProtect );

	SetDIBitsToDevice(
		hScreenDC,
		0, 0,
		VideoMonitor.x, VideoMonitor.y,
		0, 0,
		0, VideoMonitor.y,
		(PVOID)mainBuffer.memBase,
		pbmi,
		bPalette
	);

	mainBuffer.dirty = 0;
	mainBuffer.very_dirty = 0;

	if(hPalMain) SelectPalette( hScreenDC, hold1, FALSE );
}

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
static DWORD __declspec(naked) _fastcall memcpy32( DWORD count, DWORD dst, DWORD src )
{
	_asm {
		push ebx
		shr ecx, 4
		push esi
		sub edx, 16
		test ecx, ecx
		mov ebx, [esp+12]
		je memcpy32_end

memcpy32_loop:
		mov eax, [ebx]
		mov esi, [ebx+4]
		bswap eax
		add edx, 16
		bswap esi
		mov [edx], eax
		mov [edx+4], esi

		mov eax, [ebx+8]
		mov esi, [ebx+12]
		bswap eax
		add ebx, 16
		bswap esi
		dec ecx
		mov [edx+8], eax
		mov [edx+12], esi
		jnz memcpy32_loop

memcpy32_end:
		pop esi
		pop ebx

		ret 4
	}
}

/*
	*p4++ = (b1 & 0x00FFFFFF)       | b2 << 24;
	*p4++ = (b2 & 0x00FFFF00) >> 8  | b3 << 16;
	*p4++ = (b3 & 0x00FF0000) >> 16 | b4 << 8;
*/
static DWORD __declspec(naked) _fastcall memcpy24( DWORD count, DWORD dst, DWORD src )
{
	_asm {
		push esi
		push ebx
		shr ecx, 2
		push ebp
		sub edx, 4
		test ecx, ecx
		mov esi, [esp+16]
		je memcpy24_end

memcpy24_loop:

		; *p4++ = (b1 & 0x00FFFFFF)       | b2 << 24;
		mov eax, [esi]				;b1
		add esi, 4
		bswap eax
		mov ebx, [esi]				;b2
		and eax, 00ffffffH
		bswap ebx
		add esi, 4
		mov ebp, ebx					;b2
		shl ebx, 24
		and ebp, 00FFFF00H
		add edx, 4
		or  eax, ebx
		mov [edx], eax

		; *p4++ = (b2 & 0x00FFFF00) >> 8  | b3 << 16;
		shr ebp, 8
		mov eax, [esi]				;b3
		bswap eax
		add esi, 4
		mov ebx, eax
		add edx, 4
		shl eax, 16
		or  eax, ebp
		mov [edx], eax

		; *p4++ = (b3 & 0x00FF0000) >> 16 | b4 << 8;
		mov ebp, [esi]				;b4
		bswap ebp
		and ebx, 00FF0000H
		shl ebp, 8
		add esi, 4
		shr ebx, 16
		add edx, 4
		or  ebp, ebx
		dec ecx
		mov [edx], ebp
		jnz memcpy24_loop

memcpy24_end:
		pop ebp
		pop ebx
		pop esi
		ret 4
	}
}

static DWORD __declspec(naked) _fastcall memcpy15( DWORD count, DWORD dst, DWORD src )
{
	_asm {
		push esi
		shr ecx, 4
		push ebx
		test ecx, ecx
		mov esi, [esp+12]
		je memcpy15_end
		sub edx, 4

		; *p4++ = ((b2 & 0xFF00FF00) >> 8) | ((b2 & 0x00FF00FF) << 8);

memcpy15_loop:
		mov eax, [esi]
		add edx, 4
		mov ebx, eax
		and eax, 0ff00ff00H
		and ebx, 00ff00ffH
		shr eax, 8
		shl ebx, 8
		or eax, ebx
		add esi, 4
		mov [edx], eax

		mov eax, [esi]
		add edx, 4
		mov ebx, eax
		and eax, 0ff00ff00H
		and ebx, 00ff00ffH
		shr eax, 8
		shl ebx, 8
		or eax, ebx
		add esi, 4
		mov [edx], eax

		mov eax, [esi]
		add edx, 4
		mov ebx, eax
		and eax, 0ff00ff00H
		and ebx, 00ff00ffH
		shr eax, 8
		shl ebx, 8
		or eax, ebx
		add esi, 4
		mov [edx], eax

		mov eax, [esi]
		add edx, 4
		mov ebx, eax
		and eax, 0ff00ff00H
		and ebx, 00ff00ffH
		shr eax, 8
		shl ebx, 8
		add esi, 4
		or eax, ebx
		dec ecx
		mov [edx], eax
		jnz memcpy15_loop

memcpy15_end:
		pop ebx
		pop esi
		ret 4
	}
}

static DWORD __declspec(naked) _fastcall memcpy16( DWORD count, DWORD dst, DWORD src )
{
	_asm {
		push esi
		shr ecx, 4
		push ebp
		test ecx, ecx
		push ebx
		je memcpy16_end
		mov esi, [esp+16]
		sub edx, 4

		; *p4++ = ((b1 & 0x007F007F) << 9) | ((b1 & 0x1F001F00) >> 8) | ((b1 & 0xE000E000) >> 7);

memcpy16_loop:
		mov eax, [esi]
		add edx, 4
		mov ebx, eax
		mov ebp, eax
		and ebx, 1F001F00H
		and eax, 007F007FH
		and ebp, 0E000E000H
		shr ebx, 8
		shr ebp, 7
		shl eax, 9
		or ebp, ebx
		add esi, 4
		or eax, ebp
		mov [edx], eax

		mov eax, [esi]
		add edx, 4
		mov ebx, eax
		mov ebp, eax
		and ebx, 1F001F00H
		and eax, 007F007FH
		and ebp, 0E000E000H
		shr ebx, 8
		shr ebp, 7
		shl eax, 9
		or ebp, ebx
		add esi, 4
		or eax, ebp
		mov [edx], eax

		mov eax, [esi]
		add edx, 4
		mov ebx, eax
		mov ebp, eax
		and ebx, 1F001F00H
		and eax, 007F007FH
		and ebp, 0E000E000H
		shr ebx, 8
		shr ebp, 7
		shl eax, 9
		or ebp, ebx
		add esi, 4
		or eax, ebp
		mov [edx], eax

		mov eax, [esi]
		add edx, 4
		mov ebx, eax
		mov ebp, eax
		and ebx, 1F001F00H
		and eax, 007F007FH
		and ebp, 0E000E000H
		shr ebx, 8
		shr ebp, 7
		shl eax, 9
		or ebp, ebx
		add esi, 4
		or eax, ebp
		dec ecx
		mov [edx], eax
		jnz memcpy16_loop

memcpy16_end:
		pop ebx
		pop ebp
		pop esi
		ret 4
	}
}
#endif // OPTIMIZED_8BIT_MEMORY_ACCESS

/*
	*p4++ = (b1 & 0x00FFFFFF)       | b2 << 24;
	*p4++ = (b2 & 0x00FFFF00) >> 8  | b3 << 16;
	*p4++ = (b3 & 0x00FF0000) >> 16 | b4 << 8;
*/
static DWORD __declspec(naked) _fastcall memcpy24_9x( DWORD count, DWORD dst, DWORD src )
{
	_asm {
		push esi
		push ebx
		shr ecx, 2
		push ebp
		sub edx, 4
		test ecx, ecx
		mov esi, [esp+16]
		je memcpy24_9x_end

memcpy24_9x_loop:

		; *p4++ = (b1 & 0x00FFFFFF)       | b2 << 24;
		mov eax, [esi]				;b1
		add edx, 4
		add esi, 4
		and eax, 00ffffffH
		mov ebx, [esi]				;b2
		add esi, 4
		mov ebp, ebx					;b2
		shl ebx, 24
		and ebp, 00FFFF00H
		or  eax, ebx
		shr ebp, 8
		mov [edx], eax

		; *p4++ = (b2 & 0x00FFFF00) >> 8  | b3 << 16;
		mov eax, [esi]				;b3
		add edx, 4
		mov ebx, eax
		add esi, 4
		shl eax, 16
		or  eax, ebp
		mov [edx], eax

		; *p4++ = (b3 & 0x00FF0000) >> 16 | b4 << 8;
		mov ebp, [esi]				;b4
		and ebx, 00FF0000H
		shl ebp, 8
		add esi, 4
		shr ebx, 16
		add edx, 4
		or  ebp, ebx
		dec ecx
		mov [edx], ebp
		jnz memcpy24_9x_loop

memcpy24_9x_end:
		pop ebp
		pop ebx
		pop esi
		ret 4
	}
}

static void inline Screen_Draw(HDC hScreenDC)
{
  DWORD OldProtect;
  int y, line_count;
	HPALETTE hold1 = 0;
	DWORD i, j, min_a, max_a;
	DWORD offset, bytes;

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
	min_a = 0;
	max_a = mainBuffer.memLastPage;
	mainBuffer.dirty = 0;
#else
  if (pfnGetWriteWatch) {
		DWORD dwGranularity, cAddr = MAX_WRITE_WATCH_PAGES;
		if((*pfnGetWriteWatch)(
				WRITE_WATCH_FLAG_RESET,
				(PVOID)the_buffer,
				MacFrameSize,
				(PVOID *)&rglAddr,
				&cAddr,
				&dwGranularity
		)) return;
		if(!cAddr) return;

		min_a = max_a = (rglAddr[--cAddr] - mainBuffer.memBase) >> VM_PAGE_BITS;
		PFLAG_SET(min_a);
		if(mainBuffer.very_dirty) max_a = mainBuffer.memLastPage;
		while (cAddr) {
			i = (rglAddr[--cAddr] - mainBuffer.memBase) >> VM_PAGE_BITS;
			if(i <= mainBuffer.memLastPage) {
				PFLAG_SET(i);
				if(i < min_a) min_a = i; else if(i > max_a) max_a = i;
			}
		}
	} else {
		min_a = 0;
		max_a = mainBuffer.memLastPage;
	  mainBuffer.dirty = 0;
	}
#endif

	if(hPalMain2bits)
		hold1 = SelectPalette( hScreenDC, hPalMain2bits, FALSE );
	else if(hPalMain)
		hold1 = SelectPalette( hScreenDC, hPalMain, FALSE );

	i = min_a;
	for(;;) {
		// sentinel is at end
		while(PFLAG_ISCLEAR_4(i)) i += 4;
		while(PFLAG_ISCLEAR(i)) i++;
		if( i > max_a ) break;

		offset = (i<<VM_PAGE_BITS);
		j = i;
		bytes = 0;
		while(PFLAG_ISSET(i) && i <= max_a) {
			bytes += VM_PAGE_BYTES;
			PFLAG_CLEAR(i);
			i++;
		}

		y = mainBuffer.pages[j].top;
		line_count = mainBuffer.pages[i-1].bottom - y + 1;

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
		VirtualProtect( (LPVOID)(mainBuffer.memStart + offset), bytes, PAGE_READONLY, &OldProtect );
#else
		if(!pfnGetWriteWatch) {
			VirtualProtect( (LPVOID)(mainBuffer.memStart + offset), bytes, PAGE_READONLY, &OldProtect );
		}
#endif

		if(screen_bit_depth_mac == 2) {
			SetStretchBltMode( hScreenDC, COLORONCOLOR );
			StretchDIBits(
				hScreenDC,
				0, y,
				VideoMonitor.x, line_count,
				0, VideoMonitor.y - line_count - y,
				VideoMonitor.x<<1, line_count,
				(PVOID)mainBuffer.memBase,
				pbmi,
				bPalette,
				SRCCOPY
			);
		} else {
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
			switch(screen_bit_depth_mac) {
				case 15:
					memcpy15( bytes, (DWORD)mainBuffer.memStartAlt+offset, mainBuffer.memStart+offset );
					break;
				case 16:
					memcpy16( bytes, (DWORD)mainBuffer.memStartAlt+offset, mainBuffer.memStart+offset );
					break;
				case 32:
					memcpy32( bytes, (DWORD)mainBuffer.memStartAlt+offset, mainBuffer.memStart+offset );
					break;

			}
#endif
			SetDIBitsToDevice(
				hScreenDC,
				0, y,
				VideoMonitor.x, line_count,
				0, VideoMonitor.y - line_count - y,
				0, VideoMonitor.y,
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
				(PVOID)mainBuffer.memStartAlt,
#else
				(PVOID)mainBuffer.memBase,
#endif
				pbmi,
				bPalette
			);
		}
	}

	mainBuffer.very_dirty = 0;

	if(hold1) SelectPalette( hScreenDC, hold1, FALSE );
}

unsigned int WINAPI redraw_thread(LPVOID param)
{
	char caption[100];
	HDC hScreenDC;

	set_desktop();

	PFLAG_SET(mainBuffer.memLastPage+1); // sentinel

  int frame_counter = 0;
  DWORD showtime = GetTickCount() + 1000;

	if(classic_mode) {
		while(screen_inited) {
			Sleep(sleep_ticks);
			if(mainBuffer.dirty && screen_inited) {
				grab_draw_mutex();
				hScreenDC = GetDC(hMainWnd);
				if(hScreenDC) {
					Screen_Draw_classic(hScreenDC);
					ReleaseDC(hMainWnd,hScreenDC);
				}
				release_draw_mutex();
			}
			if(m_show_real_fps) {
				frame_counter++;
				if(GetTickCount() >= showtime && screen_inited) {
					wsprintf( caption, "%s [%d fps] ", m_has_caption ? GetString(STR_WINDOW_TITLE) : "", frame_counter );
					set_fps_caption( caption );
					frame_counter = 0;
					showtime = GetTickCount() + 1000;
				}
			}
		}
	} else {
		while(screen_inited) {
			Sleep(sleep_ticks);
			if(mainBuffer.dirty && screen_inited) {
				grab_draw_mutex();
				hScreenDC = GetDC(hMainWnd);
				if(hScreenDC) {
					Screen_Draw(hScreenDC);
					ReleaseDC(hMainWnd,hScreenDC);
				}
				release_draw_mutex();
			}
			if(m_show_real_fps) {
				frame_counter++;
				if(GetTickCount() >= showtime && screen_inited) {
					wsprintf( caption, "%s [%d fps] ", m_has_caption ? GetString(STR_WINDOW_TITLE) : "", frame_counter );
					set_fps_caption( caption );
					frame_counter = 0;
					showtime = GetTickCount() + 1000;
				}
			}
		}
	}

  threads[THREAD_SCREEN_GDI].h = NULL;
  threads[THREAD_SCREEN_GDI].tid = 0;
	_endthreadex( 0 );

  return 0;
}

static uint32 cl_table[16] = {
	0x00000000,
	0x01000000,
	0x00010000,
	0x01010000,
	0x00000100,
	0x01000100,
	0x00010100,
	0x01010100,
	0x00000001,
	0x01000001,
	0x00010001,
	0x01010001,
	0x00000101,
	0x01000101,
	0x00010101,
	0x01010101
};

// This function is not really needed anymore. The dx full screen routine
// would be able to handle this (save for the background filling).

static void inline Screen_Draw_dx_classic(void)
{
	HRESULT	ddrval;
  DWORD OldProtect;

	if(!dx_blits_allowed) return;
	if(mainBuffer.dirty == 0 && mainBuffer.very_dirty == 0) return;

	for(;;) {
		ddsd.dwSize = sizeof(ddsd);
		if(!b2_is_front_window()) break;
		ddrval = lpDDSPrimary->Lock(NULL, &ddsd, 0, NULL);

		if( ddrval == DD_OK ) {
			// uint8 *p2 = (BYTE *)ddsd.lpSurface + (640-512)/2 + (480-342)/2*dx_pitch;
			uint8 *p2 = (BYTE *)ddsd.lpSurface + 64 + 69*dx_pitch;

			if(mainBuffer.very_dirty) {
				mainBuffer.very_dirty = 0;
				memset( ddsd.lpSurface, 2, dx_pitch * 480 );
			}

			VirtualProtect( (LPVOID)the_buffer, 21888, PAGE_READONLY, &OldProtect );

			uint32 *p4 = (uint32 *)the_buffer;
			for( int y=342; y; y-- ) {
				uint32 *p3 = (uint32 *)p2;
				for( int x=16; x; x-- ) {
					uint32 wd = *p4++;
					*p3++ = cl_table[(wd>>4)&15];
					*p3++ = cl_table[wd&15];
					*p3++ = cl_table[(wd>>12)&15];
					*p3++ = cl_table[(wd>>8)&15];
					*p3++ = cl_table[(wd>>20)&15];
					*p3++ = cl_table[(wd>>16)&15];
					*p3++ = cl_table[wd>>28];
					*p3++ = cl_table[(wd>>24)&15];
				}
				p2 += dx_pitch;
			}
			lpDDSPrimary->Unlock(0);
			break;
		} else {
			if(dx_blits_allowed && b2_is_front_window()) {
				if( ddrval == DDERR_SURFACELOST && dx_blits_allowed ) {
					if(!is_windowed) (void)mySetDisplayMode( lpDD, VideoMonitor.x, VideoMonitor.y, screen_bit_depth_win );
					ddrval = restoreAll();
				}
				if( (ddrval == DDERR_INVALIDPIXELFORMAT || ddrval == DDERR_WRONGMODE) && !is_windowed) {
					ddrval = mySetDisplayMode( lpDD, VideoMonitor.x, VideoMonitor.y, screen_bit_depth_win );
				}
				if( ddrval != DD_OK && ddrval != DDERR_WASSTILLDRAWING ) break;
			} else {
				break;
			}
		}
	}
	mainBuffer.dirty = 0;
}

static uint8 do_dx_memcpy_scanlines;
static uint8 do_dx_memcpy_scanlines_multi;

static void inline Screen_Draw_dx(void)
{
  DWORD OldProtect;
	HRESULT	ddrval;
	DWORD i, j, min_a, max_a;
  BYTE *pbyScreen;
	DWORD x;
	DWORD offset, bytes, y;

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
	min_a = 0;
	max_a = mainBuffer.memLastPage;
	mainBuffer.dirty = 0;
#else
  if (pfnGetWriteWatch) {
		DWORD dwGranularity, cAddr = MAX_WRITE_WATCH_PAGES;
		if((*pfnGetWriteWatch)(
				WRITE_WATCH_FLAG_RESET,
				(PVOID)the_buffer,
				MacFrameSize,
				(PVOID *)&rglAddr,
				&cAddr,
				&dwGranularity
		)) return;
		if(!cAddr) return;

		min_a = max_a = (rglAddr[--cAddr] - mainBuffer.memBase) >> VM_PAGE_BITS;
		PFLAG_SET(min_a);
		if(mainBuffer.very_dirty) max_a = mainBuffer.memLastPage;
		while (cAddr) {
			i = (rglAddr[--cAddr] - mainBuffer.memBase) >> VM_PAGE_BITS;
			if(i <= mainBuffer.memLastPage) {
				PFLAG_SET(i);
				if(i < min_a) min_a = i; else if(i > max_a) max_a = i;
			}
		}
	} else {
		min_a = 0;
		max_a = mainBuffer.memLastPage;
		mainBuffer.dirty = 0;
	}
#endif

	while( dx_blits_allowed ) {
		DWORD w_offset;

		if(is_windowed) {
			RECT r;
			GetClientRect( hMainWnd, &r );
			ClientToScreen( hMainWnd, (LPPOINT)&r );
			w_offset = dx_scanlines[r.top];
			switch(screen_bit_depth_win) {
				case 1:  w_offset += r.left>>3; break;
				case 2:  w_offset += r.left>>2; break;
				case 4:  w_offset += r.left>>1; break;
				case 8:  w_offset += r.left; break;
				case 15:
				case 16: w_offset += r.left<<1; break;
				case 24: w_offset += (r.left<<1)+r.left; break;
				case 32: w_offset += r.left<<2; break;
			}
		} else {
			w_offset = 0;
		}

		ddsd.dwSize = sizeof(ddsd);
		// if(!b2_is_front_window()) break;
		ddrval = lpDDSPrimary->Lock(NULL, &ddsd, DDLOCK_WRITEONLY, NULL);

		if( ddrval == DD_OK ) {
			i = min_a;
			for(;;) {
				// sentinel is at end
				while(PFLAG_ISCLEAR_4(i)) i += 4;
				while(PFLAG_ISCLEAR(i)) i++;
				if( i > max_a ) break;

				offset = (i<<VM_PAGE_BITS);
				j = i;
				bytes = 0;
				while(PFLAG_ISSET(i) && i <= max_a) {
					bytes += VM_PAGE_BYTES;
					PFLAG_CLEAR(i);
					i++;
				}

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
				VirtualProtect( (LPVOID)(mainBuffer.memStart + offset), bytes, PAGE_READONLY, &OldProtect );
#else
				if(!pfnGetWriteWatch) {
					VirtualProtect( (LPVOID)(mainBuffer.memStart + offset), bytes, PAGE_READONLY, &OldProtect );
				}
#endif

				y = mainBuffer.pages[j].top;
				uint8 *p2 = (BYTE *)ddsd.lpSurface + dx_scanlines[y] + w_offset;
				pbyScreen = (BYTE *)mainBuffer.memBase + scanlines[y];
				y = mainBuffer.pages[i-1].bottom - y + 1;

				if(do_dx_memcpy_scanlines_multi) {
					memcpy( p2, pbyScreen, VideoMonitor.bytes_per_row*y );
				} else if(do_dx_memcpy_scanlines) {
					while(y--) {
						memcpy( p2, pbyScreen, VideoMonitor.bytes_per_row );
						p2 += dx_pitch;
						pbyScreen += VideoMonitor.bytes_per_row;
					}
				} else {
						// Low color modes: b&w, 4 colors, 16 colors
					switch(screen_bit_depth_mac) {
						case 1:
							{
							uint32 *bptr = (uint32 *)pbyScreen;
							uint32 VideoMonitor_x_per_32 = VideoMonitor.x>>5;
							while(y--) {
								uint32 *p3 = (uint32 *)p2;
								for( int x=VideoMonitor_x_per_32; x; x-- ) {
									uint32 wd = *bptr++;
									*p3++ = cl_table[(wd>>4)&15];
									*p3++ = cl_table[wd&15];
									*p3++ = cl_table[(wd>>12)&15];
									*p3++ = cl_table[(wd>>8)&15];
									*p3++ = cl_table[(wd>>20)&15];
									*p3++ = cl_table[(wd>>16)&15];
									*p3++ = cl_table[wd>>28];
									*p3++ = cl_table[(wd>>24)&15];
								}
								p2 += dx_pitch;
							}
							}
							break;
						case 2:
							{
							uint32 *bptr = (uint32 *)pbyScreen;
							uint32 VideoMonitor_bytes_per_row_per_4 = VideoMonitor.bytes_per_row>>2;
							while(y--) {
								uint32 *p4 = (uint32 *)p2;
								for( x=VideoMonitor_bytes_per_row_per_4; x; x-- ) {
									uint32 b = *bptr++;
									*p4++ = ((b & 0x000000C0) >> 6)   |
													((b & 0x00000030) << 4)   |
													((b & 0x0000000C) << 14)  |
													((b & 0x00000003) << 24);
									*p4++ = ((b & 0x0000C000) >> 14)  |
													((b & 0x00003000) >> 4)   |
													((b & 0x00000C00) << 6)   |
													((b & 0x00000300) << 16);
									*p4++ = ((b & 0x00C00000) >> 22)  |
													((b & 0x00300000) >> 12)  |
													((b & 0x000C0000) >> 2)   |
													((b & 0x00030000) << 8);
									*p4++ = ((b & 0xC0000000) >> 30)  |
													((b & 0x30000000) >> 20)  |
													((b & 0x0C000000) >> 10)  |
													( b & 0x03000000);
								}
								p2 += dx_pitch;
							}
							}
							break;
						case 4:
							{
							uint32 *bptr = (uint32 *)pbyScreen;
							uint32 VideoMonitor_bytes_per_row_per_4 = VideoMonitor.bytes_per_row>>2;
							while(y--) {
								uint32 *p4 = (uint32 *)p2;
								for( x=VideoMonitor_bytes_per_row_per_4; x; x-- ) {
									uint32 b = *bptr++;
									*p4++ = ((b & 0x000000F0) >> 4)  |
													((b & 0x0000000F) << 8)  |
													((b & 0x0000F000) << 4)  |
													((b & 0x00000F00) << 16);
									*p4++ = ((b & 0x00F00000) >> 20) |
													((b & 0x000F0000) >> 8)  |
													((b & 0xF0000000) >> 12) |
													 (b & 0x0F000000);
								}
								p2 += dx_pitch;
							}
							}
							break;
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
						case 15:
							if(equal_scanline_lengths) {
								memcpy15( dx_pitch*y, (DWORD)p2, (DWORD)pbyScreen );
							} else {
								DWORD bptr = (DWORD)pbyScreen;
								while(y--) {
									memcpy15( VideoMonitor.bytes_per_row, (DWORD)p2, bptr );
									bptr += VideoMonitor.bytes_per_row;
									p2 += dx_pitch;
								}
							}
							break;
						case 16:
							if(equal_scanline_lengths) {
								memcpy16( dx_pitch*y, (DWORD)p2, (DWORD)pbyScreen );
							} else {
								DWORD bptr = (DWORD)pbyScreen;
								while(y--) {
									memcpy16( VideoMonitor.bytes_per_row, (DWORD)p2, bptr );
									bptr += VideoMonitor.bytes_per_row;
									p2 += dx_pitch;
								}
							}
							break;
#endif
						case 32:
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
							if(screen_bit_depth_win == 32) {
								if(equal_scanline_lengths) {
									memcpy32( dx_pitch*y, (DWORD)p2, (DWORD)pbyScreen );
								} else {
									DWORD bptr = (DWORD)pbyScreen;
									while(y--) {
										memcpy32( VideoMonitor.bytes_per_row, (DWORD)p2, bptr );
										bptr += VideoMonitor.bytes_per_row;
										p2 += dx_pitch;
									}
								}
							} else
#endif
							{ // screen_bit_depth_win == 24
								// TODO: adapt for different pixel formats;
								//
								// Pre-calculate bitmasks and shift amounts using these:
								//
								// red = ddsd.ddpfPixelFormat.dwRBitMask;
								// green = ddsd.ddpfPixelFormat.dwGBitMask;
								// blue = ddsd.ddpfPixelFormat.dwBBitMask;
								//

								DWORD bptr = (DWORD)pbyScreen;
								while(y--) {
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
									memcpy24( VideoMonitor.x, (DWORD)p2, bptr );
#else
									memcpy24_9x( VideoMonitor.x, (DWORD)p2, bptr );
#endif
									bptr += VideoMonitor.bytes_per_row;
									p2 += dx_pitch;
								}
							}
							break;
					}
				}
			}
			lpDDSPrimary->Unlock(0);
			break;
		} else {
			if(dx_blits_allowed && b2_is_front_window()) {
				if( ddrval == DDERR_SURFACELOST ) {
					if(!is_windowed) (void)mySetDisplayMode( lpDD, VideoMonitor.x, VideoMonitor.y, screen_bit_depth_win );
					ddrval = restoreAll();
				}
				if( (ddrval == DDERR_INVALIDPIXELFORMAT || ddrval == DDERR_WRONGMODE) && !is_windowed) {
					ddrval = mySetDisplayMode( lpDD, VideoMonitor.x, VideoMonitor.y, screen_bit_depth_win );
				}
				if( ddrval != DD_OK && ddrval != DDERR_WASSTILLDRAWING ) break;
			} else {
				break;
			}
		}
	}

	mainBuffer.very_dirty = 0;
}

unsigned int WINAPI redraw_thread_d3d(LPVOID param)
{
	char caption[100];

	set_desktop();

  int frame_counter = 0;
  DWORD showtime = GetTickCount() + 1000;

	do_dx_memcpy_scanlines = (screen_bit_depth_mac >= 8);
	if(screen_bit_depth_win == 24 && !is_windowed) do_dx_memcpy_scanlines = 0;
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
	if(mem_8_only && screen_bit_depth_win > 8) do_dx_memcpy_scanlines = 0;
#endif

	do_dx_memcpy_scanlines_multi = do_dx_memcpy_scanlines && equal_scanline_lengths;

	if(classic_mode) {
		while(screen_inited) {
			Sleep(sleep_ticks);
			grab_draw_mutex();
			Screen_Draw_dx_classic();
			release_draw_mutex();
			if(m_show_real_fps) {
				frame_counter++;
				if(GetTickCount() >= showtime && screen_inited) {
					wsprintf( caption, "%s [%d fps] ", m_has_caption ? GetString(STR_WINDOW_TITLE) : "", frame_counter );
					set_fps_caption( caption );
					frame_counter = 0;
					showtime = GetTickCount() + 1000;
				}
			}
		}
	} else {
		PFLAG_SET(mainBuffer.memLastPage+1); // sentinel
		while(screen_inited) {
			Sleep(sleep_ticks);
			if(mainBuffer.dirty && screen_inited && dx_blits_allowed) {
				grab_draw_mutex();
				Screen_Draw_dx();
				release_draw_mutex();
			}
			if(m_show_real_fps) {
				frame_counter++;
				if(GetTickCount() >= showtime && screen_inited) {
					wsprintf( caption, "%s [%d fps] ", m_has_caption ? GetString(STR_WINDOW_TITLE) : "", frame_counter );
					set_fps_caption( caption );
					frame_counter = 0;
					showtime = GetTickCount() + 1000;
				}
			}
		}
	}

  threads[THREAD_SCREEN_DX].h = NULL;
  threads[THREAD_SCREEN_DX].tid = 0;
	_endthreadex( 0 );

  return 0;
}

// Special optimization for Win98 full screen modes.
// No need for the page bit table at all.
void inline Screen_Draw_dx_fullscreen(void)
{
	HRESULT	ddrval;
	DWORD offset, dwGranularity, cAddr, bytes;

	if(!dx_blits_allowed) return;

	cAddr = MAX_WRITE_WATCH_PAGES;
	if((*pfnGetWriteWatch)(
			WRITE_WATCH_FLAG_RESET,
			(PVOID)the_buffer,
			MacFrameSize,
			(PVOID *)&rglAddr,
			&cAddr,
			&dwGranularity
	)) return;
	if(!cAddr) return;

	DWORD max_frame_sz = dx_scanlines[VideoMonitor.y];

	while(dx_blits_allowed) {
		ddsd.dwSize = sizeof(ddsd);
		// if(!b2_is_front_window()) break;
		ddrval = lpDDSPrimary->Lock(NULL, &ddsd, 0, NULL);
		if( ddrval == DD_OK ) {
			if(mainBuffer.very_dirty) {
				mainBuffer.very_dirty = 0;
				memcpy(
					(PVOID)ddsd.lpSurface,
					(PVOID)mainBuffer.memBase,
					max_frame_sz
				);
			} else {
				while (cAddr--) {
					offset = rglAddr[cAddr] - mainBuffer.memBase;
					// Need to take some steps to protect cursor area
					bytes = VM_PAGE_BYTES;
					if(offset+VM_PAGE_BYTES > max_frame_sz) {
						if(offset >= max_frame_sz)
							continue;
						else
							bytes = max_frame_sz - offset;
					}
					memcpy( (PVOID)((DWORD)ddsd.lpSurface + offset), (PVOID)rglAddr[cAddr], bytes );
				}
			}
			lpDDSPrimary->Unlock(0);
			break;
		} else {
			if(dx_blits_allowed && b2_is_front_window()) {
				if( ddrval == DDERR_SURFACELOST && dx_blits_allowed ) {
					(void)mySetDisplayMode( lpDD, VideoMonitor.x, VideoMonitor.y, screen_bit_depth_win );
					ddrval = restoreAll();
				}
				if(ddrval == DDERR_INVALIDPIXELFORMAT || ddrval == DDERR_WRONGMODE) {
					ddrval = mySetDisplayMode( lpDD, VideoMonitor.x, VideoMonitor.y, screen_bit_depth_win );
				}
				if( ddrval != DD_OK && ddrval != DDERR_WASSTILLDRAWING ) break;
			} else {
				break;
			}
		}
	}
}

unsigned int WINAPI redraw_thread_d3d_fullscreen(LPVOID param)
{
	char caption[100];

	set_desktop();

  int frame_counter = 0;
  DWORD showtime = GetTickCount() + 1000;

  while(screen_inited) {
		Sleep(sleep_ticks);
	  if(mainBuffer.dirty && screen_inited) {
			grab_draw_mutex();
			Screen_Draw_dx_fullscreen();
			release_draw_mutex();
		}

		if(m_show_real_fps) {
			frame_counter++;
			if(GetTickCount() >= showtime && screen_inited) {
				wsprintf( caption, "%s [%d fps] ", m_has_caption ? GetString(STR_WINDOW_TITLE) : "", frame_counter );
				set_fps_caption( caption );
				frame_counter = 0;
				showtime = GetTickCount() + 1000;
			}
	  }
  }

  threads[THREAD_SCREEN_DX].h = NULL;
  threads[THREAD_SCREEN_DX].tid = 0;
	_endthreadex( 0 );

  return 0;
}

// When using linear frame buffer, graphics data is dumped
// directly on the screen. However, when the user task-switches
// away, we take a snapshot of the screen to "the_buffer" and
// set up background processing screen data to go temporarily
// to "the_buffer". When the user switches back, we blit the_buffer
// to screen and and resume linear frame buffer operation.
static void fb_blit( bool memorize )
{
	uint8 *p2 = (uint8 *)ddsd.lpSurface;
	uint8 *p1 = (uint8 *)the_buffer;
	int n1 = VideoMonitor.bytes_per_row;
	int n2 = ddsd.lPitch;
	if(n2 == 0) n2 = n1;
	for( int i=VideoMonitor.y; i; i-- ) {
		if(memorize) {
			memcpy( p1, p2, n2 );
		} else {
			memcpy( p2, p1, n2 );
		}
		p2 += n2;
		p1 += n1;
	}
}

// Buffer to pass the new palette to the frame buffer thread
static uint8 fb_buffer[768];


// Linear frame buffer thread
unsigned int WINAPI redraw_thread_fb(LPVOID param)
{
	// Is the frame locked *now*
	bool is_frame_locked = false;

	// Quit command breaks out from looping
	bool looping = true;

	// Indicates whether the next command should lock or not
	bool lock_next = true;

	// Flag used to inhibit locking when we are away
	bool waiting_to_be_locked = false;

  HRESULT	ddrval = 0;

	set_desktop();

	D(bug("fb start\n"));

	memset( &ddsd, 0, sizeof(ddsd) );
	ddsd.dwSize = sizeof( ddsd );

	while(looping) {
		if(lock_next) {
			D(bug("locking...\n"));

			for(;;) {
				memset( &ddsd, 0, sizeof(ddsd) );
				ddsd.dwSize = sizeof( ddsd );
				// if(!b2_is_front_window()) break;
				ddrval = lpDDSPrimary->Lock(NULL, &ddsd, 0, NULL);
				if( ddrval == DD_OK ) {
					is_frame_locked = true;
					MacFrameBaseHost = (BYTE *)ddsd.lpSurface;
					memory_init();
					if( fb_current_command == FB_LOCK) {
						D(bug("restoring frame...\n"));
						fb_blit(false);
					}
					break;
				} else {
					if( ddrval == DDERR_SURFACELOST ) {
						D(bug("fb surface lost, restoring\n"));
						(void)mySetDisplayMode( lpDD, VideoMonitor.x, VideoMonitor.y, screen_bit_depth_win );
						ddrval = restoreAll();
					}
					if(ddrval == DDERR_INVALIDPIXELFORMAT || ddrval == DDERR_WRONGMODE) {
						D(bug("fb invalid pixel format, restoring mode\n"));
						ddrval = mySetDisplayMode( lpDD, VideoMonitor.x, VideoMonitor.y, screen_bit_depth_win );
					}
					if( ddrval != DD_OK && ddrval != DDERR_WASSTILLDRAWING ) {
						D(bug("fb lock failed (0x%x)\n",(int)ddrval));
						break;
					}
				}
			}
		}

		if(!waiting_to_be_locked) lock_next = true;

		D(bug("fb waiting...\n"));
		WaitForSingleObject(fb_signal,INFINITE);

		if(is_frame_locked) {
			if( fb_current_command == FB_UNLOCK) {
				D(bug("memorizing frame...\n"));
				fb_blit(true);
			}

			D(bug("unlocking...\n"));
			MacFrameBaseHost = the_buffer;
			memory_init();
			for(;;) {
				ddrval = lpDDSPrimary->Unlock(0);
				if( ddrval == DD_OK ) {
					is_frame_locked = false;
					break;
				}
				if( ddrval != DD_OK && ddrval != DDERR_WASSTILLDRAWING ) break;
			}
		}

		if(waiting_to_be_locked) {
			if(fb_current_command != FB_LOCK && fb_current_command != FB_QUIT) {
				fb_current_command = FB_NONE;
				lock_next = false;
			}
		}

		switch( fb_current_command ) {
			case FB_UNLOCK:
				D(bug("FB_UNLOCK\n"));
				lock_next = false;
				waiting_to_be_locked = true;
				break;
			case FB_LOCK:
				D(bug("FB_LOCK\n"));
				waiting_to_be_locked = false;
				lock_next = true;
				break;
			case FB_QUIT:
				D(bug("FB_QUIT\n"));
				looping = false;
				break;
			case FB_SETPALETTE:
				D(bug("FB_SETPALETTE\n"));
				if(is_frame_locked) break;
				if(screen_bit_depth_win > 8) break;
				if(lpDDPal) {
					setup_palette_entries_dd3(fb_buffer);
					for(;;) {
						ddrval = lpDDPal->SetEntries( 0, 0, 256, lppal->palPalEntry );
						if( ddrval == DD_OK ) break;
						if( ddrval == DDERR_SURFACELOST ) {
							ddrval = restoreAll();
						}
						if( ddrval != DD_OK && ddrval != DDERR_WASSTILLDRAWING ) break;
					}
				}
				break;
			case FB_UPDATEPALETTE:
				D(bug("FB_UPDATEPALETTE\n"));
				if(lpDDPal && !is_frame_locked && screen_bit_depth_win <= 8) {
					for(;;) {
						ddrval = lpDDSPrimary->SetPalette(lpDDPal);
						if( ddrval == DD_OK ) break;
						if( ddrval == DDERR_SURFACELOST ) {
							ddrval = restoreAll();
						}
						if( ddrval != DD_OK && ddrval != DDERR_WASSTILLDRAWING ) break;
					}
				}
				break;
		}

		ReleaseSemaphore(fb_reply,1,NULL);
	}

	D(bug("fb thread stop\n"));

  threads[THREAD_SCREEN_LFB].h = NULL;
  threads[THREAD_SCREEN_LFB].tid = 0;
	_endthreadex( 0 );

	return(0);
}

void fb_command( uint8 cmd, LPBYTE param, uint32 sz )
{
	D(bug("fb command %ld\n",(long)cmd));

	if(!screen_inited) return;

	EnterCriticalSection( &fb_csection );
	fb_current_command = cmd;
	if(param && sz) {
		memcpy( fb_buffer, param, sz );
	}
	ReleaseSemaphore(fb_signal,1,NULL);
	WaitForSingleObject(fb_reply,INFINITE);
	LeaveCriticalSection( &fb_csection );
}

void video_activate( bool activate )
{
	if(!screen_inited) return;

	dx_blits_allowed = false;

	grab_draw_mutex();
	dx_blits_allowed = activate && (display_type == DISPLAY_DX);
	release_draw_mutex();

	/*
	grab_draw_mutex();
	dx_blits_allowed = false;
	release_draw_mutex();

	if(display_type == DISPLAY_DX) {
		if(activate) {
			// video_set_palette2(current_mac_palette);
			grab_draw_mutex();
			dx_blits_allowed = true;
			release_draw_mutex();
		}
	}
	*/
}
