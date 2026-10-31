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

"""The C64 memory of the game one step from its 100 % ending, for c64/presentacion/pruebas/disco_prueba/prueba.py's run of the ending through the
game's own code: the start state of day 7, tercia, with the investigation solved (data/puro/estados/ram_d7h2.bin,
[37F4] := 0: juego/puro/pruebas/final.sh and c64/juego_final/dias.sh's ending case, where Guillermo dies at once and
the game ends at 100 %, plat_final), converted to the C64 build by the 6502 host's own conversion
(juego/m6502/sombra6502.c, sombra6502_juego_inicio: the image, every 'copia'/'graf' block of mapa64.tsv from the CPC
state with its pointers relocated, the screen into the bitmap).

    estado_final.py OUT.bin [STATE.bin]     (STATE: another CPC start state, as it is)

The host converts for the build in its directory, so it is given the C64 build (c64/juego_final/c64: juego.bin and
juego.lbl; its code addresses differ from the host build's): a directory of links at c64/'s depth (as
c64/cinta/libres.py makes one) with those two files, the host build's own labels (plat_frame...) added at 0 where the
C64 build has none (they only matter to the frame-by-frame run, not to the conversion).  The host is built privately
(a copy of juego/ in a temporary directory, with an environment variable that writes the converted memory and exits;
juego/ is not touched).  Deterministic.
"""
import os, shutil, subprocess, sys, tempfile

D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(os.path.dirname(D)))
FINAL = os.path.join(P, "c64", "juego_final")
J = os.path.join(P, "juego")
T = os.path.join(P, "..", "data")

PARCHE = ("    Regs.SP = 0xFF; Regs.SR = 0x34; Regs.PC = j_inicio;\n}",
          "    Regs.SP = 0xFF; Regs.SR = 0x34; Regs.PC = j_inicio;\n"
          "    if (getenv(\"SOMBRA6502_VOLCADO\")) {\n"
          "        FILE *o = fopen(getenv(\"SOMBRA6502_VOLCADO\"), \"wb\");\n"
          "        fwrite(Mem, 1, 0x10000, o); fclose(o); exit(0);\n"
          "    }\n}")


def anfitrion(tmp):
    """the host, built from a copy of juego/ with the dump"""
    h = os.path.join(tmp, "juego")
    os.makedirs(h)
    for x in os.listdir(J):
        if x.endswith((".c", ".h")):
            shutil.copy(os.path.join(J, x), h)
    for x in ("z80", "m6502"):
        shutil.copytree(os.path.join(J, x), os.path.join(h, x))
    s = open(os.path.join(h, "m6502", "sombra6502.c")).read()
    assert s.count(PARCHE[0]) == 1, "sombra6502_juego_inicio's end has changed: update estado_final.py"
    open(os.path.join(h, "m6502", "sombra6502.c"), "w").write(s.replace(PARCHE[0], PARCHE[1]))
    fuentes = sorted(x for x in os.listdir(h) if x.endswith(".c") and x != "hibrido.c")
    subprocess.run(["gcc", "-std=c99", "-O2", "-o", "hibrido", "hibrido.c"] + fuentes
                   + ["z80/z80.c", "m6502/m6502.c", "m6502/6502.c", "m6502/sombra6502.c"], cwd=h, check=True)
    return os.path.join(h, "hibrido")


def memoria(salida, estado=None, juego=None):
    """the C64 memory of the ending's state, or of another CPC start state (estado: a ram_dXhY.bin of
    data/puro/estados, as it is: c64/juego_final/vice/pasos.py); juego: the C64 build's directory (default
    c64/juego_final/c64; the tape's: c64/juego_final/c64cinta)"""
    juego = juego or os.path.join(FINAL, "c64")
    tmp = tempfile.mkdtemp(prefix="estado_final_")
    dirc = os.path.join(P, "c64", f"presentacion_estado_{os.getpid()}")
    os.makedirs(dirc)
    try:
        # a build with its own map (the C128's c64/juego_final/c128): its map files instead of the C64's
        propio = os.path.exists(os.path.join(juego, "mapa64.tsv"))
        por_mapa = ("mapa64.tsv", "mapa64.inc", "stubs64.tsv", "conversion64.tsv", "punteros64.tsv")
        for x in os.listdir(FINAL):
            if x not in ("juego.bin", "juego.lbl") and not (propio and x in por_mapa):
                os.symlink(os.path.join(FINAL, x), os.path.join(dirc, x))
        if propio:
            for x in por_mapa:
                os.symlink(os.path.join(juego, x), os.path.join(dirc, x))
        shutil.copy(os.path.join(juego, "juego.bin"), dirc)
        lbl = open(os.path.join(juego, "juego.lbl")).read()
        nombres = {l.split()[2].lstrip(".") for l in lbl.splitlines() if l.startswith("al ")}
        faltan = set()
        for l in open(os.path.join(FINAL, "juego.lbl")):                # the host build's labels the C64 build lacks
            t = l.split()
            if len(t) == 3 and t[0] == "al" and t[2].lstrip(".") not in nombres:
                faltan.add(t[2].lstrip("."))
        with open(os.path.join(dirc, "juego.lbl"), "w") as f:
            f.write(lbl + "".join(f"al 000000 .{n}\n" for n in sorted(faltan)))
        h = anfitrion(tmp)
        if estado:
            ram = bytearray(open(estado, "rb").read())
        else:
            ram = bytearray(open(os.path.join(T, "puro", "estados", "ram_d7h2.bin"), "rb").read())
            ram[0x37F4] = 0
        open(os.path.join(tmp, "fin.bin"), "wb").write(ram)
        r = subprocess.run([h, os.path.join(tmp, "fin.bin"), os.path.join(T, "cpc64", "inicio_juego", "estado.txt"),
                            os.path.join(T, "sincrono", "puntos64.txt"), "--hasta", "3000", "--limite", "5000000",
                            "--juego6502", dirc], cwd=J, env=dict(os.environ, SOMBRA6502_VOLCADO=salida),
                           capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(salida):
            raise RuntimeError("the host's conversion failed: " + (r.stdout + r.stderr)[-500:])
        m = bytearray(open(salida, "rb").read())
        # the host keeps the checked build's platform mirrors at $07C0-$07FF (juego/m6502/sombra6502.c PLAT_*): in
        # the C64 build that is code (segment BAJO), which the dump must not replace: the C64 image's bytes back
        img = open(os.path.join(juego, "juego.bin"), "rb").read()
        for linea in open(os.path.join(juego, "juego.map")):
            t = linea.split()
            if len(t) >= 3 and t[0] == "BAJO" and len(t[1]) == 6 and not t[1].startswith("Offs"):  # the segment list
                a, z = int(t[1], 16), int(t[2], 16)
                m[a:z + 1] = img[a:z + 1]
                break
        open(salida, "wb").write(m)
        return bytes(m)
    finally:
        shutil.rmtree(dirc, ignore_errors=True)
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    m = memoria(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    print(f"{sys.argv[1]}: {len(m)} bytes")
