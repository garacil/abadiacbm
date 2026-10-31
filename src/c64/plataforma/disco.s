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

; abadia64ks, the C64 platform layer: the disk, through the KERNAL (switched in only for that).
;
; plat_disco_guarda: In: zhl = the block's first byte, zde = its length (the tape menu's saved game: 1500 bytes
;   from D64_STATE_BUFFER).  Saves it as the file "ABADIA64.BSn" (n = plat_ranura, the last digit key pressed,
;   "1" at first: teclado.s) on the drive plat_unidad, replacing it (the old one is scratched first).  Out:
;   C = 0, or C = 1 when the KERNAL reported an error (no drive...; the drive's own errors, such as a full disk,
;   are not read back).  A, X, Y clobbered; zbc..zp3 kept.
; plat_disco_carga: In: zhl = where, zde = the length.  Loads "ABADIA64.BSn" there.  Out: C = 0 when it was
;   loaded and had exactly that length, else C = 1 (no file, an error; a longer file would have been loaded
;   past the block: only this game writes these files).  A, X, Y clobbered.
;   Both are called with the interrupts off (the tape menu's DI) and return with them off; no tick is
;   delivered meanwhile (as during the CPC's tape operations).
; plat_final: the end of the game: loads the ending parchment ("FINAL", c64/pergamino/final.prg, a cc65
;   program at $0801) from plat_unidad and runs it ($080D); never returns.  The game's screen stays while it
;   loads; then the machine is set as after a reset (IOINIT, RAMTAS, the KERNAL's vectors, CINT) for that
;   program, which expects the KERNAL's interrupt chain.  A load error flashes the border and tries again.
;
; The game uses the zero page and $0200-$03FF (c64/MAPA.md), which the KERNAL needs.  Around a KERNAL call the
; KERNAL's part of them is put aside in $0100-$01AE (the bottom of the stack page: the stack is shallow at the
; tape menu, ~16 bytes, and the KERNAL's own use of it is measured below 60 bytes: c64/plataforma/README.md)
; and given the values the KERNAL starts with:
;   $90-$FF (the KERNAL's zero page: status, file and serial variables) -> 0;
;   $0259-$0276 (the file tables: OPEN writes entry 0) -> kept aside, untouched;
;   $02A1 (the RS-232 flags: the serial LISTEN waits while bits 0-1 are set) -> 0;
;   $0314-$0333 (the vectors) -> the KERNAL ROM's table (copied from $FD30: RESTOR would also write the RAM
;     under $FD30, a part of the bitmap), with the NMI (RESTORE key) -> an RTI and the IRQ -> an acknowledge.
; CIA 1's timer A interrupt is off during the call (the KERNAL's serial code reads CIA 1's flags itself), $01 =
; $36 (KERNAL and I/O; $A000-$BFFF stays RAM: the game's data is readable), the VIC bank and the screen as
; the game has them (the serial code keeps $DD00's bits 0-1).  Then everything goes back.

        .include "plat64.inc"
        .include "zp.inc"
        .export plat_disco_guarda, plat_disco_carga, plat_final, plat_ranura, plat_unidad
        .import plat_nmi

RESPALDO = $0100                        ; $90-$FF, $0314-$0333, $0259-$0276, $02A1: 175 bytes
R_ZP     = RESPALDO
R_VEC    = RESPALDO + $70
R_TAB    = RESPALDO + $90
R_RS232  = RESPALDO + $AE

.segment "DATA"
orden:  .byte   $53, $30, $3A           ; "S0:", the scratch command, then the name (PETSCII, as bytes: the
nombre: .byte   $41, $42, $41, $44, $49, $41, $36, $34, $2E, $42, $53   ; strings do not depend on ca65's
plat_ranura:                            ; target) "ABADIA64.BS"
        .byte   $31                     ; the slot: "1", then the last digit key pressed
NOMBRE_LARGO = * - nombre
plat_unidad:
        .byte   8                       ; the drive (the loader may set the one it loaded from)

.segment "BSS"
k_01:   .res 1                          ; the game's $01

.segment "CODE"

.ifdef CINTA
; the tape (a game can be saved on tape and loaded back): the same menu on unit 1
; through the KERNAL's tape routines, which work by interrupt (open around SAVE and LOAD) and write the file's header
; into the cassette buffer (TAPE1 = $033C), where the game keeps its sprite table: those 192 bytes put aside in three
; free 64-byte pieces of the bitmap's invisible cells meanwhile (kernal_entra, kernal_sale); no scratch command
CASETE  = $033C
APARTE  = $EEE0                         ; $EEE0, $F020, $F160 (320 apart): no data there (the game's map)
.endif
.proc plat_disco_guarda
        jsr     kernal_entra
.ifndef CINTA
        lda     #NOMBRE_LARGO + 3       ; OPEN 15,unit,15,"S0:name": CLOSE 15
        ldx     #<orden
        ldy     #>orden
        jsr     K_SETNAM
        lda     #15
        tay
        ldx     plat_unidad
        jsr     K_SETLFS
        jsr     K_OPEN
        lda     #15
        jsr     K_CLOSE
.endif
        jsr     pon_nombre
        lda     zhl                     ; SAVE from ($FB) to zhl + zde
        sta     $FB
        lda     zhl+1
        sta     $FC
        jsr     fin_bloque
        lda     #$FB
.ifdef CINTA
        cli                             ; (the tape's interrupt; kernal_sale closes it again)
.endif
        jsr     K_SAVE
        jmp     kernal_sale
.endproc

.proc plat_disco_carga
        jsr     kernal_entra
        jsr     pon_nombre
        lda     #0                      ; LOAD at X/Y (secondary address 0)
        ldx     zhl
        ldy     zhl+1
.ifdef CINTA
        cli
.endif
        jsr     K_LOAD
        bcs     :+
        stx     $FB                     ; the end + 1 must be zhl + zde
        sty     $FC
        jsr     fin_bloque
        cpx     $FB
        bne     mal
        cpy     $FC
        bne     mal
        clc
:       jmp     kernal_sale
mal:    sec
        jmp     kernal_sale
.endproc

; X/Y = zhl + zde
.proc fin_bloque
        clc
        lda     zhl
        adc     zde
        tax
        lda     zhl+1
        adc     zde+1
        tay
        rts
.endproc

; SETNAM "ABADIA64.BSn", SETLFS 1,unit,0
.proc pon_nombre
        lda     #NOMBRE_LARGO
        ldx     #<nombre
        ldy     #>nombre
        jsr     K_SETNAM
        lda     #1
        ldx     plat_unidad
        ldy     #0
        jmp     K_SETLFS
.endproc

.proc kernal_entra
        sei
        ldx     #$6F                    ; $90-$FF aside, cleared
:       lda     $90,x
        sta     R_ZP,x
        lda     #0
        sta     $90,x
        dex
        bpl     :-
        ldx     #$1F                    ; the vectors aside
:       lda     $0314,x
        sta     R_VEC,x
        dex
        bpl     :-
        ldx     #$1D                    ; the file tables aside
:       lda     $0259,x
        sta     R_TAB,x
        dex
        bpl     :-
        lda     $02A1
        sta     R_RS232
        lda     #0
        sta     $02A1
        lda     #$01                    ; CIA 1 timer A's interrupt off
        sta     CIA1_ICR
        lda     $01
        sta     k_01
.ifdef CINTA
        ldx     #63                     ; the sprite table aside (the RAM under the KERNAL still visible)
:       lda     CASETE,x
        sta     APARTE,x
        lda     CASETE+64,x
        sta     APARTE+320,x
        lda     CASETE+128,x
        sta     APARTE+640,x
        dex
        bpl     :-
        lda     #<CASETE                ; TAPE1, the KERNAL's tape buffer (cleared above with $90-$FF)
        sta     $B2
        lda     #>CASETE
        sta     $B3
.endif
        lda     #$36                    ; KERNAL and I/O in
        sta     $01
        ldx     #$1F                    ; the KERNAL's vectors
:       lda     K_VECTORES,x
        sta     $0314,x
        dex
        bpl     :-
        lda     #<plat_nmi
        sta     $0318
        lda     #>plat_nmi
        sta     $0319
        lda     #<irq_kernal
        sta     $0314
        lda     #>irq_kernal
        sta     $0315
        rts
.endproc

; (no interrupt is expected while the KERNAL is in: one would be acknowledged and ignored)
.proc irq_kernal
        lda     CIA1_ICR
        jmp     K_FIN_IRQ
.endproc

; everything back; C kept (the result)
.proc kernal_sale
        php
        sei
        lda     k_01
        sta     $01
.ifdef CINTA
        ldx     #63                     ; the sprite table back
:       lda     APARTE,x
        sta     CASETE,x
        lda     APARTE+320,x
        sta     CASETE+64,x
        lda     APARTE+640,x
        sta     CASETE+128,x
        dex
        bpl     :-
.endif
        ldx     #$6F
:       lda     R_ZP,x
        sta     $90,x
        dex
        bpl     :-
        ldx     #$1F
:       lda     R_VEC,x
        sta     $0314,x
        dex
        bpl     :-
        ldx     #$1D
:       lda     R_TAB,x
        sta     $0259,x
        dex
        bpl     :-
        lda     R_RS232
        sta     $02A1
        lda     CIA1_ICR                ; what CIA 1 flagged meanwhile: forgotten
        lda     #$81                    ; timer A's interrupt on again
        sta     CIA1_ICR
        plp
        sei                             ; (the KERNAL's serial code enables the interrupts)
        rts
.endproc

; ---- the ending ----------------------------------------------------------------------------------------

FINAL_STUB = $C400                      ; the tiles' merge tables: free once the game is over; outside what
                                        ; the load ($0801-$5117), RAMTAS ($0002-$03FF) and CINT ($0400) touch
FINAL_OPCIONES = $C3FF                  ; (the tape) the last sprite pointer of the game's screen: unused

.proc plat_final
        sei
        lda     #$7F
        sta     CIA1_ICR
        lda     #0
        sta     SID_VOLUMEN             ; silence
        ldx     #final_fin - final_ini - 1
:       lda     final_ini,x
        sta     FINAL_STUB,x
        dex
        bpl     :-
        lda     plat_unidad
        sta     FINAL_STUB + (f_unidad - f_ini) + 1
.if .defined(CINTA) || .defined(DISCO)
        .import plat_opciones
        lda     plat_opciones           ; the menu's options for "FINAL" (the tape's c64/cinta/arranque.s, the
        sta     FINAL_OPCIONES          ; disk's c64/disco64): at $C3FF, which the KERNAL's load, RAMTAS and CINT
.endif                                  ; leave alone
        jmp     FINAL_STUB
.endproc

.segment "RODATA"
final_ini:
        .org    FINAL_STUB
f_ini:  lda     #$37                    ; BASIC, KERNAL, I/O
        sta     $01
        lda     #0                      ; the KERNAL's variables at rest (as kernal_entra)
        ldx     #$6F
:       sta     $90,x
        dex
        bpl     :-
        sta     $02A1
.ifdef CINTA
        lda     #$3C                    ; TAPE1, the KERNAL's tape buffer ($033C; cleared above: below $0200 its
        sta     $B2                     ; tape routines answer 9, illegal device)
        lda     #$03
        sta     $B3
.endif
        ldx     #$1F
:       lda     K_VECTORES,x
        sta     $0314,x
        dex
        bpl     :-
        lda     #<f_rti
        sta     $0318
        lda     #>f_rti
        sta     $0319
f_carga:
        lda     #f_nombre_fin - f_nombre
        ldx     #<f_nombre
        ldy     #>f_nombre
        jsr     K_SETNAM
        lda     #1
f_unidad:
        ldx     #8                      ; (plat_unidad)
        ldy     #1                      ; at the file's own address
        jsr     K_SETLFS
        lda     #0
        jsr     K_LOAD
        bcc     :+
        inc     VIC_BORDE               ; an error: try again
        bcs     f_carga
:       sei                             ; (the KERNAL's serial code enabled them: IOINIT turns CIA 1's on)
        jsr     K_IOINIT                ; the machine as after a reset, without BASIC
        jsr     K_RAMTAS
        jsr     K_RESTOR
        jsr     K_CINT
        jsr     K_CLRCHN                ; the screen as the output device (CINT does not set it)
        lda     f_unidad + 1            ; the drive the ending came from as the current one ($BA, which RAMTAS
        sta     $BA                     ; cleared: cc65's start-up takes its unit from there, 8 when 0)
        cli
        jmp     $080D                   ; the ending's start (its BASIC line: SYS 2061)
f_rti:  rti
f_nombre:
        .byte   $46, $49, $4E, $41, $4C ; "FINAL" in PETSCII
f_nombre_fin:
        .reloc
final_fin:
