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

/* What this build adds to the presentation (abadia.c) and parchment (manuscrito.c), c64/presentacion/NOTAS.md:
 *
 * musicstart / musicstop: the CPC's music of the parchment (its player c64/pergamino/musica.s, the same AY register
 *   writes as the CPC; sid.s plays them on the SID with its voicing and runs the 300 Hz interrupt, which also scans
 *   the keyboard for conio's kbhit and cgetc, the key tests).  The introduction's tune (musica_inicio.c) or,
 *   built with -DFINAL, the ending's (musica_final.c), from the tape's stages (datos.py).
 * gameload: the picture on the game's screen, then the game's loader (cargador.s, through carga.s).
 */
#include <cbm.h>                        /* c64.h, or c128.h for the C128's disk (abadia128ks) */
#include <string.h>
#include <peekpoke.h>
#include "presentacion.h"
#include "musica.h"                     /* c64/pergamino/musica.h: the player's interface */

void musica_irq_on(unsigned char voces);                        /* sid.s */
void musica_irq_off(void);
extern const unsigned char perg_musica[], perg_reproductor[];  /* musica_inicio.c or musica_final.c */

#ifdef FINAL
#define VOCES 1                         /* sid.s's voicing of the ending's tune */
#else
#define VOCES 0                         /* and of the introduction's */
void carga_juego(void);                 /* carga.s: copies the loader to its place and jumps there */
#endif

static unsigned char empezada;
#if defined(__CBM510__)
void teclas500_vacia(void);                                    /* sid.s: cc65's keyboard buffer emptied (its keyidx) */
void __fastcall__ carga_juego500(unsigned char *buffer);       /* carga500.s: the picture, the game's files: never returns */
#endif

/* The music starts when the parchment appears (manusrun calls this after manusini), as the CPC's stage starts it at
 * 6019h-6022h before drawing the parchment: the first time with the player as the stage's image holds it
 * (musica_inicia), later (the ending, written again after each key) channel A from the start, as the CPC's re-entry
 * (musica_reinicia).  Keys pressed before (while the parchment was being loaded) are dropped: they do not end it. */
void musicstart(void)
{
    if (!empezada) {
        musica_inicia(perg_musica, 1024, perg_reproductor);
        empezada = 1;
    } else {
        musica_reinicia();
    }
    musica_irq_on(VOCES);
#if defined(__C128__)
    POKE(0xD0, 0);                      /* the KERNAL's keyboard buffer emptied (the C128's NDX) */
#elif defined(__CBM510__)
    teclas500_vacia();                  /* cc65's keyboard buffer emptied (the P500: its own, filled by its interrupt) */
#else
    POKE(0xC6, 0);                      /* the KERNAL's keyboard buffer emptied */
#endif
}

/* After the key that ends the parchment: silence (64F1h) and the KERNAL's own interrupt back */
void musicstop(void)
{
    musica_para();
    musica_irq_off();
}

#ifndef FINAL
/* abadia.koa, read by abadia.c into `buffer` before the parchment (8000 bytes of bitmap, 1000 of screen RAM, 1000 of
 * colour RAM), shown as abadia.c showed it (copied, then multicolour bitmap mode), but on the game's screen
 * instead of the original's (io.h: bitmap $C000, screen RAM $E000, where the parchment is): VIC bank 3, screen RAM $C000, bitmap
 * $E000 ($D018 = $08), the screen the game itself uses.  The game, which needs nearly all the rest of the RAM, then
 * loads under the picture (c64/cinta/FLUJO.md): the loader keeps the picture until the end, but for the side cells
 * (columns 0-3 and 36-39, row 24), blackened when their bitmap bytes, the game's data, come. */
void gameload(unsigned char *buffer)
{
#if defined(__CBM510__)
    /* the P500 (c64/discop500): the picture on the game's screen and the loading, in assembly (the picture's bitmap
     * covers cc65's C stack: no C from there on) */
    carga_juego500(buffer);
#else
#if defined(__C128__)
    POKE(0xD8, 0xFF);                   /* the C128: its screen editor's interrupt leaves the VIC-II alone */
#endif
    VIC.ctrl1 = 0x0B;                   /* blanked while the memory changes: the parchment's is the picture's */
    VIC.bordercolor = 0;
    VIC.bgcolor0 = 0;                   /* the picture's background (the bgcolor(0)) */
    VIC.spr_ena = 0;
#if defined(__C128__)
    /* the C128: $FF00-$FF04 are the MMU's registers in every configuration ("Mapping the Commodore 128"), so the
     * bitmap's 5 bytes there (row 24, cell 32) cannot be written: copied around them, that cell made black */
    memcpy((unsigned char *)0xE000, buffer, 0x1F00);
    memcpy((unsigned char *)0xFF05, buffer + 0x1F05, 8000 - 0x1F05);
    memcpy((unsigned char *)0xC000, buffer + 8000, 1000);
    memcpy(COLOR_RAM, buffer + 9000, 1000);
    POKE(0xC000 + 24 * 40 + 32, 0);
    POKE(0xD800 + 24 * 40 + 32, 0);
#else
    memcpy((unsigned char *)0xE000, buffer, 8000);         /* RAM under the KERNAL ROM: writes reach it */
    memcpy((unsigned char *)0xC000, buffer + 8000, 1000);
    memcpy(COLOR_RAM, buffer + 9000, 1000);
#endif
    CIA2.ddra |= 0x03;
    CIA2.pra &= 0xFC;                   /* VIC bank 3 ($C000-$FFFF), as the original */
    VIC.addr = 0x08;                    /* screen RAM $C000, bitmap $E000 (the original: $83) */
    VIC.ctrl2 = VIC.ctrl2 | 0x10;       /* multicolour (as screenbitmapmulticolor) */
    VIC.ctrl1 = 0x3B;                   /* bitmap mode, display on */
    carga_juego();
#endif
}
#endif
