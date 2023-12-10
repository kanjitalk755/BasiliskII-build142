#include "stdafx.h"
#include "winioctl.h"
#include "winsvc.h"
#include "\BasiliskII\src\Windows\b2ether\packet32.cpp"

// dummies
void recycle_write_packet( LPPACKET Packet )
{
}

VOID CALLBACK packet_read_completion(
  DWORD dwErrorCode,
  DWORD dwNumberOfBytesTransfered,
  LPOVERLAPPED lpOverlapped
)
{
}
