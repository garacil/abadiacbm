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

# The paths of the personajes functions the 8 exploration sessions never take (dark rooms and the lamp,
# Guillermo's fall, the stairs frames of chr_project, every command of the streams, the other floors'
# height buffers, the mirror's Q+R on every step and numeral, the flips of Malachi and Berengar, every
# key, chr_project directly in normal and test mode): from the RAM of session 5 at frames 1500 and 3000
# with synthetic changes, each case checked as the host does (the C wrapper against the Z80 original).
#   pruebas_personajes/caminos.sh        (ABADIA64_TRABAJO: the data directory, data/)
set -uo pipefail
D=$(dirname "$(realpath "$0")"); J=$(dirname "$D")
T=${ABADIA64_TRABAJO:-$(dirname "$(dirname "$J")")/data}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
make -s -C "$J" hibrido || exit 2
gcc -std=c99 -O2 -Wall -Wno-unused-function -I"$J" -o "$W/prueba_caminos" "$D/prueba_caminos.c" \
    $(ls "$J"/*.c | grep -v hibrido.c) "$J/z80/z80.c" || exit 2
fallo=0
for fr in 1500 3000; do
    "$J/hibrido" "$T/cpc64/inicio_juego/ram.bin" "$T/cpc64/inicio_juego/estado.txt" "$T/sincrono/puntos64.txt" \
        --guion "$T/cpc64/exploracion/azar5.txt" --hasta $fr --limite 50000000 --ram-final "$W/ram_$fr.bin" --solo ninguna > /dev/null 2>&1
    "$W/prueba_caminos" "$T/cpc64/inicio_juego/estado.txt" "$W/ram_$fr.bin" > "$W/caminos_$fr.txt" 2>&1 || fallo=1
    echo "frame $fr: $(tail -1 "$W/caminos_$fr.txt")"
    grep "DIFF\|does not" "$W/caminos_$fr.txt" | head -20
done
exit $fallo
