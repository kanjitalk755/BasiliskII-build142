/*
 *  scsi_windows.cpp - SCSI Manager for Win32
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

/*
		TODO: immediate bit handling.

		Now everything is synchronous
		what's scsi command 0x06? Iomega Zip uses that

		The following operation codes are vendor-specific: 02h, 05h, 06h, 09h, 0Ch,
		0Dh, 0Eh, 0Fh, 10h, 11h, 13h, 14h, 19h, 20h, 21h, 22h, 23h, 24h, 26h, 27h,
		29h, 2Ch, 2Dh and C0h through FFh.  All remaining operation codes for direct-
		access devices are reserved for future standardization.
 */

#include "sysdeps.h"
#include "windows.h"
#include <stddef.h>
#include <winioctl.h>
#include "wnaspi32.h"
#include "scsidefs.h"
#include "prefs.h"
#include "scsi.h"
#include "user_strings.h"
#include "main_windows.h"
#include "scsi_windows.h"
#include "main.h"

// This must be always on.
#define DEBUG 1
#undef OutputDebugString
#define OutputDebugString scsi_log_write
static void scsi_log_write( char *s );
#define SCSI_LOG_FILE_NAME "scsi.log"
#include "debug.h"


static bool m_use_aspi = true; // Always true. I never finished NT direct SCSI support.
static bool m_use_autosense = true;

static bool m_alloc_SCSI_buffer = true;

// HANDLE fileHandle = 0;

// Max reliable sense length under NT is 18.
#define B2_SENSE_LEN 18
// #define B2_SENSE_LEN SENSE_LEN

typedef struct _SCSI_PASS_THROUGH {
    USHORT Length;
    UCHAR ScsiStatus;
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
    UCHAR CdbLength;
    UCHAR SenseInfoLength;
    UCHAR DataIn;
    ULONG DataTransferLength;
    ULONG TimeOutValue;
    ULONG DataBufferOffset;
    ULONG SenseInfoOffset;
    UCHAR Cdb[16];
}SCSI_PASS_THROUGH, *PSCSI_PASS_THROUGH;

typedef struct _SCSI_PASS_THROUGH_DIRECT {
    USHORT Length;
    UCHAR ScsiStatus;
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
    UCHAR CdbLength;
    UCHAR SenseInfoLength;
    UCHAR DataIn;
    ULONG DataTransferLength;
    ULONG TimeOutValue;
    PVOID DataBuffer;
    ULONG SenseInfoOffset;
    UCHAR Cdb[16];
}SCSI_PASS_THROUGH_DIRECT, *PSCSI_PASS_THROUGH_DIRECT;

#define IOCTL_SCSI_BASE                 FILE_DEVICE_CONTROLLER
#define IOCTL_SCSI_PASS_THROUGH_DIRECT  CTL_CODE(IOCTL_SCSI_BASE, 0x0405, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define SCSI_IOCTL_DATA_OUT          0
#define SCSI_IOCTL_DATA_IN           1
#define SCSI_IOCTL_DATA_UNSPECIFIED  2

typedef struct _SCSI_PASS_THROUGH_WITH_BUFFERS {
	SCSI_PASS_THROUGH spt;
	ULONG             Filler;      // realign buffers to double word boundary
	UCHAR             ucSenseBuf[32];
	UCHAR             ucDataBuf[512];
} SCSI_PASS_THROUGH_WITH_BUFFERS, *PSCSI_PASS_THROUGH_WITH_BUFFERS;

typedef struct _SCSI_PASS_THROUGH_DIRECT_WITH_BUFFER {
	SCSI_PASS_THROUGH_DIRECT sptd;
	ULONG             Filler;      // realign buffer to double word boundary
	UCHAR             ucSenseBuf[32];
} SCSI_PASS_THROUGH_DIRECT_WITH_BUFFER, *PSCSI_PASS_THROUGH_DIRECT_WITH_BUFFER;

enum {
	DB_SCSI_NONE=0,
	DB_SCSI_NORMAL,
	DB_SCSI_LOUD
};

static int16 debug_scsi = DB_SCSI_NONE;

static HANDLE scsi_log_file = INVALID_HANDLE_VALUE;

static void scsi_log_open( char *path )
{
	if(debug_scsi == DB_SCSI_NONE) return;

	DeleteFile( path );
	scsi_log_file = CreateFile(
			path,
			GENERIC_READ|GENERIC_WRITE,
			FILE_SHARE_READ,
			NULL,
			CREATE_ALWAYS,
			// FILE_FLAG_WRITE_THROUGH|FILE_FLAG_NO_BUFFERING,
			FILE_FLAG_WRITE_THROUGH,
			NULL
	);
	if( scsi_log_file == INVALID_HANDLE_VALUE ) {
		ErrorAlert( "Could not create the SCSI log file." );
	}
}

static void scsi_log_close( void )
{
	if(debug_scsi == DB_SCSI_NONE) return;

	if( scsi_log_file != INVALID_HANDLE_VALUE ) {
		CloseHandle( scsi_log_file );
		scsi_log_file = INVALID_HANDLE_VALUE;
	}
}

static void scsi_log_write( char *s )
{
	DWORD bytes_written;

	// should have been checked already.
	if(debug_scsi == DB_SCSI_NONE) return;

	if( scsi_log_file != INVALID_HANDLE_VALUE ) {

		DWORD count = strlen(s);
		if (0 == WriteFile(scsi_log_file, s, count, &bytes_written, NULL) ||
				(int)bytes_written != count)
		{
			scsi_log_close();
			ErrorAlert( "SCSI log file write error (out of disk space?). Log closed." );
		} else {
			FlushFileBuffers( scsi_log_file );
		}
	}
}

#pragma pack(1)

#define SCSI_READ_DISC_INFORMATION  0x51
#define SCSI_READ_TRACK_INFORMATION 0x52
#define SCSI_CLOSE_TRACK_OR_SESSION 0x5B
#define SCSI_BLANK_DISC							0xA1
#define SCSI_SET_SPEED							0xBB

#define NEC_CDROM_TOC_SIZE          1022
#define SIZE_INQUIRYBUF							36

typedef struct {
	int haid, target, lun;
	DWORD max_transfer;
	HANDLE h;
	BOOL read_only;
	BYTE dev_type;
	DWORD sector_size;
	DWORD max_sector;
	BYTE autosense[256]; // only valid if m_use_autosense==true
	BOOL autosense_valid;
} aspi_id;

int all_scsi_count = 0;
char all_scsi_names[MAX_SCSI_NAMES][MAX_SCSI_NAME];
DWORD all_scsi_types[MAX_SCSI_NAMES];


// Max cmd size ... heh 12 would probably suffice
#define MAXCOMMAND 100
static int scsi_command_length = 0;
static BYTE scsi_command[MAXCOMMAND];

// This is the max buffer size
DWORD dwMaxTransfer;

// map Mac (target,lun) -> Windows (ha,target,lun)
// uses indices 1..6 as for now
static aspi_id fds[8*8];
static aspi_id *scsi_target = 0;

static BOOL is_aspi_available = false;
static BOOL is_direct_scsi_available = false;

static int buffer_size = 0;			// Size of data buffer
static BYTE *buffer = NULL;			// Pointer to data buffer


