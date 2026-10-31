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

/* abadia64ks: the 6502 code of the game checked in shadow (c64/CODIGO6502.md, c64/NOTAS_MAPA.md).
 *
 * c64/juego/construye.sh builds juego.bin (the 64 KiB C64 image from $0000: the data at their map addresses,
 * the code from $0800) and juego.lbl (the routines' addresses); mapa64.tsv says where each block of the CPC
 * memory lives on the C64 and how it is checked; punteros64.tsv lists the pointer fields inside the blocks;
 * resultados.tsv what each routine must leave as the Z80 does.  For a call of a translated function that has
 * a 6502 routine of the same name, the host gives this file the entry state (registers and RAM) and the Z80's
 * result: the blocks are copied into the 6502's memory (pointer fields relocated CPC -> C64, graphics converted),
 * the zero-page registers and A set, the routine run until its RTS, and the blocks and declared registers
 * compared with the Z80's (the Z80's result relocated and converted the same way).
 *
 * Block modes (mapa64.tsv): copia = copied and compared, pointer fields relocated; graf = a graphic the game
 * flips in place, converted from the CPC memory (conversion64.tsv) and compared converted; conv = a C64-format
 * constant of the image, compared with the image (it must not change); nada = neither (C64-format buffers).
 * Pointer relocation (punteros64.tsv): 0000h stays; tagC0 values C0xxh stay; bit14 keeps bit 14 as a flag; class
 * pila is not relocated nor compared (Z80 stack addresses); code -> the 6502 routine of the same Z80 entry
 * (juego.lbl, names of the C translation) when it exists; gfx -> the frame of data/c64graf/marcos64.tsv
 * (inside a frame: line * ceil(w/2) + byte / 2); var or a block list -> the block holding the value (virtual:
 * up to 20h before the block); else the value stays.  Comparisons are made in the C64 form: the Z80's result
 * relocated must equal the 6502's.  resultados.tsv: "!BLOCK" leaves a block out of a routine's comparison;
 * ">REG:target" relocates a register pair (BC DE HL IX IY) that holds a pointer at the entry, "REG:target" compares
 * it relocated at the exit (targets as in punteros64.tsv). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../juego.h"
#include "m6502.h"
#include "memory.h"
#include "peripherals.h"

#define ZBC 0x02
#define ZDE 0x04
#define ZHL 0x06
#define ZIX 0x08
#define ZIY 0x0A

typedef struct {
    char nombre[64];
    int cpc;                                  /* -1: a C64-only block */
    uint16_t len, c64, len64;
    char modo;                                /* c copia, g graf, v conv, n nada */
} bloque_t;
static bloque_t bloques[512];
static int nbloques;

enum { D_LISTA, D_CODE, D_GFX, D_VAR, D_PILA };
typedef struct {
    uint16_t campo;
    int bloque, clase, lista[8], nlista;
    char marca;                               /* - , b bit14, v virtual, t tagC0, h held (a pointer when bit 7 of field - 2) */
} campo_t;
static campo_t campos[1024];
static int ncampos;
static int16_t campo_de[0x10000];           /* CPC address of a field byte -> field + 1 */
static int16_t datos_de[0x10000];           /* CPC address -> non-graphic block + 1 */
static uint16_t gfx_c64[0x10000];           /* CPC value -> C64 address inside a converted graphic, 0 none */
static uint16_t codigo_c64[0x10000];        /* Z80 entry -> 6502 routine, 0 none */
static uint16_t codigo_z80[0x10000];        /* 6502 routine or stub -> Z80 entry, 0 none */
static uint16_t gfx_cpc[0x10000];           /* C64 address inside a converted graphic -> CPC value, 0 none */
static int16_t bloque_c64_de[0x10000];      /* C64 address -> copia block + 1 */

typedef struct { int bloque; uint16_t cpc, h, off, unidad; uint8_t w; } subgraf_t;   /* unidad: lines flipped as one */
typedef struct { int bloque; uint16_t cpc; unsigned w, h, off; } marco_t;      /* PANTALLA:doble: the sprite frames */
static marco_t marcos[512];
static int nmarcos;
static subgraf_t subgrafs[64];
static int nsubgrafs;
static uint8_t nib[256];                    /* CPC mode 1 byte -> C64 nibble (rule sim of c64_graficos.py) */
static uint8_t nib_der[256], nib_izq[256];  /* rules der (the right pixel of each pair) and izq (the left one) */
static uint8_t hw_c64[32];                  /* CPC hardware colour -> C64 colour (c64/datos/paleta.tsv): the inks' mirror */

/* a register pair that holds a pointer: relocated at the entry (>REG:target) or compared relocated (REG:target) */
typedef struct { int reg; campo_t destino; } regpunt_t;
enum { P_BC, P_DE, P_HL, P_IX, P_IY };
typedef struct {
    char nombre[64]; uint16_t dir; unsigned resultados; int excl[16], nexcl;
    regpunt_t entra[8], sale[8]; int nentra, nsale;
    int stub, pantalla;                       /* a stub (stubs64.tsv: a trap); PANTALLA: the screen compared */
    int linea;                                /* INLINE: a helper that reads the bytes after its call (RST 08h/10h) */
    char regla;                               /* PANTALLA:rule: s sim (default), d der, i izq, p par (any pair rule), f fuente */
    int hl_linea_entra, hl_linea_sale;        /* >HL:INLINE / HL:INLINE: HL points to bytes of the Z80 code */
    unsigned long long ciclos, llamadas;      /* the 6502 cycles spent (traps included), the calls */
} rutina_t;
static rutina_t rutinas[4096];
static int nrutinas;

enum { R_A = 1, R_B = 2, R_C = 4, R_D = 8, R_E = 16, R_H = 32, R_L = 64, R_IXH = 128, R_IXL = 256,
       R_IYH = 512, R_IYL = 1024, R_CF = 2048, R_ZF = 4096, R_A2 = 8192, R_BC2 = 16384, R_DE2 = 32768, R_HL2 = 65536 };

static uint8_t imagen[0x10000];             /* juego.bin as linked (code and C64-format data) */
static uint8_t antes[0x10000];              /* the 6502 memory as the call starts */
static uint8_t esperado[0x10000];           /* the Z80's result in C64 form */
unsigned long llamadas_6502, fallos_6502;
static unsigned long trampas;               /* traps run (stubs of functions not translated yet) */
static int max_fallos_6502 = 20;

static FILE *abre(const char *dir, const char *rel)
{
    char p[1024];
    FILE *f;
    snprintf(p, sizeof p, "%s/%s", dir, rel);
    if (!(f = fopen(p, "rb"))) { fprintf(stderr, "cannot read %s\n", p); exit(1); }
    return f;
}

static const char *dir_6502_ruta(const char *dir, const char *rel)
{
    static char p[1024];
    snprintf(p, sizeof p, "%s/%s", dir, rel);
    return p;
}

static int bloque_por_nombre(const char *n)
{
    int i;
    for (i = 0; i < nbloques; ++i) if (!strcmp(bloques[i].nombre, n)) return i;
    fprintf(stderr, "sombra6502: no block %s in mapa64.tsv\n", n);
    exit(2);
}

static unsigned resultados_de(const char *t)
{
    static const struct { const char *n; unsigned m; } tabla[] = {
        { "A", R_A }, { "B", R_B }, { "C", R_C }, { "D", R_D }, { "E", R_E }, { "H", R_H }, { "L", R_L },
        { "BC", R_B | R_C }, { "DE", R_D | R_E }, { "HL", R_H | R_L }, { "IX", R_IXH | R_IXL },
        { "IY", R_IYH | R_IYL }, { "IXH", R_IXH }, { "IXL", R_IXL }, { "IYH", R_IYH }, { "IYL", R_IYL },
        { "CF", R_CF }, { "ZF", R_ZF }, { "A2", R_A2 }, { "BC2", R_BC2 }, { "DE2", R_DE2 }, { "HL2", R_HL2 } };
    unsigned i;
    for (i = 0; i < sizeof tabla / sizeof tabla[0]; ++i) if (!strcmp(t, tabla[i].n)) return tabla[i].m;
    fprintf(stderr, "resultados.tsv: unknown result %s\n", t);
    exit(2);
}

/* the CPC byte -> nibble of the sprites' rule: each pixel pair keeps the pen first in 1, 2, 3, 0; pen -> bits
 * 3:00 0:01 1:10 2:11 */
static void tabla_nibbles(void)
{
    static const uint8_t bits[4] = { 1, 2, 3, 0 }, prio[4] = { 3, 0, 1, 2 };
    unsigned b, i;
    for (b = 0; b < 256; ++b) {
        uint8_t p[4], q[2];
        for (i = 0; i < 4; ++i) p[i] = (uint8_t)(((b >> (7 - i)) & 1) | (((b >> (3 - i)) & 1) << 1));
        for (i = 0; i < 2; ++i) {
            uint8_t a = p[2 * i], c = p[2 * i + 1];
            q[i] = a == c ? a : prio[a] < prio[c] ? a : c;
        }
        nib[b] = (uint8_t)(bits[q[0]] << 2 | bits[q[1]]);
        nib_der[b] = (uint8_t)(bits[p[1]] << 2 | bits[p[3]]);
        nib_izq[b] = (uint8_t)(bits[p[0]] << 2 | bits[p[2]]);
    }
}

/* rule par: the C64 nibble n is a valid half of the CPC byte b when each of its two pixels is the pen of
 * one of the two CPC pixels it stands for (any rule: sim, der, izq, detalle, a merge of tile and sprite) */
static int nibble_valido(uint8_t n, uint8_t b)
{
    static const uint8_t bits[4] = { 1, 2, 3, 0 };
    unsigned i;
    for (i = 0; i < 2; ++i) {
        uint8_t a = (uint8_t)(((b >> (7 - 2 * i)) & 1) | (((b >> (3 - 2 * i)) & 1) << 1));
        uint8_t c = (uint8_t)(((b >> (6 - 2 * i)) & 1) | (((b >> (2 - 2 * i)) & 1) << 1));
        uint8_t v = (uint8_t)((n >> (2 - 2 * i)) & 3);
        if (v != bits[a] && v != bits[c]) return 0;
    }
    return 1;
}

