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

/* The T-states musica.c counts for each tick against the CPC's interrupts in the simulator: reads
 * the ticks' costs (T at 6146h minus T at 613Fh, cpc_carga.py --marca) and the stops/entries, runs
 * musica.c from the stage's image and prints the first differences.
 *   ciclos_musica RAM.bin COSTES.txt   (COSTES: one line per tick: 'cost' or 'p'/'r' events) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "musica.h"
static unsigned char ram[65536];
void musica_registro(unsigned char reg, unsigned char valor) { (void)reg; (void)valor; }
int main(int argc, char **argv)
{
    FILE *f = fopen(argv[1], "rb");
    char linea[64];
    unsigned long n = 0, malos = 0;
    if (!f || fread(ram, 1, 65536, f) != 65536) return 2;
    fclose(f);
    musica_inicia(ram + 0x8000, 1024, ram + 0x6148);
    f = fopen(argv[2], "r");
    while (fgets(linea, sizeof linea, f)) {
        if (linea[0] == 'p') { musica_para(); continue; }
        if (linea[0] == 'r') { musica_reinicia(); continue; }
        {
            unsigned long cpc = strtoul(linea, 0, 10);
            musica_ciclos = 0;
            musica_tick();
            /* 613Fh -> 6146h: DI, PUSH AF, CALL 61DBh (32), 61DBh..RETI, POP AF, EI (14) */
            if (musica_ciclos + 46 != cpc) {
                if (++malos <= 15) printf("tick %lu: C %lu, CPC %lu\n", n, musica_ciclos + 46, cpc);
            }
            ++n;
        }
    }
    printf("%lu ticks, %lu different\n", n, malos);
    return malos != 0;
}
