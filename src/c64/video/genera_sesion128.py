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

"""Makes sesion128.py from sesion64.py (the video in both languages for the 128ks version
too), counted replacements: the C128 (x128, its 40-column VIC-II window only, the disk's boot sector:
c64/disco128/abadia128ks.d64), block 0 of its RAM (the game: c64/juego_final/c128 or c128_en, its map without the
blocks of block 1), the MMU's $FF00 instead of the 6510's $01 in the planner's call, the menu's options at $0BFF,
the presentation and ending for the C128 (c64/presentacion/generado_c128: the game loads under its picture from
_gameload; the ending is the KERNAL's "FINAL" at $1C01, it reads no key), and the full game's height lists (the
pilot's floor_map reads them from the C128's own memory: the 64 KiB game's are in its CPC image).  The pilot's
strategy is the C64 one, as it was for the PC's full game (abadia-english/partida/piloto: only the fifth night's way
back differs there, a matter of the PC engine's hook speed)."""
import os, sys

D = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, os.path.join(D, "..", "..", "..", "tools"))
from licencia import cabecera   # my licence header, on the file written too
t = open(os.path.join(D, "sesion64.py"), encoding="utf-8").read()


def r(antes, despues, veces=1):
    global t
    n = t.count(antes)
    if n != veces:
        sys.exit(f"expected {veces} of {antes!r}, found {n}")
    t = t.replace(antes, despues)


r('PRES = ROOT / "c64/presentacion/generado_disco64"\n'
  'MENU = ROOT / "c64/disco64/generado/menu.lbl"\n'
  'DISCO = ROOT / "c64/disco64/abadia64ks.d64"\n\n\n'
  'def juego_dir():\n'
  '    return ROOT / "c64/juego_final" / ("c64disco_en" if IDIOMA == "en" else "c64disco")\n',
  'PRES = ROOT / "c64/presentacion/generado_c128"\n'
  'MENU = ROOT / "c64/disco128/generado/menu.lbl"\n'
  'DISCO = ROOT / "c64/disco128/abadia128ks.d64"\n'
  'OPCIONES = 0x0BFF                    # the C128 menu\'s options (c64/disco128/disco128.inc)\n'
  'MENU_TECLA = V.etiquetas(str(MENU))["tecla"]\n\n\n'
  'def juego_dir():\n'
  '    return ROOT / "c64/juego_final" / ("c128_en" if IDIOMA == "en" else "c128")\n\n\n'
  'def alturas_c128(pil, engine):\n'
  '    """the pilot\'s height maps from the C128\'s own lists (the full game\'s), not from its 64 KiB CPC image"""\n'
  '    import mapa_alturas\n'
  '    inc = {}\n'
  '    for l in (juego_dir() / "mapa64.inc").read_text().splitlines():\n'
  '        q = l.split()\n'
  '        if len(q) >= 3 and q[1] == "=" and q[2].startswith("$"): inc[q[0]] = int(q[2][1:], 16)\n'
  '    mapa_alturas.LISTS = {k: inc[f"D64_CHR_FLOOR{k}_HEIGHTS"] for k in range(3)}\n'
  '    pil.floor_map = lambda ram, floor: mapa_alturas.floor_map(engine.native, floor)\n')
r('cmd = ["x64sc", "-default", "-seed", "64", "+autostart-delay-random",',
  'cmd = ["x128", "-default", "-seed", "64", "+autostart-delay-random", "-hidevdcwindow", "-40col",')
r('        self.hasta(0xE5CD)\n', '        self.hasta(MENU_TECLA, limite=900)       # the boot sector, the menu\n')
r('        self.ram_bank = D.bancos(vice)["ram"]\n', '        self.ram_bank = D.bancos(vice)["ram00"]\n')
r('            name, old, length, new, nlength, mode, *_ = line.split()\n'
  '            if mode == "copia" and length == nlength:\n',
  '            name, old, length, new, nlength, mode, zona, *_ = line.split()\n'
  '            if mode == "copia" and length == nlength and zona != "banco1":\n')
