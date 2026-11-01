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

"""Add a call tracer (SOMBRA6502_TRAZA) to a scratch copy of the hybrid host's 6502 shadow (juego/m6502); a
deterministic text patch, applied once (every anchor must occur exactly once).

    parche_traza.py HIBRIDO_SRC_DIR

SOMBRA6502_TRAZA="FILE:ADDR[*][!],ADDR,..." (hex entry addresses of up to 16 routines; '*' = a context routine,
'!' = record its memory footprint): in the frame run (the ticks' sys_tick excluded, as the hit counter) every
execution of a listed address opens a call: its return address is read from the stack (the word at SP+1, +1) and
the call ends when the PC reaches it with SP back (SP + 2): a routine entered by a fall-through or a JMP shares the
return address of the routine that was called, and ends with it.  FILE gets one line per call: frame, routine,
index of the call, return address (the caller), A X Y SR at the entry, the cycles of the call (the host's core
counter, callees included), a 64-bit FNV-1a hash of the bytes the call read before writing them (address and value,
in the order of the reads: the call's inputs, opcode and operand fetches included), the number of such reads, the
number of writes, A and SR at the return, the context routine (the outermost active '*' routine's index, -1 for
none) and "ok" ("cut": the frame ended with the call open).  FILE.ctx_ADDR.tsv: the per-address cycles spent while
ADDR was the context (the same "ADDR\\tCYCLES" format as SOMBRA6502_PERFIL).  FILE.huella_ADDR.tsv: for a '!'
routine, every address it read before writing (R), wrote (W) or both (RW) in any of its calls.
SOMBRA6502_TRAZA_VOLCADO="DIR:ADDR/IDX,...": the IDX-th call (0-based) of ADDR dumps the 64 KiB memory and the
registers (A X Y SP SR PCL PCH 0) to DIR/vol_ADDR_IDX_pre.bin at its entry and DIR/vol_ADDR_IDX_post.bin at its
return (the same format as the round-4 parche_volcado.py), and DIR/vol_ADDR_IDX_lee.tsv lists the addresses that
call read before writing (its inputs, "ADDR\tR").  The ticks' sys_tick stepping is traced too, with the same rules,
but only when SOMBRA6502_PERFIL is set (the host steps the ticks instruction by instruction only then); a call still
open when the tick returns is cut.  The frame number of a tick's lines is the frame whose wait delivered it."""
import os
import sys

d = sys.argv[1]


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:60], s.count(old))
        s = s.replace(old, new)
    open(path, 'w', encoding='utf-8').write(s)


# memory.h: a read hook and a write hook, called before the access when set
patch(os.path.join(d, 'm6502', 'memory.h'), [
    ("extern uint8_t *MemUsados;",
     "extern uint8_t *MemUsados;\nextern void (*MemHookR)(uint16_t a, uint8_t v);   /* SOMBRA6502_TRAZA: called at every read */\n"
     "extern void (*MemHookW)(uint16_t a, uint8_t v);   /* ... and write, before the access */"),
    ("static inline void MemWriteByte(uint16_t a, uint8_t v) { if (MemUsados) MemUsados[a] |= 2; Mem[a] = v; }",
     "static inline void MemWriteByte(uint16_t a, uint8_t v) { if (MemUsados) MemUsados[a] |= 2; if (MemHookW) MemHookW(a, v); Mem[a] = v; }"),
    ("static inline uint8_t MemReadByte(uint16_t a) { if (MemUsados) MemUsados[a] |= 1; return Mem[a]; }",
     "static inline uint8_t MemReadByte(uint16_t a) { if (MemUsados) MemUsados[a] |= 1; if (MemHookR) MemHookR(a, Mem[a]); return Mem[a]; }"),
])
patch(os.path.join(d, 'm6502', 'm6502.c'), [
    ("uint8_t *MemUsados;", "uint8_t *MemUsados;\nvoid (*MemHookR)(uint16_t a, uint8_t v);\nvoid (*MemHookW)(uint16_t a, uint8_t v);"),
])

