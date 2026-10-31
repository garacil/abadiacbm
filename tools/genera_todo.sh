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

# The three releases in one go (a deterministic tool that makes the tape automatically, compiling
# everything too; both versions, tape and disk; the 128 KiB disk, milestone H10):
#   1. the C64 tape: src/c64/cinta/abadia64ks.tap (src/c64/cinta/construye.sh);
#   2. the C64 disk: src/c64/disco64/abadia64ks.d64 (src/c64/disco64/construye.sh);
#   3. the C128 disk: src/c64/disco128/abadia128ks.d64 (src/c64/disco128/construye.sh);
#   with --prueba, each in VICE on Xvfb (DISPLAY_PRUEBAS, :99 by default): Spanish with everything on, English with
#   everything off, and the ending at 100 % from the disks.
#
#   genera_todo.sh [--prueba]      Exit status 0 only when every step passed; the three sha256 printed at the end.
set -euo pipefail
H=$(dirname "$(realpath "$0")"); P=$(dirname "$H")
C=$P/src/c64/cinta
echo "== 1. the C64 tape"
"$C/construye.sh" > /tmp/genera_todo_cinta.txt || { tail -20 /tmp/genera_todo_cinta.txt; exit 1; }
echo "== 2. the C64 disk"
"$P/src/c64/disco64/construye.sh" > /tmp/genera_todo_disco64.txt || { tail -20 /tmp/genera_todo_disco64.txt; exit 1; }
echo "== 3. the C128 disk"
"$P/src/c64/disco128/construye.sh" > /tmp/genera_todo_disco128.txt || { tail -20 /tmp/genera_todo_disco128.txt; exit 1; }
if [ "${1:-}" = --prueba ]; then
    O=$(mktemp -d /tmp/abadia_prueba_todo.XXXXXX)
    echo "== the tests in VICE (results in $O)"
    export DISPLAY=${DISPLAY_PRUEBAS:-:99}
    python3 -I "$C/prueba_cinta.py" "$O/cinta_es"
    python3 -I "$C/prueba_cinta.py" "$O/cinta_en" --opciones 123
    python3 -I "$C/prueba_cinta.py" "$O/disco64_es" --disco
    python3 -I "$C/prueba_cinta.py" "$O/disco64_en" --disco --opciones 123
    python3 -I "$C/prueba_cinta.py" "$O/disco64_final" --disco --final
    python3 -I "$P/src/c64/disco128/prueba128.py" "$O/disco128_es"
    python3 -I "$P/src/c64/disco128/prueba128.py" "$O/disco128_en" --opciones 1234
    python3 -I "$P/src/c64/disco128/prueba128.py" "$O/disco128_final" --final --opciones 1
fi
for f in src/c64/cinta/abadia64ks.tap src/c64/disco64/abadia64ks.d64 src/c64/disco128/abadia128ks.d64; do
    echo "== $f $(sha256sum "$P/$f" | cut -c1-12)"
done
