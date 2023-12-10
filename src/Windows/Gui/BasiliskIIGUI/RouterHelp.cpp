// RouterHelp.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "RouterHelp.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// RouterHelp dialog


RouterHelp::RouterHelp(CWnd* pParent /*=NULL*/)
	: CDialog(RouterHelp::IDD, pParent)
{
	//{{AFX_DATA_INIT(RouterHelp)
		// NOTE: the ClassWizard will add member initialization here
	//}}AFX_DATA_INIT
}


void RouterHelp::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(RouterHelp)
		// NOTE: the ClassWizard will add DDX and DDV calls here
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(RouterHelp, CDialog)
	//{{AFX_MSG_MAP(RouterHelp)
		// NOTE: the ClassWizard will add message map macros here
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// RouterHelp message handlers
