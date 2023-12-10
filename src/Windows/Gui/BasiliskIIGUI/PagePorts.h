#if !defined(AFX_PAGEPORTS_H__55C902D8_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_PAGEPORTS_H__55C902D8_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PagePorts.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPagePorts dialog

class CPagePorts : public CPropertyPage
{
	DECLARE_DYNCREATE(CPagePorts)

// Construction
public:
	CPagePorts();
	~CPagePorts();

// Dialog Data
	//{{AFX_DATA(CPagePorts)
	enum { IDD = IDD_PAGE_PORTS };
	CString	m_seriala;
	CString	m_serialb;
	CString	m_portfile0;
	CString	m_portfile1;
	//}}AFX_DATA

private:
	void update_buttons();

// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPagePorts)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPagePorts)
	afx_msg void OnSelchangePortsModem();
	afx_msg void OnSelchangePortsPrinter();
	virtual BOOL OnInitDialog();
	afx_msg void OnPortsFile0Browse();
	afx_msg void OnPortsFile1Browse();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEPORTS_H__55C902D8_0F05_11D3_A917_00201881A006__INCLUDED_)