#define MOVESCSIDWORD(pdwSrc,pdwDst) \
{\
    ((PBYTE)(pdwDst))[0] = ((PBYTE)(pdwSrc))[3];\
    ((PBYTE)(pdwDst))[1] = ((PBYTE)(pdwSrc))[2];\
    ((PBYTE)(pdwDst))[2] = ((PBYTE)(pdwSrc))[1];\
    ((PBYTE)(pdwDst))[3] = ((PBYTE)(pdwSrc))[0];\
}

#define MOVESCSIWORD(pwSrc,pwDst) \
{\
    ((PBYTE)(pwDst))[0] = ((PBYTE)(pwSrc))[1];\
    ((PBYTE)(pwDst))[1] = ((PBYTE)(pwSrc))[0];\
}

BOOL       gbASPIBuffer = FALSE;           // TRUE if ASPI transfer buffer
ASPI32BUFF gab;                            // Pointer to transfer buffer
HINSTANCE  ghinstWNASPI32 = 0;             // Handle to ASPI library

#define ASPICALL _cdecl

typedef DWORD (ASPICALL *LPGETASPI32SUPPORTINFO)(VOID);
typedef DWORD (ASPICALL *LPSENDASPI32COMMAND)(LPSRB);
typedef BOOL (ASPICALL *LPGETASPI32BUFFER)(PASPI32BUFF);
typedef BOOL (ASPICALL *LPFREEASPI32BUFFER)(PASPI32BUFF);
typedef BOOL (ASPICALL *LPTRANSLATEASPI32ADDRESS)(PDWORD,PDWORD);

DWORD (ASPICALL *gpfnGetASPI32SupportInfo)( VOID );
DWORD (ASPICALL *gpfnSendASPI32Command)( LPSRB );
BOOL  (ASPICALL *gpfnGetASPI32Buffer)( PASPI32BUFF );
BOOL  (ASPICALL *gpfnFreeASPI32Buffer)( PASPI32BUFF );
// BOOL  (ASPICALL *gpfnTranslateASPI32Address)( PDWORD, PDWORD );

struct smap_type {
	char vendor_from[VENDOR_LEN+1];
	char product_from[PRODUCT_LEN+1];
	char vendor_to[VENDOR_LEN+1];
	char product_to[PRODUCT_LEN+1];
	int preferred_target_id;
	struct smap_type *next;
};

static struct smap_type *smaps = 0;
static struct smap_type *senable = 0;

static void cleanup_inquiry_name( char *name, int len )
{
  int  i;

  for( i = len; i--; ) {
    if( name[i] != 0 && name[i] != ' ' ) {
      break;
    }
    name[i] = 0;
  }
  name[len] = 0;
}

static void inquiry_2_name( LPBYTE lpInquiryBuf, LPSTR name, char separator )
{
  CHAR szVendor[VENDOR_LEN+1];
  CHAR szProduct[PRODUCT_LEN+1];

  memcpy( szVendor, lpInquiryBuf + 8, VENDOR_LEN );
	cleanup_inquiry_name( szVendor, VENDOR_LEN );

  memcpy( szProduct, lpInquiryBuf + 16, PRODUCT_LEN );
	cleanup_inquiry_name( szProduct, PRODUCT_LEN );

  wsprintf( name, "%s%c%s", szVendor, separator, szProduct );
}

VOID aspi_final( VOID )
{
  if( gab.AB_BufPointer ) {
    if( gbASPIBuffer ) {
      gpfnFreeASPI32Buffer( &gab );
    } else {
      VirtualFree( gab.AB_BufPointer, 0, MEM_RELEASE );
    }
		gab.AB_BufPointer = 0;
  }
	if(buffer) {
		VirtualFree( buffer, 0, MEM_RELEASE );
		buffer = 0;
		buffer_size = 0;
	}
  if( ghinstWNASPI32 ) {
    FreeLibrary( ghinstWNASPI32 );
		ghinstWNASPI32 = 0;
  }
}

void SCSI_set_buffer_alloc( bool alloc_buffer )
{
	m_alloc_SCSI_buffer = alloc_buffer;
}

static BOOL aspi_init( VOID )
{
  UINT                fuPrevErrorMode;
  DWORD               dwSupportInfo;
  DWORD               dwLastError;
  SRB_GetSetTimeouts  srbTimeouts;
  OSVERSIONINFO				osvi;

	gab.AB_BufPointer = 0;
	ghinstWNASPI32 = 0;

  osvi.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
  GetVersionEx( &osvi );
  if( osvi.dwPlatformId == VER_PLATFORM_WIN32s ) {
		ErrorAlert( "This program does not run under Win32s." );
    return( FALSE );
  }

  fuPrevErrorMode = SetErrorMode( SEM_NOOPENFILEERRORBOX );
  ghinstWNASPI32 = LoadLibrary( "WNASPI32" );
  dwLastError = GetLastError();
  SetErrorMode( fuPrevErrorMode );
  if( !ghinstWNASPI32 ) {
		char err[200];
		if( dwLastError == ERROR_MOD_NOT_FOUND ) {
			strcpy( err, "WNASPI32.DLL was not found. You need to install ASPI before you can use SCSI under Basilisk II." );
		} else {
			wsprintf( err, "Could not load ASPI layer, error code %d", dwLastError );
		}
		ErrorAlert( err );
    return( FALSE );
  }

  gpfnGetASPI32SupportInfo = (LPGETASPI32SUPPORTINFO)GetProcAddress( ghinstWNASPI32, "GetASPI32SupportInfo" );
  gpfnSendASPI32Command = (LPSENDASPI32COMMAND)GetProcAddress( ghinstWNASPI32, "SendASPI32Command" );
  gpfnGetASPI32Buffer = (LPGETASPI32BUFFER)GetProcAddress( ghinstWNASPI32, "GetASPI32Buffer" );
  gpfnFreeASPI32Buffer = (LPFREEASPI32BUFFER)GetProcAddress( ghinstWNASPI32, "FreeASPI32Buffer" );
  // gpfnTranslateASPI32Address = (LPTRANSLATEASPI32ADDRESS)GetProcAddress( ghinstWNASPI32, "TranslateASPI32Address" );

  if( !gpfnGetASPI32SupportInfo || !gpfnSendASPI32Command ) {
    FreeLibrary( ghinstWNASPI32 );
		ghinstWNASPI32 = 0;
		ErrorAlert( "Could not find required ASPI entry points." );
    return FALSE;
  }

  dwSupportInfo = gpfnGetASPI32SupportInfo();
  if( HIBYTE(LOWORD(dwSupportInfo)) != SS_COMP )
  {
    FreeLibrary( ghinstWNASPI32 );
		ghinstWNASPI32 = 0;
		ErrorAlert( "Error in loading ASPI library." );
    return FALSE;
  }

  if( HIBYTE(LOWORD(dwSupportInfo)) == SS_NO_ADAPTERS )
  {
    FreeLibrary( ghinstWNASPI32 );
		ghinstWNASPI32 = 0;
		ErrorAlert( "No ASPI adapters found. SCSI disabled." );
    return FALSE;
  }

  memset( &srbTimeouts, 0, sizeof(SRB_GetSetTimeouts) );
  srbTimeouts.SRB_Cmd = SC_GETSET_TIMEOUTS;
  srbTimeouts.SRB_HaId = 0xFF;
  srbTimeouts.SRB_Flags = SRB_DIR_OUT;
  srbTimeouts.SRB_Target = 0xFF;
  srbTimeouts.SRB_Lun = 0xFF;
  srbTimeouts.SRB_Timeout = 10*2; // timeout is in half seconds
  gpfnSendASPI32Command( &srbTimeouts );

  gbASPIBuffer = gpfnGetASPI32Buffer ? TRUE : FALSE;

	if( !m_alloc_SCSI_buffer ) {
    gbASPIBuffer = FALSE;
  } else if( gbASPIBuffer ) {
    gbASPIBuffer = FALSE;
    for( dwMaxTransfer = 524288lu; dwMaxTransfer > 65536lu; dwMaxTransfer >>= 1 ) {
      memset( &gab, 0, sizeof(ASPI32BUFF) );
      gab.AB_BufLen = dwMaxTransfer;
      gab.AB_ZeroFill = FALSE;
      gbASPIBuffer = gpfnGetASPI32Buffer( &gab );
      if( gbASPIBuffer ) break;
    }
  }

  if( !gbASPIBuffer ) {
    dwMaxTransfer = gab.AB_BufLen = 65536lu;
    gab.AB_BufPointer = (PBYTE)VirtualAlloc (
        NULL,
        gab.AB_BufLen,
        MEM_RESERVE|MEM_COMMIT,
        PAGE_READWRITE
    );
  }

  if( !gab.AB_BufPointer ) {
    FreeLibrary( ghinstWNASPI32 );
		ghinstWNASPI32 = 0;
		ErrorAlert( "Out of memory allocating transfer buffer." );
    return FALSE;
  }

  return( TRUE );
}

