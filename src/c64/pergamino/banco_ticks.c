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

/* Benchmark: how many music interrupts in 2 seconds of CIA 2 time (2 x 985248 cycles)? */
#include <c64.h>
#include <conio.h>
#include "musica.h"
extern const unsigned char perg_musica[], perg_reproductor[];
extern unsigned int musica_ticks;
void musica_irq_on(unsigned char voces); void musica_irq_off(void);
void __fastcall__ espera(unsigned int n);
int main(void)
{
    unsigned int t;
    unsigned char i;
    musica_inicia(perg_musica, 1024, perg_reproductor);
    musica_irq_on(0);                           /* the introduction's voicing */
    musica_ticks = 0;
    for (i = 0; i < 4; ++i) espera(54403);      /* 4 x 54403 x 9.0625 cycles = 1972083 = 2.0016 s */
    t = musica_ticks;
    musica_irq_off();
    clrscr();
    cprintf("ticks en 2 s: %u (300 Hz: 600)\r\n", t);
    for (;;) ;
    return 0;
}
