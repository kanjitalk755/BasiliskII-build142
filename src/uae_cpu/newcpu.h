 /*
  * UAE - The Un*x Amiga Emulator
  *
  * MC68000 emulation
  *
  * Copyright 1995 Bernd Schmidt
  */

extern "C" {

#ifndef NEWCPU_H
#define NEWCPU_H

#define SPCFLAG_STOP 2
#define SPCFLAG_DISK 4
#define SPCFLAG_INT  8
#define SPCFLAG_BRK  16
#define SPCFLAG_EXTRA_CYCLES 32
#define SPCFLAG_TRACE 64
#define SPCFLAG_DOTRACE 128
#define SPCFLAG_DOINT 256
#define SPCFLAG_BLTNASTY 512
#define SPCFLAG_EXEC 1024
#define SPCFLAG_MODE_CHANGE 8192

/*
#ifndef SET_CFLG

#define SET_CFLG(x) (CFLG = (x))
#define SET_NFLG(x) (NFLG = (x))
#define SET_VFLG(x) (VFLG = (x))
#define SET_ZFLG(x) (ZFLG = (x))
#define SET_XFLG(x) (XFLG = (x))

#define GET_CFLG CFLG
#define GET_NFLG NFLG
#define GET_VFLG VFLG
#define GET_ZFLG ZFLG
#define GET_XFLG XFLG

#define CLEAR_CZNV do { \
 SET_CFLG (0); \
 SET_ZFLG (0); \
 SET_NFLG (0); \
 SET_VFLG (0); \
} while (0)

#define COPY_CARRY (SET_XFLG (GET_CFLG))
#endif
*/

extern int areg_byteinc[];
extern int imm8_table[];

extern int movem_index1[256];
extern int movem_index2[256];
extern int movem_next[256];

// extern int fpp_movem_index1[256];
// extern int fpp_movem_index2[256];
// extern int fpp_movem_next[256];

extern int broken_in;

#if HAVE_VOID_CPU_FUNCS
typedef void REGPARAM2 cpuop_func (uae_u32) REGPARAM;
#else
typedef unsigned long REGPARAM2 cpuop_func (uae_u32) REGPARAM;
#endif

struct cputbl {
    cpuop_func *handler;
    int specific;
    uae_u16 opcode;
};

extern void REGPARAM2 op_illg (uae_u32) REGPARAM;

static __inline__ unsigned int cft_map (unsigned int f)
{
#ifndef HAVE_GET_WORD_UNSWAPPED
  return f;
#else
  return ((f >> 8) & 255) | ((f & 255) << 8);
#endif
}

typedef char flagtype;

extern struct regstruct
{
    uae_u32 regs[16];
    uaecptr  usp,isp,msp;
    uae_u16 sr;
    flagtype t1;
    flagtype t0;
    flagtype s;
    flagtype m;
    flagtype x;
    flagtype stopped;
    int intmask;

    uae_u32 pc;
    uae_u8 *pc_p;
    uae_u8 *pc_oldp;

    uae_u32 vbr,sfc,dfc;

    long double fp[8];

    uae_u32 fpcr,fpsr,fpiar;

    uae_u32 spcflags;
    // uae_u32 kick_mask;

    /* Fellow sources say this is 4 longwords. That's impossible. It needs
     * to be at least a longword. The HRM has some cryptic comment about two
     * instructions being on the same longword boundary.
     * The way this is implemented now seems like a good compromise.
     */
#if !DISABLE_PREFETCH
    uae_u32 prefetch;
#endif

		// 003 MMU Translation Control Register (TC)
    uae_u32 tc;
		// 004 Instruction Transparent Translation Register 0 (ITT0)
    uae_u32 itt0;
		// 005 Instruction Transparent Translation Register 1 (ITT1)
    uae_u32 itt1;
		// 006 Data Transparent Translation Register 0 (DTT0)
    uae_u32 dtt0;
		// 007 Data Transparent Translation Register 1 (DTT1)
    uae_u32 dtt1;
		// 805 MMU Status Register (MMUSR)
    uae_u32 mmusr;
		// 806 User Root Pointer (URP)
    uae_u32 urp;
		// 807 Supervisor Root Pointer (SRP)
    uae_u32 srp;
} regs, lastint_regs;

#define m68k_dreg(r,num) ((r).regs[(num)])
#define m68k_areg(r,num) (((r).regs + 8)[(num)])




#ifdef SWAPPED_ADDRESS_SPACE





#define get_ibyte(o) do_get_mem_byte((uae_u8 *)(regs.pc_p - (o) - 1))
#define get_iword(o) do_get_mem_word((uae_u16 *)(regs.pc_p - (o)))
#define get_ilong(o) do_get_mem_long((uae_u32 *)(regs.pc_p - (o)))

static __inline__ uae_u32 get_ibyte_prefetch (uae_s32 o)
{
#if DISABLE_PREFETCH
	return do_get_mem_byte((uae_u8 *)(regs.pc_p - o - 1));
#else
  if (o > 3 || o < 0)
		return do_get_mem_byte((uae_u8 *)(regs.pc_p - o - 1));
  return do_get_mem_byte((uae_u8 *)(((uae_u8 *)&regs.prefetch) - o - 1));
#endif
}
static __inline__ uae_u32 get_iword_prefetch (uae_s32 o)
{
#if DISABLE_PREFETCH
	return do_get_mem_word((uae_u16 *)(regs.pc_p - o));
#else
  if (o > 3 || o < 0)
		return do_get_mem_word((uae_u16 *)(regs.pc_p - o));
  return do_get_mem_word((uae_u16 *)(((uae_u8 *)&regs.prefetch) - o));
#endif
}
static __inline__ uae_u32 get_ilong_prefetch (uae_s32 o)
{
#if DISABLE_PREFETCH
	return do_get_mem_long((uae_u32 *)(regs.pc_p - o));
#else
  if (o > 3 || o < 0)
		return do_get_mem_long((uae_u32 *)(regs.pc_p - o));
  if (o == 0)
		return do_get_mem_long(&regs.prefetch);
  return (do_get_mem_word (((uae_u16 *)&regs.prefetch) - 1) << 16) | do_get_mem_word ((uae_u16 *)(regs.pc_p - 4));
#endif
}

#define m68k_incpc(o) (regs.pc_p -= (o))

static __inline__ void fill_prefetch_0 (void)
{
#if !DISABLE_PREFETCH
    uae_u32 r;
#ifdef UNALIGNED_PROFITABLE
    r = *(uae_u32 *)regs.pc_p;
    regs.prefetch = r;
#else
    r = do_get_mem_long ((uae_u32 *)regs.pc_p);
    do_put_mem_long (&regs.prefetch, r);
#endif
#endif
}

#define fill_prefetch_2 fill_prefetch_0

/* These are only used by the 68020/68881 code, and therefore don't
 * need to handle prefetch.  */
static __inline__ uae_u32 next_ibyte (void)
{
    uae_u32 r = get_ibyte (0);
    m68k_incpc (2);
    return r;
}

static __inline__ uae_u16 next_iword (void)
{
    uae_u16 r = get_iword (0);
    m68k_incpc (2);
    return r;
}

static __inline__ uae_u32 next_ilong (void)
{
    uae_u32 r = get_ilong (0);
    m68k_incpc (4);
    return r;
}

#if !defined USE_COMPILER
static __inline__ void m68k_setpc (uaecptr newpc)
{
    regs.pc_p = regs.pc_oldp = get_real_address(newpc);
    regs.pc = newpc;
}
#else
extern void m68k_setpc (uaecptr newpc);
#endif

static __inline__ uaecptr m68k_getpc (void)
{
    return regs.pc + ((char *)regs.pc_oldp - (char *)regs.pc_p);
}

static __inline__ uaecptr m68k_getpc_p (uae_u8 *p)
{
    return regs.pc + ((char *)regs.pc_oldp - (char *)p);
}






#else // SWAPPED_ADDRESS_SPACE





#define get_ibyte(o) do_get_mem_byte((uae_u8 *)(regs.pc_p + (o) + 1))
#define get_iword(o) do_get_mem_word((uae_u16 *)(regs.pc_p + (o)))
#define get_ilong(o) do_get_mem_long((uae_u32 *)(regs.pc_p + (o)))

#ifdef HAVE_GET_WORD_UNSWAPPED
#define GET_OPCODE (do_get_mem_word_unswapped (regs.pc_p))
#else
#define GET_OPCODE (get_iword (0))
#endif

static __inline__ uae_u32 get_ibyte_prefetch (uae_s32 o)
{
#if DISABLE_PREFETCH
	return do_get_mem_byte((uae_u8 *)(regs.pc_p + o + 1));
#else
	if (o > 3 || o < 0)
		return do_get_mem_byte((uae_u8 *)(regs.pc_p + o + 1));

  return do_get_mem_byte((uae_u8 *)(((uae_u8 *)&regs.prefetch) + o + 1));
#endif
}
static __inline__ uae_u32 get_iword_prefetch (uae_s32 o)
{
#if DISABLE_PREFETCH
		return do_get_mem_word((uae_u16 *)(regs.pc_p + o));
#else
  if (o > 3 || o < 0)
		return do_get_mem_word((uae_u16 *)(regs.pc_p + o));

  return do_get_mem_word((uae_u16 *)(((uae_u8 *)&regs.prefetch) + o));
#endif
}
static __inline__ uae_u32 get_ilong_prefetch (uae_s32 o)
{
#if DISABLE_PREFETCH
	return do_get_mem_long((uae_u32 *)(regs.pc_p + o));
#else
	if (o > 3 || o < 0)
		return do_get_mem_long((uae_u32 *)(regs.pc_p + o));
  if (o == 0)
		return do_get_mem_long(&regs.prefetch);
  return (do_get_mem_word (((uae_u16 *)&regs.prefetch) + 1) << 16) | do_get_mem_word ((uae_u16 *)(regs.pc_p + 4));
#endif
}

#define m68k_incpc(o) (regs.pc_p += (o))

static __inline__ void fill_prefetch_0 (void)
{
#if !DISABLE_PREFETCH
    uae_u32 r;
#ifdef UNALIGNED_PROFITABLE
    r = *(uae_u32 *)regs.pc_p;
    regs.prefetch = r;
#else
    r = do_get_mem_long ((uae_u32 *)regs.pc_p);
    do_put_mem_long (&regs.prefetch, r);
#endif
#endif
}

#define fill_prefetch_2 fill_prefetch_0

/* These are only used by the 68020/68881 code, and therefore don't
 * need to handle prefetch.  */
static __inline__ uae_u32 next_ibyte (void)
{
    uae_u32 r = get_ibyte (0);
    m68k_incpc (2);
    return r;
}

static __inline__ uae_u16 next_iword (void)
{
    uae_u16 r = get_iword (0);
    m68k_incpc (2);
    return r;
}

static __inline__ uae_u32 next_ilong (void)
{
    uae_u32 r = get_ilong (0);
    m68k_incpc (4);
    return r;
}

#if !defined USE_COMPILER
static __inline__ void m68k_setpc (uaecptr newpc)
{
    regs.pc_p = regs.pc_oldp = get_real_address(newpc);
    regs.pc = newpc;
}
#else
extern void REGPARAM2 m68k_setpc (uaecptr newpc);
#endif

static __inline__ uaecptr m68k_getpc (void)
{
    return regs.pc + ((char *)regs.pc_p - (char *)regs.pc_oldp);
}

static __inline__ uaecptr m68k_getpc_p (uae_u8 *p)
{
    return regs.pc + ((char *)p - (char *)regs.pc_oldp);
}






#endif // SWAPPED_ADDRESS_SPACE







#ifdef USE_COMPILER
extern void REGPARAM2 m68k_setpc_fast (uaecptr newpc);
extern void REGPARAM2 m68k_setpc_bcc (uaecptr newpc);
extern void REGPARAM2 m68k_setpc_rte (uaecptr newpc);
#else
#define m68k_setpc_fast m68k_setpc
#define m68k_setpc_bcc  m68k_setpc
#define m68k_setpc_rte  m68k_setpc
#endif

#ifdef STREAMLINED_UAE
#ifdef SPECFLAG_EXCEPIONS
extern cpuop_func *real_cpufunctbl[65536];
extern cpuop_func *cpufunctbl[65536+2048];
static void __inline__ spcflags_changed(void)
{
	if(regs.spcflags != 0) {
		DWORD OldProtect;
		VirtualProtect( (LPVOID)((DWORD)cpufunctbl + 4096), 64*4*1024, PAGE_NOACCESS, &OldProtect );
	}
}
static void __inline__ spcflags_changed2(void)
{
	if(regs.spcflags == 0) {
		DWORD OldProtect;
		VirtualProtect( (LPVOID)((DWORD)cpufunctbl + 4096), 64*4*1024, PAGE_READWRITE, &OldProtect );
	}
}
#else //!SPECFLAG_EXCEPIONS
extern cpuop_func **cpufunctbl;
extern cpuop_func *fake_cpufunctbl[65536];
extern cpuop_func *real_cpufunctbl[65536];
static void __inline__ spcflags_changed(void)
{
	if(regs.spcflags != 0) cpufunctbl = fake_cpufunctbl;
}

static void __inline__ spcflags_changed2(void)
{
	if(regs.spcflags == 0) cpufunctbl = real_cpufunctbl;
}
#endif //SPECFLAG_EXCEPIONS
#endif //STREAMLINED_UAE



#ifdef DO_INTERLOCKED

#ifdef STREAMLINED_UAE

#define _LOCK lock
//#define _LOCK

#define REGS_SPCFLAGS_OR(mask) _asm { _LOCK or [regs.spcflags], mask };\
		spcflags_changed();
#define REGS_SPCFLAGS_AND(mask) _asm { _LOCK and [regs.spcflags], mask };\
		spcflags_changed2();
#else
#define REGS_SPCFLAGS_OR(mask) _asm _LOCK or [regs.spcflags], mask
#define REGS_SPCFLAGS_AND(mask) _asm _LOCK and [regs.spcflags], mask
#endif

#else
static void inline REGS_SPCFLAGS_OR( uae_u16 mask )
{
	regs.spcflags |= (mask);
#ifdef STREAMLINED_UAE
	spcflags_changed();
#endif
}
static void inline REGS_SPCFLAGS_AND( uae_u16 mask )
{
	regs.spcflags &= (mask);
#ifdef STREAMLINED_UAE
	spcflags_changed2();
#endif
}
#endif

static void inline REGS_SPCFLAGS_SET( uae_u16 value )
{
	regs.spcflags = value;
#ifdef STREAMLINED_UAE
	spcflags_changed2();
#endif
}

static __inline__ void m68k_setstopped (int stop)
{
  regs.stopped = stop;
  if (stop) {
		REGS_SPCFLAGS_OR(SPCFLAG_STOP);
  }
}

#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
static __inline__ uae_u16 next_iword_020 (void)
{
    uae_u16 r = *((uae_u16 *)regs.pc_p);
    m68k_incpc (2);
    return r;
}
#else
#define next_iword_020 next_iword
#endif


extern void setup_ea_020_table(void);

/*
	In theory, it's good to have dp as the first parameter,
	since it will be used in ecx anyway. This generates code
	that is smaller and looks better -- but is sometimes slower. Why?
*/

typedef uae_u16 uae_udp;

#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
#define PARAMS020 uae_udp dp, uae_u32 base
typedef unsigned long REGPARAM2 ea020_func (uae_udp,uae_u32) REGPARAM;
#else
#define PARAMS020 uae_u32 base, uae_udp dp
typedef unsigned long REGPARAM2 ea020_func (uae_u32,uae_udp) REGPARAM;
#endif

#ifdef HAVE_GET_DISP_020_UNROLLED

#ifdef HAVE_GET_DISP_EA_020_SWAPPED_DP
#define EA020_MASK 0xFF09
#else
#define EA020_MASK 0x09FF
#endif

extern ea020_func *ea_020_table[];

static uae_u32 __inline__ get_disp_ea_020 (uae_u32 base, uae_u16 dp)
{
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	return (*ea_020_table[dp&EA020_MASK])(dp,base);
#else
	return (*ea_020_table[dp&EA020_MASK])(base,dp);
#endif
}

#else // !HAVE_GET_DISP_020_UNROLLED

extern uae_u32 REGPARAM2 get_disp_ea_020_generic (PARAMS020);
static uae_u32 __inline__ get_disp_ea_020 (uae_u32 base, uae_u16 dp)
{
#ifdef HAVE_GET_DISP_EA_020_SWAPPED_PARAMS
	return (get_disp_ea_020_generic (dp,base) );
#else
	return (get_disp_ea_020_generic (base,dp) );
#endif
}

#endif //!HAVE_GET_DISP_020_UNROLLED

extern uae_u32 REGPARAM2 get_disp_ea_000 (uae_u32 base, uae_u32 dp);

extern uae_s32 ShowEA (int reg, amodes mode, wordsizes size, char *buf);

extern void MakeSR (void);
extern void MakeFromSR (void);
extern void Exception (int, uaecptr);
extern void dump_counts (void);
extern void m68k_move2c (int, uae_u32 *);
extern void m68k_movec2 (int, uae_u32 *);
extern void m68k_divl (uae_u32, uae_u32, uae_u16, uaecptr);
extern void m68k_mull (uae_u32, uae_u32, uae_u16);
extern void init_m68k (void);
extern void m68k_go (int);
extern void m68k_dumpstate (uaecptr *);
extern void m68k_disasm (uaecptr, uaecptr *, int);
extern void m68k_reset (void);
extern void m68k_enter_debugger(void);

extern void mmu_op (uae_u32, uae_u16);

void REGPARAM2 fpp_opp (uae_u32, uae_u16);
void REGPARAM2 fdbcc_opp (uae_u32, uae_u16);
void REGPARAM2 fscc_opp (uae_u32, uae_u16);
void REGPARAM2 ftrapcc_opp (uae_u32,uaecptr);
void REGPARAM2 fbcc_opp (uae_u32, uaecptr, uae_u32);
void REGPARAM2 fsave_opp (uae_u32);
void REGPARAM2 frestore_opp (uae_u32);

/* Opcode of faulting instruction */
extern uae_u16 last_op_for_exception_3;
/* PC at fault time */
extern uaecptr last_addr_for_exception_3;
/* Address that generated the exception */
extern uaecptr last_fault_for_exception_3;

#define CPU_OP_NAME(a) op ## a


// NOTE these are cycled now!

/* 68040 + 68881 */
extern struct cputbl op_smalltbl_0[];
/* 68020 + 68881 */
extern struct cputbl op_smalltbl_1[];
/* 68020 */
extern struct cputbl op_smalltbl_2[];
/* 68010 */
extern struct cputbl op_smalltbl_3[];
/* 68000 */
extern struct cputbl op_smalltbl_4[];
/* 68000 slow but compatible.  */
// extern struct cputbl op_smalltbl_5[];

#ifndef STREAMLINED_UAE
//extern cpuop_func *cpufunctbl[65536] ASM_SYM_FOR_FUNC ("cpufunctbl");
#endif

enum {
	OVERFLOW_NONE=0,
	OVERFLOW_OVRL,
	OVERFLOW_DIVZERO
};

#ifdef OVERFLOW_EXCEPTIONS
extern int overflow_confition;
#endif

#endif // NEWCPU_H

} // extern "C"