// TODO:
//   inspect "immediate" bit of some important scsi commands
//   and if set, do not wait on event, but set up a completion callback

static bool sync_exec_aspi(
	BYTE            byHaId,
	BYTE            byTarget,
  BYTE            byFlags,
  DWORD           dwBufferBytes,
  PBYTE           pbyBuffer,
  BYTE            byCDBBytes,
  PBYTE           pbyCDB,
	uint16					*stat,
	BOOL						silent,
	BYTE						*sense_out,
	DWORD						sense_out_max
)
{
  BOOL            bRetry = TRUE;
  DWORD           dwASPIStatus;
  HANDLE          heventExec;

	// May need larger sense area...? unbelievable
  // SRB_ExecSCSICmd srbExec;
	char sbuf[ sizeof(SRB_ExecSCSICmd) + 256 ];
  SRB_ExecSCSICmd *psrbExec = (SRB_ExecSCSICmd *)sbuf;


	if(debug_scsi != DB_SCSI_NONE) {
		D(bug("sync_exec (%d,%d), flags=%d, bytes=0x%X, cdb size=%d\n", (int)byHaId, (int)byTarget,(int)byFlags,(int)dwBufferBytes,(int)byCDBBytes));
	}

  memset( psrbExec, 0, sizeof(sbuf) );
  memcpy( psrbExec->CDBByte, pbyCDB, byCDBBytes );
  psrbExec->SRB_Cmd = SC_EXEC_SCSI_CMD;
  psrbExec->SRB_HaId = byHaId;
  psrbExec->SRB_Flags = byFlags;
  psrbExec->SRB_Target = byTarget;
  psrbExec->SRB_BufLen = dwBufferBytes;
  psrbExec->SRB_BufPointer = pbyBuffer;
  psrbExec->SRB_SenseLen = B2_SENSE_LEN;

  psrbExec->SRB_CDBLen = byCDBBytes;

	if(stat) *stat = STATUS_GOOD;

  RetryExec:
  {
    heventExec = CreateEvent( NULL, TRUE, FALSE, NULL );
    if( heventExec ) {
      psrbExec->SRB_Flags |= SRB_EVENT_NOTIFY;
      psrbExec->SRB_PostProc = (LPVOID)heventExec;
      dwASPIStatus = gpfnSendASPI32Command( (LPSRB)psrbExec );
      if( dwASPIStatus == SS_PENDING ) {
        WaitForSingleObject( heventExec, INFINITE );
      }
			// if(psrbExec->SRB_Status == SS_PENDING) psrbExec->SRB_Status = SS_COMP;
      CloseHandle( heventExec );
    } else {
			if(debug_scsi != DB_SCSI_NONE) D(bug("Can't create an event, waiting in a busy loop\n"));
      gpfnSendASPI32Command( (LPSRB)psrbExec );
      while( psrbExec->SRB_Status == SS_PENDING );
    }
  }

	if(stat) *stat = psrbExec->SRB_TargStat;

  if( psrbExec->SRB_Status == SS_COMP ) {
		memset( (void*)sense_out, 0, min(sense_out_max,B2_SENSE_LEN) );
		return TRUE;
	}

	if(debug_scsi != DB_SCSI_NONE) D(bug("SRB_Status=%d, SRB_TargStat=%d\n",(int)psrbExec->SRB_Status, (int)psrbExec->SRB_TargStat));

	if(m_use_autosense && sense_out && sense_out_max) {
		memcpy( (void*)sense_out, psrbExec->SenseArea, min(sense_out_max,B2_SENSE_LEN) );
	}

  // Retry on the first unit attention.  Anything else will generate an error dialog.
  if( bRetry &&
      (psrbExec->SRB_TargStat == STATUS_CHKCOND &&
      (psrbExec->SenseArea[2] & 0x0F) == KEY_UNITATT) )

  {
    bRetry = FALSE;
    goto RetryExec;
  } else {
		if(!silent) {
			char err[200];
			wsprintf( err, "SCSI io failure." );
			ErrorAlert( err );
		}
    return FALSE;
  }
}

/*
static bool sync_exec_direct(
	BYTE            byHaId,
	BYTE            byTarget,
  BYTE            byFlags,
  DWORD           dwBufferBytes,
  PBYTE           pbyBuffer,
  BYTE            byCDBBytes,
  PBYTE           pbyCDB,
	uint16					*stat,
	BOOL						silent,
	BYTE						*sense_out,
	DWORD						sense_out_max
)
{
  SCSI_PASS_THROUGH_DIRECT_WITH_BUFFER sptdwb;
  ULONG length, returned;
	BOOL status;

	if(debug_scsi != DB_SCSI_NONE) {
		D(bug("sync_exec (%d,%d), flags=%d, bytes=0x%X, cdb size=%d\n", (int)byHaId, (int)byTarget,(int)byFlags,(int)dwBufferBytes,(int)byCDBBytes));
	}

	memset( &sptdwb, 0, sizeof(SCSI_PASS_THROUGH_DIRECT_WITH_BUFFER) );

	sptdwb.sptd.Length = sizeof(SCSI_PASS_THROUGH_DIRECT);
	sptdwb.sptd.PathId = byHaId;
	sptdwb.sptd.TargetId = byTarget;
	sptdwb.sptd.Lun = 0;
	sptdwb.sptd.CdbLength = byCDBBytes;
	sptdwb.sptd.DataIn = (byFlags & SRB_DIR_IN) ? SCSI_IOCTL_DATA_IN : SCSI_IOCTL_DATA_OUT;
	sptdwb.sptd.SenseInfoLength = 24;
	sptdwb.sptd.DataTransferLength = dwBufferBytes;
	sptdwb.sptd.TimeOutValue = 2;
	sptdwb.sptd.DataBuffer = pbyBuffer;
	sptdwb.sptd.SenseInfoOffset =
		 offsetof(SCSI_PASS_THROUGH_DIRECT_WITH_BUFFER,ucSenseBuf);
	memcpy( &sptdwb.sptd.Cdb[0], pbyCDB, byCDBBytes );
	length = sizeof(SCSI_PASS_THROUGH_DIRECT_WITH_BUFFER);
	status = DeviceIoControl(fileHandle,
													 IOCTL_SCSI_PASS_THROUGH_DIRECT,
													 &sptdwb,
													 length,
													 &sptdwb,
													 length,
													 &returned,
													 FALSE);

	if(debug_scsi != DB_SCSI_NONE) {
		D(bug("sync_exec status=%d\n", (int)status));
	}

	return status ? true : false;
}
*/

