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

; abadia64ks, 6502 code of the game: group principal — the start, a new game, the main loop (Z80 20BE-2225),
; the end of a game (3E29-3EC6), the CTRL+TAB menu that saves and loads the game (31DF and its helpers;
; on the C64 to disk instead of tape).  C reference juego/f_principal.c, juego/f_logica_a.c (game_check_end,
; game_ending).
;
; Not on the C64: the Z80's interrupt vector and RST vectors (20EA-2107: the C64's IRQ calls sys_tick itself,
; the scripts run in logica_b's VM; the C3h at 4AFCh is kept: a data block), the SP saved at 2913h (only the tape loader and the dead debug exit read
; it), the CRTC calls (plat_crtc does nothing), the robes copied and flipped to AE2Eh at a new game
; (2126-2136: nothing reads them before the height buffer overwrites them, c64/NOTAS_MAPA.md), the lone RETs
; 3557 and 4B43, 3D05 util_return_zero and the dead debug exit after it.
;
; Check hooks: with PRUEBA defined (the host's whole-game build) plat_frame (2179h, a frame), plat_espera (a
; pass of the wait 21D6) and plat_pausa (a pass of the waits 20C7 and 3EB8) are called, so the host can
; deliver the 300 Hz ticks as its synchronous mode does and compare the game frame by frame; on the C64 they
; assemble to nothing (the interrupt is real).

        .include "zp.inc"
        .include "mapa.inc"
        .export game_main, game_check_end, principal_inicio
        .export cert_frame, cert_espera, cert_pausa1, cert_nueva      ; (the frame and wait points: c64/certifica)
.ifndef PRUEBA
        .export cert_pausa2
.endif

        .import plat_inicio, plat_di, plat_ei, plat_disco_guarda, plat_disco_carga, plat_final
        .import sys_startup_init, snd_silence_all, sys_read_keyboard, sys_key_down, sys_key_pressed
        .import game_init_new_game, vid_clear_play_area, obj_init_mirror, ai_clock_init
        .import obj_close_mirror, hud_draw_guillermo_objects, ai_clock_redraw, hud_obsequium_sub
        .import hud_clear_phrase_area, game_input_and_mirror, sys_check_pause_save_load, ai_timers_tick
        .import game_update_bonus_and_poison, hud_scroll_hour_name, ai_hour_update, game_camera_update
        .import iso_update_camera_room, iso_draw_room, obj_update_inventory, obj_update_doors, chr_update
        .import game_run_npc_behaviours, spr_place_light, obj_door_flip_graphics, iso_mirror_update
        .import snd_play_footstep, spr_draw_or_darken, vid_fill_play_area_ff, game_compute_percentage
        .import txt_print_inline, snd_psg_write, spr_unflip_monk_faces, obj_fix_owner_pointers
        .import obj_set_mirror_numeral
        .importzp hbuf_cache_key                ; estado_texto: emptied at 2151
.ifdef PRUEBA
        .import plat_frame, plat_espera, plat_pausa
.endif

ESPACIO = $2F                           ; CPC key numbers
ESC     = $42
TAB     = $44
CONTROL = $17
TECLA_S = $3C
TECLA_L = $24

; the saved game: the buffer 7F80h, 5DCh bytes (checksum at offset 5DAh), as the Z80 lays it out
ESTADO      = D64_STATE_BUFFER
ESTADO_LEN  = $05DC
ESTADO_SUMA = $05DA

PD      = zp0                           ; copia: the destination and source pointers
PS      = zp0 + 2

.ifdef C128
        .import cab_inicio
.endif
.segment "CODE"

; the C64's entry (the loader jumps here): the platform, then the game as the tape's JP 0200h / JP 20BEh
.proc principal_inicio
        sei
        ldx     #$FF
        txs
        jsr     plat_inicio
.ifdef C128
        jsr     cab_inicio              ; the C128: the heads' hardware sprites (cabezas128.s)
.endif
        jmp     game_main
.endproc

