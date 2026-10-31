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


; abadia64ks, 6502 code of the game: the C128's hires heads (milestone H10, assembled only with -D C128;
; the disk version, the one for 128 KiB, has ALL the heads in hires, every one).  The
; design of H7 (c64/SPRITES_HW.md, cabezas.s of the 64 KiB line, kept in
; the backups) for every head: the black strokes of the head (lines 0-9: the frames of Guillermo and Adso,
; the monks' faces, the reflections in the mirror) as a hires hardware sprite at the PC's full horizontal
; resolution, over the multicolour bitmap that keeps the fills (c64_graficos.py --c128: those lines by the rule
; cuerpo, no black of their own).
;
; Heads h = 0-5: the sprite records 0-5 (Guillermo, Adso, the monks, the reflections), hardware sprite h: slot
; G_CAB_SLOTS + 64 h (lines 0-9 = 30 bytes, the rest zero), pointer $C3F8 + h, black, hires, in front of the
; bitmap; X = 24 + 4 x, Y = y + 10 for the record's x (CPC bytes) and y (lines).  A record is a head when its graphic
; (+7) is one of Guillermo's or Adso's 12 animation frames, a monk's face (+0Bh bit 7 clear, the face's 30 bytes in
; G_CARAS), or a mirror buffer whose frame this file noted (cab_espejo, from iso_mirror_draw_callback).
;
; The black (G_CABEZAS_NEGRO: 26 heads x 10 lines x 3 bytes, unflipped as on the tape) is mirrored when the head is
; drawn, by a parity this file keeps exactly as the game flips its graphics in place: Guillermo's and Adso's frames
; (personajes_flip2: cab_gira_pers), each face block (personajes_flip_monk, spr_unflip_monk_faces: cab_gira_cara);
; a reflection is its frame mirrored once more (cab_espejo).
;
; Occlusion and the raster window as H7: the head's own rectangle only; right after its merge (cab_despues) the
; rectangle's bytes under its 10 lines kept as a snapshot in the unused half of the rectangle's allocation; at the
; rectangle's end (cab_fin_rect, after the tiles in front) every pair that changed (or that a tile drawn meanwhile
; covers: cab_marca, cab_marca_op from la_baldosa) hides the sprite's two pixels: pend[h] = black AND NOT changed.  At
; step 5 (cab_paso5) one raster window for every head rebuilt or gone: the beam is waited for (haz_espera) until it
; cannot reach their rows; then the first 3 cell rows of each head's rectangle are blitted, pend[h] copied into the
; slot and the VIC-II's registers set, so that the bitmap's head and its black change in the same displayed frame.
; The sprites go off when the play area is filled and at the spiral wipe (cab_apaga).  No zero page of its own:
; self-modified absolute addresses (the game's zero page is full).
;
; The dark rooms (the library with the lamp; with the lamp in the labyrinth the heads were not shown in
; hires): there the game composes one rectangle a frame, the light's (its record's graphic 0000:
; la_tramo's la_luz), with Guillermo, Adso and any monk in it merged before the light's mask, and never their own
; rectangles; so a head merged into the light's rectangle is registered too (cab_q, cab_despues: up to NLUZ of them,
; each one's state kept), compared at the rectangle's end like the own one (cab_fin_rect: luz_fin), and its window
; blits its 3 cell rows of the light's rectangle, not of its own one, stale there (cab_paso5: filas, mide, todas); a
; head shown through the light and not merged into it in a pass (out of the light) goes off in that pass's window.

.ifdef C128
        .include "logica_a.inc"         ; (zp.inc, mapa.inc, la_*)
        .include "io500.inc"            ; VIC_STA, VIC_LDA: the VIC-II's registers (the P500's in bank 15)
        .import spr_blit_to_screen, haz_espera, la_f4w, la_yl, la_dp
        .export cab_inicio, cab_apaga, cab_despues, cab_fin_rect, cab_paso5, cab_q, cab_marca, cab_marca_op
        .export cab_gira_pers, cab_gira_cara, cab_espejo
        .export cz_h, pend, neg, creg, cvis, par_g, par_a, par_c, refl_f, cz_lo, cz_hi, cz_d, cz_s   ; (par_c: also
                                        ; logica_b.s, abadia128ks's orientation quirk; the rest for the tests)
        .import la_bsrc, la_bta                 ; (la_baldosa's tile pointer and AND table operands)

NCAB    = 6
SLOTS   = G_CAB_SLOTS
REG0    = D64_SPR_TABLE
FILAS   = 3                             ; the cell rows of a head's own rectangle blitted in the window
LINEAS  = 10                            ; a head: lines 0-9
        .assert <SLOTS & $3F = 0 && SLOTS >= $C000 && SLOTS + NCAB * 64 <= $D000, error, "cabezas128: the slots"

; the 12 frames' C64 addresses (personajes, row-major, ceil(w / 2) bytes a line: c64/NOTAS_GRAFICOS.md)
.define CAB_M(adr) G_PERSONAJES + (adr - $A300) / 5 * 3
.define CAB_M4(adr) G_PERSONAJES + 174 * 3 + (adr - $A666) / 4 * 2
.define CAB_A(adr) G_PERSONAJES + 174 * 3 + 33 * 2 + (adr - $A6EA) / 5 * 3
.define CAB_A4(adr) G_PERSONAJES + 174 * 3 + 33 * 2 + 95 * 3 + (adr - $A8C5) / 4 * 2

.segment "RODATA"
frm_lo: .lobytes CAB_M($A300), CAB_M($A3B4), CAB_M($A45E), CAB_M($A508), CAB_M($A5B7), CAB_M4($A666)
        .lobytes CAB_A($A6EA), CAB_A($A78A), CAB_A($A82A), CAB_A4($A8C5), CAB_A4($A93D), CAB_A4($A9B5)
frm_hi: .hibytes CAB_M($A300), CAB_M($A3B4), CAB_M($A45E), CAB_M($A508), CAB_M($A5B7), CAB_M4($A666)
        .hibytes CAB_A($A6EA), CAB_A($A78A), CAB_A($A82A), CAB_A4($A8C5), CAB_A4($A93D), CAB_A4($A9B5)
frm_w:  .byte   5, 5, 5, 5, 5, 4, 5, 5, 5, 4, 4, 4
reg_lo: .repeat NCAB, k
        .byte   <(REG0 + $14 * k)
        .endrep
reg_hi: .repeat NCAB, k
        .byte   >(REG0 + $14 * k)
        .endrep
cbit:   .byte   1, 2, 4, 8, 16, 32
neg_lo: .repeat 26, k                   ; the 26 blacks (12 frames, 14 faces)
        .byte   <(G_CABEZAS_NEGRO + 30 * k)
        .endrep
neg_hi: .repeat 26, k
        .byte   >(G_CABEZAS_NEGRO + 30 * k)
        .endrep

.segment "BSS"
par_g:  .res    1                       ; Guillermo's frames mirrored (as the tape: 0)
par_a:  .res    1                       ; Adso's
par_c:  .res    7                       ; each face block
refl_f: .res    NCAB                    ; a record drawn from a mirror buffer: its frame (FFh: none), mirrored
refl_m: .res    NCAB
cvis:   .res    1                       ; the heads shown (bits)
creg:   .res    1                       ; the heads rebuilt in this pass (bits)
cz_h:   .res    1                       ; the head registered in the rectangle being composed (FFh: none)
cz_s:   .res    1
cnx:    .res    NCAB                    ; their x, y (the records')
cny:    .res    NCAB
cz_lp:  .res    2                       ; la_mezcla's own record: its first line's cell, line, odd start
cz_yl:  .res    1
cz_odd: .res    1
cz_dl:  .res    2                       ; the snapshot's offset (the rectangle's C64 size)
cz_rl:  .res    1                       ; la_capas's rows of the head's cells: [rl, rh)
cz_rh:  .res    1
cz_lo:  .res    1
cz_hi:  .res    1
cz_d:   .res    1
cz_w:   .res    1                       ; the head's width (CPC bytes: 5 or 4)
cz_u:   .res    1
cz_v:   .res    1
cz_m:   .res    1
cz_n:   .res    1
cz_x:   .res    1                       ; (cab_paso5: the head of its own window)
cz_y:   .res    1
cz_k:   .res    1
neg:    .res    30                      ; the head being registered: its black, mirrored if it must be
pend:   .res    30 * NCAB               ; the heads' images built in this pass
rev:    .res    256                     ; a byte's bits reversed (cab_inicio)
cfk:    .res    6                       ; a record's +0Ch..+11h for spr_blit_to_screen (zix = cfk - 12)
NLUZ    = 3                             ; the heads registered in a light's rectangle (a dark room)
luz_n:  .res    1                       ; how many in the rectangle being composed
lz_h:   .res    NLUZ                    ; each one's head, la_mezcla's first line (cz_lp, cz_yl, cz_odd), black (cz_n),
lz_lpl: .res    NLUZ                    ; mirror (cz_m) and width (cz_w), for cab_fin_rect
lz_lph: .res    NLUZ
lz_yl:  .res    NLUZ
lz_odd: .res    NLUZ
lz_n:   .res    NLUZ
lz_m:   .res    NLUZ
lz_w:   .res    NLUZ
lz_rl:  .res    1                       ; their cell rows together, for cab_marca: [rl, rh)
lz_rh:  .res    1
lz_i:   .res    1
cz_nn:  .res    1                       ; the black's index (construye's mirror uses cz_n)
en_luz: .res    1                       ; cab_despues: a head merged into the light's rectangle
luz_aho: .res   1                       ; the light's heads registered now (bits)
luzvis: .res    1                       ; the heads shown through the light (bits)
luzpas: .res    1                       ; the light's heads of this pass, rebuilt or gone: their window is the light's
luzgo:  .res    1                       ; the light's heads gone in this pass (off in cab_paso5's window)
luzgeo: .res    6                       ; the light's record's +0Ch..+11h (x, y, w, h, buffer) as composed
luzf4w: .res    2                       ; its row of cells (la_f4w, C64 bytes)
cz_lz:  .res    1                       ; (cab_paso5)

