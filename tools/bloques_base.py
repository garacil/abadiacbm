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

"""Room ("screen") data of La Abadia del Crimen (PC booter, 1988): lister, builder and renderer.

Everything here mirrors the x86 code of the room builder, 1000:2945-1000:2CB6 (see
re/notas/motor_b.md).  Addresses are DS offsets (DS = 1800, so DS:x is byte 0x8000+x of
re/disco/programa.bin, or linear 0x18000+x of an emulator memory dump).

  python3 -I bloques.py blocks   [--mem FILE]        bytecode listing of every block (material)
  python3 -I bloques.py rooms    [--mem FILE]        every room record, decoded
  python3 -I bloques.py build N  [--mem FILE]        build room N, print the 20x16 tile buffer
  python3 -I bloques.py check DUMP [--png OUT.png]   rebuild the room that DUMP shows ([1800:B71A]),
                                                     compare the 0x780-byte tile buffer at 1800:EE8E
                                                     and the play area of video RAM with DUMP
  python3 -I bloques.py render N OUT.png [--mem FILE] [--dark]   draw room N alone (no sprites)
  python3 -I bloques.py stats    [--mem FILE]        opcode/operand usage over every room
  python3 -I bloques.py render-all DIR [--mem FILE]  one PNG per non-empty room
  python3 -I bloques.py catalog DIR [--mem FILE]     one PNG per block type, built alone

--mem defaults to re/disco/programa.bin; a .bin dump of 1 MiB (emulator 'dump') is also accepted.
"""
import os, struct, sys, zlib

HERE = os.path.dirname(os.path.abspath(__file__))
TRABAJO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
PROGRAMA = os.path.join(TRABAJO, "re", "disco", "programa.bin")

# ---- addresses (DS offsets) -------------------------------------------------------------
ROOM_TABLE = 0x82C2      # iso_room_table: records [len][entries...][FF], room n = skip n records
BLOCK_TABLE = 0xB71D     # iso_block_table: 96 words, block type (entry byte0 & 0xFE) -> block
OP_TABLE = 0xB7F4        # iso_block_opcode_table: handler of opcode op = word[B7F4 + ((~op*2)&0xFF)]
REGS = 0xB7E3            # iso_block_regs: 17 bytes, operand codes 0x61..0x71
TILE_BUFFER = 0xEE8E     # iso_tile_buffer: 20 rows x 16 columns x 6 bytes
TILE_GFX = 0x2B22        # tile graphics, 32 bytes per tile (read by 1000:1C86, another area)
ROWS, COLS, CELL = 20, 16, 6

# handler address -> opcode name.  Opcodes are decoded through OP_TABLE (as 1000:2A42 does).
HANDLERS = {
    0x2A58: "END", 0x2AD2: "LOOP_P1", 0x2ADE: "LOOP_P2", 0x2B0F: "PUSH_POS", 0x2B13: "POP_POS",
    0x2B17: "NEXT", 0x2B26: "TILES_UP", 0x2B36: "TILES_RIGHT", 0x2B2E: "TILES_LEFT",
    0x2B8F: "SET", 0x2A7E: "Y_INC", 0x2A82: "X_INC", 0x2A86: "Y_DEC", 0x2A8A: "X_DEC",
    0x2A8E: "Y_ADD", 0x2A9C: "X_ADD", 0x2AB0: "P1_INC", 0x2AAA: "P2_INC", 0x2ABC: "P1_DEC",
    0x2AB6: "P2_DEC", 0x2C18: "CALL", 0x2C0E: "CALL_KEEP", 0x2C06: "JUMP", 0x2BEC: "MIRROR",
}
REG_NAMES = {0x6D: "p1", 0x6E: "p2", 0x6F: "h", 0x70: "d0", 0x71: "d1"}
REG_NAMES.update({0x61 + i: "t%d" % (i + 1) for i in range(12)})


class Mem:
    """The 64 KiB data space DS=1800."""
    def __init__(self, path=None):
        raw = open(path or PROGRAMA, "rb").read()
        if len(raw) >= 0x100000:
            self.ds = bytearray(raw[0x18000:0x28000]); self.video = raw[0xB8000:0xBC000]
        else:
            self.ds = bytearray(raw[0x8000:0x18000]); self.video = None
        self.path = path or PROGRAMA

    def b(self, a): return self.ds[a & 0xFFFF]
    def w(self, a): return self.ds[a & 0xFFFF] | self.ds[(a + 1) & 0xFFFF] << 8


