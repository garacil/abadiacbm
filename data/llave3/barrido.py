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

"""Where must Guillermo stand?  From the walk of guion_llave3.txt (Guillermo arrives in the scriptorium at
2E,3E at frame 1057, day 2 nona, Malachi at his desk), Guillermo walks (cursor up) to each target cell by
the shortest route and stands still; the original (Z80 code alone) runs 200 frames more and the table says
where Malachi is then, his destination, whether he is still moving, and whether a way for Adso to 35,37 (the
only cell from which he can take key 3, facing -y) is open past Malachi and Guillermo (ruta.py's search on
the first floor's heights, both characters' cells taken).

    barrido.py [OUT.tsv [X,Y ...]]       (hex targets; default: a grid of the scriptorium around the table)
"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from piloto import Piloto                          # noqa: E402
from mapa_alturas import floor_map                 # noqa: E402
from ruta import route, segments, celdas           # noqa: E402

T = os.path.dirname(AQUI)
ESTADO = os.path.join(T, 'puro/estados/ram_d2h4.bin')
LLEGADA = 1057                                     # the walk of guion_llave3.txt ends here, at 2E,3E


def prefijo():
    k = []
    for linea in open(os.path.join(AQUI, 'guion_llave3.txt')):
        if linea.startswith('#') or not linea.strip():
            continue
        f, rb, n = linea.split()
        r, b = (int(v) for v in rb.split(':'))
        if int(f) < LLEGADA:
            k.append((int(f), (r, b), int(n)))
    return k


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(AQUI, 'barrido.tsv')
    tmp = os.path.join(AQUI, 'tmp_' + os.path.splitext(os.path.basename(out))[0])
    os.makedirs(tmp, exist_ok=True)
    ram = open(ESTADO, 'rb').read()
    mapa = floor_map(ram, 1)
    objetivos = [(x, y) for y in (0x3B, 0x3C, 0x3D, 0x3E) for x in range(0x2C, 0x46, 2)]
    objetivos += [(x, y) for y in (0x32, 0x35, 0x38) for x in range(0x22, 0x32, 2)]
    objetivos += [(x, 0x31) for x in range(0x32, 0x3C, 2)]
    if len(sys.argv) > 2:
        objetivos = [tuple(int(v, 16) for v in a.split(',')) for a in sys.argv[2:]]
    with open(out, 'w') as f:
        f.write('target\tGuillermo\tMalachi_o_x_y\tdest\treached\tmoving\tway_for_Adso\tnote\n')
        for obj in objetivos:
            r = route(mapa, (0x2E, 0x3E), obj, (), (0x20, 0x20, 0x5F, 0x5F))
            if r is None:
                continue
            p = Piloto(ESTADO, None, tmp)
            p.teclas = prefijo()
            p.frame = LLEGADA + 30
            nota = ''
            try:
                pos = (0x2E, 0x3E)
                for o, n in segments(r[1]):
                    dx, dy = {0: (1, 0), 1: (0, -1), 2: (-1, 0), 3: (0, 1)}[o]
                    pos = (pos[0] + dx * n, pos[1] + dy * n)
                    p.gira(o)
                    if o in (0, 2):
                        p.anda(x=pos[0])
                    else:
                        p.anda(y=pos[1])
            except RuntimeError as e:
                nota = 'walk stopped: %s' % e
            t = p.corre(p.frame + 201)
            d, d0 = t[p.frame + 200], t[p.frame + 190]
            g, a, m = d['G'], d['A'], d['M']
            moviendo = 'yes' if d0['M'] != d['M'] else 'no'
            camino = route(mapa, (a[1], a[2]), (0x35, 0x37), celdas(g[1], g[2]) | celdas(m[1], m[2]),
                           (0x20, 0x20, 0x5F, 0x5F))
            f.write('%02X,%02X\t%02X,%02X,%02X\t%d %02X,%02X\t%d\t%d\t%s\t%s\t%s\n'
                    % (obj[0], obj[1], g[1], g[2], g[3], m[0], m[1], m[2], d['Mrsd'][2], d['Mrsd'][0], moviendo,
                       'open' if camino else 'closed', nota))
            f.flush()
            print('%02X,%02X -> Malachi %02X,%02X dest %d, way %s %s' % (obj[0], obj[1], m[1], m[2], d['Mrsd'][2],
                                                                       'open' if camino else 'closed', nota))


if __name__ == '__main__':
    main()
