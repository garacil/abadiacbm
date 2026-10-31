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

"""The C64 memory map of the game's data (H3; c64/MAPA.md, c64/NOTAS_MAPA.md).

    mapa64.py [DIR]     DIR = c64/juego (default: this file's directory)

Reads bloques64.tsv (the data blocks, hand-written) and ../../../data/c64graf/graficos64.tsv (the converted
graphics, c64_graficos.py), places every block in its zone and writes:
  mapa64.tsv  name, CPC start, CPC length (decimal), C64 address, C64 length, mode, zone, kind (one row per block;
              read by juego/m6502/sombra6502.c and c64/juego/datos64.py).  Modes: copia (copied CPC -> 6502 and
              compared, pointer fields relocated), graf (a graphic the game flips in place: converted from the CPC
              memory and compared converted), conv (a C64-format constant from the image), nada (neither)
  mapa64.inc  ca65 symbols: every block, every D64_ address of juego/datos_*.h at its C64 address, the code
              area (CODIGO_INICIO, CODIGO_FIN), the CPC screen names at their bitmap addresses
and prints the budget.  Zones: zp from $24 (zp.inc keeps $02-$23), var $0200-$07FF, c4 $C400-$CFFF,
io $D000-$DFFF, hueco = the invisible cells of the bitmap (columns 0-3 and 36-39 of rows 0-23, row 24 and
$FF40-$FFF9: their screen RAM and colour RAM stay black, so their bytes never show), datos = packed down
from $C000; a block that does not fit its zone goes to datos.  The code lives from $0800 to the lowest datos.
"""
import glob, os, re, sys

D = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__)))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, os.path.join(P, "..", "tools"))
from licencia import cabecera   # noqa: E402  (the GPL header of the generated sources)
BITMAP = 0xE000
CODIGO = 0x0800
ARRIBA = 0xC000
MARCADOR = BITMAP + 320 * 20 + 32      # the score bar: bitmap rows 20-23, cells 4-35 (4 runs of 256 bytes, 320 apart)
TABLAS_C4 = ["tabla_and_tile_a", "tabla_or_tile_a", "tabla_and_tile_b", "tabla_or_tile_b"]
# graphics that also go under the I/O, after the tiles (read and flipped only with the I/O switched off)
BAJO_IO = ["caras", "puerta", "luz", "romanos"]
RESERVA_VAR = 96                       # bytes of $0200-$07FF kept free for the 6502 code's own variables

def carga():
    b = []
    for l in open(os.path.join(D, "bloques64.tsv")):
        if l.startswith("#") or not l.strip(): continue
        x = l.rstrip("\n").split("\t")
        b.append(dict(nombre=x[0], cpc=None if x[1] == "-" else int(x[1], 16), len=int(x[2]), tipo=x[3], zona=x[4],
                      modo=x[5], alin=int(x[6]), len64=int(x[2])))
    g = os.path.join(P, "..", "data", "c64graf", "graficos64.tsv")
    if os.path.exists(g):
        for l in open(g):
            if l.startswith("#") or l.startswith("name") or not l.strip(): continue
            x = l.rstrip("\n").split("\t")
            # the tiles (with the objects kept in free tile slots) are read only while the I/O is off: $D000; the
            # score bar goes straight into the bitmap; the tiles' merge tables at $C400 (page-aligned), the
            # other 256-byte tables page-aligned in datos
            zona, alin = "datos", 1
            if x[0] == "baldosas": zona = "$D000"
            elif x[0] in BAJO_IO: zona = "io"
            elif x[0] == "marcador": zona = "bitmap"
            elif x[0] in TABLAS_C4: zona = "$%04X" % (0xC400 + 0x100 * TABLAS_C4.index(x[0]))
            elif x[0].startswith("tabla_") and int(x[3]) == 256: alin = 256
            elif x[0].startswith("tabla_"): zona = "hueco"
            # the graphics the game flips in place are converted from the CPC memory at every check (mode graf)
            modo = "graf" if x[6].startswith("y") else "conv"
            b.append(dict(nombre=x[0], cpc=None if x[1] in ("-", "") else int(x[1], 16), len=int(x[2] or 0), tipo="graf",
                          zona=zona, modo=modo, alin=alin, len64=int(x[3])))
    return b

def huecos():
    """the invisible bytes of the bitmap: (start, length), in address order"""
    h = [(BITMAP, 32)]
    for r in range(23): h.append((BITMAP + 320 * r + 288, 64))
    h.append((BITMAP + 320 * 23 + 288, 0xFFFA - (BITMAP + 320 * 23 + 288)))
    return h

