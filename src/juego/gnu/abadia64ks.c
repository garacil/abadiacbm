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

/* abadia64ks for GNU (SDL2): the CPC 64 KiB (tape) version played in a window from start to end, in real
 * time: the introduction parchment, the loading screen, the game, and at 100 % the ending parchment for
 * ever, as the CPC does.
 *
 * The parchments and the loading screen are ../pergamino.c (the CPC's code in C, drawing the CPC screen
 * memory and timed in Z80 T-states); the game is the hybrid host (../hibrido.c, included here with its
 * main renamed: the game's C functions with --solo-c, the Z80 core for the main loop) or, built with
 * PURO (`make abadia64ks-puro`), the game in pure C (../puro/puro_host.c: no Z80 core, the same interface).  This file is the platform of a real computer: the CPC screen drawn from the memory as the CRTC and
 * the gate array show it, the keyboard matrix from the PC keyboard, the AY's register writes played through
 * an AY synthesiser, and the pace: a frame is shown when its 300 Hz ticks have elapsed in real time.
 *
 *   abadia64ks [--escala N] [--sin-sonido] [--etapa intro|juego|final] [--carga MS] [--cinta MS]
 *              [--trabajo DIR] (where data/ is: the tape's images, the game's start, the wait points)
 *   --carga MS: the loading screen's 16 KiB arrive in MS milliseconds (4000; the tape took minutes);
 *   --cinta MS: the ending's tape loading, with "PON EL CASSETTE EN MARCHA" on the screen (3000).
 *   tests (deterministic, emulated time; on Xvfb :99):
 *     --rapido                 no real-time pace (and no window updates but the captures)
 *     --wav OUT.wav            the sound to a file (32-bit float, mono, 44100 Hz)
 *     --guion-perg KEYS.txt    keys during the parchments and the loading screen: lines 'FRAME ROW:BIT [FRAMES]',
 *                              FRAME = 50 Hz frames of emulated time since 6000h (the introduction) or 31DAh
 *                              (the ending) was entered: the frames of tools/cpc_carga.py
 *                              --imagen cinta/primera_etapa.bin --call 6000 (or cinta/final.bin --call 31DA)
 *                              --int --guion
 *     --volcado OUT.bin        the screen state at every frame of the parchments: per frame a little-endian
 *                              u32 frame, u8 mode, 17 palette bytes, 16 CRTC registers, C000h-FFFFh
 *     --fotos F1,F2,... --dir DIR   BMP pictures of the window at those parchment frames (DIR/pNNNNNN.bmp)
 *     --ay OUT.txt             every AY write as 'TICK REGISTER VALUE' (300 Hz ticks of the clock)
 *     --hasta-perg FRAME       stop at that parchment frame
 *     --salta-final FRAME      at that game frame the game goes to its 100 % ending (3EC6h: "PON EL CASSETTE
 *                              EN MARCHA", then 31CFh, the tape, the ending parchment)
 *     --guion KEYS.txt --hasta FRAME --captura OUT.bmp   the game's (frames = main-loop iterations)
 *   keys: cursors (walk, turn), space, Q R S N Y and the rest of the CPC keys at their places; F12 quits.
 */
#ifdef PURO                                         /* the game in pure C (../puro/puro_host.c), no Z80 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../puro/puro_host.h"
#else
#define main hibrido_main
#include "../hibrido.c"
#undef main
#endif

#include <SDL.h>
#include "../pergamino.h"

#ifndef TRABAJO
#define TRABAJO "../../data"
#endif

/* ---- the screen ------------------------------------------------------------------------------------ */

/* the 32 hardware colours of the CPC gate array (RGB) */
static const uint8_t cpc_rgb[32][3] = {
    {128,128,128},{128,128,128},{0,255,128},{255,255,128},{0,0,128},{255,0,128},{0,128,128},{255,128,128},
    {255,0,128},{255,255,128},{255,255,0},{255,255,255},{255,0,0},{255,0,255},{255,128,0},{255,128,255},
    {0,0,128},{0,255,128},{0,255,0},{0,255,255},{0,0,0},{0,0,255},{0,128,0},{0,128,255},
    {128,0,128},{128,255,128},{128,255,0},{128,255,255},{128,0,0},{128,0,255},{128,128,0},{128,128,255}};

