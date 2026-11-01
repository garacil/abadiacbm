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

"""ciclos6502.py: deterministic static 6502 cycle analyzer for ca65 listings (abadia64ks, C64 build).

Every cycle figure comes from sim65's 6502 core (the host's instrument), parsed from its source
6502.c at run time: OP6502Table (opcode -> handler), each handler's macro (AC_OP / ALU_OP / STO_OP /
MEM_OP / *_IMM / BRANCH / literal "Cycles = N"), the ALU_CY_* / STO_CY_* / RMW_CY_* constants, the
ADR_* address macros (+1 on PAGE_CROSS, bytes from "Regs.PC += n") and the BRANCH macro.  Each row of
tabla_opcodes.tsv cites the 6502.c lines it was taken from.  Nothing is transcribed from memory.

Inputs: the ca65 listings (-l) of one link, its ld65 map (-m), its VICE label file (-Ln) and the
linked memory image (the bytes decoded are the image's: the listing only gives addresses, lengths and
the source text).  Conditional assembly (.ifdef/.ifndef/.else/.endif, macro definitions) is evaluated
with the symbols given by --define (none for the normal C64 build).

Outputs in --out (TSV, UTF-8, tab separated): tabla_opcodes.tsv, instrucciones.tsv, bucles.tsv,
rutinas.tsv, llamadas.tsv, resumen.json.  Same inputs -> byte-identical outputs.

Loops: a backward branch (conditional, or jmp) whose target is at a lower address.  Body cycles per
iteration = one straight pass over every instruction from the target to the branch inclusive, the
closing branch taken (+1 when the branch crosses a page: exact, from the addresses), inner forward
branches not taken, inner loops' closing branches not taken (one pass), JSR = 6 (callee not included).
Possible +1 page crossings of indexed reads are counted separately, never added silently.
"""
import argparse
import json
import os
import re
import sys
from collections import OrderedDict

MODE_OF_MACRO = {
    'ZP': 'zp', 'ZPX': 'zp,x', 'ZPY': 'zp,y', 'ABS': 'abs', 'ABSX': 'abs,x', 'ABSY': 'abs,y',
    'ZPXIND': '(zp,x)', 'ZPINDY': '(zp),y', 'ZPIND': '(zp)',
}
MNEMONICS = set('''ADC AND ASL BCC BCS BEQ BIT BMI BNE BPL BRK BVC BVS CLC CLD CLI CLV CMP CPX CPY DEC DEX DEY
EOR INC INX INY JMP JSR LDA LDX LDY LSR NOP ORA PHA PHP PLA PLP ROL ROR RTI RTS SBC SEC SED SEI STA STX STY
TAX TAY TSX TXA TXS TYA'''.split())
DATA_DIRECTIVES = ('.byte', '.byt', '.word', '.addr', '.res', '.dbyt', '.lobytes', '.hibytes', '.asciiz',
                   '.incbin', '.faraddr', '.dword', '.bankbytes', '.repeat')
BRANCHES = {'BCC', 'BCS', 'BEQ', 'BNE', 'BPL', 'BMI', 'BVC', 'BVS'}


# ----------------------------------------------------------------------------------------------
# 1. The opcode table from sim65's 6502.c
# ----------------------------------------------------------------------------------------------

def _macro_body(src, i):
    """Return (text, last_line_index) of the #define starting at src[i] (continuation backslashes)."""
    body = []
    j = i
    while src[j].rstrip().endswith('\\'):
        body.append(src[j])
        j += 1
    body.append(src[j])
    return '\n'.join(body), j


