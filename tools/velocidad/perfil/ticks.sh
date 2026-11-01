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

# The tick path traced (set C: sys_tick and what it calls, the sound, the keyboard, plat_psg/plat_ei/plat_di),
# SOMBRA6502_PERFIL set so that the host steps the ticks instruction by instruction (the profile is discarded:
# it equals perfil_*.tsv).  Deterministic.
#   ticks.sh WORK      (WORK: made by ../copia.sh, its game built by construye_prueba.sh, hibrido_src/ patched by parche_traza.py; the outputs go there)
set -u
S=$(realpath "${1:?WORK}"); P=$(cd "$(dirname "$(realpath "$0")")/../../.." && pwd)   # WORK: the working copy; P: the project
H=$(dirname "$(realpath "$0")")
addr() { grep -E " \.$1\$" "$S/src/c64/juego_final/juego_todo.lbl" | head -1 | awk '{print substr($2,3)}'; }
C=""; for r in sys_tick* s_interrupcion s_salida_activo s_envolventes s_tono_siguiente plat_psg sys_read_keyboard t_frase plat_ei plat_di obj_update_doors sys_key_down sys_test_key sys_key_bit; do
  n=${r%%[*!]*}; f=${r#"$n"}; C="$C$(addr "$n")$f,"; done
echo "C=$C"
run() {  # name guion hasta
  SOMBRA6502_PERFIL="$S/perfilC_$1.tsv" SOMBRA6502_TRAZA="$S/trazaC_$1.tsv:$C" "$S/hibrido_src/hibrido" "$P/data/cpc64/inicio_juego/ram.bin" "$P/data/cpc64/inicio_juego/estado.txt" \
    "$P/data/sincrono/puntos64.txt" --guion "$2" --hasta "$3" --limite 50000000 --juego6502 "$S/src/c64/juego_final" \
    --ciclos-frame "$S/framesC_$1.tsv" > "$S/runC_$1.log" 2>&1; echo "exit=$?" >> "$S/runC_$1.log"
}
run 1 "$P/data/cpc64/exploracion/azar1.txt" 4472 &
run 8 "$P/data/cpc64/exploracion/azar8.txt" 4472 &
run nokeys "$H/sin_teclas.txt" 2472 &
wait
for n in 1 8 nokeys; do echo "== C $n"; tail -2 "$S/runC_$n.log"; done
