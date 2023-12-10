#if !defined(AFX_CONFIRMRWDLG_H__2FD888C3_6A24_11D3_A9E0_00201881A006__INCLUDED_)
#define AFX_CONFIRMRWDLG_H__2FD888C3_6A24_11D3_A9E0_00201881A006__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// ConfirmRWDlg.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CConfirmRWDlg dialog

class CConfirmRWDlg : public CDialog
{
// Construction
public:
	CConfirmRWDlg(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CConfirmRWDlg)
	enum { IDD = IDD_RW_CONFIRM };
	CString	m_path;
	//}}AFX_DATA


// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CConfirmRWDlg)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(CConfirmRWDlg)
		// NOTE: the ClassWizard will add member functions here
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_CONFIRMRWDLG_H__2FD888C3_6A24_11D3_A9E0_00201881A006__INCLUDED_)
