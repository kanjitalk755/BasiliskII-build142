/*
 *  threads_windows.h
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

#ifndef _THREADS_WINDOWS_H_
#define _THREADS_WINDOWS_H_

enum {
	THREAD_ETHER=0,
	THREAD_SERIAL_IN,
	THREAD_SERIAL_OUT,
	THREAD_CPU,
	THREAD_60_HZ,
	THREAD_1_HZ,
	THREAD_PARAMETER_RAM,
	THREAD_GUI,
	THREAD_SCREEN_GDI,
	THREAD_SCREEN_DX,
	THREAD_SCREEN_LFB,
	THREAD_SOUND_STREAM,
	THREAD_NONE,
	THREAD_COUNT = THREAD_NONE
};

typedef struct _thread_struct {
	HANDLE h;
	unsigned int tid;
	int priority_running;
	int priority_suspended;
	int def_priority_running;
	int def_priority_suspended;
	char *name;
	DWORD affinity_mask;
} thread_struct;

extern thread_struct threads[THREAD_COUNT];

void threads_init(void);
void threads_put_prefs(void);

#endif // _THREADS_WINDOWS_H_
