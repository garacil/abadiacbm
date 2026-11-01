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

# The 6502 game of a working copy (WORK, made by ../copia.sh) assembled again the way its own construye.sh built it,
# with the listings and the debug information my jump analysis (saltos6502.py) and the static cycle analyzer
# (../analizador/ciclos6502.py) read, into OUT/:
#   OUT/c64/      the C64 build (construye.sh with C64=1: the same sources and options, -D JUEGO, the generated
#                 datos64.s and juego.cfg), ca65 -g -l (listings in OUT/c64/lst), ld65 with --dbgfile (line ->
#                 address), -m (map), -Ln (labels)
#   OUT/prueba/   the checked build (-D PRUEBA, every *.s: the addresses of the host's dynamic profile), the same way
# ca65 -g changes no byte: both images are checked against the copy's own (c64/juego.bin, juego.bin).
#   construye.sh WORK OUT     (deterministic)
set -euo pipefail
W=$(realpath "${1:?WORK}"); OUT=$(realpath -m "${2:?OUT}")
P=$(cd "$(dirname "$(realpath "$0")")/../../.." && pwd)            # the project
B=$P/tools/terceros/cc65/bin
J=$W/src/c64/juego_final
cd "$J"
# the C64 build: construye.sh's C64=1 list of sources and options
mkdir -p "$OUT/c64/lst"; objs=(); fuentes=()
for s in *.s; do case "$s" in plataforma_prueba.s|plat_aleatorio_prueba.s|stubs64.s|datos64.s) ;; *) fuentes+=("$s") ;; esac; done
fuentes+=("$J/datos64.s")
for s in tinta teclado psg interrupcion disco; do fuentes+=("../plataforma/$s.s"); done
for s in "${fuentes[@]}"; do
    n=$(basename "${s%.s}")
    "$B/ca65" -g -D JUEGO -I "$J" -I "$J/../plataforma" -I "$J" -l "$OUT/c64/lst/$n.lst" -o "$OUT/c64/$n.o" "$s"; objs+=("$OUT/c64/$n.o")
done
"$B/ld65" -C "$J/juego.cfg" -o "$OUT/c64/juego.bin" -Ln "$OUT/c64/juego.lbl" -m "$OUT/c64/juego.map" --dbgfile "$OUT/c64/juego.dbg" "${objs[@]}"
cmp "$OUT/c64/juego.bin" c64/juego.bin
# the checked build
mkdir -p "$OUT/prueba/lst"; objs=()
for s in *.s; do
    n=${s%.s}
    "$B/ca65" -g -D PRUEBA -l "$OUT/prueba/lst/$n.lst" -o "$OUT/prueba/$n.o" "$s"; objs+=("$OUT/prueba/$n.o")
done
"$B/ld65" -C juego.cfg -o "$OUT/prueba/juego.bin" -Ln "$OUT/prueba/juego.lbl" -m "$OUT/prueba/juego.map" --dbgfile "$OUT/prueba/juego.dbg" "${objs[@]}"
cmp "$OUT/prueba/juego.bin" juego.bin
echo "c64: $(sha256sum "$OUT/c64/juego.bin" | cut -c1-16)  prueba: $(sha256sum "$OUT/prueba/juego.bin" | cut -c1-16)  (both the copy's own images)"
