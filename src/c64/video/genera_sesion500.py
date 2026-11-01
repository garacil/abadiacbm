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

"""Makes sesion500.py from sesion128.py (the video in both languages for the P500 too), counted replacements: the
P500 (xcbm5x0: the CBM-II 510 with 128 KiB, an 8050 with the disk c64/discop500/abadia128ks_p500.d80), its start (no
autostart: DLOAD"ABADIA" and RUN typed into the KERNAL's buffer of bank 15, ten places at most, each line once BASIC
shows "ready."), the start menu and the presentation of cc65's cbm510 target (c64/presentacion/generado_p500: their
keys into cc65's own buffer, keybuf / keyidx of bank 0's zero page; the menu's options in its _opciones500), bank 0 of
its RAM (the game: c64/juego_final/p500 or p500_en), the 6509's indirect bank register $01 = 0 instead of the C128's
MMU in the planner's call, and the ending ("FINAL", started by the loader's last stage from bank 1: its _main)."""
import os, sys

D = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, os.path.join(D, "..", "..", "..", "tools"))
from licencia import cabecera   # my licence header, on the file written too
t = open(os.path.join(D, "sesion128.py"), encoding="utf-8").read()


def r(antes, despues, veces=1):
    global t
    n = t.count(antes)
    if n != veces:
        sys.exit(f"expected {veces} of {antes!r}, found {n}")
    t = t.replace(antes, despues)


r('PRES = ROOT / "c64/presentacion/generado_c128"\n'
  'MENU = ROOT / "c64/disco128/generado/menu.lbl"\n'
  'DISCO = ROOT / "c64/disco128/abadia128ks.d64"\n'
  'OPCIONES = 0x0BFF                    # the C128 menu\'s options (c64/disco128/disco128.inc)\n'
  'MENU_TECLA = V.etiquetas(str(MENU))["tecla"]\n\n\n'
  'def juego_dir():\n'
  '    return ROOT / "c64/juego_final" / ("c128_en" if IDIOMA == "en" else "c128")\n',
  'PRES = ROOT / "c64/presentacion/generado_p500"\n'
  'DISCO = ROOT / "c64/discop500/abadia128ks_p500.d80"\n'
  '_AB = V.etiquetas(str(PRES / "abadia.lbl"))\n'
  'OPCIONES = _AB["_opciones500"]       # the P500 menu\'s options (c64/presentacion/menu500.c), bank 0\n'
  'MENU_TECLA = _AB["_cgetc"]           # the menu waits for a key in cc65\'s cgetc\n'
  'READY = bytes([0x12, 0x05, 0x01, 0x04, 0x19, 0x2E])    # "ready." in screen codes\n\n\n'
  'def juego_dir():\n'
  '    return ROOT / "c64/juego_final" / ("p500_en" if IDIOMA == "en" else "p500")\n\n\n'
  'def ready(v):\n'
  '    """how many "ready." the P500\'s text screen shows ($D000 of bank 15: the monitor\'s I/O bank, 16)"""\n'
  '    _, c = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, 0xD000, 0xD3E7, 0, 16))\n'
  '    return c[2:].count(READY)\n\n\n'
  'def teclea_kernal(v, texto):\n'
  '    """into the KERNAL\'s keyboard buffer of bank 15 ($03AB, its count $D1: ten places, $03B5 on is a vector), in\n'
  '    pieces taken by the screen editor one after the other"""\n'
  '    for k in range(0, len(texto), 10):\n'
  '        p = texto[k:k + 10].encode("ascii")\n'
  '        v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0x03AB, 0x03AB + len(p) - 1, 0, 15) + p)\n'
  '        v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0xD1, 0xD1, 0, 15) + bytes([len(p)]))\n'
  '        v.orden(V.CMD_EXIT)\n'
  '        time.sleep(0.4)\n'
  '        v.orden(V.CMD_PING)\n\n\n'
  'def espera_ready(v, antes, limite=300):\n'
  '    t0 = time.monotonic()\n'
  '    while time.monotonic() - t0 < limite:\n'
  '        n = ready(v)\n'
  '        if n > antes:\n'
  '            return n\n'
  '        v.orden(V.CMD_EXIT)\n'
  '        time.sleep(0.5)\n'
  '        v.orden(V.CMD_PING)\n'
  '    raise RuntimeError("the P500 shows no ready.")\n\n\n'
  'def arranca_p500(v):\n'
  '    """the P500\'s start: BASIC ready, DLOAD"ABADIA", ready again, RUN: the start menu waiting for a key"""\n'
  '    v.orden(V.CMD_PING)\n'
  '    n = espera_ready(v, 0)\n'
  '    teclea_kernal(v, \'DLOAD"ABADIA"\\r\')\n'
  '    espera_ready(v, n)\n'
  '    p = b"RUN\\r"\n'
  '    v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0x03AB, 0x03AB + len(p) - 1, 0, 15) + p)\n'
  '    v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0xD1, 0xD1, 0, 15) + bytes([len(p)]))\n'
  '    v.hasta(MENU_TECLA, limite=900)\n\n\n'
  'def tecla_cc65(v, c):\n'
  '    """a key into cc65\'s buffer (the menu and the presentation read it with cgetc / kbhit)"""\n'
  '    v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, _AB["keybuf"], _AB["keybuf"], 0, 0) + c.encode("ascii"))\n'
  '    v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, _AB["keyidx"], _AB["keyidx"], 0, 0) + b"\\x01")\n')
