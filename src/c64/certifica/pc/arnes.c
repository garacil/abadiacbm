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

/* arnes.c - the PC rebuild as the reference of abadia128ks (milestone H10, the full game; the PC
 * version is the reference).  Two hooks that construye.sh puts into a copy of the rebuild's game_input_and_mirror
 * (1000:2DD8, the input step of every frame of the main loop), nothing else of the game touched:
 *   arnes_entrada  at its entry: frame f += 1; the data space (1800:0000-FFFF) appended to $ARNES_VOLCADO;
 *                  after $ARNES_FOTOGRAMAS frames the run ends
 *   arnes_teclas   right after the key routine: the CPC keys of frame f held ($ARNES_TECLAS: lines "f k k ...",
 *                  CPC key numbers): each one's bit cleared in sys_keys_down (BCC8h, 0 = down) and, when it was
 *                  not held in frame f - 1, in sys_keys_pending (BCD2h): what the scripts of c64/juego_final/vice write
 *                  into D64_SYS_KEYS_DOWN / _PENDING after sys_read_keyboard on the 6502. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "abadia.h"

#define ARNES_MAX_TECLAS 8
static FILE *volcado;
static long frame, n_max;
static long *t_frame; static unsigned char (*t_teclas)[ARNES_MAX_TECLAS]; static int *t_n; static long nt;
static int iniciado;

static void inicia(void)
{
    iniciado = 1;
    const char *v = getenv("ARNES_VOLCADO"), *t = getenv("ARNES_TECLAS"), *n = getenv("ARNES_FOTOGRAMAS");
    if (v) volcado = fopen(v, "wb");
    if (n) n_max = strtol(n, NULL, 10);
    if (t) {
        FILE *f = fopen(t, "r");
        char l[256];
        long cap = 0;
        while (f && fgets(l, sizeof l, f)) {
            if (l[0] == '#') continue;
            char *p = l, *e;
            long fr = strtol(p, &e, 10);
            if (e == p) continue;
            if (nt == cap) {
                cap = cap ? 2 * cap : 1024;
                t_frame = realloc(t_frame, cap * sizeof *t_frame);
                t_teclas = realloc(t_teclas, cap * sizeof *t_teclas);
                t_n = realloc(t_n, cap * sizeof *t_n);
            }
            t_frame[nt] = fr; t_n[nt] = 0;
            for (p = e;;) {
                long k = strtol(p, &e, 10);
                if (e == p || t_n[nt] == ARNES_MAX_TECLAS) break;
                t_teclas[nt][t_n[nt]++] = (unsigned char)k;
                p = e;
            }
            nt++;
        }
        if (f) fclose(f);
    }
}

static int busca(long fr)
{
    for (long i = 0; i < nt; i++) if (t_frame[i] == fr) return (int)i;
    return -1;
}

void arnes_entrada(void)
{
    if (!iniciado) inicia();
    frame++;
    if (n_max && frame > n_max) { if (volcado) fclose(volcado); exit(0); }
    if (volcado) fwrite(ds, 1, 0x10000, volcado);
}

void arnes_teclas(void)
{
    int i = busca(frame), j = busca(frame - 1);
    if (i < 0) return;
    for (int k = 0; k < t_n[i]; k++) {
        unsigned char c = t_teclas[i][k];
        int antes = 0;
        if (j >= 0) for (int q = 0; q < t_n[j]; q++) if (t_teclas[j][q] == c) antes = 1;
        wb((uint16_t)(SYS_KEYS_DOWN + (c >> 3)), (uint8_t)(rb((uint16_t)(SYS_KEYS_DOWN + (c >> 3))) & ~(1u << (c & 7))));
        if (!antes)
            wb((uint16_t)(SYS_KEYS_PENDING + (c >> 3)), (uint8_t)(rb((uint16_t)(SYS_KEYS_PENDING + (c >> 3))) & ~(1u << (c & 7))));
    }
}
