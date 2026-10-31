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

/* The parchments of La Abadía del Crimen (CPC 64 KiB version) on the Commodore 64: the introduction
 * (the first stage, then the loading screen and the game's loader) or, built with -DFINAL and the data
 * of ABADIA64.BN1, the ending, shown over and over as the CPC does.
 *
 * A direct port of the CPC routines of the first stage (ABADIA64.BAS, code 6000h-68A8h, read in
 * data/cpc64/perg_6000.asm): the same window coordinates (x 0-255, y 0-199, shown 32 pixels from
 * the left of a 320x200 screen), the same CPC bytes (4 pixels, 2 bits each) and the same delays, measured
 * on the CPC in the simulator (ESTADO.md); the page turn (pagina.s) with each step's time measured in
 * Caprice32 (revision_pagina/NOTAS.md).  The screen is the C64 hires bitmap: each 8x8 cell has two
 * colours, chosen as the pixels arrive (a third colour in a cell takes the nearest one); the red
 * capitals are hardware sprites, and anything later drawn over a capital clears the sprite's pixels,
 * as the CPC overwrote them (the page turn's corner too).
 *
 * Memory: VIC bank 2 ($8000-$BFFF): cell colours at $8000, sprite pointers $83F8, sprites $8400,
 * bitmap $A000 (RAM under the BASIC ROM, which is switched off). */
#include <c64.h>
#include <string.h>
#include "musica.h"

#ifndef FINAL
void carga_juego(void);                               /* carga.s: the game's loader (cargador.s), never returns */
extern const unsigned char carga_pantalla[768], carga_color[768], carga_rosa;   /* carga.c (doc/revisiones/pantalla_carga/pantalla.py) */
#endif
void musica_irq_on(unsigned char voces);              /* sid.s: the 300 Hz interrupt; the SID voicing (below) */
void musica_irq_off(void);
extern const unsigned char perg_musica[], perg_reproductor[];
#ifdef FINAL
#define VOCES 1                                       /* sid.s's voicing of the ending's tune */
#else
#define VOCES 0                                       /* and of the introduction's */
#endif

extern const unsigned char perg_texto[], perg_glifos[], perg_color_pluma[];
extern const unsigned int perg_glifo_desp[];
extern const unsigned char perg_color_borde;
extern const unsigned char perg_blanco_n;             /* the blank parchment's border cells */
extern const unsigned int perg_blanco_celda[];
extern const unsigned char perg_blanco_color[], perg_blanco_bitmap[];
/* pagina.s: the entries of perg_blanco_* of the border ring: top row, bottom row (by cell column - 8), left
 * column, right column (by row); 0xFF none */
extern unsigned char perg_anillo[4][24];

#define CELDAS   ((unsigned char *)0x8000)
#define PUNTEROS ((unsigned char *)0x83F8)
#define SPRITES  ((unsigned char *)0x8400)
#define BITMAP   ((unsigned char *)0xA000)

void __fastcall__ espera(unsigned int iteraciones);   /* espera.s: CPC delay loop of n passes (0 = 65536) */
unsigned char tecla_espacio(void);                    /* espera.s: 1 while space is down */

/* ---- pixels ------------------------------------------------------------------------------------ */

static const unsigned char bit_de[8] = { 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01 };
static const unsigned char suplente[4] = { 3, 2, 1, 0 };     /* pen standing in when a cell is full */

/* capital sprites: screen position of their top-left pixel */
#define MAX_CAPITALES 8
static unsigned int cap_x[MAX_CAPITALES];
static unsigned char cap_y[MAX_CAPITALES];
unsigned char cap_usadas;                             /* (pagina.s too) */
/* for pagina.s's borra_cap: the window byte columns that overlap each capital, its window x and its line */
unsigned char cap_xb_lo[MAX_CAPITALES], cap_xb_hi[MAX_CAPITALES], cap_wx[MAX_CAPITALES], cap_wy[MAX_CAPITALES];

static unsigned char celda_vacia(unsigned char *b)
{
    return (b[0] | b[1] | b[2] | b[3] | b[4] | b[5] | b[6] | b[7]) == 0;
}

