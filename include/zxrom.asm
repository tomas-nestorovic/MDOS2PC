; print control characters for Rst(10)

CODE_AT		.EQU	22
CODE_PAPER	.EQU	17
CODE_INK	.EQU	16
CODE_ENTER	.EQU	13


; calculator (launched using Rst(28) )

CALC_LEN	.EQU	$1e
CALC_VAL	.EQU	$1d
CALC_DUPLICATE	.EQU	$31
CALC_END	.EQU	$38
FP_TO_BC	.EQU	$2da2
PRINT_FP	.EQU	$2de3
STK_STORE	.EQU	$2ab6


; Spectrum variables

DF_CC		.EQU	$5c84
ERR_NR		.EQU	$5c3a
LASTKEY		.EQU	$5c08
S_POSN		.EQU	$5c88


; ZX-ROM routines

BEEPER		.EQU	$3b5
BORDER		.EQU	$229b
CHAN_OPEN	.EQU	$1601
CL_LINE		.EQU	$e44
CL_ALL		.EQU	$daf
HLMULDE		.EQU	$30a9
OUT_NUM_1	.EQU	$1a1b
PAUSE_1		.EQU	$1f3d
VAL		.EQU	$35de
WAIT_KEY	.EQU	$15d4
WAIT_KEY_1	.EQU	$15de