def handler(mem, op):
    return mem.w(OP_TABLE + ((~op << 1) & 0xFF))


# ---- rooms ---------------------------------------------------------------------------------
def room_ptr(mem, n):
    """1000:27C8: BX = 82C2, add the length byte n times."""
    a = ROOM_TABLE
    for _ in range(n):
        a = (a + mem.b(a)) & 0xFFFF
    return a


def room_entries(mem, ptr):
    """1000:2967: entries after the length byte, 3 or 4 bytes each, FF ends the list."""
    si, out = ptr + 1, []
    while mem.b(si) != 0xFF:
        b0, b1, b2 = mem.b(si), mem.b(si + 1), mem.b(si + 2)
        e = dict(at=si, raw=[b0, b1, b2], type=b0 & 0xFE, x=b1 & 0x1F, p1=b1 >> 5,
                 y=b2 & 0x1F, p2=b2 >> 5, h=None)
        si += 3
        if b0 & 1:
            e["h"] = mem.b(si); e["raw"].append(e["h"]); si += 1
        out.append(e)
    return out, si


def room_count(mem):
    """Records until a zero length byte (the table is padded with empty 02 FF records)."""
    n, a = 0, ROOM_TABLE
    while mem.b(a) != 0 and n < 400:
        a += mem.b(a); n += 1
    return n


# ---- bytecode lister -----------------------------------------------------------------------
def operand(mem, pc):
    """1000:2C85/2C88.  Returns (text, value-or-None, new pc)."""
    v = mem.b(pc)
    if v < 0x60:
        return "%d" % v, v, pc + 1
    if v == 0x82:
        return "#%02X" % mem.b(pc + 1), mem.b(pc + 1), pc + 2
    return REG_NAMES.get(v, "BADREG_%02X" % v), None, pc + 1


def expression(mem, pc):
    """First operand, then { 84 = negate | operand = add } until a byte >= C8 (1000:2BC4)."""
    t, _, pc = operand(mem, pc)
    parts = [t]
    while mem.b(pc) < 0xC8:
        if mem.b(pc) == 0x84:
            parts = ["-(" + " ".join(parts) + ")"] if len(parts) > 1 else ["-" + parts[0]]
            pc += 1
        else:
            t, _, pc = operand(mem, pc)
            parts.append("+ " + t)
    return " ".join(parts), pc


def tile_run(mem, pc):
    """1000:2B4D: tile [80|81|count] ... ; ends at the first byte >= C8 after a tile."""
    items, odd = [], False
    while True:
        t, _, pc = operand(mem, pc)
        nxt = mem.b(pc)
        if nxt >= 0xC8:
            items.append(t); break
        pc += 1
        if nxt == 0x80:
            items.append(t)
        elif nxt == 0x81:
            items.append(t + "(stay)")
        else:                       # 1000:2B6F, never used by the data (see notes)
            c, _, pc = operand(mem, pc)
            items.append("%s(sep %02X)x%s" % (t, nxt, c)); odd = True
            if mem.b(pc) >= 0xC8:
                break
            pc += 1
    return items, pc, odd


def disasm(mem, start, seen=None):
    """Linear listing from start until END or JUMP.  Returns (lines, targets, flags)."""
    lines, targets, flags = [], [], set()
    pc = start
    while True:
        op = mem.b(pc)
        h = handler(mem, op)
        name = HANDLERS.get(h)
        at = pc; pc += 1
        if name is None:
            lines.append((at, "%02X" % op, "?? opcode %02X -> handler %04X" % (op, h))); flags.add("bad"); break
        if name in ("TILES_UP", "TILES_RIGHT", "TILES_LEFT"):
            items, pc, odd = tile_run(mem, pc)
            if odd: flags.add("count")
            txt = "%s %s" % (name, ", ".join(items))
        elif name == "SET":
            raw = mem.b(pc)
            dst, _, pc2 = operand(mem, pc)
            e, pc = expression(mem, pc2)
            txt = "SET %s = %s" % (dst, e)
            if raw < 0x61 or raw == 0x82: flags.add("setlit")
        elif name in ("Y_ADD", "X_ADD"):
            e, pc = expression(mem, pc)
            txt = "%s %s" % (name, e)
        elif name in ("CALL", "CALL_KEEP", "JUMP"):
            tgt = mem.w(pc); pc += 2
            txt = "%s %04X" % (name, tgt)
            targets.append((name, tgt))
        elif name == "MIRROR":
            txt = "MIRROR" + ("" if op == 0xE9 else "   ; opcode %02X" % op)
        else:
            txt = name
        lines.append((at, mem.ds[at:pc].hex(" ").upper(), txt))
        if name in ("END", "JUMP"):
            break
    return lines, targets, flags


def block_code(mem, blk):
    """All code reachable from a block: its own script plus JUMP targets (not CALLed blocks)."""
    todo, done, out, calls = [blk + 2], set(), [], set()
    while todo:
        s = todo.pop(0)
        if s in done: continue
        done.add(s)
        lines, targets, flags = disasm(mem, s)
        out.append((s, lines, flags))
        for name, t in targets:
            if name == "JUMP": todo.append(t)
            else: calls.add(t)
    return out, calls


def block_list(mem):
    return [(t, mem.w(BLOCK_TABLE + t)) for t in range(0, 0xC0, 2)]


def all_blocks(mem):
    """Table blocks plus every block reached only through CALL / CALL_KEEP ("sub-blocks")."""
    out, seen = [], set()
    for t, blk in block_list(mem):
        out.append(("block %02X" % t, blk))
        if blk: seen.add(blk)
    i = 0
    while i < len(out):
        blk = out[i][1]; i += 1
        if not blk: continue
        for c in sorted(block_code(mem, blk)[1]):
            if c not in seen:
                seen.add(c); out.append(("sub-block", c))
    return out


def cmd_blocks(mem):
    labels = {}
    for name, blk in all_blocks(mem):
        if blk: labels.setdefault(blk + 2, name.replace(" ", "_") if name != "sub-block" else "sub_%04X" % blk)
    for name, blk in all_blocks(mem):
        if not blk:
            print("%s: none (word 0000)\n" % name); continue
        tp = mem.w(blk)
        print("%s @ %04X  tiles @ %04X: %s" % (name, blk, tp, " ".join("%02X" % mem.b(tp + i) for i in range(12))))
        code, calls = block_code(mem, blk)
        for s, lines, flags in code:
            if s != blk + 2:
                print("   %04X:%s" % (s, "   ; = " + labels[s] if s in labels else ""))
            for at, hx, txt in lines:
                print("     %04X  %-24s %s" % (at, hx, txt))
        if calls:
            print("   calls: " + ", ".join("%04X(%s)" % (c, labels.get(c + 2, "?")) for c in sorted(calls)))
        print()


def cmd_rooms(mem):
    n = room_count(mem)
    for r in range(n):
        p = room_ptr(mem, r)
        ents, end = room_entries(mem, p)
        tail = mem.b(p) - (end + 1 - p)
        print("room %02X @ %04X len %d, %d entries%s" % (r, p, mem.b(p), len(ents),
              "" if tail == 0 else ", %d bytes after FF" % tail))
        for e in ents:
            print("   %04X  %-12s block %02X  x=%2d y=%2d p1=%d p2=%d%s" % (
                e["at"], " ".join("%02X" % v for v in e["raw"]), e["type"], e["x"], e["y"], e["p1"], e["p2"],
                "" if e["h"] is None else " h=%d" % e["h"]))


