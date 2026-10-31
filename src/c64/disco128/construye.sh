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

# abadia128ks, the C128's disk in one go (milestone H10, c64/disco128/NOTAS.md; everything as on the
# tape, but on disk, file by file): every program built from the sources and every file crunched with Exomizer:
#   1. the game for the C128, Spanish and English (c64/juego_final C128=1: c128/, c128_en/);
#   2. its files B, J, E and juego128_gen.inc (piezas128.py);
#   3. the last stage of its loading at $C000 (etapa128.s + Exomizer's exodecrunch.s): etapa128.bin;
#   4. the presentation and ending for the C128 (c64/presentacion C128=1: generado_c128/, with carga128.s and
#      the stage inside);
#   5. the presentation crunched (exomizer mem, loaded where Exomizer says for an in-place decrunch), disco128_gen.inc;
#   6. the menu at $1300 (c64/cinta/menu.s -D C128, exo_mem.s, exodecrunch.s): M;
#   7. the disk: a D64 formatted by c1541, the boot sector (arranque128.py), the files M, ABADIA, B, J, E, FINAL;
#      replaced only when complete: c64/disco128/abadia128ks.d64 (its sha256 printed).
# The English data (c64/ingles/generado) must exist: c64/ingles/datos.sh (the tape's c64/cinta/construye.sh runs it).
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
B=$P/../tools/terceros/cc65/bin
EXO=$P/../tools/terceros/exomizer/exomizer2/src/exomizer
C=$P/c64/cinta
G=$D/generado
mkdir -p "$G"
[ -f "$P/c64/ingles/generado/ram_en.bin" ] || ( cd "$P/c64/ingles" && ./datos.sh > /dev/null )

echo "== 1. the game (C128, both languages)"
( cd "$P/c64/juego_final" && C64=1 C128=1 ./construye.sh > /dev/null && C64=1 C128=1 IDIOMA=en ./construye.sh > /dev/null )
J=$P/c64/juego_final/c128; JE=$P/c64/juego_final/c128_en

echo "== 2. its files"
python3 -I "$D/piezas128.py" "$J" "$JE" "$G" | tee "$G/piezas.txt"

echo "== 3. the last stage"
"$B/ca65" -g -I "$D" -I "$G" -o "$G/etapa128.o" "$D/etapa128.s"
"$B/ca65" -o "$G/exodecrunch.o" "$C/exodecrunch.s"
"$B/ld65" -C "$D/etapa128.cfg" -o "$G/etapa128.bin" -Ln "$G/etapa128.lbl" -m "$G/etapa128.map" "$G/etapa128.o" "$G/exodecrunch.o"

echo "== 4. the presentation and ending for the C128"
( cd "$P/c64/presentacion" && C128=1 ./construye.sh | tail -2 )
G8=$P/c64/presentacion/generado_c128

echo "== 5. the presentation crunched"
"$EXO" mem -q "$G8/abadia.prg" -o "$G/abadia.exo"
python3 -I - "$G" <<'PY'
import sys
g = sys.argv[1]
b = open(f"{g}/abadia.exo", "rb").read()
a = b[0] | b[1] << 8
fin = a + len(b) - 2
assert 0x1B00 <= a and fin <= 0xC000, f"the crunched presentation ${a:04X}-${fin:04X} must lie in $1B00-$BFFF (the menu: $1300-$1AFF)"
open(f"{g}/disco128_gen.inc", "w").write(f"; made by c64/disco128/construye.sh\nPRES_FIN = ${fin:04X}"
                                         f"                    ; the crunched abadia.prg: ${a:04X}-${fin - 1:04X}\n")
PY

echo "== 6. the menu"
"$B/ca65" -g -D C128 -I "$C" -I "$D" -I "$G" -o "$G/menu.o" "$C/menu.s"
"$B/ca65" -o "$G/exo_mem.o" "$C/exo_mem.s"
"$B/ca65" -o "$G/direccion.o" "$D/direccion.s"
"$B/ld65" -C "$D/menu128.cfg" -o "$G/M.prg" -Ln "$G/menu.lbl" -m "$G/menu.map" "$G/direccion.o" "$G/menu.o" \
    "$G/exo_mem.o" "$G/exodecrunch.o"
rm -f "$G"/*.o

echo "== 7. the disk"
T=$(mktemp -d)
c1541 -format "abadia128ks,ak" d64 "$T/abadia128ks.d64" > /dev/null
python3 -I "$D/arranque128.py" "$T/abadia128ks.d64"
c1541 "$T/abadia128ks.d64" -write "$G/M.prg" m -write "$G/abadia.exo" abadia -write "$G/B.prg" b -write "$G/J.prg" j -write "$G/J2.prg" j2 \
    -write "$G/E.prg" e -write "$G/AVE.prg" ave -write "$G8/final.prg" final > /dev/null
c1541 "$T/abadia128ks.d64" -list 2>/dev/null | grep -v -e '^Unit' -e OPENCBM
mv "$T/abadia128ks.d64" "$D/abadia128ks.d64"; rmdir "$T"
echo "== the disk: $D/abadia128ks.d64 $(sha256sum "$D/abadia128ks.d64" | cut -c1-12)"
