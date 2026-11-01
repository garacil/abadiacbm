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
# VICE on the desktop of another machine named in tools/maquinas.conf (not in the repository: a name, an SSH host, and
# its VPN address a line), over SSH.  The file (a disk or tape of the synchronised project, path relative to it) copied
# to /tmp/abadia_vice there first (the games saved on it never touch the project's), the user's emulators there
# stopped, the new one on the Plasma session (DISPLAY and XAUTHORITY taken from plasmashell's environment), its binary
# monitor on that machine's VPN address only.  A disk is attached to drive 8 and the machine started (the C128 boots its
# boot sector; the C64 is autostarted; the P500, xcbm5x0 with 128 KiB and an 8050 for a .d80 or a 2031 for a .d64, has
# no autostart: DLOAD"ABADIA" and RUN are typed for it through the binary monitor, tools/teclea_p500.py).
#   vice_remoto.sh MACHINE FILE [x64sc|x128|xcbm5x0]
set -euo pipefail
H=$(dirname "$(realpath "$0")"); R=$(dirname "$H")
REL=${R#"$HOME"/}                                       # the project's place under the home directory, the same there
PC=$1; F=$2; EMU=${3:-x64sc}
IP=$(awk -v n="$PC" '!/^#/ && $1 == n {print $2}' "$H/maquinas.conf" 2>/dev/null)
[ -n "$IP" ] || { echo "vice_remoto.sh: $PC is not in tools/maquinas.conf" >&2; exit 1; }
[ -f "$R/$F" ] || { echo "vice_remoto.sh: no $F" >&2; exit 1; }
B=$(basename "$F")
if [ "$EMU" = x128 ]; then OPC="-hidevdcwindow -40col -VICIIdsize -8 /tmp/abadia_vice/$B"
elif [ "$EMU" = xcbm5x0 ]; then U=8050; [ "${B##*.}" = d64 ] && U=2031
    OPC="-model 510 -ramsize 128 -pal -VICIIdsize -drive8type $U -drive8truedrive -8 /tmp/abadia_vice/$B"
else OPC="-VICIIdsize -autostart /tmp/abadia_vice/$B"; fi
ssh "$PC" "U=\$(id -un); for p in \$(pgrep -u \$U -x x64sc) \$(pgrep -u \$U -x x128) \$(pgrep -u \$U -x xcbm5x0); do kill -TERM \$p; done; sleep 1
mkdir -p /tmp/abadia_vice && cp ~/$REL/$F /tmp/abadia_vice/ && sha256sum /tmp/abadia_vice/$B | cut -c1-12
PS=\$(pgrep -u \$U -x plasmashell | head -1)
DSP=\$(tr '\0' '\n' < /proc/\$PS/environ | sed -n 's/^DISPLAY=//p')
XA=\$(tr '\0' '\n' < /proc/\$PS/environ | sed -n 's/^XAUTHORITY=//p')
cd /tmp/abadia_vice && (DISPLAY=\$DSP XAUTHORITY=\$XA XDG_RUNTIME_DIR=/run/user/\$(id -u) PULSE_SERVER=unix:/run/user/\$(id -u)/pulse/native \\
  setsid nohup $EMU $OPC -binarymonitor -binarymonitoraddress ip4://$IP:6510 > /tmp/abadia_vice/vice.log 2>&1 < /dev/null &)
sleep 4; pgrep -a $EMU | cut -c1-140"
if [ "$EMU" = xcbm5x0 ]; then
    python3 -I "$H/teclea_p500.py" "$IP" 6510 'DLOAD"ABADIA"' 'RUN'
fi
