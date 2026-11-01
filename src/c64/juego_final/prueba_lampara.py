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

"""Compare the old and new assembled light masks, pixels and 6502 cycles.

Usage: prueba_lampara.py BASELINE OUTPUT [--cases N]
BASELINE holds juego.bin and juego_todo.lbl; the current checked build is tested.
No emulator speed, game state, graphics or clock values are changed by the optimization.
"""
import argparse
import ctypes
import json
from pathlib import Path
import random
import re
import statistics
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def labels(path):
    return {row[2].lstrip("."): int(row[1].split(":")[-1], 16)
            for line in path.read_text().splitlines() if len(row := line.split()) == 3 and row[0] == "al"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--cases", type=int, default=512)
    parser.add_argument("--snapshot", type=Path, help="also benchmark the full renderer on this real VICE state")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    core = args.output.resolve() / "m6502.so"
    subprocess.run(["gcc", "-shared", "-fPIC", "-O2", "-o", str(core),
                    str(ROOT / "juego/m6502/6502.c"), str(ROOT / "juego/m6502/m6502.c")], check=True)
    cpu = ctypes.CDLL(str(core))
    cpu.m6502_llama.argtypes = [ctypes.c_uint16, ctypes.c_uint8, ctypes.c_uint8, ctypes.c_uint8, ctypes.c_ulong]
    cpu.m6502_llama.restype = ctypes.c_ulong
    memory = (ctypes.c_uint8 * 65536).in_dll(cpu, "Mem")
    builds = [(p.joinpath("juego.bin").read_bytes(), labels(p / "juego_todo.lbl"))
              for p in (args.baseline, HERE)]
    addresses = {name: int(address, 16) for name, address in
                 re.findall(r"^(\w+) = \$(\w+)", (HERE / "mapa64.inc").read_text(), re.M)}
    rng = random.Random(0xABAD1A)
    cycles = [[], []]
    sizes = [4, 8, 12, 16, 20, 24, 28, 32, 40, 48, 64, 80, 128]
    for number in range(args.cases):
        width, height = rng.choice(sizes), rng.randrange(1, 32) * 8
        x, y = rng.randrange(width // 4) * 4, rng.randrange(32) * 8
        dx, flip, band = number % 4, (number // 4 % 2) * 0x29, (159, 239)[number // 8 % 2]
        original = rng.randbytes(0x4000)
        expected = bytearray(original)
        pattern = builds[0][0][addresses["G_LUZ"]:addresses["G_LUZ"] + 30]
        stream = [0] * (band + 1)
        for row in range(15):
            bits = int.from_bytes(pattern[2 * row:2 * row + 2], "big")
            if flip:
                bits = bits << 1 & 65535
            line = [0] * dx + [(bits >> bit) & 1 for bit in range(15, -1, -1)] + [0] * (4 - dx)
            stream.extend(line * 4)
        stream.extend([0] * (398 - band + 1))
        assert len(stream) == 1600
        cursor_x, cursor_y = x, y
        for lit in stream:
            if not lit and cursor_y < height:
                address = (cursor_y >> 3) * 4 * width + (cursor_x >> 1) * 8 + (cursor_y & 7)
                expected[address] &= 0x0F if not cursor_x & 1 else 0xF0
            cursor_x += 1
            if cursor_x >= width:
                cursor_x -= width
                cursor_y = (cursor_y + 1) & 255
        for index, (image, symbol) in enumerate(builds):
            memory[:] = image
            memory[0x8000:0xC000] = original
            memory[addresses["D64_SPR_OV_DST_X"]] = x
            memory[addresses["D64_SPR_OV_DST_Y"]] = y
            memory[addresses["D64_SPR_CUR_BUFFER"]] = 0
            memory[addresses["D64_SPR_CUR_BUFFER"] + 1] = 0x80
            memory[addresses["D64_SPR_RECT_POS"] + 2] = width
            memory[addresses["D64_SPR_RECT_POS"] + 3] = height
            for name, value in (("D64_SPR_LIGHT_DX", dx), ("D64_SPR_LIGHT_DX_REST", 4 - dx),
                                ("D64_SPR_LIGHT_FLIP", flip)):
                memory[addresses[name]] = value
            for name, value in (("D64_SPR_LIGHT_FILL_A", band), ("D64_SPR_LIGHT_FILL_B", 398 - band)):
                memory[addresses[name]] = value
                memory[addresses[name] + 1] = 0
            memory[symbol["la_f4w"]] = width * 4 & 255
            memory[symbol["la_f4w"] + 1] = width * 4 >> 8
            cpu.m6502_init()
            elapsed = cpu.m6502_llama(symbol["la_luz"], 0, 0, 0, 10000000)
            assert elapsed, ("timeout", number, index)
            actual = bytes(memory[0x8000:0xC000])
            if actual != expected:
                differences = [i for i, (a, b) in enumerate(zip(actual, expected)) if a != b]
                raise AssertionError(dict(case=number, build=index, width=width, height=height,
                                          x=x, y=y, dx=dx, flip=flip, band=band,
                                          differences=differences[:20]))
            cycles[index].append(elapsed)
    result = dict(cases=args.cases, identical_pixels=True, guards_intact=True,
                  median_cycles_before=statistics.median(cycles[0]), median_cycles_after=statistics.median(cycles[1]),
                  total_cycles_before=sum(cycles[0]), total_cycles_after=sum(cycles[1]),
                  speedup=sum(cycles[0]) / sum(cycles[1]),
                  minimum_speedup=min(a / b for a, b in zip(*cycles)))
    if args.snapshot:
        sys.path[:0] = [str(ROOT / "c64/disco"), str(ROOT / "c64/plataforma/pruebas")]
        import vice_mb as V
        import prueba as D
        with V.Vice(None, ["-warp", "-sounddev", "dummy", "-VICIIfilter", "0", "-VICIIglfilter", "0"],
                    registro=str(args.output / "vice_lampara.log")) as vice:
            vice.hasta(0xE5CD, limite=120)
            vice.restaura(str(args.snapshot.resolve()))
            state = D.lee(vice, D.bancos(vice)["ram"], 0, 65535)
        assert state[addresses["D64_GAME_ADSO_LAMP"]] & 128, "Adso does not have the lamp"
        samples = []
        for offset in range(8):
            rendered = []
            costs = []
            for image, symbol in builds:
                memory[:] = state
                memory[0x0800:0x7151] = image[0x0800:0x7151]
                memory[addresses["D64_ISO_ROOM_DARK"]] = 1
                # Cover both fill bands and all four sub-byte positions, using
                # the real sprites, occlusion, tiles and clipping of this room.
                memory[addresses["D64_SPR_TABLE"] + 0x15] += offset % 4
                memory[addresses["D64_SPR_TABLE"] + 0x16] += offset // 4 * 4
                cpu.m6502_init()
                total = 0
                for routine in ("spr_place_light", "spr_draw_or_darken"):
                    elapsed = cpu.m6502_llama(symbol[routine], 0, 0, 0, 10000000)
                    assert elapsed, (routine, offset)
                    total += elapsed
                rendered.append((bytes(memory[0xE000:0xFF40]), bytes(memory[0x9CCD:0xAC4D])))
                costs.append(total)
            assert rendered[0] == rendered[1], ("full renderer pixel/buffer mismatch", offset)
            samples.append(dict(before=costs[0], after=costs[1], speedup=costs[0] / costs[1]))
        result["full_renderer"] = dict(samples=samples, identical_pixels_and_buffers=True,
                                       source_room_dark=bool(state[addresses["D64_ISO_ROOM_DARK"]]),
                                       lamp_rendering_enabled_for_benchmark=True,
                                       speedup=sum(s["before"] for s in samples) / sum(s["after"] for s in samples))
    (args.output / "resultado.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
