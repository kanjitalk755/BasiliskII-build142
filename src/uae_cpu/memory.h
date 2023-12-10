 /*
  * UAE - The Un*x Amiga Emulator
  *
  * memory management
  *
  * Copyright 1995 Bernd Schmidt
  */

#ifndef UAE_MEMORY_H
#define UAE_MEMORY_H

/* Enabling this adds one additional native memory reference per 68k memory
 * access, but saves one shift (on the x86). Enabling this is probably
 * better for the cache. My favourite benchmark (PP2) doesn't show a
 * difference, so I leave this enabled. */

// #if 1 || defined SAVE_MEMORY
// #define SAVE_MEMORY_BANKS
// #endif

typedef uae_u32 (REGPARAM2 *mem_get_func)(uaecptr) REGPARAM;
typedef void (REGPARAM2 *mem_put_func)(uaecptr, uae_u32) REGPARAM;
typedef uae_u8 *(REGPARAM2 *xlate_func)(uaecptr) REGPARAM;
typedef int (REGPARAM2 *check_func)(uaecptr, uae_u32) REGPARAM;

#undef DIRECT_MEMFUNCS_SUCCESSFUL

#ifndef CAN_MAP_MEMORY
#undef USE_COMPILER
#endif

#if defined(USE_COMPILER) && !defined(USE_MAPPED_MEMORY)
#define USE_MAPPED_MEMORY
#endif

typedef struct {
    /* These ones should be self-explanatory... */
    mem_get_func lget, wget, bget;
    mem_put_func lput, wput, bput;
    /* Use xlateaddr to translate an Amiga address to a uae_u8 * that can
     * be used to address memory without calling the wget/wput functions.
     * This doesn't work for all memory banks, so this function may call
     * abort(). */
    xlate_func xlateaddr;
    /* To prevent calls to abort(), use check before calling xlateaddr.
     * It checks not only that the memory bank can do xlateaddr, but also
     * that the pointer points to an area of at least the specified size.
     * This is used for example to translate bitplane pointers in custom.c */
    check_func check;
} addrbank;

extern uae_u8 filesysory[65536];

extern addrbank ram_bank;	// Mac RAM
extern addrbank rom_bank;	// Mac ROM
extern addrbank frame_bank;	// Frame buffer

#define BANK_SHIFT 20

/* Default memory access functions */

extern int REGPARAM2 default_check(uaecptr addr, uae_u32 size) REGPARAM;
extern uae_u8 *REGPARAM2 default_xlate(uaecptr addr) REGPARAM;

#define bankindex(addr)			(((uaecptr)(addr)) >> BANK_SHIFT)
extern addrbank					mem_banks[65536>>(BANK_SHIFT-16)];
#define get_mem_bank(addr)		(mem_banks[bankindex(addr)])
#define put_mem_bank(addr, b)	(mem_banks[bankindex(addr)] = *(b))


extern void memory_init(void);
extern void map_banks(addrbank *bank, int first, int count);

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS

extern "C" uae_u32 MEMBaseDiff;
extern uint32 RAMSize;

/*
static inline uae_u32 Do_get_mem_long(uaecptr a) {
	uae_u32 *p = (uae_u32 *)( MEMBaseDiff + (DWORD)a );
	return *p;
}
static inline uae_u32 Do_get_mem_word(uaecptr a) {
	uae_u16 *p = (uae_u16 *)( MEMBaseDiff + (DWORD)a );
	return *p;
}
static inline uae_u32 Do_get_mem_byte(uaecptr a) {
	uae_u8 *p = (uae_u8 *)( MEMBaseDiff + (DWORD)a );
	return (*p);
}
static inline void Do_put_mem_long(uaecptr a, uae_u32 v) {
	uae_u32 *p = (uae_u32 *)( MEMBaseDiff + (DWORD)a );
	*p = v;
}
static inline void Do_put_mem_word(uaecptr a, uae_u32 v) {
	uae_u16 *p = (uae_u16 *)( MEMBaseDiff + (DWORD)a );
	*p = (uae_u16)v;
}
static inline void Do_put_mem_byte(uaecptr a, uae_u32 v) {
	uae_u8 *p = (uae_u8 *)( MEMBaseDiff + (DWORD)a );
	*p = (uae_u8)v;
}
*/

