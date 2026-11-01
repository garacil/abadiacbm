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

/* abadia64ks: the host of the game in pure C (no Z80 core) for GNU programs: the platform of the
 * synchronous mode (as hibrido.c and data/sincrono/puntos64.txt) and the game run frame by frame.
 *
 *  - a frame is the main loop's head (plat_frame, 2179h) or a pass of a `pausa` wait (plat_pausa: the end
 *    of a game, 3EB8-3EC0, and a new game, 20C7-20DD); its FNV-1a 64 hash of the 64 KiB leaves out the
 *    0xADh bytes below the Z80's SP there, as `hibrido --hash-pila 0xAD` does: BF53h-BFFFh at the main
 *    loop's head (SP = C000h) and at the new game's wait, BF51h-BFFDh at the end-of-game wait, inside 3E29
 *    (SP = BFFEh: the CALL's return address, which game_main writes as the Z80 pushes it, is part of those
 *    frames);
 *  - each pass of a wait (plat_espera at 21D6-21DB, plat_pausa) is 3328 us, one tick of the 300 Hz
 *    interrupt: due ticks are counted and one is delivered per pass when the interrupts are enabled (the
 *    game's sys_interrupt; IFF1 cleared first, as the IM 1 acceptance does); at a pausa pass the frame is
 *    taken before the interrupt runs, as the hybrid takes it at the wait's jump;
 *  - the keys: a front-end's teclas_vivas and the --guion keys by the frame counter;
 *  - LD A,R at 518Ah (plat_aleatorio, the mirror numeral): the values a Z80 run read, replayed
 *    (carga_aleatorios; the Z80's refresh register cannot be known in C; a real platform gives a random
 *    byte);
 *  - the tape: a directory where a block is saved as bloque_II.bin (II = its sync byte, the bytes from the
 *    block's end downwards, the order the turbo code moves them) and loaded back; the ending's block (2Ah,
 *    6000h-8BFFh) from the image of the tape's ending; without them a load fails (no cassette).
 *
 * The game (game_main, 20BEh) never returns: it runs as a coroutine (ucontext) that gives the control back
 * at every frame point, at the ending's tape loading (31CFh) and at the debug exit; corre_frame resumes it.
 * This is host machinery: the game code knows nothing of it (a C64 runs game_main as its main). */
#define _XOPEN_SOURCE 700
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ucontext.h>
#include "puro_host.h"

uint8_t ram[0x10000];

uint8_t paleta[17], modo, crtc[32];
uint8_t teclas_vivas[16];
void (*al_psg)(uint8_t reg, uint8_t v);
void (*en_frame)(void);
unsigned frame;
unsigned long ticks;

static int iff1;
static bool motor;
static uint16_t sp_juego = 0xC000;            /* the SP the game is started with: the main loop's */
static unsigned long reloj, siguiente = 3328, pendientes;
static const char *dir_cinta, *final_bin;

static tecla_t teclas[8192];
static int nteclas;
static uint8_t aleatorios[4096];
static unsigned naleatorios, ialeatorio;

/* ---- the coroutine ---- */
static ucontext_t ctx_host, ctx_juego;
static char *pila_juego;
#define PILA_JUEGO (4u << 20)
static int arrancado, salida, resultado;
static FILE *fh_actual;
static int salta_final;

static void cede(int r)
{
    resultado = r;
    swapcontext(&ctx_juego, &ctx_host);
}

static void juego(void)
{
    game_main(sp_juego);                      /* never returns */
    salida = 1;
    cede(0);
}

int corre_frame(FILE *fh)
{
    fh_actual = fh;
    if (salida) return 0;
    if (!arrancado) {
        pila_juego = malloc(PILA_JUEGO);
        if (!pila_juego) { fprintf(stderr, "no memory for the game's stack\n"); exit(1); }
        getcontext(&ctx_juego);
        ctx_juego.uc_stack.ss_sp = pila_juego;
        ctx_juego.uc_stack.ss_size = PILA_JUEGO;
        ctx_juego.uc_link = NULL;
        makecontext(&ctx_juego, juego, 0);
        arrancado = 1;
    }
    swapcontext(&ctx_host, &ctx_juego);
    return resultado;
}