def parse_6502c(path):
    """Build {opcode: op} from 6502.c.  op = dict(opcode, mn, mode, length, cycles, cross, branch, src)."""
    with open(path, encoding='utf-8', errors='replace') as f:
        src = f.read().split('\n')
    n = len(src)
    const = {}
    adr = {}
    macros = {}
    i = 0
    while i < n:
        line = src[i]
        m = re.match(r'#define\s+((?:ALU|STO|RMW|RMW2)_CY_[A-Z_0-9]+)\s+(\S+)\s*$', line)
        if m:
            const[m.group(1)] = (m.group(2), i + 1)
        m = re.match(r'#define\s+ADR_([A-Z_]+)\(ad\)', line)
        if m:
            text, j = _macro_body(src, i)
            pc = re.search(r'Regs\.PC\s*\+=\s*(\d+)', text)
            adr[m.group(1)] = {'cross': ('PAGE_CROSS' in text and '++Cycles' in text),
                               'length': int(pc.group(1)), 'lines': (i + 1, j + 1)}
            i = j
        m = re.match(r'#define\s+(MEM_AD_OP_IMM|ALU_OP_IMM|AC_OP_IMM|ALU_OP|AC_OP|STO_OP|MEM_OP|BRANCH)\(', line)
        if m:
            text, j = _macro_body(src, i)
            macros[m.group(1)] = {'text': text, 'lines': (i + 1, j + 1)}
            i = j
        i += 1
    for name in ('ALU_CY_ZP', 'STO_CY_ZP', 'RMW_CY_ZP', 'ALU_OP_IMM', 'AC_OP_IMM', 'BRANCH', 'MEM_AD_OP_IMM',
                 'ALU_OP', 'AC_OP', 'STO_OP', 'MEM_OP'):
        if name not in const and name not in macros:
            raise SystemExit('6502.c: %s not found' % name)

    def resolve(name):
        chain = []
        while True:
            val, ln = const[name]
            chain.append(ln)
            if val.isdigit():
                return int(val), chain
            name = val

    imm_len = int(re.search(r'Regs\.PC\s*\+=\s*(\d+)', macros['MEM_AD_OP_IMM']['text']).group(1))
    imm_cyc = {}
    for k in ('ALU_OP_IMM', 'AC_OP_IMM'):
        imm_cyc[k] = int(re.search(r'Cycles\s*=\s*(\d+)', macros[k]['text']).group(1))
    br = macros['BRANCH']['text']
    br_base = int(re.search(r'Cycles\s*=\s*(\d+)', br).group(1))
    br_incs = br.count('++Cycles')
    if br_incs != 2:
        raise SystemExit('6502.c: BRANCH macro: expected two ++Cycles (taken, page cross), found %d' % br_incs)
    br_len = int(re.search(r'Regs\.PC\s*\+=\s*(\d+)', br).group(1))
    branch_info = {'not_taken': br_base, 'taken': br_base + 1, 'taken_cross': br_base + 2, 'length': br_len,
                   'lines': macros['BRANCH']['lines']}
    # the dispatch table
    tstart = None
    for i, line in enumerate(src):
        if line.startswith('static const OPFunc OP6502Table[256]'):
            tstart = i
            break
    if tstart is None:
        raise SystemExit('6502.c: OP6502Table not found')
    names = []
    i = tstart + 1
    while len(names) < 256:
        t = src[i].strip().rstrip(',').split('//')[0].strip()
        if t.startswith('OPC_'):
            names.append((i + 1, t))
        i += 1
    table_lines = (tstart + 1, i)
    # handler bodies
    bodies = {}
    for i, line in enumerate(src):
        m = re.match(r'static void (OPC_\w+) \(void\)', line)
        if m:
            j = i + 1
            while not src[j].startswith('}'):
                j += 1
            bodies[m.group(1)] = (i + 1, j + 1, '\n'.join(src[i:j + 1]))
    ops = {}
    for opcode, (tline, hname) in enumerate(names):
        if hname == 'OPC_Illegal':
            continue
        h0, h1, body = bodies[hname]
        cm = re.search(r'/\*\s*Opcode\s*\$(\S+?):\s*([^*]*?)\s*\*/', body)
        if not cm:
            raise SystemExit('6502.c: handler %s has no "Opcode $xx:" comment' % hname)
        if int(hname[-2:], 16) != opcode:
            raise SystemExit('6502.c: handler %s is table entry $%02X' % (hname, opcode))
        if re.fullmatch(r'[0-9A-Fa-f]{2}', cm.group(1)) and int(cm.group(1), 16) != opcode:
            raise SystemExit('6502.c: handler %s comment opcode mismatch with table entry $%02X' % (hname, opcode))
        comment_note = '' if re.fullmatch(r'[0-9A-Fa-f]{2}', cm.group(1)) else \
            ' (comment reads "Opcode $%s": a typo in 6502.c; the opcode is the handler name\'s)' % cm.group(1)
        parts = cm.group(2).split(None, 1)
        mn = parts[0].upper()
        modetxt = parts[1].strip() if len(parts) > 1 else ''
        fm = re.search(r'\b(AC_OP_IMM|ALU_OP_IMM|AC_OP|ALU_OP|STO_OP|MEM_OP|BRANCH)\s*\(\s*([A-Z_0-9]*)', body)
        srcref = ['OP6502Table line %d' % tline, 'handler %s lines %d-%d%s' % (hname, h0, h1, comment_note)]
        cross = False
        branch = False
        if fm and fm.group(1) in ('AC_OP_IMM', 'ALU_OP_IMM'):
            kind = fm.group(1)
            cycles = imm_cyc[kind]
            length = imm_len
            mode = 'imm'
            srcref.append('%s lines %d-%d (Cycles = %d)' % (kind, macros[kind]['lines'][0], macros[kind]['lines'][1], cycles))
            srcref.append('MEM_AD_OP_IMM lines %d-%d (PC += %d)' % (macros['MEM_AD_OP_IMM']['lines'] + (imm_len,)))
        elif fm and fm.group(1) in ('AC_OP', 'ALU_OP', 'STO_OP', 'MEM_OP'):
            kind, mk = fm.group(1), fm.group(2)
            prefix = {'AC_OP': 'ALU', 'ALU_OP': 'ALU', 'STO_OP': 'STO', 'MEM_OP': 'RMW'}[kind]
            cycles, chain = resolve('%s_CY_%s' % (prefix, mk))
            a = adr[mk]
            length = a['length']
            cross = a['cross']
            mode = MODE_OF_MACRO[mk.replace('_NP', '')]
            srcref.append('%s(%s) lines %d-%d' % (kind, mk, macros[kind]['lines'][0], macros[kind]['lines'][1]))
            srcref.append('%s_CY_%s = %d line(s) %s' % (prefix, mk, cycles, ','.join(str(x) for x in chain)))
            srcref.append('ADR_%s lines %d-%d (PC += %d%s)' % (mk, a['lines'][0], a['lines'][1], length,
                                                              ', ++Cycles on PAGE_CROSS' if cross else ', no page-cross penalty'))
        elif fm and fm.group(1) == 'BRANCH':
            branch = True
            cycles = br_base
            length = br_len
            mode = 'rel'
            srcref.append('BRANCH lines %d-%d (Cycles = %d; +1 taken; +1 page cross; PC += %d)' %
                          (branch_info['lines'] + (br_base, br_len)))
        else:
            cm2 = re.search(r'Cycles\s*=\s*(\d+)\s*;', body)
            if not cm2:
                raise SystemExit('6502.c: handler %s: no cycle rule recognised' % hname)
            cycles = int(cm2.group(1))
            incs = [int(x) for x in re.findall(r'Regs\.PC\s*\+=\s*(\d+)', body)]
            if opcode == 0x20:
                length = 3  # JSR: reads two operand bytes with PC += 1 twice, pushes PC+2; RTS adds 1
                srcref.append('JSR: two "Regs.PC += 1" + operand bytes (lines %d-%d); 3 bytes' % (h0, h1))
            elif incs:
                length = sum(incs)
            elif 'MemReadWord (Regs.PC+1)' in body or 'MemReadWord (PC+1)' in body:
                length = 3
            elif 'POP ()' in body:
                length = 1
            else:
                raise SystemExit('6502.c: handler %s: no length rule recognised' % hname)
            if opcode == 0x20:
                mode = 'abs'    # JSR: the comment names no mode; the handler reads a 16-bit operand
            elif modetxt.lower() == 'a':
                mode = 'acc'
            elif modetxt == '(ind)':
                mode = '(ind)'
            elif modetxt == 'abs':
                mode = 'abs'
            elif modetxt == '':
                mode = 'impl'
            else:
                mode = modetxt
            srcref.append('literal Cycles = %d (handler)' % cycles)
        ops[opcode] = {'opcode': opcode, 'mn': mn, 'mode': mode, 'length': length, 'cycles': cycles,
                       'cross': cross, 'branch': branch, 'src': '; '.join(srcref), 'handler': hname}
    return ops, branch_info, {'table_lines': table_lines, 'file': path}


# ----------------------------------------------------------------------------------------------
# 2. ld65 map, VICE labels, memory image
# ----------------------------------------------------------------------------------------------

def parse_map(path):
    """Return (segments {name: (start, end, size)}, modules {module.o: {seg: (offs, size)}})."""
    segments = OrderedDict()
    modules = OrderedDict()
    with open(path, encoding='utf-8', errors='replace') as f:
        lines = f.read().split('\n')
    section = None
    cur = None
    for line in lines:
        if line.startswith('Modules list:'):
            section = 'mod'
            continue
        if line.startswith('Segment list:'):
            section = 'seg'
            continue
        if line.startswith('Exports list') or line.startswith('Imports list'):
            section = None
            continue
        if section == 'mod':
            m = re.match(r'^(\S+\.o):\s*$', line)
            if m:
                cur = m.group(1)
                modules[cur] = OrderedDict()
                continue
            m = re.match(r'^\s+(\S+)\s+Offs=([0-9A-F]+)\s+Size=([0-9A-F]+)', line)
            if m and cur:
                modules[cur][m.group(1)] = (int(m.group(2), 16), int(m.group(3), 16))
        elif section == 'seg':
            m = re.match(r'^(\S+)\s+([0-9A-F]{6})\s+([0-9A-F]{6})\s+([0-9A-F]{6})\s+([0-9A-F]+)\s*$', line)
            if m:
                segments[m.group(1)] = (int(m.group(2), 16), int(m.group(3), 16), int(m.group(4), 16))
    return segments, modules


def parse_lbl(path):
    """VICE label file (ld65 -Ln): {address: [names]}."""
    out = {}
    if not path:
        return out
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            m = re.match(r'^al\s+([0-9A-Fa-f]+)\s+\.(\S+)', line)
            if m:
                out.setdefault(int(m.group(1), 16), []).append(m.group(2))
    return out


def load_image(path, skip, base):
    """A 64 KiB memory image from a file: bytes after `skip` land at `base`."""
    mem = bytearray(65536)
    with open(path, 'rb') as f:
        data = f.read()[skip:]
    mem[base:base + len(data)] = data
    return mem


# ----------------------------------------------------------------------------------------------
# 3. ca65 listings
# ----------------------------------------------------------------------------------------------

LABEL_RE = re.compile(r'^\s*(@?[A-Za-z_][A-Za-z0-9_]*)\s*:(?!=)')
ANON_RE = re.compile(r'^\s*:(?![=+-])')


def strip_labels(text):
    """Return (labels, rest): leading `name:` / `@name:` / unnamed `:` labels removed from a source line."""
    labels = []
    rest = text
    while True:
        m = LABEL_RE.match(rest)
        if m:
            labels.append(m.group(1))
            rest = rest[m.end():]
            continue
        m = ANON_RE.match(rest)
        if m:
            labels.append(':')
            rest = rest[m.end():]
            continue
        break
    return labels, rest.strip()


