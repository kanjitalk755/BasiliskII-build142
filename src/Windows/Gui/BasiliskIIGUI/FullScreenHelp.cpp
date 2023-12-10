#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "FullScreenHelp.h"

#include <ddraw.h>
#include <d3d.h>

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

CFullScreenHelp::CFullScreenHelp(CWnd* pParent /*=NULL*/)
	: CDialog(CFullScreenHelp::IDD, pParent)
{
	//{{AFX_DATA_INIT(CFullScreenHelp)
		// NOTE: the ClassWizard will add member initialization here
	//}}AFX_DATA_INIT

	m_return_width = 0;
	m_return_height = 0;
	m_return_depth = 0;
	m_return_refresh = 0;
}


void CFullScreenHelp::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CFullScreenHelp)
	DDX_Control(pDX, IDC_MODE_LIST, m_mode_list);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CFullScreenHelp, CDialog)
	//{{AFX_MSG_MAP(CFullScreenHelp)
	ON_WM_DESTROY()
	ON_LBN_SELCHANGE(IDC_MODE_LIST, OnSelchangeModeList)
	ON_LBN_DBLCLK(IDC_MODE_LIST, OnDblclkModeList)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

static DWORD count_bits( DWORD x )
{
	DWORD count = 0, i;

	for( i=0; i<32; i++ ) {
		if( x & (1 << i) ) count++;
	}
	return count;
}

typedef struct {
	int width;
	int height;
	int depth;
	int refresh;
} iid_info;

static void format_str( char *buf, int width, int height, int depth, int refresh_rate )
{
	char depth_str[256];
	switch( depth ) {
		case 8:
			strcpy( depth_str, "256 Colors" );
			break;
		case 15:
		case 16:
			wsprintf( depth_str, "High Color (%d bit)", depth );
			break;
		case 24:
		case 32:
			wsprintf( depth_str, "True Color (%d bit)", depth );
			break;
		default:
			wsprintf( depth_str, "(%d bit)", depth );
			break;
	}
	wsprintf( 
		buf, 
		"%s%d by %d, %s, %d Hertz",
		width < 1000 ? " " : "",
		width,
		height,
		depth_str,
		refresh_rate
	);
}

static HRESULT WINAPI EnumModesCallback(
  LPDDSURFACEDESC sdesc,
  LPVOID context
)
{
	CFullScreenHelp *_this = (CFullScreenHelp *)context;

	DWORD depth = sdesc->ddpfPixelFormat.dwRGBBitCount;

	if(depth == 15 || depth == 16) {
		DWORD red = sdesc->ddpfPixelFormat.dwRBitMask;
		DWORD green = sdesc->ddpfPixelFormat.dwGBitMask;
		DWORD blue = sdesc->ddpfPixelFormat.dwBBitMask;
		DWORD depth2 = count_bits(red) + count_bits(green) + count_bits(blue);
		if(depth2 == 15 || depth2 == 16) {
			depth = depth2;
		}
	}
	
	char buf[256];
	format_str( buf, sdesc->dwWidth, sdesc->dwHeight, depth, sdesc->dwRefreshRate );

	iid_info *ptr = 0;
	int i = _this->m_mode_list.AddString(buf);
	if(i >= 0) {
		ptr = new iid_info;
		if(ptr) {
			ptr->width = sdesc->dwWidth;
			ptr->height = sdesc->dwHeight;
			ptr->depth = depth;
			ptr->refresh = sdesc->dwRefreshRate;
		}
	}
	_this->m_mode_list.SetItemDataPtr( i, (void *)ptr );

	return DDENUMRET_OK;
}