/*
static inline uae_u32 Do_get_mem_long(uaecptr a) {
	uae_u32 *p = (uae_u32 *)( MEMBaseDiff + (DWORD)a );
	uae_u32 x = *p;
	return (x >> 24) | (x >> 8) & 0xff00 | (x << 8) & 0xff0000 | (x << 24);
}

// NOTE uae_u16!!! Compiler bug.
static inline uae_u16 Do_get_mem_word(uaecptr a) {
	uae_u16 *p = (uae_u16 *)( MEMBaseDiff + (DWORD)a );
	uae_u16 x = *p;
	return (x >> 8) | (x << 8);
}
static inline uae_u32 Do_get_mem_byte(uaecptr a) {
	uae_u8 *p = (uae_u8 *)( MEMBaseDiff + (DWORD)a );
	return (*p);
}
static inline void Do_put_mem_long(uaecptr a, uae_u32 v) {
	uae_u32 *p = (uae_u32 *)( MEMBaseDiff + (DWORD)a );
	*p = (v >> 24) | (v >> 8) & 0xff00 | (v << 8) & 0xff0000 | (v << 24);
}
static inline void Do_put_mem_word(uaecptr a, uae_u32 v) {
	uae_u16 *p = (uae_u16 *)( MEMBaseDiff + (DWORD)a );
	*p = ((uae_u16)v >> 8) | ((uae_u16)v << 8);
}
static inline void Do_put_mem_byte(uaecptr a, uae_u32 v) {
	uae_u8 *p = (uae_u8 *)( MEMBaseDiff + (DWORD)a );
	*p = (uae_u8)v;
}
*/

/*
static inline uae_u32 REGPARAM2 Do_get_mem_long(uaecptr addr)
{
  _asm { 
		and   ecx, 07FFFFFFFh
    add   ecx,[MEMBaseDiff]
    mov   eax,[ecx]
    bswap eax
  };
}

static inline uae_u32 REGPARAM2 Do_get_mem_word(uaecptr addr)
{
  _asm { 
		and   ecx, 07FFFFFFFh
    xor   eax,eax
    add   ecx,[MEMBaseDiff]
    mov   ax,[ecx]
    xchg  al,ah
  };
}

static inline uae_u32 REGPARAM2 Do_get_mem_byte(uaecptr addr)
{
  _asm { 
		and   ecx, 07FFFFFFFh
    xor   eax,eax
    add   ecx,[MEMBaseDiff]
    mov   al,[ecx]
  };
}

static inline void REGPARAM2 Do_put_mem_long(uaecptr addr, uae_u32 l)
{
  _asm { 
		and   ecx, 07FFFFFFFh
    bswap edx
    add   ecx,[MEMBaseDiff]
    mov   [ecx],edx
  };
}

static inline void REGPARAM2 Do_put_mem_word(uaecptr addr, uae_u32 w)
{
  _asm { 
		and   ecx, 07FFFFFFFh
    xchg  dl,dh
    add   ecx,[MEMBaseDiff]
    mov   [ecx],dx
  };
}

static inline void REGPARAM2 Do_put_mem_byte(uaecptr addr, uae_u32 b)
{
  _asm { 
		and   ecx, 07FFFFFFFh
    add   ecx,[MEMBaseDiff]
    mov   [ecx],dl
  };
}

#define longget(addr) (Do_get_mem_long(addr))
#define wordget(addr) ((uae_u16)Do_get_mem_word(addr))
#define byteget(addr) ((uae_u8)Do_get_mem_byte(addr))
#define longput(addr,l) (Do_put_mem_long(addr, l))
#define wordput(addr,w) (Do_put_mem_word(addr, w))
#define byteput(addr,b) (Do_put_mem_byte(addr, b))
*/



