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

/* The hybrid host of abadia64ks: the CPC 64 KiB game run by a Z80 core (z80/, superzazu, MIT) on a
 * minimal CPC (RAM, gate array, CRTC, PPI and PSG with the keyboard), in the synchronous mode of
 * tools/cpc_carga.py: the 300 Hz interrupt is delivered only at the program's wait
 * points (data/sincrono/puntos64.txt), so a run depends only on its key script.  It starts from the
 * state the simulator dumped when the game starts (PC = 20BEh: ram.bin and estado.txt).
 *
 * A "frame" is one main-loop iteration (PC = 2179h): for each one the FNV-1a 64 hash of the 64 KiB of
 * RAM is written (the same as cpc_carga.py --hashes), so both emulators can be compared frame by frame.
 * The game's functions translated to C (funciones.c, table `traducidas`) are checked in shadow:
 * each time the CPU reaches the entry of one, the machine state is saved, the C function runs (through
 * its wrapper, which maps the registers to its parameters and its results back, then RETs), its
 * result is kept, the state is restored and the Z80 original runs until it returns; the two results
 * are compared (all the RAM, SP, PC and the registers the function declares as results) and the run
 * goes on from the Z80's.  --sustituye makes the C result the one that goes on (the game run by its C
 * functions); --solo NAME limits the shadow checks to one function.
 *
 *   hibrido RAM.bin ESTADO.txt PUNTOS.txt --guion KEYS.txt --hasta FRAME [--hashes OUT.tsv]
 *           [--hash-pila N] [--ram-final F] [--sustituye] [--solo NAME] [--max-fallos N]
 *           [--cobertura F] [--accesos F] (the Z80's data reads/writes per address)
 *           [--usados6502 F] (with --juego6502 or --6502: the addresses the 6502 read / wrote / executed; usados64.py)
 *           [--solo-c] (the C functions alone: the game as it will run without the Z80, no checks)
 *           [--registra-r F] (frame and value of every LD A,R at 518Ah the Z80 runs: puro.c --r replays them)
 *           [--6502 DIR] (also the 6502 routines of c64/juego, built by its construye.sh)
 *           [--solo-6502] (with --6502: the Z80 runs everything; each of its calls of a function that has a
 *           6502 routine is checked against it)
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "z80/z80.h"
#include "juego.h"

uint8_t ram[0x10000];
z80 cpu;

/* ---- the machine -------------------------------------------------------------------------------- */

static uint8_t psg_data, psg_reg, fila, ay_regs[16];
static uint8_t paleta[17], pluma, modo, crtc_sel, crtc[32];

typedef struct { unsigned frame, frames; uint8_t fila, bit; } tecla_t;
static tecla_t teclas[8192];
static int nteclas;
static unsigned frame;
uint8_t teclas_vivas[16];                  /* a front-end's keys held now, per matrix row (bit set = down) */
void (*al_psg)(uint8_t reg, uint8_t v);    /* a front-end's sound: every AY register write */

/* --accesos: the data the Z80 reads (bit 0) and writes (bit 1) per address; the bytes of the
 * instruction being executed (its 4 bytes from its PC) are its fetch, not data */
static uint8_t *accesos;
static uint16_t pc_instruccion;
static uint8_t lee(void *u, uint16_t a)
{
    (void)u;
    if (accesos && (uint16_t)(a - pc_instruccion) >= 4) accesos[a] |= 1;
    return ram[a];
}
static void escribe(void *u, uint16_t a, uint8_t v) { (void)u; if (accesos) accesos[a] |= 2; ram[a] = v; }
static void paso(void) { pc_instruccion = cpu.pc; z80_step(&cpu); }

static uint8_t puerto_in(z80 *z, uint16_t port)
{
    (void)z;
    if ((port >> 8) == 0xF4 && psg_reg == 14) {             /* keyboard row through the PSG port A */
        uint8_t row = fila & 0x0F, held = teclas_vivas[fila & 0x0F];
        int i;
        for (i = 0; i < nteclas; ++i)
            if (teclas[i].fila == row && teclas[i].frame <= frame && frame < teclas[i].frame + teclas[i].frames)
                held |= (uint8_t)(1 << teclas[i].bit);
        return (uint8_t)~held;
    }
    return 0xFF;
}

static void puerto_out(z80 *z, uint16_t port, uint8_t v)
{
    uint8_t hi = (uint8_t)(port >> 8);
    (void)z;
    if (hi == 0xF4) {
        psg_data = v;
    } else if (hi == 0xF6) {
        fila = v;
        if ((v & 0xC0) == 0xC0) psg_reg = psg_data;
        else if ((v & 0xC0) == 0x80 && psg_reg < 16) {
            ay_regs[psg_reg] = psg_data;
            if (al_psg) al_psg(psg_reg, psg_data);
        }
    } else if ((hi & 0xC0) == 0x40) {                       /* gate array */
        if ((v & 0xC0) == 0x00) pluma = v & 0x1F;
        else if ((v & 0xC0) == 0x40) paleta[pluma > 16 ? 16 : pluma] = v & 0x1F;
        else if ((v & 0xE0) == 0x80) modo = v & 3;
    } else if (hi == 0xBC) {
        crtc_sel = v & 0x1F;
    } else if (hi == 0xBD) {
        crtc[crtc_sel] = v;
    }
}

void hibrido_pon_plataforma(const plataforma_t *p)
{
    memcpy(ay_regs, p->ay, sizeof p->ay);
    memcpy(paleta, p->paleta, sizeof p->paleta);
    memcpy(crtc, p->crtc, sizeof p->crtc);
    modo = p->modo;
    cpu.iff1 = cpu.iff2 = p->iff != 0;
}

