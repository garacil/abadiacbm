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

"""Address attribution from ld65's debug file (--dbgfile of the -g link; cc65 doc ld65.sgml, "debug-info"): the
innermost `.proc` holding an address (kind "proc"), else the nearest top-level label of its module (kind "label");
the module; and the nearest label of any kind at or below the address.  The same rules as the round-4
perfil_rutinas.py (in this directory), as a module.  Deterministic."""
import bisect


class Atribucion:
    def __init__(self, dbg):
        segs, spans, scopes, syms, mods = {}, {}, {}, [], {}
        for l in open(dbg):
            if "\t" not in l:
                continue
            kind, rest = l.rstrip("\n").split("\t", 1)
            d = {}
            for kv in rest.split(","):
                k, _, v = kv.partition("=")
                d[k] = v
            if kind == "seg":
                segs[int(d["id"])] = (d["name"].strip('"'), int(d["start"], 16))
            elif kind == "span":
                spans[int(d["id"])] = (int(d["seg"]), int(d["start"]), int(d["size"]))
            elif kind == "scope":
                scopes[int(d["id"])] = dict(name=d.get("name", "").strip('"'), mod=int(d["mod"]), type=d.get("type", ""),
                                            parent=int(d["parent"]) if "parent" in d else None,
                                            spans=[int(x) for x in d["span"].split("+")] if "span" in d else [])
            elif kind == "sym" and d.get("type") == "lab" and "seg" in d and "val" in d:
                syms.append((int(d["val"], 16), d["name"].strip('"'), int(d["scope"]) if "scope" in d else -1, int(d["seg"])))
            elif kind == "mod":
                mods[int(d["id"])] = d["name"].strip('"')
        self.segs, self.spans, self.scopes, self.mods = segs, spans, scopes, mods
        code_seg = [i for i, (n, s) in segs.items() if n == "CODE"][0]
        self.code_lo = segs[code_seg][1]
        self.code_hi = max(self.span_range(s)[1] for s in spans if spans[s][0] == code_seg)
        N = 0x10000
        self.proc_of = [None] * N
        self.mod_of = [None] * N
        depth = {}

        def dep(sid):
            if sid in depth:
                return depth[sid]
            p = scopes[sid]["parent"]
            depth[sid] = 0 if p is None else dep(p) + 1
            return depth[sid]
        for sid, sc in scopes.items():
            if sc["name"] == "" and sc["parent"] is None:
                for s in sc["spans"]:
                    lo, hi = self.span_range(s)
                    for a in range(lo, hi):
                        self.mod_of[a] = sc["mod"]
        for sid in sorted((s for s in scopes if scopes[s]["type"] == "scope"), key=lambda s: (dep(s), s)):
            for s in scopes[sid]["spans"]:
                if spans[s][0] != code_seg:
                    continue
                lo, hi = self.span_range(s)
                for a in range(lo, hi):
                    self.proc_of[a] = sid
        self.labs = sorted((v, n, sc) for v, n, sc, sg in syms if sg == code_seg)
        self.lab_addr = [v for v, n, sc in self.labs]
        self.top = {}
        for v, n, sc in self.labs:
            if sc >= 0 and scopes[sc]["name"] == "" and scopes[sc]["parent"] is None:
                self.top.setdefault(scopes[sc]["mod"], []).append((v, n))
        for m in self.top:
            self.top[m].sort()
        self.by_name = {}
        for v, n, sc in self.labs:
            self.by_name.setdefault(n, v)

    def span_range(self, sid):
        seg, start, size = self.spans[sid]
        lo = self.segs[seg][1] + start
        return lo, lo + size

    def outer(self, sid):
        while self.scopes[sid]["parent"] is not None and self.scopes[self.scopes[sid]["parent"]]["type"] == "scope":
            sid = self.scopes[sid]["parent"]
        return sid

    def nearest_label(self, a):
        """(address, name) of the nearest CODE label at or below a."""
        i = bisect.bisect_right(self.lab_addr, a) - 1
        return (self.labs[i][0], self.labs[i][1]) if i >= 0 else (0, "?")

    def routine(self, a):
        """(routine, outer routine, kind, module) of address a."""
        sid = self.proc_of[a]
        m = self.mod_of[a]
        mod = self.mods.get(m, "?") if m is not None else "?"
        if sid is not None:
            o = self.outer(sid)
            return self.scopes[sid]["name"], self.scopes[o]["name"], "proc", mod
        if m is None:
            return "?", "?", "none", "?"
        t = self.top.get(m, [])
        i = bisect.bisect_right([v for v, n in t], a) - 1
        n = t[i][1] if i >= 0 else "?"
        return n, n, "label", mod

    def proc_span(self, name):
        """[lo, hi) of the CODE span of the .proc called name (the first scope of that name)."""
        for sid, sc in sorted(self.scopes.items()):
            if sc["name"] == name and sc["type"] == "scope":
                rs = [self.span_range(s) for s in sc["spans"] if self.spans[s][0] in
                      [i for i, (n, st) in self.segs.items() if n == "CODE"]]
                if rs:
                    return min(r[0] for r in rs), max(r[1] for r in rs)
        return None