r('(ROOT / "c64/juego_final/mapa64.tsv")', '(juego_dir() / "mapa64.tsv")')
r('code = bytearray((0x78, 0xD8, 0xA9, 0x35, 0x85, 1, 0xA9, mask, 0x85, 2))',
  'code = bytearray((0x78, 0xD8, 0xA9, 0x3E, 0x8D, 0x00, 0xFF, 0xA9, mask, 0x85, 2))   # (the MMU: block 0 with the I/O)')
r('            D.escribe(v, \'LOAD"*",8,1\\rRUN\\r\')\n'
  '            D.corre_hasta(v, menu["tecla"], limite=900)\n',
  '            D.corre_hasta(v, menu["tecla"], limite=900)\n')
r('            ram = D.bancos(v)["ram"]\n'
  '            if D.lee(v, ram, 0x02A7, 0x02A7)[0] != (1 if IDIOMA == "en" else 0):\n'
  '                raise RuntimeError("the menu\'s options (OPCIONES $02A7) are not the language asked for")\n',
  '            ram = D.bancos(v)["ram00"]\n'
  '            if D.lee(v, ram, OPCIONES, OPCIONES)[0] != (1 if IDIOMA == "en" else 0):\n'
  '                raise RuntimeError("the menu\'s options (OPCIONES $0BFF) are not the language asked for")\n')
r('            D.corre_hasta(v, carg["inicio"], limite=120)\n', '            D.corre_hasta(v, ab["_gameload"], limite=120)\n')
r('        carg = V.etiquetas(str(PRES / "cargador.lbl"))\n', '')
r('            D.corre_hasta(v, 0x080D, limite=900)            # the KERNAL\'s "FINAL" runs (its SYS 2061)\n'
  '            D.corre_hasta(v, 0xC000, limite=120)            # the ending\'s stage\n'
  '            D.corre_hasta(v, 0x080D, limite=900)            # the ending decrunched\n',
  '            D.corre_hasta(v, 0x1C0D, limite=900)            # the KERNAL\'s "FINAL" loaded at $1C01, its SYS\n')
r('        engine = Native(v, out, oracle=oracle)\n        pilot = piloto.Pilot(engine)\n',
  '        engine = Native(v, out, oracle=oracle)\n        alturas_c128(piloto, engine)\n        pilot = piloto_completo(piloto)(engine)\n')
r('                piloto = load_pilot()\n                pilot.__class__ = piloto.Pilot\n',
  '                piloto = load_pilot()\n                alturas_c128(piloto, self)\n                pilot.__class__ = piloto_completo(piloto)\n')
