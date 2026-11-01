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

# Characters and movement

[Home](Home.md) · previous: [Rooms and the isometric engine](Isometric-engine.md) · next: [Sprites and the screen](Sprites.md)

## The character records

Each of the six characters has a record of 15 bytes (`CHR_GUILLERMO` and the five after it, in the order Guillermo,
Adso, Malaquías, the abbot, Berengario's slot, Severino's slot):

| Offset | Meaning |
|---|---|
| +0 | the animation counter, 0-3 (bit 0 set: half-way through a step) |
| +1 | the orientation, 0-3 (0 = +x, 1 = −y, 2 = −x, 3 = +y) |
| +2, +3, +4 | x, y and the height |
| +5 | flags: bit 7 = the character occupies one cell (on stairs) instead of 2 x 2; bit 5 = turned across a slope; bit 4 = going down |
| +6 | the flip state of its graphics |
| +7, +8 | the sprite's offset |
| +9 | the command bit counter (bit 7 = no commands) |
| +0A, +0B, +0C-0D | the current command byte, its index and the command stream's address |
| +0E | the mark the character leaves in the height buffer (10h or 20h) |

A second table, `CHR_TABLE` (10 bytes per character), links each one to its sprite, its record, its behaviour
routine, the routine that flips its graphics and its animation table.

## One step of one character

Each frame, every character goes through `chr_update`: it leaves the height buffer (so that it does not block
itself), thinks or finishes its step, and marks the height buffer again:

{{code src/c64/juego_final/personajes.s | ^; 2472 chr_update | ^\.endproc}}

A step takes two frames (the half step of the animation counter's bit 0); between two steps the character's
**behaviour routine** runs: for Guillermo, the keys; for the others, their movement commands.

## Guillermo

Turning is immediate and edge-triggered; advancing is held:

{{code src/c64/juego_final/personajes.s | ^; 2561 chr_turn | ^\.endproc}}

Before advancing, the game reads a 4 x 4 window of heights in front of the character (`chr_probe_ahead`) from the
room's **height buffer** (24 x 24 cells around the room: the floor's height, or the mark of a character standing
there).  The two cells ahead decide: level ground, one unit up, one unit down, or blocked.  On stairs a character
occupies one cell; on level ground 2 x 2:

{{code src/c64/juego_final/personajes.s | ^; 250C chr_try_advance_2x2 | ^\.endproc}}

## The others: command streams

Adso and the monks do not decide their steps one at a time.  Their minds (see [The monks' minds](Monks.md)) choose a
destination, the path finder ([Heights and path finding](Paths.md)) computes a route, and the route is written as a
**bit stream** of commands in the character's command buffer.  Each step, `chr_ai_follow_commands` reads the next
command:

{{code src/c64/juego_final/personajes.s | ^; 280D chr_read_command | +5}}

| Bits | Command |
|---|---|
| `1` (2 x 2), `1b` (one cell) | advance (one cell: b = 0 climb or level, 1 go down) |
| `01b` | turn (+1 or −1) |
| `001b` | climb or go down changing size |
| `0000` | restart the stream (2 x 2) |
| `0001` | the end: no more commands |

If the move fails (another character is in the way), the ten bytes of position saved before the attempt are put back.

## From the world to the screen

`chr_project` turns a position into a sprite position: local coordinates relative to the room, rotated by the
camera's orientation, then the isometric projection — the row from `x + y − height`, the column from `x − y`:

{{code src/c64/juego_final/personajes.s | ^; 2632 chr_project | +9}}

The animation table gives, for the camera-relative orientation and the counter, the graphic, its width and its height.
Two orientations of four are drawn from the same graphics mirrored: when a character's camera-relative facing changes,
its graphics are flipped **in place** (`spr_flip_guillermo`, `spr_flip_adso`, and the monks' faces), as the CPC did,
on the C64's sprite format (two pixels in a byte, the nibbles swapped through a table).
