; vyvazenost uzlu je NEGOVANA, tj. plati:
;
;    (vpravo)		(vlevo)
;
;      2 o		  o -2
;       / \		 / \
;    1 o   o		o   o -1
;     / \		   / \
;    o   o		  o   o
;   / \			     / \
;  o   o		    o   o



PRUCHOD	.EQU	$5bff		; zasobnik informaci o Pruchodu stromem
NIL	.EQU	0
SLO_PL3	.EQU	SLOVNIK+(SLO_MAX*ZAZ_LEN*2)	; Velikost Zaznamu je dvojnasobna


	;ld	hl,0		; boot sektor (zakomentovano protoze nastaveno v nadmodulu)
	;push	hl		; prvni uspesne zkomprimovany logicky sektor (zakomentovano protoze vlozeno v nadmodulu)
	;push	hl		; logicky sektor ke kompresi (zakomentovano protoze vlozeno v nadmodulu)

	ld	(_SP+1),sp	; zaloha SP

	ld	b,8		; B = pocet volnych bitu Vystupu

	ld	hl,VYSTUP	; inicializace aktualniho bajtu Vystupu
	ld	(_ZapisK+1),hl

	ld 	hl,SLOVNIK	; inicializace volne pozice ve Slovniku
	ld	(_Slov+1),hl

	ld	h,l		; inicializace Korene stromu (zaruceno H=L=0)
	ld	(_Koren+1),hl

	pop	hl		; do HL logicky sektor ke kompresi
	push	hl

SektorK
#IFNDEF	__DEBUG__
	push	bc		; zaloha poctu volnych bitu Vystupu

	call	LOGFYZ		; logicky sektor v HL na fyzickou stopu a sektor v BC

	ld	a,b		; zobrazeni statistiky o zpracovanosti stop; A = informace <0;255>
	inc	a		; "mapovani" stop z {0..N-1} na {1..N} (aby po zpracovani posledni stopy prouzek statistiky cely zeleny)
	call	Statist
	.BYTE	36		; barva (zde Paper 4, Ink 4)
	.BYTE	STP_STA		; adresa

	ld	a,(_ZapisK+2)	; zobrazeni statistiky zaplnenosti Vystupu; A = informace <0;255>
	sub	VYSTUP>>8
	call	Statist
	.BYTE	36		; barva (zde Paper 4, Ink 4)
	.BYTE	VYS_STA		; adresa

	push	de		; zaloha Prefixu
	ld	hl,BUFFER	; precteni fyzickeho sektoru BC na adresu HL
	ld	e,3		; tri pokusy cteni (tj. dvakrat opakovani pri chybe)
	call	DREAD
	call	D80Err		; test pouze chyby CRC (rutina DREAD=$236A nezohlednuje pripravenost mechaniky)
	pop	de		; obnova Prefixu

	pop	bc		; obnova poctu volnych bitu Vystupu
#IFDEF	__EMUL__
	ld	de,$4400
	ld	hl,BUFFER
	ld	bc,512
	ldir
#ENDIF
#ENDIF

	di			; zakazani preruseni (protoze pouzivany stinove registry)
	xor	a		; Carry=0

	ld	iy,BUFFER	; IY = ukaz akt. Znaku

				; HL = < bez informace >
	ld	d,a		; DE = prefix akt. Znaku ; D=A=0
	ld	e,(iy+0)
	;ld	b,...		;  B = pocet volnych bitu Vystupu
				;  C = akt. Znak

	;exx
				; HL' = < bez informace >
	;ld	de,...		; DE' = vrchol zasobniku Pruchodu stromem (zakomentovano protoze nastaveno nize)
				; BC' = < bez informace >

RepeatK	inc	iy		; test konce Buffru
	.BYTE	$fd		; meni nasledujici instrukci na Ld(A,High(IY))
	ld	a,h		; Ld(A,High(IY))
	cp	(BUFFER+512)>>8
	jp	nc,BufCelK
	ld	c,(iy+0)	; do C Znak z Buffru

	exx
_Koren	ld	hl,$0000	; do HL' Koren stromu ($0000 = urceno za behu)
	ld	de,PRUCHOD	; do DE' vrchol zasobniku Pruchodu stromem
	ld	bc,NIL		; do BC' Zaznam Rodice Korene stromu
