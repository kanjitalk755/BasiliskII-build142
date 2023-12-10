/*
 *  audio_windows.cpp - Audio support for Win32
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

#include <process.h>
#include "sysdeps.h"
#include "cpu_emulation.h"
#include "main.h"
#include "prefs.h"
#include "user_strings.h"
#include "audio.h"
#include "audio_defs.h"
#include "main_windows.h"
#include "audio_windows.h"
#include "desktop_windows.h"
#include "threads_windows.h"


#define DEBUG 0
#include "debug.h"

#define DUMP_WAV 0
#define SECURE_SOUND_PARAMS 1


// Global variables

// Supported sample rates, sizes and channels
uint32 audio_sample_rates[] = {
	(uint32)8000 << 16,
	(uint32)11025 << 16,
	(uint32)22050 << 16,
	(uint32)44100 << 16
};

uint16 audio_sample_sizes[] = {
	8,
	16
};

uint16 audio_channel_counts[] = {
	1,
	2
};

int audio_num_sample_rates = sizeof(audio_sample_rates)/sizeof(audio_sample_rates[0]);
int audio_num_sample_sizes = sizeof(audio_sample_sizes)/sizeof(audio_sample_sizes[0]);
int audio_num_channel_counts = sizeof(audio_channel_counts)/sizeof(audio_channel_counts[0]);

static HANDLE audio_irq_done_sem;			// Signal from interrupt to streaming thread: data block read
static bool little_endian = false;		// Flag: DSP accepts only little-endian 16-bit sound data

static sound_running = false;

static bool main_mute = false;
static bool dac_mute = false;
static uint32 main_volume = 0x00800080;
static uint32 dac_volume = 0x00800080;

// NOTE this must be aligned to dword boundary.
static LONG playing_sound_count = 0;

static int next_free_sound = 0;
static int next_to_be_played = 0;

static CRITICAL_SECTION sound_csection;
static bool sound_csection_inited = false;

static bool sound_header_update_needed = true;

// The preference value.
static bool nosoundwheninactive;

// Muted because of switched out
static bool sound_muted = false;

// Muted for any reason, set by update_muted_state()
static bool is_sound_muted;

static HWAVEOUT hWaveOut = 0;

#define MAX_AUDIO_BUFFERS 4
typedef struct audio_buffer_s {
	WAVEHDR whdr;
} audio_buffer_t;
audio_buffer_t abufs[MAX_AUDIO_BUFFERS];
static int sound_buffer_size;
static int m_buffer_size_8000;
static int m_buffer_size_11025;
static int m_buffer_size_22050;
static int m_buffer_size_44100;

int m_audio_buffer_count = MAX_AUDIO_BUFFERS;

// MacOS may issue volume control calls when we don't yet have
// a wave out handle to manipulate.
static bool volume_up_to_date = true;

// Prototypes
static unsigned int stream_func(void *arg);


#if DUMP_WAV
static void dumpwav( LPSTR buf, uint32 count )
{
	HFILE hf;

	if(!count) return;

	hf = _lopen( "d:\\dump.wav", OF_READWRITE );
	if(hf == HFILE_ERROR) hf = _lcreat( "d:\\dump.wav", 0 );
	if(hf != HFILE_ERROR) {
		_llseek(hf, 0, SEEK_END);
		_lwrite(hf, buf, count);
		_lclose(hf);
	}
}
#endif

static inline void update_muted_state( void )
{
	is_sound_muted = main_mute | dac_mute | sound_muted;
}

static inline void enter_sound_section(void)
{
	EnterCriticalSection( &sound_csection );
}

static inline void leave_sound_section(void)
{
	LeaveCriticalSection( &sound_csection );
}

static uint32 get_sample_rate( uint32 s )
{
	if( s < 9000 ) return( 8000 );
	if( s < 15000 ) return( 11025 );
	if( s < 33000 ) return( 22050 );
	return( 44100 );
}

static void update_sound_parameters(void)
{
	enter_sound_section();
	sound_header_update_needed = true;
	leave_sound_section();
}

static void update_audio_frames_per_block(void)
{
	switch( get_sample_rate(AudioStatus.sample_rate >> 16) ) {
		case 8000:
			audio_frames_per_block = m_buffer_size_8000;
			break;
		case 11025:
			audio_frames_per_block = m_buffer_size_11025;
			break;
		case 22050:
			audio_frames_per_block = m_buffer_size_22050;
			break;
		case 44100:
			audio_frames_per_block = m_buffer_size_44100;
			break;
		default:
			audio_frames_per_block = m_buffer_size_22050;
			break;
	}
}

/*
 * It is better not to use Windows synchronization primitives here.
 */
