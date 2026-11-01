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

"""informe_datos.py: prints, as Markdown tables, the figures my report of the analysis quotes (deterministic: read from the
analyzer's TSV/JSON outputs and the ld65 map).  Usage: python3 -I informe_datos.py OUTDIR MAPFILE
"""
import csv
import json
import os
import re
import sys


def load(path):
    with open(path, encoding='utf-8') as f:
        return list(csv.DictReader(f, delimiter='\t'))


def main():
    out, mapf = sys.argv[1], sys.argv[2]
    loops = load(os.path.join(out, 'bucles.tsv'))
    routines = load(os.path.join(out, 'rutinas.tsv'))
    instrs = load(os.path.join(out, 'instrucciones.tsv'))
    summary = json.load(open(os.path.join(out, 'resumen.json'), encoding='utf-8'))
    print('## Totals\n')
    for k in ('instructions', 'code_bytes', 'data_bytes_in_code_segments', 'routines', 'loops', 'loops_constant'):
        print('- %s: %s' % (k, summary[k]))
    print('- problems: %d' % len(summary['problems']))
    # loops
    print('\n## 30 heaviest loops (constant iteration count: body cycles x iterations; then variable ones by body cycles)\n')
    print('| rank | id | module | routine | header | branch | body bytes | instr | cycles/iter | +1 possible | iterations | cycles x iter | depth | pattern |')
    print('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
    for k, L in enumerate(loops[:30]):
        print('| %d | %s | %s | %s | $%s %s | $%s %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (
            k + 1, L['id'], L['module'].replace('.o', ''), L['routine'], L['target'], L['target_label'], L['branch_addr'],
            L['branch'].lower(), L['body_bytes'], L['body_instructions'], L['body_cycles_per_iteration'],
            L['page_cross_plus1_possible_in_body'], L['iterations'].replace('|', '/'), L['cycles_x_iterations'],
            L['nesting_depth'], L['pattern'].replace('|', '/')))
    bounded = [L for L in loops if not L['cycles_x_iterations'] and L['max_iterations']]
    bounded.sort(key=lambda L: -int(L['body_cycles_per_iteration'] or 0) * int(L['max_iterations']))
    print('\n## 30 heaviest bounded loops (an upper bound is known: a constant initializer with other exits, or a counter without a constant initializer, <= 256 / 128): cycles/iter x bound\n')
    print('| rank | id | module | routine | header | branch | cycles/iter | +1 possible | bound | cycles x bound | other exits | depth |')
    print('|---|---|---|---|---|---|---|---|---|---|---|---|')
    for k, L in enumerate(bounded[:30]):
        print('| %d | %s | %s | %s | $%s %s | $%s %s | %s | %s | <= %s | %d | %s | %s |' % (
            k + 1, L['id'], L['module'].replace('.o', ''), L['routine'], L['target'], L['target_label'], L['branch_addr'],
            L['branch'].lower(), L['body_cycles_per_iteration'], L['page_cross_plus1_possible_in_body'], L['max_iterations'],
            int(L['body_cycles_per_iteration']) * int(L['max_iterations']), L['other_exits'], L['nesting_depth']))
    nconst = sum(1 for L in loops if L['cycles_x_iterations'])
    print('\n(%d loops in all, %d with a constant count; the variable ones start at rank %d)\n' % (len(loops), nconst, nconst + 1))
    # the heaviest variable loops
    var = [L for L in loops if not L['cycles_x_iterations']]
    print('## 30 heaviest variable loops (by body cycles per iteration)\n')
    print('| rank | id | module | routine | header | branch | body bytes | cycles/iter | +1 possible | bound | jsr in body | depth |')
    print('|---|---|---|---|---|---|---|---|---|---|---|---|')
    for k, L in enumerate(var[:30]):
        print('| %d | %s | %s | %s | $%s %s | $%s %s | %s | %s | %s | %s | %s | %s |' % (
            k + 1, L['id'], L['module'].replace('.o', ''), L['routine'], L['target'], L['target_label'], L['branch_addr'],
            L['branch'].lower(), L['body_bytes'], L['body_cycles_per_iteration'], L['page_cross_plus1_possible_in_body'],
            L['iterations'].replace('|', '/'), L['jsr_in_body'], L['nesting_depth']))
    # sprite path
    reach = summary['reached_from_root']
    print('\n## Routines reached from %s (JSR/JMP closure, %d routines)\n' % (summary['root'], len(reach)))
    rmap = {r['routine']: r for r in routines}
    print('| routine | module | start | bytes | instr | loops | jsr targets | jmp indirect |')
    print('|---|---|---|---|---|---|---|---|')
    for name in sorted(reach, key=lambda n: int(rmap[n]['start'], 16) if n in rmap else 0):
        r = rmap.get(name)
        if r:
            print('| %s | %s | $%s | %s | %s | %s | %s | %s |' % (name, r['module'].replace('.o', ''), r['start'], r['bytes'],
                                                              r['instructions'], r['loops'], r['jsr_targets'], r['jmp_indirect']))
    wanted = ['spr_draw_all', 'spr_blit_to_screen', 'spr_tile_to_buffer', 'iso_draw_tile', 'iso_draw_room_spiral',
              'spr_draw_tiles_in_depth_range', 'la_tramo', 'spr_draw_light', 'la_mezcla', 'la_capas', 'la_baldosa', 'la_luz']
    print('\n## The named sprite-composition routines\n')
    print('| routine | found as | start | bytes | in closure of spr_draw_all |')
    print('|---|---|---|---|---|')
    for w in wanted:
        cands = [r for r in routines if r['routine'] == w]
        if not cands:
            cands = [r for r in routines if w in r['routine']]
        if cands:
            for r in cands:
                print('| %s | %s | $%s | %s | %s |' % (w, r['routine'], r['start'], r['bytes'], 'yes' if r['routine'] in reach else 'no'))
        else:
            print('| %s | not a routine start (label inside another routine or absent) | | | |' % w)
    # loops inside the closure
    print('\n## Loops inside the spr_draw_all closure, heaviest first (constant: cycles x iterations; variable: cycles/iter)\n')
    print('| id | routine | header | branch | cycles/iter | +1 possible | iterations | cycles x iter | depth |')
    print('|---|---|---|---|---|---|---|---|---|')
    inside = [L for L in loops if L['routine'] in reach]
    for L in inside[:40]:
        print('| %s | %s | $%s %s | $%s %s | %s | %s | %s | %s | %s |' % (
            L['id'], L['routine'], L['target'], L['target_label'], L['branch_addr'], L['branch'].lower(),
            L['body_cycles_per_iteration'], L['page_cross_plus1_possible_in_body'], L['iterations'].replace('|', '/'),
            L['cycles_x_iterations'], L['nesting_depth']))
    # routine sizes vs map exports
    exports = {}
    with open(mapf, encoding='utf-8') as f:
        sec = False
        for line in f:
            if line.startswith('Exports list'):
                sec = True
                continue
            if line.startswith('Imports list'):
                break
            if sec:
                for m in re.finditer(r'(\S+)\s+([0-9A-F]{6})\s+R[LZ]A', line):
                    exports[m.group(1)] = int(m.group(2), 16)
    exp_sorted = sorted(exports.items(), key=lambda kv: kv[1])
    print('\n## Routine sizes: analyzer (rutinas.tsv) vs juego.map exports (next export - this export)\n')
    print('| routine | map address | next export | map size | analyzer start | analyzer end | analyzer bytes | match |')
    print('|---|---|---|---|---|---|---|---|')
    for w in ('spr_draw_all', 'iso_draw_room_spiral', 'iso_clear_tile_buffer', 'chr_path_clear_grid_marks', 'vid_init_stub', 'sys_tick'):
        if w not in exports:
            print('| %s | not exported | | | | | | |' % w)
            continue
        a = exports[w]
        nxt = [kv for kv in exp_sorted if kv[1] > a]
        nxt_name, nxt_addr = nxt[0] if nxt else ('', 0)
        rs = [r for r in routines if r['routine'] == w]
        if rs:
            r = rs[0]
            # the analyzer may split an exported routine at unexported .proc starts: sum up to the next export
            tot = sum(int(x['bytes']) for x in routines if a <= int(x['start'], 16) < nxt_addr)
            print('| %s | $%04X | %s $%04X | %d | $%s | $%s | %s (to next export: %d) | %s |' % (
                w, a, nxt_name, nxt_addr, nxt_addr - a, r['start'], r['end'], r['bytes'], tot,
                'yes' if tot == nxt_addr - a else 'NO'))
    # instruction mix
    print('\n## Instruction mix of the code segments\n')
    from collections import Counter
    c = Counter((r['mnemonic'], r['mode']) for r in instrs if r['mnemonic'] != 'DATA')
    print('| mnemonic | mode | count |')
    print('|---|---|---|')
    for (mn, mode), n in sorted(c.items(), key=lambda kv: (-kv[1], kv[0]))[:25]:
        print('| %s | %s | %d |' % (mn, mode, n))
    crossp = sum(1 for r in instrs if r['page_cross_plus1'] == 'possible')
    crossi = sum(1 for r in instrs if r['page_cross_plus1'].startswith('impossible'))
    print('\n- indexed reads with a possible +1 page crossing: %d; impossible (base low byte 00): %d' % (crossp, crossi))
    brs = [r for r in instrs if r['branch_taken']]
    print('- branches: %d, of which %d cross a page when taken (4 cycles instead of 3)' % (len(brs), sum(1 for r in brs if r['branch_taken_page_cross'] == '1')))


if __name__ == '__main__':
    main()
