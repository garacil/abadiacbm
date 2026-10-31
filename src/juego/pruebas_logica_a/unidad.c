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

/* abadia64ks, group logica_a: unit checks of the translated functions from synthetic states, for the
 * functions (or paths) the exploration sessions never reach.  Each case starts from a RAM snapshot of a
 * session (hibrido --ram-final), mutates the data the function reads and its input registers at random,
 * runs the C wrapper and the Z80 original from the same state and compares them as hibrido does (all
 * the RAM but the dead stack below the entry SP, SP, PC, the declared results).
 *   unidad SNAPSHOT.bin... [-n ITERATIONS] [-s SEED]
 * Build: pruebas_logica_a/prueba_unidad.sh (links every juego/*.c but hibrido.c, and the Z80 core). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../juego.h"
#include "../datos_logica_a.h"

uint8_t ram[0x10000];
z80 cpu;

static uint8_t lee(void *u, uint16_t a) { (void)u; return ram[a]; }
static void escribe(void *u, uint16_t a, uint8_t v) { (void)u; ram[a] = v; }
static uint8_t puerto_in(z80 *z, uint16_t port) { (void)z; (void)port; return 0xFF; }
static void puerto_out(z80 *z, uint16_t port, uint8_t v) { (void)z; (void)port; (void)v; }

void llama_z80(uint16_t dir)
{
    uint16_t sp0 = (uint16_t)(cpu.sp - 2), ret = 0xFFFF;
    unsigned long pasos = 0;
    cpu.sp = sp0;
    ram[sp0] = (uint8_t)ret; ram[(uint16_t)(sp0 + 1)] = (uint8_t)(ret >> 8);
    cpu.pc = dir;
    while (!(cpu.pc == ret && cpu.sp == (uint16_t)(sp0 + 2))) {
        z80_step(&cpu);
        if (++pasos > 50000000ul) { fprintf(stderr, "llama_z80(%04X) does not return\n", dir); exit(3); }
    }
}

/* as llama_z80_salta of hibrido.c (used by other groups' functions linked here) */
int llama_z80_salta(uint16_t dir)
{
    uint16_t sp0 = cpu.sp;
    unsigned long pasos = 0;
    ram[(uint16_t)(sp0 - 2)] = 0xFF; ram[(uint16_t)(sp0 - 1)] = 0xFF;
    ram[(uint16_t)(sp0 - 4)] = 0xFE; ram[(uint16_t)(sp0 - 3)] = 0xFF;
    cpu.sp = (uint16_t)(sp0 - 4);
    cpu.pc = dir;
    for (;;) {
        if (cpu.pc == 0xFFFE && cpu.sp == (uint16_t)(sp0 - 2)) { cpu.sp = sp0; return 0; }
        if (cpu.pc == 0xFFFF && cpu.sp == sp0) return 1;
        z80_step(&cpu);
        if (++pasos > 50000000ul) { fprintf(stderr, "llama_z80_salta(%04X) does not return\n", dir); exit(3); }
    }
}

/* as llama_z80_linea of hibrido.c: an inline-data helper called with return address `dato` */
void llama_z80_linea(uint16_t dir, uint16_t dato)
{
    uint16_t sp0 = (uint16_t)(cpu.sp - 2), anidado = 0;
    unsigned long pasos = 0;
    int llamada = 0;
    cpu.sp = sp0;
    ram[sp0] = (uint8_t)dato; ram[(uint16_t)(sp0 + 1)] = (uint8_t)(dato >> 8);
    cpu.pc = dir;
    for (;;) {
        uint16_t pc = cpu.pc, sp1 = cpu.sp;
        uint8_t op = ram[pc], op2 = ram[(uint16_t)(pc + 1)];
        int s = op == 0xC9 || (op & 0xC7) == 0xC0 || op == 0xE9 || (op == 0xED && (op2 & 0xC7) == 0x45)
                || ((op == 0xDD || op == 0xFD) && op2 == 0xE9);
        z80_step(&cpu);
        if (cpu.sp == sp0 && sp1 == (uint16_t)(sp0 + 2) && (op == 0xCD || (op & 0xC7) == 0xC4 || (op & 0xC7) == 0xC7)) {
            llamada = 1;
            anidado = (uint16_t)(ram[sp0] | ram[(uint16_t)(sp0 + 1)] << 8);
        }
        if (s && cpu.sp == (uint16_t)(sp0 + 2)) {
            if (!(llamada && cpu.pc == anidado)) break;
            llamada = 0;
        }
        if (++pasos > 50000000ul) { fprintf(stderr, "llama_z80_linea(%04X) does not return\n", dir); exit(3); }
    }
}

