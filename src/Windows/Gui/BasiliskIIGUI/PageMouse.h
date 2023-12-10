#if !defined(AFX_PAGEMOUSE_H__6A9A8F31_6AF8_11D3_A9E1_00201881A006__INCLUDED_)
#define AFX_PAGEMOUSE_H__6A9A8F31_6AF8_11D3_A9E1_00201881A006__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// PageMouse.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageMouse dialog

class CPageMouse : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageMouse)

// Construction
public:
	CPageMouse();
	~CPageMouse();

// Dialog Data
	//{{AFX_DATA(CPageMouse)
	enum { IDD = IDD_PAGE_MOUSE };
	UINT	m_mouse_lines;
	int		m_mouse_wheel_mode;
	BOOL	m_mouse_wheel_reverse_x;
	BOOL	m_mouse_wheel_reverse_y;
	int		m_mouse_wheel_click_mode;
	int		m_right_mouse;
	BOOL	m_os8_mouse;
	CString	m_mouse_wheel_cust_00;
	CString	m_mouse_wheel_cust_01;
	CString	m_mouse_wheel_cust_10;
	CString	m_mouse_wheel_cust_11;
	int		m_mouse_movement_mode;
	//}}AFX_DATA


	void enable_controls(void);

// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageMouse)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageMouse)
	afx_msg void OnSelchangeMouseMousewheel();
	virtual BOOL OnInitDialog();
	afx_msg void OnSelchangeMouseMousewheelClickMode();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGEMOUSE_H__6A9A8F31_6AF8_11D3_A9E1_00201881A006__INCLUDED_)
