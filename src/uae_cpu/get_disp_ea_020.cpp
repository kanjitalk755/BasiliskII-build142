 /*
  * UAE - The Un*x Amiga Emulator
  *
  * MC68000 emulation
  *
  * (c) 1995 Bernd Schmidt
  *
  * Streamlined for Win32/MSVC5 by Lauri Pesonen
	* Various testers to see how EA behaves.
  *
  */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sysdeps.h"
#include "cpu_emulation.h"
#include "main.h"
#include "emul_op.h"
#include "m68k.h"
#include "memory.h"
#include "readcpu.h"
#include "newcpu.h"
#include "compiler.h"
#include "fpu.h"


#ifdef HAVE_GET_DISP_020_UNROLLED

ea020_func *ea_020_table[EA020_MASK];


#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
#define GET_DISP_EA_020_TABLE_ASM
#define GET_DISP_EA_020_TABLE_C
#else
#define GET_DISP_EA_020_TABLE_C
#endif


// Note GET_DISP_EA_020_TABLE_ASM not impl for PARAMS020 uae_udp dp, uae_u32 base


#define ASM_GEN 0
#define DISP_COUNT 0
#define DISP_COUNT_OPTIMIZED 0


#ifdef GET_DISP_EA_020_TABLE_ASM
#undef ASM_GEN
#undef DISP_COUNT
#undef DISP_COUNT_OPTIMIZED
#ifndef HAVE_GET_DISP_EA_020_SWAPPED_DP
#pragma message ("GET_DISP_EA_020_TABLE_ASM defined w/o HAVE_GET_DISP_EA_020_SWAPPED_DP")
#endif
#endif



#if DISP_COUNT == 1
uint32 disp_counts[256];
#elif DISP_COUNT == 2
uint32 disp_counts[65536];
#elif DISP_COUNT == 3
uint32 disp_counts[65536];
#endif

