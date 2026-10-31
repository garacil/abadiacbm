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

; abadia64ks, 6502 code of the game: group logica_a, part 1 (Z80 3AAF-3F72, 4477, 4B43-4C45; C reference
; juego/f_logica_a.c): the spiral wipe, the scripted placements of objects and characters, the camera and the
; frame speed, the lamp and night timers, the percentage and the bonus, Malaquias rising, Guillermo's place at
; the ceremonies, the parchment test, the score-bar phrases, the inline texts and the inventory.
; Registers as the Z80 functions (c64/CODIGO6502.md); the results each routine must leave: resultados.tsv.
        .include "logica_a.inc"
        .include "plataforma.inc"

        .export vid_spiral_wipe, vid_spiral_pass, vid_spiral_put
        .export obj_lamp_reset, obj_malachi_leaves_key3, obj_remove_glasses, chr_bernardo_arrives
        .export chr_jorge_appears, chr_berengar_vanishes, chr_berengar_hooded, util_store_dx_at_bx
        .export obj_jorge_drops_book, obj_abbot_drops_parchment, obj_abbot_wants_parchment
        .export obj_place_parchment, obj_place_parchment_unused, obj_book_to_jorge, obj_place_lamp
        .export obj_place_key1, obj_remove_key1, obj_place_key3, obj_place_glasses, obj_remove_key1_unused
        .export game_idle_camera_check, ai_jorge_book_talk_with_gloves, game_camera_select
        .export game_speed_default, game_speed_set, util_return_zero, game_set_c004_inline
        .export game_camera_from_ch_unused, game_camera_update, ai_lamp_tick, ai_night_end_tick
        .export obj_jorge_takes_book, game_compute_percentage, game_update_bonus_and_poison
        .export ai_stop_hour_countdown, ai_malaquias_rise, ai_check_guillermo_at_mass
        .export ai_check_guillermo_at_refectory, ai_check_guillermo_at, ai_parchment_check
        .export util_delay_cx, util_ret_530a, txt_print_inline, hud_clear_phrase_area, hud_say_now, hud_say
        .export txt_skip_strings, hud_blink_yes_no, obj_play_inventory_sound, obj_update_inventory
        .export la_copy5

        .import la_fila_lo, la_fila_hi
        .import util_add_bx_al, iso_floor_base
        .import spr_unflip_monk_faces, hud_draw_guillermo_objects, hud_draw_objects, obj_drop_object
        .import vid_fill_play_area_ff, game_update_camera_and_bonus, sys_key_down, snd_play_music_if_idle
        .import txt_draw_char_inverted, snd_play_object_dropped, snd_play_object_taken
        .import obj_pick_up_objects, obj_drop_on_space, obj_update_key_permissions, obj_read_manuscript
        .import plat_di, plat_ei

OBJ   = D64_OBJ_OBJECTS                 ; the object records (5 bytes): 2B59h
CARAS = G_CARAS                         ; the monks' faces, 7 blocks of 2 x 10 lines of 3 bytes (60 bytes)

.segment "CODE"

; ==== 3AAF-3B3A: the spiral wipe =======================================================================

; 3AAF vid_spiral_wipe: two spiral passes (bytes alternating 00/FF, then all 00), then chr_room_x := 0 (the
; room is drawn again).  Out: A = 0 (ZF = 1, CF = 0), E = 0, B = 0, HL = the last position; C, D, IX, IY kept.
.proc vid_spiral_wipe
        lda     zix
        pha
        lda     zix+1
        pha
        lda     #$FF
        sta     zde
        jsr     vid_spiral_pass
        lda     #0
        sta     zde
        jsr     vid_spiral_pass
        pla
        sta     zix+1
        pla
        sta     zix
        lda     #0
        sta     D64_CHR_ROOM_X
        clc
        rts
.endproc

; 3AC3 vid_spiral_pass: a square spiral of bytes over the play area from (0,0) inwards: 20h turns right,
; down (2 lines a step), left, up, the side lengths in vid_spiral_sides (3F 4F 3F 4E, each 2 shorter a turn, the
; first one 1 on the first turn; a count 0 would be 256); the byte starts at 0 and is XORed with E after each
; turn (E = FFh or 0: the byte is 00h or FFh); one last byte at the end.  The bitmap address and nibble move with
; the position (la_q, la_t+3).  In: E.  Out: HL = the last position (H = line, L = byte), A = 0 (ZF), B = 0,
; IX = vid_spiral_sides; C, DE kept.
.proc vid_spiral_pass
        lda     #0
        sta     zhl
        sta     zhl+1
        ldx     #3
:       lda     lados,x
        sta     D64_VID_SPIRAL_SIDES,x
        dex
        bpl     :-
        lda     #<D64_VID_SPIRAL_SIDES
        sta     zix
        lda     #>D64_VID_SPIRAL_SIDES
        sta     zix+1
        lda     #$55                    ; the byte 00h: pen 0
        sta     la_t+2
        jsr     la_espiral_dir
        lda     #$20
        sta     zbc+1                   ; B: the turns
vuelta: ldx     #0                      ; right (the first side 1 shorter on the first turn)
        jsr     cuenta
        lda     zbc+1
        cmp     #$20
        beq     :+
        dec     D64_VID_SPIRAL_SIDES
:       jsr     la_espiral_pon
        inc     zhl
        lda     la_t+3                  ; the next nibble; past the low one, the next byte column
        eor     #$FF
        sta     la_t+3
        bpl     :+
        lda     #8
        jsr     mas
:       dec     la_t+1
        bne     :--
        ldx     #1                      ; down, 2 lines a step
        jsr     cuenta2
:       jsr     la_espiral_pon
        inc     zhl+1
        inc     zhl+1
        lda     #2
        ldx     #0
        jsr     linea
        bne     :+
        lda     #<(320 - 8)             ; into the next cell row (+ 320 - 6 in all)
        ldx     #>(320 - 8)
        jsr     mas16
:       dec     la_t+1
        bne     :--
        ldx     #2                      ; left
        jsr     cuenta2
:       jsr     la_espiral_pon
        dec     zhl
        lda     la_t+3
        eor     #$FF
        sta     la_t+3
        bmi     :+
        lda     #<-8
        ldx     #$FF
        jsr     mas16
:       dec     la_t+1
        bne     :--
        ldx     #3                      ; up
        jsr     cuenta2
:       jsr     la_espiral_pon
        lda     zhl+1
        and     #7
        php
        dec     zhl+1
        dec     zhl+1
        lda     #<-2
        ldx     #$FF
        plp
        bne     :+
        lda     #<(6 - 320)             ; into the previous cell row
        ldx     #>(6 - 320)
:       jsr     mas16
        dec     la_t+1
        bne     :--
        lda     zde                     ; the byte XOR E: 00h <-> FFh when E = FFh
        and     #$55
        eor     la_t+2
        sta     la_t+2
        dec     zbc+1
        beq     :+
        jmp     vuelta
:       jsr     la_espiral_pon
        lda     #0
        rts
cuenta2:
        jsr     cuenta
        dec     D64_VID_SPIRAL_SIDES,x
        rts
cuenta: lda     D64_VID_SPIRAL_SIDES,x  ; the count, the side 1 shorter
        sta     la_t+1
        dec     D64_VID_SPIRAL_SIDES,x
        rts
linea:  jsr     mas16                   ; + XA, then ZF when the new line is the first of a cell
        lda     zhl+1
        and     #7
        rts
mas:    ldx     #0
mas16:  clc                             ; la_q += XA
        adc     la_q
        sta     la_q
        txa
        adc     la_q+1
        sta     la_q+1
        lda     #1                      ; (ZF clear)
        rts
lados:  .byte   $3F, $4F, $3F, $4E
.endproc

; la_q := the bitmap address of line H, byte column L; la_t+3 := the nibble written ($F0 for an even L)
.proc la_espiral_dir
        lda     zhl+1                   ; the cell row
        lsr
        lsr
        lsr
        tax
        lda     zhl                     ; 8 (x / 2) + (y & 7)
        and     #$FE
        asl
        asl
        sta     zt0
        lda     zhl+1
        and     #7
        ora     zt0
        clc
        adc     la_fila_lo,x
        sta     la_q
        lda     la_fila_hi,x
        adc     #0
        sta     la_q+1
        lda     zhl
        lsr
        lda     #$F0
        bcc     :+
        lda     #$0F
:       sta     la_t+3
        rts
.endproc

; the byte la_t+2 into the nibble la_t+3 of lines (la_q),0 and (la_q),1 (an even line: the same cell);
; la_espiral_uno: only (la_q),Y
.proc la_espiral_pon
        ldy     #1
        lda     (la_q),y
        eor     la_t+2
        and     la_t+3
        eor     (la_q),y
        sta     (la_q),y
        dey
.endproc
.proc la_espiral_uno
        lda     (la_q),y
        eor     la_t+2
        and     la_t+3
        eor     (la_q),y
        sta     (la_q),y
        rts
.endproc

; 3B2A vid_spiral_put: the CPC byte A (00h or FFh: C64 nibble 5 or 0) at byte column L of the lines H and H + 1
; of the play area (the C64 bitmap, cells 4-35).  A, X, Y and the zero-page pairs kept.
.proc vid_spiral_put
        pha
        tya
        pha
        txa
        pha
        tsx
        lda     $0103,x                 ; 00h -> 55h (pen 0), FFh -> 00h (pen 3)
        cmp     #1
        lda     #$55
        bcc     :+
        lda     #0
:       sta     la_t+2
        jsr     la_espiral_dir
        ldy     #0
        jsr     la_espiral_uno
        lda     zhl+1                   ; line 7 of a cell: H + 1 is line 0 of the next cell row
        and     #7
        cmp     #7
        bne     :+
        lda     #<(320 - 8)
        ldx     #>(320 - 8)
        jsr     vid_spiral_pass::mas16
:       ldy     #1
        jsr     la_espiral_uno
        pla
        tax
        pla
        tay
        pla
        rts
.endproc

; ==== 3B3B-3C8E, 3D87: scripted placements of objects and characters ===================================

; 3C84 util_copy5_inline_ds: `JSR la_copy5`, a word (the destination), 5 bytes: the bytes copied there; the
; return goes to the caller's caller (the return address is dropped), as the Z80 one does.
.proc la_copy5
        pla
        clc
        adc     #1
        sta     zt0
        pla
        adc     #0
        sta     zt0+1                   ; zt0 = the inline word
        ldy     #0
        lda     (zt0),y
        sta     zt0+2
        iny
        lda     (zt0),y
        sta     zt0+3
        lda     zt0
        clc
        adc     #2
        sta     zt0
        bcc     :+
        inc     zt0+1
:       ldy     #4
:       lda     (zt0),y
        sta     (zt0+2),y
        dey
        bpl     :-
        rts
.endproc

; 3B3B obj_lamp_reset: when Malaquias' holder has the lamp or the lamp time runs: the lamp is reset (placed flag,
; time, in use, bit 7 of the Adso and Malaquias holders) and its record 2B81 cleared.
.proc obj_lamp_reset
        lda     D64_OBJ_MALACHI_HOLDER
        and     #$80
        ora     D64_AI_LAMP_TIME
        ora     D64_AI_LAMP_TIME+1
        bne     :+
        rts
:       lda     #0
        sta     D64_OBJ_LAMP_PLACED
        sta     D64_AI_LAMP_TIME
        sta     D64_AI_LAMP_TIME+1
        sta     D64_AI_LAMP_IN_USE
        lda     D64_GAME_ADSO_LAMP
        and     #$7F
        sta     D64_GAME_ADSO_LAMP
        lda     D64_OBJ_MALACHI_HOLDER
        and     #$7F
        sta     D64_OBJ_MALACHI_HOLDER
        jsr     la_copy5
        .word   OBJ + $28
        .byte   $00, $00, $00, $00, $00
.endproc

; 3B66 obj_malachi_leaves_key3: Malaquias loses key 3 (bit 1), which goes back on the table (record 2B77).
.proc obj_malachi_leaves_key3
        lda     D64_OBJ_MALACHI_OBJECTS
        and     #$02
        bne     :+
        rts
:       lda     D64_OBJ_MALACHI_OBJECTS
        and     #$FD
        sta     D64_OBJ_MALACHI_OBJECTS
        jsr     la_copy5
        .word   OBJ + $1E
        .byte   $00, $00, $35, $35, $13
.endproc

; 3B7B obj_remove_glasses: Guillermo and the Berengario slot lose the glasses (bit 5), the score bar is redrawn
; (4D2A, IX kept), the glasses record 2B63 cleared.
.proc obj_remove_glasses
        lda     D64_B2_GUILLERMO_OBJECTS
        and     #$DF
        sta     D64_B2_GUILLERMO_OBJECTS
        lda     D64_OBJ_BERENGAR_OBJECTS
        and     #$DF
        sta     D64_OBJ_BERENGAR_OBJECTS
        lda     zix
        pha
        lda     zix+1
        pha
        jsr     hud_draw_guillermo_objects
        pla
        sta     zix+1
        pla
        sta     zix
        jsr     la_copy5
        .word   OBJ + $0A
        .byte   $00, $00, $00, $00, $00
.endproc

; 3BE6 chr_set_face_and_place: spr_unflip_monk_faces (HL, DE kept), [HL] := DE, then the inline record of the
; caller's caller (the caller's JSR is followed by the destination word and 5 bytes: la_copy5 reads them).
.proc la_cara_y_lugar
        lda     zhl
        pha
        lda     zhl+1
        pha
        lda     zde
        pha
        lda     zde+1
        pha
        jsr     spr_unflip_monk_faces
        pla
        sta     zde+1
        pla
        sta     zde
        pla
        sta     zhl+1
        pla
        sta     zhl
        jsr     util_store_dx_at_bx
        jmp     la_copy5
.endproc

; 3B9C chr_bernardo_arrives: the Berengario slot becomes Bernardo Gui (face B293h) at the abbey entrance.
.proc chr_bernardo_arrives
        ldx     #4
        ldy     #0
        jsr     la_cara
        jsr     la_cara_y_lugar
        .word   D64_CHR_BERENGAR + 1
        .byte   $00, $88, $88, $02, $00
.endproc

; HL := spr_monk_faces + X, DE := the face Y (0 Bernardo Gui B293h, 2 Jorge B2F7h, 4 the hooded monk B35Bh)
.proc la_cara
        txa
        clc
        adc     #<D64_SPR_MONK_FACES
        sta     zhl
        lda     #>D64_SPR_MONK_FACES
        adc     #0
        sta     zhl+1
        lda     caras,y
        sta     zde
        lda     caras+1,y
        sta     zde+1
        rts
caras:  .word   CARAS + 4 * 60, CARAS + 5 * 60, CARAS + 6 * 60
.endproc

; 3BAC chr_jorge_appears: the Severino slot gets the face B2F7h (Jorge) and his place.
.proc chr_jorge_appears
        ldx     #6
        ldy     #2
        jsr     la_cara
        jsr     la_cara_y_lugar
        .word   D64_CHR_SEVERIN + 1
        .byte   $03, $12, $65, $18, $00
.endproc

; 3BBC chr_berengar_vanishes: [[chr_berengar + 0Ch]] := 10h, +0Ah, +0Bh := 0, face B2F7h and a place out of the map.
.proc chr_berengar_vanishes
        lda     D64_CHR_BERENGAR + $0C
        sta     zt0
        lda     D64_CHR_BERENGAR + $0D
        sta     zt0+1
        ldy     #0
        lda     #$10
        sta     (zt0),y
        tya
        sta     D64_CHR_BERENGAR + $0A
        sta     D64_CHR_BERENGAR + $0B
        ldx     #4
        ldy     #2
        jsr     la_cara
        jsr     la_cara_y_lugar
        .word   D64_CHR_BERENGAR + 1
        .byte   $00, $C8, $24, $00, $00
.endproc

; 3BD8 chr_berengar_hooded: spr_unflip_monk_faces, then face B35Bh (the hooded monk) in spr_monk_faces + 4.
; Out: HL = spr_monk_faces + 6, DE = the face.
.proc chr_berengar_hooded
        jsr     spr_unflip_monk_faces
        ldx     #4
        ldy     #4
        jsr     la_cara
        ; falls into util_store_dx_at_bx
.endproc