/* rule fuente (the text of txt_draw_char): par, plus the CPC byte -> C64 nibble pairs of the C64 font's own
 * glyphs (the hand-made N and ';' of c64_graficos.py fuente_der follow no pair rule): each row of the CPC font
 * (B400h + 8 (c - 2Dh), drawn as (g AND F0h) XOR m and (g << 4) XOR m, m = 0Fh or FFh) against the same row of
 * data/c64graf/fuente.bin (4 bytes a glyph, a nibble a row, bit 3 the left pixel; drawn with a set pixel 00 and
 * a clear one 11, XOR FFh when inverted): fuente_extra[b] has bit n set when nibble n may stand for CPC byte b */
static uint16_t fuente_extra[256];
static void tabla_fuente(const uint8_t *cpc, const char *dir)
{
    uint8_t fu[184];
    FILE *f = abre(dir, "../../../data/c64graf/fuente.bin");
    unsigned c, r, k, m;
    if (fread(fu, 1, sizeof fu, f) != sizeof fu) { fprintf(stderr, "sombra6502: fuente.bin is short\n"); exit(2); }
    fclose(f);
    for (c = 0; c < 46; ++c)
        for (r = 0; r < 8; ++r) {
            uint8_t g = cpc[0xB400 + 8 * c + r], n = (uint8_t)(r & 1 ? fu[4 * c + r / 2] & 15 : fu[4 * c + r / 2] >> 4), v = 0;
            for (k = 0; k < 4; ++k) v = (uint8_t)(v << 2 | (((n >> (3 - k)) & 1) ? 0 : 3));
            for (m = 0; m < 2; ++m) {
                uint8_t x = m ? 0xFF : 0x0F, w = (uint8_t)(m ? v ^ 0xFF : v);
                fuente_extra[(uint8_t)((g & 0xF0) ^ x)] |= (uint16_t)(1u << (w >> 4));
                fuente_extra[(uint8_t)((uint8_t)(g << 4) ^ x)] |= (uint16_t)(1u << (w & 15));
            }
        }
}

/* the graphic block k of the CPC memory `ram` in its C64 form, into dst (a 64 KiB image) */
/* the graphics the game flips in place, in their C64 form: c64_graficos.py makes them (its pair rules and the hand
 * retouches of c64/datos/retoques64.txt), so they are not a function of the CPC bytes; each unit the game flips as
 * one is found as the tape's (the image's bytes), or mirrored (the image's bytes flipped as the 6502's
 * spr_flip_graphics_h does: the nibbles of a line reversed, each nibble's two pixels swapped, the padding nibble of
 * an odd width kept last); a unit in neither state (never seen) by the rule sim, byte by byte */
static uint8_t cinta_ref[0x10000];         /* the tape image at the game's start: the graphics as the image holds them */
static uint8_t espejo_cpc[256];             /* a CPC mode 1 byte with its 4 pixels reversed */

static void convierte(int k, const uint8_t *ram, uint8_t *dst)
{
    int s;
    for (s = 0; s < nsubgrafs; ++s) {
        const subgraf_t *g = &subgrafs[s];
        unsigned bpr = (g->w + 1u) / 2u, l, x, u0;
        if (g->bloque != k) continue;
        for (u0 = 0; u0 < g->h; u0 += g->unidad) {
            unsigned n = g->unidad < g->h - u0 ? g->unidad : g->h - u0, igual = 1, espejo = 1;
            uint16_t c0 = (uint16_t)(g->cpc + u0 * g->w), d0 = (uint16_t)(bloques[k].c64 + g->off + u0 * bpr);
            for (l = 0; l < n && (igual || espejo); ++l)
                for (x = 0; x < g->w; ++x) {
                    uint8_t v = ram[(uint16_t)(c0 + l * g->w + x)];
                    if (v != cinta_ref[(uint16_t)(c0 + l * g->w + x)]) igual = 0;
                    if (v != espejo_cpc[cinta_ref[(uint16_t)(c0 + l * g->w + g->w - 1 - x)]]) espejo = 0;
                }
            for (l = 0; l < n; ++l) {
                uint8_t nb[16];
                unsigned m;
                for (m = 0; m < g->w; ++m) {
                    if (igual || espejo) {
                        unsigned q = espejo && !igual ? g->w - 1 - m : m;
                        uint8_t b = imagen[(uint16_t)(d0 + l * bpr + q / 2)], v = q & 1 ? (uint8_t)(b & 15) : (uint8_t)(b >> 4);
                        nb[m] = espejo && !igual ? (uint8_t)((v & 3) << 2 | v >> 2) : v;
                    }
                    else nb[m] = nib[ram[(uint16_t)(c0 + l * g->w + m)]];
                }
                if (g->w & 1) nb[g->w] = 0x5;
                for (x = 0; x < bpr; ++x) dst[(uint16_t)(d0 + l * bpr + x)] = (uint8_t)(nb[2 * x] << 4 | nb[2 * x + 1]);
            }
        }
    }
}

static uint16_t reubica(const campo_t *c, uint16_t v)
{
    uint16_t f = 0;
    int b, i;
    if (v == 0) return 0;
    if (c->marca == 't' && (v >> 8) == 0xC0) return v;
    if (c->marca == 'b') { f = v & 0x4000; v &= (uint16_t)~0x4000; }
    switch (c->clase) {
    case D_PILA: return (uint16_t)(v | f);
    case D_CODE: return codigo_c64[v] ? codigo_c64[v] : v;
    case D_GFX: return (uint16_t)((gfx_c64[v] ? gfx_c64[v] : v) | f);
    case D_VAR:
        b = datos_de[v] - 1;
        return (uint16_t)((b >= 0 ? bloques[b].c64 + v - bloques[b].cpc : v) | f);
    default:
        b = datos_de[v] - 1;
        for (i = 0; i < c->nlista; ++i)
            if (b == c->lista[i]) return (uint16_t)((bloques[b].c64 + v - bloques[b].cpc) | f);
        if (c->marca == 'r' && v >= 0x7F80 && v < 0xA000)   /* region: shifted as the first target block */
            return (uint16_t)(v + bloques[c->lista[0]].c64 - bloques[c->lista[0]].cpc);
        if (c->marca == 'f')                   /* one past the end of a target block */
            for (i = 0; i < c->nlista; ++i)
                if (v == bloques[c->lista[i]].cpc + bloques[c->lista[i]].len)
                    return (uint16_t)(bloques[c->lista[i]].c64 + bloques[c->lista[i]].len64);
        b = c->lista[0];
        if (c->marca == 'v' && v < bloques[b].cpc && v + 0x20 >= bloques[b].cpc)
            return (uint16_t)(bloques[b].c64 + v - bloques[b].cpc);
        return (uint16_t)(v | f);
    }
}

/* a target of punteros64.tsv (code, gfx, var, pila, block[|block...]) into c */
static void destino_de(char *dest, campo_t *c)
{
    char *t;
    c->nlista = 0;
    if (!strcmp(dest, "code")) c->clase = D_CODE;
    else if (!strcmp(dest, "gfx")) c->clase = D_GFX;
    else if (!strcmp(dest, "var")) c->clase = D_VAR;
    else if (!strcmp(dest, "pila")) c->clase = D_PILA;
    else {
        c->clase = D_LISTA;
        for (t = strtok(dest, "|"); t && c->nlista < 8; t = strtok(NULL, "|")) c->lista[c->nlista++] = bloque_por_nombre(t);
    }
}

static int par_de(const char *t)
{
    static const char *n[] = { "BC", "DE", "HL", "IX", "IY" };
    int i;
    for (i = 0; i < 5; ++i) if (!strncmp(t, n[i], 2) && t[2] == ':') return i;
    return -1;
}

/* reads c64/juego: juego.bin, juego.lbl, mapa64.tsv, punteros64.tsv, conversion64.tsv, resultados.tsv, and
 * data/c64graf/marcos64.tsv, data/cpc64/juego/ram.bin (a self-check of the graphics conversion) */
