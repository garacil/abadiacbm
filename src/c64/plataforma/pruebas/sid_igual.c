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

/* abadia64ks: an AY -> SID player against another, on sim65's 6502 core: the same notes at the same moments.
 * The SID voicing may differ (waveform, pulse width, envelope rates, filter); what must not: for every write call
 * (and every tick routine call), for each voice,
 *   - the gate's changes written to its control register during the call, in order (a note starts, a note is
 *     struck again, a note stops: on the same write of the same tick),
 *   - after the call: the gate; while it is on, the frequency and the waveform's kind (noise or a tone).
 * The cycles of each call are counted (JSR included): per AY register, and per tick for the log streams.
 *
 *   sid_igual [--regs] [--a5] ENTRY INIT INIT_A REF.bin REF.lbl REF_TICK NEW.bin NEW.lbl NEW_TICK STREAM...
 *
 * Each image: the player alone, linked at $1000 (its zero page, if any, below $0100); ENTRY (A = register,
 * X = value), INIT (called once with A = INIT_A before each stream), REF_TICK / NEW_TICK: a routine called once a
 * tick after the tick's writes ("-": none).  STREAM: "exhaustivo" (every period of every channel with the tone on,
 * the noise on and off, every noise period and volume, six mixers; no ticks), "azar" (400000 random writes, one a
 * tick), or a file of 'TICK REGISTER VALUE' lines (the GNU build's --ay, galeria_ay, the parchments' logs).
 * --regs: ENTRY must keep A, X and the I flag (plat_psg).  --a5: the new image again from memory full of $A5 (the
 * BSS the loader does not load): the same SID writes as from a clear memory.
 * Build: a copy of juego/m6502's core with memoria_gancho.h as its memory.h (a write hook).  Exits 1 on a
 * difference. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "m6502.h"
#include "memory.h"
#include "peripherals.h"
void (*mem_al_escribir)(uint16_t a, uint8_t v);

typedef struct { uint8_t img[0xF000]; size_t n; uint16_t entrada, inicio, tick; } imagen_t;
/* one call: per voice the gate's changes (bit k of cambios = the k-th new gate value, n of them), and after it
 * the gate, the frequency and the waveform's kind (0 none, 1 tone, 2 noise) */
typedef struct { uint8_t n[3], cambios[3], puerta[3], clase[3]; uint16_t frec[3]; } llamada_t;

static llamada_t *reg; static size_t nreg, creg;
static llamada_t actual_ll;
static uint8_t puerta_sid[3];
static unsigned long long huella;                  /* FNV-1a of every SID write (address, value, call) */
static unsigned long n_llamada;

static void anota(uint16_t a, uint8_t v)
{
    unsigned k;
    if (a < 0xD400 || a >= 0xD419) return;
    huella = (huella ^ (a & 0xFF)) * 1099511628211ull;
    huella = (huella ^ v) * 1099511628211ull;
    huella = (huella ^ (n_llamada & 0xFF)) * 1099511628211ull;
    for (k = 0; k < 3; ++k)
        if (a == 0xD404 + 7 * k && (v & 1) != puerta_sid[k]) {
            puerta_sid[k] = v & 1;
            if (actual_ll.n[k] < 8) actual_ll.cambios[k] |= (uint8_t)((v & 1) << actual_ll.n[k]);
            ++actual_ll.n[k];
        }
}
static uint16_t etiqueta(const char *lbl, const char *n)
{
    char l[256], nom[128]; unsigned a; FILE *f = fopen(lbl, "r");
    if (!f) { perror(lbl); exit(2); }
    while (fgets(l, sizeof l, f)) if (sscanf(l, "al %x .%127s", &a, nom) == 2 && !strcmp(nom, n)) { fclose(f); return (uint16_t)a; }
    fprintf(stderr, "sid_igual: no %s in %s\n", n, lbl); exit(2);
}
static void carga(imagen_t *im, const char *bin, const char *lbl, const char *entrada, const char *inicio, const char *tick)
{
    FILE *f = fopen(bin, "rb");
    if (!f) { perror(bin); exit(2); }
    im->n = fread(im->img, 1, sizeof im->img, f); fclose(f);
    im->entrada = etiqueta(lbl, entrada); im->inicio = etiqueta(lbl, inicio);
    im->tick = strcmp(tick, "-") ? etiqueta(lbl, tick) : 0;
}
static unsigned semilla;
static unsigned azar(void) { semilla = semilla * 1103515245u + 12345u; return (semilla >> 16) & 0x7FFF; }
static unsigned long long ciclos_reg[17]; static unsigned long cuenta_reg[17], mal_regs;
static unsigned long long ciclos_flujo; static unsigned long ticks_flujo;
static imagen_t *img; static int con_regs;

