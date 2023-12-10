 /*
  * UAE - The Un*x Amiga Emulator
  *
  * Memory management
  *
  * (c) 1995 Bernd Schmidt
  *
  * Streamlined for Win32/MSVC5 by Lauri Pesonen
  *
  */

#include <stdio.h>
#include <stdlib.h>

#include "sysdeps.h"

#include "cpu_emulation.h"
#include "m68k.h"
#include "memory.h"
#include "readcpu.h"
#include "newcpu.h"
#include "main.h"
#include "video.h"



#define REGNAKED __declspec(naked)
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
#define DBREAK _asm { int 3 }
#else
#define DBREAK
#endif

static bool illegal_mem = false;

addrbank					mem_banks[65536>>(BANK_SHIFT-16)];


#ifdef NO_INLINE_MEMORY_ACCESS
__inline__ uae_u32 longget (uaecptr addr)
{
    return call_mem_get_func (get_mem_bank (addr).lget, addr);
}
__inline__ uae_u32 wordget (uaecptr addr)
{
    return call_mem_get_func (get_mem_bank (addr).wget, addr);
}
__inline__ uae_u32 byteget (uaecptr addr)
{
    return call_mem_get_func (get_mem_bank (addr).bget, addr);
}
__inline__ void longput (uaecptr addr, uae_u32 l)
{
    call_mem_put_func (get_mem_bank (addr).lput, addr, l);
}
__inline__ void wordput (uaecptr addr, uae_u32 w)
{
    call_mem_put_func (get_mem_bank (addr).wput, addr, w);
}
__inline__ void byteput (uaecptr addr, uae_u32 b)
{
    call_mem_put_func (get_mem_bank (addr).bput, addr, b);
}
#endif

/* A dummy bank that only contains zeros */

static uae_u32 REGPARAM2 dummy_lget (uaecptr) REGPARAM;
static uae_u32 REGPARAM2 dummy_wget (uaecptr) REGPARAM;
static uae_u32 REGPARAM2 dummy_bget (uaecptr) REGPARAM;
static void REGPARAM2 dummy_lput (uaecptr, uae_u32) REGPARAM;
static void REGPARAM2 dummy_wput (uaecptr, uae_u32) REGPARAM;
static void REGPARAM2 dummy_bput (uaecptr, uae_u32) REGPARAM;
static int REGPARAM2 dummy_check (uaecptr addr, uae_u32 size) REGPARAM;

uae_u32 REGPARAM2 dummy_lget (uaecptr addr)
{
	DBREAK;
	if (illegal_mem)
		write_log ("Illegal lget at %08lx\n", addr);

  return 0;
}

uae_u32 REGPARAM2 dummy_wget (uaecptr addr)
{
	DBREAK;
  if (illegal_mem)
		write_log ("Illegal wget at %08lx\n", addr);

  return 0;
}

uae_u32 REGPARAM2 dummy_bget (uaecptr addr)
{
	DBREAK;
  if (illegal_mem)
		write_log ("Illegal bget at %08lx\n", addr);

  return 0;
}

void REGPARAM2 dummy_lput (uaecptr addr, uae_u32 l)
{
	DBREAK;
  if (illegal_mem)
		write_log ("Illegal lput at %08lx\n", addr);
}

void REGPARAM2 dummy_wput (uaecptr addr, uae_u32 w)
{
	DBREAK;
  if (illegal_mem)
		write_log ("Illegal wput at %08lx\n", addr);
}

void REGPARAM2 dummy_bput (uaecptr addr, uae_u32 b)
{
	DBREAK;
  if (illegal_mem)
		write_log ("Illegal bput at %08lx\n", addr);
}

int REGPARAM2 dummy_check (uaecptr addr, uae_u32 size)
{
	DBREAK;
  if (illegal_mem)
		write_log ("Illegal check at %08lx\n", addr);

  return 0;
}

/* Mac RAM (32 bit addressing) */

uae_u32 REGPARAM2 ram_lget(uaecptr) REGPARAM;
uae_u32 REGPARAM2 ram_wget(uaecptr) REGPARAM;
uae_u32 REGPARAM2 ram_bget(uaecptr) REGPARAM;
void  REGPARAM2 ram_lput(uaecptr, uae_u32) REGPARAM;
void  REGPARAM2 ram_wput(uaecptr, uae_u32) REGPARAM;
void  REGPARAM2 ram_bput(uaecptr, uae_u32) REGPARAM;

