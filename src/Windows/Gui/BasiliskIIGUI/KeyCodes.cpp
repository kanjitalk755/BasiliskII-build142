// KeyCodes.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "KeyCodes.h"
#include "sysdeps.h"
#include "keyboard_windows.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CKeyCodes dialog


CKeyCodes::CKeyCodes(CWnd* pParent /*=NULL*/)
	: CDialog(CKeyCodes::IDD, pParent)
{
	//{{AFX_DATA_INIT(CKeyCodes)
	m_mac_code_list = _T("");
	//}}AFX_DATA_INIT

	m_inx = -1;
	m_path = "BasiliskII_keyboard";
}


void CKeyCodes::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CKeyCodes)
	DDX_CBString(pDX, IDC_K_LIST, m_mac_code_list);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CKeyCodes, CDialog)
	//{{AFX_MSG_MAP(CKeyCodes)
	ON_CBN_SELCHANGE(IDC_K_LIST, OnSelchangeKList)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CKeyCodes message handlers

static int dlg_2_index( int id )
{
	int i = 0;
	while(keymap[i].dlg_id) {
		if(keymap[i].dlg_id == id) return(i);
		i++;
	}
	return(-1);
}

static void get_name_by_index( int i, char *name, int sz )
{
	*name = 0;
	int x = (keymap[i].scan_code << 16) | (keymap[i].extended << 24);
	GetKeyNameText( x, name, sz );
}

static void get_name_by_dlg_id( int id, char *name, int sz )
{
	int i;

	i = dlg_2_index(id);
	if(i >= 0) {
		get_name_by_index( i, name, sz );
	} else {
		*name = 0;
	}
}

BOOL CKeyCodes::OnInitDialog() 
{
	CDialog::OnInitDialog();

	int i = 0;
	// int vk;
	char name[100];

	SetCursor( LoadCursor( 0, IDC_WAIT ) );

	load_key_codes( m_path, keymap );

	while(keymap[i].dlg_id) {
		// vk = (int)MapVirtualKey( keymap[i].scan_code, 3 );
		if(keymap[i].show_name) {
			get_name_by_index( i, name, sizeof(name) );
		} else {
			*name = 0;
		}
		GetDlgItem(keymap[i].dlg_id)->SetWindowText( name );
		i++;
	}

	SetCursor( LoadCursor( 0, IDC_ARROW ) );

	return TRUE;
}

void CKeyCodes::key_change( int dlg_id ) 
{
	char name[100], mac_str[100];
	int i;

	i = dlg_2_index(dlg_id);
	if(i >= 0) {
		m_inx = i;
		get_name_by_dlg_id( dlg_id, name, sizeof(name) );
		GetDlgItem(IDC_K_FRIENDLY_NAME)->SetWindowText( name );
		wsprintf( mac_str, "0x%02X", keymap[i].mac );
		m_mac_code_list = mac_str;
		UpdateData(FALSE);
	}
}

BOOL CKeyCodes::OnCommand(WPARAM wParam, LPARAM lParam) 
{
	key_change(LOWORD(wParam));
	
	return CDialog::OnCommand(wParam, lParam);
}

void CKeyCodes::OnSelchangeKList() 
{
	if(m_inx >= 0) {
		UpdateData(TRUE);
		keymap[m_inx].mac = strtoul( m_mac_code_list, 0, 0 );
	}
}

void CKeyCodes::OnOK() 
{
	save_key_codes( m_path, keymap );
	CDialog::OnOK();
}