static void cierra_llamada(void)
{
    unsigned k;
    for (k = 0; k < 3; ++k) {
        uint8_t c = Mem[0xD404 + 7 * k];
        actual_ll.puerta[k] = c & 1;
        actual_ll.clase[k] = (c & 1) ? ((c & 0x80) ? 2 : (c & 0x70) ? 1 : 0) : 0;
        actual_ll.frec[k] = (c & 1) ? (uint16_t)(Mem[0xD400 + 7 * k] | Mem[0xD401 + 7 * k] << 8) : 0;
    }
    if (nreg == creg) { creg = creg ? 2 * creg : 1 << 20; reg = realloc(reg, creg * sizeof *reg); if (!reg) exit(3); }
    reg[nreg++] = actual_ll;
    memset(&actual_ll, 0, sizeof actual_ll);
}
/* one call of the image's routine: its record and cycles (register r, 16 = the tick routine) */
static void llama(uint16_t dir, uint8_t r, uint8_t v, int indice)
{
    uint8_t sr = (uint8_t)(0x30 | ((azar() & 1) ? 0x04 : 0) | (azar() & 0xC3)), y = (uint8_t)azar();
    unsigned long c;
    Regs.SR = sr; ++n_llamada;
    c = m6502_llama(dir, r, v, y, 1000000);
    if (!c) { fprintf(stderr, "sid_igual: the routine at $%04X does not return\n", dir); exit(3); }
    if (con_regs && indice < 16 && (Regs.AC != r || Regs.XR != v || (Regs.SR & 0x04) != (sr & 0x04))) ++mal_regs;
    ciclos_reg[indice] += c + 6; cuenta_reg[indice]++;
    ciclos_flujo += c + 6;
    cierra_llamada();
}
static void escribe(uint8_t r, uint8_t v) { llama(img->entrada, r, v, r < 16 ? r : 15); }
/* a tick: its routine's call, or (an image without one) the state at that moment, so both images' records match */
static void tick(void) { ++ticks_flujo; if (img->tick) llama(img->tick, 0, 0, 16); else cierra_llamada(); }

