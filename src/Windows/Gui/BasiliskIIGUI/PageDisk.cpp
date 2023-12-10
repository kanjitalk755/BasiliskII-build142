// PageDisk.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageDisk.h"
#include "MakeNewHFV.h"
#include "sysdeps.h"
#include "util_windows.h"
#include "ConfirmRWDlg.h"
#include "MountModeHelp.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageDisk property page

IMPLEMENT_DYNCREATE(CPageDisk, CPropertyPage)

CPageDisk::CPageDisk() : CPropertyPage(CPageDisk::IDD)
{
	//{{AFX_DATA_INIT(CPageDisk)
	m_poll_media = FALSE;
	m_disk_mount_mode = -1;
	//}}AFX_DATA_INIT
}

CPageDisk::~CPageDisk()
{
}

void CPageDisk::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageDisk)
	DDX_Control(pDX, IDC_DISK_LIST_INSTALLED, m_list_installed);
	DDX_Control(pDX, IDC_DISK_LIST_AVAILABLE, m_list_available);
	DDX_Check(pDX, IDC_DISK_POLL_MEDIA, m_poll_media);
	DDX_CBIndex(pDX, IDC_DISK_MOUNT_MODE, m_disk_mount_mode);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageDisk, CPropertyPage)
	//{{AFX_MSG_MAP(CPageDisk)
	ON_BN_CLICKED(IDC_DISK_CREATE_HFV, OnDiskCreateHfv)
	ON_BN_CLICKED(IDC_DISK_DOWN, OnDiskDown)
	ON_BN_CLICKED(IDC_DISK_INSTALL, OnDiskInstall)
	ON_BN_CLICKED(IDC_DISK_REMOVE, OnDiskRemove)
	ON_BN_CLICKED(IDC_DISK_UP, OnDiskUp)
	ON_WM_DESTROY()
	ON_LBN_DBLCLK(IDC_DISK_LIST_INSTALLED, OnDblclkDiskListInstalled)
	ON_LBN_DBLCLK(IDC_DISK_LIST_AVAILABLE, OnDblclkDiskListAvailable)
	ON_BN_CLICKED(IDC_DISK_ADD_VOLUME_FILE, OnDiskAddVolumeFile)
	ON_WM_CTLCOLOR()
	ON_WM_MEASUREITEM()
	ON_WM_DRAWITEM()
	ON_LBN_SELCHANGE(IDC_DISK_LIST_INSTALLED, OnSelchangeDiskListInstalled)
	ON_CBN_SELCHANGE(IDC_DISK_MOUNT_MODE, OnSelchangeDiskMountMode)
	ON_BN_CLICKED(IDC_MOUNT_MODE_HELP, OnMountModeHelp)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageDisk message handlers
enum {
	RWMODE_READ_WRITE=0,
	RWMODE_READ_ONLY,
	RWMODE_VOLATILE,
	RWMODE_UNDOABLE,
	RWMODE_UNDOABLE_AUTO
};

int CPageDisk::is_rw_item( int i )
{
	return (int)m_list_installed.GetItemData(i);
}

void CPageDisk::set_rw_item( int i, int rw )
{
	m_list_installed.SetItemData(i,rw);
}

// TODO: this does not work on NT5
int get_physical_disk_type( LPCSTR path )
{
	int index1, index2;
	char dnamebuf[64];
	char dname[64];

	if(strncmp(path,"\\\\.\\PHYSICALDRIVE",17) == 0) {
		index1 = atoi( &path[17] );
		for( char letter='A'; letter<='Z'; letter++ ) {
			sprintf( dname, "%c:", letter );
			if(QueryDosDevice(dname, dnamebuf, sizeof(dnamebuf)) != 0) {
				char *hd = strstr( dnamebuf, "\\Harddisk" );
				if(hd && strstr( dnamebuf, "\\Partition1" )) {
					index2 = atoi(hd+9);
					if(index1 == index2) {
						strcat( dname, "\\" );
						return GetDriveType(dname);
					}
				}
			}
		}
	}
	return DRIVE_UNKNOWN;
}

BOOL is_physical_hard_disk( LPCSTR path )
{
	BOOL result = FALSE;

	if(strncmp(path,"\\\\.\\PHYSICALDRIVE",17) == 0) {
		if(get_physical_disk_type(path) == DRIVE_FIXED) {
			result = TRUE;
		}
	}
	if(strncmp(path,"PHYSICAL ",9) == 0)  result = TRUE;
	return result;
}

BOOL is_dangerous_volume( LPCSTR path )
{
	BOOL result = FALSE;

	if( isalpha(path[0]) && path[1] == ':' && path[2] == '\\' && path[3] == 0 ) {
		char rootdir[10];
		wsprintf( rootdir, "%c:\\", *path );
		result = (GetDriveType( rootdir ) != DRIVE_REMOVABLE);
	}
	if(is_physical_hard_disk(path)) result = TRUE;
	return result;
}

