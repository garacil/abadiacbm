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

/* Benchmark of the parchment drawing on the C64 (built with -DBANCO): times, with CIA 2 timer B,
 * esquina() with 3 and 48 bands and 1000 calls of pon_byte_rapido, then shows the cycle counts in
 * text mode for a screenshot. */
#include <c64.h>
#include <conio.h>
#include <stdio.h>
extern unsigned char pb_x, pb_y, pb_v, es_x, es_y, es_b;
void pon_byte_rapido(void);
void esquina_asm(void);
extern const unsigned char perg_bitmap[], perg_celdas[];

static unsigned int lee_b(void)
{
    unsigned char lo, hi;
    do { hi = CIA2.tb_hi; lo = CIA2.tb_lo; } while (hi != CIA2.tb_hi);
    return (unsigned int)hi << 8 | lo;
}

static unsigned int mide_esquina(unsigned char x, unsigned char y, unsigned char b)
{
    unsigned int t0, t1;
    CIA2.tb_lo = 0xFF; CIA2.tb_hi = 0xFF; CIA2.crb = 0x11;
    t0 = lee_b();
    es_x = x; es_y = y; es_b = b;
    esquina_asm();
    t1 = lee_b();
    return t0 - t1;
}

void banco(void)
{
    unsigned int a, b, c, t0, t1, i;
    a = mide_esquina(0xD3, 0, 3);
    b = mide_esquina(0x20, 4, 47);
    CIA2.tb_lo = 0xFF; CIA2.tb_hi = 0xFF; CIA2.crb = 0x11;
    t0 = lee_b();
    for (i = 0; i < 200; ++i) { pb_x = 20; pb_y = 100; pb_v = 0; pon_byte_rapido(); }
    t1 = lee_b();
    c = t0 - t1;
    VIC.ctrl1 = 0x1B; VIC.ctrl2 = 0x08; CIA2.pra = (CIA2.pra & 0xFC) | 0x03; VIC.addr = 0x15;
    VIC.bordercolor = 0; VIC.bgcolor0 = 0;
    *(unsigned char *)0x01 = 0x37;
    clrscr();
    cprintf("esquina 3 bandas: %u ciclos\r\n", a);
    cprintf("esquina 47 bandas: %u ciclos\r\n", b);
    cprintf("200 pon_byte (00): %u ciclos\r\n", c);
    for (;;) ;
}
