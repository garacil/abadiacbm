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

"""Pixel editor of the C64 characters beside their PC EGA source (a program that shows
the characters' graphics of the CPC / PC EGA on one side and the Commodore 64's on the other, to edit them by hand
pixel by pixel, every sprite of each character, switching from one to another, with save and undo; a blinking
pixel-sized pointer, the colour chosen with the digits, SPACE paints, O left, P right, Q up, A down).

    c64_editor.py [--editados FILE] [--hoja OUT.png [--grupo NAME]] [--lista] [--escala N]

Left: the PC EGA graphic (the CPC inks) decoded as the PC game draws it (c64_compara_pc.py, from the read-only PC
reference); right: the C64 graphic at the same height, each C64 pixel twice as wide (multicolour).  The C64 side
starts as the build makes it (c64_graficos.py: the rule trazos on the tape image's graphic, one frame at a time)
with the hand-edited lines of src/c64/datos/editados64.txt put in; editing changes only the C64 side.  Saving writes
editados64.txt with the lines that differ from the rule (the format of retoques64.txt: the graphic's CPC address,
the line, one character a C64 pixel: . transparent, o orange, Y yellow, # black); the normal build applies it, so
`src/c64/presentacion/pruebas/disco_prueba/construye.sh` and `src/c64/ingles/construye.sh` make the disks with the edits.  The characters: Guillermo
(6 frames), Adso (6), the monks' faces (7 x 2) and robes (6).  The game flips Guillermo, Adso and the faces in place
and reads the robes backwards: the edited graphic is the unflipped one.  The scenery (the background
graphics, to be retouched by hand too): the 208 tiles 01h-D9h but the 9 object slots, 16 x 8 CPC pixels
each, the rule detalle (c64_sala.py) on the tape image, which is the left side here (the PC reference has no tile
decoder yet); tiles 01h-0Ah are opaque, 0Bh-7Fh have pen 2 (yellow) transparent and 80h-D9h pen 1 (orange).

Keys: O P Q A (and the arrows) move the cursor; Space paints the pen; 0 1 2 3 choose the pen (transparent, orange,
yellow, black); U or Ctrl+Z undo, Ctrl+Y or Ctrl+Shift+Z redo; S or Ctrl+S save; N or PgDn next sprite, M or PgUp
previous; Tab / Shift+Tab next / previous character; R the line back to the rule, Shift+R the whole sprite; D the
difference marks (red: where the C64 pixel differs from the PC pixel under it); + and - zoom; H this help.  Animation
(the option to animate it, and the animation's speed; Guillermo and Adso): V plays / stops the
game's own walk cycle, read from the tape's animation tables 2CF0h / 2D10h as chr_select_frame uses them (counter
n = 0..3 -> entries 0-3 for the camera-relative orientations 0 and 3, entries 4-7 for 1 and 2; orientations 2 and 3
are shown mirrored, as the game flips the graphic in place; V starts the cycle of the sprite on the screen, frames 0-2
or 3-5, from that sprite); G changes the orientation; , and . slow down / speed
up (40-1000 ms a frame).  Editing while a mirrored frame is shown edits the stored, unmirrored graphic.  Mouse:
left button moves the cursor and paints, right button only moves it.  --hoja: a contact sheet PC | C64 of a group
(or all), no window, for checks; --lista: the graphics and their edited lines.
"""
import argparse
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
sys.path.insert(0, AQUI)
import c64_graficos as G          # noqa: E402  (imagen, editados, LETRA)
import c64_mitad as M             # noqa: E402  (trazos, compara)
import c64_compara_pc as K        # noqa: E402  (the PC decoding and the groups; it chdirs to the PC reference and back)

CARACTER = {v: k for k, v in G.LETRA.items()}          # pen -> . o Y #
NOMBRE_PEN = {0: "cian", 1: "naranja", 2: "amarillo", 3: "negro"}
GRIS = (60, 60, 72)                                      # the transparent pen on the screen
# the inks: the PC EGA option's (= the CPC's day inks) and VICE's colodore palette for the C64 colours of
# src/c64/datos/paleta.tsv (cyan 3, orange 8, yellow 7, black 0), read from /usr/share/vice/C64/colodore.vpl
import c64_colores as CO          # noqa: E402
_PAL = CO.vpl("/usr/share/vice/C64/colodore.vpl")
INK_PC = {0: (0, 128, 128), 1: (255, 128, 0), 2: (255, 255, 128), 3: (0, 0, 0)}
INK_C64 = {0: _PAL[3], 1: _PAL[8], 2: _PAL[7], 3: _PAL[0]}


