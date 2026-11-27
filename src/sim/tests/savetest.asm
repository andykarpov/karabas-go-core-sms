; savetest.asm - the save test ROM of this repo (GPL-3.0 like the core), sjasmplus.
; Turns the cartridge RAM on (Sega mapper, $FFFC bit 3: RAM at $8000), counts its starts there
; ("SAVE" + a counter at $8000) and shows the count as the colour of the whole screen (the backdrop):
;   1 red, 2 green, 3 blue, 4 yellow, 5 magenta, 6 cyan, 7 white, 8 grey, then again from red.
; With the .sav of the core the count goes on after the game is loaded again.

	output "savetest.sms"
	org 0

VDP_CTRL equ $BF
VDP_DATA equ $BE

	di
	im 1
	ld sp, $DFF0
	jp main

	ds $66 - $, $FF
	retn

main:
	ld a, $08               ; mapper control: cartridge RAM at $8000
	ld ($FFFC), a

	ld hl, $8000
	ld de, magic
	ld b, 4
.cmp:	ld a, (de)
	cp (hl)
	jr nz, .fresh
	inc hl
	inc de
	djnz .cmp
	jr .count
.fresh:	ld hl, magic             ; a new RAM: the magic and a count of 0
	ld de, $8000
	ld bc, 4
	ldir
	xor a
	ld ($8004), a
.count:	ld a, ($8004)
	inc a
	ld ($8004), a

	; the colour of the count: CRAM 0 (the backdrop) and 16
	dec a
	and 7
	ld e, a
	ld d, 0
	ld hl, colours
	add hl, de
	ld b, (hl)
	xor a
	out (VDP_CTRL), a
	ld a, $C0
	out (VDP_CTRL), a
	ld a, b
	out (VDP_DATA), a

	ld hl, vdp_regs
	ld b, vdp_regs_end - vdp_regs
	ld c, VDP_CTRL
	otir

.loop:	jr .loop

magic:	db "SAVE"
colours:	; --bbggrr
	db $03, $0C, $30, $0F, $33, $3C, $3F, $15

vdp_regs:
	db $06, $80             ; mode 4
	db $C0, $81             ; display on, no sprites shown (the table is empty: y = 0 everywhere)
	db $FF, $82
	db $FF, $85
	db $00, $87             ; border = colour 0
vdp_regs_end:

	ds $7FF0 - $, $FF
	db "TMR SEGA", 0, 0, 0, 0, 0, 0, 0, $4C