void sombra6502_carga(const char *dir)
{
    char l[1024];
    FILE *f;
    size_t n;
    int i, k;
    f = abre(dir, "juego.bin");
    n = fread(imagen, 1, sizeof imagen, f);
    fclose(f);
    if (n != 0x10000) { fprintf(stderr, "juego.bin: %zu bytes, the 64 KiB image expected (c64/juego/construye.sh)\n", n); exit(1); }
    /* the map */
    f = abre(dir, "mapa64.tsv");
    while (fgets(l, sizeof l, f)) {
        char nombre[64], cpc[16], modo[16], zona[16], tipo[16];
        unsigned len, c64, len64;
        bloque_t *b = &bloques[nbloques];
        if (l[0] == '#' || sscanf(l, "%63s %15s %u %x %u %15s %15s %15s", nombre, cpc, &len, &c64, &len64, modo, zona, tipo) != 8) continue;
        snprintf(b->nombre, sizeof b->nombre, "%s", nombre);
        b->cpc = cpc[0] == '-' ? -1 : (int)strtol(cpc, NULL, 16);
        b->len = (uint16_t)len; b->c64 = (uint16_t)c64; b->len64 = (uint16_t)len64;
        b->modo = !strcmp(modo, "copia") ? 'c' : !strcmp(modo, "graf") ? 'g' : !strcmp(modo, "conv") ? 'v' : 'n';
        if (!strcmp(zona, "bitmap")) b->modo = 'n';       /* the score bar: drawn into the bitmap */
        if (b->cpc >= 0 && strcmp(tipo, "graf"))
            for (k = 0; k < (int)len; ++k) datos_de[b->cpc + k] = (int16_t)(nbloques + 1);
        ++nbloques;
    }
    fclose(f);
    /* the 6502 routines and the code map (the names of the C translation) */
    f = abre(dir, "juego.lbl");
    while (fgets(l, sizeof l, f)) {
        unsigned a; char nombre[64];
        const traducida_t *const *g;
        const traducida_t *t;
        if (sscanf(l, "al %x .%63s", &a, nombre) != 2) continue;
        if (nrutinas == (int)(sizeof rutinas / sizeof rutinas[0])) { fprintf(stderr, "juego.lbl: too many labels\n"); exit(2); }
        snprintf(rutinas[nrutinas].nombre, sizeof rutinas[nrutinas].nombre, "%s", nombre);
        rutinas[nrutinas].dir = (uint16_t)a;
        ++nrutinas;
        for (g = grupos; *g; ++g)
            for (t = *g; t->nombre; ++t)
                if (!strcmp(t->nombre, nombre)) { codigo_c64[t->dir] = (uint16_t)a; codigo_z80[a] = t->dir; }
    }
    fclose(f);
    /* the stubs: names that stand for functions not translated yet (a trap runs the Z80 original) */
    f = fopen(dir_6502_ruta(dir, "stubs64.tsv"), "r");
    if (f) {
        while (fgets(l, sizeof l, f)) {
            char nombre[64]; unsigned z;
            if (l[0] == '#' || sscanf(l, "%63s %x", nombre, &z) != 2) continue;
            for (i = 0; i < nrutinas; ++i)
                if (!strcmp(rutinas[i].nombre, nombre)) { rutinas[i].stub = 1; codigo_c64[z] = rutinas[i].dir; codigo_z80[rutinas[i].dir] = (uint16_t)z; }
        }
        fclose(f);
    }
    /* the graphics: frames (marcos64.tsv) and the layout of the ones flipped in place (conversion64.tsv) */
    tabla_nibbles();
    f = abre(dir, "../datos/paleta.tsv");                        /* CPC hardware colour -> C64 colour */
    while (fgets(l, sizeof l, f)) {
        unsigned hw, c;
        char rgb[32];
        if (l[0] == '#' || sscanf(l, "%x %31s %u", &hw, rgb, &c) != 3) continue;
        hw_c64[hw & 31] = (uint8_t)c;
    }
    fclose(f);
    f = abre(dir, "../../../data/c64graf/marcos64.tsv");
    while (fgets(l, sizeof l, f)) {
        char blk[64]; unsigned cpc, w, h, off, v;
        if (l[0] == '#' || sscanf(l, "%63s %x %u %u %u", blk, &cpc, &w, &h, &off) != 5) continue;
        k = bloque_por_nombre(blk);
        if ((!strcmp(blk, "baldosas") || !strcmp(blk, "caras") || !strcmp(blk, "habitos") || !strcmp(blk, "personajes")
             || !strcmp(blk, "puerta")) && nmarcos < 512) {
            marcos[nmarcos].bloque = k; marcos[nmarcos].cpc = (uint16_t)cpc;
            marcos[nmarcos].w = w; marcos[nmarcos].h = h; marcos[nmarcos].off = off; ++nmarcos;
        }
        if (!gfx_c64[cpc]) gfx_c64[cpc] = (uint16_t)(bloques[k].c64 + off);
        for (v = 0; v < w * h; ++v)
            if (!gfx_c64[(uint16_t)(cpc + v)])
                gfx_c64[(uint16_t)(cpc + v)] = (uint16_t)(bloques[k].c64 + off + v / w * ((w + 1) / 2) + v % w / 2);
    }
    fclose(f);
    k = bloque_por_nombre("D64_ISO_MIRROR_BUF_GUILLERMO");          /* the mirror images: the CPC layout kept */
    for (i = 0; i < bloques[k].len; ++i) gfx_c64[bloques[k].cpc + i] = (uint16_t)(bloques[k].c64 + i);
    for (i = 0xFFFF; i > 0; --i)                                     /* the inverse: the lowest CPC value wins */
        if (gfx_c64[i]) gfx_cpc[gfx_c64[i]] = (uint16_t)i;
    for (k = 0; k < nbloques; ++k)
        if (bloques[k].cpc >= 0 && bloques[k].modo == 'c')
            for (i = 0; i < bloques[k].len64; ++i) bloque_c64_de[(uint16_t)(bloques[k].c64 + i)] = (int16_t)(k + 1);
    f = abre(dir, "conversion64.tsv");
    while (fgets(l, sizeof l, f)) {
        char blk[64]; unsigned cpc, w, h, off, unidad;
        int nc;
        if (l[0] == '#' || (nc = sscanf(l, "%63s %x %u %u %u %u", blk, &cpc, &w, &h, &off, &unidad)) < 5) continue;
        if (nc < 6) unidad = h;
        if (w > 15) { fprintf(stderr, "conversion64.tsv: %s is too wide\n", blk); exit(2); }
        subgrafs[nsubgrafs].bloque = bloque_por_nombre(blk);
        subgrafs[nsubgrafs].cpc = (uint16_t)cpc; subgrafs[nsubgrafs].w = (uint8_t)w;
        subgrafs[nsubgrafs].h = (uint16_t)h; subgrafs[nsubgrafs].off = (uint16_t)off;
        subgrafs[nsubgrafs].unidad = (uint16_t)(unidad ? unidad : h);
        ++nsubgrafs;
    }
    fclose(f);
    {   /* the tape image (the flipped graphics' reference) and its mirrored bytes */
        f = abre(dir, "../../../data/cpc64/juego/ram.bin");
        n = fread(cinta_ref, 1, sizeof cinta_ref, f);
        fclose(f);
        tabla_fuente(cinta_ref, dir);
        for (k = 0; k < 256; ++k) {
            unsigned v = 0, p;
            for (p = 0; p < 4; ++p)        /* pixel p: bits 7-p (low) and 3-p (high) -> pixel 3-p */
                v |= (((unsigned)k >> (7 - p)) & 1u) << (4 + p) | (((unsigned)k >> (3 - p)) & 1u) << p;
            espejo_cpc[k] = (uint8_t)v;
        }
    }
    /* the pointer fields */
    f = abre(dir, "punteros64.tsv");
    while (fgets(l, sizeof l, f)) {
        char blk[64], dest[256], marca[16], *t;
        unsigned a;
        campo_t *c = &campos[ncampos];
        if (l[0] == '#' || sscanf(l, "%x %63s %255s %15s", &a, blk, dest, marca) != 4) continue;
        c->campo = (uint16_t)a;
        c->bloque = bloque_por_nombre(blk);
        c->marca = !strcmp(marca, "bit14") ? 'b' : !strcmp(marca, "virtual") ? 'v' : !strcmp(marca, "tagC0") ? 't'
                 : !strcmp(marca, "held") ? 'h' : !strcmp(marca, "fin") ? 'f' : !strcmp(marca, "region") ? 'r' : '-';
        (void)t;
        destino_de(dest, c);
        campo_de[c->campo] = campo_de[(uint16_t)(c->campo + 1)] = (int16_t)(ncampos + 1);
        ++ncampos;
    }
    fclose(f);
    /* the results */
    f = abre(dir, "resultados.tsv");
    while (fgets(l, sizeof l, f)) {
        char *t, *nombre;
        if (l[0] == '#') continue;
        nombre = strtok(l, " \t\n");
        if (!nombre) continue;
        for (i = 0; i < nrutinas && strcmp(rutinas[i].nombre, nombre); ++i) ;
        if (i == nrutinas) { fprintf(stderr, "resultados.tsv: no routine %s\n", nombre); exit(2); }
        {
            char *toks[32];
            int nt = 0, j;
            while (nt < 32 && (t = strtok(NULL, " \t\n")) != NULL) toks[nt++] = t;
            for (j = 0; j < nt; ++j) {         /* (destino_de uses strtok: the tokens are split first) */
                rutina_t *ru = &rutinas[i];
                t = toks[j];
                if (!strncmp(t, "PANTALLA", 8)) {
                    ru->pantalla = 1;
                    ru->regla = !strcmp(t, "PANTALLA:der") ? 'd' : !strcmp(t, "PANTALLA:izq") ? 'i'
                              : !strcmp(t, "PANTALLA:par") || !strcmp(t, "PANTALLA:detalle") ? 'p'
                              : !strcmp(t, "PANTALLA:doble") ? 'x' : !strcmp(t, "PANTALLA:fuente") ? 'f' : 's';
                }
                else if (!strcmp(t, "INLINE")) ru->linea = 1;
                else if (!strcmp(t, ">HL:INLINE")) ru->hl_linea_entra = 1;
                else if (!strcmp(t, "HL:INLINE")) ru->hl_linea_sale = 1;
                else if (t[0] == '!') { if (ru->nexcl < 16) ru->excl[ru->nexcl++] = bloque_por_nombre(t + 1); }
                else if (t[0] == '>' && par_de(t + 1) >= 0 && ru->nentra < 8) {
                    ru->entra[ru->nentra].reg = par_de(t + 1); ru->entra[ru->nentra].destino.marca = '-';
                    destino_de(t + 4, &ru->entra[ru->nentra].destino); ru->nentra++;
                }
                else if (par_de(t) >= 0 && ru->nsale < 8) {
                    ru->sale[ru->nsale].reg = par_de(t); ru->sale[ru->nsale].destino.marca = '-';
                    destino_de(t + 3, &ru->sale[ru->nsale].destino); ru->nsale++;
                }
                else if ((t[0] == '>' && par_de(t + 1) >= 0) || par_de(t) >= 0) {
                    fprintf(stderr, "resultados.tsv: %s: too many pointer registers\n", nombre); exit(2);
                }
                else ru->resultados |= resultados_de(t);
            }
        }
    }
    fclose(f);
    m6502_init();
}

static rutina_t *rutina(const char *nombre)
{
    int i;
    for (i = 0; i < nrutinas; ++i) if (!strcmp(rutinas[i].nombre, nombre)) return rutinas[i].stub ? NULL : &rutinas[i];
    return NULL;
}

