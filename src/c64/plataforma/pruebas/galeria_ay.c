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

/* abadia64ks, the C64 platform's sound test: the game's AY writes for every sound it has, and the GNU build's
 * AY synthesis of a log.
 *
 *   galeria_ay RAM.bin LOG.txt        every sound of the game, one after another, as the game's own sequencer
 *                                     (juego/f_objetos_sonido.c, pure C) writes them, tick by tick: the triggers
 *                                     snd_play_* and snd_interrupt at each 300 Hz tick; LOG.txt has
 *                                     'TICK REGISTER VALUE' lines (as the GNU build's --ay)
 *   galeria_ay --sintetiza LOG.txt OUT.wav   the AY synthesis of juego/gnu/abadia64ks.c (genera, nivel_env,
 *                                     aplica: copied here unchanged; checked against that build's --wav by
 *                                     prueba.py) of a log: 44100 Hz, 32-bit float, mono, 300 ticks a second
 *
 * The gallery is what the test needs and the game's sessions do not give: the noise (doors, the mirror,
 * Severino), the bells and the music, each from start to end.  Built with the game's C files and -DJUEGO_PURO
 * (prueba.py); the platform calls the game needs and this does not use are stubs. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "juego64.h"
#include "datos_objetos_sonido.h"

uint8_t ram[0x10000];
static FILE *f_log;
static unsigned long tick;

void plat_psg(uint8_t reg, uint8_t v) { fprintf(f_log, "%lu %u %u\n", tick, reg, v); }
void plat_di(void) {}
void plat_ei(void) {}
uint8_t plat_aleatorio(void) { return 0; }
bool plat_cinta_carga(uint16_t fin, uint16_t len, uint8_t id) { (void)fin; (void)len; (void)id; return false; }
void plat_cinta_guarda(uint16_t fin, uint16_t len, uint8_t id) { (void)fin; (void)len; (void)id; }
void plat_cinta_motor(bool on) { (void)on; }
void plat_crtc(uint8_t reg, uint8_t valor) { (void)reg; (void)valor; }
void plat_modo(uint8_t modo) { (void)modo; }
void plat_tinta(uint8_t pen, uint8_t colour) { (void)pen; (void)colour; }
uint8_t plat_teclado_fila(uint8_t fila) { (void)fila; return 0xFF; }
void plat_espera(void) {}
void plat_frame(void) {}
void plat_pausa(uint16_t sp) { (void)sp; }
void plat_final(void) {}
void plat_salir(void) { exit(0); }

static int sonando(void)
{
    return (rb(D64_SND_CHANNEL_A + SND_STATE) | rb(D64_SND_CHANNEL_B + SND_STATE) | rb(D64_SND_CHANNEL_C + SND_STATE)) & 1;
}

/* n ticks of the 300 Hz interrupt's sound */
static void ticks(unsigned long n)
{
    while (n--) {
        snd_interrupt();
        ++tick;
    }
}

/* a sound from its trigger to its end, then a pause */
static void suena(void (*disparo)(void), const char *nombre)
{
    unsigned long t0 = tick;
    disparo();
    while (sonando() && tick - t0 < 3000) ticks(1);
    fprintf(stderr, "%-14s ticks %5lu-%5lu\n", nombre, t0, tick);
    ticks(60);
}

/* ---- juego/gnu/abadia64ks.c's AY synthesis (unchanged) ---- */
#define MUESTRAS 44100
static const float nivel_ay[16] = { 0.0f, 0.0137f, 0.0205f, 0.0291f, 0.0423f, 0.0618f, 0.0847f, 0.1369f,
                                    0.1691f, 0.2647f, 0.3527f, 0.4499f, 0.5704f, 0.6873f, 0.8482f, 1.0f };
static uint8_t ay[16];
static double fase_tono[3], fase_ruido, fase_env;
static unsigned ruido_lfsr = 1, ruido_bit, env_paso;
static int env_parado;

static void aplica(uint8_t reg, uint8_t v)
{
    ay[reg] = v;
    if (reg == 13) { env_paso = 0; env_parado = 0; fase_env = 0; }
}

static unsigned nivel_env(void)
{
    unsigned forma = ay[13] & 15, ciclo = env_paso / 16, k = env_paso % 16;
    int sube = (forma & 4) != 0;
    if (!(forma & 8)) return ciclo == 0 ? (sube ? k : 15 - k) : 0;
    if (forma & 1) {
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
/* ---- end of the copy ---- */

static void escribe_u32(FILE *f, uint32_t v) { fwrite(&v, 4, 1, f); }
static void escribe_u16(FILE *f, uint16_t v) { fwrite(&v, 2, 1, f); }

static int sintetiza(const char *log, const char *wav)
{
    FILE *f = fopen(log, "r"), *o = fopen(wav, "wb");
    static float buf[MUESTRAS / 300 + 2];
    unsigned long t, ultimo = 0, sonado = 0, muestras = 0, n;
    unsigned r, v;
    int hay;
    if (!f || !o) { fprintf(stderr, "cannot open %s or %s\n", log, wav); return 2; }
    fseek(o, 44, SEEK_SET);
    hay = fscanf(f, "%lu %u %u", &t, &r, &v) == 3;
    while (hay) {
        ultimo = t;
        for (; sonado <= ultimo; ++sonado) {          /* the tick's writes first, then its samples */
            while (hay && t <= sonado) { aplica((uint8_t)r, (uint8_t)v); hay = fscanf(f, "%lu %u %u", &t, &r, &v) == 3; }
            n = (sonado + 1) * MUESTRAS / 300 - sonado * MUESTRAS / 300;
            genera(buf, (unsigned)n);
            fwrite(buf, sizeof(float), n, o);
            muestras += n;
        }
    }
    for (n = 0; n < 300; ++n, ++sonado) {               /* one more second */
        unsigned long k = (sonado + 1) * MUESTRAS / 300 - sonado * MUESTRAS / 300;
        genera(buf, (unsigned)k);
        fwrite(buf, sizeof(float), k, o);
        muestras += k;
    }
    fseek(o, 0, SEEK_SET);
    fwrite("RIFF", 1, 4, o); escribe_u32(o, (uint32_t)(36 + muestras * 4)); fwrite("WAVEfmt ", 1, 8, o);
    escribe_u32(o, 16); escribe_u16(o, 3); escribe_u16(o, 1); escribe_u32(o, MUESTRAS); escribe_u32(o, MUESTRAS * 4);
    escribe_u16(o, 4); escribe_u16(o, 32); fwrite("data", 1, 4, o); escribe_u32(o, (uint32_t)(muestras * 4));
    fclose(o);
    fclose(f);
    return 0;
}

int main(int argc, char **argv)
{
    FILE *f;
    if (argc == 4 && !strcmp(argv[1], "--sintetiza")) return sintetiza(argv[2], argv[3]);
    if (argc != 3) { fprintf(stderr, "galeria_ay RAM.bin LOG.txt | galeria_ay --sintetiza LOG.txt OUT.wav\n"); return 2; }
    f = fopen(argv[1], "rb");
    if (!f || fread(ram, 1, 0x10000, f) != 0x10000) { fprintf(stderr, "cannot read %s\n", argv[1]); return 2; }
    fclose(f);
    f_log = fopen(argv[2], "w");
    if (!f_log) return 2;
    snd_silence_all();
    wb(D64_SND_MIXER_SENT, 0x3F);
    ticks(30);
    suena(snd_play_footstep, "footstep");
    suena(snd_play_object_taken, "object taken");
    suena(snd_play_object_dropped, "object dropped");
    suena(snd_play_beep, "beep");
    suena(snd_play_door_open, "door open");
    suena(snd_play_door_close, "door close");
    suena(snd_play_mirror_open, "mirror open");
    suena(snd_play_severino, "Severino");
    suena(snd_play_tercia_bells, "tercia bells");
    suena(snd_play_hour_bells, "hour bells");
    {
        unsigned long t0 = tick;                        /* the music loops: 12 s of it */
        snd_play_music_if_idle();
        ticks(3600);
        snd_silence_all();
        fprintf(stderr, "%-14s ticks %5lu-%5lu\n", "music", t0, tick);
        ticks(60);
    }
    fclose(f_log);
    return 0;
}