int   REGPARAM2 ram_check(uaecptr addr, uae_u32 size) REGPARAM;
uae_u8 *REGPARAM2 ram_xlate(uaecptr addr) REGPARAM;

static uae_u32 RAMBaseDiff;	// RAMBaseHost - RAMBaseMac


uae_u32 REGNAKED REGPARAM2 ram_lget(uaecptr addr)
{
  _asm { 
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
		and   ecx, 07FFFFFFFh
#endif
    add   ecx,[RAMBaseDiff]
    mov   eax,[ecx]
    bswap eax
    ret
  };
}

uae_u32 REGNAKED REGPARAM2 ram_wget(uaecptr addr)
{
  _asm { 
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
		and   ecx, 07FFFFFFFh
#endif
    xor   eax,eax
    add   ecx,[RAMBaseDiff]
    mov   ax,[ecx]
    xchg  al,ah
    ret
  };
}

uae_u32 REGNAKED REGPARAM2 ram_bget(uaecptr addr)
{
  _asm { 
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
		and   ecx, 07FFFFFFFh
#endif
    xor   eax,eax
    add   ecx,[RAMBaseDiff]
    mov   al,[ecx]
    ret
  };
}

void REGNAKED REGPARAM2 ram_lput(uaecptr addr, uae_u32 l)
{
  _asm { 
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
		and   ecx, 07FFFFFFFh
#endif
    bswap edx
    add   ecx,[RAMBaseDiff]
    mov   [ecx],edx
    ret
  };
}

void REGNAKED REGPARAM2 ram_wput(uaecptr addr, uae_u32 w)
{
  _asm { 
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
		and   ecx, 07FFFFFFFh
#endif
    xchg  dl,dh
    add   ecx,[RAMBaseDiff]
    mov   [ecx],dx
    ret
  };
}

void REGNAKED REGPARAM2 ram_bput(uaecptr addr, uae_u32 b)
{
  _asm { 
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
		and   ecx, 07FFFFFFFh
#endif
    add   ecx,[RAMBaseDiff]
    mov   [ecx],dl
    ret
  };
}

uae_u8 REGNAKED *REGPARAM2 ram_xlate(uaecptr addr)
{
  _asm { 
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
		and   ecx, 07FFFFFFFh
#endif
    add   ecx,[RAMBaseDiff]
    mov   eax,ecx
    ret
  };
}

int REGPARAM2 ram_check(uaecptr addr, uae_u32 size)
{
    return (addr - RAMBaseMac + size) < RAMSize;
}


/* Mac RAM (24 bit addressing) */

static uae_u32 REGPARAM2 ram24_lget(uaecptr) REGPARAM;
static uae_u32 REGPARAM2 ram24_wget(uaecptr) REGPARAM;
static uae_u32 REGPARAM2 ram24_bget(uaecptr) REGPARAM;
static void REGPARAM2 ram24_lput(uaecptr, uae_u32) REGPARAM;
static void REGPARAM2 ram24_wput(uaecptr, uae_u32) REGPARAM;
static void REGPARAM2 ram24_bput(uaecptr, uae_u32) REGPARAM;
static int REGPARAM2 ram24_check(uaecptr addr, uae_u32 size) REGPARAM;
static uae_u8 *REGPARAM2 ram24_xlate(uaecptr addr) REGPARAM;

uae_u32 REGPARAM2 ram24_lget(uaecptr addr)
{
    uae_u32 *m;
    m = (uae_u32 *)(RAMBaseDiff + (addr & 0xffffff));
    return do_get_mem_long(m);
}

uae_u32 REGPARAM2 ram24_wget(uaecptr addr)
{
    uae_u16 *m;
    m = (uae_u16 *)(RAMBaseDiff + (addr & 0xffffff));
    return do_get_mem_word(m);
}

uae_u32 REGPARAM2 ram24_bget(uaecptr addr)
{
    return (uae_u32)*(uae_u8 *)(RAMBaseDiff + (addr & 0xffffff));
}

void REGPARAM2 ram24_lput(uaecptr addr, uae_u32 l)
{
    uae_u32 *m;
    m = (uae_u32 *)(RAMBaseDiff + (addr & 0xffffff));
    do_put_mem_long(m, l);
}

void REGPARAM2 ram24_wput(uaecptr addr, uae_u32 w)
{
    uae_u16 *m;
    m = (uae_u16 *)(RAMBaseDiff + (addr & 0xffffff));
    do_put_mem_word(m, w);
}