hook = r'''
/* SOMBRA6502_TRAZA (a scratch instrument, not the project's): see parche_traza.py */
#define TR_MAX 16
#define TR_PROF 32
static struct { uint16_t dir; int ctx, huella; unsigned n; } tr_rut[TR_MAX];
static int tr_n, tr_prof, tr_ctx_cur = -1;
static unsigned tr_frame;
static FILE *tr_out;
static char tr_base[256], tr_voldir[256];
static struct { int r, ctx; unsigned idx, frame; uint16_t ret; uint8_t sp0, a, x, y, sr; uint64_t c0, h; unsigned nr, nw; uint8_t *w, *rd; char vol[300]; } tr_pila[TR_PROF];
static uint64_t *tr_pctx[TR_MAX];
static uint8_t *tr_hr[TR_MAX], *tr_hw[TR_MAX];
static struct { uint16_t dir; unsigned idx; } tr_vol[16];
static int tr_nvol;
static uint64_t tr_mix(uint64_t h, uint16_t a, uint8_t v)
{
    h ^= a & 0xFF; h *= 1099511628211ull;
    h ^= a >> 8; h *= 1099511628211ull;
    h ^= v; h *= 1099511628211ull;
    return h;
}
static void tr_lee(uint16_t a, uint8_t v)
{
    int i;
    for (i = 0; i < tr_prof; i++)
        if (!tr_pila[i].w[a]) {
            tr_pila[i].h = tr_mix(tr_pila[i].h, a, v);
            tr_pila[i].nr++;
            if (tr_pila[i].vol[0]) tr_pila[i].rd[a] = 1;
            if (tr_rut[tr_pila[i].r].huella) tr_hr[tr_pila[i].r][a] = 1;
        }
}
static void tr_escribe(uint16_t a, uint8_t v)
{
    int i;
    (void)v;
    for (i = 0; i < tr_prof; i++) {
        tr_pila[i].w[a] = 1;
        tr_pila[i].nw++;
        if (tr_rut[tr_pila[i].r].huella) tr_hw[tr_pila[i].r][a] = 1;
    }
}
static void tr_carga(const char *e)
{
    const char *p = strchr(e, ':');
    int i;
    if (!p) return;
    snprintf(tr_base, sizeof tr_base, "%.*s", (int)(p - e), e);
    p++;
    tr_out = fopen(tr_base, "w");
    if (!tr_out) { fprintf(stderr, "cannot write %s\n", tr_base); exit(1); }
    fprintf(tr_out, "frame\trut\tidx\tret\ta\tx\ty\tsr\tcycles\thash\tnr\tnw\ta_out\tsr_out\tctx\tend\n");
    while (*p && tr_n < TR_MAX) {
        unsigned a;
        int k = 0;
        if (sscanf(p, "%x%n", &a, &k) != 1 || !k) break;
        p += k;
        tr_rut[tr_n].dir = (uint16_t)a;
        while (*p == '*' || *p == '!') { if (*p == '*') tr_rut[tr_n].ctx = 1; else tr_rut[tr_n].huella = 1; p++; }
        if (tr_rut[tr_n].ctx) tr_pctx[tr_n] = calloc(0x10000, sizeof(uint64_t));
        if (tr_rut[tr_n].huella) { tr_hr[tr_n] = calloc(0x10000, 1); tr_hw[tr_n] = calloc(0x10000, 1); }
        tr_n++;
        if (*p != ',') break;
        p++;
    }
    for (i = 0; i < TR_PROF; i++) { tr_pila[i].w = malloc(0x10000); tr_pila[i].rd = malloc(0x10000); }
    if ((e = getenv("SOMBRA6502_TRAZA_VOLCADO")) != NULL && (p = strchr(e, ':')) != NULL) {
        snprintf(tr_voldir, sizeof tr_voldir, "%.*s", (int)(p - e), e);
        p++;
        while (*p && tr_nvol < 16) {
            unsigned a, k;
            if (sscanf(p, "%x/%u", &a, &k) != 2) break;
            tr_vol[tr_nvol].dir = (uint16_t)a; tr_vol[tr_nvol].idx = k; tr_nvol++;
            p = strchr(p, ',');
            if (!p) break;
            p++;
        }
    }
}
static void tr_vuelca(const char *f)
{
    FILE *o = fopen(f, "wb");
    uint8_t r[8];
    if (!o) { fprintf(stderr, "cannot write %s\n", f); exit(1); }
    r[0] = Regs.AC; r[1] = Regs.XR; r[2] = Regs.YR; r[3] = Regs.SP; r[4] = Regs.SR; r[5] = Regs.PC & 0xFF; r[6] = Regs.PC >> 8; r[7] = 0;
    fwrite(Mem, 1, 0x10000, o);
    fwrite(r, 1, 8, o);
    fclose(o);
}
static void tr_entrada(uint16_t pc)
{
    int k, i;
    for (k = 0; k < tr_n; k++) {
        if (tr_rut[k].dir != pc) continue;
        if (tr_prof >= TR_PROF) { fprintf(stderr, "SOMBRA6502_TRAZA: the stack of calls is full at %04X\n", pc); tr_rut[k].n++; return; }
        {
            uint8_t sp0 = Regs.SP;
            char f[400];
            tr_pila[tr_prof].r = k; tr_pila[tr_prof].idx = tr_rut[k].n++; tr_pila[tr_prof].frame = tr_frame;
            tr_pila[tr_prof].ret = (uint16_t)((Mem[0x100 | ((sp0 + 1) & 0xFF)] | Mem[0x100 | ((sp0 + 2) & 0xFF)] << 8) + 1);
            tr_pila[tr_prof].sp0 = sp0;
            tr_pila[tr_prof].a = Regs.AC; tr_pila[tr_prof].x = Regs.XR; tr_pila[tr_prof].y = Regs.YR; tr_pila[tr_prof].sr = Regs.SR;
            tr_pila[tr_prof].c0 = Peripherals.Counter.ClockCycles;
            tr_pila[tr_prof].h = 14695981039346656037ull;
            tr_pila[tr_prof].nr = tr_pila[tr_prof].nw = 0;
            memset(tr_pila[tr_prof].w, 0, 0x10000);
            if (tr_rut[k].ctx && tr_ctx_cur < 0) tr_ctx_cur = k;
            tr_pila[tr_prof].ctx = tr_ctx_cur;
            tr_pila[tr_prof].vol[0] = 0;
            for (i = 0; i < tr_nvol; i++)
                if (tr_vol[i].dir == pc && tr_vol[i].idx == tr_pila[tr_prof].idx) {
                    snprintf(tr_pila[tr_prof].vol, sizeof tr_pila[tr_prof].vol, "%s/vol_%04X_%u", tr_voldir, pc, tr_vol[i].idx);
                    snprintf(f, sizeof f, "%s_pre.bin", tr_pila[tr_prof].vol);
                    tr_vuelca(f);
                    memset(tr_pila[tr_prof].rd, 0, 0x10000);
                }
            tr_prof++;
            MemHookR = tr_lee; MemHookW = tr_escribe;
        }
        return;
    }
}
static void tr_emite(int i, const char *fin)
{
    char f[400];
    fprintf(tr_out, "%u\t%04X\t%u\t%04X\t%02X\t%02X\t%02X\t%02X\t%llu\t%016llx\t%u\t%u\t%02X\t%02X\t%d\t%s\n",
            tr_pila[i].frame, tr_rut[tr_pila[i].r].dir, tr_pila[i].idx, tr_pila[i].ret, tr_pila[i].a, tr_pila[i].x, tr_pila[i].y,
            tr_pila[i].sr, (unsigned long long)(Peripherals.Counter.ClockCycles - tr_pila[i].c0), (unsigned long long)tr_pila[i].h,
            tr_pila[i].nr, tr_pila[i].nw, Regs.AC, Regs.SR, tr_pila[i].ctx, fin);
    if (tr_pila[i].vol[0]) {
        FILE *o;
        unsigned a;
        snprintf(f, sizeof f, "%s_post.bin", tr_pila[i].vol); tr_vuelca(f);
        snprintf(f, sizeof f, "%s_lee.tsv", tr_pila[i].vol);        /* the call's inputs: read before written */
        o = fopen(f, "w");
        if (o) { for (a = 0; a < 0x10000; a++) if (tr_pila[i].rd[a]) fprintf(o, "%04X\tR\n", a); fclose(o); }
    }
}
static void tr_recalcula(void)
{
    int i;
    tr_ctx_cur = -1;
    for (i = 0; i < tr_prof; i++) if (tr_rut[tr_pila[i].r].ctx) { tr_ctx_cur = tr_pila[i].r; break; }
    if (!tr_prof) { MemHookR = NULL; MemHookW = NULL; }
}
static void tr_salida(void)
{
    while (tr_prof > 0) {
        int i = tr_prof - 1;
        if (Regs.PC != tr_pila[i].ret || Regs.SP != (uint8_t)(tr_pila[i].sp0 + 2)) break;
        tr_emite(i, "ok");
        tr_prof--;
    }
    tr_recalcula();
}
static void tr_corte(void)
{
    while (tr_prof > 0) { tr_emite(tr_prof - 1, "cut"); tr_prof--; }
    tr_recalcula();
}
static void tr_fin(void)
{
    int k;
    unsigned a;
    char f[400];
    if (!tr_out) return;
    fclose(tr_out);
    for (k = 0; k < tr_n; k++) {
        FILE *o;
        if (tr_pctx[k]) {
            snprintf(f, sizeof f, "%s.ctx_%04X.tsv", tr_base, tr_rut[k].dir);
            o = fopen(f, "w");
            if (o) { for (a = 0; a < 0x10000; a++) if (tr_pctx[k][a]) fprintf(o, "%04X\t%llu\n", a, (unsigned long long)tr_pctx[k][a]); fclose(o); }
        }
        if (tr_hr[k]) {
            snprintf(f, sizeof f, "%s.huella_%04X.tsv", tr_base, tr_rut[k].dir);
            o = fopen(f, "w");
            if (o) {
                for (a = 0; a < 0x10000; a++)
                    if (tr_hr[k][a] || tr_hw[k][a]) fprintf(o, "%04X\t%s\n", a, tr_hr[k][a] && tr_hw[k][a] ? "RW" : tr_hr[k][a] ? "R" : "W");
                fclose(o);
            }
        }
    }
}
'''

