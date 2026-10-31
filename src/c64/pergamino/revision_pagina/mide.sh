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

# The page turn step by step on the C64: builds the first stage (or with -f the ending, -DFINAL) as c64/presentacion/pruebas/disco_prueba/construye.sh
# does, with pagina.s's probes (--asm-define MIDE=1), into a temporary directory, and runs c64_pasos.py on it (VICE on
# Xvfb :99): the first page turn.
#   mide.sh [-f] [-2] [OUT.tsv]   (-2: MIDE=2, the corner drawn with the interrupt held off: its own cycles)
set -euo pipefail
D=$(dirname "$(realpath "$0")"); PERG=$(dirname "$D"); P=$(dirname "$(dirname "$PERG")")
B=$P/../tools/terceros/cc65/bin
F=0; M=1
while [ $# -gt 0 ]; do
    case $1 in -f) F=1; shift ;; -2) M=2; shift ;; *) break ;; esac
done
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
cp "$PERG"/*.c "$PERG"/*.s "$PERG"/*.h "$PERG"/*.inc "$PERG"/cargador.bin "$T/"
DESTINO=$(awk '$3 == ".inicio" { print "$" substr($2, 3) }' "$PERG/cargador.lbl")
if [ $F = 1 ]; then
    (cd "$T" && "$B/cl65" -t c64 -O -Cl -DFINAL --asm-define MIDE=$M -o pergamino.prg -Ln pergamino.lbl main.c espera.s \
        pixel.s musica.s sid.s datos_final.c)
else
    (cd "$T" && "$B/cl65" -t c64 -O -Cl --asm-define MIDE=$M --asm-define "DESTINO=$DESTINO" --bin-include-dir . \
        -o pergamino.prg -Ln pergamino.lbl main.c espera.s pixel.s musica.s sid.s carga.s datos.c carga.c)
fi
python3 -I "$D/c64_pasos.py" "$T/pergamino.prg" "$T/pergamino.lbl" "$@"
