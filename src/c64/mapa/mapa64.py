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

"""The map of the abbey on the Commodore 64: for each floor, a plan seen from above and every screen as the C64
game draws it, with the passages between rooms and the staircases.

    python3 -I c64/mapa/mapa64.py [OUT.png]       (default c64/mapa/mapa_c64.png; needs gcc and PIL)

The screens are drawn by the 6502 game itself (salas64.c on the hybrid host's 6502 core: iso_update_camera_room,
iso_draw_room, spr_draw_or_darken of c64/juego_final), each room with its fixed camera, its doors and objects, no
characters, dark rooms lit, in the C64's colours.  A room's decoration is stored already drawn for its camera (the
room builder puts tiles at screen-grid positions; only the characters go through the camera transform), so two
neighbouring screens never face the same way and cannot be turned to match.  The plan joins them: it is drawn from
the heights the characters walk on (the floor's height list, one 24 x 24 buffer per room from the 6502's
chr_fill_height_buffer), north up (the MicroHobby 162 plan of the CPC game has north on the right), 16 x 16 cells
a room; the cells a character can reach follow the path search's rule (chr_path_check_square: a 2x2 square flat
or a single slope, steps of one, never above 0Ch, where the floor above begins).

Rooms are placed on the room grid of their floor: X to the right, Y down.  A passage is a run of cells on the
border of two rooms a character can step across, green on the plan; on each screen it has a green line on its
threshold and the room it leads to (the cell projected as chr_project does it: column 2(x-y)+28h, row 4(x+y-h-5)
after the camera transform).  Staircases between floors (rooms whose link byte has bit 4 up or bit 5 down): the
cells of height 0Dh / 01h, where the floor changes, purple, numbered E1, E2... at both ends.
"""
import os
import subprocess
import sys
import tempfile
from collections import Counter, deque

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.dont_write_bytecode = True                 # nothing written next to the modules it reads
from comun64 import (RAIZ, JUEGO, PALETA, DIA, simbolos, pixeles, imagen, texto, ancho_texto)   # noqa: E402

C = PALETA
FONDO = C[6]                    # the C64's blue screen, light blue letters
LETRA = C[14]
TITULO = C[1]
NOTA = C[15]
NEGRO = C[0]
BLANCO = C[1]
VERDE = C[5]                    # passages
VERDE_OSC = (0, 70, 0)
PURPURA = C[4]                  # staircases
ROJO = C[2]                     # doors, the mirror
MURO = C[9]                     # brown: walls (height 0Eh-0Fh)
OBSTACULO = C[8]                # orange: what cannot be walked on, lower than a wall
BORDE = C[11]                   # room borders
ESPEJO = C[11]
RAMPA = [C[13], C[13], C[3], C[3], C[15], C[15], C[10], C[10], C[12], C[12], C[7], C[7], C[1], C[1]]

W, H = 256, 160
CAB = 14
PASO_X, PASO_Y = W + 40, H + CAB + 30
CEL = 12
PLANTAS = ('Planta baja (alturas 00-0Ch)', 'Primera planta (alturas 0Dh-17h)',
           'Segunda planta: la biblioteca (alturas desde 18h; salas oscuras: hace falta la lampara)')
NOMBRE = ('planta baja', 'primera planta', 'biblioteca')
BASE = (0x00, 0x0B, 0x16)
ROT = (lambda x, y: (x, y), lambda x, y: (0x28 - y, x),
       lambda x, y: (0x28 - x, 0x28 - y), lambda x, y: (y, 0x28 - x))
VECINOS = ((1, 0), (0, -1), (-1, 0), (0, 1))     # link bits 0-3: +x, -y, -x, +y
VACIADAS = (0x17, 0x27, 0x32, 0x33, 0x35, 0x36, 0x4B)   # emptied by the 64 KiB version (ESTADO.md)


# ------------------------------------------------------------------ the 6502 game's output

