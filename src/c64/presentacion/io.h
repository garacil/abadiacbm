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

#if defined(__CBM510__)
#define VIC_MEM 0xc000
#define VIC_COL 0xd400
#define VIC_SCR 0xe000
#else
#define VIC_MEM 0xC000
#define VIC_COL 0xd800
#define VIC_SCR 0xe000
#endif

#if defined(__C128__)
/* The C128 (abadia128ks, c64/disco128): the bitmap at $C000-$DF3F lies under the screen editor's ROM and the I/O: block
 * 0's RAM alone ($FF00 = $3F) while it is read or written there, interrupts off; then cc65's configuration again ($0E:
 * RAM up to $BFFF, the KERNAL and the I/O).  ("Mapping the Commodore 128": the MMU's configuration register.) */
#include <6502.h>
#include <peekpoke.h>
#define RAM_VIDEO()     do { SEI(); POKE(0xFF00, 0x3F); } while (0)
#define FIN_RAM_VIDEO() do { POKE(0xFF00, 0x0E); CLI(); } while (0)
#endif

unsigned char __fastcall__ bytemirror(unsigned char c);
void __fastcall__ screenoff(void);
void __fastcall__ screenon(void);
void __fastcall__ screenbitmap(void);
void __fastcall__ screenbitmapmulticolor(void);
void screenclean(unsigned char b, unsigned char s, unsigned char c);
unsigned int xytoscreen(unsigned int x, unsigned int y);