#define ANCHO 384                          /* the picture with a border: the CPC's 320 x 200 window and more */
#define ALTO 272
static uint32_t pixeles[ANCHO * ALTO];

static uint32_t rgb(uint8_t hw) { const uint8_t *c = cpc_rgb[hw & 31]; return 0xFF000000u | c[0] << 16 | c[1] << 8 | c[2]; }

/* the visible screen: R1 characters of 2 bytes a line, R6 rows of R9 + 1 lines, from the address of R12/R13;
 * mode 1 (4 pixels a byte, 2 bits each) or mode 0 (2 pixels, 4 bits) at the CPC's 320-wide scale.  Placed as
 * the monitor shows it: the usual screen (R1 = 40, R2 = 46, R6 = 25, R7 = 30) centred, one character (8
 * pixels) further left for each step of R2 above 46, one character row higher for each step of R7 above 30
 * (the loading screen, 32 x 24 with R2 = 43, sits 24 pixels right of the usual left edge). */
static void dibuja(void)
{
    unsigned base = ((crtc[12] & 0x30u) << 10) | ((crtc[12] & 3u) << 9) | ((unsigned)crtc[13] << 1);
    unsigned bpl = 2u * crtc[1], filas = crtc[6], sl = (crtc[9] & 7u) + 1;
    int r2 = crtc[2] ? crtc[2] : 46, r7 = crtc[7] ? crtc[7] : 30;   /* never written: the firmware's */
    int x0 = (ANCHO - 320) / 2 + (46 - r2) * 8, y0 = (ALTO - 200) / 2 + (30 - r7) * (int)sl;
    unsigned x, y, i;
    uint32_t borde = rgb(paleta[16]);
    for (i = 0; i < ANCHO * ALTO; ++i) pixeles[i] = borde;
    for (y = 0; y < filas * sl; ++y) {
        int py = y0 + (int)y;
        if (py < 0 || py >= ALTO) continue;
        for (x = 0; x < bpl; ++x) {
            unsigned off = ((base & 0x7FF) + (y / sl) * bpl + x) & 0x7FF;
            uint8_t b = ram[(base & 0xC000) | ((y % sl) << 11) | off];
            uint32_t c[4];
            int k;
            if (modo == 1) {
                for (i = 0; i < 4; ++i) c[i] = rgb(paleta[((b >> (7 - i)) & 1) | (((b >> (3 - i)) & 1) << 1)]);
            } else if (modo == 0) {
                for (i = 0; i < 2; ++i) {
                    unsigned pen = ((b >> (7 - i)) & 1) | (((b >> (3 - i)) & 1) << 1) | (((b >> (5 - i)) & 1) << 2) | (((b >> (1 - i)) & 1) << 3);   /* bits 7 3 5 1: pen bits 0 1 2 3 (CPC mode 0) */
                    c[2 * i] = c[2 * i + 1] = rgb(paleta[pen]);
                }
            } else {
                for (i = 0; i < 4; ++i) c[i] = rgb(paleta[(b >> (7 - 2 * i)) & 1]);
            }
            for (k = 0; k < 4; ++k) {
                int px = x0 + 4 * (int)x + k;
                if (px >= 0 && px < ANCHO) pixeles[py * ANCHO + px] = c[k];
            }
        }
    }
}

/* ---- the keyboard ---------------------------------------------------------------------------------- */

