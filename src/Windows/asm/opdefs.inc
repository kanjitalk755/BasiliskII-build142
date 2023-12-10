_cpuid macro
	db 0fh, 0a2h
endm

_rdtsc macro
	db 0fh, 031h
endm

cmovdef macro opname, ccode
  opname macro dst, src
    local x, y
    x:
    bsf dst, src
    y:
    nop
    org x+1
    db 40h + ccode
    org y
  endm
endm

cmovdef cmovo, 0
cmovdef cmovno, 1
cmovdef cmovb, 2
cmovdef cmovc, 2
cmovdef cmovnb, 3
cmovdef cmovnc, 3
cmovdef cmovae, 3
cmovdef cmovz, 4
cmovdef cmove, 4
cmovdef cmovnz, 5
cmovdef cmovne, 5
cmovdef cmovbe, 6
cmovdef cmovna, 6
cmovdef cmova, 7
cmovdef cmovs, 8
cmovdef cmovns, 9
cmovdef cmovp, 10
cmovdef cmovpe, 10
cmovdef cmovnp, 11
cmovdef cmovpo, 11
cmovdef cmovl, 12
cmovdef cmovnl, 13
cmovdef cmovge, 13
cmovdef cmovle, 14
cmovdef cmovng, 14
cmovdef cmovg, 15
