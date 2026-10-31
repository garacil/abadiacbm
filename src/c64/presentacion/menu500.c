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

/* The P500's start menu (abadia128ks for the CBM-II 510, c64/discop500/NOTAS.md): the Commodore 128's
 * (c64/cinta/menu.s -D C128) written with cc65's conio: black, white letters, everything centred; 1 the language
 * (Spanish by default), 2 the footsteps, 3 the text's sound, 4 the Ave Maria at completas; SPACE or RETURN goes on
 * (the footer then says it is loading).  The options' bits are the game's (c64/discop500/disco500.inc, plat_opciones):
 * kept in opciones500 for the presentation (the language) and its loader (carga500.s: the last stage, the game); the
 * drive the disk was loaded from (the KERNAL's FA, $9F of bank 15's zero page; 8 if lower) in unidad500. */
#include <conio.h>
#include <string.h>
#include <cbm.h>
#include "presentacion.h"

unsigned char opciones500, unidad500;

#define F1   10                         /* the rows of the options, the footer */
#define F2   12
#define F3   14
#define F4   16
#define FPIE 19
#define ETIQ 9                          /* the labels' column (the block: 4-35) */

static void centro(unsigned char fila, const char *t)
{
    cputsxy((40 - strlen(t)) / 2, fila, t);
}

static void valor(unsigned char fila, const char *t)  /* right-aligned to column 35 */
{
    cclearxy(26, fila, 10);
    cputsxy(36 - strlen(t), fila, t);
}

static void pinta(void)
{
    static const char *const es[] = {"LA ABADIA DEL CRIMEN", "OPCIONES", "IDIOMA", "PASOS", "SONIDO DEL TEXTO", "AVE MARIA",
                                     "2026  version commodore por", "PULSA ESPACIO PARA CARGAR", "ESPANOL", "SI", "NO"};
    static const char *const en[] = {"THE ABBEY OF CRIME", "OPTIONS", "LANGUAGE", "FOOTSTEPS", "TEXT SOUND", "AVE MARIA",
                                     "2026  commodore version by", "PRESS SPACE TO LOAD", "ENGLISH", "ON", "OFF"};
    const char *const *x = (opciones500 & OPC500_INGLES) ? en : es;
    unsigned char k;
    clrscr();
    textcolor(1);
    centro(4, x[0]);
    chlinexy((40 - strlen(x[0])) / 2, 5, strlen(x[0]));
    centro(8, x[1]);
    for (k = 0; k < 4; k++) {
        revers(1);
        cputsxy(4, F1 + 2 * k, " ");
        cputc('1' + k);
        cputc(' ');
        revers(0);
        cputsxy(ETIQ, F1 + 2 * k, x[2 + k]);
    }
    valor(F1, x[8]);
    valor(F2, (opciones500 & OPC500_SIN_PASOS) ? x[10] : x[9]);
    valor(F3, (opciones500 & OPC500_SIN_TEXTO) ? x[10] : x[9]);
    valor(F4, (opciones500 & OPC500_SIN_AVE) ? x[10] : x[9]);
    centro(FPIE, x[7]);
    centro(21, x[6]);
    centro(22, "german luis aracil boned");
    centro(23, "garacilb@gmail.com");
}

void menu500(void)
{
    char c;
    unidad500 = peekbsys(0x9F);         /* FA: the drive the disk was loaded from */
    if (unidad500 < 8)
        unidad500 = 8;
    opciones500 = 0;                    /* Spanish, footsteps, text sound and Ave Maria on */
    bgcolor(0);
    bordercolor(0);
    cursor(0);
    pinta();
    for (;;) {
        c = cgetc();
        if (c == ' ' || c == '\r' || c == '\n')
            break;
        if (c >= '1' && c <= '4') {
            opciones500 ^= 1 << (c - '1');
            pinta();
        }
    }
    cclearxy(0, FPIE, 40);
    centro(FPIE, (opciones500 & OPC500_INGLES) ? "LOADING" : "CARGANDO");
}
