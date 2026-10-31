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

"""How big would C sources be when compiled by cc65 for the C64?  Measurement only: the sources are
not changed.  Each file is preprocessed by gcc with small fake libc headers and a shim abadia.h
(the data space at fixed addresses, accessors as macros), parsed by pycparser, turned into C89
(declarations in `for` and declarations after statements are moved into new nested blocks, which
keeps the meaning), printed back and compiled by cc65 (-O -Os -t c64).  The CODE/RODATA/DATA/BSS
sizes come from od65.

    mide_cc65.py C_DIR FILE.c...      (C_DIR has include/; run from anywhere)
"""
import os, re, subprocess, sys, tempfile
from pycparser import c_parser, c_ast, c_generator

HERE = os.path.dirname(os.path.abspath(__file__))
CC65 = os.path.join(os.path.dirname(HERE), "tools", "terceros", "cc65", "bin")


class C89(c_ast.NodeVisitor):
    def __init__(self):
        self.wrap = {}

    def generic_visit(self, node):
        for name, child in node.children():
            self.visit(child)
            if isinstance(child, c_ast.For) and id(child) in self.wrap and not isinstance(node, c_ast.Compound):
                Literals.replace(node, name, c_ast.Compound(list(self.wrap.pop(id(child))) + [child]))

    def visit_FuncDef(self, node):
        self.generic_visit(node)

    def visit_For(self, node):
        self.generic_visit(node)
        if isinstance(node.init, c_ast.DeclList):
            decls = node.init.decls
            node.init = None
            assigns = [c_ast.Assignment("=", c_ast.ID(d.name), d.init) for d in decls if d.init is not None]
            for d in decls:
                d.init = None
            if assigns:
                node.init = assigns[0] if len(assigns) == 1 else c_ast.ExprList(assigns)
            self.wrap[id(node)] = decls

    def visit_Compound(self, node):
        self.generic_visit(node)
        items = node.block_items or []
        out = []
        for it in items:
            if isinstance(it, c_ast.For) and id(it) in self.wrap:
                out.append(c_ast.Compound(list(self.wrap.pop(id(it))) + [it]))
            else:
                out.append(it)
        # split at the first declaration that follows a statement
        def split(lst):
            seen_stmt = False
            for i, it in enumerate(lst):
                if isinstance(it, c_ast.Decl):
                    if seen_stmt:
                        return lst[:i] + [c_ast.Compound(split(lst[i:]))]
                else:
                    seen_stmt = True
            return lst
        node.block_items = split(out)


class Literals(c_ast.NodeVisitor):
    """Compound literals (cc65 has none) become file-scope static arrays."""
    def __init__(self):
        self.globals, self.n = [], 0

    def generic_visit(self, node):
        for name, child in node.children():
            if isinstance(child, c_ast.CompoundLiteral):
                self.n += 1
                nm = f"_lit{self.n}"
                td = child.type.type
                decl = c_ast.Decl(nm, [], [], ["static"], [], c_ast.TypeDecl(nm, [], None, td.type) if isinstance(td, c_ast.TypeDecl) else self.rename(td, nm), child.init, None)
                self.globals.append(decl)
                self.replace(node, name, c_ast.ID(nm))
            else:
                self.visit(child)

    def rename(self, t, nm):
        if isinstance(t, c_ast.TypeDecl):
            return c_ast.TypeDecl(nm, t.quals, None, t.type)
        t.type = self.rename(t.type, nm)
        return t

    @staticmethod
    def replace(parent, name, new):
        m = re.match(r"(\w+)\[(\d+)\]", name)
        if m:
            getattr(parent, m.group(1))[int(m.group(2))] = new
        else:
            setattr(parent, name, new)


