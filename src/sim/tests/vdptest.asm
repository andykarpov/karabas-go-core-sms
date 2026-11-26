; vdptest.asm - a small SMS test ROM of this repo (GPL-3.0 like the core), sjasmplus.
; Mode 4, 192 lines. Draws, in a fixed picture the sim compares pixel for pixel:
;   rows 0-11:  16 colour bars, 16 pixels wide each (tile n = solid colour n, background palette)
;   rows 12-23: a checker of colours 1 / 2 (tile 16)
;   one 8 x 8 sprite (tile 17, sprite palette colour 1) at x = 120, y = 100
; Then plays a PSG tone (channel 0, ~440 Hz) and loops. No interrupts.

	output "vdptest.sms"
	org 0

VDP_CTRL equ $BF
VDP_DATA equ $BE
PSG      equ $7F

	di
	im 1
	ld sp, $DFF0
	jp main

	ds $66 - $, $FF
	retn                    ; pause button NMI

main:
	; VDP registers
	ld hl, vdp_regs
	ld b, vdp_regs_end - vdp_regs
	ld c, VDP_CTRL
	otir

	; clear VRAM 16 KB: address 0, write
	xor a
	out (VDP_CTRL), a
	ld a, $40
	out (VDP_CTRL), a
	ld bc, $4000
.clr:	xor a
	out (VDP_DATA), a
	dec bc
	ld a, b
	or c
	jr nz, .clr

	; CRAM: 32 colours
	xor a
	out (VDP_CTRL), a
	ld a, $C0
	out (VDP_CTRL), a
	ld hl, palette
	ld b, 32
	ld c, VDP_DATA
	otir

	; tiles 0-15: solid colour n (each tile 8 rows x 4 planes)
	xor a
	out (VDP_CTRL), a
	ld a, $40
	out (VDP_CTRL), a
	ld d, 0                 ; colour
.tile:	ld e, 8                 ; rows
.row:	ld b, 4                 ; planes
	ld a, d
.plane:	rrca                    ; plane k = bit k of the colour
	ld c, 0
	jr nc, .p0
	ld c, $FF
.p0:	push af
	ld a, c
	out (VDP_DATA), a
	pop af
	djnz .plane
	dec e
	jr nz, .row
	inc d
	ld a, d
	cp 16
	jr nz, .tile
	; tile 16: checker 1 / 2 (plane 0 = $AA, plane 1 = $55), tile 17: solid colour 1
	ld b, 8
.chk:	ld a, $AA
	out (VDP_DATA), a
	ld a, $55
	out (VDP_DATA), a
	xor a
	out (VDP_DATA), a
	out (VDP_DATA), a
	djnz .chk
	ld b, 8
.spr:	ld a, $FF
	out (VDP_DATA), a
	xor a
	out (VDP_DATA), a
	out (VDP_DATA), a
	out (VDP_DATA), a
	djnz .spr

	; name table at $3800: 24 rows x 32 entries (2 bytes each)
	xor a
	out (VDP_CTRL), a
	ld a, $78
	out (VDP_CTRL), a
	ld d, 0                 ; row
.nrow:	ld e, 0                 ; column
.ncol:	ld a, d
	cp 12
	ld a, 16                ; lower half: checker
	jr nc, .nput
	ld a, e
	srl a                   ; upper half: tile = column / 2
.nput:	out (VDP_DATA), a
	xor a
	out (VDP_DATA), a
	inc e
	ld a, e
	cp 32
	jr nz, .ncol
	inc d
	ld a, d
	cp 24
	jr nz, .nrow

	; sprite table at $3F00: y, then end marker; x / tile at $3F80
	xor a
	out (VDP_CTRL), a
	ld a, $7F
	out (VDP_CTRL), a
	ld a, 99                ; y + 1 = line 100
	out (VDP_DATA), a
	ld a, $D0
	out (VDP_DATA), a
	ld a, $80
	out (VDP_CTRL), a
	ld a, $7F
	out (VDP_CTRL), a
	ld a, 120
	out (VDP_DATA), a
	ld a, 17
	out (VDP_DATA), a

	; display on
	ld a, $C0
	out (VDP_CTRL), a
	ld a, $81
	out (VDP_CTRL), a

	; PSG: channel 0 tone 254 (~440 Hz), volume max; others off
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
	db $06, $80             ; mode 4 (M4 + M2), left column shown
	db $A0, $81             ; display off, 8 x 8 sprites
	db $FF, $82             ; name table $3800
	db $FF, $83
	db $FF, $84
	db $FF, $85             ; sprite attribute table $3F00
	db $FB, $86             ; sprite patterns at $0000
	db $00, $87             ; border colour 0
	db $00, $88             ; no scroll
	db $00, $89
	db $FF, $8A             ; no line interrupt
vdp_regs_end:

palette:	; --bbggrr
	db $00, $03, $0C, $0F, $30, $33, $3C, $3F, $15, $2A, $01, $04, $10, $05, $11, $14
	db $00, $3F, $03, $0C, $30, $0F, $3C, $33, $2A, $15, $02, $08, $20, $0A, $22, $28

	ds $7FF0 - $, $FF
	db "TMR SEGA", 0, 0, 0, 0, 0, 0, 0, $4C   ; header: no checksum, 32 KB, SMS export
