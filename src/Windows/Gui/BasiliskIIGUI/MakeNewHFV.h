#if !defined(AFX_MAKENEWHFV_H__A580ED96_2845_11D3_A917_00201881A006__INCLUDED_)
#define AFX_MAKENEWHFV_H__A580ED96_2845_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// MakeNewHFV.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CMakeNewHFV dialog

class CMakeNewHFV : public CDialog
{
// Construction
public:
	CMakeNewHFV(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CMakeNewHFV)
	enum { IDD = IDD_NEW_HFV };
	CString	m_path;
	int		m_size;
	//}}AFX_DATA


// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CMakeNewHFV)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(CMakeNewHFV)
	afx_msg void OnMakehfvBrowse();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_MAKENEWHFV_H__A580ED96_2845_11D3_A917_00201881A006__INCLUDED_)
