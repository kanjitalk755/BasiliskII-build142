#if !defined(AFX_PAGEEXPERIMENT_H__24A26333_73D3_11D3_A9E6_00201881A006__INCLUDED_)
#define AFX_PAGEEXPERIMENT_H__24A26333_73D3_11D3_A9E6_00201881A006__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// PageExperiment.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageExperiment dialog

class CPageExperiment : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageExperiment)

// Construction
public:
	CPageExperiment();
	~CPageExperiment();

// Dialog Data
	//{{AFX_DATA(CPageExperiment)
	enum { IDD = IDD_PAGE_EXPERIMENT };
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageExperiment)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageExperiment)
		// NOTE: the ClassWizard will add member functions here
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEEXPERIMENT_H__24A26333_73D3_11D3_A9E6_00201881A006__INCLUDED_)
