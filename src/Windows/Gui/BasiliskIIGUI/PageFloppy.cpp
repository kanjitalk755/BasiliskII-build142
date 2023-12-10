// PageFloppy.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageFloppy.h"

int get_physical_disk_type( LPCSTR path );
BOOL is_read_only_path( LPCSTR path );

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageFloppy property page

IMPLEMENT_DYNCREATE(CPageFloppy, CPropertyPage)

CPageFloppy::CPageFloppy() : CPropertyPage(CPageFloppy::IDD)
{
	//{{AFX_DATA_INIT(CPageFloppy)
	m_boot_allowed = FALSE;
	//}}AFX_DATA_INIT
}

CPageFloppy::~CPageFloppy()
{
}

void CPageFloppy::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageFloppy)
	DDX_Control(pDX, IDC_FLOPPY_LIST_INSTALLED, m_list_installed);
	DDX_Control(pDX, IDC_FLOPPY_LIST_AVAILABLE, m_list_available);
	DDX_Check(pDX, IDC_FLOPPY_BOOT_ALLOWED, m_boot_allowed);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageFloppy, CPropertyPage)
	//{{AFX_MSG_MAP(CPageFloppy)
	ON_BN_CLICKED(IDC_FLOPPY_DOWN, OnFloppyDown)
	ON_BN_CLICKED(IDC_FLOPPY_INSTALL, OnFloppyInstall)
	ON_BN_CLICKED(IDC_FLOPPY_REMOVE, OnFloppyRemove)
	ON_BN_CLICKED(IDC_FLOPPY_UP, OnFloppyUp)
	ON_WM_DESTROY()
	ON_LBN_DBLCLK(IDC_FLOPPY_LIST_INSTALLED, OnDblclkFloppyListInstalled)
	ON_LBN_DBLCLK(IDC_FLOPPY_LIST_AVAILABLE, OnDblclkFloppyListAvailable)
	ON_BN_CLICKED(IDC_FLOPPY_RW, OnFloppyRw)
	ON_LBN_SELCHANGE(IDC_FLOPPY_LIST_INSTALLED, OnSelchangeFloppyListInstalled)
	ON_WM_DRAWITEM()
	ON_WM_MEASUREITEM()
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageFloppy message handlers

BOOL CPageFloppy::is_rw_item( LPCSTR path )
{
	int i, count = m_rw_paths.GetSize();

	for( i=0; i<count; i++ ) {
		LPCSTR p = m_rw_paths.ElementAt(i);
		if( strcmp(p,path) == 0 ) return TRUE;
	}
	return FALSE;
}

void CPageFloppy::set_rw_item( LPCSTR path, BOOL rw )
{
	if(rw) {
		m_rw_paths.Add( CString(path) );
	} else {
		int i, count = m_rw_paths.GetSize();
		for( i=0; i<count; i++ ) {
			LPCSTR p = m_rw_paths.ElementAt(i);
			if( strcmp(p,path) == 0 ) {
				m_rw_paths.RemoveAt(i);
				break;
			}
		}
	}
}

void CPageFloppy::OnFloppyInstall() 
{
	int i, j = m_list_available.GetCurSel();
	CString name;

	if(j >= 0) {
		m_list_available.GetText(j, name);
		m_list_available.DeleteString(j);
		i = m_list_installed.AddString(name);
		set_rw_item(name,TRUE);
		m_list_installed.SetCurSel(i); // -1 is ok
	}
}

void CPageFloppy::OnFloppyRemove() 
{
	int i = m_list_installed.GetCurSel(), j;
	CString name;

	if(i >= 0) {
		m_list_installed.GetText(i, name);
		m_list_installed.DeleteString(i);
		j = m_list_available.AddString(name);
		m_list_available.SetCurSel(j); // -1 is ok
		set_rw_item(name,FALSE);
	}
}