#if DISP_COUNT
void dump_disp_counts(void)
{
	FILE *f = fopen ("disp_counts.txt", "w");

#if DISP_COUNT == 1
	for (int i=0; i < 256; i++) {
#elif DISP_COUNT == 2
	for (int i=0; i < EA020_MASK; i++) {
#elif DISP_COUNT == 3
	for (int i=0; i < 65536; i++) {
#endif
		if(disp_counts[i]) fprintf (f, "%04x: %lu\n", i, disp_counts[i]);
	}
	fclose (f);
}

void clear_disp_counts(void)
{
	memset( disp_counts, 0, sizeof(disp_counts) );
}

static void DISP_REF (uae_udp dp)
{
#if DISP_COUNT == 1
	disp_counts[ (uae_u8)dp ] ++;
#elif DISP_COUNT == 2
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	disp_counts[ ((dp >> 8) | (dp << 8)) & 0x09FF ] ++;
#else
	disp_counts[ dp & 0x09FF ] ++;
#endif
#elif DISP_COUNT == 3
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	disp_counts[ ((dp >> 8) | (dp << 8)) & 0xFFFF ] ++;
#else
	disp_counts[ dp & 0xFFFF ] ++;
#endif
#endif
}
#if DISP_COUNT_OPTIMIZED
#define DISP_REF_OPT(dp) DISP_REF(dp)
#else
#define DISP_REF_OPT(dp)
#endif
#else
#define DISP_REF(dp)
#define DISP_REF_OPT(dp)
void dump_disp_counts(void) {}
void clear_disp_counts(void) {}
#endif //!DISP_COUNT




#if ASM_GEN
static inline uae_u32 do_get_mem_long_local(uae_u32 *a) {uint32 x = *a; return x;}
#define get_ilong_local(o) do_get_mem_long_local((uae_u32 *)(regs.pc_p + (o)))
static __inline__ uae_u32 next_ilong_local (void)
{
    uae_u32 r = get_ilong_local (0);
    m68k_incpc (4);
    return r;
}
#define next_ilong next_ilong_local
static __inline__ uae_u32 get_long_local(uaecptr a)
{
	uae_u32 *p = (uae_u32 *)( MEMBaseDiff + (DWORD)a );
	uae_u32 x = *p;
	return x;
}
#define get_long get_long_local
static inline uae_u16 do_get_mem_word_local(uae_u16 *a) {uint16 x = *a; return x;}
#define get_iword_local(o) do_get_mem_word_local((uae_u16 *)(regs.pc_p + (o)))
static __inline__ uae_u32 next_iword_local (void)
{
    uae_u32 r = get_iword_local (0);
    m68k_incpc (2);
    return r;
}
#define next_iword next_iword_local
#endif //!ASM_GEN


/*
	There is a big temptation to split this to a set of functions,
	eliminating all branches. Unfortunately, with the current UAE
	core, the L2 efficiency would suffer too much (I should know, I tried it).
*/

static uae_u32 REGPARAM2 get_disp_ea_020_fallback (PARAMS020)
{
	DISP_REF(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
#else
	int reg = (dp >> 12) & 15;
#endif

	uae_s32 regd;
	uae_s32 outer;

#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	if (dp & 0x8)
		regd = regs.regs[reg] << ((dp >> 1) & 3);
	else
	  regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
  switch( (uae_u8)(dp >> 8) ) {
#else
	if (dp & 0x800)
		regd = regs.regs[reg] << ((dp >> 9) & 3);
	else
	  regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);

  switch( (uae_u8)dp ) {
#endif
    case 0x00: case 0x08: case 0x04: case 0x0c: case 0x10: case 0x18: case 0x14: case 0x1c:
      return base + regd;

    case 0x01: case 0x09: case 0x11: case 0x19:
      return get_long (base + regd);

    case 0x02: case 0x0a:
      return get_long (base + regd) + (uae_s32)(uae_s16)next_iword();

    case 0x03: case 0x0b:
      return get_long (base + regd) + next_ilong();

    case 0x05: case 0x0d: case 0x15: case 0x1d:
      return get_long (base) + regd;

    case 0x06: case 0x0e:
      return get_long (base) + regd + (uae_s32)(uae_s16)next_iword();

    case 0x07: case 0x0f:
      return get_long (base) + regd + next_ilong();

    case 0x12: case 0x1a:
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base + regd);
      return base + outer;

    case 0x13: case 0x1b:
      outer = next_ilong();
      base = get_long (base + regd);
      return base + outer;

    case 0x16: case 0x1e:
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + regd + outer;

    case 0x17: case 0x1f:
      outer = next_ilong();
      base = get_long (base);
      return base + regd + outer;

    case 0x20: case 0x28: case 0x24: case 0x2c:
      base += (uae_s32)(uae_s16)next_iword();
      return base + regd;

    case 0x21: case 0x29:
      base += (uae_s32)(uae_s16)next_iword();
      return get_long (base + regd);

    case 0x22: case 0x2a:
      base += (uae_s32)(uae_s16)next_iword();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base + regd);
      return base + outer;

    case 0x23: case 0x2b:
      base += (uae_s32)(uae_s16)next_iword();
      outer = next_ilong();
      base = get_long (base + regd);
      return base + outer;

    case 0x25: case 0x2d:
      base += (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + regd;

    case 0x26: case 0x2e:
      base += (uae_s32)(uae_s16)next_iword();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + regd + outer;

    case 0x27: case 0x2f:
      base += (uae_s32)(uae_s16)next_iword();
      outer = next_ilong();
      base = get_long (base);
      return base + regd + outer;

    case 0x30: case 0x38: case 0x34: case 0x3c:
      base += next_ilong();
      return base + regd;

    case 0x31: case 0x39:
      base += next_ilong();
      return get_long (base + regd);

    case 0x32: case 0x3a:
      base += next_ilong();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base + regd);
      return base + outer;

    case 0x33: case 0x3b:
      base += next_ilong();
      outer = next_ilong();
      base = get_long (base + regd);
      return base + outer;

    case 0x35: case 0x3d:
      base += next_ilong();
      base = get_long (base);
      return base + regd;

    case 0x36: case 0x3e:
      base += next_ilong();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + regd + outer;

    case 0x37: case 0x3f:
      base += next_ilong();
      outer = next_ilong();
      base = get_long (base);
      return base + regd + outer;

    case 0x40: case 0x48: case 0x44: case 0x4c: case 0x50: case 0x58: case 0x54: case 0x5c:
      return base;

    case 0x41: case 0x49: case 0x45: case 0x4d: case 0x51: case 0x59: case 0x55: case 0x5d:
      return get_long (base);

    case 0x42: case 0x4a: case 0x46: case 0x4e: case 0x52: case 0x5a: case 0x56: case 0x5e:
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + outer;

    case 0x43: case 0x4b: case 0x47: case 0x4f: case 0x53: case 0x5b: case 0x57: case 0x5f:
      outer = next_ilong();
      base = get_long (base);
      return base + outer;

    case 0x60: case 0x68: case 0x64: case 0x6c:
      return base + (uae_s32)(uae_s16)next_iword();

    case 0x61: case 0x69: case 0x65: case 0x6d:
      base += (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base;

    case 0x62: case 0x6a: case 0x66: case 0x6e:
      base += (uae_s32)(uae_s16)next_iword();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + outer;

    case 0x63: case 0x6b: case 0x67: case 0x6f:
      base += (uae_s32)(uae_s16)next_iword();
      outer = next_ilong();
      base = get_long (base);
      return base + outer;

    case 0x70: case 0x78: case 0x74: case 0x7c:
      return base + next_ilong();

    case 0x71: case 0x79: case 0x75: case 0x7d:
      base += next_ilong();
      return get_long (base);

    case 0x72: case 0x7a: case 0x76: case 0x7e:
      base += next_ilong();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + outer;

    case 0x73: case 0x7b: case 0x77: case 0x7f:
      base += next_ilong();
      outer = next_ilong();
      base = get_long (base);
      return base + outer;

    case 0x80: case 0x88: case 0x84: case 0x8c: case 0x90: case 0x98: case 0x94: case 0x9c:
      return regd;

    case 0x81: case 0x89: case 0x91: case 0x99:
      return get_long (regd);

    case 0x82: case 0x8a: case 0x92: case 0x9a:
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (regd);
      return base + outer;

    case 0x83: case 0x8b: case 0x93: case 0x9b:
      outer = next_ilong();
      base = get_long (regd);
      return base + outer;

    case 0x85: case 0x8d: case 0x95: case 0x9d:
      return get_long (0) + regd;

    case 0x86: case 0x8e: case 0x96: case 0x9e:
      outer = (uae_s32)(uae_s16)next_iword();
      return get_long (0) + regd + outer;

    case 0x87: case 0x8f: case 0x97: case 0x9f:
      outer = next_ilong();
      return get_long (0) + regd + outer;

    case 0xa0: case 0xa8: case 0xa4: case 0xac:
      base = (uae_s32)(uae_s16)next_iword();
      return base + regd;

    case 0xa1: case 0xa9:
      base = (uae_s32)(uae_s16)next_iword();
      return get_long (base + regd);

    case 0xa2: case 0xaa:
      base = (uae_s32)(uae_s16)next_iword();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base + regd);
      return base + outer;

    case 0xa3: case 0xab:
      base = (uae_s32)(uae_s16)next_iword();
      outer = next_ilong();
      base = get_long (base + regd);
      return base + outer;

    case 0xa5: case 0xad:
      base = (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + regd;

    case 0xa6: case 0xae:
      base = (uae_s32)(uae_s16)next_iword();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + regd + outer;

    case 0xa7: case 0xaf:
      base = (uae_s32)(uae_s16)next_iword();
      outer = next_ilong();
      base = get_long (base);
      return base + regd + outer;

    case 0xb0: case 0xb8: case 0xb4: case 0xbc:
      return next_ilong() + regd;

    case 0xb1: case 0xb9:
      base = next_ilong();
      return get_long (base + regd);

    case 0xb2: case 0xba:
      base = next_ilong();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base + regd);
      return base + outer;

    case 0xb3: case 0xbb:
      base = next_ilong();
      outer = next_ilong();
      base = get_long (base + regd);
      return base + outer;

    case 0xb5: case 0xbd:
      return get_long (next_ilong()) + regd;

    case 0xb6: case 0xbe:
      base = next_ilong();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + regd + outer;

    case 0xb7: case 0xbf:
      base = next_ilong();
      outer = next_ilong();
      base = get_long (base);
      return base + regd + outer;

    case 0xc1: case 0xc9: case 0xc5: case 0xcd: case 0xd1: case 0xd9: case 0xd5: case 0xdd:
      return get_long (0);

    case 0xc2: case 0xca: case 0xc6: case 0xce:
      outer = (uae_s32)(uae_s16)next_iword();
      return get_long (0) + outer;

    case 0xc3: case 0xcb: case 0xc7: case 0xcf: case 0xd3: case 0xdb: case 0xd7: case 0xdf:
      outer = next_ilong();
      return get_long (0) + outer;

    case 0xd2: case 0xda: case 0xd6: case 0xde:
      outer = (uae_s32)(uae_s16)next_iword();
      return get_long (0) + outer;

    case 0xe0: case 0xe8: case 0xe4: case 0xec:
      return (uae_s32)(uae_s16)next_iword();

    case 0xe1: case 0xe9: case 0xe5: case 0xed:
      base = (uae_s32)(uae_s16)next_iword();
      return get_long (base);

    case 0xe2: case 0xea: case 0xe6: case 0xee:
      base = (uae_s32)(uae_s16)next_iword();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + outer;

    case 0xe3: case 0xeb: case 0xe7: case 0xef:
      base = (uae_s32)(uae_s16)next_iword();
      outer = next_ilong();
      base = get_long (base);
      return base + outer;

    case 0xf0: case 0xf8: case 0xf4: case 0xfc:
      return next_ilong();

    case 0xf1: case 0xf9: case 0xf5: case 0xfd:
      base = next_ilong();
      return get_long (base);

    case 0xf2: case 0xfa: case 0xf6: case 0xfe:
      base = next_ilong();
      outer = (uae_s32)(uae_s16)next_iword();
      base = get_long (base);
      return base + outer;

    case 0xf3: case 0xfb: case 0xf7: case 0xff:
      base = next_ilong();
      outer = next_ilong();
      base = get_long (base);
      return base + outer;

    // case 0xc0: case 0xc8: case 0xc4: case 0xcc: case 0xd0: case 0xd8: case 0xd4: case 0xdc:
    default: 
			return 0;
  }
}



/* Not too many of EA modes are actually used. It's feasible to have
   special handlers for the common modes.
*/


#ifdef GET_DISP_EA_020_TABLE_ASM

/*
	The asm code below depends on that the "regs" field is the first in
	the "struct regs". This is to work around an inline assembler bug
	in vc6. "movsx	eax, WORD PTR regs.regs[eax*4]" generates
	erroneous code, but "movsx	eax, WORD PTR regs[eax*4]" is ok.
*/

static _declspec(naked) uae_u32 REGPARAM2 get_disp_ea_000_long (PARAMS020)
{
	DISP_REF(dp);
	/*
	int reg = (dp >> 4) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 1) & 3);
  return base + (uae_s32)((uae_s8)(dp>>8)) + regd;
	*/
	_asm {
#ifndef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	push	esi
	mov	eax, ecx
	mov	esi, ecx
	shr	esi, 4
	shr	ecx, 1
	and	esi, 15
	and	ecx, 3
	mov	esi, DWORD PTR regs[esi*4]
	movsx	eax, ah
	shl	esi, cl
	add	eax, esi
	add	eax, edx
	pop	esi
	ret	0
	}
}

static _declspec(naked) uae_u32 REGPARAM2 get_disp_ea_000_short (PARAMS020)
{
	DISP_REF(dp);
	/*
	int reg = (dp >> 4) & 15;
  uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
  return base + (uae_s32)((uae_s8)(dp>>8)) + regd;
	*/
	_asm {
#ifndef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	push	esi
	mov	esi, ecx
	mov	eax, ecx
	shr	esi, 4
	shr	ecx, 1
	and	esi, 15
	and	ecx, 3
	movsx	esi, WORD PTR regs[esi*4]
	shl	esi, cl
	movsx	eax, ah
	add	edx, esi
	add	eax, edx
	pop	esi
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_000 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 4) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
  return base + regd;
	*/
	_asm {
#ifndef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	mov	eax, ecx
	shr	eax, 4
	shr	ecx, 1
	and	eax, 15
	and	ecx, 3
	movsx	eax, WORD PTR regs[eax*4]
	shl	eax, cl
	add	eax, edx
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_121 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
  base += (uae_s32)(uae_s16)next_iword();
  return get_long (base + regd);
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	mov	eax, edx
	push	esi
	shr	eax, 4
	mov	esi, ecx
	and	eax, 15
	mov	ecx, edx
	movsx	eax, WORD PTR regs[eax*4]
	shr	ecx, 1
	and	ecx, 3
	shl	eax, cl
	mov	ecx, DWORD PTR regs.pc_p
	mov	dx, WORD PTR [ecx]
	add	ecx, 2
	xchg dl, dh
	mov	DWORD PTR regs.pc_p, ecx
	movsx	ecx, dx
	add	eax, DWORD PTR MEMBaseDiff
	add	ecx, eax
	mov	eax, DWORD PTR [ecx+esi]
	pop	esi
	bswap eax
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_1a0 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
  base = (uae_s32)(uae_s16)next_iword();
  return base + regd;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	mov	edx, ecx
#else
	mov	ecx, edx
#endif
	push	esi
	mov	eax, ecx
	shr	eax, 4
	shr	ecx, 1
	and	eax, 15
	movsx	esi, WORD PTR regs[eax*4]
	and	ecx, 3
	mov	eax, DWORD PTR regs.pc_p
	shl	esi, cl
	mov	cx, WORD PTR [eax]
	add	eax, 2
	xchg cl, ch
	mov	DWORD PTR regs.pc_p, eax
	movsx	eax, cx
	add	eax, esi
	pop	esi
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_1a1 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
  base = (uae_s32)(uae_s16)next_iword();
  return get_long (base + regd);
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	mov	edx, ecx
#else
	mov	ecx, edx
#endif
	shr	edx, 4
	shr	ecx, 1
	and	edx, 15
	and	ecx, 3
	movsx	eax, WORD PTR regs[edx*4]
	shl	eax, cl
	mov	ecx, DWORD PTR regs.pc_p
	mov	dx, WORD PTR [ecx]
	add	ecx, 2
	xchg dl, dh
	mov	DWORD PTR regs.pc_p, ecx
	movsx	edx, dx
	add	edx, DWORD PTR MEMBaseDiff
	mov	eax, DWORD PTR [edx+eax]
	bswap eax
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_1e1 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
  base = (uae_s32)(uae_s16)next_iword();
  return get_long (base);
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	mov	eax, DWORD PTR regs.pc_p
	mov	dx, WORD PTR [eax]
	add	eax, 2
	xchg dl, dh
	mov	DWORD PTR regs.pc_p, eax
	mov	ecx, DWORD PTR MEMBaseDiff
	movsx	eax, dx
	mov	eax, DWORD PTR [eax+ecx]
	bswap eax
	ret	0
#else
	mov	eax, DWORD PTR regs.pc_p
	mov	cx, WORD PTR [eax]
	add	eax, 2
	xchg cl, ch
	mov	DWORD PTR regs.pc_p, eax
	mov	edx, DWORD PTR MEMBaseDiff
	movsx	eax, cx
	mov	eax, DWORD PTR [eax+edx]
	bswap eax
	ret	0
#endif
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_126 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
  base += (uae_s32)(uae_s16)next_iword();
  uae_s32 outer = (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + regd + outer;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	push	esi
	push	edi
	mov	eax, edx
	mov	edi, ecx
	shr	eax, 4
	mov	ecx, edx
	and	eax, 15
	shr	ecx, 1
	movsx	esi, WORD PTR regs[eax*4]
	mov	eax, DWORD PTR regs.pc_p
	and	ecx, 3
	shl	esi, cl
	mov	cx, WORD PTR [eax]
	add	eax, 2
	xchg cl, ch
	mov	DWORD PTR regs.pc_p, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	xchg dl, dh
	mov	DWORD PTR regs.pc_p, eax
	movsx	ecx, cx
	mov	eax, DWORD PTR MEMBaseDiff
	movsx	edx, dx
	add	ecx, eax
	mov	eax, DWORD PTR [ecx+edi]
	pop	edi
	bswap eax
	add	edx, esi
	pop	esi
	add	eax, edx
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_161 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
  base += (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	mov	eax, DWORD PTR regs.pc_p
	mov	cx, WORD PTR [eax]
	add	eax, 2
	xchg cl, ch
	mov	DWORD PTR regs.pc_p, eax
	movsx	eax, cx
	add	eax, DWORD PTR MEMBaseDiff
	mov	eax, DWORD PTR [eax+edx]
	bswap eax
	ret	0
#else
	mov	eax, DWORD PTR regs.pc_p
	mov	dx, WORD PTR [eax]
	add	eax, 2
	xchg dl, dh
	mov	DWORD PTR regs.pc_p, eax
	movsx	eax, dx
	add	eax, DWORD PTR MEMBaseDiff
	mov	eax, DWORD PTR [eax+ecx]
	bswap eax
	ret	0
#endif
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_151 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
  return get_long (base);
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	mov	eax, DWORD PTR MEMBaseDiff
	mov	eax, DWORD PTR [eax+edx]
	bswap eax
	ret	0
#else
	mov	eax, DWORD PTR MEMBaseDiff
	mov	eax, DWORD PTR [eax+ecx]
	bswap eax
	ret	0
#endif
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_990 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 9) & 3);
  return regd;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	mov	eax, ecx
	shr	eax, 4
	shr	ecx, 1
	and	eax, 15
	and	ecx, 3
	mov	eax, DWORD PTR regs.regs[eax*4]
	shl	eax, cl
	ret	0
#else
#endif
	mov	eax, edx
	mov	ecx, edx
	shr	eax, 4
	shr	ecx, 1
	and	eax, 15
	and	ecx, 3
	mov	eax, DWORD PTR regs.regs[eax*4]
	shl	eax, cl
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_191 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
  return get_long (regd);
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	mov	ecx, edx
	shr	edx, 4
	shr	ecx, 1
	and	edx, 15
	and	ecx, 3
	movsx	edx, WORD PTR regs[edx*4]
	mov	eax, DWORD PTR MEMBaseDiff
	shl	edx, cl
	mov	eax, DWORD PTR [edx+eax]
	bswap eax
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_120 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
  base += (uae_s32)(uae_s16)next_iword();
  return base + regd;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	mov	eax, edx
	push	edi
	push	esi
	mov	edi, ecx
	shr	eax, 4
	mov	ecx, edx
	and	eax, 15
	shr	ecx, 1
	movsx	esi, WORD PTR regs[eax*4]
	and	ecx, 3
	mov	eax, DWORD PTR regs.pc_p
	shl	esi, cl
	mov	cx, WORD PTR [eax]
	add	eax, 2
	xchg cl, ch
	mov	DWORD PTR regs.pc_p, eax
	add	edi, esi
	movsx	eax, cx
	add	eax, edi
	pop	esi
	pop	edi
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_921 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 9) & 3);
  base += (uae_s32)(uae_s16)next_iword();
  return get_long (base + regd);
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	push	esi
	mov	eax, edx
	mov	esi, ecx
	shr	eax, 4
	mov	ecx, edx
	and	eax, 15
	shr	ecx, 1
	mov	eax, DWORD PTR regs.regs[eax*4]
	and	ecx, 3
	shl	eax, cl
	mov	ecx, DWORD PTR regs.pc_p
	mov	dx, WORD PTR [ecx]
	add	ecx, 2
	xchg dl, dh
	mov	DWORD PTR regs.pc_p, ecx
	movsx	ecx, dx
	add	ecx, DWORD PTR MEMBaseDiff
	add	ecx, eax
	mov	eax, DWORD PTR [ecx+esi]
	pop	esi
	bswap eax
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_115 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
  return get_long (base) + regd;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	push	esi
	mov	eax, edx
	mov	esi, ecx
	shr	eax, 4
	mov	ecx, edx
	and	eax, 15
	shr	ecx, 1
	movsx	eax, WORD PTR regs[eax*4]
	and	ecx, 3
	shl	eax, cl
	mov	ecx, DWORD PTR MEMBaseDiff
	mov	edx, DWORD PTR [ecx+esi]
	bswap edx
	pop	esi
	add	eax, edx
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_925 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 9) & 3);
  base += (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + regd;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	push	esi
	mov	eax, ecx
	mov	esi, edx
	mov	ecx, edx
	shr	esi, 4
	shr	ecx, 1
	and	esi, 15
	and	ecx, 3
	mov	edx, DWORD PTR regs.regs[esi*4]
	shl	edx, cl
	mov	esi, DWORD PTR regs.pc_p
	mov	cx, WORD PTR [esi]
	xchg cl, ch
	add	esi, 2
	movsx	ecx, cx
	mov	DWORD PTR regs.pc_p, esi
	mov	esi, DWORD PTR MEMBaseDiff
	add	ecx, esi
	mov	eax, DWORD PTR [ecx+eax]
	pop	esi
	bswap eax
	add	eax, edx
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_162 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
  base += (uae_s32)(uae_s16)next_iword();
  uae_s32 outer = (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + outer;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	mov	eax, DWORD PTR regs.pc_p
	push	esi
	mov	dx, WORD PTR [eax]
	mov esi, ecx
	add	eax, 2
	xchg dl, dh
	mov	DWORD PTR regs.pc_p, eax
	mov	cx, WORD PTR [eax]
	add	eax, 2
	xchg cl, ch
	mov	DWORD PTR regs.pc_p, eax
	movsx	eax, dx
	add	eax, DWORD PTR MEMBaseDiff
	movsx	edx, cx
	mov	eax, DWORD PTR [eax+esi]
	bswap eax
	pop	esi
	add	eax, edx
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_1a5 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
  base = (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + regd;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	mov	ecx, edx
	push	esi
	mov	eax, ecx
	mov	edx, DWORD PTR MEMBaseDiff
	shr	eax, 4
	and	eax, 15
	shr	ecx, 1
	movsx	esi, WORD PTR regs[eax*4]
	and	ecx, 3
	mov	eax, DWORD PTR regs.pc_p
	shl	esi, cl
	mov	cx, WORD PTR [eax]
	add	eax, 2
	xchg cl, ch
	movsx	ecx, cx
	mov	DWORD PTR regs.pc_p, eax
	mov	eax, DWORD PTR [ecx+edx]
	bswap eax
	add	eax, esi
	pop	esi
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_125 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
  base += (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + regd;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	mov	eax, ecx
	push	esi
	mov	ecx, edx
	shr	edx, 4
	shr	ecx, 1
	and	edx, 15
	and	ecx, 3
	movsx	esi, WORD PTR regs[edx*4]
	shl	esi, cl
	mov	ecx, DWORD PTR regs.pc_p
	mov	dx, WORD PTR [ecx]
	add	ecx, 2
	xchg dl, dh
	mov	DWORD PTR regs.pc_p, ecx
	movsx	edx, dx
	mov	ecx, DWORD PTR MEMBaseDiff
	add	edx, ecx
	mov	eax, DWORD PTR [edx+eax]
	bswap eax
	add	eax, esi
	pop	esi
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_920 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
	int reg = (dp >> 12) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 9) & 3);
  base += (uae_s32)(uae_s16)next_iword();
  return base + regd;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	push	esi
	mov	eax, edx
	mov	esi, ecx
	shr	eax, 4
	mov	ecx, edx
	and	eax, 15
	shr	ecx, 1
	mov	edx, DWORD PTR regs.regs[eax*4]
	and	ecx, 3
	mov	eax, DWORD PTR regs.pc_p
	shl	edx, cl
	add	eax, 2
	mov	cx, WORD PTR [eax-2]
	mov	DWORD PTR regs.pc_p, eax
	xchg cl, ch
	add	edx, esi
	movsx	eax, cx
	pop	esi
	add	eax, edx
	ret	0
	}
}

