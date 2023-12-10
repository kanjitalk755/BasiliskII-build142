/*
 *  basilisk_glue.cpp - Glue UAE CPU to Basilisk II CPU engine interface
 *
 *  Basilisk II (C) 1997-1999 Christian Bauer
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
#include "cpu_emulation.h"
#include "main.h"
#include "emul_op.h"
#include "rom_patches.h"
#include "m68k.h"
#include "memory.h"
#include "readcpu.h"
#include "newcpu.h"
#include "compiler.h"


// RAM and ROM pointers
uint32 RAMBaseMac = 0;			// RAM base (Mac address space)
uint8 *RAMBaseHost = 0;			// RAM base (host address space)
uint32 RAMSize = 0;					// Size of RAM
uint32 ROMBaseMac = 0;			// ROM base (Mac address space)
uint8 *ROMBaseHost = 0;			// ROM base (host address space)
uint32 ROMSize = 0;					// Size of ROM

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
uint32 MacFrameBaseMac = 0;
#endif

#if !REAL_ADDRESSING
// Mac frame buffer
uint8 *MacFrameBaseHost = 0;	// Frame buffer base (host address space)
uint32 MacFrameSize = 0;			// Size of frame buffer
int MacFrameLayout = 0;				// Frame buffer layout
#endif

// From newcpu.cpp
extern "C" int quit_program;


/*
 *  Initialize 680x0 emulation, CheckROM() must have been called first
 */

bool Init680x0(void)
{
#if REAL_ADDRESSING
	// Mac address space = host address space
	RAMBaseMac = (uint32)RAMBaseHost;
	ROMBaseMac = (uint32)ROMBaseHost;
#else
	// Initialize UAE memory banks
	RAMBaseMac = 0;
	switch (ROMVersion) {
		case ROM_VERSION_64K:
		case ROM_VERSION_PLUS:
		case ROM_VERSION_CLASSIC:
			ROMBaseMac = 0x00400000;
			break;
		case ROM_VERSION_II:
			ROMBaseMac = 0x00a00000;
			break;
		case ROM_VERSION_32:
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
			ROMBaseMac = 0x20800000;
#else
			ROMBaseMac = 0x40800000;
#endif
			break;
		default:
			return false;
	}
	memory_init();
#endif

	init_m68k();
#ifdef USE_COMPILER
	compiler_init();
#endif
	return true;
}


/*
 *  Deinitialize 680x0 emulation
 */

void Exit680x0(void)
{
}


/*
 *  Reset and start 680x0 emulation (doesn't return)
 */

void Start680x0(void)
{
	m68k_reset();
	m68k_go(true);
}


/*
 *  Execute MacOS 68k trap
 *  r->a[7] and r->sr are unused!
 */

void Execute68kTrap(uint16 trap, struct M68kRegisters *r)
{
	int i;

	// Save old PC
	uaecptr oldpc = m68k_getpc();

	// Set registers
	for (i=0; i<8; i++)
		m68k_dreg(regs, i) = r->d[i];
	for (i=0; i<7; i++)
		m68k_areg(regs, i) = r->a[i];

	// Push trap and EXEC_RETURN on stack
	m68k_areg(regs, 7) -= 2;
	put_word(m68k_areg(regs, 7), M68K_EXEC_RETURN);
	m68k_areg(regs, 7) -= 2;
	put_word(m68k_areg(regs, 7), trap);

	// Execute trap
	m68k_setpc(m68k_areg(regs, 7));
	fill_prefetch_0();
	quit_program = 0;
	m68k_go(true);

	// Clean up stack
	m68k_areg(regs, 7) += 4;

	// Restore old PC
	m68k_setpc(oldpc);
	fill_prefetch_0();

	// Get registers
	for (i=0; i<8; i++)
		r->d[i] = m68k_dreg(regs, i);
	for (i=0; i<7; i++)
		r->a[i] = m68k_areg(regs, i);
	quit_program = 0;
}


/*
 *  Execute MacOS 68k trap (count == how many short words on stack)
 */

void Execute68kTrapStackBased(uint16 trap, struct M68kRegisters *r,int count)
{
	int i;

	// Save old PC
	uaecptr oldpc = m68k_getpc();

	// Set registers
	for (i=0; i<8; i++)
		m68k_dreg(regs, i) = r->d[i];
	for (i=0; i<7; i++)
		m68k_areg(regs, i) = r->a[i];

	m68k_areg(regs, 7) -= 4;
	uint32 a7 = m68k_areg(regs, 7);

	// Move parameters
	memmove( Mac2HostAddr(a7), Mac2HostAddr(a7+4), count*2 );
	/*
	for (i=0; i<count; i++) {
		put_word(a7 + i*2, get_word( a7 + i*2+4 ) );
	}
	*/

	// Inject trap and EXEC_RETURN on stack above the parameters
	put_word(a7+(count+1)*2, M68K_EXEC_RETURN);
	put_word(a7+count*2, trap);

	// Execute trap
	m68k_setpc(a7+count*2);
	fill_prefetch_0();
	quit_program = 0;
	m68k_go(true);

	// Move parameters
	memmove( Mac2HostAddr(a7+4), Mac2HostAddr(a7), count*2 );
	/*
	for (i=count-1; i>=0; i--) {
		put_word(a7 + i*2+4, get_word( a7 + i*2 ) );
	}
	*/

	// Clean up stack
	m68k_areg(regs, 7) += 4;

	// Restore old PC
	m68k_setpc(oldpc);
	fill_prefetch_0();

	// Get registers
	for (i=0; i<8; i++)
		r->d[i] = m68k_dreg(regs, i);
	for (i=0; i<7; i++)
		r->a[i] = m68k_areg(regs, i);
	quit_program = 0;
}


/*
 *  Execute 68k subroutine
 *  The executed routine must reside in UAE memory!
 *  r->a[7] and r->sr are unused!
 */

void Execute68k(uint32 addr, struct M68kRegisters *r)
{
	int i;

	// Save old PC
	uaecptr oldpc = m68k_getpc();

	// Set registers
	for (i=0; i<8; i++)
		m68k_dreg(regs, i) = r->d[i];
	for (i=0; i<7; i++)
		m68k_areg(regs, i) = r->a[i];

	// Push EXEC_RETURN and faked return address (points to EXEC_RETURN) on stack
	m68k_areg(regs, 7) -= 2;
	put_word(m68k_areg(regs, 7), M68K_EXEC_RETURN);
	m68k_areg(regs, 7) -= 4;
	put_long(m68k_areg(regs, 7), m68k_areg(regs, 7) + 4);

	// Execute routine
	m68k_setpc(addr);
	fill_prefetch_0();
	quit_program = 0;
	m68k_go(true);

	// Clean up stack
	m68k_areg(regs, 7) += 2;

	// Restore old PC
	m68k_setpc(oldpc);
	fill_prefetch_0();

	// Get registers
	for (i=0; i<8; i++)
		r->d[i] = m68k_dreg(regs, i);
	for (i=0; i<7; i++)
		r->a[i] = m68k_areg(regs, i);
	quit_program = 0;
}