void puro_salta_final(void) { salta_final = 1; }

/* ---- the frames and the waits ---- */

/* FNV-1a 64 of the 64 KiB without the 0xADh bytes below sp (the host may use 64-bit types) */
static unsigned long long fnv(uint16_t sp)
{
    unsigned long long h = 0xcbf29ce484222325ull;
    unsigned i, f0 = sp >= 0xAD ? (unsigned)sp - 0xAD : 0;
    for (i = 0; i < 0x10000; ++i) {
        if (i >= f0 && i < sp) continue;
        h ^= ram[i];
        h *= 0x100000001b3ull;
    }
    return h;
}

/* a frame: its hash, the front-end's hook, the control back to corre_frame's caller */
static void un_frame(uint16_t sp)
{
    ++frame;
    if (fh_actual) fprintf(fh_actual, "%u\t%016llx\n", frame, fnv(sp));
    if (en_frame) en_frame();
    cede(1);
}

/* a pass of a wait: 3328 us; true when a tick is to be delivered now */
static bool un_paso(void)
{
    reloj += 3328;
    while (reloj >= siguiente) { siguiente += 3328; ++pendientes; }
    if (pendientes && iff1) { --pendientes; iff1 = 0; ++ticks; return true; }
    return false;
}

void plat_frame(void)
{
    un_frame(sp_juego);
    if (salta_final) {                        /* as 3E29h at 100 %: the cursor at 8006h (3E8Dh), then 3EC6h */
        salta_final = 0;
        ww(0x28E8, 0x8006);                   /* txt_cursor */
        game_ending((uint16_t)(sp_juego - 2));
    }
}
void plat_espera(void) { if (un_paso()) sys_interrupt(); }
void plat_pausa(uint16_t sp)
{
    bool tick = un_paso();
    un_frame(sp);
    if (tick) sys_interrupt();
}

/* ---- the machine ---- */

void plat_di(void) { iff1 = 0; }
void plat_ei(void) { iff1 = 1; }

void plat_crtc(uint8_t reg, uint8_t valor) { crtc[reg & 0x1F] = valor; }
void plat_tinta(uint8_t pen, uint8_t colour) { paleta[(pen & 0x1F) > 16 ? 16 : (pen & 0x1F)] = (uint8_t)(colour & 0x1F); }
void plat_modo(uint8_t m) { modo = (uint8_t)(m & 3); }
void plat_psg(uint8_t reg, uint8_t v) { if (al_psg && reg < 16) al_psg(reg, v); }

uint8_t plat_teclado_fila(uint8_t f)
{
    uint8_t held = teclas_vivas[f & 0x0F];
    int i;
    for (i = 0; i < nteclas; ++i)
        if (teclas[i].fila == (f & 0x0F) && teclas[i].frame <= frame && frame < teclas[i].frame + teclas[i].frames)
            held |= (uint8_t)(1 << teclas[i].bit);
    return (uint8_t)~held;
}

uint8_t plat_aleatorio(void)
{
    if (ialeatorio < naleatorios) return aleatorios[ialeatorio++];
    fprintf(stderr, "frame %u: LD A,R at 518Ah with no recorded value: 0\n", frame);
    return 0;
}

/* ---- the tape ---- */

void plat_cinta_motor(bool on) { motor = on; }

static FILE *bloque(uint8_t id, const char *modo_f)
{
    char nombre[1024];
    if (!dir_cinta) return NULL;
    snprintf(nombre, sizeof nombre, "%s/bloque_%02X.bin", dir_cinta, id);
    return fopen(nombre, modo_f);
}

bool plat_cinta_carga(uint16_t fin, uint16_t len, uint8_t id)
{
    static uint8_t buf[0x10000];
    FILE *f;
    unsigned i;
    if (id == 0x2A) {                         /* the ending's block (31CFh): a front-end shows the ending */
        cede(2);
        if (!final_bin) return false;
        f = fopen(final_bin, "rb");
        if (!f || fread(buf, 1, 0x10000, f) != 0x10000) { if (f) fclose(f); return false; }
        fclose(f);
        for (i = 0; i < len; ++i) ram[(uint16_t)(fin - i)] = buf[(uint16_t)(fin - i)];
        return true;
    }
    f = bloque(id, "rb");
    if (!f) return false;
    if (fread(buf, 1, len, f) != len) { fclose(f); return false; }
    fclose(f);
    for (i = 0; i < len; ++i) ram[(uint16_t)(fin - i)] = buf[i];
    return true;
}

