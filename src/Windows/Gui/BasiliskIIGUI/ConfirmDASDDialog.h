#if !defined(AFX_CONFIRMDASDDIALOG_H__938E89D3_34A2_11D3_A996_00201881A006__INCLUDED_)
#define AFX_CONFIRMDASDDIALOG_H__938E89D3_34A2_11D3_A996_00201881A006__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// ConfirmDASDDialog.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CConfirmDASDDialog dialog

class CConfirmDASDDialog : public CDialog
{
// Construction
public:
	CConfirmDASDDialog(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CConfirmDASDDialog)
	enum { IDD = IDD_DASD_CONFIRM };
	CString	m_dasd_name;
	//}}AFX_DATA


// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CConfirmDASDDialog)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(CConfirmDASDDialog)
		// NOTE: the ClassWizard will add member functions here
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_CONFIRMDASDDIALOG_H__938E89D3_34A2_11D3_A996_00201881A006__INCLUDED_)
