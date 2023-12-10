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
#include <vwin32.h>
#include <winerror.h>
#include <ndis.h>

#include "debug.h"
#include "packet.h"

#define WCHAR unsigned short
#include <winioctl.h>
#include "..\inc\ntddpack.h"

#pragma VxD_LOCKED_CODE_SEG
#pragma VxD_LOCKED_DATA_SEG


DWORD _stdcall MyPageLock(DWORD, DWORD);
void  _stdcall MyPageUnlock(DWORD, DWORD);

VOID PacketAllocatePacketBuffer(
	PNDIS_STATUS	pStatus,
	POPEN_INSTANCE	pOpen,
	PNDIS_PACKET	*lplpPacket,
	PDIOCPARAMETERS	pDiocParms,
	DWORD			FunctionCode )
{
	PNDIS_BUFFER		pNdisBuffer;
	PPACKET_RESERVED	pReserved;

	TRACE_ENTER( "PacketAllocatePacket" );

	//  Try to get a packet from our list of free ones
	NdisAllocatePacket( pStatus, lplpPacket, pOpen->PacketPool );

	if ( *pStatus != NDIS_STATUS_SUCCESS ) {
		IF_VERY_LOUD( "Read- No free packets" );
		*(DWORD *)(pDiocParms->lpcbBytesReturned) = 0;
		return;
	}

	// Initialize Reserved LIST_ELEMENT
	InitializeListHead( &(RESERVED(*lplpPacket)->ListElement) );
	pReserved = RESERVED(*lplpPacket);

	// Buffers used asynchronously must be page locked
	switch ( FunctionCode ) {
	case IOCTL_PROTOCOL_READ:
		pReserved->lpBuffer = (PVOID)PacketPageLock( (PVOID)pDiocParms->lpvOutBuffer, pDiocParms->cbOutBuffer );
		pReserved->cbBuffer = pDiocParms->cbOutBuffer;
		break;

	case IOCTL_PROTOCOL_WRITE:
		pReserved->lpBuffer = (PVOID)PacketPageLock( pDiocParms->lpvInBuffer, pDiocParms->cbInBuffer );
		pReserved->cbBuffer = pDiocParms->cbInBuffer;
		break;

	default:
		IF_TRACE_MSG( "Allocate- Invalid FunctionCode %x", FunctionCode );
		NdisReinitializePacket( *lplpPacket );
		NdisFreePacket( *lplpPacket );
		*(DWORD *)(pDiocParms->lpcbBytesReturned) = 0;
		*pStatus = NDIS_STATUS_NOT_ACCEPTED;
		return;
	}

	// Buffers used by pended I/O operations must be page locked
	pReserved->lpcbBytesReturned= (PVOID)PacketPageLock( (PVOID)pDiocParms->lpcbBytesReturned, sizeof(DWORD) );
	pReserved->lpoOverlapped = (PVOID)PacketPageLock( (PVOID)pDiocParms->lpoOverlapped, sizeof(OVERLAPPED) );

	pReserved->hDevice 				= pDiocParms->hDevice;
	pReserved->tagProcess			= pDiocParms->tagProcess;

	// Here we allocate a buffer descriptor for our page locked buffer given us by the
	// client application.
	NdisAllocateBuffer(	pStatus,
						&pNdisBuffer,
						pOpen->BufferPool,
						(PVOID)pReserved->lpBuffer,
						pDiocParms->cbOutBuffer );

	if ( *pStatus != NDIS_STATUS_SUCCESS ) {
		IF_TRACE( "Read- No free buffers" );
		NdisReinitializePacket(*lplpPacket);
		NdisFreePacket(*lplpPacket);
		*(DWORD *)(pDiocParms->lpcbBytesReturned) = 0;
		return;
	}

	// Attach buffer to Packet
	NdisChainBufferAtFront( *lplpPacket, pNdisBuffer );

#if DEBUG
	IF_PACKETDEBUG( PACKET_DEBUG_VERY_LOUD )
	{
		IF_TRACE_MSG( " lplpPacket : %lx", lplpPacket );
		IF_TRACE_MSG( "   lpPacket : %lx", *lplpPacket );
		IF_TRACE_MSG3( "pNdisBuffer : %lx  %lx  %lx", pNdisBuffer, (*lplpPacket)->Private.Head, (*lplpPacket)->Private.Tail );
		IF_TRACE_MSG( "   Reserved : %lx", pReserved );
		IF_TRACE_MSG4( "   lpBuffer : %lx  %lx  %lx  %lx", pReserved->lpBuffer, pNdisBuffer->VirtualAddress, pDiocParms->lpvOutBuffer, pDiocParms->lpvInBuffer );
		IF_TRACE_MSG3( "   cbBuffer : %lx  %lx  %lx", pReserved->cbBuffer, pDiocParms->cbOutBuffer, pDiocParms->cbInBuffer );
		IF_TRACE_MSG2( " lpcbBytes  : %lx  %lx", pReserved->lpcbBytesReturned, pDiocParms->lpcbBytesReturned );
		IF_TRACE_MSG2( " lpoOverlap : %lx  %lx", pReserved->lpoOverlapped, pDiocParms->lpoOverlapped );
		IF_TRACE_MSG2( "    hDevice : %lx  %lx", pReserved->hDevice, pDiocParms->hDevice );
		IF_TRACE_MSG2( " tagProcess : %lx  %lx", pReserved->tagProcess, pDiocParms->tagProcess );
	}
#endif

	PACKETASSERT( pReserved->lpBuffer );
	PACKETASSERT( pReserved->cbBuffer );
	PACKETASSERT( pReserved->lpcbBytesReturned );
	PACKETASSERT( pReserved->lpoOverlapped );
	PACKETASSERT( pReserved->hDevice == pDiocParms->hDevice );
	PACKETASSERT( pReserved->tagProcess == pDiocParms->tagProcess );
	PACKETASSERT( pNdisBuffer == (*lplpPacket)->Private.Head );
	PACKETASSERT( pNdisBuffer->VirtualAddress == pReserved->lpBuffer );

	TRACE_LEAVE( "PacketAllocatePacket" );
	return;
}


