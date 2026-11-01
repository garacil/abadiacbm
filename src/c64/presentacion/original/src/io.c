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

/*

cc65 Abadia del crimen

garacilb@gmail.com 27/09/2016 (Spain)

*/

#include <cbm.h>
#include <string.h>
#include <6502.h>
#include <peekpoke.h>
#include <conio.h>
#include "io.h"

unsigned char __fastcall__ bytemirror(unsigned char c)
{
	static unsigned char lookup[16] = {
	0x0, 0x8, 0x4, 0xc, 0x2, 0xa, 0x6, 0xe,
	0x1, 0x9, 0x5, 0xd, 0x3, 0xb, 0x7, 0xf, };

	return (lookup[c & 0x0f] << 4) | lookup[ c >> 4 ];
}

void __fastcall__ screenon(void)
{
#if defined(__CBM510__)
	pokebsys(0xd811, peekbsys(0xd811) | 0x10); /* screen on */
#else
	VIC.ctrl1 = VIC.ctrl1 | 0x10;
#endif
}

void __fastcall__ screenoff(void)
{
#if defined(__CBM510__)
	pokebsys(0xd811, peekbsys(0xd811) & 0xef); /* screen off */
#else
	VIC.ctrl1 = VIC.ctrl1 & 0xef;
#endif
}

void __fastcall__ screenbitmap(void)
{
#if defined(__CBM510__)
	pokebsys(0xd811, 0x3b); /* enable bitmapmode */
	pokebsys(0xd816, 0xc8); /* d8 enable multicolour, c8 not */
	pokebsys(0xd818, 0x83); /* bm 0xc000, scr 0xe000, c 0xd400 0x0f */
	pokebsys(0xde06, 0x03); /* Put VIC-II in bank 0 */
#else
	VIC.ctrl1 = VIC.ctrl1 | 0x20;
	VIC.ctrl2 = VIC.ctrl2 & 0xef;
	VIC.addr  = 0x83;
	CIA2.pra  = CIA2.pra & 0xfc;
#endif
}

void __fastcall__ screenbitmapmulticolor(void)
{
#if defined(__CBM510__)
	pokebsys(0xd811, 0x3b); /* enable bitmapmode */
	pokebsys(0xd816, 0xd8); /* d8 enable multicolour, c8 not */
	pokebsys(0xd818, 0x83); /* bm 0xc000, scr 0xe000, c 0xd400 0x0f */
	pokebsys(0xde06, 0x03); /* Put VIC-II in bank 0 */
#else
	VIC.ctrl1 = VIC.ctrl1 | 0x20;
	VIC.ctrl2 = VIC.ctrl2 | 0x10;
	VIC.addr  = 0x83;
	CIA2.pra  = CIA2.pra & 0xfc;
#endif
}

void screenclean(unsigned char b, unsigned char s, unsigned char c)
{
#if defined(__CBM510__)
	unsigned int d;
#endif

#if defined(__C64__)
	SEI();
	POKE(0x0001, 0x34);	
#endif
	memset((unsigned char*)VIC_MEM, b, 8000);
	memset((unsigned char*)VIC_SCR, s, 1000);
#if defined(__C64__)
	POKE(0x0001, 0x36);
	CLI();
#endif
#if defined(__CBM510__)
	for (d = 0; d < 1000; d++) {
		pokebsys(VIC_COL + d, c);
	}
#else
	memset((unsigned char*)VIC_COL, c, 1000);
#endif
	
}

unsigned int xytoscreen(unsigned int x, unsigned int y)
{
	return VIC_MEM + (x * 8) + (40 * 8 * y);
}

