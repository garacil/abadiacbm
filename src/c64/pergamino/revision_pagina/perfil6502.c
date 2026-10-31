/*
 * abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
 *
 * Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
 * Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see
 * <https://www.gnu.org/licenses/>.
 */

/* The page turn's own cycles, routine by routine and step by step, on a 6502 core (juego/m6502: cc65's sim65 core,
 * cycle-exact for the CPU; no VIC DMA, no interrupt).
 *
 *     perfil6502 RAM.bin LBL [STEPS.tsv]
 *
 * RAM.bin: the C64's 64 KiB at the entry of _pasa_pagina (perfil.py takes it from VICE), LBL the build's ld65 label
 * file with debug symbols (cl65 -g, so the local routines have names).  _espera is made to return at once (its
 * waits are not the drawing's); _pasa_pagina runs to its RTS.  Prints the cycles by routine (each instruction
 * counted in the routine whose label is the nearest below it) and, with STEPS.tsv, the cycles of each step's
 * corner (from the call of _esquina_asm to the call of plazo) and restores (from the return of _espera to the next
 * corner). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "m6502.h"
#include "peripherals.h"

extern PeripheralsType Peripherals;

static struct { unsigned a; char n[64]; } et[4096];
static int net;

static int cmp(const void *x, const void *y) { return (int)((const typeof(et[0]) *)x)->a - (int)((const typeof(et[0]) *)y)->a; }

static unsigned dir(const char *n)
{
    for (int i = 0; i < net; ++i) if (!strcmp(et[i].n, n)) return et[i].a;
    fprintf(stderr, "no label %s\n", n); exit(2);
}

int main(int argc, char **argv)
{
    if (argc < 3) { fprintf(stderr, "perfil6502 RAM.bin LBL [STEPS.tsv]\n"); return 2; }
    FILE *f = fopen(argv[1], "rb");
    if (!f || fread(Mem, 1, 0x10000, f) != 0x10000) { fprintf(stderr, "RAM\n"); return 2; }
    fclose(f);
    f = fopen(argv[2], "r");
    char l[256];
    while (f && fgets(l, sizeof l, f)) {
        unsigned a; char n[200];
        if (sscanf(l, "al %x .%199s", &a, n) == 2 && a >= 0x0801 && a < 0x8000 && n[0] != '@' && strncmp(n, "__", 2)
            && net < 4096) {
            et[net].a = a; strncpy(et[net].n, n, 63); ++net;
        }
    }
    if (f) fclose(f);
    qsort(et, net, sizeof et[0], cmp);
    unsigned pasa = dir("_pasa_pagina"), esq = dir("_esquina_asm"), esp = dir("_espera"), plazo = dir("plazo");
    Mem[esp] = 0x60;                                            /* RTS */
    static unsigned long long por[4096];
    m6502_init();
    Regs.SR |= 0x04;
    uint8_t sp0 = Regs.SP;
    Mem[0x0100 | Regs.SP] = 0xFF; Regs.SP--;
    Mem[0x0100 | Regs.SP] = 0xFF; Regs.SP--;
    Regs.PC = pasa;
    unsigned long long total = 0, t_esq = 0, t_plazo = 0, t_ret = 0;
    FILE *o = argc > 3 ? fopen(argv[3], "w") : NULL;
    if (o) fprintf(o, "step\tcorner_cycles\trestore_cycles_before_it\n");
    int paso = 0, en_espera = 0;
    while (!(Regs.PC == 0x0000 && Regs.SP == sp0)) {
        unsigned pc = Regs.PC;
        if (pc == esq) {
            ++paso;
            if (o && paso > 1) fprintf(o, "%d\t%llu\t%llu\n", paso - 1, t_plazo - t_esq, total - t_ret);
            t_esq = total;
        }
        if (pc == plazo) t_plazo = total;
        if (pc == esp) en_espera = 1;
        unsigned c = ExecuteInsn();
        if (en_espera && Regs.PC != esp) { en_espera = 0; t_ret = total + c; }
        int lo = 0, hi = net - 1, k = -1;
        while (lo <= hi) { int m = (lo + hi) / 2; if (et[m].a <= pc) { k = m; lo = m + 1; } else hi = m - 1; }
        if (k >= 0) por[k] += c;
        total += c;
        if (total > 200000000ULL) { fprintf(stderr, "runaway\n"); return 3; }
    }
    if (o) { fprintf(o, "%d\t%llu\t%llu\n", paso, t_plazo - t_esq, total - t_ret); fclose(o); }
    printf("total %llu cycles, %d corners\n", total, paso);
    for (int n = 0; n < 30; ++n) {
        int m = -1;
        for (int i = 0; i < net; ++i) if (por[i] && (m < 0 || por[i] > por[m])) m = i;
        if (m < 0) break;
        printf("%10llu %5.1f%% %s\n", por[m], 100.0 * por[m] / total, et[m].n);
        por[m] = 0;
    }
    return 0;
}
