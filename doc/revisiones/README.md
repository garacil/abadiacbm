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

# Reviews: the C64 against the CPC, with pictures

Three reviews made while the first C64 disk took shape, each a question answered by measuring the
C64 build against the original and kept with its pictures.  Their scripts are kept as they were run; their outputs
here are the record.

| Directory | What |
|---|---|
| `adso/` | Adso's walking frames on the C64 against the CPC's, before and after the conversion rules (`antes/`, `despues/`, `conversion/`: the font, the score bar, room 16h and the sprites converted; `variantes.png`).  Checked with `src/c64/juego_final/vice/adso.py OUTDIR --comprueba --vice`: the 16 animation frames in VICE, both alignments, the reflected bytes and every composed pixel. |
| `flauta/` | the SID voicing of the idle melody (a soft triangle, a recorder's sound) and the first disk's run with it: every parchment page as the model, the picture during the load, the game's frames (`resultados.txt`, the pictures). |
| `pantalla_carga/` | the CPC's loading picture on the C64 (`NOTAS.md`): the mode 0 pens decoded as the CPC does (checked against Caprice32), the colours chosen on a real C64's palette with CIEDE2000, before and after (`analiza.py`, `comparacion.png`, `detalle.png`); `pantalla.py` made `src/c64/pergamino/carga.c` for the first stage of that time; `previas/` the picture built up as it loaded.  The disks now show the presentation's own loading picture instead. |
