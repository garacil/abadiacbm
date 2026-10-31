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

# The GNU front-end on the hybrid (gnu/abadia64ks) and on the pure C host (gnu/abadia64ks-puro), both on
# Xvfb :99 with no sound device, emulated time (--rapido): session 1 for 3000 frames, and the 100 % ending
# forced at frame 600 up to parchment frame 500.  The window captures, the AY write logs and the sounds
# must be the same.
set -uo pipefail
A=$(dirname "$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")")   # the project
J=${1:-$A/juego}
T=$A/../data
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
make -s -C "$J/gnu" abadia64ks abadia64ks-puro || exit 2
corre() {   # NAME OPTIONS...
    local n=$1; shift
    for b in abadia64ks abadia64ks-puro; do
        XDG_RUNTIME_DIR=/tmp DISPLAY=:99 SDL_AUDIODRIVER=dummy "$J/gnu/$b" --trabajo $T --rapido --etapa juego \
            --guion $T/cpc64/exploracion/azar1.txt "$@" --captura $W/$n.$b.bmp --ay $W/$n.$b.ay --wav $W/$n.$b.wav > $W/$n.$b.log 2>&1 &
    done
    wait
    for x in bmp ay wav; do
        if cmp -s $W/$n.abadia64ks.$x $W/$n.abadia64ks-puro.$x; then echo "$n: $x identical ($(stat -c %s $W/$n.abadia64ks.$x) bytes)"
        else echo "$n: $x DIFFERENT"; mal=1; fi
    done
}
mal=0
corre juego --hasta 3000
corre final --salta-final 600 --hasta-perg 500
exit $mal
