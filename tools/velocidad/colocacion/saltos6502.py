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

"""saltos6502.py: avoidable jumps in the 6502 game of abadia64ks (C64 build), weighed by the dynamic profile.

Deterministic (same inputs -> same outputs; run with python3 -I).  Nothing is counted by hand: every cycle figure
comes from cc65's sim65 core (juego/m6502/6502.c) through the analyzer's tabla_opcodes.tsv (one row per opcode with
the 6502.c lines it was read from), and the jump-related constants used here are cited where they are used:
  JMP abs 3 cycles (6502.c 1953-1956), JSR 6 (1534-1556), RTS 6 (2154-2156), JMP (ind) 5 (2283-2290),
  a branch 2, +1 taken, +1 more when the taken branch changes page (BRANCH macro, 751-769).

Inputs (all made by build/construye.sh from a copy of the sources):
  * the sources (SRC/juego_final/*.s, SRC/plataforma/*.s): the source-level block model (what can move);
  * the normal C64 build (ld65 --dbgfile juego.dbg + juego.bin): every CODE/BAJO byte mapped to its source line,
    decoded from the image (ca65 -g changes no byte: the image is checked byte-identical to the project's);
  * the checked build (-D PRUEBA, the same sources): the addresses of the dynamic profile;
  * the per-address cycle profiles of the host (perfil_N.tsv, "ADDR\\tCYCLES", one per session) with their frame
    counts: an instruction of fixed cost ran cycles/cost times (exact); a branch's taken/not-taken counts are
    derived from its predecessor when that is exact and nothing else enters the branch (said in the output).

Blocks: a routine is a source block: a `.proc`...`.endproc`, or (in the files written with plain labels) the
lines from a column-0 label to the next one, with the comment lines above the label attached to it.  `.segment`
directives and the `.ifdef`/`.endif` groups that hold one (the SPRHW segments) or hold block starts are region
boundaries; regions with the same (normal, SPRHW) segment pair form a zone, and blocks move only inside their
zone, so both builds keep their segments.  A block whose last instruction is not RTS/RTI/JMP/BRK falls into the
next block: that is an existing fall-through edge, kept when its execution count is unknown (hard chain) and
otherwise weighed like any other edge (breaking it costs a `jmp` of 3 cycles per pass and 3 bytes).  A block whose
unnamed-label references (`:+`, `:-`) resolve outside it is tied to its neighbour (hard chain).

Candidates (each with cycles saved per execution, executions per frame, bytes):
  tail_jmp        a block's last instruction is `jmp X`, X a block entry: fall-through if X can follow it
  tail_jsr_rts    `jsr X` followed by `rts`: `jmp X` (and fall-through when it ends the block and X can follow)
  jmp_to_rts      `jmp L` with L: rts -> `rts` in place
  branch_to_rts   `bcc L` with L: rts -> inverted branch over an `rts` in place (net: taken - not taken)
  branch_over_jmp `bXX :+ / jmp X / :` -> `bYY X` when X is in branch range
  jmp_to_next     `jmp` to the next instruction (not a tail); jmp_chain: `jmp`/`jsr` to a `jmp M` -> M
Placement: a maximum-weight path cover of the chains of each zone.  Every chain has at most one candidate
successor (its last instruction is one jump or one fall-through), so the cover is exact: each target keeps its
heaviest incoming edge, cycles are broken at their lightest edge.  Conflicts and the impossible ones are reported.

Usage:
  saltos6502.py analyse --src SRC --normal OUT/c64 --prueba OUT/prueba --opcodes tabla_opcodes.tsv
                        --profile NAME=FILE:FRAMES ... --out DIR [--apply SRC_NEW]
  saltos6502.py verify  --src SRC --normal OUT/c64 --prueba OUT/prueba --src-new SRC_NEW --normal-new OUT_NEW/c64
                        --prueba-new OUT_NEW/prueba --hw-lst OUT_NEW/hw/lst --opcodes tabla_opcodes.tsv
                        --plan DIR/plan.json --out DIR
"""
import argparse
import json
import os
import re
import sys
from collections import OrderedDict, defaultdict

# ------------------------------------------------------------------------------------------------------------
# constants cited from 6502.c (see the module docstring); re-checked against tabla_opcodes.tsv at load time
CY_JMP, CY_JSR, CY_RTS, CY_JMP_IND = 3, 6, 6, 5
CY_BR_NT, CY_BR_TK, CY_BR_TK_CROSS = 2, 3, 4
CITE = {'JMP': '6502.c 1953-1956 (JMP abs: Cycles = 3)', 'JSR': '6502.c 1534-1556 (JSR: Cycles = 6)',
        'RTS': '6502.c 2154-2156 (RTS: Cycles = 6)', 'BR': '6502.c 751-769 (BRANCH: 2, +1 taken, +1 page change)'}
BRANCHES = {'BCC': 'BCS', 'BCS': 'BCC', 'BEQ': 'BNE', 'BNE': 'BEQ', 'BPL': 'BMI', 'BMI': 'BPL', 'BVC': 'BVS',
            'BVS': 'BVC'}
TERMINATORS = {'RTS', 'RTI', 'JMP', 'BRK'}
MNEMONICS = set('''ADC AND ASL BCC BCS BEQ BIT BMI BNE BPL BRK BVC BVS CLC CLD CLI CLV CMP CPX CPY DEC DEX DEY
EOR INC INX INY JMP JSR LDA LDX LDY LSR NOP ORA PHA PHP PLA PLP ROL ROR RTI RTS SBC SEC SED SEI STA STX STY
TAX TAY TSX TXA TXS TYA'''.split())
DATA_DIRECTIVES = ('.byte', '.byt', '.word', '.addr', '.res', '.dbyt', '.lobytes', '.hibytes', '.asciiz',
                   '.incbin', '.faraddr', '.dword', '.bankbytes')
IF_OPEN = ('.if', '.ifdef', '.ifndef', '.ifblank', '.ifnblank', '.ifconst', '.ifref', '.ifnref', '.ifp02',
           '.ifp816', '.ifpc02', '.ifpsc02')
NORMAL_FILES = ('plataforma_prueba.s', 'plat_aleatorio_prueba.s', 'stubs64.s')     # not in the C64 build
PLATFORM_ORDER = ['tinta', 'teclado', 'psg', 'interrupcion', 'disco']
CODE_SEGS = ('CODE', 'BAJO')
SESSIONS_MEAN = 3            # the first three profiles (the azar sessions) give the reference mean per frame


def load_opcodes(path):
    """tabla_opcodes.tsv (the analyzer's, each row citing 6502.c) -> {opcode: dict}; checks the constants above."""
    ops = {}
    with open(path, encoding='utf-8') as f:
        hdr = f.readline().rstrip('\n').split('\t')
        for line in f:
            r = dict(zip(hdr, line.rstrip('\n').split('\t')))
            opc = int(r['opcode'], 16)
            ops[opc] = {'mn': r['mnemonic'], 'mode': r['mode'], 'length': int(r['bytes']), 'cycles': int(r['cycles']),
                        'cross': r['page_cross_plus1'] == 'yes', 'branch': r['branch_not_taken'] != '',
                        'src': r['source_6502c']}
    assert ops[0x4C]['cycles'] == CY_JMP and ops[0x20]['cycles'] == CY_JSR and ops[0x60]['cycles'] == CY_RTS
    assert ops[0x6C]['cycles'] == CY_JMP_IND
    return ops


# ------------------------------------------------------------------------------------------------------------
# ld65 debug file, map and the image
def parse_dbg(path):
    segs, spans, lines, files, mods, syms = {}, {}, [], {}, {}, []
    with open(path, encoding='utf-8') as f:
        for l in f:
            if '\t' not in l:
                continue
            kind, rest = l.rstrip('\n').split('\t', 1)
            d = OrderedDict()
            for kv in rest.split(','):
                k, _, v = kv.partition('=')
                d[k] = v
            if kind == 'seg':
                segs[int(d['id'])] = (d['name'].strip('"'), int(d['start'], 16), int(d['size'], 16))
            elif kind == 'span':
                spans[int(d['id'])] = (int(d['seg']), int(d['start']), int(d['size']))
            elif kind == 'line' and 'span' in d:
                lines.append((int(d['file']), int(d['line']), d.get('type', ''),
                              [int(x) for x in d['span'].split('+')]))
            elif kind == 'file':
                files[int(d['id'])] = d['name'].strip('"')
            elif kind == 'mod':
                mods[int(d['id'])] = d['name'].strip('"')
            elif kind == 'sym' and d.get('type') == 'lab' and 'val' in d and 'seg' in d:
                syms.append((int(d['val'], 16), d['name'].strip('"'), int(d['seg'])))
    return segs, spans, lines, files, mods, syms


def parse_map_modules(path):
    """ld65 -m: module -> {segment: (offset, size)} and the segment list (name -> start, end, size)."""
    modules, segments = OrderedDict(), {}
    cur = None
    with open(path, encoding='utf-8') as f:
        text = f.read().split('\n')
    i = 0
    while i < len(text):
        l = text[i]
        m = re.match(r'^(\S+\.o):$', l)
        if m:
            cur = os.path.basename(m.group(1))
            modules[cur] = {}
        elif cur and re.match(r'^\s+\S+\s+Offs=', l):
            for seg, offs, size in re.findall(r'(\S+)\s+Offs=([0-9A-F]+)\s+Size=([0-9A-F]+)', l):
                modules[cur][seg] = (int(offs, 16), int(size, 16))
        elif l.startswith('Segment list:'):
            cur = None
            i += 4
            while i < len(text) and text[i].strip() and not text[i].startswith('-'):
                p = text[i].split()
                segments[p[0]] = (int(p[1], 16), int(p[2], 16), int(p[3], 16))
                i += 1
            break
        i += 1
    return modules, segments


def strip_comment(line):
    out, q = [], None
    for ch in line:
        if q:
            out.append(ch)
            if ch == q:
                q = None
        elif ch in '"\'':
            q = ch
            out.append(ch)
        elif ch == ';':
            break
        else:
            out.append(ch)
    return ''.join(out)


def macro_kinds_of(srcdir):
    """Macro name -> 'code' | 'data' from the .macro bodies of the sources and includes."""
    kinds = {}
    for sub in ('juego_final', 'plataforma'):
        d = os.path.join(srcdir, sub)
        for fn in sorted(os.listdir(d)):
            if not (fn.endswith('.s') or fn.endswith('.inc')):
                continue
            with open(os.path.join(d, fn), encoding='utf-8') as f:
                txt = f.read().split('\n')
            name = None
            for l in txt:
                t = strip_comment(l).strip()
                m = re.match(r'\.macro\s+(\w+)', t, re.I)
                if m:
                    name = m.group(1)
                    kinds[name] = 'data'
                    continue
                if re.match(r'\.endmacro', t, re.I):
                    name = None
                    continue
                if name and t:
                    tok = t.split()[0].upper()
                    if tok in MNEMONICS or tok.startswith('.PROC'):
                        kinds[name] = 'code'
    return kinds


def classify_line(text, macro_kinds):
    """True when the bytes of this source line are data (not instructions)."""
    t = strip_comment(text).strip()
    t = re.sub(r'^(@?[A-Za-z_][A-Za-z0-9_]*:|:)\s*', '', t)      # a leading label
    if not t:
        return False
    tok = t.split()[0]
    low = tok.lower()
    if low in DATA_DIRECTIVES or low.startswith('.repeat') or low == '.res':
        return True
    if tok.upper() in MNEMONICS:
        return False
    if tok in macro_kinds:
        return macro_kinds[tok] == 'data'
    return True