uae_u32 _declspec(naked) REGPARAM2 get_disp_ea_020_1e2 (PARAMS020)
{
	DISP_REF_OPT(dp);
	/*
  base = (uae_s32)(uae_s16)next_iword();
  uae_s32 outer = (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + outer;
	*/
	_asm {
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	xchg ecx, edx
#endif
	mov	eax, DWORD PTR regs.pc_p
	mov	cx, WORD PTR [eax]
	add	eax, 2
	xchg cl, ch
	mov	DWORD PTR regs.pc_p, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	xchg dl, dh
	mov	DWORD PTR regs.pc_p, eax
	movsx	eax, cx
	movsx	edx, dx
	mov	ecx, DWORD PTR MEMBaseDiff
	mov	eax, DWORD PTR [eax+ecx]
	bswap eax
	add	eax, edx
	ret	0
	}
}

#else //!GET_DISP_EA_020_TABLE_ASM

static uae_u32 REGPARAM2 get_disp_ea_000_long (PARAMS020)
{
	DISP_REF(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 1) & 3);
  return base + (uae_s32)((uae_s8)(dp>>8)) + regd;
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 9) & 3);
  return base + (uae_s32)((uae_s8)dp) + regd;
#endif
}

static uae_u32 REGPARAM2 get_disp_ea_000_short (PARAMS020)
{
	DISP_REF(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
  uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
  return base + (uae_s32)((uae_s8)(dp>>8)) + regd;
#else
	int reg = (dp >> 12) & 15;
  uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
  return base + (uae_s32)((uae_s8)dp) + regd;
#endif
}

uae_u32 REGPARAM2 get_disp_ea_020_000 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
  return base + regd;
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
  return base + regd;
#endif
}

