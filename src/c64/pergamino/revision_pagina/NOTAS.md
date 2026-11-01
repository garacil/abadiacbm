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

# The parchment's page turn, CPC against C64

The parchment's page turns were bad and slow, and when the new page appeared the previous page's capitals showed:
the red ones; only the black ones were erased.

Everything below was measured on the emulators with deterministic tools (this directory); the CPC is the
Caprice32 driven through its control socket, the C64 VICE (x64sc) through its binary monitor, both on Xvfb :99.

## Measurements

| | the page turn (CPC 65FDh) | how |
|---|---|---|
| CPC (Caprice32) | **3.035 s** (152 frames, each end within a frame) | `cpc_pagina.py`: a reading of the Z80's registers and stack at every frame; inside the turn while 65FDh's return address is on the stack |
| C64 before | **20.32 s** (20 022 703 cycles) | `c64_pagina.py`: from the first corner (`_esquina_asm`) to the next keyboard read |
| C64 after | **3.037 s** (2 991 806 cycles); the ending (-DFINAL) 3.045 s | the same |
| C64 after, step by step | 3.021-3.023 s for the 91 steps of the 1st, 2nd and 3rd turns of the introduction and the ending's 1st (`pasos_c64*.tsv`) | `mide.sh` (probes in a test build, below) |

