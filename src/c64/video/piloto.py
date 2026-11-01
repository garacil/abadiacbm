#!/usr/bin/env python3
"""Piloto externo por metas, sin alterar el disco, inventario, reloj o victoria.

El motor C del proyecto permite ensayar rápidamente las mismas reglas del juego.
Las rutas se verifican por posición real, no por duraciones estimadas.
"""
from __future__ import annotations

import argparse
from collections import deque
import ctypes
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[2]
_helpers = str(ROOT / "../data/llave3")
# That directory also contains an unrelated piloto.py. It must never shadow
# this module when a long-running VICE supervisor reloads its policy.
sys.path[:] = [entry for entry in sys.path if entry != _helpers]
sys.path.append(_helpers)
from mapa_alturas import floor_map
from ruta import route, celdas, DIRS, segments, square_ok

KEYS = {"up": (0, 0), "right": (0, 1), "down": (0, 2),
        "left": (1, 0), "space": (5, 7), "s": (7, 4),
        "n": (5, 6), "q": (8, 3), "r": (6, 2)}
CHARS = [0x2B87 + 15 * n for n in range(6)]
FOLLOW_DISTANCE = int(os.environ.get("ABADIA_FOLLOW_DISTANCE", "2"))
FOLLOW_RADIUS = int(os.environ.get("ABADIA_FOLLOW_RADIUS", "2"))
TRAS_ABAD = 2                           # follow(): the abbot leading Guillermo, Guillermo this many of his places behind
FOLLOW_QUANTUM = int(os.environ.get("ABADIA_FOLLOW_QUANTUM", "2"))


def follow_targets(x, y, orientation, gx, gy):
    d = FOLLOW_DISTANCE
    dx, dy = DIRS[orientation]
    if os.environ.get("ABADIA_FOLLOW_STYLE", "cardinal") == "flanks":
        candidates = [(x + forward * dx + side * dy, y + forward * dy - side * dx)
                      for forward, side in ((4, 3), (4, -3), (0, 3), (0, -3))]
        return sorted(candidates, key=lambda p: abs(p[0] - gx) + abs(p[1] - gy))
    candidates = [(x + d, y), (x - d, y), (x, y + d), (x, y - d)]
    return sorted(candidates, key=lambda p: (((p[0] - x) * dx + (p[1] - y) * dy) > 0,
                                            abs(p[0] - gx) + abs(p[1] - gy)))


class Blocked(RuntimeError):
    pass


_previous_navigation = globals().get("NPCNavigation")


