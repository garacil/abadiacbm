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

# prueba.sh's shadow check of the 8 sessions, in parallel.  sombra.sh [JUEGO_DIR] [extra hibrido args]
set -uo pipefail
A=$(dirname "$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")")   # the project
J=${1:-$A/juego}; shift || true
T=$A/../data
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
make -s -C "$J" hibrido 2>&1 | grep -v unused | head -30
[ -x "$J/hibrido" ] || exit 2
for s in 1 2 3 4 5 6 7 8; do
    "$J/hibrido" $T/cpc64/inicio_juego/ram.bin $T/cpc64/inicio_juego/estado.txt $T/sincrono/puntos64.txt \
        --guion $T/cpc64/exploracion/azar$s.txt --hasta 4472 --limite 50000000 "$@" > $W/log_$s 2>&1 &
done
wait
mal=0
for s in 1 2 3 4 5 6 7 8; do
    echo "sesion $s: $(tail -1 $W/log_$s)"
    if ! tail -1 $W/log_$s | grep -q " 0 differences"; then mal=1; grep -v "^frames to" $W/log_$s | head -20; fi
done
exit $mal