static __inline__ update_playing_sound_count(void)
{
	int count = 0;

	if(hWaveOut) {
		for( int i=MAX_AUDIO_BUFFERS-1; i>=0; i-- ) {
			LPWAVEHDR pHeader = &abufs[i].whdr;
			if(pHeader->dwFlags) {
				if(pHeader->dwFlags & WHDR_DONE) {
					waveOutUnprepareHeader( hWaveOut, pHeader, sizeof(WAVEHDR) );
					pHeader->dwFlags = 0;
				} else if(pHeader->dwFlags & WHDR_PREPARED) {
					count++;
				}
			}
		}
	}
	playing_sound_count = count;
}

static void close_sound( void )
{
	D(bug("close_sound\n"));

	if(hWaveOut) {
		waveOutReset( hWaveOut );
		update_playing_sound_count();
		while(playing_sound_count > 0) {
			Sleep(20);
			update_playing_sound_count();
		}
		waveOutClose( hWaveOut );
		hWaveOut = 0;
	}
}

static void init_volume_levels(void)
{
	WAVEFORMATEX wfex;
	MMRESULT mmr;

	D(bug("init_volume_levels\n"));

	wfex.wFormatTag = WAVE_FORMAT_PCM;
	wfex.nChannels = (short)1;
	wfex.nSamplesPerSec = 22050;
	wfex.wBitsPerSample = 8;
	wfex.nBlockAlign = wfex.nChannels;
	wfex.nAvgBytesPerSec = wfex.nSamplesPerSec * wfex.nBlockAlign;
	wfex.cbSize = 0;

	mmr = waveOutOpen(&hWaveOut, WAVE_MAPPER, &wfex, 0, (unsigned long)hInst, CALLBACK_NULL );
	if(mmr != MMSYSERR_NOERROR) {
		D(bug("init_volume_levels failed to get volumes: %X\n",mmr));
		main_volume = (uint32)GetPrivateProfileInt( "Audio", "MainVolume", 0x00800080, ini_file_name );
		dac_volume = (uint32)GetPrivateProfileInt( "Audio", "DacVolume", 0x00800080, ini_file_name );
	} else {
		(void)audio_get_main_volume();
		(void)audio_get_speaker_volume();
    waveOutClose( hWaveOut );
		hWaveOut = 0;
		// Just to make sure.
		playing_sound_count = 0;
	}

	D(bug("init_volume_levels done\n"));
}


/*
 *  Initialization
 */

