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

# Unit checks of the group logica_a from synthetic states (see unidad.c): builds unidad and runs it on
# RAM snapshots of the sessions (made here with hibrido --ram-final at frames 700, 2000 and 4472 of the
# sessions 1, 5 and 8).   pruebas_logica_a/prueba_unidad.sh [-n ITERATIONS] [-s SEED]
set -uo pipefail
U=$(dirname "$(realpath "$0")")
J=$(dirname "$U")
T=${ABADIA64_TRABAJO:-$(dirname "$(dirname "$J")")/data}
cd "$J"
if ! make -s hibrido > /dev/null 2>&1 || ! gcc -std=c99 -O2 -Wall -Wextra -o "$U/unidad" "$U/unidad.c" $(ls *.c | grep -v hibrido.c) z80/z80.c; then
    echo "BUILD FAILED"; exit 2
fi
D=$(mktemp -d)
for s in 1 5 8; do for f in 700 2000 4472; do
  ./hibrido "$T/cpc64/inicio_juego/ram.bin" "$T/cpc64/inicio_juego/estado.txt" "$T/sincrono/puntos64.txt" \
    --guion "$T/cpc64/exploracion/azar$s.txt" --hasta $f --limite 50000000 --ram-final "$D/s${s}_$f.bin" 2>/dev/null &
done; done
wait
"$U/unidad" "$D"/*.bin "$@"
st=$?
rm -rf "$D"
exit $st