BOOL is_read_only_path( LPCSTR path )
{
  DWORD attrib;
	BOOL result = FALSE;

  attrib = GetFileAttributes( (char *)path );
  if( attrib != 0xFFFFFFFF && (attrib & FILE_ATTRIBUTE_READONLY) != 0 ) {
		result = TRUE;
  }
	return result;
}

void CPageDisk::OnDiskCreateHfv() 
{
	CMakeNewHFV dlg;

	dlg.m_path = ((CBasiliskIIGUIApp*)AfxGetApp())->m_dir + "New.HFV";

	if(dlg.DoModal() == IDOK) {
		if(exists(dlg.m_path)) {
			int answer = AfxMessageBox( 
				"The file \"" + dlg.m_path + "\" already exists and will be overwritten. Ok to continue?",
				MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2
			);
			if(answer == IDNO) return;
			DeleteFile( dlg.m_path );
			if(exists(dlg.m_path)) {
				AfxMessageBox( "The file could not be overwritten.", MB_OK|MB_ICONSTOP );
				return;
			}
		}

		SetCursor( LoadCursor( 0, IDC_WAIT ) );
		if(create_file( dlg.m_path, dlg.m_size * 1024*1024 )) {
			SetCursor( LoadCursor( 0, IDC_ARROW ) );
			int i = m_list_installed.AddString( dlg.m_path );
			set_rw_item(i,RWMODE_READ_WRITE);
			m_list_installed.SetCurSel(i); // -1 is ok
			OnSelchangeDiskListInstalled();
		} else {
			SetCursor( LoadCursor( 0, IDC_ARROW ) );
			AfxMessageBox( CString("Failed to create the file \"") + dlg.m_path + "\"" );
			DeleteFile( dlg.m_path );
		}
	}
}

void CPageDisk::OnDiskInstall() 
{
	int i, j = m_list_available.GetCurSel();
	CString name;

	if(j >= 0) {
		m_list_available.GetText(j, name);
		m_list_available.DeleteString(j);
		i = m_list_installed.AddString(name);
		if(!is_dangerous_volume(name) && !is_read_only_path(name))
			set_rw_item(i,RWMODE_READ_WRITE);
		else
			set_rw_item(i,RWMODE_READ_ONLY);
		m_list_installed.SetCurSel(i); // -1 is ok
		OnSelchangeDiskListInstalled();
	}
}

void CPageDisk::OnDiskRemove() 
{
	int i = m_list_installed.GetCurSel(), j;
	CString name;

	if(i >= 0) {
		m_list_installed.GetText(i, name);
		m_list_installed.DeleteString(i);
		j = m_list_available.AddString(name);
		m_list_available.SetCurSel(j); // -1 is ok
		OnSelchangeDiskListInstalled();
	}
}

void CPageDisk::OnDiskDown() 
{
	int i = m_list_installed.GetCurSel();
	CString name;

	if(i >= 0 && i < m_list_installed.GetCount()-1) {
		m_list_installed.GetText(i, name);
		int rw = is_rw_item( i );
		m_list_installed.DeleteString(i);
		i = m_list_installed.InsertString(i+1, name);
		set_rw_item( i, rw );
		m_list_installed.SetCurSel(i);
	}
}

void CPageDisk::OnDiskUp() 
{
	int i = m_list_installed.GetCurSel();
	CString name;

	if(i > 0) {
		m_list_installed.GetText(i, name);
		int rw = is_rw_item( i );
		m_list_installed.DeleteString(i);
		i = m_list_installed.InsertString(i-1, name);
		set_rw_item( i, rw );
		m_list_installed.SetCurSel(i);
	}
}

