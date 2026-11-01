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

/* Extra shadow checks of the group motor_iso beyond the exploration sessions: every room of the three
 * floors built and drawn (lit and dark), the camera moved into every room (every floor, orientation and
 * the dark rooms), synthetic blocks with the opcodes no room uses (EB, ED, EE, E4 CALL_KEEP, the count
 * form of a tile run, SET of a depth >= 64h, the skip of a loop with 82h and E8h inside), and the small
 * functions over their inputs.  Each check is the hybrid host's own (llamada_traducida: C and Z80 from
 * the same state, all the RAM compared).  It also writes cobertura_prueba.txt (the Z80 instructions
 * of 128F-2225 that the originals ran).  From juego/:
 *   T=../../data
 *   ./hibrido $T/cpc64/inicio_juego/ram.bin $T/cpc64/inicio_juego/estado.txt $T/sincrono/puntos64.txt \
 *       --guion $T/cpc64/exploracion/azar1.txt --hasta 2000 --solo nada --ram-final /tmp/ram_f2000.bin
 *   gcc -std=c99 -O2 -I. -o /tmp/prueba_motor_iso pruebas_motor_iso/prueba_motor_iso.c f_motor_iso.c \
 *       funciones.c grupos.c z80/z80.c
 *   /tmp/prueba_motor_iso /tmp/ram_f2000.bin $T/cpc64/inicio_juego/estado.txt
 */
#define main hibrido_main
#include "../hibrido.c"
#undef main

static uint8_t base[0x10000];
static unsigned long por_prueba[8];

static void reinicia(void)
{
    memcpy(ram, base, sizeof ram);
    cpu.sp = 0xC000;
    cpu.iff1 = cpu.iff2 = 0;
}

static void comprueba(uint16_t dir)
{
    const traducida_t *t = buscada(dir);
    uint16_t sp = cpu.sp;
    if (!t) { fprintf(stderr, "%04X not translated\n", dir); exit(2); }
    cpu.sp = (uint16_t)(cpu.sp - 2);
    ram[cpu.sp] = 0xA9; ram[(uint16_t)(cpu.sp + 1)] = 0x21;
    cpu.pc = dir;
    llamada_traducida(t);
    cpu.sp = sp;
}

static void w16(uint16_t a, uint16_t v) { ram[a] = (uint8_t)v; ram[(uint16_t)(a + 1)] = (uint8_t)(v >> 8); }
static uint16_t r16(uint16_t a) { return (uint16_t)(ram[a] | ram[(uint16_t)(a + 1)] << 8); }

/* the rooms of the maps: floor 0 rows 1-10 at 1E79, floors 1 and 2 rows 2-6, columns 0-7, at 1F09 / 1F11 */
typedef struct { uint8_t room, x, y, z; } sala_t;
static sala_t salas[300];
static int nsalas;

static void busca_salas(void)
{
    int x, y;
    for (y = 1; y <= 10; ++y)
        for (x = 0; x < 16; ++x)
            if (base[0x1E79 + (y << 4 | x)]) { sala_t s = { base[0x1E79 + (y << 4 | x)], (uint8_t)x, (uint8_t)y, 0x02 }; salas[nsalas++] = s; }
    for (y = 2; y <= 6; ++y)
        for (x = 0; x < 8; ++x) {
            if (base[0x1F09 + (y << 4 | x)]) { sala_t s = { base[0x1F09 + (y << 4 | x)], (uint8_t)x, (uint8_t)y, 0x0F }; salas[nsalas++] = s; }
            if (base[0x1F11 + (y << 4 | x)]) { sala_t s = { base[0x1F11 + (y << 4 | x)], (uint8_t)x, (uint8_t)y, 0x1A }; salas[nsalas++] = s; }
        }
}