def salas():
    tmp = tempfile.mkdtemp(prefix='salas64_')
    exe = os.path.join(tmp, 'salas64')
    m65 = os.path.join(RAIZ, 'juego', 'm6502')
    subprocess.run(['gcc', '-std=c99', '-O2', '-D_DEFAULT_SOURCE', '-o', exe, os.path.join(AQUI, 'salas64.c'),
                    os.path.join(m65, 'm6502.c'), os.path.join(m65, '6502.c')], check=True)
    out = os.path.join(tmp, 'salas')
    subprocess.run([exe, JUEGO, out], check=True)
    mem = open(os.path.join(out, 'mem.bin'), 'rb').read()
    res = {}
    for linea in list(open(os.path.join(out, 'salas.tsv')))[1:]:
        f, X, Y, sala, ori, osc, tintas = linea.rstrip('\n').split('\t')
        f, X, Y = int(f), int(X), int(Y)
        nombre = os.path.join(out, f'f{f}_x{X}_y{Y}')
        pal = tuple(int(t, 16) for t in tintas.split(',')[:4])
        img = imagen(pixeles(open(nombre + '.bmp', 'rb').read(), 32, 160, pal))
        def alt(ext):
            a = open(nombre + ext, 'rb').read()
            return {(X * 16 - 4 + i, Y * 16 - 4 + j): a[j * 24 + i] & 0x0F for j in range(24) for i in range(24)}
        hb = alt('.alt')
        res[(f, X, Y)] = dict(sala=int(sala, 16), orient=int(ori), oscura=osc == '1', img=img, alturas=hb,
                              alturas_espejo=alt('.esp') if os.path.exists(nombre + '.esp') else hb)
    return res, mem


def datos(S, mem, sim):
    """From the 6502 memory at the first frame: the room links, the doors, where the characters start."""
    enl = sim['D64_CHR_ROOM_LINKS']
    for (f, X, Y), s in S.items():
        s['enlaces'] = mem[enl + (0, 0xB0, 0xB8)[f] + (Y << 4 | X)]
    g = sim['D64_CHR_GUILLERMO']
    inicio = [(mem[g + 15 * k + 2], mem[g + 15 * k + 3], mem[g + 15 * k + 4]) for k in range(6)]
    pasos = [int.from_bytes(mem[sim['D64_OBJ_DOOR_CELL_STEPS'] + 2 * i:][:2], 'little', signed=True) for i in range(4)]
    paso_xy = {1: (1, 0), -24: (0, -1), -1: (-1, 0), 24: (0, 1)}
    puertas = {}
    p = sim['D64_OBJ_DOORS']
    n = 0
    while mem[p] != 0xFF:
        dx, dy = paso_xy[pasos[mem[p] & 3]]
        puertas[n] = [(mem[p + 2] + k * dx, mem[p + 3] + k * dy) for k in range(3)]
        p += 5
        n += 1
    # the pairs of rooms whose link the doors switch (obj_set_door_permissions: per door, (link index, bits)
    # pairs to FFh)
    con_puerta = set()
    p = sim['D64_OBJ_DOOR_LINK_TABLE']
    for _ in range(6):
        while mem[p] != 0xFF:
            idx, bits = mem[p], mem[p + 1]
            p += 2
            if idx < 0xB0:
                f, X, Y = 0, idx & 15, idx >> 4
            else:
                j = idx - 0xB0
                f, X, Y = (1 if (j & 15) < 8 else 2), (j & 15) % 8, j >> 4
            for bit, (dx, dy) in enumerate(VECINOS):
                if bits >> bit & 1:
                    con_puerta.add((f, frozenset(((X, Y), (X + dx, Y + dy)))))
        p += 1
    return inicio, puertas, con_puerta


def proyecta(sala, X, Y, x, y, h):
    """Screen pixel (of the 256-pixel-wide play area) of the world point (x, y) at height h: chr_project."""
    lx, ly = ROT[sala['orient']](x - (X * 16 - 12), y - (Y * 16 - 12))
    return 8 * (lx - ly) + 128, 4 * (lx + ly - h - 5) - 40