.segment "CODE"

; ---- cab_inicio (principal, after plat_inicio; the I/O visible) ------------------------------------------------
.proc cab_inicio
        ldx     #0                      ; rev[b]
:       txa
        ldy     #8
        sta     cz_u
        lda     #0
@b:     lsr     cz_u
        rol     a
        dey
        bne     @b
        sta     rev,x
        inx
        bne     :-
        ldx     #NCAB - 1
:       txa
        clc
        adc     #(SLOTS - $C000) / 64
        sta     $C3F8,x
        lda     #0
        VIC_STA $27, x                  ; black
        sta     par_c,x                 ; (and par_c[0-5], refl_m)
        sta     refl_m,x
        lda     #$FF
        sta     refl_f,x
        dex
        bpl     :-
        lda     #0
        sta     par_c + 6
        sta     par_g
        sta     par_a
        VIC_STA $15
        VIC_STA $10
        VIC_STA $17
        VIC_STA $1B                     ; in front of the bitmap
        VIC_STA $1C                     ; hires
        VIC_STA $1D
        sta     cvis
        sta     creg
        sta     luz_n
        sta     luzvis
        sta     luzpas
        sta     luzgo
        tax
:       sta     SLOTS,x
        sta     SLOTS + NCAB * 64 - 256,x
        inx
        bne     :-
        dex
        stx     cz_h
        rts
