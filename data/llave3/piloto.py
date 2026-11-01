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

"""Builds a key script for the hybrid host step by step, deterministically: each step adds key presses,
runs the original (traza = src/juego/hibrido.c with a per-frame trace, `--solo nada`: the Z80 code alone)
from the start state to a horizon and reads the trace to place the next presses exactly (the frame where
Guillermo faces the wanted way, the frame where he reaches the end of a stretch).  Nothing is timed by
hand: the same inputs give the same script.

Key script lines: 'FRAME ROW:BIT FRAMES' (src/juego/hibrido.c carga_guion).  CPC matrix: cursor up 0:0
(walk), right 0:1 (turn -1), down 0:2 (Adso), left 1:0 (turn +1).  Orientation 0 +x, 1 -y, 2 -x, 3 +y.
"""
import os
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
T = os.path.dirname(AQUI)                      # data/
UP, RIGHT, DOWN, LEFT = (0, 0), (0, 1), (0, 2), (1, 0)


def lee_traza(path):
    """frame -> dict of the trace fields (G/A/M as (o, x, y, z), the rest as byte lists)"""
    t = {}
    for linea in open(path):
        if linea.startswith('#'):                               # (my licence header)
            continue
        c = linea.rstrip('\n').split('\t')
        d = {}
        for campo in c[1:]:
            k, _, v = campo.partition('=')
            if k in ('day', 'hour'):
                d[k] = int(v)
            elif k == 'keys':
                d[k] = v
            else:
                d[k] = [int(b, 16) for b in v.split()]
        t[int(c[0])] = d
    return t


class Piloto:
    def __init__(self, estado, guion_out, trabajo_dir):
        self.estado = estado
        self.guion_out = guion_out
        self.dir = trabajo_dir
        self.teclas = []                       # (frame, (row, bit), frames)
        self.frame = 472                       # the first frame the game reads keys (estado.txt: 471)

    def escribe(self, path=None):
        with open(path or self.guion_out, 'w') as f:
            f.write('# made by data/llave3/piloto.py\n')
            for fr, (r, b), n in sorted(tuple(k) for k in self.teclas):
                f.write('%d %d:%d %d\n' % (fr, r, b, n))

    def corre(self, hasta):
        g = os.path.join(self.dir, 'paso_guion.txt')
        tr = os.path.join(self.dir, 'paso_traza.tsv')
        self.escribe(g)
        subprocess.run([os.path.join(AQUI, 'traza'), tr, self.estado,
                        os.path.join(T, 'cpc64/inicio_juego/estado.txt'), os.path.join(T, 'sincrono/puntos64.txt'),
                        '--guion', g, '--hasta', str(hasta), '--limite', '50000000', '--solo', 'nada'],
                       check=True, stderr=subprocess.DEVNULL)
        return lee_traza(tr)

    def espera(self, n):
        self.frame += n

    def gira(self, o):
        """turns Guillermo to orientation o: one press of left (+1) or right (-1) at a time, each placed at
        the first frame where it takes effect"""
        for _ in range(8):
            t = self.corre(self.frame + 2)
            cur = t[self.frame]['G'][0]
            if cur == o:
                return
            tecla = LEFT if (o - cur) & 3 in (1, 2) else RIGHT
            while True:                           # the press counts when Guillermo is not mid-step
                self.teclas.append((self.frame, tecla, 1))
                t = self.corre(self.frame + 3)
                if t[self.frame + 2]['G'][0] != cur:
                    self.frame += 2               # a frame without the key, so the next press is new
                    break
                self.teclas.pop()
                self.frame += 1
        raise RuntimeError('cannot turn to %d at frame %d' % (o, self.frame))

    def anda(self, x=None, y=None, maximo=400):
        """walks (cursor up) until Guillermo's x (or y) reaches the value (or passes it, the way he faces: on
        stairs a step can move two cells); the key is released at that frame.  Returns the frame reached."""
        f0 = self.frame
        t = self.corre(f0 + 2)
        o = t[f0]['G'][0]
        self.teclas.append((f0, UP, maximo))
        t = self.corre(f0 + maximo + 2)
        llegada = None
        for fr in range(f0 + 1, f0 + maximo + 1):
            g = t[fr]['G']
            if x is not None and ((o == 0 and g[1] >= x) or (o == 2 and g[1] <= x) or (o in (1, 3) and g[1] == x)) and y is None:
                llegada = fr
            if y is not None and ((o == 3 and g[2] >= y) or (o == 1 and g[2] <= y) or (o in (0, 2) and g[2] == y)) and x is None:
                llegada = fr
            if llegada:
                break
        self.teclas.pop()
        if llegada is None:
            g = t[f0 + maximo]['G']
            raise RuntimeError('did not reach x=%s y=%s from frame %d: at %02X %02X %02X' % (x, y, f0, g[1], g[2], g[3]))
        self.teclas.append((f0, UP, llegada - f0))
        self.frame = llegada
        g = t[llegada]['G']
        if (x is not None and g[1] != x) or (y is not None and g[2] != y):
            print('  note: frame %d Guillermo at %02X %02X (wanted x=%s y=%s)' % (llegada, g[1], g[2], x, y))
        return llegada

    def pulsa(self, tecla, n=1):
        self.teclas.append((self.frame, tecla, n))
        self.frame += n

    def guia_adso(self, tramos, maximo=80, antes=0):
        """steers Adso along tramos, a list of (orientation, x or y at the end of the stretch), with the down
        key held all the time (Adso steps the way Guillermo faces: chr_adso_step_guillermo_dir 40EB) and
        Guillermo turned (left/right presses) to the orientation of each stretch at the frame Adso ended
        the stretch before (minus `antes` frames).  Returns the frame."""
        inicio = self.frame
        abajo = [inicio, DOWN, maximo]
        self.teclas.append(abajo)
        for o, fin in tramos:
            abajo[2] = self.frame + maximo - inicio
            t = self.corre(self.frame + 2)
            cur = t[self.frame]['G'][0]
            if cur != o:
                d = (o - cur) & 3
                presses = [LEFT] if d == 1 else [RIGHT] if d == 3 else [LEFT, LEFT]
                f = self.frame
                for k in presses:
                    self.teclas.append((f, k, 1))
                    f += 2
            eje = 1 if o in (0, 2) else 2
            t = self.corre(self.frame + maximo)
            llegada = None
            for fr in range(self.frame, self.frame + maximo):
                if t[fr]['A'][eje] == fin:
                    llegada = fr
                    break
            if llegada is None:
                a = t[self.frame + maximo - 1]['A']
                raise RuntimeError('Adso did not end the stretch %d to %02X from frame %d: at %02X %02X' % (o, fin, self.frame, a[1], a[2]))
            self.frame = max(llegada - antes, self.frame + 1)
        abajo[2] = self.frame - inicio
        return self.frame
