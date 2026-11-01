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

"""prueba_sim65.py: checks ciclos6502.py against reality (cc65's sim65, `sim65 --cycles`).

Two experiments, both deterministic (same tools -> byte-identical autocomprobacion.tsv):
 1. Per opcode: for every legal 6502 opcode a tiny program (12-byte sim65 header per sim65.sgml
    "Creating a Test in Assembly", load/reset $0200, exit by `jmp $FFF9` whose cycles sim65 does not
    count) runs `setup ; INSN ; lda #0 ; jmp $FFF9` and its baseline without INSN; the difference of the
    two measured cycle counts is the instruction's cost, measured twice: with X=Y=0 and bases $xx00 (no
    page crossing) and with X=Y=$FF and bases $xxFF (every indexed read crosses a page).  The branches
    are measured not taken, taken, and taken across a page boundary (the branch placed at $02FC).  Each
    measured value is compared with ciclos6502.py's instrucciones.tsv row for that instruction.
 2. Loops: one program with counted loops (dex/bne, iny/cpy/bne, nested, dec zp/bne, indexed reads that
    always / never cross a page, inx/bne 256, dex/bpl, a backward branch across a page boundary);
    ciclos6502.py's loop table (constant iteration counts) predicts the total; sim65 measures it.
Usage: python3 -I prueba_sim65.py --cc65 BIN_DIR --c6502 6502.c --analizador ciclos6502.py --out DIR
"""
import argparse
import csv
import os
import re
import subprocess
import sys

CFG = '''MEMORY {
    ZP:   start = $0000, size = $0100, file = "";
    HDR:  start = $0000, size = $000C, file = %O;
    MAIN: start = $0200, size = $FD00, file = %O;
}
SEGMENTS {
    HEADER: load = HDR,  type = ro;
    MAIN:   load = MAIN, type = rw;
}
'''
HEADER = '''.segment "HEADER"
        .byte   "sim65", 2, 0, $00      ; signature, version 2, CPU 6502, c_sp (unused)
        .word   $0200, $0200            ; load address, reset address
.segment "MAIN"
        .org    $0200
'''
TAIL = '''        lda     #0
        jmp     $FFF9                   ; sim65 exit (not counted by --cycles)
'''


def run(cmd, cwd):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if p.returncode != 0 and not cmd[0].endswith('sim65'):
        raise SystemExit('%s failed:\n%s\n%s' % (' '.join(cmd), p.stdout, p.stderr))
    return p


def build_and_measure(name, source, tools, work):
    """Assemble, link, run under sim65 --cycles.  Returns (cycles, lst, map, bin, lbl)."""
    src = os.path.join(work, name + '.s')
    with open(src, 'w', encoding='utf-8') as f:
        f.write(source)
    with open(os.path.join(work, 'prueba.cfg'), 'w', encoding='utf-8') as f:
        f.write(CFG)
    obj, lst = name + '.o', name + '.lst'
    binf, mapf, lbl = name + '.bin', name + '.map', name + '.lbl'
    run([tools['ca65'], '-l', lst, '-o', obj, name + '.s'], work)
    run([tools['ld65'], '-C', 'prueba.cfg', '-o', binf, '-Ln', lbl, '-m', mapf, obj], work)
    p = subprocess.run([tools['sim65'], '--cycles', binf], cwd=work, capture_output=True, text=True)
    m = re.search(r'(\d+) cycles', p.stdout)
    if not m:
        raise SystemExit('sim65 gave no cycle count for %s: rc=%d %s %s' % (name, p.returncode, p.stdout, p.stderr))
    return int(m.group(1)), os.path.join(work, lst), os.path.join(work, mapf), os.path.join(work, binf), os.path.join(work, lbl)


def analyse(tools, lst, mapf, binf, lbl, outdir):
    cmd = [sys.executable, '-I', tools['analizador'], '--c6502', tools['c6502'], '--map', mapf, '--lbl', lbl,
           '--bin', binf, '--bin-skip', '12', '--bin-base', '0x200', '--lst', lst, '--segments', 'MAIN', '--out', outdir]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        raise SystemExit('analyser failed: %s %s' % (p.stdout, p.stderr))
    rows = list(csv.DictReader(open(os.path.join(outdir, 'instrucciones.tsv'), encoding='utf-8'), delimiter='\t'))
    loops = list(csv.DictReader(open(os.path.join(outdir, 'bucles.tsv'), encoding='utf-8'), delimiter='\t'))
    return rows, loops


