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
;
;
;
; zaznam ve slovniku (8 bajtu):
;
; |  0     1  |  2     3  |  4     5  |  6     7  |
; +-----------+-----------+-----------+-----------+
; |   pravy   |  Prefix   |    levy   |  V  |  Z  |
;
; kde	V = vyvazenost {-2,...,2}
;	Z = znak
;




STROM_PRUCHOD	.EQU	$5bff		; zasobnik informaci o Pruchodu stromem
NIL		.EQU	0
ZAZNAM_K_SIZE	.EQU	8		; pocet bajtu jednoho Zaznamu ve Slovniku komprese
SLOVNIK_K	.EQU	SLOVNIK_PLNY+(SLOVNIK_MAX*ZAZNAM_K_SIZE)	; adresa zacatku Slovniku komprese


		ld	b,8		; B = pocet volnych bitu Vystupu

		ld	hl,VYSTUP	; inicializace aktualniho bajtu Vystupu
		ld	(wVystupK),hl

		ld 	hl,SLOVNIK_K	; inicializace volne pozice ve Slovniku
		ld	(wSlovnikK),hl

		ld	h,l		; inicializace Korene stromu; H=L=0
		ld	(wKoren),hl

		pop	hl		; do HL logicky sektor ke kompresi
		push	hl

SektorK
		push	bc		; zaloha poctu volnych bitu Vystupu

		call	LOGFYZ		; logicky sektor v HL na fyzickou stopu a sektor v BC

		ld	a,b		; zobrazeni statistiky o zpracovanosti stop; A = informace <0;255>
		inc	a		; "mapovani" stop z {0..N-1} na {1..N} (aby po zpracovani posledni stopy prouzek statistiky cely zeleny)
		call	Statistika
		.BYTE	36,STATIST_STOPY; barva (zde Paper 4, Ink 4) a adresa

		ld	a,(wVystupK+1)	; zobrazeni statistiky zaplnenosti Vystupu; A = informace <0;255>
		sub	VYSTUP>>8
		call	Statistika
		.BYTE	36,STATIST_VYSTUP; barva (zde Paper 4, Ink 4) a adresa

		push	de		; zaloha Prefixu
		ld	hl,BUFFER	; precteni fyzickeho sektoru BC na adresu HL
		ld	e,3		; tri pokusy cteni (tj. dvakrat opakovani pri chybe)
		call	DREAD
		call	D80Err		; test pouze chyby CRC (rutina DREAD=$236A nezohlednuje pripravenost mechaniky)
		pop	de		; obnova Prefixu

		pop	bc		; obnova poctu volnych bitu Vystupu

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

RepeatK		inc	iy		; test konce Buffru
		.BYTE	$fd		; meni nasledujici instrukci na Ld(A,High(IY))
		ld	a,h		; Ld(A,High(IY))
		cp	(BUFFER+512)>>8
		jr	nc,BufCelK
		ld	c,(iy+0)	; do C Znak z Buffru

		exx
		.BYTE	OP_LD_HL_NN	; do HL' Koren stromu ($0000 = urceno za behu)
wKoren		.WORD	0
		ld	de,STROM_PRUCHOD	; do DE' vrchol zasobniku Pruchodu stromem
		ld	bc,NIL		; do BC' Zaznam Rodice Korene stromu
HledejK		ex	de,hl		; v zasobniku Pruchodu vytvoreni informace o Rodici Zaznamu
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
		jr	z,ZaznamK

		ld	sp,hl		; do SP Zaznam ve Slovniku
		ld	b,h		; do BC' zaloha zacatku Zaznamu
		ld	c,l
		pop	hl		; do HL' "pravy podstrom"
		exx
		pop	hl		; do HL Zaznamenany Prefix
		xor	a
		sbc	hl,de
		exx
		jr	c,HledejK	; Zaznamenany Prefix mensi nez akt. Prefix, hledani v "pravem podstromu"
		pop	hl		; do HL' "levy podstrom"
		jp	nz,HledejK	; Zaznamenany Prefix vetsi nez akt. Prefix, hledani v "levem podstromu"
		exx
		pop	af		; do A Zaznamenany Znak
		sub	c
		jr	z,ShodaK	; Zaznamenany Znak shodny s akt. Znakem
		exx
		jr	nc,HledejK	; Zaznamenany Znak --vetsi-- nez akt. Znak, hledani v --"levem podstromu"--
		ld	h,b
		ld	l,c
		ld	sp,hl
		pop	hl		; do HL' opet --"pravy podstrom"--
		jp	HledejK		; Zaznamenany Znak --mensi-- nez akt. Znak, hledani v --"pravem podstromu"--