def parse_listing(path, defined):
    """Parse one ca65 listing.

    Returns dict(items=[...], labels=[...], procs=[...]).  item: seg, rel, off, bytes (list of 'XX'/'rr'),
    text (source after labels), kind ('code'|'data'|'res'), lineno, size (for .res).  label: seg, rel, off,
    name, kind ('proc'|'global'|'cheap'|'anon').  procs: (seg, rel, off_start, off_end, name).
    """
    with open(path, encoding='utf-8', errors='replace') as f:
        lines = f.read().split('\n')
    seg = 'CODE'
    cond = []          # stack of (active, else_seen)
    in_macro = False
    macro_name = ''
    macro_toks = []
    macro_kinds = {}   # macro name (lower case) -> 'code' | 'data' (from its body's first tokens)
    items = []
    labels = []
    procs = []
    open_procs = []
    pending_repeat = None   # (item index, needs kind from the body)
    trace = []              # every listing line's (seg, rel, off, continuation?): item sizes are address deltas,
    n = len(lines)          # because the listing prints at most 12 bytes of an item (--list-bytes)

    def active():
        return all(c[0] for c in cond)

    for idx in range(n):
        line = lines[idx]
        m = re.match(r'^([0-9A-F]{6})(r| ) (\d)', line)
        if not m:
            continue
        off = int(m.group(1), 16)
        rel = m.group(2) == 'r'
        field = line[11:23] if len(line) > 11 else ''
        bts = [t for t in field.split() if re.fullmatch(r'[0-9A-Fa-f]{2}|rr', t)]
        text = line[24:] if len(line) > 24 else ''
        text_nc = re.sub(r';.*$', '', text).rstrip()
        cont = bool(bts) and not text.strip()
        trace.append((seg, rel, off, cont))
        if cont:
            continue            # continuation line of the previous item's bytes (never more than shown)
        if not text_nc.strip() and not bts:
            continue
        lbls, rest = strip_labels(text_nc)
        low = rest.lower()
        tok = low.split()[0] if low.split() else ''
        # conditional assembly and macro definitions
        if tok == '.macro':
            in_macro = True
            parts = rest.split()
            macro_name = parts[1].lower() if len(parts) > 1 else ''
            macro_toks = []
            continue
        if tok == '.endmacro' or tok == '.endmac':
            in_macro = False
            kind = 'unknown'
            for t in macro_toks:
                if t.upper() in MNEMONICS or macro_kinds.get(t) == 'code':
                    kind = 'code'
                    break
                if t.startswith(DATA_DIRECTIVES) or macro_kinds.get(t) == 'data':
                    kind = 'data'
            macro_kinds[macro_name] = kind
            continue
        if in_macro:
            if tok and not tok.startswith(('.if', '.else', '.endif', '.local', '.exitmac')):
                macro_toks.append(tok)
            continue
        if tok in ('.ifdef', '.ifndef'):
            sym = rest.split()[1] if len(rest.split()) > 1 else ''
            val = sym in defined
            if tok == '.ifndef':
                val = not val
            cond.append([val, False])
            continue
        if tok in ('.if', '.ifblank', '.ifnblank', '.ifconst', '.ifref', '.ifnref', '.ifp02', '.ifpc02'):
            cond.append([True, False])      # unknown expression: assumed true (none affects this build's segments)
            continue
        if tok == '.else':
            if cond:
                cond[-1][0] = (not cond[-1][0]) and all(c[0] for c in cond[:-1])
                cond[-1][1] = True
            continue
        if tok == '.elseif':
            if cond:
                cond[-1][0] = False
            continue
        if tok == '.endif':
            if cond:
                cond.pop()
            continue
        if not active():
            continue
        # segment switches
        if tok == '.segment':
            sm = re.search(r'"([^"]+)"', rest)
            if sm:
                seg = sm.group(1)
            continue
        if tok in ('.code', '.data', '.rodata', '.bss', '.zeropage'):
            seg = {'.code': 'CODE', '.data': 'DATA', '.rodata': 'RODATA', '.bss': 'BSS', '.zeropage': 'ZEROPAGE'}[tok]
            continue
        # labels at this address
        for lb in lbls:
            kind = 'anon' if lb == ':' else ('cheap' if lb.startswith('@') else 'global')
            labels.append({'seg': seg, 'rel': rel, 'off': off, 'name': lb, 'kind': kind, 'lineno': idx + 1})
        if tok == '.proc':
            name = rest.split()[1] if len(rest.split()) > 1 else '?'
            labels.append({'seg': seg, 'rel': rel, 'off': off, 'name': name, 'kind': 'proc', 'lineno': idx + 1})
            open_procs.append((seg, rel, off, name))
            continue
        if tok == '.endproc':
            if open_procs:
                s, r, o, name = open_procs.pop()
                procs.append((s, r, o, off, name))
            continue
        if tok == '.endrep' or tok == '.endrepeat':
            pending_repeat = None
            continue
        # byte-bearing lines and .res (a .res without a fill value shows no bytes: its size is the address delta)
        if tok == '.res':
            items.append({'seg': seg, 'rel': rel, 'off': off, 'bytes': bts, 'text': rest, 'kind': 'res',
                          'lineno': idx + 1, 'size': 0, 'tidx': len(trace) - 1})
            continue
        if not bts:
            if pending_repeat is not None and tok and not tok.startswith('.'):
                # the first body line of a .repeat decides whether its bytes are code
                items[pending_repeat]['kind'] = 'code' if (tok.upper() in MNEMONICS or macro_kinds.get(tok) == 'code') else 'data'
                pending_repeat = None
            continue
        if tok.startswith('.'):
            kind = 'data'
            if tok == '.repeat':
                kind = 'data'
                pending_repeat = len(items)
        elif tok.upper() in MNEMONICS:
            kind = 'code'
        elif tok in macro_kinds:
            kind = 'code' if macro_kinds[tok] != 'data' else 'data'     # a macro: by its body (DI = sei, PRUEBAP = .byte)
        else:
            kind = 'code'   # an unknown macro: decoded from the bytes (reported if that fails)
        items.append({'seg': seg, 'rel': rel, 'off': off, 'bytes': bts, 'text': rest, 'kind': kind,
                      'lineno': idx + 1, 'size': len(bts), 'tidx': len(trace) - 1})
    # sizes: up to the next listing line of the same segment that is not a continuation line (the listing
    # prints the PC on every line, so this is exact even when the bytes shown were truncated)
    for it in items:
        k = it['tidx'] + 1
        size = None
        while k < len(trace):
            s, r, o, c = trace[k]
            if not c and s == it['seg'] and r == it['rel']:
                size = o - it['off']
                break
            if not c and (s != it['seg'] or r != it['rel']):
                break
            k += 1
        if size is None or size < len(it['bytes']):
            size = len(it['bytes'])
        it['size'] = size
    return {'items': items, 'labels': labels, 'procs': procs, 'macros': macro_kinds}


# ----------------------------------------------------------------------------------------------
# 4. The analysis
# ----------------------------------------------------------------------------------------------

