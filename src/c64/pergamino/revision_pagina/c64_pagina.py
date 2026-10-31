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

"""The C64's first page turn of the introduction parchment, captured in VICE (x64sc on Xvfb :99) through its
binary monitor (c64/plataforma/pruebas/vice_mb.py): checkpoints at the program's own labels, so the results are
a function of the emulated cycles only.

    c64_pagina.py PRG LBL OUTDIR [--cada MS] [--pasos k1,k2,...] [--solo-pasos] [--sin-warp]

PRG/LBL: a first-stage build (pergamino.prg and its ld65 label file).  The page turn starts at the first call
of _esquina_asm (the first corner, as the CPC's 65FDh draws its first corner at once) and ends at the first call
of _tecla_espacio after it (the text loop's next character: the CPC's 65FDh returns to 668Bh's loop, which reads
the keyboard first).  The time is the music interrupt's count (_musica_ticks, CIA 1 timer A, 3285 cycles a tick)
plus the timer's own count: cycles of the PAL C64 (985248 Hz).

1. a run: the duration (OUTDIR/duracion.txt); another: a screenshot every MS milliseconds from the start
   (OUTDIR/c64_t<ms>.png: the emulation advanced 1000 instructions at a time, so within ~4 ms);
2. with --pasos (--solo-pasos: only this): another run, held at the corner's step k: the first call of _espera
   after the k-th call of _esquina_asm (the corner drawn, the borders not yet put back, as cpc_pagina.py's steps);
   the program is held there (JMP * at that address) for 20000 instructions (3 frames) so that the VIC shows a
   whole frame of it (--sin-warp: at the CPC's speed, reaching the points by checkpoints instead of barriers: the
   build before the fix, whose drawing the barriers disturbed), then OUTDIR/c64_paso<k>.png and OUTDIR/c64_paso<k>.bin (the memory the VIC shows: $8000-$87FF
   cells, sprite pointers and sprites, $A000-$BF3F the bitmap, $D000-$D02E the VIC's registers), and the program goes
   on as it was (its timing is not measured in this run: the waits catch up).
"""
import os, struct, sys, time

P = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))))
sys.path.insert(0, os.path.join(P, "c64/plataforma/pruebas"))
from vice_mb import Vice, etiquetas                                  # noqa: E402

CICLOS_TICK = 3285
HZ = 985248


def tiempo(v, e):
    t = v.lee(e["_musica_ticks"], e["_musica_ticks"] + 1)
    c = v.lee(0xDC04, 0xDC05)
    return (t[0] | t[1] << 8) * CICLOS_TICK + (CICLOS_TICK - 1 - (c[0] | c[1] << 8))


def hasta_punto(v, dir):
    """run until the PC reaches dir (a temporary checkpoint; the program is not changed).  Only for points
    reached long after the EXIT: a checkpoint hit within a few thousand cycles of an EXIT is followed by
    another resume in VICE 3.10 (the PC is checked)"""
    num = v.punto(dir)
    v.golpes.discard(num)
    v.parado = False
    v.orden(0xAA)                                                      # EXIT: go on
    while num not in v.golpes:
        v._respuesta()
    v.s.settimeout(2)
    try:
        while not v.parado:
            v._respuesta()
    except OSError:
        pass
    finally:
        v.s.settimeout(None)
    pc = v.registros()[3]
    if pc != dir:
        raise RuntimeError(f"stopped at {pc:04X}, not at {dir:04X}")


def en_interrupcion(e, pc):
    """the music interrupt's code: the KERNAL's entry and exit, musica.s and sid.s (between _musica_inicia and the
    module after sid.s, carga.s in the first stage; the ending has no carga.s: sid.s's interrupt lies within 256 bytes
    after _musica_irq_off)"""
    fin = e.get("_carga_juego", e["_musica_irq_off"] + 0x100)
    return pc >= 0xE000 or e["_musica_inicia"] <= pc < fin


def barrera(v, e, dir, quita=True):
    """run until the program reaches dir, held there by a JMP * written at dir (the barrier of vice_mb.hasta, put
    in place here).  VICE's checkpoint report is not relied on (a hit soon after an EXIT may go unreported in warp
    mode): the emulation is stopped every 50 ms of host time and the PC looked at (out of the interrupt first); once
    the CPU has reached the barrier it stays there, so what is found does not depend on the host's timing.  With
    quita the bytes are put back"""
    if v.registros()[3] == dir:                # held at dir by the barrier before: off it first
        avanza(v, 1)
    guarda = v.lee(dir, dir + 2)
    v.escribe(dir, bytes([0x4C, dir & 255, dir >> 8]))
    while True:
        v.orden(0xAA)
        time.sleep(0.05)
        v.para()
        pc = v.registros()[3]
        for _ in range(8):                     # in the interrupt: 300 instructions more (it returns to dir if the
            if not en_interrupcion(e, pc):     # CPU was held there)
                break
            avanza(v, 300)
            pc = v.registros()[3]
        if pc == dir:
            break
    if quita:
        v.escribe(dir, guarda)
    return guarda