int sombra6502_tiene(const char *nombre) { return rutina(nombre) != NULL; }

/* the end of the host's summary line: the 6502 calls checked and their differences */
unsigned long sombra6502_fallos(void)
{
    const char *f = getenv("SOMBRA6502_CICLOS");     /* a table of the 6502 cycles per routine */
    if (f) {
        FILE *o = fopen(f, "w");
        int i;
        if (o) {
            fprintf(o, "routine\tcalls\tcycles\tcycles_per_call\n");
            for (i = 0; i < nrutinas; ++i)
                if (rutinas[i].llamadas)
                    fprintf(o, "%s\t%llu\t%llu\t%.1f\n", rutinas[i].nombre, rutinas[i].llamadas, rutinas[i].ciclos,
                            (double)rutinas[i].ciclos / (double)rutinas[i].llamadas);
            fclose(o);
        }
    }
    fprintf(stderr, "; 6502 routines: %lu calls, %lu differences, %lu traps", llamadas_6502, fallos_6502, trampas);
    return fallos_6502;
}

static void pon_par(uint16_t zp, uint8_t lo, uint8_t hi) { Mem[zp] = lo; Mem[zp + 1] = hi; }

/* block k of the CPC memory `ram` in its C64 form, into dst: the bytes, then the pointer fields relocated */
static void a_c64(int k, const uint8_t *ram, uint8_t *dst)
{
    const bloque_t *b = &bloques[k];
    int i;
    if (b->modo == 'g') { convierte(k, ram, dst); return; }
    memcpy(dst + b->c64, ram + b->cpc, b->len);
    for (i = 0; i < b->len; ++i) {
        int c = campo_de[b->cpc + i] - 1;
        if (c >= 0 && campos[c].campo == b->cpc + i && !(campos[c].marca == 'h' && !(ram[(uint16_t)(b->cpc + i - 2)] & 0x80))) {
            uint16_t v = reubica(&campos[c], (uint16_t)(ram[b->cpc + i] | ram[(uint16_t)(b->cpc + i + 1)] << 8));
            dst[(uint16_t)(b->c64 + i)] = (uint8_t)v;
            dst[(uint16_t)(b->c64 + i + 1)] = (uint8_t)(v >> 8);
        }
    }
}

/* ---- the CPC screen in the bitmap: the visible bytes (rows 0-23, offsets below 600h of each 2 KiB line
 * block) as nibbles of $E000 + 320 row + 8 (xb / 2 + 4) + line, the high one for an even xb ---- */

static uint16_t bitmap_de(uint16_t a, int *alto)
{
    unsigned line = (a >> 11) & 7, off = a & 0x7FF, row = off >> 6, xb = off & 63;
    *alto = !(xb & 1);
    return (uint16_t)(0xE000 + 320 * row + 8 * (xb / 2 + 4) + line);
}

static void pantalla_a_bitmap(const uint8_t *ram, uint8_t *dst, const uint8_t *solo_si_cambia)
{
    unsigned a;
    for (a = 0xC000; a <= 0xFFFF; ++a) {
        int alto;
        uint16_t b;
        if ((a & 0x7FF) >= 0x600) continue;
        if (solo_si_cambia && solo_si_cambia[a] == ram[a]) continue;
        b = bitmap_de((uint16_t)a, &alto);
        dst[b] = alto ? (uint8_t)((dst[b] & 0x0F) | nib[ram[a]] << 4) : (uint8_t)((dst[b] & 0xF0) | nib[ram[a]]);
    }
}

/* ---- traps: a stub (02h, then the Z80 entry) stands for a function not translated yet: the 6502 memory goes
 * back to the CPC form, the Z80 original runs on it (the host's core, llama_z80), and what it changed comes
 * to the C64 form; then the stub returns as an RTS ---- */

static uint8_t cpc[0x10000];                /* the CPC memory of the call in progress: entry + the traps' work */
static uint8_t sinc64[0x10000];             /* the 6502 memory as last made from cpc */
static uint16_t sp_trampa;                  /* the Z80 SP the trapped functions run with */

static uint16_t reubica_inv(const campo_t *c, uint16_t v)
{
    uint16_t f = 0;
    int b;
    if (v == 0) return 0;
    if (c->marca == 't' && (v >> 8) == 0xC0) return v;
    if (c->marca == 'b') { f = v & 0x4000; v &= (uint16_t)~0x4000; }
    switch (c->clase) {
    case D_PILA: return (uint16_t)(v | f);
    case D_CODE: return codigo_z80[v] ? codigo_z80[v] : v;
    case D_GFX: return (uint16_t)((gfx_cpc[v] ? gfx_cpc[v] : v) | f);
    default:
        b = bloque_c64_de[v] - 1;
        if (b >= 0) return (uint16_t)((bloques[b].cpc + v - bloques[b].c64) | f);
        if (c->clase == D_LISTA) {             /* a target block that is not copied (a 'nada' buffer: the mirror) */
            int i;
            for (i = 0; i < c->nlista; ++i) {
                const bloque_t *t = &bloques[c->lista[i]];
                if (t->cpc >= 0 && v >= t->c64 && v < t->c64 + t->len64 && t->len64 == t->len)
                    return (uint16_t)((t->cpc + v - t->c64) | f);
            }
        }
        if (c->clase == D_LISTA && c->marca == 'v') {
            b = c->lista[0];
            if (v < bloques[b].c64 && v + 0x20 >= bloques[b].c64) return (uint16_t)(bloques[b].cpc + v - bloques[b].c64);
        }
        if (c->clase == D_LISTA && c->marca == 'r') {
            uint16_t d = (uint16_t)(bloques[c->lista[0]].c64 - bloques[c->lista[0]].cpc);
            if ((uint16_t)(v - d) >= 0x7F80 && (uint16_t)(v - d) < 0xA000) return (uint16_t)(v - d);
        }
        if (c->clase == D_LISTA && c->marca == 'f') {
            int i;
            for (i = 0; i < c->nlista; ++i)
                if (v == bloques[c->lista[i]].c64 + bloques[c->lista[i]].len64)
                    return (uint16_t)(bloques[c->lista[i]].cpc + bloques[c->lista[i]].len);
        }
        return (uint16_t)(v | f);
    }
}

/* block k of the 6502 memory back into the CPC memory (copia blocks: the bytes, then the pointer fields) */
static void a_cpc(int k, const uint8_t *src, uint8_t *ram)
{
    const bloque_t *b = &bloques[k];
    int i;
    memcpy(ram + b->cpc, src + b->c64, b->len);
    for (i = 0; i < b->len; ++i) {
        int c = campo_de[b->cpc + i] - 1;
        if (c >= 0 && campos[c].campo == b->cpc + i && !(campos[c].marca == 'h' && !(src[(uint16_t)(b->c64 + i - 2)] & 0x80))) {
            uint16_t v = reubica_inv(&campos[c], (uint16_t)(src[(uint16_t)(b->c64 + i)] | src[(uint16_t)(b->c64 + i + 1)] << 8));
            ram[b->cpc + i] = (uint8_t)v;
            ram[(uint16_t)(b->cpc + i + 1)] = (uint8_t)(v >> 8);
        }
    }
}

#define PLAT_TECLADO 0x07C0
#define PLAT_AY      0x07CA
#define PLAT_TINTAS  0x07DA
#define PLAT_CRTC    0x07EB
#define PLAT_MODO    0x07FB
#define PLAT_IFF     0x07FC

/* the mirrors of the 6502 memory as a hardware state, and back */
static void de_espejos(const uint8_t *m, plataforma_t *p)
{
    memcpy(p->teclado, m + PLAT_TECLADO, 10);
    memcpy(p->ay, m + PLAT_AY, 16);
    /* the inks: C64 colours in the mirrors, not convertible back: the trap keeps the host's CPC inks */
    memcpy(p->crtc, m + PLAT_CRTC, 16);
    p->modo = m[PLAT_MODO];
    p->iff = m[PLAT_IFF];
}

static void pon_plataforma(const plataforma_t *p, uint8_t *m)
{
    int i;
    memcpy(m + PLAT_TECLADO, p->teclado, 10);
    memcpy(m + PLAT_AY, p->ay, 16);
    for (i = 0; i < 17; ++i) m[PLAT_TINTAS + i] = hw_c64[p->paleta[i] & 31];   /* the C64 colours plat_tinta gets */
    memcpy(m + PLAT_CRTC, p->crtc, 16);
    m[PLAT_MODO] = p->modo;
    m[PLAT_IFF] = p->iff;
}

static uint16_t saltar_linea;               /* inline bytes the trapped helper consumed */

