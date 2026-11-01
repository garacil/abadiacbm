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

#include <conio.h>
#include <cbm.h>
#include <peekpoke.h>
#include <stdio.h>
#include <stdlib.h>
#include <6502.h>
#include <string.h>

#include "manuscrito.h"
#include "io.h"

static unsigned int *pergascr;
static unsigned char *pergagraf;
static unsigned char *perga;
static unsigned char *perlet;
static unsigned char **perletaddr;
static unsigned char *minicio;

static unsigned int *ytoscreen;
static unsigned char xtobit[] = {127, 191, 223, 239, 247, 251, 253, 254};

void manusmkletptr(void)
{
	unsigned char c;
	unsigned char pc;
	unsigned char *old;
	unsigned char *new;

	c = 0;
	pc = 0;
	old = *perletaddr;
	new = perlet;
	perletaddr[pc] = perlet; // New address to first letter
	pc++;
	while ((unsigned int) perletaddr[pc] != 0xffff) {
		if ((unsigned int) perletaddr[pc] != 0x0000)
			perletaddr[pc] = new + (perletaddr[pc] - old);
		pc++;
	}
}

void manusmkytoscreen(void)
{
	unsigned char y, c;
	unsigned int addr;
	unsigned char counter;

	ytoscreen = malloc(sizeof(int) * 200);
	counter = 0;
	for (y = 0; y < 26; y++) {
		addr = VIC_MEM + (320 * y);
		for (c = 0; c < 8; c++) {
			ytoscreen[counter] = addr + c;
			counter++;
		}
	}
}

void chgscrcol(unsigned char x, unsigned char y, unsigned char lx, unsigned char ly, unsigned char c, unsigned char f, unsigned char b)
{
	unsigned char xx;

	while (y < ly) {
		xx = x;
		while (xx < lx) {
#if defined(__C64__)
			SEI();
			POKE(0x0001, 0x34);	
#endif
			POKE(VIC_SCR + xx + (y * 40), c);
			if (f != 0)
				memset((unsigned char*) VIC_MEM + (xx * 8) + (y * 320), b, 8);
#if defined(__C64__)
			POKE(0x0001, 0x36);
			CLI();
#endif
			xx++;
		}
		y++;
	}
}

void manusini(void) 
{
	unsigned int c, l;
	unsigned char d;
	FILE* fp;

	screenbitmap();
	screenoff();
	screenclean(0x00, 0xa9, 0x00);
	chgscrcol(9, 1, 31, 24, 0xa9, 1, 255);
	bgcolor(9);
	bordercolor(9);

	pergascr = malloc(sizeof(char) * 0xba);
	pergagraf = malloc(sizeof(char) * 0x5e);
	perga = malloc(sizeof(char) * 0x19e);
	perletaddr = malloc(sizeof(char) * 0xa0);
	perlet = malloc(sizeof(char) * 0x9d1);
	
	fp = fopen("pp.bin", "rb");
	fread((unsigned char*) pergascr, 1, 0xba, fp);
	fread((unsigned char*) pergagraf, 1, 0x5e, fp);
	fread((unsigned char*) perga, 1, 0x19e, fp);
	fread((unsigned char*) perletaddr, 1, 0xa0, fp);
	fread((unsigned char*) perlet, 1, 0x9d1, fp);

	fclose(fp);

	manusmkletptr();
	manusmkytoscreen();

	c = 0;
#if defined(__C64__)
	SEI();
	POKE(0x0001, 0x34);	
#endif
	while (pergagraf[c] != 0xff){
			for (l = 0; l < 8; l++) {
				d = perga[8 * (pergagraf[c] & 127) + l];
				if (pergagraf[c] & 128)
					POKE(pergascr[c] + l, bytemirror(d));
				else
					POKE(pergascr[c] + l, d);
			}
			POKE(VIC_SCR + ((pergascr[c] - VIC_MEM) / 8), 0xa9);
		c++;
	}
#if defined(__C64__)
	POKE(0x0001, 0x36);
	CLI();
#endif
	screenon();
}

void nextpage(void)
{
	unsigned char x;

	x = 31;
	while (x > 9) {
		chgscrcol(x - 1, 0, x, 24, 0x00, 0, 0);
		if (x < 31)
			chgscrcol(x, 0, x + 1, 24, 0xa9, 0, 0);
		if (x < 31)
			chgscrcol(x, 2, x + 1, 22, 0xa9, 1, 255);
		x--;
	}
	chgscrcol(x, 0, x + 1, 24, 0xa9, 0, 0);
	chgscrcol(x, 2, x + 1, 22, 0xa9, 1, 255);
}

void manusrun(unsigned char *text)
{
	unsigned int posX;
	unsigned int posY;
	unsigned int newPosX, newPosY;
	char color;
	unsigned char *charOffset;
	unsigned int pixeladdr;
	unsigned char bit;
	unsigned char capital;

	if (!text)
		return;
	manusini();
	posX = 76;
	posY = 16;
	while (1) {
		switch(*text) {

			case 0x1a: // The end
				break;

			case 0x0d: // New line
				posX = 76;
				posY += 16;
				if (posY > 164){
					posX = 76;
					posY = 16;
					nextpage();
				}
				break;

			case 0x20: // space
				posX += 10;
				break;

			case 0x0a: // New page
				posX = 76;
				posY = 16;
				nextpage();
				break;

			default:
				color = ((*text & 0x60) == 0x40) ? 0xa2 : 0xa0; // Select colour to write letter
				if (color != 0xa0)
					capital = 2;
				else
					capital = 0;

				charOffset = (unsigned char*) perletaddr[*text - 0x2c]; // (unsigned char) &text[0] - 0x20;
				
				while ((*charOffset & 0xf0) != 0xf0) {
					newPosX = (posX - capital + (*charOffset & 0x0f));
					newPosY = posY + ((*charOffset >> 4) & 0x0f);
					POKE(VIC_SCR + (newPosX >> 3) + ((newPosY >> 3) * 40), color );
					bit = xtobit[newPosX & 0x07];
					newPosX = (newPosX >> 3) * 8;
					pixeladdr = ytoscreen[newPosY] + newPosX;
#if defined(__C64__)
					SEI();
					POKE(0x0001, 0x34);	
#endif
					POKE(pixeladdr, bit & PEEK(pixeladdr));
#if defined(__C64__)
					POKE(0x0001, 0x36);
					CLI();
#endif
					charOffset++;
					for (newPosX=0;newPosX<0x160;newPosX++) {}
				}
				posX += (*charOffset & 0x0f);
				break;
		}
		if (*text != 0x1a)
			text++;
		else
			break;
	}
	free(pergascr);
	free(pergagraf);
	free(perga);
	free(perletaddr);
	free(perlet);
}

void manusintro(void)
{
	FILE* fp;

	minicio = malloc(sizeof(char) * 0x57b);

	fp = fopen("text1.bin", "rb");
	fread((unsigned char*) minicio, 1, 0x57b, fp);
	fclose(fp);

	manusrun(minicio);

	free(minicio);
}
