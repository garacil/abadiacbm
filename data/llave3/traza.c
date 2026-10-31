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

/* abadia64ks, data/llave3: the hybrid host (src/juego/hibrido.c, included with its main renamed, as
 * src/juego/gnu/abadia64ks.c does; hibrido.c itself is not changed) with a per-frame trace of the variables of
 * the key-3 question, written at every frame point (the hook en_frame), and pictures of the CPC screen:
 *
 *   traza OUT.tsv [--fotos F1,F2,... DIR] RAM.bin ESTADO.txt PUNTOS.txt [the hybrid's options: --guion
 *         --hasta --solo nada ...]
 *
 * One line per frame: frame, day, hour, then Guillermo, Adso and Malachi as orientation x y z (hex), the
 * objects of Adso [2947] and Malachi [294E], Malachi's take mask [2950], Malachi's reached / state /
 * destination [37F5-37F7], key 3's record [2B77-2B7B], the monk flags [37F2], the phrase busy flag [28F2],
 * the camera's other character [37DC] and the keys of the script held in this frame (row:bit list).
 * --fotos: DIR/zNNNNNN.ppm, the screen at those frame points as the CRTC and the gate array show it (the
 * renderer of src/juego/gnu/abadia64ks.c, dibuja: 384 x 272 with the border), so the pictures of the original
 * (the Z80 run) and of the GNU build can be compared pixel for pixel. */
#define main hibrido_main
#include "../../juego/hibrido.c"
#undef main

static FILE *traza;
static unsigned fotos[64];
static int nfotos;
static const char *dir_fotos;

static void pon(const char *nombre, uint16_t a, int n)
{
    int i;
    fprintf(traza, "\t%s", nombre);
    for (i = 0; i < n; ++i) fprintf(traza, "%s%02X", i ? " " : "=", ram[(uint16_t)(a + i)]);
}

/* the 32 hardware colours of the CPC gate array (RGB), as src/juego/gnu/abadia64ks.c */
static const uint8_t cpc_rgb[32][3] = {
    {128,128,128},{128,128,128},{0,255,128},{255,255,128},{0,0,128},{255,0,128},{0,128,128},{255,128,128},
    {255,0,128},{255,255,128},{255,255,0},{255,255,255},{255,0,0},{255,0,255},{255,128,0},{255,128,255},
    {0,0,128},{0,255,128},{0,255,0},{0,255,255},{0,0,0},{0,0,255},{0,128,0},{0,128,255},
    {128,0,128},{128,255,128},{128,255,0},{128,255,255},{128,0,0},{128,0,255},{128,128,0},{128,128,255}};
#define ANCHO 384
#define ALTO 272
static uint8_t pix[ALTO][ANCHO][3];

static void pinta(int py, int px, uint8_t hw)
{
    if (py >= 0 && py < ALTO && px >= 0 && px < ANCHO) memcpy(pix[py][px], cpc_rgb[hw & 31], 3);
}

/* src/juego/gnu/abadia64ks.c dibuja(), writing RGB */
static void foto(const char *nombre)
{
    unsigned base = ((crtc[12] & 0x30u) << 10) | ((crtc[12] & 3u) << 9) | ((unsigned)crtc[13] << 1);
    unsigned bpl = 2u * crtc[1], filas = crtc[6], sl = (crtc[9] & 7u) + 1;
    int r2 = crtc[2] ? crtc[2] : 46, r7 = crtc[7] ? crtc[7] : 30;
    int x0 = (ANCHO - 320) / 2 + (46 - r2) * 8, y0 = (ALTO - 200) / 2 + (30 - r7) * (int)sl;
    unsigned x, y, i;
    int py, px, k;
    FILE *f;
    for (py = 0; py < ALTO; ++py)
        for (px = 0; px < ANCHO; ++px) pinta(py, px, paleta[16]);
    for (y = 0; y < filas * sl; ++y) {
        py = y0 + (int)y;
        for (x = 0; x < bpl; ++x) {
            unsigned off = ((base & 0x7FF) + (y / sl) * bpl + x) & 0x7FF;
            uint8_t b = ram[(base & 0xC000) | ((y % sl) << 11) | off], c[4];
            if (modo == 1) {
                for (i = 0; i < 4; ++i) c[i] = paleta[((b >> (7 - i)) & 1) | (((b >> (3 - i)) & 1) << 1)];
            } else if (modo == 0) {
                for (i = 0; i < 2; ++i) {
                    unsigned pen = ((b >> (7 - i)) & 1) | (((b >> (3 - i)) & 1) << 2) | (((b >> (5 - i)) & 1) << 1) | (((b >> (1 - i)) & 1) << 3);
                    c[2 * i] = c[2 * i + 1] = paleta[pen];
                }
            } else {
                for (i = 0; i < 4; ++i) c[i] = paleta[(b >> (7 - 2 * i)) & 1];
            }
            for (k = 0; k < 4; ++k) {
                px = x0 + 4 * (int)x + k;
                pinta(py, px, c[k]);
            }
        }
    }
    f = fopen(nombre, "wb");
    if (!f) { perror(nombre); return; }
    fprintf(f, "P6\n%d %d\n255\n", ANCHO, ALTO);
    fwrite(pix, 1, sizeof pix, f);
    fclose(f);
}

static void al_frame(void)
{
    int i;
    fprintf(traza, "%u\tday=%u\thour=%u", frame, ram[0x28D1], ram[0x28D2]);
    pon("G", 0x2B88, 4);
    pon("A", 0x2B97, 4);
    pon("M", 0x2BA6, 4);
    pon("objA", 0x2947, 1);
    pon("objM", 0x294E, 1);
    pon("maskM", 0x2950, 1);
    pon("Mrsd", 0x37F5, 3);
    pon("key3", 0x2B77, 5);
    pon("flags", 0x37F2, 1);
    pon("phr", 0x28F2, 1);
    pon("cam", 0x37DC, 1);
    fprintf(traza, "\tkeys=");
    for (i = 0; i < nteclas; ++i)
        if (teclas[i].frame <= frame && frame < teclas[i].frame + teclas[i].frames)
            fprintf(traza, "%u:%u,", teclas[i].fila, teclas[i].bit);
    fprintf(traza, "\n");
    for (i = 0; i < nfotos; ++i)
        if (fotos[i] == frame) {
            char n[1024];
            snprintf(n, sizeof n, "%s/z%06u.ppm", dir_fotos, frame);
            foto(n);
        }
}

int main(int argc, char **argv)
{
    int r, a = 2;
    if (argc < 5) {
        fprintf(stderr, "usage: traza OUT.tsv [--fotos F1,F2,... DIR] RAM.bin ESTADO.txt PUNTOS.txt [hibrido options]\n");
        return 2;
    }
    traza = fopen(argv[1], "w");
    if (!traza) { perror(argv[1]); return 2; }
    if (!strcmp(argv[2], "--fotos") && argc > 6) {
        char *p = argv[3];
        while (*p && nfotos < 64) {
            fotos[nfotos++] = (unsigned)strtoul(p, &p, 10);
            if (*p == ',') ++p;
        }
        dir_fotos = argv[4];
        a = 5;
    }
    en_frame = al_frame;
    argv[a - 1] = argv[0];
    r = hibrido_main(argc - (a - 1), argv + (a - 1));
    fclose(traza);
    return r;
}