void REGPARAM2 ram24_bput(uaecptr addr, uae_u32 b)
{
	*(uae_u8 *)(RAMBaseDiff + (addr & 0xffffff)) = b;
}

int REGPARAM2 ram24_check(uaecptr addr, uae_u32 size)
{
    return ((addr & 0xffffff) - RAMBaseMac + size) < RAMSize;
}

uae_u8 *REGPARAM2 ram24_xlate(uaecptr addr)
{
    return (uae_u8 *)(RAMBaseDiff + (addr & 0xffffff));
}

/* Mac ROM (32 bit addressing) */

static uae_u32 REGPARAM2 rom_lget(uaecptr) REGPARAM;
static uae_u32 REGPARAM2 rom_wget(uaecptr) REGPARAM;
static uae_u32 REGPARAM2 rom_bget(uaecptr) REGPARAM;
static void  REGPARAM2 rom_lput(uaecptr, uae_u32) REGPARAM;
static void  REGPARAM2 rom_wput(uaecptr, uae_u32) REGPARAM;
static void  REGPARAM2 rom_bput(uaecptr, uae_u32) REGPARAM;
static int  REGPARAM2 rom_check(uaecptr addr, uae_u32 size) REGPARAM;
static uae_u8 *REGPARAM2 rom_xlate(uaecptr addr) REGPARAM;

static uae_u32 ROMBaseDiff;	// ROMBaseHost - ROMBaseMac

uae_u32 REGNAKED REGPARAM2 rom_lget(uaecptr addr)
{
	DBREAK;
  _asm { 
    add   ecx,[ROMBaseDiff]
    mov   eax,[ecx]
    bswap eax
    ret
  };
}

uae_u32 REGNAKED REGPARAM2 rom_wget(uaecptr addr)
{
	DBREAK;
  _asm { 
    xor   eax,eax
    add   ecx,[ROMBaseDiff]
    mov   ax,[ecx]
    xchg  al,ah
    ret
  };
}

uae_u32 REGNAKED REGPARAM2 rom_bget(uaecptr addr)
{
	DBREAK;
  _asm { 
    xor   eax,eax
    add   ecx,[ROMBaseDiff]
    ; partial register stall -- eax,swap?
    mov   al,[ecx]
    ret
  };
}

void REGPARAM2 rom_lput(uaecptr addr, uae_u32 b)
{
	DBREAK;
  if (illegal_mem)
		write_log ("Illegal ROM lput at %08lx\n", addr);
}

void REGPARAM2 rom_wput(uaecptr addr, uae_u32 b)
{
	DBREAK;
  if (illegal_mem)
		write_log ("Illegal ROM wput at %08lx\n", addr);
}

void REGPARAM2 rom_bput(uaecptr addr, uae_u32 b)
{
	DBREAK;
  if (illegal_mem)
		write_log ("Illegal ROM bput at %08lx\n", addr);
}

int REGPARAM2 rom_check(uaecptr addr, uae_u32 size)
{
	DBREAK;
  return (addr - ROMBaseMac + size) < ROMSize;
}

uae_u8 REGNAKED *REGPARAM2 rom_xlate(uaecptr addr)
{
	DBREAK;
  _asm { 
    add   ecx,[ROMBaseDiff]
    mov   eax,ecx
    ret
  };
}

/* Mac ROM (24 bit addressing) */

static uae_u32 REGPARAM2 rom24_lget(uaecptr) REGPARAM;
static uae_u32 REGPARAM2 rom24_wget(uaecptr) REGPARAM;
static uae_u32 REGPARAM2 rom24_bget(uaecptr) REGPARAM;
static int REGPARAM2 rom24_check(uaecptr addr, uae_u32 size) REGPARAM;
static uae_u8 *REGPARAM2 rom24_xlate(uaecptr addr) REGPARAM;

uae_u32 REGPARAM2 rom24_lget(uaecptr addr)
{
    uae_u32 *m;
    m = (uae_u32 *)(ROMBaseDiff + (addr & 0xffffff));
    return do_get_mem_long(m);
}

uae_u32 REGPARAM2 rom24_wget(uaecptr addr)
{
    uae_u16 *m;
    m = (uae_u16 *)(ROMBaseDiff + (addr & 0xffffff));
    return do_get_mem_word(m);
}

uae_u32 REGPARAM2 rom24_bget(uaecptr addr)
{
    return (uae_u32)*(uae_u8 *)(ROMBaseDiff + (addr & 0xffffff));
}