.endproc

; ---- cab_apaga (vid_fill_play_area, the spiral): every head sprite off.  A, X, Y kept ----------------------------
.proc cab_apaga
        pha
        lda     MEMCFG
        pha
        lda     #MEM_IO
        sta     MEMCFG
        lda     #0
        VIC_STA $15
        sta     cvis
        sta     creg
        sta     luz_n
        sta     luzvis
        sta     luzpas
        sta     luzgo
        lda     #$FF
        sta     cz_h
        pla
        sta     MEMCFG
        pla
        rts
.endproc

; ---- the flips: cab_gira_pers (personajes_flip2: X = 0 Guillermo, 8 Adso), cab_gira_cara (X = a monk slot x 2:
; the face block D64_SPR_MONK_FACES[X] is flipped).  A, X, Y kept ---------------------------------------------------
.proc cab_gira_pers
        pha
        cpx     #8
        bcs     :+
        lda     par_g
        eor     #1
        sta     par_g
        pla
        rts
:       lda     par_a
        eor     #1
        sta     par_a
        pla
        rts
.endproc

.proc cab_gira_cara
        pha
        tya
        pha
        lda     D64_SPR_MONK_FACES,x    ; the block: (pointer - G_CARAS) / 60 (16 bits: two pages)
        sec
        sbc     #<G_CARAS
        sta     cz_u
        lda     D64_SPR_MONK_FACES+1,x
        sbc     #>G_CARAS
        bcc     fin                     ; (not a face: nothing)
        beq     :+
        cmp     #1
        bne     fin
        lda     cz_u                    ; o = 256 + u (blocks 5, 6 start at 300, 360): counted from 240 (block 4)
        cmp     #<(420 - 256)
        bcs     fin
        adc     #256 - 240              ; (C = 0)
        ldy     #4
        bne     @div                    ; (always)
:       lda     cz_u
        ldy     #0
@div:
:       cmp     #60
        bcc     :+
        sbc     #60
        iny
        bne     :-
:       cpy     #7
        bcs     fin
        lda     par_c,y
        eor     #1
        sta     par_c,y
fin:    pla
        tay
        pla
        rts
.endproc
        .assert <(G_CARAS + 420) >= <G_CARAS || >(G_CARAS + 420) = >G_CARAS + 1, error, "cabezas128: the faces in two pages"

