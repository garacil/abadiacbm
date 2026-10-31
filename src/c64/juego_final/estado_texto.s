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

; abadia64ks, 6502 code of the game: group estado_texto (Z80 2FAD-3AAE; C reference juego/f_estado_texto.c,
; juego/datos_estado_texto.h).  The game state blocks and the new game, the room height buffer, the start-up,
; the text (font drawing and the phrase scroller), the script engine (RST 08h / RST 10h), the door permissions,
; the hour, the palettes.  Notes: c64/juego_estado_texto/NOTAS.md.
;
; Not translated (the C64 does not need them): 3598 hud_rows_from_hidden and 35B0 vid_copy_lines_to_row (the
; score bar is part of the bitmap image), the copy of the tiles 8300h to the hidden rows (the tiles are placed
; at $D000 by the image); 3607 vid_init_stub builds the C64 merge tables instead of the CPC's 8F00h-92FFh.
; The table entries that nothing in the C64 game calls (the RST wrappers and 3A5D if the script VM does not use
; them, 316E, the slopes, the CPC screen-address helpers) are in estado_texto_tabla.s, which the merge can drop.
        .include "zp.inc"
        .include "mapa.inc"

        .export obj_open_left_wing_doors, sys_check_pause_save_load, spr_unflip_monk_faces
        .export obj_fix_owner_pointers, spr_tile_ptr_check
        .export game_snapshot_initial_state, game_for_each_state_block, game_state_block_save
        .export game_state_block_restore, game_init_new_game
        .export chr_hbuf_fill_room, chr_hbuf_skip_list, util_clip_span
        .export sys_startup_init, game_init_mirror, vid_init_stub
        .export txt_draw_char_inverted, txt_draw_char
        .export t_frase                 ; txt_phrase_tick's work for sys_tick (personajes), which makes its test inline
.ifdef PRUEBA
        .export txt_phrase_tick, txt_skip_words ; the Z80 entries, for the checks only
        .export chr_hbuf_fill_list, chr_hbuf_clip_x, chr_hbuf_clip_y
        .export ai_script_eval, util_bits_set_or_clear
.endif
        .export estado_texto_eval_y
        .export ai_stay, ai_guillermo_is_close, ai_next_state_on_arrival, obj_set_door_permissions
        .export ai_hour_update, ai_say_phrase_param
        .export vid_palette_black, vid_palette_day, vid_palette_night

        .import plat_di, plat_ei, plat_tinta, plat_modo
.ifdef C128
        .import far_texto, far_palabras            ; (plataforma/c128.s: the texts in block 1)
.endif
        .import sys_key_pressed, sys_read_keyboard, snd_psg_write, spr_flip_graphics_h
        .import s_pon, s_empieza                ; objetos_sonido: a sequence starts (the beep), without / with DI ... EI
        .import iso_floor_base, util_add_bx_al, ai_clock_advance_hour, ai_hour_change_events, hud_say
        .import iso_mul24_lo, iso_mul24_hi      ; camino: 24 y (y = 0-23)

; the group's own zero page ($CE-$D9)
ET_C    = $CE                   ; the value of the expression being evaluated (top of the script stack)
ET_K    = $CF                   ; loop counters (2)
ET_M    = $D1                   ; a bit mask
ET_T    = $D2                   ; temporaries (2)
; $D4-$D9: the height lists' cache (HC_KEY, HC_N, HC_RES: chr_hbuf_fill_room)

ET_W    = 24                    ; the height buffer is 24 x 24 (D64_CHR_HBUF_SIZE of mapa64.inc is its byte size)

.ifdef C128
        .import cab_gira_cara
.endif
.segment "CODE"

