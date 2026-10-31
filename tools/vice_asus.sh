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
# VICE on the screen on hal9000asus (the Plasma session, display :1), with a tape, disk or program of the
# project: any VICE already running there is closed first.  The binary monitor listens only on the VPN address (172.29.253.205),
# for src/c64/cinta/remoto.py sessions.  The file is copied to /tmp/abadia_vice there.
#
#   vice_asus.sh FILE [EMULATOR]     FILE relative to the project (e.g. src/c64/cinta/abadia64ks.tap); EMULATOR x64sc
#                                    (default) or x128
set -euo pipefail
H=$(dirname "$(realpath "$0")"); R=$(dirname "$H")
F=$1; EMU=${2:-x64sc}
[ -f "$R/$F" ] || { echo "vice_asus.sh: no $F" >&2; exit 1; }
B=$(basename "$F")
ssh hal9000asus "for p in \$(pgrep -u german -x x64sc) \$(pgrep -u german -x x128); do kill -TERM \$p; done; sleep 1
mkdir -p /tmp/abadia_vice && cp ~/Proyectos/abadiacbm/$F /tmp/abadia_vice/ && sha256sum /tmp/abadia_vice/$B | cut -c1-12
XA=\$(tr '\0' '\n' < /proc/\$(pgrep -u german -x plasmashell | head -1)/environ | sed -n 's/^XAUTHORITY=//p')
cd /tmp/abadia_vice && (DISPLAY=:1 XAUTHORITY=\$XA XDG_RUNTIME_DIR=/run/user/1000 PULSE_SERVER=unix:/run/user/1000/pulse/native \
  setsid nohup $EMU -VICIIdsize -binarymonitor -binarymonitoraddress ip4://172.29.253.205:6510 -autostart /tmp/abadia_vice/$B \
  > /tmp/abadia_vice/vice.log 2>&1 < /dev/null &)
sleep 4; pgrep -a $EMU | cut -c1-100"