typedef struct { SDL_Scancode sc; uint8_t fila, bit; } tecla_cpc;
static const tecla_cpc teclado[] = {
    { SDL_SCANCODE_UP, 0, 0 }, { SDL_SCANCODE_RIGHT, 0, 1 }, { SDL_SCANCODE_DOWN, 0, 2 }, { SDL_SCANCODE_LEFT, 1, 0 },
    { SDL_SCANCODE_KP_ENTER, 0, 6 }, { SDL_SCANCODE_RETURN, 2, 2 }, { SDL_SCANCODE_LSHIFT, 2, 5 }, { SDL_SCANCODE_RSHIFT, 2, 5 },
    { SDL_SCANCODE_LCTRL, 2, 7 }, { SDL_SCANCODE_RCTRL, 2, 7 }, { SDL_SCANCODE_P, 3, 3 }, { SDL_SCANCODE_0, 4, 0 },
    { SDL_SCANCODE_9, 4, 1 }, { SDL_SCANCODE_O, 4, 2 }, { SDL_SCANCODE_I, 4, 3 }, { SDL_SCANCODE_L, 4, 4 },
    { SDL_SCANCODE_K, 4, 5 }, { SDL_SCANCODE_M, 4, 6 }, { SDL_SCANCODE_8, 5, 0 }, { SDL_SCANCODE_7, 5, 1 },
    { SDL_SCANCODE_U, 5, 2 }, { SDL_SCANCODE_Y, 5, 3 }, { SDL_SCANCODE_H, 5, 4 }, { SDL_SCANCODE_J, 5, 5 },
    { SDL_SCANCODE_N, 5, 6 }, { SDL_SCANCODE_SPACE, 5, 7 }, { SDL_SCANCODE_6, 6, 0 }, { SDL_SCANCODE_5, 6, 1 },
    { SDL_SCANCODE_R, 6, 2 }, { SDL_SCANCODE_T, 6, 3 }, { SDL_SCANCODE_G, 6, 4 }, { SDL_SCANCODE_F, 6, 5 },
    { SDL_SCANCODE_B, 6, 6 }, { SDL_SCANCODE_V, 6, 7 }, { SDL_SCANCODE_4, 7, 0 }, { SDL_SCANCODE_3, 7, 1 },
    { SDL_SCANCODE_E, 7, 2 }, { SDL_SCANCODE_W, 7, 3 }, { SDL_SCANCODE_S, 7, 4 }, { SDL_SCANCODE_D, 7, 5 },
    { SDL_SCANCODE_C, 7, 6 }, { SDL_SCANCODE_X, 7, 7 }, { SDL_SCANCODE_1, 8, 0 }, { SDL_SCANCODE_2, 8, 1 },
    { SDL_SCANCODE_ESCAPE, 8, 2 }, { SDL_SCANCODE_Q, 8, 3 }, { SDL_SCANCODE_TAB, 8, 4 }, { SDL_SCANCODE_A, 8, 5 },
    { SDL_SCANCODE_CAPSLOCK, 8, 6 }, { SDL_SCANCODE_Z, 8, 7 }, { SDL_SCANCODE_BACKSPACE, 9, 7 }, { SDL_SCANCODE_DELETE, 9, 7 },
};

static void lee_teclado(void)
{
    const Uint8 *k = SDL_GetKeyboardState(NULL);
    unsigned i;
    memset(teclas_vivas, 0, sizeof teclas_vivas);
    for (i = 0; i < sizeof teclado / sizeof teclado[0]; ++i)
        if (k[teclado[i].sc]) teclas_vivas[teclado[i].fila] |= (uint8_t)(1u << teclado[i].bit);
}

/* --guion-perg: keys by parchment frame */
static tecla_t guion_perg[1024];
static int nguion_perg;

static void carga_guion_perg(const char *p)
{
    FILE *f = fopen(p, "r");
    char linea[256];
    if (!f) { fprintf(stderr, "cannot read %s\n", p); exit(1); }
    while (fgets(linea, sizeof linea, f) && nguion_perg < (int)(sizeof guion_perg / sizeof guion_perg[0])) {
        unsigned fr, fi, bi, d = 15;
        char *c = strchr(linea, '#');
        if (c) *c = 0;
        if (sscanf(linea, "%u %u:%u %u", &fr, &fi, &bi, &d) < 3) continue;
        guion_perg[nguion_perg].frame = fr; guion_perg[nguion_perg].fila = (uint8_t)fi;
        guion_perg[nguion_perg].bit = (uint8_t)bi; guion_perg[nguion_perg].frames = d;
        ++nguion_perg;
    }
    fclose(f);
}

