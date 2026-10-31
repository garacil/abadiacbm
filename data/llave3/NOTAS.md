# Key 3 with Malachi there (the play report)

Trying to take the key in the library, the monk never stepped aside in the one position where Adso may pass and
take it for Guillermo, not even after the meal of the second day.  How it is done: with Malachi there, Guillermo stands so
that Malachi ends up against the table, which lets Adso pass and take the key.  At night it is never there, because
Malachi always takes it.

## Result

* **The original (CPC 64K, the Z80 code) allows it.**  `guion_llave3.txt` does it from the
  unchanged start state `data/puro/estados/ram_d2h4.bin` (a new game at day 2, nona, Guillermo at the gate):
  Guillermo walks to the scriptorium, stands on the lower floor at the west end of the long table, Malachi
  leaves his desk and on his way back stops with his back against the table (37,37), Adso is sent round the
  table, passes between Malachi and the step down and takes key 3 at frame 1212.  Verified on the hybrid host
  with the Z80 code alone (`--solo nada`) and on Caprice32 (real CPC timing, same result).
* **The builds do exactly the same**, with the same keys: the C64 game (src/c64/juego_final, 6502) 829 frames,
  0 with differences against the Z80; the pure C game the RAM identical at all 829 frames; the GNU build
  (pure C) the same pictures, pixel for pixel, at the 9 frames shown (also the binaries already in src/juego/gnu,
  `abadia64ks-puro` and `abadia64ks`).  **No bug in the game's logic was found on this path.**
* The one difference found is the C64's keyboard layer: `src/c64/plataforma/teclado.s` turns cursor down (A or
  CRSR down: Adso) into cursor up (walk) whenever SHIFT is down, and SHIFT is part of the C64's own left and up
  cursors (and of VICE's PC arrows).  Turning left with SHIFT + CRSR right while Adso's key is held makes the
  game read "walk + left": Malachi leaves again and the manoeuvre breaks (`guion_c64_cursores.txt`, below).
  With Q A O P, K L, Z or the joystick it does not happen.  Which keys the report's game used is not known.

## What the code says (read in full, Z80 bytes checked where it matters)

**The key.**  Key 3 is object 6: record 2B77 (`+0` flags, `+1` orientation, `+2/+3` x y, `+4` height), bit 02h
of a holder's objects.  At a new game it lies on the long table: `00 00 35 35 13`.  (`obj_place_key3` 3C66,
`CD 84 3C 72 2B 00 00 35 35 13`, called at day 6 noche, writes record 2B72: object 5, bit 04h, Guillermo's
"key 2" for the door permissions of 4D97; the name comes from the PC rebuild.  The key of this report is 2B77:
the one Adso's mask allows and the one 3B66 puts back.)

**Who may take it** (`obj_pick_up_objects` 4C46: the holders' masks `+4/+5`, minus what they hold): Guillermo
`293D +5 = FD` (all but key 3: he cannot), Adso `2944 +5 = 02` (only key 3; no script changes it), Malachi
`2950` = 02 at visperas (5308), 00 at his desk (53F5).

**Where** (4C46 with `obj_front_position` 4EA5): an object is taken from the cell two steps in front of the
holder's character, `x + 2 dx, y + 2 dy` (step table 23A8: orientation 0 +x, 1 -y, 2 -x, 3 +y), when its height
minus the character's is 0..4.  Key 3 at 35,35 height 13h; the scriptorium floor is 0Fh.  The table (the first
floor's height list 9E40, `mapa_alturas.py`; its decoding equals the game's own height buffer AE2E of that room
at frame 1129: 0 cells differ) is a block 8 high at x 32-37, y 33-35 with a leg at x 32-33, y 36-38.  A
character is the 2x2 square whose top-right cell is its position.  The only square on the floor with 35,35 two
cells ahead is **35,37 facing -y** (cells 34-35 x 36-37): 37,35, 33,35 and 35,33 are on the table.  It is also
Malachi's place 6 (`35 37 53` in his places table 37F8), where he takes the key at visperas.

**The bay.**  35,37 is the corner of a bay (x 34-3B, y 36-39): the table north and west, the reading desk (height
E, x 3C-43) east, the step down to height 2 (y 3A) south; the only way in is from the north at x 38-3B.  The game's
height buffer at frame 1129 (room 3,3; `M` = a character's mark: Malachi at 37,37, Guillermo and Adso at 31,3E
and 2F,3E):

```
   x 2C...........................43
2C 44FF00000000000000006666
30 4444444444444444EEEE555E      <- the way to the library: x 40-42, north
33 44444488888844444444444E      <- the table, height 8 (key 3 on it at 35,35)
34 44444488888844444444444E
35 44444488888844444444444E
36 4444448844MM4444EEEEEEEE      <- Malachi against the table (37,37); the reading desk E
37 4444448844MM4444EEEEEEEE
38 4444448844444444EEEEEEEE      <- the table's leg 32-33; Malachi's desk place is 37,38
39 3333334444444444EEEEEEEE
3A 222222222222222222222222      <- the lower floor (height 2)
3D 22MMMM222222222222222222      <- Guillermo (31,3E) and Adso (2F,3E)
3E 22MMMM222222222222222222
```

Malachi's desk place (place 2, `37 38 4F`: cells 36-37 x 37-38) leaves no square free between the table and the
step: with him there no way leads to 35,37 (`ruta.py`, a breadth-first search with the game's square rule,
`chr_path_check_square` 4080, his four cells taken).  His blocking place (place 3, `3A 34 8F`) closes the bay's
entrance.  For Adso coming from the west side of the table: Malachi at 37,37 (against the table), 38,37, 39,37
or 37,39-3B,39 leaves the way open; at 35,37, 36,37, 35,38-3A,38 (his desk among them), 35,39, 36,39, x 3A y
33-37 (the entrance, place 3 among them) or across the passage north of the table (x 30-3A, y 31-32) it is
closed.

**Malachi's script at his desk** (52B4; the bytes at 53EC-5468 of `cpc64/juego/ram.bin`, as
`src/juego/f_logica_b.c` translates them):

