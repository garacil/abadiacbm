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

; abadia64ks on tape: the turbo loader's core, at $033C (the KERNAL's cassette buffer, free once the KERNAL has
; loaded the first program).  A format of its own, written by cinta.py (c64/cinta/NOTAS.md):
;   a bit: one wave (CIA 1's FLAG fires once a wave): short (CORTO cycles) = 1, long (LARGO) = 0;
;   a byte: 8 bits, the most significant first;
;   a block: the pilot (PILOTO bytes), SINCRO, the header (id, address lo/hi, length lo/hi), the data, the
;     checksum (the XOR of the data bytes).
; A wave is told short or long by CIA 1's timer B in one-shot mode, restarted at every wave with UMBRAL cycles:
; still running at the next wave (bit 0 of the control register B) = short.  The caller keeps the interrupts off
; and the I/O visible ($01 = $35, $36 or $37).
;
;   $033C t_abre    A = a block's id: the tape motor on, the blocks read until that one; out: t_dir, t_cuenta
;   $033F t_byte    A = the block's next byte (X and Y kept; N, Z as A)
;   $0342 t_cierra  the rest of the block skipped, its checksum read: C = 1 bad; the motor off
;   $0345 t_carga   A = id: t_abre, the whole block at its address (not under the I/O), t_cierra
; The entries and the code run at every bit fill the cassette buffer; t_carga, t_cierra and resto (once a block) are
; at $02B0-$02FF, unused by the KERNAL; the variables at $02A8-$02AF; $02A7 holds the menu's options (cinta.inc).

        .include "cinta.inc"

CIA1_ICR  = $DC0D
CIA1_TBLO = $DC06
CIA1_TBHI = $DC07
CIA1_CRB  = $DC0F

quiere  = T_VARS + 0                    ; the id looked for
reg     = T_VARS + 1                    ; the bits coming in
id      = T_VARS + 2
suma    = T_VARS + 3                    ; the XOR of the data read
; t_dir = T_VARS + 4, t_cuenta = T_VARS + 6 (cinta.inc)

        .segment "TURBO"                ; at T_ABRE ($033C: turbo.cfg)
        jmp     t_abre
        jmp     t_byte
        jmp     t_cierra
        jmp     t_carga

        .segment "TURBO2"              ; at $02B0 (turbo.cfg): what runs once a block
.proc t_carga
        jsr     t_abre
        lda     t_dir
        sta     guarda+1
        lda     t_dir+1
        sta     guarda+2
lazo:   lda     t_cuenta
        ora     t_cuenta+1
        beq     t_cierra
        jsr     t_byte
guarda: sta     $FFFF                   ; (the address, set above)
        inc     guarda+1
        bne     lazo
        inc     guarda+2
        bne     lazo                    ; (never 0: no block reaches $FFFF)
.endproc

.proc t_cierra
        jsr     resto
        php
        lda     $01
        ora     #$20                    ; the motor off
        sta     $01
        plp
        rts
.endproc

; the rest of the block and its checksum: C = 1 bad
.proc resto
        lda     t_cuenta
        ora     t_cuenta+1
        beq     cuenta
        jsr     t_byte
        jmp     resto
cuenta: jsr     byte
        eor     suma
        cmp     #1                      ; C = 1 when not 0
        rts
.endproc

        .segment "TURBO"                ; what runs at every bit, at $033C after the entries

.proc t_abre
        sta     quiere
        lda     $01
        and     #$DF                    ; the motor on
        sta     $01
        lda     #$7F                    ; CIA 1's interrupts off (FLAG is read by polling)
        sta     CIA1_ICR
        lda     #<UMBRAL
        sta     CIA1_TBLO
        lda     #>UMBRAL
        sta     CIA1_TBHI
        lda     #$19                    ; timer B: one-shot, loaded, started
        sta     CIA1_CRB
sincro: jsr     bit                     ; the pilot: bits until the last 8 make PILOTO
        rol     reg
        lda     reg
        cmp     #PILOTO
        bne     sincro
piloto: jsr     byte                    ; then whole bytes: PILOTO..., SINCRO
        cmp     #PILOTO
        beq     piloto
        cmp     #SINCRO
        bne     sincro
        jsr     byte
        sta     id
        ldx     #0
:       jsr     byte                    ; the address and the length
        sta     t_dir,x
        inx
        cpx     #4
        bne     :-
        lda     #0
        sta     suma
        lda     id
        cmp     quiere
        beq     fin
        jsr     resto                   ; another block: skipped
        jmp     sincro
fin:    rts
.endproc

.proc t_byte
        jsr     byte
        pha
        eor     suma
        sta     suma
        lda     t_cuenta
        bne     :+
        dec     t_cuenta+1
:       dec     t_cuenta
        pla
        rts
.endproc

; A = a byte (8 bits, the most significant first)
.proc byte
        lda     #1
        sta     reg
:       jsr     bit
        rol     reg
        bcc     :-
        lda     reg
        rts
.endproc

; C = the next bit: 1 a short wave, 0 a long one
.proc bit
:       lda     CIA1_ICR
        and     #$10                    ; FLAG: a wave ended
        beq     :-
        lda     CIA1_CRB                ; bit 0: the one-shot timer still running
        lsr     a
        lda     #$19
        sta     CIA1_CRB                ; restarted for the next wave
        rts
.endproc
