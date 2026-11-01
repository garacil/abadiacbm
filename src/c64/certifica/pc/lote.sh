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

# abadia128ks against the PC (milestone H10, the full game): for each seed a random key session of FRAMES frames
# (tools/guion_azar.py: walking, turns, cursor down, space, pauses), the PC rebuild with arnes.c and
# the C128 build in x128 (corre128.py) with the same keys, then compara.py; the reports in OUT/resumen.txt.
#   lote.sh JUEGO_DIR PC_BUILD_DIR OUT FRAMES PARALLEL SEED...
#   (CORRE=corre500.py and JUEGO_DIR c64/juego_final/p500: the P500 build on its own disk instead of the C128's)
set -uo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)
P=$(cd "$AQUI/../../.." && pwd)
J=$1; PCB=$2; OUT=$3; N=$4; PAR=$5; shift 5
mkdir -p "$OUT"
printf '3 key F1:0.3\n4 key space:1\n36000 stop\n' > "$OUT/entra.guion"
sesion() {
    local s=$1 d="$OUT/azar$1"
    mkdir -p "$d"
    python3 -I "$P/../tools/guion_azar.py" "$s" 1 "$N" | python3 -I -c '
import sys
held = {}
for l in sys.stdin:
    x = l.split()
    if not x or x[0].startswith("#"): continue
    f, (r, b), n = int(x[0]), x[1].split(":"), int(x[2])
    for k in range(f, f + n): held.setdefault(k, []).append(8 * int(r) + int(b))
for f in sorted(held): print(f, *held[f])' > "$d/teclas"
    ARNES_TECLAS="$d/teclas" ARNES_VOLCADO="$d/pc.vol" ARNES_FOTOGRAMAS=$N "$PCB/abadia" --verificar "$OUT/entra.guion" --salida "$d" --segundos 36000 > "$d/pc.log" 2>&1
    DISPLAY=:99 timeout 14400 python3 -I "$AQUI/${CORRE:-corre128.py}" "$J" "$d/teclas" "$N" "$d/c128.vol" > "$d/c128.log" 2>&1
    python3 -I "$AQUI/compara.py" "$J" "$d/c128.vol" "$d/pc.vol" > "$d/compara.txt" 2>&1
    { echo "azar$s: $(tail -1 "$d/c128.log"); $(head -1 "$d/compara.txt")"; sed -n '2,6p' "$d/compara.txt"; } >> "$OUT/resumen.txt"
    rm -f "$d/pc.vol" "$d/c128.vol"
}
for s in "$@"; do
    while [ "$(jobs -r | wc -l)" -ge "$PAR" ]; do sleep 5; done
    sesion "$s" &
done
wait
echo FIN >> "$OUT/resumen.txt"