; =============================================================================================================
; the script engine: 3926 ai_script_eval, the evaluator logica_b's script VM calls (the Z80's RST 08h / RST 10h
; wrappers 391E / 38FC, 3994, 3910 and the inline jump table 3A5D are in estado_texto_tabla.s)
;
; An expression is postfix: operands (40h nn: literal nn; 00h-7Fh: literal; 80h-C0h: the script variable whose
; address is word (2 op) mod 256 of ai_script_vars) and operators (3Dh '=' 00h if equal else FFh, 3Eh '>' 00h
; if e >= c, 3Ch '<' 00h if e < c, 2Ah '*' AND, 26h '&' OR, 2Bh '+', 2Dh '-' e - c; c the top, e the value
; below it).  It ends at the first byte, in operator position, that is one of the Z80 opcodes 20h D7h C2h CDh
; CFh C9h C3h 18h (the instruction after the expression in the Z80 code).  The values below the top are on
; the 6502 stack (at most 3 in the game's 570 expressions).
; =============================================================================================================

; 3926 ai_script_eval: evaluates the expression at zhl.  Out: zhl = the address of its terminator, A = the
; terminator byte, X = zbc (C) = the value, N/Z of the value (the Z80 leaves Z = 1 there); Y and ET_C changed,
; zbc+1, zde, zt0-zp0 and the other zero page untouched, the stack balanced.  Not reentrant (ET_C and the
; self-modified operand at et_ld): not for the interrupt.  (This entry: the checks only; logica_b's VM enters at
; estado_texto_eval_y.)
.ifdef PRUEBA
ai_script_eval:
        ldy     #0
        beq     et_opnd                 ; (always)
.endif
et_push:                                ; not an operator: push the value, read an operand
        lda     ET_C
        pha
estado_texto_eval_y:                    ; the same with the expression at zhl + Y (estado_texto_tabla.s)
et_opnd:
        lda     (zhl),y
        bmi     et_var
        iny
        cmp     #$40
        bne     et_lit
        lda     (zhl),y                 ; 40h nn: the literal nn
        iny
et_lit: sta     ET_C
et_loop:
        lda     (zhl),y
        bmi     et_hi
        cmp     #$3D
        beq     et_eq
        cmp     #$20
        beq     et_end
        bcc     et_lo
        cmp     #$40
        bcc     et_mid                  ; 21h-3Fh: the operators
        bcs     et_push                 ; 40h-7Fh: an operand
et_lo:  cmp     #$18
        beq     et_end
        bne     et_push
et_hi:  cmp     #$C2
        bcc     et_push                 ; 80h-C1h: a variable
        cmp     #$C9                    ; the terminators C2h-D7h
        beq     et_end
        cmp     #$D7
        beq     et_end
        cmp     #$CF
        beq     et_end
        cmp     #$CD
        beq     et_end
        cmp     #$C3
        beq     et_end
        cmp     #$C2
        beq     et_end
        bne     et_push
et_var: iny
        asl                             ; the variable's address: word 2 op (mod 256) of the table
        tax
        lda     D64_AI_SCRIPT_VARS,x
        sta     et_ld+1
        lda     D64_AI_SCRIPT_VARS+1,x
        sta     et_ld+2
et_ld:  lda     $FFFF                   ; (self-modified)
        sta     ET_C
        bcs     et_loop                 ; (always: C from the ASL of a byte >= 80h)
et_end: tax                             ; the terminator
        tya
        clc
        adc     zhl
        sta     zhl
        bcc     :+
        inc     zhl+1
:       txa
        ldx     ET_C
        stx     zbc
        rts
et_mid: iny
        cmp     #$26
        beq     et_or
        cmp     #$2A
        beq     et_and
        cmp     #$3E
        beq     et_ge
        cmp     #$3C
        beq     et_lt
        cmp     #$2B
        beq     et_add
        cmp     #$2D
        beq     et_sub
        dey                             ; any other byte: an operand
        jmp     et_push
et_eq:  iny                             ; '=': 00h if e = c else FFh
        pla
        eor     ET_C
        beq     et_st
        lda     #$FF
        bne     et_st
et_ge:  pla                             ; '>': 00h if e >= c else FFh
        cmp     ET_C
        lda     #0
        sbc     #0
        jmp     et_st
et_lt:  pla                             ; '<': 00h if e < c else FFh
        cmp     ET_C
        lda     #0
        sbc     #0
        eor     #$FF
        jmp     et_st
et_and: pla
        and     ET_C
        jmp     et_st
et_or:  pla
        ora     ET_C
        jmp     et_st
et_add: pla
        clc
        adc     ET_C
        jmp     et_st
et_sub: pla                             ; e - c
        sec
        sbc     ET_C
et_st:  sta     ET_C
        jmp     et_loop

; 39A8 ai_stay: ai_no_route := 1 (no route planned this frame).  A = 1.
ai_stay:
        lda     #1
        sta     D64_AI_NO_ROUTE
        rts

; 39AE ai_guillermo_is_close: Z set when Guillermo is on the floor of the character at ziy and inside the box
; in front of it (ai_close_box_table, 4 bytes per orientation: x offset, x size, y offset, y size).
ai_guillermo_is_close:
        lda     D64_CHR_GUILLERMO+4
        jsr     iso_floor_base
        lda     zbc+1
        sta     ET_T
        ldy     #4
        lda     (ziy),y
        jsr     iso_floor_base
        lda     zbc+1
        cmp     ET_T
        bne     @r
        ldy     #1
        lda     (ziy),y
        asl
        asl
        tax
        lda     D64_CHR_GUILLERMO+2
        clc
        adc     D64_AI_CLOSE_BOX_TABLE,x
        iny
        sec
        sbc     (ziy),y
        cmp     D64_AI_CLOSE_BOX_TABLE+1,x
        bcs     @no
        lda     D64_CHR_GUILLERMO+3
        clc
        adc     D64_AI_CLOSE_BOX_TABLE+2,x
        iny
        sec
        sbc     (ziy),y
        cmp     D64_AI_CLOSE_BOX_TABLE+3,x
        bcs     @no
        lda     #0
@r:     rts
@no:    lda     #$FF
        rts

; 39E5 ai_next_state_on_arrival: when [zix-1] (the destination) = [zix-3] (the place reached), [zix-2] += 1,
; A = 0 and Z set; else A = [zix-1], Z clear.
ai_next_state_on_arrival:
        lda     zix
        sec
        sbc     #3
        sta     zt0
        lda     zix+1
        sbc     #0
        sta     zt0+1
        ldy     #2
        lda     (zt0),y
        ldy     #0
        cmp     (zt0),y
        bne     @r
        iny
        lda     (zt0),y
        clc
        adc     #1
        sta     (zt0),y
        lda     #0
@r:     rts

; 39F1 obj_set_door_permissions: ai_random := chr_command_buffers[0]; for the 6 doors of obj_door_link_table
; ((index into chr_room_links, bits) pairs, FFh ends a door) the bits are cleared when the door's bit of
; zbc (C) AND obj_door_check_mask is set (the opcode at 3A24 = CCF), else set (NOP).  Out: A = FFh, B = 0,
; C = that mask >> 6, zhl = chr_room_links.
obj_set_door_permissions:
.ifdef COMPLETO
        lda     D64_CHR_COMMAND_BUFFERS+4*45    ; abadia128ks, the full game: the first command buffer of the PC (and the
.else                                   ; 6128) is Adso's (the 64 KiB game's order: Malachi, the abbot, Berengar,
        lda     D64_CHR_COMMAND_BUFFERS ; Severin, Adso; the PC's: Adso first, 1000:5D0F reads it)
.endif
        sta     D64_AI_RANDOM
        lda     D64_OBJ_DOOR_CHECK_MASK
        and     zbc
        sta     zbc
        lda     #6
        sta     zbc+1
        ldx     #0
@door:  lsr     zbc
        lda     #0
        bcc     @op
        lda     #$3F                    ; CCF: the door is allowed (its bits cleared)
@op:    sta     D64_OBJ_DOOR_ALLOW_OP
        bcs     @clr
.ifdef VELOZ
@set:   ldy     D64_OBJ_DOOR_LINK_TABLE,x   ; the door's two pairs (every door of the table has two, then
        lda     D64_CHR_ROOM_LINKS,y        ; its FFh: 5 bytes a door, juego/datos_estado_texto.h)
        ora     D64_OBJ_DOOR_LINK_TABLE+1,x
        sta     D64_CHR_ROOM_LINKS,y
        ldy     D64_OBJ_DOOR_LINK_TABLE+2,x
.else
@set:   ldy     D64_OBJ_DOOR_LINK_TABLE,x
        inx
        cpy     #$FF
        beq     @nd
.endif
        lda     D64_CHR_ROOM_LINKS,y
.ifdef VELOZ
        ora     D64_OBJ_DOOR_LINK_TABLE+3,x
.else
        ora     D64_OBJ_DOOR_LINK_TABLE,x
.endif
        sta     D64_CHR_ROOM_LINKS,y
.ifdef VELOZ
        bcc     @nd                     ; (always)
.else
        inx
        bne     @set
.endif
@clr:   ldy     D64_OBJ_DOOR_LINK_TABLE,x
.ifdef VELOZ
        lda     D64_OBJ_DOOR_LINK_TABLE+1,x
.else
        inx
        cpy     #$FF
        beq     @nd
        lda     D64_OBJ_DOOR_LINK_TABLE,x
.endif
        eor     #$FF
        and     D64_CHR_ROOM_LINKS,y
        sta     D64_CHR_ROOM_LINKS,y
.ifdef VELOZ
        ldy     D64_OBJ_DOOR_LINK_TABLE+2,x
        lda     D64_OBJ_DOOR_LINK_TABLE+3,x
        eor     #$FF
        and     D64_CHR_ROOM_LINKS,y
        sta     D64_CHR_ROOM_LINKS,y
@nd:    inx                             ; the next door's 5 bytes
.endif
        inx
.ifdef VELOZ
        inx
        inx
        inx
        dec     zbc+1
.else
        bne     @clr
@nd:    dec     zbc+1
.endif
        bne     @door
.ifdef VELOZ
        ldy     #$FF                    ; (Y and C as the loop left them)
        sec
.endif
        lda     #<D64_CHR_ROOM_LINKS
        sta     zhl
        lda     #>D64_CHR_ROOM_LINKS
        sta     zhl+1
        lda     #$FF
        rts

; 3A30 util_bits_set_or_clear: C set -> A = zde (E) AND NOT A, else A = zde OR A.  (The checks only: no 6502
; routine calls it.)
.ifdef PRUEBA
util_bits_set_or_clear:
        bcc     @set
        eor     #$FF
        and     zde
        rts
@set:   ora     zde
        rts
.endif

; 3A37 ai_hour_update: txt_phrase_busy := txt_phrase_active; nothing more while the camera character is
; between two steps; when ai_advance_hour is set and no phrase is shown, it is cleared and the hour advances;
; then the hour-change actions (tail call).
ai_hour_update:
        lda     D64_TXT_PHRASE_ACTIVE
        sta     D64_TXT_PHRASE_BUSY
        lda     D64_CHR_CAMERA_TARGET
        sta     zhl
        lda     D64_CHR_CAMERA_TARGET+1
        sta     zhl+1
        ldy     #0
        lda     (zhl),y
        and     #1
        bne     @r
        lda     D64_AI_ADVANCE_HOUR
        beq     @ev
        lda     D64_TXT_PHRASE_BUSY
        bne     @r
        sta     D64_AI_ADVANCE_HOUR
        jsr     ai_clock_advance_hour
@ev:    jmp     ai_hour_change_events
@r:     rts

; 3A58 ai_say_phrase_param: hud_say of the phrase in the script variable ai_phrase_param (A2h); hud_say reads
; its phrase inline after its JSR, so the variable is copied there.
ai_say_phrase_param:
        lda     D64_AI_PHRASE_PARAM
        sta     @b
        jsr     hud_say
@b:     .byte   0
        rts

; =============================================================================================================
; the state blocks and the new game
; =============================================================================================================

