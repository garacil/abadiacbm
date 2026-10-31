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

"""The tape in VICE (x64sc 3.10, warp, its datasette and KERNAL), deterministic: abadia64ks.tap autostarted; at
the menu (menu.s's key loop) the keys of OPTIONS typed into the KERNAL's keyboard buffer, then SPACE; the
presentation passed with SPACE at each of conio's kbhit and cgetc; at the game's principal_inicio every byte the
game needs compared with its image (c64/juego_final/c64cinta, or c64cinta_en when English was chosen), the
options in plat_opciones, plat_unidad 1 (the tape); then FRAMES game frames (cert_frame) and the screen saved.

    prueba_cinta.py OUT_DIR [--opciones KEYS] [--frames N] [--final]
        KEYS: e.g. "" (Spanish, all on), "1" (English), "23" (no footsteps, no text sound)
--final: instead of the frames, the ending from the tape: the state one step from 100 % (c64/presentacion/pruebas/
estado_final.py, converted for the same tape image) written over the loaded game (its options and unit kept), the
game's own code to plat_final, the KERNAL's "FINAL" from where the tape stopped, the ending's stage, its program
decrunched (equal to final.prg) with the menu's options in OPCIONES, the ending's parchment on the screen.
--disco: the same on the C64's disk with the tape's menu (c64/disco64/abadia64ks.d64, autostarted: ABADIA64KS): the
game c64disco / c64disco_en, plat_unidad 8, the ending's "FINAL" and "FINALZ" from the disk; --unidad 1571: drive 8
a true 1571 instead of the 1541 (both must work)."""
import os, struct, sys
D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, os.path.join(P, "c64", "plataforma", "pruebas"))
sys.path.insert(0, os.path.join(P, "c64", "juego_final", "vice"))
sys.path.insert(0, os.path.join(P, "c64", "cinta"))
import vice_mb as V                                   # noqa: E402
import arranca as A                                   # noqa: E402
import flujo as F                                     # noqa: E402
from PIL import Image                                 # noqa: E402

G = os.path.join(D, "generado")
GC = os.path.join(P, "c64", "presentacion", "generado_cinta")
fallos = []


def ok(c, m):
    print(("ok    " if c else "FAIL  ") + m, flush=True)
    if not c:
        fallos.append(m)