uint8_t plat_aleatorio(void) { return cpu.r; }

void plat_di(void) { cpu.iff1 = cpu.iff2 = 0; cpu.iff_delay = 0; }
void plat_ei(void) { cpu.iff1 = cpu.iff2 = 1; cpu.iff_delay = 0; }
/* the other groups' platform calls: linked with the merged sources, never reached by these checks */
static void no_usada(const char *f) { fprintf(stderr, "%s: not expected in the logica_a unit checks\n", f); exit(3); }
void plat_crtc(uint8_t reg, uint8_t valor) { (void)reg; (void)valor; no_usada("plat_crtc"); }
void plat_tinta(uint8_t pen, uint8_t colour) { (void)pen; (void)colour; no_usada("plat_tinta"); }
void plat_modo(uint8_t modo) { (void)modo; no_usada("plat_modo"); }
uint8_t plat_teclado_fila(uint8_t fila) { (void)fila; no_usada("plat_teclado_fila"); return 0xFF; }
void plat_psg(uint8_t reg, uint8_t v) { (void)reg; (void)v; no_usada("plat_psg"); }
void plat_frame(void) { no_usada("plat_frame"); }
void plat_espera(void) { no_usada("plat_espera"); }
void plat_pausa(uint16_t sp) { (void)sp; no_usada("plat_pausa"); }
void plat_cinta_motor(bool on) { (void)on; no_usada("plat_cinta_motor"); }
bool plat_cinta_carga(uint16_t fin, uint16_t len, uint8_t id) { (void)fin; (void)len; (void)id; no_usada("plat_cinta_carga"); return false; }
void plat_cinta_guarda(uint16_t fin, uint16_t len, uint8_t id) { (void)fin; (void)len; (void)id; no_usada("plat_cinta_guarda"); }
void plat_final(void) { no_usada("plat_final"); }
void plat_salir(void) { no_usada("plat_salir"); }

static int sale(uint16_t pc)
{
    uint8_t op = ram[pc], op2 = ram[(uint16_t)(pc + 1)];
    if (op == 0xC9 || (op & 0xC7) == 0xC0 || op == 0xE9) return 1;
    if (op == 0xED && (op2 & 0xC7) == 0x45) return 1;
    if ((op == 0xDD || op == 0xFD) && op2 == 0xE9) return 1;
    return 0;
}

/* as corre_z80_hasta_retorno of hibrido.c */
static void corre_z80_hasta_retorno(void)
{
    uint16_t sp0 = cpu.sp, nido = 0;
    unsigned long pasos = 0;
    int llamada = 0;
    for (;;) {
        uint16_t pc = cpu.pc, sp1 = cpu.sp;
        uint8_t op = ram[pc];
        int s = sale(pc);
        z80_step(&cpu);
        if (cpu.sp == sp0 && sp1 == (uint16_t)(sp0 + 2)
            && (op == 0xCD || (op & 0xC7) == 0xC4 || (op & 0xC7) == 0xC7)) {
            llamada = 1;
            nido = (uint16_t)(ram[sp0] | ram[(uint16_t)(sp0 + 1)] << 8);
        }
        if (s && cpu.sp == (uint16_t)(sp0 + 2)) {
            if (!(llamada && cpu.pc == nido)) break;
            llamada = 0;
        }
        if (++pasos > 50000000ul) { fprintf(stderr, "the Z80 original does not return\n"); exit(3); }
    }
}

/* game_check_end (3E29) is not in the table (the end screen does not return): its returning paths only */
uint8_t game_check_end(uint16_t sp);
static void w_game_check_end(void) { (void)game_check_end(cpu.sp); cpu.pc = (uint16_t)(ram[cpu.sp] | ram[(uint16_t)(cpu.sp + 1)] << 8); cpu.sp = (uint16_t)(cpu.sp + 2); }
static const traducida_t t_check_end = { 0x3E29, "game_check_end (returning paths)", w_game_check_end, sin_resultados };
static const traducida_t *busca(uint16_t dir)
{
    const traducida_t *t;
    int g;
    if (dir == 0x3E29) return &t_check_end;
    for (g = 0; grupos[g]; ++g)
        for (t = grupos[g]; t->nombre; ++t)
            if (t->dir == dir) return t;
    return NULL;
}

