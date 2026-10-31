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

# The translated functions against their Z80 originals, in shadow, over the exploration sessions:
# builds ./hibrido and runs every session (data/cpc64/exploracion/azar*.txt, 4000 frames each)
# from the game's start.  Every call of every translated function is checked (all the RAM, SP, PC,
# the declared results).  Prints one line per session; exit status 1 if any call differed.
#   juego/prueba.sh [--solo NAME] [--sesiones "1 2 3"] [--max-fallos N]
set -uo pipefail
J=$(dirname "$(realpath "$0")")
T=${ABADIA64_TRABAJO:-$(dirname "$J")/trabajo}
cd "$J"
if ! make -s hibrido > /tmp/prueba_make_$$.log 2>&1; then
    grep -v "unused" /tmp/prueba_make_$$.log | head -40; rm -f /tmp/prueba_make_$$.log
    echo "BUILD FAILED"; exit 2
fi
rm -f /tmp/prueba_make_$$.log
sesiones="1 2 3 4 5 6 7 8"; extra=()
while [ $# -gt 0 ]; do
    case "$1" in
        --sesiones) sesiones=$2; shift 2 ;;
        *) extra+=("$1"); shift ;;
    esac
done
fallos=0
for s in $sesiones; do
    r=$(./hibrido "$T/cpc64/inicio_juego/ram.bin" "$T/cpc64/inicio_juego/estado.txt" "$T/sincrono/puntos64.txt" \
        --guion "$T/cpc64/exploracion/azar$s.txt" --hasta 4472 --limite 50000000 "${extra[@]}" 2>&1)
    st=$?
    echo "sesion $s: $(echo "$r" | tail -1)"
    if [ $st -ne 0 ]; then fallos=1; echo "$r" | grep -v "^frames to" | head -40; fi
done
exit $fallos
