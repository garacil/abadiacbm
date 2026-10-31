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

; The music player of the CPC 64 KiB version's first stage (Z80 61BAh-6502h) in 6502 assembly.
;
; The same logic as musica.c (which documents the channel record, the tables and the commands), in
; the CPC's order: it must produce the same register writes, tick by tick (checked with sim65 by
; data/pruebas/prueba_musica.sh).  Each write calls _musica_registro with A = register and
; X = value (an assembly interface, not a C call), which the platform provides (sid.s on the C64, a
; log in the test); it may use ptr1-4, tmp1-4 and must return.
;
; Channel records: struct of arrays indexed by X = 0, 1, 2.

        .export _musica_inicia, _musica_reinicia, _musica_tick, _musica_para, _ay
        .import _musica_registro, popax
        .importzp ptr1, ptr2, tmp1, tmp2, tmp3, tmp4

.segment "BSS"
_ay:            .res 16
c_ptr_lo:       .res 3
c_ptr_hi:       .res 3
c_dur:          .res 3
c_per_lo:       .res 3
c_per_hi:       .res 3
c_ttono_lo:     .res 3          ; pitch table
c_ttono_hi:     .res 3
c_vol:          .res 3
c_n_tono:       .res 3
c_i_tono:       .res 3
c_tvol_lo:      .res 3          ; volume table
c_tvol_hi:      .res 3
c_i_vol:        .res 3
c_n_vol:        .res 3
c_est:          .res 3
c_t_tono:       .res 3
c_t_vol:        .res 3
c_c_tono:       .res 3
c_c_vol:        .res 3
c_d_tono:       .res 3
c_d_vol:        .res 3
c_reg_tono:     .res 3
c_reg_vol:      .res 3
c_mezcla:       .res 3
datos_lo:       .res 1          ; the music: CPC address 8000h is datos
datos_hi:       .res 1
cuenta:         .res 1
recarga:        .res 1
mezclador:      .res 1
mezclador_esc:  .res 1
env_lo:         .res 1
env_hi:         .res 1
env_forma:      .res 1
ruido:          .res 1
canal:          .res 1
nota:           .res 1
est_l:          .res 1          ; registros_canal: the channel's state
mez_a:          .res 1          ; registros_canal: its mixer bits

.segment "RODATA"
per_lo: .byte <$0EEE, <$0E18, <$0D4D, <$0C8E, <$0BDA, <$0B2F, <$0A8F, <$09F7, <$0968, <$08E1, <$0861, <$07E9
per_hi: .byte >$0EEE, >$0E18, >$0D4D, >$0C8E, >$0BDA, >$0B2F, >$0A8F, >$09F7, >$0968, >$08E1, >$0861, >$07E9

.segment "CODE"

; ptr1 = the C64 address of CPC address A (lo) / Y (hi) of the music
.proc cpc_a_ptr1
        pha
        tya
        sec
        sbc     #$80
        sta     ptr1+1
        pla
        clc
        adc     datos_lo
        sta     ptr1
        lda     ptr1+1
        adc     datos_hi                ; with the carry of the low byte
        sta     ptr1+1
        rts
.endproc

; write A = register, Y = value (keeps X)
.proc escribe
        sta     tmp4
        sty     tmp3
        tay
        lda     tmp3
        sta     _ay,y
        stx     canal
        lda     tmp4
        ldx     tmp3
        jsr     _musica_registro
        ldx     canal
        rts
.endproc

; void musica_inicia(const unsigned char *musica, unsigned int longitud, const unsigned char *estado)
.proc _musica_inicia
        sta     ptr2                    ; estado (last argument, in A/X)
        stx     ptr2+1
        jsr     popax                   ; longitud
        sta     tmp1
        stx     tmp2
        jsr     popax                   ; musica
        sta     datos_lo
        stx     datos_hi
        ; recarga = musica[longitud - 1]
        clc
        adc     tmp1
        sta     ptr1
        txa
        adc     tmp2
        sta     ptr1+1
        lda     ptr1
        bne     :+
        dec     ptr1+1
