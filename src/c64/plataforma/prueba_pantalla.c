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

/* Test of wscr on the C64: the CPC screen of room 16h written byte by byte through wscr. */
#include <c64.h>
#include <string.h>
void __fastcall__ wscr(unsigned int addr, unsigned char v);
extern const unsigned char cpc_pantalla[];
int main(void)
{
    unsigned int l, o;
    *(unsigned char *)0x01 = 0x36;
    VIC.bordercolor = 0; VIC.bgcolor0 = 0;                   /* CPC pen 3: black */
    memset((void *)0xA000, 0, 8000);
    memset((void *)0x8000, (3 << 4) | 8, 1000);              /* pens 0, 1: cyan, orange */
    memset(COLOR_RAM, 7, 1000);                              /* pen 2: yellow */
    CIA2.pra = (CIA2.pra & 0xFC) | 0x01;
    VIC.addr = 0x08; VIC.ctrl2 = 0x18; VIC.ctrl1 = 0x3B;
    for (l = 0; l < 8; ++l)
        for (o = 0; o < 1600; ++o)
            wscr(0xC000 + l * 0x800 + o, cpc_pantalla[l * 1600 + o]);
    for (;;) ;
    return 0;
}
