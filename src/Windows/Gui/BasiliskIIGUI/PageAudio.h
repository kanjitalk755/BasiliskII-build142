#if !defined(AFX_PAGEAUDIO_H__A33E5B63_1564_11D3_A928_00201881A006__INCLUDED_)
#define AFX_PAGEAUDIO_H__A33E5B63_1564_11D3_A928_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageAudio.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageAudio dialog

class CPageAudio : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageAudio)

// Construction
public:
	CPageAudio();
	~CPageAudio();

// Dialog Data
	//{{AFX_DATA(CPageAudio)
	enum { IDD = IDD_PAGE_AUDIO };
	BOOL	m_audio_enabled;
	UINT	m_audio_buffer_count;
	UINT	m_buffer_size_8000;
	UINT	m_buffer_size_44100;
	UINT	m_buffer_size_22050;
	UINT	m_buffer_size_11025;
	BOOL	m_disable_audio_switchout;
	BOOL	m_audio_has_get_hardware_volume;
	BOOL	m_audio_use_startup_sound;
	//}}AFX_DATA

protected:
	void enable_controls();

// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageAudio)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageAudio)
	afx_msg void OnAudioEnabled();
	virtual BOOL OnInitDialog();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEAUDIO_H__A33E5B63_1564_11D3_A928_00201881A006__INCLUDED_)