class Analysis:
    def __init__(self, ops, branch_info, segments, modules, exports, mem, code_segments):
        self.ops = ops
        self.br = branch_info
        self.segments = segments
        self.modules = modules
        self.exports = exports
        self.mem = mem
        self.code_segments = code_segments
        self.instrs = []        # decoded instructions (dicts) in address order
        self.data = []          # data items in code segments
        self.labels_at = {}     # address -> list of (name, kind, module)
        self.procs = []         # (start, end, name, module)
        self.problems = []
        self.by_addr = {}

    def abs_addr(self, module, item_seg, rel, off):
        if not rel:
            return off
        mod = self.modules.get(module)
        if mod is None or item_seg not in mod:
            return None
        if item_seg not in self.segments:
            return None
        return self.segments[item_seg][0] + mod[item_seg][0] + off

    def add_listing(self, module, parsed):
        for lb in parsed['labels']:
            if lb['seg'] not in self.code_segments:
                continue
            a = self.abs_addr(module, lb['seg'], lb['rel'], lb['off'])
            if a is None:
                continue
            self.labels_at.setdefault(a, []).append((lb['name'], lb['kind'], module))
        for (s, r, o0, o1, name) in parsed['procs']:
            if s not in self.code_segments:
                continue
            a0 = self.abs_addr(module, s, r, o0)
            a1 = self.abs_addr(module, s, r, o1)
            if a0 is not None and a1 is not None:
                self.procs.append((a0, a1, name, module))
        items = parsed['items']
        for ix, it in enumerate(items):
            if it['seg'] not in self.code_segments:
                continue
            a = self.abs_addr(module, it['seg'], it['rel'], it['off'])
            if a is None:
                self.problems.append('%s line %d: segment %s not in map' % (module, it['lineno'], it['seg']))
                continue
            if it['kind'] in ('data', 'res'):
                if it['size'] <= 0:
                    continue
                self.data.append({'module': module, 'seg': it['seg'], 'addr': a, 'size': it['size'],
                                  'text': it['text'], 'lineno': it['lineno'],
                                  'bytes': self.mem[a:a + it['size']].hex().upper() if it['kind'] == 'data' else ''})
                continue
            nb = it['size']
            if nb <= 0:
                continue
            # an instruction whose operand bytes the assembler put on the next (data) line: ca65's 1-byte `brk`
            # followed by `.byte 0`; the bytes are borrowed from that data item
            nxt = items[ix + 1] if ix + 1 < len(items) else None
            borrow_note = ''
            if nxt is not None and nxt['kind'] == 'data' and nxt['seg'] == it['seg'] and nxt['rel'] == it['rel'] \
                    and nxt['off'] == it['off'] + nb:
                opc0 = self.mem[a]
                op0 = self.ops.get(opc0)
                if op0 is not None and op0['length'] > nb and op0['length'] - nb <= nxt['size']:
                    spill = op0['length'] - nb
                    nxt['bytes'] = nxt['bytes'][spill:]
                    nxt['off'] += spill
                    nxt['size'] -= spill
                    nb += spill
                    borrow_note = ' [%d operand byte(s) taken from the next data line]' % spill
            # the listing's known bytes must equal the image's (proves the address mapping)
            for k, b in enumerate(it['bytes']):
                if b != 'rr' and int(b, 16) != self.mem[a + k]:
                    self.problems.append('%s line %d: listing byte %s differs from image byte %02X at $%04X' %
                                         (module, it['lineno'], b, self.mem[a + k], a + k))
            pos = 0
            first = True
            while pos < nb:
                opc = self.mem[a + pos]
                op = self.ops.get(opc)
                if op is None:
                    self.problems.append('%s line %d: illegal opcode $%02X at $%04X (%s)' %
                                         (module, it['lineno'], opc, a + pos, it['text']))
                    break
                ln = op['length']
                if pos + ln > nb:
                    self.problems.append('%s line %d: instruction %s at $%04X needs %d bytes, line has %d (%s)' %
                                         (module, it['lineno'], op['mn'], a + pos, ln, nb - pos, it['text']))
                    break
                raw = bytes(self.mem[a + pos:a + pos + ln])
                ins = {'module': module, 'seg': it['seg'], 'addr': a + pos, 'bytes': raw.hex().upper(),
                       'mn': op['mn'], 'mode': op['mode'], 'length': ln, 'cycles': op['cycles'],
                       'cross': 'no', 'target': None, 'nt': None, 'tk': None, 'tk_cross': 0,
                       'text': (it['text'] if first else '(macro expansion, same line)') + borrow_note,
                       'lineno': it['lineno'], 'opcode': opc}
                if op['cross']:
                    if op['mode'] in ('abs,x', 'abs,y'):
                        base = raw[1] | (raw[2] << 8)
                        ins['cross'] = 'possible' if (base & 0xFF) != 0 else 'impossible(low byte 00)'
                        ins['target'] = base
                    else:
                        ins['cross'] = 'possible'
                if op['branch']:
                    disp = raw[1] - 256 if raw[1] >= 128 else raw[1]
                    nxt = (a + pos + 2) & 0xFFFF
                    tgt = (nxt + disp) & 0xFFFF
                    ins['target'] = tgt
                    ins['nt'] = self.br['not_taken']
                    ins['tk'] = self.br['taken'] + (1 if (tgt >> 8) != (nxt >> 8) else 0)
                    ins['tk_cross'] = 1 if (tgt >> 8) != (nxt >> 8) else 0
                elif op['mn'] in ('JSR', 'JMP') and op['mode'] == 'abs':
                    ins['target'] = raw[1] | (raw[2] << 8)
                elif op['mn'] == 'JMP' and op['mode'] == '(ind)':
                    ins['target'] = raw[1] | (raw[2] << 8)
                elif op['mode'] in ('abs', 'zp', 'zp,x', 'zp,y', '(zp,x)', '(zp),y'):
                    ins['target'] = raw[1] | (raw[2] << 8) if ln == 3 else raw[1]
                self.instrs.append(ins)
                pos += ln
                first = False

    # ---- routines -------------------------------------------------------------------------
    def finish(self):
        self.instrs.sort(key=lambda x: x['addr'])
        self.data.sort(key=lambda x: x['addr'])
        self.by_addr = {i['addr']: i for i in self.instrs}
        for k, ins in enumerate(self.instrs):
            ins['idx'] = k
        # modules that use .proc
        proc_modules = {p[3] for p in self.procs}
        jsr_targets = {i['target'] for i in self.instrs if i['mn'] == 'JSR'}
        br_targets = {i['target'] for i in self.instrs if i['mn'] in BRANCHES}
        starts = {}
        for a, lst in self.labels_at.items():
            for name, kind, module in lst:
                if kind == 'proc':
                    starts.setdefault(a, []).append((0, name))
        for a, names in self.exports.items():
            if self.in_code_range(a):
                for name in names:
                    starts.setdefault(a, []).append((1, name))
        for a, lst in self.labels_at.items():
            for name, kind, module in lst:
                if kind != 'global':
                    continue
                inside = any(p0 <= a < p1 and p[3] == module for p0, p1, _, p in
                             [(q[0], q[1], q[2], q) for q in self.procs])
                if inside:
                    continue
                if module in proc_modules:
                    starts.setdefault(a, []).append((2, name))       # top-level label of a .proc module
                elif a in jsr_targets:
                    starts.setdefault(a, []).append((2, name))
                else:
                    prev = self.instr_before(a)
                    if prev is not None and prev['mn'] in ('RTS', 'RTI', 'JMP', 'BRK') and a not in br_targets:
                        starts.setdefault(a, []).append((3, name))
        for a in jsr_targets:
            if a not in starts and a in self.by_addr:
                starts.setdefault(a, []).append((4, self.label_name(a)))
        # code before the first start of a module chunk belongs to an implicit routine named by its label
        for module, segs in self.modules.items():
            for seg, (offs, size) in segs.items():
                if seg in self.code_segments and seg in self.segments and size:
                    a0 = self.segments[seg][0] + offs
                    if a0 in self.by_addr and a0 not in starts:
                        lst = self.labels_at.get(a0, [])
                        starts[a0] = [(5, lst[0][0] if lst else '%s@%04X' % (module[:-2], a0))]
        self.routine_starts = []
        for a in sorted(starts):
            cands = sorted(starts[a])
            self.routine_starts.append((a, cands[0][1]))
        # extents: a routine runs to the next start inside the same module chunk
        chunk_end = {}
        for module, segs in self.modules.items():
            for seg, (offs, size) in segs.items():
                if seg in self.code_segments and seg in self.segments:
                    chunk_end[(module, seg)] = self.segments[seg][0] + offs + size
        self.routines = []
        for k, (a, name) in enumerate(self.routine_starts):
            mod = self.module_of(a)
            seg = self.seg_of(a)
            end = chunk_end.get((mod, seg), a)
            if k + 1 < len(self.routine_starts):
                end = min(end, self.routine_starts[k + 1][0])
            if (name.startswith('@') or name == ':') and self.routines and self.routines[-1]['module'] == mod:
                name = '%s/%s' % (self.routines[-1]['name'], name)     # a JSR target at a cheap label
            self.routines.append({'addr': a, 'end': end, 'name': name, 'module': mod, 'seg': seg})
        # the same label name in two modules (e.g. `aplica` in logica_a_spr and teclado): disambiguate
        counts = {}
        for r in self.routines:
            counts[r['name']] = counts.get(r['name'], 0) + 1
        for r in self.routines:
            if counts[r['name']] > 1:
                r['name'] = '%s@%s' % (r['name'], r['module'][:-2] if r['module'].endswith('.o') else r['module'])
        self.routine_by_addr = {r['addr']: r for r in self.routines}
        self.routine_of_addr = {}
        for r in self.routines:
            for ins in self.instrs:
                if r['addr'] <= ins['addr'] < r['end']:
                    self.routine_of_addr[ins['addr']] = r
        for ins in self.instrs:
            r = self.routine_of_addr.get(ins['addr'])
            ins['routine'] = r['name'] if r else ''
        self.exported_of = {}
        exp_sorted = sorted(a for a in self.exports if self.in_code_range(a))
        for ins in self.instrs:
            ins['exported'] = self.nearest_below(exp_sorted, ins['addr'])

    def routine_at(self, a):
        """The routine whose extent contains address a (instructions and data alike), or None."""
        starts = getattr(self, '_starts_sorted', None)
        if starts is None:
            starts = self._starts_sorted = [r['addr'] for r in self.routines]
        lo, hi = 0, len(starts)
        while lo < hi:
            mid = (lo + hi) // 2
            if starts[mid] <= a:
                lo = mid + 1
            else:
                hi = mid
        if lo == 0:
            return None
        r = self.routines[lo - 1]
        return r if r['addr'] <= a < r['end'] else None

    def nearest_below(self, sorted_addrs, a):
        lo, hi = 0, len(sorted_addrs)
        while lo < hi:
            mid = (lo + hi) // 2
            if sorted_addrs[mid] <= a:
                lo = mid + 1
            else:
                hi = mid
        if lo == 0:
            return ''
        return self.exports[sorted_addrs[lo - 1]][0]

    def in_code_range(self, a):
        for seg in self.code_segments:
            if seg in self.segments:
                s, e, _ = self.segments[seg]
                if s <= a <= e:
                    return True
        return False

    def module_of(self, a):
        for module, segs in self.modules.items():
            for seg, (offs, size) in segs.items():
                if seg in self.code_segments and seg in self.segments:
                    s = self.segments[seg][0] + offs
                    if s <= a < s + size:
                        return module
        return ''

    def seg_of(self, a):
        for seg in self.code_segments:
            if seg in self.segments:
                s, e, _ = self.segments[seg]
                if s <= a <= e:
                    return seg
        return ''

    def instr_before(self, a):
        k = self.by_addr.get(a)
        if k is None or k['idx'] == 0:
            return None
        prev = self.instrs[k['idx'] - 1]
        if prev['addr'] + prev['length'] != a:
            return None
        return prev

    def label_name(self, a, routine=None):
        """A readable name for an address: the routine starting there, a label there, or routine+offset."""
        if hasattr(self, 'routine_by_addr') and a in self.routine_by_addr:
            return self.routine_by_addr[a]['name']
        lst = self.labels_at.get(a)
        if lst:
            order = {'proc': 0, 'global': 1, 'cheap': 2, 'anon': 3}
            best = sorted(lst, key=lambda t: order[t[1]])[0]
            if best[1] in ('cheap', 'anon'):
                r = self.routine_of_addr.get(a) if hasattr(self, 'routine_of_addr') else None
                if r:
                    return '%s/%s' % (r['name'], best[0])
            return best[0]
        if a in self.exports:
            return self.exports[a][0]
        r = self.routine_at(a) if hasattr(self, 'routines') else None
        if r:
            return '%s+$%X' % (r['name'], a - r['addr'])
        return '$%04X' % a

    def labels_text(self, a):
        lst = self.labels_at.get(a, [])
        names = [t[0] for t in lst]
        if a in self.exports:
            for n in self.exports[a]:
                if n not in names:
                    names.append(n)
        return ' '.join(names)

    # ---- loops ------------------------------------------------------------------------------
    def find_loops(self):
        loops = []
        for ins in self.instrs:
            back = False
            if ins['mn'] in BRANCHES and ins['target'] is not None and ins['target'] < ins['addr']:
                back = True
            if ins['mn'] == 'JMP' and ins['mode'] == 'abs' and ins['target'] < ins['addr'] and \
                    self.routine_of_addr.get(ins['target']) is self.routine_of_addr.get(ins['addr']):
                back = True     # a jmp to a lower address of another routine is a tail call, not a loop
            if not back:
                continue
            t = ins['target']
            if t not in self.by_addr:
                loops.append({'target': t, 'branch': ins, 'body': None, 'note': 'target is not an instruction start'})
                continue
            body = [i for i in self.instrs if t <= i['addr'] <= ins['addr']]
            # contiguity: the body must be one run of decoded instructions
            contiguous = all(body[k]['addr'] + body[k]['length'] == body[k + 1]['addr'] for k in range(len(body) - 1))
            loops.append({'target': t, 'branch': ins, 'body': body,
                          'note': '' if contiguous else 'body not contiguous (data or undecoded bytes inside)'})
        loops.sort(key=lambda L: (L['target'], -L['branch']['addr']))
        for k, L in enumerate(loops):
            L['id'] = 'L%04d' % (k + 1)
        # nesting
        for L in loops:
            L['outer'] = None
            L['depth'] = 0
            L['inner'] = []
        for L in loops:
            best = None
            for M in loops:
                if M is L:
                    continue
                if M['target'] <= L['target'] and L['branch']['addr'] <= M['branch']['addr'] and \
                        (M['target'], M['branch']['addr']) != (L['target'], L['branch']['addr']):
                    if best is None or (M['target'] >= best['target'] and M['branch']['addr'] <= best['branch']['addr']):
                        best = M
            if best is not None:
                L['outer'] = best
                best['inner'].append(L)
        for L in loops:
            d = 0
            M = L['outer']
            while M is not None:
                d += 1
                M = M['outer']
            L['depth'] = d
        for L in loops:
            self.loop_cost(L)
            self.loop_iterations(L)
        self.loops = loops
        return loops

    def loop_cost(self, L):
        body = L['body']
        if not body:
            L.update(cycles=None, cross_possible=0, nbytes=0, ninstr=0, jsrs=[], inner_cost=0)
            return
        total = 0
        crossp = 0
        jsrs = []
        for ins in body:
            if ins is L['branch']:
                total += ins['tk'] if ins['mn'] in BRANCHES else ins['cycles']
            elif ins['mn'] in BRANCHES:
                total += ins['nt']
            else:
                total += ins['cycles']
            if ins['cross'] == 'possible':
                crossp += 1
            if ins['mn'] == 'JSR':
                jsrs.append(ins['target'])
        L['cycles'] = total
        L['cross_possible'] = crossp
        L['nbytes'] = L['branch']['addr'] + L['branch']['length'] - L['target']
        L['ninstr'] = len(body)
        L['jsrs'] = jsrs

    def writes_reg(self, ins, reg):
        mn = ins['mn']
        if reg == 'X':
            return mn in ('LDX', 'TAX', 'TSX', 'INX', 'DEX')
        if reg == 'Y':
            return mn in ('LDY', 'TAY', 'INY', 'DEY')
        return False

    def writes_mem(self, ins, addr):
        return ins['mn'] in ('STA', 'STX', 'STY', 'INC', 'DEC', 'ASL', 'LSR', 'ROL', 'ROR') and \
            ins['mode'] in ('zp', 'abs') and ins['target'] == addr

    def init_scan(self, L, make_pred):
        """Find the loop counter's initializer before the loop header.

        Every entry into the header from outside the body (the straight-line predecessor, and the
        predecessor of any `jmp` to the header) is scanned backwards (same routine, no merge point crossed,
        at most 10 instructions) with a fresh predicate from make_pred(); all entries must give the same
        constant.  A conditional branch into the header from outside the body makes the count unknown
        (the initializer may be bypassed).
        """
        t = L['target']
        b = L['branch']['addr']
        r = self.routine_of_addr.get(t)
        all_targets = {i['target'] for i in self.instrs if i['mn'] in BRANCHES or (i['mn'] == 'JMP' and i['mode'] == 'abs')}
        entries = []
        prev = self.instr_before(t)
        if prev is not None and prev['mn'] not in ('JMP', 'RTS', 'RTI'):
            entries.append(prev)
        for i in self.instrs:
            if i['target'] != t or (t <= i['addr'] <= b):
                continue
            if i['mn'] in BRANCHES:
                return None, 'header also entered by a conditional branch at $%04X' % i['addr']
            if i['mn'] == 'JMP' and i['mode'] == 'abs':
                p = self.instr_before(i['addr'])
                if p is None:
                    return None, 'jmp entry at $%04X has no predecessor' % i['addr']
                entries.append(p)
        if not entries:
            return None, 'no entry path into the loop header'
        values = []
        for first in entries:
            pred = make_pred()
            cur = first
            steps = 0
            found = None
            why = 'no initializer within 10 instructions'
            while steps < 10:
                if r is not None and self.routine_of_addr.get(cur['addr']) is not r:
                    why = 'routine start reached'
                    break
                res = pred(cur)
                if res == 'stop':
                    why = 'register/variable written by %s before the loop' % cur['mn']
                    break
                if res is not None:
                    found = res
                    break
                if cur['addr'] in all_targets:
                    why = 'merge point (branch target) before the loop'
                    break
                if cur['mn'] in ('JSR', 'RTS', 'RTI', 'JMP'):
                    why = 'call/jump before the loop'
                    break
                nxt = self.instr_before(cur['addr'])
                if nxt is None:
                    why = 'no straight-line predecessor'
                    break
                cur = nxt
                steps += 1
            if found is None:
                return None, why
            values.append(found)
        if len(set(values)) != 1:
            return None, 'entry paths initialise different values (%s)' % ', '.join(str(v) for v in values)
        return values[0], ''

    def loop_iterations(self, L):
        """iters/pattern/product/max_iter/exits of a loop.  A count is constant only when the closing branch's
        fall-through is the loop's only exit; with other exits (a branch or jmp leaving [target, branch], an
        rts/rti, an indirect jmp) the count found is an upper bound and the loop is variable."""
        L['max_iter'] = None
        L['exits'] = []
        self._loop_count(L)
        body = L['body']
        if not body:
            return
        t, b = L['target'], L['branch']['addr']
        exits = []
        for i in body[:-1]:
            if i['mn'] in BRANCHES and not (t <= i['target'] <= b):
                exits.append(i['addr'])
            elif i['mn'] == 'JMP' and (i['mode'] == '(ind)' or not (t <= i['target'] <= b)):
                exits.append(i['addr'])
            elif i['mn'] in ('RTS', 'RTI'):
                exits.append(i['addr'])
        L['exits'] = exits
        if L['product'] is not None:
            L['max_iter'] = L['product']
            if exits:
                L['iters'] = 'variable (bounded by: <= %d%s; other exits at %s)' % (
                    L['product'], L['iters'][len(str(L['product'])):], ' '.join('$%04X' % x for x in exits))
                L['product'] = None
        elif exits and L['iters'].startswith('variable (bounded by: ') and L['iters'].endswith(')'):
            L['iters'] = L['iters'][:-1] + '; other exits at %s)' % ' '.join('$%04X' % x for x in exits)
        m = re.search(r'<= (\d+)', L['iters'])
        if L['max_iter'] is None and m:
            L['max_iter'] = int(m.group(1))

    def _loop_count(self, L):
        body = L['body']
        L['iters'] = ''
        L['pattern'] = ''
        L['product'] = None
        if not body:
            L['iters'] = 'unknown'
            L['pattern'] = L['note']
            return
        br = L['branch']
        prev = body[-2] if len(body) >= 2 else None
        prev2 = body[-3] if len(body) >= 3 else None
        inner_body = body[:-1]
        if br['mn'] == 'JMP':
            L['iters'] = 'variable (bounded by: exits only through a forward branch inside the body)'
            L['pattern'] = 'jmp back-edge'
            return
        if prev is None:
            L['iters'] = 'variable (bounded by: ?)'
            L['pattern'] = 'empty body'
            return
        note_calls = ' (JSR in body: holds if the callees keep the counter)' if any(i['mn'] == 'JSR' for i in inner_body) else ''

        def reg_body_clean(reg, exclude):
            return not any(self.writes_reg(i, reg) for i in inner_body if i is not exclude)

        def ld_imm(reg):
            def pred(ins):
                if ins['mn'] == 'LD' + reg and ins['mode'] == 'imm':
                    return int(ins['bytes'][2:4], 16)
                if self.writes_reg(ins, reg):
                    return 'stop'
                return None
            return pred

        # (a) dex/dey ; bne|bpl        (b) inx/iny ; bne
        if prev['mn'] in ('DEX', 'DEY', 'INX', 'INY') and br['mn'] in ('BNE', 'BPL', 'BMI'):
            reg = prev['mn'][2]
            clean = reg_body_clean(reg, prev)
            n0, why = self.init_scan(L, lambda: ld_imm(reg))
            if n0 is not None and clean:
                if prev['mn'][:2] == 'DE' and br['mn'] == 'BNE':
                    it = n0 if n0 else 256
                elif prev['mn'][:2] == 'DE' and br['mn'] == 'BPL':
                    it = (n0 + 1) if n0 < 128 else None
                elif prev['mn'][:2] == 'IN' and br['mn'] == 'BNE':
                    it = (256 - n0) if n0 else 256
                elif prev['mn'][:2] == 'IN' and br['mn'] == 'BMI':
                    it = (256 - n0) if n0 >= 128 else None
                else:
                    it = None
                if it is not None:
                    L['iters'] = str(it) + note_calls
                    L['pattern'] = 'ld%s #%d ... %s/%s' % (reg.lower(), n0, prev['mn'].lower(), br['mn'].lower())
                    L['product'] = it
                    return
            bound = {'BNE': '<= 256', 'BPL': '<= 128', 'BMI': '<= 128'}[br['mn']]
            L['iters'] = 'variable (bounded by: %s at entry, %s%s)' % (reg, bound, '' if clean else '; %s rewritten in the body' % reg)
            L['pattern'] = '%s/%s without constant init (%s)' % (prev['mn'].lower(), br['mn'].lower(), why if not n0 else 'body rewrites ' + reg)
            return
        # (c) inx/dex ; cpx #M ; bne|bcc|bcs
        if prev['mn'] in ('CPX', 'CPY') and prev['mode'] == 'imm' and prev2 is not None and \
                prev2['mn'] in ('INX', 'INY', 'DEX', 'DEY') and prev2['mn'][2] == prev['mn'][2]:
            reg = prev['mn'][2]
            m_ = int(prev['bytes'][2:4], 16)
            clean = reg_body_clean(reg, prev2)
            n0, why = self.init_scan(L, lambda: ld_imm(reg))
            if n0 is not None and clean:
                it = None
                if prev2['mn'][:2] == 'IN':
                    if br['mn'] == 'BNE':
                        it = (m_ - n0) % 256 or 256
                    elif br['mn'] == 'BCC' and n0 < m_:
                        it = m_ - n0
                    elif br['mn'] == 'BEQ':
                        it = None
                else:
                    if br['mn'] == 'BNE':
                        it = (n0 - m_) % 256 or 256
                    elif br['mn'] == 'BCS' and n0 >= m_:
                        it = n0 - m_ + 1
                if it is not None:
                    L['iters'] = str(it) + note_calls
                    L['pattern'] = 'ld%s #%d ... %s ; cp%s #%d ; %s' % (reg.lower(), n0, prev2['mn'].lower(), reg.lower(), m_, br['mn'].lower())
                    L['product'] = it
                    return
            L['iters'] = 'variable (bounded by: %s at entry vs #%d, %s, <= 256)' % (reg, m_, br['mn'].lower())
            L['pattern'] = '%s ; cp%s #imm ; %s without constant init (%s)' % (prev2['mn'].lower(), reg.lower(), br['mn'].lower(), why if not n0 else 'body rewrites ' + reg)
            return
        # (c') cpx/cpy #M ; bne with iny/inx earlier in the body (not immediately before)
        if prev['mn'] in ('CPX', 'CPY') and prev['mode'] == 'imm':
            reg = prev['mn'][2]
            m_ = int(prev['bytes'][2:4], 16)
            steps = [i for i in inner_body if i['mn'] in ('IN' + reg, 'DE' + reg)]
            others = [i for i in inner_body if self.writes_reg(i, reg) and i['mn'] not in ('IN' + reg, 'DE' + reg)]
            if len(steps) == 1 and not others:
                n0, why = self.init_scan(L, lambda: ld_imm(reg))
                if n0 is not None:
                    it = None
                    if steps[0]['mn'][:2] == 'IN' and br['mn'] == 'BNE':
                        it = (m_ - n0) % 256 or 256
                    elif steps[0]['mn'][:2] == 'IN' and br['mn'] == 'BCC' and n0 < m_:
                        it = m_ - n0
                    elif steps[0]['mn'][:2] == 'DE' and br['mn'] == 'BNE':
                        it = (n0 - m_) % 256 or 256
                    elif steps[0]['mn'][:2] == 'DE' and br['mn'] == 'BCS' and n0 >= m_:
                        it = n0 - m_ + 1
                    if it is not None:
                        L['iters'] = str(it) + note_calls
                        L['pattern'] = 'ld%s #%d ... %s (in body) ... cp%s #%d ; %s' % (reg.lower(), n0, steps[0]['mn'].lower(), reg.lower(), m_, br['mn'].lower())
                        L['product'] = it
                        return
            L['iters'] = 'variable (bounded by: %s vs #%d, %s, <= 256)' % (reg, m_, br['mn'].lower())
            L['pattern'] = 'cp%s #imm ; %s (counter step not recognised)' % (reg.lower(), br['mn'].lower())
            return
        # (d) dec var / inc var ; bne
        if prev['mn'] in ('DEC', 'INC') and prev['mode'] in ('zp', 'abs') and br['mn'] in ('BNE', 'BPL'):
            var = prev['target']
            clean = not any(self.writes_mem(i, var) for i in inner_body if i is not prev)

            def make_pred():
                state = {'reg': None}

                def pred(ins):
                    if ins['mn'] in ('STA', 'STX', 'STY') and ins['mode'] in ('zp', 'abs') and ins['target'] == var and state['reg'] is None:
                        state['reg'] = ins['mn'][2]
                        return None
                    if state['reg'] is not None:
                        reg = state['reg']
                        if ins['mn'] == 'LD' + reg and ins['mode'] == 'imm':
                            return int(ins['bytes'][2:4], 16)
                        if (reg == 'A' and ins['mn'] in ('LDA', 'TXA', 'TYA', 'PLA', 'ADC', 'SBC', 'AND', 'ORA', 'EOR', 'ASL', 'LSR', 'ROL', 'ROR')) \
                                or (reg in 'XY' and self.writes_reg(ins, reg)):
                            return 'stop'
                        return None
                    if self.writes_mem(ins, var):
                        return 'stop'
                    return None
                return pred
            n0, why = self.init_scan(L, make_pred)
            if n0 is not None and clean:
                if prev['mn'] == 'DEC' and br['mn'] == 'BNE':
                    it = n0 if n0 else 256
                elif prev['mn'] == 'DEC' and br['mn'] == 'BPL':
                    it = n0 + 1 if n0 < 128 else None
                elif prev['mn'] == 'INC' and br['mn'] == 'BNE':
                    it = (256 - n0) if n0 else 256
                else:
                    it = None
                if it is not None:
                    L['iters'] = str(it) + note_calls
                    L['pattern'] = 'store #%d to $%04X ... %s $%04X ; %s' % (n0, var, prev['mn'].lower(), var, br['mn'].lower())
                    L['product'] = it
                    return
            L['iters'] = 'variable (bounded by: $%04X at entry, <= 256%s)' % (var, '' if clean else '; variable rewritten in the body')
            L['pattern'] = '%s mem ; %s without constant init (%s)' % (prev['mn'].lower(), br['mn'].lower(), why if not n0 else 'body rewrites the variable')
            return
        # data-dependent exits
        L['iters'] = 'variable (bounded by: data: %s %s then %s)' % (prev['mn'].lower(), prev['mode'], br['mn'].lower())
        L['pattern'] = 'data-dependent'

    # ---- calls ------------------------------------------------------------------------------
    def call_graph(self):
        """edges: routine start address -> [(JSR|JMP, target address, target routine or None, call address)]."""
        edges = {}
        for ins in self.instrs:
            if ins['mn'] == 'JSR' or (ins['mn'] == 'JMP' and ins['mode'] == 'abs'):
                r = self.routine_of_addr.get(ins['addr'])
                tr = self.routine_of_addr.get(ins['target'])
                if r is None:
                    continue
                edges.setdefault(r['addr'], []).append((ins['mn'], ins['target'], tr, ins['addr']))
        self.edges = edges
        return edges

    def reach(self, root_name):
        """The routines reached from root_name through JSR and JMP (a jmp into the middle of a routine counts)."""
        roots = [r for r in self.routines if r['name'] == root_name]
        if not roots:
            return set()
        seen = set()
        stack = [roots[0]['addr']]
        while stack:
            a = stack.pop()
            if a in seen:
                continue
            seen.add(a)
            for mn, tgt, tr, at in self.edges.get(a, []):
                if tr is not None and tr['addr'] not in seen:
                    stack.append(tr['addr'])
        return seen


