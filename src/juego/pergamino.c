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

/* The parchments of La Abadía del Crimen, CPC 64 KiB version (tape), in C.
 *
 * The introduction (the tape's first stage, block 16h) and the ending (block 2Ah, loaded by the game at
 * 31CFh) are the same Z80 code at 6000h-68A8h with their own text, border graphics and tune; this file
 * translates that code (data/cpc64/perg_6000.asm) routine by routine, reading every address from the
 * stage's own code in ds as the Z80 does (the text from the operand of LD IX at 6026h, the borders from
 * 655Bh, 6567h, 6573h, 657Fh and 65B5h, 65E4h, 6643h, 667Ch, the glyph pointers from 66D9h, the tune from
 * 601Ah): it writes the same bytes to the same screen addresses (mode 1, C000h-FFFFh) in the same order.
 * The music is musica.c (the player of 61BAh-6502h, checked against the CPC tick by tick).
 *
 * The time.  The CPC's parchment is paced by its own code: busy loops (672Ch: 30 T-states a pass) and
 * the drawing itself, slowed by the 300 Hz interrupt that plays the music.  So the emulated time here is
 * the Z80's: every routine adds the T-states its instructions take (SkoolKit's timings, those of the
 * simulator tools/cpc_carga.py; tools/gnu_comparacion/tiempos_z80.py lists them), an
 * interrupt is due every 13312 T-states (300 Hz) and taken, as the simulator takes it, at the first
 * instruction start at or after its time when interrupts are enabled and the byte before that start is
 * not FBh, DDh or FDh (SkoolKit's accept_interrupt as cpc_carga.py calls it; else that interrupt is
 * lost), and costs 13 T-states plus its handler (613Fh, with musica.c's count of 61DBh).  A frame (50 Hz)
 * is every 6 interrupts: there the platform shows the screen (perg_al_frame).  The screen of every frame
 * is then the CPC's at the same time: the drawing of each byte is placed at its instruction's start.
 *   z(n)  a run of instructions (n T-states) that writes no screen byte: the interrupts inside it are
 *         taken at their exact time, not at the next instruction start (at most 22 T-states early: the
 *         run's total time is the same; it could only matter if the next interrupt fell on the last
 *         instructions of a handler; juego/gnu/prueba.sh compares every frame and AY write with the
 *         simulator and finds no difference);
 *   i1(n) one instruction, ir(n) one instruction whose start refuses the interrupt (the byte before it
 *         is FBh/DDh/FDh), w(a, v, n) one instruction that writes the screen byte a := v;
 *   di(), ei() the Z80's DI and EI.
 * The order of the explicit instructions follows the listing wherever an interrupt could be refused or
 * enabled; elsewhere runs are summed (the sums are the listing's, by address range in the comments). */
#include <string.h>
#include "juego.h"
#include "musica.h"
#include "pergamino.h"

uint64_t perg_t;
unsigned long perg_ticks, perg_frames;
void (*perg_al_frame)(void);

static uint64_t prox;                   /* when the next interrupt is due */
static int iff;                         /* interrupts enabled */
static int vector_musica;               /* 0038h jumps to the parchment's handler (613Fh, set at 600Eh) */
static int musica_cargada;              /* the player's state taken from the stage's image */
static uint8_t cur_x, cur_y;            /* 6770h, 6771h: the text cursor, window pixels (x 0-255) */

/* ---- the clock --------------------------------------------------------------------------------- */

static void interrupcion(void);

/* an interrupt's time reached at an instruction start: counted (a frame every 6), taken or lost */
static void tick(int acepta)
{
    prox += PERG_TICK;
    ++perg_ticks;
    if (perg_ticks % 6 == 0) {
        ++perg_frames;
        if (perg_al_frame) perg_al_frame();
    }
    if (acepta) interrupcion();
}

static void chk(int rechaza) { if (prox <= perg_t) tick(iff && !rechaza); }
static void ciclos(unsigned long n) { perg_t += n; }

