#if !defined(AFX_PAGEROUTER_H__391BBD31_D899_11D4_AB36_00201881A006__INCLUDED_)
#define AFX_PAGEROUTER_H__391BBD31_D899_11D4_AB36_00201881A006__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// PageRouter.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageRouter dialog

class CPageRouter : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageRouter)

// Construction
public:
	CPageRouter();
	~CPageRouter();

// Dialog Data
	//{{AFX_DATA(CPageRouter)
	enum { IDD = IDD_PAGE_ROUTER };
	CListBox	m_listen_port_list;
	CListBox	m_ftp_port_list;
	BOOL	m_router_enabled;
	//}}AFX_DATA


// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CPageRouter)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

public:
	CStringArray m_tcp_ports_param;
	CString m_ftp_ports_param;

protected:
	void enable_buttons();

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(CPageRouter)
	afx_msg void OnRouterHelp();
	afx_msg void OnRouterEnable();
	afx_msg void OnRouterNewFtpPort();
	afx_msg void OnRouterDelFtpPort();
	afx_msg void OnRouterNewListenPort();
	afx_msg void OnRouterDelListenPort();
	afx_msg void OnSelchangeRouterFtpPortList();
	afx_msg void OnSelchangeRouterListenPortList();
	virtual BOOL OnInitDialog();
	afx_msg void OnDestroy();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEROUTER_H__391BBD31_D899_11D4_AB36_00201881A006__INCLUDED_)
