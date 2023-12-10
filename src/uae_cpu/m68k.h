 /* 
  * UAE - The Un*x Amiga Emulator
  * 
  * MC68000 emulation - machine dependent bits
  *
  * Copyright 1996 Bernd Schmidt
  */

#if defined(GENASM)


struct flag_struct {
    unsigned int cznv;
    unsigned int x;
};

void _stdcall SET_ZFLG( uint8 v );
void _stdcall SET_CFLG( uint8 v );
void _stdcall SET_VFLG( uint8 v );
void _stdcall SET_NFLG( uint8 v );
void _stdcall SET_XFLG( uint8 v );

uint8 _stdcall get_zflg( void );
uint8 _stdcall get_cflg( void );
uint8 _stdcall get_vflg( void );
uint8 _stdcall get_nflg( void );
uint8 _stdcall get_xflg( void );
void _stdcall clear_cznv( void );
void _stdcall copy_carry( void );

#define GET_ZFLG get_zflg()
#define GET_CFLG get_cflg()
#define GET_VFLG get_vflg()
#define GET_NFLG get_nflg()
#define GET_XFLG get_xflg()
#define CLEAR_CZNV clear_cznv()
#define COPY_CARRY copy_carry()

#ifdef __cplusplus
extern "C" struct flag_struct regflags;
#else
extern struct flag_struct regflags;
#endif

bool _stdcall cc_ja(void);
bool _stdcall cc_jbe(void);
bool _stdcall cc_jae(void);
bool _stdcall cc_jb(void);
bool _stdcall cc_jne(void);
bool _stdcall cc_je(void);
bool _stdcall cc_jno(void);
bool _stdcall cc_jo(void);
bool _stdcall cc_jns(void);
bool _stdcall cc_js(void);
bool _stdcall cc_jge(void);
bool _stdcall cc_jl(void);
bool _stdcall cc_jg(void);
bool _stdcall cc_jle(void);

#ifdef __cplusplus
extern "C" {
#endif
void _stdcall x86_flag_testl( uint32 v );
void _stdcall  x86_flag_testw( uint16 v );
void _stdcall  x86_flag_testb( uint8 v );
uint32 _stdcall  x86_flag_addl( uint32 s, uint32 d );
uint16 _stdcall  x86_flag_addw( uint16 s, uint16 d );
uint8 _stdcall  x86_flag_addb( uint8 s, uint8 d );
uint32 _stdcall  x86_flag_subl( uint32 s, uint32 d );
uint16 _stdcall  x86_flag_subw( uint16 s, uint16 d );
uint8 _stdcall  x86_flag_subb( uint8 s, uint8 d );
void _stdcall  x86_flag_cmpl( uint32 s, uint32 d );
void _stdcall  x86_flag_cmpw( uint16 s, uint16 d );
void _stdcall  x86_flag_cmpb( uint8 s, uint8 d );
#ifdef __cplusplus
}
#endif


#elif defined(X86_ASSEMBLY)

struct flag_struct {
    unsigned int cznv;
    unsigned int x;
};

#define SET_ZFLG(y) (regflags.cznv = (regflags.cznv & ~0x40) | (((y) & 1) << 6))
#define SET_CFLG(y) (regflags.cznv = (regflags.cznv & ~1) | ((y) & 1))
#define SET_VFLG(y) (regflags.cznv = (regflags.cznv & ~0x800) | (((y) & 1) << 11))
#define SET_NFLG(y) (regflags.cznv = (regflags.cznv & ~0x80) | (((y) & 1) << 7))
#define SET_XFLG(y) (regflags.x = (y))

#define GET_ZFLG ((regflags.cznv >> 6) & 1)
#define GET_CFLG (regflags.cznv & 1)
#define GET_VFLG ((regflags.cznv >> 11) & 1)
#define GET_NFLG ((regflags.cznv >> 7) & 1)
#define GET_XFLG (regflags.x & 1)