def avanza(v, n):
    """run n instructions (the binary monitor's ADVANCE_INSTRUCTIONS, stepping into subroutines and interrupts)"""
    v.parado = False
    v.orden(0x71, struct.pack("<BH", 0, n))
    while not v.parado:
        v._respuesta()


def main():
    prg, lbl, out = sys.argv[1], sys.argv[2], os.path.realpath(sys.argv[3])
    cada, pasos, tiempo_tambien, sin_warp = 500, [], True, False
    a = sys.argv[4:]
    while a:
        if a[0] == "--cada":
            cada = int(a[1]); a = a[2:]
        elif a[0] == "--pasos":
            pasos = sorted(int(x) for x in a[1].split(",")); a = a[2:]
        elif a[0] == "--solo-pasos":
            tiempo_tambien = False; a = a[1:]
        elif a[0] == "--sin-warp":
            sin_warp = True; a = a[1:]
        else:
            sys.exit(__doc__)
    os.makedirs(out, exist_ok=True)
    e = etiquetas(lbl)
    opc = ["-sounddev", "dummy", "-warp", "-VICIIextpal", "-VICIIpalette", "colodore"]

    if tiempo_tambien:
        fin = duracion(prg, e, opc, out)
        fotos(prg, e, opc, out, cada, fin)
    if pasos:
        retenidos(prg, e, [x for x in opc if x != "-warp"] if sin_warp else opc, out, pasos, not sin_warp)


def duracion(prg, e, opc, out):
    """the first corner, then one run to the keyboard read with a checkpoint that only counts the corners (no stop
    in between: a stop soon after an EXIT is not reliable in warp mode)"""
    with Vice(prg, opciones=opc) as v:
        v.para()
        hasta_punto(v, e["_esquina_asm"])
        t0 = tiempo(v, e)
        _, c = v.orden(0x12, struct.pack("<HHBBBBB", e["_esquina_asm"], e["_esquina_asm"], 0, 1, 4, 0, 0))
        cuenta = struct.unpack("<I", c[:4])[0]
        hasta_punto(v, e["_tecla_espacio"])
        fin = tiempo(v, e) - t0
        _, c = v.orden(0x11, struct.pack("<I", cuenta))
        esquinas = 1 + struct.unpack("<I", c[13:17])[0]           # (the hit count: offset 13 of the reply)
        v.orden(0x13, struct.pack("<I", cuenta))
        print(f"page turn: {esquinas} corners, {fin} cycles, {fin / HZ:.3f} s")
        with open(os.path.join(out, "duracion.txt"), "w") as o:
            o.write(f"corners {esquinas}\ncycles {fin}\nseconds {fin / HZ:.3f}\n")
    return fin


def fotos(prg, e, opc, out, cada, fin):
    with Vice(prg, opciones=opc) as v:
        v.para()
        hasta_punto(v, e["_esquina_asm"])
        t0 = tiempo(v, e)
        v.captura(os.path.join(out, "c64_t00000.png"))
        n = 1
        while True:
            avanza(v, 1000)
            t = tiempo(v, e) - t0
            if t * 1000 >= n * cada * HZ:
                v.captura(os.path.join(out, f"c64_t{round(t * 1000 / HZ):05d}.png"))
                n += 1
            if t > fin + HZ // 2:
                break


def retenidos(prg, e, opc, out, pasos, barreras=True):
    with Vice(prg, opciones=opc) as v:
        v.para()
        hasta_punto(v, e["_main"])             # the program in memory (autostart): then the barriers can go in
        k = 0
        for objetivo in pasos:
            while k < objetivo:
                if barreras:
                    barrera(v, e, e["_esquina_asm"])
                else:
                    hasta_punto(v, e["_esquina_asm"])
                k += 1
            pc = e["_espera"]
            if barreras:
                guarda = barrera(v, e, pc, quita=False)                  # held: JMP * at _espera
            else:
                hasta_punto(v, pc)
                guarda = v.lee(pc, pc + 2)
                v.escribe(pc, bytes([0x4C, pc & 255, pc >> 8]))
            avanza(v, 20000)                                           # >= 60000 cycles: 3 frames
            v.captura(os.path.join(out, f"c64_paso{objetivo:02d}.png"))
            with open(os.path.join(out, f"c64_paso{objetivo:02d}.bin"), "wb") as o:   # what compara_mem.py reads
                o.write(v.lee(0x8000, 0x87FF) + v.lee(0xA000, 0xBF3F) + v.lee(0xD000, 0xD02E))
            v.escribe(pc, guarda)
        print(f"steps held: {pasos}")

if __name__ == "__main__":
    main()