/* n T-states of instructions whose starts all accept the interrupt (if enabled) */
static void dentro(unsigned long n)
{
    uint64_t fin = perg_t + n;
    while (prox < fin) {
        uint64_t antes;
        if (prox > perg_t) perg_t = prox;
        antes = perg_t;
        tick(iff);
        fin += perg_t - antes;            /* the interrupt's handler delays the run */
    }
    perg_t = fin;
}

static void z(unsigned long n) { chk(0); dentro(n); }
static void i1(unsigned long n) { chk(0); ciclos(n); }
static void ir(unsigned long n) { chk(1); ciclos(n); }
static void di(void) { chk(0); ciclos(4); iff = 0; }
static void ei(void) { chk(0); ciclos(4); iff = 1; }
static void w(uint16_t a, uint8_t v, unsigned long n) { chk(0); wscr(a, v); ciclos(n); }

/* the interrupt: IM 1, RST 38h (13 T-states) */
static void interrupcion(void)
{
    iff = 0;
    if (!vector_musica) {                 /* before 600Eh: cpc_carga.py's firmware stub, JP B900h: EI, RET */
        dentro(13 + 10);
        ei();
        ir(10);
        return;
    }
    musica_ciclos = 0;
    musica_tick();                        /* 61DBh: its register writes go to the platform now */
    /* JP 613Fh (0038h), DI, PUSH AF, CALL 61DBh (613Fh-6141h), 61DBh up to its EI (61F1h) */
    dentro(13 + 10 + 32 + musica_ciclos - 14);
    iff = 1;
    ir(14);                               /* 61F2h RETI, after the EI */
    i1(10);                               /* 6144h POP AF */
    ei();                                 /* 6145h */
    ir(14);                               /* 6146h RETI */
}

void perg_reloj(int con_iff)
{
    perg_t = 0;
    prox = PERG_TICK;
    perg_ticks = perg_frames = 0;
    iff = con_iff;
    vector_musica = 0;
}

void perg_espera(uint64_t t)
{
    while (prox <= t) {
        if (prox > perg_t) perg_t = prox;
        tick(0);
    }
    if (t > perg_t) perg_t = t;
}

void pergamino_nuevo(void) { musica_cargada = 0; }

/* the music player's register writes: the AY through the PPI as 64C9h does */
void musica_registro(unsigned char reg, unsigned char valor) { plat_psg(reg, valor); }

/* ---- small routines ------------------------------------------------------------------------------ */

/* 682Dh: the screen address of window pixel (x, y): the window starts 8 bytes (32 pixels) into the line */
static uint16_t dir(uint8_t x, uint8_t y)
{
    return (uint16_t)((0xC000 | (y & 7) << 11 | (y >> 3) * 80) + (x >> 2) + 8);
}

/* CALL 6858h: the next screen line */
static uint16_t siguiente(uint16_t hl)
{
    uint8_t h = (uint8_t)(hl >> 8), l = (uint8_t)hl;
    if (h < 0xF8) { z(17 + 32); return (uint16_t)((h + 8) << 8 | l); }
    h &= 0xC7;
    if (l < 0xB0) { z(17 + 64); return (uint16_t)(h << 8 | (l + 0x50)); }
    z(17 + 80);
    return (uint16_t)((h << 8 | l) + 0x50);
}

/* 672Ch (after its CALL): BC passes of NOP, DEC BC, LD A,B, OR C, JR NZ (0 = 65536), then RET */
static void retardo(unsigned long n)
{
    if (!n) n = 65536;
    z(30 * n + 5);
}

/* LDIR within the screen: one byte an iteration, 21 T-states, 16 the last */
static void ldir(uint16_t hl, uint16_t de, uint16_t bc)
{
    do {
        chk(0);
        wscr(de, rscr(hl));
        ++hl; ++de;
        ciclos(--bc ? 21 : 16);
    } while (bc);
}