.ifdef VELOZ
; neg_b1_copia (abadia128ks, room for the speed work: using the C128's extra memory): the 30 bytes
; of a black from block 1 (X/Y: its address) to negbuf; in the common RAM, as plataforma/c128.s's far_lee: block 1
; mapped while it copies (an interrupt keeps MEMCFG: plat_irq), then the caller's configuration.  A, X, Y clobbered.
.segment "COMUN"
neg_b1_copia:
.ifdef P500
        stx     P5_PIO                  ; the P500: LDA (zp),Y with $01 = 1 (the 6509's LDA abs,Y reads bank 0)
        sty     P5_PIO+1
        inc     P5_IND
        ldy     #29
:       lda     (P5_PIO),y
        sta     negbuf,y
        dey
        bpl     :-
        dec     P5_IND
        rts
.else
        stx     @s+1
        sty     @s+2
        lda     MEMCFG
        pha
        lda     #MEM_B1
        sta     MEMCFG
        ldy     #29
@s:     lda     $FFFF,y
        sta     negbuf,y
        dey
        bpl     @s
        pla
        sta     MEMCFG
        rts
.endif
negbuf: .res    30
.segment "CODE"
.endif

; ---- cab_espejo (iso_mirror_draw_callback, before its copy: zix = the record, its +7 the frame copied): the frame
; noted for the record, and its parity mirrored once more (the copy is flipped).  A, X, Y kept ---------------------------
.proc cab_espejo
        pha
        txa
        pha
        tya
        pha
        jsr     registro                ; X = the record's head index, or C = 1
        bcs     fin
        ldy     #7
        lda     (zix),y
        sta     cz_u
        iny
        lda     (zix),y
        sta     cz_v
        jsr     marco                   ; Y = the frame, or C = 1
        bcs     no
        tya
        sta     refl_f,x
        jsr     paridad_marco           ; A = its parity
        eor     #1
        sta     refl_m,x
        bcc     fin                     ; (always)
no:     lda     #$FF
        sta     refl_f,x
fin:    pla
        tay
        pla
        tax
        pla
        rts
.endproc

; X = the head index of the record at zix (0 to NCAB - 1), C = 0; or C = 1
.proc registro
        ldx     #NCAB - 1
:       lda     zix
        cmp     reg_lo,x
        bne     :+
        lda     zix+1
        cmp     reg_hi,x
        beq     si
:       dex
        bpl     :--
        sec
        rts
si:     clc
        rts
.endproc

; X = the head index of the record at ziy (0 to NCAB - 1), C = 0; or C = 1
.proc registro_y
        ldx     #NCAB - 1
:       lda     ziy
        cmp     reg_lo,x
        bne     :+
        lda     ziy+1
        cmp     reg_hi,x
        beq     si
:       dex
        bpl     :--
        sec
        rts
si:     clc
        rts
.endproc

; the rectangle being composed the light's (its own record's graphic, +7, 0000: la_tramo's la_luz)?  C = 0: yes.  X kept
.proc es_luz
        ldy     #7
        lda     (zix),y
        iny
        ora     (zix),y
        bne     no
        clc
        rts
no:     sec
        rts
.endproc

; the graphic cz_u / cz_v one of the 12 frames?  C = 0: Y = it; else C = 1.  X kept
.proc marco
        ldy     #11
:       lda     cz_u
        cmp     frm_lo,y
        bne     :+
        lda     cz_v
        cmp     frm_hi,y
        beq     si
:       dey
        bpl     :--
        sec
        rts
si:     clc
        rts
.endproc

; A = the parity of frame Y (0-5 Guillermo's, 6-11 Adso's); C = 0.  X, Y kept
.proc paridad_marco
        lda     par_g
        cpy     #6
        bcc     :+
        lda     par_a
:       clc
        rts
.endproc

; ---- cab_q (la_mezcla, its destination set): for the rectangle's own record only, where its first line goes ------
.proc cab_q
        lda     ziy
        cmp     zix
        bne     otro
        lda     ziy+1
        cmp     zix+1
        beq     si
otro:   jsr     es_luz                  ; the light's rectangle: every record merged into it (a head is registered)
        bcs     no
si:     lda     la_dp
        lsr
        ror     cz_odd
        lda     la_q
        sta     cz_lp
        lda     la_q+1
        sta     cz_lp+1
        lda     la_yl
        sta     cz_yl
no:     rts
.endproc

; ---- cab_despues (encima, after la_mezcla of ziy into the rectangle of zix): in the record's own rectangle, a head:
; registered (cz_h, cnx, cny, neg: its black as it is drawn) and the rectangle under its 10 lines kept (snapshot) ----
.proc cab_despues
        lda     ziy
        cmp     zix
        bne     otro
        lda     ziy+1
        cmp     zix+1
        bne     otro
        lda     #0
        sta     en_luz
        jsr     registro
        bcc     :+
fuera:  rts
otro:   jsr     es_luz                  ; a head merged into the light's rectangle (a dark room)
        bcs     fuera
        lda     luz_n
        cmp     #NLUZ
        bcs     fuera
        jsr     registro_y
        bcs     fuera
        lda     #1
        sta     en_luz
:       stx     cz_k
        ldy     #7                      ; the graphic
        lda     (ziy),y
        sta     cz_u
        iny
        lda     (ziy),y
        sta     cz_v
        jsr     marco
        bcs     cara
        lda     frm_w,y                 ; a frame
        sta     cz_w
        jsr     paridad_marco
        jmp     negro
cara:   ldy     #$0B                    ; a monk's face?
        lda     (ziy),y
        bmi     espejo
        lda     cz_u                    ; the offset o in G_CARAS (16 bits: the 420 bytes span two pages)
        sec
        sbc     #<G_CARAS
        sta     cz_m
        lda     cz_v
        sbc     #>G_CARAS
        bcc     espejo                  ; (below G_CARAS)
        beq     bajo
        cmp     #1
        bne     espejo
        lda     cz_m                    ; o = 256 + m: a face while o < 420 (m < 164); counted from 240 (face 8)
        cmp     #<(420 - 256)
        bcs     espejo
        adc     #256 - 240              ; (C = 0)
        ldy     #8
        bne     :+                      ; (always)
bajo:   lda     cz_m
        ldy     #0                      ; its index: / 30 (and its block: / 60)
:       cmp     #30
        bcc     :+
        sbc     #30
        iny
        bne     :-
:       cmp     #0
        beq     :+
        jmp     no                      ; (not a face's first line)
:       tya
        lsr
        tax
        lda     par_c,x
        pha
        tya
        clc
        adc     #12
        tay
        lda     #5
        sta     cz_w
        pla
        ldx     cz_k
        jmp     negro
espejo: ldx     cz_k                    ; a reflection: its graphic one of the mirror buffers, its frame noted
        lda     cz_u
        cmp     #<D64_ISO_MIRROR_BUF_GUILLERMO
        bne     :+
        lda     cz_v
        cmp     #>D64_ISO_MIRROR_BUF_GUILLERMO
        beq     refleja
:       lda     cz_u
        cmp     #<D64_ISO_MIRROR_BUF_ADSO
        bne     no
        lda     cz_v
        cmp     #>D64_ISO_MIRROR_BUF_ADSO
        bne     no
refleja:
        ldy     refl_f,x
        bmi     no
        lda     frm_w,y
        sta     cz_w
        lda     refl_m,x
negro:  ; Y = the black (0-25), A = mirrored (bit 0), cz_w its width; X = cz_k
        sta     cz_m
        sty     cz_n                    ; (the black's index)
        sty     cz_nn
        ldx     cz_k
        ldy     #2                      ; its first line: from 191 on (the score bar) no sprite
        lda     (ziy),y
        cmp     #191
        bcs     no
        sta     cny,x
        dey
        lda     (ziy),y
        sta     cnx,x
        stx     cz_h
        ldy     cz_n
        jsr     construye               ; neg := the black of Y as drawn
        jsr     marca_ini               ; the rows la_baldosa marks from now on
        lda     cz_lp                   ; la_mezcla's first line: its cell + its line
        clc
        adc     cz_yl
        sta     cz_lp
        bcc     :+
        inc     cz_lp+1
:       lda     en_luz
        beq     :+
        jsr     luz_guarda              ; the light's rectangle: this head's state kept for cab_fin_rect
:       clc                             ; the snapshot
        jmp     recorre
no:     rts
.endproc

; a head of the light's rectangle: its state to the next slot; the slots' cell rows together in cz_rl, cz_rh
.proc luz_guarda
        ldx     luz_n
        lda     cz_h
        sta     lz_h,x
        lda     cz_lp
        sta     lz_lpl,x
        lda     cz_lp+1
        sta     lz_lph,x
        lda     cz_yl
        sta     lz_yl,x
        lda     cz_odd
        sta     lz_odd,x
        lda     cz_nn
        sta     lz_n,x
        lda     cz_m
        sta     lz_m,x
        lda     cz_w
        sta     lz_w,x
        txa
        bne     union
        lda     cz_rl
        sta     lz_rl
        lda     cz_rh
        sta     lz_rh
        jmp     fin
union:  lda     cz_rl
        cmp     lz_rl
        bcs     :+
        sta     lz_rl
:       lda     cz_rh
        cmp     lz_rh
        bcc     fin
        sta     lz_rh
fin:    lda     lz_rl
        sta     cz_rl
        lda     lz_rh
        sta     cz_rh
        inc     luz_n
        rts
.endproc

; neg := the black Y (G_CABEZAS_NEGRO), mirrored inside its width (cz_w CPC bytes = 4 cz_w pixels) when cz_m bit 0
.proc construye
.ifdef VELOZ
        ldx     neg_lo,y                ; the black in block 1 (mapa64.py BANCO1): its 30 bytes to negbuf, common RAM
        lda     neg_hi,y
        tay
        jsr     neg_b1_copia
        lda     #<negbuf
        sta     src+1
        lda     #>negbuf
        sta     src+2
.else
        lda     neg_lo,y
        sta     src+1
        lda     neg_hi,y
        sta     src+2
.endif
        ldx     #0
lin:    lda     cz_m
        lsr
        bcs     espejo
        ldy     #2
:
src:    lda     $FFFF,x
        sta     neg,x
        inx
        dey
        bpl     :-
        bmi     sig                     ; (always)
espejo: lda     cz_w                    ; 20 pixels: rev of the 24 bits, 4 left; 16: rev of the first 16
        cmp     #5
        bne     dieciseis
        jsr     lee3                    ; cz_u, cz_v, cz_n = rev(b2), rev(b1), rev(b0)
        lda     cz_u
        asl
        asl
        asl
        asl
        sta     cz_y
        lda     cz_v
        lsr
        lsr
        lsr
        lsr
        ora     cz_y
        sta     neg,x
        lda     cz_v
        asl
        asl
        asl
        asl
        sta     cz_y
        lda     cz_n
        lsr
        lsr
        lsr
        lsr
        ora     cz_y
        sta     neg+1,x
        lda     cz_n
        asl
        asl
        asl
        asl
        sta     neg+2,x
        jmp     tres
dieciseis:
        jsr     lee3
        lda     cz_v
        sta     neg,x
        lda     cz_n
        sta     neg+1,x
        lda     #0
        sta     neg+2,x
tres:   inx
        inx
        inx
sig:    cpx     #30
        bne     lin
        rts
; cz_u = rev(b2), cz_v = rev(b1), cz_n = rev(b0) of the line at X
lee3:   lda     src+1
        sta     l0+1
        clc
        adc     #1
        sta     l1+1
        lda     src+2
        sta     l0+2
        adc     #0
        sta     l1+2
        lda     l1+1
        clc
        adc     #1
        sta     l2+1
        lda     l1+2
        adc     #0
        sta     l2+2
l2:     lda     $FFFF,x
        tay
        lda     rev,y
        sta     cz_u
l1:     lda     $FFFF,x
        tay
        lda     rev,y
        sta     cz_v
l0:     lda     $FFFF,x
        tay
        lda     rev,y
        sta     cz_n
        rts
.endproc

; the snapshot's offset cz_dl = the rectangle's C64 size (the CPC's w h bytes allocated, half used); the rows of
; la_capas's counter (la_t: rows left, h / 8 down to 1) of the head's cells [y >> 3, (y + 9) >> 3]
.proc marca_ini
        lda     D64_SPR_BUF_FREE
        sec
        sbc     D64_SPR_CUR_BUFFER
        sta     cz_dl
        lda     D64_SPR_BUF_FREE+1
        sbc     D64_SPR_CUR_BUFFER+1
        lsr
        sta     cz_dl+1
        ror     cz_dl
        lda     LA_RECT_SIZE+1          ; rows (h / 8)
        lsr
        lsr
        lsr
        tay
        lda     D64_SPR_OV_DST_Y        ; rh = rows - (y >> 3) + 1, rl = rows - ((y + 9) >> 3)
        lsr
        lsr
        lsr
        sta     cz_u
        tya
        sec
        sbc     cz_u
        sta     cz_rh
        inc     cz_rh
        lda     D64_SPR_OV_DST_Y
        clc
        adc     #9
        lsr
        lsr
        lsr
        sta     cz_u
        tya
        sec
        sbc     cz_u
        sta     cz_rl
        rts
.endproc

; ---- recorre: the head's 10 lines in the rectangle (4 bytes a line from its first byte: +0, +8, +16, +24) and their
; copy (+ cz_dl): C = 0 the copy made (the snapshot); C = 1 the differences: pend[cz_h] = neg AND NOT the pairs that
; changed (a byte, or the low nibble of one and the high of the next when the head starts at an odd CPC byte) ---------
.proc recorre
        ror     cz_m                    ; bit 7: compare
        lda     cz_lp
        sta     cz_ptr
        lda     cz_lp+1
        sta     cz_ptr+1
        lda     cz_yl
        sta     cz_y
        lda     cz_h                    ; pend[h] = pend + 30 h
        asl
        sta     cz_u
        asl
        asl
        asl
        asl
        sec
        sbc     cz_u
        clc
        adc     #<pend
        sta     dst+1
        lda     #0
        adc     #>pend
        sta     dst+2
        ldx     #0                      ; X: the black's byte (0-29)
lin:    ldy     #3                      ; the line's 4 bytes (+24, +16, +8, +0) and their copy's
:       lda     cz_ptr
        clc
        adc     desp,y
        sta     rd+1
        lda     cz_ptr+1
        adc     #0
        sta     rd+2
        lda     rd+1
        clc
        adc     cz_dl
        sta     cp+1
        sta     cr+1
        lda     rd+2
        adc     cz_dl+1
        sta     cp+2
        sta     cr+2
rd:     lda     $FFFF
        bit     cz_m
        bmi     :+
cp:     sta     $FFFF                   ; the snapshot
        jmp     :++
:
cr:     eor     $FFFF                   ; the difference
        sta     dd,y
:       dey
        bpl     :---
        bit     cz_m
        bpl     sig3
        ldy     #0                      ; the 3 black bytes: the pairs that changed under each
:       lda     dd,y
        bit     cz_odd
        bpl     :+
        asl
        asl
        asl
        asl
        sta     cz_u
        lda     dd+1,y
        lsr
        lsr
        lsr
        lsr
        ora     cz_u
:       sta     cz_u                    ; both bits of a changed pair
        lsr
        ora     cz_u
        and     #$55
        sta     cz_u
        asl
        ora     cz_u
        eor     #$FF
        and     neg,x
dst:    sta     $FFFF,x
        inx
        iny
        cpy     #3
        bne     :--
        beq     sig                     ; (always)
sig3:   inx
        inx
        inx
sig:    inc     cz_y                    ; the next line: past line 7 of a cell, 4w - 8 more
        lda     cz_y
        and     #7
        bne     :+
        lda     cz_ptr
        clc
        adc     la_f4w
        sta     cz_ptr
        lda     cz_ptr+1
        adc     la_f4w+1
        sta     cz_ptr+1
        lda     cz_ptr
        sec
        sbc     #8
        sta     cz_ptr
        bcs     :+
        dec     cz_ptr+1
:       inc     cz_ptr
        bne     :+
        inc     cz_ptr+1
:       cpx     #30
        beq     fin
        jmp     lin
fin:    rts
.endproc

.segment "RODATA"
desp:   .byte   0, 8, 16, 24
.segment "BSS"
dd:     .res    4
cz_ptr: .res    2
.segment "CODE"

; ---- cab_fin_rect (encima, the rectangle composed: after the tiles in front): the registered head's image --------
.proc cab_fin_rect
        jsr     es_luz                  ; the light's rectangle: its heads (luz_fin)
        bcc     luz
        ldx     cz_h
        bmi     fin
        lda     cbit,x
        ora     creg
        sta     creg
        sec
        jsr     recorre
        lda     #$FF
        sta     cz_h
fin:    rts
luz:    jmp     luz_fin
.endproc

; the light's rectangle composed: each head registered in it compared as the own one (pend[h] = its black AND NOT the
; pairs drawn over it: the light's mask, a tile in front, another figure), rebuilt; those shown through the light
; before and not merged now gone; the light's geometry and row of cells kept for cab_paso5
.proc luz_fin
        lda     #0
        sta     luz_aho
        ldx     #0
        cpx     luz_n
        beq     visto
bucle:  stx     lz_i
        lda     lz_h,x
        sta     cz_h
        lda     lz_lpl,x
        sta     cz_lp
        lda     lz_lph,x
        sta     cz_lp+1
        lda     lz_yl,x
        sta     cz_yl
        lda     lz_odd,x
        sta     cz_odd
        lda     lz_w,x
        sta     cz_w
        lda     lz_m,x
        sta     cz_m
        ldy     lz_n,x
        jsr     construye               ; neg := its black as drawn
        ldx     cz_h
        lda     cbit,x
        ora     creg
        sta     creg
        lda     cbit,x
        ora     luz_aho
        sta     luz_aho
        sec
        jsr     recorre
        ldx     lz_i
        inx
        cpx     luz_n
        bne     bucle
visto:  lda     luz_aho                 ; gone: shown through the light, not merged now
        eor     #$FF
        and     luzvis
        ora     luzgo
        sta     luzgo
        lda     luz_aho
        sta     luzvis
        ora     luzgo
        ora     luzpas
        sta     luzpas
        ldy     #$0C                    ; the light's x, y, w, h, buffer
        ldx     #0
:       lda     (zix),y
        sta     luzgeo,x
        iny
        inx
        cpx     #6
        bne     :-
        lda     la_f4w
        sta     luzf4w
        lda     la_f4w+1
        sta     luzf4w+1
        lda     #0
        sta     luz_n
        lda     #$FF
        sta     cz_h
        rts
.endproc

; ---- cab_marca / cab_marca_op (la_baldosa, a tile just merged at (zp0+2), 16 bytes, while a head is registered): when
; the tile lies in the head's cell rows (la_capas's counter la_t in [cz_rl, cz_rh)), the pairs it draws opaque are
; poisoned in the snapshot (s := NOT d there), so that the comparison sees them covered even when the tile wrote the
; very value the head had.  cab_marca: a transparent tile (its pairs opaque where its AND table, la_baldosa's ta, is
; 00); cab_marca_op: an opaque tile (01h-0Ah), all of it.  A, X, Y clobbered (la_baldosa returns) --------------------
.proc cab_marca
        jsr     fila
        bcs     fin
        lda     la_bsrc+1               ; la_baldosa's tile and its AND table
        sta     src+1
        lda     la_bsrc+2
        sta     src+2
        lda     la_bta+2
        sta     ta+2
        ldy     #15
:
src:    ldx     $FFFF,y
ta:     lda     $FF00,x                 ; its AND mask (11 transparent)
        sta     cz_u
        lda     (zp0+2),y
        eor     #$FF
        jsr     snap                    ; A = s, cz_v = NOT d
        eor     cz_v                    ; s XOR (NOT d)
        and     cz_u                    ; where transparent: keep s
        eor     cz_v                    ; opaque: NOT d; transparent: s
        jsr     snap_pon
        dey
        bpl     :-
fin:    rts
.endproc

.proc cab_marca_op
        jsr     fila
        bcs     fin
        ldy     #15
:       lda     (zp0+2),y
        eor     #$FF
        sta     cz_v
        jsr     snap_pon
        dey
        bpl     :-
fin:    rts
.endproc

; the tile's row in the head's? C = 0: the snapshot's address of its 16 bytes set (sn = (zp0+2) + cz_dl)
.proc fila
        lda     la_t
        cmp     cz_rl
        bcc     no
        cmp     cz_rh
        bcs     no
        lda     zp0+2
        clc
        adc     cz_dl
        sta     snap_rd+1
        sta     snap_wr+1
        lda     zp0+3
        adc     cz_dl+1
        sta     snap_rd+2
        sta     snap_wr+2
        clc
        rts
no:     sec
        rts
.endproc
; snap: A = the snapshot's byte Y, cz_v = A on entry; snap_pon: the snapshot's byte Y := A (X, Y kept)
snap:   sta     cz_v
snap_rd: lda    $FFFF,y
        rts
snap_pon:
snap_wr: sta    $FFFF,y
        rts

; ---- cab_paso5 (spr_draw_all, step 5, before the rectangles are blitted; MEMCFG = MEM_RAM) -----------------------
REG0P   = REG0 & $FF00                  ; the records' page: REG0P + reg_lo[h] + field
        .assert >(REG0 + $14 * NCAB) = >REG0, error, "cabezas128: the head records in one page"
.proc cab_paso5
        lda     creg                    ; the heads of the window: the rebuilt ones and those shown whose record was
        sta     cz_s                    ; drawn in this pass without them (gone, hidden)
        ldx     #NCAB - 1
oo:     lda     cbit,x
        bit     creg
        bne     oo2
        and     cvis
        beq     oo2
        ldy     reg_lo,x
        lda     REG0P,y
        and     #$40
        beq     oo2
        lda     cbit,x
        ora     cz_s
        sta     cz_s
oo2:    dex
        bpl     oo
        lda     cz_s                    ; and the light's heads gone in this pass
        ora     luzgo
        sta     cz_s
        bne     :+
        rts
:       lda     MEMCFG
        pha
        lda     #MEM_IO
        sta     MEMCFG
        jsr     mide
        ; one window for all of them when the beam's forbidden stretch (hi - lo + 5 + D lines) leaves room in the
        ; frame (312 lines; H7's way, two heads); else one window a head (the C128's six heads: three of them can
        ; need 353 lines, measured, and the wait never ended); a head alone needs at most 24 + 5 + 255
        lda     cz_hi
        sec
        sbc     cz_lo
        sta     cz_u
        lda     #0
        sta     cz_v
        lda     cz_u
        clc
        adc     #5
        sta     cz_u
        bcc     :+
        inc     cz_v
:       lda     cz_u
        clc
        adc     cz_d
        sta     cz_u
        bcc     :+
        inc     cz_v
:       lda     cz_u
        cmp     #<LARGO_MAX
        lda     cz_v
        sbc     #>LARGO_MAX
        bcs     varias
        jsr     ventana
        jsr     todas
        jmp     fin
varias: lda     cz_s
        sta     cz_m
        ldx     #NCAB - 1
un:     lda     cbit,x
        and     cz_m
        beq     un2
        sta     cz_s
        stx     cz_x
        jsr     mide
        jsr     ventana
        jsr     todas
        ldx     cz_x
un2:    dex
        bpl     un
fin:    pla
        sta     MEMCFG
        lda     #0
        sta     creg
        sta     luzgo
        sta     luzpas
        rts
.endproc
LARGO_MAX = 300                         ; (the frame's 312 lines, a margin of 12)

; the heads of cz_s: their cell rows [cz_lo, cz_hi) (sprite space) and D (lines): 16 + 32 + 5 w a head (H7, calibrated)
.proc mide
        lda     #$FF
        sta     cz_lo
        lda     #0
        sta     cz_hi
        lda     #16
        sta     cz_d
        ldx     #NCAB - 1
oo:     lda     cbit,x
        and     cz_s
        beq     oo2
        jsr     filas
        lda     cz_v
        cmp     cz_lo
        bcs     :+
        sta     cz_lo
:       lda     cz_n
        cmp     cz_hi
        bcc     :+
        sta     cz_hi
:       lda     cbit,x                  ; D += 32 + 5 w (w: its rectangle's width, CPC bytes; the light's for a head
        and     luzpas                  ; of the light)
        beq     :+
        lda     luzgeo+2
        jmp     :++
:       ldy     reg_lo,x
        lda     REG0P+$0E,y
:       sta     cz_u
        asl
        asl
        adc     cz_u
        bcs     sat
        adc     #32
        bcs     sat
        adc     cz_d
        bcc     :+
sat:    lda     #$FF
:       sta     cz_d
oo2:    dex
        bpl     oo
        rts
.endproc

; waits for the window of cz_lo, cz_hi, cz_d: the beam must not be in [lo + 11 - D - 2, hi + 11 + 2) when it starts
; (raster line = sprite line + 11; in half lines, 156 a frame): lo2 = (lo + 9 - D) / 2, + 156 below 0 (wrapped);
; hi2 = (hi + 14) / 2.  The I/O visible
.proc ventana
        lda     cz_hi
        clc
        adc     #14
        ror
        sta     zt0+7                   ; (haz_espera's hi)
        lda     cz_lo
        clc
        adc     #9
        sec
        sbc     cz_d
        php
        lsr
        plp
        ldx     #0
        bcs     :+
        adc     #28                     ; (C = 0) (v + 256) / 2 + 28 = v / 2 + 156
        ldx     #$80
:       stx     zt0+1                   ; (wrapped)
        sta     zt0                     ; (lo)
        jmp     haz_espera
.endproc

; the heads of cz_s to the screen: the first FILAS cell rows of each one's own rectangle and its hardware sprite (slot,
; position, on), or its sprite off; the I/O visible
.proc todas
        ldx     #NCAB - 1
vv:     lda     cbit,x
        and     cz_s
        bne     :+
        jmp     vv2
:       stx     cz_k
        jsr     filas                   ; the first FILAS cell rows of the head's own rectangle, as a record for the blit
        lda     cbit,x
        and     luzpas
        beq     propia
        jsr     luz_filas               ; a head of the light: its rows of the light's rectangle (or no blit)
        bcs     sinblit
        jmp     blit
propia: ldy     reg_lo,x
        ldx     #0
:       lda     REG0P+$0C,y             ; (x, y, w, h, buffer: +0Ch..+11h)
        sta     cfk,x
        iny
        inx
        cpx     #6
        bne     :-
        lda     #FILAS * 8
        sta     cfk+3
blit:   lda     #<(cfk - 12)
        sta     zix
        lda     #>(cfk - 12)
        sta     zix+1
        jsr     spr_blit_to_screen
sinblit:
        ldx     cz_k
        lda     cbit,x                  ; rebuilt: the slot and the position; else off
        and     creg
        bne     :+
        jmp     apaga
:       stx     cz_u                    ; the slot: SLOTS + 64 h
        lda     #0
        sta     cz_v
        ldy     #6
:       asl     cz_u
        rol     cz_v
        dey
        bne     :-
        lda     cz_u
        clc
        adc     #<SLOTS
        sta     sl+1
        lda     cz_v
        adc     #>SLOTS
        sta     sl+2
        txa                             ; pend[h]: 30 h
        asl
        sta     cz_u
        asl
        asl
        asl
        asl
        sec
        sbc     cz_u
        tay
        ldx     #0
:       lda     pend,y
sl:     sta     $FFFF,x
        iny
        inx
        cpx     #30
        bne     :-
        ldx     cz_k
        txa
        asl
        tay
        lda     cny,x                   ; Y = y + 10
        clc
        adc     #10
        VIC_STA $01, y
        lda     #0                      ; X = 24 + 4 x (9 bits)
        sta     cz_u
        lda     cnx,x
        asl
        rol     cz_u
        asl
        rol     cz_u
        adc     #24
        VIC_STA $00, y
        bcc     :+
        inc     cz_u
:       VIC_LDA $10
        ora     cbit,x
        lsr     cz_u
        bcs     :+
        eor     cbit,x
:       VIC_STA $10
        lda     cvis
        ora     cbit,x
        bne     vfin
apaga:  lda     cbit,x
        eor     #$FF
        and     cvis
vfin:   sta     cvis
        VIC_STA $15
vv2:    dex
        bmi     fin_v
        jmp     vv
fin_v:  rts
.endproc

; the head X's cell rows for the window: [cz_v, cz_n) = its own rectangle's first FILAS cell rows (its y to y + 24).  X
; kept
.proc filas
        lda     cbit,x
        and     luzpas
        bne     luz
        ldy     reg_lo,x
        lda     REG0P+$0D,y
        sta     cz_v
        clc
        adc     #FILAS * 8
        sta     cz_n
        rts
luz:    lda     cny,x                   ; a head of the light: the cell row of its first line, FILAS of them
        and     #$F8
        sta     cz_v
        clc
        adc     #FILAS * 8
        sta     cz_n
        rts
.endproc

; a head X of the light: cfk := the light's rectangle's cell rows from the head's first line's (FILAS at most, inside
; the rectangle): x, its y, w, its h, the buffer + its rows' offset (rows x luzf4w).  C = 1: the head's first line
; outside the rectangle (gone with the light): no blit.  X kept
.proc luz_filas
        lda     cny,x
        sec
        sbc     luzgeo+1                ; its line in the rectangle
        bcc     no
        cmp     luzgeo+3
        bcs     no
        and     #$F8
        sta     cz_u                    ; its cell row's first line in the rectangle
        lda     luzgeo
        sta     cfk
        lda     luzgeo+2
        sta     cfk+2
        lda     luzgeo+1
        clc
        adc     cz_u
        sta     cfk+1
        lda     luzgeo+3                ; the lines left, FILAS * 8 at most
        sec
        sbc     cz_u
        cmp     #FILAS * 8
        bcc     :+
        lda     #FILAS * 8
:       sta     cfk+3
        lda     luzgeo+4
        sta     cfk+4
        lda     luzgeo+5
        sta     cfk+5
        lda     cz_u                    ; + (cell rows) x luzf4w
        lsr
        lsr
        lsr
        tay
        beq     si
:       lda     cfk+4
        clc
        adc     luzf4w
        sta     cfk+4
        lda     cfk+5
        adc     luzf4w+1
        sta     cfk+5
        dey
        bne     :-
si:     clc
        rts
no:     sec
        rts
.endproc
.endif