# ------------------------------------------------------------------ the floors

class Planta:
    def __init__(self, f, S, inicio, puertas, con_puerta):
        self.f = f
        self.salas = {(X, Y): s for (g, X, Y), s in S.items() if g == f}
        self.alt, self.espejo = {}, set()
        for (X, Y), s in self.salas.items():
            for j in range(16):
                for i in range(16):
                    c = (X * 16 + i, Y * 16 + j)
                    self.alt[c] = s['alturas_espejo'][c]
                    if s['alturas'][c] != self.alt[c]:
                        self.espejo.add(c)
        # the staircases: in a room whose link byte has bit 4 (up) or bit 5 (down), its cells of height 0Dh / 01h
        self.escaleras = {}
        for (X, Y), s in self.salas.items():
            s['escaleras'] = []
            for j in range(16):
                for i in range(16):
                    c = (X * 16 + i, Y * 16 + j)
                    h = s['alturas'][c]
                    k = 'sube' if s['enlaces'] & 0x10 and h == 0x0D else 'baja' if s['enlaces'] & 0x20 and h == 0x01 else None
                    if k:
                        s['escaleras'].append((k, c[0], c[1], h))
                        self.escaleras[c] = k
        # where a character can be (chr_path_check_square, from where the characters start and the top of the
        # staircases below)
        semillas = [(x, y) for x, y, z in inicio if BASE[f] <= z < (BASE[f + 1] if f < 2 else 0x100)]
        for (g, X, Y), s in S.items():
            if g == f - 1:
                semillas += [(x, y) for k, x, y, h in s.get('escaleras', []) if k == 'sube']
        visto, cola = set(), deque()
        for c in semillas:
            for n in (c, (c[0] + 1, c[1]), (c[0], c[1] + 1), (c[0] + 1, c[1] + 1)):
                if self.cuadro(n) is not None and n not in visto:
                    visto.add(n)
                    cola.append(n)
        while cola:
            x, y = cola.popleft()
            h = self.alt[(x, y)]
            if h > 0x0C:
                continue
            for dx, dy in VECINOS:
                n = (x + dx, y + dy)
                if n not in visto:
                    c = self.cuadro(n)
                    if c is not None and abs(c - h) <= 1:
                        visto.add(n)
                        cola.append(n)
        self.andable = set()
        for x, y in visto:
            self.andable.update(((x, y), (x - 1, y), (x, y - 1), (x - 1, y - 1)))
        # the passages, their runs, their kind
        self.pasos = {}
        for (X, Y) in self.salas:
            for dx, dy in ((1, 0), (0, 1)):
                if (X + dx, Y + dy) not in self.salas:
                    continue
                pares = []
                for k in range(16):
                    a = (X * 16 + 15, Y * 16 + k) if dx else (X * 16 + k, Y * 16 + 15)
                    b = (a[0] + dx, a[1] + dy)
                    if a in self.andable and b in self.andable and abs(self.alt[a] - self.alt[b]) <= 1:
                        pares.append((a, b))
                tramos = []
                for p in pares:
                    if tramos and abs(p[0][0] - tramos[-1][-1][0][0]) + abs(p[0][1] - tramos[-1][-1][0][1]) == 1:
                        tramos[-1].append(p)
                    else:
                        tramos.append([p])
                if tramos:
                    self.pasos[((X, Y), (X + dx, Y + dy))] = tramos
        self.tipo = {}
        for (a, b), tramos in self.pasos.items():
            bit = VECINOS.index((b[0] - a[0], b[1] - a[1]))
            if any(p[0] in self.espejo or p[1] in self.espejo for t in tramos for p in t):
                self.tipo[(a, b)] = 'espejo'
            elif (f, frozenset((a, b))) in con_puerta:
                self.tipo[(a, b)] = 'puerta'
            elif self.salas[a]['enlaces'] >> bit & 1 and self.salas[b]['enlaces'] >> ((bit + 2) & 3) & 1:
                self.tipo[(a, b)] = 'sin enlace'
            else:
                self.tipo[(a, b)] = 'paso'
        self.accesible = {XY for XY in self.salas
                          if any((XY[0] * 16 + i, XY[1] * 16 + j) in self.andable for i in range(16) for j in range(16))}
        self.puertas = {n: c for n, c in puertas.items() if any(x in self.alt for x in c)} if f == 0 else {}

    def cuadro(self, c):
        x, y = c
        q = [self.alt.get(p) for p in ((x, y), (x - 1, y), (x, y - 1), (x - 1, y - 1))]
        if None in q:
            return None
        h = q[0]
        a = q[1] - h
        if a == 0:
            ch = q[2] - h + 1
            if not 0 <= ch < 3:
                return None
        else:
            ch = a + 1
            if not 0 <= ch < 3 or q[2] != h:
                return None
        return h if q[3] - h + 1 == ch else None

    def salidas(self, XY):
        out = []
        for (a, b), tramos in self.pasos.items():
            if XY in (a, b):
                v = b if a == XY else a
                k = 0 if a == XY else 1
                out.append((v, (v[0] - XY[0], v[1] - XY[1]), self.tipo[(a, b)], [[p[k] for p in t] for t in tramos]))
        return out


