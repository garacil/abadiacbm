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
# abadia128ks for the P500 (the CBM-II 510), its disk in one go (c64/discop500/NOTAS.md): every program built from the
# sources, the game's bank 0 crunched with Exomizer:
#   1. the game for the P500, Spanish and English (c64/juego_final P500=1: p500/, p500_en/);
#   2. its files B, J, E, AVE and juego500_gen.inc (piezas500.py);
#   3. the last stage of its loading at $0200 of bank 1 (etapa500.s + Exomizer's exodecrunch.s): etapa500.bin;
#   4. the start menu, presentation and ending for the P500 (c64/presentacion P500=1: generado_p500/, with carga500.s
#      and the stage inside);
#   5. the disks: an 8050's D80 and a 2031's / 4040's D64, formatted by c1541, the files ABADIA (first: SHIFT +
#      RUN/STOP loads and runs it), B, J, E, AVE, FINAL; each replaced only when complete:
#      c64/discop500/abadia128ks_p500.d80 and .d64 (their sha256 printed; DISCOS=DIR: in DIR instead, for a build
#      while a session has the disks attached).
# The English data (c64/ingles/generado) must exist: c64/ingles/datos.sh (the tape's c64/cinta/construye.sh runs it).
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
B=$P/../tools/terceros/cc65/bin
C=$P/c64/cinta
G=$D/generado
mkdir -p "$G"
[ -f "$P/c64/ingles/generado/ram_en.bin" ] || ( cd "$P/c64/ingles" && ./datos.sh > /dev/null )

echo "== 1. the game (P500, both languages)"
( cd "$P/c64/juego_final" && C64=1 P500=1 ./construye.sh > /dev/null && C64=1 P500=1 IDIOMA=en ./construye.sh > /dev/null )
J=$P/c64/juego_final/p500; JE=$P/c64/juego_final/p500_en

echo "== 2. its files"
python3 -I "$D/piezas500.py" "$J" "$JE" "$G" | tee "$G/piezas.txt"

echo "== 3. the last stage"
"$B/ca65" -g -I "$D" -I "$G" -o "$G/etapa500.o" "$D/etapa500.s"
"$B/ca65" -o "$G/exodecrunch.o" "$C/exodecrunch.s"
"$B/ld65" -C "$D/etapa500.cfg" -o "$G/etapa500.bin" -Ln "$G/etapa500.lbl" -m "$G/etapa500.map" "$G/etapa500.o" "$G/exodecrunch.o"
rm -f "$G"/*.o

echo "== 4. the menu, presentation and ending for the P500"
( cd "$P/c64/presentacion" && P500=1 ./construye.sh | tail -2 )
GP=$P/c64/presentacion/generado_p500

echo "== 5. the disks"
T=$(mktemp -d)
for f in d80 d64; do
    c1541 -format "abadia128ks,ak" $f "$T/abadia128ks_p500.$f" > /dev/null
    c1541 "$T/abadia128ks_p500.$f" -write "$GP/abadia.prg" abadia -write "$G/B.prg" b -write "$G/J.prg" j \
        -write "$G/E.prg" e -write "$G/AVE.prg" ave -write "$GP/final.prg" final > /dev/null
    c1541 "$T/abadia128ks_p500.$f" -list 2>/dev/null | grep -v -e '^Unit' -e OPENCBM
    mv "$T/abadia128ks_p500.$f" "${DISCOS:-$D}/abadia128ks_p500.$f"
    echo "== the disk: ${DISCOS:-$D}/abadia128ks_p500.$f $(sha256sum "${DISCOS:-$D}/abadia128ks_p500.$f" | cut -c1-12)"
done
rmdir "$T"