uae_u32 REGPARAM2 ram_lget(uaecptr) REGPARAM;
uae_u32 REGPARAM2 ram_wget(uaecptr) REGPARAM;
uae_u32 REGPARAM2 ram_bget(uaecptr) REGPARAM;
void  REGPARAM2 ram_lput(uaecptr, uae_u32) REGPARAM;
void  REGPARAM2 ram_wput(uaecptr, uae_u32) REGPARAM;
void  REGPARAM2 ram_bput(uaecptr, uae_u32) REGPARAM;
int   REGPARAM2 ram_check(uaecptr addr, uae_u32 size) REGPARAM;
uae_u8 *REGPARAM2 ram_xlate(uaecptr addr) REGPARAM;

// #define longget(addr) (ram_lget(addr))
// #define wordget(addr) (ram_wget(addr))
// #define byteget(addr) (ram_bget(addr))

// #define longput(addr,l) (ram_lput(addr, l))
// #define wordput(addr,w) (ram_wput(addr, w))
// #define byteput(addr,b) (ram_bput(addr, b))


#else

#ifndef NO_INLINE_MEMORY_ACCESS

#define longget(addr) (call_mem_get_func(get_mem_bank(addr).lget, addr))
#define wordget(addr) (call_mem_get_func(get_mem_bank(addr).wget, addr))
#define byteget(addr) (call_mem_get_func(get_mem_bank(addr).bget, addr))
#define longput(addr,l) (call_mem_put_func(get_mem_bank(addr).lput, addr, l))
#define wordput(addr,w) (call_mem_put_func(get_mem_bank(addr).wput, addr, w))
#define byteput(addr,b) (call_mem_put_func(get_mem_bank(addr).bput, addr, b))

#else

extern uae_u32 alongget(uaecptr addr);
extern uae_u32 awordget(uaecptr addr);
extern uae_u32 longget(uaecptr addr);
extern uae_u32 wordget(uaecptr addr);
extern uae_u32 byteget(uaecptr addr);
extern void longput(uaecptr addr, uae_u32 l);
extern void wordput(uaecptr addr, uae_u32 w);
extern void byteput(uaecptr addr, uae_u32 b);

#endif
#endif //!OPTIMIZED_8BIT_MEMORY_ACCESS

#ifndef MD_HAVE_MEM_1_FUNCS

#define longget_1 longget
#define wordget_1 wordget
#define byteget_1 byteget
#define longput_1 longput
#define wordput_1 wordput
#define byteput_1 byteput

#endif

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
static __inline__ uae_u32 get_long(uaecptr a)
{
#ifdef SWAPPED_ADDRESS_SPACE
	a = MEMBaseLongTop - a;
	uae_u32 *p = (uae_u32 *)( MEMBaseDiff + (DWORD)a );
	uae_u32 x = *p;
	return x;
#else
	uae_u32 *p = (uae_u32 *)( MEMBaseDiff + (DWORD)a );
	uae_u32 x = *p;
	return (x >> 24) | (x >> 8) & 0xff00 | (x << 8) & 0xff0000 | (x << 24);
#endif
}
static __inline__ uae_u16 get_word(uaecptr a)
{
#ifdef SWAPPED_ADDRESS_SPACE
	a = MEMBaseWordTop - a;
	uae_u16 *p = (uae_u16 *)( MEMBaseDiff + (DWORD)a );
	uae_u16 x = *p;
	return x;
#else
	uae_u16 *p = (uae_u16 *)( MEMBaseDiff + (DWORD)a );
	uae_u16 x = *p;
	return (x >> 8) | (x << 8);
#endif
}
static __inline__ uae_u8 get_byte(uaecptr a)
{
#ifdef SWAPPED_ADDRESS_SPACE
	a = MEMBaseByteTop - a;
#endif
	uae_u8 *p = (uae_u8 *)( MEMBaseDiff + (DWORD)a );
	return (*p);
}
static __inline__ void put_long(uaecptr a, uae_u32 v)
{
#ifdef SWAPPED_ADDRESS_SPACE
	a = MEMBaseLongTop - a;
	uae_u32 *p = (uae_u32 *)( MEMBaseDiff + (DWORD)a );
	*p = v;
#else
	uae_u32 *p = (uae_u32 *)( MEMBaseDiff + (DWORD)a );
	*p = (v >> 24) | (v >> 8) & 0xff00 | (v << 8) & 0xff0000 | (v << 24);
#endif
}
static __inline__ void put_word(uaecptr a, uae_u16 v)
{
#ifdef SWAPPED_ADDRESS_SPACE
	a = MEMBaseWordTop - a;
	uae_u16 *p = (uae_u16 *)( MEMBaseDiff + (DWORD)a );
	*p = v;
#else
	uae_u16 *p = (uae_u16 *)( MEMBaseDiff + (DWORD)a );
	*p = ((uae_u16)v >> 8) | ((uae_u16)v << 8);
#endif
}
static __inline__ void put_byte(uaecptr a, uae_u8 v)
{
#ifdef SWAPPED_ADDRESS_SPACE
	a = MEMBaseByteTop - a;
#endif
	uae_u8 *p = (uae_u8 *)( MEMBaseDiff + (DWORD)a );
	*p = (uae_u8)v;
}

