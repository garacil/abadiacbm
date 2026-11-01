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

# The presentation and parchments on the C64 disk (src/c64/presentacion)

The parchment program in C (cc65, September 2016: "~/classic computers/Commodore/abadia"), without music,
is the introduction and ending parchments and the loading picture, its C code kept entirely.  The order: first the
parchment; on SPACE, the loading picture, and then the game loads.  The program had no ending text: it comes from the
tape.  The credits of this Commodore version go on the introduction.

So the first program on the disk, "abadia", is **the program** (`abadia.c`, `io.c`, `manuscrito.c`, built with its
own line), with only what had to change; the ending, "final", is the parchment with the CPC's ending text.

Update: the active renderer halves its stroke wait
(`0x160` to `0xB0`) in both programs. Images, font, graphics modes and music timing remain
unchanged. `text2.bin` appends the Commodore credits and the dedication to Opera Soft
after the twelve original pages, making fourteen pages and 2598 bytes. The disk test checks
all fourteen pages and the original music writes. Earlier timing tables below describe
the pre-update baseline; current results are in `src/c64/cinta/FLUJO.md`.

| On the screen | Whose |
|---|---|
| "Loading" while `abadia.koa` (the picture) is read | the `abadia.c` |
| the parchment, its border, the gothic text written pixel by pixel, the page turns | the `manuscrito.c`, the `pp.bin`, the `text1.bin` (the tape's text, byte for byte) + this version's credits |
| the music while it writes | the CPC's player (`src/c64/pergamino/musica.s`, the CPC's AY writes tick by tick) on the SID (`sid.s`) |
| a key (space) ends the parchment at any moment, or after its end | the `cgetc` + one `kbhit` test |
| the picture on the game's screen while the game loads, its side cells black at the end | the `abadia.koa`, shown by `presentacion.c`; the loader `cargador.s` |
| the ending (when the game is won at 100 %): the parchment with the CPC's ending text and music, over and over | the `manuscrito.c`, `text2.bin` (the tape's), `final.c` in the style |

## Files

| Path | What |
|---|---|
| `original/` | **the files as they are** (copied from "~/classic computers/Commodore/abadia", never edited): `src/` (abadia.c, io.c, io.h, manuscrito.c, manuscrito.h, c64.cfg, abadiac64.bat), `graphics/abadia.koa`, `graphics/pergamino/` (pp.bin, text1.bin, README.txt), the disk `abadiac64.d64` |
| `abadia.c`, `io.c`, `io.h`, `manuscrito.c`, `manuscrito.h` | the sources with the changes below (line endings as the originals: CRLF but abadia.c) |
| `c64.cfg` | the linker configuration in cc65 2.19's form (below) |
| `presentacion.c`, `presentacion.h` | what this build adds to the code: `musicstart`, `musicstop`, `gameload` |
| `final.c` | the ending's main, in the style (abadia.c's main + manuscrito.c's manusintro) |
| `sid.s` | `src/c64/pergamino/sid.s` (the SID voicing and the 300 Hz interrupt) + the KERNAL's keyboard scan every fifth tick |
| `carga.s` | `src/c64/pergamino/carga.s` (copies the loader to $C3E8 and jumps there), its comment adapted |
| `cargador.s`, `cargador.cfg` | the game's loader (from `src/c64/pergamino/cargador.s`: no picture of its own any more; the mark) |
| `datos.py` | the data files from the files and the tape: `text1.bin` (+ credits), `text2.bin`, `pp.bin` (+ 4 glyphs), `musica_inicio.c`, `musica_final.c`; the page model (`paginas()`) the tests use; `--texto` prints the ending text, `--glifos PNG` the new glyphs |
| `construye.sh` | all of it into `generado/` (called by `src/c64/presentacion/pruebas/disco_prueba/construye.sh`) |
| `pruebas/paginas_cpc.py` | the CPC's pages (the GNU build's screen at every frame) against the page model |
| `pruebas/estado_final.py` | the C64 memory one step from the 100 % ending, for the VICE run of the ending |
| `resultados/` | the pictures and `resultados.txt` of `src/c64/presentacion/pruebas/disco_prueba/prueba.py`; `glifos_nuevos.png` |

