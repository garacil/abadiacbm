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

# The PC rebuild as abadia128ks's reference (milestone H10, the full game): a copy of the rebuild's c/ (~/Proyectos/abadia/c, or ABADIA_PC/c)
# (left untouched) in DIR with the two hooks of arnes.c in game_input_and_mirror, built as DIR/abadia.
#   construye.sh DIR
set -euo pipefail
PC=${ABADIA_PC:-$HOME/Proyectos/abadia}/c
AQUI=$(cd "$(dirname "$0")" && pwd)
DIR=$1
rm -rf "$DIR"; mkdir -p "$DIR"
cp -a "$PC/src" "$PC/include" "$PC/Makefile" "$DIR/"
ln -s "$PC/res" "$DIR/res"
cp "$AQUI/arnes.c" "$DIR/src/arnes.c"
python3 -I - "$DIR/src/game.c" <<'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1]); t = p.read_text()
a = """void game_input_and_mirror(uint16_t *di)
{
    ((key_routine_fn)funcion_por_direccion(rw(SYS_KEY_ROUTINE)))(di);"""
b = """void arnes_entrada(void), arnes_teclas(void);     /* (c64/certifica/pc/arnes.c) */
void game_input_and_mirror(uint16_t *di)
{
    arnes_entrada();
    ((key_routine_fn)funcion_por_direccion(rw(SYS_KEY_ROUTINE)))(di);
    arnes_teclas();"""
assert t.count(a) == 1, "game_input_and_mirror changed in the PC rebuild"
p.write_text(t.replace(a, b))
PY
make -C "$DIR" -s abadia > /dev/null
echo "$DIR/abadia"
