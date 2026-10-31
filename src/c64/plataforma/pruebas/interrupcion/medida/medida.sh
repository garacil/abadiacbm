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

# The 300 Hz interrupt's real cost in VICE (c64/optimizacion/interrupcion/NOTAS.md, "Measured").
#   [VACIO=1] medida.sh [DIR] [FRAMES]   DIR: a game build directory (default c64/juego_final: its sources, its
#                                        generated mapa64.inc / juego.cfg / datos64.s, ../plataforma)
# Builds the C64 image with plat_irq timing its JSR sys_tick (X and Y saved around the instrument, outside the
# window; that plat_irq at $0160, segment MEDIDA: the code area has no room for it), the instrument (med.s) at
# $0100, and runs mide.py: frames 1-FRAMES (400) from the game's start.  The
# window = the JSR, sys_tick, the RTS and the instrument's own; VACIO=1 times an empty window instead (the
# instrument alone).  sys_tick's cycles a tick = window - empty; the interrupt's = that + plat_irq's own - 12.
# A tick nested in t_frase's character (its CLI, the Z80's EI there) is counted inside its outer window too.
set -euo pipefail
A=$(dirname "$(realpath "$0")"); P=$(realpath "$A/../../../../.."); B=$P/../tools/terceros/cc65/bin
D=$(realpath "${1:-$P/c64/juego_final}"); F=${2:-400}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
python3 -I - "$D/../plataforma/interrupcion.s" "$T/interrupcion.s" "${VACIO:-}" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
dentro = ("        jsr     $0100\n        jsr     $0114\n        jsr     sys_tick\n" if sys.argv[3] else
          "        jsr     $0100\n        jsr     sys_tick\n        jsr     $0114\n")
irq = (".segment \"MEDIDA\"\n.proc plat_irq\n        pha\n        txa\n        pha\n        tya\n        pha\n        lda     $01\n        pha\n"
       "        lda     #$35\n        sta     $01\n        cld\n        lda     CIA1_ICR\n" + dentro +
       "        pla\n        sta     $01\n        pla\n        tay\n        pla\n        tax\n        pla\n        rti\n"
       ".endproc\n.segment \"CODE\"\n")
s2 = re.sub(r"\.proc plat_irq\n.*?\.endproc\n", irq, s, count=1, flags=re.S)
assert s2 != s
open(sys.argv[2], "w").write(s2)
PY
objs=()
for s in "$D"/*.s; do
    case "$(basename "$s")" in plataforma_prueba.s|plat_aleatorio_prueba.s|stubs64.s) continue ;; esac
    o=$T/$(basename "${s%.s}").o; "$B/ca65" -I "$D" -I "$D/../plataforma" -o "$o" "$s"; objs+=("$o")
done
for s in tinta teclado psg disco; do "$B/ca65" -I "$D" -I "$D/../plataforma" -o "$T/p_$s.o" "$D/../plataforma/$s.s"; objs+=("$T/p_$s.o"); done
"$B/ca65" -I "$D" -I "$D/../plataforma" -o "$T/p_interrupcion.o" "$T/interrupcion.s"; objs+=("$T/p_interrupcion.o")
# the measuring plat_irq has no room in the code area: segment MEDIDA at $0160, before the image's first RAM segment
python3 -I - "$D/juego.cfg" "$T/juego.cfg" <<'PY'
import sys
l = open(sys.argv[1]).read().split("\n")
i = next(k for k, x in enumerate(l) if "load = RAM" in x)
l.insert(i, "    MEDIDA:   load = RAM, type = rw, start = $0160;")
open(sys.argv[2], "w").write("\n".join(l))
PY
"$B/ld65" -C "$T/juego.cfg" -o "$T/juego.bin" -Ln "$T/juego.lbl" "${objs[@]}"
"$B/ca65" -o "$T/med.o" "$A/med.s"; "$B/ld65" -C "$A/med.cfg" -o "$T/med.bin" "$T/med.o"
python3 -I "$A/mide.py" "$T" "$T/med.bin" "$F"
