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

/* Synthetic checks of the group principal (f_principal.c) that no session reaches: the CTRL+TAB menu
 * (ESC, and S: the save), the save and the restore of a game, its checksum, the blinking mark, the
 * delays, the motor, and the tape blocks' bookkeeping.  The hybrid host's machinery (hibrido.c included)
 * from a RAM image of session 1, frame 3000: every case runs the C function and the Z80 original from
 * the same state and the RAM is compared (the stack below the entry SP left out, and the operands the
 * Z80 tape code keeps for itself, 33E1h, 33E3h, 3344h, 3438h: the platform's in C).  The Z80 runs to its
 * return, or to the address where the C function's caller goes on (2FEF: 2151h). */
#define main hibrido_main
#include "../hibrido.c"
#undef main
#include "../juego64.h"

static uint8_t base_ram[0x10000];
static z80 base_cpu;
static unsigned long casos, fallos;

/* the keys by the number of reads of each row: patron[row][n] = the bits down at the n-th read (the last
 * one stays); read 0 is the set-up's (a CALL 2D50 before the case), the compared runs start at read 1 */
static unsigned lecturas[16];
static const uint8_t *patron[16];
static unsigned largo[16];
static uint8_t mi_puerto(z80 *z, uint16_t port)
{
    uint8_t v = puerto_in(z, port);
    unsigned f = fila & 0x0F;
    if ((port >> 8) == 0xF4 && psg_reg == 14 && patron[f]) {
        unsigned n = lecturas[f] < largo[f] ? lecturas[f] : largo[f] - 1;
        v = (uint8_t)~patron[f][n];
        ++lecturas[f];
    }
    return v;
}

static void teclas_por_lectura(unsigned f, const uint8_t *bits, unsigned n) { patron[f] = bits; largo[f] = n; }
static void sin_teclas(void) { memset(patron, 0, sizeof patron); memset(largo, 0, sizeof largo); }

static void desde_base(void) { memcpy(ram, base_ram, sizeof ram); cpu = base_cpu; sin_teclas(); memset(lecturas, 0, sizeof lecturas); }

static int fuera(unsigned a, uint16_t sp)
{
    if (a < sp && a >= (unsigned)sp - 0x200u) return 1;      /* the dead stack */
    return a == 0x33E1 || a == 0x33E3 || a == 0x3344 || a == 0x3438;
}

static unsigned cambiados(const uint8_t *antes)
{
    unsigned i, n = 0;
    for (i = 0; i < 0x10000; ++i) n += antes[i] != ram[i];
    return n;
}

/* the C function c (with the registers in cpu) against the Z80 from `dir` to its return (hasta = 0) or
 * to PC == hasta */
static void compara_caso(const char *nombre, uint16_t dir, void (*c)(void), uint16_t hasta)
{
    static uint8_t ram0[0x10000], rc[0x10000];
    z80 c0;
    unsigned i, n = 0;
    unsigned long pasos = 0;
    uint16_t sp;
    cpu.sp = (uint16_t)(cpu.sp - 2);
    ram[cpu.sp] = 0x79; ram[(uint16_t)(cpu.sp + 1)] = 0x21;     /* called from the main loop (2179) */
    sp = cpu.sp;
    c0 = cpu;
    memcpy(ram0, ram, sizeof ram);
    for (i = 0; i < 16; ++i) lecturas[i] = 1;
    c();
    memcpy(rc, ram, sizeof ram);
    memcpy(ram, ram0, sizeof ram);
    cpu = c0;
    for (i = 0; i < 16; ++i) lecturas[i] = 1;
    cpu.pc = dir;
    if (hasta) {
        while (cpu.pc != hasta) {
            z80_step(&cpu);
            if (++pasos > 200000000ul) { printf("%s: the Z80 does not reach %04X\n", nombre, hasta); exit(3); }
        }
    } else {
        corre_z80_hasta_retorno();
    }
    for (i = 0; i < 0x10000; ++i)
        if (rc[i] != ram[i] && !fuera(i, sp)) {
            if (n < 8) printf("   %s %04X: C %02X Z80 %02X (before %02X)\n", nombre, i, rc[i], ram[i], ram0[i]);
            ++n;
        }
    ++casos;
    if (n) { ++fallos; printf("DIFF %s: %u bytes\n", nombre, n); }
    else printf("%-28s same RAM; %u bytes changed; row 8 read %u times; [0C07] %02X [2913] %04X [855A] %02X\n", nombre,
                cambiados(ram0), lecturas[8] - 1, ram[0x0C07], ram[0x2913] | ram[0x2914] << 8, ram[0x855A]);
}