void AudioInit(void)
{
	D(bug("AudioInit\n"));

	m_audio_buffer_count = PrefsFindInt16("soundbuffers");
	if(m_audio_buffer_count > MAX_AUDIO_BUFFERS)
		m_audio_buffer_count = MAX_AUDIO_BUFFERS;

	audio_has_get_hardware_volume = PrefsFindBool("gethardwarevolume");

	nosoundwheninactive = PrefsFindBool("nosoundwheninactive");

	m_buffer_size_8000 = PrefsFindInt32("soundbuffersize8000");
	m_buffer_size_11025 = PrefsFindInt32("soundbuffersize11025");
	m_buffer_size_22050 = PrefsFindInt32("soundbuffersize22050");
	m_buffer_size_44100 = PrefsFindInt32("soundbuffersize44100");

	InitializeCriticalSection( &sound_csection );
	sound_csection_inited = true;

	// Maximum size stereo,16 bits
	int max_samples;
	max_samples = max(m_buffer_size_8000,m_buffer_size_11025);
	max_samples = max(max_samples,m_buffer_size_22050);
	max_samples = max(max_samples,m_buffer_size_44100);

	sound_buffer_size = 2 * 2 * max_samples;

	for( int i=0; i<m_audio_buffer_count; i++ ) {
		memset( &abufs[i], 0, sizeof(audio_buffer_t) );
		abufs[i].whdr.lpData = (LPSTR)new BYTE [sound_buffer_size];
		abufs[i].whdr.dwBytesRecorded = 0;
	}

	// Init audio status (defaults) and feature flags
	AudioStatus.sample_rate = (uint32)GetPrivateProfileInt( "Audio", "SampleRate", 22050, ini_file_name );
	if( AudioStatus.sample_rate != 8000 &&
			AudioStatus.sample_rate != 11025 &&
			AudioStatus.sample_rate != 22050 &&
			AudioStatus.sample_rate != 44100 )
	{
		AudioStatus.sample_rate = 22050;
	}
	AudioStatus.sample_rate <<= 16;

	AudioStatus.sample_size = GetPrivateProfileInt( "Audio", "SampleSize", 8, ini_file_name );
	if(AudioStatus.sample_size != 8 && AudioStatus.sample_size != 16) {
		AudioStatus.sample_size = 8;
	}

	AudioStatus.channels = GetPrivateProfileInt( "Audio", "Channels", 2, ini_file_name );
	if(AudioStatus.channels != 1 && AudioStatus.channels != 2) {
		AudioStatus.channels = 2;
	}

	update_audio_frames_per_block();

	main_mute = (bool)GetPrivateProfileInt( "Audio", "MainMute", 0, ini_file_name );
	dac_mute = (bool)GetPrivateProfileInt( "Audio", "DacMute", 0, ini_file_name );
	init_volume_levels();
	update_muted_state();

	// This is the Apple Mixer component, not Windows
	AudioStatus.mixer = 0;
	AudioStatus.num_sources = 0;

	audio_component_flags = cmpWantsRegisterMessage | kStereoOut | k16BitOut;

	// Sound disabled in prefs? Then do nothing
	if (PrefsFindBool("nosound"))
		return;

	// Init semaphore
	audio_irq_done_sem = CreateSemaphore( 0, 0, 1, NULL);
	if(!audio_irq_done_sem)
		return;

	update_sound_parameters();

	sound_running = true;

	// Start streaming thread
	threads[THREAD_SOUND_STREAM].h = (HANDLE)_beginthreadex( 0, 0, stream_func, 0, 0, &threads[THREAD_SOUND_STREAM].tid );
	SetThreadPriority( threads[THREAD_SOUND_STREAM].h, threads[THREAD_SOUND_STREAM].priority_running );
	SetThreadAffinityMask( threads[THREAD_SOUND_STREAM].h, threads[THREAD_SOUND_STREAM].affinity_mask );

	// Everything OK
	audio_open = true;
}


/*
 *  Deinitialization
 */

void AudioExit(void)
{
	D(bug("AudioExit\n"));

	sound_running = false;
	if(audio_irq_done_sem) ReleaseSemaphore(audio_irq_done_sem,1,NULL);

	// Make sure we won't hang waiting.
  DWORD endtime = GetTickCount() + 1000;

	while( threads[THREAD_SOUND_STREAM].h && GetTickCount() < endtime ) {
		Sleep(100);
	}

	// Force the threads to stop. Normally they have died already.
	if (threads[THREAD_SOUND_STREAM].h) {
		TerminateThread(threads[THREAD_SOUND_STREAM].h,0);
		threads[THREAD_SOUND_STREAM].h = 0;
		threads[THREAD_SOUND_STREAM].tid = 0;
	}
	if (audio_irq_done_sem) {
		CloseHandle(audio_irq_done_sem);
		audio_irq_done_sem = 0;
	}

	for( int i=0; i<m_audio_buffer_count; i++ ) {
		if(abufs[i].whdr.lpData) delete [] abufs[i].whdr.lpData;
	}

	if(sound_csection_inited) {
		DeleteCriticalSection( &sound_csection );
		sound_csection_inited = false;
	}
}