def measure(cdir, path):
    inc = os.path.join(HERE, "mide_cc65")
    pre = subprocess.run(["gcc", "-E", "-P", "-nostdinc", "-std=c11", "-I", os.path.join(inc, "inc"), "-I", inc,
                          "-I", os.path.join(cdir, "include"), "-I", os.path.join(cdir, "src"),
                          "-D__attribute__(x)=", "-D_Static_assert(a,b)=", path],
                         capture_output=True, text=True)
    if pre.returncode:
        raise SystemExit(pre.stderr)
    src = pre.stdout
    src = re.sub(r"\b_Noreturn\b|\binline\b", "", src)
    ast = c_parser.CParser().parse(src, filename=path)
    lit = Literals(); lit.visit(ast)
    first_fn = next(i for i, e in enumerate(ast.ext) if isinstance(e, c_ast.FuncDef))
    ast.ext[first_fn:first_fn] = lit.globals
    C89().visit(ast)
    out = c_generator.CGenerator().visit(ast)
    out = out.replace("_Bool", "unsigned char")
    with tempfile.TemporaryDirectory() as t:
        c = os.path.join(t, "x.c"); o = os.path.join(t, "x.o")
        open(c, "w").write(out)
        r = subprocess.run([os.path.join(CC65, "cl65"), "-t", "c64", "-O", "-Os", "-Cl", "-c", "-o", o, c], capture_output=True, text=True)
        if r.returncode:
            errs = [l for l in r.stdout.splitlines() + r.stderr.splitlines() if "Error" in l]
            keep = os.environ.get("MIDE_GUARDA")
            if keep:
                open(os.path.join(keep, os.path.basename(path)), "w").write(out)
            return None, errs[:8]
        d = subprocess.run([os.path.join(CC65, "od65"), "--dump-segsize", o], capture_output=True, text=True).stdout
        sizes = dict((m.group(1), int(m.group(2))) for m in re.finditer(r"(\w+):\s+(\d+)", d))
        if os.environ.get("MIDE_FUNCIONES"):
            sizes["_funcs"] = func_sizes(c, t)
    return sizes, []


def func_sizes(c, t):
    """Bytes of CODE per function: cc65 -S, ca65 -l listing, size between exported labels."""
    s = os.path.join(t, "x.s"); lst = os.path.join(t, "x.lst")
    subprocess.run([os.path.join(CC65, "cc65"), "-t", "c64", "-O", "-Os", "-Cl", "-o", s, c], capture_output=True)
    subprocess.run([os.path.join(CC65, "ca65"), "-t", "c64", "-l", lst, "-o", os.path.join(t, "y.o"), s], capture_output=True)
    funcs, cur, seg = {}, None, None
    for line in open(lst, errors="replace"):
        m = re.match(r"^([0-9A-F]{6})r? \d\s+(.*)$", line)
        if not m: continue
        body = m.group(2)
        mseg = re.search(r"\.segment\s+\"(\w+)\"", body)
        if mseg: seg = mseg.group(1); continue
        lab = re.search(r"\.proc\s+_(\w+)", body)
        if lab: cur = lab.group(1); funcs.setdefault(cur, 0); continue
        if re.search(r"\.endproc", body): cur = None; continue
        if cur and seg == "CODE":
            bytes_ = re.match(r"((?:[0-9A-Fr]{2} ?){1,4})", body.strip())
            if bytes_:
                funcs[cur] += len(re.findall(r"[0-9A-Fr]{2}", bytes_.group(1)))
    return funcs


def main():
    cdir = sys.argv[1]
    tot = {}
    for f in sys.argv[2:]:
        s, errs = measure(cdir, f)
        if s is None:
            print(f"{os.path.basename(f)}: cc65 errors: " + " | ".join(errs)); continue
        funcs = s.pop("_funcs", None)
        for k, v in s.items(): tot[k] = tot.get(k, 0) + v
        print(f"{os.path.basename(f):10} " + " ".join(f"{k}={v}" for k, v in sorted(s.items()) if v))
        if funcs:
            for name, n in sorted(funcs.items(), key=lambda kv: -kv[1]):
                print(f"   {n:6} {name}")
    print("total      " + " ".join(f"{k}={v}" for k, v in sorted(tot.items()) if v))


if __name__ == "__main__":
    main()
