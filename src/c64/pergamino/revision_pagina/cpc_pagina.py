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

"""The CPC's first page turn of the introduction parchment, captured on the Caprice32
(~/retro/amstrad/computer or ABADIA_CAPRICE, doc/control_fifo.md) through its control socket, on Xvfb :99.

The first stage as the tape leaves it (data/cpc64/cinta/primera_etapa.bin, entered by the loader's CALL 6000h at
0130h) becomes a .sna: PC = 6000h, SP = BFF8h with the return address 0133h, IM 1, interrupts
off, both ROMs off (the stage installs its own interrupt at 0038h and reads the keyboard itself), mode 1, the
CRTC at its power-on values (the stage writes R1, R2, R6).  No key is pressed: the text runs to its first page
turn (6756h: three delays of 65536 passes, then 65FDh, the turning corner).

Commands run at the top of an emulated frame (50.08 Hz), between frames; each reading pairs the emulated frame
with the CPU state at that frame top (regs: PC, SP, BC, and the stack), so the host's speed does not matter.

    cpc_pagina.py OUTDIR [--cada MS] [--pasos k1,k2,...]

1. a fast run (no speed limit) from the start until the CPU is inside 6756h's first delay, where OUTDIR/antes.sna
   is saved;
2. a run at the CPC's speed from antes.sna, read at every frame: OUTDIR/lecturas.tsv (frame, PC, SP, BC, the
   stack, where the CPU is), the page turn's start and end (the first frame at which 65FDh's return address 676Dh
   is on the stack, at the depth 6756h's CALL puts it, and the first at which it no longer is), the duration (each
   end within a frame: two readings a frame, at the frame's end and the emulator's cycle-count exit), a screenshot at the first frame
   at or past every MS milliseconds from the start (default 500; OUTDIR/cpc_t<ms>.png, ms from the start), and the
   screen memory at the end (OUTDIR/cpc_fin.bin);
3. with --pasos: a run from antes.sna where the corner's two delay calls (660Dh, 662Fh: CALL 672Ch, one per step
   of the corner, after the corner is drawn and before the borders are put back) call a stub at 9000h (memory
   the stage never uses) that counts steps and holds the CPU in a loop at step k until the tool lets it go:
   OUTDIR/cpc_paso<k>.png (the screen two frames later, unchanged meanwhile) and OUTDIR/cpc_paso<k>.bin (the
   16 KiB of screen memory).  Step 1 is the first corner (x = D3h, 3 bands); steps 46-91 are the second phase.
"""
import os, re, shutil, socket, subprocess, sys, tempfile, time

P = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))))   # the repository
sys.path.insert(0, os.path.join(P, "tools"))
from cpc_velocidad import sna, CAP                                     # noqa: E402

PILA = 0xBFF8
STUB = 0x9000
CUENTA, BANDERA = 0x9030, 0x9031


def imagen():
    ram = bytearray(open(os.path.join(P, "data/cpc64/cinta/primera_etapa.bin"), "rb").read())
    assert ram[0x6000:0x6003] == bytes([0xCD, 0x14, 0x61])            # CALL 6114h
    ram[PILA:PILA + 2] = bytes([0x33, 0x01])                            # the loader's return address 0133h
    e = {k: 0 for k in ("A", "B", "C", "D", "E", "H", "L", "IXh", "IXl", "IYh", "IYl", "I", "R",
                        "A'", "F'", "B'", "C'", "D'", "E'", "H'", "L'")}
    e.update({"F": 0x40, "SP": PILA, "PC": 0x6000, "IFF": 0, "IM": 1, "mode": 1,
              "palette": [0x14] * 17, "crtc": [63, 40, 46, 0x8E, 38, 0, 25, 30, 0, 7, 0, 0, 0x30, 0, 0, 0]})
    return ram, e