#define CLEAR_CZNV (regflags.cznv = 0)
#define COPY_CARRY (regflags.x = regflags.cznv)

#ifdef __cplusplus
extern "C" struct flag_struct regflags;
#else
extern struct flag_struct regflags;
#endif

static __inline__ int cctrue(int cc)
{
    uae_u32 cznv = regflags.cznv;
    switch(cc){
     case 0: return 1;                       /* T */
     case 1: return 0;                       /* F */
     case 2: return (cznv & 0x41) == 0; /* !GET_CFLG && !GET_ZFLG;  HI */
     case 3: return (cznv & 0x41) != 0; /* GET_CFLG || GET_ZFLG;    LS */
     case 4: return (cznv & 1) == 0;        /* !GET_CFLG;               CC */
     case 5: return (cznv & 1) != 0;           /* GET_CFLG;                CS */
     case 6: return (cznv & 0x40) == 0; /* !GET_ZFLG;               NE */
     case 7: return (cznv & 0x40) != 0; /* GET_ZFLG;                EQ */
     case 8: return (cznv & 0x800) == 0;/* !GET_VFLG;               VC */
     case 9: return (cznv & 0x800) != 0;/* GET_VFLG;                VS */
     case 10:return (cznv & 0x80) == 0; /* !GET_NFLG;               PL */
     case 11:return (cznv & 0x80) != 0; /* GET_NFLG;                MI */
     case 12:return (((cznv << 4) ^ cznv) & 0x800) == 0; /* GET_NFLG == GET_VFLG;             GE */
     case 13:return (((cznv << 4) ^ cznv) & 0x800) != 0;/* GET_NFLG != GET_VFLG;             LT */
     case 14:
				cznv &= 0x8c0;
				return (((cznv << 4) ^ cznv) & 0x840) == 0; /* !GET_ZFLG && (GET_NFLG == GET_VFLG);  GT */
     case 15:
				cznv &= 0x8c0;
				return (((cznv << 4) ^ cznv) & 0x840) != 0; /* GET_ZFLG || (GET_NFLG != GET_VFLG);   LE */
    }
    return 0;
}

#ifdef __cplusplus
extern "C" {
#endif
void REGPARAM2 x86_flag_testl( uint32 v );
void REGPARAM2 x86_flag_testw( uint16 v );
void REGPARAM2 x86_flag_testb( uint8 v );
uint32 REGPARAM2 x86_flag_addl( uint32 s, uint32 d );
uint16 REGPARAM2 x86_flag_addw( uint16 s, uint16 d );
uint8 REGPARAM2 x86_flag_addb( uint8 s, uint8 d );
uint32 REGPARAM2 x86_flag_subl( uint32 s, uint32 d );
uint16 REGPARAM2 x86_flag_subw( uint16 s, uint16 d );
uint8 REGPARAM2 x86_flag_subb( uint8 s, uint8 d );
void REGPARAM2 x86_flag_cmpl( uint32 s, uint32 d );
void REGPARAM2 x86_flag_cmpw( uint16 s, uint16 d );
void REGPARAM2 x86_flag_cmpb( uint8 s, uint8 d );
#ifdef __cplusplus
}
#endif



#elif defined(__i386__) || defined(USE_COMPILER)

struct flag_struct {
    unsigned int cznv;
    unsigned int x;
};

#define SET_ZFLG(y) (regflags.cznv = (regflags.cznv & ~0x40) | (((y) & 1) << 6))
#define SET_CFLG(y) (regflags.cznv = (regflags.cznv & ~1) | ((y) & 1))
#define SET_VFLG(y) (regflags.cznv = (regflags.cznv & ~0x800) | (((y) & 1) << 11))
#define SET_NFLG(y) (regflags.cznv = (regflags.cznv & ~0x80) | (((y) & 1) << 7))
#define SET_XFLG(y) (regflags.x = (y))