/* ---- the sound: an AY-3-8912 at 1 MHz (the CPC's), tones, noise, volumes and the envelope ----------- */

#define MUESTRAS 44100
static const float nivel_ay[16] = { 0.0f, 0.0137f, 0.0205f, 0.0291f, 0.0423f, 0.0618f, 0.0847f, 0.1369f,
                                    0.1691f, 0.2647f, 0.3527f, 0.4499f, 0.5704f, 0.6873f, 0.8482f, 1.0f };
static uint8_t ay[16];
static double fase_tono[3], fase_ruido, fase_env;
static unsigned ruido_lfsr = 1, ruido_bit, env_paso;
static int env_parado;
typedef struct { unsigned long tick; uint8_t reg, v; } escritura_t;
static escritura_t escrituras[4096];
static int nescrituras;
static SDL_AudioDeviceID audio;
static FILE *wav;                          /* --wav: the samples also to a file (32-bit float, mono) */
static FILE *f_ay;                         /* --ay: every write as 'TICK REGISTER VALUE' */
static unsigned long wav_muestras;
static unsigned long tick_sonado;

/* the sound's clock, in 300 Hz ticks since the program started: the parchments' (pergamino.c's, every
 * 13312 T-states of emulated time) or the game's (the hybrid's interrupts) */
static int en_perg;
static unsigned long base_sonido, ticks_base;
static unsigned long tick_ahora(void) { return base_sonido + (en_perg ? perg_ticks : ticks - ticks_base); }

static void psg(uint8_t reg, uint8_t v)
{
    unsigned long t = tick_ahora();
    if (f_ay) fprintf(f_ay, "%lu %u %u\n", en_perg ? perg_ticks : t, reg, v);
    if (nescrituras < (int)(sizeof escrituras / sizeof escrituras[0])) {
        escrituras[nescrituras].tick = t; escrituras[nescrituras].reg = reg; escrituras[nescrituras].v = v;
        ++nescrituras;
    }
}

static void aplica(uint8_t reg, uint8_t v)
{
    ay[reg] = v;
    if (reg == 13) { env_paso = 0; env_parado = 0; fase_env = 0; }
}

/* the envelope level 0-15 at its step (shapes of register 13: continue, attack, alternate, hold) */
static unsigned nivel_env(void)
{
    unsigned forma = ay[13] & 15, ciclo = env_paso / 16, k = env_paso % 16;
    int sube = (forma & 4) != 0;
    if (!(forma & 8)) return ciclo == 0 ? (sube ? k : 15 - k) : 0;
    if (forma & 1) {                                     /* hold after the first cycle */
        if (ciclo == 0) return sube ? k : 15 - k;
        return ((forma & 2) ? !sube : sube) ? 15 : 0;
    }
    if ((forma & 2) && (ciclo & 1)) sube = !sube;
    return sube ? k : 15 - k;
}

static void genera(float *out, unsigned n)
{
    unsigned i, c;
    for (i = 0; i < n; ++i) {
        float s = 0;
        unsigned per_ruido = ay[6] & 31 ? ay[6] & 31 : 1, per_env = ay[11] | ay[12] << 8;
        fase_ruido += 1e6 / 16.0 / per_ruido / MUESTRAS;
        while (fase_ruido >= 1) { fase_ruido -= 1; ruido_bit = ((ruido_lfsr ^ (ruido_lfsr >> 3)) & 1); ruido_lfsr = (ruido_lfsr >> 1) | (ruido_bit << 16); }
        if (per_env) {
            fase_env += 1e6 / 256.0 / per_env / MUESTRAS * 16;
            while (fase_env >= 1) { fase_env -= 1; ++env_paso; if (env_paso > 1000000) env_paso = 32; }
        }
        for (c = 0; c < 3; ++c) {
            unsigned per = (ay[2 * c] | (ay[2 * c + 1] & 15) << 8) ? (ay[2 * c] | (ay[2 * c + 1] & 15) << 8) : 1;
            int tono = !(ay[7] & (1 << c)), ruido = !(ay[7] & (8 << c)), alto;
            unsigned vol = ay[8 + c] & 16 ? nivel_env() : ay[8 + c] & 15;
            fase_tono[c] += 1e6 / 16.0 / per / MUESTRAS;
            fase_tono[c] -= (int)fase_tono[c];
            alto = (!tono || fase_tono[c] < 0.5) && (!ruido || (ruido_lfsr & 1));
            s += alto ? nivel_ay[vol] : 0;
        }
        out[i] = s * 0.25f;
    }
}

