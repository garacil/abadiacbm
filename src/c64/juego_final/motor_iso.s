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
; The isometric engine: the tile buffer and the tile placing, the room builder and its block interpreter, the
; play-area fill of the screen, the camera's room change and transforms, the floor bases, the CRTC pairs.
;
; Interfaces as the Z80's (c64/CODIGO6502.md): A, the zero-page pairs zbc/zde/zhl/zix/ziy.  Variables keep the
; CPC's values: the step opcodes INC H 24h, DEC H 25h, INC L 2Ch, DEC L 2Dh at the SMC sites; the code words
; 12C0h (12C9h / 12C2h) and 1DFCh (17F1h / 17EEh) keep their CPC values (no 6502 routine has those entries).
;
; The block interpreter keeps its frames on the 6502 stack as the Z80 kept them on its own (return tags, saved
; IX, loop frames, positions, CALL frames): an END pops IX and returns (RTS) to its tag, which is iso_build_room
; for a room entry and mi_call_return for a called block.  The deepest room needs 28 Z80 words (56 bytes).
        .include "zp.inc"
        .include "mapa.inc"

        .export util_add_bx_al, iso_put_tile, iso_draw_room, iso_build_room
.ifdef C128
        .import far_sala, SALA, cab_apaga
.endif
        .export vid_fill_play_area_ff, iso_clear_tile_buffer, vid_fill_play_area
        .export iso_block_depth, iso_tile_run, iso_put_tile_step, iso_put_tile_times
        .export iso_expression, iso_fetch_word, iso_fetch_operand, iso_operand_value
        .export vid_set_crtc, iso_update_camera_room
        .export iso_floor_base, iso_orient_relative
        .export iso_rotate_cam0, iso_rotate_cam1, iso_rotate_cam2, iso_rotate_cam3

        .import iso_draw_room_spiral, iso_select_room, chr_fill_height_buffer
        .import obj_place_doors_in_room, obj_place_objects_in_room, chr_mark_hbuf
        .import plat_crtc

