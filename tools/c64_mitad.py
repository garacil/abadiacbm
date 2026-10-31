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

"""Rule `trazos`: a CPC mode 1 graphic (4 pens, 320 pixels a line) halved to C64 multicolour pixels (160 a line)
keeping every stroke of the drawing (the C64 graphics must have the same shape as the PC EGA /
CPC ones, pixel for pixel, although the resolutions differ).

Each C64 pixel covers two CPC pixels and takes the pen of one of them (never a third pen: no blending, no
dithering).  A line of the drawing is a sequence of runs (a run = consecutive pixels of one pen).  The choice of
pixels for a whole line is the one of least cost (PESOS), where
  * a run that gets no C64 pixel is LOST.  No pen is assumed to be the stroke or the fill (Guillermo is orange with
    black strokes, the monks are black with orange strokes): what a run is comes from its neighbours in the line.
    An opaque run is a STROKE (a line, a fold, an eye, an outline) and losing it costs PESOS["trazo"] (100, plus
    its contrast with its neighbours, up to 1.9, to break ties), except a run of ONE pixel whose pen lies between
    its two opaque neighbours in brightness (black-orange-yellow or the reverse: a step of shading, not a line),
    which costs PESOS["sombra"] (0.4): dropped whenever keeping it would narrow a stroke.  An inner transparent run
    (a gap between two parts of the figure) costs PESOS["hueco"] (60); the transparent runs at the ends of a line
    are the background and cost nothing;
  * a run that survives costs PESOS["ancho"] x |pixels given - its length / 2|: its width stays as near as the half
    resolution allows (the differences come in steps of 0.5);
  * a pair with one transparent and one opaque pixel that keeps the transparent one costs PESOS["fuera"] (0.1): the
    silhouette grows outward on both sides rather than shifting, and no drawn pixel is dropped for the background;
  * a pixel whose pen differs from the C64 pixel just above it, when that pen was one of the pair's two, costs
    PESOS["vertical"] (0.25): rows are converted from the top and this term only breaks ties, so edges between two
    long areas stay vertically coherent instead of always leaning to the left pixel.
The least-cost choice is found exactly by dynamic programming over the pairs of the line (the cost of a run depends
only on the choices in its own pairs, and a pair belongs to at most two runs, so the state is the count of the run
still open); equal costs are broken by preferring the left pixel.  Deterministic: a pure function of the pens.

A 1-pixel outline or fold therefore always survives, 2 pixels wide (the natural width at half resolution); a run
of 5 keeps 2 or 3; the colours are the C64's nearest (src/c64/datos/paleta.tsv), which is a different matter.

    c64_mitad.trazos(rows, pesos=None) -> rows of C64 pens (half the length), rows = lists of CPC pens (0-3) per line
    c64_mitad.compara(rows, mc) -> dict of measures of the C64 version against the CPC one (see compara)
"""

PESOS = {"trazo": 100.0, "hueco": 60.0, "sombra": 0.4, "ancho": 1.0, "fuera": 0.1, "vertical": 0.25}
LUZ = {0: 0.70, 1: 0.59, 2: 0.94, 3: 0.0}  # brightness of the pens: cyan (when opaque, in the tiles), orange, pastel
                                          # yellow, black (CPC inks, Rec. 601)
# tr: the transparent pen of the graphic: 0 for the characters, the faces, the door and the objects; the tiles 0Bh-7Fh
# have pen 2 transparent and 80h-D9h pen 1 (src/c64/NOTAS_GRAFICOS.md); None: no transparent pen (opaque tiles 01h-0Ah)


def tramos(row):
    """The runs of a line: (pen, start, end) with end exclusive."""
    out = []
    s = 0
    for x in range(1, len(row) + 1):
        if x == len(row) or row[x] != row[s]:
            out.append((row[s], s, x))
            s = x
    return out


def perdida(runs, i, largo, pesos, tr=0):
    """The cost of losing run i of the line."""
    pen, s, e = runs[i]
    if pen == tr:
        return 0.0 if s == 0 or e == largo else pesos["hueco"]
    vecinos = [runs[j][0] for j in (i - 1, i + 1) if 0 <= j < len(runs) and runs[j][0] != tr]
    if e - s == 1 and len(vecinos) == 2:
        a, b, c = LUZ[vecinos[0]], LUZ[pen], LUZ[vecinos[1]]
        if a < b < c or a > b > c:
            return pesos["sombra"]
    return pesos["trazo"] + sum(abs(LUZ[pen] - LUZ[q]) for q in vecinos)


def trazos_fila(row, arriba=None, pesos=None, tr=0):
    """One line: CPC pens (even length) -> C64 pens (half length), the least-cost choice; arriba = the C64 line
    just above (already converted), for the vertical term; tr = the transparent pen."""
    pesos = pesos or PESOS
    n = len(row) // 2
    runs = tramos(row)
    idx = [0] * len(row)
    for i, (_, s, e) in enumerate(runs):
        for x in range(s, e):
            idx[x] = i

    def cierre(i, c):
        pen, s, e = runs[i]
        return perdida(runs, i, len(row), pesos, tr) if c == 0 else pesos["ancho"] * abs(c - (e - s) / 2)

    # state: pixels so far of the run still open after the pair -> (cost, choices so far)
    estados = {0: (0.0, ())}
    for k in range(n):
        a, b = row[2 * k], row[2 * k + 1]
        ia, ib = idx[2 * k], idx[2 * k + 1]
        nuevo = {}
        for c, (coste, elec) in estados.items():
            for lado in (("L",) if a == b else ("L", "R")):
                pen = a if lado == "L" else b
                extra = 0.0
                if a != b:
                    if pen == tr:
                        extra += pesos["fuera"]
                    if arriba is not None and arriba[k] in (a, b) and arriba[k] != pen:
                        extra += pesos["vertical"]
                if ia == ib:
                    c2, coste2 = c + 1, coste + extra
                    if runs[ia][2] == 2 * k + 2:
                        coste2, c2 = coste2 + cierre(ia, c2), 0
                else:
                    coste2 = coste + extra + cierre(ia, c + (1 if lado == "L" else 0))
                    c2 = 1 if lado == "R" else 0
                    if runs[ib][2] == 2 * k + 2:
                        coste2, c2 = coste2 + cierre(ib, c2), 0
                cand = (coste2, elec + (lado,))
                if c2 not in nuevo or cand < nuevo[c2]:
                    nuevo[c2] = cand
        estados = nuevo
    _, elec = min(estados.values())
    return [row[2 * k + (1 if lado == "R" else 0)] for k, lado in enumerate(elec)]


