// PagePorts.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PagePorts.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPagePorts property page

IMPLEMENT_DYNCREATE(CPagePorts, CPropertyPage)

CPagePorts::CPagePorts() : CPropertyPage(CPagePorts::IDD)
{
	//{{AFX_DATA_INIT(CPagePorts)
	m_seriala = _T("");
	m_serialb = _T("");
	m_portfile0 = _T("");
	m_portfile1 = _T("");
	//}}AFX_DATA_INIT
}

CPagePorts::~CPagePorts()
{
}

void CPagePorts::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPagePorts)
	DDX_CBString(pDX, IDC_PORTS_MODEM, m_seriala);
	DDV_MaxChars(pDX, m_seriala, 5);
	DDX_CBString(pDX, IDC_PORTS_PRINTER, m_serialb);
	DDV_MaxChars(pDX, m_serialb, 5);
	DDX_Text(pDX, IDC_PORTS_FILE0, m_portfile0);
	DDV_MaxChars(pDX, m_portfile0, 255);
	DDX_Text(pDX, IDC_PORTS_FILE1, m_portfile1);
	DDV_MaxChars(pDX, m_portfile1, 255);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPagePorts, CPropertyPage)
	//{{AFX_MSG_MAP(CPagePorts)
	ON_CBN_SELCHANGE(IDC_PORTS_MODEM, OnSelchangePortsModem)
	ON_CBN_SELCHANGE(IDC_PORTS_PRINTER, OnSelchangePortsPrinter)
	ON_BN_CLICKED(IDC_PORTS_FILE0_BROWSE, OnPortsFile0Browse)
	ON_BN_CLICKED(IDC_PORTS_FILE1_BROWSE, OnPortsFile1Browse)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPagePorts message handlers

void CPagePorts::update_buttons() 
{
	UpdateData(TRUE);

	BOOL enable_a = (m_seriala.CompareNoCase("FILE") == 0);

	GetDlgItem(IDC_PORTS_FILE0)->EnableWindow(enable_a);
	GetDlgItem(IDC_PORTS_FILE0_BROWSE)->EnableWindow(enable_a);

	BOOL enable_b = (m_serialb.CompareNoCase("FILE") == 0);

	GetDlgItem(IDC_PORTS_FILE1)->EnableWindow(enable_b);
	GetDlgItem(IDC_PORTS_FILE1_BROWSE)->EnableWindow(enable_b);
}

void CPagePorts::OnSelchangePortsModem() 
{
	update_buttons();
}

void CPagePorts::OnSelchangePortsPrinter() 
{
	update_buttons();
}

BOOL CPagePorts::OnInitDialog() 
{
	CPropertyPage::OnInitDialog();
	update_buttons();
	return TRUE;
}

void CPagePorts::OnPortsFile0Browse() 
{
	if(UpdateData(TRUE)) {
		CFileDialog dlg( FALSE, _T("*"), m_portfile0,
					OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT,
					_T("All Files|*.*||") );
		dlg.m_ofn.lpstrTitle = "Save Modem port output to file";
		if(dlg.DoModal() == IDOK) {
			m_portfile0 = dlg.GetPathName();
			UpdateData(FALSE);
		}
	}
}

void CPagePorts::OnPortsFile1Browse() 
{
	if(UpdateData(TRUE)) {
		CFileDialog dlg( FALSE, _T("*"), m_portfile1,
					OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT,
					_T("All Files|*.*||") );
		dlg.m_ofn.lpstrTitle = "Save Printer port output to file";
		if(dlg.DoModal() == IDOK) {
			m_portfile1 = dlg.GetPathName();
			UpdateData(FALSE);
		}
	}
}
