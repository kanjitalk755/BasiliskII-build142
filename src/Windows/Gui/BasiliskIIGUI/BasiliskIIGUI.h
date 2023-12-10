// BasiliskIIGUI.h : main header file for the BASILISKIIGUI application
//

#if !defined(AFX_BASILISKIIGUI_H__55C902C6_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_BASILISKIIGUI_H__55C902C6_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000

#ifndef __AFXWIN_H__
	#error include 'stdafx.h' before including this file for PCH
#endif

#include "resource.h"		// main symbols

/////////////////////////////////////////////////////////////////////////////
// CBasiliskIIGUIApp:
// See BasiliskIIGUI.cpp for the implementation of this class
//

class CBasiliskIIGUIApp : public CWinApp
{
public:
	CBasiliskIIGUIApp();

	CString m_dir;
	BOOL m_run_b2;

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CBasiliskIIGUIApp)
	public:
	virtual BOOL InitInstance();
	//}}AFX_VIRTUAL

// Implementation

	//{{AFX_MSG(CBasiliskIIGUIApp)
		// NOTE - the ClassWizard will add and remove member functions here.
		//    DO NOT EDIT what you see in these blocks of generated code !
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};


/////////////////////////////////////////////////////////////////////////////

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_BASILISKIIGUI_H__55C902C6_0F05_11D3_A917_00201881A006__INCLUDED_)
