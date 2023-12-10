#if !defined(AFX_PAGEEXTFS_H__F4A41ED3_98B5_11D3_AA00_00201881A006__INCLUDED_)
#define AFX_PAGEEXTFS_H__F4A41ED3_98B5_11D3_AA00_00201881A006__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// PageExtFS.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageExtFS dialog

class CPageExtFS : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageExtFS)

// Construction
public:
	CPageExtFS();
	~CPageExtFS();
	void enable_controls();
	void select_controls(int select);

// Dialog Data
	//{{AFX_DATA(CPageExtFS)
	enum { IDD = IDD_PAGE_EXTFS };
	BOOL	m_enabled;
	BOOL	m_a;
	BOOL	m_b;
	BOOL	m_c;
	BOOL	m_d;
	BOOL	m_e;
	BOOL	m_f;
	BOOL	m_g;
	BOOL	m_h;
	BOOL	m_i;
	BOOL	m_j;
	BOOL	m_k;
	BOOL	m_l;
	BOOL	m_m;
	BOOL	m_n;
	BOOL	m_o;
	BOOL	m_p;
	BOOL	m_q;
	BOOL	m_r;
	BOOL	m_s;
	BOOL	m_t;
	BOOL	m_u;
	BOOL	m_v;
	BOOL	m_w;
	BOOL	m_x;
	BOOL	m_y;
	BOOL	m_z;
	CString	m_path;
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageExtFS)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageExtFS)
	afx_msg void OnExtfsTypes();
	virtual BOOL OnInitDialog();
	afx_msg void OnExtfsEnabled();
	afx_msg void OnExtfsNone();
	afx_msg void OnExtfsAll();
	afx_msg void OnExtfsBrowsePath();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEEXTFS_H__F4A41ED3_98B5_11D3_AA00_00201881A006__INCLUDED_)
