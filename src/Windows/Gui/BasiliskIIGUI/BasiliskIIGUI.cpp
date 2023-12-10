#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "BasiliskIIGUIDlg.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

BEGIN_MESSAGE_MAP(CBasiliskIIGUIApp, CWinApp)
	//{{AFX_MSG_MAP(CBasiliskIIGUIApp)
		// NOTE - the ClassWizard will add and remove mapping macros here.
		//    DO NOT EDIT what you see in these blocks of generated code!
	//}}AFX_MSG
	ON_COMMAND(ID_HELP, CWinApp::OnHelp)
END_MESSAGE_MAP()

CBasiliskIIGUIApp::CBasiliskIIGUIApp()
{
	m_run_b2 = FALSE;
}

CBasiliskIIGUIApp theApp;

BOOL CBasiliskIIGUIApp::InitInstance()
{
	HWND w = FindWindow(0,"Basilisk II preferences");
	if(w) {
		ShowWindow( w, SW_SHOWNORMAL );
		BringWindowToTop( w );
		return(0);
	}

#ifdef _AFXDLL
	Enable3dControls();			// Call this when using MFC in a shared DLL
#else
	Enable3dControlsStatic();	// Call this when linking to MFC statically
#endif
	int page = 0;
	CBasiliskIIGUIDlg dlg( "Basilisk II preferences", NULL, page );
	dlg.m_last_active_page = ::GetPrivateProfileInt( "GUI", "Last Active Page", 0, "BasiliskII.ini" );
	m_pMainWnd = &dlg;

	char path[_MAX_PATH];

	if(*m_lpCmdLine) {
		if(*m_lpCmdLine == '\"') m_lpCmdLine++;
		strcpy( path, m_lpCmdLine );
		int len = strlen(path);
		if( len > 0 && path[len-1] == '\"' ) path[len-1] = 0;
	} else {
	  GetModuleFileName( AfxGetInstanceHandle(), path, sizeof(path) );
		char *p = strrchr( path, '\\' );
		*++p = 0;
		m_dir = path;
		strcat( path, "BasiliskII_prefs" );
	}

	dlg.m_prefs_path = path;
	dlg.SetActivePage(dlg.m_last_active_page);
	dlg.read_from_file( dlg.m_prefs_path );
	if(dlg.DoModal() != IDCANCEL) {
		dlg.save_to_file( dlg.m_prefs_path );
	}

	CString lastp_str;
	lastp_str.Format( "%ld", dlg.m_last_active_page );
	::WritePrivateProfileString( "GUI", "Last Active Page", lastp_str, "BasiliskII.ini" );

	if(m_run_b2) {
		CString app;
		app = m_dir + "BasiliskII.EXE";
		if(m_dir.Right(1) == "\\") m_dir = m_dir.Left( m_dir.GetLength()-1 );
		SetCurrentDirectory( m_dir );
		HINSTANCE h = ShellExecute( 
			::GetDesktopWindow(), 
			"open", 
			app, 
			dlg.m_prefs_path, 
			m_dir, 
			SW_SHOWNORMAL
		);
		if( h <= (HINSTANCE)32 ) {
			char msg[300];
			wsprintf( msg, "Could not launch %s", (LPCSTR)app );
			::MessageBox( 0, msg, "Error", MB_OK|MB_ICONSTOP );
		}
	}

	return(0);
}
