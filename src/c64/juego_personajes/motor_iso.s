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

; abadia64ks, 6502 code of the game: group motor_iso (Z80 128F-2225; C reference juego/f_motor_iso.c).
        .include "zp.inc"
        .include "mapa64.inc"
        .export util_add_bx_al, iso_floor_base, iso_orient_relative

.segment "CODE"

; 128F util_add_bx_al: HL += A (A unsigned).  Out: HL, A = H.
.proc util_add_bx_al
        clc
        adc     zhl
        sta     zhl
        bcc     :+
        inc     zhl+1
:       lda     zhl+1
        rts
.endproc

; 2097 iso_floor_base: the floor of height A: B = 00h below 0Dh, 16h from 18h, else 0Bh; C as the Z80's
; (set when A < 0Dh), A kept.
.proc iso_floor_base
        ldx     #0
        cmp     #$0D
        bcc     menor
        ldx     #$16
        cmp     #$18
        bcs     fin                     ; Z80: CP 18h with A >= 18h leaves C clear
        ldx     #$0B
        sec                             ; Z80: A < 18h leaves C set
        stx     zbc+1
        rts
menor:  stx     zbc+1
        sec                             ; Z80: C set
        rts
fin:    stx     zbc+1
        clc
        rts
.endproc

; 20A4 iso_orient_relative: A = (A - camera orientation) & 3 (the Z80's SUB operand at 20A5h).
.proc iso_orient_relative
        sec
        sbc     D64_ISO_CAMERA_ORIENT
        and     #3
        rts
.endproc

; 1E22 iso_fetch_operand: A = [IX], IX + 1, then 1E27 iso_operand_value (the Z80 falls into it).
        .export iso_fetch_operand
        .import iso_operand_value
.proc iso_fetch_operand
        ldy     #0
        lda     (zix),y
        inc     zix
        bne     :+
        inc     zix+1
:       jmp     iso_operand_value
.endproc
