// PageRouter.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageRouter.h"
#include "RouterHelp.h"
#include "AskNewPort.h"
#include "AskNewPortAndInterface.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageRouter dialog

IMPLEMENT_DYNCREATE(CPageRouter, CPropertyPage)


CPageRouter::CPageRouter() : CPropertyPage(CPageRouter::IDD)
{
	//{{AFX_DATA_INIT(CPageRouter)
	m_router_enabled = FALSE;
	//}}AFX_DATA_INIT
}

CPageRouter::~CPageRouter()
{
}

void CPageRouter::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageRouter)
	DDX_Control(pDX, IDC_ROUTER_LISTEN_PORT_LIST, m_listen_port_list);
	DDX_Control(pDX, IDC_ROUTER_FTP_PORT_LIST, m_ftp_port_list);
	DDX_Check(pDX, IDC_ROUTER_ENABLE, m_router_enabled);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageRouter, CPropertyPage)
	//{{AFX_MSG_MAP(CPageRouter)
	ON_BN_CLICKED(IDC_ROUTER_HELP, OnRouterHelp)
	ON_BN_CLICKED(IDC_ROUTER_ENABLE, OnRouterEnable)
	ON_BN_CLICKED(IDC_ROUTER_NEW_FTP_PORT, OnRouterNewFtpPort)
	ON_BN_CLICKED(IDC_ROUTER_DEL_FTP_PORT, OnRouterDelFtpPort)
	ON_BN_CLICKED(IDC_ROUTER_NEW_LISTEN_PORT, OnRouterNewListenPort)
	ON_BN_CLICKED(IDC_ROUTER_DEL_LISTEN_PORT, OnRouterDelListenPort)
	ON_LBN_SELCHANGE(IDC_ROUTER_FTP_PORT_LIST, OnSelchangeRouterFtpPortList)
	ON_LBN_SELCHANGE(IDC_ROUTER_LISTEN_PORT_LIST, OnSelchangeRouterListenPortList)
	ON_WM_DESTROY()
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageRouter message handlers

void CPageRouter::OnRouterHelp() 
{
	RouterHelp	dlg;
	dlg.DoModal();
}

void CPageRouter::enable_buttons()
{
	UpdateData(TRUE);

	BOOL enable = m_router_enabled;

	GetDlgItem(IDC_ROUTER_NEW_FTP_PORT)->EnableWindow(enable);
	GetDlgItem(IDC_ROUTER_NEW_LISTEN_PORT)->EnableWindow(enable);

	GetDlgItem(IDC_ROUTER_FTP_PORT_LIST)->EnableWindow(enable);
	GetDlgItem(IDC_ROUTER_LISTEN_PORT_LIST)->EnableWindow(enable);

	GetDlgItem(IDC_ROUTER_DEL_FTP_PORT)->EnableWindow(enable && (m_ftp_port_list.GetCurSel() >= 0));
	GetDlgItem(IDC_ROUTER_DEL_LISTEN_PORT)->EnableWindow(enable && (m_listen_port_list.GetCurSel() >= 0));
}

void CPageRouter::OnRouterEnable() 
{
	enable_buttons();
}

void CPageRouter::OnRouterNewFtpPort() 
{
	CAskNewPort dlg;
	if( dlg.DoModal() == IDOK ) {
		if( m_ftp_port_list.FindStringExact(0,dlg.m_new_port) < 0 ) {
			int i = m_ftp_port_list.AddString( dlg.m_new_port );
			m_ftp_port_list.SetCurSel(i);
		}
		enable_buttons();
	}
}

void CPageRouter::OnRouterDelFtpPort() 
{
	int i = m_ftp_port_list.GetCurSel();
	if( i >= 0 ) {
		m_ftp_port_list.DeleteString(i);
		m_ftp_port_list.SetCurSel(0);
		enable_buttons();
	}
}

void CPageRouter::OnRouterNewListenPort() 
{
	CAskNewPortAndInterface dlg;
	if( dlg.DoModal() == IDOK ) {
		CString str = dlg.m_new_port;
		if( dlg.m_new_interface != "" ) {
			str += ",";
			str += dlg.m_new_interface;
		}
		if( m_listen_port_list.FindStringExact(0,str) < 0 ) {
			int i = m_listen_port_list.AddString( str );
			m_listen_port_list.SetCurSel(i);
		}
		enable_buttons();
	}
}

void CPageRouter::OnRouterDelListenPort() 
{
	int i = m_listen_port_list.GetCurSel();
	if( i >= 0 ) {
		m_listen_port_list.DeleteString(i);
		m_listen_port_list.SetCurSel(0);
		enable_buttons();
	}
}

void CPageRouter::OnSelchangeRouterFtpPortList() 
{
	enable_buttons();
}

void CPageRouter::OnSelchangeRouterListenPortList() 
{
	enable_buttons();
}

BOOL CPageRouter::OnInitDialog() 
{
	CPropertyPage::OnInitDialog();

	int tcp_count = m_tcp_ports_param.GetSize();
	for( int tcp_inx=0; tcp_inx<tcp_count; tcp_inx++ ) {
		m_listen_port_list.AddString( m_tcp_ports_param.GetAt(tcp_inx) );
	}
	m_tcp_ports_param.RemoveAll();

	char *ftp = new char [ m_ftp_ports_param.GetLength() + 1 ];
	if(ftp) {
		strcpy( ftp, m_ftp_ports_param );
		char *p = ftp;
		while( p && *p ) {
			char *pp = strchr( p, ',' );
			if(pp) *pp++ = 0;
			m_ftp_port_list.AddString( p );
			p = pp;
		}
		delete [] ftp;
	}
	m_ftp_ports_param = "";

	enable_buttons();
	return TRUE;
}

void CPageRouter::OnDestroy() 
{
	m_tcp_ports_param.RemoveAll();
	int tcp_count = m_listen_port_list.GetCount();
	for( int tcp_inx=0; tcp_inx<tcp_count; tcp_inx++ ) {
		CString str;
		m_listen_port_list.GetText( tcp_inx, str );
		m_tcp_ports_param.Add( str );
	}

	int ftp_count = m_ftp_port_list.GetCount();
	for( int ftp_inx=0; ftp_inx<ftp_count; ftp_inx++ ) {
		CString str;
		m_ftp_port_list.GetText( ftp_inx, str );
		if(ftp_inx > 0) m_ftp_ports_param += ",";
		m_ftp_ports_param += str;
	}

	CPropertyPage::OnDestroy();
}
