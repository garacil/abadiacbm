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

# The presentation's test disk (src/c64/presentacion/pruebas/disco_prueba)

The first C64 disk (the presentation, the game's stream and the ending, without the start menu), kept
as the test bench of the presentation that all three releases carry: `construye.sh` builds `presentacion.d64`
(not a release) and `prueba.py` checks it in VICE.

    src/c64/presentacion/pruebas/disco_prueba/construye.sh      # presentacion.d64 (the game's C64 build first)
    src/c64/presentacion/pruebas/disco_prueba/prueba.py [OUTDIR] # the checks; pictures and resultados.txt

The disk's files, in this order: "abadia" (the first stage, `LOAD"*",8,1` + `RUN`: the presentation, the parchment
with the introduction text, then on a key the picture on the game's screen and the game's loader), "abadia.koa",
"text1.bin", "pp.bin", "juego" (the stream: `src/c64/cinta/FLUJO.md`), "final" (the ending, loaded by the game's
plat_final at 100 %) and "text2.bin".  `resultados/` holds the pictures of its first runs.

## The test (`prueba.py`, VICE x64sc 3.10, a 1541 with true drive emulation, warp, Xvfb :99)

Driven through VICE's binary monitor only while stopped (`src/c64/plataforma/pruebas/vice_mb.py`): checkpoints at the
programs' labels (src/c64/presentacion/generado: abadia.lbl, final.lbl, cargador.lbl; juego.lbl), memory read from the RAM
and I/O banks, the display buffer as PNG; times from CIA 2's timers cascaded as a 32-bit cycle counter, set and read
while stopped; `LOAD"*",8,1` and `RUN` typed through the keyboard feed at BASIC's READY; SPACE put down in a snapshot
(its KEYBOARD module patched, as the platform's tests do).  Three runs: A, the disk from READY (the parchment,
its pages and music, the picture during the load, the game); B, the reference for the game's frames (the image
written into the RAM); C, the ending through the game's own code from a state one step from 100 %
(src/c64/presentacion/pruebas/estado_final.py).  The checks and their results: src/c64/presentacion/NOTAS.md, "Tests and
results"; `src/c64/presentacion/resultados/resultados.txt`.
