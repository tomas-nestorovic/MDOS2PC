OP_CALL_NN	.EQU	$cd		; Call(NN)
OP_JR		.EQU	$18		; Jr(N)
OP_JP_NN	.EQU	$c3		; Jp(NN)
OP_JPNC_NN	.EQU	$d2		; Jp_nc(NN)
OP_LD_A_N	.EQU	$3e		; op code Ld(A,N)
OP_LD_BC_NN	.EQU	$01		; Ld(BC,NN)
OP_LD_HL_NN	.EQU	$21		; Ld(HL,NN)
OP_LD_SP_NN	.EQU	$31		; Ld(SP,NN)
OP_NOP		.EQU	$00		; Nop
OP_OR_N		.EQU	$f6		; Or(N)
OP_RET		.EQU	$c9		; Ret
OP_SCF		.EQU	$37		; Scf
OP_XOR_A	.EQU	$af		; Xor(A)