int REGPARAM2 rom24_check(uaecptr addr, uae_u32 size)
{
    return ((addr & 0xffffff) - ROMBaseMac + size) < ROMSize;
}

uae_u8 *REGPARAM2 rom24_xlate(uaecptr addr)
{
    return (uae_u8 *)(ROMBaseDiff + (addr & 0xffffff));
}

/* Frame buffer */

static uae_u32 REGPARAM2 frame_direct_lget(uaecptr) REGPARAM;
static uae_u32 REGPARAM2 frame_direct_wget(uaecptr) REGPARAM;
static uae_u32 REGPARAM2 frame_direct_bget(uaecptr) REGPARAM;
static void  REGPARAM2 frame_direct_lput(uaecptr, uae_u32) REGPARAM;
static void  REGPARAM2 frame_direct_wput(uaecptr, uae_u32) REGPARAM;
static void  REGPARAM2 frame_direct_bput(uaecptr, uae_u32) REGPARAM;

static uae_u32 REGPARAM2 frame_host_555_lget(uaecptr) REGPARAM;
static uae_u32 REGPARAM2 frame_host_555_wget(uaecptr) REGPARAM;
static void  REGPARAM2 frame_host_555_lput(uaecptr, uae_u32) REGPARAM;
static void  REGPARAM2 frame_host_555_wput(uaecptr, uae_u32) REGPARAM;

static uae_u32 REGPARAM2 frame_host_565_lget(uaecptr) REGPARAM;
static uae_u32 REGPARAM2 frame_host_565_wget(uaecptr) REGPARAM;
static void  REGPARAM2 frame_host_565_lput(uaecptr, uae_u32) REGPARAM;
static void  REGPARAM2 frame_host_565_wput(uaecptr, uae_u32) REGPARAM;

static uae_u32 REGPARAM2 frame_host_888_lget(uaecptr) REGPARAM;
static void  REGPARAM2 frame_host_888_lput(uaecptr, uae_u32) REGPARAM;

static int   REGPARAM2 frame_check(uaecptr addr, uae_u32 size) REGPARAM;
static uae_u8 *REGPARAM2 frame_xlate(uaecptr addr) REGPARAM;

static uae_u32 FrameBaseDiff;	// MacFrameBaseHost - MacFrameBaseMac

uae_u32 REGNAKED REGPARAM2 frame_direct_lget(uaecptr addr)
{
	DBREAK;
  _asm { 
    add   ecx,[FrameBaseDiff]
    mov   eax,[ecx]
    bswap eax
    ret
  };
}

uae_u32 REGNAKED REGPARAM2 frame_direct_wget(uaecptr addr)
{
	DBREAK;
  _asm { 
    xor   eax,eax
    add   ecx,[FrameBaseDiff]
    mov   ax,[ecx]
    xchg  al,ah
    ret
  };
}

uae_u32 REGNAKED REGPARAM2 frame_direct_bget(uaecptr addr)
{
	DBREAK;
  _asm { 
    xor   eax,eax
    add   ecx,[FrameBaseDiff]
    mov   al,[ecx]
    ret
  };
}

void REGNAKED REGPARAM2 frame_direct_lput(uaecptr addr, uae_u32 l)
{
	DBREAK;
  _asm { 
    add   ecx,[FrameBaseDiff]
    bswap edx
    mov   [ecx],edx
    ret
  };
}

void REGNAKED REGPARAM2 frame_direct_wput(uaecptr addr, uae_u32 l)
{
	DBREAK;
  _asm { 
    add   ecx,[FrameBaseDiff]
    xchg  dl,dh
    mov   [ecx],dx
    ret
  };
}

void REGPARAM2 frame_direct_bput(uaecptr addr, uae_u32 b)
{
	DBREAK;
    *(uae_u8 *)(FrameBaseDiff + addr) = b;
}

uae_u32 REGPARAM2 frame_host_555_lget(uaecptr addr)
{
	DBREAK;
    uae_u32 *m, l;
    m = (uae_u32 *)(FrameBaseDiff + addr);
    l = *m;
    return (l >> 16) | (l << 16);
}

uae_u32 REGPARAM2 frame_host_555_wget(uaecptr addr)
{
	DBREAK;
    uae_u16 *m;
    m = (uae_u16 *)(FrameBaseDiff + addr);
    return *m;
}

