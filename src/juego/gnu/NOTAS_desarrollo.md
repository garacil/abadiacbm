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

# The GNU version from start to end: development log (H2)

Built in a separate working copy of `src/juego/` (since merged and removed).  Tools and checks:
`tools/gnu_comparacion/`.

## Files

New:
* `src/juego/pergamino.c`, `src/juego/pergamino.h`: the parchment code (6000h-68A8h) in C, timed in Z80 T-states;
  `pergamino_final()` (the game's 31DAh loop); `pantalla_de_carga()` (the tape loader's loading screen).
* `src/juego/musica.c`, `src/juego/musica.h`: `src/c64/pergamino/musica.c` with the Z80 T-states of every path counted
  (`musica_ciclos`).  cc65 compiles it to exactly the C64's code (the counting is `#ifndef __CC65__`;
  checked: `cc65 -t c64 -O` gives the same assembly as `src/c64/pergamino/musica.c`), so it can replace the
  C64's copy and leave one source.
* `src/juego/gnu/README.md`, `src/juego/gnu/prueba.sh` (the parchments against the simulator).
* `herr/tiempos_z80.py` (T-states of every instruction of a z80dasm listing, measured by SkoolKit's
  simulator), `herr/suma.py` (sums by address range), `herr/ciclos_musica.c` (musica.c's count per tick
  against the CPC's interrupts), `herr/referencia.py` (cpc_carga.py dumping the screen state at every
  frame), `herr/compara_volcados.py`, `herr/compara_ay.py`, `herr/compara_fotos.py`.

Changed:
* `src/juego/gnu/abadia64ks.c`: the phases (introduction, loading screen, game, ending), the screen placed by
  R2/R7 and blank when R1 or R6 is 0, the sound clock shared by the parchments and the game, test options.
