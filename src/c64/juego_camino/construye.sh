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

# The 6502 game for the hybrid host's checks: juego.bin (the 64 KiB image from $0000: zero page, data, code from
# $0800) and juego.lbl (ld65's VICE label file: the routines' addresses).
#   mapa64.py   bloques64.tsv + data/c64graf/graficos64.tsv -> mapa64.tsv, mapa64.inc (the memory map)
#   punteros64.py (tools)                       -> punteros64.tsv (the pointer fields)
#   datos64.py  the map, the pointers, the tape image, the converted graphics -> datos64.s, juego.cfg,
#               conversion64.tsv
#   stubs64.py  stubs64.s, stubs64.tsv: a trap for each function called but not translated (FINAL=1: none allowed)
# The graphics (data/c64graf) are made by tools/c64_graficos.py; the inventory checks by
# tools/inventario64.py (c64/NOTAS_MAPA.md).
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
B=$P/../tools/terceros/cc65/bin
cd "$D"
python3 -I mapa64.py "$D" > /dev/null
python3 -I "$P/../tools/punteros64.py" "$D" > /dev/null    # into this build's directory
python3 -I datos64.py "$D" > /dev/null
python3 -I stubs64.py "$D" ${FINAL:+--final} > /dev/null     # stubs: functions not translated yet (traps in the host)
objs=()
for s in *.s; do "$B/ca65" -o "${s%.s}.o" "$s"; objs+=("${s%.s}.o"); done
"$B/ld65" -C juego.cfg -o juego.bin -Ln juego.lbl -m juego.map "${objs[@]}"
