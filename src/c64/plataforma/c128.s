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


; abadia64ks, the Commodore 128's own platform (milestone H10, assembled only with -D C128; the MMU:
; doc/referencias/c128.md, from "Mapping the Commodore 128").  The game runs in block 0 as on the C64 (the MMU's
; $FF00 = $3E / $3F where the C64 writes $35 / $34 into the 6510's $01: MEMCFG, plat64.inc); block 1 holds what
; mapa64.py moved out of block 0 (zone banco1, from $1000: the room table D64_ISO_ROOM_TABLE), loaded there
; from juego.bin.banco1.  Everything here lives in segment COMUN at $0800, inside the 4 KiB of common RAM
; ($0000-$0FFF, always block 0, set by c128_inicio), so it runs whichever block is mapped; plat_irq and plat_nmi
; (interrupcion.s) are there too: an interrupt that comes while block 1 is mapped takes block 1's vectors at
; $FFFA-$FFFF, which c128_inicio makes the same as block 0's.
;
; c128_inicio: the common RAM and block 1's vectors.  Called by plat_inicio with the I/O visible, the vectors of
;   block 0 set and the interrupts off.  A, Y clobbered.
; far_lee: A = the byte at (zhl),Y of block 1.  X, Y, C and V kept; N and Z of A (as LDA (zhl),Y).
; far_pon: the byte A into (zhl),Y of block 1.  A, X, Y and the flags kept (as STA (zhl),Y).
; far_sala: the room record at [D64_ISO_ROOM_PTR] (block 1) copied into SALA (block 0, common RAM), whole: its
;   first byte is its length.  iso_draw_room builds the room from SALA + 1.  A, Y clobbered; X kept.
; SALA: 256 bytes (segment SALA128, $0B00: the common RAM).
; The texts (D64_TXT_PHRASES, D64_TXT_WORDS, D64_TXT_PUNCTUATION) live in block 1 too (mapa64.py BANCO1;
; the 128ks optimised for speed, using the C128's extra memory: their 2186 bytes of
; block 0 go to the speed work), read by these (each saves the caller's MEMCFG on the stack, so the interrupt's
; character (t_frase) may come inside a call of the main program):
; far_texto: A = the byte at (zp0),Y of block 1.  Y kept, X clobbered; N and Z of A.
; far_palabras: zp0 past X >= 1 words (bit 7 ends a word) of block 1 (estado_texto's 3770 txt_skip_words); A, X,
;   Y clobbered.
; far_frases: zhl past B FFh-terminated strings of block 1 (logica_a's 4BB2 txt_skip_strings); out as it: B = 0,
;   A = FFh, Y = 0, Z = 1, C = 1.
; far_numeral: A into D64_TXT_WORD_AAA,Y of block 1 (obj_set_mirror_numeral).  A, X, Y and the flags kept.
;
; Speed (everything optimised for speed): the 8502 runs at 2 MHz (CLKRATE $D030 bit 0)
; while the beam is below and above the display window, where the VIC-II reads nothing from memory (it cannot show a
; picture at 2 MHz: "Mapping the Commodore 128"; the I/O chips are reached at 1 MHz by the C128's clock stretching,
; and the CIAs count at 1 MHz, so the game's 300 Hz tick is unchanged).  CIA 2's two timers, one frame long each
; (PAL: 312 lines of 63 cycles, 19656), started by c128_rapido on the raster lines RAPIDO_SI (252, after the last
; display line, 250) and RAPIDO_NO (46, before the first fetch line, 51 with $D011 = $3B), raise an NMI at each:
; plat_nmi sets 2 MHz on timer A, 1 MHz on timer B (an NMI: not held back by the game's SEI); the RESTORE key's
; NMI changes nothing.  112 of the 312 lines at 2 MHz.  Off around the KERNAL's disk calls (its serial code times
; itself), on again after them.
;
; The disk (the CTRL+TAB menu's save and load, the ending) goes through the C128's KERNAL, whose RAM the game uses:
; the loader's last stage (c64/disco128/etapa128.s) took a photograph of it into block 1 (kernal_foto: the zero
; page, the stack page, $0200-$03FF, $0A00-$0AFF, $1000-$10FF) and put its page $0A00 back where the game keeps it
; free (segment KERNAL128).  plat_disco_guarda / plat_disco_carga (as disco.s's on the C64: zhl = the block, zde its
; length; the file "ABADIA64.BSn"; C = 1 on an error) swap the game's zero page ($02-$FF) and $0200-$03FF with the
; photograph's (byte by byte, through no zero page nor stack), call the KERNAL in bank 15 ($FF00 = $00: this code,
; below $4000, stays visible) with no interrupt source on (CIA 1's masked) and swap back.  plat_final puts the
; KERNAL's RAM back for good, the menu's options at $0BFF (OPCIONES, c64/disco128/disco128.inc: the ending's
; language), the MMU as the KERNAL left it (1 KiB of common RAM at the bottom), the raster's interrupt, and loads
; "FINAL" (the ending for the C128, a cc65 program at $1C01) from plat_unidad and runs it; never returns.

C128_PROPIO = 1                         ; (zp.inc / plat64.inc: far_lee and far_pon are defined here)
        .include "plat64.inc"
        .include "zp.inc"
        .include "mapa.inc"
        .export c128_inicio, far_lee, far_pon, far_sala, SALA, kernal_foto
        .export far_texto, far_palabras, far_frases, far_numeral
        .export plat_disco_guarda, plat_disco_carga, plat_final, plat_ranura, plat_unidad
        .export c128_ave, c128_carga_ave, c128_carga, ave_muestra
        .import plat_opciones, psg_inicio
        .include "ave128.inc"           ; AVE_LARGO, AVE_CICLOS (c64/disco128/ave128.py, in the build's directory)

MMU_RCR = $D506                         ; the RAM configuration register (in the I/O block)
CLKRATE = $D030                         ; bit 0: 2 MHz
RAPIDO_SI = 252                         ; the raster lines of the NMIs (see above)
RAPIDO_NO = 46
CUADRO  = 312 * 63                      ; a PAL frame in cycles

.segment "COMUN"

.proc c128_inicio
        lda     #$05                    ; 4 KiB of common RAM (bits 0-1 = 01) at the bottom (bits 2-3 = 01);
        sta     MMU_RCR                 ;   the VIC-II sees block 0 (bits 6-7 = 00)
        ldy     #5                      ; block 0's NMI, RESET and IRQ vectors into block 1's $FFFA-$FFFF
:       lda     $FFFA,y
        ldx     #MEM_B1
        stx     MEMCFG
        sta     $FFFA,y
        ldx     #MEM_IO
        stx     MEMCFG
        dey
        bpl     :-
        jmp     c128_rapido
.endproc

; CIA 2's timers locked to the raster: A on RAPIDO_SI, B on RAPIDO_NO, both continuous, one frame; their NMIs on.
; With the I/O visible and the interrupts off.  A clobbered.
.proc c128_rapido
        lda     #$7F                    ; no NMI from CIA 2 meanwhile
        sta     CIA2_ICR
        lda     CIA2_ICR
        lda     #0
        sta     $DD0E
        sta     $DD0F
        sta     CLKRATE
        lda     #<(CUADRO - 1)          ; (a continuous timer's period is its latch + 1, as CICLOS_TICK's)
        sta     $DD04
        lda     #>(CUADRO - 1)
        sta     $DD05
:       lda     VIC_D011                ; line RAPIDO_SI (below 256: $D011's bit 7 clear)
        bmi     :-
:       lda     VIC_D012
        cmp     #RAPIDO_SI
        bne     :-
        lda     #%00010001              ; timer A: load, start, continuous (its first NMI a frame later)
        sta     $DD0E
        lda     #<((312 - RAPIDO_SI + RAPIDO_NO) * 63 - 20)     ; timer B: its first NMI on RAPIDO_NO (the
        sta     $DD06                   ;   ~20 cycles since timer A started taken off)
        lda     #>((312 - RAPIDO_SI + RAPIDO_NO) * 63 - 20)
        sta     $DD07
        lda     #%00010001
        sta     $DD0F
        lda     #<(CUADRO - 1)          ; its latch for the next frames (the counter is running: only the latch)
        sta     $DD06
        lda     #>(CUADRO - 1)
        sta     $DD07
        lda     #$83                    ; NMI on timers A and B
        sta     CIA2_ICR
        rts
.endproc

.proc far_lee
        lda     MEMCFG
        sta     vuelta+1                ; (the caller's configuration, put back below)
        lda     #MEM_B1
        sta     MEMCFG
        lda     (zhl),y
        pha
vuelta: lda     #MEM_IO
        sta     MEMCFG
        pla
        rts
.endproc

.proc far_pon
        php
        pha
        lda     MEMCFG
        sta     vuelta+1
        lda     #MEM_B1
        sta     MEMCFG
        pla
        sta     (zhl),y
        pha
vuelta: lda     #MEM_IO
        sta     MEMCFG
        pla
        plp
        rts
.endproc

.proc far_sala
        lda     D64_ISO_ROOM_PTR
        sta     fuente+1
        sta     largo+1
        lda     D64_ISO_ROOM_PTR+1
        sta     fuente+2
        sta     largo+2
        lda     MEMCFG
        sta     vuelta+1
        lda     #MEM_B1
        sta     MEMCFG
largo:  lda     $FFFF                   ; (the record's length: its first byte)
        sta     n+1
        ldy     #0
fuente: lda     $FFFF,y
        sta     SALA,y
        iny
n:      cpy     #0
        bne     fuente
vuelta: lda     #MEM_IO
        sta     MEMCFG
        rts
.endproc

.proc far_texto
        lda     MEMCFG
        pha
        lda     #MEM_B1
        sta     MEMCFG
        lda     (zp0),y
        tax
        pla
        sta     MEMCFG
        txa
        rts
.endproc

.proc far_palabras
        lda     MEMCFG
        pha
        lda     #MEM_B1
        sta     MEMCFG
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
:       pla
        sta     MEMCFG
        rts
.endproc

.proc far_frases
        lda     MEMCFG
        pha
        lda     #MEM_B1
        sta     MEMCFG
        ldy     #0
:       lda     (zhl),y
        inc     zhl
        bne     :+
        inc     zhl+1
:       cmp     #$FF
        bne     :--
        dec     zbc+1
        bne     :--
        pla
        sta     MEMCFG
        lda     #$FF
        ldy     #0
        rts
.endproc

.proc far_numeral
        php
        pha
        lda     MEMCFG
        sta     vuelta+1
        lda     #MEM_B1
        sta     MEMCFG
        pla
        sta     D64_TXT_WORD_AAA,y
        pha
vuelta: lda     #MEM_IO
        sta     MEMCFG
        pla
        plp
        rts
.endproc

; ---- the disk, through the KERNAL ----------------------------------------------------------------------------
; (segment COMUN2 at $0C00: it maps block 1 or bank 15 at times, so it lives in the common RAM too)

.segment "COMUN2"

K_SETBNK = $FF68
FOTO_ZP  = kernal_foto                  ; the photograph's pages (block 1)
FOTO_PILA = kernal_foto + $100
FOTO_200 = kernal_foto + $200
FOTO_0A00 = kernal_foto + $400
FOTO_1000 = kernal_foto + $500
OPCIONES = $0BFF                        ; (c64/disco128/disco128.inc)

; the game's zero page ($02-$FF) and $0200-$03FF swapped with the photograph's; no zero page, no stack.  A, X, Y
.proc intercambia
        ldx     #2
:       lda     a:$0000,x
        sta     uno
        lda     #MEM_B1
        sta     MEMCFG
        lda     FOTO_ZP,x
        tay
        lda     uno
        sta     FOTO_ZP,x
        lda     #MEM_RAM
        sta     MEMCFG
        sty     uno
        lda     uno
        sta     a:$0000,x
        inx
        bne     :-
:       .repeat 2, k
        lda     $0200 + $100 * k,x
        sta     uno
        lda     #MEM_B1
        sta     MEMCFG
        lda     FOTO_200 + $100 * k,x
        tay
        lda     uno
        sta     FOTO_200 + $100 * k,x
        lda     #MEM_RAM
        sta     MEMCFG
        tya
        sta     $0200 + $100 * k,x
        .endrep
        inx
        bne     :-
        rts
.endproc

; X/Y = zhl + zde (the block's end + 1), read before the swap; the start into k_ini
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

; into the KERNAL: the game's zero page and $0200-$03FF swapped, no interrupt source, bank 15
.proc entra
        lda     #MEM_IO
        sta     MEMCFG
        lda     #$7F                    ; CIA 1: no interrupt; CIA 2: no NMI, 1 MHz (the KERNAL's serial code)
        sta     CIA1_ICR
        sta     CIA2_ICR
        lda     CIA1_ICR
        lda     CIA2_ICR
        lda     #0
        sta     CLKRATE
        jsr     intercambia
        lda     #$00                    ; bank 15: the KERNAL, the I/O, block 0's RAM below $4000
        sta     MEMCFG
        lda     #0                      ; the data and the name in block 0
        tax
        jsr     K_SETBNK
        lda     #NOMBRE_LARGO
        ldx     #<nombre
        ldy     #>nombre
        jsr     K_SETNAM
        lda     #1
        ldx     plat_unidad
        ldy     #0
        jmp     K_SETLFS
.endproc

; out of the KERNAL: everything back; C kept
.proc sale
        php
        sei
        lda     #MEM_IO
        sta     MEMCFG
        jsr     intercambia
        lda     #MEM_IO
        sta     MEMCFG
        lda     CIA1_ICR                ; what CIA 1 flagged meanwhile: forgotten
        lda     #$81                    ; timer A's interrupt on again
        sta     CIA1_ICR
        jsr     c128_rapido             ; 2 MHz in the border again
        plp
        sei
        rts
.endproc

.proc plat_disco_guarda
        jsr     bloque
        jsr     entra
        lda     #15                     ; OPEN 15,unit,15,"S0:name": CLOSE 15 (the old file scratched)
        ldx     plat_unidad
        ldy     #15
        jsr     K_SETLFS
        lda     #NOMBRE_LARGO + 3
        ldx     #<orden
        ldy     #>orden
        jsr     K_SETNAM
        jsr     K_OPEN
        lda     #15
        jsr     K_CLOSE
        lda     #NOMBRE_LARGO
        ldx     #<nombre
        ldy     #>nombre
        jsr     K_SETNAM
        lda     #1
        ldx     plat_unidad
        ldy     #0
        jsr     K_SETLFS
        lda     k_ini                   ; SAVE from ($FB) to the end
        sta     $FB
        lda     k_ini+1
        sta     $FC
        lda     #$FB
        ldx     k_fin
        ldy     k_fin+1
        jsr     K_SAVE
        jmp     sale
.endproc

.proc plat_disco_carga
        jsr     bloque
        jsr     entra
        lda     #0                      ; LOAD at X/Y (secondary address 0)
        ldx     k_ini
        ldy     k_ini+1
        jsr     K_LOAD
        bcs     :+
        cpx     k_fin                   ; the end + 1 must be the block's
        bne     mal
        cpy     k_fin+1
        bne     mal
        clc
:       jmp     sale
mal:    sec
        jmp     sale
.endproc

.proc plat_final
        sei
        lda     #MEM_IO
        sta     MEMCFG
        lda     #$7F
        sta     CIA1_ICR
        sta     CIA2_ICR
        lda     CIA1_ICR
        lda     CIA2_ICR
        lda     #0
        sta     CLKRATE                 ; 1 MHz (the ending's program shows a picture)
        sta     SID_VOLUMEN             ; silence
        ldx     #0                      ; the KERNAL's RAM back for good (no zero page, no stack meanwhile)
:       lda     #MEM_B1
        sta     MEMCFG
        lda     FOTO_ZP,x
        ldy     FOTO_PILA,x
        sty     uno
        ldy     #MEM_RAM
        sty     MEMCFG
        cpx     #2
        bcc     :+
        sta     a:$0000,x
:       lda     uno
        sta     $0100,x
        .repeat 2, k
        lda     #MEM_B1
        sta     MEMCFG
        lda     FOTO_200 + $100 * k,x
        ldy     #MEM_RAM
        sty     MEMCFG
        sta     $0200 + $100 * k,x
        .endrep
        lda     #MEM_B1
        sta     MEMCFG
        lda     FOTO_1000,x
        ldy     #MEM_RAM
        sty     MEMCFG
        sta     $1000,x
        inx
        bne     :--
        ldx     #$FF
        txs
        lda     plat_opciones           ; the ending's language (OPCIONES, c64/disco128/disco128.inc)
        sta     OPCIONES
        lda     #$FF                    ; the screen editor leaves the VIC-II alone: the game's screen stays
        sta     $D8
        ldy     #$40                    ; the KERNAL's interrupt and reset code ($FF05-$FF44) and the 6502's vectors
kram:   sty     MMU_CR                  ; ($FFFA-$FFFF) back in the RAM of block 1, then block 0, as its RESET does
        ldx     #$3F                    ; ($E0CD: read in the ROM, written to the RAM under it).  An interrupt while a
:       lda     $FF05,x                 ; RAM block is in view goes through them ("Mapping the Commodore 128"); with
        sta     $FF05,x                 ; the game's there, the slow LOAD from a 1541 ended in the game's code it was
        dex                             ; overwriting.  (Run while the 4 KiB of common RAM at the bottom hold this.)
        bpl     :-
        ldx     #$05
:       lda     $FFFA,x
        sta     $FFFA,x
        dex
        bpl     :-
        tya
        sec
        sbc     #$40
        tay
        bcs     kram
        lda     #MEM_IO
        sta     MMU_CR
        lda     #$04                    ; the common RAM as the KERNAL had it: 1 KiB at the bottom
        sta     MMU_RCR
        lda     #$FF                    ; the raster's interrupt (the C128 KERNAL's jiffy) on
        sta     VIC_D019
        lda     #$01
        sta     VIC_D01A
        lda     #$00                    ; bank 15
        sta     MMU_CR
        cli
carga:  lda     #0
        tax
        jsr     K_SETBNK
        lda     #final_fin - final
        ldx     #<final
        ldy     #>final
        jsr     K_SETNAM
        lda     #1
        ldx     plat_unidad
        ldy     #1                      ; at the file's own address ($1C01)
        jsr     K_SETLFS
        lda     #0
        jsr     K_LOAD
        bcc     :+
        inc     VIC_BORDE               ; an error: try again
        jmp     carga
:       jmp     $1C0D                   ; the ending (its BASIC line's SYS)
.endproc

MMU_CR = $FF00

; ---- the Ave Maria (the PC version's, at completas: logica_b.s lb_hora) -----------------------------------------
; c128_ave: the game frozen while it sounds, as on the PC (13.45 s): interrupts off, CIA 2's NMIs off and 1 MHz (the
; screen stays), the three voices held at a constant level (test bit, pulse, gate, sustain 15: the 8580 needs that
; offset for the volume register to be heard; the 6581 has its own), each 4-bit sample of ave_muestra (block 1) into
; the volume register at the pace of CIA 1's timer B (AVE_CICLOS, polled); then the SID at rest (psg_inicio), CIA 1's
; tick back, 2 MHz in the border again.  The menu's option 4 off: the loader made its call 3 NOPs and the sample was
; never loaded.  A, X, Y clobbered.
.proc c128_ave
        php
        sei
        lda     MEMCFG
        pha
        lda     #MEM_IO
        sta     MEMCFG
        lda     #$7F                    ; no interrupt, no NMI
        sta     CIA1_ICR
        sta     CIA2_ICR
        lda     CIA1_ICR
        lda     CIA2_ICR
        lda     #0
        sta     CLKRATE
        ldx     #14                     ; the voices (registers 0-6, 7-13, 14-20)
:       lda     #0
        sta     SID + 5,x               ; attack, decay
        lda     #$F0
        sta     SID + 6,x               ; sustain 15
        lda     #$49
        sta     SID + 4,x               ; pulse, test, gate
        txa
        sec
        sbc     #7
        tax
        bcs     :-
        lda     #<(AVE_CICLOS - 1)      ; CIA 1's timer B: one sample's time, continuous
        sta     $DC06
        lda     #>(AVE_CICLOS - 1)
        sta     $DC07
        lda     #%00010001
        sta     $DC0F
        lda     #<ave_muestra
        sta     dato
        lda     #>ave_muestra
        sta     dato+1
bucle:  lda     #MEM_B1 & $FE           ; block 1 with the I/O
        sta     MEMCFG
dato = * + 1
        lda     $FFFF
        tay
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        jsr     espera
        sta     SID_VOLUMEN
        tya
        and     #$0F
        jsr     espera
        sta     SID_VOLUMEN
        inc     dato
        bne     :+
        inc     dato+1
:       lda     dato
        cmp     #<(ave_muestra + AVE_LARGO)
        bne     bucle
        lda     dato+1
        cmp     #>(ave_muestra + AVE_LARGO)
        bne     bucle
        lda     #MEM_IO
        sta     MEMCFG
        lda     #0
        sta     $DC0F                   ; timer B stopped
        jsr     psg_inicio              ; the SID at rest
        lda     CIA1_ICR                ; the tick again, as plat_inicio left it
        lda     #$81
        sta     CIA1_ICR
        jsr     c128_rapido
        pla
        sta     MEMCFG
        plp
        rts
; the next sample's time (CIA 1's timer B flag; its read clears it); A kept
espera: pha
:       lda     CIA1_ICR
        and     #$02
        beq     :-
        pla
        rts
.endproc

; c128_carga: the loader's last stage (c64/disco128/etapa128.s) calls it once the game's code is in place: the file
; named at X/Y (A bytes, PETSCII) loaded into block 1 at its own address with the KERNAL, as plat_disco_carga does
; (its RAM swapped with the photograph): J2 (the game's pieces above $C000) and, when the menu's option 4 is on, AVE.
; With 4 KiB of common RAM at the bottom, the KERNAL's page $0A00 in place and the interrupts off, no interrupt
; source on.  C = 1 on an error.  c128_carga_ave: AVE.
.proc c128_carga_ave
        lda     #nombre_ave_fin - nombre_ave
        ldx     #<nombre_ave
        ldy     #>nombre_ave
        ; falls into c128_carga
.endproc
.proc c128_carga
        pha                             ; (the name on the stack: intercambia leaves the stack page alone, and no
        txa                             ;   self-modified code, the game's image stays as built)
        pha
        tya
        pha
        lda     #MEM_IO
        sta     MEMCFG
        jsr     intercambia
        lda     #$00                    ; bank 15
        sta     MEMCFG
        lda     #1                      ; the data into block 1, the name in block 0
        ldx     #0
        jsr     K_SETBNK
        pla
        tay
        pla
        tax
        pla
        jsr     K_SETNAM
        lda     #1
        ldx     plat_unidad
        ldy     #1                      ; at its own address
        jsr     K_SETLFS
        lda     #0
        jsr     K_LOAD
        php
        sei
        lda     #MEM_IO
        sta     MEMCFG
        jsr     intercambia
        lda     #MEM_IO
        sta     MEMCFG
        plp
        rts
.endproc

; the names in PETSCII, as bytes (independent of ca65's target)
nombre_ave: .byte $41, $56, $45         ; "AVE"
nombre_ave_fin:
orden:  .byte   $53, $30, $3A           ; "S0:" then the name
nombre: .byte   $41, $42, $41, $44, $49, $41, $36, $34, $2E, $42, $53   ; "ABADIA64.BS"
plat_ranura:
        .byte   $31                     ; the slot: "1", then the last digit key pressed (teclado.s)
NOMBRE_LARGO = * - nombre
plat_unidad:
        .byte   8                       ; the drive (the loader sets the one it loaded from)
final:  .byte   $46, $49, $4E, $41, $4C ; "FINAL"
final_fin:
uno:    .res    1
k_ini:  .res    2
k_fin:  .res    2
        .assert * <= $1000, error, "COMUN2 must end inside the common RAM ($0FFF)"

.segment "KERNAL128"                    ; the KERNAL's page $0A00, kept free by the game (the loader puts it here)
        .res    256, 0

.segment "SALA128"
SALA:   .res    256, 0

.segment "B1FOTO"
kernal_foto:
        .res    $600
ave_muestra:                            ; the Ave Maria's samples ("AVE", loaded by c128_carga_ave)
        .res    AVE_LARGO
