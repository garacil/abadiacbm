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

/* salas64.c - every room of the abbey drawn by the C64 game itself, for the map of c64/mapa/mapa64.py.
 *
 *   salas64 DIR OUT     DIR = c64/juego_final (juego.bin built with -D PRUEBA, juego.lbl, mapa64.inc)
 *
 * The 6502 game (the image the host's --juego6502 runs) is started on the hybrid host's 6502 core
 * (juego/m6502, sim65's) at principal_inicio with no key down, and run to its first frame point (plat_frame:
 * the main loop's head, a new game set up).  Its memory there is OUT/mem.bin.  Then, for every cell of the three
 * room grids that has a room, as the main loop would after Guillermo walked in: Guillermo in the middle of the
 * cell at the floor's height (the other characters out of every room), the room shown forgotten (28C6h = 0Fh),
 * iso_update_camera_room (the room, its camera, doors, objects and height buffer), the characters' sprites
 * hidden, a dark room drawn lit, iso_draw_room, obj_room_redraw = 80h and spr_draw_or_darken: the 6502
 * routines of the game, drawing into the C64 bitmap.  For each room: OUT/f<floor>_x<X>_y<Y>.bmp (the play area:
 * 160 lines of the 32 bitmap bytes of cells 4-35), .alt (the 24 x 24 height buffer from world (16X-4, 16Y-4),
 * refilled by chr_fill_height_buffer with nobody in it), .esp for the library (the same with the mirror open,
 * as game_input_and_mirror opens it), and a line of OUT/salas.tsv (room, camera orientation, dark, the inks). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include "../../juego/m6502/m6502.h"
#include "../../juego/m6502/peripherals.h"

#define MAX_CICLOS 400000000ul

static struct { char n[64]; unsigned v; } sim[4096];
static int nsim;

static void lee_simbolos(const char *dir, const char *fich, int lbl)
{
    char ruta[1024], l[512];
    FILE *f;
    snprintf(ruta, sizeof ruta, "%s/%s", dir, fich);
    f = fopen(ruta, "r");
    if (!f) { perror(ruta); exit(2); }
    while (fgets(l, sizeof l, f) && nsim < 4096) {
        char n[64];
        unsigned v;
        if (lbl ? sscanf(l, "al %x .%63s", &v, n) == 2 : sscanf(l, "%63s = $%x", n, &v) == 2) {
            snprintf(sim[nsim].n, sizeof sim[nsim].n, "%s", n);
            sim[nsim++].v = v;
        }
    }
    fclose(f);
}

static uint16_t S(const char *n)
{
    int i;
    for (i = 0; i < nsim; ++i) if (!strcmp(sim[i].n, n)) return (uint16_t)sim[i].v;
    fprintf(stderr, "salas64: no symbol %s\n", n);
    exit(2);
}

static uint16_t rw(uint16_t a) { return (uint16_t)(Mem[a] | Mem[(uint16_t)(a + 1)] << 8); }

static void llama(const char *n)
{
    if (!m6502_llama(S(n), 0, 0, 0, MAX_CICLOS)) { fprintf(stderr, "salas64: %s does not return\n", n); exit(3); }
}

static void escribe(const char *out, const char *nombre, const uint8_t *p, size_t n)
{
    char ruta[1024];
    FILE *f;
    snprintf(ruta, sizeof ruta, "%s/%s", out, nombre);
    f = fopen(ruta, "wb");
    if (!f || fwrite(p, 1, n, f) != n) { perror(ruta); exit(2); }
    fclose(f);
}

/* the 6502 game from principal_inicio to its first frame point; the waits get the ticks due as the host's
 * j_pasa gives them (one sys_tick every 3328 cycles while the interrupts are on) */
static void arranca(void)
{
    uint16_t frame = S("plat_frame"), espera = S("plat_espera"), pausa = S("plat_pausa"), tick = S("sys_tick");
    uint16_t iff = S("PLAT_IFF");
    uint64_t c0 = Peripherals.Counter.ClockCycles, siguiente = 3328;
    m6502_init();
    Regs.SP = 0xFF; Regs.SR = 0x34; Regs.PC = S("principal_inicio");
    memset(Mem + S("PLAT_TECLADO"), 0xFF, 10);          /* no key down */
    while (Regs.PC != frame) {
        if (Regs.PC == espera || Regs.PC == pausa) {
            uint64_t t = Peripherals.Counter.ClockCycles - c0;
            if (t >= siguiente && Mem[iff]) {
                uint8_t a = Regs.AC, x = Regs.XR, y = Regs.YR, sr = Regs.SR;
                uint16_t pc = Regs.PC;
                siguiente += 3328;
                Mem[iff] = 0;
                if (!m6502_llama(tick, a, x, y, MAX_CICLOS)) { fprintf(stderr, "salas64: sys_tick\n"); exit(3); }
                Regs.AC = a; Regs.XR = x; Regs.YR = y; Regs.SR = sr; Regs.PC = pc;
            }
        }
        ExecuteInsn();
        if (Peripherals.Counter.ClockCycles - c0 > MAX_CICLOS) {
            fprintf(stderr, "salas64: no frame point (PC %04X)\n", Regs.PC);
            exit(3);
        }
    }
}

static void alturas(uint16_t guillermo)
{
    Mem[S("ziy")] = (uint8_t)guillermo;
    Mem[S("ziy") + 1] = (uint8_t)(guillermo >> 8);
    llama("chr_fill_height_buffer");
}

