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

/* build: gcc -O1 -I ../../../juego/m6502 -o unidad unidad.c ../../../juego/m6502/m6502.c ../../../juego/m6502/6502.c; run: ./unidad .. */
/* unit tests of the estado_texto routines the 8 sessions never call (2FAD, 3087, 39E5): the 6502 routine on
 * juego.bin with random state, against the C reference's rule written here on the C64 addresses */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "m6502.h"
static char nombres[512][64]; static unsigned dirs[512]; static int n;
static uint8_t img[65536];
unsigned dir(const char *s) { int i; for (i = 0; i < n; ++i) if (!strcmp(nombres[i], s)) return dirs[i]; fprintf(stderr, "no %s\n", s); exit(1); }
static const char *grupo = "..";   /* the group's directory (argv[1]): juego.bin, juego.lbl, mapa64.inc */
static unsigned sim(const char *s) { char l[256], m[512]; FILE *f; unsigned v; snprintf(m, sizeof m, "%s/mapa64.inc", grupo); f = fopen(m, "r");
    char k[80]; while (fgets(l, sizeof l, f)) if (sscanf(l, "%79s = $%x", k, &v) == 2 && !strcmp(k, s)) { fclose(f); return v; } fprintf(stderr, "no %s\n", s); exit(1); }
static uint16_t rw(uint16_t a) { return (uint16_t)(Mem[a] | Mem[(uint16_t)(a + 1)] << 8); }
int main(int argc, char **argv) {
    char p[512], l[256]; FILE *f; int t, k, bad = 0;
    if (argc > 1) grupo = argv[1];
    unsigned OBJ = sim("D64_OBJ_OBJECTS"), CO = sim("D64_OBJ_CHAR_OBJECTS"), DP = sim("D64_OBJ_DOOR_PERMISSIONS"),
             PP = sim("D64_CHR_POS_PTRS"), LAMP = sim("D64_GAME_ADSO_LAMP"), DOORS = sim("D64_OBJ_DOORS"), GB = sim("D64_GAME_BOOK_POISON_COUNT");
    snprintf(p, sizeof p, "%s/juego.bin", argv[1]); f = fopen(p, "rb"); fread(img, 1, 65536, f); fclose(f);
    snprintf(p, sizeof p, "%s/juego.lbl", argv[1]); f = fopen(p, "r");
    while (fgets(l, sizeof l, f)) if (sscanf(l, "al %x .%63s", &dirs[n], nombres[n]) == 2) ++n;
    fclose(f);
    srand(12345);
    m6502_init();
    /* 2FAD */
    memcpy(Mem, img, sizeof Mem); Regs.SP = 0xFF;
    m6502_llama(dir("obj_open_left_wing_doors"), 0, 0, 0, 100000);
    if (rw(DOORS + 0x19) != 0xE002 || rw(DOORS + 0x1E) != 0xC002 || rw(0x06) != 0xC002) { puts("2FAD wrong"); bad = 1; }
    /* 3087, 1000 random states */
    for (t = 0; t < 1000; ++t) {
        uint8_t e[65536]; uint8_t mask = 0x80; unsigned ix = OBJ;
        memcpy(Mem, img, sizeof Mem);
        for (k = 0; k < 46; ++k) Mem[OBJ + k] = (uint8_t)rand();
        for (k = 0; k < 42; ++k) Mem[CO + k] = (uint8_t)rand();
        for (k = 0; k < 12; ++k) Mem[PP + k] = (uint8_t)rand();
        memcpy(e, Mem, sizeof e);
        if (e[OBJ + 0x28] & 0x80) { e[OBJ + 0x2A] = (uint8_t)LAMP; e[OBJ + 0x2B] = (uint8_t)(LAMP >> 8); }
        for (k = 0; k < 8; ++k) {
            if (e[ix] & 0x80) {
                unsigned hl = CO + 3; int c = 5;
                do { if (e[hl] & mask) break; hl += 7; } while (--c);
                e[ix + 2] = (uint8_t)(hl - 3); e[ix + 3] = (uint8_t)((hl - 3) >> 8);
            }
            ix += 5; mask >>= 1;
        }
        for (k = 0; k < 6; ++k) {
            e[DP + 3 * k + 1] = e[PP + 2 * k]; e[CO + 7 * k + 1] = e[PP + 2 * k];
            e[DP + 3 * k + 2] = e[PP + 2 * k + 1]; e[CO + 7 * k + 2] = e[PP + 2 * k + 1];
        }
        Regs.SP = 0xFF;
        m6502_llama(dir("obj_fix_owner_pointers"), 0, 0, 0, 100000);
        for (k = 0x200; k < 0x10000; ++k) if (Mem[k] != e[k] && !(k >= 0x800 && k < 0x7151)) { printf("3087 test %d: %04X %02X/%02X\n", t, k, Mem[k], e[k]); bad = 1; break; }
        if (bad) break;
    }
    /* 39E5, 1000 random places */
    for (t = 0; t < 1000 && !bad; ++t) {
        unsigned pl = GB + 3 + (unsigned)(rand() % 100); uint8_t a1, a2, a3, za, zf;
        memcpy(Mem, img, sizeof Mem);
        Mem[pl - 1] = (uint8_t)(rand() % 4); Mem[pl - 3] = (uint8_t)(rand() % 4); Mem[pl - 2] = (uint8_t)rand();
        a1 = Mem[pl - 1]; a3 = Mem[pl - 3]; a2 = Mem[pl - 2];
        Mem[0x08] = (uint8_t)pl; Mem[0x09] = (uint8_t)(pl >> 8);
        Regs.SP = 0xFF;
        m6502_llama(dir("ai_next_state_on_arrival"), 0, 0, 0, 100000);
        za = a1 == a3 ? 0 : a1; zf = a1 == a3;
        if (Regs.AC != za || ((Regs.SR >> 1) & 1) != zf || Mem[pl - 2] != (uint8_t)(a2 + (a1 == a3))) { printf("39E5 test %d wrong\n", t); bad = 1; }
    }
    printf("unit tests 2FAD, 3087 (1000), 39E5 (1000): %s\n", bad ? "FAILED" : "all equal");
    return bad;
}