class Cap:
    def __init__(self, sock, log, rapido):
        """sock: ignored, the socket goes to a new short directory (a Unix socket path holds 108 bytes at most)"""
        self.dir_sock = tempfile.mkdtemp(prefix="cap32_")
        sock = os.path.join(self.dir_sock, "s")
        env = dict(os.environ, DISPLAY=":99")
        self.p = subprocess.Popen([os.path.join(CAP, "cap32"), "-c", os.path.join(CAP, "cap32.cfg"),
                                   "-O", f"system.limit_speed={0 if rapido else 1}", "-O", "system.model=2",
                                   "-O", "sound.enabled=0", "-O", "video.scr_fps=0", "-O", "video.scr_led=0",
                                   f"--ctrl-socket={sock}"], cwd=CAP, env=env,
                                  stdout=open(log, "w"), stderr=subprocess.STDOUT)
        self.sock = sock
        for _ in range(600):
            if os.path.exists(sock):
                break
            if self.p.poll() is not None:
                raise RuntimeError("cap32 ended at its start")
            time.sleep(0.05)
        else:
            self.p.kill()
            raise RuntimeError("no control socket")

    def orden(self, lineas):
        """sends the command lines (run together before the same frame) and returns each one's reply"""
        n = len(lineas)
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(self.sock)
        s.sendall(("\n".join(lineas) + "\n").encode())
        r = b""
        while r.count(b"\n.\n") + (1 if r.startswith(b".\n") else 0) < n:
            t = s.recv(1 << 16)
            if not t:
                break
            r += t
        s.close()
        partes = r.decode(errors="replace").split("\n.\n")[:n]
        for linea, p in zip(lineas, partes):
            if p.startswith("ERR"):
                raise RuntimeError(f"cap32: {linea}: {p}")
        return partes

    def cierra(self):
        try:
            self.orden(["quit"])
            self.p.wait(timeout=10)
        except Exception:
            self.p.kill()
        shutil.rmtree(self.dir_sock, ignore_errors=True)


def regs(t):
    v = dict(re.findall(r"([A-Z']+)=([0-9a-f]+)", t))
    return {k: int(x, 16) for k, x in v.items() if k != "frame"} | {"frame": int(t.split("frame=")[1].split()[0])}


def volcado(t):
    out = bytearray()
    for linea in t.strip().split("\n"):
        if ":" in linea and not linea.startswith("OK"):
            out += bytes(int(x, 16) for x in linea.split(":", 1)[1].split())
    return bytes(out)


def lectura(c):
    """the frame, the registers and the stack (BF00h-BFFFh) at one frame top"""
    r, p = c.orden(["regs", "peek 0xBF00 256"])
    e = regs(r)
    e["pila"] = volcado(p)
    return e


def palabra(e, d):
    o = d - 0xBF00
    return e["pila"][o] | e["pila"][o + 1] << 8