void REGPARAM2 frame_host_555_lput(uaecptr addr, uae_u32 l)
{
	DBREAK;
    uae_u32 *m;
    m = (uae_u32 *)(FrameBaseDiff + addr);
    *m = (l >> 16) | (l << 16);
}

void REGPARAM2 frame_host_555_wput(uaecptr addr, uae_u32 w)
{
	DBREAK;
    uae_u16 *m;
    m = (uae_u16 *)(FrameBaseDiff + addr);
    *m = w;
}

uae_u32 REGPARAM2 frame_host_565_lget(uaecptr addr)
{
	DBREAK;
    uae_u32 *m, l;
    m = (uae_u32 *)(FrameBaseDiff + addr);
    l = *m;
    l = (l & 0x001f001f) | ((l >> 1) & 0x7fe07fe0);
    return (l >> 16) | (l << 16);
}

uae_u32 REGPARAM2 frame_host_565_wget(uaecptr addr)
{
	DBREAK;
    uae_u16 *m, w;
    m = (uae_u16 *)(FrameBaseDiff + addr);
    w = *m;
    return (w & 0x1f) | ((w >> 1) & 0x7fe0);
}

void REGPARAM2 frame_host_565_lput(uaecptr addr, uae_u32 l)
{
	DBREAK;
    uae_u32 *m;
    m = (uae_u32 *)(FrameBaseDiff + addr);
    l = (l & 0x001f001f) | ((l << 1) & 0xffc0ffc0);
    *m = (l >> 16) | (l << 16);
}

void REGPARAM2 frame_host_565_wput(uaecptr addr, uae_u32 w)
{
	DBREAK;
    uae_u16 *m;
    m = (uae_u16 *)(FrameBaseDiff + addr);
    *m = (w & 0x1f) | ((w << 1) & 0xffc0);
}

uae_u32 REGPARAM2 frame_host_888_lget(uaecptr addr)
{
	DBREAK;
    uae_u32 *m;
    m = (uae_u32 *)(FrameBaseDiff + addr);
    return *m;
}

void REGPARAM2 frame_host_888_lput(uaecptr addr, uae_u32 l)
{
	DBREAK;
    uae_u32 *m;
    m = (uae_u32 *)(FrameBaseDiff + addr);
    *m = l;
}

int REGPARAM2 frame_check(uaecptr addr, uae_u32 size)
{
	DBREAK;
    return (addr - MacFrameBaseMac + size) < MacFrameSize;
}

uae_u8 REGNAKED *REGPARAM2 frame_xlate(uaecptr addr)
{
	DBREAK;
  _asm { 
    add   ecx,[FrameBaseDiff]
    mov   eax,ecx
		;mov   eax,[FrameBaseDiff+ecx]
    ret
  };
}

/* Default memory access functions */

int REGPARAM2 default_check (uaecptr a, uae_u32 b) REGPARAM
{
	DBREAK;
    return 0;
}

uae_u8 *REGPARAM2 default_xlate (uaecptr a) REGPARAM
{
	DBREAK;
    write_log ("Your Mac program just did something terribly stupid\n");
    return NULL;
}

/* Address banks */

addrbank dummy_bank = {
    dummy_lget, dummy_wget, dummy_bget,
    dummy_lput, dummy_wput, dummy_bput,
    default_xlate, dummy_check
};

addrbank ram_bank = {
    ram_lget, ram_wget, ram_bget,
    ram_lput, ram_wput, ram_bput,
    ram_xlate, ram_check
};

addrbank ram24_bank = {
    ram24_lget, ram24_wget, ram24_bget,
    ram24_lput, ram24_wput, ram24_bput,
    ram24_xlate, ram24_check
};

addrbank rom_bank = {
    rom_lget, rom_wget, rom_bget,
    rom_lput, rom_wput, rom_bput,
    rom_xlate, rom_check
};

addrbank rom24_bank = {
    rom24_lget, rom24_wget, rom24_bget,
    rom_lput, rom_wput, rom_bput,
    rom24_xlate, rom24_check
};

addrbank frame_direct_bank = {
    frame_direct_lget, frame_direct_wget, frame_direct_bget,
    frame_direct_lput, frame_direct_wput, frame_direct_bput,
    frame_xlate, frame_check
};

addrbank frame_host_555_bank = {
    frame_host_555_lget, frame_host_555_wget, frame_direct_bget,
    frame_host_555_lput, frame_host_555_wput, frame_direct_bput,
    frame_xlate, frame_check
};

