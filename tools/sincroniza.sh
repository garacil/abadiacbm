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
# The project from hal9000 to the other two PCs (synchronised from here on, to both once everything is
# ready): hal9000c 172.29.253.204 and hal9000asus
# 172.29.253.205, the same directory, user german, over the VPN.  The graphics are edited with c64_editor.py on
# hal9000asus or here: src/c64/datos/editados64.txt, when the two differ, the newer one (its modification time) wins; the
# other is kept in respaldos/<date>/ first.  rsync adds and updates, never deletes.
#
#   sincroniza.sh          Exit status 0 when both PCs were updated.
set -euo pipefail
H=$(dirname "$(realpath "$0")"); R=$(dirname "$H")
E=src/c64/datos/editados64.txt
suyo=$(ssh hal9000asus "sha256sum ~/Proyectos/abadiacbm/$E 2>/dev/null | cut -c1-64" || true)
nuestro=$(sha256sum "$R/$E" | cut -c1-64)
if [ -n "$suyo" ] && [ "$suyo" != "$nuestro" ]; then
    mkdir -p "$R/respaldos/$(date +%F)"
    t_suyo=$(ssh hal9000asus "stat -c %Y ~/Proyectos/abadiacbm/$E")
    t_nuestro=$(stat -c %Y "$R/$E")
    if [ "$t_suyo" -gt "$t_nuestro" ]; then
        cp -p "$R/$E" "$R/respaldos/$(date +%F)/editados64_aqui_$(date +%H%M%S).txt"
        scp -qp "hal9000asus:Proyectos/abadiacbm/$E" "$R/$E"
        echo "editados64.txt: hal9000asus's is newer: brought here (ours in respaldos/$(date +%F))"
    else
        scp -qp "hal9000asus:Proyectos/abadiacbm/$E" "$R/respaldos/$(date +%F)/editados64_asus_$(date +%H%M%S).txt"
        echo "editados64.txt: ours is newer: sent to hal9000asus (its old one in respaldos/$(date +%F))"
    fi
fi
for pc in hal9000c hal9000asus; do
    rsync -a --exclude=__pycache__ --exclude=src/c64/video/grabaciones/ "$R/" "$pc:Proyectos/abadiacbm/"   # (the videos' recordings: GBs, written while they run)
    echo "$pc: synchronised"
done
