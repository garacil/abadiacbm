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

"""The sprites' copy to the screen against the raster beam (to see the sprites well they
must be drawn under control of the screen's raster beam; that is not optional): the C64 game in VICE (as
arranca.py) with Guillermo walking (the keys held as the host's scripts do, as cabezas_anda.py); stopped at every
start and end of spr_blit_to_screen's copy (blit_copia, blit_fin): the raster line there ($D011 bit 7, $D012) and the
rectangle's lines (la_t: the first play-area line L, la_t+1: n; raster line = L + 51).  A copy fails when the beam's
path from the start to the end (forward, modulo 312 lines) meets [L + 51, L + 51 + n).  Deterministic.  The C128
(x128, both blocks of RAM, as cabezas_anda.py): its own copy (logica_a_spr.s la_haz, blit_copia after it).
    haz.py JUEGO_DIR OUT FRAMES"""
import os, socket, struct, sys
P = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../.."))
sys.path.insert(0, os.path.join(P, "plataforma/pruebas")); sys.path.insert(0, os.path.join(P, "juego_final/vice"))
juego, out, total = sys.argv[1], sys.argv[2], int(sys.argv[3])
C128 = os.path.exists(os.path.join(juego, "juego.bin.banco1"))
if C128: os.environ["VICE_EMU"] = "x128"
import vice_mb as V
import arranca as A
os.makedirs(out, exist_ok=True)
img = open(os.path.join(juego, "juego.bin"), "rb").read()
e = V.etiquetas(os.path.join(juego, "juego.lbl"))
inc = {}
for l in open(os.path.join(juego, "mapa64.inc") if C128 else os.path.join(P, "juego_final", "mapa64.inc")):   # (the C64's: one map)
    p = l.split()
    if len(p) >= 3 and p[1] == "=" and p[2].startswith("$"): inc[p[0]] = int(p[2][1:], 16)
TECLAS, PEND, LA_T = inc["D64_SYS_KEYS_DOWN"], inc["D64_SYS_KEYS_PENDING"], 0xE2
def teclas(f):
    if f < 20: return []
    if 150 <= f % 300 < 156: return [(0, 1)] if (f // 300) % 2 == 0 else [(1, 0)]
    return [(0, 0)]
copias, malas, peor, durs = 0, [], 0, []
with V.Vice(None, ["-sounddev", "dummy", "-warp"], registro=os.path.join(out, "vice.log")) as v:
    if C128:                                                        # (as cabezas_anda.py)
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
    def raster():
        d = lee(io, 0xD011, 2)
        return (d[0] >> 7) << 8 | d[1]
    pf = v.punto(e["game_input_and_mirror"], temporal=False)
    pk = v.punto(e["game_input_and_mirror"] + 3, temporal=False)
    pc = v.punto(e["blit_copia"], temporal=False)
    pe = v.punto(e["blit_fin"], temporal=False)
    f, antes, ini = 0, [], None
    while f < total:
        v.golpes.clear()
        v.orden(V.CMD_EXIT)
        v.s.settimeout(30)
        try:
            while not v.golpes: v._respuesta()
        except socket.timeout:
            print(f"stop  frame {f}: no stop in 30 s (the game over's wait, or a hang)"); break
        finally:
            v.s.settimeout(None)
        if pc in v.golpes:
            t = lee(ram, LA_T, 2)
            ini = (raster(), t[0], t[1])
        if pe in v.golpes and ini:
            r1, L, n = ini
            r2 = raster()
            largo = (r2 - r1) % 312
            peor = max(peor, largo)
            durs.append(largo)
            camino = {(r1 + k) % 312 for k in range(largo + 1)}
            filas = set(range(L + 51, L + 51 + n))
            copias += 1
            if camino & filas: malas.append((f, r1, r2, L, n))
            ini = None
        if pk in v.golpes:
            t = teclas(f)
            if t:
                fila = bytearray(lee(ram, TECLAS, 10)); pen = bytearray(lee(ram, PEND, 10))
                for r, b in t:
                    fila[r] &= ~(1 << b) & 0xFF
                    if (r, b) not in antes: pen[r] &= ~(1 << b) & 0xFF
                A.escribe_banco(v, ram, TECLAS, bytes(fila)); A.escribe_banco(v, ram, PEND, bytes(pen))
            antes = t
        if pf in v.golpes: f += 1
print("      copy lengths (raster lines): " + ", ".join(f"<={b}: {sum(1 for d in durs if (b // 2 if b > 16 else 0) < d <= b)}" for b in (16, 32, 52, 80, 120, 200)) + f"; over 52: {sum(1 for d in durs if d > 52)}")
print(f"{'ok  ' if not malas else 'FAIL'}  {copias} copies in {f} frames; {len(malas)} met the beam; the longest copy {peor} raster lines")
for m in malas[:10]: print(f"      frame {m[0]}: beam {m[1]} -> {m[2]}, the rectangle's raster lines {m[3] + 51}-{m[3] + 51 + m[4] - 1}")
sys.exit(1 if malas else 0)
