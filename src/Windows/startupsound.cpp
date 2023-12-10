/*
 *  startupsound.cpp - startup sound support for Win32. Not complete.
 *
 *  Basilisk II (C) 1997-1999 Christian Bauer
 *
 *  Windows platform specific code copyright (C) Lauri Pesonen
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "sysdeps.h"
#include "cpu_emulation.h"
#include "main.h"
#include "prefs.h"
#include "user_strings.h"
#include "audio.h"
#include "audio_defs.h"
#include "main_windows.h"
#include "audio_windows.h"
#include "startupsound.h"

static bool get_startup_sound(
	uint8 * & wave_data,
	uint32 & data_sz,
	uint32 & sample_rate,
	uint16 & bits_per_sample,
	uint8 & channels
)
{
	bool retval = false;

	uint32 ofs = 0;
	uint32 search_len = 6;
	uint8 search[6];
	search[0] = 0;
	search[1] = 1; // 'snd ' format 1
	search[2] = 0;
	search[3] = 1; // one synthesizer
	search[4] = 0;
	search[5] = sampledSynth;

	uint32 limit = ROMSize - search_len;

	while (ofs < limit) {
		if (!memcmp(ROMBaseHost + ofs, search, search_len)) {
			snd_format_1_ptr snd = (snd_format_1_ptr)( ROMBaseHost + ofs );
			if( // ntohs(snd->type) == 1 &&
					// ntohs(snd->synth_count) == 1 &&
					// && ntohs(snd->fs_rid) == sampledSynth
					ntohs(snd->cmd_count) == 1 &&							// accept only one bufferCmd
					ntohs(snd->cmd_1) == 0x8051								// bufferCmd w/ dataOffsetFlag
			)
			{
				snd_header_ptr sndhdr = (snd_header_ptr)((uint32)snd + ntohl(snd->param2));
				if(!IsBadReadPtr(sndhdr,sizeof(snd_header))) {
					// Does it look like an uncompressed startup sound?
					if(	ntohl(sndhdr->byte_count) > 0x2000
							&& sndhdr->sample_rate != 0
							&& sndhdr->encoding == stdSH
					)
					{
						wave_data = (uint8 *)sndhdr + sizeof(snd_header) + ntohl(sndhdr->dataptr);
						data_sz = ntohl(sndhdr->byte_count);
						sample_rate = ntohl(sndhdr->sample_rate);
						switch( snd->init_option & initStereoMask ) {
							case initMono:
								channels = 1;
								break;
							case initStereo:
								channels = 2;
								break;
							default:
								channels = 1;
								break;
						}
						bits_per_sample = 8;
						retval = true;
						// prefer last sound.
						// break;
					}
				}
			}
		}
		ofs++;
	}

	return retval;
}

static char *get_startup_sound_fname( uint32 checksum )
{
	static char path[_MAX_PATH];

	if(!*path) {
		char folder[_MAX_PATH], *p;
		GetModuleFileName( (HMODULE)hInst, folder, sizeof(folder) );
		p = strrchr( folder, '\\' );
		if(p) {
			*(++p) = 0;
			sprintf( path, "%sstartup_%08x.wav", folder, checksum );
		}
	}
	return path;
}

static void write_pcm_header(
	HFILE hf,
	const uint32 datalen,
	const uint32 sample_rate,
	const uint16 bits_per_sample,
	const uint8 channels
)
{
	pcm_wav_hdr_t hdr;
	int file_size = sizeof(pcm_wav_hdr_t) + datalen;

	memset( &hdr, 0, sizeof(hdr) );
	hdr.nRIFF = mmioFOURCC('R','I','F','F');
	hdr.nTotalBytes = file_size - 8;
	hdr.nWAVE = mmioFOURCC('W','A','V','E');
	hdr.nfmt = mmioFOURCC('f','m','t',' ');
	hdr.nfmtSize = 0x12;
  hdr.format.wFormatTag = WAVE_FORMAT_PCM;
  hdr.format.nChannels = channels;
  hdr.format.nSamplesPerSec = sample_rate;
  hdr.format.nAvgBytesPerSec = sample_rate * channels;
	hdr.format.nBlockAlign = channels;
  hdr.format.wBitsPerSample = bits_per_sample;
  hdr.format.cbSize = 0;
	hdr.ndata = mmioFOURCC('d','a','t','a');
	hdr.nDataLen = datalen;
	_lwrite( hf, (char *)&hdr, sizeof(hdr) );
}

static void save_startup_sound(
	const char *fname,
	const uint8 *wave_data,
	const uint32 datalen,
	const uint32 sample_rate,
	const uint16 bits_per_sample,
	const uint8 channels
)
{
	HFILE hf = _lcreat( fname, 0 );
	if( hf != HFILE_ERROR ) {
		write_pcm_header( hf, datalen, sample_rate, bits_per_sample, channels );
		_lwrite( hf, (char*)wave_data, datalen );
		_lclose(hf);
	}
}

static uint32 get_sample_rate( uint32 s )
{
	if( s < 9000 ) return( 8000 );
	if( s < 15000 ) return( 11025 );
	if( s < 33000 ) return( 22050 );
	return( 44100 );
}

void play_startup_sound( uint32 checksum )
{
	char *fname = get_startup_sound_fname( checksum );

	if(!exists(fname)) {

		uint8 *wave_data;
		uint32 data_sz;
		uint32 sample_rate;
		uint16 bits_per_sample;
		uint8 channels;

		if(get_startup_sound(
			wave_data,
			data_sz,
			sample_rate,
			bits_per_sample,
			channels ) )
		{
			save_startup_sound( fname, wave_data, data_sz, get_sample_rate(sample_rate>>16), bits_per_sample,	channels );
		}
	}
	if(exists(fname)) {
		PlaySound( fname, 0, SND_FILENAME|SND_ASYNC|SND_NODEFAULT|SND_NOWAIT );
	}
}



// Just for fun.
//-----------------------------------------------------------------------------------
#if 0
static bool find_startup_sound_portable( uint8 * & data, uint32 & data_sz )
{
	bool retval = false;

	uint32 ofs = 0;
	uint32 search_len = 6;
	uint8 search[6];
	search[0] = 0;
	search[1] = 1; // 'snd ' format 1
	search[2] = 0;
	search[3] = 1; // one synthesizer
	search[4] = 0;
	search[5] = sampledSynth;

	while (ofs < ROMSize - search_len) {
		if (!memcmp(ROMBaseHost + ofs, search, search_len)) {
			snd_format_1_ptr snd = (snd_format_1_ptr)( ROMBaseHost + ofs );
			if( // ntohs(snd->type) == 1 &&
					// ntohs(snd->synth_count) == 1 &&
					// ntohs(snd->fs_rid) == sampledSynth &&
					ntohs(snd->cmd_count) == 1 &&							// accept only one bufferCmd
					ntohs(snd->cmd_1) == 0x8051								// bufferCmd w/ dataOffsetFlag
			)
			{
				snd_header_ptr sndhdr = (snd_header_ptr)((uint32)snd + ntohl(snd->param2));
				if( sndhdr->encoding == cmpSH ) {
					CmpSoundHeaderPtr cmpsndhdr = (CmpSoundHeaderPtr)sndhdr;
					data = (uint8 *)snd;
					data_sz = ntohl(snd->param2) + 
										sizeof(CmpSoundHeader) + 
										ntohl(cmpsndhdr->samplePtr) +
										ntohl(cmpsndhdr->numFrames); // WRONG!
					retval = true;
				} else if( ntohl(sndhdr->byte_count) > 0x2000
						&& sndhdr->sample_rate != 0
						&& sndhdr->encoding == stdSH
						// && sndhdr->base_freq == 0x3C
				)
				{
					data = (uint8 *)snd;
					data_sz = ntohl(snd->param2) + 
										sizeof(snd_header) + 
										ntohl(sndhdr->dataptr) +
										ntohl(sndhdr->byte_count);
					retval = true;
				}
			}
		}
		ofs++;
	}

	return retval;
}

void play_startup_sound_portable(void)
{
	struct M68kRegisters r;
	struct M68kRegisters save_regs;
	int i;
	uint16 save_sr;

	uint8 *data;
	uint32 data_sz;
	if(!find_startup_sound_portable(data,data_sz)) {
		return;
	}

	for (i=7; i>=0; i--) {
		save_regs.d[i] = m68k_dreg(regs, i);
		save_regs.a[i] = m68k_areg(regs, i);
	}
	save_sr = regs.sr;

	for (i=7; i>=0; i--) {
		r.d[i] = m68k_dreg(regs, i);
		r.a[i] = m68k_areg(regs, i);
	}
	MakeSR();
	r.sr = regs.sr;

	r.d[0] = data_sz;
	Execute68kTrap(0xa722, &r);		// NewHandleSysClear()
	uint32 srcHandle = r.a[0];

	if(srcHandle) {
		OutputDebugString( "srcHandle ok\r\n" );
		uint32 srcPtr = ReadMacInt32( srcHandle );
		uint8 *mac_sound_ptr = Mac2HostAddr(srcPtr);
		memmove( mac_sound_ptr, data, data_sz );

		m68k_areg(regs, 7) -= 2;												// space for retval
		m68k_areg(regs, 7) -= 4;
		WriteMacInt32(m68k_areg(regs, 7), 0);						// SndChannelPtr
		m68k_areg(regs, 7) -= 4;
		WriteMacInt32(m68k_areg(regs, 7), srcHandle);		// SndListHandle
		m68k_areg(regs, 7) -= 2;
		WriteMacInt16(m68k_areg(regs, 7), 0);						// async (ignored)
		Execute68kTrapStackBased( 0xa805, &r, 6 );			// SndPlay()

		// uint16 retval = ReadMacInt16(m68k_areg(regs, 7));

		m68k_areg(regs, 7) += 2;

		r.a[0] = srcHandle;
		Execute68kTrap(0xa023, &r);		// DisposeHandle()
	} else {
		OutputDebugString( "srcHandle failed\r\n" );
	}

	for (i=7; i>=0; i--) {
		m68k_dreg(regs, i) = save_regs.d[i];
		m68k_areg(regs, i) = save_regs.a[i];
	}
	regs.sr = save_sr;
}

void play_xpram_alert_beep(void)
{
	struct M68kRegisters r;
	struct M68kRegisters save_regs;
	int i;
	uint16 save_sr;

	for (i=7; i>=0; i--) {
		save_regs.d[i] = m68k_dreg(regs, i);
		save_regs.a[i] = m68k_areg(regs, i);
	}
	save_sr = regs.sr;

	for (i=7; i>=0; i--) {
		r.d[i] = m68k_dreg(regs, i);
		r.a[i] = m68k_areg(regs, i);
	}
	MakeSR();
	r.sr = regs.sr;

	m68k_areg(regs, 7) -= 2;
	WriteMacInt16(m68k_areg(regs, 7), 0);
	r.a[0] = m68k_areg(regs, 7);
	r.d[0] = 0x2007c;
	Execute68kTrapStackBased( 0xa051, &r, 4 );			// ReadXPRam()
	r.d[0] = ReadMacInt16(m68k_areg(regs, 7));

	// r.d[0] = 1;

	m68k_areg(regs, 7) -= 8;
	m68k_areg(regs, 7) -= 4;
	WriteMacInt32(m68k_areg(regs, 7), 'snd ');
	m68k_areg(regs, 7) -= 2;
	WriteMacInt16(m68k_areg(regs, 7), (uint16)r.d[0]);
	r.d[4] = ReadMacInt8(ResLoad);
	WriteMacInt8(ResLoad, 1);
	Execute68kTrapStackBased( 0xa80c, &r, 7 );			// RGetResource()
	WriteMacInt8(ResLoad, (uint8)r.d[4]);
	r.a[0] = ReadMacInt32(m68k_areg(regs, 7));

	// printf( "RGetResource_retval= 0x%x\r\n", r.a[0] );

	m68k_areg(regs, 7) += 8;

	m68k_areg(regs, 7) -= 2;
	WriteMacInt16(m68k_areg(regs, 7), 0);
	m68k_areg(regs, 7) -= 4;
	WriteMacInt32(m68k_areg(regs, 7), 0);						// SndChannelPtr
	m68k_areg(regs, 7) -= 4;
	WriteMacInt32(m68k_areg(regs, 7), r.a[0]);			// SndListHandle
	m68k_areg(regs, 7) -= 2;
	WriteMacInt16(m68k_areg(regs, 7), 0);						// async (ignored)
	Execute68kTrapStackBased( 0xa805, &r, 6 );			// SndPlay()

	// uint16 SndPlay_retval = ReadMacInt16(m68k_areg(regs, 7));

	m68k_areg(regs, 7) += 2;

	for (i=7; i>=0; i--) {
		m68k_dreg(regs, i) = save_regs.d[i];
		m68k_areg(regs, i) = save_regs.a[i];
	}
	regs.sr = save_sr;
}
#endif
//-----------------------------------------------------------------------------------
