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

"""A deterministic random key script for long checks of the pure C game against the Z80 (as
guion_azar.py, plus the keys that do not stop the game in the synchronous mode: Q and R together (the
mirror), S and N (Adso's question at night), '.' (key 7)).  Del (pause) and CTRL+TAB (the tape menu)
are left out: they wait for keys with no frame, which a frame-based script never gives.

    guion_largo.py SEED FIRST_FRAME FRAMES > script.txt
"""
import random, sys

seed, first, frames = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
rnd = random.Random(seed)
f = first
print(f"# guion_largo.py {seed} {first} {frames}")
while f < first + frames:
    r = rnd.random()
    if r < 0.52:
        d = rnd.randint(5, 60); print(f"{f} 0:0 {d}")                          # walk
    elif r < 0.72:
        d = rnd.randint(1, 3); print(f"{f} {rnd.choice(['1:0', '0:1'])} {d}")  # turn
    elif r < 0.78:
        d = rnd.randint(1, 4); print(f"{f} 0:2 {d}")                           # cursor down
    elif r < 0.84:
        d = rnd.randint(1, 3); print(f"{f} 5:7 {d}")                           # space
    elif r < 0.86:
        d = rnd.randint(2, 8); print(f"{f} 8:3 {d}"); print(f"{f} 6:2 {d}")    # Q + R
    elif r < 0.88:
        d = rnd.randint(1, 3); print(f"{f} {rnd.choice(['7:4', '5:6'])} {d}")  # S or N
    elif r < 0.89:
        d = 1; print(f"{f} 0:7 {d}")                                           # key 7
    else:
        d = rnd.randint(3, 30)                                                  # nothing
    f += d + 1
