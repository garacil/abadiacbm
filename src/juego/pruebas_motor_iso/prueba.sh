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

# The extra checks of the group motor_iso (prueba_motor_iso.c): every room built and drawn, the camera in
# every room, synthetic blocks with every opcode, the small functions over their inputs; from the RAM
# of session 1 at frame 2000.  Exit 1 on any difference.
set -uo pipefail
D=$(dirname "$(realpath "$0")"); J=$(dirname "$D")
T=${ABADIA64_TRABAJO:-$(dirname "$(dirname "$J")")/data}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
make -s -C "$J" hibrido || exit 2
"$J/hibrido" "$T/cpc64/inicio_juego/ram.bin" "$T/cpc64/inicio_juego/estado.txt" "$T/sincrono/puntos64.txt" \
    --guion "$T/cpc64/exploracion/azar1.txt" --hasta 2000 --limite 50000000 --solo nada --ram-final "$W/ram_f2000.bin" > /dev/null 2>&1
gcc -std=c99 -O2 -w -I"$J" -o "$W/prueba_motor_iso" "$D/prueba_motor_iso.c" $(ls "$J"/*.c | grep -v hibrido.c) "$J/z80/z80.c" || exit 2
cd "$W" && "$W/prueba_motor_iso" "$W/ram_f2000.bin" "$T/cpc64/inicio_juego/estado.txt"
