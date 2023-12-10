#include "stdafx.h"
#include "sysdeps.h"
#include "main_windows.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif


BOOL win_os_old = FALSE; 


int16 SCSIReset(void)
{
	return(0);
}

void QuitEmulator(void)
{
}

void ErrorAlert(const char *text)
{
	AfxMessageBox(text);
}

char *GetString(int num)
{
	num = num;
	return("");
}
