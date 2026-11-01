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

# The per-address profile (SOMBRA6502_PERFIL) and the per-frame cycles (--ciclos-frame) of the checked build in
# WORK/src/c64/juego_final/ (the project's hibrido, the project left untouched): sessions azar1, azar5, azar8 to host frame 4472
# and the no-keys script to 2472.  Deterministic (the host is).
#   perfil.sh WORK      (WORK: made by ../copia.sh, its game built by construye_prueba.sh; the outputs go there)
set -u
S=$(realpath "${1:?WORK}"); P=$(cd "$(dirname "$(realpath "$0")")/../../.." && pwd)   # WORK: the working copy; P: the project
H=$(dirname "$(realpath "$0")")
run() {  # name guion hasta
  SOMBRA6502_PERFIL="$S/perfil_$1.tsv" "$P/src/juego/hibrido" "$P/data/cpc64/inicio_juego/ram.bin" "$P/data/cpc64/inicio_juego/estado.txt" \
    "$P/data/sincrono/puntos64.txt" --guion "$2" --hasta "$3" --limite 50000000 --juego6502 "$S/src/c64/juego_final" \
    --ciclos-frame "$S/frames_$1.tsv" > "$S/run_$1.log" 2>&1; echo "exit=$?" >> "$S/run_$1.log"
}
run 1 "$P/data/cpc64/exploracion/azar1.txt" 4472 &
run 5 "$P/data/cpc64/exploracion/azar5.txt" 4472 &
run 8 "$P/data/cpc64/exploracion/azar8.txt" 4472 &
run nokeys "$H/sin_teclas.txt" 2472 &
wait