def trazos(rows, pesos=None, tr=0):
    out = []
    for r in rows:
        out.append(trazos_fila(r, out[-1] if out else None, pesos, tr))
    return out


def doble(mc):
    """A C64 graphic at the CPC's resolution (each pixel twice), to compare."""
    return [[p for p in r for _ in (0, 1)] for r in mc]


def compara(rows, mc, tr=0):
    """Measures of a C64 version (mc, half width) against its CPC/PC source (rows):
    pixels: differing pixels when the C64 graphic is doubled back to the CPC's width, and the total;
    silueta: pixels where one is transparent (pen 0) and the other is not;
    perdidos: runs of the source (black, inner gaps, yellow, orange) with no pixel in the C64 version, by kind;
    tramos: runs of the source, by kind (to read perdidos against)."""
    d = doble(mc)
    h, w = len(rows), len(rows[0])
    pix = sum(1 for y in range(h) for x in range(w) if rows[y][x] != d[y][x])
    sil = sum(1 for y in range(h) for x in range(w) if (rows[y][x] == tr) != (d[y][x] == tr))
    perdidos, total = {}, {}
    for y in range(h):
        for pen, s, e in tramos(rows[y]):
            kind = {3: "negro", 2: "amarillo", 1: "naranja", 0: "cian"}.get(pen)
            if pen == tr:
                if s == 0 or e == w:
                    continue
                kind = "hueco"
            total[kind] = total.get(kind, 0) + 1
            if not any(mc[y][k] == pen for k in range(s // 2, (e - 1) // 2 + 1)):
                perdidos[kind] = perdidos.get(kind, 0) + 1
    return dict(pixels=pix, total=h * w, silueta=sil, perdidos=perdidos, tramos=total)


def cuerpo(rows, pesos=None):
    """The body of a character for the hardware-sprite build (the black strokes as hires
    hardware sprites over the multicolour body): C64 pens at half width where NO black is dropped to the bitmap's
    account: in a pair with one black pixel the body takes the other pixel (the sprite draws the black one exactly),
    both black stays black, and a pair without black takes the rule trazos' choice (the only pixels that differ from
    the PC: orange/yellow pairs and half-transparent pairs without black)."""
    out = []
    for row in rows:
        fila = list(row)
        for k in range(len(row) // 2):
            a, b = row[2 * k], row[2 * k + 1]
            if a == 3 and b != 3:
                fila[2 * k] = b
            elif b == 3 and a != 3:
                fila[2 * k + 1] = a
        out.append(trazos_fila(fila, out[-1] if out else None, pesos))
    return out


def pen_trazo(rows, tr=0):
    """The stroke pen of a graphic: the opaque pen with the most one-pixel runs (ties: the darkest); black for the
    protagonists and the faces, orange for the monks' black robes."""
    cuenta = {0: 0, 1: 0, 2: 0, 3: 0}
    for row in rows:
        for pen, s, e in tramos(row):
            if pen != tr and e - s == 1:
                cuenta[pen] += 1
    return max((3, 2, 1, 0), key=lambda p: (p != tr, cuenta[p], -LUZ[p]))


def contorno(rows, pen=None, pesos=None, tr=0):
    """Continuous outer contours (the quality of Darksoft's conversions): every stroke pixel that touches the
    outside (a transparent pixel to its left, right, above or below, or the edge of the graphic) is kept whole: its
    pair becomes the stroke pen; the inside of the figure is then converted by the rule trazos (the folds and
    highlights at the least cost).  A pure function of the pens; pen = the stroke pen (pen_trazo(rows) when None)."""
    pen = pen_trazo(rows, tr) if pen is None else pen
    h, w = len(rows), len(rows[0])
    fuera = lambda y, x: y < 0 or y >= h or x < 0 or x >= w or rows[y][x] == tr
    forzadas = []
    for y in range(h):
        fila = list(rows[y])
        for k in range(w // 2):
            for x in (2 * k, 2 * k + 1):
                if rows[y][x] == pen and (fuera(y, x - 1) or fuera(y, x + 1) or fuera(y - 1, x) or fuera(y + 1, x)):
                    fila[2 * k] = fila[2 * k + 1] = pen
                    break
        forzadas.append(fila)
    return trazos(forzadas, pesos, tr)


def negro(rows):
    """The black layer of a character at the PC's full width: per line, one bit a pixel (1 = pen 3), the leftmost
    pixel in bit 7 of the first byte; a line of 4w pixels packed in 4w bits (a 20-pixel line is 2.5 bytes: two lines
    in 5 bytes, the second starting at the low nibble)."""
    bits = []
    for row in rows:
        bits += [1 if p == 3 else 0 for p in row]
    while len(bits) % 8:
        bits.append(0)
    return bytes(sum(bit << (7 - i) for i, bit in enumerate(bits[k:k + 8])) for k in range(0, len(bits), 8))