static int trampa(uint16_t pc)
{
    static uint8_t ram_host[0x10000], previo[0x10000];
    uint16_t z = (uint16_t)(Mem[(uint16_t)(pc + 1)] | Mem[(uint16_t)(pc + 2)] << 8);
    z80 cpu_host = cpu;
    int k;
    uint8_t lo, hi;
    ++trampas;
    for (k = 0; k < nbloques; ++k) {           /* what the 6502 changed, back to the CPC form */
        const bloque_t *b = &bloques[k];
        if (b->cpc >= 0 && b->modo == 'c' && memcmp(Mem + b->c64, sinc64 + b->c64, b->len64)) a_cpc(k, Mem, cpc);
    }
    {   /* the bitmap the 6502 drew since the last sync, back into the CPC screen for the Z80 original (a routine
         * that merges with the screen, e.g. the tiles of 4A5F after a 6502 fill): each changed C64 pixel as two
         * CPC pixels of its pen (exact for uniform bytes) */
        static const uint8_t pen[4] = { 3, 0, 1, 2 };   /* bit pair -> CPC pen */
        unsigned a;
        for (a = 0xC000; a <= 0xFFFF; ++a) {
            int alto;
            uint16_t b;
            uint8_t n, n0, pl, pr;
            if ((a & 0x7FF) >= 0x600) continue;
            b = bitmap_de((uint16_t)a, &alto);
            if (Mem[b] == sinc64[b]) continue;
            n = alto ? (uint8_t)(Mem[b] >> 4) : (uint8_t)(Mem[b] & 0x0F);
            n0 = alto ? (uint8_t)(sinc64[b] >> 4) : (uint8_t)(sinc64[b] & 0x0F);
            if (n == n0) continue;
            pl = pen[n >> 2]; pr = pen[n & 3];
            cpc[a] = (uint8_t)((pl & 1) * 0xC0 | (pl >> 1) * 0x0C | (pr & 1) * 0x30 | (pr >> 1) * 0x03);
        }
    }
    memcpy(previo, cpc, sizeof cpc);
    memcpy(ram_host, ram, sizeof ram);
    memcpy(ram, cpc, sizeof ram);
    cpu.a = Regs.AC; cpu.cf = Regs.SR & 1; cpu.zf = (Regs.SR >> 1) & 1;
    cpu.c = Mem[ZBC]; cpu.b = Mem[ZBC + 1]; cpu.e = Mem[ZDE]; cpu.d = Mem[ZDE + 1]; cpu.l = Mem[ZHL]; cpu.h = Mem[ZHL + 1];
    cpu.ix = (uint16_t)(Mem[ZIX] | Mem[ZIX + 1] << 8); cpu.iy = (uint16_t)(Mem[ZIY] | Mem[ZIY + 1] << 8);
    cpu.c_ = Mem[0x0C]; cpu.b_ = Mem[0x0D]; cpu.e_ = Mem[0x0E]; cpu.d_ = Mem[0x0F]; cpu.l_ = Mem[0x10]; cpu.h_ = Mem[0x11];
    cpu.a_ = Mem[0x12]; cpu.f_ = Mem[0x13];
    {   /* register pairs holding pointers (stubs64.tsv / resultados.tsv ">REG:target" of the stub): C64 -> CPC */
        int i, j;
        for (i = 0; i < nrutinas; ++i)
            if (rutinas[i].stub && rutinas[i].dir == pc)
                for (j = 0; j < rutinas[i].nentra; ++j) {
                    uint16_t *p = NULL, v;
                    switch (rutinas[i].entra[j].reg) {
                    case P_IX: p = &cpu.ix; break;
                    case P_IY: p = &cpu.iy; break;
                    default: break;
                    }
                    if (p) *p = reubica_inv(&rutinas[i].entra[j].destino, *p);
                    else {
                        uint8_t *rh = rutinas[i].entra[j].reg == P_BC ? &cpu.b : rutinas[i].entra[j].reg == P_DE ? &cpu.d : &cpu.h;
                        uint8_t *rl = rutinas[i].entra[j].reg == P_BC ? &cpu.c : rutinas[i].entra[j].reg == P_DE ? &cpu.e : &cpu.l;
                        v = reubica_inv(&rutinas[i].entra[j].destino, (uint16_t)(*rh << 8 | *rl));
                        *rh = (uint8_t)(v >> 8); *rl = (uint8_t)v;
                    }
                }
    }
    {   /* the hardware as the 6502 left it, for the Z80 original; the host's own state kept aside */
        plataforma_t p6, ph;
        hibrido_plataforma(&ph);
        de_espejos(Mem, &p6);
        memcpy(p6.paleta, ph.paleta, sizeof p6.paleta);
        hibrido_pon_plataforma(&p6);
        cpu.iff1 = cpu.iff2 = p6.iff != 0;
        cpu.sp = sp_trampa;
        {
            int i, linea = 0;
            for (i = 0; i < nrutinas; ++i) if (rutinas[i].stub && rutinas[i].dir == pc) linea = rutinas[i].linea;
            if (linea) {                       /* the bytes after the JSR, copied to 0080h for the Z80 helper */
                uint16_t r6 = (uint16_t)((Mem[0x0100 | (uint8_t)(Regs.SP + 1)] | Mem[0x0100 | (uint8_t)(Regs.SP + 2)] << 8) + 1);
                uint16_t k;
                for (k = 0; k < 0x70; ++k) ram[0x0080 + k] = Mem[(uint16_t)(r6 + k)];
                llama_z80_linea(z, 0x0080);
                saltar_linea = (uint16_t)(cpu.pc - 0x0080);    /* the bytes it consumed */
                for (k = 0; k < 0x70; ++k) ram[0x0080 + k] = cpc[0x0080 + k];   /* the CPC's 0080h back */
            }
            else llama_z80(z);
        }
        hibrido_plataforma(&p6);
        memcpy(p6.teclado, Mem + PLAT_TECLADO, 10);
        pon_plataforma(&p6, Mem);
        hibrido_pon_plataforma(&ph);
    }
    memcpy(cpc, ram, sizeof cpc);
    memcpy(ram, ram_host, sizeof ram);
    Regs.AC = cpu.a;
    Regs.SR = (uint8_t)((Regs.SR & ~3) | (cpu.cf ? 1 : 0) | (cpu.zf ? 2 : 0));
    Mem[ZBC] = cpu.c; Mem[ZBC + 1] = cpu.b; Mem[ZDE] = cpu.e; Mem[ZDE + 1] = cpu.d; Mem[ZHL] = cpu.l; Mem[ZHL + 1] = cpu.h;
    Mem[ZIX] = (uint8_t)cpu.ix; Mem[ZIX + 1] = (uint8_t)(cpu.ix >> 8); Mem[ZIY] = (uint8_t)cpu.iy; Mem[ZIY + 1] = (uint8_t)(cpu.iy >> 8);
    Mem[0x0C] = cpu.c_; Mem[0x0D] = cpu.b_; Mem[0x0E] = cpu.e_; Mem[0x0F] = cpu.d_; Mem[0x10] = cpu.l_; Mem[0x11] = cpu.h_;
    Mem[0x12] = cpu.a_; Mem[0x13] = cpu.f_;
    {   /* register pairs returning pointers ("REG:target" of the stub): CPC -> C64 */
        int i, j;
        for (i = 0; i < nrutinas; ++i)
            if (rutinas[i].stub && rutinas[i].dir == pc)
                for (j = 0; j < rutinas[i].nsale; ++j) {
                    uint16_t zp = (uint16_t)(ZBC + 2 * rutinas[i].sale[j].reg);
                    uint16_t v = reubica(&rutinas[i].sale[j].destino, (uint16_t)(Mem[zp] | Mem[zp + 1] << 8));
                    pon_par(zp, (uint8_t)v, (uint8_t)(v >> 8));
                }
    }
    cpu = cpu_host;
    for (k = 0; k < nbloques; ++k) {           /* what the Z80 changed, to the C64 form */
        const bloque_t *b = &bloques[k];
        if (b->cpc >= 0 && (b->modo == 'c' || b->modo == 'g') && memcmp(previo + b->cpc, cpc + b->cpc, b->len)) a_c64(k, cpc, Mem);
    }
    pantalla_a_bitmap(cpc, Mem, previo);
    memcpy(sinc64, Mem, sizeof sinc64);
    lo = Mem[0x0100 | (uint8_t)(Regs.SP + 1)];  /* the stub's RTS */
    hi = Mem[0x0100 | (uint8_t)(Regs.SP + 2)];
    Regs.SP = (uint8_t)(Regs.SP + 2);
    Regs.PC = (uint16_t)((lo | hi << 8) + 1 + saltar_linea);
    saltar_linea = 0;
    return 1;
}

/* PANTALLA:doble: the Z80 original run a second time on doubled graphics: every tile (00h-D9h but the object
 * slots, at their places after the start-up), every sprite frame of marcos64.tsv (characters, faces, robes, door,
 * objects) and the visible screen replaced by their C64 form as the 6502 memory holds it at the entry, each C64
 * pixel as two equal CPC pixels.  The Z80's merges (pen 0 / pen 2 / pen 1 transparent, mirrors, copies) then act on
 * pixel pairs exactly as the C64 code acts on its pixels, so its screen converts exactly to what the 6502 routine
 * must draw: an exact comparison of tile and sprite composition (the per-byte rules cannot give one: the tiles'
 * detalle conversion depends on the neighbours and merges do not commute with any per-byte conversion). */
static uint8_t dbl_de(uint8_t n)
{
    static const uint8_t pen[4] = { 3, 0, 1, 2 };
    uint8_t p[4], b = 0;
    unsigned i;
    p[0] = p[1] = pen[(n >> 2) & 3]; p[2] = p[3] = pen[n & 3];
    for (i = 0; i < 4; ++i) b = (uint8_t)(b | ((p[i] & 1) << (7 - i)) | (((p[i] >> 1) & 1) << (3 - i)));
    return b;
}