def main():
    args = sys.argv[1:]
    def opcion(n, d):
        if n in args:
            i = args.index(n); v = args[i + 1]; del args[i:i + 2]; return v
        return d
    teclas = opcion("--opciones", "")
    frames = int(opcion("--frames", "300"))
    unidad = opcion("--unidad", "1541")
    assert unidad in ("1541", "1571"), unidad
    final = "--final" in args
    if final: args.remove("--final")
    global G, GC, UNIDAD, FINAL_PRG, DISCO
    DISCO = "--disco" in args
    if DISCO:
        args.remove("--disco")
        G = os.path.join(P, "c64", "disco64", "generado")
        GC = os.path.join(P, "c64", "presentacion", "generado_disco64")
        UNIDAD, FINAL_PRG = 8, os.path.join(G, "final.prg")
    out = args[0]
    os.makedirs(out, exist_ok=True)
    opc = 0
    for k in teclas:
        opc ^= {"1": 1, "2": 2, "3": 4}[k]
    ingles = opc & 1
    jdir = os.path.join(P, "c64", "juego_final", ("c64disco" if DISCO else "c64cinta") + ("_en" if ingles else ""))
    img = open(os.path.join(jdir, "juego.bin"), "rb").read()
    e = V.etiquetas(os.path.join(jdir, "juego.lbl"))
    nec = F.necesarios(os.path.join(jdir, "juego.map"))
    menu = V.etiquetas(os.path.join(G, "menu.lbl"))
    pres = V.etiquetas(os.path.join(GC, "abadia.lbl"))
    medio = os.path.join(P, "c64", "disco64", "abadia64ks.d64") if DISCO else os.path.join(D, "abadia64ks.tap")
    with V.Vice(None, ["-sounddev", "dummy", "-warp", "-autostart", medio] + (["-drive8type", unidad, "-drive8truedrive"] if DISCO else []),
                registro=os.path.join(out, "vice.log")) as v:
        ram = A.banco(v, "ram")
        lee = lambda a, n: v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, a + n - 1, 0, ram))[1][2:2 + n]
        def foto(nombre):
            w, h, rgb, _ = v.foto()
            Image.frombytes("RGB", (w, h), bytes(rgb)).resize((2 * w, 2 * h), Image.NEAREST).save(os.path.join(out, nombre))
        def tecla(c):
            A.escribe_banco(v, ram, 0x0277, bytes([c])); A.escribe_banco(v, ram, 0x00C6, b"\x01")
        def sigue():
            v.golpes.clear(); v.orden(V.CMD_EXIT)
            while not v.golpes: v._respuesta()
            return v.registros()[3]
        # the menu
        v.hasta(menu["tecla"], limite=900)
        ok(True, "the menu reached from the disk (the KERNAL's ABADIA64KS)" if DISCO else
           "the menu reached from the tape (the KERNAL's ABADIA64KS, the turbo block ID_MENU)")
        t = v.punto(menu["tecla"], temporal=False)
        for k in teclas:
            tecla(ord(k)); pc = sigue()
        ok(lee(0x02A7, 1)[0] == opc, f"the options after the keys {teclas!r}: {lee(0x02A7, 1)[0]} (expected {opc})")
        # the presentation: its breakpoints first, then SPACE in the menu; SPACE at every kbhit / cgetc until the game
        pts = {v.punto(pres["_kbhit"], temporal=False): "kbhit", v.punto(pres["_cgetc"], temporal=False): "cgetc",
               v.punto(e["principal_inicio"], temporal=False): "juego", t: "menu"}
        tecla(ord(" "))
        n = 0
        while True:
            v.golpes.clear(); v.orden(V.CMD_EXIT)
            while not v.golpes: v._respuesta()
            hits = {pts[g] for g in v.golpes if g in pts}
            if "juego" in hits:
                break
            if hits == {"menu"}:
                continue
            if hits & {"kbhit", "cgetc"} and lee(0x00C6, 1)[0] == 0:
                tecla(0x20); n += 1
            if n > 50:
                ok(False, "the presentation never ended"); return
        ok(True, f"the game reached ({n} spaces given to the presentation)")
        mem = b"".join(lee(a, 0x1000) for a in range(0, 0x10000, 0x1000))
        esperada = bytearray(img)                       # with the notes the options silence: 0Fh, a rest
        for bit, n, nota in ((2, "cinta_paso", 0x17), (4, "cinta_pitido", 0x54)):
            ok(img[e[n]] == nota, f"{n} at ${e[n]:04X} is the note {nota:02X}h in the image")
            if opc & bit:
                esperada[e[n]] = 0x0F
            ok(mem[e[n]] == esperada[e[n]],
               f"{n}: {'a rest (its sound off)' if opc & bit else 'the note kept'}: {mem[e[n]]:02X}h")
        img = bytes(esperada)
        malos = [a for a in range(0x10000) if nec[a] and mem[a] != img[a] and a not in (e["plat_unidad"], e["plat_opciones"])]
        ok(not malos, f"the game's {sum(nec)} needed bytes as the {'English' if ingles else 'Spanish'} image"
           + (f": {len(malos)} differ: " + " ".join(f"{a:04X}" for a in malos[:12]) if malos else ""))
        ok(mem[e["plat_opciones"]] == opc, f"plat_opciones = {mem[e['plat_opciones']]} (expected {opc})")
        ok(mem[e["plat_unidad"]] == UNIDAD, f"plat_unidad = {mem[e['plat_unidad']]} (expected {UNIDAD})")
        if final:
            prueba_final(v, ram, lee, foto, e, jdir, opc, out)
            print("all checks passed" if not fallos else f"{len(fallos)} checks failed")
            sys.exit(1 if fallos else 0)
        f = v.punto(e["cert_frame"], temporal=False)
        for i in range(frames):
            v.golpes.clear(); v.orden(V.CMD_EXIT)
            while not v.golpes: v._respuesta()
        foto(f"juego_frame_{frames}.png")
        ok(True, f"{frames} game frames run; the screen in juego_frame_{frames}.png")
    print("all checks passed" if not fallos else f"{len(fallos)} checks failed")
    sys.exit(1 if fallos else 0)