static unsigned long semilla = 12345;
static unsigned azar(void) { semilla = semilla * 1103515245ul + 12345ul; return (unsigned)(semilla >> 16) & 0x7FFF; }
static uint8_t a8(void) { return (uint8_t)azar(); }
static uint8_t de(const uint8_t *v, int n) { return v[azar() % (unsigned)n]; }

/* ---- the mutations of each case ---- */

static void m_check_end(void)
{
    ram[D64_GAME_GUILLERMO_DEAD] = (uint8_t)(azar() & 1);
    ram[D64_TXT_PHRASE_BUSY] = ram[D64_GAME_GUILLERMO_DEAD] ? (uint8_t)(1 + azar() % 3) : (uint8_t)(azar() & 1);
    ram[D64_GAME_CAMERA_OTHER] = a8();
}


static void m_ninguna(void) { }
static void m_lamp_reset(void)
{
    static const uint8_t v[] = { 0x00, 0x80, 0x01 };
    ram[D64_OBJ_MALACHI_HOLDER] = azar() & 1 ? de(v, 3) : a8();
    ram[D64_AI_LAMP_TIME] = azar() & 1 ? 0 : a8();
    ram[D64_AI_LAMP_TIME + 1] = azar() & 1 ? 0 : a8();
    ram[D64_OBJ_LAMP_PLACED] = a8(); ram[D64_AI_LAMP_IN_USE] = a8(); ram[D64_GAME_ADSO_LAMP] = a8();
}
static void m_key3(void) { ram[D64_OBJ_MALACHI_OBJECTS] = a8(); }
static void m_glasses(void) { ram[D64_B2_GUILLERMO_OBJECTS] = a8(); ram[D64_OBJ_BERENGAR_OBJECTS] = a8(); }
static void m_vanishes(void) { ram[D64_CHR_BERENGAR + 0x0C] = a8(); ram[D64_CHR_BERENGAR + 0x0D] = (uint8_t)(0x88 + (azar() & 3)); }
static void m_store(void) { cpu.h = (uint8_t)(0x90 + (azar() & 7)); cpu.l = a8(); cpu.d = a8(); cpu.e = a8(); }
static void m_abbot(void) { ram[D64_OBJ_ABBOT_OBJECTS] = a8(); }
static void m_lamp_placed(void) { ram[D64_OBJ_LAMP_PLACED] = azar() & 1 ? 0 : a8(); }
static void m_jorge_book(void) { ram[D64_B2_GUILLERMO_OBJECTS] = a8(); }
static void m_rise(void)
{
    ram[D64_CHR_MALACHI_RISE_DELAY] = azar() & 1 ? (uint8_t)(azar() & 0xF0) : a8();
    ram[D64_CHR_MALACHI + 4] = (uint8_t)(0x0E + (azar() & 7));
}
static void m_guillermo(void)
{
    static const uint8_t x[] = { 0x84, 0x80, 0x38, 0x20, 0x85, 0x8F, 0x30, 0x2F, 0x40 };
    static const uint8_t y[] = { 0x4B, 0x30, 0x39, 0x30, 0x4A, 0x31, 0x3F, 0x50, 0x20 };
    ram[D64_CHR_GUILLERMO + 2] = de(x, 9); ram[D64_CHR_GUILLERMO + 3] = de(y, 9);
    ram[D64_CHR_GUILLERMO + 4] = (uint8_t)(azar() % 0x10);
    ram[D64_CHR_GUILLERMO + 1] = (uint8_t)(azar() & 3);
    cpu.e = de(x, 9); cpu.d = de(y, 9);
    if (azar() & 1) { cpu.e = ram[D64_CHR_GUILLERMO + 2]; cpu.d = ram[D64_CHR_GUILLERMO + 3]; }
}
static void m_delay(void) { cpu.b = (uint8_t)(azar() & 0x3F); cpu.c = a8(); }
static void m_blink(void) { ram[D64_AI_SLEEP_ANSWER_COUNT] = a8(); }
static void m_lamp_tick(void)
{
    ram[D64_AI_LAMP_EVENT] = azar() & 1 ? 0 : a8();
    ram[D64_GAME_ADSO_LAMP] = a8(); ram[D64_AI_LAMP_IN_USE] = (uint8_t)(azar() & 1); ram[D64_ISO_ROOM_DARK] = (uint8_t)(azar() & 1);
    ram[D64_AI_LAMP_TIME] = azar() & 1 ? 0xFF : a8();
    ram[D64_AI_LAMP_TIME + 1] = (uint8_t)(azar() & 7);
}
static void m_night(void)
{
    ram[D64_AI_HOUR_FRAMES_LEFT] = azar() & 1 ? 0 : a8();
    ram[D64_AI_HOUR_FRAMES_LEFT + 1] = (uint8_t)(azar() & 3);
    ram[D64_GAME_HOUR] = (uint8_t)(azar() & 1 ? 0 : azar() % 7);
}
static void m_poison(void)
{
    ram[D64_B2_GUILLERMO_OBJECTS] = a8(); ram[D64_OBJ_ADSO_OBJECTS] = a8(); ram[D64_GAME_BONUS2] = a8();
    ram[D64_GAME_BOOK_POISON_COUNT] = azar() & 1 ? 0xFF : a8();
    ram[D64_TXT_PHRASE_BUSY] = (uint8_t)(azar() & 1);
}
static void m_percent(void)
{
    ram[D64_GAME_INVESTIGATION_OPEN] = (uint8_t)(azar() % 3);
    ram[D64_GAME_DAY] = (uint8_t)(1 + azar() % 7); ram[D64_GAME_HOUR] = (uint8_t)(azar() % 7);
    ram[D64_GAME_BONUS2] = a8(); ram[D64_GAME_BONUS] = a8();
}
static void m_parchment(void)
{
    ram[D64_AI_MONK_FLAGS] = a8(); ram[D64_B2_GUILLERMO_OBJECTS] = a8();
    ram[D64_OBJ_OBJECTS + 0x0F] = a8(); ram[D64_OBJ_OBJECTS + 0x13] = (uint8_t)(azar() % 0x20);
}
static void m_jorge_talk(void) { ram[D64_B2_GUILLERMO_OBJECTS] = a8(); ram[D64_AI_SEVERIN_STATE] = (uint8_t)(0x0B + azar() % 7); }
static void m_say(void) { ram[D64_TXT_PHRASE_BUSY] = (uint8_t)(azar() & 1); }
static void m_sound(void) { cpu.a = a8(); cpu.c = a8(); }
static void m_skip(void) { cpu.h = 0xBB; cpu.l = 0x00; cpu.b = (uint8_t)(1 + azar() % 0x30); }
static void m_camera_from(void) { cpu.b = a8(); }