Before the turn both wait three delays of 65536 passes (6756h): the CPC 1.834 s (a pass 9.33 us with the music's
interrupt, from the readings of BC), the C64 1.808 s (espera.s's 9.0625 cycles a pass); left as it was (it is the
text's pace too, ESTADO.md).

**A CPC step** (one corner, its delay of 2000 passes, the border restores), from the readings taken inside each step's
delay (BC there tells how long ago it began; `cpc_pasos.py`): first phase 20.00 ms + 0.569 ms a band of the corner,
second phase 18.47 ms + 0.569 ms a band, 3.031 s for the 91 steps; a second run: 20.18 / 18.61 / 0.565, 3.036 s (the
rest is the music's interrupt, which makes the passes 9.2-10.9 us; residuals 2 ms rms).  The corner's bands grow from 3
to 47 in the first phase (45 steps from the top right) and shrink from 47 to 2 in the second (46 steps down the left):
the CPC's steps last from 20 ms to 47 ms.

## What was wrong

1. **The red capitals stayed on the new page.**  The capitals are sprites (the hires cell has no room for a third
   colour).  pixel.s's `mira_capitales` read the row's capital bits from bit 7 down as capitals 0, 1, ... while main.c
   sets bit i for capital i, so the byte ranges it compared were another capital's and `borra_capitales` was never
   called for the corner's bytes: the sprites stayed whole until `capitales_fuera()` at the end of the turn, over the
   new pink page (`antes_20s.png`: the "Y" on the new page from 12 s, the "M" from 14 s, both to the end at 20 s).  The black text, in the bitmap,
   went with the corner.
2. **Slow: 20.3 s instead of 3.0 s** (223 ms a step on average).  The corner went through pixel.s's per-pixel path
   for most bytes (pen 1 in a pink and black cell: the full path, `decide` and `vacia` for each pixel) and the border
   restores through C's `pon_byte` (32 bytes a step, each on the full path); the music's interrupt and the VIC's DMA
   take 35-40 % of the CPU besides (a timed loop, below).  And `espera` measures the time since the previous wait as a
   16-bit difference of CIA 2's timer (espera.s): a drawing longer than 65536 cycles between two waits loses its
   multiples of 65536 cycles and the wait goes on (seen in a first version of the new code: steps of 86-180 ms with
   16-35 ms of wait in them).
3. **The pace.**  Each step waited `espera(2000)`, the CPC's delay alone (18 125 cycles, 18.4 ms): even with a drawing
   of no time the turn would have taken 91 x 18.4 ms = 1.67 s, not the CPC's 3.0 s.

## What changed (src/c64/pergamino)

* `pagina.s` (new, assembled at the end of pixel.s so the disk's build is unchanged): the whole page turn in assembly.
  * The corner (686Ch) in three passes (the CPC's writes are each "pen 1: set and red foreground" or "pen 0: clear", so
    their order does not matter): the strip of F0 at byte 0 a cell row at a time, the edge and its 00 band by band
    (one bitmap byte when the edge is a high nibble), the last band's F0 run a whole byte for two.  Every cell the
    corner reaches has the parchment's pink as its background (checked in datos.c: the 92 border cells all have
    background 10), where pixel.s's colour rule comes down to that; another background would take pixel.s's full
    path (`nib`).  Own cycles (`perfil.py`: the turn on the project's 6502 core): 1.08 M for the whole turn, the
    largest corner 25 618 cycles (47 bands, `pasos_c64_propios.tsv`).
  * The capitals: in the first phase the bytes the corner has written by a step are exactly bytes x >> 2 .. 55 of
    its bands' lines (each band appears as the last band's run and then gains one byte to the left a step), so after
    each step every capital sprite loses its pixels right of 4 (x >> 2) on the lines the corner covers
    (`capitales_paso`, a few rows of three ANDs).  At the end of the first phase nothing is left of them (as on the
    CPC); `capitales_fuera()` switches them off after the turn.
  * The restores (65A4h, 6633h, 666Bh) put back the blank parchment's border cells (`perg_blanco_*`, the cells the
    parchment starts with; main.c indexes the ring in `perg_anillo`) instead of the CPC's bytes through the pixel
    rule: a whole cell where the CPC has put back all of what the corner had taken, else those lines or that nibble of
    the blank cell's bitmap (the cell keeping its red foreground until the next step completes it).  Which is which
    follows from the corner's geometry (written out in pagina.s).
  * The time: each step waits with espera.s's deadline for the CPC's step, 2174 + 62 c passes (first phase) or 2008 +
    62 c (second), c its bands, so the drawing is absorbed and the turn has the CPC's pace and length.
* `pixel.s`: `mira_capitales` fixed (bit i is capital i; the range checks in `borra_cap`, assembly); the corner's old
  code, `rapido` and its 2 KiB of mask tables removed.
* `main.c`: `pasa_pagina` is pagina.s's; the capitals' window x and line exported for it; the border ring indexed in
  `pergamino_en_blanco`; `borra_capitales` (C) gone.
* `sid.s`: the music interrupt's copy of the shared zero page unrolled (388 cycles a tick to 168, counted from the
  instructions: the loops' 2 + 8 x 16 - 1 + 2 + 4 x 16 - 1 each way against 12 x 7; the same bytes kept,
  the music unchanged: `data/pruebas/prueba_musica.sh inicial|final` identical, `src/c64/optimizacion/sid/pruebas/
  sid_pergamino.sh` the same gates and frequencies).
* Sizes: the first stage 21 304 -> 20 053 bytes (loads in 51.4 s, was 53.5), the ending 19 476 -> 18 225.

## The C64's margin

