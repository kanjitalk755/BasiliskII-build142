// PageGeneral.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageGeneral.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageGeneral property page

IMPLEMENT_DYNCREATE(CPageGeneral, CPropertyPage)

CPageGeneral::CPageGeneral() : CPropertyPage(CPageGeneral::IDD)
{
	//{{AFX_DATA_INIT(CPageGeneral)
	m_boot_drive = 0;
	m_fpu = FALSE;
	m_prefs_path = _T("");
	m_os8_ok = _T("");
	m_model_id = _T("");
	m_boot_driver = _T("");
	m_cpu = -1;
	//}}AFX_DATA_INIT
}

CPageGeneral::~CPageGeneral()
{
}

void CPageGeneral::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageGeneral)
	DDX_Text(pDX, IDC_GENERAL_BOOT_DRIVE, m_boot_drive);
	DDV_MinMaxInt(pDX, m_boot_drive, 0, 999);
	DDX_Check(pDX, IDC_GENERAL_FPU_ENABLED, m_fpu);
	DDX_Text(pDX, IDC_GENERAL_PREFS_PATH, m_prefs_path);
	DDV_MaxChars(pDX, m_prefs_path, 255);
	DDX_Text(pDX, IDC_GENERAL_OS8_OK, m_os8_ok);
	DDV_MaxChars(pDX, m_os8_ok, 100);
	DDX_CBString(pDX, IDC_GENERAL_MODEL_ID, m_model_id);
	DDX_CBString(pDX, IDC_GENERAL_BOOT_DRIVER, m_boot_driver);
	DDX_CBIndex(pDX, IDC_CPU, m_cpu);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageGeneral, CPropertyPage)
	//{{AFX_MSG_MAP(CPageGeneral)
	ON_CBN_EDITUPDATE(IDC_GENERAL_MODEL_ID, OnEditupdateGeneralModelId)
	ON_CBN_SELCHANGE(IDC_GENERAL_MODEL_ID, OnSelchangeGeneralModelId)
	ON_CBN_EDITCHANGE(IDC_GENERAL_MODEL_ID, OnEditchangeGeneralModelId)
	ON_BN_CLICKED(IDC_GENERAL_PREFS_ASSOCIATE, OnGeneralPrefsAssociate)
	ON_BN_CLICKED(IDC_GENERAL_PREFS_BROWSE, OnGeneralPrefsBrowse)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageGeneral message handlers

void CPageGeneral::check_model_id() 
{
	int id = atoi(m_model_id);
	switch(id) {
		case 5:
		case 7:
		case 21:
		case 31:
		case 38:
		case 39:
		case 42:
		case 43:
		case 50:
		case 56:
		case 74:
		case 75:
		case 77:
			m_os8_ok = "No";
			break;
		case 14:
		case 16:
		case 20:
		case 24:
		case 29:
		case 30:
		case 45:
		case 46:
		case 47:
		case 53:
		case 57:
		case 80:
		case 81:
		case 83:
		case 84:
		case 85:
		case 86:
		case 87:
		case 88:
		case 89:
			m_os8_ok = "Yes";
			break;
		default:
			m_os8_ok = "Not known";
	}
}

void CPageGeneral::OnEditupdateGeneralModelId() 
{
	if(UpdateData(TRUE)) {
		check_model_id();
		GetDlgItem(IDC_GENERAL_OS8_OK)->SetWindowText( m_os8_ok );
	}
}

void CPageGeneral::OnSelchangeGeneralModelId() 
{
	if(UpdateData(TRUE)) {
		check_model_id();
		GetDlgItem(IDC_GENERAL_OS8_OK)->SetWindowText( m_os8_ok );
	}
}

void CPageGeneral::OnEditchangeGeneralModelId() 
{
}

static char *B2_type = "B2 Preference";
static char *B2_type_verbose = "B2 Preference File";
static char *B2_class = "B2 class";

/*
HKEY_CLASSES_ROOT\.bii
	(Default) B2 Preference

HKEY_CLASSES_ROOT\B2 Preference
	(Default) B2 Preference file
	DefaultIcon
		(Default) <Folder>\BasiliskII.exe,1
	shell
		open
			command
				(Default) <Folder>\BasiliskII.exe "%1"
	shell
		Edit in BasiliskIIGUI
			command
				(Default) <Folder>\BasiliskIIGUI.exe "%1"
*/

