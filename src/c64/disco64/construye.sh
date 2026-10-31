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

# abadia64ks, the C64's disk in one go (c64/disco64/NOTAS.md; made as the tape is, but on
# disk for the Commodore 64: the 64ks version on disk too, so that there are both, tape and disk): the
# tape's release on a 1541 disk, every program built from the sources:
#   1. the game for the disk (c64/juego_final DISCO=1: c64disco/, and English c64disco_en/);
#   2. the presentation and ending with both languages inside, the game's loader reading JUEGO and TEXTOS
#      (c64/presentacion DISCO=1: generado_disco64/);
#   3. the game's stream and the English block, checked by the model of the loader (c64/cinta/flujo_cinta.py --disco);
#   4. the presentation and the ending crunched (Exomizer mem, placed for an in-place decrunch): disco64_gen.inc;
#   5. the menu and the ending's stage at $C000 (c64/cinta/menu.s and etapa_final.s, -D DISCO), each inside its KERNAL
#      program (arranque64.s): ABADIA64KS and FINAL;
#   6. the disk: ABADIA64KS, ABADIA, JUEGO, TEXTOS, FINAL, FINALZ; replaced only when complete:
#      c64/disco64/abadia64ks.d64 (its sha256 printed).
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
B=$P/../tools/terceros/cc65/bin
EXO=$P/../tools/terceros/exomizer/exomizer2/src/exomizer
C=$P/c64/cinta
G=$D/generado
mkdir -p "$G"
[ -f "$P/c64/ingles/generado/ram_en.bin" ] || ( cd "$P/c64/ingles" && ./datos.sh > /dev/null )

echo "== 1. the game (both languages)"
( cd "$P/c64/juego_final" && C64=1 DISCO=1 ./construye.sh > /dev/null && C64=1 DISCO=1 IDIOMA=en ./construye.sh > /dev/null )

echo "== 2. the presentation and ending"
( cd "$P/c64/presentacion" && DISCO=1 ./construye.sh | grep "disk (C64)" )
GD=$P/c64/presentacion/generado_disco64

echo "== 3. the game's stream and the English block"
python3 -I "$C/flujo_cinta.py" "$P/c64/juego_final/c64disco" "$P/c64/juego_final/c64disco_en" "$GD/cargador.lbl" "$G" \
    --disco | tee "$G/flujo.txt"

echo "== 4. the presentation and the ending crunched"
for f in abadia final; do "$EXO" mem -q "$GD/$f.prg" -o "$G/$f.exo"; done
python3 -I - "$G" <<'PY'
import sys
g = sys.argv[1]
lineas = []
for f, n in (("abadia", "PRES_FIN"), ("final", "FINAL_FIN")):
    b = open(f"{g}/{f}.exo", "rb").read()
    a = b[0] | b[1] << 8
    fin = a + len(b) - 2
    assert 0x0400 <= a and fin <= 0xC000, f"{f}: the crunched data ${a:04X}-${fin:04X} must stay below the stage at $C000"
    lineas.append(f"{n} = ${fin:04X}                    ; the crunched {f}.prg: ${a:04X}-${fin - 1:04X}")
open(f"{g}/disco64_gen.inc", "w").write("; made by c64/disco64/construye.sh\n" + "\n".join(lineas) + "\n")
PY

echo "== 5. the menu, the ending's stage, their KERNAL programs"
"$B/ca65" -o "$G/exodecrunch.o" "$C/exodecrunch.s"
"$B/ca65" -o "$G/exo_mem.o" "$C/exo_mem.s"
"$B/ca65" -g -D DISCO -I "$C" -I "$G" -o "$G/menu.o" "$C/menu.s"
"$B/ld65" -C "$C/etapa.cfg" -o "$G/menu.bin" -Ln "$G/menu.lbl" "$G/menu.o" "$G/exo_mem.o" "$G/exodecrunch.o"
"$B/ca65" -g -D DISCO -I "$C" -I "$G" -o "$G/etapa_final.o" "$C/etapa_final.s"
"$B/ld65" -C "$C/etapa.cfg" -o "$G/etapa_final.bin" -Ln "$G/etapa_final.lbl" "$G/etapa_final.o" "$G/exo_mem.o" \
    "$G/exodecrunch.o"
"$B/ca65" -I "$C" --bin-include-dir "$G" -o "$G/arranque.o" "$D/arranque64.s"
"$B/ld65" -C "$D/arranque64.cfg" -o "$G/abadia64ks.prg" "$G/arranque.o"
"$B/ca65" -D FINAL -I "$C" --bin-include-dir "$G" -o "$G/arranque_final.o" "$D/arranque64.s"
"$B/ld65" -C "$D/arranque64.cfg" -o "$G/final.prg" "$G/arranque_final.o"
rm -f "$G"/*.o

echo "== 6. the disk"
T=$(mktemp -d)
c1541 -format "abadia64ks,ak" d64 "$T/abadia64ks.d64" > /dev/null 2>&1
c1541 "$T/abadia64ks.d64" -write "$G/abadia64ks.prg" abadia64ks -write "$G/abadia.exo" abadia \
    -write "$G/juego.bin" juego -write "$G/textos_en.bin" textos -write "$G/final.prg" final \
    -write "$G/final.exo" finalz > /dev/null 2>&1
c1541 "$T/abadia64ks.d64" -list 2>/dev/null | grep -v -e '^Unit' -e OPENCBM -e 'XDG_RUNTIME'
mv "$T/abadia64ks.d64" "$D/abadia64ks.d64"; rmdir "$T"
echo "== the disk: $D/abadia64ks.d64 $(sha256sum "$D/abadia64ks.d64" | cut -c1-12)"
