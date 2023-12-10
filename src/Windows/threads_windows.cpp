/*
 *  thread_windows.cpp
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
#include "main_windows.h"
#include "threads_windows.h"

thread_struct threads[THREAD_COUNT];

void threads_init(void)
{
	DWORD ProcessAffinityMask = 1, SystemAffinityMask = 1;

	if(!GetProcessAffinityMask(
		GetCurrentProcess(),
		&ProcessAffinityMask,
		&SystemAffinityMask) || ProcessAffinityMask == 0)
	{
		ProcessAffinityMask = 1;
	}

	int i;
	for( i=0; i<THREAD_COUNT; i++ ) {
		threads[i].h = 0;
		threads[i].tid = 0;
		threads[i].affinity_mask = ProcessAffinityMask;
	}

	threads[THREAD_ETHER].def_priority_running = THREAD_PRIORITY_NORMAL;
	threads[THREAD_ETHER].def_priority_suspended = THREAD_PRIORITY_NORMAL;
	threads[THREAD_ETHER].name = "ether";
	if(PrefsFindInt32("smp_ethernet") != 0) threads[THREAD_ETHER].affinity_mask = PrefsFindInt32("smp_ethernet");

	threads[THREAD_SERIAL_IN].def_priority_running = THREAD_PRIORITY_NORMAL;
	threads[THREAD_SERIAL_IN].def_priority_suspended = THREAD_PRIORITY_NORMAL;
	threads[THREAD_SERIAL_IN].name = "serial_in";
	if(PrefsFindInt32("smp_serialin") != 0) threads[THREAD_SERIAL_IN].affinity_mask = PrefsFindInt32("smp_serialin");

	threads[THREAD_SERIAL_OUT].def_priority_running = THREAD_PRIORITY_NORMAL;
	threads[THREAD_SERIAL_OUT].def_priority_suspended = THREAD_PRIORITY_NORMAL;
	threads[THREAD_SERIAL_OUT].name = "serial_out";
	if(PrefsFindInt32("smp_serialout") != 0) threads[THREAD_SERIAL_OUT].affinity_mask = PrefsFindInt32("smp_serialout");

	threads[THREAD_CPU].def_priority_running = THREAD_PRIORITY_NORMAL;
	threads[THREAD_CPU].def_priority_suspended = THREAD_PRIORITY_BELOW_NORMAL;
	threads[THREAD_CPU].name = "cpu";
	if(PrefsFindInt32("smp_cpu") != 0) threads[THREAD_CPU].affinity_mask = PrefsFindInt32("smp_cpu");

	threads[THREAD_60_HZ].def_priority_running = THREAD_PRIORITY_ABOVE_NORMAL;
	threads[THREAD_60_HZ].def_priority_suspended = THREAD_PRIORITY_ABOVE_NORMAL;
	threads[THREAD_60_HZ].name = "60hz";
	if(PrefsFindInt32("smp_60hz") != 0) threads[THREAD_60_HZ].affinity_mask = PrefsFindInt32("smp_60hz");

	threads[THREAD_1_HZ].def_priority_running = THREAD_PRIORITY_ABOVE_NORMAL;
	threads[THREAD_1_HZ].def_priority_suspended = THREAD_PRIORITY_ABOVE_NORMAL;
	threads[THREAD_1_HZ].name = "1hz";
	if(PrefsFindInt32("smp_1hz") != 0) threads[THREAD_1_HZ].affinity_mask = PrefsFindInt32("smp_1hz");

	threads[THREAD_PARAMETER_RAM].def_priority_running = THREAD_PRIORITY_NORMAL;
	threads[THREAD_PARAMETER_RAM].def_priority_suspended = THREAD_PRIORITY_BELOW_NORMAL;
	threads[THREAD_PARAMETER_RAM].name = "pram";
	if(PrefsFindInt32("smp_pram") != 0) threads[THREAD_PARAMETER_RAM].affinity_mask = PrefsFindInt32("smp_pram");

	threads[THREAD_GUI].def_priority_running = THREAD_PRIORITY_ABOVE_NORMAL;
	threads[THREAD_GUI].def_priority_suspended = THREAD_PRIORITY_NORMAL;
	threads[THREAD_GUI].name = "gui";
	if(PrefsFindInt32("smp_gui") != 0) threads[THREAD_GUI].affinity_mask = PrefsFindInt32("smp_gui");

	threads[THREAD_SCREEN_GDI].def_priority_running = THREAD_PRIORITY_NORMAL;
	threads[THREAD_SCREEN_GDI].def_priority_suspended = THREAD_PRIORITY_BELOW_NORMAL;
	threads[THREAD_SCREEN_GDI].name = "gdi";
	if(PrefsFindInt32("smp_gdi") != 0) threads[THREAD_SCREEN_GDI].affinity_mask = PrefsFindInt32("smp_gdi");

	threads[THREAD_SCREEN_DX].def_priority_running = THREAD_PRIORITY_NORMAL;
	threads[THREAD_SCREEN_DX].def_priority_suspended = THREAD_PRIORITY_BELOW_NORMAL;
	threads[THREAD_SCREEN_DX].name = "dx";
	if(PrefsFindInt32("smp_dx") != 0) threads[THREAD_SCREEN_DX].affinity_mask = PrefsFindInt32("smp_dx");

	threads[THREAD_SCREEN_LFB].def_priority_running = THREAD_PRIORITY_NORMAL;
	threads[THREAD_SCREEN_LFB].def_priority_suspended = THREAD_PRIORITY_BELOW_NORMAL;
	threads[THREAD_SCREEN_LFB].name = "fb";
	if(PrefsFindInt32("smp_fb") != 0) threads[THREAD_SCREEN_LFB].affinity_mask = PrefsFindInt32("smp_fb");

	threads[THREAD_SOUND_STREAM].def_priority_running = THREAD_PRIORITY_NORMAL;
	threads[THREAD_SOUND_STREAM].def_priority_suspended = THREAD_PRIORITY_NORMAL;
	threads[THREAD_SOUND_STREAM].name = "sound";
	if(PrefsFindInt32("smp_audio") != 0) threads[THREAD_SOUND_STREAM].affinity_mask = PrefsFindInt32("smp_audio");

	for( i=0; i<THREAD_COUNT; i++ ) {
		threads[i].priority_running = threads[i].def_priority_running;
		threads[i].priority_suspended = threads[i].def_priority_suspended;
	}

	char name[100];
	const char *nval;

	for( i=0; i<THREAD_COUNT; i++ ) {
		sprintf( name, "priority_%s_run", threads[i].name );
		nval = PrefsFindString(name);
		if(nval && *nval) threads[i].priority_running = atoi(nval);
		sprintf( name, "priority_%s_idle", threads[i].name );
		nval = PrefsFindString(name);
		if(nval && *nval) threads[i].priority_suspended = atoi(nval);
	}
}

void threads_put_prefs(void)
{
	int i;
	char name[100];
	char nval[100];

	for( i=0; i<THREAD_COUNT; i++ ) {
		sprintf( name, "priority_%s_run", threads[i].name );
		sprintf( nval, "%d", (int)threads[i].priority_running );
		PrefsReplaceString( name, nval );
		sprintf( name, "priority_%s_idle", threads[i].name );
		sprintf( nval, "%d", (int)threads[i].priority_suspended );
		PrefsReplaceString( name, nval );
	}
}