#define GET_ZFLG ((regflags.cznv >> 6) & 1)
#define GET_CFLG (regflags.cznv & 1)
#define GET_VFLG ((regflags.cznv >> 11) & 1)
#define GET_NFLG ((regflags.cznv >> 7) & 1)
#define GET_XFLG (regflags.x & 1)

#define CLEAR_CZNV (regflags.cznv = 0)
#define COPY_CARRY (regflags.x = regflags.cznv)

#ifdef WIN32
extern struct flag_struct regflags;
#else
extern struct flag_struct regflags __asm__ ("regflags");
#endif

static __inline__ int cctrue(int cc)
{
    uae_u32 cznv = regflags.cznv;
    switch(cc){
     case 0: return 1;                       /* T */
     case 1: return 0;                       /* F */
     case 2: return (cznv & 0x41) == 0; /* !GET_CFLG && !GET_ZFLG;  HI */
     case 3: return (cznv & 0x41) != 0; /* GET_CFLG || GET_ZFLG;    LS */
     case 4: return (cznv & 1) == 0;        /* !GET_CFLG;               CC */
     case 5: return (cznv & 1) != 0;           /* GET_CFLG;                CS */
     case 6: return (cznv & 0x40) == 0; /* !GET_ZFLG;               NE */
     case 7: return (cznv & 0x40) != 0; /* GET_ZFLG;                EQ */
     case 8: return (cznv & 0x800) == 0;/* !GET_VFLG;               VC */
     case 9: return (cznv & 0x800) != 0;/* GET_VFLG;                VS */
     case 10:return (cznv & 0x80) == 0; /* !GET_NFLG;               PL */
     case 11:return (cznv & 0x80) != 0; /* GET_NFLG;                MI */
     case 12:return (((cznv << 4) ^ cznv) & 0x800) == 0; /* GET_NFLG == GET_VFLG;             GE */
     case 13:return (((cznv << 4) ^ cznv) & 0x800) != 0;/* GET_NFLG != GET_VFLG;             LT */
     case 14:
	cznv &= 0x8c0;
	return (((cznv << 4) ^ cznv) & 0x840) == 0; /* !GET_ZFLG && (GET_NFLG == GET_VFLG);  GT */
     case 15:
	cznv &= 0x8c0;
	return (((cznv << 4) ^ cznv) & 0x840) != 0; /* GET_ZFLG || (GET_NFLG != GET_VFLG);   LE */
    }
    return 0;
}