; 2FAD obj_open_left_wing_doors: the doors 5 and 6 of obj_doors (bytes 0-1) = E002h and C002h.  zhl = C002h.
obj_open_left_wing_doors:
        lda     #$02
        sta     D64_OBJ_DOORS+$19
        sta     D64_OBJ_DOORS+$1E
        sta     zhl
        lda     #$E0
        sta     D64_OBJ_DOORS+$1A
        lda     #$C0
        sta     D64_OBJ_DOORS+$1F
        sta     zhl+1
        rts

; 30FD spr_tile_ptr_check: C clear when zix lies inside the tile buffer.  zhl = zix - its start (below it) or
; zix - its end.
spr_tile_ptr_check:
        sec
        lda     zix
        sbc     #<D64_ISO_TILE_BUFFER
        sta     zhl
        lda     zix+1
        sbc     #>D64_ISO_TILE_BUFFER
        sta     zhl+1
        bcc     @out
        lda     zhl
        sbc     #<D64_ISO_TILE_BUFFER_SIZE
        sta     zhl
        lda     zhl+1
        sbc     #>D64_ISO_TILE_BUFFER_SIZE
        sta     zhl+1
        rts                             ; inside: borrow, C clear; past it: C set
@out:   sec
        rts

; 310E game_snapshot_initial_state: the state blocks into game_initial_state (start-up).
game_snapshot_initial_state:
        lda     #<game_state_block_save
        sta     zhl
        lda     #>game_state_block_save
        sta     zhl+1
; 3111 game_for_each_state_block: game_state_block_fn := zhl (save or restore), called for each (address,
; length) entry of game_state_blocks with a cursor into game_initial_state.  Out: A = 0, Z set, BC = 0.
game_for_each_state_block:
        lda     zhl
        sta     D64_GAME_STATE_BLOCK_FN
        lda     zhl+1
        sta     D64_GAME_STATE_BLOCK_FN+1
        lda     #<D64_GAME_INITIAL_STATE
        sta     zhl
        lda     #>D64_GAME_INITIAL_STATE
        sta     zhl+1
        ldx     #0
@l:     lda     D64_GAME_STATE_BLOCKS,x
        sta     zde
        lda     D64_GAME_STATE_BLOCKS+1,x
        sta     zde+1
        ora     zde
        beq     @end
        lda     D64_GAME_STATE_BLOCKS+2,x
        sta     zbc
        stx     ET_K
        jsr     @call
        lda     ET_K
        clc
        adc     #3
        tax
        bne     @l
@end:   sta     zbc
        sta     zbc+1
        rts
@call:  jmp     (D64_GAME_STATE_BLOCK_FN)

; 3166 game_state_block_save: zbc (C, 1-255; B = 0) bytes from zde (the block) to zhl (the cursor);
; 316B game_state_block_restore: from zhl to zde.  Out: zhl and zde advanced, BC = 0.
game_state_block_save:
        ldy     #0
:       lda     (zde),y
        sta     (zhl),y
        iny
        cpy     zbc
        bne     :-
        beq     et_adv
game_state_block_restore:
        ldy     #0
:       lda     (zhl),y
        sta     (zde),y
        iny
        cpy     zbc
        bne     :-
et_adv: tya
        jsr     util_add_bx_al
        tya
        clc
        adc     zde
        sta     zde
        bcc     :+
        inc     zde+1
:       lda     #0
        sta     zbc
        sta     zbc+1
        rts

; 3176 game_init_new_game: clears 37D2-37F2 and 28DE-2929, restores the state blocks, hides every sprite
; (byte 0 = FEh up to the FFh end) and resets the six character records.  Out: A = 0, zhl = the FFh.
game_init_new_game:
        lda     #0
        ldx     #$20
:       sta     D64_GAME_BOOK_POISON_COUNT,x
        dex
        bpl     :-
        ldx     #$4B
:       sta     D64_ISO_MIRROR_STATE_GUILLERMO,x
        dex
        bpl     :-
        lda     #<game_state_block_restore
        sta     zhl
        lda     #>game_state_block_restore
        sta     zhl+1
        jsr     game_for_each_state_block
        lda     #<D64_SPR_TABLE
        sta     zhl
        lda     #>D64_SPR_TABLE
        sta     zhl+1
        ldy     #0
@s:     lda     (zhl),y
        cmp     #$FF
        beq     @chr
        lda     #$FE
        sta     (zhl),y
        lda     #20
        jsr     util_add_bx_al
        bne     @s                      ; (A = H, never 0)
@chr:   ldx     #5*15
@r:     lda     #0
        sta     D64_CHR_GUILLERMO,x
        sta     D64_CHR_GUILLERMO+5,x
        sta     D64_CHR_GUILLERMO+9,x
        sta     D64_CHR_GUILLERMO+$0B,x
.ifdef COMPLETO
        sta     D64_CHR_GUILLERMO+1,x   ; abadia128ks, the full game: orientation 0 (PC 1000:33BB; the 64 KiB game: 1)
.else
        lda     #1
        sta     D64_CHR_GUILLERMO+1,x
.endif
        lda     #$FD
        sta     D64_CHR_GUILLERMO+$0A,x
        txa
        sec
        sbc     #15
        tax
        bcs     @r
        lda     #0
        rts

; 304F spr_unflip_monk_faces: for the four monks whose record +6 (face flipped) is set: cleared, and the face
; spr_monk_faces[k] flipped back (spr_flip_graphics_h, 20 lines of 5 CPC bytes).
spr_unflip_monk_faces:
        ldx     #0
        stx     ET_K
        stx     ET_K+1
@l:     ldx     ET_K
        lda     D64_CHR_MALACHI+6,x
        beq     @n
        lda     #0
        sta     D64_CHR_MALACHI+6,x
        ldy     ET_K+1
        lda     D64_SPR_MONK_FACES,y
        sta     zhl
        lda     D64_SPR_MONK_FACES+1,y
        sta     zhl+1
        lda     #$05
        sta     zbc
        lda     #$14
        sta     zbc+1
.ifdef C128
        ldx     ET_K+1                  ; the C128: the face block's black follows it (cabezas128.s)
        jsr     cab_gira_cara
.endif
        jsr     spr_flip_graphics_h
@n:     lda     ET_K
        clc
        adc     #15
        sta     ET_K
        inc     ET_K+1
        inc     ET_K+1
        lda     ET_K+1
        cmp     #8
        bne     @l
        rts

; 3087 obj_fix_owner_pointers (after a load): the holders of the taken objects (the lamp: game_adso_lamp; the
; others: the obj_char_objects entry whose mask +3 has their bit, or the 6th entry), then the six position
; pointers chr_pos_ptrs into +1/+2 of the entries of obj_door_permissions (3 bytes) and obj_char_objects (7).
obj_fix_owner_pointers:
        lda     D64_OBJ_OBJECTS+$28
        bpl     @o0
        lda     #<D64_GAME_ADSO_LAMP
        sta     D64_OBJ_OBJECTS+$2A
        lda     #>D64_GAME_ADSO_LAMP
        sta     D64_OBJ_OBJECTS+$2B
@o0:    lda     #$80
        sta     ET_M
        ldx     #0
@o:     lda     D64_OBJ_OBJECTS,x
        bpl     @on
        ldy     #3
        lda     #5
        sta     ET_K
@s:     lda     D64_OBJ_CHAR_OBJECTS,y
        and     ET_M
        bne     @f
        tya
        clc
        adc     #7
        tay
        dec     ET_K
        bne     @s
@f:     tya
        clc
        adc     #<(D64_OBJ_CHAR_OBJECTS-3)
        sta     D64_OBJ_OBJECTS+2,x
        lda     #>(D64_OBJ_CHAR_OBJECTS-3)
        adc     #0
        sta     D64_OBJ_OBJECTS+3,x
