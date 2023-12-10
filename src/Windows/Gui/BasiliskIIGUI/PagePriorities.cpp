// PagePriorities.cpp : implementation file
//

#include "stdafx.h"
#include "sysdeps.h"
#include "prefs.h"
#include "main_windows.h"
#include "threads_windows.h"
#include "BasiliskIIGUI.h"
#include "PagePriorities.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPagePriorities property page

IMPLEMENT_DYNCREATE(CPagePriorities, CPropertyPage)

CPagePriorities::CPagePriorities() : CPropertyPage(CPagePriorities::IDD)
{
	//{{AFX_DATA_INIT(CPagePriorities)
	m_1hz_idle = -1;
	m_1hz_run = -1;
	m_60hz_idle = -1;
	m_60hz_run = -1;
	m_cpu_idle = -1;
	m_cpu_run = -1;
	m_dx_idle = -1;
	m_dx_run = -1;
	m_ethernet_idle = -1;
	m_ethernet_run = -1;
	m_gdi_idle = -1;
	m_gdi_run = -1;
	m_lfb_idle = -1;
	m_lfb_run = -1;
	m_gui_idle = -1;
	m_gui_run = -1;
	m_pram_idle = -1;
	m_pram_run = -1;
	m_serial_in_idle = -1;
	m_serial_in_run = -1;
	m_serial_out_idle = -1;
	m_serial_out_run = -1;
	m_sound_stream_idle = -1;
	m_sound_stream_run = -1;
	//}}AFX_DATA_INIT
}

CPagePriorities::~CPagePriorities()
{
}

void CPagePriorities::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPagePriorities)
	DDX_CBIndex(pDX, IDC_PRI_1HZ_IDLE, m_1hz_idle);
	DDX_CBIndex(pDX, IDC_PRI_1HZ_RUN, m_1hz_run);
	DDX_CBIndex(pDX, IDC_PRI_60HZ_IDLE, m_60hz_idle);
	DDX_CBIndex(pDX, IDC_PRI_60HZ_RUN, m_60hz_run);
	DDX_CBIndex(pDX, IDC_PRI_CPU_IDLE, m_cpu_idle);
	DDX_CBIndex(pDX, IDC_PRI_CPU_RUN, m_cpu_run);
	DDX_CBIndex(pDX, IDC_PRI_DX_IDLE, m_dx_idle);
	DDX_CBIndex(pDX, IDC_PRI_DX_RUN, m_dx_run);
	DDX_CBIndex(pDX, IDC_PRI_ETHERNET_IDLE, m_ethernet_idle);
	DDX_CBIndex(pDX, IDC_PRI_ETHERNET_RUN, m_ethernet_run);
	DDX_CBIndex(pDX, IDC_PRI_GDI_IDLE, m_gdi_idle);
	DDX_CBIndex(pDX, IDC_PRI_GDI_RUN, m_gdi_run);
	DDX_CBIndex(pDX, IDC_PRI_LFB_IDLE, m_lfb_idle);
	DDX_CBIndex(pDX, IDC_PRI_LFB_RUN, m_lfb_run);
	DDX_CBIndex(pDX, IDC_PRI_MOUSE_IDLE, m_gui_idle);
	DDX_CBIndex(pDX, IDC_PRI_MOUSE_RUN, m_gui_run);
	DDX_CBIndex(pDX, IDC_PRI_PRAM_IDLE, m_pram_idle);
	DDX_CBIndex(pDX, IDC_PRI_PRAM_RUN, m_pram_run);
	DDX_CBIndex(pDX, IDC_PRI_SERIAL_IN_IDLE, m_serial_in_idle);
	DDX_CBIndex(pDX, IDC_PRI_SERIAL_IN_RUN, m_serial_in_run);
	DDX_CBIndex(pDX, IDC_PRI_SERIAL_OUT_IDLE, m_serial_out_idle);
	DDX_CBIndex(pDX, IDC_PRI_SERIAL_OUT_RUN, m_serial_out_run);
	DDX_CBIndex(pDX, IDC_PRI_SOUND_STREAM_IDLE, m_sound_stream_idle);
	DDX_CBIndex(pDX, IDC_PRI_SOUND_STREAM_RUN, m_sound_stream_run);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPagePriorities, CPropertyPage)
	//{{AFX_MSG_MAP(CPagePriorities)
	ON_CBN_SELCHANGE(IDC_PRI_SERIAL_IN_RUN, OnSelchangePriSerialInRun)
	ON_CBN_SELCHANGE(IDC_PRI_SERIAL_OUT_RUN, OnSelchangePriSerialOutRun)
	ON_BN_CLICKED(IDC_PRI_DEFAULTS, OnPriDefaults)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPagePriorities message handlers