uae_u32 REGPARAM2 get_disp_ea_020_121 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
#endif
  base += (uae_s32)(uae_s16)next_iword();
  return get_long (base + regd);
}

uae_u32 REGPARAM2 get_disp_ea_020_1a0 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
#endif
  base = (uae_s32)(uae_s16)next_iword();
  return base + regd;
}

uae_u32 REGPARAM2 get_disp_ea_020_1a1 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
#endif
  base = (uae_s32)(uae_s16)next_iword();
  return get_long (base + regd);
}

uae_u32 REGPARAM2 get_disp_ea_020_1e1 (PARAMS020)
{
	DISP_REF_OPT(dp);
  base = (uae_s32)(uae_s16)next_iword();
  return get_long (base);
}

uae_u32 REGPARAM2 get_disp_ea_020_126 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
#endif
  base += (uae_s32)(uae_s16)next_iword();
  uae_s32 outer = (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + regd + outer;
}

uae_u32 REGPARAM2 get_disp_ea_020_161 (PARAMS020)
{
	DISP_REF_OPT(dp);
  base += (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base;
}

uae_u32 REGPARAM2 get_disp_ea_020_151 (PARAMS020)
{
	DISP_REF_OPT(dp);
  return get_long (base);
}

uae_u32 REGPARAM2 get_disp_ea_020_990 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 9) & 3);
#endif
  return regd;
}

