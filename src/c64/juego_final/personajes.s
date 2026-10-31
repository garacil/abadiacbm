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

; abadia64ks, 6502 code of the game: group personajes (Z80 2226-2F57; C reference juego/f_personajes.c,
; data juego/datos_personajes.h).  The characters: the NPC step, the sprite step of a dark room and the light,
; the height-buffer probes, the movement (chr_update, chr_think_or_step, the advances, the turns), the
; animation and the projection to the screen, the command streams of the characters the AI moves, the room
; selection and the height buffer of a room, the 300 Hz tick, the keyboard and the key tests, the mirror, and
; the in-place flips of the characters' and faces' graphics in the C64 sprite format (c64/NOTAS_GRAFICOS.md).
; Every routine keeps the Z80 function's interface (c64/CODIGO6502.md); notes in NOTAS.md.
        .include "zp.inc"
        .include "mapa.inc"

        .export game_run_npc_behaviours, spr_draw_or_darken, spr_place_light, vid_clear_play_area
        .export chr_step_table, util_add_bx_8al, chr_to_hbuf_coords
        .export chr_probe_ahead_flat, chr_probe_ahead, chr_probe_cells
        .export chr_guillermo_behaviour, chr_mark_hbuf, chr_update, chr_think_or_step
        .export chr_try_advance, chr_orientation_parity, chr_try_advance_2x2, chr_apply_step
        .export chr_step_level, chr_step_and_animate, chr_turn, chr_animate, chr_show_frame
        .export chr_select_frame, spr_save_old_rect, spr_mark_leaving, chr_project
        .export chr_load_params, chr_command_bit, chr_ai_follow_commands
        .export iso_select_room, chr_fill_height_buffer, chr_backup_args
