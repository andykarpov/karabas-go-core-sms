; sgtest.asm - a small SG-1000 test ROM of this repo (GPL-3.0 like the core), sjasmplus.
; TMS9918 Graphics I mode (the SG-1000 / SC-3000 mode). Draws:
;   rows 0-11:  16 colour bars of the TMS palette, 16 pixels wide each (characters 8 n..8 n+7 are solid,
;               colour table entry n = colour n on colour n)
;   rows 12-23: a checker of colours 2 / 6 (character 128: $AA / $55)
;   one 8 x 8 sprite of colour 15 at x = 120, y = 100
; Then plays a PSG tone (channel 0, ~440 Hz) and loops. No interrupts.

	output "sgtest.sg"
	org 0

VDP_CTRL equ $BF
VDP_DATA equ $BE
PSG      equ $7F

	di
	im 1
	ld sp, $C3F0            ; the SG-1000 has 1 KB of RAM at $C000
	jp main

	ds $66 - $, $FF
	retn

; VRAM address in DE for a write
setw:	ld a, e
	out (VDP_CTRL), a
	ld a, d
	or $40
	out (VDP_CTRL), a
	ret

main:
	ld hl, vdp_regs
	ld b, vdp_regs_end - vdp_regs
	ld c, VDP_CTRL
	otir

	; clear VRAM 16 KB
	ld de, 0
	call setw
	ld bc, $4000
.clr:	xor a
	out (VDP_DATA), a
	dec bc
	ld a, b
	or c
	jr nz, .clr

	; patterns $0000: characters 0-127 solid, 128 checker
	ld de, $0000
	call setw
	ld bc, 128 * 8
.pat:	ld a, $FF
	out (VDP_DATA), a
	dec bc
	ld a, b
	or c
	jr nz, .pat
	ld b, 4
.chk:	ld a, $AA
	out (VDP_DATA), a
	ld a, $55
	out (VDP_DATA), a
	djnz .chk

	; colour table $2000: entry n (characters 8 n..8 n+7) = n on n; entry 16 = 2 on 6
	ld de, $2000
	call setw
	xor a
.col:	ld c, a
	rlca
	rlca
	rlca
	rlca
	or c
	out (VDP_DATA), a
	ld a, c
	inc a
	cp 16
	jr nz, .col
	ld a, $26
	out (VDP_DATA), a

	; name table $3800: rows 0-11 column c = character (c / 2) * 8, rows 12-23 character 128
	ld de, $3800
	call setw
	ld d, 0
.nrow:	ld e, 0
.ncol:	ld a, d
	cp 12
	ld a, 128
	jr nc, .nput
	ld a, e
	and $1E
	add a, a
	add a, a                ; (c / 2) * 8
.nput:	out (VDP_DATA), a
	inc e
	ld a, e
	cp 32
	jr nz, .ncol
	inc d
	ld a, d
	cp 24
	jr nz, .nrow

	; sprite pattern 0 at $0800: solid
	ld de, $0800
	call setw
	ld b, 8
.sp:	ld a, $FF
	out (VDP_DATA), a
	djnz .sp
	; sprite attributes $3F00: y, x, pattern, colour; then the end marker
	ld de, $3F00
	call setw
	ld a, 99
	out (VDP_DATA), a
	ld a, 120
	out (VDP_DATA), a
	xor a
	out (VDP_DATA), a
	ld a, 15
	out (VDP_DATA), a
	ld a, $D0
	out (VDP_DATA), a

	; display on
	ld a, $C0
	out (VDP_CTRL), a
	ld a, $81
	out (VDP_CTRL), a

	; PSG: channel 0 tone 254, volume max; others off
	ld a, $80 | (254 & $0F)
	out (PSG), a
	ld a, 254 >> 4
	out (PSG), a
	ld a, $90
	out (PSG), a
	ld a, $BF
	out (PSG), a
	ld a, $DF
	out (PSG), a
	ld a, $FF
	out (PSG), a

.loop:	jr .loop

vdp_regs:
	db $00, $80             ; Graphics I
	db $80, $81             ; 16 KB, display off
	db $0E, $82             ; name table $3800
	db $80, $83             ; colour table $2000
	db $00, $84             ; patterns $0000
	db $7E, $85             ; sprite attributes $3F00
	db $01, $86             ; sprite patterns $0800
	db $01, $87             ; border black
vdp_regs_end:

	ds $8000 - $, $FF
