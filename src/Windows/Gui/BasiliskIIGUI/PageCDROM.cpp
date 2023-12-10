// PageCDROM.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageCDROM.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageCDROM property page

IMPLEMENT_DYNCREATE(CPageCDROM, CPropertyPage)

CPageCDROM::CPageCDROM() : CPropertyPage(CPageCDROM::IDD)
{
	//{{AFX_DATA_INIT(CPageCDROM)
	m_cd_enabled = FALSE;
	m_realmodecd = FALSE;
	//}}AFX_DATA_INIT
}

CPageCDROM::~CPageCDROM()
{
}

void CPageCDROM::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageCDROM)
	DDX_Control(pDX, IDC_CD_LIST_AVAILABLE, m_list_available);
	DDX_Control(pDX, IDC_CD_LIST_INSTALLED, m_list_installed);
	DDX_Check(pDX, IDC_CD_ENABLED, m_cd_enabled);
	DDX_Check(pDX, IDC_CD_REAL_MODE_CD, m_realmodecd);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageCDROM, CPropertyPage)
	//{{AFX_MSG_MAP(CPageCDROM)
	ON_BN_CLICKED(IDC_CD_INSTALL, OnCdInstall)
	ON_BN_CLICKED(IDC_CD_DOWN, OnCdDown)
	ON_BN_CLICKED(IDC_CD_REMOVE, OnCdRemove)
	ON_BN_CLICKED(IDC_CD_UP, OnCdUp)
	ON_WM_DESTROY()
	ON_LBN_DBLCLK(IDC_CD_LIST_INSTALLED, OnDblclkCdListInstalled)
	ON_LBN_DBLCLK(IDC_CD_LIST_AVAILABLE, OnDblclkCdListAvailable)
	ON_BN_CLICKED(IDC_CD_ENABLED, OnCdEnabled)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageCDROM message handlers

void CPageCDROM::enable_controls() 
{
	UpdateData(TRUE);
	GetDlgItem(IDC_CD_LIST_INSTALLED)->EnableWindow(m_cd_enabled);
	GetDlgItem(IDC_CD_LIST_AVAILABLE)->EnableWindow(m_cd_enabled);
	GetDlgItem(IDC_CD_INSTALL)->EnableWindow(m_cd_enabled);
	GetDlgItem(IDC_CD_REMOVE)->EnableWindow(m_cd_enabled);
	GetDlgItem(IDC_CD_UP)->EnableWindow(m_cd_enabled);
	GetDlgItem(IDC_CD_DOWN)->EnableWindow(m_cd_enabled);
	GetDlgItem(IDC_CD_REAL_MODE_CD)->EnableWindow(m_cd_enabled);
}

void CPageCDROM::OnCdInstall() 
{
	int i, j = m_list_available.GetCurSel();
	CString name;

	if(j >= 0) {
		m_list_available.GetText(j, name);
		m_list_available.DeleteString(j);
		i = m_list_installed.AddString(name);
		m_list_installed.SetCurSel(i); // -1 is ok
	}
}

void CPageCDROM::OnCdRemove() 
{
	int i = m_list_installed.GetCurSel(), j;
	CString name;

	if(i >= 0) {
		m_list_installed.GetText(i, name);
		m_list_installed.DeleteString(i);
		j = m_list_available.AddString(name);
		m_list_available.SetCurSel(j); // -1 is ok
	}
}

void CPageCDROM::OnCdDown() 
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

void CPageCDROM::OnCdUp() 
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

BOOL CPageCDROM::OnInitDialog() 
{
	int i, count;
	char rootdir[20], letter;

	CPropertyPage::OnInitDialog();

	count = m_list.GetSize();
	for(i=0; i<count; i++) {
		m_list_installed.AddString( m_list.GetAt(i) );
	}
	for( letter = 'C'; letter <= 'Z'; letter++ ) {
		wsprintf( rootdir, "%c:\\", letter );
		if(GetDriveType( rootdir ) == DRIVE_CDROM) {
			for(i=0; i<count; i++) {
				if( stricmp(rootdir,m_list.GetAt(i)) == 0 ) break;
			}
			if( i == count ) {
				m_list_available.AddString( rootdir );
			}
		}
	}

	enable_controls();
	
	return TRUE;
}

void CPageCDROM::OnDestroy() 
{
	CPropertyPage::OnDestroy();
	
	int i, count;
	CString str;

	m_list.RemoveAll();
	
	count = m_list_installed.GetCount();
	for(i=0; i<count; i++) {
		m_list_installed.GetText(i, str);
		m_list.Add(str);
	}
}

void CPageCDROM::OnDblclkCdListInstalled() 
{
	OnCdRemove();
}

void CPageCDROM::OnDblclkCdListAvailable() 
{
	OnCdInstall();
}

void CPageCDROM::OnCdEnabled() 
{
	UpdateData(TRUE);
	enable_controls();
}