/* 611Ch (after LD HL,table at 6114h or 6119h): pens 3, 2, 1, 0 and the border from the table */
static void tintas(uint16_t hl)
{
    unsigned a;
    di();                                       /* 611Ch */
    z(7 + 7);                                   /* LD A,4; LD B,7Fh */
    for (a = 4; a; --a) {
        z(4 + 4 + 12 + 7 + 6 + 8);              /* LD C,A; DEC C; OUT (C),C; LD C,(HL); INC HL; SET 6,C */
        chk(0); plat_tinta((uint8_t)(a - 1), rb(hl) & 0x1F); ciclos(12);   /* OUT (C),C */
        ++hl;
        z(4 + (a > 1 ? 12 : 7));                /* DEC A; JR NZ */
    }
    z(7 + 12 + 7 + 8);                          /* LD C,10h; OUT (C),C; LD C,(HL); SET 6,C */
    chk(0); plat_tinta(16, rb(hl) & 0x1F); ciclos(12);
    ei();                                       /* 6137h */
    ir(10);                                     /* 6138h RET */
}

/* 604Ch (after the CALL at 6004h): CRTC register, value pairs from the bytes after the CALL, FFh ends */
static void crtc_en_linea(uint16_t hl)
{
    z(10);                                      /* POP HL */
    for (;;) {
        uint8_t r = rb(hl++);
        if (r == 0xFF) { z(7 + 7 + 6 + 11 + 4 + 11); return; }   /* ... INC C; RET Z (to the byte after FFh) */
        z(7 + 7 + 6 + 11 + 4 + 5 + 4 + 10 + 12 + 4 + 7);         /* 604Dh-6059h */
        chk(0); plat_crtc(r, rb(hl)); ciclos(12);                /* 605Ah OUT (C),C */
        ++hl;
        z(6 + 12);                                               /* INC HL; JR */
    }
}

/* 605Fh (after its CALL): the keyboard matrix read into 60AEh-60B7h with interrupts off (no EI at its
 * end); the parchment only tests space (row 5, bit 7), read at its row's IN.  1 when space is down. */
static int teclado_espacio(void)
{
    uint8_t fila;
    di();                                       /* 605Fh */
    z(137 + 5 * 185 + 34);                      /* 6060h-607Dh, rows 0-4, row 5 up to its IN (6086h) */
    chk(0);
    fila = plat_teclado_fila(5);
    wb(0x60AE + 5, fila);
    ciclos(12);
    z(185 - 34 - 12 + 3 * 185 + 180 + 55);      /* the rest of row 5, rows 6-9, 609Fh-60A7h */
    return !(fila & 0x80);
}

/* ---- the blank parchment (6515h) ------------------------------------------------------------------ */

/* 6581h: 48 columns of 8 lines (a horizontal border), from the table at de */
static void borde_h(uint16_t hl, uint16_t de)
{
    unsigned c, b;
    z(7);                                       /* LD C,30h */
    for (c = 0x30; c; --c) {
        uint16_t p = hl;
        z(7 + 11);                              /* LD B,8; PUSH HL */
        for (b = 8; b; --b) {
            z(7);                               /* LD A,(DE) */
            w(p, rb(de), 7);                    /* LD (HL),A */
            p = siguiente(p);
            z(6 + (b > 1 ? 13 : 8));            /* INC DE; DJNZ */
            ++de;
        }
        z(10 + 6 + 4 + (c > 1 ? 12 : 7));       /* POP HL; INC HL; DEC C; JR NZ */
        ++hl;
    }
    z(10);                                      /* RET */
}

/* 6594h: 192 lines of 2 bytes (a vertical border) */
static void borde_v(uint16_t hl, uint16_t de)
{
    unsigned b;
    z(7);                                       /* LD B,0C0h */
    for (b = 0xC0; b; --b) {
        z(7); w(hl, rb(de), 7);                 /* LD A,(DE); LD (HL),A */
        z(6 + 6 + 7); w((uint16_t)(hl + 1), rb((uint16_t)(de + 1)), 7);   /* INC HL; INC DE; LD A,(DE); LD (HL),A */
        z(6 + 6);                               /* DEC HL; INC DE */
        de = (uint16_t)(de + 2);
        hl = siguiente(hl);
        z(b > 1 ? 13 : 8);                      /* DJNZ */
    }
    z(10);
}

