// BasiliskIIGUIDlg.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "BasiliskIIGUIDlg.h"
#include "sysdeps.h"
#include "prefs.h"
#include "prefs_windows.h"
#include "threads_windows.h"
#include "..\..\typemap.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

// Disable C4800: 'int' : forcing value to bool 'true' or 'false' (performance warning)
#pragma warning(disable:4800)

/////////////////////////////////////////////////////////////////////////////
// CBasiliskIIGUIDlg dialog

IMPLEMENT_DYNAMIC(CBasiliskIIGUIDlg, CPropertySheet)

void CBasiliskIIGUIDlg::add_pages()
{
	AddPage(&m_page_about);
	AddPage(&m_page_general);
	AddPage(&m_page_memory);
	AddPage(&m_page_screen);
	AddPage(&m_page_keyboard);
	AddPage(&m_page_mouse);
	AddPage(&m_page_disk);
	AddPage(&m_page_floppy);
	AddPage(&m_page_cdrom);
	AddPage(&m_page_scsi);
	AddPage(&m_page_ports);
	AddPage(&m_page_ethernet);
	AddPage(&m_page_router);
	AddPage(&m_page_priorities);
	AddPage(&m_page_audio);
	AddPage(&m_page_tools);
	AddPage(&m_page_extfs);
	// AddPage(&m_page_dr);
	AddPage(&m_page_debug);
	// AddPage(&m_page_experiment);
	AddPage(&m_page_smp);
}
	
CBasiliskIIGUIDlg::CBasiliskIIGUIDlg(UINT nIDCaption, CWnd* pParentWnd, UINT iSelectPage)
	:CPropertySheet(nIDCaption, pParentWnd, iSelectPage)
{
	m_last_active_page = iSelectPage;
	add_pages();
}

CBasiliskIIGUIDlg::CBasiliskIIGUIDlg(LPCTSTR pszCaption, CWnd* pParentWnd, UINT iSelectPage)
	:CPropertySheet(pszCaption, pParentWnd, iSelectPage)
{
	m_last_active_page = iSelectPage;
	add_pages();
}

CBasiliskIIGUIDlg::~CBasiliskIIGUIDlg()
{
}

BEGIN_MESSAGE_MAP(CBasiliskIIGUIDlg, CPropertySheet)
	//{{AFX_MSG_MAP(CBasiliskIIGUIDlg)
	ON_WM_DESTROY()
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CBasiliskIIGUIDlg message handlers

static const char *ether_name( void )
{
	OSVERSIONINFO osv;
	osv.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
	osv.dwPlatformId = VER_PLATFORM_WIN32_WINDOWS;
	GetVersionEx( &osv );

	if(osv.dwPlatformId == VER_PLATFORM_WIN32_WINDOWS) {
		return("ether9x");
	} else {
		if(osv.dwMajorVersion == 4) {
			return("ethernt");
		} else {
			return("ethernt5");
		}
	}
}

