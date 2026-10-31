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

static void escribe(unsigned char reg, unsigned char v)
{
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
        a = BYTE(c->tab_vol + c->i_vol);
        if (a == 0x7F) {
            c->c_vol = c->t_vol = c->n_vol = 0xFF;
            c->d_vol = 0;
            return;
        }
        if (a != 0x80) break;
        c->i_vol = 0;
    }
    if (a & 0x80) {
        env_forma = a & 0x0F;
        env_lo = BYTE(c->tab_vol + c->i_vol + 1);
        env_hi = BYTE(c->tab_vol + c->i_vol + 2);
        c->c_vol = BYTE(c->tab_vol + c->i_vol + 3);
        c->n_vol = 1;
        c->est |= 0x10;
        c->i_vol += 4;
    } else {
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
        a = BYTE(c->tab_tono + c->i_tono);
        if (a == 0x7F) {
            c->c_tono = c->t_tono = c->n_tono = 0xFF;
            c->d_tono = 0;
            return;
        }
        if (a != 0x80) break;
        c->i_tono = 0;
    }
    c->n_tono = a;
    c->d_tono = (signed char)BYTE(c->tab_tono + c->i_tono + 1);
    c->t_tono = c->c_tono = BYTE(c->tab_tono + c->i_tono + 2);
    c->i_tono += 3;
}

/* 63F0h: one tick of the volume envelope */
static void tick_vol(struct canal *c)
{
    if (--c->c_vol) return;
    if (--c->n_vol == 0) siguiente_vol(c);
    c->est |= 0x20;
    c->c_vol = c->t_vol;
    if (c->est & 0x10) return;
    c->vol = (unsigned char)((c->vol + c->d_vol) & 0x0F);
}

/* 62C7h: one tick of a channel */
static void tick_canal(unsigned char n)
{
    struct canal *c = &canales[n];
    unsigned int p;
    unsigned char a, b;
    if (!(c->est & 1)) return;
    c->est &= 0x87;
    if (cuenta == 0 && --c->dur == 0) {
        c->est = 1;
        p = c->ptr;
        for (;;) {                                  /* 62E9h: commands */
            a = BYTE(p);
            if (a < 0xF9 || a > 0xFE) break;
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
        if (a == 0xFF) { c->est = 0; return; }
        b = 1;                                      /* 6311h: a note */
        c->c_tono = c->n_tono = c->c_vol = c->n_vol = b;
        c->i_vol = c->i_tono = 0;
        c->dur = BYTE(p + 1);
        p += 2;
        if (a & 0x80) {
            ruido = BYTE(p);
            c->est |= 0x0A;
            ++p;
        }
        c->vol = 0;
        c->ptr = p;
        c->est |= 0x80;
        if ((a & 0x0F) == 0x0F) return;             /* a rest */
        c->est &= 0x7F;
        c->periodo = periodos[a & 0x0F] >> ((a >> 4) & 7);
    }
    if (c->est & 0x84) return;                      /* 6372h */
    tick_vol(c);
    if (--c->c_tono) return;
    if (--c->n_tono == 0) siguiente_tono(c);
    c->c_tono = c->t_tono;
    c->periodo += c->d_tono;
    c->est |= 0x40;
}

/* 624Bh: the registers of a channel */
static void registros_canal(unsigned char n)
{
    struct canal *c = &canales[n];
    unsigned char l = c->est, a;
    if (!(l & 1) || (l & 0x84)) return;
    if (l & 0x40) {
        escribe(c->reg_tono, (unsigned char)c->periodo);
        escribe(c->reg_tono + 1, (unsigned char)(c->periodo >> 8));
    }
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
    if (!((canales[0].est | canales[1].est | canales[2].est) & 1)) return;
    cuenta = cuenta ? cuenta - 1 : recarga;         /* 61F8h: 11 .. 0 */
    mezclador = 0x3F;
    for (i = 0; i < 3; ++i) tick_canal(i);
    for (i = 0; i < 3; ++i) registros_canal(i);
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
    canales[0].est = canales[1].est = canales[2].est = 0x84;
    escribe(7, 0x3F);
}
