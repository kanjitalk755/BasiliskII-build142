// MakeNewHFV.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "MakeNewHFV.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CMakeNewHFV dialog


CMakeNewHFV::CMakeNewHFV(CWnd* pParent /*=NULL*/)
	: CDialog(CMakeNewHFV::IDD, pParent)
{
	//{{AFX_DATA_INIT(CMakeNewHFV)
	m_path = _T("New.HFV");
	m_size = 10;
	//}}AFX_DATA_INIT
}


void CMakeNewHFV::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CMakeNewHFV)
	DDX_Text(pDX, IDC_MAKEHFV_NAME, m_path);
	DDV_MaxChars(pDX, m_path, 255);
	DDX_Text(pDX, IDC_MAKEHFV_SIZE, m_size);
	DDV_MinMaxInt(pDX, m_size, 1, 2000);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CMakeNewHFV, CDialog)
	//{{AFX_MSG_MAP(CMakeNewHFV)
	ON_BN_CLICKED(IDC_MAKEHFV_BROWSE, OnMakehfvBrowse)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CMakeNewHFV message handlers

void CMakeNewHFV::OnMakehfvBrowse() 
{
	if(UpdateData(TRUE)) {
		CFileDialog dlg( FALSE, _T("*"), m_path,
					OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT,
					_T("All Files|*.*||") );
		if(dlg.DoModal() == IDOK) {
			m_path = dlg.GetPathName();
			UpdateData(FALSE);
		}
	}
}
