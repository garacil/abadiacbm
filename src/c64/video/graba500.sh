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

# The real-time recording of a whole game of abadia128ks on the P500 (the CBM-II 510) by the pilot (sesion500.py: the abbot followed
# with the keys, ABADIA_SEGUIR_TECLAS=1), on its own virtual X display.  Run as german.
#   graba500.sh es|en DISPLAY PORT   (e.g. es :93 6513, en :92 6512; never :99, the tests' display)
# Out: grabaciones/p500_<lang>_<stamp>.mkv, its session directory grabacion500_<lang>_<stamp>/ (marcas.json for
# monta.py), and the log with a Unix timestamp on every line.
set -u
D=$(dirname "$(readlink -f "$0")")
cd "$D" || exit 1
L=$1; DSP=$2; PORT=$3
export XDG_RUNTIME_DIR=/run/user/1000
if ! DISPLAY=$DSP xdotool getdisplaygeometry >/dev/null 2>&1; then
    setsid nohup Xvfb "$DSP" -screen 0 1280x1024x24 -nolisten tcp >/dev/null 2>&1 &
    sleep 3
fi
STAMP=$(date +%Y%m%d_%H%M%S)
ABADIA_SEGUIR_TECLAS=1 ABADIA_TRAZA_OBS=1 ABADIA_DISPLAY=$DSP ABADIA_PUERTO=$PORT python3 -u sesion500.py --idioma "$L" --salida "$D/grabaciones/grabacion500_${L}_$STAMP" \
    --video "$D/grabaciones/p500_${L}_$STAMP.mkv" 2>&1 \
  | python3 -u -c 'import sys, time
for l in sys.stdin: print("%.2f %s" % (time.time(), l), end="", flush=True)' > "$D/grabaciones/log500_${L}_$STAMP.txt"
echo "$STAMP finished with code ${PIPESTATUS[0]}" >> "$D/grabaciones/log500_${L}_$STAMP.txt"
