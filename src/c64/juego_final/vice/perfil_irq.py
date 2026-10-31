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

"""A statistical profile of the game in VICE (the C64 build in x64sc, the C128's in x128): the 300 Hz interrupt is a
clock independent of the game (CIA 1's timer), so at each entry of plat_irq the interrupted instruction (the return
address the IRQ pushed: the stack at SP + 2, SP + 3) is a sample of where the time goes.  The keys of a script held
after sys_read_keyboard as mide.py does.  Out: the samples per routine (the nearest label at or below the address,
juego.lbl; the local labels of a .proc fold into it), the idle wait apart.  With PERFIL_LLAMANTE=1 also the
routine's caller: the first word above the interrupt's three bytes on the stack that is a return address (the byte
2 below it a JSR in the image, the address it calls at or below the routine), counted per (routine, caller).

    perfil_irq.py JUEGO_DIR KEYS FROM_FRAME SAMPLES [OUT.tsv]
"""
import os, socket, struct, sys, collections, bisect
P = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../.."))
sys.path.insert(0, os.path.join(P, "plataforma/pruebas")); sys.path.insert(0, os.path.join(P, "juego_final/vice"))
juego, fteclas, desde, n = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
salida = sys.argv[5] if len(sys.argv) > 5 else None
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
# the routines: the global labels (juego.lbl has no scoped ones), by address
lab = sorted((a, nom) for nom, a in e.items() if not nom.startswith("__"))
dirs = [a for a, _ in lab]
def rutina(pc):
    i = bisect.bisect_right(dirs, pc) - 1
    return lab[i][1] if i >= 0 else "?"
muestras = collections.Counter()
llamantes = collections.Counter()
LLAMANTE = os.environ.get("PERFIL_LLAMANTE") == "1"
def llamante(pila, pc):
    """the caller of the routine at pc: the first return address on the stack (pila: the bytes above the IRQ's)"""
    for i in range(0, len(pila) - 1):
        r = pila[i] | pila[i + 1] << 8
        if 2 <= r < 0x10000 and img[r - 2] == 0x20:
            dest = img[r - 1] | img[r] << 8
            if dest <= pc: return rutina(r - 2)
    return "?"
with V.Vice(None, ["-sounddev", "dummy", "-warp"], registro="/tmp/perfil_vice.log") as v:
    if C128:
        v.hasta(0xC25E, limite=120)
        ram = A.banco(v, "ram00")
        v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0xFF00, 0xFF00, 0, A.banco(v, "cpu")) + b"\x3e")
        A.escribe_banco(v, ram, 0x0002, img[2:0xFF00]); A.escribe_banco(v, ram, 0xFF05, img[0xFF05:])
        A.escribe_banco(v, A.banco(v, "ram01"), 0x1000, open(os.path.join(juego, "juego.bin.banco1"), "rb").read())
    else:
        v.hasta(0xE5CD, limite=120)
        ram = A.banco(v, "ram")
        A.escribe_banco(v, ram, 0x0002, img[2:0x10000])
    A.arranca_juego(v, e["principal_inicio"])
    lee = lambda a, k: v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, a + k - 1, 0, ram))[1][2:2 + k]
    pf = v.punto(e["game_input_and_mirror"], temporal=False)
    pk = v.punto(e["game_input_and_mirror"] + 3, temporal=False)
    pi = None
    f, tomadas = 0, 0
    while tomadas < n:
        v.golpes.clear(); v.orden(V.CMD_EXIT)
        v.s.settimeout(60)
        try:
            while not v.golpes: v._respuesta()
        except socket.timeout:
            print(f"stop  frame {f}: no stop in 60 s"); break
        finally:
            v.s.settimeout(None)
        if pf in v.golpes:
            f += 1
            if f == desde: pi = v.punto(e["plat_irq"], temporal=False)
        if pk in v.golpes and teclas.get(f):
            T, PE = inc["D64_SYS_KEYS_DOWN"], inc["D64_SYS_KEYS_PENDING"]
            fila = bytearray(lee(T, 10)); pen = bytearray(lee(PE, 10))
            for k in teclas[f]:
                fila[k >> 3] &= ~(1 << (k & 7)) & 0xFF
                if k not in teclas.get(f - 1, []): pen[k >> 3] &= ~(1 << (k & 7)) & 0xFF
            A.escribe_banco(v, ram, T, bytes(fila)); A.escribe_banco(v, ram, PE, bytes(pen))
        if pi is not None and pi in v.golpes:
            sp = v.registros()[4]
            pila = lee(0x0100 + ((sp + 1) & 0xFF), 3)
            pc = pila[1] | pila[2] << 8
            muestras[rutina(pc)] += 1
            if LLAMANTE and sp < 0xFC:
                arriba = lee(0x0100 + sp + 4, min(16, 0xFF - (sp + 3)))
                llamantes[(rutina(pc), llamante(arriba, pc))] += 1
            tomadas += 1
total = sum(muestras.values())
print(f"{total} samples from frame {desde} (to frame {f})")
for nom, c in muestras.most_common(40):
    print(f"  {100 * c / total:5.1f} %  {c:6d}  {nom}")
if LLAMANTE:
    print("routine <- caller")
    for (r, c), k in llamantes.most_common(40):
        print(f"  {100 * k / total:5.1f} %  {k:6d}  {r} <- {c}")
if salida:
    with open(salida, "w") as o:
        o.write("routine\tsamples\tpercent\n")
        for nom, c in muestras.most_common(): o.write(f"{nom}\t{c}\t{100 * c / total:.2f}\n")