def coloca(bloques):
    usado = []                                   # (start, end) taken
    def libre(a, n):
        return all(a + n <= s or a >= e for s, e in usado)
    def toma(b, a):
        b["c64"] = a; usado.append((a, a + b["len64"]))
        x = a + b["len64"] - sum(s["len64"] for s in b.get("siguen", []))
        for s in b.get("siguen", []):            # the blocks of zone 'sigue' follow it
            s["c64"] = x; usado.append((x, x + s["len64"])); x += s["len64"]
    # a block of zone 'sigue' is placed right after the previous one: the leader carries their length
    lider = None
    for b in bloques:
        if b["zona"] == "sigue":
            lider.setdefault("siguen", []).append(b); lider["len64"] += b["len64"]
        else: lider = b
    for b in bloques:
        if b.get("siguen"):
            b["len_propio"] = b["len64"] - sum(s["len64"] for s in b["siguen"])
    bloques[:] = [b for b in bloques if b["zona"] != "sigue"] + [b for b in bloques if b["zona"] == "sigue"]
    fuera = []
    for b in bloques:                            # fixed addresses
        if b["zona"].startswith("$"): toma(b, int(b["zona"][1:], 16))
        elif b["zona"] == "bitmap": b["c64"] = MARCADOR        # inside the visible bitmap: no room taken
    def secuencial(zona, ini, fin):
        a = ini
        for b in bloques:
            if b["zona"] != zona: continue
            al = b["alin"]
            x = a
            while True:
                x = (x + al - 1) // al * al
                if x + b["len64"] > fin: fuera.append(b); break
                if libre(x, b["len64"]): toma(b, x); a = x + b["len64"]; break
                x += 1
    secuencial("zp", 0x24, 0x100)
    secuencial("var", 0x0200, 0x0800)
    secuencial("c4", 0xC400, 0xD000)
    secuencial("io", 0xD000, 0xE000)
    hs = [[a, n] for a, n in huecos()]           # the invisible cells: biggest blocks first, first fit
    for b in sorted([b for b in bloques if b["zona"] == "hueco"], key=lambda b: (-b["len64"], b["cpc"] or 0)):
        for h in hs:
            if h[1] >= b["len64"]:
                toma(b, h[0]); h[0] += b["len64"]; h[1] -= b["len64"]; break
        else: fuera.append(b)
    for b in fuera: b["zona_pedida"] = b["zona"]; b["zona"] = "datos"
    # what is left of the invisible cells, of $0200-$07FF (keeping RESERVA_VAR), of $C400-$CFFF and of $D000-$DFFF
    # takes datos blocks, biggest first, best fit (not the robes: their pointers' bit 14 is a flag, they stay in
    # $8000-$BFFF; not what is read with the I/O on: only graphics go under the I/O)
    def resto(ini, fin, reserva=0):
        tope = max([b["c64"] + b["len64"] for b in bloques if b.get("c64") is not None and ini <= b["c64"] < fin] + [ini])
        return [tope, fin - reserva - tope, ini]
    hs += [resto(0x200, 0x800, RESERVA_VAR), resto(0xC400, 0xD000), resto(0xD000, 0xE000)]
    for b in sorted([b for b in bloques if b["zona"] == "datos" and "c64" not in b and b["nombre"] != "habitos" and not b.get("siguen") and b["alin"] == 1],
                    key=lambda b: (-b["len64"], b["cpc"] or 0)):
        cabe = [h for h in hs if h[1] >= b["len64"] and (len(h) < 3 or h[2] != 0xD000 or b["tipo"] == "graf")]
        if not cabe: continue
        h = min(cabe, key=lambda h: h[1])
        b["zona_pedida"] = "datos"
        b["zona"] = {0x200: "var", 0xC400: "c4", 0xD000: "io"}.get(h[2], "hueco") if len(h) > 2 else "hueco"
        toma(b, h[0]); h[0] += b["len64"]; h[1] -= b["len64"]
    # datos: down from $C000; aligned ones first, then the graphics (the robe pointers' bit 14 is a flag: the
    # graphics must stay in $8000-$BFFF), then by CPC address from the top
    a = ARRIBA
    resto = [b for b in bloques if b["zona"] == "datos" and "c64" not in b]
    for b in sorted(resto, key=lambda b: (-b["alin"], 0 if b["tipo"] == "graf" else 1, -(b["cpc"] or 0x10000))):
        x = a - b["len64"]
        x -= x % b["alin"]
        while not libre(x, b["len64"]): x -= b["alin"]
        toma(b, x); a = min(a, x)
    for b in bloques:
        if b["nombre"] == "habitos" and not 0x8000 <= b["c64"] < 0xC000:
            raise SystemExit(f"{b['nombre']} at {b['c64']:04X}: the robes must stay in $8000-$BFFF (bit 14 of their pointers is a flag)")
        if "len_propio" in b: b["len64"] = b.pop("len_propio")
    return a, fuera