uae_u32 REGPARAM2 get_disp_ea_020_191 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
#endif
  return get_long (regd);
}

uae_u32 REGPARAM2 get_disp_ea_020_120 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
#endif
  base += (uae_s32)(uae_s16)next_iword();
  return base + regd;
}

uae_u32 REGPARAM2 get_disp_ea_020_921 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 9) & 3);
#endif
  base += (uae_s32)(uae_s16)next_iword();
  return get_long (base + regd);
}

uae_u32 REGPARAM2 get_disp_ea_020_115 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
#endif
  return get_long (base) + regd;
}

uae_u32 REGPARAM2 get_disp_ea_020_925 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 9) & 3);
#endif
  base += (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + regd;
}

uae_u32 REGPARAM2 get_disp_ea_020_162 (PARAMS020)
{
	DISP_REF_OPT(dp);
  base += (uae_s32)(uae_s16)next_iword();
  uae_s32 outer = (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + outer;
}

uae_u32 REGPARAM2 get_disp_ea_020_1a5 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
#endif
  base = (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + regd;
}

uae_u32 REGPARAM2 get_disp_ea_020_125 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);
#endif
  base += (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + regd;
}

uae_u32 REGPARAM2 get_disp_ea_020_920 (PARAMS020)
{
	DISP_REF_OPT(dp);
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 1) & 3);
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd = regs.regs[reg] << ((dp >> 1) & 3);
#endif
  base += (uae_s32)(uae_s16)next_iword();
  return base + regd;
}

