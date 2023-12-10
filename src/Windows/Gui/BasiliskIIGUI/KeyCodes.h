#if !defined(AFX_KEYCODES_H__55C902DB_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_KEYCODES_H__55C902DB_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// KeyCodes.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CKeyCodes dialog

class CKeyCodes : public CDialog
{
// Construction
public:
	CKeyCodes(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CKeyCodes)
	enum { IDD = IDD_KEYBOARD };
	CString	m_mac_code_list;
	//}}AFX_DATA

	int m_inx;
	CString m_path;

	void key_change( int i );

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CKeyCodes)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	virtual BOOL OnCommand(WPARAM wParam, LPARAM lParam);
	//}}AFX_VIRTUAL

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(CKeyCodes)
	virtual BOOL OnInitDialog();
	afx_msg void OnSelchangeKList();
	virtual void OnOK();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_KEYCODES_H__55C902DB_0F05_11D3_A917_00201881A006__INCLUDED_)