Build: `src/c64/presentacion/pruebas/disco_prueba/construye.sh` (the whole disk) or `src/c64/presentacion/construye.sh` (this directory only).
Test: `src/c64/presentacion/pruebas/disco_prueba/prueba.py` (VICE on Xvfb :99, ~7 min), `src/c64/presentacion/pruebas/paginas_cpc.py intro|final`.

## The changes to the code, and why

Every source file got the project's licence header (the author, 2016-2026,
GNU GPL version 3 or later) in place of the old one ("cc65 Abadia del crimen / garacilb@gmail.com 27/09/2016
(Spain)"; io.h and manuscrito.c/.h said "gmain.com").  `io.c`, `io.h` and `manuscrito.h` have no other change.
The diffs below leave the headers out (`diff -u original/src/X X`).

### abadia.c: the new order (the parchment first; on space the picture and the load)

```diff
 #include "manuscrito.h"
 #include "io.h"
+#include "presentacion.h"
@@
 	fread((unsigned char*) buffer + 8000, 1, 1000, fp);
 	fread((unsigned char*) buffer + 9000, 1, 1000, fp);
 	fclose(fp);
-	SEI();
-	POKE(0x0001, 0x32); // Only RAM & KERNAL I/O disabled
-	memcpy((unsigned char*) VIC_MEM, (unsigned char*) &buffer[0]   , 8000);
-	memcpy((unsigned char*) VIC_SCR, (unsigned char*) &buffer[8000], 1000);
-	POKE(0x0001, 0x36); // RAM, KERNAL & I/O
-	CLI();
-	memcpy((unsigned char*) VIC_COL, (unsigned char*) &buffer[9000], 1000);
-	free(buffer);
 #endif
 
+#if defined(__CBM510__)
 	screenbitmapmulticolor();
 
 	while(1) {
@@
 		if (k)
 			break;
 	}
+#endif
 
 	manusintro();
@@
 		if (k)
 			break;
 	}
+#if !defined(__CBM510__)
+	musicstop();       // The parchment's music ends with it (presentacion.c)
+	gameload(buffer);  // The picture on the game's screen, the game loads under it and starts: never returns
+#endif
 	//screenbitmap();
```

* The picture is still read first, into the buffer, while "Loading" is shown (so it appears at once on the key);
  it is no longer shown before the parchment, and the key wait before the parchment is gone (the order).  The
  P500 (`__CBM510__`) path keeps the order untouched (it is not built here).
* After the parchment's key: the music stops, and `gameload(buffer)` shows the picture: the display code
  (`SEI` ... `memcpy` ... `screenbitmapmulticolor`), moved to `presentacion.c` with the game's screen instead of the original one:
  bitmap $E000, screen RAM $C000 ($D018 = $08; the original io.h: bitmap $C000, screen RAM $E000, $D018 = $83).  The game
  needs nearly all the RAM and loads around its own screen (src/c64/cinta/FLUJO.md); its loader runs at $C3E8, inside
  the bitmap's place, so the picture must be where the game's screen is.  Then the loader; it never returns.
* **io.h is not changed**: the parchment stays in the layout (the `pp.bin` holds the border cells' absolute
  addresses, $C040-$DDB8, for the bitmap at $C000); only the picture moves to the game's screen, at the end.

### manuscrito.c

```diff
 #include "manuscrito.h"
 #include "io.h"
+#include "presentacion.h"
@@ manusini
-	perlet = malloc(sizeof(char) * 0x9d1);
+	perlet = malloc(sizeof(char) * 0xac1); // 0x9d1 + the glyphs 0 6 @ B (datos.py)
@@
-	fread((unsigned char*) perlet, 1, 0x9d1, fp);
+	fread((unsigned char*) perlet, 1, 0xac1, fp);
@@ manusrun
 	manusini();
+	musicstart(); // The parchment's music starts with it (presentacion.c)
 	posX = 76;
 	posY = 16;
 	while (1) {
+		if (kbhit()) // A key ends the parchment at once, as space on the CPC (the caller's cgetc takes it)
+			break;
 		switch(*text) {
@@
 	free(perlet);
+	free(ytoscreen); // Allocated by each manusini: the ending writes the parchment over and over
 }
@@ manusintro
-	minicio = malloc(sizeof(char) * 0x57b);
+	minicio = malloc(sizeof(char) * 0x5d3); // 0x57b + the credits of this version (datos.py)
@@
-	fread((unsigned char*) minicio, 1, 0x57b, fp);
+	fread((unsigned char*) minicio, 1, 0x5d3, fp);
```

* The sizes: the code reads its files with fixed sizes; `pp.bin` has 240 bytes more (the four glyphs) and
  `text1.bin` 88 more (the credits).  `construye.sh` checks the numbers in the code against the files.
* `musicstart()` right after `manusini()`: the music starts when the parchment appears (manusini ends with
  `screenon()`), as the CPC's stage starts it (6019h-6022h) when it draws the parchment; not during the loads before.
* `kbhit()` once a character: space (any key) ends the text at once, as on the CPC (its 668Bh tests space once a
  character); without it the text could only be left at its end.  The key is not taken: the caller's `cgetc` (the
  wait in abadia.c, final.c's) takes it, so one press ends the parchment whether it is writing or at its end.
* `free(ytoscreen)`: each `manusini` allocates the 400-byte table and nothing freed it; the intro runs once, but the
  ending runs `manusrun` again after every key, and would lose 402 bytes a pass (its free heap, ~30 KB, gone after
  ~75 passes: malloc then returns 0 and the table is written at address 0).

Found and left as it is (to decide): `manusmkytoscreen` fills 26 rows x 8 = 208 entries of a 200-entry table
(`malloc(sizeof(int) * 200)`, `for (y = 0; y < 26; y++)`): 16 bytes past it.  Harmless here (the table is the last
block on the heap, and the frees leave the heap as it was), so not changed; `y < 25` would be the fix.

### c64.cfg (the file cannot be linked by any cc65 since 2.13)

The `c64.cfg` has the syntax of a cc65 older than 2.13 (`__STACKSIZE__: value = $0100, weak = yes;`, no load
address and BASIC header segments).  The original 2024 build (`src/bin/c64/abadia.prg`, objects of "cc65 v 2.13.3")
has 2.13's BASIC header and its C stack at $BFFF, so some other configuration linked it; cc65 2.13's ld65 rejects
this file ("Attribute expected", checked with the 2.13 sources from GitHub, which are a 2.13.9 snapshot: the 2.13.3
release is not there).  Built with the project's cc65 2.19, the file is written in 2.19's form with the values: the
program from $0801, everything below $C000 (the bitmap; the C stack from $BFFF down), a C stack of $0100 bytes.  The
build line (`abadiac64.bat`) is kept: `cl65 --register-vars -Cl -Ois -t c64 ... -C c64.cfg`.

### The data files

* `abadia.koa`: on the disk as it is (10000 bytes: bitmap, screen RAM, colour RAM, as the code reads it).
* `text1.bin`: the file **is the tape's introduction text** (data/cpc64/cinta/primera_etapa.bin at [6028h] =
  8400h, 1403 bytes up to its 1Ah: checked by datos.py).  On the disk: the file + the credits of this version on a
  page of their own (0Ah, a new page: the tape's credits fill theirs), in their style (a lower-case label with a
  colon, the names indented; three spaces, not four, so that the e-mail ends at x 241, before the right border at
  248: with four it would reach 251):

  ```
  version commodore:
     German Luis
     Aracil Boned
     garacilb@gmail.com
     2016 - 2026
  ```
  (The font has no accents; the years from the sources' dates, 2016, to 2026.)
* `pp.bin`: the glyphs and their pointers are the tape's (6772h table, 68ADh-727Dh glyphs: checked).  The font has
  no glyph for `0`, `6`, `@` nor `B` (their pointers are 0), which the credits need: they are drawn in the font's
  style (`datos.py` GLIFOS: the digits' height and flourish of 2, 3, 7; B from P's bowl and D's foot; @ an a in a
  ring; `resultados/glifos_nuevos.png`) and appended after the glyphs (240 bytes), their pointers in the table
  continuing the CPC's addresses (727Eh on), as the `manusmkletptr` expects.  The `@` does not take its ASCII code
  40h: the manusrun (as the CPC) draws the codes 40h-5Fh as capitals, red and two pixels to the left (onto the `b`);
  it takes 60h (`` ` ``, no glyph in the font), and text1.bin has 60h for the e-mail's `@`: drawn black like the
  small letters, in its place.
* `text2.bin` (new, the ending): the program had no ending text.  The tape's ending block (data/cpc64/cinta/final.bin,
  the CPC's ABADIA64.BN1 at 6000h) has the same parchment code; its text is at [6028h] = 7400h, 2409 bytes up to its
  1Ah, in the same codes as text1.bin (the CPC's: 0Dh a line, 0Ah a page, 1Ah the end, 2Ch-7Ah glyphs): copied as
  it is.  Its font is the introduction's (6772h-727Dh equal), and its border graphics and inks too, so the `pp.bin`
  serves it. The original twelve pages are followed by the Commodore credits and dedication:
  fourteen pages total. `datos.py --texto` prints the current complete text.

## What is added

* **The music** (`presentacion.c`): `musicstart` (called by the `manusrun`): the first time `musica_inicia` (the
  player as the stage's image holds it), later `musica_reinicia` (the CPC's re-entry: channel A from the start), and
  sid.s's interrupt with the voicing of the introduction or the ending (`-DFINAL`); keys pressed before (while the
  parchment loaded) are dropped.  `musicstop` (after the key): `musica_para` (64F1h) and the KERNAL's interrupt back.
  The tunes: `musica_inicio.c` / `musica_final.c`, the 1 KiB at [601Ah] and the player's state 6148h-6199h of each
  tape stage (datos.py, as c64_pergamino_datos.py reads them).
* **The keys and the 300 Hz interrupt** (`sid.s`): the waits use conio's `cgetc` (and now `kbhit`), which read the
  KERNAL's keyboard buffer, filled by the KERNAL's interrupt; sid.s's 300 Hz interrupt replaces the KERNAL's and
  skipped all its work (its whole work after a tick made some ticks too long: 587 of 600 kept in 2 s).  Now it calls
  the KERNAL's keyboard scan (SCNKEY, $EA87) every fifth tick: 60 times a second, as the KERNAL; the clock and the
  cursor are still left out (unused).  The code needs no change for it.  While the music is stopped the KERNAL's own
  interrupt runs (musicstop restores it), so the loads and waits are as they were.
* **The ending** (`final.c`): "Loading", text2.bin read once, then for ever: the `manusrun` (the parchment drawn and
  pp.bin read again by the manusini each time: ~10 s of a brown screen between passes, the code), the `cgetc` wait,
  `musicstop`.  As the CPC (main.c -DFINAL, ESTADO.md "The ending parchment"): the text until a key or its end, the
  music stopped, the parchment again with the music's channel A from the start.
* **The picture during the load** (`presentacion.c`'s `gameload`, `cargador.s`, src/c64/cinta/FLUJO.md): the picture on
  the game's screen (all 40 x 25 cells); the stream loads first everything the screen does not show, then its mark:
  the loader blackens the side cells (columns 0-3 and 36-39 of rows 0-23, row 24: screen RAM and colour RAM to 0)
  and the game's data that lives in their bitmap arrives (1025 bytes, the last 2.2 % of the file); at the end, the
  display blanked, the score bar and the held pages go in place and the play area is cleared (the picture's middle
  cells change only then), and the game starts.  No pink, no CPC picture any more (src/c64/pergamino's scheme).

## Memory

| Range | "abadia" (the program) | at gameload / the loader |
|---|---|---|
| $0801-$3345 | the program (cc65 2.19: the code, presentacion.c, sid.s, musica.s, the tune, the loader's binary); BSS to $33EF | overwritten by the game |
| $33F0-$BEFF | the heap: the picture's buffer (10000 bytes), the text, pp.bin's parts, ytoscreen | the game's |
| $BF00-$BFFF | the C stack | the game's page 2, held |
| $C000-$DF3F | the parchment's bitmap (io.h VIC_MEM; RAM under the I/O from $D000, written with $01 = $34) | the game's screen RAM ($C000-$C3E7: the picture's), the loader ($C3E8-$C642), the game's data |
| $E000-$E3E7 | the parchment's screen RAM (VIC_SCR) | the game's bitmap $E000-$FF3F: the picture |
| $D800 | colour RAM | the picture's |
| VIC | bank 3, $D018 = $83, hires (the parchment) | bank 3, $D018 = $08, multicolour bitmap |

"final" ($0801-$301C, BSS included) the same way during its parchment; plat_final's stub at $C400 is not needed once
it runs.

## Tests and results

`src/c64/presentacion/pruebas/disco_prueba/prueba.py` (VICE x64sc 3.10 on Xvfb :99, a 1541 with true drive emulation, warp; ~7 min; 38 checks, all
passed; `resultados/resultados.txt`) and `pruebas/paginas_cpc.py` (`resultados/paginas_cpc.txt`):

| Check | Result |
|---|---|
| the page model (datos.py `paginas`, the CPC's rule) against the CPC (the GNU build's screen at every frame) | introduction 8 pages, ending 12: each seen exactly, in order |
| "abadia" loaded by the KERNAL (LOAD typed -> the main) | 29.3 s (the CPC's first stage: 82.1 s) |
| abadia.koa read ("Loading"), text1.bin and pp.bin read: the parchment on the screen | at 55.6 s and 70.9 s |
| the introduction: each page when the nextpage is called, and the last at the text's end (cgetc), against the model with the rule (capitals 2 pixels left): the bitmap's text area and its cells' colours | 9 pages, 0 bytes differ each; page 9 the credits |
| the introduction written (no key) | 534.2 s (the CPC: 386 s for its 8 pages; see "Original timing observations and remaining choices") |
| its music: the AY writes of the first 19130 ticks (64 s) | the CPC's own 2828, identical; with the stop (musicstop after SPACE at tick 160174) as musica.c's |
| SPACE at the text's end: musicstop, gameload, the loader | the picture on the game's screen (1000 cells as abadia.koa, multicolour bitmap, bank 3, $D018 = $08) |
| at the mark | the picture still whole, at 106.6 s of the load |
| after the mark, at the end of the data | the 768 middle cells as abadia.koa, the 232 side cells black |
| "juego" loaded (the loader's start -> principal_inicio) | 109.1 s (40943 bytes; uncompressed it would be 55859; the old scheme 125.7 s; the CPC 501.8 s) |
| the RAM at principal_inicio | equal to src/c64/juego_final/c64/juego.bin over the 60826 bytes the game needs |
| the game's first frame, frames 50 and 200 | the merge tables rebuilt; the screens as a run with the image written straight into the RAM (0 pixels differ) |
| the ending through the game's own code (the state of day 7, tercia, investigation solved, written into the RAM, the CPU at principal_inicio) | game_check_end, the percentage "100", plat_final ("PON EL CASSETTE EN MARCHA") |
| "final" loaded by plat_final's KERNAL LOAD; text2.bin and pp.bin read by the code | 26.6 s (the CPC's ending block: 82.4 s); the parchment 44.5 s after plat_final |
| the ending: each page against the model | 12 pages, 0 bytes differ each; written in 1001.2 s (the CPC: 680 s) |
| SPACE at its end | the music stops (musica_para), the parchment again, the music restarted (musica_reinicia) |
| SPACE after 40 characters of the second pass | the text ends at once (the next character's kbhit), final.c's cgetc takes it, the third pass starts |
| the ending's music: the first 9039 ticks (30 s, to the CPC log's first stop) | the CPC's own 6748 writes, identical |
| the ending's music with its two stops and re-entries (ticks 300239 and 305375; 10 s logged after each) | as musica.c's given the same stops: 11266 writes |

Pictures (`resultados/`): `1_cargando` (the "Loading"), `2_pergamino_pagina_1`, `3_pergamino_creditos` (the
credits page), `4_imagen` (the picture during the load), `5_imagen_antes_de_la_marca`, `6_lados_negros`,
`7_fin_de_los_datos`, `8_salto` (blanked, at principal_inicio), `9_juego_frame_1`, `10_juego_frame_200`,
`11_juego_100` (the game at 100 %), `12_final_pagina_1`, `13_final_ultima_pagina`, `14_final_segunda_pasada`,
`15_final_tercera_pasada`; `glifos_nuevos.png` (the four glyphs among the font's, and the credits).

Times are emulated (CIA 2's timers as a cycle counter); deterministic: the same build gives the same figures.  The
AY writes are logged through a checkpoint at _musica_registro, which stops the emulation each time (~20 ms), so only
in windows of ticks; the tick count is sid.s's 16-bit `_musica_ticks` with its wraps added by the test.

## Original timing observations and remaining choices

* **The writing pace with the music.**  The parchment times itself with a busy loop
  (`for (newPosX=0;newPosX<0x160;newPosX++) {}` after each pixel), and without music it keeps the CPC's pace: page 1
  of the introduction in 54.4 s (the CPC: 52.5 s), of the ending in 49.4 s (the CPC: 50.6 s).  The music's 300 Hz
  interrupt takes part of the CPU (the player, the SID voicing, the keyboard scan), so with it the text is written
  slower: page 1 in 74.0 s (introduction, x1.36) and 79.1 s (ending, x1.60: its tune is busier); the whole
  introduction in 534 s (the CPC: 386 s for its 8 pages, 9 here with the credits). These are baseline measurements;
  both programs now use the shared 0xB0 delay.  To keep
  the pace, the loop's 0x160 would be ~0x103 for the introduction and ~0xDC for the ending (a per-build constant), or
  the wait would follow a timer as src/c64/pergamino does (espera.s: deadlines on CIA 2, the drawing and the interrupt
  absorbed).
* **Any key** ends the parchment (the `cgetc` waits take any key, and so does the `kbhit` test); the CPC took space
  only.  Space alone would need the waits changed too (`if (k == ' ')`).
* **The ending's passes**: each pass reads pp.bin again (the manusini), ~10 s of a brown screen between passes (the
  CPC: at once).
* `manusmkytoscreen`'s 16 bytes past its table (above): harmless here, not changed.
* The P500 (`__CBM510__`) code is kept as it was, not built nor adapted to the new order.
* The game came from drive 9: "final" loads from there, but its text2.bin and pp.bin are read from drive 8
  (plat_final's stub runs RAMTAS, which clears $BA; cc65 then takes 8): a change in the game's platform
  (src/c64/plataforma/disco.s: $BA set after RAMTAS), not made here.

## Found on the way: the game's percentage at its end (src/c64/juego_final/principal.s, not changed here)

The game-over screen of the C64 game shows the percentage wrong (`resultados/11_juego_100.png`: "HAS RESUELTO EL 10
POR CIENTO" at 100 %).  The CPC's game_compute_percentage (3DA8) writes three bytes into the text it prints: `LD
(3E61),A` (a space, or '1' at 100 %) and `LD (3E62),HL` (tens, units), so the CPC shows " 100 POR CIENTO" or
"  45 POR CIENTO".  The C64's game_check_end copies only D64_GAME_PERCENT_DIGITS and +1 into its own copy of the text
(`digitos`), not +2: at 100 % it shows "10", otherwise only the tens ("  4  POR CIENTO" for 45).  The fix:
`lda D64_GAME_PERCENT_DIGITS+2` / `sta digitos+2` after the two copies (the 100 % test reads `digitos` and is not
affected).  The whole-game check compares the memory, not the screen, so it did not show.

## The ending's text (text2.bin, the tape's)

```
 Desfigurado por la
angustia, por el aco-
so del veneno que ya
serpenteaba abundante
por sus venas, el
otrora venerable ros-
tro del anciano se
veia repulsivo y gro-
tesco.
 Habriamos podido
atraparlo con calma,
pero nos precipitamos
con vehemencia sobre
el. Logro zafarse y
apreto el libro contra
su pecho para defen-
derlo. Yo lo tenia co-
gido con la mano iz-
quierda, mientras con
la derecha trataba de
mantener en alto la
lampara. Pero roce
su rostro con la lla-
ma y emitio un so-
nido ahogado, casi un
rugido, dejando caer
trozos de folio por
la boca. Su mano
derecha solto el li-
bro, busco la lampa-
ra y, de un golpe, me
la arranco lanzandola
hacia adelante...
 Se derramo el acei-
te, y en seguida el
fuego prendio en el
pergamino que ardio
como un haz de hor-
nija reseca. Todo su-
cedio en pocos instan-
tes; una llamarada se
elevo desde los libros,
como si aquellas pa-
ginas milenarias lle-
varan siglos esperan-
do quemarse y goza-
ran al satisfacer de
pronto una sed inme-
morial de ecpirosis.
 La abadia ardio du-
rante tres dias y tres
noches y de nada va-
lieron los ultimos es-
fuerzos.  Al tercer
dia, curados los heri-
dos, enterrados los
cadaveres que habian
quedado fuera de los
edificios, los monjes
y el resto de los po-
bladores de la abadia
recogieron sus perte-
nencias y abandonaron
la meseta, que aun
humeaba, como un lu-
gar maldito.
 Guillermo y yo nos
alejamos de aquel pa-
raje en dos cabalga-
duras que encontramos
por el bosque. Cuando
llegamos a  Munich
tuve que separarme,
no sin derramar
abundantes lagrimas,
de mi buen maestro.
Despues de darme
muchos buenos con-
sejos para mis fu-
turos estudios, me
estrecho entre sus
brazos, con la ter-
nura de un padre, y
me dijo adios. Jamas
volvi a verlo.
 Ahora, ya en el um-
bral de la muerte,
cuanto mas releo la
historia que de ello ha
resultado, menos se
si esta contiene o no
una trama distinguible
de la mera sucesion
natural de los aconte-
cimientos y de los
momentos que los re-
lacionan entre si. Y
es duro para este
viejo monje no saber
si la letra que ha es-
crito contiene o no
algun sentido oculto,
ni si contiene mas de
uno, o muchos, o nin-
guno.
 Pero quizas esta
incapacidad sea pro-
ducto de la sombra
que la gran tiniebla
que se aproxima, pro-
yecta  sobre  este
mundo ya viejo.
 Hace frio en el
scriptorium, me duele
el pulgar. Dejo este
texto, no se para
quien, este texto, que
ya no se de que ha-
bla.
```
