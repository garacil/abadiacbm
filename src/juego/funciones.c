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

/* abadia64ks: the game's functions translated to C, and the table `traducidas` of the hybrid host
 * (hibrido.c), which checks each one against its Z80 original in shadow.  Each function cites its
 * CPC 64 KiB address and the full game's function it corresponds to (c/src of the PC rebuild, which
 * documents its logic; the 64K code is the reference). */
#include <stdio.h>
#include <string.h>
#include "juego.h"

#ifndef JUEGO_PURO  /* the hybrid host */
/* ---- result checks of the wrappers ---- */

int sin_resultados(const z80 *cz, const z80 *zz, char *msg, size_t n) { (void)cz; (void)zz; (void)msg; (void)n; return 1; }

static int compara8(const char *nombre, uint8_t c, uint8_t z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %02X Z80 %02X", nombre, c, z);
    return 0;
}

static int compara16(const char *nombre, uint16_t c, uint16_t z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %04X Z80 %04X", nombre, c, z);
    return 0;
}

int resultado_a(const z80 *cz, const z80 *zz, char *msg, size_t n) { return compara8("A", cz->a, zz->a, msg, n); }
int resultado_hl(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    return compara16("HL", (uint16_t)(cz->h << 8 | cz->l), (uint16_t)(zz->h << 8 | zz->l), msg, n);
}
#endif

/* ---- the functions ---- */

/* 08E5 chr_room_distance_near (PC 1000:1111): the room distance of two coordinates, (a >> 4) - (c >> 4) + 1
 * (8 bit), "near" (carry) when below 3.  In: A, C.  Out: A, CF (CP 3: also ZF). */
uint8_t chr_room_distance_near(uint8_t a, uint8_t c, bool *near)
{
    uint8_t d = (uint8_t)((a >> 4) - (c >> 4) + 1);
    *near = d < 3;
    return d;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_08E5(void)
{
    bool near;
    uint8_t d = chr_room_distance_near(cpu.a, cpu.c, &near);
    cpu.a = d;
    cpu.c >>= 4;                     /* SRL C x 4 */
    cpu.cf = near; cpu.zf = d == 3;
    z80_ret();
}

static int r_08E5(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = compara8("A", cz->a, zz->a, msg, n);
    ok &= compara8("CF", cz->cf, zz->cf, msg, n);
    ok &= compara8("ZF", cz->zf, zz->zf, msg, n);
    return ok;
}
#endif

/* 0944 iso_grid_cell_ptr (PC 1000:116D): the address of the cell (x = L, y = H) of the 24-column height
 * buffer whose base is [28DB]: base + 24 y + x.  t = 8 y; lo = (t & FF00) | (x + t) (8-bit sum); the
 * index is 2 t + lo.  Out: IX = base + index, DE = the index, HL = lo (EX DE,HL), A = low byte of lo,
 * CF = 0. */
uint16_t iso_grid_cell_ptr(uint8_t x, uint8_t y, uint16_t *index, uint16_t *low)
{
    uint16_t t = (uint16_t)(y * 8u);
    uint16_t lo = (uint16_t)((t & 0xFF00) | (uint8_t)(x + (uint8_t)t));
    uint16_t idx = (uint16_t)(2 * t + lo);
    *index = idx;
    *low = lo;
    return (uint16_t)(rw(0x28DB) + idx);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0944(void)
{
    uint16_t idx, lo;
    uint16_t p = iso_grid_cell_ptr(cpu.l, cpu.h, &idx, &lo);
    cpu.ix = p;
    SET_DE(idx);
    SET_HL(lo);
    cpu.a = (uint8_t)lo;
    cpu.cf = 0;
    z80_ret();
}

static int r_0944(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = compara16("IX", cz->ix, zz->ix, msg, n);
    ok &= compara16("DE", (uint16_t)(cz->d << 8 | cz->e), (uint16_t)(zz->d << 8 | zz->e), msg, n);
    ok &= compara16("HL", (uint16_t)(cz->h << 8 | cz->l), (uint16_t)(zz->h << 8 | zz->l), msg, n);
    ok &= compara8("A", cz->a, zz->a, msg, n);
    ok &= compara8("CF", cz->cf, zz->cf, msg, n);
    return ok;
}

const traducida_t traducidas_base[] = {
    { 0x08E5, "chr_room_distance_near", w_08E5, r_08E5 },
    { 0x0944, "iso_grid_cell_ptr", w_0944, r_0944 },
    { 0, NULL, NULL, NULL }
};
#endif