void CPageFloppy::OnFloppyDown() 
{
	int i = m_list_installed.GetCurSel();
	CString name;

	if(i >= 0 && i < m_list_installed.GetCount()-1) {
		m_list_installed.GetText(i, name);
		m_list_installed.DeleteString(i);
		i = m_list_installed.InsertString(i+1, name);
		m_list_installed.SetCurSel(i);
	}
}

void CPageFloppy::OnFloppyUp() 
{
	int i = m_list_installed.GetCurSel();
	CString name;

	if(i > 0) {
		m_list_installed.GetText(i, name);
		m_list_installed.DeleteString(i);
		i = m_list_installed.InsertString(i-1, name);
		m_list_installed.SetCurSel(i);
	}
}

static bool is_nt = false;

static void check_os(void)
{
	OSVERSIONINFO osv;

	is_nt = false;

	osv.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
	if(GetVersionEx( &osv )) {
		switch(osv.dwPlatformId) {
			case VER_PLATFORM_WIN32_NT:
				is_nt = true;
				break;
			default:
				is_nt = false;
		}
	}
}

BOOL CPageFloppy::OnInitDialog() 
{
	int i, count;
	char rootdir[20], letter;

	CPropertyPage::OnInitDialog();

	check_os();
	
	count = m_list.GetSize();
	for(i=0; i<count; i++) {
		LPCSTR path = m_list.ElementAt(i);
		BOOL rw;
		if( strncmp(path,"/RW ",4) == 0 ) {
			rw = TRUE;
			path += 3;
			while (*path == ' ') path++;
		} else if( strncmp(path,"/RO ",4) == 0 ) {
			rw = FALSE;
			path += 3;
			while (*path == ' ') path++;
		} else if( is_read_only_path(path) ) {
			rw = FALSE;
		} else {
			rw = TRUE;
		}
		m_list[i] = CString( path );
		m_list_installed.AddString( path );
		set_rw_item(path,rw);
	}
	if(is_nt) {
		// enum physical disks
		int inx = 0;
		for( inx = 0; inx < 30; inx++ ) {
			wsprintf( rootdir, "\\\\.\\PHYSICALDRIVE%d", inx );
			if(get_physical_disk_type(rootdir) == DRIVE_REMOVABLE) {
				HANDLE h = CreateFile( 
					rootdir, 
					GENERIC_READ,
					FILE_SHARE_READ|FILE_SHARE_WRITE,
					0, 
					OPEN_EXISTING, 
					FILE_FLAG_NO_BUFFERING,
					0 
				);
				if( h == INVALID_HANDLE_VALUE ) break;
				CloseHandle(h);

				for(i=0; i<count; i++) {
					if( stricmp(rootdir,m_list.GetAt(i)) == 0 ) break;
				}
				if( i == count ) {
					m_list_available.AddString( rootdir );
				}
			}
		}
	}
	for( letter = 'A'; letter <= 'Z'; letter++ ) {
		wsprintf( rootdir, "%c:\\", letter );
		if(GetDriveType( rootdir ) == DRIVE_REMOVABLE) {
			for(i=0; i<count; i++) {
				if( stricmp(rootdir,m_list.GetAt(i)) == 0 ) break;
			}
			if( i == count ) {
				m_list_available.AddString( rootdir );
			}
		}
	}
	
	return TRUE;
}

void CPageFloppy::OnDestroy() 
{
	CPropertyPage::OnDestroy();
	
	int i, count;
	CString str;

	m_list.RemoveAll();
	
	count = m_list_installed.GetCount();
	for(i=0; i<count; i++) {
		m_list_installed.GetText(i, str);
		if(!is_rw_item(str)) {
			str = CString("/RO ") + str;
		}
		m_list.Add(str);
	}
}

void CPageFloppy::OnDblclkFloppyListInstalled() 
{
	OnFloppyRemove();
}

void CPageFloppy::OnDblclkFloppyListAvailable() 
{
	OnFloppyInstall();
}

