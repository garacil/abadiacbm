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

"""Adso's four directions: CPC/C64 frame sheets and real 6510 animation.

Usage: adso.py OUTDIR [--vice]
No game state or disk image is modified by this test.
"""
from pathlib import Path
import argparse
import re
import socket
import sys

from PIL import Image, ImageDraw

D = Path(__file__).resolve().parent
ROOT = D.parents[2]
H = D.parent
sys.path.insert(0, str(ROOT / "../tools"))
sys.path.insert(0, str(ROOT / "c64/disco"))
import c64_graficos as G
import prueba as P

PALETTE = [(44, 48, 65), (221, 144, 63), (255, 236, 144), (0, 0, 0)]


def symbols():
    return {name: int(address, 16) for name, address in re.findall(
        r"^(\w+) = \$([0-9A-F]+)", (H / "mapa64.inc").read_text(), re.M)}


def picture(rows, scale=4):
    result = Image.new("RGB", (24, 38), PALETTE[0])
    width = len(rows[0])
    for y, row in enumerate(rows):
        for x, pen in enumerate(row):
            result.putpixel((x + (24-width)//2, y+36-len(rows)), PALETTE[pen])
    return result.resize((24*scale, 38*scale), Image.Resampling.NEAREST)


def sheet(out):
    cpc = (ROOT / "../data/cpc64/juego/ram.bin").read_bytes()
    converted = (ROOT / "../data/c64graf/personajes.bin").read_bytes()
    offsets = {}
    for line in (ROOT / "../data/c64graf/marcos64.tsv").read_text().splitlines():
        fields = line.split("\t")
        if fields[0] == "personajes":
            offsets[int(fields[1], 16)] = int(fields[4])
    result = Image.new("RGB", (8*106+100, 4*184), (230, 230, 230))
    draw = ImageDraw.Draw(result)
    animation = []
    for orientation in range(4):
        for phase in range(4):
            index = (((orientation+1)&2)*2) | phase
            address = 0x2D10+4*index
            pointer = int.from_bytes(cpc[address:address+2], "little")
            width, height = cpc[address+2:address+4]
            original = G.imagen(cpc, pointer, width, height)
            offset = offsets[pointer]
            native = G.de_filas(converted[offset:offset+((width+1)//2)*height], width, height)
            native = [[p for p in row for _ in range(2)] for row in native]
            if orientation >= 2:
                original = [row[::-1] for row in original]
                native = [row[::-1] for row in native]
            y = orientation*184
            for column, rows in ((phase, original), (phase+4, native)):
                x = 100+column*106
                result.paste(picture(rows), (x, y+24))
                draw.text((x, y+6), f"{pointer:04X} / {phase}", fill="black")
            draw.text((8, y+60), f"Direction {orientation}\nCPC -> C64", fill="black")
            if orientation == 1:
                animation.append(picture(native, 8))
    result.save(out / "adso_cpc_c64.png")
    animation[0].save(out / "adso_subida.gif", save_all=True, append_images=animation[1:],
                      duration=160, loop=0)
    print(out / "adso_cpc_c64.png", flush=True)


def regression(before):
    directory = ROOT / "../data/c64graf"
    current = (directory / "personajes.bin").read_bytes()
    heads = [current[offset:offset+14] for offset in (873, 933, 993)]
    assert heads[0] == heads[1] == heads[2], "the upward cap/face changes between steps"
    feet = [current[offset+44:offset+60] for offset in (873, 933, 993)]
    assert len(set(feet)) == 3, "walking legs were frozen or replaced"
    if before:
        previous = (before / "personajes.bin").read_bytes()
        assert len(current) == len(previous) == 1053
        assert current[:873] == previous[:873], "Guillermo or downward Adso was modified"
        for path in before.glob("*.bin"):
            if path.name != "personajes.bin":
                assert path.read_bytes() == (directory / path.name).read_bytes(), path.name
        print("ok: only Adso's 180 upward-view bytes changed; every other graphic is byte-identical.", flush=True)
    print("ok: steady face/cap across all upward poses, three different original walking leg poses.", flush=True)


def comparison(out, before):
    frames = []
    for phase in range(4):
        frame = Image.new("RGB", (4*204, 264), (230, 230, 230))
        draw = ImageDraw.Draw(frame)
        for group, orientation in enumerate((1, 2)):
            for version, directory in enumerate((before, out)):
                column = 2*group+version
                image = Image.open(directory / f"vice_adso_{orientation}_{phase}.png")
                # Fixed scene coordinates from vice(); preserve the alternating
                # half-byte x positions instead of registering the sprite away.
                crop = image.crop((154, 100, 186, 140))
                frame.paste(crop.resize((192, 240), Image.Resampling.NEAREST), (column*204+6, 24))
                draw.text((column*204+8, 7), f"Subida {group+1}: " + ("antes" if version == 0 else "despues"), fill="black")
        frames.append(frame)
    frames[0].save(out / "adso_comparacion.gif", save_all=True,
                   append_images=frames[1:], duration=180, loop=0)


def vice(out):
    labels = P.V.etiquetas(H / "c64/juego.lbl")
    constants = symbols()
    image = (H / "c64/juego.bin").read_bytes()
    with P.V.Vice(None, ["-sounddev", "dummy", "-speed", "100", "+warp"],
                  registro=str(out / "vice_adso.log")) as v:
        v.s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        v.hasta(0xE5CD, limite=30)
        ram = P.bancos(v)["ram"]
        P.escribe_banco(v, ram, 2, image[2:])
        v.pon_pc(labels["principal_inicio"])
        P.corre_hasta(v, labels["game_input_and_mirror"], golpes=10, limite=30)

        def put(address, data):
            P.escribe_banco(v, ram, address, data)

        def word(address, value):
            put(address, value.to_bytes(2, "little"))

        def call(names):
            code = bytearray((0x78, 0xD8, 0xA9, 0x34, 0x85, 1))
            for name in names:
                address = labels[name]
                code.extend((0x20, address&255, address>>8))
            stop = 0x100+len(code)
            code.extend((0x78, 0x4C, stop&255, stop>>8))
            put(0x100, code)
            v.pon_pc(0x100)
            P.corre_hasta(v, stop, limite=10)

        # Only Adso against a blank tile buffer; game code still selects, flips
        # and composes each frame, including half-byte x positions.
        table = constants["D64_SPR_TABLE"]
        actor = constants["D64_CHR_ADSO"]
        record = table+20
        for offset in range(0, 460, 20):
            put(table+offset, [0xFE])
        put(constants["D64_ISO_TILE_BUFFER"], bytes(1920))
        put(constants["D64_ISO_CAMERA_ORIENT"], [0])
        word(constants["D64_CHR_CUR_ANIM"], constants["D64_CHR_ANIM_ADSO"])
        word(constants["D64_CHR_CUR_FLIP"], labels["spr_flip_adso"])
        frames = []
        for orientation in range(4):
            for phase in range(4):
                word(8, record)
                word(10, actor)
                put(actor, [phase, orientation])
                put(record+1, [32+(phase&1), 110])
                put(2, [32])
                call(["chr_select_frame", "chr_show_frame"])
                # Test both directions and both alignments against the exact
                # live source after the native in-place flip.
                current = P.lee(v, ram, record, record+19)
                source = int.from_bytes(current[7:9], "little")
                width, height = current[5:7]
                size = ((width+1)//2)*height
                expected = image[source:source+size]
                if orientation >= 2:
                    expected = G.gira_c64(expected, width, height)
                actual = P.lee(v, ram, source, source+size-1)
                assert actual == expected, ("runtime graphics corrupted", orientation, phase)
                put(record+3, current[1:3])
                put(record+9, current[5:7])
                call(["vid_fill_play_area_ff", "spr_draw_all"])
                bitmap = P.lee(v, ram, 0xE000, 0xF8FF)
                rows = G.de_filas(actual, width, height)
                for y, row in enumerate(rows):
                    screen_y = current[2]-40+y
                    for x, pen in enumerate(row):
                        screen_x = 4*(current[1]-8)+32+2*x
                        offset = 320*(screen_y//8)+8*(screen_x//8)+(screen_y&7)
                        bits = (bitmap[offset] >> (6-(screen_x&7))) & 3
                        # The sprite compositor clears a lit-room rectangle
                        # to CPC pen 0, including its transparent pixels.
                        assert bits == G.BITS[pen], (
                            "compositor pixel mismatch", orientation, phase, x, y, bits, pen)
                # Let the VIC render two full frames, without further game logic.
                put(0x100, bytes((0x78,0xA9,0x35,0x85,1,0xA2,64,0xA0,0,
                                  0x88,0xD0,0xFD,0xCA,0xD0,0xF8,0x4C,15,1)))
                v.pon_pc(0x100)
                P.corre_hasta(v, 0x10F, limite=5)
                filename = out / f"vice_adso_{orientation}_{phase}.png"
                v.captura(str(filename))
                frames.append(Image.open(filename).convert("RGB"))
                print(f"VICE direction {orientation}, phase {phase}, frame {current[7:9].hex()}", flush=True)
        frames[0].save(out / "vice_adso.gif", save_all=True, append_images=frames[1:], duration=200, loop=0)
        assert not v.jams
        print("ok: 16 native animation frames, four orientations, both byte alignments, no CPU JAM.", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--vice", action="store_true")
    parser.add_argument("--comprueba", action="store_true")
    parser.add_argument("--antes", type=Path, help="graphics directory before the Adso change")
    parser.add_argument("--comparar-vice", type=Path, help="older VICE frame output for an animated comparison")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    sheet(args.out)
    if args.comprueba:
        regression(args.antes)
    if args.vice:
        vice(args.out)
    if args.comparar_vice:
        comparison(args.out, args.comparar_vice)


if __name__ == "__main__":
    main()
