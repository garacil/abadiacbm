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

"""Makes data/llave3/guion_llave3.txt: the key script of the manoeuvre (Adso takes key 3 from
Malachi's table with Malachi there), built on the ORIGINAL (the Z80 code alone: the hybrid host with
`--solo nada`, through ./traza) from the unchanged start state data/puro/estados/ram_d2h4.bin (a new game
at day 2, nona: Guillermo at the abbey's gate 88,9C, Adso beside him).

1. Guillermo walks to the scriptorium (the ground floor to the west stairs, up to the first floor, south
   part of the scriptorium), the route found by ruta.py on the floors' height maps, stretch by stretch.
2. Guillermo stops on the lower level of the scriptorium (height 0Dh) south-west of the long table, at
   31,3E (cells 30..31 x 3D..3E), walking there east with cursor up: on his last steps he is inside the box
   of Malachi at his desk (ai_guillermo_is_close 39AE, Malachi facing -y: x 31..3C, y 2C..43) with the
   advance key down, so Malachi's destination becomes 3 (52B4: 5455-5461, he goes to block the passage at
   3A,34); once Malachi has turned away Guillermo is outside his box, the destination goes back to 2 (5465)
   and Malachi walks back to his desk; when he turns south at 37,37 to step onto it, Guillermo, standing
   still, is inside his box again (facing +y: x 31..3C, y 31..48) with the advance key up: the commands
   are discarded (CALL 052E) and he stays (JP 39A8), against the table, until Guillermo moves.
3. Adso is steered with cursor down held (he steps the way Guillermo faces, 40EB) and Guillermo turning
   in place (left / right do not concern Malachi): north on the west side of the table, east along its
   north side, south through the gap between the table and the reading desk, west between Malachi and the
   step down, and north into the corner 35,37 facing -y: the cell in front of him (obj_front_position
   4EA5: x + 2 dx, y + 2 dy) is 35,35, where key 3 lies (record 2B77: 35 35, height 13h; Adso stands at
   0Fh, 13h - 0Fh < 5), and obj_pick_up_objects (4C46) gives it to him (his take mask 2949 = 02: key 3).

    hace_guion.py [OUT.txt [X Y]]     (X Y: where Guillermo stands, hex, on the row 3E; default 31 3E)
"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from piloto import Piloto, UP                      # noqa: E402
from mapa_alturas import floor_map                 # noqa: E402
from ruta import route, segments, celdas           # noqa: E402

T = os.path.dirname(AQUI)
ESTADO = os.path.join(T, 'puro/estados/ram_d2h4.bin')
TRABAJO = os.path.join(AQUI, 'tmp')

# 1. from the gate to the scriptorium: orientation and the cell at the end of each stretch (ruta.py on the
#    ground floor from 88,9C to the stairs' landing 1C,6A, then on the first floor to 2E,3E)
CAMINO = ("1->88,89 2->6F,89 1->6F,7A 2->4B,7A 3->4B,7B 2->33,7B 1->33,69 2->2B,69 3->2B,6D 2->23,6D "
          "3->23,6F 2->1D,6F 1->1D,6D 2->13,6D 1->13,63 0->17,63 3->17,69 0->1C,69 3->1C,6A 0->1D,6A "
          "1->1D,65 0->25,65 1->25,5F 0->27,5F 1->27,55 0->2E,55 1->2E,3E")
SITIO = (0x31, 0x3E)                               # 2. where Guillermo stands
LLAVE_SITIO = (0x35, 0x38)                         # 3. one cell south of Adso's place: the last step is -y


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(AQUI, 'guion_llave3.txt')
    sitio = (int(sys.argv[2], 16), int(sys.argv[3], 16)) if len(sys.argv) > 3 else SITIO
    os.makedirs(TRABAJO, exist_ok=True)
    p = Piloto(ESTADO, out, TRABAJO)
    p.espera(2)
    for tramo in CAMINO.split():
        o, xy = tramo.split('->')
        o = int(o)
        x, y = (int(v, 16) for v in xy.split(','))
        p.gira(o)
        if o in (0, 2):
            p.anda(x=x)
        else:
            p.anda(y=y)
    t = p.corre(p.frame + 1)
    print('frame %d: Guillermo in the scriptorium at %02X,%02X' % (p.frame, *t[p.frame]['G'][1:3]))
    p.espera(30)                                   # Adso comes up behind him
    p.gira(0)
    p.anda(x=sitio[0])                             # 2. east to 31,3E with cursor up: Malachi leaves his desk
    # wait for Malachi to stop away from his desk (destination 2 again, Guillermo close, cursor up released)
    t = p.corre(p.frame + 200)
    quieto = None
    for fr in range(p.frame, p.frame + 190):
        if (all(t[fr + k]['M'][1:3] == t[fr]['M'][1:3] for k in range(10)) and t[fr]['Mrsd'][2] == 2
                and t[fr]['M'][1:3] != [0x37, 0x38]):
            quieto = fr
            break
    if quieto is None:
        raise SystemExit('Malachi did not stop away from his desk')
    print('frame %d: Malachi stopped at %02X,%02X (destination 2, Guillermo close, cursor up released)'
          % (quieto, t[quieto]['M'][1], t[quieto]['M'][2]))
    p.frame = quieto + 10
    t = p.corre(p.frame + 1)
    d = t[p.frame]
    g, a, m = d['G'], d['A'], d['M']
    # 3. Adso's route, Guillermo's and Malachi's cells taken
    ram = open(ESTADO, 'rb').read()
    mapa = floor_map(ram, 1)
    r = route(mapa, (a[1], a[2]), LLAVE_SITIO, celdas(g[1], g[2]) | celdas(m[1], m[2]), (0x20, 0x20, 0x5F, 0x5F))
    if r is None:
        raise SystemExit('no way for Adso')
    cells, steps = r
    tramos = []
    pos = cells[0]
    for o, n in segments(steps):
        dx, dy = {0: (1, 0), 1: (0, -1), 2: (-1, 0), 3: (0, 1)}[o]
        pos = (pos[0] + dx * n, pos[1] + dy * n)
        tramos.append((o, pos[0] if o in (0, 2) else pos[1]))
    if tramos[-1][0] == 1:
        tramos[-1] = (1, 0x37)
    else:
        tramos.append((1, 0x37))                   # the last step -y: Adso faces the key
    print('Adso from %02X,%02X: %s' % (a[1], a[2], ' '.join('%d->%02X' % s for s in tramos)))
    p.guia_adso(tramos)
    t = p.corre(p.frame + 40)
    tomada = next((fr for fr in range(p.frame - 5, p.frame + 40) if t[fr]['objA'][0] & 0x02), None)
    if tomada is None:
        raise SystemExit('Adso did not take key 3')
    print('frame %d: Adso holds key 3 (objects %02X, record 2B77 = %s)'
          % (tomada, t[tomada]['objA'][0], ' '.join('%02X' % v for v in t[tomada]['key3'])))
    p.escribe()
    print('written', out)


if __name__ == '__main__':
    main()
