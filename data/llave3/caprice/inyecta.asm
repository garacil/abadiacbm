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
; data/llave3/caprice/inyecta.asm: the key script inside the CPC game, for a run on Caprice32 where keys
; cannot be held from outside frame by frame.  CALLed from 2D77 (the IN A,(C) / LD B,A of sys_read_keyboard
; 2D50, patched into CALL 3200h): the row the keyboard gives, ANDed with the script's mask of this row for the
; current game frame (rows 0 and 1: cursor up, right, down; cursor left), the other rows unchanged.  The game
; frame is the counter at 01F0h that the main loop's patched head (217Ah: CALL 01C0h) increments.  The table:
; entries of 4 bytes (from game frame: word; row 0 mask; row 1 mask), sorted, the last one from FFFFh.
; In: C = row | 40h (B, C are the caller's).  Out: A = B = the row; C, DE, HL kept.
CUENTA: equ 01F0h
        org 3200h
inyecta:
        in a,(c)
        push bc
        push de
        push hl
        ld e,a
        ld a,c
        and 0Fh
        cp 2
        jr nc,fuera
        ld d,a
        ld hl,(puntero)
siguiente:
        push hl
        ld bc,4
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld hl,(CUENTA)
        or a
        sbc hl,bc
        pop hl
        jr c,usa
        ld bc,4
        add hl,bc
        ld (puntero),hl
        jr siguiente
usa:    inc hl
        inc hl
        ld a,d
        or a
        jr z,fila0
        inc hl
fila0:  ld a,e
        and (hl)
        ld e,a
fuera:  ld a,e
        pop hl
        pop de
        pop bc
        ld b,a
        ret
puntero:
        dw tabla
tabla:
