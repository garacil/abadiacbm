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

"""The game's data on the C64 as ca65 source, placed at the addresses of the memory map (H3).

    datos64.py [DIR]     DIR = c64/juego (default: this file's directory)

Inputs: DIR/mapa64.tsv (mapa64.py), DIR/punteros64.tsv (tools/punteros64.py),
data/cpc64/juego/ram.bin (the tape's image of the game), data/c64graf/ (the converted graphics and
marcos64.tsv, c64_graficos.py), c64/datos/paleta.tsv, and the 6502 sources DIR/*.s (their exported routines:
a code pointer of the data becomes the 6502 routine of the same Z80 entry when it exists).
Outputs:
  datos64.s        one segment per block (D_<name>) with its initial bytes: the CPC values with every pointer
                   field rewritten CPC -> C64 (punteros64.tsv), the converted graphics, the palettes as C64
                   colours, zeros for the buffers; the score bar in the bitmap rows 20-23
  juego.cfg        the ld65 configuration: one 64 KiB image from $0000 (zero page, the data segments at their
                   addresses, the code from $0800 up to the first data segment: ld65 fails if the code overflows)
  conversion64.tsv the layout of the graphics the game flips in place (mode graf): block, CPC start, width (CPC
                   bytes), lines, C64 offset; read by juego/m6502/sombra6502.c to convert the CPC memory
The relocation rules are those of punteros64.tsv; juego/m6502/sombra6502.c applies the same ones.
"""
import glob, os, re, sys

D = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__)))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, os.path.join(P, "..", "tools"))
from licencia import cabecera   # noqa: E402  (the GPL header of the generated sources)
G = os.path.join(P, "..", "data", "c64graf")
BITMAP = 0xE000

def tsv(path):
    for l in open(path):
        if l.startswith("#") or not l.strip(): continue
        yield l.rstrip("\n").split("\t")

def carga():
    mapa = []
    for x in tsv(os.path.join(D, "mapa64.tsv")):
        mapa.append(dict(nombre=x[0], cpc=None if x[1] == "-" else int(x[1], 16), len=int(x[2]), c64=int(x[3], 16),
                         len64=int(x[4]), modo=x[5], zona=x[6], tipo=x[7]))
    punteros = [(int(x[0], 16), x[1], x[2], x[3]) for x in tsv(os.path.join(D, "punteros64.tsv"))]
    marcos = {}
    for x in tsv(os.path.join(G, "marcos64.tsv")):
        if x[0] == "block": continue
        marcos.setdefault(int(x[1], 16), (x[0], int(x[4])))
    return mapa, punteros, marcos

def nombres_codigo():
    """Z80 entry -> name: the tables of the C translation (juego/f_*.c), then data/cpc64/funciones64.tsv"""
    n = {}
    for f in sorted(glob.glob(os.path.join(P, "juego", "f_*.c"))) + [os.path.join(P, "juego", "funciones.c")]:
        for a, nom in re.findall(r'\{ 0x([0-9A-F]{4}), "(\w+)"', open(f).read()): n.setdefault(int(a, 16), nom)
    for x in tsv(os.path.join(P, "..", "data", "cpc64", "funciones64.tsv")):
        if x[0] != "addr64": n.setdefault(int(x[0], 16), x[1])
    return n

def exportados():
    e = set()
    for f in glob.glob(os.path.join(D, "*.s")):
        if os.path.basename(f) == "datos64.s": continue
        for l in open(f):
            m = re.match(r"\s*\.export\s+(.*)", l)
            if m: e.update(x.strip() for x in m.group(1).split(";")[0].split(","))
    return e

class Reubica:
    """CPC value of a pointer field -> C64 value (an int) or a 6502 routine (a str)"""
    def __init__(self, mapa, marcos, codigo, rutinas):
        self.porn = {b["nombre"]: b for b in mapa}
        self.datos = [b for b in mapa if b["cpc"] is not None and b["tipo"] != "graf" and b["zona"] != "bitmap"]
        self.graf = [b for b in mapa if b["tipo"] == "graf" and b["cpc"] is not None]
        self.marcos, self.codigo, self.rutinas = marcos, codigo, rutinas
    def dentro(self, bs, v):
        for b in bs:
            if b["cpc"] <= v < b["cpc"] + b["len"]: return b["c64"] + v - b["cpc"]
        return None
    def __call__(self, destino, marca, v):
        if v == 0: return 0
        if marca == "tagC0" and v >> 8 == 0xC0: return v
        if marca == "bit14":
            r = self(destino, "-", v & ~0x4000)
            if isinstance(r, int) and r & 0x4000: raise SystemExit(f"{destino}: {r:04X} has bit 14 set (it is a flag)")
            return r | (v & 0x4000) if isinstance(r, int) else r
        if destino == "pila": return v
        if destino == "code":
            n = self.codigo.get(v)
            return n if n in self.rutinas else v
        if destino == "gfx":
            if v in self.marcos:
                b, off = self.marcos[v]
                return self.porn[b]["c64"] + off
            r = self.dentro([self.porn["D64_ISO_MIRROR_BUF_GUILLERMO"]], v)
            if r is not None: return r
            for b in self.graf:                    # inside a graphic but not a frame start: half the offset
                if b["cpc"] <= v < b["cpc"] + b["len"]: return b["c64"] + (v - b["cpc"]) // 2
            return v
        if destino == "var":
            r = self.dentro(self.datos, v)
            return v if r is None else r
        bs = [self.porn[n] for n in destino.split("|")]
        r = self.dentro(bs, v)
        if r is None and marca == "virtual" and bs[0]["cpc"] - 0x20 <= v < bs[0]["cpc"]: r = bs[0]["c64"] + v - bs[0]["cpc"]
        return v if r is None else r

def paleta():
    c = {}
    for x in tsv(os.path.join(P, "c64", "datos", "paleta.tsv")): c.setdefault(int(x[0], 16), int(x[2]))
    return c