void CBasiliskIIGUIDlg::save_to_file( LPCSTR path ) 
{
	SetPrefsFile( path );
	PrefsInit();

	int i;
	for(i=0; i<100; i++) PrefsRemoveItem("cdrom");
	for(i=0; i<100; i++) PrefsRemoveItem("disk");
	for(i=0; i<100; i++) PrefsRemoveItem("floppy");
	for(i=0; i<100; i++) PrefsRemoveItem("replacescsi");
	for(i=0; i<100; i++) PrefsRemoveItem("tcp_port");

	PrefsRemoveItem("scsi0");
	PrefsRemoveItem("scsi1");
	PrefsRemoveItem("scsi2");
	PrefsRemoveItem("scsi3");
	PrefsRemoveItem("scsi4");
	PrefsRemoveItem("scsi5");
	PrefsRemoveItem("scsi6");

	PrefsReplaceInt32( "smp_ethernet", m_page_smp.m_smp_ethernet );
	PrefsReplaceInt32( "smp_serialin", m_page_smp.m_smp_serialin );
	PrefsReplaceInt32( "smp_serialout", m_page_smp.m_smp_serialout );
	PrefsReplaceInt32( "smp_cpu", m_page_smp.m_smp_cpu );
	PrefsReplaceInt32( "smp_60hz", m_page_smp.m_smp_60hz );
	PrefsReplaceInt32( "smp_1hz", m_page_smp.m_smp_1hz );
	PrefsReplaceInt32( "smp_pram", m_page_smp.m_smp_pram );
	PrefsReplaceInt32( "smp_gui", m_page_smp.m_smp_gui );
	PrefsReplaceInt32( "smp_gdi", m_page_smp.m_smp_gdi );
	PrefsReplaceInt32( "smp_dx", m_page_smp.m_smp_dx );
	PrefsReplaceInt32( "smp_fb", m_page_smp.m_smp_fb );
	PrefsReplaceInt32( "smp_audio", m_page_smp.m_smp_audio );

	PrefsReplaceInt16( "bootdrive", m_page_general.m_boot_drive );
	PrefsReplaceInt16( "bootdriver", atoi(m_page_general.m_boot_driver) );
	PrefsReplaceBool( "fpu", m_page_general.m_fpu );
	PrefsReplaceInt32( "modelid", atoi(m_page_general.m_model_id) );
	switch(m_page_general.m_cpu) {
		case 1:
			PrefsReplaceInt32( "cpu", 68030 );
			break;
		case 2:
			PrefsReplaceInt32( "cpu", 68040 );
			break;
		default:
			PrefsReplaceInt32( "cpu", 68020 );
	}

	PrefsReplaceString( "rom", m_page_memory.m_rom_path );
	PrefsReplaceInt32( "ramsize", m_page_memory.m_ram_size * (1024*1024) );

	PrefsReplaceInt32( "framesleepticks", m_page_screen.m_sleep_ticks );
	PrefsReplaceString( "screen", m_page_screen.m_mode_str );
	PrefsReplaceBool( "showfps", m_page_screen.m_show_real_fps );
	PrefsReplaceBool( "disable98optimizations", m_page_screen.m_disable_w98_opt );
	PrefsReplaceString( "DX_fullscreen_refreshrate", m_page_screen.m_refresh_rate );

	PrefsReplaceString( "keyboardfile", m_page_keyboard.m_keyboard_path );
	PrefsReplaceBool( "usealtescape", m_page_keyboard.m_use_alt_escape );
	PrefsReplaceBool( "usealttab", m_page_keyboard.m_use_alt_tab );
	PrefsReplaceBool( "usecontrolescape", m_page_keyboard.m_use_control_escape );
	PrefsReplaceBool( "usealtspace", m_page_keyboard.m_use_alt_space );
	PrefsReplaceBool( "usealtenter", m_page_keyboard.m_use_alt_enter );
	PrefsReplaceInt16( "keyboardtype", atoi(m_page_keyboard.m_keyboard_type) );

	PrefsReplaceInt16( "rightmouse", m_page_mouse.m_right_mouse );
	PrefsReplaceBool( "stickymenu", m_page_mouse.m_os8_mouse );
	PrefsReplaceInt16( "mousewheelmode", m_page_mouse.m_mouse_wheel_mode );
	PrefsReplaceInt16( "mousewheellines", m_page_mouse.m_mouse_lines );
	PrefsReplaceBool( "mousewheelreversex", m_page_mouse.m_mouse_wheel_reverse_x );
	PrefsReplaceBool( "mousewheelreversey", m_page_mouse.m_mouse_wheel_reverse_y );
	PrefsReplaceInt16( "mousewheelclickmode", m_page_mouse.m_mouse_wheel_click_mode );
	PrefsReplaceInt16( "mousemovementmode", m_page_mouse.m_mouse_movement_mode );

	PrefsReplaceString( "mousewheelcust00", m_page_mouse.m_mouse_wheel_cust_00 );
	PrefsReplaceString( "mousewheelcust01", m_page_mouse.m_mouse_wheel_cust_01 );
	PrefsReplaceString( "mousewheelcust10", m_page_mouse.m_mouse_wheel_cust_10 );
	PrefsReplaceString( "mousewheelcust11", m_page_mouse.m_mouse_wheel_cust_11 );

	PrefsReplaceBool( "pollmedia", m_page_disk.m_poll_media );
	int32 disk_inx = 0, disk_count = m_page_disk.m_list.GetSize();
	for( disk_inx=0; disk_inx<disk_count; disk_inx++ ) {
		PrefsAddString("disk", m_page_disk.m_list.GetAt(disk_inx));
	}

	PrefsReplaceBool( "nofloppyboot", !m_page_floppy.m_boot_allowed );
	int32 floppy_inx = 0, floppy_count = m_page_floppy.m_list.GetSize();
	for( floppy_inx=0; floppy_inx<floppy_count; floppy_inx++ ) {
		PrefsAddString("floppy", m_page_floppy.m_list.GetAt(floppy_inx));
	}

	PrefsReplaceBool( "nocdrom", !m_page_cdrom.m_cd_enabled );
	int32 cd_inx = 0, cd_count = m_page_cdrom.m_list.GetSize();
	for( cd_inx=0; cd_inx<cd_count; cd_inx++ ) {
		PrefsAddString("cdrom", m_page_cdrom.m_list.GetAt(cd_inx));
	}
	PrefsReplaceBool( "realmodecd", m_page_cdrom.m_realmodecd );
	

	PrefsReplaceBool( "noscsi", !m_page_scsi.m_scsi_enabled );
	int32 scsi_inx = 0, scsi_count_d = m_page_scsi.m_list_d.GetSize();
	for( scsi_inx=0; scsi_inx<scsi_count_d; scsi_inx++ ) {
		char scsi_str[30];
		sprintf( scsi_str, "scsi%d", scsi_inx );
		PrefsAddString(scsi_str, m_page_scsi.m_list_d.GetAt(scsi_inx));
	}
	int32 scsi_count_r = m_page_scsi.m_list_r.GetSize();
	for( scsi_inx=0; scsi_inx<scsi_count_r; scsi_inx++ ) {
		PrefsAddString("replacescsi", m_page_scsi.m_list_r.GetAt(scsi_inx));
	}

	PrefsReplaceString( "seriala", m_page_ports.m_seriala );
	PrefsReplaceString( "serialb", m_page_ports.m_serialb );
	PrefsReplaceString( "portfile0", m_page_ports.m_portfile0 );
	PrefsReplaceString( "portfile1", m_page_ports.m_portfile1 );

	threads[THREAD_1_HZ].priority_suspended 					= m_page_priorities.m_1hz_idle				- 2;
	threads[THREAD_1_HZ].priority_running 						= m_page_priorities.m_1hz_run					- 2;
	threads[THREAD_60_HZ].priority_suspended 					= m_page_priorities.m_60hz_idle				- 2;
	threads[THREAD_60_HZ].priority_running 						= m_page_priorities.m_60hz_run				- 2;
	threads[THREAD_CPU].priority_suspended 						= m_page_priorities.m_cpu_idle				- 2;
	threads[THREAD_CPU].priority_running 							= m_page_priorities.m_cpu_run					- 2;
	threads[THREAD_SCREEN_DX].priority_suspended 			= m_page_priorities.m_dx_idle					- 2;
	threads[THREAD_SCREEN_DX].priority_running 				= m_page_priorities.m_dx_run					- 2;
	threads[THREAD_ETHER].priority_suspended 					= m_page_priorities.m_ethernet_idle		- 2;
	threads[THREAD_ETHER].priority_running 						= m_page_priorities.m_ethernet_run		- 2;
	threads[THREAD_SCREEN_GDI].priority_suspended 		= m_page_priorities.m_gdi_idle				- 2;
	threads[THREAD_SCREEN_GDI].priority_running 			= m_page_priorities.m_gdi_run					- 2;
	threads[THREAD_SCREEN_LFB].priority_suspended 		= m_page_priorities.m_lfb_idle				- 2;
	threads[THREAD_SCREEN_LFB].priority_running 			= m_page_priorities.m_lfb_run					- 2;
	threads[THREAD_GUI].priority_suspended 						= m_page_priorities.m_gui_idle				- 2;
	threads[THREAD_GUI].priority_running 							= m_page_priorities.m_gui_run					- 2;
	threads[THREAD_PARAMETER_RAM].priority_suspended 	= m_page_priorities.m_pram_idle				- 2;
	threads[THREAD_PARAMETER_RAM].priority_running 		= m_page_priorities.m_pram_run				- 2;
	threads[THREAD_SERIAL_IN].priority_suspended 			= m_page_priorities.m_serial_in_idle	- 2;
	threads[THREAD_SERIAL_IN].priority_running 				= m_page_priorities.m_serial_in_run		- 2;
	threads[THREAD_SERIAL_OUT].priority_suspended 		= m_page_priorities.m_serial_out_idle - 2;
	threads[THREAD_SERIAL_OUT].priority_running 			= m_page_priorities.m_serial_out_run	- 2;
	threads[THREAD_SOUND_STREAM].priority_suspended 	= m_page_priorities.m_sound_stream_idle - 2;
	threads[THREAD_SOUND_STREAM].priority_running 		= m_page_priorities.m_sound_stream_run	- 2;
	threads_put_prefs();

	PrefsReplaceBool( "nosound", !m_page_audio.m_audio_enabled );
	PrefsReplaceInt16( "soundbuffers", m_page_audio.m_audio_buffer_count );
	PrefsReplaceInt32( "soundbuffersize8000", m_page_audio.m_buffer_size_8000 );
	PrefsReplaceInt32( "soundbuffersize11025", m_page_audio.m_buffer_size_11025 );
	PrefsReplaceInt32( "soundbuffersize22050", m_page_audio.m_buffer_size_22050 );
	PrefsReplaceInt32( "soundbuffersize44100", m_page_audio.m_buffer_size_44100 );
	PrefsReplaceBool( "nosoundwheninactive", m_page_audio.m_disable_audio_switchout );
	PrefsReplaceBool( "gethardwarevolume", m_page_audio.m_audio_has_get_hardware_volume );
	PrefsReplaceBool( "usestartupsound", m_page_audio.m_audio_use_startup_sound );

	::WritePrivateProfileString( "Window Positions", "AlwaysOnTop", m_page_tools.m_is_on_top ? "true" : "false", "BasiliskII.ini" );
	PrefsReplaceInt16( "guiautorestart", m_page_tools.m_gui_autorestart );

	PrefsReplaceInt16( "debugscsi", m_page_debug.m_debug_scsi );
	PrefsReplaceInt16( "debugfilesys", m_page_debug.m_debug_filesys );
	PrefsReplaceInt16( "debugserial", m_page_debug.m_debug_serial );
	PrefsReplaceBool( "disableaccuratetimer", m_page_debug.m_debug_disable_accurate_timer );

	::WritePrivateProfileString( "Experiments", "DisableLowMemCache", m_page_tools.m_lowmem_cache ? "true" : "false", "BasiliskII.ini" );
	PrefsReplaceInt32( "idlesleep", m_page_tools.m_sleep );
	PrefsReplaceBool( "idlesleepenabled", m_page_tools.m_sleep_enabled );
	PrefsReplaceInt32( "idletimeout", m_page_tools.m_idle_sleep_timeout );
	PrefsReplaceBool( "disablescreensaver", m_page_tools.m_disable_screensaver );

	if(m_page_ethernet.m_mac  != "" && m_page_ethernet.m_mac != "<None>") {
		PrefsReplaceString( ether_name(), m_page_ethernet.m_mac );
	} else {
		PrefsRemoveItem(ether_name());
	}
	PrefsReplaceInt16( "ethermulticastmode", m_page_ethernet.m_ethernet_mode );
	PrefsReplaceBool( "etherpermanentaddress", m_page_ethernet.m_ethernet_permanent );
	if(m_page_ethernet.m_ether_fake_address.GetLength() == 12) {
		PrefsReplaceString( "etherfakeaddress", m_page_ethernet.m_ether_fake_address );
	} else {
		PrefsRemoveItem("etherfakeaddress");
	}

	PrefsReplaceBool( "routerenabled", m_page_router.m_router_enabled );
	PrefsReplaceString( "ftp_port_list", m_page_router.m_ftp_ports_param );

	int32 tcp_inx = 0, tcp_count = m_page_router.m_tcp_ports_param.GetSize();
	for( tcp_inx=0; tcp_inx<tcp_count; tcp_inx++ ) {
		PrefsAddString("tcp_port", m_page_router.m_tcp_ports_param.GetAt(tcp_inx));
	}

	PrefsReplaceBool( "enableextfs", m_page_extfs.m_enabled );
	if(*m_page_extfs.m_path) PrefsReplaceString( "typemapfile", m_page_extfs.m_path );

	char extdrives[100], *edr = 	extdrives;
	*edr++ = '#'; // A marker to prevent PrefsFindString() from deleting an empty string
	if(m_page_extfs.m_a) *edr++ = 'A';
	if(m_page_extfs.m_b) *edr++ = 'B';
	if(m_page_extfs.m_c) *edr++ = 'C';
	if(m_page_extfs.m_d) *edr++ = 'D';
	if(m_page_extfs.m_e) *edr++ = 'E';
	if(m_page_extfs.m_f) *edr++ = 'F';
	if(m_page_extfs.m_g) *edr++ = 'G';
	if(m_page_extfs.m_h) *edr++ = 'H';
	if(m_page_extfs.m_i) *edr++ = 'I';
	if(m_page_extfs.m_j) *edr++ = 'J';
	if(m_page_extfs.m_k) *edr++ = 'K';
	if(m_page_extfs.m_l) *edr++ = 'L';
	if(m_page_extfs.m_m) *edr++ = 'M';
	if(m_page_extfs.m_n) *edr++ = 'N';
	if(m_page_extfs.m_o) *edr++ = 'O';
	if(m_page_extfs.m_p) *edr++ = 'P';
	if(m_page_extfs.m_q) *edr++ = 'Q';
	if(m_page_extfs.m_r) *edr++ = 'R';
	if(m_page_extfs.m_s) *edr++ = 'S';
	if(m_page_extfs.m_t) *edr++ = 'T';
	if(m_page_extfs.m_u) *edr++ = 'U';
	if(m_page_extfs.m_v) *edr++ = 'V';
	if(m_page_extfs.m_w) *edr++ = 'W';
	if(m_page_extfs.m_x) *edr++ = 'X';
	if(m_page_extfs.m_y) *edr++ = 'Y';
	if(m_page_extfs.m_z) *edr++ = 'Z';
	*edr = 0;
	PrefsReplaceString( "extdrives", extdrives );

	threads_init();

	SavePrefs();
	PrefsExit();
}