`pasos_c64.tsv` (introduction, 1st turn) and `pasos_c64_final.tsv` (the ending, whose music takes 40 % of the CPU): for
each step the corner, the wait left and the restores, in cycles.  The least wait: 1.9 ms (step 42, 44 bands) and
1.8 ms (the ending's step 46); no step overruns.  (In the test build the first step has no wait: its probes time a
loop of 51 359 cycles first, to measure the music's share: 34.6 % and 40.3 %.)

## Pictures

* `tiempo_cpc_c64.png`: CPC | C64 before | C64 after, every 0.5 s from the start of the turn (the screenshots of
  `capturas/`, each C64 one the nearest in time to the CPC's).  The C64 after follows the CPC frame for frame; before,
  the corner had barely left the top right at 3.5 s.
* `antes_20s.png`: the C64 before over its 20 s, every 2 s: the red capitals on the new page.
* `pasos_cpc_c64.png`: CPC | C64 after held at the same step of the corner (the corner drawn, the borders not yet put
  back; CPC: a stub counting the steps holds the Z80, `cpc_pagina.py --pasos`; C64: a JMP * barrier at `_espera`).
* `diferencias/dif_paso*.png`: CPC | C64 | the pixels whose colour differs (white), at the held steps
  (`compara_mem.py`: both screens from memory, the CPC's pens in the port's C64 colours).

| step (bands) | 1 (3) | 10 (12) | 30 (32) | 40 (42) | 45 (47) | 46 (47) | 60 (33) | 80 (13) | 91 (2) |
|---|---|---|---|---|---|---|---|---|---|
| pixels unlike the CPC | 993 | 1004 | 1095 | 1169 | 781 | 593 | 710 | 869 | 989 |
| of them in the border's cells | 993 | 1004 | 995 | 1036 | 781 | 593 | 710 | 869 | 989 |

## What still differs, and why

* **The border's cells** (all but 72-133 of those pixels): 74 cells of the border ring hold pink, the black outline
  and dark red; with two colours a cell the blank parchment's cells (made by `tools/c64_pergamino_datos.py`
  with pixel.s's rule, where pen 1 always becomes the foreground) show the black outline red in them: 993 pixels at
  the start, the same on every page.  Choosing each cell's foreground by its majority would leave 661; that is the data
  generator's, outside src/c64/pergamino (proposed, not done).
* **The text beside the strip** (72-133 pixels at steps 20-40): a cell where the turned page's dark red meets the old
  text has three colours; pixel.s's rule makes the text's pixels in it red for that step (the dark back of the page
  covering them), as before the change.
* **The colours**: the CPC's dark red (1C) and pink (07) as C64 red and light red; VICE draws its palettes through its
  own colour settings (colodore.vpl's red 150,40,46 shows 211,40,49), so the screenshots' reds look brighter than
  the CPC's.
* **A half cell for one step**: where the CPC has put back half a border cell whose other half the corner still holds,
  the border's dark pixels there show red until the next step (one 20-47 ms step).

## The tools

| | |
|---|---|
| `cpc_pagina.py OUTDIR [--cada MS] [--pasos k,...]` | the CPC's turn in Caprice32 (its own socket in a new short directory): the duration, screenshots, the readings (`lecturas.tsv`), the held steps |
| `cpc_pasos.py LECTURAS.tsv` | the CPC's step time fitted (A + B bands) from the readings inside the steps' delays |
| `c64_pagina.py PRG LBL OUTDIR [--cada MS] [--pasos k,...] [--solo-pasos] [--sin-warp]` | the C64's turn in VICE (colodore palette): the duration, screenshots, held steps (memory dumps for compara_mem.py) |
| `mide.sh [-f] [-2] [OUT.tsv] [--vuelta N]` | a test build with pagina.s's probes (MIDE): each step's corner, wait and restores; `-f` the ending, `-2` the corner with the interrupt held off (its own cycles), `--vuelta N` the N-th turn (`c64_pasos.py`) |
| `perfil.py [STEPS.tsv]` | the turn's own cycles by routine on the project's 6502 core (`perfil6502.c` with src/juego/m6502, read only), from VICE's RAM at `_pasa_pagina` |
| `compara.py tiempo|pasos OUT.png CPCDIR C64DIR[=label]...` | the side-by-side pictures |
| `compara_mem.py CPCDIR C64DIR... [--fotos DIR]` | the pixel comparison of the held steps |
| `antes/` | the build before the change (main.c, pixel.s, espera.s, the PRGs and their labels) |
| `capturas/` | `cpc/`, `c64_antes/`, `c64_despues/`: the screenshots, memory dumps and durations the pictures and tables come from |

Notes on the tools: VICE's binary monitor may resume once more when a checkpoint is hit soon after an EXIT (and in
warp mode may not report it), so points close together are reached with a JMP * barrier found by stopping and
looking (`barrera`); the build before the change gave wrong pictures when held by barriers (its drawing went another
way), so its pictures here are the time-based ones only.  Caprice32's reply to a command comes at the next frame top
or at its cycle-count exit, two readings a frame.