int main(int argc, char **argv)
{
    static const struct { uint8_t z; int y0, y1, x1; } plantas[3] = {{0x00, 1, 10, 15}, {0x0D, 2, 6, 7}, {0x18, 2, 6, 7}};
    uint16_t mapas[3], guillermo, tabla;
    char nombre[64], ruta[1024];
    FILE *idx, *f;
    int p, X, Y, k;
    size_t n;

    if (argc != 3) { fprintf(stderr, "usage: salas64 DIR OUT\n"); return 2; }
    snprintf(ruta, sizeof ruta, "%s/juego.bin", argv[1]);
    f = fopen(ruta, "rb");
    if (!f) { perror(ruta); return 2; }
    n = fread(Mem, 1, sizeof Mem, f);
    fclose(f);
    if (n != 0x10000) { fprintf(stderr, "%s: %zu bytes\n", ruta, n); return 2; }
    lee_simbolos(argv[1], "juego.lbl", 1);
    lee_simbolos(argv[1], "mapa64.inc", 0);
    lee_simbolos(argv[1], "plataforma.inc", 0);
    lee_simbolos(argv[1], "zp.inc", 0);
    mkdir(argv[2], 0755);

    arranca();
    escribe(argv[2], "mem.bin", Mem, sizeof Mem);

    mapas[0] = (uint16_t)(S("D64_ISO_FLOOR_MAPS") - 0x10);  /* motor_iso.s MI_FLOOR0_MAP */
    mapas[1] = S("D64_ISO_FLOOR1_MAP");
    mapas[2] = S("D64_ISO_FLOOR2_MAP");
    guillermo = S("D64_CHR_GUILLERMO");
    tabla = S("D64_CHR_TABLE");
    for (k = 1; k < 6; ++k) {                       /* the others out of every room: floor 2, cell (15, 15) */
        Mem[guillermo + 15 * k + 2] = 0xF8;
        Mem[guillermo + 15 * k + 3] = 0xF8;
        Mem[guillermo + 15 * k + 4] = 0x30;
    }
    Mem[S("D64_CHR_CAMERA_TARGET")] = (uint8_t)guillermo;
    Mem[S("D64_CHR_CAMERA_TARGET") + 1] = (uint8_t)(guillermo >> 8);

    snprintf(ruta, sizeof ruta, "%s/salas.tsv", argv[2]);
    idx = fopen(ruta, "w");
    if (!idx) { perror(ruta); return 2; }
    fprintf(idx, "planta\tX\tY\tsala\torientacion\toscura\ttintas\n");
    for (p = 0; p < 3; ++p)
        for (Y = plantas[p].y0; Y <= plantas[p].y1; ++Y)
            for (X = 0; X <= plantas[p].x1; ++X) {
                uint8_t sala = Mem[(uint16_t)(mapas[p] + (Y << 4 | X))], oscura, bmp[160 * 32];
                uint16_t e;
                int l;
                if (!sala) continue;
                Mem[guillermo + 2] = (uint8_t)(X * 16 + 8);
                Mem[guillermo + 3] = (uint8_t)(Y * 16 + 8);
                Mem[guillermo + 4] = plantas[p].z;
                Mem[S("D64_CHR_ROOM_X")] = 0x0F;     /* never a room x: forces the change */
                llama("iso_update_camera_room");
                oscura = Mem[S("D64_ISO_ROOM_DARK")];
                Mem[S("D64_ISO_ROOM_DARK")] = 0;
                for (e = tabla; Mem[(uint16_t)(e + 1)] != 0xFF; e = (uint16_t)(e + 10)) Mem[rw(e)] = 0xFE;
                llama("iso_draw_room");
                Mem[S("D64_OBJ_ROOM_REDRAW")] = 0x80;
                llama("spr_draw_or_darken");
                for (l = 0; l < 160; ++l) {
                    int c;
                    for (c = 0; c < 32; ++c) bmp[l * 32 + c] = Mem[0xE000 + 320 * (l >> 3) + 8 * (c + 4) + (l & 7)];
                }
                snprintf(nombre, sizeof nombre, "f%d_x%d_y%d.bmp", p, X, Y);
                escribe(argv[2], nombre, bmp, sizeof bmp);
                fprintf(idx, "%d\t%d\t%d\t%02X\t%d\t%d\t", p, X, Y, Mem[S("D64_ISO_ROOM_NUMBER")],
                        Mem[S("D64_ISO_CAMERA_ORIENT")], oscura);
                for (k = 0; k < 5; ++k) fprintf(idx, "%s%02X", k ? "," : "", Mem[S("PLAT_TINTAS") + (k < 4 ? k : 16)]);
                fprintf(idx, "\n");
                Mem[guillermo + 2] = (uint8_t)(X * 16 + 8);
                Mem[guillermo + 3] = (uint8_t)(Y * 16 + 8);
                Mem[guillermo + 4] = plantas[p].z;
                alturas(guillermo);
                snprintf(nombre, sizeof nombre, "f%d_x%d_y%d.alt", p, X, Y);
                escribe(argv[2], nombre, Mem + rw(S("D64_CHR_HBUF_PTR")), 576);
            }
    fclose(idx);

    /* the library with the mirror open: FFh at [obj_mirror_height_ptr], the height list cut there */
    Mem[rw(S("D64_OBJ_MIRROR_HEIGHT_PTR"))] = 0xFF;
    for (Y = plantas[2].y0; Y <= plantas[2].y1; ++Y)
        for (X = 0; X <= plantas[2].x1; ++X) {
            if (!Mem[(uint16_t)(mapas[2] + (Y << 4 | X))]) continue;
            Mem[guillermo + 2] = (uint8_t)(X * 16 + 8);
            Mem[guillermo + 3] = (uint8_t)(Y * 16 + 8);
            Mem[guillermo + 4] = plantas[2].z;
            alturas(guillermo);
            snprintf(nombre, sizeof nombre, "f2_x%d_y%d.esp", X, Y);
            escribe(argv[2], nombre, Mem + rw(S("D64_CHR_HBUF_PTR")), 576);
        }
    return 0;
}
