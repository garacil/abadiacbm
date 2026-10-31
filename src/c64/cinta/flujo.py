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

"""The file "juego" of the disk: the game's image as the stream the loader reads (c64/presentacion/cargador.s), loaded
under the picture (c64/cinta/FLUJO.md, "The stream").

    flujo.py OUT.prg [--sin-compresion] [--juego DIR] [--cargador LBL] [--imagen KOA] [--informe FILE]

--juego: the game's C64 build (default c64/juego_final/c64: juego.bin, juego.map, juego.lbl); --cargador: the
loader's label file (default c64/presentacion/generado/cargador.lbl); --imagen: the picture on the screen while it
loads (default abadia.koa, c64/presentacion/original/graphics/abadia.koa); --sin-compresion: the data as
literal runs only (to measure the load time without compression).  The stream is checked at once by a model of the
loader written from cargador.s (modelo()): the memory it leaves must equal the game's image over every byte the game
needs, and the picture must stay on the screen until the end (its side cells until the mark).  Deterministic.

What is loaded: every byte of the game's segments (juego.map: code, data, the variables' initial values) but the
BSS and the merge tables (D_TABLA_*: rebuilt by the game's start-up, vid_init_stub 3607); not the zero page
$02-$23 and $9E-$FF, the stack page, $079D-$07FF, $7079-$7150, the screen RAM, $C800-$C86F, $CFFD-$CFFF,
$DFEA-$DFFF, the bitmap's free bytes and the vectors (the game needs none of them: c64/cinta/libres.py), nor the
play area (rows 0-19, cells 4-35: zeros, cleared by the loader at the end).  Held aside during the load (the
KERNAL and the picture use their places): $0200-$03FF, $0090-$009D, the score bar (rows 20-23, cells 4-35).

The order: first every byte whose place is not shown (all but the bitmap of the picture's side cells), then the mark
(the loader blackens the side cells: columns 0-3 and 36-39 of rows 0-23, row 24), then the bytes of the side cells'
bitmap (the game's data that lives there), each part in the order of the game's addresses.
"""
import os, re, subprocess, sys, tempfile

D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
KOALA = os.path.join(P, "c64", "presentacion", "original", "graphics", "abadia.koa")
MARCA = 1                           # the mark's address in the stream: the side cells blackened


def etiquetas(lbl):
    out = {}
    for linea in open(lbl):
        t = linea.split()
        if len(t) == 3 and t[0] == "al":
            out[t[2].lstrip(".")] = int(t[1].split(":")[-1], 16)
    return out


def segmentos_mapa(mapa):
    out, dentro = [], False
    for linea in open(mapa):
        if linea.startswith("Segment list"):
            dentro = True
            continue
        if dentro:
            t = linea.split()
            if len(t) >= 4 and re.fullmatch(r"[0-9A-F]{6}", t[1]):
                out.append((t[0], int(t[1], 16), int(t[2], 16)))
            elif linea.startswith("Exports"):
                break
    return out


def marcador(a):
    """the score bar's row (0-3) of bitmap address a, or None: rows 20-23, cells 4-35"""
    if 0xE000 + 20 * 320 <= a < 0xE000 + 24 * 320:
        x = (a - 0xE000) % 320
        if 32 <= x < 288:
            return (a - 0xE000) // 320 - 20
    return None


def area_juego(a):
    return 0xE000 <= a < 0xE000 + 20 * 320 and 32 <= (a - 0xE000) % 320 < 288


def lado(a):
    """a bitmap byte of the picture's side cells: columns 0-3 and 36-39 of rows 0-23, and row 24"""
    if not 0xE000 <= a < 0xE000 + 8000:
        return False
    fila, col = (a - 0xE000) // 320, (a - 0xE000) % 320 // 8
    return fila == 24 or col < 4 or col >= 36


def celda_lado(i):
    """cell i (0-999) is a side cell"""
    return i // 40 == 24 or i % 40 < 4 or i % 40 >= 36


def necesarios(mapa):
    """the game's bytes the stream loads: the segments but BSS and the merge tables"""
    nec = bytearray(0x10000)
    for n, s, e in segmentos_mapa(mapa):
        if n == "BSS" or n.startswith("D_TABLA_"):
            continue
        nec[s:e + 1] = b"\1" * (e - s + 1)
    return nec


def destino(a, c):
    """where the loader puts the game's byte a during the load"""
    if 0x0200 <= a < 0x0300:
        return c["PAGINA2"] + a - 0x0200
    if 0x0300 <= a < 0x0400:
        return c["PAGINA3"] + a - 0x0300
    if 0x90 <= a < 0x9E:
        return c["ZP_KERNAL"] + a - 0x90
    f = marcador(a)
    if f is not None:
        return c["MARCADOR"] + 256 * f + (a - 0xE000) % 320 - 32
    return a


