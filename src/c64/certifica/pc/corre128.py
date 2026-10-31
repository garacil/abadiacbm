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

"""abadia128ks in x128 for the certification against the PC (milestone H10, the full game): as
c64/juego_final/vice/cabezas_anda.py the C128 build's image written into both blocks of RAM and started at
principal_inicio; at every frame (game_input_and_mirror's entry) block 0 and block 1's room table are appended to
OUT; right after sys_read_keyboard (game_input_and_mirror + 3) the CPC keys of the frame (KEYS: lines "f k k ...",
as c64/certifica/pc/arnes.c reads them) are held: their bits cleared in D64_SYS_KEYS_DOWN and, for a new press, in
D64_SYS_KEYS_PENDING.  A frame not reached in 30 s ends the run (the game over's wait, or a hang: said so).

    corre128.py JUEGO_DIR KEYS FRAMES OUT
"""
import os, socket, struct, sys
P = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../.."))
sys.path.insert(0, os.path.join(P, "plataforma/pruebas")); sys.path.insert(0, os.path.join(P, "juego_final/vice"))
os.environ["VICE_EMU"] = "x128"
import vice_mb as V
import arranca as A
juego, fteclas, total, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
img = open(os.path.join(juego, "juego.bin"), "rb").read()
b1 = open(os.path.join(juego, "juego.bin.banco1"), "rb").read()
e = V.etiquetas(os.path.join(juego, "juego.lbl"))
inc = {}
for l in open(os.path.join(juego, "mapa64.inc")):
    p = l.split()
    if len(p) >= 3 and p[1] == "=" and p[2].startswith("$"): inc[p[0]] = int(p[2][1:], 16)
TECLAS, PEND = inc["D64_SYS_KEYS_DOWN"], inc["D64_SYS_KEYS_PENDING"]
teclas = {}
for l in open(fteclas):
    x = l.split()
    if x and not x[0].startswith("#"): teclas[int(x[0])] = [int(k) for k in x[1:]]
o = open(out, "wb")
with V.Vice(None, ["-sounddev", "dummy", "-warp"], registro=out + ".vice.log") as v:
    v.hasta(0xC25E, limite=120)                                     # the KERNAL's idle loop
    ram, ram1, io = A.banco(v, "ram00"), A.banco(v, "ram01"), A.banco(v, "io")
    v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0xFF00, 0xFF00, 0, A.banco(v, "cpu")) + b"\x3e")
    A.escribe_banco(v, ram, 0x0002, img[2:0xFF00]); A.escribe_banco(v, ram, 0xFF05, img[0xFF05:])
    A.escribe_banco(v, ram1, 0x1000, b1)
    A.arranca_juego(v, e["principal_inicio"])
    lee = lambda b, a, n: v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, a + n - 1, 0, b))[1][2:2 + n]
    pf = v.punto(e["game_input_and_mirror"], temporal=False)
    pk = v.punto(e["game_input_and_mirror"] + 3, temporal=False)
    f = 0
    while True:
        v.golpes.clear()
        v.orden(V.CMD_EXIT)
        v.s.settimeout(30)
        try:
            while not v.golpes: v._respuesta()
        except socket.timeout:
            print(f"stop  frame {f}: no frame point in 30 s (the game over's wait, or a hang)"); break
        finally:
            v.s.settimeout(None)
        if pf in v.golpes:
            f += 1
            if f > total: break
            o.write(lee(ram, 0x0000, 0x8000) + lee(ram, 0x8000, 0x8000) + lee(ram1, 0x1000, len(b1)))
        if pk in v.golpes:
            t, antes = teclas.get(f, []), teclas.get(f - 1, [])
            if t:
                fila = bytearray(lee(ram, TECLAS, 10)); pen = bytearray(lee(ram, PEND, 10))
                for k in t:
                    fila[k >> 3] &= ~(1 << (k & 7)) & 0xFF
                    if k not in antes: pen[k >> 3] &= ~(1 << (k & 7)) & 0xFF
                A.escribe_banco(v, ram, TECLAS, bytes(fila)); A.escribe_banco(v, ram, PEND, bytes(pen))
o.close()
print(f"{min(f, total)} frames dumped to {out}")
