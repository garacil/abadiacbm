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

"""abadia128ks on the P500 against the PC (as corre128.py for the C128): the P500's own disk started in xcbm5x0 as a
player would (c64/video/sesion500.py's Visible: DLOAD"ABADIA" and RUN, the menu with everything on and Spanish, the
parchment, the loader, the stage in bank 1), up to the game's principal_inicio; then at every frame
(game_input_and_mirror's entry) bank 0 and bank 1's data from $1000 (juego.bin.banco1's length) are appended to OUT,
and right after sys_read_keyboard (game_input_and_mirror + 3) the CPC keys of the frame (KEYS: lines "f k k ...", as
arnes.c reads them) are held: their bits cleared in D64_SYS_KEYS_DOWN and, for a new press, in D64_SYS_KEYS_PENDING.
A frame not reached in 30 s ends the run (the game over's wait, or a hang: said so).  compara.py takes its dump as it
takes the C128's.

    corre500.py JUEGO_DIR KEYS FRAMES OUT       (JUEGO_DIR: c64/juego_final/p500; the disk: c64/discop500's .d80)
"""
import os, socket, struct, sys, time
from pathlib import Path
P = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../.."))
sys.path.insert(0, os.path.join(P, "video"))
import sesion500 as S
V, D = S.V, S.D
juego, fteclas, total, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
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
trabajo = Path(out + ".vice"); trabajo.mkdir(parents=True, exist_ok=True)
v = S.Visible(trabajo, warp=True, disk=Path(os.path.join(P, "discop500/abadia128ks_p500.d80")))
o = open(out, "wb")
f = 0
try:
    ab = V.etiquetas(str(S.PRES / "abadia.lbl"))
    v.orden(V.CMD_EXIT); time.sleep(2); v.orden(V.CMD_PING)          # the menu on the screen
    S.tecla_cc65(v, " ")
    D.corre_hasta(v, ab["_musicstart"], limite=900)
    v.orden(V.CMD_EXIT); time.sleep(2); v.orden(V.CMD_PING)
    S.tecla_cc65(v, " ")                                                 # the parchment ended: the game loads
    D.corre_hasta(v, ab["_gameload"], limite=300)
    D.corre_hasta(v, e["principal_inicio"], limite=900)
    bancos = D.bancos(v)
    ram, ram1 = bancos["ram00"], bancos["ram01"]
    lee = lambda b, a, n: v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, a + n - 1, 0, b))[1][2:2 + n]
    escribe = lambda b, a, d: v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, a, a + len(d) - 1, 0, b) + d)
    pf = v.punto(e["game_input_and_mirror"], temporal=False)
    pk = v.punto(e["game_input_and_mirror"] + 3, temporal=False)
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
                escribe(ram, TECLAS, bytes(fila)); escribe(ram, PEND, bytes(pen))
finally:
    o.close()
    try:
        v.orden(V.CMD_QUIT)
    except Exception:
        pass
    if v.xvfb:
        v.xvfb.terminate()
print(f"{min(f, total)} frames dumped to {out}")
