#if !defined(AFX_PAGECDROM_H__55C902D2_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_PAGECDROM_H__55C902D2_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageCDROM.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageCDROM dialog

class CPageCDROM : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageCDROM)

// Construction
public:
	CPageCDROM();
	~CPageCDROM();

// Dialog Data
	//{{AFX_DATA(CPageCDROM)
	enum { IDD = IDD_PAGE_CDROM };
	CListBox	m_list_available;
	CListBox	m_list_installed;
	BOOL	m_cd_enabled;
	BOOL	m_realmodecd;
	//}}AFX_DATA

	void enable_controls();

	CStringArray m_list;

// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageCDROM)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageCDROM)
	afx_msg void OnCdInstall();
	afx_msg void OnCdDown();
	afx_msg void OnCdRemove();
	afx_msg void OnCdUp();
	virtual BOOL OnInitDialog();
	afx_msg void OnDestroy();
	afx_msg void OnDblclkCdListInstalled();
	afx_msg void OnDblclkCdListAvailable();
	afx_msg void OnCdEnabled();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGECDROM_H__55C902D2_0F05_11D3_A917_00201881A006__INCLUDED_)
