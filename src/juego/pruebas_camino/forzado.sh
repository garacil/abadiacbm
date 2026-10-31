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

# The forced checks of the group camino (forzado.c): builds forzado and runs it from frames 1500 and 4000
# of the 8 sessions, 2000 set-ups each (deterministic seeds); prints the totals; exit 1 on any difference.
#   ABADIA64_TRABAJO=.../../data juego/pruebas_camino/forzado.sh [--cobertura-dir DIR]
set -uo pipefail
P=$(dirname "$(realpath "$0")")
J=$(dirname "$P")
T=${ABADIA64_TRABAJO:-$(dirname "$J")/trabajo}
O=${TMPDIR:-/tmp}/forzado_camino_$$
mkdir -p "$O"
cd "$P"
rm -f forzado
gcc -std=c99 -O2 -g -Wall -Wextra -I.. -o forzado forzado.c $(ls ../*.c | grep -v hibrido.c) ../z80/z80.c 2>&1 | grep -v unused
[ -x ./forzado ] || { echo "BUILD FAILED"; exit 2; }
for s in 1 2 3 4 5 6 7 8; do for fr in 1500 4000; do
    ./forzado "$T/cpc64/inicio_juego/ram.bin" "$T/cpc64/inicio_juego/estado.txt" "$T/sincrono/puntos64.txt" \
        --guion "$T/cpc64/exploracion/azar$s.txt" --hasta $fr --limite 50000000 --pruebas 2000 \
        --semilla $((s * 100 + fr)) --max-fallos 5 --cobertura "$O/cob_${s}_$fr.txt" > "$O/forz_${s}_$fr.log" 2>&1 &
done; done
wait
tail -qn1 "$O"/forz_*.log | awk '{a+=$2; b+=$4; c+=$6; d+=$8} END{print "forced: " a " chr_path_find, " b " ai_plan_route, " c " chr_path_build_grid; " d " differences"}'
grep -h DIFF "$O"/forz_*.log | head -20
cat "$O"/cob_*.txt | sort -u > "$O/cobertura.txt"
if [ $# -ge 2 ] && [ "$1" = "--cobertura-dir" ]; then cp "$O/cobertura.txt" "$2/"; fi
! grep -q DIFF "$O"/forz_*.log; st=$?
rm -rf "$O"
exit $st