/* the sound of the ticks up to now: each tick (1/300 s) with the writes of that tick applied first */
static void suena(void)
{
    static float buf[MUESTRAS / 300 + 2];
    unsigned long hasta = tick_ahora();
    int w = 0;
    for (; tick_sonado < hasta; ++tick_sonado) {
        unsigned n = (unsigned)((tick_sonado + 1) * MUESTRAS / 300 - tick_sonado * MUESTRAS / 300);
        while (w < nescrituras && escrituras[w].tick <= tick_sonado) { aplica(escrituras[w].reg, escrituras[w].v); ++w; }
        genera(buf, n);
        if (audio) SDL_QueueAudio(audio, buf, n * sizeof(float));
        if (wav) { fwrite(buf, sizeof(float), n, wav); wav_muestras += n; }
    }
    if (w < nescrituras) memmove(escrituras, escrituras + w, (size_t)(nescrituras - w) * sizeof escrituras[0]);
    nescrituras -= w;
}

/* ---- the window, the pace, the end ----------------------------------------------------------------- */

static SDL_Window *ventana;
static SDL_Renderer *render;
static SDL_Texture *textura;
static int rapido, sonido = 1;
static Uint64 t0_real;
static unsigned long tick0_real;
static const char *captura, *dir_fotos;
static FILE *volcado;
static unsigned long fotos[256], hasta_perg;
static int nfotos;

static void presenta(void)
{
    dibuja();
    SDL_UpdateTexture(textura, NULL, pixeles, ANCHO * sizeof(uint32_t));
    SDL_RenderClear(render);
    SDL_RenderCopy(render, textura, NULL, NULL);
    SDL_RenderPresent(render);
}

static void guarda_bmp(const char *nombre)
{
    SDL_Surface *sf;
    dibuja();
    sf = SDL_CreateRGBSurfaceWithFormatFrom(pixeles, ANCHO, ALTO, 32, ANCHO * 4, SDL_PIXELFORMAT_ARGB8888);
    if (!sf || SDL_SaveBMP(sf, nombre) != 0) fprintf(stderr, "capture: %s\n", SDL_GetError());
    if (sf) SDL_FreeSurface(sf);
}

static void termina(int estado)
{
    if (sonido) suena();
    if (wav) {                                           /* the WAV header: IEEE float, mono, 44100 Hz */
        uint32_t datos = (uint32_t)(wav_muestras * 4), v32;
        uint16_t v16;
        fseek(wav, 0, SEEK_SET);
        fwrite("RIFF", 1, 4, wav); v32 = 36 + datos; fwrite(&v32, 4, 1, wav); fwrite("WAVEfmt ", 1, 8, wav);
        v32 = 16; fwrite(&v32, 4, 1, wav); v16 = 3; fwrite(&v16, 2, 1, wav); v16 = 1; fwrite(&v16, 2, 1, wav);
        v32 = MUESTRAS; fwrite(&v32, 4, 1, wav); v32 = MUESTRAS * 4; fwrite(&v32, 4, 1, wav);
        v16 = 4; fwrite(&v16, 2, 1, wav); v16 = 32; fwrite(&v16, 2, 1, wav);
        fwrite("data", 1, 4, wav); fwrite(&datos, 4, 1, wav);
        fclose(wav);
    }
    if (f_ay) fclose(f_ay);
    if (volcado) fclose(volcado);
    if (captura) guarda_bmp(captura);
    SDL_Quit();
    exit(estado);
}