addrbank frame_host_565_bank = {
    frame_host_565_lget, frame_host_565_wget, frame_direct_bget,
    frame_host_565_lput, frame_host_565_wput, frame_direct_bput,
    frame_xlate, frame_check
};

addrbank frame_host_888_bank = {
    frame_host_888_lget, frame_direct_wget, frame_direct_bget,
    frame_host_888_lput, frame_direct_wput, frame_direct_bput,
    frame_xlate, frame_check
};

void memory_init(void)
{
  int i;
	for(i=0; i<(65536>>(BANK_SHIFT-16)); i++)
    put_mem_bank(i<<BANK_SHIFT, &dummy_bank);

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
	// not reached
	RAMBaseDiff = MEMBaseDiff;
	ROMBaseDiff = MEMBaseDiff;
	FrameBaseDiff = MEMBaseDiff;
#else
  RAMBaseDiff = (uae_u32)RAMBaseHost - (uae_u32)RAMBaseMac;
  ROMBaseDiff = (uae_u32)ROMBaseHost - (uae_u32)ROMBaseMac;
  FrameBaseDiff = (uae_u32)MacFrameBaseHost - (uae_u32)MacFrameBaseMac;
#endif

  // Limit RAM size to not overlap ROM
#if REAL_ADDRESSING
  uint32 ram_size = RAMSize;
#else
  uint32 ram_size = RAMSize > ROMBaseMac ? ROMBaseMac : RAMSize;
#endif

	// Fix to work around a proble with rom_sz going to zero for 512k ROMs
	int rom_sz = ROMSize >> BANK_SHIFT;
	if(rom_sz < 1) rom_sz = 1;

  // RAM and ROM
  if (TwentyFourBitAddressing) {
    map_banks(&ram24_bank, RAMBaseMac >> BANK_SHIFT, ram_size >> BANK_SHIFT);
    map_banks(&rom24_bank, ROMBaseMac >> BANK_SHIFT, rom_sz);
  } else {
    map_banks(&ram_bank, RAMBaseMac >> BANK_SHIFT, ram_size >> BANK_SHIFT);
    map_banks(&rom_bank, ROMBaseMac >> BANK_SHIFT, rom_sz);
  }

  // Frame buffer
  switch (MacFrameLayout) {
    case FLAYOUT_DIRECT:
      map_banks(&frame_direct_bank, MacFrameBaseMac >> BANK_SHIFT, (MacFrameSize >> BANK_SHIFT) + 1);
      break;
    case FLAYOUT_HOST_555:
      map_banks(&frame_host_555_bank, MacFrameBaseMac >> BANK_SHIFT, (MacFrameSize >> BANK_SHIFT) + 1);
      break;
    case FLAYOUT_HOST_565:
      map_banks(&frame_host_565_bank, MacFrameBaseMac >> BANK_SHIFT, (MacFrameSize >> BANK_SHIFT) + 1);
      break;
    case FLAYOUT_HOST_888:
      map_banks(&frame_host_888_bank, MacFrameBaseMac >> BANK_SHIFT, (MacFrameSize >> BANK_SHIFT) + 1);
      break;
  }
}

/*
void map_banks(addrbank *bank, int start, int size)
{
	int bnr;
	unsigned long int hioffs = 0, endhioffs = 0x100;

	if (start >= 0x100) {
		for (bnr = start; bnr < start + size; bnr++)
			put_mem_bank (bnr << 16, bank);
		return;
	}
  if (TwentyFourBitAddressing) endhioffs = 0x10000;
	for (hioffs = 0; hioffs < endhioffs; hioffs += 0x100)
		for (bnr = start; bnr < start+size; bnr++)
			put_mem_bank((bnr + hioffs) << 16, bank);
}
*/

void map_banks(addrbank *bank, int start, int size)
{
	int bnr;
	unsigned long int hioffs = 0, endhioffs = 0x100>>(BANK_SHIFT-16);

	if (start >= (0x100>>(BANK_SHIFT-16))) {
	for (bnr = start; bnr < start + size; bnr++)
		put_mem_bank (bnr << BANK_SHIFT, bank);
		return;
	}
	if (TwentyFourBitAddressing) endhioffs = 0x10000>>2*(BANK_SHIFT-16); // ?
	for (hioffs = 0; hioffs < endhioffs; hioffs += (0x100>>(BANK_SHIFT-16)))
	for (bnr = start; bnr < start+size; bnr++)
		put_mem_bank((bnr + hioffs) << BANK_SHIFT, bank);
}
