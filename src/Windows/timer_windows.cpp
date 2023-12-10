/*
 *  timer_windows.cpp - Time Manager emulation for Win32
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
#include "main.h"
#include "timer.h"
#include "timer_windows.h"

#define DEBUG 0
#include "debug.h"

static uint32 frequency;
static tm_time_t mac_boot_ticks;
static tm_time_t mac_1904_ticks;
static tm_time_t mac_now_diff;

// const uint32 TIME_OFFSET = 0x7c25cca0;	// Offset Mac->BeOS time in seconds
// const uint32 TIME_OFFSET = 0x8b31ef80;	// Offset Mac->Amiga time in seconds
// const uint32 TIME_OFFSET = 0x7c25cca0;	// Offset Mac->Unix time in seconds

// Mac time starts in 1904, Unix time in 1970, this is the offset in seconds
// Where did this one come from?

const uint32 TIME_OFFSET = 0x7c25b080;


// Use tweaks below only on x86 platform, for example on
// a MIPS the frequency varies with clock speed

// Fastest is to undefine both, but timers are skewed by 19 percents

// Faster, skewed only by less than 0.5 percent
#define ALMOST_ACCURATE 0

// Exact calculation, a lot of IDIV's and IMUL's -- for 64 bit values!
#define ACCURATE 1

// MSECS2TICKS is called most often from TimeManager


#if ALMOST_ACCURATE
#define MSECS2TICKS(ms) (((tm_time_t)(ms))*1193)
#define USECS2TICKS(us) ((((tm_time_t)(us))*305)>>8)
#define TICKS2MSECS(ti) ((((tm_time_t)(ti))*214)>>8)
#elif ACCURATE
#define MSECS2TICKS(ms) ((((tm_time_t)(ms))*frequency)/1000)
#define USECS2TICKS(us) ((((tm_time_t)(us))*frequency)/1000000)
#define TICKS2MSECS(ti) ((((tm_time_t)(ti))*1000000)/frequency)
#else
#define MSECS2TICKS(ms) (ms)
#define USECS2TICKS(us) (us)
#define TICKS2MSECS(ti) (ti)
#endif // ACCURATE


#define HIGH(x) ((uint32)((x)/0x100000000))
#define LOW(x) ((uint32)((x) & 0xFFFFFFFF))

void timer_init()
{
  LARGE_INTEGER f;
	time_t t, bias_minutes;
  tm_time_t t2;
	TIME_ZONE_INFORMATION tz;

  if(!QueryPerformanceFrequency(&f)) {
		MessageBox(
			GetFocus(),
			"QueryPerformanceFrequency failed. "
			"Your hardware does not support high resolution timers. "
			"Basilisk II will now quit.",
			"Fatal error",
			MB_ICONEXCLAMATION | MB_OK
		);
		QuitEmulator();
	}

  frequency = f.LowPart;

	// mac_boot_ticks is 1.18 us ticks since BasiliskII was started
  QueryPerformanceCounter(&f);
	mac_boot_ticks = f.QuadPart;

	// seconds since 1970
  time( &t );

	memset( &tz, 0, sizeof(tz) );
	if(GetTimeZoneInformation( &tz ) == TIME_ZONE_ID_DAYLIGHT) {
		bias_minutes = tz.Bias + tz.DaylightBias;
	} else {
		bias_minutes = tz.Bias;
	}

	// seconds since 1904
	t2 = (tm_time_t)t - 60*bias_minutes + TIME_OFFSET;

	// mac_1904_ticks is 1.18 us ticks since Mac time started 1904
	mac_1904_ticks = (tm_time_t)t * frequency;

	mac_now_diff = mac_1904_ticks - mac_boot_ticks;

	D(bug("timer_init frequency=%d\n",frequency));
	D(bug("mac_boot_ticks %08X%08X\n", HIGH(mac_boot_ticks),LOW(mac_boot_ticks) ));
	D(bug("mac_1904_ticks %08X%08X\n", HIGH(mac_1904_ticks),LOW(mac_1904_ticks) ));
}


/*
 *  Return local date/time in Mac format (seconds since 1.1.1904)
 */