ShodaK					; ve Slovniku nalezen Zaznam [AktPrefix,AktZnak] - pouziti Zaznamu jako aktualniho Prefixu (a pokus o jeho rozsireni dalsim znakem)
		ld	hl,-ZAZNAM_K_SIZE
		add	hl,sp
		ex	de,hl
		jp	RepeatK

BufCelK					; cely Buffer zpracovan
		ld	a,OP_LD_HL_NN	; zmena instrukce Jp(NN) na "neskodnou" Ld(HL,NN)
		ld	(bBuffOk),a
		xor	a
		jp	_Vyst3K		; zapis aktualniho Prefixu na Vystup


SlovnikPlnyK				; vyprazdneni plneho Seznamu a Slovniku
		ld 	hl,SLOVNIK_K	; inicializace volne pozice ve Slovniku
		ld	(wSlovnikK),hl
		ld	h,l		; H=L=0 (L=0 zaruceno jiz z HL=Slovnik vyse)
KorenK		ld	(wKoren),hl	; nastaveni Korene stromu
		xor	a
		jp	_Vyst2K


ZaznamK		exx			; ve Slovniku vytvoreni Zaznamu [AktPrefix,AktZnak]
		.BYTE	OP_LD_SP_NN	; do SP volna pozice ve Slovniku ($0000 = urceno za behu)