# ---- builder: an exact model of 1000:2945..2CB6 --------------------------------------------
class Builder:
    def __init__(self, mem):
        self.mem = mem
        self.buf = bytearray(ROWS * COLS * CELL)
        self.regs = bytearray(17)            # DS:B7E3..B7F3
        self.flip = 0                        # DS:B7DF
        self.keep = 0                        # DS:B7E2
        self.reset_smc()
        self.stack = []
        self.trace = None
        self.placed = 0

    def reset_smc(self):                     # 1000:2A66
        self.smc = {0x2A82: +1, 0x2B39: +1, 0x2A8A: -1}

    # registers
    @property
    def h(self): return self.regs[14]

    def reg_addr(self, code):                # 1000:2C98: codes >= 70 are XORed with the mirror flag
        if code >= 0x70: code ^= self.flip
        return (code - 0x61) & 0xFF

    def fetch(self):                         # 1000:2C85
        v = self.mem.b(self.si); self.si += 1
        return self.value(v)

    def value(self, v):                      # 1000:2C88 -> (value, register index or None)
        if v < 0x60: return v, None
        if v == 0x82:
            x = self.mem.b(self.si); self.si += 1; return x, None
        i = self.reg_addr(v)
        if i >= 17: raise ValueError("operand %02X reads DS:%04X" % (v, REGS + i))
        return self.regs[i], i

    def expr(self, first):                   # 1000:2BC4
        acc = first
        while self.mem.b(self.si) < 0xC8:
            if self.mem.b(self.si) == 0x84:
                self.si += 1; acc = (-acc) & 0xFF
            else:
                acc = (acc + self.fetch()[0]) & 0xFF
        return acc

    def depth(self):                         # 1000:287D, AL = h
        a = self.h
        if a == 0xFF: return
        t = ((a >> 1) + self.bh) & 0xFF
        self.regs[15] = (t + self.bl - 15) & 0xFF
        self.regs[16] = (16 + t - self.bl) & 0xFF

    def place(self, tile):                   # 1000:28A7
        r, c = (self.bh - 8) & 0xFF, (self.bl - 8) & 0xFF
        if r >= ROWS or c >= COLS: return
        o = (r * COLS + c) * CELL
        b = self.buf
        cl, ch = b[o + 3], b[o + 4]
        b[o + 2] = b[o + 5]
        d0, d1 = self.regs[15], self.regs[16]
        b[o + 3] = d0
        if d0 < cl and d1 < ch:
            cl, ch = d0, d1
        b[o + 4] = d1
        b[o + 0], b[o + 1] = cl, ch
        b[o + 5] = tile
        self.placed += 1

    def step(self, kind):
        if kind == "up": self.bh = (self.bh - 1) & 0xFF
        elif kind == "left": self.bl = (self.bl - 1) & 0xFF
        else: self.bl = (self.bl + self.smc[0x2B39]) & 0xFF

    def enter(self, copy, tiles_ptr):        # 1000:2A1E (copy) / 1000:2A1B (no copy), then 2A3A
        if copy:
            for i in range(12): self.regs[i] = self.mem.b(tiles_ptr + i)
        self.depth()
        bp = self.si
        self.si = self.stack.pop()
        self.stack.append(bp)

    def build(self, ptr, fill=True):
        if fill: self.buf[:] = bytes(len(self.buf))      # 1000:29E1
        self.si = ptr + 1
        while True:                                       # 1000:2967
            b0 = self.mem.b(self.si)
            if b0 == 0xFF: return self.buf
            blk = self.mem.w(BLOCK_TABLE + (b0 & 0xFE))
            b1, b2 = self.mem.b(self.si + 1), self.mem.b(self.si + 2)
            self.bl, p1, self.bh, p2 = b1 & 0x1F, b1 >> 5, b2 & 0x1F, b2 >> 5
            self.regs[15] = self.regs[16] = 0
            self.si += 3
            if b0 & 1:
                h = self.mem.b(self.si); self.si += 1
            else:
                h = 0xFF
            self.regs[14] = h
            self.stack = ["2967"]
            self.stack.append(blk + 2)                   # PUSH BP (script)
            self.regs[12], self.regs[13] = p1, p2        # [B7EF] = CX happens in 2A3A; same values
            self.enter(True, self.mem.w(blk))
            self.run()

    def run(self):
        m = self.mem
        steps = 0
        while True:
            steps += 1
            if steps > 1_000_000: raise RuntimeError("block bytecode does not terminate")
            at = self.si
            op = m.b(self.si); self.si += 1
            h = handler(m, op)
            name = HANDLERS.get(h)
            if self.trace is not None: self.trace.append((at, name, self.bl, self.bh))
            if name is None:
                raise ValueError("bad opcode %02X at %04X" % (op, at))
            if name == "END":                              # 1000:2A58
                self.si = self.stack.pop()
                k, self.keep = self.keep, 0
                if not k:
                    self.reset_smc(); self.flip = 0
                ret = self.stack.pop()
                if ret == "2967": return
                assert ret == "2C5E", ret
                self.regs[14] = self.stack.pop()
                self.regs[12], self.regs[13] = self.stack.pop()
                self.regs[15], self.regs[16] = self.stack.pop()
                self.flip = self.stack.pop()
                self.smc[0x2B39] = self.stack.pop(); self.smc[0x2A8A] = self.stack.pop(); self.smc[0x2A82] = self.stack.pop()
                self.bl, self.bh = self.stack.pop()
            elif name in ("LOOP_P1", "LOOP_P2"):            # 1000:2AD2 / 2ADE
                cnt = self.regs[12 if name == "LOOP_P1" else 13]
                if cnt:
                    self.stack.append(self.si); self.stack.append(cnt)
                else:                                      # 1000:2AE5: skip to the matching NEXT
                    lvl = 1
                    while True:
                        a = m.b(self.si); self.si += 2
                        if a == 0x82: continue
                        self.si -= 1; lvl += 1
                        if a in (0xFE, 0xFD, 0xE8, 0xE7): continue
                        lvl -= 1
                        if a != 0xFA: continue
                        lvl -= 1
                        if lvl == 0: break
            elif name == "NEXT":                           # 1000:2B17
                c = (self.stack.pop() - 1) & 0xFF
                if c == 0:
                    self.stack.pop()
                else:
                    self.si = self.stack[-1]; self.stack.append(c)
            elif name == "PUSH_POS": self.stack.append((self.bl, self.bh))
            elif name == "POP_POS": self.bl, self.bh = self.stack.pop()
            elif name in ("TILES_UP", "TILES_RIGHT", "TILES_LEFT"):   # 1000:2B3E
                kind = {"TILES_UP": "up", "TILES_LEFT": "left", "TILES_RIGHT": "right"}[name]
                while True:
                    tile = self.fetch()[0]
                    nxt = m.b(self.si)
                    if nxt >= 0xC8:
                        self.place(tile); self.step(kind); break
                    self.si += 1
                    if nxt == 0x80:
                        self.place(tile); self.step(kind)
                    elif nxt == 0x81:
                        self.place(tile)
                    else:
                        raise ValueError("count form of a tile run at %04X (unused path 1000:2B6F)" % at)
            elif name == "SET":                            # 1000:2B8F
                dst = m.b(self.si)
                _, idx = self.fetch()
                v = self.expr(self.fetch()[0])
                if idx is None: idx = 0              # DX is still B7E3 after a literal (1000:2C88)
                if dst < 0x70:
                    self.regs[idx] = v
                elif self.regs[idx] != 0:
                    self.regs[idx] = 0 if v >= 0x64 else v
            elif name == "Y_INC": self.bh = (self.bh + 1) & 0xFF
            elif name == "Y_DEC": self.bh = (self.bh - 1) & 0xFF
            elif name == "X_INC": self.bl = (self.bl + self.smc[0x2A82]) & 0xFF
            elif name == "X_DEC": self.bl = (self.bl + self.smc[0x2A8A]) & 0xFF
            elif name == "Y_ADD": self.bh = (self.bh + self.expr(self.fetch()[0])) & 0xFF
            elif name == "X_ADD": self.bl = (self.bl + self.expr(self.fetch()[0])) & 0xFF
            elif name in ("P1_INC", "P2_INC", "P1_DEC", "P2_DEC"):     # 1000:2AC0
                i = 12 if name.startswith("P1") else 13
                self.regs[i] = (self.regs[i] + (1 if name.endswith("INC") else -1)) & 0xFF
            elif name in ("CALL", "CALL_KEEP"):            # 1000:2C18 / 2C0E
                if name == "CALL_KEEP": self.keep = 1
                self.stack += [(self.bl, self.bh), self.smc[0x2A82], self.smc[0x2A8A], self.smc[0x2B39],
                               self.flip, (self.regs[15], self.regs[16]), (self.regs[12], self.regs[13]),
                               self.regs[14], "2C5E"]
                blk = m.w(self.si); self.si += 2
                self.stack.append(blk + 2)
                self.enter(name == "CALL", m.w(blk))
            elif name == "JUMP":
                self.si = m.w(self.si)
            elif name == "MIRROR":                         # 1000:2BEC
                self.smc = {0x2A82: -1, 0x2B39: -1, 0x2A8A: +1}; self.flip = 1
            else:
                raise AssertionError(name)