void CBasiliskIIGUIDlg::read_from_file( LPCSTR path ) 
{
	const char *str;

	m_prefs_path = path;

	SetPrefsFile( path );
	PrefsInit();

	threads_init();

	m_page_general.m_prefs_path = path;
	m_page_general.m_boot_drive = PrefsFindInt16("bootdrive");

	m_page_smp.m_smp_ethernet = PrefsFindInt32("smp_ethernet");
	m_page_smp.m_smp_serialin = PrefsFindInt32("smp_serialin");
	m_page_smp.m_smp_serialout = PrefsFindInt32("smp_serialout");
	m_page_smp.m_smp_cpu = PrefsFindInt32("smp_cpu");
	m_page_smp.m_smp_60hz = PrefsFindInt32("smp_60hz");
	m_page_smp.m_smp_1hz = PrefsFindInt32("smp_1hz");
	m_page_smp.m_smp_pram = PrefsFindInt32("smp_pram");
	m_page_smp.m_smp_gui = PrefsFindInt32("smp_gui");
	m_page_smp.m_smp_gdi = PrefsFindInt32("smp_gdi");
	m_page_smp.m_smp_dx = PrefsFindInt32("smp_dx");
	m_page_smp.m_smp_fb = PrefsFindInt32("smp_fb");
	m_page_smp.m_smp_audio = PrefsFindInt32("smp_audio");

	CString bootdriver_string;
	bootdriver_string.Format( "%ld", PrefsFindInt16("bootdriver") );
	m_page_general.m_boot_driver = bootdriver_string;

	m_page_general.m_fpu = PrefsFindBool("fpu");
	CString mod_string;
	mod_string.Format( "%ld", PrefsFindInt32("modelid") );
	m_page_general.m_model_id = mod_string;
	m_page_general.check_model_id();

	int32 cpu = PrefsFindInt32("cpu");
	if(cpu == 68030) 
		m_page_general.m_cpu = 1;
	else if(cpu == 68040) 
		m_page_general.m_cpu = 2;
	else
		m_page_general.m_cpu = 0;

	m_page_memory.m_rom_path = PrefsFindString( "rom" );
	m_page_memory.m_ram_size = PrefsFindInt32("ramsize") / (1024*1024);
	m_page_memory.check_rom_size();

	m_page_screen.m_sleep_ticks = PrefsFindInt32("framesleepticks");
  m_page_screen.m_mode_str = PrefsFindString("screen");
	m_page_screen.m_show_real_fps = PrefsFindBool("showfps");
	m_page_screen.m_disable_w98_opt = PrefsFindBool("disable98optimizations");
  m_page_screen.m_refresh_rate = PrefsFindString("DX_fullscreen_refreshrate");

	m_page_keyboard.m_keyboard_path = PrefsFindString( "keyboardfile" );
	m_page_keyboard.m_use_alt_escape = PrefsFindBool("usealtescape");
	m_page_keyboard.m_use_alt_tab = PrefsFindBool("usealttab");
	m_page_keyboard.m_use_control_escape = PrefsFindBool("usecontrolescape");
	m_page_keyboard.m_use_alt_space = PrefsFindBool("usealtspace");
	m_page_keyboard.m_use_alt_enter = PrefsFindBool("usealtenter");
	m_page_keyboard.m_keyboard_type.Format( "%d", PrefsFindInt16( "keyboardtype" ) );

	m_page_mouse.m_right_mouse = PrefsFindInt16("rightmouse");
	m_page_mouse.m_os8_mouse = PrefsFindBool("stickymenu");
	m_page_mouse.m_mouse_wheel_mode= PrefsFindInt16("mousewheelmode");
	m_page_mouse.m_mouse_lines = PrefsFindInt16("mousewheellines");
	m_page_mouse.m_mouse_wheel_reverse_x = PrefsFindBool("mousewheelreversex");
	m_page_mouse.m_mouse_wheel_reverse_y = PrefsFindBool("mousewheelreversey");
	m_page_mouse.m_mouse_wheel_click_mode = PrefsFindInt16("mousewheelclickmode");
	m_page_mouse.m_mouse_movement_mode = PrefsFindInt16("mousemovementmode");

	const char *tmp;
	tmp = PrefsFindString("mousewheelcust00");
	if(tmp) m_page_mouse.m_mouse_wheel_cust_00 = CString(tmp);
	tmp = PrefsFindString("mousewheelcust01");
	if(tmp) m_page_mouse.m_mouse_wheel_cust_01 = CString(tmp);
	tmp = PrefsFindString("mousewheelcust10");
	if(tmp) m_page_mouse.m_mouse_wheel_cust_10 = CString(tmp);
	tmp = PrefsFindString("mousewheelcust11");
	if(tmp) m_page_mouse.m_mouse_wheel_cust_11 = CString(tmp);

	m_page_disk.m_poll_media = PrefsFindBool("pollmedia");
	int32 disk_inx = 0;
	while ((str = PrefsFindString("disk", disk_inx++)) != NULL) {
		m_page_disk.m_list.Add(str);
	}

	m_page_floppy.m_boot_allowed = !PrefsFindBool("nofloppyboot");
	int32 floppy_inx = 0;
	while ((str = PrefsFindString("floppy", floppy_inx++)) != NULL) {
		if(strncmp(str,"$Null",5) != 0) {
			m_page_floppy.m_list.Add(str);
		}
	}

	m_page_cdrom.m_cd_enabled = !PrefsFindBool("nocdrom");
	int32 cd_inx = 0;
	while ((str = PrefsFindString("cdrom", cd_inx++)) != NULL) {
		if(strncmp(str,"$Null",5) != 0) {
			m_page_cdrom.m_list.Add(str);
		}
	}
	m_page_cdrom.m_realmodecd = PrefsFindBool("realmodecd");

	m_page_scsi.m_scsi_enabled = !PrefsFindBool("noscsi");

	if ((str = PrefsFindString("scsi0", 0)) != NULL) m_page_scsi.m_list_d.Add(str);
	if ((str = PrefsFindString("scsi1", 0)) != NULL) m_page_scsi.m_list_d.Add(str);
	if ((str = PrefsFindString("scsi2", 0)) != NULL) m_page_scsi.m_list_d.Add(str);
	if ((str = PrefsFindString("scsi3", 0)) != NULL) m_page_scsi.m_list_d.Add(str);
	if ((str = PrefsFindString("scsi4", 0)) != NULL) m_page_scsi.m_list_d.Add(str);
	if ((str = PrefsFindString("scsi5", 0)) != NULL) m_page_scsi.m_list_d.Add(str);
	if ((str = PrefsFindString("scsi6", 0)) != NULL) m_page_scsi.m_list_d.Add(str);

	int32 scsi_inx_r = 0;
	while ((str = PrefsFindString("replacescsi", scsi_inx_r++)) != NULL) {
		m_page_scsi.m_list_r.Add(str);
	}

	m_page_ports.m_seriala = PrefsFindString("seriala");
	m_page_ports.m_serialb = PrefsFindString("serialb");
	m_page_ports.m_portfile0 = PrefsFindString("portfile0");
	m_page_ports.m_portfile1 = PrefsFindString("portfile1");

	m_page_priorities.from_threads();

	m_page_audio.m_audio_enabled = !PrefsFindBool("nosound");
	m_page_audio.m_audio_buffer_count = PrefsFindInt16("soundbuffers");
	m_page_audio.m_buffer_size_8000 = PrefsFindInt32("soundbuffersize8000");
	m_page_audio.m_buffer_size_11025 = PrefsFindInt32("soundbuffersize11025");
	m_page_audio.m_buffer_size_22050 = PrefsFindInt32("soundbuffersize22050");
	m_page_audio.m_buffer_size_44100 = PrefsFindInt32("soundbuffersize44100");
	m_page_audio.m_disable_audio_switchout = PrefsFindBool("nosoundwheninactive");
	m_page_audio.m_audio_has_get_hardware_volume = PrefsFindBool("gethardwarevolume");
	m_page_audio.m_audio_use_startup_sound = PrefsFindBool("usestartupsound");

	char top_str[100];
	::GetPrivateProfileString( "Window Positions", "AlwaysOnTop", "false", top_str, sizeof(top_str), "BasiliskII.ini" );
	m_page_tools.m_is_on_top = stricmp(top_str,"true") == 0;
	m_page_tools.m_gui_autorestart = PrefsFindInt16("guiautorestart");

	m_page_debug.m_debug_scsi = PrefsFindInt16("debugscsi");
	m_page_debug.m_debug_filesys = PrefsFindInt16("debugfilesys");
	m_page_debug.m_debug_serial = PrefsFindInt16("debugserial");
	m_page_debug.m_debug_disable_accurate_timer = PrefsFindBool("disableaccuratetimer");

	char exp_str[100];
	::GetPrivateProfileString( "Experiments", "DisableLowMemCache", "false", exp_str, sizeof(exp_str), "BasiliskII.ini" );
	m_page_tools.m_lowmem_cache = stricmp(exp_str,"true") == 0;

	m_page_tools.m_sleep = PrefsFindInt32("idlesleep");
	if(m_page_tools.m_sleep < 1) m_page_tools.m_sleep = 1;
	if(m_page_tools.m_sleep > 30) m_page_tools.m_sleep = 30;
	m_page_tools.m_sleep_enabled = PrefsFindBool("idlesleepenabled");
	m_page_tools.m_idle_sleep_timeout = PrefsFindInt32("idletimeout");
	m_page_tools.m_disable_screensaver = PrefsFindBool("disablescreensaver");

	const char *ets;
	ets = PrefsFindString(ether_name());
	if(ets == 0 || *ets == 0) {
	  m_page_ethernet.m_mac = "<None>";
	} else {
	  m_page_ethernet.m_mac = ets;
	}
	m_page_ethernet.m_ethernet_mode = PrefsFindInt16("ethermulticastmode");
	m_page_ethernet.m_ethernet_permanent = PrefsFindBool("etherpermanentaddress");

	const char *ets2;
	ets2 = PrefsFindString("etherfakeaddress");
	if(ets2 == 0 || strlen(ets2) != 12) {
	  m_page_ethernet.m_ether_fake_address = "";
	} else {
	  m_page_ethernet.m_ether_fake_address = ets2;
	}

	m_page_router.m_router_enabled = PrefsFindBool("routerenabled");
	m_page_router.m_ftp_ports_param = PrefsFindString("ftp_port_list");

	int32 tcp_port_inx = 0;
	while ((str = PrefsFindString("tcp_port", tcp_port_inx++)) != NULL) {
		m_page_router.m_tcp_ports_param.Add(str);
	}
	
	m_page_extfs.m_enabled = PrefsFindBool("enableextfs");
	get_typemap_file_name( AfxGetInstanceHandle(), m_page_extfs.m_path.GetBuffer(_MAX_PATH) );
	m_page_extfs.m_path.ReleaseBuffer();

	const char *extdrives = PrefsFindString("extdrives");
	if(extdrives) {
		if(strchr(extdrives,'A')) m_page_extfs.m_a = TRUE;
		if(strchr(extdrives,'B')) m_page_extfs.m_b = TRUE;
		if(strchr(extdrives,'C')) m_page_extfs.m_c = TRUE;
		if(strchr(extdrives,'D')) m_page_extfs.m_d = TRUE;
		if(strchr(extdrives,'E')) m_page_extfs.m_e = TRUE;
		if(strchr(extdrives,'F')) m_page_extfs.m_f = TRUE;
		if(strchr(extdrives,'G')) m_page_extfs.m_g = TRUE;
		if(strchr(extdrives,'H')) m_page_extfs.m_h = TRUE;
		if(strchr(extdrives,'I')) m_page_extfs.m_i = TRUE;
		if(strchr(extdrives,'J')) m_page_extfs.m_j = TRUE;
		if(strchr(extdrives,'K')) m_page_extfs.m_k = TRUE;
		if(strchr(extdrives,'L')) m_page_extfs.m_l = TRUE;
		if(strchr(extdrives,'M')) m_page_extfs.m_m = TRUE;
		if(strchr(extdrives,'N')) m_page_extfs.m_n = TRUE;
		if(strchr(extdrives,'O')) m_page_extfs.m_o = TRUE;
		if(strchr(extdrives,'P')) m_page_extfs.m_p = TRUE;
		if(strchr(extdrives,'Q')) m_page_extfs.m_q = TRUE;
		if(strchr(extdrives,'R')) m_page_extfs.m_r = TRUE;
		if(strchr(extdrives,'S')) m_page_extfs.m_s = TRUE;
		if(strchr(extdrives,'T')) m_page_extfs.m_t = TRUE;
		if(strchr(extdrives,'U')) m_page_extfs.m_u = TRUE;
		if(strchr(extdrives,'V')) m_page_extfs.m_v = TRUE;
		if(strchr(extdrives,'W')) m_page_extfs.m_w = TRUE;
		if(strchr(extdrives,'X')) m_page_extfs.m_x = TRUE;
		if(strchr(extdrives,'Y')) m_page_extfs.m_y = TRUE;
		if(strchr(extdrives,'Z')) m_page_extfs.m_z = TRUE;
	}

	PrefsExit();
}

void CBasiliskIIGUIDlg::OnDestroy() 
{
	m_last_active_page = GetActiveIndex();
	m_prefs_path = m_page_general.m_prefs_path;
	CPropertySheet::OnDestroy();
}

BOOL CBasiliskIIGUIDlg::OnInitDialog()
{
	BOOL bResult = CPropertySheet::OnInitDialog();
	CenterWindow();
	SetWindowPos( &CWnd::wndTopMost, 0, 0, 0, 0, SWP_NOSIZE|SWP_NOMOVE );
	GetDlgItem(IDHELP)->SetWindowText( "&Run (F1)" );
	return bResult;
}

void CBasiliskIIGUIDlg::WinHelp(DWORD dwData, UINT nCmd) 
{
	((CBasiliskIIGUIApp*)AfxGetApp())->m_run_b2 = TRUE;
	PressButton(PSBTN_OK);
}
