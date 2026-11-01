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

"""Analyse a call trace of the scratch host (SOMBRA6502_TRAZA, parche_traza.py): per routine, calls and inclusive
cycles per frame; per context (the call type) for the routines run inside one; the callers; and, for the routines
asked, the groups of calls with identical inputs (the same input hash and entry registers A, X, Y).  Every number
is a sum over the trace's lines; deterministic.

    traza_analisis.py DBG TRACE FRAMES OUT_PREFIX [--lista LIST] [--desde FRAME] [--iguales ROUTINE...]

FRAMES is the --ciclos-frame file of the same run (its frames and their cycles); LIST is the routine list given to
the host (the context indices are positions in it); --desde F restricts a second set
of tables to the host frames >= F (the window of a repeated behaviour).  Writes OUT_PREFIX.rutinas.tsv,
OUT_PREFIX.ctx.tsv, OUT_PREFIX.llamadores.tsv, OUT_PREFIX.iguales_<routine>.tsv and prints a summary."""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atribuye import Atribucion


def main():
    args = sys.argv[1:]
    dbg, trace, frames_f, out = args[:4]
    rest = args[4:]
    desde = None
    iguales = []
    lista = ""
    i = 0
    while i < len(rest):
        if rest[i] == "--desde":
            desde = int(rest[i + 1]); i += 2
        elif rest[i] == "--lista":
            lista = rest[i + 1]; i += 2
        elif rest[i] == "--iguales":
            i += 1
            while i < len(rest) and not rest[i].startswith("--"):
                iguales.append(rest[i]); i += 1
        else:
            sys.exit("unknown option " + rest[i])
    at = Atribucion(dbg)
    fr = [l.rstrip("\n").split("\t") for l in open(frames_f) if l.strip()][1:]
    frames = [int(r[0]) for r in fr]
    cyc_frame = {int(r[0]): int(r[2]) for r in fr}
    nframes = len(frames)
    total_cycles = sum(cyc_frame.values())
    rows = []
    with open(trace) as f:
        hdr = f.readline().rstrip("\n").split("\t")
        for l in f:
            t = l.rstrip("\n").split("\t")
            rows.append(dict(frame=int(t[0]), rut=int(t[1], 16), idx=int(t[2]), ret=int(t[3], 16), a=int(t[4], 16),
                             x=int(t[5], 16), y=int(t[6], 16), sr=int(t[7], 16), cycles=int(t[8]), hash=t[9],
                             nr=int(t[10]), nw=int(t[11]), a_out=int(t[12], 16), sr_out=int(t[13], 16), ctx=int(t[14]),
                             end=t[15]))
    ruts = sorted(set(r["rut"] for r in rows))
    name = {a: at.routine(a)[0] for a in ruts}
    # the context index is the routine's position in the SOMBRA6502_TRAZA list (--lista: that list, as given to
    # the host); without it the contexts are shown by index
    ctx_rut = {}
    if lista:
        for k, item in enumerate([x for x in lista.split(",") if x]):
            ctx_rut[k] = int(item.rstrip("*!"), 16)
            name.setdefault(ctx_rut[k], at.routine(ctx_rut[k])[0])

    def wins(rs):
        return [r for r in rs if desde is None or r["frame"] >= desde]
    windows = [("all", rows, nframes, total_cycles)]
    if desde is not None:
        wf = [f for f in frames if f >= desde]
        windows.append((f"from_{desde}", wins(rows), len(wf), sum(cyc_frame[f] for f in wf)))
    summary = []
    with open(out + ".rutinas.tsv", "w") as o:
        o.write("window\troutine\taddr\tcalls\tcalls_per_frame\tcycles\tcycles_per_frame\tpercent_of_run\tcycles_per_call_mean\tmedian\tmax\tcut\n")
        for wn, rs, nf, tc in windows:
            for a in ruts:
                c = [r for r in rs if r["rut"] == a]
                if not c:
                    continue
                cy = sorted(r["cycles"] for r in c)
                tot = sum(cy)
                cut = sum(1 for r in c if r["end"] != "ok")
                o.write(f"{wn}\t{name[a]}\t{a:04X}\t{len(c)}\t{len(c) / nf:.3f}\t{tot}\t{tot / nf:.1f}\t{100 * tot / tc:.2f}\t"
                        f"{tot / len(c):.1f}\t{cy[len(cy) // 2]}\t{cy[-1]}\t{cut}\n")
                summary.append((wn, name[a], len(c), tot / nf, cut))
    with open(out + ".ctx.tsv", "w") as o:
        o.write("window\troutine\tcontext\tresult_a_out\tcalls\tcalls_per_frame\tcycles\tcycles_per_frame\tcycles_per_call\n")
        for wn, rs, nf, tc in windows:
            for a in ruts:
                groups = {}
                for r in rs:
                    if r["rut"] != a:
                        continue
                    k = (r["ctx"], r["a_out"])
                    g = groups.setdefault(k, [0, 0])
                    g[0] += 1; g[1] += r["cycles"]
                if len(groups) <= 1 and all(k[0] < 0 for k in groups):
                    continue
                for (cx, ao), (n, cy) in sorted(groups.items()):
                    cn = name.get(ctx_rut.get(cx, -1), "none") if cx >= 0 else "none"
                    o.write(f"{wn}\t{name[a]}\t{cn}\t{ao:02X}\t{n}\t{n / nf:.3f}\t{cy}\t{cy / nf:.1f}\t{cy / n:.1f}\n")
    with open(out + ".llamadores.tsv", "w") as o:
        o.write("window\troutine\tcaller_routine\tcaller_label\tret\tcalls\tcycles\tcycles_per_frame\n")
        for wn, rs, nf, tc in windows:
            for a in ruts:
                groups = {}
                for r in rs:
                    if r["rut"] != a:
                        continue
                    g = groups.setdefault(r["ret"], [0, 0])
                    g[0] += 1; g[1] += r["cycles"]
                for ret, (n, cy) in sorted(groups.items(), key=lambda kv: (-kv[1][1], kv[0])):
                    cr = at.routine(ret - 1)[0]
                    la, ln = at.nearest_label(ret - 1)
                    o.write(f"{wn}\t{name[a]}\t{cr}\t{ln}+{ret - 1 - la}\t{ret:04X}\t{n}\t{cy}\t{cy / nf:.1f}\n")
    for rn in iguales:
        a = at.by_name[rn]
        with open(out + f".iguales_{rn}.tsv", "w") as o:
            o.write("window\tgroup\tcalls\tfirst_frame\tlast_frame\tcycles_each_min\tcycles_each_max\tcycles_total\tcycles_per_frame\thash\ta\tx\ty\ta_out\tctx\tnr\tnw\n")
            for wn, rs, nf, tc in windows:
                groups = {}
                for r in rs:
                    if r["rut"] != a:
                        continue
                    k = (r["hash"], r["a"], r["x"], r["y"])
                    groups.setdefault(k, []).append(r)
                calls = sum(len(g) for g in groups.values())
                rep = sum(len(g) - 1 for g in groups.values())
                cy_rep = sum(sum(r["cycles"] for r in g[1:]) for g in groups.values())
                cy_all = sum(sum(r["cycles"] for r in g) for g in groups.values())
                print(f"{rn} [{wn}]: {calls} calls, {len(groups)} distinct inputs, {rep} repeats of an earlier call "
                      f"({cy_rep} cycles, {cy_rep / nf:.1f} per frame of {nf}; all calls {cy_all}, {cy_all / nf:.1f} per frame)")
                for gi, (k, g) in enumerate(sorted(groups.items(), key=lambda kv: (-len(kv[1]), kv[1][0]["frame"]))):
                    if len(g) < 2 and gi >= 20:
                        break
                    cy = [r["cycles"] for r in g]
                    cn = name.get(ctx_rut.get(g[0]["ctx"], -1), "none") if g[0]["ctx"] >= 0 else "none"
                    o.write(f"{wn}\t{gi}\t{len(g)}\t{g[0]['frame']}\t{g[-1]['frame']}\t{min(cy)}\t{max(cy)}\t{sum(cy)}\t{sum(cy) / nf:.1f}\t"
                            f"{k[0]}\t{k[1]:02X}\t{k[2]:02X}\t{k[3]:02X}\t{g[0]['a_out']:02X}\t{cn}\t{g[0]['nr']}\t{g[0]['nw']}\n")
    for wn, rn, n, cpf, cut in summary:
        print(f"{wn}\t{rn}\t{n} calls\t{cpf:.1f} cycles/frame\t{'CUT ' + str(cut) if cut else ''}")


if __name__ == "__main__":
    main()
