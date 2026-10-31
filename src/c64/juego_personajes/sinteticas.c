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

/* abadia64ks, group personajes: synthetic checks of the 6502 paths the exploration sessions never reach
 * (comprueba.sh lists them: the dark room and its light, Guillermo's fall after the mirror trap, the stairs
 * frames of chr_project, the 1-cell command 1 and the restart of a 2x2 command stream, the library's height
 * buffer, the mirror's Q+R, the flips of Malachi and Berengar).  It is the hybrid host (juego/hibrido.c,
 * included with its main renamed): the game runs a session to a frame, its state is kept, and for every case
 * the state is restored, changed as the case says, and the function entered as the Z80 would enter it: the
 * Z80 original runs to its return and the 6502 routine runs from the same state (sombra6502_comprueba).
 * Deterministic: the same session, frame and cases every time.  Built and run by sinteticas.sh.
 *
 *   sinteticas DIR_6502 [COVERAGE]   (COVERAGE: the Z80 instruction addresses the cases ran) */
#define main hibrido_main
#include "hibrido.c"
#undef main

extern unsigned long fallos_6502;               /* m6502/sombra6502.c */

static uint8_t ram_s[0x10000];
static z80 cpu_s;
static uint8_t teclas_s[16];
static unsigned frame_s;

static void restaura(void)
{
    memcpy(ram, ram_s, sizeof ram);
    cpu = cpu_s;
    memcpy(teclas_vivas, teclas_s, sizeof teclas_vivas);
    frame = frame_s;
}

/* enters the function at `dir` with the registers set by the case (cpu.*), as a CALL from the main loop */
static void llama(uint16_t dir)
{
    const traducida_t *t = buscada(dir);
    if (!t || !sombra6502_tiene(t->nombre)) { fprintf(stderr, "sinteticas: no 6502 routine at %04X\n", dir); exit(2); }
    cpu.sp = (uint16_t)(cpu.sp - 2);
    ram[cpu.sp] = 0x79; ram[(uint16_t)(cpu.sp + 1)] = 0x21;     /* the return into the main loop (2179h) */
    cpu.pc = dir;
    if (getenv("SINTETICAS_TRAZA")) fprintf(stderr, "case at %04X\n", dir);
    llamada_6502(t);
}

#define W(a, v) (ram[(uint16_t)(a)] = (uint8_t)(v))

