// AskNewPortAndInterface.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "AskNewPortAndInterface.h"

typedef unsigned long uint32;

#include "..\..\router\mib\interfaces.h"
#include "..\..\router\mib\mibaccess.h"

#include <winsock2.h>
#include "..\..\router\dynsockets.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CAskNewPortAndInterface dialog


CAskNewPortAndInterface::CAskNewPortAndInterface(CWnd* pParent /*=NULL*/)
	: CDialog(CAskNewPortAndInterface::IDD, pParent)
{
	//{{AFX_DATA_INIT(CAskNewPortAndInterface)
	m_new_port = _T("");
	m_new_interface = _T("");
	//}}AFX_DATA_INIT
}


void CAskNewPortAndInterface::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CAskNewPortAndInterface)
	DDX_Control(pDX, IDC_NEW_INTERFACE_NUMBER, m_if_list);
	DDX_Text(pDX, IDC_NEW_PORT_NUMBER, m_new_port);
	DDX_CBString(pDX, IDC_NEW_INTERFACE_NUMBER, m_new_interface);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CAskNewPortAndInterface, CDialog)
	//{{AFX_MSG_MAP(CAskNewPortAndInterface)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CAskNewPortAndInterface message handlers

void CAskNewPortAndInterface::OnOK() 
{
	UpdateData(TRUE);

	int port = atoi(m_new_port);
	if( port > 0 && port < 65536 ) {
		if( atoi(m_new_interface) == 0 ) {
			m_new_interface = "";
		}
		CDialog::OnOK();
	} else {
		AfxMessageBox( "Invalid port number." );
	}
}

BOOL CAskNewPortAndInterface::OnInitDialog() 
{
	CDialog::OnInitDialog();
	
	dynsockets_init();
	init_interfaces();

	if( atoi(m_new_interface) == 0 ) {
		m_new_interface = "<All interfaces>";
	}

	int if_count = get_ip_count();
	for( int i=0; i<if_count; i++ ) {
		uint32 iface = get_ip_by_index(i);
		CString istr;
		if( iface == 0 ) {
			istr = "<All interfaces>";
		} else {
			struct in_addr in;
			in.s_addr = iface;
			istr = _inet_ntoa( in );
		}
		m_if_list.AddString( istr );
	}

	final_interfaces();
	dynsockets_final();

	UpdateData(FALSE);
	
	return TRUE;
}