void CPageDisk::enum_hard_files( const char *dir, char *extension )
{
	char mask[_MAX_PATH];
	HANDLE fh;
	WIN32_FIND_DATA FindFileData;
	int ok;

	wsprintf( mask, "%s*.%s", dir, extension );
	fh = FindFirstFile( mask, &FindFileData );
	ok = fh != INVALID_HANDLE_VALUE;
	while(ok) {
		int i, count = m_list.GetSize();
		for(i=0; i<count; i++) {
			if( stricmp(FindFileData.cFileName,m_list.GetAt(i)) == 0 ) break;
		}
		if( i == count ) {
			m_list_available.AddString( FindFileData.cFileName );
		}
		ok = FindNextFile( fh, &FindFileData );
	}
	if(fh != INVALID_HANDLE_VALUE) FindClose( fh );
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

BOOL CPageDisk::OnInitDialog() 
{
	int i, count;
	char rootdir[100], letter;

	CPropertyPage::OnInitDialog();

	check_os();
	
	count = m_list.GetSize();
	for(i=0; i<count; i++) {
		LPCSTR path = m_list.ElementAt(i);
		int rw;
		if( strncmp(path,"/RW ",4) == 0 ) {
			rw = RWMODE_READ_WRITE;
			path += 3;
			while (*path == ' ') path++;
		} else if( strncmp(path,"/RO ",4) == 0 ) {
			rw = RWMODE_READ_ONLY;
			path += 3;
			while (*path == ' ') path++;
		} else if( strncmp(path,"/RV ",4) == 0 ) {
			rw = RWMODE_VOLATILE;
			path += 3;
			while (*path == ' ') path++;
		} else if( strncmp(path,"/RU ",4) == 0 ) {
			rw = RWMODE_UNDOABLE;
			path += 3;
			while (*path == ' ') path++;
		} else if( strncmp(path,"/RA ",4) == 0 ) {
			rw = RWMODE_UNDOABLE_AUTO;
			path += 3;
			while (*path == ' ') path++;
		} else if( is_read_only_path(path) ) {
			rw = RWMODE_READ_ONLY;
		} else if(is_dangerous_volume(path)) {
			rw = RWMODE_READ_ONLY;
		} else {
			rw = RWMODE_READ_WRITE;
		}

		if(is_physical_hard_disk(path)) rw = RWMODE_READ_ONLY;

		m_list[i] = CString( path );
		int inx = m_list_installed.AddString( m_list[i] );
		set_rw_item(inx,rw);
	}
	
	enum_hard_files( ((CBasiliskIIGUIApp*)AfxGetApp())->m_dir, "hf?" );
	enum_hard_files( ((CBasiliskIIGUIApp*)AfxGetApp())->m_dir, "dsk" );
	if(is_nt) {
		// enum physical disks
		int inx = 0;
		for( inx = 0; inx < 30; inx++ ) {
			wsprintf( rootdir, "\\\\.\\PHYSICALDRIVE%d", inx );
			if(get_physical_disk_type(rootdir) == DRIVE_FIXED) {
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
	for( letter = 'C'; letter <= 'Z'; letter++ ) {
		wsprintf( rootdir, "%c:\\", letter );
		int type = GetDriveType( rootdir );
		if(type == DRIVE_FIXED /* || type == DRIVE_REMOVABLE */) {
			for(i=0; i<count; i++) {
				if( stricmp(rootdir,m_list.GetAt(i)) == 0 ) break;
			}
			if( i == count ) {
				m_list_available.AddString( rootdir );
			}
		}
	}

	int select = -1;
	if(m_list_installed.GetCount() > 0) select = 0;
	m_list_installed.SetCurSel(select);

	OnSelchangeDiskListInstalled();
	
	return TRUE;
}

void CPageDisk::OnDestroy() 
{
	CPropertyPage::OnDestroy();
	
	int i, count;
	CString str;

	m_list.RemoveAll();
	
	count = m_list_installed.GetCount();
	for(i=0; i<count; i++) {
		m_list_installed.GetText(i, str);
		int rw = is_rw_item(i);
		switch(rw) {
			case RWMODE_READ_WRITE:
				if(is_dangerous_volume(str)) str = CString("/RW ") + str;
				break;
			case RWMODE_READ_ONLY:
				if(!is_dangerous_volume(str)) str = CString("/RO ") + str;
				break;
			case RWMODE_VOLATILE:
				str = CString("/RV ") + str;
				break;
			case RWMODE_UNDOABLE:
				str = CString("/RU ") + str;
				break;
			case RWMODE_UNDOABLE_AUTO:
				str = CString("/RA ") + str;
				break;
		}
		m_list.Add(str);
	}
}

void CPageDisk::OnDblclkDiskListInstalled() 
{
	OnDiskRemove();
}

void CPageDisk::OnDblclkDiskListAvailable() 
{
	OnDiskInstall();
}


void CPageDisk::OnDiskAddVolumeFile() 
{
	if(UpdateData(TRUE)) {
		CFileDialog dlg( TRUE, _T("HFV"), "",
					OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT,
					_T("Volume files (*.hf?;*.dsk)|*.hf?;*.dsk|All Files|*.*||") );
		if(dlg.DoModal() == IDOK) {
			CString path = dlg.GetPathName();
			int i = m_list_installed.AddString( path );
			if(is_read_only_path(path)) {
				set_rw_item(i,RWMODE_READ_ONLY);
			} else {
				set_rw_item(i,RWMODE_READ_WRITE);
			}
			m_list_installed.SetCurSel(i);
			OnSelchangeDiskListInstalled();
			UpdateData(FALSE);
		}
	}
}

HBRUSH CPageDisk::OnCtlColor(CDC* pDC, CWnd* pWnd, UINT nCtlColor) 
{
	HBRUSH hbr = CPropertyPage::OnCtlColor(pDC, pWnd, nCtlColor);
	
	// TODO: Change any attributes of the DC here
	
	// TODO: Return a different brush if the default is not desired
	return hbr;
}

void CPageDisk::OnMeasureItem(int nIDCtl, LPMEASUREITEMSTRUCT lpMeasureItemStruct) 
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

void CPageDisk::draw_list_item( DRAWITEMSTRUCT FAR *lpd )
{
	char buf[255];
  HBRUSH hbrBackground = 0, hbrOld = 0;
	BOOL do_warn_color = FALSE;
	COLORREF txt_color, txt_colorOld;

  ::SendMessage( lpd->hwndItem, LB_GETTEXT, (WPARAM)lpd->itemID, (LPARAM)((LPSTR)buf));

	int rw = is_rw_item(lpd->itemID);
	switch(rw) {
		case RWMODE_READ_WRITE:
			if(is_dangerous_volume(buf)) {
				do_warn_color = TRUE;
				txt_color = RGB(255,0,0);
			}
			break;
		case RWMODE_READ_ONLY:
			if(!is_dangerous_volume(buf)) {
				do_warn_color = TRUE;
				txt_color = RGB(0,0,255);
			}
			break;
		case RWMODE_VOLATILE:
			do_warn_color = TRUE;
			txt_color = RGB(255,0,255);
			break;
		case RWMODE_UNDOABLE:
		case RWMODE_UNDOABLE_AUTO:
			do_warn_color = TRUE;
			txt_color = RGB(0,128,0);
			break;
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

void CPageDisk::OnDrawItem(int nIDCtl, LPDRAWITEMSTRUCT lpDrawItemStruct) 
{
	if(nIDCtl == IDC_DISK_LIST_INSTALLED) {
		draw_list_item( lpDrawItemStruct );
	} else {
		CPropertyPage::OnDrawItem(nIDCtl, lpDrawItemStruct);
	}
}

void CPageDisk::enum_mount_modes()
{
	CWnd *item = GetDlgItem(IDC_DISK_MOUNT_MODE);

	item->SendMessage(CB_RESETCONTENT);

	int i = m_list_installed.GetCurSel();
	if(i >= 0) {
		CString path;
		m_list_installed.GetText(i,path);
		item->SendMessage(CB_ADDSTRING,0,(LPARAM)"Mount this volume read/write");
		item->SendMessage(CB_ADDSTRING,0,(LPARAM)"Mount this volume read-only");
		if(!is_dangerous_volume(path)) {
			item->SendMessage(CB_ADDSTRING,0,(LPARAM)"Virtual read/write mode (discard all changes)");
			item->SendMessage(CB_ADDSTRING,0,(LPARAM)"Undoable mode (ask whether to keep changes)");
			item->SendMessage(CB_ADDSTRING,0,(LPARAM)"Undoable auto (save changes on proper shutdown)");
		}
	}
}



void CPageDisk::OnSelchangeDiskListInstalled() 
{
	int i = m_list_installed.GetCurSel();

	enum_mount_modes();

	if(i >= 0) {
		m_disk_mount_mode = is_rw_item(i);
	} else {
		m_disk_mount_mode = -1;
	}
	UpdateData(FALSE);
}

BOOL CPageDisk::confirm_rw_mount(const char *name) 
{
	if(is_physical_hard_disk(name)) {
		AfxMessageBox( "Physical hard disks cannot be mounted Read/Write. This is a safety measure.", MB_OK|MB_ICONSTOP );
		return FALSE;
	} else {
		CConfirmRWDlg dlg;
		dlg.m_path = name;
		return( dlg.DoModal() == IDOK );
	}
}

void CPageDisk::OnSelchangeDiskMountMode() 
{
	UpdateData(TRUE);

	int i = m_list_installed.GetCurSel();

	if(i >= 0) {
		CString path;
		m_list_installed.GetText(i,path);

		switch(m_disk_mount_mode) {
			case RWMODE_READ_WRITE:
				if(!is_dangerous_volume(path) || confirm_rw_mount(path)) {
					set_rw_item(i,m_disk_mount_mode);
				}
				break;
			case RWMODE_READ_ONLY:
				set_rw_item(i,m_disk_mount_mode);
				break;
			case RWMODE_VOLATILE:
			case RWMODE_UNDOABLE:
			case RWMODE_UNDOABLE_AUTO:
				if(is_dangerous_volume(path)) {
					// not supported
					// should never get here
					AfxMessageBox( "Only HFV volume files support this mode.", MB_OK|MB_ICONSTOP );
				} else {
					set_rw_item(i,m_disk_mount_mode);
				}
				break;
		}
		InvalidateRect( NULL, FALSE );
		OnSelchangeDiskListInstalled();
	}
}

void CPageDisk::OnMountModeHelp() 
{
	CMountModeHelp dlg;
	dlg.DoModal();
}
