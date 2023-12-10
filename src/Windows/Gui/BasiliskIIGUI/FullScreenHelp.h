#if !defined(AFX_FULLSCREENHELP_H__E8E0214A_880F_44E6_9CC0_E2B46F4BFDFF__INCLUDED_)
#define AFX_FULLSCREENHELP_H__E8E0214A_880F_44E6_9CC0_E2B46F4BFDFF__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// FullScreenHelp.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CFullScreenHelp dialog

class CFullScreenHelp : public CDialog
{
// Construction
public:
	CFullScreenHelp(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CFullScreenHelp)
	enum { IDD = IDD_DX_FULL_SCREEN_HELP };
	CListBox	m_mode_list;
	//}}AFX_DATA

public:
	int m_return_width;
	int m_return_height;
	int m_return_depth;
	int m_return_refresh;

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CFullScreenHelp)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(CFullScreenHelp)
	virtual BOOL OnInitDialog();
	virtual void OnOK();
	afx_msg void OnDestroy();
	afx_msg void OnSelchangeModeList();
	afx_msg void OnDblclkModeList();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_FULLSCREENHELP_H__E8E0214A_880F_44E6_9CC0_E2B46F4BFDFF__INCLUDED_)
