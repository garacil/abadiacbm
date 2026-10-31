<!-- Made by tools/wiki.py from doc/wiki/fuentes/Isometric-engine.md: edit the template, not this page. -->
# Rooms and the isometric engine

[Home](Home.md) · previous: [The clock and the ceremonies](Clock.md) · next: [Characters and movement](Characters.md)

The abbey is a world of 256 x 256 positions on three floors (the ground, the first floor with the scriptorium, and
the library under the roof), cut into **rooms** of 16 x 16 positions.  Only one room is shown at a time, drawn in
isometric projection; when the character the camera follows walks out of it, the next room is built and drawn.

## Which room, and from which side

The floor maps give a room number for each 16 x 16 square of each floor.  Every frame `iso_update_camera_room`
checks the square of the character the camera follows (`x & F0h`, `y & F0h`, the floor of its height); when it
changed, it selects the room, and also the **camera's orientation**, which depends on the room's position: the
abbey is seen from a different side in neighbouring rooms, one of the game's best-known traits.

[`src/c64/juego_final/motor_iso.s`](../../src/c64/juego_final/motor_iso.s#L938-L946), lines 938–946:

```asm
; 1F79 iso_update_camera_room: main-loop step.  The record of the character the camera follows ([28D9h]): x & F0h
; vs 28C6h (then the origin x 2636h = x - 0Ch), y & F0h vs 28C7h (origin y), the floor base of its height vs
; 28C8h (then the floor 264Eh and the floor map 2013h); each one that changed is stored and counted; none ->
; return (A = 0).  Else 2909h = the count; the room is dark (11DCh = 1) on floor 16h with room x >= 20h but the
; room (20h, 60h); the light sprite 2B20h = FEh; the camera orientation 20A5h = ((X ^ Y) & 1) | (X & 1) << 1 of
; the room coordinates; iso_select_room(map[Y << 4 | X]); chr_fill_height_buffer; the sprite offsets 28D5h =
; 2BF0h + 40h * orientation; the camera transform 2656h = the word 1E81h[orientation]; doors and objects placed;
; then for each chr_table entry (10 bytes, FFh in byte 1 ends): 2070h = sprite, 2074h = record, 25AEh = word +6,
; 25D9h = word +8, spr_update_char_sprite and chr_mark_hbuf (C = [record + 0Eh]).  Out: A = FFh (0 unchanged).
```

## Rooms are programs

A room is not a picture.  Its record in the room table (`ISO_ROOM_TABLE`: 129 records in the 64 KiB game) is a list of
**entries**, three or four bytes each, and each entry places a **block** — a wall, a floor, a staircase, an arch, a
table, a bookcase... — at a position of the room's grid, with two size parameters and an optional height:

| byte | bits | meaning |
|---|---|---|
| 0 | 7-1 | the block type: an even number, the index of a word in the block table |
| 0 | 0 | 1 = a height byte follows |
| 1 | 4-0, 7-5 | x (0-31) and the first size parameter p1 (0-7) |
| 2 | 4-0, 7-5 | y (0-31) and the second size parameter p2 (0-7) |
| 3 | 7-0 | the height (when present) |

`FF` ends the record.  `iso_draw_room` clears the tile buffer, fills the play area (black for a dark room) and runs
the record; a lit room is then drawn from the tile buffer:

[`src/c64/juego_final/motor_iso.s`](../../src/c64/juego_final/motor_iso.s#L271-L304), lines 271–304:

```asm
; 1611 iso_draw_room: builds and shows the current room: the tile buffer cleared and the play area filled with
; 00h (lit) or FFh (dark, D64_ISO_ROOM_DARK not 0); iso_build_room on the record [11DAh] + 1 with the cell update
; of iso_put_tile (12C0h = 12C9h; 12C2h after it); a lit room is then drawn (iso_draw_room_spiral, a tail jump).
iso_draw_room:
        lda     D64_ISO_ROOM_DARK
        beq     :+
        lda     #$FF
:       jsr     iso_clear_tile_buffer
.ifdef C128
        jsr     far_sala                ; the C128: the record from block 1 into SALA (plataforma/c128.s)
        lda     #<(SALA + 1)
        sta     zix
        lda     #>(SALA + 1)
        sta     zix+1
.else
        lda     D64_ISO_ROOM_PTR
        clc
        adc     #1
        sta     zix
        lda     D64_ISO_ROOM_PTR+1
        adc     #0
        sta     zix+1
.endif
        lda     #<MI_PUT_TILE_UPDATE
        sta     D64_ISO_PUT_TILE_JUMP
        lda     #>MI_PUT_TILE_UPDATE
        sta     D64_ISO_PUT_TILE_JUMP+1
        jsr     iso_build_room
        lda     #<MI_PUT_TILE_MARK
        sta     D64_ISO_PUT_TILE_JUMP
        lda     D64_ISO_ROOM_DARK
        bne     :+
        jmp     iso_draw_room_spiral
:       rts
```

`iso_build_room` decodes one entry after another.  Before entering a block it pushes its own address as the return
tag, so that the block's `END` comes back to it for the next entry, as the Z80 did with its own stack:

[`src/c64/juego_final/motor_iso.s`](../../src/c64/juego_final/motor_iso.s#L306-L375), lines 306–375:

```asm
; 163F iso_build_room: interprets the room entries at IX up to a byte FFh.  Entry: byte 0 = block type (bits 1-7:
; the word of the block table) | bit 0 (a height byte follows); byte 1 = x | p1 << 5; byte 2 = y | p2 << 5;
; [byte 3 = height].  For each: the block at 1697h (D64_ISO_CUR_BLOCK), depth 0, 0, height (1BEBh) = the byte or
; FFh; HL = y, x, BC = p2, p1; the tag (this routine) pushed; the block entered with its tile list; its END pops
; IX = the next entry and returns here.  Out: IX = the FFh, A = FFh.
iso_build_room:
        ldy     #0
        lda     (zix),y
        cmp     #$FF
        bne     :+
        rts
:       and     #$FE
        tax
        lda     D64_ISO_BLOCK_TABLE,x
        sta     D64_ISO_CUR_BLOCK
        lda     D64_ISO_BLOCK_TABLE+1,x
        sta     D64_ISO_CUR_BLOCK+1
        ldx     #0                      ; L = x, C = p1; H = y, B = p2
:       iny
        lda     (zix),y                 ; x | p1 << 5, y | p2 << 5
        pha
        and     #$1F
        sta     zhl,x
        pla
        lsr
        lsr
        lsr
        lsr
        lsr
        sta     zbc,x
        inx
        cpx     #2
        bne     :-
        lda     #0
        sta     D64_ISO_DEPTH_X
        sta     D64_ISO_DEPTH_Y
        ldy     #0
        lda     (zix),y
        lsr                             ; C = a height follows
        lda     #$FF
        ldy     #3
        bcc     :+
        lda     (zix),y
        iny
:       sta     D64_ISO_BLOCK_HEIGHT
        tax
        tya                             ; IX past the entry
        clc
        adc     zix
        sta     zix
        bcc     :+
        inc     zix+1
:       lda     #>(iso_build_room-1)    ; the tag 163Fh: END returns to the next entry
        pha
        lda     #<(iso_build_room-1)
        pha
        ldy     #0                      ; DE = the tile list, the script after it
        lda     (D64_ISO_CUR_BLOCK),y
        sta     zde
        iny
        lda     (D64_ISO_CUR_BLOCK),y
        sta     zde+1
        lda     D64_ISO_CUR_BLOCK
        clc
        adc     #2
        sta     mi_ptr
        lda     D64_ISO_CUR_BLOCK+1
        adc     #0
        sta     mi_ptr+1
        txa                             ; A = the height
```

## The block interpreter

Each block is a list of 12 tile numbers and a small **bytecode** program that puts those tiles into the tile buffer.
The opcodes are stored complemented (`FF` is opcode 0), and the dispatcher jumps to the handler through a table of
addresses with an `RTS`, the 6502's equivalent of the Z80's `PUSH DE / RET`:

[`src/c64/juego_final/motor_iso.s`](../../src/c64/juego_final/motor_iso.s#L402-L416), lines 402–416:

```asm
; 1C2C the dispatcher: op = [IX++], the handler of ~op (opcodes FFh down to E4h), entered by RTS as the Z80's
; PUSH DE / RET; every handler comes back here.
mi_dispatch:
        ldy     #0
        lda     (zix),y
        inc     zix
        bne     :+
        inc     zix+1
:       eor     #$FF
        tax
        lda     mi_ops_hi,x
        pha
        lda     mi_ops_lo,x
        pha
        rts
```

[`src/c64/juego_final/motor_iso.s`](../../src/c64/juego_final/motor_iso.s#L727-L738), lines 727–738:

```asm
; the handlers of opcodes FFh down to E4h (index ~op), minus one for the RTS
mi_ops_lo:
        .lobytes mi_op_end-1, mi_op_loop_p1-1, mi_op_loop_p2-1, mi_op_push_pos-1, mi_op_pop_pos-1, mi_op_next-1
        .lobytes mi_op_up-1, mi_op_right-1, mi_op_set-1, mi_op_y_inc-1, mi_op_x_inc-1, mi_op_y_dec-1
        .lobytes mi_op_x_dec-1, mi_op_y_add-1, mi_op_x_add-1, mi_op_p1_inc-1, mi_op_p2_inc-1, mi_op_p1_dec-1
        .lobytes mi_op_p2_dec-1, mi_op_call-1, mi_op_left-1, mi_op_jump-1, mi_op_mirror-1, mi_op_mirror-1
        .lobytes mi_op_mirror-1, mi_op_mirror-1, mi_op_mirror-1, mi_op_call_keep-1
mi_ops_hi:
        .hibytes mi_op_end-1, mi_op_loop_p1-1, mi_op_loop_p2-1, mi_op_push_pos-1, mi_op_pop_pos-1, mi_op_next-1
        .hibytes mi_op_up-1, mi_op_right-1, mi_op_set-1, mi_op_y_inc-1, mi_op_x_inc-1, mi_op_y_dec-1
        .hibytes mi_op_x_dec-1, mi_op_y_add-1, mi_op_x_add-1, mi_op_p1_inc-1, mi_op_p2_inc-1, mi_op_p1_dec-1
        .hibytes mi_op_p2_dec-1, mi_op_call-1, mi_op_left-1, mi_op_jump-1, mi_op_mirror-1, mi_op_mirror-1
```

| Opcode | Meaning |
|---|---|
| `FF` END | back to the caller (the next room entry, or the block that called this one) |
| `FE` / `FD` LOOP | repeat until `FA` NEXT p1 or p2 times |
| `FC` / `FB` | push / pop the position |
| `F9` / `F8` / `EB` | a run of tiles: up, right, left, one cell after each |
| `F7` SET | a register := an expression (operands: literals, the tile registers, p1, p2, the height, the depth) |
| `F6`-`F1` | move the position: y+1, x+1, y−1, x−1, y += expr, x += expr |
| `F0`-`ED` | p1 / p2 + 1 or − 1 |
| `EC` CALL, `E4` CALL_KEEP | run another block here (with its own tiles, or keeping these) |
| `EA` JUMP | continue in another block's program: most blocks share code this way |
| `E9`-`E5` MIRROR | mirror the x direction until the block's END: a wall facing the other way is the same block mirrored |

A floor, for example, is two nested loops (p2 + 1 rows of p1 + 1 tiles) of `TILES_UP t1, t1` plus an edge, and a
front border; a thicker wall is the same program as a thin one with another tile list.  The whole abbey is drawn by fewer than a
hundred blocks of a few dozen bytes each (88 in the 64 KiB game's block table).

## The tile buffer and the depth

The visible part of the grid is 16 x 20 cells of 16 x 8 pixels.  Each cell of the tile buffer keeps the last **two**
tiles put into it (the lower one is drawn first), and for each a **depth**: the block's position in the world, so that
the sprite engine can later decide, pixel by pixel, whether a tile hides a character.

[`src/c64/juego_final/motor_iso.s`](../../src/c64/juego_final/motor_iso.s#L86-L91), lines 86–91:

```asm
; 1295 iso_put_tile: puts tile C at the grid position HL (H = y, L = x) when it is visible (y - 8 < 14h,
; x - 8 < 10h).  The cell is tile buffer + 96 (y - 8) + 6 (x - 8): the old tile [5] becomes the lower tile [2];
; [0],[1] = the old depth [3],[4], or the current depth (1BECh, 1BEDh) when it is smaller in both; [3],[4] = the
; current depth; [5] = the tile.  Out: A = the depth y put, or the coordinate that failed (y - 8, x - 8).
; HL, BC kept; X, Y clobbered.  (DE, which no caller reads, is not set.)
iso_put_tile:
```

The depth of a block comes from its position and its height, as the inverse of the projection of the characters:

[`src/c64/juego_final/motor_iso.s`](../../src/c64/juego_final/motor_iso.s#L912-L932), lines 912–932:

```asm
; 1BC6 iso_block_depth: the depth of the block from its position HL (H = y, L = x) and height A: nothing for
; FFh; else t = A / 2 + y, depth x (1BECh) = t + x - 0Fh, depth y (1BEDh) = 10h + t - x.  X clobbered.
iso_block_depth:
        cmp     #$FF
        beq     @r
        lsr
        clc
        adc     zhl+1
        tax
        clc
        adc     zhl
        sec
        sbc     #$0F
        sta     D64_ISO_DEPTH_X
        txa
        clc
        adc     #$10
        sec
        sbc     zhl
        sta     D64_ISO_DEPTH_Y
@r:     rts
```

## Drawing

A lit room is drawn from the tile buffer in a spiral from the centre outwards (`iso_draw_room_spiral`); each tile is
8 lines in the C64's multicolour format, 4 bytes a line; the tiles below 0Bh are copied opaque, the others merged
through the AND/OR tables.  The tiles live under the I/O (`$D000`), so the drawing switches the I/O off while it reads them.
A dark room (the library's rooms on the top floor, all but one) leaves the play area black and only the lamp's light shows (see
[Sprites and the screen](Sprites.md)).