static bool sync_exec(
	BYTE            byHaId,
	BYTE            byTarget,
  BYTE            byFlags,
  DWORD           dwBufferBytes,
  PBYTE           pbyBuffer,
  BYTE            byCDBBytes,
  PBYTE           pbyCDB,
	uint16					*stat,
	BOOL						silent,
	BYTE						*sense_out,
	DWORD						sense_out_max
)
{
	// if(m_use_aspi) {
		return( sync_exec_aspi(
				byHaId,
				byTarget,
				byFlags,
				dwBufferBytes,
				pbyBuffer,
				byCDBBytes,
				pbyCDB,
				stat,
				silent,
				sense_out,
				sense_out_max ) );
		/*
	} else {
		return( sync_exec_direct(
				byHaId,
				byTarget,
				byFlags,
				dwBufferBytes,
				pbyBuffer,
				byCDBBytes,
				pbyCDB,
				stat,
				silent,
				sense_out,
				sense_out_max ) );
	}
		*/
}

VOID aspi_rescan_bus( VOID )
{
  BYTE                    byHaId;
  BYTE                    byMaxHaId;
  DWORD                   dwASPIStatus;
  SRB_RescanPort          srbRescanPort;

  dwASPIStatus = gpfnGetASPI32SupportInfo();
  if( HIBYTE(LOWORD(dwASPIStatus)) == SS_COMP ) {
    byMaxHaId = LOBYTE(LOWORD(dwASPIStatus));
    for( byHaId = 0; byHaId < byMaxHaId; byHaId++ ) {
      memset( &srbRescanPort, 0, sizeof(SRB_RescanPort) );
      srbRescanPort.SRB_Cmd = SC_RESCAN_SCSI_BUS;
      srbRescanPort.SRB_HaId = byHaId;
      gpfnSendASPI32Command( (LPSRB)&srbRescanPort );
    }
  }
}

static void clear_map(void)
{
  BYTE byTarget, byLun;

	scsi_command_length = 0;
	memset( scsi_command, 0, MAXCOMMAND );

	for(byTarget=0; byTarget<8; byTarget++) {
		for(byLun=0; byLun<8; byLun++) {
			fds[byTarget * 8 + byLun].haid = -1;
			fds[byTarget * 8 + byLun].target = -1;
			fds[byTarget * 8 + byLun].lun = -1;
		}
	}
	scsi_target = &fds[0];
}

static void add_mapping( struct smap_type *pmap, struct smap_type **root )
{
	struct smap_type *newmap = (struct smap_type *)malloc( sizeof(struct smap_type) );
	if(newmap) {
		memcpy( newmap, pmap, sizeof(struct smap_type) );
		newmap->next = *root;
		*root = newmap;
	}
}

static void delete_mappings( void )
{
	struct smap_type *tmp;

	while(smaps) {
		tmp = smaps;
		smaps = smaps->next;
		free(tmp);
	}
	smaps = 0;
	while(senable) {
		tmp = senable;
		senable = senable->next;
		free(tmp);
	}
	senable = 0;
}


static bool get_token( const char *line, int index, char *str, int maxlen )
{
	int len, quotes = index * 2 + 1;
	char *end;

	for( int i=0; i<quotes; i++ ) {
		line = strchr(line,'\"');
		if(!line) return(false);
		line++;
	}
	end = strchr(line,'\"');
	if(!end) return(false);
	len = (uint32)end - (uint32)line;
	if(len > maxlen) return(false);
	memcpy( str, line, len );
	str[len] = 0;
	return(true);
}

static void read_scsi_mappings(void)
{
	int32 index;
	const char *str;
	struct smap_type map;
	char scsi_str[30];

	index = 0;
	while ((str = PrefsFindString("replacescsi", index++)) != NULL) {
		memset( &map, 0, sizeof(map) );
		if( get_token(str,0,map.vendor_from,VENDOR_LEN) &&
				get_token(str,1,map.product_from,PRODUCT_LEN) &&
				get_token(str,2,map.vendor_to,VENDOR_LEN) &&
				get_token(str,3,map.product_to,PRODUCT_LEN) )
		{
			add_mapping( &map, &smaps );
		}
	}

	for( index=0; index<=6; index++ ) {
		sprintf( scsi_str, "scsi%d", index );
		if((str = PrefsFindString(scsi_str, 0)) == NULL) break;
		memset( &map, 0, sizeof(map) );
		if( get_token(str,0,map.vendor_from,VENDOR_LEN) &&
				get_token(str,1,map.product_from,PRODUCT_LEN) )
		{
			map.preferred_target_id = index;
			add_mapping( &map, &senable );
		}
	}
}

static int get_taget_index( char *lpInquiryBuf )
{
	char vendor[VENDOR_LEN+1];
	char product[PRODUCT_LEN+1];
	struct smap_type *s = senable;

	char *vp = lpInquiryBuf + 8;
	char *pp = lpInquiryBuf + 16;

	memcpy( vendor, vp, VENDOR_LEN );
	memcpy( product, pp, PRODUCT_LEN );

	cleanup_inquiry_name( vendor, VENDOR_LEN );
	cleanup_inquiry_name( product, PRODUCT_LEN );

	while(s) {
		if(strcmp(vendor,s->vendor_from) == 0) {
			if(strcmp(product,s->product_from) == 0) {
				return(s->preferred_target_id);
			}
		}
		s = s->next;
	}

	return -1;
}

// Impersonate some devices
static void patch_inquiry( char *lpInquiryBuf )
{
	char vendor[VENDOR_LEN+1];
	char product[PRODUCT_LEN+1];
	struct smap_type *s = smaps;

	char *vp = lpInquiryBuf + 8;
	char *pp = lpInquiryBuf + 16;

	memcpy( vendor, vp, VENDOR_LEN );
	memcpy( product, pp, PRODUCT_LEN );

	cleanup_inquiry_name( vendor, VENDOR_LEN );
	cleanup_inquiry_name( product, PRODUCT_LEN );

	while(s) {
		if(strcmp(vendor,s->vendor_from) == 0) {
			if(strcmp(product,s->product_from) == 0) {
				memset(vp,' ',VENDOR_LEN);
				memset(pp,' ',PRODUCT_LEN);
				memcpy(vp,s->vendor_to,strlen(s->vendor_to));
				memcpy(pp,s->product_to,strlen(s->product_to));
				break;
			}
		}
		s = s->next;
	}
}