:       dec     ptr1
        ldy     #0
        lda     (ptr1),y
        sta     recarga
        ; globals 6148h-614Eh
        ldy     #0
        lda     (ptr2),y
        sta     mezclador
        iny
        lda     (ptr2),y
        sta     mezclador_esc
        iny
        lda     (ptr2),y
        sta     cuenta
        iny
        lda     (ptr2),y
        sta     env_lo
        iny
        lda     (ptr2),y
        sta     env_hi
        iny
        lda     (ptr2),y
        sta     env_forma
        iny
        lda     (ptr2),y
        sta     ruido
        ; the three records: IX = 6152h + 18h * n, i.e. estado + 0Ah + 18h * n
        ldx     #0
        lda     #$0A
        sta     tmp1
rec:    ldy     tmp1
        dey
        dey
        dey
        lda     (ptr2),y
        sta     c_reg_tono,x
        iny
        lda     (ptr2),y
        sta     c_reg_vol,x
        iny
        lda     (ptr2),y
        sta     c_mezcla,x
        iny
        lda     (ptr2),y
        sta     c_ptr_lo,x
        iny
        lda     (ptr2),y
        sta     c_ptr_hi,x
        iny
        lda     (ptr2),y
        sta     c_dur,x
        iny
        lda     (ptr2),y
        sta     c_per_lo,x
        iny
        lda     (ptr2),y
        sta     c_per_hi,x
        iny
        lda     (ptr2),y
        sta     c_ttono_lo,x
        iny
        lda     (ptr2),y
        sta     c_ttono_hi,x
        iny
        lda     (ptr2),y
        sta     c_vol,x
        iny
        lda     (ptr2),y
        sta     c_n_tono,x
        iny
        lda     (ptr2),y
        sta     c_i_tono,x
        iny
        lda     (ptr2),y
        sta     c_tvol_lo,x
        iny
        lda     (ptr2),y
        sta     c_tvol_hi,x
        iny
        lda     (ptr2),y
        sta     c_i_vol,x
        iny
        lda     (ptr2),y
        sta     c_n_vol,x
        iny
        lda     (ptr2),y
        sta     c_est,x
        iny
        lda     (ptr2),y
        sta     c_t_tono,x
        iny
        lda     (ptr2),y
        sta     c_t_vol,x
        iny
        lda     (ptr2),y
        sta     c_c_tono,x
        iny
        lda     (ptr2),y
        sta     c_c_vol,x
        iny
        lda     (ptr2),y
        sta     c_d_tono,x
        iny
        lda     (ptr2),y
        sta     c_d_vol,x
        lda     tmp1
        clc
        adc     #$18
        sta     tmp1
        inx
        cpx     #3
        beq     :+
        jmp     rec
:       ; 61BAh: channel A at 8000h
        ldx     #0
        lda     #$00
        ldy     #$80
        jmp     arranca
.endproc

; 6019h-6022h when the parchment is entered again: channel A from the start (the tempo is unchanged,
; the other channels keep what _musica_para left)
.proc _musica_reinicia
        ldx     #0
        lda     #$00
        ldy     #$80
        jmp     arranca
.endproc

; channel X starts at CPC address A (lo) / Y (hi)
.proc arranca
        sta     c_ptr_lo,x
        tya
        sta     c_ptr_hi,x
        lda     #5
        sta     c_est,x
        lda     #1
        sta     c_dur,x
        rts
.endproc

; 6416h: next entry of the volume table of channel X
.proc siguiente_vol
otra:   lda     c_tvol_lo,x
        clc
        adc     c_i_vol,x
        pha
        lda     c_tvol_hi,x
        adc     #0
        tay
        pla
        jsr     cpc_a_ptr1
        ldy     #0
        lda     (ptr1),y
        cmp     #$7F
        bne     :+
        lda     #$FF
        sta     c_c_vol,x
        sta     c_t_vol,x
        sta     c_n_vol,x
        lda     #0
        sta     c_d_vol,x
        rts
:       cmp     #$80
        bne     :+
        lda     #0
        sta     c_i_vol,x
        jmp     otra
:       cmp     #$80              ; above 80h: hardware envelope entry
        bcc     normal
        and     #$0F
        sta     env_forma
        iny
        lda     (ptr1),y
        sta     env_lo
        iny
        lda     (ptr1),y
        sta     env_hi
        iny
        lda     (ptr1),y
        sta     c_c_vol,x
        lda     #1
        sta     c_n_vol,x
        lda     c_est,x
        ora     #$10
        sta     c_est,x
        lda     c_i_vol,x
        clc
        adc     #4
        sta     c_i_vol,x
        rts