/*
 *  First source added, start audio stream
 */

void audio_enter_stream()
{
	D(bug("audio_enter_stream\n"));
	// Streaming thread is always running to avoid clicking noises
}


/*
 *  Last source removed, stop audio stream
 */

void audio_exit_stream()
{
	D(bug("audio_exit_stream\n"));
	// Streaming thread is always running to avoid clicking noises
}


/*
 *  Set sampling parameters
 *  "index" is an index into the audio_sample_rates[] etc. arrays
 *  It is guaranteed that AudioStatus.num_sources == 0
 */

void audio_set_sample_rate_byval(uint32 value)
{
	bool changed = (AudioStatus.sample_rate != value);
	if(changed) {
		AudioStatus.sample_rate = value;
		update_audio_frames_per_block();
		update_sound_parameters();
		WritePrivateProfileInt( "Audio", "SampleRate", AudioStatus.sample_rate>>16, ini_file_name );
	}
	D(bug(" audio_set_sample_rate_byval %d\n", AudioStatus.sample_rate));
}

void audio_set_sample_size_byval(uint32 value)
{
	bool changed = (AudioStatus.sample_size != value);
	if(changed) {
		AudioStatus.sample_size = value;
		update_sound_parameters();
		WritePrivateProfileInt( "Audio", "SampleSize", AudioStatus.sample_size, ini_file_name );
	}
	D(bug(" audio_set_sample_size_byval %d\n", AudioStatus.sample_size));
}

void audio_set_channels_byval(uint32 value)
{
	bool changed = (AudioStatus.channels != value);
	if(changed) {
		AudioStatus.channels = value;
		update_sound_parameters();
		WritePrivateProfileInt( "Audio", "Channels", AudioStatus.channels, ini_file_name );
	}
	D(bug(" audio_set_channels_byval %d\n", AudioStatus.channels));
}

void audio_set_sample_rate(int index)
{
	if(index >= 0 && index < audio_num_sample_rates ) {
		audio_set_sample_rate_byval( audio_sample_rates[index] );
		D(bug(" audio_set_sample_rate %d,%d\n", index, AudioStatus.sample_rate));
	}
}

void audio_set_sample_size(int index)
{
	if(index >= 0 && index < audio_num_sample_sizes  ) {
		audio_set_sample_size_byval( audio_sample_sizes[index] );
		D(bug(" audio_set_sample_size %d,%d\n", index,AudioStatus.sample_size));
	}
}

void audio_set_channels(int index)
{
	if(index >= 0 && index < audio_num_channel_counts   ) {
		audio_set_channels_byval( audio_channel_counts[index] );
		D(bug(" audio_set_channels %d,%d\n", index,AudioStatus.channels));
	}
}

static void update_sound_parameters2(void)
{
	WAVEFORMATEX wfex;
	MMRESULT mmr;

	D(bug("update_sound_parameters2\n"));

	little_endian = (AudioStatus.sample_size > 8);

	close_sound();

	wfex.wFormatTag = WAVE_FORMAT_PCM;
	wfex.nChannels = (short)AudioStatus.channels;
	wfex.nSamplesPerSec = get_sample_rate(AudioStatus.sample_rate >> 16);
	wfex.wBitsPerSample = (short)AudioStatus.sample_size;
	wfex.nBlockAlign = wfex.nChannels * (WORD)(AudioStatus.sample_size>>3);
	wfex.nAvgBytesPerSec = wfex.nSamplesPerSec * wfex.nBlockAlign;
	wfex.cbSize = 0;

	if(!is_sound_muted) {
		D(bug("waveOutOpen: nChannels=%d, nSamplesPerSec=%d, wBitsPerSample=%d, nBlockAlign=%d, nAvgBytesPerSec=%d\n",
			(int)wfex.nChannels, (int)wfex.nSamplesPerSec, (int)wfex.wBitsPerSample, (int)wfex.nBlockAlign, (int)wfex.nAvgBytesPerSec
			));
		mmr = waveOutOpen(&hWaveOut, WAVE_MAPPER, &wfex, 0, (unsigned long)hInst, CALLBACK_NULL );
		if(mmr != MMSYSERR_NOERROR) {
			D(bug("could not open wave out: %X\n",mmr));
			hWaveOut = 0;
		} else {
			if(!volume_up_to_date) audio_set_main_volume(main_volume);
		}
	}
	sound_header_update_needed = false;

	D(bug("update_sound_parameters2 done\n"));
}

