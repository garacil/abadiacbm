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

/* juego.h for measuring src/juego/f_*.c with cc65 (mide_juego.py): the same names, the CPC memory as an
 * external array (not linked), the accessors as macros, a plain Z80 register struct for the wrappers
 * (which are counted apart: only the game's functions matter for the C64). */
#ifndef JUEGO_H
#define JUEGO_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
extern uint8_t ram[];
#define ds ram
#define rb(a) (ds[(uint16_t)(a)])
#define rw(a) ((uint16_t)(ds[(uint16_t)(a)] | ds[(uint16_t)((a) + 1)] << 8))
#define wb(a, v) (ds[(uint16_t)(a)] = (uint8_t)(v))
#define ww(a, v) mide_ww((uint16_t)(a), (uint16_t)(v))
void __fastcall__ mide_ww(uint16_t a, uint16_t v);
#define rscr(a) (ds[(uint16_t)(a)])
#define wscr(a, v) (ds[(uint16_t)(a)] = (uint8_t)(v))
typedef struct z80 {
    unsigned long cyc;
    uint16_t pc, sp, ix, iy, mem_ptr;
    uint8_t a, b, c, d, e, h, l, a_, b_, c_, d_, e_, h_, l_, f_, i, r;
    uint8_t sf, zf, yf, hf, xf, pf, nf, cf, iff_delay, interrupt_mode, int_data, iff1, iff2, halted;
} z80;
extern z80 cpu;
#define HL ((uint16_t)(cpu.h << 8 | cpu.l))
#define DE ((uint16_t)(cpu.d << 8 | cpu.e))
#define BC ((uint16_t)(cpu.b << 8 | cpu.c))
void z80_pon_hl(uint16_t v);
void z80_pon_de(uint16_t v);
void z80_pon_bc(uint16_t v);
#define SET_HL(v) z80_pon_hl((uint16_t)(v))
#define SET_DE(v) z80_pon_de((uint16_t)(v))
#define SET_BC(v) z80_pon_bc((uint16_t)(v))
void z80_ret(void);
void z80_step(z80 *z);
typedef struct {
    uint16_t dir;
    const char *nombre;
    void (*envoltorio)(void);
    int (*resultados)(const z80 *cz, const z80 *zz, char *msg, size_t n);
} traducida_t;
extern const traducida_t *const grupos[];
void llama_z80(uint16_t dir);
int llama_z80_salta(uint16_t dir);
void plat_crtc(uint8_t reg, uint8_t valor);
void plat_tinta(uint8_t pen, uint8_t colour);
void plat_modo(uint8_t modo);
uint8_t plat_teclado_fila(uint8_t fila);
void plat_psg(uint8_t reg, uint8_t v);
void plat_di(void);
void plat_ei(void);
uint8_t plat_aleatorio(void);
void plat_frame(void);
void plat_espera(void);
void plat_pausa(uint16_t sp);
void plat_cinta_motor(bool on);
bool plat_cinta_carga(uint16_t fin, uint16_t len, uint8_t id);
void plat_cinta_guarda(uint16_t fin, uint16_t len, uint8_t id);
void plat_final(void);
void plat_salir(void);
void llama_z80_linea(uint16_t dir, uint16_t dato);
int sin_resultados(const z80 *cz, const z80 *zz, char *msg, size_t n);
int resultado_a(const z80 *cz, const z80 *zz, char *msg, size_t n);
int resultado_hl(const z80 *cz, const z80 *zz, char *msg, size_t n);
#endif
