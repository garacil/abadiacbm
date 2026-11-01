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

{{code src/c64/juego_final/principal.s | ^\.proc principal_inicio | ^\.endproc}}

## A new game

`game_main` runs the one-time start-up (`sys_startup_init`, which also rebuilds the C64's merge tables), then every
new game: it waits until SPACE is released, puts every record at its initial state, places Guillermo at the start
square and Adso beside him, sets the clock to day I, nona, and gives the five monks' command buffers an empty
command.  `reanuda` is also where a loaded game continues:

{{code src/c64/juego_final/principal.s | ^\.proc game_main | ^reanuda:}}

## The frame

Each pass of `bucle` is one frame of the game.  The comments give the Z80 address of each step: the order is the
original's, step by step.

{{code src/c64/juego_final/principal.s | ^bucle:  +; 2179 | ^        jmp     bucle}}

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

{{code src/c64/plataforma/interrupcion.s | ^; the game's build \(-D JUEGO; the speed | ^\.endproc}}

Two details of the 6502 version: the sound's call is an instruction rewritten in place (`JSR` while a channel plays,
`BIT` when nothing does: the common case costs no call), and the handler sets the I/O visible itself, because the game
may be reading the graphics under the I/O when the tick comes.  An empty tick costs 69 cycles.

## The game's speed

The frame's budget, `SYS_FRAME_TICKS`, is 36 ticks (120 ms) while the player plays.  When no movement key has been
pressed for 50 frames the budget becomes 0 — the game runs as fast as the machine allows, unless a phrase is being
shown — and the camera may move to the character the story wants to show:

{{code src/c64/juego_final/logica_a.s | ^; 3CC5 game_camera_select | ^\.endproc}}

So the original's speed depends on how much each frame draws.  The CPC game is often slower than its budget; the
C64 game was made faster than the CPC (VICE, no keys from the start: frames 1-2000 in 122.5 s on the C64 against
294.2 s on a CPC 6128, see `doc/ESTADO.md`), and the C128 runs at 2 MHz while the beam is in the borders.
