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

# The key-3 manoeuvre (guion_llave3.txt, made by hace_guion.py on the original) run on the original and on
# the builds, from the unchanged start state data/puro/estados/ram_d2h4.bin (a new game, day 2, nona):
#   1. the original: the Z80 code alone (hybrid host, --solo nada) through ./traza: trace and pictures;
#   2. the C64 game (src/c64/juego_final, 6502) frame by frame against the Z80 (hibrido --juego6502);
#   3. the pure C game (src/juego/puro/puro): its per-frame RAM hashes against the Z80's;
#   4. the GNU build in pure C (a private copy of src/juego/gnu/abadia64ks-puro, built here): pictures at the
#      same frames on Xvfb :99, compared pixel for pixel with the original's;
#   5. the variant guion_llave3_33.txt (variante.py 33) on the original, the C64 game and the pure C game.
# Exit 0 when every check agrees with the original.  (Caprice32: caprice/caprice_llave3.py.)
#   prueba.sh [FRAMES_TO]
set -uo pipefail
L=$(dirname "$(realpath "$0")")
P=$(dirname "$(dirname "$L")")
J=$P/src/juego
T=$P/data
G=$L/guion_llave3.txt
E=$T/puro/estados/ram_d2h4.bin
HASTA=${1:-1400}
FOTOS=$(grep -v '^#' "$L/fotos.txt" | tr '\n' ',' | sed 's/,$//')
O=$L/resultados
mkdir -p "$O/fotos"
make -s -C "$J" hibrido || exit 2
make -s -C "$J/puro" || exit 2
make -s -C "$L" traza || exit 2
fallo=0

echo "1. the original (Z80 code alone)"
"$L/traza" "$O/traza_original.tsv" --fotos "$FOTOS" "$O/fotos" "$E" "$T/cpc64/inicio_juego/estado.txt" \
    "$T/sincrono/puntos64.txt" --guion "$G" --hasta "$HASTA" --limite 50000000 --solo nada \
    --hashes "$O/hashes_z80.tsv" --hash-pila 0xAD --registra-r "$O/r.txt" 2>&1 | tail -1
python3 "$L/resumen.py" "$O/traza_original.tsv" | tee "$O/resumen_original.txt"

echo "2. the C64 game (src/c64/juego_final), 6502, frame by frame against the Z80"
( cd "$J" && ./hibrido "$E" "$T/cpc64/inicio_juego/estado.txt" "$T/sincrono/puntos64.txt" --guion "$G" \
    --hasta "$HASTA" --limite 50000000 --solo nada --juego6502 ../c64/juego_final ) > "$O/c64.txt" 2>&1
r=$?
tail -1 "$O/c64.txt"
[ $r = 0 ] || { echo "   C64: DIFFERENCES (see $O/c64.txt)"; fallo=1; }

echo "3. the pure C game (src/juego/puro/puro)"
"$J/puro/puro" "$E" "$T/cpc64/inicio_juego/estado.txt" --guion "$G" --hasta "$HASTA" \
    --hashes "$O/hashes_puro.tsv" --r "$O/r.txt" 2>&1 | tail -1
if cmp -s "$O/hashes_z80.tsv" "$O/hashes_puro.tsv"; then
    echo "   pure C: the RAM identical to the original's at all $(wc -l < "$O/hashes_puro.tsv") frames"
else
    echo "   pure C: DIFFERENT from frame $(diff "$O/hashes_z80.tsv" "$O/hashes_puro.tsv" | grep '^[<>]' | head -1 | cut -f1)"
    fallo=1
fi

echo "4. the GNU build (pure C), pictures on Xvfb :99"
if [ ! -x "$L/abadia64ks-puro" ] || [ -n "$(find "$J" -maxdepth 2 -name '*.[ch]' -newer "$L/abadia64ks-puro" | head -1)" ]; then
    ( cd "$J/gnu" && cc -std=c99 -O2 -Wall -Wno-unused-function -I.. $(pkg-config --cflags sdl2) -DPURO -DJUEGO_PURO \
        -DTRABAJO="\"$T\"" -o "$L/abadia64ks-puro" abadia64ks.c ../f_*.c ../funciones.c ../pergamino.c ../musica.c \
        ../puro/puro_host.c $(pkg-config --libs sdl2) -lm ) || exit 2
fi
for f in ${FOTOS//,/ }; do
    n=$(printf %06d "$f")
    DISPLAY=:99 "$L/abadia64ks-puro" --etapa juego --ram "$E" --guion "$G" --hasta "$f" --captura "$O/fotos/g$n.bmp" \
        --rapido --sin-sonido > /dev/null 2>&1
    magick "$O/fotos/z$n.ppm" "$O/fotos/z$n.png" && rm -f "$O/fotos/z$n.ppm"
    magick "$O/fotos/g$n.bmp" -alpha off "$O/fotos/g$n.png" && rm -f "$O/fotos/g$n.bmp"
    d=$(magick compare -metric AE "$O/fotos/z$n.png" "$O/fotos/g$n.png" null: 2>&1 | cut -d' ' -f1)
    echo "   frame $f: GNU picture vs original: $d pixels differ"
    [ "$d" = 0 ] || fallo=1
done
echo "5. the variant guion_llave3_33.txt (Guillermo at 33,3E, Malachi stays at 39,37): the original, C64, pure C"
G2=$L/guion_llave3_33.txt
"$L/traza" "$O/traza_33.tsv" "$E" "$T/cpc64/inicio_juego/estado.txt" "$T/sincrono/puntos64.txt" --guion "$G2" \
    --hasta 1250 --limite 50000000 --solo nada --hashes "$O/hashes_z80_33.tsv" --hash-pila 0xAD \
    --registra-r "$O/r_33.txt" > /dev/null 2>&1
python3 "$L/resumen.py" "$O/traza_33.tsv" | tail -1
( cd "$J" && ./hibrido "$E" "$T/cpc64/inicio_juego/estado.txt" "$T/sincrono/puntos64.txt" --guion "$G2" \
    --hasta 1250 --limite 50000000 --solo nada --juego6502 ../c64/juego_final ) > "$O/c64_33.txt" 2>&1 || fallo=1
tail -1 "$O/c64_33.txt"
"$J/puro/puro" "$E" "$T/cpc64/inicio_juego/estado.txt" --guion "$G2" --hasta 1250 --hashes "$O/hashes_puro_33.tsv" \
    --r "$O/r_33.txt" > /dev/null 2>&1
if cmp -s "$O/hashes_z80_33.tsv" "$O/hashes_puro_33.tsv"; then
    echo "   pure C: the RAM identical to the original's at all $(wc -l < "$O/hashes_puro_33.tsv") frames"
else
    echo "   pure C: DIFFERENT"; fallo=1
fi
exit $fallo