r('cmd = ["x128", "-default", "-seed", "64", "+autostart-delay-random", "-hidevdcwindow", "-40col",',
  'cmd = ["xcbm5x0", "-default", "-seed", "64", "-model", "510", "-ramsize", "128", "-pal",')
r('               "-drive8type", "1541", "-drive8truedrive",', '               "-drive8type", "8050", "-drive8truedrive",')
r('        self.hasta(MENU_TECLA, limite=900)       # the boot sector, the menu\n',
  '        arranca_p500(self)                      # DLOAD, RUN: the menu\n')
r('code = bytearray((0x78, 0xD8, 0xA9, 0x3E, 0x8D, 0x00, 0xFF, 0xA9, mask, 0x85, 2))   # (the MMU: block 0 with the I/O)',
  'code = bytearray((0x78, 0xD8, 0xA9, 0x00, 0x85, 0x01, 0xA9, mask, 0x85, 2))   # (the 6509\'s indirect bank register: bank 0)')
r('        menu = V.etiquetas(str(MENU))\n', '')
r('            D.corre_hasta(v, menu["tecla"], limite=900)\n            marca(out, "menu")\n',
  '            marca(out, "menu")                              # (the start already stopped at the menu\'s key)\n')
r('                D.escribe(v, "1")                           # option 1: the language (the menu in English)\n',
  '                tecla_cc65(v, "1")                          # option 1: the language (the menu in English)\n')
r('                raise RuntimeError("the menu\'s options (OPCIONES $0BFF) are not the language asked for")\n'
  '            D.escribe(v, " ")\n',
  '                raise RuntimeError("the menu\'s options (_opciones500) are not the language asked for")\n'
  '            tecla_cc65(v, " ")\n')
r('            marca(out, "introduccion_fin")\n            D.escribe(v, " ")\n',
  '            marca(out, "introduccion_fin")\n            tecla_cc65(v, " ")\n')
r('            D.corre_hasta(v, 0x1C0D, limite=900)            # the KERNAL\'s "FINAL" loaded at $1C01, its SYS\n', '')
r('    _, c = v.orden(V.CMD_CHECKPOINT_SET, struct.pack("<HHBBBBB", 0xA2, 0xA2, 1, 1, 2, 0, 0))   # (store, kept)\n',
  '    # (the P500: cc65\'s own clock, its `time` in bank 0\'s zero page, counted up by its 50 Hz interrupt, kudtim.s)\n'
  '    _, c = v.orden(V.CMD_CHECKPOINT_SET, struct.pack("<HHBBBBB", _AB["time"], _AB["time"], 1, 1, 2, 0, 0))\n')
r('        for _ in range(int(segundos * 60)):\n', '        for _ in range(int(segundos * 50)):\n')
r('        if not args.ensayo_vice:\n            planning_out = out / "planificador"\n',
  '        if True:                                # (the P500: the planner runs in a second VICE, the rehearsal\'s too,\n'
  '            # its snapshots restored without the game\'s interrupt, as it always ran; the visible one gets its\n'
  '            # interrupt back after a restore: Visible.restaura)\n'
  '            planning_out = out / "planificador"\n')
r('            oracle = Visible(planning_out, warp=True, disk=args.disco.resolve())\n',
  '            oracle = Visible(planning_out, warp=True, disk=args.disco.resolve())\n'
  '            oracle.oraculo = True\n')