HledejK	ex	de,hl		; v zasobniku Pruchodu vytvoreni informace o Rodici Zaznamu
	dec	l		; v A specificke informace o Rodici
	sbc	a,a		; A=-Carry
	ld	(hl),a
	dec	l
	dec	l		; v BC' Zaznam Rodice
	ld	(hl),b
	dec	l
	ld	(hl),c
	ex	de,hl

	inc	h		; pokud HL'=Nil, Zaznam [AktPrefix,AktZnak] ve Slovniku neexistuje a nutno jej vytvorit
	dec	h		; nelze Ld(A,H), Or(A) protoze nutno zachovat A
	jp	z,ZaznamK

	ld	sp,hl		; do SP Zaznam ve Slovniku
	ld	b,h		; do BC' zaloha zacatku Zaznamu
	ld	c,l
	pop	hl		; do HL' "pravy podstrom"
	exx
	pop	hl		; do HL Zaznamenany Prefix
	xor	a
	sbc	hl,de
	exx
	jp	c,HledejK	; Zaznamenany Prefix mensi nez akt. Prefix, hledani v "pravem podstromu"
	pop	hl		; do HL' "levy podstrom"
	jp	nz,HledejK	; Zaznamenany Prefix vetsi nez akt. Prefix, hledani v "levem podstromu"
	exx
	pop	af		; do A Zaznamenany Znak
	sub	c
	jp	z,ShodaK	; Zaznamenany Znak shodny s akt. Znakem
	exx
	jp	nc,HledejK	; Zaznamenany Znak --vetsi-- nez akt. Znak, hledani v --"levem podstromu"--
	ld	h,b
	ld	l,c
	ld	sp,hl
	pop	hl		; do HL' opet --"pravy podstrom"--
	jp	HledejK		; Zaznamenany Znak --mensi-- nez akt. Znak, hledani v --"pravem podstromu"--

ShodaK				; ve Slovniku nalezen Zaznam [AktPrefix,AktZnak] - pouziti Zaznamu jako aktualniho Prefixu (a pokus o jeho rozsireni dalsim znakem)
	ld	hl,-8
	add	hl,sp
	ex	de,hl
	jp	RepeatK

BufCelK				; cely Buffer zpracovan
	ld	a,$21		; zmena instrukce Jp(nc,...) na "neskodnou" Ld(Hl,...)
	ld	(_BuffOk),a
	xor	a
	jp	_Vyst3K		; zapis aktualniho Prefixu na Vystup


SloPlnK				; vyprazdneni plneho Seznamu a Slovniku
	ld 	hl,SLOVNIK	; inicializace volne pozice ve Slovniku
	ld	(_Slov+1),hl
	;ld	hl,NIL		; inicializace Korene stromu
	ld	h,a		; H=L=A=0		
	;ld	l,a		; zakomentovano protoze L=A=0 zaruceno jiz z HL=Slovnik vyse
	ld	(_Koren+1),hl
	jp	_Vyst3K		; zaruceno A=0

KorenK	ld	(_Koren+1),hl	; nastaveni Korene stromu
	xor	a
	jp	_Vyst2K

KorenDE	ld	(_Koren+1),de
	jp	_ZazVyv


ZaznamK	exx			; ve Slovniku vytvoreni Zaznamu [AktPrefix,AktZnak]
_Slov	ld	hl,$0000	; do HL volna pozice ve Slovniku ($0000 = urceno za behu)
	ex	af,af'		; do A' zaloha specifickych informaci o Rodici
	ld	a,h		; zaplnen-li Slovnik, vyprazdneni
	sub	SLO_PL3>>8
	jp	z,SloPlnK
	ld	a,l		; urceni dalsi volne pozice ve Slovniku
	or	7
	ld	l,a
	inc	hl
	ld	(_Slov+1),hl
	ld	sp,hl		; vytvoreni Zaznamu
	ld	h,c		; Zaznamenani Znaku v H a Vyvazenosti v L
	ld	l,0
	push	hl
	ld	h,l		; H=L=0
	push	hl		; Zaznamenani "leveho podstromu" (=Nil)
	push	de		; Zaznamenani Prefixu
	push	hl		; zaznamenani "praveho podstromu" (=Nil)

	exx
	;ld	hl,NIL		; zakomentovano protoze HL'=Nil zaruceno
	add	hl,sp
	inc	b		; neexistuje-li pro Zaznam Rodic (nastaven v BC'), jedna se o Koren stromu
	dec	b
	jp	z,KorenK
	ex	de,hl		; do DE' nove vytvoreny Zaznam
	ld	sp,hl		; do SP zasobnik Pruchodu stromem
	dec	l		; v zasobniku Pruchodu zaznamenani nove vytvoreneho Zaznamu (pro pripad ze nize nutna dvojita rotace)
	dec	l
	dec	l
	ld	(hl),d
	dec	l
	ld	(hl),e
	pop	hl		; do HL' Rodic Zaznamu (plati HL'=BC'=Rodic)
	ex	af,af'		; do A obnova specifickych informaci o Rodici
	jp	c,_ZazRod	; je-li Zaznam soucasti "praveho podstromu" Rodice, skoc
	set	2,l		; Zaznam soucasti --"leveho podstromu"-- Rodice, pricti 4
_ZazRod	ld	(hl),e		; pridani Zaznamu do Rodice
	inc	l
	ld	(hl),d
	;ld	l,c		; aby v HL' zacatek Rodice Zaznamu (zakomentovano protoze L' nize dale upraveno)
	;ld	b,...		; do B' Vyvazenost Zaznamu (zakomentovano protoze novy Zaznam nikdy neuvede bezprostredniho Rodice do netolerantni NeVyvazenosti)

