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

# The C64 tape in one go (a deterministic tool that makes the tape automatically: everything compiled,
# then the tape made, all in one run):
#   1. everything built and the tape made: src/c64/cinta/construye.sh (the English data, the game's four images, the
#      programs for the tape, Exomizer, the stages, the game's blocks checked by the model of the tape's loader,
#      src/c64/cinta/abadia64ks.tap);
#   2. with --prueba, the tape in VICE (src/c64/cinta/prueba_cinta.py, Xvfb :99): Spanish with everything on, English
#      with the footsteps and the text's sound off; the game's memory checked against its image each time.
#
#   genera_cinta.sh [--prueba]      Exit status 0 only when every step passed.  Deterministic: the same sources
#                                   give the same tape (its sha256 printed at the end).
set -euo pipefail
H=$(dirname "$(realpath "$0")"); P=$(dirname "$H")
C=$P/src/c64/cinta
echo "== 1. building everything and the tape"
"$C/construye.sh"
if [ "${1:-}" = --prueba ]; then
    O=$(mktemp -d /tmp/abadia_cinta_prueba.XXXXXX)
    echo "== 2. the tape in VICE (results in $O)"
    DISPLAY=${DISPLAY_PRUEBAS:-:99} python3 -I "$C/prueba_cinta.py" "$O/es"
    DISPLAY=${DISPLAY_PRUEBAS:-:99} python3 -I "$C/prueba_cinta.py" "$O/en" --opciones 123
fi
echo "== the tape: $C/abadia64ks.tap $(sha256sum "$C/abadia64ks.tap" | cut -c1-12)"
