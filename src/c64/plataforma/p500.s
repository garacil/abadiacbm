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


; abadia128ks, the P500's own platform (the CBM-II 510 with 128 KiB: banks 0 and 1; assembled with -D C128 -D P500;
; doc/referencias/p500.md).  The game runs in bank 0 as on the C128's block 0; bank 1 holds what mapa64.py moved out
; of it (zone banco1, from $1000: the room table, the texts) and the Ave Maria's samples.  The 6509 reaches bank 1
; with its own two cross-bank instructions, LDA (zp),Y and STA (zp),Y while its indirect bank register $01 holds 1
; (io500.inc); the game keeps $01 = 0.  No common RAM is needed: the code never leaves bank 0 but for the KERNAL.
;
; p500_inicio: bank 0's part of the KERNAL's cross-bank return path ($FF26: PLA TAY PLA TAX PLA PLP RTS; $FFF6: STA
;   $00 / RTS), at the addresses the KERNAL uses in bank 15 (mapa64.py keeps them free).  A, X clobbered.
; far_lee: A = the byte at (zhl),Y of bank 1.  X, Y, C and V kept; N and Z of A (as LDA (zhl),Y).
; far_pon: the byte A into (zhl),Y of bank 1.  A, X, Y and the flags kept (as STA (zhl),Y).
; far_sala: the room record at [D64_ISO_ROOM_PTR] (bank 1) copied into SALA (bank 0), whole: its first byte is its
;   length.  A, Y clobbered; X kept.
; far_texto: A = the byte at (zp0),Y of bank 1.  X, Y kept; N and Z of A.
; far_palabras: zp0 past X >= 1 words (bit 7 ends a word) of bank 1; A, X, Y clobbered.
; far_frases: zhl past B FFh-terminated strings of bank 1; out: B = 0, A = FFh, Y = 0, Z = 1, C = 1.
; far_numeral: A into D64_TXT_WORD_AAA,Y of bank 1.  A, X, Y and the flags kept.
; Every one of them goes $01: 0 -> 1 -> 0 by INC / DEC (the game keeps $01 = 0; an interrupt keeps $01 whatever it
; finds: plat_irq), so the interrupt's character (t_frase) may come inside a call of the main program.
;
; The disk (the CTRL+TAB menu's save and load: the file "ABADIA64.BSn" on plat_unidad; C = 1 on an error) goes
; through the KERNAL of bank 15, which has its own zero page, stack and variables there: nothing of the game's has to
; be moved.  k15 calls a KERNAL routine as the ROM 901234-02's own cross-bank calls do (and cc65's cbm510 runtime,
; its crt0.s callbank15): bank 15's stack, whose pointer the system keeps at $F:01FF, gets the bank to come back to
; (0), the KERNAL's way back ($FEFE - 1), the registers, the routine's address - 1 and $FF26 - 1; then $FFF6 (STA $00
; / RTS in both banks) moves the CPU to bank 15, where $FF26 (PLA TAY PLA TAX PLA PLP RTS) gives the registers and
; enters the routine; its RTS goes to $FEFE, which puts the results on bank 0's stack below the pointer kept at bank
; 0's $01FF and comes back through $FFF6 and bank 0's $FF26.  Bank 0's $01FF (the bottom of the game's stack) is kept
; aside meanwhile.  During the call the game's interrupt is off (the 6526's interrupt off, TPI 1's mask 0: the
; KERNAL's IEEE-488 code uses the 6526's timers); after it, the 6526, the TPIs and the game's tick as plat_inicio
; left them.  The KERNAL's variables are written directly in its zero page (bank 15), as its SETNAM and SETLFS
; ($FB40, $FB4F) write them: the name's address and bank $90-$92, its length $9D, the logical file $9E, the device
; $9F, the secondary address $A0; SAVE's start and end (address, bank) at $99-$9B and $96-$98, as SAVE ($F853)
; copies them from the pointers X and Y.
;
; c128_ave (the name the game's logica_b.s calls): the Ave Maria, as the C128's: the game frozen while it sounds,
;   the three voices held at a constant level, each 4-bit sample of ave_muestra (bank 1) into the SID's volume at the
;   pace of the 6526's timer B (AVE_CICLOS, polled); then the SID at rest and the tick back.  A, X, Y clobbered.
; plat_final: the ending ("FINAL", a cc65 program for the P500) loaded into bank 0 and started (never returns).

C128_PROPIO = 1                         ; (plat64.inc: far_lee and far_pon are defined here)
P500_PROPIO = 1                         ; (io500.inc: the I/O routines too)
        .include "plat64.inc"
        .include "zp.inc"
        .include "mapa.inc"
        .export p500_inicio, far_lee, far_pon, far_sala, SALA
        .export far_texto, far_palabras, far_frases, far_numeral
        .export plat_disco_guarda, plat_disco_carga, plat_final, plat_ranura, plat_unidad
        .export c128_ave, ave_muestra
        .export p5_vic_k, p5_vic_x, p5_vic_y, p5_vic_lee, p5_sid_k, p5_sid_x
        .import plat_opciones, psg_inicio
        .include "ave128.inc"           ; AVE_LARGO, AVE_CICLOS (c64/disco128/ave128.py, in the build's directory)

K_P1    = $FE                           ; 2: $0100 (bank 15's stack page, with $01 = 15)
K_EXCRTS = $FEFE                        ; the KERNAL's way back (bank 15)
K_EXPULL = $FF26                        ; its register pull (both banks)
K_CAMBIA = $FFF6                        ; STA $00 / RTS (both banks)
; (K_OPEN, K_CLOSE, K_LOAD, K_SAVE: plat64.inc; the P500's jump table has them at the C64's addresses, ROM $FFC0-$FFD8)
FNAM    = $90                           ; the KERNAL's zero page (bank 15): the file name's address, bank
FNAM_LEN = $9D
LA      = $9E
FA      = $9F
SA      = $A0
EAL     = $96                           ; SAVE's end (address, bank)
STAL    = $99                           ; SAVE's start

; the code in the C128's fixed areas, which the P500 does not need for their own purpose (COMUN $0800-$09FF, the
; C128 KERNAL's page KERNAL128 $0A00-$0AFF: juego.cfg), the rest in CODE
.segment "COMUN"

.proc p500_inicio
        ldx     #expull_fin - expull - 1
:       lda     expull,x
        sta     K_EXPULL,x
        dex
        bpl     :-
        lda     #$85                    ; STA $00
        sta     K_CAMBIA
        lda     #$00
        sta     K_CAMBIA + 1
        lda     #$60                    ; RTS
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

.proc far_lee
        inc     P5_IND                  ; bank 1
        lda     (zhl),y
        dec     P5_IND                  ; bank 0
        ora     #0                      ; (N and Z of A)
        rts
.endproc

.proc far_pon
        php
        inc     P5_IND
        sta     (zhl),y
        dec     P5_IND
        plp
        rts
.endproc

.proc far_sala
        lda     D64_ISO_ROOM_PTR
        sta     P5_PIO
        lda     D64_ISO_ROOM_PTR+1
        sta     P5_PIO+1
        inc     P5_IND
        ldy     #0
        lda     (P5_PIO),y              ; the record's length: its first byte
        sta     n+1
:       lda     (P5_PIO),y
        sta     SALA,y
        iny
n:      cpy     #0
        bne     :-
        dec     P5_IND
        rts
.endproc

.proc far_texto
        inc     P5_IND
        lda     (zp0),y
        dec     P5_IND
        ora     #0
        rts
.endproc

.proc far_palabras
        inc     P5_IND
        ldy     #0
w:      lda     (zp0),y
        bmi     e
        iny
        bne     w
        inc     zp0+1
        bne     w
e:      iny
        bne     :+
        inc     zp0+1
:       dex
        bne     w
        tya
        clc
        adc     zp0
        sta     zp0
        bcc     :+
        inc     zp0+1
:       dec     P5_IND
        rts
.endproc

.proc far_frases
        inc     P5_IND
        ldy     #0
:       lda     (zhl),y
        inc     zhl
        bne     :+
        inc     zhl+1
:       cmp     #$FF
        bne     :--
        dec     zbc+1
        bne     :--
        dec     P5_IND
        lda     #$FF                    ; (Z = 1, C = 1: CMP #$FF above)
        ldy     #0
        rts
.endproc

.proc far_numeral
        php
        pha
        lda     #<D64_TXT_WORD_AAA
        sta     P5_PIO
        lda     #>D64_TXT_WORD_AAA
        sta     P5_PIO+1
        pla
        inc     P5_IND
        sta     (P5_PIO),y
        dec     P5_IND
        plp
        rts
.endproc

; ---- the VIC-II and the SID for io500.inc's macros ------------------------------------------------------------
; In: A = the register (its offset), P5_A = the value, X / Y the index (_x, _y); called by the macros with the
; interrupts off (their PHP / SEI ... PLP keeps the flags and the interrupt flag).  Out: A = P5_A, X and Y kept.
p5_sid_x:
        sty     P5_Y
        stx     P5_PIO
        clc
        adc     P5_PIO
        tay
        jmp     sid_cola
p5_sid_k:
        sty     P5_Y
        tay
sid_cola:
        lda     #P5_SISTEMA
        sta     P5_IND
        lda     P5_A
        sta     (P5_PSID),y
        lda     #0
        sta     P5_IND
        lda     P5_A
        ldy     P5_Y
        rts
p5_vic_x:
        sty     P5_Y
        stx     P5_PIO
        clc
        adc     P5_PIO
        tay
        jmp     vic_cola
p5_vic_y:
        sty     P5_Y
        sty     P5_PIO
        clc
        adc     P5_PIO
        tay
        jmp     vic_cola
p5_vic_k:
        sty     P5_Y
        tay
vic_cola:
        lda     #P5_SISTEMA
        sta     P5_IND
        lda     P5_A
        sta     (P5_PVIC),y
        lda     #0
        sta     P5_IND
        lda     P5_A
        ldy     P5_Y
        rts
; A = the register's value (LDA $D000 + A); X, Y kept
p5_vic_lee:
        sty     P5_Y
        tay
        lda     #P5_SISTEMA
        sta     P5_IND
        lda     (P5_PVIC),y
        sta     P5_A
        lda     #0
        sta     P5_IND
        lda     P5_A
        ldy     P5_Y
        rts

; ---- the Ave Maria -------------------------------------------------------------------------------------------
.proc c128_ave
        php
        sei
        lda     #P5_SISTEMA
        sta     P5_IND
        ldy     #$0D                    ; no interrupt from the 6526 meanwhile
        lda     #$7F
        sta     (P5_PCIA),y
        lda     (P5_PCIA),y
        ldx     #14                     ; the voices (registers 0-6, 7-13, 14-20)
voz:    txa
        clc
        adc     #5
        tay
        lda     #0
        sta     (P5_PSID),y             ; attack, decay
        iny
        lda     #$F0
        sta     (P5_PSID),y             ; sustain 15
        dey
        dey
        lda     #$49
        sta     (P5_PSID),y             ; pulse, test, gate
        txa
        sec
        sbc     #7
        tax
        bcs     voz
        ldy     #$06                    ; the 6526's timer B: one sample's time, continuous
        lda     #<(AVE_CICLOS - 1)
        sta     (P5_PCIA),y
        iny
        lda     #>(AVE_CICLOS - 1)
        sta     (P5_PCIA),y
        ldy     #$0F
        lda     #%00010001
        sta     (P5_PCIA),y
        lda     #<ave_muestra
        sta     P5_PIO
        lda     #>ave_muestra
        sta     P5_PIO+1
bucle:  lda     #1                      ; the sample byte from bank 1
        sta     P5_IND
        ldy     #0
        lda     (P5_PIO),y
        ldy     #P5_SISTEMA
        sty     P5_IND
        sta     muestra
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        jsr     volumen
        lda     muestra
        and     #$0F
        jsr     volumen
        inc     P5_PIO
        bne     :+
        inc     P5_PIO+1
:       lda     P5_PIO
        cmp     #<(ave_muestra + AVE_LARGO)
        bne     bucle
        lda     P5_PIO+1
        cmp     #>(ave_muestra + AVE_LARGO)
        bne     bucle
        ldy     #$0F
        lda     #0
        sta     (P5_PCIA),y             ; timer B stopped
        sta     P5_IND
        jsr     psg_inicio              ; the SID at rest
        lda     #P5_SISTEMA
        sta     P5_IND
        ldy     #$0D                    ; the tick again, as plat_inicio left it
        lda     (P5_PCIA),y
        lda     #$81
        sta     (P5_PCIA),y
        lda     #0
        sta     P5_IND
        plp
        rts
; the next sample's time (the 6526's timer B flag; reading clears it), then A into the SID's volume register
volumen:
        tax
        ldy     #$0D
:       lda     (P5_PCIA),y
        and     #$02
        beq     :-
        txa
        ldy     #$18
        sta     (P5_PSID),y
        rts
.endproc

.segment "KERNAL128"

; ---- the KERNAL of bank 15 -------------------------------------------------------------------------------------

; k15: the KERNAL routine at k_dir (bank 15) with A, X, Y and P as given; back with them as it returned them
.proc k15
        php
        pha
        lda     $01FF                   ; (the bottom of the game's stack, back after the call)
        sta     fondo
        lda     #P5_SISTEMA
        sta     P5_IND
        txa
        pha
        tya
        pha
        sei
        ldy     #$FF
        lda     (K_P1),y                ; bank 15's stack pointer
        tay
        lda     #0                      ; the bank to come back to
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
        lda     k_dir                   ; the routine's address - 1
        iny
        sta     (K_P1),y
        lda     k_dir+1
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
        stx     $01FF                   ; bank 0's stack pointer, for the way back ($FF11)
        tya
        tax
        txs
        lda     #P5_SISTEMA
        jmp     K_CAMBIA
.endproc

; the routine A (low) / X (high) of bank 15 into k_dir (its address - 1)
.proc destino
        sec
        sbc     #1
        sta     k_dir
        txa
        sbc     #0
        sta     k_dir+1
        rts
.endproc

; the bottom of the game's stack back after a call (P kept)
.proc fondo_vuelve
        php
        pha
        lda     fondo
        sta     $01FF
        pla
        plp
        rts
.endproc

; A into the KERNAL's zero page at Y (bank 15); $01 back to 0.  A kept
.proc pon_kzp
        pha
        lda     #0
        sta     P5_PIO
        sta     P5_PIO+1
        lda     #P5_SISTEMA
        sta     P5_IND
        pla
        sta     (P5_PIO),y
        pha
        lda     #0
        sta     P5_IND
        pla
        rts
.endproc

; the file name X/Y (bank 0), A bytes, and the file A2 = (logical, device, secondary) from k_la, plat_unidad, k_sa
.proc nombre_lfs
        pha
        txa
        ldy     #FNAM
        jsr     pon_kzp
        pla
        pha
        ldy     #FNAM_LEN
        jsr     pon_kzp
        pla
        lda     nombre_hi
        ldy     #FNAM+1
        jsr     pon_kzp
        lda     #0                      ; bank 0
        ldy     #FNAM+2
        jsr     pon_kzp
        lda     k_la
        ldy     #LA
        jsr     pon_kzp
        lda     plat_unidad
        ldy     #FA
        jsr     pon_kzp
        lda     k_sa
        ldy     #SA
        jmp     pon_kzp
.endproc

; X/Y = zhl + zde (the block's end + 1); the start into k_ini
.proc bloque
        lda     zhl
        sta     k_ini
        clc
        adc     zde
        sta     k_fin
        lda     zhl+1
        sta     k_ini+1
        adc     zde+1
        sta     k_fin+1
        rts
.endproc

.segment "CODE"

; into the KERNAL: no interrupt source (the 6526's off, TPI 1's mask 0)
.proc entra
        sei
        lda     #P5_SISTEMA
        sta     P5_IND
        ldy     #$0D
        lda     #$7F
        sta     (P5_PCIA),y
        lda     (P5_PCIA),y
        ldy     #$05
        lda     #0
        sta     (P5_PTPI1),y
        ldy     #$07
        lda     (P5_PTPI1),y
        sta     (P5_PTPI1),y
        lda     #0
        sta     P5_IND
        rts
.endproc

; out of the KERNAL: the 6526 (its ports in, timer A the tick, its interrupt), TPI 1 (the 6526's input only), TPI 2's
; keyboard lines; C kept
.proc sale
        php
        sei
        jsr     fondo_vuelve
        lda     #P5_SISTEMA
        sta     P5_IND
        ldy     #$02
        lda     #0
        sta     (P5_PCIA),y
        iny
        sta     (P5_PCIA),y
        ldy     #$04
        lda     #<(CICLOS_TICK - 1)
        sta     (P5_PCIA),y
        iny
        lda     #>(CICLOS_TICK - 1)
        sta     (P5_PCIA),y
        ldy     #$0E
        lda     #$11                    ; timer A: load, start, continuous
        sta     (P5_PCIA),y
        ldy     #$05
        lda     #$04
        sta     (P5_PTPI1),y
        ldy     #$07                    ; TPI 1's active interrupt ended (the 6526's interrupt is off: its line is
        lda     (P5_PTPI1),y            ;   up), then the 6526's flags read and its interrupt on (a flag set from here
        sta     (P5_PTPI1),y            ;   on is a new edge at TPI 1)
        ldy     #$0D
        lda     (P5_PCIA),y
        lda     #$81
        sta     (P5_PCIA),y
        lda     #<P5_TPI2
        sta     P5_PIO
        lda     #>P5_TPI2
        sta     P5_PIO+1
        ldy     #0
        lda     #$FF
        sta     (P5_PIO),y
        iny
        sta     (P5_PIO),y
        lda     #0
        sta     P5_IND
        plp
        rts
.endproc

.proc plat_disco_guarda
        jsr     bloque
        jsr     entra
        lda     #15                     ; OPEN 15,unit,15,"S0:name": CLOSE 15 (the old file scratched)
        sta     k_la
        sta     k_sa
        lda     #>orden
        sta     nombre_hi
        lda     #NOMBRE_LARGO + 3
        ldx     #<orden
        jsr     nombre_lfs
        lda     #<K_OPEN
        ldx     #>K_OPEN
        jsr     destino
        clc                             ; (the CBM-II's OPEN: a plain open with C = 0; cc65's kopen.s)
        jsr     k15
        jsr     fondo_vuelve
        lda     #<K_CLOSE
        ldx     #>K_CLOSE
        jsr     destino
        lda     #15
        jsr     k15
        jsr     fondo_vuelve
        lda     #1
        sta     k_la
        lda     #0
        sta     k_sa
        lda     #>nombre
        sta     nombre_hi
        lda     #NOMBRE_LARGO
        ldx     #<nombre
        jsr     nombre_lfs
        lda     k_ini                   ; SAVE from k_ini to k_fin (bank 0)
        ldy     #STAL
        jsr     pon_kzp
        lda     k_ini+1
        ldy     #STAL+1
        jsr     pon_kzp
        lda     #0
        ldy     #STAL+2
        jsr     pon_kzp
        lda     k_fin
        ldy     #EAL
        jsr     pon_kzp
        lda     k_fin+1
        ldy     #EAL+1
        jsr     pon_kzp
        lda     #0
        ldy     #EAL+2
        jsr     pon_kzp
        lda     #<K_SAVE
        ldx     #>K_SAVE
        jsr     destino
        ldx     #STAL
        ldy     #EAL
        jsr     k15
        jmp     sale
.endproc

.proc plat_disco_carga
        jsr     bloque
        jsr     entra
        lda     #1
        sta     k_la
        lda     #0
        sta     k_sa
        lda     #>nombre
        sta     nombre_hi
        lda     #NOMBRE_LARGO
        ldx     #<nombre
        jsr     nombre_lfs
        lda     #<K_LOAD
        ldx     #>K_LOAD
        jsr     destino
        lda     #0                      ; LOAD into bank 0 at X/Y
        ldx     k_ini
        ldy     k_ini+1
        jsr     k15
        bcs     fin
        stx     k_fin_cargado
        sty     k_fin_cargado+1
        clc
fin:    jmp     sale
.endproc

.segment "CODE"

; ---- the ending ------------------------------------------------------------------------------------------------
; the loader's last stage stays in bank 1 ($0200-$0FFF, below the game's bank 1 data) with a second entry for the end
; (c64/discop500/etapa500.s, disco500.inc ETAPA_FINAL, ETAPA_OPCIONES): the options there, bank 1's $FFF8 = JMP to it,
; and bank 0's $FFF6 (STA $00 / RTS: p500_inicio) moves the CPU to bank 1
ETAPA_OPCIONES = $0203
ETAPA_FINAL = $0205
.proc plat_final
        sei
        jsr     entra
        lda     #0                      ; silence
        SID_STA $18
        lda     #<ETAPA_OPCIONES
        sta     P5_PIO
        lda     #>ETAPA_OPCIONES
        sta     P5_PIO+1
        lda     #1
        sta     P5_IND
        ldy     #0
        lda     plat_opciones
        sta     (P5_PIO),y
        lda     #<$FFF8
        sta     P5_PIO
        lda     #>$FFF8
        sta     P5_PIO+1
        ldx     #2
:       lda     salto,x
        sta     (P5_PIO),y
        iny
        inx
        cpx     #5
        bne     :-
        lda     #0
        sta     P5_IND
        lda     #1
        jmp     K_CAMBIA
salto = * - 2
        .byte   $4C, <ETAPA_FINAL, >ETAPA_FINAL
.endproc

.segment "DATA"
; the names in PETSCII, as bytes
orden:  .byte   $53, $30, $3A           ; "S0:" then the name
nombre: .byte   $41, $42, $41, $44, $49, $41, $36, $34, $2E, $42, $53   ; "ABADIA64.BS"
plat_ranura:
        .byte   $31                     ; the slot: "1", then the last digit key pressed (teclado500.s)
NOMBRE_LARGO = * - nombre
plat_unidad:
        .byte   8                       ; the drive (the loader sets the one it loaded from)

.segment "BSS"
fondo:  .res    1
k_sp:   .res    1
k_dir:  .res    2
k_la:   .res    1
k_sa:   .res    1
nombre_hi: .res 1
k_ini:  .res    2
k_fin:  .res    2
k_fin_cargado: .res 2
muestra: .res   1

.segment "SALA128"
SALA:   .res    256, 0

.segment "B1FOTO"
ave_muestra:                            ; the Ave Maria's samples ("AVE", loaded into bank 1 by the loader)
        .res    AVE_LARGO