; ---- 20BE game_main: never returns ---------------------------------------------------------------------------
.proc game_main
        jsr     plat_di                         ; 20BE
        lda     D64_SYS_STARTUP_DONE            ; 20BF-20C4: the start-up once
        cmp     #$0D
        beq     nueva
        jsr     sys_startup_init
nueva:                                          ; 20C7: a new game
::cert_nueva:
        jsr     plat_di
        jsr     snd_silence_all                 ; 20D2
        jsr     sys_read_keyboard               ; 20D5
        lda     #ESPACIO                        ; 20D8-20DD: while space is held
        jsr     sys_key_down
        beq     :+
.ifdef PRUEBA
        jsr     plat_pausa
.endif
::cert_pausa1:                                  ; (C64: a pass of the wait 20C7, for c64/certifica: the host's plat_pausa)
        jmp     nueva
:       jsr     game_init_new_game              ; 20DF
        jsr     vid_clear_play_area             ; 20E2
        lda     #6                              ; 20E5-20E7: the sound tempo
        sta     D64_SND_TEMPO_RELOAD
.ifndef COMPLETO
        lda     #$C3                            ; 20EA-20F5: of the four JPs only 4AFCh is data (in the
        sta     D64_VEC_4AFC                    ; hour durations' block)
.endif                                          ; (abadia128ks, the full game: no JP there, day 7's tercia
                                                ; lasts 0 as on the PC; the 64 KiB game: C3h x 256 frames)
        lda     D64_SYS_FRAME_TICKS_NORMAL      ; 210A-210D: the frame budget
        sta     D64_SYS_FRAME_TICKS
        lda     D64_GAME_START_POS              ; 2110-2113: Guillermo's x, y
        sta     D64_CHR_GUILLERMO_XY
        sec                                     ; 2116-211A: Adso at x - 2, y + 2
        sbc     #2
        sta     D64_CHR_ADSO_XY
        lda     D64_GAME_START_POS+1
        sta     D64_CHR_GUILLERMO_XY+1
        clc
        adc     #2
        sta     D64_CHR_ADSO_XY+1
        lda     D64_GAME_START_Z                ; 211D-2123: the same height
        sta     D64_CHR_GUILLERMO_Z
        sta     D64_CHR_ADSO_Z
        jsr     obj_init_mirror                 ; 2139
        jsr     ai_clock_init                   ; 213C
        lda     #$10                            ; 213F-214B: command 10h in the 5 command buffers
        ldx     #0
:       sta     D64_CHR_CMD_BUFFER_HEADS,x
        pha
        txa
        clc
        adc     #$2D
        tax
        pla
        cpx     #5 * $2D
        bne     :-
        lda     #0                              ; 214D-214E: ticks := 0
        sta     D64_SYS_TICKS
reanuda:                                        ; 2151: also after a game is loaded
        jsr     plat_di
        lda     #0
        sta     hbuf_cache_key                  ; (the C64: estado_texto's height-list cache emptied)
        sta     D64_CHR_ROOM_X                  ; 2152-2153: the room shown forgotten
        sta     D64_CHR_GUILLERMO_STATE         ; 2156
        lda     #2
        sta     D64_CHR_GUILLERMO_FALL_DY       ; 2159-215B
        jsr     vid_clear_play_area             ; 2162
        jsr     snd_silence_all                 ; 2165
        jsr     obj_close_mirror                ; 2168
        jsr     hud_draw_guillermo_objects      ; 216B
        jsr     ai_clock_redraw                 ; 216E
        jsr     hud_obsequium_sub               ; 2171 CALL 5129 <00>
        .byte   $00
        jsr     hud_clear_phrase_area           ; 2175
        jsr     plat_ei                         ; 2178
bucle:                                          ; 2179: the main loop, a frame
::cert_frame:                                   ; (the host's plat_frame point, for c64/certifica)
.ifdef PRUEBA
        jsr     plat_frame
.endif
        lda     D64_CHR_GUILLERMO               ; 217A-217D
        sta     D64_CHR_GUILLERMO_ANIM_COPY
        jsr     game_input_and_mirror           ; 2180
        jsr     sys_check_pause_save_load       ; 2183
        jsr     menu_disco                      ; 2186: the CTRL+TAB menu
        bcs     reanuda                         ; a game loaded: 2151
        lda     #7                              ; 2189-218E: key 7 (its CALL NZ,3557 is a lone RET)
        jsr     sys_key_down
        jsr     ai_timers_tick                  ; 2191
        jsr     game_check_end                  ; 2197 (a new game: it jumps to `nueva` itself)
        jsr     game_update_bonus_and_poison    ; 219A
        jsr     hud_scroll_hour_name            ; 219D
        jsr     ai_hour_update                  ; 21A0
        jsr     game_camera_update              ; 21A3
        jsr     iso_update_camera_room          ; 21A6
        lda     D64_ISO_ROOM_CHANGED            ; 21A9-21AD
        beq     :+
        jsr     iso_draw_room                   ; 21AF
        lda     #$80                            ; 21B2
:       sta     D64_OBJ_ROOM_REDRAW             ; 21B4
        jsr     obj_update_inventory            ; 21B7
        jsr     obj_update_doors                ; 21BA
        lda     #<D64_CHR_TABLE                 ; 21BD-21C0: Guillermo's entry of chr_table
        sta     zhl
        lda     #>D64_CHR_TABLE
        sta     zhl+1
        jsr     chr_update
        jsr     game_run_npc_behaviours         ; 21C3
        lda     #0                              ; 21C6-21CA
        sta     D64_ISO_ROOM_CHANGED
        sta     D64_CHR_PATH_FOUND_NOW
        jsr     spr_place_light                 ; 21CD
        jsr     obj_door_flip_graphics          ; 21D0
        jsr     iso_mirror_update               ; 21D3
espera: lda     D64_SYS_TICKS                   ; 21D6-21DB: the frame's ticks
        cmp     D64_SYS_FRAME_TICKS
        bcs     :+
.ifdef PRUEBA
        jsr     plat_espera
.endif
::cert_espera:                                  ; (a pass of the wait 21D6: the host's plat_espera, for c64/certifica)
        jmp     espera
:       lda     D64_CHR_GUILLERMO               ; 21DD-21E2: a footstep when mid-step
        and     #1
        beq     :+
        jsr     snd_play_footstep               ; (the footsteps off: the footstep's note a rest, cinta_paso)
:       lda     #0                              ; 21E5-21E6
        sta     D64_SYS_TICKS
        jsr     spr_draw_or_darken              ; 21E9
        lda     #ESC                            ; 21EC-21EE (then 3D05 is always Z: JP Z,2179)
        jsr     sys_key_down
        jmp     bucle
.endproc
nueva_partida = game_main::nueva

; ---- 3E29 game_check_end: the end of a game ---------------------------------------------------------------------
; Nothing unless Guillermo is dead (37E4h) and no phrase is being shown; then the play area filled, the
; percentage computed and printed; at 100 % the ending (3EC6), else "PULSA ESPACIO PARA EMPEZAR", the wait
; for space and a new game (3EC2 POP HL / JP 20C7: the JSR's return address dropped).
.proc game_check_end
        lda     D64_GAME_GUILLERMO_DEAD         ; 3E29-3E2D
        bne     :+
        rts
:       lda     #$80                            ; 3E2E-3E30
        sta     D64_GAME_CAMERA_OTHER
        lda     D64_TXT_PHRASE_BUSY             ; 3E33-3E37
        beq     :+
        rts
:       jsr     vid_fill_play_area_ff           ; 3E38 CALL 16A1
        jsr     game_compute_percentage         ; 3E3B CALL 3DA8 (the digits into D64_GAME_PERCENT_DIGITS)
        lda     D64_GAME_PERCENT_DIGITS         ; the digits into this code's own copy of the text (3E61)
        sta     digitos
        lda     D64_GAME_PERCENT_DIGITS+1
        sta     digitos+1
        lda     D64_GAME_PERCENT_DIGITS+2       ; the units (3E63): the CPC writes 3 characters
        sta     digitos+2
        ldx     #$10                            ; 3E3E-3E41: the cursor 2010h
        ldy     #$20
        jsr     cursor
        jsr     txt_print_inline
.ifdef INGLES                                   ; (English: the lines centred on the same axis as the Spanish ones)
        .byte   "YOU HAVE SOLVED", $FF
        ldx     #$0F                            ; 300Fh
.else
        .byte   "HAS RESUELTO EL", $FF
        ldx     #$0E                            ; 3E57: 300Eh
.endif
        ldy     #$30
        jsr     cursor
        jsr     txt_print_inline
        .byte   " "
.ifdef INGLES
digitos: .byte  "00  PER CENT", $FF
        ldx     #$0B                            ; 400Bh
.else
digitos: .byte  "00  POR CIENTO", $FF
        ldx     #$0C                            ; 3E70: 400Ch
.endif
        ldy     #$40
        jsr     cursor
        jsr     txt_print_inline
.ifdef INGLES
        .byte   "OF THE INVESTIGATION", $FF
.else
        .byte   "DE LA INVESTIGACION", $FF
.endif
        ldx     #$06                            ; 3E8D: 8006h
        ldy     #$80
        jsr     cursor
        lda     digitos                         ; 3E93-3E98: 100 %: the ending
        cmp     #'1'
        beq     final
        jsr     txt_print_inline
.ifdef INGLES
        .byte   "   PRESS SPACE TO START   ", $FF
.else
        .byte   "PULSA ESPACIO PARA EMPEZAR", $FF
.endif
fin_esp:                                        ; 3EB8-3EC0: the wait for space
        jsr     sys_read_keyboard
        lda     #ESPACIO
        jsr     sys_key_down
.ifdef PRUEBA
        bne     :+
        jsr     plat_pausa                      ; a pass: the JR Z,3EB8 at 3EC0
        jmp     fin_esp
:
.else
::cert_pausa2:                                  ; (C64: taken = a pass of the wait 3EB8, for c64/certifica)
        beq     fin_esp
.endif
        pla                                     ; 3EC2 POP HL / JP 20C7
        pla
        jmp     nueva_partida
final:  jsr     txt_print_inline                ; 3EC6
.ifdef CINTA                                    ; the tape: the CPC's own words (the ending comes from the tape)
.ifdef INGLES
        .byte   "    PRESS PLAY ON TAPE", $FF
.else
        .byte   "PON EL CASSETTE EN MARCHA", $FF
.endif
.elseif .defined(C128) || .defined(DISCO)       ; the C128's and the C64's disks: the same length in both languages
.ifdef INGLES
        .byte   "LOADING THE ENDING", $FF
.else
        .byte   " CARGANDO EL FINAL", $FF
.endif
.else
        .byte   "CARGANDO EL FINAL", $FF
.endif
        jmp     plat_final                      ; 31CF: the ending parchment, loaded from disk (never returns)
cursor: stx     D64_TXT_CURSOR
        sty     D64_TXT_CURSOR+1
        rts
.if .defined(INGLES) && .defined(CINTA)          ; the same size in both languages: everything after it stays where
        .res    4                               ; it is, the English image is the Spanish one plus an overlay
.elseif .defined(INGLES) && (.defined(C128) || .defined(DISCO))  ; (c64/cinta/NOTAS.md; the Spanish strings are 4
        .res    1                               ; bytes longer on the tape, 1 on the disks: piezas128.py, flujo_cinta.py
                                                ; check)
.endif
.endproc

; ---- 31DF the CTRL+TAB menu: S saves, L loads, ESC goes on (the tape's on the C64's disk) -----------------------
; Out: C = 1 when a game was loaded (the main loop starts again at 2151).
.proc menu_disco
        lda     #TAB                            ; 31DF-31E4: a new press of TAB
        jsr     sys_key_pressed
        beq     no
        lda     #CONTROL                        ; 31E5-31EA: with CONTROL down
        jsr     sys_key_down
        bne     :+
no:     clc
        rts
:       jsr     plat_di                         ; 31EB
        lda     #$3F                            ; 31EC-31F4: the PSG mixer off
        sta     D64_SND_CHANNEL_MASK_COPY
        sta     zbc
        lda     #7
        jsr     snd_psg_write
bucle:  jsr     marca                           ; 31FA-3207: the mark blinks
        jsr     espera
        jsr     marca
        jsr     espera
        jsr     sys_read_keyboard               ; 320A
        lda     #ESC                            ; 320D-3212
        jsr     sys_key_down
        bne     sale
        lda     #TECLA_S                        ; 3219-321E
        jsr     sys_key_down
        bne     guarda
        lda     #TECLA_L                        ; 3220-3225
        jsr     sys_key_down
        beq     bucle
        jsr     bloque                          ; 3227-3232: load the block
        jsr     plat_disco_carga
        bcs     sale
        jsr     suma                            ; 3234-3238: the checksum right: the game back
        cmp     ESTADO+ESTADO_SUMA
        bne     sale
        jsr     restaura
        sec                                     ; to 2151
        rts
guarda: jsr     reune                           ; 3240
        jsr     suma                            ; 3243-3246
        sta     ESTADO+ESTADO_SUMA
        jsr     bloque                          ; 3247-324F
        jsr     plat_disco_guarda
sale:   jsr     sys_read_keyboard               ; 3262-3273 tape_menu_leave: until ESC is up (the border stays black)
        lda     #ESC
        jsr     sys_key_down
        bne     sale
        jsr     plat_ei                         ; 323E
        clc
        rts

bloque: lda     #<ESTADO                        ; zhl = the block, zde = its length
        sta     zhl
        lda     #>ESTADO
        sta     zhl+1
        lda     #<ESTADO_LEN
        sta     zde
        lda     #>ESTADO_LEN
        sta     zde+1
        rts

; 3254: the 8-bit sum of the 5DAh bytes of the buffer
suma:   lda     #<ESTADO
        sta     zp0
        lda     #>ESTADO
        sta     zp0+1
        ldx     #>ESTADO_SUMA                   ; 5 pages + DAh bytes
        lda     #0
        ldy     #0
:       clc
        adc     (zp0),y
        iny
        bne     :-
        inc     zp0+1
        dex
        bne     :-
:       clc
        adc     (zp0),y
        iny
        cpy     #<ESTADO_SUMA
        bne     :-
        rts

; 3276 hud_tape_marker_swap: the 8 lines of the top left byte of the screen (the high nibble of the bitmap bytes
; $E020-$E027) exchanged with the mark's 8 nibbles
marca:  ldx     #7
:       lda     $E020,x
        and     #$F0
        sta     zt0
        lda     tabla,x
        asl     a
        asl     a
        asl     a
        asl     a
        sta     zt0+1
        lda     $E020,x
        and     #$0F
        ora     zt0+1
        sta     $E020,x
        lda     zt0
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     tabla,x
        dex
        bpl     :-
        rts

; 31C1 util_delay_units(1): the CPC's 65536 passes of 4477 (26 T-states each, ~0.43 s): about 420000 cycles
espera: ldx     #0
        ldy     #0
:       nop
        nop
        dex
        bne     :-
        dey
        bne     :-
        rts
.endproc

; the mark's 8 nibbles (the CPC bytes at 328Bh 00 00 0F 0F F0 F0 FF FF as C64 nibbles)
.segment "DATA"
tabla:  .byte   $0, $0, $F, $F, $A, $A, $0, $0
.segment "CODE"

; ---- 2FD7 game_state_gather / 2FEF game_state_restore: the saved game in the buffer, as the Z80 lays it out
; (338h bytes from 28D0h, C8h from 37D2h, FFh from 3568h; restored: 320h, 98h, E0h).  On the C64 those CPC
; ranges are in several blocks (c64/juego/mapa64.tsv): copied piece by piece to the same buffer offsets.
; 28D0h-2BE7h is contiguous ($02A4-$05BB); 2BE8h-2BEFh the monks' faces; 2BF0h-2C07h the sprite offset tables;
; 37D2h-3869h ($05DD) then 386Ah-389Ah the script variables; 3568h-3648h the command buffers.

.proc reune
        jsr     plat_di                         ; 2FD7
        ldx     #0
:       lda     piezas_r,x                      ; destination offset, source, length (words)
        sta     PD
        lda     piezas_r+1,x
        sta     PD+1
        lda     piezas_r+2,x
        sta     PS
        lda     piezas_r+3,x
        sta     PS+1
        lda     piezas_r+4,x
        sta     zbc
        lda     piezas_r+5,x
        sta     zbc+1
        txa
        pha
        jsr     copia
        pla
        clc
        adc     #6
        tax
        cpx     #piezas_r_fin - piezas_r
        bne     :-
        rts
.endproc

.proc restaura
        jsr     plat_di                         ; 2FEF
        lda     D64_CHR_GUILLERMO_FLIP          ; 2FF0-2FF7: the two flip states kept
        pha
        lda     D64_CHR_ADSO_FLIP
        pha
        jsr     spr_unflip_monk_faces           ; 2FF9
        ldx     #0
:       lda     piezas_v,x
        sta     PD
        lda     piezas_v+1,x
        sta     PD+1
        lda     piezas_v+2,x
        sta     PS
        lda     piezas_v+3,x
        sta     PS+1
        lda     piezas_v+4,x
        sta     zbc
        lda     piezas_v+5,x
        sta     zbc+1
        txa
        pha
        jsr     copia
        pla
        clc
        adc     #6
        tax
        cpx     #piezas_v_fin - piezas_v
        bne     :-
        ldy     #0                              ; 3005-3008: [obj_mirror_height_ptr] := F5h
        lda     D64_OBJ_MIRROR_HEIGHT_PTR
        sta     zp0
        lda     D64_OBJ_MIRROR_HEIGHT_PTR+1
        sta     zp0+1
        lda     #$F5
        sta     (zp0),y
        pla                                     ; 3025-302D: the flip states back
        sta     D64_CHR_ADSO_FLIP
        pla
        sta     D64_CHR_GUILLERMO_FLIP
        lda     #0                              ; 3030-303A: the four monks' flips 0
        sta     D64_CHR_GUILLERMO_FLIP + $1E
        sta     D64_CHR_GUILLERMO_FLIP + $2D
        sta     D64_CHR_GUILLERMO_FLIP + $3C
        sta     D64_CHR_GUILLERMO_FLIP + $4B
        jsr     obj_fix_owner_pointers          ; 303D
        lda     #0                              ; 3040-3041
        sta     D64_AI_UNUSED_3CAD
        lda     D64_OBJ_MIRROR_NUMERAL          ; 3044-3048
        beq     :+
        jsr     obj_set_mirror_numeral
:       rts
.endproc

; PD = destination, PS = source, zbc = length (not 0): a forward copy
.proc copia
        ldy     #0
:       lda     (PS),y
        sta     (PD),y
        iny
        bne     :+
        inc     PD+1
        inc     PS+1
:       lda     zbc
        bne     :+
        dec     zbc+1
:       dec     zbc
        lda     zbc
        ora     zbc+1
        bne     :---
        rts
.endproc

.segment "RODATA"
; gather: (destination, source, length)
piezas_r:
        .word   ESTADO + $0000, D64_STATE_PART1, $2BE8 - $28D0
        .word   ESTADO + $0318, D64_SPR_MONK_FACES, 8
        .word   ESTADO + $0320, D64_CHR_SPRITE_OFFSET_TABLES, $18
        .word   ESTADO + $0338, D64_GAME_BOOK_POISON_COUNT, $98
        .word   ESTADO + $03D0, D64_AI_SCRIPT_VARS, $30
        .word   ESTADO + $0400, D64_CHR_COMMAND_BUFFERS, $E1
piezas_r_fin:
; restore: (destination, source, length)
piezas_v:
        .word   D64_STATE_PART1, ESTADO + $0000, $2BE8 - $28D0
        .word   D64_SPR_MONK_FACES, ESTADO + $0318, 8
        .word   D64_GAME_BOOK_POISON_COUNT, ESTADO + $0338, $98
        .word   D64_CHR_COMMAND_BUFFERS, ESTADO + $0400, $E0
piezas_v_fin:
