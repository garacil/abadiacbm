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

"""Per-frame 6502 cycles by module (hibrido --ciclos-frame with SOMBRA6502_CATEGORIAS) over the sessions in DIR:
frames grouped by the number of rectangles composed (spr_blit_to_screen hits): mean cycles per group and module.

    ciclos_categorias.py DIR      DIR: columnas.txt (categorias64.py's column names, run with --hit
                                  spr_blit_to_screen chr_path_find iso_build_room) and ciclos_*.tsv (one per session)"""
import csv, glob, collections, os, sys
if len(sys.argv) != 2:
    sys.exit(__doc__)
DIR = sys.argv[1]
cols = open(os.path.join(DIR, 'columnas.txt')).read().split()
cats = [c for c in cols if not c.startswith('hit_')]; hits = [c for c in cols if c.startswith('hit_')]
cols = cats + [f'cat{i}' for i in range(len(cats), 16)] + hits      # hibrido prints 16 category columns, then the hits
rows = []
for f in sorted(glob.glob(os.path.join(DIR, 'ciclos_*.tsv'))):
    r = list(csv.reader(open(f), delimiter='\t'))
    hdr = r[0]
    for x in r[1:]:
        if len(x) < 4 + len(cols): continue
        v = [int(t) for t in x]
        rows.append((f.split('_')[-1][:-4], v[0], v[2], dict(zip(cols, v[4:]))))
print('frames', len(rows))
mods = [c for c in cols if not c.startswith('hit_')]
def grupo(n):
    return '0' if n == 0 else '1' if n == 1 else '2' if n == 2 else '3-4' if n <= 4 else '5-6' if n <= 6 else '7+'
g = collections.defaultdict(list)
for s, fr, cyc, d in rows:
    g[grupo(d['hit_spr_blit_to_screen'])].append((cyc, d))
print(f"{'rects':6s} {'frames':7s} {'cycles':>8s} " + ' '.join(f"{m[:12]:>12s}" for m in mods if m != 'other') + f" {'other':>8s} {'paths':>6s}")
for k in ['0', '1', '2', '3-4', '5-6', '7+']:
    L = g.get(k, [])
    if not L: continue
    n = len(L)
    mean = lambda f: sum(f(c, d) for c, d in L) / n
    print(f"{k:6s} {n:7d} {mean(lambda c, d: c):8.0f} " + ' '.join(f"{mean(lambda c, d, m=m: d[m]):12.0f}" for m in mods if m != 'other')
          + f" {mean(lambda c, d: d['other']):8.0f} {mean(lambda c, d: d['hit_chr_path_find']):6.2f}")
# the heaviest frames: what are they made of
L = sorted(rows, key=lambda r: -r[2])[:8]
print('\nheaviest frames (session, frame, cycles, rectangles, path searches, room builds, top modules):')
for s, fr, cyc, d in L:
    top = sorted(((d[m], m) for m in mods), reverse=True)[:3]
    print(f"  {s} {fr} {cyc} rects {d['hit_spr_blit_to_screen']} paths {d['hit_chr_path_find']} rooms {d['hit_iso_build_room']} " + ', '.join(f"{m} {v}" for v, m in top))
# composition cost per rectangle: the slope of logica_a_spr cycles against rectangles (frames without room builds)
xs = [(d['hit_spr_blit_to_screen'], d['logica_a_spr']) for s, fr, cyc, d in rows if d['hit_iso_build_room'] == 0]
n = len(xs); mx = sum(x for x, y in xs) / n; my = sum(y for x, y in xs) / n
sl = sum((x - mx) * (y - my) for x, y in xs) / max(1e-9, sum((x - mx) ** 2 for x, y in xs))
print(f"\ncomposition (logica_a_spr) cycles per rectangle, least squares over {n} frames: {sl:.0f}; mean rectangles a frame {mx:.2f}")
tot = sum(c for s, fr, c, d in rows)
print('share of all cycles by module:', ', '.join(f"{m} {100 * sum(d[m] for s, fr, c, d in rows) / tot:.1f}%" for m in mods))