# ----------------------------------------------------------------------------------------------
# 5. Outputs
# ----------------------------------------------------------------------------------------------

def write_tsv(path, header, rows):
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\t'.join(header) + '\n')
        for r in rows:
            f.write('\t'.join('' if v is None else str(v) for v in r) + '\n')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--c6502', required=True, help="sim65's 6502.c (the cycle source)")
    ap.add_argument('--map', required=True, help='ld65 map file (-m)')
    ap.add_argument('--lbl', default='', help='ld65 VICE label file (-Ln): the exported routines')
    ap.add_argument('--bin', required=True, help='the linked image')
    ap.add_argument('--bin-skip', type=int, default=0, help='bytes to skip at the start of --bin (a header)')
    ap.add_argument('--bin-base', type=lambda s: int(s, 0), default=0, help='address of the first byte after --bin-skip')
    ap.add_argument('--lst', nargs='+', required=True, help='ca65 listings (-l)')
    ap.add_argument('--segments', default='CODE,BAJO', help='code segments to analyse (comma separated)')
    ap.add_argument('--define', action='append', default=[], help='symbol defined for .ifdef (repeatable)')
    ap.add_argument('--root', default='', help='routine whose JSR/JMP closure is reported (e.g. spr_draw_all)')
    ap.add_argument('--out', required=True, help='output directory')
    a = ap.parse_args(argv)

    ops, branch_info, meta = parse_6502c(a.c6502)
    segments, modules = parse_map(a.map)
    exports = parse_lbl(a.lbl)
    mem = load_image(a.bin, a.bin_skip, a.bin_base)
    code_segments = [s for s in a.segments.split(',') if s]
    an = Analysis(ops, branch_info, segments, modules, exports, mem, code_segments)
    defined = set(a.define)
    for lst in sorted(a.lst):
        module = os.path.splitext(os.path.basename(lst))[0] + '.o'
        if module not in modules:
            an.problems.append('%s: module %s not in the map (listing ignored)' % (lst, module))
            continue
        parsed = parse_listing(lst, defined)
        an.add_listing(module, parsed)
    an.finish()
    loops = an.find_loops()
    edges = an.call_graph()
    os.makedirs(a.out, exist_ok=True)

    # tabla_opcodes.tsv
    rows = []
    for opc in sorted(ops):
        op = ops[opc]
        rows.append(['%02X' % opc, op['mn'], op['mode'], op['length'], op['cycles'],
                     'yes' if op['cross'] else 'no',
                     ('%d' % branch_info['not_taken']) if op['branch'] else '',
                     ('%d' % branch_info['taken']) if op['branch'] else '',
                     ('%d' % branch_info['taken_cross']) if op['branch'] else '',
                     op['handler'], op['src']])
    write_tsv(os.path.join(a.out, 'tabla_opcodes.tsv'),
              ['opcode', 'mnemonic', 'mode', 'bytes', 'cycles', 'page_cross_plus1', 'branch_not_taken', 'branch_taken',
               'branch_taken_page_cross', 'handler', 'source_6502c'], rows)

    # instrucciones.tsv (instructions and data items of the code segments, by address)
    rows = []
    entries = [('i', i) for i in an.instrs] + [('d', d) for d in an.data]
    entries.sort(key=lambda e: (e[1]['addr'], e[0]))
    for kind, e in entries:
        if kind == 'i':
            tgt = ''
            if e['target'] is not None and (e['mn'] in BRANCHES or e['mn'] in ('JSR', 'JMP')):
                tgt = '$%04X %s' % (e['target'], an.label_name(e['target']))
            rows.append([e['module'], e['seg'], '%04X' % e['addr'], e['bytes'], an.labels_text(e['addr']), e['routine'],
                         e['exported'], e['mn'], e['mode'], e['length'], e['cycles'], e['cross'],
                         e['nt'] if e['nt'] is not None else '', e['tk'] if e['tk'] is not None else '',
                         e['tk_cross'] if e['mn'] in BRANCHES else '', tgt, e['lineno'], e['text']])
        else:
            r = an.routine_at(e['addr'])
            rows.append([e['module'], e['seg'], '%04X' % e['addr'], e['bytes'][:48], an.labels_text(e['addr']),
                         r['name'] if r else '', '', 'DATA', '', e['size'], '', '', '', '', '', '', e['lineno'], e['text']])
    write_tsv(os.path.join(a.out, 'instrucciones.tsv'),
              ['module', 'segment', 'addr', 'bytes', 'labels', 'routine', 'exported_routine', 'mnemonic', 'mode', 'length',
               'cycles', 'page_cross_plus1', 'branch_not_taken', 'branch_taken', 'branch_taken_page_cross', 'target',
               'lst_line', 'source'], rows)

    # bucles.tsv
    def loop_sort_key(L):
        if L.get('product') is not None and L.get('cycles') is not None:
            return (0, -(L['cycles'] * L['product']), L['target'])
        return (1, -(L['cycles'] or 0), L['target'])
    rows = []
    for L in sorted(loops, key=loop_sort_key):
        br = L['branch']
        r = an.routine_of_addr.get(br['addr'])
        tr = an.routine_of_addr.get(L['target'])
        rows.append([L['id'], br['module'], r['name'] if r else '', '%04X' % L['target'], an.label_name(L['target']),
                     '%04X' % br['addr'], br['mn'], 'jmp' if br['mn'] == 'JMP' else 'cond',
                     L.get('nbytes'), L.get('ninstr'), L.get('cycles'), L.get('cross_possible'), br['tk_cross'],
                     L['iters'], L['pattern'],
                     (L['cycles'] * L['product']) if (L.get('product') is not None and L.get('cycles') is not None) else '',
                     L['max_iter'] if L['max_iter'] is not None else '',
                     ' '.join('$%04X' % x for x in L['exits']),
                     L['depth'], L['outer']['id'] if L['outer'] else '', ' '.join(x['id'] for x in L['inner']),
                     ' '.join(an.label_name(t) for t in L.get('jsrs', [])),
                     'yes' if (tr is not r) else 'no', L['note'], br['lineno']])
    write_tsv(os.path.join(a.out, 'bucles.tsv'),
              ['id', 'module', 'routine', 'target', 'target_label', 'branch_addr', 'branch', 'kind', 'body_bytes',
               'body_instructions', 'body_cycles_per_iteration', 'page_cross_plus1_possible_in_body',
               'branch_taken_page_cross', 'iterations', 'pattern', 'cycles_x_iterations', 'max_iterations', 'other_exits',
               'nesting_depth', 'outer_loop', 'inner_loops', 'jsr_in_body', 'crosses_routine', 'note', 'lst_line'], rows)

    # rutinas.tsv
    reach = an.reach(a.root) if a.root else set()
    rows = []
    for r in an.routines:
        ins = [i for i in an.instrs if r['addr'] <= i['addr'] < r['end']]
        dat = [d for d in an.data if r['addr'] <= d['addr'] < r['end']]
        c_nt = sum(i['nt'] if i['mn'] in BRANCHES else i['cycles'] for i in ins)
        c_tk = sum(i['tk'] if i['mn'] in BRANCHES else i['cycles'] for i in ins)
        crossp = sum(1 for i in ins if i['cross'] == 'possible')
        rl = [L for L in loops if an.routine_of_addr.get(L['branch']['addr']) is r]
        calls = edges.get(r['addr'], [])
        jsrs = sorted({(c[2]['name'] if c[2] else '$%04X' % c[1]) for c in calls if c[0] == 'JSR'})
        jmps = sorted({(c[2]['name'] if c[2] else '$%04X' % c[1]) for c in calls if c[0] == 'JMP' and c[2] is not r})
        ind = sum(1 for i in ins if i['mn'] == 'JMP' and i['mode'] == '(ind)')
        rows.append([r['name'], r['module'], r['seg'], '%04X' % r['addr'], '%04X' % r['end'], r['end'] - r['addr'],
                     sum(i['length'] for i in ins), sum(d['size'] for d in dat), len(ins), c_nt, c_tk, crossp,
                     len(rl), ' '.join(L['id'] for L in rl), ' '.join(jsrs), ' '.join(jmps), ind,
                     'yes' if r['addr'] in exports else 'no', 'yes' if r['addr'] in reach else ''])
    write_tsv(os.path.join(a.out, 'rutinas.tsv'),
              ['routine', 'module', 'segment', 'start', 'end', 'bytes', 'bytes_code', 'bytes_data', 'instructions',
               'cycles_sum_branches_not_taken', 'cycles_sum_branches_taken', 'page_cross_plus1_possible', 'loops',
               'loop_ids', 'jsr_targets', 'jmp_targets_outside', 'jmp_indirect', 'exported', 'reached_from_root'], rows)

    # llamadas.tsv
    rows = []
    for r in an.routines:
        for mn, tgt, tr, at in edges.get(r['addr'], []):
            rows.append([r['name'], mn, '%04X' % at, '%04X' % tgt, tr['name'] if tr else '', an.label_name(tgt)])
    write_tsv(os.path.join(a.out, 'llamadas.tsv'), ['caller', 'kind', 'at', 'target', 'target_routine', 'target_label'], rows)

    summary = {
        'cycle_source': meta['file'], 'op6502table_lines': list(meta['table_lines']),
        'branch': {k: v for k, v in branch_info.items() if k != 'lines'}, 'branch_lines': list(branch_info['lines']),
        'legal_opcodes': len(ops), 'segments': {s: list(segments[s]) for s in code_segments if s in segments},
        'instructions': len(an.instrs), 'code_bytes': sum(i['length'] for i in an.instrs),
        'data_bytes_in_code_segments': sum(d['size'] for d in an.data), 'routines': len(an.routines),
        'loops': len(loops), 'loops_constant': sum(1 for L in loops if L.get('product') is not None),
        'root': a.root, 'reached_from_root': sorted(an.routine_by_addr[x]['name'] for x in reach), 'problems': an.problems,
    }
    with open(os.path.join(a.out, 'resumen.json'), 'w', encoding='utf-8') as f:
        json.dump(summary, f, indent=1, sort_keys=True)
        f.write('\n')
    print('instructions %d (%d bytes), data in code segments %d bytes, routines %d, loops %d (%d constant), problems %d'
          % (len(an.instrs), summary['code_bytes'], summary['data_bytes_in_code_segments'], len(an.routines),
             len(loops), summary['loops_constant'], len(an.problems)))
    for p in an.problems[:40]:
        print('PROBLEM:', p)
    return 0


if __name__ == '__main__':
    sys.exit(main())
