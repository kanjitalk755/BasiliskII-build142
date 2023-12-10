// PageDebug.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageDebug.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageDebug property page

IMPLEMENT_DYNCREATE(CPageDebug, CPropertyPage)

CPageDebug::CPageDebug() : CPropertyPage(CPageDebug::IDD)
{
	//{{AFX_DATA_INIT(CPageDebug)
	m_debug_scsi = -1;
	m_debug_filesys = -1;
	m_debug_serial = -1;
	m_debug_disable_accurate_timer = FALSE;
	//}}AFX_DATA_INIT
}

CPageDebug::~CPageDebug()
{
}

void CPageDebug::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageDebug)
	DDX_CBIndex(pDX, IDC_DEBUG_SCSI_LOG_LEVEL, m_debug_scsi);
	DDX_CBIndex(pDX, IDC_DEBUG_FILESYS_LOG_LEVEL, m_debug_filesys);
	DDX_CBIndex(pDX, IDC_DEBUG_SERIAL_LOG_LEVEL, m_debug_serial);
	DDX_Check(pDX, IDC_DEBUG_DISABLE_ACCURATE_TIMER, m_debug_disable_accurate_timer);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageDebug, CPropertyPage)
	//{{AFX_MSG_MAP(CPageDebug)
		// NOTE: the ClassWizard will add message map macros here
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageDebug message handlers
