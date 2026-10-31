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

"""The graphics of the CPC 64 KiB game converted to the Commodore 64 formats (H3, src/c64/NOTAS_GRAFICOS.md).

    c64_graficos.py IMAGE OUTDIR [--comprueba PNGDIR] [--hw]

--hw (milestone H7: the heads in high definition; src/c64/juego_final/cabezas.s): the black strokes of
the HEADS of Guillermo and Adso (lines 0-9 of their 12 animation frames) drawn by hires hardware sprites at the PC's
full width over the multicolour bitmap.  The personajes block is the normal build's (rule trazos, the hand edits) but
the head lines of those frames are converted by the rule cuerpo (c64_mitad.py: no black of their own, a pair with
one black pixel takes its other pixel; variant B) unless --cabezas-a (variant A: the normal head lines kept, the
sprite adds the PC's black over them).  12 more blocks, cab_negro_00..11 (the frames in address order: Guillermo
A300h A3B4h A45Eh A508h A5B7h A666h, Adso A6EAh A78Ah A82Ah A8C5h A93Dh A9B5h): the black of lines 0-9 at the PC's
width, 3 bytes a line (2 for the frames 4 CPC bytes wide), 1 = black, each nibble's four pixels stored in the
order 0 1 3 2 so that the game's spr_flip_graphics_h (its nibble mirror swaps the two bit pairs) reverses them.  No
OR tables of the tiles and no tabla_or_spr (cabezas.s: la_baldosa's EOR form; those pages are the slots and the
run-time data).  The tiles and every other block as in the normal build.

--c128 (milestone H10, the C128's disk; ALL the heads in hires, every one, and the graphics the 64ks
and the 128ks share unchanged from one to the other, only the heads differ): every block as in the normal build (the hand edits
too) but the heads: the lines 0-9 of Guillermo's and Adso's 12 animation frames and the monks' 14 faces by the rule
cuerpo (no black of their own), and one more block, cabezas_negro: the black of those 26 heads at the PC's width, 30
bytes each (10 lines of 3 bytes, 1 bit a pixel, 1 = black, the leftmost pixel in bit 7), unflipped as on the tape:
the 12 frames in CAB_MARCOS's order, then the faces (Severino a, b, abbot a, b, ... hooded b).  The C128's hardware
sprites draw it (src/c64/juego_final/cabezas128.s), mirrored at draw time with the frame.

--completo (with --c128: abadia128ks, the full game of the PC; the same tiles as in the 64ks, with those
the 128ks uses and the 64ks lacks added, so that the tiles common to both show no difference): the tile block has the PC's 256 tile numbers by
data/completo/baldosas128.tsv (tools/baldosas128.py): a tile whose image the 64 KiB game has takes
that tile's C64 graphic byte for byte (the edits included), the new images are converted by the same rule
(detalle; their edits keyed 10000h + the PC address 2B22h + 32n), the tiles no room shows stay empty, and the
objects' graphics move to two runs of them.

IMAGE is the tape's memory image at the game's start (data/cpc64/juego/ram.bin: before sys_startup_init,
so tiles 00h-7Fh are still at 8300h + 32n and the score bar's source is in the hidden screen rows).
OUTDIR gets one <name>.bin per graphics block in its C64 format, the tables the 6502 drawing code builds
at start-up (for the host's checks), graficos64.tsv (the blocks) and marcos64.tsv (every address a pointer
of the game can hold into a converted block: CPC value -> offset in the C64 block).  --comprueba also
writes PNG renders (CPC against C64) and checks the in-place flips and the determinism.

The pixel rule: a CPC mode 1 byte (4 pixels) becomes one C64 multicolour nibble (2 pixels), each pair of
CPC pixels one C64 pixel, pen -> bit pair BITS (c64_sala.py: pen 3 = 00 = $D021, pen 0 = 01, pen 1 = 10,
pen 2 = 11).  Which pixel of a pair survives:
  sim      the door and the objects: the pen first in 1, 2, 3, 0 (orange, yellow, black, then transparent pen 0).
           Mirror-symmetric and per byte, so the game's in-place flip of the door gives exactly the conversion of
           the flipped CPC graphic.
  trazos   Guillermo, Adso, the monks' faces and robes (c64_mitad.py: the same shape as the PC
           EGA / CPC drawing): per line, the least-cost choice of one pixel of each pair, where losing a stroke of
           the drawing (a run of any pen that is darker or lighter than its neighbours, an inner gap) costs much,
           losing a one-pixel step of shading costs little, and moving an edge costs little; the silhouette grows
           outward; ties go with the line above.  Not mirror-symmetric: the game flips the C64 data in place
           (faces, Guillermo, Adso) or reads the robes backwards, and the host's checks take a flipped unit from the
           image (src/juego/m6502/sombra6502.c, convierte).  It replaces the rules aislado and the hand retouches of
           src/c64/datos/retoques64.txt (kept, no longer applied).  Over the rule, the lines edited by hand with
           tools/c64_editor.py (src/c64/datos/editados64.txt, same format: the graphic's CPC address, the
           line, one character a C64 pixel) replace the rule's lines of Guillermo, Adso, the faces, the robes and
           the tiles 01h-D9h but the object slots (the tile's key: its tape address 8300h + 32n; normal build only,
           not --hw); a line of the wrong length, outside its graphic or at an unknown address
           stops the build.  Another file: the environment variable C64_EDITADOS.
  detalle  tiles (per tile), the roman numerals: c64_sala.py's rule (right pixel, keeps one-pixel
           vertical lines and fluting).
  izq      the score bar (left pixel: the only rule that keeps its gothic "OBSEQUIUM" readable).
  der      the font (right pixel; it alone keeps the letters readable at 4 pixels) with N redrawn and ';'
           taken from the left pixels (else N = H and ';' = ':'); the obsequium tail.
"""
import hashlib, os, struct, sys, zlib

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import c64_sala as C          # noqa: E402  (mitad_detalle)
import c64_mitad as M         # noqa: E402  (trazos)

BITS = {3: 0, 0: 1, 1: 2, 2: 3}          # CPC pen -> C64 multicolour bit pair
PEN = {v: k for k, v in BITS.items()}
PRIORIDAD = (1, 2, 3, 0)                  # rule sim
PAD = BITS[0]                             # padding pixels: pen 0, transparent for sprites (bit pair 01)