```
53EC CF 87 02 3D 20 09        reached = 2 ?            (at his desk)
53F2 D7 8E 00 D7 BA 00        state := 0, take mask := 0
53F8 CD 66 3B                 3B66: if he holds key 3, record 2B77 := 00 00 35 35 13 (back on the table):
                              3A 4E 29 CB 4F C8 E6 FD 32 4E 29 CD 84 3C 77 2B 00 00 35 35 13
53FB CF 8E 00 3D C2 69 54     state = 0 ?
5402 CD AE 39 C2 65 54        Guillermo close (39AE)?  no -> 5465: destination := 2 (his desk)
5408 CF 86 03 3D 20 47        destination = 3 ?  no -> 5455
5455 CD 2E 05                 052E: his commands discarded
5458 AF CD 8D 2E 20 03        cursor up (key 0) down?  yes -> 5461: destination := 3 (block the way)
545E C3 A8 39                 no -> 39A8: no route this frame (he stays where he is)
```

`ai_guillermo_is_close` (39AE): same floor and Guillermo inside a box that depends on Malachi's orientation
(table 38EC): facing +x: x-6..x+17, y-6..y+5; -y: x-6..x+5, y-12..y+11; -x: x-12..x+11, y-6..y+5; +y: x-6..x+5,
y-6..y+17.