/*
 *  Streaming function
 */
static uint32 apple_stream_info;	// Mac address of SoundComponentData struct describing next buffer

static unsigned int stream_func(void *arg)
{
	LPWAVEHDR pHeader;

	D(bug("stream_func started\n"));

	set_desktop();

	while (sound_running) {
		if(is_sound_muted && hWaveOut) {
			// Waiting to release the sound card for other Windows apps
			close_sound();
		}
		update_playing_sound_count();
		if (AudioStatus.num_sources && (playing_sound_count < m_audio_buffer_count))
		{
			// Trigger audio interrupt to get new buffer
			// D(bug("stream: triggering irq\n"));
			SetInterruptFlag(INTFLAG_AUDIO);
			TriggerInterrupt();
			// D(bug("stream: waiting for ack\n"));
			WaitForSingleObject(audio_irq_done_sem,INFINITE);
			// D(bug("stream: ack received\n"));

			// Terminating?
			if(!sound_running || !audio_data) break;

			// Get size of audio data
			uint32 apple_stream_info = ReadMacInt32(audio_data + adatStreamInfo);
			if (apple_stream_info) {
				uint32 sample_count = ReadMacInt32(apple_stream_info + scd_sampleCount);

#if SECURE_SOUND_PARAMS
				uint32 num_channels = ReadMacInt16(apple_stream_info + scd_numChannels);
				uint32 sample_size = ReadMacInt16(apple_stream_info + scd_sampleSize);
				uint32 sample_rate = ReadMacInt32(apple_stream_info + scd_sampleRate);
#if DEBUG
				uint32 format = ReadMacInt32(apple_stream_info + scd_format);
#endif

				// Yes, this can happen.
				if(sample_count != 0) {
					if(sample_rate != AudioStatus.sample_rate) {
						audio_set_sample_rate_byval(sample_rate);
					}
					if(num_channels != AudioStatus.channels) {
						audio_set_channels_byval(num_channels);
					}
					if(sample_size != AudioStatus.sample_size) {
						audio_set_sample_size_byval(sample_size);
					}
				}
				int work_size = sample_count * num_channels * (sample_size>>3);
				D(bug("Audio block: %c%c%c%c, count=%d, bits=%d, chan=%d, rate=%d\n", format >> 24, (format >> 16) & 0xff, (format >> 8) & 0xff, format & 0xff, sample_count,sample_size,num_channels,sample_rate>>16));
#else
				int work_size = sample_count * (AudioStatus.sample_size >> 3) * AudioStatus.channels;
				D(bug("stream: work_size %d\n", work_size));
#endif

				if (work_size > sound_buffer_size)
					work_size = sound_buffer_size;
				if (work_size == 0)
					goto silence;

				if(is_sound_muted) {
					uint32 milli_secs = 1000L * sample_count / (AudioStatus.sample_rate >> 16);
					Sleep(milli_secs);
				} else {
					pHeader = &abufs[next_free_sound].whdr;
					next_free_sound++;
					if(next_free_sound == m_audio_buffer_count) next_free_sound = 0;

					// Send data to DSP
					if (little_endian) {
						// Little-endian DSP
						int16 *p = (int16 *)Mac2HostAddr(ReadMacInt32(apple_stream_info + scd_buffer));
						for (int i=0; i<work_size/2; i++)
							((int16 *)pHeader->lpData)[i] = ntohs(p[i]);
					} else {
						memcpy(pHeader->lpData, Mac2HostAddr(ReadMacInt32(apple_stream_info + scd_buffer)), work_size);
					}
					pHeader->dwBufferLength = work_size;
					pHeader->dwFlags = 0;
					pHeader->dwLoops = 0;
					if(sound_header_update_needed) {
						enter_sound_section();
						update_sound_parameters2();
						leave_sound_section();
					}
					if(hWaveOut) {
						waveOutPrepareHeader( hWaveOut, pHeader, sizeof(WAVEHDR) );
						if( MMSYSERR_NOERROR == waveOutWrite( hWaveOut, pHeader, sizeof(WAVEHDR) ) ) {
							playing_sound_count++;
							next_to_be_played++;
							if(next_to_be_played == m_audio_buffer_count) next_to_be_played = 0;
						} else {
							waveOutUnprepareHeader( hWaveOut, pHeader, sizeof(WAVEHDR) );
							pHeader->dwFlags = 0;
						}
					} else {
						// Failed to open Wave Out.
						uint32 milli_secs = 1000L * sample_count / (AudioStatus.sample_rate >> 16);
						Sleep(milli_secs);
					}
				}
#if DUMP_WAV
				dumpwav( pHeader->lpData, work_size );
#endif
				// D(bug("stream: data written\n"));
			} else {
				goto silence;
			}
		} else {
silence:
			Sleep( 50 );
		}
	}

	close_sound();

	D(bug("stream_func end\n"));

	threads[THREAD_SOUND_STREAM].h = 0;
	threads[THREAD_SOUND_STREAM].tid = 0;

	return 0;
}