/* 6515h (after its CALL): the screen cleared, the parchment's pen 1 sides (bytes 0-15 and 64-79 of every
 * line, and lines 192-199), then the four borders */
static void en_blanco(void)
{
    uint16_t hl, de, h2;
    unsigned c, b;
    z(10 + 11 + 4 + 4 + 6);                     /* LD HL,0C000h; PUSH HL; LD D,H; LD E,L; INC DE */
    w(0xC000, 0, 10);                           /* LD (HL),0 */
    z(10);                                      /* LD BC,3FFFh */
    ldir(0xC000, 0xC001, 0x3FFF);
    z(10 + 7);                                  /* POP HL; LD C,0C8h */
    hl = 0xC000;
    for (c = 200; c; --c) {
        z(7 + 7 + 11 + 10 + 4 + 11);            /* LD B,10h; LD A,0F0h; PUSH HL; LD DE,40h; EX DE,HL; ADD HL,DE */
        de = hl; h2 = (uint16_t)(hl + 0x40);
        for (b = 16; b; --b) {
            z(11);                              /* PUSH BC */
            w(h2, 0xF0, 7);                     /* LD (HL),A */
            w(de, rscr(h2), 16);                /* LDI */
            ++de; ++h2;
            z(10 + (b > 1 ? 13 : 8));           /* POP BC; DJNZ */
        }
        z(10);                                  /* POP HL */
        hl = siguiente(hl);
        z(4 + (c > 1 ? 12 : 7));                /* DEC C; JR NZ */
    }
    z(10 + 7);                                  /* LD HL,0C780h; LD B,8 */
    hl = 0xC780;
    for (b = 8; b; --b) {
        z(11 + 11 + 4 + 4 + 6 + 10);            /* PUSH BC; PUSH HL; LD E,L; LD D,H; INC DE; LD BC,4Fh */
        ldir(hl, (uint16_t)(hl + 1), 0x4F);
        z(10);                                  /* POP HL */
        hl = siguiente(hl);
        z(10 + (b > 1 ? 13 : 8));               /* POP BC; DJNZ */
    }
    z(10 + 17 + 233 + 10 + 17);                 /* 6554h: LD HL,20h; CALL 682Dh; LD DE,top; CALL 6581h */
    borde_h(dir(0x20, 0), rw(0x655B));
    z(10 + 17 + 233 + 10 + 17);                 /* 6560h: the right border */
    borde_v(dir(0xDA, 0), rw(0x6567));
    z(10 + 17 + 233 + 10 + 17);                 /* 656Ch: the left border */
    borde_v(dir(0x20, 0), rw(0x6573));
    z(10 + 17 + 233 + 10);                      /* 6578h: the bottom border (into 6581h, whose RET ends 6515h) */
    borde_h(dir(0x20, 0xB8), rw(0x657F));
}

/* ---- the page turn (65FDh) ------------------------------------------------------------------------ */

/* 686Ch (after its CALL): one frame of the turning corner, `bandas` bands of 4 lines from (x, y): each
 * line F0h at its start and its corner byte (68A9h) d bytes on, then 00h; the last band fills with F0h */
static void esquina(uint8_t x, uint8_t y, uint8_t bandas)
{
    uint16_t hl = dir(x, y);
    uint8_t b = bandas, d = 0;
    z(17 + 233 + 7);                            /* CALL 682Dh; LD D,0 */
    do {
        unsigned c;
        z(7);                                   /* 6871h LD C,4 */
        for (c = 4; c; --c) {
            uint16_t lin = hl, p = hl;
            uint8_t pat = rb((uint16_t)(0x68A9 + c - 1)), e = 0;
            z(105 + 30);                        /* 6873h-6882h: the corner byte into 6898h */
            wb(0x6898, pat);
            for (;;) {
                z(8);                           /* LD A,D; CP E */
                if (d == e) { i1(12); break; }  /* JR Z,6897h */
                z(7);
                w(p, 0xF0, 10);                 /* LD (HL),0F0h */
                if (b != 1) { z(4 + 12 + 4 + 47); p = (uint16_t)(p + d); break; }   /* DEC B; JR NZ; INC B; CALL 64C3h */
                z(4 + 7 + 4 + 6 + 4 + 12);      /* DEC B; JR NZ; INC E; INC HL; INC B; JR */
                ++e; ++p;
            }
            w(p, pat, 10);                      /* 6897h LD (HL),corner */
            z(6);                               /* INC HL */
            w((uint16_t)(p + 1), 0, 10);        /* LD (HL),0 */
            z(10);                              /* POP HL */
            hl = siguiente(lin);
            z(10 + 4 + (c > 1 ? 12 : 7));       /* POP BC; DEC C; JR NZ */
        }
        z(4 + 4 + (b > 1 ? 13 : 8));            /* INC E; INC D; DJNZ */
        ++d;
    } while (--b);
    z(10);                                      /* RET */
}

