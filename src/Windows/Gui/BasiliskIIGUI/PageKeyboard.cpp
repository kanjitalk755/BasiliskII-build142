// PageKeyboard.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageKeyboard.h"
#include "KeyCodes.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageKeyboard property page

IMPLEMENT_DYNCREATE(CPageKeyboard, CPropertyPage)

CPageKeyboard::CPageKeyboard() : CPropertyPage(CPageKeyboard::IDD)
{
	//{{AFX_DATA_INIT(CPageKeyboard)
	m_keyboard_path = _T("");
	m_use_alt_escape = FALSE;
	m_use_alt_tab = FALSE;
	m_use_control_escape = FALSE;
	m_use_alt_space = FALSE;
	m_use_alt_enter = FALSE;
	m_keyboard_type = _T("");
	//}}AFX_DATA_INIT
}

CPageKeyboard::~CPageKeyboard()
{
}

void CPageKeyboard::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageKeyboard)
	DDX_Text(pDX, IDC_KEYBOARD_MAP_FILE_PATH, m_keyboard_path);
	DDX_Check(pDX, IDC_KEYBOARD_USE_ALT_ESCAPE, m_use_alt_escape);
	DDX_Check(pDX, IDC_KEYBOARD_USE_ALT_TAB, m_use_alt_tab);
	DDX_Check(pDX, IDC_KEYBOARD_USE_CONTROL_ESCAPE, m_use_control_escape);
	DDX_Check(pDX, IDC_KEYBOARD_USE_ALT_SPACE, m_use_alt_space);
	DDX_Check(pDX, IDC_KEYBOARD_USE_ALT_ENTER, m_use_alt_enter);
	DDX_CBString(pDX, IDC_KEYBOARD_TYPE, m_keyboard_type);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageKeyboard, CPropertyPage)
	//{{AFX_MSG_MAP(CPageKeyboard)
	ON_BN_CLICKED(IDC_KEYBOARD_EDIT_CODES, OnKeyboardEditCodes)
	ON_BN_CLICKED(IDC_KEYBOARD_MAP_BROWSE, OnKeyboardMapBrowse)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageKeyboard message handlers

void CPageKeyboard::OnKeyboardEditCodes() 
{
	if(UpdateData(TRUE)) {
		if(strchr(m_keyboard_path,'\\') == 0) {
			m_keyboard_path = ((CBasiliskIIGUIApp*)AfxGetApp())->m_dir + m_keyboard_path;
		}
		CKeyCodes dlg;
		dlg.m_path = m_keyboard_path;
		dlg.DoModal();
	}
}

void CPageKeyboard::OnKeyboardMapBrowse() 
{
	if(UpdateData(TRUE)) {
		CFileDialog dlg( FALSE, _T(""), m_keyboard_path,
					OFN_HIDEREADONLY /* | OFN_OVERWRITEPROMPT*/,
					_T("All Files|*.*||") );
		if(dlg.DoModal() == IDOK) {
			m_keyboard_path = dlg.GetPathName();
			UpdateData(FALSE);
		}
	}
}
