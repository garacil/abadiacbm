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

"""The CPC 64K game's real speed, measured on the Caprice32 with its control socket
(/home/german/retro/amstrad/computer, doc/control_fifo.md): the game's state at its start (20BEh,
data/cpc64/inicio_juego: RAM and registers) as a .sna, run on Xvfb :99 with no keys, and a count of the
game's frames read with the emulator's frame counter (complete video frames, 50.08 Hz: 312 lines of 64 us).
Commands run at the top of an emulated frame, so each reading pairs an exact emulated time with the game's
progress: the host's speed does not matter.
The game has no frame counter of its own that runs from the start (28D7h, the hour's countdown, is 0 in the
first hour), so the main loop's first instruction after its head, LD A,(2B87h) at 217Ah, becomes CALL 01C0h:
LD A,(2B87h) / PUSH HL / LD HL,(01F0h) / INC HL / LD (01F0h),HL / POP HL / RET (the same A and flags; 01AAh-01FFh
is memory the game never touches: data/cpc64/accesos; 86 T-states more a frame, 0.02 %).

    cpc_velocidad.py OUTDIR [--hasta-frames N] [--fotos F1,F2,...]
        OUTDIR/inicio.sna, OUTDIR/medidas.tsv (emulated video frame, game frames), OUTDIR/cpc_<n>.png (screenshots
        at those game frames: the first reading at or past each), and the summary: game frames per second.
"""
import os, socket, struct, subprocess, sys, time

P = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
CAP = "/home/german/retro/amstrad/computer"
CUENTA = 0x01F0                                  # the frames counted by the patch
PARCHE = 0x01C0


def lee_estado(f):
    e = {}
    t = open(f).read().split()
    i = 0
    while i < len(t):
        k = t[i]
        if k in ("palette",):
            e[k] = [int(x) for x in t[i + 1:i + 18]]; i += 18
        elif k == "crtc":
            e[k] = [int(x) for x in t[i + 1:i + 17]]; i += 17
        else:
            e[k] = int(t[i + 1]); i += 2
    return e


def sna(ram, e, out):
    """a version 1 .sna (Caprice32's t_SNA_header, src/cap32.h): the registers of estado.txt, the ROMs off,
    the CRTC with the CPC's power-on values but the ones the loader wrote (R1, R2, R6: estado.txt), the inks of
    the loader, PPI and PSG at rest, 64 KiB of RAM"""
    h = bytearray(256)
    h[0:8] = b"MV - SNA"
    h[0x10] = 1
    par = lambda o, lo, hi: h.__setitem__(slice(o, o + 2), bytes([lo & 255, hi & 255]))
    par(0x11, e["F"], e["A"]); par(0x13, e["C"], e["B"]); par(0x15, e["E"], e["D"]); par(0x17, e["L"], e["H"])
    h[0x19] = e["R"]; h[0x1A] = e["I"]; h[0x1B] = h[0x1C] = e["IFF"]
    par(0x1D, e["IXl"], e["IXh"]); par(0x1F, e["IYl"], e["IYh"]); par(0x21, e["SP"], e["SP"] >> 8)
    par(0x23, e["PC"], e["PC"] >> 8); h[0x25] = e["IM"]
    par(0x26, e["F'"], e["A'"]); par(0x28, e["C'"], e["B'"]); par(0x2A, e["E'"], e["D'"]); par(0x2C, e["L'"], e["H'"])
    h[0x2E] = 0
    h[0x2F:0x2F + 17] = bytes(v & 0x1F for v in e["palette"])
    h[0x40] = 0x0C | (e["mode"] & 3)                 # both ROMs off, the screen mode
    h[0x41] = 0
    crtc = [63, 40, 46, 0x8E, 38, 0, 25, 30, 0, 7, 0, 0, 0x30, 0, 0, 0, 0, 0]
    for r in (1, 2, 6, 7, 9, 12, 13):
        crtc[r] = e["crtc"][r]
    h[0x42] = 0
    h[0x43:0x43 + 18] = bytes(crtc)
    h[0x55] = 0
    h[0x56], h[0x57], h[0x58], h[0x59] = 0, 0xFF, 0, 0x82
    h[0x5A] = 0
    psg = [0] * 16
    psg[7] = 0x3F
    h[0x5B:0x5B + 16] = bytes(psg)
    h[0x6B], h[0x6C] = 64, 0
    open(out, "wb").write(bytes(h) + ram)


