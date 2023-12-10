#if !defined(AFX_PAGETOOLS_H__A580ED93_2845_11D3_A917_00201881A006__INCLUDED_)
#define AFX_PAGETOOLS_H__A580ED93_2845_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageTools.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageTools dialog

class CPageTools : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageTools)

// Construction
public:
	CPageTools();
	~CPageTools();

	void enable_buttons();

// Dialog Data
	//{{AFX_DATA(CPageTools)
	enum { IDD = IDD_PAGE_TOOLS };
	BOOL	m_is_on_top;
	int		m_gui_autorestart;
	BOOL	m_lowmem_cache;
	UINT	m_sleep;
	BOOL	m_sleep_enabled;
	UINT	m_idle_sleep_timeout;
	BOOL	m_disable_screensaver;
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageTools)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageTools)
	afx_msg void OnUpdateToolsIdleMinutes();
	virtual BOOL OnInitDialog();
	afx_msg void OnToolsSleepEnabled();
	afx_msg void OnUpdateToolsIdleSleep();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGETOOLS_H__A580ED93_2845_11D3_A917_00201881A006__INCLUDED_)
