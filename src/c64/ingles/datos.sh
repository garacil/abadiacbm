#!/bin/bash
# abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
#
# Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along with this program.  If not, see
# <https://www.gnu.org/licenses/>.

# The English language's data for the tape (c64/cinta): from the translation (frases_en.txt, the parchments'
# texts, glifos_en.py, dia_en.py, titulo_en.py) into c64/ingles/generado:
#   ram_en.bin       the CPC game's image with the English texts and the score bar's "Day" (genera_ram_en.py)
#   c64graf/         its graphics converted for the C64 (tools/c64_graficos.py, the same rules and
#                    hand edits as the Spanish ones)
#   pergamino/       the parchments' English text1.bin, text2.bin, pp.bin and their sizes (pergamino_en.py)
#   abbey.koa        the picture with the English title (titulo_en.py)
# The game's English image is the same sources built with these (c64/juego_final: C64=1 CINTA=1 IDIOMA=en).
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
G=$D/generado
mkdir -p "$G/c64graf"
cd "$D"
python3 -I genera_ram_en.py "$G"
python3 -I "$P/../tools/c64_graficos.py" "$G/ram_en.bin" "$G/c64graf" > "$G/graficos.txt"
python3 -I pergamino_en.py "$G"
python3 -I titulo_en.py "$G/abbey.koa" "$G/abbey_koa.png"