/* synthetic data at BA70: a room record and blocks using every opcode */
static const uint8_t sintetico[] = {
    /* BA70: the tile list (12 tiles) */
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B,
    /* BA7C: block A = word tiles, script */
    0x70, 0xBA,
    0xF6,                                   /* y++ */
    0xEB, 0x61, 0x80, 0x62, 0x81, 0x63,     /* TILES_LEFT t1 put+step, t2 put, t3 put+step */
    0xF5, 0xEE, 0xED, 0xEF, 0xF0,           /* x++, p1--, p2--, p2++, p1++ */
    0xF7, 0x71, 0x01,                       /* depth y := 1 */
    0xF9, 0x64, 0x85, 0x02, 0x81, 0x65, 0x80, 0x66,   /* count form: t4, count 2, then 81 skipped, t5, t6 */
    0xF4,                                   /* y-- */
    0xF7, 0x70, 0x82, 0x70,                 /* depth x := 70h -> 0 (>= 64h) */
    0xF7, 0x61, 0x82, 0x33,                 /* t1 := 33h */
    0xE4, 0xC5, 0xBA,                       /* CALL_KEEP block B */
    0xE9,                                   /* MIRROR */
    0xF5, 0xF3, 0xF3,                       /* x mirrored */
    0xF8, 0x61, 0x80, 0x62, 0x80, 0x65,     /* TILES_RIGHT mirrored */
    0xEC, 0xC5, 0xBA,                       /* CALL block B */
    0xFC, 0xF6, 0xF6, 0xFB,                 /* push pos, y += 2, pop pos */
    0xFE, 0xF5, 0xF9, 0x66, 0xFA,           /* loop p1 { x++; TILES_UP t6 } (p1 = 0: skipped) */
    0xEA, 0xBD, 0xBA,                       /* JUMP to BABD */
    0xF6, 0xF6, 0xF6,                       /* (jumped over) */
    /* BABD */
    0xF2, 0x6F, 0x84, 0x82, 0x03,           /* y += -(height) + 3 */
    0xF8, 0x67, 0xFF,                       /* TILES_RIGHT t7, END */
    /* BAC5: block B */
    0x76, 0xBA,
    0xE8,                                   /* MIRROR */
    0xF8, 0x61, 0x80, 0x62,                 /* TILES_RIGHT */
    0xF1, 0x6D, 0x6E, 0x84,                 /* x += -(p1 + p2) */
    0xF9, 0x70, 0x80, 0x71, 0xFF,           /* TILES_UP of the depth registers' values as tiles, END */
    /* BAD5: block C (p2 = 0 only): the skip of a loop with E8 and 82 inside */
    0x70, 0xBA,
    0xFD, 0xF6, 0x82, 0xFA, 0xE8, 0xF6, 0xFA, 0xF6, 0xFA,   /* loop p2 (0): skipped up to the third FA */
    0xF9, 0x68, 0x80, 0x69, 0xFF,
    /* BAE5: the room record (length, entries, FF) */
    0x20,
    0x03, 0x0A, 0x0C, 0x08,                 /* block A (type 2), x 10, p1 0, y 12, p2 0, height 8 */
    0x03, 0x4C, 0x2E, 0x06,                 /* block A, x 12, p1 2, y 14, p2 1, height 6 */
    0x04, 0x2B, 0x0D,                       /* block C without height, x 11, p1 1, y 13, p2 0 */
    0x05, 0x2D, 0x10, 0x04,                 /* block C (type 4), x 13, p1 1, y 16, p2 0, height 4 */
    0xFF
};

