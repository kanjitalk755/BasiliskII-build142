// PageMouse.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageMouse.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageMouse property page

IMPLEMENT_DYNCREATE(CPageMouse, CPropertyPage)

CPageMouse::CPageMouse() : CPropertyPage(CPageMouse::IDD)
{
	//{{AFX_DATA_INIT(CPageMouse)
	m_mouse_lines = 0;
	m_mouse_wheel_mode = -1;
	m_mouse_wheel_reverse_x = FALSE;
	m_mouse_wheel_reverse_y = FALSE;
	m_mouse_wheel_click_mode = -1;
	m_right_mouse = -1;
	m_os8_mouse = FALSE;
	m_mouse_wheel_cust_00 = _T("");
	m_mouse_wheel_cust_01 = _T("");
	m_mouse_wheel_cust_10 = _T("");
	m_mouse_wheel_cust_11 = _T("");
	m_mouse_movement_mode = -1;
	//}}AFX_DATA_INIT
}

CPageMouse::~CPageMouse()
{
}

void CPageMouse::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageMouse)
	DDX_Text(pDX, IDC_MOUSE_MOUSELINES, m_mouse_lines);
	DDV_MinMaxUInt(pDX, m_mouse_lines, 0, 32767);
	DDX_CBIndex(pDX, IDC_MOUSE_MOUSEWHEEL, m_mouse_wheel_mode);
	DDX_Check(pDX, IDC_MOUSE_MOUSEWHEEL_REVERSE_X, m_mouse_wheel_reverse_x);
	DDX_Check(pDX, IDC_MOUSE_MOUSEWHEEL_REVERSE_Y, m_mouse_wheel_reverse_y);
	DDX_CBIndex(pDX, IDC_MOUSE_MOUSEWHEEL_CLICK_MODE, m_mouse_wheel_click_mode);
	DDX_CBIndex(pDX, IDC_MOUSE_RIGHT_MOUSE, m_right_mouse);
	DDX_Check(pDX, IDC_MOUSE_STICKY_MENU, m_os8_mouse);
	DDX_Text(pDX, IDC_MOUSE_MOUSEWHEEL_CUST_00, m_mouse_wheel_cust_00);
	DDV_MaxChars(pDX, m_mouse_wheel_cust_00, 256);
	DDX_Text(pDX, IDC_MOUSE_MOUSEWHEEL_CUST_01, m_mouse_wheel_cust_01);
	DDV_MaxChars(pDX, m_mouse_wheel_cust_01, 256);
	DDX_Text(pDX, IDC_MOUSE_MOUSEWHEEL_CUST_10, m_mouse_wheel_cust_10);
	DDV_MaxChars(pDX, m_mouse_wheel_cust_10, 256);
	DDX_Text(pDX, IDC_MOUSE_MOUSEWHEEL_CUST_11, m_mouse_wheel_cust_11);
	DDV_MaxChars(pDX, m_mouse_wheel_cust_11, 256);
	DDX_CBIndex(pDX, IDC_MOUSE_MOVEMENT, m_mouse_movement_mode);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageMouse, CPropertyPage)
	//{{AFX_MSG_MAP(CPageMouse)
	ON_CBN_SELCHANGE(IDC_MOUSE_MOUSEWHEEL, OnSelchangeMouseMousewheel)
	ON_CBN_SELCHANGE(IDC_MOUSE_MOUSEWHEEL_CLICK_MODE, OnSelchangeMouseMousewheelClickMode)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageMouse message handlers

void CPageMouse::OnSelchangeMouseMousewheel() 
{
	enable_controls();
}

void CPageMouse::enable_controls(void) 
{
	if(UpdateData(TRUE)) {

		BOOL enable1 = m_mouse_wheel_mode == 1;
		BOOL enable2 = m_mouse_wheel_click_mode == 3;

		GetDlgItem(IDC_MOUSE_MOUSELINES)->EnableWindow(enable1);
		GetDlgItem(IDC_MOUSE_MOUSEWHEEL_REVERSE_X)->EnableWindow(enable1);
		GetDlgItem(IDC_MOUSE_MOUSEWHEEL_STATIC1)->EnableWindow(enable1);
		GetDlgItem(IDC_MOUSE_MOUSEWHEEL_STATIC2)->EnableWindow(enable1);

		GetDlgItem(IDC_MOUSE_MOUSEWHEEL_STATIC3)->EnableWindow(enable2);
		GetDlgItem(IDC_MOUSE_MOUSEWHEEL_STATIC4)->EnableWindow(enable2);
		GetDlgItem(IDC_MOUSE_MOUSEWHEEL_STATIC5)->EnableWindow(enable2);
		GetDlgItem(IDC_MOUSE_MOUSEWHEEL_STATIC6)->EnableWindow(enable2);
		GetDlgItem(IDC_MOUSE_MOUSEWHEEL_CUST_00)->EnableWindow(enable2);
		GetDlgItem(IDC_MOUSE_MOUSEWHEEL_CUST_01)->EnableWindow(enable2);
		GetDlgItem(IDC_MOUSE_MOUSEWHEEL_CUST_10)->EnableWindow(enable2);
		GetDlgItem(IDC_MOUSE_MOUSEWHEEL_CUST_11)->EnableWindow(enable2);
		
		UpdateData(FALSE);
	}
}

BOOL CPageMouse::OnInitDialog() 
{
	CPropertyPage::OnInitDialog();
	enable_controls();
	return TRUE;
}

void CPageMouse::OnSelchangeMouseMousewheelClickMode() 
{
	enable_controls();
}
