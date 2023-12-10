// PageScreen.cpp : implementation file
//

#include "stdafx.h"
#include "windowsx.h"
#include "BasiliskIIGUI.h"
#include "PageScreen.h"
#include "FullScreenHelp.h"

#include <ddraw.h>

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

static const char *sMonitorDefault = "Monitor default";

/////////////////////////////////////////////////////////////////////////////
// CPageScreen property page

IMPLEMENT_DYNCREATE(CPageScreen, CPropertyPage)

CPageScreen::CPageScreen() : CPropertyPage(CPageScreen::IDD)
{
	//{{AFX_DATA_INIT(CPageScreen)
	m_screen_height = _T("");
	m_screen_type = -1;
	m_screen_width = _T("");
	m_screen_bits = -1;
	m_show_real_fps = FALSE;
	m_sleep_ticks = 0;
	m_disable_w98_opt = FALSE;
	//}}AFX_DATA_INIT
}

CPageScreen::~CPageScreen()
{
}

void CPageScreen::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageScreen)
	DDX_Control(pDX, IDC_SCREEN_REFRESH_RATE, m_rrate);
	DDX_CBString(pDX, IDC_SCREEN_HEIGHT, m_screen_height);
	DDX_CBIndex(pDX, IDC_SCREEN_TYPE, m_screen_type);
	DDX_CBString(pDX, IDC_SCREEN_WIDTH, m_screen_width);
	DDX_CBIndex(pDX, IDC_SCREEN_BITS, m_screen_bits);
	DDX_Check(pDX, IDC_SCREEN_SHOW_FPS, m_show_real_fps);
	DDX_Text(pDX, IDC_SCREEN_SLEEP_TICKS, m_sleep_ticks);
	DDV_MinMaxUInt(pDX, m_sleep_ticks, 1, 1000);
	DDX_Check(pDX, IDC_SCREEN_DISABLE_98OPT, m_disable_w98_opt);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageScreen, CPropertyPage)
	//{{AFX_MSG_MAP(CPageScreen)
	ON_WM_DESTROY()
	ON_BN_CLICKED(IDC_SCREEN_REFRESH_RATE_HELP, OnScreenRefreshRateHelp)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageScreen message handlers

static int map_bits( int h_bits )
{
	int b;
	switch(h_bits) {
		case 0:
			b = 0;
			break;
		case 1:
			b = 1;
			break;
		case 2:
			b = 2;
			break;
		case 4:
			b = 3;
			break;
		case 8:
			b = 4;
			break;
		case 15:
			b = 5;
			break;
		case 16:
			b = 6;
			break;
		case 24:
			b = 7;
			break;
		case 32:
			b = 8;
			break;
	}
	return b;
}

static int unmap_bits( int b )
{
	int bits = 0;

	switch(b) {
		case 0:
			bits = 0;
			break;
		case 1:
			bits = 1;
			break;
		case 2:
			bits = 2;
			break;
		case 3:
			bits = 4;
			break;
		case 4:
			bits = 8;
			break;
		case 5:
			bits = 15;
			break;
		case 6:
			bits = 16;
			break;
		case 7:
			bits = 24;
			break;
		case 8:
			bits = 32;
			break;
	}
	return bits;
}

static HRESULT WINAPI EnumModesCallback(
  LPDDSURFACEDESC sdesc,
  LPVOID context
)
{
	if(sdesc->dwRefreshRate != 0) {
		CPageScreen *_this = (CPageScreen *)context;
		char buf[256];
		wsprintf( buf, "%d Hertz", sdesc->dwRefreshRate );
		int i = _this->m_rrate.FindString( -1, buf );
		if(i < 0) {
			_this->m_rrate.AddString( buf );
		}
	}
	return DDENUMRET_OK;
}

static HRESULT WINAPI EnumModesCallback2(
  LPDDSURFACEDESC2 sdesc,
  LPVOID context
)
{
	if(sdesc->dwRefreshRate != 0) {
		CPageScreen *_this = (CPageScreen *)context;
		char buf[256];
		wsprintf( buf, "%d Hertz", sdesc->dwRefreshRate );
		int i = _this->m_rrate.FindString( -1, buf );
		if(i < 0) {
			_this->m_rrate.AddString( buf );
		}
	}
	return DDENUMRET_OK;
}

