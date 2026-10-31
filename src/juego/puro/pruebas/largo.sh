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

# Long checks: the pure C program against the pure Z80 run of the hybrid on the scripts of
# data/guiones_largos (guion_largo.py, 20000 frames each), frame by frame.
#   largo.sh [FRAMES_TO] [SEEDS...]
set -uo pipefail
A=$(dirname "$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")")   # the project
J=$A/juego
T=$A/../data
HASTA=${1:-20472}; shift || true
SEMILLAS=${*:-$(seq 101 116)}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
make -s -C "$J" hibrido || exit 2
make -s -C "$J/puro" || exit 2
for s in $SEMILLAS; do
    ( "$J/hibrido" $T/cpc64/inicio_juego/ram.bin $T/cpc64/inicio_juego/estado.txt $T/sincrono/puntos64.txt \
        --guion $T/guiones_largos/largo$s.txt --hasta $HASTA --limite 50000000 --solo nada --hashes $W/z_$s.tsv \
        --hash-pila 0xAD --registra-r $W/r_$s.txt > $W/zlog_$s 2>&1
      "$J/puro/puro" $T/cpc64/inicio_juego/ram.bin $T/cpc64/inicio_juego/estado.txt \
        --guion $T/guiones_largos/largo$s.txt --hasta $HASTA --hashes $W/p_$s.tsv --r $W/r_$s.txt > $W/plog_$s 2>&1 ) &
done
wait
mal=0
for s in $SEMILLAS; do
    nr=$(wc -l < $W/r_$s.txt)
    if cmp -s $W/p_$s.tsv $W/z_$s.tsv; then echo "largo $s: identical, $(wc -l < $W/p_$s.tsv) frames; LD A,R: $nr; Z80: $(tail -1 $W/zlog_$s | cut -c1-60)"
    else mal=1; echo "largo $s: DIFFERENT from frame $(diff $W/p_$s.tsv $W/z_$s.tsv | grep '^[<>]' | head -1 | cut -f1) (pure: $(tail -1 $W/plog_$s); Z80: $(tail -1 $W/zlog_$s | cut -c1-80))"; fi
done
exit $mal
