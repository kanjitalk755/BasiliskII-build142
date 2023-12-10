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


PDEVICE_EXTENSION GlobalDeviceExtension = 0;

ULONG mystrlen( BYTE *s )
{
	ULONG len = 0;

	while ( *s++ ) len++;
	return len;
}

void mystrcat( BYTE *a, BYTE *b )
{
	while(*a) a++;
	while(*b) *a++ = *b++;
	*a = 0;
}

int mytoupper( char ch )
{
	if(ch >= 'a' && ch <= 'z') {
		ch = ch - 'a' + 'A';
	}
	return(ch);
}

int mystrequal( char *a, char *b )
{
	ULONG i, len = mystrlen(a);

	if(mystrlen(b) != len) return(0);

	for(i=0; i<len; i++) {
		char ch1 = mytoupper(a[i]);
		char ch2 = mytoupper(b[i]);
		if(ch1 != ch2) return(0);
	}
	return(1);
}


NTSTATUS DriverEntry(
	IN PDRIVER_OBJECT	DriverObject,
	IN PUNICODE_STRING	RegistryPath
)
{
	NDIS_PROTOCOL_CHARACTERISTICS	ProtocolChar;

	//
	// Name MUST match string used by ndisdev.asm to declare the driver name; case counts.
	// This is necessary for binding to proceed properly.
	//
  NDIS_STRING							ProtoName = NDIS_STRING_CONST("B2ETHER");
  NDIS_HANDLE    					NdisProtocolHandle;
	NDIS_STATUS							Status;

	INIT_ENTER( "DriverEntry" );

  NdisAllocateMemory( (PVOID *)&GlobalDeviceExtension, sizeof( DEVICE_EXTENSION ), 0, -1 );

	if ( GlobalDeviceExtension != NULL ) {
		NdisZeroMemory( (UCHAR*)GlobalDeviceExtension, sizeof(DEVICE_EXTENSION) );
		NdisZeroMemory( (UCHAR*)&ProtocolChar, sizeof(NDIS_PROTOCOL_CHARACTERISTICS) );

   	ProtocolChar.MajorNdisVersion            = 0x03;
	  ProtocolChar.MinorNdisVersion            = 0x0A;
   	ProtocolChar.Reserved                    = 0;
	  ProtocolChar.OpenAdapterCompleteHandler  = PacketBindAdapterComplete;
   	ProtocolChar.CloseAdapterCompleteHandler = PacketUnbindAdapterComplete;
	  ProtocolChar.SendCompleteHandler         = PacketSendComplete;
   	ProtocolChar.TransferDataCompleteHandler = PacketTransferDataComplete;
	  ProtocolChar.ResetCompleteHandler        = PacketResetComplete;
   	ProtocolChar.RequestCompleteHandler      = PacketRequestComplete;
	  ProtocolChar.ReceiveHandler              = PacketReceiveIndicate;
   	ProtocolChar.ReceiveCompleteHandler      = PacketReceiveComplete;
	  ProtocolChar.StatusHandler               = PacketStatus;
   	ProtocolChar.StatusCompleteHandler       = PacketStatusComplete;
   	ProtocolChar.BindAdapterHandler	        = PacketBindAdapter;
   	ProtocolChar.UnbindAdapterHandler        = PacketUnbindAdapter;
   	ProtocolChar.UnloadProtocolHandler       = PacketUnload;
	  ProtocolChar.Name                        = ProtoName;

		NdisRegisterProtocol( &Status,
									 &GlobalDeviceExtension->NdisProtocolHandle,
									 &ProtocolChar,
									 sizeof(NDIS_PROTOCOL_CHARACTERISTICS) );

	  if (Status != NDIS_STATUS_SUCCESS) {
			NdisFreeMemory( GlobalDeviceExtension, sizeof( DEVICE_EXTENSION ) ,  0 );

   		IF_TRACE( "Failed to register protocol with NDIS" );
			INIT_LEAVE( "DriverEntry" );

			return Status;
   	}

		InitializeListHead( &GlobalDeviceExtension->OpenList );

		GlobalDeviceExtension->DriverObject = DriverObject;
		GlobalDeviceExtension->SelectedDriver = 0;

  	IF_TRACE( "protocol registered with NDIS" );
		INIT_LEAVE( "DriverEntry" );

		return Status;
	}

	IF_TRACE( "Memory Failure" );
	INIT_LEAVE( "DriverEntry" );

	return NDIS_STATUS_RESOURCES;
}