/* every stream on image im from memory full of `relleno`: the records into reg[]; per log stream its cycles a tick */
static void corre(imagen_t *im, int relleno, uint8_t ini_a, int nflujos, char **flujos, int informa)
{
    int i;
    img = im; nreg = 0; n_llamada = 0; semilla = 12345; mal_regs = 0; huella = 1469598103934665603ull;
    memset(ciclos_reg, 0, sizeof ciclos_reg); memset(cuenta_reg, 0, sizeof cuenta_reg);
    for (i = 0; i < nflujos; ++i) {
        memset(Mem, relleno, sizeof Mem);
        memcpy(Mem + 0x1000, im->img, im->n);
        memset(Mem + 0xD400, 0, 0x20); memset(puerta_sid, 0, sizeof puerta_sid); memset(&actual_ll, 0, sizeof actual_ll);
        Regs.SP = 0xFF;
        mem_al_escribir = anota;
        ++n_llamada;
        m6502_llama(im->inicio, ini_a, 0, 0, 1000000);
        memset(&actual_ll, 0, sizeof actual_ll);
        ciclos_flujo = 0; ticks_flujo = 0;
        if (!strcmp(flujos[i], "exhaustivo")) {
            static const uint8_t mezclas[] = { 0x38, 0x07, 0x3F, 0x00, 0x2A, 0x15 };
            unsigned m, c, p;
            for (m = 0; m < sizeof mezclas; ++m) {
                escribe(7, mezclas[m]);
                for (c = 0; c < 3; ++c) escribe((uint8_t)(8 + c), (uint8_t)(m * 3 + c));
                for (c = 0; c < 3; ++c) for (p = 0; p < 4096; ++p) {
                    escribe((uint8_t)(2 * c), (uint8_t)p);
                    escribe((uint8_t)(2 * c + 1), (uint8_t)((p >> 8) | (azar() & 0xF0)));
                }
                for (p = 0; p < 256; ++p) escribe(6, (uint8_t)p);
                for (c = 0; c < 3; ++c) for (p = 0; p < 256; ++p) escribe((uint8_t)(8 + c), (uint8_t)p);
            }
        }
        else if (!strcmp(flujos[i], "azar")) {
            unsigned k;
            for (k = 0; k < 400000; ++k) {
                unsigned r = azar() % 20; uint8_t v = (uint8_t)azar();
                if (r >= 16) r = r - 16 + 4;            /* more tone writes */
                if (r == 7 && (azar() & 1)) v &= 0x3F;
                escribe((uint8_t)r, v);
                if (k & 1) tick();
            }
        }
        else {
            char l[128]; unsigned long t, previo = 0; unsigned r, v; int primero = 1; FILE *g = fopen(flujos[i], "r");
            if (!g) { perror(flujos[i]); exit(2); }
            while (fgets(l, sizeof l, g)) if (sscanf(l, "%lu %u %u", &t, &r, &v) == 3) {
                if (primero) { previo = t; primero = 0; }
                while (previo < t) { tick(); ++previo; }
                escribe((uint8_t)r, (uint8_t)v);
            }
            tick();
            fclose(g);
            if (informa)
                printf("    %s: %lu ticks, %.1f cycles a tick (the calls' own, JSR included)\n", flujos[i], ticks_flujo,
                       (double)ciclos_flujo / ticks_flujo);
        }
        mem_al_escribir = NULL;
    }
}
int main(int argc, char **argv)
{
    static imagen_t ref, nuevo;
    llamada_t *r1; size_t n1, k; int i, mal = 0, a = 1, con_a5 = 0, nflujos; uint8_t ini_a;
    unsigned long long c1[17], h; unsigned long q1[17];
    while (a < argc && argv[a][0] == '-' && argv[a][1] == '-') {
        if (!strcmp(argv[a], "--regs")) con_regs = 1;
        else if (!strcmp(argv[a], "--a5")) con_a5 = 1;
        ++a;
    }
    if (argc - a < 10) { fprintf(stderr, "sid_igual [--regs] [--a5] ENTRY INIT INIT_A REF.bin REF.lbl REF_TICK NEW.bin NEW.lbl NEW_TICK STREAM...\n"); return 2; }
    ini_a = (uint8_t)strtoul(argv[a + 2], NULL, 0);
    carga(&ref, argv[a + 3], argv[a + 4], argv[a], argv[a + 1], argv[a + 5]);
    carga(&nuevo, argv[a + 6], argv[a + 7], argv[a], argv[a + 1], argv[a + 8]);
    nflujos = argc - a - 9;
    m6502_init();
    printf("  the reference:\n");
    corre(&ref, 0, ini_a, nflujos, argv + a + 9, 1);
    if (con_regs && mal_regs) { printf("the reference changed A, X or the I flag in %lu calls\n", mal_regs); mal = 1; }
    r1 = reg; n1 = nreg; reg = NULL; nreg = creg = 0;
    memcpy(c1, ciclos_reg, sizeof c1); memcpy(q1, cuenta_reg, sizeof q1);
    printf("  the new one:\n");
    corre(&nuevo, 0, ini_a, nflujos, argv + a + 9, 1);
    h = huella;
    if (con_regs && mal_regs) { printf("the new one changed A, X or the I flag in %lu calls\n", mal_regs); mal = 1; }
    if (nreg != n1) { printf("%zu calls against the reference's %zu\n", nreg, n1); mal = 1; }
    for (k = 0; k < nreg && k < n1; ++k) {
        int v;
        for (v = 0; v < 3; ++v) {
            llamada_t *x = &reg[k], *y = &r1[k];
            if (x->n[v] != y->n[v] || x->cambios[v] != y->cambios[v] || x->puerta[v] != y->puerta[v]
                || (x->puerta[v] && (x->frec[v] != y->frec[v] || x->clase[v] != y->clase[v]))) {
                printf("call %zu, voice %d: gate changes %u (%02X), gate %u, frequency %04X, kind %u against the "
                       "reference's %u (%02X), %u, %04X, %u\n", k, v + 1, x->n[v], x->cambios[v], x->puerta[v], x->frec[v],
                       x->clase[v], y->n[v], y->cambios[v], y->puerta[v], y->frec[v], y->clase[v]);
                mal = 1;
                break;
            }
        }
        if (mal) break;
    }
    {
        unsigned long cambios = 0, sonando = 0;
        for (k = 0; k < n1; ++k) for (i = 0; i < 3; ++i) { cambios += r1[k].n[i]; sonando += r1[k].puerta[i]; }
        printf("%zu calls, %lu gate changes, %lu voice-calls sounding: the gates and the frequencies %s the reference's\n",
               nreg, cambios, sonando, mal ? "NOT" : "the same as");
    }
    for (i = 0; i < 17; ++i)
        if (cuenta_reg[i] || q1[i])
            printf("  %s %2d: %8lu calls, %6.1f cycles each (reference %6.1f)\n", i < 16 ? "register" : "tick    ", i < 16 ? i : 0,
                   cuenta_reg[i], cuenta_reg[i] ? (double)ciclos_reg[i] / cuenta_reg[i] : 0.0, q1[i] ? (double)c1[i] / q1[i] : 0.0);
    if (con_a5) {
        free(reg); reg = NULL; nreg = creg = 0;
        corre(&nuevo, 0xA5, ini_a, nflujos, argv + a + 9, 0);
        if (huella != h) { printf("from memory full of $A5: other SID writes\n"); mal = 1; }
        else printf("from memory full of $A5 (BSS not loaded): the same SID writes\n");
    }
    return mal;
}