/* a pixel of pen 0-3 at screen (sx, sy) */
static void pon_pixel(unsigned int sx, unsigned char sy, unsigned char pen)
{
    unsigned int celda = (unsigned int)(sy >> 3) * 40 + (sx >> 3);
    unsigned char *b = BITMAP + celda * 8;
    unsigned char m = bit_de[sx & 7];
    unsigned char cc = CELDAS[celda], fg = cc >> 4, bg = cc & 15;
    unsigned char c = perg_color_pluma[pen];
    unsigned char i;

    if (c == bg) {
        b[sy & 7] &= (unsigned char)~m;
    } else if (c == fg) {
        b[sy & 7] |= m;
    } else if (fg == bg || celda_vacia(b)) {
        CELDAS[celda] = (unsigned char)((c << 4) | bg);
        b[sy & 7] |= m;
    } else {
        c = perg_color_pluma[suplente[pen]];
        if (c == bg) b[sy & 7] &= (unsigned char)~m; else b[sy & 7] |= m;
    }
    /* what is drawn over a capital clears that pixel of its sprite */
    for (i = 0; i < cap_usadas; ++i) {
        if (sx >= cap_x[i] && sx < cap_x[i] + 24 && sy >= cap_y[i] && sy < cap_y[i] + 21) {
            unsigned char dx = (unsigned char)(sx - cap_x[i]), dy = sy - cap_y[i];
            SPRITES[i * 64 + dy * 3 + (dx >> 3)] &= (unsigned char)~bit_de[dx & 7];
        }
    }
}

/* the rows where capitals lie (bit i: capital i), for pixel.s and pagina.s */
extern unsigned char perg_fila_cap[200];

/* ---- capitals ---------------------------------------------------------------------------------- */

static signed char capital_actual;

static void capitales_fuera(void)
{
    VIC.spr_ena = 0;
    cap_usadas = 0;
    memset(perg_fila_cap, 0, 200);
}

static void capital_nueva(unsigned char x, unsigned char y)
{
    unsigned char n = cap_usadas;
    unsigned int vx;
    if (n == MAX_CAPITALES) { capital_actual = -1; return; }
    cap_x[n] = (unsigned int)x + 32;
    cap_y[n] = y;
    /* byte column xb covers screen pixels 4 xb + 32 .. + 3; the sprite covers x + 32 .. x + 55 */
    cap_xb_lo[n] = x < 3 ? 0 : (unsigned char)((x - 3) >> 2);
    cap_xb_hi[n] = (unsigned char)((x + 23) >> 2);
    cap_wx[n] = x;
    cap_wy[n] = y;
    memset(SPRITES + n * 64, 0, 64);
    PUNTEROS[n] = (unsigned char)(0x10 + n);              /* $8400 / 64 = 16 */
    vx = cap_x[n] + 24;
    (&VIC.spr0_x)[n * 2] = (unsigned char)vx;
    (&VIC.spr0_y)[n * 2] = (unsigned char)(y + 50);
    if (vx & 0x100) VIC.spr_hi_x |= bit_de[7 - n]; else VIC.spr_hi_x &= (unsigned char)~bit_de[7 - n];
    (&VIC.spr0_color)[n] = perg_color_pluma[3];
    VIC.spr_ena |= bit_de[7 - n];
    for (vx = 0; vx < 21 && y + vx < 200; ++vx) perg_fila_cap[y + vx] |= bit_de[7 - n];
    cap_usadas = n + 1;
    capital_actual = (signed char)n;
}

static void capital_pixel(unsigned char dx, unsigned char dy)
{
    SPRITES[capital_actual * 64 + dy * 3 + (dx >> 3)] |= bit_de[dx & 7];
}

/* ---- the parchment ----------------------------------------------------------------------------- */

static unsigned char cur_x, cur_y;          /* parch cursor (6770h) */

/* 6515h: the blank parchment.  The CPC fills the screen with pen 0 and, on every line, bytes 0-15 and
 * 64-79 (pixels 0-63, 256-319) and the lines 192-199 with pen 1: here whole cells of one colour
 * (cell columns 8-31 pink, the rest dark red, cell row 24 dark red); then the four borders (6581h, 6594h),
 * whose cells the data generator has already drawn as this program's pixel rule draws them byte by
 * byte (that took 3 s, the CPC 0.2 s): they are copied. */