uae_u32 REGPARAM2 get_disp_ea_020_1e2 (PARAMS020)
{
	DISP_REF_OPT(dp);
  base = (uae_s32)(uae_s16)next_iword();
  uae_s32 outer = (uae_s32)(uae_s16)next_iword();
  base = get_long (base);
  return base + outer;
}
#endif // GET_DISP_EA_020_TABLE_ASM


static void set_ea020_entry( uint16 dp, ea020_func *fp )
{
	// It's faster to do "and #mask" in get_disp_ea_020() call
	// as opposed to fill in more table entries.

#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	dp = (dp >> 8) | (dp << 8);
#endif

  ea_020_table[dp] = (ea020_func *)fp;
}

void setup_ea_020_table(void)
{
	int dp;

	// First set default fallback.
	for(dp=0; dp<65536; dp++)
		ea_020_table[dp] = (ea020_func *)get_disp_ea_020_fallback;

	// Set separate fallback for 68000 compatible modes.
	for(dp=0; dp<65536; dp++) {
		// 68000 mode?
	  if ( (dp & 0x100) == 0) {
			if (dp & 0x800) {
				set_ea020_entry( dp, (ea020_func *)get_disp_ea_000_long );
			} else {
				set_ea020_entry( dp, (ea020_func *)get_disp_ea_000_short );
			}
		}
	}

	// Commonly used routines, 68000 mode.
	set_ea020_entry( 0x000, (ea020_func *)get_disp_ea_020_000 );

	// Commonly used routines, 68020 mode, grouped by aliases.
	set_ea020_entry( 0x121, (ea020_func *)get_disp_ea_020_121 );
	set_ea020_entry( 0x129, (ea020_func *)get_disp_ea_020_121 );

	set_ea020_entry( 0x1a0, (ea020_func *)get_disp_ea_020_1a0 );
	set_ea020_entry( 0x1a8, (ea020_func *)get_disp_ea_020_1a0 );
	set_ea020_entry( 0x1a4, (ea020_func *)get_disp_ea_020_1a0 );
	set_ea020_entry( 0x1ac, (ea020_func *)get_disp_ea_020_1a0 );

	set_ea020_entry( 0x1a1, (ea020_func *)get_disp_ea_020_1a1 );
	set_ea020_entry( 0x1a9, (ea020_func *)get_disp_ea_020_1a1 );

	set_ea020_entry( 0x1e1, (ea020_func *)get_disp_ea_020_1e1 );
	set_ea020_entry( 0x1e9, (ea020_func *)get_disp_ea_020_1e1 );
	set_ea020_entry( 0x1e5, (ea020_func *)get_disp_ea_020_1e1 );
	set_ea020_entry( 0x1ed, (ea020_func *)get_disp_ea_020_1e1 );

	set_ea020_entry( 0x126, (ea020_func *)get_disp_ea_020_126 );
	set_ea020_entry( 0x12e, (ea020_func *)get_disp_ea_020_126 );

	set_ea020_entry( 0x161, (ea020_func *)get_disp_ea_020_161 );
	set_ea020_entry( 0x169, (ea020_func *)get_disp_ea_020_161 );
	set_ea020_entry( 0x165, (ea020_func *)get_disp_ea_020_161 );
	set_ea020_entry( 0x16d, (ea020_func *)get_disp_ea_020_161 );

	set_ea020_entry( 0x151, (ea020_func *)get_disp_ea_020_151 );
	set_ea020_entry( 0x141, (ea020_func *)get_disp_ea_020_151 );
	set_ea020_entry( 0x149, (ea020_func *)get_disp_ea_020_151 );
	set_ea020_entry( 0x145, (ea020_func *)get_disp_ea_020_151 );
	set_ea020_entry( 0x14d, (ea020_func *)get_disp_ea_020_151 );
	set_ea020_entry( 0x159, (ea020_func *)get_disp_ea_020_151 );
	set_ea020_entry( 0x155, (ea020_func *)get_disp_ea_020_151 );
	set_ea020_entry( 0x15d, (ea020_func *)get_disp_ea_020_151 );

	set_ea020_entry( 0x990, (ea020_func *)get_disp_ea_020_990 );
	set_ea020_entry( 0x980, (ea020_func *)get_disp_ea_020_990 );
	set_ea020_entry( 0x988, (ea020_func *)get_disp_ea_020_990 );
	set_ea020_entry( 0x984, (ea020_func *)get_disp_ea_020_990 );
	set_ea020_entry( 0x98c, (ea020_func *)get_disp_ea_020_990 );
	set_ea020_entry( 0x998, (ea020_func *)get_disp_ea_020_990 );
	set_ea020_entry( 0x994, (ea020_func *)get_disp_ea_020_990 );
	set_ea020_entry( 0x99c, (ea020_func *)get_disp_ea_020_990 );

	set_ea020_entry( 0x191, (ea020_func *)get_disp_ea_020_191 );
	set_ea020_entry( 0x181, (ea020_func *)get_disp_ea_020_191 );
	set_ea020_entry( 0x189, (ea020_func *)get_disp_ea_020_191 );
	set_ea020_entry( 0x199, (ea020_func *)get_disp_ea_020_191 );

	set_ea020_entry( 0x120, (ea020_func *)get_disp_ea_020_120 );
	set_ea020_entry( 0x128, (ea020_func *)get_disp_ea_020_120 );
	set_ea020_entry( 0x124, (ea020_func *)get_disp_ea_020_120 );
	set_ea020_entry( 0x12c, (ea020_func *)get_disp_ea_020_120 );

	set_ea020_entry( 0x921, (ea020_func *)get_disp_ea_020_921 );
	set_ea020_entry( 0x929, (ea020_func *)get_disp_ea_020_921 );

	set_ea020_entry( 0x115, (ea020_func *)get_disp_ea_020_115 );
	set_ea020_entry( 0x105, (ea020_func *)get_disp_ea_020_115 );
	set_ea020_entry( 0x10d, (ea020_func *)get_disp_ea_020_115 );
	set_ea020_entry( 0x11d, (ea020_func *)get_disp_ea_020_115 );

	set_ea020_entry( 0x925, (ea020_func *)get_disp_ea_020_925 );
	set_ea020_entry( 0x92d, (ea020_func *)get_disp_ea_020_925 );

	set_ea020_entry( 0x162, (ea020_func *)get_disp_ea_020_162 );
	set_ea020_entry( 0x16a, (ea020_func *)get_disp_ea_020_162 );
	set_ea020_entry( 0x166, (ea020_func *)get_disp_ea_020_162 );
	set_ea020_entry( 0x16e, (ea020_func *)get_disp_ea_020_162 );

	set_ea020_entry( 0x1a5, (ea020_func *)get_disp_ea_020_1a5 );
	set_ea020_entry( 0x1ad, (ea020_func *)get_disp_ea_020_1a5 );

	set_ea020_entry( 0x125, (ea020_func *)get_disp_ea_020_125 );
	set_ea020_entry( 0x12d, (ea020_func *)get_disp_ea_020_125 );

	set_ea020_entry( 0x920, (ea020_func *)get_disp_ea_020_920 );
	set_ea020_entry( 0x928, (ea020_func *)get_disp_ea_020_920 );
	set_ea020_entry( 0x924, (ea020_func *)get_disp_ea_020_920 );
	set_ea020_entry( 0x92c, (ea020_func *)get_disp_ea_020_920 );

	set_ea020_entry( 0x1e2, (ea020_func *)get_disp_ea_020_1e2 );
	set_ea020_entry( 0x1ea, (ea020_func *)get_disp_ea_020_1e2 );
	set_ea020_entry( 0x1e6, (ea020_func *)get_disp_ea_020_1e2 );
	set_ea020_entry( 0x1ee, (ea020_func *)get_disp_ea_020_1e2 );
}

