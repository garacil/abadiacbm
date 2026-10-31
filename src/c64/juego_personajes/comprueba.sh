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

# The checks of the group personajes (c64/TRADUCCION6502.md, "Check"): the exploration sessions with the 6502
# routines in shadow (juego/hibrido --6502 --solo-6502), in two builds:
#   normal  this directory as construye.sh builds it;
#   npc     the same with game_run_npc_behaviours left untranslated (not exported), so that the NPC drivers
#           (group camino) run as Z80 code in the main loop and each of their calls into this group (chr_update,
#           chr_probe_ahead(_flat), chr_mark_hbuf, chr_to_hbuf_coords, chr_fill_height_buffer, chr_apply_step,
#           sys_key_down...) is checked by itself: in the normal build they run inside the drivers' traps.
# The npc build is made in a temporary tree of symbolic links to the project (the variant's directory at the same
# depth as this one), removed at the end.
#
#   comprueba.sh [--largos] [--hasta N] [OUTDIR]
#     default: the 8 sessions data/cpc64/exploracion/azarN.txt to frame 4472;
#     --largos: the 16 long scripts data/guiones_largos/largo1NN.txt to frame 20472;
#     OUTDIR (default: a temporary directory, printed): out_<build>_<script>.txt (the host's output) and
#     ciclos_<build>_<script>.tsv (the 6502 cycles per routine, SOMBRA6502_CICLOS), cobertura_<build>_<script>.txt
#     (the Z80 instructions run, --cobertura).
# Prints one line per run (the host's summary), the total of differences (exits 1 if any) and the group's Z80
# code the npc runs never reached (paths of the 6502 code the sessions do not verify); then runs sinteticas.sh,
# the synthetic cases that reach those paths.
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
largos=0; hasta=""; out=""
while [ $# -gt 0 ]; do
    case "$1" in
        --largos) largos=1 ;;
        --hasta) hasta="$2"; shift ;;
        *) out="$1" ;;
    esac
    shift
done
if [ "$largos" = 1 ]; then
    guiones=("$P"/../data/guiones_largos/largo1*.txt); hasta=${hasta:-20472}
else
    guiones=("$P"/../data/cpc64/exploracion/azar[1-8].txt); hasta=${hasta:-4472}
fi
[ -n "$out" ] || out=$(mktemp -d)
mkdir -p "$out"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# the builds: normal (here) and npc (a copy in $T/p/c64/v, $T/p a tree of links to the project)
"$D/construye.sh"
mkdir -p "$T/p/c64/v"
for x in "$P"/*; do [ "$(basename "$x")" = c64 ] || ln -s "$x" "$T/p/"; done
for x in "$P"/c64/*; do [ "$x" = "$D" ] || ln -s "$x" "$T/p/c64/"; done
for x in "$D"/*; do case "$x" in *.s|*.tsv|*.py|*.inc|*.cfg|*.sh) cp "$x" "$T/p/c64/v/" ;; esac; done
sed -i -E 's/^(\s*\.export\s+)game_run_npc_behaviours, /\1/' "$T/p/c64/v/personajes.s"
sed -i -E '/^game_run_npc_behaviours(\s|$)/d' "$T/p/c64/v/resultados.tsv"
grep -q "export.*game_run_npc_behaviours" "$T/p/c64/v/personajes.s" && { echo "npc: the export is still there" >&2; exit 2; }
"$T/p/c64/v/construye.sh"

cd "$P/juego"
pids=()
for b in normal npc; do
    dir=$D; [ "$b" = npc ] && dir=$T/p/c64/v
    for g in "${guiones[@]}"; do
        n=$(basename "$g" .txt)
        SOMBRA6502_CICLOS="$out/ciclos_${b}_$n.tsv" ./hibrido ../../data/cpc64/inicio_juego/ram.bin \
            ../../data/cpc64/inicio_juego/estado.txt ../../data/sincrono/puntos64.txt --guion "$g" --hasta "$hasta" \
            --limite 50000000 --6502 "$dir" --solo-6502 --cobertura "$out/cobertura_${b}_$n.txt" \
            > "$out/out_${b}_$n.txt" 2>&1 &
        pids+=($!)
    done
done
fallo=0
for p in "${pids[@]}"; do wait "$p" || fallo=1; done
total=0
for b in normal npc; do
    for g in "${guiones[@]}"; do
        n=$(basename "$g" .txt)
        l=$(grep "6502 routines" "$out/out_${b}_$n.txt" | tail -1 || true)
        echo "$b $n: ${l:-NO SUMMARY}"
        d=$(echo "$l" | sed -nE 's/.*6502 routines: [0-9]+ calls, ([0-9]+) differences.*/\1/p')
        [ -n "$d" ] || { fallo=1; d=0; }
        total=$((total + d))
    done
done
echo "differences: $total (outputs in $out)"
# the group's Z80 code never run in the checks of the npc build (its 6502 paths are not verified): the instruction
# lines of the group's listings (data/cpc64/listado, 2226-2F57) outside its data, as address ranges
python3 -I - "$P/../data/cpc64/listado" "$out" <<'PY'
import glob, os, re, sys
lst, out = sys.argv[1], sys.argv[2]
datos = [(0x23A2, 0x23E1), (0x2703, 0x274A), (0x28B9, 0x2D4F), (0x2DE8, 0x2DFB), (0x2E2C, 0x2E41),
         (0x2EB3, 0x2EBA), (0x2EDE, 0x2EE6)]
codigo = set()
for f in glob.glob(os.path.join(lst, "*.asm")):
    if not 0x2226 <= int(os.path.basename(f)[:4], 16) <= 0x2F57: continue
    for l in open(f):
        m = re.match(r"([0-9A-F]{4}) [ *] ", l)
        if m:
            a = int(m.group(1), 16)
            if not any(x <= a <= y for x, y in datos): codigo.add(a)
cubierto = set()
for f in glob.glob(os.path.join(out, "cobertura_npc_*.txt")):
    cubierto.update(int(x, 16) for x in open(f).read().split())
falta = sorted(codigo - cubierto)
rangos, i = [], 0
while i < len(falta):
    j = i
    while j + 1 < len(falta) and falta[j + 1] - falta[j] <= 4: j += 1
    rangos.append("%04X-%04X" % (falta[i], falta[j]) if j > i else "%04X" % falta[i]); i = j + 1
print("Z80 code of the group never run in the npc checks: " + (" ".join(rangos) if rangos else "none"))
PY
# the paths the sessions never reach: the synthetic cases (sinteticas.sh, on the normal build)
"$D/sinteticas.sh" "$D" || fallo=1
[ "$total" = 0 ] && [ "$fallo" = 0 ]
