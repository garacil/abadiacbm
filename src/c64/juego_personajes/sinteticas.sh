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

# The synthetic checks of the group personajes (sinteticas.c): the 6502 paths the sessions never reach, each case
# entered from a state of session 1 and compared with the Z80 original by the hybrid host's shadow check.
#   sinteticas.sh [DIR_6502]   (default: this directory, built by construye.sh first)
# Prints the host's summary line and the group's Z80 code the cases ran that the sessions never reach (the ranges
# comprueba.sh lists); exits 1 on a difference.
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
dir=$(realpath "${1:-$D}")
[ -n "${1:-}" ] || "$D/construye.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
J=$P/juego
gcc -std=c99 -O2 -w -I"$J" -o "$T/sinteticas" "$D/sinteticas.c" $(ls "$J"/*.c | grep -v '/hibrido.c$') \
    "$J/z80/z80.c" "$J/m6502/m6502.c" "$J/m6502/6502.c" "$J/m6502/sombra6502.c"
cd "$J"
r=0
"$T/sinteticas" "$(realpath "$dir")" "$T/cobertura.txt" || r=1
python3 -I - "$T/cobertura.txt" <<'PY'
import sys
c = {int(x, 16) for x in open(sys.argv[1]).read().split()}
rangos = ["223D-2262", "226F-22D3", "23E4-241E", "254F-2552", "26EE-2701", "27E3-27E7", "283D-284C", "2890",
          "2DA8-2DE7", "2E08-2E2B", "2F00-2F0E", "2F20-2F2E"]
for r in rangos:
    a, b = (r.split("-") + [r])[:2]
    a, b = int(a, 16), int(b, 16)
    print("%s: %s" % (r, "run" if any(a <= x <= b for x in c) else "NOT run"))
PY
exit $r
