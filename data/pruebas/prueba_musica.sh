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

# The C translation of the CPC parchment's music player against the CPC itself: the CPC's register
# writes (the Z80 simulator, each write given the index of the 300 Hz interrupt it happens in) and
# musica.c's writes, tick by tick, must be identical.
#   prueba_musica.sh [inicial|final] [MAX_INSTRUCTIONS]
# The ending is run with space pressed at 50 Hz frame 1500 for 50 frames (the text writer polls it once a character): the CPC leaves the parchment
# (64F1h stops the music) and enters it again (61BAh restarts channel A) until space is released, then
# writes it once more; the C players get musica_para / musica_reinicia after the same ticks.
# inicial: the introduction, the original cassette's first stage (data/cpc64/cinta/primera_etapa.bin,
# CALL 6000h as the tape's loader does); final: the ending, the cassette's 2Ah block
# (data/cpc64/cinta/final.bin, run from 31DAh: the game's CALL 6000h / JR back, for ever).  Both use the same player
# code (interrupt 613Fh, tick 61DBh).
set -euo pipefail
T=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$T")")
ETAPA=${1:-inicial}; MAX=${2:-40000000}
O=$T/salida_musica_$ETAPA; mkdir -p "$O"
cd "$P/data"
DSK=../original/archive.org/amstrad_abadia_del_crimen_64.dsk
case $ETAPA in
    inicial) .venv/bin/python tools/terceros/cpc_carga.py $DSK --imagen cpc64/cinta/primera_etapa.bin --call 6000 --sp C000 \
                 --int --sin-puertos --max "$MAX" --marca 61DB --ay "$O/cpc_ay.txt" --out "$O/cpc" > /dev/null
             IMAGEN=cpc64/cinta/primera_etapa.bin ;;
    final)   echo "1500 5:7 50" > "$O/guion.txt"
             .venv/bin/python tools/terceros/cpc_carga.py $DSK --imagen cpc64/cinta/final.bin --call 31DA --sp C000 \
                 --int --sin-puertos --max "$MAX" --marca 61DB --marca 64F1 --marca 61BA --guion "$O/guion.txt" \
                 --ay "$O/cpc_ay.txt" --out "$O/cpc" > /dev/null
             IMAGEN=cpc64/cinta/final.bin ;;
    *) echo "stage: inicial or final" >&2; exit 2 ;;
esac
python3 -I "$P/tools/c64_pergamino_datos.py" "$IMAGEN" "$O/datos.c" > /dev/null
python3 -I - "$O" <<'PY'
import sys, bisect
o = sys.argv[1]
traza = [l.split() for l in open(o + "/cpc/traza.log") if l.startswith("M ")]
marks = [int(t[2][2:]) for t in traza if t[1] == "61DB"]
with open(o + "/cpc_ticks.txt", "w") as f:
    for l in open(o + "/cpc_ay.txt"):
        t, r, v = map(int, l.split())
        f.write(f"{bisect.bisect_right(marks, t) - 1} {r} {v}\n")
# stops (64F1h) and later entries (61BAh, the first one is musica_inicia's) after which tick
ev = [("p" if t[1] == "64F1" else "r") + str(bisect.bisect_right(marks, int(t[2][2:])) - 1)
      for t in traza if t[1] in ("64F1", "61BA")][1:]
open(o + "/eventos.txt", "w").write(" ".join(ev))
print("CPC interrupts:", len(marks), "stops/entries:", len(ev))
PY
gcc -O1 -I "$P/src/c64/pergamino" -o "$O/prueba_musica" "$T/prueba_musica.c" "$P/src/c64/pergamino/musica.c" "$O/datos.c"
# whole ticks only: the CPC run stops at its instruction limit inside its last tick
n=$(tail -1 "$O/cpc_ticks.txt" | cut -d' ' -f1)
awk -v n="$n" '$1 < n' "$O/cpc_ticks.txt" > "$O/cpc_ticks_enteros.txt" && mv "$O/cpc_ticks_enteros.txt" "$O/cpc_ticks.txt"
"$O/prueba_musica" "$n" $(cat "$O/eventos.txt") > "$O/c_ticks.txt"
fallos=0
if cmp -s "$O/cpc_ticks.txt" "$O/c_ticks.txt"; then
    echo "$ETAPA: musica.c (host): identical, $(wc -l < "$O/c_ticks.txt") register writes over $n ticks"
else
    echo "$ETAPA: musica.c (host): DIFFERENT"; diff "$O/cpc_ticks.txt" "$O/c_ticks.txt" | head -20; fallos=1
fi
# the 6502 version, in cc65's simulator
CC65=$P/tools/terceros/cc65/bin
"$CC65/cl65" -t sim6502 -O -I "$P/src/c64/pergamino" -o "$O/prueba_musica_6502" "$T/prueba_musica_6502.c" "$T/registro_6502.s" \
    "$P/src/c64/pergamino/musica.s" "$O/datos.c"
"$CC65/sim65" "$O/prueba_musica_6502" "$n" $(cat "$O/eventos.txt") > "$O/s_ticks.txt"
if cmp -s "$O/cpc_ticks.txt" "$O/s_ticks.txt"; then
    echo "$ETAPA: musica.s (6502, sim65): identical, $(wc -l < "$O/s_ticks.txt") register writes"
else
    echo "$ETAPA: musica.s (6502, sim65): DIFFERENT"; diff "$O/cpc_ticks.txt" "$O/s_ticks.txt" | head -20; fallos=1
fi
exit $fallos
