// PageMemory.cpp : implementation file
//

#include "stdafx.h"
#include "BasiliskIIGUI.h"
#include "PageMemory.h"
#include "sysdeps.h"
#include "util_windows.h"
#include "rom_patches.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CPageMemory property page

IMPLEMENT_DYNCREATE(CPageMemory, CPropertyPage)

CPageMemory::CPageMemory() : CPropertyPage(CPageMemory::IDD)
{
	//{{AFX_DATA_INIT(CPageMemory)
	m_rom_path = _T("");
	m_ram_size = 0;
	m_rom_type = _T("");
	m_checksum = _T("");
	m_checksum_calc = _T("");
	m_info = _T("");
	//}}AFX_DATA_INIT
}

CPageMemory::~CPageMemory()
{
}

void CPageMemory::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPageMemory)
	DDX_Text(pDX, IDC_MEMORY_ROM_PATH, m_rom_path);
	DDV_MaxChars(pDX, m_rom_path, 255);
	DDX_Text(pDX, IDC_MEMORY_RAM_SIZE, m_ram_size);
	DDV_MinMaxInt(pDX, m_ram_size, 4, 8192);
	DDX_Text(pDX, IDC_MEMORY_ROM_TYPE, m_rom_type);
	DDX_Text(pDX, IDC_MEMORY_ROM_CHECKSUM, m_checksum);
	DDV_MaxChars(pDX, m_checksum, 8);
	DDX_Text(pDX, IDC_MEMORY_ROM_CHECKSUM_CALC, m_checksum_calc);
	DDX_Text(pDX, IDC_MEMORY_INFO, m_info);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CPageMemory, CPropertyPage)
	//{{AFX_MSG_MAP(CPageMemory)
	ON_BN_CLICKED(IDC_MEMORY_ROM_BROWSE, OnMemoryRomBrowse)
	ON_EN_UPDATE(IDC_MEMORY_ROM_PATH, OnUpdateMemoryRomPath)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPageMemory message handlers

