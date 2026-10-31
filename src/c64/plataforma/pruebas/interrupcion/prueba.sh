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

# abadia64ks, the 300 Hz interrupt work (c64/optimizacion/interrupcion): its two checks beyond the host's.
#   [PSG=psg.s] prueba.sh [DIR]   DIR: a build directory with both images (default c64/juego_final: construye.sh
#                       and C64=1 construye.sh both run there first); PSG: the plat_psg to check (default
#                       c64/plataforma/psg.s)
# 1. ticks.c: the C64 build's sys_tick (and everything it calls, the real plat_psg) against the checked build's,
#    from the same states, every phrase of the game with the game's sounds: the same memory, AY writes, registers.
# 2. psg.c: c64/plataforma/psg.s against psg_antes.s (before the work): the same SID writes for every period of
#    every channel, random writes, and the AY writes of the 8 sessions (the GNU build's --ay logs, made here on
#    Xvfb :99 when juego/gnu/abadia64ks-puro exists); A, X, the I flag kept; leftovers in the BSS harmless.
set -euo pipefail
A=$(dirname "$(realpath "$0")"); P=$(realpath "$A/../../../.."); B=$P/../tools/terceros/cc65/bin
D=$(realpath "${1:-$P/c64/juego_final}")
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -I "$P/juego/m6502" -o "$T/ticks" "$A/ticks.c" "$P/juego/m6502/m6502.c" "$P/juego/m6502/6502.c"
"$T/ticks" "$D" 56
mkdir "$T/core"
cp "$P/juego/m6502/"{6502.c,6502.h,m6502.c,m6502.h,peripherals.h,paravirt.h,trace.h,error.h} "$T/core/"
cp "$A/memory.h" "$T/core/"
gcc -O2 -I "$T/core" -o "$T/psg" "$A/psg.c" "$T/core/m6502.c" "$T/core/6502.c"
for s in nuevo:"${PSG:-$P/c64/plataforma/psg.s}" antes:"$A/psg_antes.s"; do
    "$B/ca65" -I "$P/c64/plataforma" -o "$T/${s%%:*}.o" "${s#*:}"
    "$B/ld65" -C "$A/psg.cfg" -o "$T/${s%%:*}.bin" -Ln "$T/${s%%:*}.lbl" "$T/${s%%:*}.o"
done
logs=()
if [ -x "$P/juego/gnu/abadia64ks-puro" ]; then
    mkdir -m 700 "$T/xdg"
    for n in 1 2 3 4 5 6 7 8; do
        (cd "$P/juego" && DISPLAY=:99 SDL_AUDIODRIVER=dummy XDG_RUNTIME_DIR="$T/xdg" ./gnu/abadia64ks-puro --etapa juego --rapido \
            --sin-sonido --guion ../../data/cpc64/exploracion/azar$n.txt --hasta 4472 --ay "$T/azar$n.txt" > /dev/null 2>&1) &
    done
    wait
    for n in 1 2 3 4 5 6 7 8; do [ -s "$T/azar$n.txt" ] && logs+=("$T/azar$n.txt"); done
fi
"$T/psg" "$T/nuevo.bin" "$T/nuevo.lbl" "$T/antes.bin" "$T/antes.lbl" exhaustivo azar "${logs[@]}"
