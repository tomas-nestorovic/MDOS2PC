#include "..\\..\\include\\z80.asm"
#include "..\\..\\include\\zxrom.asm"
#include "..\\..\\include\\mdos1.asm"

ADRDRAM	.EQU	AUXBUF		; adresa v DRAM kam utilita z obrazovky presunuta aby udelala prostor pro Slovnik

#DEFINE	__DEBUG__0		; testovaci verze pro emulator

BOR_SRC	.EQU	4		; barva Borderu pro signalizaci vlozeni zdrojove diskety
BOR_TRG	.EQU	6		; 					cilove
BOR_PAR	.EQU	5		; 				potvrzeni parametr('u) zdrojove diskety

N_BITU	.EQU	10		; pocet bitu komprimovaneho symbolu
SLO_MAX	.EQU	((1 << (N_BITU-8))-1)*256	; max pocet zaznamu ve Slovniku
SLO_PLN	.EQU	$4000		; adresa konce Slovniku komprese
VYSTUP	.EQU	$5d00
VYS_PLN	.EQU	$ff00
VYS_STA	.EQU	$21		; zacatek zobrazeni statistiky zaplnenosti Buffru v atributove casti obrazovky ($5800+xx)
STP_STA	.EQU	$61		; zacatek zobrazeni statistiky zpracovanosti stop v atributove casti obrazovky ($5800+xx)
BUFFER	.EQU	$3800		; (DIRBUF) Buffer na adrese jejiz dolni bajt nulovy (tj. XX00)

	; na adrese SrcStop mozno pretizit informaci o poctu stop na zdrojove diskete (0 = pouzita hodnota z bootu zdrojove diskety)
	; na adrese SrcStop-1 mozno pretizit informaci o poctu sektoru na jedne stope cilove diskety (vychozi hodnotou je zde 9, viz Dsk80x9)

	.ORG ADRDRAM

	exx			; zalohovani stinovych registr('u)
	push	hl
	push	bc
	push	de

	ld	a,79		; prestrankovani do DROM (viz ZX Magazin 6/93, str. 17)
	ld	hl,$3ef7	; provedeni ekvivalentu Poke #247,79 prostrednictvim zapisu 79 do fiktivniho sekvencniho souboru zacinajiciho na adrese #247 = 16119 = $3ef7
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

	call	Presun+(16384-ADRDRAM)	; kopie utility z obrazovky do DRAM (aby odpovidaly adresy volani rutin)

	ld	hl,0		; boot sektor
Lzw	push	hl		; prvni uspesne zkomprimovany logicky sektor (predpoklad)
	push	hl		; logicky sektor ke kompresi

#IFNDEF __DEBUG__
	ld	a,BOR_SRC	; signalizace vlozeni zdrojove diskety
	call	DskZmen		; nutno "+(.)" protoze PC odvozen od ORG (a ukazuje do DRAM) a rutina DskZmen je (zatim) na obrazovce
#ENDIF

	pop	hl
	push	hl
	ld	a,h
	or	l
	jr	nz,BootOk

	call	GETPAR		; do IX tabulka parametru, nacteni Bootu do $3a00(AUXBUF) = Buffer a naplneni tabulky ukazovane IX parametry vlozeneho disku

	ld	hl,DRPAR_A+1	; pretizeni informace o 40-ti stope diskete v 80-ti stope mechanice
	res	5,(hl)
	inc	l
	ld	a,(SrcStop+(16384-ADRDRAM))	; pretizeni informace o poctu stop na zdrojove diskete (0 = pouzita hodnota z bootu zdrojove diskety)
	or	a
	jr	z,Boot		; 0 = pouzita hodnota v bootu zdrojove diskety
	ld	(hl),a

Boot	push	hl
	call	DSKSTP		; zastaveni mechaniky
	xor	a		; otevreni tiskoveho kanalu 0
	rst	28
	.WORD	CHAN_OPEN
	pop	hl
	ld	a,(hl)		; zobrazeni rozpoznaneho poctu stop na zdrojove diskete ve formatu "TTxSS"
	inc	l
	call	ByteHex+(16384-ADRDRAM)	; nutno "+(.)" aby volana rutina na obrazovce protoze cast utility byla v DRAM prepsana boot sektorem diskety
	ld	a,'x'		; aby zobrazeno "TTxSS"
	rst	10
	ld	a,(hl)		; zobrazeni rozpoznaneho poctu sektoru na stopu
	call	ByteHex+(16384-ADRDRAM)	; nutno "+(.)" aby volana rutina na obrazovce protoze cast utility byla v DRAM prepsana boot sektorem diskety

	ld	hl,AUXBUF+177	; urceni celkoveho poctu sektoru na diskete jako Strany*Stopy*Sektory
	bit	4,(hl)		; nemeni Carry, pouze nastavuje Zero
	inc	hl		; nelze Inc(L) protoze nutno zachovat Zero
	ld	e,(hl)		; do E pocet stop
	inc	hl		; nelze Inc(L) protoze nutno zachovat Zero
	ld	l,(hl)		; do L pocet sektoru
	jr	z,_Nasob
	rl	e
_Nasob	xor	a
	ld	d,a		; D=H=A=0
	ld	h,a
	push	de		; uchovani poctu stop pro vytvoreni statistiky jejich zpracovanosti nize
	rst	28
	.WORD	HLMULDE		; ZX ROM rutina pro nasobeni HL*=DE
	ld	(__NSekt+1+16384-ADRDRAM),hl	; uprava argumentu instrukce "__NSekt" ("+1" = kod instrukce Ld)

	call	Presun+(16384-ADRDRAM)	; kopie utility z obrazovky do DRAM (aby odpovidaly adresy volani rutin)
	jp	$+3		; nelze "$+3-(16384-ADRDRAM)" protoze aktualni PC jiz odvozen od ORG a tedy ukazuje do DRAM

#IFNDEF __DEBUG__
	ld	a,BOR_PAR	; signalizace pozadavku potvrzeni rozpoznaneho formatu zdrojove diskety
	call	DskZmen
	ld	a,(LASTKEY)	; nestisknuto-li P (tj. nepotvrzeny-li rozpoznane parametry zdrojove diskety), Konec
	sub	'p'
	ld	(_Hotovo+1),a	; LastKey<>P -> Hotovo=1
	pop	bc		; do BC pocet stop (vyuzito nize pri vytvoreni statistiky zpracovanosti stop)
	jp	nz,Konec
#ELSE
	pop	bc		; do BC pocet stop (vyuzito nize pri vytvoreni statistiky zpracovanosti stop)
#ENDIF

	;pop	bc		; vytvoreni statistiky zpracovanosti stop; A = informace <0;255> ; (zakomentovano protoze provedeno vyse)
	ld	a,c
	call	Statist
	.BYTE	0		; barva (zde Paper 0, Ink 0)
	.BYTE	STP_STA		; adresa

	ld	a,(VYS_PLN-VYSTUP)>>8	; vytvoreni statistiky zaplnenosti Vystupu; A = informace <0;255>
	call	Statist
	.BYTE	0		; barva (zde Paper 0, Ink 0)
	.BYTE	VYS_STA		; adresa

BootOk	call	DRVSYS		; do IX tabulka parametru

#include "lzw.asm"

	call	SwapPar		; zastaveni mechaniky a prohozeni aktualnich informaci o diskete a mechanice s informacemi o cilove diskete 80x9

	pop	hl		; v zasobniku prohozeni logickeho sektoru ke kompresi a prvniho uspesne zkomprimovaneho logickeho sektoru
	ex	(sp),hl
	push	hl

#IFNDEF __DEBUG__
	ld	a,BOR_TRG	; signalizace vlozeni cilove diskety
	call	DskZmen
#ENDIF
	call	DRVSYS		; do IX tabulka parametru disku

#include "unlzw.asm"

	call	SwapPar		; zastaveni mechaniky a prohozeni aktualnich informaci o diskete a mechanice s informacemi o zdrojove diskete

Konec	pop	hl		; obnova SP
	pop	hl
_Hotovo	ld	a,$00		; opakovani cyklu Komprese-Dekomprese pro zbyvajici sektory ($00 = urceno za behu; cela disketa zpracovana =1 )
	or	a
	jp	z,Lzw

	ld	a,2*100		; zruseni statistiky zpracovanosti stop; A = informace <0;255>
	call	Statist
	.BYTE	56		; barva (zde Paper 7, Ink 0)
	.BYTE	STP_STA		; adresa

	ld	de,16384	; presun utility zpet na obrazovku
	ld	hl,ADRDRAM
	call	_Presun

	pop	de		; obnoveni puvodnich stinovych registr('u)
	pop	bc
	pop	hl
	exx

	ei			; obnoveni preruseni

	jp	ZXROM		; prestrankuj zpet do ZX ROM
	;ret			; zakomentovano protoze provedeno behem prestrankovani vyse



BrBp				; Border A a Beep HL,DE
	rst	28		; Border; volani rutiny ZX ROM primo z DROM (automaticky potom prestrankovano zpet do DROM)
	.WORD	BORDER
	push	ix
	ld	de,$40		; Beep; HL = delka kmitu (nastavi volajici), DE = pocet kmitu
	rst	28
	.WORD	BEEPER
	pop	ix
	ret

DskZmen	ld	hl,$300		; signalizace pozadavku zmeny diskety v mechanice; po navratu je povoleno preruseni
	call	BrBp		; Border a Beep
	ld	bc,0		; Pause 0
	push	iy
	ld	iy,$5c3a	; obnova IY
	rst	28
	.WORD	PAUSE_1
	pop	iy
	ld	a,7		; Border 7
	rst	28
	.WORD	BORDER
	ret			; po navratu je povoleno preruseni

D80Err	xor	a		; signalizace chyby mechaniky (pipnuti a cerny Border)
	cp	c
	ret	z		; nenastala-li chyba, konec
	;xor	a		; Border 0 (zakomentovano protoze nastaveno vyse)
	ld	hl,$100		; Beep
	jr	BrBp		; return

SwapPar	ld	hl,DRPAR_A	; zastaveni mechaniky a prohozeni aktualnich a uchovavanych informaci o diskete (4 bajty)
	ld	de,Dsk80x9
	ld	b,4
_Prohod	ld	a,(de)
	ld	c,(hl)
	ld	(hl),a
	ld	a,c
	ld	(de),a
	inc	l
	inc	de
	djnz	_Prohod
	jp	DSKSTP		; return

Statist	pop	hl		; zobrazeni statistiky; A = informace <0;255>
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
_Statis	ld	(de),a		; vykresleni statistiky
	inc	e
	djnz	_Statis
	pop	de
	pop	bc
	jp	(hl)
	
ByteHex	push	af		; prevede hodnotu v A na dva hexa znaky a zobrazi je na aktualni tiskovou pozici
	rra	
	rra
	rra
	rra
	call	TiskHex+(16384-ADRDRAM)	; horni pulbajt; nutno "+(.)" protoze PC odvozen od ORG (a ukazuje do DRAM) a rutina TiskHex je na obrazovce
	pop	af		; dolni pulbajt
TiskHex	and	$f
	add	a,$90
	daa
	adc	a,$40
	daa
	rst	10
	ret

Presun	ld	de,ADRDRAM	; presun utility z obrazovky do DRAM
	ld	hl,16384
_Presun	ld	bc,1024
	ldir
	ret

Dsk80x9	.BYTE	129,24,80,9	; informace o diskete 80x9 v mechanice A
SrcStop	.BYTE	0		; pretizeni informace o poctu stop na zdrojove diskete (0 = pouzita hodnota z bootu zdrojove diskety)


	.END