static void pergamino_en_blanco(void)
{
    unsigned char cx, cy, c0 = perg_color_pluma[0], c1 = perg_color_pluma[1], i;
    unsigned char *celda = CELDAS;
    const unsigned char *src = perg_blanco_bitmap;
    memset(BITMAP, 0, 8000);
    for (cy = 0; cy < 25; ++cy) {
        for (cx = 0; cx < 40; ++cx) {
            unsigned char c = (cy < 24 && cx >= 8 && cx < 32) ? c0 : c1;
            *celda++ = (unsigned char)((c << 4) | c);
        }
    }
    memset(perg_anillo, 0xFF, sizeof perg_anillo);
    for (i = 0; i < perg_blanco_n; ++i) {
        unsigned int c = perg_blanco_celda[i];
        unsigned char fila = (unsigned char)(c / 40), col = (unsigned char)(c % 40);
        CELDAS[c] = perg_blanco_color[i];
        memcpy(BITMAP + c * 8, src, 8);
        src += 8;
        /* the border ring's cells, for the page turn's restores (pagina.s) */
        if (fila == 0) perg_anillo[0][col - 8] = i;
        if (fila == 23) perg_anillo[1][col - 8] = i;
        if (col == 8) perg_anillo[2][fila] = i;
        if (col == 31) perg_anillo[3][fila] = i;
    }
}

/* 65FDh: the page turn (pagina.s: the corner, the border restores, the CPC's time for each step); the corner has
 * cleared every pixel of the capitals' sprites as it passed over them: they are switched off */
void pasa_pagina(void);

/* 6733h: a 3000 delay, then cursor x += pixels */
static void avanza(unsigned char pixels)
{
    espera(0x0BB8);
    cur_x += pixels;
}

/* 6756h: a new page: cursor (2Ch, 10h), three delays of 65536, the page turn */
static void pagina_nueva(void)
{
    cur_x = 0x2C; cur_y = 0x10;
    espera(0); espera(0); espera(0);
    pasa_pagina();
    capitales_fuera();
}

/* 6744h: a 60000 delay, the next line; a full page turns */
static void linea_nueva(void)
{
    espera(0xEA60);
    cur_y += 0x10;
    cur_x = 0x2C;
    if (cur_y >= 0xA4) pagina_nueva();
}

/* 668Bh: write the text until space is pressed (a test build with -DSALTA_TRAS=n stops after n
 * characters, as if space had been pressed; -DCONGELA_TRAS=n stops there for ever, for screenshots) */
static void escribe_texto(const unsigned char *t)
{
#if defined(SALTA_TRAS) || defined(CONGELA_TRAS)
    unsigned int escritos = 0;
#endif
    cur_x = 0x2C; cur_y = 0x10;
    for (;;) {
        unsigned char ch, capital;
        const unsigned char *g;
        if (tecla_espacio()) return;
#ifdef SALTA_TRAS
        if (++escritos > SALTA_TRAS) return;
#endif
#ifdef CONGELA_TRAS
        if (++escritos > CONGELA_TRAS) for (;;) ;
#endif
        ch = *t;
        if (ch == 0x1A) continue;
        ++t;
        if (ch == 0x0D) { linea_nueva(); continue; }
        if (ch == 0x20) { avanza(0x0A); continue; }
        if (ch == 0x0A) { pagina_nueva(); continue; }
        capital = (ch & 0x60) == 0x40;
        if (capital) capital_nueva(cur_x, cur_y);
        if (perg_glifo_desp[ch - 0x20] == 0xFFFF) continue;
        g = perg_glifos + perg_glifo_desp[ch - 0x20];
        for (;;) {
            unsigned char v;
            espera(0x0320);
            v = *g++;
            if ((v & 0xF0) == 0xF0) { avanza(v & 0x0F); break; }
            if (capital && capital_actual >= 0) {
                capital_pixel(v & 0x0F, v >> 4);
            } else {
                pon_pixel((unsigned int)(unsigned char)(cur_x + (v & 0x0F)) + 32,
                          (unsigned char)(cur_y + (v >> 4)), capital ? 3 : 2);
            }
        }
    }
}