#else //!HAVE_GET_DISP_020_UNROLLED

////////////// more or less original. //////////////

void setup_ea_020_table(void) {}
void dump_disp_counts(void) {}
void clear_disp_counts(void) {}

uae_u32 REGPARAM2 get_disp_ea_020_generic (PARAMS020)
{
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
	int reg = (dp >> 4) & 15;
	uae_s32 regd;
	if (dp & 0x8)
		regd = regs.regs[reg] << ((dp >> 1) & 3);
	else
	  regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 1) & 3);

  if (dp & 0x1) {
		if (dp & 0x8000) base = 0;
		if (dp & 0x4000) regd = 0;

		if (dp & 0x3000) {
			if ((dp & 0x3000) == 0x2000) base += (uae_s32)(uae_s16)next_iword();
			else if ((dp & 0x3000) == 0x3000) base += next_ilong();
		}

		if (dp & 0x400) {
			if (dp & 0x300) {
				if ((dp & 0x300) == 0x200) {
					return get_long (base) + regd + (uae_s32)(uae_s16)next_iword();
				} else if ((dp & 0x300) == 0x300) {
					return get_long (base) + regd + next_ilong();
				} else {
					return get_long (base) + regd;
				}
			} else {
				return base + regd;
			}
		} else {
			if (dp & 0x300) {
				if ((dp & 0x300) == 0x200) {
					return get_long (base + regd) + (uae_s32)(uae_s16)next_iword();
				} else if ((dp & 0x300) == 0x300) {
					return get_long (base + regd) + next_ilong();
				} else {
					return get_long (base + regd);
				}
			} else {
			  return base + regd;
			}
		}
  } else {
	  return base + (uae_s32)((uae_s8)(dp>>8)) + regd;
  }