class Build:
    """One linked build: the image decoded along the debug file's line spans."""

    def __init__(self, outdir, ops, srcdir):
        self.dir = outdir
        self.ops = ops
        self.segs, self.spans, self.lines, self.files, self.mods, self.syms = parse_dbg(os.path.join(outdir, 'juego.dbg'))
        with open(os.path.join(outdir, 'juego.bin'), 'rb') as f:
            self.mem = f.read()
        self.modules, self.segments = parse_map_modules(os.path.join(outdir, 'juego.map'))
        self.code_segs = {i for i, (n, s, z) in self.segs.items() if n in CODE_SEGS}
        self.code_ranges = [(s, s + z) for i, (n, s, z) in self.segs.items() if n in CODE_SEGS]
        self.srcdir = srcdir
        self.src_cache = {}
        self.macro_kinds = macro_kinds_of(srcdir)
        self.labels_at = defaultdict(list)
        for val, name, seg in self.syms:
            if seg in self.code_segs:
                self.labels_at[val].append(name)
        self.items = []              # [addr, size, file, line, text] in address order, one per line span
        self.instrs = []             # decoded instructions
        self.by_addr = {}
        self.data = []
        self.decode()

    def source_lines(self, fname):
        if fname not in self.src_cache:
            for sub in ('juego_final', 'plataforma'):
                p = os.path.join(self.srcdir, sub, fname)
                if os.path.exists(p):
                    with open(p, encoding='utf-8') as f:
                        self.src_cache[fname] = f.read().split('\n')
                    break
            else:
                self.src_cache[fname] = None
        return self.src_cache[fname]

    def in_code(self, a):
        return any(s <= a < e for s, e in self.code_ranges)

    def decode(self):
        covered = {}
        for fid, ln, typ, sp in self.lines:
            if typ:                                      # a macro body line: its bytes belong to the invocation
                continue
            fname = os.path.basename(self.files[fid])
            src = self.source_lines(fname)
            text = src[ln - 1] if src and ln - 1 < len(src) else ''
            for s in sp:
                seg, st, sz = self.spans[s]
                if seg not in self.code_segs or sz == 0:
                    continue
                a = self.segs[seg][1] + st
                key = (a, sz)
                if key in covered:                       # .repeat: the repeat line and the body line both cover
                    continue
                covered[key] = True
                self.items.append([a, sz, fname, ln, text])
        self.items.sort(key=lambda t: (t[0], -t[1]))
        # a .repeat / .endrepeat line covers its whole expansion and the body lines cover their own parts: keep the
        # body lines (they say whether the bytes are code or data) and drop the repeat line; otherwise keep the
        # widest item at an address
        def is_repeat(text):
            t = re.sub(r'^(@?[A-Za-z_][A-Za-z0-9_]*:|:)\s*', '', strip_comment(text).strip()).lower()
            return t.startswith('.repeat') or t.startswith('.endrep')
        pruned, last_end = [], -1
        for it in self.items:
            if is_repeat(it[4]):
                continue
            if it[0] < last_end:
                continue
            pruned.append(it)
            last_end = it[0] + it[1]
        self.items = pruned
        for a, sz, fname, ln, text in self.items:
            if classify_line(text, self.macro_kinds):
                self.data.append({'addr': a, 'size': sz, 'file': fname, 'line': ln, 'text': text,
                                  'bytes': self.mem[a:a + sz]})
                continue
            pos, k = 0, 0
            while pos < sz:
                opc = self.mem[a + pos]
                op = self.ops.get(opc)
                if op is None or pos + op['length'] > sz:
                    raise SystemExit('%s:%d: cannot decode $%04X (opcode %02X) in "%s"' % (fname, ln, a + pos, opc, text))
                raw = self.mem[a + pos:a + pos + op['length']]
                ins = {'addr': a + pos, 'len': op['length'], 'opc': opc, 'mn': op['mn'], 'mode': op['mode'],
                       'cycles': op['cycles'], 'branch': op['branch'], 'file': fname, 'line': ln, 'k': k,
                       'text': text, 'bytes': bytes(raw), 'target': None, 'cross': False, 'tk_cross': 0}
                if op['branch']:
                    disp = raw[1] - 256 if raw[1] >= 128 else raw[1]
                    nxt = a + pos + 2
                    ins['target'] = (nxt + disp) & 0xFFFF
                    ins['tk_cross'] = 1 if (ins['target'] >> 8) != (nxt >> 8) else 0
                elif op['mn'] in ('JSR', 'JMP') and op['mode'] == 'abs':
                    ins['target'] = raw[1] | (raw[2] << 8)
                elif op['mode'] in ('abs', 'abs,x', 'abs,y', '(ind)'):
                    ins['target'] = raw[1] | (raw[2] << 8)
                elif op['length'] == 2 and op['mode'] != 'imm':
                    ins['target'] = raw[1]
                if op['cross']:
                    if op['mode'] in ('abs,x', 'abs,y'):
                        ins['cross'] = (ins['target'] & 0xFF) != 0
                    else:
                        ins['cross'] = True
                self.instrs.append(ins)
                pos += op['length']
                k += 1
        self.instrs.sort(key=lambda i: i['addr'])
        for n, ins in enumerate(self.instrs):
            ins['idx'] = n
            self.by_addr[ins['addr']] = ins
        self.by_key = {(i['file'], i['line'], i['k']): i for i in self.instrs}
        self.jump_targets = defaultdict(list)       # address -> instructions that jump/branch/call there
        for ins in self.instrs:
            if ins['target'] is not None and (ins['branch'] or ins['mn'] in ('JMP', 'JSR')) and ins['mode'] != '(ind)':
                self.jump_targets[ins['target']].append(ins)

    def prev_instr(self, ins):
        """The instruction physically before ins (contiguous), or None."""
        if ins['idx'] == 0:
            return None
        p = self.instrs[ins['idx'] - 1]
        return p if p['addr'] + p['len'] == ins['addr'] else None

    def next_instr(self, ins):
        if ins['idx'] + 1 >= len(self.instrs):
            return None
        n = self.instrs[ins['idx'] + 1]
        return n if n['addr'] == ins['addr'] + ins['len'] else None


# ------------------------------------------------------------------------------------------------------------
# the source-level block model
class SourceFile:
    def __init__(self, path, name, macro_kinds):
        self.path, self.name = path, name
        with open(path, encoding='utf-8') as f:
            self.lines = f.read().split('\n')
        if self.lines and self.lines[-1] == '':
            self.lines.pop()
        self.macro_kinds = macro_kinds
        self.parse()

    def parse(self):
        L = self.lines
        n = len(L)
        depth = [0] * (n + 1)
        info = []
        d = 0
        in_macro = False
        in_proc = None
        proc_start = None
        if_stack = []
        groups = {}
        proc_spans = []
        for i, raw in enumerate(L):
            t = strip_comment(raw)
            s = t.strip()
            depth[i] = d
            rec = {'depth': d, 'label': None, 'anon': False, 'proc': None, 'endproc': False, 'segment': None,
                   'ifopen': False, 'ifclose': False, 'else': False, 'data': False, 'mnemonic': None,
                   'macro_inv': None, 'comment_only': (s == ''), 'directive': None, 'in_macro': in_macro,
                   'assign': False, 'operand': ''}
            if s.lower().startswith('.macro'):
                in_macro = True
                rec['in_macro'] = True
                rec['directive'] = '.macro'
            elif s.lower().startswith('.endmacro'):
                in_macro = False
                rec['directive'] = '.endmacro'
            elif in_macro:
                pass
            else:
                m = re.match(r'^(@?[A-Za-z_][A-Za-z0-9_]*):\s*(.*)$', t)
                if m:
                    rec['label'] = m.group(1)
                    s = m.group(2).strip()
                elif re.match(r'^:\s*', t):
                    rec['anon'] = True
                    s = re.sub(r'^:\s*', '', t).strip()
                elif re.match(r'^[A-Za-z_][A-Za-z0-9_]*\s*(=|:=)', t):
                    rec['assign'] = True
                    s = ''
                tok = s.split()[0] if s else ''
                low = tok.lower()
                if low.startswith('.proc'):
                    name = s.split()[1] if len(s.split()) > 1 else '?'
                    rec['proc'] = name
                    in_proc = name
                    proc_start = i
                elif low == '.endproc':
                    rec['endproc'] = True
                    proc_spans.append((proc_start, i, in_proc))
                    in_proc = None
                elif low == '.segment':
                    rec['segment'] = s.split(None, 1)[1].strip().strip('"') if len(s.split(None, 1)) > 1 else ''
                elif low in IF_OPEN:
                    rec['ifopen'] = True
                    if_stack.append(i)
                    d += 1
                elif low == '.endif':
                    rec['ifclose'] = True
                    d -= 1
                    o = if_stack.pop()
                    groups[o] = i
                elif low in ('.else', '.elseif'):
                    rec['else'] = True
                elif low in DATA_DIRECTIVES or low.startswith('.repeat') or low in ('.endrep', '.endrepeat'):
                    rec['data'] = True
                elif tok.upper() in MNEMONICS:
                    rec['mnemonic'] = tok.upper()
                    rec['operand'] = s[len(tok):].strip()
                elif tok in self.macro_kinds:
                    rec['macro_inv'] = tok
                    rec['macro_args'] = s[len(tok):].strip()
                    if self.macro_kinds[tok] == 'data':
                        rec['data'] = True
                elif low.startswith('.'):
                    rec['directive'] = low
            info.append(rec)
        self.info = info
        self.groups = groups
        self.proc_spans = proc_spans
        proc_lines = set()
        for a, b, _ in proc_spans:
            proc_lines.update(range(a, b + 1))
        self.proc_lines = proc_lines
        # --- structural .if groups: hold a .segment, a .proc, a column-0 label, or a .macro
        structural = set()
        for o, c in groups.items():
            if depth[o] != 0 or o in proc_lines:
                continue
            body = range(o + 1, c)
            if any(info[j]['segment'] is not None or info[j]['proc'] or info[j]['endproc'] or
                   (info[j]['label'] and not info[j]['label'].startswith('@')) or info[j]['directive'] == '.macro'
                   for j in body):
                structural.add(o)
        boundary = set()
        for i, rec in enumerate(info):
            if i in proc_lines:
                continue
            if rec['segment'] is not None and depth[i] == 0:
                boundary.add(i)
            if rec['directive'] in ('.macro', '.endmacro') or rec['in_macro']:
                boundary.add(i)
        for o in structural:
            c = groups[o]
            boundary.update(range(o, c + 1))
            for j in range(o + 1, c):
                if not (info[j]['segment'] is not None or info[j]['else'] or info[j]['ifopen'] or info[j]['ifclose']):
                    boundary.discard(j)
        self.boundary = boundary
        self.depth = depth
        self.seg_normal = self.segment_view(set())
        self.seg_hw = self.segment_view({'SPRHW'})
        self.active_normal = self.active_lines(set())
        # --- block starts
        starts = []
        for i, rec in enumerate(info):
            if i in boundary or (i in proc_lines and not rec['proc']):
                continue
            if rec['proc']:
                starts.append((i, rec['proc'], 'proc'))
            elif rec['label'] and not rec['label'].startswith('@') and i not in proc_lines:
                starts.append((i, rec['label'], 'label'))
            elif rec['macro_inv'] and self.macro_defines_proc(rec['macro_inv']):
                starts.append((i, rec['macro_args'].split(',')[0].strip(), 'macroproc'))
        # --- regions: maximal runs of non-boundary lines
        regions = []
        i = 0
        while i < n:
            if i in boundary:
                i += 1
                continue
            j = i
            while j < n and j not in boundary:
                j += 1
            regions.append((i, j - 1))
            i = j
        self.blocks = []
        self.regions = []
        start_lines = {s[0]: s for s in starts}
        for ri, (r0, r1) in enumerate(regions):
            base = depth[r0]
            rstarts = [s for s in starts if r0 <= s[0] <= r1 and depth[s[0]] == base]
            cut = []
            for (ln, name, kind) in rstarts:
                k = ln
                while k - 1 >= r0 and info[k - 1]['comment_only'] and (k - 1) not in start_lines:
                    k -= 1
                cut.append(k)
            region = {'id': ri, 'file': self.name, 'first': r0, 'last': r1, 'blocks': [],
                      'prefix': (r0, (cut[0] - 1) if cut else r1),
                      'context': (self.seg_normal[r0], self.seg_hw[r0])}
            for bi, (ln, name, kind) in enumerate(rstarts):
                b0 = cut[bi]
                b1 = (cut[bi + 1] - 1) if bi + 1 < len(rstarts) else r1
                blk = {'file': self.name, 'region': ri, 'index_in_region': bi, 'label_line': ln, 'name': name,
                       'kind': kind, 'first': b0, 'last': b1, 'tied_next': [], 'tied_prev': []}
                self.blocks.append(blk)
                region['blocks'].append(blk)
            self.regions.append(region)
        self.anon_check()

    def macro_defines_proc(self, name):
        return self.macro_kinds.get(name) == 'code' and name in ('ENTRADA',)

    def anon_check(self):
        """Tie a block to its neighbour when a `:+`/`:-` reference of it resolves to an unnamed label outside it
        (ca65's unnamed labels are positional: a moved block would silently bind to another one).  Both views
        (all lines; only the lines active in the normal build) are checked."""
        info = self.info
        anon_all = [i for i, r in enumerate(info) if r['anon']]
        anon_act = [i for i in anon_all if i in self.active_normal]
        blk_of = {}
        for b in self.blocks:
            for i in range(b['first'], b['last'] + 1):
                blk_of[i] = b
        for i, raw in enumerate(self.lines):
            t = strip_comment(raw)
            if i not in blk_of:
                continue
            for m in re.finditer(r':([+-]+)', t):
                if m.start() > 0 and (t[m.start() - 1].isalnum() or t[m.start() - 1] == '_'):
                    continue
                seq = m.group(1)
                nth = len(seq)
                for lst in (anon_all, anon_act):
                    if seq[0] == '+':
                        cands = [a for a in lst if a > i]
                        tgt = cands[nth - 1] if len(cands) >= nth else None
                    else:
                        cands = [a for a in lst if a < i]
                        tgt = cands[-nth] if len(cands) >= nth else None
                    if tgt is None:
                        continue
                    b = blk_of[i]
                    tb = blk_of.get(tgt)
                    if tb is not b:
                        note = 'unnamed label %s at line %d -> line %d' % (':' + seq, i + 1, tgt + 1)
                        if tb is not None and tb['region'] == b['region']:
                            if tb['index_in_region'] == b['index_in_region'] + 1:
                                b['tied_next'].append(note)
                            elif tb['index_in_region'] == b['index_in_region'] - 1:
                                b['tied_prev'].append(note)
                            else:
                                b['immovable'] = note + ' (not a neighbour)'
                        else:
                            b['immovable'] = note + ' (another region)'

    def anon_refs(self, defined):
        """Unnamed-label references of this file resolved under a view (None: every line; a set: the lines active
        with those symbols defined): {'by_ref': ref_line -> target_line, 'by_target': target_line -> [ref lines]}."""
        act = None if defined is None else self.active_lines(defined)
        labels = [i for i, r in enumerate(self.info) if r['anon'] and (act is None or i in act)]
        by_ref, by_target = {}, defaultdict(list)
        for i, raw in enumerate(self.lines):
            if act is not None and i not in act:
                continue
            t = strip_comment(raw)
            for m in re.finditer(r':([+-]+)', t):
                if m.start() > 0 and (t[m.start() - 1].isalnum() or t[m.start() - 1] == '_'):
                    continue
                seq = m.group(1)
                nth = len(seq)
                if seq[0] == '+':
                    cands = [a for a in labels if a > i]
                    tgt = cands[nth - 1] if len(cands) >= nth else None
                else:
                    cands = [a for a in labels if a < i]
                    tgt = cands[-nth] if len(cands) >= nth else None
                if tgt is not None:
                    by_ref[i] = tgt
                    by_target[tgt].append(i)
        return {'by_ref': by_ref, 'by_target': dict(by_target)}

    def segment_view(self, defined):
        """The segment name in effect at each line under the given defined symbols (default CODE)."""
        act = self.active_lines(defined)
        seg, out = 'CODE', []
        for i, raw in enumerate(self.lines):
            if i in act and self.info[i]['segment'] is not None:
                seg = self.info[i]['segment']
            out.append(seg)
        return out

    def active_lines(self, defined):
        """Line indexes active under the given set of defined symbols (.ifdef/.ifndef only; other .if kinds are
        taken as active)."""
        act = set()
        stack = []
        cur = True
        low_def = {x.lower() for x in defined}
        for i, raw in enumerate(self.lines):
            s = strip_comment(raw).strip().lower()
            tok = s.split()[0] if s else ''
            if tok in IF_OPEN:
                if tok == '.ifdef':
                    cond = s.split()[1] in low_def if len(s.split()) > 1 else False
                elif tok == '.ifndef':
                    cond = s.split()[1] not in low_def if len(s.split()) > 1 else True
                else:
                    cond = True
                stack.append((cur, cond))
                cur = cur and cond
                continue
            if tok == '.else':
                before, cond = stack[-1]
                cur = before and not cond
                stack[-1] = (before, not cond)
                continue
            if tok == '.endif':
                before, cond = stack.pop()
                cur = before
                continue
            if cur:
                act.add(i)
        return act


