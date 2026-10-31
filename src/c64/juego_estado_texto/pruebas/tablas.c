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

/* build: gcc -O1 -I ../../../juego/m6502 -o tablas tablas.c ../../../juego/m6502/m6502.c ../../../juego/m6502/6502.c; run: ./tablas .. */
/* vid_init_stub with the C64 tables zeroed first: must rebuild exactly the image's tables */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "m6502.h"
static char nombres[512][64]; static unsigned dirs[512]; static int n;
unsigned dir(const char *s) { int i; for (i = 0; i < n; ++i) if (!strcmp(nombres[i], s)) return dirs[i]; exit(1); }
int main(int argc, char **argv) {
    static uint8_t img[65536]; char p[512], l[256]; FILE *f; unsigned long c;
    unsigned t[] = { 0xBB00, 0xBC00, 0xBD00, 0xBE00, 0xBF00, 0xC400, 0xC500, 0xC600, 0xC700 }; int k, bad = 0;
    snprintf(p, sizeof p, "%s/juego.bin", argv[1]); f = fopen(p, "rb"); fread(img, 1, 65536, f); fclose(f);
    snprintf(p, sizeof p, "%s/juego.lbl", argv[1]); f = fopen(p, "r");
    while (fgets(l, sizeof l, f)) if (sscanf(l, "al %x .%63s", &dirs[n], nombres[n]) == 2) ++n;
    fclose(f);
    memcpy(Mem, img, sizeof Mem);
    for (k = 0; k < 9; ++k) memset(Mem + t[k], 0, 256);
    memset(Mem + 0xEA06, 0, 16);
    m6502_init(); Regs.SP = 0xFF;
    c = m6502_llama(dir("vid_init_stub"), 0, 0, 0, 10000000);
    for (k = 0; k < 9; ++k) if (memcmp(Mem + t[k], img + t[k], 256)) { printf("table %04X differs\n", t[k]); bad = 1; }
    if (memcmp(Mem + 0xEA06, img + 0xEA06, 16)) { printf("fuente_nibble differs\n"); bad = 1; }
    if (memcmp(Mem, img, 65536)) { int d = 0; for (k = 0; k < 65536; ++k) if (Mem[k] != img[k] && !(k < 0x200) && ++d < 5) printf("other byte %04X\n", k); }
    printf("vid_init_stub: %lu cycles, %s\n", c, bad ? "WRONG" : "the 10 tables equal the image's");
    return bad;
}
