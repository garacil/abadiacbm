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

"""The game's blocks of the tape (c64/cinta/NOTAS.md): the stream of the Spanish image (as c64/cinta/flujo.py
makes it, literal runs, with a third header address: the game's plat_opciones) cut at the mark into the blocks
ID_JUEGO and ID_JUEGO2, and the English texts' block ID_TEXTOS_EN: the bytes the English image has different,
segments of the same format with their own checksum.  Checked at once by a model of the tape's loader
(c64/presentacion/cargador.s -D CINTA): the memory it leaves must equal the Spanish image over every byte the
game needs, and with the English block the English image; the two images must have the same layout (the same
segments, every label at the same address but the ones inside game_check_end).

    flujo_cinta.py ES_DIR EN_DIR CARGADOR_LBL OUT_DIR [--disco]
        (ES_DIR, EN_DIR: c64/juego_final/c64cinta, c64cinta_en; CARGADOR_LBL: the tape loader's labels)
Writes OUT_DIR/juego1.bin, juego2.bin, textos_en.bin and informe.txt.  Deterministic.
--disco: the C64's disk with the tape's menu (c64/disco64: c64disco, c64disco_en, the loader -D DISCO): the stream
whole in OUT_DIR/juego.bin (the file JUEGO: no tape block to cut), the English block in textos_en.bin (TEXTOS)."""
import os, subprocess, sys, tempfile
D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, os.path.join(P, "c64", "cinta"))
import flujo as F                                     # noqa: E402

DENTRO_GCE = {"cert_pausa2"}                          # the labels inside game_check_end (principal.s: its strings)


def lz64(img, segs, tmp, nombre):
    """segments [(dst, n)] of img (64 KiB, the bytes at their destinations) as lz64's literal stream"""
    fseg, fimg, fout = (os.path.join(tmp, nombre + x) for x in (".seg", ".img", ".out"))
    with open(fseg, "w") as f:
        for d, n in segs:
            f.write(f"{d:04X} {n}\n")
    open(fimg, "wb").write(img)
    lz = os.path.join(tmp, "lz64")
    if not os.path.exists(lz):
        subprocess.run(["gcc", "-O2", "-std=c99", "-o", lz, os.path.join(P, "c64", "cinta", "lz64.c")], check=True)
    subprocess.run([lz, fimg, fseg, fout, "--literal"], check=True, capture_output=True)
    return open(fout, "rb").read()


def modelo(fichero, textos, inicial, color):
    """the tape's cargador.s on the game's stream and, if `textos`, the English block -> dict as flujo.modelo"""
    m = bytearray(inicial)
    col = bytearray(color)
    out = {}
    datos = fichero
    k = 0
    suma = 0
    bits = 0x80

    def crudo():
        nonlocal k, suma
        b = datos[k]; k += 1
        suma = (suma + b) & 0xFFFF
        return b

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

    def segmentos():
        while True:
            dst = crudo() | crudo() << 8
            if dst == 0:
                return
            if dst == F.MARCA:
                out["marca"] = dict(mem=bytes(m), color=bytes(col), leidos=k)
                for i in range(1000):
                    if F.celda_lado(i):
                        m[0xC000 + i] = 0
                        col[i] = 0
                continue
            while True:
                if not bit():
                    for _ in range(gamma()):
                        m[dst] = crudo(); dst = (dst + 1) & 0xFFFF
                else:
                    assert gamma() == 257, "a copy token in a literal stream"
                    break

    crudo(); crudo()
    out["salto"] = crudo() | crudo() << 8
    out["unidad"] = crudo() | crudo() << 8
    out["opciones"] = crudo() | crudo() << 8
    out["paso"] = crudo() | crudo() << 8
    out["pitido"] = crudo() | crudo() << 8
    segmentos()
    esperada = suma
    assert crudo() | crudo() << 8 == esperada, "the game's checksum"
    assert k == len(fichero)
    if textos is not None:
        datos, k, suma, bits = textos, 0, 0, 0x80
        segmentos()
        esperada = suma
        assert crudo() | crudo() << 8 == esperada, "the texts' checksum"
        assert k == len(textos)
    out.update(mem=bytes(m), color=bytes(col))
    return out