; spr_update_char_sprite (208C) calls chr_project (2632), which returns to its caller's caller when the character
; is visible, and jumps into chr_animate at 2589 (chr_show_frame): neither has a table entry, so no trap can stand
; for them.  Its 6502 routine is ready in motor_iso_spr.s.pendiente: rename it to motor_iso_spr.s when the group
; personajes exports chr_project and chr_show_frame with the Z80's conventions; until then the call below is a
; trap (the Z80's 208C).
        .import spr_update_char_sprite

; the group's zero page ($B6-$C1; $BD, $C0, $C1 free)
mi_cell  = $B6                          ; 2: the tile buffer row of iso_put_tile
mi_oldx  = $B8                          ; the cell's old depth x, y
mi_oldy  = $B9
mi_ptr   = $BA                          ; 2: the script start of a block entered; the inline data
mi_t0    = $BC                          ; scratch
mi_t2    = $BE                          ; SET: the destination code, its register
mi_t3    = $BF

; CPC values kept in the variables (code addresses that have no 6502 routine)
MI_PUT_TILE_MARK  = $12C2               ; 12C0h: the tile number at cell + 780h (after building)
MI_PUT_TILE_UPDATE = $12C9              ; 12C0h: the cell update (while building)
MI_ENTER_KEEP     = $17EE               ; 1DFCh: iso_enter_block_keep_tiles (CALL_KEEP)
MI_ENTER          = $17F1               ; 1DFCh: iso_enter_block (CALL)
MI_FLOOR0_MAP     = D64_ISO_FLOOR_MAPS - $10    ; 1E79h: floor 0's map base, 10h before the data (1E89h)
MI_PLAY_ROWS      = 20                  ; the play area: bitmap rows 0-19 (CPC lines 0-159), cells 4-35
MI_PLAY_AREA      = $E000 + 32          ; row r: 256 bytes from $E020 + 320 r

.segment "CODE"

; ================================================================================================
; Utilities, tiles and the tile buffer
; ================================================================================================

; 128F util_add_bx_al: HL += A (A unsigned).  Out: HL, A = H.
util_add_bx_al:
        clc
        adc     zhl
        sta     zhl
        bcc     :+
        inc     zhl+1
:       lda     zhl+1
        rts

; 1295 iso_put_tile: puts tile C at the grid position HL (H = y, L = x) when it is visible (y - 8 < 14h,
; x - 8 < 10h).  The cell is tile buffer + 96 (y - 8) + 6 (x - 8): the old tile [5] becomes the lower tile [2];
; [0],[1] = the old depth [3],[4], or the current depth (1BECh, 1BEDh) when it is smaller in both; [3],[4] = the
; current depth; [5] = the tile.  Out: A = the depth y put, or the coordinate that failed (y - 8, x - 8).
; HL, BC kept; X, Y clobbered.  (DE, which no caller reads, is not set.)
iso_put_tile:
        ldx     zhl+1
        cpx     #$1C
        bcs     @out
        lda     mi_row_hi-8,x           ; 0: y < 8
        beq     @out
        sta     mi_cell+1
        lda     mi_row_lo-8,x
        sta     mi_cell
        ldx     zhl
        cpx     #$18
        bcs     @out
        ldy     mi_col6-8,x             ; Y = 6 (x - 8) + 3; FFh: x < 8
        bmi     @out
        lda     D64_ISO_PUT_TILE_JUMP   ; JP (12C0h)
        cmp     #<MI_PUT_TILE_MARK
        beq     @mark
        lda     (mi_cell),y             ; [3]: the old depth x
        sta     mi_oldx
        lda     D64_ISO_DEPTH_X
        sta     (mi_cell),y
        iny
        lda     (mi_cell),y             ; [4]: the old depth y
        sta     mi_oldy
        lda     D64_ISO_DEPTH_Y
        sta     (mi_cell),y
        iny
        lda     (mi_cell),y             ; [5]: the old tile
        tax
        lda     zbc
        sta     (mi_cell),y
        dey
        dey
        dey
        txa
        sta     (mi_cell),y             ; [2] = the old tile
        dey
        lda     D64_ISO_DEPTH_X
        cmp     mi_oldx
        bcs     @keep
        lda     D64_ISO_DEPTH_Y
        cmp     mi_oldy
        bcs     @keep
        sta     (mi_cell),y             ; [1] = depth y
        dey
        lda     D64_ISO_DEPTH_X
        sta     (mi_cell),y             ; [0] = depth x
        lda     D64_ISO_DEPTH_Y
        rts
@out:   txa                             ; the coordinate that failed, minus 8
        sec
        sbc     #8
        rts
@keep:  lda     mi_oldy
        sta     (mi_cell),y             ; [1] = the old depth y
        dey
        lda     mi_oldx
        sta     (mi_cell),y             ; [0] = the old depth x
        lda     D64_ISO_DEPTH_Y
        rts
; 12C2h, the form set after building (never reached: iso_put_tile runs only while a room is built): the Z80
; writes the tile at cell + 780h (the CPC's pixel tables 8F00h, not on the C64 map) and returns A = the high
; byte of the cell's offset; on the C64 only A is given.
@mark:  tya
        sbc     #3                      ; C set (CMP equal): 6 (x - 8)
        clc
        adc     mi_cell
        tax                             ; the cell's low byte
        lda     mi_cell+1
        adc     #0
        cpx     #<D64_ISO_TILE_BUFFER   ; the borrow of the low bytes
        sbc     #>D64_ISO_TILE_BUFFER
        rts

; the tile buffer's rows and columns for iso_put_tile, indexed by y - 8 and x - 8 (the bytes before them: the
; invisible y and x below 8)
        .res    8, 0
mi_row_hi:
        .repeat 20, I
        .hibytes D64_ISO_TILE_BUFFER + 96 * I
        .endrep
mi_row_lo:
        .repeat 20, I
        .lobytes D64_ISO_TILE_BUFFER + 96 * I
        .endrep
        .res    8, $FF
mi_col6:
        .repeat 16, I
        .byte   6 * I + 3
        .endrep

; 1D26 iso_put_tile_step: iso_put_tile, then the step opcode at 1D29h (D64_ISO_TILE_STEP_INSN) on HL.
; Out: HL stepped, A of iso_put_tile, BC kept.
iso_put_tile_step:
        jsr     iso_put_tile
; the step at 1D29h on HL; A kept
mi_step:
        ldx     D64_ISO_TILE_STEP_INSN
; the step opcode X (INC H, DEC H, INC L, DEC L) on HL; A kept.  DEC H first (the tile runs up), then INC L.
mi_step_x:
        cpx     #$25
        beq     @dech
        cpx     #$2C
        beq     @incl
        cpx     #$2D
        beq     @decl
        inc     zhl+1                   ; 24h INC H
        rts
@dech:  dec     zhl+1                   ; 25h DEC H
        rts
@incl:  inc     zhl                     ; 2Ch INC L
        rts
@decl:  dec     zhl                     ; 2Dh DEC L
        rts

; 1D48 iso_put_tile_times: put + step while the A left by iso_put_tile, minus one, is not 0 (the count of
; the run is never used: the Z80's counter is A, which iso_put_tile overwrites; no block uses this form).
; Out: HL, A = 0 (Z set), BC kept.
iso_put_tile_times:
        jsr     iso_put_tile_step
        sec
        sbc     #1
        bne     iso_put_tile_times
        rts

; ================================================================================================
; The play area of the screen and the tile buffer
; ================================================================================================

; 16A1 vid_fill_play_area_ff: vid_fill_play_area with FFh.
vid_fill_play_area_ff:
        lda     #$FF
        bne     vid_fill_play_area

; 16A5 iso_clear_tile_buffer: zeroes the tile buffer (780h bytes), then vid_fill_play_area with A.
iso_clear_tile_buffer:
        tax
        lda     #0
        ldy     #240                    ; 8 pieces of 240 bytes
@c:     .repeat 8, I
        sta     D64_ISO_TILE_BUFFER - 1 + 240 * I, y
        .endrep
        dey
        bne     @c
        txa
; 16B2 vid_fill_play_area: fills the play area (CPC lines 0-159, 64 bytes each: bitmap rows 0-19, cells 4-35)
; with the CPC byte A, kept at 16C0h (D64_VID_FILL_BYTE).  On the C64 the byte is converted once (mi_nibble);
; the CPC's line walk (f_3558) is not needed.  Registers: none that a caller reads (A, X, Y clobbered).
vid_fill_play_area:
.ifdef C128
        jsr     cab_apaga               ; the C128: the heads' hardware sprites off (A kept)
.endif
        sta     D64_VID_FILL_BYTE
        jsr     mi_nibble
        ldy     #0
@f:     .repeat MI_PLAY_ROWS, R
        sta     MI_PLAY_AREA + 320 * R, y
        .endrep
        iny
        bne     @f
        rts

; the C64 byte of the fill: a uniform CPC byte A (its 4 pixels of one pen p; the game fills with 00h and FFh
; only) -> the bit pair of p four times (pens 0, 1, 2, 3 -> 01, 10, 11, 00).  p = bit 7 + 2 bit 3 of A.
mi_nibble:
        tax
        and     #$08
        lsr
        lsr                             ; 2 bit 3
        cpx     #$80                    ; C = bit 7
        adc     #0
        tax
        lda     mi_pen,x
        rts
mi_pen: .byte   $55, $AA, $FF, $00

; ================================================================================================
; The room builder and the block interpreter
; ================================================================================================

; 1611 iso_draw_room: builds and shows the current room: the tile buffer cleared and the play area filled with
; 00h (lit) or FFh (dark, D64_ISO_ROOM_DARK not 0); iso_build_room on the record [11DAh] + 1 with the cell update
; of iso_put_tile (12C0h = 12C9h; 12C2h after it); a lit room is then drawn (iso_draw_room_spiral, a tail jump).
iso_draw_room:
        lda     D64_ISO_ROOM_DARK
        beq     :+
        lda     #$FF
:       jsr     iso_clear_tile_buffer
.ifdef C128
        jsr     far_sala                ; the C128: the record from block 1 into SALA (plataforma/c128.s)
        lda     #<(SALA + 1)
        sta     zix
        lda     #>(SALA + 1)
        sta     zix+1
.else
        lda     D64_ISO_ROOM_PTR
        clc
        adc     #1
        sta     zix
        lda     D64_ISO_ROOM_PTR+1
        adc     #0
        sta     zix+1
.endif
        lda     #<MI_PUT_TILE_UPDATE
        sta     D64_ISO_PUT_TILE_JUMP
        lda     #>MI_PUT_TILE_UPDATE
        sta     D64_ISO_PUT_TILE_JUMP+1
        jsr     iso_build_room
        lda     #<MI_PUT_TILE_MARK
        sta     D64_ISO_PUT_TILE_JUMP
        lda     D64_ISO_ROOM_DARK
        bne     :+
        jmp     iso_draw_room_spiral
:       rts

; 163F iso_build_room: interprets the room entries at IX up to a byte FFh.  Entry: byte 0 = block type (bits 1-7:
; the word of the block table) | bit 0 (a height byte follows); byte 1 = x | p1 << 5; byte 2 = y | p2 << 5;
; [byte 3 = height].  For each: the block at 1697h (D64_ISO_CUR_BLOCK), depth 0, 0, height (1BEBh) = the byte or
; FFh; HL = y, x, BC = p2, p1; the tag (this routine) pushed; the block entered with its tile list; its END pops
; IX = the next entry and returns here.  Out: IX = the FFh, A = FFh.
iso_build_room:
        ldy     #0
        lda     (zix),y
        cmp     #$FF
        bne     :+
        rts
:       and     #$FE
        tax
        lda     D64_ISO_BLOCK_TABLE,x
        sta     D64_ISO_CUR_BLOCK
        lda     D64_ISO_BLOCK_TABLE+1,x
        sta     D64_ISO_CUR_BLOCK+1
        ldx     #0                      ; L = x, C = p1; H = y, B = p2
:       iny
        lda     (zix),y                 ; x | p1 << 5, y | p2 << 5
        pha
        and     #$1F
        sta     zhl,x
        pla
        lsr
        lsr
        lsr
        lsr
        lsr
        sta     zbc,x
        inx
        cpx     #2
        bne     :-
        lda     #0
        sta     D64_ISO_DEPTH_X
        sta     D64_ISO_DEPTH_Y
        ldy     #0
        lda     (zix),y
        lsr                             ; C = a height follows
        lda     #$FF
        ldy     #3
        bcc     :+
        lda     (zix),y
        iny
:       sta     D64_ISO_BLOCK_HEIGHT
        tax
        tya                             ; IX past the entry
        clc
        adc     zix
        sta     zix
        bcc     :+
        inc     zix+1
:       lda     #>(iso_build_room-1)    ; the tag 163Fh: END returns to the next entry
        pha
        lda     #<(iso_build_room-1)
        pha
        ldy     #0                      ; DE = the tile list, the script after it
        lda     (D64_ISO_CUR_BLOCK),y
        sta     zde
        iny
        lda     (D64_ISO_CUR_BLOCK),y
        sta     zde+1
        lda     D64_ISO_CUR_BLOCK
        clc
        adc     #2
        sta     mi_ptr
        lda     D64_ISO_CUR_BLOCK+1
        adc     #0
        sta     mi_ptr+1
        txa                             ; A = the height
; 17F1 iso_enter_block: the 12 tile numbers from DE to 1BDDh, then as 17EEh.  In: DE = the tile list, mi_ptr =
; the script start, A = the height, HL = the position, BC = p2, p1.
mi_enter_block:
        tax
        ldy     #11
:       lda     (zde),y
        sta     D64_ISO_BLOCK_TILES,y
        dey
        bpl     :-
        txa
; 17EE iso_enter_block_keep_tiles: the depth of the block (iso_block_depth), then 1C26h: the caller's IX
; pushed (EX (SP),IX), IX = the script start, p1, p2 (1BE9h, 1BEAh) = C, B; the interpreter runs.
mi_enter_keep:
        jsr     iso_block_depth
        lda     zix+1
        pha
        lda     zix
        pha
        lda     mi_ptr
        sta     zix
        lda     mi_ptr+1
        sta     zix+1
        lda     zbc
        sta     D64_ISO_BLOCK_P1
        lda     zbc+1
        sta     D64_ISO_BLOCK_P2
; 1C2C the dispatcher: op = [IX++], the handler of ~op (opcodes FFh down to E4h), entered by RTS as the Z80's
; PUSH DE / RET; every handler comes back here.
mi_dispatch:
        ldy     #0
        lda     (zix),y
        inc     zix
        bne     :+
        inc     zix+1
:       eor     #$FF
        tax
        lda     mi_ops_hi,x
        pha
        lda     mi_ops_lo,x
        pha
        rts

; 1DFE iso_call_return: where END returns after a called block: the height, p1, p2, the depth, the bytes of
; 1D06h / 1E3Eh and 1C60h / 1C66h and HL restored; the 12 tile registers are not.  (The Z80 leaves BC = the last
; pair popped: nothing reads it before setting it.)
mi_call_return:
        ldx     #0
:       pla
        sta     D64_ISO_BLOCK_P1,x      ; p1, p2, height, depth x, depth y
        inx
        cpx     #5
        bne     :-
        pla
        sta     D64_ISO_STEP_RIGHT_INSN
        pla
        sta     D64_ISO_MIRROR
        pla
        sta     D64_ISO_OP_X_INC_INSN
        pla
        sta     D64_ISO_OP_X_DEC_INSN
        pla
        sta     zhl
        pla
        sta     zhl+1
        jmp     mi_dispatch

; FFh END (1C40): IX = the caller's pointer (popped); the keep flag (1BDCh) cleared, and when it was 0 the
; mirror undone (INC L at 1C60h and 1D06h, DEC L at 1C66h, 1E3Eh = 0); RTS to the tag.
mi_op_end:
        pla
        sta     zix
        pla
        sta     zix+1
        ldx     D64_ISO_KEEP_FLAG
        lda     #0
        sta     D64_ISO_KEEP_FLAG
        cpx     #0
        bne     :+
        jsr     mi_mirror_a
:       rts

; E9h-E5h MIRROR (1D9B): DEC L at 1C60h and 1D06h, INC L at 1C66h, 1E3Eh = 1 until the block's END.
mi_op_mirror:
        lda     #1
        jsr     mi_mirror_a
        jmp     mi_dispatch

; A = 0: the normal steps; A = 1: the mirrored ones
mi_mirror_a:
        sta     D64_ISO_MIRROR
        clc
        adc     #$2C                    ; INC L / DEC L
        sta     D64_ISO_OP_X_INC_INSN
        sta     D64_ISO_STEP_RIGHT_INSN
        eor     #1
        sta     D64_ISO_OP_X_DEC_INSN
        rts

; F6h Y_INC (1C5D), F4h Y_DEC (1C63): INC H, DEC H
mi_op_y_inc:
        inc     zhl+1
        jmp     mi_dispatch
mi_op_y_dec:
        dec     zhl+1
        jmp     mi_dispatch

; F5h X_INC (1C60), F3h X_DEC (1C66): the step opcode kept at the site (INC L / DEC L, swapped while mirroring)
mi_op_x_dec:
        ldx     D64_ISO_OP_X_DEC_INSN
        .byte   $2C                     ; BIT abs: skips the next LDX
mi_op_x_inc:
        ldx     D64_ISO_OP_X_INC_INSN
        jsr     mi_step_x
        jmp     mi_dispatch

; F2h Y_ADD (1C69), F1h X_ADD (1C74): H (L) += the expression (C = its value)
mi_op_y_add:
        lda     #1
        .byte   $2C
mi_op_x_add:
        lda     #0
        pha
        jsr     mi_fetch
        jsr     iso_expression
        pla
        tax
        lda     zhl,x
        clc
        adc     zbc
        sta     zhl,x
        jmp     mi_dispatch

; F0h P1_INC (1C85), EFh P2_INC (1C7F), EEh P1_DEC (1C91), EDh P2_DEC (1C8B): through 1C95h iso_reg_add, the
; register (p1 1BE9h, p2 1BEAh) += the delta; C = the delta
mi_op_p1_inc:
        ldx     #0
        beq     mi_inc
mi_op_p2_inc:
        ldx     #1
mi_inc: lda     #1
        bne     mi_reg_add
mi_op_p1_dec:
        ldx     #0
        beq     mi_dec
mi_op_p2_dec:
        ldx     #1
mi_dec: lda     #$FF
mi_reg_add:
        sta     zbc
        clc
        adc     D64_ISO_BLOCK_P1,x
        sta     D64_ISO_BLOCK_P1,x
        jmp     mi_dispatch

; FEh LOOP_P1 (1C9F), FDh LOOP_P2 (1CAC): C = the count p1 / p2; 0 skips to the matching NEXT, else the frame
; IX (the loop start), BC pushed.
mi_op_loop_p2:
        ldx     #1
        .byte   $2C                     ; BIT abs: skips the next LDX
mi_op_loop_p1:
        ldx     #0
        lda     D64_ISO_BLOCK_P1,x
        sta     zbc
        beq     mi_loop_skip
        lda     zix+1
        pha
        lda     zix
        pha
        lda     zbc+1
        pha
        lda     zbc
        pha
        jmp     mi_dispatch
; 1CB3: a byte scan to the matching NEXT (FAh): 82h skips its literal, FEh / FDh / E8h / E7h open a level, FAh
; closes one; B = 0 at the end.
mi_loop_skip:
        ldx     #1
@l:     ldy     #0
        lda     (zix),y
        inc     zix
        bne     :+
        inc     zix+1
:       cmp     #$82
        bne     :+
        inc     zix
        bne     @l
        inc     zix+1
        bne     @l
:       cmp     #$FE
        beq     @open
        cmp     #$FD
        beq     @open
        cmp     #$E8
        beq     @open
        cmp     #$E7
        beq     @open
        cmp     #$FA
        bne     @l
        dex
        bne     @l
        stx     zbc+1
        jmp     mi_dispatch
@open:  inx
        bne     @l

; FCh PUSH_POS (1CDD), FBh POP_POS (1CE1)
mi_op_push_pos:
        lda     zhl+1
        pha
        lda     zhl
        pha
        jmp     mi_dispatch
mi_op_pop_pos:
        pla
        sta     zhl
        pla
        sta     zhl+1
        jmp     mi_dispatch

; FAh NEXT (1CE5): C - 1 in the frame; 0: the frame dropped (BC = the popped loop start, as the Z80's POP BC),
; else IX = the loop start (the frame kept).  (The Z80 also leaves BC = the frame's: nothing reads it before
; setting it, so it is not copied.)
mi_op_next:
        tsx
        dec     $0101,x                 ; C of the frame
        beq     @end
        lda     $0103,x
        sta     zix
        lda     $0104,x
        sta     zix+1
        jmp     mi_dispatch
@end:   pla
        pla
        pla
        sta     zbc
        pla
        sta     zbc+1
        jmp     mi_dispatch

; F9h TILES_UP (1CF5, step DEC H), EBh TILES_LEFT (1CFC, DEC L), F8h TILES_RIGHT (1D03, the SMC byte of 1D06h:
; INC L, DEC L while mirroring): the tile run with that step
mi_op_up:
        lda     #$25
        jsr     mi_tile_run
        jmp     mi_dispatch
mi_op_left:
        lda     #$2D
        .byte   $2C
mi_op_right:
        lda     D64_ISO_STEP_RIGHT_INSN
        jsr     mi_tile_run
        jmp     mi_dispatch

; F7h SET (1D4F) reg expr: register := expression (C = the value).  Destination codes below 70h are stored as
; they are (a literal destination writes t1 at 1BDDh); the depth registers (70h / 71h, swapped while mirroring)
; keep the value 0, and take 0 for a result from 64h.
mi_op_set:
        ldy     #0
        lda     (zix),y
        sta     mi_t2                   ; the destination code
        jsr     mi_fetch
        stx     mi_t3                   ; its register
        jsr     mi_fetch
        jsr     iso_expression
        ldx     mi_t3
        lda     mi_t2
        cmp     #$70
        bcc     @st
        lda     D64_ISO_BLOCK_TILES,x
        beq     @end
        lda     zbc
        cmp     #$64
        bcc     @st
        lda     #0
        sta     zbc
@st:    lda     zbc
        sta     D64_ISO_BLOCK_TILES,x
@end:   jmp     mi_dispatch

; EAh JUMP (1DAF) addr: IX = the word
mi_op_jump:
        ldy     #1
        lda     (zix),y
        tax
        dey
        lda     (zix),y
        sta     zix
        stx     zix+1
        jmp     mi_dispatch

; E4h CALL_KEEP (1DB8, the keep flag, entry 17EEh) and ECh CALL (1DC2, entry 17F1h) block: the entry kept at
; 1DFCh; pushed as the Z80 does: HL, the bytes of 1C60h / 1C66h and 1D06h / 1E3Eh, the depth, p1 / p2, the
; height (the 6502 frame keeps the bytes, in its own order), the tag 1DFEh (mi_call_return); the block's script
; start, its tile list (DE) and the height (A) to the entry.
mi_op_call_keep:
        lda     #1
        sta     D64_ISO_KEEP_FLAG
        lda     #<MI_ENTER_KEEP
        .byte   $2C
mi_op_call:
        lda     #<MI_ENTER
        sta     D64_ISO_ENTER_VECTOR
        lda     #>MI_ENTER
        sta     D64_ISO_ENTER_VECTOR+1
        lda     zhl+1
        pha
        lda     zhl
        pha
        lda     D64_ISO_OP_X_DEC_INSN
        pha
        lda     D64_ISO_OP_X_INC_INSN
        pha
        lda     D64_ISO_MIRROR
        pha
        lda     D64_ISO_STEP_RIGHT_INSN
        pha
        ldx     #4                      ; depth y, depth x, height, p2, p1 (1BE9h-1BEDh)
:       lda     D64_ISO_BLOCK_P1,x
        pha
        dex
        bpl     :-
        lda     D64_ISO_BLOCK_P1        ; BC = p2, p1
        sta     zbc
        lda     D64_ISO_BLOCK_P2
        sta     zbc+1
        lda     #>(mi_call_return-1)
        pha
        lda     #<(mi_call_return-1)
        pha
        jsr     iso_fetch_word          ; DE = the block
        lda     zde
        clc
        adc     #2
        sta     mi_ptr
        lda     zde+1
        adc     #0
        sta     mi_ptr+1
        ldy     #0
        lda     (zde),y
        tax
        iny
        lda     (zde),y
        sta     zde+1
        stx     zde
        lda     D64_ISO_BLOCK_HEIGHT
        ldx     D64_ISO_ENTER_VECTOR    ; JP (1DFCh)
        cpx     #<MI_ENTER_KEEP
        bne     :+
        jmp     mi_enter_keep
:       jmp     mi_enter_block

; the handlers of opcodes FFh down to E4h (index ~op), minus one for the RTS
mi_ops_lo:
        .lobytes mi_op_end-1, mi_op_loop_p1-1, mi_op_loop_p2-1, mi_op_push_pos-1, mi_op_pop_pos-1, mi_op_next-1
        .lobytes mi_op_up-1, mi_op_right-1, mi_op_set-1, mi_op_y_inc-1, mi_op_x_inc-1, mi_op_y_dec-1
        .lobytes mi_op_x_dec-1, mi_op_y_add-1, mi_op_x_add-1, mi_op_p1_inc-1, mi_op_p2_inc-1, mi_op_p1_dec-1
        .lobytes mi_op_p2_dec-1, mi_op_call-1, mi_op_left-1, mi_op_jump-1, mi_op_mirror-1, mi_op_mirror-1
        .lobytes mi_op_mirror-1, mi_op_mirror-1, mi_op_mirror-1, mi_op_call_keep-1
mi_ops_hi:
        .hibytes mi_op_end-1, mi_op_loop_p1-1, mi_op_loop_p2-1, mi_op_push_pos-1, mi_op_pop_pos-1, mi_op_next-1
        .hibytes mi_op_up-1, mi_op_right-1, mi_op_set-1, mi_op_y_inc-1, mi_op_x_inc-1, mi_op_y_dec-1
        .hibytes mi_op_x_dec-1, mi_op_y_add-1, mi_op_x_add-1, mi_op_p1_inc-1, mi_op_p2_inc-1, mi_op_p1_dec-1
        .hibytes mi_op_p2_dec-1, mi_op_call-1, mi_op_left-1, mi_op_jump-1, mi_op_mirror-1, mi_op_mirror-1
        .hibytes mi_op_mirror-1, mi_op_mirror-1, mi_op_mirror-1, mi_op_call_keep-1

; 1D0A iso_tile_run: a tile run whose step opcode is the byte after the JSR (the call returns past it), as the
; Z80's CALL 1D0A / DB step.  The interpreter's handlers enter mi_tile_run with the step in A instead.
iso_tile_run:
        tsx
        inc     $0101,x                 ; the return address now points at the step byte: RTS goes past it
        bne     :+
        inc     $0102,x
:       lda     $0101,x
        sta     mi_ptr
        lda     $0102,x
        sta     mi_ptr+1
        ldy     #0
        lda     (mi_ptr),y
; the tile run with the step A (kept at 1D29h): tile = an operand; the next byte b: from C8h (the next opcode,
; not consumed) put, step, end; 80h put, step, next tile; 81h put without stepping, next tile; other: the count
; form (b skipped, a count operand, iso_put_tile_times when it is not 0, then the next byte ends the run from
; C8h, else it is skipped).  In: HL, IX, BC.  Out: HL, IX, C = the last tile, B kept; A (of iso_put_tile, or the
; opcode byte after a count form).
mi_tile_run:
        sta     D64_ISO_TILE_STEP_INSN
@tile:  ldy     #0                      ; C = the tile: mi_fetch, with the tile registers inline
        lda     (zix),y
        inc     zix
        bne     :+
        inc     zix+1
:       cmp     #$70
        bcs     @op
        cmp     #$60
        bcc     @op
        sbc     #$61
        tax
        lda     D64_ISO_BLOCK_TILES,x
        sta     zbc
        bcs     @next                   ; (C set)
@op:    jsr     mi_operand
@next:  ldy     #0
        lda     (zix),y
        cmp     #$C8
        bcs     @last
        inc     zix
        bne     :+
        inc     zix+1
:       cmp     #$80
        bne     :+
        jsr     iso_put_tile_step
        jmp     @tile
:       cmp     #$81
        bne     @count
        jsr     iso_put_tile
        jmp     @tile
@last:  jsr     iso_put_tile
        jmp     mi_step
@count: lda     zbc                     ; PUSH BC / the count / POP BC: C stays the tile
        pha
        jsr     mi_fetch
        tax
        pla
        sta     zbc
        txa
        beq     :+
        jsr     iso_put_tile_times
:       ldy     #0
        lda     (zix),y
        cmp     #$C8
        bcs     :+
        inc     zix
        bne     @tile
        inc     zix+1
        bne     @tile
:       rts

; 1D74 iso_expression: the rest of an expression: while [IX] < C8h, 84h negates the value so far, any other
; byte is an operand added to it; the byte that ends it is not consumed.  In: C = the first value, IX.
; Out: C, IX, A = [IX] (>= C8h); B kept.
iso_expression:
@l:     ldy     #0
        lda     (zix),y
        cmp     #$C8
        bcs     @r
        inc     zix
        bne     :+
        inc     zix+1
:       cmp     #$84
        bne     @add
        lda     #0
        sec
        sbc     zbc
        sta     zbc
        jmp     @l
@add:   ldx     zbc
        stx     mi_t0
        jsr     mi_operand
        clc
        adc     mi_t0
        sta     zbc
        jmp     @l
@r:     rts

; 1D90 iso_fetch_word: DE = the word at IX, IX += 2.
iso_fetch_word:
        ldy     #0
        lda     (zix),y
        sta     zde
        iny
        lda     (zix),y
        sta     zde+1
        lda     zix
        clc
        adc     #2
        sta     zix
        bcc     :+
        inc     zix+1
:       rts

; 1E22 iso_fetch_operand: A = [IX++], then iso_operand_value (the Z80 falls into it).
iso_fetch_operand:
        ldy     #0
        lda     (zix),y
        inc     zix
        bne     iso_operand_value
        inc     zix+1
; 1E27 iso_operand_value: the value of operand code A: below 60h the literal; 82h the literal byte [IX++]; else a
; register: codes from 70h XOR the mirror flag (1E3Eh: depth x <-> y), DE = 1BDDh + (code - 61h), the value
; [DE] (61h-6Ch tiles, 6Dh p1, 6Eh p2, 6Fh height, 70h / 71h depth).  Out: A = C = the value, Z of it, DE (1BDDh
; for a literal), IX.
iso_operand_value:
        jsr     mi_operand
        txa
        clc
        adc     #<D64_ISO_BLOCK_TILES
        sta     zde
        lda     #>D64_ISO_BLOCK_TILES
        adc     #0
        sta     zde+1
        lda     zbc
        rts

; the operand fetch of the interpreter: A = [IX++], then mi_operand
mi_fetch:
        ldy     #0
        lda     (zix),y
        inc     zix
        bne     mi_operand
        inc     zix+1
; the value of operand code A: A = C = the value, X = its register (DE - 1BDDh); Y clobbered.  The rooms use
; the codes below 60h, 61h-71h and 82h (all 129 rooms, both states of the mirror); the tile registers first.
mi_operand:
        cmp     #$70
        bcs     @high
        cmp     #$60
        bcc     @lit
        sbc     #$61                    ; C set
@reg:   tax
        lda     D64_ISO_BLOCK_TILES,x
        sta     zbc
        rts
@high:  cmp     #$82
        beq     @byte
        eor     D64_ISO_MIRROR          ; 70h / 71h: depth x / y, swapped while mirroring
        sec
        sbc     #$61
        bcs     @reg
@byte:  ldy     #0
        lda     (zix),y
        inc     zix
        bne     @lit
        inc     zix+1
@lit:   ldx     #0
        sta     zbc
        rts

; 1BC6 iso_block_depth: the depth of the block from its position HL (H = y, L = x) and height A: nothing for
; FFh; else t = A / 2 + y, depth x (1BECh) = t + x - 0Fh, depth y (1BEDh) = 10h + t - x.  X clobbered.
iso_block_depth:
        cmp     #$FF
        beq     @r
        lsr
        clc
        adc     zhl+1
        tax
        clc
        adc     zhl
        sec
        sbc     #$0F
        sta     D64_ISO_DEPTH_X
        txa
        clc
        adc     #$10
        sec
        sbc     zhl
        sta     D64_ISO_DEPTH_Y
@r:     rts

; ================================================================================================
; The camera and the room shown
; ================================================================================================

; 1F79 iso_update_camera_room: main-loop step.  The record of the character the camera follows ([28D9h]): x & F0h
; vs 28C6h (then the origin x 2636h = x - 0Ch), y & F0h vs 28C7h (origin y), the floor base of its height vs
; 28C8h (then the floor 264Eh and the floor map 2013h); each one that changed is stored and counted; none ->
; return (A = 0).  Else 2909h = the count; the room is dark (11DCh = 1) on floor 16h with room x >= 20h but the
; room (20h, 60h); the light sprite 2B20h = FEh; the camera orientation 20A5h = ((X ^ Y) & 1) | (X & 1) << 1 of
; the room coordinates; iso_select_room(map[Y << 4 | X]); chr_fill_height_buffer; the sprite offsets 28D5h =
; 2BF0h + 40h * orientation; the camera transform 2656h = the word 1E81h[orientation]; doors and objects placed;
; then for each chr_table entry (10 bytes, FFh in byte 1 ends): 2070h = sprite, 2074h = record, 25AEh = word +6,
; 25D9h = word +8, spr_update_char_sprite and chr_mark_hbuf (C = [record + 0Eh]).  Out: A = FFh (0 unchanged).
iso_update_camera_room:
        lda     #0
        sta     zbc
        lda     D64_CHR_CAMERA_TARGET
        sta     ziy
        lda     D64_CHR_CAMERA_TARGET+1
        sta     ziy+1
        ldx     #0                      ; x (28C6h, 2636h), then y (28C7h, 2640h)
        ldy     #2
@xy:    lda     (ziy),y
        and     #$F0
        cmp     D64_CHR_ROOM_X,x
        beq     :+
        sta     D64_CHR_ROOM_X,x
        inc     zbc
        sec
        sbc     #$0C
        sta     D64_CHR_ROOM_ORIGIN_X,x
:       iny
        inx
        cpx     #2
        bne     @xy
        lda     (ziy),y
        jsr     iso_floor_base
        lda     zbc+1
        cmp     D64_CHR_ROOM_Z
        beq     @count
        sta     D64_CHR_ROOM_FLOOR
        sta     D64_CHR_ROOM_Z
        inc     zbc
        ldx     #<MI_FLOOR0_MAP
        ldy     #>MI_FLOOR0_MAP
        cmp     #0
        beq     :+
        ldx     #<D64_ISO_FLOOR1_MAP
        ldy     #>D64_ISO_FLOOR1_MAP
        cmp     #$0B
        beq     :+
        ldx     #<D64_ISO_FLOOR2_MAP
        ldy     #>D64_ISO_FLOOR2_MAP
:       stx     D64_ISO_FLOOR_MAP_PTR
        sty     D64_ISO_FLOOR_MAP_PTR+1
@count: lda     zbc
        bne     :+
        rts
:       sta     D64_ISO_ROOM_CHANGED
        ldx     #0                      ; lit
        lda     D64_CHR_ROOM_Z
        cmp     #D64_ISO_DARK_FLOOR
        bne     @lit
        lda     D64_CHR_ROOM_X
        cmp     #$20
        bcc     @lit
        bne     @dark
        lda     D64_CHR_ROOM_Y
        cmp     #$60
        beq     @lit
@dark:  inx
@lit:   stx     D64_ISO_ROOM_DARK
        lda     #$FE
        sta     D64_SPR_LIGHT
        lda     D64_CHR_ROOM_X          ; the orientation: bit 1 = X & 1, bit 0 = (X ^ Y) & 1 (bit 4 of 28C6h, 28C7h)
        and     #$10
        asl
        sta     mi_t0
        lda     D64_CHR_ROOM_X
        eor     D64_CHR_ROOM_Y
        and     #$10
        ora     mi_t0
        lsr
        lsr
        lsr
        lsr
        sta     D64_ISO_CAMERA_ORIENT
        lda     D64_CHR_ROOM_X          ; the map index Y << 4 | X
        lsr
        lsr
        lsr
        lsr
        ora     D64_CHR_ROOM_Y
        tay
        lda     (D64_ISO_FLOOR_MAP_PTR),y
        jsr     iso_select_room
        jsr     chr_fill_height_buffer  ; IY = the record
        lda     D64_ISO_CAMERA_ORIENT   ; 28D5h = 2BF0h + 40h * orientation
        lsr
        ror
        ror
        clc
        adc     #<D64_CHR_SPRITE_OFFSET_TABLES
        sta     D64_CHR_SPRITE_OFFSETS
        lda     #>D64_CHR_SPRITE_OFFSET_TABLES
        adc     #0
        sta     D64_CHR_SPRITE_OFFSETS+1
        lda     D64_ISO_CAMERA_ORIENT   ; 2656h = the camera transform (a 6502 routine)
        asl
        tax
        lda     D64_ISO_CAMERA_ROTATIONS,x
        sta     D64_CHR_CAMERA_TRANSFORM
        lda     D64_ISO_CAMERA_ROTATIONS+1,x
        sta     D64_CHR_CAMERA_TRANSFORM+1
        jsr     obj_place_doors_in_room
        jsr     obj_place_objects_in_room
        ldx     #0
@entry: lda     D64_CHR_TABLE+1,x
        cmp     #$FF
        bne     :+
        rts                             ; A = FFh
:       txa
        pha
        ldy     #0                      ; 2070h = sprite, 2074h = record (zero page, in a row)
:       lda     D64_CHR_TABLE,x
        sta     D64_ISO_SETUP_SPRITE,y
        inx
        iny
        cpy     #4
        bne     :-
        lda     D64_CHR_TABLE+2,x       ; 25AEh = the flip routine, 25D9h = the animation table
        sta     D64_CHR_CUR_FLIP
        lda     D64_CHR_TABLE+3,x
        sta     D64_CHR_CUR_FLIP+1
        lda     D64_CHR_TABLE+4,x
        sta     D64_CHR_CUR_ANIM
        lda     D64_CHR_TABLE+5,x
        sta     D64_CHR_CUR_ANIM+1
        jsr     mi_setup_regs
        jsr     spr_update_char_sprite
        jsr     mi_setup_regs           ; (the Z80's IX, IY: the same 2070h, 2074h)
        ldy     #$0E
        lda     (ziy),y
        sta     zbc
        jsr     chr_mark_hbuf
        pla
        clc
        adc     #10
        tax
        bne     @entry

; IX = the sprite (2070h), IY = the record (2074h) of the chr_table entry being set up
mi_setup_regs:
        lda     D64_ISO_SETUP_SPRITE
        sta     zix
        lda     D64_ISO_SETUP_SPRITE+1
        sta     zix+1
        lda     D64_ISO_SETUP_RECORD
        sta     ziy
        lda     D64_ISO_SETUP_RECORD+1
        sta     ziy+1
        rts


; 2097 iso_floor_base: the floor of height A: B = 00h below 0Dh, 16h from 18h, else 0Bh; the carry as the Z80's
; (set when A < 18h), A kept.
iso_floor_base:
        ldx     #0
        cmp     #$0D
        bcc     @set
        ldx     #$16
        cmp     #$18
        bcs     @clr
        ldx     #$0B
@set:   stx     zbc+1
        sec
        rts
@clr:   stx     zbc+1
        clc
        rts

; 20A4 iso_orient_relative: A = (A - camera orientation) & 3 (the SUB operand at 20A5h).
iso_orient_relative:
        sec
        sbc     D64_ISO_CAMERA_ORIENT
        and     #3
        rts

; the camera transforms (2656h holds one): (x, y) = (L, H).  20A9 orientation 1: (28h - y, x), A = L;
; 20AE orientation 0: nothing; 20AF orientation 2: (28h - x, 28h - y), A = L; 20B8 orientation 3: (y, 28h - x),
; A = H.
iso_rotate_cam1:
        lda     #$28
        sec
        sbc     zhl+1
        ldx     zhl
        stx     zhl+1
        sta     zhl
iso_rotate_cam0:
        rts
iso_rotate_cam2:                        ; orientation 1 twice
        jsr     iso_rotate_cam1
        jmp     iso_rotate_cam1
iso_rotate_cam3:
        lda     #$28
        sec
        sbc     zhl
        ldx     zhl+1
        stx     zhl
        sta     zhl+1
        rts

; 1E6E vid_set_crtc: programs the CRTC (plat_crtc) with the (register, value) pairs after the JSR, up to a byte
; FFh, and returns past it.  (On the C64 the platform layer keeps or ignores them.)
vid_set_crtc:
        pla
        sta     mi_ptr
        pla
        sta     mi_ptr+1                ; the byte before the data
        ldy     #0
@pair:  iny
        lda     (mi_ptr),y              ; the register, or FFh
        cmp     #$FF
        beq     @end
        pha
        iny
        lda     (mi_ptr),y              ; the value
        tax
        pla
        sty     mi_t0
        jsr     plat_crtc               ; (Y clobbered)
        ldy     mi_t0
        bne     @pair
@end:   tya                             ; RTS to the byte after the FFh
        clc
        adc     mi_ptr
        tax
        lda     mi_ptr+1
        adc     #0
        pha
        txa
        pha
        rts
