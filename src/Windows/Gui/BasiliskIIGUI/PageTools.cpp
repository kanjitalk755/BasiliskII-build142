// PageTools.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageTools.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageTools property page

IMPLEMENT_DYNCREATE(CPageTools, CPropertyPage)

CPageTools::CPageTools() : CPropertyPage(CPageTools::IDD)
{
	//{{AFX_DATA_INIT(CPageTools)
	m_is_on_top = FALSE;
	m_gui_autorestart = -1;
	m_lowmem_cache = FALSE;
	m_sleep = 0;
	m_sleep_enabled = FALSE;
	m_idle_sleep_timeout = 0;
	m_disable_screensaver = FALSE;
	//}}AFX_DATA_INIT
}

CPageTools::~CPageTools()
{
}

void CPageTools::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageTools)
	DDX_Check(pDX, IDC_TOOLS_IS_ON_TOP, m_is_on_top);
	DDX_CBIndex(pDX, IDC_TOOLS_GUI_AUTORESTART, m_gui_autorestart);
	DDX_Check(pDX, IDC_EXPERIMENT_LOWMEM_CACHE, m_lowmem_cache);
	DDX_Text(pDX, IDC_TOOLS_IDLE_SLEEP, m_sleep);
	DDV_MinMaxUInt(pDX, m_sleep, 1, 30);
	DDX_Check(pDX, IDC_TOOLS_SLEEP_ENABLED, m_sleep_enabled);
	DDX_Text(pDX, IDC_TOOLS_IDLE_MINUTES, m_idle_sleep_timeout);
	DDV_MinMaxUInt(pDX, m_idle_sleep_timeout, 0, 999999);
	DDX_Check(pDX, IDC_TOOLS_DISABLE_SCREENSAVER, m_disable_screensaver);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageTools, CPropertyPage)
	//{{AFX_MSG_MAP(CPageTools)
	ON_EN_UPDATE(IDC_TOOLS_IDLE_MINUTES, OnUpdateToolsIdleMinutes)
	ON_BN_CLICKED(IDC_TOOLS_SLEEP_ENABLED, OnToolsSleepEnabled)
	ON_EN_UPDATE(IDC_TOOLS_IDLE_SLEEP, OnUpdateToolsIdleSleep)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageTools message handlers


void CPageTools::enable_buttons() 
{
	BOOL enable = m_idle_sleep_timeout == 0;

	if(!enable) {
		m_sleep_enabled = false;
		UpdateData(FALSE);
	}
	GetDlgItem(IDC_TOOLS_SLEEP_ENABLED)->EnableWindow(enable);
	GetDlgItem(IDC_TOOLS_IDLE_SLEEP)->EnableWindow(m_sleep_enabled || m_idle_sleep_timeout > 0);
}

void CPageTools::OnUpdateToolsIdleMinutes() 
{
	if(UpdateData(TRUE)) {
		enable_buttons();
	}
}

BOOL CPageTools::OnInitDialog() 
{
	CPropertyPage::OnInitDialog();
	enable_buttons();
	return TRUE;
}

void CPageTools::OnToolsSleepEnabled() 
{
	if(UpdateData(TRUE)) {
		enable_buttons();
	}
}

void CPageTools::OnUpdateToolsIdleSleep() 
{
	// just validate
	UpdateData(TRUE);
}
