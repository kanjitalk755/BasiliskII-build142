/*
 *  cpu_emulation.h - Definitions for Basilisk II CPU emulation module (UAE 0.8.8 version)
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

#ifndef CPU_EMULATION_H
#define CPU_EMULATION_H

#include "readcpu.h"
#include "memory.h"
#include "newcpu.h"

/*
 *  Memory system
 */

// RAM and ROM pointers (allocated and set by main_*.cpp)
extern uint32 RAMBaseMac;		// RAM base (Mac address space), does not include Low Mem when != 0
extern uint8 *RAMBaseHost;		// RAM base (host address space)
extern uint32 RAMSize;			// Size of RAM

extern uint32 ROMBaseMac;		// ROM base (Mac address space)
extern uint8 *ROMBaseHost;		// ROM base (host address space)
extern uint32 ROMSize;			// Size of ROM

#if !REAL_ADDRESSING
// If we are not using real addressing, the Mac frame buffer gets mapped to this location
// The memory must be allocated by VideoInit(). If multiple monitors are used, they must
// share the frame buffer
#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
// const uint32 MacFrameBaseMac = 0xf0000000;
extern uint32 MacFrameBaseMac;
#else
const uint32 MacFrameBaseMac = 0xa0000000;
#endif

extern uint8 *MacFrameBaseHost;	// Frame buffer base (host address space)
extern uint32 MacFrameSize;		// Size of frame buffer
extern int MacFrameLayout;		// Frame buffer layout (see defines below)
#endif

// Possible frame buffer layouts
enum {
	FLAYOUT_NONE,				// No frame buffer
	FLAYOUT_DIRECT,				// Frame buffer is in MacOS layout, no conversion needed
	FLAYOUT_HOST_555,			// 16 bit, RGB 555, host byte order
	FLAYOUT_HOST_565,			// 16 bit, RGB 565, host byte order
	FLAYOUT_HOST_888			// 32 bit, RGB 888, host byte order
};

// Mac memory access functions
#if REAL_ADDRESSING
static inline uint32 ReadMacInt32(uint32 addr) {return ntohl(*(uint32 *)addr);}
static inline uint32 ReadMacInt16(uint32 addr) {return ntohs(*(uint16 *)addr);}
static inline uint32 ReadMacInt8(uint32 addr) {return *(uint8 *)addr;}
static inline void WriteMacInt32(uint32 addr, uint32 l) {*(uint32 *)addr = htonl(l);}
static inline void WriteMacInt16(uint32 addr, uint32 w) {*(uint16 *)addr = htons(w);}
static inline void WriteMacInt8(uint32 addr, uint32 b) {*(uint8 *)addr = b;}
static inline uint8 *Mac2HostAddr(uint32 addr) {return (uint8 *)addr;}
#else
#include "memory.h"
static inline uint32 ReadMacInt32(uint32 addr) {return get_long(addr);}
static inline uint16 ReadMacInt16(uint32 addr) {return (uint16)get_word(addr);}
static inline uint8 ReadMacInt8(uint32 addr) {return (uint8)get_byte(addr);}
static inline void WriteMacInt32(uint32 addr, uint32 l) {put_long(addr, l);}
static inline void WriteMacInt16(uint32 addr, uint16 w) {put_word(addr, w);}
static inline void WriteMacInt8(uint32 addr, uint8 b) {put_byte(addr, b);}
static inline uint8 *Mac2HostAddr(uint32 addr) {return get_real_address(addr);}
#endif


/*
 *  680x0 emulation
 */

// Initialization
extern bool Init680x0(void);	// This routine may want to look at CPUType/FPUType to set up the apropriate emulation
extern void Exit680x0(void);

// 680x0 emulation functions
struct M68kRegisters;
extern void Start680x0(void);									// Reset and start 680x0
extern "C" void Execute68k(uint32 addr, M68kRegisters *r);		// Execute 68k code from EMUL_OP routine
extern "C" void Execute68kTrap(uint16 trap, M68kRegisters *r);	// Execute MacOS 68k trap from EMUL_OP routine
extern "C" void Execute68kTrapStackBased(uint16 trap, M68kRegisters *r,int count);	// Execute MacOS 68k trap from EMUL_OP routine

// Interrupt functions
void __inline__ TriggerInterrupt(void) // Trigger interrupt level 1 (InterruptFlag must be set first)
{
	REGS_SPCFLAGS_OR( SPCFLAG_INT );
}


#endif
