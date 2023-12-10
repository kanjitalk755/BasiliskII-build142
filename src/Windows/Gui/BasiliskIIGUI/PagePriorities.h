#if !defined(AFX_PAGEPRIORITIES_H__F59C0533_1394_11D3_A91C_00201881A006__INCLUDED_)
#define AFX_PAGEPRIORITIES_H__F59C0533_1394_11D3_A91C_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PagePriorities.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPagePriorities dialog

class CPagePriorities : public CPropertyPage
{
	DECLARE_DYNCREATE(CPagePriorities)

// Construction
public:
	CPagePriorities();
	~CPagePriorities();

	void from_threads();

// Dialog Data
	//{{AFX_DATA(CPagePriorities)
	enum { IDD = IDD_PAGE_PRIORITIES };
	int		m_1hz_idle;
	int		m_1hz_run;
	int		m_60hz_idle;
	int		m_60hz_run;
	int		m_cpu_idle;
	int		m_cpu_run;
	int		m_dx_idle;
	int		m_dx_run;
	int		m_ethernet_idle;
	int		m_ethernet_run;
	int		m_gdi_idle;
	int		m_gdi_run;
	int		m_lfb_idle;
	int		m_lfb_run;
	int		m_gui_idle;
	int		m_gui_run;
	int		m_pram_idle;
	int		m_pram_run;
	int		m_serial_in_idle;
	int		m_serial_in_run;
	int		m_serial_out_idle;
	int		m_serial_out_run;
	int		m_sound_stream_idle;
	int		m_sound_stream_run;
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPagePriorities)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPagePriorities)
	afx_msg void OnSelchangePriSerialInRun();
	afx_msg void OnSelchangePriSerialOutRun();
	afx_msg void OnPriDefaults();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEPRIORITIES_H__F59C0533_1394_11D3_A91C_00201881A006__INCLUDED_)