void plat_cinta_guarda(uint16_t fin, uint16_t len, uint8_t id)
{
    FILE *f = bloque(id, "wb");
    unsigned i;
    if (!f) return;
    for (i = 0; i < len; ++i) fputc(ram[(uint16_t)(fin - i)], f);
    fclose(f);
}

/* the ending's program (CALL 6000h, again and again): the front-end's; here the game stays at its ending */
void plat_final(void) { cede(2); }
void plat_salir(void) { salida = 1; cede(0); for (;;) cede(0); }

void puro_cinta(const char *dir) { dir_cinta = dir; }
void puro_final(const char *f) { final_bin = f; }

/* ---- set-up ---- */

/* my licence header at the top of a data file: its '#' lines, skipped before an fscanf reading */
static void salta_cabecera(FILE *f)
{
    int c;
    while ((c = fgetc(f)) == '#') while ((c = fgetc(f)) != '\n' && c != EOF) ;
    if (c != EOF) ungetc(c, f);
}

void carga_estado(const char *ram_file, const char *estado)
{
    FILE *f = fopen(ram_file, "rb");
    char nombre[32];
    long v;
    uint16_t pc = 0x20BE;
    if (!f || fread(ram, 1, 0x10000, f) != 0x10000) { fprintf(stderr, "cannot read %s\n", ram_file); exit(1); }
    fclose(f);
    f = fopen(estado, "r");
    if (!f) { fprintf(stderr, "cannot read %s\n", estado); exit(1); }
    salta_cabecera(f);
    while (fscanf(f, "%31s %ld", nombre, &v) == 2) {
        if (!strcmp(nombre, "SP")) sp_juego = (uint16_t)v;
        else if (!strcmp(nombre, "PC")) pc = (uint16_t)v;
        else if (!strcmp(nombre, "IFF")) iff1 = v != 0;
        else if (!strcmp(nombre, "frame")) frame = (unsigned)v;
        else if (!strcmp(nombre, "mode")) modo = (uint8_t)v;
        else if (!strcmp(nombre, "palette") || !strcmp(nombre, "crtc")) {
            int k, n = nombre[0] == 'p' ? 17 : 16;
            uint8_t *d = nombre[0] == 'p' ? paleta : crtc;
            d[0] = (uint8_t)v;
            for (k = 1; k < n && fscanf(f, "%ld", &v) == 1; ++k) d[k] = (uint8_t)v;
        }
        else { int c; while ((c = fgetc(f)) != '\n' && c != EOF) ; }
    }
    fclose(f);
    if (pc != 0x20BE) { fprintf(stderr, "%s: PC %04X: the pure C game starts at 20BEh only\n", estado, pc); exit(1); }
}

void carga_puntos(const char *p) { (void)p; }

void carga_guion(const char *p)
{
    FILE *f = fopen(p, "r");
    char linea[256];
    if (!f) { fprintf(stderr, "cannot read %s\n", p); exit(1); }
    while (fgets(linea, sizeof linea, f) && nteclas < (int)(sizeof teclas / sizeof teclas[0])) {
        unsigned fr, fi, bi, d = 15;
        char *c = strchr(linea, '#');
        if (c) *c = 0;
        if (sscanf(linea, "%u %u:%u %u", &fr, &fi, &bi, &d) < 3) continue;
        teclas[nteclas].frame = fr; teclas[nteclas].fila = (uint8_t)fi;
        teclas[nteclas].bit = (uint8_t)bi; teclas[nteclas].frames = d;
        ++nteclas;
    }
    fclose(f);
}

void carga_aleatorios(const char *p)
{
    FILE *f = fopen(p, "r");
    unsigned fr, v;
    if (!f) { fprintf(stderr, "cannot read %s\n", p); exit(1); }
    salta_cabecera(f);
    while (naleatorios < sizeof aleatorios && fscanf(f, "%u %u", &fr, &v) == 2) aleatorios[naleatorios++] = (uint8_t)v;
    fclose(f);
}