static void eventos(void)
{
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT) termina(0);
        if (e.type == SDL_KEYDOWN && e.key.keysym.scancode == SDL_SCANCODE_F12) termina(0);
    }
}

/* the pace: the shown frame waits until its ticks (3328 us each, the CPC's 52 lines of 64 us) have elapsed */
static void ritmo_reinicia(void) { t0_real = SDL_GetPerformanceCounter(); tick0_real = tick_ahora(); }
static void ritmo(void)
{
    double debe = (double)(tick_ahora() - tick0_real) * 0.003328;
    double va = (double)(SDL_GetPerformanceCounter() - t0_real) / (double)SDL_GetPerformanceFrequency();
    if (debe > va) SDL_Delay((Uint32)((debe - va) * 1000));
    else if (va - debe > 0.5) ritmo_reinicia();          /* too late: start again */
}

/* the parchments' clock from now (pergamino.c's perg_reloj), the sound's going on */
static void reloj_perg(int iff)
{
    base_sonido = tick_ahora();
    en_perg = 1;
    perg_reloj(iff);
}

/* every frame of the parchments and the loading screen */
static void al_frame_perg(void)
{
    int i;
    eventos();
    lee_teclado();
    for (i = 0; i < nguion_perg; ++i)
        if (guion_perg[i].frame <= perg_frames && perg_frames < guion_perg[i].frame + guion_perg[i].frames)
            teclas_vivas[guion_perg[i].fila] |= (uint8_t)(1u << guion_perg[i].bit);
    if (sonido) suena();
    if (volcado) {
        uint32_t f = (uint32_t)perg_frames;
        uint8_t m = modo;
        fwrite(&f, 4, 1, volcado); fwrite(&m, 1, 1, volcado); fwrite(paleta, 1, 17, volcado);
        fwrite(crtc, 1, 16, volcado); fwrite(ram + 0xC000, 1, 0x4000, volcado);
    }
    for (i = 0; i < nfotos; ++i)
        if (fotos[i] == perg_frames) {
            char nombre[1024];
            snprintf(nombre, sizeof nombre, "%s/p%06lu.bmp", dir_fotos ? dir_fotos : ".", perg_frames);
            guarda_bmp(nombre);
        }
    if (!rapido) { presenta(); ritmo(); }
    if (hasta_perg && perg_frames >= hasta_perg) termina(0);
}

/* ---- the program ----------------------------------------------------------------------------------- */

static const char *trabajo = TRABAJO;
static unsigned ms_carga = 4000, ms_resto = 1000, ms_cinta = 3000;

static void lee_imagen(const char *nombre, uint8_t *m)
{
    char ruta[1024];
    FILE *f;
    snprintf(ruta, sizeof ruta, "%s/%s", trabajo, nombre);
    f = fopen(ruta, "rb");
    if (!f || fread(m, 1, 0x10000, f) != 0x10000) { fprintf(stderr, "cannot read %s\n", ruta); exit(1); }
    fclose(f);
}

/* the CPC as cpc_carga.py starts it: mode 1, every ink black, the firmware's CRTC */
static void cpc_inicial(void)
{
    static const uint8_t crtc_fw[16] = { 63, 40, 46, 0x8E, 38, 0, 25, 30, 0, 7, 0, 0, 0x30, 0, 0, 0 };
    memset(paleta, 0x14, sizeof paleta);
    modo = 1;
    memcpy(crtc, crtc_fw, sizeof crtc_fw);
}

/* the tape's first stage: the loader (0100h) has loaded block 16h (6000h-8BFFh) and calls 6000h, the
 * introduction parchment; then it shows the loading screen as the game's block arrives (pergamino.c) */
static void introduccion(void)
{
    static uint8_t etapa[0x10000], juego[0x10000];
    lee_imagen("cpc64/cinta/primera_etapa.bin", etapa);
    lee_imagen("cpc64/cinta/juego.bin", juego);
    memcpy(ram, etapa, sizeof etapa);
    cpc_inicial();
    reloj_perg(0);                                       /* 012Dh-0130h: the loader's DI, CALL 6000h */
    ritmo_reinicia();
    pergamino_nuevo();
    pergamino();
    pantalla_de_carga(etapa, juego, ms_carga, ms_resto);
}

