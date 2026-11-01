<!-- Made by tools/wiki.py from doc/wiki/fuentes/Objects.md: edit the template, not this page. -->
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

# Objects, doors and the mirror

[Home](Home.md) · previous: [The monks' minds](Monks.md) · next: [Text and the score bar](Text.md)

## Objects and holders

Nine object records (5 bytes each: flags, orientation, x, y, height) describe the book, the gloves, the glasses, the
parchment, the three keys, an unused slot and the lamp.  When an object is held (bit 7 of its flags), its x and y
bytes hold instead the address of its **holder**.  The holders are six entries of 7 bytes — Guillermo, Adso,
Malaquías, the abbot, Berengario's slot, Severino's slot:

| Offset | Meaning |
|---|---|
| +0 | flags (bit 7: holds the lamp; bit 0: cannot take objects now) |
| +1, +2 | the address of its character's x |
| +3 | the objects held, one bit each (80h the book, 40h the gloves, 20h the glasses, 10h the parchment, 08h key 1, 04h key 2, 02h key 3) |
| +4, +5 | the masks of what it may take (the lamp; the other objects) |
| +6 | a counter of frames between two takes or drops |

Guillermo starts with the glasses and may take everything but key 3; Adso may take only the lamp and key 3.

## Taking and dropping

Every frame `obj_update_inventory` runs the takes, the drops, the keys' permissions, the sounds, and redraws the
score bar's object slots:

[`src/c64/juego_final/logica_a.s`](../../src/c64/juego_final/logica_a.s#L1243-L1246), lines 1243–1246:

```asm
; 4BEC obj_update_inventory: once a frame: the objects picked up (4C46 from Guillermo's holder), dropped (4DC3),
; the key permissions (4D97); the inventory sounds of Adso (objects, lamp) and Guillermo; the manuscript read when
; Guillermo's glasses/parchment bits changed and he has both; the changed slots redrawn (4D30); bit 0 cleared in
; every object record.  Out: HL = the FFh record, BC = 5, A = FFh, ZF = 1.
```

An object is taken when it lies in the cell in front of a holder whose masks allow it — so Adso, walking behind
Guillermo, picks up the lamp or key 3 himself:

[`src/c64/juego_final/logica_b.s`](../../src/c64/juego_final/logica_b.s#L611-L615), lines 611–615:

```asm
; 4C46 obj_pick_up_objects: for each holder from IX to the FFh entry whose counter +6 runs out, the first object
; not taken this frame, not hidden, allowed by its masks and lying in front of it (its own position, or its
; holder's character's when held and the taker is not locked) is taken: from its old holder, spr_mark_leaving,
; record +0 := 81h, +2/+3 := the holder, holder +6 := 10h and its bit set.  The search stops when no allowed
; object is left (the Z80 goes on to the FFh record without effect).  Out: IX = the FFh entry.
```

SPACE drops Guillermo's first object in front of him, if that floor is free and level:

[`src/c64/juego_final/logica_b.s`](../../src/c64/juego_final/logica_b.s#L977-L991), lines 977–991:

```asm
; 4DC3 obj_drop_on_space: the space bar (CPC key 2Fh) down: Guillermo drops an object (into 4DCD).
obj_drop_on_space:
        lda     #$2F
        jsr     sys_key_down
        bne     :+
        rts
:       lda     #<D64_OBJ_CHAR_OBJECTS
        sta     zix
        lda     #>D64_OBJ_CHAR_OBJECTS
        sta     zix+1
; 4DCD obj_drop_object: holder IX drops its first object (the highest bit of +3) when its counter +6 runs out:
; in front of it if that cell of the height buffer (on the floor shown) is free, below 0Dh, at most 4 above the
; floor level and level with its three neighbours (else nothing); at its character's position when the floor
; or the buffer do not allow the test.  Then its record (bit 7 cleared, +4 height, +1 an orientation read
; where the original reads it, +2/+3 x/y) and obj_redraw_one_object.
```

The scripts move objects too, by copying five inline bytes into a record: the glasses and key 1 appear on day V, the
lamp in the kitchen from day III, Jorge takes the book, the abbot keeps the parchment in his cell.

## Keys and doors

Seven doors stand in the abbey.  Each frame `obj_update_doors` opens a door when a character allowed to pass stands
next to it, and closes it otherwise; a door's leaf is part of the height buffer, so a closed door blocks the way:

[`src/c64/juego_final/objetos_sonido.s`](../../src/c64/juego_final/objetos_sonido.s#L448-L456), lines 448–456:

```asm
; 0B1D obj_door_check_open_close: opens or closes door IY (sprite IX).  Fixed doors (bit 7 of [door+1]) are left
; alone.  C = [door+1] & 1Fh & ([D64_OBJ_DOOR_CHECK_MASK] | 10h); E, D = x - 2, y - 2.  If Guillermo or Adso
; lacks the bit (the other's mask ORed in) and stands near (obj_door_unpermitted_near), the door closes; else a
; permission entry with the bit standing at x-1..x+2, y-1..y+2 opens it; none closes it.  The change: the old
; leaf's cells get the door's height (obj_door_mark_cells with [door+4]), bit 6 set or cleared,
; [D64_OBJ_DOOR_MOVED] = 80h, the orientation -1 or +1 (opening with bit 5 set -1, closing with bit 5 clear
; -1); if the third cell of the new leaf holds a character ([cell] & F0h) the door bytes are restored,
; [D64_OBJ_DOOR_MOVED] = 0 and the leaf is marked again.  The Z80 keeps the door bytes in B', C' (EXX): o_guarda.
; The permission table (D64_OBJ_DOOR_PERMISSIONS: mask, word -> the character's x, y; FFh) is read indexed by X
```

Who may open which door comes from three sources: the **keys** (key 1 and key 2 each give Guillermo a door, key 3
gives Adso one), the **time of day** (`OBJ_DOOR_CHECK_MASK`: some doors are locked at night) and the **scripts**
(the monks' door masks).  The same permissions open or close the links between rooms that the path finder uses:

[`src/c64/juego_final/logica_b.s`](../../src/c64/juego_final/logica_b.s#L909-L910), lines 909–910:

```asm
; 4D97 obj_update_key_permissions: Adso's key 3 (bit 1 of his objects) -> bit 4 of his doors (292Dh);
; Guillermo's key 1 (bit 3) -> bit 0, key 2 (bit 2) -> bit 2 of his (292Ah).  Out: A = his new byte.
```

[`src/c64/juego_final/estado_texto.s`](../../src/c64/juego_final/estado_texto.s#L271-L274), lines 271–274:

```asm
; 39F1 obj_set_door_permissions: ai_random := chr_command_buffers[0]; for the 6 doors of obj_door_link_table
; ((index into chr_room_links, bits) pairs, FFh ends a door) the bits are cleared when the door's bit of
; zbc (C) AND obj_door_check_mask is set (the opcode at 3A24 = CCF), else set (NOP).  Out: A = FFh, B = 0,
; C = that mask >> 6, zhl = chr_room_links.
```

## The manuscript and the mirror

When Guillermo holds both the glasses and the parchment, he reads the manuscript: a numeral is chosen at random, once
per game (the CPC's `LD A,R`, here the CIA's timer and the raster line), written over the word `AAA` of the dictionary,
and the Latin phrase appears: *SECRETUM FINIS AFRICAE, MANUS SUPRA XIX IDOLUM AGE PRIMUM ET SEPTIMUM DE QUATUOR* —
with IXX, XIX or XXI:

[`src/c64/juego_final/logica_b.s`](../../src/c64/juego_final/logica_b.s#L1772-L1784), lines 1772–1784:

```asm
; 5184 obj_read_manuscript: Guillermo holds the glasses and the parchment: the stair numeral, chosen once at
; random (the CPC's LD A,R: plat_aleatorio; & 3, 0 -> 1), set again, and phrase 00h.
obj_read_manuscript:
        lda     D64_OBJ_MIRROR_NUMERAL
        bne     :+
        jsr     plat_aleatorio
        and     #$03
        bne     :+
        lda     #1
:       jsr     obj_set_mirror_numeral
        jsr     hud_say
        .byte   $00
        rts
```

In the mirror room of the library, Guillermo must stand on the step that the numeral names and press Q and R
together.  The right step opens the mirror, the way to the finis Africae; any other is a trap, and Guillermo falls:

[`src/c64/juego_final/personajes.s`](../../src/c64/juego_final/personajes.s#L2045-L2049), lines 2045–2049:

```asm
; 2D99 game_input_and_mirror: the input step of the main loop: sys_read_keyboard, EI.  While the mirror is closed
; ([28DD]): game_check_qr_mirror; with Q+R down on a step: a numeral [290D] other than 4 sets bit 2 of [2910];
; the numeral = the step opens the mirror (FF at [[2EDE]], 51h at [[2EE5]], between DI and EI); numeral 4 or
; another step is the trap ([37E4] = 1, [23E4] = 14h, 6Bh two bytes before [[2EE5]], hud_say_now with its
; inline phrase 22h).  Both: [28C6] = 0 (the room is rebuilt), [28DD] = 0, snd_play_mirror_open (0C6D).
```

On the C64 the keys are those of the CPC: Q and R together (R first, as `teclado.s` explains, since Q alone also
walks).  The PC version always chose the same numeral; the C128's full game keeps the CPC's random choice.
