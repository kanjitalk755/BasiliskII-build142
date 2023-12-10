// AskNewPort.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "AskNewPort.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CAskNewPort dialog


CAskNewPort::CAskNewPort(CWnd* pParent /*=NULL*/)
	: CDialog(CAskNewPort::IDD, pParent)
{
	//{{AFX_DATA_INIT(CAskNewPort)
	m_new_port = _T("");
	//}}AFX_DATA_INIT
}


void CAskNewPort::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CAskNewPort)
	DDX_Text(pDX, IDC_NEW_PORT_NUMBER, m_new_port);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CAskNewPort, CDialog)
	//{{AFX_MSG_MAP(CAskNewPort)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CAskNewPort message handlers

void CAskNewPort::OnOK() 
{
	UpdateData(TRUE);

	int port = atoi(m_new_port);
	if( port > 0 && port < 65536 ) {
		CDialog::OnOK();
	} else {
		AfxMessageBox( "Invalid port number." );
	}
}
