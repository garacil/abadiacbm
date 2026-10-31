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

; abadia64ks, c64/plataforma/pruebas: the reference for sid_igual.c, plat_psg as it was before the SID voicing (a copy of
; c64/plataforma/psg.s, after the interrupt work): the AY played as it is, pulse 50 %, envelope rates 0.
; Below, its own header.
;
; abadia64ks, the C64 platform layer: plat_psg, the CPC's sound chip (AY-3-8912) played on the SID.
;
; plat_psg: A = AY register 0-15, X = value.  A and X kept, Y clobbered; the interrupt flag is kept.  Needs the
; I/O visible ($01 = $35).  Registers 6-15 run with the interrupts off (PHP / SEI / PLP: the main code writes the
; mixer too, snd_silence_all and the pause).  The tone registers 0-5 do not: the game writes them only from the
; 300 Hz interrupt (snd_channel_output), the hot path (a period nearly every tick while a sound plays); a write
; of them from the main code would have to come with the interrupts off.  psg_inicio: the SID and this state at
; rest (plat_inicio calls it; the state is BSS, which the loader does not load).
;
; Each AY channel is a SID voice (A -> voice 1, B -> 2, C -> 3):
;   tone period P (registers 0-5; the coarse byte, written after the fine one, makes the change: the game
;     always writes both, fine first) -> SID frequency 2^24 * (1 MHz / 16 P) / 985248 = 1064277 / P: P in
;     128-255 from a table of 129 values (65 stored, the odd ones the mean of their neighbours), P < 128 by
;     P << k into that range, P >= 256 by P >> s rounded (within 7 cents); P < 17 -> $FFFF (3.9 kHz, the SID's
;     top; the AY goes higher);
;   noise period N (register 6, 0-31, 0 = 1): the AY's noise generator changes 62500 / N times a second; the
;     SID's noise waveform changes once every 2^20 / 985248 / F seconds, so F = 66517 / N = the tone frequency
;     of the period 16 N (the same table);
;   mixer (register 7, bit c clear: tone of channel c on; bit c + 3 clear: its noise on): noise on -> the SID's
;     noise waveform (with the tone too: the AY ANDs both, the SID cannot; the noise is what is heard), else
;     tone on -> pulse 50 %, else the voice is released (silence);
;   volume (registers 8-10, 0-15) -> the SID envelope's sustain level (the AY's logarithmic levels, MAME's
;     table, x 15, at least 1): attack 2 ms, decay 6 ms, release 6 ms; a lower volume lowers the sustain level
;     (the SID decays to it), a higher one gates the voice again (it rises to the top and decays to the new
;     level), 0 releases it;
;   registers 11-13 (the hardware envelope; the volume's bit 4) and 14-15 (ports): not used by the game (no
;     volume envelope of its sound data has an 8xh entry): ignored.

        .include "plat64.inc"
        .export plat_psg, psg_inicio

; 2^24 * 62500 / 985248: the SID frequency of the AY period 1 (PAL)
K_FREC  = 1064277

.segment "BSS"
; the state psg_inicio clears (one block, in this order)
per_lo: .res 3                          ; the fine tone period as written
frec_lo: .res 3                         ; the tone's SID frequency
frec_hi: .res 3
ruido_lo: .res 1                        ; the noise's SID frequency
ruido_hi: .res 1
volumen: .res 3                         ; AY volume 0-15
onda:   .res 3                          ; the waveform: 0 (silent), $40 pulse, $80 noise
puerta: .res 3                          ; the gate: 0 off, 1 on
estado_fin:
mezcla: .res 1                          ; the mixer as written
valor:  .res 1                          ; the value of the write being done
p_lo:   .res 1                          ; the period being converted
p_hi:   .res 1
f_lo:   .res 1                          ; its SID frequency
f_hi:   .res 1

.segment "RODATA"
voz:    .byte   0, 7, 14
bit_canal: .byte 1, 2, 4, 8, 16, 32     ; the mixer's tone bits (0-2) and noise bits (3-5) of each channel
; the SID's sustain level of each AY volume (x 16: the SR register, release 0)
sostenido:
        .byte   $00, $10, $10, $10, $10, $10, $10, $20, $30, $40, $50, $70, $90, $A0, $D0, $F0
