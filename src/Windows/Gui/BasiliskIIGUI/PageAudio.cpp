// PageAudio.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageAudio.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageAudio property page

IMPLEMENT_DYNCREATE(CPageAudio, CPropertyPage)

CPageAudio::CPageAudio() : CPropertyPage(CPageAudio::IDD)
{
	//{{AFX_DATA_INIT(CPageAudio)
	m_audio_enabled = FALSE;
	m_audio_buffer_count = 0;
	m_buffer_size_8000 = 0;
	m_buffer_size_44100 = 0;
	m_buffer_size_22050 = 0;
	m_buffer_size_11025 = 0;
	m_disable_audio_switchout = FALSE;
	m_audio_has_get_hardware_volume = FALSE;
	m_audio_use_startup_sound = FALSE;
	//}}AFX_DATA_INIT
}

CPageAudio::~CPageAudio()
{
}

void CPageAudio::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageAudio)
	DDX_Check(pDX, IDC_AUDIO_ENABLED, m_audio_enabled);
	DDX_Text(pDX, IDC_AUDIO_BUFFER_COUNT, m_audio_buffer_count);
	DDV_MinMaxUInt(pDX, m_audio_buffer_count, 1, 100);
	DDX_Text(pDX, IDC_AUDIO_BUFFER_SIZE_8000, m_buffer_size_8000);
	DDV_MinMaxUInt(pDX, m_buffer_size_8000, 100, 50000);
	DDX_Text(pDX, IDC_AUDIO_BUFFER_SIZE_44100, m_buffer_size_44100);
	DDV_MinMaxUInt(pDX, m_buffer_size_44100, 100, 50000);
	DDX_Text(pDX, IDC_AUDIO_BUFFER_SIZE_22050, m_buffer_size_22050);
	DDV_MinMaxUInt(pDX, m_buffer_size_22050, 100, 50000);
	DDX_Text(pDX, IDC_AUDIO_BUFFER_SIZE_11025, m_buffer_size_11025);
	DDV_MinMaxUInt(pDX, m_buffer_size_11025, 100, 50000);
	DDX_Check(pDX, IDC_AUDIO_SWITCHOUT, m_disable_audio_switchout);
	DDX_Check(pDX, IDC_AUDIO_MYST, m_audio_has_get_hardware_volume);
	DDX_Check(pDX, IDC_AUDIO_STARTUP_SOUND, m_audio_use_startup_sound);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageAudio, CPropertyPage)
	//{{AFX_MSG_MAP(CPageAudio)
	ON_BN_CLICKED(IDC_AUDIO_ENABLED, OnAudioEnabled)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageAudio message handlers

void CPageAudio::enable_controls() 
{
	UpdateData(TRUE);
	GetDlgItem(IDC_AUDIO_SWITCHOUT)->EnableWindow(m_audio_enabled);
	GetDlgItem(IDC_AUDIO_MYST)->EnableWindow(m_audio_enabled);
	GetDlgItem(IDC_AUDIO_STARTUP_SOUND)->EnableWindow(m_audio_enabled);
	GetDlgItem(IDC_AUDIO_BUFFER_COUNT)->EnableWindow(m_audio_enabled);
	GetDlgItem(IDC_AUDIO_BUFFER_SIZE_8000)->EnableWindow(m_audio_enabled);
	GetDlgItem(IDC_AUDIO_BUFFER_SIZE_11025)->EnableWindow(m_audio_enabled);
	GetDlgItem(IDC_AUDIO_BUFFER_SIZE_22050)->EnableWindow(m_audio_enabled);
	GetDlgItem(IDC_AUDIO_BUFFER_SIZE_44100)->EnableWindow(m_audio_enabled);
}

void CPageAudio::OnAudioEnabled() 
{
	enable_controls();
}

BOOL CPageAudio::OnInitDialog() 
{
	CPropertyPage::OnInitDialog();
	enable_controls();
	return TRUE;
}
