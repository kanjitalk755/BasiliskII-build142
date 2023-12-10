#if !defined(AFX_PAGESCSI_H__55C902D7_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_PAGESCSI_H__55C902D7_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageSCSI.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageSCSI dialog

class CPageSCSI : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageSCSI)

// Construction
public:
	CPageSCSI();
	~CPageSCSI();

// Dialog Data
	//{{AFX_DATA(CPageSCSI)
	enum { IDD = IDD_PAGE_SCSI };
	CListBox	m_list_replace_to;
	CListBox	m_list_replace_from;
	CListBox	m_list_disabled;
	BOOL	m_scsi_enabled;
	//}}AFX_DATA

	void enable_controls();

	CStringArray m_list_d, m_list_r;
	BOOL in_list( CListBox &list, LPCSTR name );
	BOOL confirm_DASD(const char *name);

// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageSCSI)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	virtual BOOL OnCommand(WPARAM wParam, LPARAM lParam);
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageSCSI)
	virtual BOOL OnInitDialog();
	afx_msg void OnDestroy();
	afx_msg void OnScsiAddDisabled();
	afx_msg void OnScsiDelDisabled();
	afx_msg void OnScsiAddFrom();
	afx_msg void OnScsiAddTo();
	afx_msg void OnScsiDelFrom();
	afx_msg void OnScsiDelTo();
	afx_msg void OnCheck1();
	afx_msg void OnScsiEnabled();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGESCSI_H__55C902D7_0F05_11D3_A917_00201881A006__INCLUDED_)
