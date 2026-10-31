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

"""Makes sesion64.py from the pilot's session of the English disk (sesion_base.py: a copy of the separate
English edition's c64/ingles/partida/sesion_en.py, the one that won the whole game in VICE) with counted replacements, for
the abadia64ks release (a video of the 64ks version showing everything, one video in English
and another in Spanish): the C64 disk with the tape's menu (c64/disco64/abadia64ks.d64), the language chosen in
the menu (--idioma es|en: the game c64/juego_final/c64disco or c64disco_en), the presentation for that disk
(c64/presentacion/generado_disco64), the ending that reads no key (its end is the loop at FIN_FINAL), the times of
the session's events in marcas.json (for monta.py: the loads cut, the chapters), the VICE helpers of ayudas.py.
The pilot (piloto.py), its strategy, the supervision and the recording are not rewritten.  Each replacement must match
exactly the expected number of times."""
import os, sys

D = os.path.dirname(os.path.realpath(__file__))
t = open(os.path.join(D, "sesion_base.py"), encoding="utf-8").read()


def r(antes, despues, veces=1):
    global t
    n = t.count(antes)
    if n != veces:
        sys.exit(f"expected {veces} of {antes!r}, found {n}")
    t = t.replace(antes, despues)


r('sys.path[:0] = [str(ROOT / "c64/ingles/pruebas"), str(ROOT / "c64/plataforma/pruebas")]\nimport vice_mb as V\nimport prueba_en as D',
  'sys.path[:0] = [str(HERE), str(ROOT / "c64/plataforma/pruebas")]\nimport vice_mb as V\nimport ayudas as D')
r('GRABAR = True\n',
  'GRABAR = True\n'
  'IDIOMA = "es"                       # the menu\'s language (--idioma)\n'
  'PRES = ROOT / "c64/presentacion/generado_disco64"\n'
  'MENU = ROOT / "c64/disco64/generado/menu.lbl"\n'
  'DISCO = ROOT / "c64/disco64/abadia64ks.d64"\n\n\n'
  'def juego_dir():\n'
  '    return ROOT / "c64/juego_final" / ("c64disco_en" if IDIOMA == "en" else "c64disco")\n\n\n'
  'def marca(out, nombre):\n'
  '    """the moment of an event of the session (wall clock), for monta.py"""\n'
  '    path = out / "marcas.json"\n'
  '    marcas = json.loads(path.read_text()) if path.exists() else []\n'
  '    marcas.append([nombre, time.time()])\n'
  '    save_json(path, marcas)\n'
  '    print("marca", nombre, flush=True)\n\n\n'
  'def espera(v, segundos):\n'
  '    """the machine runs on for a while (the menu, a page held), counted in the KERNAL\'s jiffies (the store to\n'
  '    $A2, 60 a second), so that the rehearsal in warp and the recording in real time reach the game at the same\n'
  '    emulated moment (wall-clock waits made them differ: the game\'s random numbers come from the machine\'s time)"""\n'
  '    _, c = v.orden(V.CMD_CHECKPOINT_SET, struct.pack("<HHBBBBB", 0xA2, 0xA2, 1, 1, 2, 0, 0))   # (store, kept)\n'
  '    num = struct.unpack("<I", c[:4])[0]\n'
  '    try:\n'
  '        for _ in range(int(segundos * 60)):\n'
  '            v.golpes.discard(num)\n'
  '            v.orden(V.CMD_EXIT)\n'
  '            v.s.settimeout(30)\n'
  '            while num not in v.golpes:\n'
  '                v._respuesta()\n'
  '            v.s.settimeout(None)\n'
  '    finally:\n'
  '        v.s.settimeout(None)\n'
  '        v.orden(V.CMD_CHECKPOINT_DELETE, struct.pack("<I", num))\n')
r('self.puerto = 6520 + os.getpid() % 1000 if warp else 6519',
  'self.puerto = 6520 + os.getpid() % 1000 if warp else int(os.environ.get("ABADIA_PUERTO", "6519"))\n'
  '        try:                                          # (a VICE left on that port would answer instead of ours)\n'
  '            socket.create_connection(("127.0.0.1", self.puerto), timeout=0.5).close()\n'
  '            raise RuntimeError(f"the monitor port {self.puerto} is in use: another VICE is listening there")\n'
  '        except OSError:\n'
  '            pass')
