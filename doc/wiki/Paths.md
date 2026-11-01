<!-- Made by tools/wiki.py from doc/wiki/fuentes/Paths.md: edit the template, not this page. -->
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

# Heights and path finding

[Home](Home.md) · previous: [Sprites and the screen](Sprites.md) · next: [The monks' minds](Monks.md)

The monks walk on their own through the whole abbey: up and down stairs, through doors, from one room to another and
from one floor to another.  They do it with two breadth-first searches — one inside a room, one between rooms — and
a writer that turns the path found into movement commands.  It is the heaviest work of the game: almost half of the
C64's cycles in the recorded sessions.

## The height buffer

Every room has a **height buffer**: 24 x 24 cells (the room's 16 x 16 positions and a border of 4), each the height
of the floor there (low nibble) or the mark of a character standing on it (10h, 20h).  It is filled when the room
changes, from the floor's list of height records (flat areas, slopes, steps):

[`src/c64/juego_final/personajes.s`](../../src/c64/juego_final/personajes.s#L1525-L1527), lines 1525–1527:

```asm
; 2873 chr_fill_height_buffer: clears the 24x24 height buffer [28DB] (240h bytes), sets the window origin from
; the room of character IY (07FF iso_grid_set_origin, which returns the floor base 0 / 0Bh / 16h), [3454] = the
; floor's height data and fills the buffer (JP 3456 chr_hbuf_fill_room).
```

The characters' probes read it to decide each step (see [Characters and movement](Characters.md)); the searches use a
second buffer of the same kind, built around the character that is looking for a route, so that a monk in another
room can plan without disturbing the room on the screen.

## Choosing the kind of search

`chr_path_find` is the entry: route a character to a target position.  Another floor: towards the stairs that go up
or down; another room of the same floor: through the graph of rooms; the same room: a search in the height buffer:

[`src/c64/juego_final/camino.s`](../../src/c64/juego_final/camino.s#L662-L671), lines 662–671:

```asm
; 05FA chr_path_find: route chr towards the target position (x, y, orient<<6 | z).  chr_path_result [2907]
; = FE; nothing while Guillermo is in mid-step ([0600] odd) or when a route was found in this iteration
; ([28FA]).  Else the floor test of the room search [440D] = BIT 6,(HL), [2907] = 0, chr_path_room_links_ptr
; [3F73] = the room links of the character's floor.  Other floor: stairs in the character's room in the
; wanted direction (bit 10h up / 20h down) -> every grid cell of height [0692] (0Dh / 01h) becomes a target
; (076D); else the room graph (4399, BIT 4 / BIT 5,(HL)) gives the nearest room with stairs (DE) -> 0734.
; Same floor: another room -> chr_path_via_rooms; the same cell -> [2907] = FD and chr_path_face_target;
; another cell -> the grid towards it (chr_path_search_to_dest).  In: IY = chr, IX = target.  Out: CF = a
; route was found (or chr_path_face_target's carry).
.proc chr_path_find
```

## The search inside a room

The search is a breadth-first expansion over the height buffer from the character's cell: each queued position
tries its four neighbours, which must be walkable from it (the same height or one unit up or down, for a character
of 2 x 2 cells), and marks them visited (bit 7), until a cell marked as a target (bit 6) is reached.  The room's border
is marked visited first, so that the search stays inside:

[`src/c64/juego_final/logica_a_cam.s`](../../src/c64/juego_final/logica_a_cam.s#L129-L169), lines 129–169:

```asm
.proc la_sala
        lda     D64_CHR_HBUF_PTR        ; rows 0 and 23 ...
        sta     la_c
        clc
        adc     #<$228
        sta     la_s
        lda     D64_CHR_HBUF_PTR+1
        sta     la_c+1
        adc     #>$228
        sta     la_s+1
        ldy     #23
:       lda     (la_c),y
        ora     #$80
        sta     (la_c),y
        lda     (la_s),y
        ora     #$80
        sta     (la_s),y
        dey
        bpl     :-
        ldx     #23                     ; ... columns 23 and 0: Y = 24 r - 1 and 24 r (never FFh and 0), la_c a page
        ldy     #23                     ; further when Y passes FFh
col:    lda     (la_c),y
        ora     #$80
        sta     (la_c),y
        iny
        lda     (la_c),y
        ora     #$80
        sta     (la_c),y
        tya
        clc
        adc     #23
        tay
        bcc     :+
        inc     la_c+1
:       dex
        bne     col
        lda     #1
        sta     D64_CHR_PATH_LENGTH
        lda     #0
        beq     la_busca                ; (always)
.endproc
```

The Z80 used its own **stack** as the search's queue: it pushed the positions and walked the stack pointer through
them.  The 6502's stack has only 256 bytes, so the translation keeps the queue in memory, at the same addresses,
growing downwards as the Z80's did — and writes into it the same words the Z80's `CALL`s and `PUSH`es left there, so
that the memory stays equal to the original's byte for byte (the certification compares it).

## Between rooms and floors

The floor map (one byte per room) works as a smaller grid: the same search runs over it to find the sequence of rooms
towards the target room, the doors being edges that the doors' permissions open or close.  The character then
searches a route inside its room to the band of cells that leads to the next room.  To change floor, every cell of
the stairs' height becomes a target.

## From the path to the commands

The search leaves, in its queue, the cell that reached the target.  `chr_cmd_write_path` walks the queue backwards
to rebuild the path, then simulates the character's walk along it and writes the commands — turns and steps — into
its command buffer as the bit stream the character will read one step at a time:

[`src/c64/juego_final/logica_a_cam.s`](../../src/c64/juego_final/logica_a_cam.s#L1506-L1513), lines 1506–1513:

```asm
; 41C9 chr_cmd_write_path: the default generator: rebuilds the path the room search found and writes its
; commands.  DI, sys_ticks := FFh; from chr_path_solution (the queue word that reached the target) the queue is
; read towards older entries and 3-byte records (x, y, orientation) are written at the sprite buffer after an
; FFh: the target with chr_path_orientation XOR 2, then for each earlier level the first queued cell next to the
; current one along one axis (chr_path_dy_tmp, chr_path_candidate), until chr_path_origin; EI.  Then from the last
; record back to the FFh: a turn (a 1-cell character turning to the other axis toggles +5 bit 5),
; chr_cmd_write_turn, chr_probe_ahead and chr_cmd_write_step; records whose position the simulated character
; already passed are skipped.  In: IY.  Out: IX = the FFh record, A = FFh.  The DI ... EI are the checked build's
```

## Adso

Adso does not plan when he follows Guillermo: his driver measures the path length between them and takes one step
when they are far enough apart; when Guillermo walks into him, Adso steps aside, and the player can push him with the
*down* key (`chr_adso_step_aside`, `chr_adso_step_guillermo_dir`).

## The memo of the C128

With no keys pressed, the original repeats every frame some searches that fail in the same way (Severino from the
frame 674 of the start, for example: 1328 identical calls of 91 152 cycles each).  The C128's speed work keeps the
last failing room-to-room search — every byte it reads as the key, every byte it writes as the result — and replays
it when the same call comes again: the 6502 being deterministic, the same inputs give the same outputs, and the
certification against the PC shows no difference.

[`src/c64/juego_final/camino_memo.s`](../../src/c64/juego_final/camino_memo.s#L16-L23), lines 16–23:

```asm
; abadia64ks, 6502 code of the game: a memo of the whole route search between rooms (M4, measured and
; verified in the speed work's round 5; M1 moved up to camino_room_to_room's entry).  camino_room_to_room (0734)
; searches the floor's room graph (chr_path_floor_to_screen, 8 700 cycles), clears its marks
; (chr_path_clear_room_marks, 4 070) and, when it found the next room, builds the character's grid, marks the exit
; band and searches it (~77 000 cycles when that fails).  The Z80 repeats that failing call every frame while
; nothing changes (Severin from frame 674 of the no-keys run); this memo keeps the last failing one: its inputs (the
; key) and the compared bytes it left (the outputs).  A later call whose key equals the stored one replays the
; outputs and returns as the call returns (C = 0): the 6502 being deterministic, a call that reads the same bytes
```