; 3BE1 util_store_dx_at_bx: [HL] := E, [HL + 1] := D.  Out: HL + 2.
.proc util_store_dx_at_bx
        ldy     #0
        lda     zde
        sta     (zhl),y
        iny
        lda     zde+1
        sta     (zhl),y
        lda     zhl
        clc
        adc     #2
        sta     zhl
        bcc     :+
        inc     zhl+1
:       rts
.endproc

; 3BF3 obj_jorge_drops_book: the Severino holder drops its object (4DCD; IX, IY kept), game_idle_frames := 0.
; Out: A = 0, ZF = 1, CF = 0.
.proc obj_jorge_drops_book
        ldx     #<D64_OBJ_SEVERIN_HOLDER
        ldy     #>D64_OBJ_SEVERIN_HOLDER
        bne     la_suelta                       ; (always)
.endproc

; 3BFD obj_abbot_drops_parchment: when the abbot holds the parchment (bit 4): obj_abbot_takemask := 0, his holder
; drops it, game_idle_frames := 0.  Out: A = 0, ZF = 1, CF = 0 either way.
.proc obj_abbot_drops_parchment
        lda     D64_OBJ_ABBOT_OBJECTS
        and     #$10
        bne     :+
        clc
        rts
:       lda     #0
        sta     D64_OBJ_ABBOT_TAKEMASK
        ldx     #<D64_OBJ_ABBOT_HOLDER
        ldy     #>D64_OBJ_ABBOT_HOLDER
        ; falls into la_suelta
.endproc

; 3C0F: the holder YX drops its object (obj_drop_object, IX = holder; IX and IY kept), game_idle_frames := 0
.proc la_suelta
        lda     zix
        pha
        lda     zix+1
        pha
        lda     ziy
        pha
        lda     ziy+1
        pha
        stx     zix
        sty     zix+1
        jsr     obj_drop_object
        pla
        sta     ziy+1
        pla
        sta     ziy
        pla
        sta     zix+1
        pla
        sta     zix
        lda     #0
        sta     D64_GAME_IDLE_FRAMES
        clc
        rts
.endproc

; 3C1B obj_abbot_wants_parchment: a lone RET in the 64K game.
obj_abbot_wants_parchment = la_ret

; the inline placements (3C84 with a record and its 5 bytes): the copy returns to the caller's caller
.proc obj_place_parchment               ; 3C1C: parchment 2B68 := 00 00 18 64 18
        jsr     la_copy5
        .word   OBJ + $0F
        .byte   $00, $00, $18, $64, $18
.endproc

.proc obj_place_parchment_unused        ; 3C26: (no caller) 2B68 := 00 00 58 3C 02
        jsr     la_copy5
        .word   OBJ + $0F
        .byte   $00, $00, $58, $3C, $02
.endproc

.proc obj_book_to_jorge                 ; 3C30: obj_severin_objects := 80h, book 2B59 := 80 00 60 29 00
        lda     #$80
        sta     D64_OBJ_SEVERIN_OBJECTS
        jsr     la_copy5
        .word   OBJ
        .byte   $80, $00, <D64_OBJ_SEVERIN_HOLDER, >D64_OBJ_SEVERIN_HOLDER, $00   ; held by the Severino holder (2960h)
.endproc

.proc obj_place_lamp                    ; 3C3F: once (obj_lamp_placed 0 -> 1): lamp 2B81 := 00 00 5A 2A 04.  Out: A
        lda     D64_OBJ_LAMP_PLACED
        beq     :+
        rts
:       lda     #1
        sta     D64_OBJ_LAMP_PLACED
        jsr     la_copy5
        .word   OBJ + $28
        .byte   $00, $00, $5A, $2A, $04
.endproc

.proc obj_place_key1                    ; 3C52: key 1 2B6D := 00 00 89 3E 08
        jsr     la_copy5
        .word   OBJ + $14
        .byte   $00, $00, $89, $3E, $08
.endproc

.proc obj_remove_key1                   ; 3C5C: 2B6D := 0
        jsr     la_copy5
        .word   OBJ + $14
        .byte   $00, $00, $00, $00, $00
.endproc

.proc obj_place_key3                    ; 3C66: key 3 2B72 := 00 00 35 35 13
        jsr     la_copy5
        .word   OBJ + $19
        .byte   $00, $00, $35, $35, $13
.endproc

.proc obj_place_glasses                 ; 3C70: glasses 2B63 := 00 00 1B 23 18
        jsr     la_copy5
        .word   OBJ + $0A
        .byte   $00, $00, $1B, $23, $18
.endproc

obj_remove_key1_unused = obj_remove_key1        ; 3C7A: (no caller) the same as 3C5C

; 3D87 obj_jorge_takes_book: iso_room_dark := 1, the play area cleared (16A1), Guillermo loses the book (bit 7),
; his slots redrawn (4D30, A = 80h, C = his objects), the book record cleared.
.proc obj_jorge_takes_book
        lda     #1
        sta     D64_ISO_ROOM_DARK
        jsr     vid_fill_play_area_ff
        lda     D64_B2_GUILLERMO_OBJECTS
        and     #$7F
        sta     D64_B2_GUILLERMO_OBJECTS
        sta     zbc
        lda     #$80
        jsr     hud_draw_objects
        jsr     la_copy5
        .word   OBJ
        .byte   $00, $00, $00, $00, $00
.endproc

; ==== 3C8F-3D3B: the camera and the speed =============================================================

