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

"""The game's speed in emulated time (the C64 build in x64sc, the C128's in x128: both blocks of RAM, as
cabezas_anda.py): the image started at principal_inicio, the CPC keys of a script held after sys_read_keyboard (KEYS:
lines "f k k ...", as c64/certifica/pc/arnes.c; '-' for none); at every frame mark (game_input_and_mirror's entry)
the frame counted; CIA 2's time-of-day clock (driven by the emulated mains, 1/10 s) zeroed at frame FROM and read at
each frame of MARKS.  Out: the emulated seconds from FROM to each mark.

    mide.py JUEGO_DIR KEYS FROM MARK [MARK...]
"""
import os, socket, struct, sys
P = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../.."))
sys.path.insert(0, os.path.join(P, "plataforma/pruebas")); sys.path.insert(0, os.path.join(P, "juego_final/vice"))
juego, fteclas, desde, marcas = sys.argv[1], sys.argv[2], int(sys.argv[3]), [int(x) for x in sys.argv[4:]]
C128 = os.path.exists(os.path.join(juego, "juego.bin.banco1"))
if C128: os.environ["VICE_EMU"] = "x128"
import vice_mb as V, arranca as A
img = open(os.path.join(juego, "juego.bin"), "rb").read()
e = V.etiquetas(os.path.join(juego, "juego.lbl"))
inc = {}
for l in open(os.path.join(juego, "mapa64.inc") if C128 else os.path.join(P, "juego_final", "mapa64.inc")):
    q = l.split()
    if len(q) >= 3 and q[1] == "=" and q[2].startswith("$"): inc[q[0]] = int(q[2][1:], 16)
teclas = {}
if fteclas != "-":
    for l in open(fteclas):
        x = l.split()
        if x and not x[0].startswith("#"): teclas[int(x[0])] = [int(k) for k in x[1:]]
bcd = lambda x: (x >> 4) * 10 + (x & 15)
with V.Vice(None, ["-sounddev", "dummy", "-warp"], registro="/tmp/mide_vice.log") as v:
    if C128:
        v.hasta(0xC25E, limite=120)
        ram, io = A.banco(v, "ram00"), A.banco(v, "io")
        v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0xFF00, 0xFF00, 0, A.banco(v, "cpu")) + b"\x3e")
        A.escribe_banco(v, ram, 0x0002, img[2:0xFF00]); A.escribe_banco(v, ram, 0xFF05, img[0xFF05:])
        A.escribe_banco(v, A.banco(v, "ram01"), 0x1000, open(os.path.join(juego, "juego.bin.banco1"), "rb").read())
    else:
        v.hasta(0xE5CD, limite=120)
        ram, io = A.banco(v, "ram"), A.banco(v, "io")
        A.escribe_banco(v, ram, 0x0002, img[2:0x10000])
    A.arranca_juego(v, e["principal_inicio"])
    lee = lambda b, a, n: v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, a + n - 1, 0, b))[1][2:2 + n]
    pf = v.punto(e["game_input_and_mirror"], temporal=False)
    pk = v.punto(e["game_input_and_mirror"] + 3, temporal=False) if teclas else None
    f = 0
    while f < max(marcas):
        v.golpes.clear(); v.orden(V.CMD_EXIT)
        v.s.settimeout(60)
        try:
            while not v.golpes: v._respuesta()
        except socket.timeout:
            print(f"stop  frame {f}: no frame mark in 60 s (the game over's wait, or a hang)"); break
        finally:
            v.s.settimeout(None)
        if pf in v.golpes:
            f += 1
            if f == desde:
                for r in (0xDD0B, 0xDD0A, 0xDD09, 0xDD08): A.escribe_banco(v, io, r, b"\x00")   # (hours first: the latch)
            if f in marcas:
                h, m, s, t = (lee(io, a, 1)[0] for a in (0xDD0B, 0xDD0A, 0xDD09, 0xDD08))
                print(f"frames {desde}-{f}: {bcd(h & 0x1F) * 3600 + bcd(m) * 60 + bcd(s) + bcd(t) / 10:.1f} s")
        if pk is not None and pk in v.golpes and teclas.get(f):
            T, PE = inc["D64_SYS_KEYS_DOWN"], inc["D64_SYS_KEYS_PENDING"]
            fila = bytearray(lee(ram, T, 10)); pen = bytearray(lee(ram, PE, 10))
            for k in teclas[f]:
                fila[k >> 3] &= ~(1 << (k & 7)) & 0xFF
                if k not in teclas.get(f - 1, []): pen[k >> 3] &= ~(1 << (k & 7)) & 0xFF
            A.escribe_banco(v, ram, T, bytes(fila)); A.escribe_banco(v, ram, PE, bytes(pen))
