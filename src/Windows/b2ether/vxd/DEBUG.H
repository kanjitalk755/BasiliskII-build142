/*
 *  b2ether driver -- derived from DDK packet driver sample
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

#if DEBUG

#define IF_PACKETDEBUG(f) if ( PacketTraceImpt & (f) )
extern ULONG PacketTraceImpt;

#define PACKET_TRACE_IMPT              0x00000001  // debugging info
#define PACKET_DEBUG_VERY_LOUD         0x00000002  // excessive debugging info
#define PACKET_DEBUG_INIT              0x00000100  // init debugging info
#define PACKET_DEBUG_BREAK					0x00000200  // hit breakpoint when debugging

//
// Macro for deciding whether to dump lots of debugging information.
//

#define IF_BREAK_SET 		IF_PACKETDEBUG( PACKET_DEBUG_BREAK ) DbgBreakPoint()
#define IF_INIT_TRACE(A)	IF_PACKETDEBUG( PACKET_DEBUG_INIT ) { DbgPrint("Packet: %s\r\n", A); DbgBreakPoint(); }
#define IF_TRACE(A) 			IF_PACKETDEBUG( PACKET_TRACE_IMPT ) { DbgPrint("Packet: %s\r\n", A); IF_BREAK_SET }
#define IF_VERY_LOUD(A) 	IF_PACKETDEBUG( PACKET_DEBUG_VERY_LOUD ) { DbgPrint("Packet: %s\r\n", A); IF_BREAK_SET }
#define IF_TRACE_MSG(A,B)	IF_PACKETDEBUG( PACKET_TRACE_IMPT ) { DbgPrint("Packet: "); DbgPrint(A,B); DbgPrint("\r\n"); IF_BREAK_SET }
#define IF_TRACE_MSG2(A,B,C)	IF_PACKETDEBUG( PACKET_TRACE_IMPT ) { DbgPrint("Packet: "); DbgPrint(A,B,C); DbgPrint("\r\n"); IF_BREAK_SET }
#define IF_TRACE_MSG3(A,B,C,D)	IF_PACKETDEBUG( PACKET_TRACE_IMPT ) { DbgPrint("Packet: "); DbgPrint(A,B,C,D); DbgPrint("\r\n"); IF_BREAK_SET }
#define IF_TRACE_MSG4(A,B,C,D,E)	IF_PACKETDEBUG( PACKET_TRACE_IMPT ) { DbgPrint("Packet: "); DbgPrint(A,B,C,D,E); DbgPrint("\r\n"); IF_BREAK_SET }

#define INIT_ENTER(A)		IF_PACKETDEBUG( PACKET_DEBUG_INIT ) { DbgPrint("==> Packet: %s\r\n", A); DbgBreakPoint(); }
#define INIT_LEAVE(A)		IF_PACKETDEBUG( PACKET_DEBUG_INIT ) { DbgPrint("<== Packet: %s\r\n", A); IF_BREAK_SET }
#define TRACE_ENTER(A)		IF_PACKETDEBUG( PACKET_TRACE_IMPT ) { DbgPrint("==> Packet: %s\r\n", A); IF_BREAK_SET }
#define TRACE_LEAVE(A)		IF_PACKETDEBUG( PACKET_TRACE_IMPT ) { DbgPrint("<== Packet: %s\r\n", A); IF_BREAK_SET }

#else

#define IF_BREAK_SET
#define IF_INIT_TRACE(A)
#define IF_TRACE(A)
#define IF_VERY_LOUD(A)
#define IF_TRACE_MSG(A,B)
#define IF_TRACE_MSG2(A,B,C)
#define IF_TRACE_MSG3(A,B,C,D)
#define IF_TRACE_MSG4(A,B,C,D,E)

#define INIT_ENTER(A)
#define INIT_LEAVE(A)
#define TRACE_ENTER(A)
#define TRACE_LEAVE(A)

#endif