@on:    txa
        clc
        adc     #5
        tax
        lsr     ET_M
        bcc     @o
        ldx     #0                      ; X = 2k, Y = 3k
        ldy     #0
@p:     lda     D64_CHR_POS_PTRS,x
        sta     D64_OBJ_DOOR_PERMISSIONS+1,y
        lda     D64_CHR_POS_PTRS+1,x
        sta     D64_OBJ_DOOR_PERMISSIONS+2,y
        iny
        iny
        iny
        inx
        inx
        cpx     #12
        bne     @p
        ldx     #0                      ; X = 2k, Y = 7k
        ldy     #0
@q:     lda     D64_CHR_POS_PTRS,x
        sta     D64_OBJ_CHAR_OBJECTS+1,y
        lda     D64_CHR_POS_PTRS+1,x
        sta     D64_OBJ_CHAR_OBJECTS+2,y
        tya
        clc
        adc     #7
        tay
        inx
        inx
        cpx     #12
        bne     @q
        rts

; 2FB9 sys_check_pause_save_load: the key 4Fh (Del) pauses: interrupts off, the mixer copy and PSG register 7
; := 3Fh, then the keyboard is read until 4Fh is pressed again; interrupts on.  Out: A (Z) = the last
; sys_key_pressed.
sys_check_pause_save_load:
        lda     #$4F
        jsr     sys_key_pressed
        beq     @r
        jsr     plat_di
        lda     #$3F
        sta     D64_SND_CHANNEL_MASK_COPY
        sta     zbc
        lda     #7
        jsr     snd_psg_write
@w:     jsr     sys_read_keyboard
        lda     #$4F
        jsr     sys_key_pressed
        beq     @w
        jsr     plat_ei
@r:     rts

; =============================================================================================================
; the room height buffer (24 x 24 at [chr_hbuf_ptr]) from a height list: records h<<4 | big<<3 | kind, x, y,
; then (nx-1)<<4 | (ny-1) (4 bytes) or nx-1, ny-1 (5 bytes); FFh ends
; =============================================================================================================

