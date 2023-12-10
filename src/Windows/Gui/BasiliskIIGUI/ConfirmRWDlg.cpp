// ConfirmRWDlg.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "ConfirmRWDlg.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CConfirmRWDlg dialog


CConfirmRWDlg::CConfirmRWDlg(CWnd* pParent /*=NULL*/)
	: CDialog(CConfirmRWDlg::IDD, pParent)
{
	//{{AFX_DATA_INIT(CConfirmRWDlg)
	m_path = _T("");
	//}}AFX_DATA_INIT
}


void CConfirmRWDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CConfirmRWDlg)
	DDX_Text(pDX, IDC_PATH_TO_MOUNT, m_path);
	DDV_MaxChars(pDX, m_path, 256);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CConfirmRWDlg, CDialog)
	//{{AFX_MSG_MAP(CConfirmRWDlg)
		// NOTE: the ClassWizard will add message map macros here
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CConfirmRWDlg message handlers
