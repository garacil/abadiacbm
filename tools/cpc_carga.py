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

"""Run the loader of an Amstrad CPC program on a Z80 simulator (SkoolKit) with the firmware calls
emulated, and dump the 64 KiB of RAM it leaves.  Deterministic: no clock, no real hardware.

    cpc_carga.py DISK.dsk BASFILE --call ADDR [--stop ADDR] [--max N] --out DIR
    cpc_carga.py DISK.dsk --imagen RAM.bin --call ADDR [--ret ADDR] ... --out DIR

The BASIC file is placed at its header load address and CALL ADDR is simulated (what its single line
does); with --imagen the run starts instead from a 64 KiB memory image (a ram.bin of an earlier run)
at ADDR, and the disk's files are still served (e.g. the ending loaded by the game).  --ret ADDR
makes a call to ADDR return at once (a set-up routine copied into RAM that would enter the ROM).  Every firmware call (PC in BB00-BDFF) is logged and served here: the cassette/AMSDOS file
calls read from the disk image, screen/ink/keyboard calls only log.  HALT is skipped (an interrupt
arrives).  OUT writes are logged.  The run stops at --stop, at the first PC outside every page the
loader has used once a page in 0000-00FF is jumped to, or after --max instructions.
Outputs: DIR/ram.bin (64 KiB), DIR/registros.txt, DIR/traza.log (firmware calls, OUTs, new pages).
"""
import argparse, os, struct, sys, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsk
from z80sim import Simulator
from skoolkit.simutils import A, F, B, C, D, E, H, L, SP, PC, T, IFF

NAMES = {0xBB06: "KM WAIT CHAR", 0xBB09: "KM READ CHAR", 0xBB18: "KM WAIT KEY", 0xBB1B: "KM READ KEY",
         0xBC0E: "SCR SET MODE", 0xBC32: "SCR SET INK", 0xBC38: "SCR SET BORDER", 0xBC6B: "CAS NOISY",
         0xBC77: "CAS IN OPEN", 0xBC7A: "CAS IN CLOSE", 0xBC7D: "CAS IN ABANDON", 0xBC83: "CAS IN DIRECT",
         0xBC8C: "CAS OUT OPEN", 0xBC8F: "CAS OUT CLOSE", 0xBC98: "CAS OUT DIRECT", 0xBD19: "MC WAIT FLYBACK",
         0xBCA7: "SOUND RESET", 0xBB00: "KM INITIALISE", 0xBB4E: "TXT INITIALISE", 0xBBFF: "SCR INITIALISE"}


