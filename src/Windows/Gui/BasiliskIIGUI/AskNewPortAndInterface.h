#if !defined(AFX_ASKNEWPORTANDINTERFACE_H__A5E262D5_D9E5_11D4_AB36_00201881A006__INCLUDED_)
#define AFX_ASKNEWPORTANDINTERFACE_H__A5E262D5_D9E5_11D4_AB36_00201881A006__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// AskNewPortAndInterface.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CAskNewPortAndInterface dialog

class CAskNewPortAndInterface : public CDialog
{
// Construction
public:
	CAskNewPortAndInterface(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CAskNewPortAndInterface)
	enum { IDD = IDD_ASK_NEW_PORT_AND_IF };
	CComboBox	m_if_list;
	CString	m_new_port;
	CString	m_new_interface;
	//}}AFX_DATA


// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CAskNewPortAndInterface)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(CAskNewPortAndInterface)
	virtual void OnOK();
	virtual BOOL OnInitDialog();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_ASKNEWPORTANDINTERFACE_H__A5E262D5_D9E5_11D4_AB36_00201881A006__INCLUDED_)