uint32 TimerDateTime(void)
{
	time_t bias_minutes;
	TIME_ZONE_INFORMATION tz;
	memset( &tz, 0, sizeof(tz) );
	if(GetTimeZoneInformation(&tz) == TIME_ZONE_ID_DAYLIGHT) {
		bias_minutes = tz.Bias + tz.DaylightBias;
	} else {
		bias_minutes = tz.Bias;
	}
	time_t uct_now = time(NULL) - 60*bias_minutes;
	return (uint32)uct_now + TIME_OFFSET;
}


/*
 *  Return microseconds since boot (64 bit)
 */

void Microseconds(uint32 &hi, uint32 &lo)
{
  LARGE_INTEGER tt;

  QueryPerformanceCounter(&tt);
	tt.QuadPart = TICKS2MSECS(tt.QuadPart - mac_boot_ticks);
	hi = tt.HighPart;
	lo = tt.LowPart;

	D(bug("Microseconds hi,lo %08X,%08X\n",hi,lo));
}


/*
 *  Get current time
 */

void timer_current_time(tm_time_t &t)
{
  LARGE_INTEGER tt;

  QueryPerformanceCounter(&tt);
	t = tt.QuadPart + mac_now_diff;

	D(bug("timer_current_time %08X%08X\n", HIGH(t),LOW(t) ));
}


/*
 *  Add times
 */

void timer_add_time(tm_time_t &res, tm_time_t a, tm_time_t b)
{
	res = a + b;
	D(bug("timer_add_time %08X:%08X+%08X:%08X=%08X:%08X\n",HIGH(a),LOW(a),HIGH(b),LOW(b),HIGH(res),LOW(res)));
}


/*
 *  Subtract times
 */

void timer_sub_time(tm_time_t &res, tm_time_t a, tm_time_t b)
{
	res = a - b;
	D(bug("timer_sub_time %08X:%08X+%08X:%08X=%08X:%08X\n",HIGH(a),LOW(a),HIGH(b),LOW(b),HIGH(res),LOW(res)));
}


/*
 *  Compare times (<0: a < b, =0: a = b, >0: a > b)
 */

int timer_cmp_time(tm_time_t a, tm_time_t b)
{
	tm_time_t r = a - b;

	D(bug("timer_cmp_time %08X%08X - %08X%08X = %08X%08X\n",
		HIGH(a), LOW(a),
		HIGH(b), LOW(b),
		HIGH(r), LOW(r)
		));

	return r < 0 ? -1 : (r > 0 ? 1 : 0);
}


/*
 *  Convert Mac time value (>0: microseconds, <0: microseconds) to tm_time_t
 */

// This is a time difference value, not absolute time

void timer_mac2host_time(tm_time_t &res, int32 mactime)
{
	D(bug("timer_mac2host_time %08X\n",mactime));

	if (mactime > 0) {
		// Time in milliseconds
		res = MSECS2TICKS(mactime);
	} else {
		// Time in negative microseconds
		res = USECS2TICKS(-mactime);
	}

	D(bug("timer_mac2host_time result %08X%08X\n", HIGH(res), LOW(res)));
}


/*
 *  Convert positive tm_time_t to Mac time value (>0: milliseconds, <0: microseconds)
 *  A negative input value for hosttime results in a zero return value
 *  As long as the microseconds value fits in 32 bit, it must not be converted to milliseconds!
 */

int32 timer_host2mac_time(tm_time_t hosttime)
{
	int32 res;

	if (hosttime < 0) {
		res = 0;
	} else {
		hosttime = TICKS2MSECS(hosttime);
		if (hosttime > 0x7fffffff)
			res = (int32)(hosttime / 1000);	// Time in milliseconds
		else
			res = (int32)(-hosttime);		// Time in negative microseconds
	}

	D(bug("timer_host2mac_time %08X%08X = %08X\n",HIGH(hosttime),LOW(hosttime),res));

	return(res);
}
