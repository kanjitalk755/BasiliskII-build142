// AskSCSIReplacement.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "AskSCSIReplacement.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CAskSCSIReplacement dialog


CAskSCSIReplacement::CAskSCSIReplacement(CWnd* pParent /*=NULL*/)
	: CDialog(CAskSCSIReplacement::IDD, pParent)
{
	//{{AFX_DATA_INIT(CAskSCSIReplacement)
	m_product = _T("");
	m_vendor = _T("");
	//}}AFX_DATA_INIT
}


void CAskSCSIReplacement::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CAskSCSIReplacement)
	DDX_Text(pDX, IDC_SCSIREPL_PRODUCT, m_product);
	DDV_MaxChars(pDX, m_product, 16);
	DDX_Text(pDX, IDC_SCSIREPL_VENDOR, m_vendor);
	DDV_MaxChars(pDX, m_vendor, 8);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CAskSCSIReplacement, CDialog)
	//{{AFX_MSG_MAP(CAskSCSIReplacement)
		// NOTE: the ClassWizard will add message map macros here
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CAskSCSIReplacement message handlers