/* the ending: from the game (31CFh: "PON EL CASSETTE EN MARCHA" is on the screen, block 2Ah is loaded from
 * tape to 6000h-8BFFh, then CALL 6000h for ever, 31DAh) or, for a test, from the simulator's start
 * (cpc_carga.py --imagen cinta/final.bin --call 31DA --int) */
static void final_cpc(int desde_juego)
{
    static uint8_t img[0x10000];
    lee_imagen("cpc64/cinta/final.bin", img);
    if (desde_juego) {
        reloj_perg(0);                                   /* 32ABh: DI, the tape */
        ritmo_reinicia();
        perg_espera((uint64_t)ms_cinta * 4000u);
        memcpy(ram + 0x6000, img + 0x6000, 0x2C00);
    } else {
        memcpy(ram, img, sizeof img);
        cpc_inicial();
    }
    reloj_perg(0);                                       /* 31DAh */
    ritmo_reinicia();
    pergamino_nuevo();
    pergamino_final();
}

static void lista(const char *s, unsigned long *v, int *n, int max)
{
    while (*s && *n < max) {
        char *fin;
        v[(*n)++] = strtoul(s, &fin, 10);
        if (*fin != ',') break;
        s = fin + 1;
    }
}

int main(int argc, char **argv)
{
    const char *f_ram = NULL, *f_estado = NULL, *f_puntos = NULL;
    char ruta_ram[1024], ruta_estado[1024], ruta_puntos[1024];
    unsigned hasta_f = 0, salta_final = 0;
    int escala = 3, i, etapa = 0;                        /* 0 the introduction, 1 the game, 2 the ending */
    for (i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--escala") && i + 1 < argc) escala = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--sin-sonido")) sonido = 0;
        else if (!strcmp(argv[i], "--trabajo") && i + 1 < argc) trabajo = argv[++i];
        else if (!strcmp(argv[i], "--ram") && i + 1 < argc) f_ram = argv[++i];
        else if (!strcmp(argv[i], "--estado") && i + 1 < argc) f_estado = argv[++i];
        else if (!strcmp(argv[i], "--puntos") && i + 1 < argc) f_puntos = argv[++i];
        else if (!strcmp(argv[i], "--etapa") && i + 1 < argc) {
            ++i;
            etapa = !strcmp(argv[i], "juego") ? 1 : !strcmp(argv[i], "final") ? 2 : 0;
        }
        else if (!strcmp(argv[i], "--carga") && i + 1 < argc) ms_carga = (unsigned)atoi(argv[++i]);
        else if (!strcmp(argv[i], "--cinta") && i + 1 < argc) ms_cinta = (unsigned)atoi(argv[++i]);
        else if (!strcmp(argv[i], "--guion") && i + 1 < argc) carga_guion(argv[++i]);
        else if (!strcmp(argv[i], "--hasta") && i + 1 < argc) hasta_f = (unsigned)atoi(argv[++i]);
        else if (!strcmp(argv[i], "--captura") && i + 1 < argc) captura = argv[++i];
        else if (!strcmp(argv[i], "--rapido")) rapido = 1;
        else if (!strcmp(argv[i], "--wav") && i + 1 < argc) { wav = fopen(argv[++i], "wb"); if (wav) fseek(wav, 44, SEEK_SET); }
        else if (!strcmp(argv[i], "--ay") && i + 1 < argc) f_ay = fopen(argv[++i], "w");
        else if (!strcmp(argv[i], "--guion-perg") && i + 1 < argc) carga_guion_perg(argv[++i]);
        else if (!strcmp(argv[i], "--volcado") && i + 1 < argc) volcado = fopen(argv[++i], "wb");
        else if (!strcmp(argv[i], "--fotos") && i + 1 < argc) lista(argv[++i], fotos, &nfotos, 256);
        else if (!strcmp(argv[i], "--dir") && i + 1 < argc) dir_fotos = argv[++i];
        else if (!strcmp(argv[i], "--hasta-perg") && i + 1 < argc) hasta_perg = strtoul(argv[++i], 0, 10);
        else if (!strcmp(argv[i], "--salta-final") && i + 1 < argc) salta_final = (unsigned)atoi(argv[++i]);
        else { fprintf(stderr, "unknown option %s (see the comment at the top of abadia64ks.c)\n", argv[i]); return 2; }
    }
    snprintf(ruta_ram, sizeof ruta_ram, "%s/cpc64/inicio_juego/ram.bin", trabajo);
    snprintf(ruta_estado, sizeof ruta_estado, "%s/cpc64/inicio_juego/estado.txt", trabajo);
    snprintf(ruta_puntos, sizeof ruta_puntos, "%s/sincrono/puntos64.txt", trabajo);
    if (!f_ram) f_ram = ruta_ram;
    if (!f_estado) f_estado = ruta_estado;
    if (!f_puntos) f_puntos = ruta_puntos;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_EVENTS) != 0) { fprintf(stderr, "SDL: %s\n", SDL_GetError()); return 1; }
    ventana = SDL_CreateWindow("La Abadía del Crimen (abadia64ks)", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                               ANCHO * escala, ALTO * escala, SDL_WINDOW_RESIZABLE);
    render = SDL_CreateRenderer(ventana, -1, rapido ? 0 : SDL_RENDERER_PRESENTVSYNC);
    SDL_RenderSetLogicalSize(render, ANCHO, ALTO);
    textura = SDL_CreateTexture(render, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, ANCHO, ALTO);
    if (sonido) {
        SDL_AudioSpec want, have;
        SDL_zero(want);
        want.freq = MUESTRAS; want.format = AUDIO_F32SYS; want.channels = 1; want.samples = 1024;
        audio = rapido ? 0 : SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
        if (audio) SDL_PauseAudioDevice(audio, 0);
    }
    al_psg = psg;                                        /* the hybrid's AY writes and pergamino.c's (plat_psg) */