/* 65A4h (after its CALL): two columns of the top border back at x + 4, and 8 lines of the right border
 * at 4 (c - 3) */
static void repon_arriba_derecha(uint8_t x, uint8_t c)
{
    uint16_t de = (uint16_t)(rw(0x65B5) + (uint8_t)((0x30 - c) * 4) * 2), hl, p;
    uint8_t y;
    unsigned b, k;
    z(107 + 17 + 233);                          /* 65A4h-65B8h; CALL 682Dh */
    hl = dir((uint8_t)(x + 4), 0);
    z(11 + 7);                                  /* PUSH HL; LD B,8 */
    for (k = 0; k < 2; ++k) {
        p = (uint16_t)(hl + k);
        for (b = 8; b; --b) {
            z(7); w(p, rb(de), 7);              /* LD A,(DE); LD (HL),A */
            p = siguiente(p);
            z(6 + (b > 1 ? 13 : 8));            /* INC DE; DJNZ */
            ++de;
        }
        if (!k) z(10 + 6 + 7);                  /* POP HL; INC HL; LD B,8 */
    }
    z(107 + 17 + 233);                          /* 65D3h-65E7h; CALL 682Dh */
    y = (uint8_t)((c - 3) * 4);
    de = (uint16_t)(rw(0x65E4) + y * 2);
    p = dir(0xDA, y);
    z(7);                                       /* LD B,8 */
    for (b = 8; b; --b) {
        z(7); w(p, rb(de), 7);
        z(6 + 6 + 7); w((uint16_t)(p + 1), rb((uint16_t)(de + 1)), 7);
        z(6 + 6);
        de = (uint16_t)(de + 2);
        p = siguiente(p);
        z(b > 1 ? 13 : 8);
    }
    z(30);                                      /* POP BC; POP HL; RET */
}

/* 666Bh (after its CALL or from 6669h): column c of the bottom border back at line B8h */
static void repon_abajo(uint8_t c)
{
    uint8_t e = (uint8_t)(c * 4);
    uint16_t p = dir((uint8_t)(e + 0x20), 0xB8), de = (uint16_t)(rw(0x667C) + e * 2);
    unsigned b;
    z(41 + 17 + 233 + 47);                      /* 666Bh-6674h; CALL 682Dh; 6679h-6680h */
    for (b = 8; b; --b) {
        z(7); w(p, rb(de), 7);                  /* LD A,(DE); LD (HL),A */
        z(6);                                   /* INC DE */
        ++de;
        p = siguiente(p);
        z(b > 1 ? 13 : 8);
    }
    z(10);
}

