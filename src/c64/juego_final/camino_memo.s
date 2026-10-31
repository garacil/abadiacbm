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

; abadia64ks, 6502 code of the game: a memo of the whole route search between rooms (M4, measured and
; verified in the speed work's round 5; M1 moved up to camino_room_to_room's entry).  camino_room_to_room (0734)
; searches the floor's room graph (chr_path_floor_to_screen, 8 700 cycles), clears its marks
; (chr_path_clear_room_marks, 4 070) and, when it found the next room, builds the character's grid, marks the exit
; band and searches it (~77 000 cycles when that fails).  The Z80 repeats that failing call every frame while
; nothing changes (Severin from frame 674 of the no-keys run); this memo keeps the last failing one: its inputs (the
; key) and the compared bytes it left (the outputs).  A later call whose key equals the stored one replays the
; outputs and returns as the call returns (C = 0): the 6502 being deterministic, a call that reads the same bytes
; does the same.
;
; The key = every byte the call can read before writing it that is not a constant: HL (the destination room),
; IY and cam_chr (the character: equal at both entries, kept both), 3F72h (the floor search's target test),
; 3F73h (the floor's map), the doors (36), +2..+5 of the six records, the camera room 28C6h-28C8h, 40C2
; (la_busca's square check), and of the room links the 12 door bytes (obj_door_link_table's indices).  The rest
; of the room links is in it by an invariant (a design decision; M4 in doc/ESTADO.md): their bits 6-7
; are 0 outside a floor search (its only setters, chr_path_floor_to_screen and la_busca's floor mode, are reached
; from two places, each followed by chr_path_clear_room_marks) and their bits 0-5 change only in those 12 bytes
; (obj_set_door_permissions is the only store that changes them).  Also in the key, though written before read:
; chr_grid_owner (0027) and the four height-buffer operands 0055-0058, outputs the call may leave unwritten (as M1).
; Not in it (as M1): the floor height lists (constant but the library's mirror record: a search on floor 2 is never
; stored), the character, exit and door-step tables, iso_mul24 (constants), the height-list cache and
; chr_fill_height_buffer's patched stores (caches), the grid and the queue (written before read), la_busca's
; operands and exact-mode patch, the dummy reads of the BIT-skips at 090A.
;
; The outputs = every compared byte the failing call writes: chr_grid_owner, the window origin 003D-003E, the
; height-buffer operands 0055-005A, 005F-0062 (chr_path_height, 40C2 unchanged, chr_path_solution), the exit
; routine 0200, the candidate list's FFh 021A and its pointer 0227, chr_hbuf_ptr 02AF, chr_path_origin / dest /
; result 02D7-02DB, chr_shown_floor 02DF, the floor heights pointer 05DB, chr_path_orientation and length
; 0681-0682, and cam_drv (camino_drive reads it after think); then EI (the search ends with EI) and C = 0.  What a
; hit leaves unwritten: the zero-page registers and scratch ($02-$23; chr_path_find's callers use only its C),
; camino's $A2-$A4/$A6-$A7 (written before read by their users), the room links (the call's net effect on them is
; none under the invariant: the floor search's marks are cleared in the call), the grid, the queue and the mirror
; buffers they overlap (excluded blocks of juego6502.tsv: written before read).
;
; Lookup: on a miss the entry is kept (the key's 8 bytes the call changes go to memo_pend); memo_guarda, after a
; failing grid part, stores memo_pend, the rest of the key, the outputs and the door bytes.  Placement: ten pieces
; of the bitmap's invisible bytes, declared in mapa64.py (PIEZAS_CAMINO: segments CODEMEMO01-10), camino.s changed
; in two instructions only.
.ifdef VELOZ                    ; (abadia128ks only: the 128ks optimised for speed)
        .include "zp.inc"
        .include "mapa.inc"

        .export memo_sala, memo_fin
        .import camino_hl_origin, camino_search_to_marks, plat_ei

cam_chr = $9E                   ; camino's: the character of the search
cam_drv = $A5                   ; camino's: the exit table index (read by camino_drive after think)

NKB     = 3                     ; the key runs the call changes (8 bytes: memo_pend on a miss)
ND1     = 7                     ; the key runs kept in memo_d2 (then memo_d1)
NK      = 16                    ; the key runs
NR      = 29                    ; all the runs: the key's, then the outputs'
NB      = 8                     ; bytes of the first NKB runs
NB2     = 15                    ; bytes of the first ND1 runs (memo_d2's key part)

        .assert D64_CHR_PATH_SMC_RET = D64_CHR_PATH_HEIGHT + 1 && D64_CHR_PATH_SOLUTION = D64_CHR_PATH_HEIGHT + 2, error, "005F-0062"
        .assert D64_CHR_HBUF_ORIGIN_X = D64_CHR_HBUF_ORIGIN_Y + 1, error, "003D-003E"
        .assert D64_CHR_HBUF_WIN_Y_OP = D64_CHR_HBUF_FLAT_WIDTH_OP + 5, error, "0055-005A"
        .assert D64_CHR_PATH_RESULT = D64_CHR_PATH_ORIGIN + 4, error, "02D7-02DB"
        .assert D64_CHR_PATH_LENGTH = D64_CHR_PATH_ORIENTATION + 1, error, "0681-0682"
        .assert D64_CHR_ROOM_LINKS_SIZE = $130, error, "the room links"

; ---- the hooks in camino_room_to_room (camino.s): its first and last instructions
.segment "CODE"

; ---- m_pcmp: the room links' 12 door bytes against the entry's (obj_door_link_table: 6 doors of 5 bytes, the two
; indices at +0 and +2).  Out: Z = 1 equal.  Keeps X; uses A Y zt0 zt0+1.
m_pcmp: stx     zt0+1
        ldx     #25
        lda     #10
        sta     zt0
@l:     ldy     D64_OBJ_DOOR_LINK_TABLE,x
        lda     D64_CHR_ROOM_LINKS,y
        ldy     zt0
        cmp     memo_pu,y
        bne     @f
        ldy     D64_OBJ_DOOR_LINK_TABLE+2,x
        lda     D64_CHR_ROOM_LINKS,y
        ldy     zt0
        cmp     memo_pu+1,y
        bne     @f
        dec     zt0
        dec     zt0
        txa
        sbc     #5                      ; (C = 1 from the equal CMP)
        tax
        bcs     @l
        ldx     zt0+1
        lda     #0                      ; Z = 1
        rts
@f:     ldx     zt0+1
        lda     #1                      ; Z = 0
        rts
p7b:
        .assert p7b - m_pcmp <= 64, error, "MEMO7 overflows its 64 bytes"

.segment "CODE"
; memo_fin (was jmp camino_search_to_marks): the grid search; a failure is kept (memo_guarda).  Out: C = a route.
memo_fin:
        jsr     camino_search_to_marks
        bcs     @r
        jmp     memo_guarda
@r:     rts

; ---- m_rep: a hit, the outputs back (runs NK.. from memo_d2 + NB2), then EI, C = 1.  In: X = NK, zp0+2 set.
m_rep:  lda     m_slo,x                 ; (m_src inline)
        sta     zp0
        lda     m_shi,x
        sta     zp0+1
        ldy     m_n,x
        dey
@r:     lda     (zp0+2),y
        sta     (zp0),y
        dey
        bpl     @r
        jsr     m_adv
        cpx     #NR
        bne     m_rep
        jsr     plat_ei
        sec
        rts
; m_copia: runs X .. zt0-1 copied to the stored entry at zp0+2.
m_copia:
        jsr     m_src
@c:     lda     (zp0),y
        sta     (zp0+2),y
        dey
        bpl     @c
        jsr     m_adv
        cpx     zt0
        bne     m_copia
        rts
p5b:
        .assert p5b - memo_fin <= 64, error, "MEMO5 overflows its 64 bytes"

.segment "CODE"
; ---- memo_busca: the key against the stored entry's.  Equal: the outputs replayed, EI, C = 1.  Else (or no
; entry): the key's first 8 bytes (those the call may change) kept in memo_pend, the entry kept, C = 0.
; Uses A X Y, zp0..zp0+3, zt0, zt0+1.
memo_busca:
        bit     memo_ok
        bpl     @f
        lda     #<memo_d2
        sta     zp0+2
        lda     #>memo_d2
        sta     zp0+3
        ldx     #0
@run:   lda     m_slo,x                 ; (m_src inline)
        sta     zp0
        lda     m_shi,x
        sta     zp0+1
        ldy     m_n,x
        dey
@b:     lda     (zp0),y
        cmp     (zp0+2),y
        bne     @f
        dey
        bpl     @b
        jsr     m_adv
        cpx     #NK
        bne     @run
        jsr     m_pcmp
        bne     @f
        jmp     m_rep
@f:     jmp     m_falla
p2a:
memo_pend:      .res    NB              ; the key's first 8 bytes at the last lookup
p2b:
        .assert p2b - memo_busca <= 64, error, "MEMO2 overflows its 64 bytes"

.segment "CODE"
; ---- m_adv: zp0+2 past run X, X + 1; memo_d1 after the first ND1 runs, memo_d2 + NB2 after the key's.
m_adv:  lda     m_n,x
        clc
        adc     zp0+2
        sta     zp0+2
        bcc     :+
        inc     zp0+3
:       inx
        cpx     #ND1
        beq     @d1
        cpx     #NK
        bne     @r
        lda     #<(memo_d2 + NB2)
        sta     zp0+2
        lda     #>(memo_d2 + NB2)
        sta     zp0+3
@r:     rts
@d1:    lda     #<memo_d1
        sta     zp0+2
        lda     #>memo_d1
        sta     zp0+3
        rts
; m_src: zp0 = run X's bytes, Y = its length - 1.
m_src:  lda     m_slo,x
        sta     zp0
        lda     m_shi,x
        sta     zp0+1
        ldy     m_n,x
        dey
        rts
p6b:
        .assert p6b - m_adv <= 64, error, "MEMO6 overflows its 64 bytes"

.segment "CODE"
; ---- m_falla: a miss (or no entry): the key's first NKB runs to memo_pend; the entry is kept.  Out: C = 0.
m_falla:
        lda     #<memo_pend
        sta     zp0+2
        lda     #>memo_pend
        sta     zp0+3
        ldx     #NKB
        stx     zt0
        ldx     #0
        jsr     m_copia
        clc
        rts
; ---- memo_guarda (after the grid part failed, C = 0): memo_pend, the rest of the key, the outputs and the door
; bytes stored, the entry valid; not when the grid was the library's floor (its heights list holds the mirror's
; record, not in the key).  Out: C = 0.
memo_guarda:
        lda     D64_CHR_FLOOR_HEIGHTS_PTR+1
        cmp     #>D64_CHR_FLOOR2_HEIGHTS
        beq     @no
        ldy     #NB - 1
@p:     lda     memo_pend,y
        sta     memo_d2,y
        dey
        bpl     @p
        lda     #<(memo_d2 + NB)
        sta     zp0+2
        lda     #>(memo_d2 + NB)
        sta     zp0+3
        ldx     #NR
        stx     zt0
        ldx     #NKB
        jsr     m_copia
        jsr     m_pcopia
        lda     #$80
        sta     memo_ok
@no:    clc
        rts
p8b:
        .assert p8b - m_falla <= 64, error, "MEMO8 overflows its 64 bytes"

.segment "CODE"
; memo_sala (was jsr camino_hl_origin): the lookup; a hit returns to camino_room_to_room's caller with C = 0.
memo_sala:
        jsr     memo_busca
        bcc     @no
        pla                             ; a hit: the outputs are back; camino_room_to_room returns, no route
        pla
        clc
        rts
@no:    jmp     camino_hl_origin        ; a miss: the instruction it replaces (returns into camino_room_to_room)
; ---- m_pcopia: the room links' 12 door bytes into the entry (as m_pcmp).  Uses A X Y zt0.
m_pcopia:
        ldx     #25
        ldy     #10
@l:     sty     zt0
        ldy     D64_OBJ_DOOR_LINK_TABLE,x
        lda     D64_CHR_ROOM_LINKS,y
        ldy     zt0
        sta     memo_pu,y
        ldy     D64_OBJ_DOOR_LINK_TABLE+2,x
        lda     D64_CHR_ROOM_LINKS,y
        ldy     zt0
        sta     memo_pu+1,y
        dey
        dey
        txa
        sec
        sbc     #5
        tax
        bcs     @l
        rts
p10b:
        .assert p10b - memo_sala <= 56, error, "MEMO10 overflows its 56 bytes"

.segment "CODE"
m_n:    .byte   2, 2, 4                                         ; memo_pend / memo_d2: the key's first 8
        .byte   2, 2, 1, 2                                      ; memo_d2 + 8: 7
        .byte   36, 4, 4, 4, 4, 4, 4, 3, 1                      ; memo_d1: 64
        .byte   2, 2, 6, 4, 2, 1, 2, 2, 5, 1, 2, 2, 1           ; memo_d2 + 15: the outputs, 32
p9b:
        .assert p9b - m_n = NR, error, "the runs"
        .assert p9b - m_n <= 40, error, "MEMO9 overflows its 40 bytes"

.segment "CODE"
; the runs: the key's (zhl, chr_grid_owner, the four height-buffer operands 0055-0058; IY, cam_chr, 3F72h, 3F73h;
; the doors, +2..+5 of the six records, the camera room 28C6h, 40C2), then the outputs'
m_slo:  .lobytes zhl, D64_CHR_GRID_OWNER, D64_CHR_HBUF_FLAT_WIDTH_OP
        .lobytes ziy, cam_chr, D64_CHR_PATH_FLOOR_TARGET_TEST, D64_CHR_PATH_ROOM_LINKS_PTR
        .lobytes D64_OBJ_DOORS, D64_CHR_GUILLERMO+2, D64_CHR_ADSO+2, D64_CHR_MALACHI+2, D64_CHR_ABBOT+2
        .lobytes D64_CHR_BERENGAR+2, D64_CHR_SEVERIN+2, D64_CHR_ROOM_X, D64_CHR_PATH_SMC_RET
        .lobytes D64_CHR_GRID_OWNER, D64_CHR_HBUF_ORIGIN_Y, D64_CHR_HBUF_FLAT_WIDTH_OP, D64_CHR_PATH_HEIGHT
        .lobytes D64_CHR_EXIT_MARK_ROUTINE, D64_CHR_PATH_ALTERNATIVES+3, D64_CHR_PATH_ALT_PTR, D64_CHR_HBUF_PTR
        .lobytes D64_CHR_PATH_ORIGIN, D64_CHR_SHOWN_FLOOR, D64_CHR_FLOOR_HEIGHTS_PTR, D64_CHR_PATH_ORIENTATION
        .lobytes cam_drv
m_shi:  .hibytes zhl, D64_CHR_GRID_OWNER, D64_CHR_HBUF_FLAT_WIDTH_OP
        .hibytes ziy, cam_chr, D64_CHR_PATH_FLOOR_TARGET_TEST, D64_CHR_PATH_ROOM_LINKS_PTR
        .hibytes D64_OBJ_DOORS, D64_CHR_GUILLERMO+2, D64_CHR_ADSO+2, D64_CHR_MALACHI+2, D64_CHR_ABBOT+2
        .hibytes D64_CHR_BERENGAR+2, D64_CHR_SEVERIN+2, D64_CHR_ROOM_X, D64_CHR_PATH_SMC_RET
        .hibytes D64_CHR_GRID_OWNER, D64_CHR_HBUF_ORIGIN_Y, D64_CHR_HBUF_FLAT_WIDTH_OP, D64_CHR_PATH_HEIGHT
        .hibytes D64_CHR_EXIT_MARK_ROUTINE, D64_CHR_PATH_ALTERNATIVES+3, D64_CHR_PATH_ALT_PTR, D64_CHR_HBUF_PTR
        .hibytes D64_CHR_PATH_ORIGIN, D64_CHR_SHOWN_FLOOR, D64_CHR_FLOOR_HEIGHTS_PTR, D64_CHR_PATH_ORIENTATION
        .hibytes cam_drv
p4b:
        .assert m_shi - m_slo = NR, error, "the runs"
        .assert p4b - m_slo <= 64, error, "MEMO4 overflows its 64 bytes"

.segment "CODE"
memo_d1:        .res    64                      ; the key's runs ND1 .. NK-1
.segment "CODE"
memo_ok:        .byte   0                       ; bit 7: an entry is stored (0 in the image: none)
memo_d2:        .res    NB2 + 32                ; the key's first ND1 runs, then the outputs
memo_pu:        .res    12                      ; the room links' 12 door bytes
p3b:
        .assert p3b - memo_ok <= 64, error, "MEMO3 overflows its 64 bytes"
.endif