So Malachi stops wherever he is when Guillermo is inside his box while his destination is not 3 and cursor up
is not down.  Walking needs cursor up, so Guillermo must not walk into the box: the box must come to him (it
moves and turns with Malachi).  The manoeuvre: Guillermo enters the box of Malachi at his desk walking
(destination 3: Malachi leaves to block the way), then Malachi turns and Guillermo, standing, is outside his box
(destination 2: back to the desk), and later inside it again: Malachi stays there.  In the run Guillermo stands at
31,3E (on the lower floor, under the west end of the table): inside the desk's box (facing -y: x 31-3C, y 2C-43),
outside the boxes of Malachi's way out and back (facing +x at 37,37: y up to 3C; facing -y at 39,37: x from 33;
facing -x at place 3: y up to 39; facing +y at 3A,3x: x from 34; facing -x at 39,37 / 38,37 / 37,37: y up to 3C),
inside the box at 37,37 facing +y (x 31-3C, y 31-48), when Malachi turns there to step onto his desk place: he
stays against the table.  Standing at 33,3E instead, Guillermo is inside the box of Malachi facing -y at 39,37 on
his way out (after his destination went back to 2): he stays at 39,37, which leaves the way open too
(`guion_llave3_33.txt`, made by `variante.py 33`: Adso takes key 3 at frame 1191 with Malachi at 39,37; the C64
game 779 frames 0 with differences, the pure C game identical at all 779 frames).  The sweep below measures it on
the original for many places.

**Adso** (04EB `ai_update_adso`): following Guillermo he keeps 3-4 cells behind him; with cursor down held he
steps the way Guillermo faces instead (40EB: the first free of entry o+1 of 4188: Guillermo facing +x: +x, +y,
-y; -y: -y, +x, -x; -x: -x, -y, +y; +y: +y, -x, +x).  Turning (left / right) does not concern Malachi (only cursor
up does), so Guillermo turns on the spot and Adso walks: north on the west side of the table, east along its north
side, south through the entrance, west between Malachi and the step, north into 35,37.  Released, cursor down
lets Adso walk back to Guillermo (after frame 1211 in the run he does, with the key).

**At night** (it is never there): at visperas (52E3) Malachi's mask := 02, destination 6 (35,37
facing -y) and he takes it: the original from `ram_d2h5.bin` with no keys, frame 568: his objects 02, record 2B77
= `80 00 4B 29 13` (held by his holder 294B), then he goes to the left wing's doors.  The next tercia at his desk
53EC-53F8 would put it back (read in the code; not run: a game across days needs Guillermo to keep the hours).

## The run (`guion_llave3.txt`, made by `hace_guion.py`)

Day 2, nona (`ram_d2h4.bin` unchanged).  Positions `x,y` (hex) of the character records 2B87 / 2B96 / 2BA5.

| frame | what happens |
|---|---|
| 474-1057 | Guillermo walks from the gate (88,9C) to the scriptorium (2E,3E, lower floor), Adso behind him; Malachi at his desk 37,38 facing -y since frame 567 |
| 1087-1094 | Guillermo turns +x and walks to 31,3E: inside Malachi's box with cursor up, destination 3 at frame 1094 |
| 1095-1114 | Malachi leaves the desk (37,37, 38,37, 39,37 ... 3A,34); Guillermo is outside his boxes from frame 1098: destination 2 |
| 1115-1129 | Malachi walks back (3A,35 ... 38,37, 37,37) and turns +y at 37,37: Guillermo inside his box, no cursor up: **he stays at 37,37, against the table** (to the end of the run) |
| 1137-1211 | cursor down held; Guillermo turns at 1137 (left), 1141 (right), 1146 (left), 1165, 1182, 1197, 1206 (right); Adso: 2F,3C, 31,3C, 31,32, 39,32, 39,39, 35,39, 35,38, **35,37 facing -y at 1211** |
| 1212 | **Adso holds key 3**: his objects [2947] = 02, record 2B77 = `80 00 44 29 13` (held, holder 2944) |

Pictures of the original (the CPC screen memory drawn as the GNU front-end draws it, `traza --fotos`):
`resultados/fotos/z001057.png` ... `z001230.png`; the six main ones in `secuencia_original.png`.

## Checks (`prueba.sh`, about 10 s)

