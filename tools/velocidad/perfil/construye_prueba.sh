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

# Build the checked (PRUEBA) 6502 image of a working copy (WORK, made by ../copia.sh: WORK/src/c64/juego_final) with
# the project's cc65, the project left untouched: chk/ (ca65 -D PRUEBA, the image hibrido runs), lst/ (listings),
# perfil_g/ (ca65 -g, the same image, with ld65's --dbgfile juego.dbg and the VICE label file juego_todo.lbl).
# Deterministic.
#   construye_prueba.sh WORK
set -euo pipefail
D=$(realpath "${1:?WORK}")/src/c64/juego_final
P=$(cd "$(dirname "$(realpath "$0")")/../../.." && pwd)            # the project
B=$P/tools/terceros/cc65/bin
cd "$D"
rm -rf chk lst perfil_g; mkdir -p chk lst perfil_g
objs=(); pobjs=()
for s in *.s; do
    "$B/ca65" -D PRUEBA -l "lst/${s%.s}.lst" -o "chk/${s%.s}.o" "$s"; objs+=("chk/${s%.s}.o")
    "$B/ca65" -g -D PRUEBA -o "perfil_g/${s%.s}.o" "$s"; pobjs+=("perfil_g/${s%.s}.o")
done
"$B/ld65" -C juego.cfg -o chk/juego.bin -Ln chk/juego.lbl -m chk/juego.map "${objs[@]}"
"$B/ld65" -C juego.cfg -o perfil_g/juego.bin -Ln perfil_g/juego_todo.lbl -m perfil_g/juego.map --dbgfile perfil_g/juego.dbg "${pobjs[@]}"
cmp chk/juego.bin perfil_g/juego.bin && echo "chk and perfil_g images identical"
# the game directory hibrido reads: chk's image and label file beside the copy's tables
cp chk/juego.bin juego.bin; cp chk/juego.lbl juego.lbl; cp perfil_g/juego_todo.lbl juego_todo.lbl
sha256sum chk/juego.bin
grep -E "^(CODE|RODATA|DATA|BSS) " chk/juego.map | head -5
