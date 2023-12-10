// PageEthernet.cpp : implementation file
//

#include "stdafx.h"
#include "..\..\sysdeps.h"
#include "BasiliskIIGUI.h"
#include "PageEthernet.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageEthernet property page

IMPLEMENT_DYNCREATE(CPageEthernet, CPropertyPage)

CPageEthernet::CPageEthernet() : CPropertyPage(CPageEthernet::IDD)
{
	//{{AFX_DATA_INIT(CPageEthernet)
	m_ethernet_mode = -1;
	m_ethernet_permanent = -1;
	m_ethernet_hardware_address = _T("");
	m_ether_fake_address = _T("");
	//}}AFX_DATA_INIT
}

CPageEthernet::~CPageEthernet()
{
}

void CPageEthernet::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageEthernet)
	DDX_Control(pDX, IDC_ETHERNET_MAC, m_ethernet_mac);
	DDX_CBIndex(pDX, IDC_ETHERNET_MODE, m_ethernet_mode);
	DDX_CBIndex(pDX, IDC_ETHERNET_PERMANENT, m_ethernet_permanent);
	DDX_Text(pDX, IDC_ETHERNET_HARDWARE_ADDRESS, m_ethernet_hardware_address);
	DDX_Text(pDX, IDC_ETHERNET_FAKE_ADDRESS, m_ether_fake_address);
	DDV_MaxChars(pDX, m_ether_fake_address, 12);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageEthernet, CPropertyPage)
	//{{AFX_MSG_MAP(CPageEthernet)
	ON_CBN_SELCHANGE(IDC_ETHERNET_MAC, OnSelchangeEthernetMac)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageEthernet message handlers


static const char *DEV_HEADER = "\\Device\\B2ether_";


void CPageEthernet::enum_adapters( LPADAPTER fd )
{
	char names[1024], *p;
	ULONG sz;
	OSVERSIONINFO osv;

	osv.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
	GetVersionEx( &osv );

	sz = sizeof(names);
  if(PacketGetAdapterNames( fd, names, &sz ) == ERROR_SUCCESS) {
		p = names;
		while(*p) {
			if(osv.dwPlatformId == VER_PLATFORM_WIN32_WINDOWS) {
				if( stricmp(p,"PPPMAC") != 0 ) {
					m_ethernet_mac.AddString(p);
				}
			} else {
				if( strnicmp(p,DEV_HEADER,strlen(DEV_HEADER)) == 0 ) {
					m_ethernet_mac.AddString(p+strlen(DEV_HEADER));
				}
			}
			p += strlen(p) + 1;
		}
	}
}

void CPageEthernet::enable_controls( BOOL enable )
{
	UpdateData(TRUE);
	GetDlgItem(IDC_ETHERNET_FAKE_ADDRESS)->EnableWindow(enable);
	GetDlgItem(IDC_ETHERNET_MODE)->EnableWindow(enable);
	GetDlgItem(IDC_ETHERNET_PERMANENT)->EnableWindow(enable);
}

void CPageEthernet::update_hardware_address( LPADAPTER fd ) 
{
	unsigned char ether_addr[6];
	BOOL enable = FALSE;

	UpdateData(TRUE);

	memset( ether_addr, 0, sizeof(ether_addr) );

	int i = m_ethernet_mac.GetCurSel();
	if(i > 0) {
		m_ethernet_mac.GetLBText(i,m_mac);
		if(m_mac != "<None>" && fd && fd->hFile != INVALID_HANDLE_VALUE) {
			if(PacketGetMAC(fd,ether_addr,m_ethernet_permanent)) {
				enable = TRUE;
			} else {
				memset( ether_addr, 0, sizeof(ether_addr) );
			}
		}
	}

	m_ethernet_hardware_address.Format( 
		"%02X %02X %02X %02X %02X %02X",
		ether_addr[0], 
		ether_addr[1], 
		ether_addr[2], 
		ether_addr[3], 
		ether_addr[4], 
		ether_addr[5]
	);
	UpdateData(FALSE);
	enable_controls( enable );
}

BOOL CPageEthernet::OnInitDialog() 
{
	LPADAPTER fd;

	CPropertyPage::OnInitDialog();

	SetCursor( LoadCursor( 0, IDC_WAIT ) );

	m_ethernet_mac.AddString("<None>");

	fd = PacketOpenAdapter( m_mac, m_ethernet_mode );

	enum_adapters(fd);

	int i = m_ethernet_mac.FindStringExact(0,m_mac);
	if(i < 0) i = 0;
	m_ethernet_mac.SetCurSel(i);
	
	update_hardware_address(fd);
	PacketCloseAdapter(fd);

	SetCursor( LoadCursor( 0, IDC_ARROW ) );
	
	return TRUE;
}

void CPageEthernet::OnOK() 
{
	CPropertyPage::OnOK();

	m_mac = "";

	// superfluous
	UpdateData(TRUE);
	int i = m_ethernet_mac.GetCurSel();
	if(i >= 0) {
		m_ethernet_mac.GetLBText(i,m_mac);
	}
}

void CPageEthernet::OnSelchangeEthernetMac() 
{
	m_mac = "";
	UpdateData(TRUE);
	int i = m_ethernet_mac.GetCurSel();
	if(i >= 0) {
		m_ethernet_mac.GetLBText(i,m_mac);
	}

	LPADAPTER fd = PacketOpenAdapter( m_mac, m_ethernet_mode );

	update_hardware_address(fd);
	if(fd) PacketCloseAdapter(fd);
}