def datos(img, nec, c, literal, tmp):
    """the data: the segments (runs of consecutive destinations) of the hidden places, the mark, the segments of the
    side cells; compressed by lz64 -> (bytes, the load-time image, the segments, lz64's report)"""
    carga = bytearray(0x10000)
    ocultos, lados = [], []
    for a in range(0x10000):
        if not nec[a]:
            continue
        d = destino(a, c)
        assert not (0x90 <= d < 0x100 or 0x200 <= d < 0x400 or 0x02 <= d < 0x24 or 0x100 + 14 <= d < 0x200
                    or 0xC000 <= d < 0xC3E8 or 0xC3E8 <= d < 0xC700 or area_juego(d) or marcador(d) is not None), \
            f"{a:04X} -> {d:04X}"
        carga[d] = img[a]
        segs = lados if lado(d) else ocultos
        if segs and segs[-1][0] + segs[-1][1] == d:
            segs[-1][1] += 1
        else:
            segs.append([d, 1])
    segs = ocultos + [[MARCA, 0]] + lados
    fseg = os.path.join(tmp, "segmentos.txt")
    with open(fseg, "w") as f:
        for d, n in segs:
            f.write(f"{d:04X} {n}\n")
    fimg, fout = os.path.join(tmp, "carga.bin"), os.path.join(tmp, "datos.bin")
    open(fimg, "wb").write(carga)
    lz = os.path.join(tmp, "lz64")
    subprocess.run(["gcc", "-O2", "-std=c99", "-o", lz, os.path.join(D, "lz64.c")], check=True)
    r = subprocess.run([lz, fimg, fseg, fout] + (["--literal"] if literal else []), check=True,
                       capture_output=True, text=True).stdout.strip()
    return open(fout, "rb").read(), carga, segs, r


def modelo(fichero, inicial, color):
    """the loader of cargador.s on the file's bytes, from the memory gameload leaves (`inicial`, 64 KiB; `color`, the
    colour RAM's 1000 nibbles) -> dict: mem (the memory before the end's copies), color, marca (the memory, the colour
    RAM and the bytes read at the mark), leidos (the file's bytes read), salto, unidad"""
    m = bytearray(inicial)
    col = bytearray(color)
    k = 0
    suma = 0
    out = {}
    def crudo():
        nonlocal k, suma
        b = fichero[k]; k += 1
        suma = (suma + b) & 0xFFFF
        return b
    bits = 0x80
    def bit():
        nonlocal bits
        bits <<= 1
        cb = bits >> 8 & 1
        bits &= 0xFF
        if bits == 0:
            b = crudo()
            cb = b >> 7
            bits = (b << 1 | 1) & 0xFF
        return cb
    def gamma():
        v = 1
        while not bit():
            v = v << 1 | bit()
        return v
    crudo(); crudo()
    out["salto"] = crudo() | crudo() << 8
    out["unidad"] = crudo() | crudo() << 8
    while True:
        dst = crudo() | crudo() << 8
        if dst == 0:
            break
        if dst == MARCA:
            out["marca"] = dict(mem=bytes(m), color=bytes(col), leidos=k)
            for i in range(1000):
                if celda_lado(i):
                    m[0xC000 + i] = 0
                    col[i] = 0
            continue
        while True:
            if not bit():
                for _ in range(gamma()):
                    m[dst] = crudo(); dst = (dst + 1) & 0xFFFF
            else:
                h = gamma()
                if h > 256:
                    break
                ofs = (h - 1) << 8 | crudo()
                src = (dst - ofs) & 0xFFFF
                for _ in range(gamma() + 1):
                    m[dst] = m[src]; dst = (dst + 1) & 0xFFFF; src = (src + 1) & 0xFFFF
    esperada = suma
    assert crudo() | crudo() << 8 == esperada, "checksum"
    assert k == len(fichero)
    out.update(mem=bytes(m), color=bytes(col), leidos=k)
    return out


def final(mem, c, unidad):
    """the loader's end on the memory: the score bar's rows, pages 2 and 3, the play area cleared, the zero page"""
    m = bytearray(mem)
    for src, dst in [(c["MARCADOR"], 0xF920), (c["MARCADOR"] + 256, 0xFA60), (c["MARCADOR"] + 512, 0xFBA0),
                     (c["MARCADOR"] + 768, 0xFCE0), (c["PAGINA2"], 0x0200), (c["PAGINA3"], 0x0300)]:
        m[dst:dst + 256] = m[src:src + 256]
    for f_ in range(20):
        a = 0xE020 + 320 * f_
        m[a:a + 256] = bytes(256)
    m[0x90:0x9E] = m[c["ZP_KERNAL"]:c["ZP_KERNAL"] + 14]
    m[0x9E:0x100] = bytes(0x62)
    m[0x02:0x24] = bytes(0x22)
    m[unidad] = 8                                          # (the drive the model loads from)
    return m


def koala(ruta=KOALA):
    """abadia.koa: the file is the 10000 bytes alone (bitmap, screen RAM, colour RAM), as abadia.c reads it"""
    k = open(ruta, "rb").read()
    assert len(k) == 10000, ruta
    return k[:8000], k[8000:9000], bytes(x & 15 for x in k[9000:10000])


