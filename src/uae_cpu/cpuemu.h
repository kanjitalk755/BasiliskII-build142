// Force an EXTRN definiton to the asm file
#ifdef STREAMLINED_UAE
cpuop_func *ref_cpufunctbl(void) {return(cpufunctbl[0]);}
#endif


// These hacks are needed because there is no way to force
// bswap's and xchg's as I want from visual c.
// It's up to vc5opti to replace the bswap registers.


static inline uae_u32 fast_get_ilong(uae_u32 *a)
{
	uint32 x = *a; 
	_asm bswap eax
	return x;
}
#undef get_ilong
#define get_ilong(o) fast_get_ilong((uae_u32 *)(regs.pc_p + (o)))


// Just a temporary hack to see whether this works or not.
// Terrible pairing, makes things actually worse.
/*
static inline uae_u16 fast_get_iword(uae_u16 *a)
{
	uint16 x = *a; 
	_asm bswap ebx
	return x;
}
#undef get_iword
#define get_iword(o) fast_get_iword((uae_u16 *)(regs.pc_p + (o)))
*/


#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
static inline uae_u32 fast_get_long(uae_u32 a)
{
	uae_u32 *p = (uae_u32 *)( MEMBaseDiff + (DWORD)a );
	uae_u32 x = *p;
	_asm bswap eax
	return x;
}
#undef get_long
#define get_long(a) fast_get_long(a)

// This one does not speed up as expected. Why.
/**/
static inline void fast_put_long(uaecptr a, uae_u32 v)
{
	uae_u32 *p = (uae_u32 *)( MEMBaseDiff + (DWORD)a );
	_asm bswap ebp
	*p = v;
}
#undef put_long
#define put_long(a,v) fast_put_long(a,v)
/**/
#endif //OPTIMIZED_8BIT_MEMORY_ACCESS