DWORD PacketRead(
	POPEN_INSTANCE	Open,
	DWORD  			dwDDB,
	DWORD  			hDevice,
	PDIOCPARAMETERS pDiocParms
)
{
	NDIS_STATUS		Status;
	PNDIS_PACKET	pPacket;

	TRACE_ENTER( "PacketRead" );

	//  See if the buffer is at least big enough to hold the ethernet header
	if ( pDiocParms->cbOutBuffer < ETHERNET_HEADER_LENGTH )  {
		// Need bigger buffer
		*(DWORD *)(pDiocParms->lpcbBytesReturned) = 0;

		IF_VERY_LOUD( "Read- Buffer too small" );
		TRACE_LEAVE( "ReadPacket" );

		return NDIS_STATUS_SUCCESS;
	}

	PacketAllocatePacketBuffer( &Status, Open, &pPacket, pDiocParms, IOCTL_PROTOCOL_READ );

	if ( Status == NDIS_STATUS_SUCCESS ) {
		//  Put this packet in a list of pending reads.
		//  The receive indication handler will attemp to remove packets
		//  from this list for use in transfer data calls

		PACKETASSERT( Open != NULL );
		PACKETASSERT( pPacket != NULL );

		NdisAcquireSpinLock( &Open->RcvQSpinLock );

		InsertTailList( &Open->RcvList, &RESERVED(pPacket)->ListElement );

		NdisReleaseSpinLock( &Open->RcvQSpinLock );

		IF_TRACE_MSG2( "RcvList Link : %lx  %lx", Open->RcvList.Blink, &RESERVED(pPacket)->ListElement );
		PACKETASSERT( Open->RcvList.Blink == &RESERVED(pPacket)->ListElement );
		PACKETASSERT( &(Open->RcvList) == RESERVED(pPacket)->ListElement.Flink );
	}

	TRACE_LEAVE( "PacketRead" );
	return(-1);		// This will make DeviceIOControl return ERROR_IO_PENDING
}


NDIS_STATUS NDIS_API PacketReceiveIndicate (
	IN NDIS_HANDLE ProtocolBindingContext,
	IN NDIS_HANDLE MacReceiveContext,
	IN PVOID       pvHeaderBuffer,
	IN UINT        uiHeaderBufferSize,
	IN PVOID       pvLookAheadBuffer,
	IN UINT        uiLookaheadBufferSize,
	IN UINT        uiPacketSize
)
#define pOpen	((POPEN_INSTANCE)ProtocolBindingContext)