; 3CAE ai_jorge_book_talk_with_gloves: CF = Guillermo has the gloves (bit 6) and ai_severin_state is 0Dh-0Fh.
.proc ai_jorge_book_talk_with_gloves
        lda     D64_B2_GUILLERMO_OBJECTS
        and     #$40
        beq     no
        lda     D64_AI_SEVERIN_STATE
        cmp     #$0D
        bcc     no
        cmp     #$10
        bcs     no
        sec
        rts
no:     clc
        rts
.endproc

; 3C8F game_idle_camera_check: CF (talk) set: game_idle_frames := 32h, ai_camera_target := 5, A = 0, ZF = 1.
; Else ZF = 0 when a movement key (CPC keys 0, 8, 1) is down (the last test is a tail call of sys_key_down).
.proc game_idle_camera_check
        bcc     teclas
        lda     #$32
        sta     D64_GAME_IDLE_FRAMES
        lda     #5
        sta     D64_AI_CAMERA_TARGET
        lda     #0
        rts
teclas: lda     #0
        jsr     sys_key_down
        bne     fin
        lda     #8
        jsr     sys_key_down
        bne     fin
        lda     #1
        jmp     sys_key_down
fin:    rts
.endproc

; 3CC5 game_camera_select: game_update_camera_and_bonus; a movement key puts the camera on Guillermo; else the
; idle frames count to 32h and then: the speed (normal while a phrase is shown, else no delay), the music, and
; the camera goes to ai_camera_target when it changed.
.proc game_camera_select
        jsr     game_update_camera_and_bonus
        jsr     ai_jorge_book_talk_with_gloves
        jsr     game_idle_camera_check
        beq     quieto
        lda     #0
        beq     camara                          ; (always)
quieto: inc     D64_GAME_IDLE_FRAMES
        lda     D64_GAME_IDLE_FRAMES
        cmp     #$32
        bcs     :+
        rts
:       dec     D64_GAME_IDLE_FRAMES
        lda     D64_TXT_PHRASE_BUSY
        beq     :+
        jsr     game_speed_default
        jmp     musica
:       jsr     game_speed_set                  ; A = 0: no delay
musica: jsr     snd_play_music_if_idle
        lda     D64_AI_CAMERA_TARGET
        cmp     D64_GAME_CAMERA_OTHER
        bne     camara
        rts
camara: sta     D64_GAME_CAMERA_OTHER           ; 3CF6
        sta     D64_GAME_IDLE_FRAMES
        tax
        beq     game_speed_default              ; Guillermo: the normal speed
        rts
.endproc

; 3CFE game_speed_default: sys_frame_ticks := the normal ticks.  Out: A = them; the flags kept.
.proc game_speed_default
        php
        lda     D64_SYS_FRAME_TICKS_NORMAL
        sta     D64_SYS_FRAME_TICKS
        plp
        rts
.endproc

; 3D01 game_speed_set: sys_frame_ticks := A.
.proc game_speed_set
        sta     D64_SYS_FRAME_TICKS
        rts
.endproc

; 3D05 util_return_zero: A = 0, ZF = 1, CF = 0.
.proc util_return_zero
        lda     #0
        clc
        rts
.endproc

; 3D07 game_set_c004_inline: `JSR game_set_c004_inline`, one byte v: game_idle_frames := v; returns past the byte.
; Out: A = v.
.proc game_set_c004_inline
        pla
        sta     zt0
        pla
        sta     zt0+1
        ldy     #1
        lda     (zt0),y
        sta     D64_GAME_IDLE_FRAMES
        tax
        inc     zt0
        bne     :+
        inc     zt0+1
:       lda     zt0+1
        pha
        lda     zt0
        pha
        txa
        rts
.endproc

; 3D0F game_camera_from_ch_unused: (no caller) game_camera_other := B - 1.  Out: A, ZF as DEC (CF kept).
.proc game_camera_from_ch_unused
        ldx     zbc+1
        dex
        stx     D64_GAME_CAMERA_OTHER
        txa
        rts
.endproc

; 3D15 game_camera_update: game_camera_select, then chr_camera_target := chr_record_ptrs[game_camera_other].
; Out: DE = the record, HL = the address of its high byte.
.proc game_camera_update
        jsr     game_camera_select
        lda     #<D64_CHR_RECORD_PTRS
        sta     zhl
        lda     #>D64_CHR_RECORD_PTRS
        sta     zhl+1
        lda     D64_GAME_CAMERA_OTHER
        asl
        jsr     util_add_bx_al
        ldy     #0
        lda     (zhl),y
        sta     zde
        sta     D64_CHR_CAMERA_TARGET
        iny
        lda     (zhl),y
        sta     zde+1
        sta     D64_CHR_CAMERA_TARGET+1
        inc     zhl
        bne     :+
        inc     zhl+1
:       rts
.endproc

; ==== 3D3C-3E28: the lamp and night timers, the percentage, the bonus and the poison ====================

; 3D3C ai_lamp_tick: C = ai_lamp_event, except while Adso has the lamp lit in a dark room: ai_lamp_time + 1 and,
; at each multiple of 256 frames with no event pending, 1 at 300h, 2 at 600h, else 0.
.proc ai_lamp_tick
        lda     D64_AI_LAMP_EVENT
        sta     zbc
        lda     D64_GAME_ADSO_LAMP
        bpl     fin
        lda     D64_AI_LAMP_IN_USE
        beq     fin
        lda     D64_ISO_ROOM_DARK
        beq     fin
        inc     D64_AI_LAMP_TIME
        bne     fin
        inc     D64_AI_LAMP_TIME+1
        lda     zbc
        bne     fin
        lda     D64_AI_LAMP_TIME+1
        ldx     #1
        cmp     #3
        beq     pon
        inx
        cmp     #6
        beq     pon
        ldx     #0