def tintas(tr):
    """(PC inks, C64 inks) with the transparent pen tr (None: opaque) shown grey."""
    return ({p: (GRIS if p == tr else c) for p, c in INK_PC.items()}, {p: (GRIS if p == tr else c) for p, c in INK_C64.items()})


def transparente_baldosa(n):
    """The transparent pen of tile n (src/c64/NOTAS_GRAFICOS.md): none below 0Bh, pen 2 up to 7Fh, pen 1 from 80h."""
    return None if n < 0x0B else 2 if n < 0x80 else 1
TAPE = os.path.join(RAIZ, "data", "cpc64", "juego", "ram.bin")
TABLAS_ANIMACION = {"Guillermo": 0x2CF0, "Adso": 0x2D10}     # 8 entries of (pointer, width, height), chr_select_frame
CABECERA = ("# Hand-edited C64 lines of the characters (tools/c64_editor.py); c64_graficos.py puts them over\n"
            "# the rule trazos in the normal build.  ADDRESS (CPC, the graphic's first line) LINE (from 0) PIXELS (one\n"
            "# character a C64 pixel: . transparent, o orange, Y yellow, # black).  Only lines that differ from the rule.\n")


class Grafico:
    """One graphic: its PC rows (4w pens a line), its tape rows, the rule's C64 rows (2w) and the edited C64 rows."""

    def __init__(self, nombre, personaje, bloque, pa, ca, w, h, pc, cpc, regla, tr=0, fuente="PC EGA (tintas CPC)"):
        self.nombre, self.personaje, self.bloque, self.pa, self.ca, self.w, self.h = nombre, personaje, bloque, pa, ca, w, h
        self.pc, self.cpc, self.regla, self.tr, self.fuente = pc, cpc, regla, tr, fuente
        self.pc_vs_cpc = sum(1 for y in range(h) for x in range(4 * w) if pc[y][x] != cpc[y][x])
        self.c64 = [list(r) for r in regla]
        self.tinta_pc, self.tinta_c64 = tintas(tr)
        self.animacion = None                            # {orientation: [(Grafico, mirrored), ...]} for Guillermo and Adso

    def lineas_editadas(self):
        return [y for y in range(self.h) if self.c64[y] != self.regla[y]]

    def medidas(self):
        return M.compara(self.pc, self.c64, -1 if self.tr is None else self.tr)

    def nombre_pen(self, p):
        return "transparente" if p == self.tr else NOMBRE_PEN[p]


def carga_personajes():
    """[(character, [Grafico, ...])] as the build converts them: the rule trazos on the tape image, frame by frame."""
    ds = K.ds_inicial()
    tablas = [ds[0xD968 + 0x100 * i:0xD968 + 0x100 * i + 0x100] for i in range(6)]
    m = open(TAPE, "rb").read()

    def haz(nombre, personaje, partes):
        (bloque, pa, ca, w, h), = partes
        cpc = G.imagen(m, ca, w, h)
        return Grafico(nombre, personaje, bloque, pa, ca, w, h, K.pc_sprite(ds, tablas, pa, w, h), cpc, M.trazos(cpc))

    out = []
    for quien in ("Guillermo", "Adso"):
        gs = [haz(n, quien, p) for n, p in K.PROTAGONISTAS if n.startswith(quien)]
        por_ca = {g.ca: g for g in gs}
        tabla = TABLAS_ANIMACION[quien]
        entradas = [(m[q] | m[q + 1] << 8, m[q + 2], m[q + 3]) for q in range(tabla, tabla + 32, 4)]
        for ptr, w, h in entradas:
            if ptr not in por_ca or (por_ca[ptr].w, por_ca[ptr].h) != (w, h):
                raise SystemExit(f"{quien}: animation entry {ptr:04X} {w}x{h} is not one of the frames")
        # the cycle of each camera-relative orientation o: n = 0..3 -> entry 4 ((((o + 1) & 2) << 1) | n) / 4,
        # mirrored when o >> 1 is 1 (chr_select_frame, chr_show_frame)
        ciclo = {}
        for o in range(4):
            base = (((o + 1) & 2) << 1)
            ciclo[o] = [(por_ca[entradas[base + n][0]], bool(o >> 1)) for n in range(4)]
        for g in gs: g.animacion = ciclo
        out.append((quien, gs))
    out.append(("Monjes · caras", [haz(n, "Monjes · caras", p) for n, p in K.CARAS]))
    out.append(("Monjes · hábitos", [haz(n, "Monjes · hábitos", p) for n, p in K.HABITOS]))
    baldosas = []
    for n in range(1, G.NBALDOSAS):                 # the scenery: the rule detalle per tile, as the build
        if n in G.SLOTS_OBJETOS: continue
        ca = 0x8300 + 32 * n
        cpc = G.imagen(m, ca, 4, 8)
        baldosas.append(Grafico(f"Baldosa {n:02X}", "Escenario", "baldosas", None, ca, 4, 8, cpc, cpc, G.mitad(cpc, "detalle"),
                                transparente_baldosa(n), "CPC (cinta)"))
    out.append(("Escenario", baldosas))
    return out