/* the hardware state for the 6502 checks (juego.h) */
void hibrido_plataforma(plataforma_t *p)
{
    int f, i;
    memcpy(p->ay, ay_regs, sizeof p->ay);
    memcpy(p->paleta, paleta, sizeof p->paleta);
    memcpy(p->crtc, crtc, sizeof p->crtc);
    p->modo = modo;
    p->iff = cpu.iff1;
    for (f = 0; f < 10; ++f) {                       /* as puerto_in gives the rows now */
        uint8_t held = teclas_vivas[f];
        for (i = 0; i < nteclas; ++i)
            if (teclas[i].fila == f && teclas[i].frame <= frame && frame < teclas[i].frame + teclas[i].frames)
                held |= (uint8_t)(1 << teclas[i].bit);
        p->teclado[f] = (uint8_t)~held;
    }
}

/* ---- synchronous interrupts ----------------------------------------------------------------------- */

typedef struct { uint16_t salto, cabeza; int espera, pausa; unsigned us; } punto_t;
static punto_t puntos[64];
static int npuntos;
static unsigned long reloj, siguiente = 3328, pendientes, ticks;

/* the interrupt as cpc_carga.py takes it (SkoolKit's accept_interrupt): IM 1, push PC, PC = 38h */
static void interrupcion(void)
{
    cpu.sp = (uint16_t)(cpu.sp - 2);
    ram[cpu.sp] = (uint8_t)cpu.pc;
    ram[(uint16_t)(cpu.sp + 1)] = (uint8_t)(cpu.pc >> 8);
    cpu.r = (uint8_t)((cpu.r & 0x80) | ((cpu.r + 1) & 0x7F));
    cpu.pc = 0x0038;
    cpu.iff1 = cpu.iff2 = 0;
    cpu.halted = 0;
    ++ticks;
}

static unsigned pila_fuera;                 /* --hash-pila N: the N bytes below SP are left out of the hash */

/* at a frame point (the main loop's head, SP = C000h) everything below SP is dead: a run where C
 * functions replace the Z80 (which pushes return addresses and registers there) can only be compared
 * with the hash leaving them out (BF53h-BFFFh is the stack; the game's data start below, at BF49h) */
static uint64_t fnv(void)
{
    uint64_t h = 0xcbf29ce484222325ull;
    unsigned i, f0 = (unsigned)cpu.sp >= pila_fuera ? cpu.sp - pila_fuera : 0, f1 = cpu.sp;
    for (i = 0; i < 0x10000; ++i) {
        if (i >= f0 && i < f1) continue;
        h ^= ram[i]; h *= 0x100000001b3ull;
    }
    return h;
}

/* ---- shadow checks of the C functions ---------------------------------------------------------------- */

static int sustituye, max_fallos = 20;
/* --llamadas: an open-addressing table of (caller << 16 | target) + 1 -> times */
#define NLLAMADAS (1u << 20)
static uint32_t *llam_clave;
static unsigned long *llamadas;

static void anota_llamada(uint32_t k)
{
    uint32_t h = (k * 2654435761u) & (NLLAMADAS - 1);
    while (llam_clave[h] && llam_clave[h] != k + 1) h = (h + 1) & (NLLAMADAS - 1);
    llam_clave[h] = k + 1;
    ++llamadas[h];
}
static uint8_t *cubierto;                       /* executed instruction starts */
static const char *solo;
static const char *salida_llamadas, *salida_cobertura;
static FILE *salida_r;                          /* --registra-r F: the values the Z80 reads with LD A,R at 518Ah */
static unsigned long sin_frame, limite_sin_frame = 200000000ul;
static uint16_t ultimos[16];
static unsigned nult;
static unsigned long llamadas_c, fallos_c;
static uint8_t ram0[0x10000], ram_c[0x10000];

static const traducida_t *buscada(uint16_t pc)
{
    static const traducida_t *por_dir[0x10000];
    static int hecho;
    const traducida_t *t;
    int g;
    if (!hecho) {
        for (g = 0; grupos[g]; ++g)
            for (t = grupos[g]; t->nombre; ++t) {
                if (por_dir[t->dir]) { fprintf(stderr, "%04X translated twice (%s, %s)\n", t->dir, por_dir[t->dir]->nombre, t->nombre); exit(2); }
                por_dir[t->dir] = t;
            }
        hecho = 1;
    }
    return por_dir[pc];
}

/* the lowest SP seen inside the stack window below the entry SP (the dead stack after the return) */
static uint16_t sp_entrada, sp_minimo;

static void mira_sp(void)
{
    uint16_t d = (uint16_t)(sp_entrada - cpu.sp);
    if (d > 0 && d <= 0x200 && cpu.sp < sp_minimo) sp_minimo = cpu.sp;
}

/* the Z80 original of a function not translated yet, called from C: the registers are set by the
 * caller (cpu.*), a return address is pushed and the core runs until it is popped; the results are
 * in cpu.* (development only: the finished game has no such calls) */
void llama_z80(uint16_t dir)
{
    uint16_t sp0 = (uint16_t)(cpu.sp - 2), ret = 0xFFFF;
    unsigned long pasos = 0;
    cpu.sp = sp0;
    ram[sp0] = (uint8_t)ret; ram[(uint16_t)(sp0 + 1)] = (uint8_t)(ret >> 8);
    cpu.pc = dir;
    while (!(cpu.pc == ret && cpu.sp == (uint16_t)(sp0 + 2))) {
        if (cubierto) cubierto[cpu.pc] = 1;
        paso();
        mira_sp();
        if (++pasos > 50000000ul) { fprintf(stderr, "llama_z80(%04X) does not return\n", dir); exit(3); }
    }
}

