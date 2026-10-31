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

; abadia64ks, FOR THE CHECKS OF THE GROUP objetos_sonido ONLY (not part of the game; delete when the group
; personajes delivers chr_project): the test mode of 2632 chr_project, the projection that spr_project_entity
; (0ABC) uses.  chr_project cannot be a stub: it is in no table of the C translation, and when visible it drops
; its return address and returns to its caller's caller, which a trap (llama_z80) cannot follow.
; The contract (the Z80's, with the 6502 stack): In IY = the entity, IX = its sprite.  Not visible: RTS to the
; caller.  Visible: PLA, PLA (POP DE at 267D) and, with [D64_CHR_PROJECT_TEST] = C9h (RET at 2684), RTS to the
; caller's caller with A = depth max(0, x + y - 10h), HL = screen (H line, L byte), C = x + y; [spr+12h,13h] =
; the rotated position either way once the floor matches.  The normal mode (2684 = NOP) is not here: it loops.
        .include "zp.inc"
        .include "mapa64.inc"
        .export chr_project
        .import iso_floor_base
        .import iso_rotate_cam0, iso_rotate_cam1, iso_rotate_cam2, iso_rotate_cam3     ; for the vector 2656

.segment "CODE"

.proc chr_project
        ldy     #2
        lda     (ziy),y
        sec
        sbc     D64_CHR_ROOM_ORIGIN_X
        bcc     fin
        cmp     #$28
        bcs     fin
        sta     zhl
        iny
        lda     (ziy),y
        sec
        sbc     D64_CHR_ROOM_ORIGIN_Y
        bcc     fin
        cmp     #$28
        bcs     fin
        sta     zhl+1
        iny
        lda     (ziy),y
        jsr     iso_floor_base
        lda     zbc+1
        cmp     D64_CHR_ROOM_FLOOR
        bne     fin
        ldy     #4
        lda     (ziy),y
        sec
        sbc     zbc+1
        sta     zbc+1                   ; B = the height over the floor
        jsr     rota
        ldy     #$12
        lda     zhl
        sta     (zix),y
        iny
        lda     zhl+1
        sta     (zix),y
        clc
        adc     zhl
        sta     zbc                     ; C = x + y
        sec
        sbc     zbc+1
        bcc     fin
        sbc     #6
        bcc     fin
        cmp     #8
        bcc     fin
        cmp     #$3A
        bcs     fin
        adc     #1
        asl
        asl
        sta     zbc+1                   ; B = the line
        lda     zhl
        sec
        sbc     zhl+1
        asl
        clc
        adc     #$50
        sec
        sbc     #$28
        bcc     fin
        cmp     #$50
        bcs     fin
        sta     zhl
        lda     zbc+1
        sta     zhl+1
        pla                             ; visible: POP DE
        pla
        lda     zbc
        sec
        sbc     #$10
        bcs     :+
        lda     #0
:       ldx     D64_CHR_PROJECT_TEST
        cpx     #$C9
        bne     normal
fin:    rts
normal: jmp     normal
rota:   jmp     (D64_CHR_CAMERA_TRANSFORM)
.endproc