static bool is_disabled( char *lpInquiryBuf )
{
	char vendor[VENDOR_LEN+1];
	char product[PRODUCT_LEN+1];
	struct smap_type *s = senable;

	char *vp = lpInquiryBuf + 8;
	char *pp = lpInquiryBuf + 16;

	memcpy( vendor, vp, VENDOR_LEN );
	memcpy( product, pp, PRODUCT_LEN );

	cleanup_inquiry_name( vendor, VENDOR_LEN );
	cleanup_inquiry_name( product, PRODUCT_LEN );

	while(s) {
		if(strcmp(vendor,s->vendor_from) == 0) {
			if(strcmp(product,s->product_from) == 0) {
				return(false);
			}
		}
		s = s->next;
	}
	return(true);
}

/*
 *  Initialization
 */

void SCSIInit( void )
{
  DWORD						dwASPIStatus;
  BYTE            byHaId;
  BYTE            byMaxHaId;
  BYTE            byTarget;
  BYTE            byMaxTarget;
  SRB_HAInquiry   srbHAInquiry;
  SRB_GDEVBlock   srbGDEVBlock;
  BYTE            byInquiryCDB[6];
  BYTE            *byInquiryBuf, byInquiryBufBase[SIZE_INQUIRYBUF+50];
	DWORD						dwMaxTransferBytes;
	BOOL						bExec;
  BYTE						byCapacityCDB[10];
  BYTE						byCapacity[8];
	DWORD						dwMaxSector;
	DWORD						dwSectorSize;

	// SCSI disabled?
	if(PrefsFindBool("noscsi")) return;

	read_scsi_mappings();
	clear_map();

	debug_scsi = PrefsFindInt16("debugscsi");
	if(debug_scsi != DB_SCSI_NONE) {
		scsi_log_open( SCSI_LOG_FILE_NAME );
	}

	if(m_use_aspi) {
		is_aspi_available = aspi_init();
		is_direct_scsi_available = false;
	} else {
		// Not reached.
		is_aspi_available = false;
		/*
		is_direct_scsi_available = true;
    fileHandle = CreateFile("\\\\.\\J:",
       GENERIC_WRITE | GENERIC_READ,
       FILE_SHARE_READ,
       NULL,
       OPEN_EXISTING,
       0,
       NULL);
    if(fileHandle == INVALID_HANDLE_VALUE) {
			if(debug_scsi != DB_SCSI_NONE) D(bug("Failed to open Zip\n"));
			fileHandle = 0;
		} else {
			if(debug_scsi != DB_SCSI_NONE) D(bug("Zip test opened\n"));
			fds[next_index * 8 + 0].haid = 1; // byHaId;
			fds[next_index * 8 + 0].target = 0; // byTarget;
			fds[next_index * 8 + 0].lun = 0; // lun
			fds[next_index * 8 + 0].max_transfer = 65536lu;
			fds[next_index * 8 + 0].h = fileHandle;
			fds[next_index * 8 + 0].read_only = true;
			fds[next_index * 8 + 0].dev_type = DTYPE_DASD;
			fds[next_index * 8 + 0].sector_size = 0x200;
			fds[next_index * 8 + 0].max_sector = 0;
			next_index++;
		}
		*/
	}

	if(is_direct_scsi_available) {
		dwMaxTransfer = 65536lu;
		buffer_size = 65536lu;
    buffer = (PBYTE)VirtualAlloc ( NULL, buffer_size, MEM_RESERVE|MEM_COMMIT, PAGE_READWRITE );
		if (!buffer) {
			ErrorAlert(GetString(STR_NO_MEM_ERR));
			QuitEmulator();
		}
	} else if(is_aspi_available) {

		buffer_size = dwMaxTransfer;
    buffer = (PBYTE)VirtualAlloc ( NULL, buffer_size, MEM_RESERVE|MEM_COMMIT, PAGE_READWRITE );
		if (!buffer) {
			ErrorAlert(GetString(STR_NO_MEM_ERR));
			QuitEmulator();
		}

		// aspi_rescan_bus();

		byInquiryBuf = (BYTE *)(((DWORD)byInquiryBufBase + 3) & 0xFFFFFFFC);

		dwASPIStatus = gpfnGetASPI32SupportInfo();
		if( HIBYTE(LOWORD(dwASPIStatus)) == SS_COMP ) {
			byMaxHaId = LOBYTE(LOWORD(dwASPIStatus));
			for( byHaId = 0; byHaId < byMaxHaId; byHaId++ ) {
				memset( &srbHAInquiry, 0, sizeof(SRB_HAInquiry) );
				srbHAInquiry.SRB_Cmd = SC_HA_INQUIRY;
				srbHAInquiry.SRB_HaId = byHaId;
				gpfnSendASPI32Command( (LPSRB)&srbHAInquiry );
				if( srbHAInquiry.SRB_Status != SS_COMP ) continue;
				byMaxTarget = srbHAInquiry.HA_Unique[3];
				if( byMaxTarget != 8 && byMaxTarget != 16 ) byMaxTarget = 8;
				for( byTarget = 0; byTarget < byMaxTarget; byTarget++ ) {
					memset( &srbGDEVBlock, 0, sizeof(SRB_GDEVBlock) );
					srbGDEVBlock.SRB_Cmd = SC_GET_DEV_TYPE;
					srbGDEVBlock.SRB_HaId = byHaId;
					srbGDEVBlock.SRB_Target = byTarget;
					gpfnSendASPI32Command( (LPSRB)&srbGDEVBlock );
          if( srbGDEVBlock.SRB_Status != SS_COMP ) continue;

	        dwMaxTransferBytes = *(PDWORD)&srbHAInquiry.HA_Unique[4];
					if( dwMaxTransferBytes > gab.AB_BufLen ) dwMaxTransferBytes = gab.AB_BufLen;
					if( dwMaxTransferBytes < 65536lu ) dwMaxTransferBytes = 65536lu;

					// New; as recommended by ASPI dev kit:
					dwMaxTransferBytes = 65536lu;


					memset( byCapacityCDB, 0, 10 );
					byCapacityCDB[0] = SCSI_RD_CAPAC;

					bExec = sync_exec(
							byHaId, byTarget, SRB_DIR_IN,
							8, byCapacity,
							10, byCapacityCDB,
							NULL,
							TRUE,
							0, 0
					);

					if(bExec) {
						MOVESCSIDWORD( &byCapacity[0], &dwMaxSector );
						MOVESCSIDWORD( &byCapacity[4], &dwSectorSize );
					} else {
						dwMaxSector = 0;
						dwSectorSize = 0;
						switch(srbGDEVBlock.SRB_DeviceType) {
							// make an educated guess.
							case DTYPE_DASD:
								dwSectorSize = 0x200;
								break;
							case DTYPE_WORM:
							case DTYPE_CDROM:
								dwSectorSize = 0x800;
								break;
						}
					}


					memset( byInquiryCDB, 0, 6 );
					byInquiryCDB[0] = (BYTE)SCSI_INQUIRY;
					byInquiryCDB[4] = (BYTE)SIZE_INQUIRYBUF;
					bExec = sync_exec(
							byHaId, byTarget, SRB_DIR_IN,
							SIZE_INQUIRYBUF, byInquiryBuf,
							6, byInquiryCDB,
							NULL,
							TRUE,
							0, 0
					);

					if( bExec ) {
						char name[100];
						inquiry_2_name( byInquiryBuf, name, ' ' );

						if(debug_scsi != DB_SCSI_NONE) D(bug("SCSI device found: %s\n",name));
						if(!*name) {
							if(debug_scsi != DB_SCSI_NONE) D(bug(" -- disabled (no name, something is wrong).\n"));
						} else {
							if(all_scsi_count < MAX_SCSI_NAMES ) {
								inquiry_2_name( byInquiryBuf, name, '|' );
								strcpy( all_scsi_names[all_scsi_count], name );
								all_scsi_types[all_scsi_count] = srbGDEVBlock.SRB_DeviceType;
								all_scsi_count++;
							}
							if(is_disabled( (char*)byInquiryBuf )) {
								if(debug_scsi != DB_SCSI_NONE) D(bug(" -- disabled by user.\n"));
							} else {
								// take only first lun now.
								int index = get_taget_index( (char*)byInquiryBuf );
								if(index >= 0) {
									fds[index * 8 + 0].haid = byHaId;
									fds[index * 8 + 0].target = byTarget;
									fds[index * 8 + 0].lun = 0;
									fds[index * 8 + 0].max_transfer = dwMaxTransferBytes;
									fds[index * 8 + 0].dev_type = srbGDEVBlock.SRB_DeviceType;
									fds[index * 8 + 0].sector_size = dwSectorSize;
									fds[index * 8 + 0].max_sector = dwMaxSector;
								} else {
									if(debug_scsi != DB_SCSI_NONE) D(bug(" -- no room.\n"));
								}
							}
						}
					}
				}
			}
		}
	} // if is_aspi_available

	// Reset SCSI bus
	SCSIReset();
}


