#include "..\\..\\include\\z80.asm"
#include "..\\..\\include\\zxrom.asm"
#include "..\\..\\include\\mdos1.asm"

ADRDRAM	.EQU	AUXBUF		; adresa v DRAM kam utilita z obrazovky presunuta aby udelala prostor pro Slovnik

#DEFINE		__DEBUG__0	; testovaci verze pro emulator

BORDER_SRC	.EQU	4	; barva Borderu pro signalizaci vlozeni zdrojove diskety
BORDER_TRG	.EQU	6	; 					cilove
BORDER_PAR	.EQU	5	; 				potvrzeni parametr('u) zdrojove diskety

IDCYKLUJ	.EQU	OP_XOR_A
IDHOTOVO	.EQU	OP_SCF

N_BITU		.EQU	10	; pocet bitu komprimovaneho symbolu
SLOVNIK_MAX	.EQU	((1 << (N_BITU-8))-1)*256	; max pocet zaznamu ve Slovniku
SLOVNIK_PLNY	.EQU	$4000	; adresa konce Slovniku komprese
VYSTUP		.EQU	$5d00
VYSTUP_PLNY	.EQU	$ff00
STATIST_VYSTUP	.EQU	$21	; zacatek zobrazeni statistiky zaplnenosti Buffru v atributove casti obrazovky ($5800+xx)
STATIST_STOPY	.EQU	$61	; zacatek zobrazeni statistiky zpracovanosti stop v atributove casti obrazovky ($5800+xx)
BUFFER		.EQU	DIRBUF	; Buffer na adrese jejiz dolni bajt nulovy (tj. XX00)


; na adrese SrcStop mozno pretizit informaci o poctu stop na zdrojove diskete (0 = pouzita hodnota z bootu zdrojove diskety)
; na adrese SrcStop-1 mozno pretizit informaci o poctu sektoru na jedne stope cilove diskety (vychozi hodnotou je zde 9, viz Dsk80x9)

		.ORG ADRDRAM

		ld	a,79		; prestrankovani do DROM (viz ZX Magazin 6/93, str. 17)
		ld	hl,SYSFLAG	; provedeni ekvivalentu Poke #247,79 prostrednictvim zapisu 79 do fiktivniho sekvencniho souboru zacinajiciho na adrese #247 = 16119 = $3ef7
		push	hl
		ld	hl,$fde6	; hodnota "-26" (protoze nize "SP-26" = zacatek tabulky udaju o zapisu do fiktivniho souboru) s 10.bitem nastavenym na 0 (protoze rutina pro zapis znaku testuje zda do buffru zapsano 512 bajtu testem 10.bitu: 0 = buffer neni plny)
		push	hl
		add	hl,sp
		set	1,h		; nastaveni 10.bitu na 1 aby zacatek tabulky na spravne hodnote (SP-26)
		ex	de,hl
		call	$25ab		; provedeni zapisu (Poke #247,79)
		rst	00		; prestrankovani
		pop	hl
		pop	hl

#IFNDEF __DEBUG__
		call	16384+PresunDoDRAM-ADRDRAM
		call	SignalSrc	; signalizace vlozeni zdrojove diskety
#ENDIF

		call	GETPAR		; do IX tabulka parametru, nacteni Bootu do DIRBUF (=Buffer) a naplneni tabulky ukazovane IX parametry vlozeneho disku
		call	DSKSTP		; zastaveni mechaniky

		call	16384+PresunDoDRAM-ADRDRAM
		jp	$+3		; nelze "$+3-(16384-ADRDRAM)" protoze aktualni PC jiz odvozen od ORG a tedy ukazuje do DRAM

		ld	hl,DRPAR_A+1	; pretizeni informace o 40-ti stope diskete v 80-ti stope mechanice
		res	5,(hl)
		inc	l
		ld	a,(SrcStop)	; pretizeni informace o poctu stop na zdrojove diskete (0 = pouzita hodnota z bootu zdrojove diskety)
		or	a
		jr	z,Boot		; 0 = pouzita hodnota v bootu zdrojove diskety
		ld	(hl),a

Boot		push	hl
		xor	a		; otevreni tiskoveho kanalu 0
		rst	28
		.WORD	CHAN_OPEN
		pop	hl
		ld	b,a		; B=A=0
		ld	c,(hl)		; zobrazeni rozpoznaneho formatu zdrojove diskety v podobe "TTxSS"
		rst	28
		.WORD	OUT_NUM_1
		inc	l
		ld	a,'x'
		rst	10
		inc	b		; protoze OutNum1 nastavi B=$ff
		ld	c,(hl)
		rst	28
		.WORD	OUT_NUM_1

#IFNDEF __DEBUG__
		ld	a,BORDER_PAR	; signalizace pozadavku potvrzeni rozpoznaneho formatu zdrojove diskety
		call	DskZmen
		ld	a,(LASTKEY)	; nestisknuto-li P (tj. nepotvrzeny-li rozpoznane parametry zdrojove diskety), Konec
		sub	'p'
		jp	nz,Konec
#ENDIF
		call	DRVSYS		; do IX tabulka parametru zdrojoveho disku (protoze v GetPar ukazuje na dalsi jednotku, v tomto pripade "C")
		call	SECPERDISK	; do HL celkovy pocet sektoru na diskete
		ld	(nSektoru),hl
		ld	a,IDCYKLUJ
		ld	(bHotovo),a

		call	LOGFYZ		; vytvoreni statistiky zpracovanosti stop; A = pocet stop
		ld	a,b
		call	Statistika
		.BYTE	0,STATIST_STOPY	; barva (zde Paper 0, Ink 0) a adresa

		ld	a,(VYSTUP_PLNY-VYSTUP)>>8	; vytvoreni statistiky zaplnenosti Vystupu; A = informace <0;255>
		call	Statistika
		.BYTE	0,STATIST_VYSTUP; barva (zde Paper 0, Ink 0) a adresa


		ld	h,c		; boot sektor; H=L=C=0
		ld	l,c
		push	hl		; logicky sektor k dekompresi
Lzw		push	hl		; logicky sektor ke kompresi
		ld	(wSP),sp	; zaloha SP
#include "lzw.asm"
		call	SwapPar		; zastaveni mechaniky a prohozeni aktualnich informaci o diskete a mechanice s informacemi o cilove diskete 80x9

#IFNDEF __DEBUG__
		ld	a,BORDER_TRG	; signalizace vlozeni cilove diskety
		call	DskZmen
#ENDIF
		pop	hl		; prohozeni logickeho sektoru ke kompresi a dekompresi
		ex	(sp),hl
		push	hl
#include "unlzw.asm"
		call	SwapPar		; zastaveni mechaniky a prohozeni aktualnich informaci o diskete a mechanice s informacemi o zdrojove diskete

bHotovo		.BYTE	IDCYKLUJ	; opakovani cyklu Komprese-Dekomprese pro zbyvajici sektory ($00 = urceno za behu; cela disketa zpracovana =1 )
#IFNDEF __DEBUG__
		call	nc,SignalSrc	; signalizace vlozeni zdrojove diskety
#ENDIF
		pop	hl		; obnova SP
		jp	nc,Lzw


Hotovo		pop	hl		; prenos dokoncen; obnova SP
		rst	28		; smazani obrazovky
		.WORD	CL_ALL
		ld	de,16384	; presun utility zpet na obrazovku
		ld	hl,ADRDRAM
		call	Presun
Konec		ld	hl,$2758	; Ld a Exx aby do Basicu s "Ok, 0:1"
		exx
		jp	ZXROM		; prestrankuj zpet do ZX ROM a konec


D80Err					; signalizace chyby cteni/zapisu sektoru (pipnuti a cerny Border)
		xor	a		; pri chybe Border 0
		cp	c
		ret	z		; nenastala-li chyba, konec
		ld	hl,$100		; Beep
		;fallthrough
BrBp					; Border A a Beep HL,DE
		rst	28		; Border
		.WORD	BORDER
		push	ix
		ld	de,$40		; Beep; HL = delka kmitu (nastavi volajici), DE = pocet kmitu
		rst	28
		.WORD	BEEPER
		pop	ix
		ret


SwapPar					; zastaveni mechaniky a prohozeni aktualnich a uchovavanych informaci o diskete (4 bajty)
		ld	hl,DRPAR_A
		ld	de,Dsk80x9
		ld	bc,$4ff		; nelze pouze Ld(B,4) protoze Ldi dela BC--
_Prohod		ld	a,(de)
		ldi
		dec	l
		ld	(hl),a
		inc	l
		djnz	_Prohod
		call	DSKSTP
		jp	DRVSYS		; do IX parametry pracovniho disku (zruseny v DskStp)

SignalSrc				; signalizace vlozeni zdrojove diskety
		ld	a,BORDER_SRC
DskZmen					; signalizace pozadavku zmeny diskety v mechanice; po navratu je povoleno preruseni
		ld	hl,$300		; Border a Beep
		call	BrBp
		ld	iy,ERR_NR	; obnova IY
		rst	28		; Pause 0
		.WORD	WAIT_KEY_1
		ld	a,7		; Border 7
		rst	28
		.WORD	BORDER
		ret			; po navratu je povoleno preruseni


Statistika				; zobrazeni statistiky; A = informace 0..255
		pop	hl
		push	bc		; do B pocet dilku statistiky jako "informace/8"
		and	~7		; nulovani dolnich tri bitu
		rra
		rra
		rra
		ld	b,a
		inc	b		; vzdy alespon jeden dilek prouzku statistiky obarven
		ld	a,(hl)		; do A barva
		inc	hl
		push	de		; do DE adresa jako "zacatek atributove casti obrazovky plus offset" (tj. $5800+xx)
		ld	e,(hl)
		inc	hl
		ld	d,$58
_Statis		ld	(de),a		; vykresleni statistiky
		inc	e
		djnz	_Statis
		pop	de
		pop	bc
		jp	(hl)

PresunDoDRAM	ld	de,ADRDRAM	; kopie utility z obrazovky do DRAM (aby odpovidaly adresy volani rutin)
		ld	hl,16384
Presun		ld	bc,1023		; presun utility
		ldir
		ret

Dsk80x9		.BYTE	129,24,80,9	; informace o diskete 80x9 v mechanice A

SrcStop		.BYTE	0		; pretizeni informace o poctu stop na zdrojove diskete (0 = pouzita hodnota z bootu zdrojove diskety)

		.END
