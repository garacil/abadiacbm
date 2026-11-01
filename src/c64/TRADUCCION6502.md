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

# abadia64ks: translating the game to 6502 (H4) — the method, group by group

The game exists in C (`src/juego/f_*.c`, checked against the original Z80 frame by frame) and must become 6502
assembly (ca65) for the Commodore 64 (later the Atari), because cc65 would make ~60 KB of code from that C
and the C64 has 26961 bytes for code.  I translated the game group by group (the seven groups of the C); every
routine is checked in shadow against the Z80 at every call the 8 exploration sessions make.

## What I started each group from

* `src/c64/CODIGO6502.md` — the conventions: registers (Z80 pairs in zero page), data, traps, platform calls,
  zero page per group, size and speed budget, checking.
* `src/c64/MAPA.md`, `src/c64/NOTAS_MAPA.md` — where every datum lives; `src/c64/NOTAS_GRAFICOS.md` — the C64 graphics
  formats (tiles 16 bytes column-major at $D000 + 16n, sprites row-major with the padding nibble, font 4 bytes
  a glyph, the merge tables, the score bar in the bitmap).
* The group's C: `src/juego/f_<group>.c`, `src/juego/datos_<group>.h`; the Z80 listings `data/cpc64/listado/*.asm`
  (and z80dasm on `data/cpc64/juego/ram.bin`, the original tape's memory at the game's start).
* `src/c64/juego/mapa64.inc` (every `D64_` name at its C64 address), `punteros64.tsv` (pointer fields),
  `resultados.tsv` (the format of the result declarations), `plataforma.inc`, `zp.inc`, the pilot routines
  `motor_iso.s` and `camino.s`.

## Each group's working copy

I worked each group in `src/c64/juego_<group>/`, a copy of `src/c64/juego` at the same depth (so that its relative
paths work), and changed only `<group>.s` there (more files when useful) and the group's lines of `resultados.tsv`.
I did not change the map files (`bloques64.tsv`, `mapa64.*`, `punteros64.tsv`, `datos64.*`) or `src/juego/` (the C,
the host) from a group's work: a change needed there I made on its own, in one place, and noted.  Build:
`./construye.sh` in the group's directory; `src/juego/hibrido` stays as it is meanwhile.

## Check

From `src/juego/`: `./hibrido ../../data/cpc64/inicio_juego/ram.bin ../../data/cpc64/inicio_juego/estado.txt
../../data/sincrono/puntos64.txt --guion ../../data/cpc64/exploracion/azarN.txt --hasta 4472 --limite 50000000
--6502 ../c64/juego_<group> --solo-6502` for N = 1..8 (each prints "6502 routines: X calls, Y differences, Z
traps"); `SOMBRA6502_CICLOS=file` adds the cycles per routine.  For more coverage, the long scripts
`data/guiones_largos/largo1NN.txt` (20000 frames each: `--hasta 20472`).  I accepted a routine only with 0
differences; a routine the sessions never call must at least assemble and be explained in the group's notes.

## My rules

* One routine per Z80 function of the group's table (`traducidas_<group>` in `f_<group>.c`), with the C
  function's name (`.export name`), entered with the Z80 function's registers (CODIGO6502.md).  Functions the
  C keeps as internal helpers (static) become local labels or the group's own routines with names prefixed by the
  group (`<group>_...`) so that nothing clashes when the groups are merged.
* Calls to other groups' functions: `.import name` and `JSR name` (a stub/trap until they are translated).
* Data under the I/O ($D000-$DFFF: tiles, faces, door, numerals, light): switch the I/O off around the
  access (`lda #$34 / sta $01` ... `lda #$35 / sta $01`); the C64's interrupt handler keeps $01 itself.  In
  the host's core the memory is flat, so this costs nothing there but must be right for the C64.
* Platform calls (`plat_*`) as in CODIGO6502.md; the screen: write the bitmap directly in the C64 format
  (the CPC byte at screen address a is the nibble of `$E000 + 320 row + 8 (xb / 2 + 4) + line`, high when
  xb is even; never touch cells 0-3 / 36-39 or row 24: they hold data); declare `PANTALLA` in resultados.tsv
  for routines that draw, so the screen is compared.
* Size first: shared helpers, tables, loops; within the group's budget (CODIGO6502.md).  Speed where it matters
  (drawing, path search, the script interpreter): the cycles per call of the hot routines measured and noted.
* Comments in English; deterministic tools only.

## What I wrote down for each group

In `src/c64/juego_<group>/NOTAS.md`: per routine, its bytes (from `juego.map` / the listing), the calls checked and
the cycles per call; the group's total size against its budget; the routines not exercised; the traps still used
(calls to other groups); anything odd and any change needed in the map or the host.