/*
 *  Deinitialization
 */

void SCSIExit(void)
{
	if(is_aspi_available) {
		aspi_final();
		is_aspi_available = false;
	}
	/*
	if(is_direct_scsi_available) {
		if(fileHandle) {
			CloseHandle(fileHandle);
			fileHandle = 0;
		}
	}
	*/
	clear_map();
	delete_mappings();
	scsi_log_close();
}


/*
 *  Set SCSI command to be sent by scsi_send_cmd()
 */

void scsi_set_cmd(int cmd_length, uint8 *cmd)
{
	if(is_aspi_available || is_direct_scsi_available) {
		scsi_command_length = cmd_length;
		memcpy( scsi_command, cmd, min(cmd_length,MAXCOMMAND));
		if(cmd_length > MAXCOMMAND) {
			char str[256];
			wsprintf(str, "Too long SCSI command (%d)", cmd_length);
			ErrorAlert(str);
		}
	}
}


/*
 *  Check for presence of SCSI target
 */

bool scsi_is_target_present(int id)
{
	if(is_aspi_available || is_direct_scsi_available) {
		// check first lun
		return fds[id * 8].haid >= 0;
	} else {
		return false;
	}
}


/*
 *  Set SCSI target (returns false on error)
 */

bool scsi_set_target(int id, int lun)
{
	if(is_aspi_available || is_direct_scsi_available) {
		if (fds[id * 8 + lun].haid < 0)
			return false;
		scsi_target = &fds[id * 8 + lun];
		return true;
	}
  return false;
}

static void get_scsi_command_name( BYTE c, char *cmd_name )
{
	switch(c) {
		case SCSI_INQUIRY:
			strcpy( cmd_name, "SCSI_INQUIRY" ); break;
    case SCSI_READ6:
      strcpy( cmd_name, "SCSI_READ6" ); break;
    case SCSI_REQ_SENSE:
      strcpy( cmd_name, "SCSI_REQ_SENSE" ); break;
    case SCSI_TST_U_RDY:
      strcpy( cmd_name, "SCSI_TST_U_RDY" ); break;
    case SCSI_FORMAT:
      strcpy( cmd_name, "SCSI_FORMAT" ); break;
    case SCSI_READ10:
      strcpy( cmd_name, "SCSI_READ10" ); break;
    case SCSI_RD_CAPAC:
      strcpy( cmd_name, "SCSI_RD_CAPAC" ); break;
    case SCSI_RELEASE:
      strcpy( cmd_name, "SCSI_RELEASE" ); break;
    case SCSI_SEND_DIAG:
      strcpy( cmd_name, "SCSI_SEND_DIAG" ); break;
    case SCSI_WRITE6:
      strcpy( cmd_name, "SCSI_WRITE6" ); break;
    case SCSI_WRITE10:
      strcpy( cmd_name, "SCSI_WRITE10" ); break;

    case SCSI_START_STP:
      strcpy( cmd_name, "SCSI_START_STP" ); break;
    case SCSI_SYNC_CACHE:
      strcpy( cmd_name, "SCSI_SYNC_CACHE" ); break;
    case SCSI_VERIFY:
      strcpy( cmd_name, "SCSI_VERIFY" ); break;
    case SCSI_MODE_SEL6:
      strcpy( cmd_name, "SCSI_MODE_SEL6" ); break;
    case SCSI_MODE_SEN6:
      strcpy( cmd_name, "SCSI_MODE_SEN6" ); break;
    case SCSI_MODE_SEL10:
      strcpy( cmd_name, "SCSI_MODE_SEL10" ); break;
    case SCSI_MODE_SEN10:
      strcpy( cmd_name, "SCSI_MODE_SEN10" ); break;
    case SCSI_MED_REMOVL:
      strcpy( cmd_name, "SCSI_MED_REMOVL" ); break;

    case SCSI_ERASE:
      strcpy( cmd_name, "SCSI_ERASE" ); break;
    case SCSI_RD_BLK_LIM:
      strcpy( cmd_name, "SCSI_RD_BLK_LIM" ); break;
    case SCSI_RESERVE:
      strcpy( cmd_name, "SCSI_RESERVE" ); break;
    case SCSI_REWIND:
      strcpy( cmd_name, "SCSI_REWIND" ); break;
    case SCSI_SPACE:
      strcpy( cmd_name, "SCSI_SPACE" ); break;
    case SCSI_WRT_FILE:
      strcpy( cmd_name, "SCSI_WRT_FILE" ); break;

    case SCSI_SETWINDOW:
      strcpy( cmd_name, "SCSI_SETWINDOW" ); break;

    case SCSI_READ_TOC:
      strcpy( cmd_name, "SCSI_READ_TOC" ); break;
    case SCSI_READ_DISC_INFORMATION:
      strcpy( cmd_name, "SCSI_READ_DISC_INFORMATION" ); break;
    case SCSI_READ_TRACK_INFORMATION:
      strcpy( cmd_name, "SCSI_READ_TRACK_INFORMATION" ); break;
    case SCSI_CLOSE_TRACK_OR_SESSION:
      strcpy( cmd_name, "SCSI_CLOSE_TRACK_OR_SESSION" ); break;
    case SCSI_SET_SPEED:
      strcpy( cmd_name, "SCSI_SET_SPEED" ); break;
    case SCSI_BLANK_DISC:
      strcpy( cmd_name, "SCSI_BLANK_DISC" ); break;
		default:
			strcpy( cmd_name, "command" );
	}
}