r('            # Leave the emulator visible, paused if blocked or playing the last parchment if won.\n'
  '            if args.ensayo_vice:\n',
  '            # (the recordings run on a virtual display: their emulator is closed at the end too, so that it does\n'
  '            # not keep its monitor port for the next session)\n'
  '            if args.ensayo_vice or os.environ.get("ABADIA_DISPLAY", ":99") != ":0":\n')
r('"-8", str(disk or ROOT / "c64/disco/abadia64ks_english.d64")]', '"-8", str(disk or DISCO)]')
r('        self.recording = subprocess.Popen(cmd, env=self.env, stdout=self.record_log, stderr=subprocess.STDOUT)\n',
  '        self.recording = subprocess.Popen(cmd, env=self.env, stdout=self.record_log, stderr=subprocess.STDOUT)\n'
  '        marca(out, "grabacion")\n')
r('self.labels = V.etiquetas(str(ROOT / "c64/juego_final_en/c64/juego.lbl"))',
  'self.labels = V.etiquetas(str(juego_dir() / "juego.lbl"))')
r('(ROOT / "c64/juego_final_en/mapa64.tsv")', '(ROOT / "c64/juego_final/mapa64.tsv")')
r('        if hour != self.last_hour:\n            self.snapshot(f"dia{hour[0]}_hora{hour[1]}_frame{self.frame}")\n',
  '        if hour != self.last_hour:\n            self.snapshot(f"dia{hour[0]}_hora{hour[1]}_frame{self.frame}")\n'
  '            marca(self.out, f"dia{hour[0]}_hora{hour[1]}")\n')
r('    parser.add_argument("--disco", type=Path, default=ROOT / "c64/disco/abadia64ks_english.d64",\n'
  '                        help="disco de la próxima grabación (por defecto la versión mejorada)")',
  '    parser.add_argument("--disco", type=Path, default=DISCO, help="el disco del 64ks con el menú de la cinta")\n'
  '    parser.add_argument("--idioma", choices=("es", "en"), default="es", help="el idioma elegido en el menú")')
r('    args = parser.parse_args()\n    global GRABAR\n    GRABAR = not args.sin_grabar\n',
  '    args = parser.parse_args()\n    global GRABAR, IDIOMA\n    GRABAR = not args.sin_grabar\n    IDIOMA = args.idioma\n')
r('        ab = V.etiquetas(str(ROOT / "c64/presentacion_en/generado/abadia.lbl"))\n'
  '        fi = V.etiquetas(str(ROOT / "c64/presentacion_en/generado/final.lbl"))\n'
  '        carg = V.etiquetas(str(ROOT / "c64/presentacion_en/generado/cargador.lbl"))\n'
  '        game = V.etiquetas(str(ROOT / "c64/juego_final_en/c64/juego.lbl"))\n',
  '        ab = V.etiquetas(str(PRES / "abadia.lbl"))\n'
  '        fi = V.etiquetas(str(PRES / "final.lbl"))\n'
  '        carg = V.etiquetas(str(PRES / "cargador.lbl"))\n'
  '        menu = V.etiquetas(str(MENU))\n'
  '        game = V.etiquetas(str(juego_dir() / "juego.lbl"))\n')
r('            D.escribe(v, \'LOAD"*",8,1\\rRUN\\r\')\n'
  '            D.corre_hasta(v, ab["_musicstart"], limite=900)\n'
  '            intro = parchment(v, ab, out, "introduccion")\n'
  '            D.escribe(v, " ")\n'
  '            D.corre_hasta(v, carg["inicio"], limite=120)\n'
  '            print("Introducción completa; cargando el juego", flush=True)\n'
  '            D.corre_hasta(v, game["principal_inicio"], limite=900)\n',
  '            D.escribe(v, \'LOAD"*",8,1\\rRUN\\r\')\n'
  '            D.corre_hasta(v, menu["tecla"], limite=900)\n'
  '            marca(out, "menu")\n'
  '            espera(v, 6)                                    # the menu on the screen\n'
  '            if IDIOMA == "en":\n'
  '                D.escribe(v, "1")                           # option 1: the language (the menu in English)\n'
  '                espera(v, 5)\n'
  '                marca(out, "menu_ingles")\n'
  '            ram = D.bancos(v)["ram"]\n'
  '            if D.lee(v, ram, 0x02A7, 0x02A7)[0] != (1 if IDIOMA == "en" else 0):\n'
  '                raise RuntimeError("the menu\'s options (OPCIONES $02A7) are not the language asked for")\n'
  '            D.escribe(v, " ")\n'
  '            marca(out, "menu_espacio")\n'
  '            D.corre_hasta(v, ab["_musicstart"], limite=900)\n'
  '            marca(out, "introduccion")\n'
  '            intro = parchment(v, ab, out, "introduccion")\n'
  '            marca(out, "introduccion_fin")\n'
  '            D.escribe(v, " ")\n'
  '            marca(out, "carga_juego")\n'
  '            D.corre_hasta(v, carg["inicio"], limite=120)\n'
  '            print("Introducción completa; cargando el juego", flush=True)\n'
  '            D.corre_hasta(v, game["principal_inicio"], limite=900)\n'
  '            marca(out, "juego")\n')
