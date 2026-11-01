<!-- Made by tools/wiki.py from doc/wiki/fuentes/Main-loop.md: edit the template, not this page. -->
<!--
  abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines

  Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)

  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.

  You should have received a copy of the GNU General Public License along with this program.  If not, see
  <https://www.gnu.org/licenses/>.
-->

# Main loop and timing

[Home](Home.md) · previous: [Memory map](Memory-map.md) · next: [The clock and the ceremonies](Clock.md)

The game is one loop that never returns, paced by a 300 Hz interrupt.  This page follows the program from the
loader's jump to the frame's last step.

## The entry

The loader (from tape or disk) jumps to `principal_inicio` with the game's image in memory.  The machine is set up
first (the platform layer: the VIC-II, the CIA's timer, the SID; on the C128 also the high-resolution heads), then
the game starts exactly where the CPC's tape loader jumped, `game_main` at 20BEh:

[`src/c64/juego_final/principal.s`](../../src/c64/juego_final/principal.s#L77-L86), lines 77–86:

```asm
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
```

## A new game

`game_main` runs the one-time start-up (`sys_startup_init`, which also rebuilds the C64's merge tables), then every
new game: it waits until SPACE is released, puts every record at its initial state, places Guillermo at the start
square and Adso beside him, sets the clock to day I, nona, and gives the five monks' command buffers an empty
command.  `reanuda` is also where a loaded game continues:

[`src/c64/juego_final/principal.s`](../../src/c64/juego_final/principal.s#L89-L147), lines 89–147:

```asm
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
```

## The frame

Each pass of `bucle` is one frame of the game.  The comments give the Z80 address of each step: the order is the
original's, step by step.

[`src/c64/juego_final/principal.s`](../../src/c64/juego_final/principal.s#L164-L220), lines 164–220:

```asm
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
```

In words:

1. **Input**: the keyboard is read and the mirror's two-key combination tested (`game_input_and_mirror`); DEL pauses;
   CTRL + ← opens the save and load menu.
2. **Time**: the hour's frame counter, the lamp and the end of the night (`ai_timers_tick`, see [The clock](Clock.md)).
3. **The end**: if Guillermo is dead or the investigation solved, the result is shown (`game_check_end`).
4. **The bonus and the poison**: the investigation's bonus bits, the book's poison counter.
5. **The score bar**: the hour's name scrolls in; a pending hour change happens when no phrase is playing.
6. **The camera**: which character the screen follows (Guillermo, or the monk the story points at when Guillermo
   stands still) and the room it is in; on a room change the room is built and drawn (`iso_draw_room`).
7. **Objects and doors**: taking and dropping objects, doors opening and closing.
8. **Characters**: Guillermo moves by the keys (`chr_update` on his entry of the character table), then every other
   character runs its behaviour and its next movement command (`game_run_npc_behaviours`).
9. **The light**: in a dark room the lamp's light follows Adso (`spr_place_light`).
10. **The wait**: the frame does not end before its budget of interrupt ticks has passed.
11. **The footstep**, when Guillermo is between two steps, and **the sprites**: every sprite that changed is composed
   and copied to the screen (`spr_draw_or_darken`).

## The 300 Hz interrupt

The CPC's gate array interrupts the Z80 every 52 scan lines: 300.48 times a second.  On the C64 the CIA 1's timer A
interrupts every 3279 cycles, the same rate, and its handler does what the CPC's did (`sys_tick`, 2899h): it counts
the tick, runs the sound sequencer when a channel plays, and every 45 ticks moves the phrase of the score bar by one
step:

[`src/c64/plataforma/interrupcion.s`](../../src/c64/plataforma/interrupcion.s#L131-L167), lines 131–167:

```asm
; the game's build (-D JUEGO; the speed work's round 5, brought back: the
; interrupt routines in their most optimised form): the game's sys_tick (2899h) inline: CIA 1 acknowledged,
; the tick counter [289C] + 1 kept at FFh, the sound (0CD0) and the phrase scroller (368A).  The sound's test is the
; opcode at plat_irq_sonido: JSR s_interrupcion while a channel plays (state bit 0), BIT abs (no call) else, written
; by objetos_sonido.s where a state's bit 0 changes (s_pon, a sequence's end, snd_silence_all).  The memory
; configuration kept and the I/O in (the C64: $01's bit 0 set, $34 -> $35, $35 stays; the C128: MEM_IO).  No CLD on
; the C64 (nothing in the game sets the decimal mode: no SED in its sources); the C128 keeps it (its KERNAL runs
; between games' frames).  Measured then: an empty tick 96 -> 69 cycles; the outputs, the SID's writes, identical.
.proc plat_irq
        pha
        lda     MEMCFG
        pha
.ifdef C128
        lda     #MEM_IO
        sta     MEMCFG
        cld
.else
        ora     #$01
        sta     MEMCFG
.endif
        lda     CIA1_ICR                ; acknowledged
        inc     D64_SYS_TICKS           ; 2899h: the tick counter, kept at FFh
        bne     :+
        dec     D64_SYS_TICKS
:
::plat_irq_sonido:
        bit     s_interrupcion          ; 0CD0: JSR ($20) while a channel plays (objetos_sonido.s), BIT ($2C) else
        inc     D64_TXT_SCROLL_TIMER    ; 368A's test: the scroller's 2Dh-th tick
        lda     D64_TXT_SCROLL_TIMER
        cmp     #$2D
        bne     :+
        jsr     t_frase                 ; (X and Y kept)
:       pla
        sta     MEMCFG
        pla
        rti
.endproc
```

Two details of the 6502 version: the sound's call is an instruction rewritten in place (`JSR` while a channel plays,
`BIT` when nothing does: the common case costs no call), and the handler sets the I/O visible itself, because the game
may be reading the graphics under the I/O when the tick comes.  An empty tick costs 69 cycles.

## The game's speed

The frame's budget, `SYS_FRAME_TICKS`, is 36 ticks (120 ms) while the player plays.  When no movement key has been
pressed for 50 frames the budget becomes 0 — the game runs as fast as the machine allows, unless a phrase is being
shown — and the camera may move to the character the story wants to show:

[`src/c64/juego_final/logica_a.s`](../../src/c64/juego_final/logica_a.s#L664-L695), lines 664–695:

```asm
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
```

So the original's speed depends on how much each frame draws.  The CPC game is often slower than its budget; the
C64 game was made faster than the CPC (VICE, no keys from the start: frames 1-2000 in 122.5 s on the C64 against
294.2 s on a CPC 6128, see `doc/ESTADO.md`), and the C128 runs at 2 MHz while the beam is in the borders.
