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

/* Host test of src/c64/pergamino/musica.c: runs N ticks (and, after the ticks given as
 * pTICK / rTICK arguments, musica_para / musica_reinicia, as the CPC between two entries) and prints every register write as
 * "tick register value", to compare with the CPC's writes (prueba_musica.sh). */
#include <stdio.h>
#include <stdlib.h>
#include "musica.h"
extern const unsigned char perg_musica[1024], perg_reproductor[];
static unsigned long tick;
void musica_registro(unsigned char reg, unsigned char valor) { printf("%lu %u %u\n", tick, reg, valor); }
int main(int argc, char **argv)
{
    unsigned long n = argc > 1 ? strtoul(argv[1], 0, 10) : 20000;
    int e = 2;
    musica_inicia(perg_musica, 1024, perg_reproductor);
    for (tick = 0; tick < n; ++tick) {
        musica_tick();
        while (e < argc && strtoul(argv[e] + 1, 0, 10) == tick) {
            if (argv[e][0] == 'p') musica_para(); else musica_reinicia();
            ++e;
        }
    }
    return 0;
}