static __inline__ uae_u8 *get_real_address(uaecptr a)
{
#ifdef SWAPPED_ADDRESS_SPACE
	a = MEMBaseByteTop - a;
#endif
	return (uae_u8 *) (MEMBaseDiff + (DWORD)a);
}

static __inline__ int valid_address(uaecptr a, uae_u32 size)
{
	return 1;
}

#elif REAL_ADDRESSING
static __inline__ uae_u32 get_long(uaecptr addr)
{
    return ntohl(*(uae_u32 *)addr);
}
static __inline__ uae_u32 get_word(uaecptr addr)
{
    return ntohs(*(uae_u16 *)addr);
}
static __inline__ uae_u32 get_byte(uaecptr addr)
{
    return *(uae_u8 *)addr;
}
static __inline__ void put_long(uaecptr addr, uae_u32 l)
{
    *(uae_u32 *)addr = htonl(l);
}
static __inline__ void put_word(uaecptr addr, uae_u32 w)
{
    *(uae_u16 *)addr = htons(w);
}
static __inline__ void put_byte(uaecptr addr, uae_u32 b)
{
    *(uae_u8 *)addr = b;
}
static __inline__ uae_u8 *get_real_address(uaecptr addr)
{
    return (uae_u8 *)addr;
}
static __inline__ int valid_address(uaecptr addr, uae_u32 size)
{
    return 1;
}
#else
static __inline__ uae_u32 get_long(uaecptr addr)
{
    return longget_1(addr);
}
static __inline__ uae_u32 get_word(uaecptr addr)
{
    return wordget_1(addr);
}
static __inline__ uae_u32 get_byte(uaecptr addr)
{
    return byteget_1(addr);
}
static __inline__ void put_long(uaecptr addr, uae_u32 l)
{
    longput_1(addr, l);
}
static __inline__ void put_word(uaecptr addr, uae_u32 w)
{
    wordput_1(addr, w);
}
static __inline__ void put_byte(uaecptr addr, uae_u32 b)
{
    byteput_1(addr, b);
}

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS

#define get_real_address(addr) (ram_xlate(addr))
#define valid_address(addr,b) (ram_check(addr, b))

/*
static __inline__ uae_u8 *get_real_address(uaecptr addr)
{
	uae_u8 *p = (uae_u8 *)( MEMBaseDiff + (DWORD)addr ); 
	return p;
}

static __inline__ int valid_address(uaecptr addr, uae_u32 size)
{
	return (addr - MEMBaseDiff + size) < RAMSize;
	// return 1;
}
*/

/*
static inline uae_u8 *REGPARAM2 get_real_address(uaecptr addr)
{
  _asm { 
    add   ecx,[MEMBaseDiff]
    mov   eax,ecx
  };
}

static inline int REGPARAM2 valid_address(uaecptr addr, uae_u32 size)
{
  _asm { 
    mov   eax,1
  };
}
*/

#else
static __inline__ uae_u8 *get_real_address(uaecptr addr)
{
    return get_mem_bank(addr).xlateaddr(addr);
}

static __inline__ int valid_address(uaecptr addr, uae_u32 size)
{
    return get_mem_bank(addr).check(addr, size);
}
#endif //!OPTIMIZED_8BIT_MEMORY_ACCESS

#endif

#endif
