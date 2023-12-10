;
;	The "OK" comment only means that some effort has been
; made to optimize the code. It's by no means perfect.
;
; mov	ax, mem
; xchg al, ah			;p01 3 uops
; use..						;usually pstall
; 
; mov	eax, mem		;no size prefix
; bswap	eax				;p01	1 uop, p0	1 uop
; shr	eax, 16			;p0	1 uop
; use..						;no pstall
;
;LAST_align_func

TITLE	Optimized version of cpuemu
.486P
.model FLAT

include listing.inc
include opdefs.inc
include cpuemu.inc

; Just to make easy open from IDE
;include "listing.inc"
;include "opdefs.inc"
;include "cpuemu.inc"


_TEXT	SEGMENT

;include mul.inc


_align_func macro
	; There is no optimal way to automatically align PII(I) ifetch blocks,
	; save for doing it manually each time the code changes. Too much work.
	; 8 is a good compromize.
	ALIGN 8
	; 16 makes detecting the effects of changes easier, but it's not optimal.
	;ALIGN 16
endm


EXTRN	_dump_callback@0:NEAR

; Slows down, used only when debugging
_start_func macro name
;	local SkipOver
;	jmp SkipOver
;	db	'{[(', name, ')]}'
;SkipOver:

	;INSTR_HISTORY
	;pushad
	;call	_dump_callback@0
	;popad

endm


; Some experiments:

EXTRN	_total_mem_limits:DWORD
EXTRN	_RAM_mem_limits:DWORD
EXTRN	_ROM_mem_limits:DWORD
EXTRN	_Video_mem_limits:DWORD

RCHECK macro reg
;	bound	reg, DWORD PTR [_total_mem_limits]
endm


;Of course does not work this way. Only for reference.
RCHECK_SAFE macro reg
; 	bound	reg, DWORD PTR [_RAM_mem_limits]
; 	bound	reg, DWORD PTR [_ROM_mem_limits]
; 	bound	reg, DWORD PTR [_Video_mem_limits]
endm


; MAC_BOOT_FIX: op_1140_0, op_8a8_0, op_2098_0, op_1158_0


_align_func
@op_b0b8_0@4 PROC NEAR					;CMP OK
	_start_func  'op_b0b8_0'
	movzx	edx, WORD PTR [eax+2]
	and	ecx, 14
	add	eax, 4
	bswap	edx
	mov	edi, DWORD PTR _MEMBaseDiff
	shl	ecx, 1
	shr	edx, 16
	mov	DWORD PTR _regs+92, eax
	movsx	ebx, dx
	mov	ebp, DWORD PTR [ebx+edi]
	mov	esi, DWORD PTR _regs[ecx]
	bswap	ebp
	mov	edi,[_cpufunctbl]
	cmp	esi,	ebp
	movzx	ecx, word ptr[eax]
	;decoder is not the bottleneck here
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	jmp	[ecx*4+edi]
@op_b0b8_0@4 ENDP


_align_func
;@op_6e01_0@4 PROC NEAR					;Bcc OK -- ppro variant
;	_start_func  'op_6e01_0'
;	xor	edi, edi
;	add	eax, 2
;	mov	ebx, DWORD PTR _regflags
;	movsx	esi, ch
;	test	bh, bh
;	db 0fh, 045h, 0f7h						; cmovnz  esi,edi
;	cmp	bl, BYTE PTR _regflags+3
;	db 0fh, 045h, 0f7h						; cmovnz  esi,edi
;	mov	edx,[_cpufunctbl]
;	add	eax, esi
;	movzx	ecx, word ptr[eax]
;	mov	DWORD PTR _regs+92, eax
;	jmp	[ecx*4+edx]
;@op_6e01_0@4 ENDP
@op_6e01_0@4 PROC NEAR					;Bcc OK -- order changed
	_start_func  'op_6e01_0'
	mov	ebx, DWORD PTR _regflags
	add	eax, 2
	cmp	bl, BYTE PTR _regflags+3
	mov	edx,[_cpufunctbl]
	je	SHORT $L106579_b					;PII f-time predict no forward branch
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
$L106579_b:
	test	bh, bh
	movsx	esi, ch
	je	SHORT $L106579
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
$L106579:
	add	eax, esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_6e01_0@4 ENDP
;@op_6e01_0@4 PROC NEAR					;Bcc OK -- combined
;	_start_func  'op_6e01_0'
;	mov	ebx, DWORD PTR _regflags
;	lea	eax, DWORD PTR [eax+2]
;	movsx	esi, ch
;	test	bh, bh
;	jne	SHORT $L106579
;	xor	edx, edx		;avoid pstall
;	cmp	bl, BYTE PTR _regflags+3	;TODO: break the long dependency chain
;	setne	dl				;1,0
;	mov	edi,[_cpufunctbl]
;	dec edx					;0,-1
;	and	edx, esi
;	add	eax, edx
;	mov	DWORD PTR _regs+92, eax
;	movzx	ecx, word ptr[eax]
;	jmp	[ecx*4+edi]
;$L106579:
;	mov	DWORD PTR _regs+92, eax
;	mov	edx,[_cpufunctbl]
;	movzx	ecx, word ptr[eax]
;	jmp	[ecx*4+edx]
;@op_6e01_0@4 ENDP


_align_func
@op_6701_0@4 PROC NEAR			;Bcc OK (branch free)
	_start_func  'op_6701_0'
	movzx	esi, BYTE PTR _regflags+1	;1,0
	movsx	ecx, ch
	neg esi					;-1,0
	add	eax, 2
	and	ecx, esi
	mov	edx,[_cpufunctbl]
	add	eax, ecx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_6701_0@4 ENDP


_align_func
;@op_51c8_0@4 PROC NEAR					;DBcc OK -- ppro variant
;	_start_func  'op_51c8_0'
;	mov	edx, DWORD PTR [eax+2]
;	shr	ecx, 8
;	bswap edx
;	and	ecx, 7
;	movzx	esi, WORD PTR _regs[ecx*4]
;	shr	edx, 16
;	lea	ebx, DWORD PTR [esi-1]
;	add	eax, 4
;	movsx	edi, dx
;	test	esi, esi
;	lea	edi, DWORD PTR [eax+edi-2]
;	mov	WORD PTR _regs[ecx*4], bx
;	db 0fh, 045h, 0c7h						; cmovnz  eax,edi
;	mov	esi,[_cpufunctbl]
;	movzx	ecx, word ptr[eax]
;	mov	DWORD PTR _regs+92, eax
;	jmp	[ecx*4+esi]
;@op_51c8_0@4 ENDP
@op_51c8_0@4 PROC NEAR					;DBcc OK
	_start_func  'op_51c8_0'
	shr	ecx, 6
	movzx	edx, WORD PTR [eax+2]
	and	ecx, 28
	bswap edx
	movzx	esi, WORD PTR _regs[ecx]
	shr	edx, 16
	lea	ebx, DWORD PTR [esi-1]
	test	esi, esi
	mov	WORD PTR _regs[ecx], bx
	movsx	edi, dx
	je	SHORT $L73917
	lea	eax, DWORD PTR [eax+edi+2]
	mov	esi,[_cpufunctbl]
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+esi]
$L73917:
	add	eax, 4
	mov	edi,[_cpufunctbl]
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edi]
@op_51c8_0@4 ENDP


_align_func
@op_6001_0@4 PROC NEAR					;Bcc OK
	_start_func  'op_6001_0'
	movsx	ecx, ch
	mov	edx,[_cpufunctbl]
	lea	eax, DWORD PTR [ecx+eax+2]
	movzx	ecx, word ptr[eax]
	mov	DWORD PTR _regs+92, eax
	jmp	[ecx*4+edx]
@op_6001_0@4 ENDP


_align_func
@op_6601_0@4 PROC NEAR			;Bcc OK (branch free)
	_start_func  'op_6601_0'
	movzx	esi, BYTE PTR _regflags+1	;1,0
	movsx	ecx, ch
	dec esi					;0,-1
	add	eax, 2
	and	ecx, esi
	add	eax, ecx
	mov	edx,[_cpufunctbl]
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_6601_0@4 ENDP


_align_func
@op_2028_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2028_0'
	movzx	edx, WORD PTR [eax+2]
	mov	ebx, ecx
	bswap	edx
	shr	ebx, 8
	mov	edi, DWORD PTR _MEMBaseDiff
	shr	edx, 16
	and	ebx, 7
	add	eax, 4
	mov	ebp, DWORD PTR _regs[ebx*4+32]
	movsx	edx, dx
	mov	esi,[_cpufunctbl]
	add	edi, edx
	xor	edx, edx
	mov	ebx, DWORD PTR [edi+ebp]
	mov	DWORD PTR _regs+92, eax
	bswap	ebx
	and	ecx, 14
	cmp	ebx, edx
	mov	DWORD PTR _regs[ecx*2], ebx
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	movzx	ecx, word ptr[eax]
	mov	WORD PTR _regflags+2, dx
	jmp	[ecx*4+esi]
@op_2028_0@4 ENDP


_align_func
@op_20d8_0@4 PROC NEAR					;MOVE (Ax)++,(Ay)++	OK (FIXED) (FIXED again by Akihiko Matsuo) 
	_start_func  'op_20d8_0'
	mov	ebx, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	ebx, 8
	add	eax, 2
	and	ebx, 7
	mov	DWORD PTR _regs+92, eax
	mov	edi, DWORD PTR _regs[ebx*4+32]			;srca
	and	ecx, 14
	mov	edx, DWORD PTR [edi+esi]						;src
	add	edi, 4
	mov	DWORD PTR _regs[ebx*4+32], edi			;srcreg += 4
	mov	ebp, DWORD PTR _regs[ecx*2+32]			;dsta
	mov	DWORD PTR [esi+ebp], edx
	add	ebp, 4
	bswap	edx
	xor	ebx, ebx
	mov	DWORD PTR _regs[ecx*2+32], ebp			;dstreg += 4
	cmp	edx, ebx														;FIXED
	mov	esi,[_cpufunctbl]
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	movzx	ecx, word ptr[eax]
	mov	WORD PTR _regflags+2, bx
	jmp	[ecx*4+esi]
@op_20d8_0@4 ENDP
;@op_20d8_0@4 PROC NEAR					;MOVE (Ax)++,(Ay)++	(Bug when srcreg == dstreg)
;	_start_func  'op_20d8_0'
;	mov	ebx, ecx
;	mov	esi, DWORD PTR _MEMBaseDiff
;	shr	ebx, 8
;	add	eax, 2
;	and	ebx, 7
;	mov	DWORD PTR _regs+92, eax
;	mov	edi, DWORD PTR _regs[ebx*4+32]			;srca
;	and	ecx, 14
;	mov	edx, DWORD PTR [edi+esi]						;src
;	mov	ebp, DWORD PTR _regs[ecx*2+32]			;dsta
;	add	edi, 4
;	mov	DWORD PTR [esi+ebp], edx
;	mov	DWORD PTR _regs[ebx*4+32], edi			;srcreg += 4
;	add	ebp, 4
;	bswap	edx
;	xor	ebx, ebx
;	mov	DWORD PTR _regs[ecx*2+32], ebp			;dstreg += 4
;	cmp	edx, ebx														;FIXED
;	mov	esi,[_cpufunctbl]
;	setl	BYTE PTR _regflags
;	sete	BYTE PTR _regflags+1
;	movzx	ecx, word ptr[eax]
;	mov	WORD PTR _regflags+2, bx
;	jmp	[ecx*4+esi]
;@op_20d8_0@4 ENDP


_align_func
@op_2068_0@4 PROC NEAR					;MOVEA OK
	_start_func  'op_2068_0'
	movzx	edx, WORD PTR [eax+2]
	mov	ebx, ecx
	bswap	edx
	shr	ecx, 8
	add	eax, 4
	shr	edx, 16
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	esi, DWORD PTR _regs[ecx*4+32]
	movsx	edx, dx
	mov	edi,[_cpufunctbl]
	add	edx, esi
	mov	ebp, DWORD PTR [edx+ebp]
	and	ebx, 14
	bswap	ebp
	movzx	ecx, word ptr[eax]
	mov	DWORD PTR _regs[ebx*2+32], ebp
	jmp	[ecx*4+edi]
@op_2068_0@4 ENDP


_align_func
@op_20c0_0@4 PROC NEAR					;MOVE Ax,(Ay)++ OK
	_start_func  'op_20c0_0'
	mov	ebx, ecx
	add	eax, 2
	shr	ecx, 8
	and	ebx, 14
	and	ecx, 7
	mov	edi, DWORD PTR _regs[ebx*2+32]
	mov	ecx, DWORD PTR _regs[ecx*4]
	xor	edx, edx
	lea	esi, DWORD PTR [edi+4]
	cmp	ecx, edx
	mov	DWORD PTR _regs[ebx*2+32], esi
	mov	ebx, DWORD PTR _MEMBaseDiff
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	bswap	ecx
	mov	WORD PTR _regflags+2, dx
	mov	DWORD PTR [ebx+edi], ecx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20c0_0@4 ENDP


_align_func
@op_6401_0@4 PROC NEAR					;Bcc OK (branch free)
	_start_func  'op_6401_0'
	movzx	ebx, BYTE PTR _regflags+2
	add	eax, 2
	dec ebx					;0,-1
	movsx	ecx, ch
	and	ecx, ebx
	add	eax, ecx
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_6401_0@4 ENDP


_align_func
@op_7000_0@4 PROC NEAR					;MOVE imm OK
	_start_func  'op_7000_0'
	xor	edx, edx
	movsx	ebx, ch
	add	eax, 2
	and	ecx, 14
	cmp	ebx, edx
	mov	DWORD PTR _regs+92, eax
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	mov	DWORD PTR _regs[ecx*2], ebx
	mov	edi,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	mov	WORD PTR _regflags+2, dx
	jmp	[ecx*4+edi]
@op_7000_0@4 ENDP


_align_func
@op_f620_0@4 PROC NEAR					;MOVE16 OK
	_start_func  'op_f620_0'
	mov	ebx, DWORD PTR [eax+2]
	shr	ecx, 8
	shr	ebx, 4
	and	ecx, 7
	and	ebx, 7
	add	eax, 4
	mov	edi, DWORD PTR _regs[ebx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	lea	ebp, DWORD PTR [edi+16]
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	DWORD PTR _regs[ebx*4+32], ebp
	and	edi, -16				; fffffff0H
	lea	ebp, DWORD PTR [esi+16]
	add	edi, edx
	and	esi, -16				; fffffff0H
	mov	DWORD PTR _regs[ecx*4+32], ebp
	add	esi, edx
	mov	ebx,[_cpufunctbl]
	; Dont use rep movsd in short moves
	mov	edx, DWORD PTR [esi]
	mov	ebp, DWORD PTR [esi+4]
	mov	DWORD PTR [edi], edx
	mov	DWORD PTR [edi+4], ebp
	mov	edx, DWORD PTR [esi+8]
	mov	ebp, DWORD PTR [esi+12]
	mov	DWORD PTR [edi+8], edx
	mov	DWORD PTR [edi+12], ebp
	movzx	ecx, word ptr[eax]
	mov	DWORD PTR _regs+92, eax
	jmp	[ecx*4+ebx]
@op_f620_0@4 ENDP


_align_func
@op_d1c0_0@4 PROC NEAR					;ADDA OK
	_start_func  'op_d1c0_0'
	mov	ebx, ecx
	add	eax, 2
	shr	ecx, 8
	and	ebx, 14
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	edx, DWORD PTR _regs[ebx*2+32]
	add	edx, ecx
	mov	esi,[_cpufunctbl]
	mov	DWORD PTR _regs[ebx*2+32], edx
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+esi]
@op_d1c0_0@4 ENDP


_align_func
@op_2018_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2018_0'
	mov	edi, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	edi, 8
	add	eax, 2
	and	edi, 7
	mov	edx, DWORD PTR _regs[edi*4+32]
	mov	DWORD PTR _regs+92, eax
	mov	edx, DWORD PTR [edx+esi]
	xor	ebx, ebx
	bswap	edx
	mov	esi, DWORD PTR _regs[edi*4+32]
	add	esi, 4
	cmp	edx, ebx
	mov	DWORD PTR _regs[edi*4+32], esi
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	mov	WORD PTR _regflags+2, bx
	and	ecx, 14
	mov	DWORD PTR _regs[ecx*2], edx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2018_0@4 ENDP


_align_func
@op_2108_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2108_0'
	mov	esi, ecx
	add	eax, 2
	shr	ecx, 8
	and	esi, 14
	and	ecx, 7
	mov	edx, DWORD PTR _regs[esi*2+32]
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	sub	edx, 4
	xor	ebx, ebx
	mov	DWORD PTR _regs[esi*2+32], edx
	cmp	ecx, ebx
	mov	edi, DWORD PTR _MEMBaseDiff
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	bswap	ecx
	add	edi, edx
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	mov	DWORD PTR [edi], ecx
	movzx	ecx, word ptr[eax]
	mov	WORD PTR _regflags+2, bx
	jmp	[ecx*4+edx]
@op_2108_0@4 ENDP


_align_func
@op_4a10_0@4 PROC NEAR					;TST OK
	_start_func  'op_4a10_0'
	shr	ecx, 8
	mov	edi, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	xor	edx, edx
	mov	esi, DWORD PTR _regs[ecx*4+32]
	add	eax, 2
	mov	bl, BYTE PTR [esi+edi]
	mov	DWORD PTR _regs+92, eax
	cmp	bl, dl
	mov	edi,[_cpufunctbl]
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	movzx	ecx, word ptr[eax]
	mov	WORD PTR _regflags+2, dx
	jmp	[ecx*4+edi]
@op_4a10_0@4 ENDP


_align_func
@op_2058_0@4 PROC NEAR					;MOVEA OK
	_start_func  'op_2058_0'
	mov	ebx, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	ebx, 8
	and	ecx, 14
	and	ebx, 7
	add	eax, 2
	mov	edi, DWORD PTR _regs[ebx*4+32]
	mov	DWORD PTR _regs+92, eax
	mov	edx, DWORD PTR [edi+esi]
	bswap	edx
	add	edi, 4
	mov	esi,[_cpufunctbl]
	mov	DWORD PTR _regs[ebx*4+32], edi	;This assign. must be first
	mov	DWORD PTR _regs[ecx*2+32], edx
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+esi]
@op_2058_0@4 ENDP


_align_func
@op_b1d0_0@4 PROC NEAR					;CMPA OK
	_start_func  'op_b1d0_0'
	mov	ebx, ecx
	add	eax, 2
	shr	ebx, 8
	and	ecx, 14
	and	ebx, 7
	mov	DWORD PTR _regs+92, eax
	mov	edx, DWORD PTR _regs[ebx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*2+32]
	mov	edx, DWORD PTR [edx+edi]
	movzx	ecx, word ptr[eax]
	bswap	edx
	mov	edi,[_cpufunctbl]
	cmp	esi, edx
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	jmp	[ecx*4+edi]
@op_b1d0_0@4 ENDP


_align_func
@op_6d01_0@4 PROC NEAR					;Bcc OK
	_start_func  'op_6d01_0'
	mov	dl, BYTE PTR _regflags
	add	eax, 2
	mov	bl, BYTE PTR _regflags+3
	movsx	ecx, ch
	cmp	dl, bl
	je	SHORT $L74114
	add	eax, ecx
$L74114:
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_6d01_0@4 ENDP


_align_func
@op_3028_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_3028_0'
	mov	ebx, ecx
	movzx	edx, WORD PTR [eax+2]
	shr	ebx, 8
	bswap	edx
	and	ebx, 7
	shr	edx, 16
	mov	esi, DWORD PTR _regs[ebx*4+32]
	movsx	edx, dx
	mov	edi, DWORD PTR _MEMBaseDiff
	add	edx, esi
	add	eax, 4
	movzx	ebx, WORD PTR [edx+edi]
	mov	DWORD PTR _regs+92, eax
	bswap	ebx
	xor	edx, edx
	shr	ebx, 16
	and	ecx, 14
	cmp	bx, dx
	mov	WORD PTR _regflags+2, dx
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	mov	WORD PTR _regs[ecx*2], bx
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_3028_0@4 ENDP


_align_func
@op_5048_0@4 PROC NEAR					;ADDA OK
	_start_func  'op_5048_0'
	mov	ebx, ecx
	add	eax, 2
	shr	ebx, 8
	and	ecx, 14
	and	ebx, 7
	mov	esi, DWORD PTR _imm8_table[ecx*2]
	mov	edx, DWORD PTR _regs[ebx*4+32]
	mov	DWORD PTR _regs+92, eax
	add	edx, esi
	mov	edi,[_cpufunctbl]
	mov	DWORD PTR _regs[ebx*4+32], edx
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edi]
@op_5048_0@4 ENDP


_align_func
@op_3018_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_3018_0'
	mov	esi, ecx
	mov	ebx, DWORD PTR _MEMBaseDiff
	shr	esi, 8
	xor	edx, edx
	and	esi, 7
	add	eax, 2
	mov	edi, DWORD PTR _regs[esi*4+32]
	and	ecx, 14
	movzx	ebx, WORD PTR [edi+ebx]
	add	edi, 2
	bswap ebx
	mov	DWORD PTR _regs[esi*4+32], edi
	shr	ebx, 16
	mov	DWORD PTR _regs+92, eax
	cmp	bx, dx
	mov	WORD PTR _regs[ecx*2], bx
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	mov	edi,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	mov	WORD PTR _regflags+2, dx
	jmp	[ecx*4+edi]
@op_3018_0@4 ENDP


_align_func
@op_6c01_0@4 PROC NEAR					;Bcc OK
	_start_func  'op_6c01_0'
	mov	edx, DWORD PTR _regflags
	add	eax, 2
	cmp	dl, BYTE PTR _regflags+3
	movsx	ecx, ch
	je	SHORT $L74166
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
$L74166:
	add	eax, ecx
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_6c01_0@4 ENDP
;@op_6c01_0@4 PROC NEAR					;Bcc OK
;	_start_func  'op_6c01_0'
;	mov	edx, DWORD PTR _regflags
;	add	eax, 2
;	cmp	dl, BYTE PTR _regflags+3
;	movsx	ecx, ch
;	jne	SHORT $L74166
;	add	eax, ecx
;$L74166:
;	mov	DWORD PTR _regs+92, eax
;	mov	edx,[_cpufunctbl]
;	movzx	ecx, word ptr[eax]
;	jmp	[ecx*4+edx]
;@op_6c01_0@4 ENDP


_align_func
;@op_6301_0@4 PROC NEAR					;Bcc OK
;	_start_func  'op_6301_0'
;	mov	ebx, DWORD PTR _regflags
;	add	eax, 2
;	and	ebx, 00FFFF00H
;	movsx	ecx, ch
;	test	ebx, ebx
;	je	SHORT $L74179
;	add	eax, ecx
;$L74179:
;	mov	DWORD PTR _regs+92, eax
;	mov	edx,[_cpufunctbl]
;	movzx	ecx, word ptr[eax]
;	jmp	[ecx*4+edx]
;@op_6301_0@4 ENDP
@op_6301_0@4 PROC NEAR					;Bcc OK
	_start_func  'op_6301_0'
	mov	ebx, DWORD PTR _regflags+1
	add	eax, 2
	movsx	ecx, ch
	test	bx, bx
	jne	SHORT $L74179
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
$L74179:
	add	eax, ecx
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_6301_0@4 ENDP
;@op_6301_0@4 PROC NEAR					;Bcc OK
;	_start_func  'op_6301_0'
;	mov	ebx, DWORD PTR _regflags+1
;	add	eax, 2
;	movsx	ecx, ch
;	test	bx, bx
;	je	SHORT $L74179
;	add	eax, ecx
;$L74179:
;	mov	DWORD PTR _regs+92, eax
;	mov	edx,[_cpufunctbl]
;	movzx	ecx, word ptr[eax]
;	jmp	[ecx*4+edx]
;@op_6301_0@4 ENDP


_align_func
@op_2000_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2000_0'
	mov	ebx, ecx
	xor	edx, edx
	shr	ebx, 8
	and	ecx, 14
	and	ebx, 7
	add	eax, 2
	mov	esi, DWORD PTR _regs[ebx*4]
	mov	DWORD PTR _regs+92, eax
	cmp	esi, edx
	mov	edi,[_cpufunctbl]
	mov	WORD PTR _regflags+2, dx
	mov	DWORD PTR _regs[ecx*2], esi
	setl	BYTE PTR _regflags
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_2000_0@4 ENDP


_align_func
@op_2048_0@4 PROC NEAR					;MOVEA OK
	_start_func  'op_2048_0'
	mov	ebx, ecx
	add	eax, 2
	shr	ebx, 8
	mov	DWORD PTR _regs+92, eax
	and	ebx, 7
	and	ecx, 14
	mov	edx, DWORD PTR _regs[ebx*4+32]
	mov	esi,[_cpufunctbl]
	mov	DWORD PTR _regs[ecx*2+32], edx
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+esi]
@op_2048_0@4 ENDP


_align_func
@op_2100_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2100_0'
	mov	ebx, ecx
	add	eax, 2
	and	ebx, 14
	shr	ecx, 8
	mov	edx, DWORD PTR _regs[ebx*2+32]
	and	ecx, 7
	sub	edx, 4
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	DWORD PTR _regs[ebx*2+32], edx
	xor	ebx, ebx
	mov	edi, DWORD PTR _MEMBaseDiff
	cmp	ecx, ebx
	mov	DWORD PTR _regs+92, eax
	setl	BYTE PTR _regflags
	bswap	ecx
	mov	WORD PTR _regflags+2, bx
	mov	DWORD PTR [edi+edx], ecx
	mov	esi,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+esi]
@op_2100_0@4 ENDP


_align_func
@op_c080_0@4 PROC NEAR					;AND OK
	_start_func  'op_c080_0'
	mov	ebx, ecx
	shr	ecx, 8
	and	ebx, 14
	and	ecx, 7
	xor	edx, edx
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	edi, DWORD PTR _regs[ebx*2]
	add	eax, 2
	and	ecx, edi
	mov	DWORD PTR _regs[ebx*2], ecx
	setl	BYTE PTR _regflags
	mov	DWORD PTR _regs+92, eax
	mov	esi,[_cpufunctbl]
	mov	WORD PTR _regflags+2, dx
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+esi]
@op_c080_0@4 ENDP


_align_func
@op_d080_0@4 PROC NEAR					;ADD OK
	_start_func  'op_d080_0'
	mov	esi, ecx
	shr	ecx, 8
	and	esi, 14
	and	ecx, 7
	add	eax, 2
	mov	ebx, DWORD PTR _regs[ecx*4]
	mov	edi, DWORD PTR _regs[esi*2]
	mov	DWORD PTR _regs+92, eax
	add	edi, ebx
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	setc	BYTE PTR _regflags+4
	mov	DWORD PTR _regs[esi*2], edi
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_d080_0@4 ENDP


_align_func
@op_6501_0@4 PROC NEAR					;Bcc OK
	_start_func  'op_6501_0'
	mov	dl, BYTE PTR _regflags+2
	add	eax, 2
	test	dl, dl
	movsx	ecx, ch
	je	SHORT $L74253
	add	eax, ecx
$L74253:
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_6501_0@4 ENDP


_align_func
@op_b080_0@4 PROC NEAR					;CMP OK
	_start_func  'op_b080_0'
	mov	edi, ecx
	;add	eax, 2
	lea	eax, DWORD PTR [eax+2]
	xor	ebx, ebx
	shr	edi, 8
	and	ecx, 14
	xor	edx, edx
	and	edi, 7
	mov	esi, DWORD PTR _regs[ecx*2]
	mov	DWORD PTR _regs+92, eax
	cmp	esi, DWORD PTR _regs[edi*4]
	movzx	ecx, word ptr[eax]
	mov	edi,[_cpufunctbl]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	jmp	[ecx*4+edi]
@op_b080_0@4 ENDP


_align_func
@op_c040_0@4 PROC NEAR					;AND OK
	_start_func  'op_c040_0'
	mov	esi,[_cpufunctbl]
	mov	ebx, ecx
	xor	edx, edx
	shr	ecx, 8
	and	ebx, 14
	and	ecx, 7
	add	eax, 2
	mov	di, WORD PTR _regs[ecx*4]
	mov	DWORD PTR _regs+92, eax
	and	di, WORD PTR _regs[ebx*2]
	mov	WORD PTR _regs[ebx*2], di
	setl	BYTE PTR _regflags
	mov	WORD PTR _regflags+2, dx
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+esi]
@op_c040_0@4 ENDP


_align_func
@op_5140_0@4 PROC NEAR					;SUB OK
	_start_func  'op_5140_0'
	mov	esi, ecx
	add	eax, 2
	shr	esi, 8
	and	ecx, 14
	and	esi, 7
	mov	edx, DWORD PTR _regs[esi*4]
	mov	DWORD PTR _regs+92, eax
	sub	dx, WORD PTR _imm8_table[ecx*2]
	mov	edi,[_cpufunctbl]
	mov	WORD PTR _regs[esi*4], dx
	movzx	ecx, word ptr[eax]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	setc	BYTE PTR _regflags+4
	jmp	[ecx*4+edi]
@op_5140_0@4 ENDP


_align_func
@op_2040_0@4 PROC NEAR					;MOVEA OK
	_start_func  'op_2040_0'
	mov	ebx, ecx
	add	eax, 2
	shr	ebx, 8
	mov	DWORD PTR _regs+92, eax
	and	ebx, 7
	mov	edx, DWORD PTR _regs[ebx*4]
	and	ecx, 14
	mov	DWORD PTR _regs[ecx*2+32], edx
	mov	edi,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edi]
@op_2040_0@4 ENDP


_align_func
@op_5040_0@4 PROC NEAR					;ADD OK
	_start_func  'op_5040_0'
	mov	esi, ecx
	add	eax, 2
	shr	esi, 8
	mov	DWORD PTR _regs+92, eax
	and	esi, 7
	and	ecx, 14
	mov	edi, DWORD PTR _regs[esi*4]
	mov	edx,[_cpufunctbl]
	add	di, WORD PTR _imm8_table[ecx*2]
	mov	WORD PTR _regs[esi*4], di		; will retire before used next time
	movzx	ecx, word ptr[eax]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	setc	BYTE PTR _regflags+4
	jmp	[ecx*4+edx]
@op_5040_0@4 ENDP


_align_func
@op_b040_0@4 PROC NEAR					;CMP OK
	_start_func  'op_b040_0'
	mov	ebx, ecx
	add	eax, 2
	shr	ebx, 8
	mov	DWORD PTR _regs+92, eax
	and	ebx, 7
	and	ecx, 14
	mov	esi, DWORD PTR _regs[ecx*2]
	mov	edi,[_cpufunctbl]
	cmp	si, WORD PTR _regs[ebx*4]
	movzx	ecx, word ptr[eax]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	jmp	[ecx*4+edi]
@op_b040_0@4 ENDP


_align_func
@op_3000_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_3000_0'
	mov	ebx, ecx
	add	eax, 2
	shr	ebx, 8
	mov	DWORD PTR _regs+92, eax
	and	ebx, 7
	xor	edx, edx
	mov	esi, DWORD PTR _regs[ebx*4]
	and	ecx, 14
	cmp	si, dx
	mov	WORD PTR _regs[ecx*2], si
	setl	BYTE PTR _regflags
	mov	edi,[_cpufunctbl]
	mov	WORD PTR _regflags+2, dx
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_3000_0@4 ENDP


_align_func
@op_2008_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2008_0'
	mov	ebx, ecx
	add	eax, 2
	shr	ebx, 8
	mov	DWORD PTR _regs+92, eax
	and	ebx, 7
	xor	edx, edx
	mov	ebx, DWORD PTR _regs[ebx*4+32]
	and	ecx, 14
	cmp	ebx, edx
	mov	DWORD PTR _regs[ecx*2], ebx
	setl	BYTE PTR _regflags
	mov	esi,[_cpufunctbl]
	mov	WORD PTR _regflags+2, dx
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+esi]
@op_2008_0@4 ENDP


;_align_func
ALIGN	16
@op_b148_0@4 PROC NEAR					;CMPM OK
	_start_func  'op_b148_0'
	mov	edi, ecx
	mov	ebx, DWORD PTR _MEMBaseDiff
	shr	edi, 8
	xor	edx, edx
	and	edi, 7
	mov	esi, DWORD PTR _regs[edi*4+32]
	and	ecx, 14
	movzx	edx, WORD PTR [esi+ebx]
	add	esi, 2
	bswap	edx
	mov	DWORD PTR _regs[edi*4+32], esi	; Must be before "ebp, _regs[ecx*2+32]"
	mov	ebp, DWORD PTR _regs[ecx*2+32]
	shr	edx, 16
	movzx	ebx, WORD PTR [ebx+ebp]
	add	eax, 2
	bswap	ebx
	mov	edi,[_cpufunctbl]
	add	ebp, 2
	shr	ebx, 16
	mov	DWORD PTR _regs[ecx*2+32], ebp
	mov	DWORD PTR _regs+92, eax
	cmp	bx, dx
	movzx	ecx, word ptr[eax]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	setc	BYTE PTR _regflags+4
	jmp	[ecx*4+edi]
@op_b148_0@4 ENDP


_align_func
@op_2050_0@4 PROC NEAR					;MOVEA OK
	_start_func  'op_2050_0'
	mov	ebx, ecx
	mov	edi, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ebx, 14
	and	ecx, 7
	add	eax, 2
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	DWORD PTR _regs+92, eax
	mov	edx, DWORD PTR [edx+edi]
	mov	esi,[_cpufunctbl]
	bswap	edx
	movzx	ecx, word ptr[eax]
	mov	DWORD PTR _regs[ebx*2+32], edx
	jmp	[ecx*4+esi]
@op_2050_0@4 ENDP


_align_func
@op_d0c0_0@4 PROC NEAR					;ADDA OK
	_start_func  'op_d0c0_0'
	mov	ebx, ecx
	mov	esi,[_cpufunctbl]
	shr	ecx, 8
	and	ebx, 14
	and	ecx, 7
	add	eax, 2
	movsx	ecx, WORD PTR _regs[ecx*4]
	mov	edx, DWORD PTR _regs[ebx*2+32]
	mov	DWORD PTR _regs+92, eax
	add	edx, ecx
	movzx	ecx, word ptr[eax]
	mov	DWORD PTR _regs[ebx*2+32], edx
	jmp	[ecx*4+esi]
@op_d0c0_0@4 ENDP


_align_func
@op_4e50_0@4 PROC NEAR					;LINK OK
	_start_func  'op_4e50_0'
	mov	ebx, DWORD PTR _regs+60		;A7
	shr	ecx, 8
	sub	ebx, 4
	
	;This may be needed by some tricky programs
	;mov	DWORD PTR _regs+60, ebx
	
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	bswap	edx
	mov	DWORD PTR [ebx+esi], edx				;must be first
	add	eax, 2
	mov	DWORD PTR _regs[ecx*4+32], ebx
	movzx	edx, WORD PTR [eax]
	bswap	edx
	mov	edi,[_cpufunctbl]
	shr	edx, 16
	lea	eax, DWORD PTR [eax+2]
	movsx	edx, dx
	mov	DWORD PTR _regs+92, eax
	add	ebx, edx
	movzx	ecx, word ptr[eax]
	mov	DWORD PTR _regs+60, ebx
	jmp	[ecx*4+edi]
@op_4e50_0@4 ENDP


_align_func
@op_4e58_0@4 PROC NEAR					;UNLK OK
	_start_func  'op_4e58_0'
	shr	ecx, 8
	mov	edi, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	add	eax, 2
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	DWORD PTR _regs+92, eax
	mov	ebx, DWORD PTR [edx+edi]
	mov	esi,[_cpufunctbl]
	bswap	ebx
	add	edx, 4
	mov	DWORD PTR _regs[ecx*4+32], ebx
	mov	DWORD PTR _regs+60, edx
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+esi]
@op_4e58_0@4 ENDP


_align_func
@op_2148_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2148_0'
	movzx	ebp, WORD PTR [eax+2]
	mov	esi, ecx
	xor	ebx, ebx
	shr	ecx, 8
	bswap	ebp
	and	ecx, 7
	mov	edi, DWORD PTR _regs[ecx*4+32]
	xor	edx, edx
	shr	ebp, 16
	cmp	edi, ebx
	mov	WORD PTR _regflags+2, bx
	setl	BYTE PTR _regflags
	movsx	ecx, bp
	sete	BYTE PTR _regflags+1
	and	esi, 14
	mov	ebx, DWORD PTR _MEMBaseDiff
	add	ecx, DWORD PTR _regs[esi*2+32]
	bswap	edi
	add	eax, 4
	mov	DWORD PTR [ebx+ecx], edi
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_2148_0@4 ENDP


;	uae_u32 dstreg = (opcode >> 8) & 7;
;	uae_u16 mask = get_iword(2);
;	uaecptr srca = m68k_areg(regs, dstreg) - 0;
;	uae_u16 amask = mask & 0xff, dmask = (mask >> 8) & 0xff;
;	while (amask) { srca -= 4; put_long(srca, m68k_areg(regs, movem_index2[amask])); amask = movem_next[amask]; }
;	while (dmask) { srca -= 4; put_long(srca, m68k_dreg(regs, movem_index2[dmask])); dmask = movem_next[dmask]; }
;	m68k_areg(regs, dstreg) = srca;
;	m68k_incpc(4);

_align_func
@op_48e0_0@4 PROC NEAR					;MVMLE OK
	_start_func  'op_48e0_0'
	shr	ecx, 8
	mov	eax, DWORD PTR [eax+2]			;mask
	and	ecx, 7
	movzx	esi, ah
	mov	edx, DWORD PTR _regs[ecx*4+32]
	movzx	eax, al
	test	si, si
	mov	edi, DWORD PTR _MEMBaseDiff
	je	SHORT $L107258
$L74461:
	movzx	ebx, BYTE PTR _movem_index2[esi*4]
	sub	edx, 4
	mov	ebx, DWORD PTR _regs[ebx*4+32]
	movzx	esi, BYTE PTR _movem_next[esi*4]
	bswap	ebx
	test	si, si
	mov	DWORD PTR [edi+edx], ebx
	jne	SHORT $L74461
$L107258:
	test	ax, ax
	je	SHORT $L74465
$L74464:
	movzx	ebx, BYTE PTR _movem_index2[eax*4]
	sub	edx, 4
	mov	ebx, DWORD PTR _regs[ebx*4]
	mov	al, BYTE PTR _movem_next[eax*4]
	bswap	ebx
	test	al, al
	mov	DWORD PTR [edi+edx], ebx
	jne	SHORT $L74464
$L74465:
	mov	eax, DWORD PTR _regs+92
	mov	DWORD PTR _regs[ecx*4+32], edx
	add	eax, 4
	mov	edx,[_cpufunctbl]
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_48e0_0@4 ENDP


_align_func
@op_b1c8_0@4 PROC NEAR					;CMPA	OK
	_start_func  'op_b1c8_0'
	mov	edi, ecx
	add	eax, 2
	shr	edi, 8
	and	ecx, 14
	and	edi, 7
	mov	esi, DWORD PTR _regs[ecx*2+32]
	mov	edx, DWORD PTR _regs[edi*4+32]
	mov	DWORD PTR _regs+92, eax
	cmp	esi, edx
	mov	edi,[_cpufunctbl]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	movzx	ecx, word ptr[eax]
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	jmp	[ecx*4+edi]
@op_b1c8_0@4 ENDP


;_align_func
ALIGN 16
@op_5080_0@4 PROC NEAR					;ADD OK
	_start_func  'op_5080_0'
	mov	esi, ecx
	add	eax, 2
	xor	edx, edx
	shr	esi, 8
	and	ecx, 14
	and	esi, 7
	mov	edi, DWORD PTR _imm8_table[ecx*2]
	xor	ebx, ebx
	mov	DWORD PTR _regs+92, eax
	add	edi, DWORD PTR _regs[esi*4]
	movzx	ecx, word ptr[eax]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	mov	DWORD PTR _regs[esi*4], edi
	setc	BYTE PTR _regflags+2
	mov	edi,[_cpufunctbl]
	seto	BYTE PTR _regflags+3
	setc	BYTE PTR _regflags+4
	jmp	[ecx*4+edi]
@op_5080_0@4 ENDP


_align_func
@op_2010_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2010_0'
	mov	edi, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	edi, 8
	add	eax, 2
	and	edi, 7
	and	ecx, 14
	mov	edi, DWORD PTR _regs[edi*4+32]
	xor	edx, edx
	mov	ebx, DWORD PTR [edi+esi]
	mov	DWORD PTR _regs+92, eax
	bswap	ebx
	mov	edi,[_cpufunctbl]
	cmp	ebx, edx
	mov	DWORD PTR _regs[ecx*2], ebx
	mov	WORD PTR _regflags+2, dx
	movzx	ecx, word ptr[eax]
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_2010_0@4 ENDP


_align_func
@op_41e8_0@4 PROC NEAR					;LEA OK
	_start_func  'op_41e8_0'
	movzx	edx, WORD PTR [eax+2]
	mov	esi, ecx
	bswap	edx
	shr	esi, 8
	shr	edx, 16
	and	esi, 7
	movsx	edx, dx
	and	ecx, 14
	add	edx, DWORD PTR _regs[esi*4+32]
	add	eax, 4
	mov	DWORD PTR _regs[ecx*2+32], edx
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	mov	DWORD PTR _regs+92, eax
	jmp	[ecx*4+edx]
@op_41e8_0@4 ENDP


_align_func
@op_5180_0@4 PROC NEAR					;SUB OK
	_start_func  'op_5180_0'
	mov	esi, ecx
	mov	edx,[_cpufunctbl]
	shr	esi, 8
	and	ecx, 14
	and	esi, 7
	add	eax, 2
	mov	edi, DWORD PTR _regs[esi*4]
	mov	DWORD PTR _regs+92, eax
	sub	edi, DWORD PTR _imm8_table[ecx*2]
	mov	DWORD PTR _regs[esi*4], edi
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	movzx	ecx, word ptr[eax]
	seto	BYTE PTR _regflags+3
	setc	BYTE PTR _regflags+4
	jmp	[ecx*4+edx]
@op_5180_0@4 ENDP


_align_func
@op_c40_0@4 PROC NEAR					;CMP OK
	_start_func  'op_c40_0'
	shr	ecx, 8
	movzx	edx, WORD PTR [eax+2]
	and	ecx, 7
	bswap	edx
	mov	esi, DWORD PTR _regs[ecx*4]
	shr	edx, 16
	add	eax, 4
	cmp	si, dx
	mov	DWORD PTR _regs+92, eax
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	mov	edi,[_cpufunctbl]
	setc	BYTE PTR _regflags+2
	movzx	ecx, word ptr[eax]
	seto	BYTE PTR _regflags+3
	jmp	[ecx*4+edi]
@op_c40_0@4 ENDP


_align_func
@op_6f01_0@4 PROC NEAR					;Bcc OK
	_start_func  'op_6f01_0'
	movsx	ecx, ch
	mov	edx, DWORD PTR _regflags
	add	eax, 2
	test	dh, dh
	jne	SHORT $L74570_e
	cmp	dl, BYTE PTR _regflags+3
	je	SHORT $L74570
$L74570_e:
	add	eax, ecx
$L74570:	
	mov	DWORD PTR _regs+92, eax
	mov	edi,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edi]
@op_6f01_0@4 ENDP


_align_func
@op_2030_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2030_0'
	add	eax, 2
	mov	esi, ecx
	mov	edx, DWORD PTR [eax]
	mov	ebx, esi
	add	eax, 2
	shr	ebx, 8
	mov	DWORD PTR _regs+92, eax
	and	ebx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ebx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	ebx, DWORD PTR [edi+eax]
	mov	edx,[_cpufunctbl]
	bswap	ebx
	mov	eax, DWORD PTR _regs+92
	and	esi, 14
	cmp	ebx, ecx
	mov	WORD PTR _regflags+2, cx
	mov	DWORD PTR _regs[esi*2], ebx
	movzx	ecx, word ptr[eax]
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edx]
@op_2030_0@4 ENDP


_align_func
@op_b050_0@4 PROC NEAR					;CMP OK
	_start_func  'op_b050_0'
	mov	edi, ecx
	xor	edx, edx
	shr	edi, 8
	and	ecx, 14
	and	edi, 7
	mov	ebx, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR _regs[edi*4+32]
	mov	esi, DWORD PTR _regs[ecx*2]
	movzx	ebx, WORD PTR [edi+ebx]
	add	eax, 2
	bswap	ebx
	mov	DWORD PTR _regs+92, eax
	shr	ebx, 16
	mov	edi,[_cpufunctbl]
	cmp	si, bx
	movzx	ecx, word ptr[eax]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	jmp	[ecx*4+edi]
@op_b050_0@4 ENDP


_align_func
@op_d040_0@4 PROC NEAR					;ADD OK
	_start_func  'op_d040_0'
	mov	esi, ecx
	add	eax, 2
	shr	ecx, 8
	and	esi, 14
	and	ecx, 7
	mov	edi, DWORD PTR _regs[esi*2]
	add	di, WORD PTR _regs[ecx*4]
	mov	DWORD PTR _regs+92, eax
	sets	BYTE PTR _regflags
	mov	WORD PTR _regs[esi*2], di
	sete	BYTE PTR _regflags+1
	movzx	ecx, word ptr[eax]
	setc	BYTE PTR _regflags+2
	mov	esi,[_cpufunctbl]
	seto	BYTE PTR _regflags+3
	setc	BYTE PTR _regflags+4
	jmp	[ecx*4+esi]
@op_d040_0@4 ENDP


_align_func
@op_30c0_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_30c0_0'
	mov	edi, ecx
	add	eax, 2
	and	edi, 14
	shr	ecx, 8
	mov	edx, DWORD PTR _regs[edi*2+32]
	and	ecx, 7
	lea	esi, DWORD PTR [edx+2]
	xor	ebx, ebx
	movzx	ecx, WORD PTR _regs[ecx*4]
	mov	DWORD PTR _regs[edi*2+32], esi
	cmp	cx, bx
	mov	esi, DWORD PTR _MEMBaseDiff
	bswap	ecx
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	shr	ecx, 16
	mov	DWORD PTR _regs+92, eax
	mov	WORD PTR [esi+edx], cx
	mov	edi,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	mov	WORD PTR _regflags+2, bx
	jmp	[ecx*4+edi]
@op_30c0_0@4 ENDP


_align_func
@op_b068_0@4 PROC NEAR					;CMP OK
	_start_func  'op_b068_0'
	mov	esi, ecx
	movzx	edx, WORD PTR [eax+2]
	shr	esi, 8
	bswap	edx
	and	esi, 7
	shr	edx, 16
	mov	esi, DWORD PTR _regs[esi*4+32]
	movsx	edx, dx
	mov	ebx, DWORD PTR _MEMBaseDiff
	add	esi, edx
	and	ecx, 14
	movzx	edx, WORD PTR [esi+ebx]
	add	eax, 4
	mov	esi, DWORD PTR _regs[ecx*2]
	bswap	edx
	mov	DWORD PTR _regs+92, eax
	shr	edx, 16
	mov	edi,[_cpufunctbl]
	cmp	si, dx
	movzx	ecx, word ptr[eax]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	jmp	[ecx*4+edi]
@op_b068_0@4 ENDP


;	uae_u32 dstreg = (opcode >> 8) & 7;
;	uae_u16 mask = get_iword(2);
;	unsigned int dmask = mask & 0xff, amask = (mask >> 8) & 0xff;
;	uaecptr srca = m68k_areg(regs, dstreg);
;	while (dmask) { m68k_dreg(regs, movem_index1[dmask]) = get_long(srca); srca += 4; dmask = movem_next[dmask]; }
;	while (amask) { m68k_areg(regs, movem_index1[amask]) = get_long(srca); srca += 4; amask = movem_next[amask]; }
;	m68k_areg(regs, dstreg) = srca;
;	m68k_incpc(4);

_align_func
@op_4cd8_0@4 PROC NEAR					;MVMEL OK
	_start_func  'op_4cd8_0'
	mov	ebp, eax
	shr	ecx, 8
	mov	eax, DWORD PTR [ebp+2]
	and	ecx, 7
	mov	edi, ecx
	movzx	ecx, al
	mov	edx, DWORD PTR _regs[edi*4+32]
	movzx	eax, ah
	xor ebx, ebx
	test	al, al
	mov	esi, DWORD PTR _MEMBaseDiff
	je	SHORT $L107415
	push	edi
$L74674:
	mov	edi, DWORD PTR [esi+edx]
	mov	bl, BYTE PTR _movem_index1[eax*4]
	bswap	edi
	mov	al, BYTE PTR _movem_next[eax*4]
	add	edx, 4
	test	al, al
	mov	DWORD PTR _regs[ebx*4], edi
	jne	SHORT $L74674
	pop	edi
$L107415:
	test	ecx, ecx
	je	SHORT $L74678
$L74677:
	mov	eax, DWORD PTR [esi+edx]
	mov	bl, BYTE PTR _movem_index1[ecx*4]
	bswap	eax
	mov	cl, BYTE PTR _movem_next[ecx*4]
	add	edx, 4
	test	cl, cl
	mov	DWORD PTR _regs[ebx*4+32], eax
	jne	SHORT $L74677
$L74678:
	lea	eax, DWORD PTR [ebp+4]
	mov	DWORD PTR _regs[edi*4+32], edx
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_4cd8_0@4 ENDP


_align_func
@op_b180_0@4 PROC NEAR					;EOR OK
	_start_func  'op_b180_0'
	mov	ebx, ecx
	xor	edx, edx
	shr	ebx, 8
	and	ecx, 14
	and	ebx, 7
	mov	ecx, DWORD PTR _regs[ecx*2]
	add	eax, 2
	xor	ecx, DWORD PTR _regs[ebx*4]
	mov	DWORD PTR _regs[ebx*4], ecx
	mov	WORD PTR _regflags+2, dx
	mov	DWORD PTR _regs+92, eax
	mov	edi,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_b180_0@4 ENDP


_align_func
@op_8080_0@4 PROC NEAR					;OR OK
	_start_func  'op_8080_0'
	mov	ebx, ecx
	xor	edx, edx
	shr	ecx, 8
	and	ebx, 14
	and	ecx, 7
	add	eax, 2
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	DWORD PTR _regs+92, eax
	or	ecx, DWORD PTR _regs[ebx*2]
	mov	edi,[_cpufunctbl]
	mov	WORD PTR _regflags+2, dx
	mov	DWORD PTR _regs[ebx*2], ecx
	setl	BYTE PTR _regflags
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_8080_0@4 ENDP


_align_func
@op_6a01_0@4 PROC NEAR					;Bcc OK
	_start_func  'op_6a01_0'
	mov	bl, BYTE PTR _regflags
	add	eax, 2
	test	bl, bl
	movsx	ecx, ch
	jne	SHORT $L74710
	add	eax, ecx
$L74710:
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_6a01_0@4 ENDP


_align_func
@op_9080_0@4 PROC NEAR					;SUB OK
	_start_func  'op_9080_0'
	mov	esi, ecx
	add	eax, 2
	and	esi, 14
	shr	ecx, 8
	mov	edi, DWORD PTR _regs[esi*2]
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	sub	edi, DWORD PTR _regs[ecx*4]
	mov	ebp,[_cpufunctbl]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	mov	DWORD PTR _regs[esi*2], edi
	setc	BYTE PTR _regflags+2
	movzx	ecx, word ptr[eax]
	seto	BYTE PTR _regflags+3
	setc	BYTE PTR _regflags+4
	jmp	[ecx*4+ebp]
@op_9080_0@4 ENDP


_align_func
@op_6201_0@4 PROC NEAR					;Bcc OK
	_start_func  'op_6201_0'
	add	eax, 2
	mov	ebx, DWORD PTR _regflags+1
	shr	ecx, 8
	test	bx, bx
	movsx	ecx, cl
	je	SHORT $L107505
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
$L107505:
	add	eax, ecx
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_6201_0@4 ENDP
;@op_6201_0@4 PROC NEAR					;Bcc OK
;	_start_func  'op_6201_0'
;	add	eax, 2
;	mov	ebx, DWORD PTR _regflags+1
;	shr	ecx, 8
;	test	bx, bx
;	movsx	ecx, cl
;	jne	SHORT $L107505
;	add	eax, ecx
;$L107505:
;	mov	DWORD PTR _regs+92, eax
;	mov	edx,[_cpufunctbl]
;	movzx	ecx, word ptr[eax]
;	jmp	[ecx*4+edx]
;@op_6201_0@4 ENDP


_align_func
@op_6b01_0@4 PROC NEAR					;Bcc OK
	_start_func  'op_6b01_0'
	mov	dl, BYTE PTR _regflags
	add	eax, 2
	test	dl, dl
	movsx	ecx, ch
	jne	SHORT $L74755
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
$L74755:
	add	eax, ecx
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_6b01_0@4 ENDP
;@op_6b01_0@4 PROC NEAR					;Bcc OK
;	_start_func  'op_6b01_0'
;	mov	dl, BYTE PTR _regflags
;	add	eax, 2
;	test	dl, dl
;	movsx	ecx, ch
;	je	SHORT $L74755
;	add	eax, ecx
;$L74755:
;	mov	DWORD PTR _regs+92, eax
;	mov	edx,[_cpufunctbl]
;	movzx	ecx, word ptr[eax]
;	jmp	[ecx*4+edx]
;@op_6b01_0@4 ENDP


_align_func
@op_1000_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_1000_0'
	mov	esi, ecx
	xor	edx, edx
	shr	ecx, 8
	and	esi, 14
	and	ecx, 7
	add	eax, 2
	mov	bl, BYTE PTR _regs[ecx*4]
	mov	DWORD PTR _regs+92, eax
	cmp	bl, dl
	mov	edi,[_cpufunctbl]
	mov	WORD PTR _regflags+2, dx
	movzx	ecx, word ptr[eax]
	setl	BYTE PTR _regflags
	mov	BYTE PTR _regs[esi*2], bl
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_1000_0@4 ENDP


_align_func
@op_b0a8_0@4 PROC NEAR					;CMP OK
	_start_func  'op_b0a8_0'
	movzx	edx, WORD PTR [eax+2]
	mov	ebx, ecx
	bswap	edx
	shr	ebx, 8
	shr	edx, 16
	and	ebx, 7
	movsx	edx, dx
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR _regs[ebx*4+32]
	add	edx, ebp
	and	ecx, 14
	mov	edx, DWORD PTR [edx+edi]
	mov	esi, DWORD PTR _regs[ecx*2]
	bswap	edx
	add	eax, 4
	cmp	esi, edx	
	mov	DWORD PTR _regs+92, eax
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	movzx	ecx, word ptr[eax]
	setc	BYTE PTR _regflags+2
	mov	esi,[_cpufunctbl]
	seto	BYTE PTR _regflags+3
	jmp	[ecx*4+esi]
@op_b0a8_0@4 ENDP


_align_func
@op_57c8_0@4 PROC NEAR					;DBcc OK
	_start_func  'op_57c8_0'
	shr	ecx, 8
	mov	bl, BYTE PTR _regflags+1
	and	ecx, 7
	movzx	edx, WORD PTR [eax+2]
	mov	esi, DWORD PTR _regs[ecx*4]
	test	bl, bl
	lea	eax, DWORD PTR [eax+4]
	jne	SHORT $L74807
	lea	edi, DWORD PTR [esi-1]
	test	si, si
	mov	WORD PTR _regs[ecx*4], di
	je	SHORT $L74807
	bswap	edx
	sub	eax, 2
	shr	edx, 16
	movsx	ecx, dx
	add	eax, ecx
$L74807:
	mov	DWORD PTR _regs+92, eax
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_57c8_0@4 ENDP


_align_func
@op_30d8_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_30d8_0'
	mov	ebx, ecx
	mov	ebp, DWORD PTR _MEMBaseDiff
	shr	ebx, 8
	and	ecx, 14
	and	ebx, 7
	mov	esi, ecx
	mov	edi, DWORD PTR _regs[ebx*4+32]
	add	eax, 2
	add	edi, 2
	mov	DWORD PTR _regs+92, eax
	mov	DWORD PTR _regs[ebx*4+32], edi
	movzx	ebx, WORD PTR [edi+ebp-2]
	mov	edi, DWORD PTR _regs[esi*2+32]
	bswap	ebx
	lea	ecx, DWORD PTR [edi+2]
	shr	ebx, 16
	xor	edx, edx
	mov	DWORD PTR _regs[esi*2+32], ecx
	cmp	bx, dx
	mov	esi,[_cpufunctbl]
	mov	WORD PTR _regflags+2, dx
	bswap	ebx
	sete	BYTE PTR _regflags+1
	setl	BYTE PTR _regflags
	shr	ebx, 16
	movzx	ecx, word ptr[eax]
	mov	WORD PTR [edi+ebp], bx
	jmp	[ecx*4+esi]
@op_30d8_0@4 ENDP


_align_func
@op_e088_0@4 PROC NEAR					;LSR OK
	_start_func  'op_e088_0'
	mov	edx, ecx
	add	eax, 2
	and	ecx, 14
	shr	edx, 8
	mov	ecx, DWORD PTR _imm8_table[ecx*2]
	and	edx, 7
	and	ecx, 63
	mov	esi, DWORD PTR _regs[edx*4]
	mov	DWORD PTR _regs+92, eax
	shr	esi, cl
	movzx	ecx, word ptr[eax]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	mov	DWORD PTR _regs[edx*4], esi
	setc	BYTE PTR _regflags+2
	setc	BYTE PTR _regflags+4
	xor	ebx, ebx
	mov	edx,[_cpufunctbl]
	mov	BYTE PTR _regflags+3, bl
	jmp	[ecx*4+edx]
@op_e088_0@4 ENDP


_align_func
@op_20f0_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_20f0_0'
	mov	esi, ecx
	mov	edx, DWORD PTR [eax+2]
	shr	ecx, 8
	add	eax, 4
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	esi, 14
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ebx, DWORD PTR [ecx+eax]
	mov	ecx, DWORD PTR _regs[esi*2+32]
	bswap	ebx
	lea	edx, DWORD PTR [ecx+4]
	mov	edi,[_cpufunctbl]
	mov	DWORD PTR _regs[esi*2+32], edx
	add	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	eax, DWORD PTR _regs+92
	cmp	ebx, edx
	bswap	ebx
	mov	WORD PTR _regflags+2, dx
	mov	DWORD PTR [ecx], ebx
	setl	BYTE PTR _regflags
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_20f0_0@4 ENDP


_align_func
@op_2078_0@4 PROC NEAR					;MOVEA OK
	_start_func  'op_2078_0'
	movzx	edx, WORD PTR [eax+2]
	mov	edi, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	bswap	edx
	add	eax, 4
	shr	edx, 16
	and	edi, 14
	movsx	edx, dx
	mov	DWORD PTR _regs+92, eax
	mov	ebx, DWORD PTR [edx+esi]
	mov	esi,[_cpufunctbl]
	bswap	ebx
	movzx	ecx, word ptr[eax]
	mov	DWORD PTR _regs[edi*2+32], ebx
	jmp	[ecx*4+esi]
@op_2078_0@4 ENDP


ALIGN 16
;_align_func
@op_6101_0@4 PROC NEAR					;BSR OK
	_start_func  'op_6101_0'
	mov	ebp, eax
	mov	edx, DWORD PTR _regs+88
	sub	eax, DWORD PTR _regs+96
	movsx	ecx, ch
	lea	esi, DWORD PTR [eax+edx+2]
	mov	edx, DWORD PTR _regs+60
	bswap	esi
	sub	edx, 4
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _regs+60, edx
	mov	DWORD PTR [eax+edx], esi
	lea	eax, DWORD PTR [ebp+ecx+2]
	mov	edx,[_cpufunctbl]
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_6101_0@4 ENDP


_align_func
@op_c090_0@4 PROC NEAR					;AND OK
	_start_func  'op_c090_0'
	mov	ebx, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ebx, 14
	and	ecx, 7
	mov	edi, DWORD PTR _regs[ebx*2]
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	add	eax, 2
	mov	esi, DWORD PTR [ecx+edx]
	mov	DWORD PTR _regs+92, eax
	bswap	esi
	xor	edx, edx
	and	esi, edi
	movzx	ecx, word ptr[eax]
	mov	WORD PTR _regflags+2, dx
	setl	BYTE PTR _regflags
	mov	DWORD PTR _regs[ebx*2], esi
	mov	edi,[_cpufunctbl]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_c090_0@4 ENDP


_align_func
@op_d1c8_0@4 PROC NEAR					;ADDA OK
	_start_func  'op_d1c8_0'
	mov	ebx, ecx
	add	eax, 2
	shr	ecx, 8
	and	ebx, 14
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ebx*2+32]
	mov	DWORD PTR _regs+92, eax
	add	edx, DWORD PTR _regs[ecx*4+32]
	mov	edi,[_cpufunctbl]
	mov	DWORD PTR _regs[ebx*2+32], edx
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edi]
@op_d1c8_0@4 ENDP


_align_func
@op_2170_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2170_0'
	mov	edx, DWORD PTR [eax+2]
	mov	esi, ecx
	add	eax, 4
	mov	ebx, ecx
	mov	DWORD PTR _regs+92, eax
	shr	ebx, 8
	mov	eax, edx
	and	ebx, 7
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ebx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ebp, DWORD PTR _regs+92
	mov	edi, DWORD PTR [ecx+eax]
	movzx	ecx, WORD PTR [ebp]
	xor	eax, eax
	bswap	ecx
	bswap	edi
	shr	ecx, 16
	cmp	edi, eax
	mov	WORD PTR _regflags+2, ax
	movsx	ecx, cx
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	and	esi, 14
	mov	ebx, DWORD PTR _MEMBaseDiff
	bswap	edi
	add	ecx, DWORD PTR _regs[esi*2+32]
	lea	eax, DWORD PTR [ebp+2]
	mov	DWORD PTR [ebx+ecx], edi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2170_0@4 ENDP


_align_func
@op_5148_0@4 PROC NEAR					;SUBA OK
	_start_func  'op_5148_0'
	mov	ebx, ecx
	mov	esi,[_cpufunctbl]
	shr	ebx, 8
	and	ecx, 14
	and	ebx, 7
	add	eax, 2
	mov	edx, DWORD PTR _regs[ebx*4+32]
	mov	DWORD PTR _regs+92, eax
	sub	edx, DWORD PTR _imm8_table[ecx*2]
	mov	DWORD PTR _regs[ebx*4+32], edx
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+esi]
@op_5148_0@4 ENDP


_align_func
@op_3010_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_3010_0'
	mov	ebx, ecx
	mov	edi,[_cpufunctbl]
	shr	ebx, 8
	mov	esi, DWORD PTR _MEMBaseDiff
	and	ebx, 7
	and	ecx, 14
	mov	ebx, DWORD PTR _regs[ebx*4+32]
	add	eax, 2
	movzx	ebx, WORD PTR [ebx+esi]
	xor	edx, edx
	bswap	ebx
	mov	DWORD PTR _regs+92, eax
	shr	ebx, 16
	mov	WORD PTR _regflags+2, dx
	cmp	bx, dx
	mov	WORD PTR _regs[ecx*2], bx
	movzx	ecx, word ptr[eax]
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_3010_0@4 ENDP


_align_func
@op_2140_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2140_0'
	mov	esi, ecx
	shr	ecx, 8
	and	esi, 14
	and	ecx, 7
	movzx	edx, WORD PTR [eax+2]
	mov	edi, DWORD PTR _regs[ecx*4]
	bswap	edx
	xor	ebx, ebx
	shr	edx, 16
	cmp	edi, ebx
	movsx	edx, dx
	mov	WORD PTR _regflags+2, bx
	setl	BYTE PTR _regflags
	mov	ecx, DWORD PTR _MEMBaseDiff
	sete	BYTE PTR _regflags+1
	add	edx, DWORD PTR _regs[esi*2+32]
	bswap	edi
	add	eax, 4
	mov	DWORD PTR [edx+ecx], edi
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	mov	DWORD PTR _regs+92, eax
	jmp	[ecx*4+edx]
@op_2140_0@4 ENDP


_align_func
@op_1028_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_1028_0'
	movzx	edx, WORD PTR [eax+2]
	mov	ebx, ecx
	bswap edx
	shr	ebx, 8
	shr	edx, 16
	and	ebx, 7
	movsx	edx, dx
	mov	esi, DWORD PTR _regs[ebx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	add	edx, esi
	add	eax, 4
	mov	bl, BYTE PTR [edx+edi]
	and	ecx, 14
	xor	edx, edx
	cmp	bl, dl
	mov	DWORD PTR _regs+92, eax
	mov	WORD PTR _regflags+2, dx
	mov	BYTE PTR _regs[ecx*2], bl
	setl	BYTE PTR _regflags
	movzx	ecx, word ptr[eax]
	mov	edi,[_cpufunctbl]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_1028_0@4 ENDP


;TODO: check this code
_align_func
@op_2128_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2128_0'
	movzx	edx, WORD PTR [eax+2]
	mov	esi, ecx
	bswap	edx
	shr	ecx, 8
	shr	edx, 16
	and	ecx, 7
	movsx edx, dx
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ebp, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	and	esi, 14
	mov	ecx, DWORD PTR [edx+ebp]
	mov	edi, DWORD PTR _regs[esi*2+32]
	xor	edx, edx
	sub	edi, 4
	cmp	ecx, edx
	mov	DWORD PTR _regs[esi*2+32], edi
	sete	dh
	add	eax, 4
	cmp	cl, dl		;no bswaps, cl=MSB w/ sign bit.
	mov	DWORD PTR [edi+ebp], ecx
	setl	dl
	mov	DWORD PTR _regs+92, eax
	mov	DWORD PTR _regflags, edx
	mov	eax, DWORD PTR _regs+92
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_2128_0@4 ENDP


_align_func
@op_440_0@4 PROC NEAR					;SUB OK
	_start_func  'op_440_0'
	mov	esi, ecx
	movzx	ebx, WORD PTR [eax+2]
	shr	esi, 8
	bswap	ebx
	and	esi, 7
	shr	ebx, 16
	lea	eax, DWORD PTR [eax+4]
	mov	edx, DWORD PTR _regs[esi*4]
	mov	DWORD PTR _regs+92, eax
	mov	edi,[_cpufunctbl]
	sub	dx, bx
	mov	WORD PTR _regs[esi*4], dx
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	movzx	ecx, word ptr[eax]
	seto	BYTE PTR _regflags+3
	setc	BYTE PTR _regflags+4
	jmp	[ecx*4+edi]
@op_440_0@4 ENDP


_align_func
@op_4a28_0@4 PROC NEAR					;TST OK
	_start_func  'op_4a28_0'
	movzx	edx, WORD PTR [eax+2]
	shr	ecx, 8
	bswap	edx
	and	ecx, 7
	shr	edx, 16
	mov	esi, DWORD PTR _regs[ecx*4+32]
	movsx	edx, dx
	mov	edi, DWORD PTR _MEMBaseDiff
	add	edx, esi
	xor	ecx, ecx	
	mov	dl, BYTE PTR [edx+edi]
	add	eax, 4
	cmp	dl, cl
	mov	DWORD PTR _regs+92, eax
	mov	WORD PTR _regflags+2, cx
	mov	edx,[_cpufunctbl]
	setl	BYTE PTR _regflags
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edx]
@op_4a28_0@4 ENDP


_align_func
@op_4868_0@4 PROC NEAR					;PEA OK
	_start_func  'op_4868_0'
	movzx	ebx, WORD PTR [eax+2]
	shr	ecx, 8
	bswap	ebx
	and	ecx, 7
	shr	ebx, 16
	mov	edx, DWORD PTR _regs[ecx*4+32]
	movsx	ebx, bx
	mov	ecx, DWORD PTR _regs+60
	add	ebx, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	lea	edi, DWORD PTR [ecx-4]
	add	eax, 4
	mov	DWORD PTR _regs+60, edi
	bswap	ebx
	add	edi, edx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	mov	DWORD PTR [edi], ebx
	jmp	[ecx*4+edx]
@op_4868_0@4 ENDP


_align_func
@op_e1a8_0@4 PROC NEAR					;LSL OK
	_start_func  'op_e1a8_0'
	mov	edx, ecx
	add	eax, 2
	mov	BYTE PTR _regflags+3, 0
	and	ecx, 14
	shr	edx, 8
	mov	ecx, DWORD PTR _regs[ecx*2]
	and	edx, 7
	and	ecx, 63
	mov	ebx, DWORD PTR _regs[edx*4]
	mov	DWORD PTR _regs+92, eax
	shl	ebx, cl
	mov	esi,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	setc	BYTE PTR _regflags+2
	setc	BYTE PTR _regflags+4
	mov	DWORD PTR _regs[edx*4], ebx
	jmp	[ecx*4+esi]
@op_e1a8_0@4 ENDP


_align_func
@op_e098_0@4 PROC NEAR					;ROR OK (FIXED)
	_start_func  'op_e098_0'
	mov	edx, ecx
	add	eax, 2
	shr	edx, 8
	and	ecx, 14
	and	edx, 7
	mov	ecx, DWORD PTR _imm8_table[ecx*2]
	mov	esi, DWORD PTR _regs[edx*4]
	mov	DWORD PTR _regs+92, eax
	ror	esi, cl
	mov	BYTE PTR _regflags+3, 0
	setc	BYTE PTR _regflags+2
	mov	DWORD PTR _regs[edx*4], esi
	test	esi, esi
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	mov	esi,[_cpufunctbl]
	setl	BYTE PTR _regflags
	jmp	[ecx*4+esi]
@op_e098_0@4 ENDP


_align_func
@op_4680_0@4 PROC NEAR					;NOT OK
	_start_func  'op_4680_0'
	shr	ecx, 8
	xor	edx, edx
	and	ecx, 7
	mov	BYTE PTR _regflags+2, dl
	mov	ebx, DWORD PTR _regs[ecx*4]
	mov	BYTE PTR _regflags+3, dl
	not	ebx
	add	eax, 2
	cmp	ebx, edx
	mov	DWORD PTR _regs[ecx*4], ebx
	sete	BYTE PTR _regflags+1
	mov	DWORD PTR _regs+92, eax
	mov	edi,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	setl	BYTE PTR _regflags
	jmp	[ecx*4+edi]
@op_4680_0@4 ENDP


_align_func
@op_2080_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_2080_0'
	mov	ebx, ecx
	xor	edx, edx
	shr	ebx, 8
	mov	edi,[_cpufunctbl]
	add	eax, 2
	and	ecx, 14
	and	ebx, 7
	mov	BYTE PTR _regflags+2, dl
	mov	ebx, DWORD PTR _regs[ebx*4]
	mov	BYTE PTR _regflags+3, dl
	cmp	ebx, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	bswap	ebx
	mov	ecx, DWORD PTR _regs[ecx*2+32]
	sete	BYTE PTR _regflags+1
	mov	DWORD PTR _regs+92, eax
	mov	DWORD PTR [ecx+edx], ebx
	movzx	ecx, word ptr[eax]
	setl	BYTE PTR _regflags
	jmp	[ecx*4+edi]
@op_2080_0@4 ENDP


_align_func
@op_4840_0@4 PROC NEAR					;SWAP OK
	_start_func  'op_4840_0'
	shr	ecx, 8
	xor	edx, edx
	and	ecx, 7
	add	eax, 2
	mov	esi, DWORD PTR _regs[ecx*4]
	mov	DWORD PTR _regs+92, eax
	mov	ebx, esi
	sar	ebx, 16
	shl	esi, 16
	and	ebx, 0000ffffH
	or	ebx, esi
	mov	edi,[_cpufunctbl]
	mov	WORD PTR _regflags+2, dx
	mov	DWORD PTR _regs[ecx*4], ebx
	movzx	ecx, word ptr[eax]
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_4840_0@4 ENDP


_align_func
@op_d1a8_0@4 PROC NEAR					;ADD OK
	_start_func  'op_d1a8_0'
	mov	esi, ecx
	movzx	ebx, WORD PTR [eax+2]
	and	esi, 14
	shr	ecx, 8
	bswap	ebx
	mov	edx, DWORD PTR _regs[esi*2]
	and	ecx, 7
	shr	ebx, 16
	mov	esi, DWORD PTR _regs[ecx*4+32]
	movsx	ebx, bx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	ebx, esi
	add	eax, 4
	lea	edi, DWORD PTR [ecx+ebx]
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR [edi]
	bswap	ecx
	add	ecx, edx
	sets	BYTE PTR _regflags
	bswap	ecx
	sete	BYTE PTR _regflags+1
	mov	DWORD PTR [edi], ecx
	setc	BYTE PTR _regflags+2
	movzx	ecx, word ptr[eax]
	seto	BYTE PTR _regflags+3
	mov	edx,[_cpufunctbl]
	setc	BYTE PTR _regflags+4
	jmp	[ecx*4+edx]
@op_d1a8_0@4 ENDP


_align_func
@op_b000_0@4 PROC NEAR					;CMP OK
	_start_func  'op_b000_0'
	mov	esi, ecx
	mov	edi,[_cpufunctbl]
	shr	esi, 8
	and	ecx, 14
	and	esi, 7
	mov	cl, BYTE PTR _regs[ecx*2]
	add	eax, 2
	cmp	cl, BYTE PTR _regs[esi*4]
	mov	DWORD PTR _regs+92, eax
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	movzx	ecx, word ptr[eax]
	setc	BYTE PTR _regflags+2
	seto	BYTE PTR _regflags+3
	jmp	[ecx*4+edi]
@op_b000_0@4 ENDP


_align_func
@op_4ed0_0@4 PROC NEAR					;JMP OK
	_start_func  'op_4ed0_0'
	shr	ecx, 8
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	edi,[_cpufunctbl]
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	add	eax, ecx
	mov	DWORD PTR _regs+88, ecx
	mov	DWORD PTR _regs+96, eax
	movzx	ecx, word ptr[eax]
	mov	DWORD PTR _regs+92, eax
	jmp	[ecx*4+edi]
@op_4ed0_0@4 ENDP


_align_func
@op_e9d0_0@4 PROC NEAR					;BFEXTU TODO
	_start_func  'op_e9d0_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	shr	ecx, 8
	mov	eax, edx
	and	ecx, 7
	movsx	edi, dx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 2048				; 00000800H
	test	ax, ax
	mov	eax, edi
	je	SHORT $L107873
	sar	eax, 6
	and	eax, 7
	mov	eax, DWORD PTR _regs[eax*4]
	jmp	SHORT $L107874
$L107873:
	sar	eax, 6
	and	eax, 31					; 0000001fH
$L107874:
	test	dl, 32					; 00000020H
	je	SHORT $L107875
	mov	edx, edi
	and	edx, 7
	mov	esi, DWORD PTR _regs[edx*4]
	jmp	SHORT $L107876
$L107875:
	mov	esi, edi
$L107876:
	dec	esi
	mov	edx, eax
	and	esi, 31					; 0000001fH
	and	edx, -2147483648			; 80000000H
	inc	esi
	mov	ebx, eax
	neg	edx
	sbb	edx, edx
	and	edx, -536870912				; e0000000H
	sar	ebx, 3
	or	edx, ebx
	add	ecx, edx
	mov	ebx, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR [ebx+ecx]
	bswap	edx
	and	eax, 7
	mov	ebp, eax
	xor	eax, eax
	mov	al, BYTE PTR [ebx+ecx+4]
	mov	ebx, ebp
	mov	cl, 8
	sub	cl, bl
	shr	eax, cl
	mov	ecx, ebx
	shl	edx, cl
	mov	ecx, 32					; 00000020H
	sub	ecx, esi
	or	eax, edx
	mov	edx, 1
	shr	eax, cl
	lea	ecx, DWORD PTR [esi-1]
	shl	edx, cl
	test	edx, eax
	setne	BYTE PTR _regflags
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	sete	BYTE PTR _regflags+1
	sar	edi, 12					; 0000000cH
	and	edi, 7
	mov	BYTE PTR _regflags+2, cl
	mov	DWORD PTR _regs[edi*4], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e9d0_0@4 ENDP


_align_func
@op_240_0@4 PROC NEAR					;AND imm OK
	_start_func  'op_240_0'
	movzx	ebx, WORD PTR [eax+2]
	shr	ecx, 8
	bswap	ebx
	and	ecx, 7
	shr	ebx, 16
	xor	edx, edx
	and	bx, WORD PTR _regs[ecx*4]
	add	eax, 4
	cmp	bx, dx
	mov	WORD PTR _regs[ecx*4], bx
	mov	WORD PTR _regflags+2, dx
	mov	DWORD PTR _regs+92, eax
	setl	BYTE PTR _regflags
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edx]
@op_240_0@4 ENDP


_align_func
@op_8a8_0@4 PROC NEAR					;BCLR OK
	_start_func  'op_8a8_0'
	movzx	ebp, WORD PTR [eax+4]
	shr	ecx, 8
	bswap	ebp
	and	ecx, 7
	shr	ebp, 16
	mov	bx, WORD PTR [eax+2]		;which bit
	movsx	ebp, bp
	movzx	edx, bh
	add	ebp, DWORD PTR _MEMBaseDiff
	and	edx, 7
	add	ebp, DWORD PTR _regs[ecx*4+32]
	add	eax, 6
	movzx	ecx, BYTE PTR [ebp]		;dst byte
	mov	DWORD PTR _regs+92, eax
	btr	ecx, edx	;well...
	mov	edx,[_cpufunctbl]

	;RCHECK ebp										;MAC_BOOT_FIX

	cmc
	mov	BYTE PTR [ebp], cl
	movzx	ecx, word ptr[eax]
	setc	BYTE PTR _regflags+1
	jmp	[ecx*4+edx]
@op_8a8_0@4 ENDP


_align_func
@op_d0c8_0@4 PROC NEAR					;ADDA OK
	_start_func  'op_d0c8_0'
	mov	ebx, ecx
	mov	edi,[_cpufunctbl]
	shr	ecx, 8
	and	ebx, 14
	and	ecx, 7
	add	eax, 2
	movsx	edx, WORD PTR _regs[ecx*4+32]
	mov	DWORD PTR _regs+92, eax
	add	edx, DWORD PTR _regs[ebx*2+32]
	movzx	ecx, word ptr[eax]
	mov	DWORD PTR _regs[ebx*2+32], edx
	jmp	[ecx*4+edi]
@op_d0c8_0@4 ENDP


_align_func
@op_48c0_0@4 PROC NEAR					;EXT OK
	_start_func  'op_48c0_0'
	shr	ecx, 8
	xor	edx, edx
	and	ecx, 7
	mov	edi,[_cpufunctbl]
	add	eax, 2
	movsx	ebx, WORD PTR _regs[ecx*4]
	mov	DWORD PTR _regs+92, eax
	cmp	ebx, edx
	mov	WORD PTR _regflags+2, dx
	mov	DWORD PTR _regs[ecx*4], ebx
	setl	BYTE PTR _regflags
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_48c0_0@4 ENDP


_align_func
@op_e048_0@4 PROC NEAR					;LSR OK
	_start_func  'op_e048_0'
	mov	edx, ecx
	mov	BYTE PTR _regflags+3, 0
	and	ecx, 14
	shr	edx, 8
	mov	ecx, DWORD PTR _imm8_table[ecx*2]
	and	edx, 7
	and	ecx, 63
	movzx	ebx, WORD PTR _regs[edx*4]
	add	eax, 2
	shr	ebx, cl
	mov	DWORD PTR _regs+92, eax
	sets	BYTE PTR _regflags
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	mov	edi,[_cpufunctbl]
	setc	BYTE PTR _regflags+2
	mov	WORD PTR _regs[edx*4], bx
	setc	BYTE PTR _regflags+4
	jmp	[ecx*4+edi]
@op_e048_0@4 ENDP


_align_func
@op_10d8_0@4 PROC NEAR					;MOVE TODO
	_start_func  'op_10d8_0'
	mov	eax, ecx
	shr	eax, 8
	mov	ebx, DWORD PTR _MEMBaseDiff
	and	eax, 7
	mov	edi, DWORD PTR _regs[eax*4+32]
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	dl, BYTE PTR [edi+ebx]
	add	eax, edi
	and	ecx, 14
	mov	DWORD PTR [esi], eax
	mov	esi, DWORD PTR _regs[ecx*2+32]
	lea	eax, DWORD PTR _regs[ecx*2+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*2]
	add	ecx, esi
	mov	DWORD PTR [eax], ecx
	xor	eax, eax
	cmp	dl, al
	mov	WORD PTR _regflags+2, ax
	sete	BYTE PTR _regflags+1
	setl	BYTE PTR _regflags
	mov	BYTE PTR [ebx+esi], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10d8_0@4 ENDP


_align_func
_x$107958 = -12
_dsta$75228 = -24
_bf1$75233 = -20
@op_efd0_0@4 PROC NEAR					;BFINS TODO
	_start_func  'op_efd0_0'
	mov	ebp, esp
	sub	esp, 24					; 00000018H
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	push	ebx
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	push	esi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	edx, 2048				; 00000800H
	push	edi
	test	dx, dx
	movsx	edi, ax
	je	SHORT $L107945
	mov	edx, edi
	sar	edx, 6
	and	edx, 7
	mov	esi, DWORD PTR _regs[edx*4]
	jmp	SHORT $L107946
$L107945:
	mov	esi, edi
	sar	esi, 6
	and	esi, 31					; 0000001fH
$L107946:
	test	al, 32					; 00000020H
	mov	eax, edi
	je	SHORT $L107948
	and	eax, 7
	mov	eax, DWORD PTR _regs[eax*4]
$L107948:
	dec	eax
	mov	edx, esi
	and	eax, 31					; 0000001fH
	and	edx, -2147483648			; 80000000H
	inc	eax
	mov	ebx, esi
	neg	edx
	sbb	edx, edx
	and	edx, -536870912				; e0000000H
	sar	ebx, 3
	or	edx, ebx
	add	ecx, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _dsta$75228[ebp], ecx
	mov	edx, DWORD PTR [edx+ecx]
	bswap	edx
	mov	DWORD PTR _x$107958[ebp], edx
	mov	ebx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	add	ecx, ebx
	xor	ebx, ebx
	mov	DWORD PTR -16+[ebp], ecx
	mov	bl, BYTE PTR [ecx+4]
	mov	ecx, 8
	sub	ecx, esi
	mov	DWORD PTR _bf1$75233[ebp], ebx
	mov	DWORD PTR -4+[ebp], ecx
	mov	ecx, 32					; 00000020H
	sub	ecx, eax
	mov	DWORD PTR -8+[ebp], ecx
	mov	ecx, esi
	shl	edx, cl
	mov	ecx, DWORD PTR -4+[ebp]
	shr	ebx, cl
	mov	ecx, DWORD PTR -8+[ebp]
	or	edx, ebx
	mov	ebx, 1
	shr	edx, cl
	lea	ecx, DWORD PTR [eax-1]
	shl	ebx, cl
	test	ebx, edx
	setne	cl
	xor	ebx, ebx
	mov	BYTE PTR _regflags, cl
	cmp	edx, ebx
	mov	ecx, DWORD PTR -8+[ebp]
	sete	dl
	sar	edi, 12					; 0000000cH
	and	edi, 7
	mov	BYTE PTR _regflags+1, dl
	add	eax, esi
	mov	BYTE PTR _regflags+3, bl
	mov	edx, DWORD PTR _regs[edi*4]
	mov	BYTE PTR _regflags+2, bl
	shl	edx, cl
	cmp	eax, 32					; 00000020H
	jl	SHORT $L107949
	xor	edi, edi
	jmp	SHORT $L107950
$L107949:
	or	edi, -1
	mov	ecx, eax
	shr	edi, cl
	and	edi, DWORD PTR _x$107958[ebp]
$L107950:
	mov	ecx, DWORD PTR -4+[ebp]
	mov	ebx, -16777216				; ff000000H
	shl	ebx, cl
	mov	ecx, DWORD PTR _x$107958[ebp]
	and	ebx, ecx
	mov	ecx, esi
	mov	DWORD PTR -12+[ebp], ebx
	mov	ebx, edx
	mov	esi, DWORD PTR -16+[ebp]
	shr	ebx, cl
	mov	ecx, DWORD PTR -12+[ebp]
	or	ecx, ebx
	or	ecx, edi
	cmp	eax, 32					; 00000020H
	bswap	ecx
	mov	DWORD PTR [esi], ecx
	jle	SHORT $L107973
	mov	bl, BYTE PTR _bf1$75233[ebp]
	lea	ecx, DWORD PTR [eax-32]
	mov	eax, 255				; 000000ffH
	sar	eax, cl
	mov	ecx, DWORD PTR -4+[ebp]
	shl	dl, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	al, bl
	or	al, dl
	mov	edx, DWORD PTR _dsta$75228[ebp]
	mov	BYTE PTR [ecx+edx+4], al
$L107973:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_efd0_0@4 ENDP


_align_func
@op_b058_0@4 PROC NEAR					;CMP TODO
	_start_func  'op_b058_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	esi, ecx
	shr	esi, 8
	and	esi, 7
	xor	edx, edx
	shr	ecx, 1
	mov	edi, DWORD PTR _regs[esi*4+32]
	and	ecx, 7
	mov	ax, WORD PTR [edi+eax]
	add	edi, 2
	mov	dl, ah
	mov	DWORD PTR _regs[esi*4+32], edi
	mov	si, WORD PTR _regs[ecx*4]
	mov	dh, al
	movsx	eax, si
	movsx	ecx, dx
	sub	eax, ecx
	xor	ecx, ecx
	test	si, si
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dx, dx
	setl	al
	cmp	eax, edi
	je	SHORT $L107976
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L107977
$L107976:
	mov	BYTE PTR _regflags+3, 0
$L107977:
	cmp	dx, si
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b058_0@4 ENDP


_align_func
@op_b090_0@4 PROC NEAR					;CMP TODO
	_start_func  'op_b090_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	shr	ecx, 1
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4]
	xor	ecx, ecx
	mov	eax, esi
	sub	eax, edx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L107986
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L107987
$L107986:
	mov	BYTE PTR _regflags+3, 0
$L107987:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b090_0@4 ENDP


_align_func
@op_4a00_0@4 PROC NEAR					;TST TODO
	_start_func  'op_4a00_0'
	shr	ecx, 8
	and	ecx, 7
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	cl, BYTE PTR _regs[ecx*4]
	cmp	cl, al
	sete	dl
	cmp	cl, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a00_0@4 ENDP


_align_func
@op_4a40_0@4 PROC NEAR					;TST OK
	_start_func  'op_4a40_0'
	shr	ecx, 8
	add	eax, 2
	and	ecx, 7
	xor	ebx, ebx
	mov	cx, WORD PTR _regs[ecx*4]
	mov	edi,[_cpufunctbl]
	cmp	cx, bx
	mov	WORD PTR _regflags+2, bx
	movzx	ecx, word ptr[eax]
	setl	BYTE PTR _regflags
	mov	DWORD PTR _regs+92, eax
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+edi]
@op_4a40_0@4 ENDP


_align_func
@op_50a8_0@4 PROC NEAR					;ADD OK
	_start_func  'op_50a8_0'
	movzx	esi, WORD PTR [eax+2]
	mov	ebx, ecx
	bswap	esi
	shr	ecx, 8
	shr	esi, 16
	and	ebx, 14
	movsx	esi, si
	mov	edi, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	add	eax, 4
	add	esi, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _imm8_table[ebx*2]
	mov	ebp, DWORD PTR [edi+esi]
	mov	DWORD PTR _regs+92, eax
	bswap	ebp
	movzx	ecx, word ptr[eax]
	add	ebp, edx
	mov	ebx,[_cpufunctbl]
	sets	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	bswap	ebp
	setc	BYTE PTR _regflags+2
	mov	DWORD PTR [esi+edi], ebp
	seto	BYTE PTR _regflags+3
	setc	BYTE PTR _regflags+4
	jmp	[ecx*4+ebx]
@op_50a8_0@4 ENDP


;TODO: optimize
_align_func
@op_8c0_0@4 PROC NEAR					;BSET TODO
	_start_func  'op_8c0_0'
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	mov	eax, ecx
	mov	ecx, DWORD PTR _regs+92
	mov	cx, WORD PTR [ecx+2]
	mov	esi, DWORD PTR _regs[eax*4]
	mov	dl, ch
	and	edx, 31					; 0000001fH
	mov	ecx, edx
	mov	edx, esi
	movsx	edi, cx
	mov	ecx, edi
	sar	edx, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	edx, 1
	shl	edx, cl
	or	edx, esi
	mov	DWORD PTR _regs[eax*4], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8c0_0@4 ENDP


_align_func
@op_41f0_0@4 PROC NEAR					;LEA TODO
	_start_func  'op_41f0_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	shr	esi, 1
	and	esi, 7
	mov	DWORD PTR _regs[esi*4+32], eax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41f0_0@4 ENDP


_align_func
@op_4ea8_0@4 PROC NEAR					;JSR OK
	_start_func  'op_4ea8_0'
	mov	esi, ecx
	movzx	edx, WORD PTR [eax+2]
	shr	esi, 8
	bswap	edx
	and	esi, 7
	shr	edx, 16
	mov	ecx, DWORD PTR _regs[esi*4+32]
	movsx	edx, dx
	mov	ebp, DWORD PTR _regs+96
	add	edx, ecx
	mov	edi, DWORD PTR _regs+60
	mov	ecx, DWORD PTR _regs+88
	sub	edi, 4
	sub	ecx, ebp
	mov	esi, DWORD PTR _MEMBaseDiff
	lea	ebp, DWORD PTR [ecx+eax+4]
	mov	DWORD PTR _regs+60, edi
	bswap	ebp	
	mov	DWORD PTR _regs+88, edx
	mov	DWORD PTR [esi+edi], ebp
	lea	eax, DWORD PTR [esi+edx]
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	mov	DWORD PTR _regs+96, eax
	mov	DWORD PTR _regs+92, eax
	jmp	[ecx*4+edx]
@op_4ea8_0@4 ENDP


_align_func
@op_1018_0@4 PROC NEAR					;MOVE TODO
	_start_func  'op_1018_0'
	mov	eax, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	mov	edi, DWORD PTR _regs[eax*4+32]
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	dl, BYTE PTR [edi+edx]
	add	eax, edi
	mov	DWORD PTR [esi], eax
	xor	al, al
	cmp	dl, al
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	dl, al
	mov	BYTE PTR _regflags+3, al
	setl	al
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regs[ecx*4], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1018_0@4 ENDP


_align_func
@op_828_0@4 PROC NEAR					;BTST TODO
	_start_func  'op_828_0'
	mov	esi, eax
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+4]
	mov	dx, WORD PTR [esi+2]
	mov	bl, ah
	add	esi, 6
	movsx	edi, bx
	xor	ebx, ebx
	mov	bh, al
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edi, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	mov	cl, dh
	mov	edx, DWORD PTR _MEMBaseDiff
	add	edi, eax
	and	cl, 7
	mov	al, BYTE PTR [edi+edx]
	mov	DWORD PTR _regs+92, esi
	shr	al, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_828_0@4 ENDP


_align_func
@op_4a80_0@4 PROC NEAR					;TST TODO
	_start_func  'op_4a80_0'
	shr	ecx, 8
	and	ecx, 7
	xor	eax, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	ecx, DWORD PTR _regs[ecx*4]
	cmp	ecx, eax
	sete	dl
	cmp	ecx, eax
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a80_0@4 ENDP


_flgs$75383 = -4
_align_func
@op_9180_0@4 PROC NEAR					;SUBX TODO
	_start_func  'op_9180_0'
	mov	al, BYTE PTR _regflags+4
	push	esi
	mov	esi, ecx
	shr	esi, 1
	and	esi, 7
	push	edi
	shr	ecx, 8
	mov	edi, DWORD PTR _regs[esi*4]
	and	ecx, 7
	xor	edx, edx
	mov	ecx, DWORD PTR _regs[ecx*4]
	test	al, al
	setne	dl
	mov	eax, edi
	sub	eax, edx
	xor	edx, edx
	sub	eax, ecx
	test	ecx, ecx
	setl	dl
	mov	DWORD PTR _flgs$75383[esp+20], edx
	xor	edx, edx
	test	edi, edi
	setl	dl
	xor	ecx, ecx
	mov	DWORD PTR _regs[esi*4], eax
	test	eax, eax
	setl	cl
	mov	bl, cl
	pop	edi
	xor	bl, dl
	pop	esi
	mov	BYTE PTR -5+[esp+12], bl
	mov	bl, BYTE PTR _flgs$75383[esp+12]
	xor	dl, bl
	mov	bl, BYTE PTR -5+[esp+12]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _flgs$75383[esp+12]
	xor	cl, dl
	and	cl, bl
	xor	cl, dl
	mov	dl, BYTE PTR _regflags+1
	test	eax, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	sete	cl
	and	dl, cl
	test	eax, eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9180_0@4 ENDP


_align_func
@op_3020_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_3020_0'
	mov	esi, ecx
	mov	ebp, DWORD PTR _MEMBaseDiff
	shr	esi, 8
	xor	edx, edx
	and	esi, 7
	add	eax, 2
	mov	edi, DWORD PTR _regs[esi*4+32]
	mov	DWORD PTR _regs+92, eax
	sub	edi, 2
	and	ecx, 14
	movzx	ebx, WORD PTR [ebp+edi]
	mov	DWORD PTR _regs[esi*4+32], edi
	bswap	ebx
	mov	esi,[_cpufunctbl]
	shr	ebx, 16
	mov	WORD PTR _regflags+2, dx
	cmp	bx, dx
	mov	WORD PTR _regs[ecx*2], bx
	movzx	ecx, word ptr[eax]
	setl	BYTE PTR _regflags
	sete	BYTE PTR _regflags+1
	jmp	[ecx*4+esi]
@op_3020_0@4 ENDP


_align_func
@op_30e0_0@4 PROC NEAR					;MOVE OK
	_start_func  'op_30e0_0'
	mov	ebx, ecx
	and	ecx, 14
	shr	ebx, 8
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	ebx, 7
	mov	edi, ecx
	mov	esi, DWORD PTR _regs[ebx*4+32]
	xor	edx, edx
	sub	esi, 2
	add	eax, 2
	movzx	edx, WORD PTR [esi+ebp]
	mov	DWORD PTR _regs[ebx*4+32], esi
	bswap	edx
	mov	ebx, DWORD PTR _regs[edi*2+32]
	shr	edx, 16
	xor	ecx, ecx
	lea	esi, DWORD PTR [ebx+2]
	cmp	dx, cx
	mov	DWORD PTR _regs[edi*2+32], esi
	mov	WORD PTR _regflags+2, cx
	bswap	edx
	sete	BYTE PTR _regflags+1
	mov	edi,[_cpufunctbl]
	mov	DWORD PTR _regs+92, eax
	setl	BYTE PTR _regflags
	shr	edx, 16
	movzx	ecx, word ptr[eax]
	mov	WORD PTR [ebx+ebp], dx
	jmp	[ecx*4+edi]
@op_30e0_0@4 ENDP


_align_func
@op_5088_0@4 PROC NEAR					;ADDA TODO
	_start_func  'op_5088_0'
	mov	eax, ecx
	shr	eax, 8
	shr	ecx, 1
	and	eax, 7
	and	ecx, 7
	mov	ecx, DWORD PTR _imm8_table[ecx*4]
	mov	edx, DWORD PTR _regs[eax*4+32]
	add	edx, ecx
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5088_0@4 ENDP


_align_func
@op_2138_0@4 PROC NEAR					;MOVE TODO
	_start_func  'op_2138_0'
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	ecx, ecx
	cmp	edx, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	edx, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2138_0@4 ENDP


_align_func
@op_5188_0@4 PROC NEAR					;SUBA TODO
	_start_func  'op_5188_0'
	mov	eax, ecx
	shr	eax, 8
	shr	ecx, 1
	and	eax, 7
	and	ecx, 7
	mov	ecx, DWORD PTR _imm8_table[ecx*4]
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, ecx
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5188_0@4 ENDP


_align_func
@op_d180_0@4 PROC NEAR					;ADDX TODO
	_start_func  'op_d180_0'
	mov	dl, BYTE PTR _regflags+4
	mov	esi, ecx
	shr	esi, 1
	shr	ecx, 8
	and	esi, 7
	and	ecx, 7
	xor	eax, eax
	mov	ebx, DWORD PTR _regs[esi*4]
	mov	ecx, DWORD PTR _regs[ecx*4]
	test	dl, dl
	setne	al
	add	eax, ebx
	xor	edx, edx
	add	eax, ecx
	test	ecx, ecx
	mov	edi, eax
	setl	dl
	xor	eax, eax
	mov	DWORD PTR _regs[esi*4], edi
	test	ebx, ebx
	setl	al
	xor	ecx, ecx
	mov	bl, al
	test	edi, edi
	setl	cl
	xor	bl, cl
	xor	al, dl
	xor	cl, dl
	and	al, bl
	and	cl, bl
	xor	al, dl
	mov	dl, BYTE PTR _regflags+1
	mov	BYTE PTR _regflags+3, cl
	test	edi, edi
	sete	cl
	and	dl, cl
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _regs+92
	test	edi, edi
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d180_0@4 ENDP


_align_func
@op_4ce8_0@4 PROC NEAR					;MVMEL TODO
	_start_func  'op_4ce8_0'
	mov	edi, ecx
	mov	ecx, DWORD PTR _regs+92
	xor	ebx, ebx
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	bl, ch
	mov	dl, ah
	movsx	esi, bx
	xor	ebx, ebx
	mov	dh, al
	mov	bh, cl
	and	edx, 65535				; 0000ffffH
	shr	edi, 8
	movsx	ecx, bx
	and	edi, 7
	mov	eax, edx
	or	esi, ecx
	and	eax, 255				; 000000ffH
	mov	ebx, DWORD PTR _regs[edi*4+32]
	shr	edx, 8
	add	esi, ebx
	test	eax, eax
	je	SHORT $L108174
$L75478:
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+esi]
	bswap	ecx
	mov	edi, DWORD PTR _movem_index1[eax*4]
	mov	eax, DWORD PTR _movem_next[eax*4]
	add	esi, 4
	test	eax, eax
	mov	DWORD PTR _regs[edi*4], ecx
	jne	SHORT $L75478
$L108174:
	test	edx, edx
	je	SHORT $L108177
$L75481:
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [eax+esi]
	bswap	eax
	mov	ecx, DWORD PTR _movem_index1[edx*4]
	mov	edx, DWORD PTR _movem_next[edx*4]
	add	esi, 4
	test	edx, edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	jne	SHORT $L75481
$L108177:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ce8_0@4 ENDP


_align_func
@op_21c8_0@4 PROC NEAR					;MOVE TODO
	_start_func  'op_21c8_0'
	push	esi
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	cx, WORD PTR [eax+2]
	xor	eax, eax
	cmp	esi, eax
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21c8_0@4 ENDP


_align_func
@op_3140_0@4 PROC NEAR					;MOVE TODO
	_start_func  'op_3140_0'
	mov	esi, ecx
	xor	edx, edx
	mov	eax, esi
	mov	ecx, DWORD PTR _regs+92
	shr	eax, 8
	and	eax, 7
	mov	cx, WORD PTR [ecx+2]
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	ax, WORD PTR _regs[eax*4]
	cmp	ax, dx
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	xor	ebx, ebx
	mov	dh, al
	xor	eax, eax
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3140_0@4 ENDP


_align_func
@op_91c8_0@4 PROC NEAR					;SUBA TODO
	_start_func  'op_91c8_0'
	mov	eax, ecx
	shr	eax, 1
	shr	ecx, 8
	and	eax, 7
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, ecx
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_91c8_0@4 ENDP


_align_func
@op_4a68_0@4 PROC NEAR					;TST TODO
	_start_func  'op_4a68_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	mov	ax, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ah
	xor	ecx, ecx
	mov	dh, al
	mov	BYTE PTR _regflags+2, cl
	mov	eax, edx
	mov	BYTE PTR _regflags+3, cl
	cmp	ax, cx
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	al
	add	esi, 4
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs+92, esi
	mov	eax,esi
	movzx	ecx, word ptr[esi]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a68_0@4 ENDP


_align_func
@op_e188_0@4 PROC NEAR					;LSL TODO
	_start_func  'op_e188_0'
	mov	edx, ecx
	mov	BYTE PTR _regflags+3, 0
	shr	ecx, 1
	and	ecx, 7
	shr	edx, 8
	mov	ecx, DWORD PTR _imm8_table[ecx*4]
	and	edx, 7
	and	ecx, 63					; 0000003fH
	mov	eax, DWORD PTR _regs[edx*4]
	cmp	ecx, 32					; 00000020H
	jb	SHORT $L75545
	jne	SHORT $L108221
	and	al, 1
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L75546
$L108221:
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L75546
$L75545:
	dec	ecx
	shl	eax, cl
	mov	ecx, eax
	shr	ecx, 31					; 0000001fH
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shl	eax, 1
$L75546:
	test	eax, eax
	sete	cl
	test	eax, eax
	mov	DWORD PTR _regs[edx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e188_0@4 ENDP


_align_func
@op_e0a8_0@4 PROC NEAR					;LSR TODO
	_start_func  'op_e0a8_0'
	mov	edx, ecx
	mov	BYTE PTR _regflags+2, 0
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+3, 0
	shr	edx, 8
	mov	ecx, DWORD PTR _regs[ecx*4]
	and	edx, 7
	and	ecx, 63					; 0000003fH
	mov	eax, DWORD PTR _regs[edx*4]
	cmp	ecx, 32					; 00000020H
	jl	SHORT $L75560
	shr	eax, 31					; 0000001fH
	cmp	ecx, 32					; 00000020H
	sete	cl
	and	al, cl
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L75562
$L75560:
	test	ecx, ecx
	jle	SHORT $L75562
	dec	ecx
	shr	eax, cl
	mov	cl, al
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shr	eax, 1
$L75562:
	test	eax, eax
	sete	cl
	test	eax, eax
	mov	DWORD PTR _regs[edx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e0a8_0@4 ENDP


_flgn$75579 = -4
_align_func
@op_9040_0@4 PROC NEAR					;SUB TODO
	_start_func  'op_9040_0'
	mov	esi, ecx
	shr	esi, 1
	shr	ecx, 8
	and	esi, 7
	and	ecx, 7
	mov	bp, WORD PTR _regs[ecx*4]
	mov	ax, WORD PTR _regs[esi*4]
	movsx	edi, ax
	movsx	ecx, bp
	sub	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	xor	edx, edx
	mov	WORD PTR _regs[esi*4], di
	test	di, di
	setl	dl
	test	di, di
	sete	bl
	test	bp, bp
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$75579[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$75579[esp+20]
	and	bl, dl
	cmp	bp, ax
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _regs+92
	test	ecx, ecx
	setne	dl
	add	eax, 2
	mov	BYTE PTR _regflags+3, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9040_0@4 ENDP


_align_func
@op_1030_0@4 PROC NEAR					;MOVE TODO
	_start_func  'op_1030_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [ecx+eax]
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	shr	esi, 1
	and	esi, 7
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1030_0@4 ENDP


_align_func
@op_10c0_0@4 PROC NEAR					;MOVE TODO
	_start_func  'op_10c0_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	shr	ecx, 8
	mov	esi, DWORD PTR _regs[eax*4+32]
	lea	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	and	ecx, 7
	add	eax, esi
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	DWORD PTR [edx], eax
	xor	al, al
	cmp	cl, al
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	cl, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR [edx+esi], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10c0_0@4 ENDP


_align_func
@op_e080_0@4 PROC NEAR					;ASR TODO
	_start_func  'op_e080_0'
	mov	edi, ecx
	shr	edi, 8
	shr	ecx, 1
	and	edi, 7
	and	ecx, 7
	mov	BYTE PTR _regflags+3, 0
	mov	ebx, DWORD PTR _regs[edi*4]
	mov	esi, DWORD PTR _imm8_table[ecx*4]
	mov	edx, ebx
	and	esi, 63					; 0000003fH
	shr	edx, 31					; 0000001fH
	cmp	esi, 32					; 00000020H
	jb	SHORT $L75624
	mov	eax, edx
	mov	BYTE PTR _regflags+2, dl
	neg	eax
	mov	BYTE PTR _regflags+4, dl
	jmp	SHORT $L75626
$L75624:
	lea	ecx, DWORD PTR [esi-1]
	shr	ebx, cl
	mov	ecx, 32					; 00000020H
	sub	ecx, esi
	neg	edx
	mov	al, bl
	and	al, 1
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	or	eax, -1
	shl	eax, cl
	shr	ebx, 1
	and	eax, edx
	or	eax, ebx
$L75626:
	test	eax, eax
	sete	cl
	test	eax, eax
	mov	DWORD PTR _regs[edi*4], eax
	mov	eax, DWORD PTR _regs+92
	setl	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+1, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e080_0@4 ENDP


_align_func
@op_2070_0@4 PROC NEAR
	_start_func  'op_2070_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	shr	esi, 1
	and	esi, 7
	mov	DWORD PTR _regs[esi*4+32], eax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2070_0@4 ENDP


_align_func
@op_800_0@4 PROC NEAR
	_start_func  'op_800_0'
	mov	esi, eax
	shr	ecx, 8
	mov	ax, WORD PTR [esi+2]
	xor	edx, edx
	and	ecx, 7
	mov	dl, ah
	and	dl, 31					; 0000001fH
	add	esi, 4
	mov	eax, DWORD PTR _regs[ecx*4]
	mov	ecx, edx
	sar	eax, cl
	mov	DWORD PTR _regs+92, esi
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_800_0@4 ENDP


_align_func
@op_e148_0@4 PROC NEAR
	_start_func  'op_e148_0'
	mov	edx, ecx
	xor	eax, eax
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+3, 0
	shr	edx, 8
	mov	ecx, DWORD PTR _imm8_table[ecx*4]
	and	edx, 7
	and	ecx, 63					; 0000003fH
	mov	ax, WORD PTR _regs[edx*4]
	cmp	ecx, 16					; 00000010H
	jb	SHORT $L75657
	jne	SHORT $L108288
	and	al, 1
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L75658
$L108288:
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L75658
$L75657:
	dec	ecx
	shl	eax, cl
	mov	ecx, eax
	and	eax, 32767				; 00007fffH
	shr	ecx, 15					; 0000000fH
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shl	eax, 1
$L75658:
	test	ax, ax
	sete	cl
	test	ax, ax
	mov	WORD PTR _regs[edx*4], ax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e148_0@4 ENDP


_align_func
@op_2098_0@4 PROC NEAR
	_start_func  'op_2098_0'
	mov	eax, ecx
	push	ebx
	shr	eax, 8
	and	eax, 7
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	edx, DWORD PTR [edx+esi]
	bswap	edx
	mov	esi, DWORD PTR _regs[eax*4+32]
	add	esi, 4
	mov	DWORD PTR _regs[eax*4+32], esi
	xor	eax, eax
	cmp	edx, eax
	mov	esi, DWORD PTR _MEMBaseDiff
	sete	bl
	cmp	edx, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, bl
	setl	al
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, al
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	add	ecx, esi
	bswap	edx

	;RCHECK ecx										;MAC_BOOT_FIX

	mov	DWORD PTR [ecx], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2098_0@4 ENDP


_align_func
@op_b1d8_0@4 PROC NEAR
	_start_func  'op_b1d8_0'
	mov	eax, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	edx, DWORD PTR [edx+esi]
	bswap	edx
	mov	esi, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	add	esi, 4
	and	ecx, 7
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	esi, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	mov	eax, esi
	sub	eax, edx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L108308
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L108309
$L108308:
	mov	BYTE PTR _regflags+3, 0
$L108309:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b1d8_0@4 ENDP


_align_func
@op_e140_0@4 PROC NEAR
	_start_func  'op_e140_0'
	mov	edi, ecx
	xor	eax, eax
	shr	ecx, 1
	and	ecx, 7
	shr	edi, 8
	mov	esi, DWORD PTR _imm8_table[ecx*4]
	and	edi, 7
	and	esi, 63					; 0000003fH
	mov	ax, WORD PTR _regs[edi*4]
	cmp	esi, 16					; 00000010H
	jb	SHORT $L75708
	test	eax, eax
	setne	cl
	cmp	esi, 16					; 00000010H
	mov	BYTE PTR _regflags+3, cl
	jne	SHORT $L108319
	and	al, 1
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L75709
$L108319:
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L75709
$L75708:
	mov	ecx, 15					; 0000000fH
	mov	edx, 65535				; 0000ffffH
	sub	ecx, esi
	shl	edx, cl
	and	edx, 65535				; 0000ffffH
	mov	ecx, edx
	and	ecx, eax
	cmp	ecx, edx
	je	SHORT $L108321
	test	ecx, ecx
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L108322
$L108321:
	mov	BYTE PTR _regflags+3, 0
$L108322:
	lea	ecx, DWORD PTR [esi-1]
	shl	eax, cl
	mov	ecx, eax
	and	eax, 32767				; 00007fffH
	shr	ecx, 15					; 0000000fH
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shl	eax, 1
$L75709:
	test	ax, ax
	sete	dl
	test	ax, ax
	mov	WORD PTR _regs[edi*4], ax
	mov	eax, DWORD PTR _regs+92
	setl	cl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e140_0@4 ENDP


_align_func
@op_8190_0@4 PROC NEAR
	_start_func  'op_8190_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	push	ebx
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	eax, DWORD PTR _regs[eax*4]
	mov	edx, DWORD PTR [edx+ecx]
	bswap	edx
	or	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8190_0@4 ENDP


_align_func
@op_41fa_0@4 PROC NEAR
	_start_func  'op_41fa_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _regs+88
	sub	edx, ebx
	add	edx, eax
	shr	ecx, 1
	and	ecx, 7
	lea	edx, DWORD PTR [edx+esi+2]
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41fa_0@4 ENDP


_dstreg$ = -4
_align_func
@op_efc0_0@4 PROC NEAR
	_start_func  'op_efc0_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	and	ecx, 7
	mov	eax, edx
	and	edx, 2048				; 00000800H
	push	edi
	test	dx, dx
	mov	DWORD PTR _dstreg$[esp+24], ecx
	movsx	esi, ax
	je	SHORT $L108351
	mov	edx, esi
	sar	edx, 6
	and	edx, 7
	mov	edi, DWORD PTR _regs[edx*4]
	jmp	SHORT $L108352
$L108351:
	mov	edi, esi
	sar	edi, 6
	and	edi, 31					; 0000001fH
$L108352:
	test	al, 32					; 00000020H
	mov	eax, esi
	je	SHORT $L108354
	and	eax, 7
	mov	eax, DWORD PTR _regs[eax*4]
$L108354:
	mov	edx, DWORD PTR _regs[ecx*4]
	dec	eax
	and	edi, 31					; 0000001fH
	and	eax, 31					; 0000001fH
	mov	ecx, edi
	inc	eax
	mov	DWORD PTR -8+[esp+24], edx
	mov	ebp, 32					; 00000020H
	shl	edx, cl
	sub	ebp, eax
	mov	ebx, 1
	mov	ecx, ebp
	shr	edx, cl
	lea	ecx, DWORD PTR [eax-1]
	shl	ebx, cl
	test	ebx, edx
	setne	cl
	xor	ebx, ebx
	mov	BYTE PTR _regflags, cl
	cmp	edx, ebx
	mov	ecx, ebp
	sete	dl
	sar	esi, 12					; 0000000cH
	and	esi, 7
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags+3, bl
	mov	BYTE PTR _regflags+2, bl
	mov	esi, DWORD PTR _regs[esi*4]
	shl	esi, cl
	cmp	edi, ebx
	jne	SHORT $L108355
	xor	ebp, ebp
	jmp	SHORT $L108356
$L108355:
	mov	ecx, 32					; 00000020H
	or	ebp, -1
	sub	ecx, edi
	shl	ebp, cl
$L108356:
	add	eax, edi
	cmp	eax, 32					; 00000020H
	jl	SHORT $L108357
	mov	eax, DWORD PTR -8+[esp+24]
	xor	edx, edx
	jmp	SHORT $L108358
$L108357:
	or	edx, -1
	mov	ecx, eax
	mov	eax, DWORD PTR -8+[esp+24]
	shr	edx, cl
	and	edx, eax
$L108358:
	mov	ecx, edi
	and	eax, ebp
	shr	esi, cl
	pop	edi
	or	esi, eax
	mov	eax, DWORD PTR _dstreg$[esp+20]
	or	esi, edx
	mov	DWORD PTR _regs[eax*4], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_efc0_0@4 ENDP


_align_func
@op_20b8_0@4 PROC NEAR
	_start_func  'op_20b8_0'
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20b8_0@4 ENDP


_align_func
@op_1140_0@4 PROC NEAR
	_start_func  'op_1140_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 8
	mov	dx, WORD PTR [edx+2]
	and	eax, 7
	xor	bl, bl
	mov	al, BYTE PTR _regs[eax*4]
	mov	BYTE PTR _regflags+2, bl
	cmp	al, bl
	mov	BYTE PTR _regflags+3, bl
	sete	bl
	test	al, al
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	mov	BYTE PTR _regflags, bl
	xor	ebx, ebx
	mov	bl, dh
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 1
	and	ecx, 7
	or	esi, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, edx

	;add	esi, ecx
	;RCHECK esi										;MAC_BOOT_FIX
	;mov	BYTE PTR [esi], al

	mov	BYTE PTR [esi+ecx], al

	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1140_0@4 ENDP


_align_func
@op_e9c0_0@4 PROC NEAR
	_start_func  'op_e9c0_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	edi, ecx
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	edx, eax
	movsx	esi, ax
	and	edx, 2048				; 00000800H
	mov	ecx, esi
	test	dx, dx
	je	SHORT $L108395
	sar	ecx, 6
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	jmp	SHORT $L108396
$L108395:
	sar	ecx, 6
	and	ecx, 31					; 0000001fH
$L108396:
	test	al, 32					; 00000020H
	je	SHORT $L108397
	mov	edx, esi
	and	edx, 7
	mov	eax, DWORD PTR _regs[edx*4]
	jmp	SHORT $L108398
$L108397:
	mov	eax, esi
$L108398:
	lea	edx, DWORD PTR [eax-1]
	mov	eax, DWORD PTR _regs[edi*4]
	and	ecx, 31					; 0000001fH
	and	edx, 31					; 0000001fH
	shl	eax, cl
	inc	edx
	mov	ecx, 32					; 00000020H
	sub	ecx, edx
	shr	eax, cl
	lea	ecx, DWORD PTR [edx-1]
	mov	edx, 1
	shl	edx, cl
	test	edx, eax
	setne	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	sete	dl
	sar	esi, 12					; 0000000cH
	and	esi, 7
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags+2, cl
	mov	DWORD PTR _regs[esi*4], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e9c0_0@4 ENDP


_align_func
@op_42a0_0@4 PROC NEAR
	_start_func  'op_42a0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	ecx, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42a0_0@4 ENDP


_align_func
@op_30fc_0@4 PROC NEAR
	_start_func  'op_30fc_0'
	xor	edx, edx
	shr	ecx, 1
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	lea	esi, DWORD PTR [edx+2]
	mov	DWORD PTR _regs[ecx*4+32], esi
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	ch, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+edx], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30fc_0@4 ENDP


_align_func
@op_4240_0@4 PROC NEAR
	_start_func  'op_4240_0'
	shr	ecx, 8
	and	ecx, 7
	xor	eax, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	mov	WORD PTR _regs[ecx*4], ax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, 1
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4240_0@4 ENDP


_align_func
@op_4e90_0@4 PROC NEAR
	_start_func  'op_4e90_0'
	mov	edx, DWORD PTR _regs+88
	sub	eax, DWORD PTR _regs+96
	shr	ecx, 8
	lea	eax, DWORD PTR [eax+edx+2]
	mov	edx, DWORD PTR _regs+60
	mov	esi, eax
	mov	edi, eax
	and	esi, 16711680				; 00ff0000H
	and	ecx, 7
	shr	edi, 16					; 00000010H
	or	esi, edi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	edi, eax
	sub	edx, 4
	and	edi, 65280				; 0000ff00H
	mov	DWORD PTR _regs+60, edx
	shl	eax, 16					; 00000010H
	or	edi, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	esi, 8
	shl	edi, 8
	or	esi, edi
	mov	DWORD PTR [eax+edx], esi
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _regs+88, ecx
	lea	eax, DWORD PTR [edx+ecx]
	mov	DWORD PTR _regs+96, eax
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4e90_0@4 ENDP


_align_func
@op_4a90_0@4 PROC NEAR
	_start_func  'op_4a90_0'
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [eax+ecx]
	bswap	eax
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a90_0@4 ENDP


_align_func
@op_b1e8_0@4 PROC NEAR
	_start_func  'op_b1e8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	edi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	add	edx, edi
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	shr	ecx, 1
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	mov	eax, esi
	sub	eax, edx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L108469
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L108470
$L108469:
	mov	BYTE PTR _regflags+3, 0
$L108470:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b1e8_0@4 ENDP


_align_func
@op_4228_0@4 PROC NEAR
	_start_func  'op_4228_0'
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	xor	dl, dl
	mov	bl, ah
	mov	BYTE PTR _regflags+2, dl
	movsx	esi, bx
	xor	ebx, ebx
	mov	BYTE PTR _regflags+3, dl
	mov	bh, al
	mov	BYTE PTR _regflags+1, 1
	shr	ecx, 8
	movsx	eax, bx
	and	ecx, 7
	or	esi, eax
	mov	BYTE PTR _regflags, dl
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, ebx
	mov	BYTE PTR [esi+ecx], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4228_0@4 ENDP


_align_func
@op_8040_0@4 PROC NEAR
	_start_func  'op_8040_0'
	mov	eax, ecx
	xor	edx, edx
	shr	ecx, 8
	shr	eax, 1
	and	ecx, 7
	and	eax, 7
	mov	BYTE PTR _regflags+2, dl
	mov	cx, WORD PTR _regs[ecx*4]
	mov	BYTE PTR _regflags+3, dl
	or	cx, WORD PTR _regs[eax*4]
	cmp	cx, dx
	mov	WORD PTR _regs[eax*4], cx
	mov	eax, DWORD PTR _regs+92
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8040_0@4 ENDP


_align_func
@op_3100_0@4 PROC NEAR
	_start_func  'op_3100_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	shr	ecx, 8
	mov	edx, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	sub	edx, 2
	mov	cx, WORD PTR _regs[ecx*4]
	mov	DWORD PTR _regs[eax*4+32], edx
	xor	eax, eax
	cmp	cx, ax
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	cx, ax
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags, al
	xor	eax, eax
	mov	al, ch
	mov	BYTE PTR _regflags+1, bl
	mov	ah, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+edx], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3100_0@4 ENDP


_align_func
@op_2088_0@4 PROC NEAR
	_start_func  'op_2088_0'
	mov	eax, ecx
	xor	edx, edx
	shr	eax, 8
	and	eax, 7
	push	ebx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	eax, DWORD PTR _regs[eax*4+32]
	cmp	eax, edx
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2088_0@4 ENDP


_align_func
@op_307c_0@4 PROC NEAR
	_start_func  'op_307c_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 1
	and	ecx, 7
	or	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_307c_0@4 ENDP


_align_func
@op_41f9_0@4 PROC NEAR
	_start_func  'op_41f9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	shr	ecx, 1
	and	ecx, 7
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41f9_0@4 ENDP


_align_func
@op_41fb_0@4 PROC NEAR
	_start_func  'op_41fb_0'
	mov	edx, DWORD PTR _regs+96
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	shr	esi, 1
	and	esi, 7
	mov	DWORD PTR _regs[esi*4+32], eax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41fb_0@4 ENDP


_align_func
@op_213c_0@4 PROC NEAR
	_start_func  'op_213c_0'
	push	ebx
	shr	ecx, 1
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	ecx, ecx
	cmp	edx, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	edx, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_213c_0@4 ENDP


_align_func
@op_4a18_0@4 PROC NEAR
	_start_func  'op_4a18_0'
	shr	ecx, 8
	mov	edx, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	dl, BYTE PTR [esi+edx]
	add	ecx, esi
	mov	DWORD PTR [eax], ecx
	xor	al, al
	cmp	dl, al
	mov	BYTE PTR _regflags+2, al
	sete	cl
	mov	BYTE PTR _regflags+3, al
	cmp	dl, al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a18_0@4 ENDP


_align_func
@op_c90_0@4 PROC NEAR
	_start_func  'op_c90_0'
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR [ecx+eax]
	bswap	esi
	mov	eax, esi
	xor	ecx, ecx
	sub	eax, edx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L108565
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L108566
$L108565:
	mov	BYTE PTR _regflags+3, 0
$L108566:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c90_0@4 ENDP


_align_func
@op_ca8_0@4 PROC NEAR
	_start_func  'op_ca8_0'
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	edx, DWORD PTR _regs+92
	xor	ebx, ebx
	shr	ecx, 8
	mov	ax, WORD PTR [edx+6]
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	mov	ecx, DWORD PTR [edx+ecx]
	bswap	ecx
	mov	eax, ecx
	xor	edx, edx
	sub	eax, esi
	test	ecx, ecx
	setl	dl
	mov	edi, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	esi, esi
	setl	al
	cmp	eax, edi
	je	SHORT $L108582
	cmp	edx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L108583
$L108582:
	mov	BYTE PTR _regflags+3, 0
$L108583:
	mov	eax, DWORD PTR _regs+92
	cmp	esi, ecx
	seta	cl
	test	edx, edx
	setne	dl
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ca8_0@4 ENDP


_align_func
@op_c068_0@4 PROC NEAR
	_start_func  'op_c068_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	esi, ecx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	and	esi, 7
	mov	ax, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ah
	xor	ecx, ecx
	mov	dh, al
	mov	BYTE PTR _regflags+2, cl
	and	dx, WORD PTR _regs[esi*4]
	mov	BYTE PTR _regflags+3, cl
	mov	eax, edx
	cmp	ax, cx
	mov	WORD PTR _regs[esi*4], ax
	sete	dl
	cmp	ax, cx
	mov	eax, DWORD PTR _regs+92
	setl	cl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c068_0@4 ENDP


_newv$76024 = -4
_align_func
@op_d0a8_0@4 PROC NEAR
	_start_func  'op_d0a8_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	push	esi
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	push	edi
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	and	esi, 7
	mov	ecx, DWORD PTR [edx+ecx]
	bswap	ecx
	mov	edi, DWORD PTR _regs[esi*4]
	xor	eax, eax
	lea	edx, DWORD PTR [ecx+edi]
	test	edx, edx
	setl	al
	test	edx, edx
	mov	DWORD PTR _newv$76024[ebp], edx
	sete	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, al
	test	edi, edi
	setl	bl
	xor	bl, al
	not	edi
	and	dl, bl
	cmp	edi, ecx
	setb	cl
	test	eax, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _newv$76024[ebp]
	pop	edi
	setne	al
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs[esi*4], ecx
	mov	eax, DWORD PTR _regs+92
	pop	esi
	add	eax, 4
	mov	BYTE PTR _regflags+3, dl
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d0a8_0@4 ENDP


_flgn$76050 = -4
_align_func
@op_9088_0@4 PROC NEAR
	_start_func  'op_9088_0'
	mov	esi, ecx
	shr	esi, 1
	and	esi, 7
	shr	ecx, 8
	mov	eax, DWORD PTR _regs[esi*4]
	and	ecx, 7
	mov	edi, eax
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	sub	edi, ebp
	test	eax, eax
	setl	cl
	xor	edx, edx
	mov	DWORD PTR _regs[esi*4], edi
	test	edi, edi
	setl	dl
	test	edi, edi
	sete	bl
	test	ebp, ebp
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$76050[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$76050[esp+20]
	and	bl, dl
	cmp	ebp, eax
	seta	al
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+3, bl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9088_0@4 ENDP


_align_func
@op_2110_0@4 PROC NEAR
	_start_func  'op_2110_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	push	ebx
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	edx, DWORD PTR [ecx+edx]
	bswap	edx
	mov	ecx, DWORD PTR _regs[eax*4+32]
	sub	ecx, 4
	mov	DWORD PTR _regs[eax*4+32], ecx
	xor	eax, eax
	cmp	edx, eax
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	edx, eax
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2110_0@4 ENDP


_align_func
@op_20d0_0@4 PROC NEAR
	_start_func  'op_20d0_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	push	ebx
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	push	esi
	and	eax, 7
	mov	ecx, DWORD PTR [ecx+edx]
	bswap	ecx
	mov	edx, DWORD PTR _regs[eax*4+32]
	lea	esi, DWORD PTR [edx+4]
	mov	DWORD PTR _regs[eax*4+32], esi
	xor	eax, eax
	cmp	ecx, eax
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	ecx, eax
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20d0_0@4 ENDP


_align_func
@op_313c_0@4 PROC NEAR
	_start_func  'op_313c_0'
	xor	edx, edx
	shr	ecx, 1
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	sub	edx, 2
	mov	DWORD PTR _regs[ecx*4+32], edx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	ch, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+edx], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_313c_0@4 ENDP


_align_func
@op_d088_0@4 PROC NEAR
	_start_func  'op_d088_0'
	mov	esi, ecx
	shr	esi, 1
	shr	ecx, 8
	and	esi, 7
	and	ecx, 7
	xor	eax, eax
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _regs[esi*4]
	lea	ecx, DWORD PTR [edi+ebp]
	test	ecx, ecx
	setl	al
	test	ecx, ecx
	sete	dl
	test	edi, edi
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs[esi*4], ecx
	setl	dl
	xor	dl, al
	test	ebp, ebp
	setl	bl
	xor	bl, al
	not	edi
	and	dl, bl
	cmp	edi, ebp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d088_0@4 ENDP


_align_func
@op_4aa8_0@4 PROC NEAR
	_start_func  'op_4aa8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4aa8_0@4 ENDP


_align_func
@op_2168_0@4 PROC NEAR
	_start_func  'op_2168_0'
	push	esi
	mov	esi, ecx
	push	edi
	mov	ax, WORD PTR [eax+2]
	xor	ecx, ecx
	mov	cl, ah
	movsx	edx, cx
	xor	ecx, ecx
	mov	ch, al
	movsx	eax, cx
	mov	ecx, esi
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	add	edx, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR [edx+eax]
	bswap	edi
	mov	ecx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	edi, eax
	mov	cx, WORD PTR [ecx+4]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	edi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 1
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2168_0@4 ENDP


_align_func
@op_3008_0@4 PROC NEAR
	_start_func  'op_3008_0'
	mov	eax, ecx
	xor	edx, edx
	shr	eax, 8
	and	eax, 7
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	ax, WORD PTR _regs[eax*4+32]
	cmp	ax, dx
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	WORD PTR _regs[ecx*4], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3008_0@4 ENDP


_align_func
@op_3168_0@4 PROC NEAR
	_start_func  'op_3168_0'
	mov	esi, ecx
	xor	edx, edx
	mov	ecx, DWORD PTR _regs+92
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	edi, DWORD PTR _regs[eax*4+32]
	add	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [edx+edi]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	eax, ecx
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3168_0@4 ENDP


_align_func
@op_2038_0@4 PROC NEAR
	_start_func  'op_2038_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2038_0@4 ENDP


_align_func
@op_e040_0@4 PROC NEAR
	_start_func  'op_e040_0'
	mov	edi, ecx
	shr	edi, 8
	and	edi, 7
	xor	eax, eax
	shr	ecx, 1
	mov	ax, WORD PTR _regs[edi*4]
	and	ecx, 7
	mov	ebx, eax
	mov	BYTE PTR _regflags+3, 0
	mov	esi, DWORD PTR _imm8_table[ecx*4]
	shr	ebx, 15					; 0000000fH
	and	esi, 63					; 0000003fH
	and	ebx, 1
	cmp	esi, 16					; 00000010H
	jb	SHORT $L76204
	mov	edx, ebx
	mov	BYTE PTR _regflags+2, bl
	neg	edx
	and	edx, 65535				; 0000ffffH
	mov	BYTE PTR _regflags+4, bl
	jmp	SHORT $L76206
$L76204:
	lea	ecx, DWORD PTR [esi-1]
	mov	edx, 65535				; 0000ffffH
	shr	eax, cl
	neg	ebx
	mov	cl, al
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, 16					; 00000010H
	sub	ecx, esi
	shl	edx, cl
	shr	eax, 1
	and	eax, 65535				; 0000ffffH
	and	edx, ebx
	and	edx, 65535				; 0000ffffH
	or	edx, eax
$L76206:
	test	dx, dx
	sete	al
	mov	BYTE PTR _regflags+1, al
	mov	WORD PTR _regs[edi*4], dx
	mov	eax, DWORD PTR _regs+92
	test	dx, dx
	setl	cl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e040_0@4 ENDP


_align_func
@op_1180_0@4 PROC NEAR
	_start_func  'op_1180_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	bl, BYTE PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	cl, cl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1180_0@4 ENDP


_align_func
@op_1010_0@4 PROC NEAR
	_start_func  'op_1010_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [edx+eax]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1010_0@4 ENDP


_align_func
@op_c68_0@4 PROC NEAR
	_start_func  'op_c68_0'
	mov	edi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [edi+2]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR [edi+4]
	mov	esi, edx
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebp
	mov	ax, WORD PTR [edx+ecx]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	movsx	eax, cx
	movsx	edx, si
	sub	eax, edx
	xor	edx, edx
	test	cx, cx
	setl	dl
	mov	ebp, edx
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	si, si
	setl	al
	cmp	eax, ebp
	je	SHORT $L108775
	cmp	edx, ebp
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L108776
$L108775:
	mov	BYTE PTR _regflags+3, 0
$L108776:
	cmp	si, cx
	seta	cl
	test	edx, edx
	setne	dl
	add	edi, 6
	mov	BYTE PTR _regflags+2, cl
	mov	DWORD PTR _regs+92, edi
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c68_0@4 ENDP


_align_func
@op_c0c0_0@4 PROC NEAR					;MULU OK (FIXED)
	mov	esi, ecx
	add	eax, 2
	shr	ecx, 8
	and	esi, 14
	and	ecx, 7
	movzx	edx, WORD PTR _regs[esi*2]
	movzx	edi, WORD PTR _regs[ecx*4]
	xor	ecx, ecx
	imul	edi, edx
	mov	DWORD PTR _regs+92, eax
	mov	DWORD PTR _regs[esi*2], edi
	cmp	edi, ecx
	mov	esi,[_cpufunctbl]
	mov	WORD PTR _regflags+2, cx
	sete	BYTE PTR _regflags+1
	setl	BYTE PTR _regflags
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+esi]
@op_c0c0_0@4 ENDP


_align_func
@op_880_0@4 PROC NEAR
	_start_func  'op_880_0'
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	mov	eax, ecx
	mov	ecx, DWORD PTR _regs+92
	mov	cx, WORD PTR [ecx+2]
	mov	esi, DWORD PTR _regs[eax*4]
	mov	dl, ch
	and	edx, 31					; 0000001fH
	mov	ecx, edx
	mov	edx, esi
	movsx	edi, cx
	mov	ecx, edi
	sar	edx, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	edx, 1
	shl	edx, cl
	not	edx
	and	edx, esi
	mov	DWORD PTR _regs[eax*4], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_880_0@4 ENDP


_align_func
@op_42a8_0@4 PROC NEAR
	_start_func  'op_42a8_0'
	push	ebx
	push	esi
	mov	esi, ecx
	mov	cx, WORD PTR [eax+2]
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	xor	edx, edx
	shr	esi, 8
	movsx	eax, ax
	movsx	ecx, bx
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, dl
	mov	ebx, DWORD PTR _regs[esi*4+32]
	mov	BYTE PTR _regflags+3, dl
	add	eax, ebx
	mov	BYTE PTR _regflags+1, 1
	mov	BYTE PTR _regflags, dl
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42a8_0@4 ENDP


_align_func
@op_41f8_0@4 PROC NEAR
	_start_func  'op_41f8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 1
	and	ecx, 7
	or	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41f8_0@4 ENDP


_align_func
@op_c190_0@4 PROC NEAR
	_start_func  'op_c190_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	push	ebx
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	eax, DWORD PTR _regs[eax*4]
	mov	edx, DWORD PTR [edx+ecx]
	bswap	edx
	and	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c190_0@4 ENDP


_align_func
@op_c098_0@4 PROC NEAR
	_start_func  'op_c098_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	edx, DWORD PTR [edx+esi]
	bswap	edx
	and	ecx, 7
	mov	esi, DWORD PTR _regs[eax*4+32]
	add	esi, 4
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	eax, DWORD PTR _regs[ecx*4]
	and	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c098_0@4 ENDP


_flgn$76350 = -4
_align_func
@op_9068_0@4 PROC NEAR
	_start_func  'op_9068_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	xor	ebx, ebx
	mov	esi, ecx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebp
	and	esi, 7
	mov	ax, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR _regs[esi*4]
	mov	ebp, edx
	movsx	edi, ax
	movsx	ecx, bp
	sub	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	xor	edx, edx
	mov	WORD PTR _regs[esi*4], di
	test	di, di
	setl	dl
	test	di, di
	sete	bl
	test	bp, bp
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$76350[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$76350[esp+20]
	and	bl, dl
	cmp	bp, ax
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _regs+92
	test	ecx, ecx
	setne	dl
	add	eax, 4
	mov	BYTE PTR _regflags+3, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9068_0@4 ENDP


_align_func
@op_c80_0@4 PROC NEAR
	_start_func  'op_c80_0'
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4]
	xor	ecx, ecx
	mov	eax, esi
	sub	eax, edx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L108857
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L108858
$L108857:
	mov	BYTE PTR _regflags+3, 0
$L108858:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c80_0@4 ENDP


_dst$76386 = -4
_flgn$76394 = -8
_align_func
@op_90a8_0@4 PROC NEAR
	_start_func  'op_90a8_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	push	esi
	mov	esi, ecx
	mov	dl, ah
	mov	bh, al
	push	edi
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	edi, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, edi
	and	esi, 7
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	mov	edx, DWORD PTR _regs[esi*4]
	xor	ecx, ecx
	mov	edi, edx
	mov	DWORD PTR _dst$76386[ebp], edx
	sub	edi, eax
	test	edx, edx
	setl	cl
	xor	edx, edx
	mov	DWORD PTR _regs[esi*4], edi
	test	edi, edi
	setl	dl
	test	edi, edi
	sete	bl
	test	eax, eax
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$76394[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$76394[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _dst$76386[ebp]
	pop	edi
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, bl
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _regs+92
	pop	esi
	test	ecx, ecx
	setne	dl
	add	eax, 4
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_90a8_0@4 ENDP


_align_func
@op_4260_0@4 PROC NEAR
	_start_func  'op_4260_0'
	shr	ecx, 8
	and	ecx, 7
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 2
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	ecx, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags, cl
	mov	WORD PTR [edx+eax], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4260_0@4 ENDP


_align_func
@op_2178_0@4 PROC NEAR
	_start_func  'op_2178_0'
	push	esi
	mov	esi, ecx
	push	edi
	mov	ax, WORD PTR [eax+2]
	xor	ecx, ecx
	mov	cl, ah
	movsx	edx, cx
	xor	ecx, ecx
	mov	ch, al
	movsx	eax, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	edi, DWORD PTR [edx+ecx]
	bswap	edi
	mov	edx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	edi, eax
	mov	cx, WORD PTR [edx+4]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	edi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 1
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2178_0@4 ENDP


_align_func
@op_c140_0@4 PROC NEAR
	_start_func  'op_c140_0'
	mov	eax, ecx
	shr	ecx, 8
	shr	eax, 1
	and	ecx, 7
	and	eax, 7
	mov	esi, DWORD PTR _regs[ecx*4]
	mov	edx, DWORD PTR _regs[eax*4]
	mov	DWORD PTR _regs[eax*4], esi
	mov	DWORD PTR _regs[ecx*4], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c140_0@4 ENDP


_align_func
@op_d068_0@4 PROC NEAR
	_start_func  'op_d068_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	xor	ebx, ebx
	mov	esi, ecx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebp
	and	esi, 7
	mov	ax, WORD PTR [edx+ecx]
	mov	di, WORD PTR _regs[esi*4]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	xor	eax, eax
	movsx	ebp, di
	movsx	edx, cx
	add	ebp, edx
	test	bp, bp
	setl	al
	test	bp, bp
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	mov	WORD PTR _regs[esi*4], bp
	setl	dl
	xor	dl, al
	test	cx, cx
	setl	bl
	xor	bl, al
	not	edi
	and	dl, bl
	cmp	di, cx
	setb	cl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d068_0@4 ENDP


_align_func
@op_c0d0_0@4 PROC NEAR					;MULU OK (FIXED)
	mov	esi, ecx
	mov	edi, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	esi, 14
	and	ecx, 7
	xor	edx, edx
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	add	eax, 2
	mov	bx, WORD PTR [ebx+edi]
	movzx	ecx, WORD PTR _regs[esi*2]
	xchg	bl, bh
	mov	DWORD PTR _regs+92, eax
	movzx	ebx, bx
	imul	ebx, ecx
	mov	edi,[_cpufunctbl]
	mov	WORD PTR _regflags+2, cx
	cmp	ebx, edx
	mov	DWORD PTR _regs[esi*2], ebx
	movzx	ecx, word ptr[eax]
	sete	BYTE PTR _regflags+1
	setl	BYTE PTR _regflags
	jmp	[ecx*4+edi]
@op_c0d0_0@4 ENDP


_align_func
@op_4200_0@4 PROC NEAR
	_start_func  'op_4200_0'
	shr	ecx, 8
	and	ecx, 7
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, 1
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4200_0@4 ENDP


_align_func
@op_4c40_0@4 PROC NEAR
	_start_func  'op_4c40_0'
	mov	edx, eax
	mov	eax, DWORD PTR _regs+88
	mov	edi, DWORD PTR _regs+96
	add	edx, 2
	sub	eax, edi
	mov	esi, ecx
	add	eax, edx
	mov	edi, esi
	mov	DWORD PTR _regs+92, edx
	mov	cx, WORD PTR [edx]
	push	eax
	xor	eax, eax
	shr	edi, 8
	and	edi, 7
	mov	al, ch
	mov	ah, cl
	add	edx, 2
	mov	edi, DWORD PTR _regs[edi*4]
	push	eax
	push	edi
	push	esi
	mov	DWORD PTR _regs+92, edx
	call	_m68k_divl@16
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4c40_0@4 ENDP


_align_func
@op_b0b0_0@4 PROC NEAR
	_start_func  'op_b0b0_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	shr	esi, 1
	and	esi, 7
	xor	edx, edx
	mov	esi, DWORD PTR _regs[esi*4]
	mov	eax, esi
	sub	eax, ecx
	test	esi, esi
	setl	dl
	mov	edi, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	ecx, ecx
	setl	al
	cmp	eax, edi
	je	SHORT $L108947
	cmp	edx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L108948
$L108947:
	mov	BYTE PTR _regflags+3, 0
$L108948:
	cmp	ecx, esi
	seta	cl
	test	edx, edx
	setne	dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b0b0_0@4 ENDP


_align_func
@op_3030_0@4 PROC NEAR
	_start_func  'op_3030_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	mov	dl, ah
	mov	BYTE PTR _regflags+2, cl
	mov	dh, al
	mov	BYTE PTR _regflags+3, cl
	mov	eax, edx
	cmp	ax, cx
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	shr	esi, 1
	and	esi, 7
	mov	BYTE PTR _regflags, cl
	mov	WORD PTR _regs[esi*4], ax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3030_0@4 ENDP


_align_func
@op_d0e8_0@4 PROC NEAR
	_start_func  'op_d0e8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	and	esi, 7
	mov	ax, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ah
	movsx	ecx, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	edx, DWORD PTR _regs[esi*4+32]
	or	ecx, eax
	add	edx, ecx
	mov	DWORD PTR _regs[esi*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d0e8_0@4 ENDP


_align_func
@op_4ef0_0@4 PROC NEAR
	_start_func  'op_4ef0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _regs+88, eax
	add	ecx, eax
	mov	DWORD PTR _regs+96, ecx
	mov	DWORD PTR _regs+92, ecx
	mov	eax,ecx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ef0_0@4 ENDP


_align_func
@op_c0d8_0@4 PROC NEAR
	_start_func  'op_c0d8_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	eax, 8
	shr	ecx, 1
	and	eax, 7
	and	ecx, 7
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	dx, WORD PTR [ecx+edx]
	add	ecx, 2
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, edx
	xor	ecx, ecx
	and	eax, 65535				; 0000ffffH
	mov	ch, dl
	xor	edx, edx
	mov	dx, WORD PTR _regs[esi*4]
	and	ecx, 65535				; 0000ffffH
	shr	eax, 8
	or	eax, ecx
	xor	ecx, ecx
	imul	eax, edx
	cmp	eax, ecx
	mov	DWORD PTR _regs[esi*4], eax
	sete	dl
	cmp	eax, ecx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c0d8_0@4 ENDP


_align_func
@op_4640_0@4 PROC NEAR
	_start_func  'op_4640_0'
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	mov	BYTE PTR _regflags+2, dl
	movsx	eax, WORD PTR _regs[ecx*4]
	not	eax
	cmp	ax, dx
	mov	WORD PTR _regs[ecx*4], ax
	sete	bl
	cmp	ax, dx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4640_0@4 ENDP


_align_func
@op_4880_0@4 PROC NEAR
	_start_func  'op_4880_0'
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	mov	BYTE PTR _regflags+2, dl
	movsx	ax, BYTE PTR _regs[ecx*4]
	cmp	ax, dx
	mov	WORD PTR _regs[ecx*4], ax
	sete	bl
	cmp	ax, dx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4880_0@4 ENDP


_align_func
@op_2118_0@4 PROC NEAR
	_start_func  'op_2118_0'
	mov	eax, ecx
	push	ebx
	shr	eax, 8
	and	eax, 7
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	edx, DWORD PTR [edx+esi]
	bswap	edx
	and	ecx, 7
	mov	ebx, DWORD PTR _regs[eax*4+32]
	add	ebx, 4
	mov	DWORD PTR _regs[eax*4+32], ebx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	ecx, ecx
	cmp	edx, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	edx, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2118_0@4 ENDP


_align_func
@op_b1c0_0@4 PROC NEAR
	_start_func  'op_b1c0_0'
	mov	eax, ecx
	shr	ecx, 1
	shr	eax, 8
	and	ecx, 7
	and	eax, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _regs[eax*4]
	mov	eax, esi
	xor	ecx, ecx
	sub	eax, edx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L109044
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L109045
$L109044:
	mov	BYTE PTR _regflags+3, 0
$L109045:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b1c0_0@4 ENDP


_align_func
@op_3038_0@4 PROC NEAR
	_start_func  'op_3038_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	WORD PTR _regs[ecx*4], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3038_0@4 ENDP


_align_func
@op_3128_0@4 PROC NEAR
	_start_func  'op_3128_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	esi, ecx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	edi, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	add	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	and	esi, 7
	mov	ax, WORD PTR [edx+edi]
	xor	edx, edx
	mov	cl, ah
	mov	BYTE PTR _regflags+2, dl
	mov	ch, al
	mov	BYTE PTR _regflags+3, dl
	mov	eax, ecx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	sub	ecx, 2
	cmp	ax, dx
	sete	bl
	cmp	ax, dx
	mov	DWORD PTR _regs[esi*4+32], ecx
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	WORD PTR [edi+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3128_0@4 ENDP


_align_func
@op_4268_0@4 PROC NEAR
	_start_func  'op_4268_0'
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	xor	edx, edx
	mov	bl, ah
	mov	BYTE PTR _regflags+2, dl
	movsx	esi, bx
	xor	ebx, ebx
	mov	BYTE PTR _regflags+3, dl
	mov	bh, al
	mov	BYTE PTR _regflags+1, 1
	shr	ecx, 8
	movsx	eax, bx
	and	ecx, 7
	or	esi, eax
	mov	BYTE PTR _regflags, dl
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, ebx
	mov	WORD PTR [esi+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4268_0@4 ENDP


_align_func
@op_b028_0@4 PROC NEAR
	_start_func  'op_b028_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	xor	ebx, ebx
	shr	ecx, 1
	mov	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	add	edx, esi
	and	ecx, 7
	mov	dl, BYTE PTR [edx+eax]
	mov	cl, BYTE PTR _regs[ecx*4]
	movsx	eax, cl
	movsx	esi, dl
	sub	eax, esi
	test	cl, cl
	setl	bl
	mov	esi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dl, dl
	setl	al
	cmp	eax, esi
	mov	edi, ebx
	je	SHORT $L109091
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L109092
$L109091:
	mov	BYTE PTR _regflags+3, 0
$L109092:
	mov	eax, DWORD PTR _regs+92
	cmp	dl, cl
	seta	cl
	test	edi, edi
	setne	dl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b028_0@4 ENDP


_align_func
@op_11d8_0@4 PROC NEAR
	_start_func  'op_11d8_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	al, BYTE PTR [esi+edi]
	add	ecx, esi
	mov	DWORD PTR [edx], ecx
	mov	edx, DWORD PTR _regs+92
	mov	cx, WORD PTR [edx+2]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	BYTE PTR [edx+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11d8_0@4 ENDP


_align_func
@op_e180_0@4 PROC NEAR
	_start_func  'op_e180_0'
	mov	edi, ecx
	shr	ecx, 1
	and	ecx, 7
	shr	edi, 8
	mov	edx, DWORD PTR _imm8_table[ecx*4]
	and	edi, 7
	and	edx, 63					; 0000003fH
	mov	eax, DWORD PTR _regs[edi*4]
	cmp	edx, 32					; 00000020H
	jb	SHORT $L76719
	test	eax, eax
	setne	cl
	cmp	edx, 32					; 00000020H
	mov	BYTE PTR _regflags+3, cl
	jne	SHORT $L109122
	and	al, 1
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L76720
$L109122:
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L76720
$L76719:
	mov	ecx, 31					; 0000001fH
	push	esi
	sub	ecx, edx
	or	esi, -1
	shl	esi, cl
	mov	ecx, esi
	and	ecx, eax
	cmp	ecx, esi
	pop	esi
	je	SHORT $L109124
	test	ecx, ecx
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L109125
$L109124:
	mov	BYTE PTR _regflags+3, 0
$L109125:
	lea	ecx, DWORD PTR [edx-1]
	shl	eax, cl
	mov	ecx, eax
	shr	ecx, 31					; 0000001fH
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shl	eax, 1
$L76720:
	test	eax, eax
	sete	dl
	test	eax, eax
	mov	DWORD PTR _regs[edi*4], eax
	mov	eax, DWORD PTR _regs+92
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e180_0@4 ENDP


_align_func
@op_117c_0@4 PROC NEAR
	_start_func  'op_117c_0'
	mov	edx, eax
	xor	bl, bl
	mov	al, BYTE PTR [edx+3]
	mov	dx, WORD PTR [edx+4]
	cmp	al, bl
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+3, bl
	sete	bl
	test	al, al
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	mov	BYTE PTR _regflags, bl
	xor	ebx, ebx
	mov	bl, dh
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 1
	and	ecx, 7
	or	esi, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, edx
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_117c_0@4 ENDP


_align_func
@op_1138_0@4 PROC NEAR
	_start_func  'op_1138_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	shr	ecx, 1
	mov	dl, ah
	mov	bh, al
	and	ecx, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _areg_byteinc[ecx*4]
	lea	esi, DWORD PTR _regs[ecx*4+32]
	or	edx, eax
	xor	cl, cl
	mov	eax, DWORD PTR [esi]
	mov	dl, BYTE PTR [edx+edi]
	sub	eax, ebx
	cmp	dl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	dl, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	DWORD PTR [esi], eax
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1138_0@4 ENDP


_align_func
@op_b188_0@4 PROC NEAR
	_start_func  'op_b188_0'
	mov	eax, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	mov	edx, DWORD PTR [edx+esi]
	bswap	edx
	mov	esi, DWORD PTR _regs[eax*4+32]
	mov	edi, 4
	add	esi, edi
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [eax+esi]
	bswap	esi
	mov	eax, DWORD PTR _regs[ecx*4+32]
	add	eax, edi
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	eax, esi
	sub	eax, edx
	xor	ecx, ecx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L109160
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L109161
$L109160:
	mov	BYTE PTR _regflags+3, 0
$L109161:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b188_0@4 ENDP


_align_func
@op_4220_0@4 PROC NEAR
	_start_func  'op_4220_0'
	shr	ecx, 8
	and	ecx, 7
	mov	BYTE PTR _regflags+1, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	sub	eax, esi
	xor	cl, cl
	mov	DWORD PTR [edx], eax
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4220_0@4 ENDP


_align_func
@op_2158_0@4 PROC NEAR
	_start_func  'op_2158_0'
	push	ebx
	push	esi
	mov	esi, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, esi
	push	edi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	edi, DWORD PTR [ecx+edx]
	bswap	edi
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	edx, 4
	add	ecx, edx
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	mov	cx, WORD PTR [eax+2]
	xor	eax, eax
	cmp	edi, eax
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	edi, eax
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	shr	esi, 1
	movsx	eax, ax
	movsx	ecx, bx
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, edx
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2158_0@4 ENDP


_align_func
@op_3158_0@4 PROC NEAR
	_start_func  'op_3158_0'
	mov	esi, ecx
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	xor	edx, edx
	mov	edi, DWORD PTR _regs[eax*4+32]
	mov	cx, WORD PTR [edi+ebp]
	add	edi, 2
	mov	dl, ch
	mov	DWORD PTR _regs[eax*4+32], edi
	mov	eax, DWORD PTR _regs+92
	mov	dh, cl
	mov	ecx, edx
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	cmp	cx, dx
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ch
	xor	ebx, ebx
	mov	dh, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	bh, al
	shr	esi, 1
	movsx	ecx, cx
	movsx	eax, bx
	and	esi, 7
	or	ecx, eax
	mov	edi, DWORD PTR _regs[esi*4+32]
	add	ecx, edi
	mov	WORD PTR [ecx+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3158_0@4 ENDP


_align_func
@op_128_0@4 PROC NEAR
	_start_func  'op_128_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	add	edx, edi
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	dl, BYTE PTR [edx+eax]
	and	cl, 7
	mov	DWORD PTR _regs+92, esi
	shr	dl, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_128_0@4 ENDP


_align_func
@op_40e0_0@4 PROC NEAR
	_start_func  'op_40e0_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	jne	SHORT $L76834
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L76834:
	push	esi
	mov	esi, DWORD PTR _regs[ecx*4+32]
	sub	esi, 2
	mov	DWORD PTR _regs[ecx*4+32], esi
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40e0_0@4 ENDP


_align_func
@op_e090_0@4 PROC NEAR
	_start_func  'op_e090_0'
	mov	edx, ecx
	shr	edx, 8
	shr	ecx, 1
	and	edx, 7
	and	ecx, 7
	mov	BYTE PTR _regflags+3, 0
	mov	eax, DWORD PTR _regs[edx*4]
	mov	esi, DWORD PTR _imm8_table[ecx*4]
	movsx	ecx, BYTE PTR _regflags+4
	lea	edi, DWORD PTR [eax+eax]
	and	esi, 63					; 0000003fH
	or	edi, ecx
	dec	esi
	mov	ecx, 31					; 0000001fH
	sub	ecx, esi
	shl	edi, cl
	mov	ecx, esi
	shr	eax, cl
	mov	ecx, eax
	shr	eax, 1
	and	ecx, 1
	or	eax, edi
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+2, cl
	sete	cl
	test	eax, eax
	mov	DWORD PTR _regs[edx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e090_0@4 ENDP


_align_func
@op_2180_0@4 PROC NEAR
	_start_func  'op_2180_0'
	mov	eax, ecx
	push	esi
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	esi, DWORD PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2180_0@4 ENDP


_align_func
@op_8198_0@4 PROC NEAR
	_start_func  'op_8198_0'
	mov	eax, ecx
	push	ebx
	shr	eax, 8
	and	eax, 7
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	push	edi
	mov	edx, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	esi, DWORD PTR [esi+edx]
	bswap	esi
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	edi, DWORD PTR _regs[eax*4+32]
	add	edi, 4
	or	ecx, esi
	mov	DWORD PTR _regs[eax*4+32], edi
	mov	eax, 0
	sete	bl
	cmp	ecx, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, bl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8198_0@4 ENDP


_align_func
@op_90fc_0@4 PROC NEAR
	_start_func  'op_90fc_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	shr	ecx, 1
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	sub	ebx, edx
	mov	DWORD PTR _regs[ecx*4+32], ebx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_90fc_0@4 ENDP


_src$76895 = -5
_dst$76896 = -6
_flgn$76904 = -4
_align_func
@op_9028_0@4 PROC NEAR
	_start_func  'op_9028_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	push	esi
	mov	esi, ecx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	add	edx, ebx
	mov	dl, BYTE PTR [edx+ecx]
	mov	bl, BYTE PTR _regs[esi*4]
	movsx	eax, bl
	movsx	ecx, dl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	mov	BYTE PTR _dst$76896[esp+16], bl
	mov	BYTE PTR _src$76895[esp+16], dl
	setl	cl
	xor	ebx, ebx
	mov	BYTE PTR _regs[esi*4], al
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$76904[esp+16], ebx
	mov	eax, DWORD PTR _regs+92
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$76904[esp+16]
	setl	dl
	xor	dl, cl
	xor	bl, cl
	mov	cl, BYTE PTR _dst$76896[esp+16]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$76895[esp+16]
	cmp	dl, cl
	pop	esi
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$76904[esp+12]
	test	ecx, ecx
	setne	dl
	add	eax, 4
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9028_0@4 ENDP


_align_func
@op_46d8_0@4 PROC NEAR
	_start_func  'op_46d8_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	jne	SHORT $L76915
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L76915:
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	dx, WORD PTR [eax+edx]
	add	eax, 2
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	eax, eax
	mov	al, dh
	mov	ah, dl
	mov	WORD PTR _regs+76, ax
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46d8_0@4 ENDP


_align_func
@op_207a_0@4 PROC NEAR
	_start_func  'op_207a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, ebx
	add	edx, eax
	mov	esi, DWORD PTR [edx+esi+2]
	bswap	esi
	shr	ecx, 1
	and	ecx, 7
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_207a_0@4 ENDP


_align_func
@op_91e8_0@4 PROC NEAR
	_start_func  'op_91e8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	esi, ecx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	and	esi, 7
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	mov	ecx, DWORD PTR _regs[esi*4+32]
	sub	ecx, eax
	mov	DWORD PTR _regs[esi*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_91e8_0@4 ENDP


_align_func
@op_3170_0@4 PROC NEAR
	_start_func  'op_3170_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [edi+eax]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	cx, WORD PTR [edx]
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	eax, ecx
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3170_0@4 ENDP


_flgn$76973 = -4
_align_func
@op_9050_0@4 PROC NEAR
	_start_func  'op_9050_0'
	mov	esi, ecx
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	mov	ax, WORD PTR [eax+ecx]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR _regs[esi*4]
	mov	ebp, edx
	movsx	edi, ax
	movsx	ecx, bp
	sub	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	xor	edx, edx
	mov	WORD PTR _regs[esi*4], di
	test	di, di
	setl	dl
	test	di, di
	sete	bl
	test	bp, bp
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$76973[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$76973[esp+20]
	and	bl, dl
	cmp	bp, ax
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _regs+92
	test	ecx, ecx
	setne	dl
	add	eax, 2
	mov	BYTE PTR _regflags+3, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9050_0@4 ENDP


_align_func
@op_c0a8_0@4 PROC NEAR
	_start_func  'op_c0a8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	and	esi, 7
	mov	ecx, DWORD PTR [edx+ecx]
	bswap	ecx
	mov	eax, DWORD PTR _regs[esi*4]
	and	eax, ecx
	mov	ecx, 0
	sete	dl
	cmp	eax, ecx
	mov	DWORD PTR _regs[esi*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c0a8_0@4 ENDP


_align_func
@op_4480_0@4 PROC NEAR
	_start_func  'op_4480_0'
	shr	ecx, 8
	and	ecx, 7
	mov	edi, ecx
	mov	edx, 0
	mov	esi, DWORD PTR _regs[edi*4]
	mov	eax, esi
	neg	eax
	sets	dl
	test	eax, eax
	sete	cl
	test	esi, esi
	mov	BYTE PTR _regflags+1, cl
	mov	DWORD PTR _regs[edi*4], eax
	mov	eax, DWORD PTR _regs+92
	setl	cl
	and	cl, dl
	test	esi, esi
	mov	BYTE PTR _regflags+3, cl
	seta	cl
	test	edx, edx
	setne	dl
	add	eax, 2
	mov	BYTE PTR _regflags+2, cl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4480_0@4 ENDP


_align_func
@op_20fb_0@4 PROC NEAR
	_start_func  'op_20fb_0'
	push	ebx
	mov	ebx, DWORD PTR _regs+96
	push	esi
	shr	ecx, 1
	and	ecx, 7
	add	eax, 2
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	sub	ecx, ebx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	mov	ecx, DWORD PTR _regs[esi*4+32]
	lea	edx, DWORD PTR [ecx+4]
	mov	DWORD PTR _regs[esi*4+32], edx
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20fb_0@4 ENDP


_align_func
@op_e158_0@4 PROC NEAR
	_start_func  'op_e158_0'
	mov	esi, ecx
	shr	ecx, 1
	shr	esi, 8
	and	ecx, 7
	and	esi, 7
	xor	edx, edx
	mov	edi, DWORD PTR _imm8_table[ecx*4]
	mov	ecx, 16					; 00000010H
	mov	dx, WORD PTR _regs[esi*4]
	and	edi, 15					; 0000000fH
	sub	ecx, edi
	mov	eax, edx
	shr	eax, cl
	mov	ecx, edi
	shl	edx, cl
	mov	BYTE PTR _regflags+3, 0
	or	eax, edx
	and	eax, 65535				; 0000ffffH
	mov	cl, al
	mov	WORD PTR _regs[esi*4], ax
	and	cl, 1
	test	ax, ax
	sete	dl
	test	ax, ax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e158_0@4 ENDP


_align_func
@op_d058_0@4 PROC NEAR
	_start_func  'op_d058_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _regs[eax*4+32]
	xor	ebx, ebx
	shr	ecx, 1
	mov	dx, WORD PTR [esi+edx]
	and	ecx, 7
	mov	bl, dh
	add	esi, 2
	mov	bh, dl
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	si, WORD PTR _regs[ecx*4]
	mov	ebp, ebx
	movsx	edi, si
	movsx	eax, bp
	add	edi, eax
	xor	eax, eax
	test	di, di
	setl	al
	test	di, di
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	mov	WORD PTR _regs[ecx*4], di
	setl	dl
	xor	dl, al
	test	bp, bp
	setl	bl
	xor	bl, al
	not	esi
	and	dl, bl
	cmp	si, bp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d058_0@4 ENDP


_flgn$77083 = -4
_align_func
@op_5168_0@4 PROC NEAR
	_start_func  'op_5168_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	mov	edi, DWORD PTR _imm8_table[eax*4]
	mov	ax, WORD PTR [edx+2]
	xor	edx, edx
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	xor	edx, edx
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, ebp
	mov	ax, WORD PTR [ecx+esi]
	mov	dl, ah
	mov	dh, al
	mov	ebp, edx
	movsx	ecx, di
	movsx	eax, bp
	sub	eax, ecx
	xor	ecx, ecx
	test	bp, bp
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	di, di
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$77083[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	di, bp
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$77083[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5168_0@4 ENDP


_align_func
@op_90c0_0@4 PROC NEAR
	_start_func  'op_90c0_0'
	mov	eax, ecx
	shr	ecx, 8
	shr	eax, 1
	and	ecx, 7
	and	eax, 7
	movsx	ecx, WORD PTR _regs[ecx*4]
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, ecx
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_90c0_0@4 ENDP


_align_func
@op_5058_0@4 PROC NEAR
	_start_func  'op_5058_0'
	mov	eax, ecx
	shr	ecx, 1
	shr	eax, 8
	and	ecx, 7
	and	eax, 7
	mov	edi, DWORD PTR _imm8_table[ecx*4]
	mov	ebp, DWORD PTR _regs[eax*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	cx, WORD PTR [ecx+ebp]
	mov	dl, ch
	mov	dh, cl
	lea	ecx, DWORD PTR [ebp+2]
	mov	esi, edx
	mov	DWORD PTR _regs[eax*4+32], ecx
	movsx	eax, di
	movsx	edx, si
	add	eax, edx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	si, si
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, di
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5058_0@4 ENDP


_align_func
@op_4cd0_0@4 PROC NEAR
	_start_func  'op_4cd0_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	dh, al
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	edx, 65535				; 0000ffffH
	mov	eax, edx
	and	eax, 255				; 000000ffH
	shr	edx, 8
	test	eax, eax
	je	SHORT $L109461
	push	ebx
$L77126:
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [esi+ecx]
	bswap	esi
	mov	ebx, DWORD PTR _movem_index1[eax*4]
	mov	eax, DWORD PTR _movem_next[eax*4]
	add	ecx, 4
	test	eax, eax
	mov	DWORD PTR _regs[ebx*4], esi
	jne	SHORT $L77126
	pop	ebx
$L109461:
	test	edx, edx
	je	SHORT $L109464
$L77129:
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [eax+ecx]
	bswap	eax
	mov	esi, DWORD PTR _movem_index1[edx*4]
	mov	edx, DWORD PTR _movem_next[edx*4]
	add	ecx, 4
	test	edx, edx
	mov	DWORD PTR _regs[esi*4+32], eax
	jne	SHORT $L77129
$L109464:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4cd0_0@4 ENDP


_align_func
@op_48d0_0@4 PROC NEAR
	_start_func  'op_48d0_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	push	esi
	mov	dh, al
	mov	eax, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	cl, al
	and	ecx, 255				; 000000ffH
	mov	esi, ecx
	xor	ecx, ecx
	mov	cl, ah
	test	si, si
	mov	eax, ecx
	je	SHORT $L109483
	push	edi
$L77141:
	mov	ecx, esi
	mov	edi, DWORD PTR _MEMBaseDiff
	and	ecx, 65535				; 0000ffffH
	add	edi, edx
	shl	ecx, 2
	mov	esi, DWORD PTR _movem_index1[ecx]
	mov	esi, DWORD PTR _regs[esi*4]
	bswap	esi
	mov	DWORD PTR [edi], esi
	mov	si, WORD PTR _movem_next[ecx]
	add	edx, 4
	test	si, si
	jne	SHORT $L77141
	pop	edi
$L109483:
	test	ax, ax
	je	SHORT $L109486
$L77144:
	mov	esi, DWORD PTR _MEMBaseDiff
	and	eax, 65535				; 0000ffffH
	shl	eax, 2
	add	esi, edx
	mov	ecx, DWORD PTR _movem_index1[eax]
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	bswap	ecx
	mov	DWORD PTR [esi], ecx
	mov	ax, WORD PTR _movem_next[eax]
	add	edx, 4
	test	ax, ax
	jne	SHORT $L77144
$L109486:
	mov	eax, DWORD PTR _regs+92
	pop	esi
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_48d0_0@4 ENDP


_align_func
@op_54c8_0@4 PROC NEAR
	_start_func  'op_54c8_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	si, WORD PTR _regs[ecx*4]
	mov	dh, al
	movsx	eax, BYTE PTR _regflags+2
	test	eax, eax
	je	SHORT $L77156
	lea	eax, DWORD PTR [esi-1]
	test	si, si
	mov	WORD PTR _regs[ecx*4], ax
	je	SHORT $L77156
	movsx	ecx, dx
	mov	edx, DWORD PTR _regs+92
	lea	eax, DWORD PTR [edx+ecx+2]
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L77156:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_54c8_0@4 ENDP


_align_func
@op_b098_0@4 PROC NEAR
	_start_func  'op_b098_0'
	mov	eax, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	edx, DWORD PTR [edx+esi]
	bswap	edx
	mov	esi, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	add	esi, 4
	and	ecx, 7
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	esi, DWORD PTR _regs[ecx*4]
	xor	ecx, ecx
	mov	eax, esi
	sub	eax, edx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L109536
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L109537
$L109536:
	mov	BYTE PTR _regflags+3, 0
$L109537:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b098_0@4 ENDP


_align_func
@op_c00_0@4 PROC NEAR
	_start_func  'op_c00_0'
	shr	ecx, 8
	mov	dl, BYTE PTR [eax+3]
	and	ecx, 7
	xor	ebx, ebx
	mov	cl, BYTE PTR _regs[ecx*4]
	movsx	eax, cl
	movsx	esi, dl
	sub	eax, esi
	test	cl, cl
	setl	bl
	mov	esi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dl, dl
	setl	al
	cmp	eax, esi
	mov	edi, ebx
	je	SHORT $L109547
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L109548
$L109547:
	mov	BYTE PTR _regflags+3, 0
$L109548:
	mov	eax, DWORD PTR _regs+92
	cmp	dl, cl
	seta	cl
	test	edi, edi
	setne	dl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c00_0@4 ENDP


_align_func
@op_20a8_0@4 PROC NEAR
	_start_func  'op_20a8_0'
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	ebx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20a8_0@4 ENDP


_align_func
@op_d050_0@4 PROC NEAR
	_start_func  'op_d050_0'
	mov	esi, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	mov	ax, WORD PTR [eax+ecx]
	xor	ecx, ecx
	mov	di, WORD PTR _regs[esi*4]
	mov	cl, ah
	mov	ch, al
	xor	eax, eax
	movsx	ebp, di
	movsx	edx, cx
	add	ebp, edx
	test	bp, bp
	setl	al
	test	bp, bp
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	mov	WORD PTR _regs[esi*4], bp
	setl	dl
	xor	dl, al
	test	cx, cx
	setl	bl
	xor	bl, al
	not	edi
	and	dl, bl
	cmp	di, cx
	setb	cl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d050_0@4 ENDP


_align_func
@op_3068_0@4 PROC NEAR
	_start_func  'op_3068_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	xor	ebx, ebx
	shr	ecx, 1
	mov	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	add	edx, esi
	and	ecx, 7
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3068_0@4 ENDP


_align_func
@op_b1fc_0@4 PROC NEAR
	_start_func  'op_b1fc_0'
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	shr	ecx, 1
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	mov	eax, esi
	sub	eax, edx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L109589
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L109590
$L109589:
	mov	BYTE PTR _regflags+3, 0
$L109590:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b1fc_0@4 ENDP


_align_func
@op_2150_0@4 PROC NEAR
	_start_func  'op_2150_0'
	push	esi
	mov	esi, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	push	edi
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	edi, DWORD PTR [ecx+edx]
	bswap	edi
	mov	eax, DWORD PTR _regs+92
	mov	cx, WORD PTR [eax+2]
	xor	eax, eax
	cmp	edi, eax
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	edi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 1
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2150_0@4 ENDP


_align_func
@op_317c_0@4 PROC NEAR
	_start_func  'op_317c_0'
	mov	esi, ecx
	xor	edx, edx
	mov	ecx, DWORD PTR _regs+92
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_317c_0@4 ENDP


_dstreg$ = -4
_align_func
@op_680_0@4 PROC NEAR
	_start_func  'op_680_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	shr	ecx, 8
	push	esi
	and	ecx, 7
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	DWORD PTR _dstreg$[ebp], ecx
	mov	esi, DWORD PTR _regs[ecx*4]
	xor	eax, eax
	lea	edx, DWORD PTR [edi+esi]
	test	edx, edx
	setl	al
	test	edx, edx
	sete	cl
	test	edi, edi
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, al
	test	esi, esi
	setl	bl
	xor	bl, al
	not	esi
	and	cl, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, cl
	pop	edi
	setb	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _dstreg$[ebp]
	pop	esi
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs[ecx*4], edx
	mov	eax, DWORD PTR _regs+92
	pop	ebx
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_680_0@4 ENDP


_align_func
@op_c148_0@4 PROC NEAR
	_start_func  'op_c148_0'
	mov	eax, ecx
	shr	ecx, 8
	shr	eax, 1
	and	ecx, 7
	and	eax, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c148_0@4 ENDP


_align_func
@op_d078_0@4 PROC NEAR
	_start_func  'op_d078_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	si, WORD PTR _regs[ecx*4]
	mov	ebp, edx
	movsx	edi, si
	movsx	eax, bp
	add	edi, eax
	xor	eax, eax
	test	di, di
	setl	al
	test	di, di
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	mov	WORD PTR _regs[ecx*4], di
	setl	dl
	xor	dl, al
	test	bp, bp
	setl	bl
	xor	bl, al
	not	esi
	and	dl, bl
	cmp	si, bp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d078_0@4 ENDP


_align_func
@op_207b_0@4 PROC NEAR
	_start_func  'op_207b_0'
	mov	edx, DWORD PTR _regs+96
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	shr	esi, 1
	and	esi, 7
	mov	DWORD PTR _regs[esi*4+32], eax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_207b_0@4 ENDP


_align_func
@op_b088_0@4 PROC NEAR
	_start_func  'op_b088_0'
	mov	eax, ecx
	shr	ecx, 1
	shr	eax, 8
	and	ecx, 7
	and	eax, 7
	mov	esi, DWORD PTR _regs[ecx*4]
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, esi
	xor	ecx, ecx
	sub	eax, edx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L109675
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L109676
$L109675:
	mov	BYTE PTR _regflags+3, 0
$L109676:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b088_0@4 ENDP


_align_func
@op_b190_0@4 PROC NEAR
	_start_func  'op_b190_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	push	ebx
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	eax, DWORD PTR _regs[eax*4]
	mov	edx, DWORD PTR [edx+ecx]
	bswap	edx
	xor	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b190_0@4 ENDP


_align_func
@op_20e8_0@4 PROC NEAR
	_start_func  'op_20e8_0'
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	push	esi
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	and	esi, 7
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	mov	ecx, DWORD PTR _regs[esi*4+32]
	lea	edx, DWORD PTR [ecx+4]
	mov	DWORD PTR _regs[esi*4+32], edx
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20e8_0@4 ENDP


_align_func
@op_e018_0@4 PROC NEAR
	_start_func  'op_e018_0'
	mov	edx, ecx
	shr	ecx, 1
	and	ecx, 7
	shr	edx, 8
	mov	edi, DWORD PTR _imm8_table[ecx*4]
	and	edx, 7
	xor	eax, eax
	and	edi, 7
	mov	al, BYTE PTR _regs[edx*4]
	mov	ecx, 8
	sub	ecx, edi
	mov	esi, eax
	shl	eax, cl
	mov	ecx, edi
	shr	esi, cl
	mov	BYTE PTR _regflags+3, 0
	or	eax, esi
	and	eax, 255				; 000000ffH
	mov	ecx, eax
	mov	BYTE PTR _regs[edx*4], al
	shr	ecx, 7
	and	cl, 1
	test	al, al
	mov	BYTE PTR _regflags+2, cl
	sete	cl
	test	al, al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e018_0@4 ENDP


_align_func
@op_3050_0@4 PROC NEAR
	_start_func  'op_3050_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	xor	ebx, ebx
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3050_0@4 ENDP


_align_func
@op_f438_0@4 PROC NEAR
	_start_func  'op_f438_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L77441
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L77441:
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_f438_0@4 ENDP


_flgn$77462 = -4
_align_func
@op_9168_0@4 PROC NEAR
	_start_func  'op_9168_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	mov	di, WORD PTR _regs[eax*4]
	mov	ax, WORD PTR [edx+2]
	xor	edx, edx
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	xor	edx, edx
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, ebp
	mov	ax, WORD PTR [ecx+esi]
	mov	dl, ah
	mov	dh, al
	mov	ebp, edx
	movsx	eax, bp
	movsx	ecx, di
	sub	eax, ecx
	xor	ecx, ecx
	test	bp, bp
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	di, di
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$77462[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	di, bp
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$77462[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9168_0@4 ENDP


_align_func
@op_21e8_0@4 PROC NEAR
	_start_func  'op_21e8_0'
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	push	esi
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, esi
	mov	esi, DWORD PTR [edx+ecx]
	bswap	esi
	mov	edx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	esi, eax
	mov	cx, WORD PTR [edx+4]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21e8_0@4 ENDP


_align_func
@op_640_0@4 PROC NEAR
	_start_func  'op_640_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	si, WORD PTR _regs[ecx*4]
	mov	ebp, edx
	movsx	edi, si
	movsx	eax, bp
	add	edi, eax
	xor	eax, eax
	test	di, di
	setl	al
	test	di, di
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	mov	WORD PTR _regs[ecx*4], di
	setl	dl
	xor	dl, al
	test	bp, bp
	setl	bl
	xor	bl, al
	not	esi
	and	dl, bl
	cmp	si, bp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_640_0@4 ENDP


_align_func
@op_e8c0_0@4 PROC NEAR
	_start_func  'op_e8c0_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	dh, al
	mov	esi, ecx
	mov	ecx, edx
	movsx	eax, dx
	and	ecx, 2048				; 00000800H
	test	cx, cx
	mov	ecx, eax
	je	SHORT $L109770
	sar	ecx, 6
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	jmp	SHORT $L109771
$L109770:
	sar	ecx, 6
	and	ecx, 31					; 0000001fH
$L109771:
	test	dl, 32					; 00000020H
	je	SHORT $L109773
	and	eax, 7
	mov	eax, DWORD PTR _regs[eax*4]
$L109773:
	mov	edx, DWORD PTR _regs[esi*4]
	dec	eax
	and	ecx, 31					; 0000001fH
	and	eax, 31					; 0000001fH
	shl	edx, cl
	inc	eax
	mov	ecx, 32					; 00000020H
	sub	ecx, eax
	shr	edx, cl
	lea	ecx, DWORD PTR [eax-1]
	mov	eax, 1
	shl	eax, cl
	test	eax, edx
	setne	cl
	xor	eax, eax
	mov	BYTE PTR _regflags, cl
	cmp	edx, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+2, al
	mov	eax, DWORD PTR _regs+92
	sete	dl
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e8c0_0@4 ENDP


_align_func
@op_303c_0@4 PROC NEAR
	_start_func  'op_303c_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	WORD PTR _regs[ecx*4], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_303c_0@4 ENDP


_align_func
@op_8000_0@4 PROC NEAR
	_start_func  'op_8000_0'
	mov	eax, ecx
	shr	eax, 1
	shr	ecx, 8
	and	eax, 7
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	dl, BYTE PTR _regs[eax*4]
	or	cl, dl
	mov	dl, 0
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regs[eax*4], cl
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8000_0@4 ENDP


_align_func
@op_30f0_0@4 PROC NEAR
	_start_func  'op_30f0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	ax, WORD PTR [edi+eax]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	lea	edx, DWORD PTR [ecx+2]
	mov	DWORD PTR _regs[esi*4+32], edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	WORD PTR [edi+ecx], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30f0_0@4 ENDP


_align_func
@op_4440_0@4 PROC NEAR
	_start_func  'op_4440_0'
	shr	ecx, 8
	and	ecx, 7
	mov	edi, ecx
	xor	edx, edx
	mov	si, WORD PTR _regs[edi*4]
	movsx	eax, si
	neg	eax
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	cl
	test	si, si
	mov	BYTE PTR _regflags+1, cl
	mov	WORD PTR _regs[edi*4], ax
	mov	eax, DWORD PTR _regs+92
	setl	cl
	and	cl, dl
	test	si, si
	mov	BYTE PTR _regflags+3, cl
	seta	cl
	test	edx, edx
	setne	dl
	add	eax, 2
	mov	BYTE PTR _regflags+2, cl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4440_0@4 ENDP


_align_func
@op_44c0_0@4 PROC NEAR
	_start_func  'op_44c0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	bx, WORD PTR _regs[ecx*4]
	call	_MakeSR@0
	mov	al, BYTE PTR _regs+76
	xor	al, bl
	and	eax, 255				; 000000ffH
	xor	WORD PTR _regs+76, ax
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44c0_0@4 ENDP


_align_func
@op_56c8_0@4 PROC NEAR
	_start_func  'op_56c8_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	si, WORD PTR _regs[ecx*4]
	mov	dh, al
	movsx	eax, BYTE PTR _regflags+1
	test	eax, eax
	je	SHORT $L77589
	lea	eax, DWORD PTR [esi-1]
	test	si, si
	mov	WORD PTR _regs[ecx*4], ax
	je	SHORT $L77589
	movsx	ecx, dx
	mov	edx, DWORD PTR _regs+92
	lea	eax, DWORD PTR [edx+ecx+2]
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L77589:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_56c8_0@4 ENDP


_align_func
@op_30b8_0@4 PROC NEAR
	_start_func  'op_30b8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	ax, WORD PTR [edx+esi]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	ecx, 1
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	BYTE PTR _regflags+1, bl
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30b8_0@4 ENDP


_align_func
@op_1168_0@4 PROC NEAR
	_start_func  'op_1168_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	xor	bl, bl
	mov	edi, DWORD PTR _regs[eax*4+32]
	add	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [edx+edi]
	mov	dx, WORD PTR [esi+4]
	cmp	al, bl
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+3, bl
	sete	bl
	test	al, al
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	mov	BYTE PTR _regflags, bl
	xor	ebx, ebx
	mov	bl, dh
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 1
	and	ecx, 7
	or	esi, edx
	add	esi, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [esi+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1168_0@4 ENDP


_align_func
@op_b018_0@4 PROC NEAR
	_start_func  'op_b018_0'
	mov	eax, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	mov	edi, DWORD PTR _regs[eax*4+32]
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	xor	ebx, ebx
	mov	dl, BYTE PTR [edi+edx]
	add	eax, edi
	shr	ecx, 1
	and	ecx, 7
	mov	DWORD PTR [esi], eax
	movsx	esi, dl
	mov	cl, BYTE PTR _regs[ecx*4]
	movsx	eax, cl
	sub	eax, esi
	test	cl, cl
	setl	bl
	mov	esi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dl, dl
	setl	al
	cmp	eax, esi
	mov	edi, ebx
	je	SHORT $L109905
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L109906
$L109905:
	mov	BYTE PTR _regflags+3, 0
$L109906:
	mov	eax, DWORD PTR _regs+92
	cmp	dl, cl
	seta	cl
	test	edi, edi
	setne	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b018_0@4 ENDP


_align_func
@op_b1f8_0@4 PROC NEAR
	_start_func  'op_b1f8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	shr	ecx, 1
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	mov	eax, esi
	sub	eax, edx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L109915
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L109916
$L109915:
	mov	BYTE PTR _regflags+3, 0
$L109916:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b1f8_0@4 ENDP


_align_func
@op_6901_0@4 PROC NEAR
	_start_func  'op_6901_0'
	mov	dl, BYTE PTR _regflags+3
	xor	eax, eax
	shr	ecx, 8
	test	dl, dl
	sete	al
	test	eax, eax
	mov	eax, DWORD PTR _regs+92
	movsx	ecx, cl
	je	SHORT $L77676
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L77676:
	lea	ecx, DWORD PTR [eax+ecx+2]
	mov	DWORD PTR _regs+92, ecx
	mov	eax,ecx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_6901_0@4 ENDP


_align_func
@op_b1fa_0@4 PROC NEAR
	_start_func  'op_b1fa_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	edi, DWORD PTR _regs+88
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	sub	edx, DWORD PTR _regs+96
	add	edx, ebx
	add	edx, edi
	mov	edx, DWORD PTR [edx+esi+2]
	bswap	edx
	shr	ecx, 1
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	mov	eax, esi
	sub	eax, edx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L109972
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L109973
$L109972:
	mov	BYTE PTR _regflags+3, 0
$L109973:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b1fa_0@4 ENDP


_align_func
@op_e168_0@4 PROC NEAR
	_start_func  'op_e168_0'
	mov	edx, ecx
	xor	eax, eax
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+2, 0
	shr	edx, 8
	mov	cl, BYTE PTR _regs[ecx*4]
	and	edx, 7
	and	ecx, 63					; 0000003fH
	mov	BYTE PTR _regflags+3, 0
	mov	ax, WORD PTR _regs[edx*4]
	cmp	cx, 16					; 00000010H
	jl	SHORT $L77716
	jne	SHORT $L109990
	and	al, 1
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L77718
$L109990:
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L77718
$L77716:
	test	cx, cx
	jle	SHORT $L77718
	dec	ecx
	shl	eax, cl
	mov	ecx, eax
	and	eax, 32767				; 00007fffH
	shr	ecx, 15					; 0000000fH
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shl	eax, 1
$L77718:
	test	ax, ax
	sete	cl
	test	ax, ax
	mov	WORD PTR _regs[edx*4], ax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e168_0@4 ENDP


_align_func
@op_56c0_0@4 PROC NEAR
	_start_func  'op_56c0_0'
	mov	dl, BYTE PTR _regflags+1
	xor	eax, eax
	shr	ecx, 8
	and	ecx, 7
	test	dl, dl
	sete	al
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_56c0_0@4 ENDP


_align_func
@op_d168_0@4 PROC NEAR
	_start_func  'op_d168_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	mov	bp, WORD PTR _regs[eax*4]
	mov	ax, WORD PTR [edx+2]
	xor	edx, edx
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	xor	edx, edx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, eax
	mov	ax, WORD PTR [ecx+esi]
	mov	dl, ah
	mov	dh, al
	mov	edi, edx
	movsx	eax, di
	movsx	ecx, bp
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	bp, bp
	setl	bl
	xor	bl, cl
	not	edi
	and	dl, bl
	cmp	di, bp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d168_0@4 ENDP


_align_func
@op_200_0@4 PROC NEAR
	_start_func  'op_200_0'
	shr	ecx, 8
	mov	al, BYTE PTR [eax+3]
	and	ecx, 7
	mov	dl, BYTE PTR _regs[ecx*4]
	and	al, dl
	mov	dl, 0
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 4
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_200_0@4 ENDP


_align_func
@op_c58_0@4 PROC NEAR
	_start_func  'op_c58_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	edi, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ebp, DWORD PTR _regs[edi*4+32]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR [ecx+ebp]
	xor	ecx, ecx
	mov	cl, ah
	add	ebp, 2
	mov	ch, al
	mov	DWORD PTR _regs[edi*4+32], ebp
	mov	esi, ecx
	movsx	eax, si
	movsx	ecx, dx
	sub	eax, ecx
	xor	ecx, ecx
	test	si, si
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dx, dx
	setl	al
	cmp	eax, edi
	je	SHORT $L110058
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L110059
$L110058:
	mov	BYTE PTR _regflags+3, 0
$L110059:
	cmp	dx, si
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c58_0@4 ENDP


_align_func
@op_4a50_0@4 PROC NEAR
	_start_func  'op_4a50_0'
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [eax+ecx]
	xor	ecx, ecx
	mov	dl, ah
	mov	BYTE PTR _regflags+2, cl
	mov	dh, al
	mov	BYTE PTR _regflags+3, cl
	mov	eax, edx
	cmp	ax, cx
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a50_0@4 ENDP


_align_func
@op_d0fc_0@4 PROC NEAR
	_start_func  'op_d0fc_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	shr	ecx, 1
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	add	ebx, edx
	mov	DWORD PTR _regs[ecx*4+32], ebx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d0fc_0@4 ENDP


_align_func
@op_5068_0@4 PROC NEAR					;ADD TODO
	_start_func  'op_5068_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	mov	ebp, DWORD PTR _imm8_table[eax*4]
	mov	ax, WORD PTR [edx+2]
	xor	edx, edx
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	xor	edx, edx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, eax
	mov	ax, WORD PTR [ecx+esi]
	mov	dl, ah
	mov	dh, al
	mov	edi, edx
	movsx	eax, bp
	movsx	ecx, di
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	bp, bp
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	di, di
	setl	bl
	xor	bl, cl
	not	edi
	and	dl, bl
	cmp	di, bp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5068_0@4 ENDP


_flgn$77849 = -8
_x$110111 = -4
_align_func
@op_91a8_0@4 PROC NEAR
	_start_func  'op_91a8_0'
	mov	ebp, esp
	sub	esp, 8
	mov	edx, eax
	push	ebx
	xor	ebx, ebx
	push	esi
	mov	dx, WORD PTR [edx+2]
	mov	eax, ecx
	mov	bl, dh
	push	edi
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 8
	and	ecx, 7
	or	esi, edx
	shr	eax, 1
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, edx
	and	eax, 7
	mov	edx, DWORD PTR [ecx+esi]
	bswap	edx
	mov	eax, DWORD PTR _regs[eax*4]
	mov	DWORD PTR _x$110111[ebp], edx
	mov	edi, edx
	xor	ecx, ecx
	sub	edi, eax
	test	edx, edx
	setl	cl
	xor	edx, edx
	test	edi, edi
	setl	dl
	test	edi, edi
	sete	bl
	test	eax, eax
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$77849[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$77849[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _x$110111[ebp]
	mov	BYTE PTR _regflags+3, bl
	cmp	eax, edx
	seta	al
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _MEMBaseDiff
	setne	dl
	mov	BYTE PTR _regflags, dl
	add	esi, eax
	bswap	edi
	mov	DWORD PTR [esi], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_91a8_0@4 ENDP


_align_func
@op_4ee8_0@4 PROC NEAR
	_start_func  'op_4ee8_0'
	mov	esi, ecx
	xor	edx, edx
	mov	cx, WORD PTR [eax+2]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	eax, ecx
	shr	esi, 8
	and	esi, 7
	mov	ecx, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	mov	DWORD PTR _regs+88, eax
	lea	ecx, DWORD PTR [edx+eax]
	mov	DWORD PTR _regs+96, ecx
	mov	DWORD PTR _regs+92, ecx
	mov	eax,ecx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ee8_0@4 ENDP


_newv$77870 = -4
_align_func
@op_d0b0_0@4 PROC NEAR
	_start_func  'op_d0b0_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	add	eax, 2
	push	esi
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	push	edi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	mov	edi, DWORD PTR _regs[esi*4]
	xor	eax, eax
	lea	edx, DWORD PTR [ecx+edi]
	test	edx, edx
	setl	al
	test	edx, edx
	mov	DWORD PTR _newv$77870[ebp], edx
	sete	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, al
	test	edi, edi
	setl	bl
	xor	bl, al
	not	edi
	and	dl, bl
	cmp	edi, ecx
	setb	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _newv$77870[ebp]
	pop	edi
	test	eax, eax
	setne	al
	mov	DWORD PTR _regs[esi*4], ecx
	mov	BYTE PTR _regflags, al
	pop	esi
	mov	BYTE PTR _regflags+3, dl
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d0b0_0@4 ENDP


_align_func
@op_d158_0@4 PROC NEAR
	_start_func  'op_d158_0'
	mov	eax, ecx
	shr	ecx, 1
	shr	eax, 8
	and	ecx, 7
	and	eax, 7
	mov	di, WORD PTR _regs[ecx*4]
	mov	ebp, DWORD PTR _regs[eax*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	cx, WORD PTR [ecx+ebp]
	mov	dl, ch
	mov	dh, cl
	lea	ecx, DWORD PTR [ebp+2]
	mov	esi, edx
	mov	DWORD PTR _regs[eax*4+32], ecx
	movsx	eax, si
	movsx	edx, di
	add	eax, edx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	di, di
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, di
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d158_0@4 ENDP


_align_func
@op_4eb0_0@4 PROC NEAR
	_start_func  'op_4eb0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	mov	edi, DWORD PTR _regs+92
	sub	ecx, edx
	add	ecx, edi
	mov	edx, DWORD PTR _regs+60
	mov	esi, ecx
	mov	edi, ecx
	and	esi, 16711680				; 00ff0000H
	sub	edx, 4
	shr	edi, 16					; 00000010H
	or	esi, edi
	mov	edi, ecx
	and	edi, 65280				; 0000ff00H
	mov	DWORD PTR _regs+60, edx
	shl	ecx, 16					; 00000010H
	or	edi, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	shr	esi, 8
	shl	edi, 8
	or	esi, edi
	mov	DWORD PTR [ecx+edx], esi
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _regs+88, eax
	lea	ecx, DWORD PTR [edx+eax]
	mov	DWORD PTR _regs+96, ecx
	mov	DWORD PTR _regs+92, ecx
	mov	eax,ecx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4eb0_0@4 ENDP


_align_func
@op_b070_0@4 PROC NEAR
	_start_func  'op_b070_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	shr	esi, 1
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	and	esi, 7
	mov	cl, ah
	mov	ch, al
	mov	si, WORD PTR _regs[esi*4]
	movsx	eax, si
	movsx	edx, cx
	sub	eax, edx
	xor	edx, edx
	test	si, si
	setl	dl
	mov	edi, edx
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	cx, cx
	setl	al
	cmp	eax, edi
	je	SHORT $L110201
	cmp	edx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L110202
$L110201:
	mov	BYTE PTR _regflags+3, 0
$L110202:
	cmp	cx, si
	seta	cl
	test	edx, edx
	setne	dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b070_0@4 ENDP


_align_func
@op_4298_0@4 PROC NEAR
	_start_func  'op_4298_0'
	shr	ecx, 8
	and	ecx, 7
	mov	BYTE PTR _regflags+1, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	lea	edx, DWORD PTR [eax+4]
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	add	eax, edx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags, cl
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4298_0@4 ENDP


_align_func
@op_2120_0@4 PROC NEAR
	_start_func  'op_2120_0'
	mov	eax, ecx
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	sub	edx, 4
	mov	esi, DWORD PTR [esi+edx]
	bswap	esi
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2120_0@4 ENDP


_align_func
@op_e008_0@4 PROC NEAR
	_start_func  'op_e008_0'
	mov	edx, ecx
	xor	eax, eax
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+3, 0
	shr	edx, 8
	mov	ecx, DWORD PTR _imm8_table[ecx*4]
	and	edx, 7
	and	ecx, 63					; 0000003fH
	mov	al, BYTE PTR _regs[edx*4]
	cmp	ecx, 8
	jb	SHORT $L77962
	shr	eax, 7
	cmp	ecx, 8
	sete	cl
	and	al, cl
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L77963
$L77962:
	dec	ecx
	shr	eax, cl
	mov	cl, al
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shr	eax, 1
$L77963:
	test	al, al
	sete	cl
	test	al, al
	mov	BYTE PTR _regs[edx*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e008_0@4 ENDP


_align_func
@op_c188_0@4 PROC NEAR
	_start_func  'op_c188_0'
	mov	eax, ecx
	shr	ecx, 8
	shr	eax, 1
	and	ecx, 7
	and	eax, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _regs[eax*4]
	mov	DWORD PTR _regs[eax*4], esi
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c188_0@4 ENDP


_align_func
@op_303b_0@4 PROC NEAR
	_start_func  'op_303b_0'
	mov	edx, DWORD PTR _regs+96
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	mov	dl, ah
	mov	BYTE PTR _regflags+2, cl
	mov	dh, al
	mov	BYTE PTR _regflags+3, cl
	mov	eax, edx
	cmp	ax, cx
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	shr	esi, 1
	and	esi, 7
	mov	BYTE PTR _regflags, cl
	mov	WORD PTR _regs[esi*4], ax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_303b_0@4 ENDP


;LAST_align_func

_align_func
@op_e010_0@4 PROC NEAR
	_start_func  'op_e010_0'
	mov	esi, ecx
	shr	esi, 8
	shr	ecx, 1
	and	esi, 7
	and	ecx, 7
	xor	eax, eax
	mov	al, BYTE PTR _regs[esi*4]
	mov	edi, DWORD PTR _imm8_table[ecx*4]
	movsx	ecx, BYTE PTR _regflags+4
	lea	edx, DWORD PTR [eax+eax]
	and	edi, 63					; 0000003fH
	or	edx, ecx
	dec	edi
	mov	ecx, 7
	mov	BYTE PTR _regflags+3, 0
	sub	ecx, edi
	shl	edx, cl
	mov	ecx, edi
	shr	eax, cl
	and	edx, 255				; 000000ffH
	mov	cl, al
	shr	eax, 1
	and	eax, 255				; 000000ffH
	and	cl, 1
	or	eax, edx
	mov	BYTE PTR _regflags+4, cl
	test	al, al
	sete	dl
	test	al, al
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e010_0@4 ENDP


@op_203c_0@4 PROC NEAR
	_start_func  'op_203c_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_203c_0@4 ENDP


@op_6801_0@4 PROC NEAR
	_start_func  'op_6801_0'
	movsx	eax, BYTE PTR _regflags+3
	shr	ecx, 8
	test	eax, eax
	mov	eax, DWORD PTR _regs+92
	movsx	ecx, cl
	je	SHORT $L78025
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L78025:
	lea	ecx, DWORD PTR [eax+ecx+2]
	mov	DWORD PTR _regs+92, ecx
	mov	eax,ecx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_6801_0@4 ENDP


@op_50e8_0@4 PROC NEAR
	_start_func  'op_50e8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, edx
	mov	BYTE PTR [ecx+esi], 255			; 000000ffH
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_50e8_0@4 ENDP


@op_4c00_0@4 PROC NEAR
	_start_func  'op_4c00_0'
	mov	edx, eax
	mov	esi, ecx
	mov	ax, WORD PTR [edx+2]
	add	edx, 4
	shr	esi, 8
	and	esi, 7
	mov	esi, DWORD PTR _regs[esi*4]
	mov	DWORD PTR _regs+92, edx
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	push	edx
	push	esi
	push	ecx
	call	_m68k_mull@12
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4c00_0@4 ENDP


@op_4400_0@4 PROC NEAR
	_start_func  'op_4400_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, ecx
	xor	edx, edx
	mov	cl, BYTE PTR _regs[esi*4]
	movsx	eax, cl
	neg	eax
	test	al, al
	setl	dl
	test	al, al
	sete	bl
	test	cl, cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	setl	bl
	and	bl, dl
	test	cl, cl
	seta	cl
	test	edx, edx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	setne	cl
	add	eax, 2
	mov	BYTE PTR _regflags+3, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4400_0@4 ENDP


@op_b198_0@4 PROC NEAR
	_start_func  'op_b198_0'
	mov	eax, ecx
	push	ebx
	shr	eax, 8
	and	eax, 7
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	push	edi
	mov	edx, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	esi, DWORD PTR [esi+edx]
	bswap	esi
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	edi, DWORD PTR _regs[eax*4+32]
	add	edi, 4
	xor	ecx, esi
	mov	DWORD PTR _regs[eax*4+32], edi
	mov	eax, 0
	sete	bl
	cmp	ecx, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, bl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b198_0@4 ENDP


@op_3080_0@4 PROC NEAR
	_start_func  'op_3080_0'
	mov	eax, ecx
	xor	edx, edx
	shr	eax, 8
	and	eax, 7
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	ax, WORD PTR _regs[eax*4]
	cmp	ax, dx
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	ecx, 1
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3080_0@4 ENDP


@op_2130_0@4 PROC NEAR
	_start_func  'op_2130_0'
	push	ebx
	add	eax, 2
	push	esi
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	mov	eax, DWORD PTR _regs[esi*4+32]
	xor	edx, edx
	sub	eax, 4
	cmp	ecx, edx
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	DWORD PTR _regs[esi*4+32], eax
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2130_0@4 ENDP


@op_e100_0@4 PROC NEAR
	_start_func  'op_e100_0'
	mov	edi, ecx
	xor	eax, eax
	shr	ecx, 1
	and	ecx, 7
	shr	edi, 8
	mov	esi, DWORD PTR _imm8_table[ecx*4]
	and	edi, 7
	and	esi, 63					; 0000003fH
	mov	al, BYTE PTR _regs[edi*4]
	cmp	esi, 8
	jb	SHORT $L78116
	test	eax, eax
	setne	cl
	cmp	esi, 8
	mov	BYTE PTR _regflags+3, cl
	jne	SHORT $L110422
	and	al, 1
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L78117
$L110422:
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L78117
$L78116:
	mov	ecx, 7
	mov	edx, 255				; 000000ffH
	sub	ecx, esi
	shl	edx, cl
	and	edx, 255				; 000000ffH
	mov	ecx, edx
	and	ecx, eax
	cmp	ecx, edx
	je	SHORT $L110424
	test	ecx, ecx
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L110425
$L110424:
	mov	BYTE PTR _regflags+3, 0
$L110425:
	lea	ecx, DWORD PTR [esi-1]
	shl	eax, cl
	mov	ecx, eax
	and	eax, 127				; 0000007fH
	shr	ecx, 7
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shl	eax, 1
$L78117:
	test	al, al
	sete	dl
	test	al, al
	mov	BYTE PTR _regs[edi*4], al
	mov	eax, DWORD PTR _regs+92
	setl	cl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e100_0@4 ENDP


@op_4850_0@4 PROC NEAR
	_start_func  'op_4850_0'
	mov	eax, DWORD PTR _regs+60
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	add	eax, -4					; fffffffcH
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	DWORD PTR _regs+60, eax
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4850_0@4 ENDP


@op_1178_0@4 PROC NEAR
	_start_func  'op_1178_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	xor	bl, bl
	mov	al, BYTE PTR [edx+edi]
	mov	dx, WORD PTR [esi+4]
	cmp	al, bl
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+3, bl
	sete	bl
	test	al, al
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	mov	BYTE PTR _regflags, bl
	xor	ebx, ebx
	mov	bl, dh
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 1
	and	ecx, 7
	or	esi, edx
	add	esi, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [esi+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1178_0@4 ENDP


@op_21d8_0@4 PROC NEAR
	_start_func  'op_21d8_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	push	esi
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR [eax+edx]
	bswap	esi
	mov	eax, DWORD PTR _regs[ecx*4+32]
	add	eax, 4
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	eax, DWORD PTR _regs+92
	mov	cx, WORD PTR [eax+2]
	xor	eax, eax
	cmp	esi, eax
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21d8_0@4 ENDP


_dstreg$ = -8
_flgn$78176 = -4
@op_480_0@4 PROC NEAR
	_start_func  'op_480_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	shr	ecx, 8
	push	esi
	and	ecx, 7
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	DWORD PTR _dstreg$[ebp], ecx
	mov	eax, DWORD PTR _regs[ecx*4]
	xor	ecx, ecx
	mov	esi, eax
	sub	esi, edi
	test	eax, eax
	setl	cl
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	edi, edi
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$78176[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$78176[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _dstreg$[ebp]
	cmp	edi, eax
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	test	ecx, ecx
	mov	DWORD PTR _regs[edx*4], esi
	mov	eax, DWORD PTR _regs+92
	setne	cl
	add	eax, 6
	pop	edi
	mov	BYTE PTR _regflags+3, bl
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	BYTE PTR _regflags, cl
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_480_0@4 ENDP


@op_1100_0@4 PROC NEAR
	_start_func  'op_1100_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	shr	ecx, 8
	mov	edx, DWORD PTR _regs[eax*4+32]
	lea	esi, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	mov	edi, DWORD PTR _areg_byteinc[eax*4]
	xor	al, al
	mov	cl, BYTE PTR _regs[ecx*4]
	sub	edx, edi
	cmp	cl, al
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	cl, al
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR [esi], edx
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [eax+edx], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1100_0@4 ENDP


@op_e198_0@4 PROC NEAR
	_start_func  'op_e198_0'
	mov	edx, ecx
	shr	ecx, 1
	shr	edx, 8
	and	ecx, 7
	and	edx, 7
	mov	BYTE PTR _regflags+3, 0
	mov	edi, DWORD PTR _imm8_table[ecx*4]
	mov	ecx, 32					; 00000020H
	mov	esi, DWORD PTR _regs[edx*4]
	and	edi, 31					; 0000001fH
	sub	ecx, edi
	mov	eax, esi
	shr	eax, cl
	mov	ecx, edi
	shl	esi, cl
	or	eax, esi
	mov	cl, al
	mov	DWORD PTR _regs[edx*4], eax
	and	cl, 1
	test	eax, eax
	mov	BYTE PTR _regflags+2, cl
	sete	cl
	test	eax, eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e198_0@4 ENDP


@op_c50_0@4 PROC NEAR
	_start_func  'op_c50_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	esi, ecx
	movsx	eax, si
	movsx	ecx, dx
	sub	eax, ecx
	xor	ecx, ecx
	test	si, si
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dx, dx
	setl	al
	cmp	eax, edi
	je	SHORT $L110510
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L110511
$L110510:
	mov	BYTE PTR _regflags+3, 0
$L110511:
	cmp	dx, si
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c50_0@4 ENDP


@op_2090_0@4 PROC NEAR
	_start_func  'op_2090_0'
	mov	eax, ecx
	push	ebx
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2090_0@4 ENDP


@op_830_0@4 PROC NEAR
	_start_func  'op_830_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, bh
	mov	al, BYTE PTR [edx+eax]
	and	cl, 7
	shr	al, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_830_0@4 ENDP


@op_56e8_0@4 PROC NEAR
	_start_func  'op_56e8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	xor	eax, eax
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	cl, BYTE PTR _regflags+1
	add	esi, edx
	test	cl, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	sete	al
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR [ecx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_56e8_0@4 ENDP


@op_4258_0@4 PROC NEAR
	_start_func  'op_4258_0'
	shr	ecx, 8
	and	ecx, 7
	mov	BYTE PTR _regflags+1, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	lea	edx, DWORD PTR [eax+2]
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags, cl
	mov	WORD PTR [edx+eax], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4258_0@4 ENDP


@op_4a70_0@4 PROC NEAR
	_start_func  'op_4a70_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	mov	dl, ah
	mov	BYTE PTR _regflags+2, cl
	mov	dh, al
	mov	BYTE PTR _regflags+3, cl
	mov	eax, edx
	cmp	ax, cx
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a70_0@4 ENDP


@op_d1e8_0@4 PROC NEAR
	_start_func  'op_d1e8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	esi, ecx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	and	esi, 7
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	mov	ecx, DWORD PTR _regs[esi*4+32]
	add	ecx, eax
	mov	DWORD PTR _regs[esi*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d1e8_0@4 ENDP


_src$78317 = -4
_dst$78318 = -9
_flgn$78326 = -8
@op_5100_0@4 PROC NEAR
	_start_func  'op_5100_0'
	push	esi
	mov	esi, ecx
	shr	esi, 8
	shr	ecx, 1
	and	esi, 7
	and	ecx, 7
	mov	ecx, DWORD PTR _imm8_table[ecx*4]
	mov	bl, BYTE PTR _regs[esi*4]
	movsx	edx, cl
	movsx	eax, bl
	sub	eax, edx
	xor	edx, edx
	test	bl, bl
	mov	BYTE PTR _dst$78318[esp+20], bl
	mov	DWORD PTR _src$78317[esp+20], ecx
	setl	dl
	xor	ebx, ebx
	mov	BYTE PTR _regs[esi*4], al
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$78326[esp+20], ebx
	mov	eax, DWORD PTR _regs+92
	sete	bl
	test	cl, cl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$78326[esp+20]
	setl	cl
	xor	cl, dl
	xor	bl, dl
	mov	dl, BYTE PTR _dst$78318[esp+20]
	and	cl, bl
	mov	bl, BYTE PTR _src$78317[esp+20]
	mov	BYTE PTR _regflags+3, cl
	cmp	bl, dl
	pop	esi
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$78326[esp+16]
	test	ecx, ecx
	setne	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5100_0@4 ENDP


@op_1080_0@4 PROC NEAR
	_start_func  'op_1080_0'
	mov	eax, ecx
	xor	dl, dl
	shr	eax, 8
	and	eax, 7
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	al, BYTE PTR _regs[eax*4]
	cmp	al, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [ecx+edx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1080_0@4 ENDP


@op_3150_0@4 PROC NEAR
	_start_func  'op_3150_0'
	mov	esi, ecx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	xor	edx, edx
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	ax, WORD PTR [ecx+edi]
	mov	ecx, DWORD PTR _regs+92
	mov	dl, ah
	mov	dh, al
	mov	cx, WORD PTR [ecx+2]
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	eax, ecx
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3150_0@4 ENDP


@op_3180_0@4 PROC NEAR
	_start_func  'op_3180_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	bx, WORD PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3180_0@4 ENDP


@op_1090_0@4 PROC NEAR
	_start_func  'op_1090_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	al, BYTE PTR [edx+esi]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [ecx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1090_0@4 ENDP


@op_80fc_0@4 PROC NEAR
	_start_func  'op_80fc_0'
	shr	ecx, 1
	and	ecx, 7
	mov	ebp, ecx
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	edi, DWORD PTR _regs[ebp*4]
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	test	si, si
	jne	SHORT $L78394
	mov	eax, DWORD PTR _regs+88
	mov	esi, DWORD PTR _regs+96
	sub	eax, esi
	add	eax, ecx
	push	eax
	push	5
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L78394:
	and	esi, 65535				; 0000ffffH
	mov	eax, edi
	xor	edx, edx
	div	esi
	mov	ecx, eax
	cmp	ecx, 65535				; 0000ffffH
	jbe	SHORT $L78408
	mov	al, 1
	mov	BYTE PTR _regflags+2, 0
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	jmp	SHORT $L78407
$L78408:
	test	cx, cx
	sete	dl
	test	cx, cx
	setl	al
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, al
	mov	eax, edi
	xor	edx, edx
	div	esi
	and	ecx, 65535				; 0000ffffH
	mov	BYTE PTR _regflags+2, 0
	mov	BYTE PTR _regflags+3, 0
	shl	edx, 16					; 00000010H
	or	edx, ecx
	mov	DWORD PTR _regs[ebp*4], edx
$L78407:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_80fc_0@4 ENDP


@op_b108_0@4 PROC NEAR
	_start_func  'op_b108_0'
	mov	eax, ecx
	shr	eax, 8
	mov	ebx, DWORD PTR _MEMBaseDiff
	and	eax, 7
	mov	edi, DWORD PTR _regs[eax*4+32]
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	dl, BYTE PTR [edi+ebx]
	add	eax, edi
	shr	ecx, 1
	and	ecx, 7
	mov	DWORD PTR [esi], eax
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	bl, BYTE PTR [esi+ebx]
	add	ecx, esi
	mov	DWORD PTR [eax], ecx
	movsx	eax, bl
	movsx	ecx, dl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	setl	cl
	mov	esi, ecx
	xor	ecx, ecx
	test	al, al
	setl	cl
	test	al, al
	mov	edi, ecx
	sete	al
	xor	ecx, ecx
	mov	BYTE PTR _regflags+1, al
	test	dl, dl
	setl	cl
	cmp	ecx, esi
	je	SHORT $L110713
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L110714
$L110713:
	mov	BYTE PTR _regflags+3, 0
$L110714:
	cmp	dl, bl
	seta	dl
	test	edi, edi
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b108_0@4 ENDP


@op_3040_0@4 PROC NEAR
	_start_func  'op_3040_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	movsx	edx, WORD PTR _regs[eax*4]
	and	ecx, 7
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3040_0@4 ENDP


@op_91c0_0@4 PROC NEAR
	_start_func  'op_91c0_0'
	mov	eax, ecx
	shr	eax, 1
	shr	ecx, 8
	and	eax, 7
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, ecx
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_91c0_0@4 ENDP


@op_1128_0@4 PROC NEAR
	_start_func  'op_1128_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	and	esi, 7
	add	edx, eax
	mov	eax, DWORD PTR _regs[esi*4+32]
	mov	ebx, DWORD PTR _areg_byteinc[esi*4]
	mov	cl, BYTE PTR [edx+edi]
	lea	edx, DWORD PTR _regs[esi*4+32]
	sub	eax, ebx
	mov	DWORD PTR [edx], eax
	xor	dl, dl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1128_0@4 ENDP


@op_1158_0@4 PROC NEAR
	_start_func  'op_1158_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	xor	bl, bl
	mov	edi, DWORD PTR [esi]
	add	eax, edi
	mov	dl, BYTE PTR [edi+ebp]
	mov	DWORD PTR [esi], eax
	mov	eax, DWORD PTR _regs+92
	cmp	dl, bl
	mov	ax, WORD PTR [eax+2]
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+3, bl
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	mov	BYTE PTR _regflags, bl
	xor	ebx, ebx
	mov	bl, ah
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, al
	shr	ecx, 1
	movsx	eax, bx
	and	ecx, 7
	or	esi, eax
	mov	edi, DWORD PTR _regs[ecx*4+32]
	add	esi, edi

	;add	esi, ebp
	;RCHECK esi										;MAC_BOOT_FIX
	;mov	BYTE PTR [esi], dl

	mov	BYTE PTR [esi+ebp], dl

	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1158_0@4 ENDP


_src$78489 = -8
_newv$78491 = -4
@op_5000_0@4 PROC NEAR
	_start_func  'op_5000_0'
	mov	esi, ecx
	push	edi
	shr	esi, 8
	shr	ecx, 1
	and	esi, 7
	and	ecx, 7
	xor	ebx, ebx
	mov	ecx, DWORD PTR _imm8_table[ecx*4]
	mov	al, BYTE PTR _regs[esi*4]
	movsx	edx, cl
	movsx	edi, al
	add	edx, edi
	mov	DWORD PTR _src$78489[esp+20], ecx
	test	dl, dl
	setl	bl
	test	dl, dl
	mov	DWORD PTR _newv$78491[esp+20], edx
	pop	edi
	sete	dl
	test	cl, cl
	setl	cl
	xor	cl, bl
	mov	BYTE PTR _regflags+1, dl
	test	al, al
	setl	dl
	xor	dl, bl
	and	cl, dl
	mov	dl, BYTE PTR _src$78489[esp+16]
	not	al
	cmp	al, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, BYTE PTR _newv$78491[esp+16]
	setb	al
	test	ebx, ebx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	setne	al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regs[esi*4], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5000_0@4 ENDP


@op_103b_0@4 PROC NEAR
	_start_func  'op_103b_0'
	mov	edx, DWORD PTR _regs+96
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [ecx+eax]
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	shr	esi, 1
	and	esi, 7
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_103b_0@4 ENDP


_src$78524 = -5
_newv$78526 = -4
@op_d000_0@4 PROC NEAR
	_start_func  'op_d000_0'
	mov	esi, ecx
	push	edi
	shr	esi, 1
	shr	ecx, 8
	and	esi, 7
	and	ecx, 7
	xor	ebx, ebx
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	al, BYTE PTR _regs[esi*4]
	movsx	edx, al
	movsx	edi, cl
	add	edx, edi
	mov	BYTE PTR _src$78524[esp+20], cl
	test	dl, dl
	setl	bl
	test	dl, dl
	mov	DWORD PTR _newv$78526[esp+20], edx
	pop	edi
	sete	dl
	test	al, al
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, bl
	test	cl, cl
	setl	cl
	xor	cl, bl
	and	dl, cl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$78524[esp+16]
	not	al
	cmp	al, dl
	setb	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$78526[esp+16]
	test	ebx, ebx
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	setne	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d000_0@4 ENDP


@op_d140_0@4 PROC NEAR
	_start_func  'op_d140_0'
	mov	dl, BYTE PTR _regflags+4
	mov	esi, ecx
	shr	esi, 1
	and	esi, 7
	xor	eax, eax
	shr	ecx, 8
	mov	bx, WORD PTR _regs[esi*4]
	and	ecx, 7
	test	dl, dl
	mov	cx, WORD PTR _regs[ecx*4]
	movsx	edx, bx
	setne	al
	add	eax, edx
	movsx	edx, cx
	add	eax, edx
	xor	edx, edx
	test	cx, cx
	mov	edi, eax
	setl	dl
	xor	eax, eax
	mov	WORD PTR _regs[esi*4], di
	test	bx, bx
	setl	al
	xor	ecx, ecx
	mov	bl, al
	test	di, di
	setl	cl
	xor	bl, cl
	xor	al, dl
	xor	cl, dl
	and	al, bl
	and	cl, bl
	xor	al, dl
	mov	dl, BYTE PTR _regflags+1
	mov	BYTE PTR _regflags+2, al
	test	di, di
	mov	BYTE PTR _regflags+4, al
	mov	BYTE PTR _regflags+3, cl
	sete	al
	and	dl, al
	mov	eax, DWORD PTR _regs+92
	test	di, di
	setl	cl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d140_0@4 ENDP


_dst$78568 = -1
@op_8e8_0@4 PROC NEAR
	_start_func  'op_8e8_0'
	mov	esi, ecx
	mov	bx, WORD PTR [eax+2]
	mov	cx, WORD PTR [eax+4]
	xor	eax, eax
	xor	edx, edx
	mov	al, ch
	mov	dh, cl
	movsx	eax, ax
	movsx	ecx, dx
	shr	esi, 8
	and	esi, 7
	or	eax, ecx
	xor	edx, edx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	mov	dl, bh
	and	edx, 7
	mov	cl, BYTE PTR [esi+eax]
	mov	BYTE PTR _dst$78568[esp+12], cl
	mov	bl, cl
	mov	cl, dl
	sar	bl, cl
	movsx	ecx, dx
	mov	dl, 1
	shl	dl, cl
	mov	cl, BYTE PTR _dst$78568[esp+12]
	not	bl
	and	bl, 1
	or	dl, cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [esi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8e8_0@4 ENDP


@op_5050_0@4 PROC NEAR
	_start_func  'op_5050_0'
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	eax, 1
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	eax, 7
	xor	edx, edx
	mov	edi, DWORD PTR _imm8_table[eax*4]
	mov	ax, WORD PTR [ecx+ebp]
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	movsx	eax, di
	movsx	ecx, si
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	si, si
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, di
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5050_0@4 ENDP


@op_d048_0@4 PROC NEAR
	_start_func  'op_d048_0'
	mov	esi, ecx
	shr	esi, 1
	shr	ecx, 8
	and	esi, 7
	and	ecx, 7
	mov	cx, WORD PTR _regs[ecx*4+32]
	mov	di, WORD PTR _regs[esi*4]
	movsx	ebp, di
	movsx	eax, cx
	add	ebp, eax
	xor	eax, eax
	test	bp, bp
	setl	al
	test	bp, bp
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	mov	WORD PTR _regs[esi*4], bp
	setl	dl
	xor	dl, al
	test	cx, cx
	setl	bl
	xor	bl, al
	not	edi
	and	dl, bl
	cmp	di, cx
	setb	cl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d048_0@4 ENDP


@op_213a_0@4 PROC NEAR
	_start_func  'op_213a_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR _regs+92
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	shr	ecx, 1
	mov	edx, DWORD PTR [edx+esi+2]
	bswap	edx
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	ecx, ecx
	cmp	edx, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	edx, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_213a_0@4 ENDP


@op_e108_0@4 PROC NEAR
	_start_func  'op_e108_0'
	mov	edx, ecx
	xor	eax, eax
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+3, 0
	shr	edx, 8
	mov	ecx, DWORD PTR _imm8_table[ecx*4]
	and	edx, 7
	and	ecx, 63					; 0000003fH
	mov	al, BYTE PTR _regs[edx*4]
	cmp	ecx, 8
	jb	SHORT $L78637
	jne	SHORT $L110851
	and	al, 1
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L78638
$L110851:
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L78638
$L78637:
	dec	ecx
	shl	eax, cl
	mov	ecx, eax
	and	eax, 127				; 0000007fH
	shr	ecx, 7
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shl	eax, 1
$L78638:
	test	al, al
	sete	cl
	test	al, al
	mov	BYTE PTR _regs[edx*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e108_0@4 ENDP


@op_890_0@4 PROC NEAR
	_start_func  'op_890_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	eax, eax
	mov	dl, BYTE PTR [edi+esi]
	mov	al, bh
	and	eax, 7
	mov	bl, dl
	mov	cl, al
	sar	bl, cl
	movsx	ecx, ax
	mov	al, 1
	shl	al, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	not	al
	and	al, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_890_0@4 ENDP


@op_4290_0@4 PROC NEAR
	_start_func  'op_4290_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	eax, eax
	shr	ecx, 8
	and	ecx, 7
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR _regflags, al
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4290_0@4 ENDP


@op_4250_0@4 PROC NEAR
	_start_func  'op_4250_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	eax, eax
	shr	ecx, 8
	and	ecx, 7
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR _regflags, al
	mov	WORD PTR [ecx+edx], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4250_0@4 ENDP


@op_30e8_0@4 PROC NEAR
	_start_func  'op_30e8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	add	edx, eax
	and	esi, 7
	mov	ax, WORD PTR [edx+edi]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	lea	edx, DWORD PTR [ecx+2]
	mov	DWORD PTR _regs[esi*4+32], edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	WORD PTR [edi+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30e8_0@4 ENDP


@op_e9e8_0@4 PROC NEAR
	_start_func  'op_e9e8_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	push	esi
	mov	esi, ecx
	xor	edx, edx
	mov	ecx, DWORD PTR _regs+92
	xor	ebx, ebx
	shr	esi, 8
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ah
	mov	bh, cl
	mov	dh, al
	xor	eax, eax
	mov	al, ch
	and	esi, 7
	movsx	eax, ax
	movsx	ecx, bx
	mov	ebx, DWORD PTR _regs[esi*4+32]
	or	eax, ecx
	push	edi
	mov	ecx, edx
	movsx	edi, dx
	and	ecx, 2048				; 00000800H
	add	eax, ebx
	test	cx, cx
	mov	ecx, edi
	je	SHORT $L110906
	sar	ecx, 6
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	jmp	SHORT $L110907
$L110906:
	sar	ecx, 6
	and	ecx, 31					; 0000001fH
$L110907:
	test	dl, 32					; 00000020H
	je	SHORT $L110908
	mov	edx, edi
	and	edx, 7
	mov	esi, DWORD PTR _regs[edx*4]
	jmp	SHORT $L110909
$L110908:
	mov	esi, edi
$L110909:
	dec	esi
	mov	edx, ecx
	and	esi, 31					; 0000001fH
	and	edx, -2147483648			; 80000000H
	inc	esi
	mov	ebx, ecx
	neg	edx
	sbb	edx, edx
	and	edx, -536870912				; e0000000H
	sar	ebx, 3
	or	edx, ebx
	add	eax, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	mov	ebx, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	DWORD PTR -4+[ebp], ecx
	xor	ecx, ecx
	mov	cl, BYTE PTR [ebx+eax+4]
	mov	ebx, DWORD PTR -4+[ebp]
	mov	eax, ecx
	mov	cl, 8
	sub	cl, bl
	shr	eax, cl
	mov	ecx, ebx
	shl	edx, cl
	mov	ecx, 32					; 00000020H
	sub	ecx, esi
	or	eax, edx
	mov	edx, 1
	shr	eax, cl
	lea	ecx, DWORD PTR [esi-1]
	shl	edx, cl
	test	edx, eax
	setne	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	sete	dl
	sar	edi, 12					; 0000000cH
	and	edi, 7
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags+2, cl
	mov	DWORD PTR _regs[edi*4], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e9e8_0@4 ENDP


@op_280_0@4 PROC NEAR
	_start_func  'op_280_0'
	shr	ecx, 8
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4]
	and	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 6
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_280_0@4 ENDP


@op_4a58_0@4 PROC NEAR
	_start_func  'op_4a58_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	ax, WORD PTR [esi+eax]
	add	esi, 2
	mov	dl, ah
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	dh, al
	xor	ecx, ecx
	mov	eax, edx
	mov	BYTE PTR _regflags+2, cl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a58_0@4 ENDP


@op_d1d0_0@4 PROC NEAR
	_start_func  'op_d1d0_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	ecx, DWORD PTR [ecx+edx]
	bswap	ecx
	mov	edx, DWORD PTR _regs[eax*4+32]
	add	edx, ecx
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d1d0_0@4 ENDP


@op_3148_0@4 PROC NEAR
	_start_func  'op_3148_0'
	mov	esi, ecx
	xor	edx, edx
	mov	eax, esi
	mov	ecx, DWORD PTR _regs+92
	shr	eax, 8
	and	eax, 7
	mov	cx, WORD PTR [ecx+2]
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	ax, WORD PTR _regs[eax*4+32]
	cmp	ax, dx
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	xor	ebx, ebx
	mov	dh, al
	xor	eax, eax
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3148_0@4 ENDP


@op_c000_0@4 PROC NEAR
	_start_func  'op_c000_0'
	mov	eax, ecx
	shr	eax, 1
	shr	ecx, 8
	and	eax, 7
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	dl, BYTE PTR _regs[eax*4]
	and	cl, dl
	mov	dl, 0
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regs[eax*4], cl
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c000_0@4 ENDP


@op_20c8_0@4 PROC NEAR
	_start_func  'op_20c8_0'
	mov	eax, ecx
	push	ebx
	shr	eax, 1
	and	eax, 7
	push	esi
	shr	ecx, 8
	mov	edx, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	lea	esi, DWORD PTR [edx+4]
	mov	DWORD PTR _regs[eax*4+32], esi
	xor	eax, eax
	cmp	ecx, eax
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	ecx, eax
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20c8_0@4 ENDP


_flgn$78789 = -4
@op_9048_0@4 PROC NEAR
	_start_func  'op_9048_0'
	mov	esi, ecx
	shr	esi, 1
	shr	ecx, 8
	and	esi, 7
	and	ecx, 7
	mov	bp, WORD PTR _regs[ecx*4+32]
	mov	ax, WORD PTR _regs[esi*4]
	movsx	edi, ax
	movsx	ecx, bp
	sub	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	xor	edx, edx
	mov	WORD PTR _regs[esi*4], di
	test	di, di
	setl	dl
	test	di, di
	sete	bl
	test	bp, bp
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$78789[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$78789[esp+20]
	and	bl, dl
	cmp	bp, ax
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _regs+92
	test	ecx, ecx
	setne	dl
	add	eax, 2
	mov	BYTE PTR _regflags+3, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9048_0@4 ENDP


@op_c0e8_0@4 PROC NEAR
	_start_func  'op_c0e8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	and	esi, 7
	mov	cx, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	eax, ecx
	mov	dh, cl
	and	eax, 65535				; 0000ffffH
	and	edx, 65535				; 0000ffffH
	shr	eax, 8
	xor	ecx, ecx
	or	eax, edx
	mov	cx, WORD PTR _regs[esi*4]
	imul	eax, ecx
	xor	ecx, ecx
	mov	DWORD PTR _regs[esi*4], eax
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c0e8_0@4 ENDP


@op_48a8_0@4 PROC NEAR
	_start_func  'op_48a8_0'
	mov	edx, eax
	mov	esi, ecx
	mov	ax, WORD PTR [edx+2]
	mov	dx, WORD PTR [edx+4]
	xor	ecx, ecx
	xor	ebx, ebx
	mov	cl, ah
	mov	bh, dl
	mov	ch, al
	xor	eax, eax
	mov	al, dh
	movsx	eax, ax
	movsx	edx, bx
	shr	esi, 8
	and	esi, 7
	or	eax, edx
	mov	dl, cl
	mov	edi, DWORD PTR _regs[esi*4+32]
	and	edx, 255				; 000000ffH
	add	eax, edi
	mov	edi, edx
	xor	edx, edx
	mov	dl, ch
	test	di, di
	mov	esi, edx
	je	SHORT $L111016
$L78830:
	and	edi, 65535				; 0000ffffH
	xor	edx, edx
	shl	edi, 2
	add	eax, 2
	mov	ecx, DWORD PTR _movem_index1[edi]
	mov	cx, WORD PTR _regs[ecx*4]
	mov	dl, ch
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+eax-2], dx
	mov	di, WORD PTR _movem_next[edi]
	test	di, di
	jne	SHORT $L78830
$L111016:
	test	si, si
	je	SHORT $L111019
$L78833:
	and	esi, 65535				; 0000ffffH
	add	eax, 2
	shl	esi, 2
	mov	edx, DWORD PTR _movem_index1[esi]
	mov	cx, WORD PTR _regs[edx*4+32]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+eax-2], dx
	mov	si, WORD PTR _movem_next[esi]
	test	si, si
	jne	SHORT $L78833
$L111019:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_48a8_0@4 ENDP


@op_4ab0_0@4 PROC NEAR
	_start_func  'op_4ab0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ab0_0@4 ENDP


@op_30bc_0@4 PROC NEAR
	_start_func  'op_30bc_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	ecx, 1
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	BYTE PTR _regflags+1, bl
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30bc_0@4 ENDP


@op_4218_0@4 PROC NEAR
	_start_func  'op_4218_0'
	shr	ecx, 8
	and	ecx, 7
	mov	BYTE PTR _regflags+1, 1
	mov	edx, DWORD PTR _regs[ecx*4+32]
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	add	ecx, edx
	mov	DWORD PTR [eax], ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR [ecx+edx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4218_0@4 ENDP


_dstreg$ = -4
@op_9058_0@4 PROC NEAR
	_start_func  'op_9058_0'
	mov	eax, ecx
	shr	eax, 8
	shr	ecx, 1
	and	eax, 7
	and	ecx, 7
	mov	esi, DWORD PTR _regs[eax*4+32]
	mov	ebp, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, 2
	mov	DWORD PTR _dstreg$[esp+20], ebp
	mov	dx, WORD PTR [esi+ecx-2]
	xor	ecx, ecx
	mov	cl, dh
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	bp, WORD PTR _regs[ebp*4]
	mov	ch, dl
	mov	edi, ecx
	xor	eax, eax
	movsx	esi, bp
	movsx	edx, di
	sub	esi, edx
	test	bp, bp
	setl	al
	xor	edx, edx
	test	si, si
	setl	dl
	test	si, si
	sete	cl
	test	di, di
	mov	BYTE PTR _regflags+1, cl
	mov	bl, dl
	setl	cl
	xor	cl, al
	xor	bl, al
	and	cl, bl
	cmp	di, bp
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _dstreg$[esp+20]
	test	edx, edx
	mov	WORD PTR _regs[eax*4], si
	mov	eax, DWORD PTR _regs+92
	setne	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9058_0@4 ENDP


@op_b140_0@4 PROC NEAR
	_start_func  'op_b140_0'
	mov	eax, ecx
	xor	edx, edx
	shr	ecx, 1
	shr	eax, 8
	and	ecx, 7
	and	eax, 7
	mov	BYTE PTR _regflags+2, dl
	mov	cx, WORD PTR _regs[ecx*4]
	mov	BYTE PTR _regflags+3, dl
	xor	cx, WORD PTR _regs[eax*4]
	cmp	cx, dx
	mov	WORD PTR _regs[eax*4], cx
	mov	eax, DWORD PTR _regs+92
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b140_0@4 ENDP


@op_10f0_0@4 PROC NEAR
	_start_func  'op_10f0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs[esi*4+32]
	lea	ecx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _areg_byteinc[esi*4]
	mov	al, BYTE PTR [edi+eax]
	add	esi, edx
	mov	DWORD PTR [ecx], esi
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+edx], al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10f0_0@4 ENDP


_dstreg$ = -4
@op_d098_0@4 PROC NEAR
	_start_func  'op_d098_0'
	mov	ebp, esp
	push	ecx
	mov	eax, ecx
	push	ebx
	shr	eax, 8
	and	eax, 7
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	push	edi
	mov	edx, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	edi, DWORD PTR [edx+esi]
	bswap	edi
	and	ecx, 7
	mov	DWORD PTR _dstreg$[ebp], ecx
	mov	edx, DWORD PTR _regs[eax*4+32]
	add	edx, 4
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	esi, DWORD PTR _regs[ecx*4]
	xor	eax, eax
	lea	edx, DWORD PTR [edi+esi]
	test	edx, edx
	setl	al
	test	edx, edx
	sete	cl
	test	edi, edi
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, al
	test	esi, esi
	setl	bl
	xor	bl, al
	not	esi
	and	cl, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, cl
	pop	edi
	setb	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _dstreg$[ebp]
	pop	esi
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs[ecx*4], edx
	mov	eax, DWORD PTR _regs+92
	pop	ebx
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d098_0@4 ENDP


@op_5be8_0@4 PROC NEAR
	_start_func  'op_5be8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, eax
	movsx	eax, BYTE PTR _regflags
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR [ecx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5be8_0@4 ENDP


@op_217c_0@4 PROC NEAR
	_start_func  'op_217c_0'
	push	esi
	push	edi
	mov	esi, ecx
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	ecx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	edi, eax
	mov	cx, WORD PTR [ecx+6]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	edi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 1
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_217c_0@4 ENDP


@op_5078_0@4 PROC NEAR
	_start_func  'op_5078_0'
	shr	ecx, 1
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	xor	edx, edx
	mov	ebp, DWORD PTR _imm8_table[ecx*4]
	xor	ecx, ecx
	mov	cl, ah
	mov	dh, al
	movsx	edi, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	movsx	eax, dx
	or	edi, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+edi]
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	movsx	eax, bp
	movsx	ecx, si
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	bp, bp
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	si, si
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, bp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5078_0@4 ENDP


@op_b100_0@4 PROC NEAR
	_start_func  'op_b100_0'
	mov	eax, ecx
	shr	eax, 8
	shr	ecx, 1
	and	eax, 7
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	dl, BYTE PTR _regs[eax*4]
	xor	cl, dl
	mov	dl, 0
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regs[eax*4], cl
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b100_0@4 ENDP


@op_57c0_0@4 PROC NEAR
	_start_func  'op_57c0_0'
	movsx	eax, BYTE PTR _regflags+1
	shr	ecx, 8
	and	ecx, 7
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_57c0_0@4 ENDP


_flgn$79021 = -4
@op_5178_0@4 PROC NEAR
	_start_func  'op_5178_0'
	shr	ecx, 1
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	xor	edx, edx
	mov	edi, DWORD PTR _imm8_table[ecx*4]
	xor	ecx, ecx
	mov	cl, ah
	mov	dh, al
	movsx	esi, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	movsx	eax, dx
	or	esi, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+esi]
	mov	dl, ah
	mov	dh, al
	mov	ebp, edx
	movsx	ecx, di
	movsx	eax, bp
	sub	eax, ecx
	xor	ecx, ecx
	test	bp, bp
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	di, di
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$79021[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	di, bp
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$79021[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5178_0@4 ENDP


_newv$79034 = -4
@op_d090_0@4 PROC NEAR
	_start_func  'op_d090_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	push	esi
	mov	esi, ecx
	push	edi
	shr	ecx, 8
	and	ecx, 7
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	mov	ecx, DWORD PTR [eax+ecx]
	bswap	ecx
	mov	edi, DWORD PTR _regs[esi*4]
	xor	eax, eax
	lea	edx, DWORD PTR [ecx+edi]
	test	edx, edx
	setl	al
	test	edx, edx
	mov	DWORD PTR _newv$79034[ebp], edx
	sete	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, al
	test	edi, edi
	setl	bl
	xor	bl, al
	not	edi
	and	dl, bl
	cmp	edi, ecx
	setb	cl
	test	eax, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _newv$79034[ebp]
	pop	edi
	setne	al
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs[esi*4], ecx
	mov	eax, DWORD PTR _regs+92
	pop	esi
	add	eax, 2
	mov	BYTE PTR _regflags+3, dl
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d090_0@4 ENDP


@op_e0a0_0@4 PROC NEAR
	_start_func  'op_e0a0_0'
	mov	edi, ecx
	mov	BYTE PTR _regflags+2, 0
	shr	edi, 8
	shr	ecx, 1
	and	edi, 7
	and	ecx, 7
	mov	BYTE PTR _regflags+3, 0
	mov	eax, DWORD PTR _regs[edi*4]
	mov	esi, DWORD PTR _regs[ecx*4]
	mov	edx, eax
	and	esi, 63					; 0000003fH
	shr	edx, 31					; 0000001fH
	cmp	esi, 32					; 00000020H
	jl	SHORT $L79058
	mov	eax, edx
	mov	BYTE PTR _regflags+2, dl
	neg	eax
	mov	BYTE PTR _regflags+4, dl
	jmp	SHORT $L79061
$L79058:
	test	esi, esi
	jle	SHORT $L79061
	lea	ecx, DWORD PTR [esi-1]
	shr	eax, cl
	neg	edx
	mov	cl, al
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, 32					; 00000020H
	sub	ecx, esi
	or	esi, -1
	shl	esi, cl
	shr	eax, 1
	and	esi, edx
	or	eax, esi
$L79061:
	test	eax, eax
	sete	cl
	test	eax, eax
	mov	DWORD PTR _regs[edi*4], eax
	mov	eax, DWORD PTR _regs+92
	setl	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+1, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e0a0_0@4 ENDP


_src$79070 = -1
@op_c100_0@4 PROC NEAR
	_start_func  'op_c100_0'
	mov	bl, BYTE PTR _regflags+4
	push	esi
	mov	esi, ecx
	shr	ecx, 8
	shr	esi, 1
	and	ecx, 7
	and	esi, 7
	xor	edx, edx
	push	edi
	mov	al, BYTE PTR _regs[ecx*4]
	mov	cl, BYTE PTR _regs[esi*4]
	test	bl, bl
	mov	bl, cl
	mov	BYTE PTR _src$79070[esp+16], al
	setne	dl
	and	bl, 15					; 0000000fH
	movsx	di, bl
	mov	bl, al
	add	edx, edi
	and	bl, 15					; 0000000fH
	and	eax, 240				; 000000f0H
	movsx	di, bl
	add	edi, edx
	mov	dl, cl
	and	edx, 240				; 000000f0H
	add	edx, eax
	cmp	di, 9
	mov	ebx, edx
	jbe	SHORT $L79076
	add	edi, 6
$L79076:
	add	ebx, edi
	mov	edx, 144				; 00000090H
	mov	eax, ebx
	and	eax, 496				; 000001f0H
	cmp	edx, eax
	sbb	eax, eax
	neg	eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	je	SHORT $L79077
	add	ebx, 96					; 00000060H
$L79077:
	mov	dl, BYTE PTR _regflags+1
	mov	BYTE PTR _regs[esi*4], bl
	test	bl, bl
	sete	al
	and	dl, al
	pop	edi
	test	bl, bl
	mov	BYTE PTR _regflags+1, dl
	pop	esi
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	test	cl, cl
	mov	cl, BYTE PTR _src$79070[esp+8]
	setl	dl
	test	cl, cl
	setl	cl
	xor	cl, dl
	xor	al, dl
	and	cl, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+3, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c100_0@4 ENDP


@op_4890_0@4 PROC NEAR
	_start_func  'op_4890_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	mov	cl, al
	mov	dl, ah
	and	ecx, 255				; 000000ffH
	test	cx, cx
	mov	edi, edx
	je	SHORT $L111275
$L79098:
	and	ecx, 65535				; 0000ffffH
	xor	edx, edx
	shl	ecx, 2
	add	esi, 2
	mov	eax, DWORD PTR _movem_index1[ecx]
	mov	ax, WORD PTR _regs[eax*4]
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+esi-2], dx
	mov	cx, WORD PTR _movem_next[ecx]
	test	cx, cx
	jne	SHORT $L79098
$L111275:
	test	di, di
	je	SHORT $L111278
$L79101:
	mov	eax, edi
	xor	edx, edx
	and	eax, 65535				; 0000ffffH
	add	esi, 2
	shl	eax, 2
	mov	ecx, DWORD PTR _movem_index1[eax]
	mov	cx, WORD PTR _regs[ecx*4+32]
	mov	dl, ch
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+esi-2], dx
	mov	di, WORD PTR _movem_next[eax]
	test	di, di
	jne	SHORT $L79101
$L111278:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4890_0@4 ENDP


@op_3110_0@4 PROC NEAR
	_start_func  'op_3110_0'
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	shr	eax, 1
	mov	cx, WORD PTR [ecx+esi]
	and	eax, 7
	mov	dl, ch
	mov	dh, cl
	mov	ecx, edx
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, 2
	mov	DWORD PTR _regs[eax*4+32], edx
	xor	eax, eax
	cmp	cx, ax
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	cx, ax
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags, al
	xor	eax, eax
	mov	al, ch
	mov	BYTE PTR _regflags+1, bl
	mov	ah, cl
	mov	WORD PTR [esi+edx], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3110_0@4 ENDP


_dsta$79122 = -4
@op_d198_0@4 PROC NEAR
	_start_func  'op_d198_0'
	mov	ebp, esp
	push	ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 1
	shr	eax, 8
	push	ebx
	and	ecx, 7
	push	esi
	and	eax, 7
	push	edi
	mov	edi, DWORD PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	DWORD PTR _dsta$79122[ebp], ecx
	mov	esi, DWORD PTR [edx+ecx]
	bswap	esi
	mov	ebx, DWORD PTR _regs[eax*4+32]
	lea	ecx, DWORD PTR [esi+edi]
	add	ebx, 4
	mov	DWORD PTR _regs[eax*4+32], ebx
	xor	eax, eax
	test	ecx, ecx
	setl	al
	test	ecx, ecx
	sete	dl
	test	esi, esi
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, al
	test	edi, edi
	setl	bl
	xor	bl, al
	not	esi
	and	dl, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _dsta$79122[ebp]
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d198_0@4 ENDP


@op_e058_0@4 PROC NEAR
	_start_func  'op_e058_0'
	mov	esi, ecx
	shr	ecx, 1
	shr	esi, 8
	and	ecx, 7
	and	esi, 7
	xor	edx, edx
	mov	edi, DWORD PTR _imm8_table[ecx*4]
	mov	ecx, 16					; 00000010H
	mov	dx, WORD PTR _regs[esi*4]
	and	edi, 15					; 0000000fH
	sub	ecx, edi
	mov	eax, edx
	shl	eax, cl
	mov	ecx, edi
	shr	edx, cl
	mov	BYTE PTR _regflags+3, 0
	or	eax, edx
	and	eax, 65535				; 0000ffffH
	mov	ecx, eax
	mov	WORD PTR _regs[esi*4], ax
	shr	ecx, 15					; 0000000fH
	and	cl, 1
	test	ax, ax
	sete	dl
	test	ax, ax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e058_0@4 ENDP


@op_b1f0_0@4 PROC NEAR
	_start_func  'op_b1f0_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	shr	esi, 1
	and	esi, 7
	xor	edx, edx
	mov	esi, DWORD PTR _regs[esi*4+32]
	mov	eax, esi
	sub	eax, ecx
	test	esi, esi
	setl	dl
	mov	edi, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	ecx, ecx
	setl	al
	cmp	eax, edi
	je	SHORT $L111311
	cmp	edx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L111312
$L111311:
	mov	BYTE PTR _regflags+3, 0
$L111312:
	cmp	ecx, esi
	seta	cl
	test	edx, edx
	setne	dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b1f0_0@4 ENDP


@op_e138_0@4 PROC NEAR
	_start_func  'op_e138_0'
	mov	edx, ecx
	xor	eax, eax
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+2, 0
	shr	edx, 8
	mov	cl, BYTE PTR _regs[ecx*4]
	and	edx, 7
	and	cl, 63					; 0000003fH
	mov	BYTE PTR _regflags+3, 0
	mov	al, BYTE PTR _regs[edx*4]
	jle	SHORT $L79185
	and	cl, 7
	push	esi
	movsx	esi, cl
	mov	ecx, 8
	push	edi
	sub	ecx, esi
	mov	edi, eax
	shr	edi, cl
	mov	ecx, esi
	shl	eax, cl
	or	edi, eax
	and	edi, 255				; 000000ffH
	mov	eax, edi
	pop	edi
	mov	cl, al
	pop	esi
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
$L79185:
	test	al, al
	sete	cl
	test	al, al
	mov	BYTE PTR _regs[edx*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e138_0@4 ENDP


@op_10bc_0@4 PROC NEAR
	_start_func  'op_10bc_0'
	xor	dl, dl
	mov	al, BYTE PTR [eax+3]
	mov	BYTE PTR _regflags+2, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [ecx+edx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10bc_0@4 ENDP


@op_203b_0@4 PROC NEAR
	_start_func  'op_203b_0'
	mov	edx, DWORD PTR _regs+96
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	shr	esi, 1
	and	esi, 7
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs[esi*4], eax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_203b_0@4 ENDP


_src$79226 = -5
_newv$79228 = -4
@op_d028_0@4 PROC NEAR
	_start_func  'op_d028_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	esi, ecx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	add	edx, ebx
	mov	bl, BYTE PTR [edx+ecx]
	mov	al, BYTE PTR _regs[esi*4]
	movsx	ecx, al
	movsx	edx, bl
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$79228[esp+16], ecx
	mov	BYTE PTR _src$79226[esp+16], bl
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$79226[esp+16]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$79228[esp+16]
	test	edx, edx
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	setne	dl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d028_0@4 ENDP


@op_b0c8_0@4 PROC NEAR
	_start_func  'op_b0c8_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	si, WORD PTR _regs[eax*4+32]
	and	ecx, 7
	xor	edx, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	movsx	edi, si
	mov	eax, ecx
	sub	eax, edi
	test	ecx, ecx
	setl	dl
	mov	ebp, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	si, si
	setl	al
	cmp	eax, ebp
	je	SHORT $L111374
	cmp	edx, ebp
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L111375
$L111374:
	mov	BYTE PTR _regflags+3, 0
$L111375:
	mov	eax, DWORD PTR _regs+92
	cmp	edi, ecx
	seta	cl
	test	edx, edx
	setne	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b0c8_0@4 ENDP


@op_80a8_0@4 PROC NEAR
	_start_func  'op_80a8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	and	esi, 7
	mov	ecx, DWORD PTR [edx+ecx]
	bswap	ecx
	mov	eax, DWORD PTR _regs[esi*4]
	or	eax, ecx
	mov	ecx, 0
	sete	dl
	cmp	eax, ecx
	mov	DWORD PTR _regs[esi*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_80a8_0@4 ENDP


@op_317a_0@4 PROC NEAR
	_start_func  'op_317a_0'
	mov	esi, ecx
	xor	edx, edx
	mov	ecx, DWORD PTR _regs+92
	xor	ebx, ebx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, edi
	add	edx, eax
	mov	ax, WORD PTR [edx+ecx+2]
	xor	edx, edx
	mov	dl, ah
	mov	cx, WORD PTR [ecx+4]
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	eax, ecx
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_317a_0@4 ENDP


@op_91d0_0@4 PROC NEAR
	_start_func  'op_91d0_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	ecx, DWORD PTR [ecx+edx]
	bswap	ecx
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, ecx
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_91d0_0@4 ENDP


@op_31a8_0@4 PROC NEAR
	_start_func  'op_31a8_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	ebx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	xor	ebx, ebx
	and	ecx, 7
	mov	ax, WORD PTR [edx+eax]
	mov	DWORD PTR _regs+92, esi
	mov	dx, WORD PTR [esi]
	mov	bl, ah
	mov	bh, al
	add	esi, 2
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31a8_0@4 ENDP


@op_2190_0@4 PROC NEAR
	_start_func  'op_2190_0'
	mov	eax, ecx
	push	esi
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [edx+eax]
	bswap	esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 1
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2190_0@4 ENDP


@op_4a98_0@4 PROC NEAR
	_start_func  'op_4a98_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR [eax+edx]
	bswap	eax
	mov	edx, DWORD PTR _regs[ecx*4+32]
	add	edx, 4
	mov	DWORD PTR _regs[ecx*4+32], edx
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a98_0@4 ENDP


@op_4600_0@4 PROC NEAR
	_start_func  'op_4600_0'
	shr	ecx, 8
	and	ecx, 7
	xor	dl, dl
	mov	BYTE PTR _regflags+2, dl
	movsx	eax, BYTE PTR _regs[ecx*4]
	not	eax
	cmp	al, dl
	mov	BYTE PTR _regs[ecx*4], al
	sete	bl
	cmp	al, dl
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4600_0@4 ENDP


@op_c1e8_0@4 PROC NEAR
	_start_func  'op_c1e8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	esi, ecx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	and	esi, 7
	mov	cx, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	movsx	edx, WORD PTR _regs[esi*4]
	or	eax, ecx
	xor	ecx, ecx
	imul	eax, edx
	cmp	eax, ecx
	mov	DWORD PTR _regs[esi*4], eax
	sete	dl
	cmp	eax, ecx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c1e8_0@4 ENDP


@op_c0b8_0@4 PROC NEAR
	_start_func  'op_c0b8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4]
	and	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 4
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c0b8_0@4 ENDP


@op_49c0_0@4 PROC NEAR
	_start_func  'op_49c0_0'
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	mov	BYTE PTR _regflags+2, dl
	movsx	eax, BYTE PTR _regs[ecx*4]
	cmp	eax, edx
	mov	DWORD PTR _regs[ecx*4], eax
	sete	bl
	cmp	eax, edx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_49c0_0@4 ENDP


@op_20bc_0@4 PROC NEAR
	_start_func  'op_20bc_0'
	push	ebx
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20bc_0@4 ENDP


@op_4c68_0@4 PROC NEAR
	_start_func  'op_4c68_0'
	mov	edx, eax
	mov	eax, DWORD PTR _regs+88
	mov	edi, DWORD PTR _regs+96
	add	edx, 2
	mov	esi, ecx
	sub	eax, edi
	mov	DWORD PTR _regs+92, edx
	mov	cx, WORD PTR [edx]
	add	eax, edx
	mov	dx, WORD PTR [edx+2]
	xor	ebx, ebx
	mov	bl, dh
	movsx	edi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	or	edi, edx
	mov	edx, esi
	shr	edx, 8
	and	edx, 7
	mov	ebx, DWORD PTR _regs[edx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	add	edi, ebx
	mov	edx, DWORD PTR [edi+edx]
	bswap	edx
	mov	edi, DWORD PTR _regs+92
	push	eax
	xor	eax, eax
	add	edi, 4
	mov	al, ch
	mov	DWORD PTR _regs+92, edi
	mov	ah, cl
	push	eax
	push	edx
	push	esi
	call	_m68k_divl@16
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4c68_0@4 ENDP


@op_3178_0@4 PROC NEAR
	_start_func  'op_3178_0'
	mov	esi, ecx
	xor	edx, edx
	mov	ecx, DWORD PTR _regs+92
	xor	ebx, ebx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	ax, WORD PTR [edx+edi]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	eax, ecx
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3178_0@4 ENDP


@op_c1c0_0@4 PROC NEAR
	_start_func  'op_c1c0_0'
	mov	eax, ecx
	shr	eax, 1
	shr	ecx, 8
	and	eax, 7
	and	ecx, 7
	movsx	ecx, WORD PTR _regs[ecx*4]
	movsx	edx, WORD PTR _regs[eax*4]
	imul	ecx, edx
	xor	edx, edx
	mov	DWORD PTR _regs[eax*4], ecx
	mov	eax, DWORD PTR _regs+92
	cmp	ecx, edx
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c1c0_0@4 ENDP


@op_55c0_0@4 PROC NEAR
	_start_func  'op_55c0_0'
	movsx	eax, BYTE PTR _regflags+2
	shr	ecx, 8
	and	ecx, 7
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_55c0_0@4 ENDP


@op_103c_0@4 PROC NEAR
	_start_func  'op_103c_0'
	xor	dl, dl
	mov	al, BYTE PTR [eax+3]
	mov	BYTE PTR _regflags+2, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_103c_0@4 ENDP


@op_50_0@4 PROC NEAR
	_start_func  'op_50_0'
	shr	ecx, 8
	mov	dx, WORD PTR [eax+2]
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	ax, WORD PTR [esi+ecx]
	or	eax, edx
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	WORD PTR [esi+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_50_0@4 ENDP


@op_30a8_0@4 PROC NEAR
	_start_func  'op_30a8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	add	edx, DWORD PTR _regs[eax*4+32]
	mov	ax, WORD PTR [edx+esi]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	ecx, 1
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	BYTE PTR _regflags+1, bl
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30a8_0@4 ENDP


_dsta$79522 = -4
@op_5090_0@4 PROC NEAR
	_start_func  'op_5090_0'
	mov	ebp, esp
	push	ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	push	ebx
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	push	esi
	push	edi
	mov	edi, DWORD PTR _imm8_table[eax*4]
	mov	esi, DWORD PTR [edx+ecx]
	bswap	esi
	mov	DWORD PTR _dsta$79522[ebp], ecx
	lea	edx, DWORD PTR [esi+edi]
	xor	eax, eax
	test	edx, edx
	setl	al
	test	edx, edx
	sete	cl
	test	esi, esi
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, al
	test	edi, edi
	setl	bl
	xor	bl, al
	not	esi
	and	cl, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, cl
	setb	cl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _dsta$79522[ebp]
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5090_0@4 ENDP


@op_4c28_0@4 PROC NEAR
	_start_func  'op_4c28_0'
	mov	edx, eax
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+2]
	mov	dx, WORD PTR [edx+4]
	mov	bl, dh
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	or	esi, edx
	mov	edx, ecx
	shr	edx, 8
	and	edx, 7
	mov	ebx, DWORD PTR _regs[edx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	add	esi, ebx
	mov	esi, DWORD PTR [esi+edx]
	bswap	esi
	mov	edx, DWORD PTR _regs+92
	add	edx, 6
	mov	DWORD PTR _regs+92, edx
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	push	edx
	push	esi
	push	ecx
	call	_m68k_mull@12
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4c28_0@4 ENDP


@op_b030_0@4 PROC NEAR
	_start_func  'op_b030_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	shr	esi, 1
	mov	cl, BYTE PTR [ecx+eax]
	and	esi, 7
	mov	dl, BYTE PTR _regs[esi*4]
	movsx	eax, dl
	movsx	esi, cl
	sub	eax, esi
	test	dl, dl
	setl	bl
	mov	esi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	cl, cl
	setl	al
	cmp	eax, esi
	mov	edi, ebx
	je	SHORT $L111683
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L111684
$L111683:
	mov	BYTE PTR _regflags+3, 0
$L111684:
	cmp	cl, dl
	seta	cl
	test	edi, edi
	setne	dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b030_0@4 ENDP


@op_4080_0@4 PROC NEAR
	_start_func  'op_4080_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, ecx
	mov	cl, BYTE PTR _regflags+4
	xor	edx, edx
	mov	eax, DWORD PTR _regs[esi*4]
	test	cl, cl
	setne	dl
	add	edx, eax
	xor	ecx, ecx
	neg	edx
	test	eax, eax
	setl	cl
	xor	ebx, ebx
	mov	DWORD PTR _regs[esi*4], edx
	test	edx, edx
	setl	bl
	mov	al, bl
	and	al, cl
	mov	BYTE PTR _regflags+3, al
	mov	al, bl
	xor	al, cl
	and	al, bl
	mov	bl, BYTE PTR _regflags+1
	xor	al, cl
	test	edx, edx
	sete	cl
	and	bl, cl
	mov	BYTE PTR _regflags+2, al
	test	edx, edx
	mov	BYTE PTR _regflags+4, al
	mov	BYTE PTR _regflags+1, bl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4080_0@4 ENDP


@op_b078_0@4 PROC NEAR
	_start_func  'op_b078_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	and	ecx, 7
	mov	dl, ah
	mov	dh, al
	mov	si, WORD PTR _regs[ecx*4]
	movsx	eax, si
	movsx	ecx, dx
	sub	eax, ecx
	xor	ecx, ecx
	test	si, si
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dx, dx
	setl	al
	cmp	eax, edi
	je	SHORT $L111704
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L111705
$L111704:
	mov	BYTE PTR _regflags+3, 0
$L111705:
	cmp	dx, si
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b078_0@4 ENDP


@op_8028_0@4 PROC NEAR
	_start_func  'op_8028_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	add	edx, eax
	mov	al, BYTE PTR [edx+ecx]
	mov	bl, BYTE PTR _regs[esi*4]
	or	al, bl
	mov	cl, 0
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8028_0@4 ENDP


@op_b1a8_0@4 PROC NEAR
	_start_func  'op_b1a8_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	push	esi
	push	edi
	mov	edi, DWORD PTR _regs[eax*4]
	mov	ax, WORD PTR [edx+2]
	xor	edx, edx
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, eax
	mov	eax, DWORD PTR [ecx+esi]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edi, eax
	mov	eax, 0
	sete	dl
	cmp	edi, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	lea	eax, DWORD PTR [ecx+esi]
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b1a8_0@4 ENDP


@op_a00_0@4 PROC NEAR
	_start_func  'op_a00_0'
	shr	ecx, 8
	mov	al, BYTE PTR [eax+3]
	and	ecx, 7
	mov	dl, BYTE PTR _regs[ecx*4]
	xor	al, dl
	mov	dl, 0
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 4
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a00_0@4 ENDP


@op_4210_0@4 PROC NEAR
	_start_func  'op_4210_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	al, al
	shr	ecx, 8
	and	ecx, 7
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR [ecx+edx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4210_0@4 ENDP


@op_4ca8_0@4 PROC NEAR
	_start_func  'op_4ca8_0'
	mov	edi, ecx
	xor	edx, edx
	mov	ecx, DWORD PTR _regs+92
	shr	edi, 8
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ah
	and	edi, 7
	mov	dh, al
	and	edx, 65535				; 0000ffffH
	mov	eax, edx
	shr	edx, 8
	mov	ebp, edx
	xor	edx, edx
	mov	dl, ch
	and	eax, 255				; 000000ffH
	movsx	esi, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _regs[edi*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	or	esi, ecx
	add	esi, edx
	test	eax, eax
	je	SHORT $L111779
$L79676:
	mov	cx, WORD PTR [edi+esi]
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	add	esi, 2
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	ecx, DWORD PTR _movem_index1[eax*4]
	mov	eax, DWORD PTR _movem_next[eax*4]
	test	eax, eax
	mov	DWORD PTR _regs[ecx*4], edx
	jne	SHORT $L79676
$L111779:
	test	ebp, ebp
	je	SHORT $L111782
	lea	ecx, DWORD PTR [edi+esi]
$L79681:
	mov	ax, WORD PTR [ecx]
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ah
	mov	bh, al
	add	ecx, 2
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _movem_index1[ebp*4]
	mov	ebp, DWORD PTR _movem_next[ebp*4]
	test	ebp, ebp
	mov	DWORD PTR _regs[eax*4+32], edx
	jne	SHORT $L79681
$L111782:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ca8_0@4 ENDP


@op_c0b0_0@4 PROC NEAR
	_start_func  'op_c0b0_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	mov	eax, DWORD PTR _regs[esi*4]
	and	eax, ecx
	mov	ecx, 0
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	DWORD PTR _regs[esi*4], eax
	setl	cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c0b0_0@4 ENDP


@op_31c0_0@4 PROC NEAR
	_start_func  'op_31c0_0'
	xor	edx, edx
	shr	ecx, 8
	and	ecx, 7
	mov	ax, WORD PTR [eax+2]
	mov	BYTE PTR _regflags+2, dl
	mov	cx, WORD PTR _regs[ecx*4]
	mov	BYTE PTR _regflags+3, dl
	cmp	cx, dx
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ch
	xor	ebx, ebx
	mov	dh, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	bh, al
	movsx	ecx, cx
	movsx	eax, bx
	or	ecx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31c0_0@4 ENDP


@op_8b0_0@4 PROC NEAR
	_start_func  'op_8b0_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	esi, eax
	mov	dl, bh
	and	edx, 7
	mov	al, BYTE PTR [edi+esi]
	mov	cl, dl
	mov	bl, al
	sar	bl, cl
	movsx	ecx, dx
	mov	dl, 1
	shl	dl, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	not	dl
	and	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8b0_0@4 ENDP


@op_50c0_0@4 PROC NEAR
	_start_func  'op_50c0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	BYTE PTR _regs[ecx*4], 255		; 000000ffH
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_50c0_0@4 ENDP


@op_80e8_0@4 PROC NEAR
	_start_func  'op_80e8_0'
	mov	edi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	esi, ecx
	mov	ax, WORD PTR [edi+2]
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	and	esi, 7
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	ebp, DWORD PTR _regs[esi*4]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	cmp	ax, bx
	jne	SHORT $L79739
	mov	eax, DWORD PTR _regs+88
	mov	esi, DWORD PTR _regs+96
	sub	eax, esi
	add	eax, edi
	push	eax
	push	5
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L79739:
	mov	edi, eax
	mov	eax, ebp
	and	edi, 65535				; 0000ffffH
	xor	edx, edx
	div	edi
	mov	ecx, eax
	cmp	ecx, 65535				; 0000ffffH
	jbe	SHORT $L79753
	mov	al, 1
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	jmp	SHORT $L79752
$L79753:
	cmp	cx, bx
	mov	BYTE PTR _regflags+2, bl
	sete	dl
	cmp	cx, bx
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, ebp
	xor	edx, edx
	and	ecx, 65535				; 0000ffffH
	div	edi
	mov	BYTE PTR _regflags+3, bl
	shl	edx, 16					; 00000010H
	or	edx, ecx
	mov	DWORD PTR _regs[esi*4], edx
$L79752:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_80e8_0@4 ENDP


_flgs$79767 = -4
@op_9140_0@4 PROC NEAR
	_start_func  'op_9140_0'
	mov	al, BYTE PTR _regflags+4
	push	esi
	mov	esi, ecx
	shr	esi, 1
	and	esi, 7
	push	edi
	shr	ecx, 8
	mov	di, WORD PTR _regs[esi*4]
	and	ecx, 7
	xor	edx, edx
	mov	cx, WORD PTR _regs[ecx*4]
	test	al, al
	movsx	eax, di
	setne	dl
	sub	eax, edx
	movsx	edx, cx
	sub	eax, edx
	xor	edx, edx
	test	cx, cx
	setl	dl
	mov	DWORD PTR _flgs$79767[esp+20], edx
	xor	edx, edx
	test	di, di
	setl	dl
	xor	ecx, ecx
	mov	WORD PTR _regs[esi*4], ax
	test	ax, ax
	setl	cl
	mov	bl, cl
	pop	edi
	xor	bl, dl
	pop	esi
	mov	BYTE PTR -5+[esp+12], bl
	mov	bl, BYTE PTR _flgs$79767[esp+12]
	xor	dl, bl
	mov	bl, BYTE PTR -5+[esp+12]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _flgs$79767[esp+12]
	xor	cl, dl
	and	cl, bl
	xor	cl, dl
	mov	dl, BYTE PTR _regflags+1
	test	ax, ax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	sete	cl
	and	dl, cl
	test	ax, ax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9140_0@4 ENDP


_dst$79784 = -4
_flgn$79792 = -8
@op_90b0_0@4 PROC NEAR
	_start_func  'op_90b0_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	add	eax, 2
	push	esi
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	push	edi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	mov	edx, DWORD PTR _regs[esi*4]
	xor	ecx, ecx
	mov	edi, edx
	mov	DWORD PTR _dst$79784[ebp], edx
	sub	edi, eax
	test	edx, edx
	setl	cl
	xor	edx, edx
	mov	DWORD PTR _regs[esi*4], edi
	test	edi, edi
	setl	dl
	test	edi, edi
	sete	bl
	test	eax, eax
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$79792[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _dst$79784[ebp]
	and	bl, dl
	cmp	eax, ecx
	pop	edi
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _flgn$79792[ebp]
	mov	BYTE PTR _regflags+3, bl
	test	eax, eax
	setne	dl
	pop	esi
	mov	BYTE PTR _regflags, dl
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_90b0_0@4 ENDP


@op_100_0@4 PROC NEAR
	_start_func  'op_100_0'
	mov	eax, ecx
	shr	ecx, 1
	and	ecx, 7
	shr	eax, 8
	mov	ecx, DWORD PTR _regs[ecx*4]
	and	eax, 7
	and	ecx, 31					; 0000001fH
	mov	edx, DWORD PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	sar	edx, cl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_100_0@4 ENDP


@op_3120_0@4 PROC NEAR
	_start_func  'op_3120_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	and	ecx, 7
	sub	esi, 2
	mov	edi, ecx
	xor	edx, edx
	mov	cx, WORD PTR [esi+ebp]
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	eax, DWORD PTR _regs[edi*4+32]
	mov	dl, ch
	mov	dh, cl
	xor	ecx, ecx
	sub	eax, 2
	cmp	dx, cx
	sete	bl
	cmp	dx, cx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	DWORD PTR _regs[edi*4+32], eax
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, dh
	mov	BYTE PTR _regflags+1, bl
	mov	ch, dl
	mov	WORD PTR [eax+ebp], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3120_0@4 ENDP


@op_d1f0_0@4 PROC NEAR
	_start_func  'op_d1f0_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	mov	ecx, DWORD PTR _regs[esi*4+32]
	add	ecx, eax
	mov	DWORD PTR _regs[esi*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d1f0_0@4 ENDP


@op_c050_0@4 PROC NEAR
	_start_func  'op_c050_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	cx, WORD PTR [ecx+edx]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	and	dx, WORD PTR _regs[eax*4]
	mov	ecx, edx
	xor	edx, edx
	cmp	cx, dx
	mov	WORD PTR _regs[eax*4], cx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c050_0@4 ENDP


@op_113c_0@4 PROC NEAR
	_start_func  'op_113c_0'
	shr	ecx, 1
	mov	dl, BYTE PTR [eax+3]
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _areg_byteinc[ecx*4]
	lea	esi, DWORD PTR _regs[ecx*4+32]
	xor	cl, cl
	sub	eax, edi
	cmp	dl, cl
	sete	bl
	cmp	dl, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	DWORD PTR [esi], eax
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [ecx+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_113c_0@4 ENDP


@op_30d0_0@4 PROC NEAR
	_start_func  'op_30d0_0'
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	shr	eax, 1
	mov	cx, WORD PTR [ecx+esi]
	and	eax, 7
	mov	dl, ch
	mov	dh, cl
	mov	ecx, edx
	mov	edx, DWORD PTR _regs[eax*4+32]
	lea	edi, DWORD PTR [edx+2]
	mov	DWORD PTR _regs[eax*4+32], edi
	xor	eax, eax
	cmp	cx, ax
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	cx, ax
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags, al
	xor	eax, eax
	mov	al, ch
	mov	BYTE PTR _regflags+1, bl
	mov	ah, cl
	mov	WORD PTR [esi+edx], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30d0_0@4 ENDP


@op_8f0_0@4 PROC NEAR
	_start_func  'op_8f0_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	esi, eax
	mov	dl, bh
	and	edx, 7
	mov	al, BYTE PTR [edi+esi]
	mov	cl, dl
	mov	bl, al
	sar	bl, cl
	movsx	ecx, dx
	mov	dl, 1
	shl	dl, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	or	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8f0_0@4 ENDP


@op_313b_0@4 PROC NEAR
	_start_func  'op_313b_0'
	shr	ecx, 1
	and	ecx, 7
	mov	edi, DWORD PTR _regs+96
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edi
	mov	DWORD PTR _regs+92, eax
	add	ecx, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [edi+eax]
	mov	BYTE PTR _regflags+2, dl
	mov	cl, ah
	mov	BYTE PTR _regflags+3, dl
	mov	ch, al
	mov	eax, ecx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	sub	ecx, 2
	cmp	ax, dx
	sete	bl
	cmp	ax, dx
	mov	DWORD PTR _regs[esi*4+32], ecx
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	WORD PTR [edi+ecx], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_313b_0@4 ENDP


@op_51e8_0@4 PROC NEAR
	_start_func  'op_51e8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, edx
	mov	BYTE PTR [ecx+esi], 0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_51e8_0@4 ENDP


@op_d150_0@4 PROC NEAR
	_start_func  'op_d150_0'
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	eax, 1
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	eax, 7
	xor	edx, edx
	mov	di, WORD PTR _regs[eax*4]
	mov	ax, WORD PTR [ecx+ebp]
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	movsx	eax, si
	movsx	ecx, di
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	di, di
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, di
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d150_0@4 ENDP


@op_3088_0@4 PROC NEAR
	_start_func  'op_3088_0'
	mov	eax, ecx
	xor	edx, edx
	shr	eax, 8
	and	eax, 7
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	ax, WORD PTR _regs[eax*4+32]
	cmp	ax, dx
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	ecx, 1
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3088_0@4 ENDP


_src$79935 = -8
_newv$79941 = -4
@op_5028_0@4 PROC NEAR
	_start_func  'op_5028_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	mov	ebx, DWORD PTR _imm8_table[eax*4]
	mov	ax, WORD PTR [edx+2]
	xor	edx, edx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	DWORD PTR _src$79935[esp+20], ebx
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	add	esi, DWORD PTR _regs[ecx*4+32]
	movsx	ecx, bl
	mov	al, BYTE PTR [edi+esi]
	movsx	edx, al
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$79941[esp+20], ecx
	sete	cl
	test	bl, bl
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	al, al
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$79935[esp+20]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$79941[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5028_0@4 ENDP


@op_3138_0@4 PROC NEAR
	_start_func  'op_3138_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	shr	ecx, 1
	mov	ax, WORD PTR [edx+esi]
	xor	edx, edx
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	eax, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	sub	edx, 2
	mov	DWORD PTR _regs[ecx*4+32], edx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	ch, al
	mov	WORD PTR [esi+edx], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3138_0@4 ENDP


@op_20b0_0@4 PROC NEAR
	_start_func  'op_20b0_0'
	push	esi
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	shr	esi, 1
	and	esi, 7
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, dl
	mov	esi, DWORD PTR _regs[esi*4+32]
	add	esi, ecx
	bswap	eax
	mov	DWORD PTR [esi], eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20b0_0@4 ENDP


@op_10e8_0@4 PROC NEAR
	_start_func  'op_10e8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	and	esi, 7
	add	edx, eax
	lea	ecx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _areg_byteinc[esi*4]
	mov	al, BYTE PTR [edx+edi]
	mov	edx, DWORD PTR [ecx]
	add	esi, edx
	mov	DWORD PTR [ecx], esi
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+edx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10e8_0@4 ENDP


@op_217a_0@4 PROC NEAR
	_start_func  'op_217a_0'
	push	ebx
	push	esi
	mov	esi, ecx
	xor	edx, edx
	mov	ecx, DWORD PTR _regs+92
	xor	ebx, ebx
	push	edi
	mov	edi, DWORD PTR _regs+88
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	sub	edx, DWORD PTR _regs+96
	add	edx, ebx
	add	edx, edi
	mov	edi, DWORD PTR [edx+ecx+2]
	bswap	edi
	mov	ecx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	edi, eax
	mov	cx, WORD PTR [ecx+4]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	edi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 1
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_217a_0@4 ENDP


@op_5cc0_0@4 PROC NEAR
	_start_func  'op_5cc0_0'
	mov	dl, BYTE PTR _regflags
	mov	bl, BYTE PTR _regflags+3
	xor	eax, eax
	shr	ecx, 8
	and	ecx, 7
	cmp	dl, bl
	sete	al
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5cc0_0@4 ENDP


@op_b0fc_0@4 PROC NEAR
	_start_func  'op_b0fc_0'
	xor	edx, edx
	shr	ecx, 1
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	and	ecx, 7
	mov	esi, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	xor	edx, edx
	movsx	edi, si
	mov	eax, ecx
	sub	eax, edi
	test	ecx, ecx
	setl	dl
	mov	ebp, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	si, si
	setl	al
	cmp	eax, ebp
	je	SHORT $L112232
	cmp	edx, ebp
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L112233
$L112232:
	mov	BYTE PTR _regflags+3, 0
$L112233:
	mov	eax, DWORD PTR _regs+92
	cmp	edi, ecx
	seta	cl
	test	edx, edx
	setne	dl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b0fc_0@4 ENDP


@op_c30_0@4 PROC NEAR
	_start_func  'op_c30_0'
	shr	ecx, 8
	mov	bl, BYTE PTR [eax+3]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	movsx	edx, bl
	mov	cl, BYTE PTR [ecx+eax]
	movsx	eax, cl
	sub	eax, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	mov	esi, edx
	xor	edx, edx
	test	al, al
	setl	dl
	test	al, al
	mov	edi, edx
	sete	al
	xor	edx, edx
	mov	BYTE PTR _regflags+1, al
	test	bl, bl
	setl	dl
	cmp	edx, esi
	je	SHORT $L112241
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L112242
$L112241:
	mov	BYTE PTR _regflags+3, 0
$L112242:
	cmp	bl, cl
	seta	al
	test	edi, edi
	setne	cl
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c30_0@4 ENDP


@op_e000_0@4 PROC NEAR
	_start_func  'op_e000_0'
	mov	edi, ecx
	shr	edi, 8
	and	edi, 7
	xor	eax, eax
	shr	ecx, 1
	mov	al, BYTE PTR _regs[edi*4]
	and	ecx, 7
	mov	ebx, eax
	mov	BYTE PTR _regflags+3, 0
	mov	esi, DWORD PTR _imm8_table[ecx*4]
	shr	ebx, 7
	and	esi, 63					; 0000003fH
	and	ebx, 1
	cmp	esi, 8
	jb	SHORT $L80076
	mov	edx, ebx
	mov	BYTE PTR _regflags+2, bl
	neg	edx
	and	edx, 255				; 000000ffH
	mov	BYTE PTR _regflags+4, bl
	jmp	SHORT $L80078
$L80076:
	lea	ecx, DWORD PTR [esi-1]
	mov	edx, 255				; 000000ffH
	shr	eax, cl
	neg	ebx
	mov	cl, al
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, 8
	sub	ecx, esi
	shl	edx, cl
	shr	eax, 1
	and	eax, 255				; 000000ffH
	and	edx, ebx
	and	edx, 255				; 000000ffH
	or	edx, eax
$L80078:
	test	dl, dl
	sete	al
	mov	BYTE PTR _regflags+1, al
	mov	BYTE PTR _regs[edi*4], dl
	mov	eax, DWORD PTR _regs+92
	test	dl, dl
	setl	cl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e000_0@4 ENDP


@op_31b0_0@4 PROC NEAR
	_start_func  'op_31b0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	shr	esi, 1
	mov	ax, WORD PTR [ecx+eax]
	and	esi, 7
	mov	bl, ah
	mov	bh, al
	mov	eax, DWORD PTR _regs+92
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[esi*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31b0_0@4 ENDP


@op_8d0_0@4 PROC NEAR
	_start_func  'op_8d0_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	eax, eax
	mov	dl, BYTE PTR [edi+esi]
	mov	al, bh
	and	eax, 7
	mov	bl, dl
	mov	cl, al
	sar	bl, cl
	movsx	ecx, ax
	mov	al, 1
	shl	al, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	or	al, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8d0_0@4 ENDP


_dsta$80111 = -4
@op_d190_0@4 PROC NEAR
	_start_func  'op_d190_0'
	mov	ebp, esp
	push	ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	push	ebx
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	push	esi
	push	edi
	mov	edi, DWORD PTR _regs[eax*4]
	mov	esi, DWORD PTR [edx+ecx]
	bswap	esi
	mov	DWORD PTR _dsta$80111[ebp], ecx
	lea	edx, DWORD PTR [esi+edi]
	xor	eax, eax
	test	edx, edx
	setl	al
	test	edx, edx
	sete	cl
	test	esi, esi
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, al
	test	edi, edi
	setl	bl
	xor	bl, al
	not	esi
	and	cl, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, cl
	setb	cl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _dsta$80111[ebp]
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d190_0@4 ENDP


@op_3198_0@4 PROC NEAR
	_start_func  'op_3198_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	esi, ecx
	shr	esi, 8
	and	esi, 7
	xor	ebx, ebx
	mov	edi, DWORD PTR _regs[esi*4+32]
	shr	ecx, 1
	mov	ax, WORD PTR [edi+eax]
	add	edi, 2
	mov	bl, ah
	mov	DWORD PTR _regs[esi*4+32], edi
	mov	bh, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3198_0@4 ENDP


@op_30b0_0@4 PROC NEAR
	_start_func  'op_30b0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	esi, 1
	mov	dl, ah
	and	esi, 7
	mov	dh, al
	mov	BYTE PTR _regflags+1, bl
	mov	eax, DWORD PTR _regs[esi*4+32]
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30b0_0@4 ENDP


_src$80155 = -8
_newv$80161 = -4
@op_5038_0@4 PROC NEAR
	_start_func  'op_5038_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 1
	and	ecx, 7
	or	esi, eax
	mov	ecx, DWORD PTR _imm8_table[ecx*4]
	mov	al, BYTE PTR [edi+esi]
	movsx	edx, cl
	movsx	ebx, al
	add	edx, ebx
	xor	ebx, ebx
	test	dl, dl
	setl	bl
	test	dl, dl
	mov	DWORD PTR _newv$80161[esp+20], edx
	mov	DWORD PTR _src$80155[esp+20], ecx
	sete	dl
	test	cl, cl
	setl	cl
	xor	cl, bl
	mov	BYTE PTR _regflags+1, dl
	test	al, al
	setl	dl
	xor	dl, bl
	and	cl, dl
	mov	dl, BYTE PTR _src$80155[esp+20]
	not	al
	cmp	al, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, BYTE PTR _newv$80161[esp+20]
	setb	al
	test	ebx, ebx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	setne	al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR [edi+esi], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5038_0@4 ENDP


_newv$80183 = -4
@op_50b8_0@4 PROC NEAR
	_start_func  'op_50b8_0'
	mov	ebp, esp
	push	ecx
	xor	edx, edx
	push	ebx
	push	esi
	mov	ax, WORD PTR [eax+2]
	push	edi
	mov	dl, ah
	movsx	edi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	edi, eax
	shr	ecx, 1
	mov	esi, DWORD PTR [edx+edi]
	bswap	esi
	and	ecx, 7
	mov	ecx, DWORD PTR _imm8_table[ecx*4]
	lea	edx, DWORD PTR [esi+ecx]
	xor	eax, eax
	test	edx, edx
	setl	al
	test	edx, edx
	mov	DWORD PTR _newv$80183[ebp], edx
	sete	dl
	test	esi, esi
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, al
	test	ecx, ecx
	setl	bl
	xor	bl, al
	not	esi
	and	dl, bl
	cmp	esi, ecx
	setb	cl
	test	eax, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+3, dl
	setne	al
	mov	BYTE PTR _regflags, al
	add	edi, ecx
	mov	edx, DWORD PTR _newv$80183[ebp]
	bswap	edx
	mov	DWORD PTR [edi], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_50b8_0@4 ENDP


_dsta$80201 = -8
_flgn$80210 = -4
@op_9190_0@4 PROC NEAR
	_start_func  'op_9190_0'
	mov	ebp, esp
	sub	esp, 8
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	shr	eax, 1
	and	ecx, 7
	push	ebx
	and	eax, 7
	push	esi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	push	edi
	mov	edi, DWORD PTR _regs[eax*4]
	mov	DWORD PTR _dsta$80201[ebp], ecx
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	mov	esi, eax
	xor	ecx, ecx
	sub	esi, edi
	test	eax, eax
	setl	cl
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	edi, edi
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$80210[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$80210[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _dsta$80201[ebp]
	cmp	edi, eax
	seta	al
	test	ecx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	BYTE PTR _regflags+3, bl
	setne	al
	mov	BYTE PTR _regflags, al
	lea	eax, DWORD PTR [ecx+edx]
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9190_0@4 ENDP


_src$80219 = -4
_dst$80224 = -9
_flgn$80232 = -8
@op_5138_0@4 PROC NEAR
	_start_func  'op_5138_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 1
	and	ecx, 7
	or	esi, eax
	mov	ecx, DWORD PTR _imm8_table[ecx*4]
	mov	bl, BYTE PTR [edi+esi]
	movsx	edx, cl
	movsx	eax, bl
	sub	eax, edx
	xor	edx, edx
	test	bl, bl
	mov	BYTE PTR _dst$80224[esp+24], bl
	mov	DWORD PTR _src$80219[esp+24], ecx
	setl	dl
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$80232[esp+24], ebx
	sete	bl
	test	cl, cl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$80232[esp+24]
	setl	cl
	xor	cl, dl
	xor	bl, dl
	mov	dl, BYTE PTR _dst$80224[esp+24]
	and	cl, bl
	mov	bl, BYTE PTR _src$80219[esp+24]
	mov	BYTE PTR _regflags+3, cl
	cmp	bl, dl
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$80232[esp+24]
	test	ecx, ecx
	setne	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5138_0@4 ENDP


@op_3130_0@4 PROC NEAR
	_start_func  'op_3130_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [edi+eax]
	mov	BYTE PTR _regflags+2, dl
	mov	cl, ah
	mov	BYTE PTR _regflags+3, dl
	mov	ch, al
	mov	eax, ecx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	sub	ecx, 2
	cmp	ax, dx
	sete	bl
	cmp	ax, dx
	mov	DWORD PTR _regs[esi*4+32], ecx
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	WORD PTR [edi+ecx], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3130_0@4 ENDP


@op_81e8_0@4 PROC NEAR
	_start_func  'op_81e8_0'
	mov	edi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	esi, ecx
	mov	ax, WORD PTR [edi+2]
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	and	esi, 7
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	ebp, DWORD PTR _regs[esi*4]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	cmp	ax, bx
	jne	SHORT $L80262
	mov	eax, DWORD PTR _regs+88
	mov	esi, DWORD PTR _regs+96
	sub	eax, esi
	add	eax, edi
	push	eax
	push	5
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L80262:
	movsx	ecx, ax
	mov	eax, ebp
	cdq
	idiv	ecx
	mov	edi, eax
	mov	eax, ebp
	cdq
	idiv	ecx
	mov	eax, edi
	and	eax, -32768				; ffff8000H
	je	SHORT $L80274
	cmp	eax, -32768				; ffff8000H
	je	SHORT $L80274
	mov	al, 1
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	jmp	SHORT $L80275
$L80274:
	xor	ecx, ecx
	cmp	dx, bx
	setl	cl
	xor	eax, eax
	cmp	ebp, ebx
	setl	al
	cmp	ecx, eax
	je	SHORT $L80279
	neg	edx
$L80279:
	cmp	di, bx
	mov	BYTE PTR _regflags+2, bl
	sete	cl
	cmp	di, bx
	mov	BYTE PTR _regflags+3, bl
	setl	al
	and	edx, 65535				; 0000ffffH
	and	edi, 65535				; 0000ffffH
	shl	edx, 16					; 00000010H
	or	edx, edi
	mov	BYTE PTR _regflags+1, cl
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs[esi*4], edx
$L80275:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_81e8_0@4 ENDP


@op_3090_0@4 PROC NEAR
	_start_func  'op_3090_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	ax, WORD PTR [edx+esi]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	ecx, 1
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	BYTE PTR _regflags+1, bl
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3090_0@4 ENDP


@op_81c0_0@4 PROC NEAR
	_start_func  'op_81c0_0'
	mov	edi, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	edi, 1
	mov	cx, WORD PTR _regs[ecx*4]
	and	edi, 7
	test	cx, cx
	mov	ebp, DWORD PTR _regs[edi*4]
	jne	SHORT $L80306
	mov	eax, DWORD PTR _regs+88
	mov	esi, DWORD PTR _regs+96
	mov	edx, DWORD PTR _regs+92
	sub	eax, esi
	add	eax, edx
	push	eax
	push	5
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L80306:
	mov	eax, ebp
	movsx	ecx, cx
	cdq
	idiv	ecx
	mov	esi, eax
	mov	eax, ebp
	cdq
	idiv	ecx
	mov	eax, esi
	and	eax, -32768				; ffff8000H
	je	SHORT $L80318
	cmp	eax, -32768				; ffff8000H
	je	SHORT $L80318
	mov	al, 1
	mov	BYTE PTR _regflags+2, 0
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	jmp	SHORT $L80319
$L80318:
	xor	ecx, ecx
	test	dx, dx
	setl	cl
	xor	eax, eax
	test	ebp, ebp
	setl	al
	cmp	ecx, eax
	je	SHORT $L80323
	neg	edx
$L80323:
	test	si, si
	sete	cl
	test	si, si
	setl	al
	and	edx, 65535				; 0000ffffH
	and	esi, 65535				; 0000ffffH
	shl	edx, 16					; 00000010H
	or	edx, esi
	mov	BYTE PTR _regflags+2, 0
	mov	BYTE PTR _regflags+3, 0
	mov	BYTE PTR _regflags+1, cl
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs[edi*4], edx
$L80319:
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_81c0_0@4 ENDP


_flgn$80347 = -8
_x$112488 = -4
@op_51a8_0@4 PROC NEAR
	_start_func  'op_51a8_0'
	mov	ebp, esp
	sub	esp, 8
	mov	edx, eax
	push	ebx
	xor	ebx, ebx
	push	esi
	mov	dx, WORD PTR [edx+2]
	mov	eax, ecx
	mov	bl, dh
	push	edi
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 8
	and	ecx, 7
	or	esi, edx
	shr	eax, 1
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, edx
	and	eax, 7
	mov	edx, DWORD PTR [ecx+esi]
	bswap	edx
	mov	eax, DWORD PTR _imm8_table[eax*4]
	mov	DWORD PTR _x$112488[ebp], edx
	mov	edi, edx
	xor	ecx, ecx
	sub	edi, eax
	test	edx, edx
	setl	cl
	xor	edx, edx
	test	edi, edi
	setl	dl
	test	edi, edi
	sete	bl
	test	eax, eax
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$80347[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$80347[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _x$112488[ebp]
	mov	BYTE PTR _regflags+3, bl
	cmp	eax, edx
	seta	al
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _MEMBaseDiff
	setne	dl
	mov	BYTE PTR _regflags, dl
	add	esi, eax
	bswap	edi
	mov	DWORD PTR [esi], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_51a8_0@4 ENDP


@op_2188_0@4 PROC NEAR
	_start_func  'op_2188_0'
	mov	eax, ecx
	push	esi
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2188_0@4 ENDP


@op_2198_0@4 PROC NEAR
	_start_func  'op_2198_0'
	mov	eax, ecx
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	esi, DWORD PTR [edx+esi]
	bswap	esi
	mov	edx, DWORD PTR _regs[eax*4+32]
	add	edx, 4
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 1
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2198_0@4 ENDP


@op_c0fc_0@4 PROC NEAR
	_start_func  'op_c0fc_0'
	shr	ecx, 1
	and	ecx, 7
	xor	edx, edx
	mov	esi, ecx
	mov	cx, WORD PTR [eax+2]
	mov	eax, ecx
	mov	dh, cl
	and	eax, 65535				; 0000ffffH
	and	edx, 65535				; 0000ffffH
	shr	eax, 8
	xor	ecx, ecx
	or	eax, edx
	mov	cx, WORD PTR _regs[esi*4]
	imul	eax, ecx
	xor	ecx, ecx
	mov	DWORD PTR _regs[esi*4], eax
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	add	eax, 4
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c0fc_0@4 ENDP


@op_50d8_0@4 PROC NEAR
	_start_func  'op_50d8_0'
	shr	ecx, 8
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	add	ecx, edx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR [eax+edx], 255			; 000000ffH
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_50d8_0@4 ENDP


_dsta$80406 = -8
_flgn$80415 = -4
@op_9198_0@4 PROC NEAR
	_start_func  'op_9198_0'
	mov	ebp, esp
	sub	esp, 8
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 1
	shr	eax, 8
	push	ebx
	and	ecx, 7
	push	esi
	and	eax, 7
	push	edi
	mov	edi, DWORD PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	DWORD PTR _dsta$80406[ebp], ecx
	mov	ecx, DWORD PTR [edx+ecx]
	bswap	ecx
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	esi, ecx
	add	edx, 4
	sub	esi, edi
	mov	DWORD PTR _regs[eax*4+32], edx
	xor	eax, eax
	test	ecx, ecx
	setl	al
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	edi, edi
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$80415[ebp], edx
	setl	bl
	xor	bl, al
	xor	dl, al
	and	bl, dl
	mov	edx, DWORD PTR _dsta$80406[ebp]
	cmp	edi, ecx
	mov	ecx, DWORD PTR _flgn$80415[ebp]
	seta	al
	test	ecx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	BYTE PTR _regflags+3, bl
	setne	al
	mov	BYTE PTR _regflags, al
	lea	eax, DWORD PTR [ecx+edx]
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9198_0@4 ENDP


@op_1038_0@4 PROC NEAR
	_start_func  'op_1038_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [edx+eax]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1038_0@4 ENDP


@op_80f8_0@4 PROC NEAR
	_start_func  'op_80f8_0'
	shr	ecx, 1
	and	ecx, 7
	mov	edi, ecx
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	xor	ebx, ebx
	mov	ebp, DWORD PTR _regs[edi*4]
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	cmp	si, bx
	jne	SHORT $L80447
	mov	eax, DWORD PTR _regs+88
	mov	esi, DWORD PTR _regs+96
	sub	eax, esi
	add	eax, ecx
	push	eax
	push	5
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L80447:
	and	esi, 65535				; 0000ffffH
	mov	eax, ebp
	xor	edx, edx
	div	esi
	mov	ecx, eax
	cmp	ecx, 65535				; 0000ffffH
	jbe	SHORT $L80461
	mov	al, 1
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	jmp	SHORT $L80460
$L80461:
	cmp	cx, bx
	mov	BYTE PTR _regflags+2, bl
	sete	dl
	cmp	cx, bx
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, ebp
	xor	edx, edx
	and	ecx, 65535				; 0000ffffH
	div	esi
	mov	BYTE PTR _regflags+3, bl
	shl	edx, 16					; 00000010H
	or	edx, ecx
	mov	DWORD PTR _regs[edi*4], edx
$L80460:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_80f8_0@4 ENDP


@op_2020_0@4 PROC NEAR
	_start_func  'op_2020_0'
	mov	eax, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, 4
	mov	esi, DWORD PTR [esi+edx]
	bswap	esi
	mov	DWORD PTR _regs[eax*4+32], edx
	xor	eax, eax
	cmp	esi, eax
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	setl	al
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs[ecx*4], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2020_0@4 ENDP


@op_d0d0_0@4 PROC NEAR
	_start_func  'op_d0d0_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	xor	ebx, ebx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	shr	eax, 1
	mov	cx, WORD PTR [ecx+edx]
	xor	edx, edx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	and	eax, 7
	or	edx, ecx
	mov	ecx, DWORD PTR _regs[eax*4+32]
	add	ecx, edx
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d0d0_0@4 ENDP


@op_d0f0_0@4 PROC NEAR
	_start_func  'op_d0f0_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	mov	dl, ah
	movsx	ecx, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	or	ecx, eax
	mov	eax, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	mov	DWORD PTR _regs[esi*4+32], eax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d0f0_0@4 ENDP


@op_810_0@4 PROC NEAR
	_start_func  'op_810_0'
	shr	ecx, 8
	mov	dx, WORD PTR [eax+2]
	and	ecx, 7
	xor	ebx, ebx
	add	eax, 4
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	bl, dh
	mov	edx, DWORD PTR _MEMBaseDiff
	and	bl, 7
	mov	dl, BYTE PTR [ecx+edx]
	mov	cl, bl
	shr	dl, cl
	mov	DWORD PTR _regs+92, eax
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_810_0@4 ENDP


@op_44d8_0@4 PROC NEAR
	_start_func  'op_44d8_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	bx, WORD PTR [eax+edx]
	add	eax, 2
	mov	DWORD PTR _regs[ecx*4+32], eax
	call	_MakeSR@0
	xor	eax, eax
	mov	ah, BYTE PTR _regs+77
	mov	al, bh
	mov	WORD PTR _regs+76, ax
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44d8_0@4 ENDP


@op_8128_0@4 PROC NEAR
	_start_func  'op_8128_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	edx, ecx
	or	esi, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	edx, 8
	and	edx, 7
	shr	ecx, 1
	mov	ebx, DWORD PTR _regs[edx*4+32]
	and	ecx, 7
	add	esi, ebx
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	dl, BYTE PTR [eax+esi]
	or	cl, dl
	mov	dl, 0
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [eax+esi], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8128_0@4 ENDP


@op_2060_0@4 PROC NEAR
	_start_func  'op_2060_0'
	mov	eax, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, 4
	mov	esi, DWORD PTR [esi+edx]
	bswap	esi
	shr	ecx, 1
	and	ecx, 7
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2060_0@4 ENDP


@op_c028_0@4 PROC NEAR
	_start_func  'op_c028_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	add	edx, eax
	mov	al, BYTE PTR [edx+ecx]
	mov	bl, BYTE PTR _regs[esi*4]
	and	al, bl
	mov	cl, 0
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c028_0@4 ENDP


@op_40c0_0@4 PROC NEAR
	_start_func  'op_40c0_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	mov	esi, ecx
	jne	SHORT $L80557
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L80557:
	call	_MakeSR@0
	mov	ax, WORD PTR _regs+76
	shr	esi, 8
	and	esi, 7
	mov	WORD PTR _regs[esi*4], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40c0_0@4 ENDP


@op_90f8_0@4 PROC NEAR
	_start_func  'op_90f8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 1
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	sub	ebx, edx
	mov	DWORD PTR _regs[ecx*4+32], ebx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_90f8_0@4 ENDP


@op_68_0@4 PROC NEAR
	_start_func  'op_68_0'
	mov	esi, ecx
	mov	cx, WORD PTR [eax+4]
	mov	di, WORD PTR [eax+2]
	xor	eax, eax
	xor	edx, edx
	mov	al, ch
	mov	dh, cl
	shr	esi, 8
	movsx	eax, ax
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	xor	edx, edx
	mov	ebx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	add	eax, ebx
	mov	cx, WORD PTR [esi+eax]
	or	ecx, edi
	mov	dl, ch
	mov	dh, cl
	mov	ecx, edx
	xor	edx, edx
	cmp	cx, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ch
	mov	BYTE PTR _regflags+1, bl
	mov	dh, cl
	mov	WORD PTR [esi+eax], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_68_0@4 ENDP


@op_46c0_0@4 PROC NEAR
	_start_func  'op_46c0_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L80593
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L80593:
	shr	ecx, 8
	and	ecx, 7
	mov	ax, WORD PTR _regs[ecx*4]
	mov	WORD PTR _regs+76, ax
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46c0_0@4 ENDP


@op_250_0@4 PROC NEAR
	_start_func  'op_250_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [eax+2]
	xor	edx, edx
	mov	cx, WORD PTR [edi+esi]
	mov	dl, ch
	mov	dh, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	and	edx, ecx
	xor	ecx, ecx
	mov	eax, edx
	mov	BYTE PTR _regflags+2, cl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_250_0@4 ENDP


@op_edc0_0@4 PROC NEAR
	_start_func  'op_edc0_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	ebx, ecx
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	edx, eax
	and	edx, 2048				; 00000800H
	test	dx, dx
	movsx	edi, ax
	je	SHORT $L112779
	mov	ecx, edi
	sar	ecx, 6
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4]
	jmp	SHORT $L112780
$L112779:
	mov	esi, edi
	sar	esi, 6
	and	esi, 31					; 0000001fH
$L112780:
	test	al, 32					; 00000020H
	je	SHORT $L112781
	mov	edx, edi
	and	edx, 7
	mov	eax, DWORD PTR _regs[edx*4]
	jmp	SHORT $L112782
$L112781:
	mov	eax, edi
$L112782:
	mov	ecx, esi
	lea	edx, DWORD PTR [eax-1]
	mov	eax, DWORD PTR _regs[ebx*4]
	and	ecx, 31					; 0000001fH
	and	edx, 31					; 0000001fH
	shl	eax, cl
	inc	edx
	mov	ecx, 32					; 00000020H
	sub	ecx, edx
	shr	eax, cl
	lea	ecx, DWORD PTR [edx-1]
	mov	edx, 1
	shl	edx, cl
	test	edx, eax
	setne	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	sete	bl
	cmp	edx, ecx
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags+2, cl
	je	SHORT $L112788
$L80621:
	test	edx, eax
	jne	SHORT $L112788
	shr	edx, 1
	inc	esi
	cmp	edx, ecx
	jne	SHORT $L80621
$L112788:
	sar	edi, 12					; 0000000cH
	and	edi, 7
	mov	DWORD PTR _regs[edi*4], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_edc0_0@4 ENDP


@op_4698_0@4 PROC NEAR
	_start_func  'op_4698_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	push	ebx
	shr	ecx, 8
	and	ecx, 7
	push	esi
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR [eax+edx]
	bswap	eax
	mov	esi, DWORD PTR _regs[ecx*4+32]
	add	esi, 4
	mov	DWORD PTR _regs[ecx*4+32], esi
	xor	ecx, ecx
	not	eax
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4698_0@4 ENDP


@op_b010_0@4 PROC NEAR
	_start_func  'op_b010_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	xor	ebx, ebx
	mov	dl, BYTE PTR [edx+eax]
	mov	cl, BYTE PTR _regs[ecx*4]
	movsx	eax, cl
	movsx	esi, dl
	sub	eax, esi
	test	cl, cl
	setl	bl
	mov	esi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dl, dl
	setl	al
	cmp	eax, esi
	mov	edi, ebx
	je	SHORT $L112806
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L112807
$L112806:
	mov	BYTE PTR _regflags+3, 0
$L112807:
	mov	eax, DWORD PTR _regs+92
	cmp	dl, cl
	seta	cl
	test	edi, edi
	setne	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b010_0@4 ENDP


@op_40_0@4 PROC NEAR
	_start_func  'op_40_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	dh, al
	or	dx, WORD PTR _regs[ecx*4]
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	WORD PTR _regs[ecx*4], ax
	sete	bl
	cmp	ax, dx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	add	eax, 4
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40_0@4 ENDP


_dstreg$ = -4
@op_d0b8_0@4 PROC NEAR
	_start_func  'op_d0b8_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	push	esi
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 1
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	push	edi
	mov	edi, DWORD PTR [edx+eax]
	bswap	edi
	mov	DWORD PTR _dstreg$[ebp], ecx
	mov	esi, DWORD PTR _regs[ecx*4]
	xor	eax, eax
	lea	edx, DWORD PTR [edi+esi]
	test	edx, edx
	setl	al
	test	edx, edx
	sete	cl
	test	edi, edi
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, al
	test	esi, esi
	setl	bl
	xor	bl, al
	not	esi
	and	cl, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, cl
	pop	edi
	setb	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _dstreg$[ebp]
	pop	esi
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs[ecx*4], edx
	mov	eax, DWORD PTR _regs+92
	pop	ebx
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d0b8_0@4 ENDP


@op_80c0_0@4 PROC NEAR
	_start_func  'op_80c0_0'
	mov	esi, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	esi, 1
	mov	cx, WORD PTR _regs[ecx*4]
	and	esi, 7
	test	cx, cx
	mov	ebp, DWORD PTR _regs[esi*4]
	jne	SHORT $L80700
	mov	eax, DWORD PTR _regs+88
	mov	esi, DWORD PTR _regs+96
	mov	edx, DWORD PTR _regs+92
	sub	eax, esi
	add	eax, edx
	push	eax
	push	5
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L80700:
	push	edi
	mov	edi, ecx
	and	edi, 65535				; 0000ffffH
	mov	eax, ebp
	xor	edx, edx
	div	edi
	mov	ecx, eax
	cmp	ecx, 65535				; 0000ffffH
	jbe	SHORT $L80714
	mov	al, 1
	mov	BYTE PTR _regflags+2, 0
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	jmp	SHORT $L80713
$L80714:
	test	cx, cx
	sete	dl
	test	cx, cx
	setl	al
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, al
	mov	eax, ebp
	xor	edx, edx
	div	edi
	and	ecx, 65535				; 0000ffffH
	mov	BYTE PTR _regflags+2, 0
	mov	BYTE PTR _regflags+3, 0
	shl	edx, 16					; 00000010H
	or	edx, ecx
	mov	DWORD PTR _regs[esi*4], edx
$L80713:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_80c0_0@4 ENDP


@op_20e0_0@4 PROC NEAR
	_start_func  'op_20e0_0'
	mov	eax, ecx
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	sub	edx, 4
	mov	esi, DWORD PTR [esi+edx]
	bswap	esi
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	lea	edx, DWORD PTR [eax+4]
	mov	DWORD PTR _regs[ecx*4+32], edx
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20e0_0@4 ENDP


@op_41d0_0@4 PROC NEAR
	_start_func  'op_41d0_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41d0_0@4 ENDP


@op_50e0_0@4 PROC NEAR
	_start_func  'op_50e0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	eax, esi
	mov	DWORD PTR [edx], eax
	mov	BYTE PTR [ecx+eax], 255			; 000000ffH
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_50e0_0@4 ENDP


@op_10d0_0@4 PROC NEAR
	_start_func  'op_10d0_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[eax*4+32]
	lea	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	shr	ecx, 8
	and	ecx, 7
	add	eax, esi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	cl, BYTE PTR [ecx+edi]
	mov	DWORD PTR [edx], eax
	xor	al, al
	cmp	cl, al
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	cl, al
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR [edi+esi], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10d0_0@4 ENDP


@op_268_0@4 PROC NEAR
	_start_func  'op_268_0'
	mov	edx, eax
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+2]
	mov	dx, WORD PTR [edx+4]
	mov	bl, dh
	movsx	esi, bx
	xor	ebx, ebx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 8
	and	ecx, 7
	or	esi, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	add	esi, edx
	xor	edx, edx
	mov	cx, WORD PTR [edi+esi]
	mov	dl, ch
	mov	dh, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	and	edx, ecx
	xor	ecx, ecx
	mov	eax, edx
	mov	BYTE PTR _regflags+2, cl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_268_0@4 ENDP


@op_4870_0@4 PROC NEAR
	_start_func  'op_4870_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _regs+60
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, -4					; fffffffcH
	mov	DWORD PTR _regs+60, ecx
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4870_0@4 ENDP


@op_31e8_0@4 PROC NEAR
	_start_func  'op_31e8_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	edi, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	add	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [edx+edi]
	xor	edx, edx
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	cx, WORD PTR [esi+4]
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31e8_0@4 ENDP


@op_c10_0@4 PROC NEAR
	_start_func  'op_c10_0'
	shr	ecx, 8
	mov	dl, BYTE PTR [eax+3]
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	movsx	esi, dl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	xor	ebx, ebx
	mov	cl, BYTE PTR [ecx+eax]
	movsx	eax, cl
	sub	eax, esi
	test	cl, cl
	setl	bl
	mov	esi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dl, dl
	setl	al
	cmp	eax, esi
	mov	edi, ebx
	je	SHORT $L112973
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L112974
$L112973:
	mov	BYTE PTR _regflags+3, 0
$L112974:
	mov	eax, DWORD PTR _regs+92
	cmp	dl, cl
	seta	cl
	test	edi, edi
	setne	dl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c10_0@4 ENDP


@op_57e0_0@4 PROC NEAR
	_start_func  'op_57e0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	mov	eax, DWORD PTR _regs[ecx*4+32]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	sub	eax, esi
	movsx	ecx, BYTE PTR _regflags+1
	neg	ecx
	mov	DWORD PTR [edx], eax
	mov	edx, DWORD PTR _MEMBaseDiff
	sbb	cl, cl
	and	ecx, 255				; 000000ffH
	mov	BYTE PTR [edx+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_57e0_0@4 ENDP


_dstreg$ = -8
_flgn$80843 = -4
@op_90b8_0@4 PROC NEAR
	_start_func  'op_90b8_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	push	esi
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 1
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	push	edi
	mov	edi, DWORD PTR [edx+eax]
	bswap	edi
	mov	DWORD PTR _dstreg$[ebp], ecx
	mov	eax, DWORD PTR _regs[ecx*4]
	xor	ecx, ecx
	mov	esi, eax
	sub	esi, edi
	test	eax, eax
	setl	cl
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	edi, edi
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$80843[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$80843[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _dstreg$[ebp]
	cmp	edi, eax
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	test	ecx, ecx
	mov	DWORD PTR _regs[edx*4], esi
	mov	eax, DWORD PTR _regs+92
	setne	cl
	add	eax, 4
	pop	edi
	mov	BYTE PTR _regflags+3, bl
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	BYTE PTR _regflags, cl
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_90b8_0@4 ENDP


@op_5ec0_0@4 PROC NEAR
	_start_func  'op_5ec0_0'
	mov	al, BYTE PTR _regflags+1
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	jne	SHORT $L113073
	mov	al, BYTE PTR _regflags
	mov	dl, BYTE PTR _regflags+3
	cmp	al, dl
	jne	SHORT $L113073
	mov	eax, 1
	jmp	SHORT $L113074
$L113073:
	xor	eax, eax
$L113074:
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5ec0_0@4 ENDP


@op_21c0_0@4 PROC NEAR
	_start_func  'op_21c0_0'
	push	esi
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4]
	mov	cx, WORD PTR [eax+2]
	xor	eax, eax
	cmp	esi, eax
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21c0_0@4 ENDP


@op_1c0_0@4 PROC NEAR
	_start_func  'op_1c0_0'
	mov	eax, ecx
	shr	ecx, 1
	shr	eax, 8
	and	ecx, 7
	and	eax, 7
	mov	esi, DWORD PTR _regs[ecx*4]
	mov	edi, DWORD PTR _regs[eax*4]
	and	esi, 31					; 0000001fH
	mov	edx, edi
	mov	ecx, esi
	sar	edx, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	edx, 1
	shl	edx, cl
	or	edx, edi
	mov	DWORD PTR _regs[eax*4], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1c0_0@4 ENDP


@op_d070_0@4 PROC NEAR
	_start_func  'op_d070_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	mov	esi, ecx
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	di, WORD PTR _regs[esi*4]
	movsx	ebp, di
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	xor	eax, eax
	movsx	edx, cx
	add	ebp, edx
	test	bp, bp
	setl	al
	test	bp, bp
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	mov	WORD PTR _regs[esi*4], bp
	setl	dl
	xor	dl, al
	test	cx, cx
	setl	bl
	xor	bl, al
	not	edi
	and	dl, bl
	cmp	di, cx
	setb	cl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d070_0@4 ENDP


@op_228_0@4 PROC NEAR
	_start_func  'op_228_0'
	mov	edi, eax
	mov	esi, ecx
	xor	eax, eax
	mov	cx, WORD PTR [edi+4]
	xor	edx, edx
	mov	al, ch
	mov	dh, cl
	movsx	eax, ax
	movsx	ecx, dx
	shr	esi, 8
	and	esi, 7
	or	eax, ecx
	mov	dl, 0
	mov	ecx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	mov	cl, BYTE PTR [edi+3]
	mov	bl, BYTE PTR [esi+eax]
	mov	BYTE PTR _regflags+2, dl
	and	cl, bl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_228_0@4 ENDP


@op_90c8_0@4 PROC NEAR
	_start_func  'op_90c8_0'
	mov	eax, ecx
	shr	ecx, 8
	shr	eax, 1
	and	ecx, 7
	and	eax, 7
	movsx	ecx, WORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, ecx
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_90c8_0@4 ENDP


@op_4468_0@4 PROC NEAR
	_start_func  'op_4468_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	mov	edx, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	add	esi, edx
	mov	ax, WORD PTR [esi+ebp]
	mov	cl, ah
	mov	ch, al
	mov	edi, ecx
	xor	ecx, ecx
	movsx	eax, di
	neg	eax
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	and	dl, cl
	test	di, di
	mov	BYTE PTR _regflags+3, dl
	seta	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [esi+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4468_0@4 ENDP


@op_3048_0@4 PROC NEAR
	_start_func  'op_3048_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	movsx	edx, WORD PTR _regs[eax*4+32]
	and	ecx, 7
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3048_0@4 ENDP


@op_e8d0_0@4 PROC NEAR
	_start_func  'op_e8d0_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	shr	ecx, 8
	mov	eax, edx
	and	ecx, 7
	movsx	esi, dx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 2048				; 00000800H
	test	ax, ax
	mov	eax, esi
	je	SHORT $L113150
	sar	eax, 6
	and	eax, 7
	mov	eax, DWORD PTR _regs[eax*4]
	jmp	SHORT $L113151
$L113150:
	sar	eax, 6
	and	eax, 31					; 0000001fH
$L113151:
	test	dl, 32					; 00000020H
	je	SHORT $L113153
	and	esi, 7
	mov	esi, DWORD PTR _regs[esi*4]
$L113153:
	dec	esi
	mov	edx, eax
	and	esi, 31					; 0000001fH
	and	edx, -2147483648			; 80000000H
	inc	esi
	mov	edi, eax
	neg	edx
	sbb	edx, edx
	and	edx, -536870912				; e0000000H
	sar	edi, 3
	or	edx, edi
	add	ecx, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR [edx+ecx]
	bswap	edi
	mov	ebx, DWORD PTR _MEMBaseDiff
	mov	edx, eax
	xor	eax, eax
	and	edx, 7
	mov	al, BYTE PTR [ebx+ecx+4]
	mov	cl, 8
	sub	cl, dl
	shr	eax, cl
	mov	ecx, edx
	mov	edx, 1
	shl	edi, cl
	mov	ecx, 32					; 00000020H
	sub	ecx, esi
	or	eax, edi
	shr	eax, cl
	lea	ecx, DWORD PTR [esi-1]
	shl	edx, cl
	test	edx, eax
	setne	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	cmp	eax, ecx
	mov	eax, DWORD PTR _regs+92
	sete	dl
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+2, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e8d0_0@4 ENDP


@op_ebd0_0@4 PROC NEAR
	_start_func  'op_ebd0_0'
	mov	ebp, esp
	push	ecx
	xor	edx, edx
	push	esi
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	shr	ecx, 8
	mov	eax, edx
	and	ecx, 7
	movsx	esi, dx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 2048				; 00000800H
	test	ax, ax
	mov	DWORD PTR -4+[ebp], esi
	mov	eax, esi
	je	SHORT $L113171
	sar	eax, 6
	and	eax, 7
	mov	eax, DWORD PTR _regs[eax*4]
	jmp	SHORT $L113172
$L113171:
	sar	eax, 6
	and	eax, 31					; 0000001fH
$L113172:
	test	dl, 32					; 00000020H
	je	SHORT $L113174
	and	esi, 7
	mov	esi, DWORD PTR _regs[esi*4]
$L113174:
	dec	esi
	mov	edx, eax
	and	esi, 31					; 0000001fH
	and	edx, -2147483648			; 80000000H
	inc	esi
	push	ebx
	neg	edx
	push	edi
	mov	edi, eax
	sbb	edx, edx
	and	edx, -536870912				; e0000000H
	sar	edi, 3
	or	edx, edi
	add	ecx, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR [edx+ecx]
	bswap	edi
	mov	ebx, DWORD PTR _MEMBaseDiff
	mov	edx, eax
	xor	eax, eax
	and	edx, 7
	mov	al, BYTE PTR [ebx+ecx+4]
	mov	cl, 8
	sub	cl, dl
	shr	eax, cl
	mov	ecx, edx
	mov	edx, 1
	shl	edi, cl
	mov	ecx, 32					; 00000020H
	sub	ecx, esi
	or	eax, edi
	pop	edi
	shr	eax, cl
	lea	ecx, DWORD PTR [esi-1]
	shl	edx, cl
	test	edx, eax
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	mov	BYTE PTR _regflags+1, bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	pop	ebx
	je	SHORT $L80978
	cmp	esi, 32					; 00000020H
	je	SHORT $L113176
	or	edx, -1
	mov	ecx, esi
	shl	edx, cl
$L113176:
	or	eax, edx
$L80978:
	mov	ecx, DWORD PTR -4+[ebp]
	pop	esi
	sar	ecx, 12					; 0000000cH
	and	ecx, 7
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ebd0_0@4 ENDP


@op_8168_0@4 PROC NEAR
	_start_func  'op_8168_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	xor	ebx, ebx
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	edx, ecx
	or	esi, eax
	shr	edx, 8
	and	edx, 7
	shr	ecx, 1
	mov	edi, DWORD PTR _regs[edx*4+32]
	and	ecx, 7
	add	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR _regs[ecx*4]
	xor	ecx, ecx
	mov	dx, WORD PTR [edi+esi]
	mov	bl, dh
	mov	ch, dl
	or	ax, bx
	or	eax, ecx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8168_0@4 ENDP


@op_3118_0@4 PROC NEAR
	_start_func  'op_3118_0'
	mov	eax, ecx
	shr	eax, 8
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	eax, 7
	shr	ecx, 1
	mov	edi, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	xor	edx, edx
	mov	esi, ecx
	mov	cx, WORD PTR [edi+ebp]
	add	edi, 2
	mov	dl, ch
	mov	DWORD PTR _regs[eax*4+32], edi
	mov	eax, DWORD PTR _regs[esi*4+32]
	mov	dh, cl
	xor	ecx, ecx
	sub	eax, 2
	cmp	dx, cx
	sete	bl
	cmp	dx, cx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	DWORD PTR _regs[esi*4+32], eax
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, dh
	mov	BYTE PTR _regflags+1, bl
	mov	ch, dl
	mov	WORD PTR [eax+ebp], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3118_0@4 ENDP


@op_203a_0@4 PROC NEAR
	_start_func  'op_203a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	mov	eax, DWORD PTR [edx+esi+2]
	bswap	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_203a_0@4 ENDP


@op_53e8_0@4 PROC NEAR
	_start_func  'op_53e8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	mov	eax, DWORD PTR _regflags+1
	add	esi, DWORD PTR _regs[ecx*4+32]
	test	ah, ah
	jne	SHORT $L113275
	test	al, al
	jne	SHORT $L113275
	xor	eax, eax
	jmp	SHORT $L113276
$L113275:
	mov	eax, 1
$L113276:
	mov	ecx, DWORD PTR _MEMBaseDiff
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR [ecx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_53e8_0@4 ENDP


_src$81036 = -4
_dst$81041 = -9
_flgn$81049 = -8
@op_5128_0@4 PROC NEAR
	_start_func  'op_5128_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	xor	ebx, ebx
	mov	edx, DWORD PTR _imm8_table[eax*4]
	mov	eax, DWORD PTR _regs+92
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _src$81036[esp+24], edx
	mov	ax, WORD PTR [eax+2]
	mov	bl, ah
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, al
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	add	esi, DWORD PTR _regs[ecx*4+32]
	movsx	ecx, dl
	mov	bl, BYTE PTR [edi+esi]
	movsx	eax, bl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	mov	BYTE PTR _dst$81041[esp+24], bl
	setl	cl
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$81049[esp+24], ebx
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$81049[esp+24]
	setl	dl
	xor	dl, cl
	xor	bl, cl
	mov	cl, BYTE PTR _dst$81041[esp+24]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$81036[esp+24]
	cmp	dl, cl
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$81049[esp+24]
	test	ecx, ecx
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5128_0@4 ENDP


_flgn$81069 = -4
@op_9158_0@4 PROC NEAR
	_start_func  'op_9158_0'
	mov	eax, ecx
	shr	ecx, 1
	shr	eax, 8
	and	ecx, 7
	and	eax, 7
	mov	si, WORD PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR _regs[eax*4+32]
	xor	edx, edx
	mov	cx, WORD PTR [ecx+edi]
	mov	dl, ch
	mov	dh, cl
	lea	ecx, DWORD PTR [edi+2]
	mov	ebp, edx
	mov	DWORD PTR _regs[eax*4+32], ecx
	movsx	eax, bp
	movsx	edx, si
	sub	eax, edx
	xor	ecx, ecx
	test	bp, bp
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	si, si
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$81069[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	si, bp
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$81069[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9158_0@4 ENDP


@op_57e8_0@4 PROC NEAR
	_start_func  'op_57e8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, eax
	movsx	eax, BYTE PTR _regflags+1
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR [ecx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_57e8_0@4 ENDP


@op_0_0@4 PROC NEAR
	_start_func  'op_0_0'
	shr	ecx, 8
	mov	al, BYTE PTR [eax+3]
	and	ecx, 7
	mov	dl, BYTE PTR _regs[ecx*4]
	or	al, dl
	mov	dl, 0
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 4
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_0_0@4 ENDP


@op_b03a_0@4 PROC NEAR
	_start_func  'op_b03a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	ebp, DWORD PTR _regs+96
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	sub	edx, ebp
	mov	edi, DWORD PTR _regs+88
	add	edx, ebx
	shr	ecx, 1
	add	edx, edi
	and	ecx, 7
	xor	ebx, ebx
	mov	dl, BYTE PTR [edx+esi+2]
	mov	cl, BYTE PTR _regs[ecx*4]
	movsx	eax, cl
	movsx	edi, dl
	sub	eax, edi
	test	cl, cl
	setl	bl
	mov	edi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dl, dl
	setl	al
	cmp	eax, edi
	mov	ebp, ebx
	je	SHORT $L113370
	cmp	ebp, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L113371
$L113370:
	mov	BYTE PTR _regflags+3, 0
$L113371:
	cmp	dl, cl
	seta	cl
	test	ebp, ebp
	setne	dl
	add	esi, 4
	mov	BYTE PTR _regflags+2, cl
	mov	DWORD PTR _regs+92, esi
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b03a_0@4 ENDP


@op_cb0_0@4 PROC NEAR
	_start_func  'op_cb0_0'
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	mov	eax, ecx
	xor	edx, edx
	sub	eax, esi
	test	ecx, ecx
	setl	dl
	mov	edi, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	esi, esi
	setl	al
	cmp	eax, edi
	je	SHORT $L113387
	cmp	edx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L113388
$L113387:
	mov	BYTE PTR _regflags+3, 0
$L113388:
	cmp	esi, ecx
	seta	cl
	test	edx, edx
	setne	dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_cb0_0@4 ENDP


@op_11e8_0@4 PROC NEAR
	_start_func  'op_11e8_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	edi, DWORD PTR _regs[ecx*4+32]
	mov	cx, WORD PTR [esi+4]
	add	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [edx+edi]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	BYTE PTR [edx+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11e8_0@4 ENDP


@op_5de8_0@4 PROC NEAR
	_start_func  'op_5de8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	dl, BYTE PTR _regflags+3
	or	esi, eax
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	cl, BYTE PTR _regflags
	add	esi, eax
	xor	eax, eax
	cmp	cl, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setne	al
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR [edx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5de8_0@4 ENDP


_src$81176 = -1
@op_4428_0@4 PROC NEAR
	_start_func  'op_4428_0'
	mov	esi, ecx
	mov	cx, WORD PTR [eax+2]
	xor	edx, edx
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 8
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	xor	edx, edx
	mov	ebx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	add	eax, ebx
	mov	cl, BYTE PTR [esi+eax]
	mov	BYTE PTR _src$81176[esp+12], cl
	movsx	ecx, cl
	neg	ecx
	test	cl, cl
	setl	dl
	test	cl, cl
	sete	bl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _src$81176[esp+12]
	test	bl, bl
	setl	bl
	and	bl, dl
	mov	BYTE PTR _regflags+3, bl
	mov	bl, BYTE PTR _src$81176[esp+12]
	test	bl, bl
	seta	bl
	test	edx, edx
	setne	dl
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+4, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4428_0@4 ENDP


_dstreg$ = -4
@op_9078_0@4 PROC NEAR
	_start_func  'op_9078_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	bp, WORD PTR _regs[ecx*4]
	mov	edi, edx
	mov	DWORD PTR _dstreg$[esp+20], ecx
	movsx	esi, bp
	movsx	eax, di
	sub	esi, eax
	xor	eax, eax
	test	bp, bp
	setl	al
	xor	edx, edx
	test	si, si
	setl	dl
	test	si, si
	sete	cl
	test	di, di
	mov	BYTE PTR _regflags+1, cl
	mov	bl, dl
	setl	cl
	xor	cl, al
	xor	bl, al
	and	cl, bl
	cmp	di, bp
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _dstreg$[esp+20]
	test	edx, edx
	mov	WORD PTR _regs[eax*4], si
	mov	eax, DWORD PTR _regs+92
	setne	dl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9078_0@4 ENDP


@op_81a0_0@4 PROC NEAR
	_start_func  'op_81a0_0'
	mov	eax, ecx
	push	ebx
	shr	eax, 8
	and	eax, 7
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	esi, DWORD PTR [esi+edx-4]
	bswap	esi
	and	ecx, 7
	sub	edx, 4
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	DWORD PTR _regs[eax*4+32], edx
	or	ecx, esi
	mov	eax, 0
	sete	bl
	cmp	ecx, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, bl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_81a0_0@4 ENDP


@op_130_0@4 PROC NEAR
	_start_func  'op_130_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	shr	ecx, 8
	mov	bl, BYTE PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, bl
	and	cl, 7
	mov	al, BYTE PTR [edx+eax]
	shr	al, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_130_0@4 ENDP


@op_c28_0@4 PROC NEAR
	_start_func  'op_c28_0'
	mov	esi, eax
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+4]
	mov	dl, BYTE PTR [esi+3]
	mov	bl, ah
	movsx	edi, bx
	xor	ebx, ebx
	mov	bh, al
	shr	ecx, 8
	movsx	eax, bx
	and	ecx, 7
	or	edi, eax
	xor	ebx, ebx
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edi, ebp
	mov	cl, BYTE PTR [edi+ecx]
	movsx	eax, cl
	movsx	edi, dl
	sub	eax, edi
	test	cl, cl
	setl	bl
	mov	edi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dl, dl
	setl	al
	cmp	eax, edi
	mov	ebp, ebx
	je	SHORT $L113539
	cmp	ebp, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L113540
$L113539:
	mov	BYTE PTR _regflags+3, 0
$L113540:
	cmp	dl, cl
	seta	cl
	test	ebp, ebp
	setne	dl
	add	esi, 6
	mov	BYTE PTR _regflags+2, cl
	mov	DWORD PTR _regs+92, esi
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c28_0@4 ENDP


@op_c128_0@4 PROC NEAR
	_start_func  'op_c128_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	edx, ecx
	or	esi, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	edx, 8
	and	edx, 7
	shr	ecx, 1
	mov	ebx, DWORD PTR _regs[edx*4+32]
	and	ecx, 7
	add	esi, ebx
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	dl, BYTE PTR [eax+esi]
	and	cl, dl
	mov	dl, 0
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [eax+esi], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c128_0@4 ENDP


@op_5fe0_0@4 PROC NEAR
	_start_func  'op_5fe0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	cl, BYTE PTR _regflags+1
	sub	eax, esi
	test	cl, cl
	mov	DWORD PTR [edx], eax
	jne	SHORT $L113605
	mov	cl, BYTE PTR _regflags
	mov	dl, BYTE PTR _regflags+3
	cmp	cl, dl
	jne	SHORT $L113605
	xor	ecx, ecx
	jmp	SHORT $L113606
$L113605:
	mov	ecx, 1
$L113606:
	mov	edx, DWORD PTR _MEMBaseDiff
	neg	ecx
	sbb	cl, cl
	and	ecx, 255				; 000000ffH
	mov	BYTE PTR [edx+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5fe0_0@4 ENDP


@op_8150_0@4 PROC NEAR
	_start_func  'op_8150_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[eax*4+32]
	xor	ebx, ebx
	shr	ecx, 1
	mov	dx, WORD PTR [edi+esi]
	and	ecx, 7
	mov	bl, dh
	mov	ax, WORD PTR _regs[ecx*4]
	xor	ecx, ecx
	or	ax, bx
	mov	ch, dl
	or	eax, ecx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8150_0@4 ENDP


@op_c078_0@4 PROC NEAR
	_start_func  'op_c078_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	and	dx, WORD PTR _regs[ecx*4]
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	WORD PTR _regs[ecx*4], ax
	sete	bl
	cmp	ax, dx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	add	eax, 4
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c078_0@4 ENDP


@op_3098_0@4 PROC NEAR
	_start_func  'op_3098_0'
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	esi, ecx
	shr	esi, 8
	and	esi, 7
	xor	edx, edx
	mov	edi, DWORD PTR _regs[esi*4+32]
	mov	ax, WORD PTR [edi+ebp]
	add	edi, 2
	mov	dl, ah
	mov	DWORD PTR _regs[esi*4+32], edi
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	ecx, 1
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	BYTE PTR _regflags+1, bl
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3098_0@4 ENDP


@op_8158_0@4 PROC NEAR
	_start_func  'op_8158_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	esi, DWORD PTR _regs[eax*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	lea	ebx, DWORD PTR [esi+2]
	mov	cx, WORD PTR _regs[ecx*4]
	mov	dx, WORD PTR [edi+esi]
	mov	DWORD PTR _regs[eax*4+32], ebx
	xor	eax, eax
	mov	al, dh
	mov	ah, dl
	or	ecx, eax
	xor	eax, eax
	cmp	cx, ax
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	cx, ax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	mov	dh, cl
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8158_0@4 ENDP


@op_ca0_0@4 PROC NEAR
	_start_func  'op_ca0_0'
	shr	ecx, 8
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	sub	eax, 4
	mov	esi, DWORD PTR [esi+eax]
	bswap	esi
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	eax, esi
	sub	eax, edx
	xor	ecx, ecx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L113667
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L113668
$L113667:
	mov	BYTE PTR _regflags+3, 0
$L113668:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ca0_0@4 ENDP


@op_a40_0@4 PROC NEAR
	_start_func  'op_a40_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	dh, al
	xor	dx, WORD PTR _regs[ecx*4]
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	WORD PTR _regs[ecx*4], ax
	sete	bl
	cmp	ax, dx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	add	eax, 4
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a40_0@4 ENDP


@op_e118_0@4 PROC NEAR
	_start_func  'op_e118_0'
	mov	edx, ecx
	shr	ecx, 1
	and	ecx, 7
	shr	edx, 8
	mov	edi, DWORD PTR _imm8_table[ecx*4]
	and	edx, 7
	xor	eax, eax
	and	edi, 7
	mov	al, BYTE PTR _regs[edx*4]
	mov	ecx, 8
	sub	ecx, edi
	mov	esi, eax
	shr	eax, cl
	mov	ecx, edi
	shl	esi, cl
	mov	BYTE PTR _regflags+3, 0
	or	eax, esi
	and	eax, 255				; 000000ffH
	mov	cl, al
	mov	BYTE PTR _regs[edx*4], al
	and	cl, 1
	test	al, al
	mov	BYTE PTR _regflags+2, cl
	sete	cl
	test	al, al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e118_0@4 ENDP


@op_20f8_0@4 PROC NEAR
	_start_func  'op_20f8_0'
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	push	esi
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	lea	esi, DWORD PTR [edx+4]
	mov	DWORD PTR _regs[ecx*4+32], esi
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20f8_0@4 ENDP


@op_5bc0_0@4 PROC NEAR
	_start_func  'op_5bc0_0'
	movsx	eax, BYTE PTR _regflags
	shr	ecx, 8
	and	ecx, 7
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5bc0_0@4 ENDP


_flgn$81425 = -4
@op_5150_0@4 PROC NEAR
	_start_func  'op_5150_0'
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	eax, 1
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	eax, 7
	xor	edx, edx
	mov	esi, DWORD PTR _imm8_table[eax*4]
	mov	ax, WORD PTR [ecx+ebp]
	mov	dl, ah
	mov	dh, al
	mov	edi, edx
	movsx	ecx, si
	movsx	eax, di
	sub	eax, ecx
	xor	ecx, ecx
	test	di, di
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	si, si
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$81425[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	si, di
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$81425[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+ebp], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5150_0@4 ENDP


@op_5dc0_0@4 PROC NEAR
	_start_func  'op_5dc0_0'
	mov	dl, BYTE PTR _regflags
	mov	bl, BYTE PTR _regflags+3
	xor	eax, eax
	shr	ecx, 8
	and	ecx, 7
	cmp	dl, bl
	setne	al
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5dc0_0@4 ENDP


@op_11b0_0@4 PROC NEAR
	_start_func  'op_11b0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	shr	esi, 1
	mov	bl, BYTE PTR [ecx+eax]
	mov	eax, DWORD PTR _regs+92
	and	esi, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[esi*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	cl, cl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11b0_0@4 ENDP


_src$81455 = -8
_newv$81458 = -4
@op_5010_0@4 PROC NEAR
	_start_func  'op_5010_0'
	mov	eax, ecx
	shr	ecx, 8
	shr	eax, 1
	and	ecx, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	ebx, DWORD PTR _imm8_table[eax*4]
	mov	al, BYTE PTR [edi+esi]
	movsx	ecx, bl
	movsx	edx, al
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$81458[esp+20], ecx
	mov	DWORD PTR _src$81455[esp+20], ebx
	sete	cl
	test	bl, bl
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	al, al
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$81455[esp+20]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$81458[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5010_0@4 ENDP


@op_180_0@4 PROC NEAR
	_start_func  'op_180_0'
	mov	eax, ecx
	shr	ecx, 1
	shr	eax, 8
	and	ecx, 7
	and	eax, 7
	mov	esi, DWORD PTR _regs[ecx*4]
	mov	edi, DWORD PTR _regs[eax*4]
	and	esi, 31					; 0000001fH
	mov	edx, edi
	mov	ecx, esi
	sar	edx, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	edx, 1
	shl	edx, cl
	not	edx
	and	edx, edi
	mov	DWORD PTR _regs[eax*4], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_180_0@4 ENDP


@op_5fc0_0@4 PROC NEAR
	_start_func  'op_5fc0_0'
	mov	al, BYTE PTR _regflags+1
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	jne	SHORT $L113867
	mov	al, BYTE PTR _regflags
	mov	dl, BYTE PTR _regflags+3
	cmp	al, dl
	jne	SHORT $L113867
	xor	eax, eax
	jmp	SHORT $L113868
$L113867:
	mov	eax, 1
$L113868:
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5fc0_0@4 ENDP


@op_31d8_0@4 PROC NEAR
	_start_func  'op_31d8_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [esi+edi]
	add	esi, 2
	mov	dl, ah
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	ecx, DWORD PTR _regs+92
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	mov	cx, WORD PTR [ecx+2]
	cmp	ax, dx
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	xor	ebx, ebx
	mov	dh, al
	xor	eax, eax
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31d8_0@4 ENDP


@op_11a8_0@4 PROC NEAR
	_start_func  'op_11a8_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	ebx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	and	ecx, 7
	mov	bl, BYTE PTR [edx+eax]
	mov	DWORD PTR _regs+92, esi
	mov	dx, WORD PTR [esi]
	add	esi, 2
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	cl, cl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11a8_0@4 ENDP


@op_258_0@4 PROC NEAR
	_start_func  'op_258_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dx, WORD PTR [edi+esi]
	lea	ebx, DWORD PTR [esi+2]
	mov	DWORD PTR _regs[ecx*4+32], ebx
	xor	ecx, ecx
	mov	cl, dh
	mov	ch, dl
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	and	ecx, edx
	mov	eax, ecx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_258_0@4 ENDP


@op_1120_0@4 PROC NEAR
	_start_func  'op_1120_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	edi, DWORD PTR _areg_byteinc[eax*4]
	lea	esi, DWORD PTR _regs[eax*4+32]
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	bl, BYTE PTR [edi+edx]
	and	ecx, 7
	mov	DWORD PTR [esi], edx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	xor	cl, cl
	sub	eax, esi
	cmp	bl, cl
	mov	DWORD PTR [edx], eax
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+eax], bl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1120_0@4 ENDP


_dst$81548 = -4
_flgn$81556 = -8
@op_9090_0@4 PROC NEAR
	_start_func  'op_9090_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	push	esi
	mov	esi, ecx
	push	edi
	shr	ecx, 8
	and	ecx, 7
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	mov	eax, DWORD PTR [eax+ecx]
	bswap	eax
	mov	edx, DWORD PTR _regs[esi*4]
	xor	ecx, ecx
	mov	edi, edx
	mov	DWORD PTR _dst$81548[ebp], edx
	sub	edi, eax
	test	edx, edx
	setl	cl
	xor	edx, edx
	mov	DWORD PTR _regs[esi*4], edi
	test	edi, edi
	setl	dl
	test	edi, edi
	sete	bl
	test	eax, eax
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$81556[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$81556[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _dst$81548[ebp]
	pop	edi
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, bl
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _regs+92
	pop	esi
	test	ecx, ecx
	setne	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9090_0@4 ENDP


@op_4a48_0@4 PROC NEAR
	_start_func  'op_4a48_0'
	shr	ecx, 8
	and	ecx, 7
	xor	eax, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	cx, WORD PTR _regs[ecx*4+32]
	cmp	cx, ax
	sete	dl
	cmp	cx, ax
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a48_0@4 ENDP


_src$81576 = -5
_newv$81579 = -4
@op_d110_0@4 PROC NEAR
	_start_func  'op_d110_0'
	mov	eax, ecx
	shr	ecx, 8
	shr	eax, 1
	and	ecx, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	bl, BYTE PTR _regs[eax*4]
	mov	al, BYTE PTR [edi+esi]
	movsx	ecx, al
	movsx	edx, bl
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$81579[esp+20], ecx
	mov	BYTE PTR _src$81576[esp+20], bl
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$81576[esp+20]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$81579[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d110_0@4 ENDP


@op_51d8_0@4 PROC NEAR
	_start_func  'op_51d8_0'
	shr	ecx, 8
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	add	ecx, edx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR [eax+edx], 0
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_51d8_0@4 ENDP


@op_21b0_0@4 PROC NEAR
	_start_func  'op_21b0_0'
	push	esi
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	push	edi
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR [ecx+eax]
	bswap	edi
	mov	eax, DWORD PTR _regs+92
	shr	esi, 1
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	and	esi, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	edi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	edi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	edi
	mov	DWORD PTR [eax], edi
	pop	edi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21b0_0@4 ENDP


@op_51c0_0@4 PROC NEAR
	_start_func  'op_51c0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	BYTE PTR _regs[ecx*4], 0
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_51c0_0@4 ENDP


_src$81622 = -5
_dst$81624 = -6
_flgn$81632 = -4
@op_9118_0@4 PROC NEAR
	_start_func  'op_9118_0'
	mov	eax, ecx
	shr	eax, 8
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	eax, 7
	push	edi
	mov	esi, DWORD PTR _regs[eax*4+32]
	lea	edi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	bl, BYTE PTR [esi+ebp]
	add	eax, esi
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _dst$81624[esp+24], bl
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	DWORD PTR [edi], eax
	movsx	eax, bl
	movsx	edx, cl
	sub	eax, edx
	xor	edx, edx
	test	bl, bl
	setl	dl
	xor	ebx, ebx
	mov	BYTE PTR _src$81622[esp+24], cl
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$81632[esp+24], ebx
	pop	edi
	sete	bl
	test	cl, cl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$81632[esp+20]
	setl	cl
	xor	cl, dl
	xor	bl, dl
	mov	dl, BYTE PTR _dst$81624[esp+20]
	and	cl, bl
	mov	bl, BYTE PTR _src$81622[esp+20]
	mov	BYTE PTR _regflags+3, cl
	cmp	bl, dl
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$81632[esp+20]
	test	ecx, ecx
	setne	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [esi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9118_0@4 ENDP


@op_c018_0@4 PROC NEAR
	_start_func  'op_c018_0'
	mov	eax, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	mov	edi, DWORD PTR _regs[eax*4+32]
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	dl, BYTE PTR [edi+edx]
	add	eax, edi
	shr	ecx, 1
	and	ecx, 7
	mov	DWORD PTR [esi], eax
	mov	al, 0
	mov	bl, BYTE PTR _regs[ecx*4]
	mov	BYTE PTR _regflags+2, al
	and	dl, bl
	mov	BYTE PTR _regflags+3, al
	sete	bl
	cmp	dl, al
	mov	BYTE PTR _regs[ecx*4], dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c018_0@4 ENDP


@op_313a_0@4 PROC NEAR
	_start_func  'op_313a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	edi, DWORD PTR _regs+96
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+88
	or	edx, eax
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	add	edx, edi
	add	edx, ebx
	shr	ecx, 1
	mov	ax, WORD PTR [edx+esi+2]
	xor	edx, edx
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	eax, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	sub	edx, 2
	mov	DWORD PTR _regs[ecx*4+32], edx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	ch, al
	mov	WORD PTR [edi+edx], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_313a_0@4 ENDP


_x$114157 = -8
_dsta$81673 = -20
_bf1$81678 = -16
@op_eed0_0@4 PROC NEAR
	_start_func  'op_eed0_0'
	mov	ebp, esp
	sub	esp, 20					; 00000014H
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	push	ebx
	mov	dh, al
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	push	esi
	and	eax, 2048				; 00000800H
	push	edi
	test	ax, ax
	movsx	eax, dx
	mov	esi, eax
	je	SHORT $L114144
	sar	esi, 6
	and	esi, 7
	mov	esi, DWORD PTR _regs[esi*4]
	jmp	SHORT $L114145
$L114144:
	sar	esi, 6
	and	esi, 31					; 0000001fH
$L114145:
	test	dl, 32					; 00000020H
	je	SHORT $L114147
	and	eax, 7
	mov	eax, DWORD PTR _regs[eax*4]
$L114147:
	dec	eax
	mov	edx, esi
	and	eax, 31					; 0000001fH
	and	edx, -2147483648			; 80000000H
	inc	eax
	mov	edi, esi
	neg	edx
	sbb	edx, edx
	and	edx, -536870912				; e0000000H
	sar	edi, 3
	or	edx, edi
	add	ecx, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _dsta$81673[ebp], ecx
	mov	edx, DWORD PTR [edx+ecx]
	bswap	edx
	mov	DWORD PTR _x$114157[ebp], edx
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	add	ecx, edi
	and	esi, 7
	mov	DWORD PTR -12+[ebp], ecx
	mov	edi, 32					; 00000020H
	mov	bl, BYTE PTR [ecx+4]
	mov	ecx, 8
	sub	ecx, esi
	mov	DWORD PTR _bf1$81678[ebp], ebx
	mov	DWORD PTR -4+[ebp], ecx
	mov	ecx, esi
	shl	edx, cl
	mov	ecx, DWORD PTR -4+[ebp]
	sub	edi, eax
	shr	ebx, cl
	mov	ecx, edi
	or	edx, ebx
	mov	ebx, 1
	shr	edx, cl
	lea	ecx, DWORD PTR [eax-1]
	shl	ebx, cl
	test	ebx, edx
	setne	cl
	xor	ebx, ebx
	mov	BYTE PTR _regflags, cl
	cmp	edx, ebx
	mov	ecx, edi
	sete	dl
	mov	BYTE PTR _regflags+1, dl
	or	edx, -1
	add	eax, esi
	mov	BYTE PTR _regflags+3, bl
	shl	edx, cl
	cmp	eax, 32					; 00000020H
	mov	BYTE PTR _regflags+2, bl
	jl	SHORT $L114148
	xor	edi, edi
	jmp	SHORT $L114149
$L114148:
	or	edi, -1
	mov	ecx, eax
	shr	edi, cl
	and	edi, DWORD PTR _x$114157[ebp]
$L114149:
	mov	ecx, DWORD PTR -4+[ebp]
	mov	ebx, -16777216				; ff000000H
	shl	ebx, cl
	mov	ecx, DWORD PTR _x$114157[ebp]
	and	ebx, ecx
	mov	ecx, esi
	mov	DWORD PTR -8+[ebp], ebx
	mov	ebx, edx
	mov	esi, DWORD PTR -12+[ebp]
	shr	ebx, cl
	mov	ecx, DWORD PTR -8+[ebp]
	or	ecx, ebx
	or	ecx, edi
	cmp	eax, 32					; 00000020H
	bswap	ecx
	mov	DWORD PTR [esi], ecx
	jle	SHORT $L114172
	mov	bl, BYTE PTR _bf1$81678[ebp]
	lea	ecx, DWORD PTR [eax-32]
	mov	eax, 255				; 000000ffH
	sar	eax, cl
	mov	ecx, DWORD PTR -4+[ebp]
	shl	dl, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	al, bl
	or	al, dl
	mov	edx, DWORD PTR _dsta$81673[ebp]
	mov	BYTE PTR [ecx+edx+4], al
$L114172:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_eed0_0@4 ENDP


@op_4230_0@4 PROC NEAR
	_start_func  'op_4230_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	cl, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, 1
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4230_0@4 ENDP


@op_1150_0@4 PROC NEAR
	_start_func  'op_1150_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	xor	bl, bl
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	al, BYTE PTR [edx+esi]
	mov	edx, DWORD PTR _regs+92
	cmp	al, bl
	mov	dx, WORD PTR [edx+2]
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+3, bl
	sete	bl
	test	al, al
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	mov	BYTE PTR _regflags, bl
	xor	ebx, ebx
	mov	bl, dh
	movsx	edi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 1
	and	ecx, 7
	or	edi, edx
	add	edi, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1150_0@4 ENDP


@op_4a30_0@4 PROC NEAR
	_start_func  'op_4a30_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [ecx+eax]
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a30_0@4 ENDP


_dsta$81724 = -4
@op_d1b0_0@4 PROC NEAR
	_start_func  'op_d1b0_0'
	mov	ebp, esp
	push	ecx
	mov	eax, ecx
	push	ebx
	shr	eax, 1
	and	eax, 7
	push	esi
	push	edi
	mov	edi, DWORD PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _dsta$81724[ebp], eax
	mov	esi, DWORD PTR [ecx+eax]
	bswap	esi
	lea	edx, DWORD PTR [esi+edi]
	xor	ecx, ecx
	test	edx, edx
	setl	cl
	test	edx, edx
	sete	al
	test	esi, esi
	mov	BYTE PTR _regflags+1, al
	setl	al
	xor	al, cl
	test	edi, edi
	setl	bl
	xor	bl, cl
	not	esi
	and	al, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, al
	setb	al
	test	ecx, ecx
	setne	cl
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _dsta$81724[ebp]
	add	eax, ecx
	pop	edi
	bswap	edx
	mov	DWORD PTR [eax], edx
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d1b0_0@4 ENDP


_dstreg$ = -8
_flgn$81752 = -4
@op_90bc_0@4 PROC NEAR
	_start_func  'op_90bc_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	shr	ecx, 1
	push	esi
	and	ecx, 7
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	DWORD PTR _dstreg$[ebp], ecx
	mov	eax, DWORD PTR _regs[ecx*4]
	xor	ecx, ecx
	mov	esi, eax
	sub	esi, edi
	test	eax, eax
	setl	cl
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	edi, edi
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$81752[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$81752[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _dstreg$[ebp]
	cmp	edi, eax
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	test	ecx, ecx
	mov	DWORD PTR _regs[edx*4], esi
	mov	eax, DWORD PTR _regs+92
	setne	cl
	add	eax, 6
	pop	edi
	mov	BYTE PTR _regflags+3, bl
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	BYTE PTR _regflags, cl
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_90bc_0@4 ENDP


@op_c0ba_0@4 PROC NEAR
	_start_func  'op_c0ba_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, ebx
	add	edx, eax
	shr	ecx, 1
	mov	esi, DWORD PTR [edx+esi+2]
	bswap	esi
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4]
	mov	edx, 0
	and	eax, esi
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	add	eax, 4
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c0ba_0@4 ENDP


_dstreg$ = -4
@op_907c_0@4 PROC NEAR
	_start_func  'op_907c_0'
	xor	edx, edx
	shr	ecx, 1
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	bp, WORD PTR _regs[ecx*4]
	mov	edi, edx
	movsx	esi, bp
	movsx	eax, di
	sub	esi, eax
	xor	eax, eax
	test	bp, bp
	setl	al
	xor	edx, edx
	mov	DWORD PTR _dstreg$[esp+20], ecx
	test	si, si
	setl	dl
	test	si, si
	sete	cl
	test	di, di
	mov	BYTE PTR _regflags+1, cl
	mov	bl, dl
	setl	cl
	xor	cl, al
	xor	bl, al
	and	cl, bl
	cmp	di, bp
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _dstreg$[esp+20]
	test	edx, edx
	mov	WORD PTR _regs[eax*4], si
	mov	eax, DWORD PTR _regs+92
	setne	dl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_907c_0@4 ENDP


@op_90e8_0@4 PROC NEAR
	_start_func  'op_90e8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, ecx
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	and	esi, 7
	mov	ax, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ah
	movsx	ecx, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	edx, DWORD PTR _regs[esi*4+32]
	or	ecx, eax
	sub	edx, ecx
	mov	DWORD PTR _regs[esi*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_90e8_0@4 ENDP


_src$81811 = -5
_newv$81813 = -4
@op_d010_0@4 PROC NEAR
	_start_func  'op_d010_0'
	mov	esi, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	mov	bl, BYTE PTR [eax+ecx]
	mov	al, BYTE PTR _regs[esi*4]
	mov	BYTE PTR _src$81811[esp+16], bl
	movsx	ecx, al
	movsx	edx, bl
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$81813[esp+16], ecx
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$81811[esp+16]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$81813[esp+16]
	test	edx, edx
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	setne	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d010_0@4 ENDP


@op_21a8_0@4 PROC NEAR
	_start_func  'op_21a8_0'
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	push	esi
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	add	edx, esi
	mov	esi, DWORD PTR [edx+eax]
	bswap	esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 1
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21a8_0@4 ENDP


@op_57d0_0@4 PROC NEAR
	_start_func  'op_57d0_0'
	movsx	eax, BYTE PTR _regflags+1
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	neg	eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_57d0_0@4 ENDP


@op_c058_0@4 PROC NEAR
	_start_func  'op_c058_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	dx, WORD PTR [esi+edx]
	add	esi, 2
	mov	DWORD PTR _regs[eax*4+32], esi
	xor	eax, eax
	mov	al, dh
	and	ecx, 7
	mov	ah, dl
	xor	edx, edx
	and	ax, WORD PTR _regs[ecx*4]
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	cmp	ax, dx
	mov	WORD PTR _regs[ecx*4], ax
	sete	bl
	cmp	ax, dx
	mov	eax, DWORD PTR _regs+92
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c058_0@4 ENDP


@op_10a8_0@4 PROC NEAR
	_start_func  'op_10a8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _regs[eax*4+32]
	add	edx, esi
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [edx+esi]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [ecx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10a8_0@4 ENDP


@op_e0b8_0@4 PROC NEAR
	_start_func  'op_e0b8_0'
	mov	eax, ecx
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+2, 0
	shr	eax, 8
	mov	esi, DWORD PTR _regs[ecx*4]
	and	eax, 7
	and	esi, 63					; 0000003fH
	mov	BYTE PTR _regflags+3, 0
	mov	edx, DWORD PTR _regs[eax*4]
	jle	SHORT $L81891
	and	esi, 31					; 0000001fH
	mov	ecx, 32					; 00000020H
	push	edi
	sub	ecx, esi
	mov	edi, edx
	shl	edi, cl
	mov	ecx, esi
	shr	edx, cl
	or	edx, edi
	pop	edi
	mov	ecx, edx
	shr	ecx, 31					; 0000001fH
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
$L81891:
	test	edx, edx
	sete	cl
	test	edx, edx
	mov	DWORD PTR _regs[eax*4], edx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e0b8_0@4 ENDP


@op_8090_0@4 PROC NEAR
	_start_func  'op_8090_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	ecx, DWORD PTR [ecx+edx]
	bswap	ecx
	mov	edx, DWORD PTR _regs[eax*4]
	or	ecx, edx
	mov	edx, 0
	sete	bl
	cmp	ecx, edx
	mov	DWORD PTR _regs[eax*4], ecx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8090_0@4 ENDP


@op_4270_0@4 PROC NEAR
	_start_func  'op_4270_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, 1
	mov	BYTE PTR _regflags, cl
	mov	WORD PTR [edx+eax], cx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4270_0@4 ENDP


@op_d07b_0@4 PROC NEAR
	_start_func  'op_d07b_0'
	mov	edx, DWORD PTR _regs+96
	shr	ecx, 1
	and	ecx, 7
	mov	ebx, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	add	ecx, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	si, WORD PTR _regs[ebx*4]
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	mov	dl, ah
	mov	dh, al
	mov	ebp, edx
	movsx	edi, si
	movsx	eax, bp
	add	edi, eax
	xor	eax, eax
	test	di, di
	setl	al
	test	di, di
	sete	cl
	test	si, si
	setl	dl
	xor	dl, al
	mov	BYTE PTR _regflags+1, cl
	test	bp, bp
	setl	cl
	xor	cl, al
	mov	WORD PTR _regs[ebx*4], di
	not	esi
	and	dl, cl
	cmp	si, bp
	setb	cl
	test	eax, eax
	mov	BYTE PTR _regflags+3, dl
	setne	dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d07b_0@4 ENDP


@op_1170_0@4 PROC NEAR
	_start_func  'op_1170_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs+92
	xor	dl, dl
	mov	al, BYTE PTR [edi+eax]
	mov	cx, WORD PTR [ecx]
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	edx, ecx
	add	edx, DWORD PTR _regs[esi*4+32]
	mov	BYTE PTR [edx+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1170_0@4 ENDP


_src$81961 = -5
_dst$81962 = -6
_flgn$81970 = -4
@op_9000_0@4 PROC NEAR
	_start_func  'op_9000_0'
	push	esi
	mov	esi, ecx
	shr	esi, 1
	shr	ecx, 8
	and	esi, 7
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	bl, BYTE PTR _regs[esi*4]
	movsx	eax, bl
	movsx	edx, cl
	sub	eax, edx
	xor	edx, edx
	test	bl, bl
	mov	BYTE PTR _dst$81962[esp+16], bl
	mov	BYTE PTR _src$81961[esp+16], cl
	setl	dl
	xor	ebx, ebx
	mov	BYTE PTR _regs[esi*4], al
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$81970[esp+16], ebx
	mov	eax, DWORD PTR _regs+92
	sete	bl
	test	cl, cl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$81970[esp+16]
	setl	cl
	xor	cl, dl
	xor	bl, dl
	mov	dl, BYTE PTR _dst$81962[esp+16]
	and	cl, bl
	mov	bl, BYTE PTR _src$81961[esp+16]
	mov	BYTE PTR _regflags+3, cl
	cmp	bl, dl
	pop	esi
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$81970[esp+12]
	test	ecx, ecx
	setne	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9000_0@4 ENDP


_flgn$81992 = -4
@op_9150_0@4 PROC NEAR
	_start_func  'op_9150_0'
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	eax, 1
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	eax, 7
	xor	edx, edx
	mov	si, WORD PTR _regs[eax*4]
	mov	ax, WORD PTR [ecx+ebp]
	mov	dl, ah
	mov	dh, al
	mov	edi, edx
	movsx	eax, di
	movsx	ecx, si
	sub	eax, ecx
	xor	ecx, ecx
	test	di, di
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	si, si
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$81992[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	si, di
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$81992[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+ebp], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9150_0@4 ENDP


@op_10fc_0@4 PROC NEAR
	_start_func  'op_10fc_0'
	shr	ecx, 1
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	al, BYTE PTR [eax+3]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	add	ecx, esi
	mov	DWORD PTR [edx], ecx
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10fc_0@4 ENDP


@op_e068_0@4 PROC NEAR
	_start_func  'op_e068_0'
	mov	edx, ecx
	xor	eax, eax
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+2, 0
	shr	edx, 8
	mov	cl, BYTE PTR _regs[ecx*4]
	and	edx, 7
	and	ecx, 63					; 0000003fH
	mov	BYTE PTR _regflags+3, 0
	mov	ax, WORD PTR _regs[edx*4]
	cmp	cx, 16					; 00000010H
	jl	SHORT $L82023
	shr	eax, 15					; 0000000fH
	cmp	cx, 16					; 00000010H
	sete	cl
	and	al, cl
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L82025
$L82023:
	test	cx, cx
	jle	SHORT $L82025
	dec	ecx
	shr	eax, cl
	mov	cl, al
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shr	eax, 1
$L82025:
	test	ax, ax
	sete	cl
	test	ax, ax
	mov	WORD PTR _regs[edx*4], ax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e068_0@4 ENDP


@op_4410_0@4 PROC NEAR
	_start_func  'op_4410_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	cl, BYTE PTR [edi+esi]
	movsx	eax, cl
	neg	eax
	test	al, al
	setl	dl
	test	al, al
	sete	bl
	test	cl, cl
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	and	bl, dl
	test	cl, cl
	seta	cl
	test	edx, edx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	setne	cl
	mov	BYTE PTR _regflags+3, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4410_0@4 ENDP


@op_48e8_0@4 PROC NEAR
	_start_func  'op_48e8_0'
	mov	edx, eax
	push	ebx
	push	esi
	mov	esi, ecx
	mov	ax, WORD PTR [edx+2]
	mov	dx, WORD PTR [edx+4]
	xor	ecx, ecx
	xor	ebx, ebx
	mov	cl, ah
	mov	bh, dl
	mov	ch, al
	xor	eax, eax
	mov	al, dh
	push	edi
	movsx	eax, ax
	movsx	edx, bx
	shr	esi, 8
	or	eax, edx
	and	esi, 7
	mov	dl, cl
	mov	edi, DWORD PTR _regs[esi*4+32]
	and	edx, 255				; 000000ffH
	mov	esi, edx
	xor	edx, edx
	add	eax, edi
	mov	dl, ch
	test	si, si
	mov	ecx, edx
	je	SHORT $L114524
$L82061:
	mov	edx, esi
	mov	edi, DWORD PTR _MEMBaseDiff
	and	edx, 65535				; 0000ffffH
	add	edi, eax
	shl	edx, 2
	mov	esi, DWORD PTR _movem_index1[edx]
	mov	esi, DWORD PTR _regs[esi*4]
	bswap	esi
	mov	DWORD PTR [edi], esi
	mov	si, WORD PTR _movem_next[edx]
	add	eax, 4
	test	si, si
	jne	SHORT $L82061
$L114524:
	test	cx, cx
	je	SHORT $L114527
$L82064:
	mov	esi, DWORD PTR _MEMBaseDiff
	and	ecx, 65535				; 0000ffffH
	shl	ecx, 2
	add	esi, eax
	mov	edx, DWORD PTR _movem_index1[ecx]
	mov	edx, DWORD PTR _regs[edx*4+32]
	bswap	edx
	mov	DWORD PTR [esi], edx
	mov	cx, WORD PTR _movem_next[ecx]
	add	eax, 4
	test	cx, cx
	jne	SHORT $L82064
$L114527:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_48e8_0@4 ENDP


@op_5070_0@4 PROC NEAR
	_start_func  'op_5070_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	mov	edi, DWORD PTR _imm8_table[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ebp, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+ebp]
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	movsx	eax, di
	movsx	ecx, si
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	si, si
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, di
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5070_0@4 ENDP


@op_10b8_0@4 PROC NEAR
	_start_func  'op_10b8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	al, BYTE PTR [edx+esi]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [ecx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10b8_0@4 ENDP


@op_44a8_0@4 PROC NEAR
	_start_func  'op_44a8_0'
	push	esi
	mov	esi, ecx
	xor	edx, edx
	mov	cx, WORD PTR [eax+2]
	push	edi
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 8
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	mov	edx, DWORD PTR _regs[esi*4+32]
	add	eax, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR [edx+eax]
	bswap	edi
	mov	esi, edi
	mov	ecx, 0
	neg	esi
	sets	cl
	test	esi, esi
	sete	dl
	test	edi, edi
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	and	dl, cl
	test	edi, edi
	mov	BYTE PTR _regflags+3, dl
	seta	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setne	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44a8_0@4 ENDP


@op_d1f8_0@4 PROC NEAR
	_start_func  'op_d1f8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	add	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d1f8_0@4 ENDP


@op_c060_0@4 PROC NEAR
	_start_func  'op_c060_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	mov	esi, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	edx, 2
	mov	cx, WORD PTR [ecx+edx]
	mov	DWORD PTR _regs[eax*4+32], edx
	xor	eax, eax
	mov	al, ch
	mov	ah, cl
	xor	ecx, ecx
	and	ax, WORD PTR _regs[esi*4]
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	cmp	ax, cx
	mov	WORD PTR _regs[esi*4], ax
	sete	dl
	cmp	ax, cx
	mov	eax, DWORD PTR _regs+92
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c060_0@4 ENDP


@op_e050_0@4 PROC NEAR
	_start_func  'op_e050_0'
	mov	esi, ecx
	shr	esi, 8
	shr	ecx, 1
	and	esi, 7
	and	ecx, 7
	xor	eax, eax
	mov	ax, WORD PTR _regs[esi*4]
	mov	edi, DWORD PTR _imm8_table[ecx*4]
	movsx	ecx, BYTE PTR _regflags+4
	lea	edx, DWORD PTR [eax+eax]
	and	edi, 63					; 0000003fH
	or	edx, ecx
	dec	edi
	mov	ecx, 15					; 0000000fH
	mov	BYTE PTR _regflags+3, 0
	sub	ecx, edi
	shl	edx, cl
	mov	ecx, edi
	shr	eax, cl
	and	edx, 65535				; 0000ffffH
	mov	cl, al
	shr	eax, 1
	and	eax, 65535				; 0000ffffH
	and	cl, 1
	or	eax, edx
	mov	BYTE PTR _regflags+4, cl
	test	ax, ax
	sete	dl
	test	ax, ax
	mov	WORD PTR _regs[esi*4], ax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e050_0@4 ENDP


@op_850_0@4 PROC NEAR
	_start_func  'op_850_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	edi, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	mov	cl, ah
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	edx, 1
	mov	eax, ecx
	movsx	esi, ax
	mov	al, 1
	mov	ecx, esi
	shl	al, cl
	mov	cl, BYTE PTR [edi+ebp]
	xor	al, cl
	mov	ecx, esi
	shl	edx, cl
	movsx	ecx, al
	and	edx, ecx
	mov	ecx, esi
	sar	edx, cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR [edi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_850_0@4 ENDP


@op_840_0@4 PROC NEAR
	_start_func  'op_840_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	esi, ecx
	xor	ecx, ecx
	mov	cl, ah
	and	ecx, 31					; 0000001fH
	mov	edx, 1
	mov	eax, ecx
	movsx	edi, ax
	mov	ecx, edi
	shl	edx, cl
	mov	ecx, DWORD PTR _regs[esi*4]
	mov	eax, edx
	xor	eax, ecx
	mov	ecx, edi
	and	edx, eax
	mov	DWORD PTR _regs[esi*4], eax
	mov	eax, DWORD PTR _regs+92
	sar	edx, cl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_840_0@4 ENDP


_flgn$82196 = -4
@op_5158_0@4 PROC NEAR
	_start_func  'op_5158_0'
	mov	eax, ecx
	shr	ecx, 1
	shr	eax, 8
	and	ecx, 7
	and	eax, 7
	mov	esi, DWORD PTR _imm8_table[ecx*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR _regs[eax*4+32]
	xor	edx, edx
	mov	cx, WORD PTR [ecx+edi]
	mov	dl, ch
	mov	dh, cl
	lea	ecx, DWORD PTR [edi+2]
	mov	ebp, edx
	mov	DWORD PTR _regs[eax*4+32], ecx
	movsx	edx, si
	movsx	eax, bp
	sub	eax, edx
	xor	ecx, ecx
	test	bp, bp
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	si, si
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$82196[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	si, bp
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$82196[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5158_0@4 ENDP


@op_5ce8_0@4 PROC NEAR
	_start_func  'op_5ce8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	dl, BYTE PTR _regflags+3
	or	esi, eax
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	cl, BYTE PTR _regflags
	add	esi, eax
	xor	eax, eax
	cmp	cl, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	sete	al
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR [edx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5ce8_0@4 ENDP


@op_91fa_0@4 PROC NEAR
	_start_func  'op_91fa_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	shr	ecx, 1
	mov	esi, DWORD PTR [edx+esi+2]
	bswap	esi
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	sub	edx, esi
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_91fa_0@4 ENDP


@op_d1fa_0@4 PROC NEAR
	_start_func  'op_d1fa_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	shr	ecx, 1
	mov	esi, DWORD PTR [edx+esi+2]
	bswap	esi
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	add	edx, esi
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d1fa_0@4 ENDP


@op_11c0_0@4 PROC NEAR
	_start_func  'op_11c0_0'
	xor	dl, dl
	shr	ecx, 8
	and	ecx, 7
	mov	ax, WORD PTR [eax+2]
	mov	BYTE PTR _regflags+2, dl
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	BYTE PTR _regflags+3, dl
	cmp	cl, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR [edx+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11c0_0@4 ENDP


@op_8068_0@4 PROC NEAR
	_start_func  'op_8068_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	esi, ecx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	shr	esi, 1
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	and	esi, 7
	mov	ax, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ah
	xor	ecx, ecx
	mov	dh, al
	mov	BYTE PTR _regflags+2, cl
	or	dx, WORD PTR _regs[esi*4]
	mov	BYTE PTR _regflags+3, cl
	mov	eax, edx
	cmp	ax, cx
	mov	WORD PTR _regs[esi*4], ax
	sete	dl
	cmp	ax, cx
	mov	eax, DWORD PTR _regs+92
	setl	cl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8068_0@4 ENDP


@op_51d0_0@4 PROC NEAR
	_start_func  'op_51d0_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [eax+ecx], 0
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_51d0_0@4 ENDP


_dsta$82276 = -8
_flgn$82285 = -4
@op_5190_0@4 PROC NEAR
	_start_func  'op_5190_0'
	mov	ebp, esp
	sub	esp, 8
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	shr	eax, 1
	and	ecx, 7
	push	ebx
	and	eax, 7
	push	esi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	push	edi
	mov	edi, DWORD PTR _imm8_table[eax*4]
	mov	DWORD PTR _dsta$82276[ebp], ecx
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	mov	esi, eax
	xor	ecx, ecx
	sub	esi, edi
	test	eax, eax
	setl	cl
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	edi, edi
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$82285[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$82285[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _dsta$82276[ebp]
	cmp	edi, eax
	seta	al
	test	ecx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	BYTE PTR _regflags+3, bl
	setne	al
	mov	BYTE PTR _regflags, al
	lea	eax, DWORD PTR [ecx+edx]
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5190_0@4 ENDP


@op_c98_0@4 PROC NEAR
	_start_func  'op_c98_0'
	shr	ecx, 8
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [eax+esi]
	bswap	esi
	mov	edi, DWORD PTR _regs[ecx*4+32]
	mov	eax, esi
	add	edi, 4
	sub	eax, edx
	mov	DWORD PTR _regs[ecx*4+32], edi
	xor	ecx, ecx
	test	esi, esi
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	edx, edx
	setl	al
	cmp	eax, edi
	je	SHORT $L114807
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L114808
$L114807:
	mov	BYTE PTR _regflags+3, 0
$L114808:
	cmp	edx, esi
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c98_0@4 ENDP


@op_81a8_0@4 PROC NEAR
	_start_func  'op_81a8_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	push	esi
	push	edi
	mov	edi, DWORD PTR _regs[eax*4]
	mov	ax, WORD PTR [edx+2]
	xor	edx, edx
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, eax
	mov	eax, DWORD PTR [ecx+esi]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	or	edi, eax
	mov	eax, 0
	sete	dl
	cmp	edi, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	lea	eax, DWORD PTR [ecx+esi]
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_81a8_0@4 ENDP


@op_3108_0@4 PROC NEAR
	_start_func  'op_3108_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	shr	ecx, 8
	mov	edx, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	sub	edx, 2
	mov	cx, WORD PTR _regs[ecx*4+32]
	mov	DWORD PTR _regs[eax*4+32], edx
	xor	eax, eax
	cmp	cx, ax
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	cx, ax
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags, al
	xor	eax, eax
	mov	al, ch
	mov	BYTE PTR _regflags+1, bl
	mov	ah, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+edx], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3108_0@4 ENDP


@op_46e8_0@4 PROC NEAR
	_start_func  'op_46e8_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L82342
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L82342:
	mov	eax, DWORD PTR _regs+92
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	mov	ax, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46e8_0@4 ENDP


_flgn$82365 = -4
@op_9070_0@4 PROC NEAR
	_start_func  'op_9070_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	mov	esi, ecx
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR _regs[esi*4]
	mov	ebp, edx
	movsx	edi, ax
	movsx	ecx, bp
	sub	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	xor	edx, edx
	mov	WORD PTR _regs[esi*4], di
	test	di, di
	setl	dl
	test	di, di
	sete	bl
	test	bp, bp
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$82365[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	bp, ax
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _flgn$82365[esp+20]
	test	eax, eax
	setne	dl
	mov	BYTE PTR _regflags+3, bl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9070_0@4 ENDP


@op_d0f8_0@4 PROC NEAR
	_start_func  'op_d0f8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	shr	ecx, 1
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	add	ebx, edx
	mov	DWORD PTR _regs[ecx*4+32], ebx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d0f8_0@4 ENDP


@op_2160_0@4 PROC NEAR
	_start_func  'op_2160_0'
	push	esi
	mov	esi, ecx
	mov	eax, esi
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	push	edi
	mov	ecx, DWORD PTR _regs[eax*4+32]
	sub	ecx, 4
	mov	edi, DWORD PTR [edx+ecx]
	bswap	edi
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	mov	cx, WORD PTR [eax+2]
	xor	eax, eax
	cmp	edi, eax
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	edi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 1
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2160_0@4 ENDP


@op_80_0@4 PROC NEAR
	_start_func  'op_80_0'
	shr	ecx, 8
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4]
	or	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 6
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_80_0@4 ENDP


_dstreg$ = -4
@op_d0bc_0@4 PROC NEAR
	_start_func  'op_d0bc_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	shr	ecx, 1
	push	esi
	and	ecx, 7
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	DWORD PTR _dstreg$[ebp], ecx
	mov	esi, DWORD PTR _regs[ecx*4]
	xor	eax, eax
	lea	edx, DWORD PTR [edi+esi]
	test	edx, edx
	setl	al
	test	edx, edx
	sete	cl
	test	edi, edi
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, al
	test	esi, esi
	setl	bl
	xor	bl, al
	not	esi
	and	cl, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, cl
	pop	edi
	setb	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _dstreg$[ebp]
	pop	esi
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs[ecx*4], edx
	mov	eax, DWORD PTR _regs+92
	pop	ebx
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d0bc_0@4 ENDP


@op_28_0@4 PROC NEAR
	_start_func  'op_28_0'
	mov	edi, eax
	mov	esi, ecx
	xor	eax, eax
	mov	cx, WORD PTR [edi+4]
	xor	edx, edx
	mov	al, ch
	mov	dh, cl
	movsx	eax, ax
	movsx	ecx, dx
	shr	esi, 8
	and	esi, 7
	or	eax, ecx
	mov	dl, 0
	mov	ecx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	mov	cl, BYTE PTR [edi+3]
	mov	bl, BYTE PTR [esi+eax]
	mov	BYTE PTR _regflags+2, dl
	or	cl, bl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_28_0@4 ENDP


@op_42b0_0@4 PROC NEAR
	_start_func  'op_42b0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, 1
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42b0_0@4 ENDP


@op_650_0@4 PROC NEAR
	_start_func  'op_650_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+ebp]
	mov	cl, ah
	mov	edi, edx
	mov	ch, al
	mov	esi, ecx
	xor	ecx, ecx
	movsx	eax, si
	movsx	edx, di
	add	eax, edx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	di, di
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, di
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_650_0@4 ENDP


@op_a68_0@4 PROC NEAR
	_start_func  'op_a68_0'
	mov	edx, eax
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+2]
	mov	dx, WORD PTR [edx+4]
	mov	bl, dh
	movsx	esi, bx
	xor	ebx, ebx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 8
	and	ecx, 7
	or	esi, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	add	esi, edx
	xor	edx, edx
	mov	cx, WORD PTR [edi+esi]
	mov	dl, ch
	mov	dh, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	xor	edx, ecx
	xor	ecx, ecx
	mov	eax, edx
	mov	BYTE PTR _regflags+2, cl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a68_0@4 ENDP


_dstreg$ = -8
_flgn$82509 = -4
@op_9098_0@4 PROC NEAR
	_start_func  'op_9098_0'
	mov	ebp, esp
	sub	esp, 8
	mov	eax, ecx
	push	ebx
	shr	eax, 8
	and	eax, 7
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	push	edi
	mov	edx, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	edi, DWORD PTR [edx+esi]
	bswap	edi
	and	ecx, 7
	mov	DWORD PTR _dstreg$[ebp], ecx
	mov	edx, DWORD PTR _regs[eax*4+32]
	add	edx, 4
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs[ecx*4]
	mov	esi, eax
	xor	ecx, ecx
	sub	esi, edi
	test	eax, eax
	setl	cl
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	edi, edi
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$82509[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$82509[ebp]
	and	bl, dl
	cmp	edi, eax
	pop	edi
	seta	al
	test	ecx, ecx
	mov	ecx, DWORD PTR _dstreg$[ebp]
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	BYTE PTR _regflags+3, bl
	setne	al
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs[ecx*4], esi
	mov	eax, DWORD PTR _regs+92
	pop	esi
	add	eax, 2
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9098_0@4 ENDP


@op_21d0_0@4 PROC NEAR
	_start_func  'op_21d0_0'
	shr	ecx, 8
	and	ecx, 7
	push	esi
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [eax+ecx]
	bswap	esi
	mov	edx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	esi, eax
	mov	cx, WORD PTR [edx+2]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21d0_0@4 ENDP


@op_e1b8_0@4 PROC NEAR
	_start_func  'op_e1b8_0'
	mov	eax, ecx
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+2, 0
	shr	eax, 8
	mov	esi, DWORD PTR _regs[ecx*4]
	and	eax, 7
	and	esi, 63					; 0000003fH
	mov	BYTE PTR _regflags+3, 0
	mov	edx, DWORD PTR _regs[eax*4]
	jle	SHORT $L82540
	and	esi, 31					; 0000001fH
	mov	ecx, 32					; 00000020H
	push	edi
	sub	ecx, esi
	mov	edi, edx
	shr	edi, cl
	mov	ecx, esi
	shl	edx, cl
	or	edx, edi
	pop	edi
	mov	cl, dl
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
$L82540:
	test	edx, edx
	sete	cl
	test	edx, edx
	mov	DWORD PTR _regs[eax*4], edx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e1b8_0@4 ENDP


@op_207c_0@4 PROC NEAR
	_start_func  'op_207c_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	shr	ecx, 1
	and	ecx, 7
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_207c_0@4 ENDP


@op_c60_0@4 PROC NEAR
	_start_func  'op_c60_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	edi, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	eax, DWORD PTR _regs[edi*4+32]
	sub	eax, 2
	mov	esi, ecx
	mov	cx, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ch
	mov	DWORD PTR _regs[edi*4+32], eax
	mov	dh, cl
	movsx	eax, dx
	movsx	ecx, si
	sub	eax, ecx
	xor	ecx, ecx
	test	dx, dx
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	si, si
	setl	al
	cmp	eax, edi
	je	SHORT $L115031
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L115032
$L115031:
	mov	BYTE PTR _regflags+3, 0
$L115032:
	cmp	si, dx
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c60_0@4 ENDP


@op_20fc_0@4 PROC NEAR
	_start_func  'op_20fc_0'
	push	ebx
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	push	esi
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	lea	esi, DWORD PTR [edx+4]
	mov	DWORD PTR _regs[ecx*4+32], esi
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20fc_0@4 ENDP


@op_50d0_0@4 PROC NEAR
	_start_func  'op_50d0_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [eax+ecx], 255			; 000000ffH
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_50d0_0@4 ENDP


@op_c0bc_0@4 PROC NEAR
	_start_func  'op_c0bc_0'
	shr	ecx, 1
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4]
	and	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 6
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c0bc_0@4 ENDP


@op_110_0@4 PROC NEAR
	_start_func  'op_110_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	dl, BYTE PTR [edx+eax]
	mov	eax, DWORD PTR _regs+92
	mov	cl, BYTE PTR _regs[ecx*4]
	add	eax, 2
	and	cl, 7
	mov	DWORD PTR _regs+92, eax
	shr	dl, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_110_0@4 ENDP


@op_30f8_0@4 PROC NEAR
	_start_func  'op_30f8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	shr	ecx, 1
	mov	ax, WORD PTR [edx+esi]
	xor	edx, edx
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	eax, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	lea	edi, DWORD PTR [edx+2]
	mov	DWORD PTR _regs[ecx*4+32], edi
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	ch, al
	mov	WORD PTR [esi+edx], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30f8_0@4 ENDP


_dstreg$ = -4
@op_4c98_0@4 PROC NEAR
	_start_func  'op_4c98_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	edx, ecx
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	ecx, 65535				; 0000ffffH
	mov	esi, DWORD PTR _regs[edx*4+32]
	mov	eax, ecx
	and	eax, 255				; 000000ffH
	shr	ecx, 8
	test	eax, eax
	mov	DWORD PTR _dstreg$[esp+20], edx
	mov	edi, ecx
	je	SHORT $L115153
$L82634:
	mov	cx, WORD PTR [esi+ebp]
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	add	esi, 2
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	ecx, DWORD PTR _movem_index1[eax*4]
	mov	eax, DWORD PTR _movem_next[eax*4]
	test	eax, eax
	mov	DWORD PTR _regs[ecx*4], edx
	jne	SHORT $L82634
	mov	edx, DWORD PTR _dstreg$[esp+20]
$L115153:
	test	edi, edi
	je	SHORT $L82640
$L82639:
	mov	ax, WORD PTR [esi+ebp]
	xor	ecx, ecx
	xor	ebx, ebx
	mov	cl, ah
	mov	bh, al
	add	esi, 2
	movsx	ecx, cx
	movsx	eax, bx
	or	ecx, eax
	mov	eax, DWORD PTR _movem_index1[edi*4]
	mov	edi, DWORD PTR _movem_next[edi*4]
	test	edi, edi
	mov	DWORD PTR _regs[eax*4+32], ecx
	jne	SHORT $L82639
$L82640:
	mov	DWORD PTR _regs[edx*4+32], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4c98_0@4 ENDP


@op_d1d8_0@4 PROC NEAR
	_start_func  'op_d1d8_0'
	mov	eax, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	mov	edx, DWORD PTR [edx+esi]
	bswap	edx
	mov	esi, DWORD PTR _regs[eax*4+32]
	add	esi, 4
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	esi, DWORD PTR _regs[ecx*4+32]
	add	esi, edx
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d1d8_0@4 ENDP


_flgn$82667 = -4
@op_5170_0@4 PROC NEAR
	_start_func  'op_5170_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	mov	esi, DWORD PTR _imm8_table[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ebp, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+ebp]
	mov	dl, ah
	mov	dh, al
	mov	edi, edx
	movsx	ecx, si
	movsx	eax, di
	sub	eax, ecx
	xor	ecx, ecx
	test	di, di
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	si, si
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$82667[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	si, di
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$82667[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+ebp], cx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5170_0@4 ENDP


@op_48a0_0@4 PROC NEAR
	_start_func  'op_48a0_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	ebp, ecx
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	esi, DWORD PTR _regs[ebp*4+32]
	mov	eax, ecx
	mov	dl, al
	and	edx, 255				; 000000ffH
	mov	ecx, edx
	xor	edx, edx
	mov	dl, ah
	test	cx, cx
	mov	edi, edx
	je	SHORT $L115203
$L82682:
	and	ecx, 65535				; 0000ffffH
	xor	edx, edx
	shl	ecx, 2
	sub	esi, 2
	mov	eax, DWORD PTR _movem_index2[ecx]
	mov	ax, WORD PTR _regs[eax*4+32]
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+esi], dx
	mov	cx, WORD PTR _movem_next[ecx]
	test	cx, cx
	jne	SHORT $L82682
$L115203:
	test	di, di
	je	SHORT $L82686
$L82685:
	mov	eax, edi
	xor	edx, edx
	and	eax, 65535				; 0000ffffH
	sub	esi, 2
	shl	eax, 2
	mov	ecx, DWORD PTR _movem_index2[eax]
	mov	cx, WORD PTR _regs[ecx*4]
	mov	dl, ch
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+esi], dx
	mov	di, WORD PTR _movem_next[eax]
	test	di, di
	jne	SHORT $L82685
$L82686:
	mov	DWORD PTR _regs[ebp*4+32], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_48a0_0@4 ENDP


@op_46a8_0@4 PROC NEAR
	_start_func  'op_46a8_0'
	push	ebx
	push	esi
	mov	esi, ecx
	mov	cx, WORD PTR [eax+2]
	xor	edx, edx
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 8
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	or	eax, ecx
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	ecx, DWORD PTR [edx+eax]
	bswap	ecx
	not	ecx
	xor	edx, edx
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46a8_0@4 ENDP


@op_4690_0@4 PROC NEAR
	_start_func  'op_4690_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	push	ebx
	shr	ecx, 8
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR [eax+ecx]
	bswap	eax
	not	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4690_0@4 ENDP


@op_3058_0@4 PROC NEAR
	_start_func  'op_3058_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	xor	ebx, ebx
	mov	esi, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	dx, WORD PTR [esi+edx]
	add	esi, 2
	mov	DWORD PTR _regs[eax*4+32], esi
	xor	eax, eax
	mov	al, dh
	mov	bh, dl
	movsx	eax, ax
	movsx	edx, bx
	and	ecx, 7
	or	eax, edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3058_0@4 ENDP


@op_d0d8_0@4 PROC NEAR
	_start_func  'op_d0d8_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	xor	ebx, ebx
	mov	esi, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	dx, WORD PTR [esi+edx]
	add	esi, 2
	mov	DWORD PTR _regs[eax*4+32], esi
	xor	eax, eax
	mov	al, dh
	mov	bh, dl
	movsx	eax, ax
	movsx	edx, bx
	and	ecx, 7
	or	eax, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	add	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d0d8_0@4 ENDP


_x$115268 = -4
_flgn$82751 = -8
@op_4a8_0@4 PROC NEAR
	_start_func  'op_4a8_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	push	esi
	push	edi
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _regs+92
	xor	ebx, ebx
	shr	ecx, 8
	mov	dx, WORD PTR [edx+6]
	and	ecx, 7
	mov	bl, dh
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	or	esi, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, edx
	mov	edx, DWORD PTR [ecx+esi]
	bswap	edx
	mov	DWORD PTR _x$115268[ebp], edx
	mov	edi, edx
	xor	ecx, ecx
	sub	edi, eax
	test	edx, edx
	setl	cl
	xor	edx, edx
	test	edi, edi
	setl	dl
	test	edi, edi
	sete	bl
	test	eax, eax
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$82751[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$82751[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _x$115268[ebp]
	mov	BYTE PTR _regflags+3, bl
	cmp	eax, edx
	seta	al
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _MEMBaseDiff
	setne	dl
	mov	BYTE PTR _regflags, dl
	add	esi, eax
	bswap	edi
	mov	DWORD PTR [esi], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a8_0@4 ENDP


@op_55c8_0@4 PROC NEAR
	_start_func  'op_55c8_0'
	xor	edx, edx
	mov	bl, BYTE PTR _regflags+2
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	shr	ecx, 8
	mov	dh, al
	and	ecx, 7
	xor	eax, eax
	mov	si, WORD PTR _regs[ecx*4]
	test	bl, bl
	sete	al
	test	eax, eax
	je	SHORT $L82766
	lea	eax, DWORD PTR [esi-1]
	test	si, si
	mov	WORD PTR _regs[ecx*4], ax
	je	SHORT $L82766
	movsx	ecx, dx
	mov	edx, DWORD PTR _regs+92
	lea	eax, DWORD PTR [edx+ecx+2]
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L82766:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_55c8_0@4 ENDP


@op_d170_0@4 PROC NEAR
	_start_func  'op_d170_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	mov	di, WORD PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ebp, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+ebp]
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	movsx	eax, si
	movsx	ecx, di
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	di, di
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, di
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d170_0@4 ENDP


@op_e1a0_0@4 PROC NEAR
	_start_func  'op_e1a0_0'
	mov	esi, ecx
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+2, 0
	shr	esi, 8
	mov	edx, DWORD PTR _regs[ecx*4]
	and	esi, 7
	and	edx, 63					; 0000003fH
	mov	BYTE PTR _regflags+3, 0
	mov	eax, DWORD PTR _regs[esi*4]
	cmp	edx, 32					; 00000020H
	jl	SHORT $L82801
	test	eax, eax
	setne	cl
	cmp	edx, 32					; 00000020H
	mov	BYTE PTR _regflags+3, cl
	jne	SHORT $L115344
	and	al, 1
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L82803
$L115344:
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L82803
$L82801:
	test	edx, edx
	jle	SHORT $L82803
	mov	ecx, 31					; 0000001fH
	push	edi
	sub	ecx, edx
	or	edi, -1
	shl	edi, cl
	mov	ecx, edi
	and	ecx, eax
	cmp	ecx, edi
	pop	edi
	je	SHORT $L115346
	test	ecx, ecx
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L115347
$L115346:
	mov	BYTE PTR _regflags+3, 0
$L115347:
	lea	ecx, DWORD PTR [edx-1]
	shl	eax, cl
	mov	ecx, eax
	shr	ecx, 31					; 0000001fH
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shl	eax, 1
$L82803:
	test	eax, eax
	sete	dl
	test	eax, eax
	mov	DWORD PTR _regs[esi*4], eax
	mov	eax, DWORD PTR _regs+92
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e1a0_0@4 ENDP


_src$82812 = -5
_newv$82815 = -4
@op_d118_0@4 PROC NEAR
	_start_func  'op_d118_0'
	mov	eax, ecx
	shr	eax, 8
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	eax, 7
	push	edi
	xor	ebx, ebx
	mov	esi, DWORD PTR _regs[eax*4+32]
	lea	edi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	dl, BYTE PTR [esi+ebp]
	add	eax, esi
	shr	ecx, 1
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	DWORD PTR [edi], eax
	movsx	eax, dl
	movsx	edi, cl
	add	eax, edi
	mov	BYTE PTR _src$82812[esp+24], cl
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _newv$82815[esp+24], eax
	pop	edi
	sete	al
	test	dl, dl
	mov	BYTE PTR _regflags+1, al
	setl	al
	xor	al, bl
	test	cl, cl
	setl	cl
	xor	cl, bl
	and	al, cl
	mov	BYTE PTR _regflags+3, al
	mov	al, BYTE PTR _src$82812[esp+20]
	not	dl
	cmp	dl, al
	setb	al
	test	ebx, ebx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$82815[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d118_0@4 ENDP


@op_c038_0@4 PROC NEAR
	_start_func  'op_c038_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 1
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	al, BYTE PTR [edx+eax]
	mov	dl, BYTE PTR _regs[ecx*4]
	and	al, dl
	mov	dl, 0
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 4
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c038_0@4 ENDP


@op_d07c_0@4 PROC NEAR
	_start_func  'op_d07c_0'
	xor	edx, edx
	shr	ecx, 1
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	si, WORD PTR _regs[ecx*4]
	mov	ebp, edx
	movsx	edi, si
	movsx	eax, bp
	add	edi, eax
	xor	eax, eax
	test	di, di
	setl	al
	test	di, di
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	mov	WORD PTR _regs[ecx*4], di
	setl	dl
	xor	dl, al
	test	bp, bp
	setl	bl
	xor	bl, al
	not	esi
	and	dl, bl
	cmp	si, bp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d07c_0@4 ENDP


@op_e1b0_0@4 PROC NEAR
	_start_func  'op_e1b0_0'
	mov	esi, ecx
	shr	ecx, 1
	and	ecx, 7
	shr	esi, 8
	mov	eax, DWORD PTR _regs[ecx*4]
	and	esi, 7
	and	eax, 63					; 0000003fH
	mov	BYTE PTR _regflags+3, 0
	mov	edi, DWORD PTR _regs[esi*4]
	cmp	eax, 33					; 00000021H
	jl	SHORT $L82876
	sub	eax, 33					; 00000021H
$L82876:
	test	eax, eax
	jle	SHORT $L82877
	dec	eax
	mov	ecx, 31					; 0000001fH
	sub	ecx, eax
	mov	edx, edi
	shr	edx, cl
	movsx	ecx, BYTE PTR _regflags+4
	add	edi, edi
	or	edi, ecx
	mov	ecx, eax
	shl	edi, cl
	mov	eax, edx
	shr	eax, 1
	or	edi, eax
	and	dl, 1
	mov	BYTE PTR _regflags+4, dl
$L82877:
	test	edi, edi
	sete	dl
	mov	cl, BYTE PTR _regflags+4
	mov	DWORD PTR _regs[esi*4], edi
	test	edi, edi
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e1b0_0@4 ENDP


_dsta$82888 = -4
@op_690_0@4 PROC NEAR
	_start_func  'op_690_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	DWORD PTR _dsta$82888[ebp], ecx
	mov	esi, DWORD PTR [edx+ecx]
	bswap	esi
	lea	edx, DWORD PTR [esi+edi]
	xor	eax, eax
	test	edx, edx
	setl	al
	test	edx, edx
	sete	cl
	test	esi, esi
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, al
	test	edi, edi
	setl	bl
	xor	bl, al
	not	esi
	and	cl, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, cl
	setb	cl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _dsta$82888[ebp]
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_690_0@4 ENDP


@op_c138_0@4 PROC NEAR
	_start_func  'op_c138_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 1
	or	esi, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	dl, BYTE PTR [eax+esi]
	mov	cl, BYTE PTR _regs[ecx*4]
	and	cl, dl
	mov	dl, 0
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [eax+esi], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c138_0@4 ENDP


@op_818_0@4 PROC NEAR
	_start_func  'op_818_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	al, BYTE PTR [esi+eax]
	add	ecx, esi
	mov	DWORD PTR [edx], ecx
	xor	ecx, ecx
	mov	cl, bh
	and	cl, 7
	sar	al, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_818_0@4 ENDP


_src$82931 = -5
_newv$82933 = -4
@op_d018_0@4 PROC NEAR
	_start_func  'op_d018_0'
	mov	eax, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	shr	ecx, 1
	and	eax, 7
	and	ecx, 7
	mov	esi, ecx
	lea	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	push	edi
	mov	edi, DWORD PTR [ecx]
	add	eax, edi
	mov	bl, BYTE PTR [edi+edx]
	mov	DWORD PTR [ecx], eax
	mov	al, BYTE PTR _regs[esi*4]
	mov	BYTE PTR _src$82931[esp+20], bl
	movsx	ecx, al
	movsx	edx, bl
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$82933[esp+20], ecx
	pop	edi
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$82931[esp+16]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$82933[esp+16]
	test	edx, edx
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	setne	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d018_0@4 ENDP


@op_5ae8_0@4 PROC NEAR
	_start_func  'op_5ae8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	xor	eax, eax
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	cl, BYTE PTR _regflags
	add	esi, edx
	test	cl, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	sete	al
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR [ecx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5ae8_0@4 ENDP


@op_11d0_0@4 PROC NEAR
	_start_func  'op_11d0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _regs+92
	xor	dl, dl
	mov	al, BYTE PTR [eax+esi]
	mov	cx, WORD PTR [ecx+2]
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	BYTE PTR [edx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11d0_0@4 ENDP


@op_a8_0@4 PROC NEAR
	_start_func  'op_a8_0'
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	shr	esi, 8
	mov	cx, WORD PTR [ecx+6]
	and	esi, 7
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	eax, ecx
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	ecx, DWORD PTR [edx+eax]
	bswap	ecx
	or	ecx, edi
	mov	edx, 0
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a8_0@4 ENDP


@op_1f0_0@4 PROC NEAR
	_start_func  'op_1f0_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	shr	ecx, 8
	mov	bl, BYTE PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	and	bl, 7
	mov	al, BYTE PTR [edi+esi]
	mov	cl, bl
	mov	dl, al
	sar	dl, cl
	movsx	ecx, bl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	dl, 1
	shl	dl, cl
	or	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1f0_0@4 ENDP


@op_4450_0@4 PROC NEAR
	_start_func  'op_4450_0'
	shr	ecx, 8
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	xor	edx, edx
	mov	edi, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	mov	ax, WORD PTR [edi+ebp]
	mov	cl, ah
	mov	ch, al
	mov	esi, ecx
	movsx	eax, si
	neg	eax
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	cl
	test	si, si
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	and	cl, dl
	test	si, si
	mov	BYTE PTR _regflags+3, cl
	seta	cl
	test	edx, edx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edi+ebp], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4450_0@4 ENDP


_src$83017 = -5
_newv$83023 = -4
@op_d138_0@4 PROC NEAR
	_start_func  'op_d138_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 1
	and	ecx, 7
	or	esi, eax
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	al, BYTE PTR [edi+esi]
	movsx	edx, al
	movsx	ebx, cl
	add	edx, ebx
	xor	ebx, ebx
	test	dl, dl
	setl	bl
	test	dl, dl
	mov	DWORD PTR _newv$83023[esp+20], edx
	mov	BYTE PTR _src$83017[esp+20], cl
	sete	dl
	test	al, al
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, bl
	test	cl, cl
	setl	cl
	xor	cl, bl
	and	dl, cl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$83017[esp+20]
	not	al
	cmp	al, dl
	setb	al
	test	ebx, ebx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$83023[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d138_0@4 ENDP


_src$83040 = -5
_newv$83043 = -4
@op_d130_0@4 PROC NEAR
	_start_func  'op_d130_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	shr	ecx, 8
	mov	bl, BYTE PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	mov	BYTE PTR _src$83040[esp+20], bl
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	movsx	edx, bl
	mov	al, BYTE PTR [edi+esi]
	movsx	ecx, al
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$83043[esp+20], ecx
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, BYTE PTR _src$83040[esp+20]
	not	al
	cmp	al, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$83043[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d130_0@4 ENDP


@op_e078_0@4 PROC NEAR
	_start_func  'op_e078_0'
	mov	edx, ecx
	xor	eax, eax
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+2, 0
	shr	edx, 8
	mov	cl, BYTE PTR _regs[ecx*4]
	and	edx, 7
	and	ecx, 63					; 0000003fH
	mov	BYTE PTR _regflags+3, 0
	mov	ax, WORD PTR _regs[edx*4]
	test	cx, cx
	jle	SHORT $L83067
	and	ecx, 15					; 0000000fH
	push	esi
	movsx	esi, cx
	mov	ecx, 16					; 00000010H
	push	edi
	sub	ecx, esi
	mov	edi, eax
	shl	edi, cl
	mov	ecx, esi
	shr	eax, cl
	or	edi, eax
	and	edi, 65535				; 0000ffffH
	mov	eax, edi
	pop	edi
	mov	ecx, eax
	pop	esi
	shr	ecx, 15					; 0000000fH
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
$L83067:
	test	ax, ax
	sete	cl
	test	ax, ax
	mov	WORD PTR _regs[edx*4], ax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e078_0@4 ENDP


_src$83078 = -4
_dst$83080 = -9
_flgn$83088 = -8
@op_5110_0@4 PROC NEAR
	_start_func  'op_5110_0'
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	eax, 1
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	and	eax, 7
	mov	edx, DWORD PTR _imm8_table[eax*4]
	mov	bl, BYTE PTR [edi+esi]
	movsx	ecx, dl
	movsx	eax, bl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	mov	BYTE PTR _dst$83080[esp+24], bl
	mov	DWORD PTR _src$83078[esp+24], edx
	setl	cl
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$83088[esp+24], ebx
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$83088[esp+24]
	setl	dl
	xor	dl, cl
	xor	bl, cl
	mov	cl, BYTE PTR _dst$83080[esp+24]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$83078[esp+24]
	cmp	dl, cl
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$83088[esp+24]
	test	ecx, ecx
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_5110_0@4 ENDP


_flgn$83111 = -4
@op_468_0@4 PROC NEAR
	_start_func  'op_468_0'
	mov	esi, eax
	xor	edx, edx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR [esi+4]
	mov	edi, edx
	xor	edx, edx
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	xor	edx, edx
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, ebp
	mov	ax, WORD PTR [ecx+esi]
	mov	dl, ah
	mov	dh, al
	mov	ebp, edx
	movsx	eax, bp
	movsx	ecx, di
	sub	eax, ecx
	xor	ecx, ecx
	test	bp, bp
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	di, di
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$83111[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	di, bp
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$83111[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_468_0@4 ENDP


@op_c1d8_0@4 PROC NEAR
	_start_func  'op_c1d8_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	eax, 8
	shr	ecx, 1
	and	eax, 7
	and	ecx, 7
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	dx, WORD PTR [ecx+edx]
	add	ecx, 2
	mov	DWORD PTR _regs[eax*4+32], ecx
	xor	eax, eax
	xor	ecx, ecx
	mov	al, dh
	mov	ch, dl
	movsx	eax, ax
	movsx	edx, cx
	movsx	ecx, WORD PTR _regs[esi*4]
	or	eax, edx
	imul	eax, ecx
	xor	ecx, ecx
	mov	DWORD PTR _regs[esi*4], eax
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c1d8_0@4 ENDP


@op_e128_0@4 PROC NEAR
	_start_func  'op_e128_0'
	mov	edx, ecx
	xor	eax, eax
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+2, 0
	shr	edx, 8
	mov	cl, BYTE PTR _regs[ecx*4]
	and	edx, 7
	and	cl, 63					; 0000003fH
	mov	BYTE PTR _regflags+3, 0
	mov	al, BYTE PTR _regs[edx*4]
	cmp	cl, 8
	jl	SHORT $L83146
	jne	SHORT $L115647
	and	al, 1
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L83148
$L115647:
	xor	al, al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	xor	eax, eax
	jmp	SHORT $L83148
$L83146:
	test	cl, cl
	jle	SHORT $L83148
	dec	ecx
	shl	eax, cl
	mov	ecx, eax
	and	eax, 127				; 0000007fH
	shr	ecx, 7
	and	cl, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	shl	eax, 1
$L83148:
	test	al, al
	sete	cl
	test	al, al
	mov	BYTE PTR _regs[edx*4], al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e128_0@4 ENDP


@op_56d0_0@4 PROC NEAR
	_start_func  'op_56d0_0'
	mov	dl, BYTE PTR _regflags+1
	xor	eax, eax
	shr	ecx, 8
	and	ecx, 7
	test	dl, dl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	sete	al
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_56d0_0@4 ENDP


_dstreg$ = -4
@op_9060_0@4 PROC NEAR
	_start_func  'op_9060_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	esi, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	sub	esi, 2
	mov	ebp, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _dstreg$[esp+20], ebp
	mov	dx, WORD PTR [ecx+esi]
	xor	ecx, ecx
	mov	cl, dh
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	bp, WORD PTR _regs[ebp*4]
	mov	ch, dl
	mov	edi, ecx
	xor	eax, eax
	movsx	esi, bp
	movsx	edx, di
	sub	esi, edx
	test	bp, bp
	setl	al
	xor	edx, edx
	test	si, si
	setl	dl
	test	si, si
	sete	cl
	test	di, di
	mov	BYTE PTR _regflags+1, cl
	mov	bl, dl
	setl	cl
	xor	cl, al
	xor	bl, al
	and	cl, bl
	cmp	di, bp
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _dstreg$[esp+20]
	test	edx, edx
	mov	WORD PTR _regs[eax*4], si
	mov	eax, DWORD PTR _regs+92
	setne	dl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9060_0@4 ENDP


@op_8110_0@4 PROC NEAR
	_start_func  'op_8110_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	dl, BYTE PTR [esi+eax]
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	or	cl, dl
	mov	dl, 0
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8110_0@4 ENDP


@op_1b0_0@4 PROC NEAR
	_start_func  'op_1b0_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	shr	ecx, 8
	mov	bl, BYTE PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	and	bl, 7
	mov	al, BYTE PTR [edi+esi]
	mov	cl, bl
	mov	dl, al
	sar	dl, cl
	movsx	ecx, bl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	dl, 1
	shl	dl, cl
	not	dl
	and	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1b0_0@4 ENDP


@op_e0b0_0@4 PROC NEAR
	_start_func  'op_e0b0_0'
	mov	esi, ecx
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+3, 0
	shr	esi, 8
	mov	eax, DWORD PTR _regs[ecx*4]
	and	esi, 7
	and	eax, 63					; 0000003fH
	mov	edx, DWORD PTR _regs[esi*4]
	cmp	eax, 33					; 00000021H
	jl	SHORT $L83213
	sub	eax, 33					; 00000021H
$L83213:
	test	eax, eax
	jle	SHORT $L83214
	movsx	ecx, BYTE PTR _regflags+4
	push	edi
	lea	edi, DWORD PTR [edx+edx]
	or	edi, ecx
	dec	eax
	mov	ecx, 31					; 0000001fH
	sub	ecx, eax
	shl	edi, cl
	mov	ecx, eax
	shr	edx, cl
	mov	eax, edx
	shr	edx, 1
	and	eax, 1
	or	edx, edi
	mov	BYTE PTR _regflags+4, al
	pop	edi
$L83214:
	mov	al, BYTE PTR _regflags+4
	mov	DWORD PTR _regs[esi*4], edx
	test	edx, edx
	sete	cl
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+1, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e0b0_0@4 ENDP


_src$83224 = -5
_newv$83230 = -4
@op_d128_0@4 PROC NEAR
	_start_func  'op_d128_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	mov	bl, BYTE PTR _regs[eax*4]
	mov	ax, WORD PTR [edx+2]
	xor	edx, edx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	BYTE PTR _src$83224[esp+20], bl
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	movsx	edx, bl
	add	esi, DWORD PTR _regs[ecx*4+32]
	mov	al, BYTE PTR [edi+esi]
	movsx	ecx, al
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$83230[esp+20], ecx
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$83224[esp+20]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$83230[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d128_0@4 ENDP


@op_c1d0_0@4 PROC NEAR
	_start_func  'op_c1d0_0'
	mov	esi, ecx
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	shr	esi, 1
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	mov	cx, WORD PTR [eax+ecx]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	movsx	edx, WORD PTR _regs[esi*4]
	or	eax, ecx
	xor	ecx, ecx
	imul	eax, edx
	cmp	eax, ecx
	mov	DWORD PTR _regs[esi*4], eax
	sete	dl
	cmp	eax, ecx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c1d0_0@4 ENDP


@op_80bc_0@4 PROC NEAR
	_start_func  'op_80bc_0'
	shr	ecx, 1
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4]
	or	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 6
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_80bc_0@4 ENDP


_flgn$83287 = -4
@op_450_0@4 PROC NEAR
	_start_func  'op_450_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+ebp]
	mov	cl, ah
	mov	esi, edx
	mov	ch, al
	mov	edi, ecx
	xor	ecx, ecx
	movsx	eax, di
	movsx	edx, si
	sub	eax, edx
	test	di, di
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	si, si
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$83287[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	si, di
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$83287[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_450_0@4 ENDP


_dsta$83298 = -8
_flgn$83307 = -4
@op_490_0@4 PROC NEAR
	_start_func  'op_490_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	DWORD PTR _dsta$83298[ebp], ecx
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	mov	esi, eax
	xor	ecx, ecx
	sub	esi, edi
	test	eax, eax
	setl	cl
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	edi, edi
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$83307[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$83307[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _dsta$83298[ebp]
	cmp	edi, eax
	seta	al
	test	ecx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	BYTE PTR _regflags+3, bl
	setne	al
	mov	BYTE PTR _regflags, al
	lea	eax, DWORD PTR [ecx+edx]
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_490_0@4 ENDP


@op_52c0_0@4 PROC NEAR
	_start_func  'op_52c0_0'
	mov	eax, DWORD PTR _regflags+1
	shr	ecx, 8
	and	ecx, 7
	test	ah, ah
	jne	SHORT $L115824
	test	al, al
	jne	SHORT $L115824
	mov	eax, 1
	jmp	SHORT $L115825
$L115824:
	xor	eax, eax
$L115825:
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_52c0_0@4 ENDP


@op_b048_0@4 PROC NEAR
	_start_func  'op_b048_0'
	mov	eax, ecx
	shr	eax, 8
	shr	ecx, 1
	and	eax, 7
	and	ecx, 7
	mov	dx, WORD PTR _regs[eax*4+32]
	mov	si, WORD PTR _regs[ecx*4]
	movsx	eax, si
	movsx	ecx, dx
	sub	eax, ecx
	xor	ecx, ecx
	test	si, si
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dx, dx
	setl	al
	cmp	eax, edi
	je	SHORT $L115855
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L115856
$L115855:
	mov	BYTE PTR _regflags+3, 0
$L115856:
	cmp	dx, si
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b048_0@4 ENDP


@op_1130_0@4 PROC NEAR
	_start_func  'op_1130_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ebx, DWORD PTR _areg_byteinc[esi*4]
	lea	edx, DWORD PTR _regs[esi*4+32]
	mov	cl, BYTE PTR [edi+eax]
	mov	eax, DWORD PTR [edx]
	sub	eax, ebx
	mov	DWORD PTR [edx], eax
	xor	dl, dl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+eax], cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1130_0@4 ENDP


@op_c1fc_0@4 PROC NEAR
	_start_func  'op_c1fc_0'
	shr	ecx, 1
	and	ecx, 7
	xor	edx, edx
	mov	esi, ecx
	mov	cx, WORD PTR [eax+2]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	movsx	edx, WORD PTR _regs[esi*4]
	or	eax, ecx
	xor	ecx, ecx
	imul	eax, edx
	cmp	eax, ecx
	mov	DWORD PTR _regs[esi*4], eax
	sete	dl
	cmp	eax, ecx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c1fc_0@4 ENDP


_x$115898 = -4
@op_d188_0@4 PROC NEAR
	_start_func  'op_d188_0'
	mov	ebp, esp
	push	ecx
	mov	eax, ecx
	push	ebx
	shr	eax, 8
	and	eax, 7
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	push	edi
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, 4
	shr	ecx, 1
	mov	ebx, DWORD PTR [esi+edx]
	bswap	ebx
	and	ecx, 7
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	esi, 4
	mov	eax, DWORD PTR [eax+esi]
	bswap	eax
	mov	DWORD PTR _x$115898[ebp], eax
	mov	dl, BYTE PTR _regflags+4
	mov	DWORD PTR _regs[ecx*4+32], esi
	xor	ecx, ecx
	test	dl, dl
	setne	cl
	add	ecx, eax
	xor	edx, edx
	add	ecx, ebx
	test	ebx, ebx
	mov	edi, ecx
	mov	ecx, DWORD PTR _x$115898[ebp]
	setl	dl
	xor	eax, eax
	test	ecx, ecx
	setl	al
	xor	ecx, ecx
	mov	bl, al
	test	edi, edi
	setl	cl
	xor	bl, cl
	xor	al, dl
	xor	cl, dl
	and	al, bl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	al, dl
	mov	BYTE PTR _regflags+3, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, al
	test	edi, edi
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+4, al
	test	edi, edi
	setl	al
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, al
	add	esi, ecx
	bswap	edi
	mov	DWORD PTR [esi], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d188_0@4 ENDP


_src$83390 = -5
_flgn$83402 = -4
@op_400_0@4 PROC NEAR
	_start_func  'op_400_0'
	shr	ecx, 8
	mov	dl, BYTE PTR [eax+3]
	and	ecx, 7
	push	esi
	mov	esi, ecx
	movsx	ecx, dl
	mov	bl, BYTE PTR _regs[esi*4]
	mov	BYTE PTR _src$83390[esp+16], dl
	movsx	eax, bl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	setl	cl
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$83402[esp+16], ebx
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$83402[esp+16]
	setl	dl
	xor	dl, cl
	xor	bl, cl
	mov	cl, BYTE PTR _regs[esi*4]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$83390[esp+16]
	cmp	dl, cl
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	pop	esi
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$83402[esp+12]
	test	ecx, ecx
	setne	cl
	add	eax, 4
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_400_0@4 ENDP


@op_1020_0@4 PROC NEAR
	_start_func  'op_1020_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	ebx, DWORD PTR _areg_byteinc[eax*4]
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	al, BYTE PTR [eax+edx]
	mov	DWORD PTR [esi], edx
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1020_0@4 ENDP


@op_c010_0@4 PROC NEAR
	_start_func  'op_c010_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	cl, BYTE PTR [ecx+edx]
	mov	dl, BYTE PTR _regs[eax*4]
	and	cl, dl
	mov	dl, 0
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regs[eax*4], cl
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c010_0@4 ENDP


_x$115945 = -12
_bf1$83452 = -20
@op_eee8_0@4 PROC NEAR
	_start_func  'op_eee8_0'
	mov	ebp, esp
	sub	esp, 20					; 00000014H
	push	ebx
	push	esi
	mov	esi, DWORD PTR _regs+92
	xor	edx, edx
	xor	ebx, ebx
	push	edi
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR [esi+4]
	mov	bl, ah
	movsx	edi, bx
	xor	ebx, ebx
	shr	ecx, 8
	mov	bh, al
	and	ecx, 7
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, edx
	or	edi, eax
	and	ecx, 2048				; 00000800H
	add	edi, ebx
	test	cx, cx
	movsx	eax, dx
	je	SHORT $L115928
	mov	ecx, eax
	sar	ecx, 6
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4]
	jmp	SHORT $L115929
$L115928:
	mov	esi, eax
	sar	esi, 6
	and	esi, 31					; 0000001fH
$L115929:
	test	dl, 32					; 00000020H
	je	SHORT $L115931
	and	eax, 7
	mov	eax, DWORD PTR _regs[eax*4]
$L115931:
	dec	eax
	mov	edx, esi
	and	eax, 31					; 0000001fH
	and	edx, -2147483648			; 80000000H
	inc	eax
	mov	ecx, esi
	neg	edx
	sbb	edx, edx
	and	edx, -536870912				; e0000000H
	sar	ecx, 3
	or	edx, ecx
	add	edi, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR [edx+edi]
	bswap	edx
	mov	DWORD PTR _x$115945[ebp], edx
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	add	ecx, edi
	and	esi, 7
	mov	DWORD PTR -16+[ebp], ecx
	mov	bl, BYTE PTR [ecx+4]
	mov	ecx, 8
	sub	ecx, esi
	mov	DWORD PTR _bf1$83452[ebp], ebx
	mov	DWORD PTR -4+[ebp], ecx
	mov	ecx, 32					; 00000020H
	sub	ecx, eax
	mov	DWORD PTR -8+[ebp], ecx
	mov	ecx, esi
	shl	edx, cl
	mov	ecx, DWORD PTR -4+[ebp]
	shr	ebx, cl
	mov	ecx, DWORD PTR -8+[ebp]
	or	edx, ebx
	mov	ebx, 1
	shr	edx, cl
	lea	ecx, DWORD PTR [eax-1]
	shl	ebx, cl
	test	ebx, edx
	setne	cl
	xor	ebx, ebx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR -8+[ebp]
	cmp	edx, ebx
	sete	dl
	mov	BYTE PTR _regflags+1, dl
	or	edx, -1
	add	eax, esi
	mov	BYTE PTR _regflags+3, bl
	shl	edx, cl
	cmp	eax, 32					; 00000020H
	mov	BYTE PTR _regflags+2, bl
	jge	SHORT $L115961
	or	ebx, -1
	mov	ecx, eax
	shr	ebx, cl
	and	ebx, DWORD PTR _x$115945[ebp]
$L115961:
	mov	DWORD PTR -8+[ebp], ebx
	mov	ecx, DWORD PTR -4+[ebp]
	mov	ebx, -16777216				; ff000000H
	shl	ebx, cl
	mov	ecx, DWORD PTR _x$115945[ebp]
	and	ebx, ecx
	mov	ecx, esi
	mov	DWORD PTR -12+[ebp], ebx
	mov	esi, DWORD PTR -8+[ebp]
	mov	ebx, edx
	shr	ebx, cl
	mov	ecx, DWORD PTR -12+[ebp]
	or	ecx, ebx
	or	ecx, esi
	mov	esi, DWORD PTR -16+[ebp]
	cmp	eax, 32					; 00000020H
	bswap	ecx
	mov	DWORD PTR [esi], ecx
	jle	SHORT $L115960
	mov	bl, BYTE PTR _bf1$83452[ebp]
	lea	ecx, DWORD PTR [eax-32]
	mov	eax, 255				; 000000ffH
	sar	eax, cl
	mov	ecx, DWORD PTR -4+[ebp]
	shl	dl, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	al, bl
	or	al, dl
	mov	BYTE PTR [ecx+edi+4], al
$L115960:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_eee8_0@4 ENDP


_flgn$83470 = -4
@op_9170_0@4 PROC NEAR
	_start_func  'op_9170_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	mov	si, WORD PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ebp, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+ebp]
	mov	dl, ah
	mov	dh, al
	mov	edi, edx
	movsx	eax, di
	movsx	ecx, si
	sub	eax, ecx
	xor	ecx, ecx
	test	di, di
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	si, si
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$83470[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	si, di
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$83470[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+ebp], cx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9170_0@4 ENDP


@op_21b8_0@4 PROC NEAR
	_start_func  'op_21b8_0'
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	push	esi
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [edx+eax]
	bswap	esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 1
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21b8_0@4 ENDP


@op_d160_0@4 PROC NEAR
	_start_func  'op_d160_0'
	mov	eax, ecx
	shr	eax, 8
	shr	ecx, 1
	and	eax, 7
	and	ecx, 7
	mov	esi, DWORD PTR _regs[eax*4+32]
	xor	edx, edx
	mov	bp, WORD PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	esi, 2
	mov	cx, WORD PTR [ecx+esi]
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	dl, ch
	mov	dh, cl
	mov	edi, edx
	movsx	eax, di
	movsx	ecx, bp
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	bp, bp
	setl	bl
	xor	bl, cl
	not	edi
	and	dl, bl
	cmp	di, bp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d160_0@4 ENDP


_flgn$83525 = -4
@op_9160_0@4 PROC NEAR
	_start_func  'op_9160_0'
	mov	eax, ecx
	shr	eax, 8
	shr	ecx, 1
	and	eax, 7
	and	ecx, 7
	mov	esi, DWORD PTR _regs[eax*4+32]
	mov	di, WORD PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	esi, 2
	xor	edx, edx
	mov	cx, WORD PTR [ecx+esi]
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	dl, ch
	mov	dh, cl
	mov	ebp, edx
	movsx	eax, bp
	movsx	ecx, di
	sub	eax, ecx
	xor	ecx, ecx
	test	bp, bp
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	di, di
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$83525[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	di, bp
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$83525[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9160_0@4 ENDP


@op_b07c_0@4 PROC NEAR
	_start_func  'op_b07c_0'
	xor	edx, edx
	shr	ecx, 1
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	si, WORD PTR _regs[ecx*4]
	mov	dh, al
	movsx	eax, si
	movsx	ecx, dx
	sub	eax, ecx
	xor	ecx, ecx
	test	si, si
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dx, dx
	setl	al
	cmp	eax, edi
	je	SHORT $L116033
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L116034
$L116033:
	mov	BYTE PTR _regflags+3, 0
$L116034:
	cmp	dx, si
	seta	dl
	test	ecx, ecx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	BYTE PTR _regflags+2, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b07c_0@4 ENDP


@op_11bc_0@4 PROC NEAR
	_start_func  'op_11bc_0'
	shr	ecx, 1
	mov	bl, BYTE PTR [eax+3]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	cl, cl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11bc_0@4 ENDP


@op_81fc_0@4 PROC NEAR
	_start_func  'op_81fc_0'
	mov	edx, eax
	shr	ecx, 1
	mov	ax, WORD PTR [edx+2]
	and	ecx, 7
	mov	ebp, ecx
	xor	ecx, ecx
	mov	cl, ah
	mov	edi, DWORD PTR _regs[ebp*4]
	mov	ch, al
	mov	eax, ecx
	xor	ecx, ecx
	cmp	ax, cx
	jne	SHORT $L83571
	mov	eax, DWORD PTR _regs+88
	mov	edi, DWORD PTR _regs+96
	sub	eax, edi
	add	eax, edx
	push	eax
	push	5
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L83571:
	push	ebx
	push	esi
	movsx	ebx, ax
	mov	eax, edi
	cdq
	idiv	ebx
	mov	esi, eax
	mov	eax, edi
	cdq
	idiv	ebx
	mov	eax, esi
	and	eax, -32768				; ffff8000H
	je	SHORT $L83583
	cmp	eax, -32768				; ffff8000H
	je	SHORT $L83583
	mov	al, 1
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	jmp	SHORT $L83584
$L83583:
	xor	eax, eax
	cmp	dx, cx
	setl	al
	xor	ebx, ebx
	cmp	edi, ecx
	setl	bl
	cmp	eax, ebx
	je	SHORT $L83588
	neg	edx
$L83588:
	cmp	si, cx
	mov	BYTE PTR _regflags+2, cl
	sete	al
	cmp	si, cx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	and	edx, 65535				; 0000ffffH
	and	esi, 65535				; 0000ffffH
	shl	edx, 16					; 00000010H
	or	edx, esi
	mov	BYTE PTR _regflags+1, al
	mov	BYTE PTR _regflags, cl
	mov	DWORD PTR _regs[ebp*4], edx
$L83584:
	mov	eax, DWORD PTR _regs+92
	pop	esi
	add	eax, 4
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_81fc_0@4 ENDP


@op_1a8_0@4 PROC NEAR
	_start_func  'op_1a8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	edx, ecx
	or	esi, eax
	shr	edx, 8
	and	edx, 7
	shr	ecx, 1
	mov	edi, DWORD PTR _regs[edx*4+32]
	and	ecx, 7
	add	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	al, BYTE PTR [edi+esi]
	and	cl, 7
	mov	dl, al
	sar	dl, cl
	movsx	ecx, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	dl, 1
	shl	dl, cl
	not	dl
	and	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1a8_0@4 ENDP


_newv$83616 = -4
@op_6a8_0@4 PROC NEAR
	_start_func  'op_6a8_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	push	esi
	push	edi
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	mov	eax, DWORD PTR _regs+92
	xor	ebx, ebx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+6]
	and	ecx, 7
	mov	bl, ah
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, al
	movsx	eax, bx
	or	esi, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, eax
	mov	edi, DWORD PTR [ecx+esi]
	bswap	edi
	lea	ecx, DWORD PTR [edi+edx]
	xor	eax, eax
	test	ecx, ecx
	setl	al
	test	ecx, ecx
	mov	DWORD PTR _newv$83616[ebp], ecx
	sete	cl
	test	edi, edi
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, al
	test	edx, edx
	setl	bl
	xor	bl, al
	not	edi
	and	cl, bl
	cmp	edi, edx
	mov	BYTE PTR _regflags+3, cl
	setb	cl
	test	eax, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, cl
	setne	dl
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags, dl
	add	esi, eax
	mov	ecx, DWORD PTR _newv$83616[ebp]
	pop	edi
	bswap	ecx
	mov	DWORD PTR [esi], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_6a8_0@4 ENDP


@op_103a_0@4 PROC NEAR
	_start_func  'op_103a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	mov	al, BYTE PTR [edx+esi+2]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_103a_0@4 ENDP


@op_138_0@4 PROC NEAR
	_start_func  'op_138_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 1
	and	ecx, 7
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	dl, BYTE PTR [edx+eax]
	and	cl, 7
	shr	dl, cl
	mov	DWORD PTR _regs+92, esi
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_138_0@4 ENDP


@op_b038_0@4 PROC NEAR
	_start_func  'op_b038_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 1
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	xor	ebx, ebx
	mov	dl, BYTE PTR [edx+eax]
	mov	cl, BYTE PTR _regs[ecx*4]
	movsx	eax, cl
	movsx	esi, dl
	sub	eax, esi
	test	cl, cl
	setl	bl
	mov	esi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dl, dl
	setl	al
	cmp	eax, esi
	mov	edi, ebx
	je	SHORT $L116135
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L116136
$L116135:
	mov	BYTE PTR _regflags+3, 0
$L116136:
	mov	eax, DWORD PTR _regs+92
	cmp	dl, cl
	seta	cl
	test	edi, edi
	setne	dl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b038_0@4 ENDP


@op_c1a8_0@4 PROC NEAR
	_start_func  'op_c1a8_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	push	esi
	push	edi
	mov	edi, DWORD PTR _regs[eax*4]
	mov	ax, WORD PTR [edx+2]
	xor	edx, edx
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, eax
	mov	eax, DWORD PTR [ecx+esi]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	edi, eax
	mov	eax, 0
	sete	dl
	cmp	edi, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	lea	eax, DWORD PTR [ecx+esi]
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c1a8_0@4 ENDP


@op_c070_0@4 PROC NEAR
	_start_func  'op_c070_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	mov	dl, ah
	mov	BYTE PTR _regflags+2, cl
	mov	dh, al
	mov	BYTE PTR _regflags+3, cl
	and	dx, WORD PTR _regs[esi*4]
	mov	eax, edx
	cmp	ax, cx
	mov	WORD PTR _regs[esi*4], ax
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c070_0@4 ENDP


@op_1e8_0@4 PROC NEAR
	_start_func  'op_1e8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	edx, ecx
	or	esi, eax
	shr	edx, 8
	and	edx, 7
	shr	ecx, 1
	mov	edi, DWORD PTR _regs[edx*4+32]
	and	ecx, 7
	add	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	al, BYTE PTR [edi+esi]
	and	cl, 7
	mov	dl, al
	sar	dl, cl
	movsx	ecx, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	dl, 1
	shl	dl, cl
	or	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1e8_0@4 ENDP


@op_8010_0@4 PROC NEAR
	_start_func  'op_8010_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	ecx, 8
	and	ecx, 7
	shr	eax, 1
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 7
	mov	cl, BYTE PTR [ecx+edx]
	mov	dl, BYTE PTR _regs[eax*4]
	or	cl, dl
	mov	dl, 0
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regs[eax*4], cl
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8010_0@4 ENDP


@op_8058_0@4 PROC NEAR
	_start_func  'op_8058_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	dx, WORD PTR [esi+edx]
	add	esi, 2
	mov	DWORD PTR _regs[eax*4+32], esi
	xor	eax, eax
	mov	al, dh
	and	ecx, 7
	mov	ah, dl
	xor	edx, edx
	or	ax, WORD PTR _regs[ecx*4]
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	cmp	ax, dx
	mov	WORD PTR _regs[ecx*4], ax
	sete	bl
	cmp	ax, dx
	mov	eax, DWORD PTR _regs+92
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8058_0@4 ENDP


@op_668_0@4 PROC NEAR
	_start_func  'op_668_0'
	mov	esi, eax
	xor	edx, edx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR [esi+4]
	mov	ebp, edx
	xor	edx, edx
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	xor	edx, edx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, eax
	mov	ax, WORD PTR [ecx+esi]
	mov	dl, ah
	mov	dh, al
	mov	edi, edx
	movsx	eax, di
	movsx	ecx, bp
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	bp, bp
	setl	bl
	xor	bl, cl
	not	edi
	and	dl, bl
	cmp	di, bp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_668_0@4 ENDP


@op_8018_0@4 PROC NEAR
	_start_func  'op_8018_0'
	mov	eax, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	mov	edi, DWORD PTR _regs[eax*4+32]
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	dl, BYTE PTR [edi+edx]
	add	eax, edi
	shr	ecx, 1
	and	ecx, 7
	mov	DWORD PTR [esi], eax
	mov	al, 0
	mov	bl, BYTE PTR _regs[ecx*4]
	mov	BYTE PTR _regflags+2, al
	or	dl, bl
	mov	BYTE PTR _regflags+3, al
	sete	bl
	cmp	dl, al
	mov	BYTE PTR _regs[ecx*4], dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8018_0@4 ENDP


@op_91fc_0@4 PROC NEAR
	_start_func  'op_91fc_0'
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	sub	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_91fc_0@4 ENDP


@op_91f8_0@4 PROC NEAR
	_start_func  'op_91f8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	sub	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_91f8_0@4 ENDP


@op_c0fa_0@4 PROC NEAR
	_start_func  'op_c0fa_0'
	shr	ecx, 1
	and	ecx, 7
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, ebx
	add	edx, eax
	mov	cx, WORD PTR [edx+ecx+2]
	xor	edx, edx
	mov	eax, ecx
	mov	dh, cl
	and	eax, 65535				; 0000ffffH
	and	edx, 65535				; 0000ffffH
	shr	eax, 8
	xor	ecx, ecx
	or	eax, edx
	mov	cx, WORD PTR _regs[esi*4]
	imul	eax, ecx
	xor	ecx, ecx
	mov	DWORD PTR _regs[esi*4], eax
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c0fa_0@4 ENDP


@op_d1fc_0@4 PROC NEAR
	_start_func  'op_d1fc_0'
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	add	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d1fc_0@4 ENDP


@op_31d0_0@4 PROC NEAR
	_start_func  'op_31d0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+esi]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	cx, WORD PTR [edx+2]
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31d0_0@4 ENDP


@op_80f0_0@4 PROC NEAR
	_start_func  'op_80f0_0'
	mov	eax, DWORD PTR _regs+96
	mov	edi, DWORD PTR _regs+88
	mov	esi, ecx
	sub	edi, eax
	mov	eax, DWORD PTR _regs+92
	add	edi, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ebp, DWORD PTR _regs[esi*4]
	mov	ax, WORD PTR [ecx+eax]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	test	ax, ax
	jne	SHORT $L83857
	push	edi
	push	5
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L83857:
	mov	edi, eax
	mov	eax, ebp
	and	edi, 65535				; 0000ffffH
	xor	edx, edx
	div	edi
	mov	ecx, eax
	cmp	ecx, 65535				; 0000ffffH
	jbe	SHORT $L83871
	mov	al, 1
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regflags+2, 0
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L83871:
	test	cx, cx
	sete	al
	test	cx, cx
	setl	dl
	mov	BYTE PTR _regflags+1, al
	mov	BYTE PTR _regflags, dl
	mov	eax, ebp
	xor	edx, edx
	div	edi
	and	ecx, 65535				; 0000ffffH
	mov	BYTE PTR _regflags+2, 0
	mov	BYTE PTR _regflags+3, 0
	shl	edx, 16					; 00000010H
	or	edx, ecx
	mov	DWORD PTR _regs[esi*4], edx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_80f0_0@4 ENDP


@op_4a88_0@4 PROC NEAR
	_start_func  'op_4a88_0'
	shr	ecx, 8
	and	ecx, 7
	xor	eax, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	cmp	ecx, eax
	sete	dl
	cmp	ecx, eax
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a88_0@4 ENDP


_flgs$83895 = -4
@op_9100_0@4 PROC NEAR
	_start_func  'op_9100_0'
	mov	al, BYTE PTR _regflags+4
	push	esi
	mov	esi, ecx
	shr	esi, 1
	and	esi, 7
	xor	edx, edx
	shr	ecx, 8
	mov	bl, BYTE PTR _regs[esi*4]
	and	ecx, 7
	test	al, al
	mov	cl, BYTE PTR _regs[ecx*4]
	movsx	eax, bl
	setne	dl
	sub	eax, edx
	movsx	edx, cl
	sub	eax, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	mov	DWORD PTR _flgs$83895[esp+16], edx
	xor	edx, edx
	test	bl, bl
	setl	dl
	xor	ecx, ecx
	mov	BYTE PTR _regs[esi*4], al
	test	al, al
	setl	cl
	mov	bl, cl
	pop	esi
	xor	bl, dl
	mov	BYTE PTR -5+[esp+12], bl
	mov	bl, BYTE PTR _flgs$83895[esp+12]
	xor	dl, bl
	mov	bl, BYTE PTR -5+[esp+12]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _flgs$83895[esp+12]
	xor	cl, dl
	and	cl, bl
	xor	cl, dl
	mov	dl, BYTE PTR _regflags+1
	test	al, al
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	sete	cl
	and	dl, cl
	test	al, al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_9100_0@4 ENDP


_src$83909 = -5
_newv$83914 = -4
@op_600_0@4 PROC NEAR
	_start_func  'op_600_0'
	shr	ecx, 8
	mov	bl, BYTE PTR [eax+3]
	and	ecx, 7
	mov	esi, ecx
	movsx	edx, bl
	mov	al, BYTE PTR _regs[esi*4]
	mov	BYTE PTR _src$83909[esp+16], bl
	movsx	ecx, al
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$83914[esp+16], ecx
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$83909[esp+16]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$83914[esp+16]
	test	edx, edx
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	setne	dl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_600_0@4 ENDP


@op_31c8_0@4 PROC NEAR
	_start_func  'op_31c8_0'
	xor	edx, edx
	shr	ecx, 8
	and	ecx, 7
	mov	ax, WORD PTR [eax+2]
	mov	BYTE PTR _regflags+2, dl
	mov	cx, WORD PTR _regs[ecx*4+32]
	mov	BYTE PTR _regflags+3, dl
	cmp	cx, dx
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ch
	xor	ebx, ebx
	mov	dh, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	bh, al
	movsx	ecx, cx
	movsx	eax, bx
	or	ecx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31c8_0@4 ENDP


@op_91d8_0@4 PROC NEAR
	_start_func  'op_91d8_0'
	mov	eax, ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	mov	edx, DWORD PTR [edx+esi]
	bswap	edx
	mov	esi, DWORD PTR _regs[eax*4+32]
	add	esi, 4
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	esi, DWORD PTR _regs[ecx*4+32]
	sub	esi, edx
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_91d8_0@4 ENDP


@op_8030_0@4 PROC NEAR
	_start_func  'op_8030_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	shr	esi, 1
	and	esi, 7
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [ecx+eax]
	mov	cl, BYTE PTR _regs[esi*4]
	or	al, cl
	mov	cl, 0
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regs[esi*4], al
	setl	cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8030_0@4 ENDP


@op_90fa_0@4 PROC NEAR
	_start_func  'op_90fa_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, ebx
	xor	ebx, ebx
	add	edx, eax
	shr	ecx, 1
	mov	ax, WORD PTR [edx+esi+2]
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	esi, DWORD PTR _regs[ecx*4+32]
	sub	esi, edx
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_90fa_0@4 ENDP


@op_51e0_0@4 PROC NEAR
	_start_func  'op_51e0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	eax, esi
	mov	DWORD PTR [edx], eax
	mov	BYTE PTR [ecx+eax], 0
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_51e0_0@4 ENDP


@op_3078_0@4 PROC NEAR
	_start_func  'op_3078_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 1
	and	ecx, 7
	or	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3078_0@4 ENDP


@op_54c0_0@4 PROC NEAR
	_start_func  'op_54c0_0'
	mov	dl, BYTE PTR _regflags+2
	xor	eax, eax
	shr	ecx, 8
	and	ecx, 7
	test	dl, dl
	sete	al
	neg	eax
	sbb	al, al
	and	eax, 255				; 000000ffH
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_54c0_0@4 ENDP


@op_4668_0@4 PROC NEAR
	_start_func  'op_4668_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	xor	edx, edx
	mov	edi, DWORD PTR _regs[ecx*4+32]
	add	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cx, WORD PTR [edi+esi]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	xor	ecx, ecx
	not	eax
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4668_0@4 ENDP


@op_a80_0@4 PROC NEAR
	_start_func  'op_a80_0'
	shr	ecx, 8
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4]
	xor	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	add	eax, 6
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a80_0@4 ENDP


@op_20a0_0@4 PROC NEAR
	_start_func  'op_20a0_0'
	mov	eax, ecx
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, 4
	mov	esi, DWORD PTR [esi+edx]
	bswap	esi
	mov	DWORD PTR _regs[eax*4+32], edx
	xor	eax, eax
	cmp	esi, eax
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	setl	al
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags, al
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	add	ecx, edx
	bswap	esi
	mov	DWORD PTR [ecx], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20a0_0@4 ENDP


@op_1098_0@4 PROC NEAR
	_start_func  'op_1098_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	edi, DWORD PTR [esi]
	add	eax, edi
	mov	dl, BYTE PTR [edi+ebp]
	mov	DWORD PTR [esi], eax
	xor	al, al
	cmp	dl, al
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	dl, al
	mov	BYTE PTR _regflags+3, al
	setl	al
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, al
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [ecx+ebp], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1098_0@4 ENDP


@op_1039_0@4 PROC NEAR
	_start_func  'op_1039_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [edx+eax]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1039_0@4 ENDP


@op_b0f8_0@4 PROC NEAR
	_start_func  'op_b0f8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	and	ecx, 7
	mov	esi, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	xor	edx, edx
	movsx	edi, si
	mov	eax, ecx
	sub	eax, edi
	test	ecx, ecx
	setl	dl
	mov	ebp, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	si, si
	setl	al
	cmp	eax, ebp
	je	SHORT $L116559
	cmp	edx, ebp
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L116560
$L116559:
	mov	BYTE PTR _regflags+3, 0
$L116560:
	mov	eax, DWORD PTR _regs+92
	cmp	edi, ecx
	seta	cl
	test	edx, edx
	setne	dl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b0f8_0@4 ENDP


@op_10_0@4 PROC NEAR
	_start_func  'op_10_0'
	shr	ecx, 8
	mov	al, BYTE PTR [eax+3]
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	dl, BYTE PTR [esi+ecx]
	or	al, dl
	mov	dl, 0
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10_0@4 ENDP


@op_18_0@4 PROC NEAR
	_start_func  'op_18_0'
	shr	ecx, 8
	and	ecx, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	esi, ecx
	mov	al, BYTE PTR [eax+3]
	mov	edx, DWORD PTR _regs[esi*4+32]
	lea	edi, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _areg_byteinc[esi*4]
	mov	cl, BYTE PTR [edx+ebp]
	add	esi, edx
	or	al, cl
	mov	cl, 0
	sete	bl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	DWORD PTR [edi], esi
	setl	cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_18_0@4 ENDP


@op_20_0@4 PROC NEAR
	_start_func  'op_20_0'
	shr	ecx, 8
	mov	dl, BYTE PTR [eax+3]
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _areg_byteinc[ecx*4]
	lea	esi, DWORD PTR _regs[ecx*4+32]
	sub	eax, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [edi+eax]
	mov	DWORD PTR [esi], eax
	or	dl, cl
	mov	cl, 0
	sete	bl
	cmp	dl, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20_0@4 ENDP


@op_30_0@4 PROC NEAR
	_start_func  'op_30_0'
	shr	ecx, 8
	mov	bl, BYTE PTR [eax+3]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [esi+eax]
	or	bl, cl
	mov	cl, 0
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [esi+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30_0@4 ENDP


@op_38_0@4 PROC NEAR
	_start_func  'op_38_0'
	mov	esi, eax
	xor	eax, eax
	xor	edx, edx
	mov	cx, WORD PTR [esi+4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	al, ch
	mov	dh, cl
	movsx	eax, ax
	movsx	ecx, dx
	or	eax, ecx
	mov	cl, BYTE PTR [esi+3]
	mov	dl, 0
	mov	bl, BYTE PTR [edi+eax]
	mov	BYTE PTR _regflags+2, dl
	or	cl, bl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_38_0@4 ENDP


@op_39_0@4 PROC NEAR
	_start_func  'op_39_0'
	mov	ecx, eax
	mov	al, BYTE PTR [ecx+3]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	dl, BYTE PTR [esi+ecx]
	or	al, dl
	mov	dl, 0
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_39_0@4 ENDP


@op_3c_0@4 PROC NEAR
	_start_func  'op_3c_0'
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	or	WORD PTR _regs+76, cx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3c_0@4 ENDP


@op_58_0@4 PROC NEAR
	_start_func  'op_58_0'
	shr	ecx, 8
	and	ecx, 7
	mov	si, WORD PTR [eax+2]
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [edi+edx]
	lea	ebx, DWORD PTR [edx+2]
	mov	DWORD PTR _regs[ecx*4+32], ebx
	or	eax, esi
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	ch, al
	mov	WORD PTR [edi+edx], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_58_0@4 ENDP


@op_60_0@4 PROC NEAR
	_start_func  'op_60_0'
	shr	ecx, 8
	mov	dx, WORD PTR [eax+2]
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 2
	mov	di, WORD PTR [esi+eax]
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	ecx, edi
	or	ecx, edx
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	mov	ecx, edx
	xor	edx, edx
	cmp	cx, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ch
	mov	BYTE PTR _regflags+1, bl
	mov	dh, cl
	mov	WORD PTR [esi+eax], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_60_0@4 ENDP


@op_70_0@4 PROC NEAR
	_start_func  'op_70_0'
	mov	si, WORD PTR [eax+2]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	cx, WORD PTR [edi+eax]
	or	ecx, esi
	mov	dl, ch
	mov	dh, cl
	mov	ecx, edx
	xor	edx, edx
	cmp	cx, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ch
	mov	BYTE PTR _regflags+1, bl
	mov	dh, cl
	mov	WORD PTR [edi+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_70_0@4 ENDP


@op_78_0@4 PROC NEAR
	_start_func  'op_78_0'
	xor	edx, edx
	mov	si, WORD PTR [eax+2]
	mov	cx, WORD PTR [eax+4]
	xor	eax, eax
	mov	dh, cl
	mov	al, ch
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	eax, ax
	movsx	ecx, dx
	or	eax, ecx
	xor	edx, edx
	mov	cx, WORD PTR [edi+eax]
	or	ecx, esi
	mov	dl, ch
	mov	dh, cl
	mov	ecx, edx
	xor	edx, edx
	cmp	cx, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ch
	mov	BYTE PTR _regflags+1, bl
	mov	dh, cl
	mov	WORD PTR [edi+eax], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_78_0@4 ENDP


@op_79_0@4 PROC NEAR
	_start_func  'op_79_0'
	mov	dx, WORD PTR [eax+2]
	mov	ecx, DWORD PTR [eax+4]
	bswap	ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [esi+ecx]
	or	eax, edx
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	WORD PTR [esi+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_79_0@4 ENDP


@op_7c_0@4 PROC NEAR
	_start_func  'op_7c_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L84258
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L84258:
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	mov	ch, al
	or	WORD PTR _regs+76, cx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_7c_0@4 ENDP


@op_90_0@4 PROC NEAR
	_start_func  'op_90_0'
	push	ebx
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR [eax+ecx]
	bswap	eax
	or	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_90_0@4 ENDP


@op_98_0@4 PROC NEAR
	_start_func  'op_98_0'
	push	ebx
	shr	ecx, 8
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	push	edi
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [eax+edx]
	bswap	eax
	mov	edi, DWORD PTR _regs[ecx*4+32]
	add	edi, 4
	or	eax, esi
	mov	DWORD PTR _regs[ecx*4+32], edi
	mov	ecx, 0
	sete	bl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_98_0@4 ENDP


@op_a0_0@4 PROC NEAR
	_start_func  'op_a0_0'
	push	ebx
	shr	ecx, 8
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	sub	eax, 4
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	or	edx, esi
	mov	ecx, 0
	sete	bl
	cmp	edx, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a0_0@4 ENDP


@op_b0_0@4 PROC NEAR
	_start_func  'op_b0_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	or	ecx, esi
	mov	edx, 0
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b0_0@4 ENDP


@op_b8_0@4 PROC NEAR
	_start_func  'op_b8_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	mov	cx, WORD PTR [ecx+6]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	eax, ecx
	mov	ecx, DWORD PTR [edx+eax]
	bswap	ecx
	or	ecx, esi
	mov	edx, 0
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b8_0@4 ENDP


@op_b9_0@4 PROC NEAR
	_start_func  'op_b9_0'
	push	ebx
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	mov	ecx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [ecx+6]
	bswap	ecx
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [eax+ecx]
	bswap	eax
	or	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 10					; 0000000aH
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_b9_0@4 ENDP


@op_d0_0@4 PROC NEAR
	_start_func  'op_d0_0'
	mov	ebp, eax
	xor	edx, edx
	mov	esi, DWORD PTR _regs+88
	mov	ax, WORD PTR [ebp+2]
	mov	edi, DWORD PTR _regs+96
	mov	dl, ah
	mov	dh, al
	sub	esi, edi
	mov	edi, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	eax, edi
	sar	eax, 12					; 0000000cH
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 15					; 0000000fH
	add	esi, ebp
	movsx	ebx, BYTE PTR [edx+ecx]
	mov	eax, DWORD PTR _regs[eax*4]
	movsx	ecx, BYTE PTR [edx+ecx+1]
	test	edi, 32768				; 00008000H
	jne	SHORT $L84358
	movsx	eax, al
$L84358:
	cmp	ecx, eax
	je	SHORT $L116916
	cmp	ebx, eax
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L116917
$L116916:
	mov	BYTE PTR _regflags+1, 1
$L116917:
	cmp	ebx, ecx
	jg	SHORT $L116922
	cmp	eax, ebx
	jl	SHORT $L116918
	cmp	eax, ecx
	jg	SHORT $L116918
	xor	al, al
	jmp	SHORT $L116941
$L116922:
	cmp	eax, ecx
	jg	SHORT $L116918
	cmp	eax, ebx
	jl	SHORT $L116918
	xor	al, al
	jmp	SHORT $L116941
$L116918:
	mov	al, 1
$L116941:
	and	edi, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	di, di
	je	SHORT $L84361
	test	al, al
	je	SHORT $L84361
	push	esi
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L84361:
	add	ebp, 4
	mov	DWORD PTR _regs+92, ebp
	mov	eax,ebp
	movzx	ecx, word ptr[ebp]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_d0_0@4 ENDP


@op_e8_0@4 PROC NEAR
	_start_func  'op_e8_0'
	mov	ebx, eax
	mov	eax, DWORD PTR _regs+96
	mov	edi, DWORD PTR _regs+88
	mov	esi, ecx
	sub	edi, eax
	mov	ax, WORD PTR [ebx+2]
	xor	ecx, ecx
	xor	edx, edx
	mov	cl, ah
	add	edi, ebx
	mov	ch, al
	mov	ebp, ecx
	mov	cx, WORD PTR [ebx+4]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 8
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	mov	edx, DWORD PTR _regs[esi*4+32]
	add	eax, edx
	mov	edx, ebp
	sar	edx, 12					; 0000000cH
	and	edx, 15					; 0000000fH
	test	ebp, 32768				; 00008000H
	mov	ecx, DWORD PTR _regs[edx*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	movsx	esi, BYTE PTR [edx+eax]
	movsx	eax, BYTE PTR [edx+eax+1]
	jne	SHORT $L84382
	movsx	ecx, cl
$L84382:
	cmp	eax, ecx
	je	SHORT $L116946
	cmp	esi, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L116947
$L116946:
	mov	BYTE PTR _regflags+1, 1
$L116947:
	cmp	esi, eax
	jg	SHORT $L116952
	cmp	ecx, esi
	jl	SHORT $L116948
	cmp	ecx, eax
	jg	SHORT $L116948
	xor	al, al
	jmp	SHORT $L116975
$L116952:
	cmp	ecx, eax
	jg	SHORT $L116948
	cmp	ecx, esi
	jl	SHORT $L116948
	xor	al, al
	jmp	SHORT $L116975
$L116948:
	mov	al, 1
$L116975:
	and	ebp, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	bp, bp
	je	SHORT $L84385
	test	al, al
	je	SHORT $L84385
	push	edi
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L84385:
	add	ebx, 6
	mov	DWORD PTR _regs+92, ebx
	mov	eax,ebx
	movzx	ecx, word ptr[ebx]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e8_0@4 ENDP


@op_f0_0@4 PROC NEAR
	_start_func  'op_f0_0'
	mov	esi, eax
	mov	eax, DWORD PTR _regs+96
	mov	edi, DWORD PTR _regs+88
	sub	edi, eax
	mov	ax, WORD PTR [esi+2]
	add	edi, esi
	xor	ebx, ebx
	add	esi, 4
	mov	bl, ah
	mov	DWORD PTR _regs+92, esi
	mov	bh, al
	mov	dx, WORD PTR [esi]
	add	esi, 2
	shr	ecx, 8
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, ebx
	sar	ecx, 12					; 0000000cH
	movsx	esi, BYTE PTR [edx+eax]
	movsx	eax, BYTE PTR [edx+eax+1]
	and	ecx, 15					; 0000000fH
	test	bh, -128				; ffffff80H
	mov	ecx, DWORD PTR _regs[ecx*4]
	jne	SHORT $L84403
	movsx	ecx, cl
$L84403:
	cmp	eax, ecx
	je	SHORT $L116980
	cmp	esi, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L116981
$L116980:
	mov	BYTE PTR _regflags+1, 1
$L116981:
	cmp	esi, eax
	jg	SHORT $L116986
	cmp	ecx, esi
	jl	SHORT $L116982
	cmp	ecx, eax
	jg	SHORT $L116982
	xor	al, al
	jmp	SHORT $L117015
$L116986:
	cmp	ecx, eax
	jg	SHORT $L116982
	cmp	ecx, esi
	jl	SHORT $L116982
	xor	al, al
	jmp	SHORT $L117015
$L116982:
	mov	al, 1
$L117015:
	and	ebx, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	bx, bx
	je	SHORT $L117013
	test	al, al
	je	SHORT $L117013
	push	edi
	push	6
	call	_Exception@8
$L117013:
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_f0_0@4 ENDP


@op_f8_0@4 PROC NEAR
	_start_func  'op_f8_0'
	mov	ebp, eax
	xor	ecx, ecx
	mov	ax, WORD PTR [ebp+2]
	xor	edx, edx
	mov	cl, ah
	mov	esi, DWORD PTR _regs+88
	mov	ch, al
	mov	ebx, DWORD PTR _regs+96
	mov	edi, ecx
	mov	cx, WORD PTR [ebp+4]
	mov	dl, ch
	sub	esi, ebx
	movsx	eax, dx
	xor	edx, edx
	add	esi, ebp
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, edi
	or	eax, ecx
	sar	edx, 12					; 0000000cH
	and	edx, 15					; 0000000fH
	test	edi, 32768				; 00008000H
	mov	ecx, DWORD PTR _regs[edx*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	movsx	ebx, BYTE PTR [edx+eax]
	movsx	eax, BYTE PTR [edx+eax+1]
	jne	SHORT $L84426
	movsx	ecx, cl
$L84426:
	cmp	eax, ecx
	je	SHORT $L117019
	cmp	ebx, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L117020
$L117019:
	mov	BYTE PTR _regflags+1, 1
$L117020:
	cmp	ebx, eax
	jg	SHORT $L117025
	cmp	ecx, ebx
	jl	SHORT $L117021
	cmp	ecx, eax
	jg	SHORT $L117021
	xor	al, al
	jmp	SHORT $L117048
$L117025:
	cmp	ecx, eax
	jg	SHORT $L117021
	cmp	ecx, ebx
	jl	SHORT $L117021
	xor	al, al
	jmp	SHORT $L117048
$L117021:
	mov	al, 1
$L117048:
	and	edi, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	di, di
	je	SHORT $L84429
	test	al, al
	je	SHORT $L84429
	push	esi
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L84429:
	add	ebp, 6
	mov	DWORD PTR _regs+92, ebp
	mov	eax,ebp
	movzx	ecx, word ptr[ebp]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_f8_0@4 ENDP


@op_f9_0@4 PROC NEAR
	_start_func  'op_f9_0'
	mov	esi, eax
	mov	ebx, DWORD PTR _regs+96
	mov	eax, DWORD PTR _regs+88
	xor	edx, edx
	sub	eax, ebx
	mov	cx, WORD PTR [esi+2]
	add	eax, esi
	mov	esi, DWORD PTR [esi+4]
	bswap	esi
	mov	dl, ch
	mov	dh, cl
	mov	edi, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, edi
	sar	ecx, 12					; 0000000cH
	movsx	ebx, BYTE PTR [edx+esi]
	movsx	edx, BYTE PTR [edx+esi+1]
	and	ecx, 15					; 0000000fH
	test	edi, 32768				; 00008000H
	mov	ecx, DWORD PTR _regs[ecx*4]
	jne	SHORT $L84447
	movsx	ecx, cl
$L84447:
	cmp	edx, ecx
	je	SHORT $L117053
	cmp	ebx, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L117054
$L117053:
	mov	BYTE PTR _regflags+1, 1
$L117054:
	cmp	ebx, edx
	jg	SHORT $L117059
	cmp	ecx, ebx
	jl	SHORT $L117055
	cmp	ecx, edx
	jg	SHORT $L117055
	xor	cl, cl
	jmp	SHORT $L117083
$L117059:
	cmp	ecx, edx
	jg	SHORT $L117055
	cmp	ecx, ebx
	jl	SHORT $L117055
	xor	cl, cl
	jmp	SHORT $L117083
$L117055:
	mov	cl, 1
$L117083:
	and	edi, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, cl
	test	di, di
	je	SHORT $L84450
	test	cl, cl
	je	SHORT $L84450
	push	eax
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L84450:
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_f9_0@4 ENDP


@op_fa_0@4 PROC NEAR
	_start_func  'op_fa_0'
	mov	ecx, DWORD PTR _regs+96
	mov	ebp, DWORD PTR _regs+88
	mov	esi, ebp
	sub	esi, ecx
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	xor	ebx, ebx
	mov	dl, ah
	add	esi, ecx
	mov	dh, al
	mov	ax, WORD PTR [ecx+4]
	mov	edi, edx
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	sub	edx, ebx
	mov	ebx, DWORD PTR _MEMBaseDiff
	add	edx, ebp
	lea	eax, DWORD PTR [edx+ecx+4]
	mov	edx, edi
	sar	edx, 12					; 0000000cH
	movsx	ebp, BYTE PTR [ebx+eax]
	movsx	eax, BYTE PTR [ebx+eax+1]
	and	edx, 15					; 0000000fH
	test	edi, 32768				; 00008000H
	mov	edx, DWORD PTR _regs[edx*4]
	jne	SHORT $L84471
	movsx	edx, dl
$L84471:
	cmp	eax, edx
	je	SHORT $L117088
	cmp	ebp, edx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L117089
$L117088:
	mov	BYTE PTR _regflags+1, 1
$L117089:
	cmp	ebp, eax
	jg	SHORT $L117094
	cmp	edx, ebp
	jl	SHORT $L117090
	cmp	edx, eax
	jg	SHORT $L117090
	xor	al, al
	jmp	SHORT $L117120
$L117094:
	cmp	edx, eax
	jg	SHORT $L117090
	cmp	edx, ebp
	jl	SHORT $L117090
	xor	al, al
	jmp	SHORT $L117120
$L117090:
	mov	al, 1
$L117120:
	and	edi, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	di, di
	je	SHORT $L84474
	test	al, al
	je	SHORT $L84474
	push	esi
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L84474:
	add	ecx, 6
	mov	DWORD PTR _regs+92, ecx
	mov	eax,ecx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_fa_0@4 ENDP


@op_fb_0@4 PROC NEAR
	_start_func  'op_fb_0'
	mov	edx, DWORD PTR _regs+96
	mov	esi, DWORD PTR _regs+88
	mov	cx, WORD PTR [eax+2]
	sub	esi, edx
	xor	edx, edx
	mov	dl, ch
	lea	ebp, DWORD PTR [esi+eax]
	mov	dh, cl
	add	eax, 4
	mov	edi, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	lea	ecx, DWORD PTR [esi+eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, edi
	sar	ecx, 12					; 0000000cH
	movsx	esi, BYTE PTR [edx+eax]
	movsx	eax, BYTE PTR [edx+eax+1]
	and	ecx, 15					; 0000000fH
	test	edi, 32768				; 00008000H
	mov	ecx, DWORD PTR _regs[ecx*4]
	jne	SHORT $L84493
	movsx	ecx, cl
$L84493:
	cmp	eax, ecx
	je	SHORT $L117125
	cmp	esi, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L117126
$L117125:
	mov	BYTE PTR _regflags+1, 1
$L117126:
	cmp	esi, eax
	jg	SHORT $L117131
	cmp	ecx, esi
	jl	SHORT $L117127
	cmp	ecx, eax
	jg	SHORT $L117127
	xor	al, al
	jmp	SHORT $L117162
$L117131:
	cmp	ecx, eax
	jg	SHORT $L117127
	cmp	ecx, esi
	jl	SHORT $L117127
	xor	al, al
	jmp	SHORT $L117162
$L117127:
	mov	al, 1
$L117162:
	and	edi, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	di, di
	je	SHORT $L117160
	test	al, al
	je	SHORT $L117160
	push	ebp
	push	6
	call	_Exception@8
$L117160:
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_fb_0@4 ENDP


@op_108_0@4 PROC NEAR
	_start_func  'op_108_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	edx, ecx
	or	esi, eax
	shr	edx, 8
	and	edx, 7
	shr	ecx, 1
	mov	eax, DWORD PTR _regs[edx*4+32]
	and	ecx, 7
	add	esi, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	movzx	dx, BYTE PTR [eax+esi]
	movzx	ax, BYTE PTR [eax+esi+2]
	shl	edx, 8
	add	edx, eax
	mov	WORD PTR _regs[ecx*4], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_108_0@4 ENDP


@op_118_0@4 PROC NEAR
	_start_func  'op_118_0'
	mov	eax, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	and	ecx, 7
	mov	edi, DWORD PTR [esi]
	mov	cl, BYTE PTR _regs[ecx*4]
	add	eax, edi
	mov	dl, BYTE PTR [edi+edx]
	and	cl, 7
	sar	dl, cl
	mov	DWORD PTR [esi], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_118_0@4 ENDP


@op_120_0@4 PROC NEAR
	_start_func  'op_120_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	edi, DWORD PTR _areg_byteinc[eax*4]
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	sub	edx, edi
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	al, BYTE PTR [eax+edx]
	and	cl, 7
	mov	DWORD PTR [esi], edx
	sar	al, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_120_0@4 ENDP


@op_139_0@4 PROC NEAR
	_start_func  'op_139_0'
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	and	cl, 7
	mov	al, BYTE PTR [edx+eax]
	shr	al, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_139_0@4 ENDP


@op_13a_0@4 PROC NEAR
	_start_func  'op_13a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	shr	ecx, 1
	add	edx, ebx
	and	ecx, 7
	add	edx, eax
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	dl, BYTE PTR [edx+esi-2]
	and	cl, 7
	shr	dl, cl
	mov	DWORD PTR _regs+92, esi
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13a_0@4 ENDP


@op_13b_0@4 PROC NEAR
	_start_func  'op_13b_0'
	mov	edx, DWORD PTR _regs+96
	shr	ecx, 1
	and	ecx, 7
	add	eax, 2
	mov	bl, BYTE PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _regs+88
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, bl
	and	cl, 7
	mov	al, BYTE PTR [edx+eax]
	shr	al, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13b_0@4 ENDP


@op_13c_0@4 PROC NEAR
	_start_func  'op_13c_0'
	shr	ecx, 1
	mov	dl, BYTE PTR [eax+3]
	and	ecx, 7
	add	eax, 4
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	DWORD PTR _regs+92, eax
	and	cl, 7
	sar	dl, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13c_0@4 ENDP


@op_140_0@4 PROC NEAR
	_start_func  'op_140_0'
	mov	eax, ecx
	shr	ecx, 1
	and	ecx, 7
	mov	edx, 1
	shr	eax, 8
	mov	esi, DWORD PTR _regs[ecx*4]
	and	eax, 7
	and	esi, 31					; 0000001fH
	mov	edi, DWORD PTR _regs[eax*4]
	mov	ecx, esi
	shl	edx, cl
	xor	edi, edx
	and	edx, edi
	mov	DWORD PTR _regs[eax*4], edi
	mov	eax, DWORD PTR _regs+92
	sar	edx, cl
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_140_0@4 ENDP


@op_148_0@4 PROC NEAR
	_start_func  'op_148_0'
	mov	esi, ecx
	mov	cx, WORD PTR [eax+2]
	xor	edx, edx
	mov	dl, ch
	xor	ebx, ebx
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, esi
	or	eax, ecx
	shr	edx, 8
	and	edx, 7
	shr	esi, 1
	mov	ecx, DWORD PTR _regs[edx*4+32]
	xor	edx, edx
	add	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	esi, 7
	mov	dl, BYTE PTR [ecx+eax]
	mov	bl, BYTE PTR [ecx+eax+2]
	shl	edx, 8
	add	edx, ebx
	xor	ebx, ebx
	mov	bl, BYTE PTR [ecx+eax+4]
	shl	edx, 8
	add	edx, ebx
	xor	ebx, ebx
	mov	bl, BYTE PTR [ecx+eax+6]
	shl	edx, 8
	add	edx, ebx
	mov	DWORD PTR _regs[esi*4], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_148_0@4 ENDP


@op_150_0@4 PROC NEAR
	_start_func  'op_150_0'
	mov	eax, ecx
	shr	ecx, 1
	and	ecx, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	mov	cl, BYTE PTR _regs[ecx*4]
	and	cl, 7
	and	eax, 7
	movsx	esi, cl
	mov	edi, DWORD PTR _regs[eax*4+32]
	mov	al, 1
	mov	ecx, esi
	shl	al, cl
	mov	cl, BYTE PTR [edi+ebp]
	mov	edx, 1
	xor	al, cl
	mov	ecx, esi
	shl	edx, cl
	movsx	ecx, al
	and	edx, ecx
	mov	ecx, esi
	sar	edx, cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR [edi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_150_0@4 ENDP


@op_158_0@4 PROC NEAR
	_start_func  'op_158_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	and	ecx, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR _regs[ecx*4]
	add	eax, edx
	mov	bl, BYTE PTR [edi+edx]
	and	cl, 7
	mov	DWORD PTR [esi], eax
	mov	al, 1
	movsx	esi, cl
	mov	ecx, esi
	shl	al, cl
	xor	bl, al
	mov	eax, 1
	shl	eax, cl
	movsx	ecx, bl
	and	eax, ecx
	mov	ecx, esi
	sar	eax, cl
	mov	BYTE PTR _regflags+1, al
	mov	BYTE PTR [edi+edx], bl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_158_0@4 ENDP


@op_160_0@4 PROC NEAR
	_start_func  'op_160_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	bl, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	edi, DWORD PTR _areg_byteinc[eax*4]
	lea	esi, DWORD PTR _regs[eax*4+32]
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	al, BYTE PTR [edi+edx]
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	DWORD PTR [esi], edx
	and	cl, 7
	movsx	esi, cl
	mov	ecx, esi
	shl	bl, cl
	xor	al, bl
	mov	ebx, 1
	shl	ebx, cl
	movsx	ecx, al
	and	ebx, ecx
	mov	ecx, esi
	sar	ebx, cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edi+edx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_160_0@4 ENDP


@op_168_0@4 PROC NEAR
	_start_func  'op_168_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	ebp, DWORD PTR _MEMBaseDiff
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	edx, ecx
	or	esi, eax
	shr	ecx, 1
	shr	edx, 8
	and	ecx, 7
	and	edx, 7
	mov	al, 1
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	edi, DWORD PTR _regs[edx*4+32]
	and	cl, 7
	add	esi, edi
	movsx	edi, cl
	mov	ecx, edi
	mov	edx, 1
	shl	al, cl
	mov	cl, BYTE PTR [esi+ebp]
	xor	al, cl
	mov	ecx, edi
	shl	edx, cl
	movsx	ecx, al
	and	edx, ecx
	mov	ecx, edi
	sar	edx, cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR [esi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_168_0@4 ENDP


@op_170_0@4 PROC NEAR
	_start_func  'op_170_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	shr	ecx, 8
	mov	bl, BYTE PTR _regs[eax*4]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	and	bl, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	movsx	esi, bl
	mov	dl, 1
	mov	ecx, esi
	mov	edi, eax
	shl	dl, cl
	mov	al, BYTE PTR [edi+ebp]
	xor	dl, al
	mov	eax, 1
	shl	eax, cl
	movsx	ecx, dl
	and	eax, ecx
	mov	ecx, esi
	sar	eax, cl
	mov	BYTE PTR _regflags+1, al
	mov	BYTE PTR [edi+ebp], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_170_0@4 ENDP


@op_178_0@4 PROC NEAR
	_start_func  'op_178_0'
	xor	edx, edx
	shr	ecx, 1
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	and	ecx, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	movsx	esi, dx
	mov	cl, BYTE PTR _regs[ecx*4]
	xor	edx, edx
	mov	dh, al
	and	cl, 7
	movsx	eax, dx
	movsx	edi, cl
	or	esi, eax
	mov	al, 1
	mov	ecx, edi
	mov	edx, 1
	shl	al, cl
	mov	cl, BYTE PTR [esi+ebp]
	xor	al, cl
	mov	ecx, edi
	shl	edx, cl
	movsx	ecx, al
	and	edx, ecx
	mov	ecx, edi
	sar	edx, cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR [esi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_178_0@4 ENDP


@op_179_0@4 PROC NEAR
	_start_func  'op_179_0'
	shr	ecx, 1
	and	ecx, 7
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	cl, BYTE PTR _regs[ecx*4]
	and	cl, 7
	mov	edx, DWORD PTR _MEMBaseDiff
	movsx	esi, cl
	mov	bl, BYTE PTR [edx+edi]
	mov	al, 1
	mov	ecx, esi
	shl	al, cl
	xor	al, bl
	mov	ebx, 1
	shl	ebx, cl
	movsx	ecx, al
	and	ebx, ecx
	mov	ecx, esi
	sar	ebx, cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_179_0@4 ENDP


@op_17a_0@4 PROC NEAR
	_start_func  'op_17a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	edi, DWORD PTR _regs+96
	mov	dl, ah
	mov	bh, al
	mov	ebp, DWORD PTR _MEMBaseDiff
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 1
	or	edx, eax
	mov	eax, DWORD PTR _regs+88
	and	ecx, 7
	sub	edx, edi
	add	edx, eax
	mov	al, 1
	mov	cl, BYTE PTR _regs[ecx*4]
	and	cl, 7
	lea	edi, DWORD PTR [edx+esi+2]
	movsx	esi, cl
	mov	ecx, esi
	mov	edx, 1
	shl	al, cl
	mov	cl, BYTE PTR [edi+ebp]
	xor	al, cl
	mov	ecx, esi
	shl	edx, cl
	movsx	ecx, al
	and	edx, ecx
	mov	ecx, esi
	sar	edx, cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR [edi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_17a_0@4 ENDP


@op_17b_0@4 PROC NEAR
	_start_func  'op_17b_0'
	mov	edx, DWORD PTR _regs+96
	shr	ecx, 1
	and	ecx, 7
	add	eax, 2
	mov	bl, BYTE PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _regs+88
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	and	bl, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	movsx	esi, bl
	mov	dl, 1
	mov	ecx, esi
	mov	edi, eax
	shl	dl, cl
	mov	al, BYTE PTR [edi+ebp]
	xor	dl, al
	mov	eax, 1
	shl	eax, cl
	movsx	ecx, dl
	and	eax, ecx
	mov	ecx, esi
	sar	eax, cl
	mov	BYTE PTR _regflags+1, al
	mov	BYTE PTR [edi+ebp], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_17b_0@4 ENDP


@op_188_0@4 PROC NEAR
	_start_func  'op_188_0'
	mov	edx, eax
	xor	ebx, ebx
	mov	dx, WORD PTR [edx+2]
	mov	eax, ecx
	mov	bl, dh
	movsx	esi, bx
	xor	ebx, ebx
	shr	eax, 1
	mov	bh, dl
	and	eax, 7
	shr	ecx, 8
	mov	ax, WORD PTR _regs[eax*4]
	and	ecx, 7
	movsx	edx, bx
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	or	esi, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, eax
	add	esi, ebx
	sar	ecx, 8
	mov	BYTE PTR [edx+esi], cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR [ecx+esi+2], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_188_0@4 ENDP


@op_190_0@4 PROC NEAR
	_start_func  'op_190_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	dl, BYTE PTR [esi+eax]
	and	ecx, 7
	mov	bl, dl
	mov	cl, BYTE PTR _regs[ecx*4]
	and	cl, 7
	sar	bl, cl
	movsx	ecx, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	mov	bl, 1
	shl	bl, cl
	not	bl
	and	bl, dl
	mov	BYTE PTR [esi+eax], bl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_190_0@4 ENDP


@op_198_0@4 PROC NEAR
	_start_func  'op_198_0'
	mov	eax, ecx
	shr	eax, 8
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	eax, 7
	mov	esi, DWORD PTR _regs[eax*4+32]
	lea	edi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	dl, BYTE PTR [esi+ebp]
	add	eax, esi
	shr	ecx, 1
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	DWORD PTR [edi], eax
	and	cl, 7
	mov	al, dl
	sar	al, cl
	movsx	ecx, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	al, 1
	shl	al, cl
	not	al
	and	al, dl
	mov	BYTE PTR [esi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_198_0@4 ENDP


_dst$84695 = -1
@op_1a0_0@4 PROC NEAR
	_start_func  'op_1a0_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	edi, DWORD PTR _areg_byteinc[eax*4]
	lea	esi, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	al, BYTE PTR [edi+edx]
	and	cl, 7
	mov	BYTE PTR _dst$84695[esp+12], al
	mov	DWORD PTR [esi], edx
	sar	al, cl
	movsx	ecx, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	al, 1
	shl	al, cl
	mov	cl, BYTE PTR _dst$84695[esp+12]
	not	al
	and	al, cl
	mov	BYTE PTR [edi+edx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1a0_0@4 ENDP


@op_1b8_0@4 PROC NEAR
	_start_func  'op_1b8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 1
	or	esi, eax
	and	ecx, 7
	mov	al, BYTE PTR [edi+esi]
	mov	cl, BYTE PTR _regs[ecx*4]
	and	cl, 7
	mov	dl, al
	sar	dl, cl
	movsx	ecx, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	dl, 1
	shl	dl, cl
	not	dl
	and	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1b8_0@4 ENDP


@op_1b9_0@4 PROC NEAR
	_start_func  'op_1b9_0'
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	and	cl, 7
	mov	dl, BYTE PTR [esi+eax]
	mov	bl, dl
	sar	bl, cl
	movsx	ecx, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	mov	bl, 1
	shl	bl, cl
	not	bl
	and	bl, dl
	mov	BYTE PTR [esi+eax], bl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1b9_0@4 ENDP


@op_1ba_0@4 PROC NEAR
	_start_func  'op_1ba_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _regs+88
	sub	edx, ebx
	add	edx, eax
	shr	ecx, 1
	lea	eax, DWORD PTR [edx+esi+2]
	mov	esi, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	dl, BYTE PTR [esi+eax]
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	bl, dl
	and	cl, 7
	sar	bl, cl
	movsx	ecx, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	mov	bl, 1
	shl	bl, cl
	not	bl
	and	bl, dl
	mov	BYTE PTR [esi+eax], bl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1ba_0@4 ENDP


@op_1bb_0@4 PROC NEAR
	_start_func  'op_1bb_0'
	shr	ecx, 1
	and	ecx, 7
	mov	esi, DWORD PTR _regs+96
	add	eax, 2
	mov	bl, BYTE PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _regs+88
	sub	ecx, esi
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	and	bl, 7
	mov	al, BYTE PTR [edi+esi]
	mov	cl, bl
	mov	dl, al
	sar	dl, cl
	movsx	ecx, bl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	dl, 1
	shl	dl, cl
	not	dl
	and	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1bb_0@4 ENDP


@op_1c8_0@4 PROC NEAR
	_start_func  'op_1c8_0'
	mov	edx, eax
	mov	esi, ecx
	mov	eax, esi
	xor	ebx, ebx
	mov	dx, WORD PTR [edx+2]
	shr	eax, 1
	and	eax, 7
	mov	bh, dl
	shr	esi, 8
	mov	ecx, DWORD PTR _regs[eax*4]
	xor	eax, eax
	mov	al, dh
	and	esi, 7
	movsx	eax, ax
	movsx	edx, bx
	mov	ebx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	or	eax, edx
	mov	edx, ecx
	add	eax, ebx
	sar	edx, 24					; 00000018H
	mov	BYTE PTR [esi+eax], dl
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, ecx
	sar	edx, 16					; 00000010H
	mov	BYTE PTR [esi+eax+2], dl
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, ecx
	sar	edx, 8
	mov	BYTE PTR [esi+eax+4], dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR [edx+eax+6], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1c8_0@4 ENDP


@op_1d0_0@4 PROC NEAR
	_start_func  'op_1d0_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	dl, BYTE PTR [esi+eax]
	and	ecx, 7
	mov	bl, dl
	mov	cl, BYTE PTR _regs[ecx*4]
	and	cl, 7
	sar	bl, cl
	movsx	ecx, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	mov	bl, 1
	shl	bl, cl
	or	bl, dl
	mov	BYTE PTR [esi+eax], bl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1d0_0@4 ENDP


@op_1d8_0@4 PROC NEAR
	_start_func  'op_1d8_0'
	mov	eax, ecx
	shr	eax, 8
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	eax, 7
	mov	esi, DWORD PTR _regs[eax*4+32]
	lea	edi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	dl, BYTE PTR [esi+ebp]
	add	eax, esi
	shr	ecx, 1
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	DWORD PTR [edi], eax
	and	cl, 7
	mov	al, dl
	sar	al, cl
	movsx	ecx, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	al, 1
	shl	al, cl
	or	al, dl
	mov	BYTE PTR [esi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1d8_0@4 ENDP


_dst$84767 = -1
@op_1e0_0@4 PROC NEAR
	_start_func  'op_1e0_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	edi, DWORD PTR _areg_byteinc[eax*4]
	lea	esi, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	al, BYTE PTR [edi+edx]
	and	cl, 7
	mov	BYTE PTR _dst$84767[esp+12], al
	mov	DWORD PTR [esi], edx
	sar	al, cl
	movsx	ecx, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	al, 1
	shl	al, cl
	or	al, BYTE PTR _dst$84767[esp+12]
	mov	BYTE PTR [edi+edx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1e0_0@4 ENDP


@op_1f8_0@4 PROC NEAR
	_start_func  'op_1f8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 1
	or	esi, eax
	and	ecx, 7
	mov	al, BYTE PTR [edi+esi]
	mov	cl, BYTE PTR _regs[ecx*4]
	and	cl, 7
	mov	dl, al
	sar	dl, cl
	movsx	ecx, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	dl, 1
	shl	dl, cl
	or	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1f8_0@4 ENDP


@op_1f9_0@4 PROC NEAR
	_start_func  'op_1f9_0'
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	and	cl, 7
	mov	dl, BYTE PTR [esi+eax]
	mov	bl, dl
	sar	bl, cl
	movsx	ecx, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	mov	bl, 1
	shl	bl, cl
	or	bl, dl
	mov	BYTE PTR [esi+eax], bl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1f9_0@4 ENDP


@op_1fa_0@4 PROC NEAR
	_start_func  'op_1fa_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _regs+88
	sub	edx, ebx
	add	edx, eax
	shr	ecx, 1
	lea	eax, DWORD PTR [edx+esi+2]
	mov	esi, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	dl, BYTE PTR [esi+eax]
	mov	cl, BYTE PTR _regs[ecx*4]
	mov	bl, dl
	and	cl, 7
	sar	bl, cl
	movsx	ecx, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	mov	bl, 1
	shl	bl, cl
	or	bl, dl
	mov	BYTE PTR [esi+eax], bl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1fa_0@4 ENDP


@op_1fb_0@4 PROC NEAR
	_start_func  'op_1fb_0'
	shr	ecx, 1
	and	ecx, 7
	mov	esi, DWORD PTR _regs+96
	add	eax, 2
	mov	bl, BYTE PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _regs+88
	sub	ecx, esi
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	and	bl, 7
	mov	al, BYTE PTR [edi+esi]
	mov	cl, bl
	mov	dl, al
	sar	dl, cl
	movsx	ecx, bl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	dl, 1
	shl	dl, cl
	or	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1fb_0@4 ENDP


@op_210_0@4 PROC NEAR
	_start_func  'op_210_0'
	shr	ecx, 8
	mov	al, BYTE PTR [eax+3]
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	dl, BYTE PTR [esi+ecx]
	and	al, dl
	mov	dl, 0
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_210_0@4 ENDP


@op_218_0@4 PROC NEAR
	_start_func  'op_218_0'
	shr	ecx, 8
	and	ecx, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	esi, ecx
	mov	al, BYTE PTR [eax+3]
	mov	edx, DWORD PTR _regs[esi*4+32]
	lea	edi, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _areg_byteinc[esi*4]
	mov	cl, BYTE PTR [edx+ebp]
	add	esi, edx
	and	al, cl
	mov	cl, 0
	sete	bl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	DWORD PTR [edi], esi
	setl	cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_218_0@4 ENDP


@op_220_0@4 PROC NEAR
	_start_func  'op_220_0'
	shr	ecx, 8
	mov	dl, BYTE PTR [eax+3]
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _areg_byteinc[ecx*4]
	lea	esi, DWORD PTR _regs[ecx*4+32]
	sub	eax, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [edi+eax]
	mov	DWORD PTR [esi], eax
	and	dl, cl
	mov	cl, 0
	sete	bl
	cmp	dl, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_220_0@4 ENDP


@op_230_0@4 PROC NEAR
	_start_func  'op_230_0'
	shr	ecx, 8
	mov	bl, BYTE PTR [eax+3]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [esi+eax]
	and	bl, cl
	mov	cl, 0
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [esi+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_230_0@4 ENDP


@op_238_0@4 PROC NEAR
	_start_func  'op_238_0'
	mov	esi, eax
	xor	eax, eax
	xor	edx, edx
	mov	cx, WORD PTR [esi+4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	al, ch
	mov	dh, cl
	movsx	eax, ax
	movsx	ecx, dx
	or	eax, ecx
	mov	cl, BYTE PTR [esi+3]
	mov	dl, 0
	mov	bl, BYTE PTR [edi+eax]
	mov	BYTE PTR _regflags+2, dl
	and	cl, bl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_238_0@4 ENDP


@op_239_0@4 PROC NEAR
	_start_func  'op_239_0'
	mov	ecx, eax
	mov	al, BYTE PTR [ecx+3]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	dl, BYTE PTR [esi+ecx]
	and	al, dl
	mov	dl, 0
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_239_0@4 ENDP


@op_23c_0@4 PROC NEAR
	_start_func  'op_23c_0'
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	or	ch, -1
	and	WORD PTR _regs+76, cx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23c_0@4 ENDP


@op_260_0@4 PROC NEAR
	_start_func  'op_260_0'
	shr	ecx, 8
	and	ecx, 7
	mov	ax, WORD PTR [eax+2]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	sub	esi, 2
	mov	dx, WORD PTR [edi+esi]
	mov	DWORD PTR _regs[ecx*4+32], esi
	xor	ecx, ecx
	mov	cl, dh
	mov	ch, dl
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	and	ecx, edx
	mov	eax, ecx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_260_0@4 ENDP


@op_270_0@4 PROC NEAR
	_start_func  'op_270_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [edi+esi]
	mov	dl, bh
	mov	cl, ah
	mov	dh, bl
	mov	ch, al
	xor	eax, eax
	and	ecx, edx
	mov	BYTE PTR _regflags+2, al
	cmp	cx, ax
	mov	BYTE PTR _regflags+3, al
	sete	dl
	cmp	cx, ax
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	mov	dh, cl
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_270_0@4 ENDP


@op_278_0@4 PROC NEAR
	_start_func  'op_278_0'
	mov	ecx, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ch
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	esi, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	esi, ecx
	xor	edx, edx
	mov	cx, WORD PTR [edi+esi]
	mov	dl, ch
	mov	dh, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	and	edx, ecx
	xor	ecx, ecx
	mov	eax, edx
	mov	BYTE PTR _regflags+2, cl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_278_0@4 ENDP


@op_279_0@4 PROC NEAR
	_start_func  'op_279_0'
	mov	ecx, eax
	mov	ax, WORD PTR [ecx+2]
	mov	esi, DWORD PTR [ecx+4]
	bswap	esi
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	cx, WORD PTR [edi+esi]
	mov	dl, ch
	mov	dh, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	and	edx, ecx
	xor	ecx, ecx
	mov	eax, edx
	mov	BYTE PTR _regflags+2, cl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_279_0@4 ENDP


@op_27c_0@4 PROC NEAR
	_start_func  'op_27c_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L84960
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L84960:
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	mov	ch, al
	and	WORD PTR _regs+76, cx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_27c_0@4 ENDP


@op_290_0@4 PROC NEAR
	_start_func  'op_290_0'
	push	ebx
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR [eax+ecx]
	bswap	eax
	and	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_290_0@4 ENDP


@op_298_0@4 PROC NEAR
	_start_func  'op_298_0'
	push	ebx
	shr	ecx, 8
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	push	edi
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [eax+edx]
	bswap	eax
	mov	edi, DWORD PTR _regs[ecx*4+32]
	add	edi, 4
	and	eax, esi
	mov	DWORD PTR _regs[ecx*4+32], edi
	mov	ecx, 0
	sete	bl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_298_0@4 ENDP


@op_2a0_0@4 PROC NEAR
	_start_func  'op_2a0_0'
	push	ebx
	shr	ecx, 8
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	sub	eax, 4
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	and	edx, esi
	mov	ecx, 0
	sete	bl
	cmp	edx, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2a0_0@4 ENDP


@op_2a8_0@4 PROC NEAR
	_start_func  'op_2a8_0'
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	shr	esi, 8
	mov	cx, WORD PTR [ecx+6]
	and	esi, 7
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	eax, ecx
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	ecx, DWORD PTR [edx+eax]
	bswap	ecx
	and	ecx, edi
	mov	edx, 0
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2a8_0@4 ENDP


@op_2b0_0@4 PROC NEAR
	_start_func  'op_2b0_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	and	ecx, esi
	mov	edx, 0
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2b0_0@4 ENDP


@op_2b8_0@4 PROC NEAR
	_start_func  'op_2b8_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	mov	cx, WORD PTR [ecx+6]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	eax, ecx
	mov	ecx, DWORD PTR [edx+eax]
	bswap	ecx
	and	ecx, esi
	mov	edx, 0
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2b8_0@4 ENDP


@op_2b9_0@4 PROC NEAR
	_start_func  'op_2b9_0'
	push	ebx
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	mov	ecx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [ecx+6]
	bswap	ecx
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [eax+ecx]
	bswap	eax
	and	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 10					; 0000000aH
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2b9_0@4 ENDP


@op_2d0_0@4 PROC NEAR
	_start_func  'op_2d0_0'
	mov	esi, DWORD PTR _regs+88
	mov	edi, DWORD PTR _regs+96
	xor	edx, edx
	sub	esi, edi
	xor	ebx, ebx
	add	esi, eax
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	sar	eax, 12					; 0000000cH
	shr	ecx, 8
	and	eax, 15					; 0000000fH
	and	ecx, 7
	mov	ebp, DWORD PTR _regs[eax*4]
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [eax+ecx]
	mov	bl, ah
	movsx	edi, bx
	xor	ebx, ebx
	mov	bh, al
	movsx	eax, bx
	or	edi, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	cx, WORD PTR [eax+ecx+2]
	xor	eax, eax
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	test	dh, -128				; ffffff80H
	jne	SHORT $L85076
	movsx	ebp, bp
$L85076:
	cmp	eax, ebp
	je	SHORT $L118031
	cmp	edi, ebp
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118032
$L118031:
	mov	BYTE PTR _regflags+1, 1
$L118032:
	cmp	edi, eax
	jg	SHORT $L118037
	cmp	ebp, edi
	jl	SHORT $L118033
	cmp	ebp, eax
	jg	SHORT $L118033
	xor	al, al
	jmp	SHORT $L118056
$L118037:
	cmp	ebp, eax
	jg	SHORT $L118033
	cmp	ebp, edi
	jl	SHORT $L118033
	xor	al, al
	jmp	SHORT $L118056
$L118033:
	mov	al, 1
$L118056:
	and	edx, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	dx, dx
	je	SHORT $L85079
	test	al, al
	je	SHORT $L85079
	push	esi
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L85079:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2d0_0@4 ENDP


@op_2e8_0@4 PROC NEAR
	_start_func  'op_2e8_0'
	mov	eax, DWORD PTR _regs+96
	mov	esi, ecx
	mov	edi, DWORD PTR _regs+88
	mov	ecx, DWORD PTR _regs+92
	sub	edi, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	add	edi, ecx
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ah
	mov	dh, al
	xor	eax, eax
	mov	ebp, edx
	xor	edx, edx
	mov	al, ch
	mov	dh, cl
	shr	esi, 8
	movsx	eax, ax
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	edx, ebp
	mov	ebx, DWORD PTR _regs[esi*4+32]
	add	eax, ebx
	xor	ebx, ebx
	sar	edx, 12					; 0000000cH
	mov	cx, WORD PTR [ecx+eax]
	and	edx, 15					; 0000000fH
	mov	bl, ch
	movsx	esi, bx
	xor	ebx, ebx
	mov	edx, DWORD PTR _regs[edx*4]
	mov	bh, cl
	movsx	ecx, bx
	or	esi, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+eax+2]
	xor	ecx, ecx
	mov	cl, ah
	mov	bh, al
	movsx	ecx, cx
	movsx	eax, bx
	or	ecx, eax
	test	ebp, 32768				; 00008000H
	jne	SHORT $L85100
	movsx	edx, dx
$L85100:
	cmp	ecx, edx
	mov	al, 1
	je	SHORT $L118061
	cmp	esi, edx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118062
$L118061:
	mov	BYTE PTR _regflags+1, al
$L118062:
	cmp	esi, ecx
	jg	SHORT $L118067
	cmp	edx, esi
	jl	SHORT $L118063
	cmp	edx, ecx
	jg	SHORT $L118063
	jmp	SHORT $L118091
$L118067:
	cmp	edx, ecx
	jg	SHORT $L118063
	cmp	edx, esi
	jl	SHORT $L118063
$L118091:
	xor	al, al
$L118063:
	and	ebp, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	bp, bp
	je	SHORT $L85103
	test	al, al
	je	SHORT $L85103
	push	edi
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L85103:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2e8_0@4 ENDP


@op_2f0_0@4 PROC NEAR
	_start_func  'op_2f0_0'
	mov	esi, DWORD PTR _regs+96
	mov	edi, DWORD PTR _regs+88
	sub	edi, esi
	mov	esi, DWORD PTR _regs+92
	xor	edx, edx
	add	edi, esi
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	DWORD PTR _regs+92, esi
	mov	dh, al
	add	esi, 2
	mov	ebp, edx
	mov	dx, WORD PTR [esi-2]
	shr	ecx, 8
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, ebp
	xor	ebx, ebx
	sar	ecx, 12					; 0000000cH
	and	ecx, 15					; 0000000fH
	mov	edx, DWORD PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	cx, WORD PTR [ecx+eax]
	mov	bl, ch
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, cl
	movsx	ecx, bx
	or	esi, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	cx, WORD PTR [ecx+eax+2]
	xor	eax, eax
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	test	ebp, 32768				; 00008000H
	jne	SHORT $L85121
	movsx	edx, dx
$L85121:
	cmp	eax, edx
	je	SHORT $L118095
	cmp	esi, edx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118096
$L118095:
	mov	BYTE PTR _regflags+1, 1
$L118096:
	cmp	esi, eax
	jg	SHORT $L118101
	cmp	edx, esi
	jl	SHORT $L118097
	cmp	edx, eax
	jg	SHORT $L118097
	xor	al, al
	jmp	SHORT $L118130
$L118101:
	cmp	edx, eax
	jg	SHORT $L118097
	cmp	edx, esi
	jl	SHORT $L118097
	xor	al, al
	jmp	SHORT $L118130
$L118097:
	mov	al, 1
$L118130:
	and	ebp, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	bp, bp
	je	SHORT $L118128
	test	al, al
	je	SHORT $L118128
	push	edi
	push	6
	call	_Exception@8
$L118128:
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2f0_0@4 ENDP


@op_2f8_0@4 PROC NEAR
	_start_func  'op_2f8_0'
	mov	ecx, eax
	mov	eax, DWORD PTR _regs+96
	mov	esi, DWORD PTR _regs+88
	sub	esi, eax
	mov	ax, WORD PTR [ecx+2]
	xor	edx, edx
	add	esi, ecx
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ah
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	ecx, edx
	sar	ecx, 12					; 0000000cH
	and	ecx, 15					; 0000000fH
	xor	ebx, ebx
	mov	ebp, DWORD PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	cx, WORD PTR [ecx+eax]
	mov	bl, ch
	movsx	edi, bx
	xor	ebx, ebx
	mov	bh, cl
	movsx	ecx, bx
	or	edi, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+eax+2]
	xor	ecx, ecx
	mov	cl, ah
	mov	bh, al
	movsx	ecx, cx
	movsx	eax, bx
	or	ecx, eax
	test	dh, -128				; ffffff80H
	jne	SHORT $L85144
	movsx	ebp, bp
$L85144:
	cmp	ecx, ebp
	mov	al, 1
	je	SHORT $L118134
	cmp	edi, ebp
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118135
$L118134:
	mov	BYTE PTR _regflags+1, al
$L118135:
	cmp	edi, ecx
	jg	SHORT $L118140
	cmp	ebp, edi
	jl	SHORT $L118136
	cmp	ebp, ecx
	jg	SHORT $L118136
	jmp	SHORT $L118164
$L118140:
	cmp	ebp, ecx
	jg	SHORT $L118136
	cmp	ebp, edi
	jl	SHORT $L118136
$L118164:
	xor	al, al
$L118136:
	and	edx, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	dx, dx
	je	SHORT $L85147
	test	al, al
	je	SHORT $L85147
	push	esi
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L85147:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2f8_0@4 ENDP


_extra$85154 = -4
@op_2f9_0@4 PROC NEAR
	_start_func  'op_2f9_0'
	mov	ebp, esp
	push	ecx
	mov	eax, DWORD PTR _regs+88
	mov	ecx, DWORD PTR _regs+96
	push	ebx
	push	esi
	mov	esi, DWORD PTR _regs+92
	sub	eax, ecx
	xor	edx, edx
	add	eax, esi
	mov	cx, WORD PTR [esi+2]
	mov	esi, DWORD PTR [esi+4]
	bswap	esi
	mov	dl, ch
	push	edi
	mov	dh, cl
	mov	ecx, edx
	mov	DWORD PTR _extra$85154[ebp], ecx
	sar	ecx, 12					; 0000000cH
	and	ecx, 15					; 0000000fH
	xor	ebx, ebx
	mov	edx, DWORD PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	cx, WORD PTR [ecx+esi]
	mov	bl, ch
	movsx	edi, bx
	xor	ebx, ebx
	mov	bh, cl
	movsx	ecx, bx
	or	edi, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	cx, WORD PTR [ecx+esi+2]
	mov	bl, ch
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, cl
	movsx	ecx, bx
	mov	ebx, DWORD PTR _extra$85154[ebp]
	or	esi, ecx
	test	bh, -128				; ffffff80H
	jne	SHORT $L85165
	movsx	edx, dx
$L85165:
	cmp	esi, edx
	mov	cl, 1
	je	SHORT $L118168
	cmp	edi, edx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118169
$L118168:
	mov	BYTE PTR _regflags+1, cl
$L118169:
	cmp	edi, esi
	jg	SHORT $L118174
	cmp	edx, edi
	jl	SHORT $L118170
	cmp	edx, esi
	jg	SHORT $L118170
	jmp	SHORT $L118199
$L118174:
	cmp	edx, esi
	jg	SHORT $L118170
	cmp	edx, edi
	jl	SHORT $L118170
$L118199:
	xor	cl, cl
$L118170:
	and	ebx, 2048				; 00000800H
	pop	edi
	pop	esi
	mov	BYTE PTR _regflags+2, cl
	test	bx, bx
	pop	ebx
	je	SHORT $L85168
	test	cl, cl
	je	SHORT $L85168
	push	eax
	push	6
	call	_Exception@8
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L85168:
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2f9_0@4 ENDP


_reg$85184 = -4
@op_2fa_0@4 PROC NEAR
	_start_func  'op_2fa_0'
	mov	ecx, DWORD PTR _regs+96
	mov	esi, DWORD PTR _regs+88
	mov	edi, eax
	xor	edx, edx
	mov	ebp, esi
	xor	ebx, ebx
	mov	ax, WORD PTR [edi+2]
	sub	ebp, ecx
	mov	dl, ah
	xor	ecx, ecx
	mov	dh, al
	mov	ax, WORD PTR [edi+4]
	mov	cl, ah
	mov	bh, al
	movsx	ecx, cx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	ecx, eax
	sub	ecx, ebx
	xor	ebx, ebx
	add	ecx, esi
	add	ebp, edi
	lea	eax, DWORD PTR [ecx+edi+4]
	mov	ecx, edx
	sar	ecx, 12					; 0000000cH
	and	ecx, 15					; 0000000fH
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	DWORD PTR _reg$85184[esp+20], ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	cx, WORD PTR [ecx+eax]
	mov	bl, ch
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, cl
	movsx	ecx, bx
	or	esi, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	cx, WORD PTR [ecx+eax+2]
	xor	eax, eax
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	movsx	ecx, WORD PTR _reg$85184[esp+20]
	test	dh, -128				; ffffff80H
	je	SHORT $L85189
	mov	ecx, DWORD PTR _reg$85184[esp+20]
$L85189:
	cmp	eax, ecx
	je	SHORT $L118202
	cmp	esi, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118203
$L118202:
	mov	BYTE PTR _regflags+1, 1
$L118203:
	cmp	esi, eax
	jg	SHORT $L118208
	cmp	ecx, esi
	jl	SHORT $L118204
	cmp	ecx, eax
	jg	SHORT $L118204
	xor	al, al
	jmp	SHORT $L118235
$L118208:
	cmp	ecx, eax
	jg	SHORT $L118204
	cmp	ecx, esi
	jl	SHORT $L118204
	xor	al, al
	jmp	SHORT $L118235
$L118204:
	mov	al, 1
$L118235:
	and	edx, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	dx, dx
	je	SHORT $L85192
	test	al, al
	je	SHORT $L85192
	push	ebp
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L85192:
	add	edi, 6
	mov	DWORD PTR _regs+92, edi
	mov	eax,edi
	movzx	ecx, word ptr[edi]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2fa_0@4 ENDP


_oldpc$85199 = -4
@op_2fb_0@4 PROC NEAR
	_start_func  'op_2fb_0'
	mov	eax, DWORD PTR _regs+96
	push	ebx
	push	ebp
	push	esi
	mov	esi, DWORD PTR _regs+88
	xor	edx, edx
	sub	esi, eax
	mov	eax, DWORD PTR _regs+92
	push	edi
	lea	ecx, DWORD PTR [esi+eax]
	add	eax, 4
	mov	DWORD PTR _oldpc$85199[esp+20], ecx
	mov	cx, WORD PTR [eax-2]
	mov	dl, ch
	mov	DWORD PTR _regs+92, eax
	mov	dh, cl
	lea	ecx, DWORD PTR [esi+eax]
	mov	edi, edx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, edi
	sar	ecx, 12					; 0000000cH
	and	ecx, 15					; 0000000fH
	xor	ebx, ebx
	mov	ebp, DWORD PTR _regs[ecx*4]
	mov	cx, WORD PTR [edx+eax]
	mov	bl, ch
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, cl
	movsx	ecx, bx
	or	esi, ecx
	mov	cx, WORD PTR [edx+eax+2]
	xor	edx, edx
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	test	edi, 32768				; 00008000H
	jne	SHORT $L85211
	movsx	ebp, bp
$L85211:
	cmp	eax, ebp
	je	SHORT $L118240
	cmp	esi, ebp
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118241
$L118240:
	mov	BYTE PTR _regflags+1, 1
$L118241:
	cmp	esi, eax
	jg	SHORT $L118246
	cmp	ebp, esi
	jl	SHORT $L118242
	cmp	ebp, eax
	jg	SHORT $L118242
	xor	al, al
	jmp	SHORT $L118277
$L118246:
	cmp	ebp, eax
	jg	SHORT $L118242
	cmp	ebp, esi
	jl	SHORT $L118242
	xor	al, al
	jmp	SHORT $L118277
$L118242:
	mov	al, 1
$L118277:
	and	edi, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	di, di
	pop	edi
	pop	esi
	pop	ebp
	pop	ebx
	je	SHORT $L118275
	test	al, al
	je	SHORT $L118275
	mov	edx, DWORD PTR _oldpc$85199[esp+4]
	push	edx
	push	6
	call	_Exception@8
$L118275:
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2fb_0@4 ENDP


_src$85221 = -5
_dst$85226 = -6
_flgn$85234 = -4
@op_410_0@4 PROC NEAR
	_start_func  'op_410_0'
	shr	ecx, 8
	mov	dl, BYTE PTR [eax+3]
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	ecx, dl
	mov	bl, BYTE PTR [edi+esi]
	mov	BYTE PTR _src$85221[esp+20], dl
	movsx	eax, bl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	mov	BYTE PTR _dst$85226[esp+20], bl
	setl	cl
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$85234[esp+20], ebx
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$85234[esp+20]
	setl	dl
	xor	dl, cl
	xor	bl, cl
	mov	cl, BYTE PTR _dst$85226[esp+20]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$85221[esp+20]
	cmp	dl, cl
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85234[esp+20]
	test	ecx, ecx
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_410_0@4 ENDP


_src$85243 = -5
_dst$85248 = -6
_flgn$85256 = -4
@op_418_0@4 PROC NEAR
	_start_func  'op_418_0'
	shr	ecx, 8
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	dl, BYTE PTR [eax+3]
	push	edi
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	edi, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	BYTE PTR _src$85243[esp+24], dl
	mov	bl, BYTE PTR [esi+ebp]
	add	ecx, esi
	mov	DWORD PTR [edi], ecx
	mov	BYTE PTR _dst$85248[esp+24], bl
	movsx	eax, bl
	movsx	ecx, dl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	setl	cl
	xor	ebx, ebx
	pop	edi
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$85256[esp+20], ebx
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$85256[esp+20]
	setl	dl
	xor	dl, cl
	xor	bl, cl
	mov	cl, BYTE PTR _dst$85248[esp+20]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$85243[esp+20]
	cmp	dl, cl
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85256[esp+20]
	test	ecx, ecx
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_418_0@4 ENDP


_src$85265 = -5
_dst$85270 = -6
_flgn$85278 = -4
@op_420_0@4 PROC NEAR
	_start_func  'op_420_0'
	shr	ecx, 8
	mov	dl, BYTE PTR [eax+3]
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _areg_byteinc[ecx*4]
	lea	eax, DWORD PTR _regs[ecx*4+32]
	sub	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _src$85265[esp+20], dl
	movsx	ecx, dl
	mov	bl, BYTE PTR [edi+esi]
	mov	DWORD PTR [eax], esi
	movsx	eax, bl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	mov	BYTE PTR _dst$85270[esp+20], bl
	setl	cl
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$85278[esp+20], ebx
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$85278[esp+20]
	setl	dl
	xor	dl, cl
	xor	bl, cl
	mov	cl, BYTE PTR _dst$85270[esp+20]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$85265[esp+20]
	cmp	dl, cl
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85278[esp+20]
	test	ecx, ecx
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_420_0@4 ENDP


_src$85287 = -5
_dst$85295 = -6
_flgn$85303 = -4
@op_428_0@4 PROC NEAR
	_start_func  'op_428_0'
	xor	ebx, ebx
	mov	dl, BYTE PTR [eax+3]
	mov	ax, WORD PTR [eax+4]
	mov	bl, ah
	movsx	esi, bx
	xor	ebx, ebx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	bh, al
	mov	BYTE PTR _src$85287[esp+20], dl
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	add	esi, DWORD PTR _regs[ecx*4+32]
	movsx	ecx, dl
	mov	bl, BYTE PTR [edi+esi]
	movsx	eax, bl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	mov	BYTE PTR _dst$85295[esp+20], bl
	setl	cl
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$85303[esp+20], ebx
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$85303[esp+20]
	setl	dl
	xor	dl, cl
	xor	bl, cl
	mov	cl, BYTE PTR _dst$85295[esp+20]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$85287[esp+20]
	cmp	dl, cl
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85303[esp+20]
	test	ecx, ecx
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_428_0@4 ENDP


_src$85312 = -5
_dst$85317 = -6
_flgn$85325 = -4
@op_430_0@4 PROC NEAR
	_start_func  'op_430_0'
	shr	ecx, 8
	mov	bl, BYTE PTR [eax+3]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	mov	BYTE PTR _src$85312[esp+20], bl
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	movsx	ecx, bl
	mov	dl, BYTE PTR [edi+esi]
	movsx	eax, dl
	sub	eax, ecx
	xor	ecx, ecx
	test	dl, dl
	mov	BYTE PTR _dst$85317[esp+20], dl
	setl	cl
	xor	edx, edx
	test	al, al
	setl	dl
	test	al, al
	mov	DWORD PTR _flgn$85325[esp+20], edx
	sete	dl
	test	bl, bl
	mov	bl, BYTE PTR _flgn$85325[esp+20]
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	xor	bl, cl
	mov	cl, BYTE PTR _dst$85317[esp+20]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$85312[esp+20]
	cmp	dl, cl
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85325[esp+20]
	test	ecx, ecx
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_430_0@4 ENDP


_src$85333 = -5
_dst$85341 = -6
_flgn$85349 = -4
@op_438_0@4 PROC NEAR
	_start_func  'op_438_0'
	xor	ecx, ecx
	mov	dl, BYTE PTR [eax+3]
	mov	ax, WORD PTR [eax+4]
	mov	cl, ah
	movsx	esi, cx
	xor	ecx, ecx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ch, al
	mov	BYTE PTR _src$85333[esp+20], dl
	movsx	eax, cx
	or	esi, eax
	movsx	ecx, dl
	mov	bl, BYTE PTR [edi+esi]
	movsx	eax, bl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	mov	BYTE PTR _dst$85341[esp+20], bl
	setl	cl
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$85349[esp+20], ebx
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$85349[esp+20]
	setl	dl
	xor	dl, cl
	xor	bl, cl
	mov	cl, BYTE PTR _dst$85341[esp+20]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$85333[esp+20]
	cmp	dl, cl
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85349[esp+20]
	test	ecx, ecx
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_438_0@4 ENDP


_src$85357 = -2
_dst$85363 = -1
_flgn$85371 = -8
@op_439_0@4 PROC NEAR
	_start_func  'op_439_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	push	esi
	push	edi
	mov	dl, BYTE PTR [eax+3]
	mov	esi, DWORD PTR [eax+4]
	bswap	esi
	mov	BYTE PTR _src$85357[ebp], dl
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	ecx, dl
	mov	bl, BYTE PTR [edi+esi]
	movsx	eax, bl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	mov	BYTE PTR _dst$85363[ebp], bl
	setl	cl
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	mov	DWORD PTR _flgn$85371[ebp], ebx
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _flgn$85371[ebp]
	setl	dl
	xor	dl, cl
	xor	bl, cl
	mov	cl, BYTE PTR _dst$85363[ebp]
	and	dl, bl
	mov	BYTE PTR _regflags+3, dl
	mov	dl, BYTE PTR _src$85357[ebp]
	cmp	dl, cl
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85371[ebp]
	test	ecx, ecx
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_439_0@4 ENDP


_flgn$85391 = -4
@op_458_0@4 PROC NEAR
	_start_func  'op_458_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	edi, DWORD PTR _regs[ecx*4+32]
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	esi, edx
	xor	edx, edx
	mov	ax, WORD PTR [eax+edi]
	mov	dl, ah
	mov	dh, al
	lea	eax, DWORD PTR [edi+2]
	mov	ebp, edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	movsx	eax, bp
	movsx	ecx, si
	sub	eax, ecx
	xor	ecx, ecx
	test	bp, bp
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	si, si
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$85391[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	si, bp
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85391[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+edi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_458_0@4 ENDP


_flgn$85411 = -4
@op_460_0@4 PROC NEAR
	_start_func  'op_460_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	xor	edx, edx
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	dl, ah
	sub	esi, 2
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	edi, edx
	mov	ax, WORD PTR [eax+esi]
	xor	edx, edx
	mov	dl, ah
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	dh, al
	mov	ebp, edx
	movsx	eax, bp
	movsx	ecx, di
	sub	eax, ecx
	xor	ecx, ecx
	test	bp, bp
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	di, di
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$85411[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	di, bp
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85411[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_460_0@4 ENDP


_flgn$85431 = -4
@op_470_0@4 PROC NEAR
	_start_func  'op_470_0'
	mov	esi, eax
	xor	edx, edx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	DWORD PTR _regs+92, esi
	mov	dh, al
	add	esi, 2
	mov	edi, edx
	mov	dx, WORD PTR [esi-2]
	shr	ecx, 8
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ebp, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+ebp]
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	movsx	eax, si
	movsx	ecx, di
	sub	eax, ecx
	xor	ecx, ecx
	test	si, si
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	di, di
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$85431[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	di, si
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85431[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+ebp], cx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_470_0@4 ENDP


_flgn$85453 = -4
@op_478_0@4 PROC NEAR
	_start_func  'op_478_0'
	mov	ecx, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR [ecx+4]
	mov	edi, edx
	xor	ecx, ecx
	xor	edx, edx
	mov	cl, ah
	mov	dh, al
	movsx	esi, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	movsx	eax, dx
	or	esi, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+esi]
	mov	dl, ah
	mov	dh, al
	mov	ebp, edx
	movsx	eax, bp
	movsx	ecx, di
	sub	eax, ecx
	xor	ecx, ecx
	test	bp, bp
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	di, di
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$85453[esp+20], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	di, bp
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85453[esp+20]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	dl
	xor	ecx, ecx
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_478_0@4 ENDP


_flgn$85473 = -4
_x$118467 = -8
@op_479_0@4 PROC NEAR
	_start_func  'op_479_0'
	mov	ebp, esp
	sub	esp, 8
	mov	ecx, eax
	xor	edx, edx
	push	ebx
	push	esi
	mov	ax, WORD PTR [ecx+2]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	mov	dl, ah
	push	edi
	mov	dh, al
	mov	DWORD PTR _x$118467[ebp], ecx
	mov	esi, edx
	mov	eax, DWORD PTR _MEMBaseDiff
	movsx	edx, si
	mov	ax, WORD PTR [eax+ecx]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	edi, ecx
	xor	ecx, ecx
	movsx	eax, di
	sub	eax, edx
	test	di, di
	setl	cl
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	bl
	test	si, si
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$85473[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	and	bl, dl
	cmp	si, di
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _flgn$85473[ebp]
	mov	BYTE PTR _regflags+3, bl
	test	ecx, ecx
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _x$118467[ebp]
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	pop	edi
	pop	esi
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_479_0@4 ENDP


_dsta$85484 = -8
_flgn$85493 = -4
@op_498_0@4 PROC NEAR
	_start_func  'op_498_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _dsta$85484[ebp], eax
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	esi, eax
	add	edx, 4
	sub	esi, edi
	mov	DWORD PTR _regs[ecx*4+32], edx
	xor	ecx, ecx
	test	eax, eax
	setl	cl
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	edi, edi
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$85493[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$85493[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _dsta$85484[ebp]
	cmp	edi, eax
	seta	al
	test	ecx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	BYTE PTR _regflags+3, bl
	setne	al
	mov	BYTE PTR _regflags, al
	lea	eax, DWORD PTR [ecx+edx]
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_498_0@4 ENDP


_flgn$85513 = -8
_x$118508 = -4
@op_4a0_0@4 PROC NEAR
	_start_func  'op_4a0_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	shr	ecx, 8
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	push	esi
	push	edi
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	sub	esi, 4
	mov	edx, DWORD PTR [edx+esi]
	bswap	edx
	mov	DWORD PTR _x$118508[ebp], edx
	mov	edi, edx
	mov	DWORD PTR _regs[ecx*4+32], esi
	sub	edi, eax
	xor	ecx, ecx
	test	edx, edx
	setl	cl
	xor	edx, edx
	test	edi, edi
	setl	dl
	test	edi, edi
	sete	bl
	test	eax, eax
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$85513[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$85513[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _x$118508[ebp]
	mov	BYTE PTR _regflags+3, bl
	cmp	eax, edx
	seta	al
	test	ecx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	setne	al
	mov	BYTE PTR _regflags, al
	add	esi, ecx
	bswap	edi
	mov	DWORD PTR [esi], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a0_0@4 ENDP


_dsta$85524 = -8
_flgn$85533 = -4
@op_4b0_0@4 PROC NEAR
	_start_func  'op_4b0_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _dsta$85524[ebp], eax
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	mov	esi, ecx
	xor	eax, eax
	sub	esi, edi
	test	ecx, ecx
	setl	al
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	edi, edi
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$85533[ebp], edx
	setl	bl
	xor	bl, al
	xor	dl, al
	and	bl, dl
	cmp	edi, ecx
	mov	ecx, DWORD PTR _dsta$85524[ebp]
	mov	BYTE PTR _regflags+3, bl
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _flgn$85533[ebp]
	test	eax, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	setne	dl
	mov	BYTE PTR _regflags, dl
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	edi
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4b0_0@4 ENDP


_flgn$85555 = -8
_x$118556 = -4
@op_4b8_0@4 PROC NEAR
	_start_func  'op_4b8_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	push	esi
	push	edi
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	mov	cx, WORD PTR [ecx+6]
	mov	dl, ch
	movsx	edi, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	edi, ecx
	mov	edx, DWORD PTR [edx+edi]
	bswap	edx
	mov	DWORD PTR _x$118556[ebp], edx
	mov	esi, edx
	xor	ecx, ecx
	sub	esi, eax
	test	edx, edx
	setl	cl
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	eax, eax
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$85555[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$85555[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _x$118556[ebp]
	mov	BYTE PTR _regflags+3, bl
	cmp	eax, edx
	seta	al
	test	ecx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	setne	al
	mov	BYTE PTR _regflags, al
	add	edi, ecx
	bswap	esi
	mov	DWORD PTR [edi], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4b8_0@4 ENDP


_flgn$85575 = -4
_x$118573 = -8
@op_4b9_0@4 PROC NEAR
	_start_func  'op_4b9_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	ecx, DWORD PTR _regs+92
	mov	eax, DWORD PTR [ecx+6]
	bswap	eax
	mov	DWORD PTR _x$118573[ebp], eax
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	mov	esi, eax
	xor	ecx, ecx
	sub	esi, edi
	test	eax, eax
	setl	cl
	xor	edx, edx
	test	esi, esi
	setl	dl
	test	esi, esi
	sete	bl
	test	edi, edi
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _flgn$85575[ebp], edx
	setl	bl
	xor	bl, cl
	xor	dl, cl
	mov	ecx, DWORD PTR _flgn$85575[ebp]
	and	bl, dl
	mov	edx, DWORD PTR _x$118573[ebp]
	cmp	edi, eax
	seta	al
	test	ecx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	BYTE PTR _regflags+3, bl
	setne	al
	mov	BYTE PTR _regflags, al
	lea	eax, DWORD PTR [ecx+edx]
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 10					; 0000000aH
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4b9_0@4 ENDP


@op_4d0_0@4 PROC NEAR
	_start_func  'op_4d0_0'
	mov	ebx, DWORD PTR _regs+96
	mov	esi, DWORD PTR _regs+88
	xor	edx, edx
	sub	esi, ebx
	add	esi, eax
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	mov	edi, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	mov	eax, edi
	and	ecx, 7
	sar	eax, 12					; 0000000cH
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 15					; 0000000fH
	mov	eax, DWORD PTR _regs[eax*4]
	mov	edx, DWORD PTR [edx+ecx]
	bswap	edx
	mov	ebx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ebx+ecx+4]
	bswap	ecx
	cmp	ecx, eax
	je	SHORT $L118588
	cmp	edx, eax
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118589
$L118588:
	mov	BYTE PTR _regflags+1, 1
$L118589:
	cmp	edx, ecx
	jg	SHORT $L118594
	cmp	eax, edx
	jl	SHORT $L118590
	cmp	eax, ecx
	jg	SHORT $L118590
	xor	al, al
	jmp	SHORT $L118616
$L118594:
	cmp	eax, ecx
	jg	SHORT $L118590
	cmp	eax, edx
	jl	SHORT $L118590
	xor	al, al
	jmp	SHORT $L118616
$L118590:
	mov	al, 1
$L118616:
	and	edi, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	di, di
	je	SHORT $L85591
	test	al, al
	je	SHORT $L85591
	push	esi
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L85591:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4d0_0@4 ENDP


@op_4e8_0@4 PROC NEAR
	_start_func  'op_4e8_0'
	mov	eax, DWORD PTR _regs+96
	mov	edi, DWORD PTR _regs+88
	mov	esi, ecx
	sub	edi, eax
	mov	eax, DWORD PTR _regs+92
	xor	ebx, ebx
	add	edi, eax
	mov	cx, WORD PTR [eax+2]
	xor	edx, edx
	mov	bl, ch
	mov	bh, cl
	mov	cx, WORD PTR [eax+4]
	xor	eax, eax
	mov	dh, cl
	mov	al, ch
	movsx	eax, ax
	movsx	ecx, dx
	shr	esi, 8
	mov	edx, ebx
	and	esi, 7
	sar	edx, 12					; 0000000cH
	or	eax, ecx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	and	edx, 15					; 0000000fH
	add	eax, ecx
	mov	ecx, DWORD PTR _regs[edx*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [esi+eax+4]
	bswap	eax
	cmp	eax, ecx
	je	SHORT $L118621
	cmp	edx, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118622
$L118621:
	mov	BYTE PTR _regflags+1, 1
$L118622:
	cmp	edx, eax
	jg	SHORT $L118627
	cmp	ecx, edx
	jl	SHORT $L118623
	cmp	ecx, eax
	jg	SHORT $L118623
	xor	al, al
	jmp	SHORT $L118653
$L118627:
	cmp	ecx, eax
	jg	SHORT $L118623
	cmp	ecx, edx
	jl	SHORT $L118623
	xor	al, al
	jmp	SHORT $L118653
$L118623:
	mov	al, 1
$L118653:
	and	ebx, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	bx, bx
	je	SHORT $L85608
	test	al, al
	je	SHORT $L85608
	push	edi
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L85608:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4e8_0@4 ENDP


@op_4f0_0@4 PROC NEAR
	_start_func  'op_4f0_0'
	mov	esi, eax
	mov	eax, DWORD PTR _regs+96
	mov	edi, DWORD PTR _regs+88
	sub	edi, eax
	mov	ax, WORD PTR [esi+2]
	add	edi, esi
	xor	ebx, ebx
	add	esi, 4
	mov	bl, ah
	mov	DWORD PTR _regs+92, esi
	mov	bh, al
	mov	dx, WORD PTR [esi]
	add	esi, 2
	shr	ecx, 8
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, ebx
	sar	ecx, 12					; 0000000cH
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	and	ecx, 15					; 0000000fH
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [esi+eax+4]
	bswap	eax
	cmp	eax, ecx
	je	SHORT $L118658
	cmp	edx, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118659
$L118658:
	mov	BYTE PTR _regflags+1, 1
$L118659:
	cmp	edx, eax
	jg	SHORT $L118664
	cmp	ecx, edx
	jl	SHORT $L118660
	cmp	ecx, eax
	jg	SHORT $L118660
	xor	al, al
	jmp	SHORT $L118696
$L118664:
	cmp	ecx, eax
	jg	SHORT $L118660
	cmp	ecx, edx
	jl	SHORT $L118660
	xor	al, al
	jmp	SHORT $L118696
$L118660:
	mov	al, 1
$L118696:
	and	ebx, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	bx, bx
	je	SHORT $L118694
	test	al, al
	je	SHORT $L118694
	push	edi
	push	6
	call	_Exception@8
$L118694:
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4f0_0@4 ENDP


@op_4f8_0@4 PROC NEAR
	_start_func  'op_4f8_0'
	xor	edx, edx
	mov	ebx, DWORD PTR _regs+96
	mov	cx, WORD PTR [eax+2]
	mov	esi, DWORD PTR _regs+88
	mov	dl, ch
	mov	dh, cl
	mov	cx, WORD PTR [eax+4]
	sub	esi, ebx
	mov	edi, edx
	add	esi, eax
	xor	edx, edx
	xor	eax, eax
	mov	dh, cl
	mov	al, ch
	movsx	ecx, dx
	mov	edx, edi
	movsx	eax, ax
	sar	edx, 12					; 0000000cH
	and	edx, 15					; 0000000fH
	or	eax, ecx
	mov	ecx, DWORD PTR _regs[edx*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	mov	ebx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ebx+eax+4]
	bswap	eax
	cmp	eax, ecx
	je	SHORT $L118700
	cmp	edx, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118701
$L118700:
	mov	BYTE PTR _regflags+1, 1
$L118701:
	cmp	edx, eax
	jg	SHORT $L118706
	cmp	ecx, edx
	jl	SHORT $L118702
	cmp	ecx, eax
	jg	SHORT $L118702
	xor	al, al
	jmp	SHORT $L118732
$L118706:
	cmp	ecx, eax
	jg	SHORT $L118702
	cmp	ecx, edx
	jl	SHORT $L118702
	xor	al, al
	jmp	SHORT $L118732
$L118702:
	mov	al, 1
$L118732:
	and	edi, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	di, di
	je	SHORT $L85638
	test	al, al
	je	SHORT $L85638
	push	esi
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L85638:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4f8_0@4 ENDP


@op_4f9_0@4 PROC NEAR
	_start_func  'op_4f9_0'
	mov	esi, eax
	mov	edx, DWORD PTR _regs+96
	mov	eax, DWORD PTR _regs+88
	sub	eax, edx
	xor	edx, edx
	mov	cx, WORD PTR [esi+2]
	add	eax, esi
	mov	esi, DWORD PTR [esi+4]
	bswap	esi
	mov	dl, ch
	mov	dh, cl
	mov	edi, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, edi
	sar	ecx, 12					; 0000000cH
	mov	edx, DWORD PTR [edx+esi]
	bswap	edx
	and	ecx, 15					; 0000000fH
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	ebx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [ebx+esi+4]
	bswap	esi
	cmp	esi, ecx
	je	SHORT $L118737
	cmp	edx, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118738
$L118737:
	mov	BYTE PTR _regflags+1, 1
$L118738:
	cmp	edx, esi
	jg	SHORT $L118743
	cmp	ecx, edx
	jl	SHORT $L118739
	cmp	ecx, esi
	jg	SHORT $L118739
	xor	cl, cl
	jmp	SHORT $L118770
$L118743:
	cmp	ecx, esi
	jg	SHORT $L118739
	cmp	ecx, edx
	jl	SHORT $L118739
	xor	cl, cl
	jmp	SHORT $L118770
$L118739:
	mov	cl, 1
$L118770:
	and	edi, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, cl
	test	di, di
	je	SHORT $L85652
	test	cl, cl
	je	SHORT $L85652
	push	eax
	push	6
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L85652:
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4f9_0@4 ENDP


_extra$85660 = -4
@op_4fa_0@4 PROC NEAR
	_start_func  'op_4fa_0'
	mov	ebp, esp
	push	ecx
	mov	edx, DWORD PTR _regs+96
	push	ebx
	push	esi
	mov	cx, WORD PTR [eax+2]
	push	edi
	mov	edi, DWORD PTR _regs+88
	xor	ebx, ebx
	mov	esi, edi
	sub	esi, edx
	xor	edx, edx
	mov	dl, ch
	add	esi, eax
	mov	dh, cl
	mov	cx, WORD PTR [eax+4]
	mov	DWORD PTR _extra$85660[ebp], edx
	xor	edx, edx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, ecx
	sub	edx, ebx
	add	edx, edi
	mov	edi, DWORD PTR _extra$85660[ebp]
	lea	eax, DWORD PTR [edx+eax+4]
	mov	edx, edi
	sar	edx, 12					; 0000000cH
	and	edx, 15					; 0000000fH
	mov	ecx, DWORD PTR _regs[edx*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	mov	ebx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ebx+eax+4]
	bswap	eax
	cmp	eax, ecx
	je	SHORT $L118775
	cmp	edx, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118776
$L118775:
	mov	BYTE PTR _regflags+1, 1
$L118776:
	cmp	edx, eax
	jg	SHORT $L118781
	cmp	ecx, edx
	jl	SHORT $L118777
	cmp	ecx, eax
	jg	SHORT $L118777
	xor	al, al
	jmp	SHORT $L118810
$L118781:
	cmp	ecx, eax
	jg	SHORT $L118777
	cmp	ecx, edx
	jl	SHORT $L118777
	xor	al, al
	jmp	SHORT $L118810
$L118777:
	mov	al, 1
$L118810:
	and	edi, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	di, di
	je	SHORT $L85669
	test	al, al
	je	SHORT $L85669
	push	esi
	push	6
	call	_Exception@8
	pop	edi
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L85669:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4fa_0@4 ENDP


@op_4fb_0@4 PROC NEAR
	_start_func  'op_4fb_0'
	mov	edx, DWORD PTR _regs+96
	mov	esi, DWORD PTR _regs+88
	mov	cx, WORD PTR [eax+2]
	sub	esi, edx
	xor	edx, edx
	mov	dl, ch
	lea	ebx, DWORD PTR [esi+eax]
	mov	dh, cl
	add	eax, 4
	mov	edi, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	lea	ecx, DWORD PTR [esi+eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, edi
	sar	ecx, 12					; 0000000cH
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	and	ecx, 15					; 0000000fH
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [esi+eax+4]
	bswap	eax
	cmp	eax, ecx
	je	SHORT $L118814
	cmp	edx, ecx
	mov	BYTE PTR _regflags+1, 0
	jne	SHORT $L118815
$L118814:
	mov	BYTE PTR _regflags+1, 1
$L118815:
	cmp	edx, eax
	jg	SHORT $L118820
	cmp	ecx, edx
	jl	SHORT $L118816
	cmp	ecx, eax
	jg	SHORT $L118816
	xor	al, al
	jmp	SHORT $L118854
$L118820:
	cmp	ecx, eax
	jg	SHORT $L118816
	cmp	ecx, edx
	jl	SHORT $L118816
	xor	al, al
	jmp	SHORT $L118854
$L118816:
	mov	al, 1
$L118854:
	and	edi, 2048				; 00000800H
	mov	BYTE PTR _regflags+2, al
	test	di, di
	je	SHORT $L118852
	test	al, al
	je	SHORT $L118852
	push	ebx
	push	6
	call	_Exception@8
$L118852:
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4fb_0@4 ENDP


_src$85691 = -5
_newv$85697 = -4
@op_610_0@4 PROC NEAR
	_start_func  'op_610_0'
	shr	ecx, 8
	mov	bl, BYTE PTR [eax+3]
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	edx, bl
	mov	al, BYTE PTR [edi+esi]
	mov	BYTE PTR _src$85691[esp+20], bl
	movsx	ecx, al
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$85697[esp+20], ecx
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$85691[esp+20]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$85697[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_610_0@4 ENDP


_src$85713 = -5
_newv$85719 = -4
@op_618_0@4 PROC NEAR
	_start_func  'op_618_0'
	shr	ecx, 8
	and	ecx, 7
	mov	bl, BYTE PTR [eax+3]
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	al, BYTE PTR [edi+esi]
	add	ecx, esi
	mov	DWORD PTR [edx], ecx
	mov	BYTE PTR _src$85713[esp+20], bl
	movsx	ecx, al
	movsx	edx, bl
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$85719[esp+20], ecx
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$85713[esp+20]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$85719[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_618_0@4 ENDP


_src$85735 = -5
_newv$85741 = -4
@op_620_0@4 PROC NEAR
	_start_func  'op_620_0'
	shr	ecx, 8
	mov	bl, BYTE PTR [eax+3]
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR _areg_byteinc[ecx*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	lea	edx, DWORD PTR _regs[ecx*4+32]
	sub	esi, eax
	mov	BYTE PTR _src$85735[esp+20], bl
	mov	al, BYTE PTR [edi+esi]
	mov	DWORD PTR [edx], esi
	movsx	ecx, al
	movsx	edx, bl
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$85741[esp+20], ecx
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$85735[esp+20]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$85741[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_620_0@4 ENDP


_src$85757 = -5
_newv$85766 = -4
@op_628_0@4 PROC NEAR
	_start_func  'op_628_0'
	xor	edx, edx
	mov	bl, BYTE PTR [eax+3]
	mov	ax, WORD PTR [eax+4]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dh, al
	mov	BYTE PTR _src$85757[esp+20], bl
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	movsx	edx, bl
	add	esi, DWORD PTR _regs[ecx*4+32]
	mov	al, BYTE PTR [edi+esi]
	movsx	ecx, al
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$85766[esp+20], ecx
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$85757[esp+20]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$85766[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_628_0@4 ENDP


_src$85782 = -5
_newv$85788 = -4
@op_630_0@4 PROC NEAR
	_start_func  'op_630_0'
	shr	ecx, 8
	mov	bl, BYTE PTR [eax+3]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	mov	BYTE PTR _src$85782[esp+20], bl
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	movsx	edx, bl
	mov	al, BYTE PTR [edi+esi]
	movsx	ecx, al
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$85788[esp+20], ecx
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, BYTE PTR _src$85782[esp+20]
	not	al
	cmp	al, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$85788[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_630_0@4 ENDP


_src$85803 = -5
_newv$85812 = -4
@op_638_0@4 PROC NEAR
	_start_func  'op_638_0'
	xor	ecx, ecx
	xor	edx, edx
	mov	bl, BYTE PTR [eax+3]
	mov	ax, WORD PTR [eax+4]
	mov	cl, ah
	mov	dh, al
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _src$85803[esp+20], bl
	movsx	esi, cx
	movsx	eax, dx
	or	esi, eax
	movsx	edx, bl
	mov	al, BYTE PTR [edi+esi]
	movsx	ecx, al
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$85812[esp+20], ecx
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$85803[esp+20]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$85812[esp+20]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_638_0@4 ENDP


_src$85827 = -1
_newv$85834 = -8
@op_639_0@4 PROC NEAR
	_start_func  'op_639_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	push	esi
	push	edi
	mov	bl, BYTE PTR [eax+3]
	mov	esi, DWORD PTR [eax+4]
	bswap	esi
	mov	BYTE PTR _src$85827[ebp], bl
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	edx, bl
	mov	al, BYTE PTR [edi+esi]
	movsx	ecx, al
	add	ecx, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	test	cl, cl
	mov	DWORD PTR _newv$85834[ebp], ecx
	sete	cl
	test	al, al
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, dl
	test	bl, bl
	setl	bl
	xor	bl, dl
	and	cl, bl
	mov	bl, BYTE PTR _src$85827[ebp]
	not	al
	cmp	al, bl
	mov	BYTE PTR _regflags+3, cl
	setb	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	al, BYTE PTR _newv$85834[ebp]
	setne	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_639_0@4 ENDP


@op_658_0@4 PROC NEAR
	_start_func  'op_658_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [eax+ebp]
	mov	edi, edx
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	lea	eax, DWORD PTR [ebp+2]
	mov	esi, edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	movsx	eax, si
	movsx	ecx, di
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	di, di
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, di
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_658_0@4 ENDP


@op_660_0@4 PROC NEAR
	_start_func  'op_660_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	xor	edx, edx
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	dl, ah
	sub	esi, 2
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	ebp, edx
	xor	edx, edx
	mov	ax, WORD PTR [eax+esi]
	mov	dl, ah
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	dh, al
	mov	edi, edx
	movsx	eax, di
	movsx	ecx, bp
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	bp, bp
	setl	bl
	xor	bl, cl
	not	edi
	and	dl, bl
	cmp	di, bp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_660_0@4 ENDP


@op_670_0@4 PROC NEAR
	_start_func  'op_670_0'
	mov	esi, eax
	xor	edx, edx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	DWORD PTR _regs+92, esi
	mov	dh, al
	add	esi, 2
	mov	edi, edx
	mov	dx, WORD PTR [esi-2]
	shr	ecx, 8
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ebp, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+ebp]
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	movsx	eax, si
	movsx	ecx, di
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	di, di
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, di
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_670_0@4 ENDP


@op_678_0@4 PROC NEAR
	_start_func  'op_678_0'
	mov	ecx, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR [ecx+4]
	mov	ebp, edx
	xor	ecx, ecx
	xor	edx, edx
	mov	cl, ah
	mov	dh, al
	movsx	edi, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	movsx	eax, dx
	or	edi, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+edi]
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	movsx	eax, si
	movsx	ecx, bp
	add	eax, ecx
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	bp, bp
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, bp
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_678_0@4 ENDP


_x$119044 = -4
@op_679_0@4 PROC NEAR
	_start_func  'op_679_0'
	mov	ebp, esp
	push	ecx
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	push	ebx
	push	esi
	mov	ax, WORD PTR [ecx+2]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	mov	dl, ah
	push	edi
	mov	dh, al
	mov	DWORD PTR _x$119044[ebp], ecx
	mov	edi, edx
	mov	eax, DWORD PTR _MEMBaseDiff
	movsx	edx, di
	mov	ax, WORD PTR [eax+ecx]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	esi, ecx
	xor	ecx, ecx
	movsx	eax, si
	add	eax, edx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	si, si
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, cl
	test	di, di
	setl	bl
	xor	bl, cl
	not	esi
	and	dl, bl
	cmp	si, di
	mov	BYTE PTR _regflags+3, dl
	pop	edi
	setb	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _x$119044[ebp]
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	pop	esi
	pop	ebx
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_679_0@4 ENDP


_dsta$85954 = -4
@op_698_0@4 PROC NEAR
	_start_func  'op_698_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _dsta$85954[ebp], eax
	mov	esi, DWORD PTR [edx+eax]
	bswap	esi
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	xor	eax, eax
	add	ebx, 4
	mov	DWORD PTR _regs[ecx*4+32], ebx
	lea	ecx, DWORD PTR [esi+edi]
	test	ecx, ecx
	setl	al
	test	ecx, ecx
	sete	dl
	test	esi, esi
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, al
	test	edi, edi
	setl	bl
	xor	bl, al
	not	esi
	and	dl, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _dsta$85954[ebp]
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_698_0@4 ENDP


_newv$85976 = -4
@op_6a0_0@4 PROC NEAR
	_start_func  'op_6a0_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	shr	ecx, 8
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	push	esi
	push	edi
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	esi, 4
	mov	edi, DWORD PTR [eax+esi]
	bswap	edi
	mov	DWORD PTR _regs[ecx*4+32], esi
	lea	ecx, DWORD PTR [edi+edx]
	xor	eax, eax
	mov	DWORD PTR _newv$85976[ebp], ecx
	test	ecx, ecx
	setl	al
	test	ecx, ecx
	sete	cl
	test	edi, edi
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	xor	cl, al
	test	edx, edx
	setl	bl
	xor	bl, al
	not	edi
	and	cl, bl
	cmp	edi, edx
	mov	BYTE PTR _regflags+3, cl
	setb	cl
	test	eax, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, cl
	setne	dl
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags, dl
	add	esi, eax
	mov	ecx, DWORD PTR _newv$85976[ebp]
	pop	edi
	bswap	ecx
	mov	DWORD PTR [esi], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_6a0_0@4 ENDP


_dsta$85994 = -4
@op_6b0_0@4 PROC NEAR
	_start_func  'op_6b0_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _dsta$85994[ebp], eax
	mov	esi, DWORD PTR [ecx+eax]
	bswap	esi
	lea	edx, DWORD PTR [esi+edi]
	xor	ecx, ecx
	test	edx, edx
	setl	cl
	test	edx, edx
	sete	al
	test	esi, esi
	mov	BYTE PTR _regflags+1, al
	setl	al
	xor	al, cl
	test	edi, edi
	setl	bl
	xor	bl, cl
	not	esi
	and	al, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, al
	setb	al
	test	ecx, ecx
	setne	cl
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _dsta$85994[ebp]
	add	eax, ecx
	pop	edi
	bswap	edx
	mov	DWORD PTR [eax], edx
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_6b0_0@4 ENDP


_newv$86018 = -4
@op_6b8_0@4 PROC NEAR
	_start_func  'op_6b8_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	push	esi
	push	edi
	mov	ecx, DWORD PTR [eax+2]
	bswap	ecx
	mov	edx, DWORD PTR _regs+92
	mov	ax, WORD PTR [edx+6]
	xor	edx, edx
	mov	dl, ah
	movsx	edi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	edi, eax
	mov	esi, DWORD PTR [edx+edi]
	bswap	esi
	lea	edx, DWORD PTR [esi+ecx]
	xor	eax, eax
	test	edx, edx
	setl	al
	test	edx, edx
	mov	DWORD PTR _newv$86018[ebp], edx
	sete	dl
	test	esi, esi
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, al
	test	ecx, ecx
	setl	bl
	xor	bl, al
	not	esi
	and	dl, bl
	cmp	esi, ecx
	setb	cl
	test	eax, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+3, dl
	setne	al
	mov	BYTE PTR _regflags, al
	add	edi, ecx
	mov	edx, DWORD PTR _newv$86018[ebp]
	bswap	edx
	mov	DWORD PTR [edi], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_6b8_0@4 ENDP


_x$119150 = -4
@op_6b9_0@4 PROC NEAR
	_start_func  'op_6b9_0'
	mov	ebp, esp
	push	ecx
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	ecx, DWORD PTR _regs+92
	mov	eax, DWORD PTR [ecx+6]
	bswap	eax
	mov	DWORD PTR _x$119150[ebp], eax
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [edx+eax]
	bswap	esi
	lea	ecx, DWORD PTR [esi+edi]
	xor	eax, eax
	test	ecx, ecx
	setl	al
	test	ecx, ecx
	sete	dl
	test	esi, esi
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	dl, al
	test	edi, edi
	setl	bl
	xor	bl, al
	not	esi
	and	dl, bl
	cmp	esi, edi
	mov	BYTE PTR _regflags+3, dl
	setb	dl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _x$119150[ebp]
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 10					; 0000000aH
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_6b9_0@4 ENDP


illegal2byteop PROC NEAR
	_start_func  'PROC '
	add	DWORD PTR _regs+92, 2
	call	@op_illg@4
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
illegal2byteop ENDP


@op_6c0_0@4 PROC NEAR
	_start_func  'op_6c0_0'
	jmp	illegal2byteop
@op_6c0_0@4 ENDP


@op_6c8_0@4 PROC NEAR
	_start_func  'op_6c8_0'
	jmp	illegal2byteop
@op_6c8_0@4 ENDP


@op_6d0_0@4 PROC NEAR
	_start_func  'op_6d0_0'
	jmp	illegal2byteop
@op_6d0_0@4 ENDP


@op_6e8_0@4 PROC NEAR
	_start_func  'op_6e8_0'
	jmp	illegal2byteop
@op_6e8_0@4 ENDP


@op_6f0_0@4 PROC NEAR
	_start_func  'op_6f0_0'
	jmp	illegal2byteop
@op_6f0_0@4 ENDP


@op_6f8_0@4 PROC NEAR
	_start_func  'op_6f8_0'
	jmp	illegal2byteop
@op_6f8_0@4 ENDP


@op_6f9_0@4 PROC NEAR
	_start_func  'op_6f9_0'
	jmp	illegal2byteop
@op_6f9_0@4 ENDP


@op_6fa_0@4 PROC NEAR
	_start_func  'op_6fa_0'
	jmp	illegal2byteop
@op_6fa_0@4 ENDP


@op_6fb_0@4 PROC NEAR
	_start_func  'op_6fb_0'
	jmp	illegal2byteop
@op_6fb_0@4 ENDP


@op_820_0@4 PROC NEAR
	_start_func  'op_820_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR _areg_byteinc[ecx*4]
	lea	esi, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	edx, eax
	mov	al, BYTE PTR [ecx+edx]
	xor	ecx, ecx
	mov	cl, bh
	mov	DWORD PTR [esi], edx
	and	cl, 7
	sar	al, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_820_0@4 ENDP


@op_838_0@4 PROC NEAR
	_start_func  'op_838_0'
	xor	ebx, ebx
	mov	cx, WORD PTR [eax+4]
	mov	dx, WORD PTR [eax+2]
	mov	bl, ch
	add	eax, 6
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, cl
	movsx	ecx, bx
	or	esi, ecx
	xor	ecx, ecx
	mov	cl, dh
	mov	edx, DWORD PTR _MEMBaseDiff
	and	cl, 7
	mov	dl, BYTE PTR [esi+edx]
	mov	DWORD PTR _regs+92, eax
	shr	dl, cl
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_838_0@4 ENDP


@op_839_0@4 PROC NEAR
	_start_func  'op_839_0'
	mov	cx, WORD PTR [eax+2]
	mov	eax, DWORD PTR [eax+4]
	bswap	eax
	xor	edx, edx
	mov	dl, ch
	mov	ecx, DWORD PTR _MEMBaseDiff
	and	dl, 7
	mov	al, BYTE PTR [ecx+eax]
	mov	cl, dl
	shr	al, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_839_0@4 ENDP


@op_83a_0@4 PROC NEAR
	_start_func  'op_83a_0'
	xor	ebx, ebx
	mov	cx, WORD PTR [eax+4]
	mov	dx, WORD PTR [eax+2]
	mov	bl, ch
	add	eax, 6
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, cl
	movsx	ecx, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	esi, ecx
	mov	ecx, DWORD PTR _regs+96
	sub	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	esi, ebx
	add	esi, ecx
	xor	ecx, ecx
	mov	cl, dh
	mov	dl, BYTE PTR [esi+eax-2]
	and	cl, 7
	shr	dl, cl
	mov	DWORD PTR _regs+92, eax
	not	dl
	and	dl, 1
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_83a_0@4 ENDP


@op_83b_0@4 PROC NEAR
	_start_func  'op_83b_0'
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	mov	bx, WORD PTR [eax+2]
	add	eax, 4
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, bh
	mov	al, BYTE PTR [edx+eax]
	and	cl, 7
	shr	al, cl
	not	al
	and	al, 1
	mov	BYTE PTR _regflags+1, al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_83b_0@4 ENDP


@op_83c_0@4 PROC NEAR
	_start_func  'op_83c_0'
	xor	edx, edx
	mov	cx, WORD PTR [eax+2]
	mov	bl, BYTE PTR [eax+5]
	mov	dl, ch
	add	eax, 6
	and	dl, 7
	mov	DWORD PTR _regs+92, eax
	mov	cl, dl
	sar	bl, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_83c_0@4 ENDP


@op_858_0@4 PROC NEAR
	_start_func  'op_858_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	lea	esi, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	dl, BYTE PTR [edi+eax]
	add	ecx, eax
	mov	DWORD PTR [esi], ecx
	xor	ecx, ecx
	mov	cl, bh
	mov	bl, 1
	and	ecx, 7
	movsx	esi, cx
	mov	ecx, esi
	shl	bl, cl
	xor	dl, bl
	mov	ebx, 1
	shl	ebx, cl
	movsx	ecx, dl
	and	ebx, ecx
	mov	ecx, esi
	sar	ebx, cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_858_0@4 ENDP


@op_860_0@4 PROC NEAR
	_start_func  'op_860_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _areg_byteinc[ecx*4]
	lea	esi, DWORD PTR _regs[ecx*4+32]
	sub	eax, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, bh
	mov	bl, 1
	mov	dl, BYTE PTR [edi+eax]
	and	ecx, 7
	mov	DWORD PTR [esi], eax
	movsx	esi, cx
	mov	ecx, esi
	shl	bl, cl
	xor	dl, bl
	mov	ebx, 1
	shl	ebx, cl
	movsx	ecx, dl
	and	ebx, ecx
	mov	ecx, esi
	sar	ebx, cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_860_0@4 ENDP


@op_868_0@4 PROC NEAR
	_start_func  'op_868_0'
	mov	esi, ecx
	mov	dx, WORD PTR [eax+2]
	mov	cx, WORD PTR [eax+4]
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	xor	ecx, ecx
	shr	esi, 8
	and	esi, 7
	mov	cl, dh
	and	ecx, 7
	mov	edi, DWORD PTR _regs[esi*4+32]
	mov	dl, 1
	movsx	esi, cx
	mov	ecx, esi
	add	eax, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ebx, 1
	shl	dl, cl
	mov	cl, BYTE PTR [edi+eax]
	xor	dl, cl
	mov	ecx, esi
	shl	ebx, cl
	movsx	ecx, dl
	and	ebx, ecx
	mov	ecx, esi
	sar	ebx, cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_868_0@4 ENDP


@op_870_0@4 PROC NEAR
	_start_func  'op_870_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, eax
	xor	eax, eax
	mov	al, bh
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	eax, 7
	mov	dl, 1
	movsx	esi, ax
	mov	al, BYTE PTR [edi+ebp]
	mov	ecx, esi
	shl	dl, cl
	xor	dl, al
	mov	eax, 1
	shl	eax, cl
	movsx	ecx, dl
	and	eax, ecx
	mov	ecx, esi
	sar	eax, cl
	mov	BYTE PTR _regflags+1, al
	mov	BYTE PTR [edi+ebp], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_870_0@4 ENDP


@op_878_0@4 PROC NEAR
	_start_func  'op_878_0'
	xor	edx, edx
	mov	cx, WORD PTR [eax+2]
	mov	ax, WORD PTR [eax+4]
	mov	dl, ah
	mov	ebp, DWORD PTR _MEMBaseDiff
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	or	esi, eax
	xor	eax, eax
	mov	al, ch
	mov	edx, 1
	and	eax, 7
	movsx	edi, ax
	mov	al, 1
	mov	ecx, edi
	shl	al, cl
	mov	cl, BYTE PTR [esi+ebp]
	xor	al, cl
	mov	ecx, edi
	shl	edx, cl
	movsx	ecx, al
	and	edx, ecx
	mov	ecx, edi
	sar	edx, cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR [esi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_878_0@4 ENDP


@op_879_0@4 PROC NEAR
	_start_func  'op_879_0'
	mov	cx, WORD PTR [eax+2]
	mov	edi, DWORD PTR [eax+4]
	bswap	edi
	xor	eax, eax
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	al, ch
	and	eax, 7
	mov	bl, BYTE PTR [edx+edi]
	movsx	esi, ax
	mov	al, 1
	mov	ecx, esi
	shl	al, cl
	xor	al, bl
	mov	ebx, 1
	shl	ebx, cl
	movsx	ecx, al
	and	ebx, ecx
	mov	ecx, esi
	sar	ebx, cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_879_0@4 ENDP


@op_87a_0@4 PROC NEAR
	_start_func  'op_87a_0'
	xor	ebx, ebx
	mov	cx, WORD PTR [eax+4]
	mov	bl, ch
	mov	dx, WORD PTR [eax+2]
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, cl
	mov	edi, DWORD PTR _regs+88
	movsx	ecx, bx
	mov	ebx, DWORD PTR _regs+96
	or	esi, ecx
	sub	esi, ebx
	mov	ebp, DWORD PTR _MEMBaseDiff
	add	esi, edi
	lea	edi, DWORD PTR [esi+eax+4]
	xor	eax, eax
	mov	al, dh
	mov	edx, 1
	and	eax, 7
	movsx	esi, ax
	mov	al, 1
	mov	ecx, esi
	shl	al, cl
	mov	cl, BYTE PTR [edi+ebp]
	xor	al, cl
	mov	ecx, esi
	shl	edx, cl
	movsx	ecx, al
	and	edx, ecx
	mov	ecx, esi
	sar	edx, cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR [edi+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_87a_0@4 ENDP


@op_87b_0@4 PROC NEAR
	_start_func  'op_87b_0'
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	mov	bx, WORD PTR [eax+2]
	add	eax, 4
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, eax
	xor	eax, eax
	mov	al, bh
	mov	ebp, DWORD PTR _MEMBaseDiff
	and	eax, 7
	mov	dl, 1
	movsx	esi, ax
	mov	al, BYTE PTR [edi+ebp]
	mov	ecx, esi
	shl	dl, cl
	xor	dl, al
	mov	eax, 1
	shl	eax, cl
	movsx	ecx, dl
	and	eax, ecx
	mov	ecx, esi
	sar	eax, cl
	mov	BYTE PTR _regflags+1, al
	mov	BYTE PTR [edi+ebp], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_87b_0@4 ENDP


@op_898_0@4 PROC NEAR
	_start_func  'op_898_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	dl, BYTE PTR [edi+esi]
	add	ecx, esi
	mov	DWORD PTR [eax], ecx
	xor	eax, eax
	mov	al, bh
	mov	bl, dl
	and	eax, 7
	mov	cl, al
	sar	bl, cl
	movsx	ecx, ax
	mov	al, 1
	shl	al, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	not	al
	and	al, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_898_0@4 ENDP


_dst$86225 = -1
@op_8a0_0@4 PROC NEAR
	_start_func  'op_8a0_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	sub	eax, esi
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [esi+eax]
	mov	DWORD PTR [edx], eax
	xor	edx, edx
	mov	BYTE PTR _dst$86225[esp+12], cl
	mov	dl, bh
	mov	bl, cl
	and	edx, 7
	mov	cl, dl
	sar	bl, cl
	movsx	ecx, dx
	mov	dl, 1
	shl	dl, cl
	mov	cl, BYTE PTR _dst$86225[esp+12]
	not	bl
	and	bl, 1
	not	dl
	and	dl, cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [esi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8a0_0@4 ENDP


@op_8b8_0@4 PROC NEAR
	_start_func  'op_8b8_0'
	xor	edx, edx
	mov	cx, WORD PTR [eax+2]
	mov	ax, WORD PTR [eax+4]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dh, al
	movsx	eax, dx
	or	esi, eax
	xor	eax, eax
	mov	al, ch
	mov	dl, BYTE PTR [edi+esi]
	and	eax, 7
	mov	bl, dl
	mov	cl, al
	sar	bl, cl
	movsx	ecx, ax
	mov	al, 1
	shl	al, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	not	al
	and	al, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8b8_0@4 ENDP


@op_8b9_0@4 PROC NEAR
	_start_func  'op_8b9_0'
	mov	cx, WORD PTR [eax+2]
	mov	esi, DWORD PTR [eax+4]
	bswap	esi
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	eax, eax
	mov	al, ch
	mov	dl, BYTE PTR [edi+esi]
	and	eax, 7
	mov	bl, dl
	mov	cl, al
	sar	bl, cl
	movsx	ecx, ax
	mov	al, 1
	shl	al, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	not	al
	and	al, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8b9_0@4 ENDP


@op_8ba_0@4 PROC NEAR
	_start_func  'op_8ba_0'
	xor	edx, edx
	mov	cx, WORD PTR [eax+4]
	mov	dl, ch
	mov	edi, DWORD PTR _regs+96
	movsx	esi, dx
	xor	edx, edx
	mov	bx, WORD PTR [eax+2]
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _regs+88
	or	esi, ecx
	sub	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	add	esi, edx
	lea	esi, DWORD PTR [esi+eax+4]
	xor	eax, eax
	mov	al, bh
	mov	dl, BYTE PTR [edi+esi]
	and	eax, 7
	mov	bl, dl
	mov	cl, al
	sar	bl, cl
	movsx	ecx, ax
	mov	al, 1
	shl	al, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	not	al
	and	al, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8ba_0@4 ENDP


@op_8bb_0@4 PROC NEAR
	_start_func  'op_8bb_0'
	mov	ecx, DWORD PTR _regs+88
	mov	bx, WORD PTR [eax+2]
	mov	esi, DWORD PTR _regs+96
	add	eax, 4
	sub	ecx, esi
	mov	DWORD PTR _regs+92, eax
	add	ecx, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	esi, eax
	mov	dl, bh
	and	edx, 7
	mov	al, BYTE PTR [edi+esi]
	mov	cl, dl
	mov	bl, al
	sar	bl, cl
	movsx	ecx, dx
	mov	dl, 1
	shl	dl, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	not	dl
	and	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8bb_0@4 ENDP


@op_8d8_0@4 PROC NEAR
	_start_func  'op_8d8_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	dl, BYTE PTR [edi+esi]
	add	ecx, esi
	mov	DWORD PTR [eax], ecx
	xor	eax, eax
	mov	al, bh
	mov	bl, dl
	and	eax, 7
	mov	cl, al
	sar	bl, cl
	movsx	ecx, ax
	mov	al, 1
	shl	al, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	or	al, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8d8_0@4 ENDP


_dst$86279 = -1
@op_8e0_0@4 PROC NEAR
	_start_func  'op_8e0_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	sub	eax, esi
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [esi+eax]
	mov	DWORD PTR [edx], eax
	xor	edx, edx
	mov	BYTE PTR _dst$86279[esp+12], cl
	mov	dl, bh
	mov	bl, cl
	and	edx, 7
	mov	cl, dl
	sar	bl, cl
	movsx	ecx, dx
	mov	dl, 1
	shl	dl, cl
	mov	cl, BYTE PTR _dst$86279[esp+12]
	not	bl
	and	bl, 1
	or	dl, cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [esi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8e0_0@4 ENDP


@op_8f8_0@4 PROC NEAR
	_start_func  'op_8f8_0'
	xor	edx, edx
	mov	cx, WORD PTR [eax+2]
	mov	ax, WORD PTR [eax+4]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dh, al
	movsx	eax, dx
	or	esi, eax
	xor	eax, eax
	mov	al, ch
	mov	dl, BYTE PTR [edi+esi]
	and	eax, 7
	mov	bl, dl
	mov	cl, al
	sar	bl, cl
	movsx	ecx, ax
	mov	al, 1
	shl	al, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	or	al, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8f8_0@4 ENDP


@op_8f9_0@4 PROC NEAR
	_start_func  'op_8f9_0'
	mov	cx, WORD PTR [eax+2]
	mov	esi, DWORD PTR [eax+4]
	bswap	esi
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	eax, eax
	mov	al, ch
	mov	dl, BYTE PTR [edi+esi]
	and	eax, 7
	mov	bl, dl
	mov	cl, al
	sar	bl, cl
	movsx	ecx, ax
	mov	al, 1
	shl	al, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	or	al, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8f9_0@4 ENDP


@op_8fa_0@4 PROC NEAR
	_start_func  'op_8fa_0'
	xor	edx, edx
	mov	cx, WORD PTR [eax+4]
	mov	dl, ch
	mov	edi, DWORD PTR _regs+96
	movsx	esi, dx
	xor	edx, edx
	mov	bx, WORD PTR [eax+2]
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _regs+88
	or	esi, ecx
	sub	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	add	esi, edx
	lea	esi, DWORD PTR [esi+eax+4]
	xor	eax, eax
	mov	al, bh
	mov	dl, BYTE PTR [edi+esi]
	and	eax, 7
	mov	bl, dl
	mov	cl, al
	sar	bl, cl
	movsx	ecx, ax
	mov	al, 1
	shl	al, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	or	al, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8fa_0@4 ENDP


@op_8fb_0@4 PROC NEAR
	_start_func  'op_8fb_0'
	mov	ecx, DWORD PTR _regs+88
	mov	bx, WORD PTR [eax+2]
	mov	esi, DWORD PTR _regs+96
	add	eax, 4
	sub	ecx, esi
	mov	DWORD PTR _regs+92, eax
	add	ecx, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	esi, eax
	mov	dl, bh
	and	edx, 7
	mov	al, BYTE PTR [edi+esi]
	mov	cl, dl
	mov	bl, al
	sar	bl, cl
	movsx	ecx, dx
	mov	dl, 1
	shl	dl, cl
	not	bl
	and	bl, 1
	mov	BYTE PTR _regflags+1, bl
	or	dl, al
	mov	BYTE PTR [edi+esi], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_8fb_0@4 ENDP


@op_a10_0@4 PROC NEAR
	_start_func  'op_a10_0'
	shr	ecx, 8
	mov	al, BYTE PTR [eax+3]
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	dl, BYTE PTR [esi+ecx]
	xor	al, dl
	mov	dl, 0
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a10_0@4 ENDP


@op_a18_0@4 PROC NEAR
	_start_func  'op_a18_0'
	shr	ecx, 8
	and	ecx, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	esi, ecx
	mov	al, BYTE PTR [eax+3]
	mov	edx, DWORD PTR _regs[esi*4+32]
	lea	edi, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _areg_byteinc[esi*4]
	mov	cl, BYTE PTR [edx+ebp]
	add	esi, edx
	xor	al, cl
	mov	cl, 0
	sete	bl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	DWORD PTR [edi], esi
	setl	cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+ebp], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a18_0@4 ENDP


@op_a20_0@4 PROC NEAR
	_start_func  'op_a20_0'
	shr	ecx, 8
	mov	dl, BYTE PTR [eax+3]
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _areg_byteinc[ecx*4]
	lea	esi, DWORD PTR _regs[ecx*4+32]
	sub	eax, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [edi+eax]
	mov	DWORD PTR [esi], eax
	xor	dl, cl
	mov	cl, 0
	sete	bl
	cmp	dl, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a20_0@4 ENDP


@op_a28_0@4 PROC NEAR
	_start_func  'op_a28_0'
	mov	edi, eax
	mov	esi, ecx
	xor	eax, eax
	mov	cx, WORD PTR [edi+4]
	xor	edx, edx
	mov	al, ch
	mov	dh, cl
	movsx	eax, ax
	movsx	ecx, dx
	shr	esi, 8
	and	esi, 7
	or	eax, ecx
	mov	dl, 0
	mov	ecx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	mov	cl, BYTE PTR [edi+3]
	mov	bl, BYTE PTR [esi+eax]
	mov	BYTE PTR _regflags+2, dl
	xor	cl, bl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a28_0@4 ENDP


@op_a30_0@4 PROC NEAR
	_start_func  'op_a30_0'
	shr	ecx, 8
	mov	bl, BYTE PTR [eax+3]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [esi+eax]
	xor	bl, cl
	mov	cl, 0
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [esi+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a30_0@4 ENDP


@op_a38_0@4 PROC NEAR
	_start_func  'op_a38_0'
	mov	esi, eax
	xor	eax, eax
	xor	edx, edx
	mov	cx, WORD PTR [esi+4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	al, ch
	mov	dh, cl
	movsx	eax, ax
	movsx	ecx, dx
	or	eax, ecx
	mov	cl, BYTE PTR [esi+3]
	mov	dl, 0
	mov	bl, BYTE PTR [edi+eax]
	mov	BYTE PTR _regflags+2, dl
	xor	cl, bl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a38_0@4 ENDP


@op_a39_0@4 PROC NEAR
	_start_func  'op_a39_0'
	mov	ecx, eax
	mov	al, BYTE PTR [ecx+3]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	dl, BYTE PTR [esi+ecx]
	xor	al, dl
	mov	dl, 0
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a39_0@4 ENDP


@op_a3c_0@4 PROC NEAR
	_start_func  'op_a3c_0'
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	xor	WORD PTR _regs+76, cx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a3c_0@4 ENDP


@op_a50_0@4 PROC NEAR
	_start_func  'op_a50_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [eax+2]
	xor	edx, edx
	mov	cx, WORD PTR [edi+esi]
	mov	dl, ch
	mov	dh, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	xor	edx, ecx
	xor	ecx, ecx
	mov	eax, edx
	mov	BYTE PTR _regflags+2, cl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a50_0@4 ENDP


@op_a58_0@4 PROC NEAR
	_start_func  'op_a58_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dx, WORD PTR [edi+esi]
	lea	ebx, DWORD PTR [esi+2]
	mov	DWORD PTR _regs[ecx*4+32], ebx
	xor	ecx, ecx
	mov	cl, dh
	mov	ch, dl
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	xor	ecx, edx
	mov	eax, ecx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a58_0@4 ENDP


@op_a60_0@4 PROC NEAR
	_start_func  'op_a60_0'
	shr	ecx, 8
	and	ecx, 7
	mov	ax, WORD PTR [eax+2]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	sub	esi, 2
	mov	dx, WORD PTR [edi+esi]
	mov	DWORD PTR _regs[ecx*4+32], esi
	xor	ecx, ecx
	mov	cl, dh
	mov	ch, dl
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	xor	ecx, edx
	mov	eax, ecx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a60_0@4 ENDP


@op_a70_0@4 PROC NEAR
	_start_func  'op_a70_0'
	shr	ecx, 8
	mov	bx, WORD PTR [eax+2]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [edi+esi]
	mov	dl, bh
	mov	cl, ah
	mov	dh, bl
	mov	ch, al
	xor	eax, eax
	xor	ecx, edx
	mov	BYTE PTR _regflags+2, al
	cmp	cx, ax
	mov	BYTE PTR _regflags+3, al
	sete	dl
	cmp	cx, ax
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	mov	dh, cl
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a70_0@4 ENDP


@op_a78_0@4 PROC NEAR
	_start_func  'op_a78_0'
	mov	ecx, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ch
	mov	edi, DWORD PTR _MEMBaseDiff
	movsx	esi, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	esi, ecx
	xor	edx, edx
	mov	cx, WORD PTR [edi+esi]
	mov	dl, ch
	mov	dh, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	xor	edx, ecx
	xor	ecx, ecx
	mov	eax, edx
	mov	BYTE PTR _regflags+2, cl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a78_0@4 ENDP


@op_a79_0@4 PROC NEAR
	_start_func  'op_a79_0'
	mov	ecx, eax
	mov	ax, WORD PTR [ecx+2]
	mov	esi, DWORD PTR [ecx+4]
	bswap	esi
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	cx, WORD PTR [edi+esi]
	mov	dl, ch
	mov	dh, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	xor	edx, ecx
	xor	ecx, ecx
	mov	eax, edx
	mov	BYTE PTR _regflags+2, cl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a79_0@4 ENDP


@op_a7c_0@4 PROC NEAR
	_start_func  'op_a7c_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L86516
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L86516:
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	mov	ch, al
	xor	WORD PTR _regs+76, cx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a7c_0@4 ENDP


@op_a90_0@4 PROC NEAR
	_start_func  'op_a90_0'
	push	ebx
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR [eax+ecx]
	bswap	eax
	xor	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a90_0@4 ENDP


@op_a98_0@4 PROC NEAR
	_start_func  'op_a98_0'
	push	ebx
	shr	ecx, 8
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	push	edi
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [eax+edx]
	bswap	eax
	mov	edi, DWORD PTR _regs[ecx*4+32]
	add	edi, 4
	xor	eax, esi
	mov	DWORD PTR _regs[ecx*4+32], edi
	mov	ecx, 0
	sete	bl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_a98_0@4 ENDP


@op_aa0_0@4 PROC NEAR
	_start_func  'op_aa0_0'
	push	ebx
	shr	ecx, 8
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	sub	eax, 4
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	edx, esi
	mov	ecx, 0
	sete	bl
	cmp	edx, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_aa0_0@4 ENDP


@op_aa8_0@4 PROC NEAR
	_start_func  'op_aa8_0'
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	shr	esi, 8
	mov	cx, WORD PTR [ecx+6]
	and	esi, 7
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	eax, ecx
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	ecx, DWORD PTR [edx+eax]
	bswap	ecx
	xor	ecx, edi
	mov	edx, 0
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_aa8_0@4 ENDP


@op_ab0_0@4 PROC NEAR
	_start_func  'op_ab0_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	xor	ecx, esi
	mov	edx, 0
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ab0_0@4 ENDP


@op_ab8_0@4 PROC NEAR
	_start_func  'op_ab8_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	mov	cx, WORD PTR [ecx+6]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	eax, ecx
	mov	ecx, DWORD PTR [edx+eax]
	bswap	ecx
	xor	ecx, esi
	mov	edx, 0
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ab8_0@4 ENDP


@op_ab9_0@4 PROC NEAR
	_start_func  'op_ab9_0'
	push	ebx
	mov	edx, DWORD PTR [eax+2]
	bswap	edx
	mov	ecx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [ecx+6]
	bswap	ecx
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [eax+ecx]
	bswap	eax
	xor	eax, edx
	mov	edx, 0
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 10					; 0000000aH
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ab9_0@4 ENDP


_rc$86626 = -4
@op_ad0_0@4 PROC NEAR
	_start_func  'op_ad0_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	dh, al
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, edx
	mov	bl, BYTE PTR [ecx+ebp]
	movsx	eax, ax
	mov	esi, eax
	and	eax, 7
	mov	DWORD PTR _rc$86626[esp+24], eax
	mov	al, BYTE PTR _regs[eax*4]
	movsx	edx, bl
	movsx	ecx, al
	sar	esi, 6
	mov	DWORD PTR -8+[esp+24], edx
	sub	edx, ecx
	and	esi, 7
	xor	ecx, ecx
	test	bl, bl
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	dl, dl
	setl	cl
	test	dl, dl
	sete	BYTE PTR _regflags+1
	xor	edx, edx
	test	al, al
	setl	dl
	cmp	edx, edi
	je	SHORT $L120095
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120096
$L120095:
	mov	BYTE PTR _regflags+3, 0
$L120096:
	cmp	al, bl
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	al, BYTE PTR _regflags+1
	test	ecx, ecx
	setne	cl
	test	al, al
	mov	BYTE PTR _regflags, cl
	je	SHORT $L86639
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	dl, BYTE PTR _regs[esi*4]
	mov	BYTE PTR [eax+ebp], dl
	jmp	SHORT $L120111
$L86639:
	mov	edx, DWORD PTR _rc$86626[esp+24]
	mov	ecx, DWORD PTR -8+[esp+24]
	mov	DWORD PTR _regs[edx*4], ecx
$L120111:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ad0_0@4 ENDP


_rc$86650 = -4
@op_ad8_0@4 PROC NEAR
	_start_func  'op_ad8_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	dh, al
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	edi, DWORD PTR [eax]
	mov	esi, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edi
	mov	dl, BYTE PTR [edx+edi]
	mov	DWORD PTR [eax], ecx
	movsx	eax, si
	mov	esi, eax
	and	eax, 7
	mov	DWORD PTR _rc$86650[esp+24], eax
	mov	al, BYTE PTR _regs[eax*4]
	movsx	ecx, dl
	movsx	ebx, al
	sar	esi, 6
	mov	DWORD PTR -8+[esp+24], ecx
	sub	ecx, ebx
	and	esi, 7
	xor	ebx, ebx
	test	dl, dl
	setl	bl
	mov	ebp, ebx
	xor	ebx, ebx
	test	cl, cl
	setl	bl
	test	cl, cl
	sete	BYTE PTR _regflags+1
	xor	ecx, ecx
	test	al, al
	setl	cl
	cmp	ecx, ebp
	je	SHORT $L120115
	cmp	ebx, ebp
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120116
$L120115:
	mov	BYTE PTR _regflags+3, 0
$L120116:
	cmp	al, dl
	seta	dl
	test	ebx, ebx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	al, BYTE PTR _regflags+1
	test	al, al
	mov	BYTE PTR _regflags+2, dl
	je	SHORT $L86663
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR _regs[esi*4]
	mov	BYTE PTR [edx+edi], cl
	jmp	SHORT $L120131
$L86663:
	mov	ecx, DWORD PTR _rc$86650[esp+24]
	mov	eax, DWORD PTR -8+[esp+24]
	mov	DWORD PTR _regs[ecx*4], eax
$L120131:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ad8_0@4 ENDP


_flgn$86682 = -8
@op_ae0_0@4 PROC NEAR
	_start_func  'op_ae0_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	xor	edx, edx
	mov	ebx, DWORD PTR _areg_byteinc[ecx*4]
	mov	dl, ah
	lea	esi, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dh, al
	mov	eax, DWORD PTR [esi]
	sub	eax, ebx
	mov	edi, edx
	mov	dl, BYTE PTR [ecx+eax]
	mov	DWORD PTR [esi], eax
	movsx	ecx, di
	mov	esi, ecx
	and	ecx, 7
	mov	ebp, ecx
	movsx	edi, dl
	mov	cl, BYTE PTR _regs[ebp*4]
	mov	DWORD PTR -4+[esp+24], edi
	movsx	ebx, cl
	mov	ecx, edi
	sar	esi, 6
	sub	ecx, ebx
	and	esi, 7
	xor	ebx, ebx
	test	dl, dl
	setl	bl
	mov	edi, ebx
	xor	ebx, ebx
	test	cl, cl
	setl	bl
	test	cl, cl
	mov	cl, BYTE PTR _regs[ebp*4]
	mov	DWORD PTR _flgn$86682[esp+24], ebx
	sete	BYTE PTR _regflags+1
	xor	ebx, ebx
	test	cl, cl
	setl	bl
	cmp	ebx, edi
	je	SHORT $L120135
	mov	ebx, DWORD PTR _flgn$86682[esp+24]
	mov	BYTE PTR _regflags+3, 1
	cmp	ebx, edi
	jne	SHORT $L120136
$L120135:
	mov	BYTE PTR _regflags+3, 0
$L120136:
	cmp	cl, dl
	seta	dl
	mov	BYTE PTR _regflags+2, dl
	mov	edx, DWORD PTR _flgn$86682[esp+24]
	test	edx, edx
	setne	cl
	mov	BYTE PTR _regflags, cl
	mov	cl, BYTE PTR _regflags+1
	test	cl, cl
	je	SHORT $L86687
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, BYTE PTR _regs[esi*4]
	mov	BYTE PTR [ecx+eax], dl
	jmp	SHORT $L120152
$L86687:
	mov	edx, DWORD PTR -4+[esp+24]
	mov	DWORD PTR _regs[ebp*4], edx
$L120152:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ae0_0@4 ENDP


_rc$86701 = -4
@op_ae8_0@4 PROC NEAR					;CAS TODO
	_start_func  'op_ae8_0'
	mov	esi, eax
	xor	edx, edx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR [esi+4]
	mov	edi, edx
	xor	edx, edx
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	shr	ecx, 8
	and	ecx, 7
	or	esi, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	esi, eax
	movsx	eax, di
	mov	dl, BYTE PTR [ecx+esi]
	mov	edi, eax
	and	eax, 7
	mov	DWORD PTR _rc$86701[esp+24], eax
	mov	al, BYTE PTR _regs[eax*4]
	movsx	ecx, dl
	movsx	ebx, al
	sar	edi, 6
	mov	DWORD PTR -8+[esp+24], ecx
	sub	ecx, ebx
	and	edi, 7
	xor	ebx, ebx
	test	dl, dl
	setl	bl
	mov	ebp, ebx
	xor	ebx, ebx
	test	cl, cl
	setl	bl
	test	cl, cl
	sete	BYTE PTR _regflags+1
	xor	ecx, ecx
	test	al, al
	setl	cl
	cmp	ecx, ebp
	je	SHORT $L120156
	cmp	ebx, ebp
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120157
$L120156:
	mov	BYTE PTR _regflags+3, 0
$L120157:
	cmp	al, dl
	seta	dl
	test	ebx, ebx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	al, BYTE PTR _regflags+1
	test	al, al
	mov	BYTE PTR _regflags+2, dl
	je	SHORT $L86714
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR _regs[edi*4]
	mov	BYTE PTR [edx+esi], cl
	jmp	SHORT $L120176
$L86714:
	mov	ecx, DWORD PTR _rc$86701[esp+24]
	mov	eax, DWORD PTR -8+[esp+24]
	mov	DWORD PTR _regs[ecx*4], eax
$L120176:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ae8_0@4 ENDP


_rc$86725 = -4
@op_af0_0@4 PROC NEAR
	_start_func  'op_af0_0'
	mov	esi, eax
	xor	edx, edx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	DWORD PTR _regs+92, esi
	mov	dh, al
	add	esi, 2
	mov	edi, edx
	mov	dx, WORD PTR [esi-2]
	shr	ecx, 8
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ebp, eax
	mov	bl, BYTE PTR [ecx+ebp]
	movsx	ecx, di
	mov	esi, ecx
	and	ecx, 7
	mov	DWORD PTR _rc$86725[esp+24], ecx
	mov	al, BYTE PTR _regs[ecx*4]
	movsx	edx, bl
	movsx	ecx, al
	sar	esi, 6
	mov	DWORD PTR -8+[esp+24], edx
	sub	edx, ecx
	and	esi, 7
	xor	ecx, ecx
	test	bl, bl
	setl	cl
	mov	edi, ecx
	xor	ecx, ecx
	test	dl, dl
	setl	cl
	test	dl, dl
	sete	BYTE PTR _regflags+1
	xor	edx, edx
	test	al, al
	setl	dl
	cmp	edx, edi
	je	SHORT $L120180
	cmp	ecx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120181
$L120180:
	mov	BYTE PTR _regflags+3, 0
$L120181:
	cmp	al, bl
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	al, BYTE PTR _regflags+1
	test	ecx, ecx
	setne	cl
	test	al, al
	mov	BYTE PTR _regflags, cl
	je	SHORT $L86738
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	dl, BYTE PTR _regs[esi*4]
	mov	BYTE PTR [eax+ebp], dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L86738:
	mov	edx, DWORD PTR _rc$86725[esp+24]
	mov	ecx, DWORD PTR -8+[esp+24]
	mov	DWORD PTR _regs[edx*4], ecx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_af0_0@4 ENDP


_rc$86751 = -4
@op_af8_0@4 PROC NEAR
	_start_func  'op_af8_0'
	mov	ecx, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR [ecx+4]
	mov	edi, edx
	xor	ecx, ecx
	xor	edx, edx
	mov	cl, ah
	mov	dh, al
	movsx	esi, cx
	movsx	eax, dx
	mov	ecx, DWORD PTR _MEMBaseDiff
	or	esi, eax
	movsx	eax, di
	mov	dl, BYTE PTR [ecx+esi]
	mov	edi, eax
	and	eax, 7
	mov	DWORD PTR _rc$86751[esp+24], eax
	mov	al, BYTE PTR _regs[eax*4]
	movsx	ecx, dl
	movsx	ebx, al
	sar	edi, 6
	mov	DWORD PTR -8+[esp+24], ecx
	sub	ecx, ebx
	and	edi, 7
	xor	ebx, ebx
	test	dl, dl
	setl	bl
	mov	ebp, ebx
	xor	ebx, ebx
	test	cl, cl
	setl	bl
	test	cl, cl
	sete	BYTE PTR _regflags+1
	xor	ecx, ecx
	test	al, al
	setl	cl
	cmp	ecx, ebp
	je	SHORT $L120208
	cmp	ebx, ebp
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120209
$L120208:
	mov	BYTE PTR _regflags+3, 0
$L120209:
	cmp	al, dl
	seta	dl
	test	ebx, ebx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	al, BYTE PTR _regflags+1
	test	al, al
	mov	BYTE PTR _regflags+2, dl
	je	SHORT $L86764
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR _regs[edi*4]
	mov	BYTE PTR [edx+esi], cl
	jmp	SHORT $L120228
$L86764:
	mov	ecx, DWORD PTR _rc$86751[esp+24]
	mov	eax, DWORD PTR -8+[esp+24]
	mov	DWORD PTR _regs[ecx*4], eax
$L120228:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_af8_0@4 ENDP


_x$120240 = -4
_rc$86775 = -12
@op_af9_0@4 PROC NEAR
	_start_func  'op_af9_0'
	mov	ebp, esp
	sub	esp, 12					; 0000000cH
	mov	ecx, eax
	xor	edx, edx
	push	ebx
	push	esi
	mov	ax, WORD PTR [ecx+2]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	mov	dl, ah
	push	edi
	mov	dh, al
	mov	DWORD PTR _x$120240[ebp], ecx
	mov	eax, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	movsx	eax, ax
	mov	dl, BYTE PTR [edx+ecx]
	mov	esi, eax
	and	eax, 7
	mov	DWORD PTR _rc$86775[ebp], eax
	mov	al, BYTE PTR _regs[eax*4]
	movsx	ecx, dl
	movsx	edi, al
	sar	esi, 6
	mov	DWORD PTR -8+[ebp], ecx
	and	esi, 7
	sub	ecx, edi
	test	dl, dl
	setl	bl
	mov	edi, ebx
	xor	ebx, ebx
	test	cl, cl
	setl	bl
	test	cl, cl
	sete	BYTE PTR _regflags+1
	xor	ecx, ecx
	test	al, al
	setl	cl
	cmp	ecx, edi
	je	SHORT $L120232
	cmp	ebx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120233
$L120232:
	mov	BYTE PTR _regflags+3, 0
$L120233:
	cmp	al, dl
	seta	dl
	test	ebx, ebx
	setne	al
	mov	BYTE PTR _regflags, al
	mov	al, BYTE PTR _regflags+1
	test	al, al
	mov	BYTE PTR _regflags+2, dl
	je	SHORT $L86788
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR _x$120240[ebp]
	mov	cl, BYTE PTR _regs[esi*4]
	mov	BYTE PTR [edx+eax], cl
	jmp	SHORT $L120253
$L86788:
	mov	edx, DWORD PTR _rc$86775[ebp]
	mov	ecx, DWORD PTR -8+[ebp]
	mov	DWORD PTR _regs[edx*4], ecx
$L120253:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_af9_0@4 ENDP


@op_c18_0@4 PROC NEAR
	_start_func  'op_c18_0'
	shr	ecx, 8
	mov	dl, BYTE PTR [eax+3]
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	bl, BYTE PTR [esi+edi]
	add	ecx, esi
	mov	DWORD PTR [eax], ecx
	movsx	eax, bl
	movsx	ecx, dl
	sub	eax, ecx
	xor	ecx, ecx
	test	bl, bl
	setl	cl
	mov	esi, ecx
	xor	ecx, ecx
	test	al, al
	setl	cl
	test	al, al
	mov	edi, ecx
	sete	al
	xor	ecx, ecx
	mov	BYTE PTR _regflags+1, al
	test	dl, dl
	setl	cl
	cmp	ecx, esi
	je	SHORT $L120256
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120257
$L120256:
	mov	BYTE PTR _regflags+3, 0
$L120257:
	cmp	dl, bl
	seta	dl
	test	edi, edi
	setne	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c18_0@4 ENDP


@op_c20_0@4 PROC NEAR
	_start_func  'op_c20_0'
	shr	ecx, 8
	mov	dl, BYTE PTR [eax+3]
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ebx, DWORD PTR _areg_byteinc[ecx*4]
	lea	esi, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	eax, ebx
	xor	ebx, ebx
	mov	cl, BYTE PTR [ecx+eax]
	mov	DWORD PTR [esi], eax
	movsx	eax, cl
	movsx	esi, dl
	sub	eax, esi
	test	cl, cl
	setl	bl
	mov	esi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	dl, dl
	setl	al
	cmp	eax, esi
	mov	edi, ebx
	je	SHORT $L120266
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120267
$L120266:
	mov	BYTE PTR _regflags+3, 0
$L120267:
	mov	eax, DWORD PTR _regs+92
	cmp	dl, cl
	seta	cl
	test	edi, edi
	setne	dl
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c20_0@4 ENDP


@op_c38_0@4 PROC NEAR
	_start_func  'op_c38_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+4]
	mov	cl, BYTE PTR [esi+3]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	dl, BYTE PTR [edx+eax]
	movsx	eax, dl
	movsx	edi, cl
	sub	eax, edi
	test	dl, dl
	setl	bl
	mov	edi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	cl, cl
	setl	al
	cmp	eax, edi
	mov	ebp, ebx
	je	SHORT $L120276
	cmp	ebp, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120277
$L120276:
	mov	BYTE PTR _regflags+3, 0
$L120277:
	cmp	cl, dl
	seta	cl
	test	ebp, ebp
	setne	dl
	add	esi, 6
	mov	BYTE PTR _regflags+2, cl
	mov	DWORD PTR _regs+92, esi
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c38_0@4 ENDP


@op_c39_0@4 PROC NEAR
	_start_func  'op_c39_0'
	mov	cl, BYTE PTR [eax+3]
	mov	eax, DWORD PTR [eax+4]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	movsx	esi, cl
	mov	dl, BYTE PTR [edx+eax]
	movsx	eax, dl
	sub	eax, esi
	test	dl, dl
	setl	bl
	mov	esi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	cl, cl
	setl	al
	cmp	eax, esi
	mov	edi, ebx
	je	SHORT $L120290
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120291
$L120290:
	mov	BYTE PTR _regflags+3, 0
$L120291:
	mov	eax, DWORD PTR _regs+92
	cmp	cl, dl
	seta	cl
	test	edi, edi
	setne	dl
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c39_0@4 ENDP


@op_c3a_0@4 PROC NEAR
	_start_func  'op_c3a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+4]
	mov	ebp, DWORD PTR _regs+88
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	edi, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [esi+3]
	sub	edx, edi
	add	edx, eax
	xor	ebx, ebx
	add	edx, ebp
	movsx	edi, cl
	mov	dl, BYTE PTR [edx+esi+4]
	movsx	eax, dl
	sub	eax, edi
	test	dl, dl
	setl	bl
	mov	edi, ebx
	xor	ebx, ebx
	test	al, al
	setl	bl
	test	al, al
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	cl, cl
	setl	al
	cmp	eax, edi
	mov	ebp, ebx
	je	SHORT $L120305
	cmp	ebp, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120306
$L120305:
	mov	BYTE PTR _regflags+3, 0
$L120306:
	cmp	cl, dl
	seta	cl
	test	ebp, ebp
	setne	dl
	add	esi, 6
	mov	BYTE PTR _regflags+2, cl
	mov	DWORD PTR _regs+92, esi
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c3a_0@4 ENDP


@op_c3b_0@4 PROC NEAR
	_start_func  'op_c3b_0'
	mov	ecx, DWORD PTR _regs+88
	mov	bl, BYTE PTR [eax+3]
	mov	esi, DWORD PTR _regs+96
	add	eax, 4
	sub	ecx, esi
	mov	DWORD PTR _regs+92, eax
	add	ecx, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	movsx	edx, bl
	mov	cl, BYTE PTR [ecx+eax]
	movsx	eax, cl
	sub	eax, edx
	xor	edx, edx
	test	cl, cl
	setl	dl
	mov	esi, edx
	xor	edx, edx
	test	al, al
	setl	dl
	test	al, al
	mov	edi, edx
	sete	al
	xor	edx, edx
	mov	BYTE PTR _regflags+1, al
	test	bl, bl
	setl	dl
	cmp	edx, esi
	je	SHORT $L120322
	cmp	edi, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120323
$L120322:
	mov	BYTE PTR _regflags+3, 0
$L120323:
	cmp	bl, cl
	seta	al
	test	edi, edi
	setne	cl
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c3b_0@4 ENDP


@op_c70_0@4 PROC NEAR
	_start_func  'op_c70_0'
	mov	esi, eax
	xor	edx, edx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	DWORD PTR _regs+92, esi
	mov	dh, al
	add	esi, 2
	mov	edi, edx
	mov	dx, WORD PTR [esi-2]
	shr	ecx, 8
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	movsx	edx, di
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	movsx	eax, cx
	sub	eax, edx
	xor	edx, edx
	test	cx, cx
	setl	dl
	mov	esi, edx
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	di, di
	setl	al
	cmp	eax, esi
	je	SHORT $L120342
	cmp	edx, esi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120343
$L120342:
	mov	BYTE PTR _regflags+3, 0
$L120343:
	cmp	di, cx
	seta	cl
	test	edx, edx
	setne	dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c70_0@4 ENDP


@op_c78_0@4 PROC NEAR
	_start_func  'op_c78_0'
	mov	edi, eax
	xor	ecx, ecx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [edi+2]
	mov	cl, ah
	mov	ch, al
	mov	ax, WORD PTR [edi+4]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	movsx	eax, si
	movsx	edx, cx
	sub	eax, edx
	xor	edx, edx
	test	si, si
	setl	dl
	mov	ebp, edx
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	cx, cx
	setl	al
	cmp	eax, ebp
	je	SHORT $L120364
	cmp	edx, ebp
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120365
$L120364:
	mov	BYTE PTR _regflags+3, 0
$L120365:
	cmp	cx, si
	seta	cl
	test	edx, edx
	setne	dl
	add	edi, 6
	mov	BYTE PTR _regflags+2, cl
	mov	DWORD PTR _regs+92, edi
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c78_0@4 ENDP


@op_c79_0@4 PROC NEAR
	_start_func  'op_c79_0'
	mov	edx, eax
	xor	ecx, ecx
	mov	ax, WORD PTR [edx+2]
	mov	edx, DWORD PTR [edx+4]
	bswap	edx
	mov	cl, ah
	mov	ch, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [eax+edx]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	esi, edx
	movsx	eax, si
	movsx	edx, cx
	sub	eax, edx
	xor	edx, edx
	test	si, si
	setl	dl
	mov	edi, edx
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	cx, cx
	setl	al
	cmp	eax, edi
	je	SHORT $L120382
	cmp	edx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120383
$L120382:
	mov	BYTE PTR _regflags+3, 0
$L120383:
	mov	eax, DWORD PTR _regs+92
	cmp	cx, si
	seta	cl
	test	edx, edx
	setne	dl
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c79_0@4 ENDP


@op_c7a_0@4 PROC NEAR
	_start_func  'op_c7a_0'
	mov	ecx, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	xor	ebx, ebx
	mov	dh, al
	mov	ax, WORD PTR [ecx+4]
	mov	esi, edx
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebp, DWORD PTR _regs+88
	mov	edi, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, edi
	add	edx, eax
	add	edx, ebp
	mov	ax, WORD PTR [edx+ecx+4]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	edi, edx
	movsx	eax, di
	movsx	edx, si
	sub	eax, edx
	xor	edx, edx
	test	di, di
	setl	dl
	mov	ebp, edx
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	si, si
	setl	al
	cmp	eax, ebp
	je	SHORT $L120401
	cmp	edx, ebp
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120402
$L120401:
	mov	BYTE PTR _regflags+3, 0
$L120402:
	cmp	si, di
	seta	al
	test	edx, edx
	setne	dl
	add	ecx, 6
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, ecx
	mov	eax,ecx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c7a_0@4 ENDP


@op_c7b_0@4 PROC NEAR
	_start_func  'op_c7b_0'
	xor	edx, edx
	mov	cx, WORD PTR [eax+2]
	mov	edi, DWORD PTR _regs+96
	mov	dl, ch
	add	eax, 4
	mov	dh, cl
	mov	ecx, DWORD PTR _regs+88
	sub	ecx, edi
	mov	esi, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	movsx	edx, si
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	movsx	eax, cx
	sub	eax, edx
	xor	edx, edx
	test	cx, cx
	setl	dl
	mov	edi, edx
	xor	edx, edx
	test	ax, ax
	setl	dl
	test	ax, ax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	si, si
	setl	al
	cmp	eax, edi
	je	SHORT $L120422
	cmp	edx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120423
$L120422:
	mov	BYTE PTR _regflags+3, 0
$L120423:
	cmp	si, cx
	seta	cl
	test	edx, edx
	setne	dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_c7b_0@4 ENDP


@op_cb8_0@4 PROC NEAR
	_start_func  'op_cb8_0'
	mov	ecx, DWORD PTR [eax+2]
	bswap	ecx
	mov	edx, DWORD PTR _regs+92
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+6]
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [edx+eax]
	bswap	esi
	mov	eax, esi
	xor	edx, edx
	sub	eax, ecx
	test	esi, esi
	setl	dl
	mov	edi, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	ecx, ecx
	setl	al
	cmp	eax, edi
	je	SHORT $L120446
	cmp	edx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120447
$L120446:
	mov	BYTE PTR _regflags+3, 0
$L120447:
	mov	eax, DWORD PTR _regs+92
	cmp	ecx, esi
	seta	cl
	test	edx, edx
	setne	dl
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_cb8_0@4 ENDP


@op_cb9_0@4 PROC NEAR
	_start_func  'op_cb9_0'
	mov	ecx, DWORD PTR [eax+2]
	bswap	ecx
	mov	edx, DWORD PTR _regs+92
	mov	eax, DWORD PTR [edx+6]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [edx+eax]
	bswap	esi
	mov	eax, esi
	xor	edx, edx
	sub	eax, ecx
	test	esi, esi
	setl	dl
	mov	edi, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	ecx, ecx
	setl	al
	cmp	eax, edi
	je	SHORT $L120467
	cmp	edx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120468
$L120467:
	mov	BYTE PTR _regflags+3, 0
$L120468:
	mov	eax, DWORD PTR _regs+92
	cmp	ecx, esi
	seta	cl
	test	edx, edx
	setne	dl
	add	eax, 10					; 0000000aH
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_cb9_0@4 ENDP


@op_cba_0@4 PROC NEAR
	_start_func  'op_cba_0'
	mov	ecx, DWORD PTR [eax+2]
	bswap	ecx
	mov	esi, DWORD PTR _regs+92
	xor	edx, edx
	xor	ebx, ebx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [esi+6]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _regs+88
	sub	edx, ebx
	add	edx, edi
	add	edx, eax
	mov	esi, DWORD PTR [edx+esi+6]
	bswap	esi
	mov	eax, esi
	xor	edx, edx
	sub	eax, ecx
	test	esi, esi
	setl	dl
	mov	edi, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	ecx, ecx
	setl	al
	cmp	eax, edi
	je	SHORT $L120489
	cmp	edx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120490
$L120489:
	mov	BYTE PTR _regflags+3, 0
$L120490:
	mov	eax, DWORD PTR _regs+92
	cmp	ecx, esi
	seta	cl
	test	edx, edx
	setne	dl
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_cba_0@4 ENDP


@op_cbb_0@4 PROC NEAR
	_start_func  'op_cbb_0'
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	eax, DWORD PTR _regs+92
	mov	ecx, DWORD PTR _regs+88
	mov	edi, DWORD PTR _regs+96
	add	eax, 6
	sub	ecx, edi
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	mov	eax, ecx
	xor	edx, edx
	sub	eax, esi
	test	ecx, ecx
	setl	dl
	mov	edi, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	test	eax, eax
	sete	al
	mov	BYTE PTR _regflags+1, al
	xor	eax, eax
	test	esi, esi
	setl	al
	cmp	eax, edi
	je	SHORT $L120513
	cmp	edx, edi
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120514
$L120513:
	mov	BYTE PTR _regflags+3, 0
$L120514:
	cmp	esi, ecx
	seta	cl
	test	edx, edx
	setne	dl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_cbb_0@4 ENDP


_rc$87129 = -4
@op_cd0_0@4 PROC NEAR
	_start_func  'op_cd0_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	esi, edx
	mov	ax, WORD PTR [eax+ecx]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	movsx	eax, si
	mov	esi, eax
	and	eax, 7
	mov	edi, edx
	mov	DWORD PTR _rc$87129[esp+24], eax
	mov	bx, WORD PTR _regs[eax*4]
	movsx	edx, di
	movsx	eax, bx
	sar	esi, 6
	mov	DWORD PTR -8+[esp+24], edx
	sub	edx, eax
	and	esi, 7
	xor	eax, eax
	test	di, di
	setl	al
	mov	ebp, eax
	xor	eax, eax
	test	dx, dx
	setl	al
	test	dx, dx
	sete	BYTE PTR _regflags+1
	xor	edx, edx
	test	bx, bx
	setl	dl
	cmp	edx, ebp
	je	SHORT $L120540
	cmp	eax, ebp
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120541
$L120540:
	mov	BYTE PTR _regflags+3, 0
$L120541:
	cmp	bx, di
	seta	dl
	test	eax, eax
	setne	al
	mov	BYTE PTR _regflags, al
	mov	al, BYTE PTR _regflags+1
	test	al, al
	mov	BYTE PTR _regflags+2, dl
	je	SHORT $L87142
	mov	ax, WORD PTR _regs[esi*4]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	jmp	SHORT $L120556
$L87142:
	mov	edx, DWORD PTR _rc$87129[esp+24]
	mov	ecx, DWORD PTR -8+[esp+24]
	mov	DWORD PTR _regs[edx*4], ecx
$L120556:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_cd0_0@4 ENDP


_rc$87153 = -4
@op_cd8_0@4 PROC NEAR
	_start_func  'op_cd8_0'
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	mov	ebp, DWORD PTR _regs[ecx*4+32]
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [eax+ebp]
	mov	edi, edx
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	lea	eax, DWORD PTR [ebp+2]
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	esi, edx
	movsx	eax, di
	mov	edx, eax
	and	eax, 7
	mov	DWORD PTR _rc$87153[esp+24], eax
	mov	di, WORD PTR _regs[eax*4]
	movsx	ecx, si
	movsx	eax, di
	sar	edx, 6
	mov	DWORD PTR -8+[esp+24], ecx
	sub	ecx, eax
	and	edx, 7
	xor	eax, eax
	test	si, si
	setl	al
	xor	ebx, ebx
	test	cx, cx
	setl	bl
	test	cx, cx
	sete	BYTE PTR _regflags+1
	xor	ecx, ecx
	test	di, di
	setl	cl
	cmp	ecx, eax
	je	SHORT $L120560
	cmp	ebx, eax
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120561
$L120560:
	mov	BYTE PTR _regflags+3, 0
$L120561:
	cmp	di, si
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	al, BYTE PTR _regflags+1
	test	ebx, ebx
	setne	cl
	test	al, al
	mov	BYTE PTR _regflags, cl
	je	SHORT $L87166
	mov	dx, WORD PTR _regs[edx*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	eax, eax
	mov	al, dh
	mov	ah, dl
	mov	WORD PTR [ecx+ebp], ax
	jmp	SHORT $L120576
$L87166:
	mov	eax, DWORD PTR _rc$87153[esp+24]
	mov	edx, DWORD PTR -8+[esp+24]
	mov	DWORD PTR _regs[eax*4], edx
$L120576:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_cd8_0@4 ENDP


_rc$87177 = -4
@op_ce0_0@4 PROC NEAR
	_start_func  'op_ce0_0'
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	esi, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	eax, DWORD PTR _regs[esi*4+32]
	sub	eax, 2
	mov	ebp, ecx
	mov	cx, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ch
	mov	DWORD PTR _regs[esi*4+32], eax
	mov	dh, cl
	movsx	ecx, bp
	mov	esi, ecx
	and	ecx, 7
	mov	edi, edx
	mov	DWORD PTR _rc$87177[esp+24], ecx
	mov	bp, WORD PTR _regs[ecx*4]
	movsx	edx, di
	movsx	ecx, bp
	sar	esi, 6
	mov	DWORD PTR -8+[esp+24], edx
	sub	edx, ecx
	and	esi, 7
	xor	ecx, ecx
	test	di, di
	setl	cl
	xor	ebx, ebx
	test	dx, dx
	setl	bl
	test	dx, dx
	sete	BYTE PTR _regflags+1
	xor	edx, edx
	test	bp, bp
	setl	dl
	cmp	edx, ecx
	je	SHORT $L120580
	cmp	ebx, ecx
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120581
$L120580:
	mov	BYTE PTR _regflags+3, 0
$L120581:
	cmp	bp, di
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	cl, BYTE PTR _regflags+1
	test	ebx, ebx
	setne	dl
	test	cl, cl
	mov	BYTE PTR _regflags, dl
	je	SHORT $L87190
	mov	cx, WORD PTR _regs[esi*4]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+eax], dx
	jmp	SHORT $L120596
$L87190:
	mov	eax, DWORD PTR _rc$87177[esp+24]
	mov	edx, DWORD PTR -8+[esp+24]
	mov	DWORD PTR _regs[eax*4], edx
$L120596:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ce0_0@4 ENDP


_rc$87204 = -4
@op_ce8_0@4 PROC NEAR
	_start_func  'op_ce8_0'
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	shr	esi, 8
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ah
	and	esi, 7
	mov	dh, al
	xor	eax, eax
	mov	ebp, edx
	xor	edx, edx
	mov	al, ch
	mov	dh, cl
	movsx	eax, ax
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	eax, ecx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	mov	cx, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	movsx	ecx, bp
	mov	esi, ecx
	and	ecx, 7
	mov	edi, edx
	mov	DWORD PTR _rc$87204[esp+24], ecx
	mov	bp, WORD PTR _regs[ecx*4]
	movsx	edx, di
	movsx	ecx, bp
	sar	esi, 6
	mov	DWORD PTR -8+[esp+24], edx
	sub	edx, ecx
	and	esi, 7
	xor	ecx, ecx
	test	di, di
	setl	cl
	xor	ebx, ebx
	test	dx, dx
	setl	bl
	test	dx, dx
	sete	BYTE PTR _regflags+1
	xor	edx, edx
	test	bp, bp
	setl	dl
	cmp	edx, ecx
	je	SHORT $L120600
	cmp	ebx, ecx
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120601
$L120600:
	mov	BYTE PTR _regflags+3, 0
$L120601:
	cmp	bp, di
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	cl, BYTE PTR _regflags+1
	test	ebx, ebx
	setne	dl
	test	cl, cl
	mov	BYTE PTR _regflags, dl
	je	SHORT $L87217
	mov	cx, WORD PTR _regs[esi*4]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+eax], dx
	jmp	SHORT $L120620
$L87217:
	mov	eax, DWORD PTR _rc$87204[esp+24]
	mov	edx, DWORD PTR -8+[esp+24]
	mov	DWORD PTR _regs[eax*4], edx
$L120620:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ce8_0@4 ENDP


_rc$87228 = -4
@op_cf0_0@4 PROC NEAR
	_start_func  'op_cf0_0'
	mov	esi, eax
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	bl, ah
	mov	DWORD PTR _regs+92, esi
	mov	dx, WORD PTR [esi]
	mov	bh, al
	shr	ecx, 8
	add	esi, 2
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	cx, WORD PTR [ecx+eax]
	mov	dl, ch
	mov	dh, cl
	movsx	ecx, bx
	mov	esi, ecx
	and	ecx, 7
	mov	edi, edx
	mov	DWORD PTR _rc$87228[esp+24], ecx
	mov	bx, WORD PTR _regs[ecx*4]
	movsx	edx, di
	movsx	ecx, bx
	sar	esi, 6
	mov	DWORD PTR -8+[esp+24], edx
	sub	edx, ecx
	and	esi, 7
	xor	ecx, ecx
	test	di, di
	setl	cl
	mov	ebp, ecx
	xor	ecx, ecx
	test	dx, dx
	setl	cl
	test	dx, dx
	sete	BYTE PTR _regflags+1
	xor	edx, edx
	test	bx, bx
	setl	dl
	cmp	edx, ebp
	je	SHORT $L120624
	cmp	ecx, ebp
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120625
$L120624:
	mov	BYTE PTR _regflags+3, 0
$L120625:
	cmp	bx, di
	seta	dl
	test	ecx, ecx
	setne	cl
	mov	BYTE PTR _regflags, cl
	mov	cl, BYTE PTR _regflags+1
	test	cl, cl
	mov	BYTE PTR _regflags+2, dl
	je	SHORT $L87241
	mov	cx, WORD PTR _regs[esi*4]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87241:
	mov	eax, DWORD PTR _rc$87228[esp+24]
	mov	edx, DWORD PTR -8+[esp+24]
	mov	DWORD PTR _regs[eax*4], edx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_cf0_0@4 ENDP


_rc$87254 = -4
@op_cf8_0@4 PROC NEAR
	_start_func  'op_cf8_0'
	mov	ecx, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR [ecx+4]
	xor	ecx, ecx
	mov	esi, edx
	mov	cl, ah
	movsx	edx, cx
	xor	ecx, ecx
	mov	ch, al
	movsx	eax, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	ax, WORD PTR [ecx+edx]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	movsx	eax, si
	mov	esi, eax
	and	eax, 7
	mov	edi, ecx
	mov	DWORD PTR _rc$87254[esp+24], eax
	mov	bp, WORD PTR _regs[eax*4]
	movsx	ecx, di
	movsx	eax, bp
	sar	esi, 6
	mov	DWORD PTR -8+[esp+24], ecx
	sub	ecx, eax
	and	esi, 7
	xor	eax, eax
	test	di, di
	setl	al
	xor	ebx, ebx
	test	cx, cx
	setl	bl
	test	cx, cx
	sete	BYTE PTR _regflags+1
	xor	ecx, ecx
	test	bp, bp
	setl	cl
	cmp	ecx, eax
	je	SHORT $L120652
	cmp	ebx, eax
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120653
$L120652:
	mov	BYTE PTR _regflags+3, 0
$L120653:
	cmp	bp, di
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	al, BYTE PTR _regflags+1
	test	ebx, ebx
	setne	cl
	test	al, al
	mov	BYTE PTR _regflags, cl
	je	SHORT $L87267
	mov	ax, WORD PTR _regs[esi*4]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+edx], cx
	jmp	SHORT $L120672
$L87267:
	mov	edx, DWORD PTR _rc$87254[esp+24]
	mov	ecx, DWORD PTR -8+[esp+24]
	mov	DWORD PTR _regs[edx*4], ecx
$L120672:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_cf8_0@4 ENDP


_rc$87278 = -12
_x$120684 = -4
@op_cf9_0@4 PROC NEAR
	_start_func  'op_cf9_0'
	mov	ebp, esp
	sub	esp, 12					; 0000000cH
	mov	ecx, eax
	xor	edx, edx
	push	ebx
	push	esi
	mov	ax, WORD PTR [ecx+2]
	push	edi
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR [ecx+4]
	bswap	eax
	mov	DWORD PTR _x$120684[ebp], eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	movsx	eax, dx
	mov	edx, eax
	and	eax, 7
	mov	esi, ecx
	mov	DWORD PTR _rc$87278[ebp], eax
	mov	di, WORD PTR _regs[eax*4]
	movsx	ecx, si
	movsx	eax, di
	sar	edx, 6
	mov	DWORD PTR -8+[ebp], ecx
	sub	ecx, eax
	and	edx, 7
	xor	eax, eax
	test	si, si
	setl	al
	xor	ebx, ebx
	test	cx, cx
	setl	bl
	test	cx, cx
	sete	BYTE PTR _regflags+1
	xor	ecx, ecx
	test	di, di
	setl	cl
	cmp	ecx, eax
	je	SHORT $L120676
	cmp	ebx, eax
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L120677
$L120676:
	mov	BYTE PTR _regflags+3, 0
$L120677:
	cmp	di, si
	pop	edi
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	al, BYTE PTR _regflags+1
	test	ebx, ebx
	setne	cl
	pop	esi
	mov	BYTE PTR _regflags, cl
	test	al, al
	pop	ebx
	je	SHORT $L87291
	mov	dx, WORD PTR _regs[edx*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	eax, eax
	mov	al, dh
	mov	ah, dl
	mov	edx, DWORD PTR _x$120684[ebp]
	mov	WORD PTR [ecx+edx], ax
	jmp	SHORT $L120697
$L87291:
	mov	ecx, DWORD PTR _rc$87278[ebp]
	mov	eax, DWORD PTR -8+[ebp]
	mov	DWORD PTR _regs[ecx*4], eax
$L120697:
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_cf9_0@4 ENDP


_rn1$87298 = -12
_flgo$87307 = -8
_flgn$87309 = -4
_flgo$87320 = -8
_flgn$87322 = -4
@op_cfc_0@4 PROC NEAR
	_start_func  'op_cfc_0'
	mov	ebp, esp
	sub	esp, 12					; 0000000cH
	push	ebx
	push	esi
	push	edi
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ecx, eax
	sar	ecx, 28					; 0000001cH
	and	ecx, 15					; 0000000fH
	xor	edx, edx
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	DWORD PTR _rn1$87298[ebp], ecx
	mov	cx, WORD PTR [edi+ecx]
	mov	dl, ch
	mov	dh, cl
	mov	ecx, eax
	sar	ecx, 12					; 0000000cH
	and	ecx, 15					; 0000000fH
	mov	esi, edx
	mov	edx, DWORD PTR _regs[ecx*4]
	mov	cx, WORD PTR [edx+edi]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	mov	ecx, eax
	sar	ecx, 16					; 00000010H
	and	ecx, 7
	mov	edi, edx
	mov	dx, WORD PTR _regs[ecx*4]
	movsx	ebx, dx
	movsx	ecx, si
	sub	ecx, ebx
	xor	ebx, ebx
	test	si, si
	setl	bl
	mov	DWORD PTR _flgo$87307[ebp], ebx
	xor	ebx, ebx
	test	cx, cx
	setl	bl
	test	cx, cx
	mov	ecx, DWORD PTR _flgo$87307[ebp]
	mov	DWORD PTR _flgn$87309[ebp], ebx
	sete	BYTE PTR _regflags+1
	xor	ebx, ebx
	test	dx, dx
	setl	bl
	cmp	ebx, ecx
	je	SHORT $L120700
	mov	ebx, DWORD PTR _flgn$87309[ebp]
	mov	BYTE PTR _regflags+3, 1
	cmp	ebx, ecx
	jne	SHORT $L120701
$L120700:
	mov	BYTE PTR _regflags+3, 0
$L120701:
	cmp	dx, si
	seta	dl
	mov	BYTE PTR _regflags+2, dl
	mov	edx, DWORD PTR _flgn$87309[ebp]
	test	edx, edx
	setne	cl
	mov	BYTE PTR _regflags, cl
	mov	cl, BYTE PTR _regflags+1
	test	cl, cl
	je	$L120730
	mov	edx, eax
	and	edx, 7
	movsx	ecx, di
	mov	dx, WORD PTR _regs[edx*4]
	movsx	ebx, dx
	sub	ecx, ebx
	xor	ebx, ebx
	test	di, di
	setl	bl
	mov	DWORD PTR _flgo$87320[ebp], ebx
	xor	ebx, ebx
	test	cx, cx
	setl	bl
	test	cx, cx
	mov	ecx, DWORD PTR _flgo$87320[ebp]
	mov	DWORD PTR _flgn$87322[ebp], ebx
	sete	BYTE PTR _regflags+1
	xor	ebx, ebx
	test	dx, dx
	setl	bl
	cmp	ebx, ecx
	je	SHORT $L120702
	mov	ebx, DWORD PTR _flgn$87322[ebp]
	mov	BYTE PTR _regflags+3, 1
	cmp	ebx, ecx
	jne	SHORT $L120703
$L120702:
	mov	BYTE PTR _regflags+3, 0
$L120703:
	cmp	dx, di
	mov	edx, DWORD PTR _flgn$87322[ebp]
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	cl, BYTE PTR _regflags+1
	test	edx, edx
	setne	dl
	test	cl, cl
	mov	BYTE PTR _regflags, dl
	je	SHORT $L120730
	mov	ecx, eax
	mov	edx, DWORD PTR _rn1$87298[ebp]
	sar	ecx, 22					; 00000016H
	and	ecx, 7
	xor	ebx, ebx
	mov	cx, WORD PTR _regs[ecx*4]
	mov	bl, ch
	mov	bh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+edx], bx
	mov	ecx, eax
	sar	ecx, 6
	and	ecx, 7
	xor	ebx, ebx
	mov	cx, WORD PTR _regs[ecx*4]
	mov	bl, ch
	mov	bh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+edx], bx
	mov	cl, BYTE PTR _regflags+1
	test	cl, cl
	jne	SHORT $L120731
$L120730:
	mov	edx, eax
	and	esi, 65535				; 0000ffffH
	sar	edx, 22					; 00000016H
	and	edx, 7
	and	edi, 65535				; 0000ffffH
	sar	eax, 6
	lea	ecx, DWORD PTR _regs[edx*4]
	and	eax, 7
	mov	edx, DWORD PTR [ecx]
	lea	eax, DWORD PTR _regs[eax*4]
	and	edx, -65536				; ffff0000H
	or	edx, esi
	mov	DWORD PTR [ecx], edx
	mov	ecx, DWORD PTR [eax]
	and	ecx, -65536				; ffff0000H
	or	ecx, edi
	mov	DWORD PTR [eax], ecx
$L120731:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_cfc_0@4 ENDP


@op_e10_0@4 PROC NEAR
	_start_func  'op_e10_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	jne	SHORT $L87333
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87333:
	mov	eax, DWORD PTR _regs+92
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87338
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	mov	eax, DWORD PTR _regs[eax*4]
	mov	BYTE PTR [ecx+edx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87338:
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	test	ah, -128				; ffffff80H
	mov	cl, BYTE PTR [ecx+edx]
	je	SHORT $L87344
	sar	eax, 12					; 0000000cH
	movsx	ecx, cl
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87344:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	BYTE PTR _regs[eax*4], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e10_0@4 ENDP


@op_e18_0@4 PROC NEAR
	_start_func  'op_e18_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	jne	SHORT $L87354
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87354:
	mov	eax, DWORD PTR _regs+92
	xor	edx, edx
	push	esi
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87359
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	add	ecx, esi
	mov	eax, DWORD PTR _regs[eax*4]
	mov	DWORD PTR [edx], ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR [edx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87359:
	mov	edx, DWORD PTR _MEMBaseDiff
	lea	esi, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	push	edi
	mov	edi, DWORD PTR [esi]
	add	ecx, edi
	mov	dl, BYTE PTR [edi+edx]
	mov	DWORD PTR [esi], ecx
	test	ah, -128				; ffffff80H
	pop	edi
	je	SHORT $L87365
	sar	eax, 12					; 0000000cH
	movsx	edx, dl
	and	eax, 7
	pop	esi
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87365:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	pop	esi
	mov	BYTE PTR _regs[eax*4], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e18_0@4 ENDP


@op_e20_0@4 PROC NEAR
	_start_func  'op_e20_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	mov	edx, ecx
	jne	SHORT $L87375
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87375:
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	push	esi
	push	edi
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	and	ecx, 2048				; 00000800H
	test	cx, cx
	je	SHORT $L87380
	mov	ecx, DWORD PTR _regs[edx*4+32]
	mov	edi, DWORD PTR _areg_byteinc[edx*4]
	lea	esi, DWORD PTR _regs[edx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	sub	ecx, edi
	mov	eax, DWORD PTR _regs[eax*4]
	mov	DWORD PTR [esi], ecx
	mov	BYTE PTR [edx+ecx], al
	jmp	SHORT $L87389
$L87380:
	mov	ecx, DWORD PTR _regs[edx*4+32]
	mov	edi, DWORD PTR _areg_byteinc[edx*4]
	lea	esi, DWORD PTR _regs[edx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	sub	ecx, edi
	test	ah, -128				; ffffff80H
	mov	dl, BYTE PTR [edx+ecx]
	mov	DWORD PTR [esi], ecx
	je	SHORT $L87386
	sar	eax, 12					; 0000000cH
	movsx	ecx, dl
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	jmp	SHORT $L87389
$L87386:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	BYTE PTR _regs[eax*4], dl
$L87389:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e20_0@4 ENDP


@op_e28_0@4 PROC NEAR
	_start_func  'op_e28_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	mov	esi, ecx
	jne	SHORT $L87396
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87396:
	mov	edx, DWORD PTR _regs+92
	xor	ecx, ecx
	push	ebx
	mov	ax, WORD PTR [edx+2]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	and	ecx, 2048				; 00000800H
	test	cx, cx
	je	SHORT $L87401
	mov	dx, WORD PTR [edx+4]
	xor	ecx, ecx
	xor	ebx, ebx
	mov	cl, dh
	mov	bh, dl
	movsx	ecx, cx
	movsx	edx, bx
	sar	eax, 12					; 0000000cH
	or	ecx, edx
	mov	edx, DWORD PTR _regs[esi*4+32]
	and	eax, 15					; 0000000fH
	add	ecx, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR _regs[eax*4]
	mov	BYTE PTR [ecx+edx], al
	jmp	SHORT $L87416
$L87401:
	mov	dx, WORD PTR [edx+6]
	xor	ecx, ecx
	xor	ebx, ebx
	mov	cl, dh
	mov	bh, dl
	movsx	ecx, cx
	movsx	edx, bx
	mov	ebx, DWORD PTR _regs[esi*4+32]
	or	ecx, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, ebx
	test	ah, -128				; ffffff80H
	mov	cl, BYTE PTR [ecx+edx]
	je	SHORT $L87413
	sar	eax, 12					; 0000000cH
	movsx	ecx, cl
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	jmp	SHORT $L87416
$L87413:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	BYTE PTR _regs[eax*4], cl
$L87416:
	mov	eax, DWORD PTR _regs+92
	pop	ebx
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e28_0@4 ENDP


@op_e30_0@4 PROC NEAR
	_start_func  'op_e30_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	mov	edi, ecx
	test	al, al
	jne	SHORT $L87423
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87423:
	mov	eax, DWORD PTR _regs+92
	xor	edx, edx
	mov	cx, WORD PTR [eax+2]
	lea	ebp, DWORD PTR [eax+2]
	mov	dl, ch
	mov	dh, cl
	mov	esi, edx
	mov	ecx, esi
	and	ecx, 2048				; 00000800H
	test	cx, cx
	je	SHORT $L87428
	sar	esi, 12					; 0000000cH
	and	esi, 15					; 0000000fH
	push	ebx
	add	eax, 4
	mov	ebx, DWORD PTR _regs[esi*4]
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[edi*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR [ecx+eax], bl
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87428:
	mov	ax, WORD PTR [eax]
	mov	DWORD PTR _regs+92, ebp
	mov	ecx, DWORD PTR _regs[edi*4+32]
	mov	edi, eax
	and	edi, 0ff09H
	mov	edx, eax
	call	DWORD PTR _ea_020_table[edi*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	test	esi, 32768				; 00008000H
	mov	al, BYTE PTR [edx+eax]
	je	SHORT $L87434
	sar	esi, 12					; 0000000cH
	movsx	eax, al
	and	esi, 7
	mov	DWORD PTR _regs[esi*4+32], eax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87434:
	sar	esi, 12					; 0000000cH
	and	esi, 7
	mov	BYTE PTR _regs[esi*4], al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e30_0@4 ENDP


@op_e38_0@4 PROC NEAR
	_start_func  'op_e38_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L87443
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87443:
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	push	ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87448
	mov	cx, WORD PTR [ecx+4]
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	or	edx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	pop	ebx
	mov	eax, DWORD PTR _regs[eax*4]
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87448:
	mov	cx, WORD PTR [ecx+6]
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	test	ah, -128				; ffffff80H
	mov	cl, BYTE PTR [edx+ecx]
	je	SHORT $L87460
	sar	eax, 12					; 0000000cH
	movsx	edx, cl
	and	eax, 7
	pop	ebx
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87460:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	pop	ebx
	mov	BYTE PTR _regs[eax*4], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e38_0@4 ENDP


@op_e39_0@4 PROC NEAR
	_start_func  'op_e39_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L87469
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87469:
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87474
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	mov	eax, DWORD PTR _regs[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 12					; 0000000cH
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87474:
	mov	ecx, DWORD PTR [ecx+8]
	bswap	ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	test	ah, -128				; ffffff80H
	mov	cl, BYTE PTR [edx+ecx]
	je	SHORT $L87482
	sar	eax, 12					; 0000000cH
	movsx	ecx, cl
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 12					; 0000000cH
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87482:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	BYTE PTR _regs[eax*4], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 12					; 0000000cH
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e39_0@4 ENDP


@op_e50_0@4 PROC NEAR
	_start_func  'op_e50_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	jne	SHORT $L87492
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87492:
	mov	eax, DWORD PTR _regs+92
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87497
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	xor	edx, edx
	mov	eax, DWORD PTR _regs[eax*4]
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87497:
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	cx, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	test	ah, -128				; ffffff80H
	mov	ecx, edx
	je	SHORT $L87503
	sar	eax, 12					; 0000000cH
	movsx	ecx, cx
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87503:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	WORD PTR _regs[eax*4], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e50_0@4 ENDP


@op_e58_0@4 PROC NEAR
	_start_func  'op_e58_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	mov	esi, ecx
	jne	SHORT $L87513
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87513:
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	edx, eax
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87518
	mov	ecx, DWORD PTR _regs[esi*4+32]
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	lea	edx, DWORD PTR [ecx+2]
	mov	eax, DWORD PTR _regs[eax*4]
	mov	DWORD PTR _regs[esi*4+32], edx
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87518:
	mov	ecx, DWORD PTR _MEMBaseDiff
	push	edi
	mov	edi, DWORD PTR _regs[esi*4+32]
	xor	edx, edx
	mov	cx, WORD PTR [edi+ecx]
	add	edi, 2
	mov	dl, ch
	mov	DWORD PTR _regs[esi*4+32], edi
	mov	dh, cl
	pop	edi
	test	ah, -128				; ffffff80H
	mov	ecx, edx
	je	SHORT $L87524
	sar	eax, 12					; 0000000cH
	movsx	ecx, cx
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87524:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	WORD PTR _regs[eax*4], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e58_0@4 ENDP


@op_e60_0@4 PROC NEAR
	_start_func  'op_e60_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	mov	edi, ecx
	jne	SHORT $L87534
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87534:
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	edx, eax
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87539
	sar	eax, 12					; 0000000cH
	mov	ecx, DWORD PTR _regs[edi*4+32]
	and	eax, 15					; 0000000fH
	xor	edx, edx
	sub	ecx, 2
	mov	eax, DWORD PTR _regs[eax*4]
	mov	DWORD PTR _regs[edi*4+32], ecx
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87539:
	mov	ecx, DWORD PTR _MEMBaseDiff
	push	esi
	mov	esi, DWORD PTR _regs[edi*4+32]
	xor	edx, edx
	sub	esi, 2
	test	ah, -128				; ffffff80H
	mov	cx, WORD PTR [ecx+esi]
	mov	DWORD PTR _regs[edi*4+32], esi
	mov	dl, ch
	pop	esi
	mov	dh, cl
	mov	ecx, edx
	je	SHORT $L87545
	sar	eax, 12					; 0000000cH
	movsx	ecx, cx
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87545:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	WORD PTR _regs[eax*4], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e60_0@4 ENDP


@op_e68_0@4 PROC NEAR
	_start_func  'op_e68_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	mov	esi, ecx
	jne	SHORT $L87555
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87555:
	mov	edx, DWORD PTR _regs+92
	xor	ecx, ecx
	push	ebx
	mov	ax, WORD PTR [edx+2]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	and	ecx, 2048				; 00000800H
	test	cx, cx
	je	SHORT $L87560
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	mov	dx, WORD PTR [edx+4]
	xor	ecx, ecx
	xor	ebx, ebx
	mov	eax, DWORD PTR _regs[eax*4]
	mov	bh, dl
	mov	cl, ah
	mov	ch, al
	xor	eax, eax
	mov	al, dh
	movsx	eax, ax
	movsx	edx, bx
	or	eax, edx
	mov	edx, DWORD PTR _regs[esi*4+32]
	add	eax, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+edx], cx
	jmp	SHORT $L87575
$L87560:
	mov	dx, WORD PTR [edx+6]
	xor	ecx, ecx
	xor	ebx, ebx
	mov	cl, dh
	mov	bh, dl
	movsx	ecx, cx
	movsx	edx, bx
	mov	ebx, DWORD PTR _regs[esi*4+32]
	or	ecx, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, ebx
	mov	cx, WORD PTR [ecx+edx]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	test	ah, -128				; ffffff80H
	mov	ecx, edx
	je	SHORT $L87572
	sar	eax, 12					; 0000000cH
	movsx	ecx, cx
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	jmp	SHORT $L87575
$L87572:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	WORD PTR _regs[eax*4], cx
$L87575:
	mov	eax, DWORD PTR _regs+92
	pop	ebx
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e68_0@4 ENDP


@op_e70_0@4 PROC NEAR
	_start_func  'op_e70_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	mov	edi, ecx
	test	al, al
	jne	SHORT $L87582
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87582:
	mov	eax, DWORD PTR _regs+92
	xor	edx, edx
	mov	cx, WORD PTR [eax+2]
	lea	ebp, DWORD PTR [eax+2]
	mov	dl, ch
	mov	dh, cl
	mov	esi, edx
	mov	ecx, esi
	and	ecx, 2048				; 00000800H
	test	cx, cx
	je	SHORT $L87587
	sar	esi, 12					; 0000000cH
	and	esi, 15					; 0000000fH
	push	ebx
	add	eax, 4
	mov	ebx, DWORD PTR _regs[esi*4]
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[edi*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, bh
	mov	ch, bl
	pop	ebx
	mov	WORD PTR [edx+eax], cx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87587:
	mov	ax, WORD PTR [eax]
	mov	DWORD PTR _regs+92, ebp
	mov	ecx, DWORD PTR _regs[edi*4+32]
	mov	edi, eax
	and	edi, 0ff09H
	mov	edx, eax
	call	DWORD PTR _ea_020_table[edi*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	test	esi, 32768				; 00008000H
	mov	ax, WORD PTR [ecx+eax]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	je	SHORT $L87593
	sar	esi, 12					; 0000000cH
	movsx	eax, ax
	and	esi, 7
	mov	DWORD PTR _regs[esi*4+32], eax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87593:
	sar	esi, 12					; 0000000cH
	and	esi, 7
	mov	WORD PTR _regs[esi*4], ax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e70_0@4 ENDP


@op_e78_0@4 PROC NEAR
	_start_func  'op_e78_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L87602
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87602:
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	push	ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87607
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	mov	cx, WORD PTR [ecx+4]
	xor	edx, edx
	xor	ebx, ebx
	mov	eax, DWORD PTR _regs[eax*4]
	mov	bh, cl
	mov	dl, ah
	mov	dh, al
	xor	eax, eax
	mov	al, ch
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	pop	ebx
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87607:
	mov	cx, WORD PTR [ecx+6]
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	cx, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	test	ah, -128				; ffffff80H
	mov	ecx, edx
	je	SHORT $L87619
	sar	eax, 12					; 0000000cH
	movsx	ecx, cx
	and	eax, 7
	pop	ebx
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87619:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	pop	ebx
	mov	WORD PTR _regs[eax*4], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e78_0@4 ENDP


@op_e79_0@4 PROC NEAR
	_start_func  'op_e79_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L87628
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87628:
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87633
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	mov	eax, DWORD PTR _regs[eax*4]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 12					; 0000000cH
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87633:
	mov	ecx, DWORD PTR [ecx+8]
	bswap	ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	cx, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	test	ah, -128				; ffffff80H
	mov	ecx, edx
	je	SHORT $L87641
	sar	eax, 12					; 0000000cH
	movsx	ecx, cx
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 12					; 0000000cH
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87641:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	WORD PTR _regs[eax*4], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 12					; 0000000cH
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e79_0@4 ENDP


@op_e90_0@4 PROC NEAR
	_start_func  'op_e90_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	jne	SHORT $L87651
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87651:
	mov	eax, DWORD PTR _regs+92
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87656
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	add	ecx, edx
	mov	eax, DWORD PTR _regs[eax*4]
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87656:
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+edx]
	bswap	ecx
	test	ah, -128				; ffffff80H
	je	SHORT $L87662
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87662:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e90_0@4 ENDP


@op_e98_0@4 PROC NEAR
	_start_func  'op_e98_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	jne	SHORT $L87668
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87668:
	mov	eax, DWORD PTR _regs+92
	xor	edx, edx
	push	edi
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87673
	mov	edx, DWORD PTR _regs[ecx*4+32]
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	lea	edi, DWORD PTR [edx+4]
	mov	eax, DWORD PTR _regs[eax*4]
	mov	DWORD PTR _regs[ecx*4+32], edi
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	jmp	SHORT $L87680
$L87673:
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR [edx+edi]
	bswap	edx
	mov	edi, DWORD PTR _regs[ecx*4+32]
	add	edi, 4
	test	ah, -128				; ffffff80H
	mov	DWORD PTR _regs[ecx*4+32], edi
	je	SHORT $L87679
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], edx
	jmp	SHORT $L87680
$L87679:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4], edx
$L87680:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_e98_0@4 ENDP


@op_ea0_0@4 PROC NEAR
	_start_func  'op_ea0_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	mov	edx, ecx
	jne	SHORT $L87685
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87685:
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	push	esi
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	and	ecx, 2048				; 00000800H
	test	cx, cx
	je	SHORT $L87690
	mov	ecx, DWORD PTR _regs[edx*4+32]
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	sub	ecx, 4
	mov	eax, DWORD PTR _regs[eax*4]
	mov	DWORD PTR _regs[edx*4+32], ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	jmp	SHORT $L87697
$L87690:
	mov	ecx, DWORD PTR _regs[edx*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	sub	ecx, 4
	mov	esi, DWORD PTR [esi+ecx]
	bswap	esi
	test	ah, -128				; ffffff80H
	mov	DWORD PTR _regs[edx*4+32], ecx
	je	SHORT $L87696
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], esi
	jmp	SHORT $L87697
$L87696:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4], esi
$L87697:
	mov	eax, DWORD PTR _regs+92
	pop	esi
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ea0_0@4 ENDP


@op_ea8_0@4 PROC NEAR
	_start_func  'op_ea8_0'
	mov	al, BYTE PTR _regs+80
	push	esi
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	mov	esi, ecx
	jne	SHORT $L87702
	push	0
	push	8
	call	_Exception@8
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87702:
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	push	edi
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87707
	mov	dx, WORD PTR [ecx+4]
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	mov	edi, DWORD PTR _regs[eax*4]
	xor	eax, eax
	mov	al, dh
	movsx	ecx, ax
	xor	eax, eax
	mov	ah, dl
	movsx	edx, ax
	mov	eax, DWORD PTR _MEMBaseDiff
	or	ecx, edx
	add	ecx, DWORD PTR _regs[esi*4+32]
	add	ecx, eax
	bswap	edi
	mov	DWORD PTR [ecx], edi
	jmp	SHORT $L87720
$L87707:
	mov	cx, WORD PTR [ecx+6]
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	edi, DWORD PTR _regs[esi*4+32]
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, edi
	mov	ecx, DWORD PTR [edx+ecx]
	bswap	ecx
	test	ah, -128				; ffffff80H
	pop	ebx
	je	SHORT $L87719
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	jmp	SHORT $L87720
$L87719:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4], ecx
$L87720:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ea8_0@4 ENDP


@op_eb0_0@4 PROC NEAR
	_start_func  'op_eb0_0'
	mov	al, BYTE PTR _regs+80
	push	esi
	shr	ecx, 8
	and	ecx, 7
	push	edi
	test	al, al
	mov	edi, ecx
	jne	SHORT $L87725
	push	0
	push	8
	call	_Exception@8
	pop	edi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87725:
	mov	eax, DWORD PTR _regs+92
	push	ebx
	xor	ebx, ebx
	mov	dx, WORD PTR [eax+2]
	lea	ecx, DWORD PTR [eax+2]
	mov	bl, dh
	mov	bh, dl
	mov	esi, ebx
	pop	ebx
	mov	edx, esi
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87730
	sar	esi, 12					; 0000000cH
	and	esi, 15					; 0000000fH
	add	eax, 4
	mov	esi, DWORD PTR _regs[esi*4]
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[edi*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	edi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87730:
	mov	ax, WORD PTR [eax]
	mov	DWORD PTR _regs+92, ecx
	mov	ecx, DWORD PTR _regs[edi*4+32]
	mov	edi, eax
	and	edi, 0ff09H
	mov	edx, eax
	call	DWORD PTR _ea_020_table[edi*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	test	esi, 32768				; 00008000H
	je	SHORT $L87736
	sar	esi, 12					; 0000000cH
	and	esi, 7
	pop	edi
	mov	DWORD PTR _regs[esi*4+32], eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87736:
	sar	esi, 12					; 0000000cH
	and	esi, 7
	pop	edi
	mov	DWORD PTR _regs[esi*4], eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_eb0_0@4 ENDP


@op_eb8_0@4 PROC NEAR
	_start_func  'op_eb8_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L87741
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87741:
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87746
	mov	dx, WORD PTR [ecx+4]
	push	esi
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	mov	esi, DWORD PTR _regs[eax*4]
	xor	eax, eax
	mov	al, dh
	movsx	ecx, ax
	xor	eax, eax
	mov	ah, dl
	movsx	edx, ax
	mov	eax, DWORD PTR _MEMBaseDiff
	or	ecx, edx
	add	ecx, eax
	bswap	esi
	mov	DWORD PTR [ecx], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87746:
	mov	cx, WORD PTR [ecx+6]
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [edx+ecx]
	bswap	ecx
	test	ah, -128				; ffffff80H
	pop	ebx
	je	SHORT $L87758
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87758:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_eb8_0@4 ENDP


@op_eb9_0@4 PROC NEAR
	_start_func  'op_eb9_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L87763
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87763:
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	and	edx, 2048				; 00000800H
	test	dx, dx
	je	SHORT $L87768
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	sar	eax, 12					; 0000000cH
	and	eax, 15					; 0000000fH
	mov	eax, DWORD PTR _regs[eax*4]
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 12					; 0000000cH
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87768:
	mov	ecx, DWORD PTR [ecx+8]
	bswap	ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [edx+ecx]
	bswap	ecx
	test	ah, -128				; ffffff80H
	je	SHORT $L87776
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 12					; 0000000cH
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87776:
	sar	eax, 12					; 0000000cH
	and	eax, 7
	mov	DWORD PTR _regs[eax*4], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 12					; 0000000cH
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_eb9_0@4 ENDP


_rc$87787 = -12
_flgo$87793 = -8
_flgn$87795 = -4
@op_ed0_0@4 PROC NEAR
	_start_func  'op_ed0_0'
	mov	ebp, esp
	sub	esp, 12					; 0000000cH
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	push	ebx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	dh, al
	mov	eax, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	push	esi
	push	edi
	mov	edi, DWORD PTR [edx+ecx]
	bswap	edi
	movsx	eax, ax
	mov	esi, eax
	and	eax, 7
	sar	esi, 6
	mov	ebx, DWORD PTR _regs[eax*4]
	mov	edx, edi
	mov	DWORD PTR _rc$87787[ebp], eax
	and	esi, 7
	sub	edx, ebx
	xor	eax, eax
	test	edi, edi
	setl	al
	mov	DWORD PTR _flgo$87793[ebp], eax
	xor	eax, eax
	test	edx, edx
	setl	al
	test	edx, edx
	sete	BYTE PTR _regflags+1
	xor	edx, edx
	mov	DWORD PTR _flgn$87795[ebp], eax
	mov	eax, DWORD PTR _flgo$87793[ebp]
	test	ebx, ebx
	setl	dl
	cmp	edx, eax
	je	SHORT $L121212
	mov	edx, DWORD PTR _flgn$87795[ebp]
	mov	BYTE PTR _regflags+3, 1
	cmp	edx, eax
	jne	SHORT $L121213
$L121212:
	mov	BYTE PTR _regflags+3, 0
$L121213:
	mov	edx, DWORD PTR _flgn$87795[ebp]
	cmp	ebx, edi
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	al, BYTE PTR _regflags+1
	test	edx, edx
	setne	dl
	test	al, al
	mov	BYTE PTR _regflags, dl
	je	SHORT $L87800
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[esi*4]
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	jmp	SHORT $L121230
$L87800:
	mov	ecx, DWORD PTR _rc$87787[ebp]
	mov	DWORD PTR _regs[ecx*4], edi
$L121230:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ed0_0@4 ENDP


_rc$87811 = -12
_flgo$87817 = -8
_flgn$87819 = -4
@op_ed8_0@4 PROC NEAR
	_start_func  'op_ed8_0'
	mov	ebp, esp
	sub	esp, 12					; 0000000cH
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	push	ebx
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	dh, al
	mov	eax, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	push	esi
	push	edi
	mov	esi, DWORD PTR [edx+ebx]
	bswap	esi
	mov	edx, DWORD PTR _regs[ecx*4+32]
	movsx	eax, ax
	add	edx, 4
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	edx, eax
	and	eax, 7
	mov	ecx, esi
	sar	edx, 6
	mov	edi, DWORD PTR _regs[eax*4]
	mov	DWORD PTR _rc$87811[ebp], eax
	and	edx, 7
	sub	ecx, edi
	xor	eax, eax
	test	esi, esi
	setl	al
	mov	DWORD PTR _flgo$87817[ebp], eax
	xor	eax, eax
	test	ecx, ecx
	setl	al
	test	ecx, ecx
	sete	BYTE PTR _regflags+1
	xor	ecx, ecx
	mov	DWORD PTR _flgn$87819[ebp], eax
	mov	eax, DWORD PTR _flgo$87817[ebp]
	test	edi, edi
	setl	cl
	cmp	ecx, eax
	je	SHORT $L121233
	mov	ecx, DWORD PTR _flgn$87819[ebp]
	mov	BYTE PTR _regflags+3, 1
	cmp	ecx, eax
	jne	SHORT $L121234
$L121233:
	mov	BYTE PTR _regflags+3, 0
$L121234:
	mov	ecx, DWORD PTR _flgn$87819[ebp]
	cmp	edi, esi
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	al, BYTE PTR _regflags+1
	test	ecx, ecx
	setne	cl
	test	al, al
	mov	BYTE PTR _regflags, cl
	je	SHORT $L87824
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs[edx*4]
	add	eax, ebx
	bswap	edx
	mov	DWORD PTR [eax], edx
	jmp	SHORT $L121251
$L87824:
	mov	ecx, DWORD PTR _rc$87811[ebp]
	mov	DWORD PTR _regs[ecx*4], esi
$L121251:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ed8_0@4 ENDP


_rc$87835 = -12
_flgo$87841 = -8
_flgn$87843 = -4
@op_ee0_0@4 PROC NEAR
	_start_func  'op_ee0_0'
	mov	ebp, esp
	sub	esp, 12					; 0000000cH
	xor	edx, edx
	shr	ecx, 8
	mov	ax, WORD PTR [eax+2]
	and	ecx, 7
	mov	dl, ah
	push	ebx
	mov	dh, al
	mov	eax, DWORD PTR _regs[ecx*4+32]
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	sub	eax, 4
	push	edi
	mov	edi, DWORD PTR [esi+eax]
	bswap	edi
	mov	DWORD PTR _regs[ecx*4+32], eax
	movsx	ecx, dx
	mov	esi, ecx
	and	ecx, 7
	sar	esi, 6
	mov	ebx, DWORD PTR _regs[ecx*4]
	mov	edx, edi
	mov	DWORD PTR _rc$87835[ebp], ecx
	and	esi, 7
	sub	edx, ebx
	xor	ecx, ecx
	test	edi, edi
	setl	cl
	mov	DWORD PTR _flgo$87841[ebp], ecx
	xor	ecx, ecx
	test	edx, edx
	setl	cl
	test	edx, edx
	sete	BYTE PTR _regflags+1
	xor	edx, edx
	mov	DWORD PTR _flgn$87843[ebp], ecx
	mov	ecx, DWORD PTR _flgo$87841[ebp]
	test	ebx, ebx
	setl	dl
	cmp	edx, ecx
	je	SHORT $L121254
	mov	edx, DWORD PTR _flgn$87843[ebp]
	mov	BYTE PTR _regflags+3, 1
	cmp	edx, ecx
	jne	SHORT $L121255
$L121254:
	mov	BYTE PTR _regflags+3, 0
$L121255:
	mov	edx, DWORD PTR _flgn$87843[ebp]
	cmp	ebx, edi
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	cl, BYTE PTR _regflags+1
	test	edx, edx
	setne	dl
	test	cl, cl
	mov	BYTE PTR _regflags, dl
	je	SHORT $L87848
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[esi*4]
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	jmp	SHORT $L121272
$L87848:
	mov	edx, DWORD PTR _rc$87835[ebp]
	mov	DWORD PTR _regs[edx*4], edi
$L121272:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ee0_0@4 ENDP


_rc$87862 = -12
_flgo$87868 = -8
_flgn$87870 = -4
@op_ee8_0@4 PROC NEAR
	_start_func  'op_ee8_0'
	mov	ebp, esp
	sub	esp, 12					; 0000000cH
	push	ebx
	push	esi
	mov	esi, ecx
	xor	edx, edx
	mov	ecx, DWORD PTR _regs+92
	xor	ebx, ebx
	shr	esi, 8
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ah
	mov	bh, cl
	mov	dh, al
	xor	eax, eax
	mov	al, ch
	and	esi, 7
	movsx	eax, ax
	movsx	ecx, bx
	push	edi
	mov	edi, DWORD PTR _regs[esi*4+32]
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, edi
	mov	edi, DWORD PTR [ecx+eax]
	bswap	edi
	movsx	ecx, dx
	mov	esi, ecx
	and	ecx, 7
	sar	esi, 6
	mov	ebx, DWORD PTR _regs[ecx*4]
	mov	edx, edi
	mov	DWORD PTR _rc$87862[ebp], ecx
	and	esi, 7
	sub	edx, ebx
	xor	ecx, ecx
	test	edi, edi
	setl	cl
	mov	DWORD PTR _flgo$87868[ebp], ecx
	xor	ecx, ecx
	test	edx, edx
	setl	cl
	test	edx, edx
	sete	BYTE PTR _regflags+1
	xor	edx, edx
	mov	DWORD PTR _flgn$87870[ebp], ecx
	mov	ecx, DWORD PTR _flgo$87868[ebp]
	test	ebx, ebx
	setl	dl
	cmp	edx, ecx
	je	SHORT $L121275
	mov	edx, DWORD PTR _flgn$87870[ebp]
	mov	BYTE PTR _regflags+3, 1
	cmp	edx, ecx
	jne	SHORT $L121276
$L121275:
	mov	BYTE PTR _regflags+3, 0
$L121276:
	mov	edx, DWORD PTR _flgn$87870[ebp]
	cmp	ebx, edi
	seta	cl
	mov	BYTE PTR _regflags+2, cl
	mov	cl, BYTE PTR _regflags+1
	test	edx, edx
	setne	dl
	test	cl, cl
	mov	BYTE PTR _regflags, dl
	je	SHORT $L87875
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[esi*4]
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	jmp	SHORT $L121297
$L87875:
	mov	edx, DWORD PTR _rc$87862[ebp]
	mov	DWORD PTR _regs[edx*4], edi
$L121297:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ee8_0@4 ENDP


_dsta$87883 = -4
_rc$87886 = -8
@op_ef0_0@4 PROC NEAR
	_start_func  'op_ef0_0'
	mov	ebp, esp
	sub	esp, 8
	push	ebx
	push	esi
	mov	esi, DWORD PTR _regs+92
	xor	ebx, ebx
	shr	ecx, 8
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	bl, ah
	mov	DWORD PTR _regs+92, esi
	mov	dx, WORD PTR [esi]
	mov	bh, al
	add	esi, 2
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	push	edi
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _dsta$87883[ebp], eax
	mov	edi, DWORD PTR [ecx+eax]
	bswap	edi
	movsx	ecx, bx
	mov	esi, ecx
	and	ecx, 7
	sar	esi, 6
	mov	ebx, DWORD PTR _regs[ecx*4]
	mov	edx, edi
	mov	DWORD PTR _rc$87886[ebp], ecx
	and	esi, 7
	sub	edx, ebx
	xor	ecx, ecx
	test	edi, edi
	setl	cl
	xor	eax, eax
	test	edx, edx
	setl	al
	test	edx, edx
	sete	BYTE PTR _regflags+1
	xor	edx, edx
	test	ebx, ebx
	setl	dl
	cmp	edx, ecx
	je	SHORT $L121300
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, 1
	jne	SHORT $L121301
$L121300:
	mov	BYTE PTR _regflags+3, 0
$L121301:
	cmp	ebx, edi
	seta	cl
	test	eax, eax
	mov	al, BYTE PTR _regflags+1
	mov	BYTE PTR _regflags+2, cl
	setne	dl
	test	al, al
	mov	BYTE PTR _regflags, dl
	je	SHORT $L87899
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _dsta$87883[ebp]
	mov	esi, DWORD PTR _regs[esi*4]
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	edi
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L87899:
	mov	edx, DWORD PTR _rc$87886[ebp]
	mov	DWORD PTR _regs[edx*4], edi
	pop	edi
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ef0_0@4 ENDP


_rc$87912 = -12
_flgo$87918 = -8
_flgn$87920 = -4
@op_ef8_0@4 PROC NEAR
	_start_func  'op_ef8_0'
	mov	ebp, esp
	sub	esp, 12					; 0000000cH
	mov	ecx, eax
	xor	edx, edx
	push	ebx
	push	esi
	mov	ax, WORD PTR [ecx+2]
	push	edi
	mov	dl, ah
	mov	dh, al
	mov	ax, WORD PTR [ecx+4]
	xor	ecx, ecx
	mov	esi, edx
	mov	cl, ah
	movsx	edx, cx
	xor	ecx, ecx
	mov	ch, al
	movsx	eax, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	edi, DWORD PTR [ecx+edx]
	bswap	edi
	movsx	eax, si
	mov	esi, eax
	and	eax, 7
	sar	esi, 6
	mov	ebx, DWORD PTR _regs[eax*4]
	mov	ecx, edi
	mov	DWORD PTR _rc$87912[ebp], eax
	and	esi, 7
	sub	ecx, ebx
	xor	eax, eax
	test	edi, edi
	setl	al
	mov	DWORD PTR _flgo$87918[ebp], eax
	xor	eax, eax
	test	ecx, ecx
	setl	al
	test	ecx, ecx
	sete	BYTE PTR _regflags+1
	xor	ecx, ecx
	mov	DWORD PTR _flgn$87920[ebp], eax
	mov	eax, DWORD PTR _flgo$87918[ebp]
	test	ebx, ebx
	setl	cl
	cmp	ecx, eax
	je	SHORT $L121328
	mov	ecx, DWORD PTR _flgn$87920[ebp]
	mov	BYTE PTR _regflags+3, 1
	cmp	ecx, eax
	jne	SHORT $L121329
$L121328:
	mov	BYTE PTR _regflags+3, 0
$L121329:
	mov	ecx, DWORD PTR _flgn$87920[ebp]
	cmp	ebx, edi
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	al, BYTE PTR _regflags+1
	test	ecx, ecx
	setne	cl
	test	al, al
	mov	BYTE PTR _regflags, cl
	je	SHORT $L87925
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[esi*4]
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	jmp	SHORT $L121350
$L87925:
	mov	ecx, DWORD PTR _rc$87912[ebp]
	mov	DWORD PTR _regs[ecx*4], edi
$L121350:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ef8_0@4 ENDP


_rc$87936 = -12
_flgo$87942 = -8
_flgn$87944 = -4
@op_ef9_0@4 PROC NEAR
	_start_func  'op_ef9_0'
	mov	ebp, esp
	sub	esp, 12					; 0000000cH
	mov	ecx, eax
	xor	edx, edx
	push	ebx
	push	esi
	mov	ax, WORD PTR [ecx+2]
	mov	ebx, DWORD PTR [ecx+4]
	bswap	ebx
	mov	dl, ah
	push	edi
	mov	dh, al
	mov	eax, edx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [ecx+ebx]
	bswap	esi
	movsx	eax, ax
	mov	edx, eax
	and	eax, 7
	sar	edx, 6
	mov	edi, DWORD PTR _regs[eax*4]
	mov	ecx, esi
	mov	DWORD PTR _rc$87936[ebp], eax
	and	edx, 7
	sub	ecx, edi
	xor	eax, eax
	test	esi, esi
	setl	al
	mov	DWORD PTR _flgo$87942[ebp], eax
	xor	eax, eax
	test	ecx, ecx
	setl	al
	test	ecx, ecx
	sete	BYTE PTR _regflags+1
	xor	ecx, ecx
	mov	DWORD PTR _flgn$87944[ebp], eax
	mov	eax, DWORD PTR _flgo$87942[ebp]
	test	edi, edi
	setl	cl
	cmp	ecx, eax
	je	SHORT $L121353
	mov	ecx, DWORD PTR _flgn$87944[ebp]
	mov	BYTE PTR _regflags+3, 1
	cmp	ecx, eax
	jne	SHORT $L121354
$L121353:
	mov	BYTE PTR _regflags+3, 0
$L121354:
	mov	ecx, DWORD PTR _flgn$87944[ebp]
	cmp	edi, esi
	seta	al
	mov	BYTE PTR _regflags+2, al
	mov	al, BYTE PTR _regflags+1
	test	ecx, ecx
	setne	cl
	test	al, al
	mov	BYTE PTR _regflags, cl
	je	SHORT $L87949
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs[edx*4]
	add	eax, ebx
	bswap	edx
	mov	DWORD PTR [eax], edx
	jmp	SHORT $L121376
$L87949:
	mov	ecx, DWORD PTR _rc$87936[ebp]
	mov	DWORD PTR _regs[ecx*4], esi
$L121376:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_ef9_0@4 ENDP


_x$121397 = -4
_flgo$87965 = -12
_flgn$87967 = -8
_flgn$87980 = -8
@op_efc_0@4 PROC NEAR
	_start_func  'op_efc_0'
	mov	ebp, esp
	sub	esp, 12					; 0000000cH
	push	ebx
	push	esi
	push	edi
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, eax
	mov	esi, DWORD PTR _MEMBaseDiff
	sar	ecx, 28					; 0000001cH
	and	ecx, 15					; 0000000fH
	mov	edx, DWORD PTR _regs[ecx*4]
	mov	ecx, eax
	sar	ecx, 12					; 0000000cH
	mov	edi, DWORD PTR [esi+edx]
	bswap	edi
	and	ecx, 15					; 0000000fH
	mov	ecx, DWORD PTR _regs[ecx*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [esi+ecx]
	bswap	ecx
	mov	DWORD PTR _x$121397[ebp], ecx
	mov	ecx, eax
	xor	ebx, ebx
	sar	ecx, 16					; 00000010H
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4]
	mov	ecx, edi
	sub	ecx, esi
	test	edi, edi
	setl	bl
	mov	DWORD PTR _flgo$87965[ebp], ebx
	xor	ebx, ebx
	test	ecx, ecx
	setl	bl
	test	ecx, ecx
	mov	ecx, DWORD PTR _flgo$87965[ebp]
	mov	DWORD PTR _flgn$87967[ebp], ebx
	sete	BYTE PTR _regflags+1
	xor	ebx, ebx
	test	esi, esi
	setl	bl
	cmp	ebx, ecx
	je	SHORT $L121379
	mov	ebx, DWORD PTR _flgn$87967[ebp]
	mov	BYTE PTR _regflags+3, 1
	cmp	ebx, ecx
	jne	SHORT $L121380
$L121379:
	mov	BYTE PTR _regflags+3, 0
$L121380:
	cmp	esi, edi
	mov	esi, DWORD PTR _flgn$87967[ebp]
	seta	cl
	test	esi, esi
	mov	BYTE PTR _regflags+2, cl
	setne	cl
	mov	BYTE PTR _regflags, cl
	mov	cl, BYTE PTR _regflags+1
	test	cl, cl
	je	$L121409
	mov	ecx, eax
	xor	ebx, ebx
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4]
	mov	ecx, DWORD PTR _x$121397[ebp]
	mov	DWORD PTR -12+[ebp], esi
	sub	ecx, esi
	mov	esi, DWORD PTR _x$121397[ebp]
	test	esi, esi
	setl	bl
	mov	esi, ebx
	xor	ebx, ebx
	test	ecx, ecx
	setl	bl
	test	ecx, ecx
	mov	ecx, DWORD PTR -12+[ebp]
	mov	DWORD PTR _flgn$87980[ebp], ebx
	sete	BYTE PTR _regflags+1
	xor	ebx, ebx
	test	ecx, ecx
	setl	bl
	cmp	ebx, esi
	je	SHORT $L121381
	mov	ebx, DWORD PTR _flgn$87980[ebp]
	mov	BYTE PTR _regflags+3, 1
	cmp	ebx, esi
	jne	SHORT $L121382
$L121381:
	mov	BYTE PTR _regflags+3, 0
$L121382:
	mov	ebx, DWORD PTR _x$121397[ebp]
	mov	esi, DWORD PTR _flgn$87980[ebp]
	cmp	ecx, ebx
	seta	cl
	test	esi, esi
	mov	BYTE PTR _regflags+2, cl
	setne	cl
	mov	BYTE PTR _regflags, cl
	mov	cl, BYTE PTR _regflags+1
	test	cl, cl
	je	SHORT $L121409
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, eax
	sar	ecx, 22					; 00000016H
	and	ecx, 7
	add	esi, edx
	mov	ecx, DWORD PTR _regs[ecx*4]
	bswap	ecx
	mov	DWORD PTR [esi], ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, eax
	add	edx, esi
	sar	ecx, 6
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	bswap	ecx
	mov	DWORD PTR [edx], ecx
	mov	cl, BYTE PTR _regflags+1
	test	cl, cl
	jne	SHORT $L121410
$L121409:
	mov	ecx, DWORD PTR _x$121397[ebp]
	mov	edx, eax
	sar	edx, 22					; 00000016H
	sar	eax, 6
	and	edx, 7
	and	eax, 7
	mov	DWORD PTR _regs[edx*4], edi
	mov	DWORD PTR _regs[eax*4], ecx
$L121410:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_efc_0@4 ENDP


@op_10a0_0@4 PROC NEAR
	_start_func  'op_10a0_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	edi, DWORD PTR _areg_byteinc[eax*4]
	lea	esi, DWORD PTR _regs[eax*4+32]
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [edi+edx]
	mov	DWORD PTR [esi], edx
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [ecx+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10a0_0@4 ENDP


@op_10b0_0@4 PROC NEAR
	_start_func  'op_10b0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	esi, ecx
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	dl, dl
	mov	al, BYTE PTR [ecx+eax]
	mov	BYTE PTR _regflags+2, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	shr	esi, 1
	and	esi, 7
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _regs[esi*4+32]
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10b0_0@4 ENDP


@op_10b9_0@4 PROC NEAR
	_start_func  'op_10b9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	esi, DWORD PTR _MEMBaseDiff
	xor	dl, dl
	mov	al, BYTE PTR [esi+eax]
	mov	BYTE PTR _regflags+2, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [ecx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10b9_0@4 ENDP


@op_10ba_0@4 PROC NEAR
	_start_func  'op_10ba_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	edi, DWORD PTR _regs+96
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+88
	or	edx, eax
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	add	edx, edi
	add	edx, ebx
	mov	al, BYTE PTR [edx+esi+2]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [ecx+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10ba_0@4 ENDP


@op_10bb_0@4 PROC NEAR
	_start_func  'op_10bb_0'
	mov	ebx, DWORD PTR _regs+96
	mov	esi, ecx
	add	eax, 2
	mov	ecx, DWORD PTR _regs+88
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	sub	ecx, ebx
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	dl, dl
	mov	al, BYTE PTR [ecx+eax]
	mov	BYTE PTR _regflags+2, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	shr	esi, 1
	and	esi, 7
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _regs[esi*4+32]
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10bb_0@4 ENDP


@op_10e0_0@4 PROC NEAR
	_start_func  'op_10e0_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	edi, DWORD PTR _areg_byteinc[eax*4]
	lea	esi, DWORD PTR _regs[eax*4+32]
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	al, BYTE PTR [edi+edx]
	mov	DWORD PTR [esi], edx
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	add	ecx, esi
	mov	DWORD PTR [edx], ecx
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10e0_0@4 ENDP


@op_10f8_0@4 PROC NEAR
	_start_func  'op_10f8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	edi, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	or	edx, eax
	and	ecx, 7
	mov	al, BYTE PTR [edx+edi]
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	add	ecx, esi
	mov	DWORD PTR [edx], ecx
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10f8_0@4 ENDP


@op_10f9_0@4 PROC NEAR
	_start_func  'op_10f9_0'
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	al, BYTE PTR [edi+eax]
	add	ecx, esi
	mov	DWORD PTR [edx], ecx
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10f9_0@4 ENDP


@op_10fa_0@4 PROC NEAR
	_start_func  'op_10fa_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, edi
	shr	ecx, 1
	add	edx, eax
	and	ecx, 7
	mov	al, BYTE PTR [edx+esi+2]
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	add	ecx, esi
	mov	DWORD PTR [edx], ecx
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags+1, dl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10fa_0@4 ENDP


@op_10fb_0@4 PROC NEAR
	_start_func  'op_10fb_0'
	shr	ecx, 1
	and	ecx, 7
	mov	edi, DWORD PTR _regs+96
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edi
	mov	DWORD PTR _regs+92, eax
	add	ecx, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs[esi*4+32]
	lea	ecx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _areg_byteinc[esi*4]
	mov	al, BYTE PTR [edi+eax]
	add	esi, edx
	mov	DWORD PTR [ecx], esi
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+edx], al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_10fb_0@4 ENDP


@op_1110_0@4 PROC NEAR
	_start_func  'op_1110_0'
	mov	eax, ecx
	shr	ecx, 8
	shr	eax, 1
	and	ecx, 7
	and	eax, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ebx, DWORD PTR _areg_byteinc[eax*4]
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	dl, BYTE PTR [ecx+edi]
	xor	al, al
	mov	ecx, DWORD PTR [esi]
	mov	BYTE PTR _regflags+2, al
	sub	ecx, ebx
	cmp	dl, al
	sete	bl
	cmp	dl, al
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	DWORD PTR [esi], ecx
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR [edi+ecx], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1110_0@4 ENDP


@op_1118_0@4 PROC NEAR
	_start_func  'op_1118_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	edi, DWORD PTR [esi]
	shr	ecx, 1
	mov	dl, BYTE PTR [edi+ebp]
	and	ecx, 7
	add	eax, edi
	mov	ebx, DWORD PTR _areg_byteinc[ecx*4]
	mov	DWORD PTR [esi], eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	lea	esi, DWORD PTR _regs[ecx*4+32]
	xor	cl, cl
	sub	eax, ebx
	cmp	dl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	dl, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	DWORD PTR [esi], eax
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [eax+ebp], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1118_0@4 ENDP


@op_1139_0@4 PROC NEAR
	_start_func  'op_1139_0'
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ebx, DWORD PTR _areg_byteinc[ecx*4]
	lea	esi, DWORD PTR _regs[ecx*4+32]
	xor	cl, cl
	mov	dl, BYTE PTR [edi+eax]
	mov	BYTE PTR _regflags+2, cl
	mov	eax, DWORD PTR [esi]
	mov	BYTE PTR _regflags+3, cl
	sub	eax, ebx
	cmp	dl, cl
	sete	bl
	cmp	dl, cl
	mov	DWORD PTR [esi], eax
	setl	cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1139_0@4 ENDP


@op_113a_0@4 PROC NEAR
	_start_func  'op_113a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, edi
	shr	ecx, 1
	add	edx, eax
	and	ecx, 7
	mov	dl, BYTE PTR [edx+esi+2]
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ebx, DWORD PTR _areg_byteinc[ecx*4]
	lea	esi, DWORD PTR _regs[ecx*4+32]
	xor	cl, cl
	sub	eax, ebx
	cmp	dl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	dl, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	DWORD PTR [esi], eax
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+eax], dl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_113a_0@4 ENDP


@op_113b_0@4 PROC NEAR
	_start_func  'op_113b_0'
	shr	ecx, 1
	and	ecx, 7
	mov	edi, DWORD PTR _regs+96
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edi
	mov	DWORD PTR _regs+92, eax
	add	ecx, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ebx, DWORD PTR _areg_byteinc[esi*4]
	lea	edx, DWORD PTR _regs[esi*4+32]
	mov	cl, BYTE PTR [edi+eax]
	mov	eax, DWORD PTR [edx]
	sub	eax, ebx
	mov	DWORD PTR [edx], eax
	xor	dl, dl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+eax], cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_113b_0@4 ENDP


@op_1160_0@4 PROC NEAR
	_start_func  'op_1160_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	xor	bl, bl
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	edi, DWORD PTR _areg_byteinc[eax*4]
	lea	esi, DWORD PTR _regs[eax*4+32]
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [edi+edx]
	mov	DWORD PTR [esi], edx
	mov	edx, DWORD PTR _regs+92
	cmp	al, bl
	mov	dx, WORD PTR [edx+2]
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+3, bl
	sete	bl
	test	al, al
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	mov	BYTE PTR _regflags, bl
	xor	ebx, ebx
	mov	bl, dh
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 1
	and	ecx, 7
	or	esi, edx
	add	esi, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [esi+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1160_0@4 ENDP


@op_1179_0@4 PROC NEAR
	_start_func  'op_1179_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs+92
	xor	bl, bl
	mov	al, BYTE PTR [esi+eax]
	mov	dx, WORD PTR [edx+6]
	cmp	al, bl
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+3, bl
	sete	bl
	test	al, al
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	mov	BYTE PTR _regflags, bl
	xor	ebx, ebx
	mov	bl, dh
	movsx	edi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 1
	and	ecx, 7
	or	edi, edx
	add	edi, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1179_0@4 ENDP


@op_117a_0@4 PROC NEAR
	_start_func  'op_117a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	edi, DWORD PTR _regs+96
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+88
	or	edx, eax
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	add	edx, edi
	add	edx, ebx
	xor	bl, bl
	mov	al, BYTE PTR [edx+esi+2]
	mov	dx, WORD PTR [esi+4]
	cmp	al, bl
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+3, bl
	sete	bl
	test	al, al
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	mov	BYTE PTR _regflags, bl
	xor	ebx, ebx
	mov	bl, dh
	movsx	esi, bx
	xor	ebx, ebx
	mov	bh, dl
	movsx	edx, bx
	shr	ecx, 1
	and	ecx, 7
	or	esi, edx
	add	esi, DWORD PTR _regs[ecx*4+32]
	mov	BYTE PTR [esi+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_117a_0@4 ENDP


@op_117b_0@4 PROC NEAR
	_start_func  'op_117b_0'
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	mov	edi, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edi
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs+92
	xor	dl, dl
	mov	al, BYTE PTR [edi+eax]
	mov	cx, WORD PTR [ecx]
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	edx, ecx
	add	edx, DWORD PTR _regs[esi*4+32]
	mov	BYTE PTR [edx+edi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_117b_0@4 ENDP


@op_1190_0@4 PROC NEAR
	_start_func  'op_1190_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	bl, BYTE PTR [edx+eax]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	cl, cl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1190_0@4 ENDP


@op_1198_0@4 PROC NEAR
	_start_func  'op_1198_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[eax*4+32]
	lea	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	bl, BYTE PTR [esi+edi]
	add	eax, esi
	mov	DWORD PTR [edx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 1
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	cl, cl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_1198_0@4 ENDP


@op_11a0_0@4 PROC NEAR
	_start_func  'op_11a0_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	ebx, DWORD PTR _areg_byteinc[eax*4]
	lea	esi, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	and	ecx, 7
	mov	bl, BYTE PTR [eax+edx]
	mov	DWORD PTR [esi], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	cl, cl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11a0_0@4 ENDP


@op_11b8_0@4 PROC NEAR
	_start_func  'op_11b8_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	bl, BYTE PTR [edx+eax]
	mov	DWORD PTR _regs+92, esi
	mov	dx, WORD PTR [esi]
	add	esi, 2
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	xor	cl, cl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11b8_0@4 ENDP


@op_11b9_0@4 PROC NEAR
	_start_func  'op_11b9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	bl, BYTE PTR [edx+eax]
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	cl, cl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11b9_0@4 ENDP


@op_11ba_0@4 PROC NEAR
	_start_func  'op_11ba_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	shr	ecx, 1
	mov	bl, BYTE PTR [edx+esi-2]
	mov	DWORD PTR _regs+92, esi
	mov	dx, WORD PTR [esi]
	add	esi, 2
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	xor	cl, cl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11ba_0@4 ENDP


@op_11bb_0@4 PROC NEAR
	_start_func  'op_11bb_0'
	mov	edx, DWORD PTR _regs+96
	mov	esi, ecx
	add	eax, 2
	mov	ecx, DWORD PTR _regs+88
	mov	DWORD PTR _regs+92, eax
	sub	ecx, edx
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	shr	esi, 1
	mov	bl, BYTE PTR [ecx+eax]
	mov	eax, DWORD PTR _regs+92
	and	esi, 7
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[esi*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	cl, cl
	cmp	bl, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bl, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], bl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11bb_0@4 ENDP


@op_11e0_0@4 PROC NEAR
	_start_func  'op_11e0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	sub	eax, esi
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [esi+eax]
	mov	DWORD PTR [edx], eax
	mov	eax, DWORD PTR _regs+92
	xor	dl, dl
	cmp	cl, dl
	mov	ax, WORD PTR [eax+2]
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	BYTE PTR [edx+esi], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11e0_0@4 ENDP


@op_11f0_0@4 PROC NEAR
	_start_func  'op_11f0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs+92
	xor	dl, dl
	mov	al, BYTE PTR [esi+eax]
	mov	cx, WORD PTR [ecx]
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	BYTE PTR [edx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11f0_0@4 ENDP


@op_11f8_0@4 PROC NEAR
	_start_func  'op_11f8_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	bh, al
	mov	cx, WORD PTR [ecx+4]
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	al, BYTE PTR [edx+esi]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	BYTE PTR [edx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11f8_0@4 ENDP


@op_11f9_0@4 PROC NEAR
	_start_func  'op_11f9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs+92
	xor	dl, dl
	mov	al, BYTE PTR [esi+eax]
	mov	cx, WORD PTR [ecx+6]
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	BYTE PTR [edx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11f9_0@4 ENDP


@op_11fa_0@4 PROC NEAR
	_start_func  'op_11fa_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, DWORD PTR _MEMBaseDiff
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, esi
	add	edx, eax
	mov	al, BYTE PTR [edx+ecx+2]
	mov	cx, WORD PTR [ecx+4]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	BYTE PTR [edx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11fa_0@4 ENDP


@op_11fb_0@4 PROC NEAR
	_start_func  'op_11fb_0'
	mov	ecx, DWORD PTR _regs+88
	mov	esi, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, esi
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs+92
	xor	dl, dl
	mov	al, BYTE PTR [esi+eax]
	mov	cx, WORD PTR [ecx]
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	BYTE PTR [edx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11fb_0@4 ENDP


@op_11fc_0@4 PROC NEAR
	_start_func  'op_11fc_0'
	mov	ecx, eax
	xor	dl, dl
	mov	al, BYTE PTR [ecx+3]
	mov	cx, WORD PTR [ecx+4]
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_11fc_0@4 ENDP


@op_13c0_0@4 PROC NEAR
	_start_func  'op_13c0_0'
	shr	ecx, 8
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	cl, BYTE PTR _regs[ecx*4]
	xor	dl, dl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13c0_0@4 ENDP


@op_13d0_0@4 PROC NEAR
	_start_func  'op_13d0_0'
	mov	edx, eax
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [eax+ecx]
	mov	ecx, DWORD PTR [edx+2]
	bswap	ecx
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13d0_0@4 ENDP


@op_13d8_0@4 PROC NEAR
	_start_func  'op_13d8_0'
	shr	ecx, 8
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	al, BYTE PTR [esi+eax]
	add	ecx, esi
	mov	DWORD PTR [edx], ecx
	mov	edx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [edx+2]
	bswap	ecx
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13d8_0@4 ENDP


@op_13e0_0@4 PROC NEAR
	_start_func  'op_13e0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ebx, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	eax, ebx
	mov	cl, BYTE PTR [ecx+eax]
	mov	DWORD PTR [edx], eax
	mov	edx, DWORD PTR _regs+92
	mov	eax, DWORD PTR [edx+2]
	bswap	eax
	xor	dl, dl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13e0_0@4 ENDP


@op_13e8_0@4 PROC NEAR
	_start_func  'op_13e8_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	esi, DWORD PTR [esi+4]
	bswap	esi
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	mov	al, BYTE PTR [edx+ecx]
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13e8_0@4 ENDP


@op_13f0_0@4 PROC NEAR
	_start_func  'op_13f0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs+92
	mov	al, BYTE PTR [ecx+eax]
	mov	ecx, DWORD PTR [edx]
	bswap	ecx
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13f0_0@4 ENDP


@op_13f8_0@4 PROC NEAR
	_start_func  'op_13f8_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [edx+eax]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13f8_0@4 ENDP


@op_13f9_0@4 PROC NEAR
	_start_func  'op_13f9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs+92
	mov	al, BYTE PTR [ecx+eax]
	mov	ecx, DWORD PTR [edx+6]
	bswap	ecx
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 10					; 0000000aH
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13f9_0@4 ENDP


@op_13fa_0@4 PROC NEAR
	_start_func  'op_13fa_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	mov	al, BYTE PTR [edx+ecx+2]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13fa_0@4 ENDP


@op_13fb_0@4 PROC NEAR
	_start_func  'op_13fb_0'
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs+92
	mov	al, BYTE PTR [ecx+eax]
	mov	ecx, DWORD PTR [edx]
	bswap	ecx
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13fb_0@4 ENDP


@op_13fc_0@4 PROC NEAR
	_start_func  'op_13fc_0'
	mov	ecx, eax
	mov	al, BYTE PTR [ecx+3]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR [edx+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_13fc_0@4 ENDP


@op_2039_0@4 PROC NEAR
	_start_func  'op_2039_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2039_0@4 ENDP


@op_2079_0@4 PROC NEAR
	_start_func  'op_2079_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	shr	ecx, 1
	and	ecx, 7
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2079_0@4 ENDP


@op_20b9_0@4 PROC NEAR
	_start_func  'op_20b9_0'
	push	ebx
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20b9_0@4 ENDP


@op_20ba_0@4 PROC NEAR
	_start_func  'op_20ba_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR _regs+92
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, ebx
	add	edx, eax
	mov	eax, DWORD PTR [edx+esi+2]
	bswap	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20ba_0@4 ENDP


@op_20bb_0@4 PROC NEAR
	_start_func  'op_20bb_0'
	mov	edx, DWORD PTR _regs+96
	push	esi
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	shr	esi, 1
	and	esi, 7
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, dl
	mov	esi, DWORD PTR _regs[esi*4+32]
	add	esi, ecx
	bswap	eax
	mov	DWORD PTR [esi], eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20bb_0@4 ENDP


@op_20f9_0@4 PROC NEAR
	_start_func  'op_20f9_0'
	push	ebx
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	push	esi
	and	ecx, 7
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	mov	edx, DWORD PTR _regs[ecx*4+32]
	lea	esi, DWORD PTR [edx+4]
	mov	DWORD PTR _regs[ecx*4+32], esi
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20f9_0@4 ENDP


@op_20fa_0@4 PROC NEAR
	_start_func  'op_20fa_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR _regs+92
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, ebx
	add	edx, eax
	shr	ecx, 1
	mov	eax, DWORD PTR [edx+esi+2]
	bswap	eax
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	lea	esi, DWORD PTR [edx+4]
	mov	DWORD PTR _regs[ecx*4+32], esi
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_20fa_0@4 ENDP


@op_2139_0@4 PROC NEAR
	_start_func  'op_2139_0'
	push	ebx
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	ecx, ecx
	cmp	edx, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	edx, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2139_0@4 ENDP


@op_213b_0@4 PROC NEAR
	_start_func  'op_213b_0'
	mov	edx, DWORD PTR _regs+96
	shr	ecx, 1
	push	ebx
	and	ecx, 7
	push	esi
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	mov	eax, DWORD PTR _regs[esi*4+32]
	xor	edx, edx
	sub	eax, 4
	cmp	ecx, edx
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	DWORD PTR _regs[esi*4+32], eax
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_213b_0@4 ENDP


@op_2179_0@4 PROC NEAR
	_start_func  'op_2179_0'
	push	esi
	push	edi
	mov	esi, ecx
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR [ecx+eax]
	bswap	edi
	mov	edx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	edi, eax
	mov	cx, WORD PTR [edx+6]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	edi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 1
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_2179_0@4 ENDP


@op_217b_0@4 PROC NEAR
	_start_func  'op_217b_0'
	push	esi
	mov	esi, ecx
	push	edi
	mov	ecx, DWORD PTR _regs+88
	mov	edi, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edi
	mov	DWORD PTR _regs+92, eax
	add	ecx, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR [ecx+eax]
	bswap	edi
	mov	edx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	edi, eax
	mov	cx, WORD PTR [edx]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	edi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 1
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, DWORD PTR _regs[esi*4+32]
	add	eax, ecx
	bswap	edi
	mov	DWORD PTR [eax], edi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_217b_0@4 ENDP


@op_21a0_0@4 PROC NEAR
	_start_func  'op_21a0_0'
	mov	eax, ecx
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	mov	edx, DWORD PTR _regs[eax*4+32]
	sub	edx, 4
	mov	esi, DWORD PTR [esi+edx]
	bswap	esi
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 1
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21a0_0@4 ENDP


@op_21b9_0@4 PROC NEAR
	_start_func  'op_21b9_0'
	push	esi
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [edx+eax]
	bswap	esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 1
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21b9_0@4 ENDP


@op_21ba_0@4 PROC NEAR
	_start_func  'op_21ba_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR _regs+92
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	mov	esi, DWORD PTR [edx+esi+2]
	bswap	esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 1
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21ba_0@4 ENDP


@op_21bb_0@4 PROC NEAR
	_start_func  'op_21bb_0'
	push	esi
	mov	esi, ecx
	push	edi
	mov	ecx, DWORD PTR _regs+88
	mov	edi, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edi
	mov	DWORD PTR _regs+92, eax
	add	ecx, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR [ecx+eax]
	bswap	edi
	mov	eax, DWORD PTR _regs+92
	shr	esi, 1
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	and	esi, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	edi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	edi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	edi
	mov	DWORD PTR [eax], edi
	pop	edi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21bb_0@4 ENDP


@op_21bc_0@4 PROC NEAR
	_start_func  'op_21bc_0'
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 1
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	esi, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	esi, ecx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21bc_0@4 ENDP


@op_21e0_0@4 PROC NEAR
	_start_func  'op_21e0_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	push	esi
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	esi, DWORD PTR [edx+eax]
	bswap	esi
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	eax, DWORD PTR _regs+92
	mov	cx, WORD PTR [eax+2]
	xor	eax, eax
	cmp	esi, eax
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21e0_0@4 ENDP


@op_21f0_0@4 PROC NEAR
	_start_func  'op_21f0_0'
	push	esi
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [ecx+eax]
	bswap	esi
	mov	edx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	esi, eax
	mov	cx, WORD PTR [edx]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21f0_0@4 ENDP


@op_21f8_0@4 PROC NEAR
	_start_func  'op_21f8_0'
	xor	ecx, ecx
	push	esi
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	movsx	edx, cx
	xor	ecx, ecx
	mov	ch, al
	movsx	eax, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	esi, DWORD PTR [edx+ecx]
	bswap	esi
	mov	edx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	esi, eax
	mov	cx, WORD PTR [edx+4]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21f8_0@4 ENDP


@op_21f9_0@4 PROC NEAR
	_start_func  'op_21f9_0'
	push	esi
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [ecx+eax]
	bswap	esi
	mov	edx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	esi, eax
	mov	cx, WORD PTR [edx+6]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21f9_0@4 ENDP


@op_21fa_0@4 PROC NEAR
	_start_func  'op_21fa_0'
	mov	ecx, eax
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	push	esi
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs+88
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	add	edx, ebx
	add	edx, esi
	mov	esi, DWORD PTR [edx+ecx+2]
	bswap	esi
	mov	ecx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	esi, eax
	mov	cx, WORD PTR [ecx+4]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21fa_0@4 ENDP


@op_21fb_0@4 PROC NEAR
	_start_func  'op_21fb_0'
	mov	ecx, DWORD PTR _regs+88
	push	esi
	mov	esi, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, esi
	mov	DWORD PTR _regs+92, eax
	add	ecx, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [ecx+eax]
	bswap	esi
	mov	edx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	esi, eax
	mov	cx, WORD PTR [edx]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21fb_0@4 ENDP


@op_21fc_0@4 PROC NEAR
	_start_func  'op_21fc_0'
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	ecx, DWORD PTR _regs+92
	xor	eax, eax
	cmp	esi, eax
	mov	cx, WORD PTR [ecx+6]
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	esi, eax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_21fc_0@4 ENDP


@op_23c0_0@4 PROC NEAR
	_start_func  'op_23c0_0'
	push	ebx
	shr	ecx, 8
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	xor	edx, edx
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23c0_0@4 ENDP


@op_23c8_0@4 PROC NEAR
	_start_func  'op_23c8_0'
	push	ebx
	shr	ecx, 8
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	xor	edx, edx
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23c8_0@4 ENDP


@op_23d0_0@4 PROC NEAR
	_start_func  'op_23d0_0'
	shr	ecx, 8
	and	ecx, 7
	push	ebx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [eax+ecx]
	bswap	eax
	mov	edx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [edx+2]
	bswap	ecx
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23d0_0@4 ENDP


@op_23d8_0@4 PROC NEAR
	_start_func  'op_23d8_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	push	ebx
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR [eax+edx]
	bswap	eax
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	add	ebx, 4
	mov	DWORD PTR _regs[ecx*4+32], ebx
	mov	ecx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [ecx+2]
	bswap	ecx
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23d8_0@4 ENDP


@op_23e0_0@4 PROC NEAR
	_start_func  'op_23e0_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	push	ebx
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	eax, DWORD PTR _regs+92
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	xor	ecx, ecx
	cmp	edx, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	edx, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23e0_0@4 ENDP


@op_23e8_0@4 PROC NEAR
	_start_func  'op_23e8_0'
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	mov	edx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [edx+4]
	bswap	ecx
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23e8_0@4 ENDP


@op_23f0_0@4 PROC NEAR
	_start_func  'op_23f0_0'
	push	ebx
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	mov	edx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [edx]
	bswap	ecx
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23f0_0@4 ENDP


@op_23f8_0@4 PROC NEAR
	_start_func  'op_23f8_0'
	xor	ecx, ecx
	push	ebx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	movsx	edx, cx
	xor	ecx, ecx
	mov	ch, al
	movsx	eax, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	mov	edx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [edx+4]
	bswap	ecx
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23f8_0@4 ENDP


@op_23f9_0@4 PROC NEAR
	_start_func  'op_23f9_0'
	push	ebx
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	mov	edx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [edx+6]
	bswap	ecx
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 10					; 0000000aH
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23f9_0@4 ENDP


@op_23fa_0@4 PROC NEAR
	_start_func  'op_23fa_0'
	mov	ecx, eax
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	mov	eax, DWORD PTR [edx+ecx+2]
	bswap	eax
	mov	ecx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23fa_0@4 ENDP


@op_23fb_0@4 PROC NEAR
	_start_func  'op_23fb_0'
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	push	ebx
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	mov	edx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [edx]
	bswap	ecx
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23fb_0@4 ENDP


@op_23fc_0@4 PROC NEAR
	_start_func  'op_23fc_0'
	push	ebx
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _regs+92
	mov	ecx, DWORD PTR [ecx+6]
	bswap	ecx
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 10					; 0000000aH
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_23fc_0@4 ENDP


@op_3039_0@4 PROC NEAR
	_start_func  'op_3039_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	WORD PTR _regs[ecx*4], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3039_0@4 ENDP


@op_303a_0@4 PROC NEAR
	_start_func  'op_303a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	mov	ax, WORD PTR [edx+esi+2]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	shr	ecx, 1
	and	ecx, 7
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	WORD PTR _regs[ecx*4], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_303a_0@4 ENDP


@op_3060_0@4 PROC NEAR
	_start_func  'op_3060_0'
	mov	eax, ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	xor	ebx, ebx
	mov	esi, DWORD PTR _regs[eax*4+32]
	sub	esi, 2
	shr	ecx, 1
	mov	dx, WORD PTR [edx+esi]
	mov	DWORD PTR _regs[eax*4+32], esi
	xor	eax, eax
	mov	bh, dl
	mov	al, dh
	and	ecx, 7
	movsx	eax, ax
	movsx	edx, bx
	or	eax, edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3060_0@4 ENDP


@op_3070_0@4 PROC NEAR
	_start_func  'op_3070_0'
	add	eax, 2
	mov	esi, ecx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	shr	esi, 1
	mov	ax, WORD PTR [ecx+eax]
	and	esi, 7
	mov	dl, ah
	movsx	ecx, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	or	ecx, eax
	mov	DWORD PTR _regs[esi*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3070_0@4 ENDP


@op_3079_0@4 PROC NEAR
	_start_func  'op_3079_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	shr	ecx, 1
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3079_0@4 ENDP


@op_307a_0@4 PROC NEAR
	_start_func  'op_307a_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	xor	ebx, ebx
	shr	ecx, 1
	mov	ax, WORD PTR [edx+esi+2]
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_307a_0@4 ENDP


@op_307b_0@4 PROC NEAR
	_start_func  'op_307b_0'
	mov	edx, DWORD PTR _regs+96
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	shr	esi, 1
	mov	ax, WORD PTR [ecx+eax]
	and	esi, 7
	mov	dl, ah
	movsx	ecx, dx
	xor	edx, edx
	mov	dh, al
	movsx	eax, dx
	or	ecx, eax
	mov	DWORD PTR _regs[esi*4+32], ecx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_307b_0@4 ENDP


@op_30a0_0@4 PROC NEAR
	_start_func  'op_30a0_0'
	mov	esi, ecx
	mov	ebp, DWORD PTR _MEMBaseDiff
	shr	esi, 8
	and	esi, 7
	xor	edx, edx
	mov	edi, DWORD PTR _regs[esi*4+32]
	sub	edi, 2
	mov	ax, WORD PTR [edi+ebp]
	mov	DWORD PTR _regs[esi*4+32], edi
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	ecx, 1
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	BYTE PTR _regflags+1, bl
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	WORD PTR [eax+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30a0_0@4 ENDP


@op_30b9_0@4 PROC NEAR
	_start_func  'op_30b9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	esi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [esi+eax]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	ecx, 1
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	BYTE PTR _regflags+1, bl
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30b9_0@4 ENDP


@op_30ba_0@4 PROC NEAR
	_start_func  'op_30ba_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, edi
	add	edx, eax
	mov	ax, WORD PTR [edx+esi+2]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	ecx, 1
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	BYTE PTR _regflags+1, bl
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30ba_0@4 ENDP


@op_30bb_0@4 PROC NEAR
	_start_func  'op_30bb_0'
	mov	ebx, DWORD PTR _regs+96
	mov	esi, ecx
	add	eax, 2
	mov	ecx, DWORD PTR _regs+88
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	sub	ecx, ebx
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	shr	esi, 1
	mov	dl, ah
	and	esi, 7
	mov	dh, al
	mov	BYTE PTR _regflags+1, bl
	mov	eax, DWORD PTR _regs[esi*4+32]
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30bb_0@4 ENDP


@op_30c8_0@4 PROC NEAR
	_start_func  'op_30c8_0'
	mov	eax, ecx
	shr	eax, 1
	and	eax, 7
	shr	ecx, 8
	mov	edx, DWORD PTR _regs[eax*4+32]
	and	ecx, 7
	mov	cx, WORD PTR _regs[ecx*4+32]
	lea	esi, DWORD PTR [edx+2]
	mov	DWORD PTR _regs[eax*4+32], esi
	xor	eax, eax
	cmp	cx, ax
	mov	BYTE PTR _regflags+2, al
	sete	bl
	cmp	cx, ax
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags, al
	xor	eax, eax
	mov	al, ch
	mov	BYTE PTR _regflags+1, bl
	mov	ah, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+edx], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30c8_0@4 ENDP


@op_30f9_0@4 PROC NEAR
	_start_func  'op_30f9_0'
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [esi+eax]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	lea	edi, DWORD PTR [edx+2]
	mov	DWORD PTR _regs[ecx*4+32], edi
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	ch, al
	mov	WORD PTR [esi+edx], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30f9_0@4 ENDP


@op_30fa_0@4 PROC NEAR
	_start_func  'op_30fa_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, edi
	add	edx, eax
	shr	ecx, 1
	mov	ax, WORD PTR [edx+esi+2]
	xor	edx, edx
	mov	dl, ah
	and	ecx, 7
	mov	dh, al
	mov	eax, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	lea	esi, DWORD PTR [edx+2]
	mov	DWORD PTR _regs[ecx*4+32], esi
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	ch, al
	mov	WORD PTR [edi+edx], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30fa_0@4 ENDP


@op_30fb_0@4 PROC NEAR
	_start_func  'op_30fb_0'
	shr	ecx, 1
	and	ecx, 7
	mov	edi, DWORD PTR _regs+96
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	add	eax, 2
	sub	ecx, edi
	mov	DWORD PTR _regs+92, eax
	add	ecx, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	ax, WORD PTR [edi+eax]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	ecx, DWORD PTR _regs[esi*4+32]
	lea	edx, DWORD PTR [ecx+2]
	mov	DWORD PTR _regs[esi*4+32], edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	WORD PTR [edi+ecx], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_30fb_0@4 ENDP


@op_3139_0@4 PROC NEAR
	_start_func  'op_3139_0'
	shr	ecx, 1
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [esi+eax]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	mov	edx, DWORD PTR _regs[ecx*4+32]
	sub	edx, 2
	mov	DWORD PTR _regs[ecx*4+32], edx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	ch, al
	mov	WORD PTR [esi+edx], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3139_0@4 ENDP


@op_3160_0@4 PROC NEAR
	_start_func  'op_3160_0'
	mov	esi, ecx
	mov	eax, esi
	mov	ebp, DWORD PTR _MEMBaseDiff
	shr	eax, 8
	and	eax, 7
	xor	edx, edx
	mov	edi, DWORD PTR _regs[eax*4+32]
	sub	edi, 2
	mov	cx, WORD PTR [edi+ebp]
	mov	DWORD PTR _regs[eax*4+32], edi
	mov	eax, DWORD PTR _regs+92
	mov	dl, ch
	mov	dh, cl
	mov	ax, WORD PTR [eax+2]
	mov	ecx, edx
	xor	edx, edx
	cmp	cx, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ch
	mov	BYTE PTR _regflags+1, bl
	mov	dh, cl
	xor	ecx, ecx
	xor	ebx, ebx
	mov	cl, ah
	mov	bh, al
	shr	esi, 1
	movsx	ecx, cx
	movsx	eax, bx
	and	esi, 7
	or	ecx, eax
	mov	edi, DWORD PTR _regs[esi*4+32]
	add	ecx, edi
	mov	WORD PTR [ecx+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3160_0@4 ENDP


@op_3179_0@4 PROC NEAR
	_start_func  'op_3179_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	esi, ecx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [edi+eax]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	cx, WORD PTR [edx+6]
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	eax, ecx
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3179_0@4 ENDP


@op_317b_0@4 PROC NEAR
	_start_func  'op_317b_0'
	mov	esi, ecx
	mov	ecx, DWORD PTR _regs+88
	mov	edi, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edi
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [edi+eax]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	cx, WORD PTR [edx]
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	eax, ecx
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	WORD PTR [eax+edi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_317b_0@4 ENDP


@op_3188_0@4 PROC NEAR
	_start_func  'op_3188_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	shr	ecx, 1
	mov	bx, WORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	and	ecx, 7
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3188_0@4 ENDP


@op_3190_0@4 PROC NEAR
	_start_func  'op_3190_0'
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	xor	ebx, ebx
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	mov	ax, WORD PTR [edx+eax]
	mov	bl, ah
	mov	bh, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_3190_0@4 ENDP


@op_31a0_0@4 PROC NEAR
	_start_func  'op_31a0_0'
	mov	esi, ecx
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	esi, 8
	and	esi, 7
	xor	ebx, ebx
	mov	edi, DWORD PTR _regs[esi*4+32]
	sub	edi, 2
	shr	ecx, 1
	mov	ax, WORD PTR [eax+edi]
	mov	DWORD PTR _regs[esi*4+32], edi
	mov	bl, ah
	and	ecx, 7
	mov	bh, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31a0_0@4 ENDP


@op_31b8_0@4 PROC NEAR
	_start_func  'op_31b8_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+eax]
	mov	DWORD PTR _regs+92, esi
	mov	dx, WORD PTR [esi]
	mov	bl, ah
	shr	ecx, 1
	mov	bh, al
	add	esi, 2
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31b8_0@4 ENDP


@op_31b9_0@4 PROC NEAR
	_start_func  'op_31b9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	shr	ecx, 1
	mov	ax, WORD PTR [edx+eax]
	and	ecx, 7
	mov	bl, ah
	mov	bh, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31b9_0@4 ENDP


@op_31ba_0@4 PROC NEAR
	_start_func  'op_31ba_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	xor	ebx, ebx
	shr	ecx, 1
	mov	ax, WORD PTR [edx+esi-2]
	mov	DWORD PTR _regs+92, esi
	mov	dx, WORD PTR [esi]
	mov	bl, ah
	mov	bh, al
	add	esi, 2
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	and	eax, 0ff09H
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31ba_0@4 ENDP


@op_31bb_0@4 PROC NEAR
	_start_func  'op_31bb_0'
	mov	edx, DWORD PTR _regs+96
	mov	esi, ecx
	add	eax, 2
	mov	ecx, DWORD PTR _regs+88
	mov	DWORD PTR _regs+92, eax
	sub	ecx, edx
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	ebx, ebx
	shr	esi, 1
	mov	ax, WORD PTR [ecx+eax]
	and	esi, 7
	mov	bl, ah
	mov	bh, al
	mov	eax, DWORD PTR _regs+92
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	ecx, DWORD PTR _regs[esi*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31bb_0@4 ENDP


@op_31bc_0@4 PROC NEAR
	_start_func  'op_31bc_0'
	mov	esi, eax
	xor	ebx, ebx
	shr	ecx, 1
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	bl, ah
	mov	DWORD PTR _regs+92, esi
	mov	dx, WORD PTR [esi]
	mov	bh, al
	add	esi, 2
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	xor	ecx, ecx
	cmp	bx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	bx, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	dl, bh
	mov	dh, bl
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31bc_0@4 ENDP


@op_31e0_0@4 PROC NEAR
	_start_func  'op_31e0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, ecx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR _regs[esi*4+32]
	xor	edx, edx
	sub	eax, 2
	mov	cx, WORD PTR [edi+eax]
	mov	DWORD PTR _regs[esi*4+32], eax
	mov	eax, DWORD PTR _regs+92
	mov	dl, ch
	mov	dh, cl
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	cmp	dx, cx
	sete	bl
	cmp	dx, cx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, dh
	xor	ebx, ebx
	mov	ch, dl
	xor	edx, edx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	WORD PTR [edx+edi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31e0_0@4 ENDP


@op_31f0_0@4 PROC NEAR
	_start_func  'op_31f0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [esi+eax]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	cx, WORD PTR [edx]
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31f0_0@4 ENDP


@op_31f8_0@4 PROC NEAR
	_start_func  'op_31f8_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	dl, ah
	mov	bh, al
	mov	cx, WORD PTR [ecx+4]
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	ax, WORD PTR [edx+esi]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31f8_0@4 ENDP


@op_31f9_0@4 PROC NEAR
	_start_func  'op_31f9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [esi+eax]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	cx, WORD PTR [edx+6]
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31f9_0@4 ENDP


@op_31fa_0@4 PROC NEAR
	_start_func  'op_31fa_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	mov	esi, DWORD PTR _MEMBaseDiff
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, esi
	add	edx, eax
	mov	ax, WORD PTR [edx+ecx+2]
	xor	edx, edx
	mov	dl, ah
	mov	cx, WORD PTR [ecx+4]
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31fa_0@4 ENDP


@op_31fb_0@4 PROC NEAR
	_start_func  'op_31fb_0'
	mov	ecx, DWORD PTR _regs+88
	mov	esi, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, esi
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [esi+eax]
	mov	cl, ah
	mov	ch, al
	mov	eax, ecx
	mov	cx, WORD PTR [edx]
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31fb_0@4 ENDP


@op_31fc_0@4 PROC NEAR
	_start_func  'op_31fc_0'
	mov	ecx, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	xor	eax, eax
	xor	ebx, ebx
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_31fc_0@4 ENDP


@op_33c0_0@4 PROC NEAR
	_start_func  'op_33c0_0'
	shr	ecx, 8
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	cx, WORD PTR _regs[ecx*4]
	xor	edx, edx
	cmp	cx, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ch
	mov	BYTE PTR _regflags+1, bl
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33c0_0@4 ENDP


@op_33c8_0@4 PROC NEAR
	_start_func  'op_33c8_0'
	shr	ecx, 8
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	and	ecx, 7
	mov	cx, WORD PTR _regs[ecx*4+32]
	xor	edx, edx
	cmp	cx, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ch
	mov	BYTE PTR _regflags+1, bl
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+eax], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33c8_0@4 ENDP


@op_33d0_0@4 PROC NEAR
	_start_func  'op_33d0_0'
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [eax+ecx]
	mov	ecx, DWORD PTR _regs+92
	mov	dl, ah
	mov	ecx, DWORD PTR [ecx+2]
	bswap	ecx
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33d0_0@4 ENDP


@op_33d8_0@4 PROC NEAR
	_start_func  'op_33d8_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	ax, WORD PTR [esi+eax]
	add	esi, 2
	mov	dl, ah
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	ecx, DWORD PTR _regs+92
	mov	dh, al
	mov	eax, edx
	mov	ecx, DWORD PTR [ecx+2]
	bswap	ecx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33d8_0@4 ENDP


@op_33e0_0@4 PROC NEAR
	_start_func  'op_33e0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	eax, DWORD PTR _regs[esi*4+32]
	sub	eax, 2
	mov	cx, WORD PTR [ecx+eax]
	mov	DWORD PTR _regs[esi*4+32], eax
	mov	eax, DWORD PTR _regs+92
	mov	dl, ch
	mov	dh, cl
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	xor	ecx, ecx
	cmp	dx, cx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	dx, cx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, dh
	mov	BYTE PTR _regflags+1, bl
	mov	ch, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [edx+eax], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33e0_0@4 ENDP


@op_33e8_0@4 PROC NEAR
	_start_func  'op_33e8_0'
	mov	esi, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [esi+2]
	mov	esi, DWORD PTR [esi+4]
	bswap	esi
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	shr	ecx, 8
	and	ecx, 7
	or	edx, eax
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, eax
	mov	ax, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	ecx, ecx
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33e8_0@4 ENDP


@op_33f0_0@4 PROC NEAR
	_start_func  'op_33f0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	mov	ecx, DWORD PTR _regs+92
	mov	dl, ah
	mov	ecx, DWORD PTR [ecx]
	bswap	ecx
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33f0_0@4 ENDP


@op_33f8_0@4 PROC NEAR
	_start_func  'op_33f8_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33f8_0@4 ENDP


@op_33f9_0@4 PROC NEAR
	_start_func  'op_33f9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	mov	ecx, DWORD PTR _regs+92
	mov	dl, ah
	mov	ecx, DWORD PTR [ecx+6]
	bswap	ecx
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 10					; 0000000aH
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33f9_0@4 ENDP


@op_33fa_0@4 PROC NEAR
	_start_func  'op_33fa_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	mov	ax, WORD PTR [edx+ecx+2]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33fa_0@4 ENDP


@op_33fb_0@4 PROC NEAR
	_start_func  'op_33fb_0'
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	mov	ecx, DWORD PTR _regs+92
	mov	dl, ah
	mov	ecx, DWORD PTR [ecx]
	bswap	ecx
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33fb_0@4 ENDP


@op_33fc_0@4 PROC NEAR
	_start_func  'op_33fc_0'
	mov	ecx, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	xor	edx, edx
	mov	dl, ah
	mov	BYTE PTR _regflags+1, bl
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+ecx], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_33fc_0@4 ENDP


@op_4000_0@4 PROC NEAR
	_start_func  'op_4000_0'
	mov	dl, BYTE PTR _regflags+4
	shr	ecx, 8
	and	ecx, 7
	mov	esi, ecx
	xor	eax, eax
	test	dl, dl
	mov	cl, BYTE PTR _regs[esi*4]
	movsx	edx, cl
	setne	al
	add	eax, edx
	xor	edx, edx
	neg	eax
	test	cl, cl
	setl	dl
	xor	ebx, ebx
	mov	BYTE PTR _regs[esi*4], al
	test	al, al
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	al, al
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	al, al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+4, cl
	setl	cl
	add	eax, 2
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4000_0@4 ENDP


@op_4010_0@4 PROC NEAR
	_start_func  'op_4010_0'
	mov	dl, BYTE PTR _regflags+4
	shr	ecx, 8
	and	ecx, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	xor	eax, eax
	test	dl, dl
	mov	cl, BYTE PTR [edi+esi]
	movsx	edx, cl
	setne	al
	add	eax, edx
	xor	edx, edx
	neg	eax
	test	cl, cl
	setl	dl
	xor	ebx, ebx
	test	al, al
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	al, al
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	al, al
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4010_0@4 ENDP


@op_4018_0@4 PROC NEAR
	_start_func  'op_4018_0'
	shr	ecx, 8
	and	ecx, 7
	mov	dl, BYTE PTR _regflags+4
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	add	ecx, esi
	mov	bl, BYTE PTR [edi+esi]
	mov	DWORD PTR [eax], ecx
	xor	eax, eax
	test	dl, dl
	movsx	edx, bl
	setne	al
	add	eax, edx
	xor	edx, edx
	neg	eax
	test	bl, bl
	setl	dl
	xor	ebx, ebx
	test	al, al
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	al, al
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	al, al
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4018_0@4 ENDP


@op_4020_0@4 PROC NEAR
	_start_func  'op_4020_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _areg_byteinc[ecx*4]
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	dl, BYTE PTR _regflags+4
	sub	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [edi+esi]
	mov	DWORD PTR [eax], esi
	xor	eax, eax
	test	dl, dl
	movsx	edx, cl
	setne	al
	add	eax, edx
	xor	edx, edx
	neg	eax
	test	cl, cl
	setl	dl
	xor	ebx, ebx
	test	al, al
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	al, al
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	al, al
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4020_0@4 ENDP


@op_4028_0@4 PROC NEAR
	_start_func  'op_4028_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	mov	dl, BYTE PTR _regflags+4
	or	esi, eax
	xor	eax, eax
	mov	edi, DWORD PTR _regs[ecx*4+32]
	add	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	test	dl, dl
	mov	cl, BYTE PTR [edi+esi]
	movsx	edx, cl
	setne	al
	add	eax, edx
	xor	edx, edx
	neg	eax
	test	cl, cl
	setl	dl
	xor	ebx, ebx
	test	al, al
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	al, al
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	al, al
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4028_0@4 ENDP


@op_4030_0@4 PROC NEAR
	_start_func  'op_4030_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	mov	al, BYTE PTR _regflags+4
	xor	ecx, ecx
	mov	dl, BYTE PTR [edi+esi]
	test	al, al
	movsx	eax, dl
	setne	cl
	add	ecx, eax
	xor	eax, eax
	neg	ecx
	test	dl, dl
	setl	al
	xor	ebx, ebx
	test	cl, cl
	setl	bl
	mov	dl, bl
	and	dl, al
	mov	BYTE PTR _regflags+3, dl
	mov	dl, bl
	xor	dl, al
	and	dl, bl
	xor	dl, al
	test	cl, cl
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	dl, BYTE PTR _regflags+1
	sete	al
	and	dl, al
	test	cl, cl
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4030_0@4 ENDP


@op_4038_0@4 PROC NEAR
	_start_func  'op_4038_0'
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	mov	dh, al
	movsx	esi, cx
	movsx	eax, dx
	mov	dl, BYTE PTR _regflags+4
	mov	edi, DWORD PTR _MEMBaseDiff
	or	esi, eax
	xor	eax, eax
	mov	cl, BYTE PTR [edi+esi]
	test	dl, dl
	movsx	edx, cl
	setne	al
	add	eax, edx
	xor	edx, edx
	neg	eax
	test	cl, cl
	setl	dl
	xor	ebx, ebx
	test	al, al
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	al, al
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	al, al
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4038_0@4 ENDP


@op_4039_0@4 PROC NEAR
	_start_func  'op_4039_0'
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, BYTE PTR _regflags+4
	xor	eax, eax
	mov	cl, BYTE PTR [edi+esi]
	test	dl, dl
	movsx	edx, cl
	setne	al
	add	eax, edx
	xor	edx, edx
	neg	eax
	test	cl, cl
	setl	dl
	xor	ebx, ebx
	test	al, al
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	al, al
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	al, al
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4039_0@4 ENDP


@op_4040_0@4 PROC NEAR
	_start_func  'op_4040_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, ecx
	mov	cl, BYTE PTR _regflags+4
	xor	edx, edx
	mov	ax, WORD PTR _regs[esi*4]
	test	cl, cl
	movsx	ecx, ax
	setne	dl
	add	edx, ecx
	xor	ecx, ecx
	neg	edx
	test	ax, ax
	setl	cl
	xor	ebx, ebx
	mov	WORD PTR _regs[esi*4], dx
	test	dx, dx
	setl	bl
	mov	al, bl
	and	al, cl
	mov	BYTE PTR _regflags+3, al
	mov	al, bl
	xor	al, cl
	and	al, bl
	mov	bl, BYTE PTR _regflags+1
	xor	al, cl
	test	dx, dx
	sete	cl
	and	bl, cl
	mov	BYTE PTR _regflags+2, al
	test	dx, dx
	mov	BYTE PTR _regflags+4, al
	mov	BYTE PTR _regflags+1, bl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4040_0@4 ENDP


@op_4050_0@4 PROC NEAR
	_start_func  'op_4050_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, BYTE PTR _regflags+4
	xor	ecx, ecx
	mov	ax, WORD PTR [edi+esi]
	mov	cl, ah
	mov	ch, al
	xor	eax, eax
	test	dl, dl
	movsx	edx, cx
	setne	al
	add	eax, edx
	xor	edx, edx
	neg	eax
	test	cx, cx
	setl	dl
	xor	ebx, ebx
	test	ax, ax
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	ax, ax
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	ax, ax
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4050_0@4 ENDP


@op_4058_0@4 PROC NEAR
	_start_func  'op_4058_0'
	shr	ecx, 8
	and	ecx, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	bl, BYTE PTR _regflags+4
	xor	edx, edx
	mov	ax, WORD PTR [esi+ebp]
	mov	dl, ah
	mov	dh, al
	lea	eax, DWORD PTR [esi+2]
	mov	edi, edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	eax, eax
	test	bl, bl
	movsx	ecx, di
	setne	al
	add	eax, ecx
	xor	edx, edx
	neg	eax
	test	di, di
	setl	dl
	xor	ebx, ebx
	test	ax, ax
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	ax, ax
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	ax, ax
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [esi+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4058_0@4 ENDP


@op_4060_0@4 PROC NEAR
	_start_func  'op_4060_0'
	shr	ecx, 8
	and	ecx, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	sub	esi, 2
	mov	bl, BYTE PTR _regflags+4
	xor	edx, edx
	mov	ax, WORD PTR [esi+ebp]
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	dl, ah
	mov	dh, al
	xor	eax, eax
	mov	edi, edx
	test	bl, bl
	movsx	ecx, di
	setne	al
	add	eax, ecx
	xor	edx, edx
	neg	eax
	test	di, di
	setl	dl
	xor	ebx, ebx
	test	ax, ax
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	ax, ax
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	ax, ax
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [esi+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4060_0@4 ENDP


@op_4068_0@4 PROC NEAR
	_start_func  'op_4068_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	mov	dl, BYTE PTR _regflags+4
	mov	edi, DWORD PTR _regs[ecx*4+32]
	xor	ecx, ecx
	add	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [edi+esi]
	mov	cl, ah
	mov	ch, al
	xor	eax, eax
	test	dl, dl
	movsx	edx, cx
	setne	al
	add	eax, edx
	xor	edx, edx
	neg	eax
	test	cx, cx
	setl	dl
	xor	ebx, ebx
	test	ax, ax
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	ax, ax
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	ax, ax
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4068_0@4 ENDP


@op_4070_0@4 PROC NEAR
	_start_func  'op_4070_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	xor	edx, edx
	xor	ecx, ecx
	mov	ax, WORD PTR [edi+esi]
	mov	dl, ah
	mov	dh, al
	mov	al, BYTE PTR _regflags+4
	test	al, al
	movsx	eax, dx
	setne	cl
	add	ecx, eax
	xor	eax, eax
	neg	ecx
	test	dx, dx
	setl	al
	xor	ebx, ebx
	test	cx, cx
	setl	bl
	mov	dl, bl
	and	dl, al
	mov	BYTE PTR _regflags+3, dl
	mov	dl, bl
	xor	dl, al
	and	dl, bl
	xor	dl, al
	test	cx, cx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	dl, BYTE PTR _regflags+1
	sete	al
	and	dl, al
	test	cx, cx
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	xor	eax, eax
	mov	BYTE PTR _regflags, dl
	mov	al, ch
	mov	ah, cl
	mov	WORD PTR [edi+esi], ax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4070_0@4 ENDP


@op_4078_0@4 PROC NEAR
	_start_func  'op_4078_0'
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	mov	dh, al
	movsx	esi, cx
	movsx	eax, dx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, BYTE PTR _regflags+4
	or	esi, eax
	xor	ecx, ecx
	mov	ax, WORD PTR [edi+esi]
	mov	cl, ah
	mov	ch, al
	xor	eax, eax
	test	dl, dl
	movsx	edx, cx
	setne	al
	add	eax, edx
	xor	edx, edx
	neg	eax
	test	cx, cx
	setl	dl
	xor	ebx, ebx
	test	ax, ax
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	ax, ax
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	ax, ax
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4078_0@4 ENDP


@op_4079_0@4 PROC NEAR
	_start_func  'op_4079_0'
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, BYTE PTR _regflags+4
	xor	ecx, ecx
	mov	ax, WORD PTR [edi+esi]
	mov	cl, ah
	mov	ch, al
	xor	eax, eax
	test	dl, dl
	movsx	edx, cx
	setne	al
	add	eax, edx
	xor	edx, edx
	neg	eax
	test	cx, cx
	setl	dl
	xor	ebx, ebx
	test	ax, ax
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	ax, ax
	sete	dl
	and	bl, dl
	mov	BYTE PTR _regflags+2, cl
	test	ax, ax
	mov	BYTE PTR _regflags+4, cl
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4079_0@4 ENDP


@op_4090_0@4 PROC NEAR
	_start_func  'op_4090_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	push	ebx
	shr	ecx, 8
	and	ecx, 7
	push	esi
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR [eax+esi]
	bswap	eax
	mov	cl, BYTE PTR _regflags+4
	xor	edx, edx
	test	cl, cl
	setne	dl
	add	edx, eax
	xor	ecx, ecx
	neg	edx
	test	eax, eax
	setl	cl
	xor	ebx, ebx
	test	edx, edx
	setl	bl
	mov	al, bl
	and	al, cl
	mov	BYTE PTR _regflags+3, al
	mov	al, bl
	xor	al, cl
	and	al, bl
	mov	bl, BYTE PTR _regflags+1
	xor	al, cl
	test	edx, edx
	sete	cl
	and	bl, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	setl	al
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, al
	add	esi, ecx
	bswap	edx
	mov	DWORD PTR [esi], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4090_0@4 ENDP


@op_4098_0@4 PROC NEAR
	_start_func  'op_4098_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	push	ebx
	shr	ecx, 8
	and	ecx, 7
	push	esi
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	eax, DWORD PTR [eax+esi]
	bswap	eax
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	dl, BYTE PTR _regflags+4
	add	ebx, 4
	mov	DWORD PTR _regs[ecx*4+32], ebx
	xor	ecx, ecx
	test	dl, dl
	setne	cl
	add	ecx, eax
	xor	edx, edx
	neg	ecx
	test	eax, eax
	setl	dl
	xor	ebx, ebx
	test	ecx, ecx
	setl	bl
	mov	al, bl
	and	al, dl
	mov	BYTE PTR _regflags+3, al
	mov	al, bl
	xor	al, dl
	and	al, bl
	mov	bl, BYTE PTR _regflags+1
	xor	al, dl
	test	ecx, ecx
	sete	dl
	and	bl, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	setl	al
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, al
	add	esi, edx
	bswap	ecx
	mov	DWORD PTR [esi], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4098_0@4 ENDP


@op_40a0_0@4 PROC NEAR
	_start_func  'op_40a0_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	push	ebx
	shr	ecx, 8
	and	ecx, 7
	push	esi
	push	edi
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	edi, DWORD PTR [edx+eax]
	bswap	edi
	mov	bl, BYTE PTR _regflags+4
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	ecx, ecx
	test	bl, bl
	setne	cl
	add	ecx, edi
	xor	edx, edx
	neg	ecx
	test	edi, edi
	mov	esi, ecx
	setl	dl
	xor	ebx, ebx
	test	esi, esi
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	esi, esi
	sete	dl
	and	bl, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	test	esi, esi
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	setl	cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40a0_0@4 ENDP


@op_40a8_0@4 PROC NEAR
	_start_func  'op_40a8_0'
	push	ebx
	push	esi
	mov	esi, ecx
	mov	cx, WORD PTR [eax+2]
	xor	edx, edx
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	eax, ecx
	shr	esi, 8
	and	esi, 7
	add	eax, DWORD PTR _regs[esi*4+32]
	mov	ecx, DWORD PTR [edx+eax]
	bswap	ecx
	mov	bl, BYTE PTR _regflags+4
	xor	edx, edx
	test	bl, bl
	setne	dl
	add	edx, ecx
	neg	edx
	mov	esi, edx
	xor	edx, edx
	test	ecx, ecx
	setl	dl
	xor	ebx, ebx
	test	esi, esi
	setl	bl
	mov	cl, bl
	and	cl, dl
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, dl
	and	cl, bl
	mov	bl, BYTE PTR _regflags+1
	xor	cl, dl
	test	esi, esi
	sete	dl
	and	bl, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	test	esi, esi
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	setl	cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40a8_0@4 ENDP


@op_40b0_0@4 PROC NEAR
	_start_func  'op_40b0_0'
	push	ebx
	add	eax, 2
	push	esi
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	mov	ecx, DWORD PTR [ecx+esi]
	bswap	ecx
	mov	al, BYTE PTR _regflags+4
	xor	edx, edx
	test	al, al
	setne	dl
	add	edx, ecx
	xor	eax, eax
	neg	edx
	test	ecx, ecx
	setl	al
	xor	ebx, ebx
	test	edx, edx
	setl	bl
	mov	cl, bl
	and	cl, al
	mov	BYTE PTR _regflags+3, cl
	mov	cl, bl
	xor	cl, al
	and	cl, bl
	xor	cl, al
	test	edx, edx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	cl, BYTE PTR _regflags+1
	sete	al
	and	cl, al
	mov	eax, DWORD PTR _MEMBaseDiff
	test	edx, edx
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	add	esi, eax
	bswap	edx
	mov	DWORD PTR [esi], edx
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40b0_0@4 ENDP


@op_40b8_0@4 PROC NEAR
	_start_func  'op_40b8_0'
	xor	ecx, ecx
	xor	edx, edx
	push	ebx
	mov	ax, WORD PTR [eax+2]
	push	esi
	mov	cl, ah
	mov	dh, al
	movsx	ecx, cx
	movsx	eax, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	ecx, eax
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	mov	bl, BYTE PTR _regflags+4
	xor	edx, edx
	test	bl, bl
	setne	dl
	add	edx, eax
	neg	edx
	mov	esi, edx
	xor	edx, edx
	test	eax, eax
	setl	dl
	xor	ebx, ebx
	test	esi, esi
	setl	bl
	mov	al, bl
	and	al, dl
	mov	BYTE PTR _regflags+3, al
	mov	al, bl
	xor	al, dl
	and	al, bl
	mov	bl, BYTE PTR _regflags+1
	xor	al, dl
	test	esi, esi
	sete	dl
	and	bl, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	test	esi, esi
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	setl	al
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, al
	add	ecx, edx
	bswap	esi
	mov	DWORD PTR [ecx], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40b8_0@4 ENDP


@op_40b9_0@4 PROC NEAR
	_start_func  'op_40b9_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+esi]
	bswap	eax
	mov	dl, BYTE PTR _regflags+4
	xor	ecx, ecx
	test	dl, dl
	setne	cl
	add	ecx, eax
	xor	edx, edx
	neg	ecx
	test	eax, eax
	setl	dl
	xor	ebx, ebx
	test	ecx, ecx
	setl	bl
	mov	al, bl
	and	al, dl
	mov	BYTE PTR _regflags+3, al
	mov	al, bl
	xor	al, dl
	and	al, bl
	mov	bl, BYTE PTR _regflags+1
	xor	al, dl
	test	ecx, ecx
	sete	dl
	and	bl, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	setl	al
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, al
	add	esi, edx
	bswap	ecx
	mov	DWORD PTR [esi], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40b9_0@4 ENDP


@op_40d0_0@4 PROC NEAR
	_start_func  'op_40d0_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L90082
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90082:
	shr	ecx, 8
	and	ecx, 7
	push	esi
	mov	esi, DWORD PTR _regs[ecx*4+32]
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40d0_0@4 ENDP


@op_40d8_0@4 PROC NEAR
	_start_func  'op_40d8_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	jne	SHORT $L90090
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90090:
	push	esi
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	eax, DWORD PTR [esi+2]
	mov	DWORD PTR _regs[ecx*4+32], eax
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40d8_0@4 ENDP


@op_40e8_0@4 PROC NEAR
	_start_func  'op_40e8_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L90098
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90098:
	mov	eax, DWORD PTR _regs+92
	xor	edx, edx
	push	esi
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	add	esi, DWORD PTR _regs[ecx*4+32]
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40e8_0@4 ENDP


@op_40f0_0@4 PROC NEAR
	_start_func  'op_40f0_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L90109
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90109:
	mov	eax, DWORD PTR _regs+92
	push	esi
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	esi, eax
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40f0_0@4 ENDP


@op_40f8_0@4 PROC NEAR
	_start_func  'op_40f8_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L90116
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90116:
	mov	eax, DWORD PTR _regs+92
	push	ebx
	mov	bx, WORD PTR [eax+2]
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+76
	xor	ecx, ecx
	xor	edx, edx
	mov	cl, ah
	mov	dl, bh
	mov	ch, al
	movsx	eax, dx
	xor	edx, edx
	mov	dh, bl
	pop	ebx
	movsx	edx, dx
	or	eax, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+edx], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40f8_0@4 ENDP


@op_40f9_0@4 PROC NEAR
	_start_func  'op_40f9_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L90126
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90126:
	mov	eax, DWORD PTR _regs+92
	push	esi
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	call	_MakeSR@0
	mov	eax, DWORD PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	esi
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_40f9_0@4 ENDP


@op_4100_0@4 PROC NEAR
	_start_func  'op_4100_0'
	mov	eax, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	sub	eax, edx
	mov	edx, DWORD PTR _regs+92
	add	eax, edx
	mov	edx, ecx
	shr	ecx, 1
	and	ecx, 7
	shr	edx, 8
	mov	ecx, DWORD PTR _regs[ecx*4]
	and	edx, 7
	test	ecx, ecx
	mov	edx, DWORD PTR _regs[edx*4]
	jge	SHORT $L90140
	push	eax
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90140:
	cmp	ecx, edx
	jle	SHORT $L90144
	push	eax
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90144:
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4100_0@4 ENDP


@op_4110_0@4 PROC NEAR
	_start_func  'op_4110_0'
	mov	edx, eax
	mov	eax, DWORD PTR _regs+88
	mov	esi, DWORD PTR _regs+96
	sub	eax, esi
	mov	esi, DWORD PTR _MEMBaseDiff
	add	eax, edx
	mov	edx, ecx
	shr	edx, 8
	and	edx, 7
	mov	edx, DWORD PTR _regs[edx*4+32]
	mov	edx, DWORD PTR [edx+esi]
	bswap	edx
	shr	ecx, 1
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	test	ecx, ecx
	jge	SHORT $L90156
	push	eax
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90156:
	cmp	ecx, edx
	jle	SHORT $L90160
	push	eax
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90160:
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4110_0@4 ENDP


@op_4118_0@4 PROC NEAR
	_start_func  'op_4118_0'
	mov	edx, DWORD PTR _regs+88
	mov	esi, eax
	mov	eax, ecx
	mov	edi, DWORD PTR _regs+96
	shr	eax, 8
	and	eax, 7
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	add	edx, esi
	mov	esi, DWORD PTR _regs[eax*4+32]
	mov	esi, DWORD PTR [esi+edi]
	bswap	esi
	mov	edi, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	add	edi, 4
	and	ecx, 7
	mov	DWORD PTR _regs[eax*4+32], edi
	mov	ecx, DWORD PTR _regs[ecx*4]
	test	ecx, ecx
	jge	SHORT $L90172
	push	edx
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90172:
	cmp	ecx, esi
	jle	SHORT $L90176
	push	edx
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90176:
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4118_0@4 ENDP


@op_4120_0@4 PROC NEAR
	_start_func  'op_4120_0'
	mov	edx, DWORD PTR _regs+88
	mov	esi, eax
	mov	eax, ecx
	mov	edi, DWORD PTR _regs+96
	shr	eax, 8
	and	eax, 7
	sub	edx, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	add	edx, esi
	mov	esi, DWORD PTR _regs[eax*4+32]
	sub	esi, 4
	mov	edi, DWORD PTR [edi+esi]
	bswap	edi
	shr	ecx, 1
	and	ecx, 7
	mov	DWORD PTR _regs[eax*4+32], esi
	mov	ecx, DWORD PTR _regs[ecx*4]
	test	ecx, ecx
	jge	SHORT $L90188
	push	edx
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90188:
	cmp	ecx, edi
	jle	SHORT $L90192
	push	edx
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90192:
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4120_0@4 ENDP


@op_4128_0@4 PROC NEAR
	_start_func  'op_4128_0'
	mov	eax, DWORD PTR _regs+96
	mov	esi, DWORD PTR _regs+88
	sub	esi, eax
	mov	eax, DWORD PTR _regs+92
	add	esi, eax
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	xor	ebx, ebx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	ebx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	mov	eax, DWORD PTR [edx+eax]
	bswap	eax
	shr	ecx, 1
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	test	ecx, ecx
	jge	SHORT $L90207
	push	esi
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90207:
	cmp	ecx, eax
	jle	SHORT $L90211
	push	esi
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90211:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4128_0@4 ENDP


@op_4130_0@4 PROC NEAR
	_start_func  'op_4130_0'
	mov	edx, DWORD PTR _regs+96
	mov	edi, DWORD PTR _regs+88
	mov	esi, ecx
	sub	edi, edx
	add	edi, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	shr	esi, 1
	and	esi, 7
	mov	esi, DWORD PTR _regs[esi*4]
	test	esi, esi
	jge	SHORT $L90223
	push	edi
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90223:
	cmp	esi, eax
	jle	SHORT $L124441
	push	edi
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
$L124441:
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4130_0@4 ENDP


@op_4138_0@4 PROC NEAR
	_start_func  'op_4138_0'
	mov	eax, DWORD PTR _regs+88
	mov	ebx, DWORD PTR _regs+96
	mov	esi, ecx
	sub	eax, ebx
	mov	ecx, DWORD PTR _regs+92
	xor	edx, edx
	add	eax, ecx
	xor	ebx, ebx
	mov	cx, WORD PTR [ecx+2]
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [edx+ecx]
	bswap	ecx
	shr	esi, 1
	and	esi, 7
	mov	esi, DWORD PTR _regs[esi*4]
	test	esi, esi
	jge	SHORT $L90241
	push	eax
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90241:
	cmp	esi, ecx
	jle	SHORT $L90245
	push	eax
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90245:
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4138_0@4 ENDP


@op_4139_0@4 PROC NEAR
	_start_func  'op_4139_0'
	mov	eax, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	sub	eax, edx
	mov	edx, DWORD PTR _regs+92
	add	eax, edx
	mov	edx, DWORD PTR [edx+2]
	bswap	edx
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR [esi+edx]
	bswap	edx
	shr	ecx, 1
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	test	ecx, ecx
	jge	SHORT $L90257
	push	eax
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90257:
	cmp	ecx, edx
	jle	SHORT $L90261
	push	eax
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90261:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4139_0@4 ENDP


_x$124489 = -4
@op_413a_0@4 PROC NEAR
	_start_func  'op_413a_0'
	mov	ebp, esp
	push	ecx
	mov	eax, DWORD PTR _regs+88
	push	ebx
	push	esi
	push	edi
	mov	edi, DWORD PTR _regs+96
	mov	esi, eax
	sub	esi, edi
	mov	edi, DWORD PTR _regs+92
	xor	ebx, ebx
	add	esi, edi
	mov	dx, WORD PTR [edi+2]
	mov	bl, dh
	mov	DWORD PTR _x$124489[ebp], edx
	movsx	edx, bx
	xor	ebx, ebx
	mov	bh, BYTE PTR _x$124489[ebp]
	movsx	ebx, bx
	or	edx, ebx
	mov	ebx, DWORD PTR _regs+96
	sub	edx, ebx
	mov	ebx, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	add	edx, eax
	mov	edi, DWORD PTR [edx+edi+2]
	bswap	edi
	shr	ecx, 1
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	test	ecx, ecx
	jge	SHORT $L90275
	push	esi
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	pop	edi
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90275:
	cmp	ecx, edi
	jle	SHORT $L90279
	push	esi
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	pop	edi
	pop	esi
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90279:
	mov	eax, DWORD PTR _regs+92
	pop	edi
	add	eax, 4
	pop	esi
	mov	DWORD PTR _regs+92, eax
	pop	ebx
	mov	esp, ebp
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_413a_0@4 ENDP


@op_413b_0@4 PROC NEAR
	_start_func  'op_413b_0'
	mov	edi, eax
	mov	edx, DWORD PTR _regs+96
	mov	eax, DWORD PTR _regs+88
	sub	eax, edx
	mov	esi, ecx
	lea	ebx, DWORD PTR [eax+edi]
	add	edi, 2
	mov	DWORD PTR _regs+92, edi
	mov	dx, WORD PTR [edi]
	lea	ecx, DWORD PTR [eax+edi]
	mov	eax, edx
	add	edi, 2
	and	eax, 0ff09H
	mov	DWORD PTR _regs+92, edi
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	shr	esi, 1
	and	esi, 7
	mov	esi, DWORD PTR _regs[esi*4]
	test	esi, esi
	jge	SHORT $L90291
	push	ebx
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90291:
	cmp	esi, eax
	jle	SHORT $L124519
	push	ebx
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
$L124519:
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_413b_0@4 ENDP


@op_413c_0@4 PROC NEAR
	_start_func  'op_413c_0'
	mov	eax, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	sub	eax, edx
	mov	edx, DWORD PTR _regs+92
	add	eax, edx
	mov	edx, DWORD PTR [edx+2]
	bswap	edx
	shr	ecx, 1
	and	ecx, 7
	mov	ecx, DWORD PTR _regs[ecx*4]
	test	ecx, ecx
	jge	SHORT $L90306
	push	eax
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90306:
	cmp	ecx, edx
	jle	SHORT $L90310
	push	eax
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90310:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_413c_0@4 ENDP


@op_4180_0@4 PROC NEAR
	_start_func  'op_4180_0'
	mov	eax, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	sub	eax, edx
	mov	edx, DWORD PTR _regs+92
	add	eax, edx
	mov	edx, ecx
	shr	ecx, 1
	and	ecx, 7
	shr	edx, 8
	mov	cx, WORD PTR _regs[ecx*4]
	and	edx, 7
	test	cx, cx
	mov	dx, WORD PTR _regs[edx*4]
	jge	SHORT $L90321
	push	eax
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90321:
	cmp	cx, dx
	jle	SHORT $L90325
	push	eax
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90325:
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4180_0@4 ENDP


@op_4190_0@4 PROC NEAR
	_start_func  'op_4190_0'
	mov	edx, eax
	mov	eax, DWORD PTR _regs+88
	mov	esi, DWORD PTR _regs+96
	sub	eax, esi
	mov	esi, DWORD PTR _MEMBaseDiff
	add	eax, edx
	mov	edx, ecx
	shr	edx, 8
	and	edx, 7
	shr	ecx, 1
	mov	edx, DWORD PTR _regs[edx*4+32]
	and	ecx, 7
	mov	dx, WORD PTR [edx+esi]
	mov	si, WORD PTR _regs[ecx*4]
	test	si, si
	jge	SHORT $L90337
	push	eax
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90337:
	xor	ecx, ecx
	mov	cl, dh
	mov	ch, dl
	cmp	si, cx
	jle	SHORT $L90341
	push	eax
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90341:
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4190_0@4 ENDP


@op_4198_0@4 PROC NEAR
	_start_func  'op_4198_0'
	mov	edx, eax
	mov	esi, DWORD PTR _regs+88
	mov	eax, ecx
	mov	edi, DWORD PTR _regs+96
	shr	eax, 8
	and	eax, 7
	sub	esi, edi
	add	esi, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	edi, DWORD PTR _regs[eax*4+32]
	shr	ecx, 1
	mov	dx, WORD PTR [edi+edx]
	add	edi, 2
	and	ecx, 7
	mov	DWORD PTR _regs[eax*4+32], edi
	mov	cx, WORD PTR _regs[ecx*4]
	test	cx, cx
	jge	SHORT $L90353
	push	esi
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90353:
	xor	eax, eax
	mov	al, dh
	mov	ah, dl
	cmp	cx, ax
	jle	SHORT $L90357
	push	esi
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90357:
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4198_0@4 ENDP


@op_41a0_0@4 PROC NEAR
	_start_func  'op_41a0_0'
	mov	edx, DWORD PTR _regs+96
	mov	eax, ecx
	mov	esi, DWORD PTR _regs+88
	shr	eax, 8
	mov	edi, DWORD PTR _regs+92
	and	eax, 7
	sub	esi, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	add	esi, edi
	mov	edi, DWORD PTR _regs[eax*4+32]
	sub	edi, 2
	shr	ecx, 1
	mov	dx, WORD PTR [edx+edi]
	and	ecx, 7
	mov	DWORD PTR _regs[eax*4+32], edi
	mov	cx, WORD PTR _regs[ecx*4]
	test	cx, cx
	jge	SHORT $L90369
	push	esi
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90369:
	xor	eax, eax
	mov	al, dh
	mov	ah, dl
	cmp	cx, ax
	jle	SHORT $L90373
	push	esi
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90373:
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41a0_0@4 ENDP


@op_41a8_0@4 PROC NEAR
	_start_func  'op_41a8_0'
	mov	edx, DWORD PTR _regs+96
	mov	esi, DWORD PTR _regs+88
	mov	edi, eax
	sub	esi, edx
	xor	edx, edx
	mov	ax, WORD PTR [edi+2]
	xor	ebx, ebx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	add	esi, edi
	shr	ecx, 1
	mov	ebx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _MEMBaseDiff
	and	ecx, 7
	add	edx, ebx
	mov	cx, WORD PTR _regs[ecx*4]
	mov	ax, WORD PTR [edx+eax]
	test	cx, cx
	jge	SHORT $L90388
	push	esi
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90388:
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	cmp	cx, dx
	jle	SHORT $L90392
	push	esi
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90392:
	add	edi, 4
	mov	DWORD PTR _regs+92, edi
	mov	eax,edi
	movzx	ecx, word ptr[edi]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41a8_0@4 ENDP


@op_41b0_0@4 PROC NEAR
	_start_func  'op_41b0_0'
	mov	edx, DWORD PTR _regs+96
	mov	edi, DWORD PTR _regs+88
	mov	esi, ecx
	sub	edi, edx
	add	edi, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	shr	esi, 1
	mov	ax, WORD PTR [ecx+eax]
	and	esi, 7
	mov	si, WORD PTR _regs[esi*4]
	test	si, si
	jge	SHORT $L90404
	push	edi
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90404:
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	cmp	si, dx
	jle	SHORT $L124612
	push	edi
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
$L124612:
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41b0_0@4 ENDP


@op_41b8_0@4 PROC NEAR
	_start_func  'op_41b8_0'
	mov	edi, eax
	mov	edx, DWORD PTR _regs+96
	mov	eax, DWORD PTR _regs+88
	mov	esi, ecx
	sub	eax, edx
	mov	cx, WORD PTR [edi+2]
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ch
	mov	bh, cl
	add	eax, edi
	movsx	edx, dx
	movsx	ecx, bx
	shr	esi, 1
	and	esi, 7
	or	edx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	si, WORD PTR _regs[esi*4]
	mov	cx, WORD PTR [edx+ecx]
	test	si, si
	jge	SHORT $L90422
	push	eax
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90422:
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	cmp	si, dx
	jle	SHORT $L90426
	push	eax
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90426:
	add	edi, 4
	mov	DWORD PTR _regs+92, edi
	mov	eax,edi
	movzx	ecx, word ptr[edi]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41b8_0@4 ENDP


@op_41b9_0@4 PROC NEAR
	_start_func  'op_41b9_0'
	mov	eax, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	sub	eax, edx
	mov	edx, DWORD PTR _regs+92
	add	eax, edx
	mov	esi, DWORD PTR [edx+2]
	bswap	esi
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 1
	mov	dx, WORD PTR [edx+esi]
	and	ecx, 7
	mov	si, WORD PTR _regs[ecx*4]
	test	si, si
	jge	SHORT $L90438
	push	eax
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90438:
	xor	ecx, ecx
	mov	cl, dh
	mov	ch, dl
	cmp	si, cx
	jle	SHORT $L90442
	push	eax
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90442:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41b9_0@4 ENDP


@op_41ba_0@4 PROC NEAR
	_start_func  'op_41ba_0'
	mov	edx, DWORD PTR _regs+96
	mov	ebp, DWORD PTR _regs+88
	mov	edi, eax
	mov	esi, ebp
	sub	esi, edx
	xor	edx, edx
	mov	ax, WORD PTR [edi+2]
	xor	ebx, ebx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	add	esi, edi
	shr	ecx, 1
	sub	edx, eax
	and	ecx, 7
	add	edx, ebx
	mov	cx, WORD PTR _regs[ecx*4]
	add	edx, ebp
	test	cx, cx
	mov	ax, WORD PTR [edx+edi+2]
	jge	SHORT $L90456
	push	esi
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90456:
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	cmp	cx, dx
	jle	SHORT $L90460
	push	esi
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90460:
	add	edi, 4
	mov	DWORD PTR _regs+92, edi
	mov	eax,edi
	movzx	ecx, word ptr[edi]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41ba_0@4 ENDP


@op_41bb_0@4 PROC NEAR
	_start_func  'op_41bb_0'
	mov	edi, eax
	mov	edx, DWORD PTR _regs+96
	mov	eax, DWORD PTR _regs+88
	sub	eax, edx
	mov	esi, ecx
	lea	ebx, DWORD PTR [eax+edi]
	add	edi, 2
	mov	DWORD PTR _regs+92, edi
	mov	dx, WORD PTR [edi]
	lea	ecx, DWORD PTR [eax+edi]
	mov	eax, edx
	add	edi, 2
	and	eax, 0ff09H
	mov	DWORD PTR _regs+92, edi
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	shr	esi, 1
	mov	ax, WORD PTR [ecx+eax]
	and	esi, 7
	mov	si, WORD PTR _regs[esi*4]
	test	si, si
	jge	SHORT $L90472
	push	ebx
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90472:
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	cmp	si, dx
	jle	SHORT $L124687
	push	ebx
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
$L124687:
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41bb_0@4 ENDP


@op_41bc_0@4 PROC NEAR
	_start_func  'op_41bc_0'
	mov	edi, eax
	mov	esi, DWORD PTR _regs+96
	mov	eax, DWORD PTR _regs+88
	sub	eax, esi
	shr	ecx, 1
	mov	dx, WORD PTR [edi+2]
	and	ecx, 7
	add	eax, edi
	mov	si, WORD PTR _regs[ecx*4]
	test	si, si
	jge	SHORT $L90487
	push	eax
	push	6
	mov	BYTE PTR _regflags, 1
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90487:
	xor	ecx, ecx
	mov	cl, dh
	mov	ch, dl
	cmp	si, cx
	jle	SHORT $L90491
	push	eax
	push	6
	mov	BYTE PTR _regflags, 0
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L90491:
	add	edi, 4
	mov	DWORD PTR _regs+92, edi
	mov	eax,edi
	movzx	ecx, word ptr[edi]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_41bc_0@4 ENDP


@op_4238_0@4 PROC NEAR
	_start_func  'op_4238_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	xor	cl, cl
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, 1
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4238_0@4 ENDP


@op_4239_0@4 PROC NEAR
	_start_func  'op_4239_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	cl, cl
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, 1
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edx+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4239_0@4 ENDP


@op_4278_0@4 PROC NEAR
	_start_func  'op_4278_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	xor	ecx, ecx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, 1
	mov	BYTE PTR _regflags, cl
	mov	WORD PTR [edx+eax], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4278_0@4 ENDP


@op_4279_0@4 PROC NEAR
	_start_func  'op_4279_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, 1
	mov	BYTE PTR _regflags, cl
	mov	WORD PTR [edx+eax], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4279_0@4 ENDP


@op_4280_0@4 PROC NEAR
	_start_func  'op_4280_0'
	shr	ecx, 8
	and	ecx, 7
	xor	eax, eax
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs[ecx*4], eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, 1
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4280_0@4 ENDP


@op_42b8_0@4 PROC NEAR
	_start_func  'op_42b8_0'
	push	ebx
	xor	ebx, ebx
	xor	edx, edx
	mov	cx, WORD PTR [eax+2]
	xor	eax, eax
	mov	al, ch
	mov	bh, cl
	movsx	eax, ax
	movsx	ecx, bx
	or	eax, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+3, dl
	mov	BYTE PTR _regflags+1, 1
	mov	BYTE PTR _regflags, dl
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42b8_0@4 ENDP


@op_42b9_0@4 PROC NEAR
	_start_func  'op_42b9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, 1
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42b9_0@4 ENDP


@op_42c0_0@4 PROC NEAR
	_start_func  'op_42c0_0'
	mov	esi, ecx
	call	_MakeSR@0
	mov	al, BYTE PTR _regs+76
	shr	esi, 8
	and	esi, 7
	and	eax, 255				; 000000ffH
	mov	WORD PTR _regs[esi*4], ax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42c0_0@4 ENDP


@op_42d0_0@4 PROC NEAR
	_start_func  'op_42d0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	call	_MakeSR@0
	mov	al, BYTE PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	and	eax, 255				; 000000ffH
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42d0_0@4 ENDP


@op_42d8_0@4 PROC NEAR
	_start_func  'op_42d8_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	lea	eax, DWORD PTR [esi+2]
	mov	DWORD PTR _regs[ecx*4+32], eax
	call	_MakeSR@0
	mov	al, BYTE PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	and	eax, 255				; 000000ffH
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42d8_0@4 ENDP


@op_42e0_0@4 PROC NEAR
	_start_func  'op_42e0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	sub	esi, 2
	mov	DWORD PTR _regs[ecx*4+32], esi
	call	_MakeSR@0
	mov	al, BYTE PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	and	eax, 255				; 000000ffH
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42e0_0@4 ENDP


@op_42e8_0@4 PROC NEAR
	_start_func  'op_42e8_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	or	esi, eax
	add	esi, DWORD PTR _regs[ecx*4+32]
	call	_MakeSR@0
	mov	al, BYTE PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	and	eax, 255				; 000000ffH
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42e8_0@4 ENDP


@op_42f0_0@4 PROC NEAR
	_start_func  'op_42f0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	esi, eax
	call	_MakeSR@0
	mov	al, BYTE PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	and	eax, 255				; 000000ffH
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42f0_0@4 ENDP


@op_42f8_0@4 PROC NEAR
	_start_func  'op_42f8_0'
	mov	bx, WORD PTR [eax+2]
	call	_MakeSR@0
	mov	al, BYTE PTR _regs+76
	xor	ecx, ecx
	and	eax, 255				; 000000ffH
	xor	edx, edx
	mov	cl, ah
	mov	dl, bh
	mov	ch, al
	movsx	eax, dx
	xor	edx, edx
	mov	dh, bl
	movsx	edx, dx
	or	eax, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+edx], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42f8_0@4 ENDP


@op_42f9_0@4 PROC NEAR
	_start_func  'op_42f9_0'
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	call	_MakeSR@0
	mov	al, BYTE PTR _regs+76
	mov	edx, DWORD PTR _MEMBaseDiff
	and	eax, 255				; 000000ffH
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR [edx+esi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_42f9_0@4 ENDP


@op_4418_0@4 PROC NEAR
	_start_func  'op_4418_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	lea	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	dl, BYTE PTR [edi+esi]
	add	ecx, esi
	mov	DWORD PTR [eax], ecx
	xor	ecx, ecx
	movsx	eax, dl
	neg	eax
	test	al, al
	setl	cl
	test	al, al
	sete	bl
	test	dl, dl
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	and	bl, cl
	test	dl, dl
	seta	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	dl
	mov	BYTE PTR _regflags+3, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4418_0@4 ENDP


_src$90637 = -1
@op_4420_0@4 PROC NEAR
	_start_func  'op_4420_0'
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	sub	eax, esi
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [esi+eax]
	mov	DWORD PTR [edx], eax
	mov	BYTE PTR _src$90637[esp+12], cl
	xor	edx, edx
	movsx	ecx, cl
	neg	ecx
	test	cl, cl
	setl	dl
	test	cl, cl
	sete	bl
	mov	BYTE PTR _regflags+1, bl
	mov	bl, BYTE PTR _src$90637[esp+12]
	test	bl, bl
	setl	bl
	and	bl, dl
	mov	BYTE PTR _regflags+3, bl
	mov	bl, BYTE PTR _src$90637[esp+12]
	test	bl, bl
	seta	bl
	test	edx, edx
	setne	dl
	mov	BYTE PTR _regflags+2, bl
	mov	BYTE PTR _regflags+4, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4420_0@4 ENDP


@op_4430_0@4 PROC NEAR
	_start_func  'op_4430_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	xor	edx, edx
	mov	al, BYTE PTR [edi+esi]
	movsx	ecx, al
	neg	ecx
	test	cl, cl
	setl	dl
	test	cl, cl
	sete	bl
	test	al, al
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	and	bl, dl
	test	al, al
	seta	al
	test	edx, edx
	setne	dl
	mov	BYTE PTR _regflags+3, bl
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4430_0@4 ENDP


@op_4438_0@4 PROC NEAR
	_start_func  'op_4438_0'
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	mov	dh, al
	movsx	esi, cx
	movsx	eax, dx
	mov	edi, DWORD PTR _MEMBaseDiff
	or	esi, eax
	xor	edx, edx
	mov	cl, BYTE PTR [edi+esi]
	movsx	eax, cl
	neg	eax
	test	al, al
	setl	dl
	test	al, al
	sete	bl
	test	cl, cl
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	and	bl, dl
	test	cl, cl
	seta	cl
	test	edx, edx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	setne	cl
	mov	BYTE PTR _regflags+3, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4438_0@4 ENDP


@op_4439_0@4 PROC NEAR
	_start_func  'op_4439_0'
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	cl, BYTE PTR [edi+esi]
	movsx	eax, cl
	neg	eax
	test	al, al
	setl	dl
	test	al, al
	sete	bl
	test	cl, cl
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	and	bl, dl
	test	cl, cl
	seta	cl
	test	edx, edx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	setne	cl
	mov	BYTE PTR _regflags+3, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4439_0@4 ENDP


@op_4458_0@4 PROC NEAR
	_start_func  'op_4458_0'
	shr	ecx, 8
	and	ecx, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	xor	edx, edx
	mov	ax, WORD PTR [esi+ebp]
	mov	dl, ah
	mov	dh, al
	lea	eax, DWORD PTR [esi+2]
	mov	edi, edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	movsx	eax, di
	neg	eax
	xor	ecx, ecx
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	and	dl, cl
	test	di, di
	mov	BYTE PTR _regflags+3, dl
	seta	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [esi+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4458_0@4 ENDP


@op_4460_0@4 PROC NEAR
	_start_func  'op_4460_0'
	shr	ecx, 8
	and	ecx, 7
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	xor	edx, edx
	sub	esi, 2
	mov	ax, WORD PTR [esi+ebp]
	mov	DWORD PTR _regs[ecx*4+32], esi
	mov	dl, ah
	xor	ecx, ecx
	mov	dh, al
	mov	edi, edx
	movsx	eax, di
	neg	eax
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	and	dl, cl
	test	di, di
	mov	BYTE PTR _regflags+3, dl
	seta	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [esi+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4460_0@4 ENDP


@op_4470_0@4 PROC NEAR
	_start_func  'op_4470_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	edi, eax
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [edi+ebp]
	mov	cl, ah
	mov	ch, al
	mov	esi, ecx
	movsx	ecx, si
	neg	ecx
	test	cx, cx
	setl	dl
	test	cx, cx
	sete	al
	test	si, si
	mov	BYTE PTR _regflags+1, al
	setl	al
	and	al, dl
	test	si, si
	mov	BYTE PTR _regflags+3, al
	seta	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	setne	dl
	xor	eax, eax
	mov	BYTE PTR _regflags, dl
	mov	al, ch
	mov	ah, cl
	mov	WORD PTR [edi+ebp], ax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4470_0@4 ENDP


@op_4478_0@4 PROC NEAR
	_start_func  'op_4478_0'
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	ebp, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	dh, al
	movsx	esi, cx
	movsx	eax, dx
	or	esi, eax
	xor	ecx, ecx
	mov	ax, WORD PTR [esi+ebp]
	mov	cl, ah
	mov	ch, al
	mov	edi, ecx
	xor	ecx, ecx
	movsx	eax, di
	neg	eax
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	dl
	test	di, di
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	and	dl, cl
	test	di, di
	mov	BYTE PTR _regflags+3, dl
	seta	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	setne	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [esi+ebp], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4478_0@4 ENDP


@op_4479_0@4 PROC NEAR
	_start_func  'op_4479_0'
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	edx, DWORD PTR _MEMBaseDiff
	xor	ecx, ecx
	mov	ax, WORD PTR [edx+edi]
	mov	cl, ah
	mov	ch, al
	mov	esi, ecx
	xor	ecx, ecx
	movsx	eax, si
	neg	eax
	test	ax, ax
	setl	cl
	test	ax, ax
	sete	bl
	test	si, si
	mov	BYTE PTR _regflags+1, bl
	setl	bl
	and	bl, cl
	test	si, si
	mov	BYTE PTR _regflags+3, bl
	seta	bl
	test	ecx, ecx
	setne	cl
	mov	BYTE PTR _regflags, cl
	xor	ecx, ecx
	mov	cl, ah
	mov	BYTE PTR _regflags+2, bl
	mov	ch, al
	mov	BYTE PTR _regflags+4, bl
	mov	WORD PTR [edx+edi], cx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4479_0@4 ENDP


@op_4490_0@4 PROC NEAR
	_start_func  'op_4490_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	push	esi
	shr	ecx, 8
	and	ecx, 7
	push	edi
	mov	edi, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR [eax+edi]
	bswap	esi
	mov	eax, esi
	mov	edx, 0
	neg	eax
	sets	dl
	test	eax, eax
	sete	cl
	test	esi, esi
	mov	BYTE PTR _regflags+1, cl
	setl	cl
	and	cl, dl
	test	esi, esi
	mov	BYTE PTR _regflags+3, cl
	seta	cl
	test	edx, edx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	setne	dl
	mov	BYTE PTR _regflags, dl
	add	ecx, edi
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4490_0@4 ENDP


@op_4498_0@4 PROC NEAR
	_start_func  'op_4498_0'
	mov	eax, DWORD PTR _MEMBaseDiff
	push	esi
	shr	ecx, 8
	and	ecx, 7
	push	edi
	mov	edi, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR [eax+edi]
	bswap	esi
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	eax, esi
	add	edx, 4
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	ecx, 0
	neg	eax
	sets	cl
	test	eax, eax
	sete	dl
	test	esi, esi
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	and	dl, cl
	test	esi, esi
	mov	BYTE PTR _regflags+3, dl
	seta	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setne	cl
	mov	BYTE PTR _regflags, cl
	lea	ecx, DWORD PTR [edx+edi]
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4498_0@4 ENDP


@op_44a0_0@4 PROC NEAR
	_start_func  'op_44a0_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	push	esi
	shr	ecx, 8
	and	ecx, 7
	push	edi
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	edi, DWORD PTR [edx+eax]
	bswap	edi
	mov	esi, edi
	mov	DWORD PTR _regs[ecx*4+32], eax
	neg	esi
	mov	ecx, 0
	sets	cl
	test	esi, esi
	sete	dl
	test	edi, edi
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	and	dl, cl
	test	edi, edi
	mov	BYTE PTR _regflags+3, dl
	seta	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setne	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44a0_0@4 ENDP


@op_44b0_0@4 PROC NEAR
	_start_func  'op_44b0_0'
	push	esi
	add	eax, 2
	push	edi
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	edi, eax
	mov	esi, DWORD PTR [ecx+edi]
	bswap	esi
	mov	ecx, esi
	mov	edx, 0
	neg	ecx
	sets	dl
	test	ecx, ecx
	sete	al
	test	esi, esi
	mov	BYTE PTR _regflags+1, al
	setl	al
	and	al, dl
	test	esi, esi
	mov	BYTE PTR _regflags+3, al
	seta	al
	test	edx, edx
	mov	BYTE PTR _regflags+2, al
	mov	BYTE PTR _regflags+4, al
	mov	eax, DWORD PTR _MEMBaseDiff
	setne	dl
	mov	BYTE PTR _regflags, dl
	add	eax, edi
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	pop	edi
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44b0_0@4 ENDP


@op_44b8_0@4 PROC NEAR
	_start_func  'op_44b8_0'
	xor	edx, edx
	push	esi
	push	edi
	mov	cx, WORD PTR [eax+2]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	eax, ecx
	mov	edi, DWORD PTR [edx+eax]
	bswap	edi
	mov	esi, edi
	mov	ecx, 0
	neg	esi
	sets	cl
	test	esi, esi
	sete	dl
	test	edi, edi
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	and	dl, cl
	test	edi, edi
	mov	BYTE PTR _regflags+3, dl
	seta	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setne	cl
	mov	BYTE PTR _regflags, cl
	add	eax, edx
	bswap	esi
	mov	DWORD PTR [eax], esi
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44b8_0@4 ENDP


@op_44b9_0@4 PROC NEAR
	_start_func  'op_44b9_0'
	push	esi
	push	edi
	mov	edi, DWORD PTR [eax+2]
	bswap	edi
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [ecx+edi]
	bswap	esi
	mov	eax, esi
	mov	ecx, 0
	neg	eax
	sets	cl
	test	eax, eax
	sete	dl
	test	esi, esi
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	and	dl, cl
	test	esi, esi
	mov	BYTE PTR _regflags+3, dl
	seta	dl
	test	ecx, ecx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	setne	cl
	mov	BYTE PTR _regflags, cl
	lea	ecx, DWORD PTR [edx+edi]
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	edi
	mov	DWORD PTR _regs+92, eax
	pop	esi
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44b9_0@4 ENDP


@op_44d0_0@4 PROC NEAR
	_start_func  'op_44d0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	bx, WORD PTR [eax+ecx]
	call	_MakeSR@0
	xor	edx, edx
	mov	dh, BYTE PTR _regs+77
	mov	dl, bh
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44d0_0@4 ENDP


@op_44e0_0@4 PROC NEAR
	_start_func  'op_44e0_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 2
	mov	bx, WORD PTR [edx+eax]
	mov	DWORD PTR _regs[ecx*4+32], eax
	call	_MakeSR@0
	xor	eax, eax
	mov	ah, BYTE PTR _regs+77
	mov	al, bh
	mov	WORD PTR _regs+76, ax
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44e0_0@4 ENDP


@op_44e8_0@4 PROC NEAR
	_start_func  'op_44e8_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	mov	bh, al
	shr	ecx, 8
	movsx	edx, dx
	movsx	eax, bx
	and	ecx, 7
	or	edx, eax
	mov	ebx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	add	edx, ebx
	mov	bx, WORD PTR [edx+ecx]
	call	_MakeSR@0
	xor	edx, edx
	mov	dh, BYTE PTR _regs+77
	mov	dl, bh
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44e8_0@4 ENDP


@op_44f0_0@4 PROC NEAR
	_start_func  'op_44f0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	bx, WORD PTR [ecx+eax]
	call	_MakeSR@0
	xor	edx, edx
	mov	dh, BYTE PTR _regs+77
	mov	dl, bh
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44f0_0@4 ENDP


@op_44f8_0@4 PROC NEAR
	_start_func  'op_44f8_0'
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	movsx	edx, cx
	xor	ecx, ecx
	mov	ch, al
	movsx	eax, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	bx, WORD PTR [edx+ecx]
	call	_MakeSR@0
	xor	edx, edx
	mov	dh, BYTE PTR _regs+77
	mov	dl, bh
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44f8_0@4 ENDP


@op_44f9_0@4 PROC NEAR
	_start_func  'op_44f9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	bx, WORD PTR [ecx+eax]
	call	_MakeSR@0
	xor	edx, edx
	mov	dh, BYTE PTR _regs+77
	mov	dl, bh
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44f9_0@4 ENDP


@op_44fa_0@4 PROC NEAR
	_start_func  'op_44fa_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	mov	bx, WORD PTR [edx+ecx+2]
	call	_MakeSR@0
	xor	ecx, ecx
	mov	ch, BYTE PTR _regs+77
	mov	cl, bh
	mov	WORD PTR _regs+76, cx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44fa_0@4 ENDP


@op_44fb_0@4 PROC NEAR
	_start_func  'op_44fb_0'
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	bx, WORD PTR [ecx+eax]
	call	_MakeSR@0
	xor	edx, edx
	mov	dh, BYTE PTR _regs+77
	mov	dl, bh
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44fb_0@4 ENDP


@op_44fc_0@4 PROC NEAR
	_start_func  'op_44fc_0'
	mov	bx, WORD PTR [eax+2]
	call	_MakeSR@0
	xor	ecx, ecx
	mov	ch, BYTE PTR _regs+77
	mov	cl, bh
	mov	WORD PTR _regs+76, cx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_44fc_0@4 ENDP


@op_4610_0@4 PROC NEAR
	_start_func  'op_4610_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	xor	dl, dl
	movsx	eax, BYTE PTR [esi+ecx]
	not	eax
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4610_0@4 ENDP


@op_4618_0@4 PROC NEAR
	_start_func  'op_4618_0'
	shr	ecx, 8
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	lea	esi, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	al, BYTE PTR [edi+edx]
	add	ecx, edx
	movsx	eax, al
	mov	DWORD PTR [esi], ecx
	xor	cl, cl
	not	eax
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+edx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4618_0@4 ENDP


@op_4620_0@4 PROC NEAR
	_start_func  'op_4620_0'
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	sub	eax, esi
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [esi+eax]
	mov	DWORD PTR [edx], eax
	movsx	ecx, cl
	not	ecx
	xor	dl, dl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4620_0@4 ENDP


@op_4628_0@4 PROC NEAR
	_start_func  'op_4628_0'
	mov	esi, ecx
	mov	cx, WORD PTR [eax+2]
	xor	edx, edx
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	shr	esi, 8
	and	esi, 7
	or	eax, ecx
	xor	dl, dl
	mov	ecx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	add	eax, ecx
	movsx	ecx, BYTE PTR [esi+eax]
	not	ecx
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4628_0@4 ENDP


@op_4630_0@4 PROC NEAR
	_start_func  'op_4630_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	xor	dl, dl
	movsx	ecx, BYTE PTR [esi+eax]
	not	ecx
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4630_0@4 ENDP


@op_4638_0@4 PROC NEAR
	_start_func  'op_4638_0'
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	dh, al
	movsx	ecx, cx
	movsx	eax, dx
	or	ecx, eax
	xor	dl, dl
	movsx	eax, BYTE PTR [esi+ecx]
	not	eax
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4638_0@4 ENDP


@op_4639_0@4 PROC NEAR
	_start_func  'op_4639_0'
	mov	ecx, DWORD PTR [eax+2]
	bswap	ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	xor	dl, dl
	movsx	eax, BYTE PTR [esi+ecx]
	not	eax
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4639_0@4 ENDP


@op_4650_0@4 PROC NEAR
	_start_func  'op_4650_0'
	shr	ecx, 8
	and	ecx, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	xor	eax, eax
	xor	edx, edx
	mov	cx, WORD PTR [edi+esi]
	mov	al, ch
	mov	dh, cl
	movsx	eax, ax
	movsx	ecx, dx
	or	eax, ecx
	xor	ecx, ecx
	not	eax
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4650_0@4 ENDP


@op_4658_0@4 PROC NEAR
	_start_func  'op_4658_0'
	shr	ecx, 8
	and	ecx, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	dx, WORD PTR [edi+esi]
	lea	eax, DWORD PTR [esi+2]
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	ecx, ecx
	mov	cl, dh
	movsx	eax, cx
	xor	ecx, ecx
	mov	ch, dl
	movsx	edx, cx
	or	eax, edx
	xor	ecx, ecx
	not	eax
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4658_0@4 ENDP


@op_4660_0@4 PROC NEAR
	_start_func  'op_4660_0'
	shr	ecx, 8
	and	ecx, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[ecx*4+32]
	xor	eax, eax
	sub	esi, 2
	mov	dx, WORD PTR [edi+esi]
	mov	DWORD PTR _regs[ecx*4+32], esi
	xor	ecx, ecx
	mov	al, dh
	mov	ch, dl
	movsx	eax, ax
	movsx	edx, cx
	or	eax, edx
	xor	ecx, ecx
	not	eax
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4660_0@4 ENDP


@op_4670_0@4 PROC NEAR
	_start_func  'op_4670_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [edi+esi]
	mov	cl, ah
	mov	dh, al
	movsx	ecx, cx
	movsx	eax, dx
	or	ecx, eax
	xor	eax, eax
	not	ecx
	cmp	cx, ax
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	cx, ax
	mov	BYTE PTR _regflags+3, al
	mov	BYTE PTR _regflags+1, dl
	setl	al
	xor	edx, edx
	mov	BYTE PTR _regflags, al
	mov	dl, ch
	mov	dh, cl
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4670_0@4 ENDP


@op_4678_0@4 PROC NEAR
	_start_func  'op_4678_0'
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	dh, al
	movsx	esi, cx
	movsx	eax, dx
	or	esi, eax
	xor	edx, edx
	mov	cx, WORD PTR [edi+esi]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	xor	ecx, ecx
	not	eax
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4678_0@4 ENDP


@op_4679_0@4 PROC NEAR
	_start_func  'op_4679_0'
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	cx, WORD PTR [edi+esi]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	or	eax, ecx
	xor	ecx, ecx
	not	eax
	cmp	ax, cx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+3, cl
	mov	BYTE PTR _regflags+1, dl
	setl	cl
	xor	edx, edx
	mov	BYTE PTR _regflags, cl
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR [edi+esi], dx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4679_0@4 ENDP


@op_46a0_0@4 PROC NEAR
	_start_func  'op_46a0_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	push	ebx
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	ecx, ecx
	not	edx
	cmp	edx, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	edx, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	mov	BYTE PTR _regflags, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, ecx
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46a0_0@4 ENDP


@op_46b0_0@4 PROC NEAR
	_start_func  'op_46b0_0'
	push	ebx
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+eax]
	bswap	ecx
	not	ecx
	xor	edx, edx
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46b0_0@4 ENDP


@op_46b8_0@4 PROC NEAR
	_start_func  'op_46b8_0'
	xor	edx, edx
	push	ebx
	mov	cx, WORD PTR [eax+2]
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	movsx	ecx, dx
	mov	edx, DWORD PTR _MEMBaseDiff
	or	eax, ecx
	mov	ecx, DWORD PTR [edx+eax]
	bswap	ecx
	not	ecx
	xor	edx, edx
	cmp	ecx, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ecx, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46b8_0@4 ENDP


@op_46b9_0@4 PROC NEAR
	_start_func  'op_46b9_0'
	push	ebx
	mov	ecx, DWORD PTR [eax+2]
	bswap	ecx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	not	eax
	xor	edx, edx
	cmp	eax, edx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	eax, edx
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	BYTE PTR _regflags+1, bl
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46b9_0@4 ENDP


@op_46d0_0@4 PROC NEAR
	_start_func  'op_46d0_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L91185
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L91185:
	shr	ecx, 8
	and	ecx, 7
	xor	edx, edx
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [eax+ecx]
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46d0_0@4 ENDP


@op_46e0_0@4 PROC NEAR
	_start_func  'op_46e0_0'
	mov	al, BYTE PTR _regs+80
	shr	ecx, 8
	and	ecx, 7
	test	al, al
	mov	edx, ecx
	jne	SHORT $L91194
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L91194:
	mov	eax, DWORD PTR _regs[edx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	eax, 2
	mov	cx, WORD PTR [ecx+eax]
	mov	DWORD PTR _regs[edx*4+32], eax
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46e0_0@4 ENDP


@op_46f0_0@4 PROC NEAR
	_start_func  'op_46f0_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L91203
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L91203:
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46f0_0@4 ENDP


@op_46f8_0@4 PROC NEAR
	_start_func  'op_46f8_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L91211
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L91211:
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	movsx	edx, cx
	xor	ecx, ecx
	mov	ch, al
	movsx	eax, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	ax, WORD PTR [edx+ecx]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46f8_0@4 ENDP


@op_46f9_0@4 PROC NEAR
	_start_func  'op_46f9_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L91222
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L91222:
	mov	eax, DWORD PTR _regs+92
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46f9_0@4 ENDP


@op_46fa_0@4 PROC NEAR
	_start_func  'op_46fa_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L91231
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L91231:
	mov	ecx, DWORD PTR _regs+92
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, eax
	add	edx, ebx
	mov	ax, WORD PTR [edx+ecx+2]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR _regs+76, cx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46fa_0@4 ENDP


@op_46fb_0@4 PROC NEAR
	_start_func  'op_46fb_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L91242
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L91242:
	mov	eax, DWORD PTR _regs+92
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	mov	dl, ah
	mov	dh, al
	mov	WORD PTR _regs+76, dx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46fb_0@4 ENDP


@op_46fc_0@4 PROC NEAR
	_start_func  'op_46fc_0'
	mov	al, BYTE PTR _regs+80
	test	al, al
	jne	SHORT $L91251
	push	0
	push	8
	call	_Exception@8
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
$L91251:
	mov	eax, DWORD PTR _regs+92
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	mov	ch, al
	mov	WORD PTR _regs+76, cx
	call	_MakeFromSR@0
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_46fc_0@4 ENDP


@op_4800_0@4 PROC NEAR
	_start_func  'op_4800_0'
	mov	dl, BYTE PTR _regflags+4
	shr	ecx, 8
	and	ecx, 7
	xor	eax, eax
	mov	esi, ecx
	test	dl, dl
	mov	cl, BYTE PTR _regs[esi*4]
	mov	dl, cl
	setne	al
	and	dl, 15					; 0000000fH
	and	ecx, 240				; 000000f0H
	movsx	dx, dl
	add	eax, edx
	neg	eax
	neg	ecx
	cmp	ax, 9
	jbe	SHORT $L91265
	add	eax, 65530				; 0000fffaH
	add	ecx, 65520				; 0000fff0H
$L91265:
	and	eax, 15					; 0000000fH
	mov	edx, 144				; 00000090H
	add	eax, ecx
	and	ecx, 496				; 000001f0H
	cmp	edx, ecx
	sbb	ecx, ecx
	neg	ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	je	SHORT $L91266
	add	eax, 65440				; 0000ffa0H
$L91266:
	mov	dl, BYTE PTR _regflags+1
	mov	BYTE PTR _regs[esi*4], al
	test	al, al
	sete	cl
	and	dl, cl
	test	al, al
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4800_0@4 ENDP


@op_4808_0@4 PROC NEAR
	_start_func  'op_4808_0'
	mov	eax, DWORD PTR _regs+60
	push	esi
	mov	esi, DWORD PTR _MEMBaseDiff
	add	eax, -4					; fffffffcH
	shr	ecx, 8
	and	ecx, 7
	mov	DWORD PTR _regs+60, eax
	add	eax, esi
	mov	edx, DWORD PTR _regs[ecx*4+32]
	bswap	edx
	mov	DWORD PTR [eax], edx
	mov	edx, DWORD PTR _regs+60
	mov	DWORD PTR _regs[ecx*4+32], edx
	mov	eax, DWORD PTR _regs+92
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _regs+60
	pop	esi
	add	ecx, eax
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+60, ecx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4808_0@4 ENDP


@op_4810_0@4 PROC NEAR
	_start_func  'op_4810_0'
	mov	dl, BYTE PTR _regflags+4
	shr	ecx, 8
	and	ecx, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	xor	eax, eax
	mov	esi, DWORD PTR _regs[ecx*4+32]
	test	dl, dl
	mov	cl, BYTE PTR [edi+esi]
	mov	dl, cl
	setne	al
	and	dl, 15					; 0000000fH
	and	ecx, 240				; 000000f0H
	movsx	dx, dl
	add	eax, edx
	neg	eax
	neg	ecx
	cmp	ax, 9
	jbe	SHORT $L91289
	add	eax, 65530				; 0000fffaH
	add	ecx, 65520				; 0000fff0H
$L91289:
	and	eax, 15					; 0000000fH
	mov	edx, 144				; 00000090H
	add	eax, ecx
	and	ecx, 496				; 000001f0H
	cmp	edx, ecx
	sbb	ecx, ecx
	neg	ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	je	SHORT $L91290
	add	eax, 65440				; 0000ffa0H
$L91290:
	mov	dl, BYTE PTR _regflags+1
	test	al, al
	sete	cl
	and	dl, cl
	test	al, al
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4810_0@4 ENDP


@op_4818_0@4 PROC NEAR
	_start_func  'op_4818_0'
	shr	ecx, 8
	and	ecx, 7
	mov	eax, ecx
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[eax*4+32]
	lea	edx, DWORD PTR _regs[eax*4+32]
	mov	eax, DWORD PTR _areg_byteinc[eax*4]
	mov	cl, BYTE PTR [edi+esi]
	add	eax, esi
	mov	DWORD PTR [edx], eax
	mov	dl, BYTE PTR _regflags+4
	xor	eax, eax
	test	dl, dl
	mov	dl, cl
	setne	al
	and	dl, 15					; 0000000fH
	and	ecx, 240				; 000000f0H
	movsx	dx, dl
	add	eax, edx
	neg	eax
	neg	ecx
	cmp	ax, 9
	jbe	SHORT $L91303
	add	eax, 65530				; 0000fffaH
	add	ecx, 65520				; 0000fff0H
$L91303:
	and	eax, 15					; 0000000fH
	mov	edx, 144				; 00000090H
	add	eax, ecx
	and	ecx, 496				; 000001f0H
	cmp	edx, ecx
	sbb	ecx, ecx
	neg	ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	je	SHORT $L91304
	add	eax, 65440				; 0000ffa0H
$L91304:
	mov	dl, BYTE PTR _regflags+1
	test	al, al
	sete	cl
	and	dl, cl
	test	al, al
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4818_0@4 ENDP


@op_4820_0@4 PROC NEAR
	_start_func  'op_4820_0'
	shr	ecx, 8
	and	ecx, 7
	mov	dl, BYTE PTR _regflags+4
	mov	esi, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _areg_byteinc[ecx*4]
	lea	eax, DWORD PTR _regs[ecx*4+32]
	sub	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, BYTE PTR [edi+esi]
	mov	DWORD PTR [eax], esi
	xor	eax, eax
	test	dl, dl
	mov	dl, cl
	setne	al
	and	dl, 15					; 0000000fH
	and	ecx, 240				; 000000f0H
	movsx	dx, dl
	add	eax, edx
	neg	eax
	neg	ecx
	cmp	ax, 9
	jbe	SHORT $L91317
	add	eax, 65530				; 0000fffaH
	add	ecx, 65520				; 0000fff0H
$L91317:
	and	eax, 15					; 0000000fH
	mov	edx, 144				; 00000090H
	add	eax, ecx
	and	ecx, 496				; 000001f0H
	cmp	edx, ecx
	sbb	ecx, ecx
	neg	ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	je	SHORT $L91318
	add	eax, 65440				; 0000ffa0H
$L91318:
	mov	dl, BYTE PTR _regflags+1
	test	al, al
	sete	cl
	and	dl, cl
	test	al, al
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4820_0@4 ENDP


@op_4828_0@4 PROC NEAR
	_start_func  'op_4828_0'
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	dl, ah
	movsx	esi, dx
	xor	edx, edx
	mov	dh, al
	shr	ecx, 8
	movsx	eax, dx
	and	ecx, 7
	mov	dl, BYTE PTR _regflags+4
	or	esi, eax
	xor	eax, eax
	mov	edi, DWORD PTR _regs[ecx*4+32]
	add	esi, edi
	mov	edi, DWORD PTR _MEMBaseDiff
	test	dl, dl
	mov	cl, BYTE PTR [edi+esi]
	mov	dl, cl
	setne	al
	and	dl, 15					; 0000000fH
	and	ecx, 240				; 000000f0H
	movsx	dx, dl
	add	eax, edx
	neg	eax
	neg	ecx
	cmp	ax, 9
	jbe	SHORT $L91334
	add	eax, 65530				; 0000fffaH
	add	ecx, 65520				; 0000fff0H
$L91334:
	and	eax, 15					; 0000000fH
	mov	edx, 144				; 00000090H
	add	eax, ecx
	and	ecx, 496				; 000001f0H
	cmp	edx, ecx
	sbb	ecx, ecx
	neg	ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	je	SHORT $L91335
	add	eax, 65440				; 0000ffa0H
$L91335:
	mov	dl, BYTE PTR _regflags+1
	test	al, al
	sete	cl
	and	dl, cl
	test	al, al
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4828_0@4 ENDP


@op_4830_0@4 PROC NEAR
	_start_func  'op_4830_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, eax
	mov	al, BYTE PTR _regflags+4
	xor	ecx, ecx
	mov	dl, BYTE PTR [edi+esi]
	test	al, al
	mov	al, dl
	setne	cl
	and	al, 15					; 0000000fH
	and	edx, 240				; 000000f0H
	movsx	ax, al
	add	ecx, eax
	neg	ecx
	neg	edx
	cmp	cx, 9
	jbe	SHORT $L91348
	add	ecx, 65530				; 0000fffaH
	add	edx, 65520				; 0000fff0H
$L91348:
	and	ecx, 15					; 0000000fH
	mov	eax, 144				; 00000090H
	add	ecx, edx
	and	edx, 496				; 000001f0H
	cmp	eax, edx
	sbb	edx, edx
	neg	edx
	mov	BYTE PTR _regflags+2, dl
	mov	BYTE PTR _regflags+4, dl
	je	SHORT $L91349
	add	ecx, 65440				; 0000ffa0H
$L91349:
	mov	al, BYTE PTR _regflags+1
	test	cl, cl
	sete	dl
	and	al, dl
	test	cl, cl
	mov	BYTE PTR _regflags+1, al
	setl	al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR [edi+esi], cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4830_0@4 ENDP


@op_4838_0@4 PROC NEAR
	_start_func  'op_4838_0'
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	dh, al
	movsx	esi, cx
	movsx	eax, dx
	mov	dl, BYTE PTR _regflags+4
	or	esi, eax
	xor	eax, eax
	mov	cl, BYTE PTR [edi+esi]
	test	dl, dl
	mov	dl, cl
	setne	al
	and	dl, 15					; 0000000fH
	and	ecx, 240				; 000000f0H
	movsx	dx, dl
	add	eax, edx
	neg	eax
	neg	ecx
	cmp	ax, 9
	jbe	SHORT $L91364
	add	eax, 65530				; 0000fffaH
	add	ecx, 65520				; 0000fff0H
$L91364:
	and	eax, 15					; 0000000fH
	mov	edx, 144				; 00000090H
	add	eax, ecx
	and	ecx, 496				; 000001f0H
	cmp	edx, ecx
	sbb	ecx, ecx
	neg	ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	je	SHORT $L91365
	add	eax, 65440				; 0000ffa0H
$L91365:
	mov	dl, BYTE PTR _regflags+1
	test	al, al
	sete	cl
	and	dl, cl
	test	al, al
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4838_0@4 ENDP


@op_4839_0@4 PROC NEAR
	_start_func  'op_4839_0'
	mov	esi, DWORD PTR [eax+2]
	bswap	esi
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	dl, BYTE PTR _regflags+4
	xor	eax, eax
	mov	cl, BYTE PTR [edi+esi]
	test	dl, dl
	mov	dl, cl
	setne	al
	and	dl, 15					; 0000000fH
	and	ecx, 240				; 000000f0H
	movsx	dx, dl
	add	eax, edx
	neg	eax
	neg	ecx
	cmp	ax, 9
	jbe	SHORT $L91378
	add	eax, 65530				; 0000fffaH
	add	ecx, 65520				; 0000fff0H
$L91378:
	and	eax, 15					; 0000000fH
	mov	edx, 144				; 00000090H
	add	eax, ecx
	and	ecx, 496				; 000001f0H
	cmp	edx, ecx
	sbb	ecx, ecx
	neg	ecx
	mov	BYTE PTR _regflags+2, cl
	mov	BYTE PTR _regflags+4, cl
	je	SHORT $L91379
	add	eax, 65440				; 0000ffa0H
$L91379:
	mov	dl, BYTE PTR _regflags+1
	test	al, al
	sete	cl
	and	dl, cl
	test	al, al
	mov	BYTE PTR _regflags+1, dl
	setl	dl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [edi+esi], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4839_0@4 ENDP


@op_4848_0@4 PROC NEAR
	_start_func  'op_4848_0'
	jmp	illegal2byteop
@op_4848_0@4 ENDP


@op_4878_0@4 PROC NEAR
	_start_func  'op_4878_0'
	mov	ecx, DWORD PTR _regs+60
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, -4					; fffffffcH
	mov	ax, WORD PTR [eax+2]
	mov	DWORD PTR _regs+60, ecx
	push	ebx
	add	ecx, edx
	xor	edx, edx
	xor	ebx, ebx
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	pop	ebx
	bswap	edx
	mov	DWORD PTR [ecx], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4878_0@4 ENDP


@op_4879_0@4 PROC NEAR
	_start_func  'op_4879_0'
	mov	ecx, DWORD PTR [eax+2]
	bswap	ecx
	mov	edx, DWORD PTR _regs+60
	lea	eax, DWORD PTR [edx-4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _regs+60, eax
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4879_0@4 ENDP


@op_487a_0@4 PROC NEAR
	_start_func  'op_487a_0'
	mov	ecx, eax
	push	ebx
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _regs+88
	or	edx, eax
	sub	edx, DWORD PTR _regs+96
	add	edx, ebx
	lea	ecx, DWORD PTR [edx+ecx+2]
	mov	edx, DWORD PTR _regs+60
	lea	eax, DWORD PTR [edx-4]
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	DWORD PTR _regs+60, eax
	add	eax, edx
	bswap	ecx
	mov	DWORD PTR [eax], ecx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_487a_0@4 ENDP


@op_487b_0@4 PROC NEAR
	_start_func  'op_487b_0'
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _regs+60
	mov	edx, DWORD PTR _MEMBaseDiff
	add	ecx, -4					; fffffffcH
	mov	DWORD PTR _regs+60, ecx
	add	ecx, edx
	bswap	eax
	mov	DWORD PTR [ecx], eax
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_487b_0@4 ENDP


@op_48b0_0@4 PROC NEAR
	_start_func  'op_48b0_0'
	mov	esi, eax
	xor	ebx, ebx
	shr	ecx, 8
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	bl, ah
	mov	DWORD PTR _regs+92, esi
	mov	dx, WORD PTR [esi]
	mov	bh, al
	add	esi, 2
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	cl, bl
	mov	esi, eax
	and	ecx, 255				; 000000ffH
	xor	eax, eax
	mov	edx, ecx
	mov	al, bh
	test	dx, dx
	mov	edi, eax
	je	SHORT $L125788
$L91424:
	and	edx, 65535				; 0000ffffH
	add	esi, 2
	shl	edx, 2
	mov	ecx, DWORD PTR _movem_index1[edx]
	mov	ax, WORD PTR _regs[ecx*4]
	xor	ecx, ecx
	mov	cl, ah
	mov	ch, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+esi-2], cx
	mov	dx, WORD PTR _movem_next[edx]
	test	dx, dx
	jne	SHORT $L91424
$L125788:
	test	di, di
	je	SHORT $L125791
$L91427:
	mov	ecx, edi
	add	esi, 2
	and	ecx, 65535				; 0000ffffH
	shl	ecx, 2
	mov	edx, DWORD PTR _movem_index1[ecx]
	mov	ax, WORD PTR _regs[edx*4+32]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+esi-2], dx
	mov	di, WORD PTR _movem_next[ecx]
	test	di, di
	jne	SHORT $L91427
$L125791:
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_48b0_0@4 ENDP


@op_48b8_0@4 PROC NEAR
	_start_func  'op_48b8_0'
	mov	edx, eax
	xor	ecx, ecx
	xor	ebx, ebx
	mov	ax, WORD PTR [edx+2]
	mov	dx, WORD PTR [edx+4]
	mov	cl, ah
	mov	bh, dl
	mov	ch, al
	xor	eax, eax
	mov	al, dh
	movsx	eax, ax
	movsx	edx, bx
	or	eax, edx
	mov	dl, cl
	and	edx, 255				; 000000ffH
	mov	edi, edx
	xor	edx, edx
	mov	dl, ch
	test	di, di
	mov	esi, edx
	je	SHORT $L125814
$L91441:
	and	edi, 65535				; 0000ffffH
	xor	edx, edx
	shl	edi, 2
	add	eax, 2
	mov	ecx, DWORD PTR _movem_index1[edi]
	mov	cx, WORD PTR _regs[ecx*4]
	mov	dl, ch
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+eax-2], dx
	mov	di, WORD PTR _movem_next[edi]
	test	di, di
	jne	SHORT $L91441
$L125814:
	test	si, si
	je	SHORT $L125817
$L91444:
	and	esi, 65535				; 0000ffffH
	add	eax, 2
	shl	esi, 2
	mov	edx, DWORD PTR _movem_index1[esi]
	mov	cx, WORD PTR _regs[edx*4+32]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+eax-2], dx
	mov	si, WORD PTR _movem_next[esi]
	test	si, si
	jne	SHORT $L91444
$L125817:
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_48b8_0@4 ENDP


@op_48b9_0@4 PROC NEAR
	_start_func  'op_48b9_0'
	mov	ecx, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	mov	esi, ecx
	mov	cl, al
	xor	edx, edx
	and	ecx, 255				; 000000ffH
	mov	dl, ah
	test	cx, cx
	mov	edi, edx
	je	SHORT $L125841
$L91456:
	and	ecx, 65535				; 0000ffffH
	xor	edx, edx
	shl	ecx, 2
	add	esi, 2
	mov	eax, DWORD PTR _movem_index1[ecx]
	mov	ax, WORD PTR _regs[eax*4]
	mov	dl, ah
	mov	dh, al
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [eax+esi-2], dx
	mov	cx, WORD PTR _movem_next[ecx]
	test	cx, cx
	jne	SHORT $L91456
$L125841:
	test	di, di
	je	SHORT $L125844
$L91459:
	mov	eax, edi
	xor	edx, edx
	and	eax, 65535				; 0000ffffH
	add	esi, 2
	shl	eax, 2
	mov	ecx, DWORD PTR _movem_index1[eax]
	mov	cx, WORD PTR _regs[ecx*4+32]
	mov	dl, ch
	mov	dh, cl
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	WORD PTR [ecx+esi-2], dx
	mov	di, WORD PTR _movem_next[eax]
	test	di, di
	jne	SHORT $L91459
$L125844:
	mov	eax, DWORD PTR _regs+92
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_48b9_0@4 ENDP


@op_48f0_0@4 PROC NEAR
	_start_func  'op_48f0_0'
	push	ebx
	push	esi
	mov	esi, DWORD PTR _regs+92
	xor	ebx, ebx
	shr	ecx, 8
	mov	ax, WORD PTR [esi+2]
	add	esi, 4
	mov	bl, ah
	mov	DWORD PTR _regs+92, esi
	mov	dx, WORD PTR [esi]
	mov	bh, al
	add	esi, 2
	and	ecx, 7
	mov	eax, edx
	mov	DWORD PTR _regs+92, esi
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	cl, bl
	and	ecx, 255				; 000000ffH
	mov	esi, ecx
	xor	ecx, ecx
	test	si, si
	mov	cl, bh
	je	SHORT $L125871
	push	edi
$L91471:
	mov	edx, esi
	mov	edi, DWORD PTR _MEMBaseDiff
	and	edx, 65535				; 0000ffffH
	add	edi, eax
	shl	edx, 2
	mov	esi, DWORD PTR _movem_index1[edx]
	mov	esi, DWORD PTR _regs[esi*4]
	bswap	esi
	mov	DWORD PTR [edi], esi
	mov	si, WORD PTR _movem_next[edx]
	add	eax, 4
	test	si, si
	jne	SHORT $L91471
	pop	edi
$L125871:
	test	cx, cx
	je	SHORT $L125874
$L91474:
	mov	esi, DWORD PTR _MEMBaseDiff
	and	ecx, 65535				; 0000ffffH
	shl	ecx, 2
	add	esi, eax
	mov	edx, DWORD PTR _movem_index1[ecx]
	mov	edx, DWORD PTR _regs[edx*4+32]
	bswap	edx
	mov	DWORD PTR [esi], edx
	mov	cx, WORD PTR _movem_next[ecx]
	add	eax, 4
	test	cx, cx
	jne	SHORT $L91474
$L125874:
	pop	esi
	pop	ebx
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_48f0_0@4 ENDP


@op_48f8_0@4 PROC NEAR
	_start_func  'op_48f8_0'
	mov	ecx, eax
	xor	edx, edx
	push	ebx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	cx, WORD PTR [ecx+4]
	mov	dl, ah
	mov	bh, cl
	mov	dh, al
	push	esi
	mov	eax, edx
	xor	edx, edx
	mov	dl, ch
	movsx	edx, dx
	movsx	ecx, bx
	or	edx, ecx
	mov	cl, al
	and	ecx, 255				; 000000ffH
	mov	esi, ecx
	xor	ecx, ecx
	mov	cl, ah
	test	si, si
	mov	eax, ecx
	je	SHORT $L125896
	push	edi
$L91488:
	mov	ecx, esi
	mov	edi, DWORD PTR _MEMBaseDiff
	and	ecx, 65535				; 0000ffffH
	add	edi, edx
	shl	ecx, 2
	mov	esi, DWORD PTR _movem_index1[ecx]
	mov	esi, DWORD PTR _regs[esi*4]
	bswap	esi
	mov	DWORD PTR [edi], esi
	mov	si, WORD PTR _movem_next[ecx]
	add	edx, 4
	test	si, si
	jne	SHORT $L91488
	pop	edi
$L125896:
	test	ax, ax
	je	SHORT $L125899
$L91491:
	mov	esi, DWORD PTR _MEMBaseDiff
	and	eax, 65535				; 0000ffffH
	shl	eax, 2
	add	esi, edx
	mov	ecx, DWORD PTR _movem_index1[eax]
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	bswap	ecx
	mov	DWORD PTR [esi], ecx
	mov	ax, WORD PTR _movem_next[eax]
	add	edx, 4
	test	ax, ax
	jne	SHORT $L91491
$L125899:
	mov	eax, DWORD PTR _regs+92
	pop	esi
	add	eax, 6
	pop	ebx
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_48f8_0@4 ENDP


@op_48f9_0@4 PROC NEAR
	_start_func  'op_48f9_0'
	mov	ecx, eax
	xor	edx, edx
	push	esi
	mov	ax, WORD PTR [ecx+2]
	mov	ecx, DWORD PTR [ecx+4]
	bswap	ecx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	mov	edx, ecx
	mov	cl, al
	and	ecx, 255				; 000000ffH
	mov	esi, ecx
	xor	ecx, ecx
	mov	cl, ah
	test	si, si
	mov	eax, ecx
	je	SHORT $L125922
	push	edi
$L91503:
	mov	ecx, esi
	mov	edi, DWORD PTR _MEMBaseDiff
	and	ecx, 65535				; 0000ffffH
	add	edi, edx
	shl	ecx, 2
	mov	esi, DWORD PTR _movem_index1[ecx]
	mov	esi, DWORD PTR _regs[esi*4]
	bswap	esi
	mov	DWORD PTR [edi], esi
	mov	si, WORD PTR _movem_next[ecx]
	add	edx, 4
	test	si, si
	jne	SHORT $L91503
	pop	edi
$L125922:
	test	ax, ax
	je	SHORT $L125925
$L91506:
	mov	esi, DWORD PTR _MEMBaseDiff
	and	eax, 65535				; 0000ffffH
	shl	eax, 2
	add	esi, edx
	mov	ecx, DWORD PTR _movem_index1[eax]
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	bswap	ecx
	mov	DWORD PTR [esi], ecx
	mov	ax, WORD PTR _movem_next[eax]
	add	edx, 4
	test	ax, ax
	jne	SHORT $L91506
$L125925:
	mov	eax, DWORD PTR _regs+92
	pop	esi
	add	eax, 8
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_48f9_0@4 ENDP


@op_4a20_0@4 PROC NEAR
	_start_func  'op_4a20_0'
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	esi, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	eax, esi
	mov	cl, BYTE PTR [ecx+eax]
	mov	DWORD PTR [edx], eax
	xor	al, al
	cmp	cl, al
	mov	BYTE PTR _regflags+2, al
	sete	dl
	cmp	cl, al
	mov	BYTE PTR _regflags+3, al
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a20_0@4 ENDP


@op_4a38_0@4 PROC NEAR
	_start_func  'op_4a38_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [edx+eax]
	xor	dl, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	add	ecx, 4
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, ecx
	mov	eax,ecx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a38_0@4 ENDP


@op_4a39_0@4 PROC NEAR
	_start_func  'op_4a39_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [ecx+eax]
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a39_0@4 ENDP


@op_4a3a_0@4 PROC NEAR
	_start_func  'op_4a3a_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	cx, WORD PTR [eax+2]
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, ecx
	add	edx, ebx
	mov	cl, BYTE PTR [edx+eax+2]
	xor	dl, dl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	add	eax, 4
	mov	BYTE PTR _regflags+1, bl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a3a_0@4 ENDP


@op_4a3b_0@4 PROC NEAR
	_start_func  'op_4a3b_0'
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	al, BYTE PTR [ecx+eax]
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a3b_0@4 ENDP


@op_4a3c_0@4 PROC NEAR
	_start_func  'op_4a3c_0'
	mov	ecx, eax
	xor	dl, dl
	mov	al, BYTE PTR [ecx+3]
	mov	BYTE PTR _regflags+2, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+1, bl
	setl	al
	add	ecx, 4
	mov	BYTE PTR _regflags, al
	mov	DWORD PTR _regs+92, ecx
	mov	eax,ecx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a3c_0@4 ENDP


@op_4a60_0@4 PROC NEAR
	_start_func  'op_4a60_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	eax, DWORD PTR _regs[esi*4+32]
	sub	eax, 2
	mov	cx, WORD PTR [ecx+eax]
	mov	DWORD PTR _regs[esi*4+32], eax
	mov	dl, ch
	xor	eax, eax
	mov	dh, cl
	mov	BYTE PTR _regflags+2, al
	mov	ecx, edx
	mov	BYTE PTR _regflags+3, al
	cmp	cx, ax
	sete	dl
	cmp	cx, ax
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a60_0@4 ENDP


@op_4a78_0@4 PROC NEAR
	_start_func  'op_4a78_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	or	edx, eax
	mov	eax, DWORD PTR _MEMBaseDiff
	mov	ax, WORD PTR [edx+eax]
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+1, bl
	setl	al
	add	ecx, 4
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regflags+3, dl
	mov	DWORD PTR _regs+92, ecx
	mov	eax,ecx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a78_0@4 ENDP


@op_4a79_0@4 PROC NEAR
	_start_func  'op_4a79_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	mov	dl, ah
	mov	BYTE PTR _regflags+2, cl
	mov	dh, al
	mov	BYTE PTR _regflags+3, cl
	mov	eax, edx
	cmp	ax, cx
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a79_0@4 ENDP


@op_4a7a_0@4 PROC NEAR
	_start_func  'op_4a7a_0'
	xor	edx, edx
	xor	ebx, ebx
	mov	cx, WORD PTR [eax+2]
	mov	dl, ch
	mov	bh, cl
	movsx	edx, dx
	movsx	ecx, bx
	mov	ebx, DWORD PTR _regs+96
	or	edx, ecx
	mov	ecx, DWORD PTR _MEMBaseDiff
	sub	edx, ebx
	mov	ebx, DWORD PTR _regs+88
	add	edx, ecx
	add	edx, ebx
	mov	cx, WORD PTR [edx+eax+2]
	xor	edx, edx
	mov	dl, ch
	mov	dh, cl
	mov	ecx, edx
	xor	edx, edx
	cmp	cx, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cx, dx
	mov	BYTE PTR _regflags+1, bl
	setl	cl
	add	eax, 4
	mov	BYTE PTR _regflags+3, dl
	mov	DWORD PTR _regs+92, eax
	mov	BYTE PTR _regflags, cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a7a_0@4 ENDP


@op_4a7b_0@4 PROC NEAR
	_start_func  'op_4a7b_0'
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	xor	edx, edx
	mov	ax, WORD PTR [ecx+eax]
	xor	ecx, ecx
	mov	dl, ah
	mov	BYTE PTR _regflags+2, cl
	mov	dh, al
	mov	BYTE PTR _regflags+3, cl
	mov	eax, edx
	cmp	ax, cx
	sete	dl
	cmp	ax, cx
	mov	BYTE PTR _regflags+1, dl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a7b_0@4 ENDP


@op_4a7c_0@4 PROC NEAR
	_start_func  'op_4a7c_0'
	mov	ecx, eax
	xor	edx, edx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	dh, al
	mov	eax, edx
	xor	edx, edx
	cmp	ax, dx
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	ax, dx
	mov	BYTE PTR _regflags+1, bl
	setl	al
	add	ecx, 4
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regflags+3, dl
	mov	DWORD PTR _regs+92, ecx
	mov	eax,ecx
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4a7c_0@4 ENDP


@op_4aa0_0@4 PROC NEAR
	_start_func  'op_4aa0_0'
	mov	edx, DWORD PTR _MEMBaseDiff
	shr	ecx, 8
	and	ecx, 7
	mov	eax, DWORD PTR _regs[ecx*4+32]
	sub	eax, 4
	mov	edx, DWORD PTR [edx+eax]
	bswap	edx
	mov	DWORD PTR _regs[ecx*4+32], eax
	xor	eax, eax
	cmp	edx, eax
	mov	BYTE PTR _regflags+2, al
	sete	cl
	mov	BYTE PTR _regflags+3, al
	cmp	edx, eax
	mov	eax, DWORD PTR _regs+92
	mov	BYTE PTR _regflags+1, cl
	setl	dl
	add	eax, 2
	mov	BYTE PTR _regflags, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4aa0_0@4 ENDP


@op_4ab8_0@4 PROC NEAR
	_start_func  'op_4ab8_0'
	xor	ecx, ecx
	mov	ax, WORD PTR [eax+2]
	mov	cl, ah
	movsx	edx, cx
	xor	ecx, ecx
	mov	ch, al
	movsx	eax, cx
	mov	ecx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	eax, DWORD PTR [edx+ecx]
	bswap	eax
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ab8_0@4 ENDP


@op_4ab9_0@4 PROC NEAR
	_start_func  'op_4ab9_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ab9_0@4 ENDP


@op_4aba_0@4 PROC NEAR
	_start_func  'op_4aba_0'
	mov	ecx, eax
	xor	edx, edx
	xor	ebx, ebx
	mov	ax, WORD PTR [ecx+2]
	mov	dl, ah
	mov	bh, al
	movsx	edx, dx
	movsx	eax, bx
	mov	ebx, DWORD PTR _MEMBaseDiff
	or	edx, eax
	mov	eax, DWORD PTR _regs+96
	sub	edx, eax
	mov	eax, DWORD PTR _regs+88
	add	edx, ebx
	add	edx, eax
	mov	eax, DWORD PTR [edx+ecx+2]
	bswap	eax
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4aba_0@4 ENDP


@op_4abb_0@4 PROC NEAR
	_start_func  'op_4abb_0'
	mov	ecx, DWORD PTR _regs+88
	mov	edx, DWORD PTR _regs+96
	add	eax, 2
	sub	ecx, edx
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	ecx, eax
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	BYTE PTR _regflags+1, dl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4abb_0@4 ENDP


@op_4abc_0@4 PROC NEAR
	_start_func  'op_4abc_0'
	mov	eax, DWORD PTR [eax+2]
	bswap	eax
	xor	ecx, ecx
	cmp	eax, ecx
	mov	BYTE PTR _regflags+2, cl
	sete	dl
	cmp	eax, ecx
	mov	BYTE PTR _regflags+3, cl
	setl	al
	mov	BYTE PTR _regflags, al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	BYTE PTR _regflags+1, dl
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4abc_0@4 ENDP


@op_4ac0_0@4 PROC NEAR
	_start_func  'op_4ac0_0'
	shr	ecx, 8
	and	ecx, 7
	xor	dl, dl
	mov	BYTE PTR _regflags+2, dl
	mov	al, BYTE PTR _regs[ecx*4]
	mov	BYTE PTR _regflags+3, dl
	cmp	al, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	or	al, 128					; 00000080H
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR _regs[ecx*4], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ac0_0@4 ENDP


@op_4ad0_0@4 PROC NEAR
	_start_func  'op_4ad0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	xor	dl, dl
	mov	al, BYTE PTR [esi+ecx]
	mov	BYTE PTR _regflags+2, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	or	al, 128					; 00000080H
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ad0_0@4 ENDP


@op_4ad8_0@4 PROC NEAR
	_start_func  'op_4ad8_0'
	shr	ecx, 8
	and	ecx, 7
	mov	edx, DWORD PTR _regs[ecx*4+32]
	mov	edi, DWORD PTR _MEMBaseDiff
	lea	esi, DWORD PTR _regs[ecx*4+32]
	mov	ecx, DWORD PTR _areg_byteinc[ecx*4]
	mov	al, BYTE PTR [edi+edx]
	add	ecx, edx
	mov	DWORD PTR [esi], ecx
	xor	cl, cl
	cmp	al, cl
	mov	BYTE PTR _regflags+2, cl
	sete	bl
	cmp	al, cl
	mov	BYTE PTR _regflags+3, cl
	setl	cl
	or	al, 128					; 00000080H
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, cl
	mov	BYTE PTR [edi+edx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ad8_0@4 ENDP


@op_4ae0_0@4 PROC NEAR
	_start_func  'op_4ae0_0'
	shr	ecx, 8
	and	ecx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR _regs[ecx*4+32]
	mov	ebx, DWORD PTR _areg_byteinc[ecx*4]
	lea	edx, DWORD PTR _regs[ecx*4+32]
	sub	eax, ebx
	mov	cl, BYTE PTR [esi+eax]
	mov	DWORD PTR [edx], eax
	xor	dl, dl
	cmp	cl, dl
	mov	BYTE PTR _regflags+2, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	setl	dl
	or	cl, 128					; 00000080H
	mov	BYTE PTR _regflags+1, bl
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ae0_0@4 ENDP


@op_4ae8_0@4 PROC NEAR
	_start_func  'op_4ae8_0'
	mov	esi, ecx
	mov	cx, WORD PTR [eax+2]
	xor	edx, edx
	mov	dl, ch
	movsx	eax, dx
	xor	edx, edx
	mov	dh, cl
	shr	esi, 8
	movsx	ecx, dx
	and	esi, 7
	or	eax, ecx
	xor	dl, dl
	mov	ebx, DWORD PTR _regs[esi*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	add	eax, ebx
	mov	cl, BYTE PTR [esi+eax]
	mov	BYTE PTR _regflags+2, dl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	or	cl, 128					; 00000080H
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4ae8_0@4 ENDP


@op_4af0_0@4 PROC NEAR
	_start_func  'op_4af0_0'
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	shr	ecx, 8
	mov	DWORD PTR _regs+92, eax
	and	ecx, 7
	mov	eax, edx
	mov	ecx, DWORD PTR _regs[ecx*4+32]
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	esi, DWORD PTR _MEMBaseDiff
	xor	dl, dl
	mov	cl, BYTE PTR [esi+eax]
	mov	BYTE PTR _regflags+2, dl
	cmp	cl, dl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	cl, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	or	cl, 128					; 00000080H
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+eax], cl
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4af0_0@4 ENDP


@op_4af8_0@4 PROC NEAR
	_start_func  'op_4af8_0'
	xor	ecx, ecx
	xor	edx, edx
	mov	ax, WORD PTR [eax+2]
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	cl, ah
	mov	dh, al
	movsx	ecx, cx
	movsx	eax, dx
	or	ecx, eax
	xor	dl, dl
	mov	al, BYTE PTR [esi+ecx]
	mov	BYTE PTR _regflags+2, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	or	al, 128					; 00000080H
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4af8_0@4 ENDP


@op_4af9_0@4 PROC NEAR
	_start_func  'op_4af9_0'
	mov	ecx, DWORD PTR [eax+2]
	bswap	ecx
	mov	esi, DWORD PTR _MEMBaseDiff
	xor	dl, dl
	mov	al, BYTE PTR [esi+ecx]
	mov	BYTE PTR _regflags+2, dl
	cmp	al, dl
	mov	BYTE PTR _regflags+3, dl
	sete	bl
	cmp	al, dl
	mov	BYTE PTR _regflags+1, bl
	setl	dl
	or	al, 128					; 00000080H
	mov	BYTE PTR _regflags, dl
	mov	BYTE PTR [esi+ecx], al
	mov	eax, DWORD PTR _regs+92
	add	eax, 6
	mov	DWORD PTR _regs+92, eax
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4af9_0@4 ENDP


@op_4c10_0@4 PROC NEAR
	_start_func  'op_4c10_0'
	mov	edx, ecx
	shr	edx, 8
	mov	ax, WORD PTR [eax+2]
	and	edx, 7
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	edx, DWORD PTR _regs[edx*4+32]
	mov	esi, DWORD PTR [edx+esi]
	bswap	esi
	mov	edx, DWORD PTR _regs+92
	add	edx, 4
	mov	DWORD PTR _regs+92, edx
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	push	edx
	push	esi
	push	ecx
	call	_m68k_mull@12
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4c10_0@4 ENDP


@op_4c18_0@4 PROC NEAR
	_start_func  'op_4c18_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 8
	mov	dx, WORD PTR [edx+2]
	and	eax, 7
	mov	edi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR _regs[eax*4+32]
	mov	esi, DWORD PTR [esi+edi]
	bswap	esi
	mov	ebx, DWORD PTR _regs[eax*4+32]
	mov	edi, 4
	add	ebx, edi
	mov	DWORD PTR _regs[eax*4+32], ebx
	mov	eax, DWORD PTR _regs+92
	add	eax, edi
	mov	DWORD PTR _regs+92, eax
	xor	eax, eax
	mov	al, dh
	mov	ah, dl
	push	eax
	push	esi
	push	ecx
	call	_m68k_mull@12
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4c18_0@4 ENDP


@op_4c20_0@4 PROC NEAR
	_start_func  'op_4c20_0'
	mov	edx, eax
	mov	eax, ecx
	shr	eax, 8
	and	eax, 7
	mov	bx, WORD PTR [edx+2]
	mov	edx, DWORD PTR _regs[eax*4+32]
	mov	esi, DWORD PTR _MEMBaseDiff
	sub	edx, 4
	mov	esi, DWORD PTR [esi+edx]
	bswap	esi
	mov	DWORD PTR _regs[eax*4+32], edx
	mov	eax, DWORD PTR _regs+92
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	xor	eax, eax
	mov	al, bh
	mov	ah, bl
	push	eax
	push	esi
	push	ecx
	call	_m68k_mull@12
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4c20_0@4 ENDP


@op_4c30_0@4 PROC NEAR
	_start_func  'op_4c30_0'
	mov	esi, ecx
	mov	bx, WORD PTR [eax+2]
	add	eax, 4
	mov	DWORD PTR _regs+92, eax
	mov	dx, WORD PTR [eax]
	add	eax, 2
	mov	DWORD PTR _regs+92, eax
	mov	eax, esi
	shr	eax, 8
	and	eax, 7
	mov	ecx, DWORD PTR _regs[eax*4+32]
	mov	eax, edx
	and	eax, 0ff09H
	call	DWORD PTR _ea_020_table[eax*4]
	mov	ecx, DWORD PTR _MEMBaseDiff
	mov	eax, DWORD PTR [ecx+eax]
	bswap	eax
	xor	edx, edx
	mov	dl, bh
	mov	dh, bl
	push	edx
	push	eax
	push	esi
	call	_m68k_mull@12
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4c30_0@4 ENDP


@op_4c38_0@4 PROC NEAR
	_start_func  'op_4c38_0'
	mov	esi, ecx
	xor	ebx, ebx
	mov	ecx, DWORD PTR _regs+92
	mov	ax, WORD PTR [ecx+2]
	mov	dx, WORD PTR [ecx+4]
	xor	ecx, ecx
	mov	bh, dl
	mov	cl, dh
	movsx	ecx, cx
	movsx	edx, bx
	or	ecx, edx
	mov	edx, DWORD PTR _MEMBaseDiff
	mov	ecx, DWORD PTR [ecx+edx]
	bswap	ecx
	mov	edx, DWORD PTR _regs+92
	add	edx, 6
	mov	DWORD PTR _regs+92, edx
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	push	edx
	push	ecx
	push	esi
	call	_m68k_mull@12
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4c38_0@4 ENDP


@op_4c39_0@4 PROC NEAR
	_start_func  'op_4c39_0'
	mov	edx, eax
	mov	ax, WORD PTR [edx+2]
	mov	edx, DWORD PTR [edx+4]
	bswap	edx
	mov	esi, DWORD PTR _MEMBaseDiff
	mov	esi, DWORD PTR [esi+edx]
	bswap	esi
	mov	edx, DWORD PTR _regs+92
	add	edx, 8
	mov	DWORD PTR _regs+92, edx
	xor	edx, edx
	mov	dl, ah
	mov	dh, al
	push	edx
	push	esi
	push	ecx


