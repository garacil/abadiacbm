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


; abadia128ks on the P500, the last stage of the game's loading (c64/discop500/NOTAS.md), at $0200-$0FFF of bank 1
; (below the game's bank 1 data, $1000 on).  The presentation's loader (c64/presentacion/carga500.s) has put into bank
; 1 with the KERNAL: the game's bank 1 (B, $1000), its bank 0 crunched by Exomizer (J, ending at J_FIN) and, for
; English, the bytes the English image has different (E, at B1_INGLES); it copied this stage here, wrote the menu's
; options and the drive into its first bytes, held every interrupt off (the 6526's off, TPI 1's mask 0) and moved the
; CPU to bank 1 at its start ($FFF6: STA $00 in bank 0, JMP here at bank 1's $FFF8).
; Here, in bank 1 (its own zero page and stack): the display blanked; J decrunched by Exomizer's own decruncher
; (exodecrunch.s): its literal bytes read here in bank 1 (get_crunched_byte), its copies and its output written to bank
; 0 by LDA / STA (zp),Y, the 6509's two cross-bank instructions, with the indirect bank register $01 = 0; the English
; bytes; the options (plat_opciones, plat_unidad; the footsteps', the text's and the Ave Maria's calls 3 NOPs when
; turned off); the Ave Maria's samples (AVE) into bank 1 with the KERNAL when option 4 is on (the KERNAL's own
; cross-bank call, as the game's plataforma/p500.s k15, coming back to bank 1); then the game: bank 0's $FFF8 = JMP
; principal_inicio, and $FFF6 (STA $00 in both banks) moves the CPU to bank 0.  A load error flashes the border.

        .include "disco500.inc"         ; OPC_INGLES, OPC_SIN_PASOS, OPC_SIN_TEXTO, OPC_SIN_AVE
        .include "juego500_gen.inc"             ; J_FIN, B1_INGLES, the game's labels (piezas500.py)
        .export get_crunched_byte
        .import decrunch

IND     = $01                           ; the 6509's indirect bank register
EXEC    = $00                           ; its execution bank register
PTR     = $F0                           ; 2: a pointer for (zp),Y ($F0-$F3: not exodecrunch.s's)
K_P1    = $F2                           ; 2: $0100 (bank 15's stack page)
K_EXCRTS = $FEFE                        ; the KERNAL's way back (bank 15)
K_EXPULL = $FF26                        ; its register pull (bank 15, and here in bank 1)
K_CAMBIA = $FFF6                        ; STA $00 / RTS (bank 15; here and in bank 0 written below)
K_LOAD  = $FFD5
FNAM    = $90                           ; the KERNAL's zero page (bank 15): the name's address and bank, its length,
FNAM_LEN = $9D                          ;   the logical file, the device, the secondary address (SETNAM $FB40,
LA      = $9E                           ;   SETLFS $FB4F write them so)
FA      = $9F
SA      = $A0

.segment "CODE"
        jmp     inicio
opciones: .byte 0                       ; ($0203, $0204: written by carga500.s)
unidad: .byte   8
        jmp     final                   ; ($0205: the game's plat_final, at its end: "FINAL", below)

inicio: sei
        cld
        ldx     #$FE                    ; (the stack below $01FF: the KERNAL's way back uses it)
        txs
        lda     #<nada                  ; bank 1's NMI and IRQ vectors: an RTI (no source is on)
        sta     $FFFA
        sta     $FFFE
        lda     #>nada
        sta     $FFFB
        sta     $FFFF
        lda     #$0B                    ; the display blanked (bitmap mode kept): VIC-II $D811, bank 15
        ldx     #<$D811
        ldy     #>$D811
        jsr     pon15
        lda     #0
        sta     IND                     ; the cross-bank accesses to bank 0
        lda     #<J_FIN
        sta     fuente
        lda     #>J_FIN
        sta     fuente + 1
        jsr     decrunch
        lda     opciones
        and     #OPC_INGLES
        beq     opc
; the English bytes: records (address lo, address hi, length 1-255, the bytes), ended by an address 0: bank 0's, then
; bank 1's
        lda     #0
        jsr     ingles
        lda     #1
        jsr     ingles
; the options
opc:    ldy     #0
        sty     IND
        lda     #<J_PLAT_OPCIONES
        sta     PTR
        lda     #>J_PLAT_OPCIONES
        sta     PTR + 1
        lda     opciones
        sta     (PTR),y
        lda     #<J_PLAT_UNIDAD
        sta     PTR
        lda     #>J_PLAT_UNIDAD
        sta     PTR + 1
        lda     unidad
        sta     (PTR),y
        lda     opciones
        and     #OPC_SIN_PASOS
        beq     :+
        ldx     #<J_PASO                ; the footstep's note a rest: played as before, silent (objetos_sonido.s)
        ldy     #>J_PASO
        jsr     silencio
:       lda     opciones
        and     #OPC_SIN_TEXTO
        beq     :+
        ldx     #<J_PITIDO              ; the beep's note, the same
        ldy     #>J_PITIDO
        jsr     silencio
:       lda     opciones
        and     #OPC_SIN_AVE
        bne     sin_ave
        jsr     prepara_k
        lda     #>nombre_ave
        sta     nombre_hi
        ldx     #<nombre_ave
        lda     #nombre_ave_fin - nombre_ave
        jsr     nombre
        lda     #1                      ; LOAD: into bank 1 (the game's ave_muestra, the file's own address)
        jsr     carga
        bcc     juego
sin_ave:
        ldx     #<J_AVE                 ; the Ave Maria's call (option 4 off, or a load error)
        ldy     #>J_AVE
        jsr     nops
; the game: bank 0's $FFF6-$FFFA = STA $00, JMP principal_inicio; the switch from bank 1's $FFF6
juego:  lda     #0
        sta     IND
        lda     #<$FFF6
        sta     PTR
        lda     #>$FFF6
        sta     PTR + 1
        ldy     #4
:       lda     salto,y
        sta     (PTR),y
        dey
        bpl     :-
        lda     #$85                    ; bank 1's $FFF6: STA $00
        sta     K_CAMBIA
        lda     #$00
        sta     K_CAMBIA + 1
        lda     #0                      ; bank 0
        jmp     K_CAMBIA
salto:  .byte   $85, $00, $4C, <J_PRINCIPAL_INICIO, >J_PRINCIPAL_INICIO

nada:   rti

; A into the register X/Y of bank 15 (the I/O); $01 = 0 after.  A, Y clobbered
.proc pon15
        stx     PTR
        sty     PTR + 1
        ldy     #15
        sty     IND
        ldy     #0
        sta     (PTR),y
        sty     IND
        rts
.endproc

; the note at X/Y of bank 0 a rest (0Fh)
.proc silencio
        stx     PTR
        sty     PTR + 1
        ldy     #0
        sty     IND
        lda     #$0F
        sta     (PTR),y
        rts
.endproc

; 3 NOPs at X/Y of bank 0
.proc nops
        stx     PTR
        sty     PTR + 1
        lda     #0
        sta     IND
        lda     #$EA
        ldy     #2
:       sta     (PTR),y
        dey
        bpl     :-
        rts
.endproc

; E's records for bank A (0 or 1), from `ing` on
.proc ingles
        sta     banco
reg:    jsr     lee1                    ; the address
        sta     PTR
        jsr     lee1
        sta     PTR + 1
        ora     PTR
        beq     fin
        jsr     lee1                    ; the length
        tax
        lda     banco
        sta     IND
        ldy     #0
:       jsr     lee1
        sta     (PTR),y
        iny
        dex
        bne     :-
        beq     reg
fin:    rts
.endproc

; A = the next byte of E (bank 1, here: a plain read); X, Y kept
.proc lee1
ing = * + 1
        lda     B1_INGLES
        inc     ing
        bne     :+
        inc     ing + 1
:       rts
.endproc

; the previous crunched byte (backwards from `fuente`, bank 1), for exodecrunch.s: X, Y and the carry kept
get_crunched_byte:
        lda     fuente
        bne     :+
        dec     fuente + 1
:       dec     fuente
fuente = * + 1
        lda     $FFFF
        rts

; ---- the KERNAL's LOAD from here (bank 1) ------------------------------------------------------------------
; The KERNAL's cross-bank call from bank 1 (plataforma/p500.s's k15, coming back to bank 1): bank 1's $FF26 (PLA TAY
; PLA TAX PLA PLP RTS) and $FFF6 (STA $00 / RTS) as in bank 15 (prepara_k); bank 1's $01FF the stack pointer for the
; way back (the stack starts at $01FE).  The KERNAL's zero page written directly (FNAM, LA, FA, SA).
.proc prepara_k
        ldx     #expull_fin - expull - 1
:       lda     expull,x
        sta     K_EXPULL,x
        dex
        bpl     :-
        lda     #$85
        sta     K_CAMBIA
        lda     #$00
        sta     K_CAMBIA + 1
        lda     #$60
        sta     K_CAMBIA + 2
        lda     #<$0100
        sta     K_P1
        lda     #>$0100
        sta     K_P1 + 1
        rts
expull: pla
        tay
        pla
        tax
        pla
        plp
        rts
expull_fin:
.endproc

; the file name at X / nombre_hi (bank 1), A bytes
.proc nombre
        pha
        txa
        ldy     #FNAM
        jsr     pon_kzp
        pla
        ldy     #FNAM_LEN
        jsr     pon_kzp
        lda     nombre_hi
        ldy     #FNAM + 1
        jmp     pon_kzp
.endproc

; LOAD into bank A at the file's own address: the name's bank this one, the file 1 on the drive `unidad`, secondary
; address 0; C = 1 on an error
.proc carga
        pha
        lda     #1
        ldy     #FNAM + 2
        jsr     pon_kzp
        ldy     #LA
        jsr     pon_kzp
        lda     unidad
        ldy     #FA
        jsr     pon_kzp
        lda     #0
        ldy     #SA
        jsr     pon_kzp
        pla
        ldx     #$FF
        ldy     #$FF
        clc
        jsr     k15
        sei
        rts
.endproc

; ---- the ending: "FINAL" (a cc65 program for the P500, c64/presentacion final.c) into bank 0, started ------------
; Entered from the game's plat_final at $0205, every interrupt source off, the options at $0203: the program loaded
; with the KERNAL over the game; the options at bank 1's FINAL_OPCIONES for it (c64/presentacion/final500.s reads
; them); TPI 1's mask as the KERNAL's reset leaves it ($FF: cc65's runtime takes the 50 Hz interrupt for its
; keyboard); then as BASIC's SYS 256 into cc65's BASIC header's code: the stack pointer the system keeps ($F:01FF),
; and here at $0100 SEI, LDA #0, STA $00, which moves the CPU to bank 0 at $0105 (cc65's start-up: a JMP to its
; start).  Never returns; a load error tries again, the border changing.
final:  sei
        cld
        ldx     #$FE
        txs
        lda     #<nada
        sta     $FFFA
        sta     $FFFE
        lda     #>nada
        sta     $FFFB
        sta     $FFFF
        lda     opciones
        sta     FINAL_OPCIONES
        jsr     prepara_k
otra:   lda     #>nombre_final
        sta     nombre_hi
        ldx     #<nombre_final
        lda     #nombre_final_fin - nombre_final
        jsr     nombre
        lda     #0                      ; LOAD: into bank 0
        jsr     carga
        bcc     :+
        lda     #<$D820                 ; a load error: the border changes, again
        sta     PTR
        lda     #>$D820
        sta     PTR + 1
        lda     #15
        sta     IND
        ldy     #0
        lda     (PTR),y
        clc
        adc     #1
        sta     (PTR),y
        sty     IND
        jmp     otra
:       lda     #$FF                    ; TPI 1's mask as the KERNAL's reset ($FA03)
        ldx     #<$DE05
        ldy     #>$DE05
        jsr     pon15
        ldy     #$FF                    ; the system's stack pointer
        lda     #<$0100
        sta     PTR
        lda     #>$0100
        sta     PTR + 1
        lda     #15
        sta     IND
        lda     (PTR),y
        tax
        lda     #0
        sta     IND
        txs
        ldx     #4                      ; SEI, LDA #0, STA $00 at $0100 (as cc65's BASIC header pokes into bank 15)
:       lda     arranque,x
        sta     $0100,x
        dex
        bpl     :-
        lda     #0
        jmp     $0100
arranque: .byte $78, $A9, $00, $85, $00

; A into the KERNAL's zero page at Y (bank 15).  A, X kept
.proc pon_kzp
        pha
        lda     #0
        sta     PTR
        sta     PTR + 1
        lda     #15
        sta     IND
        pla
        sta     (PTR),y
        pha
        lda     #0
        sta     IND
        pla
        rts
.endproc

; the KERNAL's LOAD in bank 15 with A, X, Y and P as given; back here (bank 1) with them as it returned them
.proc k15
        php
        pha
        lda     #15
        sta     IND
        txa
        pha
        tya
        pha
        sei
        ldy     #$FF
        lda     (K_P1),y                ; bank 15's stack pointer (kept at $F:01FF)
        tay
        lda     EXEC                    ; the bank to come back to: this one
        sta     (K_P1),y
        dey
        lda     #>(K_EXCRTS - 1)
        sta     (K_P1),y
        dey
        lda     #<(K_EXCRTS - 1)
        sta     (K_P1),y
        tya
        sec
        sbc     #7
        sta     k_sp
        tay
        pla                             ; Y, X, A, P
        iny
        sta     (K_P1),y
        pla
        iny
        sta     (K_P1),y
        pla
        iny
        sta     (K_P1),y
        pla
        iny
        sta     (K_P1),y
        lda     #<(K_LOAD - 1)          ; the routine's address - 1
        iny
        sta     (K_P1),y
        lda     #>(K_LOAD - 1)
        iny
        sta     (K_P1),y
        ldy     k_sp
        lda     #>(K_EXPULL - 1)
        sta     (K_P1),y
        dey
        lda     #<(K_EXPULL - 1)
        sta     (K_P1),y
        dey
        tsx
        stx     $01FF                   ; this bank's stack pointer, for the way back ($FF11)
        tya
        tax
        txs
        lda     #15
        jmp     K_CAMBIA
.endproc

.segment "RODATA"
nombre_ave: .byte $41, $56, $45         ; "AVE" in PETSCII
nombre_ave_fin:
nombre_final: .byte $46, $49, $4E, $41, $4C     ; "FINAL"
nombre_final_fin:

.segment "BSS"
banco:  .res    1
k_sp:   .res    1
nombre_hi: .res 1
