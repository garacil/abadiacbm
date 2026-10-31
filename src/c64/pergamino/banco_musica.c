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

/* Benchmark: cycles of musica_tick on the C64 (average over 3000 ticks, and the worst tick). */
#include <c64.h>
#include <conio.h>
#include "musica.h"
extern const unsigned char perg_musica[], perg_reproductor[];
void musica_registro(unsigned char reg, unsigned char valor) { (void)reg; (void)valor; }
static unsigned int lee_b(void)
{
    unsigned char lo, hi;
    do { hi = CIA2.tb_hi; lo = CIA2.tb_lo; } while (hi != CIA2.tb_hi);
    return (unsigned int)hi << 8 | lo;
}
int main(void)
{
    unsigned int i, t0, t1, d, peor = 0;
    unsigned long total = 0;
    musica_inicia(perg_musica, 1024, perg_reproductor);
    __asm__("sei");
    for (i = 0; i < 3000; ++i) {
        CIA2.tb_lo = 0xFF; CIA2.tb_hi = 0xFF; CIA2.crb = 0x11;
        t0 = lee_b();
        musica_tick();
        t1 = lee_b();
        d = t0 - t1;
        total += d;
        if (d > peor) peor = d;
    }
    __asm__("cli");
    clrscr();
    cprintf("musica_tick: media %lu ciclos, peor %u\r\n", total / 3000, peor);
    for (;;) ;
    return 0;
}
