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

/* abadia64ks: the C64 build's 300 Hz interrupt against the checked build's, on sim65's core (juego/m6502).
 *   ticks DIR [SCENARIOS]       DIR: a build directory with both images (construye.sh: juego.bin / juego.lbl, the
 *                               checked build; C64=1 construye.sh: c64/juego.bin / c64/juego.lbl, the C64's)
 * The host checks only the checked build; the C64 build differs in sys_tick (no PHP/PHA ... PLA/PLP, no EI: the
 * interrupt's entry and RTI keep A and the flags, the I flag is set), in the phrase scroller's beep (s_pon without
 * snd_start's DI ... EI), in the platform (the real plat_psg: the SID) and in the entries the checks only use.
 * Each scenario starts both images from their own memory with the same random zero page and registers, a
 * phrase being shown (every phrase of the game in turn: what hud_say sets) and the game's sounds started by its
 * own triggers (snd_play_*) at random ticks, then gives 6000 ticks back to back (sys_tick as each build's
 * interrupt calls it).  After every tick: the same memory in both (but the code area $0800-$7150, the stack page,
 * the checked build's mirrors $07C0-$07FF, the SID $D400-$D41F, s_vec $AF-$B0 and the bytes that hold code
 * pointers, which differ between the images and must not change), the same AY writes in the same order (the
 * register and value at plat_psg's entry), X and Y kept by the C64's sys_tick, A, X, Y, the flags kept and the
 * IFF mirror at 1 by the checked one.  Exit 1 on a difference.
 * Build: gcc -O2 -I ../../../../juego/m6502 -o ticks ticks.c ../../../../juego/m6502/m6502.c ../../../../juego/m6502/6502.c */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "m6502.h"
#include "peripherals.h"

typedef struct { char nom[64]; unsigned dir; } etiqueta_t;
typedef struct { uint8_t img[0x10000], mem[0x10000]; etiqueta_t et[1024]; int n; uint16_t tick, psg; } build_t;
static build_t A, B;                    /* A: the checked build, B: the C64's */

static unsigned dir(build_t *b, const char *s)
{
    int i;
    for (i = 0; i < b->n; ++i) if (!strcmp(b->et[i].nom, s)) return b->et[i].dir;
    fprintf(stderr, "ticks: no %s\n", s); exit(2);
}
static void carga(build_t *b, const char *d, const char *sub)
{
    char p[1024], l[256]; FILE *f;
    snprintf(p, sizeof p, "%s/%sjuego.bin", d, sub);
    if (!(f = fopen(p, "rb")) || fread(b->img, 1, 0x10000, f) != 0x10000) { fprintf(stderr, "ticks: %s\n", p); exit(2); }
    fclose(f);
    snprintf(p, sizeof p, "%s/%sjuego.lbl", d, sub);
    if (!(f = fopen(p, "r"))) { fprintf(stderr, "ticks: %s\n", p); exit(2); }
    while (fgets(l, sizeof l, f) && b->n < 1024) if (sscanf(l, "al %x .%63s", &b->et[b->n].dir, b->et[b->n].nom) == 2) ++b->n;
    fclose(f);
    b->tick = (uint16_t)dir(b, "sys_tick"); b->psg = (uint16_t)dir(b, "plat_psg");
}
static unsigned simbolo(const char *d, const char *s)
{
    char p[1024], l[256], k[80]; unsigned v; FILE *f;
    snprintf(p, sizeof p, "%s/mapa64.inc", d);
    if (!(f = fopen(p, "r"))) { fprintf(stderr, "ticks: %s\n", p); exit(2); }
    while (fgets(l, sizeof l, f)) if (sscanf(l, "%79s = $%x", k, &v) == 2 && !strcmp(k, s)) { fclose(f); return v; }
    fprintf(stderr, "ticks: no %s in mapa64.inc\n", s); exit(2);
}
static unsigned semilla = 2026;
static unsigned azar(void) { semilla = semilla * 1103515245u + 12345u; return (semilla >> 16) & 0x7FFF; }