; The fill keeps a cache of its last list and window ($D4-$D9 and $C3E8-$C3FF).  The lists never change but for
; the library's last record, the mirror's (the 5 bytes at [obj_mirror_height_ptr]: the record when closed, FFh
; when open, F5h after a load), so a window shows the same records of a list at every fill.  A fill with another
; list or window (a miss) scans the whole list and keeps the addresses of its first HC_MAX visible records and
; where a later scan must resume: at the first visible record not kept, else at the FFh or (the library's list)
; the mirror's place.  A fill with the same list and window (a hit: most fills, the path searches of the
; characters in the same rooms) draws the kept records again and scans from the resume point only.  The same
; records are drawn in the same order, so the buffer, the Z80's operands and the end of the list are those of a
; whole scan; a kept record that has become FFh (the mirror opened) ends the list there, as the scan does.
; Neither $D4-$D9 nor $C3E8-$C3FF is loaded from the disk: principal's 2151 (the game's start, a new game, a
; loaded game) empties the cache with hbuf_cache_key = 0 (no list's high byte) before any fill.
hbuf_cache_key = $D4            ; exported for principal.s
        .exportzp hbuf_cache_key
HC_KEY  = hbuf_cache_key        ; the last fill's list (its high byte: the three lists' differ) and window x, y
HC_N    = $D7                   ; the records kept
HC_RES  = $D8                   ; the resume point (2; high byte 0 during a miss's scan: not known yet)
HC_MAX  = 12                    ; (a room's window shows at most 20, 15, 44 records of the three lists)
HC_LO   = $C3E8                 ; the kept records' addresses, low and high bytes: the 24 bytes after the screen
.ifdef C128
HC_HI   = G_HC_HI               ; (the C128: the heads' sprites use the VIC's pointers $C3F8-$C3FF; mapa64.py hc_hi)
.else
HC_HI   = HC_LO + HC_MAX        ; RAM (c64/MAPA.md; $C3F8-$C3FF are the VIC's sprite pointers: the sprites are off)
        .assert HC_HI + HC_MAX = $C400, error, "the cache's 24 bytes"
.endif

HB_NX   = zt0                   ; visible columns, rows (indexed by the axis: X = 0 / 1)
HB_NY   = zt0+1
HB_SKX  = zt0+2                 ; the first visible column, row of the block
HB_SKY  = zt0+3
HB_STX  = zt0+4                 ; its place in the buffer: column, row
HB_ROW  = zt0+5
HB_DC   = zt0+6                 ; height step per column, row (0, 1, FFh)
HB_DR   = zt0+7
HB_H    = zp0                   ; height of the first cell of the row
HB_P    = zp0+1                 ; the buffer cell (2)
HB_I    = zp0+3                 ; a hit: the next kept record; FFh: scanning
HB_AX   = zp0+4                 ; hb_span's axis
HB_R    = zp0+5                 ; the record (2)

        .assert >D64_CHR_FLOOR0_HEIGHTS <> >D64_CHR_FLOOR1_HEIGHTS && >D64_CHR_FLOOR0_HEIGHTS <> >D64_CHR_FLOOR2_HEIGHTS && >D64_CHR_FLOOR1_HEIGHTS <> >D64_CHR_FLOOR2_HEIGHTS, error, "the cache keys a list by its high byte"
        .assert D64_CHR_FLOOR0_HEIGHTS < D64_CHR_FLOOR2_HEIGHTS && D64_CHR_FLOOR1_HEIGHTS < D64_CHR_FLOOR2_HEIGHTS, error, "the first two lists end before the mirror's place"
        .assert D64_CHR_HBUF_WIN_Y_OP = D64_CHR_HBUF_WIN_X_OP + 1 && D64_CHR_HBUF_ROW_STEP_OP = D64_CHR_HBUF_COL_STEP_OP + 1, error, "indexed by the axis"

; 346E chr_hbuf_fill_list (the Z80 entry: only the checks call it): the list at zix.  Out: zix = the FFh, C = 0,
; A = 0, Z set.
.ifdef PRUEBA
chr_hbuf_fill_list:
        lda     zix
        sta     HB_R
        lda     zix+1
        sta     HB_R+1
        jsr     hb_list
        lda     HB_R
        sta     zix
        lda     HB_R+1
        sta     zix+1
        lda     #0
        rts
.endif

; 3456 chr_hbuf_fill_room: the window origin into the operands at 354A / 354E, then the current floor's list.
; zix kept; C = 0, A = 0, Z set.
chr_hbuf_fill_room:
        lda     D64_CHR_HBUF_ORIGIN_X
        sta     D64_CHR_HBUF_WIN_X_OP
        lda     D64_CHR_HBUF_ORIGIN_Y
        sta     D64_CHR_HBUF_WIN_Y_OP
        lda     D64_CHR_FLOOR_HEIGHTS_PTR
        sta     HB_R
        lda     D64_CHR_FLOOR_HEIGHTS_PTR+1
        sta     HB_R+1
                                        ; (falls into hb_list)
; the buffer from the list at HB_R (each record clipped to the window; kind 5 flat, kinds 1-4 slopes of +1/-1
; per column or row, the others flat), keeping the Z80's operands (the visible width at 34EA/3510, the step
; opcodes at 3515/351C).  Out: HB_R = the FFh, C = 0, A = 0, Z set.
hb_list:
        lda     HB_R+1                  ; the same list and window as the last fill?
        ldx     D64_CHR_HBUF_WIN_X_OP
        ldy     D64_CHR_HBUF_WIN_Y_OP
        cmp     HC_KEY
        bne     @miss
        cpx     HC_KEY+1
        bne     @miss
        cpy     HC_KEY+2
        bne     @miss
        ldy     #0                      ; a hit: the kept records, then the scan from the resume point
@kept:  cpy     HC_N
        bcs     @res
        lda     HC_LO,y
        sta     HB_R
        lda     HC_HI,y
        sta     HB_R+1
        iny
        sty     HB_I
        bne     @rec                    ; (always)
@miss:  sta     HC_KEY                  ; a miss: the new key, nothing kept, the resume point not known
        stx     HC_KEY+1
        sty     HC_KEY+2
        lda     #0
        sta     HC_N
        sta     HC_RES+1
        beq     @scan                   ; (always)
@res:   lda     HC_RES
        sta     HB_R
        lda     HC_RES+1
        sta     HB_R+1
@scan:  lda     #$FF
        sta     HB_I
@rec:   ldy     #0
        lda     (HB_R),y
        cmp     #$FF                    ; (a kept record become FFh: the mirror opened, the list ends there)
        beq     @end
        tax                             ; (for hb_draw)
        iny                             ; a quick test of the x span, by util_clip_span's rule (hb_draw clips the
        lda     (HB_R),y                ; spans that pass): hidden when it starts 24 or more right of the window's
        sec                             ; left edge, or left of it by e with e - 1 >= byte 3 (5 bytes: columns - 1;
        sbc     D64_CHR_HBUF_WIN_X_OP   ; 4 bytes: (columns - 1) << 4 | rows - 1, so e - 1 >= columns - 1 too)
        bcs     @xr
        eor     #$FF                    ; e - 1
        ldy     #3
        cmp     (HB_R),y
        bcs     @nx
        bcc     @draw
@xr:    cmp     #ET_W
        bcs     @nx
@draw:  jsr     hb_draw
@nx:    ldy     HB_I
        bpl     @kept
        ldy     #0                      ; scanning: the next record, 4 or 5 bytes on
        lda     (HB_R),y
        and     #8
        lsr
        lsr
        lsr
        adc     #4
        adc     HB_R
        sta     HB_R
        bcc     @rec
        inc     HB_R+1
        bcs     @rec                    ; (always)
@end:   lda     HC_RES+1                ; the FFh.  After a miss's scan the resume point is the FFh, or in the
        bne     @out                    ; library's list the mirror's place (at or before the FFh)
        ldy     HB_R
        ldx     HB_R+1
        lda     HC_KEY
        cmp     #>D64_CHR_FLOOR2_HEIGHTS
        bne     :+
        ldy     D64_OBJ_MIRROR_HEIGHT_PTR
        ldx     D64_OBJ_MIRROR_HEIGHT_PTR+1
:       sty     HC_RES
        stx     HC_RES+1
@out:   lda     #0
        sta     zbc
        rts

; one span of the record at HB_R against the window (util_clip_span), X = the axis (0: x, the window at 354A;
; 1: y, at 354E), Y = its first coordinate's byte (1, 2), A = its count - 1.  C set: it shows, HB_NX,x = the
; visible count, HB_SKX,x = the first visible one, HB_STX,x = its place in the buffer.  X, Y kept.
.ifdef VELOZ
; (util_clip_span's three cases are made inline with the window's width ET_W and the results stored straight
; into HB_NX,x / HB_SKX,x / HB_STX,x: the same arithmetic on the same bytes; zde+1 holds the count; A and the
; flags at the exit are as before: A = the place when visible, else the distance.)
.endif
hb_span:
.ifdef VELOZ
        clc
        adc     #1
        sta     zde+1                   ; D = the count
.else
        sta     zde+1
        lda     (HB_R),y
        sta     zhl+1
.endif
        lda     D64_CHR_HBUF_WIN_X_OP,x
.ifdef VELOZ
        sec
        sbc     (HB_R),y                ; window - span
        beq     @al
        bcc     @aft
        cmp     zde+1                   ; the span starts before the window: hidden when it ends before it
        bcs     @hid
        sta     HB_SKX,x                ; the first visible one
        lda     #0
        sta     HB_STX,x                ; its place: the window's first
        lda     HB_SKX,x
        adc     #ET_W                   ; (C clear) the window's end in the span
        cmp     zde+1
        bcs     @part
        lda     #ET_W                   ; the whole window shows
        bne     @all                    ; (always)
@part:  lda     zde+1                   ; (C set) the rest of the span
        sbc     HB_SKX,x
        sta     HB_NX,x
        lda     HB_STX,x                ; (A = the place, as before)
        rts
@al:    sta     HB_SKX,x                ; aligned (A = 0)
        sta     HB_STX,x
.else
        sta     zhl
.endif
        lda     #ET_W
.ifdef VELOZ
        cmp     zde+1
        bcc     @all
        lda     zde+1                   ; (C set) the span is shorter than the window
.else
        sta     zde
        inc     zde+1
        stx     HB_AX
        jsr     util_clip_span
        ldx     HB_AX
        bcc     hb_no
.endif
        sta     HB_NX,x
.ifdef VELOZ
        lda     HB_STX,x
        rts
@aft:   eor     #$FF                    ; the span starts inside the window or after it (C clear)
        adc     #1
        cmp     #ET_W
        bcs     @hid
        sta     HB_STX,x                ; its place in the window
        lda     #0
.else
        lda     zhl+1
.endif
        sta     HB_SKX,x
.ifdef VELOZ
        lda     HB_STX,x
        eor     #$FF
        sec
        adc     #ET_W                   ; the window's rest
        cmp     zde+1
        bcc     @all
        lda     zde+1                   ; (C set) the span is shorter
        sta     HB_NX,x
        lda     HB_STX,x
        rts
@all:   sta     HB_NX,x
        lda     HB_STX,x
        sec
        rts
@hid:   cpx     #0                      ; (N/Z from the axis, as the LDX of before; C clear)
        clc
.else
        lda     zhl
        sta     HB_STX,x
.endif
hb_no:  rts

; the record at HB_R (X = its byte 0): both spans clipped (util_clip_span: 3549 / 354D's results); a visible
; record is kept during a miss's scan and drawn (the Z80's operands, then the cells).
hb_draw:
        txa
        and     #8
        bne     @b5
        ldy     #3                      ; 4 bytes: byte 3 = (columns - 1) << 4 | rows - 1
        lda     (HB_R),y
        and     #$0F
        sta     HB_NY
        lda     (HB_R),y
        lsr
        lsr
        lsr
        lsr
        bpl     @b                      ; (always)
@b5:    ldy     #4                      ; 5 bytes: byte 3 = columns - 1, byte 4 = rows - 1
        lda     (HB_R),y
        sta     HB_NY
        dey
        lda     (HB_R),y
@b:     ldx     #0
        ldy     #1
        jsr     hb_span                 ; the columns (x: byte 1)
        bcc     hb_no
        lda     HB_NY
        inx
        iny
        jsr     hb_span                 ; the rows (y: byte 2)
        bcc     hb_no
        lda     HC_RES+1                ; a miss's scan keeps the record (the first HC_MAX: the scan of a hit
        bne     @op                     ; resumes at the next visible one)
        ldy     HC_N
        cpy     #HC_MAX
        bcs     @full
        lda     HB_R
        sta     HC_LO,y
        lda     HB_R+1
        sta     HC_HI,y
        inc     HC_N
        bne     @op                     ; (always)
@full:  lda     HB_R
        sta     HC_RES
        lda     HB_R+1
        sta     HC_RES+1
@op:    ldx     #0
        stx     D64_CHR_HBUF_ROW_STEP_OP
        stx     D64_CHR_HBUF_COL_STEP_OP
        stx     HB_DC
        stx     HB_DR
        ldy     #0
        lda     (HB_R),y
        lsr
        lsr
        lsr
        lsr
        sta     HB_H
        lda     (HB_R),y                ; kinds 1-4: slopes of +1 (1 a column, 4 a row) or -1 (3, 2)
        and     #7
        beq     @fill
        cmp     #5
        bcs     @fill
        lsr                             ; X = 0 for a column slope (odd kind), 1 for a row slope
        bcs     :+
        inx
:       ldy     #1                      ; the step: +1, or -1 for kinds 2 and 3
        cmp     #1
        bne     :+
        ldy     #$FF
