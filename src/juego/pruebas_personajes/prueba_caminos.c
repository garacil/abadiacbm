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

/* Path tests of the personajes group: the paths the 8 exploration sessions never take, checked the same
 * way as the host does (llamada_traducida: the C wrapper and the Z80 original from the same state, RAM
 * except the dead stack, SP, PC and the declared results), from a mid-game RAM state with synthetic
 * changes.  Includes hibrido.c to reach its static machinery. */
#define main hibrido_main
#include "hibrido.c"
#undef main

static uint8_t base[0x10000];
static int casos;

static void prepara(void)
{
    memcpy(ram, base, sizeof ram);
    cpu.sp = 0xBF00;
    ram[0xBF00] = 0x79; ram[0xBF01] = 0x21;   /* return address 2179 */
    cpu.iff1 = cpu.iff2 = 1;
}

static void corre(uint16_t dir, const char *caso)
{
    const traducida_t *t = buscada(dir);
    unsigned long antes = fallos_c;
    if (!t) { fprintf(stderr, "%04X not in the table\n", dir); exit(2); }
    cpu.pc = dir;
    llamada_traducida(t);
    ++casos;
    printf("%-26s %-40s %s\n", t->nombre, caso, fallos_c == antes ? "ok" : "DIFF");
}


bool chr_project(uint16_t chr, uint16_t spr, uint8_t *depth, uint16_t *screen);
static unsigned long fallos_proy;

/* chr_project (not in the table: it returns to its caller's caller when visible) against 2632 run with
 * two return addresses (1111 = its own, 2222 = its caller's): same RAM outside the stack, same
 * visibility, and when visible the depth (C, or A in test mode) and HL = the screen position */
static void proyecta(uint16_t chr, uint16_t spr, int prueba, const char *caso)
{
    static uint8_t r0[0x10000], rz[0x10000];
    z80 zz;
    unsigned i, n = 0;
    int vz, vc;
    uint8_t depth = 0;
    uint16_t screen = 0;
    unsigned long pasos = 0;
    memcpy(ram, base, sizeof ram);
    ram[0x2684] = prueba ? 0xC9 : 0x00;
    memcpy(r0, ram, sizeof ram);
    cpu.iy = chr; cpu.ix = spr;
    ram[0xBF00] = 0x22; ram[0xBF01] = 0x22; ram[0xBEFE] = 0x11; ram[0xBEFF] = 0x11;
    cpu.sp = 0xBEFE; cpu.pc = 0x2632;
    while (cpu.pc != 0x1111 && cpu.pc != 0x2222 && ++pasos < 1000000) z80_step(&cpu);
    zz = cpu;
    vz = cpu.pc == 0x2222;
    memcpy(rz, ram, sizeof ram);
    memcpy(ram, r0, sizeof ram);
    cpu.iy = chr; cpu.ix = spr; cpu.sp = 0xBEFE;
    vc = chr_project(chr, spr, &depth, &screen);
    for (i = 0; i < 0x10000; ++i) if (ram[i] != rz[i] && !(i >= 0xBE00 && i < 0xBF02)) ++n;
    ++casos;
    if (n || vz != vc || (vc && (screen != (uint16_t)(zz.h << 8 | zz.l) || depth != (prueba ? zz.a : zz.c)))) {
        ++fallos_proy;
        printf("%-26s %-40s DIFF: %u bytes, visible C %d Z80 %d, depth %02X/%02X, screen %04X/%04X\n", "chr_project", caso,
               n, vc, vz, depth, prueba ? zz.a : zz.c, screen, (uint16_t)(zz.h << 8 | zz.l));
    } else printf("%-26s %-40s ok (%s)\n", "chr_project", caso, vc ? "visible" : "hidden");
}

static void tecla(uint8_t key)          /* CPC key number down from now on */
{
    teclas[nteclas].frame = 0; teclas[nteclas].frames = 1000000;
    teclas[nteclas].fila = (uint8_t)(key >> 3); teclas[nteclas].bit = (uint8_t)(key & 7);
    ++nteclas;
}

