; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
; Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
; option) any later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
; implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
; for more details.
;
; You should have received a copy of the GNU General Public License along with this program.  If not, see
; <https://www.gnu.org/licenses/>.

; The page turn of the parchment (CPC 65FDh) on the C64: the turning corner (686Ch), the border restores (65A4h,
; 6633h-6654h, 666Bh) and the CPC's time for each step.  (c64/pergamino/revision_pagina/NOTAS.md)
;
; Assembled as part of pixel.s (.include at its end): it uses pixel.s's tables and _pon_byte_rapido, and pixel.s
; calls its borra_cap.
;
; The CPC's 65FDh: 45 steps with the corner at x = D3h, CFh, ... 23h, y = 0, 3 to 47 bands, each step the corner, a
; delay of 2000 passes (672Ch) and 65A4h (two columns of the top border at x + 4, eight lines of the right border at
; 4 (bands - 3)); 65A4h once more; 46 steps with the corner at x = 20h, y = 4, 8, ... B8h, 47 down to 2 bands, each
; the corner, the delay, four lines of the left border (y - 4 .. y - 1) and 666Bh (a column of the bottom border:
; the band count's); 666Bh for the last count and for 0.
;
; The corner (686Ch): `es_b` bands of 4 lines from window (es_x, es_y).  In band d (0 = the top), line l (0-3) the
; CPC writes F0 (4 pixels of pen 1, the dark red back of the page) at byte 0 (x >> 2) unless d = 0, the edge byte
; (80, C0, E0, F0 for l = 0-3: pen 1 then pen 0, the new page) at byte d and 00 (pen 0) at byte d + 1; in the last
; band F0 at bytes 0 .. d - 1.  Here a CPC byte is a nibble of a bitmap byte (pixel.s), written 4 lines at a time: a
; band's 4 lines are always in one cell row (y is a multiple of 4).  Every cell the corner reaches (cell columns 8-31,
; rows 0-23) has the parchment's pink as its background (pergamino_en_blanco and the border cells of the data
; generator; nothing changes a background), where pixel.s's rule comes down to: a pen 1 pixel makes red the cell's
; foreground (what is left of the text in the cell turns red with it: the dark back of the page covering the text)
; and sets its bit, a pen 0 pixel clears its bit.  (A cell with another background takes pixel.s's full path byte by
; byte: `nib`.)
;
; The capitals (sprites): the CPC's corner writes over the capitals' pixels with the old page's text.  In the first
; phase the bytes it has written by a step are exactly bytes x >> 2 .. 55 of the lines of its bands (each band, from the
; step it first appears, is the last band's run of F0 to its edge and 00, then one byte more to the left each step):
; after each step of the first phase every capital loses its pixels at window x >= 4 (x >> 2) on lines < 4 bands
; (capitales_paso).  At the end of the first phase (x >> 2 = 8, lines 0-187) nothing is left of any capital (the
; text and its capitals start at x 2Ch and lie within lines 10h-B4h: the last line is at A0h), so the second phase has
; none to clear.
;
; The restores put back the CPC's border bytes.  Here they put back whole cells of the blank parchment's border (the
; data generator's cells, perg_blanco_*: the CPC's border bytes under the pixel rule, as at the start), and where
; the CPC has put back only part of a cell whose other part the corner still holds, those lines or that nibble of the
; blank cell's bitmap, the cell keeping its colours (red over pink: the border's dark pixels there show red until the
; next step puts back the rest of the cell, as pixel.s's rule showed them).  Which cells are whole follows from the
; corner's geometry: after each step every border byte the corner has passed is back but those of its last band(s).
;
; The time: a CPC step is its corner, the delay and the restores.  Measured in Caprice32 (revision_pagina/NOTAS.md:
; the readings of BC inside each step's delay, cpc_pasos.py), a step of the first phase takes 20.00 ms + 0.569 ms a
; band of its corner and one of the second phase 18.47 ms + 0.569 ms a band (a second run: 20.18, 18.61, 0.565):
; 3.03 s for the 91 steps (Caprice32's turn: 3.035 s).
; Here each step waits for that time with espera.s's deadline (passes of 9.0625 cycles: 2174 + 62 bands and 2008 +
; 62 bands), so the drawing, which takes less, is absorbed and the turn has the CPC's pace and length.

        .export _pasa_pagina, _esquina_asm, _es_x, _es_y, _es_b, _perg_anillo
        .import _espera
        .import _perg_blanco_color, _perg_blanco_bitmap
        .import _cap_xb_lo, _cap_xb_hi, _cap_wx, _cap_wy, _cap_usadas
        .importzp sreg, regsave
.ifdef MIDE
        .import _musica_ticks
.endif
; a probe of the test build (marca, below)
.macro MARCA
.ifdef MIDE
        jsr     marca
.endif
.endmacro

BM = regsave            ; the bitmap byte of the cell being written (its band's first line; a restore's line 0)
CE = ptr4               ; the band's row of cell colours
SPR = sreg              ; borra_cap: the sprite row
SRC = sreg              ; the restores: the blank cell's bitmap

PASOS_A = 2174          ; the deadline of a step, passes: the first phase's 20.00 ms
PASOS_B = 2008          ; the second phase's 18.47 ms
                        ; and 62 passes (0.569 ms) a band: plazo

; nib, the general write of the corner: a kind is even, + 1 for a low nibble; an entry of 16 bytes: the pen 1
; pixels of the 4 lines where they go, the bits kept, pen 1 in it, two columns (a whole bitmap byte), a pad byte, the
; CPC bytes of the 4 lines (pixel.s's full path) and those of the second column
F0      = 0             ; F0
CANTO   = 2             ; the edge: 80 C0 E0 F0
CERO    = 4             ; 00
F0F0    = 6             ; F0 in both nibbles (the last band's run)
CANTO0  = 8             ; the edge in the high nibble and 00 in the low one

.segment "RODATA"
tabla:  .byte $F0, $F0, $F0, $F0, $0F, 1, 0, 0, $F0, $F0, $F0, $F0, 0, 0, 0, 0          ; F0, high nibble
        .byte $0F, $0F, $0F, $0F, $F0, 1, 0, 0, $F0, $F0, $F0, $F0, 0, 0, 0, 0          ; F0, low
        .byte $80, $C0, $E0, $F0, $0F, 1, 0, 0, $80, $C0, $E0, $F0, 0, 0, 0, 0          ; the edge, high
        .byte $08, $0C, $0E, $0F, $F0, 1, 0, 0, $80, $C0, $E0, $F0, 0, 0, 0, 0          ; the edge, low
        .byte 0, 0, 0, 0, $0F, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0                          ; 00, high
        .byte 0, 0, 0, 0, $F0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0                          ; 00, low
        .byte $FF, $FF, $FF, $FF, 0, 1, 1, 0, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0    ; F0 F0
        .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0                            ; (never at a low nibble)
        .byte $80, $C0, $E0, $F0, 0, 1, 1, 0, $80, $C0, $E0, $F0, 0, 0, 0, 0            ; edge, 00
; borra_cap: the AND masks of a sprite row's 3 bytes that clear its pixels dx .. dx + 3 (those in 0-23), for
; dx + 6 = 0 .. 29 (pixel p is bit 7 - (p & 7) of byte p >> 3)
bc_m0:  .byte $FF, $FF, $FF, $7F, $3F, $1F, $0F, $87, $C3, $E1, $F0, $F8, $FC, $FE, $FF
        .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
bc_m1:  .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $7F, $3F, $1F, $0F
        .byte $87, $C3, $E1, $F0, $F8, $FC, $FE, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
bc_m2:  .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
        .byte $FF, $FF, $FF, $FF, $7F, $3F, $1F, $0F, $87, $C3, $E1, $F0, $F8, $FC, $FE
spr_lo: .repeat 8, i                    ; capital i's sprite: $8400 + 64 i (main.c)
        .byte <($8400 + i * 64)
        .endrep
spr_hi: .repeat 8, i
        .byte >($8400 + i * 64)
        .endrep
por3:   .repeat 21, i
        .byte i * 3
        .endrep
; capitales_paso: the AND masks of a sprite row's 3 bytes that keep its pixels 0 .. p - 1 (p = 0 .. 23)
cap_k0: .repeat 24, p
        .byte <((($1000000 - ($1000000 >> p)) & $FFFFFF) >> 16)
        .endrep
cap_k1: .repeat 24, p
        .byte <((($1000000 - ($1000000 >> p)) & $FFFFFF) >> 8)
        .endrep
cap_k2: .repeat 24, p
        .byte <(($1000000 - ($1000000 >> p)) & $FFFFFF)
        .endrep

.segment "BSS"
_es_x:  .res 1          ; _esquina_asm's arguments
_es_y:  .res 1
_es_b:  .res 1
; the blank parchment's border cells (main.c fills it from perg_blanco_celda): their entries in perg_blanco_*,
; top row by cell column - 8, bottom row (23) likewise, left column (8) by row, right column (31) by row
_perg_anillo: .res 4 * 24
ARRIBA = _perg_anillo
ABAJO = _perg_anillo + 24
IZQUIERDA = _perg_anillo + 48
DERECHA = _perg_anillo + 72
e_b0:   .res 1          ; byte 0 of the corner (x >> 2)
e_e:    .res 1          ; its edge's byte column (b0 + d)
e_y:    .res 1          ; its first line
e_bm:   .res 2          ; the bitmap address of its first line in cell column 0
e_xb:   .res 1          ; nib's byte column
e_n:    .res 1
e_fin:  .res 1          ; the corner's last line + 1
g_bm:   .res 2          ; BM and CE kept around the general write
g_ce:   .res 2
t_cc:   .res 1          ; the strip of F0 at byte 0: its cell column, its offset
t_off:  .res 2
n_ent:  .res 1          ; nib: the entry (16 x)
n_l:    .res 1
rojo_fg: .res 1         ; red << 4 | pink: a cell's colours once pen 1 is in it
rosa:   .res 1
p_x:    .res 1          ; _pasa_pagina: x, bands, steps left, y
p_c:    .res 1
p_n:    .res 1
p_y:    .res 1
p_base: .res 2          ; the deadline's constant part
pz_lo:  .res 1
pz_hi:  .res 1
r_fila: .res 1          ; copia: the cell, the lines, the bits
r_col:  .res 1
r_l0:   .res 1
r_l1:   .res 1
r_bits: .res 1
r_deja: .res 1
ck0:    .res 1          ; capitales_paso: the masks, the rows
ck1:    .res 1
ck2:    .res 1
cn:     .res 1
bc_bits: .res 1         ; borra_cap
bc_i:   .res 1
bc_idx: .res 1

.segment "CODE"

; a test build (ca65 -D MIDE) writes the time before and after a loop of known length, at each step's start, after
; its corner and after its wait, and at the end, from $C000 (free while the parchment runs): the interrupt count (2
; bytes), CIA 1 timer A (high, low, high again) and CIA 2 timer A (likewise); MIDE = 2 draws the corner with the
; interrupt held off (its own cycles, from CIA 2) (revision_pagina/c64_pasos.py)
.ifdef MIDE
.proc marca
        php
        sei
        pha
        lda     _musica_ticks
        jsr     guarda
        lda     _musica_ticks+1
        jsr     guarda
        lda     $DC05
        jsr     guarda
        lda     $DC04
        jsr     guarda
        lda     $DC05
        jsr     guarda
        lda     $DD05                   ; and CIA 2 timer A (free-running: espera.s), high, low, high again
        jsr     guarda
        lda     $DD04
        jsr     guarda
        lda     $DD05
        jsr     guarda
        pla
        plp
        rts
guarda:
mp:     sta     $C000
        inc     mp+1
        bne     :+
        inc     mp+2
:       rts
.endproc
.endif

; void pasa_pagina(void): CPC 65FDh
.proc _pasa_pagina
        lda     _perg_color_pluma+1     ; pen 1's red as the foreground over the pink
        asl     a
        asl     a
        asl     a
        asl     a
        ora     _perg_color_pluma+0
        sta     rojo_fg
        lda     _perg_color_pluma+0
        sta     rosa
.ifdef MIDE
        lda     #<$C000                 ; the test build: each turn's probes from $C000
        sta     marca::mp+1
        lda     #>$C000
        sta     marca::mp+2
        MARCA                           ; 51359 cycles of a loop, timed (the interrupt's share)
        ldx     #0
        ldy     #40
:       dex
        bne     :-
        dey
        bne     :-
        MARCA
.endif
        ; the first phase: the corner from the top right
        lda     #<PASOS_A
        sta     p_base
        lda     #>PASOS_A
        sta     p_base+1
        lda     #$2D
        sta     p_n
        lda     #3
        sta     p_c
        lda     #$D3
        sta     p_x
f1:     MARCA
        lda     p_x
        sta     _es_x
        lda     #0
        sta     _es_y
        lda     p_c
        sta     _es_b
.ifdef MIDE
.if ::MIDE = 2
        sei                             ; MIDE = 2: the corner alone, the interrupt held off
.endif
.endif
        jsr     _esquina_asm
        jsr     capitales_paso
.ifdef MIDE
.if ::MIDE = 2
        cli
.endif
.endif
        MARCA
        jsr     plazo
        jsr     _espera
        MARCA
        jsr     arriba_derecha
        lda     p_x
        sec
        sbc     #4
        sta     p_x
        inc     p_c
        dec     p_n
        bne     f1
        jsr     arriba_derecha
        ; the second phase: the corner down the left
        lda     #<PASOS_B
        sta     p_base
        lda     #>PASOS_B
        sta     p_base+1
        lda     #$2F
        sta     p_c
        lda     #4
        sta     p_y
        lda     #$2E
        sta     p_n
f2:     MARCA
        lda     #$20
        sta     _es_x
        lda     p_y
        sta     _es_y
        lda     p_c
        sta     _es_b
.ifdef MIDE
.if ::MIDE = 2
        sei                             ; MIDE = 2: the corner alone, the interrupt held off
.endif
.endif
        jsr     _esquina_asm
.ifdef MIDE
.if ::MIDE = 2
        cli
.endif
.endif
        MARCA
        jsr     plazo
        jsr     _espera
        MARCA
        jsr     izquierda
        lda     p_c
        jsr     abajo
        lda     p_y
        clc
        adc     #4
        sta     p_y
        dec     p_c
        dec     p_n
        bne     f2
        lda     p_c
        jsr     abajo
        lda     #0
        jsr     abajo
        MARCA
        rts
.endproc

; A/X = p_base + 62 p_c: the step's deadline in espera.s's passes
.proc plazo
        lda     p_c                     ; 64 c
        lsr     a
        lsr     a
        sta     pz_hi
        lda     p_c
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        sta     pz_lo
        lda     p_c                     ; - 2 c
        asl     a
        sta     n_l
        lda     pz_lo
        sec
        sbc     n_l
        sta     pz_lo
        lda     pz_hi
        sbc     #0
        sta     pz_hi
        lda     pz_lo                   ; + the constant
        clc
        adc     p_base
        sta     pz_lo
        lda     pz_hi
        adc     p_base+1
        tax
        lda     pz_lo
        rts
.endproc

; ---- the restores ---------------------------------------------------------------------------------------------

; copy the blank cell X (an entry of perg_blanco_*; $FF: none) into the cell (r_fila, r_col): bitmap lines
; r_l0 .. r_l1 - 1, the bits r_bits of each; with every line and every bit, its colours too
.proc copia
        cpx     #$FF
        bne     :+
        rts
:       txa                             ; SRC = perg_blanco_bitmap + 8 X
        sta     pz_lo
        lda     #0
        sta     pz_hi
        asl     pz_lo
        rol     pz_hi
        asl     pz_lo
        rol     pz_hi
        asl     pz_lo
        rol     pz_hi
        lda     pz_lo
        clc
        adc     #<_perg_blanco_bitmap
        sta     SRC
        lda     pz_hi
        adc     #>_perg_blanco_bitmap
        sta     SRC+1
        ldy     r_fila                  ; BM = the cell's bitmap
        lda     bm_lo,y
        sta     BM
        lda     bm_hi,y
        sta     BM+1
        ldy     r_col
        lda     c8_lo,y
        clc
        adc     BM
        sta     BM
        lda     c8_hi,y
        adc     BM+1
        sta     BM+1
        ldy     r_l0
        lda     r_bits
        cmp     #$FF
        bne     bits
todo:   lda     (SRC),y                 ; whole lines
        sta     (BM),y
        iny
        cpy     r_l1
        bne     todo
        beq     color
bits:   eor     #$FF
        sta     r_deja
lin:    lda     (SRC),y
        and     r_bits
        sta     n_l
        lda     (BM),y
        and     r_deja
        ora     n_l
        sta     (BM),y
        iny
        cpy     r_l1
        bne     lin
        rts
color:  lda     r_l0                    ; the whole cell: its colours
        bne     fin
        lda     r_l1
        cmp     #8
        bne     fin
        ldy     r_fila
        lda     ce_lo,y
        sta     BM
        lda     ce_hi,y
        sta     BM+1
        ldy     r_col
        lda     _perg_blanco_color,x
        sta     (BM),y
fin:    rts
.endproc

; the whole cell (r_fila, A = cell column) from the blank cell X
.proc celda_entera
        sta     r_col
        lda     #0
        sta     r_l0
        lda     #8
        sta     r_l1
        lda     #$FF
        sta     r_bits
        jmp     copia
.endproc

; 65A4h after the step with the corner at p_x and p_c bands: the CPC puts back the top border's bytes b = (x + 4) >> 2
; and b + 1 (lines 0-7), which the corner's two top bands had passed; the bytes right of them are back from the earlier
; steps and the corner's own (b - 1 and left of it) stay.  So: b even, the cell of b and b + 1 is whole again; b odd,
; b's nibble (the cell's low one: the high one, b - 1, is the corner's) and the next cell (b + 1 and b + 2) whole.
; Then the right border's 8 lines y0 = 4 (bands - 3) .. y0 + 7 (bytes DAh >> 2 and + 1: all of cell column 31), which
; the corner's bands c - 3 and c - 2 had passed: its last band (lines 4c - 4 .. 4c - 1) still holds those bytes.  So
; y0 a multiple of 8: the cell of row y0 / 8 whole; else the cell of row y0 >> 3 whole (its lines 0-3 are back from
; the step before) and lines 0-3 of the next.
.proc arriba_derecha
        lda     #0
        sta     r_fila
        lda     p_x
        clc
        adc     #4
        lsr     a
        lsr     a                       ; b
        lsr     a                       ; C: b odd
        bcs     impar
        adc     #4                      ; the cell of b and b + 1 (C = 0)
        tay
        ldx     ARRIBA-8,y
        tya
        jsr     celda_entera
        jmp     derecha
impar:  adc     #4 - 1                  ; (C = 1) the cell of b - 1 and b: b's nibble, lines 0-7
        sta     r_col
        tay
        ldx     ARRIBA-8,y
        lda     #0
        sta     r_l0
        lda     #8
        sta     r_l1
        lda     #$0F
        sta     r_bits
        jsr     copia
        ldy     r_col                   ; the next cell whole
        iny
        ldx     ARRIBA-8,y
        tya
        jsr     celda_entera
derecha:
        lda     p_c
        sec
        sbc     #3
        asl     a
        asl     a                       ; y0
        lsr     a
        lsr     a
        lsr     a                       ; its row; C: y0 not a multiple of 8
        php
        sta     r_fila
        tay
        ldx     DERECHA,y
        lda     #31
        jsr     celda_entera
        plp
        bcc     :+
        inc     r_fila                  ; lines 0-3 of the next row
        ldy     r_fila
        ldx     DERECHA,y
        lda     #0
        sta     r_l0
        lda     #4
        sta     r_l1
        jmp     copia                   ; (r_col = 31, r_bits = FF)
:       rts
.endproc

; 6633h-6654h after the second phase's step at p_y: the left border's 4 lines p_y - 4 .. p_y - 1 (bytes 20h >> 2 and
; + 1: all of cell column 8), the corner's own from p_y down.  Lines 4-7 of a cell: the cell whole (lines 0-3 back
; from the step before); lines 0-3: those lines.
.proc izquierda
        lda     p_y
        sec
        sbc     #4
        lsr     a
        lsr     a
        lsr     a                       ; the row; C: lines 4-7
        sta     r_fila
        tay
        ldx     IZQUIERDA,y
        lda     #8
        bcc     :+
        jmp     celda_entera
:       sta     r_col
        lda     #0
        sta     r_l0
        lda     #4
        sta     r_l1
        lda     #$FF
        sta     r_bits
        jmp     copia
.endproc

; 666Bh: byte A + 8 of the bottom border (lines B8h-BFh: cell row 23), the corner's last bands still holding the bytes
; left of it and the bytes right of it back from the steps before.  A even: the high nibble of a cell whose low nibble
; is back: the cell whole; A odd: the low nibble.
.proc abajo
        ldx     #23
        stx     r_fila
        lsr     a                       ; (A + 8) >> 1 + 4 = A >> 1 + 8; C: A odd
        php
        clc
        adc     #8
        sta     r_col
        tay
        ldx     ABAJO-8,y
        plp
        bcs     :+
        lda     r_col
        jmp     celda_entera
:       lda     #0
        sta     r_l0
        lda     #8
        sta     r_l1
        lda     #$0F
        sta     r_bits
        jmp     copia
.endproc

; ---- the capitals ---------------------------------------------------------------------------------------------

; after the first phase's corner at p_x with p_c bands: each capital sprite loses its pixels at window x >= 4 (p_x >> 2)
; on lines < 4 p_c, the bytes the corner has written so far (see the top)
.proc capitales_paso
        ldx     _cap_usadas
        beq     fin
        dex
cap:    lda     p_x                     ; the first pixel cleared: 4 (x >> 2) - the capital's window x (0 if less)
        and     #$FC
        sec
        sbc     _cap_wx,x
        bcs     :+
        lda     #0
:       cmp     #24
        bcs     sig                     ; not reached yet
        tay
        lda     cap_k0,y                ; the pixels kept: those left of it
        sta     ck0
        lda     cap_k1,y
        sta     ck1
        lda     cap_k2,y
        sta     ck2
        lda     p_c                     ; the rows: lines < 4 bands
        asl     a
        asl     a
        sec
        sbc     _cap_wy,x
        bcc     sig
        beq     sig
        cmp     #21
        bcc     :+
        lda     #21
:       sta     cn
        lda     spr_lo,x
        sta     SPR
        lda     spr_hi,x
        sta     SPR+1
        ldy     #0
fila:   lda     (SPR),y
        and     ck0
        sta     (SPR),y
        iny
        lda     (SPR),y
        and     ck1
        sta     (SPR),y
        iny
        lda     (SPR),y
        and     ck2
        sta     (SPR),y
        iny
        dec     cn
        bne     fila
sig:    dex
        bpl     cap
fin:    rts
.endproc

; ---- the corner -------------------------------------------------------------------------------------------------

; 4 lines of the strip from line Y of BM (its nibble's immediates set by _esquina_asm)
.proc cuatro
        lda     (BM),y
k0:     and     #$0F
p0:     ora     #$F0
        sta     (BM),y
        iny
        lda     (BM),y
k1:     and     #$0F
p1:     ora     #$F0
        sta     (BM),y
        iny
        lda     (BM),y
k2:     and     #$0F
p2:     ora     #$F0
        sta     (BM),y
        iny
        lda     (BM),y
k3:     and     #$0F
p3:     ora     #$F0
        sta     (BM),y
        rts
.endproc

; void esquina_asm(void): CPC 686Ch, the corner: es_b (>= 2) bands of 4 lines from window (es_x, es_y).  Written in
; three passes (the bytes are different and each write is "pen 1: set, foreground red" or "pen 0: clear", so the
; order does not change the result): the strip of F0 at byte 0 down bands 1 .. es_b - 1, a cell row at a time; the
; edge and its 00 band by band; the rest of the last band's F0.
.proc _esquina_asm
        lda     _es_x
        lsr     a
        lsr     a
        sta     e_b0
        lsr     a                       ; the strip's cell column, its offset and its nibble
        php
        clc
        adc     #4
        sta     t_cc
        tay
        lda     c8_lo,y
        sta     t_off
        lda     c8_hi,y
        sta     t_off+1
        plp
        lda     #$F0
        ldx     #$0F
        bcc     :+
        lda     #$0F
        ldx     #$F0
:       sta     cuatro::p0+1
        sta     cuatro::p1+1
        sta     cuatro::p2+1
        sta     cuatro::p3+1
        stx     cuatro::k0+1
        stx     cuatro::k1+1
        stx     cuatro::k2+1
        stx     cuatro::k3+1
        lda     _es_b                   ; the last line + 1: es_y + 4 es_b (<= 192)
        asl     a
        asl     a
        clc
        adc     _es_y
        sta     e_fin

        ; 1. the strip: lines es_y + 4 .. e_fin - 1 at byte b0; BM, CE: its cell in the row of e_y
        lda     _es_y
        clc
        adc     #4
        sta     e_y
        lsr     a
        lsr     a
        lsr     a
        tax
        lda     bm_lo,x
        clc
        adc     t_off
        sta     BM
        lda     bm_hi,x
        adc     t_off+1
        sta     BM+1
        lda     ce_lo,x
        clc
        adc     t_cc
        sta     CE
        lda     ce_hi,x
        adc     #0
        sta     CE+1
franja: ldy     #0                      ; the cell's colours
        lda     (CE),y
        and     #$0F
        cmp     rosa
        bne     f_lenta
        lda     rojo_fg
        sta     (CE),y
        lda     e_y                     ; its lines: e_y & 4 .. 7, or .. 3 at the end
        and     #4
        tay
        jsr     cuatro
        lda     e_y
        clc
        adc     #4
        sta     e_y
        cmp     e_fin
        bcs     f_fin
        and     #4
        beq     f_fila
        ldy     #4                      ; the cell's lower half
        jsr     cuatro
        lda     e_y
        clc
        adc     #4
        sta     e_y
        cmp     e_fin
        bcs     f_fin
f_fila: lda     BM                      ; the next row
        clc
        adc     #<320
        sta     BM
        lda     BM+1
        adc     #>320
        sta     BM+1
        lda     CE
        clc
        adc     #40
        sta     CE
        bcc     franja
        inc     CE+1
        bcs     franja
f_lenta:
        jsr     f_nib                   ; (another background: the general write, half a row at a time)
        lda     e_y
        clc
        adc     #4
        sta     e_y
        cmp     e_fin
        bcs     f_fin
        and     #4
        beq     f_fila
        jsr     f_nib
        lda     e_y
        clc
        adc     #4
        sta     e_y
        cmp     e_fin
        bcc     f_fila

f_fin:  ; 2. the edge at e = b0 + d and 00 at e + 1, band d at es_y + 4 d; BM: line es_y + 4 d of e's cell, CE: e's cell
        lda     _es_y
        sta     e_y
        lsr     a
        lsr     a
        lsr     a
        tax
        lda     e_b0
        sta     e_e
        lsr     a
        clc
        adc     #4
        tay
        lda     ce_lo,x
        sta     CE
        lda     ce_hi,x
        sta     CE+1
        tya
        clc
        adc     CE
        sta     CE
        bcc     :+
        inc     CE+1
:       lda     _es_y
        and     #4
        clc
        adc     bm_lo,x
        sta     BM
        lda     bm_hi,x
        adc     #0
        sta     BM+1
        lda     c8_lo,y
        clc
        adc     BM
        sta     BM
        lda     c8_hi,y
        adc     BM+1
        sta     BM+1
bordes: lda     e_e
        lsr     a
        bcs     impar
        ldy     #0                      ; e even: one bitmap byte, the edge's nibble and 00's
        lda     (CE),y
        and     #$0F
        cmp     rosa
        bne     b_lento
        lda     rojo_fg
        sta     (CE),y
        lda     #$80
        sta     (BM),y
        iny
        lda     #$C0
        sta     (BM),y
        iny
        lda     #$E0
        sta     (BM),y
        iny
        lda     #$F0
        sta     (BM),y
        jmp     b_sig
impar:  ldy     #0                      ; e odd: the edge in this cell's low nibble, 00 in the next cell's high one
        lda     (CE),y
        and     #$0F
        cmp     rosa
        bne     b_lento
        iny
        lda     (CE),y
        and     #$0F
        cmp     rosa
        bne     b_lento
        dey
        lda     rojo_fg
        sta     (CE),y
        lda     (BM),y
        and     #$F0
        ora     #$08
        sta     (BM),y
        iny
        lda     (BM),y
        and     #$F0
        ora     #$0C
        sta     (BM),y
        iny
        lda     (BM),y
        and     #$F0
        ora     #$0E
        sta     (BM),y
        iny
        lda     (BM),y
        ora     #$0F
        sta     (BM),y
        ldy     #8
        lda     (BM),y
        and     #$0F
        sta     (BM),y
        iny
        lda     (BM),y
        and     #$0F
        sta     (BM),y
        iny
        lda     (BM),y
        and     #$0F
        sta     (BM),y
        iny
        lda     (BM),y
        and     #$0F
        sta     (BM),y
        jmp     b_sig
b_lento:
        jsr     b_nib
b_sig:  lda     e_y                     ; the next band
        clc
        adc     #4
        cmp     e_fin
        bcs     resto
        sta     e_y
        inc     e_e
        lda     e_e
        lsr     a
        bcs     mismo                   ; e odd: the cell of e - 1
        lda     BM                      ; e even: the next cell column
        clc
        adc     #8
        sta     BM
        bcc     :+
        inc     BM+1
:       inc     CE
        bne     mismo
        inc     CE+1
mismo:  lda     e_y                     ; the lower half of the row, or the next row
        and     #4
        beq     :+
        lda     BM
        clc
        adc     #4
        sta     BM
        bcc     bordes2
        inc     BM+1
        bcs     bordes2
:       lda     BM
        clc
        adc     #<(320 - 4)
        sta     BM
        lda     BM+1
        adc     #>(320 - 4)
        sta     BM+1
        lda     CE
        clc
        adc     #40
        sta     CE
        bcc     bordes2
        inc     CE+1
bordes2:
        jmp     bordes

        ; 3. the last band (e_y): F0 at bytes b0 + 1 .. b0 + d - 1
resto:  lda     e_e
        sec
        sbc     e_b0                    ; d
        cmp     #2
        bcc     :+
        sbc     #1                      ; (C = 1) d - 1 bytes
        sta     e_n
        ldx     e_b0
        inx
        stx     e_xb
        jsr     fila_banda
        jmp     corrida
:       rts
.endproc

; e_bm and CE (the row of cell colours) for the band at e_y
.proc fila_banda
        lda     e_y
        lsr     a
        lsr     a
        lsr     a
        tax
        lda     e_y
        and     #4
        clc
        adc     bm_lo,x
        sta     e_bm
        lda     bm_hi,x
        adc     #0
        sta     e_bm+1
        lda     ce_lo,x
        sta     CE
        lda     ce_hi,x
        sta     CE+1
        rts
.endproc

; BM and CE kept while the general write (nib) uses them
.proc guarda_punteros
        lda     BM
        sta     g_bm
        lda     BM+1
        sta     g_bm+1
        lda     CE
        sta     g_ce
        lda     CE+1
        sta     g_ce+1
        jmp     fila_banda
.endproc

.proc repon_punteros
        lda     g_bm
        sta     BM
        lda     g_bm+1
        sta     BM+1
        lda     g_ce
        sta     CE
        lda     g_ce+1
        sta     CE+1
        rts
.endproc

; the strip's F0 on the 4 lines of e_y through the general write
.proc f_nib
        jsr     guarda_punteros
        lda     e_b0
        sta     e_xb
        lda     #F0
        jsr     nib
        jmp     repon_punteros
.endproc

; the band's edge and 00 through the general write
.proc b_nib
        jsr     guarda_punteros
        lda     e_e
        sta     e_xb
        lsr     a
        bcs     :+
        lda     #CANTO0
        jsr     nib
        jmp     repon_punteros
:       lda     #CANTO
        jsr     nib
        inc     e_xb
        lda     #CERO
        jsr     nib
        jmp     repon_punteros
.endproc

; BM = the band's first line in cell column Y
.proc puntero
        lda     c8_lo,y
        clc
        adc     e_bm
        sta     BM
        lda     c8_hi,y
        adc     e_bm+1
        sta     BM+1
        rts
.endproc

; the last band's run: F0 at e_n bytes from e_xb, a whole bitmap byte for two of them in one cell
.proc corrida
run:    lda     e_xb
        lsr     a
        bcs     solo
        ldx     e_n
        cpx     #2
        bcc     solo
        clc
        adc     #4
        tay
        lda     (CE),y
        and     #$0F
        cmp     rosa
        bne     lento
        lda     rojo_fg
        sta     (CE),y
        jsr     puntero
        ldy     #0
        lda     #$FF
        sta     (BM),y
        iny
        sta     (BM),y
        iny
        sta     (BM),y
        iny
        sta     (BM),y
        jmp     dos
lento:  lda     #F0F0
        jsr     nib
dos:    inc     e_xb
        inc     e_xb
        dec     e_n
        dec     e_n
        bne     run
        rts
solo:   lda     #F0
        jsr     nib
        inc     e_xb
        dec     e_n
        bne     run
        rts
.endproc

; A = a kind (even): written at column e_xb on the band's 4 lines (the general write: the corner's writes take it in
; a cell whose background is not pink, through pixel.s's full path, and for a lone F0 of the last band's run)
.proc nib
        sta     n_ent
        lda     e_xb
        lsr     a
        php                             ; C: the low nibble
        clc
        adc     #4
        tay                             ; Y = the cell column
        plp
        lda     n_ent
        adc     #0
        asl     a
        asl     a
        asl     a
        asl     a
        tax                             ; X = the entry
        lda     (CE),y
        and     #$0F
        cmp     rosa
        beq     :+
        jmp     lento
:       lda     tabla+5,x               ; pen 1: the cell's foreground red
        beq     :+
        lda     rojo_fg
        sta     (CE),y
:       jsr     puntero
        ldy     #0
        lda     (BM),y
        and     tabla+4,x
        ora     tabla+0,x
        sta     (BM),y
        iny
        lda     (BM),y
        and     tabla+4,x
        ora     tabla+1,x
        sta     (BM),y
        iny
        lda     (BM),y
        and     tabla+4,x
        ora     tabla+2,x
        sta     (BM),y
        iny
        lda     (BM),y
        and     tabla+4,x
        ora     tabla+3,x
        sta     (BM),y
        rts

lento:  stx     n_ent                   ; pixel.s's full path, byte by byte (its capitals too)
        ldy     #0
ll:     sty     n_l
        tya
        clc
        adc     e_y
        sta     _pb_y
        lda     e_xb
        sta     _pb_x
        tya
        clc
        adc     n_ent
        tax
        lda     tabla+8,x
        sta     _pb_v
        jsr     _pon_byte_rapido
        ldx     n_ent
        lda     tabla+6,x
        beq     :+
        lda     n_l
        clc
        adc     e_y
        sta     _pb_y
        ldx     e_xb
        inx
        stx     _pb_x
        lda     n_l
        clc
        adc     n_ent
        tax
        lda     tabla+12,x
        sta     _pb_v
        jsr     _pon_byte_rapido
:       ldy     n_l
        iny
        cpy     #4
        bne     ll
        rts
.endproc

; A = the capitals on line _pb_y (bit i: capital i, _perg_fila_cap), _pb_x a window byte column just written: the
; capitals whose sprite it covers lose those pixels (the 4 pixels at screen x 4 xb + 32, the capital's left pixel
; at its window x + 32)
.proc borra_cap
        sta     bc_bits
        ldx     #0
bucle:  lsr     bc_bits
        bcc     sig
        lda     _pb_x
        cmp     _cap_xb_lo,x
        bcc     sig
        cmp     _cap_xb_hi,x
        beq     :+
        bcs     sig
:       asl     a                       ; dx + 6 = 4 xb - window x + 6 (0 .. 29 in this range)
        asl     a
        sec
        sbc     _cap_wx,x
        clc
        adc     #6
        sta     bc_idx
        lda     _pb_y                   ; the sprite row: line - the capital's line (0-20)
        sec
        sbc     _cap_wy,x
        tay
        lda     por3,y
        clc
        adc     spr_lo,x
        sta     SPR
        lda     spr_hi,x
        sta     SPR+1
        stx     bc_i
        ldx     bc_idx
        ldy     #0
        lda     (SPR),y
        and     bc_m0,x
        sta     (SPR),y
        iny
        lda     (SPR),y
        and     bc_m1,x
        sta     (SPR),y
        iny
        lda     (SPR),y
        and     bc_m2,x
        sta     (SPR),y
        ldx     bc_i
sig:    inx
        lda     bc_bits
        bne     bucle
        rts
.endproc
