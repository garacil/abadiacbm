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

; The CPC's sound chip (AY-3-8912) played on the C64's SID, and the 300 Hz interrupt of the music.
;
; _musica_registro (A = register, X = value) receives the player's writes (musica.s), in the CPC's
; order.  Each AY channel is a SID voice.  The notes and their timing are the AY's: the same frequencies, a
; voice gated, struck again and released on the same register writes as before (as the AY's tone starts, its
; volume rises and its tone stops); the voicing is the SID's, by role (c64/optimizacion/sid/NOTAS.md):
;   tone period P (registers 0-5, high byte last) -> SID frequency 1064250 / P (AY clock 1 MHz,
;     f = 1e6 / (16 P); SID PAL: F = f * 2^24 / 985248): every period the two tunes write is in the table
;     (sid_tabla.py: the 96 notes and the ending's vibrato), found by a binary search; others by a division;
;   volume v (registers 8-10) -> the SID sustain level of the AY's logarithmic level (MAME's AY
;     table scaled to 0-15): a lower volume lowers the sustain level (the SID decays to it), a higher
;     one gates the voice again (it rises to the top and decays to the new level); 0 releases it;
;   mixer (register 7): a disabled tone releases the voice (the gate off, the waveform kept: its release);
;   the voices (the profile _musica_irq_on is given: 0 the introduction, 1 the ending):
;     the melody (A): pulse, its width swept slowly between 25 and 50 % (a triangle LFO of its own rate and
;       phase), attack 8 ms, decay and release 24 ms;
;     the bass (the introduction's B, the ending's C): a pulse swept between 37 and 50 % (its weight kept, its even
;       harmonics coming and going) through the SID's resonant low-pass filter, whose cut-off opens at each note
;       it strikes and closes slowly (an envelope of ~0.4 s);
;     the introduction's C (a few chord notes): triangle, attack 16 ms, decay and release 48 ms;
;     the ending's B (the singing line with the vibrato and the swells): a thinner pulse (12-37 %) under the
;       melody, attack 24 ms, decay and release 72 ms;
;   every voice keeps one rate for its attack and release (and its decay no slower): the SID's envelope delay
;   (its rate counter overrunning a faster rate's period, up to 33 ms) never comes in, so a note sounds on its tick.
; Registers 6 (noise) and 11-13 (hardware envelope) are not used by this music.
;
; musica_irq_on (A = the profile) / musica_irq_off: CIA 1 timer A at 300 Hz; the KERNAL interrupt entry ($0314)
; calls _musica_tick, then sid_tick (the voicing's work a tick: a voice's pulse width or the filter's envelope,
; in turn), and returns through the KERNAL's register restore ($EA81), without the KERNAL's keyboard
; scan and clock (not needed, and they would make a tick long enough to lose the next); the zero page the C
; runtime and the drawing share (ptr1-ptr4, tmp1-tmp4) is kept.

        .export _musica_registro, _musica_irq_on, _musica_irq_off, _musica_ticks, sid_tick
        .import _musica_tick
        .importzp ptr1, ptr2, ptr3, ptr4, tmp1, tmp2, tmp3, tmp4

SID = $D400
PICO  = $68                     ; the bass filter's cut-off (bits 3-10) at a note's strike: ~4.5 kHz on a 6581
SUELO = $20                     ; and its floor: ~0.7 kHz on a 6581 (~2.5 kHz on an 8580)

.segment "BSS"
per_lo:   .res 3
per_hi:   .res 3
vol:      .res 3
activa:   .res 3                ; tone enabled by the mixer
sonando:  .res 3                ; gate on
num:      .res 3                ; division: 1064250 (24 bits)
coc:      .res 2
resto:    .res 2
divisor:  .res 2
guarda:   .res 12
viejo_irq: .res 2
_musica_ticks: .res 2           ; interrupts counted (for tests)
reg:      .res 1
valor:    .res 1
; the voices of the profile (copied by musica_irq_on, in this order)
forma:    .res 3                ; the waveform: $40 pulse, $10 triangle
ad:       .res 3                ; attack / decay
rel:      .res 3                ; release (the attack's rate)
paso_lo:  .res 3                ; the pulse width's LFO: its phase's step an update (75 a second)
paso_hi:  .res 3
ancho:    .res 3                ; the width's depth: the triangle (0-255) << ancho
base:     .res 3                ; the width's lowest, high byte
filtro:   .res 1                ; the filtered voice (0-2)
fase_lo:  .res 3                ; the LFOs' phases
fase_hi:  .res 3
turno:    .res 1                ; the voice whose width moves this tick
apagar:   .res 3                ; a released voice: its turns until its waveform goes off (its release over)
corte_lo: .res 1                ; the filter's cut-off (corte_hi: bits 3-10) and its fraction
corte_hi: .res 1

.segment "RODATA"
        .include "sid_tabla.inc"
voz:      .byte 0, 7, 14
; AY volume 0-15 -> SID sustain 0-15 (MAME's AY level table, 15 * level, rounded)
sostenido: .byte 0, 0, 0, 0, 1, 1, 1, 2, 3, 4, 5, 7, 9, 10, 13, 15
; the profiles: per voice A, B, C the waveform, AD, release, the LFO's step (low, high: one turn in 65536 / step
; updates, 75 a second), the depth, the base; then the filtered voice and the filter register ($D417: the
; resonance | the voice's bit)
NPERFIL = 7 * 3 + 2
perfiles:
        ; the introduction: A the melody, B the bass, C the chord notes
        .byte   $40, $40, $10           ; waveforms
        .byte   $11, $11, $22           ; attack / decay: 8 / 24 ms, 8 / 24 ms, 16 / 48 ms
        .byte   $01, $01, $02           ; release: 24, 24, 48 ms
        .byte   <(65536 / 150), <(65536 / 240), 0       ; the LFO: a turn in 2.0 s, 3.2 s
        .byte   >(65536 / 150), >(65536 / 240), 0
        .byte   2, 1, 0                 ; width: $400 + 4 t (25-50 %), $600 + 2 t (37-50 %)
        .byte   $04, $06, $08
        .byte   1, $A2                  ; B filtered, resonance 10
        ; the ending: A the high melody, B the singing line, C the bass
        .byte   $40, $40, $40
        .byte   $11, $33, $11           ; 8 / 24 ms, 24 / 72 ms, 8 / 24 ms
        .byte   $01, $03, $01           ; 24, 72, 24 ms
        .byte   <(65536 / 120), <(65536 / 195), <(65536 / 240)  ; 1.6 s, 2.6 s, 3.2 s
        .byte   >(65536 / 120), >(65536 / 195), >(65536 / 240)
        .byte   2, 2, 1                 ; $400 + 4 t (25-50 %), $200 + 4 t (12-37 %), $600 + 2 t (37-50 %)
        .byte   $04, $02, $06
        .byte   2, $A4                  ; C filtered
        .assert * - perfiles = 2 * NPERFIL, error, "the profiles' size"

.segment "CODE"

.proc _musica_registro
        sta     reg
        stx     valor
        cmp     #6
        bcs     :+
        ; tone period: registers 0-5
        lsr     a                       ; channel, C = high byte
        tay
        lda     valor
        bcs     alto
        sta     per_lo,y
        rts
alto:   sta     per_hi,y
        jmp     frecuencia              ; Y = channel
:       cmp     #7
        bne     :+
        jmp     mezclador
:       cmp     #8
        bcc     fin
        cmp     #11
        bcs     fin
        sec                             ; volume: registers 8-10
        sbc     #8
        tay
        lda     valor
        and     #$0F
        cmp     vol,y
        sta     vol,y
        bcc     baja                    ; lower: the sustain level follows
        beq     fin
        jmp     dispara                 ; higher: gate again
baja:   jmp     sustain
fin:    rts
.endproc

; the voice of channel Y: SID frequency = 1064250 / period: from the table of the tunes' periods
; (binary search), else by division (pitch slides)
.proc frecuencia
        lda     per_lo,y
        sta     divisor
        lda     per_hi,y
        and     #$0F
        sta     divisor+1
        ; binary search in tab_p (sorted ascending): lo = tmp1, hi = tmp2 (exclusive)
        lda     #0
        sta     tmp1
        lda     #NPERIODOS
        sta     tmp2
busca:  lda     tmp1
        cmp     tmp2
        bcs     dividir
        clc
        adc     tmp2
        ror     a
        tax                             ; mid
        lda     tab_p_hi,x
        cmp     divisor+1
        bne     :+
        lda     tab_p_lo,x
        cmp     divisor
        beq     hallado
:       bcs     menor                   ; tab[mid] > P: search the lower half
        inx
        stx     tmp1
        jmp     busca
menor:  stx     tmp2
        jmp     busca
hallado:
        lda     tab_f_lo,x
        sta     coc
        lda     tab_f_hi,x
        sta     coc+1
        jmp     pon
dividir:
        lda     divisor
        ora     divisor+1
        bne     :+
        lda     #$FF                    ; period 0: the highest
        sta     coc
        sta     coc+1
        jmp     pon
:       lda     #<1064250
        sta     num
        lda     #>1064250
        sta     num+1
        lda     #^1064250
        sta     num+2
        lda     #0
        sta     resto
        sta     resto+1
        sta     coc
        sta     coc+1
        ldx     #24
paso:   asl     num                     ; shift the dividend into the remainder
        rol     num+1
        rol     num+2
        rol     resto
        rol     resto+1
        lda     resto
        sec
        sbc     divisor
        sta     tmp1
        lda     resto+1
        sbc     divisor+1
        bcc     :+
        sta     resto+1
        lda     tmp1
        sta     resto
:       rol     coc                     ; quotient bit = carry
        rol     coc+1
        bcc     :+
        lda     #$FF                    ; more than 16 bits: the highest
        sta     coc
        sta     coc+1
        jmp     pon
:       dex
        bne     paso
pon:    ldx     voz,y
        lda     coc
        sta     SID+0,x
        lda     coc+1
        sta     SID+1,x
        rts
.endproc

; mixer: bit c clear = tone of channel c enabled
.proc mezclador
        ldy     #0
        lda     valor
        sta     tmp1
canal:  lsr     tmp1
        lda     #0
        bcs     :+
        lda     #1
:       cmp     activa,y
        beq     sig
        sta     activa,y
        cmp     #0
        beq     :+
        jsr     dispara
        jmp     sig
:       jsr     suelta
sig:    iny
        cpy     #3
        bne     canal
        rts
.endproc

; channel Y: gate the voice again with its volume (when its tone is enabled and the volume is not 0); the bass
; strikes its filter's envelope
.proc dispara
        lda     activa,y
        beq     suelta
        lda     vol,y
        beq     suelta
        ldx     voz,y
        lda     ad,y                    ; the voice's attack and decay
        sta     SID+5,x
        stx     tmp2
        ldx     vol,y
        lda     sostenido,x
        asl     a
        asl     a
        asl     a
        asl     a
        ora     rel,y
        ldx     tmp2
        sta     SID+6,x                 ; sustain, the voice's release
        lda     forma,y                 ; the voice's waveform, gate off
        sta     SID+4,x
        ora     #1                      ; gate on
        sta     SID+4,x
        lda     #1
        sta     sonando,y
        lda     #0
        sta     apagar,y                ; (a release in course: not to be cut)
        cpy     filtro
        bne     :+
        lda     #PICO                   ; the filter opens
        sta     corte_hi
        sta     SID+22
        lda     #0
        sta     corte_lo
:       rts
.endproc

.proc suelta
        lda     sonando,y
        beq     :+
        ldx     voz,y
        lda     forma,y                 ; the gate off, the waveform kept: the release
        sta     SID+4,x
        lda     #0
        sta     sonando,y
        lda     #6                      ; its waveform off after 6 turns (80 ms: the longest release, 72 ms, is over)
        sta     apagar,y
:       rts
.endproc

; channel Y: a lower volume -> lower the sustain level (0 releases the voice)
.proc sustain
        lda     vol,y
        bne     :+
        jmp     suelta
:       lda     sonando,y
        bne     :+
        jmp     dispara
:       ldx     vol,y
        lda     sostenido,x
        asl     a
        asl     a
        asl     a
        asl     a
        ora     rel,y
        ldx     voz,y
        sta     SID+6,x
        rts
.endproc

; ---- the voicing's work a tick ------------------------------------------------------------------------

; One thing a tick, in turn (each 75 times a second): voice A, B, C, then the filter.  A voice: once its release is
; over, its waveform off (a 6581 lets the tone of a voice at the envelope's zero through, ~35 dB down, while its
; waveform runs); a pulse's width: its LFO's phase + its step, the phase's triangle t (0-255), the width
; (base : 0) + t << ancho.  The filter: its cut-off falls towards its floor by 8 (corte - SUELO) / 256 (an
; exponential of 32 turns, 0.43 s).  Uses tmp1, tmp2 (the interrupt keeps them).
.proc sid_tick
        ldx     turno
        dex
        bpl     :+
        ldx     #3
:       stx     turno
        cpx     #3
        beq     corte
        lda     apagar,x
        beq     :+
        dec     apagar,x
        bne     :+
        ldy     voz,x                   ; the release over: the waveform off
        lda     #0
        sta     SID+4,y
:       lda     forma,x
        cmp     #$40
        bne     fin                     ; not a pulse
        lda     fase_lo,x
        clc
        adc     paso_lo,x
        sta     fase_lo,x
        lda     fase_hi,x
        adc     paso_hi,x
        sta     fase_hi,x
        asl     a                       ; the triangle t
        bcc     :+
        eor     #$FF
:       sta     tmp1
        lda     #0
        sta     tmp2
        ldy     ancho,x
:       asl     tmp1
        rol     tmp2
        dey
        bne     :-
        ldy     voz,x
        lda     tmp1
        sta     SID+2,y
        lda     tmp2
        clc
        adc     base,x
        sta     SID+3,y
fin:    rts
corte:  lda     corte_hi
        sec
        sbc     #SUELO
        beq     fin                     ; at the floor
        sta     tmp1                    ; 8 (corte - SUELO)
        lda     #0
        asl     tmp1
        rol     a
        asl     tmp1
        rol     a
        asl     tmp1
        rol     a
        sta     tmp2
        lda     corte_lo
        sec
        sbc     tmp1
        sta     corte_lo
        lda     corte_hi
        sbc     tmp2
        sta     corte_hi
        sta     SID+22
        rts
.endproc

; ---- the 300 Hz interrupt ------------------------------------------------------------------------

; A = the profile (0 the introduction, 1 the ending): the voices' settings, the SID, the interrupt
.proc _musica_irq_on
        sei
        tax                             ; the profile's settings
        beq     :+
        ldx     #NPERFIL
:       ldy     #0
:       lda     perfiles,x
        sta     forma,y
        inx
        iny
        cpy     #NPERFIL - 1
        bne     :-
        lda     perfiles,x              ; the filter register
        sta     SID+23
        ldy     #2                      ; each voice: its AD, its LFO's phase (A 0, B 1/3, C 2/3 of a turn), its
:       ldx     voz,y                   ; width's base
        lda     ad,y
        sta     SID+5,x
        lda     #0
        sta     fase_lo,y
        sta     SID+2,x
        lda     fase_inicial,y
        sta     fase_hi,y
        lda     base,y
        sta     SID+3,x
        dey
        bpl     :-
        lda     #SUELO                  ; the filter at its floor
        sta     corte_hi
        sta     SID+22
        lda     #0
        sta     corte_lo
        sta     SID+21
        sta     turno
        lda     #$1F                    ; low-pass, volume 15
        sta     SID+24
        lda     $0314
        sta     viejo_irq
        lda     $0315
        sta     viejo_irq+1
        lda     #<irq
        sta     $0314
        lda     #>irq
        sta     $0315
        lda     #<3284                  ; 985248 / 300
        sta     $DC04
        lda     #>3284
        sta     $DC05
        lda     #%00010001              ; load and start, continuous
        sta     $DC0E
        cli
        rts
fase_inicial:
        .byte   $00, $55, $AA
.endproc

.proc _musica_irq_off
        sei
        lda     viejo_irq
        sta     $0314
        lda     viejo_irq+1
        sta     $0315
        lda     #<$4025                 ; the KERNAL's 60 Hz (PAL value)
        sta     $DC04
        lda     #>$4025
        sta     $DC05
        lda     #0
        sta     SID+4
        sta     SID+11
        sta     SID+18
        sta     SID+23                  ; no filter
        sta     SID+24
        cli
        rts
.endproc

.proc irq
        lda     $DC0D                   ; acknowledge CIA 1 (the KERNAL's work is not needed: the keyboard
                                        ; is read directly and the jiffy clock is not used)
        .repeat 8, i                    ; keep the shared zero page (unrolled: 84 cycles, not 194)
        lda     ptr1+i
        sta     guarda+i
        .endrep
        .repeat 4, i
        lda     tmp1+i
        sta     guarda+8+i
        .endrep
        inc     _musica_ticks
        bne     :+
        inc     _musica_ticks+1
:       jsr     _musica_tick
        jsr     sid_tick
        .repeat 8, i
        lda     guarda+i
        sta     ptr1+i
        .endrep
        .repeat 4, i
        lda     guarda+8+i
        sta     tmp1+i
        .endrep
        jmp     $EA81                   ; the KERNAL's end of interrupt: restore Y, X, A; RTI
.endproc
