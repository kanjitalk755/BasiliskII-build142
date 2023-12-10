#ifndef _mem_limits_h_
#define _mem_limits_h_

#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS
typedef struct {
	DWORD mem_start;
	DWORD mem_end;
} mem_limits_t;

extern "C" {
	extern mem_limits_t total_mem_limits;
	extern mem_limits_t RAM_mem_limits;
	extern mem_limits_t ROM_mem_limits;
	extern mem_limits_t Video_mem_limits;
}
#endif

#endif // _mem_limits_h_
