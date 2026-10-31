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

"""The parchment glyphs the English text needs and the tape's gothic font lacks, drawn in the font's style.

The tape's font (68ADh-727Dh, 70 glyphs) has the lower-case letters a-z (but its `w` is an n-tilde: the Spanish text
writes the tilde as w), the capitals A C D E G H J L M O P S T Y, and 1 2 3 7 , - . : ; (c64/presentacion/datos.py adds
0 6 @ B for the credits).  The English text adds I, F and W (capitals: 14-row glyphs, advance 14, drawn in red 2 pixels
to the left of the cursor by the manusrun) and replaces `w` by a real w (3 strokes, advance 12).  '#' = ink.
Drawn here by hand: they are not the original artist's, and need a visual review (c64/ingles/NOTAS.md).
"""

REEMPLAZA = ("w",)          # characters whose glyph exists in the tape's font and is replaced (the tilde-n)

GLIFOS = {
    "w": (12, [".#...##...#.",           # rows 4-12: two v's sharing their middle stroke, as the font's v (rows 4-12)
               "###.####.###",
               ".##..##..##.",
               ".##..##..##.",
               ".##..##..##.",
               ".##..##..##.",
               ".##..##..##.",
               ".##.###.##..",
               "..###.###..."]),
    "I": (12, ["......#.##..",
               ".....#.####.",
               "....#.#..##.",
               "...#.##..#..",
               "...#.##.....",
               "...#.##.....",
               "...#.##.....",
               "...#.##.....",
               "...#.##.....",
               "...#.##.....",
               "...#.##.....",
               "..##.##.....",
               ".###.#......",
               "##...#......"]),
    "F": (14, ["..###....##...",
               ".#.###..####..",
               "#...#..#..##..",
               "...##.#...#...",
               "..##.##.......",
               "..##.##.##.#..",
               "#.##.######...",
               ".#######......",
               "..##.##.......",
               "..#..#........",
               "..#.#.........",
               ".#..#.........",
               "#...#.........",
               "..#..........."]),
    "W": (14, [".##....##...#.",
               "####..####.##.",
               ".###..###..##.",
               ".###..###..##.",
               ".###..###..##.",
               ".###..###..##.",
               ".###..###..##.",
               ".###..####.##.",
               ".###..#.####..",
               ".###.##..###..",
               "..###.#..##...",
               "..#####.###...",
               "...###..##....",
               "....#...#....."]),
}

# the rows these glyphs start at (their first drawn row from the cursor's line): the lower-case ones as the font's
# (x-height from row 4), the capitals from row 0
FILA_INICIAL = {"w": 4, "I": 0, "F": 0, "W": 0}
CODIGO = {"w": 0x77, "I": 0x49, "F": 0x46, "W": 0x57}