pon:    stx     zbc
fin:    rts
.endproc

; 3D6A ai_night_end_tick: C = 1 at night when ai_hour_frames_left is exactly 0200h, else 0 (ai_advance_hour := 1
; when its high byte is 0 with the word not 0 and the low byte 0: unreachable).
.proc ai_night_end_tick
        lda     #0
        sta     zbc
        lda     D64_AI_HOUR_FRAMES_LEFT
        ora     D64_AI_HOUR_FRAMES_LEFT+1
        beq     fin
        lda     D64_AI_HOUR_FRAMES_LEFT
        bne     fin
        lda     D64_GAME_HOUR
        bne     fin
        lda     D64_AI_HOUR_FRAMES_LEFT+1
        cmp     #2
        bne     :+
        inc     zbc
        rts
:       cmp     #0
        bne     fin
        lda     #1
        sta     D64_AI_ADVANCE_HOUR
fin:    rts
.endproc

; 3DA8 game_compute_percentage: "100" when the investigation is solved; else 7 (day - 1) + hour + 4 per bit of
; the word game_bonus2 (8-bit sum), 0 below 5; its digits go to game_percent_digits (' ', tens, units).
; Out: A = 20h (31h when solved), BC = units << 8 | tens (0), HL = 3030h + BC.
.proc game_compute_percentage
        lda     D64_GAME_INVESTIGATION_OPEN
        bne     calc
        sta     zbc
        sta     zbc+1
        lda     #$31
        bne     guarda                          ; (always)
calc:   lda     D64_GAME_DAY
        sec
        sbc     #1
        sta     zt0
        asl
        sta     zt0+1
        asl
        clc
        adc     zt0
        clc
        adc     zt0+1
        clc
        adc     D64_GAME_HOUR
        sta     zt0
        ldx     #1                      ; + 4 per bit of the word game_bonus2 (8 bits)
palabra:
        ldy     D64_GAME_BONUS2,x
unbit:  tya
        beq     :+
        asl
        tay
        bcc     unbit
        lda     zt0
        adc     #4 - 1                  ; (C set)
        sta     zt0
        jmp     unbit
:       dex
        bpl     palabra
        lda     zt0
        cmp     #5
        bcs     :+
        lda     #0
:       ldx     #0
:       cmp     #10
        bcc     :+
        sbc     #10
        inx
        bne     :-
:       sta     zbc+1                           ; B = units
        stx     zbc                             ; C = tens
        lda     #$20
guarda: sta     D64_GAME_PERCENT_DIGITS
        tax
        lda     zbc
        clc
        adc     #$30
        sta     zhl
        sta     D64_GAME_PERCENT_DIGITS+1
        lda     zbc+1
        adc     #$30
        sta     zhl+1
        sta     D64_GAME_PERCENT_DIGITS+2
        txa
        rts
.endproc

; 3DEE game_update_bonus_and_poison: game_bonus2 |= Guillermo's objects & 4Ch | Adso's & 02h.  While Guillermo holds
; the book without the gloves the poison counts; when it wraps he dies (state, fall, dead flag, phrase 22h).
.proc game_update_bonus_and_poison
        lda     D64_B2_GUILLERMO_OBJECTS
        sta     zbc
        and     #$4C
        sta     zt0
        lda     D64_OBJ_ADSO_OBJECTS
        and     #$02
        ora     zt0
        ora     D64_GAME_BONUS2
        sta     D64_GAME_BONUS2
        lda     zbc
        bpl     fin
        and     #$40
        bne     fin
        inc     D64_GAME_BOOK_POISON_COUNT
        bne     fin
        lda     D64_SPR_TABLE+2
        lsr
        sta     D64_CHR_GUILLERMO_STATE
        lda     #$FE
        sta     D64_CHR_GUILLERMO_FALL_DY
        lda     #1
        sta     D64_GAME_GUILLERMO_DEAD
        jsr     hud_say_now
        .byte   $22
fin:    rts
.endproc

; 3EE6 ai_stop_hour_countdown: ai_hour_frames_left := 0.  Out: HL = 0.
.proc ai_stop_hour_countdown
        lda     #0
        sta     D64_AI_HOUR_FRAMES_LEFT
        sta     D64_AI_HOUR_FRAMES_LEFT+1
        sta     zhl
        sta     zhl+1
        rts
.endproc

; ==== 3EEF-3F72: Malaquias rising, Guillermo's place, the parchment ===================================

; 3EEF ai_malaquias_rise: one step of Malaquias rising when he dies (every 16th call: height + 1; at 14h out).
.proc ai_malaquias_rise
        lda     D64_CHR_MALACHI_RISE_DELAY
        and     #$0F
        sta     D64_CHR_MALACHI_RISE_DELAY
        bne     fin
        lda     #1
        sta     D64_CHR_MALACHI_RISING
        inc     D64_CHR_MALACHI+4
        lda     D64_CHR_MALACHI+4
        cmp     #$14
        bcc     fin
        lda     #0
        sta     D64_CHR_MALACHI+2
        sta     D64_AI_MALACHI_REACHED
        lda     #2
        sta     D64_AI_MALACHI_DYING
fin:    rts
.endproc

; 3F15 ai_check_guillermo_at_mass: his place in the church (4B84h), else 3080h.  Out: A = C.
.proc ai_check_guillermo_at_mass
        ldx     #$84
        ldy     #$4B
        jsr     la_en
        bne     fin
        ldx     #$80
        ldy     #$30
        jmp     la_en
