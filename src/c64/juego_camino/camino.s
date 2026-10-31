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

; abadia64ks, 6502 code of the game: group camino (Z80 0000-0982: the monks' drivers 036D-04EB, the route
; planner, the path search's high level, its grid, the exits, the command writer; C reference
; juego/f_camino.c, and juego/funciones.c for 08E5 and 0944).  Registers as c64/CODIGO6502.md: the Z80
; pairs in zero page, A in A, the Z80's CF in the 6502's C.  Notes: c64/juego_camino/NOTAS.md.
;
; The path searches proper (3F92, 3F9E, 438F, 4399) and the command generators (434F, 41A8, 432C) belong to
; group logica_a: they keep the Z80 stack as their queue (877Eh down, chr_path_saved_sp 2901h).  Nothing
; here touches that queue: this code only stores the queue entry a search returns in HL into
; chr_path_solution (41D4h), which chr_cmd_generate reads back.  The `sp` of the C functions (the Z80 SP
; handed down to the searches) has no counterpart here.
        .include "zp.inc"
        .include "mapa64.inc"

        .export ai_update_malachi, ai_update_abbot, ai_update_berengar, ai_update_severin, ai_update_adso
        .export chr_path_add_targets_around, chr_path_add_target_beside, ai_check_planned_move
        .export chr_cmd_discard, chr_path_find, chr_path_face_target, chr_cmd_rewind, chr_room_coords
        .export chr_path_clear_room_marks, chr_path_via_rooms, chr_path_search_to_dest
        .export chr_path_restore_screen_grid, iso_grid_set_origin, chr_path_clear_grid_marks
        .export chr_path_build_grid, chr_path_mark_exit_up, chr_path_mark_exit_right
        .export chr_path_mark_exit_left, chr_path_mark_exit_down, iso_grid_cell_of, iso_grid_cell_ptr
        .export chr_cmd_write_bits, chr_room_distance_near

        .import iso_floor_base                                          ; motor_iso
        .import ai_malachi_think, ai_abbot_think, ai_berengar_think     ; the monks' behaviour (logica_b)
        .import ai_severin_think, ai_adso_think
        .import obj_set_door_permissions                                ; estado_texto
        .import chr_update, chr_to_hbuf_coords, chr_fill_height_buffer  ; personajes
        .import chr_mark_hbuf, chr_probe_ahead_flat, sys_key_down
        .import obj_door_mark_cells, chr_path_reset_alternatives        ; objetos_sonido
        .import chr_path_room_to_marked, chr_path_room_search           ; logica_a: the searches
        .import chr_path_floor_to_screen, chr_path_floor_search
        .import chr_cmd_generate, chr_cmd_write_turn, chr_cmd_write_one_step
        .import chr_adso_step_aside, chr_adso_step_guillermo_dir, util_return_zero

; the group's zero page ($9E-$A9, c64/CODIGO6502.md)
cam_chr = $9E                   ; 2: the character (IY) of the search, kept across calls
cam_tgt = $A0                   ; 2: the target (IX) of chr_path_find
cam_ptr = $A2                   ; 2: the chr_table / door walk of chr_path_build_grid
cam_n   = $A4                   ; 1: loop counter
cam_drv = $A5                   ; 1: the driver; the exit table index
cam_dx  = $A6                   ; 1: chr_path_build_grid's room distances (the Z80's B, C)
cam_dy  = $A7
cam_o   = $A8                   ; 1: the orientation in chr_path_add_target_beside (its PUSH BC)

.segment "CODE"

; ======================================================================================== the drivers

; 036D ai_update_malachi, 038E ai_update_abbot, 04A0 ai_update_berengar, 04C1 ai_update_severin: one
; driver, X = the monk (the opcode 2Ch, BIT abs, skips the next LDX): camino_drive, then 03AC.
ai_update_malachi:
        ldx     #0
        .byte   $2C                     ; BIT $01A2: skips LDX #1
ai_update_abbot:
        ldx     #1
        .byte   $2C
ai_update_berengar:
        ldx     #2
        .byte   $2C
ai_update_severin:
        ldx     #3
        jsr     camino_drive
        jmp     camino_plan_route