/* development only: a Z80 function that may return to its caller's caller (chr_project 2632, which
 * POPs its return address and RETs to the caller of its caller when the character is in view): two
 * marks are pushed, FFFFh (the caller's caller) and FFFEh (the return address), and the core runs
 * until one of them is reached with its SP.  1 when it returned past its caller (the FFFFh mark), 0
 * when it returned normally (the FFFFh mark is dropped). */
int llama_z80_salta(uint16_t dir)
{
    uint16_t sp0 = cpu.sp;
    unsigned long pasos = 0;
    ram[(uint16_t)(sp0 - 2)] = 0xFF; ram[(uint16_t)(sp0 - 1)] = 0xFF;
    ram[(uint16_t)(sp0 - 4)] = 0xFE; ram[(uint16_t)(sp0 - 3)] = 0xFF;
    cpu.sp = (uint16_t)(sp0 - 4);
    mira_sp();
    cpu.pc = dir;
    for (;;) {
        if (cpu.pc == 0xFFFE && cpu.sp == (uint16_t)(sp0 - 2)) { cpu.sp = sp0; return 0; }
        if (cpu.pc == 0xFFFF && cpu.sp == sp0) return 1;
        if (cubierto) cubierto[cpu.pc] = 1;
        paso();
        mira_sp();
        if (++pasos > 50000000ul) { fprintf(stderr, "llama_z80_salta(%04X) does not return\n", dir); exit(3); }
    }
}

/* llama_z80 for an inline-data helper (it pops its return address, reads the bytes there and returns
 * past them): `dato` is pushed as the return address of a CALL from C, and the core runs until an exit
 * leaves SP = the entry SP + 2, with the rule of corre_z80_hasta_retorno for nested returns */
