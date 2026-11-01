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

# The call traces (SOMBRA6502_TRAZA, the scratch host hibrido_src/hibrido) of two routine sets on the four runs:
# set A = the path search and its callers, set B = the height buffer fills, the doors, the inventory and the sprite
# composition.  Addresses from juego_final/juego_todo.lbl (the -g link of the checked build).  Deterministic.
#   traza.sh WORK      (WORK: made by ../copia.sh, its game built by construye_prueba.sh, hibrido_src/ patched by parche_traza.py; the outputs go there)
set -u
S=$(realpath "${1:?WORK}"); P=$(cd "$(dirname "$(realpath "$0")")/../../.." && pwd)   # WORK: the working copy; P: the project
H=$(dirname "$(realpath "$0")")
addr() { grep -E " \.$1\$" "$S/src/c64/juego_final/juego_todo.lbl" | head -1 | awk '{print substr($2,3)}'; }
A=""; for r in la_busca! la_sala chr_path_room_to_marked* chr_path_room_search* chr_path_floor_to_screen* chr_path_floor_search* chr_path_find! chr_path_clear_grid_marks! chr_path_clear_room_marks! chr_path_via_rooms chr_path_search_to_dest camino_plan_route camino_drive iso_grid_cell_of chr_path_add_target_beside chr_path_restore_screen_grid; do
  n=${r%%[*!]*}; f=${r#"$n"}; A="$A$(addr "$n")$f,"; done
B=""; for r in chr_fill_height_buffer! hb_draw! hb_span chr_hbuf_fill_list! hb_list obj_update_doors! obj_update_inventory! obj_set_door_permissions spr_draw_all la_capas la_tramo la_baldosa spr_blit_to_screen chr_probe_cells sys_key_down sys_test_key; do
  n=${r%%[*!]*}; f=${r#"$n"}; B="$B$(addr "$n")$f,"; done
echo "A=$A"; echo "B=$B"
run() {  # set name guion hasta
  SOMBRA6502_TRAZA="$S/traza${1}_$2.tsv:${!1}" "$S/hibrido_src/hibrido" "$P/data/cpc64/inicio_juego/ram.bin" "$P/data/cpc64/inicio_juego/estado.txt" \
    "$P/data/sincrono/puntos64.txt" --guion "$3" --hasta "$4" --limite 50000000 --juego6502 "$S/src/c64/juego_final" \
    --ciclos-frame "$S/frames${1}_$2.tsv" > "$S/run${1}_$2.log" 2>&1; echo "exit=$?" >> "$S/run${1}_$2.log"
}
for X in A B; do
  run $X 1 "$P/data/cpc64/exploracion/azar1.txt" 4472 &
  run $X 5 "$P/data/cpc64/exploracion/azar5.txt" 4472 &
  run $X 8 "$P/data/cpc64/exploracion/azar8.txt" 4472 &
  run $X nokeys "$H/sin_teclas.txt" 2472 &
done
wait
for X in A B; do for n in 1 5 8 nokeys; do echo "== $X $n"; tail -2 "$S/run${X}_$n.log"; done; done
