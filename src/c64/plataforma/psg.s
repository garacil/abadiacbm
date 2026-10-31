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

; abadia64ks, the C64 platform layer: plat_psg, the CPC's sound chip (AY-3-8912) played on the SID.
;
; plat_psg: A = AY register 0-15, X = value.  A and X kept, Y clobbered; the interrupt flag is kept.  Needs the
; I/O visible ($01 = $35).  Registers 6-15 run with the interrupts off (PHP / SEI / PLP: the main code writes the
; mixer too, snd_silence_all and the pause).  The tone registers 0-5 do not: the game writes them only from the
; 300 Hz interrupt (snd_channel_output), the hot path (a period nearly every tick while a sound plays); a write
; of them from the main code would have to come with the interrupts off.  psg_inicio: the SID and this state at
; rest (plat_inicio calls it; the state is BSS, which the loader does not load).
;
; Each AY channel is a SID voice (A -> voice 1, B -> 2, C -> 3).  The notes and their timing are the AY's: the
; same frequencies, a voice gated and released on the same register writes as the AY's tone starts and stops; the
; voicing is the SID's (c64/optimizacion/sid/NOTAS.md):
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
;     tone on -> triangle (a recorder; the footsteps: pulse), else the voice stops (its waveform 0: the 6581 lets a silent voice's running waveform
;     through; a release before it comes from the volume, below);
;   the pulse's width moves at each tone period written (the music's vibrato writes one every 4 ticks, the
;     footsteps every 2): a phase + PASO, its triangle t (0-255), the low byte of the width: $500 + t (31 % - 37.5 %)
;     on voice 3 (the music, the footsteps, the beep), $600 + t (37.5 % - 44 %) on voices 1 and 2 (the bells, the
;     objects); voice 3 sounds through the SID's low-pass filter (cut-off FILTRO, resonance 8): sid_inicial;
;   volume (registers 8-10, 0-15) -> the SID envelope's sustain level (the AY's logarithmic levels, MAME's
;     table, x 15, at least 1): attack 24 ms, decay 72 ms, release 72 ms (RATE: one rate, the SID's envelope delay bug
;     never comes in, a gate is heard at once); a lower volume lowers the sustain level (the SID decays to it), a
;     higher one gates the voice again (it rises to the top and decays to the new level), 0 releases it (the
;     waveform kept: the release fades the note out instead of the AY's cut);
;   registers 11-13 (the hardware envelope; the volume's bit 4) and 14-15 (ports): not used by the game (no
;     volume envelope of its sound data has an 8xh entry): ignored.
;
; psg_paso (the footsteps at half; the game's s_canal_c calls it at every start on
; channel C, with the interrupts off): Z = 1, channel C starts the footstep; Z = 0, anything else.  The footstep's
; volume rises 0 -> 12 a step a tick and falls back the same way: gated again at each rise (the rule above) the
; SID stays at its attack's top through the whole rise, which made the footsteps as loud as anything.  As the
; footstep, voice 3 is released at its start and gated once, at its first volume (pon_volumen or actualiza, when
; the mixer turns it on), with the sustain level 4: the attack's 8 ms to the top, the decay to a quarter of it, no
; gate again on the rises; a fall sets half the usual sustain level.  The rates stay every voice's (attack, decay
; and release with one period: the SID's envelope delay bug never comes in), so the attack's top stays; its decay
; and the lower plateau make the footstep half as loud, measured (voice 3's envelope from VICE's SID writes, its
; RMS over the footstep: c64/juego_final/vice/pasos.py).  A clobbered, X and Y kept.
; The idle melody (A = F9h, its restored loop opcode): voice 3 filtered without resonance; the other sounds on voice
; 3 with resonance 8.  Every tone is the triangle with RATE's envelope (before, the pulse, 8 / 24 ms: a hard
; strike at each note's start, like a hard blow on the note when it comes); the footsteps keep their
; pulse and their envelope.

        .include "plat64.inc"
        .export plat_psg, plat_psg_tono, psg_inicio, psg_paso
.if .defined(CINTA) || .defined(C128) || .defined(DISCO)
        .export plat_opciones
.endif

; 2^24 * 62500 / 985248: the SID frequency of the AY period 1 (PAL)
K_FREC  = 1064277
PASO    = 3                             ; the pulse width's phase step a period written: the music's sweep ~1.1 s
FILTRO  = $50                           ; the low-pass cut-off of voice 3 (bits 3-10): ~3 kHz on a 6581, ~5 on an 8580

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
fase:   .res 1                          ; the pulse width's phase
paso:   .res 3                          ; 0 normal, 1 footstep, 80h idle flute (channel C only)
estado_fin:
mezcla: .res 1                          ; the mixer as written
valor:  .res 1                          ; the value of the write being done
p_lo:   .res 1                          ; the period being converted
p_hi:   .res 1
f_lo:   .res 1                          ; its SID frequency
f_hi:   .res 1

.if .defined(CINTA) || .defined(C128) || .defined(DISCO)
.segment "DATA"
plat_opciones: .byte 0                  ; the menu's options (the tape's c64/cinta/cinta.inc, the C128 disk's
                                        ; c64/disco128/disco128.inc), written by the loader; plat_final passes
                                        ; the language on to the ending