#define x86_flag_testl(v) \
  __asm__ __volatile__ ("testl %1,%1\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv) : "r" (v) : "cc")

#define x86_flag_testw(v) \
  __asm__ __volatile__ ("testw %w1,%w1\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv) : "r" (v) : "cc")

#define x86_flag_testb(v) \
  __asm__ __volatile__ ("testb %b1,%b1\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv) : "q" (v) : "cc")

#define x86_flag_addl(v, s, d) do { \
  __asm__ __volatile__ ("addl %k2,%k1\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv), "=r" (v) : "rmi" (s), "1" (d) : "cc"); \
    COPY_CARRY; \
    } while (0)

#define x86_flag_addw(v, s, d) do { \
  __asm__ __volatile__ ("addw %w2,%w1\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv), "=r" (v) : "rmi" (s), "1" (d) : "cc"); \
    COPY_CARRY; \
    } while (0)

#define x86_flag_addb(v, s, d) do { \
  __asm__ __volatile__ ("addb %b2,%b1\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv), "=q" (v) : "qmi" (s), "1" (d) : "cc"); \
    COPY_CARRY; \
    } while (0)

#define x86_flag_subl(v, s, d) do { \
  __asm__ __volatile__ ("subl %k2,%k1\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv), "=r" (v) : "rmi" (s), "1" (d) : "cc"); \
    COPY_CARRY; \
    } while (0)

#define x86_flag_subw(v, s, d) do { \
  __asm__ __volatile__ ("subw %w2,%w1\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv), "=r" (v) : "rmi" (s), "1" (d) : "cc"); \
    COPY_CARRY; \
    } while (0)

#define x86_flag_subb(v, s, d) do { \
  __asm__ __volatile__ ("subb %b2,%b1\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv), "=q" (v) : "qmi" (s), "1" (d) : "cc"); \
    COPY_CARRY; \
    } while (0)

#define x86_flag_cmpl(s, d) \
  __asm__ __volatile__ ("cmpl %k1,%k2\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv) : "rmi" (s), "r" (d) : "cc")

#define x86_flag_cmpw(s, d) \
  __asm__ __volatile__ ("cmpw %w1,%w2\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv) : "rmi" (s), "r" (d) : "cc")

#define x86_flag_cmpb(s, d) \
  __asm__ __volatile__ ("cmpb %b1,%b2\n\t" \
			"pushfl\n\t" \
			"popl %0\n\t" \
			: "=r" (regflags.cznv) : "qmi" (s), "q" (d) : "cc")

#else

/*
struct flag_struct {
    unsigned int c;
    unsigned int z;
    unsigned int n;
    unsigned int v; 
    unsigned int x;
};
*/

// Good.
/*
#pragma pack(2)
struct flag_struct {
    int8 c;
    int8 v; 
    int8 n;
    int8 z;
    int8 x;
};
#pragma pack()
*/

// Better?
#pragma pack(2)
struct flag_struct {
    int8 n;
    int8 z;
    int8 c;
    int8 v; 
    int8 x;
};
#pragma pack()

extern "C" struct flag_struct regflags;

#define ZFLG (regflags.z)
#define NFLG (regflags.n)
#define CFLG (regflags.c)
#define VFLG (regflags.v)
#define XFLG (regflags.x)

#define SET_CFLG(x) (CFLG = (x))
#define SET_NFLG(x) (NFLG = (x))
#define SET_VFLG(x) (VFLG = (x))
#define SET_ZFLG(x) (ZFLG = (x))
#define SET_XFLG(x) (XFLG = (x))

#define GET_CFLG CFLG
#define GET_NFLG NFLG
#define GET_VFLG VFLG
#define GET_ZFLG ZFLG
#define GET_XFLG XFLG

#define CLEAR_CZNV do { \
 SET_CFLG (0); \
 SET_ZFLG (0); \
 SET_NFLG (0); \
 SET_VFLG (0); \
} while (0)

#define COPY_CARRY (SET_XFLG (GET_CFLG))

static __inline__ int cctrue(const int cc)
{
    switch(cc){
     case 0: return 1;                       /* T */
     case 1: return 0;                       /* F */
     case 2: return !CFLG && !ZFLG;          /* HI */
     case 3: return CFLG || ZFLG;            /* LS */
     case 4: return !CFLG;                   /* CC */
     case 5: return CFLG;                    /* CS */
     case 6: return !ZFLG;                   /* NE */
     case 7: return ZFLG;                    /* EQ */
     case 8: return !VFLG;                   /* VC */
     case 9: return VFLG;                    /* VS */
     case 10:return !NFLG;                   /* PL */
     case 11:return NFLG;                    /* MI */
     case 12:return NFLG == VFLG;            /* GE */
     case 13:return NFLG != VFLG;            /* LT */

/*
ZFLG NFLG VFLG !ZFLG (NFLG == VFLG) Result NFLG ^ VFLG
0    0    0		 1     1							1			 0
0    0    1		 1     0										 1
0    1    0		 1     0										 1
0    1    1		 1     1							1			 0
1    0    0		 0     1										 1
1    0    1		 0     0										 0
1    1    0		 0     0										 0
1    1    1		 0     1										 1
*/

     case 14:return !ZFLG && (NFLG == VFLG); /* GT */
		 // case 14:return (int)((NFLG ^ VFLG) + ZFLG == 0); /* GT */

     case 15:return ZFLG || (NFLG != VFLG);  /* LE */
		 // case 15:return (int)((NFLG ^ VFLG) + ZFLG != 0); /* LE */
    }
    return 0;
}

#endif