; 1064277 / m for m = 128, 130, ... 256, rounded
t_lo:   .repeat 65, i
        .byte   <((2 * K_FREC + 128 + 2 * i) / (2 * (128 + 2 * i)))
        .endrep
t_hi:   .repeat 65, i
        .byte   >((2 * K_FREC + 128 + 2 * i) / (2 * (128 + 2 * i)))
        .endrep

.segment "CODE"

.proc plat_psg
        cmp     #6
        bcs     otros
        lsr     a                       ; a tone register: the channel; C = 1: the coarse byte
        tay
        txa
        bcs     grueso
        sta     per_lo,y                ; the fine byte: kept for the coarse one
        tya                             ; A = the register (2 c)
        asl     a
        rts
grueso: stx     valor                   ; the period P = (coarse & 0Fh) : fine -> frec of the channel
        and     #$0F
        bne     grande                  ; P >= 256
        lda     per_lo,y
        bpl     pequeno                 ; P < 128
        eor     #$80                    ; 128-255 (as `tabla`): h = P - 128, i = h / 2, C = h odd
        lsr     a
        tax
        lda     t_lo,x
        bcs     impar
        sta     frec_lo,y
        lda     t_hi,x
        sta     frec_hi,y
        bcc     hecho                   ; (C = 0)
grande: sta     p_hi                    ; the other periods: convierte (C = 1 from the LSR)
        lda     per_lo,y
        bcs     convierte_p
pequeno:
        ldx     #0
        stx     p_hi
convierte_p:
        sta     p_lo
        jsr     convierte
        lda     f_hi
        sta     frec_hi,y
        lda     f_lo
        jmp     guarda
impar:  adc     t_lo+1,x                ; (T(P - 1) + T(P + 1) + 1) / 2 (C = 1)
        sta     f_lo
        lda     t_hi,x
        adc     t_hi+1,x
        lsr     a
        sta     frec_hi,y
        lda     f_lo
        ror     a
guarda: sta     frec_lo,y
hecho:  lda     onda,y                  ; a pulse: its frequency to the SID
        cmp     #$40
        bne     :+
        ldx     voz,y
        lda     frec_lo,y
        sta     SID+0,x
        lda     frec_hi,y
        sta     SID+1,x
:       ldx     valor
        tya                             ; A = the register (2 c + 1)
        sec
        rol     a
        rts

otros:  php                             ; registers 6-15: with the interrupts off
        sei
        pha
        stx     valor
        cmp     #8
        bcc     :+
        cmp     #11
        bcs     fin                     ; 11-15: not used
        sbc     #7                      ; 8-10 (C = 0): the channel
        tay
        jsr     pon_volumen
fin:    pla
        ldx     valor
        plp
        rts
:       cmp     #7
        beq     mezclador

ruido:  lda     valor                   ; period 16 N
        and     #$1F
        bne     :+
        lda     #1
:       sta     p_lo
        lda     #0
        asl     p_lo
        rol     a
        asl     p_lo
        rol     a
        asl     p_lo
        rol     a
        asl     p_lo
        rol     a
        sta     p_hi
        jsr     convierte
        lda     f_lo
        sta     ruido_lo
        lda     f_hi
        sta     ruido_hi
        ldy     #2
:       lda     onda,y
        bpl     :+                      ; not noise
        jsr     pon_frecuencia
:       dey
        bpl     :--
        jmp     fin

mezclador:
        lda     valor
        cmp     mezcla
        beq     fin2                    ; no change
        sta     mezcla
        ldy     #2
canal:  jsr     actualiza
        dey
        bpl     canal
fin2:   jmp     fin
.endproc

; the voice of channel Y after a mixer write: its waveform from the mixer, the gate as the volume says
.proc actualiza
        lda     mezcla
        and     bit_canal+3,y
        beq     :+                      ; noise on: $80
        lda     mezcla
        and     bit_canal,y
        beq     :++                     ; tone on: $40
        lda     #0
        beq     nueva
:       lda     #$80
        bne     nueva
:       lda     #$40
nueva:  cmp     onda,y
        beq     fin
        sta     onda,y
        tax
        beq     suelta
        jsr     pon_frecuencia
        lda     puerta,y
        bne     :+                      ; sounding: the new waveform, the envelope goes on
        lda     volumen,y
        beq     fin                     ; volume 0: stays silent
        lda     #1
        sta     puerta,y
