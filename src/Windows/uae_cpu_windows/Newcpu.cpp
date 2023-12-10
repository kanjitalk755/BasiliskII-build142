 /*
  * UAE - The Un*x Amiga Emulator
  *
  * MC68000 emulation
  *
  * (c) 1995 Bernd Schmidt
  *
  * Streamlined for Win32/MSVC5 by Lauri Pesonen
  *
  */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sysdeps.h"

#include "cpu_emulation.h"
#include "main.h"
#include "emul_op.h"
#include "clip_windows.h"
#include "counter.h"

#define INSTR_HISTORY 0

// From main_windows.cpp -- test
extern int m_disable_internal_wait;

#include "fpu.h"

extern "C" {

#ifdef OVERFLOW_EXCEPTIONS
int overflow_confition = 0;
#endif


#include "m68k.h"
#include "memory.h"
#include "readcpu.h"
#include "newcpu.h"
#include "compiler.h"
#include "audio.h"


#define DEBUG 0
#include "debug.h"

int quit_program = 0;
// int debugging = 0;
struct flag_struct regflags;

/* Opcode of faulting instruction */
uae_u16 last_op_for_exception_3;
/* PC at fault time */
uaecptr last_addr_for_exception_3;
/* Address that generated the exception */
uaecptr last_fault_for_exception_3;

int areg_byteinc[] = { 1,1,1,1,1,1,1,2 };
int imm8_table[] = { 8,1,2,3,4,5,6,7 };

int movem_index1[256];
int movem_index2[256];
int movem_next[256];

// int fpp_movem_index1[256];
// int fpp_movem_index2[256];
// int fpp_movem_next[256];


#ifdef STREAMLINED_UAE
#ifdef SPECFLAG_EXCEPIONS
cpuop_func *real_cpufunctbl[65536];
cpuop_func *cpufunctbl[65536+2048];
#else
cpuop_func *real_cpufunctbl[65536];
cpuop_func *fake_cpufunctbl[65536];
cpuop_func **cpufunctbl = fake_cpufunctbl;
#endif
#else
cpuop_func *real_cpufunctbl[65536];
static const cpuop_func **cpufunctbl = real_cpufunctbl;
#endif

static int caar = 0, cacr = 0;

#define COUNT_INSTRS 0

#if COUNT_INSTRS
int counting_instrs = 0;
static unsigned long int instrcount[65536];
static uae_u16 opcodenums[65536];

static int __cdecl compfn (const void *el1, const void *el2)
{
  return (int)instrcount[*(const uae_u16 *)el2] - (int)instrcount[*(const uae_u16 *)el1];
}

static char *icountfilename (void)
{
	char *name = getenv ("INSNCOUNT");
	if (name)
		return name;
	return COUNT_INSTRS == 2 ? "frequent.68k" : "insncount";
}

void dump_counts (void)
{
	FILE *f = fopen (icountfilename (), "w");
	unsigned long int total = 0;
	int i;

	write_log ("Writing instruction count file...\n");
	for (i = 0; i < 65536; i++) {
		opcodenums[i] = i;
		total += instrcount[i];
	}
	qsort (opcodenums, 65536, sizeof(uae_u16), compfn);

	fprintf (f, "Total: %lu\n", total);
	for (i=0; i < 65536; i++) {
		unsigned long int cnt = instrcount[opcodenums[i]];
		struct instr *dp;
		struct mnemolookup *lookup;
		if (!cnt)
			break;
		dp = table68k + opcodenums[i];
		for (lookup = lookuptab;lookup->mnemo != (int)dp->mnemo; lookup++)
			;
		fprintf (f, "%04x: %lu %s\n", opcodenums[i], cnt, lookup->name);
	}
	fclose (f);
}
#else
#endif

// int broken_in;

#ifdef STREAMLINED_UAE
static int do_specialties (void);

#define CPUOP_LOCAL_SPACE 2048

void _declspec(naked) fake_cpufunctbl_all_funcs(void)
{
	if(do_specialties()) {
		if(m_sleep_enabled) Sleep(m_sleep);
		_asm {
			add  esp, CPUOP_LOCAL_SPACE
			pop  ebp
			pop  edx
			pop  ecx
			pop  ebx
			pop  eax
			pop  edi
			pop  esi
			ret ; returns to m68k_run_1
		}
	} else {
		_asm {
			mov   eax,[regs.pc_p]
#ifdef SWAPPED_ADDRESS_SPACE
			movzx   ecx, word ptr [eax-1]
#else
			movzx ecx, word ptr [eax]
#ifndef HAVE_GET_WORD_UNSWAPPED
	    xchg  cl,ch
#endif
#endif
			jmp   [ecx*4+real_cpufunctbl]
		}
	}
}

void _declspec(naked) op_illg_1 (void) REGPARAM
{
	// ecx is the opcode
	// op_illg() is _fastcall so ecx is fine.
	_asm {
#ifdef HAVE_GET_WORD_UNSWAPPED
	  xchg  cl,ch
#endif
		call   op_illg
		mov   eax,[regs.pc_p]
#ifndef SPECFLAG_EXCEPIONS
		mov		edx,[cpufunctbl]
#endif
#ifdef SWAPPED_ADDRESS_SPACE
		movzx ecx, word ptr [eax-1]
#else
		movzx ecx, word ptr [eax]
#ifndef HAVE_GET_WORD_UNSWAPPED
	  xchg  cl,ch
#endif
#endif
#ifdef SPECFLAG_EXCEPIONS
		jmp   dword ptr [ecx*4+cpufunctbl+4096]
#else
		jmp   dword ptr [ecx*4+edx]
#endif
	}
}

#define op_illg_1 ((cpuop_func *)op_illg_1)

#else //!STREAMLINED_UAE

#if HAVE_VOID_CPU_FUNCS
void REGPARAM2 op_illg_1 (uae_u32 opcode) REGPARAM;

void REGPARAM2 op_illg_1 (uae_u32 opcode) REGPARAM
{
  op_illg (cft_map (opcode));
}
#else
unsigned long REGPARAM2 op_illg_1 (uae_u32 opcode) REGPARAM;

unsigned long REGPARAM2 op_illg_1 (uae_u32 opcode) REGPARAM
{
  op_illg (cft_map (opcode));
  return 4;
}
#endif //!HAVE_VOID_CPU_FUNCS
#endif //!STREAMLINED_UAE

// This doesn't need to be particularly efficient.
static void do_putscrap( uint8 *data, uint32 data_sz )
{
	struct M68kRegisters r;
	struct M68kRegisters save_regs;
	int i;
	uint16 save_sr;

	for (i=7; i>=0; i--) {
		save_regs.d[i] = m68k_dreg(regs, i);
		save_regs.a[i] = m68k_areg(regs, i);
	}
	save_sr = regs.sr;

	for (i=7; i>=0; i--) {
		r.d[i] = m68k_dreg(regs, i);
		r.a[i] = m68k_areg(regs, i);
	}
	MakeSR();
	r.sr = regs.sr;

	r.d[0] = data_sz;
	Execute68kTrap(0xa71e, &r);		// NewPtrSysClear()
	uint32 srcPtr = r.a[0];

	if(srcPtr) {
		memmove( Mac2HostAddr(srcPtr), data, data_sz );

		m68k_areg(regs, 7) -= 4; // space for retval
		Execute68kTrapStackBased(0xA9FC, &r, 2);	// ZeroScrap()
		m68k_areg(regs, 7) += 4;

		m68k_areg(regs, 7) -= 4; // space for retval
		m68k_areg(regs, 7) -= 4;
		WriteMacInt32(m68k_areg(regs, 7), data_sz);
		m68k_areg(regs, 7) -= 4;
		WriteMacInt32(m68k_areg(regs, 7), 'TEXT');
		m68k_areg(regs, 7) -= 4;
		WriteMacInt32(m68k_areg(regs, 7), srcPtr);

		Execute68kTrapStackBased( 0xA9FE, &r, 8 );	// PutScrap()

		m68k_areg(regs, 7) += 4;

		r.a[0] = srcPtr;
		Execute68kTrap(0xa01f, &r);		// DisposePtr()
	}

	for (i=7; i>=0; i--) {
		m68k_dreg(regs, i) = save_regs.d[i];
		m68k_areg(regs, i) = save_regs.a[i];
	}
	regs.sr = save_sr;

	ZeroScrap();
}

// Must not be inlined. Need a stack frame.
void GetScrap_InfoScrap_helper (void)
{
	uint8 *data;
	uint32 data_sz;
	GetTextScrap( data, data_sz );
	if(data && data_sz) {
		do_putscrap( data, data_sz );
	}
}

void _declspec(naked) ZeroScrap_PutScrap_handler (void) REGPARAM
{
	_asm {
		push  ecx
		call  ZeroScrap
		pop   ecx
#ifdef HAVE_GET_WORD_UNSWAPPED
	  xchg  cl,ch
#endif
		call   op_illg
		mov   eax,[regs.pc_p]
#ifndef SPECFLAG_EXCEPIONS
		mov		edx,[cpufunctbl]
#endif
#ifdef SWAPPED_ADDRESS_SPACE
		movzx ecx, word ptr [eax-1]
#else
		movzx ecx, word ptr [eax]
#ifndef HAVE_GET_WORD_UNSWAPPED
	  xchg  cl,ch
#endif
#endif
#ifdef SPECFLAG_EXCEPIONS
		jmp   dword ptr [ecx*4+cpufunctbl+4096]
#else
		jmp   dword ptr [ecx*4+edx]
#endif
	}
}

void _declspec(naked) GetScrap_InfoScrap_handler (void) REGPARAM
{
	_asm {
		push  ecx
		call  GetScrap_InfoScrap_helper
		pop   ecx
#ifdef HAVE_GET_WORD_UNSWAPPED
	  xchg  cl,ch
#endif
		call   op_illg
		mov   eax,[regs.pc_p]
#ifndef SPECFLAG_EXCEPIONS
		mov		edx,[cpufunctbl]
#endif
#ifdef SWAPPED_ADDRESS_SPACE
		movzx ecx, word ptr [eax-1]
#else
		movzx ecx, word ptr [eax]
#ifndef HAVE_GET_WORD_UNSWAPPED
	  xchg  cl,ch
#endif
#endif
#ifdef SPECFLAG_EXCEPIONS
		jmp   dword ptr [ecx*4+cpufunctbl+4096]
#else
		jmp   dword ptr [ecx*4+edx]
#endif
	}
}

void _declspec(naked) DIW_trap_handler (void) REGPARAM
{
	compiler_flush_jsr_stack();
	m68k_incpc(2);
	fill_prefetch_0 ();

	_asm {
		mov   eax,[regs.pc_p]
#ifndef SPECFLAG_EXCEPIONS
		mov		edx,[cpufunctbl]
#endif
#ifdef SWAPPED_ADDRESS_SPACE
		movzx ecx, word ptr [eax-1]
#else
		movzx ecx, word ptr [eax]
#ifndef HAVE_GET_WORD_UNSWAPPED
	  xchg  cl,ch
#endif
#endif
#ifdef SPECFLAG_EXCEPIONS
		jmp   dword ptr [ecx*4+cpufunctbl+4096]
#else
		jmp   dword ptr [ecx*4+edx]
#endif
	}
}

static void build_cpufunctbl ( cpuop_func **cpufunctbl)
{
  int i;
  unsigned long opcode;

	int cpu_level = (CPUType == 4 ? 4
									 : CPUType == 3 ? 3
									 : CPUType == 2 ? 2
									 : CPUType == 1 ? 1
									 : 0 );
	if(FPUType && (CPUType == 2)) cpu_level = 3;

  struct cputbl *tbl = (cpu_level == 4 ? op_smalltbl_0
												: cpu_level == 3 ? op_smalltbl_1
                        : cpu_level == 2 ? op_smalltbl_1
                        : cpu_level == 1 ? op_smalltbl_3
												: op_smalltbl_4 );

  for (opcode = 0; opcode < 65536; opcode++)
    cpufunctbl[cft_map (opcode)] = op_illg_1;
  for (i = 0; tbl[i].handler != NULL; i++) {
    if (! tbl[i].specific)
      cpufunctbl[cft_map (tbl[i].opcode)] = tbl[i].handler;
  }
  for (opcode = 0; opcode < 65536; opcode++) {
    cpuop_func *f;
    if (table68k[opcode].mnemo == i_ILLG || (int)table68k[opcode].clev > cpu_level)
      continue;
    if (table68k[opcode].handler != -1) {
      f = cpufunctbl[cft_map (table68k[opcode].handler)];
      if (f == op_illg_1) abort();
        cpufunctbl[cft_map (opcode)] = f;
    }
  }
  for (i = 0; tbl[i].handler != NULL; i++) {
    if (tbl[i].specific)
      cpufunctbl[cft_map (tbl[i].opcode)] = tbl[i].handler;
  }

	// A-line traps
	// Must not use the EmulOp mechanism for these.
	cpufunctbl[cft_map (0xa9fc)] = (cpuop_func *)ZeroScrap_PutScrap_handler;
	cpufunctbl[cft_map (0xa9fe)] = (cpuop_func *)ZeroScrap_PutScrap_handler;
	cpufunctbl[cft_map (0xa9fd)] = (cpuop_func *)GetScrap_InfoScrap_handler;
	cpufunctbl[cft_map (0xa9f9)] = (cpuop_func *)GetScrap_InfoScrap_handler;
	if(m_disable_internal_wait) {
		cpufunctbl[cft_map (0xa07f)] = (cpuop_func *)DIW_trap_handler;
	}

	// FPU
}

void init_m68k (void)
{
	int i;

	for (i = 0 ; i < 256 ; i++) {
		int j;
		for (j = 0 ; j < 8 ; j++) {
			if (i & (1 << j)) break;
		}
		movem_index1[i] = j;
		movem_index2[i] = 7-j;
		movem_next[i] = i & (~(1 << j));
	}
	/*
	for (i = 0 ; i < 256 ; i++) {
		int j;
		for (j = 7 ; j >= 0 ; j--) {
			if (i & (1 << j)) break;
		}
		fpp_movem_index1[i] = j;
		fpp_movem_index2[i] = 7-j;
		fpp_movem_next[i] = i & (~(1 << j));
		D(bug("%03d %03d %03d \r\n",(int)fpp_movem_index1[i],(int)fpp_movem_index2[i],(int)fpp_movem_next[i]));
	}
	*/
#if COUNT_INSTRS
	{
		FILE *f = fopen (icountfilename (), "r");
		memset (instrcount, 0, sizeof instrcount);
		if (f) {
			uae_u32 opcode, count, total;
			char name[20];
			write_log ("Reading instruction count file...\n");
			fscanf (f, "Total: %lu\n", &total);
			while (fscanf (f, "%lx: %lu %s\n", &opcode, &count, name) == 3) {
				instrcount[opcode] = count;
			}
			fclose(f);
		}
	}
#endif
	init_counts();

	read_table68k ();

#ifdef STREAMLINED_UAE

	setup_ea_020_table();

#ifdef SPECFLAG_EXCEPIONS
	do_merges ();
	build_cpufunctbl(&cpufunctbl[1024]);
	for(i=0; i<65536; i++) {
		real_cpufunctbl[i] = cpufunctbl[i+1024];
	}
#else
	// There may be some interrupt already pending,
	// causing cpufunctbl = fake_cpufunctbl.
	// Therefore must fill the ops into the fake table.
	cpufunctbl = fake_cpufunctbl;
	do_merges ();
	build_cpufunctbl(cpufunctbl);
	for(i=0; i<65536; i++) {
		real_cpufunctbl[i] = fake_cpufunctbl[i];
	}
	for(i=0; i<65536; i++) {
		fake_cpufunctbl[i] = (cpuop_func *)fake_cpufunctbl_all_funcs;
	}
	cpufunctbl = real_cpufunctbl;
#endif

#else
	do_merges ();
	build_cpufunctbl (cpufunctbl);
#endif
}

struct regstruct regs;
// struct regstruct lastint_regs;
// int lastint_no;

uae_u32 REGPARAM2 get_disp_ea_000 (uae_u32 base, uae_u32 dp)
{
	int reg = (dp >> 12) & 15;
	uae_s32 regd = regs.regs[reg];
#if 1
	if ((dp & 0x800) == 0)
		regd = (uae_s32)(uae_s16)regd;
	return base + (uae_s8)dp + regd;
#else
	/* Branch-free code... benchmark this again now that
	 * things are no longer inline.  */
	uae_s32 regd16;
	uae_u32 mask;
	mask = ((dp & 0x800) >> 11) - 1;
	regd16 = (uae_s32)(uae_s16)regd;
	regd16 &= mask;
	mask = ~mask;
	base += (uae_s8)dp;
	regd &= mask;
	regd |= regd16;
	return base + regd;
#endif
}

void MakeSR (void)
{
#if 0
  assert((regs.t1 & 1) == regs.t1);
  assert((regs.t0 & 1) == regs.t0);
  assert((regs.s & 1) == regs.s);
  assert((regs.m & 1) == regs.m);
  assert((XFLG & 1) == XFLG);
  assert((NFLG & 1) == NFLG);
  assert((ZFLG & 1) == ZFLG);
  assert((VFLG & 1) == VFLG);
  assert((CFLG & 1) == CFLG);
#endif
  regs.sr = ((regs.t1 << 15) | (regs.t0 << 14)
       | (regs.s << 13) | (regs.m << 12) | (regs.intmask << 8)
       | (GET_XFLG << 4) | (GET_NFLG << 3) | (GET_ZFLG << 2) | (GET_VFLG << 1)
       | GET_CFLG);
}

void MakeFromSR (void)
{
  int oldm = regs.m;
  int olds = regs.s;

  regs.t1 = (regs.sr >> 15) & 1;
  regs.t0 = (regs.sr >> 14) & 1;
  regs.s = (regs.sr >> 13) & 1;
  regs.m = (regs.sr >> 12) & 1;
  regs.intmask = (regs.sr >> 8) & 7;
  SET_XFLG ((regs.sr >> 4) & 1);
  SET_NFLG ((regs.sr >> 3) & 1);
  SET_ZFLG ((regs.sr >> 2) & 1);
  SET_VFLG ((regs.sr >> 1) & 1);
  SET_CFLG (regs.sr & 1);
  if (CPUType >= 2) {
    if (olds != regs.s) {
      if (olds) {
        if (oldm)
          regs.msp = m68k_areg(regs, 7);
        else
          regs.isp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.usp;
      } else {
        regs.usp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.m ? regs.msp : regs.isp;
      }
    } else if (olds && oldm != regs.m) {
      if (oldm) {
        regs.msp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.isp;
      } else {
        regs.isp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.msp;
      }
    }
  } else {
    if (olds != regs.s) {
      if (olds) {
        regs.isp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.usp;
      } else {
        regs.usp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.isp;
      }
    }
  }

	REGS_SPCFLAGS_OR( SPCFLAG_INT );

  if (regs.t1 || regs.t0) {
		REGS_SPCFLAGS_OR( SPCFLAG_TRACE );
  } else {
		REGS_SPCFLAGS_AND( ~(SPCFLAG_TRACE | SPCFLAG_DOTRACE) );
	}
}

void MakeFromSR_no_interrupt(void)
{
  int oldm = regs.m;
  int olds = regs.s;

  regs.t1 = (regs.sr >> 15) & 1;
  regs.t0 = (regs.sr >> 14) & 1;
  regs.s = (regs.sr >> 13) & 1;
  regs.m = (regs.sr >> 12) & 1;
  regs.intmask = (regs.sr >> 8) & 7;
  SET_XFLG ((regs.sr >> 4) & 1);
  SET_NFLG ((regs.sr >> 3) & 1);
  SET_ZFLG ((regs.sr >> 2) & 1);
  SET_VFLG ((regs.sr >> 1) & 1);
  SET_CFLG (regs.sr & 1);
  if (CPUType >= 2) {
    if (olds != regs.s) {
      if (olds) {
        if (oldm)
          regs.msp = m68k_areg(regs, 7);
        else
          regs.isp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.usp;
      } else {
        regs.usp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.m ? regs.msp : regs.isp;
      }
    } else if (olds && oldm != regs.m) {
      if (oldm) {
        regs.msp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.isp;
      } else {
        regs.isp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.msp;
      }
    }
  } else {
    if (olds != regs.s) {
      if (olds) {
        regs.isp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.usp;
      } else {
        regs.usp = m68k_areg(regs, 7);
        m68k_areg(regs, 7) = regs.isp;
      }
    }
  }
}

void Exception(int nr, uaecptr oldpc)
{
  compiler_flush_jsr_stack();
  MakeSR();
  if (!regs.s) {
    regs.usp = m68k_areg(regs, 7);
    if (CPUType >= 2)
      m68k_areg(regs, 7) = regs.m ? regs.msp : regs.isp;
    else
      m68k_areg(regs, 7) = regs.isp;
    regs.s = 1;
  }
  if (CPUType > 0) {
    if (nr == 2 || nr == 3) {
      int i;
      /* @@@ this is probably wrong (?) */
      for (i = 0 ; i < 12 ; i++) {
        m68k_areg(regs, 7) -= 2;
        put_word (m68k_areg(regs, 7), 0);
      }
      m68k_areg(regs, 7) -= 2;
      put_word (m68k_areg(regs, 7), 0xa000 + nr * 4);
    } else if (nr ==5 || nr == 6 || nr == 7 || nr == 9) {
      m68k_areg(regs, 7) -= 4;
      put_long (m68k_areg(regs, 7), oldpc);
      m68k_areg(regs, 7) -= 2;
      put_word (m68k_areg(regs, 7), 0x2000 + nr * 4);
    } else if (regs.m && nr >= 24 && nr < 32) {
      m68k_areg(regs, 7) -= 2;
      put_word (m68k_areg(regs, 7), nr * 4);
      m68k_areg(regs, 7) -= 4;
      put_long (m68k_areg(regs, 7), m68k_getpc ());
      m68k_areg(regs, 7) -= 2;
      put_word (m68k_areg(regs, 7), regs.sr);
      regs.sr |= (1 << 13);
      regs.msp = m68k_areg(regs, 7);
      m68k_areg(regs, 7) = regs.isp;
      m68k_areg(regs, 7) -= 2;
      put_word (m68k_areg(regs, 7), 0x1000 + nr * 4);
    } else {
      m68k_areg(regs, 7) -= 2;
      put_word (m68k_areg(regs, 7), nr * 4);
    }
  } else {
    if (nr == 2 || nr == 3) {
      m68k_areg(regs, 7) -= 12;
      /* ??????? */
      if (nr == 3) {
        put_long (m68k_areg(regs, 7), last_fault_for_exception_3);
        put_word (m68k_areg(regs, 7)+4, last_op_for_exception_3);
        put_long (m68k_areg(regs, 7)+8, last_addr_for_exception_3);
      }
      // write_log ("Exception!\n");
      goto kludge_me_do;
    }
  }
  m68k_areg(regs, 7) -= 4;
  put_long (m68k_areg(regs, 7), m68k_getpc ());
kludge_me_do:
  m68k_areg(regs, 7) -= 2;
  put_word (m68k_areg(regs, 7), regs.sr);
  m68k_setpc (get_long (regs.vbr + 4*nr));
  fill_prefetch_0 ();
  regs.t1 = regs.t0 = regs.m = 0;
	REGS_SPCFLAGS_AND( ~(SPCFLAG_TRACE | SPCFLAG_DOTRACE) );
}

static void Interrupt(int nr)
{
  // assert(nr < 8 && nr >= 0);
  // lastint_regs = regs;
  // lastint_no = nr;

  Exception(nr+24, 0);
  regs.intmask = nr;
  REGS_SPCFLAGS_OR( SPCFLAG_INT );
}

void m68k_move2c (int regno, uae_u32 *regp)
{
  if (CPUType == 1 && (regno & 0x7FF) > 1) {
    op_illg (0x4E7B);
  } else {
    switch (regno) {
			// 000 Source Function Code (SFC)
      case 0: 
				regs.sfc = *regp & 7;
				break;
			// 001 Destination Function Code (DFC)
      case 1: 
				regs.dfc = *regp & 7;
				break;
			// 002 Cache Control Register (CACR)
      case 2: 
				cacr = *regp & 0x3; /* ignore C and CE */
				break;
			// 800 User Stack Pointer (USP)
      case 0x800: 
				regs.usp = *regp; 
				break;
			// 801 Vector Base Register (VBR)
      case 0x801: 
				regs.vbr = *regp; 
				break;
			// 802 Cache Address Register (CAAR)
      case 0x802: 
				if (CPUType == 2 || CPUType == 3) {
					caar = *regp &0xfc;
				} else {
          op_illg (0x4E7B);
				}
				break;
			// 803 Master Stack Pointer (MSP)
      case 0x803: 
				regs.msp = *regp; 
				if (regs.m == 1) m68k_areg(regs, 7) = regs.msp; 
				break;
			// 804 Interrupt Stack Pointer (ISP)
      case 0x804: 
				regs.isp = *regp; 
				if (regs.m == 0) m68k_areg(regs, 7) = regs.isp; 
				break;
      default:
				if(CPUType < 4) {
					// _asm int 3
					op_illg (0x4E7B);
				} else {
					// MC68040/MC68LC040
					switch (regno) {
						// 003 MMU Translation Control Register (TC)
						case 3: 
							regs.tc = *regp & 0xc000;
							break;
						// 004 Instruction Transparent Translation Register 0 (ITT0)
						case 4: 
							regs.itt0 = *regp & 0xffffe364;
							break;
						// 005 Instruction Transparent Translation Register 1 (ITT1)
						case 5: 
							regs.itt1 = *regp & 0xffffe364;
							break;
						// 006 Data Transparent Translation Register 0 (DTT0)
						case 6: 
							regs.dtt0 = *regp & 0xffffe364;
							break;
						// 007 Data Transparent Translation Register 1 (DTT1)
						case 7: 
							regs.dtt1 = *regp & 0xffffe364;
							break;
						// 805 MMU Status Register (MMUSR)
						case 0x805: 
							regs.mmusr = *regp;
							break;
						// 806 User Root Pointer (URP)
						case 0x806: 
							regs.urp = *regp;
							break;
						// 807 Supervisor Root Pointer (SRP)
						case 0x807: 
							regs.srp = *regp;
							break;
						default:
							// _asm int 3
							op_illg (0x4E7B);
					}
				}
        break;
    }
  }
}

void m68k_movec2 (int regno, uae_u32 *regp)
{
  if (CPUType == 1 && (regno & 0x7FF) > 1) {
    op_illg (0x4E7A);
  } else {
    switch (regno) {
			case 0: 
				*regp = regs.sfc; 
				break;
			case 1: 
				*regp = regs.dfc; 
				break;
			case 2: 
				*regp = cacr; 
				break;
			case 0x800: 
				*regp = regs.usp; 
				break;
			case 0x801: 
				*regp = regs.vbr; 
				break;
			case 0x802: 
				if (CPUType == 2 || CPUType == 3) {
					*regp = caar; 
				} else {
          op_illg (0x4E7B);
				}
				break;
			case 0x803: 
				*regp = regs.m == 1 ? m68k_areg(regs, 7) : regs.msp; 
				break;
			case 0x804: 
				*regp = regs.m == 0 ? m68k_areg(regs, 7) : regs.isp; 
				break;
			default:
				if(CPUType < 4) {
					// _asm int 3
					op_illg (0x4E7A);
				} else {
					// MC68040/MC68LC040
					switch (regno) {
						// 003 MMU Translation Control Register (TC)
						case 3: 
							*regp = regs.tc;
							break;
						// 004 Instruction Transparent Translation Register 0 (ITT0)
						case 4: 
							*regp = regs.itt0;
							break;
						// 005 Instruction Transparent Translation Register 1 (ITT1)
						case 5: 
							*regp = regs.itt1;
							break;
						// 006 Data Transparent Translation Register 0 (DTT0)
						case 6: 
							*regp = regs.dtt0;
							break;
						// 007 Data Transparent Translation Register 1 (DTT1)
						case 7: 
							*regp = regs.dtt1;
							break;
						// 805 MMU Status Register (MMUSR)
						case 0x805: 
							*regp = regs.mmusr;
							break;
						// 806 User Root Pointer (URP)
						case 0x806: 
							*regp = regs.urp;
							break;
						// 807 Supervisor Root Pointer (SRP)
						case 0x807: 
							*regp = regs.srp;
							break;
						default:
							// _asm int 3
							op_illg (0x4E7A);
					}
				}
				break;
    }
  }
}

#ifdef OVERFLOW_EXCEPTIONS
/*
	Let the exception handler in video_windows.cpp) do all of the
	overflow and divide by zero checking.
*/
void m68k_divl (uae_u32 opcode, uae_u32 src, uae_u16 extra, uaecptr oldpc)
{
  if (extra & 0x800) {
		/* signed variant */
		uae_s32 a = (uae_s32)m68k_dreg(regs, (extra >> 12) & 7);
		uae_s32 quot;
		uae_s32 rem;

		if (extra & 0x400) {
			uae_s32 b = m68k_dreg(regs, extra & 7);
			_asm {
				; push eax
				push edx
				mov eax, a
				mov edx, b
				idiv src
				mov quot, eax
				mov rem, edx
				pop edx
				; pop eax
			}
		} else {
			_asm {
				; push eax
				push edx
				mov eax, a
				cdq
				idiv src
				mov quot, eax
				mov rem, edx
				pop edx
				; pop eax
			}
		}

		if(overflow_confition) {
			if(overflow_confition == OVERFLOW_OVRL) {
				overflow_confition = 0;
				SET_VFLG (1);
				SET_NFLG (1);
				SET_CFLG (0);
			} else { // OVERFLOW_DIVZERO
				overflow_confition = 0;
				Exception (5, oldpc);
				return;
			}
		} else {
			SET_VFLG (0);
			SET_CFLG (0);
			SET_ZFLG (((uae_s32)quot) == 0);
			SET_NFLG (((uae_s32)quot) < 0);
			m68k_dreg(regs, extra & 7) = (uae_u32)rem;
			m68k_dreg(regs, (extra >> 12) & 7) = (uae_u32)quot;
		}
  } else {
		/* unsigned */
		uae_s32 a = (uae_s32)m68k_dreg(regs, (extra >> 12) & 7);
		uae_s32 quot;
		uae_s32 rem;

		if (extra & 0x400) {
			uae_s32 b = m68k_dreg(regs, extra & 7);
			_asm {
				; push eax
				push edx
				mov eax, a
				mov edx, b
				div src
				mov rem, edx
				mov quot, eax
				pop edx
				; pop eax
			}
		} else {
			_asm {
				; push eax
				push edx
				mov eax, a
				xor edx, edx
				div src
				mov rem, edx
				mov quot, eax
				pop edx
				; pop eax
			}
		}

		if(overflow_confition) {
			if(overflow_confition == OVERFLOW_OVRL) {
				overflow_confition = 0;
				SET_VFLG (1);
				SET_NFLG (1);
				SET_CFLG (0);
			} else { // OVERFLOW_DIVZERO
				overflow_confition = 0;
				Exception (5, oldpc);
				return;
			}
		} else {
			SET_VFLG (0);
			SET_CFLG (0);
			SET_ZFLG (((uae_s32)quot) == 0);
			SET_NFLG (((uae_s32)quot) < 0);
			m68k_dreg(regs, extra & 7) = (uae_u32)rem;
			m68k_dreg(regs, (extra >> 12) & 7) = (uae_u32)quot;
		}
  }
}
#else //!OVERFLOW_EXCEPTIONS
void m68k_divl (uae_u32 opcode, uae_u32 src, uae_u16 extra, uaecptr oldpc)
{
  if (src == 0) {
		Exception (5, oldpc);
	  return;
  }
  if (extra & 0x800) {
		/* signed variant */

		uae_s64 a = (uae_s64)(uae_s32)m68k_dreg(regs, (extra >> 12) & 7);
		uae_s64 quot, rem;

		if (extra & 0x400) {
			a &= 0xffffffffu;
			a |= (uae_s64)m68k_dreg(regs, extra & 7) << 32;
		}

		rem = a % (uae_s64)(uae_s32)src;
		quot = a / (uae_s64)(uae_s32)src;

		if ((quot & UVAL64(0xffffffff80000000)) != 0
				&& (quot & UVAL64(0xffffffff80000000)) != UVAL64(0xffffffff80000000))
		{
			SET_VFLG (1);
			SET_NFLG (1);
			SET_CFLG (0);
		} else {
      if (((uae_s32)rem < 0) != ((uae_s64)a < 0)) rem = -rem;
      SET_VFLG (0);
      SET_CFLG (0);
      SET_ZFLG (((uae_s32)quot) == 0);
      SET_NFLG (((uae_s32)quot) < 0);
      m68k_dreg(regs, extra & 7) = (uae_u32)rem;
      m68k_dreg(regs, (extra >> 12) & 7) = (uae_u32)quot;
	  }

  } else {
		/* unsigned */

		uae_u64 a = (uae_u64)(uae_u32)m68k_dreg(regs, (extra >> 12) & 7);
		uae_u64 quot, rem;

		if (extra & 0x400) {
			a &= 0xffffffffu;
			a |= (uae_u64)m68k_dreg(regs, extra & 7) << 32;
		}
		rem = a % (uae_u64)src;
		quot = a / (uae_u64)src;
		if (quot > 0xffffffffu) {
      SET_VFLG (1);
      SET_NFLG (1);
      SET_CFLG (0);
		} else {
      SET_VFLG (0);
      SET_CFLG (0);
      SET_ZFLG (((uae_s32)quot) == 0);
      SET_NFLG (((uae_s32)quot) < 0);
      m68k_dreg(regs, extra & 7) = (uae_u32)rem;
      m68k_dreg(regs, (extra >> 12) & 7) = (uae_u32)quot;
	  }
  }
}
#endif //OVERFLOW_EXCEPTIONS

#ifdef OVERFLOW_EXCEPTIONS
void m68k_mull (uae_u32 opcode, uae_u32 src, uae_u16 extra)
{
#if defined(X86_ASSEMBLY)
	uint8 overflow;
#endif
  if (extra & 0x800) {
		/* signed variant */
		uae_s32 a = (uae_s32)m68k_dreg(regs, (extra >> 12) & 7);

		if (extra & 0x400) {
			uae_s32 b;
			_asm {
				; push eax
				push edx
				mov eax, a
				imul src
				mov b, edx
				mov a, eax
				pop edx
				; pop eax
			}
			m68k_dreg(regs, extra & 7) = (uae_u32)b;
			SET_VFLG (0);
		} else {
			_asm {
				; push eax
				push edx
				mov eax, a
				imul src
				mov a, eax
#if defined(X86_ASSEMBLY)
				setc byte ptr overflow
#else
				setc byte ptr VFLG
#endif
				pop edx
				; pop eax
			}
#if defined(X86_ASSEMBLY)
			SET_VFLG(overflow);
#endif
		}

		SET_CFLG (0);
		SET_ZFLG (a == 0);
		SET_NFLG (a < 0);
	  m68k_dreg(regs, (extra >> 12) & 7) = (uae_u32)a;

  } else {
		/* unsigned */
		uae_u32 a = (uae_u32)m68k_dreg(regs, (extra >> 12) & 7);

		if (extra & 0x400) {
			uae_u32 b;
			_asm {
				; push eax
				push edx
				mov eax, a
				mul src
				mov a, eax
				mov b, edx
				pop edx
				; pop eax
			}
			m68k_dreg(regs, extra & 7) = b;
			SET_VFLG (0);
		} else {
			_asm {
				; push eax
				push edx
				mov eax, a
				mul src
				mov a, eax
#if defined(X86_ASSEMBLY)
				setc byte ptr overflow
#else
				setc byte ptr VFLG
#endif
				pop edx
				; pop eax
			}
#if defined(X86_ASSEMBLY)
			SET_VFLG(overflow);
#endif
		}

		SET_CFLG (0);
		SET_ZFLG (a == 0);

		// Is this *really* correct???? I know that the docs say so, but...
		SET_NFLG (a < 0);

	  m68k_dreg(regs, (extra >> 12) & 7) = (uae_u32)a;
  }
}
#else //!OVERFLOW_EXCEPTIONS
void m68k_mull (uae_u32 opcode, uae_u32 src, uae_u16 extra)
{
  if (extra & 0x800) {
		/* signed variant */
		uae_s64 a = (uae_s64)(uae_s32)m68k_dreg(regs, (extra >> 12) & 7);

		a *= (uae_s64)(uae_s32)src;
		SET_VFLG (0);
		SET_CFLG (0);
		SET_ZFLG (a == 0);
		SET_NFLG (a < 0);
		if (extra & 0x400)
				m68k_dreg(regs, extra & 7) = (uae_u32)(a >> 32);
		else if ((a & UVAL64(0xffffffff80000000)) != 0
			 && (a & UVAL64(0xffffffff80000000)) != UVAL64(0xffffffff80000000))
		{
			SET_VFLG (1);
		}
	  m68k_dreg(regs, (extra >> 12) & 7) = (uae_u32)a;
  } else {
		/* unsigned */
		uae_u64 a = (uae_u64)(uae_u32)m68k_dreg(regs, (extra >> 12) & 7);

		a *= (uae_u64)src;
		SET_VFLG (0);
		SET_CFLG (0);
		SET_ZFLG (a == 0);

		// ???? miten unsigned multiplystä voi ikinä tulla negatiivinen.
		// mä olen ihan kauhian hämmästynyt.
		SET_NFLG (((uae_s64)a) < 0);

	  if (extra & 0x400)
      m68k_dreg(regs, extra & 7) = (uae_u32)(a >> 32);
		else if ((a & UVAL64(0xffffffff00000000)) != 0) {
      SET_VFLG (1);
		}
		m68k_dreg(regs, (extra >> 12) & 7) = (uae_u32)a;
  }
}
#endif //OVERFLOW_EXCEPTIONS

static char* ccnames[] =
{ "T ","F ","HI","LS","CC","CS","NE","EQ",
  "VC","VS","PL","MI","GE","LT","GT","LE" };

void m68k_reset (void)
{
	memset( &regs, 0, sizeof(regs) );
  m68k_areg (regs, 7) = 0x2000;
  m68k_setpc (ROMBaseMac + 0x2a);
  fill_prefetch_0 ();
  regs.s = 1;
  regs.m = 0;
  regs.stopped = 0;
  regs.t1 = 0;
  regs.t0 = 0;
  SET_ZFLG (0);
  SET_XFLG (0);
  SET_CFLG (0);
  SET_VFLG (0);
  SET_NFLG (0);
	REGS_SPCFLAGS_SET(0);
  regs.intmask = 7;
  regs.vbr = regs.sfc = regs.dfc = 0;
  regs.fpcr = regs.fpsr = regs.fpiar = 0;
	caar = cacr = 0;
	regs.tc = 0;
	regs.itt0 = 0;
	regs.itt1 = 0;
	regs.dtt0 = 0;
	regs.dtt1 = 0;
	regs.mmusr = 0;
	regs.urp = 0;
	regs.srp = 0;
	fpu_reset();
#ifdef OVERFLOW_EXCEPTIONS
	overflow_confition = 0;
#endif
}

void REGPARAM2 op_illg (uae_u32 opcode) REGPARAM
{
  compiler_flush_jsr_stack ();

  if ((opcode & 0xFF00) == 0x7100) {
    struct M68kRegisters r;
    int i;

    // Return from Execute68k()?
    if (opcode == M68K_EXEC_RETURN) {
      REGS_SPCFLAGS_OR( SPCFLAG_BRK );
      quit_program = 1;
      return;
    }

    // Call EMUL_OP opcode
    for (i=7; i>=0; i--) {
      r.d[i] = m68k_dreg(regs, i);
      r.a[i] = m68k_areg(regs, i);
    }
    MakeSR();
    r.sr = regs.sr;
    EmulOp((uint16)opcode, &r);
    for (i=7; i>=0; i--) {
      m68k_dreg(regs, i) = r.d[i];
      m68k_areg(regs, i) = r.a[i];
    }
    regs.sr = r.sr;
    MakeFromSR_no_interrupt();
    m68k_incpc(2);
    fill_prefetch_0 ();
    return;
  }

  if ((opcode & 0xF000) == 0xA000) {
		/*
		static bool startup_sound_played = false;
		// Wait for first SetPort
	  if (!startup_sound_played && opcode == 0xa873 && AudioAvailable) {
			startup_sound_played = true;
			play_startup_sound_portable();
		}
		*/

		/*
		extern int debugging_fpp;
		if ((opcode & 0xFFFF) == 0xA9EC) {
			debugging_fpp = 1;
		}
		*/

		Exception(0xA,0);
		return;
  }

  if ((opcode & 0xF000) == 0xF000) {
		Exception(0xB,0);
		return;
  }

  Exception (4,0);
  return;
}

void mmu_op(uae_u32 opcode, uae_u16 extra)
{
	if ((extra & 0xB000) == 0) { /* PMOVE instruction */
	} else if ((extra & 0xF000) == 0x2000) { /* PLOAD instruction */
	} else if ((extra & 0xF000) == 0x8000) { /* PTEST instruction */
	} else
	op_illg (opcode);
}

// static int n_insns = 0, n_spcinsns = 0;

static uaecptr last_trace_ad = 0;

static __inline__ void do_trace (void)
{
  if (regs.spcflags & SPCFLAG_TRACE) {    /* 6 */
	  if (regs.t0) {
      uae_u16 opcode;
      /* should also include TRAP, CHK, SR modification FPcc */
      /* probably never used so why bother */
      /* We can afford this to be inefficient... */
      m68k_setpc (m68k_getpc ());
      fill_prefetch_0 ();
      opcode = (uae_u16)get_word (regs.pc);
      if (opcode == 0x4e72    /* RTE */
    || opcode == 0x4e74     /* RTD */
    || opcode == 0x4e75     /* RTS */
    || opcode == 0x4e77     /* RTR */
    || opcode == 0x4e76     /* TRAPV */
    || (opcode & 0xffc0) == 0x4e80  /* JSR */
    || (opcode & 0xffc0) == 0x4ec0  /* JMP */
    || (opcode & 0xff00) == 0x6100  /* BSR */
    || ((opcode & 0xf000) == 0x6000 /* Bcc */
        && cctrue((opcode >> 8) & 0xf))
    || ((opcode & 0xf0f0) == 0x5050 /* DBcc */
        && !cctrue((opcode >> 8) & 0xf)
        && (uae_s16)m68k_dreg(regs, opcode & 7) != 0))
      {
				last_trace_ad = m68k_getpc ();
				REGS_SPCFLAGS_AND( ~SPCFLAG_TRACE );
				REGS_SPCFLAGS_OR( SPCFLAG_DOTRACE );
			}
		} else if (regs.t1) {
      last_trace_ad = m68k_getpc ();
      REGS_SPCFLAGS_AND( ~SPCFLAG_TRACE );
      REGS_SPCFLAGS_OR( SPCFLAG_DOTRACE );
		}
  }
}

static int do_specialties (void)
{
  /*n_spcinsns++;*/
  run_compiled_code();

  if (regs.spcflags & (SPCFLAG_DOTRACE|SPCFLAG_STOP|SPCFLAG_TRACE)) {
		if (regs.spcflags & SPCFLAG_DOTRACE) {
			Exception (9,last_trace_ad);
		}
		while (regs.spcflags & SPCFLAG_STOP) {
			if (regs.spcflags & (SPCFLAG_INT | SPCFLAG_DOINT)){
				int intr = intlev ();
				REGS_SPCFLAGS_AND( ~(SPCFLAG_INT | SPCFLAG_DOINT) );
				// B2 version of intlev() returns 0 or 1.
				if (/*intr != -1 &&*/ intr > regs.intmask) {
					Interrupt (intr);
					regs.stopped = 0;
					REGS_SPCFLAGS_AND( ~SPCFLAG_STOP );
				}
			}
		}
		do_trace ();
	}

  if (regs.spcflags & SPCFLAG_DOINT) {
		int intr = intlev ();
		REGS_SPCFLAGS_AND( ~SPCFLAG_DOINT );
		if (/*intr != -1 &&*/ intr > regs.intmask) {
      Interrupt (intr);
      regs.stopped = 0;
	  }
  }
  if (regs.spcflags & SPCFLAG_INT) {
		REGS_SPCFLAGS_AND( ~SPCFLAG_INT );
		REGS_SPCFLAGS_OR( SPCFLAG_DOINT );
  }
  if (regs.spcflags & (SPCFLAG_BRK | SPCFLAG_MODE_CHANGE)) {
	  REGS_SPCFLAGS_AND( ~(SPCFLAG_BRK | SPCFLAG_MODE_CHANGE) );
		return 1;
  }
  return 0;
}


#ifdef STREAMLINED_UAE
static void _declspec(naked) setup_frame(void)
{
	_asm {
		push  esi
		push  edi
		push  eax
		push  ebx
		push  ecx
		push  edx
		push  ebp
		; we must be prepared for the stack usage of any inlined functions
		sub		esp, CPUOP_LOCAL_SPACE
		mov   eax,[regs.pc_p]

#ifdef SWAPPED_ADDRESS_SPACE
		movzx ecx, word ptr [eax-1]
#else
		movzx ecx, word ptr [eax]
#ifndef HAVE_GET_WORD_UNSWAPPED
	  xchg  cl,ch
#endif
#endif

#ifdef SPECFLAG_EXCEPIONS
		jmp   dword ptr [ecx*4+cpufunctbl+4096]
#else
		mov		edx,[cpufunctbl]
		jmp   dword ptr [ecx*4+edx]
#endif
	}
}

static void m68k_run_1 (void)
{
	setup_frame();
}

#elif 1		//COUNT_INSTRS

static void m68k_run_1 (void)
{
  for (;;) {
		uae_u32 opcode = cft_map(get_iword(0));
#if COUNT_INSTRS == 2
	  uae_u32 op = ((opcode >> 8) & 255) | ((opcode & 255) << 8);
		if (counting_instrs && table68k[op].handler != -1)
	    instrcount[table68k[op].handler]++;
#elif COUNT_INSTRS == 1
	  uae_u32 op = ((opcode >> 8) & 255) | ((opcode & 255) << 8);
		if(counting_instrs) instrcount[op]++;
#endif
		(*cpufunctbl[opcode])(opcode);
		/*n_insns++;*/
		if (regs.spcflags) {
	    if (do_specialties ())
				return;
		}
  }
}

#else // !STREAMLINED_UAE

static void m68k_run_1 (void)
{
m68k_run_loop:
  _asm { 
    mov    ecx,[regs.pc_p]
#ifdef SWAPPED_ADDRESS_SPACE
		movzx ecx, word ptr [ecx-1]
#else
		movzx ecx, word ptr [ecx]
#ifndef HAVE_GET_WORD_UNSWAPPED
	  xchg  cl,ch
#endif
#endif
    call   [ecx*4+cpufunctbl]
    test   [regs.spcflags],0FFFFFFFFh
    jz     m68k_run_loop
    call   do_specialties
    test   eax,eax
    jz     m68k_run_loop
  }
}

#endif //STREAMLINED_UAE

static int in_m68k_go = 0;

void m68k_go (int may_quit)
{
  in_m68k_go++;
  for (;;) {
	  if (quit_program > 0) {
      if (quit_program == 1)
			  break;
      quit_program = 0;
      m68k_reset ();
		}
		m68k_run_1();
  }
#if 0
  if (debugging) {
    uaecptr nextpc;
    m68k_dumpstate(&nextpc);
    exit(1);
  }
#endif
  in_m68k_go--;
}




#if 0
#define get_ibyte_1(o) get_byte(regs.pc + (regs.pc_p - regs.pc_oldp) + (o) + 1)
#define get_iword_1(o) get_word(regs.pc + (regs.pc_p - regs.pc_oldp) + (o))
#define get_ilong_1(o) get_long(regs.pc + (regs.pc_p - regs.pc_oldp) + (o))

static long int m68kpc_offset;

/* The plan is that this will take over the job of exception 3 handling -
 * the CPU emulation functions will just do a longjmp to m68k_go whenever
 * they hit an odd address. */
static int verify_ea (int reg, amodes mode, wordsizes size, uae_u32 *val)
{
  uae_u16 dp;
  uae_s8 disp8;
  uae_s16 disp16;
  int r;
  uae_u32 dispreg;
  uaecptr addr;
  uae_s32 offset = 0;

  switch (mode){
    case Dreg:
		  *val = m68k_dreg (regs, reg);
			return 1;
    case Areg:
			*val = m68k_areg (regs, reg);
			return 1;

    case Aind:
    case Aipi:
		  addr = m68k_areg (regs, reg);
			break;
    case Apdi:
			addr = m68k_areg (regs, reg);
			break;
    case Ad16:
			disp16 = get_iword_1 (m68kpc_offset); m68kpc_offset += 2;
			addr = m68k_areg(regs,reg) + (uae_s16)disp16;
			break;
    case Ad8r:
		  addr = m68k_areg (regs, reg);
d8r_common:
			dp = get_iword_1 (m68kpc_offset); m68kpc_offset += 2;
			disp8 = dp & 0xFF;
			r = (dp & 0x7000) >> 12;
			dispreg = dp & 0x8000 ? m68k_areg(regs,r) : m68k_dreg(regs,r);
			if (!(dp & 0x800)) dispreg = (uae_s32)(uae_s16)(dispreg);
			dispreg <<= (dp >> 9) & 3;

			if (dp & 0x100) {
				uae_s32 outer = 0, disp = 0;
				uae_s32 base = addr;
				if (dp & 0x80) base = 0;
				if (dp & 0x40) dispreg = 0;
				if ((dp & 0x30) == 0x20) { disp = (uae_s32)(uae_s16)get_iword_1 (m68kpc_offset); m68kpc_offset += 2; }
				if ((dp & 0x30) == 0x30) { disp = get_ilong_1 (m68kpc_offset); m68kpc_offset += 4; }
				base += disp;

				if ((dp & 0x3) == 0x2) { outer = (uae_s32)(uae_s16)get_iword_1 (m68kpc_offset); m68kpc_offset += 2; }
				if ((dp & 0x3) == 0x3) { outer = get_ilong_1 (m68kpc_offset); m68kpc_offset += 4; }

				if (!(dp & 4)) base += dispreg;
				if (dp & 3) base = get_long (base);
				if (dp & 4) base += dispreg;

				addr = base + outer;
			} else {
		    addr += (uae_s32)((uae_s8)disp8) + dispreg;
			}
			break;
    case PC16:
			addr = m68k_getpc () + m68kpc_offset;
			disp16 = get_iword_1 (m68kpc_offset); m68kpc_offset += 2;
			addr += (uae_s16)disp16;
			break;
    case PC8r:
			addr = m68k_getpc () + m68kpc_offset;
			goto d8r_common;
    case absw:
			addr = (uae_s32)(uae_s16)get_iword_1 (m68kpc_offset);
			m68kpc_offset += 2;
			break;
    case absl:
			addr = get_ilong_1 (m68kpc_offset);
			m68kpc_offset += 4;
			break;
    case imm:
			switch (size){
			 case sz_byte:
					*val = get_iword_1 (m68kpc_offset) & 0xff;
					m68kpc_offset += 2;
					break;
			 case sz_word:
					*val = get_iword_1 (m68kpc_offset) & 0xffff;
					m68kpc_offset += 2;
					break;
			 case sz_long:
					*val = get_ilong_1 (m68kpc_offset);
					m68kpc_offset += 4;
					break;
			 default:
					break;
			}
		  return 1;
    case imm0:
			*val = (uae_s32)(uae_s8)get_iword_1 (m68kpc_offset);
			m68kpc_offset += 2;
			return 1;
    case imm1:
			*val = (uae_s32)(uae_s16)get_iword_1 (m68kpc_offset);
			m68kpc_offset += 2;
			return 1;
    case imm2:
			*val = get_ilong_1 (m68kpc_offset);
			m68kpc_offset += 4;
			return 1;
    case immi:
			*val = (uae_s32)(uae_s8)(reg & 0xff);
			return 1;
    default:
			addr = 0;
			break;
  }
  if ((addr & 1) == 0)
	  return 1;

  last_addr_for_exception_3 = m68k_getpc () + m68kpc_offset;
  last_fault_for_exception_3 = addr;
  return 0;
}

#pragma optimize("",off)
uae_s32 ShowEA (int reg, amodes mode, wordsizes size, char *buf)
{
  uae_u16 dp;
  uae_s8 disp8;
  uae_s16 disp16;
  int r;
  uae_u32 dispreg;
  uaecptr addr;
  uae_s32 offset = 0;
  char buffer[80];

  switch (mode){
		case Dreg:
			sprintf (buffer,"D%d", reg);
			break;
    case Areg:
			sprintf (buffer,"A%d", reg);
			break;
    case Aind:
			sprintf (buffer,"(A%d)", reg);
			break;
    case Aipi:
			sprintf (buffer,"(A%d)+", reg);
			break;
    case Apdi:
			sprintf (buffer,"-(A%d)", reg);
			break;
    case Ad16:
			disp16 = (uae_s16)get_iword_1 (m68kpc_offset); m68kpc_offset += 2;
			addr = m68k_areg(regs,reg) + (uae_s16)disp16;
			sprintf (buffer,"(A%d,$%04x) == $%08lx", reg, disp16 & 0xffff,
          (long unsigned int)addr);
		  break;
    case Ad8r:
			dp = (uae_u16)get_iword_1 (m68kpc_offset); m68kpc_offset += 2;
			disp8 = dp & 0xFF;
			r = (dp & 0x7000) >> 12;
			dispreg = dp & 0x8000 ? m68k_areg(regs,r) : m68k_dreg(regs,r);
			if (!(dp & 0x800)) dispreg = (uae_s32)(uae_s16)(dispreg);
			  dispreg <<= (dp >> 9) & 3;

			if (dp & 0x100) {
				uae_s32 outer = 0, disp = 0;
				uae_s32 base = m68k_areg(regs,reg);
				char name[10];
				sprintf (name,"A%d, ",reg);
				if (dp & 0x80) { base = 0; name[0] = 0; }
				if (dp & 0x40) dispreg = 0;
				if ((dp & 0x30) == 0x20) { disp = (uae_s32)(uae_s16)get_iword_1 (m68kpc_offset); m68kpc_offset += 2; }
				if ((dp & 0x30) == 0x30) { disp = get_ilong_1 (m68kpc_offset); m68kpc_offset += 4; }
				base += disp;

				if ((dp & 0x3) == 0x2) { outer = (uae_s32)(uae_s16)get_iword_1 (m68kpc_offset); m68kpc_offset += 2; }
				if ((dp & 0x3) == 0x3) { outer = get_ilong_1 (m68kpc_offset); m68kpc_offset += 4; }

				if (!(dp & 4)) base += dispreg;
				if (dp & 3) base = get_long (base);
				if (dp & 4) base += dispreg;

				addr = base + outer;
				sprintf (buffer,"(%s%c%d.%c*%d+%ld)+%ld == $%08lx", name,
					dp & 0x8000 ? 'A' : 'D', (int)r, dp & 0x800 ? 'L' : 'W',
					1 << ((dp >> 9) & 3),
					disp,outer,
					(long unsigned int)addr);
			} else {
				addr = m68k_areg(regs,reg) + (uae_s32)((uae_s8)disp8) + dispreg;
				sprintf (buffer,"(A%d, %c%d.%c*%d, $%02x) == $%08lx", reg,
						 dp & 0x8000 ? 'A' : 'D', (int)r, dp & 0x800 ? 'L' : 'W',
						 1 << ((dp >> 9) & 3), disp8,
						 (long unsigned int)addr);
		  }
			break;
    case PC16:
			addr = m68k_getpc () + m68kpc_offset;
			disp16 = (uae_s16)get_iword_1 (m68kpc_offset); m68kpc_offset += 2;
			addr += (uae_s16)disp16;
			sprintf (buffer,"(PC,$%04x) == $%08lx", disp16 & 0xffff,(long unsigned int)addr);
			break;
    case PC8r:
			addr = m68k_getpc () + m68kpc_offset;
			dp = (uae_u16)get_iword_1 (m68kpc_offset); m68kpc_offset += 2;
			disp8 = dp & 0xFF;
			r = (dp & 0x7000) >> 12;
			dispreg = dp & 0x8000 ? m68k_areg(regs,r) : m68k_dreg(regs,r);
			if (!(dp & 0x800)) dispreg = (uae_s32)(uae_s16)(dispreg);
			dispreg <<= (dp >> 9) & 3;

			if (dp & 0x100) {
				uae_s32 outer = 0,disp = 0;
				uae_s32 base = addr;
				char name[10];
				sprintf (name,"PC, ");
				if (dp & 0x80) { base = 0; name[0] = 0; }
				if (dp & 0x40) dispreg = 0;
				if ((dp & 0x30) == 0x20) { disp = (uae_s32)(uae_s16)get_iword_1 (m68kpc_offset); m68kpc_offset += 2; }
				if ((dp & 0x30) == 0x30) { disp = get_ilong_1 (m68kpc_offset); m68kpc_offset += 4; }
				base += disp;

				if ((dp & 0x3) == 0x2) { outer = (uae_s32)(uae_s16)get_iword_1 (m68kpc_offset); m68kpc_offset += 2; }
				if ((dp & 0x3) == 0x3) { outer = get_ilong_1 (m68kpc_offset); m68kpc_offset += 4; }

				if (!(dp & 4)) base += dispreg;
				if (dp & 3) base = get_long (base);
				if (dp & 4) base += dispreg;

				addr = base + outer;
				sprintf (buffer,"(%s%c%d.%c*%d+%ld)+%ld == $%08lx", name,
					dp & 0x8000 ? 'A' : 'D', (int)r, dp & 0x800 ? 'L' : 'W',
					1 << ((dp >> 9) & 3),
					disp,outer,
					(long unsigned int)addr);
			} else {
				addr += (uae_s32)((uae_s8)disp8) + dispreg;
				sprintf (buffer,"(PC, %c%d.%c*%d, $%02x) == $%08lx", dp & 0x8000 ? 'A' : 'D',
				(int)r, dp & 0x800 ? 'L' : 'W',  1 << ((dp >> 9) & 3),
				disp8, (long unsigned int)addr);
			}
			break;
    case absw:
			sprintf (buffer,"$%08lx", (long unsigned int)(uae_s32)(uae_s16)get_iword_1 (m68kpc_offset));
			m68kpc_offset += 2;
			break;
    case absl:
			sprintf (buffer,"$%08lx", (long unsigned int)get_ilong_1 (m68kpc_offset));
			m68kpc_offset += 4;
			break;
    case imm:
			switch (size){
			 case sz_byte:
					sprintf (buffer,"#$%02x", (unsigned int)(get_iword_1 (m68kpc_offset) & 0xff));
					m68kpc_offset += 2;
					break;
			 case sz_word:
					sprintf (buffer,"#$%04x", (unsigned int)(get_iword_1 (m68kpc_offset) & 0xffff));
					m68kpc_offset += 2;
					break;
			 case sz_long:
					sprintf (buffer,"#$%08lx", (long unsigned int)(get_ilong_1 (m68kpc_offset)));
					m68kpc_offset += 4;
					break;
			 default:
					break;
			}
		  break;
    case imm0:
			offset = (uae_s32)(uae_s8)get_iword_1 (m68kpc_offset);
			m68kpc_offset += 2;
			sprintf (buffer,"#$%02x", (unsigned int)(offset & 0xff));
			break;
    case imm1:
			offset = (uae_s32)(uae_s16)get_iword_1 (m68kpc_offset);
			m68kpc_offset += 2;
			sprintf (buffer,"#$%04x", (unsigned int)(offset & 0xffff));
			break;
    case imm2:
			offset = (uae_s32)get_ilong_1 (m68kpc_offset);
			m68kpc_offset += 4;
			sprintf (buffer,"#$%08lx", (long unsigned int)offset);
			break;
    case immi:
			offset = (uae_s32)(uae_s8)(reg & 0xff);
			sprintf (buffer,"#$%08lx", (long unsigned int)offset);
			break;
    default:
		  break;
  }
  if (buf == 0)
		printf ("%s", buffer);
  else
		strcat (buf, buffer);
  return offset;
}
#pragma optimize("",on)

static void m68k_verify (uaecptr addr, uaecptr *nextpc)
{
  uae_u32 opcode, val;
  struct instr *dp;

  opcode = get_iword_1(0);
  last_op_for_exception_3 = opcode;
  m68kpc_offset = 2;

  if (cpufunctbl[cft_map (opcode)] == op_illg_1) {
	  opcode = 0x4AFC;
  }
  dp = table68k + opcode;

	if (dp->suse) {
		if (!verify_ea (dp->sreg, (amodes)dp->smode, (wordsizes)dp->size, &val)) {
      Exception (3, 0);
      return;
		}
  }
  if (dp->duse) {
		if (!verify_ea (dp->dreg, (amodes)dp->dmode, (wordsizes)dp->size, &val)) {
      Exception (3, 0);
      return;
		}
  }
}

#pragma optimize("",off)
void m68k_disasm (uaecptr addr, uaecptr *nextpc, int cnt)
{
	uaecptr newpc = 0;
	m68kpc_offset = addr - m68k_getpc ();
	while (cnt-- > 0) {
		char instrname[20],*ccpt;
		int opwords;
		uae_u32 opcode;
		struct mnemolookup *lookup;
		struct instr *dp;
		printf ("%08lx: ", m68k_getpc () + m68kpc_offset);
		for (opwords = 0; opwords < 5; opwords++){
			printf ("%04x ", get_iword_1 (m68kpc_offset + opwords*2));
		}
		opcode = get_iword_1 (m68kpc_offset);
		m68kpc_offset += 2;
		if (cpufunctbl[cft_map (opcode)] == op_illg_1) {
			opcode = 0x4AFC;
		}
	  dp = table68k + opcode;
		for (lookup = lookuptab;lookup->mnemo != (instrmnem)dp->mnemo; lookup++)
      ;

		strcpy (instrname, lookup->name);
		ccpt = strstr (instrname, "cc");
		if (ccpt != 0) {
			strncpy (ccpt, ccnames[dp->cc], 2);
		}
	  printf ("%s", instrname);
		switch (dp->size){
			case sz_byte: printf (".B "); break;
			case sz_word: printf (".W "); break;
			case sz_long: printf (".L "); break;
			default: printf ("   "); break;
		}

		if (dp->suse) {
			newpc = m68k_getpc () + m68kpc_offset;
			newpc += ShowEA (dp->sreg, (amodes)dp->smode, (wordsizes)dp->size, 0);
		}
	  if (dp->suse && dp->duse)
      printf (",");
		if (dp->duse) {
      newpc = m68k_getpc () + m68kpc_offset;
      newpc += ShowEA (dp->dreg, (amodes)dp->dmode, (wordsizes)dp->size, 0);
		}
		if (ccpt != 0) {
      if (cctrue(dp->cc))
				printf (" == %08lx (TRUE)", newpc);
      else
				printf (" == %08lx (FALSE)", newpc);
		} else if ((opcode & 0xff00) == 0x6100) /* BSR */
      printf (" == %08lx", newpc);
		printf ("\n");
  }
  if (nextpc)
		*nextpc = m68k_getpc () + m68kpc_offset;
}

void m68k_dumpstate (uaecptr *nextpc)
{
	int i;
	for (i = 0; i < 8; i++){
	  printf ("D%d: %08lx ", i, m68k_dreg(regs, i));
		if ((i & 3) == 3) printf ("\n");
  }
  for (i = 0; i < 8; i++){
		printf ("A%d: %08lx ", i, m68k_areg(regs, i));
		if ((i & 3) == 3) printf ("\n");
  }
  if (regs.s == 0) regs.usp = m68k_areg(regs, 7);
  if (regs.s && regs.m) regs.msp = m68k_areg(regs, 7);
  if (regs.s && regs.m == 0) regs.isp = m68k_areg(regs, 7);
  printf ("USP=%08lx ISP=%08lx MSP=%08lx VBR=%08lx\n",
    regs.usp,regs.isp,regs.msp,regs.vbr);
  printf ("T=%d%d S=%d M=%d X=%d N=%d Z=%d V=%d C=%d IMASK=%d\n",
    regs.t1, regs.t0, regs.s, regs.m,
    GET_XFLG, GET_NFLG, GET_ZFLG, GET_VFLG, GET_CFLG, regs.intmask);
  for (i = 0; i < 8; i++){
	  printf ("FP%d: %g ", i, regs.fp[i]);
		if ((i & 3) == 3) printf ("\n");
  }
  printf ("N=%d Z=%d I=%d NAN=%d\n",
    (regs.fpsr & 0x8000000) != 0,
    (regs.fpsr & 0x4000000) != 0,
    (regs.fpsr & 0x2000000) != 0,
    (regs.fpsr & 0x1000000) != 0);

  m68k_disasm(m68k_getpc (), nextpc, 1);
  if (nextpc)
		printf ("next PC: %08lx\n", *nextpc);
}
#pragma optimize("",on)

#endif // #if 0

#if INSTR_HISTORY
#define MAX_IH 1024
static int ih_inx = 0;

static int ih_instr[MAX_IH];
static int ih_pc[MAX_IH];
static int ih_pc_p[MAX_IH];
static int _ecx_tmp;
#endif //INSTR_HISTORY

void dump_callback(void)
{
#if INSTR_HISTORY
	_asm mov _ecx_tmp, ecx
	ih_instr[ih_inx] = _ecx_tmp;
	ih_pc[ih_inx] = regs.pc;
	ih_pc_p[ih_inx] = (int)regs.pc_p;
	ih_inx++;
	ih_inx &= (MAX_IH-1);
#endif //INSTR_HISTORY

	/*
	uaecptr pc = m68k_getpc();
	if(pc >= 0x208EE516 && pc <= 0x208EE516 + 0x86) {
	// if(pc >= 0x208edcac && pc <= 0x208edcac + 0x118) {
	  uaecptr nextpc;
		m68k_dumpstate(&nextpc);
	}
	*/
}


// tester only. not inlined.

#if defined(X86_ASSEMBLY)
void _declspec(naked) REGPARAM2 x86_flag_testl( uint32 v )
{
	_asm {
		test ecx, ecx
		pushfd
		pop ecx
		mov dword ptr [regflags.cznv], ecx
		ret
	}
}
void _declspec(naked) REGPARAM2 x86_flag_testw( uint16 v )
{
	_asm {
		test cx, cx
		pushfd
		pop ecx
		mov	dword ptr [regflags.cznv], ecx
		ret
	}
}
void _declspec(naked) REGPARAM2 x86_flag_testb( uint8 v )
{
	_asm {
		test cl, cl
		pushfd
		pop ecx
		mov	dword ptr [regflags.cznv], ecx
		ret
	}
}
uint32 _declspec(naked) REGPARAM2 x86_flag_addl( uint32 s, uint32 d )
{
	_asm {
		add ecx, edx
		pushfd
		pop edx
		mov dword ptr [regflags.cznv], edx
		mov eax, ecx
		ret
	}
}
uint16 _declspec(naked) REGPARAM2 x86_flag_addw( uint16 s, uint16 d )
{
	_asm {
		add cx, dx
		pushfd
		pop edx
		mov dword ptr [regflags.cznv], edx
		mov eax, ecx
		ret
	}
}
uint8 _declspec(naked) REGPARAM2 x86_flag_addb( uint8 s, uint8 d )
{
	_asm {
		add cl, dl
		pushfd
		pop edx
		mov dword ptr [regflags.cznv], edx
		mov eax, ecx
		ret
	}
}
uint32 _declspec(naked) REGPARAM2 x86_flag_subl( uint32 s, uint32 d )
{
	_asm {
		sub edx, ecx
		pushfd
		pop ecx
		mov dword ptr [regflags.cznv], ecx
		mov eax, edx
		ret
	}
}
uint16 _declspec(naked) REGPARAM2 x86_flag_subw( uint16 s, uint16 d )
{
	_asm {
		sub dx, cx
		pushfd
		pop ecx
		mov dword ptr [regflags.cznv], ecx
		mov eax, edx
		ret
	}
}
uint8 _declspec(naked) REGPARAM2 x86_flag_subb( uint8 s, uint8 d )
{
	_asm {
		sub dl, cl
		pushfd
		pop ecx
		mov dword ptr [regflags.cznv], ecx
		mov eax, edx
		ret
	}
}
void _declspec(naked) REGPARAM2 x86_flag_cmpl( uint32 s, uint32 d )
{
	_asm {
		cmp edx, ecx
		pushfd
		pop ecx
		mov dword ptr [regflags.cznv], ecx
		ret
	}
}
void _declspec(naked) REGPARAM2 x86_flag_cmpw( uint16 s, uint16 d )
{
	_asm {
		cmp dx, cx
		pushfd
		pop ecx
		mov	dword ptr [regflags.cznv], ecx
		ret
	}
}
void _declspec(naked) REGPARAM2 x86_flag_cmpb( uint8 s, uint8 d )
{
	_asm {
		cmp dl, cl
		pushfd
		pop ecx
		mov	dword ptr [regflags.cznv], ecx
		ret
	}
}
#endif //X86_ASSEMBLY

} // extern "C"