def pens(b):
    return [((b >> (7 - i)) & 1) | (((b >> (3 - i)) & 1) << 1) for i in range(4)]


def imagen(m, p, w, h):
    """A row-major CPC graphic (w bytes x h lines from p) as rows of pens."""
    return [sum((pens(m[p + r * w + x]) for x in range(w)), []) for r in range(h)]


def mitad(img, regla):
    """CPC pens (4w per row) -> C64 pens (2w per row)."""
    out = []
    for y, row in enumerate(img):
        o = []
        for x in range(len(row) // 2):
            a, b = row[2 * x], row[2 * x + 1]
            if a == b: p = a
            elif regla == "sim": p = a if PRIORIDAD.index(a) < PRIORIDAD.index(b) else b
            elif regla == "der": p = b
            elif regla == "izq": p = a
            elif regla == "detalle": p = C.mitad_detalle(img, x, y)
            else: raise ValueError(regla)
            o.append(p)
        out.append(o)
    return out


def aislado(img):
    """Rule aislado (characters): sim, but the black pixel of a pair wins when its two neighbours in the line
    are orange or yellow."""
    out = mitad(img, "sim")
    for y, row in enumerate(img):
        for x in range(len(row) // 2):
            a, b = row[2 * x], row[2 * x + 1]
            if a == b or 3 not in (a, b) or 0 in (a, b): continue
            k = 2 * x if a == 3 else 2 * x + 1
            iz = row[k - 1] if k > 0 else 0
            de = row[k + 1] if k + 1 < len(row) else 0
            if iz in (1, 2) and de in (1, 2): out[y][x] = 3
    return out


RETOQUES = os.path.join(AQUI, "..", "src", "c64", "datos", "retoques64.txt")
LETRA = {".": 0, "o": 1, "Y": 2, "#": 3}


def retoques():
    """src/c64/datos/retoques64.txt: {CPC frame address: {line: C64 pens}}"""
    out = {}
    if not os.path.exists(RETOQUES): return out
    for linea in open(RETOQUES):
        t = linea.split()
        if not t or t[0].startswith("#"): continue
        out.setdefault(int(t[0], 16), {})[int(t[1])] = [LETRA[c] for c in t[2]]
    return out


EDITADOS = os.environ.get("C64_EDITADOS", os.path.join(AQUI, "..", "src", "c64", "datos", "editados64.txt"))
# the graphics the editor can change: their CPC address (the key of editados64.txt) -> (C64 width in pixels / 2, lines)
EDITABLES = {}


def editados(path=EDITADOS):
    """src/c64/datos/editados64.txt (c64_editor.py: the hand-edited C64 lines): {CPC address: {line: C64 pens}}"""
    out = {}
    if not os.path.exists(path): return out
    for n, linea in enumerate(open(path), 1):
        t = linea.split()
        if not t or t[0].startswith("#"): continue
        if len(t) != 3 or any(c not in LETRA for c in t[2]):
            raise SystemExit(f"{path}:{n}: expected ADDRESS LINE PIXELS (characters . o Y #)")
        out.setdefault(int(t[0], 16), {})[int(t[1])] = [LETRA[c] for c in t[2]]
    return out


def aplica_editados(mc, addr, w, ed):
    """mc (rows of 2w C64 pens of the graphic at CPC address addr) with its hand-edited lines put in."""
    EDITABLES[addr] = (w, len(mc))
    for linea, pens in sorted(ed.get(addr, {}).items()):
        if not 0 <= linea < len(mc) or len(pens) != 2 * w:
            raise SystemExit(f"editados64: {addr:04X} line {linea}: the graphic has {len(mc)} lines of {2 * w} pixels")
        mc[linea] = list(pens)
    return mc


def byte(px):
    v = 0
    for p in px: v = (v << 2) | BITS[p]
    return v


def filas(mc, w):
    """Row-major sprite format: per line ceil(w/2) bytes; w odd: the last low nibble is padding (01 01)."""
    out = bytearray()
    for row in mc:
        r = list(row) + [0] * (2 if w & 1 else 0)
        for k in range(0, len(r), 4): out.append(byte(r[k:k + 4]))
    return bytes(out)


def baldosa(mc):
    """Tile format: 16 bytes, column-major: the left byte column's 8 lines, then the right one's."""
    return bytes(byte(mc[l][c * 4:c * 4 + 4]) for c in range(2) for l in range(8))


def de_filas(data, w, h):
    """C64 row-major bytes -> pens (2w per row), for the checks."""
    bpr = (w + 1) // 2
    return [[PEN[(data[r * bpr + k // 4] >> (6 - 2 * (k % 4))) & 3] for k in range(2 * w)] for r in range(h)]


def de_baldosa(data):
    return [[PEN[(data[(k // 4) * 8 + l] >> (6 - 2 * (k % 4))) & 3] for k in range(8)] for l in range(8)]


# ---- the blocks --------------------------------------------------------------------------------------------
# tile slots of the C64 tile block (tiles 00h-D9h; DAh-FFh hold the height lists on the CPC): the objects
# live in free tile slots as on the CPC (2Dh-2Fh, A1h-A6h), at half their CPC offset
NBALDOSAS = 0xDA
OBJETOS = [  # CPC pointer as held by the sprite table, the tape image's address, name
    (0xD7A0, 0x88A0, "lamp (object 8, sprite 2B0Ch)"),
    (0xD7D0, 0x88D0, "book (object 0, sprite 2A6Ch)"),
    (0x9720, 0x9720, "glasses (object 2, sprite 2A94h)"),
    (0x9750, 0x9750, "object 1 (sprite 2A80h)"),
    (0x9780, 0x9780, "keys (objects 4-6, sprites 2ABCh, 2AD0h, 2AE4h)"),
    (0x97B0, 0x97B0, "parchment (object 3, sprite 2AA8h)"),
]
OBJ_W, OBJ_H = 4, 12


def slot_de_cpc(p):
    """The tape image's tile area address -> tile slot, offset in it."""
    return (p - 0x8300) // 32, (p - 0x8300) % 32


SLOTS_OBJETOS = set()
for _, p, _ in OBJETOS:
    s, o = slot_de_cpc(p)
    for k in range(o, o + OBJ_W * OBJ_H): SLOTS_OBJETOS.add(s + k // 32)

# Guillermo's and Adso's frames: (CPC start, width, lines) of each sub-block, flipped in place as a whole
PERSONAJES = [(0xA300, 5, 0xAE, "Guillermo, 5 bytes wide (flipped by 2F40)"),
              (0xA666, 4, 0x21, "Guillermo, 4 bytes wide (flipped by 2F40)"),
              (0xA6EA, 5, 0x5F, "Adso, 5 bytes wide (flipped by 2EE7)"),
              (0xA8C5, 4, 0x5A, "Adso, 4 bytes wide (flipped by 2EE7)")]
ROBES = [(0xAB59, 26), (0xABDB, 24), (0xAC53, 24), (0xACCB, 25), (0xAD48, 23), (0xADBB, 23)]
CARAS = [(0xB103, "Severino"), (0xB167, "abbot"), (0xB1CB, "Malaquias"), (0xB22F, "Berengario"),
         (0xB293, "Bernardo Gui"), (0xB2F7, "Jorge"), (0xB35B, "hooded monk")]


def fuente_der(m):
    """The font, 46 glyphs 2Dh-5Ah of 8 rows x 4 pixels (right pixel of each pair); the collisions of
    the rule fixed: N redrawn (else = H), ';' from the left pixels (else = ':')."""
    def g(c, regla):
        rows = []
        for r in range(8):
            b = m[0xB400 + (c - 0x2D) * 8 + r]
            p = [(b >> (7 - i)) & 1 for i in range(8)]
            rows.append([p[2 * k + (1 if regla == "der" else 0)] for k in range(4)])
        return rows
    N = ["....", "#..#", "##.#", "##.#", "#.##", "#.##", "#..#", "#..#"]
    out = {}
    for c in range(0x2D, 0x5B):
        out[c] = g(c, "izq" if c == 0x3B else "der")
        if c == 0x4E: out[c] = [[1 if ch == "#" else 0 for ch in r] for r in N]
    vistos = {}
    for c, v in out.items():
        k = str(v)
        if k in vistos and c not in (0x3A,): raise SystemExit(f"font: glyphs {vistos[k]:02X} and {c:02X} equal")
        vistos[k] = c
    return out


def empaqueta_glifo(rows):
    """4 bytes: byte k = row 2k in the high nibble, row 2k+1 in the low; bit 3 of a nibble = the left pixel."""
    nib = [sum(v << (3 - i) for i, v in enumerate(r)) for r in rows]
    return bytes((nib[2 * k] << 4) | nib[2 * k + 1] for k in range(4))


def tablas():
    """The 6502 drawing tables (built at start-up by the game's code; written here for the host's checks):
    masks (AND keeps the screen where the pixel is transparent, OR = the byte with the transparent pixels
    cleared) for the tiles 0Bh-7Fh (pen 2 = 11 transparent), 80h-FFh (pen 1 = 10) and the sprites (pen 0 =
    01); the mirror tables (espejo_nibble: the 2 pixels of each nibble swapped; espejo_byte: the 4 pixels
    reversed); the nibble swap (a sprite at an odd CPC byte x is half a C64 byte off); the font's nibble ->
    byte table (set pixel pen 3 = 00, clear pen 2 = 11; inverted text = EOR FFh)."""
    def mascaras(trans):
        a = bytearray(256); o = bytearray(256)
        for b in range(256):
            m = 0
            for k in range(4):
                if (b >> (6 - 2 * k)) & 3 == trans: m |= 3 << (6 - 2 * k)
            a[b] = m; o[b] = b & ~m & 0xFF
        return a, o
    t = {}
    t["and_tile_a"], t["or_tile_a"] = mascaras(BITS[2])
    t["and_tile_b"], t["or_tile_b"] = mascaras(BITS[1])
    t["and_spr"], t["or_spr"] = mascaras(BITS[0])
    if HW:                                            # H7: no OR tables of the tiles, no tabla_or_spr (cabezas.s)
        del t["or_tile_a"], t["or_tile_b"], t["or_spr"]
    mn = bytearray(256); mb = bytearray(256)
    for b in range(256):
        px = [(b >> (6 - 2 * k)) & 3 for k in range(4)]
        q = [px[1], px[0], px[3], px[2]]
        mn[b] = (q[0] << 6) | (q[1] << 4) | (q[2] << 2) | q[3]
        r = px[::-1]
        mb[b] = (r[0] << 6) | (r[1] << 4) | (r[2] << 2) | r[3]
    t["espejo_nibble"], t["espejo_byte"] = mn, mb
    t["nibbles"] = bytes(((b << 4) | (b >> 4)) & 0xFF for b in range(256))   # high <-> low nibble (odd x)
    fu = bytearray(16)
    for n in range(16):
        v = 0
        for i in range(4):
            v = (v << 2) | (BITS[3] if (n >> (3 - i)) & 1 else BITS[2])
        fu[n] = v
    t["fuente_nibble"] = fu
    return t


# (H7, the CABEZAS build) graphics stored in tile slots no room draws: name -> first slot (mapa64.py EN_BALDOSAS_HW)
EN_BALDOSAS_HW = {"romanos": 0x46, "luz": 0x85}

def convierte(m):
    """-> blocks: list of dicts (name, cpc, cpc_len, data, format, merge, flip, notes) and frames: list of
    (block, cpc pointer, w, h, c64 offset, c64 bytes, note)."""
    bloques, marcos = [], []
    ed = editados()                                 # the hand-edited lines (c64_editor.py)
    EDITABLES.clear()

    # tiles 00h-D9h + the objects in free slots
    t = bytearray(NBALDOSAS * 16)
    for n in range(NBALDOSAS):
        if n in SLOTS_OBJETOS: continue
        # the rule detalle (c64_sala.py), the chosen room look; trazos per tile (tried: fewer
        # runs of the source lost, 807 against 1373) looked worse in the rooms (those background graphics were worse):
        # the tiles form continuous surfaces and the per-tile choices broke the brick courses and floor patterns
        mc = aplica_editados(mitad(imagen(m, 0x8300 + 32 * n, 4, 8), "detalle"), 0x8300 + 32 * n, 4, ed)
        t[16 * n:16 * n + 16] = baldosa(mc)
    obj_mueve = lambda p: 0                        # (--completo: the objects' slots move, baldosas128.tsv)
    if COMPLETO:
        # abadia128ks (milestone H10, the full game): the PC's 256 tile numbers.  A tile whose image the 64 KiB game
        # has takes that tile's C64 graphic as it is (the edits included: the same tiles in the 64ks
        # and the 128ks, no difference in the common ones); a new image is converted by the same rule (detalle),
        # its edits keyed 10000h + its PC address (2B22h + 32n); a tile no room shows stays empty
        t64 = t
        t = bytearray(256 * 16)
        objetos = {}
        for l in open(BALDOSAS128):
            if l.startswith("#") or l.startswith("tile"): continue
            n, clase, fuente = l.rstrip("\n").split("\t")
            n = int(n, 16)
            if clase == "64K":
                k = int(fuente, 16)
                t[16 * n:16 * n + 16] = t64[16 * k:16 * k + 16]
            elif clase == "new":
                src = bytes.fromhex(fuente)
                img = [sum((pens(src[r * 4 + x]) for x in range(4)), []) for r in range(8)]
                t[16 * n:16 * n + 16] = baldosa(aplica_editados(mitad(img, "detalle"), 0x10000 + 0x2B22 + 32 * n, 4, ed))
            elif clase == "objects":
                objetos.setdefault(n, True)
        uno = min(x for x in objetos if x < 0x80); dos = min(x for x in objetos if x >= 0x80)
        obj_mueve = lambda p: 16 * ((uno - 0x2D) if p < 0x9000 else (dos - 0xA1))
    for ptr, p, nota in OBJETOS:
        d = filas(mitad(imagen(m, p, OBJ_W, OBJ_H), "sim"), OBJ_W)
        off = (p - 0x8300) // 2 + obj_mueve(p)
        t[off:off + len(d)] = d
        marcos.append(("baldosas", ptr, OBJ_W, OBJ_H, off, len(d), "object graphic: " + nota))
    marcos.append(("baldosas", 0xA006, OBJ_W, OBJ_H, (0x88A0 - 0x8300) // 2 + obj_mueve(0x88A0), 24,
                   "GARBAGE: object 7 (record 2B7Ch, sprite 2AF8h, never in play) points into the library heights; "
                   "mapped to the lamp's graphic"))
    if COMPLETO:
        bloques.append(dict(nombre="baldosas", cpc=0x8300, n=256 * 32, datos=bytes(t),
                            formato="tile n at +16n: 2 byte columns x 8 lines, column-major; objects row-major 2 x 12",
                            mezcla="tiles 01-0A opaque copy; 0B-7F pen 2 (11) transparent; 80-FF pen 1 (10) transparent; "
                                   "objects pen 0 (01) transparent (sprite merge), opaque in the score bar",
                            giro="n", notas="abadia128ks: the PC's tile numbers (data/completo/baldosas128.tsv: 204 "
                                            "the 64 KiB game's C64 graphics, 25 new, the objects in free slots)"))
    else:
        bloques.append(dict(nombre="baldosas", cpc=0x8300, n=NBALDOSAS * 32, datos=bytes(t),
                        formato="tile n at +16n: 2 byte columns x 8 lines, column-major; objects row-major 2 x 12 "
                                "at (CPC offset)/2",
                        mezcla="tiles 01-0A opaque copy; 0B-7F pen 2 (11) transparent; 80-D9 pen 1 (10) transparent; "
                               "objects pen 0 (01) transparent (sprite merge), opaque in the score bar",
                        giro="n", notas="tape image 8300h-9E3Fh = tile n at 8300h + 32n (after start-up tiles 00-7F "
                                        "live in the screen gaps C6xx-FFxx); slots 00 73 85 86 unused (6D unused by "
                                        "the rooms); objects in 2D-2F, A1-A6"))

    # Guillermo and Adso: rule trazos (c64_mitad.py), frame by frame so that no line is coupled to the previous
    # frame's last line; with --hw the body only (cuerpo) and the black layer apart (negro, negro_tabla)
    d = bytearray()
    marcos_pers = set()
    entradas = []                                   # the 16 animation entries in table order: (ptr, w, h)
    for tabla in (0x2CF0, 0x2D10):
        for e in range(8):
            q = tabla + 4 * e
            entradas.append((m[q] | m[q + 1] << 8, m[q + 2], m[q + 3]))
            marcos_pers.add(entradas[-1])
    regla = M.trazos                                # (M.contorno was tried and put back: Adso's eyes
                                                    # vanish in some frames, the forced contour eats the highlights)
    for p, w, h, nota in PERSONAJES:
        pix = [None] * h
        for ptr, fw, fh in sorted(marcos_pers):
            if p <= ptr < p + w * h:
                if fw != w or (ptr - p) % w or (ptr - p) // w + fh > h: raise SystemExit(f"frame {ptr:04X} outside {p:04X}")
                mc = aplica_editados(regla(imagen(m, ptr, w, fh)), ptr, w, ed)
                if (HW and not CABEZAS_A) or C128:  # H7 B, the C128: the head lines 0-9 by cuerpo (the sprite's black)
                    mc[:CAB_LINEAS] = M.cuerpo(imagen(m, ptr, w, CAB_LINEAS))
                pix[(ptr - p) // w:(ptr - p) // w + fh] = mc
        for r in range(h):
            if pix[r] is None: pix[r] = M.trazos_fila(imagen(m, p + r * w, w, 1)[0])
        sub = filas(pix, w)
        marcos.append(("personajes", p, w, h, len(d), len(sub), nota + ": sub-block start"))
        d += sub
    frames = set()
    for tabla in (0x2CF0, 0x2D10):
        for e in range(8):
            q = tabla + 4 * e
            frames.add((m[q] | m[q + 1] << 8, m[q + 2], m[q + 3]))
    for ptr, w, h in sorted(frames):
        base = max(p for p, _, _, _ in PERSONAJES if p <= ptr)
        pw = [x for x in PERSONAJES if x[0] == base][0]
        if (ptr - base) % pw[1] or pw[1] != w: raise SystemExit(f"frame {ptr:04X} not at a line start")
        off = sum(((x[1] + 1) // 2) * x[2] for x in PERSONAJES if x[0] < base) + (ptr - base) // w * ((w + 1) // 2)
        marcos.append(("personajes", ptr, w, h, off, ((w + 1) // 2) * h, "animation frame (2CF0h/2D10h)"))
    bloques.append(dict(nombre="personajes", cpc=0xA300, n=0xAA2D - 0xA300, datos=bytes(d),
                        formato="row-major, ceil(w/2) bytes a line, odd w: low nibble of the last byte = padding 01",
                        mezcla="sprite: pen 0 (01) transparent", giro="y (2EE7, 2F40: spr_flip_graphics_h)",
                        notas="4 sub-blocks (Guillermo 5x174, 4x33, Adso 5x95, 4x90); AA2Dh-AA48h unused; rule "
                              + ("trazos, the heads' lines 0-9 cuerpo (H7: hardware sprites draw their black)" if HW and not CABEZAS_A
                                 else "trazos") + " (c64_mitad.py) frame by frame"))
    if HW:                                          # H7: the heads' black, a block a frame (cabezas.s)
        cuadros = sorted(frames)
        if [(x, w) for x, w, _ in cuadros] != CAB_MARCOS:
            raise SystemExit("cab_negro: the animation frames are not the expected 12: " + str(cuadros))
        for k, (ptr, w, h) in enumerate(cuadros):
            d = bytearray()
            nb = 3 if w == 5 else 2                 # bytes a line (the 6th nibble of a 5-wide line: 0, padding)
            for fila in imagen(m, ptr, w, CAB_LINEAS):
                px = [1 if q == 3 else 0 for q in fila] + [0] * (8 * nb - 4 * w)
                for n in range(0, 8 * nb, 8):
                    nib = lambda q: q[0] << 3 | q[1] << 2 | q[3] << 1 | q[2]     # pixels 0 1 3 2 (spr_flip_graphics_h)
                    d.append(nib(px[n:n + 4]) << 4 | nib(px[n + 4:n + 8]))
            bloques.append(dict(nombre="cab_negro_%02d" % k, cpc=None, n=0, datos=bytes(d),
                                formato="10 lines x 3 bytes (2 when 4 CPC bytes wide), 1 bit a PC pixel (1 = black) from bit 7; each "
                                        "nibble's pixels in the order 0 1 3 2",
                                mezcla="hires hardware sprite (black), masked by what the rectangle draws after the head",
                                giro="y (with the frames: cab_gira, spr_flip_graphics_h a line at a time)",
                                notas=f"the black of lines 0-9 of frame {ptr:04X} ({w} CPC bytes wide), milestone H7"))

    # the door leaf
    d = filas(mitad(imagen(m, 0xAA49, 6, 0x28), "sim"), 6)
    marcos.append(("puerta", 0xAA49, 6, 0x28, 0, len(d), "door leaf (door sprites +7, code 0A7Eh, 0AE6h)"))
    bloques.append(dict(nombre="puerta", cpc=0xAA49, n=240, datos=d, formato="row-major, 3 bytes x 40 lines",
                        mezcla="sprite: pen 0 (01) transparent", giro="y (obj door flip, 28C9h state)", notas=""))

    # the roman numerals of the day
    d = filas(mitad(imagen(m, 0xAB39, 2, 8), "detalle"), 2) + filas(mitad(imagen(m, 0xAB49, 2, 8), "detalle"), 2)
    marcos.append(("romanos", 0xAB39, 2, 8, 0, 8, "V (code 50E7h)"))
    marcos.append(("romanos", 0xAB49, 2, 8, 8, 8, "I (code 50E0h)"))
    bloques.append(dict(nombre="romanos", cpc=0xAB39, n=32, datos=d, formato="row-major, 1 byte x 8 lines each (V, I)",
                        mezcla="opaque (score bar)", giro="n", notas="the blank glyph row 50D7h (FF FF) = 1 byte 00"))

    # the monks' robes
    d = bytearray()
    for p, h in ROBES:
        sub = filas(aplica_editados(M.trazos(imagen(m, p, 5, h)), p, 5, ed), 5)
        marcos.append(("habitos", p, 5, h, len(d), len(sub),
                       "robe (table 4431h; the table's words also carry bit 14 = drawn mirrored)"))
        d += sub
    bloques.append(dict(nombre="habitos", cpc=0xAB59, n=0xAE2E - 0xAB59, datos=bytes(d),
                        formato="row-major, 3 bytes a line (w 5)", mezcla="sprite: pen 0 (01) transparent",
                        giro="mirrored at draw time (bit 14 of the robe pointer)",
                        notas="rule trazos; 6 robes of 26, 24, 24, 25, 23, 23 lines; 2126h copies them to AE2Eh and flips the copy "
                              "(dead: overwritten by the height buffer, B06E-B102 never read)"))

    # the monks' faces: 7 blocks of 2 faces (10 lines each), flipped in place as 5 x 20 (the C128: the rule cuerpo, the
    # black by its hardware sprites)
    d = bytearray()
    for p, quien in CARAS:
        if C128:                                    # (the edits of the faces: the 64 KiB version's; registered)
            aplica_editados(M.trazos(imagen(m, p, 5, 10)), p, 5, ed)
            aplica_editados(M.trazos(imagen(m, p + 50, 5, 10)), p + 0x32, 5, ed)
            sub = filas(M.cuerpo(imagen(m, p, 5, 10)) + M.cuerpo(imagen(m, p + 50, 5, 10)), 5)
        else:
            sub = filas(aplica_editados(M.trazos(imagen(m, p, 5, 10)), p, 5, ed)
                        + aplica_editados(M.trazos(imagen(m, p + 50, 5, 10)), p + 0x32, 5, ed), 5)   # each face on its own
        marcos.append(("caras", p, 5, 10, len(d), 30, f"face of {quien}"))
        marcos.append(("caras", p + 0x32, 5, 10, len(d) + 30, 30, f"second face of {quien} (+32h on the CPC, +1Eh here)"))
        d += sub
    bloques.append(dict(nombre="caras", cpc=0xB103, n=700, datos=bytes(d),
                        formato="row-major, 3 bytes a line; 7 x (2 faces x 10 lines)",
                        mezcla="sprite: pen 0 (01) transparent", giro="y (2F00-2F30, 304F unflip)",
                        notas="rule trazos; pointers: 2BE8h table, 2D30h animation (face, face + 32h), code 3B9Fh, 3BAFh, "
                              "3BCBh, 3BDEh"))

    if C128:                                        # the heads' black for the C128's hardware sprites
        d = bytearray()
        cabezas = [(x, w) for x, w in CAB_MARCOS] + [(p + 0x32 * j, 5) for p, _ in CARAS for j in (0, 1)]
        for ptr, w in cabezas:
            for fila in imagen(m, ptr, w, CAB_LINEAS):
                px = [1 if q == 3 else 0 for q in fila] + [0] * (24 - 4 * w)
                d += bytes(sum(px[8 * n + k] << (7 - k) for k in range(8)) for n in range(3))
        bloques.append(dict(nombre="cabezas_negro", cpc=None, n=0, datos=bytes(d),
                            formato="26 heads x 10 lines x 3 bytes, 1 bit a PC pixel (1 = black), the leftmost in bit 7; "
                                    "the 12 frames (CAB_MARCOS), then the 14 faces",
                            mezcla="the C128's hires hardware sprites (black), masked by what the rectangle draws after "
                                   "the head", giro="n (mirrored at draw time: cabezas128.s)",
                            notas="the black of the heads' lines 0-9, unflipped as on the tape (milestone H10)"))

    desconocidas = sorted(set(ed) - set(EDITABLES))
    if desconocidas:
        raise SystemExit("editados64: no editable graphic at " + ", ".join(f"{a:04X}" for a in desconocidas))

    # the font and the blank glyph
    f = fuente_der(m)
    d = b"".join(empaqueta_glifo(f[c]) for c in range(0x2D, 0x5B))
    marcos.append(("fuente", 0xB400, 2, 8, 0, len(d), "font base: glyph c at B400h + 8 (c - 2Dh) -> +4 (c - 2Dh)"))
    bloques.append(dict(nombre="fuente", cpc=0xB400, n=0x170, datos=d,
                        formato="4 bytes a glyph (2Dh-5Ah): rows 2k / 2k+1 in the high / low nibble, bit 3 = left pixel",
                        mezcla="drawn opaque: set pixel pen 3 (00) on pen 2 (11); inverted = EOR FFh",
                        giro="n", notas="rule der, N redrawn, ';' from the left pixels"))
    bloques.append(dict(nombre="glifo_blanco", cpc=0x344C, n=8, datos=bytes(4), formato="as the font",
                        mezcla="as the font", giro="n", notas="the glyph of code 20h"))
    marcos.append(("glifo_blanco", 0x344C, 2, 8, 0, 4, "blank glyph"))

    # the score bar (character rows 20-23 of the screen), in the bitmap's cell order
    img = []
    for src in (0xC600, 0xD600, 0xE600, 0xF600):
        for l in range(8): img.append(sum((pens(m[src + l * 64 + x]) for x in range(64)), []))
    mc = mitad(img, "izq")
    d = bytearray()
    for r in range(4):
        for c in range(32):
            for l in range(8): d.append(byte(mc[r * 8 + l][c * 4:c * 4 + 4]))
    for k, src in enumerate((0xC600, 0xD600, 0xE600, 0xF600)):
        marcos.append(("marcador", src, 64, 8, 256 * k, 256, f"source of score bar row {20 + k} (3598h)"))
    bloques.append(dict(nombre="marcador", cpc=0xC600, n=0x800, datos=bytes(d),
                        formato="C64 bitmap order: 4 character rows x 32 cells x 8 bytes (cells 4-35 of bitmap rows 20-23)",
                        mezcla="opaque", giro="n",
                        notas="rule izq; CPC sources C600h, D600h, E600h, F600h (512 bytes each, hidden rows of the tape image); "
                              "goes straight into the bitmap"))

    # the lamp's light, the obsequium tail, the blank row of the numerals
    d = bytes(m[0x4451:0x4451 + 30])
    marcos.append(("luz", 0x4451, 2, 15, 0, 30, "light pattern"))
    bloques.append(dict(nombre="luz", cpc=0x4451, n=30, datos=d,
                        formato="as on the CPC: 15 big-endian words, one bit per CPC byte = per C64 nibble (0 = dark)",
                        mezcla="writes dark (pen 3 = 00) nibbles into the sprite buffer", giro="shift (476Dh)",
                        notas="not pixels: unchanged"))
    d = bytes(byte(mitad([pens(m[0x5180 + k])], "der")[0] + [3, 3]) >> 4 for k in range(4))
    marcos.append(("cola_obsequium", 0x5180, 1, 1, 0, 4, "obsequium bar tail"))
    bloques.append(dict(nombre="cola_obsequium", cpc=0x5180, n=4, datos=d,
                        formato="4 nibbles (low 4 bits): the partial nibble of the bar for obsequium & 3",
                        mezcla="opaque", giro="n", notas="full nibble pen 2 = F, empty pen 3 = 0 (CPC 0Fh, FFh)"))
    marcos.append(("fila_blanca", 0x50D7, 2, 1, 0, 1, "blank row of the day numeral"))
    bloques.append(dict(nombre="fila_blanca", cpc=0x50D7, n=2, datos=bytes([byte([3, 3, 3, 3])]),
                        formato="1 byte (pen 3)", mezcla="opaque", giro="n", notas="CPC FF FF"))
    if HW:                                          # H7: the numerals and the light in tile slots no room uses (46h, 85h-86h:
        # the 129 rooms built by the game's own 6502 builder in VICE; their only reads are the composer's
        # out-of-buffer cells, clipped off the screen), both read with the I/O off: the room under the I/O they leave
        # takes the heads' black (mapa64.py: G_ROMANOS, G_LUZ there)
        bal = [b for b in bloques if b["nombre"] == "baldosas"][0]
        tb = bytearray(bal["datos"])
        for nom, slot in EN_BALDOSAS_HW.items():
            b = [x for x in bloques if x["nombre"] == nom][0]
            if any(s in SLOTS_OBJETOS for s in range(slot, slot + (len(b["datos"]) + 15) // 16)):
                raise SystemExit(f"{nom}: tile slot {slot:02X}h holds an object")
            tb[16 * slot:16 * slot + len(b["datos"])] = b["datos"]
            bloques.remove(b)
            marcos[:] = [("baldosas", q, w, h, o + 16 * slot, n, nota + f" (H7: in tile slot {slot:02X}h)") if bl == nom
                         else (bl, q, w, h, o, n, nota) for bl, q, w, h, o, n, nota in marcos]
        bal["datos"] = bytes(tb)
    return bloques, marcos


# ---- output -------------------------------------------------------------------------------------------------
def escribe(m, outdir):
    os.makedirs(outdir, exist_ok=True)
    bloques, marcos = convierte(m)
    tb = tablas()
    for b in bloques:
        open(os.path.join(outdir, b["nombre"] + ".bin"), "wb").write(b["datos"])
    for k, v in tb.items():
        open(os.path.join(outdir, "tabla_" + k + ".bin"), "wb").write(bytes(v))
    lin = ["# the CPC 64 KiB game's graphics in their C64 formats (c64_graficos.py; src/c64/NOTAS_GRAFICOS.md)",
           "name\tcpc_start\tcpc_len\tc64_len\tformat\ttransparent_merge\tflipped_in_place\tnotes"]
    for b in bloques:
        cpc = "-" if b["cpc"] is None else f"{b['cpc']:04X}"
        lin.append(f"{b['nombre']}\t{cpc}\t{b['n']}\t{len(b['datos'])}\t{b['formato']}\t{b['mezcla']}\t{b['giro']}\t{b['notas']}")
    for k, v in tb.items():
        lin.append(f"tabla_{k}\t-\t0\t{len(v)}\ttable built at start-up by the 6502 code\t-\tn\t(written for the host's checks)")
    open(os.path.join(outdir, "graficos64.tsv"), "w").write("\n".join(lin) + "\n")
    lin = ["# every address a pointer of the game can hold into a converted graphics block: CPC value -> C64 offset",
           "block\tcpc_ptr\tw_cpc_bytes\th_lines\tc64_offset\tc64_bytes\tnote"]
    for bl, p, w, h, off, n, nota in sorted(marcos, key=lambda x: (x[0], x[1])):
        lin.append(f"{bl}\t{p:04X}\t{w}\t{h}\t{off}\t{n}\t{nota}")
    open(os.path.join(outdir, "marcos64.tsv"), "w").write("\n".join(lin) + "\n")
    return bloques, marcos, tb


# ---- checks -------------------------------------------------------------------------------------------------
def png(path, scr, pal=(0x06, 0x0E, 0x03, 0x14)):
    import salas64 as S
    w = max(len(r) for r in scr)
    S.write_png(path, [r + [0] * (w - len(r)) for r in scr], list(pal))


def gira_cpc(m, p, w, h):
    """spr_flip_graphics_h on a copy: each line's bytes reversed and each byte's pixels reversed."""
    out = bytearray(m[p:p + w * h])
    for r in range(h):
        fila = out[r * w:(r + 1) * w]
        nueva = []
        for b in reversed(fila):
            px = pens(b)[::-1]
            v = 0
            for i, c in enumerate(px): v |= ((c & 1) << (7 - i)) | (((c >> 1) & 1) << (3 - i))
            nueva.append(v)
        out[r * w:(r + 1) * w] = bytes(nueva)
    return bytes(out)


def gira_c64(data, w, h):
    """The C64 in-place flip: the w nibbles of each line reversed, each nibble's 2 pixels swapped, the padding
    nibble (odd w) kept last."""
    bpr = (w + 1) // 2
    out = bytearray(data)
    for r in range(h):
        nib = [(data[r * bpr + k // 2] >> (4 if k % 2 == 0 else 0)) & 15 for k in range(w)]
        nib = [((n & 3) << 2) | (n >> 2) for n in reversed(nib)]
        if w & 1: nib.append((BITS[0] << 2) | BITS[0])
        for k in range(bpr): out[r * bpr + k] = (nib[2 * k] << 4) | nib[2 * k + 1]
    return bytes(out)


def comprueba(m, outdir, pngdir):
    import salas64 as S, bloques_base as B
    os.makedirs(pngdir, exist_ok=True)
    bloques, marcos, tb = escribe(m, outdir)
    porn = {b["nombre"]: b for b in bloques}
    fallos = 0
    # 1. determinism: a second conversion gives the same bytes
    b2, mc2 = convierte(m)
    if [x["datos"] for x in b2] != [x["datos"] for x in bloques] or mc2 != marcos:
        print("NOT deterministic"); fallos += 1
    h = hashlib.sha256(b"".join(x["datos"] for x in bloques)).hexdigest()[:16]
    print(f"blocks: {len(bloques)}, frames: {len(marcos)}, C64 bytes {sum(len(x['datos']) for x in bloques)}, sha256 {h}")
    # 2. the in-place flips: C64 flip of the converted data == conversion of the CPC flip
    casos = [(0xAA49, 6, 0x28, "puerta")]
    for p, w, hh, bl in casos:              # (the symmetric rule sim; personajes, caras and habitos use trazos, flipped by the C64's code as they are)
        regla = (lambda img: mitad(img, "sim"))
        ref = filas(regla(imagen(m, p, w, hh)), w)
        mm = bytearray(m); mm[p:p + w * hh] = gira_cpc(m, p, w, hh)
        girado = filas(regla(imagen(mm, p, w, hh)), w)
        if gira_c64(ref, w, hh) != girado:
            print(f"flip {bl} {p:04X}: C64 flip != conversion of the CPC flip"); fallos += 1
    print(f"flips checked: {len(casos)} blocks")
    # 3. every frame row: offsets inside their blocks
    for bl, p, w, hh, off, n, _ in marcos:
        if off + n > len(porn[bl]["datos"]): print(f"frame {bl} {p:04X} past its block"); fallos += 1
    # 4. sprite sheet: CPC above, C64 below (decoded, pixels doubled)
    hoja_cpc, hoja_c64 = [[] for _ in range(36)], [[] for _ in range(36)]
    for bl, p, w, hh, off, n, nota in marcos:
        if bl not in ("personajes", "caras", "habitos", "puerta", "baldosas") or "start" in nota or "GARBAGE" in nota: continue
        src = p if bl != "baldosas" else [q for ptr, q, _ in OBJETOS if ptr == p][0]
        a = imagen(m, src, w, min(hh, 36))
        c = de_filas(porn[bl]["datos"][off:off + n], w, hh)
        for y in range(36):
            hoja_cpc[y] += (a[y] if y < len(a) else [0] * (4 * w)) + [0] * 4
            hoja_c64[y] += (sum(([x, x] for x in c[y]), []) if y < hh else [0] * (4 * w)) + [0] * 4
    png(os.path.join(pngdir, "sprites.png"), hoja_cpc + [[1] * len(hoja_cpc[0])] + hoja_c64)
    # 5. room 16h composed with the CPC tiles and masks, and with the C64 tiles and masks; the C64 one
    #    compared with c64_sala's conversion of the composed CPC room
    mem = S.Mem(sys.argv[1]); S.setup(mem)
    t0 = [0] * 4
    def mascara_cpc(tile, pen):
        if tile < 0x0B: return pen
        return None if (tile < 0x80 and pen == 2) or (tile >= 0x80 and pen == 1) else pen
    andA, orA, andB, orB = tb["and_tile_a"], tb["or_tile_a"], tb["and_tile_b"], tb["or_tile_b"]
    tiles = porn["baldosas"]["datos"]
    resumen = []
    for sala in (0x16, 0x00, 0x3B, 0x64, 0x72):
        buf = B.Builder(mem).build(B.room_ptr(mem, sala))
        cpc = [[3] * 256 for _ in range(160)]
        c64 = [bytearray(64) for _ in range(160)]        # bitmap bytes, 32 per line, 4 px each; fill pen 3 = 00
        for (r, c) in B.spiral():
            if not (0 <= r < B.ROWS and 0 <= c < B.COLS): continue
            o = (r * B.COLS + c) * B.CELL
            for tile in (buf[o + 2], buf[o + 5]):
                if not tile: continue
                for line in range(8):
                    y = r * 8 + line
                    for i in range(4):
                        for k, pen in enumerate(pens(m[0x8300 + 32 * tile + line * 4 + i])):
                            v = mascara_cpc(tile, pen)
                            if v is not None: cpc[y][c * 16 + i * 4 + k] = v
                    for col in range(2):
                        g = tiles[16 * tile + col * 8 + line]
                        x = c * 2 + col
                        if tile < 0x0B: c64[y][x] = g
                        elif tile < 0x80: c64[y][x] = (c64[y][x] & andA[g]) | orA[g]
                        else: c64[y][x] = (c64[y][x] & andB[g]) | orB[g]
        c64p = [[PEN[(c64[y][x // 4] >> (6 - 2 * (x % 4))) & 3] for x in range(128)] for y in range(160)]
        ref = [[C.mitad_detalle(cpc, x, y) for x in range(128)] for y in range(160)]
        dif = sum(1 for y in range(160) for x in range(128) if c64p[y][x] != ref[y][x])
        resumen.append(f"{sala:02X}:{dif}")
        if sala == 0x16:
            png(os.path.join(pngdir, "sala16.png"),
                cpc + [[1] * 256] + [sum(([p, p] for p in r), []) for r in c64p] + [[1] * 256] +
                [sum(([p, p] for p in r), []) for r in ref])
    print("rooms, C64 pixels differing from the whole-room conversion (of 20480): " + " ".join(resumen))
    # 6. font and score bar
    fu = porn["fuente"]["datos"]
    texto = "SECRETUM FINIS AFRICAE MANUS SUPRA IDOLUM; NONA: VENID AQUI FRAY GUILLERMO - 0123456789"
    filas_f = []
    for inv in (False, True):
        for r in range(8):
            fila = []
            for ch in texto:
                cc = ord(ch)
                if 0x2D <= cc <= 0x5A:
                    g = fu[4 * (cc - 0x2D) + r // 2]
                    nib = g >> 4 if r % 2 == 0 else g & 15
                else: nib = 0
                v = tb["fuente_nibble"][nib] ^ (0xFF if inv else 0)
                fila += sum(([PEN[(v >> (6 - 2 * k)) & 3]] * 2 for k in range(4)), [])
            filas_f.append(fila)
    png(os.path.join(pngdir, "fuente.png"), filas_f)
    mb = porn["marcador"]["datos"]
    img = []
    for src in (0xC600, 0xD600, 0xE600, 0xF600):
        for l in range(8): img.append(sum((pens(m[src + l * 64 + x]) for x in range(64)), []))
    dec = [[PEN[(mb[(y // 8) * 256 + (x // 4) * 8 + y % 8] >> (6 - 2 * (x % 4))) & 3] for x in range(128)] for y in range(32)]
    png(os.path.join(pngdir, "marcador.png"), img + [[1] * 256] + [sum(([p, p] for p in r), []) for r in dec])
    print(f"renders in {pngdir}; {fallos} failures")
    return fallos


HW = False
C128 = False                                        # --c128: the C128's heads (milestone H10)
COMPLETO = False                                    # --completo: abadia128ks's full game (the PC's tiles, milestone H10)
BALDOSAS128 = os.path.join(AQUI, "..", "data", "completo", "baldosas128.tsv")
CABEZAS_A = False                                   # H7 variant A (--cabezas-a): the head lines as in the normal build
CAB_LINEAS = 10                                     # H7: the head = lines 0-9 of a frame
CAB_MARCOS = [(0xA300, 5), (0xA3B4, 5), (0xA45E, 5), (0xA508, 5), (0xA5B7, 5), (0xA666, 4),
              (0xA6EA, 5), (0xA78A, 5), (0xA82A, 5), (0xA8C5, 4), (0xA93D, 4), (0xA9B5, 4)]


def main():
    global HW, CABEZAS_A, C128, COMPLETO
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(2)
    HW = "--hw" in sys.argv
    C128 = "--c128" in sys.argv
    COMPLETO = "--completo" in sys.argv
    CABEZAS_A = "--cabezas-a" in sys.argv
    m = open(sys.argv[1], "rb").read()[:0x10000]
    if "--comprueba" in sys.argv:
        sys.exit(1 if comprueba(m, sys.argv[2], sys.argv[sys.argv.index("--comprueba") + 1]) else 0)
    bloques, marcos, tb = escribe(m, sys.argv[2])
    print(f"{len(bloques)} blocks, {sum(len(b['datos']) for b in bloques)} C64 bytes (CPC {sum(b['n'] for b in bloques)}), "
          f"{len(marcos)} pointer targets, {len(tb)} tables ({sum(len(v) for v in tb.values())} bytes)")


if __name__ == "__main__":
    main()
