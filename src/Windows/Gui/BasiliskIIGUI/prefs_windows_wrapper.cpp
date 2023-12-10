#include "stdafx.h"
#include "\BasiliskII\src\Windows\prefs_windows.cpp"

void SysAddSerialPrefs(void)
{
	PrefsAddString("seriala", "COM1");
	PrefsAddString("serialb", "COM2");
}