:       ldx     voz,y
        lda     onda,y
        ora     #1
        sta     SID+4,x
fin:    rts
.endproc

; channel Y: volume valor & 15
.proc pon_volumen
        lda     valor
        and     #$0F
        cmp     volumen,y
        beq     fin
        pha
        lda     volumen,y
        sta     p_lo                    ; the old volume
        pla
        sta     volumen,y
        tax
        lda     sostenido,x
        ldx     voz,y
        sta     SID+6,x
        lda     onda,y
        beq     fin                     ; silent: kept for when it sounds
        lda     volumen,y
        beq     suelta
        lda     puerta,y
        beq     :+                      ; released: gate it
        lda     volumen,y
        cmp     p_lo
        bcc     fin                     ; lower: the SID decays to the new sustain level
:       lda     onda,y                  ; higher: gate again
        sta     SID+4,x
        ora     #1
        sta     SID+4,x
        lda     #1
        sta     puerta,y
fin:    rts
.endproc

; channel Y: the gate off (volume 0: the release with its waveform; mixer off: its waveform is 0 already, the
; voice stops at once, as the AY's)
.proc suelta
        lda     puerta,y
        beq     :+
        lda     #0
        sta     puerta,y
        ldx     voz,y
        lda     onda,y
        sta     SID+4,x
:       rts
.endproc

; channel Y: its frequency (tone or noise, by its waveform) to its SID voice
.proc pon_frecuencia
        ldx     voz,y
        lda     onda,y
        bmi     :+
        lda     frec_lo,y
        sta     SID+0,x
        lda     frec_hi,y
        sta     SID+1,x
        rts
:       lda     ruido_lo
        sta     SID+0,x
        lda     ruido_hi
        sta     SID+1,x
        rts
.endproc

; p_hi:p_lo (0-4095) -> f_hi:f_lo = 1064277 / P (P < 17: $FFFF).  Y kept.
.proc convierte
        sty     guarda_y
        ldy     #0
        lda     p_hi
        bne     grande
        lda     p_lo
        bmi     tabla_y                 ; 128-255: from the table
        cmp     #17
        bcc     tope
:       iny                             ; P << k into 128-254
        asl     a
        bpl     :-
        jsr     tabla
:       asl     f_lo
        rol     f_hi
        dey
        bne     :-
        beq     fin
tope:   lda     #$FF
        sta     f_lo
        sta     f_hi
        bne     fin
grande: iny                             ; P >> s into 128-255, the last bit shifted out rounds
        lsr     p_hi
        ror     p_lo
        lda     p_hi
        bne     grande
        lda     p_lo
        adc     #0                      ; 255 + 1 -> 0, m = 256
        jsr     tabla
:       lsr     f_hi
        ror     f_lo
        dey
        bne     :-
fin:    ldy     guarda_y
        rts
tabla_y:
        jsr     tabla
        jmp     fin
.endproc

; A = m (128-255, 0 for 256) -> f_hi:f_lo = 1064277 / m.  X clobbered, Y kept.
.proc tabla
        eor     #$80                    ; h = m - 128: 0-128
        lsr     a                       ; i = h / 2, C = h odd
        tax
        lda     t_lo,x
        sta     f_lo
        lda     t_hi,x
        sta     f_hi
        bcc     :+
        lda     f_lo                    ; odd m: (T(m - 1) + T(m + 1) + 1) / 2 (C = 1)
        adc     t_lo+1,x
        sta     f_lo
        lda     f_hi
        adc     t_hi+1,x
        lsr     a
        sta     f_hi
        ror     f_lo
:       rts
.endproc

.proc psg_inicio
        lda     #0
        ldx     #24
:       sta     SID,x
        dex
        bpl     :-
        ldx     #estado_fin - per_lo - 1 ; the whole state: the periods and frequencies too (BSS: the loader does
:       sta     per_lo,x                ; not load it, so pon_frecuencia must never find leftovers there)
        dex
        bpl     :-
        lda     #$08                    ; pulse width 50 %
        sta     SID+3
        sta     SID+10
        sta     SID+17
        lda     #$3F                    ; the AY's mixer at rest: all off
        sta     mezcla
        lda     #$0F                    ; volume 15, no filter
        sta     SID_VOLUMEN
        rts
.endproc

.segment "BSS"
guarda_y: .res 1
