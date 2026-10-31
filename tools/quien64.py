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

"""Who reads and writes each datum of the CPC 64 KiB game: the 8 exploration sessions run again by a copy
of the hybrid host (src/juego/hibrido.c, not modified: the copy is patched in a temporary directory) whose
--accesos also records, per address, the instruction addresses that read or wrote it (up to NQ per address
and session; a warning says when an address outside the Z80 stack BF53h-BFFFh has more: none has).

    quien64.py            -> data/cpc64/accesos/quien_pc.tsv (address, every instruction address that read or wrote it: XXXXr / XXXXw)
                             data/cpc64/accesos/quien.tsv    (address, functions: name:rw)

The Z80 core (superzazu) executes BIT n,(HL) as a read-modify-write: those writes are not the program's
and are dropped here (the plain --accesos files keep them).  The function of a PC is the entry of
data/cpc64/funciones64.tsv at or before it.
"""
import bisect, glob, os, subprocess, sys, tempfile

P = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
J = os.path.join(P, "src", "juego")
C = os.path.join(P, "data", "cpc64")
NQ = 64                                   # enough for every address: the sets are complete, not the first few

def parchea(src):
    s = open(src).read()
    viejo_lee = """static uint8_t lee(void *u, uint16_t a)
{
    (void)u;
    if (accesos && (uint16_t)(a - pc_instruccion) >= 4) accesos[a] |= 1;
    return ram[a];
}
static void escribe(void *u, uint16_t a, uint8_t v) { (void)u; if (accesos) accesos[a] |= 2; ram[a] = v; }"""
    nuevo_lee = """#define NQ %d
static uint32_t (*quien)[NQ];
static void anota_quien(uint16_t a, unsigned w)
{
    uint32_t k = ((uint32_t)pc_instruccion << 1 | w) + 1;
    int i;
    if (!quien) return;
    for (i = 0; i < NQ; ++i) { if (quien[a][i] == k) return; if (!quien[a][i]) { quien[a][i] = k; return; } }
}
static uint8_t lee(void *u, uint16_t a)
{
    (void)u;
    if (accesos && (uint16_t)(a - pc_instruccion) >= 4) { accesos[a] |= 1; anota_quien(a, 0); }
    return ram[a];
}
static void escribe(void *u, uint16_t a, uint8_t v) { (void)u; if (accesos) { accesos[a] |= 2; anota_quien(a, 1); } ram[a] = v; }""" % NQ
    viejo_opc = """        else if (!strcmp(argv[i], "--accesos") && i + 1 < argc) { accesos = calloc(0x10000, 1); salida_accesos = argv[++i]; }"""
    nuevo_opc = """        else if (!strcmp(argv[i], "--accesos") && i + 1 < argc) { accesos = calloc(0x10000, 1); salida_accesos = argv[++i]; quien = calloc(0x10000, sizeof *quien); }"""
    viejo_sal = """        for (k = 0; k < 0x10000; ++k) if (accesos[k]) fprintf(f, "%04X %c%c\\n", k, accesos[k] & 1 ? 'r' : '-', accesos[k] & 2 ? 'w' : '-');"""
    nuevo_sal = """        for (k = 0; k < 0x10000; ++k) if (accesos[k]) {
            int j;
            fprintf(f, "%04X %c%c", k, accesos[k] & 1 ? 'r' : '-', accesos[k] & 2 ? 'w' : '-');
            for (j = 0; j < NQ && quien[k][j]; ++j) fprintf(f, " %04X%c", (quien[k][j] - 1) >> 1, (quien[k][j] - 1) & 1 ? 'w' : 'r');
            fprintf(f, "\\n");
        }"""
    for a, b in ((viejo_lee, nuevo_lee), (viejo_opc, nuevo_opc), (viejo_sal, nuevo_sal)):
        if a not in s: raise SystemExit("hibrido.c changed: quien64.py must be updated")
        s = s.replace(a, b)
    return s

def main():
    ram = open(os.path.join(C, "juego", "ram.bin"), "rb").read()
    with tempfile.TemporaryDirectory() as t:
        open(os.path.join(t, "hibrido_quien.c"), "w").write(parchea(os.path.join(J, "hibrido.c")))
        fuentes = [f for f in sorted(glob.glob(os.path.join(J, "*.c"))) if not f.endswith("hibrido.c")]
        exe = os.path.join(t, "hibrido_quien")
        subprocess.run(["gcc", "-std=c99", "-O2", "-w", "-I" + J, "-o", exe, os.path.join(t, "hibrido_quien.c")] + fuentes +
                       [os.path.join(J, "z80", "z80.c"), os.path.join(J, "m6502", "m6502.c"), os.path.join(J, "m6502", "6502.c"),
                        os.path.join(J, "m6502", "sombra6502.c")], check=True)
        procs = []
        for i in range(1, 9):
            procs.append(subprocess.Popen([exe, os.path.join(C, "inicio_juego", "ram.bin"), os.path.join(C, "inicio_juego", "estado.txt"),
                                           os.path.join(P, "data", "sincrono", "puntos64.txt"), "--guion",
                                           os.path.join(C, "exploracion", f"azar{i}.txt"), "--hasta", "4472", "--limite", "50000000",
                                           "--accesos", os.path.join(t, f"q{i}.txt")], cwd=J, stderr=subprocess.DEVNULL))
        for p in procs: p.wait()
        q = {}
        llenos = 0
        for i in range(1, 9):
            for l in open(os.path.join(t, f"q{i}.txt")):
                x = l.split(); a = int(x[0], 16)
                if len(x) - 2 >= NQ and not 0xBF53 <= a <= 0xBFFF: llenos += 1   # (the Z80 stack is everyone's)
                s = q.setdefault(a, set())
                for y in x[2:]:
                    pc = int(y[:4], 16)
                    if y[4] == "w" and ram[pc] == 0xCB and (ram[pc + 1] & 0xC7) == 0x46: continue   # BIT n,(HL)
                    s.add(y)
    ent, nom = [], {}
    for l in open(os.path.join(C, "funciones64.tsv")):
        if l[0] in "#a": continue
        x = l.rstrip("\n").split("\t"); a = int(x[0], 16); ent.append(a); nom[a] = x[1]
    ent.sort()
    def fn(pc):
        i = bisect.bisect_right(ent, pc) - 1
        return nom[ent[i]] if i >= 0 else "?"
    o1 = ["# address, every instruction address that read (r) / wrote (w) it as data in the 8 sessions (quien64.py)"]
    o2 = ["# address, the functions that read (r) / wrote (w) it as data in the 8 sessions (quien64.py; function = entry of funciones64.tsv at or before the PC)"]
    for a in sorted(q):
        if not q[a]: continue
        o1.append(f"{a:04X}\t" + " ".join(sorted(q[a])))
        fs = {}
        for y in q[a]: fs.setdefault(fn(int(y[:4], 16)), set()).add(y[4])
        o2.append(f"{a:04X}\t" + " ".join(f"{k}:{''.join(sorted(v))}" for k, v in sorted(fs.items())))
    open(os.path.join(C, "accesos", "quien_pc.tsv"), "w").write("\n".join(o1) + "\n")
    open(os.path.join(C, "accesos", "quien.tsv"), "w").write("\n".join(o2) + "\n")
    print(f"{len(o2) - 1} addresses" + (f"; {llenos} address-sessions reached NQ = {NQ} instructions (raise NQ)" if llenos else ""))

main()