r('def marca(out, nombre):\n',
  'def piloto_completo(pil):\n'
  '    """the full game\'s pilot: the C64 one with the PC\'s fifth night (abadia-english/partida/piloto/ajustes_pc.py, the\n'
  '    pilot that won the PC\'s full game): taking the second key on day 5 makes the abbot hunt Guillermo at once, and\n'
  '    in the full game\'s longer abbey the planner\'s walk back to the cell is caught (the C128 rehearsal:\n'
  '    dead at BEh, 2Ch, night 5); the way back is walked with the keys, ahead of the abbot by the east gap (C8h, 34h)"""\n'
  '    class PilotoCompleto(pil.Pilot):\n'
  '        def follow(self, who, until, limit=5000):\n'
  '            \"\"\"(ABADIA_SEGUIR_TECLAS=1) following with the keys: the planner chooses the way, Guillermo walks it\n'
  '            with the keys (0.5 cells a frame, the abbot\'s pace; under the planner\'s own walk he lags and leaves the\n'
  '            abbot\'s box, ai_guillermo_is_close: obsequium - 2 each time)\"\"\"\n'
  '            if os.environ.get("ABADIA_SEGUIR_TECLAS") != "1":\n'
  '                return pil.Pilot.follow(self, who, until, limit)\n'
  '            motor = self.e\n'
  '            class SinMeta:\n'
  '                def __getattr__(s, n):\n'
  '                    if n == "set_guillermo_goal": raise AttributeError(n)\n'
  '                    return getattr(motor, n)\n'
  '            # the keys first; a stretch with no arrival (a stair the keys\' route does not climb) goes to the\n'
  '            # planner\'s own walk, and back (ABADIA_SEGUIR_TROZO iterations a stretch)\n'
  '            trozo, usados, teclas = int(os.environ.get("ABADIA_SEGUIR_TROZO", "250")), 0, True\n'
  '            while usados < limit:\n'
  '                if teclas: self.e = SinMeta()\n'
  '                try:\n'
  '                    return pil.Pilot.follow(self, who, until, min(trozo, limit - usados))\n'
  '                except pil.Blocked as e:\n'
  '                    if "Seguir al personaje" not in str(e): raise\n'
  '                    usados += trozo\n'
  '                    teclas = not teclas\n'
  '                finally:\n'
  '                    self.e = motor\n'
  '                self.log("Seguimiento: " + ("con las teclas" if teclas else "con el planificador"))\n'
  '            raise pil.Blocked(f"Seguir al personaje {who}: {self.state()}")\n'
  '        def sleep(self):\n'
  '            \"\"\"the C64 pilot\'s sleep() with the PC\'s fifth night (the day is read after midnight, as there)\"\"\"\n'
  '            self.goto(0xA8, 0x1C)\n'
  '            self.until(lambda: self.b(0x28D2) == 0)\n'
  '            if self.b(0x28D1) in (3, 5, 6):\n'
  '                self.until(lambda: self.b(0x385F) == 4)\n'
  '                self.until(lambda: not self.b(0x28F2))\n'
  '                self.step(("n",))\n'
  '                self.step(("n",))\n'
  '                if self.b(0x28D1) == 3:\n'
  '                    self.take(3)\n'
  '                    self.return_cell()\n'
  '                elif self.b(0x28D1) == 5:\n'
  '                    self.take(4)\n'
  '                    self.log("Llave en la mano: el abad nos busca; volvemos a la celda con las teclas")\n'
  '                    self.goto(0xC8, 0x34, local=True)\n'
  '                    self.goto(0xA8, 0x1C, z=2, local=True)\n'
  '                elif self.b(0x28D1) == 6:\n'
  '                    self.take(5)\n'
  '                    self.take(2)\n'
  '                    self.goto(0x56, 0x2D, z=0)\n'
  '                    self.log("Esperamos el alba en el ala oeste, fuera de la ronda del abad")\n'
  '                    self.until(lambda: int.from_bytes(self.e.read(0x28D7, 2), "little") < 300)\n'
  '                    self.goto(0x60, 0x2A, z=0)\n'
  '                    self.goto(0x84, 0x4B, 1, local=True, bounds=(0x60, 1, 254, 254))\n'
  '            self.until(lambda: self.b(0x28D2) == 1, keys=("s",))\n'
  '            self.log("Amanece")\n'
  '    return PilotoCompleto\n\n\n'
  'def marca(out, nombre):\n')
r('        self.refresh()\n        if time.monotonic() - self.last_status > 5:\n',
  '        self.refresh()\n'
  '        if os.environ.get("ABADIA_TRAZA_OBS") == "1":           # (a diagnosis: every frame the obsequium falls)\n'
  '            obs = self.virtual[0x28D0]\n'
  '            if getattr(self, "_obs", None) is not None and obs < self._obs:\n'
  '                g, a = self.virtual[0x2B87:0x2B87 + 5], self.virtual[0x2B87 + 45:0x2B87 + 50]\n'
  '                print("OBS", self.frame, self._obs, "->", obs, "G", list(g), "abad", list(a),\n'
  '                      "estado", self.virtual[0x3814], "hora", self.virtual[0x28D2], flush=True)\n'
  '            self._obs = obs\n'
  '        if time.monotonic() - self.last_status > 5:\n')
head = ('#!/usr/bin/env python3\n' + cabecera("hash") + '\n"""Generated by genera_sesion128.py from sesion64.py; do not edit.  The C64 pilot\'s visible session on the C128\n'
        'with the abadia128ks disk (the full game; its menu, Spanish or English), recorded on a virtual X display."""\n')
body = t.split('"""', 2)[2]
open(os.path.join(D, "sesion128.py"), "w", encoding="utf-8").write(head + body)
print("sesion128.py written")
