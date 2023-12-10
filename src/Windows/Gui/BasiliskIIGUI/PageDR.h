#if !defined(AFX_PAGEDR_H__F4A41ED5_98B5_11D3_AA00_00201881A006__INCLUDED_)
#define AFX_PAGEDR_H__F4A41ED5_98B5_11D3_AA00_00201881A006__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// PageDR.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageDR dialog

class CPageDR : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageDR)

// Construction
public:
	CPageDR();
	~CPageDR();

// Dialog Data
	//{{AFX_DATA(CPageDR)
	enum { IDD = IDD_PAGE_DR };
		// NOTE - ClassWizard will add data members here.
		//    DO NOT EDIT what you see in these blocks of generated code !
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageDR)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageDR)
		// NOTE: the ClassWizard will add member functions here
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEDR_H__F4A41ED5_98B5_11D3_AA00_00201881A006__INCLUDED_)