def build_room(mem, n=None, ptr=None):
    b = Builder(mem)
    b.build(room_ptr(mem, n) if ptr is None else ptr)
    return b.buf


def cmd_build(mem, n):
    buf = build_room(mem, n)
    print("room %02X: upper tile of each cell (lower tile in brackets when non-zero)" % n)
    for r in range(ROWS):
        row = []
        for c in range(COLS):
            o = (r * COLS + c) * CELL
            row.append("%02X%s" % (buf[o + 5], "[%02X]" % buf[o + 2] if buf[o + 2] else "    "))
        print("%2d " % r + " ".join(row))
    print("depth (d0,d1) of the upper tile:")
    for r in range(ROWS):
        print("%2d " % r + " ".join("%02X%02X" % (buf[(r * COLS + c) * CELL + 3], buf[(r * COLS + c) * CELL + 4]) for c in range(COLS)))


# ---- renderer: what 1000:1BD6 / 1000:1C86 do with the buffer (other area's code) -------------
def spiral():
    """Cell visiting order of 1000:1BD6 (start row 8 col 7; down, right, up, left)."""
    cnt = {"d": 4, "r": 1, "u": 5, "l": 2}
    r, c, order = 8, 7, []
    while cnt["d"] < 20:
        for k, dr, dc in (("d", 1, 0), ("r", 0, 1), ("u", -1, 0), ("l", 0, -1)):
            n = cnt[k]; cnt[k] += 2
            for _ in range(n):
                order.append((r, c)); r += dr; c += dc
    return order