def file_order(srcdir):
    """Every source that a build may link (the map gives the real order); the platform files last."""
    jf = sorted(f for f in os.listdir(os.path.join(srcdir, 'juego_final')) if f.endswith('.s'))
    pf = sorted(f for f in os.listdir(os.path.join(srcdir, 'plataforma')) if f.endswith('.s'))
    return [('juego_final', f) for f in jf] + [('plataforma', f) for f in pf]


# ------------------------------------------------------------------------------------------------------------
class Model:
    """The normal build's blocks with their addresses and instructions, the chains and the zones."""

    def __init__(self, srcdir, build, prof=None):
        self.srcdir = srcdir
        self.build = build
        self.prof = prof
        self.files = OrderedDict()
        mk = build.macro_kinds
        mods = [m for m in build.modules if 'CODE' in build.modules[m]]
        mods.sort(key=lambda m: build.modules[m]['CODE'][0])
        where = {fn: sub for sub, fn in file_order(srcdir)}
        self.link_order = []
        for m in mods:
            fn = m[:-2] + '.s'
            if fn not in where:
                raise SystemExit('module %s of the map has no source in %s' % (m, srcdir))
            self.files[fn] = SourceFile(os.path.join(srcdir, where[fn], fn), fn, mk)
            self.link_order.append(fn)
        for fn, sub in where.items():
            if fn not in self.files:
                self.files[fn] = SourceFile(os.path.join(srcdir, sub, fn), fn, mk)
        self.attach_addresses()

    def attach_addresses(self):
        b = self.build
        items_by_line = defaultdict(list)
        for a, sz, fname, ln, text in b.items:
            items_by_line[(fname, ln)].append((a, sz))
        self.blocks = []
        self.block_of_addr = {}
        for fn, sf in self.files.items():
            # a block without bytes in this build (a label aliasing the next entry, SPRHW-only code, a comment
            # tail) is folded into the next block of its region (the last one into the previous): it keeps its place
            for reg in sf.regions:
                keep = []
                pending = []
                for blk in reg['blocks']:
                    has = any(items_by_line.get((fn, ln + 1)) for ln in range(blk['first'], blk['last'] + 1))
                    if not has:
                        pending.append(blk)
                        continue
                    if pending:
                        blk['first'] = pending[0]['first']
                        blk['folded'] = [b['name'] for b in pending]
                        pending = []
                    keep.append(blk)
                if pending:
                    if keep:
                        keep[-1]['last'] = pending[-1]['last']
                        keep[-1].setdefault('folded', []).extend(b['name'] for b in pending)
                    else:
                        keep.extend(pending)          # a region without code: untouched
                for i, blk in enumerate(keep):
                    blk['index_in_region'] = i
                reg['blocks'] = keep
            sf.blocks = [blk for reg in sf.regions for blk in reg['blocks']]
            for blk in sf.blocks:
                addrs = []
                for ln in range(blk['first'], blk['last'] + 1):
                    addrs.extend(items_by_line.get((fn, ln + 1), []))
                if not addrs:
                    blk['lo'] = blk['hi'] = None
                    blk['instrs'] = []
                    blk['data_items'] = []
                    continue
                addrs.sort()
                lo, hi = addrs[0][0], max(a + s for a, s in addrs)
                blk['lo'], blk['hi'] = lo, hi
                blk['contiguous'] = (sum(s for a, s in addrs) == hi - lo)
                blk['instrs'] = [i for i in b.instrs if lo <= i['addr'] < hi]
                blk['data_items'] = [d for d in b.data if lo <= d['addr'] < hi]
                label_items = items_by_line.get((fn, blk['label_line'] + 1), [])
                blk['entry'] = min(a for a, s in label_items) if label_items else lo
                for i in blk['instrs']:
                    self.block_of_addr[i['addr']] = blk
                for d in blk['data_items']:
                    for o in range(d['size']):
                        self.block_of_addr[d['addr'] + o] = blk
                self.blocks.append(blk)
        for fn, sf in self.files.items():
            for blk in sf.blocks:
                blk['tied_next'], blk['tied_prev'] = [], []
                blk.pop('immovable', None)
            sf.anon_check()
        for blk in self.blocks:
            last = blk['instrs'][-1] if blk['instrs'] else None
            ends_in_data = bool(blk['data_items']) and (last is None or blk['data_items'][-1]['addr'] > last['addr'])
            blk['last_instr'] = last
            blk['ends_in_data'] = ends_in_data
            blk['falls_through'] = (last is not None and not ends_in_data and last['mn'] not in TERMINATORS)
            blk['bytes'] = blk['hi'] - blk['lo']
            blk['tail_at_base_depth'] = (last is not None and self.files[blk['file']].depth[last['line'] - 1] ==
                                         self.files[blk['file']].depth[blk['label_line']])
        self.entry_block = {blk['entry']: blk for blk in self.blocks}
        # a relative branch into another block needs its distance kept: every block between the two (inclusive)
        # is tied to the next, so the group moves as one; across regions the blocks cannot move at all
        for blk in self.blocks:
            for ins in blk['instrs']:
                if not ins['branch']:
                    continue
                tb = self.block_of_addr.get(ins['target'])
                if tb is None or tb is blk:
                    continue
                note = 'branch %s at line %d -> %s (line %d)' % (ins['mn'].lower(), ins['line'], tb['name'], tb['label_line'] + 1)
                if tb['file'] != blk['file'] or tb['region'] != blk['region']:
                    blk['immovable'] = note + ' (another region)'
                    tb['immovable'] = note + ' (another region)'
                    continue
                reg = self.files[blk['file']].regions[blk['region']]
                pres = [bk for bk in reg['blocks'] if bk.get('lo') is not None]
                i, j = sorted((pres.index(blk), pres.index(tb)))
                for k in range(i, j):
                    pres[k]['tied_next'].append(note)
        # zones: regions of a file with the same (normal, SPRHW) segment context
        for fn, sf in self.files.items():
            for reg in sf.regions:
                reg['present'] = [bk for bk in reg['blocks'] if bk.get('lo') is not None]
                reg['zone'] = (fn,) + reg['context']
        # chains: consecutive blocks of a region tied hard (unnamed labels, or a fall-through whose count is unknown)
        self.chains = []
        for fn, sf in self.files.items():
            for reg in sf.regions:
                blks = reg['present']
                i = 0
                while i < len(blks):
                    ch = [blks[i]]
                    while i + 1 < len(blks) and self.hard_glue(blks[i], blks[i + 1]):
                        i += 1
                        ch.append(blks[i])
                    i += 1
                    c = {'file': fn, 'region': reg['id'], 'zone': reg['zone'], 'blocks': ch, 'index': len(self.chains),
                         'immovable': any(bk.get('immovable') for bk in ch)}
                    for bk in ch:
                        bk['chain'] = c
                    self.chains.append(c)
                reg['chains'] = [c for c in self.chains if c['file'] == fn and c['region'] == reg['id']]

    def fall_count(self, blk):
        """Executions per session of the fall-through from blk's last instruction into the next block, and how."""
        last = blk['last_instr']
        if self.prof is None:
            return None, 'no profile'
        m, how = map_to_prueba(self, self.prof, last)
        if m is None:
            return None, how
        if m['branch'] and last['branch']:
            bc, why = self.prof.branch_counts(m)
            if bc is None:
                return None, how + '; ' + why
            return [nt for tk, nt in bc], how + '; not-taken count: ' + why
        e, how2 = executions(self, self.prof, last)
        return e, how2

    def hard_glue(self, a, b):
        if a['tied_next'] or b['tied_prev']:
            a.setdefault('glue', []).append('tied: %s' % '; '.join(a['tied_next'] + b['tied_prev']))
            return True
        if a['falls_through']:
            e, how = self.fall_count(a)
            a['fall_exec'] = e
            a['fall_how'] = how
            sf = self.files[a['file']]
            if e is None or not a['tail_at_base_depth'] or last_code_line_of_block(sf, a) != a['last_instr']['line'] - 1:
                a.setdefault('glue', []).append('falls through into %s (%s)' % (
                    b['name'], 'count unknown: ' + how if e is None else 'conditional code or data after the last instruction'))
                return True
            a.setdefault('glue', []).append('falls through into %s (soft: %.3f passes/frame)' % (b['name'], mean_pf(self.prof, e)))
            return False
        return False


def mean_pf(prof, per_session):
    vals = [n / s['frames'] for n, s in zip(per_session, prof.sessions)]
    k = min(SESSIONS_MEAN, len(vals))
    return sum(vals[:k]) / k


def nokeys_pf(prof, per_session):
    vals = [n / s['frames'] for n, s in zip(per_session, prof.sessions)]
    return vals[SESSIONS_MEAN] if len(vals) > SESSIONS_MEAN else None