static void doble_esperado(const rutina_t *r, const z80 *ce, const uint8_t *ram_e, uint8_t *esp)
{
    static uint8_t rd[0x10000], ram_host[0x10000];
    z80 cpu_host = cpu;
    plataforma_t ph;
    unsigned a, l, x;
    int m, n;
    memcpy(rd, ram_e, sizeof rd);
    for (a = 0xC000; a <= 0xFFFF; ++a) {           /* the screen */
        int alto;
        uint16_t b;
        if ((a & 0x7FF) >= 0x600) continue;
        b = bitmap_de((uint16_t)a, &alto);
        rd[a] = dbl_de(alto ? (uint8_t)(antes[b] >> 4) : (uint8_t)(antes[b] & 15));
    }
    for (n = 1; n <= 0xD9; ++n) {                  /* the tiles: 80h-D9h at 8300h + 32n, below 80h in the screen's gaps */
        uint16_t src = (uint16_t)(n * 32);
        if ((n >= 0x2D && n <= 0x2F) || (n >= 0xA1 && n <= 0xA6)) continue;
        if (n & 0x80) src = (uint16_t)((((src >> 8) + 0x83) << 8) | (src & 0xFF));
        else src = (uint16_t)(((0xC6 + (((n & 0x70) >> 1) | ((n >> 3) & 1))) << 8) | (src & 0xFF));
        for (l = 0; l < 8; ++l)
            for (x = 0; x < 4; ++x) {
                uint8_t c = antes[(uint16_t)(0xD000 + 16 * n + 8 * (x >> 1) + l)];
                rd[(uint16_t)(src + 4 * l + x)] = dbl_de((x & 1) ? (uint8_t)(c & 15) : (uint8_t)(c >> 4));
            }
    }
    for (m = 0; m < nmarcos; ++m) {                /* the sprite frames */
        const marco_t *g = &marcos[m];
        for (l = 0; l < g->h; ++l)
            for (x = 0; x < g->w; ++x) {
                uint8_t c = antes[(uint16_t)(bloques[g->bloque].c64 + g->off + l * ((g->w + 1) / 2) + x / 2)];
                rd[(uint16_t)(g->cpc + l * g->w + x)] = dbl_de((x & 1) ? (uint8_t)(c & 15) : (uint8_t)(c >> 4));
            }
    }
    memcpy(ram_host, ram, sizeof ram);
    memcpy(ram, rd, sizeof ram);
    hibrido_plataforma(&ph);
    cpu = *ce;
    llama_z80(codigo_z80[r->dir]);
    memcpy(rd, ram, sizeof rd);
    memcpy(ram, ram_host, sizeof ram);
    hibrido_pon_plataforma(&ph);
    cpu = cpu_host;
    memcpy(esp, antes, 0x10000);
    for (a = 0xC000; a <= 0xFFFF; ++a) {
        int alto;
        uint16_t b;
        if ((a & 0x7FF) >= 0x600) continue;
        b = bitmap_de((uint16_t)a, &alto);
        esp[b] = alto ? (uint8_t)((esp[b] & 0x0F) | nib_izq[rd[a]] << 4) : (uint8_t)((esp[b] & 0xF0) | nib_izq[rd[a]]);
    }
}

/* the call of t: entry state (ce, ram_e), the Z80's result (zz, ram_z).  Nothing when t has no routine. */
void sombra6502_comprueba(const char *nombre, const z80 *ce, const uint8_t *ram_e, const z80 *zz, const uint8_t *ram_z,
                          const plataforma_t *pe, const plataforma_t *pz)
{
    rutina_t *r = rutina(nombre);
    unsigned long ciclos;
    int i, mal = 0;
    unsigned k, m;
    char msg[512];
    size_t lmsg = 0;
    if (!r) return;
    ++llamadas_6502;
    memcpy(Mem, imagen, sizeof Mem);
    for (i = 0; i < nbloques; ++i)
        if (bloques[i].cpc >= 0 && (bloques[i].modo == 'c' || bloques[i].modo == 'g')) a_c64(i, ram_e, Mem);
    pantalla_a_bitmap(ram_e, Mem, NULL);
    pon_plataforma(pe, Mem);
    memcpy(cpc, ram_e, sizeof cpc);                 /* for the traps */
    sp_trampa = (uint16_t)(ce->sp - 0x40);
    m6502_trampa = trampa;
    pon_par(ZBC, ce->c, ce->b); pon_par(ZDE, ce->e, ce->d); pon_par(ZHL, ce->l, ce->h);
    pon_par(ZIX, (uint8_t)ce->ix, (uint8_t)(ce->ix >> 8)); pon_par(ZIY, (uint8_t)ce->iy, (uint8_t)(ce->iy >> 8));
    pon_par(0x0C, ce->c_, ce->b_); pon_par(0x0E, ce->e_, ce->d_); pon_par(0x10, ce->l_, ce->h_);   /* the alternate set */
    Mem[0x12] = ce->a_; Mem[0x13] = ce->f_;
    for (i = 0; i < r->nentra; ++i) {          /* a pointer in a register at the entry: CPC -> C64 */
        uint16_t zp = (uint16_t)(ZBC + 2 * r->entra[i].reg);
        uint16_t v = reubica(&r->entra[i].destino, (uint16_t)(Mem[zp] | Mem[zp + 1] << 8));
        pon_par(zp, (uint8_t)v, (uint8_t)(v >> 8));
    }
    memcpy(antes, Mem, sizeof antes);
    memcpy(sinc64, Mem, sizeof sinc64);
    Regs.SP = 0xFF; Regs.SR = (uint8_t)(0x30 | (ce->cf ? 1 : 0) | (ce->zf ? 2 : 0));
    if (r->hl_linea_entra) {                   /* >HL:INLINE: the bytes HL points at (Z80 code) at $0100-$016F */
        uint16_t hl = (uint16_t)(ce->h << 8 | ce->l);
        for (k = 0; k < 0x70; ++k) Mem[0x0100 + k] = ram_e[(uint16_t)(hl + k)];
        memcpy(antes + 0x0100, Mem + 0x0100, 0x70);
        pon_par(ZHL, 0x00, 0x01);
    }
    if (r->linea) {                            /* INLINE: the bytes after the Z80's call, at $0100-$016F */
        uint16_t ret_z = (uint16_t)(ram_e[ce->sp] | ram_e[(uint16_t)(ce->sp + 1)] << 8);
        for (k = 0; k < 0x70; ++k) Mem[0x0100 + k] = ram_e[(uint16_t)(ret_z + k)];
        memcpy(antes + 0x0100, Mem + 0x0100, 0x70);
        /* a routine that drops its return address and jumps (3A5D: to a word of its table, a Z80 address
         * in the copied bytes): it also stops at the Z80's exit PC with SP back */
        ciclos = m6502_llama_hasta(r->dir, ce->a, 0x00FF, 0x0100, 0x0170,
                                   (zz->pc >= 0x0100 && zz->pc < 0x0170) ? 0 : zz->pc, 50000000ul);
        if (ciclos && Regs.PC >= 0x0100 && Regs.PC < 0x0170 && (uint16_t)(Regs.PC - 0x0100) != (uint16_t)(zz->pc - ret_z)) {
            lmsg += (size_t)snprintf(msg + lmsg, sizeof msg - lmsg, " inline bytes consumed %u/%u",
                                     (unsigned)(Regs.PC - 0x0100), (unsigned)(uint16_t)(zz->pc - ret_z));
            mal = 1;
        }
    }
    else ciclos = m6502_llama(r->dir, ce->a, 0, 0, 50000000ul);
    r->ciclos += ciclos; r->llamadas++;
    if (!ciclos) {
        snprintf(msg, sizeof msg, "does not return");
        mal = 1;
    } else {
        for (i = 0; i < nbloques && lmsg < sizeof msg - 96; ++i) {
            const bloque_t *b = &bloques[i];
            const uint8_t *ref;
            int j, excluido = 0;
            for (j = 0; j < r->nexcl; ++j) if (r->excl[j] == i) excluido = 1;
            if (excluido || b->modo == 'n' || (b->cpc < 0 && b->modo != 'v')) continue;
            if (b->modo == 'v') ref = imagen;                     /* a constant: it must not change */
            else if (!memcmp(ram_e + b->cpc, ram_z + b->cpc, b->len)) ref = antes;   /* the Z80 left it alone */
            else { a_c64(i, ram_z, esperado); ref = esperado; }
            if (!memcmp(Mem + b->c64, ref + b->c64, b->len64)) continue;
            for (k = 0; k < b->len64; ++k) {
                uint16_t a = (uint16_t)(b->c64 + k);
                if (Mem[a] == ref[a]) continue;
                if (b->modo == 'c') {                              /* a Z80 stack address: not compared */
                    int c = campo_de[(uint16_t)(b->cpc + k)] - 1;
                    if (c >= 0 && campos[c].clase == D_PILA) continue;
                }
                lmsg += (size_t)snprintf(msg + lmsg, sizeof msg - lmsg, " [%s %04X->%04X] %02X/%02X", b->nombre,
                                         b->cpc >= 0 && b->modo == 'c' ? (unsigned)b->cpc + k : 0u, a, Mem[a], ref[a]);
                mal = 1;
                break;
            }
        }
        {                                      /* the hardware state: the mirrors against the Z80's port effects */
            static uint8_t pm[0x800];
            pon_plataforma(pz, pm);
            for (k = PLAT_AY; k <= PLAT_IFF && lmsg < sizeof msg - 48; ++k)
                if (Mem[k] != pm[k]) {
                    lmsg += (size_t)snprintf(msg + lmsg, sizeof msg - lmsg, " [%s %u] %02X/%02X",
                                             k < PLAT_TINTAS ? "AY" : k < PLAT_CRTC ? "ink" : k < PLAT_MODO ? "CRTC" : k == PLAT_MODO ? "mode" : "IFF",
                                             k < PLAT_TINTAS ? k - PLAT_AY : k < PLAT_CRTC ? k - PLAT_TINTAS : k < PLAT_MODO ? k - PLAT_CRTC : 0,
                                             Mem[k], pm[k]);
                    mal = 1;
                    break;
                }
        }
        if (r->pantalla && r->regla == 'x') {  /* PANTALLA:doble: exact, cells 4-35 of rows 0-24 */
            static uint8_t esp[0x10000];
            doble_esperado(r, ce, ram_e, esp);
            for (k = 0xE000; k < 0xFF40 && lmsg < sizeof msg - 64; ++k) {
                unsigned col = (k - 0xE000) % 320 / 8;
                if (col < 4 || col >= 36 || Mem[k] == esp[k]) continue;
                lmsg += (size_t)snprintf(msg + lmsg, sizeof msg - lmsg, " [doble %04X] %02X/%02X (before %02X)", k, Mem[k], esp[k], antes[k]);
                mal = 1;
                break;
            }
        }
        else if (r->pantalla) {                     /* the screen: the Z80's result converted (its rule), cells 4-35 of rows 0-23 */
            for (k = 0xC000; k <= 0xFFFF && lmsg < sizeof msg - 64; ++k) {
                int alto;
                uint16_t b;
                uint8_t n6, ne, cb = ram_z[k];
                if ((k & 0x7FF) >= 0x600) continue;
                b = bitmap_de((uint16_t)k, &alto);
                n6 = alto ? (uint8_t)(Mem[b] >> 4) : (uint8_t)(Mem[b] & 0x0F);
                if (cb == ram_e[k] && n6 == (alto ? (uint8_t)(antes[b] >> 4) : (uint8_t)(antes[b] & 0x0F))) continue;   /* untouched */
                if (r->regla == 'p' || r->regla == 'f') {
                    if (nibble_valido(n6, cb) || (r->regla == 'f' && ((fuente_extra[cb] >> n6) & 1))) continue;
                    ne = nib[cb];
                }
                else {
                    ne = r->regla == 'd' ? nib_der[cb] : r->regla == 'i' ? nib_izq[cb] : nib[cb];
                    if (n6 == ne) continue;
                }
                lmsg += (size_t)snprintf(msg + lmsg, sizeof msg - lmsg, " [screen %04X->%04X%s] %X/%X (CPC %02X)", k, b, alto ? "h" : "l", n6, ne, cb);
                mal = 1;
                break;
            }
        }
        if (r->hl_linea_sale) {                /* HL:INLINE: the bytes HL went over, against the Z80's */
            uint16_t d6 = (uint16_t)((Mem[ZHL] | Mem[ZHL + 1] << 8) - 0x0100);
            uint16_t dz = (uint16_t)((zz->h << 8 | zz->l) - (ce->h << 8 | ce->l));
            if (d6 != dz) {
                lmsg += (size_t)snprintf(msg + lmsg, sizeof msg - lmsg, " HL advanced %u/%u", (unsigned)d6, (unsigned)dz);
                mal = 1;
            }
        }
        for (i = 0; i < r->nsale; ++i) {       /* a pointer in a register at the exit: compared in C64 form */
            uint16_t zp = (uint16_t)(ZBC + 2 * r->sale[i].reg), v6 = (uint16_t)(Mem[zp] | Mem[zp + 1] << 8), vz;
            switch (r->sale[i].reg) {
            case P_BC: vz = (uint16_t)(zz->b << 8 | zz->c); break;
            case P_DE: vz = (uint16_t)(zz->d << 8 | zz->e); break;
            case P_HL: vz = (uint16_t)(zz->h << 8 | zz->l); break;
            case P_IX: vz = zz->ix; break;
            default: vz = zz->iy; break;
            }
            vz = reubica(&r->sale[i].destino, vz);
            if (v6 != vz) {
                lmsg += (size_t)snprintf(msg + lmsg, sizeof msg - lmsg, " %s %04X/%04X", (const char *[]){ "BC", "DE", "HL", "IX", "IY" }[r->sale[i].reg], v6, vz);
                mal = 1;
            }
        }
        m = r->resultados;
#define REG(bit, txt, v6, vz) if ((m & (bit)) && (v6) != (vz)) { lmsg += (size_t)snprintf(msg + lmsg, sizeof msg - lmsg, " %s %02X/%02X", txt, (unsigned)(v6), (unsigned)(vz)); mal = 1; }
        REG(R_A, "A", Regs.AC, zz->a)
        REG(R_B, "B", Mem[ZBC + 1], zz->b) REG(R_C, "C", Mem[ZBC], zz->c)
        REG(R_D, "D", Mem[ZDE + 1], zz->d) REG(R_E, "E", Mem[ZDE], zz->e)
        REG(R_H, "H", Mem[ZHL + 1], zz->h) REG(R_L, "L", Mem[ZHL], zz->l)
        REG(R_IXH, "IXH", Mem[ZIX + 1], zz->ix >> 8) REG(R_IXL, "IXL", Mem[ZIX], zz->ix & 0xFF)
        REG(R_IYH, "IYH", Mem[ZIY + 1], zz->iy >> 8) REG(R_IYL, "IYL", Mem[ZIY], zz->iy & 0xFF)
        REG(R_CF, "CF", Regs.SR & 1, zz->cf ? 1 : 0) REG(R_ZF, "ZF", (Regs.SR >> 1) & 1, zz->zf ? 1 : 0)
        REG(R_A2, "A'", Mem[0x12], zz->a_)
        REG(R_BC2, "BC'", Mem[0x0C] | Mem[0x0D] << 8, zz->c_ | zz->b_ << 8)
        REG(R_DE2, "DE'", Mem[0x0E] | Mem[0x0F] << 8, zz->e_ | zz->d_ << 8)
        REG(R_HL2, "HL'", Mem[0x10] | Mem[0x11] << 8, zz->l_ | zz->h_ << 8)
#undef REG
    }
    if (mal) {
        ++fallos_6502;
        if (fallos_6502 <= (unsigned long)max_fallos_6502)
            fprintf(stderr, "6502 DIFF %s (A=%02X BC=%02X%02X DE=%02X%02X HL=%02X%02X IX=%04X IY=%04X):%s\n", nombre,
                    ce->a, ce->b, ce->c, ce->d, ce->e, ce->h, ce->l, ce->ix, ce->iy, msg);
    }
}