def render(mem, buf, fill):
    """2-bit pixels of the 256x160 play area (x 32..287 of the screen)."""
    vram = bytearray(0x4000)
    def addr(y, xb): return (0x2000 if y & 1 else 0) + (y >> 1) * 80 + xb
    for y in range(160):
        for xb in range(8, 72): vram[addr(y, xb)] = fill
    for (r, c) in spiral():
        if not (0 <= r < ROWS and 0 <= c < COLS): continue
        o = (r * COLS + c) * CELL
        for tile in (buf[o + 2], buf[o + 5]):
            if not tile: continue
            src = TILE_GFX + tile * 32
            tab = 0x200 if tile & 0x80 else 0
            for line in range(8):
                y = r * 8 + line
                for i in range(4):
                    g = mem.b(src + line * 4 + i)
                    a = addr(y, 8 + c * 4 + i)
                    if tile < 0x0B: vram[a] = mem.b(g)
                    else: vram[a] = (vram[a] & mem.b(tab + 0x100 + g)) | mem.b(tab + g)
    return vram


PALETTE = [(0, 0, 0), (85, 255, 85), (255, 85, 85), (255, 255, 85)]   # CGA palette 0, high intensity


def write_png(path, vram, w=320, h=200):
    rows = []
    for y in range(h):
        line = bytearray()
        for x in range(w):
            a = (0x2000 if y & 1 else 0) + (y >> 1) * 80 + (x >> 2)
            pix = (vram[a] >> (6 - 2 * (x & 3))) & 3
            line += bytes(PALETTE[pix])
        rows.append(bytes(line))
    raw = b"".join(b"\x00" + r for r in rows)
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def cmd_check(path, png=None):
    mem = Mem(path)
    ptr = mem.w(0xB71A)
    n = next((r for r in range(room_count(mem)) if room_ptr(mem, r) == ptr), None)
    dark = mem.b(0xB71C)
    buf = Builder(mem).build(ptr)
    ref = mem.ds[TILE_BUFFER:TILE_BUFFER + len(buf)]
    diff = [i for i in range(len(buf)) if buf[i] != ref[i]]
    print("%s: room %s (DS:%04X), dark flag %d, tile buffer: %d of %d bytes differ"
          % (os.path.basename(path), "%02X" % n if n is not None else "?", ptr, dark, len(diff), len(buf)))
    for i in diff[:20]:
        r, c, k = i // (COLS * CELL), (i // CELL) % COLS, i % CELL
        print("   row %d col %d byte %d: built %02X, dump %02X" % (r, c, k, buf[i], ref[i]))
    if mem.video is not None:
        fill = 0 if dark else mem.b(0xAD20)
        v = render(mem, buf, fill)
        same = tot = 0
        for y in range(160):
            for xb in range(8, 72):
                a = (0x2000 if y & 1 else 0) + (y >> 1) * 80 + xb
                tot += 1; same += v[a] == mem.video[a]
        print("   play area: %d of %d video bytes equal to the dump (the rest = sprites drawn over it)" % (same, tot))
        if png: write_png(png, v); print("   wrote", png)
    return len(diff)


