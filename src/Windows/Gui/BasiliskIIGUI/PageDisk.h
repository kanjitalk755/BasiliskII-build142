#if !defined(AFX_PAGEDISK_H__55C902D9_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_PAGEDISK_H__55C902D9_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageDisk.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageDisk dialog

class CPageDisk : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageDisk)

// Construction
public:
	CPageDisk();
	~CPageDisk();

// Dialog Data
	//{{AFX_DATA(CPageDisk)
	enum { IDD = IDD_PAGE_DISK };
	CListBox	m_list_installed;
	CListBox	m_list_available;
	BOOL	m_poll_media;
	int		m_disk_mount_mode;
	//}}AFX_DATA

	CStringArray m_list;

	void enum_hard_files( const char *dir, char *extension );
	void draw_list_item( DRAWITEMSTRUCT FAR *lpd );
	void enum_mount_modes();

	int is_rw_item( int i );
	void set_rw_item( int i, int rw );

	BOOL confirm_rw_mount(const char *name);

// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageDisk)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageDisk)
	afx_msg void OnDiskCreateHfv();
	afx_msg void OnDiskDown();
	afx_msg void OnDiskInstall();
	afx_msg void OnDiskRemove();
	afx_msg void OnDiskUp();
	afx_msg void OnDestroy();
	virtual BOOL OnInitDialog();
	afx_msg void OnDblclkDiskListInstalled();
	afx_msg void OnDblclkDiskListAvailable();
	afx_msg void OnDiskAddVolumeFile();
	afx_msg HBRUSH OnCtlColor(CDC* pDC, CWnd* pWnd, UINT nCtlColor);
	afx_msg void OnMeasureItem(int nIDCtl, LPMEASUREITEMSTRUCT lpMeasureItemStruct);
	afx_msg void OnDrawItem(int nIDCtl, LPDRAWITEMSTRUCT lpDrawItemStruct);
	afx_msg void OnSelchangeDiskListInstalled();
	afx_msg void OnSelchangeDiskMountMode();
	afx_msg void OnMountModeHelp();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEDISK_H__55C902D9_0F05_11D3_A917_00201881A006__INCLUDED_)