int main(int argc, char **argv)
{
    static const uint8_t pasos[] = { 0x14, 0x13, 0x05, 0x02, 0x01 };
    static const uint8_t dys[] = { 2, 1, 3 };
    static const uint8_t f5s[] = { 0x80, 0x81, 0x82, 0x83, 0x91, 0x92, 0xA1, 0xC1, 0xC2, 0xC3, 0xD1, 0xD3 };
    static const uint8_t xs[] = { 0x03, 0x45, 0x07, 0x8E }, ys[] = { 0x10, 0x5C, 0x23, 0x0B };
    static const uint8_t qr_y[] = { 0x6D, 0x69, 0x65, 0x70 }, numerales[] = { 1, 2, 3, 4 };
    unsigned i, j, k, casos = 0;
    if (argc < 2) { fprintf(stderr, "usage: sinteticas DIR_6502\n"); return 2; }
    carga_estado("../../data/cpc64/inicio_juego/ram.bin", "../../data/cpc64/inicio_juego/estado.txt");
    carga_puntos("../../data/sincrono/puntos64.txt");
    carga_guion("../../data/cpc64/exploracion/azar1.txt");
    solo = "-";                                       /* the Z80 alone up to the state the cases start from */
    while (frame < 1200 && corre_frame(NULL)) ;
    sombra6502_carga(argv[1]);
    if (argc > 2) cubierto = calloc(0x10000, 1);      /* the Z80 instructions the cases run, into argv[2] */
    memcpy(ram_s, ram, sizeof ram); cpu_s = cpu; memcpy(teclas_s, teclas_vivas, sizeof teclas_s); frame_s = frame;

    /* the dark room: 2236 (sprites darkened, the light when Adso carries the lamp) and 2265 (the light on Adso) */
    for (i = 0; i < 4; ++i) {
        restaura();
        W(0x11DC, 1);
        if (i & 1) W(0x2944, ram[0x2944] | 0x80); else W(0x2944, ram[0x2944] & 0x7F);
        if (i & 2) W(0x297C, 0xFE); else W(0x297C, 0x80);
        llama(0x2265);                                  /* the light placed first, as the main loop does */
        llama(0x2236); casos += 2;
    }
    for (i = 0; i < 4; ++i)
        for (j = 0; j < 2; ++j) {
            restaura();
            W(0x11DC, 1);
            W(0x297C, i == 3 && j ? 0xFE : 0x80);
            W(0x297D, xs[i]); W(0x297E, ys[i]);
            W(0x2B9C, j);
            llama(0x2265); ++casos;
        }
    /* Guillermo's fall (the mirror trap): chr_update of Guillermo with the counter [23E4] and the step [2406] */
    for (i = 0; i < sizeof pasos; ++i)
        for (j = 0; j < sizeof dys; ++j) {
            restaura();
            W(0x23E4, pasos[i]); W(0x2406, dys[j]);
            W(0x2B87, ram[0x2B87] & 0xFE);
            cpu.h = 0x27; cpu.l = 0x03;
            llama(0x2472); ++casos;
        }
    /* the stairs frames of chr_project: Guillermo halfway through a step with the flags [2B8C] of a 1-cell
     * character (turned, on a slope, descending), for both halves of the counter */
    for (i = 0; i < sizeof f5s; ++i)
        for (j = 0; j < 2; ++j) {
            restaura();
            W(0x2B87, (j ? 3 : 1));
            W(0x2B8C, f5s[i]);
            cpu.h = 0x27; cpu.l = 0x03;
            llama(0x2472); ++casos;
        }
    /* the command streams of Adso (chr_table entry 270Dh): a 1-cell character's '11' (command 1) and '0000'
     * (command 0), and a 2x2 one's '0000' read from byte 1, which restarts the stream at byte 0: '1' (1),
     * '0001' (the end), '010' (a turn), '0010' (4) */
    for (i = 0; i < 7; ++i) {
        static const uint8_t reinicio[] = { 0x80, 0x10, 0x40, 0x20 };
        uint16_t buf;
        restaura();
        buf = (uint16_t)(ram[0x2BA2] | ram[0x2BA3] << 8);  /* Adso's [+0C]: his command buffer */
        W(0x2B96, ram[0x2B96] & 0xFE);
        W(0x2B9F, 0);                                      /* [+9]: the bit counter (bit 7 clear: commands) */
        switch (i) {
        case 0: W(0x2B9B, 0x80); W(0x2BA1, 0); W(buf, 0xC0); break;                /* 1-cell: '11' */
        case 1: W(0x2B9B, 0xA0); W(0x2BA1, 0); W(buf, 0x00); W(buf + 1, 0x10); break; /* 1-cell '0000', slope */
        case 2: W(0x2B9B, 0x80); W(0x2BA1, 0); W(buf, 0x00); W(buf + 1, 0x10); break; /* 1-cell '0000' */
        default: W(0x2B9B, 0x00); W(0x2BA1, 1); W(buf, reinicio[i - 3]); W(buf + 1, 0x00); break; /* 2x2: restart */
        }
        cpu.h = 0x27; cpu.l = 0x0D;
        llama(0x2472); ++casos;
    }
    /* the height buffer of the library (floor base 16h): chr_fill_height_buffer of Guillermo at height 16h-18h */
    for (i = 0; i < 3; ++i) {
        restaura();
        W(0x2B8B, 0x16 + i);
        cpu.iy = 0x2B87;
        llama(0x2873); ++casos;
    }
    /* the mirror: game_input_and_mirror with Guillermo at x 22h, height 1Ah, on each step (and off them), Q and
     * R down (Q alone too), the numeral 1-4: it opens, or it is the trap (hud_say_now with its inline 22h) */
    for (i = 0; i < sizeof qr_y; ++i)
        for (j = 0; j < sizeof numerales; ++j)
            for (k = 0; k < 2; ++k) {
                restaura();
                W(0x28DD, 1);
                W(0x2B89, 0x22); W(0x2B8A, qr_y[i]); W(0x2B8B, 0x1A);
                W(0x290D, numerales[j]);
                teclas_vivas[8] |= 0x08;                  /* Q (43h) */
                if (k) teclas_vivas[6] |= 0x04;           /* R (32h) */
                llama(0x2D99); ++casos;
            }
    /* the flips of Malachi and Berengar (never needed in the sessions) */
    restaura(); llama(0x2F00); ++casos;
    restaura(); llama(0x2F20); ++casos;
    restaura(); llama(0x2F00); llama(0x2F00); ++casos;
    fprintf(stderr, "%u synthetic cases from frame %u", casos, frame_s);
    sombra6502_fallos();
    fprintf(stderr, "\n");
    if (cubierto) {
        FILE *f = fopen(argv[2], "w");
        for (i = 0; i < 0x10000; ++i) if (cubierto[i]) fprintf(f, "%04X\n", i);
        fclose(f);
    }
    return fallos_6502 ? 1 : 0;
}