anchor = "void sombra6502_juego_inicio(const char *dir, const uint8_t *ram, const plataforma_t *p)"
patch(os.path.join(d, 'm6502', 'sombra6502.c'), [
    (anchor, hook + "\n" + anchor),
    ("""            if (pc == j_frame) { j_retoma = 1; return 1; }
            if (pc == j_pausa) { j_pasa(); j_retoma = 1; return 1; }
            if (pc == j_final) return 2;""",
     """            if (pc == j_frame) { if (tr_n) tr_corte(); j_retoma = 1; return 1; }
            if (pc == j_pausa) { if (tr_n) tr_corte(); j_pasa(); j_retoma = 1; return 1; }
            if (pc == j_final) { if (tr_n) tr_corte(); return 2; }"""),
    ("""        j_retoma = 0;
        if (j_perfil || j_cat) {
            uint64_t c1 = Peripherals.Counter.ClockCycles;
            int k;
            ExecuteInsn();
            if (j_perfil) j_perfil[pc] += Peripherals.Counter.ClockCycles - c1;
            if (j_cat) {
                j_cat_ciclos[j_cat[pc]] += (unsigned long)(Peripherals.Counter.ClockCycles - c1);
                for (k = 0; k < j_hits; k++) if (j_hit_dir[k] == pc) j_hit_n[k]++;
            }
        }
        else ExecuteInsn();
        if (Peripherals.Counter.ClockCycles - c0 > 400000000ull) return 0;""",
     """        j_retoma = 0;
        if (tr_n) tr_entrada(pc);
        if (j_perfil || j_cat || tr_n) {
            uint64_t c1 = Peripherals.Counter.ClockCycles;
            int k;
            ExecuteInsn();
            if (j_perfil) j_perfil[pc] += Peripherals.Counter.ClockCycles - c1;
            if (j_cat) {
                j_cat_ciclos[j_cat[pc]] += (unsigned long)(Peripherals.Counter.ClockCycles - c1);
                for (k = 0; k < j_hits; k++) if (j_hit_dir[k] == pc) j_hit_n[k]++;
            }
            if (tr_n) {
                if (tr_ctx_cur >= 0) tr_pctx[tr_ctx_cur][pc] += Peripherals.Counter.ClockCycles - c1;
                if (tr_prof) tr_salida();
            }
        }
        else ExecuteInsn();
        if (Peripherals.Counter.ClockCycles - c0 > 400000000ull) { if (tr_n) tr_corte(); return 0; }"""),
    ("""    if (getenv("SOMBRA6502_CATEGORIAS")) j_cat_carga(getenv("SOMBRA6502_CATEGORIAS"));
    Regs.SP = 0xFF;""",
     """    if (getenv("SOMBRA6502_CATEGORIAS")) j_cat_carga(getenv("SOMBRA6502_CATEGORIAS"));
    if (getenv("SOMBRA6502_TRAZA")) tr_carga(getenv("SOMBRA6502_TRAZA"));
    Regs.SP = 0xFF;"""),
    ("""    uint64_t c0 = Peripherals.Counter.ClockCycles;
    memcpy(Mem + PLAT_TECLADO, pe->teclado, 10);""",
     """    uint64_t c0 = Peripherals.Counter.ClockCycles;
    tr_frame = frame;
    memcpy(Mem + PLAT_TECLADO, pe->teclado, 10);"""),
    ("""    if (j_perfil) {                                     /* address, cycles: the labels are put on by a script */
        FILE *o = fopen(getenv("SOMBRA6502_PERFIL"), "w");""",
     """    tr_fin();
    if (j_perfil) {                                     /* address, cycles: the labels are put on by a script */
        FILE *o = fopen(getenv("SOMBRA6502_PERFIL"), "w");"""),
    ("""            while (!(Regs.PC == 0x0000 && Regs.SP == sp0)) {
                uint16_t p = Regs.PC;
                uint64_t c1 = Peripherals.Counter.ClockCycles;
                ExecuteInsn();
                j_perfil[p] += Peripherals.Counter.ClockCycles - c1;
            }""",
     """            while (!(Regs.PC == 0x0000 && Regs.SP == sp0)) {
                uint16_t p = Regs.PC;
                uint64_t c1 = Peripherals.Counter.ClockCycles;
                if (tr_n) tr_entrada(p);
                ExecuteInsn();
                j_perfil[p] += Peripherals.Counter.ClockCycles - c1;
                if (tr_n) {
                    if (tr_ctx_cur >= 0) tr_pctx[tr_ctx_cur][p] += Peripherals.Counter.ClockCycles - c1;
                    if (tr_prof) tr_salida();
                }
            }
            if (tr_n) tr_corte();"""),
])
print("patched")