/* the C sides */
static void c_gather(void) { game_state_gather(); }
static void c_restore(void) { game_state_restore(); }
static void c_checksum(void) { uint16_t hl; (void)game_state_checksum(&hl); }
static void c_marca(void) { hud_tape_marker_swap(); }
static void c_retardo(void) { util_delay_units(cpu.a); }
static void c_motor_on(void) { tape_motor_on(); }
static void c_motor_off(void) { tape_motor_off(); }
static void c_salida(void) { tape_menu_leave(); }
static void c_menu(void) { (void)sys_tape_menu(cpu.sp); }
static void c_interrupcion(void) { sys_interrupt(); }

int main(void)
{
    const char *T = getenv("ABADIA64_TRABAJO") ? getenv("ABADIA64_TRABAJO") : "/home/german/proyectos/abadia64ks/trabajo";
    char p1[256], p2[256];
    unsigned k;
    static const uint8_t tab_esc[] = { 0x10, 0x04, 0x00 };   /* row 8: TAB (bit 4), then ESC (bit 2), then up */
    static const uint8_t ctrl[] = { 0x80 };                  /* row 2: CTRL (bit 7) */
    static const uint8_t tab[] = { 0x10, 0x00 };             /* row 8: TAB, then nothing */
    static const uint8_t s_tecla[] = { 0x00, 0x10, 0x00 };   /* row 7: S (bit 4) at the menu's first read */
    snprintf(p1, sizeof p1, "%s", getenv("SINTETICA_RAM") ? getenv("SINTETICA_RAM") : "r3000.bin");
    snprintf(p2, sizeof p2, "%s/cpc64/inicio_juego/estado.txt", T);
    carga_estado(p1, p2);
    cpu.sp = 0xC000;
    cpu.port_in = mi_puerto;
    memcpy(base_ram, ram, sizeof ram);
    base_cpu = cpu;

    desde_base(); compara_caso("game_state_gather", 0x2FD7, c_gather, 0);
    for (k = 0; k < 3; ++k) {                               /* a buffer: the state of this game, changed */
        desde_base();
        game_state_gather();
        ram[0x7F80 + 0x10 + k] ^= 0x5A; ram[0x7F80 + 0x338 + k] ^= 0x33; ram[0x7F80 + 0x400 + k] ^= 0x81;
        ram[0x2B8D] = (uint8_t)(k & 1); ram[0x2B9C] = (uint8_t)(k >> 1);
        ram[0x290D] = (uint8_t)k;
        compara_caso("game_state_restore", 0x2FEF, c_restore, 0x2151);
    }
    desde_base(); compara_caso("game_state_checksum", 0x3254, c_checksum, 0);
    desde_base(); compara_caso("hud_tape_marker_swap", 0x3276, c_marca, 0);
    desde_base(); cpu.a = 1; compara_caso("util_delay_units", 0x31C1, c_retardo, 0);
    desde_base(); compara_caso("tape_motor_on", 0x329A, c_motor_on, 0);
    desde_base(); compara_caso("tape_motor_off", 0x3293, c_motor_off, 0);
    desde_base(); compara_caso("tape_menu_leave", 0x3262, c_salida, 0);
    desde_base(); compara_caso("sys_interrupt", 0x0038, c_interrupcion, 0);

    /* the menu: no TAB; TAB without CTRL; TAB + CTRL then ESC; TAB + CTRL then S (the save) */
    desde_base(); llama_z80(0x2D50); compara_caso("sys_tape_menu (no key)", 0x31DF, c_menu, 0);
    desde_base(); teclas_por_lectura(8, tab, 2); llama_z80(0x2D50);
    compara_caso("sys_tape_menu (TAB alone)", 0x31DF, c_menu, 0);
    desde_base(); teclas_por_lectura(8, tab_esc, 3); teclas_por_lectura(2, ctrl, 1); llama_z80(0x2D50);
    compara_caso("sys_tape_menu (ESC)", 0x31DF, c_menu, 0);
    desde_base(); teclas_por_lectura(8, tab, 2); teclas_por_lectura(2, ctrl, 1); teclas_por_lectura(7, s_tecla, 3);
    llama_z80(0x2D50);
    compara_caso("sys_tape_menu (S: save)", 0x31DF, c_menu, 0);

    printf("%lu synthetic cases, %lu with differences\n", casos, fallos);
    return fallos ? 1 : 0;
}