def inicial_presentacion(ruta=KOALA):
    """the memory as the presentation leaves it for the loader (presentacion.c's gameload): a pattern everywhere
    (what is there does not matter), abadia.koa's bitmap at $E000 and screen RAM at $C000; and the colour RAM"""
    bm, pant, col = koala(ruta)
    m = bytearray((i * 7 + 0x5A) & 0xFF for i in range(0x10000))
    m[0xE000:0xE000 + 8000] = bm
    m[0xC000:0xC000 + 1000] = pant
    return m, col


def imagen_intacta(mem, color, ruta=KOALA, celdas=range(1000)):
    """the cells of the picture (bitmap, screen RAM, colour RAM) that differ from abadia.koa, among `celdas`"""
    bm, pant, col = koala(ruta)
    return [i for i in celdas if mem[0xE000 + 8 * i:0xE008 + 8 * i] != bm[8 * i:8 * i + 8]
            or mem[0xC000 + i] != pant[i] or color[i] & 15 != col[i]]


def main():
    args = sys.argv[1:]
    def opcion(nombre, defecto):
        if nombre in args:
            i = args.index(nombre)
            v = args[i + 1]
            del args[i:i + 2]
            return v
        return defecto
    literal = "--sin-compresion" in args
    if literal:
        args.remove("--sin-compresion")
    juego = opcion("--juego", os.path.join(P, "c64", "juego_final", "c64"))
    lblc = opcion("--cargador", os.path.join(P, "c64", "presentacion", "generado", "cargador.lbl"))
    ruta_koa = opcion("--imagen", KOALA)
    informe = opcion("--informe", None)
    salida = args[0]
    img = open(os.path.join(juego, "juego.bin"), "rb").read()
    e = etiquetas(os.path.join(juego, "juego.lbl"))
    c = etiquetas(lblc)
    nec = necesarios(os.path.join(juego, "juego.map"))
    # bytes of the image the stream does not carry must be zero (they are: the image is the segments, zero filled)
    fuera = [a for a in range(2, 0x10000) if not nec[a] and img[a] and not 0xBB00 <= a < 0xC800 and not 0xEA06 <= a < 0xEA16]
    assert not fuera, "image bytes outside what is loaded: " + " ".join(f"{a:04X}" for a in fuera[:20])
    with tempfile.TemporaryDirectory() as tmp:
        dat, carga, segs, r = datos(img, nec, c, literal, tmp)
    cab = bytes([e["principal_inicio"] & 255, e["principal_inicio"] >> 8, e["plat_unidad"] & 255, e["plat_unidad"] >> 8])
    cuerpo = bytes([0x00, 0xC0]) + cab + dat
    suma = sum(cuerpo) & 0xFFFF
    fichero = cuerpo + bytes([suma & 255, suma >> 8])
    open(salida, "wb").write(fichero)
    # the check: the model of the loader on the file
    m0, col0 = inicial_presentacion(ruta_koa)
    mo = modelo(fichero, m0, col0)
    m = final(mo["mem"], c, mo["unidad"])
    malos = [a for a in range(0x10000) if nec[a] and m[a] != img[a]]
    ok_juego = not malos and mo["salto"] == e["principal_inicio"]
    antes = imagen_intacta(mo["marca"]["mem"], mo["marca"]["color"], ruta_koa)
    centro = imagen_intacta(mo["mem"], mo["color"], ruta_koa, [i for i in range(1000) if not celda_lado(i)])
    negras = [i for i in range(1000) if celda_lado(i) and (mo["mem"][0xC000 + i] or mo["color"][i])]
    lados_n = sum(n for d, n in segs if lado(d))
    lineas = [
        f"game image: {os.path.join(juego, 'juego.bin')}; {sum(nec)} bytes loaded in {len(segs) - 1} segments ({r})",
        f"stream: {len(fichero)} bytes (data {len(dat)}{' literal' if literal else ''}, header and checksum 8); the mark "
        f"after {mo['marca']['leidos']} bytes ({100 * mo['marca']['leidos'] / len(fichero):.1f} % of the file), then the "
        f"{lados_n} bytes of the side cells' bitmap",
        f"model of the loader: {'the game image exact over the ' + str(sum(nec)) + ' bytes' if ok_juego else str(len(malos)) + ' bytes wrong: ' + ' '.join(f'{a:04X}' for a in malos[:16])}; "
        f"the picture {'intact' if not antes else 'CHANGED in ' + str(len(antes)) + ' cells'} at the mark, its 768 "
        f"middle cells {'intact' if not centro else 'CHANGED in ' + str(len(centro))} at the end of the data, the 232 "
        f"side cells {'black' if not negras else 'NOT BLACK: ' + str(len(negras))} after the mark",
    ]
    for l in lineas:
        print(l)
    if informe:
        open(informe, "w").write("\n".join(lineas) + "\n")
    if not (ok_juego and not antes and not centro and not negras):
        sys.exit(1)


if __name__ == "__main__":
    main()