int main(int argc, char **argv)
{
    FILE *f;
    int i, a, o, k;
    uint16_t rec;
    unsigned long antes;
    if (argc < 3) { fprintf(stderr, "usage: prueba_motor_iso RAM_DUMP ESTADO\n"); return 2; }
    carga_estado(argv[1], argv[2]);
    f = fopen(argv[1], "rb");
    if (!f || fread(base, 1, sizeof base, f) != sizeof base) return 2;
    fclose(f);
    busca_salas();
    cubierto = calloc(0x10000, 1);

    /* 1. every room built and drawn, lit and dark */
    antes = llamadas_c;
    for (i = 0; i < nsalas; ++i)
        for (a = 0; a < 2; ++a) {
            reinicia();
            frame = (unsigned)(1000 + i * 2 + a);
            ram[0x11DC] = (uint8_t)a;
            cpu.a = salas[i].room;
            llama_z80(0x2855);              /* iso_select_room */
            comprueba(0x1611);              /* iso_draw_room */
            cpu.ix = (uint16_t)(r16(0x11DA) + 1);
            comprueba(0x163F);              /* iso_build_room again on the tile buffer just built */
        }
    por_prueba[0] = llamadas_c - antes;

    /* 2. the camera moved into every room (every floor, orientation, dark rooms), then drawn */
    antes = llamadas_c;
    for (i = 0; i < nsalas; ++i) {
        reinicia();
        frame = (unsigned)(3000 + i);
        rec = r16(0x28D9);
        ram[(uint16_t)(rec + 2)] = (uint8_t)(salas[i].x << 4 | 8);
        ram[(uint16_t)(rec + 3)] = (uint8_t)(salas[i].y << 4 | 8);
        ram[(uint16_t)(rec + 4)] = salas[i].z;
        comprueba(0x1F79);                  /* iso_update_camera_room: the room changes */
        comprueba(0x1F79);                  /* again: nothing changes */
        comprueba(0x1611);                  /* iso_draw_room */
    }
    por_prueba[1] = llamadas_c - antes;

    /* 3. synthetic blocks: every opcode, lit and dark */
    antes = llamadas_c;
    for (a = 0; a < 2; ++a) {
        reinicia();
        frame = (unsigned)(5000 + a);
        memcpy(&ram[0xBA70], sintetico, sizeof sintetico);
        w16(0x11DD + 2, 0xBA7C);            /* block type 2 = A */
        w16(0x11DD + 4, 0xBAD5);            /* block type 4 = C */
        w16(0x11DA, 0xBAE5);                /* the room record */
        ram[0x11DC] = (uint8_t)a;
        comprueba(0x1611);
        cpu.ix = (uint16_t)(r16(0x11DA) + 1);
        comprueba(0x163F);
    }
    por_prueba[2] = llamadas_c - antes;

    /* 4. the small functions over their inputs */
    antes = llamadas_c;
    reinicia();
    for (a = 0; a < 256; ++a) {
        frame = (unsigned)(6000 + a);
        cpu.a = (uint8_t)a; cpu.b = 0x55;
        comprueba(0x2097);                  /* iso_floor_base */
        for (o = 0; o < 4; ++o) {
            ram[0x20A5] = (uint8_t)o;
            cpu.a = (uint8_t)a;
            comprueba(0x20A4);              /* iso_orient_relative */
        }
        for (k = 0; k < 256; k += 7) {
            cpu.a = (uint8_t)a; cpu.h = (uint8_t)k; cpu.l = (uint8_t)(k * 13 + a);
            comprueba(0x128F);              /* util_add_bx_al */
            cpu.h = (uint8_t)a; cpu.l = (uint8_t)k;
            comprueba(0x20A9); cpu.h = (uint8_t)a; cpu.l = (uint8_t)k;
            comprueba(0x20AE); cpu.h = (uint8_t)a; cpu.l = (uint8_t)k;
            comprueba(0x20AF); cpu.h = (uint8_t)a; cpu.l = (uint8_t)k;
            comprueba(0x20B8);
        }
    }
    /* iso_put_tile both forms, iso_put_tile_step, iso_put_tile_times (depth y 1: it ends at the first
     * visible put), iso_block_depth */
    for (k = 0; k < 2; ++k)
        for (a = 0; a < 0x20; ++a)
            for (o = 0; o < 0x20; o += 3) {
                reinicia();
                frame = (unsigned)(7000 + k * 1024 + a * 32 + o);
                w16(0x12C0, k ? 0x12C2 : 0x12C9);
                ram[0x1BEC] = (uint8_t)(a * 5); ram[0x1BED] = (uint8_t)(o * 7 + 3);
                cpu.h = (uint8_t)a; cpu.l = (uint8_t)o; cpu.c = (uint8_t)(a + o); cpu.d = 0x12; cpu.e = 0x34;
                comprueba(0x1295);
                ram[0x1D29] = (uint8_t)(o & 1 ? 0x25 : o & 2 ? 0x2C : 0x2D);
                cpu.h = (uint8_t)a; cpu.l = (uint8_t)o;
                comprueba(0x1D26);
                ram[0x1BED] = 1;                /* it ends only when a visible put is reached */
                if (k == 0 && (ram[0x1D29] == 0x25 ? o >= 8 && o < 24 : a >= 8 && a < 28)) {   /* the 12C2h form never gives A = 1 */
                    cpu.h = (uint8_t)a; cpu.l = (uint8_t)o; cpu.a = 2;
                    comprueba(0x1D48);
                }
                cpu.h = (uint8_t)a; cpu.l = (uint8_t)o; cpu.a = (uint8_t)(o == 3 ? 0xFF : a * 3);
                comprueba(0x1BC6);
            }
    /* vid_set_crtc on its two data lists, the play-area fills */
    reinicia();
    frame = 9000;
    cpu.sp = (uint16_t)(cpu.sp - 2); w16(cpu.sp, 0x1E66); cpu.pc = 0x1E6E; llamada_traducida(buscada(0x1E6E)); cpu.sp = 0xC000;
    cpu.sp = (uint16_t)(cpu.sp - 2); w16(cpu.sp, 0x20CB); cpu.pc = 0x1E6E; llamada_traducida(buscada(0x1E6E)); cpu.sp = 0xC000;
    cpu.a = 0x5A; comprueba(0x16B2);
    comprueba(0x16A1);
    cpu.a = 0x0F; comprueba(0x16A5);
    por_prueba[3] = llamadas_c - antes;

    fprintf(stderr, "rooms %lu, camera %lu, synthetic %lu, small %lu checks; %lu calls, %lu differences (%d rooms)\n",
            por_prueba[0], por_prueba[1], por_prueba[2], por_prueba[3], llamadas_c, fallos_c, nsalas);
    {   /* the Z80 instructions of 128F-2225 the originals never ran in these checks */
        FILE *c = fopen("cobertura_prueba.txt", "w");
        unsigned k2;
        for (k2 = 0x128F; k2 < 0x2226; ++k2) if (cubierto[k2]) fprintf(c, "%04X\n", k2);
        fclose(c);
    }
    return fallos_c ? 1 : 0;
}