int main(int argc, char **argv)
{
    FILE *f;
    unsigned i, j;
    char nombre[80];
    if (argc < 3) { fprintf(stderr, "prueba_caminos ESTADO.txt RAM.bin\n"); return 2; }
    carga_estado(argv[2], argv[1]);
    f = fopen(argv[2], "rb");
    if (!f || fread(base, 1, sizeof base, f) != sizeof base) return 2;
    fclose(f);
    frame = 100;
    cubierto = calloc(0x10000, 1);

    /* ---- dark rooms: 2236 spr_draw_or_darken, 2265 spr_place_light ---- */
    for (i = 0; i < 4; ++i) {
        prepara();
        ram[0x11DC] = 1;
        if (i & 1) ram[0x2944] |= 0x80; else ram[0x2944] &= 0x7F;
        if (i & 2) ram[0x297C] = 0xFE;
        sprintf(nombre, "dark, lamp %u, adso spr %s", i & 1, (i & 2) ? "off" : "on");
        corre(0x2265, nombre);              /* the light placed as after a room change */
        cpu.sp = 0xBF00; ram[0xBF00] = 0x79; ram[0xBF01] = 0x21;
        corre(0x2236, nombre);
    }
    {
        static const uint8_t xs[] = { 0x02, 0x09, 0x41, 0x7F }, ys[] = { 0x03, 0x14, 0x1C, 0x9E };
        for (i = 0; i < 4; ++i)
            for (j = 0; j < 4; ++j) {
                prepara();
                ram[0x11DC] = 1;
                ram[0x297D] = xs[i];
                ram[0x297E] = ys[j];
                ram[0x2B9C] = (uint8_t)(j & 1);
                ram[0x2944] |= 0x80;
                sprintf(nombre, "dark, adso at %02X,%02X flip %u", xs[i], ys[j], j & 1);
                corre(0x2265, nombre);
            }
        prepara(); ram[0x11DC] = 1; ram[0x297C] = 0xFE; corre(0x2265, "dark, adso sprite off");
        prepara(); ram[0x11DC] = 0; corre(0x2265, "lit");
    }

    /* ---- Guillermo's fall (23E2 with [23E4] != 0) and the camera on another character ---- */
    {
        static const uint8_t st[] = { 1, 2, 3, 0x14, 0x14, 0x14, 0x10 }, dy[] = { 2, 2, 2, 2, 1, 3, 2 };
        for (i = 0; i < sizeof st; ++i) {
            prepara();
            ram[0x23E4] = st[i];
            ram[0x2406] = dy[i];
            cpu.iy = 0x2B87; cpu.ix = 0x2968; SET_HL(0x23E2);
            sprintf(nombre, "state %02X fall dy %u", st[i], dy[i]);
            corre(0x23E2, nombre);
        }
        prepara();
        ram[0x23E4] = 0; ram[0x37DC] = 1;
        cpu.iy = 0x2B87; cpu.ix = 0x2968; SET_HL(0x23E2);
        corre(0x23E2, "camera on another character");
    }

    /* ---- chr_animate (chr_project) with the frames of a 1-cell character on stairs ---- */
    {
        static const uint8_t f5[] = { 0x80, 0x81, 0x82, 0x83, 0xC1, 0xC2, 0xC3, 0x90, 0x91, 0x92, 0xD3, 0xA0, 0xB1, 0x00, 0x10 };
        for (i = 0; i < sizeof f5; ++i)
            for (j = 0; j < 2; ++j) {
                prepara();
                ram[0x2B87 + 5] = f5[i];
                ram[0x2B87] = (uint8_t)j;
                cpu.iy = 0x2B87; cpu.ix = 0x2968;
                sprintf(nombre, "[chr+5] %02X [chr] %u", f5[i], j);
                corre(0x257C, nombre);
            }
        for (i = 0; i < 4; ++i) {           /* the four orientations, and the other camera rotations */
            prepara();
            ram[0x2B87 + 1] = (uint8_t)i;
            cpu.iy = 0x2B87; cpu.ix = 0x2968;
            sprintf(nombre, "orientation %u", i);
            corre(0x257C, nombre);
        }
        prepara(); ram[0x2B87 + 2] = 0x00; cpu.iy = 0x2B87; cpu.ix = 0x2968; corre(0x257C, "far away (x 00)");
        prepara(); ram[0x2B87 + 4] = 0x30; cpu.iy = 0x2B87; cpu.ix = 0x2968; corre(0x257C, "another floor");
        prepara(); ram[0x2B87 + 4] = 0x0A; cpu.iy = 0x2B87; cpu.ix = 0x2968; corre(0x257C, "high (z 0A)");
        prepara(); ram[0x2968] = 0xFE; cpu.iy = 0x2B87; cpu.ix = 0x2968; corre(0x257C, "sprite inactive");
    }

    /* ---- the command streams of 278F: every command, 1-cell and 2x2, and the restart of a 2x2 ---- */
    {
        /* stream bytes (MSB first) */
        static const uint8_t s1[][2] = {
            { 0xC0, 0 }, { 0x80, 0 }, { 0x00, 0 }, { 0x60, 0 }, { 0x40, 0 }, { 0x30, 0 }, { 0x20, 0 }, { 0x10, 0 },
        };
        static const char *const n1[] = { "11", "10", "0000", "011", "010", "0011", "0010", "0001 end" };
        uint16_t buf = 0x7F00;
        for (j = 0; j < 2; ++j)
            for (i = 0; i < 8; ++i) {
                if (j == 1 && i == 2) continue;     /* '0000' on a 2x2 from index 0 would loop */
                prepara();
                ram[buf] = s1[i][0]; ram[buf + 1] = s1[i][1];
                ram[0x2B96 + 5] = j ? 0x00 : 0x80;
                ram[0x2B96 + 9] = 0; ram[0x2B96 + 0x0B] = 0;
                ram[0x2B96 + 0x0C] = (uint8_t)buf; ram[0x2B96 + 0x0D] = (uint8_t)(buf >> 8);
                cpu.iy = 0x2B96; cpu.ix = 0x297C; SET_HL(0x278F);
                sprintf(nombre, "%s '%s'", j ? "2x2" : "1-cell", n1[i]);
                corre(0x278F, nombre);
            }
        prepara();                              /* 2x2: '0000' at index 1 restarts at index 0: '1' */
        ram[buf] = 0x80; ram[buf + 1] = 0x00;
        ram[0x2B96 + 5] = 0x00; ram[0x2B96 + 9] = 0; ram[0x2B96 + 0x0B] = 1;
        ram[0x2B96 + 0x0C] = (uint8_t)buf; ram[0x2B96 + 0x0D] = (uint8_t)(buf >> 8);
        cpu.iy = 0x2B96; cpu.ix = 0x297C; SET_HL(0x278F);
        corre(0x278F, "2x2 '0000' restart then '1'");
        prepara();
        ram[0x2B96 + 9] = 0x80;
        cpu.iy = 0x2B96; cpu.ix = 0x297C; SET_HL(0x278F);
        corre(0x278F, "no commands (bit 7)");
        prepara();                              /* 1-cell with bit 5 (turned on the stairs), '10' */
        ram[buf] = 0x80; ram[0x2B96 + 5] = 0xA0; ram[0x2B96 + 9] = 0; ram[0x2B96 + 0x0B] = 0;
        ram[0x2B96 + 0x0C] = (uint8_t)buf; ram[0x2B96 + 0x0D] = (uint8_t)(buf >> 8);
        cpu.iy = 0x2B96; cpu.ix = 0x297C; SET_HL(0x278F);
        corre(0x278F, "1-cell bit 5 '10'");
    }

    /* ---- the height buffer of the other floors ---- */
    {
        static const uint8_t z[] = { 0x00, 0x0B, 0x0E, 0x16, 0x18, 0x20 };
        for (i = 0; i < sizeof z; ++i) {
            prepara();
            ram[0x2B87 + 4] = z[i];
            cpu.iy = 0x2B87;
            sprintf(nombre, "z %02X", z[i]);
            corre(0x2873, nombre);
        }
    }

    /* ---- the mirror: Q + R on the three steps, every numeral ---- */
    tecla(0x43);
    tecla(0x32);
    {
        static const uint8_t ys[] = { 0x6D, 0x69, 0x65, 0x67 };
        for (i = 0; i < 4; ++i)
            for (j = 1; j <= 4; ++j) {
                prepara();
                ram[0x2B87 + 2] = 0x22; ram[0x2B87 + 3] = ys[i]; ram[0x2B87 + 4] = 0x1A;
                ram[0x28DD] = 1; ram[0x290D] = (uint8_t)j;
                sprintf(nombre, "y %02X numeral %u", ys[i], j);
                corre(0x2D99, nombre);
                prepara();
                ram[0x2B87 + 2] = 0x22; ram[0x2B87 + 3] = ys[i]; ram[0x2B87 + 4] = 0x1A;
                corre(0x2DFC, nombre);
            }
        prepara();
        ram[0x2B87 + 2] = 0x22; ram[0x2B87 + 3] = 0x6D; ram[0x2B87 + 4] = 0x1B; ram[0x28DD] = 1;
        corre(0x2D99, "height 1B");
        corre(0x2DFC, "height 1B");
    }
    nteclas -= 2;
    tecla(0x43);                                /* only Q */
    prepara();
    ram[0x2B87 + 2] = 0x22; ram[0x2B87 + 3] = 0x6D; ram[0x2B87 + 4] = 0x1A; ram[0x28DD] = 1; ram[0x290D] = 1;
    corre(0x2D99, "only Q");
    nteclas -= 1;


    /* ---- chr_project directly, normal and test mode ([2684] = C9h), every character ---- */
    {
        static const uint16_t chrs[] = { 0x2B87, 0x2B96, 0x2BA5, 0x2BB4, 0x2BC3, 0x2BD2 };
        static const uint16_t sprs[] = { 0x2968, 0x297C, 0x2990, 0x29A4, 0x29B8, 0x29CC };
        int k, m, d;
        for (k = 0; k < 6; ++k)
            for (m = 0; m < 2; ++m)
                for (d = -12; d <= 12; d += 4) {
                    uint8_t *b = base;
                    uint8_t x0 = b[chrs[k] + 2], y0 = b[chrs[k] + 3];
                    b[chrs[k] + 2] = (uint8_t)(x0 + d);
                    b[chrs[k] + 3] = (uint8_t)(y0 - d / 2);
                    sprintf(nombre, "chr %04X %s dx %d", chrs[k], m ? "test" : "normal", d);
                    proyecta(chrs[k], sprs[k], m, nombre);
                    b[chrs[k] + 2] = x0;
                    b[chrs[k] + 3] = y0;
                }
    }

    /* ---- the flips never called in the sessions, and the key tests of every key ---- */
    prepara(); corre(0x2F00, "malachi");
    prepara(); corre(0x2F20, "berengar");
    prepara(); cpu.ix = 0; SET_HL(0x8000); cpu.b = 0; cpu.c = 3; corre(0x2F57, "256 rows of 3");
    tecla(0x08); tecla(0x25); tecla(0x00); tecla(0x4B); tecla(0x2F);
    for (i = 0; i < 0x50; ++i) {
        prepara(); cpu.a = (uint8_t)i; sprintf(nombre, "key %02X", i); corre(0x2E8D, nombre);
        prepara(); cpu.a = (uint8_t)i; corre(0x2E7D, nombre);
        prepara(); cpu.a = (uint8_t)i; SET_DE(0x2DE8); corre(0x2E98, nombre);
    }
    prepara(); corre(0x2D50, "keys down");

    if (argc > 3) {
        FILE *c = fopen(argv[3], "w");
        for (i = 0; i < 0x10000; ++i) if (cubierto[i]) fprintf(c, "%04X\n", i);
        fclose(c);
    }
    printf("%d cases, %lu differences\n", casos, fallos_c + fallos_proy);
    return fallos_c + fallos_proy ? 1 : 0;
}