/*
 *  MacOS audio interrupt, read next data block
 */

void AudioInterrupt(void)
{
	D(bug("AudioInterrupt\n"));

	// Get data from apple mixer
	if(audio_data) {
		if (AudioStatus.mixer) {
			M68kRegisters r;
			r.a[0] = audio_data + adatStreamInfo;
			r.a[1] = AudioStatus.mixer;
			Execute68k(audio_data + adatGetSourceData, &r);
			D(bug(" GetSourceData() returns %08lx\n", r.d[0]));
		} else
			WriteMacInt32(audio_data + adatStreamInfo, 0);
	}

	// Signal stream function
	ReleaseSemaphore(audio_irq_done_sem,1,NULL);
	D(bug("AudioInterrupt done\n"));
}


/*
 *  Get/set volume controls (volume values received/returned have the left channel
 *  volume in the upper 16 bits and the right channel volume in the lower 16 bits;
 *  both volumes are 8.8 fixed point values with 0x0100 meaning "maximum volume"))
 */

bool audio_get_main_mute(void)
{
	D(bug(" audio_get_main_mute %d\n", main_mute));
	return main_mute;
}

uint32 volume_win2mac( uint32 dwVolume, uint32 steps )
{
	uint32 left_win, right_win;
	uint32 left_mac, right_mac;
	uint32 vol;

	left_win = LOWORD(dwVolume);
	right_win = HIWORD(dwVolume);

	left_mac = (DWORD)( ((double)left_win * steps) / 0xFFFF + 0.5 );
	right_mac = (DWORD)( ((double)right_win * steps) / 0xFFFF + 0.5 );

	vol = (left_mac << 16) | right_mac;

	return vol;
}

DWORD volume_mac2win( uint32 vol, uint32 steps )
{
	uint32 left_win, right_win;
	uint32 left_mac, right_mac;
	uint32 dwVolume;

	left_mac = HIWORD(vol);
	right_mac = LOWORD(vol);

	left_win = ((DWORD)left_mac * 0xFFFF) / steps;
	right_win = ((DWORD)right_mac * 0xFFFF) / steps;

	dwVolume = (right_win << 16) | left_win;

	return dwVolume;
}

