<!-- Made by tools/wiki.py from doc/wiki/fuentes/Characters.md: edit the template, not this page. -->
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

[`src/c64/juego_final/personajes.s`](../../src/c64/juego_final/personajes.s#L577-L607), lines 577–607:

```asm
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
```

A step takes two frames (the half step of the animation counter's bit 0); between two steps the character's
**behaviour routine** runs: for Guillermo, the keys; for the others, their movement commands.

## Guillermo

Turning is immediate and edge-triggered; advancing is held:

[`src/c64/juego_final/personajes.s`](../../src/c64/juego_final/personajes.s#L834-L852), lines 834–852:

```asm
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
```

Before advancing, the game reads a 4 x 4 window of heights in front of the character (`chr_probe_ahead`) from the
room's **height buffer** (24 x 24 cells around the room: the floor's height, or the mark of a character standing
there).  The two cells ahead decide: level ground, one unit up, one unit down, or blocked.  On stairs a character
occupies one cell; on level ground 2 x 2:

[`src/c64/juego_final/personajes.s`](../../src/c64/juego_final/personajes.s#L779-L805), lines 779–805:

```asm
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
```

## The others: command streams

Adso and the monks do not decide their steps one at a time.  Their minds (see [The monks' minds](Monks.md)) choose a
destination, the path finder ([Heights and path finding](Paths.md)) computes a route, and the route is written as a
**bit stream** of commands in the character's command buffer.  Each step, `chr_ai_follow_commands` reads the next
command:

[`src/c64/juego_final/personajes.s`](../../src/c64/juego_final/personajes.s#L1340-L1344), lines 1340–1344:

```asm
; 280D chr_read_command: decodes one command of character IY's bit stream into C (C flag clear).  1-cell: '1b'
; -> b.  2x2: '1' -> 1.  Both: '01b' -> 2+b (a turn), '001b' -> 4+b, '0000' -> 0 for a 1-cell character, or the
; stream restarts ([IY+0B] = [IY+9] = 0) and is read again (2x2).  '0001' = the end: bit 7 of [IY+9] set and
; the C flag set (the Z80 POPs its return address and the step 278F pushed, returning from 278F; its only
; caller, 278F, does so on the flag).
```

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

[`src/c64/juego_final/personajes.s`](../../src/c64/juego_final/personajes.s#L1056-L1064), lines 1056–1064:

```asm
; 2632 chr_project: projects character (or object, door) IY onto the screen, sprite IX.  Local x = [IY+2] -
; [2636], y = [IY+3] - [2640], each < 28h; the floor of [IY+4] must be [264E]; h = the height over it.  The camera
; rotation [2656] turns (x, y) (HL); they go to [IX+12h,13h].  Visible when r = x+y-h-6 is in 8..39h (row 4(r+1))
; and the column 2(x-y)+28h in 0..4Fh: then the return address is dropped (it returns to its caller's caller) and
; the depth is max(0, x+y-10h).  Not visible: a plain return.  Test mode ([2684] = C9h, set by 0ABC): A = the
; depth, HL = row:column, C = x+y.  Normal mode: plus the per-orientation offset of the table [28D5] (+16 per
; camera-relative orientation, +2 per frame chosen from [IY], [IY+5]) and [IY+7] / [IY+8]: the sprite's x
; (bytes) and y (lines) in [IX+1,2] (and [IX+3,4] when the sprite was inactive), HL = them; C = the depth.
        .assert D64_CHR_ROOM_ORIGIN_Y = D64_CHR_ROOM_ORIGIN_X + 1, error, "chr_project: the origins contiguous"
```

The animation table gives, for the camera-relative orientation and the counter, the graphic, its width and its height.
Two orientations of four are drawn from the same graphics mirrored: when a character's camera-relative facing changes,
its graphics are flipped **in place** (`spr_flip_guillermo`, `spr_flip_adso`, and the monks' faces), as the CPC did,
on the C64's sprite format (two pixels in a byte, the nibbles swapped through a table).
