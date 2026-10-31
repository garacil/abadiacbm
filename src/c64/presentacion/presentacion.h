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

/* What this build adds to the presentation (abadia.c) and parchment (manuscrito.c): presentacion.c */

void musicstart(void);                  /* the parchment's music, when it appears (manusrun) */
void musicstop(void);                   /* and when the key that ends it is taken (abadia.c, final.c) */
void gameload(unsigned char *buffer);   /* abadia.koa on the game's screen, then the game's loader: never returns */

#if defined(CINTA)
/* The tape (c64/cinta/NOTAS.md): both languages' picture, parchment border and glyphs (pp.bin) and texts are in
 * the program itself (datos_cinta.s, datos_final_cinta.s: one load, crunched with Exomizer); the menu's language
 * is bit 0 of OPCIONES ($02A7, c64/cinta/cinta.inc): 1 English. */
#include <peekpoke.h>
#if defined(__C128__)
/* The C128's disk (abadia128ks, c64/disco128) is built with CINTA too: the same data inside the program, its menu's
 * options at $0BFF (c64/disco128/disco128.inc OPCIONES) */
#define CINTA_INGLES (PEEK(0x0BFF) & 1)
#elif defined(__CBM510__)
/* The P500's disk (abadia128ks, c64/discop500) too: its menu (menu500.c) keeps the options in opciones500 */
extern unsigned char opciones500, unidad500;
void menu500(void);
#define OPC500_INGLES    1              /* the bits of c64/discop500/disco500.inc */
#define OPC500_SIN_PASOS 2
#define OPC500_SIN_TEXTO 4
#define OPC500_SIN_AVE   8
#define CINTA_INGLES (opciones500 & 1)
#else
#define CINTA_INGLES (PEEK(0x02A7) & 1)
#endif
extern unsigned char cinta_koa_es[], cinta_koa_en[], cinta_pp_es[], cinta_pp_en[];
extern unsigned char cinta_text1_es[], cinta_text1_en[], cinta_text2_es[], cinta_text2_en[];
#endif
