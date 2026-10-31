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

; abadia64ks, 6502 code of the game: group estado_texto, the table entries that nothing in the C64 game calls
; (C reference juego/f_estado_texto.c).  They keep the Z80 functions' interfaces so that the hybrid host checks
; them; the merge can drop this file if no other group imports them: the RST 08h / RST 10h wrappers, the
; inline jump table, 3994 ai_script_operand and 3910 ai_script_var_ptr (the scripts run in logica_b's VM, which
; calls only ai_script_eval; the eval reads its operands inline), 316E util_clear_bytes (its only
; caller, 3176, clears inline), the four height slopes 3521-3540 (inlined in 346E), and the CPC screen-address
; helpers 3558 / 3778 (the C64 code writes the bitmap directly).
        .include "zp.inc"
        .include "mapa64.inc"

        .export ai_script_test, ai_script_assign, util_jump_table_inline, util_clear_bytes
        .export chr_hbuf_slope_x_inc, chr_hbuf_slope_y_dec, chr_hbuf_slope_x_dec, chr_hbuf_slope_y_inc
        .export vid_next_line, vid_xy_to_offset, ai_script_operand, ai_script_var_ptr
        .import estado_texto_eval_y

.segment "CODE"

; 391E ai_script_test (RST 08h): `JSR ai_script_test <expression>`: A = zbc (C) = its value, Z = (value = 0),
; zhl = the terminator, where it returns.  (zhl = the return address, the last byte of the JSR: the
; expression is read from Y = 1.)
ai_script_test:
        pla
        sta     zhl
        pla
        sta     zhl+1
        ldy     #1
        jsr     estado_texto_eval_y
        txa
        jmp     (zhl)

; 38FC ai_script_assign (RST 10h): `JSR ai_script_assign <var> <expression>`: ai_script_dest_ptr := the
; address of var, [it] := the value; A = zbc (C) = the value, zhl = the terminator, where it returns.
ai_script_assign:
        pla
        sta     zhl
        pla
        sta     zhl+1
        ldy     #1
        lda     (zhl),y
        asl
        tax
        lda     D64_AI_SCRIPT_VARS,x
        sta     D64_AI_SCRIPT_DEST_PTR
        lda     D64_AI_SCRIPT_VARS+1,x
        sta     D64_AI_SCRIPT_DEST_PTR+1
        iny
        jsr     estado_texto_eval_y
        txa
        ldy     #0
        sta     (D64_AI_SCRIPT_DEST_PTR),y
        jmp     (zhl)

; 3A5D util_jump_table_inline: `JSR util_jump_table_inline <.word t0, t1, ..., 0>` after a script test: Z set
; selects t0, else entry zbc (C) counted from t1 (0: 256).  The entry is entered by JMP, the JSR's return
; address dropped; past the 0 word it returns after the table.
util_jump_table_inline:
        beq     @zero
        ldx     zbc
        ldy     #3
        bne     @go
@zero:  ldx     #1
        ldy     #1
@go:    pla
        sta     zhl
        pla
        sta     zhl+1
@next:  lda     (zhl),y
        sta     zt0
        iny
        lda     (zhl),y
        sta     zt0+1
        iny
        ora     zt0
        beq     @end
        dex
        bne     @next
        jmp     (zt0)
@end:   tya
        clc
        adc     zhl
        sta     zhl
        bcc     :+
        inc     zhl+1
:       jmp     (zhl)

; 316E util_clear_bytes: zeroes the zbc + 1 bytes from zhl.  Out: zhl = the last one, zde = zhl + 1, BC = 0.
util_clear_bytes:
        ldy     #0
        tya
        sta     (zhl),y
@l:     lda     zbc
        ora     zbc+1
        beq     @r
        inc     zhl
        bne     :+
        inc     zhl+1
:       tya
        sta     (zhl),y
        lda     zbc
        bne     :+
        dec     zbc+1
:       dec     zbc
        jmp     @l
@r:     lda     zhl
        clc
        adc     #1
        sta     zde
        lda     zhl+1
        adc     #0
        sta     zde+1
        rts

; 3521 chr_hbuf_slope_x_inc: A += H' (zhl2+1); the column step = INC C; A' = 0Ch.
chr_hbuf_slope_x_inc:
        clc
        adc     zhl2+1
        ldx     #$0C
        stx     D64_CHR_HBUF_COL_STEP_OP
        stx     za2
        rts
; 352C chr_hbuf_slope_y_dec: A -= H; the row step = DEC C; A' = 0Dh.
chr_hbuf_slope_y_dec:
        sec
        sbc     zhl+1
        ldx     #$0D
        stx     D64_CHR_HBUF_ROW_STEP_OP
        stx     za2
        rts
; 3535 chr_hbuf_slope_x_dec: A -= H'; the column step = DEC C; A' = 0Dh.
chr_hbuf_slope_x_dec:
        sec
        sbc     zhl2+1
        ldx     #$0D
        stx     D64_CHR_HBUF_COL_STEP_OP
        stx     za2
        rts
; 3540 chr_hbuf_slope_y_inc: A += H; the row step = INC C; A' = 0Ch.
chr_hbuf_slope_y_inc:
        clc
        adc     zhl+1
        ldx     #$0C
        stx     D64_CHR_HBUF_ROW_STEP_OP
        stx     za2
        rts

; =============================================================================================================
; the CPC screen address helpers (pure arithmetic, kept for the Z80 callers' interface)
; =============================================================================================================

; 3558 vid_next_line: the CPC screen address of the next pixel line: H + 8; on a carry L + 40h and H = (H +
; that carry) OR C0h.  Out: zhl, A = H, C clear.
vid_next_line:
        lda     zhl+1
        clc
        adc     #8
        sta     zhl+1
        bcc     @r
        lda     zhl
        adc     #$3F                    ; (C set: + 40h)
        sta     zhl
        lda     zhl+1
        adc     #0
        ora     #$C0
        sta     zhl+1
        clc
@r:     rts

; 3778 vid_xy_to_offset: the CPC screen address of byte column L on pixel line H: H = (H rotated left 3) OR
; C0h, L = (that AND C0h) OR L.  Out: zhl, A = L, Z of A.
vid_xy_to_offset:
        lda     zhl+1
        asl
        adc     #0
        asl
        adc     #0
        asl
        adc     #0
        tax
        ora     #$C0
        sta     zhl+1
        txa
        and     #$C0
        ora     zhl
        sta     zhl
        rts

; 3994 ai_script_operand: one operand at zhl.  Out: zbc (C) = its value, zhl past it; A, X, Y changed.
ai_script_operand:
        ldy     #0
        lda     (zhl),y
        bmi     @var
        iny
        cmp     #$40
        bne     @lit
        lda     (zhl),y
        iny
@lit:   sta     zbc
        tya
        clc
        adc     zhl
        sta     zhl
        bcc     :+
        inc     zhl+1
:       rts
@var:   inc     zhl
        bne     :+
        inc     zhl+1
:       asl
        tax
        lda     D64_AI_SCRIPT_VARS,x
        sta     zt0
        lda     D64_AI_SCRIPT_VARS+1,x
        sta     zt0+1
        lda     (zt0),y                 ; (Y = 0)
        sta     zbc
        rts

; 3910 ai_script_var_ptr: zhl = the address of script variable A (word 2 A mod 256 of ai_script_vars).
ai_script_var_ptr:
        asl
        tax
        lda     D64_AI_SCRIPT_VARS,x
        sta     zhl
        lda     D64_AI_SCRIPT_VARS+1,x
        sta     zhl+1
        rts