normal: sta     c_n_vol,x
        iny
        lda     (ptr1),y
        sta     c_d_vol,x
        iny
        lda     (ptr1),y
        sta     c_t_vol,x
        sta     c_c_vol,x
        lda     c_i_vol,x
        clc
        adc     #3
        sta     c_i_vol,x
        rts
.endproc

; 63ACh: next entry of the pitch table of channel X
.proc siguiente_tono
otra:   lda     c_ttono_lo,x
        clc
        adc     c_i_tono,x
        pha
        lda     c_ttono_hi,x
        adc     #0
        tay
        pla
        jsr     cpc_a_ptr1
        ldy     #0
        lda     (ptr1),y
        cmp     #$7F
        bne     :+
        lda     #$FF
        sta     c_c_tono,x
        sta     c_t_tono,x
        sta     c_n_tono,x
        lda     #0
        sta     c_d_tono,x
        rts
:       cmp     #$80
        bne     :+
        lda     #0
        sta     c_i_tono,x
        jmp     otra
:       sta     c_n_tono,x
        iny
        lda     (ptr1),y
        sta     c_d_tono,x
        iny
        lda     (ptr1),y
        sta     c_t_tono,x
        sta     c_c_tono,x
        lda     c_i_tono,x
        clc
        adc     #3
        sta     c_i_tono,x
        rts
.endproc

; 62C7h: one tick of channel X
.proc tick_canal
        lda     c_est,x
        lsr     a
        bcs     :+
        rts
:       lda     c_est,x
        and     #$87
        sta     c_est,x
        lda     cuenta
        beq     :+
        jmp     t6372
:       dec     c_dur,x
        beq     :+
        jmp     t6372
:       lda     #1
        sta     c_est,x
        lda     c_ptr_lo,x
        sta     tmp1
        lda     c_ptr_hi,x
        sta     tmp2                    ; tmp1/tmp2 = CPC address of the stream
mandos: lda     tmp1
        ldy     tmp2
        jsr     cpc_a_ptr1
        ldy     #0
        lda     (ptr1),y
        cmp     #$F9
        bcc     nomando
        cmp     #$FF
        bcs     nomando
        ; a command: BC = next two bytes, stream += 3
        sta     nota
        iny
        lda     (ptr1),y
        sta     tmp3                    ; C
        iny
        lda     (ptr1),y
        sta     tmp4                    ; B
        lda     tmp1
        clc
        adc     #3
        sta     tmp1
        bcc     :+
        inc     tmp2
:       lda     nota
        cmp     #$F9
        bne     :+
        lda     tmp3
        sta     tmp1
        lda     tmp4
        sta     tmp2
        jmp     mandos
:       cmp     #$FA
        bne     :+
        lda     tmp3
        sta     c_tvol_lo,x
        lda     tmp4
        sta     c_tvol_hi,x
        jmp     mandos
:       cmp     #$FB
        bne     :+
        lda     tmp3
        sta     c_ttono_lo,x
        lda     tmp4
        sta     c_ttono_hi,x
        jmp     mandos
:       cmp     #$FC
        bne     :+
        jmp     mandos
:       stx     canal
        cmp     #$FD
        bne     :+
        ldx     #2
        bne     arr
:       ldx     #1
arr:    lda     tmp3
        ldy     tmp4
        jsr     arranca
        ldx     canal
        jmp     mandos
nomando:
        cmp     #$FF
        bne     :+
        lda     #0
        sta     c_est,x
        rts
:       sta     nota                    ; 6311h: a note
        lda     #1
        sta     c_c_tono,x
        sta     c_n_tono,x
        sta     c_c_vol,x
        sta     c_n_vol,x
        lda     #0
        sta     c_i_vol,x
        sta     c_i_tono,x
        iny
        lda     (ptr1),y
        sta     c_dur,x
        ldy     #2
        lda     nota
        bpl     :+
        lda     (ptr1),y                ; noise period
        sta     ruido
        lda     c_est,x
        ora     #$0A
        sta     c_est,x
        iny
