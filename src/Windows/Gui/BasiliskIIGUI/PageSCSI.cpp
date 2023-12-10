// PageSCSI.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageSCSI.h"
#include "sysdeps.h"
#include "SCSI.h"
#include "scsi_windows.h"
#include "prefs.h"
#include "prefs_windows.h"
#include "AskSCSIReplacement.h"
#include "ConfirmDASDDialog.h"
#include "scsidefs.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

#define MID_GUI_SCSI_FIRST_DISABLED 10000
#define MID_GUI_SCSI_FIRST_FROM			20000

/////////////////////////////////////////////////////////////////////////////
// CPageSCSI property page

IMPLEMENT_DYNCREATE(CPageSCSI, CPropertyPage)

CPageSCSI::CPageSCSI() : CPropertyPage(CPageSCSI::IDD)
{
	//{{AFX_DATA_INIT(CPageSCSI)
	m_scsi_enabled = FALSE;
	//}}AFX_DATA_INIT
}

CPageSCSI::~CPageSCSI()
{
}

void CPageSCSI::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageSCSI)
	DDX_Control(pDX, IDC_SCSI_LIST_REPLACE_TO, m_list_replace_to);
	DDX_Control(pDX, IDC_SCSI_LIST_REPLACE_FROM, m_list_replace_from);
	DDX_Control(pDX, IDC_SCSI_LIST_DISABLED, m_list_disabled);
	DDX_Check(pDX, IDC_SCSI_ENABLED, m_scsi_enabled);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageSCSI, CPropertyPage)
	//{{AFX_MSG_MAP(CPageSCSI)
	ON_WM_DESTROY()
	ON_BN_CLICKED(IDC_SCSI_ADD_DISABLED, OnScsiAddDisabled)
	ON_BN_CLICKED(IDC_SCSI_DEL_DISABLED, OnScsiDelDisabled)
	ON_BN_CLICKED(IDC_SCSI_ADD_FROM, OnScsiAddFrom)
	ON_BN_CLICKED(IDC_SCSI_ADD_TO, OnScsiAddTo)
	ON_BN_CLICKED(IDC_SCSI_DEL_FROM, OnScsiDelFrom)
	ON_BN_CLICKED(IDC_SCSI_DEL_TO, OnScsiDelTo)
	ON_BN_CLICKED(IDC_SCSI_ENABLED, OnScsiEnabled)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageSCSI message handlers

