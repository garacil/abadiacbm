<!-- Made by tools/wiki.py from doc/wiki/fuentes/Clock.md: edit the template, not this page. -->
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

# The clock and the ceremonies

[Home](Home.md) · previous: [Main loop and timing](Main-loop.md) · next: [Rooms and the isometric engine](Isometric-engine.md)

## Day and hour

Two bytes hold the time: `GAME_DAY` (1 to 7) and `GAME_HOUR` (0 night, 1 prima, 2 tercia, 3 sexta, 4 nona, 5
vísperas, 6 completas).  A new game copies them from two data bytes (day 1, hour 4: nona):

[`src/c64/juego_final/logica_b.s`](../../src/c64/juego_final/logica_b.s#L1479-L1485), lines 1479–1485:

```asm
; 5028 ai_clock_init: a new game: game_day := [BF4Fh], game_hour := [BF4Eh].  Out: A = the hour.
ai_clock_init:
        lda     D64_GAME_START_DAY
        sta     D64_GAME_DAY
        lda     D64_GAME_START_HOUR
        sta     D64_GAME_HOUR
        rts
```

## How long an hour lasts

A table of seven bytes per day gives each hour's length in units of 256 frames; 0 means that the hour has no time
limit and only the story can end it.  These are the values of the CPC 64 KiB game (the table at 4AD0h):

| day | night | prima | tercia | sexta | nona | vísperas | completas |
|---|---|---|---|---|---|---|---|
| I | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| II | 0 | 0 | 5 | 0 | 5 | 0 | 0 |
| III | 0 | 0 | 5 | 0 | 5 | 0 | 0 |
| IV | 0Fh | 0 | 0 | 0 | 5 | 0 | 0 |
| V | 0Fh | 0 | 5 | 0 | 0 | 0 | 0 |
| VI | 0Fh | 0 | 5 | 0 | 5 | 0 | 0 |
| VII | 0Fh | 0 | 0 (C3h in the 64 KiB game) | 0 | 2 | 0 | 0 |

Day VII's tercia is a curiosity of the 64 KiB version: at every new game `game_main` writes the byte C3h (the opcode
`JP`, part of the Z80's interrupt set-up) at 4AFCh, which is inside this table, so that hour lasts C3h x 256 frames.
The C128's full game does not write it, as the PC version.  The last four entries of day VII lie beyond the table's
45 bytes: they are the first bytes of the next table (the day numerals), harmless because the game ends at tercia of
day VII.

When the hour starts, its length is loaded into a 16-bit counter, `AI_HOUR_FRAMES_LEFT`:

[`src/c64/juego_final/logica_b.s`](../../src/c64/juego_final/logica_b.s#L1519-L1543), lines 1519–1543:

```asm
; 5060 ai_clock_load_duration: ai_hour_frames_left := ai_hour_durations[7 (day - 1) + hour] << 8.  Out: HL.
ai_clock_load_duration:
        lda     D64_GAME_DAY
        sec
        sbc     #1
        sta     zt0
        asl     a
        asl     a
        asl     a
        sec
        sbc     zt0                     ; 7 (day - 1), 8-bit
        clc
        adc     #<D64_AI_HOUR_DURATIONS
        sta     zp0
        lda     #>D64_AI_HOUR_DURATIONS
        adc     #0
        sta     zp0+1
        ldy     D64_GAME_HOUR
        lda     (zp0),y
        sta     zhl+1
        sta     D64_AI_HOUR_FRAMES_LEFT+1
        lda     #0
        sta     zhl
        sta     D64_AI_HOUR_FRAMES_LEFT
        rts
```

Every frame the counter goes down; when it reaches 0 the hour advances.  After completas the day advances, its
numeral is redrawn on the score bar, and the name of the new hour scrolls in (`HUD_HOUR_SCROLL_STEPS` = 9 steps):

[`src/c64/juego_final/logica_b.s`](../../src/c64/juego_final/logica_b.s#L1545-L1619), lines 1545–1619:

```asm
; 507D ai_clock_tick: once a frame: sys_key_pressed(6) and util_return_zero (the CPC's skip-the-hour test,
; always Z), then ai_hour_frames_left counts down when not 0; at 0 the hour advances.
ai_clock_tick:
        lda     #6
        jsr     sys_key_pressed
        jsr     util_return_zero
        bne     ai_clock_advance_hour
        lda     D64_AI_HOUR_FRAMES_LEFT
        ora     D64_AI_HOUR_FRAMES_LEFT+1
        bne     :+
        rts
:       lda     D64_AI_HOUR_FRAMES_LEFT
        bne     :+
        dec     D64_AI_HOUR_FRAMES_LEFT+1
:       dec     D64_AI_HOUR_FRAMES_LEFT
        lda     D64_AI_HOUR_FRAMES_LEFT
        ora     D64_AI_HOUR_FRAMES_LEFT+1
        beq     ai_clock_advance_hour
        rts

; 5094 ai_clock_advance_hour: hour + 1, the scroll of its name (9 steps) and its duration; after completas:
; the first name, day + 1 (8 -> 1) and hud_set_and_draw_day.
ai_clock_advance_hour:
        lda     D64_GAME_HOUR
        clc
        adc     #1
        cmp     #7
        bne     lb_hora
        lda     #<D64_HUD_HOUR_NAMES
        sta     D64_HUD_HOUR_NAME_PTR
        lda     #>D64_HUD_HOUR_NAMES
        sta     D64_HUD_HOUR_NAME_PTR+1
        lda     D64_GAME_DAY
        clc
        adc     #1
        sta     D64_GAME_DAY
        cmp     #8
        bcc     lb_dia
        lda     #1
; 50AF hud_set_and_draw_day: game_day := A and its three numeral glyphs (hud_roman_days + 3 (day - 1)) at
; ED09h; game_hour := 0, the scroll (9) and the duration.
hud_set_and_draw_day:
        sta     D64_GAME_DAY
lb_dia: sec
        sbc     #1
        sta     zt0
        asl     a
        clc
        adc     zt0
        clc
        adc     #<D64_HUD_ROMAN_DAYS
        sta     zde
        lda     #>D64_HUD_ROMAN_DAYS
        adc     #0
        sta     zde+1
        lda     #<$ED09
        sta     zhl
        lda     #>$ED09
        sta     zhl+1
        jsr     hud_draw_day_numeral
        jsr     hud_draw_day_numeral
        jsr     hud_draw_day_numeral
        lda     #0
lb_hora:
        sta     D64_GAME_HOUR
.ifdef C128
        cmp     #6                      ; the C128: completas, the PC version's Ave Maria (its 5AAF-5AB3;
        bne     :+                      ; plataforma/c128.s c128_ave; 3 NOPs when the menu's option 4 is off)
::c128_ave_llamada:
        jsr     c128_ave
:
.endif
        lda     #9
        sta     D64_HUD_HOUR_SCROLL_STEPS
        jmp     ai_clock_load_duration
```

The call `sys_key_pressed(6)` followed by `util_return_zero` is the trace of a developers' key that skipped to the next
hour: the original disabled it by making the test always false, and the translation keeps it as it is.  On the C128,
at completas, the hour change also plays the Ave María of the PC version (`c128_ave`, see [The Commodore 128](C128.md)).

## Hours that end by the story

Most hours have no time limit: a script sets `AI_ADVANCE_HOUR` (for example the abbot, when every monk is in the
church and he has said *OREMOS*; or Adso, when Guillermo answers yes to *¿DORMIMOS?, MAESTRO*).  The hour then
advances as soon as no phrase is being shown — so the last phrase of a scene is always heard — and never while the
character the camera follows is between two steps:

[`src/c64/juego_final/estado_texto.s`](../../src/c64/juego_final/estado_texto.s#L373-L394), lines 373–394:

```asm
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
```

## What happens at each hour

`ai_hour_change_events` runs once each time the hour differs from the last one handled.  It is one of the game's
scripts: a list of tests and actions in the original's own bytecode (see [The monks' minds](Monks.md)), translated by
a generator into the same bytecode with 6502 operands, with every expression written above it as a comment:

[`src/c64/juego_final/logica_b_guiones.s`](../../src/c64/juego_final/logica_b_guiones.s#L1118-L1162), lines 1118–1162:

```asm
; 5A4F ai_hour_change_events
ai_hour_change_events:
        jsr     logica_b_vm
L5A4F:
        ; [game_hour] [ai_last_hour_done] =
        PRUEBA   $E7, $10, $54, L5A58
T5A4F:
        .byte   $C9
L5A58:
        .byte   $D7, $54, $88  ; [ai_last_hour_done] := [game_hour]
        .byte   $CD, 4, 0, $00  ; game_set_c004_inline
        ; [game_hour]
        PRUEBA3  $EB, $10, T5A5F
T5A5F:
        .byte   $CD, 10, 0  ; util_jump_table_inline
        .word   L5A75, L5A91, L5AE2, L5AE9, L5AFC, L5B0F, L5B13, 0
        .byte   $C9
L5A75:
        ; [game_day] 05h =
        PRUEBAP $F8, D64_CHR_BACKUP+24, $05, L5A81
T5A75:
        .byte   $CD
        .word   obj_place_glasses
        .byte   $CD
        .word   obj_place_key1
L5A81:
        ; [game_day] 06h =
        PRUEBAP $F8, D64_CHR_BACKUP+24, $06, L5A90
T5A81:
        .byte   $CD
        .word   obj_place_key3
        .byte   $CD
        .word   chr_jorge_appears
        .byte   $D8, $5A, $00  ; [ai_severin_slot_busy] := 00h
L5A90:
        .byte   $C9
L5A91:
        .byte   $CD
        .word   vid_spiral_wipe
        .byte   $D8, $3C, $EF  ; [obj_door_check_mask] := EFh
        .byte   $CD
        .word   vid_palette_day
        .byte   $CD
        .word   obj_open_left_wing_doors
        .byte   $CD
```

| Hour | Every day | Some days |
|---|---|---|
| night | | day V: the glasses and key 1 placed; day VI: key 3 placed, Jorge appears in Severino's slot |
| prima | the spiral transition, the doors' mask for the day, the day palette, the left wing's doors opened, the bells | from day III the lamp in the kitchen; day II Guillermo loses the glasses; day III Jorge gets the book, Berengario vanishes, the parchment goes to the abbot if Guillermo has not taken it; day V key 1 removed if Guillermo has not got it |
| tercia | the spiral transition, the bells | |
| sexta | the bells | day IV: Bernardo Gui arrives in Berengario's slot |
| nona | the spiral transition, the bells | day III: Berengario's slot set free |
| vísperas | the bells | |
| completas | the spiral transition, the night palette, the doors' mask for the night, the bells | |

The *spiral transition* (`vid_spiral_wipe`) fills the play area with two square spirals and makes the room be drawn
again; the *doors' mask* (`OBJ_DOOR_CHECK_MASK`) decides which doors each character may open at that time of day.

## The ceremonies

At prima and vísperas the monks go to the church; at sexta to the refectory.  The abbot goes to his place, and only
when every living monk has reached his own (the script sums their `reached` values) does he check Guillermo:

* absent: the abbot counts; after C8h frames he comes to expel him;
* present but late (after 32h frames of waiting): *LLEGÁIS TARDE, FRAY GUILLERMO*, and the obsequium goes down by 2;
* in the room but not at his exact place (church: x 84h, y 4Bh facing the altar; refectory: 38h, 39h): every 1Eh
  frames *OCUPAD VUESTRO SITIO, FRAY GUILLERMO*, and −2;
* at his place: the prayer or the announcement of the day, and the hour advances.

Adso reminds Guillermo once per ceremony (*DEBEMOS IR A LA IGLESIA, MAESTRO*).  At completas the abbot sends the
monks to their cells and follows Guillermo to his; at night, when Guillermo has been out of his cell for a while, the
abbot leaves his own to look for him, and expels him if he finds him.
