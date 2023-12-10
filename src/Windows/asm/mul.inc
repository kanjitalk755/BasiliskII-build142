UUSI TALLESSA

@op_4c00_0@4 PROC NEAR					;MULL
	mov	edx, eax
	mov	esi, ecx
	
	mov	bx, WORD PTR [edx+2]
	shr	esi, 8
	add	edx, 4
	xchg	bl, bh
	and	esi, 7
	mov	DWORD PTR _regs+92, edx
	mov	esi, DWORD PTR _regs[esi*4]

	;extra=bx,src=esi
	call	m68k_mull@0
	
	mov	eax, DWORD PTR _regs+92
	mov	edx,[_cpufunctbl]
	movzx	ecx, word ptr[eax]
	jmp	[ecx*4+edx]
@op_4c00_0@4 ENDP


@op_4c28_0@4 PROC NEAR					;MULL
	mov	edx, eax
	mov	ax, WORD PTR [edx+2]
	mov	dx, WORD PTR [edx+4]
	
	xchg	dl, dh
	movsx	esi, dx
	
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
	mov	bl, ah
	mov	bh, al

	;extra=bx,src=esi
	call	m68k_mull@0
	
	mov	eax, DWORD PTR _regs+92
	movzx	ecx, word ptr[eax]
	mov	edx,[_cpufunctbl]
	jmp	[ecx*4+edx]
@op_4c28_0@4 ENDP





;
;void m68k_mull (/*uae_u32 opcode,*/ uae_u32 src, uae_u16 extra)
;
;src: 		esi
;extra:		bx
;

m68k_mull@0 PROC NEAR
	;uae_s32/uae_u32 a = m68k_dreg(regs, (extra >> 12) & 7);
	mov	edi, ebx
	xor	ecx, ecx											;common for all 4 parts
	shr	edi, 12
	test	bh, 8												;(extra & 0x800)?
	and	edi, 7
	mov	eax, DWORD PTR _regs[edi*4]		;a
	je		$mull_unsigned
	
	;signed variant
	test	bh, 4												;(extra & 0x400)?
	je		$mull_signed_32
	
	;64bit signed
	imul esi
	and	ebx, 7
	mov	DWORD PTR _regs[edi*4], eax
	mov	DWORD PTR _regs[ebx*4], edx
	;WRONG?
	cmp	eax, ecx
	sete	ch
	setl	cl
	mov	DWORD PTR _regflags, ecx
	ret
	
$mull_signed_32:
	imul esi
	setc ch
	mov	WORD PTR _regflags+2, cx
	mov	DWORD PTR _regs[edi*4], eax

	xor	ecx, ecx
	cmp	eax, ecx
	sete	ch
	setl	cl
	mov	WORD PTR _regflags, cx
	ret

$mull_unsigned:

	;unsigned variant
	test	bh, 4												;(extra & 0x400)?
	je		$mull_unsigned_32

	;64bit unsigned
	mul esi
	and	ebx, 7
	mov	DWORD PTR _regs[edi*4], eax
	mov	DWORD PTR _regs[ebx*4], edx
	;WRONG?
	cmp	eax, ecx
	sete	ch
	setl	cl
	mov	DWORD PTR _regflags, ecx
	ret

$mull_unsigned_32:
	mul esi
	setc ch
	mov	WORD PTR _regflags+2, cx
	mov	DWORD PTR _regs[edi*4], eax
	xor	ecx, ecx
	cmp	eax, ecx
	sete	ch
	setl	cl
	mov	WORD PTR _regflags, cx
	ret

m68k_mull@0 ENDP
