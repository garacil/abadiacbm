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

{{code src/c64/juego_final/logica_b.s | ^; 5028 ai_clock_init | ^        rts}}

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

{{code src/c64/juego_final/logica_b.s | ^; 5060 ai_clock_load_duration | ^\s+rts}}

Every frame the counter goes down; when it reaches 0 the hour advances.  After completas the day advances, its
numeral is redrawn on the score bar, and the name of the new hour scrolls in (`HUD_HOUR_SCROLL_STEPS` = 9 steps):

{{code src/c64/juego_final/logica_b.s | ^; 507D ai_clock_tick | ^\s+jmp     ai_clock_load_duration}}

The call `sys_key_pressed(6)` followed by `util_return_zero` is the trace of a developers' key that skipped to the next
hour: the original disabled it by making the test always false, and the translation keeps it as it is.  On the C128,
at completas, the hour change also plays the Ave María of the PC version (`c128_ave`, see [The Commodore 128](C128.md)).

## Hours that end by the story

Most hours have no time limit: a script sets `AI_ADVANCE_HOUR` (for example the abbot, when every monk is in the
church and he has said *OREMOS*; or Adso, when Guillermo answers yes to *¿DORMIMOS?, MAESTRO*).  The hour then
advances as soon as no phrase is being shown — so the last phrase of a scene is always heard — and never while the
character the camera follows is between two steps:

{{code src/c64/juego_final/estado_texto.s | ^; 3A37 ai_hour_update | ^@r:     rts}}

## What happens at each hour

`ai_hour_change_events` runs once each time the hour differs from the last one handled.  It is one of the game's
scripts: a list of tests and actions in the original's own bytecode (see [The monks' minds](Monks.md)), translated by
a generator into the same bytecode with 6502 operands, with every expression written above it as a comment:

{{code src/c64/juego_final/logica_b_guiones.s | ^; 5A4F ai_hour_change_events | +45}}

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