{
	PLIST_ENTRY			PacketListEntry;
	PNDIS_PACKET   		pPacket;
	ULONG          		ulSizeToTransfer;
	NDIS_STATUS    		Status;
	UINT           		uiBytesTransferred;
	PPACKET_RESERVED	pReserved;
	PNDIS_BUFFER		pNdisBuffer;
	PVOID				pvActualVirtualAddress;
	UINT				uiActualLength;

	// we wait to print the trace to see if we even have a buffer
	PACKETASSERT( (pOpen != NULL) );

	//  See if there are any pending read that we can satisfy
	NdisAcquireSpinLock( &pOpen->RcvQSpinLock );
	PacketListEntry = PacketRemoveHeadList( &pOpen->RcvList );
	NdisReleaseSpinLock( &pOpen->RcvQSpinLock );

	if ( PacketListEntry == NULL ) return NDIS_STATUS_SUCCESS;

	TRACE_ENTER( "IndicateReceive" );

	pReserved = CONTAINING_RECORD( PacketListEntry, PACKET_RESERVED, ListElement );
	pPacket   = CONTAINING_RECORD( pReserved, NDIS_PACKET, ProtocolReserved );

#if DEBUG
	IF_PACKETDEBUG( PACKET_DEBUG_VERY_LOUD )
	{
		IF_TRACE_MSG( "   Reserved : %lx", pReserved );
		IF_TRACE_MSG( "    pPacket : %lx", pPacket );
		IF_TRACE_MSG2( "     Header : %lx  %lx", pvHeaderBuffer, uiHeaderBufferSize );
		IF_TRACE_MSG2( "  LookAhead : %lx  %lx", pvLookAheadBuffer, uiLookaheadBufferSize );
		IF_TRACE_MSG( " PacketSize : %lx", uiPacketSize );
	}
#endif

	PACKETASSERT( (pReserved != NULL) );
	PACKETASSERT( (pPacket != NULL) );

	uiBytesTransferred = 0;

	// Get pointer to private buffer
	pNdisBuffer = pPacket->Private.Head;

	// Save private buffer's start address
	pvActualVirtualAddress	= pNdisBuffer->VirtualAddress;
	uiActualLength			= pNdisBuffer->Length;

	// Copy header buffer into client buffer
	if ( uiHeaderBufferSize > 0 ) {
		if ( uiHeaderBufferSize > pNdisBuffer->Length ) {
			uiHeaderBufferSize = pNdisBuffer->Length;
		}

		NdisMoveMemory( pNdisBuffer->VirtualAddress, pvHeaderBuffer, uiHeaderBufferSize );

		uiBytesTransferred += uiHeaderBufferSize;

		// Advance the NDIS_BUFFER address to the end of the header
		(BYTE *)(pNdisBuffer->VirtualAddress) += uiHeaderBufferSize;

		pNdisBuffer->Length -= uiHeaderBufferSize;
	}

	// Copy look ahead buffer into client buffer
	if ( uiLookaheadBufferSize > 0 ) {
		if ( uiLookaheadBufferSize > pNdisBuffer->Length ) {
			uiLookaheadBufferSize = pNdisBuffer->Length;
		}

		NdisMoveMemory( pNdisBuffer->VirtualAddress, pvLookAheadBuffer, uiLookaheadBufferSize );

		uiBytesTransferred += uiLookaheadBufferSize;

		// Advance the NDIS_BUFFER address to the end of the Lookahead data
		(BYTE *)(pNdisBuffer->VirtualAddress) += uiLookaheadBufferSize;

		pNdisBuffer->Length -= uiLookaheadBufferSize;
	}


	// Save bytes transferred to client buffer so far
	*(pReserved->lpcbBytesReturned) = uiBytesTransferred;

	// Copy any remaining bytes in packet
	if ( uiLookaheadBufferSize < uiPacketSize ) {
		if ( uiPacketSize >= 1500 ) {
			_asm { int 3 }
		}

		ulSizeToTransfer = uiPacketSize - uiLookaheadBufferSize;

		if ( ulSizeToTransfer > pNdisBuffer->Length ) {
			ulSizeToTransfer = pNdisBuffer->Length;
		}

		//  Call the Mac to transfer the packet
		NdisTransferData(	&Status,					// ndis status
							pOpen->AdapterHandle,		// from NdisOpenAdapter
							MacReceiveContext,			// handle from NIC
							uiLookaheadBufferSize,		// offset from start of buffer
							ulSizeToTransfer,			// number of bytes to copy
							pPacket,					// packet descriptor pointer
							&uiBytesTransferred );		// number of bytes actually copied

		// Restore the private buffer's address pointer

		pNdisBuffer->VirtualAddress = pvActualVirtualAddress;
		pNdisBuffer->Length			= uiActualLength;

		if ( Status != NDIS_STATUS_PENDING ) {
			PacketTransferDataComplete(	pOpen,				// protocol context
										pPacket,			// packet descriptor pointer
										Status,				// ndis status
										uiBytesTransferred );// number of bytes actually copied
		}
	} else {
		// The entire packet was in the look ahead buffer

		Status = NDIS_STATUS_SUCCESS;

		// Restore the private buffer's address pointer

		pNdisBuffer->VirtualAddress = pvActualVirtualAddress;
		pNdisBuffer->Length			= uiActualLength;

		PacketTransferDataComplete(	pOpen,			// protocol context
									pPacket,		// packet descriptor pointer
									Status,			// ndis status
									0 );			// number of bytes copied by NdisTransferData
	}

	TRACE_LEAVE( "IndicateReceive" );

	return NDIS_STATUS_SUCCESS;
}


