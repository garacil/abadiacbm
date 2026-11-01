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

garacilb@gmain.com 27/09/2016 (Spain)

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

unsigned char __fastcall__ bytemirror(unsigned char c);
void __fastcall__ screenoff(void);
void __fastcall__ screenon(void);
void __fastcall__ screenbitmap(void);
void __fastcall__ screenbitmapmulticolor(void);
void screenclean(unsigned char b, unsigned char s, unsigned char c);
unsigned int xytoscreen(unsigned int x, unsigned int y);