OvlivnK				; ovlivneni Vyvazenosti Rodice HL' Zaznamem DE' (v B' Vyvazenost Zaznamu)
	ld	a,c		; ovlivneni Vyvazenosti Rodice ukazovaneho HL' jako (HL'+6)+=A
	or	6		; do A soucasna Vyvazenost Rodice
	ld	l,a
	pop	af		; do A "-Carry" ("-1" = Zaznam soucasti "praveho podstromu", 0 = Zaznam soucasti "leveho podstromu")
	add	a,a		; do A specificke informace o Rodici, tj. "-Carry"={-1,0} -> {-1,1}
	inc	a
	add	a,(hl)		; uprava Vyvazenosti Rodice jako (HL'+6)+=A
	ld	(hl),a
	jp	z,_Vyst2K	; (zaruceno A=0); Rodic se stal idealne Vyvazenym a neovlivni Vyvazenost zadneho ze svych Nadrodicu
	ld	l,c		; z C' obnova Low(Rodic)
	bit	0,a
	ex	de,hl		; do DE' Rodic (stava se Zaznamem), do HL' Zaznam (nize nahrazen rodicem Rodice)
	jp	z,RotaceK	; je-li Vyvazenost Zaznamu {2,-2}, nulty bit je vzdy roven 0 a Rodic je v netolerovane NeVyvazenosti
	ld	b,a		; do B' Vyvazenost Zaznamu
	pop	hl		; do HL' Rodic ze zasobniku Pruchodu stromem
	inc	h
	dec	h
	ld	c,l		; do C' zaloha Low(Rodic)
	jp	nz,OvlivnK
	xor	a
	jp	_Vyst2K		; zadny dalsi Rodic

_RotDvo				; dokonceni Dvojite Rotace (provedenim "vnejsi" jednoduche Rotace)
	dec	l		; do HL' zacatek Rodice
	res	2,l
	ex	de,hl		; do HL' Zaznam, do DE' Rodic
	ccf			; "vnejsi" rotace opacny smer nez "vnitrni" rotace
	ld	a,1		; A=1-1=0 = po provedeni "vnejsi" rotace netreba zadnou dalsi rotaci
	dec	a
	jp	_RotJed

RotaceK				; Rodic DE' je v netolerovane NeVyvazenosti A={2,-2} (v HL' Zaznam, v B' Vyvazenost Zaznamu HL')
	xor	b		; urceni zda nutno Jednoduchou nebo Dvojitou Rotaci
	jp	p,RotJedn
RotDvoj				; nutna dvojita Rotace - urceni smeru
	ld	hl,-12		; nastaveni puvodnich HL' a DE'
	add	hl,sp
	ld	sp,hl
	pop	hl		; do HL' zpet puvodni zaznam
	pop	bc
	pop	de		; do DE' zpet puvodni rodic
	pop	bc
RotJedn				; nutna jednoducha Rotace
	rra			; protoze 0.bit vzdy =1
	srl	a		; urceni smeru Rotace
_RotJed	jp	nc,Rot_LL

Rot_RR	ex	af,af'		; nutna Rotace RR (v HL' Zaznam, v DE' Rodic)
	set	2,e		; "pravy podstrom" Zaznamu HL' musi "levym podstromem" Rodice DE'
	ldi
	ld	a,(hl)
	ld	(de),a
	rlca			; do B': 1 <=> Zaznam HL' ma "pravy podstrom", 0 <=> jinak
	rlca
	and	1
	ld	b,a
	ld	(hl),d		; Rodic jako "pravy podstrom" Zaznamu
	dec	l
	dec	e
	res	2,e
	ld	(hl),e
	ex	de,hl		; do DE' Zaznam, do HL' Rodic
	inc	l		; do A: "-1" <=> Rodic HL' ma "pravy podstrom", 0 <=> jinak
	xor	a
	cp	(hl)
	sbc	a,a
	add	a,b		; urceni a nastaveni Vyvazenosti Rodice DE'
	set	2,l
	inc	l
	jp	_RodVyv