static HRESULT WINAPI EnumModesCallback2(
  LPDDSURFACEDESC2 sdesc,
  LPVOID context
)
{
	CFullScreenHelp *_this = (CFullScreenHelp *)context;

	DWORD depth = sdesc->ddpfPixelFormat.dwRGBBitCount;

	if(depth == 15 || depth == 16) {
		DWORD red = sdesc->ddpfPixelFormat.dwRBitMask;
		DWORD green = sdesc->ddpfPixelFormat.dwGBitMask;
		DWORD blue = sdesc->ddpfPixelFormat.dwBBitMask;
		DWORD depth2 = count_bits(red) + count_bits(green) + count_bits(blue);
		if(depth2 == 15 || depth2 == 16) {
			depth = depth2;
		}
	}
	
	char buf[256];
	format_str( buf, sdesc->dwWidth, sdesc->dwHeight, depth, sdesc->dwRefreshRate );

	iid_info *ptr = 0;
	int i = _this->m_mode_list.AddString(buf);
	if(i >= 0) {
		ptr = new iid_info;
		if(ptr) {
			ptr->width = sdesc->dwWidth;
			ptr->height = sdesc->dwHeight;
			ptr->depth = depth;
			ptr->refresh = sdesc->dwRefreshRate;
		}
	}
	_this->m_mode_list.SetItemDataPtr( i, (void *)ptr );

	return DDENUMRET_OK;
}
/*
88760078 == DDERR_INVALIDMODE
DDERR_GENERIC  
DDERR_INVALIDMODE  
DDERR_INVALIDOBJECT  
DDERR_INVALIDPARAMS  
DDERR_LOCKEDSURFACES  
DDERR_NOEXCLUSIVEMODE  
DDERR_SURFACEBUSY  
DDERR_UNSUPPORTED  
DDERR_UNSUPPORTEDMODE  
DDERR_WASSTILLDRAWING  
*/

BOOL CFullScreenHelp::OnInitDialog() 
{
	CDialog::OnInitDialog();
	
	LPDIRECTDRAW lpDD = 0;

	SetCursor( LoadCursor( 0, IDC_WAIT ) );

  HRESULT	ddrval = DirectDrawCreate( NULL, &lpDD, NULL );
  if( ddrval == DD_OK ) {
		LPDIRECTDRAW4 lpDD4 = 0;
		ddrval = lpDD->QueryInterface( IID_IDirectDraw4, (void **)&lpDD4 );
		if( !FAILED(ddrval)) {
			// AfxMessageBox( "Got IID_IDirectDraw4 interface" );
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
		s.Format( "Could not query DirectX modes (error code 0x%X).", ddrval );
		m_mode_list.AddString( s );
		GetDlgItem( IDC_MODE_LIST )->EnableWindow(FALSE);
	}

	SetCursor( LoadCursor( 0, IDC_ARROW ) );

	char buf[256];
	format_str(
		buf, 
		m_return_width,
		m_return_height,
		m_return_depth,
		m_return_refresh
	);
	int i = m_mode_list.FindString( -1, buf );
	if(i >= 0) {
		m_mode_list.SetCurSel(i);
	} else {
		GetDlgItem( IDOK )->EnableWindow(FALSE);
	}
	
	return TRUE;
}

/*
		"The values listed are commonly used values. "
		"Not all of the refresh rates may be supported by your video card and monitor. "
		"If the selected rate is not valid (with a particular width, height and color depth combination), "
		"Basilisk II will fall back to the \"Monitor default\" value."
*/

void CFullScreenHelp::OnOK() 
{
	UpdateData(TRUE);

	m_return_width = 0;
	m_return_height = 0;
	m_return_depth = 0;
	m_return_refresh = 0;

	int i = m_mode_list.GetCurSel();
	if(i >= 0) {
		iid_info *ptr = (iid_info *)m_mode_list.GetItemDataPtr(i);
		if(ptr) {
			m_return_width = ptr->width;
			m_return_height = ptr->height;
			m_return_depth = ptr->depth;
			m_return_refresh = ptr->refresh;
		}
	}
	
	CDialog::OnOK();
}

void CFullScreenHelp::OnDestroy() 
{
	int count = m_mode_list.GetCount();
	for( int i=0; i<count; i++ ) {
		iid_info *ptr = (iid_info *)m_mode_list.GetItemDataPtr(i);
		if(ptr) delete ptr;
	}

	CDialog::OnDestroy();
}

void CFullScreenHelp::OnSelchangeModeList() 
{
	UpdateData(TRUE);

	int i = m_mode_list.GetCurSel();
	if(i >= 0) {
		GetDlgItem( IDOK )->EnableWindow(TRUE);
	}
}

void CFullScreenHelp::OnDblclkModeList() 
{
	PostMessage( WM_COMMAND, IDOK, 0 );
}
