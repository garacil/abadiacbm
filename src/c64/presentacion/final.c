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

/* "final": the ending parchment, the program the game loads (plat_final, c64/plataforma/disco.s) when it is won at
 * 100 %, as the CPC tape's ABADIA64.BN1: the parchment (manuscrito.c's manusrun) with the CPC's ending text
 * (text2.bin, the tape's bytes plus the credits and dedication: datos.py) and the ending's music, written
 * over and over as the CPC does (its end
 * routine calls the parchment for ever, 3376h): a key ends the text at once (manusrun's kbhit) or waits at its end
 * (cgetc, as the abadia.c), the music stops (6038h) and the parchment is drawn again with the music from the
 * start of its channel A (6019h-6022h).  In the style of abadia.c's main and manuscrito.c's manusintro. */
#include <conio.h>
#include <stdio.h>
#include <stdlib.h>

#include "manuscrito.h"
#include "io.h"
#include "presentacion.h"

#define TEXT2 0xa26          // original ending, credits and dedication (datos.py)

void manusrun(unsigned char *text);  // manuscrito.c

int main(void)
{
	FILE* fp;
	unsigned int k;
	unsigned char *mfinal;

	bgcolor(0);
	bordercolor(0);
	textcolor(1);
	clrscr();
	puts("Loading");

#if defined(CINTA)
	mfinal = CINTA_INGLES ? cinta_text2_en : cinta_text2_es;   /* the tape: in the program */
#else
	mfinal = malloc(sizeof(char) * TEXT2);
	fp = fopen("text2.bin", "rb");
	fread((unsigned char*) mfinal, 1, TEXT2, fp);
	fclose(fp);
#endif

#if defined(CINTA)
	/* the tape (SPACE or any other key does nothing at all): the
	 * parchment once, its music going on, and nothing more */
	manusrun(mfinal);
	while(1)
		;
#endif
	while(1) {
		manusrun(mfinal);
		while(1) {
			k = (int)cgetc();
			if (k)
				break;
		}
		musicstop();
	}
}