.ifndef JUEGO
        .export sys_tick                ; (the game's plat_irq has its body inline: c64/plataforma/interrupcion.s)
.endif
        .export sys_read_keyboard, game_input_and_mirror, game_check_qr_mirror
        .export sys_test_key, sys_key_pressed, sys_key_down, sys_key_bit
        .export obj_init_mirror, obj_close_mirror
        .export spr_flip_adso, spr_flip_malachi, spr_flip_abbot, spr_flip_berengar, spr_flip_severin
        .export spr_flip_guillermo, spr_flip_graphics_h

        ; other groups (a trap in the checked build until they are translated)
        .import ai_update_adso, ai_update_malachi, ai_update_abbot, ai_update_berengar, ai_update_severin
        .import spr_draw_all, vid_fill_play_area, iso_floor_base, iso_orient_relative
        .import iso_grid_cell_of, iso_grid_set_origin, chr_hbuf_fill_room, iso_mul24_lo, iso_mul24_hi
        .import hud_say_now, snd_play_mirror_open
        ; the 300 Hz interrupt's bodies (sys_tick makes their tests inline): the sound's (objetos_sonido, with
        ; the channels' state bytes) and the phrase scroller's (estado_texto)
        .import s_interrupcion, s_estado_a, s_estado_b, s_estado_c, t_frase
        ; reached only through code pointers (the camera rotation [2656], the flip routine [25AE]): imported
        ; so that the pointers relocate to them
        .import iso_rotate_cam0, iso_rotate_cam1, iso_rotate_cam2, iso_rotate_cam3, iso_mirror_draw_callback
        .import plat_di, plat_ei, plat_teclado_fila

; the group's zero page ($C2-$CD)
.ifdef VELOZ
pkl     = $C2                   ; 2: sys_test_key, the key list being walked (sys_key_down: 1, the index)
.else
pkl     = $C2                   ; 2: sys_test_key, the key list being walked
.endif
pkflag  = $C4                   ; 1: sys_key_pressed / sys_key_down, 0 = level test, else consume the press
.ifdef VELOZ
PKLISTS = D64_SYS_KEY_ALIAS_LEFT & $FF00  ; the page of the key alias lists (sys_key_down indexes it)
.endif

; the characters' graphics in the C64 sprite format (block personajes, c64/NOTAS_GRAFICOS.md: ceil(w/2) bytes a
; line); their offsets inside the block are those of data/c64graf/marcos64.tsv
GFX_GUILLERMO_W5 = G_PERSONAJES + 0     ; CPC A300h, 5 x AEh
GFX_GUILLERMO_W4 = G_PERSONAJES + 522   ; CPC A666h, 4 x 21h
GFX_ADSO_W5      = G_PERSONAJES + 588   ; CPC A6EAh, 5 x 5Fh
GFX_ADSO_W4      = G_PERSONAJES + 873   ; CPC A8C5h, 4 x 5Ah
FACE2_OFFSET     = 30                   ; the second face of a monk: 10 lines of 3 bytes further (CPC +32h)
ESPEJO_NIBBLE    = G_TABLA_ESPEJO_NIBBLE ; each nibble's two pixels swapped

        .assert >D64_CHR_STEP_TABLE_1X1 = >D64_CHR_STEP_TABLE_2X2, error, "chr_step_table: one page"
        .assert (D64_SYS_BIT_MASKS & 7) = 0, error, "sys_key_bit: the bit masks 8-aligned"
        .assert >D64_SYS_KEYS_DOWN = >(D64_SYS_KEYS_PENDING + 9), error, "the key bitmaps in one page"
        .assert >D64_CHR_ANIM_GUILLERMO <> $C0 && >(D64_CHR_ANIM_GUILLERMO + 95) <> $C0, error, "C0xxh is the monks' tag"
        .assert (D64_SPR_MONK_FACES & $FF) < $F8, error, "the faces table in one page"
        .assert D64_CHR_PROBE_OUTER = D64_CHR_PROBE_INNER + 2, error, "chr_probe_cells: the strides contiguous"
        .assert >D64_SYS_KEY_ALIAS_LEFT = >(D64_SYS_KEY_ALIAS_012 + 11), error, "the key alias lists in one page"

.ifdef C128
        .import cab_gira_pers, cab_gira_cara
.endif
.segment "CODE"

; ================================================================== the main loop's steps

; 2226 game_run_npc_behaviours: one step of every NPC (Adso, Malachi, the Abbot, Berengar, Severin).
.proc game_run_npc_behaviours
        jsr     ai_update_adso
        jsr     ai_update_malachi
        jsr     ai_update_abbot
        jsr     ai_update_berengar
        jmp     ai_update_severin
.endproc

; 2236 spr_draw_or_darken: lit room: the sprites are drawn (JP 447D); dark room: 223D.
.proc spr_draw_or_darken
        lda     D64_ISO_ROOM_DARK
        bne     personajes_dark
        jmp     spr_draw_all
.endproc

; 223D (inside 2236, also reached from 2274): dark room.  Clears the redraw bit 7 of every active sprite record
; (FE inactive, FF end); then, if Adso's sprite is active and he carries the lamp (bit 7 of [2944]), the light
; is shown (BCh) and the sprites drawn (JP 447D).
.proc personajes_dark
        lda     #<D64_SPR_TABLE
        sta     zp0
        lda     #>D64_SPR_TABLE
        sta     zp0+1
        ldy     #0
loop:   lda     (zp0),y
        cmp     #$FF
        beq     done
        cmp     #$FE
        beq     next
        and     #$7F
        sta     (zp0),y
next:   lda     zp0
        clc
        adc     #$14
        sta     zp0
        bcc     loop
        inc     zp0+1
        bne     loop
done:   lda     D64_SPR_TABLE+$14
        cmp     #$FE
        beq     ret
        bit     D64_GAME_ADSO_LAMP
        bpl     ret
        lda     #$BC
        sta     D64_SPR_LIGHT
        jmp     spr_draw_all
ret:    rts
.endproc

; 2265 spr_place_light: hides the light sprite; lit room: nothing more.  Dark room without Adso's sprite: 223D.
; Else the light on Adso: x = max(0, (x & FC) - 8), y = max(0, (y & F8) - 18h), depth FE FE, and the light
; drawer's operands: [4756] = x & 3, [4782] = 4 - (x & 3), [4738] / [479E] = EFh / 9Fh (swapped when (y & 7) < 4),
; [476D] = 29h (ADD HL,HL) when Adso's graphics are flipped, else 00 (NOP).
.proc spr_place_light
        lda     #$FE
        sta     D64_SPR_LIGHT
        lda     D64_ISO_ROOM_DARK
        bne     :+
        rts
:       lda     D64_SPR_TABLE+$14
        cmp     #$FE
        beq     personajes_dark
        lda     D64_SPR_TABLE+$15
        and     #3
        sta     D64_SPR_LIGHT_DX
        eor     #$FF                    ; 4 - (x & 3)
        sec
        adc     #4
        sta     D64_SPR_LIGHT_DX_REST
        lda     #$FE
        sta     D64_SPR_LIGHT+$12
        sta     D64_SPR_LIGHT+$13
        lda     D64_SPR_TABLE+$15
        and     #$FC
        sec
        sbc     #8
        bcs     :+
        lda     #0
:       sta     D64_SPR_LIGHT+1
        sta     D64_SPR_LIGHT+3
        lda     D64_SPR_TABLE+$16
        and     #7
        cmp     #4
        ldx     #$EF
        ldy     #$9F
        bcs     :+
        ldx     #$9F
        ldy     #$EF
:       stx     D64_SPR_LIGHT_FILL_A
        sty     D64_SPR_LIGHT_FILL_B
        lda     #0
        sta     D64_SPR_LIGHT_FILL_A+1
        sta     D64_SPR_LIGHT_FILL_B+1
        lda     D64_SPR_TABLE+$16
        and     #$F8
        sec
        sbc     #$18
        bcs     :+
        lda     #0
:       sta     D64_SPR_LIGHT+2
        sta     D64_SPR_LIGHT+4
        lda     D64_CHR_ADSO+6
        lsr
        lda     #0
        bcc     :+
        lda     #$29
:       sta     D64_SPR_LIGHT_FLIP_PATCH
        rts
.endproc

; 22D4 vid_clear_play_area: the play area filled with colour 0 (JP 16B2).
.proc vid_clear_play_area
        lda     #0
        jmp     vid_fill_play_area
.endproc

; ================================================================== the height buffer and the probe

; 22D8 chr_step_table: the orientation entry of the step table of character IY: 23C2 (1-cell characters,
; bit 7 of [IY+5]) or 23A2 (2x2) + 8 [IY+1]; falls into 22E7.  Out: HL (A = H).
.proc chr_step_table
        ldy     #5
        lda     (ziy),y
        asl
        lda     #<D64_CHR_STEP_TABLE_2X2
        bcc     :+
        lda     #<D64_CHR_STEP_TABLE_1X1
:       sta     zhl
        lda     #>D64_CHR_STEP_TABLE_2X2
        sta     zhl+1
        ldy     #1
        lda     (ziy),y
        ; falls into util_add_bx_8al
.endproc

; 22E7 util_add_bx_8al: HL += 8 A (the product on 8 bits, ADD A,A x3).  Out: HL, A = H.
.proc util_add_bx_8al
        asl
        asl
        asl
        clc
        adc     zhl
        sta     zhl
        bcc     :+
        inc     zhl+1
:       lda     zhl+1
        rts
.endproc

; 22F0 chr_to_hbuf_coords: world position (L = x, H = y) -> height-buffer coordinates (y - [22F2],
; x - [22FE]).  C set when a coordinate is outside 2..15h, leaving the partial result: y fails -> HL unchanged;
; x fails -> H converted, L unchanged.
.proc chr_to_hbuf_coords
        lda     zhl+1
        sec
        sbc     D64_CHR_HBUF_ORIGIN_Y
        bcc     fail
        cmp     #2
        bcc     fail
        cmp     #$16
        bcs     fail
        sta     zhl+1
        lda     zhl
        sec
        sbc     D64_CHR_HBUF_ORIGIN_X
        bcc     fail
        cmp     #2
        bcc     fail
        cmp     #$16
        bcs     fail
        sta     zhl
        clc
        rts
fail:   sec
        rts
.endproc

; 2309 chr_probe_ahead_flat: chr_probe_cells with the height 0 (B = the fallback A).
.proc chr_probe_ahead_flat
        sta     zbc+1
        lda     #0
        beq     chr_probe_cells
.endproc

; 230D chr_probe_ahead: if the floor of [IY+4] (iso_floor_base) is not the floor of the height buffer [290B],
; returns the fallback A (C set; C and HL unchanged; E = the fallback); else chr_probe_cells with the height over
; that floor (falls into 2320).
.proc chr_probe_ahead
        sta     zde
        ldy     #4
        lda     (ziy),y
        jsr     iso_floor_base
        lda     D64_CHR_SHOWN_FLOOR
        cmp     zbc+1
        beq     :+
        lda     zde
        sec
        rts
:       ldy     #4
        lda     (ziy),y
        sec
        sbc     zbc+1
        ldx     zde
        stx     zbc+1
        ; falls into chr_probe_cells
.endproc

; 2320 chr_probe_cells: samples the 4x4 window of the height buffer in front of character IY into 2916 (a cell
; >= 10h is a character mark, kept & 30h; else its height minus A, kept in [2374]); the strides come from the
; step table entry (into the operands [2378], [237F]).  Off the centre of the buffer: A = the fallback B, C and
; HL unchanged, C (flag) set.  Else C = [2917], HL = the entry + 6 (dx, dy), A = [291B] (1-cell), or for a 2x2
; character [2918] if equal to [2917], else 2.  In: A = height, B = fallback, C, HL, IY.
; The window's cells lie within 50 bytes of the character's cell for every entry of the (constant) step tables
; (strides +-1, +-18h; starts FFCEh-0031h), so the cells are addressed as cell - 80h + an 8-bit offset.
.ifdef VELOZ
.proc chr_probe_cells
rowoff  = zt0+1                         ; the offset of the row's first cell from cell - 80h
        sta     D64_CHR_PROBE_HEIGHT
        lda     zhl                     ; EX DE,HL: the fallback HL in DE
        sta     zde
        lda     zhl+1
        sta     zde+1
        ldy     #3
        lda     (ziy),y
        sta     zhl+1
        dey
        lda     (ziy),y
        sta     zhl
        jsr     chr_to_hbuf_coords
        bcc     in
        lda     zde                     ; off the buffer: HL back, A = B, C (flag) set
        sta     zhl
        lda     zde+1
        sta     zhl+1
        lda     zbc+1
        rts
in:     ldy     zhl+1                   ; zp0 = the cell [28DB] + 24 y + x, - 80h (y, x in 2..15h)
        lda     iso_mul24_lo,y
        clc
        adc     zhl
        tax
        lda     iso_mul24_hi,y
        adc     #0
        tay                             ; Y:X = 24 y + x
        txa
        sec
        sbc     #$80
        bcs     :+
        dey
:       clc
        adc     D64_CHR_HBUF_PTR
        sta     zp0
        tya
        adc     D64_CHR_HBUF_PTR+1
        sta     zp0+1
        jsr     chr_step_table          ; HL = the entry
        ldy     #3                      ; the strides into the operands [2378], [237F]
:       lda     (zhl),y
        sta     D64_CHR_PROBE_INNER,y
        dey
        bpl     :-
        ldy     #4
        lda     (zhl),y                 ; the window's start, from cell - 80h
        eor     #$80
        sta     rowoff
        lda     zhl                     ; HL = the entry + 6 (dx, dy)
        clc
        adc     #6
        sta     zhl
        bcc     :+
        inc     zhl+1
:       ldx     #0                      ; the 4 cells of a row unrolled (Y = the cell's offset)
row:    ldy     rowoff
.repeat 4, k
        lda     (zp0),y
        cmp     #$10
        bcc     :+
        and     #$30
        bcs     :++
:       sec                             ; the height minus [2374]
        sbc     D64_CHR_PROBE_HEIGHT
:       sta     D64_CHR_PROBE+k,x
.if k < 3
        tya
        clc
        adc     D64_CHR_PROBE_INNER
        tay
.endif
.endrepeat
        lda     rowoff
        clc
        adc     D64_CHR_PROBE_OUTER
        sta     rowoff
        inx
        inx
        inx
        inx
        cpx     #16
        bne     row
        lda     D64_CHR_PROBE+1
        sta     zbc
        ldy     #5
        lda     (ziy),y
        bpl     two
        lda     D64_CHR_PROBE+5
        rts
two:    lda     D64_CHR_PROBE+2
        cmp     zbc
        beq     :+
        lda     #2
:       rts
.endproc
.else
.proc chr_probe_cells
off     = zt0                           ; the offset of the next cell from cell - 80h
rowoff  = zt0+1                         ; the offset of the row's first cell
        sta     D64_CHR_PROBE_HEIGHT
        lda     zhl                     ; EX DE,HL: the fallback HL in DE
        sta     zde
        lda     zhl+1
        sta     zde+1
        ldy     #3
        lda     (ziy),y
        sta     zhl+1
        dey
        lda     (ziy),y
        sta     zhl
        jsr     chr_to_hbuf_coords
        bcc     in
        lda     zde                     ; off the buffer: HL back, A = B, C (flag) set
        sta     zhl
        lda     zde+1
        sta     zhl+1
        lda     zbc+1
        rts
in:     ldy     zhl+1                   ; zp0 = the cell [28DB] + 24 y + x, - 80h (y, x in 2..15h)
        lda     iso_mul24_lo,y
        clc
        adc     zhl
        tax
        lda     iso_mul24_hi,y
        adc     #0
        tay                             ; Y:X = 24 y + x
        txa
        sec
        sbc     #$80
        bcs     :+
        dey
:       clc
        adc     D64_CHR_HBUF_PTR
        sta     zp0
        tya
        adc     D64_CHR_HBUF_PTR+1
        sta     zp0+1
        jsr     chr_step_table          ; HL = the entry
        ldy     #3                      ; the strides into the operands [2378], [237F]
:       lda     (zhl),y
        sta     D64_CHR_PROBE_INNER,y
        dey
        bpl     :-
        ldy     #4
        lda     (zhl),y                 ; the window's start, from cell - 80h
        eor     #$80
        sta     rowoff
        lda     zhl                     ; HL = the entry + 6 (dx, dy)
        clc
        adc     #6
        sta     zhl
        bcc     :+
        inc     zhl+1
:       ldx     #0
row:    lda     rowoff
        sta     off
cell:   ldy     off
        lda     (zp0),y
        cmp     #$10
        bcc     height
        and     #$30
        bcs     store
height: sec                             ; the height minus [2374]
        sbc     D64_CHR_PROBE_HEIGHT
store:  sta     D64_CHR_PROBE,x
        tya
        clc
        adc     D64_CHR_PROBE_INNER
        sta     off
        inx
        txa
        and     #3
        bne     cell
        lda     rowoff
        clc
        adc     D64_CHR_PROBE_OUTER
        sta     rowoff
        cpx     #16
        bne     row
        lda     D64_CHR_PROBE+1
        sta     zbc
        ldy     #5
        lda     (ziy),y
        bpl     two
        lda     D64_CHR_PROBE+5
        rts
two:    lda     D64_CHR_PROBE+2
        cmp     zbc
        beq     :+
        lda     #2
:       rts
.endproc
.endif

; 2444 chr_mark_hbuf: the mark C into the height-buffer cell of character IY (iso_grid_cell_of; nothing when it
; is off the buffer or off the floor shown): low nibble kept, mark ORed; a 2x2 character also marks the cells
; -1, -18h, -19h.  Out: IX = the cell (unchanged when off the buffer).
.ifdef VELOZ
.proc chr_mark_hbuf
        jsr     iso_grid_cell_of
        bcs     done
        ldy     #0
        lda     (zix),y
        and     #$0F
        ora     zbc
        sta     (zix),y
        ldy     #5
        lda     (ziy),y
        bmi     done
        lda     zix
        sec
        sbc     #$19
        sta     zp0
        lda     zix+1
        sbc     #0
        sta     zp0+1
        ldy     #$18                    ; IX - 1
        lda     (zp0),y
        and     #$0F
        ora     zbc
        sta     (zp0),y
        ldy     #1                      ; IX - 18h
        lda     (zp0),y
        and     #$0F
        ora     zbc
        sta     (zp0),y
        dey                             ; IX - 19h
        lda     (zp0),y
        and     #$0F
        ora     zbc
        sta     (zp0),y
done:   rts
.endproc
.else
.proc chr_mark_hbuf
        jsr     iso_grid_cell_of
        bcs     done
        ldy     #0
        lda     (zix),y
        and     #$0F
        ora     zbc
        sta     (zix),y
        ldy     #5
        lda     (ziy),y
        bmi     done
        lda     zix
        sec
        sbc     #$19
        sta     zp0
        lda     zix+1
        sbc     #0
        sta     zp0+1
        ldy     #$18                    ; IX - 1
        jsr     mark
        ldy     #1                      ; IX - 18h
        jsr     mark
        dey                             ; IX - 19h
mark:   lda     (zp0),y
        and     #$0F
        ora     zbc
        sta     (zp0),y
done:   rts
.endproc
.endif

; ================================================================== moving a character

; 2472 chr_update: moves one character and updates its sprite.  HL = its chr_table entry: chr_load_params;
; IX = the sprite [2477], spr_save_old_rect; IY = the record [247E]; the mark leaves the height buffer; [3EED]
; (Malachi rising) is read and cleared; chr_think_or_step; the mark [IY+0E] goes back (JP 2444).
; Out: IY = the record, IX = what the last chr_mark_hbuf leaves.
.proc chr_update
        jsr     chr_load_params
        lda     D64_CHR_CUR_SPRITE
        sta     zix
        lda     D64_CHR_CUR_SPRITE+1
        sta     zix+1
        jsr     spr_save_old_rect
        lda     D64_CHR_CUR_DATA
        sta     ziy
        lda     D64_CHR_CUR_DATA+1
        sta     ziy+1
        lda     #0
        sta     zbc
        jsr     chr_mark_hbuf
        lda     D64_CHR_CUR_SPRITE      ; IX back (the Z80's PUSH IX / POP IX)
        sta     zix
        lda     D64_CHR_CUR_SPRITE+1
        sta     zix+1
        lda     #0
        ldx     D64_CHR_MALACHI_RISING  ; Z: not rising
        sta     D64_CHR_MALACHI_RISING
        jsr     chr_think_or_step
        ldy     #$0E
        lda     (ziy),y
        sta     zbc
        jmp     chr_mark_hbuf
.endproc

; 249A chr_think_or_step: NZ (Malachi rising): only chr_animate.  A step in progress (bit 0 of [IY]): finish
; it (2556).  Else the behaviour routine [24A6] (HL = its address, as the Z80's JP (HL)).  In: Z, IY, IX.
.proc chr_think_or_step
        beq     :+
        jmp     chr_animate
:       ldy     #0
        lda     (ziy),y
        lsr
        bcc     :+
        jmp     chr_advance_anim
:       lda     D64_CHR_CUR_BEHAVIOUR
        sta     zhl
        lda     D64_CHR_CUR_BEHAVIOUR+1
        sta     zhl+1
        jmp     (D64_CHR_CUR_BEHAVIOUR)
.endproc

; 23E2 chr_guillermo_behaviour: Guillermo.  A fall in progress ([23E4] <> 0, the mirror trap): the counter goes
; down (1 stays, nothing); 13h with the step [2406] = 2: x - 1 and chr_animate; [23E4] or that step = 1: the
; sprite becomes inactive; else sprite y += [2406], redraw, [2912] = FF.  Normal: nothing while the camera follows
; another character ([37DC]); left (8) newly pressed: chr_turn +1; right (1): chr_turn -1; up (0) down:
; chr_probe_ahead and chr_try_advance.  The probe's fallbacks are what the registers hold: A = the bit
; sys_key_down found, C = the code it tested last, HL = this routine's Z80 address 23E2: off the floor shown
; chr_try_advance reads its step from there, the bytes 00 3Eh of the code (guillermo_self).  In: IY, IX.
.proc chr_guillermo_behaviour
        lda     D64_CHR_GUILLERMO_STATE
        beq     normal
        sec
        sbc     #1
        bne     :+
        rts
:       sta     D64_CHR_GUILLERMO_STATE
        cmp     #$13
        bne     fall
        lda     D64_CHR_GUILLERMO_FALL_DY
        cmp     #2
        bne     fall
        ldy     #2
        lda     (ziy),y
        sec
        sbc     #1
        sta     (ziy),y
        jmp     chr_animate
fall:   cmp     #1
        beq     hide
        ldy     #2
        lda     (zix),y
        clc
        adc     D64_CHR_GUILLERMO_FALL_DY
        sta     (zix),y
        ldy     #0
        lda     (zix),y
        and     #$3F
        ora     #$80
        sta     (zix),y
        lda     #$FF
        sta     D64_CHR_MOVED
        rts
hide:   lda     #$FE
        ldy     #0
        sta     (zix),y
        rts
normal: lda     D64_GAME_CAMERA_OTHER
        bne     ret
        lda     #8
        jsr     sys_key_pressed
        beq     :+
        lda     #1
        sta     zbc
        jmp     chr_turn
:       lda     #1
        jsr     sys_key_pressed
        beq     :+
        lda     #$FF
        sta     zbc
        jmp     chr_turn
:       lda     #0
        jsr     sys_key_down
        beq     ret
        ldx     #<guillermo_self
        stx     zhl
        ldx     #>guillermo_self
        stx     zhl+1
        jsr     chr_probe_ahead
        jmp     chr_try_advance
ret:    rts
.endproc
guillermo_self: .byte   $00, $3E        ; the bytes at 23E2h (NOP; LD A,n)

; 24A9 chr_try_advance: advances character IY if the heights allow it.  A = ahead1, C = ahead2 (relative heights
; of the two cells ahead), HL = the dx, dy of the orientation entry.  Clears bit 4 (descending) of [IY+5]; 2x2:
; chr_try_advance_2x2.  1-cell: a character mark (10h/20h) in the second cell blocks; turned across a slope
; (bit 5): moves only on level ground; else climbs (1) or descends (FF, bit 4 set) one unit, any other difference
; blocks; two equal cells ahead: becomes 2x2 ([IY+5] &= 10h) and steps once, or twice for the orientations 0
; and 3; [2912] = FF; animates (2556).  (The Z80's E = [IY+4] serves only the dead code at 254F.)
.proc chr_try_advance
        tax
        ldy     #5
        lda     (ziy),y
        and     #$EF
        sta     (ziy),y
        bmi     one
        txa
        jmp     chr_try_advance_2x2
one:    lda     zbc
        cmp     #$10
        beq     ret
        cmp     #$20
        beq     ret
        lda     (ziy),y
        and     #$20
        beq     level
        stx     zbc+1                   ; LD B,A
        jsr     chr_orientation_parity
        beq     :+
        ldx     zbc
:       txa
        bne     ret
        jmp     chr_step_and_animate
level:  cpx     #1                      ; 1 climbs, FF descends (bit 4): the height + ahead1
        beq     :+
        cpx     #$FF
        bne     ret
        lda     (ziy),y
        ora     #$10
        sta     (ziy),y
:       ldy     #4
        txa
        clc
        adc     (ziy),y
        sta     (ziy),y
        cpx     zbc
        beq     :+
        txa
        jmp     chr_step_level
:       ldy     #5
        lda     (ziy),y
        and     #$10
        sta     (ziy),y
        jsr     personajes_step_kept
        bne     :+
        jsr     chr_apply_step
:       jmp     personajes_moved
ret:    rts
.endproc

; chr_apply_step with HL kept (the Z80's PUSH HL / CALL 2539 / POP HL), then chr_orientation_parity
.proc personajes_step_kept
        lda     zhl
        pha
        lda     zhl+1
        pha
        jsr     chr_apply_step
        pla
        sta     zhl+1
        pla
        sta     zhl
        jmp     chr_orientation_parity
.endproc

; 2503 chr_orientation_parity: 0 (Z) for the orientations ([IY+1] & 3) 0 and 3, else (o ^ 3).  Out: A, Z.
.proc chr_orientation_parity
        ldy     #1
        lda     (ziy),y
        and     #3
        beq     :+
        eor     #3
:       rts
.endproc

; 250C chr_try_advance_2x2: A = ahead1: 1 climbs (height + 1, [IY+5] = 80h: 1-cell), FF descends (height - 1,
; [IY+5] = 90h), 0 is a level step (2549), anything else blocks.  After climbing or descending it steps once, or
; twice for the orientations 1 and 2; [2912] = FF; animates (2556).
.proc chr_try_advance_2x2
        tax
        bne     :+
        jmp     chr_step_level
:       ldy     #$80                    ; 1 climbs: [IY+5] = 80h
        cpx     #1
        beq     :+
        ldy     #$90                    ; FF descends: [IY+5] = 90h
        cpx     #$FF
        beq     :+
        rts
:       tya
        ldy     #5
        sta     (ziy),y
        dey
        txa                             ; the height + ahead1
        clc
        adc     (ziy),y
        sta     (ziy),y
        jsr     personajes_step_kept
        beq     personajes_moved
        jsr     chr_apply_step
        ; falls into personajes_moved
.endproc

; [2912] = FF, then 2556
.proc personajes_moved
        lda     #$FF
        sta     D64_CHR_MOVED
        jmp     chr_advance_anim
.endproc

; 2539 chr_apply_step: [IY+2] += [HL] (dx), [IY+3] += [HL+1] (dy).  Out: A = the new [IY+3], HL = HL + 1.
.proc chr_apply_step
        ldy     #0
        lda     (zhl),y
        ldy     #2
        clc
        adc     (ziy),y
        sta     (ziy),y
        inc     zhl
        bne     :+
        inc     zhl+1
:       ldy     #0
        lda     (zhl),y
        ldy     #3
        clc
        adc     (ziy),y
        sta     (ziy),y
        rts
.endproc

; 2561 chr_turn: turns character IY by C (+1 or FF): [IY] = 0; a 1-cell character toggles bit 5 of [IY+5];
; [IY+1] = ([IY+1] + C) & 3; falls into chr_animate.
.proc chr_turn
        ldy     #0
        tya
        sta     (ziy),y
        ldy     #5
        lda     (ziy),y
        bpl     :+
        eor     #$20
        sta     (ziy),y
:       ldy     #1
        lda     (ziy),y
        clc
        adc     zbc
        and     #3
        sta     (ziy),y
        jmp     chr_animate
.endproc

; 2549 chr_step_level: a level step: its SUB C / INC A / CP 3 is dead (the JR at 254D is unconditional): falls
; into chr_step_and_animate.
chr_step_level:

; 2553 chr_step_and_animate: chr_apply_step, then 2556.
.proc chr_step_and_animate
        jsr     chr_apply_step
        ; falls into chr_advance_anim
.endproc

; 2556 (inside 2553, also the target of 24A2): [IY] = ([IY] + 1) & 3, then chr_animate (falls into it).
.proc chr_advance_anim
        ldy     #0
        lda     (ziy),y
        clc
        adc     #1
        and     #3
        sta     (ziy),y
.endproc

; 257C chr_animate: chr_select_frame, [2912] = FF, chr_project_or_hide: not visible, the sprite is marked as
; leaving and chr_project_or_hide returns from here (it drops this routine's return address and the frame kept
; on the stack, as the Z80's POP HL / POP HL); visible: the frame into the sprite (2589).  In: IY, IX.
.proc chr_animate
        jsr     chr_select_frame
        lda     #$FF
        sta     D64_CHR_MOVED
        lda     zhl
        pha
        lda     zhl+1
        pha
        jsr     chr_project_or_hide
        pla
        sta     zhl+1
        pla
        sta     zhl
        ; falls into chr_show_frame
.endproc

; 2589 chr_show_frame (inside chr_animate; the JP target of 2094 in spr_update_char_sprite): the 4-byte frame HL
; (graphics word, width, height) into [IX+7], [IX+8], [IX+5], [IX+6]; [IX] = 80h | C (the depth); if the
; camera-relative orientation (iso_orient_relative of [IY+1], >> 1) differs from the flip state [IY+6], the flip
; routine [25AE]; [2912] = FF.
.proc chr_show_frame
        ldx     #3
:       txa
        tay
        lda     (zhl),y
        ldy     dst,x
        sta     (zix),y
        dex
        bpl     :-
        lda     zbc
        ora     #$80
        ldy     #0
        sta     (zix),y
        ldy     #1
        lda     (ziy),y
        jsr     iso_orient_relative
        lsr
        ldy     #6
        eor     (ziy),y
        beq     :+
        jsr     flip
:       lda     #$FF
        sta     D64_CHR_MOVED
        rts
flip:   jmp     (D64_CHR_CUR_FLIP)
dst:    .byte   7, 8, 5, 6
.endproc

; 25B6 chr_select_frame: the 4-byte animation entry of character IY, sprite IX.  o = the camera-relative
; orientation, n = [IY]; the low nibble of [IX+0B] = 4o | n; index = 4 (((o+1) & 2) 2 | n).  A real table [25D9]:
; HL = table + index.  The monks ([25D9] = C0xxh, a tag: tested as C0h exactly, the C64's tables lie at CFxxh):
; the shared body table 2D30 + index, whose graphics word becomes the monk's face [2BE8 + xx] (the second face,
; +1Eh on the C64 for the CPC's +32h, on the frames with index bit 4).  Out: HL.
.proc chr_select_frame
        ldy     #1
        lda     (ziy),y
        jsr     iso_orient_relative
        sta     zt0                     ; o
        asl
        asl
        ldy     #0
        ora     (ziy),y
        sta     zt0+1
        ldy     #$0B
        lda     (zix),y
        and     #$F0
        ora     zt0+1
        sta     (zix),y
        lda     zt0
        clc
        adc     #1
        and     #2
        asl
        ldy     #0
        ora     (ziy),y
        asl
        asl                             ; the index
        ldx     D64_CHR_CUR_ANIM+1
        cpx     #$C0
        beq     monk
        clc
        adc     D64_CHR_CUR_ANIM
        sta     zhl
        lda     #0
        adc     D64_CHR_CUR_ANIM+1
        sta     zhl+1
        rts
monk:   tay
        clc
        adc     #<D64_CHR_ANIM_MONK
        sta     zhl
        lda     #>D64_CHR_ANIM_MONK
        adc     #0
        sta     zhl+1
        ldx     D64_CHR_CUR_ANIM        ; the monk's face [2BE8 + xx], or his second face
        tya
        ldy     #0
        and     #$10
        beq     :+
        lda     #FACE2_OFFSET
:       clc
        adc     D64_SPR_MONK_FACES,x
        sta     (zhl),y
        iny
        lda     D64_SPR_MONK_FACES+1,x
        adc     #0
        sta     (zhl),y
        rts
.endproc

; 2605 spr_save_old_rect: sprite IX: old x, y [IX+3,4] = [IX+1,2]; old width, height [IX+9,0A] = [IX+5,6].
; Out: A = [IX+6].
.ifdef VELOZ
.proc spr_save_old_rect                 ; (the 4 copies unrolled, in the order of the Z80's; X = FFh and N/Z as the loop left them)
        ldy     #1
        lda     (zix),y
        ldy     #3
        sta     (zix),y
        ldy     #2
        lda     (zix),y
        ldy     #4
        sta     (zix),y
        ldy     #5
        lda     (zix),y
        ldy     #9
        sta     (zix),y
        ldy     #6
        lda     (zix),y
        ldy     #$0A
        sta     (zix),y
        ldx     #$FF
        rts
.endproc
.else
.proc spr_save_old_rect
        ldx     #3
:       ldy     src,x
        lda     (zix),y
        ldy     dst,x
        sta     (zix),y
        dex
        bpl     :-
        rts
src:    .byte   6, 5, 2, 1
dst:    .byte   $0A, 9, 4, 3
.endproc
.endif

; 261E chr_project_or_hide: chr_project; visible: it returns to chr_animate (past this routine).  Not visible:
; drops the return address into chr_animate and the frame chr_animate keeps on the stack, and falls into
; spr_mark_leaving, whose RTS leaves chr_animate.
.proc chr_project_or_hide
        jsr     chr_project
        pla
        pla
        pla
        pla
        ; falls into spr_mark_leaving
.endproc

; 2623 spr_mark_leaving: sprite IX stops being visible: nothing if it is inactive (FE); else [IX] = 80h (redraw)
; and bit 7 of [IX+5] set (erase the old area).  Out: A = the old [IX], Z = (A = FE).
.proc spr_mark_leaving
        ldy     #0
        lda     (zix),y
        cmp     #$FE
        beq     done
        tax
        lda     #$80
        sta     (zix),y
        ldy     #5
        lda     (zix),y
        ora     #$80
        sta     (zix),y
        txa
        cmp     #$FE
done:   rts
.endproc

; 2632 chr_project: projects character (or object, door) IY onto the screen, sprite IX.  Local x = [IY+2] -
; [2636], y = [IY+3] - [2640], each < 28h; the floor of [IY+4] must be [264E]; h = the height over it.  The camera
; rotation [2656] turns (x, y) (HL); they go to [IX+12h,13h].  Visible when r = x+y-h-6 is in 8..39h (row 4(r+1))
; and the column 2(x-y)+28h in 0..4Fh: then the return address is dropped (it returns to its caller's caller) and
; the depth is max(0, x+y-10h).  Not visible: a plain return.  Test mode ([2684] = C9h, set by 0ABC): A = the
; depth, HL = row:column, C = x+y.  Normal mode: plus the per-orientation offset of the table [28D5] (+16 per
; camera-relative orientation, +2 per frame chosen from [IY], [IY+5]) and [IY+7] / [IY+8]: the sprite's x
; (bytes) and y (lines) in [IX+1,2] (and [IX+3,4] when the sprite was inactive), HL = them; C = the depth.
        .assert D64_CHR_ROOM_ORIGIN_Y = D64_CHR_ROOM_ORIGIN_X + 1, error, "chr_project: the origins contiguous"
personajes_project_no:
        rts
.proc chr_project
        ldx     #0                      ; L = x - [2636], H = y - [2640], each < 28h
        ldy     #2
:       lda     (ziy),y
        sec
        sbc     D64_CHR_ROOM_ORIGIN_X,x
        bcc     personajes_project_no
        cmp     #$28
        bcs     personajes_project_no
        sta     zhl,x
        iny
        inx
        cpx     #2
        bne     :-
        lda     (ziy),y
        jsr     iso_floor_base
        lda     zbc+1
        cmp     D64_CHR_ROOM_FLOOR
        bne     no
        ldy     #4
        lda     (ziy),y
        sec
        sbc     zbc+1
        sta     zbc+1                   ; B = h
        pha
        jsr     rotate
        pla
        sta     zt0                     ; h
        ldy     #$12
        jsr     personajes_store_hl
        clc
        adc     zhl
        sta     zbc                     ; C = x + y
        sec
        sbc     zt0
        bcc     no
        sbc     #6
        bcc     no
        cmp     #8
        bcc     no
        cmp     #$3A
        bcs     no
        adc     #1                      ; (C clear) row = 4 (r + 1)
        asl
        asl
        sta     zbc+1
        lda     zhl                     ; column = 2 (x - y) + 50h - 28h
        sec
        sbc     zhl+1
        asl
        clc
        adc     #$50
        sec
        sbc     #$28
        bcc     no
        cmp     #$50
        bcs     no
        sta     zhl
        lda     zbc+1
        sta     zhl+1
        pla                             ; visible: back to the caller's caller (POP DE)
        pla
        lda     zbc
        sec
        sbc     #$10
        bcs     :+
        lda     #0
:       ldx     D64_CHR_PROJECT_TEST
        cpx     #$C9
        bne     :+
no:     rts
:       sta     zbc                     ; C = the depth
        ldx     #0                      ; B: the frame
        ldy     #5
        lda     (ziy),y
        bmi     stairs
half:   ldy     #0                      ; 268F
        lda     (ziy),y
        lsr
        bcc     frame
        inx
frame:  stx     zbc+1                   ; 2696
        ldy     #1
        lda     (ziy),y
        jsr     iso_orient_relative
        asl
        asl
        asl
        asl
        adc     zbc+1                   ; (C clear) 16 o + 2 b
        adc     zbc+1
        clc
        adc     D64_CHR_SPRITE_OFFSETS
        sta     zde
        lda     #0
        adc     D64_CHR_SPRITE_OFFSETS+1
        sta     zde+1
        ldy     #0
        lda     (zde),y
        clc
        adc     zhl
        ldy     #7
        clc
        adc     (ziy),y
        sta     zhl
        ldy     #1
        lda     (zde),y
        clc
        adc     zhl+1
        ldy     #8
        clc
        adc     (ziy),y
        sta     zhl+1
        ldy     #1
        jsr     personajes_store_hl
        ldy     #0
        lda     (zix),y
        cmp     #$FE
        bne     ret
        ldy     #3
        jmp     personajes_store_hl
ret:    rts
stairs: inx                             ; 26CD: the frames of a 1-cell character
        inx
        and     #$20
        bne     half
        inx
        inx
        lda     (ziy),y
        and     #3
        bne     s26EE
        ldy     #0
        lda     (ziy),y
        lsr
        bcc     frame
        inx
s26E5:  ldy     #5
        lda     (ziy),y
        and     #$10
        beq     frame
        inx
        bne     frame
s26EE:  sta     zt0
        inx
        inx
        inx
        lda     (ziy),y
        and     #$40
        bne     :+
        inx
        inx
        inx
        inx
:       lda     zt0
        cmp     #1
        bne     s26E5
        inx
        inx
        bne     s26E5
rotate: jmp     (D64_CHR_CAMERA_TRANSFORM)
.endproc

; [IX+Y] = L, [IX+Y+1] = H (A = H)
.proc personajes_store_hl
        lda     zhl
        sta     (zix),y
        iny
        lda     zhl+1
        sta     (zix),y
        rts
.endproc

; ================================================================== the command streams

; 274B chr_load_params: the 5 words of the chr_table entry HL into the operands listed at 2741 (sprite 2477,
; record 247E, behaviour 24A6, flip 25AE, animation 25D9): that list is constant, so the 6502 stores them
; directly (bytes 0-3 to $46-$49, 4-7 to $0208-$020B, 8-9 to $4A-$4B).  HL is left unchanged (the Z80 leaves
; HL + 10; its only caller, chr_update, does not read it).
        .assert D64_CHR_CUR_DATA = D64_CHR_CUR_SPRITE + 2 && D64_CHR_CUR_FLIP = D64_CHR_CUR_BEHAVIOUR + 2, error, "chr_load_params"
.ifdef VELOZ
.proc chr_load_params                   ; (the 10 bytes unrolled, in the same order; Y, C and N/Z as the loop left them)
        ldy     #9
        lda     (zhl),y
        sta     D64_CHR_CUR_ANIM+1
        dey
        lda     (zhl),y
        sta     D64_CHR_CUR_ANIM
        dey
        lda     (zhl),y
        sta     D64_CHR_CUR_FLIP+1
        dey
        lda     (zhl),y
        sta     D64_CHR_CUR_FLIP
        dey
        lda     (zhl),y
        sta     D64_CHR_CUR_BEHAVIOUR+1
        dey
        lda     (zhl),y
        sta     D64_CHR_CUR_BEHAVIOUR
        dey
        lda     (zhl),y
        sta     D64_CHR_CUR_DATA+1
        dey
        lda     (zhl),y
        sta     D64_CHR_CUR_DATA
        dey
        lda     (zhl),y
        sta     D64_CHR_CUR_SPRITE+1
        dey
        lda     (zhl),y
        sta     D64_CHR_CUR_SPRITE
        dey
        clc
        rts
.endproc
.else
.proc chr_load_params
        ldy     #9
loop:   lda     (zhl),y
        cpy     #8
        bcc     :+
        sta     D64_CHR_CUR_ANIM-8,y
        bcs     next
:       cpy     #4
        bcc     :+
        sta     D64_CHR_CUR_BEHAVIOUR-4,y
        bcs     next
:       sta     D64_CHR_CUR_SPRITE,y
next:   dey
        bpl     loop
        rts
.endproc
.endif

; 2765 chr_command_bit: the next bit (MSB first) of the command stream of character IY: when the bit counter
; [IY+9] is 0, [IY+0A] = [word [IY+0C] + index [IY+0B]] and the index advances; counter = (counter + 1) & 7;
; [IY+0A] <<= 1.  Out: C = the bit shifted out, A = the new [IY+0A] (Z).
.proc chr_command_bit
        ldy     #9
        lda     (ziy),y
        bne     shift
        ldy     #$0B
        lda     (ziy),y
        tax
        clc
        adc     #1
        sta     (ziy),y
        txa
        iny
        clc
        adc     (ziy),y
        sta     zhl
        iny
        lda     (ziy),y
        adc     #0
        sta     zhl+1
        ldy     #0
        lda     (zhl),y
        ldy     #$0A
        sta     (ziy),y
        ldy     #9
        lda     #0
shift:  clc
        adc     #1
        and     #7
        sta     (ziy),y
        ldy     #$0A
        lda     (ziy),y
        asl
        sta     (ziy),y
        rts
.endproc

; 280D chr_read_command: decodes one command of character IY's bit stream into C (C flag clear).  1-cell: '1b'
; -> b.  2x2: '1' -> 1.  Both: '01b' -> 2+b (a turn), '001b' -> 4+b, '0000' -> 0 for a 1-cell character, or the
; stream restarts ([IY+0B] = [IY+9] = 0) and is read again (2x2).  '0001' = the end: bit 7 of [IY+9] set and
; the C flag set (the Z80 POPs its return address and the step 278F pushed, returning from 278F; its only
; caller, 278F, does so on the flag).
.proc personajes_read_command
start:  ldy     #5
        lda     (ziy),y
        bpl     two
        jsr     chr_command_bit
        bcc     c2823
        lda     #0
        beq     last
two:    jsr     chr_command_bit
        bcc     c2823
        lda     #1
        sta     zbc
        clc
        rts
c2823:  lda     #1
        sta     zbc
        jsr     chr_command_bit
        bcs     last1
        asl     zbc                     ; RL C: 2
        jsr     chr_command_bit
        bcs     last1
        jsr     chr_command_bit
        bcs     end
        lda     #0
        sta     zbc
        ldy     #5
        lda     (ziy),y
        bmi     ok
        ldy     #$0B
        lda     #0
        sta     (ziy),y
        ldy     #9
        sta     (ziy),y
        bcc     start                   ; (C clear: the last bit read was 0; LDY #9 left Z clear)
last:   sta     zbc
last1:  jsr     chr_command_bit
        rol     zbc                     ; C <= 2: the C flag comes out clear
        rts
end:    ldy     #9
        lda     (ziy),y
        ora     #$80
        sta     (ziy),y
        sec
        rts
ok:     clc
        rts
.endproc

; 278F chr_ai_follow_commands: Adso and the monks.  Nothing when bit 7 of [IY+9] (no commands).  Saves the 10
; bytes [IY+2..0B] to 28B9, reads a command (the end of the stream returns from here): 3 turns +1, 2 turns -1;
; otherwise (A, C) = the height differences assumed off the floor shown (2x2: 1 -> (0,FF), 5 -> (FF,FF), others
; (1,FF); 1-cell: 0 -> (0,0) with bit 5 of [IY+5] else (1,2), 1 -> (FF,FE), 4 -> (1,1), others (FF,FF)),
; [2912] = 0, chr_probe_ahead and chr_try_advance with the step entry + 6; if [2912] is still 0 the 10 bytes are
; restored.  In: IY, IX.
.proc chr_ai_follow_commands
        ldy     #9
        lda     (ziy),y
        bpl     :+
        rts
:       jsr     chr_step_table
        lda     zhl
        clc
        adc     #6
        pha
        lda     zhl+1
        adc     #0
        pha
        jsr     chr_backup_args
        jsr     personajes_copy10
        jsr     personajes_read_command
        pla
        sta     zhl+1
        pla
        sta     zhl
        bcc     :+
        rts
:       lda     zbc
        ldx     #1
        cmp     #3
        beq     turn
        ldx     #$FF
        cmp     #2
        beq     turn
        tax                             ; the command: 0, 1, 4, 5 here
        ldy     #5
        lda     (ziy),y
        bmi     one
        ldy     #$FF                    ; 2x2: C = FF
        lda     two_a,x
        jmp     go
one:    cpx     #0
        bne     :+
        and     #$20                    ; 1-cell, command 0: (0, 0) across a slope, else (1, 2)
        beq     :+
        lda     #0
        tay
        beq     go
:       ldy     one_c,x
        lda     one_a,x
go:     sty     zbc
        sta     zbc+1                   ; LD B,A
        ldx     #0
        stx     D64_CHR_MOVED
        jsr     chr_probe_ahead
        jsr     chr_try_advance
        lda     D64_CHR_MOVED
        bne     done
        jsr     chr_backup_args         ; EX DE,HL / LDIR: the 10 bytes back
        ldy     #9
:       lda     (zde),y
        sta     (zhl),y
        dey
        bpl     :-
        rts
turn:   stx     zbc
        jmp     chr_turn
done:   rts
two_a:  .byte   1, 0, 1, 1, 1, $FF      ; 2x2, by command: A (C = FF)
one_a:  .byte   1, $FF, 1, 1, 1, $FF    ; 1-cell, by command (0: when not across a slope)
one_c:  .byte   2, $FE, $FF, $FF, 1, $FF
.endproc

; the LDIR of 10 bytes HL -> DE (chr_backup_args' BC; the areas do not overlap)
.proc personajes_copy10
        ldy     #9
:       lda     (zhl),y
        sta     (zde),y
        dey
        bpl     :-
        rts
.endproc

; 28AD chr_backup_args: the LDIR arguments for the position block of character IY: HL = IY + 2, DE = 28B9
; (the Z80's BC = 10: the 6502 copies, personajes_copy10 and 278F, count 10 themselves).
.proc chr_backup_args
        lda     ziy
        clc
        adc     #2
        sta     zhl
        lda     ziy+1
        adc     #0
        sta     zhl+1
        lda     #<D64_CHR_BACKUP
        sta     zde
        lda     #>D64_CHR_BACKUP
        sta     zde+1
        rts
.endproc

; ================================================================== rooms, the height buffer, the clock

; 2855 iso_select_room: [290E] = A; [11DA] = HL = the record A of the room table (each record starts with its
; length).  Between DI and EI when A <> 0.  (The Z80's BC = 7FC0h, the 6128's bank switching left over, and
; A = H are not reproduced: its caller reads neither.)
.proc iso_select_room
        sta     D64_ISO_ROOM_NUMBER
        ldx     #<D64_ISO_ROOM_TABLE
        stx     zhl
        ldx     #>D64_ISO_ROOM_TABLE
        stx     zhl+1
        tax
        beq     done
        jsr     plat_di
        ldy     #0
loop:   LEE_SALA
        clc
        adc     zhl
        sta     zhl
        bcc     :+
        inc     zhl+1
:       dex
        bne     loop
        jsr     plat_ei
done:   ldx     zhl
        stx     D64_ISO_ROOM_PTR
        ldx     zhl+1
        stx     D64_ISO_ROOM_PTR+1
        rts
.endproc

; 2873 chr_fill_height_buffer: clears the 24x24 height buffer [28DB] (240h bytes), sets the window origin from
; the room of character IY (07FF iso_grid_set_origin, which returns the floor base 0 / 0Bh / 16h), [3454] = the
; floor's height data and fills the buffer (JP 3456 chr_hbuf_fill_room).
.ifdef VELOZ
.proc chr_fill_height_buffer
        lda     D64_CHR_HBUF_PTR        ; the clear stores into the buffer directly (sta abs,y: 8 stores 72 bytes
        ldx     D64_CHR_HBUF_PTR+1      ; apart, Y = 0..71); their operands are patched when the pointer is not
        cmp     last                    ; the last call's (the path search switches it to its grid and back)
        bne     patch
        cpx     last+1
        beq     clear
patch:  sta     last
        stx     last+1
        ldy     #0
@p:     sta     st+1,y                  ; the k-th store's operand: the pointer + 72 k
        pha
        txa
        sta     st+2,y
        pla
        clc
        adc     #72
        bcc     :+
        inx
:       iny
        iny
        iny
        cpy     #24
        bne     @p
clear:  lda     #0
        ldy     #71
st:     .repeat 8
        sta     $FFFF,y                 ; (the operands are patched above)
        .endrepeat
        dey
        bpl     st
        jsr     iso_grid_set_origin
        ldx     #<D64_CHR_FLOOR0_HEIGHTS
        ldy     #>D64_CHR_FLOOR0_HEIGHTS
        cmp     #0
        beq     set
        ldx     #<D64_CHR_FLOOR1_HEIGHTS
        ldy     #>D64_CHR_FLOOR1_HEIGHTS
        cmp     #$0B
        beq     set
        ldx     #<D64_CHR_FLOOR2_HEIGHTS
        ldy     #>D64_CHR_FLOOR2_HEIGHTS
set:    stx     D64_CHR_FLOOR_HEIGHTS_PTR
        sty     D64_CHR_FLOOR_HEIGHTS_PTR+1
        jmp     chr_hbuf_fill_room
last:   .word   0                       ; the pointer the stores are patched for (0: never yet)
.endproc
.else
.proc chr_fill_height_buffer
        lda     D64_CHR_HBUF_PTR
        sta     zp0
        lda     D64_CHR_HBUF_PTR+1
        sta     zp0+1
        lda     #0
        tay
        ldx     #2
:       sta     (zp0),y
        iny
        bne     :-
        inc     zp0+1
        dex
        bne     :-
        ldy     #$3F
:       sta     (zp0),y
        dey
        bpl     :-
        jsr     iso_grid_set_origin
        ldx     #<D64_CHR_FLOOR0_HEIGHTS
        ldy     #>D64_CHR_FLOOR0_HEIGHTS
        cmp     #0
        beq     set
        ldx     #<D64_CHR_FLOOR1_HEIGHTS
        ldy     #>D64_CHR_FLOOR1_HEIGHTS
        cmp     #$0B
        beq     set
        ldx     #<D64_CHR_FLOOR2_HEIGHTS
        ldy     #>D64_CHR_FLOOR2_HEIGHTS
set:    stx     D64_CHR_FLOOR_HEIGHTS_PTR
        sty     D64_CHR_FLOOR_HEIGHTS_PTR+1
        jmp     chr_hbuf_fill_room
.endproc
.endif

; 2899 sys_tick: the 300 Hz interrupt handler's body (on the C64 the platform's IRQ entry calls it): DI; the tick
; counter [289C] + 1, kept at FFh; the sound (0CD0); txt_phrase_tick; EI.  A and the flags are kept (the Z80's
; PUSH AF / POP AF); the other registers are kept by the callees (c64/juego_personajes/NOTAS.md), X and Y too.
; The tests that find nothing to do, the common case, are made here inline: snd_interrupt's (no channel
; playing: state bit 0) and txt_phrase_tick's (its tick counter + 1 is not 2Dh); their bodies (s_interrupcion,
; t_frase) run only when there is work.  In the checked build (-D PRUEBA) A and the flags are kept here and the
; EI is the platform's mirror (the IFF the host compares; the DIs inside the handler, IFF already 0 there, are
; left out); on the C64 the interrupt's entry keeps A (plat_irq) and the flags (RTI), and the I flag is set
; from the entry to the RTI but for t_frase's character: after its beep starts, a CLI as the Z80's EI there
; (snd_start's), so a tick that falls due while the character is drawn (up to ~3 ticks) comes nested at once:
; its sys_tick keeps X and Y, the sound keeps its zero page, and the counter t_frase cleared first keeps it from
; coming again for 2Dh ticks.
.ifndef JUEGO                           ; (the game: inline in plat_irq, -D JUEGO)
.proc sys_tick
.ifdef PRUEBA
        php
        pha
.endif
        inc     D64_SYS_TICKS
        bne     :+
        dec     D64_SYS_TICKS
:       lda     s_estado_a              ; 0CD0's test: a channel playing
        ora     s_estado_b
        ora     s_estado_c
        lsr
        bcc     :+
        jsr     s_interrupcion
:       inc     D64_TXT_SCROLL_TIMER    ; 368A's test: the scroller's 2Dh-th tick
        lda     D64_TXT_SCROLL_TIMER
        cmp     #$2D
        bne     :+
        jsr     t_frase
:
.ifdef PRUEBA
        jsr     plat_ei
        pla
        plp
.endif
        rts
.endproc
.endif

; ================================================================== the keyboard

; 2D50 sys_read_keyboard: the 10 rows of the keyboard matrix (plat_teclado_fila) into the keys-down bitmap 2DE8
; (0 = down), and the pending presses 2DF2 = (pending & ~(now | before)) | now (a bit goes to 0 on a new press
; and stays 0 until sys_key_pressed consumes it).  Returns with the interrupts off (DI; the caller does EI).
.proc sys_read_keyboard
        jsr     plat_di
        ldx     #0
loop:   txa
        jsr     plat_teclado_fila
        sta     zt0
        ora     D64_SYS_KEYS_DOWN,x
        eor     #$FF
        and     D64_SYS_KEYS_PENDING,x
        ora     zt0
        sta     D64_SYS_KEYS_PENDING,x
        lda     zt0
        sta     D64_SYS_KEYS_DOWN,x
        inx
        cpx     #10
        bne     loop
.ifdef VELOZ
        lda     #$80                    ; (the key queries' summary: not known yet this frame)
        sta     kb_est
.endif
        rts
.endproc

; 2E98 sys_key_bit: DE = bitmap + key / 8, HL = 2EB3 + key % 8 (the bit masks); A = ~[DE] & [HL] (not 0: the key
; is down / has a pending press), Z, C flag clear.  In: A = key, DE = bitmap.  Out: A, C = key, DE, HL.
.proc sys_key_bit
        sta     zbc
        lsr
        lsr
        lsr
        clc
        adc     zde
        sta     zde
        bcc     :+
        inc     zde+1
:       lda     zbc
        and     #7
        tax
        ora     #<D64_SYS_BIT_MASKS
        sta     zhl
        lda     #>D64_SYS_BIT_MASKS
        sta     zhl+1
        ldy     #0
        lda     (zde),y
        eor     #$FF
        and     D64_SYS_BIT_MASKS,x
        clc
        rts
.endproc

; 2E42 sys_test_key: is the CPC key A down in the bitmap DE?  Keys 8 (left), 2Fh (space), 0, 1, 2 (up, right,
; down) also accept their aliases (lists ending in FF at 2E2E, 2E32, 2E36 + 4k); any other key is tried alone
; (2E2C = key, FF).  Writes [2E6A] (the bitmap) and [2E2C].  Out: A = the nonzero bit of the first code found, or
; 0 (Z); C flag clear; C, DE, HL = sys_key_bit's of that code, or of the last one tried.
.proc sys_test_key
        ldx     zde
        stx     D64_SYS_KEY_BITMAP
        ldx     zde+1
        stx     D64_SYS_KEY_BITMAP+1
        sta     D64_SYS_KEY_SINGLE
        ldy     #>D64_SYS_KEY_ALIAS_LEFT ; the alias lists share a page
        ldx     #<D64_SYS_KEY_ALIAS_LEFT
        cmp     #8
        beq     set
        ldx     #<D64_SYS_KEY_ALIAS_SPACE
        cmp     #$2F
        beq     set
        cmp     #3
        bcs     single
        asl
        asl
        adc     #<D64_SYS_KEY_ALIAS_012 ; (C clear)
        tax
        bcc     set
single: ldx     #<D64_SYS_KEY_SINGLE
        ldy     #>D64_SYS_KEY_SINGLE
set:    stx     pkl
        sty     pkl+1
loop:   ldy     #0
        lda     (pkl),y
        inc     pkl
        bne     :+
        inc     pkl+1
:       ldx     D64_SYS_KEY_BITMAP
        stx     zde
        ldx     D64_SYS_KEY_BITMAP+1
        stx     zde+1
        jsr     sys_key_bit
        bne     found
        ldy     #0
        lda     (pkl),y
        cmp     #$FF
        bcc     loop
        lda     #0
        clc
found:  rts
.endproc

; 2E7D sys_key_pressed: edge test: not 0 (NZ) when key A has a pending press in 2DF2; the pending bit of the code
; tested last is set (the press is consumed).  2E8D sys_key_down: level test in 2DE8.  Out: A, Z, C flag clear,
.ifdef VELOZ
; C = the code tested last; HL, DE kept.  The list walk of sys_test_key and the bit test of sys_key_bit are made
; here inline without touching DE and HL (so nothing is saved on the stack); what the Z80 writes is written the
; same: [2E6A] = the bitmap (D64_SYS_KEY_BITMAP), [2E2C] = the key (D64_SYS_KEY_SINGLE) and, for a pressed test,
; the pending bit of the code tested last.  A single key (no alias list) is tested from the FFh that ends the
; left list (D64_SYS_KEY_ALIAS_LEFT + 3, its 4th byte: juego/datos_personajes.h).  sys_test_key and sys_key_bit
; stay as they are for the checks.  X = A, Y = 4 and the flags at the exit are as before.
.else
; C = the code tested last; HL, DE kept.
.endif
.proc sys_key_pressed
        ldx     #<D64_SYS_KEYS_PENDING
        .byte   $2C                     ; BIT abs: skips the next LDX
.endproc
.ifdef VELOZ
.proc sys_key_down
        ldx     #<D64_SYS_KEYS_DOWN
.ifdef VELOZ
        bit     kb_est                  ; abadia128ks (optimised for speed): while nothing is
        bpl     :+                      ; down nor pending this frame (bit 6), the answer at once with the same effects
        jsr     kb_mira
:       bvc     :+
        jmp     kb_nada
:
.endif
        stx     pkflag
        stx     bitmap+1                ; the bitmap read below (its low byte: the two share a page, .assert)
        stx     D64_SYS_KEY_BITMAP      ; the Z80's [2E6A] = DE
        ldx     #>D64_SYS_KEYS_DOWN
        stx     D64_SYS_KEY_BITMAP+1
        sta     D64_SYS_KEY_SINGLE      ; the Z80's [2E2C] = the key
        ldx     #<D64_SYS_KEY_ALIAS_LEFT ; X = the list, in the lists' page
        cmp     #8
        beq     list
        ldx     #<D64_SYS_KEY_ALIAS_SPACE
        cmp     #$2F
        beq     list
        cmp     #3
        bcs     one
        asl
        asl
        adc     #<D64_SYS_KEY_ALIAS_012 ; (C clear)
        tax
list:   lda     PKLISTS,x               ; the next code of the list
code:   sta     zbc                     ; C = the code tested last
        stx     pkl                     ; its place in the list
        and     #7
        tay                             ; Y = its bit
        lda     zbc
        lsr
        lsr
        lsr
        tax                             ; X = its row
bitmap: lda     D64_SYS_KEYS_DOWN,x     ; (the low byte of the operand is the bitmap chosen above)
        eor     #$FF
        and     D64_SYS_BIT_MASKS,y
        bne     found
        ldx     pkl
        inx
        lda     PKLISTS,x
        cmp     #$FF                    ; FFh ends the list
        bcc     code
        lda     zbc                     ; not found: X = the row of the code tested last (for the consume)
        lsr
        lsr
        lsr
        tax
        lda     #0
found:  pha
        lda     pkflag
        cmp     #<D64_SYS_KEYS_DOWN
        beq     :+
        lda     D64_SYS_KEYS_PENDING,x  ; consume: the pending bit of the code tested last
        ora     D64_SYS_BIT_MASKS,y
        sta     D64_SYS_KEYS_PENDING,x
:       pla
        ldy     #4
        tax                             ; (X = A, Y = 4, V clear and N/Z from A, as before)
        clv
        clc
        rts
one:    ldx     #<D64_SYS_KEY_ALIAS_LEFT+2 ; a single key: the next byte is the FFh that ends the left list
        jmp     code
.endproc
        .assert >D64_SYS_KEYS_DOWN = >(D64_SYS_KEYS_PENDING + 9), error, "sys_key_down: the bitmaps in one page"
        .assert >D64_SYS_KEY_ALIAS_LEFT = >(D64_SYS_KEY_ALIAS_012 + 11), error, "sys_key_down: the lists in one page"
.else
.proc sys_key_down
        ldx     #<D64_SYS_KEYS_DOWN
.ifdef VELOZ
        bit     kb_est                  ; abadia128ks (optimised for speed): while nothing is
        bpl     :+                      ; down nor pending this frame (bit 6), the answer at once with the same effects
        jsr     kb_mira
:       bvc     :+
        jmp     kb_nada
:
.endif
        stx     pkflag
        tay
        ldx     #3                      ; DE, HL kept on the stack
:       lda     zde,x
        pha
        dex
        bpl     :-
        lda     pkflag
        sta     zde
        lda     #>D64_SYS_KEYS_DOWN
        sta     zde+1
        tya
        jsr     sys_test_key
        tax
        lda     pkflag
        cmp     #<D64_SYS_KEYS_DOWN
        beq     :+
        ldy     #0                      ; consume: [DE] |= [HL]
        lda     (zde),y
        ora     (zhl),y
        sta     (zde),y
:       ldy     #0
:       pla
        sta     zde,y
        iny
        cpy     #4
        bne     :-
        txa
        clc
        rts
.endproc
        .assert zhl = zde + 2, error, "sys_key_down: DE, HL contiguous"
.endif

.ifdef VELOZ
.ifdef VELOZ
; abadia128ks: the key queries when nothing is down nor pending (the CPC's game asks ~20 keys a frame): kb_est, the
; frame's summary of the two bitmaps (sys_read_keyboard: $80 not known; kb_mira, at the frame's first query, so that
; the keys the project's VICE tests write right after sys_read_keyboard count: $40 the 20 bytes all FFh, else 0;
; sys_key_pressed only sets bits, so a clean frame stays clean).  kb_nada: what sys_key_down / sys_key_pressed leave
; then: [2E6A] = the bitmap, [2E2C] = the key, C (zbc) = the code tested last (its alias list's last), nothing
; consumed (the bits are set), A = 0, Z, C and V clear, X = 0, Y = 4; DE, HL kept.
.proc kb_mira
        pha
        lda     #$FF
        ldy     #9
:       and     D64_SYS_KEYS_DOWN,y
        and     D64_SYS_KEYS_PENDING,y
        dey
        bpl     :-
        cmp     #$FF
        lda     #0
        bcc     :+
        lda     #$40
:       sta     kb_est
        pla
        bit     kb_est
        rts
.endproc
.proc kb_nada
        stx     D64_SYS_KEY_BITMAP
        ldy     #>D64_SYS_KEYS_DOWN
        sty     D64_SYS_KEY_BITMAP+1
        sta     D64_SYS_KEY_SINGLE
        sta     zbc
        ldx     #<D64_SYS_KEY_ALIAS_LEFT
        cmp     #8
        beq     lista
        ldx     #<D64_SYS_KEY_ALIAS_SPACE
        cmp     #$2F
        beq     lista
        cmp     #3
        bcs     fin                     ; (alone: it is the code tested last)
        asl
        asl
        adc     #<D64_SYS_KEY_ALIAS_012 ; (C clear)
        tax
lista:  lda     D64_SYS_KEY_ALIAS_LEFT & $FF00,x   ; (the lists share a page: sys_test_key)
        cmp     #$FF
        beq     fin
        sta     zbc
        inx
        bne     lista
fin:    ldy     #4
        lda     #0
        tax
        clv
        clc
        rts
.endproc
.segment "BSS"
kb_est: .res    1
.segment "CODE"
.endif
.else
.ifdef VELOZ
; abadia128ks: the key queries when nothing is down nor pending (the CPC's game asks ~20 keys a frame): kb_est, the
; frame's summary of the two bitmaps (sys_read_keyboard: $80 not known; kb_mira, at the frame's first query, so that
; the keys the project's VICE tests write right after sys_read_keyboard count: $40 the 20 bytes all FFh, else 0;
; sys_key_pressed only sets bits, so a clean frame stays clean).  kb_nada: what sys_key_down / sys_key_pressed leave
; then: [2E6A] = the bitmap, [2E2C] = the key, C (zbc) = the code tested last (its alias list's last), nothing
; consumed (the bits are set), A = 0, Z, C flag clear, X = 0, Y = 4; DE, HL kept.
.proc kb_mira
        pha
        lda     #$FF
        ldy     #9
:       and     D64_SYS_KEYS_DOWN,y
        and     D64_SYS_KEYS_PENDING,y
        dey
        bpl     :-
        cmp     #$FF
        lda     #0
        bcc     :+
        lda     #$40
:       sta     kb_est
        pla
        bit     kb_est
        rts
.endproc
.proc kb_nada
        stx     D64_SYS_KEY_BITMAP
        ldy     #>D64_SYS_KEYS_DOWN
        sty     D64_SYS_KEY_BITMAP+1
        sta     D64_SYS_KEY_SINGLE
        sta     zbc
        ldx     #<D64_SYS_KEY_ALIAS_LEFT
        cmp     #8
        beq     lista
        ldx     #<D64_SYS_KEY_ALIAS_SPACE
        cmp     #$2F
        beq     lista
        cmp     #3
        bcs     fin                     ; (alone: it is the code tested last)
        asl
        asl
        adc     #<D64_SYS_KEY_ALIAS_012 ; (C clear)
        tax
lista:  lda     D64_SYS_KEY_ALIAS_LEFT & $FF00,x   ; (the lists share a page: sys_test_key)
        cmp     #$FF
        beq     fin
        sta     zbc
        inx
        bne     lista
fin:    ldy     #4
        lda     #0
        tax
        clc
        rts
.endproc
.segment "BSS"
kb_est: .res    1
.segment "CODE"
.endif
.endif

; ================================================================== the input step and the mirror

; 2DFC game_check_qr_mirror: E = 0 unless Guillermo stands at x = 22h, height 1Ah with the keys Q (43h) and R
; (32h) down; then 1, 2, 3 for y = 6Dh, 69h, 65h (the three steps), 0 for any other y.  IX = 2B87.
.proc game_check_qr_mirror
        lda     #0
        sta     zde
        lda     #<D64_CHR_GUILLERMO
        sta     zix
        lda     #>D64_CHR_GUILLERMO
        sta     zix+1
        lda     D64_CHR_GUILLERMO+2
        cmp     #$22
        bne     ret
        lda     D64_CHR_GUILLERMO+4
        cmp     #$1A
        bne     ret
        lda     #$43
        jsr     sys_key_down
        beq     ret
        lda     #$32
        jsr     sys_key_down
        beq     ret
        lda     D64_CHR_GUILLERMO+3
        ldx     #3
:       cmp     steps-1,x
        beq     set
        dex
        bne     :-
set:    stx     zde
ret:    rts
steps:  .byte   $6D, $69, $65
.endproc

; 2D99 game_input_and_mirror: the input step of the main loop: sys_read_keyboard, EI.  While the mirror is closed
; ([28DD]): game_check_qr_mirror; with Q+R down on a step: a numeral [290D] other than 4 sets bit 2 of [2910];
; the numeral = the step opens the mirror (FF at [[2EDE]], 51h at [[2EE5]], between DI and EI); numeral 4 or
; another step is the trap ([37E4] = 1, [23E4] = 14h, 6Bh two bytes before [[2EE5]], hud_say_now with its
; inline phrase 22h).  Both: [28C6] = 0 (the room is rebuilt), [28DD] = 0, snd_play_mirror_open (0C6D).
.proc game_input_and_mirror
        jsr     sys_read_keyboard
        jsr     plat_ei
        lda     D64_OBJ_MIRROR_CLOSED
        beq     ret
        jsr     game_check_qr_mirror
        lda     zde
        beq     ret
.ifdef COMPLETO
        lda     #0                      ; abadia128ks, the full game: Q+R on a step ends the hour (PC 1000:2DD8
        sta     D64_AI_HOUR_FRAMES_LEFT ; ai_hour_frames_left := 0; the 64 KiB game has no equivalent)
        sta     D64_AI_HOUR_FRAMES_LEFT+1
.endif
        lda     D64_OBJ_MIRROR_NUMERAL
        cmp     #4
        beq     trap
        tax
        lda     D64_GAME_BONUS
        ora     #4
        sta     D64_GAME_BONUS
        cpx     zde
        beq     open
trap:   lda     #1
        sta     D64_GAME_GUILLERMO_DEAD
        lda     #$14
        sta     D64_CHR_GUILLERMO_STATE
        jsr     personajes_mirror_entry
        lda     #$6B
        PON_SALA
        jsr     hud_say_now
        .byte   $22
        jmp     fin
open:   jsr     plat_di
        lda     D64_OBJ_MIRROR_HEIGHT_PTR
        sta     zhl
        lda     D64_OBJ_MIRROR_HEIGHT_PTR+1
        sta     zhl+1
        ldy     #0
        lda     #$FF
        sta     (zhl),y
        jsr     personajes_mirror_entry
        ldy     #2
        lda     #$51
        PON_SALA
        jsr     plat_ei
fin:    lda     #0
        sta     D64_CHR_ROOM_X
        sta     D64_OBJ_MIRROR_CLOSED
        jmp     snd_play_mirror_open
ret:    rts
.endproc

; 2EBB obj_init_mirror: start of a game: [28DD] = 1 (the mirror is closed), [290D] = 0 (no numeral yet), then
; obj_close_mirror (falls into it).
.proc obj_init_mirror
        lda     #1
        sta     D64_OBJ_MIRROR_CLOSED
        lda     #0
        sta     D64_OBJ_MIRROR_NUMERAL
        ; falls into obj_close_mirror
.endproc

; 2EC4 obj_close_mirror: between DI and EI, the 5 'mirror closed' height bytes 2EE0 to [2EDE]; 11h into the
; mirror's entry [2EE5] and 1Fh two bytes before it.  Out: A = 1Fh, BC = 0, HL = [2EE5] - 2 (the Z80's DE =
; [2EDE] + 5 is not reproduced: it is one past the heights block, and no caller reads it).
.proc obj_close_mirror
        jsr     plat_di
        lda     D64_OBJ_MIRROR_HEIGHT_PTR
        sta     zde
        lda     D64_OBJ_MIRROR_HEIGHT_PTR+1
        sta     zde+1
        ldy     #4
:       lda     D64_OBJ_MIRROR_CLOSED_HEIGHTS,y
        sta     (zde),y
        dey
        bpl     :-
        jsr     personajes_mirror_entry
        sty     zbc
        sty     zbc+1
        lda     #$1F
        PON_SALA
        ldy     #2
        lda     #$11
        PON_SALA
        lda     #$1F
        jmp     plat_ei
.endproc

; HL = [2EE5] - 2 (two bytes before the mirror's entry in the room data), Y = 0
.proc personajes_mirror_entry
        lda     D64_OBJ_MIRROR_ENTRY_PTR
        sec
        sbc     #2
        sta     zhl
        lda     D64_OBJ_MIRROR_ENTRY_PTR+1
        sbc     #0
        sta     zhl+1
        ldy     #0
        rts
.endproc

; ================================================================== the sprite flips

; 2EE7 spr_flip_adso: toggles Adso's flip state [2B9C] and mirrors his 5-wide (5Fh lines) and 4-wide (5Ah)
; frames.  2F40 spr_flip_guillermo: [2B8D], the 5-wide (AEh lines) and 4-wide (21h) frames.
.proc spr_flip_adso
        lda     D64_CHR_ADSO+6
        eor     #1
        sta     D64_CHR_ADSO+6
        ldx     #8
        bne     personajes_flip2
.endproc

.proc spr_flip_guillermo
        lda     D64_CHR_GUILLERMO+6
        eor     #1
        sta     D64_CHR_GUILLERMO+6
        ldx     #0
        ; falls into personajes_flip2
.endproc

; the two flips of the entries X and X + 4 of personajes_flips
.proc personajes_flip2
.ifdef C128
        jsr     cab_gira_pers           ; the C128: the heads' black follows the frames (cabezas128.s; X kept)
.endif
        jsr     personajes_flip1
        ; falls into personajes_flip1
.endproc
.proc personajes_flip1
        lda     personajes_flips,x
        sta     zhl
        lda     personajes_flips+1,x
        sta     zhl+1
        lda     personajes_flips+2,x
        sta     zbc
        lda     personajes_flips+3,x
        sta     zbc+1
        txa
        pha
        jsr     spr_flip_graphics_h
        pla
        clc
        adc     #4
        tax
        rts
.endproc

personajes_flips:                       ; graphics, width (CPC bytes), lines
        .word   GFX_GUILLERMO_W5
        .byte   5, $AE
        .word   GFX_GUILLERMO_W4
        .byte   4, $21
        .word   GFX_ADSO_W5
        .byte   5, $5F
        .word   GFX_ADSO_W4
        .byte   4, $5A

; 2F00 spr_flip_malachi, 2F10 spr_flip_abbot, 2F20 spr_flip_berengar, 2F30 spr_flip_severin: the flip state
; [record + 6] ^= 1 and the face [2BE8 + 2k] (5 bytes x 14h lines: the face and the second face) mirrored.
.proc spr_flip_malachi
        ldy     #D64_CHR_MALACHI - D64_CHR_MALACHI
        ldx     #0
        beq     personajes_flip_monk
.endproc
.proc spr_flip_abbot
        ldy     #D64_CHR_ABBOT - D64_CHR_MALACHI
        ldx     #2
        bne     personajes_flip_monk
.endproc
.proc spr_flip_berengar
        ldy     #D64_CHR_BERENGAR - D64_CHR_MALACHI
        ldx     #4
        bne     personajes_flip_monk
.endproc
.proc spr_flip_severin
        ldy     #D64_CHR_SEVERIN - D64_CHR_MALACHI
        ldx     #6
        ; falls into personajes_flip_monk
.endproc
.proc personajes_flip_monk
        lda     D64_CHR_MALACHI+6,y
        eor     #1
        sta     D64_CHR_MALACHI+6,y
.ifdef C128
        jsr     cab_gira_cara           ; (the face block of slot X)
.endif
        lda     D64_SPR_MONK_FACES,x
        sta     zhl
        lda     D64_SPR_MONK_FACES+1,x
        sta     zhl+1
        lda     #5
        sta     zbc
        lda     #$14
        sta     zbc+1
        ; falls into spr_flip_graphics_h
.endproc

; 2F57 spr_flip_graphics_h: mirrors in place B lines (0 = 256) of a graphic HL in the C64 sprite format, C CPC
; bytes (= nibbles) wide: ceil(C/2) bytes a line, an odd width's last low nibble is padding.  Every line's
; nibbles are reversed, each through espejo_nibble (its two pixels swapped), the padding staying last; this is
; exactly the conversion of the CPC graphic flipped by the Z80 (the "sim" rule, c64/NOTAS_GRAFICOS.md).  The
; width is kept in [2FA3] as the Z80 does.  The faces and the door lie under the I/O: switched off meanwhile
; ($01 = $34; the caller's $01 comes back at the end).
; The Z80's registers at the exit (it returns with the banks exchanged) are not reproduced: no caller uses them.
.proc spr_flip_graphics_h
bpl_    = zt0                           ; bytes a line
lines   = zt0+1
prev    = zt0+2
pad     = zt0+3
cur     = zt0+4
tmp     = zt0+5
        lda     zbc
        sta     D64_SPR_FLIP_WIDTH
        lda     #0
        sta     D64_SPR_FLIP_WIDTH+1
        lda     MEMCFG                     ; the memory configuration as the caller left it
        pha
        lda     #MEM_RAM
        sta     MEMCFG
        lda     zbc
        clc
        adc     #1
        ror
        sta     bpl_
        lda     zbc+1
        sta     lines
line:   ldy     #0                      ; the line's bytes mirrored onto the stack
push:   lda     (zhl),y
        tax
        lda     ESPEJO_NIBBLE,x
        pha
        iny
        cpy     bpl_
        bne     push
        ldy     #0
        lda     zbc
        lsr
        bcs     odd
even:   pla                             ; new byte k = old byte bpl-1-k, its 4 pixels reversed
        asl                             ; (espejo_nibble with the nibbles swapped)
        adc     #$80
        rol
        asl
        adc     #$80
        rol
        sta     (zhl),y
        iny
        cpy     bpl_
        bne     even
        beq     next
odd:    pla                             ; new byte k = high nibble of E(old byte bpl-1-k) | low nibble of
        sta     prev                    ; E(old byte bpl-2-k); the last: high nibble of E(old byte 0) | padding
        and     #$0F
        sta     pad
        ldx     bpl_
        dex
        beq     lastb
mid:    pla
        sta     cur
        and     #$0F
        sta     tmp
        lda     prev
        and     #$F0
        ora     tmp
        sta     (zhl),y
        iny
        lda     cur
        sta     prev
        dex
        bne     mid
lastb:  lda     prev
        and     #$F0
        ora     pad
        sta     (zhl),y
next:   lda     zhl
        clc
        adc     bpl_
        sta     zhl
        bcc     :+
        inc     zhl+1
:       dec     lines
        bne     line
        pla
        sta     MEMCFG
        rts
.endproc