:       tya                             ; stream += 2 or 3
        clc
        adc     tmp1
        sta     c_ptr_lo,x
        lda     tmp2
        adc     #0
        sta     c_ptr_hi,x
        lda     #0
        sta     c_vol,x
        lda     c_est,x
        ora     #$80
        sta     c_est,x
        lda     nota
        and     #$0F
        cmp     #$0F
        bne     :+
        rts                             ; a rest
:       tay
        lda     c_est,x
        and     #$7F
        sta     c_est,x
        lda     per_lo,y
        sta     tmp3
        lda     per_hi,y
        sta     tmp4
        lda     nota
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        and     #7
        beq     :++
        tay
:       lsr     tmp4
        ror     tmp3
        dey
        bne     :-
:       lda     tmp3
        sta     c_per_lo,x
        lda     tmp4
        sta     c_per_hi,x
t6372:  lda     c_est,x
        and     #$84
        beq     :+
        rts
:       ; 63F0h: the volume envelope
        dec     c_c_vol,x
        bne     tono
        dec     c_n_vol,x
        bne     :+
        jsr     siguiente_vol
:       lda     c_est,x
        ora     #$20
        sta     c_est,x
        lda     c_t_vol,x
        sta     c_c_vol,x
        lda     c_est,x
        and     #$10
        bne     tono
        lda     c_vol,x
        clc
        adc     c_d_vol,x
        and     #$0F
        sta     c_vol,x
tono:   dec     c_c_tono,x
        beq     :+
        rts
:       dec     c_n_tono,x
        bne     :+
        jsr     siguiente_tono
:       lda     c_t_tono,x
        sta     c_c_tono,x
        lda     c_d_tono,x              ; period += signed step
        clc
        adc     c_per_lo,x
        sta     c_per_lo,x
        lda     c_d_tono,x
        and     #$80
        beq     :+
        lda     #$FF
:       adc     c_per_hi,x
        sta     c_per_hi,x
        lda     c_est,x
        ora     #$40
        sta     c_est,x
        rts
.endproc

; 624Bh: the registers of channel X
.proc registros_canal
        lda     c_est,x
        sta     est_l
        lsr     a
        bcs     :+
        rts
:       lda     est_l
        and     #$84
        beq     :+
        rts
:       lda     est_l
        and     #$40
        beq     vol
        lda     c_reg_tono,x
        ldy     c_per_lo,x
        jsr     escribe
        lda     c_reg_tono,x
        clc
        adc     #1
        ldy     c_per_hi,x
        jsr     escribe
vol:    lda     est_l
        and     #$20
        beq     mez
        lda     est_l
        and     #$10
        bne     env
        lda     c_reg_vol,x
        ldy     c_vol,x
        jsr     escribe
        jmp     mez
env:    lda     #11
        ldy     env_lo
        jsr     escribe
        lda     #12
        ldy     env_hi
        jsr     escribe
        lda     #13
        ldy     env_forma
        jsr     escribe
        lda     c_reg_vol,x
        ldy     #$10
        jsr     escribe
mez:    lda     #7
        sta     mez_a
        lda     est_l
        and     #$02
        beq     :+
        lda     #$3F
        sta     mez_a
        lda     est_l
        and     #$08
        beq     :+
        lda     #6
        ldy     ruido
        jsr     escribe
:       lda     mez_a
        and     c_mezcla,x
        eor     mezclador
        sta     mezclador
        rts
.endproc

; 61DBh: one 300 Hz tick
.proc _musica_tick
        lda     c_est
        ora     c_est+1
        ora     c_est+2
        lsr     a
        bcs     :+
        rts
:       lda     cuenta
        bne     :+
        lda     recarga
        sta     cuenta
        jmp     :++
:       dec     cuenta
:       lda     #$3F
        sta     mezclador
        ldx     #0
        jsr     tick_canal
        ldx     #1
        jsr     tick_canal
        ldx     #2
        jsr     tick_canal
        ldx     #0
        jsr     registros_canal
        ldx     #1
        jsr     registros_canal
        ldx     #2
        jsr     registros_canal
        lda     mezclador
        cmp     mezclador_esc
        beq     :+
        sta     mezclador_esc
        tay
        lda     #7
        jsr     escribe
:       rts
.endproc

; 64F1h: silence
.proc _musica_para
        lda     #$84
        sta     c_est
        sta     c_est+1
        sta     c_est+2
        lda     #7
        ldy     #$3F
        jmp     escribe
.endproc
