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

{{code src/c64/juego_final/logica_a.s | ^; 4BEC obj_update_inventory | +4}}

An object is taken when it lies in the cell in front of a holder whose masks allow it — so Adso, walking behind
Guillermo, picks up the lamp or key 3 himself:

{{code src/c64/juego_final/logica_b.s | ^; 4C46 obj_pick_up_objects | +5}}

SPACE drops Guillermo's first object in front of him, if that floor is free and level:

{{code src/c64/juego_final/logica_b.s | ^; 4DC3 obj_drop_on_space | ^; where the original reads it}}

The scripts move objects too, by copying five inline bytes into a record: the glasses and key 1 appear on day V, the
lamp in the kitchen from day III, Jorge takes the book, the abbot keeps the parchment in his cell.

## Keys and doors

Seven doors stand in the abbey.  Each frame `obj_update_doors` opens a door when a character allowed to pass stands
next to it, and closes it otherwise; a door's leaf is part of the height buffer, so a closed door blocks the way:

{{code src/c64/juego_final/objetos_sonido.s | ^; 0B1D obj_door_check_open_close | +9}}

Who may open which door comes from three sources: the **keys** (key 1 and key 2 each give Guillermo a door, key 3
gives Adso one), the **time of day** (`OBJ_DOOR_CHECK_MASK`: some doors are locked at night) and the **scripts**
(the monks' door masks).  The same permissions open or close the links between rooms that the path finder uses:

{{code src/c64/juego_final/logica_b.s | ^; 4D97 obj_update_key_permissions | +2}}

{{code src/c64/juego_final/estado_texto.s | ^; 39F1 obj_set_door_permissions | +4}}

## The manuscript and the mirror

When Guillermo holds both the glasses and the parchment, he reads the manuscript: a numeral is chosen at random, once
per game (the CPC's `LD A,R`, here the CIA's timer and the raster line), written over the word `AAA` of the dictionary,
and the Latin phrase appears: *SECRETUM FINIS AFRICAE, MANUS SUPRA XIX IDOLUM AGE PRIMUM ET SEPTIMUM DE QUATUOR* —
with IXX, XIX or XXI:

{{code src/c64/juego_final/logica_b.s | ^; 5184 obj_read_manuscript | ^\s+rts}}

In the mirror room of the library, Guillermo must stand on the step that the numeral names and press Q and R
together.  The right step opens the mirror, the way to the finis Africae; any other is a trap, and Guillermo falls:

{{code src/c64/juego_final/personajes.s | ^; 2D99 game_input_and_mirror | +5}}

On the C64 the keys are those of the CPC: Q and R together (R first, as `teclado.s` explains, since Q alone also
walks).  The PC version always chose the same numeral; the C128's full game keeps the CPC's random choice.