.endif
; the tones' envelope (no hard blow on the note when it comes; the sound of a recorder):
; one rate for the attack, the decay and the release (the SID's envelope delay bug never comes in): 3 = 24 ms up,
; 72 ms down (it was 1: 8 / 24 ms, the hard strike at each note's start)
RATE    = $33
.segment "BAJO"                       ; the nine constant bytes fit below the game's code
voz:    .byte   0, 7, 14
bit_canal: .byte 1, 2, 4, 8, 16, 32     ; the mixer's tone bits (0-2) and noise bits (3-5) of each channel
.segment "RODATA"
; the SID's sustain level of each AY volume (x 16) and the release (24 ms): the SR register
sostenido:
        .byte   $03, $13, $13, $13, $13, $13, $13, $23, $33, $43, $53, $73, $93, $A3, $D3, $F3
; the SID at rest, register by register: the voices silent, the widths' high bytes, attack 24 ms and decay 72 ms
; (RATE); the filter
sid_inicial:
        .byte   0, 0, 0, $06, 0, RATE, 0
        .byte   0, 0, 0, $06, 0, RATE, 0
        .byte   0, 0, 0, $05, 0, RATE, 0
        .byte   0, FILTRO, $84, $1F     ; cut-off, resonance 8 | voice 3 filtered, low-pass | volume 15
; 1064277 / m for m = 128, 130, ... 256, rounded
t_lo:   .repeat 65, i
        .byte   <((2 * K_FREC + 128 + 2 * i) / (2 * (128 + 2 * i)))
        .endrep
t_hi:   .repeat 65, i
        .byte   >((2 * K_FREC + 128 + 2 * i) / (2 * (128 + 2 * i)))
        .endrep

.segment "CODE"

; plat_psg's registers 6-15 (before it: its branch here is backward, the tone path falls through)
.proc otros
        php                             ; registers 6-15: with the interrupts off
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

ruido:  lda     valor                   ; period 16 N (N = 0 as 1)
        and     #$1F
        bne     :+
        lda     #1
:       pha
        asl     a
        asl     a
        asl     a
        asl     a
        sta     p_lo
        pla
        lsr     a
        lsr     a
        lsr     a
        lsr     a
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
grueso: stx     valor
        jsr     tono
        ldx     valor
        tya                             ; A = the register (2 c + 1)
        sec
        rol     a
        rts
.endproc

; plat_psg_tono (the speed work's round 5, SND-1: the game's snd_channel_output, the hot path): a channel's tone
; period at once, as plat_psg's two writes (the fine register, then the coarse one: the game's order): Y = the fine
; register (0, 2, 4), A = its value, X = the coarse register's value; A, X, Y clobbered
.proc plat_psg_tono
        pha
        tya
        lsr     a
        tay                             ; the channel
        pla
        sta     per_lo,y
        txa
.endproc
; the coarse byte A of channel Y: the period P = (coarse & 0Fh) : fine -> frec of the channel, to the SID when it
; sounds a tone (Y kept)
.proc tono
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
grande: sta     p_hi                    ; the other periods: convierte
        lda     per_lo,y
        sta     p_lo
        jsr     convierte
        jmp     convertido
pequeno:
        jsr     convierte_bajo          ; (A = P)
convertido:
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
        beq     listo                   ; (silent)
        bmi     listo                   ; (noise: its own frequency)
        ldx     voz,y
        lda     frec_lo,y
        SID_STA 0, x
        lda     frec_hi,y
        SID_STA 1, x
        lda     fase                    ; the pulse width's step: the phase + PASO
        adc     #PASO                   ; (+ C, either)
        sta     fase
        asl     a                       ; its triangle t = 0-255
        bcc     :+
        eor     #$FF
:
        SID_STA 2, x                    ; the width's low byte (its high byte: sid_inicial)
listo:  rts
.endproc

; the voice of channel Y after a mixer write: its waveform from the mixer, the gate as the volume says
.proc actualiza
        ldx     #$80                    ; noise on: the noise
        lda     mezcla
        and     bit_canal+3,y
        beq     nueva
        ldx     #$10                    ; tone on: the triangle (the recorder), but the
        lda     paso,y                  ; footstep's pulse as it always was (paso = 1)
        cmp     #1
        bne     :+
        ldx     #$40
:       lda     mezcla
        and     bit_canal,y
        beq     nueva
        ldx     #0                      ; neither: silent
nueva:  txa
        cmp     onda,y
        beq     fin
        sta     onda,y
        tax
        beq     suelta                  ; off: the voice stopped
        jsr     pon_frecuencia          ; (X = the voice)
        lda     puerta,y
        bne     :+                      ; sounding: the new waveform, the envelope goes on
        lda     volumen,y
        beq     fin                     ; volume 0: stays silent
        lda     #1
        sta     puerta,y
:       lda     onda,y
        ora     #1
        SID_STA 4, x
fin:    rts
.endproc

; channel Y: volume valor & 15
.proc pon_volumen
        lda     valor
        and     #$0F
        cmp     volumen,y               ; C = 1: not lower (kept to the BCC below: no other op sets it)
        beq     fin
        sta     volumen,y
        tax
        lda     paso,y
        beq     :+
        bmi     :+                      ; flute keeps the normal envelope, not the footstep's attenuation
        jmp     paso_c                  ; the footstep: its own rule (psg_paso)
:       lda     sostenido,x
        ldx     voz,y
        SID_STA 6, x
        lda     onda,y
        beq     fin                     ; silent: kept for when it sounds
        lda     volumen,y
        beq     suelta
        lda     puerta,y
        beq     puerta_on               ; released: gate it
        bcc     fin                     ; lower: the SID decays to the new sustain level
puerta_on:
        lda     onda,y                  ; higher: gate again
        SID_STA 4, x
        ora     #1
        SID_STA 4, x
        lda     #1
        sta     puerta,y
fin:    rts
.endproc

; channel Y: volume 0: the gate off with the waveform kept (its release, 24 ms); the mixer turning it off (onda = 0):
; the waveform 0 too, gated or not (the voice stopped: a 6581 lets the tone of a voice at the envelope's zero through,
; ~35 dB down, while its waveform runs; the game turns a channel off by the mixer once its sound has ended)
.proc suelta
        ldx     voz,y
        lda     puerta,y
        bne     :+
        lda     onda,y                  ; not gated: a stopped voice's waveform off
        bne     fin
:       lda     onda,y
        SID_STA 4, x
        lda     #0
        sta     puerta,y
fin:    rts
.endproc

; channel Y: its frequency (tone or noise, by its waveform) to its SID voice.  Out: X = the voice.
.proc pon_frecuencia
        ldx     voz,y
        lda     onda,y
        bmi     :+
        lda     frec_lo,y
        SID_STA 0, x
        lda     frec_hi,y
        SID_STA 1, x
        rts
:       lda     ruido_lo
        SID_STA 0, x
        lda     ruido_hi
        SID_STA 1, x
        rts
.endproc

; convierte: p_hi:p_lo (0-4095) -> f_hi:f_lo = 1064277 / P (P < 17: $FFFF); convierte_bajo: the same for A = P
; (0-127: the tone periods of the music and the beep, without p_hi:p_lo).  Y kept.
.proc convierte_bajo
        sty     guarda_y
        ldy     #0
bajo:   cmp     #17
        bcc     tope
:       iny                             ; P << k into 128-254
        asl     a
        bpl     :-
tabla_k:
        jsr     tabla
izq:    dey                             ; f << k
        bmi     fin
        asl     f_lo
        rol     f_hi
        jmp     izq
tope:   lda     #$FF
        sta     f_lo
        sta     f_hi
        bne     fin
::convierte:
        sty     guarda_y
        ldy     #0
        lda     p_hi
        bne     grande
        lda     p_lo
        bpl     bajo                    ; 0-127 (Y = 0)
        bmi     tabla_k                 ; 128-255: from the table (k = 0)
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

.proc psg_paso
        bne     otro
        lda     onda+2                  ; the footstep: voice 3 released, so that it gates once, at its first volume
        SID_STA 14+4
        lsr     puerta+2
        lda     #1
        bne     elegido
otro:   cmp     #$F9                    ; s_canal_c restores this opcode only for the idle music
        bne     normal
        lda     #$80
        bne     elegido
normal: lda     #0
elegido:
        sta     paso+2
        cmp     #1                      ; voice 3's attack and decay: the footstep's 8 / 24 ms (its own rule,
        beq     :+                      ; paso_c), every other sound's RATE (X and Y kept: the callers need them)
        lda     #RATE
        .byte   $2C                     ; (BIT abs: skips the LDA)
