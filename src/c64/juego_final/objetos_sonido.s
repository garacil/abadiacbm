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

; abadia64ks, 6502 code of the game: group objetos_sonido (Z80 0983-128E; C reference juego/f_objetos_sonido.c).
; The doors and objects of the room shown (their sprites, the door leaves in the height buffer, opening and
; closing), the projection of a door or object, the AY sound sequencer of the 300 Hz interrupt, its triggers
; and the AY write.  One routine per Z80 function, entered with the Z80 function's registers (c64/CODIGO6502.md);
; the sound's internal entries take the channel in X (0, 18h, 30h from channel A) instead of IX.
        .include "zp.inc"
        .include "mapa.inc"

        .export obj_redraw_one_object, obj_place_objects_in_room, obj_place_doors_in_room
        .export obj_for_each_visible, obj_update_doors, obj_object_sprite_update, obj_door_sprite_update
        .export obj_door_mark_cells, obj_door_cells, spr_project_entity, obj_door_flip_graphics
        .export obj_door_camera_adjust, obj_door_adjust_grid_pos, obj_door_check_open_close
        .export chr_path_reset_alternatives
        .export snd_play_mirror_open, snd_play_footstep, snd_play_music_if_idle, snd_play_hour_bells
        .export snd_play_tercia_bells, snd_play_door_close, snd_play_door_open, snd_play_beep
        .export snd_play_object_taken, snd_play_severino, snd_play_object_dropped
        .export snd_cmd_jump, snd_cmd_start_b, snd_cmd_start_c
        .export snd_cmd_tone_env, snd_cmd_vol_env, snd_cmd_nothing, snd_psg_write, snd_silence_all
        ; the 300 Hz interrupt's sound for sys_tick (personajes), which makes snd_interrupt's test inline; the
        ; start of a sequence without (s_pon) and with (s_empieza) snd_start's DI / EI, for the phrase scroller's beep
        .export s_interrupcion, s_estado_a, s_estado_b, s_estado_c, s_pon, s_empieza