/* 65FDh (after its CALL): the corner runs along the top from the right, then down the left side */
static void pasa_pagina(void)
{
    uint8_t x = 0xD3, c = 3, y;
    unsigned n, k;
    z(7 + 7 + 10);                              /* LD B,2Dh; LD C,3; LD HL,0D3h */
    for (n = 0x2D; n; --n) {
        z(11 + 11 + 4 + 17);                    /* PUSH BC; PUSH HL; LD B,C; CALL 686Ch */
        esquina(x, 0, c);
        z(10 + 17);                             /* LD BC,7D0h; CALL 672Ch */
        retardo(0x07D0);
        z(10 + 10 + 17);                        /* POP HL; POP BC; CALL 65A4h */
        repon_arriba_derecha(x, c);
        z(16 + 4 + (n > 1 ? 13 : 8));           /* DEC L x4; INC C; DJNZ */
        x = (uint8_t)(x - 4); ++c;
    }
    z(17);                                      /* CALL 65A4h */
    repon_arriba_derecha(x, c);
    z(7 + 7 + 10);                              /* LD B,2Eh; LD C,2Fh; LD HL,420h */
    c = 0x2F; y = 4;
    for (n = 0x2E; n; --n) {
        uint16_t p, de;
        z(11 + 4 + 11 + 17);                    /* PUSH BC; LD B,C; PUSH HL; CALL 686Ch */
        esquina(0x20, y, c);
        z(10 + 17);
        retardo(0x07D0);
        z(10 + 37 + 17 + 233 + 68);             /* POP HL; 6633h-6638h; CALL 682Dh; 663Ch-6647h */
        p = dir(0x20, (uint8_t)(y - 4));
        de = (uint16_t)(rw(0x6643) + (uint8_t)(y - 4) * 2);
        for (k = 4; k; --k) {                   /* 4 lines of the left border back */
            z(7); w(p, rb(de), 7);
            z(6 + 6 + 7); w((uint16_t)(p + 1), rb((uint16_t)(de + 1)), 7);
            z(6 + 6);
            de = (uint16_t)(de + 2);
            p = siguiente(p);
            z(k > 1 ? 13 : 8);
        }
        z(42 + 17);                             /* POP HL; POP BC; PUSH BC; PUSH HL; CALL 666Bh */
        repon_abajo(c);
        z(39 + (n > 1 ? 13 : 8));               /* POP HL; LD A,H; ADD A,4; LD H,A; POP BC; DEC C; DJNZ */
        y = (uint8_t)(y + 4); --c;
    }
    z(17);                                      /* CALL 666Bh */
    repon_abajo(c);
    z(7);                                       /* LD C,0, into 666Bh: its RET ends 65FDh */
    repon_abajo(0);
}

/* ---- the text (668Bh) ------------------------------------------------------------------------------ */

static void pagina_nueva(void);

/* 6733h (after its CALL): a delay of 3000, then cursor x += pixels */
static void avanza(uint8_t pixeles)
{
    z(11 + 10 + 17);                            /* PUSH AF; LD BC,0BB8h; CALL 672Ch */
    retardo(0x0BB8);
    z(10 + 16 + 4 + 4 + 16 + 10);               /* POP AF; LD HL,(6770h); ADD A,L; LD L,A; LD (6770h),HL; RET */
    cur_x = (uint8_t)(cur_x + pixeles);
}

/* 6744h (after its CALL): a delay of 60000, the next line; past line A4h the page turns */
static void linea_nueva(void)
{
    z(10 + 17);
    retardo(0xEA60);
    z(7 + 7 + 4 + 4 + 16 + 7);                  /* LD A,10h; LD L,2Ch; ADD A,H; LD H,A; LD (6770h),HL; CP 0A4h */
    cur_y = (uint8_t)(cur_y + 0x10);
    cur_x = 0x2C;
    if (cur_y < 0xA4) { z(11); return; }        /* RET C */
    z(5);
    pagina_nueva();
}

/* 6756h: cursor (2Ch, 10h), three delays of 65536, the page turn */
static void pagina_nueva(void)
{
    unsigned k;
    z(10 + 16 + 7);                             /* LD HL,102Ch; LD (6770h),HL; LD B,3 */
    cur_x = 0x2C; cur_y = 0x10;
    for (k = 3; k; --k) {
        z(11 + 10 + 17);                        /* PUSH BC; LD BC,0; CALL 672Ch */
        retardo(0);
        z(10 + (k > 1 ? 13 : 8));               /* POP BC; DJNZ */
    }
    z(15 + 17);                                 /* PUSH IX; CALL 65FDh */
    pasa_pagina();
    z(14 + 10);                                 /* POP IX; RET */
}

