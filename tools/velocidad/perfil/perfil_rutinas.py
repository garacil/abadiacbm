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

"""Attribute a per-address 6502 cycle profile (hibrido SOMBRA6502_PERFIL: "ADDR\tCYCLES") to routines.

Every address is attributed with ld65's debug file (--dbgfile of the -g build, cc65 doc ld65.sgml / debug-info):
the innermost `.proc` scope whose span holds it (kind "proc"); outside any .proc, the nearest top-level label of
the module at or below it (kind "label"); the module (the .o whose top scope holds it); and the nearest label of
any kind (the "by label" view).  Deterministic; no estimates: every number is a sum of the profile's cycles.

    perfil_rutinas.py DBG OUTDIR NAME:PROFILE:FRAMES[:HITS_TSV@COLS]...

FRAMES is hibrido's --ciclos-frame file (frame, z80_tstates, c64_cycles, budget_ticks[, 16 categories, hits]);
HITS_TSV@COLS a --ciclos-frame file written with SOMBRA6502_CATEGORIAS and the column-name file of
categorias64.py (the hit_<label> columns give the times each label's address ran in the frames: the calls).
Writes OUTDIR/rutinas_<NAME>.tsv, OUTDIR/etiquetas_<NAME>.tsv, OUTDIR/modulos_<NAME>.tsv and, over all the
sessions, OUTDIR/perfil_medio.tsv (mean cycles per frame of each routine) and prints a summary."""
import sys, os, bisect

def parse_dbg(path):
    segs, spans, scopes, syms, mods, files, lines = {}, {}, {}, [], {}, {}, []
    for l in open(path):
        if "\t" not in l: continue
        kind, rest = l.rstrip("\n").split("\t", 1)
        d = {}
        for kv in rest.split(","):
            k, _, v = kv.partition("=")
            d[k] = v
        if kind == "seg": segs[int(d["id"])] = (d["name"].strip('"'), int(d["start"], 16))
        elif kind == "span": spans[int(d["id"])] = (int(d["seg"]), int(d["start"]), int(d["size"]))
        elif kind == "scope":
            scopes[int(d["id"])] = dict(name=d.get("name", "").strip('"'), mod=int(d["mod"]), type=d.get("type", ""),
                                        parent=int(d["parent"]) if "parent" in d else None,
                                        spans=[int(x) for x in d["span"].split("+")] if "span" in d else [])
        elif kind == "sym" and d.get("type") == "lab" and "seg" in d and "val" in d:
            syms.append((int(d["val"], 16), d["name"].strip('"'), int(d["scope"]) if "scope" in d else -1, int(d["seg"])))
        elif kind == "mod": mods[int(d["id"])] = d["name"].strip('"')
        elif kind == "file": files[int(d["id"])] = d["name"].strip('"')
        elif kind == "line" and "span" in d:
            lines.append((int(d["file"]), int(d["line"]), [int(x) for x in d["span"].split("+")]))
    return segs, spans, scopes, syms, mods, files, lines

def span_range(spans, segs, sid):
    seg, start, size = spans[sid]
    lo = segs[seg][1] + start
    return lo, lo + size

