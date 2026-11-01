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

# The Commodore 64 platform

[Home](Home.md) · previous: [Sound](Sound.md) · next: [The Commodore 128](C128.md)

The game never touches the hardware: every access of the original to the CPC's hardware is a call to the platform
layer, `src/c64/plataforma/`, with the CPC's values.  These few routines are all that makes the CPC game a C64 game.

| File | What |
|---|---|
| `interrupcion.s` | the machine's set-up, the 300 Hz interrupt, `DI` / `EI`, the random byte |
| `pantalla.s`, `tinta.s` | the CPC screen address to the bitmap; the inks |
| `psg.s` | the AY's registers on the SID ([Sound](Sound.md)) |
| `teclado.s` | the CPC's keyboard matrix from the C64's keyboard and joystick |
| `disco.s` | saving and loading a game, and the ending's load, through the KERNAL |
| `c128.s` | the Commodore 128's own parts ([The Commodore 128](C128.md)) |

## The set-up

`plat_inicio` turns the C64 into the machine the game expects: no ROMs (RAM everywhere but the I/O), every interrupt
off but CIA 1's timer A every 3279 cycles (the CPC's 300.48 Hz), the vectors in RAM, the VIC-II in bank 3 with the
multicolour bitmap at `$E000` and the screen RAM at `$C000`, everything black, and the SID at rest:

{{code src/c64/plataforma/interrupcion.s | ^\.proc plat_inicio | ^\.endproc}}

## The keyboard and the joystick

The game reads the CPC's keyboard as ten rows of eight keys (`sys_read_keyboard`).  Reading the first row makes the
C64 scan its whole keyboard and the joystick in port 2 and translate them, key by key, into the CPC's matrix; the
other nine rows return that picture:

{{code src/c64/plataforma/teclado.s | ^; plat_teclado_fila: A = CPC matrix row | ^;     are left out of the scan}}

## The inks

See [Memory map](Memory-map.md), "The screen": a CPC ink becomes `$D021`, a nibble of the screen RAM or the colour RAM
of the game's cells, and no pixel is redrawn.  The game's palette tables already hold C64 colours, chosen by hue from
the CPC's (`src/c64/datos/paleta.tsv`).

## The disk and the KERNAL

The game uses the zero page and pages 2-3, which the KERNAL needs.  To save or load a game (CTRL + ← in the game) or
to load the ending, the platform puts the KERNAL's part of those pages aside, gives them the values the KERNAL starts
with, switches the KERNAL ROM in, calls it, and puts everything back:

{{code src/c64/plataforma/disco.s | ^; plat_disco_guarda: In: zhl | the game has them \(the serial code}}

The saved game is the 1500-byte state block that the CPC saved to tape (the characters, the objects, the doors, the
clock, the scripts' variables), as a file `ABADIA64.BSn` — n being the last digit key pressed, so ten games can be
kept.  On the tape release the same menu saves and loads on the tape through the KERNAL's tape routines.

## The random byte

The original reads the Z80's refresh register (`LD A,R`) once: to choose the mirror's numeral.  The C64 combines the
CIA's timer, which runs within the tick, with the raster line:

{{code src/c64/plataforma/interrupcion.s | ^\.proc plat_aleatorio | ^\.endproc}}
