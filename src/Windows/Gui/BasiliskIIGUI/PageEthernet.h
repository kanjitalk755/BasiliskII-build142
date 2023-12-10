#if !defined(AFX_PAGEETHERNET_H__A580ED95_2845_11D3_A917_00201881A006__INCLUDED_)
#define AFX_PAGEETHERNET_H__A580ED95_2845_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000
// PageEthernet.h : header file
//

#include "sysdeps.h"
#include "..\..\b2ether\inc\b2ether_hl.h"

/////////////////////////////////////////////////////////////////////////////
// CPageEthernet dialog

class CPageEthernet : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageEthernet)

// Construction
public:
	CPageEthernet();
	~CPageEthernet();

// Dialog Data
	//{{AFX_DATA(CPageEthernet)
	enum { IDD = IDD_PAGE_ETHERNET };
	CComboBox	m_ethernet_mac;
	int		m_ethernet_mode;
	int		m_ethernet_permanent;
	CString	m_ethernet_hardware_address;
	CString	m_ether_fake_address;
	//}}AFX_DATA

	void enum_adapters( LPADAPTER fd );
	void enable_controls( BOOL enable );
	void update_hardware_address( LPADAPTER fd );

	CString m_mac;


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageEthernet)
	public:
	virtual void OnOK();
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageEthernet)
	virtual BOOL OnInitDialog();
	afx_msg void OnSelchangeEthernetMac();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEETHERNET_H__A580ED95_2845_11D3_A917_00201881A006__INCLUDED_)
