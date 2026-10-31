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

/* abadia64ks: the CPC 64 KiB game rebuilt in C.  The data model is the CPC's memory: ds[] is the
 * 64 KiB of RAM and the addresses are the CPC 64 KiB version's (datos64.h).  Every function keeps
 * the name of the full game's function it corresponds to and cites its 64K address. */
#ifndef JUEGO_H
#define JUEGO_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

extern uint8_t ram[0x10000];
#define ds ram

static inline uint8_t rb(uint16_t a) { return ds[a]; }
static inline uint16_t rw(uint16_t a) { return (uint16_t)(ds[a] | ds[(uint16_t)(a + 1)] << 8); }
static inline void wb(uint16_t a, uint8_t v) { ds[a] = v; }
static inline void ww(uint16_t a, uint16_t v) { ds[a] = (uint8_t)v; ds[(uint16_t)(a + 1)] = (uint8_t)(v >> 8); }

/* the CPC screen (C000h-FFFFh): every access of the game goes through these (the C64 converts) */
static inline uint8_t rscr(uint16_t a) { return ds[a]; }
static inline void wscr(uint16_t a, uint8_t v) { ds[a] = v; }

/* ---- the hybrid host (hibrido.c): the Z80 registers for the wrappers.  The pure C game (JUEGO_PURO,
 * puro.c) has none of this: every f_*.c keeps its wrappers and checks under #ifndef JUEGO_PURO ---- */
#ifndef JUEGO_PURO
#include "z80/z80.h"
extern z80 cpu;
#define HL ((uint16_t)(cpu.h << 8 | cpu.l))
#define DE ((uint16_t)(cpu.d << 8 | cpu.e))
#define BC ((uint16_t)(cpu.b << 8 | cpu.c))
/* the argument is evaluated once (SET_HL(f(HL)) calls f once, before H changes) */
static inline void z80_pon_hl(uint16_t v) { cpu.h = (uint8_t)(v >> 8); cpu.l = (uint8_t)v; }
static inline void z80_pon_de(uint16_t v) { cpu.d = (uint8_t)(v >> 8); cpu.e = (uint8_t)v; }
static inline void z80_pon_bc(uint16_t v) { cpu.b = (uint8_t)(v >> 8); cpu.c = (uint8_t)v; }
#define SET_HL(v) z80_pon_hl((uint16_t)(v))
#define SET_DE(v) z80_pon_de((uint16_t)(v))
#define SET_BC(v) z80_pon_bc((uint16_t)(v))
static inline void z80_ret(void) { cpu.pc = (uint16_t)(ram[cpu.sp] | ram[(uint16_t)(cpu.sp + 1)] << 8); cpu.sp = (uint16_t)(cpu.sp + 2); }

/* a translated function: its 64K entry, its wrapper (registers in, the C function, results out, RET)
 * and the check of its results (registers it declares): 1 when C (cz) and Z80 (zz) agree, else 0
 * with a description in msg */
typedef struct {
    uint16_t dir;
    const char *nombre;
    void (*envoltorio)(void);
    int (*resultados)(const z80 *cz, const z80 *zz, char *msg, size_t n);
} traducida_t;
extern const traducida_t *const grupos[];          /* grupos.c: the tables of every group, NULL-ended */
void llama_z80(uint16_t dir);                         /* development only: run a Z80 original from C */
int llama_z80_salta(uint16_t dir);                    /* development only: one that may return to its caller's caller */
/* development only: a Z80 original that reads inline data after its CALL (and returns past it), run as if
 * called by a CALL whose return address is `dato` (the address of its inline data in the 64K code) */
void llama_z80_linea(uint16_t dir, uint16_t dato);

/* the state of the CPC hardware the game drives, for the 6502 checks (m6502/sombra6502.c): the AY's
 * registers as written, the inks (16 = border), the CRTC, the mode, the interrupt flag, the keyboard
 * matrix rows (active low) as the program reads them now */
typedef struct { uint8_t ay[16], paleta[17], crtc[16], modo, iff, teclado[10]; } plataforma_t;
void hibrido_plataforma(plataforma_t *p);
void hibrido_pon_plataforma(const plataforma_t *p);   /* sets AY, inks, CRTC, mode and IFF (not the keyboard) */

int sin_resultados(const z80 *cz, const z80 *zz, char *msg, size_t n);
int resultado_a(const z80 *cz, const z80 *zz, char *msg, size_t n);
int resultado_hl(const z80 *cz, const z80 *zz, char *msg, size_t n);
#endif

/* ---- the platform: the CPC hardware the game drives (hibrido.c does what the port code does) ---- */
void plat_crtc(uint8_t reg, uint8_t valor);           /* CRTC register reg := valor (OUT &BCxx reg, OUT &BDxx valor) */
void plat_tinta(uint8_t pen, uint8_t colour);         /* gate array: pen 0-15 (16 = border) := hardware colour 0-31 */
void plat_modo(uint8_t modo);                         /* gate array: screen mode (the game sets 1; the ROMs stay off) */
uint8_t plat_teclado_fila(uint8_t fila);              /* keyboard matrix row 0-9, active low (0 = key down) */
void plat_psg(uint8_t reg, uint8_t v);                /* AY register reg := v through the PPI ports (as 0FBE does) */
uint8_t plat_aleatorio(void);                         /* a random byte: the Z80 refresh register R (LD A,R at 518Ah) */
void plat_di(void);                                   /* DI: the 300 Hz interrupt off */
void plat_ei(void);                                   /* EI: the 300 Hz interrupt on */
/* the time: the game is synchronous with the 300 Hz interrupt only at its wait points; the platform
 * delivers each tick by calling sys_interrupt (f_principal.c) with the interrupts enabled (IFF1, which
 * the acceptance clears) */
void sys_interrupt(void);                             /* the game: the IM 1 interrupt (0038h), f_principal.c */
void plat_frame(void);                                /* 2179: the main loop's head, a frame */
void plat_espera(void);                               /* 21D6-21DB: a pass of the wait for the tick counter */
void plat_pausa(uint16_t sp);                          /* 3EB8-3EC0, 20C7-20DD: a pass of a wait that is a frame
                                                         (sp: the Z80's SP there, for the test hosts' hash) */
/* the tape (the game's own turbo code 32AB-3446; on the CPC the motor is PPI port C bit 4): a block of
 * len bytes stored downwards from `fin` with the sync byte `id` */
void plat_cinta_motor(bool on);                       /* OUT (F6xx),10h / 00h */
bool plat_cinta_carga(uint16_t fin, uint16_t len, uint8_t id);   /* true: loaded (CF = 0) */
void plat_cinta_guarda(uint16_t fin, uint16_t len, uint8_t id);
void plat_final(void);                                /* the ending loaded from the tape (CALL 6000h, again and again) */
void plat_salir(void);                                /* the debug exit's RET into the ROM: the CPC resets (never returns) */

#endif
