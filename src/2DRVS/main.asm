#include "..\\..\\include\\z80.asm"
#include "..\\..\\include\\zxrom.asm"
#include "..\\..\\include\\mdos1.asm"

BUFFER		.EQU	$5d00
BUF_PLN		.EQU	$ff00
BUF_KAP		.EQU	(BUF_PLN-BUFFER)/512
STATIST		.EQU	$5800+1+(20*32)


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

		ld	de,DRPAR_A	; nastaveni parametru ciloveho disku A
		ld	hl,Dsk80x9
		ld	bc,4
		ldir

		call	Tiskni		; tiskni uvodni hlaseni
		.TEXT	"Plug "
		.BYTE	CODE_INK,1
		.TEXT	"source"
		.BYTE	CODE_INK,0
		.TEXT	" disk into drive "
		.BYTE	CODE_INK,1,'B',CODE_INK,0,CODE_ENTER
		.TEXT	"and "
		.BYTE	CODE_INK,3
		.TEXT	"target"
		.BYTE	CODE_INK,0
		.TEXT	" into drive "
		.BYTE	CODE_INK,3,'A',CODE_INK,0
		.BYTE	CODE_ENTER
		.TEXT	">> NOT THE OTHER WAY ROUND <<"
		.BYTE	CODE_ENTER
		.TEXT	"and hit a ke"
		.BYTE	'y'+128
		call	Pause0		; Pause 0 (tj. cekej na stisk libovolne klavesy)

		ld	a,1		; pracovnim diskem je zdrojovy disk B
		ld	(WORKDR),a
		call	GETPAR		; do IX tabulka parametru zdrojoveho disku B, nacteni Bootu zdrojoveho disku B do Buffru a naplneni tabulky ukazovane IX parametry vlozeneho disku

		ld	hl,DRPAR_B+1	; pretizeni informace o 40-ti stope diskete v 80-ti stope mechanice
		res	5,(hl)
		inc	l
		ld	a,(SrcStop)	; pretizeni informace o poctu stop na zdrojove diskete (0 = pouzita hodnota z bootu zdrojove diskety)
		or	a
		jr	z,Boot		; 0 = pouzita hodnota v bootu zdrojove diskety
		ld	(hl),a
Boot		push	hl
		call	DSKSTP		; zastaveni mechaniky
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
		call	TiskPridej
		.TEXT	" (P=Proceed"
		.BYTE	')'+128
		call	Pause0		; cekani na stisk libovolne klavesy
		sub	'p'		; nestisknuto-li P (tj. nepotvrzeny-li rozpoznane parametry zdrojoveho disku), Konec
		jr	nz,Konec

		call	DRVSYS		; do IX tabulka parametru zdrojoveho disku (protoze v GetPar ukazuje na dalsi jednotku, v tomto pripade "C")
		call	SECPERDISK	; do HL celkovy pocet sektoru na diskete
		push	hl		; pocet zbyvajicich sektoru k prenosu

		ld	b,c		; B=C=0
		push	bc		; aktualni sektor k prenosu (prenos zacina od Boot sektoru)

		;ld	c,0		; vytvoreni statistiky prenesenosti obsahu disket; HL = pocet prenesenych sektoru, C = barva (zde Paper 0, Ink 0); zakomentovano protoze nastaveno vyse
		call	Stat

Repeat		call	DRVSYS		; do IX tabulka parametru zdrojoveho disku B
		pop	hl		; do D pocet sektoru ktere budou preneseny v teto obratce jako D = Min( ZbyvajicichSektoru , KapacitaBuffru )
		ex	(sp),hl		; do HL pocet zbyvajicich sektoru
		ld	d,BUF_KAP	; predpoklad (zbyvajici sektory zaplni cely Buffer)
		ld	a,d
		sub	l
		ld	a,0		; nelze Xor(A) protoze by Carry=0
		sbc	a,h
		jr	c,_Urceno
		ld	d,l
_Urceno		ex	(sp),hl		; do zasobniku zpet pocet zbyvajicich sektoru a do HL aktualne zpracovavany sektor
		push	hl

		ld	e,3		; pri chybe CRC dvakrat opakuj
		push	de		; do zasobniku pocet prenasenych sektoru
		push	de

		push	hl		; uchovani logickeho sektoru
		call	LOGFYZ		; logicky sektor v HL na fyzickou stopu a sektor v BC

		ld	hl,BUFFER	; precteni D sektor('u) ze zdrojove diskety do Buffru
		call	BREADA
		call	DSKSTP		; zastaveni zdrojove mechaniky B

		ld	hl,WORKDR	; do IX parametry ciloveho disku A
		dec	(hl)
		call	DRVSYS
		pop	hl		; logicky sektor v HL na fyzickou stopu a sektor v BC
		call	LOGFYZ
		ld	hl,BUFFER	; zapis D sektor('u) na cilovou disketu
		pop	de		; do D pocet sektoru ktere budou preneseny v teto obratce, do E stejny pocet opakovani pri CRC chybe jako pri cteni
		call	BWRITE
		call	DSKSTP		; zastaveni cilove mechaniky A

		pop	de		; zvyseni cisla logickeho Sektoru o pocet prave prenesenych
		ld	e,d		; do DE pocet prenasenych sektoru
		ld	d,0
		pop	hl		; do HL aktualne zpracovavany sektor
		add	hl,de
		ex	(sp),hl		; snizeni poctu zbyvajicich sektoru o pocet prave prenesenych
		sbc	hl,de		; zaruceno Carry=0
		jr	z,Hotovo	; preneseny-li vsechny sektory, konec
		ex	(sp),hl		; do zasobniku obe aktualizovane informace
		push	hl

		ld	c,36		; zobrazeni statistiky prenesenosti obsahu disket; HL = pocet prenesenych sektoru, C = barva (zde Paper 4, Ink 4)
		call	Stat

		ld	hl,WORKDR	; pracovnim diskem je zdrojovy disk B
		inc	(hl)
		jr	Repeat		; pokracuj v prenosu


Hotovo		ld	c,56		; zruseni statistiky prenesenosti obsahu disket; HL = pocet prenesenych sektoru, C = barva (zde Paper 7, Ink 0)
		pop	hl
		call	Stat
Konec		jp	ZXROM		; prestrankovani zpet do ZX ROM a konec



Pause0					; cekani na stisk klavesy a jeji vraceni
		set	5,(iy+2)	; nastaveni signalu ze spodni cast obrazovky nutno vycistit (po stisku klavesy)
		rst	28
		.WORD	WAIT_KEY
		ld	a,(LASTKEY)	; do A stisknuta klavesa
		ret


Tiskni					; na dany Radek vytiskne text
		xor	a		; otevreni tiskoveho kanalu cislo 2
		rst	28
		.WORD	CHAN_OPEN
TiskPridej	pop	hl
_Tisk		ld	a,(hl)
		and	127		; nejvyssi bit A na 0
		rst	10
		bit	7,(hl)
		inc	hl
		jr	z,_Tisk
		jp	(hl)		; skoc za text a pokracuj v programu


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
		ld	b,a
		inc	b		; vzdy alespon jeden dilek prouzku statistiky obarven
		ld	hl,STATIST
_Stat		ld	(hl),c
		inc	hl
		djnz	_Stat
		ret


Dsk80x9		.BYTE	129,24,80,9	; informace o diskete 80x9 v mechanice A

SrcStop		.BYTE	0		; pretizeni informace o poctu stop na zdrojove diskete (0 = pouzita hodnota z bootu zdrojove diskety)

		.END