typedef struct { uint8_t a, x; } ay_t;
/* a routine of build b run on b->mem from the given registers; with lista, plat_psg's entries */
static void corre(build_t *b, uint16_t d, uint8_t a, uint8_t x, uint8_t y, uint8_t sr, ay_t *lista, int *n)
{
    unsigned long pasos = 0;
    uint8_t sp0;
    memcpy(Mem, b->mem, 0x10000);
    Regs.SP = 0xF0; Regs.AC = a; Regs.XR = x; Regs.YR = y; Regs.SR = sr;
    sp0 = Regs.SP;
    Mem[0x0100 | Regs.SP] = 0xFF; Regs.SP--;
    Mem[0x0100 | Regs.SP] = 0xFF; Regs.SP--;
    Regs.PC = d;
    if (n) *n = 0;
    while (!(Regs.PC == 0x0000 && Regs.SP == sp0)) {
        if (lista && Regs.PC == b->psg && *n < 64) { lista[*n].a = Regs.AC; lista[*n].x = Regs.XR; ++*n; }
        if (Mem[Regs.PC] == 0x02) { fprintf(stderr, "ticks: a JAM at %04X\n", Regs.PC); exit(3); }
        ExecuteInsn();
        if (++pasos > 5000000) { fprintf(stderr, "ticks: %04X does not return\n", d); exit(3); }
    }
    memcpy(b->mem, Mem, 0x10000);
}
static int fuera(unsigned a)
{
    return (a >= 0x0100 && a < 0x0200) || (a >= 0x0800 && a < 0x7151) || (a >= 0x07C0 && a < 0x0800) ||
           (a >= 0xD400 && a < 0xD420) || a == 0xAF || a == 0xB0;
}
static const char *disparos[] = { "snd_play_mirror_open", "snd_play_footstep", "snd_play_music_if_idle", "snd_play_hour_bells",
    "snd_play_tercia_bells", "snd_play_door_close", "snd_play_door_open", "snd_play_beep", "snd_play_object_taken",
    "snd_play_severino", "snd_play_object_dropped" };
#define NDISP (int)(sizeof disparos / sizeof disparos[0])

