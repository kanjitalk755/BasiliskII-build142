#if !defined(AFX_PAGESCREEN_H__55C902D6_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_PAGESCREEN_H__55C902D6_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageScreen.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageScreen dialog

class CPageScreen : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageScreen)

// Construction
public:
	CPageScreen();
	~CPageScreen();

// Dialog Data
	//{{AFX_DATA(CPageScreen)
	enum { IDD = IDD_PAGE_SCREEN };
	CComboBox	m_rrate;
	CString	m_screen_height;
	int		m_screen_type;
	CString	m_screen_width;
	int		m_screen_bits;
	BOOL	m_show_real_fps;
	UINT	m_sleep_ticks;
	BOOL	m_disable_w98_opt;
	//}}AFX_DATA

public:
  CString m_mode_str;
	CString m_refresh_rate;

// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageScreen)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageScreen)
	afx_msg void OnDestroy();
	virtual BOOL OnInitDialog();
	afx_msg void OnScreenRefreshRateHelp();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGESCREEN_H__55C902D6_0F05_11D3_A917_00201881A006__INCLUDED_)