/* 668Bh (after its CALL): the text, glyph by glyph, until space is seen down at a character's start */
static void texto(void)
{
    uint16_t ix = rw(0x6028), tabla = rw(0x66D9), iy;
    uint8_t ch, v, mascara;
    z(7 + 7 + 16);                              /* LD L,2Ch; LD H,10h; LD (6770h),HL */
    cur_x = 0x2C; cur_y = 0x10;
    for (;;) {
        int pulsada;
        z(15 + 17);                             /* 6692h PUSH IX; CALL 605Fh */
        pulsada = teclado_espacio();
        ei();                                   /* 6697h */
        ir(7);                                  /* 6698h LD A,2Fh (after EI) */
        z(17 + 196 + 14);                       /* CALL 60DCh; POP IX */
        if (pulsada) { z(11); return; }         /* RET NZ */
        z(5 + 19 + 7);                          /* LD A,(IX+0); CP 1Ah */
        ch = rb(ix);
        if (ch == 0x1A) { z(12); continue; }    /* the end: space is all that is left */
        z(7 + 10 + 7);                          /* JR Z; INC IX; CP 0Dh */
        ++ix;
        if (ch == 0x0D) { z(7 + 16 + 17); linea_nueva(); z(12); continue; }   /* LD HL,(6770h); CALL 6744h; JR */
        i1(12);                                 /* JR NZ,66B5h */
        ir(7);                                  /* 66B5h CP 20h (the byte before is DDh) */
        if (ch == 0x20) { z(7 + 7 + 17); avanza(0x0A); z(12); continue; }
        z(12 + 7);                              /* JR NZ; CP 0Ah */
        if (ch == 0x0A) { z(7 + 17); pagina_nueva(); z(12); continue; }
        z(12 + 25);                             /* JR NZ; LD C,A; AND 60h; CP 40h; LD A,0FFh */
        if ((ch & 0x60) == 0x40) { z(12); mascara = 0xFF; }   /* capitals in pen 3 */
        else { z(7 + 7); mascara = 0x0F; }                     /* the rest in pen 2 */
        wb(0x6726, mascara);
        z(100 + 30);                            /* 66D4h-66E5h: the glyph's pointer (6772h) */
        iy = rw((uint16_t)(tabla + (uint8_t)((ch - 0x20) * 2)));
        for (;;) {
            uint16_t a;
            uint8_t x, y, k, m;
            z(10 + 17);                         /* 66E7h LD BC,320h; CALL 672Ch */
            retardo(0x0320);
            v = rb(iy++);
            z(19 + 10 + 4 + 7 + 7);             /* LD A,(IY+0); INC IY; LD C,A; AND 0F0h; CP 0F0h */
            if ((v & 0xF0) == 0xF0) { z(7 + 4 + 7 + 17); avanza(v & 0x0F); z(12); break; }
            z(12 + 126 + 233);                  /* 6701h-671Ah, with 682Dh */
            x = (uint8_t)(cur_x + (v & 0x0F));
            y = (uint8_t)(cur_y + (v >> 4));
            k = x & 3;
            a = dir(x, y);
            if (!k) i1(12);                     /* JR Z,6721h */
            else { z(7 + 17u * k - 5 - 8); i1(8); }   /* RRCA; DJNZ: the mask of pixel k */
            m = (uint8_t)(0x88 >> k);
            ir(4);                              /* 6721h LD C,A (the byte before is FDh) */
            z(30);                              /* CPL; AND (HL); LD B,A; LD A,mask; AND C; OR B */
            w(a, (uint8_t)((rscr(a) & ~m) | (mascara & m)), 7);   /* LD (HL),A */
            z(12);                              /* JR 66E7h */
        }
    }
}

/* ---- 6000h ------------------------------------------------------------------------------------------ */