class NPCNavigation:
    """The original NPC path planner and command stream, with checked movement."""
    def set_guillermo_goal(self, x, y, z, orientation=0, follow=None):
        goal = (x, y, z, orientation, follow) if follow is None else ("follow", follow)
        if getattr(self, "g_goal", None) != goal:
            self.g_goal = goal
            self.g_plan_key = None
            self.g_reset()
        self.g_enabled(True)

    def clear_guillermo_goal(self):
        self.g_goal = None
        self.g_enabled(False)

    def prepare_guillermo(self):
        goal = getattr(self, "g_goal", None)
        if goal is None:
            return
        if goal[0] == "follow":
            follow = goal[1]
            o, x, y, z = self.read(CHARS[follow] + 1, 4)
            key = (follow, x // FOLLOW_QUANTUM, y // FOLLOW_QUANTUM, z)
        else:
            x, y, z, o, follow = goal
            key = goal
        if key != getattr(self, "g_plan_key", None):
            self.g_reset()
            self.g_plan_key = key
        if self.read(CHARS[0])[0] & 1:
            return
        if self.read(CHARS[0] + 9)[0] & 128:
            stream = self.generate(x, y, z, o, follow=follow)
            if stream is None:
                self.ignore_adso = True
                try:
                    stream = self.generate(x, y, z, o, follow=follow)
                finally:
                    self.ignore_adso = False
            if stream is not None:
                self.g_load(stream)

    def team_inputs(self, keys):
        if "up" in keys and "down" not in keys:
            o, gx, gy, gz = self.read(CHARS[0] + 1, 4)
            _, ax, ay, az = self.read(CHARS[1] + 1, 4)
            dx, dy = DIRS[o]
            along = (ax - gx) * dx + (ay - gy) * dy
            across = (ax - gx) * dy - (ay - gy) * dx
            if Pilot.floor(gz) == Pilot.floor(az) and 0 < along <= 4 and abs(across) <= 1:
                return (*keys, "down")
        return keys

    def plan(self, x, y, z, orientation=1, who=0, follow=None):
        chr = CHARS[who]
        state = self.read(chr, 15)
        if state[0] & 1:
            return None
        position = bytes(state[1:6])
        key = (who, "follow", follow, x // 2, y // 2, z) if follow is not None else (who, x, y, z, orientation)
        cache = getattr(self, "navigation_cache", None)
        if cache and cache["key"] == key:
            if cache.get("position") == position:
                cache["retries"] += 1
                if cache["retries"] < 12:
                    return cache["command"]
                cache = None
        else:
            cache = None
        for _ in range(2):
            if cache is None:
                stream = self.generate(x, y, z, orientation, who, follow)
                if stream is None:
                    self.navigation_cache = None
                    return None
                cache = dict(key=key, data=stream, bit=0)
            bits = cache["data"]
            def bit():
                n = cache["bit"]
                if n >= len(bits) * 8:
                    return 1
                cache["bit"] += 1
                return (bits[n // 8] >> (7 - n % 8)) & 1
            for _ in range(3):
                if state[5] & 128 and bit():
                    cmd = bit()
                elif not state[5] & 128 and bit():
                    cmd = 1
                elif bit():
                    cmd = 2 + bit()
                elif bit():
                    cmd = 4 + bit()
                elif bit():
                    cmd = None
                elif state[5] & 128:
                    cmd = 0
                else:
                    cache["bit"] = 0
                    continue
                break
            if cmd is None:
                cache = None
                continue
            cache.update(position=position, command=cmd, retries=0)
            self.navigation_cache = cache
            return cmd
        self.navigation_cache = None
        return None


# Existing VICE sessions retain their base class while the supervisor reloads
# this module. Update that interface in place without resetting the emulator.
if _previous_navigation is not None:
    for _method in ("set_guillermo_goal", "clear_guillermo_goal", "prepare_guillermo", "team_inputs", "plan"):
        setattr(_previous_navigation, _method, NPCNavigation.__dict__[_method])
    NPCNavigation = _previous_navigation


class Pure(NPCNavigation):
    def __init__(self, mirror_numeral=1):
        lib = HERE / "puro_actores.so"
        if not lib.exists() or lib.stat().st_mtime < max((HERE / "meta_adso.c").stat().st_mtime,
                                                       (ROOT / "juego/f_personajes.c").stat().st_mtime):
            sources = sorted(x for x in (ROOT / "juego").glob("f_*.c") if x.name != "f_logica_b.c")
            subprocess.run(["gcc", "-shared", "-fPIC", "-O2", "-DJUEGO_PURO", "-DABADIA_AUTOPILOT",
                            "-I" + str(ROOT / "juego"), "-o", str(lib),
                            str(ROOT / "juego/puro/puro_host.c"),
                            str(ROOT / "juego/funciones.c"), str(HERE / "meta_adso.c"), *map(str, sources)], check=True)
        self.lib = ctypes.CDLL(str(lib))
        self.ram = (ctypes.c_uint8 * 65536).in_dll(self.lib, "ram")
        self.keys = (ctypes.c_uint8 * 16).in_dll(self.lib, "teclas_vivas")
        self.counter = ctypes.c_uint.in_dll(self.lib, "frame")
        self.lib.carga_estado(str(ROOT / "../data/cpc64/inicio_juego/ram.bin").encode(),
                              str(ROOT / "../data/cpc64/inicio_juego/estado.txt").encode())
        with tempfile.TemporaryDirectory(prefix="abadia_azar_ensayo_") as fixture:
            random_file = Path(fixture) / "aleatorio.txt"
            random_file.write_text(f"0 {mirror_numeral}\n")
            self.lib.carga_aleatorios(str(random_file).encode())
        self.inputs = []
        self.lib.corre_frame(None)
        self.lib.chr_path_find.restype = ctypes.c_bool
        self.lib.chr_read_command.restype = ctypes.c_bool

    @property
    def frame(self):
        return self.counter.value

    def step(self, keys=()):
        self.prepare_guillermo()
        if getattr(self, "g_goal", None) is not None:
            keys = (*keys, "up")
        keys = self.team_inputs(keys)
        for n in range(16):
            self.keys[n] = 0
        for k in keys:
            row, bit = KEYS[k]
            self.keys[row] |= 1 << bit
        self.inputs.append((self.frame, tuple(keys)))
        result = self.lib.corre_frame(None)
        if result == 2:
            raise StopIteration("Final alcanzado por el juego")
        if result != 1:
            raise Blocked("El motor ha terminado")

    def read(self, address, length=1):
        return bytes(self.ram[address:address + length])

    def g_enabled(self, value):
        ctypes.c_uint8.in_dll(self.lib, "meta_guillermo_active").value = int(value)

    def g_reset(self):
        self.ram[CHARS[0] + 9] = 128

    def g_load(self, stream):
        buf = (ctypes.c_uint8 * 45).in_dll(self.lib, "meta_guillermo_stream")
        buf[:] = stream
        self.ram[CHARS[0] + 9:CHARS[0] + 12] = b"\0\0\0"

    def activate(self, who, stream):
        chr = CHARS[who]
        pointer = self.ram[chr + 12] | self.ram[chr + 13] << 8
        self.ram[pointer:pointer + len(stream)] = stream
        self.ram[chr + 9:chr + 12] = b"\0\0\0"

    def adso_goal(self, x, y, z, orientation):
        self.adso_place_saved = self.read(0x3861, 3)
        for name, value in (("x", x), ("y", y), ("z", z), ("o", orientation), ("active", 1)):
            ctypes.c_uint8.in_dll(self.lib, "meta_adso_" + name).value = value
        self.lib.chr_cmd_discard(CHARS[1])

    def adso_release(self):
        ctypes.c_uint8.in_dll(self.lib, "meta_adso_active").value = 0
        self.ram[0x3861:0x3864] = self.adso_place_saved
        self.ram[0x3860] = 255
        self.lib.chr_cmd_discard(CHARS[1])

    def generate(self, x, y, z, orientation=1, who=0, follow=None):
        """Ask the game's own NPC planner, in a reversible planning sandbox.

        Only the command stream is kept. The actor executes it with the same
        collision checks as the monks; planning never changes the live world.
        """
        if self.ram[CHARS[who]] & 1:
            return None
        saved = bytes(self.ram)
        try:
            chr = CHARS[who]
            if who == 0 and getattr(self, "ignore_adso", False):
                # A teammate in a narrow passage will be asked to move ahead,
                # rather than treated as a permanently impassable wall.
                self.ram[CHARS[1] + 2] = 0
            # Borrow an existing command workspace only during planning.
            self.ram[chr + 12], self.ram[chr + 13] = 0x68, 0x35
            self.ram[chr + 9] = 0x80
            self.ram[0x0600] = 0
            self.ram[0x28FA] = 0
            self.ram[0x0213], self.ram[0x0214] = 3, 2
            self.ram[0x0203:0x0207] = bytes((x, y, (orientation << 6) | z, 255))
            if follow is not None:
                candidates = follow_targets(x, y, self.ram[CHARS[follow] + 1],
                                            self.ram[chr + 2], self.ram[chr + 3])
                targets = bytes(v for tx, ty in candidates for v in (tx, ty, z)) + b"\xff"
                self.ram[0x0203:0x0203 + len(targets)] = targets
            mask = 0x28 | self.ram[0x292A] | self.ram[0x292D]
            for door in range(0x2B35, 0x2B58, 5):
                flag = self.ram[door + 1]
                if flag & 64:
                    mask |= flag & 31
            mask = getattr(self, "diagnostic_mask", mask)
            self.lib.obj_set_door_permissions(mask)
            self.lib.chr_path_find(chr, 0x0203, 0xBFFE)
            if self.ram[chr + 9] & 0x80:
                return None
            return bytes(self.ram[0x3568:0x3568 + 45])
        finally:
            ctypes.memmove(self.ram, saved, 65536)
            self.lib.plat_ei()


class Pilot:
    def __init__(self, engine):
        self.e = engine
        self.bad = set()
        self.last_key = None
        self.events = []

    def b(self, address):
        return self.e.read(address)[0]

    def pos(self, who=0):
        return tuple(self.e.read(CHARS[who] + 1, 4))

    def state(self):
        return dict(frame=self.e.frame, day=self.b(0x28D1), hour=self.b(0x28D2),
                    G=self.pos(), A=self.pos(1), M=self.pos(2), abad=self.pos(3),
                    abad_state=self.b(0x3814), objects=self.b(0x2940),
                    obsequium=self.b(0x28D0), room=self.b(0x290E),
                    dead=self.b(0x37E4), open=self.b(0x37F4))

    def log(self, message):
        s = self.state()
        self.events.append(dict(message=message, **s))
        print(message, json.dumps(s), flush=True)

    def step(self, keys=()):
        request = None if getattr(self, "listening", False) else self.dialogue_request()
        if request is not None:
            self.listen(request)
            self.last_key = ()
            return
        if "up" in keys and "down" not in keys:
            o, gx, gy, gz = self.pos()
            _, ax, ay, az = self.pos(1)
            dx, dy = DIRS[o]
            along = (ax - gx) * dx + (ay - gy) * dy
            across = (ax - gx) * dy - (ay - gy) * dx
            if self.floor(gz) == self.floor(az) and 0 < along <= 4 and abs(across) <= 1:
                keys = (*keys, "down")
        try:
            self.e.step(keys)
        except StopIteration:
            if hasattr(self.e, "refresh"):
                self.e.refresh()
            if self.b(0x37F4):
                raise Blocked("El motor pidió el final sin resolver la investigación")
            self.log("Victoria confirmada por el estado real del juego")
            if hasattr(self.e, "snapshot"):
                self.e.snapshot("victoria_100")
                self.e.status("victoria", investigation_open=0, percentage=100)
            raise
        self.last_key = tuple(keys)
        if self.b(0x37E4) and self.b(0x37F4):
            raise Blocked("Guillermo ha muerto: " + json.dumps(self.state()))

    def npc_in_speaking_range(self, who):
        """Same directional proximity box used by ai_guillermo_is_close."""
        _, gx, gy, gz = self.pos()
        o, x, y, z = self.pos(who)
        ox, sx, oy, sy = self.e.read(0x38EC + 4 * o, 4)
        return (self.floor(gz) == self.floor(z)
                and ((gx + ox - x) & 255) < sx
                and ((gy + oy - y) & 255) < sy)

    def dialogue_request(self):
        day, hour = self.b(0x28D1), self.b(0x28D2)
        if day >= 6 or self.b(0x384E) != 0xFF or not self.npc_in_speaking_range(5):
            return None
        if day == 4 and hour == 2:
            return "severino_esperad"
        if day == 5 and hour == 1 and (not self.b(0x37F1) or self.b(0x28F2)):
            return "severino_libro"
        if self.b(0x37F2) & 6 == 4 and self.b(0x28F2):
            return "severino_presentacion"
        return None

    def listen(self, request):
        """Suspend the travel goal, let the NPC speak, then resume that goal."""
        saved = getattr(self.e, "g_goal", None)
        self.listening = True
        self.e.clear_guillermo_goal()
        self.log("Nos detenemos para escuchar a Severino: " + request)
        try:
            def finished():
                if self.b(0x28F2):
                    return False
                if request == "severino_esperad":
                    return self.b(0x28D1) != 4 or self.b(0x28D2) != 2
                if request == "severino_libro":
                    return bool(self.b(0x37F1)) or self.b(0x28D2) != 1
                return not (self.b(0x37F2) & 6 == 4)
            self.until(finished, limit=3000)
            self.log("Conversación terminada; retomamos la meta")
        finally:
            self.listening = False
            if saved is not None:
                if saved[0] == "follow":
                    self.e.set_guillermo_goal(0, 0, 0, follow=saved[1])
                else:
                    self.e.set_guillermo_goal(*saved[:4])

    def wait(self, frames=1):
        for _ in range(frames):
            self.step()

    @staticmethod
    def floor(z):
        return 0 if z < 13 else 1 if z < 24 else 2

    def map(self, occupied=True, who=0):
        # Height lists retain their original CPC addresses in the rehearsal engine.
        ram = self.e.read(0, 65536)
        m = floor_map(ram, self.floor(self.pos(who)[3]))
        if occupied:
            for other in range(6):
                if other == who:
                    continue
                _, x, y, z = self.pos(other)
                if x and self.floor(z) == self.floor(self.pos(who)[3]):
                    for cx, cy in celdas(x, y):
                        m[cy & 255][cx & 255] = 31
        for x, y in self.bad:
            m[y][x] = 31
        return m

    def goto(self, x, y, orientation=None, limit=3000, tolerance=0, who=0, z=None, local=False, bounds=None):
        if hasattr(self.e, "plan") and who == 0 and not local:
            return self.goal(x, y, z=z, orientation=orientation, limit=limit, tolerance=tolerance)
        goal = (x, y)
        stagnant = 0
        previous = None
        path = []
        last_floor = None
        for _ in range(limit):
            o, gx, gy, gz = self.pos(who)
            if abs(gx - x) + abs(gy - y) <= tolerance:
                if orientation is None or o == orientation:
                    return
                if who:
                    # Adso faces the direction of his last actual step.
                    dx, dy = DIRS[orientation]
                    self.goto(x - dx, y - dy, who=who, limit=limit)
                    self.turn(orientation)
                    while self.pos(who)[1:3] != goal:
                        self.step(("down",))
                    return
                self.turn(orientation)
                return
            if previous == (gx, gy, gz):
                stagnant += 1
            else:
                stagnant = 0
            previous = (gx, gy, gz)
            if not who and self.secret_crossing(x):
                self.open_secret()
                path, stagnant = [], 0
            if stagnant >= 35:
                dx, dy = DIRS[o]
                self.bad.add((gx + dx, gy + dy))
                path = []
                stagnant = 0
            if not path or last_floor != self.floor(gz) or (gx, gy) not in path:
                r = route(self.map(who=who), (gx, gy), goal, ventana=bounds)
                if r is None:
                    # A moving monk can temporarily occupy the only passage.
                    self.wait(3)
                    r = route(self.map(False, who=who), (gx, gy), goal, ventana=bounds)
                if r is None:
                    raise Blocked(f"Sin ruta de {(gx, gy, gz)} a {goal}: {self.state()}")
                path, _ = r
                last_floor = self.floor(gz)
            index = path.index((gx, gy))
            if index + 1 == len(path):
                continue
            nx, ny = path[index + 1]
            wanted = next(d for d, delta in DIRS.items() if delta == (nx - gx, ny - gy))
            if self.pos()[0] != wanted:
                self.turn(wanted)
            else:
                self.step(("down",) if who else ("up",))
        raise Blocked(f"No se alcanza {goal}: {self.state()}")

    def goal(self, x, y, z=None, orientation=None, limit=3000, tolerance=0):
        if z is None:
            base = (0, 11, 22)[self.floor(self.pos()[3])]
            z = base + min(self.map(False)[y][x], 13)
        if hasattr(self.e, "set_guillermo_goal"):
            self.e.set_guillermo_goal(x, y, z, orientation or 0)
            try:
                still, last = 0, None
                for _ in range(limit):
                    o, gx, gy, gz = self.pos()
                    if (abs(x - gx) + abs(y - gy) <= tolerance and self.floor(gz) == self.floor(z)
                            and (orientation is None or o == orientation)):
                        return
                    current = (gx, gy, gz)
                    still = still + 1 if current == last else 0
                    last = current
                    if self.secret_crossing(x):
                        self.e.clear_guillermo_goal()
                        self.open_secret()
                        self.e.set_guillermo_goal(x, y, z, orientation or 0)
                        still = 0
                    if still > 80:
                        self.e.g_reset()
                    if still > 140:
                        raise Blocked(f"Meta de Guillermo bloqueada {(x, y, z)}: {self.state()}")
                    self.step()
                raise Blocked(f"Tiempo agotado para la meta {(x, y, z)}")
            finally:
                self.e.clear_guillermo_goal()
        still = 0
        last = None
        for _ in range(limit):
            o, gx, gy, gz = self.pos()
            if (abs(x - gx) + abs(y - gy) <= tolerance and self.floor(gz) == self.floor(z)):
                if orientation is not None:
                    self.turn(orientation)
                return
            current = (gx, gy, gz)
            still = still + 1 if current == last else 0
            last = current
            if self.secret_crossing(x):
                self.open_secret()
                still = 0
                self.e.navigation_cache = None
                continue
            if still > 100:
                raise Blocked(f"El piloto no puede llegar a {(x, y, z)}: {self.state()}")
            cmd = self.e.plan(x, y, z, orientation or 0)
            key = "left" if cmd == 3 else "right" if cmd == 2 else "up" if cmd is not None else None
            if key in ("left", "right") and self.last_key and key in self.last_key:
                self.step()
            else:
                self.step((key,) if key else ())

    def turn(self, wanted, keep=()):
        for _ in range(16):
            current = self.pos()[0]
            if current == wanted:
                return
            key = "left" if (wanted - current) % 4 in (1, 2) else "right"
            self.step((*keep, key))
            self.step(keep)
        raise Blocked("No puede girar")

    def follow(self, who, until, limit=5000):
        last_npc, still_npc = None, 0
        progress = None
        traza = os.environ.get("ABADIA_TRAZA_SEGUIR") == "1"     # (a line a step, and the heights around, to study)
        rastro = []                     # the abbot's places while he leads Guillermo, in order
        for iteration in range(limit):
            if traza:
                o, x, y, z = self.pos(who)
                go, gx, gy, gz = self.pos()
                print(f"SEG f={self.e.frame} who={who} npc=({o},{x},{y},{z}) G=({go},{gx},{gy},{gz}) estado={self.b(0x3814):02X} "
                      f"destino={self.b(0x3815):02X} obs={self.b(0x28D0)}", flush=True)
                if iteration == 0:
                    m = self.map()
                    print("MAPA x " + " ".join(f"{c:02d}"[-2:] for c in range(x - 12, x + 13)), flush=True)
                    for cy in range(y - 12, y + 25):
                        print(f"MAPA {cy:3d} " + " ".join(f"{m[cy & 255][c & 255]:2x}" for c in range(x - 12, x + 13)), flush=True)
            if iteration % 150 == 0:
                self.log("Seguimiento")
            if until():
                if hasattr(self.e, "clear_guillermo_goal"):
                    self.e.clear_guillermo_goal()
                return
            _, x, y, z = self.pos(who)
            _, gx, gy, gz = self.pos()
            npc = (x, y, z)
            if iteration % 120 == 119:
                if (progress is not None and abs(x - progress[0]) + abs(y - progress[1]) <= 3
                        and who == 3 and self.b(0x28D1) == 5 and self.b(0x28D2) == 4
                        and 0x3C <= x <= 0x5A and 0x50 <= y <= 0x6E):
                    self.log("Guillermo y Adso despejan la escalera para el abad")
                    self.e.clear_guillermo_goal()
                    self.goto(0x4E, 0x5D, z=0, local=True)
                progress = (x, y)
            still_npc = still_npc + 1 if last_npc == npc else 0
            last_npc = npc
            if who == 3 and self.b(0x28D1) == 5 and self.b(0x28D2) == 4 and self.floor(z) == self.floor(gz):
                # day 5, nona: the abbot leads Guillermo to his place 8 and takes 2 of obsequium each time Guillermo is
                # not in the box in front of him (ai_guillermo_is_close: from 6 places behind to 17 ahead, he walking
                # +y); the usual rules leave Guillermo 7 behind or beside him in the narrow way (the P500's rehearsal).
                # So Guillermo walks on the abbot's own trail, TRAS_ABAD of his places behind him, and stands still while
                # the abbot, offended (bit 7 of his state), comes back for him.
                if self.b(0x3814) & 0x80:
                    rastro.clear()
                    self.step()
                    continue
                if not rastro or rastro[-1] != (x, y):
                    rastro.append((x, y))
                if len(rastro) > TRAS_ABAD:
                    meta = rastro[-1 - TRAS_ABAD]
                    r = route(self.map(), (gx, gy), meta) if (gx, gy) != meta else None
                    if r and r[1]:
                        o = self.pos()[0]
                        if o != r[1][0]:                # a turn takes one frame (the game turns on the key's press;
                            key = "left" if (r[1][0] - o) % 4 in (1, 2) else "right"     # the next "up" releases it)
                            self.step(() if self.last_key and key in self.last_key else (key,))
                        else:
                            self.step(("up",))
                        continue
                    if (gx, gy) == meta:
                        self.step()
                        continue
                elif abs(gx - x) + abs(gy - y) <= 4:     # (he has not set off yet: wait near him, out of the way
                    self.step()                         #  rules that would move Guillermo aside or round him)
                    continue
            if still_npc > 25 and not self.b(0x28F2) and abs(gx - x) + abs(gy - y) <= 5:
                self.log("Dejamos paso al personaje que seguimos")
                o = self.pos(who)[0]
                offsets = ((0, 3), (0, -3)) if o in (0, 2) else ((3, 0), (-3, 0))
                for dx, dy in offsets:
                    if route(self.map(), (gx, gy), (gx + dx, gy + dy)):
                        self.goto(gx + dx, gy + dy, limit=80)
                        break
                still_npc = 0
                continue
            dx, dy = DIRS[self.pos(who)[0]]
            in_front = (gx - x) * dx + (gy - y) * dy > 0 and abs((gx - x) * dy - (gy - y) * dx) <= 2
            along = (gx - x) * dx + (gy - y) * dy
            across = (gx - x) * dy - (gy - y) * dx
            beside = (os.environ.get("ABADIA_FOLLOW_STYLE", "cardinal") == "flanks"
                      and 2 <= abs(across) <= 4 and abs(along) <= 4)
            if (beside or (abs(gx - x) + abs(gy - y) <= FOLLOW_RADIUS and not in_front)) and self.floor(z) == self.floor(gz):
                if hasattr(self.e, "clear_guillermo_goal"):
                    self.e.clear_guillermo_goal()
                self.wait(1)
                continue
            if hasattr(self.e, "set_guillermo_goal"):
                self.e.set_guillermo_goal(x, y, z, follow=who)
                self.step()
                if until():
                    self.e.clear_guillermo_goal()
                    return
                continue
            if hasattr(self.e, "plan"):
                cmd = self.e.plan(x, y, z, who=0, follow=who)
                key = "left" if cmd == 3 else "right" if cmd == 2 else "up" if cmd is not None else None
                if key in ("left", "right") and self.last_key and key in self.last_key:
                    self.step()
                else:
                    self.step((key,) if key else ())
                continue
            m = self.map()
            candidates = [(abs(cx - gx) + abs(cy - gy), cx, cy)
                          for dx, dy in ((3, 0), (-3, 0), (0, 3), (0, -3))
                          if 0 < (cx := x + dx) < 255 and 0 < (cy := y + dy) < 255]
            for _, cx, cy in sorted(candidates):
                r = route(m, (gx, gy), (cx, cy))
                if r and r[1]:
                    wanted = r[1][0]
                    if self.pos()[0] != wanted:
                        try:
                            self.turn(wanted)
                        except Blocked:                 # (the game lets him not turn there: a frame, and on)
                            self.step()
                    else:
                        self.step(("up",))
                    break
            else:
                self.wait(1)
        raise Blocked(f"Seguir al personaje {who}: {self.state()}")

    def tour(self):
        self.log("Comienzo del primer día")
        self.follow(3, lambda: self.b(0x28D2) != 4)
        self.log("Visita de bienvenida completa")
        self.goto(0x84, 0x4B, 1)
        self.log("En el puesto de misa")
        while self.b(0x28D2) == 5:
            self.wait()
        self.log("Misa completa")
        self.goto(0xA8, 0x1C)
        self.log("En nuestra celda")

    def until(self, condition, limit=10000, keys=()):
        for _ in range(limit):
            if condition():
                return
            self.step(keys)
        raise Blocked("Espera agotada: " + json.dumps(self.state()))

    def sleep(self):
        self.goto(0xA8, 0x1C)
        self.until(lambda: self.b(0x28D2) == 0)
        if self.b(0x28D1) in (3, 5, 6):
            self.until(lambda: self.b(0x385F) == 4)
            self.until(lambda: not self.b(0x28F2))
            self.step(("n",))
            self.step(("n",))
            if self.b(0x28D1) == 3:
                self.take(3)
                self.return_cell()
            elif self.b(0x28D1) == 5:
                self.take(4)
                self.goto(0xA8, 0x1C, z=2)
            elif self.b(0x28D1) == 6:
                self.take(5)
                self.take(2)
                self.goto(0x56, 0x2D, z=0)
                self.log("Esperamos el alba en el ala oeste, fuera de la ronda del abad")
                self.until(lambda: int.from_bytes(self.e.read(0x28D7, 2), "little") < 300)
                self.goto(0x60, 0x2A, z=0)
                self.goto(0x84, 0x4B, 1, local=True, bounds=(0x60, 1, 254, 254))
        self.until(lambda: self.b(0x28D2) == 1, keys=("s",))
        self.log("Amanece")

    def return_cell(self):
        self.goto(0x8E, 0x2A, z=2)
        self.goto(0x98, 0x33, local=True)
        self.goto(0xA5, 0x33, local=True)
        self.goto(0xA8, 0x1C, z=2)

    def ceremony(self, hour):
        if hour in (1, 5):
            self.goto(0x84, 0x4B, 1)
        elif hour == 3:
            self.follow(1, lambda: self.pos(1)[1:3] == (0x34, 0x39) or self.b(0x28D2) != hour)
            self.goto(0x38, 0x39, 1)
        self.until(lambda: self.b(0x28D2) != hour)
        self.log("Ceremonia completa")

    def announcement(self):
        self.follow(3, lambda: self.b(0x3814) == 0x10 and not self.b(0x28F2))
        self.log("Anuncio completo")

    def take(self, index, local=False):
        record = self.e.read(0x2B59 + 5 * index, 5)
        if record[0] & 0x80:
            return
        _, _, x, y, z = record
        _, gx, gy, _ = self.pos()
        base = (0, 11, 22)[self.floor(z)]
        m = floor_map(self.e.read(0, 65536), self.floor(z))
        options = []
        for o, (dx, dy) in DIRS.items():
            target = (x - 2 * dx, y - 2 * dy)
            tx, ty = target
            h = m[ty][tx]
            if h < 14 and square_ok(m, tx, ty, h) and 0 <= z - (base + h) <= 4:
                if any(ox and self.floor(oz) == self.floor(z) and celdas(tx, ty) & celdas(ox, oy)
                       for _, ox, oy, oz in (self.pos(who) for who in range(1, 6))):
                    continue
                if self.floor(z) == self.floor(self.pos()[3]) and not route(m, (gx, gy), target):
                    continue
                options.append((abs(tx - gx) + abs(ty - gy), target, o, base + h))
        if not options:
            raise Blocked(f"Objeto {index} inaccesible en {x:x},{y:x},{z:x}")
        _, (tx, ty), o, height = min(options, key=lambda option: (option[3], option[0]))
        self.goto(tx, ty, o, z=height, local=local)
        self.until(lambda: bool(self.b(0x2B59 + 5 * index) & 0x80), limit=30)
        self.log(f"Objeto {index} recogido")

    def stairs_up(self):
        self.bad.clear()
        if hasattr(self.e, "plan"):
            self.goto(0x2E, 0x3E, z=0x0D)
            self.log("Escalera: subida al scriptorium")
            return
        self.goto(0x1C, 0x6A)
        self.goto(0x1D, 0x6A)
        self.straight(1, y=0x65)
        self.log("Escalera: subida al scriptorium")

    def stairs_down(self):
        self.bad.clear()
        if hasattr(self.e, "plan"):
            self.goto(0x33, 0x69, z=2)
            self.log("Escalera: bajada")
            return
        self.goto(0x1D, 0x65)
        self.straight(3, y=0x6A)
        self.goto(0x1C, 0x6A)
        self.log("Escalera: bajada")

    def straight(self, orientation, x=None, y=None, who=0, limit=200):
        self.turn(orientation, ("down",) if who else ())
        for _ in range(limit):
            _, cx, cy, _ = self.pos(who)
            if (x is None or cx == x) and (y is None or cy == y):
                return
            self.step(("down",) if who else ("up",))
        raise Blocked(f"Tramo recto bloqueado hacia {x},{y}: {self.state()}")

    def key3(self):
        self.stairs_up()
        self.goto(0x2E, 0x3E)
        self.wait(30)
        self.goto(0x31, 0x3E, 0)
        self.wait(50)
        self.log("Malaquías desplazado para Adso")
        _, ax, ay, _ = self.pos(1)
        r = route(self.map(who=1), (ax, ay), (0x35, 0x38), ventana=(0x20, 0x20, 0x5F, 0x5F))
        if r is None:
            raise Blocked("Malaquías no ha dejado paso para Adso")
        cells, steps = r
        cursor = 0
        for o, n in segments(steps):
            cursor += n
            x, y = cells[cursor]
            self.straight(o, x=x if o in (0, 2) else None,
                          y=y if o in (1, 3) else None, who=1)
        self.straight(1, y=0x37, who=1)
        self.until(lambda: self.b(0x2947) & 2, limit=30)
        self.log("Adso tiene la llave de la biblioteca")
        self.stairs_down()

    def steer_adso(self, x, y, orientation=None):
        self.directing_adso = True
        base = (0, 11, 22)[self.floor(self.pos(1)[3])]
        height = base + min(self.map(False, who=1)[y][x], 13)
        self.e.adso_goal(x, y, height, orientation if orientation is not None else self.pos(1)[0])
        try:
            still, last = 0, None
            for tick in range(600):
                ao, ax, ay, az = self.pos(1)
                if (ax, ay) == (x, y) and (orientation is None or ao == orientation):
                    return
                current = (ax, ay, az)
                still = still + 1 if current == last else 0
                last = current
                if (still == 25 or tick % 120 == 119) and abs(ax - self.pos()[1]) + abs(ay - self.pos()[2]) > 7:
                    self.log("Guillermo se acerca para acompañar a Adso")
                    self.goto(ax + 2, ay + 2, z=az, tolerance=2)
                    still = 0
                # Held turn keys keep the game's camera on the team without
                # walking Guillermo into Adso's working space.
                self.step(("left", "right"))
            raise Blocked(f"Adso no alcanza {(x, y, orientation)}: {self.pos(1)}")
        finally:
            self.e.adso_release()
            self.directing_adso = False

    def lamp(self):
        self.goto(0x56, 0x2D, z=0)
        self.log("Guillermo espera a Adso en la cocina")
        self.steer_adso(0x58, 0x2A, 0)
        self.until(lambda: self.b(0x2944) & 128, limit=30)
        self.log("Adso recoge la lámpara")

    def steer_door(self, x, y):
        _, ax, ay, _ = self.pos(1)
        r = route(self.map(who=1), (ax, ay), (x, y))
        if not r:
            raise Blocked("Adso no puede aproximarse a la puerta")
        cells, steps = r
        cursor = 0
        for o, n in segments(steps):
            cursor += n
            tx, ty = cells[cursor]
            self.straight(o, x=tx if o in (0, 2) else None,
                          y=ty if o in (1, 3) else None, who=1)

    def secret_crossing(self, target_x):
        """Ask Adso before reaching his locked door, rather than after a failed entry."""
        _, x, y, z = self.pos()
        return (not getattr(self, "cooperating", False) and self.floor(z) == 0
                and self.b(0x28D2) == 0 and self.b(0x2947) & 2 and not self.b(0x2B4A) & 64
                and ((x < 0x7E) != (target_x < 0x7E))
                and abs(x - 0x7E) + abs(y - 0x26) <= 16)

    def open_secret(self):
        self.cooperating = True
        held = False
        try:
            self.log("Guillermo deja paso y pide a Adso abrir el pasadizo")
            if self.pos()[1] >= 0x7E:
                self.goto(0x82, 0x2B, z=2)
                self.steer_door(0x7D, 0x28)
            else:
                self.goto(0x7A, 0x2B, z=2)
                self.steer_door(0x80, 0x28)
            self.until(lambda: self.b(0x2B4A) & 64, limit=20)
            self.log("Adso abre el pasadizo con su llave")
            # The door closes again when its key holder walks away. Keep Adso
            # beside it until Guillermo has crossed, not merely until it opens.
            ao, ax, ay, az = self.pos(1)
            self.e.adso_goal(ax, ay, az, ao)
            held = True
            from_east = self.pos()[1] >= 0x7E
            self.goto(0x7F if from_east else 0x7E, 0x28, 2 if from_east else 0, z=2)
            self.e.adso_release()
            held = False
            # Now the normal two-person forward input lets Adso lead through
            # the narrow opening, rather than leaving him blocking the exit.
            self.goto(0x7A if from_east else 0x82, 0x2B, z=2)
        finally:
            if held:
                self.e.adso_release()
            self.cooperating = False

    def finish(self):
        self.until(lambda: self.b(0x385F) == 4)
        self.until(lambda: not self.b(0x28F2))
        self.step(("n",))
        self.step(("n",))
        self.lamp()
        numeral = self.b(0x290D)
        if numeral not in (1, 2, 3):
            raise Blocked("El manuscrito todavía no se ha leído")
        self.goto(0x1B, 0x25, z=0x18)
        self.goto(0x22, {1: 0x6D, 2: 0x69, 3: 0x65}[numeral], z=0x1A, local=True)
        self.log("Guillermo reconoce el peldaño indicado por el manuscrito")
        self.step(("q", "r"))
        self.until(lambda: not self.b(0x28DD), limit=10)
        self.log("Espejo abierto sin activar la trampa")
        self.goto(0x18, 0x65, z=0x18)
        self.until(lambda: self.b(0x384D) == 0x0C)
        self.take(0, local=True)
        self.until(lambda: self.b(0x384D) == 0x10)
        self.log("Jorge huye con el libro: lo seguimos")
        self.goto(0x1B, 0x25, z=0x18, local=True)
        self.until(lambda: not self.b(0x37F4))
        self.log("Investigación resuelta por las reglas del juego")
        self.until(lambda: False)

    def before_lunch(self, day):
        if day == 6:
            self.take(1)
        if day == 3:
            self.follow(3, lambda: self.b(0x28D2) != 2)
        else:
            self.goto(0x38, 0x39, 1)
            self.until(lambda: self.b(0x28D2) == 3)

    def afternoon(self, day):
        if day == 2:
            self.key3()
        if day == 3:
            self.lamp()
        if day == 4:
            self.until(lambda: self.b(0x295C) & 16 or self.b(0x2955) & 16 or self.b(0x37DD))
        if day == 5:
            self.steer_adso(0x34, 0x39, 1)
            self.e.adso_goal(0x34, 0x39, 2, 1)
            try:
                self.follow(3, lambda: self.b(0x28D2) == 5)
            finally:
                self.e.adso_release()
            self.take(3, local=True)
            self.goto(0x64, 0x36)
        else:
            self.log("Investigación terminada: nos adelantamos a la misa")
            self.goto(0x84, 0x4B, 1, z=2)
            self.until(lambda: self.b(0x28D2) == 5)

    def escort_abbot(self):
        """Walk beside the abbot, leaving his direction of travel unobstructed."""
        self.e.clear_guillermo_goal()
        for tick in range(6000):
            if self.b(0x28D2) == 5:
                return
            o, x, y, z = self.pos(3)
            go, gx, gy, gz = self.pos()
            dx, dy = DIRS[o]
            along = (gx - x) * dx + (gy - y) * dy
            across = (gx - x) * dy - (gy - y) * dx
            if 2 <= abs(across) <= 4 and abs(along) <= 2 and self.floor(gz) == self.floor(z):
                self.wait()
                continue
            if tick % 150 == 0:
                self.log("Acompañamos al abad sin cerrarle el paso")
            m = self.map()
            targets = set()
            for forward in (-2, 0, 2):
                for side in (-3, -2, 2, 3):
                    tx, ty = x + forward * dx + side * dy, y + forward * dy - side * dx
                    targets.add((tx, ty))
            queue, visited = deque([(gx, gy, None)]), {(gx, gy)}
            wanted = None
            while queue:
                cx, cy, first = queue.popleft()
                if first is not None and (cx, cy) in targets:
                    wanted = first
                    break
                for direction in (go, (go + 1) % 4, (go - 1) % 4, (go + 2) % 4):
                    sx, sy = DIRS[direction]
                    nx, ny = cx + sx, cy + sy
                    if not (1 <= nx < 255 and 1 <= ny < 255 and abs(nx - gx) <= 20 and abs(ny - gy) <= 20):
                        continue
                    if (nx, ny) not in visited and square_ok(m, nx, ny, m[cy][cx] & 15):
                        visited.add((nx, ny))
                        queue.append((nx, ny, direction if first is None else first))
            if wanted is None:
                # Adso may step aside in a narrow doorway using his own logic.
                self.step(("up", "down"))
                continue
            if go != wanted:
                self.turn(wanted)
            else:
                self.step(("up",))
        raise Blocked("El acompañamiento del abad no progresa")

    def last_night(self):
        self.goto(0xA8, 0x1C)
        self.until(lambda: self.b(0x28D2) == 0)
        self.log("Última noche")

    def phase(self, name, callback):
        if hasattr(self.e, "execute_phase"):
            self.e.execute_phase(name, callback, self)
        else:
            callback()

    def rehearsal(self, start_day=2, initial=True):
        if initial:
            self.phase("bienvenida", self.tour)
            self.phase("noche_1", self.sleep)
        for day in range(start_day, 7):
            self.phase(f"dia{day}_prima", lambda: self.ceremony(1))
            self.phase(f"dia{day}_anuncio", self.announcement)
            self.phase(f"dia{day}_tercia", lambda: self.before_lunch(day))
            self.phase(f"dia{day}_sexta", lambda: self.ceremony(3))
            self.phase(f"dia{day}_investigacion", lambda: self.afternoon(day))
            self.phase(f"dia{day}_visperas", lambda: self.ceremony(5))
            if day == 6:
                self.phase("ultima_noche", self.last_night)
                self.phase("espejo_y_jorge", self.finish)
                return
            self.phase(f"noche_{day}", self.sleep)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tour", action="store_true")
    parser.add_argument("--ensayo", action="store_true")
    parser.add_argument("--diagnostico", action="store_true")
    parser.add_argument("--numero-ensayo", type=int, choices=(1, 2, 3), default=1)
    args = parser.parse_args()
    engine = Pure(mirror_numeral=args.numero_ensayo)
    pilot = Pilot(engine)
    try:
        if args.diagnostico:
            state = (HERE / "ensayo_ram.bin").read_bytes()
            ctypes.memmove(engine.ram, state, 65536)
            print("Puertas", engine.read(0x2B35, 36).hex(), "Permisos", engine.read(0x292A, 6).hex())
            print("Adso", engine.read(CHARS[1], 15).hex(), "lámpara", engine.read(0x2B81, 5).hex())
            print("Plan Adso lámpara", engine.generate(88, 42, 0, 0, who=1))
            print("Plan Adso comedor", engine.generate(52, 57, 2, 1, who=1))
            print("Adso vars", engine.read(0x385E, 12).hex(), "no-route", engine.read(0x37E9).hex())
            for mask in (0x28, 0x38, 0x39, 0x3A, 0x3C, 0x3F):
                engine.diagnostic_mask = mask
                result = engine.generate(0x36, 0x5C, 15)
                print(f"Permiso {mask:02X}:", result.hex() if result else None)
        elif args.ensayo:
            pilot.rehearsal()
        elif args.tour:
            pilot.tour()
        else:
            pilot.log("Estado inicial")
            print("Abbot places", engine.read(0x3816, 33).hex())
            print("Adso places", engine.read(0x3861, 9).hex())
            print("Objects", engine.read(0x2B59, 45).hex())
            print("Hours", engine.read(0x4AD0, 49).hex())
    except StopIteration:
        pilot.log("VICTORIA: el juego carga su final")
        return 0
    except Blocked as exc:
        pilot.log("BLOQUEO: " + str(exc))
        return 2
    finally:
        if not args.diagnostico:
            (HERE / "ensayo_ram.bin").write_bytes(engine.read(0, 65536))
        (HERE / "ensayo.json").write_text(json.dumps(dict(events=pilot.events, inputs=engine.inputs), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
