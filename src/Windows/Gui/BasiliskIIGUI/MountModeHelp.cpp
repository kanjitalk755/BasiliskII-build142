// MountModeHelp.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "MountModeHelp.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CMountModeHelp dialog


CMountModeHelp::CMountModeHelp(CWnd* pParent /*=NULL*/)
	: CDialog(CMountModeHelp::IDD, pParent)
{
	//{{AFX_DATA_INIT(CMountModeHelp)
		// NOTE: the ClassWizard will add member initialization here
	//}}AFX_DATA_INIT
}


void CMountModeHelp::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CMountModeHelp)
		// NOTE: the ClassWizard will add DDX and DDV calls here
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CMountModeHelp, CDialog)
	//{{AFX_MSG_MAP(CMountModeHelp)
		// NOTE: the ClassWizard will add message map macros here
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CMountModeHelp message handlers
