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

/* The music player of the CPC 64 KiB version's first stage (Z80 61BAh-6502h), translated to C.
 *
 * It does what the CPC does on each 300 Hz interrupt (61DBh) and produces the same writes to the
 * sound chip's registers (an AY-3-8912 on the CPC); the platform turns those registers into sound
 * (sid.c on the C64).  Checked tick by tick against the writes logged on the CPC in the simulator
 * (tools/prueba_musica.sh).
 *
 * This copy (juego/) is c64/pergamino/musica.c with the Z80's T-states counted (MT): on a host build
 * musica_ciclos gets what each path costs on the CPC (SkoolKit's timings, the simulator's), so the GNU
 * parchment (pergamino.c) knows how long each interrupt keeps the main program waiting.  The logic is
 * unchanged; on cc65 MT is empty and the file is the C64's.
 *
 * Channel record (IX on the CPC, offsets in brackets):
 *   ptr [0,1]      next byte of the note stream          dur [2]        rows left of the note
 *   periodo [3,4]  tone period                           tab_tono [5,6] pitch table
 *   vol [7]        volume (0-15)                         n_tono [8]     steps left of the pitch entry
 *   i_tono [9]     index in the pitch table              tab_vol [A,B]  volume table
 *   i_vol [C]      index in the volume table             n_vol [D]      steps left of the volume entry
 *   est [E]        bit 0 playing, 1 noise, 2 waiting for its first row, 3 write the noise period,
 *                  4 hardware envelope, 5 write the volume, 6 write the period, 7 rest
 *   t_tono [F]     ticks of a pitch step                 t_vol [10]     ticks of a volume step
 *   c_tono [11]    ticks left of the pitch step          c_vol [12]     ticks left of the volume step
 *   d_tono [13]    pitch step (signed)                   d_vol [14]     volume step
 * plus, before the record on the CPC: the tone register (0, 2, 4), the volume register (8, 9, 10)
 * and the mixer bits of the channel (09, 12, 24 hex).
 * The tables are lists of 3-byte entries (count, step, ticks); 7Fh ends them, 80h starts them again;
 * a volume entry with bit 7 set selects the hardware envelope (shape, period low, period high, ticks).
 * Notes: byte n (bits 0-3 the note, 0Fh = rest; bits 4-6 the octave; bit 7: a noise period follows),
 * the duration in rows, [the noise period].  Commands (61E9h): F9 w = jump, FA w = volume table,
 * FB w = pitch table, FC w = nothing, FD w = start channel C at w, FE w = start channel B at w;
 * FFh ends the channel. */
#include "musica.h"

#ifdef __CC65__
#define MT(n)
#else
unsigned long musica_ciclos;
#define MT(n) (musica_ciclos += (n))
#endif

/* the 12 tone periods of the lowest octave (6197h) */
static const unsigned int periodos[12] = {
    0x0EEE, 0x0E18, 0x0D4D, 0x0C8E, 0x0BDA, 0x0B2F, 0x0A8F, 0x09F7, 0x0968, 0x08E1, 0x0861, 0x07E9
};

struct canal {
    unsigned int ptr, periodo, tab_tono, tab_vol;
    unsigned char dur, vol, n_tono, i_tono, i_vol, n_vol, est;
    unsigned char t_tono, t_vol, c_tono, c_vol;
    signed char d_tono, d_vol;
    unsigned char reg_tono, reg_vol, mezcla;
};

static struct canal canales[3];
static const unsigned char *datos;          /* the music; its addresses are CPC addresses from 8000h */
static unsigned char cuenta, recarga;       /* 614Ah, and the tempo patched at 6201h */
static unsigned char mezclador, mezclador_escrito;   /* 6148h, 6149h */
static unsigned char env_lo, env_hi, env_forma, ruido;   /* 614Bh, 614Ch, 614Dh, 614Eh */

unsigned char ay[16];                       /* the chip's registers as written */
unsigned char ay_cambio;                    /* bit r: register r written in this tick (r < 14) */

/* 64C9h (its CALL is counted by the caller) */
static void escribe(unsigned char reg, unsigned char v)
{
    MT(147);
    ay[reg] = v;
    ay_cambio |= (unsigned int)1 << reg;
    musica_registro(reg, v);
}

