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

"""A session watched on a desktop screen (the tape loaded in VICE on another of my PCs, played up to the
end, to see that the ending loads): the tape in a VICE already running there
(remoto.py: its binary monitor on the VPN), driven as prueba_cinta.py --final does: the menu (the options typed),
the presentation passed, the game loaded from the tape, a few seconds of play, then the state one step from 100 %
(estado_final.py, converted here for the same tape image), the game's own ending: "PON EL CASSETTE EN MARCHA", the
KERNAL's "FINAL" and the ending's parchment from where the tape stopped.  At the emulator's own speed: VICE 3.10
has no warp resource for the monitor's Resource Set (0x52 answers 01, no such object: only -warp at the start and
the Alt+W key); Alt+W may be pressed there.  The emulator keeps running at the end.

    sesion_final.py MACHINE:PORT [--opciones KEYS] [--pausa SECONDS]"""
import os, struct, sys, time
D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, D)
sys.path.insert(0, os.path.join(P, "c64", "juego_final", "vice"))
sys.path.insert(0, os.path.join(P, "c64", "plataforma", "pruebas"))
sys.path.insert(0, os.path.join(P, "c64", "presentacion", "pruebas"))
import vice_mb as V                                   # noqa: E402
import arranca as A                                   # noqa: E402
import estado_final                                   # noqa: E402
from remoto import Remoto                             # noqa: E402

G = os.path.join(D, "generado")
GC = os.path.join(P, "c64", "presentacion", "generado_cinta")


def dice(t):
    print(time.strftime("%H:%M:%S"), t, flush=True)


def main():
    args = sys.argv[1:]
    def opcion(n, d):
        if n in args:
            i = args.index(n); v = args[i + 1]; del args[i:i + 2]; return v
        return d
    teclas = opcion("--opciones", "")
    pausa = float(opcion("--pausa", "4"))
    maquina, puerto = args[0].split(":")
    opc = 0
    for k in teclas:
        opc ^= {"1": 1, "2": 2, "3": 4}[k]
    jdir = os.path.join(P, "c64", "juego_final", "c64cinta_en" if opc & 1 else "c64cinta")
    e = V.etiquetas(os.path.join(jdir, "juego.lbl"))
    menu = V.etiquetas(os.path.join(G, "menu.lbl"))
    pres = V.etiquetas(os.path.join(GC, "abadia.lbl"))
    fi = V.etiquetas(os.path.join(GC, "final.lbl"))
    dice("the ending's state converted for the tape image (estado_final.py)")
    estado = bytearray(estado_final.memoria("/tmp/sesion_final_estado.bin", juego=jdir))
    estado[e["plat_opciones"]] = opc
    estado[e["plat_unidad"]] = 1
    with Remoto(maquina, int(puerto)) as v:
        ram = A.banco(v, "ram")
        lee = lambda a, n: v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, a + n - 1, 0, ram))[1][2:2 + n]
        def warp(si):
            pass                        # VICE 3.10 has no warp resource (only -warp and its key, Alt+W): real time
        def tecla(c):
            A.escribe_banco(v, ram, 0x0277, bytes([c])); A.escribe_banco(v, ram, 0x00C6, b"\x01")
        def corre(dir):
            n = v.punto(dir, temporal=True)
            while True:
                v.golpes.clear(); v.orden(V.CMD_EXIT)
                while not v.golpes: v._respuesta()
                if n in v.golpes: return
        def espera(seg):
            v.orden(V.CMD_EXIT); time.sleep(seg); v.registros()      # (a register read stops it again)
        warp(True)
        dice("connected; warp on to the menu")
        corre(menu["tecla"])
        warp(False)
        dice("the menu: the options typed, then SPACE")
        espera(pausa)
        for k in teclas:
            tecla(ord(k)); corre(menu["tecla"]); espera(1.5)
        tecla(ord(" "))
        warp(True)
        corre(pres["_main"])
        dice("the presentation: its parchment passed with SPACE")
        corre(pres["_kbhit"]); tecla(ord(" "))
        corre(pres["_gameload"])
        dice("the picture; the game loads from the tape (warp)")
        corre(e["principal_inicio"])
        warp(False)
        dice(f"the game: {pausa} s of it, then the state one step from 100 %")
        espera(pausa)
        for i in range(0x0002, 0x10000, 0x1000):
            A.escribe_banco(v, ram, i, bytes(estado[i:min(0x10000, i + 0x1000)]))
        A.arranca_juego(v, e["principal_inicio"])
        corre(e["plat_final"])
        dice(f"plat_final: {lee(0x067A, 3).decode('latin-1')} per cent; the CPC's words on the screen")
        espera(pausa)
        warp(True)
        corre(0x080D)
        dice("the KERNAL loaded \"FINAL\" from the tape; the ending's stage and program (warp)")
        corre(fi["_main"])
        warp(False)
        dice(f"the ending's program running, OPCIONES = {lee(0x02A7, 1)[0]}: its parchment at normal speed")
    dice("done: VICE goes on")


if __name__ == "__main__":
    main()
