#!/usr/bin/env python3
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

"""Executions of a routine's entry instruction derived from the profile: cycles measured at the entry address
divided by that instruction's cost, which is fixed for the opcodes below (a hand count from the host's core,
juego/m6502/6502.c: the line of each `Cycles =`).  Only for routines whose calls the hit counter cannot see (the
ones run inside the 300 Hz ticks: sombra6502.c counts hits in the frame run only) and as a cross-check of the
hit counts.  Opcodes with a variable cost (abs,X: +1 on a page crossing) give bounds, not a count.

    derive_calls.py > derivadas.tsv"""
D = "c64/juego_final"
# opcode -> (cycles, source line in 6502.c)
COST = {0x08: (3, "PHP: line 1262"), 0x48: (3, "PHA: line 1919"), 0x8A: (2, "TXA: line 2657"), 0xA8: (2, "TAY: line 3017"),
        0xA9: (2, "LDA #: handler 3026-3029 -> ALU_OP_IMM, line 565"), 0x86: (3, "STX zp: handler 2610-2613 -> STO_OP, line 595, STO_CY_ZP line 578"),
        0x85: (3, "STA zp: handler 2602-2605 -> STO_OP, line 595, STO_CY_ZP line 578"), 0x20: (6, "JSR: line 1556")}
VARIABLE = {0xBD: ("LDA abs,X: ALU_CY_ABSX 4 (line 555) + 1 on a page crossing (ADR_ABSX lines 476-483)", 4, 5)}
b = open(D + "/juego.bin", "rb").read()
lbl = {}
for l in open(D + "/juego_todo.lbl"):
    t = l.split()
    if len(t) == 3 and t[0] == "al": lbl.setdefault(t[2].lstrip("."), int(t[1], 16))
print("routine\tsession\tentry\topcode\tcost\tsource\texecutions\tnote")
for s in ("1", "5", "8"):
    prof = {int(a, 16): int(c) for a, c in (l.split() for l in open(f"perfil_{s}.tsv") if l.strip())}
    for r in ("sys_tick", "s_interrupcion", "s_salida_activo", "t_frase", "plat_psg", "plat_ei", "plat_di", "s_envolventes", "s_tono_siguiente", "la_busca", "hb_draw"):
        a = lbl[r]; op = b[a]; c = prof.get(a, 0)
        if op in COST:
            k, src = COST[op]
            print(f"{r}\t{s}\t{a:04X}\t{op:02X}\t{k}\t{src}\t{c // k}\t{'exact' if c % k == 0 else 'NOT A MULTIPLE: ' + str(c)}")
        elif op in VARIABLE:
            src, lo, hi = VARIABLE[op]
            print(f"{r}\t{s}\t{a:04X}\t{op:02X}\t{lo}-{hi}\t{src}\t{c // hi}-{c // lo}\tbounds")