typedef struct {
    uint16_t dir;
    void (*muta)(void);
    unsigned iter;            /* 0: the default */
} caso_t;

static const caso_t casos[] = {
    { 0x3B3B, m_lamp_reset, 0 }, { 0x3B66, m_key3, 0 }, { 0x3B7B, m_glasses, 0 },
    { 0x3B9C, m_ninguna, 20 }, { 0x3BAC, m_ninguna, 20 }, { 0x3BBC, m_vanishes, 0 }, { 0x3BD8, m_ninguna, 20 },
    { 0x3BE1, m_store, 0 }, { 0x3BF3, m_ninguna, 40 }, { 0x3BFD, m_abbot, 0 }, { 0x3C1B, m_ninguna, 5 },
    { 0x3C1C, m_ninguna, 5 }, { 0x3C26, m_ninguna, 5 }, { 0x3C30, m_ninguna, 5 }, { 0x3C3F, m_lamp_placed, 0 },
    { 0x3C52, m_ninguna, 5 }, { 0x3C5C, m_ninguna, 5 }, { 0x3C66, m_ninguna, 5 }, { 0x3C70, m_ninguna, 5 },
    { 0x3C7A, m_ninguna, 5 }, { 0x3D0F, m_camera_from, 0 }, { 0x3D87, m_jorge_book, 0 }, { 0x3EEF, m_rise, 0 },
    { 0x3F15, m_guillermo, 0 }, { 0x3F22, m_guillermo, 0 }, { 0x3F2D, m_guillermo, 0 }, { 0x4477, m_delay, 0 },
    { 0x4BBB, m_blink, 0 },
    /* paths of exercised functions the sessions miss */
    { 0x3D3C, m_lamp_tick, 0 }, { 0x3D6A, m_night, 0 }, { 0x3DEE, m_poison, 0 }, { 0x3DA8, m_percent, 0 },
    { 0x3F56, m_parchment, 0 }, { 0x3CAE, m_jorge_talk, 0 }, { 0x4B57, m_ninguna, 5 },
    { 0x4BDE, m_sound, 0 }, { 0x4BB2, m_skip, 0 }, { 0x4B71, m_say, 0 },
    { 0x3E29, m_check_end, 0 },
    { 0, NULL, 0 }
};

