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


#pragma VxD_LOCKED_CODE_SEG
#pragma VxD_LOCKED_DATA_SEG


// The VxD Device Descriptor Block (DDB).  This is exported by the VxD
// and used by the system to obtain the pointer to the VxD Control proc.
//
struct VxD_Desc_Block PACKET_DDB =
{
    0,                                 // DDB_Next
    DDK_VERSION,                       // DDK_SDK_Version
    UNDEFINED_DEVICE_ID,               // DDB_Req_Device_Number
    3,                                 // DDB_Dev_Major_Version
    10,                                // DDB_Dev_Minor_Version
    0,                                 // DDB_Flags
    {'B','2','E','T','H','E','R',' '}, // DDB_Name
    PROTOCOL_INIT_ORDER,               // DDB_Init_Order
    (ULONG)PACKET_Control,             // DDB_Control_Proc
    0,                                 // DDB_V86_API_Proc
    0,                                 // DDB_PM_API_Proc
    0,                                 // DDB_V86_API_CSIP
    0,                                 // DDB_PM_API_CSIP
    0,                                 // DDB_Reference_Data
    0,                                 // DDB_Service_Table_Ptr
    0,                                 // DDB_Service_Table_Size
    0,                                 // DDB_Win32_Service_Table
    'Prev',                            // DDB_Prev
    0,                                 // DDB_Reserved0
    'Rsv1',                            // DDB_Reserved1
    'Rsv2',                            // DDB_Reserved2
    'Rsv3'                             // DDB_Reserved3
};


//********************************************************************
// PACKET_Control()
//
// Main entry point into our VxD
//
// Entry:
//      EAX = System Control message
//
//********************************************************************

VOID _declspec(naked) PACKET_Control (VOID)
{
	int msg;

  _asm	mov	msg, eax

	switch ( msg ) {
	case SYS_DYNAMIC_DEVICE_INIT:
	case DEVICE_INIT:


        jnz     VXDSAMP_Control_clc_exit
        jmp     VXDSAMP_Control_stc_exit
    not_SYS_DYNAMIC_DEVICE_INIT:

        cmp     eax, SYS_DYNAMIC_DEVICE_EXIT
        jnz     not_SYS_DYNAMIC_DEVICE_EXIT
        call    SysDynamicDeviceExit
        jmp     VXDSAMP_Control_clc_exit
    not_SYS_DYNAMIC_DEVICE_EXIT:

        cmp     eax, W32_DEVICEIOCONTROL
        jnz     not_W32_DEVICEIOCONTROL
        //      EAX = W32_DEVICEIOCONTROL
        //      EBX = DDB ptr
        //      ECX = dwIoControlCode
        //      EDX = hDevice
        //      ESI = pointer to a DIOCPARAMETERS struct
        push    esi
        push    ecx
        call    DeviceIOControl
    not_W32_DEVICEIOCONTROL:


    VXDSAMP_Control_clc_exit:
        clc
        ret

    VXDSAMP_Control_stc_exit:
        stc
        ret
    }
}

//********************************************************************
// SysDynamicDeviceInit()
//
// VxD is being loaded.  Register our protocol with NDIS wrapper.
//
//********************************************************************

BOOL _stdcall SysDynamicDeviceInit (VOID)
{
    DWORD       dwVersion;
    NDIS_STATUS Status;

    DbgPrintf("VXDSAMP: Dynamic Init\n");

    dwVersion = NdisGetVersion();
    if (0 == dwVersion) {
        DbgPrintf("VXDSAMP: NDIS not loaded\n");
        return FALSE;
    } else if (0x030A > dwVersion) {
        DbgPrintf("VXDSAMP: bad NDIS version\n");
        return FALSE;
    }

    //
    // Register our protocol with NDIS
    //
    NdisRegisterProtocol(
        &Status,
        &ProtocolHandle,
        &ProtocolCharacteristics,
        sizeof(ProtocolCharacteristics)
        );

    if (NDIS_STATUS_SUCCESS != Status) {
        DbgPrintf("VXDSAMP: failure NdisRegisterProtocol %08X\n", Status);
        return FALSE;
    }

    // Hook system broadcast messages so we know about DevNodes which
    // are removed.  If this was a real PnP protocol, NDIS wrapper would
    // take care of this by calling our UnbindAdapterHandler when an
    // adapter goes away (e.g. popping out a PCMCIA net adatper).
    //
    hSysBroadcastHook = SHELL_HookSystemBroadcast(
        SystemBroadcastHook,
        0,
        0
        );

    return TRUE;
}

//********************************************************************
// SysDynamicDeviceExit()
//
// VxD is being unloaded.  Deregister our protocol with NDIS wrapper.
//
//********************************************************************

VOID _stdcall SysDynamicDeviceExit (VOID)
{
    PPROTOCOL_ADAPTER_BLOCK pProtocolAdapterBlock;
    NDIS_STATUS             Status;

    DbgPrintf("VXDSAMP: Dynamic Exit\n");

    SHELL_UnhookSystemBroadcast(hSysBroadcastHook);

    // Make sure there are no open adapters which the app did not close
    // as the protocol deregister will fail if it is still bound to any
    // adapters.
    //
    pProtocolAdapterBlock = ProtocolAdapterBlockHead.pNext;
    while (pProtocolAdapterBlock) {
        DbgPrintf("VXDSAMP: adapter still open, closing it due to exit\n");

        // Attempt to close the adapter
        //
        NdisCloseAdapter(
            &Status,
            pProtocolAdapterBlock->NdisBindingHandle
            );

        if (NDIS_STATUS_PENDING == Status) {
            // XXXXX This code path not traversed yet
            //
            Wait_Semaphore(
                pProtocolAdapterBlock->vmmSemComplete,
                BLOCK_SVC_INTS
                );
            if (NDIS_STATUS_SUCCESS != pProtocolAdapterBlock->Status)
            {
                DbgPrintf("VXDSAMP: failure NdisCloseAdapter %08X\n",
                          pProtocolAdapterBlock->Status);
            }
        } else if (NDIS_STATUS_SUCCESS != Status) {
            DbgPrintf("VXDSAMP: failure NdisCloseAdapter %08X\n",
                      Status);
        }

        FreeProtocolAdapterBlock(pProtocolAdapterBlock);
        pProtocolAdapterBlock = ProtocolAdapterBlockHead.pNext;
    }

    //
    // Deregister our protocol with NDIS
    //
    NdisDeregisterProtocol(
        &Status,
        ProtocolHandle
        );

    if (NDIS_STATUS_SUCCESS != Status) {
        DbgPrintf("VXDSAMP: failure NdisDeregisterProtocol %08X\n", Status);
    }
}