VOID NDIS_API PacketUnload()
{
	NDIS_STATUS		Status;

	TRACE_ENTER( "Unload" );

	if ( GlobalDeviceExtension ) {
	  NdisDeregisterProtocol( &Status, GlobalDeviceExtension->NdisProtocolHandle );
		if ( Status == NDIS_STATUS_SUCCESS ) {
			NdisFreeMemory( GlobalDeviceExtension, sizeof( DEVICE_EXTENSION ) ,  0 );
			GlobalDeviceExtension = 0;
		}
	}
	TRACE_LEAVE( "Unload" );
}


POPEN_INSTANCE GetSelectedAdapter( VOID )
{
	int i, selected_item = 0;
	PLIST_ENTRY		pEntry;
	POPEN_INSTANCE pOpen;
	PLIST_ENTRY	pHead = &(GlobalDeviceExtension->OpenList);

	selected_item = GlobalDeviceExtension->SelectedDriver;

	pEntry = GlobalDeviceExtension->OpenList.Flink;

	if(!IsListEmpty(pEntry)) {
		for(i=0; i<selected_item; i++) {
			if(IsListEmpty(pEntry)) {
				IF_TRACE_MSG( "Invalid selected driver index: %lu", (ULONG)selected_item );
				break;
			}
			pEntry = pEntry->Flink;
		}
		if(pEntry == pHead) pEntry = GlobalDeviceExtension->OpenList.Flink;
	}

	pOpen  = CONTAINING_RECORD( pEntry, OPEN_INSTANCE, ListElement );

	return pOpen;
}


DWORD PacketSelectByName(
	DWORD  					dwDDB,
  DWORD  					hDevice,
  PDIOCPARAMETERS	pDiocParms
)
{
	PLIST_ENTRY	pHead = &(GlobalDeviceExtension->OpenList);
	PLIST_ENTRY pEntry;
	DWORD			dwBytes = 0;
	BYTE *name;

  TRACE_ENTER( "PacketSelectByName" );

	GlobalDeviceExtension->SelectedDriver = 0;

	name = (BYTE*)pDiocParms->lpvInBuffer;

	for ( pEntry=pHead->Flink; pEntry != pHead; pEntry=pEntry->Flink ) {
		BYTE 	*lpzName;
		POPEN_INSTANCE pOpen = CONTAINING_RECORD( pEntry, OPEN_INSTANCE, ListElement );

		PWRAPPER_MAC_BLOCK			pWMBlock;
		PNDIS_MAC_CHARACTERISTICS	pNMChar;

		pWMBlock = ((PWRAPPER_OPEN_BLOCK)(pOpen->AdapterHandle))->MacHandle;
		pNMChar  = &pWMBlock->MacCharacteristics;
		lpzName  = pNMChar->Name.Buffer;

		if(mystrequal(lpzName,name)) {
			// Done, GlobalDeviceExtension->SelectedDriver is updated now.
			IF_TRACE_MSG( "     Selected adapter index %lu", GlobalDeviceExtension->SelectedDriver );
			break;
		}
		GlobalDeviceExtension->SelectedDriver++;
	}

	if(pEntry == pHead) GlobalDeviceExtension->SelectedDriver = 0;

	*(ULONG*)(pDiocParms->lpcbBytesReturned) = 0;

	TRACE_LEAVE( "PacketSelectByName" );

	return NDIS_STATUS_SUCCESS;
}


