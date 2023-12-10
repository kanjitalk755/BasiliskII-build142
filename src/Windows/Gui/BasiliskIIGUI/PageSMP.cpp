#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageSMP.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

#define MAX_CPUS 8

/////////////////////////////////////////////////////////////////////////////
// CPageSMP property page

IMPLEMENT_DYNCREATE(CPageSMP, CPropertyPage)

void CPageSMP::init_affinities()
{
	if(!GetProcessAffinityMask(
		GetCurrentProcess(),
		&m_ProcessAffinityMask,
		&m_SystemAffinityMask) || m_SystemAffinityMask == 0)
	{
		m_SystemAffinityMask = 1;
	}

	/*
	m_smp_ethernet	= m_SystemAffinityMask;
	m_smp_serialin	= m_SystemAffinityMask;
	m_smp_serialout = m_SystemAffinityMask;
	m_smp_cpu				= m_SystemAffinityMask;
	m_smp_60hz			= m_SystemAffinityMask;
	m_smp_1hz				= m_SystemAffinityMask;
	m_smp_pram			= m_SystemAffinityMask;
	m_smp_gui				= m_SystemAffinityMask;
	m_smp_gdi				= m_SystemAffinityMask;
	m_smp_dx				= m_SystemAffinityMask;
	m_smp_fb				= m_SystemAffinityMask;
	m_smp_audio			= m_SystemAffinityMask;
	*/

	m_smp_ethernet	= 0;
	m_smp_serialin	= 0;
	m_smp_serialout = 0;
	m_smp_cpu				= 0;
	m_smp_60hz			= 0;
	m_smp_1hz				= 0;
	m_smp_pram			= 0;
	m_smp_gui				= 0;
	m_smp_gdi				= 0;
	m_smp_dx				= 0;
	m_smp_fb				= 0;
	m_smp_audio			= 0;
}

CPageSMP::CPageSMP() : CPropertyPage(CPageSMP::IDD)
{
	//{{AFX_DATA_INIT(CPageSMP)
		// NOTE: the ClassWizard will add member initialization here
	//}}AFX_DATA_INIT

	init_affinities();
}

CPageSMP::~CPageSMP()
{
}

void CPageSMP::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageSMP)
		// NOTE: the ClassWizard will add DDX and DDV calls here
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageSMP, CPropertyPage)
	//{{AFX_MSG_MAP(CPageSMP)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

void CPageSMP::enable_items( int first_id ) 
{
	for( int i=0; i<MAX_CPUS; i++ ) {
		BOOL enabled = (m_SystemAffinityMask & (1<<i)) != 0;
		GetDlgItem(first_id+i)->EnableWindow(enabled);
	}
	CPropertyPage::OnOK();
}

void CPageSMP::set_items( DWORD affinity_mask, int first_id ) 
{
	// if(affinity_mask == 0) affinity_mask = m_SystemAffinityMask;

	for( int i=0; i<MAX_CPUS; i++ ) {
		BOOL set = (affinity_mask & (1<<i)) != 0;
		if(set) CheckDlgButton( first_id+i, BST_CHECKED );
	}
	CPropertyPage::OnOK();
}

void CPageSMP::get_items( DWORD &affinity_mask, int first_id ) 
{
	// BOOL count = 0;
	for( int i=0; i<MAX_CPUS; i++ ) {

		// Leave room for more cpu's. I cannot foresee how many of them
		// are used in near/distant future.
		// affinity_mask = 0;

		affinity_mask &= ~(1<<i);
		if(IsDlgButtonChecked(first_id+i)) {
			affinity_mask |= (1<<i);
			// count++;
		}
	}
	// If all unchecked, use process affinity.
	// if(count == 0) affinity_mask = 1;
	CPropertyPage::OnOK();
}

void CPageSMP::OnOK() 
{
	CPropertyPage::OnOK();

	get_items( m_smp_ethernet, IDC_SMP_ETHERNET_1 );
	get_items( m_smp_serialin, IDC_SMP_SERIALIN_1  );
	get_items( m_smp_serialout, IDC_SMP_SERIALOUT_1 );
	get_items( m_smp_cpu, IDC_SMP_CPU_1 );
	get_items( m_smp_60hz, IDC_SMP_60HZ_1);
	get_items( m_smp_1hz, IDC_SMP_1HZ_1 );
	get_items( m_smp_pram, IDC_SMP_PRAM_1 );
	get_items( m_smp_gui, IDC_SMP_GUI_1 );
	get_items( m_smp_gdi, IDC_SMP_GDI_1 );
	get_items( m_smp_dx, IDC_SMP_DX_1 );
	get_items( m_smp_fb, IDC_SMP_FB_1 );
	get_items( m_smp_audio, IDC_SMP_AUDIO_1 );
}

BOOL CPageSMP::OnInitDialog() 
{
	CPropertyPage::OnInitDialog();

	enable_items( IDC_SMP_ETHERNET_1 );
	enable_items( IDC_SMP_SERIALIN_1  );
	enable_items( IDC_SMP_SERIALOUT_1 );
	enable_items( IDC_SMP_CPU_1 );
	enable_items( IDC_SMP_60HZ_1);
	enable_items( IDC_SMP_1HZ_1 );
	enable_items( IDC_SMP_PRAM_1 );
	enable_items( IDC_SMP_GUI_1 );
	enable_items( IDC_SMP_GDI_1 );
	enable_items( IDC_SMP_DX_1 );
	enable_items( IDC_SMP_FB_1 );
	enable_items( IDC_SMP_AUDIO_1 );
	
	set_items( m_smp_ethernet, IDC_SMP_ETHERNET_1 );
	set_items( m_smp_serialin, IDC_SMP_SERIALIN_1  );
	set_items( m_smp_serialout, IDC_SMP_SERIALOUT_1 );
	set_items( m_smp_cpu, IDC_SMP_CPU_1 );
	set_items( m_smp_60hz, IDC_SMP_60HZ_1);
	set_items( m_smp_1hz, IDC_SMP_1HZ_1 );
	set_items( m_smp_pram, IDC_SMP_PRAM_1 );
	set_items( m_smp_gui, IDC_SMP_GUI_1 );
	set_items( m_smp_gdi, IDC_SMP_GDI_1 );
	set_items( m_smp_dx, IDC_SMP_DX_1 );
	set_items( m_smp_fb, IDC_SMP_FB_1 );
	set_items( m_smp_audio, IDC_SMP_AUDIO_1 );
	
	return TRUE;
}