void CPageMemory::check_rom_size() 
{
	CFile f;
	char *rom;
	uint32 size = 0, csum1 = 0, csum2 = 0;

	// m_os8_ok = "Unknown";
	m_rom_type = "Unknown";
	m_checksum = "Unknown";
	m_checksum_calc = "Unknown";
	m_info = "";

	if(f.Open(m_rom_path,CFile::modeRead)) {
		size = f.SeekToEnd();
		/*
		if(size == 1048576) {
			m_os8_ok = "Yes";
		} else {
			m_os8_ok = "No";
		}
		*/

		f.SeekToBegin();

		rom = new char [size+4];

		if(size && f.Read( rom, size ) == size) {
			switch( ntohs(*(uint16 *)(rom + 8)) ) {
				case ROM_VERSION_64K:
					m_rom_type = "Original Macintosh ROM (64KB)";
					break;
				case ROM_VERSION_PLUS:
					m_rom_type = "Mac Plus ROM (128KB)";
					break;
				case ROM_VERSION_CLASSIC:
					m_rom_type = "SE/Classic ROM (256/512KB)";
					break;
				case ROM_VERSION_II:
					m_rom_type = "Not 32-bit clean Mac II ROM (256KB)";
					break;
				case ROM_VERSION_32:
					m_rom_type = "32-bit clean Mac II ROM (512KB/1MB)";
					break;
			}
			csum1 = ntohl(*((uint32 *)rom));
			sprintf( m_checksum.GetBuffer(100), "%08X", csum1 );
			m_checksum.ReleaseBuffer();

			uint16 *r = (uint16 *)rom;
			for( uint32 i=2; i<size/2; i++ ) {
				csum2 += ntohs(r[i]);
			}

			sprintf( m_checksum_calc.GetBuffer(100), "%08X", csum2 );
			m_checksum_calc.ReleaseBuffer();

			switch( ntohl(*(uint32 *)rom) ) {

				// 64 KB
				case 0x28BA61CE:
				case 0x28BA4E50:
					m_info += "Identified as Mac 128 or Mac 512\r\n";
					m_info += "Not supported by Basilisk II";
					break;

				// 128 KB
				case 0x4D1EEEE1:
					m_info += "Identified as Mac Plus v1 Lonely Hearts\r\n";
					m_info += "Not supported by Basilisk II";
					break;
				case 0x4D1EEAE1:
					m_info += "Identified as Mac Plus v2 Lonely Heifers\r\n";
					m_info += "Not supported by Basilisk II";
					break;
				case 0x4D1F8172:
					m_info += "Identified as Mac Plus v3 Loud Harmonicas\r\n";
					m_info += "Not supported by Basilisk II";
					break;

				// 256 KB
				case 0xB2E362A8:
				case 0xB306E171:
					m_info += "Identified as Mac SE\r\n";
					m_info += "Not supported by Basilisk II";
					break;
				case 0xA49F9914:
					m_info += "Identified as Mac Classic\r\n";
					m_info += "Classic emulation is currently broken.";
					break;
				case 0x97221136:
					m_info += "Identified as Mac IIcx\r\n";
					m_info += "Not supported by Basilisk II";
					break;
				case 0x9779D2C4:
				case 0x97851DB6:
					m_info += "Identified as Mac II\r\n";
					m_info += "Not supported by Basilisk II";
					break;

				// 512 KB
				case 0x368CADFE:
					m_info += "Identified as Mac IIci\r\n";
					m_info += "FPU must be enabled.\r\n";
					m_info += "AppleTalk is not supported.";
					break;
				case 0x36B7FB6C:
					m_info += "Identified as Mac IIsi\r\n";
					m_info += "AppleTalk is not supported.";
					break;
				case 0x4147DD77:
					m_info += "Identified as Mac IIfx\r\n";
					m_info += "FPU must be enabled.\r\n";
					m_info += "AppleTalk is not supported.";
					break;
				case 0x35C28C8F:
					m_info += "Identified as Mac IIx\r\n";
					m_info += "AppleTalk may not be supported.\r\n";
					m_info += "Not tested by the Windows port author";
					break;
				case 0x4957EB49:
					m_info += "Identified as Mac IIvi\r\n";
					m_info += "AppleTalk may not be supported.\r\n";
					m_info += "Not tested by the Windows port author";
					break;
				case 0x350EACF0:
					m_info += "Identified as Mac LC\r\n";
					m_info += "AppleTalk is not supported.";
					break;
				case 0x35C28F5F:
					m_info += "Identified as Mac LC II\r\n";
					m_info += "AppleTalk is not supported.";
					break;
				case 0x3193670E:
					m_info += "Identified as Mac Classic II\r\n";
					m_info += "May require the FPU.\r\n";
					m_info += "AppleTalk may not be supported.\r\n";
					m_info += "Not tested by the Windows port author";
					break;

				// 1024 KB
				case 0x49579803:
					m_info += "Identified as Mac IIvx\r\n";
					m_info += "Not tested by the Windows port author";
					break;
				case 0xECBBC41C:
					m_info += "Identified as Mac LC III";
					break;
				case 0xECD99DC0:
					m_info += "Identified as Mac Color Classic";
					break;
				case 0xFF7439EE:
					m_info += "Identified as Quadra 605 or LC/Performa 475/575";
					break;
				case 0xF1A6F343:
					m_info += "Identified as Quadra/Centris 610/650/800";
					break;
				case 0xF1ACAD13:	// Mac Quadra 650
					m_info += "Identified as Quadra 650";
					break;
				case 0x420DBFF3:
					m_info += "Identified as Quadra 700/900\r\n";
					m_info += "AppleTalk is not supported.\r\n";
					m_info += "This is the worst known 1MB ROM.";
					break;
				case 0x3DC27823:
					m_info += "Identified as Mac Quadra 950\r\n";
					m_info += "AppleTalk is not supported.";
					break;
				case 0xE33B2724:
					m_info += "Identified as Powerbook 165c\r\n";
					m_info += "Not tested by the Windows port author";
					break;
				case 0x06684214:
					m_info += "Identified as LC/Quadra/Performa 630";
					break;
				case 0x064DC91D:
					m_info += "Identified as Performa 580/588\r\n";
					m_info += "AppleTalk is reported to work.\r\n";
					m_info += "Not tested by the Windows port author";
					break;
				case 0xEDE66CBD:
					m_info += "Maybe Performa 450-550";
					break;

				default:
					m_info += "Unknown ROM\r\n";
					switch(size) {
						case 1048576:
							break;
						case 524288:
							m_info += "AppleTalk is not supported.";
							break;
						case 262144:
							break;
						default:
							m_info += "Unsupported ROM size.";
							break;
					}
					break;
			}
			if(csum1 != csum2) {
				m_info += "\r\nChecksums do not match -- corrupted ROM file.";
			}
		}

		f.Close();

		delete [] rom;
	}
}

void CPageMemory::OnMemoryRomBrowse() 
{
	if(UpdateData(TRUE)) {
		CFileDialog dlg( TRUE, _T("*"), m_rom_path,
					OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT,
					_T("All Files|*.*||") );
		if(dlg.DoModal() == IDOK) {
			m_rom_path = dlg.GetPathName();
			check_rom_size();
			UpdateData(FALSE);
		}
	}
}

void CPageMemory::OnUpdateMemoryRomPath() 
{
	if(UpdateData(TRUE)) {
		check_rom_size();
		// GetDlgItem(IDC_MEMORY_OS8_OK)->SetWindowText( m_os8_ok );
		GetDlgItem(IDC_MEMORY_ROM_TYPE)->SetWindowText( m_rom_type );
		GetDlgItem(IDC_MEMORY_ROM_CHECKSUM)->SetWindowText( m_checksum );
		GetDlgItem(IDC_MEMORY_ROM_CHECKSUM_CALC)->SetWindowText( m_checksum_calc );
	}
}