def nombres_d64():
    n = {}
    for f in sorted(glob.glob(os.path.join(P, "juego", "datos_*.h"))):
        for l in open(f):
            m = re.match(r"#define\s+(D64_\w+)\s+0x([0-9A-Fa-f]{1,4})u?\b", l)
            if m: n.setdefault(m.group(1), int(m.group(2), 16))
    return n

# names whose value is a constant (opcode, size, a cursor position), not an address
CONSTANTES = re.compile(r"(?<!D64_SPR_RECT)_SIZE$|^D64_OP_|^D64_ISO_INSN_|^D64_BIT[0-9]_HL$|^D64_ISO_DARK_FLOOR$|"
                        r"^D64_TXT_STRIP_CURSOR$|^D64_TXT_CURSOR_HOUR_NAME$")

def pantalla(a):
    """CPC screen address (mode 1, 64 bytes a line) -> C64 bitmap byte address and nibble (0 high, 1 low)"""
    linea, fila, xb = (a >> 11) & 7, (a & 0x7FF) >> 6, a & 63
    return BITMAP + 320 * fila + 8 * (xb // 2 + 4) + linea, xb & 1

def main():
    bloques = carga()
    datos_ini, fuera = coloca(bloques)
    o = ["# The game's data on the C64 (generated by mapa64.py from bloques64.tsv and data/c64graf/graficos64.tsv; do not edit).",
         "# name, CPC start, CPC length (decimal), C64 address, C64 length, mode (copia/conv/nada), zone, kind"]
    for b in sorted(bloques, key=lambda b: b["c64"]):
        o.append(f"{b['nombre']}\t{'-' if b['cpc'] is None else '%04X' % b['cpc']}\t{b['len']}\t{b['c64']:04X}\t{b['len64']}\t{b['modo']}\t{b['zona']}\t{b['tipo']}")
    open(os.path.join(D, "mapa64.tsv"), "w").write("\n".join(o) + "\n")
    inc = ["; generated by mapa64.py from bloques64.tsv (do not edit): the game's data at their C64 addresses",
           f"CODIGO_INICIO = ${CODIGO:04X}", f"CODIGO_FIN = ${datos_ini:04X}    ; first byte after the code area"]
    definidos = set()
    for b in sorted(bloques, key=lambda b: b["c64"]):
        nom = b["nombre"] if b["nombre"].startswith("D64_") or b["nombre"].isupper() else "G_" + b["nombre"].upper()
        cpc = "C64 only" if b["cpc"] is None else f"CPC {b['cpc']:04X}h"
        inc.append(f"{nom} = ${b['c64']:04X}    ; {cpc}, {b['len']} -> {b['len64']} bytes, {b['zona']}")
        definidos.add(nom)
    porcpc = [b for b in bloques if b["cpc"] is not None and b["tipo"] != "graf"]
    for n, v in sorted(nombres_d64().items(), key=lambda x: x[1]):
        if n in definidos: continue
        if CONSTANTES.search(n) or v < 0x100 and n != "D64_SYS_STARTUP_DONE":
            inc.append(f"{n} = ${v:02X}    ; a constant"); continue
        for b in porcpc:
            if b["cpc"] <= v < b["cpc"] + b["len"]:
                inc.append(f"{n} = ${b['c64'] + v - b['cpc']:04X}    ; CPC {v:04X}h in {b['nombre']}"); break
        else:
            if v >= 0xC000:
                c, nib = pantalla(v)
                inc.append(f"{n} = ${c:04X}    ; CPC screen {v:04X}h -> bitmap byte{' (low nibble)' if nib else ''}")
            else:
                inc.append(f"; {n}: CPC {v:04X}h is Z80 code or a converted graphic: a 6502 label or a graphics frame (graficos64.tsv)")
    open(os.path.join(D, "mapa64.inc"), "w").write(cabecera("asm") + "\n".join(inc) + "\n")
    def suma(f): return sum(b["len64"] for b in bloques if f(b))
    print(f"code area ${CODIGO:04X}-${datos_ini - 1:04X}: {datos_ini - CODIGO} bytes")
    zonas = {"zp": ("zp",), "var": ("var",), "c4": ("c4",) + tuple("$%04X" % a for a in range(0xC400, 0xD000, 0x100)),
             "io": ("io", "$D000"), "hueco": ("hueco",), "datos": ("datos", "sigue"), "bitmap": ("bitmap",)}
    for z, zs in zonas.items():
        print(f"  zone {z:6s} {suma(lambda b: b['zona'] in zs):6d} bytes")
    for b in fuera: print(f"  {b['nombre']} ({b['len64']} bytes) did not fit zone {b['zona_pedida']}: placed in datos")

main()