void CPagePriorities::OnSelchangePriSerialInRun() 
{
	UpdateData(TRUE);
	m_serial_in_idle = m_serial_in_run;
	UpdateData(FALSE);
}

void CPagePriorities::OnSelchangePriSerialOutRun() 
{
	UpdateData(TRUE);
	m_serial_out_idle = m_serial_out_run;
	UpdateData(FALSE);
}

void CPagePriorities::from_threads() 
{
	m_1hz_idle				= 2 + threads[THREAD_1_HZ].priority_suspended;
	m_1hz_run					= 2 + threads[THREAD_1_HZ].priority_running;
	m_60hz_idle				= 2 + threads[THREAD_60_HZ].priority_suspended;
	m_60hz_run				= 2 + threads[THREAD_60_HZ].priority_running;
	m_cpu_idle				= 2 + threads[THREAD_CPU].priority_suspended;
	m_cpu_run					= 2 + threads[THREAD_CPU].priority_running;
	m_dx_idle					= 2 + threads[THREAD_SCREEN_DX].priority_suspended;
	m_dx_run					= 2 + threads[THREAD_SCREEN_DX].priority_running;
	m_ethernet_idle		= 2 + threads[THREAD_ETHER].priority_suspended;
	m_ethernet_run		= 2 + threads[THREAD_ETHER].priority_running;
	m_gdi_idle				= 2 + threads[THREAD_SCREEN_GDI].priority_suspended;
	m_gdi_run					= 2 + threads[THREAD_SCREEN_GDI].priority_running;
	m_lfb_idle				= 2 + threads[THREAD_SCREEN_LFB].priority_suspended;
	m_lfb_run					= 2 + threads[THREAD_SCREEN_LFB].priority_running;
	m_gui_idle				= 2 + threads[THREAD_GUI].priority_suspended;
	m_gui_run					= 2 + threads[THREAD_GUI].priority_running;
	m_pram_idle				= 2 + threads[THREAD_PARAMETER_RAM].priority_suspended;
	m_pram_run				= 2 + threads[THREAD_PARAMETER_RAM].priority_running;
	m_serial_in_idle	= 2 + threads[THREAD_SERIAL_IN].priority_suspended;
	m_serial_in_run		= 2 + threads[THREAD_SERIAL_IN].priority_running;
	m_serial_out_idle = 2 + threads[THREAD_SERIAL_OUT].priority_suspended;
	m_serial_out_run	= 2 + threads[THREAD_SERIAL_OUT].priority_running;
	m_sound_stream_idle = 2 + threads[THREAD_SOUND_STREAM].priority_suspended;
	m_sound_stream_run	= 2 + threads[THREAD_SOUND_STREAM].priority_running;
}

void CPagePriorities::OnPriDefaults() 
{
	for( int i=0; i<THREAD_COUNT; i++ ) {
		threads[i].priority_running = threads[i].def_priority_running;
		threads[i].priority_suspended = threads[i].def_priority_suspended;
	}
	from_threads();
	UpdateData(FALSE);
}