static void dbout_scsi_data( size_t data_length, unsigned char *buffer )
{
	size_t j;
	char *msg, m2[20];

	if(data_length > 512) data_length = 512;

	msg = (char *)malloc(2048);
	if(msg) {
		strcpy( msg, "\"" );
		for( j=0; j<data_length; j++ ) {
			unsigned char ch = buffer[j];
			if(!isprint(ch)) ch = '.';
			wsprintf( m2, "%c", ch );
			strcat( msg, m2 );
		}
		strcat( msg, "\"\n" );
		OutputDebugString(msg);

		*msg = 0;
		for( j=0; j<data_length; j++ ) {
			wsprintf( m2, "%02X ", (int)buffer[j] );
			strcat( msg, m2 );
		}
		strcat( msg, "\n" );
		OutputDebugString(msg);


		free(msg);
	}
}

static void dbout_scsi_req(size_t data_length, bool reading, int sg_size, uint32 *sg_len)
{
	char msg[512], m2[20], cmd_name[100];
	int j;

	get_scsi_command_name( scsi_command[0], cmd_name );
	wsprintf(
		msg,
		"%s %Xh bytes in %d s/g areas, host=(%d,%d,%d), %s[%d] = ",
		reading ? "reading" : "writing",
		(int)data_length,
		(int)sg_size,
		(int)scsi_target->haid,
		(int)scsi_target->target,
		(int)scsi_target->lun,
		cmd_name,
		(int)scsi_command_length
	);
	for( j=0; j<scsi_command_length; j++ ) {
		wsprintf( m2, "%02X ", (int)scsi_command[j] );
		strcat( msg, m2 );
	}
	strcat( msg, "\n" );
	OutputDebugString(msg);

	size_t data_length_verify = 0;
	for(j=0; j<sg_size; j++) {
		data_length_verify += sg_len[j];
	}
	if(data_length_verify != data_length) {
		wsprintf( msg, "data length mismatch: %02X != %02X\n", (int)data_length, (int)data_length_verify );
		OutputDebugString(msg);
	}
}

/*
 *  Check if requested data size fits into buffer, allocate new buffer if needed
 */

static bool try_buffer(int size)
{
	if (size <= buffer_size)
		return true;

  BYTE *new_buffer = (PBYTE)VirtualAlloc ( NULL, size, MEM_RESERVE|MEM_COMMIT, PAGE_READWRITE );
	if (new_buffer == NULL)
		return false;
  if(buffer) VirtualFree( buffer, 0, MEM_RELEASE );
	buffer = new_buffer;
	buffer_size = size;
	return true;
}

// Splitting ASSUMES that it's a READ6, WRITE6, READ10 or WRITE10
// with LBA @ index 2, len @ index 7.
// It is caller's responsibility to check this.

// split transfer. does some extra moving, but the mac requests
// are sometimes larger than aspi can handle
static bool sync_exec_split(
	BYTE            byHaId,
	BYTE            byTarget,
  BYTE            byFlags,
  DWORD           dwBufferBytes,
  PBYTE           pbyBuffer,
  BYTE            byCDBBytes,
  PBYTE           pbyCDB,
	uint16					*stat,
	BOOL						silent,
	DWORD						max_transfer,
	BYTE						*sense_out,
	DWORD						sense_out_max
)
{
	bool retval = false;
	bool multi = false;
	uint32 block_size, block, n_blocks, bytes, bytes_left = dwBufferBytes;
	uint32 device_block_size, lba;
	uint16 device_blocks;

	// Assert
	if(byCDBBytes != 6 && byCDBBytes != 10) {
		if(debug_scsi != DB_SCSI_NONE) D(bug("Illegal cdb size %d\n", (int)byCDBBytes));
		return false;
	}

	block_size = min(max_transfer,dwMaxTransfer);

	n_blocks = (dwBufferBytes + block_size - 1) / block_size;
	if(n_blocks == 0) n_blocks = 1;

	if(n_blocks > 1) {
		multi = true;
		if(byCDBBytes == 10) {
			MOVESCSIDWORD( &pbyCDB[2], &lba );
			MOVESCSIWORD( &pbyCDB[7], &device_blocks );
		} else {
			MOVESCSIDWORD( &pbyCDB[0], &lba );
			lba &= 0x001FFFFF;
			device_blocks = pbyCDB[4];
			if(device_blocks == 0) device_blocks = 256;
		}
		device_block_size = dwBufferBytes / device_blocks;
		if(debug_scsi != DB_SCSI_NONE) D(bug("i/o: lba=%d, blocks=%d, block size=%d\n\n",(int)lba, (int)device_blocks, (int)device_block_size));

		if(scsi_target->sector_size && (scsi_target->sector_size != device_block_size)) {
			if(debug_scsi != DB_SCSI_NONE) D(bug("Device block size mismatch: (%d,%d)\n\n",(int)scsi_target->sector_size, (int)device_block_size));
			device_block_size = scsi_target->sector_size;
		}
	}

	for( block=0; block<n_blocks; block++ ) {
		bytes = min(block_size, bytes_left);
		if(byFlags & SRB_DIR_OUT) {
			if(bytes) memcpy( gab.AB_BufPointer, pbyBuffer, bytes );
		}
		if(multi) {
			device_blocks = (uint16)(bytes / device_block_size);
			if(debug_scsi != DB_SCSI_NONE) D(bug("i/o block %d of %d, lba=%d, blocks=%d\n\n",(int)block+1, (int)n_blocks, (int)lba, (int)device_blocks));
			if(byCDBBytes == 10) {
				MOVESCSIDWORD( &lba, &pbyCDB[2] );
				MOVESCSIWORD( &device_blocks, &pbyCDB[7] );
			} else {
				pbyCDB[1] &= 0xE0; // Keep the LUN
				pbyCDB[1] |= (BYTE)( (lba >> 16) & 0x1F );
				pbyCDB[2] = (BYTE)( (lba >> 8) & 0xFF );
				pbyCDB[3] = (BYTE)( lba & 0xFF );
				pbyCDB[4] = device_blocks > 255 ? (BYTE)0 : (BYTE)device_blocks;
			}
			lba += device_blocks;
		}

		// MUST align to full device sectors.
		if(scsi_target->sector_size) {
			bytes = (bytes + scsi_target->sector_size - 1) & ~(scsi_target->sector_size-1);
		}

		retval = sync_exec(
			byHaId,
			byTarget,
			byFlags,
			bytes,
			gab.AB_BufPointer,
			byCDBBytes,
			pbyCDB,
			stat,
			silent,
			sense_out,
			sense_out_max
		);
		if(!retval) break;
		if(byFlags & SRB_DIR_IN) {
			if(bytes) memcpy( pbyBuffer, gab.AB_BufPointer, bytes );
		}
		pbyBuffer += bytes;
		bytes_left -= bytes;
	}
	return( retval );
}

/*
 *  Send SCSI command to active target (scsi_set_command() must have been called),
 *  read/write data according to S/G table (returns false on error)
 */

// The code assumes that data_length and scatter/gather total length match