.ifdef PRUEBA
        ; the Z80 entries nothing in the 6502 game calls (it uses the X entries, the inline tests and the indexed
        ; reads): kept for the checks only (construye.sh's checked build), left out of the C64's
        .export obj_door_unpermitted_near, util_read_indirect_pair, snd_start_if_idle, snd_start, snd_interrupt
        .export snd_channel_output, snd_channel_tick, snd_tone_env_next, snd_vol_env_step, snd_vol_env_next
        .export snd_add_hl_a, snd_shift_right
.endif

        .import plat_psg, plat_psg_tono, plat_di, plat_ei
.ifdef JUEGO
        .import plat_irq_sonido         ; the sound's test in plat_irq: JSR ($20) while a channel plays, BIT ($2C) else
.endif
.ifndef PRUEBA
        .import psg_paso
.endif
        .import chr_project                     ; 2632 (personajes): returns past its caller when visible
        .import spr_save_old_rect, spr_flip_graphics_h, iso_grid_cell_of

; ---- the group's own zero page ($AA-$B5) ----
; the sound interrupt's (nothing else touches them: the interrupt may come at any time)
s_ch    = $AA                           ; the channel being processed (0, 18h, 30h)
s_gx    = $C5                           ; s_interrupcion's caller's X and Y ($C5-$C6: no other instruction uses them)
s_gy    = $C6
s_st    = $AB                           ; its state, while its AY registers are written
s_nota  = $AC                           ; the note byte of the sequence
s_ptr   = $AD                           ; word: the envelope or the sequence; the period being shifted
s_vec   = $AF                           ; word: the handler of a sequence command (JMP (s_vec))
; the main code's
o_guarda = $B1                          ; 2 bytes: the door's orientation and flags before a change
o_spr   = $B3                           ; word: the sprite of the record being processed (the loops' IX)

o_spr_puertas = D64_SPR_TABLE + 6 * $14 ; the door sprites (D64_SPR_DOORS)

.segment "CODE"

; ================================================================================ doors and objects

; 0983 obj_redraw_one_object: one object only: [D64_OBJ_FOR_EACH_PATCH] = C9h (RET) so that
; obj_for_each_visible stops after this entry, the object callback, the patch back to 00h (NOP).
; In: IX = spr, IY = obj.  Out: A = 0, ZF set, CF clear.
.proc obj_redraw_one_object
        lda     #$C9
        sta     D64_OBJ_FOR_EACH_PATCH
        lda     #<obj_object_sprite_update
        sta     zhl
        lda     #>obj_object_sprite_update
        sta     zhl+1
        jsr     obj_for_each_visible
        lda     #0
        sta     D64_OBJ_FOR_EACH_PATCH
        clc
        rts
.endproc

; 0993 obj_place_objects_in_room, 09A0 obj_place_doors_in_room: obj_for_each_visible with HL, IX, IY = the
; callback, the first sprite and the first record of the objects or of the doors (o_lugares).
.proc obj_place_objects_in_room
        ldx     #5
        .byte   $2C                     ; BIT abs: skips the LDX #11
.endproc
.proc obj_place_doors_in_room
        ldx     #11
        ldy     #5
:       lda     o_lugares,x             ; HL, IX, IY are contiguous ($06-$0B)
        sta     zhl,y
        dex
        dey
        bpl     :-
.endproc                                ; falls into obj_for_each_visible

; 09AB obj_for_each_visible: [D64_OBJ_ENTITY_CALLBACK] = HL (a 6502 routine); for each 5-byte record from IY
; to its FFh: spr_project_entity; visible: the callback (IY rec, IX spr, HL screen, C depth); the sprite's old
; position = its new one ([spr+3,4] = [spr+1,2]); IY += 5, IX += 14h; [D64_OBJ_FOR_EACH_PATCH] = C9h stops
; after one entry.  In: HL, IX, IY.  Out: -
.proc obj_for_each_visible
        lda     zhl
        sta     D64_OBJ_ENTITY_CALLBACK
        lda     zhl+1
        sta     D64_OBJ_ENTITY_CALLBACK+1
        lda     zix
        sta     o_spr
        lda     zix+1
        sta     o_spr+1
bucle:  ldy     #0                      ; (IX = o_spr: o_siguiente ends in o_spr_ix)
        lda     (ziy),y
        cmp     #$FF
        beq     fin
        jsr     spr_project_entity
        bcs     oculto
        jsr     llama                   ; CALL NC,(09BAh) between PUSH IX and POP IX
        jsr     o_spr_ix
oculto: ldy     #1
        lda     (zix),y
        ldy     #3
        sta     (zix),y
        ldy     #2
        lda     (zix),y
        ldy     #4
        sta     (zix),y
        jsr     o_siguiente
        lda     D64_OBJ_FOR_EACH_PATCH
        cmp     #$C9
        bne     bucle
fin:    rts
llama:  jmp     (D64_OBJ_ENTITY_CALLBACK)
.endproc

o_lugares:
        .word   obj_object_sprite_update, D64_OBJ_SPRITES, D64_OBJ_OBJECTS
        .word   obj_door_sprite_update, o_spr_puertas, D64_OBJ_DOORS

; 09D7 obj_update_doors: main-loop step.  [D64_OBJ_DOOR_FLIP_WANTED] = 0; for each door (D64_OBJ_DOORS, its
; sprite from D64_SPR_DOORS): [D64_OBJ_DOOR_MOVED] = 0, obj_door_check_open_close, visible ->
; obj_door_sprite_update; when the room is not being redrawn ([D64_ISO_ROOM_CHANGED] = 0) and the sprite is
; active (not FEh) and to be redrawn (bit 7): the door-open sound if the door is open, else the door-close one.
.proc obj_update_doors
        lda     #<o_spr_puertas
        sta     o_spr
        lda     #>o_spr_puertas
        sta     o_spr+1
        lda     #<D64_OBJ_DOORS
        sta     ziy
        lda     #>D64_OBJ_DOORS
        sta     ziy+1
        lda     #0
        sta     D64_OBJ_DOOR_FLIP_WANTED
        jsr     o_spr_ix
bucle:  ldy     #0                      ; (IX = o_spr: o_siguiente ends in o_spr_ix)
        lda     (ziy),y
        cmp     #$FF
        beq     fin
        sty     D64_OBJ_DOOR_MOVED
        jsr     obj_door_check_open_close
        jsr     o_spr_ix                ; (PUSH IX / POP IX)
        jsr     spr_project_entity
        bcs     oculta
        jsr     obj_door_sprite_update
        jsr     o_spr_ix
oculta: lda     D64_ISO_ROOM_CHANGED
        bne     sigue
        ldy     #0
        lda     (zix),y
        cmp     #$FE
        beq     sigue
        tax
        bpl     sigue
        ldy     #1                      ; the triggers keep IX and IY
        lda     (ziy),y
        and     #$40
        beq     cierra
        jsr     snd_play_door_open
        jmp     sigue
cierra: jsr     snd_play_door_close
sigue:  jsr     o_siguiente
        jmp     bucle
fin:    rts
.endproc

; IY += 5, o_spr += 14h (the next record and sprite); IX = o_spr
.proc o_siguiente
        lda     ziy
        clc
        adc     #5
        sta     ziy
        bcc     :+
        inc     ziy+1
        clc
:       lda     o_spr
        adc     #$14
        sta     o_spr
        bcc     o_spr_ix
        inc     o_spr+1
.endproc
; IX = o_spr
.proc o_spr_ix
        lda     o_spr
        sta     zix
        lda     o_spr+1
        sta     zix+1
        rts
.endproc

; 0A2B obj_object_sprite_update: the callback for a visible object: a carried one (bit 7 of [rec]) is left
; alone; else [spr] = depth | 80h, [spr+2] = line - 8, [spr+1] = byte - 2.
; In: IY = rec, IX = spr, HL = screen (H line, L byte), C = depth.  Out: -
.proc obj_object_sprite_update
        ldy     #0
        lda     (ziy),y
        bmi     fin
        lda     zbc
        ora     #$80
        sta     (zix),y
        lda     zhl+1
        sec
        sbc     #8
        ldy     #2
        sta     (zix),y
        lda     zhl
        sec
        sbc     #2
        dey
        sta     (zix),y
fin:    rts
.endproc

; 0A42 obj_door_sprite_update: the callback for a visible door.  spr_save_old_rect; BC = the screen offsets of
; obj_door_camera_adjust (which also turns [spr+12h,13h]); e = D64_OBJ_DOOR_ORIENT_TABLE + 8 ((orientation -
; camera) & 3): [spr+1] = e0 + byte + C, [spr+2] = e1 + line + B, [spr] = (e2 + depth) | [D64_OBJ_ROOM_REDRAW] |
; [D64_OBJ_DOOR_MOVED], [D64_OBJ_DOOR_FLIP_WANTED] |= e3, obj_door_adjust_grid_pos(e + 3), the graphic [spr+7,8] =
; the door leaf; falls into obj_door_mark_cells with A = 0Fh (the leaf is impassable).
; In: IY = rec, IX = spr, HL = screen, C = depth.  Out: - (IX: the leaf's last cell).
        .assert >D64_OBJ_DOOR_ORIENT_TABLE = >(D64_OBJ_DOOR_ORIENT_TABLE + 31), error, "a page crossed"
.proc obj_door_sprite_update
        lda     zhl                     ; EX DE,HL: DE = the screen position
        sta     zde
        lda     zhl+1
        sta     zde+1
        jsr     spr_save_old_rect
        lda     zbc                     ; PUSH BC: the depth
        pha
        jsr     obj_door_camera_adjust
        ldy     #0
        lda     (ziy),y
        sec
        sbc     D64_ISO_CAMERA_ORIENT   ; iso_orient_relative
        and     #3
        asl
        asl
        asl
        tax
        lda     D64_OBJ_DOOR_ORIENT_TABLE,x
        clc
        adc     zde
        clc
        adc     zbc
        ldy     #1
        sta     (zix),y
        lda     D64_OBJ_DOOR_ORIENT_TABLE+1,x
        clc
        adc     zde+1
        clc
        adc     zbc+1
        iny
        sta     (zix),y
        pla                             ; POP BC: the depth
        clc
        adc     D64_OBJ_DOOR_ORIENT_TABLE+2,x
        ora     D64_OBJ_ROOM_REDRAW
        ora     D64_OBJ_DOOR_MOVED
        ldy     #0
        sta     (zix),y
        lda     D64_OBJ_DOOR_FLIP_WANTED
        ora     D64_OBJ_DOOR_ORIENT_TABLE+3,x
        sta     D64_OBJ_DOOR_FLIP_WANTED
        txa
        clc
        adc     #<(D64_OBJ_DOOR_ORIENT_TABLE+3)
        sta     zhl
        lda     #>(D64_OBJ_DOOR_ORIENT_TABLE+3)
        sta     zhl+1
        jsr     obj_door_adjust_grid_pos
        ldy     #7
        lda     #<G_PUERTA
        sta     (zix),y
        iny
        lda     #>G_PUERTA
        sta     (zix),y
        lda     #$0F
.endproc                                ; falls into obj_door_mark_cells

; 0A89 obj_door_mark_cells: when the door lies in the current height buffer (obj_door_cells), A goes into the
; three cells of its leaf: cell, cell + step, cell + 2 step.  In: A = value, IY = door, IX = cell (kept when
; outside).  Out: CF set when outside; marked: IX = the third cell, A = the value.
.proc obj_door_mark_cells
        jsr     obj_door_cells
        bcs     fin
        lda     za2                     ; EX AF,AF': the value
        ldy     #0
        sta     (zix),y
        jsr     o_ix_mas_bc
        lda     za2
        sta     (zix),y
        jsr     o_ix_mas_bc
        lda     za2
        sta     (zix),y
fin:    rts
.endproc

; 0A9C obj_door_cells: BC = the step along the door leaf (D64_OBJ_DOOR_CELL_STEPS[[door] & 3]: +1, -24, -1,
; +24); iso_grid_cell_of(door): CF set when the door is not in the current height buffer (IX kept), else IX =
; the first cell of its leaf.  The caller's A is kept in A' (za2: EX AF,AF').
; In: A, IY = door, IX.  Out: CF, IX, BC, A as iso_grid_cell_of leaves it.
.proc obj_door_cells
        sta     za2
        jsr     iso_grid_cell_of
        php
        pha
        ldy     #0
        lda     (ziy),y
        and     #3
        asl
        tay
        lda     D64_OBJ_DOOR_CELL_STEPS,y
        sta     zbc
        lda     D64_OBJ_DOOR_CELL_STEPS+1,y
        sta     zbc+1
        pla
        plp
        rts
.endproc

; 0ABC spr_project_entity: the screen position of door or object IY with chr_project cut short
; ([D64_CHR_PROJECT_TEST] = C9h, RET, meanwhile).  chr_project returns past its caller (to the instruction
; after JSR inner) when visible, with A = depth, HL = screen (H line, L byte); it returns to inner when not.
; In: IY = rec, IX = spr.  Out: A = 0, ZF set; CF clear visible (HL, C = depth), set not visible ([spr] = FEh).
.proc spr_project_entity
        lda     #$C9
        sta     D64_CHR_PROJECT_TEST
        jsr     inner
        sta     zbc                     ; visible: C = depth
        lda     #0
        sta     D64_CHR_PROJECT_TEST
        clc
        rts
inner:  jsr     chr_project             ; 0ACA spr_project_entity_inner
        pla                             ; not visible: POP DE (the return into spr_project_entity)
        pla
        lda     #$FE
        ldy     #0
        sta     (zix),y
        tya
        sta     D64_CHR_PROJECT_TEST
        sec
        rts
.endproc

; 0AD6 obj_door_flip_graphics: main-loop step: if the visible doors need another mirror state
; ([D64_OBJ_DOOR_FLIP_WANTED]) than the door leaf's ([D64_OBJ_DOOR_GFX_FLIPPED]), the state = it and the leaf
; (6 CPC bytes x 28h lines, under the I/O) is mirrored by spr_flip_graphics_h (BC = 2806h, HL = the leaf).
.proc obj_door_flip_graphics
        lda     D64_OBJ_DOOR_FLIP_WANTED
        cmp     D64_OBJ_DOOR_GFX_FLIPPED
        beq     fin
        sta     D64_OBJ_DOOR_GFX_FLIPPED
        lda     #$06
        sta     zbc
        lda     #$28
        sta     zbc+1
        lda     #<G_PUERTA
        sta     zhl
        lda     #>G_PUERTA
        sta     zhl+1
        lda     #MEM_RAM                    ; the I/O off: the leaf is at $Dxxx
        sta     MEMCFG
        lda     D64_OBJ_DOOR_GFX_FLIPPED
        jsr     spr_flip_graphics_h
        lda     #MEM_IO
        sta     MEMCFG
fin:    rts
.endproc

; 0AEC obj_door_camera_adjust: e = D64_OBJ_DOOR_CAMERA_OFFSETS + 4 ((3 - camera) & 3): BC = the screen offsets
; (C = e0, B = e1); falls into obj_door_adjust_grid_pos with HL = e + 1 ([spr+12h] += e2, [spr+13h] += e3).
; In: IX = spr.  Out: BC, HL = e + 3, A = [spr+13h].
        .assert >D64_OBJ_DOOR_CAMERA_OFFSETS = >(D64_OBJ_DOOR_CAMERA_OFFSETS + 15), error, "a page crossed"
.proc obj_door_camera_adjust
        lda     #3
        sec
        sbc     D64_ISO_CAMERA_ORIENT   ; iso_orient_relative(3)
        and     #3
        asl
        asl
        adc     #<D64_OBJ_DOOR_CAMERA_OFFSETS   ; (C clear: A < 10h after the shifts)
        sta     zhl
        lda     #>D64_OBJ_DOOR_CAMERA_OFFSETS
        sta     zhl+1
        ldy     #0
        lda     (zhl),y
        sta     zbc
        iny
        lda     (zhl),y
        sta     zbc+1
        inc     zhl
.endproc                                ; falls into obj_door_adjust_grid_pos

; 0AFC obj_door_adjust_grid_pos: [spr+12h] += [p+1], [spr+13h] += [p+2] (the rotated grid position of a door
; sprite).  In: HL = p, IX = spr.  Out: HL = p + 2, A = [spr+13h].
.proc obj_door_adjust_grid_pos
        ldy     #1
        lda     (zhl),y
        ldy     #$12
        clc
        adc     (zix),y
        sta     (zix),y
        ldy     #2
        lda     (zhl),y
        ldy     #$13
        clc
        adc     (zix),y
        sta     (zix),y
        tax
        lda     zhl
        clc
        adc     #2
        sta     zhl
        bcc     :+
        inc     zhl+1
:       txa
        rts
.endproc

; 0B1D obj_door_check_open_close: opens or closes door IY (sprite IX).  Fixed doors (bit 7 of [door+1]) are left
; alone.  C = [door+1] & 1Fh & ([D64_OBJ_DOOR_CHECK_MASK] | 10h); E, D = x - 2, y - 2.  If Guillermo or Adso
; lacks the bit (the other's mask ORed in) and stands near (obj_door_unpermitted_near), the door closes; else a
; permission entry with the bit standing at x-1..x+2, y-1..y+2 opens it; none closes it.  The change: the old
; leaf's cells get the door's height (obj_door_mark_cells with [door+4]), bit 6 set or cleared,
; [D64_OBJ_DOOR_MOVED] = 80h, the orientation -1 or +1 (opening with bit 5 set -1, closing with bit 5 clear
; -1); if the third cell of the new leaf holds a character ([cell] & F0h) the door bytes are restored,
; [D64_OBJ_DOOR_MOVED] = 0 and the leaf is marked again.  The Z80 keeps the door bytes in B', C' (EXX): o_guarda.
; The permission table (D64_OBJ_DOOR_PERMISSIONS: mask, word -> the character's x, y; FFh) is read indexed by X
; (o_no_permitido, o_cerca) instead of through HL and util_read_indirect_pair as the Z80 does: the same tests,
; faster; HL and B are not left as the Z80 leaves them (no caller reads them).
; In: IY = door, IX = spr.  Out: - (IX: the caller keeps it).
.proc obj_door_check_open_close
        ldy     #1
        lda     (ziy),y
        bpl     :+
        rts                             ; a fixed door
:       and     #$1F
        sta     zbc
        iny
        lda     (ziy),y
        sec
        sbc     #2
        sta     zde                     ; E = x - 2
        iny
        lda     (ziy),y
        sec
        sbc     #2
        sta     zde+1                   ; D = y - 2
        lda     D64_OBJ_DOOR_CHECK_MASK
        ora     #$10
        and     zbc
        sta     zbc                     ; C = the door's bit
        ldx     #0                      ; Guillermo, with Adso's mask
        lda     D64_OBJ_DOOR_PERMISSIONS_ADSO
        jsr     o_no_permitido
        bcc     cierra
        ldx     #3                      ; Adso, with Guillermo's mask
        lda     D64_OBJ_DOOR_PERMISSIONS
        jsr     o_no_permitido
        bcc     cierra
        inc     zde                     ; x - 1, y - 1
        inc     zde+1
        ldx     #0
bucle:  lda     D64_OBJ_DOOR_PERMISSIONS,x
        cmp     #$FF
        beq     cierra                  ; nobody allowed is near
        and     zbc
        beq     sigue
        lda     #4
        jsr     o_cerca
        bcc     abre
sigue:  inx
        inx
        inx
        bne     bucle
abre:   ldy     #1                      ; 0B6E: open it if it is closed
        lda     (ziy),y
        and     #$40
        bne     fin
        jsr     antigua
        ldy     #1
        lda     (ziy),y
        ora     #$40
        sta     (ziy),y
        and     #$20                    ; bit 5 set: -1
        bpl     gira
cierra: ldy     #1                      ; 0BB6: close it if it is open
        lda     (ziy),y
        and     #$40
        beq     fin
        jsr     antigua
        ldy     #1
        lda     (ziy),y
        and     #$BF
        sta     (ziy),y
        and     #$20
        eor     #$20                    ; bit 5 clear: -1
gira:   cmp     #1                      ; C set (A = 20h): -1, else +1
        ldy     #0
        lda     (ziy),y
        bcc     :+
        sbc     #1
        .byte   $2C                     ; BIT abs: skips the ADC #1
:       adc     #1
        sta     (ziy),y
        jsr     obj_door_cells          ; 0B98: the new leaf; its third cell
        jsr     o_ix_mas_bc
        jsr     o_ix_mas_bc
        ldy     #0
        lda     (zix),y
        and     #$F0
        beq     fin
        lda     o_guarda                ; a character there: undone
        sta     (ziy),y
        iny
        lda     o_guarda+1
        sta     (ziy),y
        lda     #0
        sta     D64_OBJ_DOOR_MOVED
        ldy     #4
        lda     (ziy),y
        jmp     obj_door_mark_cells
fin:    rts
; the door bytes kept, [D64_OBJ_DOOR_MOVED] = 80h, the old leaf gets the door's height
antigua:
        ldy     #0
        lda     (ziy),y
        sta     o_guarda
        iny
        lda     (ziy),y
        sta     o_guarda+1
        lda     #$80
        sta     D64_OBJ_DOOR_MOVED
        ldy     #4
        lda     (ziy),y
        jmp     obj_door_mark_cells
.endproc

; 0BDC obj_door_unpermitted_near: (A | [HL]) & C -> CF clear (one of the two may pass); else (x, y) = the
; position the word at HL + 1 points to: CF set when x - E < 6 and y - D < 6 (8 bit).  HL is an entry of
; D64_OBJ_DOOR_PERMISSIONS (its only callers, 0B3E and 0B49, pass Guillermo's and Adso's).
; In: A = mask, HL = entry, C = bit, E, D.  Out: CF (HL kept: no caller reads it).  (The checks only: the 6502
; obj_door_check_open_close calls o_no_permitido.)
.ifdef PRUEBA
.proc obj_door_unpermitted_near
        tay
        lda     zhl
        sec
        sbc     #<D64_OBJ_DOOR_PERMISSIONS
        tax
        tya
        jsr     o_no_permitido
        bcc     si
        clc
        rts
si:     sec
        rts
.endproc
.endif

; C clear when entry X of D64_OBJ_DOOR_PERMISSIONS lacks the door's bit C (with A, the other's mask, ORed in) and
; its character stands within 6 of E, D; X kept.
o_no_permitido:
        ora     D64_OBJ_DOOR_PERMISSIONS,x
        and     zbc
        bne     o_lejos
        lda     #6
; C clear when the character entry X of D64_OBJ_DOOR_PERMISSIONS points to stands at x - E < A and y - D < A
; (8 bit); X kept.
o_cerca:
        sta     zt0+2
        lda     D64_OBJ_DOOR_PERMISSIONS+1,x
        sta     zt0
        lda     D64_OBJ_DOOR_PERMISSIONS+2,x
        sta     zt0+1
        ldy     #0
        lda     (zt0),y
        sec
        sbc     zde
        cmp     zt0+2
        bcs     o_cerca_fin
        iny
        lda     (zt0),y
        sec
        sbc     zde+1
        cmp     zt0+2
o_cerca_fin:
        rts
o_lejos:
        sec
        rts

; 0BEC util_read_indirect_pair: q = the word at HL, HL += 2; A = [q], B = [q+1].  In: HL.  Out: A, B, HL.  (The
; checks only: obj_door_check_open_close reads the table indexed.)
.ifdef PRUEBA
.proc util_read_indirect_pair
        ldy     #0
        lda     (zhl),y
        sta     zt0
        iny
        lda     (zhl),y
        sta     zt0+1
        lda     (zt0),y
        sta     zbc+1
        lda     zhl
        clc
        adc     #2
        sta     zhl
        bcc     :+
        inc     zhl+1
:       dey
        lda     (zt0),y
        rts
.endproc
.endif

; IX += BC (Y kept)
.proc o_ix_mas_bc
        lda     zix
        clc
        adc     zbc
        sta     zix
        lda     zix+1
        adc     zbc+1
        sta     zix+1
        rts
.endproc

; 0BF8 chr_path_reset_alternatives: [D64_CHR_PATH_ALT_PTR] = D64_CHR_PATH_ALTERNATIVES and FFh at its fourth
; byte (only the first candidate destination is kept).  Out: DE = D64_CHR_PATH_ALTERNATIVES + 3, A = FFh.
.proc chr_path_reset_alternatives
        lda     #<D64_CHR_PATH_ALTERNATIVES
        sta     D64_CHR_PATH_ALT_PTR
        lda     #>D64_CHR_PATH_ALTERNATIVES
        sta     D64_CHR_PATH_ALT_PTR+1
        lda     #<(D64_CHR_PATH_ALTERNATIVES + 3)
        sta     zde
        lda     #>(D64_CHR_PATH_ALTERNATIVES + 3)
        sta     zde+1
        lda     #$FF
        sta     D64_CHR_PATH_ALTERNATIVES + 3
        rts
.endproc

; ================================================================================ the sound

; the channel records (D64_SND_CHANNEL_A/B/C, 18h apart); the field offsets of datos_objetos_sonido.h
CH = D64_SND_CHANNEL_A
        .assert D64_SND_CHANNEL_B = CH + $18, error, "sound channels"
        .assert D64_SND_CHANNEL_C = CH + $30, error, "sound channels"
SND_REG_TONE    = -3
SND_REG_VOLUME  = -2
SND_MIXER_BITS  = -1
SND_SEQ         = $00
SND_LEFT        = $02
SND_PERIOD      = $03
SND_TONE_ENV    = $05
SND_VOLUME      = $07
SND_TONE_STEPS  = $08
SND_TONE_INDEX  = $09
SND_VOL_ENV     = $0A
SND_VOL_INDEX   = $0C
SND_VOL_STEPS   = $0D
SND_STATE       = $0E
SND_TONE_RATE   = $0F
SND_VOL_RATE    = $10
SND_TONE_COUNT  = $11
SND_VOL_COUNT   = $12
SND_TONE_DELTA  = $13
SND_VOL_DELTA   = $14

; ---- the triggers 0C6D-0CA2: LD HL,seq and a JR to the start of channel A, B or C (0CAF, 0CB5, 0CBB, falling
; into snd_start) or to snd_start_if_idle.  Here Y, A = the sequence (low, high), X = the channel, for
; s_empieza; the triggers of one channel whose sequences share their high byte share the tail (an entry is
; LDY #low and a BIT abs that skips the next one's).  IX, IY and HL are kept (the Z80 leaves IX = the channel,
; HL = the sequence: no caller reads them).
.macro ENTRADA nombre, secuencia, alto, saltada
        .assert >secuencia = alto, error, "a sequence in another page"
  .ifnblank saltada                     ; skipped by the BIT before it: BIT $xxA0 must not read the I/O
        .assert <secuencia < $D0 || <secuencia > $DF, error, "a skipped LDY would make the BIT read the I/O"
  .endif
.proc nombre
        ldy     #<secuencia
.endproc
.endmacro
.macro SALTA alto, canal
        lda     #alto
        ldx     #canal
  .if canal = 0
        beq     s_empieza
  .else
        bne     s_empieza
  .endif
.endmacro
SND_P0  = >D64_SND_SEQ_MUSIC            ; the sequences' two pages ($FE and $FF on the C64; the C128: mapa64.py)
SND_P1  = SND_P0 + 1
        ENTRADA snd_play_mirror_open, D64_SND_SEQ_MIRROR_OPEN, SND_P0             ; 0C6D (2DE4)
        SALTA   SND_P0, 0
        ENTRADA snd_play_hour_bells, D64_SND_SEQ_HOUR_BELLS, SND_P1               ; 0C7C
        .byte   $2C
        ENTRADA snd_play_tercia_bells, D64_SND_SEQ_TERCIA_BELLS, SND_P1, 1           ; 0C81
        SALTA   SND_P1, 0
        ENTRADA snd_play_door_close, D64_SND_SEQ_DOOR_CLOSE, SND_P1               ; 0C86
        .byte   $2C
        ENTRADA snd_play_door_open, D64_SND_SEQ_DOOR_OPEN, SND_P1, 1                 ; 0C8B
        .byte   $2C
        ENTRADA snd_play_severino, D64_SND_SEQ_SEVERINO, SND_P1, 1                   ; 0C9A
        .byte   $2C
        ENTRADA snd_play_object_dropped, D64_SND_SEQ_OBJECT_DROPPED, SND_P1, 1       ; 0C9F
        SALTA   SND_P1, $18
        ENTRADA snd_play_object_taken, D64_SND_SEQ_OBJECT_TAKEN, SND_P0           ; 0C95
        SALTA   SND_P0, $18
        ENTRADA snd_play_footstep, D64_SND_SEQ_FOOTSTEP, SND_P0                   ; 0C72
.ifdef PRUEBA
        SALTA   SND_P0, $30
.else
        jmp     s_paso                  ; the C64: not while the music plays (BAJO)
.endif
        ENTRADA snd_play_beep, D64_SND_SEQ_BEEP, SND_P1                           ; 0C90
        SALTA   SND_P1, $30
        ENTRADA snd_play_music_if_idle, D64_SND_SEQ_MUSIC, SND_P0                 ; 0C77
        lda     #SND_P0
        bne     s_si_libre

; 0CA4 snd_start_if_idle: snd_start(channel C, HL) only if channel C is idle (state 0).  In: HL = seq.  (The
; Z80 entry: the checks only.)
.ifdef PRUEBA
.proc snd_start_if_idle
        ldy     zhl
        lda     zhl+1
.endproc
.endif
s_si_libre:
        ldx     CH+$30+SND_STATE
        bne     s_fin
        ldx     #$30
        bne     s_empieza

; 0CBF snd_start: channel IX plays sequence HL: state 5 (playing, starting), 1 tick left; DI ... EI.
; In: IX = ch, HL = seq.  s_empieza: X = the channel, Y, A = the sequence.  Out: - (interrupts enabled).  (The
; Z80 entry: the checks only.)
.ifdef PRUEBA
.proc snd_start
        jsr     s_ix_x
        ldy     zhl
        lda     zhl+1
.endproc
.endif
s_empieza:
        jsr     plat_di
        jsr     s_pon
        jmp     plat_ei
; channel X plays the sequence Y, A (low, high): state 5 (playing, starting), 1 tick left.  Out: A = 1.
s_pon:  sta     CH+SND_SEQ+1,x
        tya
        sta     CH+SND_SEQ,x
.ifndef PRUEBA
        jsr     s_canal_c               ; the C64: what channel C plays (BAJO)
.endif
        lda     #5
        sta     CH+SND_STATE,x
.ifdef JUEGO
        lda     #$20                    ; plat_irq calls s_interrupcion (JSR)
        sta     plat_irq_sonido
.endif
        lda     #1
        sta     CH+SND_LEFT,x
        rts

; X = the channel of IX (IX - D64_SND_CHANNEL_A: the routines' entries from the Z80's interface, the checks only)
.ifdef PRUEBA
s_ix_x: lda     zix
        sec
        sbc     #<CH
        tax
.endif
s_fin:  rts

; 0CD0 snd_interrupt: the sound of the interrupt (300 times a second).  Nothing unless a channel plays; the
; tempo counter (6..0, reloaded from [D64_SND_TEMPO_RELOAD]); the mixer from 3Fh (all off); the sequences of
; the three channels (snd_channel_tick), then what they send (snd_channel_output); the mixer to the AY
; (register 7) when it changed.  A, the flags and the register pairs are kept (BC, DE, IX only while a
; sequence command runs, on the stack); the rest of its zero page is its own (s_*).  DI ... EI.  The game's
; sys_tick makes the test inline (s_estado_*) and calls the work, s_interrupcion; this entry (the Z80's, with
; its DI / EI and the kept A and flags) is for the checks only.
s_estado_a = CH+SND_STATE               ; the channels' states (bit 0: playing)
s_estado_b = CH+$18+SND_STATE
s_estado_c = CH+$30+SND_STATE
.ifdef PRUEBA
.proc snd_interrupt
        php
        pha
        jsr     plat_di
        lda     s_estado_a
        ora     s_estado_b
        ora     s_estado_c
        lsr
        bcc     :+
        jsr     s_interrupcion
:       jsr     plat_ei
        pla
        plp
        rts
.endproc
.endif

; snd_interrupt's work when a channel plays (sys_tick's call): X and Y kept (the C64's interrupt saves neither),
; A and the flags not; no DI / EI (the interrupt's).
.proc s_interrupcion
        stx     s_gx                    ; (never nested: the interrupt's I flag is set while it runs)
        sty     s_gy
        ldx     D64_SND_TEMPO           ; the tempo - 1; from 0: the reload
        bne     :+
        ldx     D64_SND_TEMPO_RELOAD
        inx
:       dex
        stx     D64_SND_TEMPO
        lda     #$3F
        sta     D64_SND_MIXER
        lda     s_estado_a              ; A or B playing (C on the stack)?  If not, only channel C ticks and sends
        ora     s_estado_b              ; (C's commands can start B, not A: B is then starting, which sends nothing)
        lsr
        php
        bcc     @c
        .repeat 2, k                    ; the sequences (the idle channels skipped here)
        lda     CH+k*$18+SND_STATE
        lsr
        bcc     :+
        rol
        ldx     #k*$18
        jsr     s_tick_activo
:
        .endrepeat
@c:     lda     s_estado_c
        lsr
        bcc     :+
        rol
        ldx     #$30
        jsr     s_tick_activo
:       plp
        bcc     @sc
        .repeat 2, k                    ; what they send (playing, not starting nor silent)
        lda     CH+k*$18+SND_STATE
        and     #$85
        cmp     #$01
        bne     :+
        ldx     #k*$18
        jsr     s_salida_activo
:
        .endrepeat
@sc:    lda     s_estado_c
        and     #$85
        cmp     #$01
        bne     :+
        ldx     #$30
        jsr     s_salida_activo
:
        lda     D64_SND_MIXER
        cmp     D64_SND_MIXER_SENT
        beq     fin
        sta     D64_SND_MIXER_SENT
        tax
        lda     #7
        jsr     plat_psg
fin:    ldx     s_gx
        ldy     s_gy
        rts
.endproc

; 0D40 snd_channel_output: what the channel sends to the AY.  Nothing unless playing (bit 0) and not starting
; (bit 2) nor silent (bit 7).  Bit 6: the period to its tone registers; bit 5: the volume to its volume
; register, or with an AY envelope (bit 4) the envelope period and shape (11-13) and 10h to its volume
; register; then its mixer bits, tone only (07h & bits) or with noise (bit 1) tone and noise (3Fh & bits, the
; noise period to register 6 when bit 3), toggled into [D64_SND_MIXER].  In: IX = ch (s_salida_activo: X, the
; state tested by the caller).
.ifdef PRUEBA
snd_channel_output:
        jsr     s_ix_x
        lda     CH+SND_STATE,x
        and     #$85
        cmp     #$01
        beq     s_salida_activo
        rts
.endif
s_salida_activo:                        ; X = the channel, playing, not starting nor silent
        stx     s_ch
        lda     CH+SND_STATE,x
        sta     s_st
        bit     s_st
        bvc     @volumen
        ldy     CH+SND_REG_TONE,x       ; bit 6: the period: its fine register (REG_TONE) and the coarse one (+ 1)
        lda     CH+SND_PERIOD,x         ; at once (plat_psg_tono: Y = the fine register, A = fine, X = coarse)
        pha
        lda     CH+SND_PERIOD+1,x
        tax
        pla
        jsr     plat_psg_tono
@volumen:
        lda     #$20
        bit     s_st
        beq     @mezcla
        lda     #$10
        bit     s_st
        bne     @envolvente
        ldy     s_ch
        ldx     CH+SND_VOLUME,y
        lda     CH+SND_REG_VOLUME,y
        jsr     plat_psg
        jmp     @mezcla
@envolvente:
        ldx     D64_SND_ENV_PERIOD_LO
        lda     #11
        jsr     plat_psg
        ldx     D64_SND_ENV_PERIOD_HI
        lda     #12
        jsr     plat_psg
        ldx     D64_SND_ENV_SHAPE
        lda     #13
        jsr     plat_psg
        ldy     s_ch
        lda     CH+SND_REG_VOLUME,y
        ldx     #$10
        jsr     plat_psg
@mezcla:
        lda     #$02
        bit     s_st
        beq     @tono
        lda     #$08
        bit     s_st
        beq     :+
        ldx     D64_SND_NOISE_PERIOD
        lda     #6
        jsr     plat_psg
:       lda     #$3F
        .byte   $2C                     ; BIT abs: skips the LDA #07h
@tono:  lda     #$07
        ldy     s_ch
        and     CH+SND_MIXER_BITS,y
        eor     D64_SND_MIXER
        sta     D64_SND_MIXER
        rts

; 0DBC snd_channel_tick: the sequence of the channel, once an interrupt.  Nothing unless playing (bit 0); the
; state keeps bits 0, 1, 2, 7.  On the tempo tick ([D64_SND_TEMPO] = 0) when the note ends (left - 1 = 0):
; state 1, the sequence commands (D64_SND_COMMANDS) run; FFh ends the sequence (state 0); else a note: byte n,
; its ticks, [the noise period when bit 7 of n: state bits 1, 3], the envelopes restart, volume 0; n & 0Fh =
; 0Fh is a rest (state bit 7), else the period = D64_SND_NOTE_PERIODS[n & 0Fh] >> ((n >> 4) & 7).  Then,
; unless silent (bit 7) or starting (bit 2): snd_vol_env_step, and every tone rate ticks a tone envelope step:
; steps - 1 (at 0 snd_tone_env_next), period += delta (signed), state bit 6.  In: IX = ch (s_tick_activo: X,
; A = the state, its bit 0 tested by the caller).
.ifdef PRUEBA
snd_channel_tick:
        jsr     s_ix_x
        lda     CH+SND_STATE,x
        lsr
        bcs     :+
        rts                             ; not playing
:       rol
.endif
s_tick_activo:                          ; X = the channel, A = its state (playing)
        and     #$87
        sta     CH+SND_STATE,x
        lda     D64_SND_TEMPO
        bne     s_envolventes
        dec     CH+SND_LEFT,x
        beq     s_siguiente
s_envolventes:                          ; 0E67
        lda     CH+SND_STATE,x
        bmi     @fin
        and     #4
        bne     @fin
        dec     CH+SND_VOL_COUNT,x      ; snd_vol_env_step's first test here
        bne     :+
        jsr     s_paso_volumen_0
:       dec     CH+SND_TONE_COUNT,x
        bne     @fin
        dec     CH+SND_TONE_STEPS,x
        bne     :+
        jsr     s_tono_siguiente
:       lda     CH+SND_TONE_RATE,x
        sta     CH+SND_TONE_COUNT,x
        ldy     #0
        lda     CH+SND_TONE_DELTA,x
        bpl     :+
        dey
:       clc
        adc     CH+SND_PERIOD,x
        sta     CH+SND_PERIOD,x
        tya
        adc     CH+SND_PERIOD+1,x
        sta     CH+SND_PERIOD+1,x
        lda     CH+SND_STATE,x
        ora     #$40
        sta     CH+SND_STATE,x
@fin:   rts

; the note ended: the commands at the sequence pointer, then the next note (0DD4-0E64).  The commands' handlers
; take the Z80's registers (BC = the argument, DE = the sequence past it, IX = the channel): the interrupted
; code's BC, DE, HL, IX are kept on the stack meanwhile.
s_siguiente:
        lda     #1
        sta     CH+SND_STATE,x
        stx     s_ch
        ldx     #7
:       lda     zbc,x
        pha
        dex
        bpl     :-
        ldx     s_ch
        txa
        clc
        adc     #<CH
        sta     zix
        lda     #>CH
        adc     #0
        sta     zix+1
        lda     CH+SND_SEQ,x
        sta     zde
        lda     CH+SND_SEQ+1,x
        sta     zde+1
@orden: ldy     #0
        lda     (zde),y
        ldx     #0
:       cmp     D64_SND_COMMANDS,x
        beq     @ejecuta
        inx
        inx
        inx
        cpx     #18
        bne     :-
        sta     s_nota                  ; not a command
        lda     zde
        sta     s_ptr
        lda     zde+1
        sta     s_ptr+1
        ldx     #0
:       pla
        sta     zbc,x
        inx
        cpx     #8
        bne     :-
        ldx     s_ch
        lda     s_nota
        cmp     #$FF
        bne     s_nota_nueva
        lda     #0                      ; the end of the sequence
        sta     CH+SND_STATE,x
.ifdef JUEGO
        lda     s_estado_a              ; no channel plays any more: plat_irq's call idles (BIT abs)
        ora     s_estado_b
        ora     s_estado_c
        lsr     a
        bcs     :+
        lda     #$2C
        sta     plat_irq_sonido
:
.endif
        rts
@ejecuta:
        lda     D64_SND_COMMANDS+1,x
        sta     s_vec
        lda     D64_SND_COMMANDS+2,x
        sta     s_vec+1
        iny
        lda     (zde),y
        sta     zbc
        iny
        lda     (zde),y
        sta     zbc+1
        lda     zde
        clc
        adc     #3
        sta     zde
        bcc     :+
        inc     zde+1
:       jsr     @llama
        jmp     @orden
@llama: jmp     (s_vec)

s_nota_nueva:                           ; 0E06: X = the channel, A = the note byte
        lda     #1
        sta     CH+SND_TONE_COUNT,x
        sta     CH+SND_TONE_STEPS,x
        sta     CH+SND_VOL_COUNT,x
        sta     CH+SND_VOL_STEPS,x
        lsr
        sta     CH+SND_VOL_INDEX,x
        sta     CH+SND_TONE_INDEX,x
        sta     CH+SND_VOLUME,x
        ldy     #1
        lda     (s_ptr),y
        sta     CH+SND_LEFT,x
        iny
        bit     s_nota
        bpl     :+
        lda     (s_ptr),y               ; with noise
        sta     D64_SND_NOISE_PERIOD
        lda     CH+SND_STATE,x
        ora     #$0A
        sta     CH+SND_STATE,x
        iny
:       tya
        clc
        adc     s_ptr
        sta     CH+SND_SEQ,x
        lda     #0
        adc     s_ptr+1
        sta     CH+SND_SEQ+1,x
        lda     s_nota
        and     #$0F
        cmp     #$0F
        bne     @tono
        lda     CH+SND_STATE,x          ; a rest: silent (bit 7 is clear before)
        ora     #$80
        sta     CH+SND_STATE,x
        rts
@tono:  asl
        tay
        lda     D64_SND_NOTE_PERIODS,y
        sta     s_ptr
        lda     D64_SND_NOTE_PERIODS+1,y
        sta     s_ptr+1
        lda     s_nota                  ; >> the octave
        lsr
        lsr
        lsr
        lsr
        and     #7
        beq     :++
        tay
:       lsr     s_ptr+1
        ror     s_ptr
        dey
        bne     :-
:       lda     s_ptr
        sta     CH+SND_PERIOD,x
        lda     s_ptr+1
        sta     CH+SND_PERIOD+1,x
        jmp     s_envolventes

; 0EA1 snd_tone_env_next: the next entry of the channel's tone envelope: e = [TONE_ENV] + [TONE_INDEX]; 7Fh
; holds (steps, rate, count FFh, delta 0); 80h restarts it (index 0); else steps = e0, delta = e1, rate =
; count = e2, index += 3.  In: IX = ch (s_tono_siguiente: X, kept).
.ifdef PRUEBA
snd_tone_env_next:
        jsr     s_ix_x
.endif
s_tono_siguiente:
        lda     CH+SND_TONE_ENV,x
        sta     s_ptr
        lda     CH+SND_TONE_ENV+1,x
        sta     s_ptr+1
@entrada:
        ldy     CH+SND_TONE_INDEX,x
        lda     (s_ptr),y
        cmp     #$7F
        beq     @mantiene
        cmp     #$80
        beq     @reinicia
        sta     CH+SND_TONE_STEPS,x
        iny
        lda     (s_ptr),y
        sta     CH+SND_TONE_DELTA,x
        iny
        lda     (s_ptr),y
        sta     CH+SND_TONE_RATE,x
        sta     CH+SND_TONE_COUNT,x
        iny
        tya
        sta     CH+SND_TONE_INDEX,x
        rts
@mantiene:
        lda     #$FF
        sta     CH+SND_TONE_COUNT,x
        sta     CH+SND_TONE_RATE,x
        sta     CH+SND_TONE_STEPS,x
        lda     #0
        sta     CH+SND_TONE_DELTA,x
        rts
@reinicia:
        lda     #0
        sta     CH+SND_TONE_INDEX,x
        beq     @entrada

; 0EE5 snd_vol_env_step: the channel's volume envelope, once a tick: count - 1, nothing while not 0; then steps
; - 1 (at 0 snd_vol_env_next), count = rate, state bit 5 (volume to send), and unless an AY envelope (bit 4)
; volume = (volume + delta) & 0Fh.  In: IX = ch (s_paso_volumen_0: X, kept, the count
; already 0).
.ifdef PRUEBA
snd_vol_env_step:
        jsr     s_ix_x
        dec     CH+SND_VOL_COUNT,x
        bne     s_pv_fin
.endif
s_paso_volumen_0:                       ; the count reached 0
        dec     CH+SND_VOL_STEPS,x
        bne     :+
        jsr     s_volumen_siguiente
:       lda     CH+SND_VOL_RATE,x
        sta     CH+SND_VOL_COUNT,x
        lda     CH+SND_STATE,x
        ora     #$20
        sta     CH+SND_STATE,x
        and     #$10
        bne     s_pv_fin
        lda     CH+SND_VOLUME,x
        clc
        adc     CH+SND_VOL_DELTA,x
        and     #$0F
        sta     CH+SND_VOLUME,x
s_pv_fin:   rts

; 0F0B snd_vol_env_next: the next entry of the channel's volume envelope: e = [VOL_ENV] + [VOL_INDEX]; 7Fh holds
; (count, rate, steps FFh, delta 0); 80h restarts it; 8xh the AY envelope: shape x, period e1, e2
; (D64_SND_ENV_*), count = e3, steps 1, state bit 4, index += 4; else steps = e0, delta = e1, rate = count =
; e2, index += 3.  In: IX = ch (s_volumen_siguiente: X, kept).
.ifdef PRUEBA
snd_vol_env_next:
        jsr     s_ix_x
.endif
s_volumen_siguiente:
        lda     CH+SND_VOL_ENV,x
        sta     s_ptr
        lda     CH+SND_VOL_ENV+1,x
        sta     s_ptr+1
@entrada:
        ldy     CH+SND_VOL_INDEX,x
        lda     (s_ptr),y
        cmp     #$7F
        bne     :+
        lda     #$FF
        sta     CH+SND_VOL_COUNT,x
        sta     CH+SND_VOL_RATE,x
        sta     CH+SND_VOL_STEPS,x
        lda     #0
        sta     CH+SND_VOL_DELTA,x
        rts
:       cmp     #$80
        bne     :+
        lda     #0
        sta     CH+SND_VOL_INDEX,x
        beq     @entrada
:       bcc     @volumen                ; below 80h
        and     #$0F                    ; 8xh: the AY envelope
        sta     D64_SND_ENV_SHAPE
        iny
        lda     (s_ptr),y
        sta     D64_SND_ENV_PERIOD_LO
        iny
        lda     (s_ptr),y
        sta     D64_SND_ENV_PERIOD_HI
        iny
        lda     (s_ptr),y
        sta     CH+SND_VOL_COUNT,x
        lda     #1
        sta     CH+SND_VOL_STEPS,x
        lda     CH+SND_STATE,x
        ora     #$10
        sta     CH+SND_STATE,x
        bne     @indice                 ; index + 4 (Y = index + 3)
@volumen:
        sta     CH+SND_VOL_STEPS,x
        iny
        lda     (s_ptr),y
        sta     CH+SND_VOL_DELTA,x
        iny
        lda     (s_ptr),y
        sta     CH+SND_VOL_RATE,x
        sta     CH+SND_VOL_COUNT,x
@indice:
        iny
        tya
        sta     CH+SND_VOL_INDEX,x
        rts

; ---- the sequence commands (D64_SND_COMMANDS holds these routines): entered from s_siguiente with BC = the
; argument (the two bytes after the command), DE = the sequence past them, IX = the channel.

; 0F88 snd_cmd_jump (F9): the sequence goes on at the argument.  Out: DE = BC.
.proc snd_cmd_jump
        lda     zbc
        sta     zde
        lda     zbc+1
        sta     zde+1
        rts
.endproc

; 0F8B snd_cmd_start_b (FE), 0F9A snd_cmd_start_c (FD): channel B / C plays sequence BC (state 5, 1 tick left).
; Out: A = 1.
.proc snd_cmd_start_b
        ldx     #$18
        .byte   $2C                     ; BIT abs: skips the LDX #30h
.endproc
.proc snd_cmd_start_c
        ldx     #$30
        ldy     zbc
        lda     zbc+1
        jmp     s_pon
.endproc

; 0FA9 snd_cmd_tone_env (FB), 0FB0 snd_cmd_vol_env (FA): the channel's tone / volume envelope = BC; 0FB7
; snd_cmd_nothing (FC): a lone RET.
.proc snd_cmd_tone_env
        ldy     #SND_TONE_ENV
        .byte   $2C                     ; BIT abs: skips the LDY #0Ah
.endproc
.proc snd_cmd_vol_env
        ldy     #SND_VOL_ENV
        lda     zbc
        sta     (zix),y
        iny
        lda     zbc+1
        sta     (zix),y
.endproc
.proc snd_cmd_nothing
        rts
.endproc

; 0FB8 snd_add_hl_a: HL += A (A a byte).  Out: HL, A = H.  (0FB8 and 0FDC: the checks only; the 6502 sequencer
; does both inline.)
.ifdef PRUEBA
.proc snd_add_hl_a
        clc
        adc     zhl
        sta     zhl
        bcc     :+
        inc     zhl+1
:       lda     zhl+1
        rts
.endproc
.endif

; 0FBE snd_psg_write: AY register A = C (plat_psg).  In: A = register, C = value.
.proc snd_psg_write
        ldx     zbc
        jmp     plat_psg
.endproc

; 0FDC snd_shift_right: HL >>= A (A the octave, 0-7).  Out: HL, A = 0, ZF set.  (The checks only.)
.ifdef PRUEBA
.proc snd_shift_right
        tax
        beq     fin
:       lsr     zhl+1
        ror     zhl
        dex
        bne     :-
fin:    lda     #0
        rts
.endproc
.endif

; 0FE6 snd_silence_all: every channel stops (state 84h: not playing, silent, starting) and the AY mixer = 3Fh
; (all off; [D64_SND_MIXER_SENT] is kept).
.proc snd_silence_all
        lda     #$84
        sta     CH+SND_STATE
        sta     CH+$18+SND_STATE
        sta     CH+$30+SND_STATE
.ifdef JUEGO
        lda     #$2C                    ; plat_irq's call idles (BIT abs); the callers run with the interrupts off
        sta     plat_irq_sonido         ; (20D2h, 2165h)
.endif
        ldx     #$3F
        lda     #7
        jmp     plat_psg
.endproc

; ================================================================================ the C64's footsteps
; The C64 build only: the music keeps channel C.  On the CPC the footstep (Guillermo's,
; at 21DD) takes channel C whatever plays there, so walking cuts the music, which starts again from its beginning
; once Guillermo has stood still for 50 frames (3CEA).  Here a footstep while the music plays is not started, and
; the music ends at its end instead of starting again (its F9 at D64_SND_SEQ_MUSIC + 7Eh jumps back to its start:
; it never ends on its own on the CPC; that byte becomes FFh, the end, until the music starts again); then the
; footsteps come back.  If Guillermo stands still meanwhile, it loops as on the CPC.  The phrases' beep (t_frase)
; still takes channel C as on the CPC.  The SID plays the footstep softer (psg_paso, c64/plataforma/psg.s).
.ifndef PRUEBA
        .assert <D64_SND_SEQ_MUSIC <> <D64_SND_SEQ_FOOTSTEP && <D64_SND_SEQ_MUSIC <> <D64_SND_SEQ_BEEP, error, "channel C's sequences: their low bytes must differ"
        .assert <D64_SND_SEQ_FOOTSTEP <> <D64_SND_SEQ_BEEP && <D64_SND_SEQ_FOOTSTEP <> $F9, error, "channel C's sequences: their low bytes must differ"
S_MUSICA_F9 = D64_SND_SEQ_MUSIC + $7E   ; the music's loop: F9h, D64_SND_SEQ_MUSIC (checked by vice/pasos.py)
.if .defined(CINTA) || .defined(C128) || .defined(DISCO)
; The options menu's footsteps or text's sound off: the loaders write 0Fh over the one note of the footstep's or the
; beep's sequence (FB w, FA w, the note, its ticks, FFh), a rest as long (n & 0Fh = 0Fh, no noise byte).  The sequence
; still takes channel C as when it sounds: walking ends the music at its end, a phrase cuts it, only silent (a JSR
; taken away instead left the music looping for ever).  The loaders' tools check the notes (17h, 54h).
cinta_paso   = D64_SND_SEQ_FOOTSTEP + 6            ; 17h 04h
cinta_pitido = D64_SND_SEQ_BEEP + 6                ; 54h 0Ah
        .export cinta_paso, cinta_pitido
.endif

.segment "BSS"
s_cual: .res 1                          ; the low byte of the sequence channel C last started (only the footstep,
                                        ; the beep and the music start there: no sequence starts it by FDh)

.segment "BAJO"
; snd_play_footstep (Y = <D64_SND_SEQ_FOOTSTEP): the footstep, unless channel C plays the music (then its end ends it)
s_paso: lda     s_cual
        cmp     #<D64_SND_SEQ_MUSIC
        bne     :+
        lda     CH+$30+SND_STATE        ; bit 0: playing (snd_silence_all leaves 84h)
        lsr     a
        bcc     :+
        lda     #$FF
        sta     S_MUSICA_F9
        rts
:       lda     #>D64_SND_SEQ_FOOTSTEP
        ldx     #$30
        jmp     s_empieza

; s_pon (interrupts off), X = the channel, A = the low byte of its sequence; channel C: the music gets its loop
; back; the SID's voicing of the channel (psg_paso, Z = 1 the footstep).  X and Y kept.
s_canal_c:
        cpx     #$30
        bne     s_ret
        sta     s_cual
        cmp     #<D64_SND_SEQ_MUSIC
        bne     :+
        lda     #$F9
        sta     S_MUSICA_F9
:       cmp     #<D64_SND_SEQ_FOOTSTEP  ; (F9h is not it)
        jmp     psg_paso
s_ret:  rts
.endif
