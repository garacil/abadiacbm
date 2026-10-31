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

# The checks of the integrated 6502 build (c64/TRADUCCION6502.md, "Check"): juego/hibrido with every translated
# routine in shadow (--6502 this directory --solo-6502), or with --juego the whole 6502 game from its entry in
# step with the Z80, its memory compared at every frame (--juego6502: juego6502.tsv says what is left out).
#   comprueba.sh [--juego] [--largos] [OUTDIR]
#     default: the 8 sessions data/cpc64/exploracion/azarN.txt to frame 4472; --largos: the 16 long scripts
#     data/guiones_largos/largo1NN.txt to frame 20472.  OUTDIR (default: a temporary directory): out_<script>.txt
#     (the host's output), ciclos_<script>.tsv (the 6502 cycles per routine).
# Prints the host's summary per run and the differences per routine; exits 1 if any.
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
largos=0; out=""; modo=(--6502 "$D" --solo-6502); resumen='6502 routines'
for a in "$@"; do
    case "$a" in
        --largos) largos=1 ;;
        --juego) modo=(--juego6502 "$D"); resumen='6502 game' ;;
        *) out="$a" ;;
    esac
done
if [ "$largos" = 1 ]; then guiones=("$P"/../data/guiones_largos/largo1*.txt); hasta=20472
else guiones=("$P"/../data/cpc64/exploracion/azar[1-8].txt); hasta=4472; fi
[ -n "$out" ] || out=$(mktemp -d)
mkdir -p "$out"
cd "$P/juego"
for g in "${guiones[@]}"; do
    n=$(basename "$g" .txt)
    SOMBRA6502_CICLOS="$out/ciclos_$n.tsv" ./hibrido ../../data/cpc64/inicio_juego/ram.bin \
        ../../data/cpc64/inicio_juego/estado.txt ../../data/sincrono/puntos64.txt --guion "$g" --hasta "$hasta" \
        --limite 50000000 "${modo[@]}" > "$out/out_$n.txt" 2>&1 &
done
wait
mal=0
for g in "${guiones[@]}"; do
    n=$(basename "$g" .txt)
    l=$(grep "$resumen" "$out/out_$n.txt" | tail -1 || true)
    [ -n "$l" ] || l="FAILED: $(tail -1 "$out/out_$n.txt")"
    echo "$n: ${l##*; }"
    case "$l" in *" 0 differences"*|*" 0 with differences"*) ;; *) mal=1 ;; esac
done
grep -h '^6502 DIFF' "$out"/out_*.txt | awk '{print $3}' | sort | uniq -c | sort -rn || true
grep -h '^6502 GAME' "$out"/out_*.txt | head -5 | cut -c1-300 || true
echo "output: $out"
exit $mal