static uint8_t ram0[0x10000], ram_c[0x10000], snaps[16][0x10000];

int main(int argc, char **argv)
{
    int nsnaps = 0, i, k;
    unsigned iter = 300, total = 0, fallos = 0;
    for (i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "-n") && i + 1 < argc) iter = (unsigned)atoi(argv[++i]);
        else if (!strcmp(argv[i], "-s") && i + 1 < argc) semilla = strtoul(argv[++i], 0, 0);
        else if (nsnaps < 16) {
            FILE *f = fopen(argv[i], "rb");
            if (!f || fread(snaps[nsnaps], 1, 0x10000, f) != 0x10000) { fprintf(stderr, "cannot read %s\n", argv[i]); return 2; }
            fclose(f);
            ++nsnaps;
        }
    }
    if (!nsnaps) { fprintf(stderr, "usage: unidad SNAPSHOT.bin... [-n N] [-s SEED]\n"); return 2; }
    z80_init(&cpu);
    cpu.read_byte = lee; cpu.write_byte = escribe; cpu.port_in = puerto_in; cpu.port_out = puerto_out;
    for (k = 0; casos[k].muta; ++k) {
        const traducida_t *t = busca(casos[k].dir);
        unsigned n = casos[k].iter ? casos[k].iter : iter, it, malos = 0;
        if (!t) { fprintf(stderr, "%04X is not in the table\n", casos[k].dir); return 2; }
        for (it = 0; it < n; ++it) {
            z80 c0, cz, zz;
            char msg[256] = "";
            unsigned a, dif = 0;
            uint16_t sp = 0xBF80;
            memcpy(ram, snaps[it % (unsigned)nsnaps], sizeof ram);
            cpu.a = a8(); cpu.b = a8(); cpu.c = a8(); cpu.d = a8(); cpu.e = a8(); cpu.h = a8(); cpu.l = a8();
            cpu.cf = azar() & 1; cpu.zf = azar() & 1; cpu.sf = azar() & 1; cpu.pf = azar() & 1;
            cpu.ix = (uint16_t)(0x2968 + 0x14 * (azar() % 8)); cpu.iy = (uint16_t)(0x2B87 + 0x0F * (azar() % 6));
            cpu.sp = sp; ram[sp] = 0x79; ram[(uint16_t)(sp + 1)] = 0x21;
            cpu.iff1 = cpu.iff2 = 0;
            casos[k].muta();
            cpu.pc = t->dir;
            c0 = cpu;
            memcpy(ram0, ram, sizeof ram);
            t->envoltorio();
            cz = cpu;
            memcpy(ram_c, ram, sizeof ram);
            memcpy(ram, ram0, sizeof ram);
            cpu = c0;
            corre_z80_hasta_retorno();
            zz = cpu;
            for (a = 0; a < 0x10000; ++a)
                if (ram_c[a] != ram[a] && !(a >= (unsigned)(sp - 0x200) && a < sp)) {
                    if (dif < 4) fprintf(stderr, "   %04X: C %02X Z80 %02X (before %02X)\n", a, ram_c[a], ram[a], ram0[a]);
                    ++dif;
                }
            if (cz.sp != zz.sp || cz.pc != zz.pc) snprintf(msg, sizeof msg, " SP/PC C %04X/%04X Z80 %04X/%04X", cz.sp, cz.pc, zz.sp, zz.pc);
            if (dif || msg[0] || !t->resultados(&cz, &zz, msg, sizeof msg)) {
                ++malos;
                if (malos <= 3) fprintf(stderr, "DIFF %s (%04X) case %u: %u RAM bytes%s\n", t->nombre, t->dir, it, dif, msg);
            }
        }
        printf("%04X %-32s %5u cases, %u differences\n", t->dir, t->nombre, n, malos);
        total += n; fallos += malos;
    }
    printf("%u cases, %u differences\n", total, fallos);
    return fallos ? 1 : 0;
}
