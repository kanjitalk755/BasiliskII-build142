#if !defined(AFX_PAGESMP_H__915EF293_3579_11D4_AAB0_00201881A006__INCLUDED_)
#define AFX_PAGESMP_H__915EF293_3579_11D4_AAB0_00201881A006__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// PageSMP.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CPageSMP dialog

class CPageSMP : public CPropertyPage
{
	DECLARE_DYNCREATE(CPageSMP)

// Construction
public:
	CPageSMP();
	~CPageSMP();

// Dialog Data
	//{{AFX_DATA(CPageSMP)
	enum { IDD = IDD_PAGE_SMP };
		// NOTE - ClassWizard will add data members here.
		//    DO NOT EDIT what you see in these blocks of generated code !
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CPageSMP)
	public:
	virtual void OnOK();
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

public:
	void init_affinities();
	void enable_items( int first_id );
	void set_items( DWORD affinity_mask, int first_id );
	void get_items( DWORD &affinity_mask, int first_id );

	DWORD m_ProcessAffinityMask, m_SystemAffinityMask;

	DWORD m_smp_ethernet;
	DWORD m_smp_serialin;
	DWORD m_smp_serialout;
	DWORD m_smp_cpu;
	DWORD m_smp_60hz;
	DWORD m_smp_1hz;
	DWORD m_smp_pram;
	DWORD m_smp_gui;
	DWORD m_smp_gdi;
	DWORD m_smp_dx;
	DWORD m_smp_fb;
	DWORD m_smp_audio;

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CPageSMP)
	virtual BOOL OnInitDialog();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PAGESMP_H__915EF293_3579_11D4_AAB0_00201881A006__INCLUDED_)
