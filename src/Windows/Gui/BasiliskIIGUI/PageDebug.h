#if !defined(AFX_PAGEDEBUG_H__48B10794_156A_11D3_A929_00201881A006__INCLUDED_)
#define AFX_PAGEDEBUG_H__48B10794_156A_11D3_A929_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageDebug.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageDebug dialog

class CPageDebug : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageDebug)

// Construction
public:
	CPageDebug();
	~CPageDebug();

// Dialog Data
	//{{AFX_DATA(CPageDebug)
	enum { IDD = IDD_PAGE_DEBUG };
	int		m_debug_scsi;
	int		m_debug_filesys;
	int		m_debug_serial;
	BOOL	m_debug_disable_accurate_timer;
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageDebug)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageDebug)
		// NOTE: the ClassWizard will add member functions here
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEDEBUG_H__48B10794_156A_11D3_A929_00201881A006__INCLUDED_)
