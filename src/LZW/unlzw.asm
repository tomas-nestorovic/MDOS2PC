ZAZNAM_D_SIZE	.EQU	4		; pocet bajtu jednoho Zaznamu ve Slovniku dekomprese
SLOVNIK_D	.EQU	SLOVNIK_PLNY+(SLOVNIK_MAX*ZAZNAM_D_SIZE)	; adresa zacatku Slovniku dekomprese


		ld	hl,VYSTUP	; HL = akt. znak Vystupu
					; DE = akt. symbol
					; BC = predchozi symbol

		exx

		ld	hl,SLOVNIK_D	; HL' = < bez informace > (zde pouze inicializace prazdneho Slovniku)
					; DE' = < bez informace >
		;ld	bc,...		; BC' = ukaz akt. znak Buffru (nastaveno nize)

		ld	a,8		; A' = pocet bitu Vystupu
		ex	af,af'
	
SektorD		di
		ld	sp,hl		; do SP volna pozice ve Slovniku
		ld	bc,BUFFER	; BC' = ukaz akt. znak Buffru
		ld	d,c		; do D'=C'=0
		ld	hl,___1stD	; zmena adresy skoku instrukce Jp(NN) = pro prvni symbol nelze vytvorit Zaznam ve Slovniku (protoze neexistuje predchozi symbol)
		ld	(wPrvniD),hl
		exx

RepeatD					; ziskani symbolu do DE
		ld	a,b		; zaloha B
		ex	af,af'
		ld	d,a		; do D pocet bitu Vystupu
		xor	a		; mezivysledek ziskavan do A':E
		ld	b,N_BITU
_Repe1D		rr	(hl)
		rra
		rr	e
		dec	d
		jp	nz,_Repe2D
		inc	hl
		ld	d,8
_Repe2D		djnz	_Repe1D
		ld	b,16-N_BITU
_Repe3D		rra			; zaruceno Carry=0
		rr	e
		djnz	_Repe3D
		ld	b,a
		ld	a,d
		ld	d,b		; do DE symbol
		ex	af,af'		; obnova B
		ld	b,a

SymbolD
		ld	a,d		; zjisteni zda symbol Ascii
		or	a
		jr	nz,_Symb2D
		ld	a,e		; Carry=0 = symbol znamy (zde Ascii)
_Symb1D		exx			; symbol je Ascii - mozno jej do Buffru zapsat primo
		ld	(bc),a
		jp	_Vyst3D

___1stD					; Zaznam ve Slovniku NEmozno vytvorit
		ld	hl,ZaznamD	; zmena adresy skoku instrukce Jp(...) = Buffer neprazdny = pro nasledujici symboly vytvareny Zaznamy ve Slovniku
		ld	(wPrvniD),hl
		jp	PredD

SlovnikPlnyD	ld	hl,SLOVNIK_D	; Slovnik plny - vyprazdneni
		ld	sp,hl		; nutno take do HL' pro pripad ze Buffer plny
		jp	PredD

_Symb2D		ex	de,hl		; symbol do HL
		dec	h		; zjisteni zda symbol znamy (tj. zda existuje zaznam ve Slovniku)
		add	hl,hl
		add	hl,hl
		;ld	a,h		; H+=High(SLOVNIK_PLNY) (protoze Slovnik zarovnan na $xx00)
		;add	a,SLOVNIK_PLNY>>8
		;ld	h,a
		set	6,h		; ekvivalent k vyse zakomentovanemu protoze High(SLOVNIK_PLNY)=$40
		sbc	hl,sp		; urceni zda symbol znamy jako HL-SP (zaruceno Carry=0); znamy-li, Carry=0
		add	hl,sp
		ex	de,hl		; DE = symbol reprezentujici aktualni vystup do Buffru
		jp	nc,VystupD	; Carry=0 = symbol je znamy
		inc	b		; symbol neni znamy (Carry=1) - jako ukazatel Zaznamu ve Slovniku pouzit predchozi symbol
		dec	b
		ld	a,c
		jr	z,_Symb1D	; je-li predchozi symbol Ascii, mozno jej do Buffru zapsat primo
		push	bc		; predchozi symbol zapsan do Buffru
		.BYTE	OP_LD_A_N	; meni nasledujici instrukci na "neskodnou" Ld(A,N)