#define BYTE(a) datos[(unsigned int)(a) - 0x8000]

static void arranca(unsigned char n, unsigned int ptr)
{
    canales[n].est = 5;
    canales[n].ptr = ptr;
    canales[n].dur = 1;
}

/* estado: the player's bytes 6148h-6199h as the first stage's image holds them (channel B is
 * left playing by the image: its stale record matters on the first ticks) */
void musica_inicia(const unsigned char *musica, unsigned int longitud, const unsigned char *estado)
{
    unsigned char i;
    const unsigned char *r;
    datos = musica;
    mezclador = estado[0];                      /* 6148h */
    mezclador_escrito = estado[1];              /* 6149h */
    cuenta = estado[2];                         /* 614Ah */
    env_lo = estado[3]; env_hi = estado[4]; env_forma = estado[5]; ruido = estado[6];
    for (i = 0; i < 3; ++i) {
        r = estado + 0x0A + i * 0x18;           /* IX = 6152h, 616Ah, 6182h */
        canales[i].reg_tono = r[-3];
        canales[i].reg_vol = r[-2];
        canales[i].mezcla = r[-1];
        canales[i].ptr = r[0] | (unsigned int)r[1] << 8;
        canales[i].dur = r[2];
        canales[i].periodo = r[3] | (unsigned int)r[4] << 8;
        canales[i].tab_tono = r[5] | (unsigned int)r[6] << 8;
        canales[i].vol = r[7];
        canales[i].n_tono = r[8];
        canales[i].i_tono = r[9];
        canales[i].tab_vol = r[0x0A] | (unsigned int)r[0x0B] << 8;
        canales[i].i_vol = r[0x0C];
        canales[i].n_vol = r[0x0D];
        canales[i].est = r[0x0E];
        canales[i].t_tono = r[0x0F];
        canales[i].t_vol = r[0x10];
        canales[i].c_tono = r[0x11];
        canales[i].c_vol = r[0x12];
        canales[i].d_tono = (signed char)r[0x13];
        canales[i].d_vol = (signed char)r[0x14];
    }
    recarga = musica[longitud - 1];             /* (83FFh) -> 6201h */
    arranca(0, 0x8000);                         /* 61BAh with HL = 8000h */
}

/* 6416h: the next entry of the volume table */
static void siguiente_vol(struct canal *c)
{
    unsigned char a;
    for (;;) {
        MT(118);                                /* 6416h-6423h */
        a = BYTE(c->tab_vol + c->i_vol);
        if (a == 0x7F) {
            MT(100);                            /* 6425h-6436h */
            c->c_vol = c->t_vol = c->n_vol = 0xFF;
            c->d_vol = 0;
            return;
        }
        if (a != 0x80) break;
        MT(61);                                 /* 6425h-643Fh */
        c->i_vol = 0;
    }
    MT(39);                                     /* 6425h, 6437h, 6439h, 6441h */
    if (a & 0x80) {
        MT(220);                                /* 6443h-6466h, 647Dh-6480h */
        env_forma = a & 0x0F;
        env_lo = BYTE(c->tab_vol + c->i_vol + 1);
        env_hi = BYTE(c->tab_vol + c->i_vol + 2);
        c->c_vol = BYTE(c->tab_vol + c->i_vol + 3);
        c->n_vol = 1;
        c->est |= 0x10;
        c->i_vol += 4;
    } else {
        MT(169);                                /* 6443h, 6468h-6480h */
        c->n_vol = a;
        c->d_vol = (signed char)BYTE(c->tab_vol + c->i_vol + 1);
        c->t_vol = c->c_vol = BYTE(c->tab_vol + c->i_vol + 2);
        c->i_vol += 3;
    }
}

