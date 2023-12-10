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

#include <basedef.h>
#include <vmm.h>
#include <ndis.h>
#include <vwin32.h>

#include "debug.h"
#include "packet.h"

#define WCHAR unsigned short
#include <winioctl.h>
#include "..\inc\ntddpack.h"

#pragma VxD_LOCKED_CODE_SEG
#pragma VxD_LOCKED_DATA_SEG

DWORD _stdcall MyPageLock(DWORD, DWORD);
void  _stdcall MyPageUnlock(DWORD, DWORD);


DWORD PacketWrite(
	POPEN_INSTANCE	Open,
	DWORD  			dwDDB,
	DWORD  			hDevice,
	PDIOCPARAMETERS	pDiocParms
)
{
	PNDIS_PACKET	pPacket;
	PNDIS_BUFFER 	pNdisBuffer;
	NDIS_STATUS		Status;

	TRACE_ENTER( "SendPacket" );

	PacketAllocatePacketBuffer( &Status, Open, &pPacket, pDiocParms, IOCTL_PROTOCOL_WRITE );
	if ( Status != NDIS_STATUS_SUCCESS ) return 0;

	NdisSend( &Status, Open->AdapterHandle, pPacket );
	if ( Status != NDIS_STATUS_PENDING )  {
		PacketSendComplete( Open, pPacket, Status );
	}

	TRACE_LEAVE( "SendPacket" );
	return(-1);		// This will make DeviceIOControl return ERROR_IO_PENDING
}


VOID NDIS_API PacketSendComplete(
	IN NDIS_HANDLE	ProtocolBindingContext,
	IN PNDIS_PACKET	pPacket,
	IN NDIS_STATUS	Status
)
{
	PNDIS_BUFFER 		pNdisBuffer;
	PPACKET_RESERVED	Reserved = (PPACKET_RESERVED) pPacket->ProtocolReserved;

	TRACE_ENTER( "SendComplete" );

	// free buffer descriptor
	NdisUnchainBufferAtFront( pPacket, &pNdisBuffer );

	if( pNdisBuffer ) NdisFreeBuffer( pNdisBuffer );

	// The internal member of overlapped structure contains
	// a pointer to the event structure that will be signalled,
	// resuming the execution of the waiting GetOverlappedResult
	// call.
	//
	VWIN32_DIOCCompletionRoutine( Reserved->lpoOverlapped->O_Internal );

	PacketPageUnlock( Reserved->lpBuffer, Reserved->cbBuffer );
	PacketPageUnlock( Reserved->lpcbBytesReturned, sizeof(DWORD) );
	PacketPageUnlock( Reserved->lpoOverlapped, sizeof(OVERLAPPED) );
	NdisReinitializePacket(pPacket);
	NdisFreePacket(pPacket);
	TRACE_LEAVE( "SendComplete" );
}