def todos(personajes):
    return [g for _, gs in personajes for g in gs]


def carga_editados(personajes, path):
    """Puts the file's lines into the graphics; returns the addresses of the file that match no graphic."""
    ed = G.editados(path)
    por_ca = {g.ca: g for g in todos(personajes)}
    for ca, lineas in ed.items():
        g = por_ca.get(ca)
        if g is None: continue
        for y, pens in lineas.items():
            if 0 <= y < g.h and len(pens) == 2 * g.w: g.c64[y] = list(pens)
    return sorted(set(ed) - set(por_ca))


def texto_editados(personajes):
    lineas = [CABECERA.rstrip("\n")]
    for g in sorted(todos(personajes), key=lambda g: g.ca):
        for y in g.lineas_editadas():
            lineas.append(f"{g.ca:04X} {y} {''.join(CARACTER[p] for p in g.c64[y])}")
    return "\n".join(lineas) + "\n"


def guarda_editados(personajes, path):
    """One atomic write; the same bytes for the same edits."""
    temporal = path + ".tmp"
    with open(temporal, "w") as f: f.write(texto_editados(personajes))
    os.replace(temporal, path)


def hoja(personajes, ruta, grupo=None, escala=3):
    """Contact sheet PC | C64 (edited) of one character or all, without a window (PIL)."""
    from PIL import Image, ImageDraw
    piezas = [(g, K.lamina(g.pc, g.tinta_pc, escala), K.lamina(M.doble(g.c64), g.tinta_c64, escala))
              for quien, gs in personajes if grupo is None or quien == grupo for g in gs]
    if not piezas: raise SystemExit(f"no character called {grupo}")
    por_fila = 14 if len(piezas) > 12 else 6
    ancho = max(a.width + b.width for _, a, b in piezas) + 4
    alto = max(a.height for _, a, _ in piezas) + 26
    filas = (len(piezas) + por_fila - 1) // por_fila
    im = Image.new("RGB", (16 + por_fila * (ancho + 14), 44 + filas * (alto + 14)), (36, 36, 44))
    d = ImageDraw.Draw(im)
    d.text((16, 8), f"{piezas[0][0].fuente} | C64 editado   x{escala}   {grupo or 'todos'}", fill=(255, 220, 120))
    d.text((16, 22), "C64 con la paleta colodore; gris = transparente; líneas editadas marcadas en amarillo", fill=(150, 150, 165))
    for i, (g, a, b) in enumerate(piezas):
        x0 = 16 + (i % por_fila) * (ancho + 14); y0 = 44 + (i // por_fila) * (alto + 14)
        im.paste(a, (x0, y0)); im.paste(b, (x0 + a.width + 4, y0))
        for y in g.lineas_editadas():
            d.rectangle((x0 + a.width + 4 + b.width + 1, y0 + y * escala, x0 + a.width + 4 + b.width + 2, y0 + (y + 1) * escala - 1), fill=(255, 220, 0))
        d.text((x0, y0 + a.height + 3), g.nombre + (f"  PC!=CPC {g.pc_vs_cpc}" if g.pc_vs_cpc else "") + (f"  ed {len(g.lineas_editadas())}" if g.lineas_editadas() else ""), fill=(225, 225, 225))
    im.save(ruta)
    return im.size


# --------------------------------------------------------------------------- the window
def ventana(personajes, path, escala):
    from PySide6 import QtCore, QtGui, QtWidgets

    Qt = QtCore.Qt
    colores = {}

    def tinta(g):
        """(PC, C64) QColor dicts of a graphic, cached by its transparent pen."""
        if g.tr not in colores:
            colores[g.tr] = ({p: QtGui.QColor(*c) for p, c in g.tinta_pc.items()}, {p: QtGui.QColor(*c) for p, c in g.tinta_c64.items()})
        return colores[g.tr]

    FONDO, REJILLA, EDITADA, DIF = QtGui.QColor(36, 36, 44), QtGui.QColor(52, 52, 62), QtGui.QColor(255, 220, 0), QtGui.QColor(255, 40, 40)
    MARGEN, ARRIBA, SEP = 24, 30, 48
    AYUDA = ("O P Q A / flechas: cursor · Espacio: pinta · 0 1 2 3: lápiz (cian/transparente, naranja, amarillo, negro) · "
             "U / Ctrl+Z: deshacer · Ctrl+Y: rehacer · S: guardar · N / M: sprite siguiente / anterior · Tab: personaje · "
             "R: línea a la regla, Mayús+R: sprite entero · D: marcas de diferencia · + -: zoom · "
             "V: animar / parar · G: orientación · , .: más lento / más rápido · H: ayuda")

    def imagen_c64(g, e):
        """The edited C64 graphic as a QImage, e screen pixels a C64 line (2e wide)."""
        im = QtGui.QImage(4 * g.w * e, g.h * e, QtGui.QImage.Format.Format_RGB32)
        p = QtGui.QPainter(im)
        tc = tinta(g)[1]
        for y in range(g.h):
            for k in range(2 * g.w):
                p.fillRect(2 * k * e, y * e, 2 * e, e, tc[g.c64[y][k]])
        p.end()
        return im

    class Pintar(QtGui.QUndoCommand):
        def __init__(self, editor, g, cambios, texto):
            super().__init__(texto)
            self.editor, self.g, self.cambios = editor, g, cambios     # [(x, y, before, after)]

        def redo(self):
            for x, y, _, d in self.cambios: self.g.c64[y][x] = d
            self.editor.tras_cambio(self.g)

        def undo(self):
            for x, y, a, _ in self.cambios: self.g.c64[y][x] = a
            self.editor.tras_cambio(self.g)

    class Lienzo(QtWidgets.QWidget):
        def __init__(self, editor):
            super().__init__()
            self.editor = editor
            self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
            self.setMouseTracking(False)

        def focusNextPrevChild(self, siguiente):
            return False                                     # Tab reaches keyPressEvent (switches character)

        def geometria(self):
            g, e = self.editor.actual, self.editor.escala
            x_pc = MARGEN
            x_c64 = x_pc + 4 * g.w * e + SEP
            return g, e, x_pc, x_c64, ARRIBA

        def sizeHint(self):
            e = self.editor.escala
            w = max(4 * g.w for g in self.editor.graficos); h = max(g.h for g in self.editor.graficos)
            return QtCore.QSize(2 * MARGEN + 2 * w * e + SEP + 12, ARRIBA + h * e + MARGEN)

        def paintEvent(self, ev):
            g, e, x_pc, x_c64, y0 = self.geometria()
            p = QtGui.QPainter(self)
            p.fillRect(self.rect(), FONDO)
            tp, tc = tinta(g)
            esp = self.editor.espejo
            fx = (lambda x: 4 * g.w - 1 - x) if esp else (lambda x: x)      # screen column -> stored column (PC)
            fk = (lambda k: 2 * g.w - 1 - k) if esp else (lambda k: k)      # the same for the C64 pixels
            p.setPen(QtGui.QColor(255, 220, 120))
            p.drawText(x_pc, y0 - 10, f"{g.fuente}  {'' if g.pa is None else f'{g.pa:04X}  '}{4 * g.w}x{g.h}" + ("  ESPEJO" if esp else ""))
            p.drawText(x_c64, y0 - 10, f"C64 (colodore)  {g.ca:04X}  {2 * g.w}x{g.h} píxeles dobles"
                       + ("" if g.tr is None else f"  transparente: {NOMBRE_PEN[g.tr]} ({g.tr})") + ("  ESPEJO" if esp else ""))
            for y in range(g.h):
                for x in range(4 * g.w):
                    p.fillRect(x_pc + x * e, y0 + y * e, e, e, tp[g.pc[y][fx(x)]])
                for k in range(2 * g.w):
                    p.fillRect(x_c64 + 2 * k * e, y0 + y * e, 2 * e, e, tc[g.c64[y][fk(k)]])
            if e >= 6:                                       # the grids
                p.setPen(REJILLA)
                for x in range(4 * g.w + 1):
                    p.drawLine(x_pc + x * e, y0, x_pc + x * e, y0 + g.h * e)
                    if x % 2 == 0: p.drawLine(x_c64 + x * e, y0, x_c64 + x * e, y0 + g.h * e)
                for y in range(g.h + 1):
                    p.drawLine(x_pc, y0 + y * e, x_pc + 4 * g.w * e, y0 + y * e)
                    p.drawLine(x_c64, y0 + y * e, x_c64 + 4 * g.w * e, y0 + y * e)
            for y in g.lineas_editadas():                    # the edited lines: a yellow bar at the right
                p.fillRect(x_c64 + 4 * g.w * e + 4, y0 + y * e, 5, e, EDITADA)
            if self.editor.marcas:                           # red: the half of the C64 pixel that differs from the PC
                for y in range(g.h):
                    for x in range(4 * g.w):
                        if g.c64[y][fx(x) // 2] != g.pc[y][fx(x)]:
                            p.fillRect(x_c64 + x * e, y0 + y * e + e - max(2, e // 4), e, max(2, e // 4), DIF)
            cx, cy = fk(self.editor.cx), self.editor.cy       # the cursor is kept in stored coordinates
            lapiz = QtGui.QPen(Qt.GlobalColor.white if self.editor.visible else Qt.GlobalColor.black)
            lapiz.setWidth(2)
            p.setPen(lapiz)
            p.drawRect(x_c64 + 2 * cx * e + 1, y0 + cy * e + 1, 2 * e - 2, e - 2)
            lapiz = QtGui.QPen(QtGui.QColor(0, 200, 255)); lapiz.setWidth(2); p.setPen(lapiz)
            p.drawRect(x_pc + 2 * cx * e + 1, y0 + cy * e + 1, 2 * e - 2, e - 2)
            p.end()

        def pixel_en(self, pos):
            """The stored C64 pixel (x, y) under a screen point, on either side; None outside."""
            g, e, x_pc, x_c64, y0 = self.geometria()
            x, y = int(pos.x()), int(pos.y())
            k = None
            if x_c64 <= x < x_c64 + 4 * g.w * e and y0 <= y < y0 + g.h * e: k = (x - x_c64) // (2 * e)
            elif x_pc <= x < x_pc + 4 * g.w * e and y0 <= y < y0 + g.h * e: k = (x - x_pc) // (2 * e)
            if k is None: return None
            return (2 * g.w - 1 - k if self.editor.espejo else k), (y - y0) // e

        def mousePressEvent(self, ev):
            self.setFocus()
            px = self.pixel_en(ev.position())
            if px is None: return
            self.editor.cx, self.editor.cy = px
            if ev.button() == Qt.MouseButton.LeftButton: self.editor.pinta()
            else: self.editor.refresca()

        def mouseMoveEvent(self, ev):
            if ev.buttons() & Qt.MouseButton.LeftButton:
                px = self.pixel_en(ev.position())
                if px is not None and px != (self.editor.cx, self.editor.cy):
                    self.editor.cx, self.editor.cy = px
                    self.editor.pinta()

        def keyPressEvent(self, ev):
            if not self.editor.tecla(ev): ev.ignore()

    class Editor(QtWidgets.QMainWindow):
        def __init__(self):
            super().__init__()
            self.personajes, self.path, self.escala = personajes, path, escala
            self.graficos = todos(personajes)
            self.actual = self.graficos[0]
            self.cx = self.cy = 0
            self.lapiz = 3
            self.marcas = False
            self.visible = True
            self.silencio = False
            self.espejo = False                              # the shown frame is the mirrored one (animation)
            self.animando = False
            self.orientacion = 0
            self.paso = 0
            self.ms = 150
            self.reloj_anim = QtCore.QTimer(self); self.reloj_anim.timeout.connect(self.avanza)
            self.pila = QtGui.QUndoStack(self)
            self.pila.cleanChanged.connect(lambda _limpio: self.titulo())
            self.setWindowTitle("Editor de gráficos C64 · abadia64ks")
            self.ayuda = QtWidgets.QLabel(AYUDA); self.ayuda.setWordWrap(True)
            self.ayuda.setStyleSheet("color: #c8c8d2; background: #202028; padding: 4px;")
            self.combo = QtWidgets.QComboBox(); self.combo.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            for quien, _ in personajes: self.combo.addItem(quien)
            self.combo.currentIndexChanged.connect(self.personaje_cambiado)
            self.lista = QtWidgets.QListWidget(); self.lista.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            self.lista.setIconSize(QtCore.QSize(64, 76)); self.lista.setMinimumWidth(220)
            self.lista.currentRowChanged.connect(self.fila_cambiada)
            self.lienzo = Lienzo(self)
            self.area = QtWidgets.QScrollArea(); self.area.setWidget(self.lienzo); self.area.setWidgetResizable(False)
            self.area.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            izquierda = QtWidgets.QVBoxLayout(); izquierda.addWidget(self.combo); izquierda.addWidget(self.lista)
            cuerpo = QtWidgets.QHBoxLayout(); cuerpo.addLayout(izquierda); cuerpo.addWidget(self.area, 1)
            todo = QtWidgets.QVBoxLayout(); todo.addWidget(self.ayuda); todo.addLayout(cuerpo, 1)
            central = QtWidgets.QWidget(); central.setLayout(todo); self.setCentralWidget(central)
            self.reloj = QtCore.QTimer(self); self.reloj.setInterval(400); self.reloj.timeout.connect(self.parpadea); self.reloj.start()
            self.rellena_lista()
            self.resize(1500, 900)
            self.titulo(); self.estado()
            self.lienzo.setFocus()

        # -- the lists
        def indice_personaje(self, g):
            for i, (_, gs) in enumerate(self.personajes):
                if g in gs: return i, gs.index(g)
            raise ValueError(g.nombre)

        def rellena_lista(self):
            self.silencio = True
            i, j = self.indice_personaje(self.actual)
            self.combo.setCurrentIndex(i)
            self.lista.clear()
            for g in self.personajes[i][1]:
                item = QtWidgets.QListWidgetItem(QtGui.QIcon(QtGui.QPixmap.fromImage(imagen_c64(g, 4 if g.h <= 8 else 2))), g.nombre)
                self.lista.addItem(item)
            self.lista.setCurrentRow(j)
            self.silencio = False

        def icono(self, g):
            i, j = self.indice_personaje(g)
            if i == self.combo.currentIndex():
                self.lista.item(j).setIcon(QtGui.QIcon(QtGui.QPixmap.fromImage(imagen_c64(g, 4 if g.h <= 8 else 2))))

        def personaje_cambiado(self, i):
            if self.silencio or i < 0: return
            self.muestra(self.personajes[i][1][0])

        def fila_cambiada(self, j):
            if self.silencio or j < 0: return
            self.muestra(self.personajes[self.combo.currentIndex()][1][j])
            if self.animando: self.anima(True)           # (the cycle of the sprite picked)

        def muestra(self, g, espejo=False):
            cambio_personaje = g.personaje != self.actual.personaje
            if cambio_personaje and self.animando: self.anima(False)
            self.actual, self.espejo = g, espejo
            self.cx, self.cy = min(self.cx, 2 * g.w - 1), min(self.cy, g.h - 1)
            if cambio_personaje: self.rellena_lista()
            else:
                self.silencio = True; self.lista.setCurrentRow(self.indice_personaje(g)[1]); self.silencio = False
            self.refresca()
            self.lienzo.setFocus()

        def siguiente(self, paso):
            k = (self.graficos.index(self.actual) + paso) % len(self.graficos)
            self.muestra(self.graficos[k])
            if self.animando and self.actual.animacion: self.anima(True)

        def personaje(self, paso):
            i = (self.indice_personaje(self.actual)[0] + paso) % len(self.personajes)
            self.muestra(self.personajes[i][1][0])

        # -- animation (Guillermo and Adso: the game's own cycle, see the module docstring)
        def anima(self, encender=None):
            g = self.actual
            quiere = (not self.animando) if encender is None else encender
            if quiere and not g.animacion:
                self.statusBar().showMessage("este grupo no tiene animación (solo Guillermo y Adso)", 3000)
                return
            self.animando = quiere
            if self.animando:
                # the cycle of the sprite on the screen (animating used to play the first three
                # sprites always, even with the fourth shown): orientations 0 and 3 walk frames 0-2, 1 and 2 frames 3-5;
                # if the shown sprite is not in this orientation's cycle, the other cycle with the same mirroring
                # (0 <-> 1, 3 <-> 2), started at the shown sprite
                if all(x is not g for x, _ in g.animacion[self.orientacion]):
                    self.orientacion = {0: 1, 1: 0, 2: 3, 3: 2}[self.orientacion]
                self.paso = next(i for i, (x, _) in enumerate(g.animacion[self.orientacion]) if x is g)
                self.reloj_anim.start(self.ms)
                self.avanza()
            else:
                self.reloj_anim.stop()
                self.muestra(self.actual, False)

        def avanza(self):
            ciclo = self.actual.animacion
            if not ciclo: return
            g, espejo = ciclo[self.orientacion][self.paso % 4]
            self.paso = (self.paso + 1) % 4
            self.muestra(g, espejo)

        def orienta(self):
            self.orientacion = (self.orientacion + 1) % 4
            if self.animando: self.paso = 0; self.avanza()
            else: self.refresca()

        def velocidad(self, delta):
            self.ms = max(40, min(1000, self.ms + delta))
            if self.animando: self.reloj_anim.start(self.ms)
            self.refresca()

        # -- edits
        def pinta(self):
            g = self.actual
            if g.c64[self.cy][self.cx] != self.lapiz:
                self.pila.push(Pintar(self, g, [(self.cx, self.cy, g.c64[self.cy][self.cx], self.lapiz)],
                                      f"pintar {g.nombre} ({self.cx},{self.cy}) {g.nombre_pen(self.lapiz)}"))
            else: self.refresca()

        def restaura(self, todo):
            g = self.actual
            lineas = range(g.h) if todo else [self.cy]
            cambios = [(x, y, g.c64[y][x], g.regla[y][x]) for y in lineas for x in range(2 * g.w) if g.c64[y][x] != g.regla[y][x]]
            if cambios: self.pila.push(Pintar(self, g, cambios, ("sprite" if todo else "línea") + " a la regla"))

        def tras_cambio(self, g):
            if g is not self.actual: self.muestra(g)
            self.icono(g)
            self.refresca()

        def guarda(self):
            guarda_editados(self.personajes, self.path)
            self.pila.setClean()
            n = sum(len(g.lineas_editadas()) for g in self.graficos)
            self.statusBar().showMessage(f"guardado {self.path}: {n} líneas editadas", 4000)
            self.titulo()

        # -- keys
        def tecla(self, ev):
            k, mods, texto = ev.key(), ev.modifiers(), ev.text()
            ctrl = bool(mods & Qt.KeyboardModifier.ControlModifier)
            mayus = bool(mods & Qt.KeyboardModifier.ShiftModifier)
            g = self.actual
            if k in (Qt.Key.Key_O, Qt.Key.Key_Left): self.mueve(-1)
            elif k in (Qt.Key.Key_P, Qt.Key.Key_Right): self.mueve(1)
            elif k in (Qt.Key.Key_Q, Qt.Key.Key_Up): self.cy = max(0, self.cy - 1)
            elif k in (Qt.Key.Key_A, Qt.Key.Key_Down): self.cy = min(g.h - 1, self.cy + 1)
            elif k == Qt.Key.Key_Space: self.pinta(); return True
            elif Qt.Key.Key_0 <= k <= Qt.Key.Key_3: self.lapiz = k - Qt.Key.Key_0
            elif k == Qt.Key.Key_U or (ctrl and not mayus and k == Qt.Key.Key_Z): self.pila.undo()
            elif (ctrl and k == Qt.Key.Key_Y) or (ctrl and mayus and k == Qt.Key.Key_Z): self.pila.redo()
            elif k == Qt.Key.Key_S: self.guarda()
            elif k in (Qt.Key.Key_N, Qt.Key.Key_PageDown): self.siguiente(1); return True
            elif k in (Qt.Key.Key_M, Qt.Key.Key_PageUp): self.siguiente(-1); return True
            elif k == Qt.Key.Key_Tab: self.personaje(-1 if mayus else 1); return True
            elif k == Qt.Key.Key_Backtab: self.personaje(-1); return True
            elif k == Qt.Key.Key_R: self.restaura(mayus); return True
            elif k == Qt.Key.Key_D: self.marcas = not self.marcas
            elif k == Qt.Key.Key_V: self.anima(); return True
            elif k == Qt.Key.Key_G: self.orienta(); return True
            elif k == Qt.Key.Key_Comma or texto == ",": self.velocidad(25); return True
            elif k == Qt.Key.Key_Period or texto == ".": self.velocidad(-25); return True
            elif k in (Qt.Key.Key_Plus, Qt.Key.Key_Equal) or texto == "+": self.zoom(2)
            elif k == Qt.Key.Key_Minus or texto == "-": self.zoom(-2)
            elif k in (Qt.Key.Key_H, Qt.Key.Key_F1):
                QtWidgets.QMessageBox.information(self, "Teclas", AYUDA + "\n\nFichero: " + self.path)
            else: return False
            self.refresca()
            return True

        def mueve(self, dx):
            """The cursor dx screen pixels to the right (left when negative), whatever the mirroring."""
            if self.espejo: dx = -dx
            self.cx = max(0, min(2 * self.actual.w - 1, self.cx + dx))

        def zoom(self, paso):
            self.escala = max(4, min(40, self.escala + paso))
            self.lienzo.resize(self.lienzo.sizeHint())

        def parpadea(self):
            self.visible = not self.visible
            self.lienzo.update()

        def refresca(self):
            self.visible = True
            self.lienzo.resize(self.lienzo.sizeHint())
            self.lienzo.update()
            self.estado()

        def estado(self):
            g = self.actual
            a, b = g.pc[self.cy][2 * self.cx], g.pc[self.cy][2 * self.cx + 1]
            med = g.medidas()
            perdidos = ", ".join(f"{k} {v}" for k, v in sorted(med["perdidos"].items())) or "ninguno"
            self.statusBar().showMessage(
                f"{g.personaje} · {g.nombre}   cursor ({self.cx}, {self.cy})   C64: {g.nombre_pen(g.c64[self.cy][self.cx])}   "
                f"debajo: {g.nombre_pen(a)} / {g.nombre_pen(b)}   lápiz {self.lapiz} {g.nombre_pen(self.lapiz)}   "
                f"líneas editadas {len(g.lineas_editadas())}   trazos del PC perdidos: {perdidos}   "
                f"silueta distinta {med['silueta']} px" + (f"   PC≠CPC {g.pc_vs_cpc} px" if g.pc_vs_cpc else "") +
                (f"   ANIMACIÓN o={self.orientacion} {self.ms} ms/frame" if self.animando else
                 (f"   orientación {self.orientacion}, {self.ms} ms (V anima)" if g.animacion else "")) +
                ("" if self.pila.isClean() else "   SIN GUARDAR"))

        def titulo(self):
            try:
                self.setWindowTitle("Editor de gráficos C64 · abadia64ks" + ("" if self.pila.isClean() else " *"))
            except RuntimeError:
                pass                                     # the stack is being destroyed with the window

        def closeEvent(self, ev):
            if self.pila.isClean(): return
            r = QtWidgets.QMessageBox.question(self, "Cambios sin guardar", "¿Guardar las líneas editadas antes de salir?",
                                               QtWidgets.QMessageBox.StandardButton.Save | QtWidgets.QMessageBox.StandardButton.Discard
                                               | QtWidgets.QMessageBox.StandardButton.Cancel)
            if r == QtWidgets.QMessageBox.StandardButton.Save: self.guarda()
            elif r == QtWidgets.QMessageBox.StandardButton.Cancel: ev.ignore()

    return Editor


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--editados", default=G.EDITADOS, help="the hand-edited lines file (default src/c64/datos/editados64.txt)")
    ap.add_argument("--hoja", help="write a contact sheet PNG and exit")
    ap.add_argument("--grupo", help="with --hoja: one group (Guillermo, Adso, 'Monjes · caras', 'Monjes · hábitos', Escenario)")
    ap.add_argument("--lista", action="store_true", help="print the graphics and their edited lines and exit")
    ap.add_argument("--escala", type=int, default=16, help="screen pixels per PC pixel (a C64 pixel is twice as wide)")
    x = ap.parse_args(argv)
    personajes = carga_personajes()
    sobran = carga_editados(personajes, x.editados)
    if sobran: print("editados: addresses of no character here: " + ", ".join(f"{a:04X}" for a in sobran), file=sys.stderr)
    if x.lista:
        for g in todos(personajes):
            ed = g.lineas_editadas()
            print(f"{g.personaje:18s} {g.nombre:22s} PC {'----' if g.pa is None else f'{g.pa:04X}'} CPC {g.ca:04X} {4 * g.w:2d}x{g.h:<2d} PC!=CPC {g.pc_vs_cpc:3d}  "
                  f"edited lines {len(ed)}" + (": " + " ".join(map(str, ed)) if ed else ""))
        return 0
    if x.hoja:
        print(x.hoja, hoja(personajes, x.hoja, x.grupo, max(1, x.escala // 4)))
        return 0
    from PySide6 import QtWidgets
    app = QtWidgets.QApplication(sys.argv[:1])
    editor = ventana(personajes, x.editados, x.escala)()
    editor.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
