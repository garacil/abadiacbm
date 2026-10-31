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

"""A client of VICE's binary monitor (x64sc -binarymonitor), for deterministic tests on Xvfb :99.

The emulator is driven only through emulator hooks: checkpoints at addresses of the program under test
(from ld65's label file), memory reads and writes, the joystick port value and snapshots, all while the
emulation is stopped.  What the program does is a function of the emulated cycles alone, so the results
do not depend on the host's speed (VICE's random autostart delay off, its random seed fixed).

    with Vice("t.prg") as v:
        v.hasta(e["fin"])                  # run until the program reaches its barrier `fin: JMP fin`
        datos = v.lee(0xC000, 0xC3E7)
        v.captura("t.png")                 # the screen as the VIC-II shows it (no GUI involved)
        v.pasa(e["fin"])                   # and on past it

Inputs: the keyboard matrix and the joysticks are part of the machine's snapshot (modules KEYBOARD and
JOYSTICK0/1): instantanea(), patch the file, restaura() (prueba.py's `entradas`); the monitor's own
"joyport set" command had no effect in VICE 3.10.

Protocol: VICE's "Binary Monitor" documentation (API version 2, VICE 3.7 and later).
"""
import os, shutil, socket, struct, subprocess, tempfile, time, zlib

STX = 0x02
API = 0x02
EVENTO = 0xFFFFFFFF

CMD_MEM_GET, CMD_MEM_SET = 0x01, 0x02
CMD_CHECKPOINT_SET, CMD_CHECKPOINT_DELETE = 0x12, 0x13
CMD_REGISTERS_GET, CMD_REGISTERS_SET = 0x31, 0x32
CMD_DUMP, CMD_UNDUMP = 0x41, 0x42
CMD_DISPLAY_GET, CMD_PALETTE_GET = 0x84, 0x91
CMD_JOYPORT_SET = 0xA2
CMD_EXIT, CMD_QUIT, CMD_PING = 0xAA, 0xBB, 0x81
RESP_STOPPED, RESP_RESUMED, RESP_JAM, RESP_CHECKPOINT = 0x62, 0x63, 0x61, 0x11


def etiquetas(lbl):
    """ld65's -Ln file (VICE labels: 'al C:0801 .nombre') -> {nombre: address}"""
    out = {}
    for linea in open(lbl):
        t = linea.split()
        if len(t) == 3 and t[0] == "al":
            out[t[2].lstrip(".")] = int(t[1].split(":")[-1], 16)
    return out


def png(nombre, ancho, alto, rgb):
    """a minimal PNG writer (8-bit RGB), so the tests need no imaging library"""
    filas = b"".join(b"\x00" + rgb[y * ancho * 3:(y + 1) * ancho * 3] for y in range(alto))
    def trozo(tipo, datos):
        return struct.pack(">I", len(datos)) + tipo + datos + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF)
    with open(nombre, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + trozo(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0))
                + trozo(b"IDAT", zlib.compress(filas, 9)) + trozo(b"IEND", b""))