#ifndef PURO
    cpu.port_in = puerto_in; cpu.port_out = puerto_out;  /* plat_psg goes through the CPC's ports: before the parchments,
                                                            which play before carga_estado sets up the CPU */
#endif
    perg_al_frame = al_frame_perg;

    if (etapa == 2) final_cpc(0);
    if (etapa == 0) introduccion();

    /* the game: the hybrid from the game's start (the tape loader's JP 0200h, 20BEh) */
    {
        uint8_t m = modo, p[17], c[32];
        memcpy(p, paleta, sizeof p); memcpy(c, crtc, sizeof c);
        carga_estado(f_ram, f_estado);
        carga_puntos(f_puntos);
        if (etapa == 0) {                                /* the CPC as the loading screen left it */
            modo = m; memcpy(paleta, p, sizeof p); memcpy(crtc, c, sizeof c);
        }
    }
#ifndef PURO
    solo_c = 1;                                          /* the game's C functions do the work, no checks */
    parada = 0x31CF;                                     /* the ending: corre_frame returns 2 there */
#endif
    base_sonido = tick_ahora(); en_perg = 0; ticks_base = ticks;
    ritmo_reinicia();
    for (;;) {
        int r;
        eventos();
        lee_teclado();
        if (salta_final && frame == salta_final) {       /* as 3E29h at 100 %: the cursor at 8006h (3E8Dh), 3EC6h */
#ifdef PURO
            puro_salta_final();
#else
            ww(0x28E8, 0x8006);                          /* D64_TXT_CURSOR */
            cpu.pc = 0x3EC6;
#endif
        }
        r = corre_frame(NULL);
        if (r == 2) {
            if (!rapido) presenta();
            final_cpc(1);
        }
        if (!r) { fprintf(stderr, "the game stopped\n"); termina(1); }
        if (sonido) suena();
        if (hasta_f && frame >= hasta_f) termina(0);
        if (!rapido) { presenta(); ritmo(); }
    }
}