/* 63ACh: the next entry of the pitch table */
static void siguiente_tono(struct canal *c)
{
    unsigned char a;
    for (;;) {
        MT(118);                                /* 63ACh-63B9h */
        a = BYTE(c->tab_tono + c->i_tono);
        if (a == 0x7F) {
            MT(100);                            /* 63BBh-63CCh */
            c->c_tono = c->t_tono = c->n_tono = 0xFF;
            c->d_tono = 0;
            return;
        }
        if (a != 0x80) break;
        MT(61);                                 /* 63BBh-63D5h */
        c->i_tono = 0;
    }
    MT(188);                                    /* 63BBh, 63CDh, 63CFh, 63D7h-63EFh */
    c->n_tono = a;
    c->d_tono = (signed char)BYTE(c->tab_tono + c->i_tono + 1);
    c->t_tono = c->c_tono = BYTE(c->tab_tono + c->i_tono + 2);
    c->i_tono += 3;
}

/* 63F0h: one tick of the volume envelope */
static void tick_vol(struct canal *c)
{
    MT(23);                                     /* 63F0h */
    if (--c->c_vol) { MT(11); return; }
    MT(28 + (c->n_vol == 1 ? 17 : 10));         /* 63F3h, 63F4h, 63F7h */
    if (--c->n_vol == 0) siguiente_vol(c);
    c->est |= 0x20;
    c->c_vol = c->t_vol;
    MT(81);                                     /* 63FAh-6404h */
    if (c->est & 0x10) { MT(11); return; }
    MT(83);                                     /* 6408h-6415h */
    c->vol = (unsigned char)((c->vol + c->d_vol) & 0x0F);
}

#ifndef __CC65__
/* the command table of 6481h, in its order: the index costs 57 T-states a step */
static const unsigned char orden[6] = { 0xFE, 0xFD, 0xFB, 0xFC, 0xFA, 0xF9 };
static const unsigned char coste_orden[6] = { 70, 70, 48, 10, 48, 18 };   /* the handlers with their RET */
#endif

/* 62C7h: one tick of a channel */
static void tick_canal(unsigned char n)
{
    struct canal *c = &canales[n];
    unsigned int p;
    unsigned char a, b;
#ifndef __CC65__
    unsigned char j;
#endif
    MT(27);                                         /* 62C7h, 62CAh */
    if (!(c->est & 1)) { MT(11); return; }
    MT(58 + (cuenta == 0 ? 33 : 0));                /* 62CCh-62D6h (62D9h, 62DCh) */
    c->est &= 0x87;
    if (cuenta == 0 && --c->dur == 0) {
        MT(57);                                 /* 62DFh-62E6h */
        c->est = 1;
        p = c->ptr;
        for (;;) {                              /* 62E9h: commands */
            a = BYTE(p);
#ifdef __CC65__
            if (a < 0xF9 || a > 0xFE) break;
#else
            for (j = 0; j < 6 && orden[j] != a; ++j) ;
            if (j == 6) { MT(17 + 337); break; }    /* 62E9h-62EBh, 62EEh-6306h six times */
            MT(17 + 57u * j + 116 + coste_orden[j]);
#endif
            p += 3;
            switch (a) {
            case 0xF9: p = BYTE(p - 2) | (unsigned int)BYTE(p - 1) << 8; break;
            case 0xFA: c->tab_vol = BYTE(p - 2) | (unsigned int)BYTE(p - 1) << 8; break;
            case 0xFB: c->tab_tono = BYTE(p - 2) | (unsigned int)BYTE(p - 1) << 8; break;
            case 0xFC: break;
            case 0xFD: arranca(2, BYTE(p - 2) | (unsigned int)BYTE(p - 1) << 8); break;
            case 0xFE: arranca(1, BYTE(p - 2) | (unsigned int)BYTE(p - 1) << 8); break;
            }
        }
        MT(7);                                  /* 6308h */
        if (a == 0xFF) { MT(36); c->est = 0; return; }
        MT(12 + 182 + (a & 0x80 ? 79 : 12));    /* 630Ah, 6311h-632Eh, 6330h(-633Eh) */
        b = 1;                                  /* 6311h: a note */
        c->c_tono = c->n_tono = c->c_vol = c->n_vol = b;
        c->i_vol = c->i_tono = 0;
        c->dur = BYTE(p + 1);
        p += 2;
        if (a & 0x80) {
            ruido = BYTE(p);
            c->est |= 0x0A;
            ++p;
        }
        MT(98);                                 /* 633Fh-6350h */
        c->vol = 0;
        c->ptr = p;
        c->est |= 0x80;
        if ((a & 0x0F) == 0x0F) { MT(11); return; }   /* a rest */
        MT(140 + 21 + ((a >> 4) & 7 ? 10 + 32u * ((a >> 4) & 7) : 11) + 38);   /* 6352h-6369h, 64E7h-64F0h, 636Ch-636Fh */
        c->est &= 0x7F;
        c->periodo = periodos[a & 0x0F] >> ((a >> 4) & 7);
    }
    MT(c->est & 0x80 ? 31 : c->est & 0x04 ? 56 : 67);   /* 6372h-637Bh, CALL 63F0h */
    if (c->est & 0x84) return;                      /* 6372h */
    tick_vol(c);
    MT(23);                                         /* 637Fh */
    if (--c->c_tono) { MT(11); return; }
    MT(28 + (c->n_tono == 1 ? 17 : 10));            /* 6382h, 6383h, 6386h */
    if (--c->n_tono == 0) siguiente_tono(c);
    c->c_tono = c->t_tono;
    MT(72 + (c->d_tono < 0 ? 11 : 12) + 124);       /* 6389h-63ABh */
    c->periodo += c->d_tono;
    c->est |= 0x40;
}