* `src/juego/gnu/Makefile`: `TRABAJO ?=` (by default the project's `data/`).
* `src/juego/hibrido.c`, 3 lines, inert unless a front-end sets it:
  `uint16_t parada;` after `static int retoma;`, the comment of `corre_frame` (returns 2 at `parada`), and
  in `corre_frame` after `ultimos[nult++ & 15] = pc0;`: `if (parada && pc0 == parada) return 2;`.
  `src/juego/Makefile` compiles `pergamino.c` and `musica.c` into `./hibrido` too (wildcard); they link
  (pergamino.c defines `musica_registro` on `plat_psg`) and do nothing there.

## How the parchment is timed (the point of exactness)

The CPC parchment is paced by its own code: busy loops (672Ch, 30 T-states a pass), the drawing itself,
and the 300 Hz interrupt that plays the music (1.4-13 K T-states a tick).  pergamino.c adds, routine by
routine, the T-states the Z80 instructions take (SkoolKit's table, as `tiempos_z80.py` measured them),
and runs the interrupt as cpc_carga.py does: due every 13312 T-states, taken at the first instruction
start at or after that time if interrupts are enabled, lost otherwise, a frame every 6 (taken or not).
The cost of each interrupt is 13 + JP + 613Fh + musica.c's count of 61DBh: identical to the CPC for every
tick (9529 of the introduction, 19521 of the ending with a stop and a re-entry, `ciclos_musica.c`).
A screen byte is written at its instruction's start, so the screen at every frame is the CPC's.

A quirk of the simulator reproduced on purpose: cpc_carga.py passes PC-1 as the "previous instruction" to
SkoolKit's `accept_interrupt`, which refuses the interrupt when that byte is FBh (EI), DDh or FDh, and the
interrupt is then lost (next_int was already advanced).  Besides the real EI cases (6138h, 61DAh, 6511h,
6698h, 61F2h, 6146h) this hits 66B5h (after JR ..,DDh) and 6721h (after DJNZ ..,FDh).  On a real CPC the
gate array keeps the request until it is taken.  pergamino.c follows the simulator (it is the reference);
the difference on a real CPC would be a few music ticks more per page.

## Results (tape images, `src/juego/gnu/prueba.sh`)

* Introduction (`cinta/primera_etapa.bin`, CALL 6000h, space at frame 4500): frames 1-4510 (90 s, a page
  turn at 2735, the exit) identical: screen memory, mode, inks, CRTC; all 3996 AY writes identical
  (tick, register, value); 8 pictures (frames 30-4505, three during the page turn) 64000 of 64000 pixels.
* Ending (`cinta/final.bin`, 31DAh, space at 1500 for 30 frames and at 3000 for 200 frames: the exit,
  the music restarted, 15 passes while space is held): frames 1-4500 identical, 20096 AY writes identical,
  8 pictures pixel-identical.
* The GNU WAV against the CPC's notes (`compara_audio.py`, after converting the float WAV to 16-bit PCM):
  94-95 % of 50 ms windows agree (the rest are note boundaries and chords, as with the C64 recording; the
  register writes themselves are identical).
* Real time on Xvfb :99: 250 parchment frames in 5.0 s; intro + loading + 130 game frames in 18 s.
* The whole flow: intro -> loading screen -> game (frame 472 on) -> `--salta-final` (3EC6h: the game prints
  "PON EL CASSETTE EN MARCHA", 31CFh detected) -> tape wait -> ending parchment.  Pictures checked.

## Odd things found

1. **The loader's ink table is reversed** in `data/cpc64/cinta/tintas.txt`'s description and in the new
   `data/cpc64/inicio_juego/estado.txt` palette: the loader's loop (026Ch, run at 00C6h) is
   `LD A,11h ... LD C,A; DEC C; OUT (C),C; LD C,(HL); INC HL; SET 6,C; OUT (C),C; DEC A; JR NZ`, so the
   first byte of 0103h goes to pen 16 (the border, 14h black), then pens 15, 14, ..., 0 (pen 0 = 07h).  This
   agrees with the disk repack's SCR SET INK colours (pen 0 fw 16 = hw 07, ..., border hw 14).  estado.txt
   has pen 0 = 20 (14h) and border = 7: wrong order (cinta64.py's docstring says "pens 0-15 and the
   border").  The front-end keeps the inks the loading screen set when it goes on into the game, so it is
   not affected; the hybrid's own runs only use estado.txt's palette for pictures before the game sets its
   own.  The old `cpc64/pantalla_carga/final.png` (cyan background) does not match either order of these
   inks; it predates the ink mapping.
2. A space tap shorter than one character (about 14 frames for a gothic capital) can go unseen: the
   parchment reads the keyboard once per character (also on the CPC; a 10-frame press in the simulator
   was missed).  Test scripts hold space 30 frames.
3. The simulator's reference for the tape: `cpc_carga.py DSK --imagen cpc64/cinta/primera_etapa.bin --call
   6000 --int` (the DSK argument is required but not used with --imagen); for the ending `--imagen
   cpc64/cinta/final.bin --call 31DA --int` (with `--call 6000` its RET goes to the firmware stub and the
   loop of 31DAh is lost).  After 6000h returns in the introduction the simulator runs on into nothing;
   comparisons stop at the frame of its RET (604Bh).
4. The tape's byte at 6000h (CD, CALL 6114h) against the repack's (CC, CALL Z): same path and time (Z was
   set at both callers).
5. The game's start palette/CRTC: the tape game starts with the loader's mode 0, inks and 32 x 24 CRTC;
   it sets its own at once (the first frame, 472, already shows the score bar).
6. For the pure C version: game_check_end returning 2 (3E98h -> 3EC6h -> 31CFh) must call the platform's
   ending: in this front-end that is `final_cpc(1)` (the tape wait, block 2Ah into 6000h-8BFFh,
   `pergamino_final()`).

## Not done / possible

* The tape loader's border stripes while loading (the routine at 0081h changes the border colour on the
  tape's edges) are not shown; the border stays as the inks set it.
* The firmware's look before the introduction (the BASIC loading messages) is not shown: the window starts
  at 6000h (black inks at once).
