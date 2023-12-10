#ifndef _STARTUP_SOUND_H_
#define _STARTUP_SOUND_H_

// Compression encodings
enum { stdSH=0, extSH=0xFF, cmpSH=0xFE };

// Channels
enum { initMono=0x0080, initStereo=0x00C0, initStereoMask=0x00C0 };

// Synthesizer
enum { squareWaveSynth=1, waveTableSynth=3, sampledSynth=5 };

#define ResLoad 0x0a5e

#pragma pack(1)
typedef struct {
	uint16 type;				// 0x"0001"	//format type
	uint16 synth_count;	// 0x"0001"	//number of synthesizers
	uint16 fs_rid;			// 0x"0005"	//resource ID of first synthesizer
	uint32 init_option;	// 0x"00000080"	//initialization option: initMono
	uint16 cmd_count;		// 0x"0001"	//number of sound commands that follow (1)
	uint16 cmd_1;				// 0x"8051"	//command 1--bufferCmd
	uint16 param1;			// 0x"0000"	//param1 = 0
	uint32 param2;			// // param2 = offset to sound header (20 bytes)
} snd_format_1, *snd_format_1_ptr;

typedef struct {
	uint32 dataptr;			// 0x"00000000"	//pointer to data (it follows immediately)
	uint32 byte_count;	// 0x"00000BB8"	//number of bytes in sample (3000 bytes)
	uint32 sample_rate; // 0x"56EE8BA3"	//sampling rate of this sound (22 kHz)
	uint32 loop_start;	// 0x"000007D0"	//starting of the sample's loop point
	uint32 loop_end;		// 0x"00000898"	//ending of the sample's loop point
	uint8  encoding;		// 0x"00"	//standard sample encoding
	uint8  base_freq;		// 0x"3C"	//baseFrequency at which sample was taken
} snd_header, *snd_header_ptr;

typedef struct {
	uint32 				samplePtr;					/*if nil then samples are in sample area*/
	uint32 				numChannels;				/*number of channels i.e. mono = 1*/
	uint32 				sampleRate;					/*sample rate in Apples Fixed point representation*/
	uint32 				loopStart;					/*loopStart of sound before compression*/
	uint32 				loopEnd;						/*loopEnd of sound before compression*/
	uint8 				encode;							/*data structure used , stdSH, extSH, or cmpSH*/
	uint8 				baseFrequency;			/*same meaning as regular SoundHeader*/
	uint32 				numFrames;					/*length in frames ( packetFrames or sampleFrames )*/
	uint8					AIFFSampleRate[10];	/*IEEE sample rate*/
	uint32				markerChunk;				/*sync track*/
	uint32 				format;							/*data format type, was futureUse1*/
	uint32 				futureUse2;					/*reserved by Apple*/
	uint32 				stateVars;					/*pointer to State Block*/
	uint32 				leftOverSamples;		/*used to save truncated samples between compression calls*/
	uint16 				compressionID;			/*0 means no compression, non zero means compressionID*/
	uint16 				packetSize;					/*number of bits in compressed sample packet*/
	uint16 				snthID;							/*resource ID of Sound Manager snth that contains NRT C/E*/
	uint16 				sampleSize;					/*number of bits in non-compressed sample*/
	// uint8 				sampleArea[1];		/*space for when samples follow directly*/
} CmpSoundHeader, *CmpSoundHeaderPtr;
#pragma pack()

/*
5 kHz 15bba2e8
7			1cfa2e8b
	11		2b7745d1
22		56ee8ba3
22050	56220000
44		ac440000
*/

// Windows specific

#pragma pack(1)
typedef struct {
	DWORD   nRIFF;
	DWORD   nTotalBytes;
	DWORD   nWAVE;
	DWORD   nfmt;
	DWORD   nfmtSize;
	WAVEFORMATEX format;
	DWORD   ndata;
	DWORD   nDataLen;
} pcm_wav_hdr_t;
#pragma pack()

void play_startup_sound( uint32 checksum );

#endif //_STARTUP_SOUND_H_
