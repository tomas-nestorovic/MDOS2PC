#include "..\\..\\include\\z80.asm"
#include "..\\..\\include\\zxrom.asm"
#include "..\\..\\include\\mdos1.asm"

BUFFER		.EQU	$5d00
BUFFER_PLNY	.EQU	$ff00
BUFFER_KAPACITA	.EQU	(BUFFER_PLNY-BUFFER)/512
STATISTIKA	.EQU	$59c0+1

BORDER_SRC	.EQU	4		; barva Borderu pro signalizaci vlozeni zdrojove diskety
BORDER_TRG	.EQU	6		; 					cilove
BORDER_PAR	.EQU	5		; 				potvrzeni parametr('u) zdrojove diskety


; na adrese SrcStop mozno pretizit informaci o poctu stop na zdrojove diskete (0 = pouzita hodnota z bootu zdrojove diskety)
; na adrese SrcStop-1 mozno pretizit informaci o poctu sektoru na jedne stope cilove diskety (vychozi hodnotou je zde 9, viz Dsk80x9)


		.ORG 16384

		ld	a,79		; prestrankovani do DROM (viz ZX Magazin 6/93, str. 17)
		ld	hl,SYSFLAG	; provedeni ekvivalentu Poke #247,79 prostrednictvim zapisu 79 do fiktivniho sekvencniho souboru zacinajiciho na adrese #247 = 16119 = $3ef7
		push	hl
		ld	hl,$fde6	; hodnota "-26" ("SP-26" = zacatek tabulky udaju o zapisu do fiktivniho souboru) s 10.bitem nastavenym na 0 (protoze rutina pro zapis znaku testuje zda do buffru zapsano 512 bajtu testem 10.bitu: 0 = buffer neni plny)
		push	hl
		add	hl,sp
		set	1,h		; nastaveni 10.bitu na 1 aby zacatek tabulky na spravne hodnote (SP-26)
		ex	de,hl
		call	$25ab		; provedeni zapisu (Poke #247,79)
		rst	00		; prestrankovani
		pop	hl
		pop	hl

		ld	a,BORDER_SRC	; signalizace vlozeni zdrojove diskety
		call	DskZmen
		call	GETPAR		; do IX tabulka parametru zdrojoveho disku, nacteni Bootu zdrojoveho disku do Buffru a naplneni tabulky ukazovane IX parametry vlozeneho disku
		ld	hl,DRPAR_A+1	; pretizeni informace o 40-ti stope diskete v 80-ti stope mechanice
		res	5,(hl)
		inc	l
		ld	a,(SrcStop)	; pretizeni informace o poctu stop na zdrojove diskete (0 = pouzita hodnota z bootu zdrojove diskety)
		or	a
		jr	z,Boot		; 0 = pouzita hodnota v bootu zdrojove diskety
		ld	(hl),a
Boot		push	hl
		call	DSKSTP		; zastaveni mechaniky
		call	DRVSYS		; do IX tabulka parametru zdrojoveho disku (protoze v GetPar ukazuje na dalsi jednotku, v tomto pripade "B")
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
		ld	a,BORDER_PAR	; signalizace pozadavku potvrzeni rozpoznaneho formatu zdrojove diskety
		call	DskZmen
		ld	a,(LASTKEY)	; nestisknuto-li P (tj. nepotvrzeny-li rozpoznane parametry disku), Konec
		sub	'p'
		jr	nz,Konec

		call	SECPERDISK	; do HL celkovy pocet sektoru na diskete
		push	hl		; pocet zbyvajicich sektoru k prenosu

		;ld	c,0		; vytvoreni statistiky prenesenosti obsahu disket; HL = pocet prenesenych sektoru, C = barva (zde Paper 0, Ink 0); zakomentovano protoze C=0 zaruceno
		call	Stat


		ld	h,c		; prenos zacina od boot sektoru
		ld	l,c		; H=L=C=0

Repeat		pop	bc		; priprava zasobniku
		push	bc		; do zasobniku pocet zbyvajicich sektoru k prenosu
		push	hl		; do zasobniku aktualni sektor k prenosu
		push	bc		; do zasobniku pocet zbyvajicich sektoru k prenosu

		call	LOGFYZ		; logicky sektor v HL na fyzickou stopu a sektor v BC
		ld	hl,DREAD	; nacteni sektor('u) ze zdrojove diskety do Buffer('u)
		ld	(wOperIO),hl
		call	Prenos
		call	SwapPar		; zastaveni mechaniky a prohozeni aktualnich informaci o diskete a mechanice s informacemi o cilove diskete 80x9
		ld	a,BORDER_TRG	; signalizace vlozeni zdrojove diskety
		call	DskZmen
		pop	bc

		pop	hl
		call	LOGFYZ		; logicky sektor v HL na fyzickou stopu a sektor v BC
		ld	hl,DWRITE	; zapis sektor('u) na cilovou disketu z Buffer('u)
		ld	(wOperIO),hl
		call	Prenos
		call	FYZLOG		; fyzicka stopa a sektor v BC na logicky sektor do HL
		push	hl

		ld	c,36		; zobrazeni statistiky prenesenosti obsahu disket; HL = pocet prenesenych sektoru, C = barva (zde Paper 4, Ink 4)
		call	Stat

		call	SwapPar		; zastaveni mechaniky a prohozeni aktualnich informaci o cilove diskete diskete 80x9 s informacemi o zdrojove diskete

		pop	hl
		ex	(sp),hl		; preneseny-li vsechny sektory, konec
		ld	a,h
		or	l
		jr	z,Hotovo
		ex	(sp),hl

		push	hl
		ld	a,BORDER_SRC	; signalizace vlozeni zdrojove diskety
		call	DskZmen
		pop	hl

		jr	Repeat		; pokracuj v prenosu


Hotovo		ld	c,56		; zruseni statistiky prenesenosti obsahu disket; HL = pocet prenesenych sektoru, C = barva (zde Paper 7, Ink 0)
		pop	hl
		call	Stat

Konec		jp	ZXROM		; prestrankovani zpet do ZX ROM a konec



IO_Chyba			; signalizace chyby cteni/zapisu sektoru
		xor	a
		ld	hl,$100
		;fallthrough
BrBp					; Border A a Beep HL,DE
		rst	28		; Border; volani rutiny ZX ROM primo z DROM (automaticky potom prestrankovano zpet do DROM)
		.WORD	BORDER
		push	ix
		ld	de,$40		; Beep; HL = delka kmitu (nastavi volajici), DE = pocet kmitu
		rst	28
		.WORD	BEEPER
		pop	ix
		ret

DskZmen					; signalizace pozadavku zmeny diskety v mechanice; po navratu je povoleno preruseni
		ld	hl,$300
		call	BrBp		; Border a Beep
		rst	28		; Pause 0
		.WORD	WAIT_KEY_1
		ld	a,7		; Border 7
		rst	28
		.WORD	BORDER
		ret			; po navratu je povoleno preruseni


DiskIO					; zaplni/vyprazdni Buffer HL o kapacite E sektoru
		pop	af		; 2x navratova adresa
		pop	af
		ex	(sp),hl		; do HL pocet zbyvajicich sektoru
		ld	a,h		; urceni zda zbyvaji sektory k prenosu (HL<>0)
		or	l
		ex	af,af'		; uchovani vysledku
		ld	a,e		; do E pocet zbyvajicich sektoru ktere mozno do/z Buffru prenest jako E = Min( ZbyvajicichSektoru , KapacitaBuffru = E )
		sub	l
		ld	a,0		; nelze Xor(A) protoze by Carry=0
		sbc	a,h
		jr	c,_DecZby
		ld	e,l
_DecZby		xor	a		; snizeni poctu zbyvajicich sektoru o E
		ld	d,a
		sbc	hl,de
		ex	(sp),hl		; pocet zbyvajicich sektoru zpet do zasobniku
		dec	sp		; 2x navratova adresa
		dec	sp
		dec	sp
		dec	sp
		ex	af,af'		; nezbyvaji-li zadne sektory k prenosu (tj. HL=0), konec
		ret	z
		ld	d,e		; provedeni IO operace
		ld	e,3		; pri chybe CRC dvakrat opakuj
_RepIO		push	de		; provedeni IO operace
		push	bc
		push	hl
		.BYTE	OP_CALL_NN	; adresu urci volajici
wOperIO		.WORD	0
		inc	c		; pri chybe signalizace (pipnuti a cerny Border); test pouze chyby CRC (rutina {DREAD,DWRITE} nezohlednuje pripravenost mechaniky)
		dec	c
		call	nz,IO_Chyba	; signalizace v pripade chyby
		pop	hl		; prenos dalsiho sektoru
		inc	h		; zvyseni adresy Buffru o 512
		inc	h
		pop	bc		; posun na dalsi sektor
		inc	c
		ld	a,(ix+3)	; je-li konec stopy, presun na dalsi stopu
		sub	c
		jr	nz,_Dalsi
		inc	b		; konec stopy; presun na zacatek dalsi stopy (B++ a C=0)
		ld	c,a		; C=A=0
_Dalsi		pop	de		; preneseny-li vsechny sektory, konec
		dec	d
		jr	nz,_RepIO
		ret
	

Prenos					; naplni/vyprazdni dostupne Buffry
		ld	hl,BUFFER	; adresa Buffru
		ld	e,BUFFER_KAPACITA	; kapacita Buffru
		call	DiskIO
		ld	hl,DIRBUF	; adresa Buffru
		ld	e,3		; kapacita Buffru
		call	DiskIO
		ld	hl,$41a0	; adresa Buffru
		ld	e,12		; kapacita Buffru
		call	DiskIO
		ld	hl,$5a00	; adresa Buffru
		ld	e,1		; kapacita Buffru
		call	DiskIO
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
		jp	DRVSYS		; do IX tabulka parametru disku (zmeneno v DskStp)


Stat					; zobrazi statistiku prenesenosti obsahu disket; HL = pocet prenesenych sektoru, C = barva
		ld	a,l
		and	~63		; nulovani dolnich sesti bitu
		rr	h
		rra
		rr	h
		rra
		rr	h
		rra
		rra			; nyni zarucene H=0 a jiz jej proto netreba dale rotovat
		rra
		rra
		inc	a		; vzdy alespon jeden dilek prouzku statistiky obarven
		ld	hl,STATISTIKA
_Stat		ld	(hl),c
		inc	hl
		dec	a
		jr	nz,_Stat
		ret


Dsk80x9		.BYTE	129,24,80,9	; informace o diskete 80x9 v mechanice

SrcStop		.BYTE	0		; pretizeni informace o poctu stop na zdrojove diskete (0 = pouzita hodnota z bootu zdrojove diskety)

		.END
