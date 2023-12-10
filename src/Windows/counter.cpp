#include "sysdeps.h"
#include "m68k.h"
#include "memory.h"
#include "readcpu.h"
#include "newcpu.h"
#include "compiler.h"
#include "cputbl.h"
#include "counter.h"


#if COUNT_INSTRS
static unsigned long int instrcount[65536];
static uae_u16 opcodenums[65536];

static int __cdecl compfn (const void *el1, const void *el2)
{
  return (int)instrcount[*(const uae_u16 *)el2] - (int)instrcount[*(const uae_u16 *)el1];
}

static char *icountfilename (void)
{
	return COUNT_INSTRS == 2 ? "frequent.68k" : "insncount";
}

void dump_counts (void)
{
	char modestr[2]; // kludge to work around a linker bug
	modestr[0] = 'w';
	modestr[1] = 0;

	FILE *f = fopen (icountfilename (), modestr);
	unsigned long int total = 0;
	int i;

	for (i = 0; i < 65536; i++) {
		opcodenums[i] = i;
		total += instrcount[i];
	}
	qsort (opcodenums, 65536, sizeof(uae_u16), compfn);

	fprintf (f, "Total: %lu\n", total);
	for (i=0; i < 65536; i++) {
		unsigned long int cnt = instrcount[opcodenums[i]];
		struct instr *dp;
		struct mnemolookup *lookup;
		if (!cnt)
			break;
		dp = table68k + opcodenums[i];
		for (lookup = lookuptab;lookup->mnemo != (int)dp->mnemo; lookup++)
			;
		fprintf (f, "%04x: %lu %s\n", opcodenums[i], cnt, lookup->name);
	}
	fclose (f);
}

void init_counts(void)
{
	char modestr[2]; // kludge to work around a linker bug
	modestr[0] = 'r';
	modestr[1] = 0;

	FILE *f = fopen (icountfilename (), modestr);
	memset (instrcount, 0, sizeof instrcount);
	if (f) {
		uae_u32 opcode, count, total;
		char name[20];
		fscanf (f, "Total: %lu\n", &total);
		while (fscanf (f, "%lx: %lu %s\n", &opcode, &count, name) == 3) {
			instrcount[opcode] = count;
		}
		fclose(f);
	}
}

void _fastcall CPUOP_PREFIX(uae_u32 opcode)
{
	_asm {
		push eax
		push ebx
		push ecx
		push edx
		push esi
		push edi
	}

#if COUNT_INSTRS == 2
	uae_u32 op = ((opcode >> 8) & 255) | ((opcode & 255) << 8);
	if (table68k[op].handler != -1)
		instrcount[table68k[op].handler]++;
#elif COUNT_INSTRS == 1
	uae_u32 op = ((opcode >> 8) & 255) | ((opcode & 255) << 8);
	instrcount[op]++;
#endif
	_asm {
		pop edi
		pop esi
		pop edx
		pop ecx
		pop ebx
		pop eax
	}
}

#endif //COUNT_INSTRS
