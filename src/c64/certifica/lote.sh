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

# The certification of the C64 build in VICE (vice_cert.py) over sessions, N at a time: lote.sh BUILD OUT N SESSION...
B=$1; O=$2; N=$3; shift 3
D=$(dirname "$(realpath "$0")"); R=$(dirname "$(dirname "$D")")
mkdir -p $O; : > $O/resumen.txt
for s in "$@"; do
  while [ $(jobs -r | wc -l) -ge $N ]; do sleep 5; done
  ( cd "$D" && DISPLAY=:99 timeout 14400 python3 -I certifica.py $B $O $s $R/../data/cpc64/inicio_juego/ram.bin $R/../data/cpc64/exploracion/$s.txt 4001 > /dev/null 2>&1
    echo "$s: $(tail -1 $O/$s.host.txt | cut -c1-200)" >> $O/resumen.txt ) &
done
wait
echo FIN >> $O/resumen.txt
