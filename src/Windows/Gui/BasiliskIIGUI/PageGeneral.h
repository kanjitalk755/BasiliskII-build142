#if !defined(AFX_PAGEGENERAL_H__55C902D4_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_PAGEGENERAL_H__55C902D4_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageGeneral.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageGeneral dialog

class CPageGeneral : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageGeneral)

// Construction
public:
	CPageGeneral();
	~CPageGeneral();
	void check_model_id();

// Dialog Data
	//{{AFX_DATA(CPageGeneral)
	enum { IDD = IDD_PAGE_GENERAL };
	int		m_boot_drive;
	BOOL	m_fpu;
	CString	m_prefs_path;
	CString	m_os8_ok;
	CString	m_model_id;
	CString	m_boot_driver;
	int		m_cpu;
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageGeneral)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageGeneral)
	afx_msg void OnEditupdateGeneralModelId();
	afx_msg void OnSelchangeGeneralModelId();
	afx_msg void OnEditchangeGeneralModelId();
	afx_msg void OnGeneralPrefsAssociate();
	afx_msg void OnGeneralPrefsBrowse();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEGENERAL_H__55C902D4_0F05_11D3_A917_00201881A006__INCLUDED_)