def cmd_render(mem, n, out, dark=False):
    buf = build_room(mem, n)
    write_png(out, render(mem, buf, 0 if dark else mem.b(0xAD20)))


def cmd_render_all(mem, outdir):
    """One PNG per room (as the game draws it when lit, without sprites)."""
    os.makedirs(outdir, exist_ok=True)
    for r in range(room_count(mem)):
        if len(room_entries(mem, room_ptr(mem, r))[0]) == 0: continue
        cmd_render(mem, r, os.path.join(outdir, "sala_%02X.png" % r))
    print("rooms written to", outdir)


def block_alone(mem, t, x=16, y=22, p1=2, p2=2, h=None):
    """Build one entry of block type t in an otherwise empty room (synthetic record in a copy of DS)."""
    m2 = Mem.__new__(Mem); m2.ds = bytearray(mem.ds); m2.video = None; m2.path = mem.path
    rec = [t | (1 if h is not None else 0), (p1 << 5) | x, (p2 << 5) | y] + ([h] if h is not None else []) + [0xFF]
    at = 0xA772                                   # zero bytes after the padded room table
    m2.ds[at] = len(rec) + 1
    m2.ds[at + 1:at + 1 + len(rec)] = bytes(rec)
    b = Builder(m2); b.build(at)
    return m2, b.buf


def cmd_catalog(mem, outdir):
    """One PNG per block type: the block alone, p1 = p2 = 2, at x=16 y=22, with and without height 0."""
    os.makedirs(outdir, exist_ok=True)
    for t, blk in block_list(mem):
        if not blk: continue
        for h, suf in ((None, ""), (0, "_h0")):
            try:
                m2, buf = block_alone(mem, t, h=h)
            except Exception as e:
                print("block %02X%s: %s" % (t, suf, e)); continue
            write_png(os.path.join(outdir, "bloque_%02X%s.png" % (t, suf)), render(m2, buf, 0))
    print("blocks written to", outdir)


def cmd_stats(mem):
    from collections import Counter
    ops, used_blocks, errors = Counter(), Counter(), []
    for r in range(room_count(mem)):
        p = room_ptr(mem, r)
        b = Builder(mem); b.trace = []
        try:
            b.build(p)
        except Exception as e:
            errors.append((r, str(e)))
        for at, name, bl, bh in b.trace: ops[name] += 1
        for e in room_entries(mem, p)[0]: used_blocks[e["type"]] += 1
    print("opcodes executed over all rooms:")
    for k, v in ops.most_common(): print("   %-12s %d" % (k, v))
    print("block types used by rooms: %d of 95" % len(used_blocks))
    print("   never used:", " ".join("%02X" % t for t, blk in block_list(mem) if blk and t not in used_blocks))
    print("errors:", errors or "none")
    flags = Counter()
    for t, blk in block_list(mem):
        if not blk: continue
        for s, lines, fl in block_code(mem, blk)[0]:
            for f in fl: flags[f] += 1
    print("static listing flags (count form / bad opcode / SET to literal):", dict(flags) or "none")


def main(argv):
    args = list(argv)
    mem_path = None
    if "--mem" in args:
        i = args.index("--mem"); mem_path = args[i + 1]; del args[i:i + 2]
    png = None
    if "--png" in args:
        i = args.index("--png"); png = args[i + 1]; del args[i:i + 2]
    dark = "--dark" in args
    if dark: args.remove("--dark")
    if not args:
        print(__doc__); return 1
    cmd = args[0]
    if cmd == "check":
        bad = 0
        for p in args[1:]: bad += cmd_check(p, png) != 0
        return 1 if bad else 0
    mem = Mem(mem_path)
    if cmd == "blocks": cmd_blocks(mem)
    elif cmd == "rooms": cmd_rooms(mem)
    elif cmd == "build": cmd_build(mem, int(args[1], 0))
    elif cmd == "render": cmd_render(mem, int(args[1], 0), args[2], dark)
    elif cmd == "stats": cmd_stats(mem)
    elif cmd == "render-all": cmd_render_all(mem, args[1])
    elif cmd == "catalog": cmd_catalog(mem, args[1])
    else:
        print(__doc__); return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