static int sale(uint16_t pc);
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
        uint8_t op = ram[pc];
        int s = sale(pc);
        if (cubierto) cubierto[pc] = 1;
        paso();
        mira_sp();
        if (cpu.sp == sp0 && sp1 == (uint16_t)(sp0 + 2)
            && (op == 0xCD || (op & 0xC7) == 0xC4 || (op & 0xC7) == 0xC7)) {
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


/* ---- the platform: the CPC's ports as the port code does them ------------------------------------ */

/* CRTC register reg := valor: OUT (&BCxx),reg selects it, OUT (&BDxx),valor writes it */
void plat_crtc(uint8_t reg, uint8_t valor)
{
    crtc_sel = reg & 0x1F;
    crtc[crtc_sel] = valor;
}

/* gate array: OUT (7Fxx),pen then OUT (7Fxx),40h|colour; OUT (7Fxx),80h-9Fh (mode) */
void plat_tinta(uint8_t pen, uint8_t colour)
{
    pluma = pen & 0x1F;
    paleta[pluma > 16 ? 16 : pluma] = colour & 0x1F;
}
void plat_modo(uint8_t m) { modo = m & 3; }

/* plat_teclado_fila: row `f` (0-9) of the CPC keyboard matrix, active low (0 = key down), read through
 * the PPI and the PSG as 2D50 sys_read_keyboard does: PSG register 14 selected (F4 <- 0Eh, F6 <- C0h |
 * the port C bits 4-5 read from F6, F6 <- those bits), PPI port A as input (F7 <- 92h), the row selected
 * with the PSG in read mode (F6 <- 40h | bits | row), the row read from F4, then port A as output again
 * (F7 <- 82h) and the PSG inactive (F6 <- bits).  2D50 selects the register once and reads the ten rows
 * in one pass; doing the whole sequence per row leaves the machine in the same state. */
uint8_t plat_teclado_fila(uint8_t f)
{
    uint8_t bits, v;
    puerto_out(&cpu, 0xF40E, 0x0E);
    bits = (uint8_t)(cpu.port_in(&cpu, 0xF60E) & 0x30);
    puerto_out(&cpu, (uint16_t)(0xF600 | bits), (uint8_t)(bits | 0xC0));
    puerto_out(&cpu, (uint16_t)(0xF600 | bits), bits);
    puerto_out(&cpu, (uint16_t)(0xF700 | bits), 0x92);
    puerto_out(&cpu, (uint16_t)(0xF600 | bits), (uint8_t)(0x40 | bits | f));
    v = cpu.port_in(&cpu, (uint16_t)(0xF400 | 0x40 | bits | f));
    puerto_out(&cpu, (uint16_t)(0xF700 | bits), 0x82);
    puerto_out(&cpu, (uint16_t)(0xF600 | bits), bits);
    return v;
}

/* the AY write of 0FBE (group objetos_sonido): PPI port A = the register, port C read back, | C0h
 * (select the register), & 3Fh (inactive), port A = the value, port C | 80h (write), port C inactive;
 * the low byte of each port address is the C register's as in the Z80 code */
void plat_psg(uint8_t reg, uint8_t v)
{
    uint8_t a, c;
    puerto_out(&cpu, (uint16_t)(0xF400 | v), reg);              /* LD B,F4h / OUT (C),A */
    a = cpu.port_in(&cpu, (uint16_t)(0xF600 | v));                 /* LD B,F6h / IN A,(C) */
    a |= 0xC0;
    puerto_out(&cpu, (uint16_t)(0xF600 | v), a);                 /* OR C0h / OUT (C),A */
    a &= 0x3F;
    puerto_out(&cpu, (uint16_t)(0xF600 | v), a);                 /* AND 3Fh / OUT (C),A */
    puerto_out(&cpu, (uint16_t)(0xF400 | v), v);                 /* LD B,F4h / OUT (C),C */
    c = a;
    puerto_out(&cpu, (uint16_t)(0xF600 | c), (uint8_t)(a | 0x80));   /* LD B,F6h / LD C,A / OR 80h / OUT (C),A */
    puerto_out(&cpu, (uint16_t)(0xF600 | c), c);                 /* OUT (C),C */
}

/* the platform's random byte: in the hybrid, the Z80 refresh register (the game's LD A,R at 518Ah; the
 * caller's wrapper brings cpu.r to the value the Z80 reads there) */
uint8_t plat_aleatorio(void) { return cpu.r; }

/* plat_di, plat_ei: the Z80's DI and EI (EI takes effect at once here: the host delivers interrupts only
 * at the wait points of the main loop) */
void plat_di(void) { cpu.iff1 = cpu.iff2 = 0; cpu.iff_delay = 0; }
void plat_ei(void) { cpu.iff1 = cpu.iff2 = 1; cpu.iff_delay = 0; }

/* the waits and the frame when C code runs them (the hybrid runs the main loop and its waits in Z80, so
 * the sessions never get here): a pass delivers the ticks as a wait point does (sys_interrupt with
 * IFF1, which the acceptance clears; R as the IM 1 acceptance counts it), a pausa pass also counts a
 * frame (no hash: the hashes are written at the Z80's frame points) */
void plat_espera(void)
{
    reloj += 3328;
    while (reloj >= siguiente) { siguiente += 3328; ++pendientes; }
    if (pendientes && cpu.iff1) {
        --pendientes;
        cpu.iff1 = cpu.iff2 = 0;
        cpu.r = (uint8_t)((cpu.r & 0x80) | ((cpu.r + 1) & 0x7F));
        ++ticks;
        sys_interrupt();
    }
}
void plat_pausa(uint16_t sp) { (void)sp; plat_espera(); ++frame; }
void plat_frame(void) { ++frame; }

/* the tape: the hybrid has none (a load fails, a save writes nothing); the ending and the debug exit
 * leave the program */
static bool motor_cinta;
void plat_cinta_motor(bool on) { motor_cinta = on; }
bool plat_cinta_carga(uint16_t fin, uint16_t len, uint8_t id) { (void)fin; (void)len; (void)id; return false; }
void plat_cinta_guarda(uint16_t fin, uint16_t len, uint8_t id) { (void)fin; (void)len; (void)id; }
void plat_final(void) { fprintf(stderr, "frame %u: the ending (loaded from the tape) is not part of the hybrid\n", frame); exit(0); }
void plat_salir(void) { fprintf(stderr, "frame %u: the game left to the ROM\n", frame); exit(0); }

/* an instruction that can leave a function: RET (C9, conditional RETs, RETI/RETN), JP (HL), JP (IX),
 * JP (IY) (the inline-data helpers return past their data) */
static int sale(uint16_t pc)
{
    uint8_t op = ram[pc], op2 = ram[(uint16_t)(pc + 1)];
    if (op == 0xC9 || (op & 0xC7) == 0xC0 || op == 0xE9) return 1;
    if (op == 0xED && (op2 & 0xC7) == 0x45) return 1;
    if ((op == 0xDD || op == 0xFD) && op2 == 0xE9) return 1;
    return 0;
}

/* the Z80 original from its entry until it returns: an exit instruction that leaves SP = entry SP + 2,
 * unless it goes to the return address that a CALL/RST of this run pushed into that entry slot: a helper
 * that pops its return address and then CALLs (the RST 08h/10h helpers 391E/38FC: POP HL / CALL 3926)
 * puts the nested return address in that same slot, and that nested RET is not the helper's return.
 * The nested callee may pop and push the word again (3926 does POP DE / PUSH DE): what counts is the
 * address the exit goes to, not the instruction that wrote the slot last. */
static void corre_z80_hasta_retorno(void)
{
    uint16_t sp0 = cpu.sp, anidado = 0;
    unsigned long pasos = 0;
    int llamada = 0;                          /* a CALL/RST of this run pushed `anidado` into the entry slot */
    for (;;) {
        uint16_t pc = cpu.pc, sp1 = cpu.sp;
        uint8_t op = ram[pc];
        int s = sale(pc);
        if (cubierto) cubierto[pc] = 1;
        paso();
        mira_sp();
        if (cpu.sp == sp0 && sp1 == (uint16_t)(sp0 + 2)
            && (op == 0xCD || (op & 0xC7) == 0xC4 || (op & 0xC7) == 0xC7)) {   /* a call pushed into the entry slot */
            llamada = 1;
            anidado = (uint16_t)(ram[sp0] | ram[(uint16_t)(sp0 + 1)] << 8);
        }
        if (s && cpu.sp == (uint16_t)(sp0 + 2)) {
            if (!(llamada && cpu.pc == anidado)) break;
            llamada = 0;                      /* the return of a nested call */
        }
        if (++pasos > 50000000ul) { fprintf(stderr, "the Z80 original does not return\n"); exit(3); }
    }
}

/* the dead stack [sp_minimo, sp_entrada) is not compared: what the Z80 pushed there (return
 * addresses, saved registers) a C function never writes */
static int muerta(unsigned i) { return i >= sp_minimo && i < sp_entrada; }

static void compara(const traducida_t *t, const z80 *cz, const z80 *zz)
{
    unsigned i, n = 0;
    char reg[128] = "";
    for (i = 0; i < 0x10000; ++i) if (ram_c[i] != ram[i] && !muerta(i)) ++n;
    if (cz->sp != zz->sp || cz->pc != zz->pc) snprintf(reg, sizeof reg, " SP/PC C %04X/%04X Z80 %04X/%04X", cz->sp, cz->pc, zz->sp, zz->pc);
    if (!n && !reg[0] && t->resultados(cz, zz, reg, sizeof reg)) return;
    ++fallos_c;
    if (fallos_c <= (unsigned long)max_fallos) {
        fprintf(stderr, "DIFF %s (%04X) frame %u call %lu: %u RAM bytes differ%s\n", t->nombre, t->dir, frame, llamadas_c, n, reg);
        for (i = 0, n = 0; i < 0x10000 && n < 12; ++i)
            if (ram_c[i] != ram[i] && !muerta(i)) { fprintf(stderr, "   %04X: C %02X  Z80 %02X  (before %02X)\n", i, ram_c[i], ram[i], ram0[i]); ++n; }
    }
}

static int solo_c;                         /* --solo-c: the C functions alone, no Z80 run, no check */

/* --6502 DIR: the game's 6502 routines checked too (m6502/sombra6502.c, linked into ./hibrido only;
 * weak, so the programs that include this file without it still link) */
void sombra6502_carga(const char *dir) __attribute__((weak));
void sombra6502_comprueba(const char *nombre, const z80 *ce, const uint8_t *ram_e, const z80 *zz, const uint8_t *ram_z,
                          const plataforma_t *pe, const plataforma_t *pz) __attribute__((weak));
unsigned long sombra6502_fallos(void) __attribute__((weak));     /* and prints the 6502 calls and differences */
static int con_6502, solo_6502;
int sombra6502_tiene(const char *nombre) __attribute__((weak));
/* --juego6502 DIR: the whole 6502 game in step with the Z80's run, compared at every frame point */
void sombra6502_juego_inicio(const char *dir, const uint8_t *ram, const plataforma_t *p) __attribute__((weak));
int sombra6502_juego_frame(const uint8_t *ram, const plataforma_t *pe, const plataforma_t *pz, uint8_t r,
                           unsigned frame) __attribute__((weak));
unsigned long sombra6502_juego_fallos(void) __attribute__((weak));
static const char *juego6502;
unsigned long sombra6502_juego_ciclos(void) __attribute__((weak));   /* the 6502 cycles of the last frame */
unsigned long *sombra6502_juego_categorias(unsigned long **hits, int *nhits) __attribute__((weak));  /* per frame, SOMBRA6502_CATEGORIAS */
void sombra6502_usados(const char *salida) __attribute__((weak));     /* --usados6502 F: the addresses the 6502 used */
void sombra6502_usados_guarda(void) __attribute__((weak));
static FILE *ciclos_frame;                 /* --ciclos-frame F: per frame the Z80's T-states (and the 6502's cycles) */
static uint8_t valor_r;                    /* the value the Z80's LD A,R at 518Ah read last (plat_aleatorio) */

/* --solo-6502: no C function runs; every entry of the Z80 into a function that has a 6502 routine is
 * checked: the Z80 runs it to its return, the 6502 routine from the same state, compared */
static void llamada_6502(const traducida_t *t)
{
    z80 c0 = cpu, zz;
    plataforma_t pe, pz;
    hibrido_plataforma(&pe);
    memcpy(ram0, ram, sizeof ram);
    sp_entrada = sp_minimo = cpu.sp;
    corre_z80_hasta_retorno();
    zz = cpu;
    hibrido_plataforma(&pz);
    sombra6502_comprueba(t->nombre, &c0, ram0, &zz, ram, &pe, &pz);
}

static void llamada_traducida(const traducida_t *t)
{
    z80 c0 = cpu, cz, zz;
    ++llamadas_c;
    plataforma_t pe, pz;
    if (solo_c) { sp_entrada = sp_minimo = cpu.sp; t->envoltorio(); return; }
    hibrido_plataforma(&pe);
    memcpy(ram0, ram, sizeof ram);
    sp_entrada = sp_minimo = cpu.sp;
    t->envoltorio();                          /* the C function: registers -> parameters -> results, RET */
    cz = cpu;
    memcpy(ram_c, ram, sizeof ram);
    memcpy(ram, ram0, sizeof ram);            /* back to the entry state: the Z80 original */
    cpu = c0;
    corre_z80_hasta_retorno();
    zz = cpu;
    compara(t, &cz, &zz);
    hibrido_plataforma(&pz);
    if (con_6502) sombra6502_comprueba(t->nombre, &c0, ram0, &zz, ram, &pe, &pz);
    if (sustituye) { memcpy(ram, ram_c, sizeof ram); cpu = cz; }
}

/* ---- set-up ----------------------------------------------------------------------------------------- */

static void carga_estado(const char *ram_file, const char *estado)
{
    FILE *f = fopen(ram_file, "rb");
    char nombre[32];
    long v;
    if (!f || fread(ram, 1, 0x10000, f) != 0x10000) { fprintf(stderr, "cannot read %s\n", ram_file); exit(1); }
    fclose(f);
    z80_init(&cpu);
    cpu.read_byte = lee; cpu.write_byte = escribe; cpu.port_in = puerto_in; cpu.port_out = puerto_out;
    f = fopen(estado, "r");
    if (!f) { fprintf(stderr, "cannot read %s\n", estado); exit(1); }
    while (fscanf(f, "%31s %ld", nombre, &v) == 2) {
        if (!strcmp(nombre, "A")) cpu.a = (uint8_t)v;
        else if (!strcmp(nombre, "F")) {
            cpu.sf = (v >> 7) & 1; cpu.zf = (v >> 6) & 1; cpu.yf = (v >> 5) & 1; cpu.hf = (v >> 4) & 1;
            cpu.xf = (v >> 3) & 1; cpu.pf = (v >> 2) & 1; cpu.nf = (v >> 1) & 1; cpu.cf = v & 1;
        }
        else if (!strcmp(nombre, "B")) cpu.b = (uint8_t)v;
        else if (!strcmp(nombre, "C")) cpu.c = (uint8_t)v;
        else if (!strcmp(nombre, "D")) cpu.d = (uint8_t)v;
        else if (!strcmp(nombre, "E")) cpu.e = (uint8_t)v;
        else if (!strcmp(nombre, "H")) cpu.h = (uint8_t)v;
        else if (!strcmp(nombre, "L")) cpu.l = (uint8_t)v;
        else if (!strcmp(nombre, "IXh")) cpu.ix = (uint16_t)((cpu.ix & 0xFF) | v << 8);
        else if (!strcmp(nombre, "IXl")) cpu.ix = (uint16_t)((cpu.ix & 0xFF00) | v);
        else if (!strcmp(nombre, "IYh")) cpu.iy = (uint16_t)((cpu.iy & 0xFF) | v << 8);
        else if (!strcmp(nombre, "IYl")) cpu.iy = (uint16_t)((cpu.iy & 0xFF00) | v);
        else if (!strcmp(nombre, "SP")) cpu.sp = (uint16_t)v;
        else if (!strcmp(nombre, "I")) cpu.i = (uint8_t)v;
        else if (!strcmp(nombre, "R")) cpu.r = (uint8_t)v;
        else if (!strcmp(nombre, "A'")) cpu.a_ = (uint8_t)v;
        else if (!strcmp(nombre, "F'")) cpu.f_ = (uint8_t)v;
        else if (!strcmp(nombre, "B'")) cpu.b_ = (uint8_t)v;
        else if (!strcmp(nombre, "C'")) cpu.c_ = (uint8_t)v;
        else if (!strcmp(nombre, "D'")) cpu.d_ = (uint8_t)v;
        else if (!strcmp(nombre, "E'")) cpu.e_ = (uint8_t)v;
        else if (!strcmp(nombre, "H'")) cpu.h_ = (uint8_t)v;
        else if (!strcmp(nombre, "L'")) cpu.l_ = (uint8_t)v;
        else if (!strcmp(nombre, "PC")) cpu.pc = (uint16_t)v;
        else if (!strcmp(nombre, "IFF")) cpu.iff1 = cpu.iff2 = v != 0;
        else if (!strcmp(nombre, "IM")) cpu.interrupt_mode = (uint8_t)v;
        else if (!strcmp(nombre, "frame")) frame = (unsigned)v;
        else if (!strcmp(nombre, "mode")) modo = (uint8_t)v;
        else if (!strcmp(nombre, "palette") || !strcmp(nombre, "crtc")) {   /* the video state, for a front-end */
            int k, n = nombre[0] == 'p' ? 17 : 16;
            uint8_t *d = nombre[0] == 'p' ? paleta : crtc;
            d[0] = (uint8_t)v;
            for (k = 1; k < n && fscanf(f, "%ld", &v) == 1; ++k) d[k] = (uint8_t)v;
        }
        else { int c; while ((c = fgetc(f)) != '\n' && c != EOF) ; }
    }
    fclose(f);
}

static void carga_puntos(const char *p)
{
    FILE *f = fopen(p, "r");
    char linea[256], tipo[16];
    unsigned cabeza, salto, us;
    if (!f) { fprintf(stderr, "cannot read %s\n", p); exit(1); }
    while (fgets(linea, sizeof linea, f)) {
        char *c = strchr(linea, '#');
        int n;
        if (c) *c = 0;
        us = 0;
        n = sscanf(linea, "%15s %x %x %u", tipo, &cabeza, &salto, &us);
        if (n < 3) continue;
        puntos[npuntos].cabeza = (uint16_t)cabeza;
        puntos[npuntos].salto = (uint16_t)salto;
        puntos[npuntos].pausa = !strcmp(tipo, "pausa");
        puntos[npuntos].espera = !strcmp(tipo, "espera") || puntos[npuntos].pausa;
        puntos[npuntos].us = us;
        ++npuntos;
    }
    fclose(f);
}

static void carga_guion(const char *p)
{
    FILE *f = fopen(p, "r");
    char linea[256];
    if (!f) { fprintf(stderr, "cannot read %s\n", p); exit(1); }
    while (fgets(linea, sizeof linea, f)) {
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

/* ---- the run ---------------------------------------------------------------------------------------- */

static unsigned long instrucciones;
void (*en_frame)(void);                    /* a front-end's hook at every frame point */
static int retoma;                         /* stopped at the main loop's head: go on without counting it again */
uint16_t parada;                           /* a front-end's stop: the CPU at this address (the ending, 31CFh) */

/* runs the machine until the next frame point (the main loop's head, or a pass of a `pausa` wait), which it
 * executes; 0 when no frame comes for --limite instructions (stuck); 2 when the CPU reaches `parada` (not
 * executed: a front-end goes on from there, e.g. the game's tape loading of the ending at 31CFh) */
static int corre_frame(FILE *fh)
{
    int i;
    for (;;) {
        uint16_t pc0 = cpu.pc;
        if (++sin_frame > limite_sin_frame) {                 /* no main-loop iteration for too long */
            unsigned k;
            fprintf(stderr, "STUCK at frame %u: %lu instructions without a frame; last PCs:", frame, sin_frame);
            for (k = 0; k < 16; ++k) fprintf(stderr, " %04X", ultimos[(nult + k) & 15]);
            fprintf(stderr, "\n  SP %04X, stack:", cpu.sp);
            for (k = 0; k < 10; ++k) fprintf(stderr, " %04X", ram[(uint16_t)(cpu.sp + 2 * k)] | ram[(uint16_t)(cpu.sp + 2 * k + 1)] << 8);
            fprintf(stderr, "\n");
            return 0;
        }
        ultimos[nult++ & 15] = pc0;
        if (parada && pc0 == parada) return 2;
        if (pc0 == 0x2179 && !retoma) {                       /* a frame: one main-loop iteration */
            sin_frame = 0;
            ++frame;
            if (fh) fprintf(fh, "%u\t%016llx\n", frame, (unsigned long long)fnv());
            if (en_frame) en_frame();
            retoma = 1;
            return 1;
        }
        retoma = 0;
        {
            const traducida_t *t = buscada(pc0);
            if (t && solo_6502) { if (sombra6502_tiene(t->nombre)) { llamada_6502(t); continue; } }
            else if (t && (!solo || !strcmp(solo, t->nombre))) { llamada_traducida(t); continue; }
        }
        if (ram[pc0] == 0x76) {                               /* HALT: a tick, as the simulator does */
            cpu.pc = (uint16_t)(pc0 + 1);
            if (cpu.iff1) { reloj = siguiente; siguiente += 3328; interrupcion(); }
            continue;
        }
        if (cubierto) cubierto[pc0] = 1;
        paso();
        ++instrucciones;
        if (pc0 == 0x518A) {                                 /* LD A,R: the value read */
            valor_r = cpu.a;
            if (salida_r) fprintf(salida_r, "%u %u\n", frame, cpu.a);
        }
        if (llamadas) {                                      /* a taken CALL or RST: the return address on the stack */
            uint8_t op = ram[pc0];
            int call = op == 0xCD || (op & 0xC7) == 0xC4, rst = (op & 0xC7) == 0xC7;
            uint16_t ret = (uint16_t)(ram[cpu.sp] | ram[(uint16_t)(cpu.sp + 1)] << 8);
            if ((call && ret == (uint16_t)(pc0 + 3) && cpu.pc != (uint16_t)(pc0 + 3)) || (rst && ret == (uint16_t)(pc0 + 1)))
                anota_llamada((uint32_t)pc0 << 16 | cpu.pc);
        }
        for (i = 0; i < npuntos; ++i) {
            if (puntos[i].salto == pc0 && cpu.pc == puntos[i].cabeza) {
                reloj += puntos[i].espera ? 3328 : puntos[i].us;
                while (reloj >= siguiente) { siguiente += 3328; ++pendientes; }
                if (pendientes && cpu.iff1) { --pendientes; interrupcion(); }
                if (puntos[i].pausa) {                       /* a pass of a wait outside the main loop: a frame */
                    sin_frame = 0;
                    ++frame;
                    if (fh) fprintf(fh, "%u\t%016llx\n", frame, (unsigned long long)fnv());
                    if (en_frame) en_frame();
                    return 1;
                }
                break;
            }
        }
    }
}

int main(int argc, char **argv)
{
    const char *hashes = NULL, *ram_final = NULL, *salida_accesos = NULL;
    unsigned hasta = 0;
    FILE *fh = NULL;
    int i;
    if (argc < 4) { fprintf(stderr, "usage: hibrido RAM.bin ESTADO.txt PUNTOS.txt --guion G --hasta F [--hashes OUT] [--ram-final F]\n"); return 2; }
    carga_estado(argv[1], argv[2]);
    carga_puntos(argv[3]);
    for (i = 4; i < argc; ++i) {
        if (!strcmp(argv[i], "--guion") && i + 1 < argc) carga_guion(argv[++i]);
        else if (!strcmp(argv[i], "--hasta") && i + 1 < argc) hasta = (unsigned)atoi(argv[++i]);
        else if (!strcmp(argv[i], "--hashes") && i + 1 < argc) hashes = argv[++i];
        else if (!strcmp(argv[i], "--hash-pila") && i + 1 < argc) pila_fuera = (unsigned)strtoul(argv[++i], 0, 0);
        else if (!strcmp(argv[i], "--ram-final") && i + 1 < argc) ram_final = argv[++i];
        else if (!strcmp(argv[i], "--sustituye")) sustituye = 1;
        else if (!strcmp(argv[i], "--solo-c")) solo_c = 1;
        else if (!strcmp(argv[i], "--6502") && i + 1 < argc) {
            if (!sombra6502_carga) { fprintf(stderr, "this build has no 6502 core\n"); return 2; }
            sombra6502_carga(argv[++i]); con_6502 = 1;
        }
        else if (!strcmp(argv[i], "--solo-6502")) solo_6502 = 1;
        else if (!strcmp(argv[i], "--ciclos-frame") && i + 1 < argc) {
            ciclos_frame = fopen(argv[++i], "w");
            fprintf(ciclos_frame, "frame\tz80_tstates\tc64_cycles\tbudget_ticks\n");
        }
        else if (!strcmp(argv[i], "--juego6502") && i + 1 < argc) {
            if (!sombra6502_juego_inicio) { fprintf(stderr, "this build has no 6502 core\n"); return 2; }
            juego6502 = argv[++i];
            sombra6502_carga(juego6502);
        }
        else if (!strcmp(argv[i], "--limite") && i + 1 < argc) limite_sin_frame = strtoul(argv[++i], 0, 0);
        else if (!strcmp(argv[i], "--llamadas") && i + 1 < argc) {
            llamadas = calloc(NLLAMADAS, sizeof *llamadas);
            llam_clave = calloc(NLLAMADAS, sizeof *llam_clave);
            salida_llamadas = argv[++i];
        }
        else if (!strcmp(argv[i], "--cobertura") && i + 1 < argc) { cubierto = calloc(0x10000, 1); salida_cobertura = argv[++i]; }
        else if (!strcmp(argv[i], "--registra-r") && i + 1 < argc) salida_r = fopen(argv[++i], "w");
        else if (!strcmp(argv[i], "--accesos") && i + 1 < argc) { accesos = calloc(0x10000, 1); salida_accesos = argv[++i]; }
        else if (!strcmp(argv[i], "--usados6502") && i + 1 < argc) {
            if (!sombra6502_usados) { fprintf(stderr, "this build has no 6502 core\n"); return 2; }
            sombra6502_usados(argv[++i]);
        }
        else if (!strcmp(argv[i], "--solo") && i + 1 < argc) solo = argv[++i];
        else if (!strcmp(argv[i], "--max-fallos") && i + 1 < argc) max_fallos = atoi(argv[++i]);
    }
    if (hashes) fh = fopen(hashes, "w");
    if (juego6502) {
        plataforma_t p;
        parada = 0x31CF;                                 /* the ending: compared where the Z80 starts its tape load */
        hibrido_plataforma(&p);
        sombra6502_juego_inicio(juego6502, ram, &p);
    }
    while (frame < hasta) {
        plataforma_t pe, pz;
        int e;
        unsigned long c0 = cpu.cyc;
        if (juego6502) hibrido_plataforma(&pe);          /* the keyboard of the span the Z80 runs now */
        e = corre_frame(fh);
        if (e != 1) {
            if (juego6502 && e == 2) {                   /* the ending (31CFh, the tape load): the 6502 to plat_final */
                hibrido_plataforma(&pz);
                (void)sombra6502_juego_frame(ram, &pe, &pz, valor_r, frame);
            }
            break;
        }
        if (juego6502) {
            hibrido_plataforma(&pz);
            if (!sombra6502_juego_frame(ram, &pe, &pz, valor_r, frame)) break;
        }
        if (ciclos_frame) {
            fprintf(ciclos_frame, "%u\t%lu\t%lu\t%u", frame, cpu.cyc - c0, juego6502 ? sombra6502_juego_ciclos() : 0ul, ram[0x21DA]);
            if (juego6502 && sombra6502_juego_categorias) {    /* the categories' cycles and the hit counts, then reset */
                unsigned long *hits, *cat;
                int nh, k;
                cat = sombra6502_juego_categorias(&hits, &nh);
                if (cat) {
                    for (k = 0; k < 16; k++) { fprintf(ciclos_frame, "\t%lu", cat[k]); cat[k] = 0; }
                    for (k = 0; k < nh; k++) { fprintf(ciclos_frame, "\t%lu", hits[k]); hits[k] = 0; }
                }
            }
            fputc('\n', ciclos_frame);
        }
    }
    if (fh) fclose(fh);
    if (salida_r) fclose(salida_r);
    if (ciclos_frame) fclose(ciclos_frame);
    if (ram_final) { FILE *f = fopen(ram_final, "wb"); fwrite(ram, 1, 0x10000, f); fclose(f); }
    if (llamadas) {
        FILE *f = fopen(salida_llamadas, "w");
        unsigned k;
        fprintf(f, "caller\ttarget\ttimes\n");
        for (k = 0; k < NLLAMADAS; ++k)
            if (llam_clave[k]) fprintf(f, "%04X\t%04X\t%lu\n", (llam_clave[k] - 1) >> 16, (llam_clave[k] - 1) & 0xFFFF, llamadas[k]);
        fclose(f);
    }
    if (cubierto) {
        FILE *f = fopen(salida_cobertura, "w");
        unsigned k;
        for (k = 0; k < 0x10000; ++k) if (cubierto[k]) fprintf(f, "%04X\n", k);
        fclose(f);
    }
    if (accesos) {                                       /* one line per address the Z80 used as data */
        FILE *f = fopen(salida_accesos, "w");
        unsigned k;
        for (k = 0; k < 0x10000; ++k) if (accesos[k]) fprintf(f, "%04X %c%c\n", k, accesos[k] & 1 ? 'r' : '-', accesos[k] & 2 ? 'w' : '-');
        fclose(f);
    }
    if (sombra6502_usados_guarda) sombra6502_usados_guarda();
    fprintf(stderr, "frames to %u, %lu instructions, %lu interrupts; C functions: %lu calls, %lu differences",
            frame, instrucciones, ticks, llamadas_c, fallos_c);
    {
        unsigned long f6 = con_6502 ? sombra6502_fallos() : 0;
        if (juego6502) f6 += sombra6502_juego_fallos();
        fprintf(stderr, "\n");
        return fallos_c || f6 ? 1 : 0;
    }
}