Rot_LL	ex	af,af'		; nutna Rotace LL (v HL' Zaznam, v DE' Rodic)
	set	2,l		; "levy podstrom" Zaznamu HL' musi "pravym podstromem" Rodice DE'
	ldi
	ld	a,(hl)
	ld	(de),a
	rlca			; do B': "-1" <=> Zaznam HL' ma "levy podstrom", 0 <=> jinak
	rlca
	sbc	a,a
	ld	b,a
	ld	(hl),d		; Rodic jako "levy podstrom" Zaznamu
	dec	l
	dec	e
	ld	(hl),e
	res	2,l		; obnova zacatku Zaznamu HL'
	ex	de,hl		; do DE' Zaznam, do HL' Rodic
	set	2,l		; do A: 1 <=> Rodic HL' ma "levy podstrom", 0 <=> jinak
	inc	l
	xor	a
	cp	(hl)
	adc	a,b		; urceni a nastaveni Vyvazenosti Rodice HL'
	inc	l
_RodVyv	ld	(hl),a
	pop	hl		; do HL' Nadrodic (tj. rodic Rodice) (v DE' Zaznam)
	ld	a,h
	or	a
	jp	z,KorenDE
	pop	af		; do A specificke informace o Rodici
	or	a
	jp	m,_NadRod	; ma-li Zaznam soucasti "praveho podstromu" Nadrodice, skoc
	set	2,l		; Zaznam soucast --"leveho podstromu"-- Nadrodice, pricti 4
_NadRod	ld	(hl),e		; Zaznam DE' jako "pravy/levy podstrom" Nadrodice HL'
	inc	l
	ld	(hl),d
	ex	af,af'		; rozhodnuti zda nutna Dvojita rotace
	jp	nz,_RotDvo

_ZazVyv	ld	a,e		; nulovani Vyvazenosti Zaznamu HL'
	or	6
	ld	e,a
	xor	a
	ld	(de),a

	



_Vyst2K	exx
_Vyst3K	or	d		; (zaruceno A=0) do A horni bajt Prefixu, tj. A=D=High(Prefix)
	jp	z,_ZapisK	; prefixem je Ascii znak
	sub	SLOVNIK>>8	; A-=High(Slovnik) (protoze Slovnik na adrese $xx00)
	rra			; zaruceno Carry=0
	rr	e
	rra	
	rr	e
	rra	
	rr	e
	inc	a		; symbol ma kod "za" Ascii
_ZapisK	ld	hl,$0000	; do HL ukaz volne pozice Vystupu ($0000 = urceno za behu)
	ld	d,b		; do D pocet volnych bitu Vystupu
	ld	b,N_BITU	; zapis nBitu symbolu na Vystup
_Zap1K	rra
	rr	e
	rr	(hl)		; zapis nejnizsiho bitu DE do Vystupniho fifo
	dec	d
	jp	nz,_Zap2K
	inc	hl		; dalsi bajt Vystupu
	inc	h		; test zaplnenosti Vystupu
	jp	z,KonecK	; zaplnen-li Vystup, konec (Carry=0)
	dec	h
	ld	d,8
_Zap2K	djnz	_Zap1K
	ld	(_ZapisK+1),hl	; uchovani ukaz volne pozice Vystupu
	ld	b,d		; do B zpet pocet volnych bitu Vystupu
	ld	d,0		; aktualni Znak prefixem dalsiho znaku (D=0, E=C)
	ld	e,c
_BuffOk	jp	RepeatK		; opcode instrukce po zpracovani celeho Buffru zmenen z Jp(...) na Ld(Hl,...)
	ld	a,$c3		; uprava opcodu instrukce BuffOk z Ld(Hl,...) zpet na Jp(...)
	ld	(_BuffOk),a

_SP	ld	sp,$0000	; obnova SP ($0000 = urceno za behu)
__NSekt	ld	hl,$0000	; do HL pocet sektoru na diskete ($0000 = urceno za behu)
	pop	de
	inc	de
	push	de
	xor	a
	sbc	hl,de
	ld	h,d		; do HL pripadny dalsi sektor
	ld	l,e
	jp	nz,SektorK	; zpracovany-li vsechny sektory, komprese hotova

	inc	a		; A=1, tj. cela disketa zpracovana (zaruceno ze predtim A=0)
	ld	(_Hotovo+1),a
	ld	hl,(_ZapisK+1)	; do HL ukaz volne pozice Vystupu
_FifoK	rr	(hl)		; rolovani fifo aby na nejnizsim bitu prvni zapsany bit
	djnz	_FifoK

KonecK	ld	sp,(_SP+1)	; obnova SP (v pripade ze Buffer plny)