BOOL CPageSCSI::in_list( CListBox &list, LPCSTR name ) 
{
	int i, count = list.GetCount();
	CString str;

	for(i=0; i<count; i++) {
		list.GetText(i, str);
		if(stricmp(str,name) == 0) return TRUE;
	}
	return FALSE;
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

static void parse( LPCSTR str, char *b1, char *b2 )
{
	char v1[VENDOR_LEN+1], p1[PRODUCT_LEN+1];
	char v2[VENDOR_LEN+1], p2[PRODUCT_LEN+1];

	*b1 = *b2 = 0;
	*v1 = *v2 = 0;
	*p1 = *p2 = 0;

	get_token(str,0,v1,VENDOR_LEN);
	get_token(str,1,p1,PRODUCT_LEN);
	get_token(str,2,v2,VENDOR_LEN);
	get_token(str,3,p2,PRODUCT_LEN);

	wsprintf( b1, "%s|%s", v1, p1 );
	if(*p2) {
		wsprintf( b2, "%s|%s", v2, p2 );
	} else {
		strcpy( b2, v2 );
	}
}

static void split( CString & s )
{
	char vendor[100], product[100], *p;

	strcpy( vendor, s );
	p = strchr( vendor, '|' );
	if(p) *p = 0;

	p = strchr( s, '|' );
	if(p) {
		p++;
		strcpy( product, p );
	} else {
		*product = 0;
	}

	if(*product) {
		s.Format( "\"%s\" \"%s\"", vendor, product );
	} else {
		s.Format( "\"%s\"", vendor );
	}
}

void CPageSCSI::enable_controls() 
{
	UpdateData(TRUE);
	GetDlgItem(IDC_SCSI_LIST_REPLACE_FROM)->EnableWindow(m_scsi_enabled);
	GetDlgItem(IDC_SCSI_LIST_REPLACE_TO)->EnableWindow(m_scsi_enabled);
	GetDlgItem(IDC_SCSI_ADD_FROM)->EnableWindow(m_scsi_enabled);
	GetDlgItem(IDC_SCSI_DEL_FROM)->EnableWindow(m_scsi_enabled);
	GetDlgItem(IDC_SCSI_ADD_TO)->EnableWindow(m_scsi_enabled);
	GetDlgItem(IDC_SCSI_DEL_TO)->EnableWindow(m_scsi_enabled);
	GetDlgItem(IDC_SCSI_LIST_DISABLED)->EnableWindow(m_scsi_enabled);
	GetDlgItem(IDC_SCSI_ADD_DISABLED)->EnableWindow(m_scsi_enabled);
	GetDlgItem(IDC_SCSI_DEL_DISABLED)->EnableWindow(m_scsi_enabled);
}

BOOL CPageSCSI::OnInitDialog() 
{
	int i, count;
	char buf1[256], buf2[256];

	CPropertyPage::OnInitDialog();

	SetCursor( LoadCursor( 0, IDC_WAIT ) );

	count = m_list_d.GetSize();
	for(i=0; i<count; i++) {
		CString str = m_list_d.GetAt(i);
		if(strncmp( str,"<Free SCSI slot", 15 ) == 0) {
			m_list_disabled.AddString( str );
		} else {
			parse( str, buf1, buf2 );
			m_list_disabled.AddString( buf1 );
		}
	}
	for(i=count; i<7; i++) {
		CString str;
		str.Format( "<Free SCSI slot %d>", i );
		m_list_disabled.AddString( str );
	}
	count = m_list_r.GetSize();
	for(i=0; i<count; i++) {
		parse( m_list_r.GetAt(i), buf1, buf2 );
		m_list_replace_from.AddString( buf1 );
		m_list_replace_to.AddString( buf2 );
	}

	SetPrefsFile( "~BasiliskII_prefs_file.tmp" );
	PrefsInit();
	PrefsReplaceBool( "noscsi", false );
	for(i=0; i<100; i++) PrefsRemoveItem("replacescsi");

	SCSI_set_buffer_alloc(false);
	SCSIInit();
	PrefsExit();
	SCSIExit();
	DeleteFile( "~BasiliskII_prefs_file.tmp" );
	SetCursor( LoadCursor( 0, IDC_ARROW ) );

	enable_controls();

	return TRUE;
}

void CPageSCSI::OnDestroy() 
{
	int i, count, count_to, count_from;
	CString str1, str2;

	m_list_d.RemoveAll();
	m_list_r.RemoveAll();

	count = m_list_disabled.GetCount();
	for(i=0; i<count; i++) {
		m_list_disabled.GetText(i,str1);
		if(strncmp( str1,"<Free SCSI slot", 15 ) == 0) {
			m_list_d.Add( str1 );
		} else {
			split( str1 );
			m_list_d.Add( str1 );
		}
	}

	count_from = m_list_replace_from.GetCount();
	count_to = m_list_replace_to.GetCount();
	count = min(count_from,count_to);
	for(i=0; i<count; i++) {
		m_list_replace_from.GetText(i,str1);
		split( str1 );
		m_list_replace_to.GetText(i,str2);
		split( str2 );
		m_list_r.Add( str1 + " " + str2 );
	}

	CPropertyPage::OnDestroy();
}

void CPageSCSI::OnScsiAddDisabled() 
{
  HMENU hmenu;
  POINT p;
	int i;

	hmenu = CreatePopupMenu();
	for(i=0; i<all_scsi_count; i++) {
		if(!in_list(m_list_disabled,all_scsi_names[i])) {
			AppendMenu( hmenu, MF_ENABLED|MF_STRING, MID_GUI_SCSI_FIRST_DISABLED+i, all_scsi_names[i] );
		}
	}
	GetCursorPos( &p );
	TrackPopupMenu( hmenu, TPM_LEFTALIGN, p.x, p.y, 0, GetSafeHwnd(), NULL );
}

void CPageSCSI::OnScsiDelDisabled() 
{
	int i = m_list_disabled.GetCurSel();
	if(i >= 0) {
		m_list_disabled.DeleteString(i);
		CString str;
		str.Format( "<Free SCSI slot %d>", i );
		m_list_disabled.InsertString(i, str);
		m_list_disabled.SetCurSel(i);
	}
}

BOOL CPageSCSI::confirm_DASD(const char *name) 
{
	CConfirmDASDDialog dlg;
	dlg.m_dasd_name = name;
	return( dlg.DoModal() == IDOK );
}

BOOL CPageSCSI::OnCommand(WPARAM wParam, LPARAM lParam) 
{
	int i;

	if((int)wParam >= MID_GUI_SCSI_FIRST_DISABLED && (int)wParam < MID_GUI_SCSI_FIRST_DISABLED+all_scsi_count) {
		wParam -= MID_GUI_SCSI_FIRST_DISABLED;
		for(i=0; i<all_scsi_count; i++) {
			if(!in_list(m_list_disabled,all_scsi_names[i])) {
				if(wParam == 0) {
					if(all_scsi_types[i] == DTYPE_DASD) {
						if(!confirm_DASD(all_scsi_names[i])) {
							break;
						}
					}
					int new_pos = -1;
					CString str;

					int sel_inx = m_list_disabled.GetCurSel();
					if(sel_inx >= 0) {
						m_list_disabled.GetText(sel_inx,str);
						if(strncmp( str,"<Free SCSI slot", 15 ) == 0) {
							new_pos = sel_inx;
						}
					}

					if(new_pos < 0) {
						for(new_pos=0; new_pos<7; new_pos++) {
							m_list_disabled.GetText(new_pos,str);
							if(strncmp( str,"<Free SCSI slot", 15 ) == 0) break;
						}
					}
					if(new_pos >= 7 || new_pos < 0) {
						AfxMessageBox( "No room for new SCSI device." );
					} else {
						m_list_disabled.DeleteString(new_pos);
						int j = m_list_disabled.InsertString(new_pos,all_scsi_names[i]);
						m_list_disabled.SetCurSel(j);
					}
					break;
				}
			}
			wParam--;
		}
	} else if((int)wParam >= MID_GUI_SCSI_FIRST_FROM && (int)wParam < MID_GUI_SCSI_FIRST_FROM+all_scsi_count) {
		wParam -= MID_GUI_SCSI_FIRST_FROM;
		for(i=0; i<all_scsi_count; i++) {
			if(!in_list(m_list_replace_from,all_scsi_names[i])) {
				if(wParam == 0) {
					int j = m_list_replace_from.AddString(all_scsi_names[i]);
					m_list_replace_from.SetCurSel(j);
					break;
				}
			}
			wParam--;
		}
	}
	
	return CPropertyPage::OnCommand(wParam, lParam);
}

void CPageSCSI::OnScsiAddFrom() 
{
  HMENU hmenu;
  POINT p;
	int i;

	hmenu = CreatePopupMenu();
	for(i=0; i<all_scsi_count; i++) {
		if(!in_list(m_list_replace_from,all_scsi_names[i])) {
			AppendMenu( hmenu, MF_ENABLED|MF_STRING, MID_GUI_SCSI_FIRST_FROM+i, all_scsi_names[i] );
		}
	}
	GetCursorPos( &p );
	TrackPopupMenu( hmenu, TPM_LEFTALIGN, p.x, p.y, 0, GetSafeHwnd(), NULL );
}

void CPageSCSI::OnScsiAddTo() 
{
	CAskSCSIReplacement dlg;
	CString str;

	if(dlg.DoModal() == IDOK) {
		dlg.m_vendor.TrimLeft();
		dlg.m_product.TrimLeft();
		if(dlg.m_vendor != "" && dlg.m_product != "") {
			str.Format( "%s|%s", dlg.m_vendor, dlg.m_product );
			int j = m_list_replace_to.AddString(str);
			m_list_replace_to.SetCurSel(j);
		}
	}
}

void CPageSCSI::OnScsiDelFrom() 
{
	int i = m_list_replace_from.GetCurSel();
	if(i >= 0) {
		m_list_replace_from.DeleteString(i);
	}
}

void CPageSCSI::OnScsiDelTo() 
{
	int i = m_list_replace_to.GetCurSel();
	if(i >= 0) {
		m_list_replace_to.DeleteString(i);
	}
}

void CPageSCSI::OnScsiEnabled() 
{
	UpdateData(TRUE);
	enable_controls();
}