def main():
    disco = "--disco" in sys.argv
    es, en, lblc, sal = [a for a in sys.argv[1:] if a != "--disco"][:4]
    os.makedirs(sal, exist_ok=True)
    img = open(os.path.join(es, "juego.bin"), "rb").read()
    img_en = open(os.path.join(en, "juego.bin"), "rb").read()
    e, e_en = F.etiquetas(os.path.join(es, "juego.lbl")), F.etiquetas(os.path.join(en, "juego.lbl"))
    c = F.etiquetas(lblc)
    seg_es, seg_en = F.segmentos_mapa(os.path.join(es, "juego.map")), F.segmentos_mapa(os.path.join(en, "juego.map"))
    assert seg_es == seg_en, "the English image's segments differ from the Spanish ones"
    otras = sorted(n for n in set(e) | set(e_en) if e.get(n) != e_en.get(n) and n not in DENTRO_GCE)
    assert not otras, "labels at other addresses in English: " + " ".join(otras)
    nec = F.necesarios(os.path.join(es, "juego.map"))
    fuera = [a for a in range(2, 0x10000) if not nec[a] and (img[a] or img_en[a])
             and not 0xBB00 <= a < 0xC800 and not 0xEA06 <= a < 0xEA16]
    assert not fuera, "image bytes outside what is loaded: " + " ".join(f"{a:04X}" for a in fuera[:20])
    with tempfile.TemporaryDirectory() as tmp:
        dat, carga, segs, r = F.datos(img, nec, c, True, tmp)
        # the English block: the differing bytes at their load-time destinations, consecutive ones in one segment
        carga_en = bytearray(0x10000)
        segs_en = []
        dif = [a for a in range(0x10000) if nec[a] and img[a] != img_en[a]]
        for a in dif:
            d = F.destino(a, c)
            carga_en[d] = img_en[a]
            if segs_en and segs_en[-1][0] + segs_en[-1][1] == d:
                segs_en[-1][1] += 1
            else:
                segs_en.append([d, 1])
        dat_en = lz64(bytes(carga_en), segs_en, tmp, "textos_en")
    cab = b"".join(bytes([v & 255, v >> 8]) for v in (e["principal_inicio"], e["plat_unidad"], e["plat_opciones"],
                                                      e["cinta_paso"], e["cinta_pitido"]))
    cuerpo = bytes([0x00, 0xC0]) + cab + dat
    suma = sum(cuerpo) & 0xFFFF
    fichero = cuerpo + bytes([suma & 255, suma >> 8])
    suma_en = sum(dat_en) & 0xFFFF
    textos = dat_en + bytes([suma_en & 255, suma_en >> 8])
    m0, col0 = F.inicial_presentacion()
    fallos = []
    for idioma, tx, ref in (("Spanish", None, img), ("English", textos, img_en)):
        mo = modelo(fichero, tx, m0, col0)
        m = F.final(mo["mem"], c, mo["unidad"])
        m[mo["unidad"]] = 1                             # (the tape: cargador.s writes 1)
        m[mo["opciones"]] = ref[mo["opciones"]]         # (the menu's options: the image's 0)
        malos = [a for a in range(0x10000) if nec[a] and m[a] != ref[a] and a != mo["unidad"]]
        if (mo["paso"], mo["pitido"]) != (e["cinta_paso"], e["cinta_pitido"]) or img[e["cinta_paso"]] != 0x17 \
                or img[e["cinta_pitido"]] != 0x54:
            fallos.append("the header's sound notes are not the footstep's (17h) and the beep's (54h)")
        if malos or mo["salto"] != e["principal_inicio"]:
            fallos.append(f"{idioma}: {len(malos)} bytes wrong: " + " ".join(f"{a:04X}" for a in malos[:16]))
        if idioma == "Spanish":
            corte = mo["marca"]["leidos"]                # the first block ends with the mark's address
            antes = F.imagen_intacta(mo["marca"]["mem"], mo["marca"]["color"])
            centro = F.imagen_intacta(mo["mem"], mo["color"], celdas=[i for i in range(1000) if not F.celda_lado(i)])
            if antes or centro:
                fallos.append(f"the picture changed: {len(antes)} cells before the mark, {len(centro)} in the middle")
    assert fichero[corte - 2:corte] == bytes([F.MARCA, 0]), "the cut is not after the mark"
    if disco:
        open(os.path.join(sal, "juego.bin"), "wb").write(fichero)
    else:
        open(os.path.join(sal, "juego1.bin"), "wb").write(fichero[:corte])
        open(os.path.join(sal, "juego2.bin"), "wb").write(fichero[corte:])
    open(os.path.join(sal, "textos_en.bin"), "wb").write(textos)
    lineas = [
        f"the game (Spanish): {sum(nec)} bytes loaded in {len(segs) - 1} segments; stream {len(fichero)} bytes: "
        f"ID_JUEGO {corte} (to the mark), ID_JUEGO2 {len(fichero) - corte}",
        f"the English texts: {len(dif)} bytes in {len(segs_en)} segments, block {len(textos)} bytes",
        "model of the tape's loader: " + ("the Spanish image exact; with the English block the English image exact"
                                          if not fallos else "; ".join(fallos)),
    ]
    for l in lineas:
        print(l)
    open(os.path.join(sal, "informe.txt"), "w").write("\n".join(lineas) + "\n")
    sys.exit(1 if fallos else 0)


if __name__ == "__main__":
    main()