#ifndef FINAL
/* After the parchment the CPC tape's loader sets mode 0, the border black and the pens 15..0 from its table (pen 0
 * pink: the screen memory is 0, so the screen is pink), then reads the block 20h, the picture building up as its
 * bytes arrive (c64/pergamino/cargador.s).  Here the picture's place is the game's screen, as on the CPC (whose loader
 * sets the game's CRTC geometry): VIC bank 3, screen RAM $C000, bitmap $E000, cells 4-35 of rows 0-23; $D021 and
 * the border black.  Each cell of the picture gets its loading colours (the picture's own, with pink in a free slot
 * or in place of the least used of three: doc/revisiones/pantalla_carga/pantalla.py) and its bitmap the bit pair of the pink: the
 * picture's place is pink until its bytes come.  The cells outside it are black (their bitmap bytes are the game's
 * data, loaded as they come). */
static void pantalla_de_carga(void)
{
    unsigned char f, c, s, patron;
    unsigned char *pant = (unsigned char *)0xC000, *col = COLOR_RAM, *bm;
    const unsigned char *ps = carga_pantalla, *pc = carga_color;
    VIC.ctrl1 = 0x0B;                                    /* the CPC sets every ink black: blanked meanwhile */
    VIC.bordercolor = 0;
    VIC.bgcolor0 = 0;
    VIC.spr_ena = 0;
    memset(pant, 0, 1000);
    memset(COLOR_RAM, 0, 1000);
    for (f = 0; f < 24; ++f) {
        bm = (unsigned char *)0xE000 + f * 320 + 4 * 8;  /* (RAM under the KERNAL: writes reach it) */
        for (c = 0; c < 32; ++c) {
            s = *ps++;
            pant[f * 40 + 4 + c] = s;
            col[f * 40 + 4 + c] = *pc++;
            patron = (s >> 4) == carga_rosa ? 0x55 : (s & 15) == carga_rosa ? 0xAA : 0xFF;
            memset(bm, patron, 8);
            bm += 8;
        }
    }
    CIA2.ddra |= 0x03;                                   /* VIC bank 3 ($C000-$FFFF) */
    CIA2.pra &= 0xFC;
    VIC.addr = 0x08;                                     /* screen RAM $C000, bitmap $E000 */
    VIC.ctrl2 = 0x18;                                    /* multicolour, 40 columns */
    VIC.ctrl1 = 0x3B;                                    /* bitmap mode, display on: pink */
}
#endif

int main(void)
{
    *(unsigned char *)0x01 = 0x36;                       /* BASIC ROM off: RAM at $A000-$BFFF */
    musica_inicia(perg_musica, 1024, perg_reproductor);  /* 6019h-6022h: the music starts with the parchment */
    musica_irq_on(VOCES);
    VIC.ctrl1 = 0x0B;                                    /* screen off while drawing */
    VIC.bordercolor = perg_color_borde;
    VIC.bgcolor0 = perg_color_borde;
    capitales_fuera();
    VIC.spr_mcolor = 0;
    VIC.spr_exp_x = 0;
    VIC.spr_exp_y = 0;
    VIC.spr_bg_prio = 0;
    pergamino_en_blanco();
    CIA2.pra = (CIA2.pra & 0xFC) | 0x01;                 /* VIC bank 2 */
    VIC.addr = 0x08;                                     /* cells $8000, bitmap $A000 */
    VIC.ctrl2 = 0x08;                                    /* hires, 40 columns */
    VIC.ctrl1 = 0x3B;                                    /* bitmap mode, screen on */
#ifdef BANCO
    { void banco(void); banco(); }
#endif
#ifdef FINAL
    /* the ending (ABADIA64.BN1): the game's end routine (3346h) calls the parchment over and over
     * (3376h): after space, 6038h-604Bh stop the music, set every ink black and clear the screen; the
     * next entry starts the music again (6019h-6022h) and draws the blank parchment and the text anew */
    for (;;) {
        escribe_texto(perg_texto);
        musica_para();                                   /* 6038h */
        VIC.ctrl1 = 0x0B;                                /* 603Bh: every ink black */
        VIC.bordercolor = 0;
        VIC.bgcolor0 = 0;
        capitales_fuera();
        musica_reinicia();                               /* 6019h-6022h */
        pergamino_en_blanco();                           /* 6503h */
        VIC.bordercolor = perg_color_borde;              /* 6119h: the parchment's inks */
        VIC.bgcolor0 = perg_color_borde;
        VIC.ctrl1 = 0x3B;
    }
#else
    escribe_texto(perg_texto);
    musica_para();                                       /* 6038h */
    musica_irq_off();
    pantalla_de_carga();
    carga_juego();
    return 0;
#endif
}
