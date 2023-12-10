/*
 *  headers_windows.cpp
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

// TODO: version info must be visible somewhere
//       rom file name prefs item

#include <stdio.h>
#include <process.h>
#include <math.h>
#include <stdio.h>

#include "sysdeps.h"
#include "main_windows.h"
#include "threads_windows.h"
#include "video_windows.h"
#include "timer_windows.h"
#include "xpram_windows.h"
#include "desktop_windows.h"
#include "sys_windows.h"
#include "prefs_windows.h"
#include "resource.h"
#include "keyboard_windows.h"
#include "check_windows.h"
#include "kernel_windows.h"

#include <dbt.h>
#include <windowsx.h>

#include "headers_windows.h"