r('            print("Victoria real: el juego carga el pergamino final desde el disco", flush=True)\n'
  '            D.corre_hasta(v, fi["_musicstart"], limite=900)\n'
  '            pages = parchment(v, fi, out, "final")\n'
  '            engine.status("completo", intro_pages=intro, final_pages=pages)\n'
  '            v.orden(V.CMD_EXIT)\n'
  '            time.sleep(15)\n',
  '            print("Victoria real: el juego carga el pergamino final desde el disco", flush=True)\n'
  '            marca(out, "final_carga")\n'
  '            D.corre_hasta(v, 0x080D, limite=900)            # the KERNAL\'s "FINAL" runs (its SYS 2061)\n'
  '            D.corre_hasta(v, 0xC000, limite=120)            # the ending\'s stage\n'
  '            D.corre_hasta(v, 0x080D, limite=900)            # the ending decrunched\n'
  '            D.corre_hasta(v, fi["_main"], limite=120)\n'
  '            D.corre_hasta(v, fi["_musicstart"], limite=120)\n'
  '            marca(out, "final")\n'
  '            pages = parchment_final(v, fi, out)\n'
  '            marca(out, "final_fin")\n'
  '            engine.status("completo", intro_pages=intro, final_pages=pages)\n'
  '            v.orden(V.CMD_EXIT)\n'
  '            time.sleep(20)                                  # the ending\'s last page held (its music goes on)\n'
  '            marca(out, "final_espera")\n')
r('def main():\n',
  'def parchment_final(v, labels, out):\n'
  '    """the ending: its pages (nextpage), its end the loop the disk\'s ending stays in (it reads no key: final.c)"""\n'
  '    prg = (PRES / "final.prg").read_bytes()\n'
  '    base, d = prg[0] | prg[1] << 8, prg[2:]\n'
  '    lazos = [base + i for i in range(len(d) - 2) if d[i] == 0x4C and d[i + 1] | d[i + 2] << 8 == base + i]\n'
  '    if len(lazos) != 1:\n'
  '        raise RuntimeError(f"the ending\'s end loop: {len(lazos)} found")\n'
  '    points = D.Puntos(v)\n'
  '    points.pon(labels["_nextpage"])\n'
  '    points.pon(lazos[0])\n'
  '    page = 1\n'
  '    while True:\n'
  '        pc = points.siguiente(limite=900)\n'
  '        v.captura(str(out / f"final_pagina_{page:02}.png"))\n'
  '        print(f"final: página {page} completa", flush=True)\n'
  '        page += 1\n'
  '        if pc == lazos[0]:\n'
  '            points.fuera()\n'
  '            return page - 1\n\n\n'
  'def main():\n')
r('            for args in (["module-null-sink", "sink_name=" + sink, "rate=48000", "channels=2"],\n'
  '                         ["module-loopback", "source=" + sink + ".monitor", "latency_msec=20"]):',
  '            for args in (["module-null-sink", "sink_name=" + sink, "rate=48000", "channels=2"],):   '
  '# (no loopback to the speakers: two recordings at once)')
head = ('#!/usr/bin/env python3\n"""Generated by genera_sesion64.py from sesion_base.py; do not edit.  The C64 pilot\'s visible session\n'
        'with the abadia64ks disk (the tape\'s menu, Spanish or English), recorded on a virtual X display."""\n')
body = t.split('"""', 2)[2]
open(os.path.join(D, "sesion64.py"), "w", encoding="utf-8").write(head + 'from __future__ import annotations\n' + body.replace("from __future__ import annotations\n", "", 1))
print("sesion64.py written")
