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

# The three sessions run once per batch of hit labels (8 labels each: hibrido counts at most 8), the cycles of each
# module and the hits per frame (SOMBRA6502_CATEGORIAS, src/c64/juego_final/categorias64.py).
#   golpes.sh WORK      WORK: made by ../copia.sh, its game built by construye_prueba.sh, and the batches hits_batch_K (one label a
#                       line); the outputs go there (categorias_BK.txt, catBK_N.tsv, runBK_N.log)
set -u
S=$(realpath "${1:?WORK}"); D=$S/src/c64/juego_final; P=$(cd "$(dirname "$(realpath "$0")")/../../.." && pwd)
for b in "$S"/hits_batch_*; do
  k=$(basename "$b" | sed 's/hits_batch_//')
  python3 -I "$P/src/c64/juego_final/categorias64.py" "$S/categorias_B$k.txt" --juego "$D" > "$S/categorias_B${k}_cols.txt"
  for h in $(cat "$b"); do a=$(grep -E " \.$h\$" "$D/juego_todo.lbl" | head -1 | awk '{print $2}'); printf 'hit %s\n' "${a:2}" >> "$S/categorias_B$k.txt"; printf '\thit_%s' "$h" >> "$S/categorias_B${k}_cols.txt"; done
  cd "$P/src/juego" || exit 1
  for N in 1 5 8; do ( SOMBRA6502_CATEGORIAS="$S/categorias_B$k.txt" ./hibrido ../../data/cpc64/inicio_juego/ram.bin ../../data/cpc64/inicio_juego/estado.txt ../../data/sincrono/puntos64.txt --guion ../../data/cpc64/exploracion/azar$N.txt --hasta 4472 --limite 50000000 --juego6502 "$D" --ciclos-frame "$S/catB${k}_$N.tsv" > "$S/runB${k}_$N.log" 2>&1; echo "exit=$?" >> "$S/runB${k}_$N.log" ) & done
  wait
  echo "batch $k done"
done
