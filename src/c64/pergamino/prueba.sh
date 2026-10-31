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

# The C64 parchments: built with the rest of the disk by c64/presentacion/pruebas/disco_prueba/construye.sh (the first stage pergamino.prg =
# "abadia": introduction parchment, loading screen, the game's loader cargador.s; the ending final.prg = "final", built
# with -DFINAL; the disk c64/disco/abadia64ks.d64), then VICE (x64sc) on Xvfb :99 for each cycle count given
# (default a few), one screenshot each: captura_<cycles>.png.  The disk is attached as drive 8 (the loader reads
# "juego" from it after the parchment).
#   PRG=final.prg                          runs the ending instead of the first stage
#   AUTOSTART="-autostart ../disco/abadia64ks.d64"   boots from the disk instead of injecting the PRG
#   CFLAGS=-DSALTA_TRAS=n / -DCONGELA_TRAS=n         test builds (as if space after n characters / stop there)
# Deterministic: the same build and cycles give the same images.  The whole disk's test: c64/presentacion/pruebas/disco_prueba/prueba.py.
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
cd "$D"
"$P/c64/presentacion/pruebas/disco_prueba/construye.sh" > /dev/null
PRG=${PRG:-pergamino.prg}
for cyc in "${@:-30000000}"; do
    V=$(mktemp -d); mkdir -p "$V/.local/state/vice" "$V/xdg"; chmod 700 "$V/xdg"
    DISPLAY=:99 XDG_RUNTIME_DIR=$V/xdg HOME=$V timeout 600 x64sc -default -sounddev dummy -warp -8 "$P/c64/disco/abadia64ks.d64" \
        ${AUTOSTART:--autostart $PRG -autostartprgmode 1} -limitcycles "$cyc" -exitscreenshot "$D/captura_$cyc.png" > vice.log 2>&1 || true
    rm -rf "$V"
    ls "$D/captura_$cyc.png"
done
