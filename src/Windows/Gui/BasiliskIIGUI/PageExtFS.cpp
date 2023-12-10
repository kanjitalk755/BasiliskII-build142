// PageExtFS.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageExtFS.h"
#include "FileTypeMapping.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageExtFS property page

IMPLEMENT_DYNCREATE(CPageExtFS, CPropertyPage)

CPageExtFS::CPageExtFS() : CPropertyPage(CPageExtFS::IDD)
{
	//{{AFX_DATA_INIT(CPageExtFS)
	m_enabled = FALSE;
	m_a = FALSE;
	m_b = FALSE;
	m_c = FALSE;
	m_d = FALSE;
	m_e = FALSE;
	m_f = FALSE;
	m_g = FALSE;
	m_h = FALSE;
	m_i = FALSE;
	m_j = FALSE;
	m_k = FALSE;
	m_l = FALSE;
	m_m = FALSE;
	m_n = FALSE;
	m_o = FALSE;
	m_p = FALSE;
	m_q = FALSE;
	m_r = FALSE;
	m_s = FALSE;
	m_t = FALSE;
	m_u = FALSE;
	m_v = FALSE;
	m_w = FALSE;
	m_x = FALSE;
	m_y = FALSE;
	m_z = FALSE;
	m_path = _T("");
	//}}AFX_DATA_INIT
}

CPageExtFS::~CPageExtFS()
{
}

void CPageExtFS::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageExtFS)
	DDX_Check(pDX, IDC_EXTFS_ENABLED, m_enabled);
	DDX_Check(pDX, IDC_EXTFS_A, m_a);
	DDX_Check(pDX, IDC_EXTFS_B, m_b);
	DDX_Check(pDX, IDC_EXTFS_C, m_c);
	DDX_Check(pDX, IDC_EXTFS_D, m_d);
	DDX_Check(pDX, IDC_EXTFS_E, m_e);
	DDX_Check(pDX, IDC_EXTFS_F, m_f);
	DDX_Check(pDX, IDC_EXTFS_G, m_g);
	DDX_Check(pDX, IDC_EXTFS_H, m_h);
	DDX_Check(pDX, IDC_EXTFS_I, m_i);
	DDX_Check(pDX, IDC_EXTFS_J, m_j);
	DDX_Check(pDX, IDC_EXTFS_K, m_k);
	DDX_Check(pDX, IDC_EXTFS_L, m_l);
	DDX_Check(pDX, IDC_EXTFS_M, m_m);
	DDX_Check(pDX, IDC_EXTFS_N, m_n);
	DDX_Check(pDX, IDC_EXTFS_O, m_o);
	DDX_Check(pDX, IDC_EXTFS_P, m_p);
	DDX_Check(pDX, IDC_EXTFS_Q, m_q);
	DDX_Check(pDX, IDC_EXTFS_R, m_r);
	DDX_Check(pDX, IDC_EXTFS_S, m_s);
	DDX_Check(pDX, IDC_EXTFS_T, m_t);
	DDX_Check(pDX, IDC_EXTFS_U, m_u);
	DDX_Check(pDX, IDC_EXTFS_V, m_v);
	DDX_Check(pDX, IDC_EXTFS_W, m_w);
	DDX_Check(pDX, IDC_EXTFS_X, m_x);
	DDX_Check(pDX, IDC_EXTFS_Y, m_y);
	DDX_Check(pDX, IDC_EXTFS_Z, m_z);
	DDX_Text(pDX, IDC_EXTFS_PATH, m_path);
	DDV_MaxChars(pDX, m_path, 255);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageExtFS, CPropertyPage)
	//{{AFX_MSG_MAP(CPageExtFS)
	ON_BN_CLICKED(IDC_EXTFS_TYPES, OnExtfsTypes)
	ON_BN_CLICKED(IDC_EXTFS_ENABLED, OnExtfsEnabled)
	ON_BN_CLICKED(IDC_EXTFS_NONE, OnExtfsNone)
	ON_BN_CLICKED(IDC_EXTFS_ALL, OnExtfsAll)
	ON_BN_CLICKED(IDC_EXTFS_BROWSE_PATH, OnExtfsBrowsePath)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageExtFS message handlers

void CPageExtFS::OnExtfsTypes() 
{
	CFileTypeMapping dlg;
	dlg.m_path = m_path;
	dlg.DoModal();
}

void CPageExtFS::enable_controls()
{
	UpdateData(TRUE);
	for( char letter = 'A'; letter <= 'Z'; letter++ ) {
		BOOL enable = m_enabled;
		BOOL uncheck = FALSE;
		int id = IDC_EXTFS_A + letter - 'A';
		char rootdir[20];
		wsprintf( rootdir, "%c:\\", letter );
		switch(GetDriveType(rootdir)) {
			case DRIVE_REMOVABLE:
			case DRIVE_FIXED:
			case DRIVE_REMOTE:
			case DRIVE_CDROM:
			case DRIVE_RAMDISK:
				break;
			default:
				enable = FALSE;
				uncheck = TRUE;
				break;
		}
		GetDlgItem(id)->EnableWindow(enable);
		if(uncheck) CheckDlgButton(id, 0);
	}
	GetDlgItem(IDC_EXTFS_TYPES)->EnableWindow(m_enabled);
	GetDlgItem(IDC_EXTFS_ALL)->EnableWindow(m_enabled);
	GetDlgItem(IDC_EXTFS_NONE)->EnableWindow(m_enabled);
	GetDlgItem(IDC_EXTFS_PATH)->EnableWindow(m_enabled);
	GetDlgItem(IDC_EXTFS_BROWSE_PATH)->EnableWindow(m_enabled);
}

BOOL CPageExtFS::OnInitDialog() 
{
	CPropertyPage::OnInitDialog();
	enable_controls();
	return TRUE;
}

void CPageExtFS::OnExtfsEnabled() 
{
	UpdateData(TRUE);
	enable_controls();
	UpdateData(FALSE);
}

void CPageExtFS::select_controls(int select)
{
	for( char letter = 'A'; letter <= 'Z'; letter++ ) {
		int id = IDC_EXTFS_A + letter - 'A';
		if(GetDlgItem(id)->IsWindowEnabled()) CheckDlgButton(id, select);
	}
}

void CPageExtFS::OnExtfsNone() 
{
	UpdateData(TRUE);
	select_controls(FALSE);
}

void CPageExtFS::OnExtfsAll() 
{
	UpdateData(TRUE);
	select_controls(TRUE);
}

void CPageExtFS::OnExtfsBrowsePath() 
{
	if(UpdateData(TRUE)) {
		CFileDialog dlg( TRUE, _T("FTM"), m_path,
					OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT,
					_T("Type mapping files (*.ftm)|*.ftm|All Files|*.*||") );
		if(dlg.DoModal() == IDOK) {
			m_path = dlg.GetPathName();
			UpdateData(FALSE);
		}
	}
}
