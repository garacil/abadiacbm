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

"""Every room of abadia128ks (milestone H10, the full game) as the C128 game draws it: x128 with the C128 build (as
cabezas_anda.py); Guillermo put in each room in turn (its square of the PC's room maps: floor 0 1800:AD23, floor 1
ADB3, floor 2 ADBB, 16 a row; x, y = the square's centre, z = the floor's base 0, 0Bh, 16h; the room shown forgotten,
chr_room_x := 0, as a loaded game does), the camera kept on him (game_idle_frames, game_camera_other := 0 every frame),
the game left a few frames to draw it, the screen captured.  Then pages of 20 rooms (1280 x 640: each play area 256 x 160 with its
room number), for looking at the full game's rooms and its new tiles.

    salas128.py JUEGO_DIR OUT
"""
import os, socket, struct, sys
P = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../.."))
sys.path.insert(0, os.path.join(P, "plataforma/pruebas")); sys.path.insert(0, os.path.join(P, "juego_final/vice"))
os.environ["VICE_EMU"] = "x128"
import vice_mb as V
import arranca as A
from PIL import Image, ImageDraw
juego, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
img = open(os.path.join(juego, "juego.bin"), "rb").read()
b1 = open(os.path.join(juego, "juego.bin.banco1"), "rb").read()
e = V.etiquetas(os.path.join(juego, "juego.lbl"))
inc = {}
for l in open(os.path.join(juego, "mapa64.inc")):
    p = l.split()
    if len(p) >= 3 and p[1] == "=" and p[2].startswith("$"): inc[p[0]] = int(p[2][1:], 16)
ds = open("/home/german/Proyectos/abadia/trabajo/re/disco/programa.bin", "rb").read()[0x8000:0x18000]
salas, vistas = [], set()
# (the PC's maps: floor 0 rows 1-10 of 16 rooms, floors 1 and 2 rows 2-6 of 8, interleaved in 16-byte rows)
for base, z, filas, cols in ((0xAD23, 0x00, range(1, 11), 16), (0xADB3, 0x0B, range(2, 7), 8), (0xADBB, 0x16, range(2, 7), 8)):
    for gy in filas:
        for gx in range(cols):
            a = base + 16 * gy + gx
            r = ds[a]
            if r and r not in vistas:
                vistas.add(r); salas.append((r, gx * 16 + 8, gy * 16 + 8, z))
G = inc["D64_CHR_GUILLERMO"]
fotos = []
with V.Vice(None, ["-sounddev", "dummy", "-warp"], registro=os.path.join(out, "vice.log")) as v:
    v.hasta(0xC25E, limite=120)
    ram, ram1 = A.banco(v, "ram00"), A.banco(v, "ram01")
    v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0xFF00, 0xFF00, 0, A.banco(v, "cpu")) + b"\x3e")
    A.escribe_banco(v, ram, 0x0002, img[2:0xFF00]); A.escribe_banco(v, ram, 0xFF05, img[0xFF05:])
    A.escribe_banco(v, ram1, 0x1000, b1)
    A.arranca_juego(v, e["principal_inicio"])
    pf = v.punto(e["game_input_and_mirror"], temporal=False)
    f, i = 0, 0
    while i < len(salas):
        v.golpes.clear(); v.orden(V.CMD_EXIT)
        v.s.settimeout(30)
        try:
            while not v.golpes: v._respuesta()
        except socket.timeout:
            print(f"stop at frame {f}, room {salas[i][0]:02X}: no frame in 30 s"); break
        finally:
            v.s.settimeout(None)
        if pf not in v.golpes: continue
        f += 1
        if f < 30: continue
        k = (f - 30) % 8
        r, x, y, z = salas[i]
        # the camera kept on Guillermo (no idle count, no other character followed); a move forgets the room shown
        A.escribe_banco(v, ram, inc["D64_GAME_IDLE_FRAMES"], b"\0")
        A.escribe_banco(v, ram, inc["D64_GAME_CAMERA_OTHER"], b"\0")
        A.escribe_banco(v, ram, inc["D64_HUD_OBSEQUIUM"], b"\x1f")        # (no game over meanwhile)
        A.escribe_banco(v, ram, inc["D64_GAME_GUILLERMO_DEAD"], b"\0")
        if k == 0:
            A.escribe_banco(v, ram, G + 2, bytes([x, y, z]))
            A.escribe_banco(v, ram, inc["D64_CHR_ROOM_X"], b"\0")
        elif k == 7:
            nom = os.path.join(out, f"sala_{r:02X}.png"); v.captura(nom); fotos.append((r, nom)); i += 1
# the pages: the play area of each capture (x 64-319, y 36-195 of the 384 x 272 picture), 5 x 4 a page
W, H = 256, 160
for pg in range(0, len(fotos), 20):
    hoja = Image.new("RGB", (5 * W, 4 * H), (40, 40, 40))
    d = ImageDraw.Draw(hoja)
    for n, (r, nom) in enumerate(fotos[pg:pg + 20]):
        im = Image.open(nom).convert("RGB")
        sx, sy = im.width / 384, im.height / 272
        im = im.crop((int(64 * sx), int(36 * sy), int(320 * sx), int(196 * sy))).resize((W, H))
        hoja.paste(im, ((n % 5) * W, (n // 5) * H))
        d.rectangle(((n % 5) * W, (n // 5) * H, (n % 5) * W + 22, (n // 5) * H + 11), fill=(0, 0, 0))
        d.text(((n % 5) * W + 2, (n // 5) * H), f"{r:02X}", fill=(255, 255, 255))
    hoja.save(os.path.join(out, f"salas_{pg // 20 + 1}.png"))
print(f"{len(fotos)} rooms captured; pages salas_1..{(len(fotos) + 19) // 20}.png in {out}")