/* ---- the whole game (hibrido --juego6502 DIR): the 6502 game from its entry (principal_inicio; principal.s
 * built with -D PRUEBA) in step with the Z80's run.  At every frame point of the host (the main loop's head
 * 2179h, a pass of a `pausa` wait) the 6502 runs to its own (plat_frame, plat_pausa), the 300 Hz ticks given
 * at the same wait passes (plat_espera, plat_pausa) by the host's rule (a tick due every 3328 us of the waits,
 * delivered when the IFF mirror is on: sys_tick called as the C64's interrupt calls it, A X Y P kept), the
 * keyboard of the frame in the mirror and the value of the Z80's LD A,R (518Ah) in plat_aleatorio's byte.
 * Then the memory is compared with the Z80's in C64 form: every block of mapa64.tsv but the ones juego6502.tsv
 * leaves out (C64-format graphics buffers), the Z80 stack fields, and the platform mirrors (AY, inks, mode,
 * IFF; not the CRTC: the C64 game makes no CRTC calls).  The screen is not compared here (the per-call checks
 * compare each routine's drawing; tile and sprite composition has no per-byte rule). ---- */

#define PLAT_ALEATORIO 0x07BF

static uint16_t j_inicio, j_frame, j_espera, j_pausa, j_tick, j_final, j_nueva;
static int j_excl[64], nj_excl, j_excl_nuevo[16], nj_excl_nuevo, j_retoma, j_es_nueva;
static uint8_t j_no_cpc[0x10000];          /* CPC addresses not compared (juego6502.tsv @XXXX N) */
static uint8_t j_no_cpc_final[0x10000];    /* CPC addresses not compared at the ending only (juego6502.tsv final @XXXX N) */
static unsigned long j_reloj, j_siguiente = 3328, j_pendientes, j_ticks, j_frames, j_fallos;
static int j_final_visto;                  /* the 6502 reached plat_final (the ending) */
static unsigned long j_ciclos;             /* the cycles of the last frame (the ticks' sys_tick included) */
static unsigned long long *j_perfil;       /* SOMBRA6502_PERFIL=F: the cycles spent at each address */
/* SOMBRA6502_CATEGORIAS=F: per frame, the cycles spent in each category of addresses (lines "start end cat", hex
 * addresses, cat 0-15) and the times each listed address is executed (lines "hit addr"): hibrido --ciclos-frame
 * adds them as columns (c64/juego_final/categorias64.py writes the file from juego.map and juego.lbl) */
static uint8_t *j_cat;
static unsigned long j_cat_ciclos[16], j_hit_n[8];
static uint16_t j_hit_dir[8];
static int j_hits;
unsigned long *sombra6502_juego_categorias(unsigned long **hits, int *nhits)
{
    *hits = j_hit_n; *nhits = j_hits;
    return j_cat ? j_cat_ciclos : NULL;
}
static void j_cat_carga(const char *f)
{
    char l[128];
    FILE *o = fopen(f, "r");
    unsigned a, b, c;
    if (!o) { fprintf(stderr, "cannot read %s\n", f); exit(1); }
    j_cat = calloc(0x10000, 1);
    while (fgets(l, sizeof l, o)) {
        if (sscanf(l, "hit %x", &a) == 1) { if (j_hits < 8) j_hit_dir[j_hits++] = (uint16_t)a; }
        else if (sscanf(l, "%x %x %u", &a, &b, &c) == 3) while (a <= b && a < 0x10000) j_cat[a++] = (uint8_t)(c & 15);
    }
    fclose(o);
}
unsigned long sombra6502_juego_ciclos(void) { return j_ciclos; }

static uint16_t etiqueta(const char *n)
{
    int i;
    for (i = 0; i < nrutinas; ++i) if (!strcmp(rutinas[i].nombre, n)) return rutinas[i].dir;
    fprintf(stderr, "sombra6502: no %s in juego.lbl (the whole game: principal.s built with -D PRUEBA)\n", n);
    exit(2);
}

/* --usados6502 F (hibrido.c): every address the 6502 read (r), wrote (w) or executed (x) over the run, one line per
 * address used; c64/juego_final/usados64.py joins the runs and reports what the image never uses.  The host's own
 * pokes (the platform's keys and ticks, the image copied at the start) are not counted: only the 6502's accesses. */
static const char *u_salida;
void sombra6502_usados(const char *salida) { MemUsados = calloc(0x10000, 1); u_salida = salida; }
void sombra6502_usados_guarda(void)
{
    FILE *f;
    unsigned k;
    if (!MemUsados) return;
    if (!(f = fopen(u_salida, "w"))) { fprintf(stderr, "cannot write %s\n", u_salida); exit(1); }
    for (k = 0; k < 0x10000; ++k)
        if (MemUsados[k])
            fprintf(f, "%04X %c%c%c\n", k, MemUsados[k] & 1 ? 'r' : '-', MemUsados[k] & 2 ? 'w' : '-', MemUsados[k] & 4 ? 'x' : '-');
    fclose(f);
}