class Machine:
    def __init__(self, files, log):
        self.files = {f"{n}.{e}".upper(): d for u, n, e, d in files}
        self.log = log
        self.mem = bytearray(65536)
        self.sim = Simulator(self.mem)
        self.sim.set_tracer(self)
        self.open = None
        self.header = 0xA000          # where CAS IN OPEN leaves the header copy
        self.psg_data = self.psg_reg = self.row = 0
        self.keys = {}                # keyboard matrix row -> pressed bits
        self.tr_from = self.tr_to = 0
        self.pen, self.mode, self.palette = 0, 1, [0x14] * 17
        self.crtc_sel, self.crtc = 0, [0] * 32
        self.crtc[12], self.crtc[13] = 0x30, 0
        self.crtc[1], self.crtc[6], self.crtc[9] = 40, 25, 7
        self.log_ports = True
        self.ints = False                                  # deliver the 300 Hz interrupt
        self.script = []                                   # (frame, row, bit, frames held)
        self.photos = set()
        self.coverage = set()
        self.outdir = "."
        self.marks = set()
        self.rets = set()              # --ret: calls that return at once
        self.ay_log = None
        self.hashes = None             # --hashes: FNV-1a 64 of the RAM at each main-loop iteration
        self.hasta_frame = 1 << 30
        self.calls = None              # (caller, target) -> times, with --llamadas
        self.sinc = None               # synchronous mode: back-jump address -> (head, kind, us)
        self.clock = 0; self.next_tick = 3328; self.pending = 0; self.sync_ticks = 0
        self.sinc_activo = False; self.sinc_desde = 0x20BE; self.bucle_principal = 0x2179

    # --- ports ---------------------------------------------------------------------------------
    def read_port(self, registers, port, *rest):
        if port >> 8 == 0xF4 and self.psg_reg == 14:       # keyboard row through the PSG port A
            row = self.row & 0x0F
            held = self.keys.get(row, 0)
            for f, r, b, d in self.script:
                if r == row and f <= self.frame < f + d:
                    held |= 1 << b
            return 0xFF & ~held
        return 0xFF

    def write_port(self, registers, port, value, *rest):
        hi = port >> 8
        if hi == 0xF4:
            self.psg_data = value
        elif hi == 0xF6:
            self.row = value
            if value & 0xC0 == 0xC0:                       # latch the PSG register number
                self.psg_reg = self.psg_data
            elif value & 0xC0 == 0x80 and self.psg_reg < 16:   # write the PSG register
                if self.ay_log is not None:
                    self.ay_log.write(f"{registers[25]} {self.psg_reg} {self.psg_data}\n")
        elif hi & 0xC0 == 0x40:                            # gate array (7Fxx)
            if value & 0xC0 == 0x00:
                self.pen = value & 0x1F
            elif value & 0xC0 == 0x40:
                self.palette[min(self.pen, 16)] = value & 0x1F
            elif value & 0xE0 == 0x80:
                self.mode = value & 3
            self.log_out(port, value)
        elif hi == 0xBC:
            self.crtc_sel = value & 0x1F
        elif hi == 0xBD:
            self.crtc[self.crtc_sel] = value
            if self.log_ports:
                self.log.write(f"CRTC R{self.crtc_sel}={value:02X}\n")
        else:
            self.log_out(port, value)

    def log_out(self, port, value):
        if self.log_ports:
            self.log.write(f"OUT {port:04X},{value:02X}\n")

    # --- firmware ------------------------------------------------------------------------------
    def ret(self, carry=None, zero=None):
        r, m = self.sim.registers, self.mem
        if carry is not None:
            r[F] = (r[F] & ~1) | (1 if carry else 0)
        if zero is not None:
            r[F] = (r[F] & ~0x40) | (0x40 if zero else 0)
        r[PC] = m[r[SP]] | m[(r[SP] + 1) & 0xFFFF] << 8
        r[SP] = (r[SP] + 2) & 0xFFFF

    def firmware(self, pc):
        r, m = self.sim.registers, self.mem
        hl, de, bc = r[H] << 8 | r[L], r[D] << 8 | r[E], r[B] << 8 | r[C]
        name = NAMES.get(pc, "?")
        extra = ""
        if pc == 0xBC77:                                   # CAS IN OPEN: HL name, B length
            fn = bytes(m[(hl + i) & 0xFFFF] for i in range(r[B])).decode("latin1").strip().upper()
            fn = fn if "." in fn else fn + "."
            key = next((k for k in self.files if k == fn or k.rstrip(".") == fn.rstrip(".")), None)
            extra = f'"{fn}" -> {key}'
            if key is None:
                self.log.write(f"FW {pc:04X} {name} {extra}\n")
                return self.ret(carry=False, zero=False)
            data = self.files[key]
            hdr = data[:128]
            typ = hdr[18]
            load, ln, ent = struct.unpack_from("<H", hdr, 21)[0], struct.unpack_from("<H", hdr, 24)[0], struct.unpack_from("<H", hdr, 26)[0]
            self.open = data[128:128 + ln]
            for i in range(64):
                m[self.header + i] = hdr[i]
            r[H], r[L] = self.header >> 8, self.header & 0xFF
            r[D], r[E] = load >> 8, load & 0xFF
            r[B], r[C] = ln >> 8, ln & 0xFF
            r[A] = typ
            extra += f" load {load:04X} len {ln:04X} entry {ent:04X}"
            self.log.write(f"FW {pc:04X} {name} {extra}\n")
            return self.ret(carry=True, zero=False)
        if pc == 0xBC83:                                   # CAS IN DIRECT: HL destination
            for i, b in enumerate(self.open):
                m[(hl + i) & 0xFFFF] = b
            self.log.write(f"FW {pc:04X} {name} -> {hl:04X}..{hl + len(self.open) - 1:04X}\n")
            return self.ret(carry=True, zero=False)
        if pc in (0xBC7A, 0xBC7D):
            self.open = None
            self.log.write(f"FW {pc:04X} {name}\n")
            return self.ret(carry=True, zero=False)
        if pc in (0xBC32, 0xBC38):                         # SCR SET INK / BORDER: A pen, B first colour
            fw2hw = [0x54, 0x44, 0x55, 0x5C, 0x58, 0x5D, 0x4C, 0x45, 0x4D, 0x56, 0x46, 0x57, 0x5E, 0x40,
                     0x5F, 0x4E, 0x47, 0x4F, 0x52, 0x42, 0x53, 0x5A, 0x59, 0x5B, 0x4A, 0x43, 0x4B]
            pen = 16 if pc == 0xBC38 else r[A] & 15
            self.palette[pen] = fw2hw[(r[B] & 0x1F) % 27] & 0x1F
            self.log.write(f"FW {pc:04X} {name} pen {pen} colour {r[B]}\n")
            return self.ret(carry=True)
        if pc == 0xBC0E:                                   # SCR SET MODE
            self.mode = r[A] & 3
            self.log.write(f"FW {pc:04X} {name} {r[A]}\n")
            return self.ret(carry=True)
        if pc == 0xBB09:                                   # KM READ CHAR: nothing pressed
            self.log.write(f"FW {pc:04X} {name}\n")
            return self.ret(carry=False)
        if pc in (0xBB06, 0xBB18):                         # KM WAIT CHAR/KEY: a space
            r[A] = 0x20
            self.log.write(f"FW {pc:04X} {name} -> 20\n")
            return self.ret(carry=True)
        self.log.write(f"FW {pc:04X} {name} A={r[A]:02X} BC={bc:04X} DE={de:04X} HL={hl:04X}\n")
        return self.ret(carry=True)

    # 27 hardware colours of the CPC, by hardware number (0x00-0x1F)
    HW = [(128,128,128),(128,128,128),(0,255,128),(255,255,128),(0,0,128),(255,0,128),(0,128,128),(255,128,128),
          (255,0,128),(255,255,128),(255,255,0),(255,255,255),(255,0,0),(255,0,255),(255,128,0),(255,128,255),
          (0,0,128),(0,255,128),(0,255,0),(0,255,255),(0,0,0),(0,0,255),(0,128,0),(0,128,255),
          (128,0,128),(128,255,128),(128,255,0),(128,255,255),(128,0,0),(128,0,255),(128,128,0),(128,128,255)]

    def screenshot(self, path):
        """The visible screen (CRTC base, 80 bytes a line, 200 lines) in the current mode, 2x1 pixels in mode 1."""
        m = self.mem
        base = ((self.crtc[12] & 0x30) << 10) | ((self.crtc[12] & 3) << 9) | (self.crtc[13] << 1)
        bpl, nrows, sl = 2 * max(1, self.crtc[1]), max(1, self.crtc[6]), (self.crtc[9] & 7) + 1
        W, H = bpl * 8, nrows * sl
        rows = []
        for y in range(H):
            line = bytearray()
            for xb in range(bpl):
                off = ((base & 0x7FF) + (y // sl) * bpl + xb) & 0x7FF
                b = m[(base & 0xC000) | ((y % sl) << 11) | off]
                if self.mode == 1:
                    pix = [((b >> (7 - i)) & 1) | (((b >> (3 - i)) & 1) << 1) for i in range(4)]
                    w = 2
                elif self.mode == 0:
                    def p0(b, s):
                        return ((b >> (7 - s)) & 1) | (((b >> (3 - s)) & 1) << 1) | (((b >> (5 - s)) & 1) << 2) | (((b >> (1 - s)) & 1) << 3)   # mode 0: bits 7 3 5 1 = pen bits 0 1 2 3
                    pix = [p0(b, 0), p0(b, 1)]
                    w = 4
                else:
                    pix = [(b >> (7 - i)) & 1 for i in range(8)]
                    w = 1
                for c in pix:
                    line += bytes(self.HW[self.palette[c] & 0x1F]) * w
            rows.append(b"\0" + bytes(line))
        raw = zlib.compress(b"".join(rows), 9)
        def chunk(t, d):
            return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")
        open(path, "wb").write(png)

    def run(self, start, stop, maxn):
        r, m = self.sim.registers, self.mem
        r[PC] = start
        pages = set()
        n = 0
        self.frame = 0
        next_int = 13312
        ints = 0
        while n < maxn:
            if self.sinc is not None and not self.sinc_activo and r[PC] == self.sinc_desde:
                self.sinc_activo = True                # the game starts: from here on, synchronous
                self.log.write(f"SYNC from {r[PC]:04X} at instruction {n}\n")
            if self.sinc_activo:                       # synchronous mode: interrupts only at wait points;
                if r[PC] == self.bucle_principal:      # a "frame" is one main-loop iteration
                    self.frame += 1
                    if self.hashes is not None:
                        h = 0xcbf29ce484222325
                        for b in m:
                            h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
                        self.hashes.write(f"{self.frame}\t{h:016x}\n")
                    if self.frame >= self.hasta_frame:
                        self.log.write(f"STOP at frame {self.frame}\n")
                        return n
                    if self.frame in self.photos:
                        self.screenshot(os.path.join(self.outdir, f"f{self.frame:06d}.png"))
            elif self.ints and r[T] >= next_int:
                next_int += 13312
                ints += 1
                if ints % 6 == 0:
                    self.frame += 1
                    if self.frame in self.photos:
                        self.screenshot(os.path.join(self.outdir, f"f{self.frame:06d}.png"))
                if r[IFF]:
                    self.sim.accept_interrupt(r, m, (r[PC] - 1) & 0xFFFF)
            pc = r[PC]
            self.coverage.add(pc)
            if pc in self.marks:
                self.log.write(f"M {pc:04X} T={r[T]} BC={r[B]:02X}{r[C]:02X} HL={r[H]:02X}{r[L]:02X}\n")
            if pc == stop:
                self.log.write(f"STOP at {pc:04X} after {n} instructions\n")
                return n
            if 0xBB00 <= pc <= 0xBDFF:
                self.firmware(pc)
                continue
            if pc in self.rets:
                self.log.write(f"RET {pc:04X}\n")
                self.ret()
                continue
            if m[pc] == 0x76:                              # HALT: wait for the next interrupt
                r[PC] = (pc + 1) & 0xFFFF                  # (the interrupt returns after the HALT)
                if self.sinc_activo and r[IFF]:
                    self.clock = self.next_tick; self.next_tick += 3328
                    self.sync_ticks += 1
                    self.sim.accept_interrupt(r, m, pc)
                elif self.ints and r[IFF]:
                    r[T] = max(r[T], next_int)
                continue
            if self.calls is not None:
                op = m[pc]
                sp0 = r[SP]
            if self.tr_from <= n < self.tr_to:
                self.log.write(f"T {n} {pc:04X} {m[pc]:02X}{m[(pc+1)&0xFFFF]:02X}{m[(pc+2)&0xFFFF]:02X}{m[(pc+3)&0xFFFF]:02X} A={r[A]:02X} BC={r[B]:02X}{r[C]:02X} DE={r[D]:02X}{r[E]:02X} HL={r[H]:02X}{r[L]:02X} SP={r[SP]:04X}\n")
            if pc >> 8 not in pages:
                pages.add(pc >> 8)
                self.log.write(f"PAGE {pc:04X} (instr {n}) SP={r[SP]:04X}\n")
            self.sim.run()
            n += 1
            if self.sinc_activo and pc in self.sinc and r[PC] == self.sinc[pc][0]:
                kind, head, us = self.sinc[pc][1], self.sinc[pc][0], self.sinc[pc][2]
                self.clock += 3328 if kind in ("espera", "pausa") else us
                while self.clock >= self.next_tick:
                    self.next_tick += 3328
                    self.pending += 1
                if self.pending and r[IFF]:
                    self.pending -= 1
                    self.sync_ticks += 1
                    self.sim.accept_interrupt(r, m, (r[PC] - 1) & 0xFFFF)
                if kind == "pausa":                    # a pass of a wait outside the main loop: a frame
                    self.frame += 1
                    if self.hashes is not None:
                        h = 0xcbf29ce484222325
                        for b in m:
                            h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
                        self.hashes.write(f"{self.frame}\t{h:016x}\n")
                    if self.frame >= self.hasta_frame:
                        self.log.write(f"STOP at frame {self.frame}\n")
                        return n
            if self.calls is not None:
                # a CALL or RST that was taken: SP went down by 2 and the return address is the next instruction
                if (op in (0xCD, 0xC4, 0xCC, 0xD4, 0xDC, 0xE4, 0xEC, 0xF4, 0xFC) and r[SP] == (sp0 - 2) & 0xFFFF
                        and (m[r[SP]] | m[(r[SP] + 1) & 0xFFFF] << 8) == (pc + 3) & 0xFFFF):
                    self.calls[(pc, r[PC])] += 1
                elif op & 0xC7 == 0xC7 and r[SP] == (sp0 - 2) & 0xFFFF:
                    self.calls[(pc, r[PC])] += 1
        self.log.write(f"MAX reached at {r[PC]:04X}\n")
        return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("disk"); ap.add_argument("bas", nargs="?")
    ap.add_argument("--imagen", default=None, help="start from this 64 KiB memory image instead of the BASIC file")
    ap.add_argument("--ret", action="append", default=[], help="a call to ADDR returns at once (hex)")
    ap.add_argument("--sp", type=lambda s: int(s, 16), default=None, help="SP at the start, nothing pushed (hex; default BFF8h with a return address)")
    ap.add_argument("--call", type=lambda s: int(s, 16), required=True)
    ap.add_argument("--stop", type=lambda s: int(s, 16), default=-1)
    ap.add_argument("--max", type=int, default=50_000_000)
    ap.add_argument("--poke", action="append", default=[], help="ADDR=BYTE before running (hex)")
    ap.add_argument("--tecla", action="append", default=[], help="ROW:BIT held down (e.g. 5:7 space)")
    ap.add_argument("--traza", default="0:0", help="FROM:TO instruction numbers to log one by one")
    ap.add_argument("--int", action="store_true", help="deliver the 300 Hz interrupt (IM 1)")
    ap.add_argument("--marca", action="append", default=[], help="log T-states each time PC reaches ADDR (hex)")
    ap.add_argument("--ay", default=None, help="write every PSG register write as 'T REG VALUE' to this file")
    ap.add_argument("--llamadas", action="store_true", help="record taken CALL/RST (caller, target) in llamadas.tsv")
    ap.add_argument("--hasta-frame", type=int, default=1 << 30, help="synchronous mode: stop at this main-loop iteration")
    ap.add_argument("--hashes", default=None, help="synchronous mode: write 'frame FNV-1a-64-of-RAM' at each main-loop iteration")
    ap.add_argument("--sincrono", default=None, help="wait-point file: from the game's start (20BEh) interrupts only at those points (see sincrono/puntos64.txt)")
    ap.add_argument("--guion", default=None, help="key script: lines 'FRAME ROW:BIT [FRAMES]'")
    ap.add_argument("--fotos", default="", help="frames to screenshot: a,b,c or a-b/step")
    ap.add_argument("--sin-puertos", action="store_true", help="do not log OUTs")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    img = open(a.disk, "rb").read()
    fmt, files = dsk.amsdos(dsk.tracks(img))
    log = open(os.path.join(a.out, "traza.log"), "w")
    mc = Machine(files, log)
    if a.imagen:
        mc.mem[:] = open(a.imagen, "rb").read()
    else:
        bas = next(d for u, n, e, d in files if f"{n}.{e}".upper() == a.bas.upper())
        load, ln = struct.unpack_from("<H", bas, 21)[0], struct.unpack_from("<H", bas, 24)[0]
        mc.mem[load:load + ln] = bas[128:128 + ln]
    mc.rets = {int(x, 16) for x in a.ret}
    mc.mem[0xBC77] = 0xDF                                  # AMSDOS has patched the cassette calls
    mc.mem[0xBD3D] = 0xCF                                  # 664/6128 jumpblock entry
    mc.mem[0x0038:0x003B] = bytes([0xC3, 0x00, 0xB9])      # RST 38 -> the firmware interrupt handler
    mc.mem[0xB900:0xB902] = bytes([0xFB, 0xC9])            # which here only re-enables interrupts
    for p in a.poke:
        k, v = p.split("="); mc.mem[int(k, 16)] = int(v, 16)
    mc.tr_from, mc.tr_to = map(int, a.traza.split(":"))
    mc.ints, mc.outdir, mc.log_ports = a.int, a.out, not a.sin_puertos
    mc.marks = {int(x, 16) for x in a.marca}
    if a.ay:
        mc.ay_log = open(a.ay, "w")
    if a.sincrono:
        mc.sinc = {}
        for line in open(a.sincrono):
            t = line.split("#")[0].split()
            if t:
                mc.sinc[int(t[2], 16)] = (int(t[1], 16), t[0], int(t[3]) if len(t) > 3 else 0)
    mc.hasta_frame = a.hasta_frame
    if a.hashes:
        mc.hashes = open(a.hashes, "w")
    if a.llamadas:
        import collections
        mc.calls = collections.Counter()
    if a.guion:
        for line in open(a.guion):
            t = line.split("#")[0].split()
            if t:
                row, bit = map(int, t[1].split(":"))
                mc.script.append((int(t[0]), row, bit, int(t[2]) if len(t) > 2 else 15))
    for part in filter(None, a.fotos.split(",")):
        if "-" in part:
            rng, _, step = part.partition("/")
            lo, hi = map(int, rng.split("-"))
            mc.photos.update(range(lo, hi + 1, int(step or 1)))
        else:
            mc.photos.add(int(part))
    for k in a.tecla:
        row, bit = map(int, k.split(":")); mc.keys[row] = mc.keys.get(row, 0) | 1 << bit
    r = mc.sim.registers
    if a.sp is not None:
        r[SP] = a.sp                                       # as a loader leaves it before its JP
    else:
        r[SP] = 0xBFF8
        mc.mem[0xBFF8], mc.mem[0xBFF9] = 0xFE, 0xBD        # return of CALL: a firmware address, logged
    n = mc.run(a.call, a.stop, a.max)
    if mc.ay_log is not None:
        mc.ay_log.close()
    if mc.hashes is not None:
        mc.hashes.close()
    if mc.calls is not None:
        with open(os.path.join(a.out, "llamadas.tsv"), "w") as f:
            f.write("caller\ttarget\ttimes\n")
            for (c, t), k in sorted(mc.calls.items(), key=lambda x: (x[0][1], x[0][0])):
                f.write(f"{c:04X}\t{t:04X}\t{k}\n")
    log.close()
    open(os.path.join(a.out, "ram.bin"), "wb").write(mc.mem)
    # the whole register state, for the C host (src/juego/) to start from the same point
    nombres = ["A", "F", "B", "C", "D", "E", "H", "L", "IXh", "IXl", "IYh", "IYl", "SP", "SP2", "I", "R",
               "A'", "F'", "B'", "C'", "D'", "E'", "H'", "L'", "PC", "T", "IFF", "IM", "HALT", "MEMPTR"]
    with open(os.path.join(a.out, "estado.txt"), "w") as f:
        for i, nm in enumerate(nombres):
            f.write(f"{nm} {r[i]}\n")
        f.write(f"mode {mc.mode}\npalette {' '.join(str(c) for c in mc.palette)}\n")
        f.write(f"crtc {' '.join(str(c) for c in mc.crtc[:16])}\nframe {mc.frame}\n")
    open(os.path.join(a.out, "cobertura.txt"), "w").write("".join(f"{p:04X}\n" for p in sorted(mc.coverage)))
    mc.screenshot(os.path.join(a.out, "final.png"))
    print("sync ticks", mc.sync_ticks, "frame", mc.frame)
    print("mode", mc.mode, "palette", " ".join(f"{c:02X}" for c in mc.palette), "crtc12/13", f"{mc.crtc[12]:02X}{mc.crtc[13]:02X}")
    with open(os.path.join(a.out, "registros.txt"), "w") as f:
        f.write(f"instructions {n}\n" + " ".join(f"{k}={r[v]:02X}" for k, v in (("A", A), ("F", F), ("B", B), ("C", C), ("D", D), ("E", E), ("H", H), ("L", L))) + f" SP={r[SP]:04X} PC={r[PC]:04X}\n")
    print(open(os.path.join(a.out, "registros.txt")).read(), end="")


if __name__ == "__main__":
    main()
