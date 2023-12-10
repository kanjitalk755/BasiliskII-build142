#if !defined(AFX_PAGEMEMORY_H__55C902D5_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_PAGEMEMORY_H__55C902D5_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageMemory.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageMemory dialog

class CPageMemory : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageMemory)

// Construction
public:
	CPageMemory();
	~CPageMemory();
	void check_rom_size();

// Dialog Data
	//{{AFX_DATA(CPageMemory)
	enum { IDD = IDD_PAGE_MEMORY };
	CString	m_rom_path;
	int		m_ram_size;
	CString	m_rom_type;
	CString	m_checksum;
	CString	m_checksum_calc;
	CString	m_info;
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageMemory)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageMemory)
	afx_msg void OnMemoryRomBrowse();
	afx_msg void OnUpdateMemoryRomPath();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEMEMORY_H__55C902D5_0F05_11D3_A917_00201881A006__INCLUDED_)