/* 624Bh: the registers of a channel */
static void registros_canal(unsigned char n)
{
    struct canal *c = &canales[n];
    unsigned char l = c->est, a;
    MT(!(l & 1) ? 38 : l & 0x04 ? 51 : l & 0x80 ? 64 : 66);   /* 624Bh-6257h */
    if (!(l & 1) || (l & 0x84)) return;
    MT(l & 0x40 ? 7 + 114 : 12);                    /* 6259h(-626Dh) */
    if (l & 0x40) {
        escribe(c->reg_tono, (unsigned char)c->periodo);
        escribe(c->reg_tono + 1, (unsigned char)(c->periodo >> 8));
    }
    MT(8 + (l & 0x20 ? 15 + (l & 0x10 ? 12 + 166 : 7 + 67) : 12));   /* 626Eh-62A1h */
    if (l & 0x20) {
        if (!(l & 0x10)) {
            escribe(c->reg_vol, c->vol);
        } else {
            escribe(11, env_lo);
            escribe(12, env_hi);
            escribe(13, env_forma);
            escribe(c->reg_vol, 0x10);
        }
    }
    MT(15 + (l & 0x02 ? 22 + (l & 0x08 ? 7 + 48 : 12) : 12) + 63);   /* 62A4h-62C6h */
    a = 7;
    if (l & 0x02) {
        a = 0x3F;
        if (l & 0x08) {
            escribe(6, ruido);
            a = 0x3F;
        }
    }
    mezclador ^= (unsigned char)(a & c->mezcla);
}

/* 61DBh: one 300 Hz tick */
void musica_tick(void)
{
    unsigned char i;
    ay_cambio = 0;
    MT(88);                                         /* 61DBh-61EBh */
    if (!((canales[0].est | canales[1].est | canales[2].est) & 1)) { MT(7 + 38); return; }   /* 61EDh-61F2h */
    MT(12 + 61 + (cuenta ? 12 : 14) + 33 + 6 * 31);   /* 61EDh-6231h but the channels' calls */
    cuenta = cuenta ? cuenta - 1 : recarga;         /* 61F8h: 11 .. 0 */
    mezclador = 0x3F;
    for (i = 0; i < 3; ++i) tick_canal(i);
    for (i = 0; i < 3; ++i) registros_canal(i);
    MT(24 + (mezclador != mezclador_escrito ? 7 + 24 + 17 : 12) + 44 + 38);   /* 6234h-6248h, 61EFh-61F2h */
    if (mezclador != mezclador_escrito) {
        mezclador_escrito = mezclador;
        escribe(7, mezclador);
    }
}

/* 64F1h: silence */
/* 6019h-6022h when the parchment is entered again (the ending is shown over and over): channel A from
 * the start of the music; the tempo (6201h) is unchanged and the other channels keep what musica_para
 * left, as on the CPC */
void musica_reinicia(void)
{
    arranca(0, 0x8000);
}

void musica_para(void)
{
    MT(70);                                         /* 64F1h-6500h */
    canales[0].est = canales[1].est = canales[2].est = 0x84;
    escribe(7, 0x3F);
}