DWORD PacketGetMacNameList(
	DWORD  					dwDDB,
  DWORD  					hDevice,
  PDIOCPARAMETERS	pDiocParms
)
{
	PLIST_ENTRY	pHead = &(GlobalDeviceExtension->OpenList);
	PLIST_ENTRY pEntry;
	DWORD			dwBytes = 0;

  TRACE_ENTER( "GetMacNameList" );

	for ( pEntry=pHead->Flink; pEntry != pHead; pEntry=pEntry->Flink ) {
		BYTE 	*lpzName;
		ULONG	uLength;
		POPEN_INSTANCE pOpen = CONTAINING_RECORD( pEntry, OPEN_INSTANCE, ListElement );

		PWRAPPER_MAC_BLOCK			pWMBlock;
		PNDIS_MAC_CHARACTERISTICS	pNMChar;

		pWMBlock = ((PWRAPPER_OPEN_BLOCK)(pOpen->AdapterHandle))->MacHandle;
		pNMChar  = &pWMBlock->MacCharacteristics;
		lpzName  = pNMChar->Name.Buffer;
		uLength  = mystrlen( lpzName );

		IF_TRACE_MSG2( "     %s  %lu",  lpzName, uLength );

		if ( uLength < pDiocParms->cbOutBuffer - dwBytes - 1 ) {
			mystrcat( (BYTE*)(pDiocParms->lpvOutBuffer), lpzName );
			mystrcat( (BYTE*)(pDiocParms->lpvOutBuffer), "|" );
			dwBytes += (uLength + 1);
		} else {
			break;
		}
	}

	*(ULONG*)(pDiocParms->lpcbBytesReturned) = dwBytes;

	IF_TRACE_MSG( "     Bytes Returned: %lu", *(ULONG*)(pDiocParms->lpcbBytesReturned) );

	TRACE_LEAVE( "GetMacNameList" );

	return NDIS_STATUS_SUCCESS;
}

DWORD _stdcall PacketIOControl(
	DWORD  			dwService,
  DWORD  			dwDDB,
  DWORD  			hDevice,
  PDIOCPARAMETERS pDiocParms
)
{
   POPEN_INSTANCE    Open;
   NDIS_STATUS     	Status;

   TRACE_ENTER( "DeviceIoControl" );

//BUGBUG
//For now we utilize only the FIRST adapter bound to the protocol
   Open = GetSelectedAdapter();

   IF_TRACE_MSG3( "    Function code is %08lx  buff size=%08lx  %08lx",
						dwService,
						pDiocParms->cbInBuffer,
						pDiocParms->cbOutBuffer );

	switch ( dwService ) {
	case DIOC_OPEN:
		// Just return success,  This is required for Win95
		break;

	case DIOC_CLOSEHANDLE:
		// Make sure there are no pending i/o
		Status = NDIS_STATUS_SUCCESS;
		PacketCleanUp( &Status, GetSelectedAdapter() );
		break;

	case IOCTL_PROTOCOL_RESET:
		PacketReset( &Status, Open );
		break;

	case IOCTL_PROTOCOL_SET_OID:
	case IOCTL_PROTOCOL_QUERY_OID:
	// case IOCTL_PROTOCOL_STATISTICS:
		return PacketRequest( Open, dwService, dwDDB, hDevice, pDiocParms );

	case IOCTL_PROTOCOL_READ:
		return PacketRead( Open, dwDDB, hDevice, pDiocParms );

	case IOCTL_PROTOCOL_WRITE:
		return PacketWrite( Open, dwDDB, hDevice, pDiocParms );

	case IOCTL_PROTOCOL_MACNAME:
		PacketGetMacNameList( dwDDB, hDevice, pDiocParms );
		break;

	case IOCTL_PROTOCOL_SELECT_BY_NAME:
		PacketSelectByName( dwDDB, hDevice, pDiocParms );
		break;

	default:
		// Error, Unrecognized IOCTL
		*(DWORD *)(pDiocParms->lpcbBytesReturned) = 0;
		break;
	}

   TRACE_LEAVE( "DeviceIoControl" );

   return NDIS_STATUS_SUCCESS;
}


VOID PacketStatus(
	IN NDIS_HANDLE   ProtocolBindingContext,
	IN NDIS_STATUS   Status,
	IN PVOID         StatusBuffer,
	IN UINT          StatusBufferSize
)
{
   TRACE_ENTER( "Status Indication" );
   TRACE_LEAVE( "Status Indication" );
}


VOID NDIS_API PacketStatusComplete( IN NDIS_HANDLE  ProtocolBindingContext )
{
   TRACE_ENTER( "StatusIndicationComplete" );
   TRACE_LEAVE( "StatusIndicationComplete" );
}


PLIST_ENTRY PacketRemoveHeadList( IN PLIST_ENTRY pListHead )
{
	if ( !IsListEmpty( pListHead ) ) {
		PLIST_ENTRY pLE = RemoveHeadList( pListHead );
		return pLE;
	}
	return NULL;
}