static void associate()
{
  char gui_path[_MAX_PATH], b2_path[_MAX_PATH], icon_ref[_MAX_PATH];
	char launch_cmd[_MAX_PATH+10], edit_cmd[_MAX_PATH+10];
  HKEY bii_key = 0;
	HKEY pref_key = 0;
  HKEY icon_key = 0;
	HKEY shell_key = 0;
	HKEY open_key = 0;
	HKEY command_key = 0;

  GetModuleFileName( AfxGetInstanceHandle(), gui_path, sizeof(gui_path) );
	strcpy( b2_path, gui_path );
	char *p = strrchr( b2_path, '\\' );
	if(!p) {
		return;
	}
	*++p = 0;
	strcat( p, "BasiliskII.exe" );
	wsprintf( icon_ref, "%s,1", b2_path );
	wsprintf( launch_cmd, "%s \"%%1\"", b2_path );
	wsprintf( edit_cmd, "%s \"%%1\"", gui_path );

	// No error checking here. Why bother.
  RegCreateKeyEx( HKEY_CLASSES_ROOT, ".BII", 0, B2_class, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &bii_key, NULL );
		RegSetValueEx( bii_key, NULL, 0, REG_SZ, (CONST BYTE *)B2_type, strlen(B2_type)+1 );
  RegCloseKey( bii_key );

  RegCreateKeyEx( HKEY_CLASSES_ROOT, B2_type, 0, B2_class, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &pref_key, NULL );

		RegSetValueEx( pref_key, NULL, 0, REG_SZ, (CONST BYTE *)B2_type_verbose, strlen(B2_type_verbose)+1 );

		RegCreateKeyEx( pref_key, "DefaultIcon", 0, B2_class, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &icon_key, NULL );
			RegSetValueEx( icon_key, NULL, 0, REG_SZ, (CONST BYTE *)icon_ref, strlen(icon_ref)+1 );
		RegCloseKey( icon_key );

		RegCreateKeyEx( pref_key, "shell", 0, B2_class, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &shell_key, NULL );
			RegCreateKeyEx( shell_key, "open", 0, B2_class, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &open_key, NULL );
				RegCreateKeyEx( open_key, "command", 0, B2_class, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &command_key, NULL );
					RegSetValueEx( command_key, NULL, 0, REG_SZ, (CONST BYTE *)launch_cmd, strlen(launch_cmd)+1 );
				RegCloseKey( command_key );
			RegCloseKey( open_key );
		RegCloseKey( shell_key );

		RegCreateKeyEx( pref_key, "shell", 0, B2_class, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &shell_key, NULL );
			RegCreateKeyEx( shell_key, "Edit in BasiliskIIGUI", 0, B2_class, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &open_key, NULL );
				RegCreateKeyEx( open_key, "command", 0, B2_class, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &command_key, NULL );
					RegSetValueEx( command_key, NULL, 0, REG_SZ, (CONST BYTE *)edit_cmd, strlen(edit_cmd)+1 );
				RegCloseKey( command_key );
			RegCloseKey( open_key );
		RegCloseKey( shell_key );
	
  RegCloseKey( pref_key );
}

void CPageGeneral::OnGeneralPrefsAssociate() 
{
	associate();
	AfxMessageBox( 
		"File extension *.BII was registered for Basilisk II preference files. "
		"You can now save multiple preference files (just type in a new name with a .BII extension and hit OK) and double-click them in Explorer to launch Basilisk II. "
		"You can edit the old *.BII preference files by right-clicking on them in Explorer and selecting \"Edit in BasiliskIIGUI\" command.\n\n"
		"If you later decide to move the Basilisk II files into a different folder, you need to register the types again.\n\n"
		"Both BasiliskII.exe and BasiliskIIGUI.exe accept a preference file path in the command line, so you can create different shortcuts. "
		"If you launch the GUI or the main application without parameters, the old-style \"BasiliskII_prefs\" file is used."
		,
		MB_OK | MB_ICONINFORMATION
	);
}

void CPageGeneral::OnGeneralPrefsBrowse() 
{
	if(UpdateData(TRUE)) {
		CFileDialog dlg( FALSE, _T("BII"), m_prefs_path,
					OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT,
					_T("Basilisk II prefs files (*.BII)|*.BII|All Files|*.*||") );
		dlg.m_ofn.lpstrTitle = "Select new preference file";
		if(dlg.DoModal() == IDOK) {
			m_prefs_path = dlg.GetPathName();
			UpdateData(FALSE);
		}
	}
}