:       lda     #$11
        SID_STA 14+5
        lda     paso+2
        and     #$80
        eor     #$80
        ora     #$04                    ; flute has no resonance; other C sounds retain resonance 8
        SID_STA $17
        txa
        pha
        tya
        pha
        ldy     #2
        jsr     actualiza               ; update a running voice even if its AY mixer is unchanged
        pla
        tay
        pla
        tax
        rts
.endproc

.ifdef P500
.segment "CODE"                         ; (the P500: its SID macros make it longer than BAJO's room)
.else
.segment "BAJO"
.endif
; pon_volumen for the footstep (channel C): X = its new volume, C = 1 a rise.  A rise: the sustain level 4 (a
; quarter of the top); released and sounding: gated (no gate again while gated: its attack and decay go on).  A fall: half the
; usual sustain level (the envelope decays to it); 0 releases it.
.proc paso_c
        bcs     sube
        lda     sostenido,x
        lsr     a
        and     #$F0
        ora     #$01                    ; (the release 24 ms)
        SID_STA 14+6
        txa
        bne     fin
        jmp     suelta
sube:   lda     #$41
        SID_STA 14+6
        lda     puerta+2
        bne     fin
        lda     onda+2
        beq     fin                     ; silent: actualiza gates it when the mixer turns it on
        ldx     #14
        jmp     pon_volumen::puerta_on
fin:    rts
.endproc

.segment "CODE"

.proc psg_inicio
        ldx     #24                     ; the SID: every register (sid_inicial)
:       lda     sid_inicial,x
        SID_STA 0, x
        dex
        bpl     :-
        lda     #0
        ldx     #estado_fin - per_lo - 1 ; the whole state: the periods and frequencies too (BSS: the loader does
:       sta     per_lo,x                ; not load it, so pon_frecuencia must never find leftovers there)
        dex
        bpl     :-
        lda     #$3F                    ; the AY's mixer at rest: all off
        sta     mezcla
        rts
.endproc

.segment "BSS"
guarda_y: .res 1
