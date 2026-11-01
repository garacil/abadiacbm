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
# The project from this machine to the others named in tools/maquinas.conf (not in the repository: a name, an SSH host,
# and its VPN address a line), at the same place under the home directory, over SSH.  The graphics are edited with
# c64_editor.py on any of them: src/c64/datos/editados64.txt, when this machine's and another's differ, the newer one
# (its modification time) wins; the other is kept in respaldos/<date>/ first.  rsync adds and updates, never deletes.
#
#   sincroniza.sh          Exit status 0 when every machine was updated.
set -euo pipefail
H=$(dirname "$(realpath "$0")"); R=$(dirname "$H")
REL=${R#"$HOME"/}                                       # the project's place under the home directory, the same there
E=src/c64/datos/editados64.txt
[ -f "$H/maquinas.conf" ] || { echo "sincroniza.sh: no tools/maquinas.conf" >&2; exit 1; }
MAQUINAS=$(awk '!/^#/ && NF {print $1}' "$H/maquinas.conf")
for pc in $MAQUINAS; do
    suyo=$(ssh "$pc" "sha256sum ~/$REL/$E 2>/dev/null | cut -c1-64" || true)
    nuestro=$(sha256sum "$R/$E" | cut -c1-64)
    if [ -n "$suyo" ] && [ "$suyo" != "$nuestro" ]; then
        mkdir -p "$R/respaldos/$(date +%F)"
        t_suyo=$(ssh "$pc" "stat -c %Y ~/$REL/$E")
        t_nuestro=$(stat -c %Y "$R/$E")
        if [ "$t_suyo" -gt "$t_nuestro" ]; then
            cp -p "$R/$E" "$R/respaldos/$(date +%F)/editados64_aqui_$(date +%H%M%S).txt"
            scp -qp "$pc:$REL/$E" "$R/$E"
            echo "editados64.txt: $pc's is newer: brought here (ours in respaldos/$(date +%F))"
        else
            scp -qp "$pc:$REL/$E" "$R/respaldos/$(date +%F)/editados64_${pc}_$(date +%H%M%S).txt"
            echo "editados64.txt: ours is newer: sent to $pc (its old one in respaldos/$(date +%F))"
        fi
    fi
done
for pc in $MAQUINAS; do
    rsync -a --exclude=__pycache__ --exclude=src/c64/video/grabaciones/ "$R/" "$pc:$REL/"   # (the videos' recordings: GBs, written while they run)
    echo "$pc: synchronised"
done