bool scsi_send_cmd(size_t data_length, bool reading, int sg_size, uint8 **sg_ptr, uint32 *sg_len, uint16 *stat, uint32 timeout)
{
	bool retval = false;

	timeout = timeout;

	if(debug_scsi != DB_SCSI_NONE) D(bug("SCSI_SEND_CMD START\n"));

	if( ( is_aspi_available || is_direct_scsi_available ) &&
			scsi_target->haid >= 0 && scsi_command_length > 0 )
	{

		// Generally cannot patch just any cdb, the data length location varies

		if(debug_scsi != DB_SCSI_NONE) dbout_scsi_req(data_length, reading, sg_size, sg_len);

		if(data_length & 1) {
			if(debug_scsi != DB_SCSI_NONE) D(bug("Warning: byte aligned data length\n"));
		}

		// patches
		// note that this does not affect the emulation, only the
		// aspi layer and lower drivers

		switch(scsi_command[0]) {
			case SCSI_REQ_SENSE:
				if(data_length && data_length < B2_SENSE_LEN) {
					scsi_command[4] = data_length = B2_SENSE_LEN;
				} else if(data_length & 1) {
					scsi_command[4]++;
					data_length++;
				}
				break;

			case SCSI_INQUIRY:
				if(data_length && data_length < SIZE_INQUIRYBUF) {
					scsi_command[4] = data_length = SIZE_INQUIRYBUF;
				} else if(data_length & 1) {
					scsi_command[4]++;
					data_length++;
				}
				break;
			case 0x06:
				// some downstream guy doesn't like byte aligned sizes.
				if(scsi_command[4] & 1) {
					scsi_command[4]++;
					data_length++;
				}
				break;
			case SCSI_READ_TOC:
				// some cd's don't work with partial toc requests
				if(data_length < NEC_CDROM_TOC_SIZE) {
					data_length = NEC_CDROM_TOC_SIZE;
					int16 src = data_length; // size_t may be 16 or 32 bits
					MOVESCSIWORD(&src,&scsi_command[7]);
				}
				break;

			default:
				break;
		}

		// Check if buffer is large enough, allocate new buffer if needed
		if (!try_buffer(data_length)) {
			char str[256];
			wsprintf(str, GetString(STR_SCSI_BUFFER_ERR), data_length);
			ErrorAlert(str);
			return false;
		}

		// Process S/G table when writing
		if (!reading) {
			if(debug_scsi != DB_SCSI_NONE) D(bug(" writing to buffer\n"));
			uint8 *buffer_ptr = buffer;
			for (int i=0; i<sg_size; i++) {
				uint32 len = sg_len[i];
				if(debug_scsi != DB_SCSI_NONE) D(bug("  %d bytes from %08lx\n", len, sg_ptr[i]));
				memcpy(buffer_ptr, sg_ptr[i], len);
				buffer_ptr += len;
			}
		}

		if( scsi_command[0] == SCSI_WRITE6 || scsi_command[0] == SCSI_READ6 ||
		    scsi_command[0] == SCSI_WRITE10 || scsi_command[0] == SCSI_READ10 )
		{
try_again_split:
			// These may need splitting.
			retval = sync_exec_split(
				scsi_target->haid,
				scsi_target->target,
				reading ? SRB_DIR_IN : SRB_DIR_OUT,
				data_length,
				buffer,
				scsi_command_length,
				scsi_command,
				stat,
				TRUE,
				scsi_target->max_transfer,
				scsi_target->autosense,
				B2_SENSE_LEN
			);
			if(!retval && (scsi_command[0] == SCSI_WRITE6 || scsi_command[0] == SCSI_READ6) ) {
				// The device may not support 6 byte versions.
				// Control
				scsi_command[9] = scsi_command[5];

				// Length
				scsi_command[8] = scsi_command[4];
				if(scsi_command[8] == 0) scsi_command[8] = (BYTE)256;
				scsi_command[7] = 0;

				// Reserved
				scsi_command[6] = 0;

				// LBA
				scsi_command[5] = scsi_command[3];
				scsi_command[4] = scsi_command[2];
				scsi_command[3] = 0;
				scsi_command[2] = scsi_command[1] & 0x1F;

				// DPO=0, FUA=0, Res=0, RelAdr=0
				scsi_command[1] = scsi_command[1] & 0xE0;

				// Command
				if(scsi_command[0] == SCSI_READ6) {
					scsi_command[0] = SCSI_READ10;
				} else {
					scsi_command[0] = SCSI_WRITE10;
				}

				scsi_command_length = 10;
				if(debug_scsi != DB_SCSI_NONE) dbout_scsi_req(data_length, reading, sg_size, sg_len);
				goto try_again_split;
			}
		} else {
try_again_regular:
			// Send regular command
			if (m_use_autosense && scsi_command[0] == SCSI_REQ_SENSE && scsi_target->autosense_valid) {
				memcpy( buffer, scsi_target->autosense, min(data_length,B2_SENSE_LEN) );
				*stat = STATUS_GOOD;
				retval = true;
			} else {
				retval = sync_exec(
					scsi_target->haid,
					scsi_target->target,
					reading ? SRB_DIR_IN : SRB_DIR_OUT,
					data_length,
					buffer,
					scsi_command_length,
					scsi_command,
					stat,
					TRUE,
					scsi_target->autosense,
					B2_SENSE_LEN
				);
				scsi_target->autosense_valid = !retval;
			}
			if(!retval && (scsi_command[0] == SCSI_MODE_SEN6 || scsi_command[0] == SCSI_MODE_SEL6) ) {
				// Control
				scsi_command[9] = scsi_command[5];

				// Length
				scsi_command[8] = scsi_command[4];
				scsi_command[7] = 0;

				// Reserved
				scsi_command[6] = 0;
				scsi_command[5] = 0;
				scsi_command[4] = 0;

				// Command
				if(scsi_command[0] == SCSI_MODE_SEN6) {
					scsi_command[0] = SCSI_MODE_SEN10;
				} else {
					scsi_command[0] = SCSI_MODE_SEL10;
				}

				scsi_command_length = 10;
				if(debug_scsi != DB_SCSI_NONE) dbout_scsi_req(data_length, reading, sg_size, sg_len);
				goto try_again_regular;
			}
		}

		// Process S/G table when reading
		if (retval && reading) {
			if(debug_scsi == DB_SCSI_LOUD) {
				dbout_scsi_data( data_length, buffer );
			}

			if(scsi_command[0] == SCSI_INQUIRY) {
				patch_inquiry( (char*)buffer );
			}

			if(debug_scsi != DB_SCSI_NONE) D(bug(" reading from buffer\n"));
			uint8 *buffer_ptr = buffer;
			for (int i=0; i<sg_size; i++) {
				uint32 len = sg_len[i];
				if(debug_scsi != DB_SCSI_NONE) D(bug("  %d bytes to %08lx\n", len, sg_ptr[i]));
				memcpy(sg_ptr[i], buffer_ptr, len);
				buffer_ptr += len;
			}
		}

	} else {
		*stat = STATUS_GOOD;
		retval = false;
	}

	if(debug_scsi != DB_SCSI_NONE) D(bug("SCSI_SEND_CMD END, retval=%d, stat=%d\n\n",(int)retval,(int)*stat));

  return(retval);
}

#pragma pack()