# ------------------------------------------------------------------ drawing

def flecha(d, x0, y0, x1, y1, color, punta=5):
    d.line((x0, y0, x1, y1), fill=color, width=2)
    vx, vy = x1 - x0, y1 - y0
    n = max(1e-6, (vx * vx + vy * vy) ** 0.5)
    vx, vy = vx / n, vy / n
    d.polygon([(x1 + vx * 2, y1 + vy * 2), (x1 - vx * punta - vy * punta * 0.6, y1 - vy * punta + vx * punta * 0.6),
               (x1 - vx * punta + vy * punta * 0.6, y1 - vy * punta - vx * punta * 0.6)], fill=color)


def color_celda(P, c):
    if c in P.escaleras:
        return PURPURA
    if c in P.espejo:
        return ROJO
    if c in P.andable:
        return RAMPA[min(P.alt[c], 13)]
    return MURO if P.alt[c] >= 0x0E else OBSTACULO


def esquina_camara(s, X, Y):
    cx, cy = X * 16 + 8, Y * 16 + 8
    _, r0 = proyecta(s, X, Y, cx, cy, 0)
    _, rx = proyecta(s, X, Y, cx + 1, cy, 0)
    _, ry = proyecta(s, X, Y, cx, cy + 1, 0)
    return (1 if rx > r0 else -1), (1 if ry > r0 else -1)


