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
; in turn), every fifth tick the KERNAL's keyboard scan (SCNKEY, $EA87: 60 times a second, as the KERNAL's own
; interrupt does it), and returns through the KERNAL's register restore ($EA81), without the rest of the KERNAL's
; interrupt (its clock and cursor: not needed; the whole of it after a tick would make some ticks long enough to
; lose the next); the zero page the C runtime and the drawing share (ptr1-ptr4, tmp1-tmp4) is kept.
;
; This is c64/pergamino/sid.s with the keyboard scan added (c64/presentacion/NOTAS.md): the parchment reads the
; keys with conio's kbhit and cgetc, which take them from the KERNAL's keyboard buffer, filled by that scan.

        .export _musica_registro, _musica_irq_on, _musica_irq_off, _musica_ticks, sid_tick
        .import _musica_tick
        .importzp ptr1, ptr2, ptr3, ptr4, tmp1, tmp2, tmp3, tmp4

SID = $D400

; SIDW reg[, x|y]: STA SID + reg (,X / ,Y).  On the C64 and the C128 that plain instruction; on the P500 (cc65's cbm510
; target) the SID is in bank 15 ($DA00, cc65's zero-page pointer `sid`): PHP, SEI, the value into sid_a, LDA #reg, JSR
; to sidw_k / _x / _y (STA (sid),Y with the 6509's indirect bank register IndReg = 15, then the execution bank's
; again), PLP: A, X, Y and the flags kept (c64/discop500/NOTAS.md)
.ifdef __CBM510__
        .include "cbm510.inc"           ; ExecReg, IndReg
        .importzp sid, cia2, tpi1
.macro SIDW reg, ind
        php
        sei
        sta     sid_a
        lda     #reg
  .if .xmatch({ind}, {x})
        jsr     sidw_x
  .elseif .xmatch({ind}, {y})
        jsr     sidw_y
  .else
        jsr     sidw_k
  .endif
        plp
.endmacro
.else
.macro SIDW reg, ind
  .if .xmatch({ind}, {x})
        sta     SID + reg, x
  .elseif .xmatch({ind}, {y})
        sta     SID + reg, y
  .else
        sta     SID + reg
  .endif
.endmacro
.endif
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
teclado:  .res 1                ; ticks left to the next keyboard scan
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
        SIDW    0, x
        lda     coc+1
        SIDW    1, x
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
        SIDW    5, x
        stx     tmp2
        ldx     vol,y
        lda     sostenido,x
        asl     a
        asl     a
        asl     a
        asl     a
        ora     rel,y
        ldx     tmp2
        SIDW    6, x                 ; sustain, the voice's release
        lda     forma,y                 ; the voice's waveform, gate off
        SIDW    4, x
        ora     #1                      ; gate on
        SIDW    4, x
        lda     #1
        sta     sonando,y
        lda     #0
        sta     apagar,y                ; (a release in course: not to be cut)
        cpy     filtro
        bne     :+
        lda     #PICO                   ; the filter opens
        sta     corte_hi
        SIDW    22
        lda     #0
        sta     corte_lo
:       rts
.endproc

.proc suelta
        lda     sonando,y
        beq     :+
        ldx     voz,y
        lda     forma,y                 ; the gate off, the waveform kept: the release
        SIDW    4, x
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
        SIDW    6, x
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
        SIDW    4, y
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
        SIDW    2, y
        lda     tmp2
        clc
        adc     base,x
        SIDW    3, y
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
        SIDW    22
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
        SIDW    23
        ldy     #2                      ; each voice: its AD, its LFO's phase (A 0, B 1/3, C 2/3 of a turn), its
:       ldx     voz,y                   ; width's base
        lda     ad,y
        SIDW    5, x
        lda     #0
        sta     fase_lo,y
        SIDW    2, x
        lda     fase_inicial,y
        sta     fase_hi,y
        lda     base,y
        SIDW    3, x
        dey
        bpl     :-
        lda     #SUELO                  ; the filter at its floor
        sta     corte_hi
        SIDW    22
        lda     #0
        sta     corte_lo
        SIDW    21
        sta     turno
        lda     #$1F                    ; low-pass, volume 15
        SIDW    24
.ifdef __CBM510__
        jmp     irq500_on               ; the P500: the 6526's timer A through TPI 1, cc65's interruptor (below)
.endif
        lda     #5                      ; the first keyboard scan in 5 ticks
        sta     teclado
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
.ifdef __C128__
        lda     #0                      ; the C128: the raster's interrupt (its KERNAL's jiffy) masked, CIA 1's timer
        sta     $D01A                   ;   A's on (see irq)
        lda     #$FF
        sta     $D019
        lda     #$81
        sta     $DC0D
.endif
        cli
        rts
fase_inicial:
        .byte   $00, $55, $AA
.endproc

.proc _musica_irq_off
        sei
.ifdef __CBM510__
        jsr     irq500_off
        jmp     silencio
.endif
        lda     viejo_irq
        sta     $0314
        lda     viejo_irq+1
        sta     $0315
.ifdef __C128__
        lda     #$01                    ; the C128: CIA 1's timer A interrupt off, the raster's back
        sta     $DC0D
        lda     $DC0D
        lda     #$01
        sta     $D01A
.else
        lda     #<$4025                 ; the KERNAL's 60 Hz (PAL value)
        sta     $DC04
        lda     #>$4025
        sta     $DC05
.endif
::silencio:
        lda     #0
        SIDW    4
        SIDW    11
        SIDW    18
        SIDW    23                  ; no filter
        SIDW    24
        cli
        rts
.endproc

.ifdef __C128__
; The C128 (abadia128ks): its KERNAL's jiffy interrupt is the VIC-II's raster at line 255, not CIA 1's timer A
; ("Mapping the Commodore 128", SCNIRQ $C194): the music's 300 Hz is CIA 1's timer A as on the C64, the raster's
; interrupt masked meanwhile (_musica_irq_on / _musica_irq_off).  Every interrupt comes through the KERNAL's JIRQ
; ($FF17: A, X, Y and the MMU's configuration pushed, bank 15 set, JMP ($0314)) and leaves through its common exit
; $FF33; bank 15 shows the RAM only below $4000, so the entry is in LOWCODE (low, after the start-up) and maps
; cc65's configuration ($0E: the RAM up to $BFFF) first.  The keyboard scan: SCNKEY through its jump table, $FF9F.
.segment "LOWCODE"
irq:    lda     #$0E
        sta     $FF00
        jmp     irq_cuerpo
.segment "CODE"
.proc irq_cuerpo
.else
.proc irq
.endif
        lda     $DC0D                   ; acknowledge CIA 1 (of the KERNAL's work only the keyboard scan is
                                        ; done, below; the jiffy clock is not used)
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
        dec     teclado                 ; every fifth tick: the KERNAL's keyboard scan (conio's kbhit, cgetc)
        bne     :+
        lda     #5
        sta     teclado
.ifdef __C128__
        jsr     $FF9F                   ; SCNKEY
.else
        jsr     $EA87                   ; SCNKEY
.endif
:
        .repeat 8, i
        lda     guarda+i
        sta     ptr1+i
        .endrep
        .repeat 4, i
        lda     guarda+8+i
        sta     tmp1+i
        .endrep
.ifdef __C128__
        jmp     $FF33                   ; the KERNAL's common exit: the MMU's configuration, Y, X, A; RTI
.else
        jmp     $EA81                   ; the KERNAL's end of interrupt: restore Y, X, A; RTI
.endif
.endproc

.ifdef __CBM510__
; ---- the P500 (cc65's cbm510 target) ---------------------------------------------------------------------------
; The 300 Hz tick: the 6526 ($DC00, bank 15: cc65's pointer `cia2`) timer A, its interrupt through TPI 1's input 2 (its
; mask, register 5, bit 2: cc65's tpi1); cc65's interrupt handler (crt0.s: in bank 0, IndReg = ExecReg) calls irq500
; (an interruptor) at every interrupt and, after it, serves TPI 1 itself (the 50 Hz one: its keyboard scan for conio,
; and the active interrupt register written back): irq500 reads the 6526's flags (which clears them) and, on timer A,
; ends TPI 1's interrupt of it and reads the 6526 again (the order of plataforma/interrupcion500.s plat_irq), then does
; the tick (_musica_tick, sid_tick) with the shared zero page kept; the carry clear (cc65's handler goes on).
.interruptor irq500

.proc irq500_on
        lda     #$0F
        sta     IndReg
        ldy     #$04
        lda     #<3284                  ; 985248 / 300
        sta     (cia2),y
        iny
        lda     #>3284
        sta     (cia2),y
        ldy     #$0E
        lda     #%00010001              ; load and start, continuous
        sta     (cia2),y
        ldy     #$0D
        lda     (cia2),y                ; (old flags cleared)
        lda     #$81                    ; its interrupt on
        sta     (cia2),y
        ldy     #$05
        lda     (tpi1),y
        ora     #$04                    ; TPI 1: the 6526's input unmasked
        sta     (tpi1),y
        lda     ExecReg
        sta     IndReg
        lda     #1
        sta     activa500
        cli
        rts
.endproc

.proc irq500_off
        lda     #0
        sta     activa500
        lda     #$0F
        sta     IndReg
        ldy     #$0D
        lda     #$01                    ; the 6526's timer A interrupt off
        sta     (cia2),y
        lda     (cia2),y
        ldy     #$0E
        lda     #0
        sta     (cia2),y
        lda     ExecReg
        sta     IndReg
        rts
.endproc

.proc irq500
        lda     activa500
        bne     :+
        jmp     no
:
        lda     #$0F
        sta     IndReg
        ldy     #$0D
        lda     (cia2),y                ; the 6526's flags (read: cleared, its line up)
        lsr     a
        bcs     :+
        ldx     ExecReg
        stx     IndReg
        jmp     no                      ; not timer A
:       ldy     #$07                    ; TPI 1's interrupt of the 6526 ended here (cc65's handler then finds no
        lda     (tpi1),y                ;   active one, or the 50 Hz one, which it serves), and the 6526 read again:
        cmp     #$04                    ;   an underflow between the two reads, whose interrupt TPI 1 has just
        bne     :+                      ;   ended, would leave its line down for ever (the music stopped); this read
        sta     (tpi1),y                ;   puts it up (that one tick is lost)
        ldy     #$0D
        lda     (cia2),y
:       ldx     ExecReg
        stx     IndReg
        .repeat 8, i                    ; keep the shared zero page
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
no:     clc
        rts
.endproc

; cc65's keyboard buffer emptied (presentacion.c musicstart: the keys pressed before the parchment do not end it)
.export _teclas500_vacia
.importzp keyidx
_teclas500_vacia:
        lda     #0
        sta     keyidx
        rts

; SIDW's writes: A = the register, sid_a the value; X or Y the index (_x, _y).  A = sid_a after, X and Y kept
sidw_x: sty     sid_y
        stx     sid_t
        clc
        adc     sid_t
        tay
        jmp     sidw_cola
sidw_y: sty     sid_y
        sty     sid_t
        clc
        adc     sid_t
        tay
        jmp     sidw_cola
sidw_k: sty     sid_y
        tay
sidw_cola:
        lda     #$0F
        sta     IndReg
        lda     sid_a
        sta     (sid),y
        lda     ExecReg
        sta     IndReg
        lda     sid_a
        ldy     sid_y
        rts

.segment "BSS"
sid_a:  .res    1
sid_y:  .res    1
sid_t:  .res    1
activa500: .res 1
.endif