| run | result |
|---|---|
| 1. the original, hybrid host, Z80 code alone (`traza ... --solo nada`) | key 3 taken at frame 1212 (`resultados/resumen_original.txt`) |
| 2. the C64 game, `hibrido --juego6502 ../c64/juego_final` (6502, frame by frame) | 829 frames, 0 with differences (`resultados/c64.txt`) |
| 3. the pure C game, `src/juego/puro/puro` | RAM hashes identical to the Z80's at all 829 frames |
| 4. the GNU build in pure C (`abadia64ks-puro` built here from src/juego/gnu, `--captura` on Xvfb :99) | the 9 pictures 0 pixels different from the original's (`resultados/fotos/g*.png`) |
| src/juego/gnu/abadia64ks-puro and src/juego/gnu/abadia64ks as they are | frames 1129 and 1212: 0 pixels different |
| 5. Caprice32, `caprice/caprice_llave3.py` | at game frame 850 (frame 1321): Adso's objects 02, record 2B77 `80 00 44 29 13`, Guillermo 31,3E, Adso 31,3C, Malachi 37,37 facing +y, as the hybrid; pictures (`caprice/resultados/cpc_*.png`) equal to the hybrid's in the 320x200 game area, compared by brightness (the two emulators give the CPC colours slightly different RGB): 0 pixels differ; the one taken "at 1170" is the hybrid's 1171 (the screenshot came after that iteration had redrawn) |

Caprice32 cannot hold keys from outside frame by frame, so `caprice_llave3.py` puts the script inside the CPC: the
same start state with three patches in memory this run never uses (checked with `hibrido --accesos --cobertura`):
217Ah `CALL 01C0h` counts the main-loop iterations at 01F0h (as `tools/cpc_velocidad.py`), 2D77h
`CALL 3200h` (`caprice/inyecta.asm`, in the tape code) ANDs keyboard rows 0 and 1 with a table of the script
(323Dh).  `caprice_llave3.py comprueba` runs that patched state in the hybrid with no key script: positions,
objects, key 3 and Malachi identical to the scripted run at frames 472-1300.

## Where Guillermo must stand (`barrido.py`, `barrido.tsv`, `barrido_fino.tsv`)

From frame 1057 of the run, Guillermo walks by the shortest way to a cell and stands; 200 frames later:

| Malachi ends at | destination | way for Adso | Guillermo standing at |
|---|---|---|---|
| 37,37 (against the table) | 2 | open | 31,3D 32,3D 31,3E 32,3E |
| 39,37 (in the bay, north of the step) | 2 | open | 33,3D 33,3E 34,3E 35,3E |
| 37,38 (his desk) | 2 | closed | 22,32 24,32 26,32 28,32 2A,32 2C,32 2E,32 30,32 22,35 24,35 26,35 28,35 2A,35 2C,35 2E,35 30,35 22,38 24,38 26,38 2C,38 2E,38 30,38 2C,3B 2E,3B 30,3B 44,3B 2C,3C 2E,3C 30,3C 44,3C 2C,3D 2E,3D 2F,3D 30,3D 40,3D 42,3D 44,3D 2C,3E 2E,3E 2F,3E 30,3E 40,3E 42,3E 44,3E |
| 3A,34 (place 3: blocking) | 3 | closed | 32,31 34,31 36,31 38,31 3A,31 |
| 3A,34 (place 3: blocking) | 2 | closed | 38,3B 3A,3B 3C,3B 3E,3B 38,3C 3A,3C 3C,3C 3E,3C 3A,3D 3C,3D 3E,3D 3C,3E 3E,3E |
| 3A,35 | 2 | closed | 34,3B 36,3B 34,3C 36,3C 34,3D 35,3D 36,3D 38,3D 36,3E 38,3E 3A,3E |
| 3A,37 | 2 | closed | 31,3B 32,3B 33,3B 40,3B 42,3B 31,3C 32,3C 33,3C 40,3C 42,3C |

(Guillermo comes from 2E,3E by the shortest way, so Malachi leaves his desk only if that way enters his box with
cursor up; standing in the west part, on a way that never enters it, Malachi just stays at his desk.)  The way
for Adso is open only for Guillermo at 31-32,3D-3E (Malachi against the table) and at
33,3D-3E, 34-35,3E (Malachi at 39,37): a patch of eight cells (all those tried there) on the lower floor,
under the west end of the table and just east of it.  One cell further west (30,3D-3E) Malachi goes back to his desk; one further east or north
he stops at 3A,35 or 3A,37 in the bay's entrance.