fin:    rts
.endproc

; 3F22 ai_check_guillermo_at_refectory: 3938h, else 3020h.  Out: A = C.
.proc ai_check_guillermo_at_refectory
        ldx     #$38
        ldy     #$39
        jsr     la_en
        bne     fin
        ldx     #$20
        ldy     #$30
        jmp     la_en
fin:    rts
.endproc

la_en:  stx     zde
        sty     zde+1
        ; falls into ai_check_guillermo_at

; 3F2D ai_check_guillermo_at: Guillermo at the ground-floor position E = x, D = y?  0 (height >= 0Bh or another
; room), 2 (that room), 1 (exactly there with orientation 1); into ai_guillermo_in_place.  Out: A = C, ZF.
.proc ai_check_guillermo_at
        lda     #0
        sta     zbc
        lda     D64_CHR_GUILLERMO+4
        cmp     #$0B
        bcs     fin
        lda     D64_CHR_GUILLERMO+2
        eor     zde
        sta     zde
        lda     D64_CHR_GUILLERMO+3
        eor     zde+1
        ora     zde
        cmp     #$10
        bcs     fin
        ldx     #2
        stx     zbc
        cmp     #0
        bne     fin
        lda     D64_CHR_GUILLERMO+1
        cmp     #1
        bne     fin
        dec     zbc
fin:    lda     zbc
        sta     D64_AI_GUILLERMO_IN_PLACE
        rts
.endproc

; 3F56 ai_parchment_check: ZF = 0 if bit 0 of ai_monk_flags; ZF = 1 if Guillermo has the parchment; ZF = 0 if
; somebody holds it; else ZF = 1 when it lies on the ground floor.
.proc ai_parchment_check
        lda     D64_AI_MONK_FLAGS
        and     #$01
        bne     fin
        lda     D64_B2_GUILLERMO_OBJECTS
        and     #$10
        cmp     #$10
        beq     fin
        lda     OBJ + $0F
        bmi     fin
        lda     OBJ + $13
        jsr     iso_floor_base
        lda     zbc+1
fin:    rts
.endproc

; ==== 4477, 4B43-4C45: the delay, the score-bar phrases, the inline texts, the inventory ===================

; 4477 util_delay_cx: a busy delay of BC passes (0 = 65536).  Out: BC = 0, A = 0, ZF = 1, CF = 0.
.proc util_delay_cx
:       lda     zbc
        bne     :+
        dec     zbc+1
:       dec     zbc
        lda     zbc
        ora     zbc+1
        bne     :--
        clc
        rts
.endproc

; 4B43 util_ret_530a: a lone RET (a removed routine).
util_ret_530a = la_ret
la_ret: rts

; 4B44 txt_print_inline: `JSR txt_print_inline`, bytes, FFh: every byte AND 7Fh drawn by txt_draw_char_inverted
; at txt_cursor; returns past the FFh.  Out: A = FFh, ZF = 1.
.proc txt_print_inline
        pla
        sta     la_s
        pla
        sta     la_s+1
sig:    inc     la_s
        bne     :+
        inc     la_s+1
:       ldy     #0
        lda     (la_s),y
        cmp     #$FF
        beq     fin
        and     #$7F
        jsr     txt_draw_char_inverted
        jmp     sig
fin:    lda     la_s+1
        pha
        lda     la_s
        pha
        lda     #$FF
        cmp     #$FF
        rts
.endproc

; 4BB2 txt_skip_strings: HL past B FFh-terminated strings (B = 0: 256).  Out: HL, B = 0, A = FFh.
.proc txt_skip_strings
        ldy     #0
:       lda     (zhl),y
        inc     zhl
        bne     :+
        inc     zhl+1
:       cmp     #$FF
        bne     :--
        dec     zbc+1
        bne     :--
        rts
.endproc

; 4B57 hud_clear_phrase_area: the phrase line of the score bar (CPC E510h: 8 lines of 20h bytes from line 4 of
; row 20) cleared to FFh (pen 3): bitmap lines 4-7 of row 20 and 0-3 of row 21, cells 12-27.
.proc hud_clear_phrase_area
        ldx     #8 * 15
:       lda     #0
        sta     D64_SCR_ROW20 + 64 + 4,x
        sta     D64_SCR_ROW20 + 64 + 5,x
        sta     D64_SCR_ROW20 + 64 + 6,x
        sta     D64_SCR_ROW20 + 64 + 7,x
        sta     D64_SCR_ROW20 + 320 + 64,x
        sta     D64_SCR_ROW20 + 320 + 65,x
        sta     D64_SCR_ROW20 + 320 + 66,x
        sta     D64_SCR_ROW20 + 320 + 67,x
        txa
        sec
        sbc     #8
        tax
        bcs     :-
        rts
.endproc

; 4B71 hud_say_now: `JSR hud_say_now`, the phrase: a phrase with priority (busy and active cleared, the phrase
; line cleared), then falls into hud_say with the same inline byte.
.proc hud_say_now
        jsr     plat_di
        lda     #0
        sta     D64_TXT_PHRASE_BUSY
        sta     D64_TXT_PHRASE_ACTIVE
        jsr     hud_clear_phrase_area
        ; falls into hud_say
.endproc