def corre(v, dir, limite=240):
    """on to the next pass of dir (other breakpoints ignored); no pass within `limite` seconds: where the CPU is"""
    import socket
    n = v.punto(dir, temporal=True)
    while True:
        v.golpes.clear(); v.orden(V.CMD_EXIT)
        v.s.settimeout(limite)
        try:
            while not v.golpes: v._respuesta()
        except socket.timeout:
            v.s.settimeout(None); v.para()
            r = v.registros()
            raise SystemExit(f"FAIL  no pass of ${dir:04X} in {limite} s: PC ${r[3]:04X} A {r[0]:02X} X {r[1]:02X} "
                             f"Y {r[2]:02X} SP {r[4]:02X} flags {r[5]:02X} (I = {r[5] >> 2 & 1})")
        v.s.settimeout(None)
        if n in v.golpes: return


def prueba_final(v, ram, lee, foto, e, jdir, opc, out):
    sys.path.insert(0, os.path.join(P, "c64", "presentacion", "pruebas"))
    import estado_final
    estado = bytearray(estado_final.memoria(os.path.join(out, "estado_final.bin"), juego=jdir))
    estado[e["plat_opciones"]] = opc
    estado[e["plat_unidad"]] = UNIDAD
    for i in range(0x0002, 0x10000, 0x1000):
        A.escribe_banco(v, ram, i, bytes(estado[i:min(0x10000, i + 0x1000)]))
    A.arranca_juego(v, e["principal_inicio"])
    corre(v, e["game_check_end"])
    corre(v, e["plat_final"])
    pct = lee(0x067A, 3)
    ok(pct == b"100", f"the state of day 7, tercia, solved: game_check_end, \"{pct.decode('latin-1')}\" per cent, plat_final")
    foto("final_1_juego_100.png")
    corre(v, 0x080D)                                   # the KERNAL's "FINAL" running (plat_final's stub: its SYS 2061)
    ok(lee(0x0801, 4) == open(FINAL_PRG, "rb").read()[2:6],
       "the KERNAL loaded \"FINAL\" from the disk and runs it" if DISCO else
       "the KERNAL loaded \"FINAL\" from where the tape stopped and runs it")
    corre(v, ETAPA)
    fi = V.etiquetas(os.path.join(GC, "final.lbl"))
    corre(v, 0x080D)                                   # the stage jumps to the decrunched program: before it runs
    prg = open(os.path.join(GC, "final.prg"), "rb").read()[2:]
    ok(lee(0x0801, len(prg)) == prg, f"the ending's program decrunched at $0801: equal to final.prg ({len(prg)} bytes)")
    corre(v, fi["_main"])
    ok(lee(0x02A7, 1)[0] == opc, f"OPCIONES = {lee(0x02A7, 1)[0]} at the ending's start (the menu's: {opc})")
    corre(v, fi["_musicstart"])
    import time
    v.orden(V.CMD_EXIT); time.sleep(3); v.registros()  # (3 s of the parchment, in warp: its pages drawn; the
                                                       # tape's ending reads no key)
    foto("final_2_pergamino.png")
    ok(True, "the ending's parchment on the screen: final_2_pergamino.png")


ETAPA = 0xC000
UNIDAD, FINAL_PRG, DISCO = 1, os.path.join(G, "arranque_ETAPA_FIN.prg"), False


if __name__ == "__main__":
    main()
