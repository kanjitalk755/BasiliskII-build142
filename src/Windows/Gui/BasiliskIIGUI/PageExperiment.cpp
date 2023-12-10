// PageExperiment.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageExperiment.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageExperiment property page

IMPLEMENT_DYNCREATE(CPageExperiment, CPropertyPage)

CPageExperiment::CPageExperiment() : CPropertyPage(CPageExperiment::IDD)
{
	//{{AFX_DATA_INIT(CPageExperiment)
	//}}AFX_DATA_INIT
}

CPageExperiment::~CPageExperiment()
{
}

void CPageExperiment::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageExperiment)
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageExperiment, CPropertyPage)
	//{{AFX_MSG_MAP(CPageExperiment)
		// NOTE: the ClassWizard will add message map macros here
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageExperiment message handlers
