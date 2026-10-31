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

"""The pages of the CPC's parchments against the page model of c64/presentacion/datos.py (paginas(), with the CPC's
rule for capitals: no shift): the CPC is the GNU build (juego/gnu/abadia64ks, the tape's parchment code in C, identical
to the CPC simulator frame by frame: juego/gnu/prueba.sh), its screen memory at every 50 Hz frame (--volcado, read
from a pipe).  For each page of the model, in order, a frame must show exactly that page in the text area (x 72-247,
y 16-175: CPC screen bytes 18-61 of those lines; mode 1, pen 0 the paper, pens 2 and 3 the ink): the page complete,
before its page turn.  So the texts the parchment writes (text1.bin's first part, text2.bin) are the CPC's, page
by page; c64/presentacion/pruebas/disco_prueba/prueba.py checks the parchment on the C64 against the same model.

    paginas_cpc.py intro|final [FRAMES]       (default 40000 frames: the whole text, then it stops)
"""
import os, subprocess, sys, tempfile

D = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, D)
sys.dont_write_bytecode = True
import datos as Dt                                                  # noqa: E402

GNU = os.path.join(P, "juego", "gnu", "abadia64ks")
REG = 4 + 1 + 17 + 16 + 0x4000                                      # a frame of --volcado


def esperado(pag):
    """the CPC screen bytes 18-61 of lines 16-175 with the page: pen 0, the ink pen 2 (3 the capitals)"""
    out = bytearray(160 * 44)
    for (x, y), color in pag["tinta"].items():
        if 72 <= x < 248 and 16 <= y < 176:
            pen = 3 if color == 0xA2 else 2
            i = (y - 16) * 44 + (x - 72) // 4
            p = x & 3
            out[i] |= (pen & 1) << (7 - p) | (pen >> 1) << (3 - p)
    return bytes(out)


def zona(pant):
    return b"".join(pant[((y & 7) << 11) + (y >> 3) * 80 + 18:((y & 7) << 11) + (y >> 3) * 80 + 62] for y in range(16, 176))


def main():
    etapa = sys.argv[1]
    frames = int(sys.argv[2]) if len(sys.argv) > 2 else 40000
    pp = open(os.path.join(Dt.ORIGINAL, "pp.bin"), "rb").read()
    gl = Dt.glifos(pp)
    texto = (open(os.path.join(Dt.ORIGINAL, "text1.bin"), "rb").read() if etapa == "intro"
             else Dt.texto_cinta(Dt.etapa("final.bin")))
    pags = Dt.paginas(texto, gl, desplaza=0)
    esp = [esperado(p) for p in pags]
    tmp = tempfile.mkdtemp()
    fifo = os.path.join(tmp, "volcado")
    os.mkfifo(fifo)
    entorno = dict(os.environ, DISPLAY=os.environ.get("DISPLAY", ":99"), SDL_AUDIODRIVER="dummy", XDG_RUNTIME_DIR=tmp)
    proc = subprocess.Popen([GNU, "--etapa", etapa, "--rapido", "--sin-sonido", "--volcado", fifo, "--hasta-perg", str(frames)],
                            cwd=os.path.dirname(GNU), env=entorno, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    vistas, k, n = [], 0, 0
    with open(fifo, "rb") as f:
        while k < len(esp):
            r = f.read(REG)
            if len(r) < REG:
                break
            n += 1
            crtc = r[22:38]
            assert crtc[12] & 0x30 == 0x30 and crtc[13] == 0 and crtc[1] == 40, "not the firmware's screen"
            if zona(r[38:]) == esp[k]:
                vistas.append(int.from_bytes(r[:4], "little"))
                k += 1
    proc.kill()
    proc.wait()
    os.remove(fifo)
    os.rmdir(tmp)
    ok = k == len(esp)
    print(f"{'ok   ' if ok else 'FALLO'} {etapa}: {k} of the model's {len(esp)} pages seen on the CPC (GNU build), "
          f"each exactly, in order, at frames {vistas} ({n} frames read)")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