void pergamino(void)
{
    int p;
    z(17 + 22);                                 /* 6000h CALL 6114h; LD HL,610Ah; JR */
    tintas(rw(0x6115));                         /* every ink black */
    di();                                       /* 6003h */
    z(17);                                      /* CALL 604Ch */
    crtc_en_linea(0x6007);                      /* R1 = 40, R2 = 46, R6 = 25 */
    z(7 + 13 + 10 + 16);                        /* 600Eh-6016h: JP 613Fh at 0038h */
    wb(0x0038, 0xC3); ww(0x0039, 0x613F);
    vector_musica = 1;
    z(10 + 13 + 13 + 17 + 14 + 12);             /* 6019h-6022h: the tune, its tempo to 6201h; CALL 61BAh: LD IX; JR */
    di();                                       /* 61CAh */
    z(4 * 19);                                  /* channel A from the start of the tune */
    if (!musica_cargada) {
        musica_inicia(ds + rw(0x601A), (unsigned)(rw(0x601D) - rw(0x601A) + 1), ds + 0x6148);
        musica_cargada = 1;
    } else musica_reinicia();
    ei();                                       /* 61D9h */
    ir(10);                                     /* 61DAh RET */
    di();                                       /* 6025h */
    z(14 + 17 + 15 + 17 + 22);                  /* LD IX,text; CALL 6503h; PUSH IX; CALL 6114h; LD HL; JR */
    tintas(rw(0x6115));
    z(17);                                      /* CALL 6515h */
    en_blanco();
    z(17 + 10);                                 /* CALL 6119h; LD HL,610Fh */
    tintas(rw(0x611A));                         /* the parchment's inks */
    z(14);                                      /* 650Eh POP IX */
    ei();                                       /* 6510h */
    ir(17);                                     /* 6511h CALL 668Bh (after EI) */
    texto();
    z(10);                                      /* 6514h RET */
    for (;;) {                                  /* 602Dh: until space is seen (it is) */
        z(17);
        p = teclado_espacio();
        z(7 + 17 + 196);                        /* LD A,2Fh; CALL 60DCh */
        if (p) break;
        z(12);                                  /* JR Z,602Dh */
    }
    z(7);
    di();                                       /* 6037h */
    z(17);                                      /* CALL 64F1h: the music stops */
    musica_ciclos = 0;
    musica_para();
    z(musica_ciclos);
    z(17 + 22);                                 /* CALL 6114h: every ink black */
    tintas(rw(0x6115));
    z(10 + 4 + 4 + 6);                          /* 603Eh LD HL,0C000h; LD E,L; LD D,H; INC DE */
    w(0xC000, 0, 10);                           /* LD (HL),0 */
    z(10);                                      /* LD BC,3FFFh */
    ldir(0xC000, 0xC001, 0x3FFF);
    z(10);                                      /* RET */
}

/* the game's end (31DAh, after the tape has loaded block 2Ah): CALL 6000h; JR 31DAh, for ever */
void pergamino_final(void)
{
    for (;;) {
        z(17);
        pergamino();
        z(12);
    }
}

/* ---- the tape loader's loading screen ----------------------------------------------------------- */

void pantalla_de_carga(const uint8_t *cargador, const uint8_t *juego, unsigned ms_pantalla, unsigned ms_resto)
{
    unsigned k, n;
    uint64_t t0;
    iff = 0;                                    /* 0133h DI */
    vector_musica = 0;
    plat_modo(0);                               /* 00C6h: OUT 7F8Ch, mode 0 */
    for (k = 0; k < 17; ++k)                    /* pens 16 (the border), 15, ..., 0 from 0103h */
        plat_tinta((uint8_t)(16 - k), cargador[0x0103 + k] & 0x1F);
    plat_crtc(1, 0x20);                         /* 01E9h: 32 x 24 characters */
    plat_crtc(2, 0x2B);
    plat_crtc(6, 0x18);
    /* 0150h: the block 20h from FFFFh down; its screen part, 16384 bytes, at an even pace */
    t0 = perg_t;
    n = 0;
    while (n < 0x4000) {
        uint64_t t = t0 + (uint64_t)(n + 1) * ms_pantalla * 4000u / 0x4000;
        perg_espera(t);
        wscr((uint16_t)(0xFFFF - n), juego[0xFFFF - n]);
        ++n;
    }
    perg_espera(perg_t + (uint64_t)ms_resto * 4000u);
}
