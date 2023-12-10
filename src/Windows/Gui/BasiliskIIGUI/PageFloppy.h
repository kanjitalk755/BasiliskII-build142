#if !defined(AFX_PAGEFLOPPY_H__55C902D3_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_PAGEFLOPPY_H__55C902D3_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageFloppy.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageFloppy dialog

class CPageFloppy : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageFloppy)

// Construction
public:
	CPageFloppy();
	~CPageFloppy();

// Dialog Data
	//{{AFX_DATA(CPageFloppy)
	enum { IDD = IDD_PAGE_FLOPPY };
	CListBox	m_list_installed;
	CListBox	m_list_available;
	BOOL	m_boot_allowed;
	//}}AFX_DATA

	BOOL is_rw_item( LPCSTR path );
	void set_rw_item( LPCSTR path, BOOL rw );
	void draw_list_item( DRAWITEMSTRUCT FAR *lpd );

	CStringArray m_list;
	CStringArray m_rw_paths;

// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageFloppy)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageFloppy)
	afx_msg void OnFloppyDown();
	afx_msg void OnFloppyInstall();
	afx_msg void OnFloppyRemove();
	afx_msg void OnFloppyUp();
	virtual BOOL OnInitDialog();
	afx_msg void OnDestroy();
	afx_msg void OnDblclkFloppyListInstalled();
	afx_msg void OnDblclkFloppyListAvailable();
	afx_msg void OnFloppyRw();
	afx_msg void OnSelchangeFloppyListInstalled();
	afx_msg void OnDrawItem(int nIDCtl, LPDRAWITEMSTRUCT lpDrawItemStruct);
	afx_msg void OnMeasureItem(int nIDCtl, LPMEASUREITEMSTRUCT lpMeasureItemStruct);
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEFLOPPY_H__55C902D3_0F05_11D3_A917_00201881A006__INCLUDED_)
