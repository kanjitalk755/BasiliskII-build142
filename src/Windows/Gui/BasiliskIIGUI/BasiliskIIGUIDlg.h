// BasiliskIIGUIDlg.h : header file
//

#if !defined(AFX_BASILISKIIGUIDLG_H__55C902C8_0F05_11D3_A917_00201881A006__INCLUDED_)
#define AFX_BASILISKIIGUIDLG_H__55C902C8_0F05_11D3_A917_00201881A006__INCLUDED_

#if _MSC_VER >= 1000
#pragma once
#endif // _MSC_VER >= 1000

#include "PageCDROM.h"
#include "PageDisk.h"
#include "PageFloppy.h"
#include "PageGeneral.h"
#include "PageMemory.h"
#include "PagePorts.h"
#include "PageScreen.h"
#include "PageSCSI.h"
#include "PageKeyboard.h"
#include "PageTools.h"
#include "PageAbout.h"
#include "PageEthernet.h"
#include "PageRouter.h"
#include "PagePriorities.h"
#include "PageSMP.h"
#include "PageAudio.h"
#include "PageDebug.h"
#include "PageMouse.h"
#include "PageExperiment.h"
#include "PageExtFS.h"
#include "PageDR.h"

/////////////////////////////////////////////////////////////////////////////
// CBasiliskIIGUIDlg dialog

class CBasiliskIIGUIDlg : public CPropertySheet
{
	DECLARE_DYNAMIC(CBasiliskIIGUIDlg)

public:
	CBasiliskIIGUIDlg(UINT nIDCaption, CWnd* pParentWnd = NULL, UINT iSelectPage = 0);
	CBasiliskIIGUIDlg(LPCTSTR pszCaption, CWnd* pParentWnd = NULL, UINT iSelectPage = 0);
	void add_pages();
	virtual ~CBasiliskIIGUIDlg();
	void save_to_file( LPCSTR path );
	void read_from_file( LPCSTR path );

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CBasiliskIIGUIDlg)
	public:
	virtual BOOL OnInitDialog();
	virtual void WinHelp(DWORD dwData, UINT nCmd = HELP_CONTEXT);
	//}}AFX_VIRTUAL

// Dialog Data
	//{{AFX_DATA(CBasiliskIIGUIDlg)
	enum { IDD = IDD_BASILISKIIGUI_DIALOG };
		// NOTE: the ClassWizard will add data members here
	//}}AFX_DATA

protected:
	//{{AFX_MSG(CBasiliskIIGUIDlg)
	afx_msg void OnDestroy();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

public:
	int m_last_active_page;
	CString m_prefs_path;

protected:
	CPageCDROM			m_page_cdrom;
	CPageDisk				m_page_disk;
	CPageFloppy			m_page_floppy;
	CPageGeneral		m_page_general;
	CPageMemory			m_page_memory;
	CPagePorts			m_page_ports;
	CPageScreen			m_page_screen;
	CPageSCSI				m_page_scsi;
	CPageKeyboard   m_page_keyboard;
	CPageMouse			m_page_mouse;
	CPageTools			m_page_tools;
	CPageAbout			m_page_about;
	CPageEthernet		m_page_ethernet;
	CPageRouter			m_page_router;
	CPagePriorities m_page_priorities;
	CPageSMP				m_page_smp;
	CPageAudio			m_page_audio;
	CPageDebug			m_page_debug;
	CPageExperiment m_page_experiment;
	CPageExtFS			m_page_extfs;
	CPageDR					m_page_dr;
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Developer Studio will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_BASILISKIIGUIDLG_H__55C902C8_0F05_11D3_A917_00201881A006__INCLUDED_)
