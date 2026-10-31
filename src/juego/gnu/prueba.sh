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

# The GNU parchments (../pergamino.c through ./abadia64ks) against the CPC in the simulator
# (tools/cpc_carga.py, non-synchronous mode: a 50 Hz frame every 6 interrupts of 13312
# T-states), on the tape's images (data/cpc64/cinta/):
#   introduction: primera_etapa.bin from CALL 6000h, space held at frame 4500 for 30 frames (one page turn
#                 at frame ~2735, the exit); compared up to the frame where 6000h returns;
#   ending:       final.bin from 31DAh (CALL 6000h; JR 31DAh), space at frame 1500 for 30 frames (the exit
#                 and the next pass) and at 3000 for 200 frames (a pass after another while it is held).
# At every frame: the screen memory C000h-FFFFh, the mode, the inks the mode shows, R1/R6/R9/R12/R13
# (compara_volcados.py); every AY write by the tick of the interrupt that made it (compara_ay.py); and the
# pictures of some frames, pixel by pixel (compara_fotos.py).  Runs abadia64ks on Xvfb :99 without sound
# devices; the simulator takes about a minute per stage.
#   prueba.sh [OUTDIR]       (RAIZ: the project, by default ../..; HERR: the comparison tools)
set -euo pipefail
G=$(dirname "$(realpath "$0")")
RAIZ=${RAIZ:-$(dirname "$(dirname "$G")")}
T=$RAIZ/../data
HERR=${HERR:-$RAIZ/../tools/gnu_comparacion}
O=${1:-$T/pruebas/salida_pergamino_gnu}
DSK=$RAIZ/../data/original/archive.org/amstrad_abadia_del_crimen_64.dsk     # cpc_carga.py wants a disk; --imagen is what runs
PY=$T/.venv/bin/python
mkdir -p "$O"
make -s -C "$G" TRABAJO="$T"
export DISPLAY=:99 SDL_AUDIODRIVER=dummy XDG_RUNTIME_DIR=/tmp
fallos=0

etapa() {   # name, image, call, frames, frames of the pictures, key script lines...
    local n=$1 img=$2 call=$3 frames=$4 fotos=$5; shift 5
    printf "%s\n" "$@" > "$O/guion_$n.txt"
    rm -rf "$O/ref_$n" "$O/fotos_$n"; mkdir -p "$O/fotos_$n"
    "$PY" "$HERR/referencia.py" "$O/ref_$n.bin" --png "$fotos" "$DSK" --imagen "$T/cpc64/cinta/$img" --call "$call" --int --sin-puertos \
        --guion "$O/guion_$n.txt" --fotos "1-$frames" --marca 613F --marca 6146 --marca 604B \
        --ay "$O/ref_${n}_ay.txt" --max $((frames * 17000 + 1000000)) --out "$O/ref_$n" > /dev/null
    "$G/abadia64ks" --etapa "$( [ "$n" = final ] && echo final || echo intro )" --rapido --guion-perg "$O/guion_$n.txt" \
        --volcado "$O/gnu_$n.bin" --ay "$O/gnu_${n}_ay.txt" --wav "$O/gnu_$n.wav" --fotos "$fotos" --dir "$O/fotos_$n" \
        --hasta-perg "$frames"
    # the introduction: up to the frame where 6000h returns (then the simulator runs on into nothing)
    local hasta=$frames
    if [ "$n" = intro ]; then
        hasta=$(awk '$1 == "M" && $2 == "604B" { sub("T=", "", $3); print int($3 / 79872); exit }' "$O/ref_$n/traza.log")
    fi
    echo "$n: frames 1-$hasta"
    python3 "$HERR/compara_volcados.py" "$O/ref_$n.bin" "$O/gnu_$n.bin" 1 "$hasta" || fallos=1
    python3 "$HERR/compara_ay.py" "$O/ref_$n/traza.log" "$O/ref_${n}_ay.txt" "$O/gnu_${n}_ay.txt" || fallos=1
    for f in ${fotos//,/ }; do
        python3 "$HERR/compara_fotos.py" "$O/ref_$n/f$(printf %06d "$f").png" "$O/fotos_$n/p$(printf %06d "$f").bmp" || fallos=1
    done
}

etapa intro primera_etapa.bin 6000 4600 30,290,1000,2740,2760,2800,4000,4505 "4500 5:7 30"
etapa final final.bin 31DA 4500 30,300,1200,1515,1540,3010,3100,4400 "1500 5:7 30" "3000 5:7 200"
[ $fallos = 0 ] && echo "the GNU parchments: identical to the CPC" || echo "DIFFERENT"
exit $fallos
