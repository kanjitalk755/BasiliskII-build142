#if !defined(AFX_ASKNEWPORT_H__A5E262D4_D9E5_11D4_AB36_00201881A006__INCLUDED_)
#define AFX_ASKNEWPORT_H__A5E262D4_D9E5_11D4_AB36_00201881A006__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// AskNewPort.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CAskNewPort dialog

class CAskNewPort : public CDialog
{
// Construction
public:
	CAskNewPort(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CAskNewPort)
	enum { IDD = IDD_ASK_NEW_PORT };
	CString	m_new_port;
	//}}AFX_DATA


// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CAskNewPort)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(CAskNewPort)
	virtual void OnOK();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_ASKNEWPORT_H__A5E262D4_D9E5_11D4_AB36_00201881A006__INCLUDED_)