:       sty     HB_DC,x
        tya
        asl
        lda     #$0C                    ; the step's Z80 opcode: INC C (0Ch) or DEC C (0Dh)
        adc     #0
        sta     D64_CHR_HBUF_COL_STEP_OP,x
        lsr                             ; (C = 1: it falls)
        lda     HB_SKX,x                ; the height of the first visible cell: h + SK, or h + (SK XOR FFh) + 1
        bcc     :+
        eor     #$FF
:       adc     HB_H
        sta     HB_H
@fill:  ldx     HB_ROW                  ; the cell: [chr_hbuf_ptr] + 24 row + column
        lda     D64_CHR_HBUF_PTR
        clc
        adc     iso_mul24_lo,x
        sta     HB_P
        lda     D64_CHR_HBUF_PTR+1
        adc     iso_mul24_hi,x
        sta     HB_P+1
        lda     HB_STX
        adc     HB_P                    ; (C = 0)
        sta     HB_P
        bcc     :+
        inc     HB_P+1
:       lda     HB_NX
        sta     D64_CHR_HBUF_FLAT_WIDTH_OP
        sta     D64_CHR_HBUF_SLOPE_WIDTH_OP
        ldx     HB_NY
.ifdef VELOZ
        lda     HB_DC                   ; a flat block (kinds 0 and 5-7, most records): every cell the same
        ora     HB_DR                   ; height, the rows without the general loop's work per row
        bne     @row
        ldy     HB_NX
        dey
        bmi     @row                    ; (0: 256 cells, as the Z80's loop, by the general one)
        sty     HB_AX                   ; (free after hb_span) the last column
        lda     HB_H
@frow:  ldy     HB_AX
@fcol:  sta     (HB_P),y
        dey
        bpl     @fcol
        dex
        beq     @fend
        tay
        lda     HB_P
        clc
        adc     #ET_W
        sta     HB_P
        bcc     :+
        inc     HB_P+1
:       tya
        jmp     @frow
@fend:  clc                             ; (C and V clear, as the general loop leaves them)
        clv
        rts
.endif
@row:   lda     HB_H
        ldy     HB_DC
        bne     @slo
        ldy     HB_NX                   ; a flat row, from its last cell
        dey
        bmi     @slo                    ; (0: 256 cells, as the Z80's loop, by the general one)
@flat:  sta     (HB_P),y
        dey
        bpl     @flat
        bmi     @nrow
@slo:   ldy     #0
@col:   sta     (HB_P),y
        clc
        adc     HB_DC
        iny
        cpy     HB_NX
        bne     @col
@nrow:  lda     HB_P
        clc
        adc     #ET_W
        sta     HB_P
        bcc     :+
        inc     HB_P+1
:       lda     HB_H
        clc
        adc     HB_DR
        sta     HB_H
        dex
        bne     @row
        rts

; 354D chr_hbuf_clip_y / 3549 chr_hbuf_clip_x (the Z80 entries: only the checks call them; the fill calls
; util_clip_span through hb_span): the rows / columns of a block in the 24-wide window whose world y / x is the
; operand at 354E / 354A.  In: H = y / x, D = count - 1.  Out: C set = visible, A = E = the visible count, H =
; the first visible one, L = its place in the buffer, D = count.
.ifdef PRUEBA
chr_hbuf_clip_y:
        lda     D64_CHR_HBUF_WIN_Y_OP
        .byte   $2C                     ; (BIT abs: skips the next LDA)
chr_hbuf_clip_x:
        lda     D64_CHR_HBUF_WIN_X_OP
        sta     zhl
        lda     #ET_W
        sta     zde
        inc     zde+1
        jsr     util_clip_span
        sta     zde
        rts
.endif

; 3786 util_clip_span: the span [H, H+D) against the window [L, L+E) (8-bit coordinates).  Visible (C set):
; A = its visible length, H = the offset of the visible part in the span, L = its place in the window.  Hidden
; (C clear): A = the distance; H = 0, L = distance (span after the window) or H, L unchanged (before it).
util_clip_span:
        lda     zhl
        sec
        sbc     zhl+1                   ; window - span
        beq     @al
        bcc     @aft
        cmp     zde+1                   ; the span starts before the window
        bcs     @hid
        sta     zhl+1
        ldx     #0
        stx     zhl
        adc     zde                     ; (C clear)
        cmp     zde+1
        bcs     @part
        lda     zde
        sec
        rts
@part:  lda     zde+1                   ; (C set)
        sbc     zhl+1
        rts
@hid:   clc
        rts
@al:    sta     zhl                     ; aligned (A = 0)
        sta     zhl+1
        lda     zde
        cmp     zde+1
        bcc     @r1
        lda     zde+1
        rts
@aft:   eor     #$FF                    ; the span starts inside the window or after it (C clear)
        adc     #1
        sta     zhl
        ldx     #0
        stx     zhl+1
        cmp     zde
        bcs     @hid
        eor     #$FF
        sec
        adc     zde
        cmp     zde+1
        bcc     @r1
        lda     zde+1
        rts
@r1:    sec
        rts

; 35F8 chr_hbuf_skip_list: zhl past the 4/5-byte records of a height list, to its FFh.  A = FFh, Z set.
chr_hbuf_skip_list:
        ldy     #0
@l:     lda     (zhl),y
        cmp     #$FF
        beq     @r
        and     #8                      ; (C clear) 4 or 5 bytes
        lsr
        lsr
        lsr
        adc     #4
        jsr     util_add_bx_al
        bne     @l                      ; (A = H, never 0)
@r:     rts

; =============================================================================================================
; the start-up
; =============================================================================================================

; 3568 sys_startup_init: run once (sys_startup_done = 0Dh): every pen black, mode 1, the initial-state snapshot,
; the mirror, the C64's merge tables.  Out: zhl = obj_mirror_entry_ptr.
sys_startup_init:
        lda     #$0D
        sta     D64_SYS_STARTUP_DONE
        jsr     vid_palette_black
        lda     #1
        jsr     plat_modo
        jsr     game_snapshot_initial_state
        jsr     game_init_mirror
        jmp     vid_init_stub

; 35C3 game_init_mirror: obj_mirror_height_ptr = the end of the second floor's height list; in room 72h finds
; the block 1F AA 51 and closes the mirror (51h -> 11h); obj_mirror_entry_ptr = zhl = that byte.
game_init_mirror:
        lda     #<D64_CHR_FLOOR2_HEIGHTS
        sta     zhl
        lda     #>D64_CHR_FLOOR2_HEIGHTS
        sta     zhl+1
        jsr     chr_hbuf_skip_list
        lda     zhl
        sta     D64_OBJ_MIRROR_HEIGHT_PTR
        lda     zhl+1
        sta     D64_OBJ_MIRROR_HEIGHT_PTR+1
        lda     #<D64_ISO_ROOM_TABLE
        sta     zhl
        lda     #>D64_ISO_ROOM_TABLE
        sta     zhl+1
        ldx     #$72
        ldy     #0
@rm:    LEE_SALA                 ; the rooms, each led by its length
        jsr     util_add_bx_al
        dex
        bne     @rm
@s:     LEE_SALA                 ; (X = 0: 256 bytes at most; Y the offset in the room)
        iny
        cmp     #$1F
        bne     @ns
        LEE_SALA
        cmp     #$AA
        bne     @ns
        iny
        LEE_SALA
        cmp     #$51
        beq     @f
        dey
@ns:    dex
        bne     @s
        inc     zhl+1                   ; (not found: 256 bytes on, as the Z80)
        rts
@f:     lda     #$11
        PON_SALA
        tya
        jsr     util_add_bx_al
        lda     zhl
        sta     D64_OBJ_MIRROR_ENTRY_PTR
        lda     zhl+1
        sta     D64_OBJ_MIRROR_ENTRY_PTR+1
        rts

; 3607 vid_init_stub: on the C64, the drawing tables (c64/NOTAS_GRAFICOS.md, c64_graficos.py `tablas`): the
; AND masks of the transparent pairs (tiles A: 11, tiles B: 10, sprites: 01) and the ORs (the byte without
; them), the mirrors of the nibbles and of the byte, the nibble swap, and the font's nibble -> byte table.
vid_init_stub:
        ldx     #0
@b:     stx     zt0                     ; b
        txa
        lsr
        sta     zt0+1                   ; b >> 1
        and     zt0                     ; pairs 11: both bits
        jsr     @mask
        sta     G_TABLA_AND_TILE_A,x
        jsr     @or
        sta     G_TABLA_OR_TILE_A,x
        lda     zt0                     ; pairs 10: the high bit only
        eor     #$FF
        and     zt0+1
        jsr     @mask
        sta     G_TABLA_AND_TILE_B,x
        jsr     @or
        sta     G_TABLA_OR_TILE_B,x
        lda     zt0+1                   ; pairs 01: the low bit only
        eor     #$FF
        and     zt0
        jsr     @mask
        sta     G_TABLA_AND_SPR,x
        jsr     @or
        sta     G_TABLA_OR_SPR,x
        lda     zt0                     ; the two pixels of each nibble swapped
        and     #$33
        asl
        asl
        sta     zt0+2
        lda     zt0+1
        lsr
        and     #$33
        ora     zt0+2
        sta     G_TABLA_ESPEJO_NIBBLE,x
        jsr     @swap                   ; the four pixels reversed
        sta     G_TABLA_ESPEJO_BYTE,x
        txa
        jsr     @swap
        sta     G_TABLA_NIBBLES,x
        inx
        bne     @b
        ldx     #15                     ; the font: a set pixel 00 (pen 3), a clear one 11 (pen 2)
@f:     txa
        asl
        asl
        asl
        asl
        sta     zt0
        lda     #0
        ldy     #4
:       asl     zt0
        php
        rol
        plp
        rol
        dey
        bne     :-
        eor     #$FF
        sta     G_TABLA_FUENTE_NIBBLE,x
        dex
        bpl     @f
        rts
@mask:  and     #$55                    ; the low bits of the pairs -> both bits
        sta     zt0+2
        asl
        ora     zt0+2
        rts
@or:    eor     #$FF
        and     zt0
        rts
@swap:  asl                             ; nibble swap
        adc     #$80
        rol
        asl
        adc     #$80
        rol
        rts

; 3A83 vid_palette_black / 3A88 vid_palette_day / 3A8D vid_palette_night: pens 3, 2, 1, 0 and the border :=
; the 5 colours of the palette (C64 colours in the data image).
vid_palette_black:
        ldx     #0
        .byte   $2C
vid_palette_day:
        ldx     #5
        .byte   $2C
vid_palette_night:
        ldx     #10
        stx     zt0
        lda     #3
        sta     zt0+1
@p:     ldy     zt0
        ldx     D64_VID_PALETTE_BLACK,y
        lda     zt0+1
        jsr     plat_tinta
        inc     zt0
        dec     zt0+1
        bpl     @p
        ldy     zt0
        ldx     D64_VID_PALETTE_BLACK,y
        lda     #$10
        jmp     plat_tinta

; =============================================================================================================
; the text: the C64 font (4 bytes a glyph, c64/NOTAS_GRAFICOS.md) drawn into the bitmap
; =============================================================================================================

; 3649 txt_draw_char_inverted / 364D txt_draw_char: draws code A (bit 7 ignored; 20h the blank glyph, below
; 2Dh nothing, C set) at txt_cursor (x in CPC bytes, y in lines), opaque: a set pixel pen 3 and a clear one pen
; 2 (inverted: the other way round); a glyph at an odd x straddles two C64 bytes.  Then txt_cursor x += 2.
; Uses only zt0 and zp0 (it runs from the phrase scroller's interrupt too).
TX_MASK = zt0+2
TX_G    = zt0+4                 ; the glyph (2)
TX_ODD  = zt0+6                 ; bit 7: x odd
TX_ROW  = zt0+1                 ; the glyph row
txt_draw_char_inverted:
        ldx     #$FF
        .byte   $2C
txt_draw_char:
        ldx     #0
        stx     TX_MASK
        and     #$7F
        cmp     #$20
        bne     @font
        lda     #<G_GLIFO_BLANCO
        ldx     #>G_GLIFO_BLANCO
        bne     @g
@font:  sec
        sbc     #$2D
        bcs     :+
        sec                             ; below 2Dh: nothing (C set as the Z80's)
        rts
:       ldx     #>G_FUENTE              ; the glyph: G_FUENTE + 4 (code - 2Dh)
        asl                             ; (C = 0: code - 2Dh < 80h)
        asl
        bcc     :+
        inx
        clc
:       adc     #<G_FUENTE
        bcc     @g
        inx
@g:     sta     TX_G
        stx     TX_G+1
        lda     D64_TXT_CURSOR
        lsr
        ror     TX_ODD
        clc
        adc     #4
        tax                             ; X = the cell column
        lda     D64_TXT_CURSOR+1        ; zp0 = the bitmap byte of line A (0-191) in cell column X:
        tay                             ; $E000 + 320 (A >> 3) + 8 X + (A AND 7)
        and     #7
        sta     zp0
        tya
        lsr
        lsr
        lsr
        tay                             ; the character row
        lsr
        lsr
        sta     zp0+1
        tya
        clc
        adc     zp0+1
        adc     #$E0
        sta     zp0+1
        tya
        and     #3
        lsr
        ror
        ror
        ora     zp0
        sta     zp0
        txa
        asl
        asl
        asl
        bcc     :+
        inc     zp0+1
        clc
:       adc     zp0
        sta     zp0
        bcc     :+
        inc     zp0+1
:       lda     #0
        sta     TX_ROW
@row:   lsr                             ; the glyph row: high nibble of byte r/2 for an even r
        tay
        lda     (TX_G),y
        bcs     :+
        lsr
        lsr
        lsr
        lsr
:       and     #$0F
        tax
        lda     G_TABLA_FUENTE_NIBBLE,x
        eor     TX_MASK
        ldy     #0
        bit     TX_ODD
        bmi     @odd
        sta     (zp0),y
        bpl     @nl                     ; (always: N from the BIT)
@odd:   pha                             ; the left half in the low nibble, the right one in the next cell
        lsr
        lsr
        lsr
        lsr
        sta     zt0
        lda     (zp0),y
        and     #$F0
        ora     zt0
        sta     (zp0),y
        pla
        asl
        asl
        asl
        asl
        sta     zt0
        ldy     #8
        lda     (zp0),y
        and     #$0F
        ora     zt0
        sta     (zp0),y
@nl:    inc     zp0                     ; the next pixel line (a cell is 8 consecutive bytes, 8-aligned)
        bne     :+
        inc     zp0+1
:       lda     zp0
        and     #7
        bne     @nr
        lda     zp0                     ; the next character row: + 320 - 8
        clc
        adc     #<(320-8)
        sta     zp0
        lda     zp0+1
        adc     #>(320-8)
        sta     zp0+1
@nr:    inc     TX_ROW
        lda     TX_ROW
        cmp     #8
        bne     @row
        inc     D64_TXT_CURSOR
        inc     D64_TXT_CURSOR
        clc
        rts

; 3770 txt_skip_words: zhl past zbc+1 (B; 0: 256) words of the dictionary (bit 7 ends a word).  B = 0.  (The
; checks only: the phrase scroller skips the words inline, with zp0.)
.ifdef PRUEBA
txt_skip_words:
        ldy     #0
@w:     lda     (zhl),y
        bmi     @e
        iny
        bne     @w
        inc     zhl+1
        bne     @w
@e:     iny
        bne     :+
        inc     zhl+1
:       dec     zbc+1
        bne     @w
        tya
        jmp     util_add_bx_al
.endif

; 368A txt_phrase_tick: the phrase scroller (300 Hz interrupt): every 2Dh-th call while a phrase is active, a
; beep and the next character (the next letter of the word; at its end a trailing blank or the next phrase byte:
; FFh the end, FA-FE punctuation, F9 nn word nn without a blank, else a blank and word n): the strip (lines
; A4h-ABh, CPC bytes 10h-2Fh) scrolls one C64 byte to the left and the character is drawn inverted at its right
; end.  Every Z80 register is kept.  The game's sys_tick makes the test (the counter + 1 = 2Dh) inline and calls
; t_frase; this entry (the Z80's, with its DI) is for the checks only.
; t_frase: the 2Dh-th tick: the counter to 0 and, while a phrase is active, the character.  X and Y kept (the
; C64's interrupt saves neither); the zero page it uses ($14-$1D: the word pointer in zp0, a flag in zt0,
; txt_draw_char's zt0-zt0+6 and zp0) and txt_cursor are saved and restored.
.ifdef PRUEBA
txt_phrase_tick:
        jsr     plat_di
        inc     D64_TXT_SCROLL_TIMER
        lda     D64_TXT_SCROLL_TIMER
        cmp     #$2D
        beq     t_frase
        rts
.endif
t_frase:
        lda     #0
        sta     D64_TXT_SCROLL_TIMER
        lda     D64_TXT_PHRASE_ACTIVE
        bne     @act
        rts
@act:   txa
        pha
        tya
        pha
        ldx     #zp0+1-zt0
:       lda     zt0,x
        pha
        dex
        bpl     :-
        lda     D64_TXT_CURSOR
        pha
        lda     D64_TXT_CURSOR+1
        pha
        ldy     #<D64_SND_SEQ_BEEP      ; 0C90 snd_play_beep: channel C plays the beep
        lda     #>D64_SND_SEQ_BEEP
        ldx     #$30
.ifdef PRUEBA
        jsr     s_empieza               ; snd_start's DI ... EI: the IFF mirror as the Z80 leaves it
.else
        jsr     s_pon                   ; (the text's sound off: the beep's note a rest, cinta_pitido) then the Z80's EI (snd_start's) on the C64 too: the character takes up to
        cli                             ; ~9600 cycles here (nearly 3 ticks), so the ticks that fall due meanwhile
.endif                                  ; come at once (nested: see sys_tick), the music losing none
@next:  lda     D64_TXT_WORD_DONE       ; (0 or 1: the only values written, here and by 4B7C hud_say)
        bne     @wend
        lda     D64_TXT_WORD_PTR        ; the next letter of the word
        sta     zp0
        lda     D64_TXT_WORD_PTR+1
        sta     zp0+1
        ldy     #0
.ifdef C128
        jsr     far_texto               ; (the texts in block 1: plataforma/c128.s)
.else
        lda     (zp0),y
.endif
        bpl     :+
        ldx     #1
        stx     D64_TXT_WORD_DONE
:       and     #7
        sta     D64_SND_VOICE_TONE_A
        sta     D64_SND_VOICE_TONE_B
        eor     #$FF
        clc
        adc     #1
        sta     D64_SND_VOICE_TONE_NEG
.ifdef C128
        jsr     far_texto
.else
        lda     (zp0),y
.endif
        and     #$7F
        inc     D64_TXT_WORD_PTR
        bne     :+
        inc     D64_TXT_WORD_PTR+1
:       jmp     @print
@wend:  lda     D64_TXT_TRAILING_BLANKS ; the word is finished
        beq     @phr
        dec     D64_TXT_TRAILING_BLANKS
        bne     @blank
        lda     #0
        sta     D64_TXT_PHRASE_ACTIVE
        jmp     @rest
@blank: lda     #$20
        jmp     @print
@phr:   sta     D64_TXT_WORD_DONE       ; the next byte of the phrase (A = 0)
        lda     D64_TXT_PHRASE_PTR
        sta     zp0
        lda     D64_TXT_PHRASE_PTR+1
        sta     zp0+1
        ldy     #0
.ifdef C128
        jsr     far_texto
.else
        lda     (zp0),y
.endif
        cmp     #$FF
        bne     :+
        lda     #$11                    ; the end: 16 blanks
        sta     D64_TXT_TRAILING_BLANKS
        lda     #1
        sta     D64_TXT_WORD_DONE
        bne     @wend
:       cmp     #$FA
        bcs     @punct
        ldx     #$20                    ; word n after a blank
        cmp     #$F9
        bcc     :+
.ifdef C128
        iny                             ; F9 nn: word nn, no blank
        jsr     far_texto
        ldx     #0
.else
        ldx     #0                      ; F9 nn: word nn, no blank
        iny
        lda     (zp0),y
.endif
:       iny
        stx     zt0
        tax                             ; X = n
        tya
        clc
        adc     zp0
        sta     D64_TXT_PHRASE_PTR
        lda     zp0+1
        adc     #0
        sta     D64_TXT_PHRASE_PTR+1
        lda     #<D64_TXT_WORDS
        sta     zp0
        lda     #>D64_TXT_WORDS
        sta     zp0+1
        txa
        beq     @wptr
.ifdef C128
        jsr     far_palabras            ; zp0 past n words (bit 7 ends a word): 3770 txt_skip_words
        jmp     @wptr
.endif
        ldy     #0                      ; zp0 past n words (bit 7 ends a word): 3770 txt_skip_words
@w:     lda     (zp0),y
        bmi     @e
        iny
        bne     @w
        inc     zp0+1
        bne     @w
@e:     iny
        bne     :+
        inc     zp0+1
:       dex
        bne     @w
        tya
        clc
        adc     zp0
        sta     zp0
        bcc     @wptr
        inc     zp0+1
@wptr:  lda     zp0
        sta     D64_TXT_WORD_PTR
        lda     zp0+1
        sta     D64_TXT_WORD_PTR+1
        lda     zt0
        bne     @print
        jmp     @next
@punct: sbc     #$FA                    ; (C set) punctuation: a one-letter word of txt_punctuation
        clc
        adc     #<D64_TXT_PUNCTUATION
        sta     D64_TXT_WORD_PTR
        lda     #>D64_TXT_PUNCTUATION
        adc     #0
        sta     D64_TXT_WORD_PTR+1
        inc     D64_TXT_PHRASE_PTR
        bne     :+
        inc     D64_TXT_PHRASE_PTR+1
:       jmp     @next
@print: pha                             ; print A: scroll the strip one C64 byte (2 CPC bytes) left: in each of
        ldx     #0                      ; its 8 lines A4h-ABh (txt_draw_char's bitmap bytes) the bytes of the cell
@sl:    .repeat 8, k                    ; columns 13-27 into 12-26 (X = 8 k, the k-th column)
        lda     $E000 + 320 * (($A4 + k) >> 3) + 8 * 13 + (($A4 + k) & 7),x
        sta     $E000 + 320 * (($A4 + k) >> 3) + 8 * 12 + (($A4 + k) & 7),x
        .endrepeat
        txa
        clc
        adc     #8
        tax
        cpx     #8 * 15
        bne     @sl
        lda     #<D64_TXT_STRIP_CURSOR
        sta     D64_TXT_CURSOR
        lda     #>D64_TXT_STRIP_CURSOR
        sta     D64_TXT_CURSOR+1
        pla
        ldx     #0
        cmp     #$20
        beq     :+
        ldx     #6
:       stx     D64_SND_VOICE_LEVEL
        jsr     txt_draw_char_inverted
@rest:  pla
        sta     D64_TXT_CURSOR+1
        pla
        sta     D64_TXT_CURSOR
        ldx     #0
:       pla
        sta     zt0,x
        inx
        cpx     #zp0+2-zt0
        bne     :-
        pla
        tay
        pla
        tax
        rts
