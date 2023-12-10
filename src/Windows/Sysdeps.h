/*
 *  sysdeps.h - System dependent definitions for Win32
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

#ifndef _SYSDEPS_H_
#define _SYSDEPS_H_


// Some compiler may use different variable, and we need this.
#ifndef WIN32
#define WIN32
#endif


// 0x0400 is minimum for waitable timers.
// 0x0500 is minimum for vlm stuff

// Must be before <winnt.h>
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0500
#else
#if(_WIN32_WINNT < 0x0500)
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0500
#endif
#endif


// Needed for the new win98 stuff.
#ifndef _WIN32_WINDOWS
#define _WIN32_WINDOWS 0x0401
#else
#if(_WIN32_WINDOWS < 0x0401)
#undef _WIN32_WINDOWS
#define _WIN32_WINDOWS 0x0401
#endif
#endif

// Recommended.
#define HAVE_ASM_LOCKED_INTFLAGS 1

// Do not use.
// #define HAVE_VOID_CPU_FUNCS 1

// Fast divide, overflow check in exception routine.
#define OVERFLOW_EXCEPTIONS

// A work in progress.
// #define USE_COMPILER
#define CAN_MAP_MEMORY
// #define USE_MAPPED_MEMORY

// gencpu x86 flags
// #define X86_ASSEMBLY

// Assembly generation template
// #define X86_ASSEMBLY
// #define GENASM

// x86 cpu's don't have a major penalty accessing unaligned memory.
#define UNALIGNED_PROFITABLE

// Faster to have this defined.
#define HAVE_GET_WORD_UNSWAPPED

#ifndef WIN9X
// Speed up NT version. USE_COMPILER needs this.
#define OPTIMIZED_8BIT_MEMORY_ACCESS
#endif

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
#define HAVE_GET_DISP_EA_020_SWAPPED_DP
#define HAVE_GET_DISP_020_UNROLLED
// #define SWAPPED_ADDRESS_SPACE
#else
#define HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
#endif


// Recommended.
#define DO_INTERLOCKED

// I don't need prefetch.
#define DISABLE_PREFETCH 1


#ifndef _DEBUG
// If you use this, cpuemu.asm must be post-processed
// with vc5opti.exe, run through masm and relinked.
#define STREAMLINED_UAE
#endif

// True:  new method, cpufunctbl is read & write protected.
// This was a very interesting experiment, and demonstrates an alternative
// way to do interrupts. Unfortunately, the performance hit is far too great
// (instead of speeding things up!)
// #define SPECFLAG_EXCEPIONS

#include <sys/types.h>
#include <time.h>
#include <assert.h>
#include <stdio.h>
#include <windows.h>
#include <winnt.h>


// Are the Mac and the host address space the same?
// Do not define REAL_ADDRESSING under windows unless
// you do some serious implementation first
#define REAL_ADDRESSING 0

// Are we using a 68k emulator or the real thing?
#define EMULATED_68K 1

// Is the Mac ROM write protected?
#define ROM_IS_WRITE_PROTECTED 1

// Always on, turn off in GUI if you need to
#define SUPPORTS_EXTFS 1

// Data types
typedef unsigned char uint8;
typedef signed char int8;
typedef unsigned short uint16;
typedef signed short int16;
typedef unsigned long uint32;
typedef signed long int32;

#define true TRUE
#define false FALSE
typedef __int64 longlong;
typedef __int64 loff_t;

#ifdef __SC__ //For Symantec C++
typedef BOOL bool;
#endif

// Time data type for Time Manager emulation
typedef __int64 tm_time_t;

// UAE CPU data types
#define uae_s8 int8
#define uae_u8 uint8
#define uae_s16 int16
#define uae_u16 uint16
#define uae_s32 int32
#define uae_u32 uint32
typedef uae_u32 uaecptr;

#define uae_s64 __int64
#define uae_u64 unsigned __int64
#define UVAL64(x) ((unsigned __int64)(x))


// Endianess
#define LITTLE_ENDIAN
#define CAN_ACCESS_UNALIGNED 1


#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
#ifdef __cplusplus
extern "C" uae_u32 MEMBaseDiff;
#else
extern uae_u32 MEMBaseDiff;
#endif
#ifdef SWAPPED_ADDRESS_SPACE
extern uae_u32 MEMBaseLongTop;
extern uae_u32 MEMBaseWordTop;
extern uae_u32 MEMBaseByteTop;
#endif
#endif


#include "util_windows.h"


#ifndef NOMEMFUNCS

// UAE CPU defines
#ifdef LITTLE_ENDIAN

#ifdef SWAPPED_ADDRESS_SPACE
static inline uae_u32 do_get_mem_long(uae_u32 *a) {return *a;}
static inline uae_u16 do_get_mem_word(uae_u16 *a) {return *a;}
static inline void do_put_mem_long(uae_u32 *a, uae_u32 v) {*a = v;}
static inline void do_put_mem_word(uae_u16 *a, uae_u16 v) {*a = v;}
#elif __i386__
static inline uae_u32 do_get_mem_long(uae_u32 *a) {uint32 retval; __asm__ ("bswapl %0" : "=r" (retval) : "0" (*a) : "cc"); return retval;}
static inline uae_u16 do_get_mem_word(uae_u16 *a) {uint32 retval; __asm__ ("xorl %k0,%k0\n\tmovw %w1,%w0\n\trolw $8,%w0" : "=&r" (retval) : "m" (*a) : "cc"); return retval;}
static inline void do_put_mem_long(uae_u32 *a, uae_u32 v) {__asm__ ("bswapl %0" : "=r" (v) : "0" (v) : "cc"); *a = v;}
static inline void do_put_mem_word(uae_u16 *a, uae_u16 v) {__asm__ ("rolw $8,%0" : "=r" (v) : "0" (v) : "cc"); *a = v;}
#elif defined(CAN_ACCESS_UNALIGNED)
static inline uae_u32 do_get_mem_long(uae_u32 *a) {uint32 x = *a; return (x >> 24) | (x >> 8) & 0xff00 | (x << 8) & 0xff0000 | (x << 24);}
static inline uae_u16 do_get_mem_word(uae_u16 *a) {uint16 x = *a; return (x >> 8) | (x << 8);}
static inline void do_put_mem_long(uae_u32 *a, uae_u32 v) {*a = (v >> 24) | (v >> 8) & 0xff00 | (v << 8) & 0xff0000 | (v << 24);}
static inline void do_put_mem_word(uae_u16 *a, uae_u16 v) {*a = (v >> 8) | (v << 8);}
#else
static inline uae_u32 do_get_mem_long(uae_u32 *a) {uint8 *b = (uint8 *)a; return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];}
static inline uae_u16 do_get_mem_word(uae_u16 *a) {uint8 *b = (uint8 *)a; return (b[0] << 8) | b[1];}
static inline void do_put_mem_long(uae_u32 *a, uae_u32 v) {uint8 *b = (uint8 *)a; b[0] = v >> 24; b[1] = v >> 16; b[2] = v >> 8; b[3] = v;}
static inline void do_put_mem_word(uae_u16 *a, uae_u16 v) {uint8 *b = (uint8 *)a; b[0] = v >> 8; b[1] = v;}
#endif
#elif defined(CAN_ACCESS_UNALIGNED)
static inline uae_u32 do_get_mem_long(uae_u32 *a) {return *a;}
static inline uae_u16 do_get_mem_word(uae_u16 *a) {return *a;}
static inline void do_put_mem_long(uae_u32 *a, uae_u32 v) {*a = v;}
static inline void do_put_mem_word(uae_u16 *a, uae_u16 v) {*a = v;}
#else
static inline uae_u32 do_get_mem_long(uae_u32 *a) {uint8 *b = (uint8 *)a; return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];}
static inline uae_u16 do_get_mem_word(uae_u16 *a) {uint8 *b = (uint8 *)a; return (b[0] << 8) | b[1];}
static inline void do_put_mem_long(uae_u32 *a, uae_u32 v) {uint8 *b = (uint8 *)a; b[0] = v >> 24; b[1] = v >> 16; b[2] = v >> 8; b[3] = v;}
static inline void do_put_mem_word(uae_u16 *a, uae_u16 v) {uint8 *b = (uint8 *)a; b[0] = v >> 8; b[1] = v;}
#endif

#define do_get_mem_byte(a) ((uae_u32)*((uae_u8 *)(a)))
#define do_put_mem_byte(a, v) (*(uae_u8 *)(a) = (v))
// static inline uae_u8 do_get_mem_byte(uae_u8 *a) {return *a;}
// static inline void do_put_mem_byte(uae_u8 *a, uae_u8 v) {*a = v;}

#define call_mem_get_func(func, addr) ((*func)(addr))
#define call_mem_put_func(func, addr, v) ((*func)(addr, v))

#endif // MEMFUNCS

#define __inline__ inline
#define CPU_EMU_SIZE 0
#undef NO_INLINE_MEMORY_ACCESS
#undef MD_HAVE_MEM_1_FUNCS

#define REGPARAM
#define REGPARAM2 _fastcall
#define REGPARAM3
#define ENUMDECL typedef enum
#define ENUMNAME(name) name
#define ASM_SYM_FOR_FUNC(a)

#define write_log printf

#endif
