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

"""Summary of a trace of ./traza: the frames where Malachi's destination / reached place / position change,
where Guillermo stops, and where Adso takes key 3 (bit 1 of his objects [2947]; record 2B77 +0 = 80h held,
+2/+3 = his holder 2944).

    resumen.py TRAZA.tsv
"""
import sys
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from piloto import lee_traza   # noqa: E402


def h(v):
    return ' '.join('%02X' % x for x in v)


t = lee_traza(sys.argv[1])
frames = sorted(t)
antes = None
tomada = None
for fr in frames:
    d = t[fr]
    m = (tuple(d['M']), tuple(d['Mrsd']))
    if antes is not None and m != antes and fr > 1000:
        print('%5d  Malachi o x y z %s  reached/state/dest %s   Guillermo %s  Adso %s'
              % (fr, h(d['M']), h(d['Mrsd']), h(d['G']), h(d['A'])))
    antes = m
    if tomada is None and d['objA'][0] & 0x02:
        tomada = fr
if tomada:
    d = t[tomada]
    print('%5d  ADSO TAKES KEY 3: his objects %02X, record 2B77 = %s; Adso %s (o x y z), Malachi %s, Guillermo %s'
          % (tomada, d['objA'][0], h(d['key3']), h(d['A']), h(d['M']), h(d['G'])))
else:
    print('key 3 not taken: record 2B77 = %s at frame %d' % (h(t[frames[-1]]['key3']), frames[-1]))