def main():
    mapa, punteros, marcos = carga()
    ram = open(os.path.join(P, "..", "data", "cpc64", "juego", "ram.bin"), "rb").read()
    reub = Reubica(mapa, marcos, nombres_codigo(), exportados())
    porbloque = {}
    for f, bl, d, mk in punteros: porbloque.setdefault(bl, []).append((f, d, mk))
    pal = paleta()
    s = ["; generated by datos64.py (do not edit): the game's data at their C64 addresses (mapa64.tsv)"]
    importados, segs = set(), []
    def segmento(nombre, dir_, cuerpo, n):
        segs.append((dir_, nombre, n))
        s.append(f'\n.segment "{nombre}"    ; ${dir_:04X}, {n} bytes')
        s.extend(cuerpo)
    def bytes_(data):
        return [".byte " + ",".join(f"${x:02X}" for x in data[i:i + 16]) for i in range(0, len(data), 16)]
    for b in sorted(mapa, key=lambda b: b["c64"]):
        seg = "D_" + b["nombre"].upper()
        if b["zona"] == "bitmap":                  # the score bar: 4 rows of 32 cells (256 bytes), 320 apart
            data = open(os.path.join(G, b["nombre"] + ".bin"), "rb").read()
            for k in range(4): segmento(f"{seg}{k}", b["c64"] + 320 * k, bytes_(data[256 * k:256 * k + 256]), 256)
            continue
        if b["tipo"] == "graf":
            data = open(os.path.join(G, b["nombre"] + ".bin"), "rb").read()
            assert len(data) == b["len64"], b["nombre"]
            segmento(seg, b["c64"], bytes_(data), len(data)); continue
        if b["modo"] == "nada" or b["tipo"] == "buffer":
            segmento(seg, b["c64"], [f".res {b['len64']}, 0"], b["len64"]); continue
        data = bytearray(ram[b["cpc"]:b["cpc"] + b["len"]])
        if b["tipo"] == "conv":                    # the palettes: CPC hardware colours -> C64 colours
            data = bytearray(pal[x] for x in data)
        palabras = {}
        for f, d, mk in porbloque.get(b["nombre"], []):
            v = ram[f] | ram[f + 1] << 8
            r = reub(d, mk, v)
            palabras[f - b["cpc"]] = r
            if isinstance(r, str): importados.add(r)
        cuerpo, i, run = [], 0, bytearray()
        while i < len(data):
            if i in palabras:
                if run: cuerpo.extend(bytes_(run)); run = bytearray()
                r = palabras[i]
                cuerpo.append(f".word {r}" if isinstance(r, str) else f".word ${r:04X}")
                i += 2
            else:
                run.append(data[i]); i += 1
        if run: cuerpo.extend(bytes_(run))
        segmento(seg, b["c64"], cuerpo, len(data))
    if importados: s.insert(1, ".import " + ", ".join(sorted(importados)))
    open(os.path.join(D, "datos64.s"), "w").write(cabecera("asm") + "\n".join(s) + "\n")
    # the ld65 configuration
    codigo_fin = min(a for a, n, l in segs if a >= 0x0800)
    cfg = ["# abadia64ks, the 6502 game: one 64 KiB image from $0000 (generated by datos64.py; do not edit).",
           "# The code (CODE, RODATA, DATA, BSS) runs from $0800 to the first data segment ($%04X)." % codigo_fin,
           "MEMORY {",
           "    ZP:  start = $0000, size = $0100, type = rw, file = %O, fill = yes;",
           "    RAM: start = $0100, size = $FF00, type = rw, file = %O, fill = yes;",
           "}", "SEGMENTS {"]
    hecho_codigo = False
    for a, n, l in sorted(segs):
        if a >= 0x0800 and not hecho_codigo:
            cfg += ["    CODE:     load = RAM, type = rw, start = $0800;",
                    "    RODATA:   load = RAM, type = ro, optional = yes;",
                    "    DATA:     load = RAM, type = rw, optional = yes;",
                    "    BSS:      load = RAM, type = bss, optional = yes;"]
            hecho_codigo = True
        if a < 0x100:
            cfg.append(f"    {n}: load = ZP, type = rw, start = ${a:04X};")
            if not any(x < 0x100 and x > a for x, _, _ in segs):
                cfg.append("    ZEROPAGE: load = ZP, type = zp, optional = yes;")
        else:
            cfg.append(f"    {n}: load = RAM, type = rw, start = ${a:04X};")
    cfg.append("}")
    open(os.path.join(D, "juego.cfg"), "w").write(cabecera("hash") + "\n".join(cfg) + "\n")
    # the layout of the graphics flipped in place, for the host's checks
    conv = ["# graphics converted from the CPC memory at every check (mode graf): block, CPC start, width (CPC bytes), lines, C64 offset,",
            "# the lines the game flips in place as one (generated by datos64.py from data/c64graf/marcos64.tsv)"]
    filas = [x for x in tsv(os.path.join(G, "marcos64.tsv")) if x[0] != "block"]
    for b in mapa:
        if b["modo"] != "graf": continue
        sub = [x[:5] + [x[3]] for x in filas if x[0] == b["nombre"] and "sub-block start" in x[-1]]   # flipped whole
        if not sub:                                # whole frames that tile the block (door, faces: face + second face)
            fr = sorted({(int(x[1], 16), int(x[2]), int(x[3]), int(x[4])) for x in filas if x[0] == b["nombre"]})
            sub, i = [], 0
            while i < len(fr):
                c, w, h, o = fr[i]
                unidad = h
                if b["nombre"] == "caras":         # the faces: flipped in place two at a time (face + second face)
                    unidad = 2 * h
                    while i + 1 < len(fr) and fr[i + 1][0] == c + w * h and fr[i + 1][1] == w:
                        h += fr[i + 1][2]; i += 1
                sub.append(("", "%04X" % c, str(w), str(h), str(o), str(unidad))); i += 1
        for x in sub: conv.append(f"{b['nombre']}\t{x[1]}\t{x[2]}\t{x[3]}\t{x[4]}\t{x[5]}")
    open(os.path.join(D, "conversion64.tsv"), "w").write("\n".join(conv) + "\n")
    print(f"{len(segs)} data segments, {sum(l for a, n, l in segs)} bytes; {len(importados)} code pointers to 6502 routines; code up to ${codigo_fin:04X}")

main()
