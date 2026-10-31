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

# abadia64ks.tap, the C64 tape (c64/cinta/NOTAS.md): both languages on one tape, chosen in the start menu.  In
# this order:
#   "ABADIA64KS"  the KERNAL's file: the turbo core and the menu's loader (arranque.s)
#   ID_MENU       the menu (menu.s, with Exomizer's decruncher)
#   ID_PRES       the presentation with both languages' picture, parchment and texts (Exomizer)
#   ID_JUEGO, ID_JUEGO2   the game (Spanish; literal, read as it comes: c64/presentacion/cargador.s -D CINTA)
#   ID_TEXTOS_EN  the English game's different bytes (read only in English)
#   "FINAL"       the KERNAL's file the game loads at 100 % (the tape stopped there): the ending's loader
#   ID_ETAPA_FIN  the ending's stage;  ID_FINAL  the ending with both languages' text (Exomizer)
# Builds everything first: the English data (c64/ingles/datos.sh), the game's tape images (c64/juego_final:
# C64=1 CINTA=1, and IDIOMA=en), the programs for the tape (c64/presentacion: CINTA=1); the ordinary
# builds are made again last (the disk's C64 image and the checked one), so the directory stays as before.
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
B=$P/../tools/terceros/cc65/bin
EXO=$P/../tools/terceros/exomizer/exomizer2/src/exomizer
G=$D/generado
mkdir -p "$G"
"$P/c64/ingles/datos.sh" > "$G/ingles.txt"
( cd "$P/c64/juego_final"
  C64=1 CINTA=1 IDIOMA=en ./construye.sh > /dev/null
  C64=1 CINTA=1 ./construye.sh > /dev/null
  C64=1 ./construye.sh > /dev/null
  ./construye.sh > /dev/null )
( cd "$P/c64/presentacion" && CINTA=1 ./construye.sh > "$G/presentacion.txt" )
GC=$P/c64/presentacion/generado_cinta

# the programs crunched (exomizer mem: backwards, loaded where Exomizer says for an in-place decrunch)
for f in abadia final; do "$EXO" mem -q "$GC/$f.prg" -o "$G/$f.exo"; done
python3 -I - "$G" <<'EOF'
import sys
g = sys.argv[1]
lineas = []
for f, n in (("abadia", "PRES_FIN"), ("final", "FINAL_FIN")):
    b = open(f"{g}/{f}.exo", "rb").read()
    a = b[0] | b[1] << 8
    fin = a + len(b) - 2
    assert 0x0400 <= a and fin <= 0xC000, f"{f}: the crunched data ${a:04X}-${fin:04X} must stay below the stage at $C000"
    lineas.append(f"{n} = ${fin:04X}                    ; the crunched {f}.prg: ${a:04X}-${fin - 1:04X}")
    open(f"{g}/{f}.dir", "w").write(f"0x{a:04X}\n")
    open(f"{g}/{f}.dat", "wb").write(b[2:])
open(f"{g}/cinta_gen.inc", "w").write("; made by c64/cinta/construye.sh\n" + "\n".join(lineas) + "\n")
EOF

# the turbo core, the KERNAL's two programs, the menu, the ending's stage
cd "$G"
"$B/ca65" -g -I "$D" -o turbo.o "$D/turbo.s"
"$B/ld65" -C "$D/turbo.cfg" -o turbo.bin -Ln turbo.lbl turbo.o
"$B/ca65" -I "$D" -I "$G" -o arranque_MENU.o "$D/arranque.s"
"$B/ca65" -I "$D" -I "$G" -D CINTA_FIN -o arranque_ETAPA_FIN.o "$D/arranque.s"
for e in MENU ETAPA_FIN; do "$B/ld65" -C "$D/arranque.cfg" -o "arranque_$e.prg" "arranque_$e.o"; done
"$B/ca65" -I "$D" -o exodecrunch.o "$D/exodecrunch.s"
"$B/ca65" -I "$D" -o exo_mem.o "$D/exo_mem.s"
for e in menu etapa_final; do
    "$B/ca65" -g -I "$D" -I "$G" -o "$e.o" "$D/$e.s"
    "$B/ld65" -C "$D/etapa.cfg" -o "$e.bin" -Ln "$e.lbl" "$e.o" exo_mem.o exodecrunch.o
done
rm -f ./*.o

# the game's blocks, checked by the model of the tape's loader
python3 -I "$D/flujo_cinta.py" "$P/c64/juego_final/c64cinta" "$P/c64/juego_final/c64cinta_en" "$GC/cargador.lbl" "$G" \
    > "$G/flujo.txt" || { cat "$G/flujo.txt"; exit 1; }

# the tape
python3 -I "$D/cinta.py" "$D/abadia64ks.tap" \
    kernal:ABADIA64KS:arranque_MENU.prg \
    turbo:1:0xC000:menu.bin \
    turbo:2:"$(cat abadia.dir)":abadia.dat \
    turbo:3:0:juego1.bin \
    turbo:4:0:juego2.bin \
    turbo:5:0:textos_en.bin \
    kernal:FINAL:arranque_ETAPA_FIN.prg \
    turbo:6:0xC000:etapa_final.bin \
    turbo:7:"$(cat final.dir)":final.dat > "$G/cinta.txt"
cat "$G/flujo.txt" "$G/cinta.txt"
if [ "$(id -u)" = 0 ]; then chown -R german:german "$D" "$GC"; fi
