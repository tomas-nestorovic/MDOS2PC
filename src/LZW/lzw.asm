SEZNAMK	.EQU	SLOVNIK+(SLO_MAX*ZAZ_LEN)	; seznam usporadavajici Slovnik (zaznamy ve Slovniku brany jako 24bitova cisla usporadana podle velikosti vzestupne); adresa musi zarovnana na 256, tj. musi xx00
SEZ_PLN	.EQU	SEZNAMK+(SLO_MAX*2)


	;ld	hl,0		; boot sektor (zakomentovano protoze nastaveno v nadmodulu)
	;push	hl		; prvni uspesne zkomprimovany logicky sektor (zakomentovano protoze vlozeno v nadmodulu)
	;push	hl		; logicky sektor ke kompresi (zakomentovano protoze vlozeno v nadmodulu)

	ld	(_SP+1),sp	; zaloha SP

	ld	a,8		; A' = pocet volnych bitu aktualniho bajtu Vystupu
	ex	af,af'

	ld	bc,SEZNAMK	; BC' = konec Seznamu ukazatelu do Slovniku (zbytek inicializace nize)

	ld	(_HorMez+1),bc	; inicializce HorniMeze binarniho hledani
	exx

	ld	hl,SLOVNIK	; inicializace Slovniku jako prazdneho
	ld	(_SlovK+1),hl

	ld	hl,VYSTUP	; inicializce aktualniho bajtu Vystupu
	ld	(_Vystup+1),hl

	pop	hl		; do HL logicky sektor ke kompresi
	push	hl

SektorK
#IFNDEF	__DEBUG__
	call	LOGFYZ		; logicky sektor v HL na fyzickou stopu a sektor v BC

	ld	a,b		; zobrazeni statistiky o zpracovanosti stop; A = informace <0;255>
	inc	a		; "mapovani" stop z {0..N-1} na {1..N} (aby po zpracovani posledni stopy prouzek statistiky cely zeleny)
	call	Statist
	.BYTE	36		; barva (zde Paper 4, Ink 4)
	.BYTE	STP_STA		; adresa

	ld	a,(_Vystup+2)	; zobrazeni statistiky zaplnenosti Vystupu; A = informace <0;255>
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
				;  C = akt. Znak
	;exx
	;ld	hl,...		; HL' = < bez informace > (zde pouze aby adresa prvni volne pozice ve Slovniku nize vlozena do zasobniku)
				; DE' = < bez informace >
	;ld	bc,...		; BC' = Seznam ukazatelu do Slovniku (zakomentovano protoze nastaveno vyse)

RepeatK	exx
	ld	de,SEZNAMK	; inicializace DolniMeze binarniho hledani

_RepeaK	exx
	inc	iy
				; test konce Buffru
	.BYTE	$fd		; meni nasledujici instrukci na Ld(A,High(IY))
	ld	a,h
	cp	(BUFFER+512)>>8
	jp	nc,BufCelK

	ld	c,(iy+0)	; do C Znak z Buffru

	exx			; binarnim hledanim nalezeni zaznamu [Znak,Prefix] ve Slovniku; DE' = DolniMez, BC' = HorniMez binarniho hledani