int main(int argc, char **argv)
{
    unsigned FRASES, SONIDO, VOZ, BUSY, ACTIVE, DONE, PTR, BLANKS, TIMER, k, a, s, t, NESC = argc > 2 ? (unsigned)atoi(argv[2]) : 56;
    unsigned long cA = 0, cB = 0, escrituras = 0, total = 0;
    int i, mal = 0, nA, nB;
    ay_t ayA[64], ayB[64];
    if (argc < 2) { fprintf(stderr, "ticks DIR [SCENARIOS]\n"); return 2; }
    carga(&A, argv[1], ""); carga(&B, argv[1], "c64/");
    FRASES = simbolo(argv[1], "D64_TXT_PHRASES"); SONIDO = simbolo(argv[1], "D64_TXT_PHRASE_SOUND");
    VOZ = simbolo(argv[1], "D64_SND_PHRASE_VOICE"); BUSY = simbolo(argv[1], "D64_TXT_PHRASE_BUSY");
    ACTIVE = simbolo(argv[1], "D64_TXT_PHRASE_ACTIVE"); DONE = simbolo(argv[1], "D64_TXT_WORD_DONE");
    PTR = simbolo(argv[1], "D64_TXT_PHRASE_PTR"); BLANKS = simbolo(argv[1], "D64_TXT_TRAILING_BLANKS");
    TIMER = simbolo(argv[1], "D64_TXT_SCROLL_TIMER");
    m6502_init();
    for (s = 0; s < NESC && mal < 5; ++s) {
        unsigned frase = s % 56, p = FRASES, cuando[4]; int cual[4];
        memcpy(A.mem, A.img, 0x10000); memcpy(B.mem, B.img, 0x10000);
        corre(&B, (uint16_t)dir(&B, "psg_inicio"), 0, 0, 0, 0x34, NULL, NULL);
        for (a = 0x02; a < 0x100; ++a) A.mem[a] = B.mem[a] = (uint8_t)azar();      /* the interrupted code's zero page */
        for (k = 0; k < frase; ++k) while (A.mem[p++] != 0xFF) {}                   /* hud_say(frase) */
        A.mem[VOZ] = B.mem[VOZ] = A.mem[SONIDO + frase];
        A.mem[BUSY] = B.mem[BUSY] = A.mem[ACTIVE] = B.mem[ACTIVE] = A.mem[DONE] = B.mem[DONE] = 1;
        A.mem[PTR] = B.mem[PTR] = (uint8_t)p; A.mem[PTR + 1] = B.mem[PTR + 1] = (uint8_t)(p >> 8);
        A.mem[BLANKS] = B.mem[BLANKS] = 0;
        A.mem[TIMER] = B.mem[TIMER] = (uint8_t)(azar() % 0x2D);
        for (k = 0; k < 4; ++k) { cuando[k] = azar() % 3000; cual[k] = (int)(azar() % NDISP); }
        for (t = 0; t < 6000 && mal < 5; ++t) {
            uint8_t ra = (uint8_t)azar(), rx = (uint8_t)azar(), ry = (uint8_t)azar(), sr = (uint8_t)(0x34 | (azar() & 0xC3));
            for (k = 0; k < 4; ++k) if (cuando[k] == t) {                           /* the main code starts a sound */
                corre(&A, (uint16_t)dir(&A, disparos[cual[k]]), 0, 0, 0, 0x30, NULL, NULL);
                corre(&B, (uint16_t)dir(&B, disparos[cual[k]]), 0, 0, 0, 0x30, NULL, NULL);
            }
            A.mem[0x07FC] = 0;                                                       /* the host's acceptance */
            { uint64_t c0 = Peripherals.Counter.ClockCycles;
              corre(&A, A.tick, ra, rx, ry, sr, ayA, &nA); cA += Peripherals.Counter.ClockCycles - c0; }
            if (Regs.AC != ra || Regs.XR != rx || Regs.YR != ry || (Regs.SR & 0xCF) != (sr & 0xCF) || A.mem[0x07FC] != 1) {
                printf("scenario %u tick %u: the checked sys_tick left A %02X X %02X Y %02X P %02X IFF %d\n", s, t, Regs.AC,
                       Regs.XR, Regs.YR, Regs.SR, A.mem[0x07FC]); ++mal; }
            { uint64_t c0 = Peripherals.Counter.ClockCycles;
              corre(&B, B.tick, ra, rx, ry, 0x34, ayB, &nB); cB += Peripherals.Counter.ClockCycles - c0; }
            if (Regs.XR != rx || Regs.YR != ry || !(Regs.SR & 0x04)) {
                printf("scenario %u tick %u: the C64's sys_tick left X %02X Y %02X I %d\n", s, t, Regs.XR, Regs.YR, !!(Regs.SR & 4)); ++mal; }
            if (nA != nB) { printf("scenario %u tick %u: %d AY writes against %d\n", s, t, nA, nB); ++mal; }
            else for (i = 0; i < nA; ++i) if (ayA[i].a != ayB[i].a || ayA[i].x != ayB[i].x) {
                printf("scenario %u tick %u: AY write %d %02X,%02X against %02X,%02X\n", s, t, i, ayA[i].a, ayA[i].x, ayB[i].a, ayB[i].x); ++mal; break; }
            escrituras += (unsigned long)nA; ++total;
            for (a = 0; a < 0x10000; ++a) {
                if (fuera(a)) continue;
                if (A.img[a] == B.img[a] ? A.mem[a] != B.mem[a] : (A.mem[a] != A.img[a] || B.mem[a] != B.img[a])) {
                    printf("scenario %u tick %u: [%04X] %02X against %02X\n", s, t, a, A.mem[a], B.mem[a]); ++mal; break; }
            }
        }
    }
    printf("ticks: %u scenarios, %lu ticks, %lu AY writes; cycles a tick: the checked build %.1f, the C64 build %.1f "
           "(its sys_tick and the real plat_psg, without plat_irq's 56); %s\n", s, total, escrituras,
           (double)cA / (double)total, (double)cB / (double)total, mal ? "DIFFERENCES" : "the same");
    return mal != 0;
}