VystupD		push	de		; aktualni symbol zapsan do Buffru (provedeno pouze pokud symbol znamy)
_VystD		exx

					; urceni delky prefixu - posun ukazatele do Buffru (BC') o danou delku
		pop	hl		; prenos ukazatele Zaznamu ve Slovniku
		ld	d,h
		ld	e,l
_PrfxLn		ld	a,(hl)		; prefix
		inc	l
		ld	h,(hl)
		ld	l,a
		inc	bc
		inc	h		; protoze High(Prefix) ve Slovniku ulozeno o jednicku zmensene (jinak by nutno Or(H') a to zrusi Carry, symbol ne/znamy)
		jp	nz,_PrfxLn

					; zapis do Buffru
		push	bc		; zaloha ukazatele do Buffru (BC')
_PrfxWr		ex	de,hl
		ld	e,(hl)		; prefix
		inc	l
		ld	d,(hl)
		inc	l		; znak
		ld	a,(hl)
		ld	(bc),a
		dec	bc
		inc	d		; protoze High(Prefix) ve Slovniku ulozeno o jednicku zmensene (jinak by nutno Or(D') a to zrusi Carry, symbol ne/znamy)
		jp	nz,_PrfxWr
		ld	a,e
		ld	(bc),a
		pop	bc		; obnova BC'

_Vyst3D					; je-li symbol NEznamy, zopakovani prvniho ("nejlevejsiho") znaku na konec Buffru
		inc	bc
		.BYTE	OP_JPNC_NN
wPrvniD		.WORD	ZaznamD
		ld	(bc),a
		inc	bc

ZaznamD					; ve Slovniku vytvoreni Zaznamu [AktPrefix,AktZnak] (pouze pokud se NEjedna o prvni zapisovany symbol do Buffru - tehdy zaruceno ze pro nej existuje predchozi symbol)
		ld	l,a		; sestaveni a zapis ctyrbajtoveho Zaznamu [Low(PredSymbol),High(PredSymbol),Znak,-]
		push	hl
		exx	
		dec	b		; High(PredSymbol) do Slovniku ulozeno o jednicku zmensene (viz duvod v PrfxLn vyse)
		push	bc
		exx

					; zaplnen-li Slovnik, vyprazdneni (6.bit=0 = D'<High(SLOVNIK_PLNY)=$40 )
		ld	h,d		; H'=L'=D'=0
		ld	l,d
		add	hl,sp
		;ld	a,d
		;sub	SLOVNIK_PLNY>>8
		bit	6,h		; ekvivalent k vyse zakomentovanemu
		jr	z,SlovnikPlnyD

PredD		bit	1,b		; test zaplnenosti Buffru (vyhodnoceni nize)
		exx
		ld	b,d		; symbol aktualniho vystupu do Buffru je nyni predchozim symbolem
		ld	c,e
		;pop	hl		; do HL aktualni bajt Vystupu (zakomentovano protoze zaruceno predchozim zpracovanim)
		jp	z,RepeatD	; vyhodnoceni testu zaplnenosti Buffru

		ld	a,h		; zobrazeni statistiky zaplnenosti Vystupu; A = informace <0;255>
		sub	VYSTUP>>8
		exx
		ex	de,hl		; do DE' volna pozice ve Slovniku (nastaveno vyse pri testu zaplnenosti Slovniku)
		call	Statistika
		.BYTE	0,STATIST_VYSTUP; barva (zde Paper 0, Ink 0) a adresa

		ld	sp,(wSP)	; obnova SP

		pop	hl		; do HL' logicky sektor k zapisu
		push	hl
		call	LOGFYZ		; logicky sektor v HL' na fyzickou stopu a sektor v BC'

		push	de
		ld	hl,BUFFER	; zapis do fyzickeho sektoru BC' z adresy HL'
		ld	e,3		; tri pokusy zapisu (tj. dvakrat opakovani pri chybe)
		call	DWRITE
		call	D80Err		; test pouze chyby CRC (DWRITE nezohlednuje pripravenost mechaniky)
		pop	de

		pop	hl		; zpracovany-li vsechny sektory, dekomprese hotova
		inc	hl
		pop	bc
		push	bc
		push	hl
		or	a
		sbc	hl,bc
		ex	de,hl		; do HL' volna pozice ve Slovniku
		jp	c,SektorD
