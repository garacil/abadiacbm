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

"""The arithmetic of the speed goal from the host's per-frame cycle files (hibrido --ciclos-frame).

    goal.py NOKEYS.tsv NOKEYS.log SESSION.tsv...      prints a Markdown fragment (deterministic)

NOKEYS.tsv: the no-keys run to --hasta 2472 (host frames 472-2472: 2001 main-loop frames); VICE / Caprice32
measured frames 1-2000 of the same no-keys game (ESTADO.md "Speed, measured": CPC 6128 294.2 s, C64 PAL 373.2 s).
The C64 clock 0.985 MHz is the figure of c64/CODIGO6502.md; 985248 Hz is the exact PAL value used here for the
conversions (not taken from a project source)."""
import sys, re
F_C64 = 985248.0            # PAL C64 CPU clock, Hz
CPC_S, C64_S, FRAMES = 294.2, 373.2, 2000
CPC_400, C64_400 = 33.8, 35.0
TICK = F_C64 / 300.0        # cycles in a 300 Hz tick on the C64

def rows(f):
    r = [l.rstrip("\n").split("\t") for l in open(f) if l.strip()][1:]
    return [(int(x[0]), int(x[1]), int(x[2]), int(x[3])) for x in r]

nk = rows(sys.argv[1])
ticks = int(re.search(r"(\d+) ticks", open(sys.argv[2]).read()).group(1))
first = nk[:FRAMES]                  # host frames 472-2471
c = sum(r[2] for r in first); z = sum(r[1] for r in first)
b36 = sum(1 for r in first if r[3] == 36); b0 = sum(1 for r in first if r[3] == 0)
over = sum(1 for r in first if r[2] > 36 * TICK)
print(f"- No-keys run, host frames {first[0][0]}-{first[-1][0]} ({len(first)} main-loop frames, VICE's frames 1-{FRAMES}): "
      f"**{c} 6502 cycles**, {c / len(first):.0f} per frame ({c / len(first) / F_C64 * 1000:.1f} ms at {F_C64 / 1e6:.6f} MHz); "
      f"Z80 {z} T-states, {z / len(first):.0f} per frame ({z / len(first) / 4000:.1f} ms at 4 MHz).")
print(f"- Frame budget (ram[21DA], the CP operand at 21D9): {b36} frames with 36 ticks, {b0} with 0 (set by the game's scripts, 3D01); "
      f"{over} of the {len(first)} frames have more than 36 ticks of 6502 work ({36 * TICK:.0f} cycles) on the host.")
ratio = CPC_S / C64_S
print(f"- Measured on the machines (ESTADO.md): CPC {CPC_S} s, C64 {C64_S} s for frames 1-{FRAMES}: the C64 takes {C64_S / CPC_S:.3f}x; "
      f"to match, the C64 must take {ratio:.4f} of its time: **{100 * (1 - ratio):.2f} % less**.")
cpf = c / len(first)
print(f"- Cycles per frame now (host, game work): **{cpf:.0f}**; needed: **{cpf * ratio:.0f}** ({cpf * (1 - ratio):.0f} fewer per frame, "
      f"{(1 - ratio) * c:.0f} over the {FRAMES} frames) if the unmeasured platform part shrinks in proportion.")
vice_cpf = C64_S / FRAMES * F_C64
print(f"- VICE's frame: {C64_S / FRAMES * 1000:.1f} ms = {vice_cpf:.0f} cycles; the host sees {cpf:.0f} of them ({100 * cpf / vice_cpf:.1f} %): "
      f"the rest, {vice_cpf - cpf:.0f} cycles per frame ({100 * (1 - cpf / vice_cpf):.1f} %), is what the host does not measure "
      f"(the real 300 Hz interrupt: {C64_S / FRAMES * 300:.1f} ticks per VICE frame against {ticks} delivered by the host in the whole 2001-frame run; see the report).")
print(f"- CPC's frame: {CPC_S / FRAMES * 1000:.1f} ms = {CPC_S / FRAMES * 300:.1f} ticks; at 0 budget a frame is pure work, so the target is "
      f"**{CPC_S / FRAMES * F_C64:.0f} C64 cycles per frame all included** (game + interrupt + platform).")
f400 = nk[:400]; c400 = sum(r[2] for r in f400)
print(f"- Frames 1-400 (host frames {f400[0][0]}-{f400[-1][0]}): {c400} cycles, {c400 / 400:.0f} per frame; machines: CPC {CPC_400} s, C64 {C64_400} s: "
      f"the C64 must lose {100 * (1 - CPC_400 / C64_400):.2f} %: {c400 / 400 * CPC_400 / C64_400:.0f} host cycles per frame if proportional "
      f"({sum(1 for r in f400 if r[3] == 36)} of these frames have the 36-tick budget, {sum(1 for r in f400 if r[2] > 36 * TICK)} exceed it in work).")
for f in sys.argv[3:]:
    r = rows(f); c = sum(x[2] for x in r); n = len(r)
    s = sorted(x[2] for x in r)
    print(f"- {f}: {n} frames, {c} cycles, {c / n:.0f} per frame, median {s[n // 2]}, 90th percentile {s[int(n * 0.9)]}, max {s[-1]}; "
          f"{sum(1 for x in r if x[2] > 36 * TICK)} frames over 36 ticks of work.")