class Vice:
    def __init__(self, prg, opciones=(), puerto=None, disco=None, registro=None):
        self.puerto = puerto or 6510 + os.getpid() % 1000
        self.casa = tempfile.mkdtemp(prefix="vice_mb_")
        os.makedirs(os.path.join(self.casa, ".local/state/vice"))
        os.makedirs(os.path.join(self.casa, "xdg"), mode=0o700)
        entorno = dict(os.environ, HOME=self.casa, XDG_RUNTIME_DIR=os.path.join(self.casa, "xdg"),
                       DISPLAY=os.environ.get("VICE_DISPLAY", ":99"))
        orden = [os.environ.get("VICE_EMU", "x64sc"), "-default", "-seed", "64", "+autostart-delay-random",   # VICE_EMU: x128...
                 "-VICIIfilter", "0", "-VICIIglfilter", "0", "-VICIIdscan", "-binarymonitor",
                 "-binarymonitoraddress", f"ip4://127.0.0.1:{self.puerto}"]
        orden += list(opciones)
        if disco:
            orden += ["-8", disco]
        if prg:
            orden += ["-autostart", prg, "-autostartprgmode", "1"]
        self.registro = open(registro or os.devnull, "w")
        self.proc = subprocess.Popen(orden, env=entorno, stdout=self.registro, stderr=subprocess.STDOUT)
        self.s = None
        for _ in range(300):                       # the emulator's start-up: wait for its socket
            try:
                self.s = socket.create_connection(("127.0.0.1", self.puerto))
                break
            except OSError:
                if self.proc.poll() is not None:
                    raise RuntimeError("x64sc ended at its start")
                time.sleep(0.1)
        if not self.s:
            raise RuntimeError("no binary monitor")
        self.id = 0
        self.eventos = []
        self.parado = False
        self.pc = None
        self.paradas = 0                           # STOPPED events received
        self.golpes = set()                        # checkpoints reported hit (their numbers)
        self.jams = 0                              # CPU JAMs reported

    # ---- the protocol ----
    def _lee(self, n):
        b = b""
        while len(b) < n:
            t = self.s.recv(n - len(b))
            if not t:
                raise RuntimeError("the monitor closed the connection")
            b += t
        return b

    def _respuesta(self):
        cab = self._lee(12)
        stx, api, largo, tipo, error, rid = struct.unpack("<BBIBBI", cab)
        if stx != STX:
            raise RuntimeError("bad response")
        cuerpo = self._lee(largo)
        if tipo == RESP_STOPPED:
            self.parado = True
            self.paradas += 1
            self.pc = struct.unpack("<H", cuerpo[:2])[0]
        elif tipo == RESP_RESUMED:
            self.parado = False
        elif tipo == RESP_CHECKPOINT and rid == EVENTO and cuerpo[4]:
            self.golpes.add(struct.unpack("<I", cuerpo[:4])[0])
        elif tipo == RESP_JAM:
            self.parado = True
            self.paradas += 1
            self.pc = struct.unpack("<H", cuerpo[:2])[0]
            self.eventos.append(("jam", self.pc))
            self.jams += 1
        return tipo, error, rid, cuerpo

    def orden(self, cmd, cuerpo=b""):
        self.id += 1
        rid = self.id
        self.s.sendall(struct.pack("<BBIIB", STX, API, len(cuerpo), rid, cmd) + cuerpo)
        while True:
            tipo, error, r, c = self._respuesta()
            if r == rid:
                if error:
                    raise RuntimeError(f"monitor command {cmd:02X}: error {error:02X}")
                return tipo, c
            self.eventos.append((tipo, c))

    # ---- what the tests use ----
    def para(self):
        """stop the emulation (any command does) and wait until it is stopped"""
        self.orden(CMD_PING)

    def lee(self, ini, fin):
        _, c = self.orden(CMD_MEM_GET, struct.pack("<BHHBH", 0, ini, fin, 0, 0))
        n = struct.unpack("<H", c[:2])[0]
        return c[2:2 + n]

    def escribe(self, ini, datos):
        self.orden(CMD_MEM_SET, struct.pack("<BHHBH", 0, ini, ini + len(datos) - 1, 0, 0) + bytes(datos))

    def punto(self, dir, temporal=True):
        _, c = self.orden(CMD_CHECKPOINT_SET, struct.pack("<HHBBBBB", dir, dir, 1, 1, 4, 1 if temporal else 0, 0))
        return struct.unpack("<I", c[:4])[0]

    def hasta(self, dir, limite=600):
        """run until the program reaches dir, which must be a barrier `dir: JMP dir` (the program waits there
        with the interrupts off until the test moves it on with pasa()): a temporary checkpoint at dir,
        waited for by its own hit event, then the PC is checked.  (VICE 3.10 may resume once more after a
        checkpoint hit soon after an EXIT: the barrier keeps the program where it was.)"""
        num = self.punto(dir)
        self.golpes.discard(num)
        self.orden(CMD_EXIT)
        self.s.settimeout(limite)
        try:
            j = self.jams
            while num not in self.golpes and self.jams == j:
                self._respuesta()
        finally:
            self.s.settimeout(None)
        pc = self.registros()[3]
        self.parado = True
        self.pc = pc
        if pc != dir:
            raise RuntimeError(f"stopped at {pc:04X}, not at {dir:04X}")
        return pc

    def pasa(self, dir):
        """move the program on past the barrier at dir (PC := dir + 3)"""
        self.pon_pc(dir + 3)

    def pon_pc(self, pc):
        self.orden(CMD_REGISTERS_SET, struct.pack("<BHBBH", 0, 1, 3, 3, pc))

    def registros(self):
        _, c = self.orden(CMD_REGISTERS_GET, struct.pack("<B", 0))
        n = struct.unpack("<H", c[:2])[0]
        out = {}
        for i in range(n):
            tam, rid, val = struct.unpack("<BBH", c[2 + 4 * i:6 + 4 * i])
            out[rid] = val
        return out

    def joystick(self, puerto, valor):
        """the value of a control port: bits 0-4 up, down, left, right, fire, 1 = pressed"""
        self.orden(CMD_JOYPORT_SET, struct.pack("<HH", puerto, valor))

    def foto(self, borde=(32, 35, 32, 37)):
        """the screen as the VIC-II shows it: (width, height, RGB bytes, colour indices) of the 320 x 200 display
        window with `borde` pixels of border around it (left, top, right, bottom: VICE's normal borders, a
        384 x 272 picture)"""
        _, c = self.orden(CMD_DISPLAY_GET, struct.pack("<BB", 1, 0))
        (campo, ancho_d, alto_d, ox, oy, ancho, alto, bpp) = struct.unpack("<IHHHHHHB", c[:17])
        largo = struct.unpack("<I", c[17:21])[0]
        buf = c[21:21 + largo]
        if len(buf) < largo:                       # (x128 sends its VIC-II picture 4 bytes short: the last
            buf += bytes(largo - len(buf))         # border pixels; x64sc sends it whole)
        _, p = self.orden(CMD_PALETTE_GET, struct.pack("<B", 1))
        n = struct.unpack("<H", p[:2])[0]
        pal = []
        k = 2
        for _ in range(n):
            tam = p[k]
            pal.append(bytes(p[k + 1:k + 4]))
            k += 1 + tam
        x0, y0 = max(0, ox - borde[0]), max(0, oy - borde[1])
        x1, y1 = min(ancho_d, ox + ancho + borde[2]), min(alto_d, oy + alto + borde[3])
        idx = bytes(buf[y * ancho_d + x] for y in range(y0, y1) for x in range(x0, x1))
        return x1 - x0, y1 - y0, b"".join(pal[i] for i in idx), idx

    def captura(self, nombre):
        ancho, alto, rgb, _ = self.foto()
        png(nombre, ancho, alto, rgb)

    def instantanea(self, nombre):
        self.orden(CMD_DUMP, struct.pack("<BBB", 0, 0, len(nombre)) + nombre.encode())

    def restaura(self, nombre):
        self.orden(CMD_UNDUMP, struct.pack("<B", len(nombre)) + nombre.encode())

    def cierra(self):
        try:
            if self.s:
                self.orden(CMD_QUIT)
        except Exception:
            pass
        try:
            self.proc.wait(timeout=20)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()
        self.registro.close()
        shutil.rmtree(self.casa, ignore_errors=True)

    def __enter__(self):
        return self

    def __exit__(self, *a):
        self.cierra()