void sombra6502_juego_inicio(const char *dir, const uint8_t *ram, const plataforma_t *p)
{
    char l[256];
    FILE *f;
    int i;
    j_inicio = etiqueta("principal_inicio"); j_frame = etiqueta("plat_frame"); j_espera = etiqueta("plat_espera");
    j_pausa = etiqueta("plat_pausa"); j_tick = etiqueta("sys_tick"); j_final = etiqueta("plat_final");
    j_nueva = etiqueta("game_init_new_game");
    f = abre(dir, "juego6502.tsv");                 /* what is not compared (its comment says how) */
    while (fgets(l, sizeof l, f)) {
        char n[64], m[64];
        unsigned a, len;
        if (l[0] == '#' || sscanf(l, "%63s", n) != 1) continue;
        if (n[0] == '@' && sscanf(l, "@%x %u", &a, &len) == 2) { while (len--) j_no_cpc[(uint16_t)a++] = 1; }
        else if (!strcmp(n, "final") && sscanf(l, "%*s @%x %u", &a, &len) == 2) { while (len--) j_no_cpc_final[(uint16_t)a++] = 1; }
        else if (!strcmp(n, "nuevo") && sscanf(l, "%*s %63s", m) == 1 && nj_excl_nuevo < 16) j_excl_nuevo[nj_excl_nuevo++] = bloque_por_nombre(m);
        else if (nj_excl < 64) j_excl[nj_excl++] = bloque_por_nombre(n);
    }
    fclose(f);
    memcpy(Mem, imagen, sizeof Mem);
    for (i = 0; i < nbloques; ++i)
        if (bloques[i].cpc >= 0 && (bloques[i].modo == 'c' || bloques[i].modo == 'g')) a_c64(i, ram, Mem);
    pantalla_a_bitmap(ram, Mem, NULL);
    pon_plataforma(p, Mem);
    m6502_trampa = NULL;
    if (getenv("SOMBRA6502_PERFIL")) j_perfil = calloc(0x10000, sizeof *j_perfil);
    if (getenv("SOMBRA6502_CATEGORIAS")) j_cat_carga(getenv("SOMBRA6502_CATEGORIAS"));
    Regs.SP = 0xFF; Regs.SR = 0x34; Regs.PC = j_inicio;
}

/* a pass of a wait: the ticks due, as the host's corre_frame gives them */
static void j_pasa(void)
{
    j_reloj += 3328;
    while (j_reloj >= j_siguiente) { j_siguiente += 3328; ++j_pendientes; }
    if (j_pendientes && Mem[PLAT_IFF]) {
        uint8_t a = Regs.AC, x = Regs.XR, y = Regs.YR, sr = Regs.SR;
        uint16_t pc = Regs.PC;
        --j_pendientes;
        ++j_ticks;
        Mem[PLAT_IFF] = 0;                              /* the acceptance (the 6502's I flag) */
        if (j_perfil) {                                 /* step it here so its addresses are counted too */
            uint8_t sp0 = Regs.SP;
            Mem[0x0100 | Regs.SP] = 0xFF; Regs.SP--;
            Mem[0x0100 | Regs.SP] = 0xFF; Regs.SP--;
            Regs.PC = j_tick;
            while (!(Regs.PC == 0x0000 && Regs.SP == sp0)) {
                uint16_t p = Regs.PC;
                uint64_t c1 = Peripherals.Counter.ClockCycles;
                ExecuteInsn();
                j_perfil[p] += Peripherals.Counter.ClockCycles - c1;
            }
        }
        else if (!m6502_llama(j_tick, a, x, y, 50000000ul)) { fprintf(stderr, "6502 GAME: sys_tick does not return\n"); exit(3); }
        Regs.AC = a; Regs.XR = x; Regs.YR = y; Regs.SR = sr; Regs.PC = pc;
    }
}

/* the 6502 game to its next frame point: 1; plat_final: 2; no frame for 400 M cycles: 0 */
static int j_corre(void)
{
    uint64_t c0 = Peripherals.Counter.ClockCycles;
    for (;;) {
        uint16_t pc = Regs.PC;
        if (!j_retoma) {
            if (pc == j_frame) { j_retoma = 1; return 1; }
            if (pc == j_pausa) { j_pasa(); j_retoma = 1; return 1; }
            if (pc == j_final) return 2;
            if (pc == j_espera) j_pasa();
            if (pc == j_nueva) j_es_nueva = 1;
        }
        j_retoma = 0;
        if (j_perfil || j_cat) {
            uint64_t c1 = Peripherals.Counter.ClockCycles;
            int k;
            ExecuteInsn();
            if (j_perfil) j_perfil[pc] += Peripherals.Counter.ClockCycles - c1;
            if (j_cat) {
                j_cat_ciclos[j_cat[pc]] += (unsigned long)(Peripherals.Counter.ClockCycles - c1);
                for (k = 0; k < j_hits; k++) if (j_hit_dir[k] == pc) j_hit_n[k]++;
            }
        }
        else ExecuteInsn();
        if (Peripherals.Counter.ClockCycles - c0 > 400000000ull) return 0;
    }
}

/* one frame of the whole game: the 6502 run over the span the Z80 just ran (pe: the platform at its start,
 * for the keyboard; r: the Z80's LD A,R in it), then compared with the Z80's memory ram and platform pz.
 * 0: stop (the 6502 is stuck or reached plat_final) */
int sombra6502_juego_frame(const uint8_t *ram, const plataforma_t *pe, const plataforma_t *pz, uint8_t r, unsigned frame)
{
    char msg[1024];
    size_t lmsg = 0;
    int i, e, mal = 0;
    unsigned k;
    uint64_t c0 = Peripherals.Counter.ClockCycles;
    memcpy(Mem + PLAT_TECLADO, pe->teclado, 10);
    Mem[PLAT_ALEATORIO] = r;
    e = j_corre();
    j_ciclos = (unsigned long)(Peripherals.Counter.ClockCycles - c0);
    if (e == 0) {
        fprintf(stderr, "6502 GAME frame %u: no frame point for 400 M cycles (PC %04X)\n", frame, Regs.PC);
        ++j_fallos;
        return 0;
    }
    if (e == 2) fprintf(stderr, "6502 GAME frame %u: plat_final reached (the ending): the memory compared there\n", frame);
    else ++j_frames;
    for (i = 0; i < nbloques && lmsg < sizeof msg - 96; ++i) {
        const bloque_t *b = &bloques[i];
        const uint8_t *ref;
        int j, excluido = 0;
        for (j = 0; j < nj_excl; ++j) if (j_excl[j] == i) excluido = 1;
        if (j_es_nueva) for (j = 0; j < nj_excl_nuevo; ++j) if (j_excl_nuevo[j] == i) excluido = 1;
        if (excluido || b->modo == 'n' || (b->cpc < 0 && b->modo != 'v')) continue;
        if (b->modo == 'v') ref = imagen;
        else { a_c64(i, ram, esperado); ref = esperado; }
        if (!memcmp(Mem + b->c64, ref + b->c64, b->len64)) continue;
        for (k = 0; k < b->len64; ++k) {
            uint16_t a = (uint16_t)(b->c64 + k);
            if (Mem[a] == ref[a]) continue;
            if (b->modo == 'c') {
                int c = campo_de[(uint16_t)(b->cpc + k)] - 1;
                if (c >= 0 && campos[c].clase == D_PILA) continue;
                if (j_no_cpc[(uint16_t)(b->cpc + k)]) continue;
                if (e == 2 && j_no_cpc_final[(uint16_t)(b->cpc + k)]) continue;   /* the ending's own differences */
            }
            lmsg += (size_t)snprintf(msg + lmsg, sizeof msg - lmsg, " [%s %04X->%04X] %02X/%02X", b->nombre,
                                     b->cpc >= 0 && b->modo == 'c' ? (unsigned)b->cpc + k : 0u, a, Mem[a], ref[a]);
            mal = 1;
            break;
        }
    }
    {
        static uint8_t pm[0x800];
        pon_plataforma(pz, pm);
        for (k = PLAT_AY; k <= PLAT_IFF && lmsg < sizeof msg - 48; ++k) {
            if (k >= PLAT_CRTC && k < PLAT_MODO) continue;
            if (Mem[k] != pm[k]) {
                lmsg += (size_t)snprintf(msg + lmsg, sizeof msg - lmsg, " [%s %u] %02X/%02X",
                                         k < PLAT_TINTAS ? "AY" : k < PLAT_CRTC ? "ink" : k == PLAT_MODO ? "mode" : "IFF",
                                         k < PLAT_TINTAS ? k - PLAT_AY : k < PLAT_CRTC ? k - PLAT_TINTAS : 0, Mem[k], pm[k]);
                mal = 1;
            }
        }
    }
    j_es_nueva = 0;
    j_final_visto = e == 2;
    if (mal) {
        ++j_fallos;
        if (j_fallos <= (unsigned long)max_fallos_6502)
            fprintf(stderr, "6502 GAME frame %u (%llu cycles, Z80 at %04X, 6502 at %04X):%s\n", frame,
                    (unsigned long long)(Peripherals.Counter.ClockCycles - c0), cpu.pc, Regs.PC, msg);
    }
    return e == 1;
}

/* the end of the host's summary line for --juego6502 */
unsigned long sombra6502_juego_fallos(void)
{
    fprintf(stderr, "; 6502 game: %lu frames, %lu with differences, %lu ticks%s", j_frames, j_fallos, j_ticks,
            j_final_visto ? ", the ending reached" : "");
    if (j_perfil) {                                     /* address, cycles: the labels are put on by a script */
        FILE *o = fopen(getenv("SOMBRA6502_PERFIL"), "w");
        unsigned a;
        if (o) {
            for (a = 0; a < 0x10000; ++a) if (j_perfil[a]) fprintf(o, "%04X\t%llu\n", a, j_perfil[a]);
            fclose(o);
        }
    }
    return j_fallos;
}
