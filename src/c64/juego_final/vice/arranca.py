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

"""The C64 game (c64/juego_final/c64/juego.bin, `C64=1 ./construye.sh`) run in VICE without its loader: the
whole 64 KiB image is written into the RAM through the binary monitor (the RAM bank: under the I/O and the
ROMs too) once the machine has booted, and the CPU is sent to principal_inicio.  Deterministic: VICE driven
only at checkpoints (c64/plataforma/pruebas/vice_mb.py), frames counted at the game's own main-loop calls.

    arranca.py OUTDIR [FRAME...]     screenshots OUTDIR/frame_N.png at those frames (default 1 50 200 400)
                                     and OUTDIR/ciclos.tsv: the CPU cycles of each frame (the CIA 2 timers)

Keys: none (Guillermo stays; the abbot comes to him at the start, as on the CPC).
"""
import os, struct, sys
D = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, os.path.join(D, "../../plataforma/pruebas"))
import vice_mb as V

CMD_BANKS = 0x82


def banco(v, nombre):
    _, c = v.orden(CMD_BANKS)
    n = struct.unpack("<H", c[:2])[0]
    k = 2
    for _ in range(n):
        tam = c[k]
        bid = struct.unpack("<H", c[k + 1:k + 3])[0]
        nlen = c[k + 3]
        nom = c[k + 4:k + 4 + nlen].decode()
        if nom == nombre:
            return bid
        k += 1 + tam
    raise RuntimeError(f"no bank {nombre}")


def escribe_banco(v, b, ini, datos):
    for i in range(0, len(datos), 0x1000):
        trozo = datos[i:i + 0x1000]
        a = ini + i
        v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, a, a + len(trozo) - 1, 0, b) + bytes(trozo))


def arranca_juego(v, pc):
    """the CPU sent to pc with the interrupts disabled: the KERNAL's IRQ (alive until the game installs its own)
    must not run once more over the image just written (its keyboard scan and jiffy clock would land on the
    game's variables); the game's start enables them when its own vectors are in place"""
    r = v.registros()                               # VICE's 6510 register ids: 3 PC, 5 the status register
    v.orden(V.CMD_REGISTERS_SET, struct.pack("<BHBBHBBH", 0, 2, 3, 3, pc, 3, 5, r[5] | 0x04))


def main():
    out = sys.argv[1]
    frames = [int(x) for x in sys.argv[2:]] or [1, 50, 200, 400]
    os.makedirs(out, exist_ok=True)
    juego = os.environ.get("JUEGO_DIR", os.path.join(D, "../c64"))   # JUEGO_DIR: another build (c64hw: the hardware sprites)
    img = open(os.path.join(juego, "juego.bin"), "rb").read()
    e = V.etiquetas(os.path.join(juego, "juego.lbl"))
    with V.Vice(None, ["-sounddev", "dummy", "-warp"], registro=os.path.join(out, "vice.log")) as v:
        v.hasta(0xE5CD, limite=120)                 # the KERNAL's screen editor waits for a key: booted
        ram = banco(v, "ram")
        escribe_banco(v, ram, 0x0002, img[2:0x10000])
        arranca_juego(v, e["principal_inicio"])
        io = banco(v, "io")
        # CIA 2 as a 32-bit cycle counter (the game uses neither its timers nor its interrupts): timer A counts
        # the clock from FFFFh, timer B its underflows
        escribe_banco(v, io, 0xDD04, b"\xff\xff\xff\xff")
        escribe_banco(v, io, 0xDD0F, b"\x51")
        escribe_banco(v, io, 0xDD0E, b"\x11")
        n = 0
        golpe = v.punto(e["game_input_and_mirror"], temporal=False)
        tiempos = []
        while n < max(frames):
            v.golpes.discard(golpe)
            v.orden(V.CMD_EXIT)
            while golpe not in v.golpes:
                v._respuesta()
            n += 1
            _, c = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, 0xDD04, 0xDD07, 0, io))
            ta, tb = struct.unpack("<HH", c[2:6])
            tiempos.append((0xFFFF - tb) * 65536 + (0xFFFF - ta))
            if n in frames:
                v.captura(os.path.join(out, f"frame_{n}.png"))
                print(f"frame {n}: {os.path.join(out, f'frame_{n}.png')}", flush=True)
        with open(os.path.join(out, "ciclos.tsv"), "w") as o:
            o.write("frame\tcycles_since_start\tcycles_of_frame\n")
            for i, t in enumerate(tiempos):
                o.write(f"{i + 1}\t{t}\t{t - tiempos[i - 1] if i else t}\n")


if __name__ == "__main__":
    main()