; 4B7C hud_say: `JSR hud_say`, the phrase: starts it unless one is shown (DI ... EI): its voice, busy = active =
; word done := 1, txt_phrase_ptr := the phrase, no trailing blanks.  Out: CF = 1 started (A = 0, B = 0,
; DE = the voice entry, HL = the phrase), CF = 0 busy (A = txt_phrase_busy).
.proc hud_say
        pla
        sta     la_s
        pla
        sta     la_s+1
        inc     la_s
        bne     :+
        inc     la_s+1
:       lda     la_s+1
        pha
        lda     la_s
        pha
        lda     D64_TXT_PHRASE_BUSY
        beq     :+
        clc
        rts
:       jsr     plat_di
        ldy     #0
        lda     (la_s),y
        sta     zbc+1                           ; B = the phrase
        clc
        adc     #<D64_TXT_PHRASE_SOUND
        sta     zde
        lda     #>D64_TXT_PHRASE_SOUND
        adc     #0
        sta     zde+1
        lda     (zde),y
        sta     D64_SND_PHRASE_VOICE
        lda     #1
        sta     D64_TXT_PHRASE_BUSY
        sta     D64_TXT_PHRASE_ACTIVE
        sta     D64_TXT_WORD_DONE
        lda     #<D64_TXT_PHRASES
        sta     zhl
        lda     #>D64_TXT_PHRASES
        sta     zhl+1
        lda     zbc+1
        beq     :+
        jsr     txt_skip_strings
:       lda     zhl
        sta     D64_TXT_PHRASE_PTR
        lda     zhl+1
        sta     D64_TXT_PHRASE_PTR+1
        lda     #0
        sta     D64_TXT_TRAILING_BLANKS
        jsr     plat_ei
        lda     #0
        sec
        rts
.endproc

; 4BBB hud_blink_yes_no: at txt_cursor := A41Dh "   " (ai_sleep_answer_count odd) or "S:N" (even).  IX kept.
; Out: A = FFh, ZF = 1.
.proc hud_blink_yes_no
        lda     zix
        pha
        lda     zix+1
        pha
        lda     #$1D
        sta     D64_TXT_CURSOR
        lda     #$A4
        sta     D64_TXT_CURSOR+1
        lda     D64_AI_SLEEP_ANSWER_COUNT
        and     #1
        beq     sn
        jsr     txt_print_inline
        .byte   $20, $20, $20, $FF
        jmp     fin
sn:     jsr     txt_print_inline
        .byte   $53, $3A, $4E, $FF
fin:    pla
        sta     zix+1
        pla
        sta     zix
        lda     #$FF
        cmp     #$FF
        rts
.endproc

; 4BDE obj_play_inventory_sound: A = changed, C = held: the drop sound (0C9F) when (changed & held) = 0, else
; the take sound (0C95).  A, the flags and BC kept.
.proc obj_play_inventory_sound
        php
        pha
        ldx     zbc
        stx     la_t+3
        ldx     zbc+1
        stx     la_t+2
        and     zbc
        bne     :+
        jsr     snd_play_object_dropped
        jmp     fin
:       jsr     snd_play_object_taken
fin:    lda     la_t+3
        sta     zbc
        lda     la_t+2
        sta     zbc+1
        pla
        plp
        rts
.endproc

; 4BEC obj_update_inventory: once a frame: the objects picked up (4C46 from Guillermo's holder), dropped (4DC3),
; the key permissions (4D97); the inventory sounds of Adso (objects, lamp) and Guillermo; the manuscript read when
; Guillermo's glasses/parchment bits changed and he has both; the changed slots redrawn (4D30); bit 0 cleared in
; every object record.  Out: HL = the FFh record, BC = 5, A = FFh, ZF = 1.
.proc obj_update_inventory
        lda     D64_B2_GUILLERMO_OBJECTS
        sta     D64_OBJ_GUILLERMO_OBJECTS_BEFORE
        lda     D64_GAME_ADSO_LAMP
        sta     la_t                            ; the lamp byte before
        lda     D64_OBJ_ADSO_OBJECTS
        sta     la_t+1                          ; Adso's objects before
        lda     #<D64_OBJ_CHAR_OBJECTS
        sta     zix
        lda     #>D64_OBJ_CHAR_OBJECTS
        sta     zix+1
        jsr     obj_pick_up_objects
        jsr     obj_drop_on_space
        jsr     obj_update_key_permissions
        lda     D64_OBJ_ADSO_OBJECTS
        sta     zbc
        eor     la_t+1
        beq     :+
        jsr     obj_play_inventory_sound
:       lda     D64_GAME_ADSO_LAMP
        sta     zbc
        eor     la_t
        beq     :+
        jsr     obj_play_inventory_sound
:       lda     D64_B2_GUILLERMO_OBJECTS
        sta     zbc
        eor     D64_OBJ_GUILLERMO_OBJECTS_BEFORE
        beq     limpia
        sta     la_t                            ; changed
        jsr     obj_play_inventory_sound
        and     #$30
        beq     :+
        lda     zbc
        and     #$30
        cmp     #$30
        bne     :+
        lda     zbc
        pha
        jsr     obj_read_manuscript
        pla
        sta     zbc
:       lda     la_t
        jsr     hud_draw_objects
limpia: lda     #<OBJ
        sta     zhl
        lda     #>OBJ
        sta     zhl+1
        ldy     #0
:       lda     (zhl),y
        cmp     #$FF
        beq     fin
        and     #$FE
        sta     (zhl),y
        lda     zhl
        clc
        adc     #5
        sta     zhl
        bcc     :-
        inc     zhl+1
        bne     :-                              ; (always)
fin:    lda     #5
        sta     zbc
        sty     zbc+1
        lda     #$FF
        cmp     #$FF
        rts
.endproc