HledejK	ld	a,e		; binarni hledani proveditelne pokud HorniMez>DolniMez
	sub	c
	ld	a,d
	sbc	a,b
	jp	nc,VystupK	; zadne dalsi ukazatele v Seznamu - zapis Prefixu na Vystup
	ld	h,d		; urceni Pivota jako (DolniMez+HorniMez)/2
	ld	l,e
	add	hl,bc
	rr	h		; zaruceno Carry=0
	rr	l
	res	0,l		; zarovnani na zacatek ukazatele
	ld	sp,hl		; do SP Zaznam ve Slovniku, tj. SP=(HL')
	exx
	pop	hl
	ld	sp,hl
	pop	hl		; do HL Zaznamenany Prefix
	sbc	hl,de		; zaruceno Carry=0
	jp	c,_PravyI	; Zaznamenany Prefix mensi nez akt. Prefix, hledani v "pravem intervalu" od Pivota
	jp	nz,_LevyI	; Zaznamenany Prefix vetsi nez akt. Prefix, hledani v "levem intervalu" od Pivota
	pop	af		; do A Zaznamenany Znak
	cp	c
	jp	c,_PravyI	; Zaznamenany Znak mensi nez akt. Znak, hledani v "pravem intervalu" od Pivota
	jp	nz,_LevyI	; Zaznamenany Znak vetsi nez akt. Znak, hledani v "levem intervalu" od Pivota
	add	hl,sp		; shoda (zaruceno HL=0); pouziti Zaznamu HL jako noveho Prefixu (a pokus o jeho rozsireni dalsim znakem)
	dec	hl
	dec	l		; zarovnani Zaznamu ve Slovniku zarucuje ze L nepretece
	dec	l		; zarovnani Zaznamu ve Slovniku zarucuje ze L nepretece
	dec	l		; zarovnani Zaznamu ve Slovniku zarucuje ze L nepretece
	ex	de,hl
	exx
_HorMez	ld	bc,$0000	; obnova HorniMeze binarniho hledani (konce Seznamu ukazatelu do Slovniku; $0000 = urceno za behu)
	jp	_RepeaK

_LevyI	exx			; [ZazZnak,ZazPrefix]>[AktZnak,AktPrefix] -> HorniMez=Pivot-1 ("levy interval")
	ld	b,h
	ld	c,l
	jp	HledejK
_PravyI	exx			; [ZazZnak,ZazPrefix]<[AktZnak,AktPrefix] -> DolniMez=Pivot+1 ("pravy interval")
	ex	de,hl
	inc	e
	inc	de
	jp	HledejK


BufCelK	scf			; cely Buffer zpracovan
	jp	_Vyst3K		; zapis aktualniho Prefixu na Vystup


SloPlnK	ld	bc,SEZNAMK	; vyprazdneni plneho Seznamu a Slovniku
	ld	(_HorMez+1),bc
	ld	hl,SLOVNIK
	ld	(_SlovK+1),hl
	exx
	jp	_Vyst3K


VystupK	ld	bc,(_HorMez+1)	; obnova konce Seznamu ukazatelu do Slovniku
	ld	a,b		; rozhodnuti zda do Slovniku mozno dalsi zaznam
	cp	SEZ_PLN>>8
	jp	nc,SloPlnK	; zaplnen-li Slovnik, vyprazdneni

	ld	a,e		; Slovnik nezaplnen - mozno vlozit dalsi zaznam
	cp	c		; vytvoreni volne pozice v Seznamu (aby jeho ukazatele na Zaznamy ve Slovniku vzestupne)
	ld	a,d
	sbc	a,b
	ex	de,hl		; do HL' pozice noveho ukazatele v Seznamu (vyuzito pouze pokud ukazatel nutno pridat na konec Seznamu, viz nize)
	jp	nc,_Zaznam	; novy ukazatel nutno pridat na konec Seznamu
	ld	d,b		; novy ukazatel nutno pridat "doprostred" Seznamu: Lddr = repeat (DE')=(HL') until BC'=0
	ld	e,c
	ld	a,c
	sub	l
	ld	c,a
	ld	a,b
	sbc	a,h
	ld	b,a
	ld	h,d
	ld	l,e
	dec	hl
	inc	e		; zarovnani ukazatelu Seznamu zarucuje ze E' nepretece
	lddr
	inc	hl
	ld	bc,(_HorMez+1)	; obnova konce Seznamu ukazatelu do Slovniku

_Zaznam				; vytvoreni noveho ukazatele v Seznamu
_SlovK	ld	de,$0000	; do DE' volna pozice ve Slovniku ($0000 = urceno za behu)
	ld	(hl),e
	inc	l		; zarovnani ukazatelu Seznamu zarucuje ze L' nepretece
	ld	(hl),d
	inc	c		; dalsi volna pozice pro ukazatel v Seznamu ; zarovnani ukazatelu Seznamu zarucuje ze C' nepretece
	inc	bc
	ld	(_HorMez+1),bc	; zaloha HorniMeze binarniho hledani (konce Seznamu ukazatelu do Slovniku)
	ex	de,hl		; do HL' dalsi volna pozice ve Slovniku
	inc	l		; zarovnani Zaznamu ve Slovniku zarucuje ze L' nepretece
	inc	l		; zarovnani Zaznamu ve Slovniku zarucuje ze L' nepretece
	inc	l		; zarovnani Zaznamu ve Slovniku zarucuje ze L' nepretece
	inc	hl		; aby spravna Velikost Zaznamu
	ld	(_SlovK+1),hl
	ld	sp,hl

	exx			; vytvoreni Zaznamu ve Slovniku
	ld	a,c		; uloz Znak do Slovniku
	push	af
	push	de		; uloz Prefix do Slovniku

	;or	a		; Carry=0 = Buffer dosud nezpracovan cely (zakomentovano protoze Carry=0 zaruceno)

_Vyst3K	ex	af,af'		; zaloha Carry (Buffer ne/zpracovan cely)
	ld	b,d		; do D pocet volnych bitu Vystupu a do A horni bajt Prefixu, tj. A=D=High(Prefix)
	ld	d,a
	ld	a,b
	or	a
	jp	z,_ZapisK	; prefixem je Ascii znak
	sub	SLOVNIK>>8	; A-=High(Slovnik) (protoze Slovnik na adrese $xx00)
	rra			; zaruceno Carry=0
	rr	e
	rra	
	rr	e
	inc	a		; symbol ma kod "za" Ascii
_ZapisK
_Vystup	ld	hl,$0000	; do HL ukaz volne pozice Vystupu ($0000 = urceno za behu)
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
	ld	(_Vystup+1),hl	; uchovani ukaz volne pozice Vystupu
	ld	a,d		; do A' zpet pocet volnych bitu Vystupu
	ld	d,b		; aktualni Znak prefixem dalsiho znaku (D=B=0, E=C)
	ld	e,c
	ex	af,af'		; zpracovan-li cely Buffer, konec (Carry=1)
	jp	nc,RepeatK

_SP	ld	sp,$0000	; obnova SP ($0000 = urceno za behu)
__NSekt	ld	hl,$0000	; zpracovany-li vsechny sektory, komprese hotova (0000 = instrukce upravena za chodu poctem sektoru na zdrojove diskete)
	pop	bc
	inc	bc
	push	bc
	xor	a
	sbc	hl,bc
	ld	h,b		; do HL pripadny dalsi sektor
	ld	l,c
	jp	nz,SektorK

	inc	a		; A=1, tj. cela disketa zpracovana (zaruceno ze predtim A=0)
	ld	(_Hotovo+1),a
	ex	af,af'		; rolovani fifo aby na nejnizsim bitu prvni zapsany bit
	ld	b,a
	ld	hl,(_Vystup+1)	; do HL ukaz volne pozice Vystupu
_FifoK	rr	(hl)
	djnz	_FifoK

KonecK	ld	sp,(_SP+1)	; obnova SP (v pripade ze Buffer plny)
