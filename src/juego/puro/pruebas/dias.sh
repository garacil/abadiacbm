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

# The pure C program against the pure Z80 run starting each day 1-7 at each hour 0-6 (the start state
# with [BF4F] = day, [BF4E] = hour: ai_clock_init reads them at a new game), a long random script each.
#   dias.sh [FRAMES_TO]
set -uo pipefail
A=$(dirname "$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")")   # the project
J=$A/juego
T=$A/../data
HASTA=${1:-6472}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
make -s -C "$J" hibrido || exit 2
make -s -C "$J/puro" || exit 2
k=0
for d in 1 2 3 4 5 6 7; do for h in 0 1 2 3 4 5 6; do
    g=$T/guiones_largos/largo$((101 + k % 16)).txt; k=$((k + 1))
    ( "$J/hibrido" $T/puro/estados/ram_d${d}h$h.bin $T/cpc64/inicio_juego/estado.txt $T/sincrono/puntos64.txt \
        --guion $g --hasta $HASTA --limite 50000000 --solo nada --hashes $W/z_$d$h.tsv \
        --hash-pila 0xAD --registra-r $W/r_$d$h.txt > $W/zlog_$d$h 2>&1
      "$J/puro/puro" $T/puro/estados/ram_d${d}h$h.bin $T/cpc64/inicio_juego/estado.txt \
        --guion $g --hasta $HASTA --hashes $W/p_$d$h.tsv --r $W/r_$d$h.txt > $W/plog_$d$h 2>&1 ) &
done; done
wait
mal=0
for d in 1 2 3 4 5 6 7; do for h in 0 1 2 3 4 5 6; do
    if cmp -s $W/p_$d$h.tsv $W/z_$d$h.tsv; then echo "day $d hour $h: identical, $(wc -l < $W/p_$d$h.tsv) frames; LD A,R: $(wc -l < $W/r_$d$h.txt); $(tail -1 $W/plog_$d$h)"
    else mal=1; echo "day $d hour $h: DIFFERENT from frame $(diff $W/p_$d$h.tsv $W/z_$d$h.tsv | grep '^[<>]' | head -1 | cut -f1) (pure: $(tail -1 $W/plog_$d$h); Z80: $(tail -1 $W/zlog_$d$h | cut -c1-80))"; fi
done; done
exit $mal
