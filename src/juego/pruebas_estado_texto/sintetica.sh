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

# Synthetic shadow checks of the estado_texto functions the exploration sessions do not reach (pause,
# monks' faces, owner pointers after a load, arrival, night palette, crafted script expressions, jump
# table ends, hour advance, height lists with kinds 0/6/7, random clips/addresses/characters): from the
# RAM of session 1 at frame 3000.   juego/pruebas_estado_texto/sintetica.sh
set -euo pipefail
P=$(dirname "$(realpath "$0")"); J=$(dirname "$P")
T=${ABADIA64_TRABAJO:-$(dirname "$J")/trabajo}
O=$(mktemp -d)
make -s -C "$J" hibrido
"$J/hibrido" "$T/cpc64/inicio_juego/ram.bin" "$T/cpc64/inicio_juego/estado.txt" "$T/sincrono/puntos64.txt" \
    --guion "$T/cpc64/exploracion/azar1.txt" --hasta 3000 --limite 50000000 --solo nada --ram-final "$O/r3000.bin" 2>/dev/null
gcc -std=c99 -O2 -w -I"$J" -o "$O/sintetica" "$P/sintetica.c" \
    $(ls "$J"/*.c | grep -v hibrido.c) "$J/z80/z80.c"
SINTETICA_RAM="$O/r3000.bin" ABADIA64_TRABAJO="$T" "$O/sintetica"
rm -rf "$O"
