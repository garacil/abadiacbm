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

# The 100 % ending: from the start state of day 7, tercia (Guillermo dies at once) with the investigation
# solved ([37F4] := 0), the Z80 run reaches the tape loader of the ending (31CF -> 32AB, where it waits
# for a tape signal: stopped by --limite) and the pure C program reaches plat_cinta_carga / plat_final.
# Their frames and their RAM there (the stack apart) must be the same.
set -uo pipefail
A=$(dirname "$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")")   # the project
J=$A/juego
T=$A/../data
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
make -s -C "$J" hibrido || exit 2
make -s -C "$J/puro" || exit 2
python3 - "$T/puro/estados/ram_d7h2.bin" "$W/ram.bin" <<'PY'
import sys
d = bytearray(open(sys.argv[1], 'rb').read()); d[0x37F4] = 0; open(sys.argv[2], 'wb').write(d)
PY
"$J/hibrido" $W/ram.bin $T/cpc64/inicio_juego/estado.txt $T/sincrono/puntos64.txt --guion $T/guiones_largos/largo101.txt \
    --hasta 3000 --limite 5000000 --solo nada --hashes $W/z.tsv --hash-pila 0xAD --ram-final $W/z.bin > $W/zlog 2>&1
"$J/puro/puro" $W/ram.bin $T/cpc64/inicio_juego/estado.txt --guion $T/guiones_largos/largo101.txt --hasta 3000 \
    --hashes $W/p.tsv --ram-final $W/p.bin > $W/plog 2>&1
echo "Z80: $(grep STUCK $W/zlog | cut -c1-60)"
echo "pure C: $(tail -1 $W/plog)"
n=$(cmp -l $W/z.bin $W/p.bin | awk '{a = $1 - 1; if (a < 0xBF00 || a >= 0xC000) print}' | wc -l)
if cmp -s $W/z.tsv $W/p.tsv && [ "$n" -eq 0 ]; then echo "ending: identical ($(wc -l < $W/p.tsv) frames, the RAM at the tape load)"; exit 0; fi
echo "ending: DIFFERENT ($n RAM bytes)"; exit 1