def main():
    dbg, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    specs = sys.argv[3:]
    segs, spans, scopes, syms, mods, files, lines = parse_dbg(dbg)
    code_seg = [i for i, (n, s) in segs.items() if n == "CODE"][0]
    code_lo = segs[code_seg][1]
    code_hi = max(span_range(spans, segs, s)[1] for s in spans if spans[s][0] == code_seg)
    N = 0x10000
    proc_of = [None] * N          # innermost .proc scope id
    mod_of = [None] * N           # module id (the module's top scope)
    depth = {}
    def dep(sid):
        if sid in depth: return depth[sid]
        p = scopes[sid]["parent"]
        depth[sid] = 0 if p is None else dep(p) + 1
        return depth[sid]
    # the modules first, then the procs from the outermost to the innermost: the inner ones overwrite
    for sid, sc in scopes.items():
        if sc["name"] == "" and sc["parent"] is None:
            for s in sc["spans"]:
                lo, hi = span_range(spans, segs, s)
                for a in range(lo, hi): mod_of[a] = sc["mod"]
    for sid in sorted((s for s in scopes if scopes[s]["type"] == "scope"), key=lambda s: (dep(s), s)):
        for s in scopes[sid]["spans"]:
            if spans[s][0] != code_seg: continue
            lo, hi = span_range(spans, segs, s)
            for a in range(lo, hi): proc_of[a] = sid
    def outer(sid):
        while scopes[sid]["parent"] is not None and scopes[scopes[sid]["parent"]]["type"] == "scope":
            sid = scopes[sid]["parent"]
        return sid
    # labels of the CODE segment: all, and the top-level ones (scope = a module's top scope) per module
    labs = sorted((v, n, sc) for v, n, sc, sg in syms if sg == code_seg)
    lab_addr = [v for v, n, sc in labs]
    top = {}
    for v, n, sc in labs:
        if sc >= 0 and scopes[sc]["name"] == "" and scopes[sc]["parent"] is None:
            top.setdefault(scopes[sc]["mod"], []).append((v, n))
    for m in top: top[m].sort()
    def nearest_label(a):
        i = bisect.bisect_right(lab_addr, a) - 1
        return labs[i][1] if i >= 0 else "?"
    def routine(a):
        sid = proc_of[a]
        if sid is not None:
            o = outer(sid)
            return scopes[sid]["name"], scopes[o]["name"], "proc"
        m = mod_of[a]
        if m is None: return "?", "?", "none"
        t = top.get(m, [])
        i = bisect.bisect_right([v for v, n in t], a) - 1
        n = t[i][1] if i >= 0 else "?"
        return n, n, "label"
    # line info: address -> (file, line) of the first span that holds it (for the report's references)
    sessions = []
    all_rout = {}
    for spec in specs:
        parts = spec.split(":")
        name, prof, frames = parts[0], parts[1], parts[2]
        hits_specs = parts[3:]
        cyc = {}
        for l in open(prof):
            t = l.split()
            if len(t) == 2: cyc[int(t[0], 16)] = cyc.get(int(t[0], 16), 0) + int(t[1])
        total = sum(cyc.values())
        fr = [l.split("\t") for l in open(frames) if l.strip()]
        hdr, rows = fr[0], fr[1:]
        nframes = len(rows)
        ftot = sum(int(r[2]) for r in rows)
        # the categories (the ticks' cycles are not in them: hibrido counts them only in the per-address profile)
        cat_sum = sum(int(x) for r in rows for x in r[4:20]) if len(rows[0]) >= 20 else None
        hits = {}
        for hs in hits_specs:
            tsv, cols = hs.split("@")
            names = open(cols).read().split()
            hn = [c for c in names if c.startswith("hit_")]
            rws = [l.split("\t") for l in open(tsv) if l.strip()][1:]
            if len(rws) != nframes: sys.exit(f"{tsv}: {len(rws)} frames, {frames} has {nframes}")
            for j, h in enumerate(hn):
                hits[h[4:]] = sum(int(r[20 + j]) for r in rws)
        by_r, by_l, by_m = {}, {}, {}
        for a, c in cyc.items():
            r, o, k = routine(a)
            key = (r, o, k, mods.get(mod_of[a], "?") if mod_of[a] is not None else "?")
            by_r[key] = by_r.get(key, 0) + c
            lk = (nearest_label(a), r)
            by_l[lk] = by_l.get(lk, 0) + c
            mk = mods.get(mod_of[a], "?") if mod_of[a] is not None else "?"
            by_m[mk] = by_m.get(mk, 0) + c
        # a label's address -> routine, for the hits
        lab_rout = {}
        for v, n, sc in labs:
            if v < N and (proc_of[v] is not None or mod_of[v] is not None): lab_rout.setdefault(n, routine(v)[0])
        calls = {}
        for h, n in hits.items():
            if h in lab_rout: calls[lab_rout[h]] = calls.get(lab_rout[h], 0) + n
        with open(os.path.join(outdir, f"rutinas_{name}.tsv"), "w") as o:
            o.write("routine\touter\tkind\tmodule\tcycles\tcycles_per_frame\tpercent\tcalls\tcycles_per_call\n")
            for key, c in sorted(by_r.items(), key=lambda x: (-x[1], x[0])):
                r, oo, k, m = key
                n = calls.get(r, "")
                o.write(f"{r}\t{oo}\t{k}\t{m}\t{c}\t{c / nframes:.1f}\t{100 * c / total:.2f}\t{n}\t"
                        f"{(c / n):.1f}\n" if n else f"{r}\t{oo}\t{k}\t{m}\t{c}\t{c / nframes:.1f}\t{100 * c / total:.2f}\t\t\n")
                all_rout.setdefault(key, {})[name] = c / nframes
        with open(os.path.join(outdir, f"etiquetas_{name}.tsv"), "w") as o:
            o.write("label\troutine\tcycles\tcycles_per_frame\tpercent\n")
            for (l, r), c in sorted(by_l.items(), key=lambda x: (-x[1], x[0])):
                o.write(f"{l}\t{r}\t{c}\t{c / nframes:.1f}\t{100 * c / total:.2f}\n")
        with open(os.path.join(outdir, f"modulos_{name}.tsv"), "w") as o:
            o.write("module\tcycles\tcycles_per_frame\tpercent\n")
            for m, c in sorted(by_m.items(), key=lambda x: (-x[1], x[0])):
                o.write(f"{m}\t{c}\t{c / nframes:.1f}\t{100 * c / total:.2f}\n")
        fc = sorted(int(r[2]) for r in rows)
        print(f"== {name}: {nframes} frames, {total} cycles in the profile, {ftot} in the frame file"
              f"{' (EQUAL)' if total == ftot else ' (DIFFERENT)'}; {total / nframes:.0f} cycles per frame; "
              f"frame min {fc[0]} median {fc[len(fc) // 2]} max {fc[-1]}"
              + (f"; category columns {cat_sum} (ticks outside them: {ftot - cat_sum}, {100 * (ftot - cat_sum) / ftot:.1f} %)" if cat_sum is not None else ""))
        sessions.append((name, nframes, total))
    with open(os.path.join(outdir, "perfil_medio.tsv"), "w") as o:
        names = [s[0] for s in sessions]
        o.write("routine\touter\tkind\tmodule\t" + "\t".join(f"cpf_{n}" for n in names) + "\tmean_cycles_per_frame\tmean_percent\n")
        tot_cpf = {n: t / f for n, f, t in sessions}
        rows = []
        for key, d in all_rout.items():
            vals = [d.get(n, 0.0) for n in names]
            mean = sum(vals) / len(names)
            pct = sum(100 * d.get(n, 0.0) / tot_cpf[n] for n in names) / len(names)
            rows.append((mean, pct, key, vals))
        for mean, pct, key, vals in sorted(rows, key=lambda x: (-x[0], x[2])):
            o.write("\t".join(key) + "\t" + "\t".join(f"{v:.1f}" for v in vals) + f"\t{mean:.1f}\t{pct:.2f}\n")

if __name__ == "__main__":
    main()
