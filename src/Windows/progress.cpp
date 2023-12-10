/*
 *  progress.cpp
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

#include "sysdeps.h"
#include "main.h"
#include "prefs.h"
#include "user_strings.h"
#include "cpu_emulation.h"
#include "macos_util.h"
#include "sys.h"
#include "errno.h"
#include "winioctl.h"
#include "main_windows.h"
#include "util_windows.h"
#include "progress.h"
#include "resource.h"

static int CALLBACK progress_proc( HWND hDlg, unsigned message, WPARAM wParam, LPARAM lParam )
{
	int result = 0;

	switch (message) {
		case WM_INITDIALOG:
			center_window( hDlg );
			SetForegroundWindow( hDlg );
			result = 1;
			break;
		case WM_DESTROY:
			break;
		case WM_COMMAND:
			switch (LOWORD(wParam)) {
				case IDOK:
					EndDialog( hDlg, TRUE );
					result = 1;
					break;
				case IDCANCEL:
					EndDialog( hDlg, FALSE );
					result = 1;
					break;
			}
	  	break;
	}
  return(result);
}

progress_c::progress_c( int maxval, char *caption, char *explain )
{
	m_maxval = maxval;

	m_wnd = CreateDialogParam( hInst, "DLG_COMMIT_PROGRESS", GetForegroundWindow(), progress_proc, 0L);
	if(m_wnd) {
		SetWindowText( GetDlgItem( m_wnd, IDC_PROGRESS_FNAME ), caption );
		SetWindowText( GetDlgItem( m_wnd, IDC_XPLAIN ), explain );
		ShowWindow( m_wnd, SW_NORMAL );
		UpdateWindow( m_wnd );
	}
}

progress_c::~progress_c()
{
	if(m_wnd) {
		DestroyWindow(m_wnd);
		m_wnd = 0;
	}
}

progress_c::set(int inx)
{
	m_index = inx;
	if(m_wnd) {
		HWND w = GetDlgItem( m_wnd, IDC_PROGRESS_BAR );
		if(w) {
			RECT r;
			GetWindowRect( w, &r );
			InflateRect( &r, -1, -1 );
			ScreenToClient( m_wnd, (LPPOINT)&r.left );
			ScreenToClient( m_wnd, (LPPOINT)&r.right );
			int width = r.right - r.left;
			r.right = r.left + width * m_index / m_maxval;
			HDC hdc = GetDC( m_wnd );
			if(hdc) {
				FillRect( hdc, &r, (HBRUSH)GetStockObject(DKGRAY_BRUSH) );
				ValidateRect( m_wnd, &r );
				UpdateWindow( m_wnd );
			}
		}
	}
}
