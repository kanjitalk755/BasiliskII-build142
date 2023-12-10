// ConfirmDASDDialog.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "ConfirmDASDDialog.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CConfirmDASDDialog dialog


CConfirmDASDDialog::CConfirmDASDDialog(CWnd* pParent /*=NULL*/)
	: CDialog(CConfirmDASDDialog::IDD, pParent)
{
	//{{AFX_DATA_INIT(CConfirmDASDDialog)
	m_dasd_name = _T("");
	//}}AFX_DATA_INIT
}


void CConfirmDASDDialog::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CConfirmDASDDialog)
	DDX_Text(pDX, IDC_DASD_NAME, m_dasd_name);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CConfirmDASDDialog, CDialog)
	//{{AFX_MSG_MAP(CConfirmDASDDialog)
		// NOTE: the ClassWizard will add message map macros here
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CConfirmDASDDialog message handlers