def main():
    out = os.path.realpath(sys.argv[1])
    cada, pasos = 500, []
    a = sys.argv[2:]
    while a:
        if a[0] == "--cada":
            cada = int(a[1]); a = a[2:]
        elif a[0] == "--pasos":
            pasos = sorted(int(x) for x in a[1].split(",")); a = a[2:]
        else:
            sys.exit(__doc__)
    os.makedirs(out, exist_ok=True)
    ram, e = imagen()
    s0 = os.path.join(out, "inicio.sna")
    sna(bytes(ram), e, s0)
    antes = os.path.join(out, "antes.sna")

    # 1. fast, to 6756h's first delay: 672Ch called from 6762h (return address 6765h on top of the stack)
    c = Cap(os.path.join(out, "cap32.sock"), os.path.join(out, "cap32_1.log"), True)
    try:
        c.orden([f"loadsnap {s0}", "resume"])
        while True:
            r = lectura(c)
            if 0x672C <= r["PC"] <= 0x6732 and palabra(r, r["SP"]) == 0x6765:
                c.orden(["pause"])
                r = lectura(c)
                assert 0x672C <= r["PC"] <= 0x6732 and palabra(r, r["SP"]) == 0x6765
                c.orden([f"snapshot {antes}"])
                print(f"antes.sna at frame {r['frame']}, PC {r['PC']:04X} BC {r['BC']:04X}")
                break
    finally:
        c.cierra()

    # 2. at the CPC's speed, a reading every frame
    c = Cap(os.path.join(out, "cap32.sock"), os.path.join(out, "cap32_2.log"), False)
    try:
        c.orden([f"loadsnap {antes}", "resume"])
        lect = []
        base = None            # the stack slot where 6756h's CALL 65FDh puts 676Dh
        ini = fin = None
        fotos = []
        while True:
            r = lectura(c)
            if base is None:
                # inside 6756h's delays: L - 2 holds 6756h's return address, L - 4 the BC it pushed, L - 6 = SP
                # 672Ch's (6765h); 6768h's PUSH IX takes L - 4 and CALL 65FDh puts 676Dh at L - 6
                base = r["SP"]
            dentro = r["SP"] <= base and palabra(r, base) == 0x676D
            r["dentro"] = dentro
            lect.append(r)
            if dentro and ini is None:
                ini = r["frame"]
            if ini is not None and not dentro and fin is None:
                fin = r["frame"]
            if ini is not None and (r["frame"] - ini) * 19.968 >= len(fotos) * cada and r["frame"] not in fotos and \
                    (fin is None or r["frame"] - fin < 50):
                ms = round((r["frame"] - ini) * 19968 / 1000)
                c.orden([f"screenshot {os.path.join(out, f'cpc_t{ms:05d}.png')}"])
                fotos.append(r["frame"])
            if fin is not None and r["frame"] - fin >= 50:
                break
            if fin is not None and r["frame"] == fin:
                open(os.path.join(out, "cpc_fin.bin"), "wb").write(volcado(c.orden(["peek 0xC000 16384"])[0]))
        saltos = [b["frame"] - a_["frame"] for a_, b in zip(lect, lect[1:])]
        with open(os.path.join(out, "lecturas.tsv"), "w") as o:
            o.write("frame\tPC\tSP\tBC\tHL\t[SP]\t[SP+2]\t[SP+4]\tinside_65FDh\n")
            for r in lect:
                pw = [palabra(r, r["SP"] + 2 * i) if r["SP"] + 2 * i < 0xBFFF else 0 for i in range(3)]
                o.write(f"{r['frame']}\t{r['PC']:04X}\t{r['SP']:04X}\t{r['BC']:04X}\t{r['HL']:04X}\t"
                        f"{pw[0]:04X}\t{pw[1]:04X}\t{pw[2]:04X}\t{int(r['dentro'])}\n")
        dur = (fin - ini) * 19968e-6
        print(f"page turn (65FDh): first frame inside {ini}, first frame after {fin}: {fin - ini} frames, "
              f"{dur:.3f} s (each end +-1 frame: the reading is at the frame top); readings every "
              f"{min(saltos)}-{max(saltos)} frames")
        with open(os.path.join(out, "duracion.txt"), "w") as o:
            o.write(f"first_frame_inside {ini}\nfirst_frame_after {fin}\nframes {fin - ini}\nseconds {dur:.3f}\n"
                    f"frame_step_min {min(saltos)}\nframe_step_max {max(saltos)}\nantes_frame {lect[0]['frame']}\n")
    finally:
        c.cierra()

    # 3. the corner's steps, held
    if pasos:
        c = Cap(os.path.join(out, "cap32.sock"), os.path.join(out, "cap32_3.log"), True)
        stub = bytes([0xF5, 0x3A, CUENTA & 255, CUENTA >> 8, 0x3D, 0x32, CUENTA & 255, CUENTA >> 8, 0x20, 0x09,
                      0x32, BANDERA & 255, BANDERA >> 8, 0x3A, BANDERA & 255, BANDERA >> 8, 0xB7, 0x28, 0xFA,
                      0xF1, 0xC3, 0x2C, 0x67])
        try:
            c.orden(["pause", f"loadsnap {antes}"])
            ver = volcado(c.orden(["peek 0x660D 3"])[0]) + volcado(c.orden(["peek 0x662F 3"])[0])
            assert ver == bytes([0xCD, 0x2C, 0x67] * 2), ver.hex()
            hecho = 0
            c.orden([f"poke 0x{STUB:04X} {stub.hex()}", f"poke 0x{CUENTA:04X} {pasos[0]:02x}",
                     f"poke 0x{BANDERA:04X} 01", "poke 0x660E 00 90", "poke 0x6630 00 90", "resume"])
            for k in pasos:
                while True:
                    b = volcado(c.orden([f"peek 0x{BANDERA:04X} 1"])[0])[0]
                    if b == 0:
                        break
                f0 = lectura(c)["frame"]
                while lectura(c)["frame"] < f0 + 2:
                    pass
                pant = volcado(c.orden(["peek 0xC000 16384"])[0])
                c.orden([f"screenshot {os.path.join(out, f'cpc_paso{k:02d}.png')}"])
                assert volcado(c.orden(["peek 0xC000 16384"])[0]) == pant
                open(os.path.join(out, f"cpc_paso{k:02d}.bin"), "wb").write(pant)
                hecho = k
                sig = next((x for x in pasos if x > k), None)
                if sig is None:
                    break
                c.orden([f"poke 0x{CUENTA:04X} {sig - hecho:02x}", f"poke 0x{BANDERA:04X} 01"])
            print(f"steps held: {pasos}")
        finally:
            c.cierra()


if __name__ == "__main__":
    main()