## The C64's cursors (`guion_c64_cursores.txt`)

`teclado.s` (escanea, after the scan): when SHIFT (CPC key 15h) is down, a cursor down in row 0 becomes cursor up
and cursor right becomes cursor left; A gives cursor down too (Q A O P).  So SHIFT + A, or SHIFT + CRSR down +
CRSR right (the C64's left with Adso's CRSR down held; in VICE the PC's left arrow is SHIFT + CRSR right) reads
as walk (+ left), not Adso.  The test of `src/c64/plataforma/pruebas/prueba.py teclado` has the case LEFT SHIFT + A
(expected: cursor up), so it is by design.  `guion_c64_cursores.txt` is `guion_llave3.txt` as the game gets it
when the two left turns of the steering (frames 1137 and 1146) are made that way: in those frames walk + left
instead of Adso + left.  On the original: at frame 1138 Malachi's destination is 3 again, he leaves 37,37, walks
to 3A,34 and back, the steering goes on without him in place and Adso does not get the key (record 2B77 still `00
00 35 35 13` at frame 1400).  Malachi stops again at 37,37 at frame 1171 (Guillermo has not moved), so the
manoeuvre can be started again, but every left turn with SHIFT while Adso's key is held undoes it.  (Run on the
original with the CPC keys the C64 layer produces; not run in VICE.)

## Not verified

* How the reported game was played: which build (C64 in VICE, GNU), which keys, from which position.  Any input that keeps
  cursor up down while Guillermo is in Malachi's box sends Malachi to block the way again.
* Other days and hours than day 2 nona (the script's walk depends on where the other monks are).  From the code:
  Malachi is at his desk with state 0 at tercia, sexta and nona (not day 5 tercia), so the same applies then.
* The C64's platform layer in VICE with the manoeuvre (the hybrid checks the 6502 game with the CPC keyboard rows;
  the keyboard decode is covered by its own VICE test, 85 cases).

## Files

| file | what |
|---|---|
| `guion_llave3.txt` | the key script (lines `FRAME ROW:BIT FRAMES`, hybrid host format) |
| `hace_guion.py` | makes it on the original, step by step from the trace (`piloto.py`), routes from `ruta.py` |
| `prueba.sh [FRAMES]` | runs it on the original and on the C64, pure C and GNU builds (results in `resultados/`) |
| `fotos.txt` | the frames of the pictures |
| `traza.c`, `Makefile` | `traza`: the hybrid host (src/juego/hibrido.c included, unchanged) with a per-frame trace of the key-3 variables and `--fotos` (the CPC screen as PPM) |
| `piloto.py` | builds key scripts on the original: turns, walks to a coordinate, steers Adso (cursor down + turns) |
| `mapa_alturas.py`, `ruta.py` | a floor's height map from its height list; shortest routes for a 2x2 character |
| `resumen.py` | Malachi's changes and the frame Adso takes key 3, from a trace |
| `barrido.py` | where Malachi ends for each place Guillermo stands |
| `guion_c64_cursores.txt` | the script as the C64 decodes SHIFT + cursors with Adso's key held |
| `variante.py`, `guion_llave3_33.txt` | the manoeuvre with Guillermo at another place of the row 3E (33,3E: Malachi stays at 39,37) |
| `caprice/` | the run on Caprice32: `caprice_llave3.py comprueba` (the patched state in the hybrid: `traza_parcheada.tsv`), `caprice_llave3.py corre 850` (Xvfb :99, about a minute: `resultados/cpc_*.png`, `medidas.tsv`, `final*.txt`, the `.sna`), `inyecta.asm` |
| `estado_inicio.py` | a start state with Guillermo's start position changed ([BF50-BF52]); used while exploring, not by the final script |
| `secuencia_original.png` | six pictures of the original's run |
