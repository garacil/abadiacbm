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

# The whole 6502 game (hibrido --juego6502) against the Z80 from each day 1-7 at each hour 0-6 (the start states
# of juego/puro/pruebas/dias.sh: [BF4F] = day, [BF4E] = hour), a long random script each, then the 100 % ending
# (juego/puro/pruebas/final.sh's state: day 7, tercia, the investigation solved): the 6502 must reach plat_final
# with the memory the Z80 has at 31CFh.
# With --rutinas, each translated routine is checked call by call instead (--6502 --solo-6502), from the same
# states and scripts.
#   dias.sh [--rutinas] [FRAMES_TO]
set -uo pipefail
modo=(--juego6502); resumen='6502 game'; bien=' 0 with differences'
if [ "${1:-}" = --rutinas ]; then modo=(--solo-6502 --6502); resumen='6502 routines'; bien=' 0 differences'; shift; fi
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
J=$P/juego; T=$P/../data
HASTA=${1:-6472}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
k=0
for d in 1 2 3 4 5 6 7; do for h in 0 1 2 3 4 5 6; do
    g=$T/guiones_largos/largo$((101 + k % 16)).txt; k=$((k + 1))
    "$J/hibrido" $T/puro/estados/ram_d${d}h$h.bin $T/cpc64/inicio_juego/estado.txt $T/sincrono/puntos64.txt \
        --guion $g --hasta $HASTA --limite 50000000 "${modo[@]}" "$D" > $W/log_$d$h 2>&1 &
done; done
python3 -I - "$T/puro/estados/ram_d7h2.bin" "$W/fin.bin" <<'PY'
import sys
d = bytearray(open(sys.argv[1], 'rb').read()); d[0x37F4] = 0; open(sys.argv[2], 'wb').write(d)
PY
"$J/hibrido" $W/fin.bin $T/cpc64/inicio_juego/estado.txt $T/sincrono/puntos64.txt --guion $T/guiones_largos/largo101.txt \
    --hasta 3000 --limite 5000000 "${modo[@]}" "$D" > $W/log_fin 2>&1 &
wait
mal=0
for d in 1 2 3 4 5 6 7; do for h in 0 1 2 3 4 5 6; do
    l=$(grep "$resumen" $W/log_$d$h | tail -1); echo "day $d hour $h: ${l##*; }"
    case "$l" in *"$bien"*) ;; *) mal=1; grep -E '^6502 (GAME|DIFF)' $W/log_$d$h | head -3 | cut -c1-300 ;; esac
done; done
l=$(grep "$resumen" $W/log_fin | tail -1); echo "ending: ${l##*; }"
case "$l" in *"$bien"*) ;; *) mal=1; grep -E '^6502 (GAME|DIFF)' $W/log_fin | head -3 | cut -c1-300 ;; esac
exit $mal