def plano(P, S, numero):
    xs = [X for X, Y in P.salas]
    ys = [Y for X, Y in P.salas]
    x0, y0 = min(xs), min(ys)
    img = Image.new('RGB', ((max(xs) - x0 + 1) * 16 * CEL + 1, (max(ys) - y0 + 1) * 16 * CEL + 1), FONDO)
    d = ImageDraw.Draw(img)
    pos = lambda x, y: ((x - x0 * 16) * CEL, (y - y0 * 16) * CEL)
    for c in P.alt:
        px, py = pos(*c)
        d.rectangle((px, py, px + CEL - 1, py + CEL - 1), fill=color_celda(P, c))
    for celdas in P.puertas.values():
        for c in celdas:
            if c in P.alt:
                px, py = pos(*c)
                d.rectangle((px + 1, py + 1, px + CEL - 2, py + CEL - 2), fill=ROJO, outline=NEGRO)
    for X, Y in P.salas:
        px, py = pos(X * 16, Y * 16)
        d.rectangle((px, py, px + 16 * CEL, py + 16 * CEL), outline=BORDE)
    for (x, y), h in P.alt.items():
        px, py = pos(x, y)
        for dx, dy in VECINOS:
            n = (x + dx, y + dy)
            if n in P.alt and abs(P.alt[n] - h) < 2 and (n in P.andable) == ((x, y) in P.andable):
                continue
            if dx == 1:
                d.line((px + CEL, py, px + CEL, py + CEL), fill=NEGRO, width=2)
            elif dx == -1:
                d.line((px, py, px, py + CEL), fill=NEGRO, width=2)
            elif dy == 1:
                d.line((px, py + CEL, px + CEL, py + CEL), fill=NEGRO, width=2)
            else:
                d.line((px, py, px + CEL, py), fill=NEGRO, width=2)
    for ((X, Y), (X2, Y2)), tramos in P.pasos.items():
        rayas = P.tipo[((X, Y), (X2, Y2))] == 'sin enlace'
        for t in tramos:
            for a, b in t:
                px, py = pos(*b)
                if X2 != X:
                    d.rectangle((px - 2, py, px + 1, py + CEL), fill=VERDE)
                    if rayas:
                        d.rectangle((px - 2, py + CEL // 2, px + 1, py + CEL), fill=NEGRO)
                else:
                    d.rectangle((px, py - 2, px + CEL, py + 1), fill=VERDE)
                    if rayas:
                        d.rectangle((px + CEL // 2, py - 2, px + CEL, py + 1), fill=NEGRO)
    for (X, Y), s in P.salas.items():
        px, py = pos(X * 16, Y * 16)
        t = f'{s["sala"]:02X}h'
        tw = ancho_texto(t, 2)
        texto(img, px + 8 * CEL - tw // 2, py + 8 * CEL - 10, t, BLANCO if (X, Y) in P.accesible else C[12], 2, NEGRO)
        if (X, Y) not in P.accesible or s['sala'] in VACIADAS:
            t = ('vaciada en 64K' if s['sala'] in VACIADAS else 'macizo') + \
                ('' if (X, Y) in P.accesible else ', sin acceso')
            texto(img, px + 8 * CEL - ancho_texto(t) // 2, py + 8 * CEL + 12, t, C[12], 1, NEGRO)
        for c in sorted(P.espejo):
            if (c[0] >> 4, c[1] >> 4) == (X, Y):
                texto(img, pos(*c)[0] + CEL + 2, pos(*c)[1], 'espejo', BLANCO, 1, ROJO)
                break
        sx, sy = esquina_camara(s, X, Y)
        cx = px + (16 * CEL - 4 if sx > 0 else 4)
        cy = py + (16 * CEL - 4 if sy > 0 else 4)
        d.polygon([(cx, cy), (cx - sx * 14, cy), (cx, cy - sy * 14)], fill=BLANCO, outline=NEGRO)
        for kind in ('sube', 'baja'):
            if ((P.f, X, Y), kind) not in numero:
                continue
            nn, otro = numero[((P.f, X, Y), kind)]
            celdas = [(x, y) for k2, x, y, h in s['escaleras'] if k2 == kind]
            qx, qy = pos(sum(c[0] for c in celdas) / len(celdas), min(c[1] for c in celdas))
            t = f'E{nn}{"↑" if kind == "sube" else "↓"}{S[otro]["sala"]:02X}h'
            tw = ancho_texto(t)
            texto(img, max(px + 2, min(px + 16 * CEL - tw - 2, int(qx) - tw // 2)), max(py + 2, int(qy) - 16), t,
                  BLANCO, 1, PURPURA)
    return img


def pantalla(P, S, X, Y, numero):
    s = P.salas[(X, Y)]
    img = s['img'].copy()
    d = ImageDraw.Draw(img)
    puntos_esc = {}
    for kind, x, y, h in s['escaleras']:
        # projected one height step inside the floor shown: 0Dh is already the floor above, 01h below
        px, py = proyecta(s, X, Y, x + 0.5, y + 0.5, 0x0C if kind == 'sube' else 0x02)
        if 0 <= px < W and 0 <= py < H:
            d.rectangle((px - 3, py - 2, px + 3, py + 2), fill=PURPURA)
            puntos_esc.setdefault(kind, []).append((px, py))
    for kind, puntos in puntos_esc.items():
        if ((P.f, X, Y), kind) not in numero:
            continue
        n, otro = numero[((P.f, X, Y), kind)]
        mx = sum(p[0] for p in puntos) // len(puntos)
        my = min(p[1] for p in puntos)
        t = f'E{n} {"↑" if kind == "sube" else "↓"} {NOMBRE[otro[0]]} {S[otro]["sala"]:02X}h'
        tw = ancho_texto(t)
        texto(img, int(max(2, min(W - tw - 2, mx - tw // 2))), int(max(2, my - 18)), t, BLANCO, 1, PURPURA)
    for (X2, Y2), (dx, dy), tipo, tramos in P.salidas((X, Y)):
        for t in tramos:
            puntos = []
            for x, y in t:
                h = P.alt[(x, y)]
                if dx:
                    ex = x + (dx > 0)
                    puntos.append((proyecta(s, X, Y, ex, y, h), proyecta(s, X, Y, ex, y + 1, h)))
                else:
                    ey = y + (dy > 0)
                    puntos.append((proyecta(s, X, Y, x, ey, h), proyecta(s, X, Y, x + 1, ey, h)))
            for a, b in puntos:
                d.line((a, b), fill=NEGRO, width=5)
            for i, (a, b) in enumerate(puntos):
                d.line((a, b), fill=VERDE if tipo != 'sin enlace' or i % 2 == 0 else NEGRO, width=3)
        t = max(tramos, key=len)
        x, y = t[len(t) // 2]
        px, py = proyecta(s, X, Y, x + 0.5, y + 0.5, P.alt[(x, y)])
        t = f'→{P.salas[(X2, Y2)]["sala"]:02X}h' + (' espejo' if tipo == 'espejo' else '')
        tw = ancho_texto(t)
        qx = int(max(1, min(W - tw - 1, px - tw // 2)))
        qy = int(max(1, min(H - 13, py - 16)))
        d.rectangle((qx - 1, qy - 1, qx + tw, qy + 12), fill=NEGRO)
        texto(img, qx, qy, t, VERDE, 1, VERDE_OSC)
    return img


def brujula(img, x, y, s, X, Y):
    d = ImageDraw.Draw(img)
    d.rectangle((x, y, x + 34, y + 13), fill=NEGRO)
    cx, cy = X * 16 + 8, Y * 16 + 8
    a = proyecta(s, X, Y, cx, cy, 0)
    b = proyecta(s, X, Y, cx, cy - 1, 0)
    vx, vy = b[0] - a[0], b[1] - a[1]
    n = (vx * vx + vy * vy) ** 0.5
    vx, vy = vx / n * 5.5, vy / n * 5.5
    flecha(d, x + 7 - vx, y + 7 - vy, x + 7 + vx, y + 7 + vy, BLANCO, 3)
    texto(img, x + 14, y - 1, 'N', BLANCO)


def main(destino):
    sim = simbolos()
    S, mem = salas()
    inicio, puertas, con_puerta = datos(S, mem, sim)
    plantas = []
    for f in range(3):
        plantas.append(Planta(f, S, inicio, puertas, con_puerta))
    escaleras = []
    for (f, X, Y), s in sorted(S.items()):
        for kind, x, y, h in s['escaleras']:
            dest = (f + 1, x >> 4, y >> 4)
            if kind == 'sube' and dest in S and not any(e[0] == (f, X, Y) for e in escaleras):
                escaleras.append(((f, X, Y), dest))
    numero = {}
    for i, (a, b) in enumerate(escaleras):
        numero[(a, 'sube')] = (i + 1, b)
        numero[(b, 'baja')] = (i + 1, a)
    sin_enlace = []
    for P in plantas:
        for (X, Y), s in P.salas.items():
            for bit, (dx, dy) in enumerate(VECINOS):
                v = (X + dx, Y + dy)
                geo = (((X, Y), v) in P.pasos) or ((v, (X, Y)) in P.pasos)
                if v in P.accesible and (X, Y) in P.accesible and not geo and not s['enlaces'] >> bit & 1:
                    print(f'aviso: planta {P.f} sala {s["sala"]:02X}h -> {P.salas[v]["sala"]:02X}h: enlace abierto, '
                          'no hay paso')
        sin_enlace += [f'{P.salas[a]["sala"]:02X}h-{P.salas[b]["sala"]:02X}h' for (a, b), k in P.tipo.items()
                       if k == 'sin enlace']
        print(f'{NOMBRE[P.f]}: ' + ', '.join(f'{k} {n}' for k, n in sorted(Counter(P.tipo.values()).items())) +
              '; sin acceso: ' + ' '.join(f'{P.salas[XY]["sala"]:02X}h' for XY in P.salas if XY not in P.accesible))

    planos = [plano(P, S, numero) for P in plantas]
    rejillas = []
    for P in plantas:
        xs = [X for X, Y in P.salas]
        ys = [Y for X, Y in P.salas]
        rejillas.append((min(xs), min(ys), (max(xs) - min(xs) + 1) * PASO_X, (max(ys) - min(ys) + 1) * PASO_Y))
    ancho = max(max(40 + r[2] for r in rejillas), 40 + planos[0].width + 20,
                max(40 + rejillas[f][2] + 40 + planos[f].width + 20 for f in (1, 2)))
    secciones = []
    y = 300 + 14 * len(escaleras)
    for f in range(3):
        al_lado = f > 0
        secciones.append((y, al_lado))
        y += (40 + max(rejillas[f][3], planos[f].height + 30) + 30) if al_lado else \
             (40 + planos[f].height + 50 + rejillas[f][3] + 30)
    L = Image.new('RGB', (ancho, y + 20), FONDO)
    d = ImageDraw.Draw(L)

    texto(L, 18, 18, 'La Abadia del Crimen en el Commodore 64: mapa de todas las pantallas', TITULO, 2)
    lineas = (
        'Es la version de 64 KiB del CPC (la de cinta), pasada al C64. Cada planta tiene un plano visto desde arriba, '
        'con el norte arriba (el de MicroHobby 162 lo tiene a la derecha),',
        'y debajo todas sus pantallas tal como las dibuja el propio codigo 6502 del juego, con sus colores (paleta '
        'colodore de VICE).',
        'Cada sala tiene su propia camara: su decorado esta guardado ya dibujado asi, y por eso dos pantallas vecinas '
        'nunca se ven desde el mismo lado. El plano es lo que las une.',
        'El plano sale de las alturas por las que andan los personajes (16x16 casillas cada sala); las pantallas van en '
        'la misma rejilla de salas (X a la derecha, Y hacia abajo).')
    for i, l in enumerate(lineas):
        texto(L, 18, 50 + 12 * i, l, LETRA)
    ly = 112
    texto(L, 18, ly, 'Plano:', TITULO)
    muestras = [(RAMPA[0], 'suelo, altura 0-1'), (RAMPA[2], '2-3'), (RAMPA[4], '4-5'), (RAMPA[6], '6-7'),
                (RAMPA[8], '8-9'), (RAMPA[10], '10-11'), (RAMPA[12], '12-13'), (OBSTACULO, 'no se puede pisar'),
                (MURO, 'muro (14-15)'), (ROJO, 'puerta, espejo'), (PURPURA, 'cambio de planta'),
                (VERDE, 'paso entre salas')]
    x = 80
    for color, t in muestras:
        d.rectangle((x, ly + 1, x + 11, ly + 11), fill=color, outline=NEGRO)
        x += 16
        w, _ = texto(L, x, ly, t, LETRA)
        x += w + 12
    d.polygon([(x + 12, ly + 12), (x, ly + 12), (x + 12, ly)], fill=BLANCO, outline=NEGRO)
    texto(L, x + 16, ly, 'esquina desde la que mira la camara', LETRA)
    notas = [
        'Lineas negras: escalones de 2 o mas (no se pueden subir ni bajar) y bordes; gris: limites de las salas. '
        'Alturas sobre la base de la planta (0, 0Bh o 16h).',
        'El espejo de la biblioteca se abre pulsando Q y R a la vez en el escalon bueno de los tres que tiene delante; '
        'los otros dos son una trampa. Esta dibujado abierto.',
        'Salas "vaciada en 64K": la version de 64 KiB les quito todo el decorado y las cerro (17h, 27h, 32h, 33h, 35h, '
        '36h, 4Bh). Las demas "sin acceso" son bloques macizos, como en el juego completo.']
    if sin_enlace:
        notas.insert(1, 'Paso a trazos: la tabla de enlaces de salas lo tiene cerrado y los monjes no lo usan para ir de '
                     'una sala a otra (' + ', '.join(sin_enlace) + ').')
    for i, l in enumerate(notas):
        texto(L, 18, ly + 18 + 12 * i, l, NOTA)
    ly += 18 + 12 * len(notas) + 10
    texto(L, 18, ly, 'Pantallas:', TITULO)
    x = 106
    d.rectangle((x, ly, x + 37, ly + 13), fill=NEGRO)
    texto(L, x + 1, ly + 1, '→02h', VERDE, 1, VERDE_OSC)
    t = 'salida hacia la sala 02h, encima del umbral (raya verde) por el que se sale;'
    texto(L, x + 44, ly, t, LETRA)
    x += 44 + ancho_texto(t) + 10
    d.rectangle((x, ly + 4, x + 6, ly + 8), fill=PURPURA)
    texto(L, x + 12, ly, 'casillas donde cambia la planta (E1, E2... en los dos extremos); N: el norte.', LETRA)
    ly += 22
    texto(L, 18, ly, 'Escaleras entre plantas (las unicas):', TITULO)
    for i, (a, b) in enumerate(escaleras):
        t = (f'E{i + 1}: {NOMBRE[a[0]]}, sala {S[a]["sala"]:02X}h (X{a[1]} Y{a[2]}) ↔ {NOMBRE[b[0]]}, sala '
             f'{S[b]["sala"]:02X}h (X{b[1]} Y{b[2]})')
        texto(L, 36, ly + 16 + 14 * i, t, BLANCO, 1, PURPURA)

    for f, P in enumerate(plantas):
        ys, al_lado = secciones[f]
        texto(L, 18, ys, PLANTAS[f], TITULO, 2)
        x0, y0, rw, rh = rejillas[f]
        if al_lado:
            base_y = ys + 40
            L.paste(planos[f], (40 + rw + 40, base_y + 20))
            texto(L, 40 + rw + 40, base_y, 'Plano (norte arriba)', LETRA)
        else:
            texto(L, 40, ys + 36, 'Plano (norte arriba)', LETRA)
            L.paste(planos[f], (40, ys + 52))
            base_y = ys + 52 + planos[f].height + 30
            texto(L, 40, base_y - 4, 'Pantallas', LETRA)
            base_y += 14
        for (X, Y), s in P.salas.items():
            cx, cy = 40 + (X - x0) * PASO_X, base_y + (Y - y0) * PASO_Y
            t = f'{s["sala"]:02X}h X{X} Y{Y}' + (' (oscura)' if s['oscura'] else '') + \
                (' (vaciada)' if s['sala'] in VACIADAS else '' if (X, Y) in P.accesible else ' (sin acceso)')
            texto(L, cx - 2, cy - 2, t, LETRA)
            brujula(L, cx + W - 35, cy - 2, s, X, Y)
            L.paste(pantalla(P, S, X, Y, numero), (cx, cy + CAB))
    L.save(destino, optimize=True)
    print(f'{destino}: {L.width}x{L.height}, {len(S)} pantallas, {len(escaleras)} escaleras, '
          f'{sum(len(P.pasos) for P in plantas)} pares de salas con paso')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(AQUI, 'mapa_c64.png'))