VOID NDIS_API PacketTransferDataComplete(
	IN NDIS_HANDLE ProtocolBindingContext,
	IN PNDIS_PACKET  pPacket,
	IN NDIS_STATUS   Status,
	IN UINT          uiBytesTransferred
)
{
	PPACKET_RESERVED	pReserved;
	OVERLAPPED*			pOverlap;
	PNDIS_BUFFER		pNdisBuffer;

	TRACE_ENTER( "TransferDataComplete" );

	pReserved = (PPACKET_RESERVED) pPacket->ProtocolReserved;
	pOverlap  = (OVERLAPPED *) pReserved->lpoOverlapped;

	PACKETASSERT( (pOpen != NULL) );
	PACKETASSERT( (pReserved != NULL) );
	PACKETASSERT( (pOverlap != NULL) );

#if DEBUG
	IF_PACKETDEBUG( PACKET_DEBUG_VERY_LOUD )
	{
		IF_TRACE_MSG( "     Status : %lx", Status );
		IF_TRACE_MSG( "BytesXfered : %lx", uiBytesTransferred );
		IF_TRACE_MSG( "Byte Offset : %lx", *(pReserved->lpcbBytesReturned) );
	}
#endif

	// free buffer descriptor
	NdisUnchainBufferAtFront( pPacket, &pNdisBuffer );
	PACKETASSERT( (pNdisBuffer != NULL) );
	if( pNdisBuffer ) NdisFreeBuffer( pNdisBuffer );

	*(pReserved->lpcbBytesReturned) += uiBytesTransferred;
	pOverlap->O_InternalHigh         = *(pReserved->lpcbBytesReturned);


	// The internal member of overlapped structure contains
	// a pointer to the event structure that will be signalled,
	// resuming the execution of the waitng GetOverlappedResult
	// call.

	VWIN32_DIOCCompletionRoutine( pOverlap->O_Internal );

	PacketPageUnlock( pReserved->lpBuffer, pReserved->cbBuffer );
	PacketPageUnlock( pReserved->lpcbBytesReturned, sizeof(DWORD) );
	PacketPageUnlock( pReserved->lpoOverlapped, sizeof(OVERLAPPED) );
	NdisReinitializePacket( pPacket );
	NdisFreePacket( pPacket );

	TRACE_LEAVE( "TransferDataComplete" );
}


VOID NDIS_API PacketReceiveComplete( IN NDIS_HANDLE  ProtocolBindingContext )
{
#if DEBUG
	IF_PACKETDEBUG( PACKET_DEBUG_VERY_LOUD )
	{
		TRACE_ENTER( "ReceiveComplete" );
		TRACE_LEAVE( "ReceiveComplete" );
	}
#endif
}