class Cap:
    def __init__(self, sock, log):
        if os.path.exists(sock):
            os.unlink(sock)
        env = dict(os.environ, DISPLAY=":99")
        self.p = subprocess.Popen([os.path.join(CAP, "cap32"), "-c", os.path.join(CAP, "cap32.cfg"),
                                   "-O", "system.limit_speed=0", "-O", "system.model=2", "-O", "sound.enabled=0",
                                   f"--ctrl-socket={sock}"], cwd=CAP, env=env,
                                  stdout=open(log, "w"), stderr=subprocess.STDOUT)
        self.sock = sock
        for _ in range(600):                     # the emulator's start-up: its socket
            if os.path.exists(sock):
                break
            if self.p.poll() is not None:
                raise RuntimeError("cap32 ended at its start")
            time.sleep(0.05)
        else:
            raise RuntimeError("no control socket")

    def orden(self, linea):
        """sends the command lines and waits for each one's reply (OK/ERR ... '.' line: sent once the emulator
        has run it, at the top of a frame), then closes"""
        n = linea.count("\n") + 1
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(self.sock)
        s.sendall((linea + "\n").encode())
        r = b""
        while r.count(b"\n.\n") + (1 if r.startswith(b".\n") else 0) < n:
            t = s.recv(4096)
            if not t:
                break
            r += t
        s.close()
        r = r.decode(errors="replace")
        if "ERR" in r.split("\n")[0:1]:
            raise RuntimeError(f"cap32: {linea}: {r}")
        return r

    def espera_fichero(self, f):
        for _ in range(2000):
            if os.path.exists(f) and os.path.getsize(f) > 0:
                return open(f).read()
            time.sleep(0.01)
        raise RuntimeError(f"no {f}")

    def lectura(self, d, n):
        """the emulated frame and the word at 28D7h, from one command each at the same frame top: status and peek
        are queued together and run before the same frame (both are read from one batch)"""
        st, pk = os.path.join(d, f"st{n}.txt"), os.path.join(d, f"pk{n}.txt")
        for f in (st, pk):
            if os.path.exists(f):
                os.unlink(f)
        self.orden(f"status {st}\npeek {CUENTA} 2 {pk}")
        s = self.espera_fichero(st)
        p = self.espera_fichero(pk)
        frame = int(s.split("frame=")[1].split()[0])
        b = [int(x, 16) for x in p.replace(":", " ").split()[-2:]]
        return frame, b[0] | b[1] << 8

    def cierra(self):
        try:
            self.orden("quit")
            self.p.wait(timeout=10)
        except Exception:
            self.p.kill()


def main():
    out = sys.argv[1]
    hasta = 3000
    fotos = []
    a = sys.argv[2:]
    while a:
        if a[0] == "--hasta-frames":
            hasta = int(a[1]); a = a[2:]
        elif a[0] == "--fotos":
            fotos = [int(x) for x in a[1].split(",")]; a = a[2:]
        else:
            sys.exit(__doc__)
    os.makedirs(out, exist_ok=True)
    ram = bytearray(open(os.path.join(P, "data/cpc64/inicio_juego/ram.bin"), "rb").read())
    assert ram[0x217A:0x217D] == bytes([0x3A, 0x87, 0x2B])    # LD A,(2B87h)
    ram[0x217A:0x217D] = bytes([0xCD, PARCHE & 255, PARCHE >> 8])
    ram[PARCHE:PARCHE + 13] = bytes([0x3A, 0x87, 0x2B, 0xE5, 0x2A, CUENTA & 255, CUENTA >> 8, 0x23,
                                     0x22, CUENTA & 255, CUENTA >> 8, 0xE1, 0xC9])
    ram[CUENTA:CUENTA + 2] = b"\0\0"
    ram = bytes(ram)
    e = lee_estado(os.path.join(P, "data/cpc64/inicio_juego/estado.txt"))
    s = os.path.join(out, "inicio.sna")
    sna(ram, e, s)
    c = Cap(os.path.join(out, "cap32.sock"), os.path.join(out, "cap32.log"))
    try:
        c.orden(f"loadsnap {s}")
        c.orden("resume")
        medidas, n = [], 0
        pend = sorted(fotos)
        primera = None
        while True:
            f, v = c.lectura(out, n)
            n += 1
            medidas.append((f, v))
            if primera is None and v:
                primera = (f, v)                  # the first frame counted: the game is in its main loop
            if pend and v >= pend[0]:
                c.orden(f"screenshot {os.path.join(out, f'cpc_{pend[0]}.png')}")
                pend.pop(0)
            if primera and f - primera[0] >= hasta:
                break
        with open(os.path.join(out, "medidas.tsv"), "w") as o:
            o.write("emulated_video_frame\tgame_frames\n")
            for f, v in medidas:
                o.write(f"{f}\t{v}\n")
        f1, v1 = medidas[-1]
        seg = (f1 - primera[0]) * 19968e-6
        print(f"CPC: {v1 - primera[1]} game frames in {f1 - primera[0]} video frames ({seg:.2f} s): "
              f"{(v1 - primera[1]) / seg:.2f} game frames per second")
        for a_, b_ in ((1, 400), (1, 600), (1, 1000), (1, 2000)):   # game frames a_ to b_: the first readings past them
            fa = next((f for f, v in medidas if v >= a_), None)
            fb = next((f for f, v in medidas if v >= b_), None)
            if fa is not None and fb is not None:
                print(f"CPC: game frames {a_}-{b_} in {(fb - fa) * 19968e-6:.2f} s (+-0.02)")
    finally:
        c.cierra()


if __name__ == "__main__":
    main()