def opcode_table(tools):
    """The table as ciclos6502.py builds it (tabla_opcodes.tsv of a dummy run is not needed: import-free)."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(tools['analizador'])))
    import ciclos6502
    ops, br, meta = ciclos6502.parse_6502c(tools['c6502'])
    return ops, br


OPERAND = {
    'imm': '#$01', 'zp': '$90', 'zp,x': '$90,x', 'zp,y': '$90,y', 'abs': '$0500', 'acc': 'a', 'impl': '',
    '(zp,x)': '($80,x)', '(zp),y': '($80),y', '(ind)': '($80)',
}


def setup_lines(cross):
    v = '$FF' if cross else '$00'
    return ('        ldx     #%s\n        ldy     #%s\n        lda     #%s\n        sta     $80\n'
            '        lda     #$05\n        sta     $81\n        lda     #$02\n        sta     $82\n'
            '        lda     #$FF\n        sta     $83\n' % (v, v, v))


def per_opcode_cases(ops):
    """Yield (name, setup, insn_lines, expected_cross_flag) for every legal opcode."""
    for opc in sorted(ops):
        op = ops[opc]
        mn = op['mn'].lower()
        mode = op['mode']
        if mode == 'rel':
            continue
        for cross in (False, True):
            if mode in ('abs,x', 'abs,y'):
                operand = ('$05FF' if cross else '$0500') + (',x' if mode == 'abs,x' else ',y')
            else:
                operand = OPERAND[mode]
            setup = setup_lines(cross)
            # helper instructions inside the measured part (their cost is taken from the table: listed as `extra`)
            extra = []
            if op['mn'] == 'BRK':
                # the IRQ vector must point past the BRK (BRK pushes PC+2 and jumps through $FFFE)
                insn = ('        lda     #<ret_%02X\n        sta     $FFFE\n        lda     #>ret_%02X\n        sta     $FFFF\n'
                        '        brk\n        .byte 0\nret_%02X:\n' % (opc, opc, opc))
                extra = [0xA9, 0x8D, 0xA9, 0x8D]
            elif op['mn'] == 'JSR':
                insn = '        jsr     sub_%02X\nsub_%02X:\n        pla\n        pla\n' % (opc, opc)
                extra = [0x68, 0x68]        # the two pulls drop the return address
            elif op['mn'] == 'RTS':
                insn = ('        lda     #>(ret_%02X-1)\n        pha\n        lda     #<(ret_%02X-1)\n        pha\n'
                        '        rts\nret_%02X:\n' % (opc, opc, opc))
                extra = [0xA9, 0x48, 0xA9, 0x48]
            elif op['mn'] == 'RTI':
                insn = ('        lda     #>ret_%02X\n        pha\n        lda     #<ret_%02X\n        pha\n        php\n'
                        '        rti\nret_%02X:\n' % (opc, opc, opc))
                extra = [0xA9, 0x48, 0xA9, 0x48, 0x08]
            elif op['mn'] == 'JMP' and mode == 'abs':
                insn = '        jmp     ret_%02X\nret_%02X:\n' % (opc, opc)
            elif op['mn'] == 'JMP' and mode == '(ind)':
                insn = ('        lda     #<ret_%02X\n        sta     $84\n        lda     #>ret_%02X\n        sta     $85\n'
                        '        jmp     ($84)\nret_%02X:\n' % (opc, opc, opc))
                extra = [0xA9, 0x85, 0xA9, 0x85]
            elif op['mn'] in ('TXS',):
                insn = '        txs\n'
            else:
                insn = '        %s     %s\n' % (mn, operand) if operand else '        %s\n' % mn
            yield ('op%02X_%s' % (opc, 'cross' if cross else 'nocross'), setup, insn, cross, op, extra)
            if mode in ('impl', 'acc', 'imm', 'zp', 'zp,x', 'zp,y', 'abs', '(zp,x)', '(ind)') and not cross:
                break   # a second variant is pointless without an indexed read


def branch_cases(ops):
    """(name, setup, insn, kind) for the 8 branches: not taken / taken / taken across a page."""
    flag_setup = {
        'BCC': ('        clc\n', '        sec\n'), 'BCS': ('        sec\n', '        clc\n'),
        'BEQ': ('        lda     #0\n', '        lda     #1\n'), 'BNE': ('        lda     #1\n', '        lda     #0\n'),
        'BMI': ('        lda     #$80\n', '        lda     #1\n'), 'BPL': ('        lda     #1\n', '        lda     #$80\n'),
        'BVS': ('        bit     $82\n', '        clv\n'), 'BVC': ('        clv\n', '        bit     $82\n'),
    }
    for opc in sorted(ops):
        op = ops[opc]
        if op['mode'] != 'rel':
            continue
        mn = op['mn']
        take, notake = flag_setup[mn]
        base = setup_lines(False) + '        lda     #$40\n        sta     $82\n'
        yield ('br%02X_nt' % opc, base + notake, '        %s     *+2\n' % mn.lower(), 'not_taken', op, [])
        yield ('br%02X_tk' % opc, base + take, '        %s     *+2\n' % mn.lower(), 'taken', op, [])
        pad = '        .res    $02FC - *, $EA\n'     # NOP fill, executed in both the test and its baseline
        insn = '        %s     dest_%02X\n        .res    2\ndest_%02X:\n' % (mn.lower(), opc, opc)
        yield ('br%02X_tkx' % opc, base + take + pad, insn, 'taken_cross', op, [])


LOOPS_SRC = '''        ldx     #10
l1:     dex
        bne     l1                      ; 10 iterations
        ldy     #0
l2:     iny
        cpy     #20
        bne     l2                      ; 20
        ldx     #5
l3:     ldy     #3
l4:     dey
        bne     l4                      ; inner 3 x outer 5
        dex
        bne     l3
        lda     #7
        sta     $80
l5:     dec     $80
        bne     l5                      ; 7
        ldx     #4
l6:     lda     $03FF,x                 ; X = 4..1: every read crosses a page (+1 each)
        dex
        bne     l6
        ldx     #4
l7:     lda     $0300,x                 ; never crosses
        dex
        bne     l7
        jsr     sub
        ldx     #0
l8:     inx
        bne     l8                      ; 256
        ldx     #3
l9:     dex
        bpl     l9                      ; 4 (X = 3,2,1,0)
        ldy     #2
        ldx     #6
        jmp     l10
        .res    $03FD - *               ; never executed
l10:    dex                             ; at $03FD
        bne     l10                     ; the taken branch crosses from $0400 back to $03FD: 4 cycles, 6 times
        ldx     #5
l11:    cpx     #$77
        beq     salida                  ; an exit never taken: the analyser must give "<= 5", not "5"
        dex
        bne     l11
salida:
'''
LOOPS_SUB = '''sub:    rts
'''


def predict_loops(rows, loops):
    """Total cycles of a program made of counted loops, from the analyser's tables (see the docstring)."""
    ins = [r for r in rows if r['mnemonic'] != 'DATA']
    cl = []
    bounds_used = []
    for L in loops:
        it = L['iterations']
        if not it.isdigit():
            if L['max_iterations'].isdigit():
                it = L['max_iterations']        # the test's extra exit is never taken: the bound is the count
                bounds_used.append(L['id'])
            else:
                return None, 'loop %s has no constant iteration count: %s' % (L['id'], it)
        cl.append((int(L['target'], 16), int(L['branch_addr'], 16), int(it)))
    lo = hi = 0
    for r in ins:
        a = int(r['addr'], 16)
        if r['mnemonic'] == 'JMP' and r['target'].startswith('$FFF9'):
            continue
        count = 1
        for (t, b, it) in cl:
            if t <= a <= b:
                count *= it
        if r['mnemonic'] in ('BCC', 'BCS', 'BEQ', 'BNE', 'BPL', 'BMI', 'BVC', 'BVS'):
            mine = [x for x in cl if x[1] == a]
            if mine:
                t, b, it = mine[0]
                outer = count // it
                c = outer * ((it - 1) * int(r['branch_taken']) + int(r['branch_not_taken']))
            else:
                c = count * int(r['branch_not_taken'])
            lo += c
            hi += c
        else:
            c = count * int(r['cycles'])
            lo += c
            hi += c + (count if r['page_cross_plus1'] == 'possible' else 0)
    return (lo, hi), ('bound used as the count for ' + ' '.join(bounds_used) if bounds_used else '')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--cc65', required=True, help='cc65 bin directory (ca65, ld65, sim65)')
    ap.add_argument('--c6502', required=True)
    ap.add_argument('--analizador', required=True, help='path of ciclos6502.py')
    ap.add_argument('--out', required=True)
    a = ap.parse_args(argv)
    tools = {'ca65': os.path.join(a.cc65, 'ca65'), 'ld65': os.path.join(a.cc65, 'ld65'), 'sim65': os.path.join(a.cc65, 'sim65'),
             'c6502': os.path.abspath(a.c6502), 'analizador': os.path.abspath(a.analizador)}
    os.makedirs(a.out, exist_ok=True)
    work = os.path.join(a.out, 'trabajo')
    os.makedirs(work, exist_ok=True)
    ops, br = opcode_table(tools)
    results = []
    bad = 0
    # ---- 1. per opcode -------------------------------------------------------------------
    cases = list(per_opcode_cases(ops)) + list(branch_cases(ops))
    for name, setup, insn, kind, op, extra_ops in cases:
        base_src = HEADER + setup + TAIL
        test_src = HEADER + setup + insn + TAIL
        c0, _, _, _, _ = build_and_measure(name + '_base', base_src, tools, work)
        c1, lst, mapf, binf, lbl = build_and_measure(name, test_src, tools, work)
        measured = c1 - c0
        rows, loops = analyse(tools, lst, mapf, binf, lbl, os.path.join(work, name + '_an'))
        # the instruction under test: the last instruction of this opcode before the tail's `lda #0`
        mine = [r for r in rows if r['mnemonic'] == op['mn'] and r['mode'] == op['mode']]
        if op['mn'] == 'LDA' and op['mode'] == 'imm':
            mine = [r for r in rows if r['bytes'].upper() == 'A901']
        if not mine:
            raise SystemExit('%s: instruction not found in the analysis' % name)
        r = mine[-1]
        extra = sum(ops[x]['cycles'] for x in extra_ops)
        if op['mode'] == 'rel':
            pred = {'not_taken': int(r['branch_not_taken']), 'taken': int(r['branch_taken']), 'taken_cross': int(r['branch_taken'])}[kind]
            analyser_cross = r['branch_taken_page_cross']
            note = 'branch %s' % kind
            if kind == 'taken_cross' and analyser_cross != '1':
                note += ' (analyser did not flag the page cross)'
        else:
            pred = int(r['cycles']) + extra + (1 if (kind and r['page_cross_plus1'] == 'possible') else 0)
            note = ('X=Y=$FF, base low byte $FF (page cross)' if kind else 'X=Y=0, base low byte 0') if op['mode'] not in ('impl', 'acc') else ''
            if extra:
                note += ' (includes helper instructions: %d cycles from the table: %s)' % (extra, ' '.join('%02X' % x for x in extra_ops))
        ok = (measured == pred)
        if not ok:
            bad += 1
        results.append(['opcode', name, '%02X' % op['opcode'], op['mn'], op['mode'], r['page_cross_plus1'], pred, measured,
                        'OK' if ok else 'MISMATCH', note])
    # ---- 2. loops ----------------------------------------------------------------------------
    src = HEADER + LOOPS_SRC + TAIL + LOOPS_SUB
    c1, lst, mapf, binf, lbl = build_and_measure('bucles', src, tools, work)
    rows, loops = analyse(tools, lst, mapf, binf, lbl, os.path.join(work, 'bucles_an'))
    pred, why = predict_loops(rows, loops)
    designed_extra = 4   # l6: four reads of $03FF,x with X = 4..1 cross a page; l7 never does
    if pred is None:
        results.append(['loops', 'bucles', '', '', '', '', '', c1, 'MISMATCH', why])
        bad += 1
    else:
        lo, hi = pred
        exact = lo + designed_extra
        ok = (c1 == exact) and (lo <= c1 <= hi)
        if not ok:
            bad += 1
        results.append(['loops', 'bucles', '', '', '', '', '%d..%d (designed exact %d)' % (lo, hi, exact), c1,
                        'OK' if ok else 'MISMATCH',
                        (why + '; ' if why else '') + 'loops found: ' +
                        '; '.join('%s %s=%s' % (L['id'], L['target_label'], L['iterations']) for L in loops)])
    with open(os.path.join(a.out, 'autocomprobacion.tsv'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\t'.join(['experiment', 'case', 'opcode', 'mnemonic', 'mode', 'page_cross_rule', 'predicted', 'measured_sim65',
                           'result', 'note']) + '\n')
        for r in results:
            f.write('\t'.join(str(x) for x in r) + '\n')
    print('cases %d, mismatches %d' % (len(results), bad))
    for r in results:
        if r[8] != 'OK':
            print('MISMATCH', r)
    print('loops program: measured %d, predicted %s' % (c1, pred))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
