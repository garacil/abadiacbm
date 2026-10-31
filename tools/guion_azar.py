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

"""A deterministic random key script for the CPC 64 KiB game (exploration sessions).

    guion_azar.py SEED FIRST_FRAME FRAMES > script.txt

Frames are main-loop iterations (synchronous mode).  Mostly walking (cursor up), turns (left/right,
1-3 frames), sometimes cursor down and space; pauses with no key.  The same seed gives the same script.
"""
import random, sys


def main():
    seed, first, frames = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
    rnd = random.Random(seed)
    f = first
    print(f"# guion_azar.py {seed} {first} {frames}")
    while f < first + frames:
        r = rnd.random()
        if r < 0.55:
            d = rnd.randint(5, 60); print(f"{f} 0:0 {d}")        # walk
        elif r < 0.75:
            d = rnd.randint(1, 3); print(f"{f} {rnd.choice(['1:0', '0:1'])} {d}")   # turn
        elif r < 0.82:
            d = rnd.randint(1, 4); print(f"{f} 0:2 {d}")         # cursor down
        elif r < 0.88:
            d = rnd.randint(1, 3); print(f"{f} 5:7 {d}")         # space
        else:
            d = rnd.randint(3, 30)                                # nothing
        f += d + 1


if __name__ == "__main__":
    main()