# ------------------------------------------------------------------------------------------------------------
class Profile:
    """Per-address cycles of the host's sessions on the checked build -> executions of each instruction."""

    def __init__(self, specs, prueba):
        self.sessions = []
        for spec in specs:
            name, rest = spec.split('=', 1)
            path, frames = rest.rsplit(':', 1)
            cyc = {}
            with open(path, encoding='utf-8') as f:
                for l in f:
                    p = l.split()
                    if len(p) >= 2:
                        cyc[int(p[0], 16)] = int(p[1])
            self.sessions.append({'name': name, 'frames': int(frames), 'cycles': cyc, 'path': path})
        self.prueba = prueba

    def exec_exact(self, ins):
        """Executions per session of a fixed-cost instruction of the checked build, or None."""
        if ins['branch'] or ins['cross']:
            return None
        return [s['cycles'].get(ins['addr'], 0) // ins['cycles'] for s in self.sessions]

    def branch_counts(self, ins):
        """(taken, not_taken) per session of a checked-build branch, derived from the predecessor when that is an
        exact, non-jumping instruction and nothing else enters the branch; else (None, why)."""
        b = self.prueba
        prev = b.prev_instr(ins)
        if prev is None or prev['branch'] or prev['mn'] in ('JMP', 'JSR', 'RTS', 'RTI', 'BRK'):
            return None, 'predecessor not straight-line'
        e = self.exec_exact(prev)
        if e is None:
            return None, 'predecessor cost not fixed'
        if ins['addr'] in b.jump_targets or ins['addr'] in b.labels_at:
            return None, 'other entries into the branch'
        out = []
        for s, E in zip(self.sessions, e):
            c = s['cycles'].get(ins['addr'], 0)
            extra = CY_BR_TK + ins['tk_cross'] - CY_BR_NT
            tk = (c - CY_BR_NT * E) // extra
            nt = E - tk
            if tk < 0 or nt < 0:
                return None, 'inconsistent counts'
            out.append((tk, nt))
        return out, 'taken/not taken derived from the predecessor $%04X (%s, %d cycles each, exact) and the branch cycles' % (
            prev['addr'], prev['mn'], prev['cycles'])


def map_to_prueba(model, prof, ins):
    """The checked-build instruction with the same (file, line, k), or the first of its line for a macro line."""
    pb = prof.prueba
    key = (ins['file'], ins['line'], ins['k'])
    m = pb.by_key.get(key)
    if m is not None and m['opc'] == ins['opc']:
        return m, 'the same instruction in the checked build at $%04X' % m['addr']
    m0 = pb.by_key.get((ins['file'], ins['line'], 0))
    if m0 is not None:
        return m0, 'the first instruction of the same source line in the checked build at $%04X (%s)' % (m0['addr'], m0['mn'])
    return None, 'not in the checked build (the platform layer is replaced there: not profiled)'


def executions(model, prof, ins):
    """Executions per session of a normal-build instruction: (list, how) or (None, why)."""
    m, how = map_to_prueba(model, prof, ins)
    if m is None:
        return None, how
    e = prof.exec_exact(m)
    if e is not None:
        return e, how + '; exact: its cycles / %d' % m['cycles']
    if m['branch']:
        bc, why = prof.branch_counts(m)
        if bc is not None:
            return [tk + nt for tk, nt in bc], how + '; ' + why
    prev = prof.prueba.prev_instr(m)
    if prev is not None and not prev['branch'] and prev['mn'] not in ('JMP', 'JSR', 'RTS', 'RTI', 'BRK') \
            and m['addr'] not in prof.prueba.jump_targets and m['addr'] not in prof.prueba.labels_at:
        e = prof.exec_exact(prev)
        if e is not None:
            return e, how + '; from its straight-line predecessor $%04X (exact)' % prev['addr']
    return None, how + '; not derivable (variable cost, no exact neighbour)'


# ------------------------------------------------------------------------------------------------------------
def code_lines_between(sf, a, b):
    """Source lines strictly between a and b (0-based) that are not comment-only: [] when the two are adjacent in
    every build (no conditional assembly, data or code can come between them)."""
    return [i for i in range(a + 1, b) if not sf.info[i]['comment_only']]


def last_code_line_of_block(sf, blk):
    """The last line of the block that is not comment-only nor `.endproc`."""
    for i in range(blk['last'], blk['first'] - 1, -1):
        r = sf.info[i]
        if r['comment_only'] or r['endproc']:
            continue
        return i
    return None


def label_adjacent_to(sf, line):
    """True when the line's label (on it, or on the nearest label-only line above with only comments between) is
    adjacent to the line in every build."""
    r = sf.info[line]
    if r['label'] or r['anon']:
        return True
    j = line - 1
    while j >= 0 and sf.info[j]['comment_only']:
        j -= 1
    if j < 0:
        return False
    rj = sf.info[j]
    return (rj['label'] or rj['anon']) and rj['mnemonic'] is None and not rj['data'] and rj['macro_inv'] is None


def stack_tricks(blk):
    return [i['mn'] for i in blk['instrs'] if i['mn'] in ('PLA', 'TSX', 'TXS')]


def name_of(b, a):
    if a in b.labels_at:
        names = sorted(b.labels_at[a], key=lambda n: (n.startswith('@'), len(n), n))
        return names[0]
    return '$%04X' % a


def source_instr_text(ins):
    t = strip_comment(ins['text']).strip()
    t = re.sub(r'^(@?[A-Za-z_][A-Za-z0-9_]*:|:)\s*', '', t)
    return re.sub(r'\s+', ' ', t)


def find_candidates(model, prof, inline_routines):
    b = model.build
    cands = []

    def exe(ins):
        return executions(model, prof, ins)

    for ins in b.instrs:
        blk = model.block_of_addr.get(ins['addr'])
        if blk is None:
            continue
        is_last = blk['last_instr'] is ins and not blk['ends_in_data']
        # (a) tail jmp
        if ins['mn'] == 'JMP' and ins['mode'] == 'abs' and blk['last_instr'] is ins:
            tgt = ins['target']
            tb = model.entry_block.get(tgt)
            inside = model.block_of_addr.get(tgt)
            e, how = exe(ins)
            c = {'kind': 'tail_jmp', 'ins': ins, 'block': blk, 'target': tgt, 'target_block': tb,
                 'cycles_per_exec': CY_JMP, 'bytes': -3, 'exec': e, 'how': how, 'cite': CITE['JMP'],
                 'tail': is_last, 'adjacent': (tgt == ins['addr'] + 3)}
            if inside is blk:
                continue                                            # a loop back into the routine itself
            if tb is None:
                c['impossible'] = 'the target %s is inside %s, not a routine entry' % (
                    name_of(b, tgt), inside['name'] if inside else '?')
            elif blk['ends_in_data']:
                c['impossible'] = 'data follows the jmp inside the block (%s): it cannot fall through' % blk['name']
            elif not blk['tail_at_base_depth']:
                c['impossible'] = 'the jmp is inside a conditional assembly block'
            elif last_code_line_of_block(model.files[blk['file']], blk) != ins['line'] - 1:
                c['impossible'] = 'source lines follow the jmp inside the block (conditional code or data in another build)'
            cands.append(c)
        # (b) jsr X ; rts
        if ins['mn'] == 'JSR':
            nxt = b.next_instr(ins)
            if nxt is not None and nxt['mn'] == 'RTS' and model.block_of_addr.get(nxt['addr']) is blk \
                    and ins['k'] == 0 and nxt['k'] == 0:
                tgt = ins['target']
                tb = model.entry_block.get(tgt)
                e, how = exe(ins)
                rts_referenced = nxt['addr'] in b.jump_targets or nxt['addr'] in b.labels_at
                tname = name_of(b, tgt)
                rts_is_last = blk['last_instr'] is nxt and not blk['ends_in_data']
                c = {'kind': 'tail_jsr_rts', 'ins': ins, 'block': blk, 'target': tgt, 'target_block': tb,
                     'cycles_per_exec': CY_JSR + CY_RTS - CY_JMP, 'bytes': 0 if rts_referenced else -1,
                     'exec': e, 'how': how, 'cite': '%s, %s, %s' % (CITE['JSR'], CITE['RTS'], CITE['JMP']),
                     'rts': nxt, 'rts_referenced': rts_referenced,
                     'tail': rts_is_last and not rts_referenced, 'adjacent': False}
                tblk = model.block_of_addr.get(tgt)
                tricks = stack_tricks(tblk) if tblk else []
                sf = model.files[blk['file']]
                if code_lines_between(sf, ins['line'] - 1, nxt['line'] - 1):
                    c['impossible'] = 'source lines between the jsr and the rts (conditional code in another build)'
                elif rts_is_last and last_code_line_of_block(sf, blk) != nxt['line'] - 1:
                    c['tail'] = False
                if c.get('impossible'):
                    pass
                elif tname in inline_routines:
                    c['impossible'] = 'the target %s reads the bytes after its call (INLINE)' % tname
                elif tricks:
                    c['impossible'] = 'the target %s touches the stack pointer / return address (%s)' % (tname, ' '.join(tricks))
                elif tblk is None:
                    c['impossible'] = 'the target %s is outside the decoded code' % tname
                cands.append(c)
        # (c) jmp / branch to an rts
        if (ins['mn'] == 'JMP' and ins['mode'] == 'abs') or ins['branch']:
            t = b.by_addr.get(ins['target'])
            if t is not None and t['mn'] == 'RTS':
                sf = model.files[blk['file']]
                mp, _ = map_to_prueba(model, prof, ins)
                tp = prof.prueba.by_addr.get(mp['target']) if mp is not None and mp['target'] is not None else None
                safe = (t['k'] == 0 and label_adjacent_to(sf, t['line'] - 1) and
                        (mp is None or (tp is not None and tp['mn'] == 'RTS')))
                if not safe:
                    continue
                if ins['mn'] == 'JMP':
                    e, how = exe(ins)
                    cands.append({'kind': 'jmp_to_rts', 'ins': ins, 'block': blk, 'target': ins['target'],
                                  'target_block': None, 'cycles_per_exec': CY_JMP, 'bytes': -2, 'exec': e,
                                  'how': how, 'cite': '%s (jmp L with L: rts -> rts: the rts costs the same)' % CITE['JMP']})
                else:
                    m, how = map_to_prueba(model, prof, ins)
                    bc, why = (None, how) if m is None or not m['branch'] else prof.branch_counts(m)
                    c = {'kind': 'branch_to_rts', 'ins': ins, 'block': blk, 'target': ins['target'],
                         'target_block': None, 'bytes': +1, 'cite': CITE['BR'] + ' and ' + CITE['RTS']}
                    if bc is not None:
                        gain = [tk * (1 + ins['tk_cross']) - nt for tk, nt in bc]
                        c['exec'] = [tk + nt for tk, nt in bc]
                        c['net'] = gain
                        c['how'] = how + '; ' + why + '; net = taken*(1+page_cross) - not_taken'
                        c['cycles_per_exec'] = (sum(gain) / sum(c['exec'])) if sum(c['exec']) else 0
                    else:
                        c['exec'] = None
                        c['how'] = how + '; ' + why
                        c['cycles_per_exec'] = 0
                    cands.append(c)
        # (d) branch over a jmp
        if ins['branch']:
            j = b.next_instr(ins)
            if j is not None and j['mn'] == 'JMP' and j['mode'] == 'abs' and ins['target'] == j['addr'] + 3 \
                    and model.block_of_addr.get(j['addr']) is blk and ins['k'] == 0 and j['k'] == 0:
                X = j['target']
                disp = X - (ins['addr'] + 2)
                inrange = -128 <= disp <= 127
                # the checked build (-D PRUEBA) assembles the same lines with extra bytes between them: the new
                # branch must be in range there too (found 2026-10-29: la_busca `beq :+ / jmp sig_p` at 147 bytes
                # in the checked build); a line not matched exactly in the checked build is not proven in range
                m_ins, _ = map_to_prueba(model, prof, ins)
                m_jmp, _ = map_to_prueba(model, prof, j)
                disp_p = None
                if m_ins is not None or m_jmp is not None:
                    if m_ins is not None and m_jmp is not None and m_ins['opc'] == ins['opc'] and m_jmp['mn'] == 'JMP' \
                            and m_jmp.get('target') is not None:
                        disp_p = m_jmp['target'] - (m_ins['addr'] + 2)
                        if not (-128 <= disp_p <= 127):
                            inrange = False
                    else:
                        inrange = False
                sf = model.files[blk['file']]
                after = b.by_addr.get(j['addr'] + 3)
                if code_lines_between(sf, ins['line'] - 1, j['line'] - 1) or after is None or after['k'] != 0 \
                        or code_lines_between(sf, j['line'] - 1, after['line'] - 1) or not label_adjacent_to(sf, after['line'] - 1):
                    continue
                m, how = map_to_prueba(model, prof, ins)
                bc, why = (None, how) if m is None or not m['branch'] else prof.branch_counts(m)
                ej, howj = exe(j)
                c = {'kind': 'branch_over_jmp', 'ins': ins, 'jmp': j, 'block': blk, 'target': X, 'target_block': None,
                     'bytes': -3, 'cite': CITE['BR'] + ' and ' + CITE['JMP'], 'in_range': inrange, 'disp': disp}
                new_cross = 1 if ((X >> 8) != ((ins['addr'] + 2) >> 8)) else 0
                if bc is not None:
                    gain = [nt * (CY_BR_NT + CY_JMP - CY_BR_TK - new_cross) + tk * (CY_BR_TK + ins['tk_cross'] - CY_BR_NT)
                            for tk, nt in bc]
                    c['exec'] = [tk + nt for tk, nt in bc]
                    c['net'] = gain
                    c['cycles_per_exec'] = (sum(gain) / sum(c['exec'])) if sum(c['exec']) else 0
                    c['how'] = how + '; ' + why + '; net = not_taken*(5-3-new_cross) + taken*(1+old_cross)'
                elif ej is not None:
                    c['exec'] = ej
                    c['net'] = [n * (CY_BR_NT + CY_JMP - CY_BR_TK - new_cross) for n in ej]
                    c['cycles_per_exec'] = CY_BR_NT + CY_JMP - CY_BR_TK - new_cross
                    c['how'] = 'only the jmp path counted (%s); the branch-taken path saves 1 more each' % howj
                else:
                    c['exec'] = None
                    c['cycles_per_exec'] = 2 - new_cross
                    c['how'] = howj
                if not inrange:
                    c['impossible'] = 'the target %s is %+d bytes away: out of branch range' % (name_of(b, X), disp) + \
                        ('' if disp_p is None else ' (%+d in the checked build)' % disp_p)
                cands.append(c)
        # (e) jmp to the next instruction (inside a block: a tail jmp to the adjacent routine is listed under (a))
        if ins['mn'] == 'JMP' and ins['mode'] == 'abs' and ins['target'] == ins['addr'] + 3 and blk['last_instr'] is not ins:
            e, how = exe(ins)
            cands.append({'kind': 'jmp_to_next', 'ins': ins, 'block': blk, 'target': ins['target'], 'target_block': None,
                          'cycles_per_exec': CY_JMP, 'bytes': -3, 'exec': e, 'how': how, 'cite': CITE['JMP']})
        # (f) jmp / jsr to a jmp
        if ins['mn'] in ('JMP', 'JSR') and ins['mode'] == 'abs':
            t = b.by_addr.get(ins['target'])
            if t is not None and t['mn'] == 'JMP' and t['mode'] == 'abs' and t['target'] != ins['target']:
                e, how = exe(ins)
                selfmod = [s for s in b.instrs if s['mn'] in ('STA', 'STX', 'STY', 'INC', 'DEC')
                           and s['target'] in (t['addr'] + 1, t['addr'] + 2)]
                c = {'kind': 'jmp_chain', 'ins': ins, 'block': blk, 'target': ins['target'], 'target_block': None,
                     'via': t, 'cycles_per_exec': CY_JMP, 'bytes': 0, 'exec': e, 'how': how,
                     'cite': CITE['JMP'] + ' (the intermediate jmp is skipped)'}
                if selfmod:
                    c['impossible'] = 'the intermediate jmp at $%04X is written by code (self-modified)' % t['addr']
                cands.append(c)
    for c in cands:
        e = c['exec']
        c['per_frame'] = mean_pf(prof, e) if e is not None else None
        c['nokeys_pf'] = nokeys_pf(prof, e) if e is not None else None
        c['executed'] = bool(e) and any(n > 0 for n in e)
        if c['kind'] in ('branch_to_rts', 'branch_over_jmp') and c.get('net') is not None:
            c['saved_pf'] = mean_pf(prof, c['net'])
            c['saved_nokeys'] = nokeys_pf(prof, c['net'])
        elif c['per_frame'] is not None:
            c['saved_pf'] = c['per_frame'] * c['cycles_per_exec']
            c['saved_nokeys'] = (c['nokeys_pf'] * c['cycles_per_exec']) if c['nokeys_pf'] is not None else None
        else:
            c['saved_pf'] = None
            c['saved_nokeys'] = None
    return cands


# ------------------------------------------------------------------------------------------------------------
# placement: a maximum-weight path cover of the chains of each zone
def plan_placement(model, cands):
    """Nodes: chains.  Out-edges (one per chain at most): its last block's tail jmp (a candidate) or its soft
    fall-through into the next block (weight = 3 cycles x passes, the jmp that breaking it would cost).  Every
    target keeps its heaviest incoming edge; a cycle is broken at its lightest edge."""
    out_edge = {}
    # existing soft fall-throughs
    for fn, sf in model.files.items():
        for reg in sf.regions:
            pres = reg['present']
            for i in range(len(pres) - 1):
                a, b2 = pres[i], pres[i + 1]
                if a['chain'] is b2['chain'] or not a['falls_through']:
                    continue
                w = mean_pf(model.prof, a['fall_exec']) * CY_JMP
                out_edge[a['chain']['index']] = {'kind': 'existing', 'src': a['chain'], 'tgt': b2['chain'], 'w': w,
                                                 'src_block': a, 'tgt_block': b2, 'cand': None,
                                                 'nokeys': (nokeys_pf(model.prof, a['fall_exec']) or 0) * CY_JMP}
    # tail jumps
    for c in cands:
        if c['kind'] not in ('tail_jmp', 'tail_jsr_rts') or c.get('impossible') or not c.get('tail'):
            continue
        tb = c['target_block']
        if tb is None:
            c['placement_note'] = 'the target is not a routine entry'
            continue
        src_chain = c['block']['chain']
        tgt_chain = tb['chain']
        if src_chain['blocks'][-1] is not c['block']:
            c['placement_note'] = 'the routine is tied to the next one (%s)' % '; '.join(c['block'].get('glue', []))
            continue
        if tgt_chain['blocks'][0] is not tb:
            prev = tgt_chain['blocks'][tgt_chain['blocks'].index(tb) - 1]
            c['placement_note'] = 'the target %s is tied after %s (%s)' % (tb['name'], prev['name'], '; '.join(prev.get('glue', [])))
            continue
        if src_chain is tgt_chain:
            c['placement_note'] = 'the target is the routine itself (a loop)'
            continue
        if src_chain.get('immovable') or tgt_chain.get('immovable'):
            c['placement_note'] = 'a routine cannot move: ' + '; '.join(
                bk.get('immovable', '') for ch in (src_chain, tgt_chain) for bk in ch['blocks'] if bk.get('immovable'))
            continue
        w = (c['per_frame'] or 0.0) * CY_JMP
        nk = (c['nokeys_pf'] or 0.0) * CY_JMP
        if c['exec'] is None:
            c['placement_note'] = 'possible, not applied: not profiled (%s)' % c['how']
            continue
        if w == 0 and nk == 0:
            c['placement_note'] = 'possible, not applied: never executed in the profiled sessions (3 bytes only)'
            continue
        if src_chain['zone'] == tgt_chain['zone']:
            kind = 'zone'
        else:
            if src_chain['file'] == tgt_chain['file']:
                c['placement_note'] = 'the target lives in another segment context of the same file (%s vs %s): a SPRHW segment' % (
                    '/'.join(src_chain['zone'][1:]), '/'.join(tgt_chain['zone'][1:]))
                continue
            lo = model.link_order
            if src_chain['file'] not in lo or tgt_chain['file'] not in lo:
                c['placement_note'] = 'a file is not in the CODE link order'
                continue
            fi, ti = lo.index(src_chain['file']), lo.index(tgt_chain['file'])
            if ti != fi + 1:
                c['placement_note'] = 'the target is in another file (%s -> %s), not the next object in the link order' % (
                    src_chain['file'], tgt_chain['file'])
                continue
            if src_chain['zone'] != last_code_zone(model, src_chain['file']) or tgt_chain['zone'] != first_code_zone(model, tgt_chain['file']):
                c['placement_note'] = 'the file boundary %s -> %s is between other segment contexts' % (src_chain['file'], tgt_chain['file'])
                continue
            kind = 'boundary'
        e = {'kind': kind, 'src': src_chain, 'tgt': tgt_chain, 'w': w, 'nokeys': nk, 'cand': c,
             'src_block': c['block'], 'tgt_block': tb}
        assert src_chain['index'] not in out_edge           # a chain ending in a jmp has no fall-through
        out_edge[src_chain['index']] = e
    # the heaviest incoming edge per target; boundaries: one per file pair
    in_edges = defaultdict(list)
    for e in out_edge.values():
        in_edges[e['tgt']['index']].append(e)
    chosen, rejected = {}, []
    for t, lst in in_edges.items():
        lst.sort(key=lambda e: (-e['w'], -e['nokeys'], 0 if e['kind'] == 'existing' else 1, e['src']['index']))
        chosen[t] = lst[0]
        for e in lst[1:]:
            e['reject'] = 'the target %s keeps %s before it (%.3f cycles/frame against %.3f)' % (
                lst[0]['tgt_block']['name'], lst[0]['src_block']['name'], lst[0]['w'], e['w'])
            rejected.append(e)
    used = {}
    for t in sorted(chosen):
        e = chosen[t]
        if e['kind'] == 'boundary':
            key = (e['src']['file'], e['tgt']['file'])
            if key in used and used[key]['w'] >= e['w']:
                e['reject'] = 'the file boundary is taken by %s -> %s' % (used[key]['src_block']['name'], used[key]['tgt_block']['name'])
                rejected.append(e)
                del chosen[t]
                continue
            if key in used:
                old = used[key]
                old['reject'] = 'the file boundary is taken by %s -> %s' % (e['src_block']['name'], e['tgt_block']['name'])
                rejected.append(old)
                del chosen[old['tgt']['index']]
            used[key] = e
    # cycles: each chain has one out-edge, so a cycle is a ring; drop its lightest edge
    changed = True
    while changed:
        changed = False
        succ = {e['src']['index']: e for e in chosen.values()}
        seen = {}
        for start in sorted(succ):
            if start in seen:
                continue
            path = []
            x = start
            while x in succ and x not in seen:
                seen[x] = start
                path.append(x)
                x = succ[x]['tgt']['index']
            if x in seen and seen[x] == start and x in path:
                ring = path[path.index(x):]
                worst = min((succ[i] for i in ring), key=lambda e: (e['w'], e['nokeys'], -e['src']['index']))
                worst['reject'] = 'would close a ring of fall-throughs'
                rejected.append(worst)
                del chosen[worst['tgt']['index']]
                changed = True
                break
    chosen_list = sorted(chosen.values(), key=lambda e: (-e['w'], e['src']['index']))
    inserts = [e for e in out_edge.values() if e['kind'] == 'existing' and chosen.get(e['tgt']['index']) is not e]
    inserts.sort(key=lambda e: e['src']['index'])
    # the order per region: paths; a path lives in the region of its head
    succ = {e['src']['index']: e for e in chosen.values()}
    pred = {e['tgt']['index']: e for e in chosen.values()}
    orders = {}
    for fn, sf in model.files.items():
        all_chains = [c for reg in sf.regions for c in reg.get('chains', [])]
        if not all_chains:
            continue
        idx = {c['index'] for c in all_chains}
        heads = [c for c in all_chains if c['index'] not in pred or pred[c['index']]['src']['file'] != fn]
        paths = []
        for h in heads:
            p = [h]
            x = h['index']
            while x in succ and succ[x]['tgt']['index'] in idx and succ[x]['tgt']['file'] == fn:
                x = succ[x]['tgt']['index']
                p.append(model.chains[x])
            paths.append(p)
        by_region = defaultdict(list)
        for p in paths:
            by_region[p[0]['region']].append(p)
        for reg in sf.regions:
            ps = by_region.get(reg['id'], [])

            def key(p):
                first_from_prev = p[0]['index'] in pred and pred[p[0]['index']]['src']['file'] != fn
                last_to_next = p[-1]['index'] in succ and succ[p[-1]['index']]['tgt']['file'] != fn
                return (0 if first_from_prev else 1, 2 if last_to_next else 1, p[0]['index'])
            ps.sort(key=key)
            new = [c for p in ps for c in p]
            if [c['index'] for c in new] != [c['index'] for c in reg.get('chains', [])]:
                orders[(fn, reg['id'])] = new
    return chosen_list, rejected, inserts, orders


def last_code_zone(model, fn):
    sf = model.files[fn]
    regs = [r for r in sf.regions if r.get('chains') and r['context'] == ('CODE', 'CODE')]
    return regs[-1]['zone'] if regs else None


def first_code_zone(model, fn):
    sf = model.files[fn]
    regs = [r for r in sf.regions if r.get('chains') and r['context'] == ('CODE', 'CODE')]
    return regs[0]['zone'] if regs else None


# ------------------------------------------------------------------------------------------------------------
def apply_plan(model, cands, chosen, inserts, orders, src_new, plan):
    """Write the reordered sources with the local changes into src_new/juego_final and src_new/plataforma."""
    edits = defaultdict(dict)         # file -> line index -> new text (None = delete)
    applied = []
    chosen_cands = {id(e['cand']) for e in chosen if e['cand'] is not None}
    for c in cands:
        if c.get('impossible') or c.get('skip'):
            continue
        ins = c['ins']
        fn, li = ins['file'], ins['line'] - 1
        sf = model.files[fn]
        raw = sf.lines[li]
        if c['kind'] == 'tail_jmp':
            if id(c) not in chosen_cands:
                continue
            edits[fn][li] = None
            c['applied'] = 'jmp deleted at line %d (%s now follows)' % (li + 1, c['target_block']['name'])
            applied.append(c)
        elif c['kind'] == 'tail_jsr_rts':
            new = re.sub(r'\bjsr\b', 'jmp', raw, count=1, flags=re.I)
            if new == raw:
                continue
            rl = c['rts']['line'] - 1
            rraw = sf.lines[rl]
            if id(c) in chosen_cands:
                edits[fn][li] = None
                edits[fn][rl] = None
                c['applied'] = 'jsr and rts deleted at lines %d-%d (%s now follows)' % (li + 1, rl + 1, c['target_block']['name'])
            elif not c['rts_referenced'] and not sf.info[rl]['label'] and not sf.info[rl]['anon'] \
                    and re.match(r'^\s*rts\b', strip_comment(rraw), re.I):
                edits[fn][li] = new
                edits[fn][rl] = None
                c['applied'] = 'jsr -> jmp at line %d, rts deleted at line %d' % (li + 1, rl + 1)
            else:
                edits[fn][li] = new
                c['applied'] = 'jsr -> jmp at line %d (rts kept: referenced)' % (li + 1)
            applied.append(c)
        elif c['kind'] == 'jmp_to_rts':
            new = re.sub(r'\bjmp\s+\S+', 'rts', raw, count=1, flags=re.I)
            edits[fn][li] = new
            c['applied'] = 'jmp -> rts at line %d' % (li + 1)
            applied.append(c)
        elif c['kind'] == 'branch_to_rts':
            inv = BRANCHES[ins['mn']].lower()
            m = re.match(r'^(\s*(?:@?\w+:|:)?\s*)(b\w\w)(\s+)(\S+)(.*)$', raw, re.I)
            if not m:
                continue
            lab = '@s%04X' % ins['addr']
            edits[fn][li] = '%s%s%s%s%s\n        rts\n%s:' % (m.group(1), inv, m.group(3), lab, m.group(5), lab)
            c['applied'] = 'branch inverted over an rts in place at line %d' % (li + 1)
            applied.append(c)
        elif c['kind'] == 'branch_over_jmp' and c['in_range']:
            inv = BRANCHES[ins['mn']].lower()
            jraw = sf.lines[c['jmp']['line'] - 1]
            mj = re.search(r'\bjmp\s+(\S+)', jraw, re.I)
            m = re.match(r'^(\s*(?:@?\w+:|:)?\s*)(b\w\w)(\s+)(\S+)(.*)$', raw, re.I)
            if not m or not mj:
                continue
            edits[fn][li] = '%s%s%s%s%s' % (m.group(1), inv, m.group(3), mj.group(1), m.group(5))
            edits[fn][c['jmp']['line'] - 1] = None
            c['applied'] = 'branch inverted to the jmp target at line %d, jmp deleted at line %d' % (li + 1, c['jmp']['line'])
            applied.append(c)
        elif c['kind'] == 'jmp_chain':
            tname = name_of(model.build, c['via']['target'])
            if tname.startswith('$') or tname.startswith('@'):
                continue
            m = re.match(r'^(.*\b(?:jmp|jsr)\s+)(\S+)(.*)$', raw, re.I)
            if not m:
                continue
            edits[fn][li] = m.group(1) + tname + m.group(3)
            c['applied'] = 'retargeted to %s at line %d' % (tname, li + 1)
            applied.append(c)
        elif c['kind'] == 'jmp_to_next':
            edits[fn][li] = None
            c['applied'] = 'jmp deleted at line %d' % (li + 1)
            applied.append(c)
    # a branch_to_rts whose operand was an unnamed label: drop the `:` it pointed to when that was its only
    # reference in every conditional view (ca65 warns on an unreferenced unnamed label; another reference would
    # otherwise silently rebind)
    for c in applied:
        if c['kind'] not in ('branch_to_rts', 'branch_over_jmp'):
            continue
        ins = c['ins']
        fn, li = ins['file'], ins['line'] - 1
        sf = model.files[fn]
        m = re.search(r'\b(b\w\w)\s+:([+-]+)', strip_comment(sf.lines[li]), re.I)
        if not m:
            continue
        only = True
        tgt_line = None
        for view in (None, set(), {'PRUEBA'}, {'SPRHW'}):
            refs = sf.anon_refs(view)
            t = refs['by_ref'].get(li)
            if t is None:
                only = False
                break
            tgt_line = t if tgt_line is None else tgt_line
            if t != tgt_line or refs['by_target'].get(t) != [li]:
                only = False
                break
        if only and tgt_line is not None and tgt_line not in edits[fn]:
            raw = sf.lines[tgt_line]
            edits[fn][tgt_line] = re.sub(r'^:', ' ', raw, count=1)
            c['applied'] += '; the unnamed label at line %d dropped (no other reference)' % (tgt_line + 1)
    # the inserted jmp of a broken existing fall-through: after the block's last instruction line
    inserted = []
    for e in inserts:
        blk, tb = e['src_block'], e['tgt_block']
        last = blk['last_instr']
        fn, li = last['file'], last['line'] - 1
        raw = model.files[fn].lines[li]
        edits[fn][li] = raw + '\n        jmp     %s                  ; (colocacion: %s moved away)' % (tb['name'], tb['name'])
        inserted.append({'file': fn, 'line': li + 1, 'block': blk['name'], 'target': tb['name'],
                         'passes_per_frame': e['w'] / CY_JMP})
    os.makedirs(os.path.join(src_new, 'juego_final'), exist_ok=True)
    os.makedirs(os.path.join(src_new, 'plataforma'), exist_ok=True)
    moved = []
    for sub in ('juego_final', 'plataforma'):
        d = os.path.join(model.srcdir, sub)
        for fname in sorted(os.listdir(d)):
            srcp = os.path.join(d, fname)
            dstp = os.path.join(src_new, sub, fname)
            if not os.path.isfile(srcp):
                continue
            if fname not in model.files:
                with open(srcp, 'rb') as f, open(dstp, 'wb') as g:
                    g.write(f.read())
                continue
            sf = model.files[fname]
            line_plan = []
            i = 0
            n = len(sf.lines)
            region_at = {reg['first']: reg for reg in sf.regions}
            while i < n:
                if i in region_at:
                    reg = region_at[i]
                    p0, p1 = reg['prefix']
                    line_plan.extend(range(p0, p1 + 1))
                    chains = orders.get((fname, reg['id']))
                    if chains is None:
                        for bk in reg['blocks']:
                            line_plan.extend(range(bk['first'], bk['last'] + 1))
                    else:
                        done = set()
                        for ch in chains:
                            for bk in ch['blocks']:
                                line_plan.extend(range(bk['first'], bk['last'] + 1))
                                done.add(id(bk))
                        for bk in reg['blocks']:        # blocks without code in this build keep their place
                            if id(bk) not in done and bk.get('lo') is None:
                                line_plan.extend(range(bk['first'], bk['last'] + 1))
                        moved.append({'file': fname, 'region': reg['id'], 'old': [c['blocks'][0]['name'] for c in reg['chains']],
                                      'new': [c['blocks'][0]['name'] for c in chains]})
                    i = reg['last'] + 1
                else:
                    line_plan.append(i)
                    i += 1
            counts = defaultdict(int)
            for li in line_plan:
                counts[li] += 1
            assert all(v == 1 for v in counts.values()), (fname, [l for l, v in counts.items() if v != 1][:5])
            assert len(line_plan) == n, (fname, len(line_plan), n)
            out = []
            for li in line_plan:
                if li in edits[fname]:
                    if edits[fname][li] is None:
                        continue
                    out.append(edits[fname][li])
                else:
                    out.append(sf.lines[li])
            with open(dstp, 'w', encoding='utf-8') as g:
                g.write('\n'.join(out) + '\n')
    plan['applied'] = [{'id': c['id'], 'kind': c['kind'], 'file': c['ins']['file'], 'line': c['ins']['line'], 'block': c['block']['name'],
                        'note': c['applied']} for c in applied]
    plan['inserted'] = inserted
    plan['moved'] = moved
    plan['fallthroughs'] = [{'src': e['src_block']['name'], 'tgt': e['tgt_block']['name'], 'file': e['src']['file'],
                             'tgt_file': e['tgt']['file'], 'kind': e['kind'], 'cand': e['cand']['id'] if e['cand'] else None}
                            for e in chosen if e['cand'] is not None]
    return applied


# ------------------------------------------------------------------------------------------------------------
class Symbols:
    """The symbols of a build from its debug file, resolved by scope at an address (ca65 .proc scopes)."""

    def __init__(self, dbgpath, build):
        self.scopes, self.syms = {}, defaultdict(list)
        spans = build.spans
        segs = build.segs
        with open(dbgpath, encoding='utf-8') as f:
            for l in f:
                if '\t' not in l:
                    continue
                kind, rest = l.rstrip('\n').split('\t', 1)
                d = {}
                for kv in rest.split(','):
                    k, _, v = kv.partition('=')
                    d[k] = v
                if kind == 'scope':
                    rngs = []
                    for sid in (int(x) for x in d['span'].split('+')) if 'span' in d else []:
                        seg, st, sz = spans[sid]
                        base = segs[seg][1] + st
                        rngs.append((base, base + sz))
                    self.scopes[int(d['id'])] = {'parent': int(d['parent']) if 'parent' in d else None, 'ranges': rngs,
                                                 'mod': int(d['mod'])}
                elif kind == 'sym' and 'val' in d and d.get('type') in ('lab', 'equ'):
                    self.syms[d['name'].strip('"')].append((int(d['scope']) if 'scope' in d else -1, int(d['val'], 16)))
        self.mod_top = {}
        for sid, sc in self.scopes.items():
            if sc['parent'] is None:
                self.mod_top[sc['mod']] = sid

    def scope_chain(self, addr):
        inner = [sid for sid, sc in self.scopes.items() if any(lo <= addr < hi for lo, hi in sc['ranges'])]
        if not inner:
            return []
        # the innermost: the one with the smallest range
        inner.sort(key=lambda sid: min(hi - lo for lo, hi in self.scopes[sid]['ranges']))
        chain, x = [], inner[0]
        while x is not None:
            chain.append(x)
            x = self.scopes[x]['parent']
        return chain

    def lookup(self, name, addr):
        name = name[2:] if name.startswith('::') else name
        cands = self.syms.get(name)
        if not cands:
            return None
        for sid in self.scope_chain(addr):
            for sc, val in cands:
                if sc == sid:
                    return val
        vals = {val for sc, val in cands if sc in self.mod_top.values()}
        if len(vals) == 1:
            return vals.pop()
        vals = {val for sc, val in cands}
        return vals.pop() if len(vals) == 1 else None


def eval_expr(text, resolve, pc):
    """Evaluate a ca65 expression with the given symbol resolver; None when something is unknown."""
    t = strip_comment(text).strip()
    if not t or '"' in t or "'" in t:
        return None
    t = re.sub(r'\.lobyte\s*\(', '<(', t, flags=re.I)
    t = re.sub(r'\.hibyte\s*\(', '>(', t, flags=re.I)
    t = re.sub(r'\$([0-9A-Fa-f]+)', lambda m: str(int(m.group(1), 16)), t)
    t = re.sub(r'%([01]+)', lambda m: str(int(m.group(1), 2)), t)
    bad = [None]

    def sub(m):
        name = m.group(0)
        v = resolve(name)
        if v is None:
            bad[0] = name
            return '0'
        return str(v)
    t = re.sub(r'(::)?[A-Za-z_@][A-Za-z0-9_]*', sub, t)
    if bad[0] is not None:
        return None
    t = t.replace('*', str(pc)) if re.search(r'(^|[^0-9)\s])\s*\*', t) and False else t
    t = re.sub(r'(?<![0-9)\s])\s*\*(?=\s*[-+)]|\s*$)', str(pc), t)
    # unary < and > (low / high byte), ^ bank: rewrite as functions
    out, i = [], 0
    while i < len(t):
        ch = t[i]
        if ch in '<>' and (i + 1 >= len(t) or t[i + 1] not in '<>=') and (i == 0 or t[i - 1] in ' (+-*/,|&^~'):
            fn = 'lo' if ch == '<' else 'hi'
            j = i + 1
            while j < len(t) and t[j] == ' ':
                j += 1
            if j < len(t) and t[j] == '(':
                depth, k = 0, j
                while k < len(t):
                    if t[k] == '(':
                        depth += 1
                    elif t[k] == ')':
                        depth -= 1
                        if depth == 0:
                            break
                    k += 1
                out.append('%s(%s)' % (fn, t[j + 1:k]))
                i = k + 1
            else:
                k = j
                while k < len(t) and (t[k].isalnum() or t[k] in '_'):
                    k += 1
                out.append('%s(%s)' % (fn, t[j:k]))
                i = k
            continue
        out.append(ch)
        i += 1
    t = ''.join(out)
    t = t.replace('.MOD', '%').replace('.mod', '%')
    if not re.match(r'^[0-9a-z()+\-*/%&|^~<> ,]*$', t):
        return None
    try:
        return eval(t, {'__builtins__': {}}, {'lo': lambda v: v & 0xFF, 'hi': lambda v: (v >> 8) & 0xFF})
    except Exception:
        return None


def expected_bytes(item, kind, syms, addr):
    """The bytes a source line should produce in a build, from its expressions and that build's symbols (the
    instruction's operand, or a data directive's elements); None when not evaluable."""
    text = strip_comment(item['text']).strip()
    text = re.sub(r'^(@?[A-Za-z_][A-Za-z0-9_]*:|:)\s*', '', text)

    def resolve(name):
        return syms.lookup(name, addr)
    if kind == 'i':
        m = re.match(r'^[A-Za-z]{3}\s+(.*)$', text)
        if not m:
            return None
        op = m.group(1).strip()
        imm = op.startswith('#')
        op = op[1:] if imm else op
        op = re.sub(r'\s*,\s*[xyXY]\s*$', '', op)
        op = re.sub(r'^\(\s*(.*?)\s*(,\s*[xX])?\s*\)\s*(,\s*[yY])?\s*$', r'\1', op) if op.startswith('(') and item['mode'] in ('(zp,x)', '(zp),y', '(ind)') else op
        v = eval_expr(op, resolve, addr)
        if v is None:
            return None
        if item['len'] == 2:
            return bytes([item['bytes'][0], v & 0xFF])
        if item['len'] == 3:
            return bytes([item['bytes'][0], v & 0xFF, (v >> 8) & 0xFF])
        return None
    m = re.match(r'^(\.\w+)\s*(.*)$', text)
    if not m:
        return None
    d, rest = m.group(1).lower(), m.group(2)
    elems, depth, cur = [], 0, ''
    for ch in rest:
        if ch == ',' and depth == 0:
            elems.append(cur)
            cur = ''
            continue
        depth += (ch == '(') - (ch == ')')
        cur += ch
    if cur.strip():
        elems.append(cur)
    out = bytearray()
    pc = addr
    for e in elems:
        v = eval_expr(e, resolve, pc)
        if v is None:
            return None
        if d in ('.byte', '.byt'):
            out.append(v & 0xFF)
        elif d == '.lobytes':
            out.append(v & 0xFF)
        elif d == '.hibytes':
            out.append((v >> 8) & 0xFF)
        elif d in ('.word', '.addr'):
            out += bytes([v & 0xFF, (v >> 8) & 0xFF])
        elif d == '.dbyt':
            out += bytes([(v >> 8) & 0xFF, v & 0xFF])
        else:
            return None
        pc = addr + len(out)
    return bytes(out)


def align_blocks(model_old, model_new, plan):
    """Pair the old and new blocks by (file, name) and align their items; the address map old -> new."""
    old_by_name = {(b['file'], b['name']): b for b in model_old.blocks}
    new_by_name = {(b['file'], b['name']): b for b in model_new.blocks}
    problems = []
    edited = {(e['file'], e['line']): e for e in plan.get('applied', [])}
    inserted = {(e['file'], e['block']): e for e in plan.get('inserted', [])}
    amap = {}
    pairs = []
    for key, ob in sorted(old_by_name.items()):
        nb = new_by_name.get(key)
        if nb is None:
            problems.append('block %s/%s missing in the new build' % key)
            continue
        pairs.append((ob, nb))
    for ob, nb in pairs:
        oi = sorted([('i', x) for x in ob['instrs']] + [('d', x) for x in ob['data_items']], key=lambda t: t[1]['addr'])
        ni = sorted([('i', x) for x in nb['instrs']] + [('d', x) for x in nb['data_items']], key=lambda t: t[1]['addr'])
        a = c = 0
        while a < len(oi) and c < len(ni):
            ka, xa = oi[a]
            kc, xc = ni[c]
            if ka == 'i':
                ed = edited.get((xa['file'], xa['line']))
                if ed and ed['kind'] == 'tail_jmp' and xa['mn'] == 'JMP':
                    amap[xa['addr']] = None
                    a += 1
                    continue
                if ed and ed['kind'] == 'tail_jsr_rts' and xa['mn'] == 'JSR':
                    if 'jsr and rts deleted' in ed['note']:
                        amap[xa['addr']] = None
                        amap[oi[a + 1][1]['addr']] = None
                        a += 2
                        continue
                    amap[xa['addr']] = xc['addr']
                    a += 1
                    c += 1
                    if 'rts deleted' in ed['note']:
                        amap[oi[a][1]['addr']] = None
                        a += 1
                    continue
                if ed and ed['kind'] == 'jmp_to_rts' and xa['mn'] == 'JMP':
                    amap[xa['addr']] = xc['addr']
                    a += 1
                    c += 1
                    continue
                if ed and ed['kind'] == 'branch_to_rts' and xa['branch']:
                    amap[xa['addr']] = xc['addr']
                    a += 1
                    c += 2
                    continue
                if ed and ed['kind'] == 'branch_over_jmp' and xa['branch']:
                    amap[xa['addr']] = xc['addr']
                    amap[oi[a + 1][1]['addr']] = None
                    a += 2
                    c += 1
                    continue
                if ed and ed['kind'] == 'jmp_to_next':
                    amap[xa['addr']] = None
                    a += 1
                    continue
            amap[xa['addr']] = xc['addr']
            if ka == 'd':
                for o in range(xa['size']):
                    amap[xa['addr'] + o] = xc['addr'] + o
            a += 1
            c += 1
        while a < len(oi) and oi[a][0] == 'i':            # deletions at the block's end
            xa = oi[a][1]
            ed = edited.get((xa['file'], xa['line']))
            if ed and ((ed['kind'] == 'tail_jmp' and xa['mn'] == 'JMP') or ed['kind'] == 'jmp_to_next'):
                amap[xa['addr']] = None
                a += 1
            elif ed and ed['kind'] == 'tail_jsr_rts' and xa['mn'] == 'JSR' and 'jsr and rts deleted' in ed['note']:
                amap[xa['addr']] = None
                amap[oi[a + 1][1]['addr']] = None
                a += 2
            elif ed and ed['kind'] == 'tail_jsr_rts' and xa['mn'] == 'RTS' and 'rts deleted' in ed['note']:
                amap[xa['addr']] = None
                a += 1
            else:
                break
        if a == len(oi) and c == len(ni) - 1 and ni[c][0] == 'i' and ni[c][1]['mn'] == 'JMP' and (ob['file'], ob['name']) in inserted:
            c += 1
        if a != len(oi) or c != len(ni):
            problems.append('block %s/%s: %d old items, %d new items, aligned %d/%d' % (ob['file'], ob['name'], len(oi), len(ni), a, c))
    return pairs, amap, problems, edited, inserted


def verify_pair(model_old, model_new, plan, label):
    pairs, amap, problems, edited, inserted = align_blocks(model_old, model_new, plan)
    bo, bn = model_old.build, model_new.build
    so = Symbols(os.path.join(bo.dir, 'juego.dbg'), bo)
    sn = Symbols(os.path.join(bn.dir, 'juego.dbg'), bn)
    # old -> new for any address: inside an instruction / data item of CODE through the block map; in the other
    # segments (RODATA, DATA, BSS: shifted when CODE shrinks) through the segment offsets
    starts = sorted(a for a, v in amap.items() if v is not None)
    import bisect

    def map_addr(t):
        if t in amap:
            return amap[t]
        k = bisect.bisect_right(starts, t) - 1
        if k >= 0:
            a0 = starts[k]
            ins = bo.by_addr.get(a0)
            size = ins['len'] if ins else 1
            if a0 <= t < a0 + size:
                return amap[a0] + (t - a0)
        for name, (s0, e0, z0) in bo.segments.items():
            if name in CODE_SEGS or name not in bn.segments:
                continue
            if s0 <= t <= e0:
                return bn.segments[name][0] + (t - s0)
        return None

    def by_expr(xa, xc, kind):
        eo = expected_bytes(xa, kind, so, xa['addr'])
        en = expected_bytes(xc, kind, sn, xc['addr'])
        return eo is not None and en is not None and eo == xa['bytes'] and en == xc['bytes']
    checked = 0
    expr_checked = 0
    for ob, nb in pairs:
        for xa in ob['instrs']:
            na = amap.get(xa['addr'])
            if na is None:
                continue
            xc = bn.by_addr.get(na)
            if xc is None:
                problems.append('%s: old $%04X -> new $%04X is not an instruction' % (ob['name'], xa['addr'], na))
                continue
            ed = edited.get((xa['file'], xa['line']))
            if ed:
                checked += 1
                continue
            if xa['opc'] != xc['opc']:
                problems.append('%s: old $%04X %s %s != new $%04X %s %s' % (ob['name'], xa['addr'], xa['mn'], xa['mode'], na, xc['mn'], xc['mode']))
                continue
            if xa['bytes'] == xc['bytes']:
                if xa['branch'] or (xa['len'] == 3 and bo.in_code(xa['target'])):
                    want = map_addr(xa['target'])
                    if want is not None and want != xc['target']:
                        problems.append('%s: %s at old $%04X -> $%04X should now reach $%04X but reaches $%04X' % (
                            ob['name'], xa['mn'], xa['addr'], xa['target'], want, xc['target']))
                        continue
                checked += 1
                continue
            if xa['branch']:
                want = map_addr(xa['target'])
                if want != xc['target']:
                    problems.append('%s: branch at old $%04X -> $%04X maps to $%04X but the new one goes to $%04X' % (
                        ob['name'], xa['addr'], xa['target'], want if want is not None else -1, xc['target']))
                    continue
            elif xa['len'] == 3:
                want = map_addr(xa['target'])
                if want != xc['target'] and not by_expr(xa, xc, 'i'):
                    problems.append('%s: operand at old $%04X (%s) %s != new %s' % (ob['name'], xa['addr'], source_instr_text(xa), xa['bytes'].hex(), xc['bytes'].hex()))
                    continue
                expr_checked += (want != xc['target'])
            else:
                if not by_expr(xa, xc, 'i'):
                    problems.append('%s: bytes at old $%04X (%s) %s != new %s' % (ob['name'], xa['addr'], source_instr_text(xa), xa['bytes'].hex(), xc['bytes'].hex()))
                    continue
                expr_checked += 1
            checked += 1
        for d in ob['data_items']:
            na = amap.get(d['addr'])
            nd = [x for x in nb['data_items'] if x['addr'] == na]
            if not nd:
                problems.append('%s: data at old $%04X not found in the new build' % (ob['name'], d['addr']))
                continue
            nd = nd[0]
            if nd['size'] != d['size']:
                problems.append('%s: data at old $%04X size %d != %d' % (ob['name'], d['addr'], d['size'], nd['size']))
                continue
            if nd['bytes'] == d['bytes']:
                checked += 1
                continue
            if by_expr(d, nd, 'd'):
                checked += 1
                expr_checked += 1
                continue
            problems.append('%s: data at old $%04X (%s) differs: %s != %s' % (ob['name'], d['addr'], d['text'].strip(), d['bytes'].hex(), nd['bytes'].hex()))
    # the other initialised segments (RODATA, DATA): byte-identical, or words that are relocated CODE addresses
    for name in ('RODATA', 'DATA'):
        if name not in bo.segments or name not in bn.segments:
            continue
        s0, e0, z0 = bo.segments[name]
        s1, e1, z1 = bn.segments[name]
        if z0 != z1:
            problems.append('segment %s: size %d != %d' % (name, z0, z1))
            continue
        o = 0
        while o < z0:
            if bo.mem[s0 + o] == bn.mem[s1 + o]:
                o += 1
                continue
            w = bo.mem[s0 + o] | (bo.mem[s0 + o + 1] << 8) if o + 1 < z0 else -1
            nw = bn.mem[s1 + o] | (bn.mem[s1 + o + 1] << 8) if o + 1 < z1 else -2
            if w >= 0 and map_addr(w) == nw:
                o += 2
                expr_checked += 1
                continue
            problems.append('segment %s: byte at old $%04X %02X != new %02X' % (name, s0 + o, bo.mem[s0 + o], bn.mem[s1 + o]))
            o += 1
    # the new fall-throughs: the target's entry must be the byte after the source's last instruction
    new_by_name = {(b['file'], b['name']): b for b in model_new.blocks}
    adjacency = []
    for e in plan.get('fallthroughs', []):
        sb = new_by_name.get((e['file'], e['src']))
        tb = new_by_name.get((e['tgt_file'], e['tgt']))
        if sb is None or tb is None or sb['last_instr'] is None:
            problems.append('fall-through %s -> %s: a block is missing in the new build' % (e['src'], e['tgt']))
            continue
        end = sb['last_instr']['addr'] + sb['last_instr']['len']
        ok = (end == tb['entry'] and sb['hi'] == tb['lo'] and not sb['ends_in_data'] and sb['last_instr']['mn'] not in TERMINATORS)
        adjacency.append({'src': e['src'], 'tgt': e['tgt'], 'end_of_src': '%04X' % end, 'entry_of_tgt': '%04X' % tb['entry'], 'ok': ok})
        if not ok:
            problems.append('fall-through %s -> %s: %s ends at $%04X (%s), %s starts at $%04X' % (
                e['src'], e['tgt'], e['src'], end, sb['last_instr']['mn'], e['tgt'], tb['entry']))
    for e in plan.get('inserted', []):
        sb = new_by_name.get((e['file'], e['block']))
        tb = new_by_name.get((e['file'], e['target']))
        last = sb['last_instr'] if sb else None
        if last is None or last['mn'] != 'JMP' or tb is None or last['target'] != tb['entry']:
            problems.append('inserted jmp in %s -> %s: not found at the block end' % (e['block'], e['target']))
    return {'build': label, 'blocks_paired': len(pairs), 'items_checked': checked, 'relocations_checked_by_expression': expr_checked,
            'problems': problems, 'adjacency': adjacency}


def check_hw_listings(lstdir, plan):
    """SPRHW assembly listings: every chosen fall-through has the target's label right after the source's last
    emitted byte, with no bytes in between (the listing's offsets are relative to the current segment)."""
    out = []
    cache = {}

    def listing(fn):
        if fn not in cache:
            p = os.path.join(lstdir, fn[:-2] + '.lst')
            rows = []
            with open(p, encoding='utf-8', errors='replace') as f:
                for l in f:
                    m = re.match(r'^([0-9A-F]{6})r?\s+(\d+)\s+((?:[0-9A-Frx]{2} ?)*)\s*(.*)$', l.rstrip('\n'))
                    if m:
                        rows.append((int(m.group(1), 16), m.group(3).split(), m.group(4)))
            cache[fn] = rows
        return cache[fn]

    for e in plan.get('fallthroughs', []):
        if e['file'] != e['tgt_file']:
            out.append({'src': e['src'], 'tgt': e['tgt'], 'ok': None, 'note': 'across files: not checked in the SPRHW listing'})
            continue
        rows = listing(e['file'])
        ti = None
        for i, (off, byts, text) in enumerate(rows):
            if re.match(r'^(%s:|\.proc\s+%s\b)' % (re.escape(e['tgt']), re.escape(e['tgt'])), text.strip()):
                ti = i
                break
        if ti is None:
            out.append({'src': e['src'], 'tgt': e['tgt'], 'ok': False, 'note': 'target label not found in the SPRHW listing'})
            continue
        j = ti - 1
        while j >= 0 and not rows[j][1]:
            j -= 1
        off, byts, text = rows[j]
        end = off + len(byts)
        ok = (end == rows[ti][0])
        out.append({'src': e['src'], 'tgt': e['tgt'], 'ok': ok, 'last_bytes_line': text.strip()[:60],
                    'end': '%06X' % end, 'target_offset': '%06X' % rows[ti][0]})
    return out


def write_tsv(path, header, rows):
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\t'.join(header) + '\n')
        for r in rows:
            f.write('\t'.join('' if v is None else (('%.3f' % v) if isinstance(v, float) else str(v)) for v in r) + '\n')


def load_inline(path):
    names = set()
    if not path or not os.path.exists(path):
        return names
    with open(path, encoding='utf-8') as f:
        for l in f:
            if 'INLINE' in l:
                names.add(l.split('\t')[0].strip())
    return names


def cmd_analyse(a):
    ops = load_opcodes(a.opcodes)
    normal = Build(a.normal, ops, a.src)
    prueba = Build(a.prueba, ops, a.src)
    prof = Profile(a.profile, prueba)
    model = Model(a.src, normal, prof)
    inline = load_inline(a.resultados)
    cands = find_candidates(model, prof, inline)
    chosen, rejected, inserts, orders = plan_placement(model, cands)
    os.makedirs(a.out, exist_ok=True)
    rows = []
    for blk in model.blocks:
        rows.append([blk['file'], blk['region'], blk['index_in_region'], blk['name'], blk['kind'], blk['first'] + 1, blk['last'] + 1,
                     '%04X' % blk['lo'], '%04X' % blk['hi'], blk['bytes'], len(blk['instrs']),
                     blk['last_instr']['mn'] if blk['last_instr'] else '', 'yes' if blk['falls_through'] else 'no',
                     'yes' if blk['ends_in_data'] else 'no', '; '.join(blk.get('glue', [])), blk.get('immovable', ''),
                     blk['chain']['index'], '/'.join(blk['chain']['zone'][1:])])
    write_tsv(os.path.join(a.out, 'bloques.tsv'),
              ['file', 'region', 'index', 'name', 'kind', 'first_line', 'last_line', 'lo', 'hi', 'bytes', 'instructions',
               'last_instr', 'falls_through', 'ends_in_data', 'glue', 'immovable', 'chain', 'segment_normal/sprhw'], rows)
    chosen_c = {id(e['cand']): e for e in chosen if e['cand'] is not None}
    rows = []
    cands_sorted = sorted(cands, key=lambda c: (-(c['saved_pf'] or 0), -(c['saved_nokeys'] or 0), c['ins']['addr']))
    for n, c in enumerate(cands_sorted):
        ins = c['ins']
        tgt = name_of(normal, c['target'])
        e = chosen_c.get(id(c))
        placement = ''
        total_pf, total_nk, total_cpe = c['saved_pf'], c['saved_nokeys'], c['cycles_per_exec']
        if e is not None:
            if c['adjacent']:
                placement = 'no move: %s already follows; the jmp is deleted' % e['tgt']['blocks'][0]['name']
            else:
                placement = 'fall-through: %s placed after %s' % (e['tgt']['blocks'][0]['name'], e['src']['blocks'][-1]['name'])
            if c['kind'] == 'tail_jsr_rts':
                total_cpe = CY_JSR + CY_RTS
                total_pf = (c['per_frame'] or 0) * total_cpe
                total_nk = (c['nokeys_pf'] or 0) * total_cpe
                c['bytes'] = -4
        elif c.get('placement_note'):
            placement = 'no fall-through: ' + c['placement_note']
        elif c.get('impossible'):
            placement = 'impossible: ' + c['impossible']
        elif c['kind'] in ('tail_jmp', 'tail_jsr_rts'):
            rej = [r for r in rejected if r['cand'] is c]
            if rej:
                placement = 'no fall-through: ' + rej[0]['reject']
            elif c['kind'] == 'tail_jsr_rts':
                placement = 'local change only: jsr -> jmp (the rts stays: %s)' % (
                    'referenced by other code' if c['rts_referenced'] else 'not the end of the routine')
            else:
                placement = 'no fall-through: not chosen'
        c['id'] = 'S%03d' % (n + 1)
        c['placement'] = placement
        c['total_pf'] = total_pf
        c['total_nk'] = total_nk
        c['total_cpe'] = total_cpe
        rows.append([c['id'], c['kind'], ins['file'], c['block']['name'], ins['line'], '%04X' % ins['addr'],
                     source_instr_text(ins), tgt, total_cpe, c['per_frame'], c['nokeys_pf'], total_pf, total_nk, c['bytes'],
                     placement, c['how'], c['cite'], c.get('impossible', '')])
    write_tsv(os.path.join(a.out, 'candidatos.tsv'),
              ['id', 'kind', 'file', 'routine', 'line', 'addr', 'instruction', 'target', 'cycles_saved_per_exec',
               'exec_per_frame_mean3', 'exec_per_frame_nokeys', 'cycles_saved_per_frame_mean3', 'cycles_saved_per_frame_nokeys',
               'bytes_delta', 'placement', 'executions_how', 'cycle_source', 'impossible'], rows)
    rows = []
    for (fn, rid), chains in sorted(orders.items()):
        sf = model.files[fn]
        reg = sf.regions[rid]
        rows.append([fn, rid, reg['first'] + 1, reg['last'] + 1, '%s/%s' % reg['context'],
                     ' '.join(c['blocks'][0]['name'] for c in reg['chains']), ' '.join(c['blocks'][0]['name'] for c in chains)])
    write_tsv(os.path.join(a.out, 'orden.tsv'), ['file', 'region', 'first_line', 'last_line', 'segment_normal/sprhw', 'old_order', 'new_order'], rows)
    plan = {'chosen': [{'cand': e['cand']['id'] if e['cand'] else None, 'kind': e['kind'], 'src': e['src_block']['name'],
                        'tgt': e['tgt_block']['name'], 'file': e['src']['file'], 'cycles_per_frame': e['w'], 'nokeys': e['nokeys']}
                       for e in chosen],
            'rejected': [{'cand': e['cand']['id'] if e['cand'] else None, 'kind': e['kind'], 'src': e['src_block']['name'],
                          'tgt': e['tgt_block']['name'], 'cycles_per_frame': e['w'], 'why': e['reject']} for e in rejected],
            'inserts': [{'src': e['src_block']['name'], 'tgt': e['tgt_block']['name'], 'file': e['src']['file'],
                         'cycles_per_frame_cost': e['w'], 'nokeys_cost': e['nokeys']} for e in inserts],
            'sessions': [{'name': s['name'], 'frames': s['frames'], 'path': s['path']} for s in prof.sessions]}
    if a.apply:
        for c in cands:
            if c.get('impossible'):
                c['skip'] = True
            elif c['kind'] == 'tail_jmp':
                c['skip'] = id(c) not in chosen_c
            elif c['kind'] == 'branch_to_rts':
                c['skip'] = not (c.get('saved_pf') and c['saved_pf'] > 0 and (c.get('saved_nokeys') or 0) >= 0)
            elif c['kind'] == 'branch_over_jmp':
                c['skip'] = not c['in_range']
            elif c['kind'] == 'jmp_chain':
                c['skip'] = not c['executed']
            elif c['kind'] == 'tail_jsr_rts':
                c['skip'] = not c['executed']
            elif c['kind'] in ('jmp_to_rts', 'jmp_to_next'):
                c['skip'] = False
        apply_plan(model, cands, chosen, inserts, orders, a.apply, plan)
    with open(os.path.join(a.out, 'plan.json'), 'w', encoding='utf-8') as f:
        json.dump(plan, f, indent=1, sort_keys=True)
    print('blocks %d, chains %d, candidates %d, chosen edges %d (tail jumps %d), rejected %d, inserted jmps %d, regions reordered %d' % (
        len(model.blocks), len(model.chains), len(cands), len(chosen), len(chosen_c), len(rejected), len(inserts), len(orders)))


def cmd_verify(a):
    ops = load_opcodes(a.opcodes)
    with open(a.plan, encoding='utf-8') as f:
        plan = json.load(f)
    reports = []
    old = Model(a.src, Build(a.normal, ops, a.src))
    new = Model(a.src_new, Build(a.normal_new, ops, a.src_new))
    reports.append(verify_pair(old, new, plan, 'normal'))
    reports[-1]['segments_old'] = {k: list(v) for k, v in old.build.segments.items() if k in ('CODE', 'BAJO', 'RODATA', 'DATA', 'BSS')}
    reports[-1]['segments_new'] = {k: list(v) for k, v in new.build.segments.items() if k in ('CODE', 'BAJO', 'RODATA', 'DATA', 'BSS')}
    if a.prueba and a.prueba_new:
        oldp = Model(a.src, Build(a.prueba, ops, a.src))
        newp = Model(a.src_new, Build(a.prueba_new, ops, a.src_new))
        reports.append(verify_pair(oldp, newp, plan, 'prueba'))
        reports[-1]['segments_old'] = {k: list(v) for k, v in oldp.build.segments.items() if k in ('CODE', 'BAJO', 'RODATA', 'DATA', 'BSS')}
        reports[-1]['segments_new'] = {k: list(v) for k, v in newp.build.segments.items() if k in ('CODE', 'BAJO', 'RODATA', 'DATA', 'BSS')}
    hw = check_hw_listings(a.hw_lst, plan) if a.hw_lst else []
    rep = {'builds': reports, 'sprhw_listing_adjacency': hw}
    with open(os.path.join(a.out, 'verificacion.json'), 'w', encoding='utf-8') as f:
        json.dump(rep, f, indent=1, sort_keys=True)
    for r in reports:
        print('%s: paired blocks %d, items checked %d, problems %d' % (r['build'], r['blocks_paired'], r['items_checked'], len(r['problems'])))
        for p in r['problems'][:30]:
            print('  ' + p)
    bad = [h for h in hw if h['ok'] is False]
    print('sprhw listing adjacency: %d checked, %d not adjacent' % (len(hw), len(bad)))
    for h in bad:
        print('  ' + json.dumps(h))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('analyse')
    p.add_argument('--src', required=True)
    p.add_argument('--normal', required=True)
    p.add_argument('--prueba', required=True)
    p.add_argument('--opcodes', required=True)
    p.add_argument('--profile', action='append', default=[], help='NAME=FILE:FRAMES')
    p.add_argument('--resultados', default='', help="the project's resultados.tsv (INLINE routines)")
    p.add_argument('--out', required=True)
    p.add_argument('--apply', default='', help='write the reordered sources here')
    p = sub.add_parser('verify')
    p.add_argument('--src', required=True)
    p.add_argument('--normal', required=True)
    p.add_argument('--prueba', default='')
    p.add_argument('--src-new', required=True)
    p.add_argument('--normal-new', required=True)
    p.add_argument('--prueba-new', default='')
    p.add_argument('--hw-lst', default='')
    p.add_argument('--opcodes', required=True)
    p.add_argument('--plan', required=True)
    p.add_argument('--out', required=True)
    a = ap.parse_args(argv)
    if a.cmd == 'analyse':
        cmd_analyse(a)
    else:
        cmd_verify(a)


if __name__ == '__main__':
    main()
