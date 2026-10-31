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

/* abadia64ks: plat_psg (c64/plataforma/psg.s) against the reference (pruebas/psg_antes.s, the one before the
 * interrupt work) on sim65's core: every SID write, in order, for the same AY write streams; A, X and the I flag
 * kept; the cycles of each register's writes (JSR included).  Then the new one again from memory full of $A5
 * (the BSS the loader does not load): the same SID writes as from a clear memory (psg_inicio clears its state).
 *   psg NEW.bin NEW.lbl REF.bin REF.lbl STREAM...   (each image psg.s alone at $1000, psg.cfg; STREAM:
 *   "exhaustivo" (every period of every channel with the tone on, the noise on and off, every noise period and
 *   volume, six mixers), "azar" (400000 random writes), or a file of 'TICK REGISTER VALUE' lines: the AY writes
 *   of the GNU build, abadia64ks-puro --ay)
 * Build (prueba.sh): a copy of juego/m6502's core with pruebas/memory.h (a write hook) in place of its own. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "m6502.h"
#include "memory.h"
#include "peripherals.h"
void (*mem_al_escribir)(uint16_t a, uint8_t v);

typedef struct { uint8_t img[0x8000]; size_t n; uint16_t psg, ini; } imagen_t;
typedef struct { unsigned long llamada; uint16_t a; uint8_t v; } escritura_t;
static escritura_t *esc; static size_t nesc, cesc; static unsigned long n_llamada;
static void anota(uint16_t a, uint8_t v)
{
    if (a < 0xD400 || a >= 0xD420) return;
    if (nesc == cesc) { cesc = cesc ? 2 * cesc : 1 << 20; esc = realloc(esc, cesc * sizeof *esc); if (!esc) exit(3); }
    esc[nesc].llamada = n_llamada; esc[nesc].a = a; esc[nesc].v = v; ++nesc;
}
static uint16_t etiqueta(const char *lbl, const char *n)
{
    char l[256], nom[128]; unsigned a; FILE *f = fopen(lbl, "r");
    if (!f) { perror(lbl); exit(2); }
    while (fgets(l, sizeof l, f)) if (sscanf(l, "al %x .%127s", &a, nom) == 2 && !strcmp(nom, n)) { fclose(f); return (uint16_t)a; }
    fprintf(stderr, "psg: no %s in %s\n", n, lbl); exit(2);
}
static void carga(imagen_t *im, const char *bin, const char *lbl)
{
    FILE *f = fopen(bin, "rb");
    if (!f) { perror(bin); exit(2); }
    im->n = fread(im->img, 1, sizeof im->img, f); fclose(f);
    im->psg = etiqueta(lbl, "plat_psg"); im->ini = etiqueta(lbl, "psg_inicio");
}
static unsigned semilla;
static unsigned azar(void) { semilla = semilla * 1103515245u + 12345u; return (semilla >> 16) & 0x7FFF; }
static unsigned long long ciclos[16]; static unsigned long cuenta[16], mal_regs;
static imagen_t *actual;
static void llama(uint8_t r, uint8_t v)
{
    uint8_t sr = (uint8_t)(0x30 | ((azar() & 1) ? 0x04 : 0) | (azar() & 0xC3)), y = (uint8_t)azar();
    unsigned long c;
    Regs.SR = sr; ++n_llamada;
    c = m6502_llama(actual->psg, r, v, y, 100000);
    if (!c) { fprintf(stderr, "psg: plat_psg does not return\n"); exit(3); }
    if (Regs.AC != r || Regs.XR != v || (Regs.SR & 0x04) != (sr & 0x04)) ++mal_regs;
    if (r < 16) { ciclos[r] += c + 6; cuenta[r]++; }
}
/* every stream on image im from memory full of `relleno`: the SID writes into esc[] */
static void corre(imagen_t *im, int relleno, int nflujos, char **flujos)
{
    int i;
    actual = im; nesc = 0; n_llamada = 0; semilla = 12345; mal_regs = 0;
    memset(ciclos, 0, sizeof ciclos); memset(cuenta, 0, sizeof cuenta);
    for (i = 0; i < nflujos; ++i) {
        memset(Mem, relleno, sizeof Mem);
        memcpy(Mem + 0x1000, im->img, im->n);
        Regs.SP = 0xFF;
        mem_al_escribir = anota;
        ++n_llamada;
        m6502_llama(im->ini, 0, 0, 0, 100000);
        if (!strcmp(flujos[i], "exhaustivo")) {
            static const uint8_t mezclas[] = { 0x38, 0x07, 0x3F, 0x00, 0x2A, 0x15 };
            unsigned m, c, p;
            for (m = 0; m < sizeof mezclas; ++m) {
                llama(7, mezclas[m]);
                for (c = 0; c < 3; ++c) llama((uint8_t)(8 + c), (uint8_t)(m * 3 + c));
                for (c = 0; c < 3; ++c) for (p = 0; p < 4096; ++p) {
                    llama((uint8_t)(2 * c), (uint8_t)p);
                    llama((uint8_t)(2 * c + 1), (uint8_t)((p >> 8) | (azar() & 0xF0)));
                }
                for (p = 0; p < 256; ++p) llama(6, (uint8_t)p);
                for (c = 0; c < 3; ++c) for (p = 0; p < 256; ++p) llama((uint8_t)(8 + c), (uint8_t)p);
            }
        }
        else if (!strcmp(flujos[i], "azar")) {
            unsigned k;
            for (k = 0; k < 400000; ++k) {
                unsigned r = azar() % 20; uint8_t v = (uint8_t)azar();
                if (r >= 16) r = r - 16 + 4;            /* more tone writes */
                if (r == 7 && (azar() & 1)) v &= 0x3F;
                llama((uint8_t)r, v);
            }
        }
        else {
            char l[128]; unsigned t, r, v; FILE *g = fopen(flujos[i], "r");
            if (!g) { perror(flujos[i]); exit(2); }
            while (fgets(l, sizeof l, g)) if (sscanf(l, "%u %u %u", &t, &r, &v) == 3) llama((uint8_t)r, (uint8_t)v);
            fclose(g);
        }
        mem_al_escribir = NULL;
    }
}
int main(int argc, char **argv)
{
    static imagen_t nuevo, ref;
    escritura_t *e1; size_t n1, k; int i, mal = 0;
    unsigned long long c1[16]; unsigned long q1[16];
    if (argc < 6) { fprintf(stderr, "psg NEW.bin NEW.lbl REF.bin REF.lbl STREAM...\n"); return 2; }
    carga(&nuevo, argv[1], argv[2]); carga(&ref, argv[3], argv[4]);
    m6502_init();
    corre(&ref, 0, argc - 5, argv + 5);
    e1 = esc; n1 = nesc; esc = NULL; nesc = cesc = 0;
    memcpy(c1, ciclos, sizeof c1); memcpy(q1, cuenta, sizeof q1);
    if (mal_regs) { printf("the reference changed A, X or the I flag in %lu calls\n", mal_regs); mal = 1; }
    corre(&nuevo, 0, argc - 5, argv + 5);
    if (mal_regs) { printf("plat_psg changed A, X or the I flag in %lu calls\n", mal_regs); mal = 1; }
    if (nesc != n1) { printf("%zu SID writes against the reference's %zu\n", nesc, n1); mal = 1; }
    for (k = 0; k < nesc && k < n1; ++k)
        if (esc[k].llamada != e1[k].llamada || esc[k].a != e1[k].a || esc[k].v != e1[k].v) {
            printf("SID write %zu (call %lu): %04X = %02X against the reference's (call %lu) %04X = %02X\n", k, esc[k].llamada,
                   esc[k].a, esc[k].v, e1[k].llamada, e1[k].a, e1[k].v);
            mal = 1; break;
        }
    printf("%zu SID writes in %lu calls: %s the reference's\n", nesc, n_llamada, mal ? "NOT" : "the same as");
    for (i = 0; i < 16; ++i)
        if (cuenta[i]) printf("  register %2d: %8lu writes, %6.1f cycles each (reference %6.1f)\n", i, cuenta[i],
                              (double)ciclos[i] / cuenta[i], (double)c1[i] / q1[i]);
    free(e1); e1 = esc; n1 = nesc; esc = NULL; nesc = cesc = 0;
    corre(&nuevo, 0xA5, argc - 5, argv + 5);
    for (k = 0; k < nesc && k < n1 && esc[k].llamada == e1[k].llamada && esc[k].a == e1[k].a && esc[k].v == e1[k].v; ++k) {}
    if (k != nesc || nesc != n1) { printf("from memory full of $A5: the SID writes differ from %zu on\n", k); mal = 1; }
    else printf("from memory full of $A5 (BSS not loaded): the same SID writes\n");
    return mal;
}
