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

"""The manoeuvre of hace_guion.py with Guillermo standing elsewhere on the row 3E: the walk of guion_llave3.txt
to 2E,3E (frame 1057) is kept, then Guillermo walks east to X,3E, Malachi stops where Guillermo's place makes
him stop, Adso is steered to 35,37 by his shortest way past both (ruta.py) and the script is written if he
takes key 3 (all on the original, the Z80 code alone).

    variante.py X OUT.txt        (X hex)
"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import barrido                                     # noqa: E402  (prefijo, LLEGADA, ESTADO)
from piloto import Piloto                          # noqa: E402
from mapa_alturas import floor_map                 # noqa: E402
from ruta import route, segments, celdas           # noqa: E402


def main():
    x, out = int(sys.argv[1], 16), sys.argv[2]
    tmp = os.path.join(AQUI, 'tmp_variante')
    os.makedirs(tmp, exist_ok=True)
    p = Piloto(barrido.ESTADO, out, tmp)
    p.teclas = barrido.prefijo()
    p.frame = barrido.LLEGADA + 30
    p.gira(0)
    p.anda(x=x)
    t = p.corre(p.frame + 200)
    quieto = next((fr for fr in range(p.frame, p.frame + 190)
                   if all(t[fr + k]['M'] == t[fr]['M'] for k in range(10)) and t[fr]['Mrsd'][2] == 2
                   and t[fr]['M'][1:3] != [0x37, 0x38]), None)
    if quieto is None:
        raise SystemExit('Malachi did not stop away from his desk')
    d = t[quieto]
    print('frame %d: Malachi stopped at %02X,%02X facing %d' % (quieto, d['M'][1], d['M'][2], d['M'][0]))
    p.frame = quieto + 10
    t = p.corre(p.frame + 1)
    g, a, m = t[p.frame]['G'], t[p.frame]['A'], t[p.frame]['M']
    mapa = floor_map(open(barrido.ESTADO, 'rb').read(), 1)
    r = route(mapa, (a[1], a[2]), (0x35, 0x38), celdas(g[1], g[2]) | celdas(m[1], m[2]), (0x20, 0x20, 0x5F, 0x5F))
    if r is None:
        raise SystemExit('no way for Adso')
    tramos, pos = [], r[0][0]
    for o, n in segments(r[1]):
        dx, dy = {0: (1, 0), 1: (0, -1), 2: (-1, 0), 3: (0, 1)}[o]
        pos = (pos[0] + dx * n, pos[1] + dy * n)
        tramos.append((o, pos[0] if o in (0, 2) else pos[1]))
    tramos.append((1, 0x37))                       # the last step -y: Adso faces the key
    print('Adso from %02X,%02X: %s' % (a[1], a[2], ' '.join('%d->%02X' % s for s in tramos)))
    p.guia_adso(tramos)
    t = p.corre(p.frame + 40)
    tomada = next((fr for fr in range(p.frame - 5, p.frame + 40) if t[fr]['objA'][0] & 0x02), None)
    if tomada is None:
        raise SystemExit('Adso did not take key 3')
    d = t[tomada]
    print('frame %d: Adso holds key 3 (record 2B77 = %s); Malachi at %02X,%02X'
          % (tomada, ' '.join('%02X' % v for v in d['key3']), d['M'][1], d['M'][2]))
    p.escribe()


if __name__ == '__main__':
    main()
