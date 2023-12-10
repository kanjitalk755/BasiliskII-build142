#define COUNT_INSTRS 0

#if COUNT_INSTRS

void dump_counts (void);
void init_counts(void);
void _fastcall CPUOP_PREFIX(uae_u32 opcode);

#else //!COUNT_INSTRS

static void dump_counts (void) {}
static void init_counts(void) {}
#define CPUOP_PREFIX(opcode)

#endif //COUNT_INSTRS
