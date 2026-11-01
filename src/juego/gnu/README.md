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

# abadia64ks for GNU

The CPC 64 KiB (tape) version of La Abadía del Crimen in an SDL2 window, from start to end as the CPC
shows it: the introduction parchment with its music, the loading screen appearing as the tape loads it,
the game, and at 100 % the ending parchment, for ever.

## Build and run

    make -C src/juego/gnu                 # needs SDL2 (pkg-config sdl2); TRABAJO=DIR if data/ is elsewhere
    src/juego/gnu/abadia64ks-puro         # the game in pure C (no Z80 core); F12 or closing the window quits
    src/juego/gnu/abadia64ks              # the same on the hybrid host (Z80 core + C), for comparisons

Both give the same pictures, AY writes and sound frame by frame (`src/juego/puro/pruebas/frontal.sh`).

* **Introduction**: the parchment writes its text with its music.  Space skips it; hold it a moment, as on
  the CPC: the parchment looks at the keyboard once per character (a gothic capital takes about 0.3 s).
* **Loading screen**: mode 0, 32 x 24 characters, the picture appearing in the order the tape's bytes fill
  the screen memory (from FFFFh down: the eighth line of every character row first, bottom to top).  The
  real tape takes minutes; here the 16 KiB of the screen take 4 s (`--carga MS`), then 1 s more.
* **The game**: cursors walk and turn, space, Q R S N Y and the rest of the CPC keys at their places.
* **The ending**: at 100 % the game prints "PON EL CASSETTE EN MARCHA" and loads the ending from tape
  (3 s here, `--cinta MS`), then the ending parchment over and over: space turns the screen black and it
  starts again.

Other options: `--escala N` (window scale, 3), `--sin-sonido`, `--etapa juego` (start at the game, as
before), `--etapa final` (only the ending), `--trabajo DIR`.

At run time (development build) it reads the tape's memory images `data/cpc64/cinta/primera_etapa.bin`,
`juego.bin`, `final.bin` (made by `tools/cinta64.py`), the game's start
`data/cpc64/inicio_juego/` and the wait points `data/sincrono/puntos64.txt`.

## How it is made

* `src/juego/pergamino.c`: the parchment code of the tape (6000h-68A8h, the same for both parchments) in C,
  drawing the same bytes into the CPC screen memory as the Z80, timed in Z80 T-states (busy loops,
  drawing and the 300 Hz music interrupt included); `src/juego/musica.c` is the music player (the C64's, with
  the T-states of each path counted on a host build).  Also the tape loader's loading screen.
* `src/juego/gnu/abadia64ks.c`: the platform (screen as the CRTC and gate array show it, keyboard matrix, an
  AY synthesiser, real-time pace) and the hybrid host (`src/juego/hibrido.c`) for the game.

## Tests

`src/juego/gnu/prueba.sh [OUTDIR]` runs both parchments in the CPC simulator (`cpc_carga.py`) and in
`abadia64ks --rapido` on Xvfb :99 and compares every frame (screen memory, inks, mode, CRTC), every AY
register write and the pictures of some frames pixel by pixel (about 2 minutes).  The test options
(`--guion-perg`, `--volcado`, `--fotos`, `--ay`, `--wav`, `--hasta-perg`, `--salta-final`, `--guion`,
`--hasta`, `--captura`) are described at the top of `abadia64ks.c`.
