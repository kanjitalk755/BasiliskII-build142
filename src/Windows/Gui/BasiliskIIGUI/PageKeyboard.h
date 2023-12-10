#if !defined(AFX_PAGEKEYBOARD_H__55C902DA_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_PAGEKEYBOARD_H__55C902DA_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageKeyboard.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageKeyboard dialog

class CPageKeyboard : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageKeyboard)

// Construction
public:
	CPageKeyboard();
	~CPageKeyboard();

// Dialog Data
	//{{AFX_DATA(CPageKeyboard)
	enum { IDD = IDD_PAGE_KEYBOARD };
	CString	m_keyboard_path;
	BOOL	m_use_alt_escape;
	BOOL	m_use_alt_tab;
	BOOL	m_use_control_escape;
	BOOL	m_use_alt_space;
	BOOL	m_use_alt_enter;
	CString	m_keyboard_type;
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageKeyboard)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageKeyboard)
	afx_msg void OnKeyboardEditCodes();
	afx_msg void OnKeyboardMapBrowse();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEKEYBOARD_H__55C902DA_0F05_11D3_A917_00201881A006__INCLUDED_)
