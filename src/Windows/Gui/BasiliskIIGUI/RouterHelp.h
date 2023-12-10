#if !defined(AFX_ROUTERHELP_H__A5E262D3_D9E5_11D4_AB36_00201881A006__INCLUDED_)
#define AFX_ROUTERHELP_H__A5E262D3_D9E5_11D4_AB36_00201881A006__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// RouterHelp.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// RouterHelp dialog

class RouterHelp : public CDialog
{
// Construction
public:
	RouterHelp(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(RouterHelp)
	enum { IDD = IDD_ROUTER_HELP };
		// NOTE: the ClassWizard will add data members here
	//}}AFX_DATA


// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(RouterHelp)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(RouterHelp)
		// NOTE: the ClassWizard will add member functions here
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_ROUTERHELP_H__A5E262D3_D9E5_11D4_AB36_00201881A006__INCLUDED_)