BOOL CPageScreen::OnInitDialog() 
{
	int got_args, w_user=0, h_user=0, h_bits=0;
	CPropertyPage::OnInitDialog();

	SetCursor( LoadCursor( 0, IDC_WAIT ) );

	LPDIRECTDRAW lpDD = 0;

  HRESULT	ddrval = DirectDrawCreate( NULL, &lpDD, NULL );
  if( ddrval == DD_OK ) {
		m_rrate.AddString( sMonitorDefault );

		LPDIRECTDRAW4 lpDD4 = 0;
		ddrval = lpDD->QueryInterface( IID_IDirectDraw4, (void **)&lpDD4 );
		if( !FAILED(ddrval)) {
			lpDD4->EnumDisplayModes( 
				DDEDM_REFRESHRATES, 
				NULL, 
				(LPVOID)this,
				(LPDDENUMMODESCALLBACK2)EnumModesCallback2
			);
			lpDD4->Release();
		} else {
			lpDD->EnumDisplayModes( 
				DDEDM_REFRESHRATES, 
				NULL, 
				(LPVOID)this,
				(LPDDENUMMODESCALLBACK)EnumModesCallback
			);
		}

		lpDD->Release();
	} else {
		CString s;
		s.Format( "Error code 0x%X).", ddrval );
		// CComboBox
		m_rrate.AddString( s );
		GetDlgItem( IDC_SCREEN_REFRESH_RATE )->EnableWindow(FALSE);
	}

	SetCursor( LoadCursor( 0, IDC_ARROW ) );

	if(m_rrate.SelectString(-1, m_refresh_rate) < 0) {
		// m_rrate.SelectString(-1, sMonitorDefault);
		GetDlgItem(IDC_SCREEN_REFRESH_RATE)->SetWindowText(m_refresh_rate);
	}

	m_screen_type = 0;

	if(m_mode_str == "") m_mode_str = "dx/800/600/8";

  if (strncmp(m_mode_str, "win",3) == 0) {
		m_screen_type = 0;
		got_args = sscanf(m_mode_str, "win/%d/%d/%d", &w_user, &h_user, &h_bits);
  } else if (strncmp(m_mode_str, "dxwin",5) == 0) {
		m_screen_type = 2;
		got_args = sscanf(m_mode_str, "dxwin/%d/%d/%d", &w_user, &h_user, &h_bits);
  } else if (strncmp(m_mode_str, "dx",2) == 0) {
		m_screen_type = 1;
		got_args = sscanf(m_mode_str, "dx/%d/%d/%d", &w_user, &h_user, &h_bits);
  } else if (strncmp(m_mode_str, "fb",2) == 0) {
		m_screen_type = 3;
		got_args = sscanf(m_mode_str, "fb/%d/%d/%d", &w_user, &h_user, &h_bits);
  }

	if(w_user == 0) {
		m_screen_width = "Full Screen";
	} else {
		m_screen_width.Format( "%d", w_user );
	}
	if(h_user == 0) {
		m_screen_height = "Full Screen";
	} else {
		m_screen_height.Format( "%d", h_user );
	}
	m_screen_bits = map_bits(h_bits);

	UpdateData(FALSE);
	return TRUE;
}

void CPageScreen::OnDestroy() 
{
	UpdateData(FALSE);

	CString mode;
	int bits = 0;

	/*
	int i = m_rrate.GetCurSel();
	if(i >= 0) {
		CString s;
		m_rrate.GetLBText(i, m_refresh_rate);
	}
	*/
	GetDlgItem(IDC_SCREEN_REFRESH_RATE)->GetWindowText(m_refresh_rate);

	switch( m_screen_type ) {
		case 0:
			mode = "win";
			break;
		case 1:
			mode = "dx";
			break;
		case 2:
			mode = "dxwin";
			break;
		case 3:
			mode = "fb";
			break;
		default:
			mode = "win";
			break;
	}
	bits = unmap_bits(m_screen_bits);
	m_mode_str.Format( 
		"%s/%d/%d/%d", 
		(LPCSTR)mode,
		atoi(m_screen_width),
		atoi(m_screen_height),
		bits
	);
	CPropertyPage::OnDestroy();
}

void CPageScreen::OnScreenRefreshRateHelp() 
{
	UpdateData(TRUE);

	CFullScreenHelp dlg;

	dlg.m_return_width = atoi(m_screen_width);
	dlg.m_return_height = atoi(m_screen_height);
	dlg.m_return_depth = unmap_bits(m_screen_bits);

	dlg.m_return_refresh = 0;
	int i = m_rrate.GetCurSel();
	if(i >= 0) {
		CString s;
		m_rrate.GetLBText(i, s);
		dlg.m_return_refresh = atoi(s);
	}

	if(dlg.DoModal() == IDOK && dlg.m_return_width != 0) {
		m_screen_width.Format( "%d", dlg.m_return_width );
		m_screen_height.Format( "%d", dlg.m_return_height );
		m_screen_bits = map_bits(dlg.m_return_depth);
		CString sss;
		if(dlg.m_return_refresh == 0) {
			sss = sMonitorDefault;
		} else {
			sss.Format( "%d", dlg.m_return_refresh );
		}
		m_rrate.SelectString(-1, sss);
		if(m_screen_type != 1 && m_screen_type != 3) m_screen_type = 1;
		UpdateData(FALSE);
	}
}

/*
LRESULT CPageScreen::WindowProc(UINT message, WPARAM wParam, LPARAM lParam) 
{
	if(message == WM_NCHITTEST) {
		int xPos = GET_X_LPARAM(lParam);
		int yPos = GET_Y_LPARAM(lParam);
		// ::MessageBox( 0, "", "", 0 );
	}
	return CPropertyPage::WindowProc(message, wParam, lParam);
}
*/