void CPageFloppy::OnFloppyRw() 
{
	int i = m_list_installed.GetCurSel();
	CString path;

	if(i >= 0) {
		m_list_installed.GetText(i, path);
		set_rw_item(path,!is_rw_item(path));
		InvalidateRect( NULL, FALSE );
		OnSelchangeFloppyListInstalled();
	}
}

void CPageFloppy::OnMeasureItem(int nIDCtl, LPMEASUREITEMSTRUCT lpMeasureItemStruct) 
{
	if(nIDCtl == IDC_DISK_LIST_INSTALLED) {
		HDC hdc = ::GetDC( GetSafeHwnd() );
		if(hdc) {
			TEXTMETRIC tm;
			GetTextMetrics( hdc, &tm );
			lpMeasureItemStruct->itemHeight = tm.tmHeight-2;
			::ReleaseDC( GetSafeHwnd(), hdc );
		}
	}
	CPropertyPage::OnMeasureItem(nIDCtl, lpMeasureItemStruct);
}

void CPageFloppy::draw_list_item( DRAWITEMSTRUCT FAR *lpd )
{
	char buf[255];
  HBRUSH hbrBackground = 0, hbrOld = 0;
	BOOL do_warn_color = FALSE;
	COLORREF txt_color, txt_colorOld;

  ::SendMessage( lpd->hwndItem, LB_GETTEXT, (WPARAM)lpd->itemID, (LPARAM)((LPSTR)buf));

	if(!is_rw_item(buf)) {
		do_warn_color = TRUE;
		txt_color = RGB(0,0,255);
	}
	  
  hbrBackground = CreateSolidBrush( GetSysColor(COLOR_WINDOW) );
  if(hbrBackground) {
		if( lpd->itemAction & (ODA_DRAWENTIRE | ODA_SELECT) ) {
		  FillRect( lpd->hDC, &lpd->rcItem, hbrBackground );
			if(do_warn_color) txt_colorOld = SetTextColor( lpd->hDC, txt_color );
			TextOut( lpd->hDC, lpd->rcItem.left, lpd->rcItem.top, buf, strlen(buf) );
			if(do_warn_color) SetTextColor( lpd->hDC, txt_colorOld );
		  if(lpd->itemState & ODS_SELECTED) {
		    InvertRect( lpd->hDC, &lpd->rcItem );
				if(do_warn_color) {
					int bkmodeOld = SetBkMode( lpd->hDC, TRANSPARENT );
					txt_colorOld = SetTextColor( lpd->hDC, txt_color );
					TextOut( lpd->hDC, lpd->rcItem.left, lpd->rcItem.top, buf, strlen(buf) );
					SetTextColor( lpd->hDC, txt_colorOld );
					SetBkMode( lpd->hDC, bkmodeOld );
				}
			}
	  }
	  DeleteObject( (HGDIOBJ)hbrBackground );
	}
}

void CPageFloppy::OnDrawItem(int nIDCtl, LPDRAWITEMSTRUCT lpDrawItemStruct) 
{
	if(nIDCtl == IDC_FLOPPY_LIST_INSTALLED) {
		draw_list_item( lpDrawItemStruct );
	} else {
		CPropertyPage::OnDrawItem(nIDCtl, lpDrawItemStruct);
	}
}

void CPageFloppy::OnSelchangeFloppyListInstalled() 
{
	int i = m_list_installed.GetCurSel();
	CString path, txt;

	if(i >= 0) {
		GetDlgItem(IDC_FLOPPY_RW)->EnableWindow(TRUE);
		m_list_installed.GetText(i, path);
		if(is_rw_item(path)) {
			txt = "This volume will be mounted as Read/Write.";
		} else {
			txt = "This volume will be mounted as Read Only.";
		}
	} else {
		GetDlgItem(IDC_FLOPPY_RW)->EnableWindow(FALSE);
		txt = "Select mount mode (read only, read/write)";
	}
	GetDlgItem(IDC_FLOPPY_RW)->SetWindowText( txt );
}