r('    def record(self, out, video=None):\n',
  '    def restaura(self, nombre):\n'
  '        """VICE 3.10\'s xcbm5x0 restores the 6526 with its interrupt pending and TPI 1 waiting for an edge that does not\n'
  '        come (checked: ICR 81h, no tick afterwards): the game\'s own acknowledgement after the restore (the 6526\'s ICR\n'
  '        read, TPI 1\'s AIR written back, the ICR read again, through the monitor\'s I/O bank 16) brings the tick back\n'
  '        (checked).  Not on the planner\'s VICE, whose code always ran without it."""\n'
  '        V.Vice.restaura(self, nombre)\n'
  '        if not getattr(self, "oraculo", False):\n'
  '            self.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 1, 0xDC0D, 0xDC0D, 0, 16))\n'
  '            _, c = self.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, 0xDE07, 0xDE07, 0, 16))\n'
  '            self.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0xDE07, 0xDE07, 0, 16) + c[2:3])\n'
  '            self.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 1, 0xDC0D, 0xDC0D, 0, 16))\n\n'
  '    def record(self, out, video=None):\n')
r('        self.puerto = 6520 + os.getpid() % 1000 if warp else int(os.environ.get("ABADIA_PUERTO", "6519"))\n',
  '        Visible.n = getattr(Visible, "n", 0) + 1         # (the rehearsal\'s two VICEs, both in warp: a port each)\n'
  '        self.puerto = 6520 + os.getpid() % 500 * 2 + Visible.n if warp else int(os.environ.get("ABADIA_PUERTO", "6519"))\n')
r('        self.registro = (out / "vice.log").open("w")\n',
  '        self.registro = (out / "vice.log").open("a")\n'
  '        self.salida_dir, self.disco = out, disk          # (a new oracle, the same as this one: nuevo_oraculo)\n')
r('            self.oracle.restaura(str(checkpoint))\n',
  '            try:\n'
  '                self.oracle.restaura(str(checkpoint))\n'
  '            except Exception as exc:                # (VICE\'s xcbm5x0 fails a restore after many of them, the\n'
  '                print("Oráculo: restauración fallida, otro VICE:", exc, flush=True)   # snapshot itself good)\n'
  '                self.oracle = nuevo_oraculo(self.oracle)\n'
  '                self.oracle.restaura(str(checkpoint))\n')
r('def marca(out, nombre):\n',
  'def nuevo_oraculo(viejo):\n'
  '    """the planner\'s VICE closed (it may have died) and another one started the same way"""\n'
  '    try:\n'
  '        viejo.orden(V.CMD_QUIT)\n'
  '    except Exception:\n'
  '        pass\n'
  '    try:\n'
  '        viejo.proc.kill()\n'
  '        viejo.proc.wait(timeout=20)\n'
  '        viejo.s.close()\n'
  '        if viejo.xvfb:\n'
  '            viejo.xvfb.terminate()\n'
  '            viejo.xvfb.wait(timeout=10)\n'
  '    except Exception:\n'
  '        pass\n'
  '    nuevo = Visible(viejo.salida_dir, warp=True, disk=viejo.disco)\n'
  '    nuevo.oraculo = True\n'
  '    return nuevo\n\n\n'
  'def marca(out, nombre):\n')
r('        if oracle:\n'
  '            oracle.orden(V.CMD_QUIT)\n'
  '            oracle.proc.wait(timeout=20)\n'
  '            oracle.s.close()\n'
  '            if oracle.xvfb:\n'
  '                oracle.xvfb.terminate()\n'
  '                oracle.xvfb.wait(timeout=10)\n',
  '        if oracle:\n'
  '            oracle = getattr(engine, "oracle", None) or oracle if "engine" in locals() else oracle   # (maybe a new one)\n'
  '            try:\n'
  '                oracle.orden(V.CMD_QUIT)\n'
  '                oracle.proc.wait(timeout=20)\n'
  '                oracle.s.close()\n'
  '            except Exception:\n'
  '                pass\n'
  '            if oracle.xvfb:\n'
  '                oracle.xvfb.terminate()\n'
  '                oracle.xvfb.wait(timeout=10)\n')
head = ('#!/usr/bin/env python3\n' + cabecera("hash") + '\n"""Generated by genera_sesion500.py from sesion128.py; do not edit.  The C64 pilot\'s visible session on the P500\n'
        '(the CBM-II 510) with the abadia128ks_p500 disk (the full game; its menu, Spanish or English), recorded on a virtual\n'
        'X display."""\n')
body = t.split('"""', 2)[2]
open(os.path.join(D, "sesion500.py"), "w", encoding="utf-8").write(head + body)
print("sesion500.py written")