#else
	int reg = (dp >> 12) & 15;
	uae_s32 regd;
	if (dp & 0x800)
		regd = regs.regs[reg] << ((dp >> 9) & 3);
	else
	  regd = ((uae_s32)(uae_s16)regs.regs[reg]) << ((dp >> 9) & 3);

  if (dp & 0x100) {
		if (dp & 0x80) base = 0;
		if (dp & 0x40) regd = 0;

		if (dp & 0x30) {
			if ((dp & 0x30) == 0x20) base += (uae_s32)(uae_s16)next_iword();
			else if ((dp & 0x30) == 0x30) base += next_ilong();
		}

		if (dp & 0x4) {
			if (dp & 0x3) {
				if ((dp & 0x3) == 0x2) {
					return get_long (base) + regd + (uae_s32)(uae_s16)next_iword();
				} else if ((dp & 0x3) == 0x3) {
					return get_long (base) + regd + next_ilong();
				} else {
					return get_long (base) + regd;
				}
			} else {
				return base + regd;
			}
		} else {
			if (dp & 0x3) {
				if ((dp & 0x3) == 0x2) {
					return get_long (base + regd) + (uae_s32)(uae_s16)next_iword();
				} else if ((dp & 0x3) == 0x3) {
					return get_long (base + regd) + next_ilong();
				} else {
					return get_long (base + regd);
				}
			} else {
			  return base + regd;
			}
		}
  } else {
	  return base + (uae_s32)((uae_s8)dp) + regd;
  }
#endif
}

#endif //!HAVE_GET_DISP_020_UNROLLED