uint32 audio_get_main_volume(void)
{
	uint32 vol = main_volume;
	DWORD dwVolume;
	MMRESULT mmr;

	if(hWaveOut) {
		mmr = waveOutGetVolume(hWaveOut,&dwVolume);
		if(mmr != MMSYSERR_NOERROR) {
			D(bug("Could not get volume: %X\n",mmr));
		} else {
			vol = main_volume = volume_win2mac(dwVolume,256);
		}
		D(bug(" audio_get_main_volume %X\n", vol));
	}
	return vol;
}

bool audio_get_speaker_mute(void)
{
	D(bug(" audio_get_dac_mute %d\n", dac_mute));
	return dac_mute;
}

uint32 audio_get_speaker_volume(void)
{
	uint32 vol = dac_volume;
	DWORD dwVolume;
	MMRESULT mmr;

	if(hWaveOut) {
		mmr = waveOutGetVolume(hWaveOut,&dwVolume);
		if(mmr != MMSYSERR_NOERROR) {
			D(bug("Could not get volume: %X\n",mmr));
		} else {
			vol = dac_volume = volume_win2mac(dwVolume,256);
		}
		D(bug(" audio_get_dac_volume %X\n", vol));
	}
	return vol;
}

void audio_set_main_mute(bool mute)
{
	D(bug(" audio_set_main_mute %d\n", mute));

	bool was_sound_muted = is_sound_muted;

	main_mute = mute;
	update_muted_state();
	WritePrivateProfileInt( "Audio", "MainMute", main_mute, ini_file_name );

	if(was_sound_muted != is_sound_muted) {
		if(mute) {
			close_sound();
		} else {
			update_sound_parameters();
		}
	}
}

void audio_set_main_volume(uint32 vol)
{
	DWORD dwVolume;
	MMRESULT mmr;

	D(bug("audio_set_main_volume %X\n", vol));
	main_volume = vol;
	WritePrivateProfileInt( "Audio", "MainVolume", main_volume, ini_file_name );

	dwVolume = volume_mac2win(vol,256);
	if(hWaveOut) {
		mmr = waveOutSetVolume(hWaveOut,dwVolume);
		if(mmr != MMSYSERR_NOERROR) {
			D(bug("Could not set volume: %X\n",mmr));
			volume_up_to_date = false;
		} else {
			volume_up_to_date = true;
		}
	} else {
		volume_up_to_date = false;
	}
}

void audio_set_speaker_mute(bool mute)
{
	D(bug(" audio_set_dac_mute %d\n", mute));

	bool was_sound_muted = is_sound_muted;

	dac_mute = mute;
	update_muted_state();
	WritePrivateProfileInt( "Audio", "DacMute", dac_mute, ini_file_name );
	if(was_sound_muted != is_sound_muted) {
		if(mute) {
			close_sound();
		} else {
			update_sound_parameters();
		}
	}
}

void audio_set_speaker_volume(uint32 vol)
{
	DWORD dwVolume;
	MMRESULT mmr;

	D(bug("audio_set_dac_volume %X\n", vol));
	dac_volume = vol;
	WritePrivateProfileInt( "Audio", "DacVolume", dac_volume, ini_file_name );

	dwVolume = volume_mac2win(vol,256);
	if(hWaveOut) {
		mmr = waveOutSetVolume(hWaveOut,dwVolume);
		if(mmr != MMSYSERR_NOERROR) {
			D(bug("Could not set volume: %X\n",mmr));
			volume_up_to_date = false;
		} else {
			volume_up_to_date = true;
		}
	} else {
		volume_up_to_date = false;
	}
}

void audio_switch_inout( bool switch_in )
{
	D(bug("audio_switch_inout %d\n",(int)switch_in));

	if(audio_open && sound_running && nosoundwheninactive) {
		if(switch_in) {
			update_sound_parameters();
			sound_muted = false;
			update_muted_state();
		} else {
			sound_muted = true;
			update_muted_state();
			close_sound();
		}
	}
	D(bug("audio_switch_inout done\n"));
}