; The common part of the drivers (X = 0 Malachi, 1 the abbot, 2 Berengar, 3 Severin, 4 Adso): ai_no_route
; [37E9] = 0; the behaviour (IY = record, IX = places, A = 0); the door permissions (C = the mask;
; Berengar's is the operand 04B0h, script variable A9); chr_update (HL = the chr_table entry).  Out: IY =
; the record chr_update worked on ([247E]), IX = the places.
.proc camino_drive
        stx     cam_drv
        lda     #0
        sta     D64_AI_NO_ROUTE
        lda     drv_rec_lo,x
        sta     ziy
        lda     #>D64_CHR_MALACHI       ; (one page: asserted below)
        sta     ziy+1
        jsr     places
        jsr     think
        ldx     cam_drv
        lda     drv_mask,x
        cpx     #2
        bne     :+
        lda     D64_AI_BERENGAR_DOOR_MASK
:       sta     zbc
        jsr     obj_set_door_permissions
        ldx     cam_drv
        lda     drv_tab_lo,x
        sta     zhl
        lda     #>D64_CHR_TABLE_MALACHI
        sta     zhl+1
        jsr     chr_update
        lda     D64_CHR_CUR_DATA
        sta     ziy
        lda     D64_CHR_CUR_DATA+1
        sta     ziy+1
        ldx     cam_drv
places: lda     drv_pl_lo,x
        sta     zix
        lda     #>D64_AI_MALACHI_PLACES
        sta     zix+1
        rts
think:  lda     drv_th_hi,x             ; the behaviour routine, through RTS
        pha
        lda     drv_th_lo,x
        pha
        lda     #0                      ; XOR A: A = 0, Z set, C clear
        clc
        rts

drv_rec_lo: .lobytes D64_CHR_MALACHI, D64_CHR_ABBOT, D64_CHR_BERENGAR, D64_CHR_SEVERIN, D64_CHR_ADSO
drv_pl_lo:  .lobytes D64_AI_MALACHI_PLACES, D64_AI_ABBOT_PLACES, D64_AI_BERENGAR_PLACES, D64_AI_SEVERIN_PLACES, D64_AI_ADSO_PLACES
drv_tab_lo: .lobytes D64_CHR_TABLE_MALACHI, D64_CHR_TABLE_ABBOT, D64_CHR_TABLE_BERENGAR, D64_CHR_TABLE_SEVERIN, D64_CHR_TABLE_ADSO
drv_th_lo:  .lobytes ai_malachi_think-1, ai_abbot_think-1, ai_berengar_think-1, ai_severin_think-1, ai_adso_think-1
drv_th_hi:  .hibytes ai_malachi_think-1, ai_abbot_think-1, ai_berengar_think-1, ai_severin_think-1, ai_adso_think-1
drv_mask:   .byte   $3F, $3F, $3F, $2F, $3C
        .assert >D64_CHR_MALACHI = >D64_CHR_ADSO && >D64_CHR_ABBOT = >D64_CHR_ADSO && >D64_CHR_BERENGAR = >D64_CHR_ADSO && >D64_CHR_SEVERIN = >D64_CHR_ADSO, error, "records: one page"
        .assert >D64_AI_MALACHI_PLACES = >D64_AI_ADSO_PLACES && >D64_AI_ABBOT_PLACES = >D64_AI_ADSO_PLACES && >D64_AI_BERENGAR_PLACES = >D64_AI_ADSO_PLACES && >D64_AI_SEVERIN_PLACES = >D64_AI_ADSO_PLACES, error, "places: one page"
        .assert >D64_CHR_TABLE_MALACHI = >D64_CHR_TABLE_ADSO && >D64_CHR_TABLE_ABBOT = >D64_CHR_TABLE_ADSO && >D64_CHR_TABLE_BERENGAR = >D64_CHR_TABLE_ADSO && >D64_CHR_TABLE_SEVERIN = >D64_CHR_TABLE_ADSO, error, "chr_table: one page"
.endproc

; 03AC (ai_plan_route, the shared tail of the drivers): a move already planned (bit 7 of [chr+9] clear) ->
; ai_check_planned_move; ai_no_route set -> nothing.  Destination d = [places-1]: FF/FE/FD/FC = Guillermo /
; the abbot / the book / the parchment, whose four neighbours are the candidates (slot 0201h); else the
; place p = places + 3d (8 bit) is copied to 0203h (FF after it) and its neighbours follow (slot 0204h).
; chr_path_alt_ptr [0213] = 0203h; a candidate -> chr_path_find; result FD (already there) -> [places-3] =
; [places-1].  In: IY = chr, IX = places.
.proc camino_plan_route
        ldy     #9
        lda     (ziy),y
        bmi     plan
        jmp     ai_check_planned_move
plan:   lda     D64_AI_NO_ROUTE
        beq     :+
        rts
:       lda     zix                     ; places - 3: [+0] reached, [+2] the destination
        sec
        sbc     #3
        sta     zp0
        pha                             ; (the Z80's PUSH IX)
        lda     zix+1
        sbc     #0
        sta     zp0+1
        pha
        ldy     #2
        lda     (zp0),y                 ; d
        cmp     #$FC
        bcs     fixed
        sta     zt0
        asl
        clc
        adc     zt0                     ; 3 d (8 bit)
        clc
        adc     zix
        sta     zt0
        lda     zix+1
        adc     #0
        sta     zt0+1                   ; p
        ldy     #2                      ; LDI x 3, then FF
:       lda     (zt0),y
        sta     D64_CHR_PATH_ALTERNATIVES,y
        dey
        bpl     :-
        lda     #$FF
        sta     D64_CHR_PATH_ALTERNATIVES+3
        lda     zt0                     ; HL = p - 2: a pseudo record (x +2, y +3, z +4)
        sec
        sbc     #2
        sta     zhl
        lda     zt0+1
        sbc     #0
        sta     zhl+1
        ldx     #<(D64_CHR_PATH_ALTERNATIVES+1)
        ldy     #>(D64_CHR_PATH_ALTERNATIVES+1)
        jmp     around
fixed:  and     #3                      ; FC parchment, FD book, FE abbot, FF Guillermo
        asl
        tax
        lda     fixed_targets,x
        sta     zhl
        lda     fixed_targets+1,x
        sta     zhl+1
        ldx     #<D64_CHR_PATH_SLOT
        ldy     #>D64_CHR_PATH_SLOT
around: stx     zde
        sty     zde+1
        jsr     camino_save_iy          ; PUSH IY
        jsr     chr_path_add_targets_around
        lda     #<D64_CHR_PATH_ALTERNATIVES
        sta     zix
        sta     D64_CHR_PATH_ALT_PTR
        lda     #>D64_CHR_PATH_ALTERNATIVES
        sta     zix+1
        sta     D64_CHR_PATH_ALT_PTR+1
        jsr     camino_iy               ; POP IY
        lda     D64_CHR_PATH_ALTERNATIVES
        cmp     #$FF
        beq     drop                    ; no candidate
        jsr     chr_path_find
        pla                             ; POP IX
        sta     zp0+1
        pla
        sta     zp0
        lda     D64_CHR_PATH_RESULT
        cmp     #$FD
        bne     done
        ldy     #2                      ; there: [places-3] = [places-1]
        lda     (zp0),y
        ldy     #0
        sta     (zp0),y
done:   rts
drop:   pla
        pla
        rts

fixed_targets:  .word   D64_OBJ_PARCHMENT, D64_OBJ_OBJECTS, D64_CHR_ABBOT, D64_CHR_GUILLERMO
.endproc

; 042D chr_path_add_targets_around: chr_path_add_target_beside four times, orientation [target+1], +1, +2,
; +3.  In: HL = target, DE = slot.  Out: IX = target, IY = the last slot, B.
.proc chr_path_add_targets_around
        lda     zhl
        sta     zix
        lda     zhl+1
        sta     zix+1
        lda     zde
        sta     ziy
        lda     zde+1
        sta     ziy+1
        ldy     #1
        lda     (zix),y
        sta     zbc+1
        lda     #4
        sta     cam_n
loop:   jsr     chr_path_add_target_beside
        dec     cam_n
        beq     done
        inc     zbc+1                   ; (B is 1..4 here: always taken)
        bne     loop
done:   rts
.endproc

; 0442 chr_path_add_target_beside: o = B & 3; the candidate at slot+2: x = [target+2] + dx, y = [target+3]
; + dy (chr_beside_offsets 0215h), byte 2 = ((o ror 2) xor 80h) & C0h | [target+4].  The slot is located
; as a pseudo record ([slot+4] = [target+4] meanwhile): outside the height buffer, or (z - floor base(z) -
; ([cell] & EFh) + 1) < 6 -> accepted: IY = slot + 3, FF at IY+2; else FF at slot+2.  In: B, IX = target,
; IY = slot.  Out: IX = target, IY = the next slot, B = o, C = byte 2.
.proc chr_path_add_target_beside
        lda     zix                     ; PUSH IX
        sta     zp0
        lda     zix+1
        sta     zp0+1
        lda     zbc+1
        and     #3
        sta     zbc+1
        sta     cam_o
        tax
        lda     facing,x
        ldy     #4
        ora     (zix),y
        sta     zbc                     ; C = byte 2
        lda     (zix),y
        sta     (ziy),y                 ; [slot+4] = z meanwhile
        ldy     #2
        lda     (zix),y
        sta     zt0+1                   ; the target's x
        iny
        lda     (zix),y
        sta     zt0+2                   ; and y
        lda     zix+1                   ; an object held by a character (bit 7 of +0) keeps its holder's
        cmp     #>D64_OBJ_OBJECTS       ; address there (a C64 address, punteros64 `held`): the Z80 reads
        bne     xy                      ; the CPC address's bytes as x, y (the book / the parchment as a
        lda     zix                     ; destination while somebody carries it)
        sec
        sbc     #<D64_OBJ_OBJECTS
        cmp     #46                     ; inside the object records?
        bcs     xy
        ldy     #0
        lda     (zix),y
        bpl     xy
        lda     zt0+1
        clc
        adc     #<HOLDER_CPC
        sta     zt0+1
        lda     zt0+2
        adc     #>HOLDER_CPC
        sta     zt0+2
xy:     txa
        asl
        tax
        lda     zt0+1
        clc
        adc     D64_CHR_BESIDE_OFFSETS,x
        ldy     #2
        sta     (ziy),y
        lda     zt0+2
        clc
        adc     D64_CHR_BESIDE_OFFSETS+1,x
        iny
        sta     (ziy),y
        jsr     iso_grid_cell_of        ; the slot's cell (IY = the slot)
        ldy     #4                      ; (the carry is kept down to the BCS)
        lda     zbc
        sta     (ziy),y                 ; [slot+4] = byte 2
        ldy     #0
        lda     (zix),y                 ; the cell (the target's first byte when outside, as the Z80)
        ldx     zp0                     ; POP IX
        stx     zix
        ldx     zp0+1
        stx     zix+1
        bcs     accept                  ; outside the buffer
        and     #$EF                    ; the 10h mark of other characters ignored
        sta     zt0
        ldy     #4
        lda     (zix),y                 ; z
        jsr     iso_floor_base          ; (A kept)
        sec
        sbc     zbc+1
        sec
        sbc     zt0
        clc
        adc     #1
        cmp     #6
        bcs     tail                    ; rejected: FF at slot+2
accept: lda     ziy                     ; accepted: IY = slot + 3, FF at its +2
        clc
        adc     #3
        sta     ziy
        bcc     tail
        inc     ziy+1
tail:   ldx     cam_o                   ; POP BC: B = o
        stx     zbc+1
        lda     #$FF
        ldy     #2
        sta     (ziy),y
        rts

facing: .byte   $80, $C0, $00, $40      ; ((o ror 2) xor 80h) & C0h for o = 0..3
HOLDER_CPC = $28B9 - D64_CHR_BACKUP     ; C64 -> CPC for an address in D64_CHR_BACKUP (CPC 28B9h)
        .assert >D64_OBJ_OBJECTS = >(D64_OBJ_OBJECTS + 45), error, "the object records cross a page"
.endproc

; 04EB ai_update_adso: driver of Adso (X = 4 in camino_drive).  A destination ([3860] != FF) -> 03AC like a
; monk.  Following Guillermo: nothing while the camera follows another character ([37DC] >= 2); a planned
; move that failed is counted in [28FB] up to 10, then discarded; no plan: sys_key_down(17h),
; util_return_zero (RET NZ); [2907] = 0; Adso off the height buffer -> chr_path_find(Adso, Guillermo's
; position) and, when found, the driver again; key 0 down and a cell ahead of Guillermo (2917, 2918, 291B,
; 291C bit 5) holds Adso -> JP 410D; key 2 -> JP 40EB (both run the driver again when he moved); else a grid
; search from Guillermo to Adso gives the path length [3F82]; a long enough path (4 when Adso uses one cell
; or shares no coordinate with Guillermo, else 3) writes one step in orientation [3F81] (41A8) and the
; driver runs again (JP 04EB: a loop).
.proc ai_update_adso
        ldx     #4
        jsr     camino_drive
        lda     D64_AI_ADSO_DEST
        cmp     #$FF
        beq     follow
        jmp     camino_plan_route
follow: lda     D64_GAME_CAMERA_OTHER
        cmp     #2
        bcc     :+
        rts
:       ldy     #9
        lda     (ziy),y
        bmi     noplan
        lda     D64_CHR_MOVED           ; a planned move: did it fail?
        cmp     #$FF
        bne     :+
        rts
:       inc     D64_AI_ADSO_BLOCKED_COUNT
        lda     D64_AI_ADSO_BLOCKED_COUNT
        cmp     #10
        bcs     :+
        rts
:       lda     #0
        sta     D64_AI_ADSO_BLOCKED_COUNT
        jmp     chr_cmd_discard         ; (falls into 052E)
noplan: lda     #$17
        jsr     sys_key_down
        jsr     util_return_zero
        beq     :+
        rts
:       jsr     iy_adso
        lda     #0
        sta     D64_CHR_PATH_RESULT
        jsr     iso_grid_cell_of
        bcc     inside
        lda     #<(D64_CHR_GUILLERMO+2) ; off the buffer: a route to Guillermo's position
        sta     zix
        lda     #>(D64_CHR_GUILLERMO+2)
        sta     zix+1
        jsr     chr_path_find
        bcc     :+
        jmp     ai_update_adso
:       rts
inside: lda     #0
        jsr     sys_key_down
        beq     key2
        jsr     iy_guillermo            ; (A kept for chr_probe_ahead_flat)
        jsr     chr_probe_ahead_flat
        jsr     iy_adso
        lda     D64_CHR_PROBE+1
        ora     D64_CHR_PROBE+2
        ora     D64_CHR_PROBE+5
        ora     D64_CHR_PROBE+6
        tax
        and     #$20
        beq     key2
        txa
        jmp     chr_adso_step_aside     ; JP 410D (IY = Adso, IX = his cell)
key2:   lda     #2
        jsr     sys_key_down
        beq     search
        jmp     chr_adso_step_guillermo_dir   ; JP 40EB
search: lda     #0                      ; 0581: both out of the buffer
        tax
        jsr     marks
        jsr     iy_guillermo
        jsr     camino_origin           ; [2903] = Guillermo's cell, [2905] = Adso's
        jsr     iy_adso
        jsr     camino_iy_xy
        jsr     camino_hbuf_dest
        jsr     chr_path_room_to_marked
        lda     zhl
        sta     D64_CHR_PATH_SOLUTION
        lda     zhl+1
        sta     D64_CHR_PATH_SOLUTION+1
        jsr     chr_path_clear_grid_marks
        lda     D64_CHR_GUILLERMO+$0E   ; both marked again
        ldx     D64_CHR_ADSO+$0E
        jsr     marks
        lda     D64_CHR_PATH_RESULT
        bne     :+
        rts
:       ldx     #4                      ; the path length needed
        lda     D64_CHR_ADSO+5
        bmi     :+                      ; Adso uses one cell
        dex
        lda     D64_CHR_ADSO+2
        cmp     D64_CHR_GUILLERMO+2
        beq     :+
        lda     D64_CHR_ADSO+3
        cmp     D64_CHR_GUILLERMO+3
        beq     :+
        inx
:       stx     zbc
        lda     D64_CHR_PATH_LENGTH
        cmp     zbc
        bcs     :+
        rts
:       lda     D64_CHR_PATH_ORIENTATION
        sta     zbc
        jsr     chr_cmd_write_one_step  ; IY = Adso, C = the orientation
        jmp     ai_update_adso
marks:  stx     cam_o                   ; chr_mark_hbuf(Guillermo, C = A), chr_mark_hbuf(Adso, C = X)
        sta     zbc
        jsr     iy_guillermo
        jsr     chr_mark_hbuf
        lda     cam_o
        sta     zbc
        jsr     iy_adso
        jmp     chr_mark_hbuf
iy_guillermo:                           ; (A kept)
        ldx     #<D64_CHR_GUILLERMO
        stx     ziy
        ldx     #>D64_CHR_GUILLERMO
        stx     ziy+1
        rts
iy_adso:
        ldx     #<D64_CHR_ADSO
        stx     ziy
        ldx     #>D64_CHR_ADSO
        stx     ziy+1
        rts
.endproc

; 04E2 ai_check_planned_move: the last move attempt failed (chr_moved [2912] != FF) -> chr_cmd_discard.
; In: IY = chr.
ai_check_planned_move:
        lda     D64_CHR_MOVED
        cmp     #$FF
        bne     chr_cmd_discard
        rts

; 052E chr_cmd_discard: command 10h ('think again') at the start of the command buffer [[chr+0Ch]], the
; bit counter [chr+9] and the index [chr+0Bh] cleared.  In: IY = chr.  Out: HL = the buffer; A and the
; flags kept (as the Z80: the script code after 5FCD goes on with them).
.proc chr_cmd_discard
        php
        pha
        ldy     #$0C
        lda     (ziy),y
        sta     zhl
        iny
        lda     (ziy),y
        sta     zhl+1
        ldy     #0
        lda     #$10
        sta     (zhl),y
        tya
        ldy     #9
        sta     (ziy),y
        ldy     #$0B
        sta     (ziy),y
        pla
        plp
        rts
.endproc

; ======================================================================================== the path search

; 05FA chr_path_find: route chr towards the target position (x, y, orient<<6 | z).  chr_path_result [2907]
; = FE; nothing while Guillermo is in mid-step ([0600] odd) or when a route was found in this iteration
; ([28FA]).  Else the floor test of the room search [440D] = BIT 6,(HL), [2907] = 0, chr_path_room_links_ptr
; [3F73] = the room links of the character's floor.  Other floor: stairs in the character's room in the
; wanted direction (bit 10h up / 20h down) -> every grid cell of height [0692] (0Dh / 01h) becomes a target
; (076D); else the room graph (4399, BIT 4 / BIT 5,(HL)) gives the nearest room with stairs (DE) -> 0734.
; Same floor: another room -> chr_path_via_rooms; the same cell -> [2907] = FD and chr_path_face_target;
; another cell -> the grid towards it (chr_path_search_to_dest).  In: IY = chr, IX = target.  Out: CF = a
; route was found (or chr_path_face_target's carry).
.proc chr_path_find
        lda     #$FE
        sta     D64_CHR_PATH_RESULT
        lda     D64_CHR_GUILLERMO_ANIM_COPY
        and     #1
        bne     no                      ; RET NZ (CF = 0 after AND)
        lda     D64_CHR_PATH_FOUND_NOW
        bne     no
        lda     #$76                    ; BIT 6,(HL): a marked cell is the target
        sta     D64_CHR_PATH_FLOOR_TARGET_TEST
        lda     #0
        sta     D64_CHR_PATH_RESULT
        jsr     camino_save_iy
        lda     zix
        sta     cam_tgt
        lda     zix+1
        sta     cam_tgt+1
        ldy     #4
        lda     (ziy),y
        jsr     iso_floor_base
        lda     zbc+1
        sta     zde                     ; E = the character's floor base
        ldy     #2
        lda     (zix),y
        and     #$3F
        jsr     iso_floor_base          ; B = the target's
        ldx     #0
        lda     zde
        beq     :+
        ldx     #2
        cmp     #$0B
        beq     :+
        ldx     #4
:       lda     links,x
        sta     D64_CHR_PATH_ROOM_LINKS_PTR
        lda     links+1,x
        sta     D64_CHR_PATH_ROOM_LINKS_PTR+1
        lda     zde
        cmp     zbc+1
        bne     other
        jmp     same
no:     clc
        rts

other:  ldx     #$10                    ; 0638: another floor: up (10h) or down (20h)
        bcc     :+
        ldx     #$20
:       stx     zbc
        ldy     #3                      ; the room: (y & F0h) | x >> 4
        lda     (ziy),y
        and     #$F0
        sta     zde
        dey
        lda     (ziy),y
        lsr
        lsr
        lsr
        lsr
        ora     zde
        clc
        adc     D64_CHR_PATH_ROOM_LINKS_PTR
        sta     zhl
        lda     D64_CHR_PATH_ROOM_LINKS_PTR+1
        adc     #0
        sta     zhl+1
        ldy     #0
        lda     (zhl),y
        and     zbc
        bne     stairs
        ldx     #$66                    ; 0657: BIT 4,(HL) (stairs up) or BIT 5,(HL) (down)
        lda     zbc
        cmp     #$10
        beq     :+
        ldx     #$6E
:       stx     D64_CHR_PATH_FLOOR_TARGET_TEST
        jsr     chr_room_coords
        jsr     camino_hl_origin
        jsr     chr_path_floor_search   ; DE = the room found
        jsr     chr_path_clear_room_marks
        lda     #$76
        sta     D64_CHR_PATH_FLOOR_TARGET_TEST
        lda     D64_CHR_PATH_RESULT
        beq     no
        lda     zde                     ; EX DE,HL
        sta     zhl
        lda     zde+1
        sta     zhl+1
        jsr     camino_iy
        jmp     camino_room_to_room

stairs: ldx     #$0D                    ; 067C: the stairs of this room are the targets
        lda     zbc
        cmp     #$10
        beq     :+
        ldx     #$01
:       stx     D64_CHR_STAIRS_HEIGHT
        jsr     chr_path_build_grid
        lda     #<D64_CHR_PATH_GRID
        sta     zp0
        lda     #>D64_CHR_PATH_GRID
        sta     zp0+1
        ldx     #3                      ; 3 x 192 cells: bit 6 where the height is [0692]
@seg:   ldy     #192
@cell:  dey
        lda     (zp0),y
        cmp     D64_CHR_STAIRS_HEIGHT
        bne     :+
        ora     #$40
        sta     (zp0),y
:       tya
        bne     @cell
        lda     zp0
        clc
        adc     #192
        sta     zp0
        bcc     :+
        inc     zp0+1
:       dex
        bne     @seg
        lda     #0
        sta     D64_CHR_PATH_DEST
        sta     D64_CHR_PATH_DEST+1
        jsr     chr_path_reset_alternatives
        jmp     camino_search_to_marks

same:   ldy     #0                      ; 06A7: the same floor
        lda     (zix),y
        sta     zhl
        iny
        lda     (zix),y
        sta     zhl+1                   ; HL = the target's x, y
        ldy     #2
        lda     (ziy),y
        eor     zhl
        sta     zbc
        and     #$F0
        bne     via
        iny
        lda     (ziy),y
        eor     zhl+1
        sta     zbc+1
        and     #$F0
        bne     via
        lda     #$FD
        sta     D64_CHR_PATH_RESULT
        lda     zbc+1
        ora     zbc
        bne     cell
        jmp     chr_path_face_target    ; on the target's cell (06C6 falls into 06C8)
via:    jmp     chr_path_via_rooms
cell:   lda     #0                      ; 06EC: the same room, another cell
        sta     D64_CHR_PATH_RESULT
        jsr     chr_path_build_grid
        ldy     #0                      ; POP HL
        lda     (cam_tgt),y
        sta     zhl
        iny
        lda     (cam_tgt),y
        sta     zhl+1
        jsr     camino_hbuf_dest
        jsr     camino_iy
        jmp     chr_path_search_to_dest

links:  .word   D64_CHR_ROOM_LINKS, D64_CHR_ROOM_LINKS_FLOOR1, D64_CHR_ROOM_LINKS_FLOOR2
.endproc

camino_save_iy:                         ; cam_chr = IY
        lda     ziy
        sta     cam_chr
        lda     ziy+1
        sta     cam_chr+1
        rts

camino_iy:                              ; IY = cam_chr
        lda     cam_chr
        sta     ziy
        lda     cam_chr+1
        sta     ziy+1
        rts

; 06C8 chr_path_face_target: the character stands on the target cell.  Wanted orientation = [target+2] >>
; 6; already facing it -> CF = 0 (CP equal).  Else chr_cmd_rewind, the turn commands (432C: A = [chr+1],
; C = the wanted one), the 12-bit command 1000h (chr_cmd_write_bits) and chr_cmd_rewind: CF of
; chr_cmd_write_bits.  In: IY = chr, IX = target.  Out: CF.
.proc chr_path_face_target
        ldy     #2
        lda     (zix),y
        asl
        rol
        rol
        and     #3
        sta     zbc
        ldy     #1
        lda     (ziy),y
        cmp     zbc
        bne     turn
        clc
        rts
turn:   jsr     chr_cmd_rewind          ; (A kept)
        jsr     chr_cmd_write_turn
        lda     #$00
        sta     zhl
        lda     #$10
        sta     zhl+1
        lda     #$0C
        sta     zbc+1
        jsr     chr_cmd_write_bits
        ; falls into chr_cmd_rewind (the carry kept)
.endproc

; 06E3 chr_cmd_rewind: [chr+9] = [chr+0Bh] = 0.  In: IY = chr.  A and the carry kept.
.proc chr_cmd_rewind
        tax
        lda     #0
        ldy     #9
        sta     (ziy),y
        ldy     #$0B
        sta     (ziy),y
        txa
        rts
.endproc

; 06FE chr_room_coords: L = [rec+2] >> 4, H = [rec+3] >> 4.  In: IY = rec.  Out: HL, A = H.
.proc chr_room_coords
        ldy     #2
        lda     (ziy),y
        lsr
        lsr
        lsr
        lsr
        sta     zhl
        iny
        lda     (ziy),y
        lsr
        lsr
        lsr
        lsr
        sta     zhl+1
        rts
.endproc

; 0713 chr_path_clear_room_marks: AND 3Fh over the 130h bytes of the room links 023Dh (the room search's
; marks in bits 6-7).  Its callers use no register.
.proc chr_path_clear_room_marks
        ldx     #152
:       lda     D64_CHR_ROOM_LINKS-1,x
        and     #$3F
        sta     D64_CHR_ROOM_LINKS-1,x
        lda     D64_CHR_ROOM_LINKS+151,x
        and     #$3F
        sta     D64_CHR_ROOM_LINKS+151,x
        dex
        bne     :-
        rts
.endproc

; 0724 chr_path_via_rooms: the target in another room of the floor: HL >> 4 (both bytes) is the
; destination room, then 0734.  In: IY = chr, HL = the target's x, y.  Out: CF as chr_path_find's.
.proc chr_path_via_rooms
        jsr     camino_save_iy
        lda     zhl+1
        lsr
        lsr
        lsr
        lsr
        sta     zhl+1
        lda     zhl
        lsr
        lsr
        lsr
        lsr
        sta     zhl
        ; falls into camino_room_to_room
.endproc

; 0734 (chr_path_room_to_room): chr_path_origin [2903] = the destination room (HL), chr_path_dest [2905] =
; the character's room, the room graph search 438F, chr_path_clear_room_marks; nothing found -> CF = 0.
; Found: entry [3F81] of chr_exit_table 08FAh: the band routine to [076B], chr_path_reset_alternatives,
; [2905] = its grid target, chr_path_build_grid, CALL [076B], then 076D.  In: IY = chr = cam_chr.
.proc camino_room_to_room
        jsr     camino_hl_origin
        jsr     chr_room_coords
        jsr     camino_hl_dest
        jsr     chr_path_floor_to_screen
        jsr     chr_path_clear_room_marks
        lda     D64_CHR_PATH_RESULT
        bne     found
        clc
        rts
found:  lda     D64_CHR_PATH_ORIENTATION
        asl
        asl
        sta     cam_drv
        tax
        lda     D64_CHR_EXIT_TABLE,x
        sta     D64_CHR_EXIT_MARK_ROUTINE
        lda     D64_CHR_EXIT_TABLE+1,x
        sta     D64_CHR_EXIT_MARK_ROUTINE+1
        jsr     chr_path_reset_alternatives
        ldx     cam_drv
        lda     D64_CHR_EXIT_TABLE+2,x
        sta     D64_CHR_PATH_DEST
        lda     D64_CHR_EXIT_TABLE+3,x
        sta     D64_CHR_PATH_DEST+1
        jsr     camino_iy
        jsr     chr_path_build_grid
        jsr     call_exit
        jmp     camino_search_to_marks
call_exit:
        jmp     (D64_CHR_EXIT_MARK_ROUTINE)   ; 076A CALL nn: a chr_path_mark_exit_* routine
.endproc

; 076D (chr_path_search_to_marks): chr_path_origin [2903] = the character's cell in grid coordinates
; (whatever chr_to_hbuf_coords' carry), the grid search 3F92 towards [2905] or any bit-6 cell, then 078D.
.proc camino_search_to_marks
        jsr     camino_iy
        jsr     camino_origin
        jsr     chr_path_room_to_marked
        jmp     camino_check_result
.endproc

; chr_path_origin [2903] = the x, y of IY in grid coordinates (camino_origin), or HL (camino_hl_origin);
; chr_path_dest [2905] = HL in grid coordinates (camino_hbuf_dest), or HL (camino_hl_dest).
camino_origin:
        jsr     camino_iy_xy
        jsr     chr_to_hbuf_coords
camino_hl_origin:
        lda     zhl
        sta     D64_CHR_PATH_ORIGIN
        lda     zhl+1
        sta     D64_CHR_PATH_ORIGIN+1
        rts

camino_iy_xy:                           ; HL = the x, y of IY
        ldy     #2
        lda     (ziy),y
        sta     zhl
        iny
        lda     (ziy),y
        sta     zhl+1
        rts

camino_hbuf_dest:
        jsr     chr_to_hbuf_coords
camino_hl_dest:
        lda     zhl
        sta     D64_CHR_PATH_DEST
        lda     zhl+1
        sta     D64_CHR_PATH_DEST+1
        rts

; 077E chr_path_search_to_dest: [2903] = the character's cell in grid coordinates, the grid search 3F9E
; towards [2905], then 078D (chr_path_check_result): chr_path_solution [41D4] = the search's HL.  Found
; ([2907] != 0): chr_path_found_now [28FA] = 1, chr_path_clear_grid_marks, chr_cmd_generate 434F,
; chr_path_restore_screen_grid (CF = 1).  Else the next candidate ([0213] += 3): FF -> restore, CF = 0;
; else chr_path_clear_grid_marks, [2907] = FD, the character on that candidate -> chr_path_face_target and
; the same CF = 0 exit; else [2907] = 0, [2905] = the candidate in grid coordinates, again from 077E.
; In: IY = chr.  Out: CF as chr_path_find's.
.proc chr_path_search_to_dest
        jsr     camino_save_iy
        jsr     camino_origin
        jsr     chr_path_room_search
        ; falls into camino_check_result
.endproc

.proc camino_check_result
        lda     zhl
        sta     D64_CHR_PATH_SOLUTION
        lda     zhl+1
        sta     D64_CHR_PATH_SOLUTION+1
        lda     D64_CHR_PATH_RESULT
        bne     found
        lda     D64_CHR_PATH_ALT_PTR    ; the next candidate
        clc
        adc     #3
        sta     D64_CHR_PATH_ALT_PTR
        sta     zix
        lda     D64_CHR_PATH_ALT_PTR+1
        adc     #0
        sta     D64_CHR_PATH_ALT_PTR+1
        sta     zix+1
        ldy     #0
        lda     (zix),y
        cmp     #$FF
        beq     none
        sta     zhl                     ; HL = the candidate's x, y (chr_path_clear_grid_marks keeps it)
        iny
        lda     (zix),y
        sta     zhl+1
        jsr     chr_path_clear_grid_marks
        lda     #$FD
        sta     D64_CHR_PATH_RESULT
        jsr     camino_iy
        ldy     #2
        lda     (ziy),y
        eor     zhl
        sta     zbc
        iny
        lda     (ziy),y
        eor     zhl+1
        ora     zbc
        bne     next
        jsr     chr_path_face_target    ; the character stands on this candidate
none:   jsr     chr_path_restore_screen_grid
        clc
        rts
next:   lda     #0
        sta     D64_CHR_PATH_RESULT
        jsr     camino_hbuf_dest
        jmp     chr_path_search_to_dest
found:  lda     #1
        sta     D64_CHR_PATH_FOUND_NOW
        jsr     chr_path_clear_grid_marks   ; A = 0, BC = 0
        jsr     camino_iy
        jsr     chr_cmd_generate
        jmp     chr_path_restore_screen_grid
.endproc

; 07E6 chr_path_restore_screen_grid: chr_hbuf_ptr [28DB] = AE2Eh (the screen's height buffer),
; iso_grid_set_origin(the camera's pseudo record 28C4h), chr_shown_floor [290B] = [28C8].  Out: CF = 1,
; A = [28C8], B = the floor base, HL = AE2Eh (its C64 address), IY kept.
.proc chr_path_restore_screen_grid
        lda     #<D64_CHR_HEIGHT_BUFFER
        sta     D64_CHR_HBUF_PTR
        sta     zhl
        lda     #>D64_CHR_HEIGHT_BUFFER
        sta     D64_CHR_HBUF_PTR+1
        sta     zhl+1
        lda     #<D64_ISO_CAMERA_RECORD
        sta     zp0
        lda     #>D64_ISO_CAMERA_RECORD
        sta     zp0+1
        jsr     camino_set_origin       ; (IY untouched: the Z80's PUSH IY / POP IY)
        lda     D64_CHR_ROOM_Z          ; the camera record's +4
        sta     D64_CHR_SHOWN_FLOOR
        sec
        rts
.endproc

; 07FF iso_grid_set_origin: the grid origin of the room of rec: chr_to_hbuf_coords' operands [22FE] =
; ([rec+2] & F0h) - 4, [22F2] = ([rec+3] & F0h) - 4; chr_shown_floor [290B] = iso_floor_base([rec+4]).
; In: IY = rec.  Out: A = B = the floor base.
.proc iso_grid_set_origin
        lda     ziy
        sta     zp0
        lda     ziy+1
        sta     zp0+1
.endproc
.proc camino_set_origin                 ; the same for the record at zp0
        ldy     #2
        lda     (zp0),y
        and     #$F0
        sec
        sbc     #4
        sta     D64_CHR_HBUF_ORIGIN_X
        iny
        lda     (zp0),y
        and     #$F0
        sec
        sbc     #4
        sta     D64_CHR_HBUF_ORIGIN_Y
        iny
        lda     (zp0),y
        jsr     iso_floor_base
        lda     zbc+1
        sta     D64_CHR_SHOWN_FLOOR
        rts
.endproc

; 081E chr_path_clear_grid_marks: AND 3Fh over the 240h cells of the height buffer [28DB] (the search's
; marks in bits 6-7): three strips of 192 cells, X = 192..1 (the strips' addresses written into the code).
; Out: A = 0, BC = 0.
.proc chr_path_clear_grid_marks
        lda     D64_CHR_HBUF_PTR
        sec
        sbc     #1
        tay
        lda     D64_CHR_HBUF_PTR+1
        sbc     #0
        tax                             ; X:Y = the buffer - 1
        sty     l0+1
        sty     s0+1
        stx     l0+2
        stx     s0+2
        tya
        clc
        adc     #192
        tay
        bcc     :+
        inx
:       sty     l1+1
        sty     s1+1
        stx     l1+2
        stx     s1+2
        tya
        clc
        adc     #192
        tay
        bcc     :+
        inx
:       sty     l2+1
        sty     s2+1
        stx     l2+2
        stx     s2+2
        ldx     #192
l0:     lda     $FFFF,x
        and     #$3F
s0:     sta     $FFFF,x
l1:     lda     $FFFF,x
        and     #$3F
s1:     sta     $FFFF,x
l2:     lda     $FFFF,x
        and     #$3F
s2:     sta     $FFFF,x
        dex
        bne     l0
        lda     #0
        sta     zbc
        sta     zbc+1
        rts
.endproc

; 082F chr_path_build_grid: chr_hbuf_ptr [28DB] = 8174h (chr_path_grid); chr_fill_height_buffer for chr;
; then, if Guillermo, or else the camera room (28C6-28C8), is within one room of chr in x and y
; (chr_room_distance_near) and on its floor: chr_grid_owner [08A0] = chr, the records of 5 chr_table
; entries from 270Dh (6 from 2703h when both distances are 1) but chr get the mark 10h (chr_mark_hbuf), the
; leaves of the open doors (bit 6 of [door+1]) get height 0Fh (obj_door_mark_cells) and chr's cells are
; cleared (chr_mark_hbuf with 0).  In: IY = chr.  Out: IY = chr.
.proc chr_path_build_grid
        jsr     camino_save_iy
        lda     #<D64_CHR_PATH_GRID
        sta     D64_CHR_HBUF_PTR
        lda     #>D64_CHR_PATH_GRID
        sta     D64_CHR_HBUF_PTR+1
        jsr     chr_fill_height_buffer
        jsr     camino_iy
        ldy     #4
        lda     (ziy),y
        jsr     iso_floor_base
        lda     zbc+1
        sta     zt0                     ; chr's floor
        lda     #<(D64_CHR_GUILLERMO+2) ; Guillermo near?
        ldx     #>(D64_CHR_GUILLERMO+2)
        jsr     near
        bcc     camera
        lda     D64_CHR_GUILLERMO+4
        jsr     iso_floor_base
        lda     zbc+1
        cmp     zt0
        beq     mark
camera: lda     #<D64_CHR_ROOM_X        ; 0864: the room shown near?
        ldx     #>D64_CHR_ROOM_X
        jsr     near
        bcs     :+
        rts
:       lda     D64_CHR_ROOM_Z
        cmp     zt0
        beq     mark
        rts
mark:   lda     ziy                     ; 0887
        sta     D64_CHR_GRID_OWNER
        lda     ziy+1
        sta     D64_CHR_GRID_OWNER+1
        ldx     #5                      ; the other characters get the mark 10h: 5 entries from 270Dh
        ldy     #$0C                    ; (their record fields from 270Fh)
        lda     cam_dx
        cmp     #1
        bne     :+
        lda     cam_dy
        cmp     #1
        bne     :+
        ldy     #2                      ; both distances 1: 6 from 2703h (Guillermo too)
        inx
:       stx     cam_n
        tya
        clc
        adc     #<D64_CHR_TABLE
        sta     cam_ptr
        lda     #>D64_CHR_TABLE
        adc     #0
        sta     cam_ptr+1
chr:    ldy     #0
        lda     (cam_ptr),y
        sta     ziy
        iny
        lda     (cam_ptr),y
        sta     ziy+1
        cmp     D64_CHR_GRID_OWNER+1
        bne     :+
        lda     ziy
        cmp     D64_CHR_GRID_OWNER
        beq     :++
:       lda     #$10
        sta     zbc
        jsr     chr_mark_hbuf
:       lda     cam_ptr
        clc
        adc     #10
        sta     cam_ptr
        bcc     :+
        inc     cam_ptr+1
:       dec     cam_n
        bne     chr
        lda     #<D64_OBJ_DOORS         ; the open doors' leaves get height 0Fh
        sta     cam_ptr
        lda     #>D64_OBJ_DOORS
        sta     cam_ptr+1
door:   lda     cam_ptr
        sta     ziy
        lda     cam_ptr+1
        sta     ziy+1
        ldy     #1
        lda     (ziy),y
        and     #$40
        beq     :+
        lda     #$0F
        jsr     obj_door_mark_cells
:       lda     cam_ptr
        clc
        adc     #5
        sta     cam_ptr
        bcc     :+
        inc     cam_ptr+1
:       ldy     #0
        lda     (cam_ptr),y
        cmp     #$FF
        bne     door
        lda     D64_CHR_GRID_OWNER      ; chr's own cells cleared
        sta     ziy
        lda     D64_CHR_GRID_OWNER+1
        sta     ziy+1
        lda     #0
        sta     zbc
        jmp     chr_mark_hbuf
near:   sta     zp0                     ; the room distances of x, y at [AX] and chr's: cam_dx, cam_dy,
        stx     zp0+1                   ; CF = both near (chr_room_distance_near: the second one is
        ldy     #0                      ; skipped when the first is far, as the Z80)
        jsr     near1
        sta     cam_dx
        bcc     :+
        iny
        jsr     near1
        sta     cam_dy
:       rts
near1:  lda     (zp0),y                 ; chr_room_distance_near([zp0+Y], C = [chr+2+Y])
        pha
        iny
        iny
        lda     (ziy),y
        sta     zbc
        dey
        dey
        pla
        jmp     chr_room_distance_near
.endproc

; 08E5 chr_room_distance_near: the room distance (A >> 4) - (C >> 4) + 1 (8 bit), near (CF) below 3.
; In: A, C.  Out: A, C = C >> 4, CF, ZF (CP 3).
.proc chr_room_distance_near
        lsr     zbc
        lsr     zbc
        lsr     zbc
        lsr     zbc
        lsr
        lsr
        lsr
        lsr
        sec
        sbc     zbc
        clc
        adc     #1
        cmp     #3
        bcs     far
        sec                             ; near: CF = 1 (Z clear: A != 3)
        rts
far:    clc                             ; CF = 0, Z = (A = 3)
        rts
.endproc

; 090A chr_path_mark_exit_up, 091C _right, 0924 _left, 0929 _down (called through [076B]): bit 6 in 16
; cells of [28DB] + offset, step 1 or 24 (the exit band: row 3, column 20, column 3, row 20).  Its caller
; uses no register.
chr_path_mark_exit_up:
        ldx     #0
        .byte   $2C                     ; BIT $01A2: skips LDX #1
chr_path_mark_exit_right:
        ldx     #1
        .byte   $2C
chr_path_mark_exit_left:
        ldx     #2
        .byte   $2C
chr_path_mark_exit_down:
        ldx     #3
.proc camino_mark_band
        lda     D64_CHR_HBUF_PTR
        clc
        adc     band_lo,x
        sta     zp0
        lda     D64_CHR_HBUF_PTR+1
        adc     band_hi,x
        sta     zp0+1
        lda     band_step,x
        sta     zt0
        ldx     #16
        ldy     #0
loop:   lda     (zp0),y
        ora     #$40
        sta     (zp0),y
        lda     zp0
        clc
        adc     zt0
        sta     zp0
        bcc     :+
        inc     zp0+1
:       dex
        bne     loop
        rts
band_lo:    .byte   $4C, $74, $63, $E4
band_hi:    .byte   $00, $00, $00, $01
band_step:  .byte   1, 24, 24, 1
.endproc

; 092E iso_grid_cell_of: the cell of record rec (x +2, y +3, z +4) in the height buffer in use.  Another
; floor than chr_shown_floor [290B] -> CF = 1, A = [290B]; outside the 24 x 24 window (chr_to_hbuf_coords
; 22F0, inline here: x - [22FE] and y - [22F2] in 2..15h) -> CF = 1, A and HL as 22F0 leaves them.  Else
; 0944 (inline for coordinates in 2..15h): IX = [28DB] + 24 y + x, DE = 24 y + x, HL = A = 8 y + x, CF = 0.
; B = the floor base always (iso_floor_base inline); C, IY kept.  In: IY = rec.
.proc iso_grid_cell_of
        ldy     #4
        lda     (ziy),y                 ; z
        ldx     #0
        cmp     #$0D
        bcc     :+
        ldx     #$16
        cmp     #$18
        bcs     :+
        ldx     #$0B
:       stx     zbc+1
        cpx     D64_CHR_SHOWN_FLOOR
        bne     other
        ldy     #2
        lda     (ziy),y
        sta     zhl                     ; L = x
        iny
        lda     (ziy),y
        sta     zhl+1                   ; H = y
        sec
        sbc     D64_CHR_HBUF_ORIGIN_Y
        bcc     out
        cmp     #2
        bcc     out
        cmp     #$16
        bcs     out
        sta     zhl+1
        tax                             ; X = y'
        lda     zhl
        sec
        sbc     D64_CHR_HBUF_ORIGIN_X
        bcc     out
        cmp     #2
        bcc     out
        cmp     #$16
        bcs     out
        sta     zt0                     ; x'
        clc
        adc     mul24_lo-2,x
        sta     zde
        lda     mul24_hi-2,x
        adc     #0
        sta     zde+1                   ; DE = 24 y' + x'
        lda     zde
        clc
        adc     D64_CHR_HBUF_PTR
        sta     zix
        lda     zde+1
        adc     D64_CHR_HBUF_PTR+1
        sta     zix+1                   ; IX = the cell
        txa
        asl
        asl
        asl
        adc     zt0                     ; (no carry: 8 y' + x' < 256)
        sta     zhl                     ; HL = A = 8 y' + x'
        ldx     #0
        stx     zhl+1
        clc
        rts
other:  lda     D64_CHR_SHOWN_FLOOR
out:    sec
        rts

mul24_lo:                               ; 24 y for y = 2..21
        .repeat 20, i
        .byte   <((i + 2) * 24)
        .endrep
mul24_hi:
        .repeat 20, i
        .byte   >((i + 2) * 24)
        .endrep
.endproc

; 0944 iso_grid_cell_ptr: the cell (x = L, y = H) of the 24-column height buffer whose base is [28DB]:
; t = 8 y; lo = (t & FF00) | (x + t) (8-bit sum); idx = 2 t + lo.  Out: IX = base + idx (a C64 address: the
; base is relocated), DE = idx, HL = lo, A = low byte of lo, C clear.
.proc iso_grid_cell_ptr
        lda     zhl+1                   ; y
        asl
        asl
        asl
        sta     zt0                     ; t = 8 y: low byte
        clc
        adc     zhl
        sta     zhl                     ; lo = (t high, x + t low)
        lda     zhl+1
        lsr
        lsr
        lsr
        lsr
        lsr
        sta     zhl+1                   ; t high = lo high
        sta     zt0+1
        asl     zt0                     ; idx = 2 t + lo
        rol     zt0+1
        lda     zt0
        clc
        adc     zhl
        sta     zde
        lda     zt0+1
        adc     zhl+1
        sta     zde+1                   ; DE = idx, HL = lo (the Z80's EX DE,HL)
        lda     D64_CHR_HBUF_PTR        ; IX = base + idx
        clc
        adc     zde
        sta     zix
        lda     D64_CHR_HBUF_PTR+1
        adc     zde+1
        sta     zix+1
        lda     zhl
        clc
        rts
.endproc

; 0959 chr_cmd_write_bits: appends the B most significant bits of HL (B = 0: 256) to chr's command
; stream, MSB first: when the bit counter [chr+9] is 8, the byte [chr+0Ah] goes to [chr+0Ch] + [chr+0Bh]
; (DE), the index [chr+0Bh] + 1 and the counter 0; then HL << 1 and its bit 15 rotated into [chr+0Ah]
; (RL), counter + 1.  In: IY = chr, HL, B.  Out: HL, B = 0, A as the last pass leaves it (the counter
; read, or the byte stored), CF = bit 7 of [chr+0Ah] before the last RL, DE = the last byte stored (if
; any).
.proc chr_cmd_write_bits
loop:   ldy     #9
        lda     (ziy),y
        cmp     #8
        bne     shift
        lda     #0
        sta     (ziy),y                 ; counter 0
        ldy     #$0B
        lda     (ziy),y
        tax                             ; the index
        inx
        txa
        sta     (ziy),y
        dex
        txa
        ldy     #$0C
        clc
        adc     (ziy),y
        sta     zde
        iny
        lda     (ziy),y
        adc     #0
        sta     zde+1
        ldy     #$0A
        lda     (ziy),y
        ldy     #0
        sta     (zde),y
shift:  sta     zt0                     ; A for the exit
        asl     zhl                     ; ADD HL,HL
        rol     zhl+1
        ldy     #$0A
        lda     (ziy),y
        rol                             ; RL (IY+0Ah)
        sta     (ziy),y
        ldy     #9                      ; INC (IY+9) (the carry kept)
        lda     (ziy),y
        tax
        inx
        txa
        sta     (ziy),y
        dec     zbc+1
        bne     loop
        lda     zt0
        rts
.endproc
