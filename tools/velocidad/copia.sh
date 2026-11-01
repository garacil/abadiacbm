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

# A working copy of the 6502 game for my speed instruments, at the same depth as in the project so that every
# relative path works (the game's construye.sh reads ../../tools and ../../data; the hybrid host reads the game's
# ../datos and ../../../data): WORK/src/c64/juego_final and WORK/src/c64/plataforma copied (the files to change),
# the rest of WORK/src/c64, WORK/src/juego, WORK/data and WORK/tools linked to the project's (read only), and the copy built twice with its own construye.sh: the C64's (c64/juego.bin) and the checked build (juego.bin, the
# host's).  The project is left untouched.
#   copia.sh WORK
set -euo pipefail
P=$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)            # the project
W=$(realpath -m "${1:?WORK}")
[ -e "$W" ] && { echo "copia.sh: $W exists" >&2; exit 1; }
mkdir -p "$W/src/c64"
cp -a "$P/src/c64/juego_final" "$P/src/c64/plataforma" "$W/src/c64/"
for d in "$P"/src/c64/*; do case "$(basename "$d")" in juego_final|plataforma) ;; *) ln -s "$d" "$W/src/c64/$(basename "$d")" ;; esac; done
ln -s "$P/src/juego" "$W/src/juego"; ln -s "$P/data" "$W/data"; ln -s "$P/tools" "$W/tools"
cd "$W/src/c64/juego_final"
C64=1 ./construye.sh > /dev/null       # (first: the checked build leaves the generated files as it needs them)
./construye.sh > /dev/null
echo "checked build: $(sha256sum juego.bin | cut -c1-16)  C64 build: $(sha256sum c64/juego.bin | cut -c1-16)"