wSlovnikK	.WORD	0
		ld	h,c		; Zaznamenani Znaku v H a Vyvazenosti=0 v L
		ld	l,0
		push	hl
		ld	h,l		; H=L=0
		push	hl		; Zaznamenani "leveho podstromu" (=Nil)
		push	de		; Zaznamenani Prefixu
		push	hl		; zaznamenani "praveho podstromu" (=Nil)
		ex	af,af'		; do A' zaloha specifickych informaci o Rodici
		exx

		;ld	hl,NIL		; zakomentovano protoze HL'=Nil zaruceno
		add	hl,sp
		bit	6,h		; zaplnen-li Slovnik, vyprazdneni (6.bit=0 = H'<High(SLOVNIK_PLNY)=$40 )
		jr	z,SlovnikPlnyK
		ld	(wSlovnikK),hl	; urceni dalsi volne pozice ve Slovniku
		inc	b		; neexistuje-li pro Zaznam Rodic (nastaven v BC'), jedna se o Koren stromu
		dec	b
		jr	z,KorenK
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
		jr	c,_ZazRod	; je-li Zaznam soucasti "praveho podstromu" Rodice, skoc
		set	2,l		; Zaznam soucasti --"leveho podstromu"-- Rodice, pricti 4
_ZazRod		ld	(hl),e		; pridani Zaznamu do Rodice
		inc	l
		ld	(hl),d
		;ld	l,c		; aby v HL' zacatek Rodice Zaznamu (zakomentovano protoze L' nize dale upraveno)
		;ld	b,...		; do B' Vyvazenost Zaznamu (zakomentovano protoze novy Zaznam nikdy neuvede bezprostredniho Rodice do netolerantni NeVyvazenosti)

OvlivniVyvazenost			; ovlivneni Vyvazenosti Rodice HL' Zaznamem DE' (v B' Vyvazenost Zaznamu)
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
		jr	z,RotaceK	; je-li Vyvazenost Zaznamu {2,-2}, nulty bit je vzdy roven 0 a Rodic je v netolerovane NeVyvazenosti
		ld	b,a		; do B' Vyvazenost Zaznamu
		pop	hl		; do HL' Rodic ze zasobniku Pruchodu stromem
		xor	a
		or	h
		ld	c,l		; do C' zaloha Low(Rodic)
		jp	nz,OvlivniVyvazenost
		jp	_Vyst2K		; zadny dalsi Rodic (zaruceno A=0)

_RotDvo					; dokonceni Dvojite Rotace (provedenim "vnejsi" jednoduche Rotace)
		ld	l,b		; obnova Low(Rodic)
		ex	de,hl		; do HL' Zaznam, do DE' Rodic
		ccf			; "vnejsi" rotace opacny smer nez "vnitrni" rotace
		bit	7,h		; aby Zero=1 (zaruceno H'<$7F) = po provedeni "vnejsi" rotace netreba zadnou dalsi rotaci
		jp	_RotJednoducha

RotaceK					; Rodic DE' je v netolerovane NeVyvazenosti A={2,-2} (v HL' Zaznam, v B' Vyvazenost Zaznamu HL')
		xor	b		; urceni zda nutno Jednoduchou nebo Dvojitou Rotaci
		jp	p,RotJednoducha
RotDvojita				; nutna dvojita Rotace - urceni smeru
		ld	hl,-12		; nastaveni puvodnich HL' a DE'
		add	hl,sp
		ld	sp,hl
		pop	hl		; do HL' zpet puvodni zaznam
		pop	bc
		pop	de		; do DE' zpet puvodni rodic
		pop	bc
RotJednoducha				; nutna jednoducha Rotace
		rra			; protoze 0.bit vzdy =1
		srl	a		; urceni smeru Rotace
_RotJednoducha	ld	b,e		; do B' zaloha Low(Rodic)
		ld	c,l		; do C' zaloha Low(Zaznam)
		inc	bc		; BC'++ protoze nize provadeno Ldi (a to BC'--) (nelze Inc(C) protoze nutno zachovat Zero)
		jr	c,Rot_RR

Rot_LL		ex	af,af'		; nutna Rotace LL (v HL' Zaznam, v DE' Rodic)
		set	2,l		; "levy podstrom" Zaznamu HL' musi "pravym podstromem" Rodice DE'
		ldi
		ld	a,(hl)
		ld	(de),a
		ld	(hl),d		; Rodic DE' jako "levy podstrom" Zaznamu HL'
		dec	l
		ld	(hl),b
		ex	de,hl		; do DE' Zaznam, do HL' Rodic
		rlca			; do A: 1 <=> Rodic HL' ma "pravy podstrom", 0 <=> jinak
		rlca
		and	1
		set	2,l		; A -= ( 1 <=> Rodic HL' ma "levy podstrom", 0 <=> jinak )
		cp	(hl)
		sbc	a,0
		neg			; A=-A
		jp	_RodVyv

KorenDE		ld	(wKoren),de
		jp	_ZazVyv

Rot_RR		ex	af,af'		; nutna Rotace RR (v HL' Zaznam, v DE' Rodic)
		set	2,e		; "pravy podstrom" Zaznamu HL' musi "levym podstromem" Rodice DE'
		ldi
		ld	a,(hl)
		ld	(de),a
		ld	(hl),d		; Rodic DE' jako "pravy podstrom" Zaznamu HL'
		dec	l
		ld	(hl),b
		ex	de,hl		; do DE' Zaznam, do HL' Rodic
		rlca			; do A: 1 <=> Rodic HL' ma "levy podstrom", 0 <=> jinak
		rlca
		and	1
		res	2,l		; A -= ( 1 <=> Rodic HL' ma "pravy podstrom", 0 <=> jinak )
		cp	(hl)
		sbc	a,0
		set	2,l

_RodVyv		inc	l		; urceni a nastaveni Vyvazenosti Rodice HL'
		ld	(hl),a
		ld	e,c		; obnova Low(Zaznam)
		pop	hl		; do HL' Nadrodic (tj. rodic Rodice) (v DE' Zaznam)
		ld	a,h
		or	a
		jr	z,KorenDE
		pop	af		; do A specificke informace o Rodici
		or	a
		ld	b,l		; do B' zaloha Low(Nadrodic) (pro pripad ze nutna Dvojita rotace)
		jr	nz,_NadRod	; ma-li Zaznam soucasti "praveho podstromu" Nadrodice, skoc
		set	2,l		; Zaznam soucast --"leveho podstromu"-- Nadrodice, pricti 4
_NadRod		ld	(hl),e		; Zaznam DE' jako "pravy/levy podstrom" Nadrodice HL'
		inc	l
		ld	(hl),d
		ex	af,af'		; rozhodnuti zda nutna Dvojita rotace
		jr	nz,_RotDvo

_ZazVyv		ld	a,e		; nulovani Vyvazenosti Zaznamu HL'
		or	6
		ld	e,a
		xor	a
		ld	(de),a

	



_Vyst2K		exx
_Vyst3K		or	d		; (zaruceno A=0) do A horni bajt Prefixu, tj. A=D=High(Prefix)
		jp	z,_VystuK	; prefixem je Ascii znak
		sub	SLOVNIK_PLNY>>8	; A-=High(SLOVNIK_PLNY) (protoze zarovnani Slovniku na $xx00)
		rra			; zaruceno Carry=0
		rr	e
		rra	
		rr	e
		rra	
		rr	e
		inc	a		; symbol ma kod "za" Ascii
_VystuK		.BYTE	OP_LD_HL_NN	; do HL ukaz volne pozice Vystupu ($0000 = urceno za behu)
wVystupK	.WORD	0
		ld	d,b		; do D pocet volnych bitu Vystupu
		ld	b,N_BITU	; zapis nBitu symbolu na Vystup
_Zap1K		rra
		rr	e
		rr	(hl)		; zapis nejnizsiho bitu DE do Vystupniho fifo
		dec	d
		jp	nz,_Zap2K
		inc	hl		; dalsi bajt Vystupu
		inc	h		; test zaplnenosti Vystupu
		jr	z,KonecK	; zaplnen-li Vystup, konec (Carry=0)
		dec	h
		ld	d,8
_Zap2K		djnz	_Zap1K
		ld	(wVystupK),hl	; uchovani ukaz volne pozice Vystupu
		ld	b,d		; do B zpet pocet volnych bitu Vystupu
		ld	d,0		; aktualni Znak prefixem dalsiho znaku (D=0, E=C)
		ld	e,c
bBuffOk		.BYTE	OP_JP_NN
		.WORD	RepeatK		; opcode instrukce po zpracovani celeho Buffru zmenen z Jp(NN) na Ld(HL,NN)
		ld	a,OP_JP_NN	; uprava opcodu instrukce BuffOk z Ld(HL,NN) zpet na Jp(NN)
		ld	(bBuffOk),a

		.BYTE	OP_LD_SP_NN	; obnova SP ($0000 = urceno za behu)
wSP		.WORD	0
		.BYTE	OP_LD_HL_NN	; do HL pocet sektoru na diskete ($0000 = urceno za behu)
nSektoru	.WORD	0
		pop	de
		inc	de
		push	de
		xor	a
		sbc	hl,de
		ex	de,hl		; do HL pripadny dalsi sektor
		jp	nz,SektorK	; zpracovany-li vsechny sektory, komprese hotova

		ld	a,IDHOTOVO	; A=1, tj. cela disketa zpracovana (zaruceno ze predtim A=0)
		ld	(bHotovo),a
		ld	hl,(wVystupK)	; do HL ukaz volne pozice Vystupu
_FifoK		rr	(hl)		; rolovani fifo aby na nejnizsim bitu prvni zapsany bit
		djnz	_FifoK

KonecK		ld	sp,(wSP)	; obnova SP (v pripade ze Buffer plny)
