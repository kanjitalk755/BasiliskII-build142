#if !defined(AFX_MOUNTMODEHELP_H__27EEFF84_F091_43BE_8E3D_19D071CAB30F__INCLUDED_)
#define AFX_MOUNTMODEHELP_H__27EEFF84_F091_43BE_8E3D_19D071CAB30F__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// MountModeHelp.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CMountModeHelp dialog

class CMountModeHelp : public CDialog
{
// Construction
public:
	CMountModeHelp(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CMountModeHelp)
	enum { IDD = IDD_MOUNT_MODE_HELP };
		// NOTE: the ClassWizard will add data members here
	//}}AFX_DATA


// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CMountModeHelp)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(CMountModeHelp)
		// NOTE: the ClassWizard will add member functions here
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_MOUNTMODEHELP_H__27EEFF84_F091_43BE_8E3D_19D071CAB30F__INCLUDED_)
